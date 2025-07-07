require_relative '../services/whisper_service'
require_relative '../services/gemini_service'
require_relative '../services/s3_service'
require_relative '../services/lambda_service'
require_relative '../services/local_video_service'
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
    @local_video_service = LocalVideoService.new
    @audio_processor = AudioProcessor.new
    @content_analyzer = ContentAnalyzer.new
    @image_generator = ImageGenerator.new
  end

  # Generate complete Ken Burns video from audio file
  # @param audio_file_path [String] Path to audio file
  # @param options [Hash] Generation options
  # @return [Hash] Generation result
  def generate_video(audio_file_path, options = {})
    project_id = options[:project_id] || generate_project_id(audio_file_path)
    force = options[:force] || options[:no_cache] || false
    puts "🎬 Starting Ken Burns video generation"
    puts "  📁 Audio file: #{audio_file_path}"
    puts "  🆔 Project ID: #{project_id}"
    puts "  ⚙️  Options: #{options}"
    
    begin
      # Step 1: Process audio and transcribe (with cache)
      puts "\n📝 Step 1: Processing audio and transcription..."
      transcription_result = nil
      if !force && @s3_service.transcription_exists?(project_id)
        puts "  💾 Using cached transcription from S3"
        transcription_result = @s3_service.get_transcription(project_id)
      else
        transcription_result = process_audio(audio_file_path, project_id)
        if transcription_result[:success]
          @s3_service.save_transcription(project_id, transcription_result)
        end
      end
      log_artifact(project_id, 'transcription', transcription_result)
      unless transcription_result[:success]
        return { success: false, error: "Audio processing failed: #{transcription_result[:error]}" }
      end
      
      # Step 2: Analyze content and generate image queries (with cache)
      puts "\n🎨 Step 2: Analyzing content and generating image queries..."
      analysis_result = nil
      if !force && @s3_service.image_analysis_exists?(project_id)
        puts "  💾 Using cached image analysis from S3"
        analysis_result = @s3_service.get_image_analysis(project_id)
      else
        analysis_result = analyze_content_for_images(transcription_result)
        if analysis_result[:success]
          @s3_service.save_image_analysis(project_id, analysis_result)
        end
      end
      log_artifact(project_id, 'gemini_analysis', analysis_result)
      unless analysis_result[:success]
        return { success: false, error: "Content analysis failed: #{analysis_result[:error]}" }
      end
      
      # Step 3: Generate images for each segment (with cache)
      puts "\n🖼️  Step 3: Generating images for segments..."
      image_result = nil
      if !force && @s3_service.image_generation_exists?(project_id)
        puts "  💾 Using cached image generation from S3"
        image_result = @s3_service.get_image_generation(project_id)
      else
        image_result = generate_images(project_id, analysis_result[:segments])
        if image_result[:success]
          @s3_service.save_image_generation(project_id, image_result)
        end
      end
      unless image_result[:success]
        return { success: false, error: "Image generation failed: #{image_result[:error]}" }
      end
      
      # Step 4: Create project manifest (with cache)
      puts "\n📋 Step 4: Creating project manifest..."
      manifest_result = nil
      if !force && @s3_service.project_manifest_exists?(project_id)
        puts "  💾 Using cached manifest from S3"
        manifest_result = @s3_service.get_project_manifest(project_id)
      else
        manifest_result = create_project_manifest(project_id, transcription_result, image_result)
        if manifest_result[:success]
          @s3_service.save_project_manifest(project_id, manifest_result[:manifest])
        end
      end
      log_artifact(project_id, 'manifest', manifest_result)
      unless manifest_result[:success]
        return { success: false, error: "Manifest creation failed: #{manifest_result[:error]}" }
      end
      
      # Step 5: Generate final video
      puts "\n🎥 Step 5: Generating final Ken Burns video..."
      video_result = generate_final_video(project_id, options)
      
      unless video_result[:success]
        return { success: false, error: "Video generation failed: #{video_result[:error]}" }
      end
      
      # Save completed video to local completed folder
      audio_basename = File.basename(audio_file_path, File.extname(audio_file_path))
      completed_video_path = "completed/#{audio_basename}_ken_burns_video.mp4"
      
      # Copy video from S3 to local completed folder if available
      if video_result[:video_s3_key] && @s3_service
        begin
          puts "📥 Downloading completed video to: #{completed_video_path}"
          @s3_service.download_video(video_result[:video_s3_key], completed_video_path)
          puts "✅ Video saved to: #{completed_video_path}"
        rescue => e
          puts "⚠️  Could not download video to local folder: #{e.message}"
        end
      end
      
      # Success response
      result = {
        success: true,
        project_id: project_id,
        video_url: video_result[:video_url],
        video_s3_key: video_result[:video_s3_key],
        local_video_path: completed_video_path,
        duration: video_result[:duration],
        resolution: video_result[:resolution],
        fps: video_result[:fps],
        segments_count: transcription_result[:segments].length,
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
      
      # Return ONLY the raw transcription data - no image queries here!
      {
        success: true,
        segments: audio_result[:segments], # Raw segments from Whisper only
        audio_file: audio_s3_key,
        duration: audio_result[:duration],
        language: 'en', # Default language
        word_count: audio_result[:word_count],
        quality_metrics: audio_result[:quality_metrics]
      }
      
    rescue => e
      { success: false, error: "Audio processing error: #{e.message}" }
    end
  end

  # Analyze content and generate image queries
  # @param transcription_result [Hash] Transcription result
  # @return [Hash] Analysis result with image queries
  def analyze_content_for_images(transcription_result)
    puts "  🎨 Analyzing content for image generation..."
    
    begin
      # Analyze segments for image queries using ContentAnalyzer
      analysis = @content_analyzer.analyze_for_images(transcription_result)
      
      {
        success: true,
        segments: analysis[:segments],
        analysis_metrics: analysis[:analysis_metrics],
        total_image_queries: analysis[:total_image_queries],
        segments_with_images: analysis[:segments_with_images]
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
        image_result = @image_generator.generate_images_for_segment(segment, { project_id: project_id })
        
        # Update segment with generated images
        segment.merge!(image_result)
        total_images += image_result[:generated_images].length
        puts "      ✅ Generated #{image_result[:generated_images].length} images"
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
  # @param image_result [Hash] Image generation result
  # @return [Hash] Manifest creation result
  def create_project_manifest(project_id, transcription_result, image_result)
    puts "  📋 Creating project manifest..."
    
    begin
      manifest = {
        project_id: project_id,
        created_at: Time.now.iso8601,
        audio_file: transcription_result[:audio_file],
        duration: transcription_result[:duration],
        language: transcription_result[:language],
        segments: image_result[:segments],
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

  # Generate final video using Lambda service for parallel processing
  # @param project_id [String] Project identifier
  # @param options [Hash] Video generation options
  # @return [Hash] Video generation result
  def generate_final_video(project_id, options)
    puts "  🎥 Generating final video using AWS Lambda for parallel processing..."
    
    begin
      # Get project manifest
      manifest_result = @s3_service.get_project_manifest(project_id)
      
      unless manifest_result[:success]
        return { success: false, error: "Failed to get project manifest: #{manifest_result[:error]}" }
      end
      
      segments = manifest_result[:manifest]['segments']
      puts "    📝 Processing #{segments.length} segments concurrently..."
      
      # Generate video using Lambda service for parallel processing
      video_result = @lambda_service.generate_video_segments_concurrently(project_id, segments, {
        resolution: options[:resolution] || '1080p',
        fps: options[:fps] || 24,
        ken_burns_effect: options[:ken_burns_effect] || true,
        smooth_transitions: options[:smooth_transitions] || true,
        total_segments: segments.length
      })
      
      if video_result[:success]
        puts "    ✅ Lambda video generation completed"
        puts "    📹 Video URL: #{video_result[:video_url]}"
        puts "    📁 S3 Key: #{video_result[:video_s3_key]}"
        puts "    ⏱️  Duration: #{video_result[:duration]} seconds"
        puts "    📐 Resolution: #{video_result[:resolution]}"
        puts "    🎬 FPS: #{video_result[:fps]}"
        
        {
          success: true,
          video_url: video_result[:video_url],
          video_s3_key: video_result[:video_s3_key],
          duration: video_result[:duration],
          resolution: video_result[:resolution],
          fps: video_result[:fps],
          generated_at: video_result[:generated_at]
        }
      else
        { success: false, error: "Lambda video generation failed: #{video_result[:error]}" }
      end
      
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

  # Generate project ID from audio file name
  # @param audio_file_path [String] Path to audio file
  # @return [String] Project ID based on file name
  def generate_project_id(audio_file_path)
    # Extract filename without extension
    filename = File.basename(audio_file_path, File.extname(audio_file_path))
    # Clean up filename for use as project ID (remove special chars, replace spaces with underscores)
    project_id = filename.gsub(/[^a-zA-Z0-9_-]/, '_').gsub(/_+/, '_').downcase
    project_id
  end

  # Helper to append debug info to log file
  def log_artifact(project_id, stage, data)
    log_dir = 'logs'
    Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
    log_file = File.join(log_dir, "pipeline_debug.log")
    File.open(log_file, 'a') do |f|
      f.puts "\n=== [#{Time.now.iso8601}] Project: #{project_id} | Stage: #{stage} ==="
      f.puts JSON.pretty_generate(data)
      f.puts "=== END #{stage} ===\n"
    end
  rescue => e
    puts "[LOGGING ERROR] Could not write to log: #{e.message}"
  end
end 