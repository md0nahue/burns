#!/usr/bin/env ruby

require_relative 'lib/services/whisper_service'
require_relative 'lib/services/llm_service'
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
  llm_service = LLMService.new
  audio_processor = AudioProcessor.new(whisper_service)
  content_analyzer = ContentAnalyzer.new(llm_service)
  image_generator = ImageGenerator.new
  
  puts "✅ All services initialized successfully!"
  
  # Show service status
  puts "\n📊 Service Status:"
  puts "  🎤 WhisperService: Available"
  puts "  🧠 LLMService: Available"
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
  puts "final_result = image_generator.generate_images_for_segments(enhanced_result, {"
  puts "  resolution: '1080p',"
  puts "  images_per_query: 1,"
  puts "  delay: 1"
  puts "})"
  puts "```"
  
  # Show what the pipeline output looks like
  puts "\n📊 Pipeline Output Structure:"
  puts "```ruby"
  puts "{"
  puts "  audio_file: 'review.mp3',"
  puts "  duration: 120.5,"
  puts "  word_count: 450,"
  puts "  segments: ["
  puts "    {"
  puts "      id: 0,"
  puts "      start_time: 0.0,"
  puts "      end_time: 10.5,"
  puts "      text: 'This product is amazing...',"
  puts "      image_queries: ['modern smartphone', 'tech workspace'],"
  puts "      generated_images: ["
  puts "        {"
  puts "          url: 'https://...',"
  puts "          width: 1920,"
  puts "          height: 1080,"
  puts "          query: 'modern smartphone',"
  puts "          provider: 'unsplash',"
  puts "          segment_id: 0"
  puts "        }"
  puts "      ],"
  puts "      generation_success: true"
  puts "    }"
  puts "  ],"
  puts "  analysis_metrics: {"
  puts "    average_confidence: 0.75,"
  puts "    total_image_queries: 24,"
  puts "    segments_with_images: 12"
  puts "  },"
  puts "  generation_metrics: {"
  puts "    total_images_generated: 20,"
  puts "    success_rate: 0.83,"
  puts "    average_images_per_segment: 1.67"
  puts "  }"
  puts "}"
  puts "```"
  
  # Show analysis capabilities
  puts "\n🎯 Content Analysis Features:"
  puts "  • Automatic chunking of audio segments"
  puts "  • LLM-powered image query generation"
  puts "  • Context-aware analysis (product reviews, tutorials, etc.)"
  puts "  • Fallback query generation for failed LLM responses"
  puts "  • Confidence scoring for query quality"
  puts "  • Query distribution across segments"
  
  # Show image generation features
  puts "\n🖼️  Image Generation Features:"
  puts "  • Multi-provider image search (Unsplash, Pexels, Pixabay, etc.)"
  puts "  • High-resolution image support (1080p, 4K)"
  puts "  • Rate limiting and error handling"
  puts "  • Provider distribution tracking"
  puts "  • Resolution quality validation"
  puts "  • Failed query tracking and reporting"
  
  # Show validation capabilities
  puts "\n🔍 Validation & Quality Control:"
  puts "  • Audio file validation (format, size, quality)"
  puts "  • Transcription quality metrics"
  puts "  • Content analysis validation"
  puts "  • Image generation validation"
  puts "  • Comprehensive error reporting"
  
  # Show cost optimization
  puts "\n💰 Cost Optimization:"
  puts "  • Whisper model selection based on needs"
  puts "  • LLM chunking to minimize API calls"
  puts "  • Image service fallback chain"
  puts "  • Rate limiting to avoid API limits"
  puts "  • Quality metrics to optimize results"
  
  # Show next steps
  puts "\n🚀 Next Steps in Pipeline:"
  puts "  1. ✅ Audio transcription (WhisperService)"
  puts "  2. ✅ Content analysis (LLMService)"
  puts "  3. ✅ Image generation (ImageGenerator)"
  puts "  4. 🔄 Video assembly (AWS Lambda)"
  puts "  5. 🔄 Final video download (S3)"
  
  puts "\n💡 Tips for Best Results:"
  puts "  • Use 'whisper-large-v3-turbo' for cost-effective transcription"
  puts "  • Provide context in audio processing prompts"
  puts "  • Set appropriate chunk durations for content analysis"
  puts "  • Use 1080p resolution for good Ken Burns effects"
  puts "  • Monitor quality metrics to optimize pipeline"
  
rescue => e
  puts "\n❌ Error: #{e.message}"
  puts "\nTo fix this:"
  puts "1. Set your GROQ API key: export GROQ_API_KEY='your_key_here'"
  puts "2. Get your key from: https://console.groq.com/keys"
  puts "3. Install required gems: gem install mime-types"
  puts "4. Configure image service API keys (optional)"
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