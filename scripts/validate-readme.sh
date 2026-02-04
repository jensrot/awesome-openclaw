#!/bin/bash

# Validate README.md against contribution guidelines
# Run this script to check entries conform to CONTRIBUTING.md and PULL_REQUEST_TEMPLATE.md
#
# Usage: bash validate-readme.sh [--quiet] [--fix] [--slow]
#
# Options:
#   --quiet  Suppress progress output
#   --fix    Automatically fix alphabetical order errors
#   --slow   Use slow mode with animated spinners (default is fast)
#
# Checks performed:
# 1. Format: [Name](Link) - Description.
# 2. Description starts with capital letter
# 3. Description ends with period
# 4. Alphabetical order within sections
# 5. No duplicate entry names
# 6. Blank line after section headers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
QUIET_MODE=false
FIX_MODE=false
SLOW_MODE=false
for arg in "$@"; do
    case $arg in
        --quiet) QUIET_MODE=true ;;
        --fix) FIX_MODE=true ;;
        --slow) SLOW_MODE=true ;;
    esac
done

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=6

# Spinner characters
SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPIN_WIDTH=3
SPINNER_PID=""

# Start spinner in background
start_spinner() {
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

# Stop spinner and show result
stop_spinner() {
    local msg="$1"
    local status="$2"
    local error_count="$3"

    # Kill spinner if running
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
        SPINNER_PID=""
    fi

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
    if [ "$status" = "pass" ]; then
        printf "${BLUE}[%s] %3d%% ${YELLOW}%s ${GREEN}✓${NC}      \n" "$bar" "$percent" "$msg"
    else
        printf "${BLUE}[%s] %3d%% ${YELLOW}%s ${RED}✗ (%d)${NC}   \n" "$bar" "$percent" "$msg" "$error_count"
    fi
}

# Get project root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

README="$PROJECT_ROOT/README.md"
ERRORS=0

if [ "$QUIET_MODE" = false ]; then
    echo -e "${YELLOW}=== Validating README.md ===${NC}"
    echo ""
fi

# Check if README exists
if [ ! -f "$README" ]; then
    echo -e "${RED}ERROR: README.md not found${NC}"
    exit 1
fi

# ============================================
# FAST MODE (default): Single-pass validation using awk
# ============================================
if [ "$SLOW_MODE" = false ]; then

    # Run all checks in a single awk pass
    RESULT=$(awk '
    BEGIN {
        format_err = 0
        capital_err = 0
        period_err = 0
        alpha_err = 0
        header_err = 0
        prev_name = ""
        prev_was_header = 0
        in_toc = 0
    }

    # Track if we are in TOC (Contents section)
    /^## Contents/ { in_toc = 1; next }
    /^## / && !/^## Contents/ { in_toc = 0 }

    # Check blank line after headers
    /^## / {
        prev_was_header = 1
        prev_name = ""
        next
    }

    # If prev was header and this line is not empty
    prev_was_header && !/^$/ {
        header_err++
    }

    { prev_was_header = 0 }

    # Skip TOC entries and non-entry lines
    !/^- \[/ { next }
    /^- \[.*\]\(#/ { next }

    # Entry line processing
    {
        line = $0

        # Check format: - [Name](URL) - Description
        if (line !~ /^- \[[^\]]+\]\(https?:\/\/[^)]+\) - .+$/) {
            format_err++
        }

        # Extract description (after "] - ")
        if (match(line, /\] - (.+)$/, arr)) {
            desc = arr[1]
            # Check capital letter
            first = substr(desc, 1, 1)
            if (first !~ /[A-Z]/) {
                capital_err++
            }
            # Check period
            if (line !~ /\.$/) {
                period_err++
            }
        }

        # Extract name for alphabetical check
        if (match(line, /\[([^\]]+)\]/, arr)) {
            name = tolower(arr[1])
            if (prev_name != "" && prev_name > name) {
                alpha_err++
            }
            prev_name = name
        }
    }

    END {
        print format_err, capital_err, period_err, alpha_err, header_err
    }
    ' "$README")

    # Parse results
    read -r FORMAT_ERR CAPITAL_ERR PERIOD_ERR ALPHA_ERR HEADER_ERR <<< "$RESULT"

    # Check duplicates (still needs separate command but fast)
    DUP_COUNT=$(grep -oP "(?<=^- \[)[^\]]+" "$README" | sort | uniq -d | wc -l)

    TOTAL_ERRORS=$((FORMAT_ERR + CAPITAL_ERR + PERIOD_ERR + ALPHA_ERR + HEADER_ERR + DUP_COUNT))

    if [ "$QUIET_MODE" = false ]; then
        [ $FORMAT_ERR -eq 0 ] && echo -e "${GREEN}✓${NC} Entry format" || echo -e "${RED}✗${NC} Entry format ($FORMAT_ERR errors)"
        [ $CAPITAL_ERR -eq 0 ] && echo -e "${GREEN}✓${NC} Capital letters" || echo -e "${RED}✗${NC} Capital letters ($CAPITAL_ERR errors)"
        [ $PERIOD_ERR -eq 0 ] && echo -e "${GREEN}✓${NC} Ending periods" || echo -e "${RED}✗${NC} Ending periods ($PERIOD_ERR errors)"
        [ $ALPHA_ERR -eq 0 ] && echo -e "${GREEN}✓${NC} Alphabetical order" || echo -e "${RED}✗${NC} Alphabetical order ($ALPHA_ERR errors)"
        [ $DUP_COUNT -eq 0 ] && echo -e "${GREEN}✓${NC} No duplicates" || echo -e "${RED}✗${NC} Duplicates ($DUP_COUNT found)"
        [ $HEADER_ERR -eq 0 ] && echo -e "${GREEN}✓${NC} Blank lines after headers" || echo -e "${RED}✗${NC} Blank lines ($HEADER_ERR errors)"
        echo ""
        if [ $TOTAL_ERRORS -eq 0 ]; then
            echo -e "${GREEN}All checks passed!${NC}"
        else
            echo -e "${RED}Found $TOTAL_ERRORS error(s)${NC}"
        fi
    fi

    exit $( [ $TOTAL_ERRORS -eq 0 ] && echo 0 || echo 1 )
