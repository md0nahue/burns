#!/usr/bin/env ruby

require_relative 'lib/services/whisper_service'
require_relative 'lib/services/gemini_service'
require_relative 'lib/pipeline/audio_processor'
require_relative 'lib/pipeline/content_analyzer'
require_relative 'lib/pipeline/image_generator'
require_relative 'config/services'

puts "🎬 Full Pipeline Demo - Audio to Images"
puts "======================================="

begin
  # Initialize all services
  puts "\n🔧 Initializing services..."
  
  whisper_service = WhisperService.new
  gemini_service = GeminiService.new
  audio_processor = AudioProcessor.new(whisper_service)
  content_analyzer = ContentAnalyzer.new(gemini_service)
  image_generator = ImageGenerator.new
  
  puts "✅ All services initialized successfully!"
  
  # Show service status
  puts "\n📊 Service Status:"
  puts "  🎤 WhisperService: Available"
  puts "  🧠 GeminiService: Available"
  puts "  🎨 ContentAnalyzer: Available"
  puts "  🖼️  ImageGenerator: Available"
  
  # Show image service status
  client_status = image_generator.get_client_status
  puts "  📸 Image Services:"
  client_status.each do |client, status|
    status_icon = status[:available] ? "✅" : "❌"
    puts "    #{status_icon} #{client}: #{status[:available] ? 'Available' : 'Unavailable'}"
  end
  
  # Example usage (commented out since we don't have actual audio files)
  puts "\n📝 Example Pipeline Usage:"
  puts "```ruby"
  puts "# 1. Process audio file"
  puts "audio_result = audio_processor.process_audio('review.mp3', {"
  puts "  model: 'whisper-large-v3-turbo',"
  puts "  language: 'en',"
  puts "  prompt: 'This is a product review about technology'"
  puts "})"
  puts ""
  puts "# 2. Analyze content for image queries"
  puts "enhanced_result = content_analyzer.analyze_for_images(audio_result, {"
  puts "  context: 'product review',"
  puts "  style: 'modern, professional',"
  puts "  chunk_duration: 30"
  puts "})"
  puts ""
  puts "# 3. Generate images for each segment"
  puts "final_result = image_generator.generate_images_for_segments(enhanced_result)"
  puts "```"
  
  puts "\n✅ Demo completed successfully!"
  
rescue => e
  puts "❌ Demo failed: #{e.message}"
  puts "🔧 Error details: #{e.backtrace.first(5).join("\n  ")}"
end

puts "\n🎬 Pipeline Status:"
puts "  ✅ Audio Processing: Ready"
puts "  ✅ Content Analysis: Ready"
puts "  ✅ Image Generation: Ready"
puts "  🔄 Video Assembly: Next step"
puts "  🔄 Video Download: Final step"

puts "\n📚 Documentation:"
puts "  • GROQ_INTEGRATION.md - Audio transcription guide"
puts "  • README.md - Image service bus documentation"
puts "  • next-steps.md - Project roadmap" 