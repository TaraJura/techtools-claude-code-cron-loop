#!/bin/bash
# update-impact-analyzer.sh - Analyze dependencies between system components
# Identifies: which files depend on which, blast radius of changes, coupling metrics

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/impact-analysis.json"
WEB_ROOT="/var/www/cronloop.techtools.cz"
HOME_ROOT="/home/novakj"
SCRIPTS_DIR="$HOME_ROOT/scripts"
ACTORS_DIR="$HOME_ROOT/actors"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create temp files
TMP_HTML_DEPS=$(mktemp)
TMP_SCRIPT_DEPS=$(mktemp)
TMP_PROMPT_DEPS=$(mktemp)
TMP_NODE_DATA=$(mktemp)
TMP_EDGE_DATA=$(mktemp)

cleanup() {
    rm -f "$TMP_HTML_DEPS" "$TMP_SCRIPT_DEPS" "$TMP_PROMPT_DEPS" "$TMP_NODE_DATA" "$TMP_EDGE_DATA"
}
trap cleanup EXIT

# ============================================================
# 1. Analyze HTML -> API dependencies (which pages fetch which APIs)
# ============================================================
analyze_html_api_deps() {
    for html in "$WEB_ROOT"/*.html; do
        [ -f "$html" ] || continue
        local page=$(basename "$html")

        # Find all API fetches in HTML file
        grep -oE "fetch\(['\"][^'\"]*\.json" "$html" 2>/dev/null | \
            grep -oE "[a-zA-Z0-9_-]+\.json" | \
            sort -u | while read api; do
            echo "$page,$api,html_to_api" >> "$TMP_HTML_DEPS"
        done
    done
}

# ============================================================
# 2. Analyze Script -> JSON dependencies (which scripts update which APIs)
# ============================================================
analyze_script_json_deps() {
    for script in "$SCRIPTS_DIR"/*.sh "$SCRIPTS_DIR"/*.py; do
        [ -f "$script" ] || continue
        local script_name=$(basename "$script")

        # Find JSON files written by scripts (OUTPUT_FILE patterns)
        grep -oE 'OUTPUT_FILE="[^"]+\.json"' "$script" 2>/dev/null | \
            grep -oE "[a-zA-Z0-9_-]+\.json" | while read json; do
            echo "$script_name,$json,script_updates_api" >> "$TMP_SCRIPT_DEPS"
        done

        # Also look for direct writes to /api/ paths
        grep -oE '>/var/www/cronloop\.techtools\.cz/api/[a-zA-Z0-9_-]+\.json' "$script" 2>/dev/null | \
            grep -oE "[a-zA-Z0-9_-]+\.json" | while read json; do
            echo "$script_name,$json,script_updates_api" >> "$TMP_SCRIPT_DEPS"
        done

        # Look for echo/cat to API files
        grep -oE 'api/[a-zA-Z0-9_-]+\.json' "$script" 2>/dev/null | \
            grep -oE "[a-zA-Z0-9_-]+\.json" | while read json; do
            echo "$script_name,$json,script_uses_api" >> "$TMP_SCRIPT_DEPS"
        done
    done
}

# ============================================================
# 3. Analyze Agent Prompt -> Config dependencies
# ============================================================
analyze_prompt_deps() {
    for prompt in "$ACTORS_DIR"/*/prompt.md; do
        [ -f "$prompt" ] || continue
        local agent=$(basename $(dirname "$prompt"))

        # Find references to files in prompts
        # Look for paths, filenames, and config references
        grep -oE '/home/novakj/[a-zA-Z0-9_/.-]+' "$prompt" 2>/dev/null | while read path; do
            local target=$(basename "$path")
            echo "${agent}_prompt,$target,prompt_references" >> "$TMP_PROMPT_DEPS"
        done

        # Look for .md file references
        grep -oE '[a-zA-Z0-9_-]+\.md' "$prompt" 2>/dev/null | while read md_file; do
            echo "${agent}_prompt,$md_file,prompt_references" >> "$TMP_PROMPT_DEPS"
        done

        # Look for .sh script references
        grep -oE '[a-zA-Z0-9_-]+\.sh' "$prompt" 2>/dev/null | while read sh_file; do
            echo "${agent}_prompt,$sh_file,prompt_references" >> "$TMP_PROMPT_DEPS"
        done
    done
}

# Run all analyses
analyze_html_api_deps
analyze_script_json_deps
analyze_prompt_deps

# ============================================================
# 4. Build dependency graph data structures
# ============================================================

# Count dependencies for each file
declare -A DEPENDENTS_COUNT
declare -A DEPENDENCIES_COUNT

# Count incoming edges (dependents - files that depend on this one)
while IFS=',' read -r source target type; do
    [ -z "$target" ] && continue
    DEPENDENTS_COUNT[$target]=$((${DEPENDENTS_COUNT[$target]:-0} + 1))
    DEPENDENCIES_COUNT[$source]=$((${DEPENDENCIES_COUNT[$source]:-0} + 1))
