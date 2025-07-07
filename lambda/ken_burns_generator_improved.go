package main

import (
	"context"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

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
	SegmentIndex   int             `json:"segment_index"`
	Images         []Image         `json:"images"`
	Duration       float64         `json:"duration"`
	StartTime      float64         `json:"start_time"`
	EndTime        float64         `json:"end_time"`
	SegmentResults []SegmentResult `json:"segment_results"`
	Options        map[string]interface{} `json:"options"`
}

type Image struct {
	URL string `json:"url"`
}

type SegmentResult struct {
	SegmentID    string  `json:"segment_id"`
	SegmentS3Key string  `json:"segment_s3_key"`
	Duration     float64 `json:"duration"`
	StartTime    float64 `json:"start_time"`
	EndTime      float64 `json:"end_time"`
}

type AudioFile struct {
	S3Key string `json:"s3_key"`
}

// Response represents the Lambda response
type Response struct {
	StatusCode int         `json:"statusCode"`
	Body       interface{} `json:"body"`
}

func handleRequest(ctx context.Context, event Event) (Response, error) {
	fmt.Fprintf(os.Stderr, "🚀 Starting Enhanced Ken Burns video generator...\n")
	fmt.Fprintf(os.Stderr, "📥 Received event: ProjectID=%s, SegmentID=%s, Images=%d, Duration=%.2f\n", 
		event.ProjectID, event.SegmentID, len(event.Images), event.Duration)

	if event.ProjectID == "" {
		return Response{StatusCode: 400, Body: "project_id is required"}, fmt.Errorf("project_id is required")
	}

	// Check if this is segment processing or combination
	if event.SegmentID != "" && len(event.Images) > 0 {
		// Process single segment with multiple images and proper Ken Burns
		result, err := processSegmentEnhanced(event)
		if err != nil {
			fmt.Fprintf(os.Stderr, "❌ Failed to process segment: %v\n", err)
			return Response{StatusCode: 500, Body: err.Error()}, err
		}

		response := Response{
			StatusCode: 200,
			Body:       result,
		}

		fmt.Fprintf(os.Stderr, "✅ Enhanced segment %s completed\n", event.SegmentID)
		return response, nil
	} else if len(event.SegmentResults) > 0 {
		// Combine segments with audio
		result, err := combineSegmentsWithAudio(event)
		if err != nil {
			fmt.Fprintf(os.Stderr, "❌ Failed to combine segments: %v\n", err)
			return Response{StatusCode: 500, Body: err.Error()}, err
		}

		response := Response{
			StatusCode: 200,
			Body:       result,
		}

		fmt.Fprintf(os.Stderr, "✅ Enhanced video combination completed\n")
		return response, nil
	} else {
		return Response{StatusCode: 400, Body: "Invalid event format"}, fmt.Errorf("invalid event format")
	}
}

func processSegmentEnhanced(event Event) (map[string]interface{}, error) {
	fmt.Fprintf(os.Stderr, "🎬 Processing enhanced segment: %s with %d images\n", event.SegmentID, len(event.Images))

	// Use multiple images if available, otherwise repeat the first one
	imagesToUse := event.Images
	if len(imagesToUse) == 0 {
		return nil, fmt.Errorf("no images provided for segment %s", event.SegmentID)
	}

	// Calculate timing for each image
	imageCount := len(imagesToUse)
	timePerImage := event.Duration / float64(imageCount)
	
	// Ensure minimum time per image
	if timePerImage < 2.0 {
		// If we have too many images for the duration, use fewer images
		maxImages := int(event.Duration / 2.0)
		if maxImages < 1 {
			maxImages = 1
		}
		imagesToUse = imagesToUse[:min(maxImages, len(imagesToUse))]
		imageCount = len(imagesToUse)
		timePerImage = event.Duration / float64(imageCount)
	}

	fmt.Fprintf(os.Stderr, "📊 Using %d images, %.2f seconds each\n", imageCount, timePerImage)

	// Download all images
	imagePaths := make([]string, imageCount)
	for i, img := range imagesToUse {
		imagePath := filepath.Join(TempDir, fmt.Sprintf("segment_%s_image_%d.jpg", event.SegmentID, i))
		
		fmt.Fprintf(os.Stderr, "📥 Downloading image %d: %s\n", i+1, img.URL)
		if err := downloadFile(img.URL, imagePath); err != nil {
			fmt.Fprintf(os.Stderr, "⚠️  Failed to download image %d, using first image as fallback\n", i+1)
			if i == 0 {
				return nil, fmt.Errorf("failed to download any images: %v", err)
			}
			// Use the first image as fallback
			imagePath = imagePaths[0]
		}
		imagePaths[i] = imagePath
	}

	// Generate enhanced Ken Burns video with multiple images
	videoPath := filepath.Join(TempDir, fmt.Sprintf("segment_%s_video.mp4", event.SegmentID))

	fmt.Fprintf(os.Stderr, "🎥 Generating enhanced Ken Burns video...\n")
	if err := generateEnhancedKenBurnsVideo(imagePaths, videoPath, event.Duration, timePerImage); err != nil {
		return nil, fmt.Errorf("failed to generate enhanced video: %v", err)
	}

	// Upload to S3
	s3Key := fmt.Sprintf("segments/%s/%s_segment.mp4", event.ProjectID, event.SegmentID)

	fmt.Fprintf(os.Stderr, "📤 Uploading to S3: %s\n", s3Key)
	if err := uploadToS3(videoPath, s3Key); err != nil {
		return nil, fmt.Errorf("failed to upload to S3: %v", err)
	}

	// Clean up
	for _, imgPath := range imagePaths {
		os.Remove(imgPath)
	}
	os.Remove(videoPath)

	result := map[string]interface{}{
		"segment_id":     event.SegmentID,
		"segment_s3_key": s3Key,
		"duration":       event.Duration,
		"start_time":     event.StartTime,
		"end_time":       event.EndTime,
		"images_used":    imageCount,
	}

	fmt.Fprintf(os.Stderr, "✅ Enhanced segment %s completed\n", event.SegmentID)
	return result, nil
}

