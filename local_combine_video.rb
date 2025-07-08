#!/usr/bin/env ruby

require 'fileutils'
require 'tempfile'

puts "🎬 Local Video Combination for project: b3"
puts "=" * 50

# Create temp directory
temp_dir = Dir.mktmpdir
puts "📁 Temp directory: #{temp_dir}"

begin
  # Download available segments
  puts "📥 Downloading segments from S3..."
  
  # Get list of available segments
  segment_list = `aws s3 ls s3://burns-videos/segments/b3/ | grep "\.mp4"`
  segment_files = segment_list.split("\n").map do |line|
    parts = line.split
    parts.last if parts.last&.end_with?('.mp4')
  end.compact.sort_by { |f| f.split('_').first.to_i }
  
  puts "📊 Found #{segment_files.length} segments to download"
  
  # Download segments
  downloaded_files = []
  segment_files.each_with_index do |segment_file, index|
    local_path = File.join(temp_dir, segment_file)
    s3_path = "s3://burns-videos/segments/b3/#{segment_file}"
    
    print "\r📥 Downloading segment #{index + 1}/#{segment_files.length}: #{segment_file}"
    
    if system("aws s3 cp #{s3_path} #{local_path} > /dev/null 2>&1")
      downloaded_files << local_path
    else
      puts "\n⚠️  Failed to download #{segment_file}"
    end
  end
  
  puts "\n✅ Downloaded #{downloaded_files.length} segments"
  
  if downloaded_files.empty?
    puts "❌ No segments downloaded. Exiting."
    exit 1
  end
  
  # Create file list for ffmpeg
  file_list_path = File.join(temp_dir, 'file_list.txt')
  File.open(file_list_path, 'w') do |f|
    downloaded_files.sort_by { |path| File.basename(path).split('_').first.to_i }.each do |file|
      f.puts "file '#{file}'"
    end
  end
  
  puts "📋 Created file list with #{downloaded_files.length} segments"
  
  # Combine videos with ffmpeg
  output_path = File.join(temp_dir, 'b3_combined.mp4')
  puts "🎬 Combining videos with ffmpeg..."
  
  ffmpeg_cmd = [
    'ffmpeg',
    '-f', 'concat',
    '-safe', '0',
    '-i', file_list_path,
    '-c', 'copy',
    '-avoid_negative_ts', 'make_zero',
    output_path
  ].join(' ')
  
  puts "🔧 FFmpeg command: #{ffmpeg_cmd}"
  
  if system("#{ffmpeg_cmd} 2>/dev/null")
    puts "✅ Video combination successful!"
    
    if File.exist?(output_path)
      file_size = File.size(output_path)
      puts "📹 Combined video size: #{(file_size / 1024.0 / 1024.0).round(2)} MB"
      
      # Copy to completed directory
      FileUtils.mkdir_p('completed')
      final_path = 'completed/b3_ken_burns_video.mp4'
      
      puts "📁 Copying to completed directory..."
      FileUtils.cp(output_path, final_path)
      
      if File.exist?(final_path)
        puts "✅ Final video saved to: #{final_path}"
        puts "📹 Final file size: #{(File.size(final_path) / 1024.0 / 1024.0).round(2)} MB"
        
        # Test video with ffprobe
        puts "🧪 Testing video integrity..."
        if system("ffprobe -v quiet -print_format json -show_format -show_streams '#{final_path}' > /dev/null 2>&1")
          puts "✅ Video file is valid and playable!"
        else
          puts "⚠️  Video file may have issues"
        end
        
        # Upload to S3 as final video
        puts "📤 Uploading final video to S3..."
        s3_final_path = "s3://burns-videos/projects/b3/final_video.mp4"
        if system("aws s3 cp '#{final_path}' #{s3_final_path}")
          puts "✅ Final video uploaded to S3!"
          puts "🔗 S3 path: #{s3_final_path}"
        else
          puts "⚠️  Failed to upload to S3, but local file is available"
        end
        
      else
        puts "❌ Failed to copy to completed directory"
      end
    else
      puts "❌ Output file not created"
    end
  else
    puts "❌ Video combination failed"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
  
ensure
  # Cleanup
  puts "\n🧹 Cleaning up temp directory..."
  FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
end

puts "\n" + "=" * 50
puts "🏁 Local video combination finished"