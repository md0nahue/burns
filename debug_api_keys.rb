#!/usr/bin/env ruby

require_relative 'lib/pexels_client'
require_relative 'lib/pixabay_client'

puts "🔍 API Key Debug Script"
puts "=" * 30

# Get API keys from environment
pexels_key = ENV['PEXELS_API_KEY']
pixabay_key = ENV['PIXABAY_API_KEY']

puts "Pexels API Key: #{pexels_key ? "#{pexels_key[0..10]}..." : '❌ Not set'}"
puts "Pixabay API Key: #{pixabay_key ? "#{pixabay_key[0..10]}..." : '❌ Not set'}"
puts

# Test Pexels with detailed debugging
puts "🧪 Testing Pexels API..."
if pexels_key
  begin
    pexels_client = PexelsClient.new({ api_key: pexels_key })
    
    # Test the request manually
    url = "https://api.pexels.com/v1/search?query=mountain&per_page=1&orientation=landscape"
    headers = { 'Authorization' => pexels_key }
    
    puts "   Making request to: #{url}"
    puts "   Headers: #{headers}"
    
    response = pexels_client.make_request(url, headers)
    if response
      puts "✅ Pexels API working!"
      if response['photos'] && response['photos'].any?
        photo = response['photos'].first
        puts "   Found: #{photo['alt'] || 'No description'}"
        puts "   Size: #{photo['width']}x#{photo['height']}"
        puts "   Photographer: #{photo['photographer']}"
        puts "   URL: #{photo['src']['large']}"
      else
        puts "   No photos found in response"
      end
    else
      puts "❌ Pexels API returned nil response"
    end
  rescue => e
    puts "❌ Pexels API error: #{e.message}"
    puts "   Error class: #{e.class}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
else
  puts "⚠️  Skipping Pexels test - no API key"
end

puts

# Test Pixabay with detailed debugging
puts "🧪 Testing Pixabay API..."
if pixabay_key
  begin
    pixabay_client = PixabayClient.new({ api_key: pixabay_key })
    
    # Test the request manually
    url = "https://pixabay.com/api/?key=#{pixabay_key}&q=ocean&image_type=photo&orientation=horizontal&per_page=1"
    
    puts "   Making request to: #{url.gsub(pixabay_key, '***')}"
    
    response = pixabay_client.make_request(url)
    if response
      puts "✅ Pixabay API working!"
      if response['hits'] && response['hits'].any?
        photo = response['hits'].first
        puts "   Found: #{photo['tags'] || 'No description'}"
        puts "   Size: #{photo['imageWidth']}x#{photo['imageHeight']}"
        puts "   Photographer: #{photo['user']}"
        puts "   URL: #{photo['webformatURL']}"
      else
        puts "   No hits found in response"
      end
    else
      puts "❌ Pixabay API returned nil response"
    end
  rescue => e
    puts "❌ Pixabay API error: #{e.message}"
    puts "   Error class: #{e.class}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
else
  puts "⚠️  Skipping Pixabay test - no API key"
end

puts
puts "📝 Troubleshooting tips:"
puts "   1. Check if your API keys are correct"
puts "   2. Verify the keys are active in your account"
puts "   3. Check if you have any rate limits or usage restrictions"
puts "   4. Try regenerating the API keys" 