# AWS Integration for Video Pipeline

This document covers the AWS integration for the Burns video generation pipeline, including S3, Lambda, and infrastructure provisioning.

## 🎯 Overview

The AWS integration provides cloud infrastructure for storing generated images, processing videos with Lambda, and managing the complete video generation pipeline.

## 📋 Features

- **S3 Storage**: Secure image and video storage with lifecycle policies
- **Lambda Processing**: Serverless video generation with Ken Burns effects
- **Infrastructure as Code**: Automated provisioning with AWS CLI
- **Lifecycle Management**: Automatic cleanup of old projects
- **Security**: IAM roles and policies for secure access
- **Monitoring**: CloudWatch integration for logging

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install AWS CLI
# macOS
brew install awscli

# Ubuntu/Debian
sudo apt-get install awscli

# Install AWS SDK for Ruby
gem install aws-sdk-s3
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID='your_access_key'
export AWS_SECRET_ACCESS_KEY='your_secret_key'
export AWS_REGION='us-east-1'
```

### 3. Provision Infrastructure

```bash
# Run the provisioning script
ruby provision_aws.rb
```

### 4. Test the Integration

```bash
# Test S3 service
ruby test_s3_service.rb
```

## 🪣 S3 Service

### Core Functionality

The `S3Service` handles all S3 operations:

```ruby
require_relative 'lib/services/s3_service'

s3_service = S3Service.new

# Create bucket
result = s3_service.create_bucket('my-burns-videos', {
  lifecycle_days: 14,
  versioning: true,
  cors: true
})

# Upload project images
upload_result = s3_service.upload_project_images(
  'project-123',
  generated_images,
  'burns-videos'
)

# Create project manifest
manifest_result = s3_service.create_project_manifest(
  'project-123',
  project_data,
  'burns-videos'
)
```

### Bucket Structure

```
burns-videos/
├── projects/
│   ├── project-123/
│   │   ├── images/
│   │   │   ├── modern_smartphone_20241201_143022.jpg
│   │   │   ├── tech_workspace_20241201_143023.jpg
│   │   │   └── ...
│   │   └── manifest.json
│   ├── project-456/
│   │   ├── images/
│   │   └── manifest.json
│   └── ...
└── videos/
    ├── project-123_final_video.mp4
    └── ...
```

### Lifecycle Policy

- **Automatic Cleanup**: Projects older than 14 days are automatically deleted
- **Cost Management**: Helps manage storage costs
- **Configurable**: Can be adjusted via bucket settings

## ⚡ Lambda Integration

### Infrastructure Provisioning

The `AWSProvisioner` handles infrastructure creation:

```ruby
require_relative 'lib/services/aws_provisioner'

provisioner = AWSProvisioner.new

# Check infrastructure status
status = provisioner.check_infrastructure_status

# Provision infrastructure
result = provisioner.provision_infrastructure({
  region: 'us-east-1',
  bucket_name: 'burns-videos',
  lambda_function: 'ken-burns-video-generator'
})

# Test connectivity
test_result = provisioner.test_infrastructure
```

### Created Resources

- **S3 Bucket**: `burns-videos` (with lifecycle policy)
- **Lambda Function**: `ken-burns-video-generator`
- **IAM Role**: `burns-video-generator-role`
- **IAM Policy**: `burns-video-generator-policy`
- **CloudWatch Log Group**: `/aws/lambda/ken-burns-video-generator`

## 🔧 Configuration

### Environment Variables

```bash
# Required AWS credentials
export AWS_ACCESS_KEY_ID='your_access_key'
export AWS_SECRET_ACCESS_KEY='your_secret_key'
export AWS_REGION='us-east-1'

# Optional configuration
export S3_BUCKET='burns-videos'
export LAMBDA_FUNCTION='ken-burns-video-generator'
export S3_LIFECYCLE_DAYS='14'
```

### Configuration File

```ruby
# config/services.rb
AWS_CONFIG = {
  access_key_id: ENV['AWS_ACCESS_KEY_ID'],
  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
  region: ENV['AWS_REGION'] || 'us-east-1',
  lambda_function: ENV['LAMBDA_FUNCTION'] || 'ken-burns-video-generator',
  s3_bucket: ENV['S3_BUCKET'] || 'burns-videos',
  s3_lifecycle_days: ENV['S3_LIFECYCLE_DAYS'] || 14
}
```

## 📊 Pipeline Integration

### Complete Workflow

```ruby
# 1. Process audio and generate images
audio_result = audio_processor.process_audio('review.mp3')
enhanced_result = content_analyzer.analyze_for_images(audio_result)
final_result = image_generator.generate_images_for_segments(enhanced_result)

# 2. Upload images to S3
s3_service = S3Service.new
upload_result = s3_service.upload_project_images(
  'project-123',
  final_result[:segments].flat_map { |s| s[:generated_images] },
  'burns-videos'
)

