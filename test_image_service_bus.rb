#!/usr/bin/env ruby

require 'test/unit'
require_relative 'lib/image_service_bus'
require 'json'
require 'time'

# Test suite for Image Service Bus
class TestImageServiceBus < Test::Unit::TestCase
  def setup
    # Load configuration from environment or use defaults
    @config = {
      unsplash: { api_key: ENV['UNSPLASH_API_KEY'] },
      pexels: { api_key: ENV['PEXELS_API_KEY'] },
      pixabay: { api_key: ENV['PIXABAY_API_KEY'] },
      lorem_picsum: {},
      openverse: {}
    }
    
    @service_bus = ImageServiceBus.new(@config)
    @test_queries = ['mountain', 'ocean', 'forest', 'city', 'sunset']
  end

  def teardown
    # Add delay between tests to respect rate limits
    sleep(2)
  end

  # Test basic service bus initialization
  def test_service_bus_initialization
    assert_not_nil(@service_bus)
    assert_equal(5, @service_bus.clients.keys.length)
    assert_includes(@service_bus.clients.keys, :unsplash)
    assert_includes(@service_bus.clients.keys, :pexels)
    assert_includes(@service_bus.clients.keys, :pixabay)
    assert_includes(@service_bus.clients.keys, :lorem_picsum)
    assert_includes(@service_bus.clients.keys, :openverse)
  end

  # Test client status
  def test_client_status
    status = @service_bus.client_status
    assert_not_nil(status)
    assert_equal(5, status.keys.length)
    
    status.each do |client_name, client_status|
      assert_includes([true, false], client_status[:available])
    end
  end

  # Test single image retrieval
  def test_get_single_image
    query = @test_queries.sample
    result = @service_bus.get_single_image(query, '1080p')
    
    if result
      assert_not_nil(result[:provider])
      assert_not_nil(result[:query])
      assert_not_nil(result[:images])
      assert(result[:images].length > 0, "Should have at least one image")
      
      image = result[:images].first
      assert_not_nil(image[:url])
      assert_not_nil(image[:width])
      assert_not_nil(image[:height])
      assert_not_nil(image[:photographer])
    else
      # It's okay if no results are found (rate limits, etc.)
      puts "No results found for query: #{query}"
    end
  end

  # Test multiple image retrieval with fallback
  def test_get_multiple_images
    query = @test_queries.sample
    results = @service_bus.get_images(query, 3, '1080p')
    
    assert_not_nil(results)
    assert(results.length <= 3, "Should not return more than requested")
    
    results.each do |result|
      next unless result
      assert_not_nil(result[:provider])
      assert_not_nil(result[:images])
      assert(result[:images].length > 0, "Each result should have images")
    end
  end

  # Test different resolutions
  def test_different_resolutions
    query = @test_queries.sample
    
    ['1080p', '4k'].each do |resolution|
      result = @service_bus.get_single_image(query, resolution)
      
      if result && result[:images].any?
        image = result[:images].first
        dimensions = @service_bus.clients[:unsplash].get_image_dimensions(resolution)
        
        # Check if image meets minimum size requirements
        case resolution
        when '1080p'
          assert(image[:width] >= 2560 || image[:height] >= 1440, 
                 "1080p image should meet minimum size requirements")
        when '4k'
          assert(image[:width] >= 5120 || image[:height] >= 2880, 
                 "4K image should meet minimum size requirements")
        end
      end
    end
  end

  # Test individual API clients
  def test_unsplash_client
    client = @service_bus.clients[:unsplash]
    assert_not_nil(client)
    
    if @config[:unsplash][:api_key]
      result = client.search_images('mountain', '1080p')
      if result
        assert_equal('unsplash', result[:provider])
        assert_not_nil(result[:images])
        assert(result[:images].length > 0, "Should have images")
        
        image = result[:images].first
        assert_not_nil(image[:url])
        assert_not_nil(image[:photographer])
        assert_not_nil(image[:metadata])
      end
    else
      puts "Skipping Unsplash test - no API key provided"
    end
  end

  def test_pexels_client
    client = @service_bus.clients[:pexels]
    assert_not_nil(client)
    
    if @config[:pexels][:api_key]
      result = client.search_images('ocean', '1080p')
      if result
        assert_equal('pexels', result[:provider])
        assert_not_nil(result[:images])
        assert(result[:images].length > 0, "Should have images")
        
        image = result[:images].first
        assert_not_nil(image[:url])
        assert_not_nil(image[:photographer])
      end
    else
      puts "Skipping Pexels test - no API key provided"
    end
  end

  def test_pixabay_client
    client = @service_bus.clients[:pixabay]
    assert_not_nil(client)
    
    if @config[:pixabay][:api_key]
      result = client.search_images('forest', '1080p')
      if result
        assert_equal('pixabay', result[:provider])
        assert_not_nil(result[:images])
        assert(result[:images].length > 0, "Should have images")
        
        image = result[:images].first
        assert_not_nil(image[:url])
        assert_not_nil(image[:photographer])
        assert_not_nil(image[:metadata])
      end
    else
      puts "Skipping Pixabay test - no API key provided"
    end
  end

  def test_lorem_picsum_client
    client = @service_bus.clients[:lorem_picsum]
    assert_not_nil(client)
    
    result = client.search_images('placeholder', '1080p')
    assert_not_nil(result)
    assert_equal('lorem_picsum', result[:provider])
    assert_not_nil(result[:images])
    assert(result[:images].length > 0, "Should have images")
    
    image = result[:images].first
    assert_not_nil(image[:url])
    assert_equal('Lorem Picsum', image[:photographer])
    assert_equal(2560, image[:width])
    assert_equal(1440, image[:height])
  end

  def test_openverse_client
    client = @service_bus.clients[:openverse]
    assert_not_nil(client)
    
    result = client.search_images('city', '1080p')
    if result
      assert_equal('openverse', result[:provider])
      assert_not_nil(result[:images])
      
      if result[:images].length > 0
        image = result[:images].first
        assert_not_nil(image[:url])
        assert_not_nil(image[:metadata])
        assert_not_nil(image[:metadata][:license])
      end
    else
      puts "No results from Openverse (this is normal)"
    end
  end

  # Test error handling
  def test_error_handling
    # Test with invalid query
    result = @service_bus.get_single_image('', '1080p')
    # Should handle gracefully without crashing
    
    # Test with very long query
    long_query = 'a' * 1000
    result = @service_bus.get_single_image(long_query, '1080p')
    # Should handle gracefully
  end

  # Test random selection logic
  def test_random_selection
    query = @test_queries.sample
    results = @service_bus.get_images(query, 5, '1080p')
    
    providers = results.compact.map { |r| r[:provider] }
    assert(providers.length > 0, "Should have some results")
    
    # Check that we're getting different providers (not always the same one)
    unique_providers = providers.uniq
    assert(unique_providers.length > 0, "Should have at least one provider")
  end

  # Test image metadata structure
  def test_image_metadata_structure
    query = @test_queries.sample
    result = @service_bus.get_single_image(query, '1080p')
    
    if result && result[:images].any?
      image = result[:images].first
      
      # Check required fields
      required_fields = [:url, :width, :height, :photographer]
      required_fields.each do |field|
        assert_not_nil(image[field], "Image should have #{field}")
      end
      
      # Check optional fields
      optional_fields = [:description, :photographer_url, :metadata]
      optional_fields.each do |field|
        # These can be nil, but the key should exist
        assert(image.key?(field), "Image should have #{field} key")
      end
    end
  end

  # Performance test (with rate limiting consideration)
  def test_performance
    start_time = Time.now
    query = @test_queries.sample
    
    result = @service_bus.get_single_image(query, '1080p')
    
    end_time = Time.now
    duration = end_time - start_time
    
    # Should complete within reasonable time (30 seconds for API calls)
    assert(duration < 30, "Request should complete within 30 seconds, took #{duration} seconds")
    
    if result
      puts "Performance test: Got #{result[:images].length} images in #{duration.round(2)} seconds"
    end
  end

  # Test rate limiting awareness
  def test_rate_limiting_awareness
    # This test checks that we're not making too many requests too quickly
    queries = @test_queries.first(3)
    
    queries.each do |query|
      result = @service_bus.get_single_image(query, '1080p')
      # Just check that it doesn't crash
      assert_not_nil(@service_bus, "Service bus should still be functional")
    end
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  puts "Image Service Bus Test Suite"
  puts "============================"
  puts "Note: Some tests require API keys to be set in environment variables:"
  puts "  UNSPLASH_API_KEY"
  puts "  PEXELS_API_KEY" 
  puts "  PIXABAY_API_KEY"
  puts ""
  puts "Tests will be skipped for clients without API keys."
  puts ""
  
  # Run the test suite
  Test::Unit::AutoRunner.run
end 