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

  def get_images(query, count = 3, target_resolution = '1080p')
    puts "    🔍 ImageServiceBus: Getting #{count} images for query '#{query}'"
    results = []
    available_clients = @clients.keys.to_a
    @used_clients.clear
    
    count.times do |i|
      unused_clients = available_clients - @used_clients.to_a
      if unused_clients.empty?
        @logger.warn("All clients have been tried. Resetting used clients.")
        @used_clients.clear
        unused_clients = available_clients
      end
      selected_client = unused_clients.sample
      @used_clients.add(selected_client)
      puts "    🔍 ImageServiceBus: Using client #{selected_client} for image #{i + 1}"
      
      begin
        puts "    🔍 ImageServiceBus: About to call search_images on #{selected_client}"
        puts "    🔍 ImageServiceBus: Client class: #{@clients[selected_client].class}"
        puts "    🔍 ImageServiceBus: Query: '#{query}', Resolution: '#{target_resolution}'"
        
        # Add a small delay to avoid rate limiting
        sleep(0.5) if i > 0
        
        puts "    🔍 ImageServiceBus: Calling search_images now..."
        result = @clients[selected_client].search_images(query, target_resolution)
        puts "    🔍 ImageServiceBus: Got result: #{result.class}"
        
        if result && !result[:images].empty?
          results << result
          puts "    ✅ ImageServiceBus: Successfully got #{result[:images].length} images from #{selected_client}"
        else
          puts "    ⚠️  ImageServiceBus: No results from #{selected_client}"
        end
      rescue => e
        puts "    ❌ ImageServiceBus: Error with #{selected_client}: #{e.message}"
        puts "    ❌ ImageServiceBus: Error class: #{e.class}"
        puts "    ❌ ImageServiceBus: Error backtrace: #{e.backtrace.first(10)}"
        puts "    ❌ ImageServiceBus: Error location: #{e.backtrace.first}"
      end
    end
    
    puts "    🔍 ImageServiceBus: Returning #{results.length} results"
    results
  end

  def get_single_image(query, target_resolution = '1080p')
    result = get_images(query, 1, target_resolution)
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
end 