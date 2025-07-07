#!/usr/bin/env ruby

require_relative 'lib/image_service_bus'
require_relative 'config'

puts "🔑 Unsplash Service Bus Test Script"
puts "=" * 45

# Initialize the image service bus with config
config = {
  unsplash: {
    api_key: ENV['UNSPLASH_ACCESS_KEY'],
    secret_key: ENV['UNSPLASH_SECRET_KEY']
  }
}

puts "Unsplash Access Key: #{ENV['UNSPLASH_ACCESS_KEY'] ? '✅ Set' : '❌ Not set'}"
puts "Unsplash Secret Key: #{ENV['UNSPLASH_SECRET_KEY'] ? '✅ Set' : '❌ Not set'}"
puts

# Test through service bus
puts "🧪 Testing Unsplash through Image Service Bus..."
begin
  service_bus = ImageServiceBus.new(config)
  
  # Test single image retrieval
  puts "🔍 Searching for 'mountain landscape'..."
  result = service_bus.get_single_image('mountain landscape', '1080p')
  
  if result && result[:images] && result[:images].any?
    image = result[:images].first
    puts "✅ Service Bus working with Unsplash!"
    puts "   Provider: #{result[:provider]}"
    puts "   Query: #{result[:query]}"
    puts "   Found: #{image[:description] || 'No description'}"
    puts "   Size: #{image[:width]}x#{image[:height]}"
    puts "   Photographer: #{image[:photographer]}"
    puts "   URL: #{image[:url]}"
    
    if image[:metadata]
      puts "   Image ID: #{image[:metadata][:id]}"
      puts "   Likes: #{image[:metadata][:likes]}"
      puts "   Color: #{image[:metadata][:color]}"
    end
  else
    puts "❌ Service Bus returned no results"
  end
  
  # Test multiple images
  puts "\n🔍 Searching for multiple 'forest' images..."
  results = service_bus.get_images('forest', 2, '1080p')
  
  if results.any?
    puts "✅ Service Bus returned #{results.length} result sets"
    results.each_with_index do |result, index|
      puts "   Result #{index + 1}: #{result[:provider]} - #{result[:images].length} images"
    end
  else
    puts "❌ Service Bus returned no results for multiple search"
  end
  
rescue => e
  puts "❌ Service Bus error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
end

puts
puts "📝 Service Bus test completed!" 