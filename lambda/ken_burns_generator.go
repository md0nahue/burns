package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

// Configuration
const (
	DefaultFPS        = 24
	DefaultResolution = "1920x1080"
	TempDir           = "/tmp"
)

// Event represents the Lambda event
type Event struct {
	ProjectID      string          `json:"project_id"`
	SegmentID      string          `json:"segment_id"`
	Images         []Image         `json:"images"`
	Duration       float64         `json:"duration"`
	SegmentResults []SegmentResult `json:"segment_results"`
}

type Image struct {
	URL string `json:"url"`
}

type SegmentResult struct {
	SegmentID    string  `json:"segment_id"`
	SegmentS3Key string  `json:"segment_s3_key"`
	Duration     float64 `json:"duration"`
}

// Response represents the Lambda response
type Response struct {
	StatusCode int         `json:"statusCode"`
	Body       interface{} `json:"body"`
}

func handleRequest(ctx context.Context, event Event) (Response, error) {
	fmt.Fprintf(os.Stderr, "🚀 Starting Go Ken Burns video generator...\n")
	fmt.Fprintf(os.Stderr, "📥 Received event: %+v\n", event)

	if event.ProjectID == "" {
		return Response{StatusCode: 400, Body: "project_id is required"}, fmt.Errorf("project_id is required")
	}

	// Check if this is segment processing or combination
	if event.SegmentID != "" && len(event.Images) > 0 {
		// Process single segment
		result, err := processSegment(event)
		if err != nil {
			fmt.Fprintf(os.Stderr, "❌ Failed to process segment: %v\n", err)
			return Response{StatusCode: 500, Body: err.Error()}, err
		}

		response := Response{
			StatusCode: 200,
			Body:       result,
		}

		fmt.Fprintf(os.Stderr, "✅ Segment %s completed\n", event.SegmentID)
		return response, nil
	} else if len(event.SegmentResults) > 0 {
		// Combine segments
		result, err := combineSegments(event)
		if err != nil {
			fmt.Fprintf(os.Stderr, "❌ Failed to combine segments: %v\n", err)
			return Response{StatusCode: 500, Body: err.Error()}, err
		}

		response := Response{
			StatusCode: 200,
			Body:       result,
		}

		fmt.Fprintf(os.Stderr, "✅ Video combination completed\n")
		return response, nil
	} else {
		return Response{StatusCode: 400, Body: "Invalid event format"}, fmt.Errorf("invalid event format")
	}
}

func processSegment(event Event) (map[string]interface{}, error) {
	fmt.Fprintf(os.Stderr, "🎬 Processing segment: %s\n", event.SegmentID)

	// Download first image
	imageURL := event.Images[0].URL
	imagePath := filepath.Join(TempDir, fmt.Sprintf("segment_%s_image.jpg", event.SegmentID))

	fmt.Fprintf(os.Stderr, "📥 Downloading image: %s\n", imageURL)
	if err := downloadFile(imageURL, imagePath); err != nil {
		return nil, fmt.Errorf("failed to download image: %v", err)
	}

	// Generate Ken Burns video
	videoPath := filepath.Join(TempDir, fmt.Sprintf("segment_%s_video.mp4", event.SegmentID))

	fmt.Fprintf(os.Stderr, "🎥 Generating Ken Burns video...\n")
	if err := generateKenBurnsVideo(imagePath, videoPath, event.Duration); err != nil {
		return nil, fmt.Errorf("failed to generate video: %v", err)
	}

	// Upload to S3
	s3Key := fmt.Sprintf("segments/%s/%s_segment.mp4", event.ProjectID, event.SegmentID)

	fmt.Fprintf(os.Stderr, "📤 Uploading to S3: %s\n", s3Key)
	if err := uploadToS3(videoPath, s3Key); err != nil {
		return nil, fmt.Errorf("failed to upload to S3: %v", err)
	}

	// Clean up
	os.Remove(imagePath)
	os.Remove(videoPath)

	result := map[string]interface{}{
		"segment_id":     event.SegmentID,
		"segment_s3_key": s3Key,
		"duration":       event.Duration,
	}

	fmt.Fprintf(os.Stderr, "✅ Segment %s completed\n", event.SegmentID)
	return result, nil
}

