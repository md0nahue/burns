#!/bin/bash

# Deploy Go-based Lambda function for Ken Burns video generation
set -e

# Configuration
FUNCTION_NAME="ken-burns-video-generator-go"
RUNTIME="provided.al2"
HANDLER="ken_burns_generator"
ROLE_NAME="ken-burns-lambda-role"
POLICY_NAME="ken-burns-lambda-policy"
REGION="us-east-1"
TIMEOUT=300
MEMORY_SIZE=1024

echo "🚀 Deploying Go-based Lambda function for Ken Burns video generation..."
echo "  📝 Function: $FUNCTION_NAME"
echo "  🐚 Runtime: $RUNTIME"
echo "  📍 Region: $REGION"
echo "  ⏱️  Timeout: ${TIMEOUT}s"
echo "  💾 Memory: ${MEMORY_SIZE}MB"

# Create deployment directory
DEPLOY_DIR="lambda_go_deployment"
mkdir -p $DEPLOY_DIR

echo "\n📦 Creating deployment package..."

# Compile Go binary
echo "🔧 Compiling Go binary..."
cd lambda
GOOS=linux GOARCH=amd64 go build -o ../$DEPLOY_DIR/bootstrap ken_burns_generator_improved.go
cd ..
chmod +x $DEPLOY_DIR/bootstrap

# Create cache directory for downloads
CACHE_DIR="cache"
mkdir -p $CACHE_DIR

# Download ffmpeg binary (cached)
echo "🎥 Checking ffmpeg binary..."
FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
FFMPEG_CACHE="$CACHE_DIR/ffmpeg-release-amd64-static.tar.xz"

cd $DEPLOY_DIR

if [ ! -f "../$FFMPEG_CACHE" ]; then
    echo "  📥 Downloading ffmpeg binary..."
    curl -L -o "../$FFMPEG_CACHE" $FFMPEG_URL
else
    echo "  ✅ Using cached ffmpeg binary"
fi

cp "../$FFMPEG_CACHE" ffmpeg.tar.xz
tar -xf ffmpeg.tar.xz
cp ffmpeg-*-amd64-static/ffmpeg .
cp ffmpeg-*-amd64-static/ffprobe .
chmod +x ffmpeg ffprobe

# Clean up ffmpeg download
rm -rf ffmpeg-*-amd64-static ffmpeg.tar.xz

# Create deployment package
echo "📦 Creating deployment package..."
zip -r ../lambda_go_deployment.zip . > /dev/null
cd ..

# Check package size
PACKAGE_SIZE=$(stat -f%z lambda_go_deployment.zip 2>/dev/null || stat -c%s lambda_go_deployment.zip 2>/dev/null)
echo "📦 Package size: $((PACKAGE_SIZE / 1024 / 1024)) MB"

if [ $PACKAGE_SIZE -gt 50000000 ]; then
    echo "⚠️  Warning: Package size is over 50MB. Lambda has a 50MB limit for direct upload."
    echo "   Using S3 for deployment..."
    USE_S3=true
else
    echo "✅ Package size is under 50MB limit"
    USE_S3=false
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
    
    if [ "$USE_S3" = true ]; then
        echo "  📤 Uploading package to S3..."
        aws s3 cp lambda_go_deployment.zip s3://burns-videos/lambda-deployments/
        
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --s3-bucket burns-videos \
            --s3-key lambda-deployments/lambda_go_deployment.zip \
            --region $REGION
    else
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --zip-file fileb://lambda_go_deployment.zip \
            --region $REGION
    fi
    
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --timeout $TIMEOUT \
        --memory-size $MEMORY_SIZE \
        --environment Variables={S3_BUCKET=burns-videos} \
        --region $REGION
else
    echo "  📝 Creating new function..."
    
    if [ "$USE_S3" = true ]; then
        echo "  📤 Uploading package to S3..."
        aws s3 cp lambda_go_deployment.zip s3://burns-videos/lambda-deployments/
        
        aws lambda create-function \
            --function-name $FUNCTION_NAME \
            --runtime $RUNTIME \
            --role $ROLE_ARN \
            --handler $HANDLER \
            --code S3Bucket=burns-videos,S3Key=lambda-deployments/lambda_go_deployment.zip \
            --timeout $TIMEOUT \
            --memory-size $MEMORY_SIZE \
            --environment Variables={S3_BUCKET=burns-videos} \
            --region $REGION
    else
        aws lambda create-function \
            --function-name $FUNCTION_NAME \
            --runtime $RUNTIME \
            --role $ROLE_ARN \
            --handler $HANDLER \
            --code ZipFile=fileb://lambda_go_deployment.zip \
            --timeout $TIMEOUT \
            --memory-size $MEMORY_SIZE \
            --environment Variables={S3_BUCKET=burns-videos} \
            --region $REGION
    fi
fi

echo "\n✅ Deployment completed successfully!"
echo "  📝 Function: $FUNCTION_NAME"
echo "  🔗 Test with: aws lambda invoke --function-name $FUNCTION_NAME --payload fileb://test_event.json response.json" 