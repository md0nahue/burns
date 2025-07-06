require 'net/http'
require 'json'
require 'mime/types'
require 'tempfile'
require_relative '../../config/services'

class WhisperService
  GROQ_API_BASE = Config::GROQ_CONFIG[:base_url]
  
  # Available models and their characteristics
  MODELS = {
    'whisper-large-v3-turbo' => {
      cost_per_hour: 0.04,
      language_support: 'multilingual',
      translation_support: false,
      speed_factor: 216,
      word_error_rate: '12%'
    },
    'distil-whisper-large-v3-en' => {
      cost_per_hour: 0.02,
      language_support: 'english_only',
      translation_support: false,
      speed_factor: 250,
      word_error_rate: '13%'
    },
    'whisper-large-v3' => {
      cost_per_hour: 0.111,
      language_support: 'multilingual',
      translation_support: true,
      speed_factor: 189,
      word_error_rate: '10.3%'
    }
  }

  def initialize(api_key = nil)
    @api_key = api_key || Config::GROQ_CONFIG[:api_key]
    Config.validate_groq_config! unless @api_key
  end

  # Transcribe audio file to text
  # @param file_path [String] Path to audio file
  # @param options [Hash] Transcription options
  # @return [Hash] Transcription result with metadata
  def transcribe(file_path, options = {})
    validate_file!(file_path)
    
    # Check for cached response
    cache_file = get_cache_file_path(file_path)
    if File.exist?(cache_file)
      puts "    📁 Using cached transcription from: #{cache_file}"
      cached_data = JSON.parse(File.read(cache_file))
      return parse_response(cached_data, options[:response_format] || 'verbose_json')
    end
    
    model = options[:model] || 'whisper-large-v3-turbo'
    language = options[:language]
    prompt = options[:prompt]
    response_format = options[:response_format] || 'verbose_json'
    timestamp_granularities = options[:timestamp_granularities] || ['segment']
    temperature = options[:temperature] || 0

    uri = URI("#{GROQ_API_BASE}/audio/transcriptions")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"

    # Build multipart form data
    boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    
    body = build_multipart_body(
      file_path, model, language, prompt, response_format, 
      timestamp_granularities, temperature, boundary
    )
    
    request.body = body

    response = make_request(request, uri)
    response_data = parse_response(response, response_format)
    
    # Cache the response
    puts "    💾 Caching transcription to: #{cache_file}"
    File.write(cache_file, JSON.pretty_generate(response_data))
    
    response_data
  end

  # Translate audio file to English text
  # @param file_path [String] Path to audio file
  # @param options [Hash] Translation options
  # @return [Hash] Translation result
  def translate(file_path, options = {})
    validate_file!(file_path)
    
    model = options[:model] || 'whisper-large-v3'
    prompt = options[:prompt]
    response_format = options[:response_format] || 'json'
    temperature = options[:temperature] || 0

    uri = URI("#{GROQ_API_BASE}/audio/translations")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"

    # Build multipart form data
    boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    
    body = build_multipart_body(
      file_path, model, nil, prompt, response_format, 
      [], temperature, boundary, translation: true
    )
    
    request.body = body

    response = make_request(request, uri)
    parse_response(response, response_format)
  end

  # Get available models and their characteristics
  # @return [Hash] Model information
  def available_models
    MODELS
  end

  # Validate audio file before processing
  # @param file_path [String] Path to audio file
  def validate_file!(file_path)
    unless File.exist?(file_path)
      raise ArgumentError, "Audio file not found: #{file_path}"
    end

    file_size = File.size(file_path)
    max_size = 25 * 1024 * 1024 # 25MB for free tier
    
    if file_size > max_size
      raise ArgumentError, "File size (#{file_size} bytes) exceeds maximum allowed size (#{max_size} bytes)"
    end

    # Check file type
    mime_type = MIME::Types.type_for(file_path).first
    supported_types = %w[audio/flac audio/mp3 audio/mp4 audio/mpeg audio/mpga audio/m4a audio/ogg audio/wav audio/webm]
    
    unless supported_types.include?(mime_type.to_s)
      raise ArgumentError, "Unsupported file type: #{mime_type}. Supported types: #{supported_types.join(', ')}"
    end
  end

  private

  # Generate cache file path for transcription
  # @param file_path [String] Path to audio file
  # @return [String] Cache file path
  def get_cache_file_path(file_path)
    base_name = File.basename(file_path, File.extname(file_path))
    cache_dir = 'cache'
    Dir.mkdir(cache_dir) unless Dir.exist?(cache_dir)
    "#{cache_dir}/#{base_name}.json"
  end

  def build_multipart_body(file_path, model, language, prompt, response_format, 
                          timestamp_granularities, temperature, boundary, translation: false)
    body = []
    
    # Add file
    file_content = File.read(file_path)
    body << "--#{boundary}"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file_path)}\""
    body << "Content-Type: #{MIME::Types.type_for(file_path).first}"
    body << ""
    body << file_content
    
    # Add model
    body << "--#{boundary}"
    body << "Content-Disposition: form-data; name=\"model\""
    body << ""
    body << model
    
    # Add response format
    body << "--#{boundary}"
    body << "Content-Disposition: form-data; name=\"response_format\""
    body << ""
    body << response_format
    
    # Add temperature
    body << "--#{boundary}"
    body << "Content-Disposition: form-data; name=\"temperature\""
    body << ""
    body << temperature.to_s
    
    # Add language if specified
    if language && !translation
      body << "--#{boundary}"
      body << "Content-Disposition: form-data; name=\"language\""
      body << ""
      body << language
    end
    
    # Add prompt if specified
    if prompt
      body << "--#{boundary}"
      body << "Content-Disposition: form-data; name=\"prompt\""
      body << ""
      body << prompt
    end
    
    # Add timestamp granularities for verbose_json
    # Note: Groq API doesn't support timestamp_granularities, so we skip it
    # if response_format == 'verbose_json' && !timestamp_granularities.empty?
    #   body << "--#{boundary}"
    #   body << "Content-Disposition: form-data; name=\"timestamp_granularities\""
    #   body << ""
    #   body << JSON.generate(timestamp_granularities)
    # end
    
    body << "--#{boundary}--"
    body.join("\r\n")
  end

  def make_request(request, uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 300 # 5 minutes for large files
    
    response = http.request(request)
    
    case response.code.to_i
    when 200
      response
    when 401
      raise "Authentication failed. Check your GROQ_API_KEY"
    when 400
      error_data = JSON.parse(response.body) rescue {}
      raise "Bad request: #{error_data['error'] || response.body}"
    when 413
      raise "File too large. Maximum size is 25MB for free tier"
    when 429
      raise "Rate limit exceeded. Please wait before retrying"
    else
      raise "API request failed with status #{response.code}: #{response.body}"
    end
  end

  def parse_response(response, response_format)
    # Handle both HTTP response objects and cached Hash data
    data = if response.is_a?(Net::HTTPResponse)
      JSON.parse(response.body)
    else
      response # Already a Hash from cache
    end
    
    case response_format
    when 'json', 'verbose_json'
      # Return standardized format expected by pipeline
      {
        success: true,
        text: data['text'],
        segments: data['segments'] || [],
        duration: data['duration'],
        language: data['language'],
        task: data['task']
      }
    when 'text'
      { 
        success: true,
        text: data['text'] || data,
        segments: [],
        duration: nil,
        language: nil,
        task: 'transcribe'
      }
    else
      raise "Unsupported response format: #{response_format}"
    end
  end
end 