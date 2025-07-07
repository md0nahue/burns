#!/usr/bin/env ruby

require_relative 'lib/unsplash_client'

puts "🔑 Unsplash Advanced Test Script"
puts "=" * 40

# Initialize client
unsplash_client = UnsplashClient.new({ 
  api_key: ENV['UNSPLASH_ACCESS_KEY'],
  secret_key: ENV['UNSPLASH_SECRET_KEY']
})

# Test queries
test_queries = [
  'sunset',
  'city skyline',
  'abstract art',
  'nature wildlife',
  'technology'
]

puts "🧪 Testing multiple queries and resolutions..."
puts

test_queries.each do |query|
  puts "🔍 Testing query: '#{query}'"
  
  # Test different resolutions
  ['1080p', '4k'].each do |resolution|
    begin
      result = unsplash_client.search_images(query, resolution)
      
      if result && result[:images] && result[:images].any?
        image = result[:images].first
        puts "   ✅ #{resolution}: #{image[:description] || 'No description'}"
        puts "      Size: #{image[:width]}x#{image[:height]}"
        puts "      Photographer: #{image[:photographer]}"
        puts "      Likes: #{image[:metadata][:likes]}"
      else
        puts "   ❌ #{resolution}: No results"
      end
    rescue => e
      puts "   ❌ #{resolution}: Error - #{e.message}"
    end
  end
  puts
end

puts "📝 Advanced test completed!" 