#!/usr/bin/env ruby

require_relative 'lib/services/local_video_service'

# Test Ken Burns variety locally
puts "🎬 Testing Ken Burns variety effects locally..."

# Create test service
service = LocalVideoService.new

# Create test image if it doesn't exist
test_image_path = "/tmp/test_image.jpg"
unless File.exist?(test_image_path)
  puts "🎨 Creating test image..."
  system("ffmpeg -f lavfi -i 'color=c=blue:s=1920x1080:d=1' -frames:v 1 -y #{test_image_path}")
end

# Test different effects
effects = [
  { duration: 3.0, name: "3 second test" },
  { duration: 5.0, name: "5 second test" },
  { duration: 7.0, name: "7 second test" }
]

effects.each_with_index do |effect, index|
  puts "\n🎥 Testing effect #{index + 1}: #{effect[:name]}"
  
  output_path = "/tmp/test_ken_burns_#{index + 1}.mp4"
  
  # Test the private method directly
  service.send(:create_single_image_ken_burns, test_image_path, effect[:duration], output_path)
  
  if File.exist?(output_path)
    puts "✅ Created test video: #{output_path}"
    puts "📄 File size: #{File.size(output_path) / 1024} KB"
  else
    puts "❌ Failed to create test video"
  end
end

puts "\n✅ Ken Burns variety test completed!"
puts "🎬 Test videos created in /tmp/ directory"