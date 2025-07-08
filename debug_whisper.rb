#!/usr/bin/env ruby

require_relative 'lib/services/whisper_service'

puts "🔍 Debugging Whisper Service"
puts "=" * 50

# Initialize service
begin
  service = WhisperService.new
  puts "✅ WhisperService initialized successfully"
rescue => e
  puts "❌ Failed to initialize WhisperService: #{e.message}"
  exit 1
end

# Check API key
api_key = ENV['GROQ_API_KEY']
if api_key
  puts "✅ GROQ_API_KEY is set (#{api_key[0..10]}...)"
else
  puts "❌ GROQ_API_KEY is not set"
  exit 1
end

# Validate file
audio_file = 'b3.mp3'
puts "\n🎵 Testing audio file: #{audio_file}"

unless File.exist?(audio_file)
  puts "❌ Audio file not found: #{audio_file}"
  exit 1
end

file_size = File.size(audio_file)
puts "📊 File size: #{(file_size / 1024.0 / 1024.0).round(2)} MB"

# Test file validation
begin
  service.send(:validate_file!, audio_file)
  puts "✅ File validation passed"
rescue => e
  puts "❌ File validation failed: #{e.message}"
  exit 1
end

# Test transcription with different models
models_to_try = [
  'whisper-large-v3-turbo',
  'distil-whisper-large-v3-en',
  'whisper-large-v3'
]

models_to_try.each do |model|
  puts "\n🎤 Testing transcription with model: #{model}"
  puts "Response format: json"

  begin
    result = service.transcribe(audio_file, {
      model: model,
      response_format: 'json',
      temperature: 0
    })
  
    puts "✅ Transcription successful with #{model}!"
    puts "📝 Text preview: #{result[:text][0..100]}..."
    puts "⏱️  Duration: #{result[:duration]} seconds"
    puts "🌐 Language: #{result[:language]}"
    puts "📊 Segments: #{result[:segments]&.length || 0}"
    break # Success, exit loop
    
  rescue => e
    puts "❌ Transcription failed with #{model}: #{e.message}"
    puts "🔍 Error details:"
    puts "  Class: #{e.class}"
    puts "  Message: #{e.message}"
    if model == models_to_try.last
      puts "  Backtrace:"
      e.backtrace.first(5).each { |line| puts "    #{line}" }
    end
  end
end

puts "\n" + "=" * 50
puts "🏁 Debug complete"