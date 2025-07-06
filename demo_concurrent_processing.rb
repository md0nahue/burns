#!/usr/bin/env ruby

require_relative 'lib/pipeline/video_generator'
require_relative 'config/services'

# Demo script for concurrent Lambda processing
puts "⚡ Burns - Concurrent Lambda Processing Demo"
puts "=" * 60

# Initialize video generator
generator = VideoGenerator.new

# Demo options
demo_options = {
  resolution: '1080p',
  fps: 24,
  max_concurrency: nil,  # Let the system calculate optimal concurrency
  test_mode: true
}

# Check if audio file is provided as argument
audio_file = ARGV[0]

if audio_file && File.exist?(audio_file)
  puts "📁 Using provided audio file: #{audio_file}"
else
  puts "❌ No valid audio file provided"
  puts "Usage: ruby demo_concurrent_processing.rb <audio_file_path>"
  puts "Example: ruby demo_concurrent_processing.rb sample_audio.mp3"
  exit 1
end

puts "\n🚀 Starting concurrent processing demo..."
puts "  📁 Audio file: #{audio_file}"
puts "  ⚡ Concurrency: #{demo_options[:max_concurrency] || 'Auto-calculated (unlimited Lambda scaling)'}"
puts "  ⚙️  Options: #{demo_options}"

# Step 1: Process audio and generate images (same as before)
puts "\n" + "=" * 50
puts "STEP 1: Audio Processing & Image Generation"
puts "=" * 50

# This would normally be done by the full pipeline
# For demo purposes, we'll simulate having a project ready
project_id = "demo_concurrent_#{Time.now.strftime('%Y%m%d_%H%M%S')}"

puts "  🎵 Processing audio and generating images..."
puts "  🆔 Project ID: #{project_id}"
puts "  📝 This step creates segments and images (simulated)"

# Step 2: Demonstrate concurrent vs sequential processing
puts "\n" + "=" * 50
puts "STEP 2: Concurrent vs Sequential Processing"
puts "=" * 50

# Simulate segments (in real usage, these would come from the manifest)
simulated_segments = [
  {
    id: 'segment_1',
    start_time: 0.0,
    end_time: 30.0,
    generated_images: [
      { s3_key: 'projects/demo/images/segment_1_1.jpg', query: 'documentary', provider: 'unsplash' },
      { s3_key: 'projects/demo/images/segment_1_2.jpg', query: 'filmmaking', provider: 'pexels' }
    ]
  },
  {
    id: 'segment_2',
    start_time: 30.0,
    end_time: 60.0,
    generated_images: [
      { s3_key: 'projects/demo/images/segment_2_1.jpg', query: 'cinema', provider: 'pixabay' },
      { s3_key: 'projects/demo/images/segment_2_2.jpg', query: 'camera', provider: 'unsplash' }
    ]
  },
  {
    id: 'segment_3',
    start_time: 60.0,
    end_time: 90.0,
    generated_images: [
      { s3_key: 'projects/demo/images/segment_3_1.jpg', query: 'director', provider: 'pexels' },
      { s3_key: 'projects/demo/images/segment_3_2.jpg', query: 'movie set', provider: 'pixabay' }
    ]
  },
  {
    id: 'segment_4',
    start_time: 90.0,
    end_time: 120.0,
    generated_images: [
      { s3_key: 'projects/demo/images/segment_4_1.jpg', query: 'editing', provider: 'unsplash' },
      { s3_key: 'projects/demo/images/segment_4_2.jpg', query: 'post production', provider: 'pexels' }
    ]
  },
  {
    id: 'segment_5',
    start_time: 120.0,
    end_time: 150.0,
    generated_images: [
      { s3_key: 'projects/demo/images/segment_5_1.jpg', query: 'final cut', provider: 'pixabay' },
      { s3_key: 'projects/demo/images/segment_5_2.jpg', query: 'premiere', provider: 'unsplash' }
    ]
  }
]

puts "  📊 Simulated segments: #{simulated_segments.length}"
puts "  ⏱️  Total duration: #{simulated_segments.last[:end_time]} seconds"

# Step 3: Test concurrent processing
puts "\n" + "=" * 50
puts "STEP 3: Concurrent Lambda Processing"
puts "=" * 50

begin
  # Initialize Lambda service
  lambda_service = LambdaService.new
  
  # Test concurrent processing
  puts "  🚀 Starting concurrent segment processing..."
  start_time = Time.now
  
  result = lambda_service.generate_video_segments_concurrently(
    project_id, 
    simulated_segments, 
    demo_options.merge(total_segments: simulated_segments.length)
  )
  
  end_time = Time.now
  processing_time = end_time - start_time
  
  if result[:success]
    puts "  ✅ Concurrent processing completed successfully!"
    puts "  ⏱️  Processing time: #{processing_time.round(2)} seconds"
    puts "  📹 Video URL: #{result[:video_url]}"
    puts "  ⚡ Segments processed concurrently: #{simulated_segments.length}"
    puts "  🎬 Final video duration: #{result[:duration]} seconds"
  else
    puts "  ❌ Concurrent processing failed: #{result[:error]}"
    puts "  💡 This is expected if Lambda functions aren't deployed yet"
  end
  
rescue => e
  puts "  ❌ Error in concurrent processing: #{e.message}"
  puts "  💡 Make sure Lambda functions are deployed and configured"
end

# Step 4: Performance comparison
puts "\n" + "=" * 50
puts "STEP 4: Performance Analysis"
puts "=" * 50

# Calculate theoretical performance improvements
sequential_time = simulated_segments.length * 30  # Assume 30 seconds per segment
optimal_concurrency = demo_options[:max_concurrency] || simulated_segments.length
concurrent_time = (simulated_segments.length / optimal_concurrency.to_f).ceil * 30
improvement = ((sequential_time - concurrent_time) / sequential_time.to_f * 100).round(2)

puts "  📊 Performance Analysis:"
puts "    📝 Segments: #{simulated_segments.length}"
puts "    ⚡ Concurrency: #{optimal_concurrency} (unlimited Lambda scaling)"
puts "    ⏱️  Sequential (estimated): #{sequential_time} seconds"
puts "    ⚡ Concurrent (estimated): #{concurrent_time} seconds"
puts "    📈 Performance improvement: #{improvement}%"

# Step 5: Architecture explanation
puts "\n" + "=" * 50
puts "STEP 5: Concurrent Architecture"
puts "=" * 50

puts "  🏗️  How concurrent processing works:"
puts "    1. 📝 Ruby splits project into #{optimal_concurrency} concurrent tasks"
puts "    2. 🚀 Each task invokes a separate Lambda function"
puts "    3. 📹 Each Lambda processes one video segment independently"
puts "    4. ⏳ Ruby waits for all segments to complete"
puts "    5. 🎬 Final Lambda combines segments and adds audio"
puts "    6. 📤 Final video uploaded to S3"

puts "\n  💡 Benefits:"
puts "    ⚡ Faster processing (parallel execution)"
puts "    🔄 Better resource utilization"
puts "    🛡️  Fault tolerance (failed segments don't stop others)"
puts "    📈 Scalable (can handle more segments efficiently)"

puts "\n" + "=" * 60
puts "🎉 Concurrent processing demo completed!"
puts "💡 Deploy Lambda functions to test with real data"
puts "=" * 60 