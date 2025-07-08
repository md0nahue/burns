#!/usr/bin/env ruby

require_relative 'lib/services/local_video_service'
require_relative 'lib/services/s3_service'
require_relative 'config/services'

puts "🔧 Completing vibe3 video with local fallback..."

# Initialize services
local_video_service = LocalVideoService.new

begin
  # Try to complete with local processing of segments from S3
  puts "🎬 Attempting to complete vibe3 video with local processing..."
  
  result = local_video_service.complete_video_from_segments('vibe3', [])
  
  if result && result[:success]
    puts "✅ Video completion successful!"
    puts "📹 Video file: #{result[:video_path]}"
    puts "⏱️  Duration: #{result[:duration]} seconds"
    puts "🎬 Segments: #{result[:segments_count]}"
  else
    puts "❌ Video completion failed: #{result[:error] if result}"
  end

rescue => e
  puts "❌ Error during video completion: #{e.message}"
  puts "🔍 Stack trace: #{e.backtrace.first(5).join("\n")}"
end