#!/bin/bash

# Validate README.md against contribution guidelines
# Run this script to check entries conform to CONTRIBUTING.md and PULL_REQUEST_TEMPLATE.md
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
NC='\033[0m' # No Color

# Get project root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

README="$PROJECT_ROOT/README.md"
ERRORS=0
WARNINGS=0

echo -e "${YELLOW}=== Validating README.md ===${NC}"
echo ""

# Check if README exists
if [ ! -f "$README" ]; then
    echo -e "${RED}ERROR: README.md not found${NC}"
    exit 1
fi

# ============================================
# Check 1: Entry format [Name](Link) - Description.
# ============================================
echo -e "${YELLOW}[1/6] Checking entry format...${NC}"

# Find all list entries (lines starting with "- [")
while IFS= read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Skip TOC entries (they don't have descriptions)
    if echo "$content" | grep -qE '^\s*-\s*\[.*\]\(#'; then
        continue
    fi

    # Check format: [Name](URL) - Description
    if ! echo "$content" | grep -qE '^\s*-\s*\[.+\]\(https?://[^\)]+\)\s*-\s*.+$'; then
        echo -e "${RED}  Line $line_num: Invalid format${NC}"
        echo "    Found: $content"
        echo "    Expected: [Name](Link) - Description."
        ((ERRORS++))
    fi
done < <(grep -n '^- \[' "$README")

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  ✓ All entries have valid format${NC}"
fi

# ============================================
# Check 2: Description starts with capital letter
# ============================================
echo -e "${YELLOW}[2/6] Checking descriptions start with capital letter...${NC}"

FORMAT_ERRORS=$ERRORS
while IFS= read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Skip TOC entries
    if echo "$content" | grep -qE '^\s*-\s*\[.*\]\(#'; then
        continue
    fi

    # Extract description (everything after " - ")
    description=$(echo "$content" | sed -n 's/.*\]\s*-\s*//p')

    if [ -n "$description" ]; then
        # Get first character of description
        first_char=$(echo "$description" | cut -c1)

        # Check if it's uppercase
        if [[ ! "$first_char" =~ [A-Z] ]]; then
            echo -e "${RED}  Line $line_num: Description doesn't start with capital letter${NC}"
            echo "    Description: $description"
            ((ERRORS++))
        fi
    fi
done < <(grep -n '^- \[' "$README")

if [ $ERRORS -eq $FORMAT_ERRORS ]; then
    echo -e "${GREEN}  ✓ All descriptions start with capital letter${NC}"
fi

# ============================================
# Check 3: Description ends with period
# ============================================
echo -e "${YELLOW}[3/6] Checking descriptions end with period...${NC}"

CAPITAL_ERRORS=$ERRORS
while IFS= read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Skip TOC entries
    if echo "$content" | grep -qE '^\s*-\s*\[.*\]\(#'; then
        continue
    fi

    # Check if line ends with period (allowing trailing whitespace)
    if ! echo "$content" | grep -qE '\.\s*$'; then
        echo -e "${RED}  Line $line_num: Description doesn't end with period${NC}"
        echo "    Found: $content"
        ((ERRORS++))
    fi
done < <(grep -n '^- \[' "$README")

if [ $ERRORS -eq $CAPITAL_ERRORS ]; then
    echo -e "${GREEN}  ✓ All descriptions end with period${NC}"
fi

# ============================================
# Check 4: Alphabetical order within sections
# ============================================
echo -e "${YELLOW}[4/6] Checking alphabetical order within sections...${NC}"

PERIOD_ERRORS=$ERRORS
current_section=""
prev_name=""
prev_line=0

while IFS= read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # Check for section headers
    if echo "$content" | grep -qE '^## '; then
        current_section=$(echo "$content" | sed 's/^## //')
        prev_name=""
        prev_line=0
        continue
    fi

    # Skip non-list entries and TOC
    if ! echo "$content" | grep -qE '^- \['; then
        continue
    fi
    if echo "$content" | grep -qE '^- \[.*\]\(#'; then
        continue
    fi

    # Extract the name from [Name](link)
    name=$(echo "$content" | sed -n 's/^- \[\([^]]*\)\].*/\1/p')

    if [ -n "$prev_name" ] && [ -n "$name" ]; then
        # Compare names (case-insensitive)
        if [[ "$(echo "$prev_name" | tr '[:upper:]' '[:lower:]')" > "$(echo "$name" | tr '[:upper:]' '[:lower:]')" ]]; then
            echo -e "${RED}  Section '$current_section': Not in alphabetical order${NC}"
            echo "    Line $prev_line: $prev_name"
            echo "    Line $line_num: $name (should come before)"
            ((ERRORS++))
        fi
    fi

    prev_name="$name"
    prev_line="$line_num"
done < <(grep -nE '^(## |- \[)' "$README")

if [ $ERRORS -eq $PERIOD_ERRORS ]; then
    echo -e "${GREEN}  ✓ All sections are in alphabetical order${NC}"
fi

# ============================================
# Check 5: No duplicate entry names
# ============================================
echo -e "${YELLOW}[5/6] Checking for duplicate entry names...${NC}"

ALPHA_ERRORS=$ERRORS

# Extract all entry names and find duplicates
grep -oP '(?<=^- \[)[^\]]+' "$README" | sort | uniq -d | while read -r dup; do
    if [ -n "$dup" ]; then
        echo -e "${RED}  Duplicate entry name found: '$dup'${NC}"
        grep -n "^- \[$dup\]" "$README" | while read -r occurrence; do
            echo "    $occurrence"
        done
        ((ERRORS++))
    fi
done

# Re-check duplicates for error counting
DUP_COUNT=$(grep -oP '(?<=^- \[)[^\]]+' "$README" | sort | uniq -d | wc -l)
ERRORS=$((ERRORS + DUP_COUNT))

if [ $DUP_COUNT -eq 0 ]; then
    echo -e "${GREEN}  ✓ No duplicate entry names${NC}"
fi

# ============================================
# Check 6: Blank line after section headers
# ============================================
echo -e "${YELLOW}[6/6] Checking blank line after section headers...${NC}"

HEADER_ERRORS=0
prev_line=""
prev_line_num=0

while IFS= read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    content=$(echo "$line" | cut -d: -f2-)

    # If previous line was a section header (## ), current line should be empty
    if echo "$prev_line" | grep -qE '^## ' && [ -n "$content" ]; then
        section_name=$(echo "$prev_line" | sed 's/^## //')
        echo -e "${RED}  Missing blank line after '## $section_name' (line $prev_line_num)${NC}"
        ((HEADER_ERRORS++))
        ((ERRORS++))
    fi

    prev_line="$content"
    prev_line_num="$line_num"
done < <(grep -n '' "$README")

if [ $HEADER_ERRORS -eq 0 ]; then
    echo -e "${GREEN}  ✓ All section headers have blank line after them${NC}"
fi

# ============================================
# Summary
# ============================================
echo ""
echo -e "${YELLOW}=== Summary ===${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! README.md conforms to contribution guidelines.${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s). Please fix before merging.${NC}"
    exit 1
fi
