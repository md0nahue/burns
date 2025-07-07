#!/usr/bin/env ruby

require_relative 'config/services'
require_relative 'lib/services/lambda_service'
require 'json'

puts "🧪 Testing Lambda function directly..."

begin
  # Initialize Lambda service
  lambda_service = LambdaService.new
  puts "✅ Lambda service initialized"
  
  # Check function status
  puts "\n🔍 Checking Lambda function status..."
  status = lambda_service.check_function_status
  
  if status[:success]
    puts "✅ Lambda function is available and accessible"
  else
    puts "❌ Lambda function not accessible: #{status[:error]}"
    exit 1
  end
  
  # Test with simple payload
  puts "\n🧪 Testing with simple payload..."
  test_result = lambda_service.test_function('test-project-123')
  
  if test_result[:success]
    puts "✅ Simple test completed successfully"
  else
    puts "❌ Simple test failed: #{test_result[:error]}"
  end
  
  # Test with segment payload (similar to what pipeline sends)
  puts "\n🎬 Testing with segment payload..."
  segment_payload = {
    project_id: 'test-cooper',
    segment_id: '0',
    segment_index: 0,
    images: [
      { url: 'https://images.pexels.com/photos/269077/pexels-photo-269077.jpeg?auto=compress&cs=tinysrgb&h=650&w=940' }
    ],
    duration: 3.86,
    start_time: 0.0,
    end_time: 3.86,
    options: {
      segment_processing: true,
      resolution: '1080p',
      fps: 24
    }
  }
  
  puts "📤 Sending segment payload:"
  puts "  Project: #{segment_payload[:project_id]}"
  puts "  Segment: #{segment_payload[:segment_id]}"
  puts "  Images: #{segment_payload[:images].length}"
  puts "  Duration: #{segment_payload[:duration]}s"
  
  segment_result = lambda_service.send(:invoke_lambda_function, segment_payload)
  
  if segment_result[:success]
    puts "✅ Segment test completed successfully"
    puts "  S3 Key: #{segment_result[:segment_s3_key]}"
    puts "  Video URL: #{segment_result[:video_url]}"
  else
    puts "❌ Segment test failed: #{segment_result[:error]}"
    puts "  Error type: #{segment_result[:error_type]}" if segment_result[:error_type]
  end
  
  # Get function configuration
  puts "\n📋 Getting function configuration..."
  config = lambda_service.get_function_configuration
  
  unless config[:error]
    puts "  Function: #{config[:function_name]}"
    puts "  Runtime: #{config[:runtime]}"
    puts "  Timeout: #{config[:timeout]}s"
    puts "  Memory: #{config[:memory_size]}MB"
    puts "  Handler: #{config[:handler]}"
    puts "  Environment vars: #{config[:environment].keys.join(', ')}"
  end
  
rescue => e
  puts "❌ Error in Lambda testing: #{e.message}"
  puts "🔧 Backtrace: #{e.backtrace.first(5)}"
end

puts "\n🎯 Lambda direct test complete!"