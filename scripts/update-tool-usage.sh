#!/bin/bash
# update-tool-usage.sh - Analyze Claude Code tool and command usage frequency
# Parses agent session JSONL files to extract tool call statistics
# Output: /var/www/cronloop.techtools.cz/api/tool-usage.json

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/tool-usage.json"
CLAUDE_DIR="/home/novakj/.claude/projects/-home-novakj"
ACTORS_DIR="/home/novakj/actors"
DAYS_TO_ANALYZE=7
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create temp files
TEMP_TOOLS=$(mktemp)
TEMP_BASH=$(mktemp)
TEMP_AGENT_TOOLS=$(mktemp)
TEMP_COMBOS=$(mktemp)

# Calculate cutoff timestamp
cutoff_date=$(date -d "$DAYS_TO_ANALYZE days ago" +%Y-%m-%dT00:00:00Z)

# Get list of recent JSONL session files
echo "Analyzing Claude Code sessions from last $DAYS_TO_ANALYZE days..."

# Process each JSONL session file modified in last N days
for session_file in $(find "$CLAUDE_DIR" -name "*.jsonl" -mtime -$DAYS_TO_ANALYZE -type f 2>/dev/null); do
    # Extract tool_use entries
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' "$session_file" 2>/dev/null >> "$TEMP_TOOLS"

    # Extract Bash commands
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command' "$session_file" 2>/dev/null >> "$TEMP_BASH"
done

# Also process agent logs to correlate tool usage with agents
for agent_dir in "$ACTORS_DIR"/*/; do
    agent_name=$(basename "$agent_dir")
    logs_dir="$agent_dir/logs"

    [ -d "$logs_dir" ] || continue

    # Count logs from last N days as a proxy for runs
    run_count=$(find "$logs_dir" -name "*.log" -mtime -$DAYS_TO_ANALYZE -type f 2>/dev/null | wc -l)

    # Estimate tool usage based on common patterns in logs
    # Since we can't directly correlate sessions to agents, we'll track run counts
    echo "$agent_name:$run_count" >> "$TEMP_AGENT_TOOLS"
done

# Count tool usage
echo "Counting tool usage frequencies..."

# Tool counts
declare -A tool_counts
while IFS= read -r tool; do
    [[ -z "$tool" ]] && continue
    tool_counts[$tool]=$(( ${tool_counts[$tool]:-0} + 1 ))
done < "$TEMP_TOOLS"

total_tool_calls=0
for count in "${tool_counts[@]}"; do
    total_tool_calls=$((total_tool_calls + count))
done

# Bash command analysis
echo "Analyzing Bash commands..."

declare -A bash_commands
declare -A bash_categories

# Categorize bash commands
while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue

    # Extract the base command (first word)
    base_cmd=$(echo "$cmd" | awk '{print $1}' | sed 's/^sudo //')

    # Clean up common prefixes
    base_cmd=$(echo "$base_cmd" | sed 's|.*/||')  # Remove path prefix

    # Skip empty
    [[ -z "$base_cmd" ]] && continue

    # Count base command
    bash_commands[$base_cmd]=$(( ${bash_commands[$base_cmd]:-0} + 1 ))

    # Categorize
    case "$base_cmd" in
        git) bash_categories["git"]=$(( ${bash_categories["git"]:-0} + 1 )) ;;
        ls|cat|head|tail|less|wc|find|grep|awk|sed|cut|sort|uniq|tr)
            bash_categories["file_ops"]=$(( ${bash_categories["file_ops"]:-0} + 1 )) ;;
        cp|mv|rm|mkdir|touch|chmod|chown)
            bash_categories["file_mgmt"]=$(( ${bash_categories["file_mgmt"]:-0} + 1 )) ;;
        curl|wget)
            bash_categories["network"]=$(( ${bash_categories["network"]:-0} + 1 )) ;;
        npm|node|yarn|pnpm)
            bash_categories["nodejs"]=$(( ${bash_categories["nodejs"]:-0} + 1 )) ;;
        python|python3|pip|pip3)
            bash_categories["python"]=$(( ${bash_categories["python"]:-0} + 1 )) ;;
        systemctl|service|journalctl)
            bash_categories["systemd"]=$(( ${bash_categories["systemd"]:-0} + 1 )) ;;
        docker|docker-compose)
            bash_categories["docker"]=$(( ${bash_categories["docker"]:-0} + 1 )) ;;
        jq|yq)
            bash_categories["json_yaml"]=$(( ${bash_categories["json_yaml"]:-0} + 1 )) ;;
        date|echo|printf|sleep)
            bash_categories["utils"]=$(( ${bash_categories["utils"]:-0} + 1 )) ;;
        *)
            bash_categories["other"]=$(( ${bash_categories["other"]:-0} + 1 )) ;;
    esac
done < "$TEMP_BASH"

total_bash_cmds=0
for count in "${bash_commands[@]}"; do
    total_bash_cmds=$((total_bash_cmds + count))
done

# Calculate tool combos (tools used frequently together)
# Read tool usage in sequence and track pairs
echo "Analyzing tool combinations..."
prev_tool=""
declare -A tool_combos
while IFS= read -r tool; do
    [[ -z "$tool" ]] && continue
    if [[ -n "$prev_tool" && "$prev_tool" != "$tool" ]]; then
        combo="$prev_tool→$tool"
        tool_combos[$combo]=$(( ${tool_combos[$combo]:-0} + 1 ))
    fi
    prev_tool="$tool"
done < "$TEMP_TOOLS"

# Load agent run counts
declare -A agent_runs
while IFS=: read -r agent count; do
    [[ -n "$agent" ]] && agent_runs[$agent]=$count
done < "$TEMP_AGENT_TOOLS"

