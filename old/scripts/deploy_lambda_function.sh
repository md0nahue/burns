#!/bin/bash

# Deploy Lambda function for Ken Burns video generation
set -e

# Configuration
FUNCTION_NAME="ken-burns-video-generator"
RUNTIME="python3.9"
HANDLER="ken_burns_video_generator.lambda_handler"
ROLE_NAME="ken-burns-lambda-role"
POLICY_NAME="ken-burns-lambda-policy"
REGION="us-east-1"
TIMEOUT=300
MEMORY_SIZE=1024

echo "🚀 Deploying Lambda function for Ken Burns video generation..."
echo "  📝 Function: $FUNCTION_NAME"
echo "  🐍 Runtime: $RUNTIME"
echo "  📍 Region: $REGION"
echo "  ⏱️  Timeout: ${TIMEOUT}s"
echo "  💾 Memory: ${MEMORY_SIZE}MB"

# Create deployment directory
DEPLOY_DIR="lambda_deployment"
mkdir -p $DEPLOY_DIR

echo "\n📦 Creating deployment package..."

# Copy Lambda function
cp lambda/ken_burns_video_generator.py $DEPLOY_DIR/

# Create minimal requirements.txt (only boto3)
cat > $DEPLOY_DIR/requirements.txt << EOF
boto3>=1.26.0
EOF

# Install only boto3
echo "📥 Installing minimal Python dependencies..."
cd $DEPLOY_DIR
pip install -r requirements.txt -t .

# Remove unnecessary files to reduce package size
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find . -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true

# Download ffmpeg binary for Lambda
echo "🎥 Downloading ffmpeg binary for Lambda..."
FFMPEG_VERSION="4.4.2"
FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"

# Download and extract ffmpeg
curl -L -o ffmpeg.tar.xz $FFMPEG_URL
tar -xf ffmpeg.tar.xz
cp ffmpeg-*-amd64-static/ffmpeg .
cp ffmpeg-*-amd64-static/ffprobe .
chmod +x ffmpeg ffprobe

# Clean up ffmpeg download
rm -rf ffmpeg-*-amd64-static ffmpeg.tar.xz

# Create deployment package
echo "📦 Creating deployment package..."
zip -r ../lambda_deployment.zip . > /dev/null
cd ..

# Check package size
PACKAGE_SIZE=$(stat -f%z lambda_deployment.zip 2>/dev/null || stat -c%s lambda_deployment.zip 2>/dev/null)
echo "📦 Package size: $((PACKAGE_SIZE / 1024 / 1024)) MB"

if [ $PACKAGE_SIZE -gt 50000000 ]; then
    echo "⚠️  Warning: Package size is over 50MB. Lambda has a 50MB limit for direct upload."
    echo "   Consider using S3 for deployment or reducing package size."
fi

# Check if IAM role exists, create if not
echo "\n🔐 Checking IAM role..."
if ! aws iam get-role --role-name $ROLE_NAME --region $REGION > /dev/null 2>&1; then
    echo "  📝 Creating IAM role: $ROLE_NAME"
    
    # Create trust policy
    cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    
    # Create role
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file://trust-policy.json \
        --region $REGION
    
    # Wait for role to be available
    echo "  ⏳ Waiting for role to be available..."
    aws iam wait role-exists --role-name $ROLE_NAME --region $REGION
    
    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
        --region $REGION
    
    echo "  ✅ IAM role created successfully"
else
    echo "  ✅ IAM role already exists"
fi

# Create custom policy for S3 access
echo "\n📋 Creating custom IAM policy..."
cat > lambda-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::burns-videos",
                "arn:aws:s3:::burns-videos/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
EOF

# Create policy if it doesn't exist
if ! aws iam get-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME --region $REGION > /dev/null 2>&1; then
    echo "  📝 Creating custom policy: $POLICY_NAME"
    aws iam create-policy \
        --policy-name $POLICY_NAME \
        --policy-document file://lambda-policy.json \
        --region $REGION
else
    echo "  ✅ Custom policy already exists"
fi

# Attach custom policy to role
echo "  🔗 Attaching custom policy to role..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME \
    --region $REGION

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --region $REGION --query Role.Arn --output text)

echo "  📋 Role ARN: $ROLE_ARN"

# Check if function exists
echo "\n🔍 Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION > /dev/null 2>&1; then
    echo "  📝 Updating existing function..."
    
    # If package is too large, upload to S3 first
    if [ $PACKAGE_SIZE -gt 50000000 ]; then
        echo "  📤 Uploading package to S3 (package too large for direct upload)..."
        aws s3 cp lambda_deployment.zip s3://burns-videos/lambda-deployments/
        
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --s3-bucket burns-videos \
            --s3-key lambda-deployments/lambda_deployment.zip \
            --region $REGION
    else
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --zip-file fileb://lambda_deployment.zip \
            --region $REGION
    fi
    
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --timeout $TIMEOUT \
        --memory-size $MEMORY_SIZE \
        --environment Variables='{"S3_BUCKET":"burns-videos"}' \
        --region $REGION
else
    echo "  📝 Creating new function..."
    
    # If package is too large, upload to S3 first
    if [ $PACKAGE_SIZE -gt 50000000 ]; then
        echo "  📤 Uploading package to S3 (package too large for direct upload)..."
        aws s3 cp lambda_deployment.zip s3://burns-videos/lambda-deployments/
        
        aws lambda create-function \
            --function-name $FUNCTION_NAME \
            --runtime $RUNTIME \
            --role $ROLE_ARN \
            --handler $HANDLER \
            --code S3Bucket=burns-videos,S3Key=lambda-deployments/lambda_deployment.zip \
            --timeout $TIMEOUT \
            --memory-size $MEMORY_SIZE \
            --environment Variables='{"S3_BUCKET":"burns-videos"}' \
            --region $REGION
    else
        aws lambda create-function \
            --function-name $FUNCTION_NAME \
            --runtime $RUNTIME \
            --role $ROLE_ARN \
            --handler $HANDLER \
            --zip-file fileb://lambda_deployment.zip \
            --timeout $TIMEOUT \
            --memory-size $MEMORY_SIZE \
            --environment Variables='{"S3_BUCKET":"burns-videos"}' \
            --region $REGION
    fi
fi

# Wait for function to be active
echo "\n⏳ Waiting for function to be active..."
aws lambda wait function-active --function-name $FUNCTION_NAME --region $REGION

# Test function
echo "\n🧪 Testing Lambda function..."
TEST_PAYLOAD='{"project_id":"test-deployment","options":{"test_mode":true}}'

aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload "$TEST_PAYLOAD" \
    --region $REGION \
    response.json

echo "  📊 Function response:"
cat response.json | jq '.' 2>/dev/null || cat response.json

# Clean up
echo "\n🧹 Cleaning up deployment files..."
rm -rf $DEPLOY_DIR
rm -f lambda_deployment.zip
rm -f response.json
rm -f trust-policy.json
rm -f lambda-policy.json

echo "\n✅ Lambda function deployment completed!"
echo "🎬 Function name: $FUNCTION_NAME"
echo "📍 Region: $REGION"
echo "🔗 Test with: aws lambda invoke --function-name $FUNCTION_NAME --payload '{\"project_id\":\"test\"}' response.json" 