func generateEnhancedKenBurnsVideo(imagePaths []string, outputVideo string, totalDuration, timePerImage float64) error {
	imageCount := len(imagePaths)
	
	if imageCount == 1 {
		// Single image with smooth Ken Burns effect
		return generateSingleImageKenBurns(imagePaths[0], outputVideo, totalDuration)
	}

	// Multiple images with transitions
	fmt.Fprintf(os.Stderr, "🎬 Creating multi-image Ken Burns sequence\n")
	
	// Create filter complex for multiple images with Ken Burns and crossfades
	var filterParts []string
	var inputParts []string
	
	for _, imgPath := range imagePaths {
		inputParts = append(inputParts, "-loop", "1", "-t", fmt.Sprintf("%.2f", timePerImage), "-i", imgPath)
	}
	
	// Build filter chain for each image with Ken Burns effect
	for i := 0; i < imageCount; i++ {
		// Random Ken Burns parameters for variety
		rand.Seed(time.Now().UnixNano() + int64(i))
		
		startZoom := 1.0 + rand.Float64()*0.3 // 1.0 to 1.3
		endZoom := startZoom + 0.2 + rand.Float64()*0.3 // Smooth zoom
		
		startX := rand.Float64() * 0.1 // Small random offset
		startY := rand.Float64() * 0.1
		endX := startX + (rand.Float64()-0.5)*0.1 // Gentle pan
		endY := startY + (rand.Float64()-0.5)*0.1
		
		frameCount := int(timePerImage * DefaultFPS)
		
		kenBurnsFilter := fmt.Sprintf(
			"[%d:v]scale=2560:1440:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1," +
			"zoompan=z='%f+(%f-%f)*on/%d':x='iw*%f+(iw*(%f-%f))*on/%d':y='ih*%f+(ih*(%f-%f))*on/%d':" +
			"d=%d:s=1920x1080:fps=%d[v%d]",
			i, 
			startZoom, endZoom, startZoom, frameCount,
			startX, endX, startX, frameCount,
			startY, endY, startY, frameCount,
			frameCount, DefaultFPS, i)
		
		filterParts = append(filterParts, kenBurnsFilter)
	}
	
	// Concatenate all video streams
	var concatInputs []string
	for i := 0; i < imageCount; i++ {
		concatInputs = append(concatInputs, fmt.Sprintf("[v%d]", i))
	}
	
	concatFilter := fmt.Sprintf("%sconcat=n=%d:v=1:a=0[out]", 
		strings.Join(concatInputs, ""), imageCount)
	
	filterParts = append(filterParts, concatFilter)
	filterComplex := strings.Join(filterParts, ";")
	
	// Build ffmpeg command
	cmd := []string{"./ffmpeg"}
	cmd = append(cmd, inputParts...)
	cmd = append(cmd, 
		"-filter_complex", filterComplex,
		"-map", "[out]",
		"-c:v", "libx264",
		"-preset", "medium",
		"-crf", "20",
		"-r", strconv.Itoa(DefaultFPS),
		"-pix_fmt", "yuv420p",
		"-y", outputVideo)
	
	execCmd := exec.Command(cmd[0], cmd[1:]...)
	execCmd.Stderr = os.Stderr
	return execCmd.Run()
}

