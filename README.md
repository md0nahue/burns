# Image Service Bus

A Ruby service bus architecture for multiple image APIs with intelligent fallback and random selection. Perfect for YouTube Ken Burns effects and high-resolution image needs.

## 🎯 Features

- **Service Bus Architecture**: Interchangeable API clients with unified interface
- **Random Selection**: Automatically selects random APIs for each request
- **Intelligent Fallback**: Continues trying APIs until no matches found on all
- **YouTube Optimized**: Supports 1080p and 4K resolutions for Ken Burns effects
- **Multiple APIs**: Unsplash, Pexels, Pixabay, Lorem Picsum, Openverse
- **Comprehensive Testing**: Live API tests with rate limiting awareness
- **Rich Metadata**: Image metadata, photographer info, licensing details

## 📋 Supported APIs

| API | License | Rate Limit | API Key Required |
|-----|---------|------------|------------------|
| **Unsplash** | ✅ Free commercial use | 50/hour | ✅ |
| **Pexels** | ✅ Free commercial use | 200/hour | ✅ |
| **Pixabay** | ✅ Free commercial use | 5000/hour | ✅ |
| **Lorem Picsum** | ✅ Creative Commons | 1000/hour | ❌ |
| **Openverse** | ✅ Creative Commons | 100/hour | ❌ |

## 🚀 Quick Start

### 1. Installation

```bash
# Clone or download the files
# No gems required - uses only Ruby standard library
```

### 2. Set up API Keys (Optional)

```bash
# Set environment variables for paid APIs
export UNSPLASH_API_KEY='your_unsplash_key'
export PEXELS_API_KEY='your_pexels_key'
export PIXABAY_API_KEY='your_pixabay_key'
```

### 3. Basic Usage

```ruby
require_relative 'image_service_bus'
require_relative 'config'

# Initialize with configuration
config = ImageServiceBusConfig::SERVICES
service_bus = ImageServiceBus.new(config)

# Get a single image
result = service_bus.get_single_image('mountain landscape', '1080p')

# Get multiple images with fallback
results = service_bus.get_images('ocean waves', 3, '4k')
```

### 4. Run Demo

```bash
ruby demo.rb
```

### 5. Run Tests

```bash
ruby test_image_service_bus.rb
```

## 📐 Resolution Support

The service bus supports YouTube-optimized resolutions:

| Target Video | Minimum Image Size | Ideal Image Size |
|--------------|-------------------|------------------|
| 1080p (1920×1080) | 2560×1440 | 3840×2160 |
| 4K (3840×2160) | 5120×2880 | 6000×3375 |

## 🔧 API Reference

### ImageServiceBus

Main service bus class that orchestrates all API clients.

#### Methods

- `get_single_image(query, resolution = '1080p')` - Get one image with fallback
- `get_images(query, count = 3, resolution = '1080p')` - Get multiple images
- `client_status` - Get status of all API clients

#### Example

```ruby
service_bus = ImageServiceBus.new(config)

# Single image
result = service_bus.get_single_image('mountain', '1080p')
if result
  image = result[:images].first
  puts "Found: #{image[:description]} (#{image[:width]}x#{image[:height]})"
  puts "URL: #{image[:url]}"
  puts "Photographer: #{image[:photographer]}"
end

# Multiple images with fallback
results = service_bus.get_images('ocean', 3, '4k')
results.each do |result|
  next unless result
  puts "#{result[:provider]}: #{result[:images].length} images"
end
```

### Individual API Clients

Each API has its own client class:

- `UnsplashClient` - High-quality photos, requires API key
- `PexelsClient` - Diverse collection, requires API key  
- `PixabayClient` - Broad range, requires API key
- `LoremPicsumClient` - Placeholder images, no API key needed
- `OpenverseClient` - Creative Commons images, no API key needed

## 📊 Response Format

All API responses follow a consistent format:

