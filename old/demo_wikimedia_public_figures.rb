#!/usr/bin/env ruby

require_relative 'lib/image_service_bus'
require 'json'

# Demo script showcasing WikiMedia client for public figures
class WikimediaPublicFiguresDemo
  def initialize
    @config = {
      unsplash: {},
      pexels: {},
      pixabay: {},
      lorem_picsum: {},
      openverse: {},
      wikimedia: {}
    }
    @service_bus = ImageServiceBus.new(@config)
    
    @public_figures = [
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
      'Steve Jobs',
      'Bill Gates',
      'Elon Musk',
      'Oprah Winfrey',
      'Michelle Obama'
    ]
  end

  def run_demo
    puts "🎬 WikiMedia Public Figures Demo"
    puts "=" * 50
    puts "This demo showcases the WikiMedia client's ability to find"
    puts "high-quality images of public figures and historical personalities."
    puts "WikiMedia Commons is particularly valuable for:"
    puts "• Historical figures and public domain images"
    puts "• Official portraits and government photos"
    puts "• Educational and documentary content"
    puts "• Images with clear licensing information"
    puts
    puts "Testing #{@public_figures.length} public figures..."
    puts

    successful_searches = 0
    total_images = 0

    @public_figures.each_with_index do |figure, index|
      puts "🔍 #{index + 1}/#{@public_figures.length}: Searching for '#{figure}'"
      puts "-" * 40
      
      begin
        # Use the service bus to get images from WikiMedia
        result = @service_bus.get_single_image(figure, '1080p')
        
        if result && result[:images] && !result[:images].empty?
          successful_searches += 1
          total_images += result[:images].length
          
          puts "✅ Found #{result[:images].length} images"
          
          # Show details of the first image
          image = result[:images].first
          puts "   📸 Best match:"
          puts "      URL: #{image[:url]}"
          puts "      Size: #{image[:width]}x#{image[:height]}"
          puts "      Author: #{image[:photographer]}"
          puts "      License: #{image[:metadata][:license]}"
          
          if image[:description]
            puts "      Description: #{image[:description][0..100]}..."
          end
          
          if image[:metadata][:categories] && !image[:metadata][:categories].empty?
            puts "      Categories: #{image[:metadata][:categories].first(2).join(', ')}"
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
    
    puts "📊 Demo Summary"
    puts "=" * 30
    puts "Successful searches: #{successful_searches}/#{@public_figures.length}"
    puts "Total images found: #{total_images}"
    puts "Average images per search: #{(total_images.to_f / successful_searches).round(1)}" if successful_searches > 0
    puts
    puts "🎯 Key Benefits of WikiMedia for Public Figures:"
    puts "• Rich metadata (author, license, categories)"
    puts "• High-resolution historical images"
    puts "• Clear licensing information"
    puts "• Educational and documentary value"
    puts "• Public domain and Creative Commons content"
  end

  def test_specific_historical_figures
    puts "\n🏛️  Historical Figures Deep Dive"
    puts "=" * 40
    
    historical_figures = [
      'Abraham Lincoln',
      'George Washington',
      'Thomas Jefferson',
      'Benjamin Franklin',
      'John Adams'
    ]
    
    historical_figures.each do |figure|
      puts "\n🔍 Searching for: '#{figure}'"
      puts "-" * 30
      
      begin
        result = @service_bus.get_single_image(figure, '1080p')
        
        if result && result[:images] && !result[:images].empty?
          puts "✅ Found #{result[:images].length} images"
          
          result[:images].each_with_index do |image, index|
            puts "   Image #{index + 1}:"
            puts "      URL: #{image[:url]}"
            puts "      Size: #{image[:width]}x#{image[:height]}"
            puts "      Author: #{image[:photographer]}"
            puts "      License: #{image[:metadata][:license]}"
            puts "      File Size: #{(image[:metadata][:file_size].to_i / 1024.0 / 1024.0).round(1)} MB"
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

  def test_modern_public_figures
    puts "\n👥 Modern Public Figures"
    puts "=" * 30
    
    modern_figures = [
      'Elon Musk',
      'Bill Gates',
      'Steve Jobs',
      'Oprah Winfrey',
      'Michelle Obama'
    ]
    
    modern_figures.each do |figure|
      puts "\n🔍 Searching for: '#{figure}'"
      puts "-" * 30
      
      begin
        result = @service_bus.get_single_image(figure, '1080p')
        
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

  def run_full_demo
    run_demo
    test_specific_historical_figures
    test_modern_public_figures
    
    puts "\n🎉 Demo Complete!"
    puts "The WikiMedia client is now integrated into your image service bus"
    puts "and can be used alongside other image providers for comprehensive"
    puts "image search capabilities, especially for public figures and"
    puts "historical content."
  end
end

# Run the demo if this script is executed directly
if __FILE__ == $0
  demo = WikimediaPublicFiguresDemo.new
  demo.run_full_demo
end 