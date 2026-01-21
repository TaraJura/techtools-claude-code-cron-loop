#!/bin/bash
# update-usage-analytics.sh - Parse nginx logs to track page and API usage
# Detects: ghost pages, orphan APIs, unused features

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/usage-analytics.json"
WEB_ROOT="/var/www/cronloop.techtools.cz"
NGINX_LOG="/var/log/nginx/cronloop.techtools.cz.access.log"
NGINX_LOG_PREV="/var/log/nginx/cronloop.techtools.cz.access.log.1"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create temp files
TMP_PAGE_HITS=$(mktemp)
TMP_API_HITS=$(mktemp)
TMP_PAGE_COUNTS=$(mktemp)
TMP_API_COUNTS=$(mktemp)

cleanup() {
    rm -f "$TMP_PAGE_HITS" "$TMP_API_HITS" "$TMP_PAGE_COUNTS" "$TMP_API_COUNTS"
}
trap cleanup EXIT

# Parse logs for HTML page hits
for log in "$NGINX_LOG" "$NGINX_LOG_PREV"; do
    if [ -f "$log" ] && [ -r "$log" ]; then
        sudo cat "$log" 2>/dev/null | grep -oE "GET /[a-z0-9_-]+\.html" | sed "s/GET \///" >> "$TMP_PAGE_HITS" || true
    fi
done

# Parse logs for API hits
for log in "$NGINX_LOG" "$NGINX_LOG_PREV"; do
    if [ -f "$log" ] && [ -r "$log" ]; then
        sudo cat "$log" 2>/dev/null | grep -oE "GET /api/[a-z0-9_-]+\.json" | sed "s/GET \/api\///" >> "$TMP_API_HITS" || true
    fi
done

# Count hits per page
sort "$TMP_PAGE_HITS" | uniq -c | awk '{print $2","$1}' > "$TMP_PAGE_COUNTS"

# Count hits per API
sort "$TMP_API_HITS" | uniq -c | awk '{print $2","$1}' > "$TMP_API_COUNTS"

# Get all HTML pages
ALL_PAGES=$(find "$WEB_ROOT" -maxdepth 1 -name "*.html" -type f -printf "%f\n" | sort)

# Get all API JSON files
ALL_APIS=$(find "$WEB_ROOT/api" -maxdepth 1 -name "*.json" -type f -printf "%f\n" 2>/dev/null | sort)

# Get pages linked from index.html
LINKED_PAGES=$(grep -oE 'href="[a-z0-9_-]+\.html"' "$WEB_ROOT/index.html" 2>/dev/null | sed 's/href="//;s/"//' | sort -u)

# Helper function to get hit count
get_hits() {
    local name="$1"
    local file="$2"
    grep "^${name}," "$file" 2>/dev/null | cut -d',' -f2 || echo "0"
}

# Find API consumers (HTML pages that reference this API)
find_api_consumers() {
    local api_file="$1"
    local consumers=""
    for html in $ALL_PAGES; do
        if grep -q "$api_file" "$WEB_ROOT/$html" 2>/dev/null; then
            if [ -n "$consumers" ]; then
                consumers="$consumers,$html"
            else
                consumers="$html"
            fi
        fi
    done
    echo "$consumers"
}

# Calculate stats
TOTAL_PAGES=$(echo "$ALL_PAGES" | wc -l)
TOTAL_APIS=$(echo "$ALL_APIS" | grep -c . 2>/dev/null || echo "0")

# Count ghost and popular pages
GHOST_COUNT=0
HIGH_TRAFFIC_COUNT=0
for page in $ALL_PAGES; do
    hits=$(get_hits "$page" "$TMP_PAGE_COUNTS")
    [ -z "$hits" ] && hits=0
    if [ "$hits" -le 5 ]; then
        GHOST_COUNT=$((GHOST_COUNT + 1))
    fi
    if [ "$hits" -ge 100 ]; then
        HIGH_TRAFFIC_COUNT=$((HIGH_TRAFFIC_COUNT + 1))
    fi
done

# Count orphan APIs
ORPHAN_API_COUNT=0
for api in $ALL_APIS; do
    consumers=$(find_api_consumers "$api")
    if [ -z "$consumers" ]; then
        ORPHAN_API_COUNT=$((ORPHAN_API_COUNT + 1))
    fi
done

# Calculate feature adoption score
if [ "$TOTAL_PAGES" -gt 0 ]; then
    ADOPTION_SCORE=$(echo "scale=1; 100 - ($GHOST_COUNT * 100 / $TOTAL_PAGES)" | bc)
else
    ADOPTION_SCORE="0"
fi

