#!/usr/bin/env ruby

require_relative 'lib/services/whisper_service'
require_relative 'lib/services/gemini_service'
require_relative 'lib/pipeline/content_analyzer'
require_relative 'lib/pipeline/video_generator'

# Test script to verify pipeline configuration
class PipelineConfigurationTest
  def initialize
    puts "🔧 Pipeline Configuration Test"
    puts "=" * 40
  end

  def run_tests
    test_service_initialization
    test_configuration_consistency
    test_pipeline_integration
    test_environment_variables
    
    puts "\n🎉 All configuration tests completed!"
  end

  def test_service_initialization
    puts "\n📋 Test 1: Service Initialization"
    puts "-" * 35
    
    begin
      # Test WhisperService (should use Groq)
      whisper_service = WhisperService.new
      puts "✅ WhisperService initialized (using Groq)"
      puts "   API Base: #{WhisperService::GROQ_API_BASE}"
      puts "   Default Model: #{Config::GROQ_CONFIG[:default_model]}"
      
    rescue => e
      puts "❌ WhisperService initialization failed: #{e.message}"
    end
    
    begin
      # Test GeminiService (should use Gemini)
      gemini_service = GeminiService.new
      puts "✅ GeminiService initialized (using Gemini)"
      puts "   API Base: #{GeminiService::GEMINI_API_BASE}"
      puts "   Model: #{gemini_service.instance_variable_get(:@model)}"
      
    rescue => e
      puts "❌ GeminiService initialization failed: #{e.message}"
    end
    
    begin
      # Test ContentAnalyzer (should use Gemini)
      content_analyzer = ContentAnalyzer.new
      puts "✅ ContentAnalyzer initialized (using Gemini)"
      
    rescue => e
      puts "❌ ContentAnalyzer initialization failed: #{e.message}"
    end
    
    begin
      # Test VideoGenerator (should use both services)
      video_generator = VideoGenerator.new
      puts "✅ VideoGenerator initialized"
      puts "   WhisperService: #{video_generator.instance_variable_get(:@whisper_service).class}"
      puts "   GeminiService: #{video_generator.instance_variable_get(:@gemini_service).class}"
      
    rescue => e
      puts "❌ VideoGenerator initialization failed: #{e.message}"
    end
  end

  def test_configuration_consistency
    puts "\n🔧 Test 2: Configuration Consistency"
    puts "-" * 35
    
    # Check Groq configuration
    puts "📊 Groq Configuration (for Whisper):"
    puts "   API Key: #{ENV['GROQ_API_KEY'] ? '✅ Set' : '❌ Not set'}"
    puts "   Base URL: #{Config::GROQ_CONFIG[:base_url]}"
    puts "   Default Model: #{Config::GROQ_CONFIG[:default_model]}"
    
    # Check Gemini configuration
    puts "\n📊 Gemini Configuration (for LLM):"
    puts "   API Key: #{ENV['GEMINI_API_KEY'] ? '✅ Set' : '❌ Not set'}"
    puts "   Model: #{Config::GEMINI_CONFIG[:model]}"
    puts "   Max Tokens: #{Config::GEMINI_CONFIG[:max_tokens]}"
    puts "   Temperature: #{Config::GEMINI_CONFIG[:temperature]}"
    
    # Check LLM configuration
    puts "\n📊 LLM Configuration:"
    puts "   Provider: #{Config::LLM_CONFIG[:provider]}"
    puts "   API Key: #{Config::LLM_CONFIG[:api_key] ? '✅ Set' : '❌ Not set'}"
    puts "   Model: #{Config::LLM_CONFIG[:model]}"
    
    # Verify consistency
    if Config::LLM_CONFIG[:provider] == 'gemini' && 
       Config::LLM_CONFIG[:api_key] == ENV['GEMINI_API_KEY']
      puts "\n✅ Configuration is consistent: LLM uses Gemini"
    else
      puts "\n❌ Configuration inconsistency detected"
    end
  end

  def test_pipeline_integration
    puts "\n🔗 Test 3: Pipeline Integration"
    puts "-" * 30
    
    begin
      # Test that ContentAnalyzer uses Gemini
      content_analyzer = ContentAnalyzer.new
      gemini_service = content_analyzer.instance_variable_get(:@gemini_service)
      
      if gemini_service.is_a?(GeminiService)
        puts "✅ ContentAnalyzer correctly uses GeminiService"
      else
        puts "❌ ContentAnalyzer is not using GeminiService"
      end
      
    rescue => e
      puts "❌ Pipeline integration test failed: #{e.message}"
    end
    
    begin
      # Test that VideoGenerator uses both services
      video_generator = VideoGenerator.new
      whisper_service = video_generator.instance_variable_get(:@whisper_service)
      gemini_service = video_generator.instance_variable_get(:@gemini_service)
      
      if whisper_service.is_a?(WhisperService) && gemini_service.is_a?(GeminiService)
        puts "✅ VideoGenerator correctly uses both WhisperService (Groq) and GeminiService (Gemini)"
      else
        puts "❌ VideoGenerator service configuration incorrect"
      end
      
    rescue => e
      puts "❌ VideoGenerator integration test failed: #{e.message}"
    end
  end

  def test_environment_variables
    puts "\n🔑 Test 4: Environment Variables"
    puts "-" * 30
    
    required_vars = {
      'GROQ_API_KEY' => 'Whisper (Speech-to-Text)',
      'GEMINI_API_KEY' => 'LLM (Content Analysis)'
    }
    
    optional_vars = {
      'UNSPLASH_API_KEY' => 'Unsplash Images',
      'PEXELS_API_KEY' => 'Pexels Images',
      'PIXABAY_API_KEY' => 'Pixabay Images'
    }
    
    puts "📋 Required Environment Variables:"
    required_vars.each do |var, purpose|
      if ENV[var]
        puts "   ✅ #{var} - #{purpose}"
      else
        puts "   ❌ #{var} - #{purpose} (NOT SET)"
      end
    end
    
    puts "\n📋 Optional Environment Variables:"
    optional_vars.each do |var, purpose|
      if ENV[var]
        puts "   ✅ #{var} - #{purpose}"
      else
        puts "   ⚠️  #{var} - #{purpose} (NOT SET - some image services may not work)"
      end
    end
    
    # Check if we have minimum required setup
    has_groq = ENV['GROQ_API_KEY']
    has_gemini = ENV['GEMINI_API_KEY']
    
    if has_groq && has_gemini
      puts "\n✅ Minimum configuration met: Whisper + LLM services available"
    else
      puts "\n❌ Missing required API keys:"
      puts "   - GROQ_API_KEY: #{has_groq ? '✅' : '❌'}"
      puts "   - GEMINI_API_KEY: #{has_gemini ? '✅' : '❌'}"
    end
  end

  def generate_summary
    puts "\n📊 Configuration Summary"
    puts "=" * 25
    
    puts "🎵 Whisper (Speech-to-Text):"
    puts "   Service: Groq API"
    puts "   Model: #{Config::GROQ_CONFIG[:default_model]}"
    puts "   Status: #{ENV['GROQ_API_KEY'] ? '✅ Ready' : '❌ Missing API Key'}"
    
    puts "\n🧠 LLM (Content Analysis):"
    puts "   Service: Google Gemini API"
    puts "   Model: #{Config::GEMINI_CONFIG[:model]}"
    puts "   Status: #{ENV['GEMINI_API_KEY'] ? '✅ Ready' : '❌ Missing API Key'}"
    
    puts "\n🖼️  Image Services:"
    image_services = []
    image_services << "Unsplash" if ENV['UNSPLASH_API_KEY']
    image_services << "Pexels" if ENV['PEXELS_API_KEY']
    image_services << "Pixabay" if ENV['PIXABAY_API_KEY']
    image_services << "WikiMedia" # Always available
    image_services << "Lorem Picsum" # Always available
    image_services << "Openverse" # Always available
    
    puts "   Available: #{image_services.join(', ')}"
    puts "   Status: ✅ Ready (#{image_services.length} services)"
    
    puts "\n🎯 Pipeline Flow:"
    puts "   Audio → Whisper (Groq) → Transcription"
    puts "   Transcription → Gemini (LLM) → Image Queries"
    puts "   Image Queries → Image Services → Images"
    puts "   Images + Audio → Video Generation → Final Video"
  end
end

# Run the tests if this script is executed directly
if __FILE__ == $0
  puts "Pipeline Configuration Test Suite"
  puts "================================"
  puts "This test verifies that the pipeline is correctly configured"
  puts "to use Groq for Whisper and Gemini for LLM tasks."
  puts ""
  
  test = PipelineConfigurationTest.new
  test.run_tests
  test.generate_summary
end 