#!/usr/bin/env ruby

require_relative 'lib/services/s3_service'

puts "🔍 Debugging vibe3 segments in S3..."

s3_service = S3Service.new

# Check what segments exist in S3
begin
  bucket_name = 'burns-videos'
  prefix = 'segments/vibe3/'
  
  puts "📂 Checking S3 bucket '#{bucket_name}' for segments with prefix '#{prefix}'"
  
  objects = s3_service.instance_variable_get(:@s3_client).list_objects_v2(
    bucket: bucket_name,
    prefix: prefix
  )
  
  if objects.contents.any?
    puts "✅ Found #{objects.contents.length} segment files:"
    objects.contents.each do |obj|
      puts "  📁 #{obj.key} (#{obj.size} bytes, modified: #{obj.last_modified})"
    end
    
    # Extract segment numbers from file names
    segment_numbers = objects.contents.map do |obj|
      if obj.key =~ /(\d+)_segment\.mp4$/
        $1.to_i
      end
    end.compact.sort
    
    puts "\n📊 Available segment numbers: #{segment_numbers.join(', ')}"
    puts "📊 Total available segments: #{segment_numbers.length}/57"
    
    missing_segments = (0..56).to_a - segment_numbers
    puts "❌ Missing segments: #{missing_segments.join(', ')}" if missing_segments.any?
    
  else
    puts "❌ No segment files found in S3"
  end
  
rescue => e
  puts "❌ Error checking S3: #{e.message}"
end