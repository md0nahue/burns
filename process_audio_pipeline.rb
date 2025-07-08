#!/usr/bin/env ruby

require_relative 'lib/pipeline/video_generator'
require_relative 'config/services'
require 'fileutils'
require 'time'

# 🎬 MAIN AUDIO PROCESSING PIPELINE - USE THIS SCRIPT FOR PRODUCTION
# This is the current, up-to-date pipeline for processing audio files into Ken Burns videos
# 
# Usage: ruby process_audio_pipeline.rb <audio_file_path>
# Example: ruby process_audio_pipeline.rb my_audio.mp3
# Example: ruby process_audio_pipeline.rb sad.m4a

# Setup logging
FileUtils.mkdir_p('logs')
timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
log_file_path = "logs/pipeline_#{timestamp}.log"
log_file = File.open(log_file_path, 'a')

# Tee STDOUT and STDERR to log file
class TeeIO
  def initialize(*targets)
    @targets = targets
  end
  def write(*args)
    @targets.each { |t| t.write(*args) }
  end
  def flush; @targets.each(&:flush); end
end
$stdout = TeeIO.new($stdout, log_file)
$stderr = TeeIO.new($stderr, log_file)

# Log pipeline start time
pipeline_start = Time.now
puts "\n=== Pipeline started at: #{pipeline_start.iso8601} ===\n"

puts "🎬 Burns - Audio to Ken Burns Video Pipeline"
puts "=" * 60

# Get audio file from command line argument
audio_file = ARGV[0]

# Validate input
if audio_file.nil?
  puts "❌ Error: No audio file specified"
  puts "Usage: ruby process_audio_pipeline.rb <audio_file_path>"
  puts "Example: ruby process_audio_pipeline.rb sad.m4a"
  exit 1
end

# Validate audio file exists
unless File.exist?(audio_file)
  puts "❌ Error: Audio file '#{audio_file}' not found"
  puts "Please ensure the file exists and try again."
  exit 1
end

# Check if completed video already exists locally
audio_basename = File.basename(audio_file, File.extname(audio_file))
completed_video_path = "completed/#{audio_basename}_ken_burns_video.mp4"

if File.exist?(completed_video_path)
  puts "✅ Found existing completed video: #{completed_video_path}"
  puts "📹 Video file size: #{(File.size(completed_video_path) / 1024.0 / 1024.0).round(2)} MB"
  puts "📅 Last modified: #{File.mtime(completed_video_path)}"
  
  # Test if video file is playable
  puts "🎬 Testing video playback..."
  test_result = system("ffprobe -v quiet -print_format json -show_format -show_streams '#{completed_video_path}' > /dev/null 2>&1")
  
  if test_result
    puts "✅ Video file is valid and playable!"
    puts "🎉 Using existing completed video instead of regenerating."
    puts "📺 Video path: #{completed_video_path}"
    exit 0
  else
    puts "⚠️  Video file appears to be corrupted or invalid."
    puts "🔄 Will regenerate the video..."
  end
else
  # Check if video exists in S3 and try to download it
  puts "🔍 Checking for existing video in S3..."
  project_id = audio_basename
  
  # Check if final video exists in S3
  video_s3_key = "projects/#{project_id}/final_video.mp4"
  if system("aws s3 ls s3://burns-videos/#{video_s3_key} > /dev/null 2>&1")
    puts "📥 Found existing video in S3, downloading..."
    FileUtils.mkdir_p('completed')
    
    download_result = system("aws s3 cp s3://burns-videos/#{video_s3_key} '#{completed_video_path}' 2>/dev/null")
    if download_result && File.exist?(completed_video_path)
      puts "✅ Downloaded existing video from S3!"
      puts "📹 Video file size: #{(File.size(completed_video_path) / 1024.0 / 1024.0).round(2)} MB"
      puts "📺 Video path: #{completed_video_path}"
      exit 0
    else
      puts "⚠️  Failed to download video from S3, will regenerate..."
    end
  else
    puts "🆕 No existing video found in S3, generating new video..."
  end
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
  image_duration: 4.0, # Seconds per image (longer for smoother motion)
  transition_duration: 1.0, # Seconds for transitions
  zoom_factor: 1.4, # More pronounced zoom effect for better Ken Burns
  pan_speed: 0.3, # Slower panning for smoother motion
  cache_images: true, # Enable image caching to avoid duplicate API requests
  cache_transcription: true, # Enable transcription caching since it works
  cache_analysis: true, # Enable content analysis caching for speed
  force: false # Don't force regeneration - use caching for speed
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
puts "  💾 Image Caching: #{generation_options[:cache_images]}"
puts "  💾 Transcription Caching: #{generation_options[:cache_transcription]}"
puts "  💾 Analysis Caching: #{generation_options[:cache_analysis]}"
puts "  🔄 Force Refresh: #{generation_options[:force]}"

puts "\n" + "=" * 60
puts "🎬 STARTING KEN BURNS VIDEO GENERATION"
puts "=" * 60

# Step 1: Generate complete video
step_start = Time.now
puts "\n📝 Step 1: Processing audio and transcription..."
puts "🎵 Transcribing audio content..."
puts "⏱️  Step 1 started at: #{step_start.strftime('%H:%M:%S')}"

begin
  result = generator.generate_video(audio_file, generation_options)
