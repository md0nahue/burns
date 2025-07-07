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
    
    # For a single image, try multiple providers until we get a good result
    all_clients = primary_clients + fallback_clients
    attempts = 0
    max_attempts = all_clients.length * 2 # Allow retries
    
    while results.empty? && attempts < max_attempts
      client_name = all_clients[attempts % all_clients.length]
      client = @clients[client_name]
      attempts += 1
      
      next unless client
      
      puts "    🔍 ImageServiceBus: Attempting #{client_name} (attempt #{attempts}/#{max_attempts})"
      
      begin
        # Add delay for rate limiting
        sleep(0.3) if attempts > 1
        
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
    
    # Skip placeholder patterns
    placeholder_patterns = [
      /placeholder/i,
      /default/i,
      /notfound/i,
      /404/i,
      /missing/i,
      /unavailable/i,
      /lorem/i,
      /picsum\.photos.*\?blur/i # Skip blurred Lorem Picsum images
    ]
    
    return false if placeholder_patterns.any? { |pattern| url.match?(pattern) }
    
    # Check minimum dimensions if available
    if image[:width] && image[:height]
      return false if image[:width] < 800 || image[:height] < 600
    end
    
    true
  end

  # Get images with relaxed quality requirements
  # @param query [String] Search query
  # @param target_resolution [String] Target resolution
  # @return [Array] Results with relaxed requirements
  def get_images_relaxed(query, target_resolution)
    results = []
    
    # Try each client once more with any result accepted
    @clients.each do |client_name, client|
      begin
        result = client.search_images(query, target_resolution)
        
        if result && result[:images] && !result[:images].empty?
          results << result
          puts "    ✅ ImageServiceBus: Accepted relaxed quality from #{client_name}"
          break # Take first available result
        end
        
      rescue => e
        puts "    ❌ ImageServiceBus: Relaxed attempt failed for #{client_name}: #{e.message}"
      end
    end
    
    results
  end
end 