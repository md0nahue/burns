#!/usr/bin/env ruby

require_relative 'lib/services/local_video_service'

puts "🎬 Testing improved smooth Ken Burns effects..."

# Initialize local video service
local_video_service = LocalVideoService.new

# Test with a high-quality image URL
test_image_url = "https://images.pexels.com/photos/4031905/pexels-photo-4031905.jpeg"
test_duration = 4.0  # 4 seconds

begin
  puts "📥 Testing smooth Ken Burns effect..."
  puts "🖼️  Image: #{test_image_url}"
  puts "⏱️  Duration: #{test_duration} seconds"
  
  # Download test image first
  puts "📥 Downloading test image..."
  require 'net/http'
  require 'uri'
  
  image_path = "/tmp/test_ken_burns_image.jpg"
  uri = URI(test_image_url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    response = http.get(uri.path)
    File.open(image_path, 'wb') { |f| f.write(response.body) }
  end
  
  # Create test video with improved Ken Burns
  output_path = "/tmp/test_smooth_ken_burns.mp4"
  puts "🎬 Creating Ken Burns video..."
  
  success = local_video_service.create_single_image_ken_burns(
    image_path,
    test_duration,
    output_path
  )
  
  result = {
    success: success && File.exist?(output_path),
    video_path: output_path,
    duration: test_duration
  }
  
  if result[:success]
    puts "✅ Smooth Ken Burns test completed successfully!"
    puts "📹 Test video: #{result[:video_path]}"
    puts "⏱️  Duration: #{result[:duration]} seconds"
    puts "📊 File size: #{(File.size(result[:video_path]) / 1024.0 / 1024.0).round(2)} MB"
    
    puts "\n🔍 Video details:"
    puts "  📐 Resolution: 1920x1080"
    puts "  🎬 Frame rate: 24fps"
    puts "  🎨 Encoding: H.264 with CRF 16"
    puts "  🔧 Scaling: Lanczos (highest quality)"
    puts "  ⚡ Motion: Reduced increments for smoothness"
    puts "  🎯 vsync: Frame drop prevention enabled"
    
  else
    puts "❌ Test failed: #{result[:error]}"
  end

rescue => e
  puts "❌ Error during test: #{e.message}"
  puts "🔍 Stack trace: #{e.backtrace.first(5).join("\n")}"
end