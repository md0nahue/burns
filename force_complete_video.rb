#!/usr/bin/env ruby

require_relative 'lib/services/lambda_service'
require_relative 'lib/services/s3_service'

puts "🎬 Force completing video for project: b3"
puts "=" * 50

# Initialize services
lambda_service = LambdaService.new
s3_service = S3Service.new

# Check available segments
bucket_name = 'burns-videos'
puts "🔍 Checking available segments..."
segments = []

begin
  # List all segment files
  s3_client = Aws::S3::Client.new(
    region: 'us-east-1',
    credentials: Aws::Credentials.new(
      ENV['AWS_ACCESS_KEY_ID'],
      ENV['AWS_SECRET_ACCESS_KEY']
    )
  )
  
  response = s3_client.list_objects_v2(
    bucket: bucket_name,
    prefix: 'segments/b3/'
  )
  
  segment_files = response.contents.map(&:key).select { |key| key.end_with?('.mp4') }
  puts "📊 Found #{segment_files.length} segment files"
  
  # Create segment results array
  segment_results = segment_files.map do |key|
    segment_id = key.split('/').last.gsub('_segment.mp4', '')
    {
      success: true,
      segment_id: segment_id,
      segment_s3_key: key,
      duration: 3.0,  # Default duration
      processing_time: 0.0
    }
  end
  
  puts "✅ Prepared #{segment_results.length} segments for combination"
  
  # Force video combination
  puts "\n🎬 Combining segments into final video..."
  combination_result = lambda_service.combine_segments_into_video('b3', segment_results, {
    resolution: '1080p',
    fps: 24,
    ken_burns_effect: true
  })
  
  if combination_result[:success]
    puts "✅ Video combination completed!"
    puts "📹 Video URL: #{combination_result[:video_url]}"
    puts "⏱️  Duration: #{combination_result[:duration]} seconds"
    
    # Try to download to completed directory
    if combination_result[:video_url]
      puts "\n📥 Downloading final video to completed directory..."
      system("mkdir -p completed")
      
      video_s3_key = combination_result[:video_s3_key] || "projects/b3/final_video.mp4"
      completed_video_path = "completed/b3_ken_burns_video.mp4"
      
      download_command = "aws s3 cp s3://burns-videos/#{video_s3_key} '#{completed_video_path}'"
      puts "💾 Downloading: #{download_command}"
      
      if system(download_command)
        puts "✅ Video downloaded successfully!"
        puts "📁 Local path: #{completed_video_path}"
        if File.exist?(completed_video_path)
          puts "📹 File size: #{(File.size(completed_video_path) / 1024.0 / 1024.0).round(2)} MB"
        end
      else
        puts "⚠️  Download failed, but video is available at: #{combination_result[:video_url]}"
      end
    end
    
  else
    puts "❌ Video combination failed: #{combination_result[:error]}"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end

puts "\n" + "=" * 50
puts "🏁 Force completion attempt finished"