#!/bin/bash
# update-api-catalog.sh - Generate API catalog for the API Explorer page
# Scans /var/www/cronloop.techtools.cz/api/ for JSON endpoints and builds catalog

set -e

API_DIR="/var/www/cronloop.techtools.cz/api"
WEB_DIR="/var/www/cronloop.techtools.cz"
OUTPUT="$API_DIR/api-catalog.json"
TEMP_FILE=$(mktemp)

echo "Generating API catalog..."

# Start JSON
echo '{' > "$TEMP_FILE"
echo '  "generated": "'$(date -Iseconds)'",' >> "$TEMP_FILE"
echo '  "endpoints": [' >> "$TEMP_FILE"

# Track if first entry
first=true

# Scan all JSON files in API directory
for file in "$API_DIR"/*.json; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")

        # Skip the catalog file itself
        if [ "$filename" = "api-catalog.json" ]; then
            continue
        fi

        # Get file stats
        size=$(stat -c %s "$file" 2>/dev/null || echo 0)
        modified=$(stat -c %Y "$file" 2>/dev/null || echo 0)
        modified_iso=$(date -d "@$modified" -Iseconds 2>/dev/null || date -Iseconds)

        # Check if valid JSON
        valid="true"
        if ! jq empty "$file" 2>/dev/null; then
            valid="false"
        fi

        # Add comma before entry (except first)
        if [ "$first" = true ]; then
            first=false
        else
            echo ',' >> "$TEMP_FILE"
        fi

        # Write entry
        echo -n "    {\"name\": \"$filename\", \"path\": \"/api/$filename\", \"size\": $size, \"modified\": \"$modified_iso\", \"valid\": $valid}" >> "$TEMP_FILE"
    fi
done

echo '' >> "$TEMP_FILE"
echo '  ],' >> "$TEMP_FILE"

# Find HTML references to API endpoints
echo '  "references": [' >> "$TEMP_FILE"

# Scan HTML files for API references
referenced_apis=""
first_ref=true

for html_file in "$WEB_DIR"/*.html; do
    if [ -f "$html_file" ]; then
        # Extract API endpoint references
        while IFS= read -r api_ref; do
            if [ -n "$api_ref" ]; then
                # Check if already added
                if [[ ! "$referenced_apis" =~ "$api_ref" ]]; then
                    if [ "$first_ref" = true ]; then
                        first_ref=false
                    else
                        echo ',' >> "$TEMP_FILE"
                    fi
                    echo -n "    \"$api_ref\"" >> "$TEMP_FILE"
                    referenced_apis="$referenced_apis $api_ref"
                fi
            fi
        done < <(grep -oP "(?<=/api/)[a-zA-Z0-9_-]+\.json" "$html_file" 2>/dev/null | sort -u)
    fi
done

echo '' >> "$TEMP_FILE"
echo '  ],' >> "$TEMP_FILE"

# Add summary stats
total_endpoints=$(ls -1 "$API_DIR"/*.json 2>/dev/null | wc -l)
total_size=$(du -sb "$API_DIR" 2>/dev/null | cut -f1 || echo 0)

echo "  \"stats\": {" >> "$TEMP_FILE"
echo "    \"total_endpoints\": $((total_endpoints - 1))," >> "$TEMP_FILE"  # -1 for catalog itself
echo "    \"total_size\": $total_size," >> "$TEMP_FILE"
echo "    \"referenced_count\": $(echo "$referenced_apis" | wc -w)" >> "$TEMP_FILE"
echo "  }" >> "$TEMP_FILE"

echo '}' >> "$TEMP_FILE"

# Validate and move to output
if jq empty "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_FILE" "$OUTPUT"
    echo "API catalog generated: $OUTPUT"
else
    echo "Error: Generated JSON is invalid"
    cat "$TEMP_FILE"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Make readable by web server
chmod 644 "$OUTPUT"

echo "Done! Generated catalog with $((total_endpoints - 1)) endpoints"
