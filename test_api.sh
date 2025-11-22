#!/bin/bash

# Test script for the Document Processing API

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get API endpoint from Terraform output
if [ -f terraform/terraform.tfstate ]; then
    API_ENDPOINT=$(cd terraform && terraform output -raw api_endpoint 2>/dev/null)
else
    echo -e "${RED}Error: Terraform state not found. Please deploy first.${NC}"
    exit 1
fi

if [ -z "$API_ENDPOINT" ]; then
    echo -e "${RED}Error: Could not get API endpoint${NC}"
    exit 1
fi

echo -e "${GREEN}Testing API at: ${API_ENDPOINT}${NC}\n"

# Test 1: Health check
echo -e "${YELLOW}Test 1: Health Check${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" "${API_ENDPOINT}/health")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "$BODY" | jq .
else
    echo -e "${RED}✗ Health check failed (HTTP $HTTP_CODE)${NC}"
    echo "$BODY"
fi

# Test 2: Upload a test file
echo -e "\n${YELLOW}Test 2: File Upload${NC}"

# Create a test file if it doesn't exist
if [ ! -f test_document.txt ]; then
    echo "This is a test document for the document processing service." > test_document.txt
    echo "It contains sample text for testing OCR and processing capabilities." >> test_document.txt
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_ENDPOINT}/upload" \
    -F "file=@sample.pdf" \
    -F "notification_email=your@email.here")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ File upload successful${NC}"
    echo "$BODY" | jq .
    
    # Extract job_id for next tests
    JOB_ID=$(echo "$BODY" | jq -r '.job_id')
    
    # Test 3: Check status
    echo -e "\n${YELLOW}Test 3: Check Job Status${NC}"
    sleep 2
    
    RESPONSE=$(curl -s -w "\n%{http_code}" "${API_ENDPOINT}/status/${JOB_ID}")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Status check successful${NC}"
        echo "$BODY" | jq .
    else
        echo -e "${RED}✗ Status check failed (HTTP $HTTP_CODE)${NC}"
        echo "$BODY"
    fi
    
    # Test 4: Get results (after some time)
    echo -e "\n${YELLOW}Test 4: Get Results (waiting 10 seconds for processing)${NC}"
    sleep 10
    
    RESPONSE=$(curl -s -w "\n%{http_code}" "${API_ENDPOINT}/results/${JOB_ID}")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Results retrieved${NC}"
        echo "$BODY" | jq .
    else
        echo -e "${RED}✗ Results retrieval failed (HTTP $HTTP_CODE)${NC}"
        echo "$BODY"
    fi
    
else
    echo -e "${RED}✗ File upload failed (HTTP $HTTP_CODE)${NC}"
    echo "$BODY"
fi

echo -e "\n${GREEN}Testing complete!${NC}"