done < <(cat "$TMP_HTML_DEPS" "$TMP_SCRIPT_DEPS" "$TMP_PROMPT_DEPS" 2>/dev/null | sort -u)

# Calculate risk scores
calculate_risk() {
    local file="$1"
    local dependents=${DEPENDENTS_COUNT[$file]:-0}
    local risk="low"

    if [ "$dependents" -ge 10 ]; then
        risk="critical"
    elif [ "$dependents" -ge 5 ]; then
        risk="high"
    elif [ "$dependents" -ge 2 ]; then
        risk="medium"
    fi

    echo "$risk"
}

# ============================================================
# 5. Build JSON output
# ============================================================

# Get git churn data for files (how often they change)
get_git_churn() {
    local file="$1"
    local full_path=""

    # Try to find the file
    if [ -f "$WEB_ROOT/$file" ]; then
        full_path="$WEB_ROOT/$file"
    elif [ -f "$WEB_ROOT/api/$file" ]; then
        full_path="$WEB_ROOT/api/$file"
    elif [ -f "$SCRIPTS_DIR/$file" ]; then
        full_path="$SCRIPTS_DIR/$file"
    elif [ -f "$HOME_ROOT/$file" ]; then
        full_path="$HOME_ROOT/$file"
    fi

    if [ -n "$full_path" ]; then
        # Count commits in last 30 days
        cd "$HOME_ROOT" 2>/dev/null
        git log --oneline --since="30 days ago" -- "$full_path" 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# Collect all unique nodes (files)
declare -A ALL_NODES
while IFS=',' read -r source target type; do
    ALL_NODES[$source]=1
    ALL_NODES[$target]=1
done < <(cat "$TMP_HTML_DEPS" "$TMP_SCRIPT_DEPS" "$TMP_PROMPT_DEPS" 2>/dev/null | sort -u)

# Determine node type
get_node_type() {
    local file="$1"

    if [[ "$file" == *.html ]]; then
        echo "html_page"
    elif [[ "$file" == *.json ]]; then
        echo "api_data"
    elif [[ "$file" == *.sh ]]; then
        echo "script"
    elif [[ "$file" == *.py ]]; then
        echo "script"
    elif [[ "$file" == *_prompt ]]; then
        echo "agent_prompt"
    elif [[ "$file" == *.md ]]; then
        echo "documentation"
    else
        echo "other"
    fi
}

# Calculate summary metrics
TOTAL_NODES=${#ALL_NODES[@]}
TOTAL_EDGES=$(cat "$TMP_HTML_DEPS" "$TMP_SCRIPT_DEPS" "$TMP_PROMPT_DEPS" 2>/dev/null | sort -u | wc -l)

# Count by risk level
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0

for file in "${!ALL_NODES[@]}"; do
    risk=$(calculate_risk "$file")
    case $risk in
        critical) CRITICAL_COUNT=$((CRITICAL_COUNT + 1)) ;;
        high) HIGH_COUNT=$((HIGH_COUNT + 1)) ;;
        medium) MEDIUM_COUNT=$((MEDIUM_COUNT + 1)) ;;
        low) LOW_COUNT=$((LOW_COUNT + 1)) ;;
    esac
done

# Count high-impact files (many dependents)
HIGH_IMPACT_FILES=0
for file in "${!ALL_NODES[@]}"; do
    [ "${DEPENDENTS_COUNT[$file]:-0}" -ge 5 ] && HIGH_IMPACT_FILES=$((HIGH_IMPACT_FILES + 1))
done

# Count isolated files (no dependencies either way)
ISOLATED_COUNT=0
for file in "${!ALL_NODES[@]}"; do
    deps=${DEPENDENCIES_COUNT[$file]:-0}
    depents=${DEPENDENTS_COUNT[$file]:-0}
    [ "$deps" -eq 0 ] && [ "$depents" -eq 0 ] && ISOLATED_COUNT=$((ISOLATED_COUNT + 1))
done

# Calculate coupling score (average edges per node)
if [ "$TOTAL_NODES" -gt 0 ]; then
    COUPLING_SCORE=$(echo "scale=2; $TOTAL_EDGES * 2 / $TOTAL_NODES" | bc)
else
    COUPLING_SCORE="0"
fi

