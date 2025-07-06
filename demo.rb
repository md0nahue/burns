#!/usr/bin/env ruby

require_relative 'lib/image_service_bus'
require_relative 'config'

# Demo script for Image Service Bus
class ImageServiceBusDemo
  def initialize
    @config = ImageServiceBusConfig::SERVICES
    @service_bus = ImageServiceBus.new(@config)
    @demo_queries = [
      'mountain landscape',
      'ocean waves',
      'forest path',
      'city skyline',
      'sunset clouds',
      'desert dunes',
      'waterfall',
      'beach sunset'
    ]
  end

  def run_demo
    puts "🎨 Image Service Bus Demo"
    puts "=" * 50
    puts

    # Show client status
    show_client_status

    # Demo 1: Single image search
    demo_single_image_search

    # Demo 2: Multiple images with fallback
    demo_multiple_images

    # Demo 3: Different resolutions
    demo_different_resolutions

    # Demo 4: Error handling
    demo_error_handling

    # Demo 5: Performance test
    demo_performance_test

    puts "\n✅ Demo completed!"
  end

  private

  def show_client_status
    puts "📊 Client Status:"
    puts "-" * 30
    
    status = @service_bus.client_status
    status.each do |client, info|
      status_icon = info[:available] ? "✅" : "❌"
      api_key_status = @config[client][:api_key] ? "🔑" : "🔓"
      puts "  #{status_icon} #{client.to_s.upcase} #{api_key_status}"
    end
    puts
  end

  def demo_single_image_search
    puts "🔍 Demo 1: Single Image Search"
    puts "-" * 35
    
    query = @demo_queries.sample
    puts "Searching for: '#{query}'"
    
    result = @service_bus.get_single_image(query, '1080p')
    
    if result && result[:images].any?
      image = result[:images].first
      puts "✅ Found image from #{result[:provider].upcase}:"
      puts "   📸 #{image[:description] || 'No description'}"
      puts "   📏 #{image[:width]}x#{image[:height]}"
      puts "   👤 #{image[:photographer]}"
      puts "   🔗 #{image[:url]}"
      
      if image[:metadata]
        puts "   📊 Metadata: #{image[:metadata].keys.join(', ')}"
      end
    else
      puts "❌ No results found"
    end
    puts
  end

  def demo_multiple_images
    puts "🔄 Demo 2: Multiple Images with Fallback"
    puts "-" * 40
    
    query = @demo_queries.sample
    puts "Searching for: '#{query}' (3 images with fallback)"
    
    results = @service_bus.get_images(query, 3, '1080p')
    
    if results.any?
      puts "✅ Found #{results.length} result sets:"
      results.each_with_index do |result, i|
        next unless result
        puts "   #{i + 1}. #{result[:provider].upcase}: #{result[:images].length} images"
        if result[:images].any?
          image = result[:images].first
          puts "      📸 #{image[:description] || 'No description'}"
          puts "      📏 #{image[:width]}x#{image[:height]}"
        end
      end
    else
      puts "❌ No results found"
    end
    puts
  end

  def demo_different_resolutions
    puts "📐 Demo 3: Different Resolutions"
    puts "-" * 35
    
    query = @demo_queries.sample
    puts "Searching for: '#{query}' in different resolutions"
    
    ['1080p', '4k'].each do |resolution|
      puts "\n   #{resolution.upcase}:"
      result = @service_bus.get_single_image(query, resolution)
      
      if result && result[:images].any?
        image = result[:images].first
        puts "     ✅ #{image[:width]}x#{image[:height]} from #{result[:provider]}"
        
        # Check if meets minimum requirements
        dimensions = @service_bus.clients[:unsplash].get_image_dimensions(resolution)
        meets_requirements = image[:width] >= dimensions[:width] || image[:height] >= dimensions[:height]
        status = meets_requirements ? "✅" : "⚠️"
        puts "     #{status} Meets #{resolution} requirements"
      else
        puts "     ❌ No results"
      end
    end
    puts
  end

  def demo_error_handling
    puts "🛡️ Demo 4: Error Handling"
    puts "-" * 30
    
    # Test with empty query
    puts "Testing empty query..."
    result = @service_bus.get_single_image('', '1080p')
    puts result ? "✅ Handled gracefully" : "✅ No results (expected)"
    
    # Test with very long query
    puts "Testing very long query..."
    long_query = 'a' * 1000
    result = @service_bus.get_single_image(long_query, '1080p')
    puts result ? "✅ Handled gracefully" : "✅ No results (expected)"
    
    puts
  end

  def demo_performance_test
    puts "⚡ Demo 5: Performance Test"
    puts "-" * 30
    
    query = @demo_queries.sample
    puts "Testing performance with query: '#{query}'"
    
    start_time = Time.now
    result = @service_bus.get_single_image(query, '1080p')
    end_time = Time.now
    
    duration = end_time - start_time
    
    if result
      puts "✅ Got #{result[:images].length} images in #{duration.round(2)} seconds"
      puts "   📊 Performance: #{duration < 10 ? 'Excellent' : duration < 30 ? 'Good' : 'Slow'}"
    else
      puts "❌ No results in #{duration.round(2)} seconds"
    end
    puts
  end

  def show_usage_examples
    puts "📖 Usage Examples:"
    puts "-" * 20
    puts
    puts "1. Basic usage:"
    puts "   service_bus = ImageServiceBus.new(config)"
    puts "   result = service_bus.get_single_image('mountain', '1080p')"
    puts
    puts "2. Multiple images with fallback:"
    puts "   results = service_bus.get_images('ocean', 3, '4k')"
    puts
    puts "3. Check client status:"
    puts "   status = service_bus.client_status"
    puts
    puts "4. Environment variables for API keys:"
    puts "   export UNSPLASH_API_KEY='your_key_here'"
    puts "   export PEXELS_API_KEY='your_key_here'"
    puts "   export PIXABAY_API_KEY='your_key_here'"
    puts
  end
end

# Run demo if this file is executed directly
if __FILE__ == $0
  demo = ImageServiceBusDemo.new
  
  # Show usage examples first
  demo.show_usage_examples
  
  # Ask user if they want to run the demo
  print "\nRun the demo? (y/n): "
  response = gets.chomp.downcase
  
  if response == 'y' || response == 'yes'
    demo.run_demo
  else
    puts "Demo skipped. You can run it later with: ruby demo.rb"
  end
end 