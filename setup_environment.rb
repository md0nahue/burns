#!/usr/bin/env ruby

# Setup script to check and configure environment for Ken Burns video generation
puts "🔧 Burns - Environment Setup for Ken Burns Video Generation"
puts "=" * 60

# Required environment variables
required_vars = {
  'GROQ_API_KEY' => 'Groq API key for Whisper transcription',
  'GEMINI_API_KEY' => 'Gemini API key for content analysis',
  'AWS_ACCESS_KEY_ID' => 'AWS Access Key ID',
  'AWS_SECRET_ACCESS_KEY' => 'AWS Secret Access Key',
  'AWS_REGION' => 'AWS Region (default: us-east-1)'
}

# Optional environment variables
optional_vars = {
  'UNSPLASH_API_KEY' => 'Unsplash API key for high-quality images',
  'PEXELS_API_KEY' => 'Pexels API key for additional image sources',
  'PIXABAY_API_KEY' => 'Pixabay API key for more image variety',
  'LAMBDA_FUNCTION' => 'Lambda function name (default: ken-burns-video-generator)',
  'S3_BUCKET' => 'S3 bucket name (default: burns-videos)',
  'S3_LIFECYCLE_DAYS' => 'S3 lifecycle days (default: 14)'
}

puts "\n📋 Checking required environment variables..."
puts "=" * 40

all_good = true

required_vars.each do |var, description|
  if ENV[var]
    puts "✅ #{var}: Configured"
  else
    puts "❌ #{var}: Missing - #{description}"
    all_good = false
  end
end

puts "\n📋 Checking optional environment variables..."
puts "=" * 40

optional_vars.each do |var, description|
  if ENV[var]
    puts "✅ #{var}: Configured"
  else
    puts "⚠️  #{var}: Not set - #{description}"
  end
end

# Check for sad.m4a file
puts "\n📁 Checking for audio file..."
puts "=" * 40

if File.exist?('sad.m4a')
  file_size = (File.size('sad.m4a') / 1024.0 / 1024.0).round(2)
  puts "✅ sad.m4a: Found (#{file_size} MB)"
else
  puts "❌ sad.m4a: Not found in current directory"
  all_good = false
end

# Check Ruby dependencies
puts "\n💎 Checking Ruby dependencies..."
puts "=" * 40

begin
  require 'json'
  puts "✅ json: Available"
rescue LoadError
  puts "❌ json: Missing"
  all_good = false
end

begin
  require 'securerandom'
  puts "✅ securerandom: Available"
rescue LoadError
  puts "❌ securerandom: Missing"
  all_good = false
end

# Check if we can load the main components
puts "\n🔧 Checking pipeline components..."
puts "=" * 40

begin
  require_relative 'lib/pipeline/video_generator'
  puts "✅ VideoGenerator: Available"
rescue LoadError => e
  puts "❌ VideoGenerator: #{e.message}"
  all_good = false
end

begin
  require_relative 'config/services'
  puts "✅ Services config: Available"
rescue LoadError => e
  puts "❌ Services config: #{e.message}"
  all_good = false
end

# Summary
puts "\n" + "=" * 60
if all_good
  puts "🎉 ENVIRONMENT SETUP COMPLETE!"
  puts "✅ All required components are configured"
  puts "🚀 Ready to run: ruby process_sad_audio.rb"
  puts "=" * 60
else
  puts "❌ ENVIRONMENT SETUP INCOMPLETE"
  puts "🔧 Please fix the issues above before running the pipeline"
  puts "📖 Check the documentation for setup instructions"
  puts "=" * 60
  exit 1
end

puts "\n💡 Quick start commands:"
puts "  ruby setup_environment.rb    # Check environment (this script)"
puts "  ruby process_sad_audio.rb    # Generate Ken Burns video"
puts "  ruby demo_complete_pipeline.rb sad.m4a  # Alternative demo script"
puts "\n🎬 Happy video generating!" 