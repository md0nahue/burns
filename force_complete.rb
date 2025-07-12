#!/usr/bin/env ruby

# Universal force completion script for any project
# Usage: ruby force_complete.rb <project_id>
# Example: ruby force_complete.rb first

require_relative 'lib/services/s3_service'
require_relative 'lib/services/local_video_service'
require 'fileutils'
require 'json'

if ARGV.empty?
  puts "❌ Usage: #{$0} <project_id>"
  puts "Example: #{$0} first"
  exit 1
end

project_id = ARGV[0]
puts "🔧 Force completing #{project_id} video with all available segments..."

# Initialize services
s3_service = S3Service.new
local_video_service = LocalVideoService.new

begin
  # Get project manifest
  puts "📥 Getting project manifest..."
  manifest_result = s3_service.get_project_manifest(project_id)
  
  unless manifest_result[:success]
    puts "❌ Failed to get manifest: #{manifest_result[:error]}"
    exit 1
  end
  
  manifest = manifest_result[:manifest]
  puts "✅ Manifest loaded: #{manifest['segments'].length} segments total"
  
  # Download all available segments from S3
  puts "\n🎬 Downloading all available segments..."
  
  segments_dir = "segments/#{project_id}"
  FileUtils.mkdir_p(segments_dir)
  
  downloaded_count = 0
  (0...manifest['segments'].length).each do |i|
    segment_key = "segments/#{project_id}/#{i}_segment.mp4"
    local_path = "#{segments_dir}/#{i}_segment.mp4"
    
    begin
      s3_service.instance_variable_get(:@s3_client).get_object(
        bucket: 'burns-videos',
        key: segment_key,
        response_target: local_path
      )
      downloaded_count += 1
      puts "  ✅ Downloaded segment #{i}" if i % 10 == 0
    rescue => e
      # Skip missing segments
      puts "  ⚠️  Segment #{i} not available"
    end
  end
  
  puts "📊 Downloaded #{downloaded_count} segment files"
  
  if downloaded_count < (manifest['segments'].length * 0.5)
    puts "❌ Too few segments available (#{downloaded_count}/#{manifest['segments'].length})"
    exit 1
  end
  
  # Combine available segments
  puts "🎬 Combining #{downloaded_count} segments with audio..."
  
  segment_files = (0...manifest['segments'].length).map { |i| "#{segments_dir}/#{i}_segment.mp4" }.select { |f| File.exist?(f) }
  
  # Create FFmpeg concat file
  concat_file = "/tmp/#{project_id}_segments.txt"
  File.open(concat_file, 'w') do |f|
    segment_files.each { |file| f.puts "file '#{File.absolute_path(file)}'" }
  end
  
  # Combine segments
  temp_video = "/tmp/#{project_id}_segments_combined.mp4"
  cmd = ["ffmpeg", "-f", "concat", "-safe", "0", "-i", concat_file, "-c", "copy", "-y", temp_video]
  
  puts "🔧 Combining segments..."
  unless system(*cmd)
    puts "❌ Failed to combine segments"
    exit 1
  end
  
  # Add audio
  audio_file = "#{project_id}.m4a"
  final_video = "completed/#{project_id}_ken_burns_video.mp4"
  
  FileUtils.mkdir_p("completed")
  
  audio_cmd = [
    "ffmpeg", "-i", temp_video, "-i", audio_file,
    "-c:v", "copy", "-c:a", "aac", "-map", "0:v:0", "-map", "1:a:0",
    "-shortest", "-y", final_video
  ]
  
  puts "🎵 Adding audio..."
  unless system(*audio_cmd)
    puts "❌ Failed to add audio"
    exit 1
  end
  
  if File.exist?(final_video)
    puts "\n🎉 #{project_id} video completed successfully!"
    puts "📹 Video saved to: #{final_video}"
    puts "📊 File size: #{(File.size(final_video) / 1024.0 / 1024.0).round(2)} MB"
    puts "🎬 Segments used: #{segment_files.length}/#{manifest['segments'].length} (#{(segment_files.length/manifest['segments'].length.to_f*100).round(1)}%)"
    
    # Upload to S3
    puts "📤 Uploading to S3..."
    s3_key = "projects/#{project_id}/final_video.mp4"
    s3_service.instance_variable_get(:@s3_client).put_object(
      bucket: 'burns-videos',
      key: s3_key,
      body: File.read(final_video),
      content_type: 'video/mp4'
    )
    puts "✅ Uploaded to S3: s3://burns-videos/#{s3_key}"
    
    # Cleanup
    [concat_file, temp_video].each { |f| File.delete(f) if File.exist?(f) }
    
  else
    puts "❌ Failed to create final video"
    exit 1
  end

rescue => e
  puts "❌ Error: #{e.message}"
  exit 1
end