#!/usr/bin/env ruby

require_relative 'lib/services/s3_service'
require_relative 'lib/services/local_video_service'
require_relative 'lib/pipeline/video_generator'
require 'fileutils'
require 'json'

puts "🔧 Force completing vibe3 video with mixed Lambda/local segments..."

# Initialize services
s3_service = S3Service.new
local_video_service = LocalVideoService.new
video_generator = VideoGenerator.new

begin
  # Get project manifest
  puts "📥 Getting project manifest..."
  manifest_result = s3_service.get_project_manifest('vibe3')
  
  unless manifest_result[:success]
    puts "❌ Failed to get manifest: #{manifest_result[:error]}"
    exit 1
  end
  
  manifest = manifest_result[:manifest]
  puts "✅ Manifest loaded: #{manifest['segments'].length} segments total"
  
  # Check which segments exist in S3
  available_segments = []
  missing_segments = []
  
  (0..56).each do |i|
    segment_key = "segments/vibe3/#{i}_segment.mp4"
    begin
      s3_service.instance_variable_get(:@s3_client).head_object(bucket: 'burns-videos', key: segment_key)
      available_segments << i
    rescue
      missing_segments << i
    end
  end
  
  puts "✅ Available segments: #{available_segments.length}/57"
  puts "❌ Missing segments: #{missing_segments.join(', ')}"
  
  # Generate missing segments locally
  if missing_segments.any?
    puts "\n🎬 Generating #{missing_segments.length} missing segments locally..."
    
    missing_segments.each do |segment_index|
      segment = manifest['segments'][segment_index]
      puts "  📝 Generating segment #{segment_index}: #{segment['text'][0,50]}..."
      
      # Create local Ken Burns video for this segment
      begin
        result = local_video_service.create_single_image_ken_burns(
          segment['generated_images'][0]['url'],
          segment['end_time'].to_f - segment['start_time'].to_f,
          {
            resolution: '1080p',
            fps: 24,
            ken_burns_effect: true
          }
        )
        
        if result[:success]
          # Upload to S3 with correct naming
          segment_key = "segments/vibe3/#{segment_index}_segment.mp4"
          s3_service.instance_variable_get(:@s3_client).put_object(
            bucket: 'burns-videos',
            key: segment_key,
            body: File.read(result[:video_path])
          )
          puts "    ✅ Generated and uploaded segment #{segment_index}"
        else
          puts "    ❌ Failed to generate segment #{segment_index}: #{result[:error]}"
        end
      rescue => e
        puts "    ❌ Error generating segment #{segment_index}: #{e.message}"
      end
    end
  end
  
  # Now combine all segments
  puts "\n🎬 Combining all segments into final video..."
  
  # Create segments directory locally
  segments_dir = "segments/vibe3"
  FileUtils.mkdir_p(segments_dir)
  
  # Download all segments from S3
  puts "📥 Downloading segments from S3..."
  (0..56).each do |i|
    segment_key = "segments/vibe3/#{i}_segment.mp4"
    local_path = "#{segments_dir}/#{i}_segment.mp4"
    
    begin
      s3_service.instance_variable_get(:@s3_client).get_object(
        bucket: 'burns-videos',
        key: segment_key,
        response_target: local_path
      )
      puts "  ✅ Downloaded segment #{i}"
    rescue => e
      puts "  ❌ Failed to download segment #{i}: #{e.message}"
    end
  end
  
  # Use local video service to combine segments with audio
  puts "🎬 Combining segments with audio..."
  
  # Create a list of segment files in order
  segment_files = (0..56).map { |i| "#{segments_dir}/#{i}_segment.mp4" }.select { |f| File.exist?(f) }
  puts "📊 Found #{segment_files.length} segment files to combine"
  
  # Create FFmpeg concat file
  concat_file = "/tmp/vibe3_segments.txt"
  File.open(concat_file, 'w') do |f|
    segment_files.each { |file| f.puts "file '#{File.absolute_path(file)}'" }
  end
  
  # Combine segments
  temp_video = "/tmp/vibe3_segments_combined.mp4"
  cmd = [
    "ffmpeg",
    "-f", "concat",
    "-safe", "0",
    "-i", concat_file,
    "-c", "copy",
    "-y",
    temp_video
  ]
  
  puts "🔧 Running FFmpeg concat: #{cmd.join(' ')}"
  system(*cmd)
  
  if File.exist?(temp_video)
    # Add audio
    audio_file = "vibe3.mp3"
    final_video = "completed/vibe3_ken_burns_video.mp4"
    
    FileUtils.mkdir_p("completed")
    
    audio_cmd = [
      "ffmpeg",
      "-i", temp_video,
      "-i", audio_file,
      "-c:v", "copy",
      "-c:a", "aac",
      "-map", "0:v:0",
      "-map", "1:a:0",
      "-shortest",
      "-y",
      final_video
    ]
    
    puts "🎵 Adding audio: #{audio_cmd.join(' ')}"
    system(*audio_cmd)
    
    if File.exist?(final_video)
      puts "\n✅ Video completed successfully!"
      puts "📹 Video saved to: #{final_video}"
      puts "📊 File size: #{(File.size(final_video) / 1024.0 / 1024.0).round(2)} MB"
    else
      puts "❌ Failed to create final video with audio"
    end
  else
    puts "❌ Failed to combine segments"
  end

rescue => e
  puts "❌ Error during completion: #{e.message}"
  puts "🔍 Stack trace: #{e.backtrace.first(5).join("\n")}"
end