```ruby
{
  provider: 'unsplash',           # API name
  query: 'mountain landscape',    # Original search query
  images: [
    {
      url: 'https://...',         # Display URL
      download_url: 'https://...', # High-res download URL
      width: 2560,               # Image width
      height: 1440,              # Image height
      description: 'Mountain...', # Image description
      photographer: 'John Doe',   # Photographer name
      photographer_url: 'https://...', # Photographer profile
      metadata: {                 # Additional metadata
        id: '12345',
        likes: 42,
        license: 'CC0',
        # ... other API-specific data
      }
    }
  ]
}
```

## 🧪 Testing

The test suite includes:

- **Unit Tests**: Individual client functionality
- **Integration Tests**: Service bus orchestration
- **Live API Tests**: Real API calls (with rate limiting)
- **Error Handling**: Invalid queries, network issues
- **Performance Tests**: Response time validation

### Running Tests

```bash
# Run all tests
ruby test_image_service_bus.rb

# Tests will be skipped for APIs without keys
# Lorem Picsum and Openverse tests will always run
```

### Test Configuration

Tests are designed to respect rate limits:

- 2-second delays between tests
- Limited test queries
- Graceful handling of API failures
- Performance benchmarks

## ⚙️ Configuration

### Environment Variables

```bash
# Required for paid APIs
export UNSPLASH_API_KEY='your_key'
export PEXELS_API_KEY='your_key'
export PIXABAY_API_KEY='your_key'
```

### Configuration File

Edit `config.rb` to customize:

- Rate limits
- Timeouts
- Resolution presets
- Default settings

## 🎨 Use Cases

### YouTube Ken Burns Effect

```ruby
# Get high-resolution images for video backgrounds
result = service_bus.get_single_image('mountain landscape', '4k')
if result && result[:images].any?
  image = result[:images].first
  # Use image[:download_url] for highest quality
  # image[:width] and image[:height] for scaling
end
```

### Multiple Backup Images

```ruby
# Get 3 different images from different APIs
results = service_bus.get_images('sunset', 3, '1080p')
results.each do |result|
  # Each result is from a different API
  # Provides variety and redundancy
end
```

### Error Handling

```ruby
begin
  result = service_bus.get_single_image('query', '1080p')
  if result
    # Process successful result
  else
    # Handle no results
  end
rescue => e
  # Handle network/API errors
  puts "Error: #{e.message}"
end
```

## 🔍 API Details

### Unsplash
- **Quality**: High-quality professional photos
- **Rate Limit**: 50 requests/hour
- **Best For**: Professional content, high-end projects

### Pexels
- **Quality**: Diverse collection, good variety
- **Rate Limit**: 200 requests/hour
- **Best For**: General use, diverse content

### Pixabay
- **Quality**: Broad range including illustrations
- **Rate Limit**: 5000 requests/hour
- **Best For**: High-volume usage, mixed content

### Lorem Picsum
- **Quality**: Placeholder images
- **Rate Limit**: 1000 requests/hour
- **Best For**: Development, testing, placeholders

### Openverse
- **Quality**: Creative Commons licensed content
- **Rate Limit**: 100 requests/hour
- **Best For**: Open source projects, attribution required

## 🚨 Rate Limiting

The service bus includes built-in rate limiting awareness:

- Automatic delays between requests
- Graceful handling of rate limit errors
- Client status monitoring
- Fallback to available APIs

## 📝 License

This project is open source. The individual APIs have their own licensing terms:

- **Unsplash**: Free for commercial/non-commercial use
- **Pexels**: Free use, commercial allowed
- **Pixabay**: Free for most uses, commercial OK
- **Lorem Picsum**: Creative Commons
- **Openverse**: Creative Commons (attribution may be required)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📞 Support

For issues or questions:

1. Check the test suite for examples
2. Review API documentation for specific services
3. Ensure API keys are properly configured
4. Check rate limits for your API tier

## 🔄 Changelog

### v1.0.0
- Initial release
- Service bus architecture
- 5 API integrations
- YouTube resolution support
- Comprehensive test suite
- Rate limiting awareness
