#!/bin/bash

# Ken Burns Video Generator - Barebones Bash Script
# This script runs directly in Lambda with ffmpeg binary

set -e

# Configuration
BUCKET_NAME="${S3_BUCKET:-burns-videos}"
TEMP_DIR="/tmp"
DEFAULT_FPS=24
DEFAULT_RESOLUTION="1920x1080"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Download file from S3
download_s3_file() {
    local s3_key="$1"
    local local_path="$2"
    
    log "Downloading from S3: $s3_key"
    aws s3 cp "s3://$BUCKET_NAME/$s3_key" "$local_path" || return 1
    log "Downloaded: $local_path"
}

# Upload file to S3
upload_s3_file() {
    local local_path="$1"
    local s3_key="$2"
    
    log "Uploading to S3: $s3_key"
    aws s3 cp "$local_path" "s3://$BUCKET_NAME/$s3_key" || return 1
    log "Uploaded: $s3_key"
}

# Download image from URL
download_image() {
    local url="$1"
    local local_path="$2"
    
    log "Downloading image: $url"
    curl -L -o "$local_path" "$url" || return 1
    log "Downloaded image: $local_path"
}

# Generate Ken Burns video from image
generate_ken_burns_video() {
    local input_image="$1"
    local output_video="$2"
    local duration="$3"
    
    log "Generating Ken Burns video: $input_image -> $output_video"
    
    # Create Ken Burns effect: zoom from 1.3x to 1.0x
    ffmpeg -i "$input_image" \
        -filter_complex "scale=$DEFAULT_RESOLUTION:force_original_aspect_ratio=decrease,pad=$DEFAULT_RESOLUTION:(ow-iw)/2:(oh-ih)/2,zoompan=z='min(zoom+0.0015,1.5)':d=$((duration * DEFAULT_FPS)):x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=$DEFAULT_RESOLUTION" \
        -t "$duration" \
        -c:v libx264 \
        -preset fast \
        -crf 23 \
        -y "$output_video" || return 1
    
    log "Generated video: $output_video"
}

# Combine videos with audio
combine_videos_with_audio() {
    local video_list="$1"
    local audio_file="$2"
    local output_video="$3"
    
    log "Combining videos with audio"
    
    # Combine videos first
    local combined_video="$TEMP_DIR/combined_video.mp4"
    ffmpeg -f concat -safe 0 -i "$video_list" -c copy -y "$combined_video" || return 1
    
    # Add audio if available
    if [ -f "$audio_file" ]; then
        ffmpeg -i "$combined_video" -i "$audio_file" -c:v copy -c:a aac -shortest -y "$output_video" || return 1
        log "Added audio to video"
    else
        mv "$combined_video" "$output_video"
    fi
    
    log "Final video: $output_video"
}

# Get video duration
get_video_duration() {
    local video_path="$1"
    ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_path" 2>/dev/null || echo "0"
}

# Main processing function
process_segment() {
    local project_id="$1"
    local segment_id="$2"
    local images_json="$3"
    local duration="$4"
    
    log "Processing segment: $segment_id"
    
    # Parse images JSON and download first image
    local first_image_url=$(echo "$images_json" | ./jq -r '.[0].url // empty')
    if [ -z "$first_image_url" ]; then
        error_exit "No images found for segment $segment_id"
    fi
    
    # Download image
    local image_path="$TEMP_DIR/segment_${segment_id}_image.jpg"
    download_image "$first_image_url" "$image_path" || error_exit "Failed to download image"
    
    # Generate video
    local video_path="$TEMP_DIR/segment_${segment_id}_video.mp4"
    generate_ken_burns_video "$image_path" "$video_path" "$duration" || error_exit "Failed to generate video"
    
    # Upload segment video
    local s3_key="segments/$project_id/${segment_id}_segment.mp4"
    upload_s3_file "$video_path" "$s3_key" || error_exit "Failed to upload segment video"
    
    # Clean up
    rm -f "$image_path" "$video_path"
    
    log "Segment $segment_id completed"
    echo "{\"segment_id\":\"$segment_id\",\"segment_s3_key\":\"$s3_key\",\"duration\":$duration}"
}

