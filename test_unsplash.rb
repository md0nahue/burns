#!/usr/bin/env ruby

require_relative 'lib/unsplash_client'

puts "🔑 Unsplash API Key Test Script"
puts "=" * 40

# Get API keys from environment
unsplash_access_key = ENV['UNSPLASH_ACCESS_KEY']
unsplash_secret_key = ENV['UNSPLASH_SECRET_KEY']

puts "Unsplash Access Key: #{unsplash_access_key ? '✅ Set' : '❌ Not set'}"
puts "Unsplash Secret Key: #{unsplash_secret_key ? '✅ Set' : '❌ Not set'}"
puts

# Test Unsplash
puts "🧪 Testing Unsplash API..."
if unsplash_access_key
  begin
    unsplash_client = UnsplashClient.new({ 
      api_key: unsplash_access_key,
      secret_key: unsplash_secret_key
    })
    
    # Test with a simple query
    result = unsplash_client.search_images('mountain', '1080p')
    if result && result[:images].any?
      image = result[:images].first
      puts "✅ Unsplash API working!"
      puts "   Found: #{image[:description] || 'No description'}"
      puts "   Size: #{image[:width]}x#{image[:height]}"
      puts "   Photographer: #{image[:photographer]}"
      puts "   URL: #{image[:url]}"
      puts "   Download URL: #{image[:download_url]}"
      puts "   Image ID: #{image[:metadata][:id]}"
      puts "   Likes: #{image[:metadata][:likes]}"
      puts "   Color: #{image[:metadata][:color]}"
    else
      puts "❌ Unsplash API returned no results"
    end
    
    # Test with another query
    puts "\n🧪 Testing second query..."
    result2 = unsplash_client.search_images('ocean sunset', '1080p')
    if result2 && result2[:images].any?
      image2 = result2[:images].first
      puts "✅ Second query successful!"
      puts "   Found: #{image2[:description] || 'No description'}"
      puts "   Size: #{image2[:width]}x#{image2[:height]}"
      puts "   Photographer: #{image2[:photographer]}"
    else
      puts "❌ Second query returned no results"
    end
    
  rescue => e
    puts "❌ Unsplash API error: #{e.message}"
    puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  end
else
  puts "⚠️  Skipping Unsplash test - no API key"
end

puts
puts "📝 To set your Unsplash API keys, run:"
puts "   export UNSPLASH_ACCESS_KEY='your_actual_access_key'"
puts "   export UNSPLASH_SECRET_KEY='your_actual_secret_key'"
puts "   ruby test_unsplash.rb" 