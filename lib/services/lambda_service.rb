require 'aws-sdk-lambda'
require 'json'
require 'concurrent'
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
    puts "🚀 Generating video segments concurrently for project: #{project_id}"
    puts "  📝 Segments: #{segments.length}"
    puts "  ⚡ Concurrency: #{options[:max_concurrency] || 5}"
    
    begin
      # Create concurrent executor
      max_concurrency = options[:max_concurrency] || 5
      executor = Concurrent::FixedThreadPool.new(max_concurrency)
      
      # Prepare segment tasks
      segment_tasks = segments.map.with_index do |segment, index|
        {
          segment_id: segment[:id],
          segment_index: index,
          images: segment[:generated_images],
          duration: segment[:end_time] - segment[:start_time],
          start_time: segment[:start_time],
          end_time: segment[:end_time]
        }
      end
      
      # Submit tasks to executor
      futures = segment_tasks.map do |task|
        Concurrent::Future.execute(executor: executor) do
          generate_segment_video(project_id, task, options)
        end
      end
      
      # Wait for all segments to complete
      puts "  ⏳ Waiting for #{futures.length} segments to complete..."
      results = futures.map(&:value)
      
      # Check for failures
      failed_segments = results.select { |r| !r[:success] }
      if failed_segments.any?
        puts "❌ #{failed_segments.length} segments failed to process"
        failed_segments.each do |failure|
          puts "  ❌ Segment #{failure[:segment_id]}: #{failure[:error]}"
        end
        return { success: false, error: "Some segments failed to process" }
      end
      
      # Combine segments into final video
      puts "  🎬 Combining #{results.length} segments into final video..."
      final_result = combine_segments_into_video(project_id, results, options)
      
      executor.shutdown
      executor.wait_for_termination
      
      final_result
      
    rescue => e
      puts "❌ Error in concurrent video generation: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Generate a single video segment
  # @param project_id [String] Project identifier
  # @param segment_data [Hash] Segment information
  # @param options [Hash] Generation options
  # @return [Hash] Segment generation result
  def generate_segment_video(project_id, segment_data, options = {})
    begin
      puts "  📹 Processing segment #{segment_data[:segment_id]} (#{segment_data[:segment_index] + 1}/#{options[:total_segments]})"
      
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
      
      # Invoke Lambda function for this segment
      response = invoke_lambda_function(payload)
      
      if response[:success]
        puts "    ✅ Segment #{segment_data[:segment_id]} completed"
        puts "    📁 Segment file: #{response[:segment_s3_key]}"
      else
        puts "    ❌ Segment #{segment_data[:segment_id]} failed: #{response[:error]}"
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
      
      # Invoke Lambda function for video combination
      response = invoke_lambda_function(payload)
      
      if response[:success]
        puts "✅ Final video combination completed!"
        puts "  📹 Video URL: #{response[:video_url]}"
        puts "  ⏱️  Duration: #{response[:duration]} seconds"
        puts "  🎬 Segments combined: #{segment_results.length}"
      else
        puts "❌ Final video combination failed: #{response[:error]}"
      end
      
      response
      
    rescue => e
      puts "❌ Error combining segments: #{e.message}"
      { success: false, error: e.message }
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

  private

  # Invoke Lambda function
  # @param payload [Hash] Function payload
  # @return [Hash] Invocation result
  def invoke_lambda_function(payload)
    begin
      puts "  📤 Invoking Lambda function: #{@function_name}"
      
      response = @lambda_client.invoke(
        function_name: @function_name,
        payload: payload.to_json,
        invocation_type: 'RequestResponse',
        log_type: 'Tail'
      )
      
      # Parse response
      response_body = JSON.parse(response.payload.read)
      
      if response.status_code == 200
        # Success response
        body = JSON.parse(response_body['body'])
        
        {
          success: true,
          status_code: response.status_code,
          video_url: body['video_url'],
          video_s3_key: body['video_s3_key'],
          segment_s3_key: body['segment_s3_key'],
          duration: body['duration'],
          resolution: body['resolution'],
          fps: body['fps'],
          generated_at: body['generated_at'],
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
      
    rescue => e
      {
        success: false,
        error: "Lambda invocation failed: #{e.message}"
      }
    end
  end
end 