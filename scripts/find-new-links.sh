#!/bin/bash

# Find new links from other awesome-openclaw repositories
# Searches GitHub for repos matching "awesome-openclaw" and extracts links not in our README
#
# This script discovers public links from other awesome-openclaw repositories
# to help maintain comprehensive coverage. All sources are credited in the output.
# Uses GitHub's public API with rate-limit-respecting delays.
# Results should be manually reviewed before adding - we curate for quality.
#
# Usage: ./find-new-links.sh [search-term]
# Default search term: awesome-openclaw

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
README="$PROJECT_ROOT/README.md"
TEMP_DIR=$(mktemp -d)
SEARCH_TERM="${1:-awesome-openclaw}"

# Cleanup on exit
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${YELLOW}=== Awesome OpenClaw - Link Finder ===${NC}"
echo ""
echo -e "${BLUE}Search term:${NC} $SEARCH_TERM"
echo ""

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed.${NC}"
    exit 1
fi

# Extract existing links from our README
echo -e "${YELLOW}[1/4] Extracting existing links from README...${NC}"
grep -oP 'https?://[^\s\)\]>"]+' "$README" | sort -u > "$TEMP_DIR/existing_links.txt"
EXISTING_COUNT=$(wc -l < "$TEMP_DIR/existing_links.txt")
echo -e "${GREEN}  Found $EXISTING_COUNT existing links${NC}"

# Search for repositories using GitHub API
echo ""
echo -e "${YELLOW}[2/4] Searching GitHub for '$SEARCH_TERM' repositories...${NC}"

# URL encode the search term
ENCODED_SEARCH=$(echo "$SEARCH_TERM" | sed 's/ /%20/g')

# Search GitHub API
curl -s "https://api.github.com/search/repositories?q=$ENCODED_SEARCH&per_page=50" > "$TEMP_DIR/repos.json"

if [ ! -s "$TEMP_DIR/repos.json" ] || grep -q "API rate limit" "$TEMP_DIR/repos.json"; then
    echo -e "${RED}  API request failed or rate limited${NC}"
    echo -e "${YELLOW}  Try again later or authenticate with: export GITHUB_TOKEN=your_token${NC}"
    exit 1
fi

# Parse repo full names
REPOS=$(grep -oP '"full_name":\s*"[^"]+"' "$TEMP_DIR/repos.json" | cut -d'"' -f4)
REPO_COUNT=$(echo "$REPOS" | grep -c .)
echo -e "${GREEN}  Found $REPO_COUNT repositories${NC}"

# Fetch README from each repo and extract links
echo ""
echo -e "${YELLOW}[3/4] Fetching READMEs and extracting links...${NC}"
> "$TEMP_DIR/all_new_links.txt"

CURRENT=0
for REPO in $REPOS; do
    ((CURRENT++))

    # Skip our own repo
    if [[ "$REPO" == *"jensrot/awesome-openclaw"* ]]; then
        continue
    fi

    printf "\r  Processing %d/%d: %-60s" "$CURRENT" "$REPO_COUNT" "$REPO"

    # Fetch README via GitHub API
    README_CONTENT=$(curl -s "https://api.github.com/repos/$REPO/readme" | \
        grep -oP '"content":\s*"[^"]+"' | \
        cut -d'"' -f4 | \
        tr -d '\n' | \
        base64 -d 2>/dev/null)

    if [ -n "$README_CONTENT" ]; then
        # Extract links and add source repo
        echo "$README_CONTENT" | grep -oP 'https?://[^\s\)\]>"\\]+' | while read -r link; do
            # Clean up the link
            link=$(echo "$link" | sed 's/\\n//g' | sed 's/\\//g')

            # Skip GitHub links to the repo itself, images, and common non-resource links
            if [[ ! "$link" =~ github\.com/$REPO ]] && \
               [[ ! "$link" =~ \.(png|jpg|jpeg|gif|svg|ico)$ ]] && \
               [[ ! "$link" =~ (shields\.io|badge|img\.shields) ]] && \
               [[ ! "$link" =~ (awesome\.re/badge) ]] && \
               [[ ${#link} -gt 10 ]]; then
                echo "$link|$REPO" >> "$TEMP_DIR/all_new_links.txt"
            fi
        done
    fi

    # Small delay to avoid rate limiting
    sleep 0.5
done
echo ""

# Find links not in our README
echo ""
echo -e "${YELLOW}[4/4] Finding new links not in your README...${NC}"

# Create output file
OUTPUT_FILE="$PROJECT_ROOT/new-links-found.md"
> "$OUTPUT_FILE"

echo "# New Links Found" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Generated on: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "These links were found in other awesome-openclaw repositories but are not in your README.md yet." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process and deduplicate
NEW_COUNT=0
declare -A SEEN_LINKS

if [ -f "$TEMP_DIR/all_new_links.txt" ]; then
    while IFS='|' read -r link source; do
        # Skip empty lines
        [ -z "$link" ] && continue

        # Normalize link (remove trailing slashes)
        normalized_link=$(echo "$link" | sed 's:/*$::')

        # Skip if we've seen this link
        if [[ -n "${SEEN_LINKS[$normalized_link]}" ]]; then
            continue
        fi
        SEEN_LINKS[$normalized_link]=1

        # Check if link exists in our README (also check without trailing slash)
        if ! grep -qF "$normalized_link" "$TEMP_DIR/existing_links.txt" && \
           ! grep -qF "${normalized_link}/" "$TEMP_DIR/existing_links.txt"; then

            # Skip common non-resource links we already have
            if [[ "$normalized_link" =~ (github\.com/openclaw/openclaw$|docs\.openclaw\.ai$|openclaw\.ai$) ]]; then
                continue
            fi

            # Skip GitHub user/org pages
            if [[ "$normalized_link" =~ ^https://github\.com/[^/]+$ ]]; then
                continue
            fi

            ((NEW_COUNT++))
            echo "- <$normalized_link> (from: $source)" >> "$OUTPUT_FILE"
        fi
    done < "$TEMP_DIR/all_new_links.txt"
fi

echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "Total new links found: $NEW_COUNT" >> "$OUTPUT_FILE"

# Summary
echo ""
echo -e "${YELLOW}=== Summary ===${NC}"
echo -e "${BLUE}Repositories searched:${NC} $REPO_COUNT"
echo -e "${BLUE}Existing links in README:${NC} $EXISTING_COUNT"
echo -e "${GREEN}New links found:${NC} $NEW_COUNT"
echo ""

if [ $NEW_COUNT -gt 0 ]; then
    echo -e "${GREEN}Results saved to:${NC} $OUTPUT_FILE"
    echo ""
    echo -e "${YELLOW}Preview of new links:${NC}"
    grep "^- <" "$OUTPUT_FILE" | head -15
else
    echo -e "${GREEN}No new links found - your README is comprehensive!${NC}"
    rm -f "$OUTPUT_FILE"
fi
