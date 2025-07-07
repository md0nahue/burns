#!/usr/bin/env ruby

require_relative 'config/services'
require_relative 'lib/services/s3_service'
require 'json'

puts "🔍 DEBUG: Segment Data Investigation"
puts "=" * 60

# Initialize S3 service
s3_service = S3Service.new

# Check recent project manifests
bucket_name = Config::AWS_CONFIG[:s3_bucket]
puts "📦 Checking project manifests in S3 bucket: #{bucket_name}"

begin
  s3_client = Aws::S3::Client.new(
    region: Config::AWS_CONFIG[:region],
    credentials: Aws::Credentials.new(
      Config::AWS_CONFIG[:access_key_id],
      Config::AWS_CONFIG[:secret_access_key]
    )
  )
  
  # Find recent manifests
  manifests = []
  s3_client.list_objects_v2(bucket: bucket_name, prefix: 'projects/').contents.each do |obj|
    if obj.key.end_with?('/manifest.json')
      manifests << {
        key: obj.key,
        last_modified: obj.last_modified
      }
    end
  end
  
  puts "📋 Found #{manifests.length} project manifests"
  
  if manifests.any?
    # Get the most recent manifest
    latest_manifest = manifests.sort_by { |m| m[:last_modified] }.last
    puts "📄 Latest manifest: #{latest_manifest[:key]}"
    
    # Download and parse it
    manifest_obj = s3_client.get_object(bucket: bucket_name, key: latest_manifest[:key])
    manifest_data = JSON.parse(manifest_obj.body.read)
    
    puts "\n📊 Manifest Data:"
    puts "  🆔 Project ID: #{manifest_data['project_id']}"
    puts "  📅 Created: #{manifest_data['created_at']}"
    puts "  📝 Status: #{manifest_data['status'] || 'unknown'}"
    puts "  📊 Segments: #{manifest_data['segments']&.length || 0}"
    
    if manifest_data['segments'] && manifest_data['segments'].any?
      puts "\n🔍 Examining first segment structure:"
      first_segment = manifest_data['segments'].first
      puts "  📋 Segment keys: #{first_segment.keys.join(', ')}"
      
      puts "\n📝 Segment Details:"
      puts "  🆔 ID: #{first_segment['id']}"
      puts "  ⏰ Start: #{first_segment['start_time']}"
      puts "  ⏰ End: #{first_segment['end_time']}"
      puts "  📝 Text: #{first_segment['text']&.slice(0, 50)}..."
      
      if first_segment['generated_images']
        puts "  🖼️  Generated Images: #{first_segment['generated_images'].length}"
        if first_segment['generated_images'].any?
          first_image = first_segment['generated_images'].first
          puts "    📋 Image keys: #{first_image.keys.join(', ')}"
          puts "    🔗 URL: #{first_image['url'] || first_image[:url] || 'No URL found'}"
        end
      else
        puts "  ❌ No generated_images found"
      end
      
      puts "\n🧪 Simulating Lambda Payload Construction:"
      
      # Simulate what the Ruby code does to build segment data
      segments = manifest_data['segments']
      
      segments.each_with_index do |segment, index|
        puts "\n  📹 Segment #{index + 1}:"
        
        # Normalize keys for mixed string/symbol keys (from lambda_service.rb line 73)
        seg = segment.is_a?(Hash) ? segment.transform_keys(&:to_s) : segment
        
        puts "    📋 After key normalization: #{seg.keys.join(', ')}"
        
        # Extract timing data (from lambda_service.rb lines 79-86)
        start_time = (seg['start_time'] || seg['start'] || 0.0).to_f
        end_time = (seg['end_time'] || seg['end'] || 5.0).to_f
        
        if end_time <= start_time
          end_time = start_time + 3.0
        end
        duration = end_time - start_time
        
        puts "    ⏰ Timing: #{start_time}s - #{end_time}s (duration: #{duration}s)"
        
        # Build images array (from lambda_service.rb lines 89-95)
        generated_images = seg['generated_images'] || []
        images = generated_images.map do |img|
          img_data = img.is_a?(Hash) ? img.transform_keys(&:to_s) : img
          url = img_data['url'] || img_data[:url]
          { url: url } if url && !url.empty?
        end.compact
        
        puts "    🖼️  Images found: #{images.length}"
        images.each_with_index do |img, img_idx|
          puts "      #{img_idx + 1}. #{img[:url]}"
        end
        
        if images.empty?
          puts "    ⚠️  Warning: No images found for this segment"
        end
        
        # Build the final task data (from lambda_service.rb lines 102-111)
        task_data = {
          project_id: manifest_data['project_id'],
          segment_id: (seg['id'] || index).to_s,
          segment_index: index,
          images: images,
          duration: duration,
          start_time: start_time,
          end_time: end_time
        }
        
        puts "    📤 Lambda Payload Structure:"
        puts "      project_id: #{task_data[:project_id]}"
        puts "      segment_id: #{task_data[:segment_id]}"
        puts "      segment_index: #{task_data[:segment_index]}"
        puts "      images: #{task_data[:images].length} items"
        puts "      duration: #{task_data[:duration]}"
        puts "      start_time: #{task_data[:start_time]}"
        puts "      end_time: #{task_data[:end_time]}"
        
        # Show first 2 segments only to avoid clutter
        break if index >= 1
      end
    else
      puts "  ❌ No segments found in manifest"
    end
  else
    puts "  ❌ No project manifests found"
  end
  
rescue => e
  puts "❌ Error: #{e.message}"
end

puts "\n" + "=" * 60
puts "🏁 Segment data investigation complete"