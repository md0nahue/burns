#!/usr/bin/env ruby

require_relative 'config/services'
require_relative 'lib/services/lambda_service'
require 'json'

puts "🧪 Testing improved Lambda function..."

begin
  # Initialize Lambda service
  lambda_service = LambdaService.new
  puts "✅ Lambda service initialized"
  
  # Test with segment payload that includes multiple images
  puts "\n🎬 Testing with improved segment payload..."
  segment_payload = {
    project_id: 'test-improved',
    segment_id: '0',
    segment_index: 0,
    images: [
      { url: 'https://images.pexels.com/photos/269077/pexels-photo-269077.jpeg?auto=compress&cs=tinysrgb&h=650&w=940' },
      { url: 'https://images.pexels.com/photos/6753335/pexels-photo-6753335.jpeg?auto=compress&cs=tinysrgb&h=650&w=940' },
      { url: 'https://images.pexels.com/photos/12220471/pexels-photo-12220471.jpeg?auto=compress&cs=tinysrgb&h=650&w=940' }
    ],
    duration: 8.0,
    start_time: 0.0,
    end_time: 8.0,
    options: {
      segment_processing: true,
      resolution: '1080p',
      fps: 24
    }
  }
  
  puts "📤 Sending improved segment payload:"
  puts "  Project: #{segment_payload[:project_id]}"
  puts "  Segment: #{segment_payload[:segment_id]}"
  puts "  Images: #{segment_payload[:images].length} images"
  puts "  Duration: #{segment_payload[:duration]}s"
  
  segment_result = lambda_service.send(:invoke_lambda_function, segment_payload)
  
  if segment_result[:success]
    puts "✅ Improved segment test completed successfully"
    puts "  S3 Key: #{segment_result[:segment_s3_key]}"
    puts "  Video URL: #{segment_result[:video_url]}"
    puts "  Images used: #{segment_result[:images_used] || 'unknown'}"
  else
    puts "❌ Improved segment test failed: #{segment_result[:error]}"
    puts "  Error type: #{segment_result[:error_type]}" if segment_result[:error_type]
  end
  
rescue => e
  puts "❌ Error in improved Lambda testing: #{e.message}"
  puts "🔧 Backtrace: #{e.backtrace.first(5)}"
end

puts "\n🎯 Improved Lambda test complete!"