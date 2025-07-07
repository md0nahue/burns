# Burns - Ken Burns Style Video Generator

Burns is an automated video generation system that transforms spoken dialogue into Ken Burns-style documentaries. It processes audio through transcription, content analysis, image generation, and video assembly to create compelling visual narratives.

## 🎬 Features

- **Audio Transcription**: High-quality speech-to-text using Groq's Whisper API
- **Content Analysis**: LLM-powered analysis to generate relevant image queries
- **Image Generation**: Multi-provider image service bus (Unsplash, Pexels, Pixabay, etc.)
- **Ken Burns Effects**: Smooth zoom and pan effects applied to images
- **Video Assembly**: AWS Lambda-powered video generation with original audio
- **S3 Storage**: Automated file management with lifecycle policies
- **Complete Pipeline**: End-to-end processing from audio to final video

## 🏗️ Architecture

```
Audio Input → Whisper Transcription → LLM Analysis → Image Generation → Lambda Video Assembly → Final Video
     ↓              ↓                    ↓              ↓                    ↓              ↓
   S3 Upload    Segment Processing   Query Generation  Multi-Provider    Ken Burns     S3 Storage
                                                      Image Service      Effects
```

## 📋 Prerequisites

- Ruby 3.0+
- Python 3.9+ (for Lambda function)
- AWS CLI configured
- Groq API key
- Image service API keys (optional)

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install Python dependencies for Lambda
pip install boto3 opencv-python-headless moviepy numpy requests
```

### 2. Configure Environment Variables

Create a `.env` file or set environment variables:

```bash
# Required
export GROQ_API_KEY="your_groq_api_key"
export AWS_ACCESS_KEY_ID="your_aws_access_key"
export AWS_SECRET_ACCESS_KEY="your_aws_secret_key"
export AWS_REGION="us-east-1"

# Optional (for image services)
export UNSPLASH_API_KEY="your_unsplash_key"
export PEXELS_API_KEY="your_pexels_key"
export PIXABAY_API_KEY="your_pixabay_key"
```

### 3. Provision AWS Infrastructure

```bash
# Provision S3 bucket and IAM resources
./scripts/provision_aws_infrastructure.sh

# Or use Ruby wrapper
ruby provision_aws.rb
```

### 4. Deploy Lambda Function

```bash
# Deploy the video generation Lambda function
./scripts/deploy_lambda_function.sh
```

### 5. Test the System

```bash
# Test individual components
ruby test_whisper_service.rb
ruby test_gemini_service.rb
ruby test_s3_service.rb
ruby test_lambda_service.rb

# Run complete pipeline demo
ruby demo_complete_pipeline.rb path/to/audio.mp3
```

## 📚 Usage

### Basic Video Generation

```ruby
require_relative 'lib/pipeline/video_generator'

# Initialize the video generator
generator = VideoGenerator.new

# Generate a Ken Burns video
result = generator.generate_video('path/to/audio.mp3', {
  resolution: '1080p',
  fps: 24
})

if result[:success]
  puts "Video generated: #{result[:video_url]}"
  puts "Duration: #{result[:duration]} seconds"
else
  puts "Error: #{result[:error]}"
end
```

### Individual Service Usage

```ruby
# Audio transcription
whisper = WhisperService.new
gemini = GeminiService.new
image_bus = ImageServiceBus.new

# Content analysis
analysis = gemini.analyze_content(whisper.transcribe_file('audio.mp3')[:segments])

# Image generation
images = image_bus.generate_images_for_segment(segment, project_id)

# S3 operations
s3 = S3Service.new
s3.upload_file('file.jpg', 'project-123/images/')
```

## 🧪 Testing

### Test Individual Services

```bash
# Test Whisper (Speech-to-Text)
ruby test_whisper_service.rb

# Test Gemini (Content Analysis)
ruby test_gemini_service.rb

# Test Image Services
ruby test_image_service_bus.rb
ruby test_wikimedia_client.rb

# Test Lambda Service
ruby test_lambda_service.rb
```

### Integration Tests

```bash
# Test complete pipeline
ruby demo_complete_pipeline.rb sample_audio.mp3

# Test individual pipeline components
ruby demo_audio_processing.rb
ruby demo_full_pipeline.rb
```

## 📁 Project Structure

```
burns/
├── config/
│   └── services.rb          # Configuration management
├── lib/
│   ├── services/            # External service integrations
│   │   ├── whisper_service.rb

