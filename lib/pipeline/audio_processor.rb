require_relative '../services/whisper_service'

class AudioProcessor
  def initialize(whisper_service = nil)
    @whisper_service = whisper_service || WhisperService.new
  end

  # Process an audio file and return structured transcription data
  # @param file_path [String] Path to audio file
  # @param options [Hash] Processing options
  # @return [Hash] Structured transcription data
  def process_audio(file_path, options = {})
    puts "🎤 Processing audio file: #{File.basename(file_path)}"
    
    # Default options for best results
    whisper_options = {
      model: options[:model] || 'whisper-large-v3-turbo',
      language: options[:language] || 'en',
      response_format: 'verbose_json',
      timestamp_granularities: ['segment', 'word'],
      temperature: 0,
      prompt: options[:prompt]
    }

    # Transcribe the audio
    result = @whisper_service.transcribe(file_path, whisper_options)
    
    # Structure the data for the pipeline
    structured_data = structure_transcription(result, file_path)
    
    puts "✅ Transcription completed: #{structured_data[:segments].length} segments"
    puts "📊 Total duration: #{structured_data[:duration]} seconds"
    puts "📝 Total words: #{structured_data[:word_count]}"
    
    structured_data
  end

  # Get audio file metadata
  # @param file_path [String] Path to audio file
  # @return [Hash] File metadata
  def get_audio_metadata(file_path)
    {
      filename: File.basename(file_path),
      file_size: File.size(file_path),
      file_type: File.extname(file_path),
      created_at: File.ctime(file_path),
      modified_at: File.mtime(file_path)
    }
  end

  # Validate audio file for processing
  # @param file_path [String] Path to audio file
  # @return [Boolean] Whether file is valid
  def validate_audio_file(file_path)
    begin
      @whisper_service.validate_file!(file_path)
      true
    rescue => e
      puts "❌ Audio file validation failed: #{e.message}"
      false
    end
  end

  private

  # Structure the transcription result for pipeline processing
  # @param result [Hash] Raw transcription result from WhisperService
  # @param file_path [String] Original audio file path
  # @return [Hash] Structured data
  def structure_transcription(result, file_path)
    segments = result[:segments] || []
    words = result[:words] || []
    
    # Calculate total duration
    duration = segments.any? ? segments.last[:end_time] || segments.last['end'] : 0
    
    # Structure segments with additional metadata
    structured_segments = segments.map.with_index do |segment, index|
      {
        id: index,
        start_time: segment[:start_time] || segment['start'],
        end_time: segment[:end_time] || segment['end'],
        text: segment[:text] || segment['text'],
        confidence: segment[:confidence] || segment['avg_logprob'],
        no_speech_prob: segment[:no_speech_prob] || segment['no_speech_prob'],
        compression_ratio: segment[:compression_ratio] || segment['compression_ratio'],
        # Extract words for this segment
        words: extract_words_for_segment(words, segment[:start_time] || segment['start'], segment[:end_time] || segment['end'])
      }
    end

    # Calculate quality metrics
    quality_metrics = calculate_quality_metrics(structured_segments)
    
    {
      audio_file: file_path,
      metadata: get_audio_metadata(file_path),
      duration: duration,
      word_count: words.length,
      segments: structured_segments,
      quality_metrics: quality_metrics,
      raw_result: result
    }
  end

  # Extract words that fall within a time segment
  # @param words [Array] All words from transcription
  # @param start_time [Float] Segment start time
  # @param end_time [Float] Segment end time
  # @return [Array] Words in the segment
  def extract_words_for_segment(words, start_time, end_time)
    words.select do |word|
      word['start'] >= start_time && word['end'] <= end_time
    end
  end

  # Calculate quality metrics for the transcription
  # @param segments [Array] Structured segments
  # @return [Hash] Quality metrics
  def calculate_quality_metrics(segments)
    return {} if segments.empty?

    confidences = segments.map { |s| s[:confidence] }.compact
    no_speech_probs = segments.map { |s| s[:no_speech_prob] }.compact
    compression_ratios = segments.map { |s| s[:compression_ratio] }.compact

    {
      average_confidence: confidences.any? ? confidences.sum / confidences.length : 0,
      average_no_speech_prob: no_speech_probs.any? ? no_speech_probs.sum / no_speech_probs.length : 0,
      average_compression_ratio: compression_ratios.any? ? compression_ratios.sum / compression_ratios.length : 0,
      low_confidence_segments: segments.count { |s| s[:confidence] && s[:confidence] < -0.5 },
      high_noise_segments: segments.count { |s| s[:no_speech_prob] && s[:no_speech_prob] > 0.5 },
      total_segments: segments.length
    }
  end
end 