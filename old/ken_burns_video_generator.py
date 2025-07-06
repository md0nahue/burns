import json
import boto3
import os
import subprocess
import tempfile
import urllib.request
from datetime import datetime
import logging
from typing import Dict, List, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')

# Configuration
BUCKET_NAME = os.environ.get('S3_BUCKET', 'burns-videos')
TEMP_DIR = '/tmp'
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
            duration = event.get('duration', 5.0)
            
            logger.info(f"Processing segment {segment_id} for project {project_id}")
            
            # Download images for this segment
            segment_images = []
            for image_data in images:
                image_url = image_data.get('url')
                if image_url:
                    image_path = self._download_image(image_url, f"segment_{segment_id}_{len(segment_images)}.jpg")
                    if image_path:
                        segment_images.append(image_path)
            
            if not segment_images:
                return self._error_response(f"No images found for segment {segment_id}")
            
            # Generate segment video using ffmpeg
            segment_path = self._generate_segment_video_ffmpeg(segment_images, duration)
            
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
                    'generated_at': datetime.now().isoformat()
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
            
            # Combine segments and add audio using ffmpeg
            final_video_path = self._combine_segments_with_audio_ffmpeg(segment_videos, audio_file)
            
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
                    'generated_at': datetime.now().isoformat(),
                    'duration': self._get_video_duration_ffmpeg(final_video_path),
                    'resolution': f"{DEFAULT_RESOLUTION[0]}x{DEFAULT_RESOLUTION[1]}",
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
            
            # Generate Ken Burns video using ffmpeg
            video_path = self._generate_ken_burns_video_ffmpeg(images, audio_file, manifest)
            
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
                    'generated_at': datetime.now().isoformat(),
                    'duration': self._get_video_duration_ffmpeg(video_path),
                    'resolution': f"{DEFAULT_RESOLUTION[0]}x{DEFAULT_RESOLUTION[1]}",
                    'fps': DEFAULT_FPS
                })
            }
            
        except Exception as e:
            logger.error(f"Error in full video generation: {str(e)}")
            return self._error_response(f"Full video generation failed: {str(e)}")

    def _download_project_manifest(self, project_id: str) -> Dict[str, Any]:
        """Download project manifest from S3"""
        try:
            manifest_key = f"projects/{project_id}/manifest.json"
            response = s3_client.get_object(Bucket=self.bucket_name, Key=manifest_key)
            manifest_content = response['Body'].read().decode('utf-8')
            return json.loads(manifest_content)
        except Exception as e:
            logger.error(f"Error downloading manifest: {str(e)}")
            return None

    def _download_project_images(self, project_id: str, manifest: Dict[str, Any]) -> List[str]:
        """Download project images from S3"""
        images = []
        try:
            for segment in manifest.get('segments', []):
                for image_data in segment.get('generated_images', []):
                    image_url = image_data.get('url')
                    if image_url:
                        image_path = self._download_image(image_url, f"image_{len(images)}.jpg")
                        if image_path:
                            images.append(image_path)
        except Exception as e:
            logger.error(f"Error downloading images: {str(e)}")
        return images

    def _download_image(self, url: str, filename: str) -> str:
        """Download image from URL"""
        try:
            local_path = os.path.join(self.temp_dir, filename)
            urllib.request.urlretrieve(url, local_path)
            return local_path
        except Exception as e:
            logger.error(f"Error downloading image {url}: {str(e)}")
            return None

    def _download_audio_file(self, audio_s3_key: str) -> str:
        """Download audio file from S3"""
        try:
            if not audio_s3_key:
                return None
            local_path = os.path.join(self.temp_dir, f"audio{os.path.splitext(audio_s3_key)[1]}")
            s3_client.download_file(self.bucket_name, audio_s3_key, local_path)
            return local_path
        except Exception as e:
            logger.error(f"Error downloading audio file: {str(e)}")
            return None

    def _download_s3_file(self, s3_key: str, local_filename: str) -> str:
        """Download file from S3"""
        try:
            local_path = os.path.join(self.temp_dir, local_filename)
            s3_client.download_file(self.bucket_name, s3_key, local_path)
            return local_path
        except Exception as e:
            logger.error(f"Error downloading S3 file: {str(e)}")
            return None

    def _generate_segment_video_ffmpeg(self, image_paths: List[str], duration: float) -> str:
        """Generate segment video using ffmpeg"""
        if not image_paths:
            return None
        
        output_path = os.path.join(self.temp_dir, f"segment_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4")
        
        # Use first image and create Ken Burns effect
        input_image = image_paths[0]
        
        # Create Ken Burns effect: zoom from 1.3x to 1.0x
        filter_complex = (
            f"[0:v]scale={DEFAULT_RESOLUTION[0]}:{DEFAULT_RESOLUTION[1]}:force_original_aspect_ratio=decrease,"
            f"pad={DEFAULT_RESOLUTION[0]}:{DEFAULT_RESOLUTION[1]}:(ow-iw)/2:(oh-ih)/2,"
            f"zoompan=z='min(zoom+0.0015,1.5)':d={int(duration * DEFAULT_FPS)}:"
            f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={DEFAULT_RESOLUTION[0]}x{DEFAULT_RESOLUTION[1]}[v]"
        )
        
        cmd = [
            'ffmpeg',
            '-i', input_image,
            '-filter_complex', filter_complex,
            '-map', '[v]',
            '-t', str(duration),
            '-c:v', 'libx264',
            '-preset', 'fast',
            '-crf', '23',
            '-y',
            output_path
        ]
        
        logger.info(f"Running ffmpeg command: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"FFmpeg error: {result.stderr}")
            return None
        
        return output_path

    def _combine_segments_with_audio_ffmpeg(self, segment_videos: List[str], audio_file: str) -> str:
        """Combine segment videos with audio using ffmpeg"""
        if not segment_videos:
            return None
        
        # Create file list for concatenation
        file_list_path = os.path.join(self.temp_dir, "file_list.txt")
        with open(file_list_path, 'w') as f:
            for video_path in segment_videos:
                f.write(f"file '{video_path}'\n")
        
        # Combine videos
        combined_video_path = os.path.join(self.temp_dir, "combined_video.mp4")
        
        cmd = [
            'ffmpeg',
            '-f', 'concat',
            '-safe', '0',
            '-i', file_list_path,
            '-c', 'copy',
            '-y',
            combined_video_path
        ]
        
        logger.info(f"Running ffmpeg concat command: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"FFmpeg concat error: {result.stderr}")
            return None
        
        # Add audio if available
        if audio_file and os.path.exists(audio_file):
            final_video_path = os.path.join(self.temp_dir, "final_video.mp4")
            
            cmd = [
                'ffmpeg',
                '-i', combined_video_path,
                '-i', audio_file,
                '-c:v', 'copy',
                '-c:a', 'aac',
                '-shortest',
                '-y',
                final_video_path
            ]
            
            logger.info(f"Running ffmpeg audio command: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"FFmpeg audio error: {result.stderr}")
                return combined_video_path
            
            return final_video_path
        else:
            return combined_video_path

    def _generate_ken_burns_video_ffmpeg(self, images: List[str], audio_file: str, manifest: Dict[str, Any]) -> str:
        """Generate Ken Burns video using ffmpeg"""
        if not images:
            return None
        
        # Create a simple video with Ken Burns effect
        output_path = os.path.join(self.temp_dir, f"ken_burns_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4")
        
        # Use first image and create zoom effect
        input_image = images[0]
        duration = manifest.get('duration', 30.0)
        
        # Create Ken Burns effect
        filter_complex = (
            f"[0:v]scale={DEFAULT_RESOLUTION[0]}:{DEFAULT_RESOLUTION[1]}:force_original_aspect_ratio=decrease,"
            f"pad={DEFAULT_RESOLUTION[0]}:{DEFAULT_RESOLUTION[1]}:(ow-iw)/2:(oh-ih)/2,"
            f"zoompan=z='min(zoom+0.0015,1.5)':d={int(duration * DEFAULT_FPS)}:"
            f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={DEFAULT_RESOLUTION[0]}x{DEFAULT_RESOLUTION[1]}[v]"
        )
        
        cmd = [
            'ffmpeg',
            '-i', input_image,
            '-filter_complex', filter_complex,
            '-map', '[v]',
            '-t', str(duration),
            '-c:v', 'libx264',
            '-preset', 'fast',
            '-crf', '23',
            '-y',
            output_path
        ]
        
        logger.info(f"Running ffmpeg Ken Burns command: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            logger.error(f"FFmpeg Ken Burns error: {result.stderr}")
            return None
        
        # Add audio if available
        if audio_file and os.path.exists(audio_file):
            final_video_path = os.path.join(self.temp_dir, "final_with_audio.mp4")
            
            cmd = [
                'ffmpeg',
                '-i', output_path,
                '-i', audio_file,
                '-c:v', 'copy',
                '-c:a', 'aac',
                '-shortest',
                '-y',
                final_video_path
            ]
            
            logger.info(f"Running ffmpeg audio command: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"FFmpeg audio error: {result.stderr}")
                return output_path
            
            return final_video_path
        else:
            return output_path

    def _upload_segment_video(self, s3_key: str, video_path: str) -> str:
        """Upload segment video to S3"""
        try:
            s3_client.upload_file(video_path, self.bucket_name, s3_key)
            return f"s3://{self.bucket_name}/{s3_key}"
        except Exception as e:
            logger.error(f"Error uploading segment video: {str(e)}")
            return None

    def _upload_final_video(self, project_id: str, video_path: str) -> str:
        """Upload final video to S3"""
        try:
            s3_key = f"videos/{project_id}_final_video.mp4"
            s3_client.upload_file(video_path, self.bucket_name, s3_key)
            return f"s3://{self.bucket_name}/{s3_key}"
        except Exception as e:
            logger.error(f"Error uploading final video: {str(e)}")
            return None

    def _get_video_duration_ffmpeg(self, video_path: str) -> float:
        """Get video duration using ffmpeg"""
        try:
            cmd = [
                'ffprobe',
                '-v', 'quiet',
                '-show_entries', 'format=duration',
                '-of', 'csv=p=0',
                video_path
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                return float(result.stdout.strip())
            else:
                return 0.0
        except Exception as e:
            logger.error(f"Error getting video duration: {str(e)}")
            return 0.0

    def _cleanup_temp_files(self):
        """Clean up temporary files"""
        try:
            for filename in os.listdir(self.temp_dir):
                file_path = os.path.join(self.temp_dir, filename)
                if os.path.isfile(file_path):
                    os.unlink(file_path)
        except Exception as e:
            logger.error(f"Error cleaning up temp files: {str(e)}")

    def _error_response(self, message: str) -> Dict[str, Any]:
        """Create error response"""
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': message,
                'timestamp': datetime.now().isoformat()
            })
        }

# Lambda handler function
def lambda_handler(event, context):
    generator = KenBurnsVideoGenerator()
    return generator.lambda_handler(event, context) 