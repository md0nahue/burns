#!/usr/bin/env ruby

require_relative 'lib/services/whisper_service'

# Test the WhisperService
puts "🎤 WhisperService Test"
puts "======================"

begin
  # Initialize the service
  whisper = WhisperService.new
  
  # Show available models
  puts "\n📋 Available Models:"
  whisper.available_models.each do |model, info|
    puts "  #{model}:"
    puts "    Cost: $#{info[:cost_per_hour]}/hour"
    puts "    Language: #{info[:language_support]}"
    puts "    Speed: #{info[:speed_factor]}x real-time"
    puts "    Error Rate: #{info[:word_error_rate]}"
    puts ""
  end

  # Example usage (commented out since we don't have actual audio files)
  puts "\n📝 Example Usage:"
  puts "```ruby"
  puts "# Transcribe an audio file"
  puts "result = whisper.transcribe('path/to/audio.mp3', {"
  puts "  model: 'whisper-large-v3-turbo',"
  puts "  language: 'en',"
  puts "  response_format: 'verbose_json',"
  puts "  timestamp_granularities: ['segment', 'word']"
  puts "})"
  puts ""
  puts "# Translate audio to English"
  puts "translation = whisper.translate('path/to/foreign_audio.mp3', {"
  puts "  model: 'whisper-large-v3',"
  puts "  prompt: 'This is a technical discussion about software development'"
  puts "})"
  puts "```"
  
  puts "\n✅ WhisperService initialized successfully!"
  puts "   Make sure to set GROQ_API_KEY environment variable"
  
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts "\nTo fix this:"
  puts "1. Set your GROQ API key: export GROQ_API_KEY='your_key_here'"
  puts "2. Get your key from: https://console.groq.com/keys"
end

puts "\n🔧 File Validation:"
puts "The service validates:"
puts "  - File exists"
puts "  - File size ≤ 25MB (free tier)"
puts "  - Supported formats: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm"

puts "\n📊 Response Formats:"
puts "  - 'json': Basic transcription"
puts "  - 'verbose_json': Detailed with timestamps and metadata"
puts "  - 'text': Plain text only"

puts "\n🎯 Recommended Models:"
puts "  - whisper-large-v3-turbo: Best price/performance, multilingual"
puts "  - distil-whisper-large-v3-en: Fastest, English only"
puts "  - whisper-large-v3: Highest accuracy, multilingual + translation" 