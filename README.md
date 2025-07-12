# Ken Burns Video Generator

A production-ready pipeline for generating cinematic Ken Burns effect videos from audio files using AI-powered image generation and AWS Lambda processing.

## Features

- 🎬 **Automatic Ken Burns Effects**: Creates cinematic pan/zoom effects
- 🎤 **Audio Transcription**: Uses Whisper for accurate speech-to-text
- 🧠 **AI Image Generation**: Gemini analyzes content to generate relevant image queries
- 📸 **Multi-Source Images**: Searches Pexels, Unsplash, Pixabay, and more
- ⚡ **Parallel Processing**: AWS Lambda processes video segments concurrently
- 💾 **Smart Caching**: Avoids duplicate API calls and processing
- 🔄 **Automatic Recovery**: Resilient pipeline with retry logic and local fallback
- 📱 **High Quality**: 1080p HD output with smooth 24fps motion

## Quick Start

1. **Setup Configuration**: Copy `config/services.rb.example` to `config/services.rb` and add your API keys

2. **Process Audio File**:
   ```bash
   ruby process_audio_pipeline.rb your_audio.m4a
   ```

3. **Force Complete** (if needed):
   ```bash
   ruby force_complete.rb project_name
   ```

## Pipeline Overview

1. **Audio Processing**: Transcribes audio using Whisper API
2. **Content Analysis**: AI analyzes transcript to generate image search queries  
3. **Image Generation**: Searches multiple stock photo APIs for relevant images
4. **Video Segments**: Creates Ken Burns video segments using AWS Lambda
5. **Final Combination**: Combines all segments with original audio

## Output

- Videos saved to `completed/` directory
- Also uploaded to S3 for sharing
- Typical output: 1080p MP4 with synchronized audio and smooth Ken Burns effects

## Example

```bash
# Process an audio file
ruby process_audio_pipeline.rb first.m4a

# Output: completed/first_ken_burns_video.mp4
```

## Architecture

- **Ruby Pipeline**: Orchestrates the entire process
- **AWS Lambda**: Parallel video segment processing for speed
- **Multiple APIs**: Whisper (audio), Gemini (analysis), image services
- **S3 Storage**: Caching and final video storage
- **Local Fallback**: Automatic fallback if Lambda fails

## Requirements

- Ruby with required gems
- AWS account with Lambda and S3 access
- API keys for: OpenAI (Whisper), Google (Gemini), image services
- FFmpeg for video processing