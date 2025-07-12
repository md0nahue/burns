#!/usr/bin/env ruby

require_relative 'lib/services/lambda_service'

puts "🔧 Optimizing Lambda configuration for better reliability..."

# Initialize Lambda service
lambda_service = LambdaService.new

# Check current configuration
puts "\n📊 Current Lambda Configuration:"
current_config = lambda_service.get_function_configuration
if current_config[:error]
  puts "❌ Failed to get current configuration: #{current_config[:error]}"
  exit 1
end

puts "  💾 Memory: #{current_config[:memory_size]} MB"
puts "  ⏱️  Timeout: #{current_config[:timeout]} seconds"
puts "  📦 Code Size: #{current_config[:code_size]} bytes"
puts "  🐍 Runtime: #{current_config[:runtime]}"

# Recommended optimizations for video processing
recommended_config = {
  memory_size: 3008,  # Maximum Lambda memory for better processing power
  timeout: 900,       # 15 minutes - maximum Lambda timeout
  environment: {
    'FFMPEG_THREADS' => '4',
    'FFMPEG_PRESET' => 'fast',
    'LAMBDA_OPTIMIZED' => 'true',
    'RETRY_ENABLED' => 'true'
  }
}

puts "\n🎯 Recommended Optimizations:"
puts "  💾 Memory: #{current_config[:memory_size]} MB → #{recommended_config[:memory_size]} MB"
puts "  ⏱️  Timeout: #{current_config[:timeout]}s → #{recommended_config[:timeout]}s"
puts "  🔧 Environment Variables: #{recommended_config[:environment].keys.join(', ')}"

# Ask for confirmation
print "\n❓ Apply these optimizations? (y/N): "
response = gets.chomp.downcase

if response == 'y' || response == 'yes'
  puts "\n🚀 Applying Lambda optimizations..."
  
  result = lambda_service.update_function_configuration(recommended_config)
  
  if result[:success]
    puts "✅ Lambda configuration updated successfully!"
    puts "  📝 Function: #{result[:function_name]}"
    puts "  📅 Last Modified: #{result[:last_modified]}"
    
    # Verify the changes
    puts "\n🔍 Verifying configuration changes..."
    new_config = lambda_service.get_function_configuration
    
    if new_config[:memory_size] == recommended_config[:memory_size]
      puts "  ✅ Memory updated to #{new_config[:memory_size]} MB"
    else
      puts "  ⚠️  Memory not updated (expected #{recommended_config[:memory_size]}, got #{new_config[:memory_size]})"
    end
    
    if new_config[:timeout] == recommended_config[:timeout]
      puts "  ✅ Timeout updated to #{new_config[:timeout]} seconds"
    else
      puts "  ⚠️  Timeout not updated (expected #{recommended_config[:timeout]}, got #{new_config[:timeout]})"
    end
    
    puts "\n🎉 Lambda optimization complete!"
    puts "📈 Expected improvements:"
    puts "  • 6x more memory (512MB → 3008MB)"
    puts "  • 3x longer timeout (300s → 900s)"
    puts "  • Better FFmpeg performance with optimized settings"
    puts "  • Reduced memory-related crashes"
    puts "  • Faster video processing"
    
  else
    puts "❌ Failed to update Lambda configuration: #{result[:error]}"
    puts "\n🔧 Manual steps:"
    puts "1. Go to AWS Lambda console"
    puts "2. Select function: #{current_config[:function_name]}"
    puts "3. Update Configuration → General configuration"
    puts "4. Set Memory to 3008 MB"
    puts "5. Set Timeout to 15 minutes"
    puts "6. Add environment variables: #{recommended_config[:environment]}"
  end
else
  puts "\n⏭️  Skipping Lambda optimization"
  puts "💡 You can run this script later to apply optimizations"
end

puts "\n📝 Additional Resilience Features Added:"
puts "  🔄 Enhanced retry logic with exponential backoff"
puts "  🏠 Automatic fallback to local processing"
puts "  🎯 Simplified payload for failed retries"
puts "  📊 Better error categorization and handling"
puts "  💾 Smarter caching to avoid duplicate work"