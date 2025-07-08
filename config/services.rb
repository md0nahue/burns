module Config
  # Groq API Configuration
  GROQ_CONFIG = {
    api_key: ENV['GROQ_API_KEY'],
    base_url: 'https://api.groq.com/openai/v1',
    default_model: 'whisper-large-v3',
    default_language: 'en'
  }

  # AWS Configuration
  AWS_CONFIG = {
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    region: ENV['AWS_REGION'] || 'us-east-1',
    lambda_function: ENV['LAMBDA_FUNCTION'] || 'ken-burns-video-generator-go',
    s3_bucket: ENV['S3_BUCKET'] || 'burns-videos',
    s3_lifecycle_days: ENV['S3_LIFECYCLE_DAYS'] || 14
  }

  # Image Service Configuration
  IMAGE_SERVICE_CONFIG = {
    unsplash: { api_key: ENV['UNSPLASH_API_KEY'] },
    pexels: { api_key: ENV['PEXELS_API_KEY'] },
    pixabay: { api_key: ENV['PIXABAY_API_KEY'] },
    lorem_picsum: {}, # No API key needed
    openverse: {} # No API key needed
  }

  # LLM Configuration for content analysis (using Gemini)
  LLM_CONFIG = {
    provider: 'gemini', # Using Gemini for LLM tasks
    api_key: ENV['GEMINI_API_KEY'],
    model: 'gemini-2.5-flash-lite-preview-06-17',
    max_tokens: 2048,
    temperature: 0.1
  }

  # Gemini Configuration
  GEMINI_CONFIG = {
    api_key: ENV['GEMINI_API_KEY'],
    model: 'gemini-2.5-flash-lite-preview-06-17',
    max_tokens: 2048,
    temperature: 0.1
  }

  # Pipeline Configuration
  PIPELINE_CONFIG = {
    temp_dir: ENV['TEMP_DIR'] || 'temp',
    upload_dir: ENV['UPLOAD_DIR'] || 'uploads',
    output_dir: ENV['OUTPUT_DIR'] || 'output',
    max_audio_size: 25 * 1024 * 1024, # 25MB
    supported_audio_formats: %w[flac mp3 mp4 mpeg mpga m4a ogg wav webm]
  }

  # Validation methods
  def self.validate_groq_config!
    raise "GROQ_API_KEY environment variable not set" unless GROQ_CONFIG[:api_key]
  end

  def self.validate_gemini_config!
    raise "GEMINI_API_KEY environment variable not set" unless GEMINI_CONFIG[:api_key]
  end

  def self.validate_aws_config!
    required_keys = [:access_key_id, :secret_access_key, :region]
    missing_keys = required_keys.select { |key| AWS_CONFIG[key].nil? }
    
    if missing_keys.any?
      raise "Missing AWS environment variables: #{missing_keys.join(', ')}"
    end
  end

  def self.validate_image_config!
    # At least one image service should be configured
    configured_services = IMAGE_SERVICE_CONFIG.select do |service, config|
      service == :lorem_picsum || service == :openverse || config[:api_key]
    end
    
    if configured_services.empty?
      puts "⚠️  Warning: No image services configured. Only Lorem Picsum and Openverse will work."
    end
  end

  # Get configuration for a specific service
  def self.get_service_config(service_name)
    case service_name
    when 'groq'
      GROQ_CONFIG
    when 'gemini'
      GEMINI_CONFIG
    when 'aws'
      AWS_CONFIG
    when 'llm'
      LLM_CONFIG
    when 'pipeline'
      PIPELINE_CONFIG
    else
      raise "Unknown service: #{service_name}"
    end
  end
end 