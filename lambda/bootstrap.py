#!/usr/bin/python3
"""
Minimal Python bootstrap for Lambda custom runtime.
Reads events from Lambda Runtime API and passes them to bash script via stdin.
"""

import json
import os
import subprocess
import sys
import requests
import time

# Try to find Python interpreter
def find_python():
    python_paths = [
        '/usr/bin/python3',
        '/usr/bin/python',
        '/usr/local/bin/python3',
        '/usr/local/bin/python'
    ]
    
    for path in python_paths:
        if os.path.exists(path):
            return path
    
    # If none found, try to use sys.executable
    return sys.executable

# Debug: Print Python version and environment
print(f"🐍 Python version: {sys.version}", file=sys.stderr)
print(f"🐍 Python executable: {sys.executable}", file=sys.stderr)
print(f"📁 Current directory: {os.getcwd()}", file=sys.stderr)
print(f"📋 Environment variables: {dict(os.environ)}", file=sys.stderr)

# Lambda Runtime API endpoints
RUNTIME_API = os.environ.get('AWS_LAMBDA_RUNTIME_API')
BASE_URL = f"http://{RUNTIME_API}/2018-06-01/runtime"

def get_next_event():
    """Get the next event from Lambda Runtime API."""
    response = requests.get(f"{BASE_URL}/invocation/next")
    if response.status_code != 200:
        raise Exception(f"Failed to get next event: {response.status_code}")
    
    # Extract request ID and event data
    request_id = response.headers.get('Lambda-Runtime-Aws-Request-Id')
    event_data = response.json()
    
    return request_id, event_data

def send_response(request_id, response_data):
    """Send response back to Lambda Runtime API."""
    response_json = json.dumps(response_data)
    response = requests.post(
        f"{BASE_URL}/invocation/{request_id}/response",
        data=response_json,
        headers={'Content-Type': 'application/json'}
    )
    if response.status_code != 202:
        print(f"Warning: Failed to send response: {response.status_code}", file=sys.stderr)

def send_error(request_id, error_data):
    """Send error back to Lambda Runtime API."""
    error_json = json.dumps(error_data)
    response = requests.post(
        f"{BASE_URL}/invocation/{request_id}/error",
        data=error_json,
        headers={'Content-Type': 'application/json'}
    )
    if response.status_code != 202:
        print(f"Warning: Failed to send error: {response.status_code}", file=sys.stderr)

def main():
    """Main bootstrap function."""
    print("🚀 Starting Python bootstrap for Ken Burns video generator...", file=sys.stderr)
    
    while True:
        try:
            # Get next event from Lambda Runtime API
            request_id, event_data = get_next_event()
            print(f"📥 Received event for request: {request_id}", file=sys.stderr)
            
            # Convert event to JSON string
            event_json = json.dumps(event_data)
            
            # Call bash script with event via stdin
            print("🔄 Calling bash script...", file=sys.stderr)
            result = subprocess.run(
                ['./ken_burns_video_generator.sh'],
                input=event_json.encode('utf-8'),
                capture_output=True,
                text=True,
                cwd='/var/task'
            )
            
            # Check if bash script succeeded
            if result.returncode == 0:
                try:
                    # Parse bash script output as JSON
                    response_data = json.loads(result.stdout.strip())
                    print(f"✅ Bash script completed successfully", file=sys.stderr)
                    send_response(request_id, response_data)
                except json.JSONDecodeError as e:
                    print(f"❌ Failed to parse bash script output as JSON: {e}", file=sys.stderr)
                    print(f"Bash stdout: {result.stdout}", file=sys.stderr)
                    print(f"Bash stderr: {result.stderr}", file=sys.stderr)
                    send_error(request_id, {
                        "errorType": "RuntimeError",
                        "errorMessage": f"Bash script output is not valid JSON: {result.stdout}"
                    })
            else:
                print(f"❌ Bash script failed with return code: {result.returncode}", file=sys.stderr)
                print(f"Bash stdout: {result.stdout}", file=sys.stderr)
                print(f"Bash stderr: {result.stderr}", file=sys.stderr)
                send_error(request_id, {
                    "errorType": "RuntimeError",
                    "errorMessage": f"Bash script failed: {result.stderr}"
                })
                
        except Exception as e:
            print(f"❌ Bootstrap error: {e}", file=sys.stderr)
            # Try to send error if we have a request_id
            if 'request_id' in locals():
                send_error(request_id, {
                    "errorType": "RuntimeError",
                    "errorMessage": str(e)
                })
            time.sleep(1)  # Brief pause before retrying

if __name__ == "__main__":
    main() 