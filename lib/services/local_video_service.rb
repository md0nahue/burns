require 'json'
require 'fileutils'
require 'open3'
require 'tempfile'

# Local video generation service
# This replaces the Lambda-based video generation for faster development
class LocalVideoService
  def initialize
    @temp_dir = Dir.mktmpdir
    @ffmpeg_path = find_ffmpeg
    puts "🎬 Local Video Service initialized"
    puts "  📁 Temp directory: #{@temp_dir}"
    puts "  🎥 FFmpeg path: #{@ffmpeg_path}"
  end

  # Generate Ken Burns video from project data
  # @param project_id [String] Project identifier
  # @param manifest [Hash] Project manifest
  # @return [Hash] Generation result
  def generate_video(project_id, manifest)
    puts "🎬 Generating Ken Burns video locally for project: #{project_id}"
    
    begin
      # Download project data
      project_data = download_project_data(project_id, manifest)
      
      # Generate video segments
      segment_videos = generate_segments(project_data)
      
      # Combine segments with audio
      final_video_path = combine_segments_with_audio(segment_videos, project_data[:audio_file])
      
      # Move to completed folder
      completed_video_path = move_to_completed_folder(final_video_path, project_id)
      
      # Clean up
      cleanup_temp_files
      
      {
        success: true,
        video_path: completed_video_path,
        duration: get_video_duration(completed_video_path),
        resolution: '1920x1080',
        fps: 24,
        segments_count: segment_videos.length,
        generated_at: Time.now.iso8601
      }
      
    rescue => e
      puts "❌ Error generating video: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Complete video from segments (useful for handling failed Lambda segments)
  # @param project_id [String] Project identifier
  # @param segment_results [Array] Array of segment results from previous processing
  # @return [Hash] Completion result
  def complete_video_from_segments(project_id, segment_results = [])
    puts "🎬 Completing video from segments locally for project: #{project_id}"
    
    begin
      # If no segment results provided, try to find them from S3
      if segment_results.empty?
        puts "  📥 No segment results provided, downloading from S3..."
        segment_results = download_segments_from_s3(project_id)
      end
      
      if segment_results.empty?
        return { success: false, error: "No segments found to combine" }
      end
      
      puts "  📊 Found #{segment_results.length} segments to combine"
      
      # Download audio file
      audio_file = download_project_audio(project_id)
      
      # Download and combine segments
      segment_videos = download_segment_videos(project_id, segment_results)
      
      if segment_videos.empty?
        return { success: false, error: "Failed to download segment videos" }
      end
      
      # Combine segments with audio
      final_video_path = combine_segments_with_audio(segment_videos, audio_file)
      
      if final_video_path && File.exist?(final_video_path)
        # Move to completed folder
        completed_video_path = move_to_completed_folder(final_video_path, project_id)
        
        # Upload to S3
        s3_key = upload_final_video_to_s3(completed_video_path, project_id)
        
        # Clean up
        cleanup_temp_files
        
        {
          success: true,
          video_path: completed_video_path,
          video_s3_key: s3_key,
          duration: get_video_duration(completed_video_path),
          resolution: '1920x1080',
          fps: 24,
          segments_count: segment_results.length,
          generated_at: Time.now.iso8601
        }
      else
        { success: false, error: "Failed to create final video" }
      end
      
    rescue => e
      puts "❌ Error completing video: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Public method for creating single image Ken Burns videos
  # @param image_path [String] Path to the image file
  # @param duration [Float] Duration in seconds
  # @param output_path [String] Path for the output video
  # @return [Boolean] Success status
  def create_single_image_ken_burns(image_path, duration, output_path)
    # Get random Ken Burns effect for variety
    ken_burns_filter = get_random_ken_burns_effect(duration)
    
    # Ultra-smooth Ken Burns with highest quality settings
    # NEW APPROACH: Direct scale/crop with time-based interpolation
    # This eliminates the jittery motion from the old zoompan approach
    filter_complex = [
      "[0:v]#{ken_burns_filter},",
      "scale=1920:1080:flags=lanczos[v]"
    ].join
    
    cmd = [
      @ffmpeg_path,
      "-i", image_path,
      "-filter_complex", filter_complex,
      "-map", "[v]",
      "-t", duration.to_s,
      "-fps_mode", "cfr",   # Constant frame rate mode (replaces vsync)
      "-r", "24",           # Explicit frame rate
      "-c:v", "libx264",
      "-preset", "slower",  # Higher quality encoding
      "-crf", "16",         # Lower CRF for higher quality
      "-profile:v", "high",
      "-level", "4.1",
      "-pix_fmt", "yuv420p",
      "-g", "48",           # GOP size (2 seconds at 24fps)
      "-keyint_min", "24",  # Minimum keyframe interval
      "-sc_threshold", "0", # Disable scene cut detection
      "-movflags", "+faststart",
      "-y", # Overwrite output
      output_path
    ]
    
    puts "    🎥 Creating ultra-smooth Ken Burns effect: #{File.basename(output_path)}"
    system(*cmd)
  end

  private

  def download_project_data(project_id, manifest)
    puts "📥 Downloading project data..."
    
    # Ensure manifest keys are strings for consistency
    manifest = manifest.transform_keys(&:to_s) if manifest.is_a?(Hash)
    
    # Download audio file
    audio_file = download_audio_file(manifest['audio_file'])
    
    # Download images for each segment
    segments_with_images = []
    manifest['segments'].each_with_index do |segment, index|
      # Ensure segment keys are strings
      segment = segment.transform_keys(&:to_s) if segment.is_a?(Hash)
      
      segment_images = download_segment_images(segment['generated_images'])
      segments_with_images << {
        id: segment['id'],
        start_time: segment['start_time'].to_f,
        end_time: segment['end_time'].to_f,
        text: segment['text'],
        images: segment_images,
        duration: segment['end_time'].to_f - segment['start_time'].to_f
      }
    end
    
    {
      project_id: project_id,
      audio_file: audio_file,
      segments: segments_with_images
    }
  end

  def download_audio_file(audio_s3_key)
    # Handle case where audio_s3_key might be a Hash or other type
    audio_path = audio_s3_key.is_a?(String) ? audio_s3_key : 'sad.m4a'
    
    local_path = File.join(@temp_dir, "audio#{File.extname(audio_path)}")
    
    # For now, assume the audio file is already local
    # In a real implementation, you'd download from S3
    if File.exist?(audio_path)
      FileUtils.cp(audio_path, local_path)
      puts "    📁 Copied audio file: #{audio_path} -> #{local_path}"
    else
      # Create a silent audio file as fallback
      puts "    ⚠️  Audio file not found, creating silent audio"
      create_silent_audio(local_path, 30.0) # 30 seconds
    end
    
    local_path
  end

  def download_segment_images(image_data_array)
    images = []
    
    # Handle case where image_data_array might be nil or not an array
    return images unless image_data_array.is_a?(Array)
    
    image_data_array.each_with_index do |image_data, index|
      # Ensure image_data is a hash with string keys
      image_data = image_data.transform_keys(&:to_s) if image_data.is_a?(Hash)
      
      # Try to download the actual image from the URL
      image_path = download_image_from_url(image_data['url'], index)
      
      if image_path && File.exist?(image_path)
        images << {
          path: image_path,
          query: image_data['query'] || "image_#{index}",
          provider: image_data['provider'] || 'downloaded'
        }
        puts "      ✅ Downloaded image #{index + 1}: #{image_data['url']}"
      else
        # Fallback to placeholder if download fails
        placeholder_path = create_placeholder_image(image_data['url'] || "placeholder_#{index}", index)
        images << {
          path: placeholder_path,
          query: image_data['query'] || "image_#{index}",
          provider: image_data['provider'] || 'placeholder'
        }
        puts "      ⚠️  Failed to download image #{index + 1}, using placeholder"
      end
    end
    
    images
  end

  def download_image_from_url(url, index)
    return nil unless url && url.is_a?(String) && url.start_with?('http')
    
    begin
      require 'net/http'
      require 'uri'
      
      # Parse URL and download image
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        # Determine file extension from URL or content type
        extension = get_image_extension(url, response['content-type'])
        output_path = File.join(@temp_dir, "downloaded_image_#{index}#{extension}")
        
        # Save the image
        File.open(output_path, 'wb') do |file|
          file.write(response.body)
        end
        
        # Verify the image is valid
        if File.exist?(output_path) && File.size(output_path) > 0
          return output_path
        end
      end
    rescue => e
      puts "      ❌ Error downloading image #{index + 1}: #{e.message}"
    end
    
    nil
  end

  def get_image_extension(url, content_type)
    # Try to get extension from URL first
    if url.include?('.')
      ext = File.extname(url).downcase
      return ext if %w[.jpg .jpeg .png .gif .bmp .webp].include?(ext)
    end
    
    # Fallback to content type
    case content_type
    when /jpeg|jpg/
      '.jpg'
    when /png/
      '.png'
    when /gif/
      '.gif'
    when /webp/
      '.webp'
    when /bmp/
      '.bmp'
    else
      '.jpg' # Default fallback
    end
  end

  def generate_segments(project_data)
    puts "🎬 Generating #{project_data[:segments].length} video segments..."
    
    segment_videos = []
    
    project_data[:segments].each_with_index do |segment, index|
      puts "  📹 Processing segment #{index + 1}/#{project_data[:segments].length}"
      
      segment_video = generate_segment_video(segment)
      segment_videos << segment_video if segment_video
    end
    
    segment_videos
  end

  def generate_segment_video(segment)
    return nil if segment[:images].empty?
    
    # Create a simple video with Ken Burns effect
    output_path = File.join(@temp_dir, "segment_#{segment[:id]}.mp4")
    
    # Use FFmpeg to create a video with zoom/pan effect
    create_ken_burns_video(segment[:images], segment[:duration], output_path)
    
    output_path
  end

  def create_ken_burns_video(images, duration, output_path)
    return nil if images.empty?
    
    if images.length == 1
      # Single image Ken Burns effect
      create_single_image_ken_burns(images.first[:path], duration, output_path)
    else
      # If somehow we have multiple images, just use the first one
      puts "    ⚠️  Multiple images found, using first image only"
      create_single_image_ken_burns(images.first[:path], duration, output_path)
    end
  end

  def get_random_ken_burns_effect(duration)
    # ULTRA-SMOOTH KEN BURNS EFFECTS - Complete rewrite using scale/crop approach
    # NEW APPROACH: Use time-based interpolation instead of incremental zoom
    # This provides perfectly smooth motion without jitter
    
    effects = [
      # 1. Ultra-smooth zoom in from center using time-based interpolation
      "scale=2560:1440:flags=lanczos,crop='1920+200*sin(t/(#{duration})*3.14159)':'1080+150*sin(t/(#{duration})*3.14159)':x='320-100*sin(t/(#{duration})*3.14159)':y='180-75*sin(t/(#{duration})*3.14159)'",
      
      # 2. Smooth zoom out from center
      "scale=3840:2160:flags=lanczos,crop='1920+960*cos(t/(#{duration})*3.14159)':'1080+540*cos(t/(#{duration})*3.14159)':x='960-480*cos(t/(#{duration})*3.14159)':y='540-270*cos(t/(#{duration})*3.14159)'",
      
      # 3. Gentle pan left to right with slight zoom
      "scale=2560:1440:flags=lanczos,crop='1920+100*sin(t/(#{duration})*3.14159)':'1080+50*sin(t/(#{duration})*3.14159)':x='320*t/(#{duration})':y='180-25*sin(t/(#{duration})*3.14159)'",
      
      # 4. Gentle pan right to left with slight zoom  
      "scale=2560:1440:flags=lanczos,crop='1920+100*sin(t/(#{duration})*3.14159)':'1080+50*sin(t/(#{duration})*3.14159)':x='320*(1-t/(#{duration}))':y='180-25*sin(t/(#{duration})*3.14159)'",
      
      # 5. Smooth diagonal pan (top-left to bottom-right)
      "scale=2560:1440:flags=lanczos,crop='1920+150*sin(t/(#{duration})*3.14159)':'1080+75*sin(t/(#{duration})*3.14159)':x='320*t/(#{duration})':y='180*t/(#{duration})'",
      
      # 6. Smooth diagonal pan (bottom-right to top-left)
      "scale=2560:1440:flags=lanczos,crop='1920+150*sin(t/(#{duration})*3.14159)':'1080+75*sin(t/(#{duration})*3.14159)':x='320*(1-t/(#{duration}))':y='180*(1-t/(#{duration}))'",
      
      # 7. Cinematic slow zoom with subtle movement
      "scale=2048:1152:flags=lanczos,crop='1920+64*sin(t/(#{duration})*3.14159)':'1080+36*sin(t/(#{duration})*3.14159)':x='64*sin(t/(#{duration})*1.5)':y='36*cos(t/(#{duration})*1.5)'",
      
      # 8. Gentle circular motion
      "scale=2560:1440:flags=lanczos,crop='1920+100*sin(t/(#{duration})*3.14159)':'1080+100*sin(t/(#{duration})*3.14159)':x='320+100*sin(t/(#{duration})*6.28)':y='180+100*cos(t/(#{duration})*6.28)'",
      
      # 9. Smooth focus shift top to bottom
      "scale=2560:1440:flags=lanczos,crop='1920+120*sin(t/(#{duration})*3.14159)':'1080+60*sin(t/(#{duration})*3.14159)':x='320-60*sin(t/(#{duration})*3.14159)':y='180*t/(#{duration})'",
      
      # 10. Smooth focus shift bottom to top
      "scale=2560:1440:flags=lanczos,crop='1920+120*sin(t/(#{duration})*3.14159)':'1080+60*sin(t/(#{duration})*3.14159)':x='320-60*sin(t/(#{duration})*3.14159)':y='180*(1-t/(#{duration}))'",
      
      # 11. Ultra-cinematic slow zoom with drift
      "scale=2304:1296:flags=lanczos,crop='1920+192*sin(t/(#{duration})*3.14159)':'1080+108*sin(t/(#{duration})*3.14159)':x='192*sin(t/(#{duration})*2)':y='108*cos(t/(#{duration})*2)'",
      
      # 12. Subtle breathing effect (zoom in/out)
      "scale=2560:1440:flags=lanczos,crop='1920+320*sin(t/(#{duration})*6.28)':'1080+180*sin(t/(#{duration})*6.28)':x='320*sin(t/(#{duration})*6.28)':y='180*sin(t/(#{duration})*6.28)'",
      
      # 13. Gentle S-curve pan
      "scale=2560:1440:flags=lanczos,crop='1920+100*sin(t/(#{duration})*3.14159)':'1080+50*sin(t/(#{duration})*3.14159)':x='320*sin(t/(#{duration})*3.14159)':y='180*cos(t/(#{duration})*3.14159)'",
      
      # 14. Smooth arc motion
      "scale=2560:1440:flags=lanczos,crop='1920+150*sin(t/(#{duration})*3.14159)':'1080+75*sin(t/(#{duration})*3.14159)':x='320*cos(t/(#{duration})*3.14159)':y='180*sin(t/(#{duration})*3.14159)'",
      
      # 15. Cinematic reveal (zoom out with drift)
      "scale=3840:2160:flags=lanczos,crop='1920+960*cos(t/(#{duration})*3.14159)':'1080+540*cos(t/(#{duration})*3.14159)':x='960*cos(t/(#{duration})*3.14159)+200*sin(t/(#{duration})*2)':y='540*cos(t/(#{duration})*3.14159)+150*cos(t/(#{duration})*2)'"
    ]
    
    # Get random effect
    effect_index = rand(effects.length)
    effects[effect_index]
  end

  def combine_segments_with_audio(segment_videos, audio_file)
    puts "🎬 Combining #{segment_videos.length} segments with audio..."
    
    return nil if segment_videos.empty?
    
    # Create a file list for concatenation
    file_list_path = File.join(@temp_dir, "file_list.txt")
    File.open(file_list_path, 'w') do |f|
      segment_videos.each do |video_path|
        f.puts "file '#{video_path}'"
      end
    end
    
    # Combine videos
    combined_video_path = File.join(@temp_dir, "combined_video.mp4")
    
    cmd = [
      @ffmpeg_path,
      "-f", "concat",
      "-safe", "0",
      "-i", file_list_path,
      "-c", "copy",
      "-y",
      combined_video_path
    ]
    
    system(*cmd)
    
    # Add audio if available
    if audio_file && File.exist?(audio_file)
      final_video_path = File.join(@temp_dir, "final_video.mp4")
      
      cmd = [
        @ffmpeg_path,
        "-i", combined_video_path,
        "-i", audio_file,
        "-c:v", "copy",
        "-c:a", "aac",
        "-shortest",
        "-y",
        final_video_path
      ]
      
      system(*cmd)
      final_video_path
    else
      combined_video_path
    end
  end

  def move_to_completed_folder(video_path, project_id)
    return nil unless video_path && File.exist?(video_path)
    
    # Create completed directory
    completed_dir = "completed"
    FileUtils.mkdir_p(completed_dir)
    
    # Generate filename
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "#{project_id}_#{timestamp}_ken_burns_video.mp4"
    completed_path = File.join(completed_dir, filename)
    
    # Move video to completed folder
    FileUtils.mv(video_path, completed_path)
    
    puts "✅ Video saved to: #{completed_path}"
    completed_path
  end

  def create_placeholder_image(url, index)
    # Create a simple colored rectangle as placeholder
    width, height = 1920, 1080
    output_path = File.join(@temp_dir, "placeholder_#{index}.jpg")
    
    # Create a colored rectangle using ImageMagick or similar
    # For now, create a simple text-based image
    colors = ['red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'cyan', 'magenta', 'brown']
    color = colors[index % colors.length]
    
    cmd = [
      @ffmpeg_path,
      "-f", "lavfi",
      "-i", "color=c=#{color}:s=#{width}x#{height}:d=1",
      "-frames:v", "1",
      "-y",
      output_path
    ]
    
    puts "      🎨 Creating placeholder image #{index + 1}: #{color} (#{width}x#{height})"
    system(*cmd)
    output_path
  end

  def create_silent_audio(output_path, duration)
    cmd = [
      @ffmpeg_path,
      "-f", "lavfi",
      "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
      "-t", duration.to_s,
      "-c:a", "aac",
      "-y",
      output_path
    ]
    
    system(*cmd)
    output_path
  end

  def get_video_duration(video_path)
    return 0 unless video_path && File.exist?(video_path)
    
    cmd = [
      @ffmpeg_path,
      "-i", video_path,
      "-show_entries", "format=duration",
      "-v", "quiet",
      "-of", "csv=p=0"
    ]
    
    duration = `#{cmd.join(' ')}`.strip.to_f
    duration
  end

  def find_ffmpeg
    # Try to find ffmpeg in PATH
    ffmpeg_paths = ['ffmpeg', '/usr/local/bin/ffmpeg', '/opt/homebrew/bin/ffmpeg']
    
    ffmpeg_paths.each do |path|
      if system("which #{path} > /dev/null 2>&1")
        return path
      end
    end
    
    raise "FFmpeg not found. Please install FFmpeg to generate videos."
  end

  def download_segments_from_s3(project_id)
    # This would download segment info from S3 - for now return empty
    # In a real implementation, we'd check S3 for available segments
    []
  end

  def download_project_audio(project_id)
    # Download the project's audio file from S3
    audio_path = File.join(@temp_dir, "audio.mp3")
    
    # Try common audio file locations
    audio_keys = [
      "projects/#{project_id}/audio/#{project_id}.mp3",
      "projects/#{project_id}/#{project_id}.mp3",
      "#{project_id}.mp3"
    ]
    
    audio_keys.each do |key|
      begin
        # In a real implementation, download from S3
        # For now, try to find local file
        local_audio = "#{project_id}.mp3"
        if File.exist?(local_audio)
          FileUtils.cp(local_audio, audio_path)
          return audio_path
        end
      rescue
        # Continue to next key
      end
    end
    
    nil
  end

  def download_segment_videos(project_id, segment_results)
    segment_videos = []
    
    segment_results.each do |result|
      next unless result[:success] && result[:segment_s3_key]
      
      segment_path = File.join(@temp_dir, "segment_#{result[:segment_id]}.mp4")
      
      # In a real implementation, download from S3
      # For now, this would be handled by the calling script
      if File.exist?(segment_path)
        segment_videos << segment_path
      end
    end
    
    segment_videos
  end

  def upload_final_video_to_s3(video_path, project_id)
    # In a real implementation, upload to S3
    # For now, return a mock S3 key
    "projects/#{project_id}/final_video.mp4"
  end

  def cleanup_temp_files
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end
end 