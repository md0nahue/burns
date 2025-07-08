#!/usr/bin/env ruby

require 'fileutils'
require 'tempfile'

puts "🎬 Completing Fireship Video"
puts "=" * 50

# Create temp directory
temp_dir = Dir.mktmpdir
puts "📁 Temp directory: #{temp_dir}"

begin
  # Download fireship segments
  puts "📥 Downloading fireship segments from S3..."
  
  # Get list of available segments
  segment_list = `aws s3 ls s3://burns-videos/segments/fireship/ | grep "\.mp4"`
  segment_files = segment_list.split("\n").map do |line|
    parts = line.split
    parts.last if parts.last&.end_with?('.mp4')
  end.compact.sort_by { |f| f.split('_').first.to_i }
  
  puts "📊 Found #{segment_files.length} segments to download"
  
  # Download segments
  downloaded_files = []
  segment_files.each_with_index do |segment_file, index|
    local_path = File.join(temp_dir, segment_file)
    s3_path = "s3://burns-videos/segments/fireship/#{segment_file}"
    
    print "\r📥 Downloading segment #{index + 1}/#{segment_files.length}: #{segment_file}"
    
    if system("aws s3 cp #{s3_path} #{local_path} > /dev/null 2>&1")
      downloaded_files << local_path
    else
      puts "\n⚠️  Failed to download #{segment_file}"
    end
  end
  
  puts "\n✅ Downloaded #{downloaded_files.length} segments"
  
  # Create file list for ffmpeg
  file_list_path = File.join(temp_dir, 'file_list.txt')
  File.open(file_list_path, 'w') do |f|
    downloaded_files.sort_by { |path| File.basename(path).split('_').first.to_i }.each do |file|
      f.puts "file '#{file}'"
    end
  end
  
  # Combine videos with ffmpeg
  output_path = File.join(temp_dir, 'fireship_combined.mp4')
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
  
  if system("#{ffmpeg_cmd} 2>/dev/null")
    puts "✅ Video combination successful!"
    
    # Add original audio
    puts "🎵 Adding original fireship.mp3 audio..."
    audio_file = 'fireship.mp3'
    final_path_temp = File.join(temp_dir, 'fireship_with_audio.mp4')
    
    audio_cmd = [
      'ffmpeg',
      '-i', output_path,
      '-i', audio_file,
      '-c:v', 'copy',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-shortest',
      '-movflags', '+faststart',
      '-y', final_path_temp
    ].join(' ')
    
    if system(audio_cmd)
      puts "✅ Audio added successfully!"
      
      # Copy to completed directory
      FileUtils.mkdir_p('completed')
      final_path = 'completed/fireship_ken_burns_video.mp4'
      
      FileUtils.cp(final_path_temp, final_path)
      
      if File.exist?(final_path)
        puts "✅ Final video saved to: #{final_path}"
        puts "📹 Final file size: #{(File.size(final_path) / 1024.0 / 1024.0).round(2)} MB"
        
        # Test video integrity
        if system("ffprobe -v quiet -print_format json -show_format -show_streams '#{final_path}' > /dev/null 2>&1")
          puts "✅ Video file is valid and playable with audio!"
          
          # Get duration
          duration = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 '#{final_path}'`.strip.to_f
          puts "⏱️  Final video duration: #{(duration / 60).round(1)} minutes"
          
          # Upload to S3
          puts "📤 Uploading final video to S3..."
          s3_final_path = "s3://burns-videos/projects/fireship/final_video.mp4"
          if system("aws s3 cp '#{final_path}' #{s3_final_path}")
            puts "✅ Final video uploaded to S3!"
          end
        else
          puts "⚠️  Video file may have issues"
        end
      end
    else
      puts "❌ Failed to add audio"
    end
  else
    puts "❌ Video combination failed"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  
ensure
  # Cleanup
  puts "\n🧹 Cleaning up temp directory..."
  FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
end

puts "\n" + "=" * 50
puts "🏁 Fireship video completion finished"