import json
import boto3
import os
import tempfile
import requests
from datetime import datetime
import logging
from typing import Dict, List, Any
import cv2
import numpy as np
from moviepy.editor import *
from moviepy.video.fx import resize
import urllib.parse

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
lambda_client = boto3.client('lambda')

# Configuration
BUCKET_NAME = os.environ.get('S3_BUCKET', 'burns-videos')
TEMP_DIR = '/tmp'
MAX_VIDEO_DURATION = 300  # 5 minutes
DEFAULT_FPS = 24
DEFAULT_RESOLUTION = (1920, 1080)

class KenBurnsVideoGenerator:
    def __init__(self):
        self.temp_dir = TEMP_DIR
        self.bucket_name = BUCKET_NAME
        
    def lambda_handler(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """
        Main Lambda handler for Ken Burns video generation
        """
        try:
            logger.info(f"Starting video generation for event: {json.dumps(event)}")
            
            # Extract project information
            project_id = event.get('project_id')
            if not project_id:
                return self._error_response("project_id is required")
            
            # Check if this is segment processing or final video combination
            if event.get('options', {}).get('segment_processing'):
                return self._process_segment(event, context)
            elif event.get('options', {}).get('video_combination'):
                return self._combine_segments(event, context)
            else:
                return self._process_full_video(event, context)
            
        except Exception as e:
            logger.error(f"Error in video generation: {str(e)}")
            return self._error_response(f"Video generation failed: {str(e)}")
    
    def _process_segment(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Process a single video segment"""
        try:
            project_id = event.get('project_id')
            segment_id = event.get('segment_id')
            images = event.get('images', [])
            duration = event.get('duration', 0)
            
            logger.info(f"Processing segment {segment_id} for project {project_id}")
            
            # Download images for this segment
            segment_images = []
            for image_data in images:
                s3_key = image_data.get('s3_key')
                if s3_key:
                    image_path = self._download_s3_file(s3_key, f"segment_{segment_id}_{len(segment_images)}.jpg")
                    if image_path:
                        segment_images.append({
                            'path': image_path,
                            'query': image_data.get('query'),
                            'provider': image_data.get('provider')
                        })
            
            if not segment_images:
                return self._error_response(f"No images found for segment {segment_id}")
            
            # Generate segment video
            segment_path = self._generate_segment_video(segment_images, duration)
            
            # Upload segment video
            segment_s3_key = f"segments/{project_id}/{segment_id}_segment.mp4"
            self._upload_segment_video(segment_s3_key, segment_path)
            
            # Clean up temporary files
            self._cleanup_temp_files()
            
            logger.info(f"Segment {segment_id} completed for project {project_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'project_id': project_id,
                    'segment_id': segment_id,
                    'segment_s3_key': segment_s3_key,
                    'duration': duration,
                    'generated_at': datetime.now().iso8601()
                })
            }
            
        except Exception as e:
            logger.error(f"Error processing segment: {str(e)}")
            return self._error_response(f"Segment processing failed: {str(e)}")
    
    def _combine_segments(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Combine segment videos into final video with audio"""
        try:
            project_id = event.get('project_id')
            segment_results = event.get('segment_results', [])
            
            logger.info(f"Combining {len(segment_results)} segments for project {project_id}")
            
            # Download segment videos
            segment_videos = []
            for result in segment_results:
                if result.get('success'):
                    segment_s3_key = result.get('segment_s3_key')
                    if segment_s3_key:
                        video_path = self._download_s3_file(segment_s3_key, f"segment_{len(segment_videos)}.mp4")
                        if video_path:
                            segment_videos.append(video_path)
            
            if not segment_videos:
                return self._error_response("No segment videos found")
            
            # Download original audio
            manifest = self._download_project_manifest(project_id)
            audio_file = self._download_audio_file(manifest.get('audio_file')) if manifest else None
            
            # Combine segments and add audio
            final_video_path = self._combine_segments_with_audio(segment_videos, audio_file)
            
            # Upload final video
            video_url = self._upload_final_video(project_id, final_video_path)
            
            # Clean up temporary files
            self._cleanup_temp_files()
            
            logger.info(f"Segment combination completed for project {project_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'project_id': project_id,
                    'video_url': video_url,
                    'video_s3_key': f"videos/{project_id}_final_video.mp4",
                    'generated_at': datetime.now().iso8601(),
                    'duration': self._get_video_duration(final_video_path),
                    'resolution': DEFAULT_RESOLUTION,
                    'fps': DEFAULT_FPS
                })
            }
            
        except Exception as e:
            logger.error(f"Error combining segments: {str(e)}")
            return self._error_response(f"Segment combination failed: {str(e)}")
    
    def _process_full_video(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Process full video (legacy method for backward compatibility)"""
        try:
            project_id = event.get('project_id')
            
            # Download project manifest
            manifest = self._download_project_manifest(project_id)
            if not manifest:
                return self._error_response(f"Could not download manifest for project {project_id}")
            
            # Download images and audio
            images = self._download_project_images(project_id, manifest)
            audio_file = self._download_audio_file(manifest.get('audio_file'))
            
            if not images:
                return self._error_response("No images found for project")
            
            # Generate Ken Burns video
            video_path = self._generate_ken_burns_video(images, audio_file, manifest)
            
            # Upload final video
            video_url = self._upload_final_video(project_id, video_path)
            
            # Clean up temporary files
            self._cleanup_temp_files()
            
            logger.info(f"Full video generation completed for project {project_id}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'project_id': project_id,
                    'video_url': video_url,
                    'video_s3_key': f"videos/{project_id}_final_video.mp4",
                    'generated_at': datetime.now().iso8601(),
                    'duration': self._get_video_duration(video_path),
                    'resolution': DEFAULT_RESOLUTION,
                    'fps': DEFAULT_FPS
                })
            }
            
        except Exception as e:
            logger.error(f"Error in full video generation: {str(e)}")
            return self._error_response(f"Full video generation failed: {str(e)}")
    
    def _download_project_manifest(self, project_id: str) -> Dict[str, Any]:
        """Download and parse project manifest from S3"""
        try:
            manifest_key = f"projects/{project_id}/manifest.json"
            response = s3_client.get_object(Bucket=self.bucket_name, Key=manifest_key)
            manifest_data = response['Body'].read().decode('utf-8')
            return json.loads(manifest_data)
        except Exception as e:
            logger.error(f"Error downloading manifest: {str(e)}")
            return None
    
    def _download_project_images(self, project_id: str, manifest: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Download all project images from S3"""
        images = []
        
        try:
            for segment in manifest.get('segments', []):
                for image_data in segment.get('generated_images', []):
                    s3_key = image_data.get('s3_key')
                    if s3_key:
                        image_path = self._download_s3_file(s3_key, f"image_{len(images)}.jpg")
                        if image_path:
                            images.append({
                                'path': image_path,
                                'segment_id': segment.get('id'),
                                'start_time': segment.get('start_time'),
                                'end_time': segment.get('end_time'),
                                'query': image_data.get('query'),
                                'provider': image_data.get('provider')
                            })
            
            logger.info(f"Downloaded {len(images)} images for project {project_id}")
            return images
            
        except Exception as e:
            logger.error(f"Error downloading images: {str(e)}")
            return []
    
    def _download_audio_file(self, audio_file_path: str) -> str:
        """Download audio file from S3"""
        try:
            if audio_file_path and audio_file_path.startswith('s3://'):
                # Extract bucket and key from S3 URL
                parsed = urllib.parse.urlparse(audio_file_path)
                bucket = parsed.netloc
                key = parsed.path.lstrip('/')
                
                return self._download_s3_file(key, 'audio.mp3', bucket)
            else:
                # Assume it's a local file path (for testing)
                return audio_file_path
                
        except Exception as e:
            logger.error(f"Error downloading audio: {str(e)}")
            return None
    
    def _download_s3_file(self, s3_key: str, local_filename: str, bucket: str = None) -> str:
        """Download a file from S3 to local temp directory"""
        try:
            bucket = bucket or self.bucket_name
            local_path = os.path.join(self.temp_dir, local_filename)
            
            s3_client.download_file(bucket, s3_key, local_path)
            logger.info(f"Downloaded {s3_key} to {local_path}")
            
            return local_path
            
        except Exception as e:
            logger.error(f"Error downloading {s3_key}: {str(e)}")
            return None
    
    def _generate_ken_burns_video(self, images: List[Dict[str, Any]], audio_file: str, manifest: Dict[str, Any]) -> str:
        """Generate Ken Burns video from images and audio"""
        try:
            # Create video clips for each segment
            video_clips = []
            total_duration = manifest.get('duration', 0)
            
            for segment in manifest.get('segments', []):
                segment_images = [img for img in images if img['segment_id'] == segment['id']]
                
                if segment_images:
                    # Create Ken Burns effect for this segment
                    segment_duration = segment['end_time'] - segment['start_time']
                    segment_clip = self._create_ken_burns_segment(segment_images, segment_duration)
                    
                    if segment_clip:
                        video_clips.append(segment_clip)
            
            if not video_clips:
                raise Exception("No video clips created")
            
            # Concatenate all clips
            final_video = concatenate_videoclips(video_clips)
            
            # Add audio if available
            if audio_file and os.path.exists(audio_file):
                audio_clip = AudioFileClip(audio_file)
                
                # Trim audio to match video duration
                if audio_clip.duration > final_video.duration:
                    audio_clip = audio_clip.subclip(0, final_video.duration)
                
                final_video = final_video.set_audio(audio_clip)
            
            # Set video properties
            final_video = final_video.set_fps(DEFAULT_FPS)
            
            # Resize to target resolution
            final_video = final_video.resize(DEFAULT_RESOLUTION)
            
            # Export video
            output_path = os.path.join(self.temp_dir, 'final_video.mp4')
            final_video.write_videofile(
                output_path,
                codec='libx264',
                audio_codec='aac',
                temp_audiofile=os.path.join(self.temp_dir, 'temp-audio.m4a'),
                remove_temp=True,
                verbose=False,
                logger=None
            )
            
            # Clean up video clips
            for clip in video_clips:
                clip.close()
            final_video.close()
            
            logger.info(f"Video generated successfully: {output_path}")
            return output_path
            
        except Exception as e:
            logger.error(f"Error generating video: {str(e)}")
            raise
    
    def _create_ken_burns_segment(self, images: List[Dict[str, Any]], duration: float) -> VideoClip:
        """Create Ken Burns effect for a segment with multiple images"""
        try:
            if not images:
                return None
            
            # Calculate timing for each image
            image_count = len(images)
            image_duration = duration / image_count
            
            clips = []
            
            for i, image_data in enumerate(images):
                image_path = image_data['path']
                
                if not os.path.exists(image_path):
                    continue
                
                # Load image
                image_clip = ImageClip(image_path)
                
                # Apply Ken Burns effect
                ken_burns_clip = self._apply_ken_burns_effect(image_clip, image_duration)
                
                clips.append(ken_burns_clip)
            
            if not clips:
                return None
            
            # Concatenate image clips
            segment_clip = concatenate_videoclips(clips)
            
            return segment_clip
            
        except Exception as e:
            logger.error(f"Error creating Ken Burns segment: {str(e)}")
            return None
    
    def _apply_ken_burns_effect(self, image_clip: ImageClip, duration: float) -> VideoClip:
        """Apply Ken Burns zoom and pan effect to an image"""
        try:
            # Resize image to be larger than target resolution for zoom effect
            target_size = DEFAULT_RESOLUTION
            zoom_factor = 1.3  # 30% larger for zoom effect
            
            # Calculate zoomed size
            zoomed_size = (
                int(target_size[0] * zoom_factor),
                int(target_size[1] * zoom_factor)
            )
            
            # Resize image
            resized_clip = image_clip.resize(zoomed_size)
            
            # Create zoom and pan effect
            def zoom_pan(t):
                # Calculate zoom level (start at 1.3, end at 1.0)
                zoom = 1.3 - (0.3 * t / duration)
                
                # Calculate pan position
                pan_x = 0.15 * (1 - t / duration)  # Move from 15% to 0%
                pan_y = 0.15 * (1 - t / duration)  # Move from 15% to 0%
                
                return zoom, pan_x, pan_y
            
            # Apply the effect
            def apply_effect(get_frame, t):
                zoom, pan_x, pan_y = zoom_pan(t)
                
                # Get the frame
                frame = get_frame(t)
                
                # Calculate crop region
                h, w = frame.shape[:2]
                crop_w = int(w / zoom)
                crop_h = int(h / zoom)
                
                # Calculate crop position
                start_x = int(pan_x * (w - crop_w))
                start_y = int(pan_y * (h - crop_h))
                
                # Crop the frame
                cropped = frame[start_y:start_y + crop_h, start_x:start_x + crop_w]
                
                # Resize to target resolution
                resized = cv2.resize(cropped, target_size)
                
                return resized
            
            # Create the effect clip
            effect_clip = resized_clip.fl(apply_effect)
            effect_clip = effect_clip.set_duration(duration)
            
            return effect_clip
            
        except Exception as e:
            logger.error(f"Error applying Ken Burns effect: {str(e)}")
            # Return original clip if effect fails
            return image_clip.set_duration(duration)
    
    def _generate_segment_video(self, images: List[Dict[str, Any]], duration: float) -> str:
        """Generate a single segment video from images"""
        try:
            if not images:
                raise Exception("No images provided for segment")
            
            # Calculate timing for each image
            image_count = len(images)
            image_duration = duration / image_count
            
            clips = []
            
            for i, image_data in enumerate(images):
                image_path = image_data['path']
                
                if not os.path.exists(image_path):
                    continue
                
                # Load image
                image_clip = ImageClip(image_path)
                
                # Apply Ken Burns effect
                ken_burns_clip = self._apply_ken_burns_effect(image_clip, image_duration)
                
                clips.append(ken_burns_clip)
            
            if not clips:
                raise Exception("No video clips created for segment")
            
            # Concatenate image clips
            segment_video = concatenate_videoclips(clips)
            
            # Set video properties
            segment_video = segment_video.set_fps(DEFAULT_FPS)
            segment_video = segment_video.resize(DEFAULT_RESOLUTION)
            
            # Export segment video
            output_path = os.path.join(self.temp_dir, 'segment_video.mp4')
            segment_video.write_videofile(
                output_path,
                codec='libx264',
                temp_audiofile=os.path.join(self.temp_dir, 'temp-segment-audio.m4a'),
                remove_temp=True,
                verbose=False,
                logger=None
            )
            
            # Clean up video clips
            for clip in clips:
                clip.close()
            segment_video.close()
            
            logger.info(f"Segment video generated successfully: {output_path}")
            return output_path
            
        except Exception as e:
            logger.error(f"Error generating segment video: {str(e)}")
            raise
    
    def _combine_segments_with_audio(self, segment_videos: List[str], audio_file: str) -> str:
        """Combine segment videos and add original audio"""
        try:
            # Load segment video clips
            video_clips = []
            for video_path in segment_videos:
                if os.path.exists(video_path):
                    clip = VideoFileClip(video_path)
                    video_clips.append(clip)
            
            if not video_clips:
                raise Exception("No valid segment videos found")
            
            # Concatenate all segments
            final_video = concatenate_videoclips(video_clips)
            
            # Add audio if available
            if audio_file and os.path.exists(audio_file):
                audio_clip = AudioFileClip(audio_file)
                
                # Trim audio to match video duration
                if audio_clip.duration > final_video.duration:
                    audio_clip = audio_clip.subclip(0, final_video.duration)
                
                final_video = final_video.set_audio(audio_clip)
            
            # Set video properties
            final_video = final_video.set_fps(DEFAULT_FPS)
            final_video = final_video.resize(DEFAULT_RESOLUTION)
            
            # Export final video
            output_path = os.path.join(self.temp_dir, 'final_video.mp4')
            final_video.write_videofile(
                output_path,
                codec='libx264',
                audio_codec='aac',
                temp_audiofile=os.path.join(self.temp_dir, 'temp-audio.m4a'),
                remove_temp=True,
                verbose=False,
                logger=None
            )
            
            # Clean up video clips
            for clip in video_clips:
                clip.close()
            final_video.close()
            
            logger.info(f"Final video with audio generated successfully: {output_path}")
            return output_path
            
        except Exception as e:
            logger.error(f"Error combining segments with audio: {str(e)}")
            raise
    
    def _upload_segment_video(self, s3_key: str, video_path: str) -> str:
        """Upload segment video to S3"""
        try:
            s3_client.upload_file(
                video_path,
                self.bucket_name,
                s3_key,
                ExtraArgs={
                    'ContentType': 'video/mp4',
                    'Metadata': {
                        'video_type': 'segment',
                        'generated_at': datetime.now().iso8601()
                    }
                }
            )
            
            video_url = f"s3://{self.bucket_name}/{s3_key}"
            logger.info(f"Segment video uploaded: {video_url}")
            
            return video_url
            
        except Exception as e:
            logger.error(f"Error uploading segment video: {str(e)}")
            raise
    
    def _upload_final_video(self, project_id: str, video_path: str) -> str:
        """Upload final video to S3"""
        try:
            s3_key = f"videos/{project_id}_final_video.mp4"
            
            s3_client.upload_file(
                video_path,
                self.bucket_name,
                s3_key,
                ExtraArgs={
                    'ContentType': 'video/mp4',
                    'Metadata': {
                        'project_id': project_id,
                        'generated_at': datetime.now().iso8601(),
                        'video_type': 'ken_burns'
                    }
                }
            )
            
            video_url = f"s3://{self.bucket_name}/{s3_key}"
            logger.info(f"Video uploaded: {video_url}")
            
            return video_url
            
        except Exception as e:
            logger.error(f"Error uploading video: {str(e)}")
            raise
    
    def _get_video_duration(self, video_path: str) -> float:
        """Get duration of video file"""
        try:
            clip = VideoFileClip(video_path)
            duration = clip.duration
            clip.close()
            return duration
        except Exception as e:
            logger.error(f"Error getting video duration: {str(e)}")
            return 0.0
    
    def _cleanup_temp_files(self):
        """Clean up temporary files"""
        try:
            for filename in os.listdir(self.temp_dir):
                if filename.startswith(('image_', 'audio.', 'temp-', 'final_video.')):
                    filepath = os.path.join(self.temp_dir, filename)
                    if os.path.exists(filepath):
                        os.remove(filepath)
                        logger.info(f"Cleaned up: {filename}")
        except Exception as e:
            logger.error(f"Error cleaning up temp files: {str(e)}")
    
    def _error_response(self, message: str) -> Dict[str, Any]:
        """Create error response"""
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': message,
                'timestamp': datetime.now().iso8601()
            })
        }

# Initialize the generator
generator = KenBurnsVideoGenerator()

# Lambda handler function
def lambda_handler(event, context):
    """AWS Lambda handler function"""
    return generator.lambda_handler(event, context) 