fi

# ============================================
# Check 1: Entry format [Name](Link) - Description.
# ============================================
if [ "$QUIET_MODE" = false ]; then
    start_spinner "Checking entry format..." &
    SPINNER_PID=$!
fi

CHECK1_ERRORS=0
while IFS= read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    if echo "$content" | grep -qE '^\s*-\s*\[.*\]\(#'; then
        continue
    fi

    if ! echo "$content" | grep -qE '^\s*-\s*\[.+\]\(https?://[^\)]+\)\s*-\s*.+$'; then
        ((CHECK1_ERRORS++))
        ((ERRORS++))
    fi
done < <(grep -n '^- \[' "$README")

if [ "$QUIET_MODE" = false ]; then
    if [ $CHECK1_ERRORS -eq 0 ]; then
        stop_spinner "Entry format" "pass" 0
    else
        stop_spinner "Entry format" "fail" $CHECK1_ERRORS
    fi
fi

# ============================================
# Check 2: Description starts with capital letter
# ============================================
if [ "$QUIET_MODE" = false ]; then
    start_spinner "Checking capital letters..." &
    SPINNER_PID=$!
fi

CHECK2_ERRORS=0
while IFS= read -r line; do
    content=$(echo "$line" | cut -d: -f2-)

    if echo "$content" | grep -qE '^\s*-\s*\[.*\]\(#'; then
        continue
    fi

    description=$(echo "$content" | sed -n 's/.*\]\s*-\s*//p')

    if [ -n "$description" ]; then
        first_char=$(echo "$description" | cut -c1)
        if [[ ! "$first_char" =~ [A-Z] ]]; then
            ((CHECK2_ERRORS++))
            ((ERRORS++))
        fi
    fi
