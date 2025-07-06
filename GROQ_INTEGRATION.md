# Groq API Integration for Audio Transcription

This document covers the Groq API integration for speech-to-text transcription in the Burns video generation pipeline.

## 🎯 Overview

The Groq integration provides fast, accurate audio transcription using Whisper models. It's designed to work seamlessly with your existing image service bus to create Ken Burns-style videos from spoken content.

## 📋 Features

- **Multiple Whisper Models**: Support for all Groq Whisper variants
- **File Validation**: Automatic validation of audio files
- **Quality Metrics**: Detailed transcription quality analysis
- **Structured Output**: Pipeline-ready data format
- **Error Handling**: Comprehensive error handling and recovery
- **Cost Optimization**: Model selection based on needs

## 🚀 Quick Start

### 1. Get Groq API Key

1. Visit [Groq Console](https://console.groq.com/keys)
2. Create a new API key
3. Set environment variable:
   ```bash
   export GROQ_API_KEY='your_api_key_here'
   ```

### 2. Install Dependencies

```bash
gem install mime-types
```

### 3. Test the Integration

```bash
ruby test_whisper_service.rb
```

## 📊 Available Models

| Model | Cost/Hour | Language | Translation | Speed | Error Rate |
|-------|-----------|----------|-------------|-------|------------|
| `whisper-large-v3-turbo` | $0.04 | Multilingual | ❌ | 216x | 12% |
| `distil-whisper-large-v3-en` | $0.02 | English only | ❌ | 250x | 13% |
| `whisper-large-v3` | $0.111 | Multilingual | ✅ | 189x | 10.3% |

## 🔧 Usage Examples

### Basic Transcription

```ruby
require_relative 'lib/services/whisper_service'

whisper = WhisperService.new

# Simple transcription
result = whisper.transcribe('audio.mp3', {
  model: 'whisper-large-v3-turbo',
  language: 'en'
})

puts result['text']
```

### Advanced Transcription with Metadata

```ruby
# Get detailed transcription with timestamps
result = whisper.transcribe('audio.mp3', {
  model: 'whisper-large-v3-turbo',
  language: 'en',
  response_format: 'verbose_json',
  timestamp_granularities: ['segment', 'word'],
  prompt: 'This is a product review about technology'
})

# Access structured data
segments = result['segments']
words = result['words']

segments.each do |segment|
  puts "#{segment['start']}s - #{segment['end']}s: #{segment['text']}"
end
```

### Audio Processing Pipeline

```ruby
require_relative 'lib/pipeline/audio_processor'

processor = AudioProcessor.new

# Process audio and get structured data
result = processor.process_audio('audio.mp3', {
  model: 'whisper-large-v3-turbo',
  language: 'en',
  prompt: 'This is a product review'
})

# Access pipeline-ready data
puts "Duration: #{result[:duration]} seconds"
puts "Word count: #{result[:word_count]}"
puts "Segments: #{result[:segments].length}"

# Process each segment
result[:segments].each do |segment|
  puts "#{segment[:start_time]}s - #{segment[:end_time]}s: #{segment[:text]}"
  puts "Confidence: #{segment[:confidence]}"
end
```

## 📁 File Support

### Supported Formats
- **Audio**: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm
- **Max Size**: 25MB (free tier), 100MB (dev tier)
- **Min Duration**: 0.01 seconds
- **Billed Duration**: 10 seconds minimum

### File Validation

The service automatically validates:
- File existence and readability
- File size limits
- Supported audio formats
- Audio quality (basic checks)

## 📊 Quality Metrics

The `AudioProcessor` provides detailed quality metrics:

```ruby
metrics = result[:quality_metrics]

puts "Average Confidence: #{metrics[:average_confidence]}"
puts "Low Confidence Segments: #{metrics[:low_confidence_segments]}"
puts "High Noise Segments: #{metrics[:high_noise_segments]}"
puts "Total Segments: #{metrics[:total_segments]}"
```

### Quality Thresholds

- **Confidence**: Closer to 0 = better (normal range: -0.1 to -0.3)
- **No Speech Probability**: Lower = better (normal range: 0.0 to 0.1)
- **Compression Ratio**: ~1.6 = normal speech patterns

## 🔄 Integration with Image Service Bus

The transcription output is designed to work seamlessly with your existing image service bus:

```ruby
# 1. Transcribe audio
audio_result = processor.process_audio('review.mp3')

# 2. Analyze content for image selection (next step)
# This will use LLM to determine what images to generate
segments = audio_result[:segments]

# 3. Generate images for each segment
segments.each do |segment|
  # Use your existing image_service_bus
  images = image_service_bus.get_images(segment[:image_queries], 1, '1080p')
  # Process images for video generation
end
```

## 🛠️ Error Handling

The service handles various error scenarios:

```ruby
begin
  result = whisper.transcribe('audio.mp3')
rescue => e
  case e.message
  when /Authentication failed/
    puts "❌ Check your GROQ_API_KEY"
  when /File too large/
    puts "❌ File exceeds 25MB limit"
  when /Rate limit exceeded/
    puts "⏳ Wait before retrying"
  when /Unsupported file type/
    puts "❌ Check file format"
  else
    puts "❌ Unexpected error: #{e.message}"
  end
end
```

## 💰 Cost Optimization

### Model Selection Guide

- **Best Price/Performance**: `whisper-large-v3-turbo`
- **Fastest Processing**: `distil-whisper-large-v3-en` (English only)
- **Highest Accuracy**: `whisper-large-v3`
- **Translation Needed**: `whisper-large-v3`

### Cost Calculation

```ruby
# Example: 5-minute audio file
duration_hours = 5.0 / 3600  # Convert to hours
cost_per_hour = 0.04  # whisper-large-v3-turbo
total_cost = duration_hours * cost_per_hour
puts "Estimated cost: $#{total_cost.round(4)}"
```

## 🔧 Configuration

### Environment Variables

```bash
# Required
export GROQ_API_KEY='your_groq_api_key'

# Optional (for AWS integration)
export AWS_ACCESS_KEY_ID='your_aws_key'
export AWS_SECRET_ACCESS_KEY='your_aws_secret'
export AWS_REGION='us-east-1'
```

### Configuration File

The service uses `config/services.rb` for centralized configuration:

```ruby
# config/services.rb
module Config
  GROQ_CONFIG = {
    api_key: ENV['GROQ_API_KEY'],
    base_url: 'https://api.groq.com/openai/v1',
    default_model: 'whisper-large-v3-turbo',
    default_language: 'en'
  }
end
```

## 🧪 Testing

### Run Tests

```bash
# Test WhisperService
ruby test_whisper_service.rb

# Test AudioProcessor
ruby demo_audio_processing.rb
```

### Test with Real Audio

```ruby
# Create a test audio file (if you have one)
result = whisper.transcribe('test_audio.mp3')
puts "Transcription: #{result['text']}"
```

## 🚀 Next Steps

1. **Get API Key**: Sign up at [Groq Console](https://console.groq.com/keys)
2. **Test Integration**: Run the test scripts
3. **Process Audio**: Try with a real audio file
4. **Integrate with LLM**: Build content analysis for image selection
5. **Connect to Image Service**: Use your existing image service bus
6. **Build Video Pipeline**: Create the Ken Burns video generation

## 📚 API Reference

### WhisperService Methods

- `transcribe(file_path, options)` - Transcribe audio to text
- `translate(file_path, options)` - Translate audio to English
- `available_models` - Get model information
- `validate_file!(file_path)` - Validate audio file

### AudioProcessor Methods

- `process_audio(file_path, options)` - Process audio with structured output
- `get_audio_metadata(file_path)` - Get file metadata
- `validate_audio_file(file_path)` - Validate file for processing

## 🤝 Support

- **Groq Documentation**: [https://console.groq.com/docs](https://console.groq.com/docs)
- **API Reference**: [https://console.groq.com/docs/openai](https://console.groq.com/docs/openai)
- **Community**: [Groq Discord](https://discord.gg/groq) 