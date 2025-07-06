# LLM Integration for Content Analysis

This document covers the LLM integration for analyzing transcribed audio content and generating image queries for the Burns video generation pipeline.

## 🎯 Overview

The LLM integration uses Groq's language models to analyze transcribed audio segments and determine what images would best illustrate the narrative. It's designed to work seamlessly with your existing image service bus to create compelling Ken Burns-style videos.

## 📋 Features

- **Intelligent Content Analysis**: LLM-powered analysis of transcribed audio
- **Automatic Chunking**: Groups audio segments for efficient analysis
- **Context-Aware Queries**: Generates specific image search queries
- **Fallback Generation**: Handles LLM failures gracefully
- **Quality Metrics**: Confidence scoring and validation
- **Multi-Format Support**: Works with various audio content types

## 🚀 Quick Start

### 1. Prerequisites

Ensure you have the Groq API integration set up:
```bash
export GROQ_API_KEY='your_groq_api_key'
```

### 2. Basic Usage

```ruby
require_relative 'lib/services/llm_service'
require_relative 'lib/pipeline/content_analyzer'

# Initialize services
llm_service = LLMService.new
content_analyzer = ContentAnalyzer.new(llm_service)

# Analyze transcribed segments
enhanced_result = content_analyzer.analyze_for_images(audio_result, {
  context: 'product review',
  style: 'modern, professional',
  chunk_duration: 30
})
```

## 🧠 LLM Service

### Core Functionality

The `LLMService` provides intelligent content analysis:

```ruby
# Analyze content for image queries
analyzed_segments = llm_service.analyze_content_for_images(segments, {
  chunk_duration: 30,  # Group segments into 30-second chunks
  context: 'product review',
  style: 'realistic, high-quality'
})

# Generate queries for single text
queries = llm_service.generate_image_queries_for_text("This smartphone has amazing features", {
  type: 'product review',
  style: 'modern technology'
})
```

### Analysis Process

1. **Chunking**: Groups audio segments into logical chunks (default: 30 seconds)
2. **LLM Analysis**: Sends each chunk to Groq LLM for analysis
3. **Query Generation**: Extracts specific image search queries
4. **Distribution**: Distributes queries across individual segments
5. **Validation**: Ensures quality and provides fallbacks

## 🎨 Content Analyzer

### Enhanced Analysis

The `ContentAnalyzer` provides high-level analysis capabilities:

```ruby
# Analyze audio result for images
enhanced_result = content_analyzer.analyze_for_images(audio_result, {
  context: 'product review',
  style: 'modern, professional',
  chunk_duration: 30
})

# Get analysis summary
summary = content_analyzer.get_analysis_summary(enhanced_result)

# Validate results
validation = content_analyzer.validate_analysis(enhanced_result)
```

### Analysis Metrics

The analyzer provides comprehensive metrics:

```ruby
metrics = enhanced_result[:analysis_metrics]

puts "Average Confidence: #{metrics[:average_confidence]}"
puts "Total Image Queries: #{metrics[:total_image_queries]}"
puts "Segments with Images: #{metrics[:segments_with_images]}"
puts "Average Queries per Segment: #{metrics[:average_queries_per_segment]}"
```

## 📊 Query Generation

### Smart Query Generation

The LLM generates specific, descriptive queries:

**Example Input:**
```
"This smartphone has an amazing camera that takes incredible photos. 
The battery life is outstanding and the design is sleek and modern."
```

**Generated Queries:**
- "modern smartphone camera"
- "sleek phone design"
- "high-quality photography"
- "battery technology"

### Query Quality Features

- **Specificity**: Focuses on visual elements mentioned in text
- **Descriptiveness**: 2-6 words for optimal search results
- **Context Awareness**: Considers emotional tone and content type
- **Ken Burns Optimization**: Prioritizes queries that work well for video effects

## 🔧 Configuration

### LLM Configuration

```ruby
# config/services.rb
LLM_CONFIG = {
  provider: 'groq',
  api_key: ENV['GROQ_API_KEY'],
  model: ENV['LLM_MODEL'] || 'llama-3.1-8b-instant',
  max_tokens: 2048,
  temperature: 0.1
}
```

### Analysis Options

```ruby
analysis_options = {
  context: 'product review',           # Content type
  style: 'modern, professional',       # Visual style
  chunk_duration: 30,                  # Seconds per chunk
  temperature: 0.1,                    # LLM creativity (0-1)
  max_tokens: 2048                     # Response length
}
```

## 📈 Quality Control

### Confidence Scoring

Each analysis includes confidence metrics:

```ruby
segment = {
  confidence: 0.75,           # Query quality score (0-1)
  image_queries: ['modern smartphone', 'tech workspace'],
  has_images: true,
  primary_theme: 'technology review',
  visual_style: 'modern, professional'
}
```