# Combine segments function
combine_segments() {
    local project_id="$1"
    local segments_json="$2"
    
    log "Combining segments for project: $project_id"
    
    # Download segment videos
    local video_list="$TEMP_DIR/video_list.txt"
    local segment_videos=()
    
    echo "$segments_json" | ./jq -r '.[] | .segment_s3_key' | while read s3_key; do
        if [ -n "$s3_key" ]; then
            local video_path="$TEMP_DIR/segment_$(basename "$s3_key" .mp4).mp4"
            download_s3_file "$s3_key" "$video_path" || continue
            segment_videos+=("$video_path")
            echo "file '$video_path'" >> "$video_list"
        fi
    done
    
    if [ ${#segment_videos[@]} -eq 0 ]; then
        error_exit "No segment videos found"
    fi
    
    # Download audio file
    local audio_file="$TEMP_DIR/audio.mp3"
    local manifest_key="projects/$project_id/manifest.json"
    local manifest_path="$TEMP_DIR/manifest.json"
    
    download_s3_file "$manifest_key" "$manifest_path" || error_exit "Failed to download manifest"
    local audio_s3_key=$(./jq -r '.audio_file // empty' "$manifest_path")
    
    if [ -n "$audio_s3_key" ]; then
        download_s3_file "$audio_s3_key" "$audio_file" || log "Warning: Could not download audio file"
    fi
    
    # Combine videos
    local final_video="$TEMP_DIR/final_video.mp4"
    combine_videos_with_audio "$video_list" "$audio_file" "$final_video" || error_exit "Failed to combine videos"
    
    # Upload final video
    local final_s3_key="videos/${project_id}_final_video.mp4"
    upload_s3_file "$final_video" "$final_s3_key" || error_exit "Failed to upload final video"
    
    # Get video duration
    local duration=$(get_video_duration "$final_video")
    
    # Clean up
    rm -f "$video_list" "$audio_file" "$manifest_path" "$final_video"
    for video in "${segment_videos[@]}"; do
        rm -f "$video"
    done
    
    log "Video combination completed"
    echo "{\"video_s3_key\":\"$final_s3_key\",\"duration\":$duration,\"resolution\":\"$DEFAULT_RESOLUTION\",\"fps\":$DEFAULT_FPS}"
}

# Main handler
main() {
    local event="$1"
    
    log "Starting Ken Burns video generation"
    log "Event: $event"
    log "Event length: ${#event}"
    log "First 100 chars: ${event:0:100}"
    
    # Parse event
    local project_id=$(echo "$event" | ./jq -r '.project_id // empty')
    local segment_id=$(echo "$event" | ./jq -r '.segment_id // empty')
    local images_json=$(echo "$event" | ./jq -r '.images // empty')
    local duration=$(echo "$event" | ./jq -r '.duration // 5.0')
    local segments_json=$(echo "$event" | ./jq -r '.segment_results // empty')
    
    log "Parsed values:"
    log "  project_id: '$project_id'"
    log "  segment_id: '$segment_id'"
    log "  duration: '$duration'"
    log "  images_json length: ${#images_json}"
    
    if [ -z "$project_id" ]; then
        error_exit "project_id is required"
    fi
    
    # Check if this is segment processing or combination
    if [ -n "$segment_id" ] && [ -n "$images_json" ]; then
        # Process single segment
        result=$(process_segment "$project_id" "$segment_id" "$images_json" "$duration")
        echo "{\"statusCode\":200,\"body\":$result}"
    elif [ -n "$segments_json" ]; then
        # Combine segments
        result=$(combine_segments "$project_id" "$segments_json")
        echo "{\"statusCode\":200,\"body\":$result}"
    else
        error_exit "Invalid event format"
    fi
}

# Check if running in Lambda
if [ -n "$AWS_LAMBDA_FUNCTION_NAME" ]; then
    # Lambda environment - read from stdin
    event=$(cat)
    main "$event"
else
    # Local testing
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <event_json>"
        exit 1
    fi
    main "$1"
fi 