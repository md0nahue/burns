#!/usr/bin/env ruby

require_relative 'lib/pexels_client'
require_relative 'lib/pixabay_client'
require_relative 'lib/unsplash_client'

puts "🔑 API Key Test Script"
puts "=" * 30

# Get API keys from environment
pexels_key = ENV['PEXELS_API_KEY']
pixabay_key = ENV['PIXABAY_API_KEY']
unsplash_access_key = ENV['UNSPLASH_ACCESS_KEY']
unsplash_secret_key = ENV['UNSPLASH_SECRET_KEY']

puts "Pexels API Key: #{pexels_key ? '✅ Set' : '❌ Not set'}"
puts "Pixabay API Key: #{pixabay_key ? '✅ Set' : '❌ Not set'}"
puts "Unsplash Access Key: #{unsplash_access_key ? '✅ Set' : '❌ Not set'}"
puts "Unsplash Secret Key: #{unsplash_secret_key ? '✅ Set' : '❌ Not set'}"
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

# Test Unsplash
puts "🧪 Testing Unsplash API..."
if unsplash_access_key
  begin
    unsplash_client = UnsplashClient.new({ 
      api_key: unsplash_access_key,
      secret_key: unsplash_secret_key
    })
    result = unsplash_client.search_images('forest', '1080p')
    if result && result[:images].any?
      image = result[:images].first
      puts "✅ Unsplash API working!"
      puts "   Found: #{image[:description] || 'No description'}"
      puts "   Size: #{image[:width]}x#{image[:height]}"
      puts "   Photographer: #{image[:photographer]}"
      puts "   URL: #{image[:url]}"
    else
      puts "❌ Unsplash API returned no results"
    end
  rescue => e
    puts "❌ Unsplash API error: #{e.message}"
  end
else
  puts "⚠️  Skipping Unsplash test - no API key"
end

puts
puts "📝 To set your API keys, run:"
puts "   export PEXELS_API_KEY='your_actual_pexels_key'"
puts "   export PIXABAY_API_KEY='your_actual_pixabay_key'"
puts "   export UNSPLASH_ACCESS_KEY='your_actual_unsplash_access_key'"
puts "   export UNSPLASH_SECRET_KEY='your_actual_unsplash_secret_key'"
puts "   ruby test_api_keys.rb" 