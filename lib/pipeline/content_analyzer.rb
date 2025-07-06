require_relative '../services/llm_service'

class ContentAnalyzer
  def initialize(llm_service = nil)
    @llm_service = llm_service || LLMService.new
  end

  # Analyze transcribed audio and generate image queries for each segment
  # @param audio_result [Hash] Result from AudioProcessor
  # @param options [Hash] Analysis options
  # @return [Hash] Enhanced audio result with image queries
  def analyze_for_images(audio_result, options = {})
    puts "🎨 Analyzing content for image generation..."
    
    segments = audio_result[:segments]
    
    # Analyze segments for image queries
    enriched_segments = @llm_service.analyze_content_for_images(segments, options)
    
    # Calculate analysis metrics
    analysis_metrics = calculate_analysis_metrics(enriched_segments)
    
    # Create enhanced result
    enhanced_result = audio_result.merge({
      segments: enriched_segments,
      analysis_metrics: analysis_metrics,
      total_image_queries: enriched_segments.sum { |s| s[:image_queries].length },
      segments_with_images: enriched_segments.count { |s| s[:has_images] }
    })
    
    puts "✅ Content analysis completed:"
    puts "  📊 Total segments: #{enriched_segments.length}"
    puts "  🖼️  Segments with images: #{enhanced_result[:segments_with_images]}"
    puts "  🔍 Total image queries: #{enhanced_result[:total_image_queries]}"
    puts "  📈 Average confidence: #{analysis_metrics[:average_confidence].round(3)}"
    
    enhanced_result
  end

  # Analyze a single text segment for image queries
  # @param text [String] Text to analyze
  # @param context [Hash] Additional context
  # @return [Array] Image queries
  def analyze_single_segment(text, context = {})
    @llm_service.generate_image_queries_for_text(text, context)
  end

  # Get analysis summary for debugging
  # @param enhanced_result [Hash] Enhanced audio result
  # @return [Hash] Analysis summary
  def get_analysis_summary(enhanced_result)
    segments = enhanced_result[:segments]
    
    summary = {
      total_segments: segments.length,
      segments_with_images: segments.count { |s| s[:has_images] },
      total_image_queries: segments.sum { |s| s[:image_queries].length },
      average_queries_per_segment: segments.sum { |s| s[:image_queries].length }.to_f / segments.length,
      confidence_distribution: {
        high: segments.count { |s| s[:confidence] && s[:confidence] > 0.7 },
        medium: segments.count { |s| s[:confidence] && s[:confidence] > 0.4 && s[:confidence] <= 0.7 },
        low: segments.count { |s| s[:confidence] && s[:confidence] <= 0.4 }
      },
      top_queries: get_top_queries(segments),
      duration_breakdown: get_duration_breakdown(segments)
    }
    
    summary
  end

  # Validate analysis results
  # @param enhanced_result [Hash] Enhanced audio result
  # @return [Hash] Validation results
  def validate_analysis(enhanced_result)
    segments = enhanced_result[:segments]
    issues = []
    
    # Check for segments without images
    segments_without_images = segments.select { |s| !s[:has_images] }
    if segments_without_images.any?
      issues << {
        type: :segments_without_images,
        count: segments_without_images.length,
        segments: segments_without_images.map { |s| { id: s[:id], text: s[:text][0..50] } }
      }
    end
    
    # Check for low confidence segments
    low_confidence_segments = segments.select { |s| s[:confidence] && s[:confidence] < 0.3 }
    if low_confidence_segments.any?
      issues << {
        type: :low_confidence_segments,
        count: low_confidence_segments.length,
        segments: low_confidence_segments.map { |s| { id: s[:id], confidence: s[:confidence] } }
      }
    end
    
    # Check for very short segments
    short_segments = segments.select { |s| (s[:end_time] - s[:start_time]) < 2.0 }
    if short_segments.any?
      issues << {
        type: :short_segments,
        count: short_segments.length,
        segments: short_segments.map { |s| { id: s[:id], duration: s[:end_time] - s[:start_time] } }
      }
    end
    
    {
      valid: issues.empty?,
      issues: issues,
      total_issues: issues.sum { |i| i[:count] }
    }
  end

  private

  # Calculate analysis metrics
  # @param segments [Array] Enriched segments
  # @return [Hash] Analysis metrics
  def calculate_analysis_metrics(segments)
    return {} if segments.empty?
    
    confidences = segments.map { |s| s[:confidence] }.compact
    query_counts = segments.map { |s| s[:image_queries].length }
    durations = segments.map { |s| s[:end_time] - s[:start_time] }
    
    {
      average_confidence: confidences.any? ? confidences.sum / confidences.length : 0,
      average_queries_per_segment: query_counts.any? ? query_counts.sum.to_f / query_counts.length : 0,
      total_queries: query_counts.sum,
      segments_with_images: segments.count { |s| s[:has_images] },
      average_segment_duration: durations.any? ? durations.sum / durations.length : 0,
      total_duration: durations.sum
    }
  end

  # Get top image queries by frequency
  # @param segments [Array] Enriched segments
  # @return [Array] Top queries with counts
  def get_top_queries(segments)
    query_counts = Hash.new(0)
    
    segments.each do |segment|
      segment[:image_queries].each do |query|
        query_counts[query] += 1
      end
    end
    
    query_counts.sort_by { |query, count| -count }.first(10)
  end

  # Get duration breakdown
  # @param segments [Array] Enriched segments
  # @return [Hash] Duration statistics
  def get_duration_breakdown(segments)
    durations = segments.map { |s| s[:end_time] - s[:start_time] }
    
    return {} if durations.empty?
    
    {
      total_duration: durations.sum,
      average_duration: durations.sum / durations.length,
      min_duration: durations.min,
      max_duration: durations.max,
      duration_distribution: {
        short: durations.count { |d| d < 5.0 },
        medium: durations.count { |d| d >= 5.0 && d < 15.0 },
        long: durations.count { |d| d >= 15.0 }
      }
    }
  end
end 