# Start building JSON
cat > "$OUTPUT_FILE" << EOF
{
  "generated": "$TIMESTAMP",
  "summary": {
    "total_components": $TOTAL_NODES,
    "total_dependencies": $TOTAL_EDGES,
    "coupling_score": $COUPLING_SCORE,
    "high_impact_files": $HIGH_IMPACT_FILES,
    "isolated_files": $ISOLATED_COUNT,
    "risk_distribution": {
      "critical": $CRITICAL_COUNT,
      "high": $HIGH_COUNT,
      "medium": $MEDIUM_COUNT,
      "low": $LOW_COUNT
    }
  },
  "nodes": [
EOF

# Output all nodes
FIRST=true
for file in "${!ALL_NODES[@]}"; do
    [ -z "$file" ] && continue

    type=$(get_node_type "$file")
    dependents=${DEPENDENTS_COUNT[$file]:-0}
    dependencies=${DEPENDENCIES_COUNT[$file]:-0}
    risk=$(calculate_risk "$file")
    churn=$(get_git_churn "$file")

    # Calculate blast radius (total downstream files that could be affected)
    blast_radius=$dependents

    if [ "$FIRST" = "true" ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    # Escape special characters in filename
    safe_file=$(echo "$file" | sed 's/"/\\"/g')

    printf '    {"id": "%s", "type": "%s", "dependents": %d, "dependencies": %d, "risk": "%s", "churn": %d, "blast_radius": %d}' \
        "$safe_file" "$type" "$dependents" "$dependencies" "$risk" "$churn" "$blast_radius" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# Output all edges
echo '  "edges": [' >> "$OUTPUT_FILE"

FIRST=true
while IFS=',' read -r source target type; do
    [ -z "$source" ] || [ -z "$target" ] && continue

    if [ "$FIRST" = "true" ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    safe_source=$(echo "$source" | sed 's/"/\\"/g')
    safe_target=$(echo "$target" | sed 's/"/\\"/g')

    printf '    {"from": "%s", "to": "%s", "type": "%s"}' \
        "$safe_source" "$safe_target" "$type" >> "$OUTPUT_FILE"
done < <(cat "$TMP_HTML_DEPS" "$TMP_SCRIPT_DEPS" "$TMP_PROMPT_DEPS" 2>/dev/null | sort -u)

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# High-impact files (files with most dependents - changing them affects many things)
echo '  "high_impact_files": [' >> "$OUTPUT_FILE"

FIRST=true
for file in "${!DEPENDENTS_COUNT[@]}"; do
    deps=${DEPENDENTS_COUNT[$file]}
    [ "$deps" -lt 3 ] && continue

    type=$(get_node_type "$file")
    risk=$(calculate_risk "$file")

    if [ "$FIRST" = "true" ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    safe_file=$(echo "$file" | sed 's/"/\\"/g')
    printf '    {"file": "%s", "type": "%s", "dependents": %d, "risk": "%s"}' \
        "$safe_file" "$type" "$deps" "$risk" >> "$OUTPUT_FILE"
done | sort -t':' -k3 -rn >> "$OUTPUT_FILE" 2>/dev/null || true

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# Fragile dependencies (high churn + high impact)
echo '  "fragile_dependencies": [' >> "$OUTPUT_FILE"

FIRST=true
for file in "${!DEPENDENTS_COUNT[@]}"; do
    deps=${DEPENDENTS_COUNT[$file]}
    [ "$deps" -lt 2 ] && continue

    churn=$(get_git_churn "$file")
    [ "$churn" -lt 3 ] && continue

    # This file is fragile: changes often and has many dependents
    type=$(get_node_type "$file")

    if [ "$FIRST" = "true" ]; then
        FIRST=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    safe_file=$(echo "$file" | sed 's/"/\\"/g')
    printf '    {"file": "%s", "type": "%s", "dependents": %d, "recent_changes": %d, "risk": "fragile"}' \
        "$safe_file" "$type" "$deps" "$churn" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# Decoupling opportunities (files with >10 dependents that could be abstracted)
echo '  "decoupling_suggestions": [' >> "$OUTPUT_FILE"

FIRST=true
for file in "${!DEPENDENTS_COUNT[@]}"; do
    deps=${DEPENDENTS_COUNT[$file]}
    [ "$deps" -lt 8 ] && continue

    type=$(get_node_type "$file")

    # Generate suggestion based on file type
    suggestion=""
    if [[ "$file" == *.json ]]; then
        suggestion="Consider versioning this API or adding abstraction layer"
    elif [[ "$file" == *.sh ]]; then
        suggestion="Consider splitting into smaller modules"
    elif [[ "$file" == *.html ]]; then
        suggestion="Extract common components to shared JS"
    fi

    if [ -n "$suggestion" ]; then
        if [ "$FIRST" = "true" ]; then
            FIRST=false
        else
            echo "," >> "$OUTPUT_FILE"
        fi

        safe_file=$(echo "$file" | sed 's/"/\\"/g')
        printf '    {"file": "%s", "dependents": %d, "suggestion": "%s"}' \
            "$safe_file" "$deps" "$suggestion" >> "$OUTPUT_FILE"
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# Dependency types breakdown
HTML_TO_API=$(grep -c "html_to_api" "$TMP_HTML_DEPS" 2>/dev/null || echo "0")
SCRIPT_UPDATES=$(grep -c "script_updates_api" "$TMP_SCRIPT_DEPS" 2>/dev/null || echo "0")
PROMPT_REFS=$(grep -c "prompt_references" "$TMP_PROMPT_DEPS" 2>/dev/null || echo "0")

cat >> "$OUTPUT_FILE" << EOF
  "dependency_types": {
    "html_to_api": $HTML_TO_API,
    "script_to_api": $SCRIPT_UPDATES,
    "prompt_to_config": $PROMPT_REFS
  }
}
EOF

echo "Impact analysis updated: $OUTPUT_FILE"
