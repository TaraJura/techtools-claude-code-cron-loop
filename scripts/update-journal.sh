#!/bin/bash
# update-journal.sh - Generate agent daily journal entries from logs
# Creates daily narrative entries from each agent's perspective about what they learned, struggled with, and improved

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/journal.json"
ACTORS_DIR="/home/novakj/actors"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)

# Agents to analyze
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Initialize JSON
echo "{" > "$OUTPUT_FILE"
echo "  \"generated\": \"$TIMESTAMP\"," >> "$OUTPUT_FILE"
echo "  \"entries\": [" >> "$OUTPUT_FILE"

first_entry=true

# Process logs from last 7 days
for days_ago in {0..6}; do
    target_date=$(date -d "$days_ago days ago" +%Y-%m-%d 2>/dev/null || date -v-${days_ago}d +%Y-%m-%d)
    date_prefix=$(date -d "$days_ago days ago" +%Y%m%d 2>/dev/null || date -v-${days_ago}d +%Y%m%d)

    for agent in "${AGENTS[@]}"; do
        log_dir="$ACTORS_DIR/$agent/logs"

        if [[ ! -d "$log_dir" ]]; then
            continue
        fi

        # Find logs from this date
        log_files=("$log_dir/${date_prefix}_"*.log)

        # Check if any matching files exist
        if [[ ! -f "${log_files[0]}" ]]; then
            continue
        fi

        # Analyze the day's logs for this agent
        total_runs=0
        success_runs=0
        error_runs=0
        tasks_worked=""
        files_touched=""
        errors_encountered=""
        duration_total=0
        duration_count=0

        for log_file in "${log_files[@]}"; do
            if [[ ! -f "$log_file" ]]; then
                continue
            fi

            total_runs=$((total_runs + 1))

            # Check for errors
            if grep -qi "error\|failed\|exception\|traceback" "$log_file" 2>/dev/null; then
                error_runs=$((error_runs + 1))
                # Extract error messages
                error_msg=$(grep -i "error\|failed\|exception" "$log_file" 2>/dev/null | head -1 | tr -d '\n' | tr -d '"' | cut -c1-100)
                if [[ -n "$error_msg" && -z "$(echo "$errors_encountered" | grep -F "$error_msg" 2>/dev/null)" ]]; then
                    if [[ -n "$errors_encountered" ]]; then
                        errors_encountered="$errors_encountered; $error_msg"
                    else
                        errors_encountered="$error_msg"
                    fi
                fi
            else
                success_runs=$((success_runs + 1))
            fi

            # Extract TASK IDs mentioned
            task_ids=$(grep -oE "TASK-[0-9]+" "$log_file" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$task_ids" ]]; then
                if [[ -n "$tasks_worked" ]]; then
                    # Merge unique tasks
                    for tid in $(echo "$task_ids" | tr ',' ' '); do
                        if [[ ! "$tasks_worked" == *"$tid"* ]]; then
                            tasks_worked="$tasks_worked,$tid"
                        fi
                    done
                else
                    tasks_worked="$task_ids"
                fi
            fi

            # Extract files mentioned (common patterns)
            file_mentions=$(grep -oE "(/[a-zA-Z0-9_/.-]+\.(html|js|sh|json|md|css))" "$log_file" 2>/dev/null | sort -u | head -5 | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$file_mentions" ]]; then
                if [[ -n "$files_touched" ]]; then
                    files_touched="$files_touched,$file_mentions"
                else
                    files_touched="$file_mentions"
                fi
            fi

            # Extract duration if available
            start_time=""
            end_time=""
            while IFS= read -r line; do
                if [[ $line =~ ^Started:\ (.+)$ ]]; then
                    start_time="${BASH_REMATCH[1]}"
                elif [[ $line =~ ^Completed:\ (.+)$ ]]; then
                    end_time="${BASH_REMATCH[1]}"
                fi
            done < "$log_file"

            if [[ -n "$start_time" && -n "$end_time" ]]; then
                start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
                end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo "0")
                if [[ $start_epoch -gt 0 && $end_epoch -gt 0 && $end_epoch -gt $start_epoch ]]; then
                    duration=$((end_epoch - start_epoch))
                    duration_total=$((duration_total + duration))
                    duration_count=$((duration_count + 1))
                fi
            fi
        done

        # Skip if no runs
        if [[ $total_runs -eq 0 ]]; then
            continue
        fi

        # Calculate average duration
        avg_duration=0
        if [[ $duration_count -gt 0 ]]; then
            avg_duration=$((duration_total / duration_count))
        fi

        # Calculate success rate
        success_rate=0
        if [[ $total_runs -gt 0 ]]; then
            success_rate=$((success_runs * 100 / total_runs))
        fi

        # Determine mood based on success rate
        mood="neutral"
        if [[ $success_rate -ge 90 ]]; then
            mood="happy"
        elif [[ $success_rate -ge 70 ]]; then
            mood="content"
        elif [[ $success_rate -ge 50 ]]; then
            mood="concerned"
        else
            mood="frustrated"
        fi

        # Generate narrative entry
        narrative="Today I ran $total_runs times with a $success_rate% success rate."

        if [[ -n "$tasks_worked" ]]; then
            task_count=$(echo "$tasks_worked" | tr ',' '\n' | wc -l)
            narrative="$narrative I worked on $task_count task(s): $tasks_worked."
        fi

        if [[ $error_runs -gt 0 ]]; then
            narrative="$narrative I encountered $error_runs error(s)."
            if [[ -n "$errors_encountered" ]]; then
                narrative="$narrative Challenges: $errors_encountered."
            fi
        fi

        if [[ $avg_duration -gt 0 ]]; then
            if [[ $avg_duration -ge 60 ]]; then
                mins=$((avg_duration / 60))
                secs=$((avg_duration % 60))
                narrative="$narrative Average run took ${mins}m ${secs}s."
            else
                narrative="$narrative Average run took ${avg_duration}s."
            fi
        fi

        # Generate lesson learned (based on patterns)
        lesson=""
        if [[ $success_rate -eq 100 && $total_runs -gt 1 ]]; then
            lesson="All runs successful today - maintaining good practices."
        elif [[ $error_runs -gt 0 && $success_runs -gt 0 ]]; then
            lesson="Mixed results today. Need to investigate the failures and apply lessons to future runs."
        elif [[ $error_runs -gt 0 && $success_runs -eq 0 ]]; then
            lesson="Difficult day with all runs encountering issues. Tomorrow I should focus on stability."
        else
            lesson="Routine day with steady performance."
        fi

        # Generate highlight
        highlight=""
        if [[ -n "$tasks_worked" ]]; then
            highlight="Worked on $tasks_worked"
        elif [[ $success_rate -eq 100 ]]; then
            highlight="100% success rate"
        elif [[ $total_runs -ge 3 ]]; then
            highlight="High activity day with $total_runs runs"
        else
            highlight="Quiet day"
        fi

        # Clean up strings for JSON
        narrative=$(echo "$narrative" | tr -d '\n' | sed 's/"/\\"/g')
        lesson=$(echo "$lesson" | tr -d '\n' | sed 's/"/\\"/g')
        highlight=$(echo "$highlight" | tr -d '\n' | sed 's/"/\\"/g')
        errors_encountered=$(echo "$errors_encountered" | tr -d '\n' | sed 's/"/\\"/g' | cut -c1-200)
        tasks_worked=$(echo "$tasks_worked" | tr -d '\n' | sed 's/"/\\"/g')
        files_touched=$(echo "$files_touched" | tr -d '\n' | sed 's/"/\\"/g' | cut -c1-300)

        # Output JSON entry
        if [[ $first_entry == false ]]; then
            echo "," >> "$OUTPUT_FILE"
        fi
        first_entry=false

        cat >> "$OUTPUT_FILE" << EOF
    {
      "date": "$target_date",
      "agent": "$agent",
      "runs": $total_runs,
      "success": $success_runs,
      "errors": $error_runs,
      "success_rate": $success_rate,
      "mood": "$mood",
      "avg_duration_seconds": $avg_duration,
      "tasks": "$tasks_worked",
      "files": "$files_touched",
      "narrative": "$narrative",
      "lesson": "$lesson",
      "highlight": "$highlight",
      "challenges": "$errors_encountered"
    }
EOF
    done
done

echo "" >> "$OUTPUT_FILE"
echo "  ]," >> "$OUTPUT_FILE"

# Add summary statistics
# Note: grep -c returns exit code 1 when count is 0, so we need special handling
total_entries=$(grep -c '"agent":' "$OUTPUT_FILE" 2>/dev/null) || total_entries=0
unique_dates=$(grep '"date":' "$OUTPUT_FILE" 2>/dev/null | sort -u | wc -l) || unique_dates=0
total_happy=$(grep -c '"mood": "happy"' "$OUTPUT_FILE" 2>/dev/null) || total_happy=0
total_content=$(grep -c '"mood": "content"' "$OUTPUT_FILE" 2>/dev/null) || total_content=0
total_neutral=$(grep -c '"mood": "neutral"' "$OUTPUT_FILE" 2>/dev/null) || total_neutral=0
total_concerned=$(grep -c '"mood": "concerned"' "$OUTPUT_FILE" 2>/dev/null) || total_concerned=0
total_frustrated=$(grep -c '"mood": "frustrated"' "$OUTPUT_FILE" 2>/dev/null) || total_frustrated=0

cat >> "$OUTPUT_FILE" << EOF
  "summary": {
    "total_entries": $total_entries,
    "unique_dates": $unique_dates,
    "mood_distribution": {
      "happy": $total_happy,
      "content": $total_content,
      "neutral": $total_neutral,
      "concerned": $total_concerned,
      "frustrated": $total_frustrated
    }
  }
}
EOF

echo "Journal data updated: $OUTPUT_FILE"