rescue => e
  puts "\n❌ Pipeline failed with error: #{e.message}"
  puts "🔧 Debug information:"
  puts "  • Audio file: #{audio_file}"
  puts "  • File exists: #{File.exist?(audio_file)}"
  puts "  • File size: #{File.size(audio_file)} bytes"
  puts "  • Error class: #{e.class}"
  puts "  • Backtrace: #{e.backtrace.first(5).join("\n    ")}"
  exit 1
end

step_end = Time.now
puts "⏱️  Step 1 completed at: #{step_end.strftime('%H:%M:%S')}"
puts "⏱️  Step 1 runtime: #{(step_end - step_start).round(2)} seconds"

if result[:success]
  puts "\n" + "=" * 60
  puts "✅ KEN BURNS VIDEO GENERATION COMPLETED SUCCESSFULLY!"
  puts "=" * 60
  
  puts "\n📊 Generation Results:"
  puts "  🆔 Project ID: #{result[:project_id]}"
  puts "  📹 Video URL: #{result[:video_url]}"
  puts "  📁 Local Video: #{result[:local_video_path]}"
  puts "  ⏱️  Duration: #{result[:duration]} seconds"
  puts "  📐 Resolution: #{result[:resolution]}"
  puts "  🎬 FPS: #{result[:fps]}"
  puts "  📝 Segments: #{result[:segments_count]}"
  puts "  🖼️  Images Generated: #{result[:images_generated]}"
  puts "  📅 Generated: #{result[:generated_at]}"
  
  puts "\n🎉 Your beautiful Ken Burns video is ready!"
  puts "📺 Watch it at: #{result[:video_url]}"
  
  # Download the final video to completed directory
  if result[:video_url] && !result[:video_url].empty?
    download_start = Time.now
    puts "\n📥 Downloading final video to completed directory..."
    puts "⏱️  Download started at: #{download_start.strftime('%H:%M:%S')}"
    FileUtils.mkdir_p('completed')
    
    # Extract S3 key from URL or use result data
    video_s3_key = result[:video_s3_key] || "projects/#{result[:project_id]}/final_video.mp4"
    
    # Debug S3 access
    puts "🔍 Checking S3 access..."
    puts "    • S3 Key: #{video_s3_key}"
    puts "    • Target path: #{completed_video_path}"
    
    # Check if file exists in S3 first
    s3_check_command = "aws s3 ls s3://burns-videos/#{video_s3_key}"
    puts "    • Checking S3: #{s3_check_command}"
    
    if system("#{s3_check_command} > /dev/null 2>&1")
      puts "    ✅ File exists in S3"
      
      download_command = "aws s3 cp s3://burns-videos/#{video_s3_key} '#{completed_video_path}'"
      puts "    💾 Downloading: #{download_command}"
      
      if system("#{download_command}")
        download_end = Time.now
        puts "    ✅ Video downloaded successfully!"
        puts "    📁 Local path: #{completed_video_path}"
        puts "    📹 File size: #{(File.size(completed_video_path) / 1024.0 / 1024.0).round(2)} MB"
        puts "    ⏱️  Download completed at: #{download_end.strftime('%H:%M:%S')}"
        puts "    ⏱️  Download runtime: #{(download_end - download_start).round(2)} seconds"
      else
        puts "    ❌ Failed to download video from S3"
        puts "    🔗 Video is still available at: #{result[:video_url]}"
        puts "    🔧 Debug: Check AWS credentials and network connectivity"
      end
    else
      puts "    ❌ File does not exist in S3 at key: #{video_s3_key}"
      puts "    🔗 Video is still available at: #{result[:video_url]}"
      puts "    🔧 Debug: Check if the S3 key is correct"
    end
  else
    puts "    ⚠️  No video URL provided in result"
  end
  
  # Step 2: Get detailed project status
  puts "\n" + "=" * 50
  puts "📊 PROJECT STATUS DETAILS"
  puts "=" * 50
  
  begin
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
  rescue => e
    puts "❌ Error getting project status: #{e.message}"
  end
  
  puts "\n" + "=" * 60
  puts "🎬 KEN BURNS VIDEO READY FOR VIEWING!"
  puts "=" * 60
  puts "📹 Video URL: #{result[:video_url]}"
  puts "🆔 Project ID: #{result[:project_id]}"
  puts "⏱️  Duration: #{result[:duration]} seconds"
  puts "📐 Quality: #{result[:resolution]} at #{result[:fps]} FPS"
  puts "🎭 Features: Ken Burns effect with smooth transitions"
  puts "💾 Caching: Images and analysis cached for future runs"
  puts "=" * 60
  
else
  puts "\n" + "=" * 60
  puts "❌ VIDEO GENERATION FAILED"
  puts "=" * 60
  puts "Error: #{result[:error]}"
  puts "Project ID: #{result[:project_id]}" if result[:project_id]
  puts "\n🔧 Troubleshooting tips:"
  puts "  • Check your API keys are properly configured"
  puts "  • Ensure AWS services are accessible"
  puts "  • Verify the audio file is in a supported format"
  puts "  • Check network connectivity"
  puts "  • Try running with test_mode: true for debugging"
  puts "=" * 60
  exit 1
end

# Note: Individual step timing is now integrated above

# Log pipeline end time and total runtime
pipeline_end = Time.now
puts "\n=== Pipeline ended at: #{pipeline_end.iso8601} ==="
puts "⏱️  Total pipeline runtime: #{(pipeline_end - pipeline_start).round(2)} seconds\n"
log_file.close

puts "\n🎉 Pipeline completed successfully!"
puts "📹 Your Ken Burns video with custom visuals is ready!"
puts "💾 Cached data saved for faster future runs"
puts "=" * 60 