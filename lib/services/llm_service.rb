require 'net/http'
require 'json'
require 'securerandom'
require_relative '../../config/services'

class LLMService
  GROQ_API_BASE = 'https://api.groq.com/openai/v1'
  
  def initialize(api_key = nil)
    @api_key = api_key || Config::LLM_CONFIG[:api_key]
    Config.validate_groq_config! unless @api_key
    @model = Config::LLM_CONFIG[:model]
    @max_tokens = Config::LLM_CONFIG[:max_tokens]
    @temperature = Config::LLM_CONFIG[:temperature]
  end

  # Analyze transcribed segments and generate image queries
  # @param segments [Array] Transcribed audio segments
  # @param options [Hash] Analysis options
  # @return [Array] Segments with image queries and timing
  def analyze_content_for_images(segments, options = {})
    puts "🧠 Analyzing content for image generation..."
    
    # Group segments into logical chunks for analysis
    chunks = group_segments_into_chunks(segments, options[:chunk_duration] || 30)
    
    analyzed_chunks = []
    
    chunks.each_with_index do |chunk, index|
      puts "  Analyzing chunk #{index + 1}/#{chunks.length} (#{chunk[:duration].round(1)}s)"
      
      # Analyze this chunk
      analysis = analyze_chunk(chunk, options)
      
      # Distribute image queries across segments in this chunk
      enriched_segments = distribute_image_queries(chunk[:segments], analysis[:image_queries])
      
      analyzed_chunks.concat(enriched_segments)
    end
    
    puts "✅ Content analysis completed: #{analyzed_chunks.length} segments processed"
    analyzed_chunks
  end

  # Analyze a single chunk of audio content
  # @param chunk [Hash] Audio chunk with segments
  # @param options [Hash] Analysis options
  # @return [Hash] Analysis result with image queries
  def analyze_chunk(chunk, options = {})
    prompt = build_analysis_prompt(chunk, options)
    
    response = make_llm_request(prompt)
    
    # Parse the response
    parsed_response = parse_analysis_response(response)
    
    # Validate and enhance the response
    enhanced_response = enhance_analysis(parsed_response, chunk, options)
    
    enhanced_response
  end

  # Generate image queries for a specific text segment
  # @param text [String] Text to analyze
  # @param context [Hash] Additional context
  # @return [Array] Image queries
  def generate_image_queries_for_text(text, context = {})
    prompt = build_single_text_prompt(text, context)
    
    response = make_llm_request(prompt)
    
    parsed = parse_analysis_response(response)
    parsed[:image_queries] || []
  end

  private

  # Group segments into logical chunks for analysis
  # @param segments [Array] Audio segments
  # @param chunk_duration [Integer] Target chunk duration in seconds
  # @return [Array] Chunks of segments
  def group_segments_into_chunks(segments, chunk_duration)
    chunks = []
    current_chunk = { segments: [], start_time: 0, end_time: 0, text: "" }
    
    segments.each do |segment|
      # If adding this segment would exceed chunk duration, start a new chunk
      if current_chunk[:segments].any? && 
         (segment[:end_time] - current_chunk[:start_time]) > chunk_duration
        
        # Finalize current chunk
        current_chunk[:duration] = current_chunk[:end_time] - current_chunk[:start_time]
        chunks << current_chunk
        
        # Start new chunk
        current_chunk = { 
          segments: [segment], 
          start_time: segment[:start_time], 
          end_time: segment[:end_time], 
          text: segment[:text] 
        }
      else
        # Add to current chunk
        current_chunk[:segments] << segment
        current_chunk[:end_time] = segment[:end_time]
        current_chunk[:text] += " " + segment[:text]
      end
    end
    
    # Add final chunk
    if current_chunk[:segments].any?
      current_chunk[:duration] = current_chunk[:end_time] - current_chunk[:start_time]
      chunks << current_chunk
    end
    
    chunks
  end

  # Build prompt for content analysis
  # @param chunk [Hash] Audio chunk
  # @param options [Hash] Analysis options
  # @return [String] Formatted prompt
  def build_analysis_prompt(chunk, options)
    context = options[:context] || "product review"
    style = options[:style] || "realistic, high-quality"
    
    prompt = <<~PROMPT
      You are an expert at analyzing spoken content and determining what images would best illustrate the narrative.

      CONTEXT: This is a #{context} that has been transcribed from audio.

      AUDIO SEGMENT (Duration: #{chunk[:duration].round(1)} seconds):
      "#{chunk[:text].strip}"

      TASK: Analyze this content and generate 1-2 specific image search queries that would create compelling visual accompaniment for a Ken Burns-style video effect.

      REQUIREMENTS:
      - Generate queries that are specific and descriptive
      - Focus on visual elements mentioned or implied in the text
      - Consider the emotional tone and context
      - Avoid generic terms, be specific about objects, scenes, or concepts
      - Each query should be 2-6 words maximum
      - Prioritize queries that would work well for Ken Burns effects (landscapes, objects, people, etc.)

      RESPONSE FORMAT (JSON only):
      {
        "image_queries": [
          "specific visual query 1",
          "specific visual query 2"
        ],
        "primary_theme": "brief description of main theme",
        "visual_style": "#{style}",
        "duration_suggestion": #{chunk[:duration].round(1)}
      }

      Generate only the JSON response, no other text.
    PROMPT

    prompt
  end

  # Build prompt for single text analysis
  # @param text [String] Text to analyze
  # @param context [Hash] Additional context
  # @return [String] Formatted prompt
  def build_single_text_prompt(text, context = {})
    context_type = context[:type] || "content"
    style = context[:style] || "realistic, high-quality"
    
    prompt = <<~PROMPT
      You are an expert at analyzing text and determining what images would best illustrate the content.

      CONTEXT: This is #{context_type} that needs visual accompaniment.

      TEXT: "#{text.strip}"

      TASK: Generate 2-3 specific image search queries that would create compelling visual accompaniment.

      REQUIREMENTS:
      - Generate queries that are specific and descriptive
      - Focus on visual elements mentioned or implied in the text
      - Each query should be 2-6 words maximum
      - Prioritize queries that would work well for Ken Burns effects

      RESPONSE FORMAT (JSON only):
      {
        "image_queries": [
          "specific visual query 1",
          "specific visual query 2"
        ],
        "visual_style": "#{style}"
      }

      Generate only the JSON response, no other text.
    PROMPT

    prompt
  end

  # Make request to Groq LLM API
  # @param prompt [String] The prompt to send
  # @return [Hash] LLM response
  def make_llm_request(prompt)
    uri = URI("#{GROQ_API_BASE}/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'

    body = {
      model: @model,
      messages: [
        {
          role: "user",
          content: prompt
        }
      ],
      max_tokens: @max_tokens,
      temperature: @temperature,
      stream: false
    }

    request.body = body.to_json

    response = make_request(request, uri)
    JSON.parse(response.body)
  end

  # Make HTTP request with error handling
  # @param request [Net::HTTP::Post] Request object
  # @param uri [URI] Request URI
  # @return [Net::HTTPResponse] Response object
  def make_request(request, uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    response = http.request(request)

    case response.code.to_i
    when 200
      response
    when 401
      raise "Authentication failed. Check your GROQ_API_KEY"
    when 400
      error_data = JSON.parse(response.body) rescue {}
      raise "Bad request: #{error_data['error'] || response.body}"
    when 429
      raise "Rate limit exceeded. Please wait before retrying"
    else
      raise "API request failed with status #{response.code}: #{response.body}"
    end
  end

  # Parse LLM response for analysis
  # @param response [Hash] LLM response
  # @return [Hash] Parsed analysis
  def parse_analysis_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    
    return { image_queries: [], primary_theme: "unknown", visual_style: "realistic" } unless content

    # Try to parse JSON from the response
    begin
      # Extract JSON from the response (in case there's extra text)
      json_match = content.match(/\{.*\}/m)
      if json_match
        parsed = JSON.parse(json_match[0])
        return {
          image_queries: parsed['image_queries'] || [],
          primary_theme: parsed['primary_theme'] || "unknown",
          visual_style: parsed['visual_style'] || "realistic",
          duration_suggestion: parsed['duration_suggestion']
        }
      else
        # Fallback: try to extract queries from text
        queries = extract_queries_from_text(content)
        return {
          image_queries: queries,
          primary_theme: "extracted from text",
          visual_style: "realistic"
        }
      end
    rescue JSON::ParserError => e
      puts "⚠️  Warning: Could not parse JSON response: #{e.message}"
      # Fallback: extract queries from text
      queries = extract_queries_from_text(content)
      return {
        image_queries: queries,
        primary_theme: "extracted from text",
        visual_style: "realistic"
      }
    end
  end

  # Extract image queries from text when JSON parsing fails
  # @param text [String] Response text
  # @return [Array] Extracted queries
  def extract_queries_from_text(text)
    # Simple fallback extraction
    lines = text.split("\n")
    queries = []
    
    lines.each do |line|
      line = line.strip
      next if line.empty?
      
      # Look for quoted strings or key phrases
      if line.match(/^["'](.+?)["']$/) || line.match(/^[-*]\s*(.+)$/)
        query = line.gsub(/^["']|["']$/, '').gsub(/^[-*]\s*/, '').strip
        queries << query if query.length > 2 && query.length < 50
      end
    end
    
    queries.uniq.first(3) # Limit to 3 queries
  end

  # Enhance analysis with additional context
  # @param parsed [Hash] Parsed analysis
  # @param chunk [Hash] Original chunk
  # @param options [Hash] Analysis options
  # @return [Hash] Enhanced analysis
  def enhance_analysis(parsed, chunk, options)
    # Ensure we have at least some queries
    if parsed[:image_queries].empty?
      # Generate fallback queries based on text content
      fallback_queries = generate_fallback_queries(chunk[:text])
      parsed[:image_queries] = fallback_queries
    end

    # Add timing information
    parsed[:start_time] = chunk[:start_time]
    parsed[:end_time] = chunk[:end_time]
    parsed[:duration] = chunk[:duration]
    parsed[:segment_count] = chunk[:segments].length

    # Add confidence score based on query quality
    parsed[:confidence] = calculate_query_confidence(parsed[:image_queries])

    parsed
  end

  # Generate fallback queries when LLM fails
  # @param text [String] Text content
  # @return [Array] Fallback queries
  def generate_fallback_queries(text)
    # Create imaginative, positive, and cheerful fallback queries
    # These are designed to be engaging and work well for Ken Burns effects
    
    # Positive, cheerful themes that work well for video
    cheerful_themes = [
      "sunny landscape",
      "happy people",
      "beautiful nature",
      "inspiring architecture",
      "vibrant colors",
      "peaceful scenes",
      "creative workspace",
      "adventure travel",
      "artistic expression",
      "community celebration",
      "serene landscapes",
      "dynamic city life",
      "natural beauty",
      "cultural diversity",
      "innovative technology",
      "sustainable living",
      "human connection",
      "artistic creativity",
      "urban exploration",
      "rural tranquility"
    ]
    
    # Extract some context from the text to make queries more relevant
    words = text.downcase.split(/\W+/).reject { |w| w.length < 3 }
    
    # Look for specific themes in the text
    if text.match(/tech|digital|computer|phone|device/i)
      queries = ["modern technology", "innovative design", "digital lifestyle"]
    elsif text.match(/business|work|professional|career/i)
      queries = ["professional workspace", "business collaboration", "modern office"]
    elsif text.match(/nature|outdoor|environment|green/i)
      queries = ["natural landscape", "environmental beauty", "outdoor adventure"]
    elsif text.match(/city|urban|building|architecture/i)
      queries = ["urban architecture", "city skyline", "modern cityscape"]
    elsif text.match(/people|human|person|community/i)
      queries = ["diverse community", "human connection", "cultural celebration"]
    elsif text.match(/art|creative|design|artistic/i)
      queries = ["artistic expression", "creative workspace", "design inspiration"]
    elsif text.match(/travel|adventure|exploration/i)
      queries = ["adventure travel", "exploration journey", "world discovery"]
    elsif text.match(/food|cooking|culinary/i)
      queries = ["culinary artistry", "food culture", "gourmet experience"]
    elsif text.match(/music|sound|audio/i)
      queries = ["musical expression", "sound studio", "creative performance"]
    elsif text.match(/health|wellness|fitness/i)
      queries = ["healthy lifestyle", "wellness journey", "active living"]
    else
      # Default to positive, engaging themes
      queries = cheerful_themes.sample(3)
    end
    
    # Ensure we have exactly 3 queries
    queries = queries.first(3)
    while queries.length < 3
      queries << cheerful_themes.sample
    end
    
    queries.uniq.first(3)
  end

  # Calculate confidence score for queries
  # @param queries [Array] Image queries
  # @return [Float] Confidence score (0-1)
  def calculate_query_confidence(queries)
    return 0.0 if queries.empty?
    
    # Simple scoring based on query characteristics
    scores = queries.map do |query|
      score = 0.5 # Base score
      score += 0.2 if query.length > 3 && query.length < 20
      score += 0.2 if query.match(/^[a-zA-Z\s]+$/) # Only letters and spaces
      score += 0.1 if query.split.length > 1 # Multiple words
      score
    end
    
    scores.sum / scores.length
  end

  # Distribute image queries across segments in a chunk
  # @param segments [Array] Audio segments
  # @param image_queries [Array] Image queries for the chunk
  # @return [Array] Segments with distributed queries
  def distribute_image_queries(segments, image_queries)
    return segments if image_queries.empty?
    
    # Simple distribution: assign ONE query to each segment
    segments.map.with_index do |segment, index|
      # Assign ONE query per segment based on segment position
      query_index = index % image_queries.length
      
      segment.merge({
        image_queries: [image_queries[query_index]], # Only ONE query per segment
        has_images: true
      })
    end
  end
end 