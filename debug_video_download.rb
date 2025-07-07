#!/usr/bin/env ruby

require_relative 'config/services'
require_relative 'lib/services/lambda_service'
require_relative 'lib/services/s3_service'
require 'json'

puts "🔍 DEBUG: Video Download Investigation"
puts "=" * 60

# Check environment variables
puts "\n📋 Environment Variables:"
puts "  AWS_ACCESS_KEY_ID: #{ENV['AWS_ACCESS_KEY_ID'] ? '✅' : '❌'}"
puts "  AWS_SECRET_ACCESS_KEY: #{ENV['AWS_SECRET_ACCESS_KEY'] ? '✅' : '❌'}"
puts "  AWS_REGION: #{ENV['AWS_REGION'] || 'us-east-1'}"
puts "  LAMBDA_FUNCTION: #{ENV['LAMBDA_FUNCTION'] || 'ken-burns-video-generator-go'}"
puts "  S3_BUCKET: #{ENV['S3_BUCKET'] || 'burns-videos'}"

# Initialize services
lambda_service = LambdaService.new
s3_service = S3Service.new

puts "\n🔧 AWS Services Status:"

# Check Lambda function
puts "📊 Checking Lambda function..."
lambda_status = lambda_service.check_function_status
if lambda_status[:success]
  puts "  ✅ Lambda function is accessible"
  puts "  📝 Function: #{lambda_status[:function_name]}"
  puts "  🐍 Runtime: #{lambda_status[:runtime]}"
  puts "  ⏱️  Timeout: #{lambda_status[:timeout]}s"
  puts "  💾 Memory: #{lambda_status[:memory_size]}MB"
  puts "  🔄 State: #{lambda_status[:state]}"
else
  puts "  ❌ Lambda function issue: #{lambda_status[:error]}"
end

# Check S3 bucket
puts "\n📦 Checking S3 bucket access..."
begin
  # Try to list recent projects
  # This will test both bucket access and credentials
  puts "  🔍 Testing S3 bucket access..."
  
  # Check if we can list objects in the bucket
  bucket_name = Config::AWS_CONFIG[:s3_bucket]
  s3_client = Aws::S3::Client.new(
    region: Config::AWS_CONFIG[:region],
    credentials: Aws::Credentials.new(
      Config::AWS_CONFIG[:access_key_id],
      Config::AWS_CONFIG[:secret_access_key]
    )
  )
  
  response = s3_client.list_objects_v2(bucket: bucket_name, max_keys: 5)
  puts "  ✅ S3 bucket is accessible"
  puts "  📊 Objects in bucket: #{response.key_count}"
  
  # List recent video files
  video_objects = []
  response.contents.each do |obj|
    if obj.key.end_with?('.mp4')
      video_objects << {
        key: obj.key,
        size: obj.size,
        last_modified: obj.last_modified
      }
    end
  end
  
  puts "  🎬 Recent video files:"
  if video_objects.any?
    video_objects.sort_by { |obj| obj[:last_modified] }.reverse.first(3).each do |obj|
      puts "    📹 #{obj[:key]}"
      puts "      📊 Size: #{(obj[:size] / 1024.0 / 1024.0).round(2)} MB"
      puts "      📅 Modified: #{obj[:last_modified]}"
    end
  else
    puts "    ❌ No video files found in S3 bucket"
  end
  
rescue => e
  puts "  ❌ S3 bucket access error: #{e.message}"
end

# Test video download functionality
puts "\n📥 Testing Video Download Process:"
puts "  🔍 Searching for recent completed videos..."

# Check if there are any project manifests
begin
  manifests = []
  s3_client.list_objects_v2(bucket: bucket_name, prefix: 'projects/').contents.each do |obj|
    if obj.key.end_with?('/manifest.json')
      manifests << obj.key
    end
  end
  
  puts "  📋 Found #{manifests.length} project manifests"
  
  if manifests.any?
    # Get the most recent manifest
    latest_manifest = manifests.sort.last
    puts "  📄 Latest manifest: #{latest_manifest}"
    
    # Try to download and parse it
    manifest_obj = s3_client.get_object(bucket: bucket_name, key: latest_manifest)
    manifest_data = JSON.parse(manifest_obj.body.read)
    
    puts "  🆔 Project ID: #{manifest_data['project_id']}"
    puts "  📅 Created: #{manifest_data['created_at']}"
    puts "  📝 Status: #{manifest_data['status'] || 'unknown'}"
    
    # Look for associated video files
    project_id = manifest_data['project_id']
    video_files = []
    
    s3_client.list_objects_v2(bucket: bucket_name, prefix: "projects/#{project_id}/").contents.each do |obj|
      if obj.key.end_with?('.mp4')
        video_files << obj.key
      end
    end
    
    puts "  🎬 Video files for this project: #{video_files.length}"
    video_files.each do |video_file|
      puts "    📹 #{video_file}"
      
      # Test download
      begin
        temp_path = "/tmp/test_download_#{File.basename(video_file)}"
        puts "    📥 Testing download to: #{temp_path}"
        
        s3_client.get_object(bucket: bucket_name, key: video_file, response_target: temp_path)
        
        if File.exist?(temp_path)
          file_size = File.size(temp_path)
          puts "    ✅ Download successful: #{(file_size / 1024.0 / 1024.0).round(2)} MB"
          
          # Test if it's a valid video file
          if system("ffprobe -v quiet '#{temp_path}' 2>/dev/null")
            puts "    ✅ Video file is valid"
          else
            puts "    ❌ Video file appears to be corrupted"
          end
          
          # Clean up
          File.delete(temp_path) if File.exist?(temp_path)
        else
          puts "    ❌ Download failed - file not created"
        end
      rescue => e
        puts "    ❌ Download error: #{e.message}"
      end
    end
  else
    puts "  ❌ No project manifests found"
  end
  
rescue => e
  puts "  ❌ Error checking manifests: #{e.message}"
end

# Check local completed directory
puts "\n📁 Local Completed Directory:"
completed_dir = "completed"
if Dir.exist?(completed_dir)
  files = Dir.entries(completed_dir).select { |f| f.end_with?('.mp4') }
  puts "  📊 Video files in completed/: #{files.length}"
  files.each do |file|
    file_path = File.join(completed_dir, file)
    puts "    📹 #{file}"
    puts "      📊 Size: #{(File.size(file_path) / 1024.0 / 1024.0).round(2)} MB"
    puts "      📅 Modified: #{File.mtime(file_path)}"
  end
else
  puts "  ❌ Completed directory does not exist"
end

# Test the download_video method specifically
puts "\n🧪 Testing S3Service.download_video Method:"
begin
  # Find a video file to test with
  video_key = nil
  s3_client.list_objects_v2(bucket: bucket_name, prefix: 'projects/').contents.each do |obj|
    if obj.key.end_with?('.mp4')
      video_key = obj.key
      break
    end
  end
  
  if video_key
    puts "  📹 Testing with video: #{video_key}"
    test_path = "test_download.mp4"
    
    result = s3_service.download_video(video_key, test_path)
    
    if result[:success]
      puts "  ✅ S3Service.download_video succeeded"
      puts "  📊 Downloaded file size: #{result[:file_size]} bytes"
      
      # Clean up
      File.delete(test_path) if File.exist?(test_path)
    else
      puts "  ❌ S3Service.download_video failed: #{result[:error]}"
    end
  else
    puts "  ❌ No video files found to test with"
  end
rescue => e
  puts "  ❌ Error testing download_video: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 Debug investigation complete"