# 3. Create project manifest
manifest_result = s3_service.create_project_manifest(
  'project-123',
  final_result,
  'burns-videos'
)

# 4. Trigger Lambda video generation (next step)
# lambda_service = LambdaService.new
# video_result = lambda_service.generate_video('project-123')
```

### Image Upload Process

1. **Download**: Images are downloaded from their original URLs
2. **Upload**: Images are uploaded to S3 with metadata
3. **Metadata**: Each image includes query, provider, timing info
4. **Organization**: Images are organized by project ID
5. **Manifest**: Project manifest is created with all metadata

## 🔒 Security Features

### IAM Roles and Policies

- **Lambda Execution Role**: Basic Lambda execution permissions
- **S3 Access Policy**: Read/write access to specific bucket
- **Least Privilege**: Minimal permissions for security

### Access Control

- **Presigned URLs**: Temporary access to S3 objects
- **Metadata Tracking**: Full audit trail of uploads
- **Versioning**: Optional versioning for data protection

## 💰 Cost Management

### Lifecycle Policies

- **Automatic Cleanup**: 14-day retention for projects
- **Storage Optimization**: Configurable retention periods
- **Cost Monitoring**: CloudWatch metrics for tracking

### Resource Optimization

- **Lambda Timeout**: 5 minutes for video processing
- **Memory Allocation**: 512MB for Lambda function
- **S3 Storage Classes**: Standard storage for active projects

## 🧪 Testing

### Test Infrastructure

```bash
# Test S3 service
ruby test_s3_service.rb

# Test infrastructure provisioning
ruby provision_aws.rb
```

### Manual Testing

```ruby
# Test S3 operations
s3_service = S3Service.new

# List project files
files = s3_service.list_project_files('project-123', 'burns-videos')

# Clean up old projects
cleanup_result = s3_service.cleanup_old_projects('burns-videos', 14)
```

## 🚀 Next Steps

### Lambda Video Generation

The next component to build is the Lambda function for video generation:

```python
# lambda_function.py (placeholder)
import json
import boto3
import os

def lambda_handler(event, context):
    """
    Ken Burns video generation Lambda function.
    This will be implemented with actual video processing logic.
    """
    project_id = event['project_id']
    
    # 1. Download images from S3
    # 2. Apply Ken Burns effects
    # 3. Combine with audio
    # 4. Upload final video to S3
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'project_id': project_id,
            'video_url': 's3://burns-videos/videos/project-123_final_video.mp4'
        })
    }
```

### Video Processing Pipeline

1. **Image Download**: Lambda downloads images from S3
2. **Ken Burns Effects**: Apply zoom and pan effects
3. **Audio Integration**: Combine with original audio
4. **Video Assembly**: Create final MP4 video
5. **Upload**: Upload final video to S3

## 📚 API Reference

### S3Service Methods

- `create_bucket(bucket_name, options)` - Create S3 bucket
- `upload_image(image_data, bucket_name, prefix)` - Upload single image
- `upload_project_images(project_id, images, bucket_name)` - Upload project images
- `create_project_manifest(project_id, project_data, bucket_name)` - Create manifest
- `list_project_files(project_id, bucket_name)` - List project files
- `cleanup_old_projects(bucket_name, days_old)` - Clean up old projects

### AWSProvisioner Methods

- `provision_infrastructure(options)` - Provision all infrastructure
- `check_infrastructure_status()` - Check current status
- `test_infrastructure()` - Test connectivity
- `get_infrastructure_details()` - Get resource details

## 🛠️ Troubleshooting

### Common Issues

1. **AWS Credentials Not Configured**
   ```bash
   aws configure
   ```

2. **S3 Bucket Already Exists**
   - Script will skip creation if bucket exists
   - Check bucket permissions

3. **IAM Role Creation Fails**
   - Ensure AWS CLI has IAM permissions
   - Check for existing roles with same name

4. **Lambda Function Creation Fails**
   - Ensure role ARN is correct
   - Check Lambda service permissions

### Debug Commands

```bash
# Check AWS identity
aws sts get-caller-identity

# List S3 buckets
aws s3 ls

# Check Lambda functions
aws lambda list-functions

# Check IAM roles
aws iam list-roles
```

## 🤝 Support

- **AWS Documentation**: [https://docs.aws.amazon.com/](https://docs.aws.amazon.com/)
- **AWS CLI**: [https://docs.aws.amazon.com/cli/](https://docs.aws.amazon.com/cli/)
- **AWS SDK for Ruby**: [https://docs.aws.amazon.com/sdk-for-ruby/](https://docs.aws.amazon.com/sdk-for-ruby/)
- **S3 API**: [https://docs.aws.amazon.com/s3/](https://docs.aws.amazon.com/s3/)
- **Lambda API**: [https://docs.aws.amazon.com/lambda/](https://docs.aws.amazon.com/lambda/) 