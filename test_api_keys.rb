#!/usr/bin/env ruby

require_relative 'lib/pexels_client'
require_relative 'lib/pixabay_client'

puts "🔑 API Key Test Script"
puts "=" * 30

# Get API keys from environment
pexels_key = ENV['PEXELS_API_KEY']
pixabay_key = ENV['PIXABAY_API_KEY']

puts "Pexels API Key: #{pexels_key ? '✅ Set' : '❌ Not set'}"
puts "Pixabay API Key: #{pixabay_key ? '✅ Set' : '❌ Not set'}"
puts

# Test Pexels
puts "🧪 Testing Pexels API..."
if pexels_key
  begin
    pexels_client = PexelsClient.new({ api_key: pexels_key })
    result = pexels_client.search_images('mountain', '1080p')
    if result && result[:images].any?
      image = result[:images].first
      puts "✅ Pexels API working!"
      puts "   Found: #{image[:description] || 'No description'}"
      puts "   Size: #{image[:width]}x#{image[:height]}"
      puts "   Photographer: #{image[:photographer]}"
      puts "   URL: #{image[:url]}"
    else
      puts "❌ Pexels API returned no results"
    end
  rescue => e
    puts "❌ Pexels API error: #{e.message}"
  end
else
  puts "⚠️  Skipping Pexels test - no API key"
end

puts

# Test Pixabay
puts "🧪 Testing Pixabay API..."
if pixabay_key
  begin
    pixabay_client = PixabayClient.new({ api_key: pixabay_key })
    result = pixabay_client.search_images('ocean', '1080p')
    if result && result[:images].any?
      image = result[:images].first
      puts "✅ Pixabay API working!"
      puts "   Found: #{image[:description] || 'No description'}"
      puts "   Size: #{image[:width]}x#{image[:height]}"
      puts "   Photographer: #{image[:photographer]}"
      puts "   URL: #{image[:url]}"
    else
      puts "❌ Pixabay API returned no results"
    end
  rescue => e
    puts "❌ Pixabay API error: #{e.message}"
  end
else
  puts "⚠️  Skipping Pixabay test - no API key"
end

puts
puts "📝 To set your API keys, run:"
puts "   export PEXELS_API_KEY='your_actual_pexels_key'"
puts "   export PIXABAY_API_KEY='your_actual_pixabay_key'"
puts "   ruby test_api_keys.rb" 