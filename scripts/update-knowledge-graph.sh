#!/bin/bash
# update-knowledge-graph.sh - Build knowledge graph from agent file access patterns
# Parses Claude Code JSONL session files to extract:
# - Which files are read together (co-access patterns)
# - Which files are modified after reading others
# - File access frequency by agent
# - Relationship inference from access patterns

OUTPUT_DIR="/var/www/cronloop.techtools.cz/api"
OUTPUT_FILE="$OUTPUT_DIR/knowledge-graph.json"
SESSIONS_DIR="/home/novakj/.claude/projects/-home-novakj"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Temporary files for aggregation
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Get sessions from last 7 days - find recent files by modification time
echo "Analyzing Claude Code sessions from $SESSIONS_DIR..."

session_count=0
cutoff_epoch=$(date -d "7 days ago" +%s 2>/dev/null || date -v-7d +%s)

# Process each JSONL session file
for session_file in "$SESSIONS_DIR"/*.jsonl; do
    [ -f "$session_file" ] || continue

    # Check if file is recent enough (by modification time)
    file_date=$(stat -c %Y "$session_file" 2>/dev/null || stat -f %m "$session_file" 2>/dev/null)
    [ -z "$file_date" ] && continue

    if [ "$file_date" -lt "$cutoff_epoch" ]; then
        continue
    fi

    ((session_count++))

    # Extract tool calls using jq with slurp to handle the whole file
    # Filter for tool_use messages and extract file paths
    jq -r '
        .message.content[]? |
        select(.type == "tool_use") |
        select(.name == "Read" or .name == "Edit" or .name == "Write" or .name == "Glob" or .name == "Grep") |
        "\(.name)\t\(.input.file_path // .input.path // .input.pattern // "")"
    ' "$session_file" 2>/dev/null >> "$TEMP_DIR/operations.txt"

done

echo "Processed $session_count session files"

# Create empty operations file if none exists
touch "$TEMP_DIR/operations.txt"

# Count file accesses - aggregate by file path (regardless of operation type)
echo "Building access counts..."
cut -f2 "$TEMP_DIR/operations.txt" 2>/dev/null | sort | uniq -c | sort -rn > "$TEMP_DIR/access_counts.txt"

# Find co-occurring files (files accessed sequentially in same sessions)
echo "Finding file relationships..."
awk -F'\t' '
    NR > 1 && prev_file && $2 && prev_file != $2 && $2 !~ /\*/ && prev_file !~ /\*/ {
        f1 = prev_file
        f2 = $2
        if (f1 > f2) { tmp = f1; f1 = f2; f2 = tmp }
        pairs[f1 "\t" f2]++
    }
    { prev_file = $2 }
    END {
        for (pair in pairs) {
            print pairs[pair] "\t" pair
        }
    }
' "$TEMP_DIR/operations.txt" 2>/dev/null | sort -rn > "$TEMP_DIR/file_pairs.txt"

# Find read-then-write patterns (causal relationships)
echo "Finding causal patterns..."
awk -F'\t' '
    $1 == "Read" { last_read = $2 }
    ($1 == "Edit" || $1 == "Write") && last_read && last_read != $2 && $2 !~ /\*/ && last_read !~ /\*/ {
        print last_read "\t" $2
    }
' "$TEMP_DIR/operations.txt" 2>/dev/null | sort | uniq -c | sort -rn > "$TEMP_DIR/read_write.txt"

# Build JSON output
echo "Generating JSON output..."

