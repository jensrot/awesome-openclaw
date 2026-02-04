#!/bin/bash

# Check remote GitHub repo with awesome-lint
# Run this AFTER pushing to verify changes on GitHub

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Awesome OpenClaw - Remote Check ===${NC}"
echo ""
echo -e "${YELLOW}Checking GitHub repo with awesome-lint...${NC}"
echo -e "${YELLOW}Note: This checks the published version on GitHub, not local files.${NC}"
echo ""

npm run lint:remote

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=== Remote check passed! ===${NC}"
else
    echo ""
    echo -e "${RED}=== Remote check failed! ===${NC}"
    echo -e "${YELLOW}Make sure you've pushed your latest changes to GitHub.${NC}"
    exit 1
fi