done < <(grep -n '^- \[' "$README")

if [ "$QUIET_MODE" = false ]; then
    if [ $CHECK2_ERRORS -eq 0 ]; then
        stop_spinner "Capital letters" "pass" 0
    else
        stop_spinner "Capital letters" "fail" $CHECK2_ERRORS
    fi
fi

# ============================================
# Check 3: Description ends with period
# ============================================
if [ "$QUIET_MODE" = false ]; then
    start_spinner "Checking periods..." &
    SPINNER_PID=$!
fi

CHECK3_ERRORS=0
while IFS= read -r line; do
    content=$(echo "$line" | cut -d: -f2-)

    if echo "$content" | grep -qE '^\s*-\s*\[.*\]\(#'; then
        continue
    fi

    if ! echo "$content" | grep -qE '\.\s*$'; then
        ((CHECK3_ERRORS++))
        ((ERRORS++))
    fi
done < <(grep -n '^- \[' "$README")

if [ "$QUIET_MODE" = false ]; then
    if [ $CHECK3_ERRORS -eq 0 ]; then
        stop_spinner "Ending periods" "pass" 0
    else
        stop_spinner "Ending periods" "fail" $CHECK3_ERRORS
    fi
fi

# ============================================
# Check 4: Alphabetical order within sections
# ============================================
if [ "$QUIET_MODE" = false ]; then
    start_spinner "Checking alphabetical order..." &
    SPINNER_PID=$!
fi

CHECK4_ERRORS=0
current_section=""
prev_name=""

while IFS= read -r line; do
    content=$(echo "$line" | cut -d: -f2-)

    if echo "$content" | grep -qE '^## '; then
        current_section=$(echo "$content" | sed 's/^## //')
        prev_name=""
        continue
    fi

    if ! echo "$content" | grep -qE '^- \['; then
        continue
    fi
    if echo "$content" | grep -qE '^- \[.*\]\(#'; then
        continue
    fi

    name=$(echo "$content" | sed -n 's/^- \[\([^]]*\)\].*/\1/p')

    if [ -n "$prev_name" ] && [ -n "$name" ]; then
        if [[ "$(echo "$prev_name" | tr '[:upper:]' '[:lower:]')" > "$(echo "$name" | tr '[:upper:]' '[:lower:]')" ]]; then
            ((CHECK4_ERRORS++))
            ((ERRORS++))
        fi
    fi

    prev_name="$name"
done < <(grep -nE '^(## |- \[)' "$README")

if [ "$QUIET_MODE" = false ]; then
    if [ $CHECK4_ERRORS -eq 0 ]; then
        stop_spinner "Alphabetical order" "pass" 0
    else
        stop_spinner "Alphabetical order" "fail" $CHECK4_ERRORS
    fi
fi

