#!/bin/bash

# Check, commit, and push script for Awesome OpenClaw
# Runs all lint checks before committing and pushing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Awesome OpenClaw - Check & Push ===${NC}"
echo ""

# Step 1: Run lint:local
echo -e "${YELLOW}[1/4] Running local lint (remark)...${NC}"
npm run lint:local --silent
if [ $? -ne 0 ]; then
    echo -e "${RED}Local lint failed! Please fix the issues above.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Local lint passed${NC}"
echo ""

# Step 2: Run lint:remote (awesome-lint)
echo -e "${YELLOW}[2/4] Running awesome-lint...${NC}"
npm run lint:remote --silent
if [ $? -ne 0 ]; then
    echo -e "${RED}Awesome-lint failed! Please fix the issues above.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Awesome-lint passed${NC}"
echo ""

# Step 3: Run lint:urls (optional - warnings only)
echo -e "${YELLOW}[3/4] Checking URLs (warnings only)...${NC}"
npm run lint:urls 2>&1 | tail -5
echo -e "${YELLOW}Note: URL check warnings are informational only${NC}"
echo ""

# Step 4: Run custom validation (format, alphabetical order, duplicates)
echo -e "${YELLOW}[4/4] Validating contribution guidelines...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/validate-readme.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Validation failed! Please fix the issues above.${NC}"
    exit 1
fi
echo ""

# Show current status
echo -e "${YELLOW}=== Git Status ===${NC}"
git status --short
echo ""

# Check if there are changes to commit
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${YELLOW}No changes to commit.${NC}"
    exit 0
fi

# Prompt for commit message
echo -e "${YELLOW}Enter commit message (or press Enter for default):${NC}"
read -e -p "> " COMMIT_MSG

if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="Update Awesome OpenClaw"
fi

# Confirm
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  Commit message: ${COMMIT_MSG}"
echo ""
read -e -p "Proceed with commit and push? (y/n): " CONFIRM

if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 0
fi

# Stage all changes
echo -e "${YELLOW}Staging changes...${NC}"
git add -A

# Commit
echo -e "${YELLOW}Creating commit...${NC}"
git commit -m "$COMMIT_MSG"

if [ $? -ne 0 ]; then
    echo -e "${RED}Commit failed!${NC}"
    exit 1
fi

# Push
echo -e "${YELLOW}Pushing to remote...${NC}"
git push origin main

if [ $? -ne 0 ]; then
    echo -e "${RED}Push failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Successfully committed and pushed! ===${NC}"
