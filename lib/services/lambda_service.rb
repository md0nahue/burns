require 'aws-sdk-lambda'
require 'aws-sdk-s3'
require 'json'
require 'concurrent'
require 'timeout'
require_relative '../../config/services'

class LambdaService
  def initialize(region = nil)
    @region = region || Config::AWS_CONFIG[:region]
    @lambda_client = Aws::Lambda::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(
        Config::AWS_CONFIG[:access_key_id],
        Config::AWS_CONFIG[:secret_access_key]
      )
    )
    @function_name = Config::AWS_CONFIG[:lambda_function]
    @s3_client = Aws::S3::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(
        Config::AWS_CONFIG[:access_key_id],
        Config::AWS_CONFIG[:secret_access_key]
      )
    )
    @bucket_name = Config::AWS_CONFIG[:s3_bucket]
  end

  # Generate Ken Burns video for a project
  # @param project_id [String] Project identifier
  # @param options [Hash] Generation options
  # @return [Hash] Generation result
  def generate_video(project_id, options = {})
    puts "🎬 Generating Ken Burns video for project: #{project_id}"
    
    begin
      # Prepare payload for Lambda
      payload = {
        project_id: project_id,
        options: options
      }
      
      # Invoke Lambda function
      response = invoke_lambda_function(payload)
      
      if response[:success]
        puts "✅ Video generation completed successfully!"
        puts "  📹 Video URL: #{response[:video_url]}"
        puts "  ⏱️  Duration: #{response[:duration]} seconds"
        puts "  📐 Resolution: #{response[:resolution]}"
      else
        puts "❌ Video generation failed: #{response[:error]}"
      end
      
      response
      
    rescue => e
      puts "❌ Error generating video: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Generate video segments concurrently
  # @param project_id [String] Project identifier
  # @param segments [Array] Array of segments with images
  # @param options [Hash] Generation options
  # @return [Hash] Generation result
  def generate_video_segments_concurrently(project_id, segments, options = {})
    total_start_time = Time.now
    puts "🚀 Generating video segments concurrently for project: #{project_id}"
    puts "  📝 Segments: #{segments.length}"
    
    # Handle empty segments case
    if segments.empty?
      puts "⚠️  No segments to process - audio transcription resulted in empty segments"
      return {
        success: false,
        error: "No segments to process. This may indicate an issue with audio transcription or segmentation.",
        suggestion: "Check if the audio file contains speech and is in a supported format"
      }
    end
    
    # Calculate optimal concurrency based on segments
    max_concurrency = options[:max_concurrency] || calculate_optimal_concurrency(segments.length)
    puts "  ⚡ Concurrency: #{max_concurrency} (conservative to prevent Lambda /tmp issues)"
    
    begin
      # Create concurrent executor - can handle unlimited Lambda invocations
      executor = Concurrent::FixedThreadPool.new(max_concurrency)
      
      # Prepare segment tasks
      segment_tasks = segments.map.with_index do |segment, index|
        # Normalize keys for mixed string/symbol keys
        seg = segment.is_a?(Hash) ? segment.transform_keys(&:to_s) : segment
        
        # Debug: Check segment data
        puts "    Debug - Segment #{index}: id=#{seg['id']}, start_time=#{seg['start_time']}, end_time=#{seg['end_time']}"
        
        # Ensure we have valid timing data with safety checks
        start_time = (seg['start_time'] || seg['start'] || 0.0).to_f
        end_time = (seg['end_time'] || seg['end'] || 5.0).to_f
        
        # Ensure minimum duration
        if end_time <= start_time
          end_time = start_time + 3.0
        end
        duration = end_time - start_time
        
        # Build images array for Lambda (array of {url: ...})
        generated_images = seg['generated_images'] || []
        images = generated_images.map do |img|
          img_data = img.is_a?(Hash) ? img.transform_keys(&:to_s) : img
          url = img_data['url'] || img_data[:url]
          { url: url } if url && !url.empty?
        end.compact
        
        # Skip segments without images
        if images.empty?
          puts "    Warning - Segment #{index} has no images, skipping"
          next nil
        end
        
        {
          project_id: project_id,
          segment_id: (seg['id'] || index).to_s,
          segment_index: index,
          images: images,
          duration: duration,
          start_time: start_time,
          end_time: end_time
        }
      end.compact
      
      # Submit tasks to executor with better data passing
      futures = segment_tasks.map.with_index do |task, index|
        Concurrent::Future.execute(executor: executor) do
          enhanced_task = task.merge(segment_index: index)
          generate_segment_video(project_id, enhanced_task, options.merge(total_segments: segment_tasks.length))
        end
      end
      
      # Wait for all segments to complete
      puts "  ⏳ Waiting for #{futures.length} segments to complete..."
      results = futures.map(&:value)
      total_time = Time.now - total_start_time
      
      # Performance analysis
      cached_count = results.count { |r| r[:cached] }
      successful_count = results.count { |r| r[:success] }
      processing_times = results.select { |r| r[:processing_time] }.map { |r| r[:processing_time] }
      lambda_times = results.select { |r| r[:lambda_time] }.map { |r| r[:lambda_time] }
      
      puts "  📊 PERFORMANCE SUMMARY:"
      puts "    ⏱️  Total time: #{total_time.round(2)}s"
      puts "    ✅ Successful: #{successful_count}/#{results.length}"
      puts "    💾 Cached: #{cached_count}/#{results.length} (#{(cached_count.to_f/results.length*100).round(1)}%)"
      if processing_times.any?
        puts "    📈 Avg processing time: #{(processing_times.sum/processing_times.length).round(2)}s"
        puts "    📈 Max processing time: #{processing_times.max.round(2)}s"
      end
      if lambda_times.any?
        puts "    ⚡ Avg Lambda time: #{(lambda_times.sum/lambda_times.length).round(2)}s"
        puts "    ⚡ Max Lambda time: #{lambda_times.max.round(2)}s"
      end
      
      # Check for failures and categorize them
      failed_segments = results.select { |r| !r[:success] }
      fallback_segments = results.select { |r| r[:used_fallback] || r[:used_local_fallback] }
      
      if failed_segments.any?
        puts "❌ #{failed_segments.length} segments failed to process"
        failed_segments.each do |failure|
          puts "  ❌ Segment #{failure[:segment_id]}: #{failure[:error]}"
        end
        
        # If we have some successful segments, try to continue with partial video
        successful_segments = results.select { |r| r[:success] }
        if successful_segments.length >= (results.length * 0.6) # At least 60% success
          puts "⚠️  Continuing with #{successful_segments.length}/#{results.length} segments (#{(successful_segments.length.to_f/results.length*100).round(1)}% success rate)"
          puts "🔄 Will attempt to create video with available segments..."
        else
          return { 
            success: false, 
            error: "Too many segments failed (#{failed_segments.length}/#{results.length}). Success rate: #{(successful_segments.length.to_f/results.length*100).round(1)}%",
            partial_results: results,
            fallback_needed: true
          }
        end
      end
      
      if fallback_segments.any?
        puts "🏠 #{fallback_segments.length} segments used local fallback processing"
      end
      
      # Combine segments into final video
      puts "  🎬 Combining #{results.length} segments into final video..."
      final_result = combine_segments_into_video(project_id, results, options)
      
      # If combination failed but segments were successful, mark for fallback
      if !final_result[:success] && final_result[:fallback_needed]
        final_result[:segment_results] = results
      end
      
      executor.shutdown
      executor.wait_for_termination
      
      final_result
      
    rescue => e
      puts "❌ Error in concurrent video generation: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Generate a single video segment locally as fallback
  # @param project_id [String] Project identifier
  # @param segment_data [Hash] Segment information
  # @param options [Hash] Generation options
  # @return [Hash] Segment generation result
  def generate_segment_locally(project_id, segment_data, options = {})
    puts "    🏠 Generating segment #{segment_data[:segment_id]} locally..."
    
    begin
      # Use the local video service for fallback
      require_relative 'local_video_service'
      local_service = LocalVideoService.new
      
      # Get the first image URL from segment data
      images = segment_data[:images] || []
      if images.empty?
        return {
          success: false,
          error: "No images available for local processing",
          segment_id: segment_data[:segment_id]
        }
      end
      
      first_image_url = images[0][:url] || images[0]['url']
      duration = segment_data[:duration] || 5.0
      
      # Download image to temp location
      require 'net/http'
      require 'uri'
      require 'tempfile'
      
      temp_image = Tempfile.new(['segment_image', '.jpg'])
      uri = URI(first_image_url)
      
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        response = http.get(uri.path)
        temp_image.write(response.body)
        temp_image.flush
      end
      
      # Create output path
      temp_video = Tempfile.new(['segment_video', '.mp4'])
      temp_video.close
      
      # Generate Ken Burns video locally
      success = local_service.create_single_image_ken_burns(
        temp_image.path,
        duration,
        temp_video.path
      )
      
      if success && File.exist?(temp_video.path)
        # Upload to S3
        s3_key = "segments/#{project_id}/#{segment_data[:segment_id]}_segment.mp4"
        
        require_relative 's3_service'
        s3_service = S3Service.new
        s3_service.instance_variable_get(:@s3_client).put_object(
          bucket: Config::AWS_CONFIG[:s3_bucket],
          key: s3_key,
          body: File.read(temp_video.path)
        )
        
        # Clean up
        temp_image.unlink
        temp_video.unlink
        
        {
          success: true,
          segment_id: segment_data[:segment_id],
          segment_s3_key: s3_key,
          duration: duration,
          start_time: segment_data[:start_time],
          end_time: segment_data[:end_time],
          used_local_fallback: true
        }
      else
        temp_image.unlink
        temp_video.unlink
        
        {
          success: false,
          error: "Local video generation failed",
          segment_id: segment_data[:segment_id]
        }
      end
      
    rescue => e
      puts "    ❌ Local fallback failed for segment #{segment_data[:segment_id]}: #{e.message}"
      {
        success: false,
        error: "Local fallback failed: #{e.message}",
        segment_id: segment_data[:segment_id]
      }
    end
  end
  
  # Generate a single video segment
  # @param project_id [String] Project identifier
  # @param segment_data [Hash] Segment information
  # @param options [Hash] Generation options
  # @return [Hash] Segment generation result
  def generate_segment_video(project_id, segment_data, options = {})
    segment_start_time = Time.now
    begin
      puts "  📹 Processing segment #{segment_data[:segment_id]} (#{segment_data[:segment_index] + 1}/#{options[:total_segments]}) - Duration: #{segment_data[:duration].round(2)}s"
      
      # Prepare payload for segment processing
      payload = {
        project_id: project_id,
        segment_id: segment_data[:segment_id],
        segment_index: segment_data[:segment_index],
        images: segment_data[:images],
        duration: segment_data[:duration],
        start_time: segment_data[:start_time],
        end_time: segment_data[:end_time],
        options: options.merge(segment_processing: true)
      }
      
      # Debug: Check for nil values in payload
      puts "    Debug - Payload: project_id=#{payload[:project_id]}, segment_id=#{payload[:segment_id]}, segment_index=#{payload[:segment_index]}, images=#{payload[:images].class}, duration=#{payload[:duration]}, start_time=#{payload[:start_time]}, end_time=#{payload[:end_time]}"
      
      # Check if segment already exists in S3 cache
      expected_s3_key = "segments/#{project_id}/#{segment_data[:segment_id]}_segment.mp4"
      if segment_cached?(expected_s3_key)
        segment_time = Time.now - segment_start_time
        puts "    💾 Segment #{segment_data[:segment_id]} cached (#{segment_time.round(3)}s saved)"
        return {
          success: true,
          segment_id: segment_data[:segment_id],
          segment_s3_key: expected_s3_key,
          duration: segment_data[:duration],
          start_time: segment_data[:start_time],
          end_time: segment_data[:end_time],
          cached: true,
          processing_time: segment_time
        }
      end
      
      # Invoke Lambda function for this segment with retry logic and fallback
      lambda_start = Time.now
      puts "    ⚡ Invoking Lambda for segment #{segment_data[:segment_id]} (#{payload[:images].length} images)..."
      response = invoke_lambda_function_with_retry(payload, segment_data[:segment_id])
      lambda_time = Time.now - lambda_start
      
      if response[:success]
        segment_time = Time.now - segment_start_time
        puts "    ✅ Segment #{segment_data[:segment_id]} completed in #{segment_time.round(2)}s (Lambda: #{lambda_time.round(2)}s)"
        puts "    📁 Segment file: #{response[:segment_s3_key]}"
        response[:processing_time] = segment_time
        response[:lambda_time] = lambda_time
      elsif response[:needs_fallback]
        # Lambda failed, try local fallback
        puts "    🔄 Lambda failed for segment #{segment_data[:segment_id]}, attempting local fallback..."
        fallback_response = generate_segment_locally(project_id, segment_data, options)
        
        if fallback_response[:success]
          segment_time = Time.now - segment_start_time
          puts "    ✅ Segment #{segment_data[:segment_id]} completed locally in #{segment_time.round(2)}s (Lambda failed)"
          puts "    📁 Segment file: #{fallback_response[:segment_s3_key]}"
          fallback_response[:processing_time] = segment_time
          fallback_response[:lambda_time] = lambda_time
          fallback_response[:used_fallback] = true
          response = fallback_response
        else
          segment_time = Time.now - segment_start_time
          puts "    ❌ Segment #{segment_data[:segment_id]} failed both Lambda and local in #{segment_time.round(2)}s"
          response[:processing_time] = segment_time
        end
      else
        segment_time = Time.now - segment_start_time
        puts "    ❌ Segment #{segment_data[:segment_id]} failed in #{segment_time.round(2)}s: #{response[:error]}"
        response[:processing_time] = segment_time
      end
      
      response
      
    rescue => e
      puts "    ❌ Error processing segment #{segment_data[:segment_id]}: #{e.message}"
      { 
        success: false, 
        error: e.message,
        segment_id: segment_data[:segment_id],
        segment_index: segment_data[:segment_index]
      }
    end
  end

  # Combine segment videos into final video
  # @param project_id [String] Project identifier
  # @param segment_results [Array] Results from segment processing
  # @param options [Hash] Generation options
  # @return [Hash] Final video result
  def combine_segments_into_video(project_id, segment_results, options = {})
    begin
      puts "  🎬 Combining segments into final video..."
      
      # Prepare payload for video combination
      payload = {
        project_id: project_id,
        segment_results: segment_results,
        options: options.merge(video_combination: true)
      }
      
      # Invoke Lambda function for video combination with timeout handling
      puts "  🔧 Payload for combination: #{payload.keys.join(', ')}"
      puts "  📊 Segment results count: #{segment_results.length}"
      puts "  📤 Invoking Lambda function: #{@function_name}"
      puts "    Debug - Payload keys: #{payload.keys.join(', ')}"
      puts "    Debug - Payload values: #{payload.values.map(&:class).join(', ')}"
      
      # Set a timeout for the Lambda call
      lambda_timeout = 60 # 60 seconds timeout for combination
      response = nil
      
      begin
        # Use timeout wrapper for Lambda invocation
        Timeout::timeout(lambda_timeout) do
          response = invoke_lambda_function(payload)
        end
      rescue Timeout::Error
        puts "⚠️  Lambda combination timed out after #{lambda_timeout}s, falling back to local completion..."
        return { success: false, error: "Lambda timeout", fallback_needed: true, timeout: true }
      end
      
      if response[:success]
        puts "✅ Final video combination completed!"
        puts "  📹 Video URL: #{response[:video_url]}"
        puts "  ⏱️  Duration: #{response[:duration]} seconds"
        puts "  🎬 Segments combined: #{segment_results.length}"
      else
        puts "❌ Final video combination failed: #{response[:error]}"
        puts "  🔄 Will attempt local fallback completion..."
        response[:fallback_needed] = true
      end
      
      response
      
    rescue => e
      puts "❌ Error combining segments: #{e.message}"
      puts "  🔄 Will attempt local fallback completion..."
      { success: false, error: e.message, fallback_needed: true }
    end
  end

  # Check Lambda function status
  # @return [Hash] Function status
  def check_function_status
    puts "🔍 Checking Lambda function status..."
    
    begin
      response = @lambda_client.get_function(
        function_name: @function_name
      )
      
      function_info = response.configuration
      
      status = {
        success: true,
        function_name: function_info.function_name,
        runtime: function_info.runtime,
        timeout: function_info.timeout,
        memory_size: function_info.memory_size,
        last_modified: function_info.last_modified,
        state: function_info.state
      }
      
      puts "✅ Lambda function is available:"
      puts "  📝 Name: #{status[:function_name]}"
      puts "  🐍 Runtime: #{status[:runtime]}"
      puts "  ⏱️  Timeout: #{status[:timeout]} seconds"
      puts "  💾 Memory: #{status[:memory_size]} MB"
      puts "  📅 Last Modified: #{status[:last_modified]}"
      puts "  🔄 State: #{status[:state]}"
      
      status
      
    rescue => e
      puts "❌ Error checking Lambda function: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Test Lambda function with sample data
  # @param project_id [String] Test project ID
  # @return [Hash] Test result
  def test_function(project_id = 'test-project-123')
    puts "🧪 Testing Lambda function with project: #{project_id}"
    
    begin
      # Create test payload
      test_payload = {
        project_id: project_id,
        options: {
          test_mode: true,
          resolution: '1080p',
          fps: 24
        }
      }
      
      # Invoke function
      response = invoke_lambda_function(test_payload)
      
      if response[:success]
        puts "✅ Lambda function test completed"
        puts "  📊 Response: #{response[:body]}"
      else
        puts "❌ Lambda function test failed: #{response[:error]}"
      end
      
      response
      
    rescue => e
      puts "❌ Error testing Lambda function: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get function configuration
  # @return [Hash] Function configuration
  def get_function_configuration
    puts "📋 Getting Lambda function configuration..."
    
    begin
      response = @lambda_client.get_function_configuration(
        function_name: @function_name
      )
      
      config = {
        function_name: response.function_name,
        function_arn: response.function_arn,
        runtime: response.runtime,
        role: response.role,
        handler: response.handler,
        code_size: response.code_size,
        description: response.description,
        timeout: response.timeout,
        memory_size: response.memory_size,
        last_modified: response.last_modified,
        code_sha256: response.code_sha256,
        version: response.version,
        environment: response.environment&.variables || {}
      }
      
      puts "✅ Function configuration retrieved"
      config
      
    rescue => e
      puts "❌ Error getting function configuration: #{e.message}"
      { error: e.message }
    end
  end

  # Update function configuration
  # @param updates [Hash] Configuration updates
  # @return [Hash] Update result
  def update_function_configuration(updates)
    puts "🔧 Updating Lambda function configuration..."
    
    begin
      update_params = {}
      update_params[:timeout] = updates[:timeout] if updates[:timeout]
      update_params[:memory_size] = updates[:memory_size] if updates[:memory_size]
      update_params[:environment] = { variables: updates[:environment] } if updates[:environment]
      
      response = @lambda_client.update_function_configuration(
        function_name: @function_name,
        **update_params
      )
      
      puts "✅ Function configuration updated successfully"
      {
        success: true,
        function_name: response.function_name,
        last_modified: response.last_modified
      }
      
    rescue => e
      puts "❌ Error updating function configuration: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # List recent invocations
  # @param max_items [Integer] Maximum number of invocations to return
  # @return [Hash] Invocation list
  def list_recent_invocations(max_items = 10)
    puts "📊 Listing recent Lambda invocations..."
    
    begin
      # Get CloudWatch logs for recent invocations
      log_group_name = "/aws/lambda/#{@function_name}"
      
      # This would require CloudWatch Logs client
      # For now, return a placeholder
      {
        success: true,
        message: "Recent invocations would be listed here",
        log_group: log_group_name,
        max_items: max_items
      }
      
    rescue => e
      puts "❌ Error listing invocations: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Invoke Lambda function with comprehensive retry logic and fallback
  # @param payload [Hash] Function payload
  # @param segment_id [String] Segment identifier for logging
  # @param max_retries [Integer] Maximum number of retry attempts
  # @return [Hash] Invocation result
  def invoke_lambda_function_with_retry(payload, segment_id, max_retries = 5)
    retries = 0
    last_error = nil
    
    begin
      # First attempt: Try with current payload
      result = invoke_lambda_function(payload)
      
      # If successful, return immediately
      return result if result[:success]
      
      # If failed but not retryable, return immediately
      unless retryable_error_from_result?(result)
        puts "    ❌ Non-retryable error for segment #{segment_id}: #{result[:error]}"
        return result.merge(needs_fallback: true)
      end
      
      # Store error for potential retry
      last_error = result[:error]
      raise StandardError.new(result[:error])
      
    rescue => e
      last_error = e.message
      
      if retries < max_retries && retryable_error?(e)
        retries += 1
        backoff_seconds = calculate_backoff_time(retries)
        puts "    🔄 Retry #{retries}/#{max_retries} for segment #{segment_id} in #{backoff_seconds}s (#{e.message})"
        sleep(backoff_seconds)
        
        # Modify payload for retry (simplify Ken Burns effect to reduce complexity)
        if retries >= 2
          payload = simplify_payload_for_retry(payload, retries)
          puts "    🎯 Using simplified payload for retry #{retries}"
        end
        
        retry
      else
        puts "    💥 Max retries exceeded for segment #{segment_id}: #{last_error}"
        {
          success: false,
          error: "Lambda invocation failed after #{max_retries} retries: #{last_error}",
          segment_id: segment_id,
          retries: retries,
          needs_fallback: true
        }
      end
    end
  end

  # Check if an error is retryable
  # @param error [Exception] The error to check
  # @return [Boolean] True if error is retryable
  def retryable_error?(error)
    retryable_patterns = [
      /signal: killed/i,              # Memory/timeout kills
      /net::readtimeout/i,            # Network timeouts
      /net::connecttimeout/i,         # Connection timeouts
      /timeout/i,                     # General timeouts
      /throttle/i,                    # Rate limiting
      /serviceexception/i,            # AWS service exceptions
      /internalfailure/i,             # Internal AWS failures
      /temporarilythrottled/i,        # Temporary throttling
      /requesttimeout/i,              # Request timeouts
      /connectionerror/i,             # Connection errors
      /failed to generate enhanced video/i, # FFmpeg failures
      /error when evaluating/i,       # FFmpeg filter errors
      /failed to configure input pad/i, # FFmpeg configuration errors
      /conversion failed/i,           # FFmpeg conversion errors
      /bash script failed/i           # Script execution errors
    ]
    
    error_message = error.message.to_s.downcase
    retryable_patterns.any? { |pattern| error_message.match?(pattern) }
  end
  
  # Check if a result contains a retryable error
  # @param result [Hash] The result to check
  # @return [Boolean] True if error is retryable
  def retryable_error_from_result?(result)
    return false if result[:success]
    return false unless result[:error]
    
    mock_error = StandardError.new(result[:error])
    retryable_error?(mock_error)
  end
  
  # Calculate exponential backoff time with jitter
  # @param retry_count [Integer] Current retry attempt
  # @return [Integer] Backoff time in seconds
  def calculate_backoff_time(retry_count)
    base_delay = [2 ** retry_count, 60].min  # Cap at 60 seconds
    jitter = rand(1..5)  # Add randomness to prevent thundering herd
    base_delay + jitter
  end
  
  # Simplify payload for retry attempts (reduce complexity)
  # @param payload [Hash] Original payload
  # @param retry_count [Integer] Current retry attempt
  # @return [Hash] Simplified payload
  def simplify_payload_for_retry(payload, retry_count)
    modified_payload = payload.dup
    
    # Add retry-specific options to make processing simpler
    if modified_payload[:options]
      modified_payload[:options] = modified_payload[:options].dup
      
      # Progressively simplify for each retry
      case retry_count
      when 2
        # First retry: Reduce quality slightly
        modified_payload[:options][:simple_ken_burns] = true
        modified_payload[:options][:retry_attempt] = retry_count
      when 3
        # Second retry: Use basic zoom only
        modified_payload[:options][:basic_zoom_only] = true
        modified_payload[:options][:reduce_quality] = true
        modified_payload[:options][:retry_attempt] = retry_count
      when 4, 5
        # Final retries: Minimum viable processing
        modified_payload[:options][:minimal_processing] = true
        modified_payload[:options][:static_image_fallback] = true
        modified_payload[:options][:retry_attempt] = retry_count
      end
    else
      modified_payload[:options] = {
        simple_ken_burns: true,
        retry_attempt: retry_count
      }
    end
    
    modified_payload
  end

  private

  # Generate presigned URL for S3 object
  # @param s3_key [String] S3 object key
  # @return [String] Presigned URL
  def generate_presigned_url(s3_key)
    begin
      require_relative 's3_service'
      s3_service = S3Service.new
      bucket_name = Config::AWS_CONFIG[:s3_bucket]
      
      # Use S3 client to generate presigned URL
      s3_client = Aws::S3::Client.new(
        region: @region,
        credentials: Aws::Credentials.new(
          Config::AWS_CONFIG[:access_key_id],
          Config::AWS_CONFIG[:secret_access_key]
        )
      )
      
      presigner = Aws::S3::Presigner.new(client: s3_client)
      presigner.presigned_url(:get_object, bucket: bucket_name, key: s3_key, expires_in: 3600)
    rescue => e
      puts "    ⚠️ Failed to generate presigned URL: #{e.message}"
      "s3://#{Config::AWS_CONFIG[:s3_bucket]}/#{s3_key}"
    end
  end

  # Calculate optimal concurrency based on segment count
  # @param segment_count [Integer] Number of segments to process
  # @return [Integer] Optimal concurrency level
  def calculate_optimal_concurrency(segment_count)
    # AWS Lambda can handle thousands of concurrent executions
    # Optimize for speed while maintaining reliability
    
    # Handle edge case of 0 segments
    return 1 if segment_count <= 0
    
    if segment_count <= 15
      # Small projects: process all segments concurrently for speed
      segment_count
    elsif segment_count <= 60
      # Medium projects: aggressive concurrency for speed
      [segment_count, 25].min  # Increased from 15 to 25
    else
      # Large projects: balanced approach
      [segment_count, 20].min  # Increased from 10 to 20
    end
  end

  # Check if segment video already exists in S3
  # @param s3_key [String] S3 object key
  # @return [Boolean] True if segment exists
  def segment_cached?(s3_key)
    begin
      @s3_client.head_object(bucket: @bucket_name, key: s3_key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    rescue => e
      puts "    ⚠️  Error checking S3 cache for #{s3_key}: #{e.message}"
      false
    end
  end

  # Invoke Lambda function
  # @param payload [Hash] Function payload
  # @return [Hash] Invocation result
  def invoke_lambda_function(payload)
    begin
      puts "  📤 Invoking Lambda function: #{@function_name}"
      
      # Debug: Check payload before JSON serialization
      puts "    Debug - Payload keys: #{payload.keys.join(', ')}"
      puts "    Debug - Payload values: #{payload.values.map(&:class).join(', ')}"
      
      response = @lambda_client.invoke(
        function_name: @function_name,
        payload: payload.to_json,
        invocation_type: 'RequestResponse',
        log_type: 'Tail'
      )
      
      # Parse response
      puts "    Debug - Response status: #{response.status_code}"
      response_body = JSON.parse(response.payload.read)
      puts "    Debug - Response body keys: #{response_body.keys.join(', ')}"
      
      if response.status_code == 200
        # Check if there's an error in the response
        if response_body['errorMessage']
          puts "    Debug - Lambda error: #{response_body['errorMessage']}"
          puts "    Debug - Error type: #{response_body['errorType']}"
          puts "    Debug - Stack trace: #{response_body['stackTrace']}"
          return {
            success: false,
            error: "Lambda function error: #{response_body['errorMessage']}",
            error_type: response_body['errorType']
          }
        end
        
        # Success response - handle both string and object body formats
        body = if response_body['body'].is_a?(String)
          JSON.parse(response_body['body'])
        else
          response_body['body']
        end
        
        # Generate presigned URL for video access
        s3_key = body['video_s3_key'] || body['segment_s3_key']
        video_url = if s3_key
          generate_presigned_url(s3_key)
        else
          nil
        end
        
        {
          success: true,
          status_code: response.status_code,
          video_url: video_url,
          video_s3_key: body['video_s3_key'],
          segment_s3_key: body['segment_s3_key'],
          duration: body['duration'],
          resolution: body['resolution'] || '1920x1080',
          fps: body['fps'] || 24,
          generated_at: Time.now.iso8601,
          project_id: body['project_id']
        }
      else
        # Error response
        {
          success: false,
          status_code: response.status_code,
          error: response_body['error'] || 'Unknown error',
          timestamp: response_body['timestamp']
        }
      end
      
    rescue JSON::ParserError => e
      puts "    ❌ JSON parsing error: #{e.message}"
      puts "    ❌ Raw response: #{response.payload.read}"
      {
        success: false,
        error: "Invalid JSON response from Lambda: #{e.message}"
      }
    rescue => e
      puts "    ❌ Lambda invocation error: #{e.message}"
      puts "    ❌ Error class: #{e.class}"
      {
        success: false,
        error: "Lambda invocation failed: #{e.message}"
      }
    end
  end
end 