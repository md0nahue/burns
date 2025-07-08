#!/bin/bash

# Deploy Bash-based Lambda function for Ken Burns video generation
set -e

# Configuration
FUNCTION_NAME="ken-burns-video-generator-bash"
RUNTIME="provided.al2"
HANDLER="ken_burns_video_generator.sh"
ROLE_NAME="ken-burns-lambda-role"
POLICY_NAME="ken-burns-lambda-policy"
REGION="us-east-1"
TIMEOUT=300
MEMORY_SIZE=1024

echo "🚀 Deploying Bash-based Lambda function for Ken Burns video generation..."
echo "  📝 Function: $FUNCTION_NAME"
echo "  🐚 Runtime: $RUNTIME"
echo "  📍 Region: $REGION"
echo "  ⏱️  Timeout: ${TIMEOUT}s"
echo "  💾 Memory: ${MEMORY_SIZE}MB"

# Create deployment directory
DEPLOY_DIR="lambda_bash_deployment"
mkdir -p $DEPLOY_DIR

echo "\n📦 Creating minimal deployment package..."

# Compile Go bootstrap and copy bash script
echo "🔧 Compiling Go bootstrap..."
cd lambda
GOOS=linux GOARCH=amd64 go build -o ../$DEPLOY_DIR/bootstrap bootstrap.go
cd ..
chmod +x $DEPLOY_DIR/bootstrap
cp lambda/ken_burns_video_generator.sh $DEPLOY_DIR/ken_burns_video_generator.sh
chmod +x $DEPLOY_DIR/ken_burns_video_generator.sh

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

# Download jq binary (cached)
echo "🔧 Checking jq binary..."
JQ_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
JQ_CACHE="$CACHE_DIR/jq-linux64"

if [ ! -f "../$JQ_CACHE" ]; then
    echo "  📥 Downloading jq binary..."
    curl -L -o "../$JQ_CACHE" $JQ_URL
else
    echo "  ✅ Using cached jq binary"
fi

cp "../$JQ_CACHE" jq
chmod +x jq

# Clean up ffmpeg download
rm -rf ffmpeg-*-amd64-static ffmpeg.tar.xz

# Create deployment package
echo "📦 Creating deployment package..."
zip -r ../lambda_bash_deployment.zip . > /dev/null
cd ..

# Check package size
PACKAGE_SIZE=$(stat -f%z lambda_bash_deployment.zip 2>/dev/null || stat -c%s lambda_bash_deployment.zip 2>/dev/null)
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
        aws s3 cp lambda_bash_deployment.zip s3://burns-videos/lambda-deployments/
        
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --s3-bucket burns-videos \
            --s3-key lambda-deployments/lambda_bash_deployment.zip \
            --region $REGION
    else
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --zip-file fileb://lambda_bash_deployment.zip \
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
        aws s3 cp lambda_bash_deployment.zip s3://burns-videos/lambda-deployments/
        
        aws lambda create-function \
            --function-name $FUNCTION_NAME \
            --runtime $RUNTIME \
            --role $ROLE_ARN \
            --handler $HANDLER \
            --code S3Bucket=burns-videos,S3Key=lambda-deployments/lambda_bash_deployment.zip \
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
            --zip-file fileb://lambda_bash_deployment.zip \
            --timeout $TIMEOUT \
            --memory-size $MEMORY_SIZE \
            --environment Variables={S3_BUCKET=burns-videos} \
            --region $REGION
    fi
fi

# Wait for function to be active
echo "\n⏳ Waiting for function to be active..."
aws lambda wait function-active --function-name $FUNCTION_NAME --region $REGION

# Test function
echo "\n🧪 Testing Lambda function..."
TEST_PAYLOAD='{"project_id":"test-bash-deployment","segment_id":"test","images":[{"url":"https://picsum.photos/1920/1080"}],"duration":5.0}'

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
rm -f lambda_bash_deployment.zip
rm -f response.json
rm -f trust-policy.json
rm -f lambda-policy.json

echo "\n✅ Bash Lambda function deployment completed!"
echo "🎬 Function name: $FUNCTION_NAME"
echo "📍 Region: $REGION"
echo "🔗 Test with: aws lambda invoke --function-name $FUNCTION_NAME --payload '{\"project_id\":\"test\"}' response.json" 