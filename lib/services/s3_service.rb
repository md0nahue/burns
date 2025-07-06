require 'aws-sdk-s3'
require 'json'
require_relative '../../config/services'

class S3Service
  def initialize(region = nil)
    @region = region || Config::AWS_CONFIG[:region]
    @s3_client = Aws::S3::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(
        Config::AWS_CONFIG[:access_key_id],
        Config::AWS_CONFIG[:secret_access_key]
      )
    )
    @s3_resource = Aws::S3::Resource.new(client: @s3_client)
  end

  # Create S3 bucket with proper configuration
  # @param bucket_name [String] Name of the bucket to create
  # @param options [Hash] Bucket configuration options
  # @return [Hash] Creation result
  def create_bucket(bucket_name, options = {})
    puts "🪣 Creating S3 bucket: #{bucket_name}"
    
    begin
      # Create bucket
      bucket = @s3_resource.create_bucket(
        bucket: bucket_name,
        create_bucket_configuration: {
          location_constraint: 'us-east-1'
        }
      )

      # Configure bucket settings
      configure_bucket_settings(bucket_name, options)
      
      puts "✅ Bucket created successfully: #{bucket_name}"
      { success: true, bucket_name: bucket_name }
      
    rescue Aws::S3::Errors::BucketAlreadyExists
      puts "⚠️  Bucket already exists: #{bucket_name}"
      { success: true, bucket_name: bucket_name, already_exists: true }
    rescue => e
      puts "❌ Error creating bucket: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Upload image to S3
  # @param image_data [Hash] Image data with URL and metadata
  # @param bucket_name [String] S3 bucket name
  # @param prefix [String] S3 key prefix
  # @return [Hash] Upload result
  def upload_image(image_data, bucket_name, prefix = 'images')
    puts "📤 Uploading image: #{image_data[:url]}"
    
    begin
      # Download image from URL
      image_content = download_image_from_url(image_data[:url])
      
      # Generate S3 key
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = "#{image_data[:query].gsub(/\s+/, '_')}_#{timestamp}.jpg"
      s3_key = "#{prefix}/#{filename}"
      
      # Upload to S3
      bucket = @s3_resource.bucket(bucket_name)
      obj = bucket.object(s3_key)
      
      obj.put(
        body: image_content,
        content_type: 'image/jpeg',
        metadata: {
          'original-url' => image_data[:url],
          'query' => image_data[:query],
          'provider' => image_data[:provider],
          'width' => image_data[:width].to_s,
          'height' => image_data[:height].to_s,
          'segment-id' => image_data[:segment_id].to_s,
          'start-time' => image_data[:start_time].to_s,
          'end-time' => image_data[:end_time].to_s
        }
      )
      
      # Generate presigned URL for access
      presigned_url = obj.presigned_url(:get, expires_in: 3600)
      
      puts "✅ Image uploaded: s3://#{bucket_name}/#{s3_key}"
      
      {
        success: true,
        s3_key: s3_key,
        s3_url: "s3://#{bucket_name}/#{s3_key}",
        presigned_url: presigned_url,
        original_data: image_data
      }
      
    rescue => e
      puts "❌ Error uploading image: #{e.message}"
      { success: false, error: e.message, original_data: image_data }
    end
  end

  # Upload multiple images for a project
  # @param project_id [String] Unique project identifier
  # @param images [Array] Array of image data
  # @param bucket_name [String] S3 bucket name
  # @return [Hash] Upload results
  def upload_project_images(project_id, images, bucket_name)
    puts "📤 Uploading #{images.length} images for project: #{project_id}"
    
    results = []
    successful_uploads = 0
    
    images.each_with_index do |image, index|
      puts "  Uploading image #{index + 1}/#{images.length}"
      
      prefix = "projects/#{project_id}/images"
      result = upload_image(image, bucket_name, prefix)
      
      results << result
      successful_uploads += 1 if result[:success]
      
      # Add delay to avoid overwhelming the system
      sleep(0.5) if index < images.length - 1
    end
    
    puts "✅ Upload completed: #{successful_uploads}/#{images.length} successful"
    
    {
      total_images: images.length,
      successful_uploads: successful_uploads,
      failed_uploads: images.length - successful_uploads,
      results: results
    }
  end

  # Create project manifest file
  # @param project_id [String] Project identifier
  # @param project_data [Hash] Project data including segments and images
  # @param bucket_name [String] S3 bucket name
  # @return [Hash] Manifest creation result
  def create_project_manifest(project_id, project_data, bucket_name)
    puts "📋 Creating project manifest: #{project_id}"
    
    begin
      manifest = {
        project_id: project_id,
        created_at: Time.now.iso8601,
        audio_file: project_data[:audio_file],
        duration: project_data[:duration],
        word_count: project_data[:word_count],
        segments: project_data[:segments].map do |segment|
          {
            id: segment[:id],
            start_time: segment[:start_time],
            end_time: segment[:end_time],
            text: segment[:text],
            image_queries: segment[:image_queries],
            generated_images: segment[:generated_images].map do |img|
              {
                s3_key: img[:s3_key],
                s3_url: img[:s3_url],
                presigned_url: img[:presigned_url],
                query: img[:query],
                provider: img[:provider],
                width: img[:width],
                height: img[:height]
              }
            end
          }
        end,
        analysis_metrics: project_data[:analysis_metrics],
        generation_metrics: project_data[:generation_metrics]
      }
      
      # Upload manifest to S3
      bucket = @s3_resource.bucket(bucket_name)
      manifest_key = "projects/#{project_id}/manifest.json"
      obj = bucket.object(manifest_key)
      
      obj.put(
        body: JSON.pretty_generate(manifest),
        content_type: 'application/json'
      )
      
      puts "✅ Manifest created: s3://#{bucket_name}/#{manifest_key}"
      
      {
        success: true,
        manifest_key: manifest_key,
        manifest_url: "s3://#{bucket_name}/#{manifest_key}",
        project_id: project_id
      }
      
    rescue => e
      puts "❌ Error creating manifest: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # List project files
  # @param project_id [String] Project identifier
  # @param bucket_name [String] S3 bucket name
  # @return [Hash] Project files listing
  def list_project_files(project_id, bucket_name)
    puts "📁 Listing files for project: #{project_id}"
    
    begin
      bucket = @s3_resource.bucket(bucket_name)
      prefix = "projects/#{project_id}/"
      
      files = []
      bucket.objects(prefix: prefix).each do |obj|
        files << {
          key: obj.key,
          size: obj.size,
          last_modified: obj.last_modified,
          url: "s3://#{bucket_name}/#{obj.key}"
        }
      end
      
      {
        success: true,
        project_id: project_id,
        files: files,
        total_files: files.length
      }
      
    rescue => e
      puts "❌ Error listing project files: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Clean up old project files
  # @param bucket_name [String] S3 bucket name
  # @param days_old [Integer] Age threshold in days
  # @return [Hash] Cleanup result
  def cleanup_old_projects(bucket_name, days_old = 14)
    puts "🧹 Cleaning up projects older than #{days_old} days"
    
    begin
      bucket = @s3_resource.bucket(bucket_name)
      cutoff_time = Time.now - (days_old * 24 * 60 * 60)
      
      deleted_count = 0
      projects_to_delete = []
      
      # Find old projects
      bucket.objects(prefix: 'projects/').each do |obj|
        if obj.last_modified < cutoff_time
          project_id = obj.key.split('/')[1]
          projects_to_delete << project_id unless projects_to_delete.include?(project_id)
        end
      end
      
      # Delete old projects
      projects_to_delete.each do |project_id|
        puts "  Deleting project: #{project_id}"
        bucket.objects(prefix: "projects/#{project_id}/").each do |obj|
          obj.delete
          deleted_count += 1
        end
      end
      
      puts "✅ Cleanup completed: #{deleted_count} files deleted from #{projects_to_delete.length} projects"
      
      {
        success: true,
        deleted_files: deleted_count,
        deleted_projects: projects_to_delete.length
      }
      
    rescue => e
      puts "❌ Error during cleanup: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Upload audio file to S3
  # @param audio_file_path [String] Path to audio file
  # @param project_id [String] Project identifier
  # @param bucket_name [String] S3 bucket name (optional)
  # @return [Hash] Upload result
  def upload_audio_file(audio_file_path, project_id, bucket_name = nil)
    bucket_name ||= Config::AWS_CONFIG[:s3_bucket]
    puts "📤 Uploading audio file: #{File.basename(audio_file_path)}"
    
    begin
      # Read audio file
      audio_content = File.read(audio_file_path)
      
      # Generate S3 key
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = File.basename(audio_file_path)
      s3_key = "projects/#{project_id}/audio/#{filename}"
      
      # Upload to S3 with minimal metadata
      bucket = @s3_resource.bucket(bucket_name)
      obj = bucket.object(s3_key)
      
      obj.put(
        body: audio_content,
        content_type: 'audio/mpeg'
      )
      
      # Generate presigned URL for access
      presigned_url = obj.presigned_url(:get, expires_in: 3600)
      
      puts "✅ Audio file uploaded: s3://#{bucket_name}/#{s3_key}"
      
      {
        success: true,
        s3_key: s3_key,
        s3_url: "s3://#{bucket_name}/#{s3_key}",
        presigned_url: presigned_url,
        filename: filename,
        file_size: File.size(audio_file_path)
      }
      
    rescue => e
      puts "❌ Error uploading audio file: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Upload project manifest to S3
  # @param project_id [String] Project identifier
  # @param manifest [Hash] Project manifest data
  # @param bucket_name [String] S3 bucket name (optional)
  # @return [Hash] Upload result
  def upload_project_manifest(project_id, manifest, bucket_name = nil)
    bucket_name ||= Config::AWS_CONFIG[:s3_bucket]
    puts "📤 Uploading project manifest: #{project_id}"
    
    begin
      # Generate S3 key
      manifest_key = "projects/#{project_id}/manifest.json"
      
      # Upload to S3
      bucket = @s3_resource.bucket(bucket_name)
      obj = bucket.object(manifest_key)
      
      obj.put(
        body: JSON.pretty_generate(manifest),
        content_type: 'application/json',
        metadata: {
          'project-id' => project_id,
          'upload-timestamp' => Time.now.iso8601,
          'manifest-version' => '1.0'
        }
      )
      
      # Generate presigned URL for access
      presigned_url = obj.presigned_url(:get, expires_in: 3600)
      
      puts "✅ Project manifest uploaded: s3://#{bucket_name}/#{manifest_key}"
      
      {
        success: true,
        manifest_key: manifest_key,
        manifest_url: "s3://#{bucket_name}/#{manifest_key}",
        presigned_url: presigned_url,
        project_id: project_id
      }
      
    rescue => e
      puts "❌ Error uploading project manifest: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get project manifest from S3
  # @param project_id [String] Project identifier
  # @param bucket_name [String] S3 bucket name (optional)
  # @return [Hash] Manifest data
  def get_project_manifest(project_id, bucket_name = nil)
    bucket_name ||= Config::AWS_CONFIG[:s3_bucket]
    puts "📥 Getting project manifest: #{project_id}"
    
    begin
      # Generate S3 key
      manifest_key = "projects/#{project_id}/manifest.json"
      
      # Get from S3
      bucket = @s3_resource.bucket(bucket_name)
      obj = bucket.object(manifest_key)
      
      # Check if object exists
      unless obj.exists?
        return { success: false, error: "Project manifest not found" }
      end
      
      # Get manifest content
      manifest_content = obj.get.body.read
      manifest = JSON.parse(manifest_content)
      
      puts "✅ Project manifest retrieved: s3://#{bucket_name}/#{manifest_key}"
      
      {
        success: true,
        manifest: manifest,
        manifest_key: manifest_key,
        project_id: project_id
      }
      
    rescue => e
      puts "❌ Error getting project manifest: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  # Configure bucket settings after creation
  # @param bucket_name [String] Bucket name
  # @param options [Hash] Configuration options
  def configure_bucket_settings(bucket_name, options)
    bucket = @s3_resource.bucket(bucket_name)
    
    # Set lifecycle policy for automatic cleanup
    lifecycle_days = options[:lifecycle_days] || Config::AWS_CONFIG[:s3_lifecycle_days]
    
    lifecycle_config = {
      rules: [
        {
          id: 'auto-cleanup',
          status: 'Enabled',
          filter: {
            prefix: 'projects/'
          },
          expiration: {
            days: lifecycle_days
          }
        }
      ]
    }
    
    bucket.put_lifecycle_configuration(lifecycle_config)
    puts "  ✅ Lifecycle policy set: #{lifecycle_days} days"
    
    # Set bucket versioning (optional)
    if options[:versioning]
      bucket.versioning.put(versioning_configuration: { status: 'Enabled' })
      puts "  ✅ Versioning enabled"
    end
    
    # Set CORS policy for web access (optional)
    if options[:cors]
      cors_config = {
        cors_rules: [
          {
            allowed_headers: ['*'],
            allowed_methods: ['GET', 'PUT', 'POST', 'DELETE'],
            allowed_origins: ['*'],
            expose_headers: ['ETag'],
            max_age_seconds: 3000
          }
        ]
      }
      
      bucket.put_cors(cors_configuration: cors_config)
      puts "  ✅ CORS policy configured"
    end
  end

  # Download image from URL
  # @param url [String] Image URL
  # @return [String] Image content
  def download_image_from_url(url)
    require 'net/http'
    require 'uri'
    
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      response.body
    else
      raise "Failed to download image: HTTP #{response.code}"
    end
  end

  # Download video from S3 to local path
  # @param s3_key [String] S3 key of the video
  # @param local_path [String] Local path to save the video
  # @return [Hash] Download result
  def download_video(s3_key, local_path)
    puts "📥 Downloading video from S3: #{s3_key}"
    
    begin
      bucket_name = Config::AWS_CONFIG[:s3_bucket]
      bucket = @s3_resource.bucket(bucket_name)
      obj = bucket.object(s3_key)
      
      # Create directory if it doesn't exist
      require 'fileutils'
      FileUtils.mkdir_p(File.dirname(local_path))
      
      # Download the video
      obj.download_file(local_path)
      
      puts "✅ Video downloaded successfully: #{local_path}"
      {
        success: true,
        local_path: local_path,
        file_size: File.size(local_path),
        s3_key: s3_key
      }
      
    rescue => e
      puts "❌ Error downloading video: #{e.message}"
      { success: false, error: e.message }
    end
  end
end 