func generateSingleImageKenBurns(imagePath, outputVideo string, duration float64) error {
	// Enhanced single image Ken Burns with smooth movement
	frameCount := int(duration * DefaultFPS)
	
	// Random Ken Burns parameters for variety
	rand.Seed(time.Now().UnixNano())
	
	startZoom := 1.0 + rand.Float64()*0.2 // 1.0 to 1.2
	endZoom := startZoom + 0.3 + rand.Float64()*0.2 // Smooth zoom
	
	// Ensure we don't go too extreme
	if endZoom > 1.8 {
		endZoom = 1.8
	}
	
	startX := rand.Float64() * 0.1
	startY := rand.Float64() * 0.1
	endX := startX + (rand.Float64()-0.5)*0.15
	endY := startY + (rand.Float64()-0.5)*0.15
	
	filterComplex := fmt.Sprintf(
		"scale=2560:1440:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1," +
		"zoompan=z='%f+(%f-%f)*on/%d':x='iw*%f+(iw*(%f-%f))*on/%d':y='ih*%f+(ih*(%f-%f))*on/%d':" +
		"d=%d:s=1920x1080:fps=%d",
		startZoom, endZoom, startZoom, frameCount,
		startX, endX, startX, frameCount,
		startY, endY, startY, frameCount,
		frameCount, DefaultFPS)

	cmd := exec.Command("./ffmpeg",
		"-loop", "1",
		"-i", imagePath,
		"-filter_complex", filterComplex,
		"-t", strconv.FormatFloat(duration, 'f', 2, 64),
		"-c:v", "libx264",
		"-preset", "medium",
		"-crf", "20",
		"-r", strconv.Itoa(DefaultFPS),
		"-pix_fmt", "yuv420p",
		"-y", outputVideo,
	)

	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func combineSegmentsWithAudio(event Event) (map[string]interface{}, error) {
	fmt.Fprintf(os.Stderr, "🎬 Combining segments with audio for project: %s\n", event.ProjectID)

	// Download audio file first
	audioS3Key := fmt.Sprintf("projects/%s/audio/%s.mp3", event.ProjectID, event.ProjectID)
	audioPath := filepath.Join(TempDir, "audio.mp3")
	
	fmt.Fprintf(os.Stderr, "📥 Downloading audio: %s\n", audioS3Key)
	if err := downloadFromS3(audioS3Key, audioPath); err != nil {
		fmt.Fprintf(os.Stderr, "⚠️  Warning: Failed to download audio: %v\n", err)
		audioPath = "" // Continue without audio
	}
	defer os.Remove(audioPath)

	// Create video list file with proper ordering
	videoListPath := filepath.Join(TempDir, "video_list.txt")
	videoListFile, err := os.Create(videoListPath)
	if err != nil {
		return nil, fmt.Errorf("failed to create video list file: %v", err)
	}
	defer os.Remove(videoListPath)

	// Sort segments by start time to ensure proper order
	sortedSegments := make([]SegmentResult, len(event.SegmentResults))
	copy(sortedSegments, event.SegmentResults)
	
	// Simple sort by segment ID (which should be in order)
	for i := 0; i < len(sortedSegments)-1; i++ {
		for j := i + 1; j < len(sortedSegments); j++ {
			iVal, _ := strconv.Atoi(sortedSegments[i].SegmentID)
			jVal, _ := strconv.Atoi(sortedSegments[j].SegmentID)
			if iVal > jVal {
				sortedSegments[i], sortedSegments[j] = sortedSegments[j], sortedSegments[i]
			}
		}
	}

	// Download segment videos and add to list
	downloadedCount := 0
	for _, segment := range sortedSegments {
		localVideoPath := filepath.Join(TempDir, fmt.Sprintf("segment_%s.mp4", segment.SegmentID))

		fmt.Fprintf(os.Stderr, "📥 Downloading segment video %s: %s\n", segment.SegmentID, segment.SegmentS3Key)
		if err := downloadFromS3(segment.SegmentS3Key, localVideoPath); err != nil {
			fmt.Fprintf(os.Stderr, "⚠️  Warning: Failed to download segment %s: %v\n", segment.SegmentID, err)
			continue
		}

		fmt.Fprintf(videoListFile, "file '%s'\n", localVideoPath)
		downloadedCount++
	}
	videoListFile.Close()

	if downloadedCount == 0 {
		return nil, fmt.Errorf("no video segments could be downloaded")
	}

	fmt.Fprintf(os.Stderr, "✅ Downloaded %d/%d video segments\n", downloadedCount, len(sortedSegments))

	// Combine videos with consistent encoding
	tempVideoPath := filepath.Join(TempDir, "combined_video_no_audio.mp4")
	
	fmt.Fprintf(os.Stderr, "🎬 Combining videos with consistent encoding...\n")
	if err := combineVideosEnhanced(videoListPath, tempVideoPath); err != nil {
		return nil, fmt.Errorf("failed to combine videos: %v", err)
	}
	defer os.Remove(tempVideoPath)

	// Final video path
	finalVideoPath := filepath.Join(TempDir, "final_video_with_audio.mp4")
	
	// Add audio track if available
	if audioPath != "" && fileExists(audioPath) {
		fmt.Fprintf(os.Stderr, "🎵 Adding audio track...\n")
		if err := addAudioToVideo(tempVideoPath, audioPath, finalVideoPath); err != nil {
			fmt.Fprintf(os.Stderr, "⚠️  Warning: Failed to add audio, using video without audio: %v\n", err)
			finalVideoPath = tempVideoPath
		}
	} else {
		fmt.Fprintf(os.Stderr, "⚠️  No audio available, creating video without audio\n")
		finalVideoPath = tempVideoPath
	}
	defer os.Remove(finalVideoPath)

	// Upload final video
	finalS3Key := fmt.Sprintf("videos/%s_final_video.mp4", event.ProjectID)

	fmt.Fprintf(os.Stderr, "📤 Uploading final video: %s\n", finalS3Key)
	if err := uploadToS3(finalVideoPath, finalS3Key); err != nil {
		return nil, fmt.Errorf("failed to upload final video: %v", err)
	}

	// Get video duration and properties
	duration, err := getVideoDuration(finalVideoPath)
	if err != nil {
		duration = 0
	}

	result := map[string]interface{}{
		"video_s3_key":      finalS3Key,
		"duration":          duration,
		"resolution":        DefaultResolution,
		"fps":               DefaultFPS,
		"segments_combined": downloadedCount,
		"has_audio":         audioPath != "",
	}

	fmt.Fprintf(os.Stderr, "✅ Enhanced video combination completed\n")
	return result, nil
}

func combineVideosEnhanced(videoListPath, outputVideo string) error {
	// Use re-encoding to ensure consistency
	cmd := exec.Command("./ffmpeg",
		"-f", "concat",
		"-safe", "0",
		"-i", videoListPath,
		"-c:v", "libx264",
		"-preset", "medium",
		"-crf", "20",
		"-r", strconv.Itoa(DefaultFPS),
		"-pix_fmt", "yuv420p",
		"-movflags", "+faststart",
		"-y", outputVideo,
	)

	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func addAudioToVideo(videoPath, audioPath, outputPath string) error {
	cmd := exec.Command("./ffmpeg",
		"-i", videoPath,
		"-i", audioPath,
		"-c:v", "copy",
		"-c:a", "aac",
		"-b:a", "128k",
		"-shortest",
		"-movflags", "+faststart",
		"-y", outputPath,
	)

	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Rest of the functions remain the same...
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

	sess, err := session.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create AWS session: %v", err)
	}

	s3Client := s3.New(sess)

	file, err := os.Open(localPath)
	if err != nil {
		return fmt.Errorf("failed to open file: %v", err)
	}
	defer file.Close()

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

	sess, err := session.NewSession()
	if err != nil {
		return fmt.Errorf("failed to create AWS session: %v", err)
	}

	s3Client := s3.New(sess)

	result, err := s3Client.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(s3Key),
	})
	if err != nil {
		return fmt.Errorf("failed to download from S3: %v", err)
	}
	defer result.Body.Close()

	file, err := os.Create(localPath)
	if err != nil {
		return fmt.Errorf("failed to create local file: %v", err)
	}
	defer file.Close()

	_, err = io.Copy(file, result.Body)
	if err != nil {
		return fmt.Errorf("failed to copy data: %v", err)
	}

	return nil
}

func main() {
	lambda.Start(handleRequest)
}