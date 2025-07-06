#!/usr/bin/env ruby

require_relative 'lib/services/lambda_service'
require_relative 'config/services'

# Test script for Lambda service
puts "🧪 Testing Lambda Service"
puts "=" * 40

# Initialize Lambda service
lambda_service = LambdaService.new

# Test 1: Check Lambda function status
puts "\n📋 Test 1: Checking Lambda function status..."
status_result = lambda_service.check_function_status

if status_result[:success]
  puts "✅ Lambda function status check passed"
  puts "  📝 Function: #{status_result[:function_name]}"
  puts "  🐍 Runtime: #{status_result[:runtime]}"
  puts "  ⏱️  Timeout: #{status_result[:timeout]} seconds"
  puts "  💾 Memory: #{status_result[:memory_size]} MB"
  puts "  🔄 State: #{status_result[:state]}"
else
  puts "❌ Lambda function status check failed: #{status_result[:error]}"
  puts "  💡 Make sure the Lambda function is deployed and accessible"
end

# Test 2: Get function configuration
puts "\n📋 Test 2: Getting function configuration..."
config_result = lambda_service.get_function_configuration

if config_result[:function_name]
  puts "✅ Function configuration retrieved"
  puts "  📝 Function: #{config_result[:function_name]}"
  puts "  🔗 ARN: #{config_result[:function_arn]}"
  puts "  🐍 Runtime: #{config_result[:runtime]}"
  puts "  📝 Handler: #{config_result[:handler]}"
  puts "  💾 Code Size: #{config_result[:code_size]} bytes"
  puts "  ⏱️  Timeout: #{config_result[:timeout]} seconds"
  puts "  💾 Memory: #{config_result[:memory_size]} MB"
  puts "  📅 Last Modified: #{config_result[:last_modified]}"
else
  puts "❌ Failed to get function configuration: #{config_result[:error]}"
end

# Test 3: Test Lambda function with sample data
puts "\n📋 Test 3: Testing Lambda function with sample data..."
test_result = lambda_service.test_function('test-project-123')

if test_result[:success]
  puts "✅ Lambda function test completed"
  puts "  📊 Response received successfully"
else
  puts "❌ Lambda function test failed: #{test_result[:error]}"
  puts "  💡 This is expected if no test project exists in S3"
end

# Test 4: List recent invocations
puts "\n📋 Test 4: Listing recent invocations..."
invocations_result = lambda_service.list_recent_invocations(5)

if invocations_result[:success]
  puts "✅ Invocations list retrieved"
  puts "  📊 Log Group: #{invocations_result[:log_group]}"
  puts "  📋 Max Items: #{invocations_result[:max_items]}"
else
  puts "❌ Failed to list invocations: #{invocations_result[:error]}"
end

# Test 5: Test video generation (requires existing project)
puts "\n📋 Test 5: Testing video generation..."
puts "  💡 This test requires an existing project in S3"
puts "  💡 Create a project first using the full pipeline demo"

# Uncomment to test with a real project ID
# video_result = lambda_service.generate_video('your-project-id-here')
# if video_result[:success]
#   puts "✅ Video generation test completed"
#   puts "  📹 Video URL: #{video_result[:video_url]}"
#   puts "  ⏱️  Duration: #{video_result[:duration]} seconds"
# else
#   puts "❌ Video generation test failed: #{video_result[:error]}"
# end

puts "\n" + "=" * 40
puts "🧪 Lambda service tests completed!"
puts "=" * 40

# Summary
puts "\n📊 Test Summary:"
puts "  ✅ Function Status: #{status_result[:success] ? 'PASS' : 'FAIL'}"
puts "  ✅ Configuration: #{config_result[:function_name] ? 'PASS' : 'FAIL'}"
puts "  ✅ Function Test: #{test_result[:success] ? 'PASS' : 'FAIL'}"
puts "  ✅ Invocations: #{invocations_result[:success] ? 'PASS' : 'FAIL'}"

if status_result[:success] && config_result[:function_name]
  puts "\n🎉 Lambda service is ready for video generation!"
  puts "  💡 Deploy the Lambda function to enable video generation"
  puts "  💡 Use the complete pipeline demo to test end-to-end functionality"
else
  puts "\n⚠️  Lambda service needs configuration"
  puts "  💡 Check AWS credentials and Lambda function deployment"
  puts "  💡 Ensure the Lambda function is properly configured"
end 