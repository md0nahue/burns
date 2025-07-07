#!/usr/bin/env ruby

require_relative 'lib/services/gemini_service'
require 'json'

# Test Gemini with a few segments (not the full 137)
puts "🧠 Testing Gemini Service with batch processing..."

service = GeminiService.new
puts "✅ GeminiService initialized"

# Read the cached transcription
transcription_file = 'cache/angry.json'
if File.exist?(transcription_file)
  puts "📁 Reading transcription from cache..."
  cached_data = JSON.parse(File.read(transcription_file), symbolize_names: true)
  
  # Test with just the first 5 segments
  test_segments = cached_data[:segments].first(5)
  
  puts "\n📝 Testing with #{test_segments.length} segments:"
  test_segments.each_with_index do |segment, i|
    puts "  #{i}: #{segment[:text][0..60]}..."
  end
  
  puts "\n🎨 Analyzing content for images..."
  begin
    result = service.analyze_content_for_images(test_segments)
    puts "\n✅ Analysis completed successfully!"
    puts "📊 Total segments processed: #{result.length}"
    puts "📊 Segments with images: #{result.count { |s| s[:has_images] }}"
    puts "📊 Total image queries: #{result.sum { |s| s[:image_queries].length }}"
    
    # Show first few results
    result.first(3).each_with_index do |segment, i|
      puts "\nSegment #{i}:"
      puts "  Text: #{segment[:text][0..60]}..."
      puts "  Has images: #{segment[:has_images]}"
      puts "  Image queries: #{segment[:image_queries]}"
    end
    
  rescue => e
    puts "\n❌ Error in analysis: #{e.message}"
    puts "🔧 Error class: #{e.class}"
    puts "🔧 Backtrace:"
    puts e.backtrace.first(10)
  end
  
else
  puts "❌ No transcription cache found at #{transcription_file}"
end