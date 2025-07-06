#!/bin/bash

# AWS Infrastructure Provisioning Script for Burns Video Pipeline
# This script creates the necessary AWS resources for the video generation pipeline

set -e  # Exit on any error

# Configuration
REGION=${AWS_REGION:-"us-east-1"}
BUCKET_NAME=${S3_BUCKET:-"burns-videos"}
LAMBDA_FUNCTION_NAME=${LAMBDA_FUNCTION:-"ken-burns-video-generator"}
LAMBDA_ROLE_NAME="burns-video-generator-role"
LAMBDA_POLICY_NAME="burns-video-generator-policy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    log_success "AWS CLI found"
}

# Check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    log_success "AWS credentials configured"
}

# Create S3 bucket
create_s3_bucket() {
    log_info "Creating S3 bucket: $BUCKET_NAME"
    
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        log_warning "Bucket $BUCKET_NAME already exists"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
        log_success "S3 bucket created: $BUCKET_NAME"
    fi
    
    # Configure bucket lifecycle policy
    log_info "Configuring lifecycle policy for bucket"
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --lifecycle-configuration '{
            "Rules": [
                {
                    "ID": "auto-cleanup",
                    "Status": "Enabled",
                    "Filter": {
                        "Prefix": "projects/"
                    },
                    "Expiration": {
                        "Days": 14
                    }
                }
            ]
        }'
    log_success "Lifecycle policy configured (14 days)"
}

# Create IAM role for Lambda
create_iam_role() {
    log_info "Creating IAM role: $LAMBDA_ROLE_NAME"
    
    # Create trust policy for Lambda
    cat > /tmp/trust-policy.json << EOF
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
        --role-name "$LAMBDA_ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json
    
    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    log_success "IAM role created: $LAMBDA_ROLE_NAME"
}

# Create IAM policy for S3 access
create_iam_policy() {
    log_info "Creating IAM policy: $LAMBDA_POLICY_NAME"
    
    # Create policy document
    cat > /tmp/policy-document.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF
    
    # Create policy
    aws iam create-policy \
        --policy-name "$LAMBDA_POLICY_NAME" \
        --policy-document file:///tmp/policy-document.json
    
    # Attach policy to role
    aws iam attach-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$LAMBDA_POLICY_NAME"
    
    log_success "IAM policy created and attached"
}

# Create Lambda function (placeholder)
create_lambda_function() {
    log_info "Creating Lambda function: $LAMBDA_FUNCTION_NAME"
    
    # Create a simple placeholder function
    cat > /tmp/lambda-function.py << 'EOF'
import json
import boto3
import os

def lambda_handler(event, context):
    """
    Placeholder Lambda function for Ken Burns video generation.
    This will be replaced with actual video processing logic.
    """
    print("Event:", json.dumps(event))
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Ken Burns video generator placeholder',
            'event': event
        })
    }
EOF
    
    # Create deployment package
    cd /tmp
    zip -r lambda-function.zip lambda-function.py
    
    # Get role ARN
    ROLE_ARN=$(aws iam get-role --role-name "$LAMBDA_ROLE_NAME" --query 'Role.Arn' --output text)
    
    # Create Lambda function
    aws lambda create-function \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --runtime python3.9 \
        --role "$ROLE_ARN" \
        --handler lambda-function.lambda_handler \
        --zip-file fileb://lambda-function.zip \
        --timeout 300 \
        --memory-size 512
    
    log_success "Lambda function created: $LAMBDA_FUNCTION_NAME"
}

# Create CloudWatch log group
create_log_group() {
    log_info "Creating CloudWatch log group"
    
    aws logs create-log-group --log-group-name "/aws/lambda/$LAMBDA_FUNCTION_NAME" || true
    log_success "CloudWatch log group created"
}

# Test the infrastructure
test_infrastructure() {
    log_info "Testing infrastructure..."
    
    # Test S3 bucket
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        log_success "S3 bucket accessible"
    else
        log_error "S3 bucket not accessible"
        return 1
    fi
    
    # Test Lambda function
    if aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" &>/dev/null; then
        log_success "Lambda function accessible"
    else
        log_error "Lambda function not accessible"
        return 1
    fi
    
    log_success "Infrastructure test passed"
}

# Clean up temporary files
cleanup() {
    rm -f /tmp/trust-policy.json
    rm -f /tmp/policy-document.json
    rm -f /tmp/lambda-function.py
    rm -f /tmp/lambda-function.zip
}

# Main execution
main() {
    echo "🚀 AWS Infrastructure Provisioning for Burns Video Pipeline"
    echo "=========================================================="
    echo ""
    
    # Pre-flight checks
    check_aws_cli
    check_aws_credentials
    
    # Create infrastructure
    create_s3_bucket
    create_iam_role
    create_iam_policy
    create_lambda_function
    create_log_group
    
    # Test everything
    test_infrastructure
    
    # Cleanup
    cleanup
    
    echo ""
    echo "🎉 Infrastructure provisioning completed!"
    echo ""
    echo "📋 Created Resources:"
    echo "  🪣 S3 Bucket: $BUCKET_NAME"
    echo "  👤 IAM Role: $LAMBDA_ROLE_NAME"
    echo "  📜 IAM Policy: $LAMBDA_POLICY_NAME"
    echo "  ⚡ Lambda Function: $LAMBDA_FUNCTION_NAME"
    echo "  📊 CloudWatch Log Group: /aws/lambda/$LAMBDA_FUNCTION_NAME"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Update your environment variables:"
    echo "     export S3_BUCKET='$BUCKET_NAME'"
    echo "     export LAMBDA_FUNCTION='$LAMBDA_FUNCTION_NAME'"
    echo "  2. Test the S3 service: ruby test_s3_service.rb"
    echo "  3. Implement the actual Lambda video generation function"
    echo "  4. Test the full pipeline"
}

# Run main function
main "$@" 