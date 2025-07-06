#!/usr/bin/env ruby

require 'httparty'

puts "🔍 Pixabay API Debug"
puts "=" * 20

pixabay_key = ENV['PIXABAY_API_KEY']
puts "Pixabay API Key: #{pixabay_key ? "#{pixabay_key[0..10]}..." : '❌ Not set'}"

if pixabay_key
  # Test different Pixabay API endpoints
  puts "\n🧪 Testing basic search..."
  url = "https://pixabay.com/api/?key=#{pixabay_key}&q=ocean&per_page=1"
  puts "URL: #{url.gsub(pixabay_key, '***')}"
  
  begin
    response = HTTParty.get(url)
    puts "Status: #{response.code}"
    puts "Response: #{response.body[0..200]}..."
    
    if response.success?
      data = response.parsed_response
      if data['hits'] && data['hits'].any?
        photo = data['hits'].first
        puts "✅ Pixabay API working!"
        puts "   Found: #{photo['tags'] || 'No description'}"
        puts "   Size: #{photo['imageWidth']}x#{photo['imageHeight']}"
        puts "   Photographer: #{photo['user']}"
      else
        puts "❌ No hits found in response"
      end
    else
      puts "❌ HTTP Error: #{response.code} - #{response.message}"
      puts "Full response: #{response.body}"
    end
  rescue => e
    puts "❌ Error: #{e.message}"
  end
  
  # Test with minimal parameters
  puts "\n🧪 Testing minimal search..."
  url2 = "https://pixabay.com/api/?key=#{pixabay_key}&q=test"
  puts "URL: #{url2.gsub(pixabay_key, '***')}"
  
  begin
    response2 = HTTParty.get(url2)
    puts "Status: #{response2.code}"
    puts "Response: #{response2.body[0..200]}..."
  rescue => e
    puts "❌ Error: #{e.message}"
  end
else
  puts "❌ No Pixabay API key found"
end

puts "\n📝 Pixabay API Documentation:"
puts "   https://pixabay.com/api/docs/"
puts "   Check if your key is active and has proper permissions" 