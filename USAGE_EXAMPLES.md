# Usage Examples

Complete examples for using the Document Processing API.

---

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Python Client](#python-client)
3. [JavaScript Client](#javascript-client)
4. [cURL Examples](#curl-examples)
5. [Batch Processing](#batch-processing)
6. [Error Handling](#error-handling)
7. [Integration Examples](#integration-examples)

---

## Basic Usage

### 1. Upload a Document

```bash
curl -X POST http://YOUR-API-ENDPOINT/upload \
  -F "file=@document.pdf" \
  -F "notification_email=user@example.com"
```

**Response:**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "File uploaded successfully. Processing will begin shortly.",
  "s3_key": "uploads/550e8400-e29b-41d4-a716-446655440000/document.pdf",
  "file_size": 1048576,
  "file_type": "application/pdf"
}
```

### 2. Check Status

```bash
curl http://YOUR-API-ENDPOINT/status/550e8400-e29b-41d4-a716-446655440000
```

**Response:**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "processing",
  "created_at": "2024-01-01T10:00:00Z",
  "updated_at": "2024-01-01T10:00:30Z",
  "progress": 60,
  "message": "Analyzing image"
}
```

### 3. Get Results

```bash
curl http://YOUR-API-ENDPOINT/results/550e8400-e29b-41d4-a716-446655440000
```

**Response:**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "original_file": "document.pdf",
  "file_type": "application/pdf",
  "file_size": 1048576,
  "results": {
    "ocr_text": "This is the extracted text from the document...",
    "thumbnail_url": "https://s3.amazonaws.com/...",
    "metadata": {
      "file_size": 1048576,
      "file_type": "application/pdf",
      "page_count": 5,
      "extracted_at": "2024-01-01T10:01:00Z"
    },
    "labels": [],
    "moderation": null
  },
  "created_at": "2024-01-01T10:00:00Z",
  "completed_at": "2024-01-01T10:01:00Z"
}
```

---

## Python Client

### Installation

```bash
pip install requests
```

### Complete Client Class

```python
import requests
import time
from typing import Optional, Dict, Any
from pathlib import Path


class DocumentProcessorClient:
    """Client for the Document Processing API."""
    
    def __init__(self, api_url: str):
        """
        Initialize the client.
        
        Args:
            api_url: Base URL of the API (e.g., http://api.example.com)
        """
        self.api_url = api_url.rstrip('/')
        self.session = requests.Session()
    
    def upload_file(
        self, 
        file_path: str, 
        notification_email: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Upload a file for processing.
        
        Args:
            file_path: Path to the file to upload
            notification_email: Optional email for notifications
            
        Returns:
            Dictionary with job_id and upload details
            
        Raises:
            requests.HTTPError: If upload fails
        """
        url = f"{self.api_url}/upload"
        
        with open(file_path, 'rb') as f:
            files = {'file': f}
            data = {}
            if notification_email:
                data['notification_email'] = notification_email
            
            response = self.session.post(url, files=files, data=data)
            response.raise_for_status()
            
        return response.json()
    
    def get_status(self, job_id: str) -> Dict[str, Any]:
        """
        Get the status of a processing job.
        
        Args:
            job_id: The job identifier
            
        Returns:
            Dictionary with job status
        """
        url = f"{self.api_url}/status/{job_id}"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()
    
    def get_results(self, job_id: str) -> Dict[str, Any]:
        """
        Get the results of a completed job.
        
        Args:
            job_id: The job identifier
            
        Returns:
            Dictionary with processing results
        """
        url = f"{self.api_url}/results/{job_id}"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()
    
    def delete_job(self, job_id: str) -> Dict[str, Any]:
        """
        Delete a job and its associated files.
        
        Args:
            job_id: The job identifier
            
        Returns:
            Dictionary with deletion confirmation
        """
        url = f"{self.api_url}/jobs/{job_id}"
        response = self.session.delete(url)
        response.raise_for_status()
        return response.json()
    
    def wait_for_completion(
        self, 
        job_id: str, 
        timeout: int = 300,
        poll_interval: int = 5
    ) -> Dict[str, Any]:
        """
        Wait for a job to complete.
        
        Args:
            job_id: The job identifier
            timeout: Maximum time to wait in seconds
            poll_interval: Time between status checks in seconds
            
        Returns:
            Dictionary with final results
            
        Raises:
            TimeoutError: If job doesn't complete within timeout
            RuntimeError: If job fails
        """
        start_time = time.time()
        
        while True:
            if time.time() - start_time > timeout:
                raise TimeoutError(f"Job {job_id} did not complete within {timeout}s")
            
            status = self.get_status(job_id)
            
            if status['status'] == 'completed':
                return self.get_results(job_id)
            elif status['status'] == 'failed':
                raise RuntimeError(f"Job {job_id} failed: {status.get('message')}")
            
            time.sleep(poll_interval)
    
    def process_file(
        self, 
        file_path: str,
        notification_email: Optional[str] = None,
        wait: bool = True,
        timeout: int = 300
    ) -> Dict[str, Any]:
        """
        Upload and process a file (convenience method).
        
        Args:
            file_path: Path to the file
            notification_email: Optional email for notifications
            wait: Whether to wait for completion
            timeout: Maximum time to wait if wait=True
            
        Returns:
            Dictionary with results if wait=True, else upload response
        """
        # Upload file
        upload_response = self.upload_file(file_path, notification_email)
        job_id = upload_response['job_id']
        
        print(f"Uploaded file. Job ID: {job_id}")
        
        if wait:
            print("Waiting for processing to complete...")
            results = self.wait_for_completion(job_id, timeout)
            print("Processing completed!")
            return results
        
        return upload_response


# Usage Examples
if __name__ == "__main__":
    # Initialize client
    client = DocumentProcessorClient("http://your-api-endpoint")
    
    # Example 1: Simple upload and wait
    results = client.process_file("document.pdf", wait=True)
    print(f"OCR Text: {results['results']['ocr_text'][:100]}...")
    
    # Example 2: Upload without waiting
    upload_response = client.upload_file("image.jpg", "user@example.com")
    job_id = upload_response['job_id']
    
    # Check status later
    status = client.get_status(job_id)
    print(f"Status: {status['status']}")
    
    # Get results when ready
    if status['status'] == 'completed':
        results = client.get_results(job_id)
        print(f"Labels: {results['results']['labels']}")
    
    # Example 3: Batch processing
    files = ["doc1.pdf", "doc2.pdf", "image1.jpg"]
    job_ids = []
    
    for file_path in files:
        response = client.upload_file(file_path)
        job_ids.append(response['job_id'])
    
    # Wait for all to complete
    for job_id in job_ids:
        try:
            results = client.wait_for_completion(job_id)
            print(f"Job {job_id}: Success")
        except Exception as e:
            print(f"Job {job_id}: Failed - {e}")
```

### Simple Example

```python
from document_processor_client import DocumentProcessorClient

# Initialize
client = DocumentProcessorClient("http://your-api-endpoint")

# Process a file
results = client.process_file("document.pdf", wait=True)

# Access results
print(f"OCR Text: {results['results']['ocr_text']}")
print(f"Thumbnail: {results['results']['thumbnail_url']}")
print(f"Metadata: {results['results']['metadata']}")
```

---

## JavaScript Client

### Node.js Client

```javascript
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

class DocumentProcessorClient {
  constructor(apiUrl) {
    this.apiUrl = apiUrl.replace(/\/$/, '');
    this.client = axios.create({
      baseURL: this.apiUrl,
      timeout: 30000,
    });
  }

  async uploadFile(filePath, notificationEmail = null) {
    const form = new FormData();
    form.append('file', fs.createReadStream(filePath));
    
    if (notificationEmail) {
      form.append('notification_email', notificationEmail);
    }

    const response = await this.client.post('/upload', form, {
      headers: form.getHeaders(),
    });

    return response.data;
  }

  async getStatus(jobId) {
    const response = await this.client.get(`/status/${jobId}`);
    return response.data;
  }

  async getResults(jobId) {
    const response = await this.client.get(`/results/${jobId}`);
    return response.data;
  }

  async deleteJob(jobId) {
    const response = await this.client.delete(`/jobs/${jobId}`);
    return response.data;
  }

  async waitForCompletion(jobId, timeout = 300000, pollInterval = 5000) {
    const startTime = Date.now();

    while (true) {
      if (Date.now() - startTime > timeout) {
        throw new Error(`Job ${jobId} did not complete within ${timeout}ms`);
      }

      const status = await this.getStatus(jobId);

      if (status.status === 'completed') {
        return await this.getResults(jobId);
      } else if (status.status === 'failed') {
        throw new Error(`Job ${jobId} failed: ${status.message}`);
      }

      await new Promise(resolve => setTimeout(resolve, pollInterval));
    }
  }

  async processFile(filePath, notificationEmail = null, wait = true, timeout = 300000) {
    const uploadResponse = await this.uploadFile(filePath, notificationEmail);
    const jobId = uploadResponse.job_id;

    console.log(`Uploaded file. Job ID: ${jobId}`);

    if (wait) {
      console.log('Waiting for processing to complete...');
      const results = await this.waitForCompletion(jobId, timeout);
      console.log('Processing completed!');
      return results;
    }

    return uploadResponse;
  }
}

// Usage
(async () => {
  const client = new DocumentProcessorClient('http://your-api-endpoint');

  try {
    // Process a file
    const results = await client.processFile('document.pdf', 'user@example.com');
    console.log('OCR Text:', results.results.ocr_text.substring(0, 100));
    console.log('Thumbnail:', results.results.thumbnail_url);
  } catch (error) {
    console.error('Error:', error.message);
  }
})();
```

### Browser JavaScript

```javascript
class DocumentProcessorClient {
  constructor(apiUrl) {
    this.apiUrl = apiUrl.replace(/\/$/, '');
  }

  async uploadFile(file, notificationEmail = null) {
    const formData = new FormData();
    formData.append('file', file);
    
    if (notificationEmail) {
      formData.append('notification_email', notificationEmail);
    }

    const response = await fetch(`${this.apiUrl}/upload`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`Upload failed: ${response.statusText}`);
    }

    return await response.json();
  }

  async getStatus(jobId) {
    const response = await fetch(`${this.apiUrl}/status/${jobId}`);
    
    if (!response.ok) {
      throw new Error(`Status check failed: ${response.statusText}`);
    }

    return await response.json();
  }

  async getResults(jobId) {
    const response = await fetch(`${this.apiUrl}/results/${jobId}`);
    
    if (!response.ok) {
      throw new Error(`Get results failed: ${response.statusText}`);
    }

    return await response.json();
  }
}

// Usage in HTML
/*
<input type="file" id="fileInput">
<button onclick="uploadFile()">Upload</button>
<div id="status"></div>
<div id="results"></div>

<script>
const client = new DocumentProcessorClient('http://your-api-endpoint');

async function uploadFile() {
  const fileInput = document.getElementById('fileInput');
  const file = fileInput.files[0];
  
  if (!file) {
    alert('Please select a file');
    return;
  }

  try {
    const uploadResponse = await client.uploadFile(file, 'user@example.com');
    const jobId = uploadResponse.job_id;
    
    document.getElementById('status').textContent = 'Processing...';
    
    // Poll for completion
    const checkStatus = setInterval(async () => {
      const status = await client.getStatus(jobId);
      
      if (status.status === 'completed') {
        clearInterval(checkStatus);
        const results = await client.getResults(jobId);
        displayResults(results);
      } else if (status.status === 'failed') {
        clearInterval(checkStatus);
        document.getElementById('status').textContent = 'Processing failed';
      } else {
        document.getElementById('status').textContent = 
          `Status: ${status.status} (${status.progress}%)`;
      }
    }, 5000);
  } catch (error) {
    alert('Error: ' + error.message);
  }
}

function displayResults(results) {
  const resultsDiv = document.getElementById('results');
  resultsDiv.innerHTML = `
    <h3>Results</h3>
    <p><strong>Status:</strong> ${results.status}</p>
    <p><strong>OCR Text:</strong> ${results.results.ocr_text?.substring(0, 200)}...</p>
    <img src="${results.results.thumbnail_url}" alt="Thumbnail">
  `;
}
</script>
*/
```

---

## cURL Examples

### Upload Different File Types

```bash
# PDF Document
curl -X POST http://API_URL/upload \
  -F "file=@document.pdf" \
  -F "notification_email=user@example.com"

# Image
curl -X POST http://API_URL/upload \
  -F "file=@photo.jpg"

# Video
curl -X POST http://API_URL/upload \
  -F "file=@video.mp4"
```

### Check Status with Pretty Print

```bash
curl -s http://API_URL/status/JOB_ID | jq .
```

### Get Results and Extract Specific Fields

```bash
# Get OCR text only
curl -s http://API_URL/results/JOB_ID | jq -r '.results.ocr_text'

# Get thumbnail URL
curl -s http://API_URL/results/JOB_ID | jq -r '.results.thumbnail_url'

# Get all labels
curl -s http://API_URL/results/JOB_ID | jq -r '.results.labels[]'
```

### Delete Job

```bash
curl -X DELETE http://API_URL/jobs/JOB_ID
```

---

## Batch Processing

### Python Batch Processor

```python
import concurrent.futures
from document_processor_client import DocumentProcessorClient

def process_directory(directory_path: str, api_url: str, max_workers: int = 5):
    """Process all files in a directory."""
    client = DocumentProcessorClient(api_url)
    
    # Get all files
    files = list(Path(directory_path).glob('*.*'))
    print(f"Found {len(files)} files to process")
    
    # Upload all files
    job_ids = []
    for file_path in files:
        try:
            response = client.upload_file(str(file_path))
            job_ids.append((response['job_id'], file_path.name))
            print(f"Uploaded: {file_path.name} -> {response['job_id']}")
        except Exception as e:
            print(f"Failed to upload {file_path.name}: {e}")
    
    # Wait for all to complete (parallel)
    def wait_for_job(job_info):
        job_id, filename = job_info
        try:
            results = client.wait_for_completion(job_id, timeout=600)
            return {'filename': filename, 'job_id': job_id, 'results': results, 'error': None}
        except Exception as e:
            return {'filename': filename, 'job_id': job_id, 'results': None, 'error': str(e)}
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        results = list(executor.map(wait_for_job, job_ids))
    
    # Print summary
    successful = sum(1 for r in results if r['error'] is None)
    print(f"\nProcessing complete: {successful}/{len(results)} successful")
    
    return results

# Usage
results = process_directory('/path/to/documents', 'http://your-api-endpoint')

# Save results to JSON
import json
with open('processing_results.json', 'w') as f:
    json.dump(results, f, indent=2)
```

### Bash Batch Script

```bash
#!/bin/bash

API_URL="http://your-api-endpoint"
DIRECTORY="/path/to/documents"

# Upload all files
for file in "$DIRECTORY"/*; do
    if [ -f "$file" ]; then
        echo "Uploading: $file"
        
        RESPONSE=$(curl -s -X POST "$API_URL/upload" \
            -F "file=@$file")
        
        JOB_ID=$(echo "$RESPONSE" | jq -r '.job_id')
        echo "$file,$JOB_ID" >> jobs.csv
        
        echo "Job ID: $JOB_ID"
    fi
done

# Check status of all jobs
echo "Checking job statuses..."
while IFS=',' read -r file job_id; do
    STATUS=$(curl -s "$API_URL/status/$job_id" | jq -r '.status')
    echo "$file: $STATUS"
done < jobs.csv
```

---

## Error Handling

### Python Error Handling

```python
from document_processor_client import DocumentProcessorClient
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def safe_process_file(file_path: str, api_url: str):
    """Process a file with comprehensive error handling."""
    client = DocumentProcessorClient(api_url)
    
    try:
        # Upload file
        logger.info(f"Uploading {file_path}")
        upload_response = client.upload_file(file_path)
        job_id = upload_response['job_id']
        logger.info(f"Upload successful. Job ID: {job_id}")
        
        # Wait for completion
        logger.info("Waiting for processing...")
        results = client.wait_for_completion(job_id, timeout=600)
        
        # Validate results
        if not results.get('results'):
            raise ValueError("No results returned")
        
        logger.info("Processing completed successfully")
        return results
        
    except FileNotFoundError:
        logger.error(f"File not found: {file_path}")
        return None
        
    except requests.exceptions.ConnectionError:
        logger.error("Cannot connect to API. Is it running?")
        return None
        
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 400:
            logger.error(f"Invalid file: {e.response.json().get('detail')}")
        elif e.response.status_code == 413:
            logger.error("File too large")
        else:
            logger.error(f"HTTP error: {e}")
        return None
        
    except TimeoutError:
        logger.error(f"Processing timed out for job {job_id}")
        # Job might still complete - check later
        return None
        
    except RuntimeError as e:
        logger.error(f"Processing failed: {e}")
        return None
        
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return None

# Usage
result = safe_process_file("document.pdf", "http://your-api-endpoint")
if result:
    print("Success!")
else:
    print("Failed - check logs")
```

---

## Integration Examples

### Flask Web Application

```python
from flask import Flask, request, jsonify, render_template
from document_processor_client import DocumentProcessorClient
import os

app = Flask(__name__)
client = DocumentProcessorClient(os.getenv('API_URL'))

@app.route('/')
def index():
    return render_template('upload.html')

@app.route('/upload', methods=['POST'])
def upload():
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    email = request.form.get('email')
    
    # Save temporarily
    temp_path = f'/tmp/{file.filename}'
    file.save(temp_path)
    
    try:
        # Upload to processing service
        response = client.upload_file(temp_path, email)
        return jsonify(response)
    finally:
        os.remove(temp_path)

@app.route('/status/<job_id>')
def status(job_id):
    return jsonify(client.get_status(job_id))

@app.route('/results/<job_id>')
def results(job_id):
    return jsonify(client.get_results(job_id))

if __name__ == '__main__':
    app.run(debug=True)
```

### Django View

```python
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from document_processor_client import DocumentProcessorClient
import os

client = DocumentProcessorClient(os.getenv('API_URL'))

@csrf_exempt
def upload_document(request):
    if request.method == 'POST':
        file = request.FILES.get('file')
        email = request.POST.get('email')
        
        if not file:
            return JsonResponse({'error': 'No file provided'}, status=400)
        
        # Save temporarily
        temp_path = f'/tmp/{file.name}'
        with open(temp_path, 'wb+') as destination:
            for chunk in file.chunks():
                destination.write(chunk)
        
        try:
            response = client.upload_file(temp_path, email)
            return JsonResponse(response)
        finally:
            os.remove(temp_path)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)
```

---

## Advanced Usage

### Retry Logic

```python
import time
from typing import Callable, Any

def retry_with_backoff(
    func: Callable,
    max_retries: int = 3,
    initial_delay: float = 1.0,
    backoff_factor: float = 2.0
) -> Any:
    """Retry a function with exponential backoff."""
    delay = initial_delay
    
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            
            print(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay}s...")
            time.sleep(delay)
            delay *= backoff_factor

# Usage
client = DocumentProcessorClient("http://your-api-endpoint")

result = retry_with_backoff(
    lambda: client.upload_file("document.pdf"),
    max_retries=3
)
```

### Progress Tracking

```python
def track_progress(client: DocumentProcessorClient, job_id: str):
    """Track and display processing progress."""
    import sys
    
    while True:
        status = client.get_status(job_id)
        
        # Display progress bar
        progress = status.get('progress', 0)
        bar_length = 50
        filled = int(bar_length * progress / 100)
        bar = '=' * filled + '-' * (bar_length - filled)
        
        sys.stdout.write(f'\r[{bar}] {progress}% - {status["status"]}')
        sys.stdout.flush()
        
        if status['status'] in ['completed', 'failed']:
            print()  # New line
            break
        
        time.sleep(2)
    
    return status

# Usage
upload_response = client.upload_file("document.pdf")
final_status = track_progress(client, upload_response['job_id'])
```

---

This completes the usage examples. The API is now fully documented with examples in multiple languages and use cases!
