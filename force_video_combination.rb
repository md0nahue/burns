#!/usr/bin/env ruby

require_relative 'config/services'
require_relative 'lib/services/s3_service'
require_relative 'lib/services/lambda_service'
require 'json'

project_id = 'bernie'

puts "🔧 Force Video Combination for #{project_id}"
puts "============================================================"

begin
  # Initialize services
  s3_service = S3Service.new
  lambda_service = LambdaService.new
  
  puts "📋 Getting project manifest..."
  manifest_result = s3_service.get_project_manifest(project_id)
  
  unless manifest_result[:success]
    puts "❌ Failed to get project manifest: #{manifest_result[:error]}"
    exit 1
  end
  
  manifest = manifest_result[:manifest]
  segments = manifest['segments']
  
  puts "📊 Total segments in manifest: #{segments.length}"
  
  # Filter segments that have images and are processed
  valid_segments = segments.select do |segment|
    segment['generated_images'] && segment['generated_images'].length > 0
  end
  
  puts "📊 Valid segments with images: #{valid_segments.length}"
  
  if valid_segments.length == 0
    puts "❌ No valid segments found"
    exit 1
  end
  
  # Manually create segment results for Lambda combination
  segment_results = valid_segments.map do |segment|
    {
      segment_id: segment['id'].to_s,
      segment_s3_key: "segments/#{project_id}/#{segment['id']}_segment.mp4",
      duration: segment['end_time'] - segment['start_time'],
      start_time: segment['start_time'],
      end_time: segment['end_time']
    }
  end
  
  puts "🎬 Triggering video combination with #{segment_results.length} segments..."
  
  # Create combination payload for Lambda
  combination_payload = {
    project_id: project_id,
    segment_results: segment_results,
    options: {
      resolution: '1080p',
      fps: 24,
      has_audio: true
    }
  }
  
  puts "📤 Sending combination request to Lambda..."
  video_result = lambda_service.send(:invoke_lambda_function, combination_payload)
  
  if video_result[:success]
    puts "✅ Video combination successful!"
    puts "📹 Video S3 Key: #{video_result[:video_s3_key]}"
    puts "⏱️  Duration: #{video_result[:duration]} seconds"
    puts "🎬 FPS: #{video_result[:fps]}"
    puts "📐 Resolution: #{video_result[:resolution]}"
    
    # Download the video
    puts "📥 Downloading final video..."
    require 'fileutils'
    FileUtils.mkdir_p('completed')
    
    local_path = "completed/#{project_id}_ken_burns_video.mp4"
    download_result = s3_service.download_video(video_result[:video_s3_key], local_path)
    
    if download_result[:success]
      puts "✅ Video downloaded successfully!"
      puts "📁 Video path: #{local_path}"
      puts "📊 File size: #{(File.size(local_path) / 1024.0 / 1024.0).round(2)} MB"
    else
      puts "❌ Failed to download video: #{download_result[:error]}"
    end
    
  else
    puts "❌ Video combination failed: #{video_result[:error]}"
    puts "📋 Available segment results:"
    segment_results.each_with_index do |seg, idx|
      puts "  #{idx + 1}. Segment #{seg[:segment_id]}: #{seg[:duration].round(2)}s"
    end
  end
  
rescue => e
  puts "❌ Error in force video combination: #{e.message}"
  puts "🔧 Backtrace: #{e.backtrace.first(5)}"
end

puts "\n🎯 Force combination complete!"