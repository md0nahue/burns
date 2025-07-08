require_relative 'unsplash_client'
require_relative 'pexels_client'
require_relative 'pixabay_client'
require_relative 'lorem_picsum_client'
require_relative 'openverse_client'
require_relative 'wikimedia_client'
require 'logger'
require 'set'

class ImageServiceBus
  attr_reader :clients, :logger, :used_clients

  def initialize(config = {})
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @used_clients = Set.new
    @config = config
    
    # Initialize API clients
    @clients = {
      unsplash: UnsplashClient.new(config[:unsplash] || {}),
      pexels: PexelsClient.new(config[:pexels] || {}),
      pixabay: PixabayClient.new(config[:pixabay] || {}),
      lorem_picsum: LoremPicsumClient.new(config[:lorem_picsum] || {}),
      openverse: OpenverseClient.new(config[:openverse] || {}),
      wikimedia: WikimediaClient.new(config[:wikimedia] || {})
    }
    
    @logger.info("ImageServiceBus initialized with #{@clients.keys.length} clients")
  end

  def get_images(query, count = 3, target_resolution = '1080p', category = 'general')
    puts "    🔍 ImageServiceBus: Getting #{count} images for query '#{query}' (category: #{category})"
    results = []
    
    # Determine client priority based on category
    if category == 'famous_person'
      # For famous persons, prioritize Wikimedia first, then regular sources
      primary_clients = [:wikimedia]
      fallback_clients = [:unsplash, :pexels, :pixabay, :openverse, :lorem_picsum]
      puts "    👤 Famous person detected - prioritizing Wikimedia"
    else
      # For stock images and general content, use traditional priority
      primary_clients = [:unsplash, :pexels, :pixabay]
      fallback_clients = [:openverse, :wikimedia, :lorem_picsum]
    end
    
    # For speed optimization: limit attempts and reduce delays
    all_clients = primary_clients + fallback_clients
    attempts = 0
    max_attempts = [all_clients.length, 6].min # Limit max attempts for speed
    
    while results.empty? && attempts < max_attempts
      client_name = all_clients[attempts % all_clients.length]
      client = @clients[client_name]
      attempts += 1
      
      next unless client
      
      puts "    🔍 ImageServiceBus: Attempting #{client_name} (attempt #{attempts}/#{max_attempts})"
      
      begin
        # Reduced delay for faster processing
        sleep(0.1) if attempts > 1
        
        result = client.search_images(query, target_resolution)
        
        if result && result[:images] && !result[:images].empty?
          # Filter out placeholder/low quality images
          quality_images = result[:images].select { |img| is_quality_image?(img) }
          
          if quality_images.any?
            filtered_result = result.merge(images: quality_images)
            results << filtered_result
            puts "    ✅ ImageServiceBus: Got #{quality_images.length} quality images from #{client_name}"
            break # Success! Stop trying other clients
          else
            puts "    ⚠️  ImageServiceBus: #{client_name} returned only placeholder images"
          end
        else
          puts "    ⚠️  ImageServiceBus: No results from #{client_name}"
        end
        
      rescue => e
        puts "    ❌ ImageServiceBus: Error with #{client_name}: #{e.message}"
        # Continue to next client
      end
    end
    
    # If still no results, try with relaxed quality requirements
    if results.empty?
      puts "    🔄 ImageServiceBus: Retrying with relaxed quality requirements"
      results = get_images_relaxed(query, target_resolution)
    end
    
    puts "    🔍 ImageServiceBus: Returning #{results.length} results"
    results
  end

  def get_single_image(query, target_resolution = '1080p', category = 'general')
    result = get_images(query, 1, target_resolution, category)
    result.first
  end

  def client_status
    status = {}
    @clients.each do |name, client|
      status[name] = {
        available: client.respond_to?(:available?) ? client.available? : true,
        rate_limit_info: client.respond_to?(:rate_limit_info) ? client.rate_limit_info : nil
      }
    end
    status
  end

  private

  # Check if image meets quality requirements
  # @param image [Hash] Image data
  # @return [Boolean] True if image is good quality
  def is_quality_image?(image)
    return false unless image && image[:url]
    
    url = image[:url]
    
    # Skip placeholder patterns and low-quality indicators
    low_quality_patterns = [
      /placeholder/i,
      /default/i,
      /notfound/i,
      /404/i,
      /missing/i,
      /unavailable/i,
      /lorem/i,
      /picsum\.photos.*\?blur/i, # Skip blurred Lorem Picsum images
      /thumb/i,                   # Skip thumbnail versions
      /small/i,                   # Skip small versions
      /compressed/i,              # Skip heavily compressed
      /preview/i,                 # Skip preview versions
      /low.*res/i,               # Skip low resolution indicators
      /grainy/i,                 # Skip explicitly grainy images
      /pixelated/i,              # Skip pixelated images
      /\?w=\d{1,3}[&$]/,         # Skip URLs with small width parameters (< 1000px)
      /\?h=\d{1,3}[&$]/,         # Skip URLs with small height parameters (< 1000px)
      /size=small/i,             # Skip small size parameters
      /quality=low/i             # Skip low quality parameters
    ]
    
    return false if low_quality_patterns.any? { |pattern| url.match?(pattern) }
    
    # STRICT minimum dimensions for high-quality Ken Burns effects
    if image[:width] && image[:height]
      # Require MUCH higher resolution - Ken Burns needs room to zoom and pan
      min_width = 2560   # Minimum 2560px width for smooth 1080p output
      min_height = 1440  # Minimum 1440px height for smooth 1080p output
      
      return false if image[:width] < min_width || image[:height] < min_height
      
      # Reject images with poor aspect ratios that might be low quality
      aspect_ratio = image[:width].to_f / image[:height].to_f
      return false if aspect_ratio < 0.5 || aspect_ratio > 3.0  # Reject extreme ratios
      
      # Prefer larger images - they usually have better quality
      total_pixels = image[:width] * image[:height]
      return false if total_pixels < 3_686_400  # Minimum ~3.7MP (2560x1440)
    end
    
    # Additional URL-based quality checks
    # Prefer images from URLs that indicate high quality
    quality_indicators = [
      /\d{4,}x\d{4,}/,           # URLs containing large dimensions
      /hd/i,                     # HD indicator
      /high.*res/i,              # High resolution indicator
      /full.*res/i,              # Full resolution indicator
      /original/i,               # Original size indicator
      /large/i,                  # Large size indicator
      /4k/i,                     # 4K indicator
      /uhd/i,                    # Ultra HD indicator
      /raw/i,                    # Raw/uncompressed indicator
      /uncompressed/i            # Uncompressed indicator
    ]
    
    # Boost score for quality indicators but don't require them
    has_quality_indicator = quality_indicators.any? { |pattern| url.match?(pattern) }
    
    # For Ken Burns, we need the highest possible quality
    # If dimensions aren't available, be more strict about URL quality indicators
    if !image[:width] || !image[:height]
      return has_quality_indicator  # Require quality indicators if no dimensions
    end
    
    true
  end

  # Get images with relaxed quality requirements
  # @param query [String] Search query
  # @param target_resolution [String] Target resolution
  # @return [Array] Results with relaxed requirements
  def get_images_relaxed(query, target_resolution)
    results = []
    
    # Try each client once more with relaxed but still reasonable minimums
    @clients.each do |client_name, client|
      begin
        result = client.search_images(query, target_resolution)
        
        if result && result[:images] && !result[:images].empty?
          # Apply relaxed quality filter - still require decent resolution
          relaxed_quality_images = result[:images].select { |img| is_relaxed_quality_image?(img) }
          
          if relaxed_quality_images.any?
            filtered_result = result.merge(images: relaxed_quality_images)
            results << filtered_result
            puts "    ✅ ImageServiceBus: Accepted relaxed quality from #{client_name} (#{relaxed_quality_images.length} images)"
            break # Take first available result
          end
        end
        
      rescue => e
        puts "    ❌ ImageServiceBus: Relaxed attempt failed for #{client_name}: #{e.message}"
      end
    end
    
    results
  end
  
  # Check if image meets relaxed quality requirements
  def is_relaxed_quality_image?(image)
    return false unless image && image[:url]
    
    url = image[:url]
    
    # Skip obvious low-quality patterns (more permissive than strict)
    low_quality_patterns = [
      /placeholder/i,
      /default/i,
      /notfound/i,
      /404/i,
      /missing/i,
      /unavailable/i,
      /grainy/i,                 # Still reject explicitly grainy images
      /pixelated/i,              # Still reject pixelated images
      /\?w=\d{1,2}[&$]/,         # Reject very small width parameters (< 100px)
      /\?h=\d{1,2}[&$]/,         # Reject very small height parameters (< 100px)
      /quality=low/i             # Still reject explicitly low quality
    ]
    
    return false if low_quality_patterns.any? { |pattern| url.match?(pattern) }
    
    # Relaxed but still decent minimum dimensions for Ken Burns
    if image[:width] && image[:height]
      min_width = 1920   # Still require Full HD minimum for relaxed
      min_height = 1080  # Still require Full HD minimum for relaxed
      
      return false if image[:width] < min_width || image[:height] < min_height
      
      # Still reject extreme aspect ratios
      aspect_ratio = image[:width].to_f / image[:height].to_f
      return false if aspect_ratio < 0.3 || aspect_ratio > 4.0  # More permissive but still reasonable
      
      # Minimum pixel count for relaxed quality
      total_pixels = image[:width] * image[:height]
      return false if total_pixels < 2_073_600  # Minimum ~2MP (1920x1080)
    end
    
    true
  end
end 