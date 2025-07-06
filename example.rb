#!/usr/bin/env ruby

require_relative 'lib/image_service_bus'
require_relative 'config'

# Simple example of using the Image Service Bus
puts "🖼️  Image Service Bus Example"
puts "=" * 40

# Initialize the service bus
config = ImageServiceBusConfig::SERVICES
service_bus = ImageServiceBus.new(config)

# Example 1: Get a single image
puts "\n1. Getting a single image..."
result = service_bus.get_single_image('mountain landscape', '1080p')

if result && result[:images].any?
  image = result[:images].first
  puts "✅ Found image from #{result[:provider].upcase}:"
  puts "   📸 #{image[:description] || 'No description'}"
  puts "   📏 #{image[:width]}x#{image[:height]}"
  puts "   👤 #{image[:photographer]}"
  puts "   🔗 #{image[:url]}"
else
  puts "❌ No results found"
end

# Example 2: Get multiple images with fallback
puts "\n2. Getting multiple images with fallback..."
results = service_bus.get_images('ocean waves', 2, '1080p')

if results.any?
  puts "✅ Found #{results.length} result sets:"
  results.each_with_index do |result, i|
    next unless result
    puts "   #{i + 1}. #{result[:provider].upcase}: #{result[:images].length} images"
    if result[:images].any?
      image = result[:images].first
      puts "      📸 #{image[:description] || 'No description'}"
      puts "      📏 #{image[:width]}x#{image[:height]}"
    end
  end
else
  puts "❌ No results found"
end

# Example 3: Check client status
puts "\n3. Checking client status..."
status = service_bus.client_status
status.each do |client, info|
  status_icon = info[:available] ? "✅" : "❌"
  api_key_status = config[client][:api_key] ? "🔑" : "🔓"
  puts "   #{status_icon} #{client.to_s.upcase} #{api_key_status}"
end

# Example 4: Different resolutions
puts "\n4. Testing different resolutions..."
['1080p', '4k'].each do |resolution|
  puts "   #{resolution.upcase}:"
  result = service_bus.get_single_image('sunset', resolution)
  
  if result && result[:images].any?
    image = result[:images].first
    puts "     ✅ #{image[:width]}x#{image[:height]} from #{result[:provider]}"
  else
    puts "     ❌ No results"
  end
end

puts "\n✅ Example completed!"
puts "\n💡 Tip: Set API keys as environment variables for better results:"
puts "   export UNSPLASH_API_KEY='your_key'"
puts "   export PEXELS_API_KEY='your_key'"
puts "   export PIXABAY_API_KEY='your_key'" 