#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Document Processor Frontend${NC}"
echo -e "${GREEN}===========================${NC}\n"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}\n"
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env file${NC}"
    echo -e "${YELLOW}⚠ Please edit .env and set your API_URL${NC}\n"
fi

# Start development server
echo -e "${GREEN}Starting development server...${NC}"
echo -e "${YELLOW}Frontend will be available at: http://localhost:3000${NC}\n"
npm run dev
