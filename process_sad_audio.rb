#!/usr/bin/env ruby

require_relative 'lib/pipeline/video_generator'
require_relative 'config/services'

# Script to process sad.m4a through the complete Ken Burns video generation pipeline
puts "🎬 Burns - Processing sad.m4a for Ken Burns Video Generation"
puts "=" * 70

# Configuration
audio_file = 'sad.m4a'

# Validate audio file exists
unless File.exist?(audio_file)
  puts "❌ Error: Audio file '#{audio_file}' not found in current directory"
  puts "Please ensure the file exists and try again."
  exit 1
end

puts "✅ Found audio file: #{audio_file}"
puts "📊 File size: #{(File.size(audio_file) / 1024.0 / 1024.0).round(2)} MB"

# Initialize video generator
puts "\n🚀 Initializing video generator..."
generator = VideoGenerator.new

# Generation options optimized for Ken Burns effect
generation_options = {
  resolution: '1080p',
  fps: 24,
  test_mode: false, # Set to false for production
  ken_burns_effect: true,
  smooth_transitions: true,
  image_duration: 3.0, # Seconds per image
  transition_duration: 1.0, # Seconds for transitions
  zoom_factor: 1.2, # Subtle zoom effect
  pan_speed: 0.5 # Slow panning
}

puts "\n⚙️  Generation options:"
puts "  📐 Resolution: #{generation_options[:resolution]}"
puts "  🎬 FPS: #{generation_options[:fps]}"
puts "  🎭 Ken Burns Effect: #{generation_options[:ken_burns_effect]}"
puts "  🔄 Smooth Transitions: #{generation_options[:smooth_transitions]}"
puts "  ⏱️  Image Duration: #{generation_options[:image_duration]}s"
puts "  🌊 Transition Duration: #{generation_options[:transition_duration]}s"
puts "  🔍 Zoom Factor: #{generation_options[:zoom_factor]}x"
puts "  📹 Pan Speed: #{generation_options[:pan_speed]}"

puts "\n" + "=" * 70
puts "🎬 STARTING KEN BURNS VIDEO GENERATION"
puts "=" * 70

# Step 1: Generate complete video
puts "\n📝 Step 1: Processing audio and transcription..."
puts "🎵 Transcribing audio content..."

result = generator.generate_video(audio_file, generation_options)

if result[:success]
  puts "\n" + "=" * 70
  puts "✅ KEN BURNS VIDEO GENERATION COMPLETED SUCCESSFULLY!"
  puts "=" * 70
  
  puts "\n📊 Generation Results:"
  puts "  🆔 Project ID: #{result[:project_id]}"
  puts "  📹 Video URL: #{result[:video_url]}"
  puts "  ⏱️  Duration: #{result[:duration]} seconds"
  puts "  📐 Resolution: #{result[:resolution]}"
  puts "  🎬 FPS: #{result[:fps]}"
  puts "  📝 Segments: #{result[:segments_count]}"
  puts "  🖼️  Images Generated: #{result[:images_generated]}"
  puts "  📅 Generated: #{result[:generated_at]}"
  
  puts "\n🎉 Your beautiful Ken Burns video is ready!"
  puts "📺 Watch it at: #{result[:video_url]}"
  
  # Step 2: Get detailed project status
  puts "\n" + "=" * 50
  puts "📊 PROJECT STATUS DETAILS"
  puts "=" * 50
  
  status = generator.get_project_status(result[:project_id])
  
  if status[:success]
    puts "✅ Project status retrieved successfully"
    puts "  📅 Created: #{status[:created_at]}"
    puts "  🔄 Status: #{status[:status]}"
    puts "  ⏱️  Duration: #{status[:duration]} seconds"
    puts "  📝 Segments: #{status[:segments_count]}"
    puts "  🖼️  Total Images: #{status[:total_images]}"
    puts "  🌐 Language: #{status[:language]}"
  else
    puts "❌ Failed to get project status: #{status[:error]}"
  end
  
  puts "\n" + "=" * 70
  puts "🎬 KEN BURNS VIDEO READY FOR VIEWING!"
  puts "=" * 70
  puts "📹 Video URL: #{result[:video_url]}"
  puts "🆔 Project ID: #{result[:project_id]}"
  puts "⏱️  Duration: #{result[:duration]} seconds"
  puts "📐 Quality: #{result[:resolution]} at #{result[:fps]} FPS"
  puts "🎭 Features: Ken Burns effect with smooth transitions"
  puts "=" * 70
  
else
  puts "\n" + "=" * 70
  puts "❌ VIDEO GENERATION FAILED"
  puts "=" * 70
  puts "Error: #{result[:error]}"
  puts "Project ID: #{result[:project_id]}" if result[:project_id]
  puts "\n🔧 Troubleshooting tips:"
  puts "  • Check your API keys are properly configured"
  puts "  • Ensure AWS services are accessible"
  puts "  • Verify the audio file is in a supported format"
  puts "  • Check network connectivity"
  puts "=" * 70
  exit 1
end

puts "\n🎉 Script completed successfully!"
puts "📹 Your Ken Burns video with custom visuals is ready!"
puts "=" * 70 