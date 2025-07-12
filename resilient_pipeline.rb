#!/usr/bin/env ruby

require_relative 'lib/pipeline/video_generator'
require_relative 'config/services'
require 'fileutils'
require 'time'

# 🚀 RESILIENT AUDIO PROCESSING PIPELINE 
# Enhanced version with automatic retry, fallback, and monitoring
# 
# Usage: ruby resilient_pipeline.rb <audio_file_path>
# Example: ruby resilient_pipeline.rb first.m4a

class ResilientPipeline
  def initialize
    @generator = VideoGenerator.new
    setup_logging
  end

  def process(audio_file)
    @pipeline_start = Time.now
    log_info "=== RESILIENT PIPELINE STARTED ===", "🚀"
    log_info "Audio file: #{audio_file}", "📁"
    log_info "Enhanced features: Retry logic, local fallback, partial recovery", "✨"

    # Validate input
    unless File.exist?(audio_file)
      log_error "Audio file '#{audio_file}' not found"
      return false
    end

    # Check if completed video already exists
    if completed_video_exists?(audio_file)
      log_success "Video already completed, using existing file"
      return true
    end

    # Enhanced generation options for resilience
    options = {
      resolution: '1080p',
      fps: 24,
      test_mode: false,
      ken_burns_effect: true,
      smooth_transitions: true,
      image_duration: 4.0,
      transition_duration: 1.0,
      zoom_factor: 1.4,
      pan_speed: 0.3,
      cache_images: true,
      cache_transcription: true,
      cache_analysis: true,
      force: false,
      # NEW RESILIENCE OPTIONS
      max_retries: 5,
      retry_with_fallback: true,
      partial_video_threshold: 0.6,  # Accept video if 60% of segments succeed
      lambda_timeout_threshold: 3,   # Switch to local after 3 timeouts
      monitor_performance: true
    }

    log_info "Starting video generation with resilient options...", "🎬"
    
    begin
      result = @generator.generate_video(audio_file, options)
      
      if result[:success]
        handle_success(result)
        return true
      elsif result[:fallback_needed]
        log_warn "Lambda processing failed, attempting complete local fallback..."
        return attempt_local_fallback(audio_file, options)
      else
        handle_failure(result)
        return false
      end
      
    rescue => e
      log_error "Pipeline crashed: #{e.message}"
      log_debug "Stack trace: #{e.backtrace.first(5).join("\n")}"
      
      # Attempt emergency local fallback
      log_warn "Attempting emergency local processing..."
      return attempt_emergency_fallback(audio_file)
    end
  end

  private

  def setup_logging
    FileUtils.mkdir_p('logs')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    @log_file = File.open("logs/resilient_pipeline_#{timestamp}.log", 'a')
  end

  def log_info(message, emoji = "ℹ️")
    puts "#{emoji} #{message}"
    @log_file.puts "[#{Time.now.iso8601}] INFO: #{message}"
    @log_file.flush
  end

  def log_success(message, emoji = "✅")
    puts "#{emoji} #{message}"
    @log_file.puts "[#{Time.now.iso8601}] SUCCESS: #{message}"
    @log_file.flush
  end

  def log_warn(message, emoji = "⚠️")
    puts "#{emoji} #{message}"
    @log_file.puts "[#{Time.now.iso8601}] WARN: #{message}"
    @log_file.flush
  end

  def log_error(message, emoji = "❌")
    puts "#{emoji} #{message}"
    @log_file.puts "[#{Time.now.iso8601}] ERROR: #{message}"
    @log_file.flush
  end

  def log_debug(message, emoji = "🔍")
    puts "#{emoji} #{message}"
    @log_file.puts "[#{Time.now.iso8601}] DEBUG: #{message}"
    @log_file.flush
  end

  def completed_video_exists?(audio_file)
    audio_basename = File.basename(audio_file, File.extname(audio_file))
    completed_path = "completed/#{audio_basename}_ken_burns_video.mp4"
    
    if File.exist?(completed_path)
      # Test if video is valid
      test_result = system("ffprobe -v quiet -print_format json -show_format '#{completed_path}' > /dev/null 2>&1")
      if test_result
        log_info "Valid completed video found: #{completed_path}", "📹"
        return true
      else
        log_warn "Corrupted video found, will regenerate: #{completed_path}"
        File.delete(completed_path) rescue nil
      end
    end
    
    false
  end

  def handle_success(result)
    duration = Time.now - @pipeline_start
    log_success "=== PIPELINE COMPLETED SUCCESSFULLY ===", "🎉"
    log_info "Project ID: #{result[:project_id]}", "🆔"
    log_info "Video URL: #{result[:video_url]}", "📹"
    log_info "Duration: #{result[:duration]} seconds", "⏱️"
    log_info "Resolution: #{result[:resolution]}", "📐"
    log_info "Segments: #{result[:segments_count]}", "📝"
    log_info "Pipeline runtime: #{duration.round(2)}s", "⏱️"
    
    # Download if available
    download_final_video(result)
  end

  def handle_failure(result)
    duration = Time.now - @pipeline_start
    log_error "=== PIPELINE FAILED ==="
    log_error "Error: #{result[:error]}"
    log_error "Pipeline runtime: #{duration.round(2)}s"
    
    if result[:partial_results]
      successful = result[:partial_results].count { |r| r[:success] }
      total = result[:partial_results].length
      log_info "Partial success: #{successful}/#{total} segments", "📊"
    end
  end

  def download_final_video(result)
    return unless result[:video_url] && !result[:video_url].empty?
    
    audio_basename = File.basename(ARGV[0], File.extname(ARGV[0]))
    completed_path = "completed/#{audio_basename}_ken_burns_video.mp4"
    
    log_info "Downloading final video...", "📥"
    FileUtils.mkdir_p('completed')
    
    # Extract S3 key and download
    video_s3_key = result[:video_s3_key] || "projects/#{result[:project_id]}/final_video.mp4"
    
    if system("aws s3 cp s3://burns-videos/#{video_s3_key} '#{completed_path}'")
      file_size = (File.size(completed_path) / 1024.0 / 1024.0).round(2)
      log_success "Video downloaded: #{completed_path} (#{file_size} MB)", "💾"
    else
      log_warn "Failed to download video, but it's available at: #{result[:video_url]}"
    end
  end

  def attempt_local_fallback(audio_file, options)
    log_info "=== STARTING LOCAL FALLBACK PROCESSING ===", "🏠"
    
    begin
      # Use the force completion approach but integrated
      require_relative 'force_complete_first'
      
      audio_basename = File.basename(audio_file, File.extname(audio_file))
      completed_path = "completed/#{audio_basename}_ken_burns_video.mp4"
      
      # The force completion script should handle everything
      if File.exist?(completed_path)
        file_size = (File.size(completed_path) / 1024.0 / 1024.0).round(2)
        log_success "Local fallback completed: #{completed_path} (#{file_size} MB)", "🎉"
        return true
      else
        log_error "Local fallback failed to create video"
        return false
      end
      
    rescue => e
      log_error "Local fallback failed: #{e.message}"
      return false
    end
  end

  def attempt_emergency_fallback(audio_file)
    log_info "=== EMERGENCY FALLBACK ===", "🚨"
    log_info "Attempting basic local video generation...", "🔧"
    
    begin
      # Super simple approach: transcribe + generate images + local video
      require_relative 'lib/services/local_video_service'
      local_service = LocalVideoService.new
      
      audio_basename = File.basename(audio_file, File.extname(audio_file))
      completed_path = "completed/#{audio_basename}_ken_burns_video.mp4"
      
      # TODO: Implement emergency fallback logic
      log_warn "Emergency fallback not fully implemented yet"
      return false
      
    rescue => e
      log_error "Emergency fallback failed: #{e.message}"
      return false
    end
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.empty?
    puts "❌ Usage: #{$0} <audio_file>"
    puts "Example: #{$0} first.m4a"
    exit 1
  end

  audio_file = ARGV[0]
  pipeline = ResilientPipeline.new
  
  success = pipeline.process(audio_file)
  exit(success ? 0 : 1)
end