# Build JSON output
cat > "$OUTPUT_FILE" << EOF
{
  "generated": "$TIMESTAMP",
  "log_period": "Combined nginx logs (approximately last 2 log rotations)",
  "summary": {
    "total_pages": $TOTAL_PAGES,
    "total_apis": $TOTAL_APIS,
    "ghost_pages": $GHOST_COUNT,
    "orphan_apis": $ORPHAN_API_COUNT,
    "high_traffic_pages": $HIGH_TRAFFIC_COUNT,
    "feature_adoption_score": $ADOPTION_SCORE
  },
  "pages": [
EOF

# Output page data
FIRST=true
for page in $ALL_PAGES; do
    hits=$(get_hits "$page" "$TMP_PAGE_COUNTS")
    [ -z "$hits" ] && hits=0

    modified_time=$(stat -c %Y "$WEB_ROOT/$page" 2>/dev/null || echo "0")
    modified_iso=$(date -d "@$modified_time" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
    size=$(stat -c %s "$WEB_ROOT/$page" 2>/dev/null || echo "0")

    # Check if linked from index
    linked="false"
    if echo "$LINKED_PAGES" | grep -q "^${page}$"; then
        linked="true"
    fi

    # Determine status
    status="active"
    if [ "$hits" -eq 0 ]; then
        status="dead"
    elif [ "$hits" -le 5 ]; then
        status="ghost"
    elif [ "$hits" -ge 100 ]; then
        status="popular"
    fi

    if [ "$FIRST" = "true" ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    printf '    {"page": "%s", "hits": %d, "status": "%s", "linked_from_index": %s, "last_modified": "%s", "size_bytes": %d}' \
        "$page" "$hits" "$status" "$linked" "$modified_iso" "$size" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# Output API data
echo '  "apis": [' >> "$OUTPUT_FILE"

FIRST=true
for api in $ALL_APIS; do
    hits=$(get_hits "$api" "$TMP_API_COUNTS")
    [ -z "$hits" ] && hits=0

    modified_time=$(stat -c %Y "$WEB_ROOT/api/$api" 2>/dev/null || echo "0")
    modified_iso=$(date -d "@$modified_time" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
    size=$(stat -c %s "$WEB_ROOT/api/$api" 2>/dev/null || echo "0")

    consumers=$(find_api_consumers "$api")

    # Determine status
    status="active"
    if [ -z "$consumers" ]; then
        status="orphan"
    elif [ "$hits" -eq 0 ]; then
        status="unused"
    elif [ "$hits" -ge 50 ]; then
        status="popular"
    fi

    # Format consumers as JSON array
    consumers_json="[]"
    if [ -n "$consumers" ]; then
        consumers_json="[\"$(echo "$consumers" | sed 's/,/","/g')\"]"
    fi

    if [ "$FIRST" = "true" ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    printf '    {"api": "%s", "hits": %d, "status": "%s", "consumers": %s, "last_modified": "%s", "size_bytes": %d}' \
        "$api" "$hits" "$status" "$consumers_json" "$modified_iso" "$size" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# Output recommendations
echo '  "recommendations": [' >> "$OUTPUT_FILE"

FIRST=true

# Recommend removing dead pages
for page in $ALL_PAGES; do
    hits=$(get_hits "$page" "$TMP_PAGE_COUNTS")
    [ -z "$hits" ] && hits=0

    if [ "$hits" -eq 0 ] && [ "$page" != "index.html" ]; then
        if [ "$FIRST" = "true" ]; then
            FIRST=false
        else
            echo "," >> "$OUTPUT_FILE"
        fi
        printf '    {"type": "remove", "target": "%s", "reason": "0 visits - dead feature", "priority": "low"}' "$page" >> "$OUTPUT_FILE"
    fi
done

# Recommend promoting ghost pages not linked from index
for page in $ALL_PAGES; do
    hits=$(get_hits "$page" "$TMP_PAGE_COUNTS")
    [ -z "$hits" ] && hits=0

    linked="false"
    if echo "$LINKED_PAGES" | grep -q "^${page}$"; then
        linked="true"
    fi

    if [ "$hits" -gt 0 ] && [ "$hits" -le 5 ] && [ "$linked" = "false" ]; then
        if [ "$FIRST" = "true" ]; then
            FIRST=false
        else
            echo "," >> "$OUTPUT_FILE"
        fi
        printf '    {"type": "promote", "target": "%s", "reason": "only %d visits but not linked from index", "priority": "medium"}' "$page" "$hits" >> "$OUTPUT_FILE"
    fi
done

# Recommend cleaning up orphan APIs
for api in $ALL_APIS; do
    consumers=$(find_api_consumers "$api")
    if [ -z "$consumers" ]; then
        if [ "$FIRST" = "true" ]; then
            FIRST=false
        else
            echo "," >> "$OUTPUT_FILE"
        fi
        printf '    {"type": "cleanup", "target": "api/%s", "reason": "no HTML page uses this API file", "priority": "medium"}' "$api" >> "$OUTPUT_FILE"
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "  ]" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo "Usage analytics updated: $OUTPUT_FILE"
