require 'net/http'
require 'json'
require 'securerandom'
require 'digest'
require 'pry'

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
    
    # Check for cached analysis (respect force option)
    cache_file = get_cache_file_path(segments, options)
    if File.exist?(cache_file) && !options[:force]
      puts "    📁 Using cached content analysis from: #{cache_file}"
      cached_data = JSON.parse(File.read(cache_file), symbolize_names: true)
      return cached_data
    elsif options[:force]
      puts "    🔄 Force mode enabled - bypassing cache"
    end
    
    # Process segments in smaller batches to avoid API limits
    batch_size = 10  # Process 10 segments at a time
    all_results = []
    
    puts "  📝 Analyzing #{segments.length} segments in batches of #{batch_size}..."
    
    segments.each_slice(batch_size).with_index do |batch, batch_index|
      puts "    🔄 Processing batch #{batch_index + 1}/#{(segments.length.to_f / batch_size).ceil} (#{batch.length} segments)"
      
      begin
        # Build prompt for this batch
        prompt = build_batch_analysis_prompt(batch, options)
        
        # Make API request for this batch
        response = make_gemini_request(prompt)
        
        # Parse the response
        batch_results = parse_batch_analysis_response(response, batch)
        
        # Add to overall results
        all_results.concat(batch_results)
        
        # Add delay between batches to respect rate limits
        sleep(2) if batch_index < (segments.length.to_f / batch_size).ceil - 1
        
      rescue => e
        puts "    ❌ Error processing batch #{batch_index + 1}: #{e.message}"
        # Add segments with fallback queries instead of failing completely
        batch.each do |segment|
          all_results << segment.merge({
            image_queries: generate_fallback_queries(segment[:text] || segment['text'] || ''),
            has_images: true
          })
        end
      end
    end
    
    # Cache the analysis result
    puts "    💾 Caching content analysis to: #{cache_file}"
    File.write(cache_file, JSON.pretty_generate(all_results))
    
    puts "✅ Content analysis completed: #{all_results.length} segments processed"
    all_results
  end

  # Analyze a single chunk of audio content
  # @param chunk [Hash] Audio chunk with segments
  # @param options [Hash] Analysis options
  # @return [Hash] Analysis result with image queries
  def analyze_chunk(chunk, options = {})
    prompt = build_analysis_prompt(chunk, options)
    
    # Add delay between requests to avoid rate limiting
    sleep(1) if options[:rate_limit]
    
    response = make_gemini_request_with_retry(prompt)
    
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

  # Generate cache file path for content analysis
  # @param segments [Array] Audio segments
  # @param options [Hash] Analysis options
  # @return [String] Cache file path
  def get_cache_file_path(segments, options)
    # Create a hash of the segments and options to generate a unique cache key
    content_hash = Digest::MD5.hexdigest(segments.to_json + options.to_json)
    cache_dir = 'cache'
    Dir.mkdir(cache_dir) unless Dir.exist?(cache_dir)
    "#{cache_dir}/gemini_analysis_#{content_hash}.json"
  end

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
      - Generate queries that are HIGHLY specific and descriptive
      - Focus on concrete visual elements mentioned or implied in the text
      - Consider the emotional tone and context
      - Avoid generic terms, be specific about objects, scenes, or concepts
      - Each query should be 3-8 words for better specificity
      - Prioritize queries that would work well for Ken Burns effects (landscapes, objects, people, etc.)
      - Include backup queries that are broader but still relevant
      - Always provide 2-3 alternative search terms per segment

      RESPONSE FORMAT (JSON only):
      {
        "image_queries": [
          "highly specific primary query",
          "specific secondary query",
          "broader fallback query"
        ],
        "backup_queries": [
          "alternative search term 1",
          "alternative search term 2"
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

  # Make Gemini API request with retry logic for rate limiting
  # @param prompt [String] Prompt to send
  # @param max_retries [Integer] Maximum number of retries
  # @return [Hash] API response
  def make_gemini_request_with_retry(prompt, max_retries = 3)
    retries = 0
    
    begin
      make_gemini_request(prompt)
    rescue => e
      if e.message.include?('429') && retries < max_retries
        retries += 1
        wait_time = 2 ** retries # Exponential backoff: 2, 4, 8 seconds
        puts "    ⏳ Rate limited, retrying in #{wait_time} seconds... (attempt #{retries}/#{max_retries})"
        sleep(wait_time)
        retry
      else
        raise e
      end
    end
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
      # Assign ONE query per segment based on segment position
      query_index = index % image_queries.length
      # Preserve all original segment data and add ONE image query
      segment.merge!({
        image_queries: [image_queries[query_index]], # Only ONE query per segment
        has_images: true
      })
    end
    
    segments
  end

  # Build a single comprehensive prompt for all segments
  # @param segments [Array] Transcribed audio segments
  # @param options [Hash] Analysis options
  # @return [String] Formatted prompt
  def build_batch_analysis_prompt(segments, options)
    context = options[:context] || "content analysis"
    style = options[:style] || "realistic, high-quality"
    
    # Calculate total duration
    total_duration = segments.sum { |s| (s[:end_time] || s['end'] || 0) - (s[:start_time] || s['start'] || 0) }
    
    prompt = <<~PROMPT
      You are an expert at analyzing spoken content and determining what images would best illustrate the narrative.

      CONTEXT: This is a #{context} that has been transcribed from audio.

      AUDIO SEGMENTS (Total Duration: #{total_duration.round(1)} seconds):
    PROMPT

    segments.each_with_index do |segment, index|
      start_time = segment[:start_time] || segment['start'] || 0
      end_time = segment[:end_time] || segment['end'] || 0
      text = segment[:text] || segment['text'] || ''
      
      prompt += <<~SEGMENT
        Segment #{index + 1} (#{start_time.round(1)}s - #{end_time.round(1)}s): "#{text.strip}"
      SEGMENT
    end

          prompt += <<~PROMPT
        TASK: Analyze each segment and generate 1-2 specific image search queries for each segment that would create compelling visual accompaniment for a Ken Burns-style video effect.

        REQUIREMENTS:
        - Generate 2-3 queries PER SEGMENT PLUS backup options
        - CATEGORIZE each query as either "famous_person", "stock_image", or "general"
        - For FAMOUS PERSONS (politicians, celebrities, historical figures, public figures): Use category "famous_person"
        - For STOCK IMAGES (landscapes, objects, generic scenes, concepts): Use category "stock_image"  
        - For GENERAL CONTENT (mixed or unclear): Use category "general"
        - Generate queries that are HIGHLY specific and descriptive
        - Focus on concrete visual elements mentioned or implied in each segment's text
        - Consider the emotional tone and context of each segment
        - TIMING AWARENESS: Consider each segment's position in the narrative flow
        - Match images to the EXACT moment being described in each time segment
        - For segments with multiple concepts, prioritize the most visually prominent element
        - Avoid generic terms, be specific about objects, scenes, or concepts
        - Each query should be 3-8 words for better specificity
        - Prioritize queries that would work well for Ken Burns effects (landscapes, objects, people, etc.)
        - Always include backup/fallback queries for each segment
        - Provide alternative search terms that could work if primary queries fail
        - Ensure images can sustain viewer attention for 5-11 seconds without being repetitive

        RESPONSE FORMAT (JSON only):
        {
          "segments": [
            {
              "segment_id": 0,
              "image_queries": [
                {"query": "primary specific query", "category": "famous_person"},
                {"query": "secondary query", "category": "stock_image"},
                {"query": "fallback query", "category": "general"}
              ],
              "backup_queries": ["alternative term 1", "alternative term 2"]
            },
            {
              "segment_id": 1,
              "image_queries": [
                {"query": "primary specific query", "category": "stock_image"},
                {"query": "secondary query", "category": "general"},
                {"query": "fallback query", "category": "famous_person"}
              ],
              "backup_queries": ["alternative term 1", "alternative term 2"]
            }
          ],
          "primary_theme": "brief description of main theme",
          "visual_style": "#{style}",
          "total_duration": #{total_duration.round(1)}
        }

        Generate only the JSON response, no other text. Provide image_queries for each segment with proper categorization.
      PROMPT

    prompt
  end

  # Parse batch analysis response from Gemini
  # @param response [Hash] Gemini API response
  # @param segments [Array] Transcribed audio segments
  # @return [Array] Enriched segments with image queries
  def parse_batch_analysis_response(response, segments)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    

    
    return segments unless content
    
    begin
      # Try to parse as JSON
      parsed = JSON.parse(content.strip, symbolize_names: true)
      
      # Check if we have the new format with segments
      if parsed[:segments] && parsed[:segments].is_a?(Array)
        # New format: each segment has its own queries
        enriched_segments = segments.map.with_index do |segment, index|
          segment_analysis = parsed[:segments].find { |s| s[:segment_id] == index }
          
          if segment_analysis && segment_analysis[:image_queries]
            # Handle both old string format and new categorized format
            processed_queries = segment_analysis[:image_queries].map do |query_item|
              if query_item.is_a?(Hash) && query_item[:query] && query_item[:category]
                # New categorized format
                {
                  query: query_item[:query].to_s.strip,
                  category: query_item[:category].to_s.strip
                }
              elsif query_item.is_a?(String)
                # Old string format - default to general category
                {
                  query: query_item.to_s.strip,
                  category: 'general'
                }
              else
                # Fallback
                {
                  query: query_item.to_s.strip,
                  category: 'general'
                }
              end
            end.reject { |q| q[:query].empty? }
            
            # Extract backup queries if available
            backup_queries = segment_analysis[:backup_queries] || []
            clean_backup_queries = backup_queries.map do |query|
              query.to_s.gsub(/^["\s]*/, '').gsub(/["\s]*$/, '').gsub(/^backup_queries":\s*\[?"?/, '').gsub(/"?\s*,?\s*$/, '')
            end.reject(&:empty?)
            
            segment.merge({
              image_queries: processed_queries,
              backup_queries: clean_backup_queries,
              has_images: processed_queries.any?
            })
          else
            # Fallback: generate queries for this segment
            fallback_queries = generate_fallback_queries(segment[:text] || segment['text'] || '')
            segment.merge({
              image_queries: fallback_queries,
              backup_queries: generate_fallback_queries(segment[:text] || segment['text'] || ''),
              has_images: true
            })
          end
        end
        
        enriched_segments
      else
        # Old format: distribute queries across segments
        image_queries = parsed[:image_queries] || []
        distribute_image_queries(segments, image_queries)
      end
    rescue JSON::ParserError
      # Fallback: try to extract queries from text
      fallback_queries = extract_queries_from_text(content)
      distribute_image_queries(segments, fallback_queries)
    end
  end
end 