### Validation Features

```ruby
validation = content_analyzer.validate_analysis(enhanced_result)

if validation[:valid]
  puts "✅ Analysis passed validation"
else
  puts "⚠️  Issues found: #{validation[:total_issues]}"
  validation[:issues].each do |issue|
    puts "  - #{issue[:type]}: #{issue[:count]} items"
  end
end
```

## 🛠️ Error Handling

### LLM Response Parsing

The service handles various LLM response formats:

```ruby
# JSON response (preferred)
{
  "image_queries": ["modern smartphone", "tech workspace"],
  "primary_theme": "technology review",
  "visual_style": "modern, professional"
}

# Text fallback (when JSON parsing fails)
"modern smartphone
tech workspace
professional technology"
```

### Fallback Generation

When LLM analysis fails, the service generates fallback queries:

```ruby
# Based on keyword extraction
text = "This smartphone has amazing features"
fallback_queries = ["modern technology", "smartphone device"]
```

## 💰 Cost Optimization

### Chunking Strategy

- **Default**: 30-second chunks (good balance of cost/quality)
- **Short Content**: 15-second chunks for detailed analysis
- **Long Content**: 60-second chunks for cost efficiency

### Model Selection

```ruby
# Cost-effective analysis
llm_service = LLMService.new
# Uses llama-3.1-8b-instant by default

# For higher quality (if needed)
ENV['LLM_MODEL'] = 'llama-3.1-70b-8192'
```

## 🔄 Integration with Image Service

### Seamless Pipeline

```ruby
# 1. Process audio
audio_result = audio_processor.process_audio('review.mp3')

# 2. Analyze for images
enhanced_result = content_analyzer.analyze_for_images(audio_result)

# 3. Generate images
final_result = image_generator.generate_images_for_segments(enhanced_result)

# 4. Access results
final_result[:segments].each do |segment|
  puts "#{segment[:start_time]}s - #{segment[:end_time]}s: #{segment[:text]}"
  segment[:generated_images].each do |image|
    puts "  Image: #{image[:url]} (from '#{image[:query]}')"
  end
end
```

## 📊 Analysis Examples

### Product Review Analysis

**Input Audio:**
```
"This smartphone is absolutely incredible. The camera quality is 
unbelievable, and the battery life lasts all day. The design is 
sleek and modern, perfect for professionals."
```

**Generated Queries:**
- "professional smartphone camera"
- "sleek modern phone design"
- "long battery life technology"
- "high-quality mobile photography"

### Tutorial Analysis

**Input Audio:**
```
"Today we're going to learn how to cook the perfect pasta. 
First, you'll need a large pot of boiling water and some 
fresh ingredients. The key is to use high-quality olive oil."
```

**Generated Queries:**
- "cooking pasta pot"
- "fresh food ingredients"
- "olive oil cooking"
- "Italian cuisine preparation"

## 🧪 Testing

### Test Individual Components

```ruby
# Test LLM service
llm_service = LLMService.new
queries = llm_service.generate_image_queries_for_text(
  "This product is amazing", 
  { type: 'product review' }
)
puts "Generated queries: #{queries}"

# Test content analyzer
content_analyzer = ContentAnalyzer.new
summary = content_analyzer.get_analysis_summary(enhanced_result)
puts "Analysis summary: #{summary}"
```

### Run Full Demo

```bash
ruby demo_full_pipeline.rb
```

## 🚀 Next Steps

1. **Get Groq API Key**: Sign up at [Groq Console](https://console.groq.com/keys)
2. **Test Analysis**: Try with sample transcribed audio
3. **Integrate with Images**: Connect to your image service bus
4. **Optimize Queries**: Fine-tune analysis parameters
5. **Build Video Pipeline**: Create Ken Burns video generation

## 📚 API Reference

### LLMService Methods

- `analyze_content_for_images(segments, options)` - Analyze segments for image queries
- `generate_image_queries_for_text(text, context)` - Generate queries for single text
- `available_models` - Get available LLM models

### ContentAnalyzer Methods

- `analyze_for_images(audio_result, options)` - Analyze audio result for images
- `analyze_single_segment(text, context)` - Analyze single text segment
- `get_analysis_summary(enhanced_result)` - Get analysis summary
- `validate_analysis(enhanced_result)` - Validate analysis results

## 🤝 Support

- **Groq Documentation**: [https://console.groq.com/docs](https://console.groq.com/docs)
- **LLM Models**: [https://console.groq.com/docs/models](https://console.groq.com/docs/models)
- **Community**: [Groq Discord](https://discord.gg/groq) 