func combineSegments(event Event) (map[string]interface{}, error) {
	fmt.Fprintf(os.Stderr, "🎬 Combining segments for project: %s\n", event.ProjectID)

	// Create video list file
	videoListPath := filepath.Join(TempDir, "video_list.txt")
	videoListFile, err := os.Create(videoListPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create video list file: %v", err)
	}
	defer os.Remove(videoListPath)

	// Download segment videos and add to list
	for _, segment := range event.SegmentResults {
		localVideoPath := filepath.Join(TempDir, fmt.Sprintf("segment_%s.mp4", segment.SegmentID))

		fmt.Fprintf(os.Stderr, "📥 Downloading segment video: %s\n", segment.SegmentS3Key)
		if err := downloadFromS3(segment.SegmentS3Key, localVideoPath); err != nil {
			fmt.Fprintf(os.Stderr, "⚠️  Warning: Failed to download segment %s: %v\n", segment.SegmentID, err)
			continue
		}

		fmt.Fprintf(videoListFile, "file '%s'\n", localVideoPath)
	}
	videoListFile.Close()

	// Combine videos
	combinedVideoPath := filepath.Join(TempDir, "combined_video.mp4")

	fmt.Fprintf(os.Stderr, "🎬 Combining videos...\n")
	if err := combineVideos(videoListPath, combinedVideoPath); err != nil {
		return nil, fmt.Errorf("failed to combine videos: %v", err)
	}

	// Upload final video
	finalS3Key := fmt.Sprintf("videos/%s_final_video.mp4", event.ProjectID)

	fmt.Fprintf(os.Stderr, "📤 Uploading final video: %s\n", finalS3Key)
	if err := uploadToS3(combinedVideoPath, finalS3Key); err != nil {
		return nil, fmt.Errorf("failed to upload final video: %v", err)
	}

	// Get video duration
	duration, err := getVideoDuration(combinedVideoPath)
	if err != nil {
		duration = 0
	}

	// Clean up
	os.Remove(combinedVideoPath)

	result := map[string]interface{}{
		"video_s3_key": finalS3Key,
		"duration":     duration,
		"resolution":   DefaultResolution,
		"fps":          DefaultFPS,
	}

	fmt.Fprintf(os.Stderr, "✅ Video combination completed\n")
	return result, nil
}

func downloadFile(url, localPath string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, url)
	}

	file, err := os.Create(localPath)
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, resp.Body)
	return err
}

func generateKenBurnsVideo(inputImage, outputVideo string, duration float64) error {
	// Ken Burns effect: zoom from 1.3x to 1.0x over the duration
	frameCount := int(duration * DefaultFPS)

	// Create Ken Burns zoom effect
	filterComplex := fmt.Sprintf(
		"scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,"+
			"zoompan=z='min(zoom+0.0015,1.5)':d=%d:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1920x1080",
		frameCount,
	)

	cmd := exec.Command("./ffmpeg",
		"-i", inputImage,
		"-filter_complex", filterComplex,
		"-t", strconv.FormatFloat(duration, 'f', 2, 64),
		"-c:v", "libx264",
		"-preset", "fast",
		"-crf", "23",
		"-y", outputVideo,
	)

	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func combineVideos(videoListPath, outputVideo string) error {
	cmd := exec.Command("./ffmpeg",
		"-f", "concat",
		"-safe", "0",
		"-i", videoListPath,
		"-c", "copy",
		"-y", outputVideo,
	)

	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func getVideoDuration(videoPath string) (float64, error) {
	cmd := exec.Command("./ffprobe",
		"-v", "quiet",
		"-show_entries", "format=duration",
		"-of", "csv=p=0",
		videoPath,
	)

	output, err := cmd.Output()
	if err != nil {
		return 0, err
	}

	duration, err := strconv.ParseFloat(strings.TrimSpace(string(output)), 64)
	if err != nil {
		return 0, err
	}

	return duration, nil
}

func uploadToS3(localPath, s3Key string) error {
	bucket := os.Getenv("S3_BUCKET")
	if bucket == "" {
		bucket = "burns-videos"
	}

	// Create AWS session
	sess, err := session.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create AWS session: %v", err)
	}

	// Create S3 client
	s3Client := s3.New(sess)

	// Open the file
	file, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("failed to open file: %v", err)
	}
	defer file.Close()

	// Upload to S3
	_, err = s3Client.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(s3Key),
		Body:   file,
	})

	if err != nil {
		return fmt.Errorf("failed to upload to S3: %v", err)
	}

	return nil
}

func downloadFromS3(s3Key, localPath string) error {
	bucket := os.Getenv("S3_BUCKET")
	if bucket == "" {
		bucket = "burns-videos"
	}

	// Create AWS session
	sess, err := session.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create AWS session: %v", err)
	}

	// Create S3 client
	s3Client := s3.New(sess)

	// Download from S3
	result, err := s3Client.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(s3Key),
	})
	if err != nil {
		return fmt.Errorf("failed to download from S3: %v", err)
	}
	defer result.Body.Close()

	// Create local file
	file, err := os.Create(localPath)
	if err != nil {
		return fmt.Errorf("failed to create local file: %v", err)
	}
	defer file.Close()

	// Copy data
	_, err = io.Copy(file, result.Body)
	if err != nil {
		return fmt.Errorf("failed to copy data: %v", err)
	}

	return nil
}

func main() {
	lambda.Start(handleRequest)
}
