#!/usr/bin/env ruby

require_relative 'lib/services/whisper_service'
require_relative 'lib/pipeline/audio_processor'

puts "🎤 Audio Processing Pipeline Demo"
puts "================================"

begin
  # Initialize services
  whisper_service = WhisperService.new
  audio_processor = AudioProcessor.new(whisper_service)
  
  puts "\n✅ Services initialized successfully!"
  
  # Show available models
  puts "\n📋 Available Whisper Models:"
  whisper_service.available_models.each do |model, info|
    puts "  • #{model}: $#{info[:cost_per_hour]}/hour (#{info[:language_support]})"
  end
  
  # Example usage (commented out since we don't have actual audio files)
  puts "\n📝 Example Usage:"
  puts "```ruby"
  puts "# Process an audio file"
  puts "result = audio_processor.process_audio('path/to/audio.mp3', {"
  puts "  model: 'whisper-large-v3-turbo',"
  puts "  language: 'en',"
  puts "  prompt: 'This is a product review about technology'"
  puts "})"
  puts ""
  puts "# Access structured data"
  puts "puts \"Duration: #{result[:duration]} seconds\""
  puts "puts \"Word count: #{result[:word_count]}\""
  puts "puts \"Segments: #{result[:segments].length}\""
  puts ""
  puts "# Process each segment"
  puts "result[:segments].each do |segment|"
  puts "  puts \"#{segment[:start_time]}s - #{segment[:end_time]}s: #{segment[:text]}\""
  puts "end"
  puts "```"
  
  # Show what the structured output looks like
  puts "\n📊 Structured Output Format:"
  puts "```ruby"
  puts "{"
  puts "  audio_file: 'path/to/audio.mp3',"
  puts "  metadata: { filename: 'audio.mp3', file_size: 1234567, ... },"
  puts "  duration: 120.5,"
  puts "  word_count: 450,"
  puts "  segments: ["
  puts "    {"
  puts "      id: 0,"
  puts "      start_time: 0.0,"
  puts "      end_time: 10.5,"
  puts "      text: 'Hello, this is a test...',"
  puts "      confidence: -0.097,"
  puts "      no_speech_prob: 0.012,"
  puts "      compression_ratio: 1.66,"
  puts "      words: [...]"
  puts "    }"
  puts "  ],"
  puts "  quality_metrics: {"
  puts "    average_confidence: -0.097,"
  puts "    low_confidence_segments: 0,"
  puts "    high_noise_segments: 0,"
  puts "    total_segments: 12"
  puts "  }"
  puts "}"
  puts "```"
  
  puts "\n🎯 Quality Metrics Explained:"
  puts "  • average_confidence: Higher (closer to 0) = better transcription"
  puts "  • low_confidence_segments: Segments with confidence < -0.5"
  puts "  • high_noise_segments: Segments with noise probability > 0.5"
  puts "  • compression_ratio: Normal speech = ~1.6, unusual = potential issues"
  
  puts "\n🔧 File Validation:"
  puts "The processor validates:"
  puts "  • File exists and is readable"
  puts "  • File size ≤ 25MB (free tier limit)"
  puts "  • Supported audio formats: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm"
  
  puts "\n💡 Tips for Best Results:"
  puts "  • Use 'whisper-large-v3-turbo' for best price/performance"
  puts "  • Provide context in the prompt parameter"
  puts "  • Use 'verbose_json' format for detailed timestamps"
  puts "  • Check quality_metrics to assess transcription quality"
  
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts "\nTo fix this:"
  puts "1. Set your GROQ API key: export GROQ_API_KEY='your_key_here'"
  puts "2. Get your key from: https://console.groq.com/keys"
  puts "3. Install required gems: gem install mime-types"
end

puts "\n🚀 Next Steps:"
puts "1. Get a GROQ API key from https://console.groq.com/keys"
puts "2. Set the environment variable: export GROQ_API_KEY='your_key'"
puts "3. Test with an audio file: ruby demo_audio_processing.rb"
puts "4. Integrate with your image generation pipeline" 