# ============================================
# Fix alphabetical order if --fix flag is set
# ============================================
if [ "$FIX_MODE" = true ] && [ $CHECK4_ERRORS -gt 0 ]; then
    if [ "$QUIET_MODE" = false ]; then
        echo -e "${YELLOW}Fixing alphabetical order...${NC}"
    fi

    # Create temp files for processing
    TEMP_FILE=$(mktemp)
    ENTRIES_FILE=$(mktemp)

    # Process README line by line
    in_section=false
    collecting_entries=false

    while IFS= read -r line; do
        # Check if this is a section header (## )
        if echo "$line" | grep -qE '^## '; then
            # Output any collected entries from previous section (sorted)
            if [ -s "$ENTRIES_FILE" ]; then
                # Sort by the name inside brackets (case-insensitive)
                while IFS= read -r entry; do
                    name=$(echo "$entry" | sed -n 's/^- \[\([^]]*\)\].*/\1/p' | tr '[:upper:]' '[:lower:]')
                    printf '%s\t%s\n' "$name" "$entry"
                done < "$ENTRIES_FILE" | sort -t$'\t' -k1 | cut -f2- >> "$TEMP_FILE"
                > "$ENTRIES_FILE"
            fi
            collecting_entries=true
            echo "$line" >> "$TEMP_FILE"
        # Check if this is an entry line (- [) but not TOC entry
        elif echo "$line" | grep -qE '^- \[' && ! echo "$line" | grep -qE '^- \[.*\]\(#'; then
            echo "$line" >> "$ENTRIES_FILE"
        else
            # Output any collected entries before non-entry line
            if [ -s "$ENTRIES_FILE" ]; then
                while IFS= read -r entry; do
                    name=$(echo "$entry" | sed -n 's/^- \[\([^]]*\)\].*/\1/p' | tr '[:upper:]' '[:lower:]')
                    printf '%s\t%s\n' "$name" "$entry"
                done < "$ENTRIES_FILE" | sort -t$'\t' -k1 | cut -f2- >> "$TEMP_FILE"
                > "$ENTRIES_FILE"
            fi
            echo "$line" >> "$TEMP_FILE"
        fi
    done < "$README"

    # Output any remaining entries
    if [ -s "$ENTRIES_FILE" ]; then
        while IFS= read -r entry; do
            name=$(echo "$entry" | sed -n 's/^- \[\([^]]*\)\].*/\1/p' | tr '[:upper:]' '[:lower:]')
            printf '%s\t%s\n' "$name" "$entry"
        done < "$ENTRIES_FILE" | sort -t$'\t' -k1 | cut -f2- >> "$TEMP_FILE"
    fi

    # Clean up temp entries file
    rm -f "$ENTRIES_FILE"

    # Replace original file
    mv "$TEMP_FILE" "$README"

    if [ "$QUIET_MODE" = false ]; then
        echo -e "${GREEN}Fixed alphabetical order in README.md${NC}"
    fi

    # Reset error count for this check since we fixed it
    ERRORS=$((ERRORS - CHECK4_ERRORS))
    CHECK4_ERRORS=0
fi

# ============================================
# Check 5: No duplicate entry names
# ============================================
if [ "$QUIET_MODE" = false ]; then
    start_spinner "Checking duplicates..." &
    SPINNER_PID=$!
fi

DUP_COUNT=$(grep -oP '(?<=^- \[)[^\]]+' "$README" | sort | uniq -d | wc -l)
ERRORS=$((ERRORS + DUP_COUNT))

if [ "$QUIET_MODE" = false ]; then
    if [ $DUP_COUNT -eq 0 ]; then
        stop_spinner "No duplicates" "pass" 0
    else
        stop_spinner "Duplicates found" "fail" $DUP_COUNT
    fi
fi

# ============================================
# Check 6: Blank line after section headers
# ============================================
if [ "$QUIET_MODE" = false ]; then
    start_spinner "Checking blank lines..." &
    SPINNER_PID=$!
fi

HEADER_ERRORS=0
prev_line=""

while IFS= read -r line; do
    content=$(echo "$line" | cut -d: -f2-)

    if echo "$prev_line" | grep -qE '^## ' && [ -n "$content" ]; then
        ((HEADER_ERRORS++))
        ((ERRORS++))
    fi

    prev_line="$content"
done < <(grep -n '' "$README")

if [ "$QUIET_MODE" = false ]; then
    if [ $HEADER_ERRORS -eq 0 ]; then
        stop_spinner "Blank lines after headers" "pass" 0
    else
        stop_spinner "Blank lines" "fail" $HEADER_ERRORS
    fi
fi

# ============================================
# Summary
# ============================================
if [ "$QUIET_MODE" = false ]; then
    echo ""
    if [ $ERRORS -eq 0 ]; then
        printf "${BLUE}[████████████████████] 100%% ${GREEN}All checks passed!${NC}\n"
    else
        printf "${BLUE}[████████████████████] 100%% ${RED}Found $ERRORS error(s)${NC}\n"
    fi
fi

if [ $ERRORS -eq 0 ]; then
    exit 0
else
    exit 1
fi
