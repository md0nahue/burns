require_relative '../services/whisper_service'
require_relative '../services/gemini_service'
require_relative '../services/s3_service'
require_relative '../services/lambda_service'
require_relative 'audio_processor'
require_relative 'content_analyzer'
require_relative 'image_generator'
require 'json'
require 'securerandom'

class VideoGenerator
  def initialize
    @whisper_service = WhisperService.new
    @gemini_service = GeminiService.new
    @s3_service = S3Service.new
    @lambda_service = LambdaService.new
    @audio_processor = AudioProcessor.new
    @content_analyzer = ContentAnalyzer.new
    @image_generator = ImageGenerator.new
  end

  # Generate complete Ken Burns video from audio file
  # @param audio_file_path [String] Path to audio file
  # @param options [Hash] Generation options
  # @return [Hash] Generation result
  def generate_video(audio_file_path, options = {})
    project_id = options[:project_id] || generate_project_id
    
    puts "🎬 Starting Ken Burns video generation"
    puts "  📁 Audio file: #{audio_file_path}"
    puts "  🆔 Project ID: #{project_id}"
    puts "  ⚙️  Options: #{options}"
    
    begin
      # Step 1: Process audio and transcribe
      puts "\n📝 Step 1: Processing audio and transcription..."
      transcription_result = process_audio(audio_file_path, project_id)
      
      unless transcription_result[:success]
        return { success: false, error: "Audio processing failed: #{transcription_result[:error]}" }
      end
      
      # Step 2: Analyze content and generate image queries
      puts "\n🧠 Step 2: Analyzing content and generating image queries..."
      analysis_result = analyze_content(project_id, transcription_result[:segments])
      
      unless analysis_result[:success]
        return { success: false, error: "Content analysis failed: #{analysis_result[:error]}" }
      end
      
      # Step 3: Generate images for each segment
      puts "\n🖼️  Step 3: Generating images for segments..."
      image_result = generate_images(project_id, analysis_result[:segments])
      
      unless image_result[:success]
        return { success: false, error: "Image generation failed: #{image_result[:error]}" }
      end
      
      # Step 4: Create project manifest
      puts "\n📋 Step 4: Creating project manifest..."
      manifest_result = create_project_manifest(project_id, transcription_result, analysis_result, image_result)
      
      unless manifest_result[:success]
        return { success: false, error: "Manifest creation failed: #{manifest_result[:error]}" }
      end
      
      # Step 5: Generate final video
      puts "\n🎥 Step 5: Generating final Ken Burns video..."
      video_result = generate_final_video(project_id, options)
      
      unless video_result[:success]
        return { success: false, error: "Video generation failed: #{video_result[:error]}" }
      end
      
      # Success response
      result = {
        success: true,
        project_id: project_id,
        video_url: video_result[:video_url],
        video_s3_key: video_result[:video_s3_key],
        duration: video_result[:duration],
        resolution: video_result[:resolution],
        fps: video_result[:fps],
        segments_count: analysis_result[:segments].length,
        images_generated: image_result[:total_images],
        generated_at: video_result[:generated_at]
      }
      
      puts "\n✅ Ken Burns video generation completed successfully!"
      puts "  📹 Video URL: #{result[:video_url]}"
      puts "  ⏱️  Duration: #{result[:duration]} seconds"
      puts "  📐 Resolution: #{result[:resolution]}"
      puts "  🎬 Segments: #{result[:segments_count]}"
      puts "  🖼️  Images: #{result[:images_generated]}"
      
      result
      
    rescue => e
      puts "❌ Error in video generation: #{e.message}"
      { success: false, error: e.message, project_id: project_id }
    end
  end

  # Process audio file and transcribe
  # @param audio_file_path [String] Path to audio file
  # @param project_id [String] Project identifier
  # @return [Hash] Processing result
  def process_audio(audio_file_path, project_id)
    puts "  🎵 Processing audio file..."
    
    begin
      # Validate audio file
      unless File.exist?(audio_file_path)
        return { success: false, error: "Audio file not found: #{audio_file_path}" }
      end
      
      # Process audio file using AudioProcessor
      puts "    🎤 Processing audio with AudioProcessor..."
      audio_result = @audio_processor.process_audio(audio_file_path)
      
      unless audio_result[:segments]
        return { success: false, error: "Audio processing failed: no segments returned" }
      end
      
      # Upload audio file to S3
      audio_s3_key = @s3_service.upload_audio_file(audio_file_path, project_id)
      
      {
        success: true,
        segments: audio_result[:segments],
        audio_file: audio_s3_key,
        duration: audio_result[:duration],
        language: 'en' # Default language
      }
      
    rescue => e
      { success: false, error: "Audio processing error: #{e.message}" }
    end
  end

  # Analyze content and generate image queries
  # @param project_id [String] Project identifier
  # @param segments [Array] Audio segments
  # @return [Hash] Analysis result
  def analyze_content(project_id, segments)
    puts "  📊 Analyzing content and generating queries..."
    
    begin
      # Analyze content and generate image queries
      analysis = @content_analyzer.analyze_segments(segments)
      
      unless analysis[:success]
        return { success: false, error: "Content analysis failed: #{analysis[:error]}" }
      end
      
      # Distribute queries across segments
      segments_with_queries = @content_analyzer.distribute_queries(segments, analysis[:queries])
      
      {
        success: true,
        segments: segments_with_queries,
        total_queries: analysis[:queries].length,
        analysis_summary: analysis[:summary]
      }
      
    rescue => e
      { success: false, error: "Content analysis error: #{e.message}" }
    end
  end

  # Generate images for segments
  # @param project_id [String] Project identifier
  # @param segments [Array] Segments with image queries
  # @return [Hash] Image generation result
  def generate_images(project_id, segments)
    puts "  🖼️  Generating images for segments..."
    
    begin
      total_images = 0
      
      segments.each do |segment|
        puts "    📝 Processing segment: #{segment[:id]}"
        
        # Generate images for this segment
        image_result = @image_generator.generate_images_for_segment(segment, project_id)
        
        if image_result[:success]
          segment[:generated_images] = image_result[:images]
          total_images += image_result[:images].length
          puts "      ✅ Generated #{image_result[:images].length} images"
        else
          puts "      ❌ Failed to generate images: #{image_result[:error]}"
          segment[:generated_images] = []
        end
      end
      
      {
        success: true,
        segments: segments,
        total_images: total_images
      }
      
    rescue => e
      { success: false, error: "Image generation error: #{e.message}" }
    end
  end

  # Create project manifest
  # @param project_id [String] Project identifier
  # @param transcription_result [Hash] Transcription result
  # @param analysis_result [Hash] Analysis result
  # @param image_result [Hash] Image generation result
  # @return [Hash] Manifest creation result
  def create_project_manifest(project_id, transcription_result, analysis_result, image_result)
    puts "  📋 Creating project manifest..."
    
    begin
      manifest = {
        project_id: project_id,
        created_at: Time.now.iso8601,
        audio_file: transcription_result[:audio_file],
        duration: transcription_result[:duration],
        language: transcription_result[:language],
        segments: image_result[:segments],
        analysis_summary: analysis_result[:analysis_summary],
        total_images: image_result[:total_images],
        status: 'ready_for_video_generation'
      }
      
      # Upload manifest to S3
      manifest_key = @s3_service.upload_project_manifest(project_id, manifest)
      
      {
        success: true,
        manifest_key: manifest_key,
        manifest: manifest
      }
      
    rescue => e
      { success: false, error: "Manifest creation error: #{e.message}" }
    end
  end

  # Generate final video using Lambda (concurrent approach)
  # @param project_id [String] Project identifier
  # @param options [Hash] Video generation options
  # @return [Hash] Video generation result
  def generate_final_video(project_id, options)
    puts "  🎥 Generating final video using concurrent Lambda processing..."
    
    begin
      # Get segments from manifest
      manifest = @s3_service.get_project_manifest(project_id)
      return { success: false, error: "Could not get project manifest" } unless manifest[:success]
      
      segments = manifest[:manifest]['segments']
      
      # Use concurrent processing for better performance
      video_result = @lambda_service.generate_video_segments_concurrently(
        project_id, 
        segments, 
        options.merge(total_segments: segments.length)
      )
      
      if video_result[:success]
        puts "    ✅ Concurrent video generation completed"
        puts "    📹 Video URL: #{video_result[:video_url]}"
        puts "    ⏱️  Duration: #{video_result[:duration]} seconds"
        puts "    ⚡ Processed #{segments.length} segments concurrently"
      else
        puts "    ❌ Concurrent video generation failed: #{video_result[:error]}"
      end
      
      video_result
      
    rescue => e
      { success: false, error: "Video generation error: #{e.message}" }
    end
  end

  # Get project status
  # @param project_id [String] Project identifier
  # @return [Hash] Project status
  def get_project_status(project_id)
    puts "📊 Getting project status: #{project_id}"
    
    begin
      # Check if manifest exists
      manifest = @s3_service.get_project_manifest(project_id)
      
      if manifest[:success]
        status = {
          project_id: project_id,
          status: manifest[:manifest]['status'],
          created_at: manifest[:manifest]['created_at'],
          duration: manifest[:manifest]['duration'],
          segments_count: manifest[:manifest]['segments'].length,
          total_images: manifest[:manifest]['total_images'],
          language: manifest[:manifest]['language']
        }
        
        puts "✅ Project status retrieved"
        puts "  📅 Created: #{status[:created_at]}"
        puts "  🔄 Status: #{status[:status]}"
        puts "  ⏱️  Duration: #{status[:duration]} seconds"
        puts "  📝 Segments: #{status[:segments_count]}"
        puts "  🖼️  Images: #{status[:total_images]}"
        
        status
      else
        { success: false, error: "Project not found or manifest missing" }
      end
      
    rescue => e
      { success: false, error: "Error getting project status: #{e.message}" }
    end
  end

  # List all projects
  # @return [Hash] Projects list
  def list_projects
    puts "📋 Listing all projects..."
    
    begin
      projects = @s3_service.list_projects
      
      if projects[:success]
        puts "✅ Found #{projects[:projects].length} projects"
        projects[:projects].each do |project|
          puts "  🆔 #{project[:project_id]} - #{project[:created_at]}"
        end
      else
        puts "❌ Error listing projects: #{projects[:error]}"
      end
      
      projects
      
    rescue => e
      { success: false, error: "Error listing projects: #{e.message}" }
    end
  end

  # Clean up project files
  # @param project_id [String] Project identifier
  # @return [Hash] Cleanup result
  def cleanup_project(project_id)
    puts "🧹 Cleaning up project: #{project_id}"
    
    begin
      result = @s3_service.cleanup_project(project_id)
      
      if result[:success]
        puts "✅ Project cleanup completed"
        puts "  🗑️  Deleted files: #{result[:deleted_files]}"
      else
        puts "❌ Project cleanup failed: #{result[:error]}"
      end
      
      result
      
    rescue => e
      { success: false, error: "Error cleaning up project: #{e.message}" }
    end
  end

  private

  # Generate unique project ID
  # @return [String] Project ID
  def generate_project_id
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    random_id = SecureRandom.hex(4)
    "burns_#{timestamp}_#{random_id}"
  end
end 