│   │   ├── s3_service.rb
│   │   ├── lambda_service.rb
│   │   └── aws_provisioner.rb
│   ├── pipeline/            # Pipeline components
│   │   ├── audio_processor.rb
│   │   ├── content_analyzer.rb
│   │   ├── image_generator.rb
│   │   └── video_generator.rb
│   └── base_image_client.rb # Image service base classes
├── lambda/
│   └── ken_burns_video_generator.py  # AWS Lambda function
├── scripts/
│   ├── provision_aws_infrastructure.sh
│   └── deploy_lambda_function.sh
├── test_*.rb               # Test scripts
├── demo_*.rb               # Demo scripts
└── README.md
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GROQ_API_KEY` | Groq API key for Whisper/LLM | Yes |
| `AWS_ACCESS_KEY_ID` | AWS access key | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | Yes |
| `AWS_REGION` | AWS region | No (default: us-east-1) |
| `UNSPLASH_API_KEY` | Unsplash API key | No |
| `PEXELS_API_KEY` | Pexels API key | No |
| `PIXABAY_API_KEY` | Pixabay API key | No |

### AWS Resources

The system creates the following AWS resources:

- **S3 Bucket**: `burns-videos` (with lifecycle policy)
- **IAM Role**: `ken-burns-lambda-role`
- **IAM Policy**: `ken-burns-lambda-policy`
- **Lambda Function**: `ken-burns-video-generator`

## 🎥 Video Generation Process

1. **Audio Processing**: Upload and transcribe audio using Whisper
2. **Content Analysis**: LLM analyzes transcript to generate image queries
3. **Image Generation**: Fetch relevant images from multiple providers
4. **Manifest Creation**: Create project manifest with all metadata
5. **Video Assembly**: Lambda function generates Ken Burns video
6. **Final Output**: Upload completed video to S3

## 🖼️ Image Service Providers

The system supports multiple image providers:

- **Unsplash**: High-quality photography (API key required)
- **Pexels**: Free stock photos (API key required)
- **Pixabay**: Creative Commons images (API key required)
- **Lorem Picsum**: Placeholder images (no API key needed)
- **Openverse**: Creative Commons search (no API key needed)

## 📊 Monitoring

### CloudWatch Logs

```bash
# Monitor Lambda function logs
aws logs tail /aws/lambda/ken-burns-video-generator --follow

# Monitor S3 access logs
aws logs tail /aws/s3/burns-videos --follow
```

### Project Status

```ruby
# Check project status
generator = VideoGenerator.new
status = generator.get_project_status('project-id')

# List all projects
projects = generator.list_projects
```

## 🧹 Cleanup

### Project Cleanup

```ruby
# Clean up project files
generator = VideoGenerator.new
result = generator.cleanup_project('project-id')
```

### AWS Resource Cleanup

```bash
# Remove Lambda function
aws lambda delete-function --function-name ken-burns-video-generator

# Remove IAM role and policy
aws iam detach-role-policy --role-name ken-burns-lambda-role --policy-arn arn:aws:iam::ACCOUNT:policy/ken-burns-lambda-policy
aws iam delete-role --role-name ken-burns-lambda-role
aws iam delete-policy --policy-arn arn:aws:iam::ACCOUNT:policy/ken-burns-lambda-policy

# Remove S3 bucket (after emptying)
aws s3 rb s3://burns-videos --force
```

## 🐛 Troubleshooting

### Common Issues

1. **Lambda Function Not Found**
   - Ensure the function is deployed: `./scripts/deploy_lambda_function.sh`
   - Check function name in config: `AWS_LAMBDA_FUNCTION`

2. **S3 Access Denied**
   - Verify IAM permissions are attached to Lambda role
   - Check bucket name configuration

3. **Image Generation Fails**
   - Verify API keys for image services
   - Check network connectivity
   - Fallback to Lorem Picsum (no API key needed)

4. **Video Generation Timeout**
   - Increase Lambda timeout in deployment script
   - Check video duration limits

### Debug Mode

```ruby
# Enable debug logging
ENV['DEBUG'] = 'true'
generator = VideoGenerator.new
```

## 📈 Performance

### Optimizations

- **Parallel Processing**: Image generation runs in parallel
- **Caching**: S3 stores intermediate results
- **Lambda Optimization**: 1024MB memory, 300s timeout
- **Image Compression**: Automatic resizing for video generation

### Limits

- **Audio Duration**: Up to 10 minutes recommended
- **Image Count**: 2-4 images per segment
- **Video Resolution**: 1920x1080 (1080p)
- **File Size**: 25MB max audio upload

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **Groq**: For fast Whisper transcription and LLM processing
- **AWS Lambda**: For serverless video generation
- **Image Providers**: Unsplash, Pexels, Pixabay for high-quality images
- **OpenCV & MoviePy**: For video processing and Ken Burns effects
