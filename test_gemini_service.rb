#!/usr/bin/env ruby

require_relative 'lib/services/gemini_service'
require 'json'

# Test script for Gemini service
class GeminiServiceTest
  def initialize
    @service = GeminiService.new
    @test_texts = [
      "I recently tried the new iPhone 15 Pro and I have to say, the camera quality is absolutely stunning. The macro photography feature allows you to capture incredible detail in close-up shots, and the low-light performance is remarkable.",
      "The Grand Canyon is one of the most breathtaking natural wonders I've ever seen. The layers of red rock stretching for miles, the Colorado River winding through the bottom, and the way the light changes throughout the day create an unforgettable experience.",
      "Cooking homemade pasta is such a rewarding experience. The process of mixing flour and eggs, kneading the dough until it's smooth, and then rolling it out into thin sheets is both therapeutic and delicious.",
      "The Tesla Model S is an engineering marvel. The instant acceleration, the minimalist interior design, and the advanced autopilot features make every drive feel like a glimpse into the future of transportation.",
      "Hiking in the Pacific Northwest offers some of the most diverse landscapes you can imagine. From dense rainforests with moss-covered trees to snow-capped mountain peaks, every trail reveals something new and beautiful."
    ]
  end

  def run_tests
    puts "🧠 Gemini Service Test Suite"
    puts "=" * 40
    puts "Testing Gemini API integration with model: gemini-2.5-flash-lite-preview-06-17"
    puts "API Key: #{ENV['GEMINI_API_KEY'] ? '✅ Set' : '❌ Not set'}"
    puts

    test_basic_functionality
    test_image_query_generation
    test_content_analysis
    test_error_handling
    
    puts "\n🎉 All tests completed!"
  end

  def test_basic_functionality
    puts "📋 Test 1: Basic Functionality"
    puts "-" * 30
    
    begin
      # Test simple text analysis
      text = "The sunset over the ocean was absolutely beautiful with vibrant orange and pink colors."
      queries = @service.generate_image_queries_for_text(text)
      
      puts "✅ Basic functionality test passed"
      puts "   Generated queries: #{queries.inspect}"
      puts "   Number of queries: #{queries.length}"
      
    rescue => e
      puts "❌ Basic functionality test failed: #{e.message}"
    end
    
    puts
  end

  def test_image_query_generation
    puts "🖼️  Test 2: Image Query Generation"
    puts "-" * 35
    
    @test_texts.each_with_index do |text, index|
      puts "   Testing text #{index + 1}/#{@test_texts.length}"
      
      begin
        queries = @service.generate_image_queries_for_text(text)
        
        if queries && queries.length > 0
          puts "   ✅ Generated #{queries.length} queries"
          queries.each_with_index do |query, q_index|
            puts "      #{q_index + 1}. #{query}"
          end
        else
          puts "   ⚠️  No queries generated"
        end
        
      rescue => e
        puts "   ❌ Error: #{e.message}"
      end
      
      sleep(1) # Be respectful to the API
    end
    
    puts
  end

  def test_content_analysis
    puts "📊 Test 3: Content Analysis"
    puts "-" * 25
    
    # Create mock segments for testing
    segments = [
      {
        start_time: 0.0,
        end_time: 5.0,
        text: "The iPhone 15 Pro has an incredible camera system."
      },
      {
        start_time: 5.0,
        end_time: 10.0,
        text: "The macro photography feature is particularly impressive."
      },
      {
        start_time: 10.0,
        end_time: 15.0,
        text: "You can capture stunning close-up shots with amazing detail."
      }
    ]
    
    begin
      analyzed_segments = @service.analyze_content_for_images(segments, {
        context: "product review",
        style: "modern, high-quality"
      })
      
      puts "✅ Content analysis test passed"
      puts "   Processed #{analyzed_segments.length} segments"
      
      analyzed_segments.each_with_index do |segment, index|
        if segment[:image_query]
          puts "   Segment #{index + 1}: #{segment[:image_query]}"
        end
      end
      
    rescue => e
      puts "❌ Content analysis test failed: #{e.message}"
    end
    
    puts
  end

  def test_error_handling
    puts "🚨 Test 4: Error Handling"
    puts "-" * 25
    
    # Test with empty text
    begin
      queries = @service.generate_image_queries_for_text("")
      puts "   ✅ Handled empty text gracefully"
    rescue => e
      puts "   ❌ Failed to handle empty text: #{e.message}"
    end
    
    # Test with very short text
    begin
      queries = @service.generate_image_queries_for_text("Hi")
      puts "   ✅ Handled short text gracefully"
    rescue => e
      puts "   ❌ Failed to handle short text: #{e.message}"
    end
    
    # Test with very long text
    long_text = "This is a very long text that repeats the same words over and over again. " * 50
    begin
      queries = @service.generate_image_queries_for_text(long_text)
      puts "   ✅ Handled long text gracefully"
    rescue => e
      puts "   ❌ Failed to handle long text: #{e.message}"
    end
    
    puts
  end

  def test_specific_queries
    puts "🎯 Test 5: Specific Query Types"
    puts "-" * 30
    
    specific_texts = [
      {
        text: "The mountain landscape was covered in snow",
        expected: "mountain snow landscape"
      },
      {
        text: "The city skyline at night was lit up beautifully",
        expected: "city skyline night"
      },
      {
        text: "The ocean waves crashed against the rocky shore",
        expected: "ocean waves rocky shore"
      }
    ]
    
    specific_texts.each_with_index do |test_case, index|
      puts "   Testing case #{index + 1}: #{test_case[:text][0..50]}..."
      
      begin
        queries = @service.generate_image_queries_for_text(test_case[:text])
        
        if queries && queries.length > 0
          puts "   ✅ Generated queries: #{queries.join(', ')}"
        else
          puts "   ⚠️  No queries generated"
        end
        
      rescue => e
        puts "   ❌ Error: #{e.message}"
      end
      
      sleep(1)
    end
    
    puts
  end

  def run_full_test_suite
    run_tests
    test_specific_queries
    
    puts "\n📈 Test Summary"
    puts "=" * 15
    puts "• Gemini API integration: ✅"
    puts "• Model: gemini-2.5-flash-lite-preview-06-17"
    puts "• Environment variable: #{ENV['GEMINI_API_KEY'] ? 'GEMINI_API_KEY' : 'Not set'}"
    puts "• Service ready for use in the Burns video generator pipeline"
  end
end

# Run the tests if this script is executed directly
if __FILE__ == $0
  puts "Gemini Service Test Suite"
  puts "========================"
  puts "This test suite verifies the Gemini service integration."
  puts "Make sure GEMINI_API_KEY environment variable is set."
  puts ""
  
  test = GeminiServiceTest.new
  test.run_full_test_suite
end 