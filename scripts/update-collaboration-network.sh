#!/bin/bash
# update-collaboration-network.sh - Generate agent collaboration network data
# Parses agent logs and tasks.md to extract collaboration patterns between agents

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/collaboration-network.json"
ACTORS_DIR="/home/novakj/actors"
TASKS_FILE="/home/novakj/tasks.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Agents to analyze
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Initialize collaboration matrix - track which agents work together on tasks
declare -A collaboration_count
declare -A collaboration_success
declare -A agent_runs
declare -A agent_tasks
declare -A handoff_count

# Calculate date ranges
now=$(date +%s)
seven_days_ago=$((now - 7*24*60*60))
thirty_days_ago=$((now - 30*24*60*60))

# Track task IDs seen by each agent
declare -A task_agents

# Process agent logs to find task IDs each agent worked on
for agent in "${AGENTS[@]}"; do
    log_dir="$ACTORS_DIR/$agent/logs"

    if [[ ! -d "$log_dir" ]]; then
        continue
    fi

    agent_runs[$agent]=0
    agent_tasks[$agent]=0

    for log_file in "$log_dir"/*.log; do
        if [[ ! -f "$log_file" ]]; then
            continue
        fi

        # Extract timestamp from filename
        filename=$(basename "$log_file")
        if [[ $filename =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\.log$ ]]; then
            year=${BASH_REMATCH[1]}
            month=${BASH_REMATCH[2]}
            day=${BASH_REMATCH[3]}
            hour=${BASH_REMATCH[4]}
            minute=${BASH_REMATCH[5]}
            second=${BASH_REMATCH[6]}

            file_timestamp=$(date -d "$year-$month-$day $hour:$minute:$second" +%s 2>/dev/null || echo "0")

            # Skip if older than 30 days
            if [[ $file_timestamp -lt $thirty_days_ago ]]; then
                continue
            fi

            agent_runs[$agent]=$((${agent_runs[$agent]} + 1))

            # Extract task IDs from log content
            task_ids=$(grep -oE "TASK-[0-9]+" "$log_file" 2>/dev/null | sort -u)

            for task_id in $task_ids; do
                agent_tasks[$agent]=$((${agent_tasks[$agent]} + 1))
                # Record which agents touched this task
                if [[ -n "${task_agents[$task_id]}" ]]; then
                    task_agents[$task_id]="${task_agents[$task_id]},$agent"
                else
                    task_agents[$task_id]="$agent"
                fi
            done
        fi
    done
done

# Calculate collaboration counts from shared task work
for task_id in "${!task_agents[@]}"; do
    # Get unique agents who worked on this task
    IFS=',' read -ra agents_list <<< "${task_agents[$task_id]}"
    unique_agents=($(printf "%s\n" "${agents_list[@]}" | sort -u))

    # Count collaborations between pairs
    for ((i=0; i<${#unique_agents[@]}; i++)); do
        for ((j=i+1; j<${#unique_agents[@]}; j++)); do
            agent1="${unique_agents[$i]}"
            agent2="${unique_agents[$j]}"

            # Create consistent key (alphabetically sorted)
            if [[ "$agent1" < "$agent2" ]]; then
                key="${agent1}|${agent2}"
            else
                key="${agent2}|${agent1}"
            fi

            collaboration_count[$key]=$((${collaboration_count[$key]:-0} + 1))
        done
    done
done

# Calculate handoff patterns from pipeline sequence
# Based on expected flow: idea-maker -> PM -> developer/developer2 -> tester -> security
declare -A expected_flow
expected_flow["idea-maker"]="project-manager"
expected_flow["project-manager"]="developer developer2"
expected_flow["developer"]="tester"
expected_flow["developer2"]="tester"
expected_flow["tester"]="security"

# Count handoffs based on task assignment history
for agent in "${AGENTS[@]}"; do
    next_agents="${expected_flow[$agent]}"
    if [[ -n "$next_agents" ]]; then
        for next_agent in $next_agents; do
            handoff_count["${agent}|${next_agent}"]=$((${handoff_count["${agent}|${next_agent}"]:-0} + ${agent_runs[$agent]:-0}))
        done
    fi
done

# Calculate centrality scores (simplified degree centrality)
declare -A centrality_scores
total_collaborations=0

for key in "${!collaboration_count[@]}"; do
    IFS='|' read -ra pair <<< "$key"
    agent1="${pair[0]}"
    agent2="${pair[1]}"
    count=${collaboration_count[$key]}

    centrality_scores[$agent1]=$((${centrality_scores[$agent1]:-0} + count))
    centrality_scores[$agent2]=$((${centrality_scores[$agent2]:-0} + count))
    total_collaborations=$((total_collaborations + count))
done

# Normalize centrality scores (0-100)
max_centrality=1
for agent in "${AGENTS[@]}"; do
    if [[ ${centrality_scores[$agent]:-0} -gt $max_centrality ]]; then
        max_centrality=${centrality_scores[$agent]}
    fi
done

# Calculate collaboration health score
health_score=100
total_agents=${#AGENTS[@]}
connected_agents=0
for agent in "${AGENTS[@]}"; do
    if [[ ${centrality_scores[$agent]:-0} -gt 0 ]]; then
        connected_agents=$((connected_agents + 1))
    fi
done
if [[ $total_agents -gt 0 ]]; then
    health_score=$((connected_agents * 100 / total_agents))
fi

# Identify clusters
# Pipeline cluster: idea-maker, project-manager
# Development cluster: developer, developer2, tester
# Review cluster: tester, security
declare -A cluster_members
cluster_members["pipeline"]="idea-maker,project-manager"
cluster_members["development"]="developer,developer2,tester"
cluster_members["review"]="tester,security"

# Find bottleneck (highest betweenness - simplified as agent with most unique connections)
bottleneck_agent=""
bottleneck_connections=0
for agent in "${AGENTS[@]}"; do
    conn_count=0
    for key in "${!collaboration_count[@]}"; do
        if [[ "$key" == *"$agent"* ]]; then
            conn_count=$((conn_count + 1))
        fi
    done
    if [[ $conn_count -gt $bottleneck_connections ]]; then
        bottleneck_connections=$conn_count
        bottleneck_agent=$agent
    fi
done

# Build JSON output
{
    echo "{"
    echo "  \"generated\": \"$TIMESTAMP\","
    echo "  \"summary\": {"
    echo "    \"total_collaborations\": $total_collaborations,"
    echo "    \"health_score\": $health_score,"
    echo "    \"connected_agents\": $connected_agents,"
    echo "    \"total_agents\": $total_agents,"
    echo "    \"bottleneck_agent\": \"$bottleneck_agent\","
    echo "    \"unique_tasks\": ${#task_agents[@]}"
    echo "  },"

    # Nodes (agents)
    echo "  \"nodes\": ["
    first_node=true
    for agent in "${AGENTS[@]}"; do
        if [[ $first_node == false ]]; then
            echo ","
        fi
        first_node=false

        runs=${agent_runs[$agent]:-0}
        tasks=${agent_tasks[$agent]:-0}
        centrality=${centrality_scores[$agent]:-0}

        # Normalize centrality to 0-100
        if [[ $max_centrality -gt 0 ]]; then
            normalized_centrality=$((centrality * 100 / max_centrality))
        else
            normalized_centrality=0
        fi

        # Determine cluster
        cluster="none"
        for c in "${!cluster_members[@]}"; do
            if [[ "${cluster_members[$c]}" == *"$agent"* ]]; then
                cluster=$c
                break
            fi
        done

        echo -n "    {\"id\": \"$agent\", \"runs\": $runs, \"tasks\": $tasks, \"centrality\": $normalized_centrality, \"cluster\": \"$cluster\"}"
    done
    echo ""
    echo "  ],"

    # Edges (collaborations)
    echo "  \"edges\": ["
    first_edge=true
    for key in "${!collaboration_count[@]}"; do
        IFS='|' read -ra pair <<< "$key"
        agent1="${pair[0]}"
        agent2="${pair[1]}"
        count=${collaboration_count[$key]}

        if [[ $first_edge == false ]]; then
            echo ","
        fi
        first_edge=false

        # Calculate edge quality (based on count relative to average)
        quality=50
        if [[ $total_collaborations -gt 0 ]]; then
            avg=$((total_collaborations / ${#collaboration_count[@]}))
            if [[ $count -gt $avg ]]; then
                quality=$((50 + (count - avg) * 50 / avg))
                if [[ $quality -gt 100 ]]; then quality=100; fi
            else
                quality=$((count * 50 / avg))
            fi
        fi

        echo -n "    {\"source\": \"$agent1\", \"target\": \"$agent2\", \"weight\": $count, \"quality\": $quality}"
    done
    echo ""
    echo "  ],"

    # Handoffs
    echo "  \"handoffs\": ["
    first_handoff=true
    for key in "${!handoff_count[@]}"; do
        IFS='|' read -ra pair <<< "$key"
        from="${pair[0]}"
        to="${pair[1]}"
        count=${handoff_count[$key]}

        if [[ $count -gt 0 ]]; then
            if [[ $first_handoff == false ]]; then
                echo ","
            fi
            first_handoff=false
            echo -n "    {\"from\": \"$from\", \"to\": \"$to\", \"count\": $count}"
        fi
    done
    echo ""
    echo "  ],"

    # Clusters
    echo "  \"clusters\": ["
    first_cluster=true
    for cluster_name in "${!cluster_members[@]}"; do
        if [[ $first_cluster == false ]]; then
            echo ","
        fi
        first_cluster=false
        members="${cluster_members[$cluster_name]}"
        echo -n "    {\"name\": \"$cluster_name\", \"members\": [\"${members//,/\", \"}\"]}"
    done
    echo ""
    echo "  ],"

    # Recommendations
    echo "  \"recommendations\": ["
    recommendation_count=0

    # Check for isolated agents
    for agent in "${AGENTS[@]}"; do
        if [[ ${centrality_scores[$agent]:-0} -eq 0 ]]; then
            if [[ $recommendation_count -gt 0 ]]; then echo ","; fi
            echo -n "    \"$agent appears isolated with no recorded collaborations - consider reviewing pipeline integration\""
            recommendation_count=$((recommendation_count + 1))
        fi
    done

    # Check for weak connections between clusters
    pipeline_dev_collabs=0
    for key in "${!collaboration_count[@]}"; do
        if [[ "$key" == *"project-manager"* && ("$key" == *"developer"* || "$key" == *"developer2"*) ]]; then
            pipeline_dev_collabs=$((pipeline_dev_collabs + ${collaboration_count[$key]}))
        fi
    done
    if [[ $pipeline_dev_collabs -lt 5 && $total_collaborations -gt 10 ]]; then
        if [[ $recommendation_count -gt 0 ]]; then echo ","; fi
        echo -n "    \"Weak connection between pipeline and development clusters - consider more direct PM-Developer coordination\""
        recommendation_count=$((recommendation_count + 1))
    fi

    # Check for bottleneck
    if [[ -n "$bottleneck_agent" && $bottleneck_connections -gt 3 ]]; then
        if [[ $recommendation_count -gt 0 ]]; then echo ","; fi
        echo -n "    \"$bottleneck_agent is a central bottleneck with $bottleneck_connections connections - consider distributing responsibilities\""
        recommendation_count=$((recommendation_count + 1))
    fi

    echo ""
    echo "  ]"
    echo "}"
} > "$OUTPUT_FILE"

echo "Collaboration network data updated: $OUTPUT_FILE"