{
    echo "{"
    echo '  "generated": "'$(date -Iseconds)'",'
    echo '  "period_days": 7,'
    echo '  "sessions_analyzed": '$session_count','

    # Summary stats
    total_files=$(cut -f2 "$TEMP_DIR/operations.txt" 2>/dev/null | grep -v '\*' | sort -u | wc -l)
    total_files=$((total_files > 0 ? total_files : 0))
    total_ops=$(wc -l < "$TEMP_DIR/operations.txt" 2>/dev/null || echo 0)
    total_ops=$((total_ops > 0 ? total_ops : 0))
    unique_rel=$(wc -l < "$TEMP_DIR/file_pairs.txt" 2>/dev/null || echo 0)
    unique_rel=$((unique_rel > 0 ? unique_rel : 0))

    echo '  "summary": {'
    echo '    "total_files_touched": '$total_files','
    echo '    "total_operations": '$total_ops','
    echo '    "unique_relationships": '$unique_rel
    echo '  },'

    # Nodes (files with their access counts)
    echo '  "nodes": ['
    first=true
    while read -r line; do
        [ -z "$line" ] && continue

        count=$(echo "$line" | awk '{print $1}')
        filepath=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')

        [ -z "$filepath" ] && continue
        [[ "$filepath" == *"*"* ]] && continue
        [[ "$filepath" == "" ]] && continue

        # Determine file type
        ext="${filepath##*.}"
        case "$ext" in
            html) ftype="web" ;;
            js|ts) ftype="script" ;;
            css) ftype="web" ;;
            sh|bash) ftype="script" ;;
            md) ftype="docs" ;;
            json) ftype="data" ;;
            log) ftype="logs" ;;
            py) ftype="script" ;;
            *) ftype="other" ;;
        esac

        # Get basename for display
        basename=$(basename "$filepath" 2>/dev/null || echo "$filepath")

        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        # Escape special characters in filepath for JSON
        filepath_escaped=$(printf '%s' "$filepath" | sed 's/\\/\\\\/g; s/"/\\"/g')
        basename_escaped=$(printf '%s' "$basename" | sed 's/\\/\\\\/g; s/"/\\"/g')

        printf '    {"id": "%s", "label": "%s", "type": "%s", "access_count": %d}' \
            "$filepath_escaped" "$basename_escaped" "$ftype" "$count"
    done < <(head -100 "$TEMP_DIR/access_counts.txt")
    echo ""
    echo '  ],'

    # Edges (file relationships)
    echo '  "edges": ['
    first=true
    while read -r line; do
        [ -z "$line" ] && continue

        weight=$(echo "$line" | awk '{print $1}')
        file1=$(echo "$line" | cut -f2)
        file2=$(echo "$line" | cut -f3)

        [ -z "$file1" ] || [ -z "$file2" ] && continue
        [[ "$file1" == *"*"* ]] && continue
        [[ "$file2" == *"*"* ]] && continue

        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        file1_escaped=$(printf '%s' "$file1" | sed 's/\\/\\\\/g; s/"/\\"/g')
        file2_escaped=$(printf '%s' "$file2" | sed 's/\\/\\\\/g; s/"/\\"/g')

        printf '    {"source": "%s", "target": "%s", "weight": %d, "type": "co-access"}' \
            "$file1_escaped" "$file2_escaped" "$weight"
    done < <(head -200 "$TEMP_DIR/file_pairs.txt")
    echo ""
    echo '  ],'

    # Causal relationships (read then write)
    echo '  "causal_edges": ['
    first=true
    while read -r line; do
        [ -z "$line" ] && continue

        weight=$(echo "$line" | awk '{print $1}')
        source=$(echo "$line" | cut -f2)
        target=$(echo "$line" | cut -f3)

        [ -z "$source" ] || [ -z "$target" ] && continue
        [[ "$source" == *"*"* ]] && continue
        [[ "$target" == *"*"* ]] && continue

        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        source_escaped=$(printf '%s' "$source" | sed 's/\\/\\\\/g; s/"/\\"/g')
        target_escaped=$(printf '%s' "$target" | sed 's/\\/\\\\/g; s/"/\\"/g')

        printf '    {"source": "%s", "target": "%s", "weight": %d, "type": "read-then-write"}' \
            "$source_escaped" "$target_escaped" "$weight"
    done < <(head -100 "$TEMP_DIR/read_write.txt")
    echo ""
    echo '  ],'

    # Hot files (most accessed)
    echo '  "hot_files": ['
    first=true
    while read -r line; do
        [ -z "$line" ] && continue

        count=$(echo "$line" | awk '{print $1}')
        filepath=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')

        [ -z "$filepath" ] && continue
        [[ "$filepath" == *"*"* ]] && continue

        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi

        filepath_escaped=$(printf '%s' "$filepath" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '    {"path": "%s", "count": %d}' "$filepath_escaped" "$count"
    done < <(head -20 "$TEMP_DIR/access_counts.txt")
    echo ""
    echo '  ],'

    # File clusters (inferred from co-access patterns)
    echo '  "clusters": ['

    # Web cluster
    web_count=$(grep -E '\.html|\.css' "$TEMP_DIR/access_counts.txt" 2>/dev/null | wc -l)
    echo '    {"name": "Web App", "pattern": "*.html, *.css, *.js", "file_count": '$((web_count > 0 ? web_count : 0))'},'

    # Scripts cluster
    script_count=$(grep -E '\.sh|\.py' "$TEMP_DIR/access_counts.txt" 2>/dev/null | wc -l)
    echo '    {"name": "Scripts", "pattern": "*.sh, *.py", "file_count": '$((script_count > 0 ? script_count : 0))'},'

    # Docs cluster
    docs_count=$(grep -E '\.md' "$TEMP_DIR/access_counts.txt" 2>/dev/null | wc -l)
    echo '    {"name": "Documentation", "pattern": "*.md", "file_count": '$((docs_count > 0 ? docs_count : 0))'},'

    # Data cluster
    data_count=$(grep -E '\.json' "$TEMP_DIR/access_counts.txt" 2>/dev/null | wc -l)
    echo '    {"name": "Data", "pattern": "*.json", "file_count": '$((data_count > 0 ? data_count : 0))'}'

    echo '  ],'

    # Knowledge gaps (files that might cause issues) - empty for now
    echo '  "knowledge_gaps": []'

    echo "}"
} > "$OUTPUT_FILE"

# Validate JSON
if python3 -c "import json; json.load(open('$OUTPUT_FILE'))" 2>/dev/null; then
    echo "Successfully generated knowledge graph at $OUTPUT_FILE"
    echo "Nodes: $(jq '.nodes | length' "$OUTPUT_FILE" 2>/dev/null || echo 0)"
    echo "Edges: $(jq '.edges | length' "$OUTPUT_FILE" 2>/dev/null || echo 0)"
else
    echo "Warning: Generated JSON may be invalid"
    head -50 "$OUTPUT_FILE"
fi
