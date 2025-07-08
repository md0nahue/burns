#!/usr/bin/env ruby

require_relative 'lib/image_service_bus'

puts "🔍 Testing improved image quality standards..."
puts "=============================================="

# Initialize image service bus
image_bus = ImageServiceBus.new

# Test queries
test_queries = [
  "digital technology",
  "professional office",
  "modern cityscape",
  "abstract art"
]

test_queries.each do |query|
  puts "\n🎯 Testing query: '#{query}'"
  puts "-" * 40
  
  results = image_bus.get_images(query, 3, '1080p', 'stock_image')
  
  if results.any?
    results.each do |result|
      puts "📊 Provider: #{result[:provider]}"
      puts "🖼️  Images found: #{result[:images].length}"
      
      result[:images].each_with_index do |img, idx|
        puts "  #{idx + 1}. #{img[:width]}x#{img[:height]} - #{img[:url][0,80]}..."
        if img[:metadata] && img[:metadata][:quality_score]
          puts "     📈 Quality Score: #{img[:metadata][:quality_score].round(2)}"
        end
        if img[:metadata] && img[:metadata][:likes]
          puts "     👍 Likes: #{img[:metadata][:likes]}"
        end
      end
    end
  else
    puts "❌ No quality images found for this query"
  end
end

puts "\n✅ Image quality test completed!"