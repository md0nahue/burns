#!/usr/bin/env ruby

require_relative 'lib/pipeline/video_generator'
require_relative 'config/services'

# ⚠️  DEPRECATED - DO NOT USE THIS SCRIPT FOR PRODUCTION ⚠️
# This demo script is outdated and contains bugs. 
# Use process_audio_pipeline.rb instead for actual audio processing.
# 
# This file is kept for reference only and may not work correctly.
# The current, working pipeline is in process_audio_pipeline.rb
puts "🎬 Burns - Complete Ken Burns Video Generation Pipeline Demo"
puts "=" * 60

# Initialize video generator
generator = VideoGenerator.new

# Demo options
demo_options = {
  resolution: '1080p',
  fps: 24,
  test_mode: true
}

# Check if audio file is provided as argument
audio_file = ARGV[0]

if audio_file && File.exist?(audio_file)
  puts "📁 Using provided audio file: #{audio_file}"
else
  puts "❌ No valid audio file provided"
  puts "Usage: ruby demo_complete_pipeline.rb <audio_file_path>"
  puts "Example: ruby demo_complete_pipeline.rb sample_audio.mp3"
  exit 1
end

puts "\n🚀 Starting complete pipeline demo..."
puts "  📁 Audio file: #{audio_file}"
puts "  ⚙️  Options: #{demo_options}"

# Step 1: Generate complete video
puts "\n" + "=" * 50
puts "STEP 1: Complete Video Generation"
puts "=" * 50

result = generator.generate_video(audio_file, demo_options)

if result[:success]
  puts "\n✅ Complete pipeline demo successful!"
  puts "  🆔 Project ID: #{result[:project_id]}"
  puts "  📹 Video URL: #{result[:video_url]}"
  puts "  ⏱️  Duration: #{result[:duration]} seconds"
  puts "  📐 Resolution: #{result[:resolution]}"
  puts "  🎬 Segments: #{result[:segments_count]}"
  puts "  🖼️  Images: #{result[:images_generated]}"
  puts "  📅 Generated: #{result[:generated_at]}"
else
  puts "\n❌ Pipeline demo failed: #{result[:error]}"
  exit 1
end

# Step 2: Get project status
puts "\n" + "=" * 50
puts "STEP 2: Project Status Check"
puts "=" * 50

status = generator.get_project_status(result[:project_id])

if status[:success]
  puts "✅ Project status retrieved successfully"
  puts "  📅 Created: #{status[:created_at]}"
  puts "  🔄 Status: #{status[:status]}"
  puts "  ⏱️  Duration: #{status[:duration]} seconds"
  puts "  📝 Segments: #{status[:segments_count]}"
  puts "  🖼️  Images: #{status[:total_images]}"
  puts "  🌐 Language: #{status[:language]}"
else
  puts "❌ Failed to get project status: #{status[:error]}"
end

# Step 3: List all projects
puts "\n" + "=" * 50
puts "STEP 3: List All Projects"
puts "=" * 50

projects = generator.list_projects

if projects[:success]
  puts "✅ Projects listed successfully"
  if projects[:projects].empty?
    puts "  📋 No projects found"
  else
    puts "  📋 Found #{projects[:projects].length} projects:"
    projects[:projects].each_with_index do |project, index|
      puts "    #{index + 1}. #{project[:project_id]} (#{project[:created_at]})"
    end
  end
else
  puts "❌ Failed to list projects: #{projects[:error]}"
end

# Step 4: Optional cleanup (commented out for safety)
puts "\n" + "=" * 50
puts "STEP 4: Cleanup (Optional)"
puts "=" * 50

puts "🧹 Project cleanup is available but disabled for demo safety"
puts "  To clean up this project, uncomment the following line:"
puts "  generator.cleanup_project('#{result[:project_id]}')"

# Uncomment the line below to clean up the demo project
# cleanup_result = generator.cleanup_project(result[:project_id])
# if cleanup_result[:success]
#   puts "✅ Project cleanup completed"
#   puts "  🗑️  Deleted files: #{cleanup_result[:deleted_files]}"
# else
#   puts "❌ Project cleanup failed: #{cleanup_result[:error]}"
# end

puts "\n" + "=" * 60
puts "🎉 Demo completed successfully!"
puts "📹 Your Ken Burns video is ready at: #{result[:video_url]}"
puts "=" * 60 