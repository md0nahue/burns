package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"os/exec"

	"github.com/aws/aws-lambda-go/lambda"
)

// LambdaEvent represents the incoming event
type LambdaEvent struct {
	ProjectID     string                   `json:"project_id"`
	SegmentID     string                   `json:"segment_id,omitempty"`
	SegmentIndex  int                      `json:"segment_index,omitempty"`
	Images        []map[string]interface{} `json:"images,omitempty"`
	Duration      float64                  `json:"duration,omitempty"`
	StartTime     float64                  `json:"start_time,omitempty"`
	EndTime       float64                  `json:"end_time,omitempty"`
	Options       map[string]interface{}   `json:"options,omitempty"`
	SegmentResults []map[string]interface{} `json:"segment_results,omitempty"`
}

// LambdaResponse represents the response
type LambdaResponse struct {
	StatusCode int                    `json:"statusCode"`
	Body       map[string]interface{} `json:"body"`
}

func handleRequest(ctx context.Context, event LambdaEvent) (LambdaResponse, error) {
	log.Printf("Processing event: %+v", event)

	// Create JSON input for the bash script
	eventJSON, err := json.Marshal(event)
	if err != nil {
		return LambdaResponse{
			StatusCode: 500,
			Body: map[string]interface{}{
				"error": "Failed to marshal event: " + err.Error(),
			},
		}, nil
	}

	// Execute the bash script
	cmd := exec.Command("./ken_burns_video_generator.sh")
	cmd.Env = append(os.Environ(), "LAMBDA_EVENT="+string(eventJSON))
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Bash script error: %s", string(output))
		return LambdaResponse{
			StatusCode: 500,
			Body: map[string]interface{}{
				"error": "Bash script execution failed: " + err.Error(),
				"output": string(output),
			},
		}, nil
	}

	// Parse the output as JSON
	var result map[string]interface{}
	if err := json.Unmarshal(output, &result); err != nil {
		log.Printf("Failed to parse output as JSON: %s", string(output))
		return LambdaResponse{
			StatusCode: 500,
			Body: map[string]interface{}{
				"error": "Failed to parse script output",
				"output": string(output),
			},
		}, nil
	}

	return LambdaResponse{
		StatusCode: 200,
		Body:       result,
	}, nil
}

func main() {
	lambda.Start(handleRequest)
}