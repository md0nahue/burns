require_relative '../image_service_bus'
require_relative '../../config'
require 'digest'
require 'json'

class ImageGenerator
  def initialize(image_service_bus = nil)
    @image_service_bus = image_service_bus || ImageServiceBus.new(Config::IMAGE_SERVICE_CONFIG)
  end

  # Generate images for all segments in the enhanced audio result
  # @param enhanced_result [Hash] Enhanced audio result with image queries
  # @param options [Hash] Generation options
  # @return [Hash] Result with generated images
  def generate_images_for_segments(enhanced_result, options = {})
    puts "🖼️  Generating images for segments..."
    
    segments = enhanced_result[:segments]
    generated_segments = []
    
    puts "    🔍 ImageGenerator: Processing #{segments.length} segments"
    
    segments.each_with_index do |segment, index|
      puts "  Generating images for segment #{index + 1}/#{segments.length}"
      
      begin
        # Generate images for this segment
        generated_segment = generate_images_for_segment(segment, options)
        generated_segments << generated_segment
        
        # Add delay to respect rate limits
        sleep(options[:delay] || 1) if index < segments.length - 1
      rescue => e
        puts "    ❌ ImageGenerator: Error processing segment #{index}: #{e.message}"
        puts "    ❌ ImageGenerator: Error class: #{e.class}"
        puts "    ❌ ImageGenerator: Error backtrace: #{e.backtrace.first(5)}"
        # Continue with next segment
        generated_segments << segment.merge({
          generated_images: [],
          images_generated: 0,
          generation_success: false,
          error: e.message
        })
      end
    end
    
    # Calculate generation metrics
    generation_metrics = calculate_generation_metrics(generated_segments)
    
    # Create final result
    final_result = enhanced_result.merge({
      segments: generated_segments,
      generation_metrics: generation_metrics,
      total_images_generated: generated_segments.sum { |s| s[:generated_images].length },
      segments_with_images: generated_segments.count { |s| s[:generated_images].any? }
    })
    
    puts "✅ Image generation completed:"
    puts "  📊 Total segments: #{generated_segments.length}"
    puts "  🖼️  Segments with images: #{final_result[:segments_with_images]}"
    puts "  🎯 Total images generated: #{final_result[:total_images_generated]}"
    puts "  📈 Success rate: #{(final_result[:segments_with_images].to_f / generated_segments.length * 100).round(1)}%"
    
    final_result
  end

  # Generate images for a single segment with fallback support
  # @param segment [Hash] Audio segment with image queries
  # @param options [Hash] Generation options
  # @return [Hash] Segment with generated images
  def generate_images_for_segment(segment, options = {})
    puts "    📝 Processing segment: #{segment[:id]}"
    puts "      Debug - segment keys: #{segment.keys}"
    puts "      Debug - image_queries: #{segment[:image_queries].inspect}"
    
    # Normalize segment keys to symbols
    normalized_segment = {}
    segment.each do |key, value|
      normalized_segment[key.to_sym] = value
    end
    
    # Ensure image_queries is an array
    image_queries = if normalized_segment[:image_queries].is_a?(Array)
      normalized_segment[:image_queries]
    elsif normalized_segment[:image_query]
      [normalized_segment[:image_query]]
    else
      []
    end
    
    puts "      Debug - final image_queries: #{image_queries.inspect}"
    
    resolution = options[:resolution] || '1080p'
    
    # Only get ONE image per segment - use the first query
    if image_queries.empty?
      puts "      ⚠️  No image queries for segment"
      return normalized_segment.merge({
        generated_images: [],
        images_generated: 0,
        generation_success: false
      })
    end
    
    # Check cache first
    cache_key = generate_cache_key(normalized_segment, resolution)
    cached_result = get_cached_images(cache_key)
    
    if cached_result
      puts "      💾 Using cached images for segment #{normalized_segment[:id]}"
      return cached_result
    end
    
    # Try all queries with fallback strategy
    generated_images = []
    all_queries = image_queries + (normalized_segment[:backup_queries] || [])
    
    puts "      Searching for ONE image with #{all_queries.length} query options"
    
    all_queries.each_with_index do |query, query_index|
      next if generated_images.any? # Stop once we have an image
      
      puts "      Trying query #{query_index + 1}/#{all_queries.length}: '#{query}'"
      
      begin
        # Use the image service bus to get ONE image
        results = @image_service_bus.get_images(query, 1, resolution)
        
        # Process results and take only the first image
        results.each do |result|
          if result && result[:images] && !result[:images].empty?
            # Take only the first image from the first successful provider
            image = result[:images].first
            
            # Skip placeholder/low quality images
            next if is_placeholder_image?(image)
            
            enriched_image = image.merge({
              query: query,
              query_index: query_index,
              segment_id: normalized_segment[:id],
              start_time: normalized_segment[:start_time],
              end_time: normalized_segment[:end_time],
              generated_at: Time.now
            })
            
            generated_images << enriched_image
            puts "      ✅ Found quality image from #{result[:provider]}: #{image[:url]}"
            break # Only take the first successful result
          end
        end
        
      rescue => e
        puts "      ❌ Error with query '#{query}': #{e.message}"
        # Continue to next query
      end
    end
    
    if generated_images.empty?
      puts "      ⚠️  No quality images found for any query, using emergency fallback"
      generated_images = get_emergency_fallback_image(normalized_segment, resolution)
    end
    
    # Cache the result
    result = normalized_segment.merge({
      generated_images: generated_images,
      images_generated: generated_images.length,
      generation_success: generated_images.any?
    })
    
    cache_images(cache_key, result) if generated_images.any?
    
    result
  end

  # Get generation summary for debugging
  # @param final_result [Hash] Final result with generated images
  # @return [Hash] Generation summary
  def get_generation_summary(final_result)
    segments = final_result[:segments]
    
    summary = {
      total_segments: segments.length,
      segments_with_images: segments.count { |s| s[:generation_success] },
      total_images_generated: segments.sum { |s| s[:generated_images].length },
      average_images_per_segment: segments.sum { |s| s[:generated_images].length }.to_f / segments.length,
      success_rate: segments.count { |s| s[:generation_success] }.to_f / segments.length,
      provider_distribution: get_provider_distribution(segments),
      resolution_distribution: get_resolution_distribution(segments),
      failed_queries: get_failed_queries(segments)
    }
    
    summary
  end

  # Validate generation results
  # @param final_result [Hash] Final result with generated images
  # @return [Hash] Validation results
  def validate_generation(final_result)
    segments = final_result[:segments]
    issues = []
    
    # Check for segments without generated images
    segments_without_images = segments.select { |s| !s[:generation_success] }
    if segments_without_images.any?
      issues << {
        type: :segments_without_images,
        count: segments_without_images.length,
        segments: segments_without_images.map { |s| { id: s[:id], queries: s[:image_queries] } }
      }
    end
    
    # Check for segments with too few images
    segments_with_few_images = segments.select { |s| s[:generated_images].length < s[:image_queries].length }
    if segments_with_few_images.any?
      issues << {
        type: :segments_with_few_images,
        count: segments_with_few_images.length,
        segments: segments_with_few_images.map { |s| { id: s[:id], expected: s[:image_queries].length, actual: s[:generated_images].length } }
      }
    end
    
    # Check for low-quality images (based on resolution)
    low_res_images = segments.flat_map { |s| s[:generated_images] }.select { |img| img[:width] < 1920 || img[:height] < 1080 }
    if low_res_images.any?
      issues << {
        type: :low_resolution_images,
        count: low_res_images.length,
        images: low_res_images.map { |img| { url: img[:url], width: img[:width], height: img[:height] } }
      }
    end
    
    {
      valid: issues.empty?,
      issues: issues,
      total_issues: issues.sum { |i| i[:count] }
    }
  end

  # Get client status from image service bus
  # @return [Hash] Client status
  def get_client_status
    @image_service_bus.client_status
  end

  private

  # Generate cache key for segment images
  # @param segment [Hash] Segment data
  # @param resolution [String] Resolution setting
  # @return [String] Cache key
  def generate_cache_key(segment, resolution)
    content = "#{segment[:id]}_#{segment[:text]}_#{segment[:image_queries].join('_')}_#{resolution}"
    Digest::MD5.hexdigest(content)
  end

  # Get cached images for segment
  # @param cache_key [String] Cache key
  # @return [Hash] Cached result or nil
  def get_cached_images(cache_key)
    cache_dir = 'cache/images'
    require 'fileutils'
    FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
    cache_file = "#{cache_dir}/#{cache_key}.json"
    
    return nil unless File.exist?(cache_file)
    
    begin
      JSON.parse(File.read(cache_file), symbolize_names: true)
    rescue
      nil
    end
  end

  # Cache images for segment
  # @param cache_key [String] Cache key
  # @param result [Hash] Result to cache
  def cache_images(cache_key, result)
    cache_dir = 'cache/images'
    require 'fileutils'
    FileUtils.mkdir_p(cache_dir) unless Dir.exist?(cache_dir)
    cache_file = "#{cache_dir}/#{cache_key}.json"
    
    begin
      File.write(cache_file, JSON.pretty_generate(result))
    rescue => e
      puts "      ⚠️ Failed to cache images: #{e.message}"
    end
  end

  # Check if image is likely a placeholder
  # @param image [Hash] Image data
  # @return [Boolean] True if likely placeholder
  def is_placeholder_image?(image)
    url = image[:url] || image['url']
    return true if url.nil? || url.empty?
    
    # Check for common placeholder patterns
    placeholder_patterns = [
      /placeholder/i,
      /default/i,
      /notfound/i,
      /404/i,
      /missing/i,
      /unavailable/i
    ]
    
    placeholder_patterns.any? { |pattern| url.match?(pattern) }
  end

  # Get emergency fallback image
  # @param segment [Hash] Segment data
  # @param resolution [String] Resolution setting
  # @return [Array] Emergency fallback images
  def get_emergency_fallback_image(segment, resolution)
    # Use a high-quality stock image as emergency fallback
    fallback_queries = [
      "abstract background design",
      "minimalist texture pattern",
      "soft gradient background"
    ]
    
    fallback_queries.each do |query|
      begin
        results = @image_service_bus.get_images(query, 1, resolution)
        results.each do |result|
          if result && result[:images] && !result[:images].empty?
            image = result[:images].first
            return [image.merge({
              query: query,
              query_index: 999, # Mark as emergency fallback
              segment_id: segment[:id],
              start_time: segment[:start_time],
              end_time: segment[:end_time],
              generated_at: Time.now,
              is_fallback: true
            })]
          end
        end
      rescue
        # Continue to next fallback
      end
    end
    
    # Ultimate fallback - return empty but mark as attempted
    []
  end

  # Calculate generation metrics
  # @param generated_segments [Array] Segments with generated images
  # @return [Hash] Generation metrics
  def calculate_generation_metrics(generated_segments)
    return {} if generated_segments.empty?
    
    total_images = generated_segments.sum { |s| s[:generated_images].length }
    successful_segments = generated_segments.count { |s| s[:generation_success] }
    total_queries = generated_segments.sum { |s| s[:image_queries].length }
    
    {
      total_segments: generated_segments.length,
      successful_segments: successful_segments,
      success_rate: successful_segments.to_f / generated_segments.length,
      total_images_generated: total_images,
      total_queries: total_queries,
      average_images_per_segment: total_images.to_f / generated_segments.length,
      average_images_per_query: total_queries > 0 ? total_images.to_f / total_queries : 0
    }
  end

  # Get provider distribution
  # @param segments [Array] Segments with generated images
  # @return [Hash] Provider distribution
  def get_provider_distribution(segments)
    provider_counts = Hash.new(0)
    
    segments.each do |segment|
      segment[:generated_images].each do |image|
        provider = image[:provider] || 'unknown'
        provider_counts[provider] += 1
      end
    end
    
    provider_counts
  end

  # Get resolution distribution
  # @param segments [Array] Segments with generated images
  # @return [Hash] Resolution distribution
  def get_resolution_distribution(segments)
    resolution_counts = Hash.new(0)
    
    segments.each do |segment|
      segment[:generated_images].each do |image|
        width = image[:width] || 0
        height = image[:height] || 0
        
        if width >= 3840 && height >= 2160
          resolution_counts['4K'] += 1
        elsif width >= 1920 && height >= 1080
          resolution_counts['1080p'] += 1
        elsif width >= 1280 && height >= 720
          resolution_counts['720p'] += 1
        else
          resolution_counts['SD'] += 1
        end
      end
    end
    
    resolution_counts
  end

  # Get failed queries
  # @param segments [Array] Segments with generated images
  # @return [Array] Failed queries
  def get_failed_queries(segments)
    failed_queries = []
    
    segments.each do |segment|
      successful_queries = segment[:generated_images].map { |img| img[:query] }.uniq
      all_queries = segment[:image_queries]
      
      failed = all_queries - successful_queries
      failed.each do |query|
        failed_queries << {
          segment_id: segment[:id],
          query: query,
          text: segment[:text][0..50]
        }
      end
    end
    
    failed_queries
  end
end 