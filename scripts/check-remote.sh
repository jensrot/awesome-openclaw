#!/bin/bash

# Check remote GitHub repo with awesome-lint
# Run this AFTER pushing to verify changes on GitHub

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=1

# Spinner characters
SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPIN_WIDTH=3

# Show progress bar with spinner
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

echo -e "${YELLOW}=== Awesome OpenClaw - Remote Check ===${NC}"
echo ""
echo -e "${YELLOW}Note: This checks the published version on GitHub, not local files.${NC}"
echo ""

run_with_progress "Checking GitHub repo with awesome-lint..." npm run lint:remote --silent

if [ $? -eq 0 ]; then
    echo ""
    printf "${BLUE}[████████████████████] 100%% ${GREEN}Remote check passed!${NC}\n"
else
    echo ""
    echo -e "${RED}=== Remote check failed! ===${NC}"
    echo -e "${YELLOW}Make sure you've pushed your latest changes to GitHub.${NC}"
    exit 1
fi
