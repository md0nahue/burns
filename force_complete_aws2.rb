#!/usr/bin/env ruby

require_relative 'lib/services/s3_service'
require_relative 'lib/services/local_video_service'
require_relative 'lib/pipeline/video_generator'
require 'fileutils'
require 'json'

puts "🔧 Force completing aws2 video with mixed Lambda/local segments..."

# Initialize services
s3_service = S3Service.new
local_video_service = LocalVideoService.new
video_generator = VideoGenerator.new

begin
  # Get project manifest
  puts "📥 Getting project manifest..."
  manifest_result = s3_service.get_project_manifest('aws2')
  
  unless manifest_result[:success]
    puts "❌ Failed to get manifest: #{manifest_result[:error]}"
    exit 1
  end
  
  manifest = manifest_result[:manifest]
  puts "✅ Manifest loaded: #{manifest['segments'].length} segments total"
  
  # Check what segments exist in S3
  bucket_name = 'burns-videos'
  prefix = 'segments/aws2/'
  
  puts "📂 Checking S3 bucket '#{bucket_name}' for segments with prefix '#{prefix}'"
  
  objects = s3_service.instance_variable_get(:@s3_client).list_objects_v2(
    bucket: bucket_name,
    prefix: prefix
  )
  
  if objects.contents.any?
    puts "✅ Found #{objects.contents.length} segment files in S3"
    
    # Extract segment numbers from file names
    available_segment_numbers = objects.contents.map do |obj|
      if obj.key =~ /(\d+)_segment\.mp4$/
        $1.to_i
      end
    end.compact.sort
    
    puts "📊 Available segment numbers: #{available_segment_numbers.join(', ')}"
    puts "📊 Total available segments: #{available_segment_numbers.length}/89"
    
    missing_segments = (0..88).to_a - available_segment_numbers
    puts "❌ Missing segments: #{missing_segments.join(', ')}" if missing_segments.any?
    
    # Generate missing segments locally with ultra-smooth Ken Burns
    if missing_segments.any?
      puts "\n🎬 Generating #{missing_segments.length} missing segments locally with ultra-smooth Ken Burns..."
      
      missing_segments.each do |segment_index|
        segment = manifest['segments'][segment_index]
        puts "  📝 Generating segment #{segment_index}: #{segment['text'][0,50]}..."
        
        # Create local Ken Burns video for this segment with improved settings
        begin
          if segment['generated_images'] && segment['generated_images'].any?
            # Download image first
            require 'net/http'
            require 'uri'
            
            image_url = segment['generated_images'][0]['url']
            image_path = "/tmp/aws2_segment_#{segment_index}_image.jpg"
            uri = URI(image_url)
            
            puts "    📥 Downloading image from #{image_url[0,60]}..."
            Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
              response = http.get(uri.path)
              File.open(image_path, 'wb') { |f| f.write(response.body) }
            end
            
            # Create output path
            output_path = "/tmp/aws2_segment_#{segment_index}.mp4"
            duration = segment['end_time'].to_f - segment['start_time'].to_f
            
            # Generate with ultra-smooth Ken Burns
            success = local_video_service.create_single_image_ken_burns(
              image_path,
              duration,
              output_path
            )
            
            if success && File.exist?(output_path)
              # Upload to S3 with correct naming
              segment_key = "segments/aws2/#{segment_index}_segment.mp4"
              s3_service.instance_variable_get(:@s3_client).put_object(
                bucket: 'burns-videos',
                key: segment_key,
                body: File.read(output_path)
              )
              puts "    ✅ Generated and uploaded segment #{segment_index} with ultra-smooth Ken Burns"
              
              # Clean up temp files
              File.delete(image_path) if File.exist?(image_path)
              File.delete(output_path) if File.exist?(output_path)
            else
              puts "    ❌ Failed to generate segment #{segment_index}"
            end
          else
            puts "    ⚠️  No images available for segment #{segment_index}"
          end
        rescue => e
          puts "    ❌ Error generating segment #{segment_index}: #{e.message}"
        end
      end
    end
  else
    puts "❌ No segment files found in S3"
    exit 1
  end
  
  # Now combine all segments
  puts "\n🎬 Combining all segments into final video..."
  
  # Create segments directory locally
  segments_dir = "segments/aws2"
  FileUtils.mkdir_p(segments_dir)
  
  # Download all segments from S3
  puts "📥 Downloading segments from S3..."
  downloaded_count = 0
  (0..88).each do |i|
    segment_key = "segments/aws2/#{i}_segment.mp4"
    local_path = "#{segments_dir}/#{i}_segment.mp4"
    
    begin
      s3_service.instance_variable_get(:@s3_client).get_object(
        bucket: 'burns-videos',
        key: segment_key,
        response_target: local_path
      )
      downloaded_count += 1
      puts "  ✅ Downloaded segment #{i}" if i % 10 == 0 || missing_segments.include?(i)
    rescue => e
      puts "  ❌ Failed to download segment #{i}: #{e.message}" if missing_segments.include?(i)
    end
  end
  
  puts "📊 Downloaded #{downloaded_count} segment files"
  
  # Create a list of segment files in order
  segment_files = (0..88).map { |i| "#{segments_dir}/#{i}_segment.mp4" }.select { |f| File.exist?(f) }
  puts "📊 Found #{segment_files.length} segment files to combine"
  
  # Create FFmpeg concat file
  concat_file = "/tmp/aws2_segments.txt"
  File.open(concat_file, 'w') do |f|
    segment_files.each { |file| f.puts "file '#{File.absolute_path(file)}'" }
  end
  
  # Combine segments
  temp_video = "/tmp/aws2_segments_combined.mp4"
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
    audio_file = "aws2.mp3"
    final_video = "completed/aws2_ken_burns_video.mp4"
    
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
      puts "\n🎉 AWS2 video completed successfully with ultra-smooth Ken Burns effects!"
      puts "📹 Video saved to: #{final_video}"
      puts "📊 File size: #{(File.size(final_video) / 1024.0 / 1024.0).round(2)} MB"
      puts "⏱️  Duration: ~#{(manifest['duration'] / 60.0).round(1)} minutes"
      puts "🎬 Segments: #{segment_files.length}/89 (#{(segment_files.length/89.0*100).round(1)}%)"
      puts "✨ Features: High-quality images + Ultra-smooth Ken Burns effects (NEW ALGORITHM)"
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