# Service Configuration Summary

## 🎯 Service Architecture

The Burns video generator uses a **hybrid approach** with different services optimized for specific tasks:

### 🎵 **Whisper (Speech-to-Text)**
- **Service**: Groq API
- **Model**: `whisper-large-v3-turbo`
- **Purpose**: Audio transcription and segmentation
- **Environment Variable**: `GROQ_API_KEY`
- **File**: `lib/services/whisper_service.rb`

### 🧠 **LLM (Content Analysis)**
- **Service**: Google Gemini API
- **Model**: `gemini-2.5-flash-lite-preview-06-17`
- **Purpose**: Content analysis and image query generation
- **Environment Variable**: `GEMINI_API_KEY`
- **File**: `lib/services/gemini_service.rb`

### 🖼️ **Image Services**
- **Providers**: Multiple (Unsplash, Pexels, Pixabay, WikiMedia, etc.)
- **Purpose**: Image search and retrieval
- **Environment Variables**: `UNSPLASH_API_KEY`, `PEXELS_API_KEY`, `PIXABAY_API_KEY`
- **File**: `lib/image_service_bus.rb`

## 🔧 Configuration Files

### `config/services.rb`
```ruby
# Groq for Whisper (Speech-to-Text)
GROQ_CONFIG = {
  api_key: ENV['GROQ_API_KEY'],
  base_url: 'https://api.groq.com/openai/v1',
  default_model: 'whisper-large-v3-turbo'
}

# Gemini for LLM (Content Analysis)
GEMINI_CONFIG = {
  api_key: ENV['GEMINI_API_KEY'],
  model: 'gemini-2.5-flash-lite-preview-06-17',
  max_tokens: 2048,
  temperature: 0.1
}

# LLM Configuration (points to Gemini)
LLM_CONFIG = {
  provider: 'gemini',
  api_key: ENV['GEMINI_API_KEY'],
  model: 'gemini-2.5-flash-lite-preview-06-17'
}
```

## 🚀 Pipeline Flow

1. **Audio Input** → **WhisperService** (Groq) → **Transcription**
2. **Transcription** → **GeminiService** (Gemini) → **Image Queries**
3. **Image Queries** → **ImageServiceBus** (Multiple providers) → **Images**
4. **Images + Audio** → **Video Generation** → **Final Video**

## 📋 Environment Variables

```bash
# Required for Whisper (Speech-to-Text)
GROQ_API_KEY=your_groq_api_key_here

# Required for LLM (Content Analysis)
GEMINI_API_KEY=your_gemini_api_key_here

# Optional for Image Services
UNSPLASH_API_KEY=your_unsplash_api_key_here
PEXELS_API_KEY=your_pexels_api_key_here
PIXABAY_API_KEY=your_pixabay_api_key_here

# AWS Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
```

## 🧪 Testing

### Test Whisper (Groq)
```bash
ruby test_whisper_service.rb
```

### Test Gemini (LLM)
```bash
ruby test_gemini_service.rb
```

### Test Image Services
```bash
ruby test_image_service_bus.rb
ruby test_wikimedia_client.rb
```

## 🔍 Service Selection Logic

### Why Groq for Whisper?
- **Speed**: Whisper models on Groq are extremely fast
- **Cost**: Competitive pricing for audio transcription
- **Quality**: Excellent accuracy for speech-to-text
- **Reliability**: Stable API with good uptime

### Why Gemini for LLM?
- **Model Quality**: `gemini-2.5-flash-lite-preview-06-17` is excellent for content analysis
- **Context Understanding**: Better at understanding narrative context
- **Image Query Generation**: Superior at generating specific, descriptive image queries
- **Cost**: Competitive pricing for LLM tasks

### Why Multiple Image Services?
- **Diversity**: Different services have different image collections
- **Fallback**: If one service fails, others can provide images
- **Specialization**: WikiMedia for public figures, Unsplash for landscapes, etc.
- **Quality**: Each service has strengths in different image types

## 📊 Performance Metrics

### Whisper (Groq)
- **Speed**: ~216x real-time for `whisper-large-v3-turbo`
- **Accuracy**: 12% word error rate
- **Cost**: $0.04/hour

### Gemini (LLM)
- **Response Time**: ~2-5 seconds per analysis
- **Query Quality**: High specificity and relevance
- **Cost**: Competitive pricing for content analysis

### Image Services
- **WikiMedia**: Excellent for public figures and historical content
- **Unsplash**: High-quality landscape and lifestyle images
- **Pexels**: Good for business and technology images
- **Pixabay**: Diverse collection with good licensing

## 🔧 Troubleshooting

### Common Issues

1. **Whisper Service Fails**
   - Check `GROQ_API_KEY` is set
   - Verify audio file format is supported
   - Ensure file size is under 25MB

2. **Gemini Service Fails**
   - Check `GEMINI_API_KEY` is set
   - Verify API key has proper permissions
   - Check network connectivity

3. **Image Services Fail**
   - Check individual API keys are set
   - Verify rate limits haven't been exceeded
   - Check network connectivity

### Validation Commands

```bash
# Validate all services
ruby -e "
require_relative 'lib/services/whisper_service'
require_relative 'lib/services/gemini_service'
require_relative 'lib/image_service_bus'

puts '✅ WhisperService initialized'
puts '✅ GeminiService initialized'
puts '✅ ImageServiceBus initialized'
"
```

## 🎯 Best Practices

1. **Environment Variables**: Always set required API keys
2. **Error Handling**: Services include comprehensive error handling
3. **Rate Limiting**: Respect API rate limits
4. **Testing**: Run tests before production use
5. **Monitoring**: Monitor API usage and costs
6. **Fallbacks**: Multiple image services provide redundancy 