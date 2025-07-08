#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'fileutils'
require 'json'
require_relative 'config/services'

puts "🎬 Completing Vibe Video with Ken Burns Variety Effects"
puts "===================================================="

# AWS S3 setup
s3 = Aws::S3::Client.new(
  region: Config::AWS_CONFIG[:region],
  credentials: Aws::Credentials.new(
    Config::AWS_CONFIG[:access_key_id],
    Config::AWS_CONFIG[:secret_access_key]
  )
)

bucket_name = Config::AWS_CONFIG[:s3_bucket]
project_id = 'vibe'

# Create temp directory
temp_dir = Dir.mktmpdir
puts "📁 Temp directory: #{temp_dir}"

begin
  # Download vibe segments from S3
  puts "📥 Downloading vibe segments from S3..."
  
  # List all segments
  segment_objects = s3.list_objects_v2(
    bucket: bucket_name,
    prefix: "segments/#{project_id}/"
  ).contents
  
  segment_count = segment_objects.length
  puts "📊 Found #{segment_count} segments to download"
  
  if segment_count == 0
    puts "❌ No segments found! Make sure the video generation has started."
    exit 1
  end
  
  # Download each segment
  segment_files = []
  segment_objects.sort_by { |obj| obj.key.match(/(\d+)_segment/)[1].to_i }.each_with_index do |obj, index|
    segment_num = obj.key.match(/(\d+)_segment/)[1]
    local_path = File.join(temp_dir, "#{segment_num}_segment.mp4")
    
    print "📥 Downloading segment #{index + 1}/#{segment_count}: #{segment_num}_segment.mp4"
    s3.get_object(
      bucket: bucket_name,
      key: obj.key,
      response_target: local_path
    )
    segment_files << local_path
    puts ""
  end
  
  puts "✅ Downloaded #{segment_files.length} segments"
  
  # Create file list for ffmpeg concat
  file_list_path = File.join(temp_dir, "vibe_file_list.txt")
  File.open(file_list_path, 'w') do |f|
    segment_files.each do |file|
      f.puts "file '#{file}'"
    end
  end
  
  # Combine videos with ffmpeg
  puts "🎬 Combining videos with ffmpeg..."
  combined_path = File.join(temp_dir, "vibe_combined.mp4")
  
  concat_cmd = [
    "ffmpeg",
    "-f", "concat",
    "-safe", "0", 
    "-i", file_list_path,
    "-c", "copy",
    "-y",
    combined_path
  ].join(" ")
  
  if system(concat_cmd)
    puts "✅ Video combination successful!"
  else
    puts "❌ Video combination failed!"
    exit 1
  end
  
  # Add audio
  puts "🎵 Adding original vibe.mp3 audio..."
  final_path = File.join(temp_dir, "vibe_with_audio.mp4")
  
  audio_cmd = [
    "ffmpeg",
    "-i", combined_path,
    "-i", "vibe.mp3",
    "-c:v", "copy",
    "-c:a", "aac",
    "-shortest",
    "-y",
    final_path
  ].join(" ")
  
  if system(audio_cmd)
    puts "✅ Audio added successfully!"
  else
    puts "❌ Failed to add audio"
    exit 1
  end
  
  # Move to completed folder
  FileUtils.mkdir_p("completed")
  completed_path = "completed/vibe_ken_burns_video.mp4"
  FileUtils.mv(final_path, completed_path)
  
  puts "✅ Final video saved to: #{completed_path}"
  
  # Get file size
  file_size = File.size(completed_path)
  puts "📹 Final file size: #{(file_size / 1024.0 / 1024.0).round(2)} MB"
  
  # Validate video
  probe_cmd = "ffprobe -v quiet -print_format json -show_format '#{completed_path}'"
  probe_output = `#{probe_cmd}`
  
  if $?.success?
    probe_data = JSON.parse(probe_output)
    duration = probe_data.dig('format', 'duration').to_f
    puts "✅ Video file is valid and playable with audio!"
    puts "⏱️  Final video duration: #{(duration / 60.0).round(1)} minutes"
  else
    puts "⚠️  Could not validate video file"
  end
  
  # Upload final video to S3
  puts "📤 Uploading final video to S3..."
  s3.put_object(
    bucket: bucket_name,
    key: "projects/#{project_id}/final_video.mp4",
    body: File.read(completed_path),
    content_type: 'video/mp4'
  )
  puts "✅ Final video uploaded to S3!"

rescue => e
  puts "❌ Error: #{e.message}"
ensure
  # Clean up temp directory
  puts "🧹 Cleaning up temp directory..."
  FileUtils.rm_rf(temp_dir)
end

puts "\n=================================================="
puts "🏁 Vibe video completion finished"
puts "📺 Video location: #{File.expand_path('completed/vibe_ken_burns_video.mp4')}"
puts "☁️  S3 location: s3://#{bucket_name}/projects/#{project_id}/final_video.mp4"