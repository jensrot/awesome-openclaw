#!/bin/bash

# Check, commit, and push script for Awesome OpenClaw
# Runs all lint checks before committing and pushing
#
# Usage: ./check-and-push.sh [commit message]
# If commit message is provided as argument, skips the prompt

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=7  # lint:local, lint:urls, validate, stage, commit, push, remote

# Spinner characters
SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPIN_WIDTH=3

# Show progress bar with spinner
# Usage: show_progress_spinner "message" &
show_progress_spinner() {
    local msg="$1"
    local i=0

    while true; do
        local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
        local filled=$((percent / 5))
        local empty=$((20 - filled))

        local bar=""
        for ((j=0; j<filled; j++)); do bar+="█"; done
        for ((j=0; j<empty; j++)); do bar+="░"; done

        local spin_char="${SPIN:$i:$SPIN_WIDTH}"
        printf "\r${BLUE}[%s] %3d%% ${YELLOW}%s ${NC}%s" "$bar" "$percent" "$msg" "$spin_char"

        i=$(( (i + SPIN_WIDTH) % ${#SPIN} ))
        sleep 0.1
    done
}

# Run command with spinner and progress bar
# Usage: run_with_progress "message" command args...
run_with_progress() {
    local msg="$1"
    shift

    # Start spinner in background
    show_progress_spinner "$msg" &
    local spinner_pid=$!

    # Run command and capture output
    local tmpfile=$(mktemp)
    "$@" > "$tmpfile" 2>&1
    local exit_code=$?

    # Stop spinner
    kill $spinner_pid 2>/dev/null
    wait $spinner_pid 2>/dev/null

    # Update progress
    ((CURRENT_STEP++))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    local bar=""
    for ((j=0; j<filled; j++)); do bar+="█"; done
    for ((j=0; j<empty; j++)); do bar+="░"; done

    # Show result
    printf "\r"
    if [ $exit_code -eq 0 ]; then
        printf "${BLUE}[%s] %3d%% ${YELLOW}%s ${GREEN}✓${NC}      \n" "$bar" "$percent" "$msg"
    else
        printf "${BLUE}[%s] %3d%% ${YELLOW}%s ${RED}✗${NC}      \n" "$bar" "$percent" "$msg"
        cat "$tmpfile"
    fi

    rm -f "$tmpfile"
    return $exit_code
}

echo -e "${YELLOW}=== Awesome OpenClaw - Check & Push ===${NC}"
echo ""

# Get script directory early
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Run lint:local
run_with_progress "Running local lint (remark)..." npm run lint:local --silent
if [ $? -ne 0 ]; then
    echo -e "${RED}Local lint failed! Please fix the issues above.${NC}"
    exit 1
fi

# Step 2: Run lint:urls (optional - warnings only)
run_with_progress "Checking URLs..." npm run lint:urls --silent
# Don't fail on URL check - informational only

# Step 3: Run custom validation
run_with_progress "Validating contribution guidelines..." bash "$SCRIPT_DIR/validate-readme.sh" --quiet
if [ $? -ne 0 ]; then
    echo -e "${RED}Validation failed! Run 'bash scripts/validate-readme.sh' for details.${NC}"
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

# Get commit message (from argument or prompt)
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
    echo -e "${YELLOW}Using provided commit message: ${COMMIT_MSG}${NC}"
else
    echo -e "${YELLOW}Enter commit message (or press Enter for default):${NC}"
    read -e -p "> " COMMIT_MSG
    if [ -z "$COMMIT_MSG" ]; then
        COMMIT_MSG="Update Awesome OpenClaw"
    fi
fi

# Confirmation loop (allows editing message)
while true; do
    echo ""
    echo -e "${YELLOW}Summary:${NC}"
    echo "  Commit message: ${COMMIT_MSG}"
    echo ""
    echo -e "${YELLOW}Options: [y]es, [e]dit message, [n]o${NC}"
    read -e -p "> " CONFIRM

    case "$CONFIRM" in
        y|Y)
            break
            ;;
        e|E)
            echo ""
            echo -e "${YELLOW}Enter new commit message:${NC}"
            read -e -p "> " NEW_MSG
            if [ -n "$NEW_MSG" ]; then
                COMMIT_MSG="$NEW_MSG"
            fi
            ;;
        n|N)
            echo -e "${RED}Aborted.${NC}"
            exit 0
            ;;
        *)
            echo -e "${YELLOW}Please enter y, e, or n${NC}"
            ;;
    esac
done

# Stage all changes
run_with_progress "Staging changes..." git add -A

# Commit
run_with_progress "Creating commit..." git commit -m "$COMMIT_MSG"
if [ $? -ne 0 ]; then
    echo -e "${RED}Commit failed!${NC}"
    exit 1
fi

# Push
run_with_progress "Pushing to remote..." git push origin main
if [ $? -ne 0 ]; then
    echo -e "${RED}Push failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Successfully committed and pushed! ===${NC}"
echo ""

# Run remote check
run_with_progress "Running remote validation..." npm run lint:remote --silent

# Final progress - 100%
echo ""
printf "${BLUE}[████████████████████] 100%% ${GREEN}Complete!${NC}\n"
