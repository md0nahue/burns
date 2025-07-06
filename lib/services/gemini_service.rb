require 'net/http'
require 'json'
require 'securerandom'

class GeminiService
  GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta'
  
  def initialize(api_key = nil)
    @api_key = api_key || ENV['GEMINI_API_KEY']
    @model = 'gemini-2.5-flash-lite-preview-06-17'
    @max_tokens = 2048
    @temperature = 0.1
    
    raise "GEMINI_API_KEY environment variable not set" unless @api_key
  end

  # Analyze transcribed segments and generate image queries
  # @param segments [Array] Transcribed audio segments
  # @param options [Hash] Analysis options
  # @return [Array] Segments with image queries and timing
  def analyze_content_for_images(segments, options = {})
    puts "🧠 Analyzing content for image generation using Gemini..."
    
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
    
    response = make_gemini_request(prompt)
    
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
    
    response = make_gemini_request(prompt)
    
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

      TASK: Analyze this content and generate 2-4 specific image search queries that would create compelling visual accompaniment for a Ken Burns-style video effect.

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
          "specific visual query 2",
          "specific visual query 3"
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

  # Make request to Gemini API
  # @param prompt [String] The prompt to send
  # @return [Hash] API response
  def make_gemini_request(prompt)
    uri = URI("#{GEMINI_API_BASE}/models/#{@model}:generateContent?key=#{@api_key}")
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    request.body = {
      contents: [
        {
          parts: [
            {
              text: prompt
            }
          ]
        }
      ],
      generationConfig: {
        temperature: @temperature,
        maxOutputTokens: @max_tokens,
        topP: 0.8,
        topK: 40
      }
    }.to_json
    
    response = make_request(request, uri)
    
    if response['error']
      raise "Gemini API Error: #{response['error']['message']}"
    end
    
    response
  end

  # Make HTTP request
  # @param request [Net::HTTP::Request] The request object
  # @param uri [URI] The URI object
  # @return [Hash] Parsed JSON response
  def make_request(request, uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    http.open_timeout = 30
    
    response = http.request(request)
    
    if response.code != '200'
      raise "HTTP Error: #{response.code} - #{response.message}"
    end
    
    JSON.parse(response.body)
  rescue => e
    raise "Request failed: #{e.message}"
  end

  # Parse analysis response from Gemini
  # @param response [Hash] Gemini API response
  # @return [Hash] Parsed analysis result
  def parse_analysis_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    
    return { image_queries: [], primary_theme: '', visual_style: '' } unless content
    
    begin
      # Try to parse as JSON
      parsed = JSON.parse(content.strip)
      
      # Validate structure
      {
        image_queries: parsed['image_queries'] || [],
        primary_theme: parsed['primary_theme'] || '',
        visual_style: parsed['visual_style'] || 'realistic, high-quality',
        duration_suggestion: parsed['duration_suggestion']
      }
    rescue JSON::ParserError
      # Fallback: try to extract queries from text
      {
        image_queries: extract_queries_from_text(content),
        primary_theme: 'extracted from content',
        visual_style: 'realistic, high-quality'
      }
    end
  end

  # Extract queries from text when JSON parsing fails
  # @param text [String] Response text
  # @return [Array] Extracted queries
  def extract_queries_from_text(text)
    # Simple fallback extraction
    lines = text.split("\n")
    queries = []
    
    lines.each do |line|
      line = line.strip
      next if line.empty?
      
      # Look for quoted strings or simple phrases
      if line.match(/^["'](.+?)["']$/) || line.match(/^[-*]\s*(.+)$/)
        query = $1.strip
        queries << query if query.length > 2 && query.length < 50
      elsif line.match(/^(\w+(?:\s+\w+){1,5})$/)
        queries << line
      end
    end
    
    queries.uniq.first(4) # Limit to 4 queries
  end

  # Enhance analysis with fallbacks and validation
  # @param parsed [Hash] Parsed response
  # @param chunk [Hash] Original chunk
  # @param options [Hash] Options
  # @return [Hash] Enhanced analysis
  def enhance_analysis(parsed, chunk, options)
    # Ensure we have at least some queries
    if parsed[:image_queries].empty?
      puts "  ⚠️  No queries generated, using fallback extraction"
      parsed[:image_queries] = generate_fallback_queries(chunk[:text])
    end
    
    # Validate query quality
    parsed[:image_queries] = parsed[:image_queries].select do |query|
      query.length >= 2 && query.length <= 50
    end
    
    # Add confidence score
    parsed[:confidence] = calculate_query_confidence(parsed[:image_queries])
    
    parsed
  end

  # Generate fallback queries from text
  # @param text [String] Text to analyze
  # @return [Array] Generated queries
  def generate_fallback_queries(text)
    # Simple keyword extraction
    words = text.downcase.split(/\W+/).reject { |w| w.length < 3 }
    
    # Count word frequency
    word_count = Hash.new(0)
    words.each { |word| word_count[word] += 1 }
    
    # Get most common words
    common_words = word_count.sort_by { |_, count| -count }.first(10).map(&:first)
    
    # Generate simple queries
    queries = []
    common_words.each_slice(2) do |words|
      query = words.join(' ')
      queries << query if query.length >= 3
      break if queries.length >= 3
    end
    
    queries
  end

  # Calculate confidence in generated queries
  # @param queries [Array] Image queries
  # @return [Float] Confidence score (0.0 to 1.0)
  def calculate_query_confidence(queries)
    return 0.0 if queries.empty?
    
    # Simple heuristic: longer, more specific queries get higher confidence
    avg_length = queries.map(&:length).sum.to_f / queries.length
    specificity_score = [avg_length / 20.0, 1.0].min
    
    # More queries = higher confidence (up to a point)
    quantity_score = [queries.length / 4.0, 1.0].min
    
    (specificity_score + quantity_score) / 2.0
  end

  # Distribute image queries across segments
  # @param segments [Array] Audio segments
  # @param image_queries [Array] Image queries
  # @return [Array] Segments with assigned queries
  def distribute_image_queries(segments, image_queries)
    return segments if image_queries.empty?
    
    segments.each_with_index do |segment, index|
      # Assign queries based on segment position
      query_index = index % image_queries.length
      segment[:image_query] = image_queries[query_index]
    end
    
    segments
  end
end 