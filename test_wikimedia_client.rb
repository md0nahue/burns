#!/usr/bin/env ruby

require_relative 'lib/wikimedia_client'
require 'json'
require 'time'

# Live test script for WikiMedia client
class WikimediaClientTest
  def initialize
    @client = WikimediaClient.new
    @test_queries = [
      'Albert Einstein',
      'Barack Obama',
      'Queen Elizabeth II',
      'Nelson Mandela',
      'Mahatma Gandhi',
      'Martin Luther King Jr',
      'Winston Churchill',
      'John F Kennedy',
      'Mother Teresa',
      'Malala Yousafzai',
      'mountain landscape',
      'ocean waves',
      'city skyline',
      'forest trees',
      'sunset sky'
    ]
  end

  def run_tests
    puts "=== WikiMedia Client Live Test ==="
    puts "Testing #{@test_queries.length} queries..."
    puts

    @test_queries.each_with_index do |query, index|
      puts "Test #{index + 1}/#{@test_queries.length}: '#{query}'"
      puts "-" * 50
      
      begin
        result = @client.search_images(query, '1080p')
        
        if result && result[:images] && !result[:images].empty?
          puts "✅ Success! Found #{result[:images].length} images"
          
          # Display first image details
          image = result[:images].first
          puts "   📸 First image:"
          puts "      URL: #{image[:url]}"
          puts "      Size: #{image[:width]}x#{image[:height]}"
          puts "      Author: #{image[:photographer]}"
          puts "      License: #{image[:metadata][:license]}"
          puts "      Description: #{image[:description] || 'No description'}"
          
          if image[:metadata][:categories] && !image[:metadata][:categories].empty?
            puts "      Categories: #{image[:metadata][:categories].first(3).join(', ')}"
          end
          
          if image[:metadata][:usage_restrictions]
            puts "      Restrictions: #{image[:metadata][:usage_restrictions]}"
          end
          
        else
          puts "❌ No images found"
        end
        
      rescue => e
        puts "❌ Error: #{e.message}"
      end
      
      puts
      sleep(1) # Be respectful to the API
    end
    
    puts "=== Test Complete ==="
  end

  def test_specific_public_figures
    puts "\n=== Testing Public Figures ==="
    
    public_figures = [
      'Albert Einstein portrait',
      'Barack Obama official',
      'Queen Elizabeth II portrait',
      'Nelson Mandela portrait',
      'Mahatma Gandhi portrait'
    ]
    
    public_figures.each do |query|
      puts "\nTesting: '#{query}'"
      puts "-" * 30
      
      begin
        result = @client.search_images(query, '1080p')
        
        if result && result[:images] && !result[:images].empty?
          puts "✅ Found #{result[:images].length} images"
          
          result[:images].each_with_index do |image, index|
            puts "   Image #{index + 1}:"
            puts "      URL: #{image[:url]}"
            puts "      Size: #{image[:width]}x#{image[:height]}"
            puts "      Author: #{image[:photographer]}"
            puts "      License: #{image[:metadata][:license]}"
          end
        else
          puts "❌ No images found"
        end
        
      rescue => e
        puts "❌ Error: #{e.message}"
      end
      
      sleep(1)
    end
  end

  def test_image_quality_filtering
    puts "\n=== Testing Image Quality Filtering ==="
    
    test_queries = ['mountain', 'ocean', 'city']
    
    test_queries.each do |query|
      puts "\nTesting: '#{query}'"
      puts "-" * 30
      
      begin
        result = @client.search_images(query, '1080p')
        
        if result && result[:images] && !result[:images].empty?
          puts "✅ Found #{result[:images].length} images"
          
          # Check image sizes
          large_images = result[:images].select { |img| img[:width] >= 1920 && img[:height] >= 1080 }
          puts "   High quality images (1920x1080+): #{large_images.length}"
          
          result[:images].each_with_index do |image, index|
            puts "   Image #{index + 1}: #{image[:width]}x#{image[:height]}"
          end
        else
          puts "❌ No images found"
        end
        
      rescue => e
        puts "❌ Error: #{e.message}"
      end
      
      sleep(1)
    end
  end

  def test_metadata_extraction
    puts "\n=== Testing Metadata Extraction ==="
    
    test_query = 'Albert Einstein'
    puts "Testing metadata extraction for: '#{test_query}'"
    puts "-" * 50
    
    begin
      result = @client.search_images(test_query, '1080p')
      
      if result && result[:images] && !result[:images].empty?
        image = result[:images].first
        puts "✅ Metadata extracted successfully:"
        puts "   Page ID: #{image[:metadata][:id]}"
        puts "   License: #{image[:metadata][:license]}"
        puts "   File Size: #{image[:metadata][:file_size]} bytes"
        puts "   Categories: #{image[:metadata][:categories].length} categories"
        
        if image[:metadata][:categories] && !image[:metadata][:categories].empty?
          puts "   Sample categories:"
          image[:metadata][:categories].first(5).each do |category|
            puts "      - #{category}"
          end
        end
        
        if image[:metadata][:usage_restrictions]
          puts "   Usage Restrictions: #{image[:metadata][:usage_restrictions]}"
        end
      else
        puts "❌ No images found"
      end
      
    rescue => e
      puts "❌ Error: #{e.message}"
    end
  end

  def run_all_tests
    run_tests
    test_specific_public_figures
    test_image_quality_filtering
    test_metadata_extraction
    
    puts "\n🎉 All tests completed!"
  end
end

# Run the tests if this script is executed directly
if __FILE__ == $0
  test = WikimediaClientTest.new
  test.run_all_tests
end 