# Build JSON output
echo "Generating JSON output..."

{
    echo "{"
    echo "  \"generated\": \"$TIMESTAMP\","
    echo "  \"period_days\": $DAYS_TO_ANALYZE,"

    # Summary stats
    echo "  \"summary\": {"
    echo "    \"total_tool_calls\": $total_tool_calls,"
    echo "    \"total_bash_commands\": $total_bash_cmds,"
    echo "    \"unique_tools\": ${#tool_counts[@]},"
    echo "    \"unique_bash_commands\": ${#bash_commands[@]},"

    # Most used tool
    max_count=0
    most_used=""
    for tool in "${!tool_counts[@]}"; do
        if [[ ${tool_counts[$tool]} -gt $max_count ]]; then
            max_count=${tool_counts[$tool]}
            most_used=$tool
        fi
    done
    echo "    \"most_used_tool\": \"$most_used\","
    echo "    \"most_used_tool_count\": $max_count"
    echo "  },"

    # Tool frequency breakdown
    echo "  \"tools\": {"
    first=true
    # Sort by count descending
    for tool in $(for t in "${!tool_counts[@]}"; do echo "$t:${tool_counts[$t]}"; done | sort -t: -k2 -rn | cut -d: -f1); do
        count=${tool_counts[$tool]}
        pct=0
        if [[ $total_tool_calls -gt 0 ]]; then
            pct=$(awk "BEGIN {printf \"%.1f\", $count * 100 / $total_tool_calls}")
        fi

        [[ $first == false ]] && echo ","
        first=false
        echo -n "    \"$tool\": {\"count\": $count, \"percentage\": $pct}"
    done
    echo ""
    echo "  },"

    # Bash command frequency (top 20)
    echo "  \"bash_commands\": {"
    first=true
    count=0
    for cmd in $(for c in "${!bash_commands[@]}"; do echo "$c:${bash_commands[$c]}"; done | sort -t: -k2 -rn | cut -d: -f1); do
        [[ $count -ge 20 ]] && break
        cnt=${bash_commands[$cmd]}

        [[ $first == false ]] && echo ","
        first=false
        echo -n "    \"$cmd\": $cnt"
        count=$((count + 1))
    done
    echo ""
    echo "  },"

    # Bash command categories
    echo "  \"bash_categories\": {"
    first=true
    for cat in $(for c in "${!bash_categories[@]}"; do echo "$c:${bash_categories[$c]}"; done | sort -t: -k2 -rn | cut -d: -f1); do
        cnt=${bash_categories[$cat]}
        pct=0
        if [[ $total_bash_cmds -gt 0 ]]; then
            pct=$(awk "BEGIN {printf \"%.1f\", $cnt * 100 / $total_bash_cmds}")
        fi

        [[ $first == false ]] && echo ","
        first=false
        echo -n "    \"$cat\": {\"count\": $cnt, \"percentage\": $pct}"
    done
    echo ""
    echo "  },"

    # Tool combos (top 10)
    echo "  \"tool_combinations\": ["
    first=true
    count=0
    for combo in $(for c in "${!tool_combos[@]}"; do echo "$c:${tool_combos[$c]}"; done | sort -t: -k2 -rn | head -10 | cut -d: -f1); do
        [[ $count -ge 10 ]] && break
        cnt=${tool_combos[$combo]}

        [[ $first == false ]] && echo ","
        first=false
        echo -n "    {\"sequence\": \"$combo\", \"count\": $cnt}"
        count=$((count + 1))
    done
    echo ""
    echo "  ],"

    # Agent run counts (as context for correlation)
    echo "  \"agent_runs\": {"
    first=true
    for agent in "${!agent_runs[@]}"; do
        runs=${agent_runs[$agent]}
        [[ $runs -eq 0 ]] && continue

        [[ $first == false ]] && echo ","
        first=false
        echo -n "    \"$agent\": $runs"
    done
    echo ""
    echo "  },"

    # Tool efficiency insights
    echo "  \"insights\": ["

    insights=""

    # Check if Read is heavily used
    read_count=${tool_counts["Read"]:-0}
    if [[ $read_count -gt 50 ]]; then
        insights="$insights{\"type\": \"info\", \"message\": \"Read tool used $read_count times - consider batching file reads\"},"
    fi

    # Check for high Bash usage
    bash_count=${tool_counts["Bash"]:-0}
    if [[ $bash_count -gt 100 ]]; then
        insights="$insights{\"type\": \"warning\", \"message\": \"High Bash usage ($bash_count calls) - prefer specialized tools when available\"},"
    fi

    # Check for Edit vs Write ratio
    edit_count=${tool_counts["Edit"]:-0}
    write_count=${tool_counts["Write"]:-0}
    if [[ $write_count -gt $edit_count && $write_count -gt 20 ]]; then
        insights="$insights{\"type\": \"info\", \"message\": \"More Write ($write_count) than Edit ($edit_count) - creating many new files\"},"
    fi

    # Git command usage
    git_count=${bash_categories["git"]:-0}
    if [[ $git_count -gt 0 ]]; then
        insights="$insights{\"type\": \"info\", \"message\": \"Git operations account for ${git_count} bash commands\"},"
    fi

    # Remove trailing comma if present
    insights=${insights%,}

    echo "    $insights"
    echo "  ]"

    echo "}"
} > "$OUTPUT_FILE"

# Cleanup
rm -f "$TEMP_TOOLS" "$TEMP_BASH" "$TEMP_AGENT_TOOLS" "$TEMP_COMBOS"

echo "Tool usage data updated: $OUTPUT_FILE"
echo "  - Total tool calls: $total_tool_calls"
echo "  - Unique tools: ${#tool_counts[@]}"
echo "  - Total bash commands: $total_bash_cmds"
