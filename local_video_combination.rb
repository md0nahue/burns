#!/usr/bin/env ruby

require_relative 'config/services'
require_relative 'lib/services/s3_service'
require_relative 'lib/services/local_video_service'
require 'json'
require 'fileutils'

project_id = 'bernie'

puts "🔧 Local Video Combination for #{project_id}"
puts "============================================================"

begin
  # Initialize services
  s3_service = S3Service.new
  video_service = LocalVideoService.new
  
  puts "📋 Getting project manifest..."
  manifest_result = s3_service.get_project_manifest(project_id)
  
  unless manifest_result[:success]
    puts "❌ Failed to get project manifest: #{manifest_result[:error]}"
    exit 1
  end
  
  manifest = manifest_result[:manifest]
  segments = manifest['segments']
  
  puts "📊 Total segments in manifest: #{segments.length}"
  
  # Filter segments that have images
  valid_segments = segments.select do |segment|
    segment['generated_images'] && segment['generated_images'].length > 0
  end
  
  puts "📊 Valid segments with images: #{valid_segments.length}"
  
  if valid_segments.length == 0
    puts "❌ No valid segments found"
    exit 1
  end
  
  # Create temp directory for downloads
  temp_dir = Dir.mktmpdir("bernie_video_combination_")
  puts "📁 Using temp directory: #{temp_dir}"
  
  # Download all segment videos from S3
  segment_files = []
  audio_file = nil
  
  puts "📥 Downloading segment videos from S3..."
  valid_segments.each_with_index do |segment, index|
    segment_s3_key = "segments/#{project_id}/#{segment['id']}_segment.mp4"
    local_segment_path = File.join(temp_dir, "segment_#{segment['id']}.mp4")
    
    puts "  #{index + 1}/#{valid_segments.length}: Downloading segment #{segment['id']}..."
    
    download_result = s3_service.download_video(segment_s3_key, local_segment_path)
    
    if download_result[:success]
      segment_files << {
        path: local_segment_path,
        segment_id: segment['id'],
        start_time: segment['start_time'],
        end_time: segment['end_time']
      }
      puts "    ✅ Downloaded: #{File.basename(local_segment_path)}"
    else
      puts "    ⚠️  Failed to download segment #{segment['id']}: #{download_result[:error]}"
    end
  end
  
  puts "✅ Downloaded #{segment_files.length} segment videos"
  
  # Download audio file
  puts "📥 Downloading audio file..."
  audio_s3_key = "projects/#{project_id}/audio/#{project_id}.mp3"
  audio_path = File.join(temp_dir, "#{project_id}.mp3")
  
  audio_download = s3_service.download_video(audio_s3_key, audio_path)
  if audio_download[:success]
    audio_file = audio_path
    puts "✅ Audio downloaded: #{File.basename(audio_file)}"
  else
    puts "⚠️  Failed to download audio: #{audio_download[:error]}"
  end
  
  # Sort segments by start time
  segment_files.sort_by! { |seg| seg[:start_time] }
  
  # Create video list file for FFmpeg
  video_list_path = File.join(temp_dir, "video_list.txt")
  File.open(video_list_path, 'w') do |f|
    segment_files.each do |seg|
      f.puts "file '#{seg[:path]}'"
    end
  end
  
  puts "📋 Video list created with #{segment_files.length} segments"
  
  # Combine videos using FFmpeg
  combined_video_path = File.join(temp_dir, "combined_video.mp4")
  puts "🎬 Combining videos with FFmpeg..."
  
  ffmpeg_cmd = [
    "ffmpeg",
    "-f", "concat",
    "-safe", "0",
    "-i", video_list_path,
    "-c:v", "libx264",
    "-preset", "medium",
    "-crf", "20",
    "-r", "24",
    "-pix_fmt", "yuv420p",
    "-movflags", "+faststart",
    "-y", combined_video_path
  ]
  
  result = system(*ffmpeg_cmd)
  
  unless result && File.exist?(combined_video_path)
    puts "❌ Failed to combine videos"
    exit 1
  end
  
  puts "✅ Videos combined successfully"
  
  # Add audio if available
  final_video_path = File.join(temp_dir, "final_video.mp4")
  
  if audio_file && File.exist?(audio_file)
    puts "🎵 Adding audio track..."
    
    audio_cmd = [
      "ffmpeg",
      "-i", combined_video_path,
      "-i", audio_file,
      "-c:v", "copy",
      "-c:a", "aac",
      "-b:a", "128k",
      "-shortest",
      "-movflags", "+faststart",
      "-y", final_video_path
    ]
    
    audio_result = system(*audio_cmd)
    
    if audio_result && File.exist?(final_video_path)
      puts "✅ Audio added successfully"
    else
      puts "⚠️  Failed to add audio, using video without audio"
      final_video_path = combined_video_path
    end
  else
    puts "⚠️  No audio file, creating video without audio"
    final_video_path = combined_video_path
  end
  
  # Move to completed directory
  FileUtils.mkdir_p('completed')
  final_destination = "completed/#{project_id}_ken_burns_video.mp4"
  
  FileUtils.cp(final_video_path, final_destination)
  
  puts "✅ Video saved to: #{final_destination}"
  puts "📊 File size: #{(File.size(final_destination) / 1024.0 / 1024.0).round(2)} MB"
  
  # Get video info
  duration_cmd = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 "#{final_destination}" 2>/dev/null`.strip
  if duration_cmd && !duration_cmd.empty?
    duration = duration_cmd.to_f
    puts "⏱️  Duration: #{(duration / 60).round(2)} minutes"
  end
  
  puts "🎬 Testing video playback..."
  test_cmd = system("ffprobe", "-v", "error", final_destination, :out => "/dev/null", :err => "/dev/null")
  if test_cmd
    puts "✅ Video file is valid and playable!"
  else
    puts "⚠️  Video file may have issues"
  end
  
  # Cleanup
  FileUtils.rm_rf(temp_dir)
  puts "🧹 Cleaned up temporary files"
  
rescue => e
  puts "❌ Error in local video combination: #{e.message}"
  puts "🔧 Backtrace: #{e.backtrace.first(5)}"
ensure
  # Cleanup temp directory if it exists
  FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
end

puts "\n🎯 Local video combination complete!"