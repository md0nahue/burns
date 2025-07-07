#!/usr/bin/env ruby

require_relative 'lib/services/gemini_service'
require 'json'

puts "🔧 Debugging Gemini service with Cooper content..."

service = GeminiService.new

# Test with one simple segment from Cooper
test_segment = [
  {
    id: 0,
    start_time: 0.0,
    end_time: 3.86,
    text: "Just over eight years ago, President Trump went to the CIA headquarters in Langley, Virginia"
  }
]

puts "\n📝 Testing with political content:"
puts "Text: #{test_segment.first[:text]}"

puts "\n🧠 Calling Gemini directly..."
begin
  # Make the API call directly to see what happens
  prompt = service.send(:build_batch_analysis_prompt, test_segment, {})
  puts "\n📤 Prompt (first 200 chars):"
  puts prompt[0..200] + "..."
  
  response = service.send(:make_gemini_request, prompt)
  puts "\n📥 Raw Gemini response:"
  puts JSON.pretty_generate(response)
  
  # Parse the response
  parsed = service.send(:parse_batch_analysis_response, response, test_segment)
  puts "\n📊 Parsed result:"
  puts JSON.pretty_generate(parsed)
  
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts "🔧 Error class: #{e.class}"
  puts "🔧 Backtrace:"
  puts e.backtrace.first(10)
end