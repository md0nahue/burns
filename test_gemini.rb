#!/usr/bin/env ruby

require_relative 'lib/services/gemini_service'
require 'json'

# Test Gemini content analysis with a simple example
puts "🧠 Testing Gemini Service..."

service = GeminiService.new
puts "✅ GeminiService initialized"

# Create a simple test segment
test_segments = [
  {
    id: 0,
    start_time: 0.0,
    end_time: 5.0,
    text: "In this video, I want to talk about a highly successful YouTuber by the name of Cassidy"
  }
]

puts "\n📝 Test segments:"
puts JSON.pretty_generate(test_segments)

puts "\n🎨 Analyzing content for images..."
begin
  result = service.analyze_content_for_images(test_segments)
  puts "\n✅ Analysis completed successfully!"
  puts "📊 Result:"
  puts JSON.pretty_generate(result)
rescue => e
  puts "\n❌ Error in analysis: #{e.message}"
  puts "🔧 Error class: #{e.class}"
  puts "🔧 Backtrace:"
  puts e.backtrace.first(5)
end