#!/bin/bash
# generate-horoscope.sh - Generate agent daily horoscopes based on historical patterns
# Creates whimsical predictions with fortune-telling aesthetic

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/horoscope.json"
HISTORY_FILE="/var/www/cronloop.techtools.cz/api/horoscope-history.json"
ACTORS_DIR="/home/novakj/actors"
TASKS_FILE="/home/novakj/tasks.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%A)
HOUR=$(date +%H)

# Agent zodiac assignments based on their roles
declare -A AGENT_ZODIAC
AGENT_ZODIAC["idea-maker"]="Aquarius"
AGENT_ZODIAC["project-manager"]="Capricorn"
AGENT_ZODIAC["developer"]="Aries"
AGENT_ZODIAC["developer2"]="Sagittarius"
AGENT_ZODIAC["tester"]="Virgo"
AGENT_ZODIAC["security"]="Scorpio"
AGENT_ZODIAC["supervisor"]="Leo"

declare -A ZODIAC_SYMBOLS
ZODIAC_SYMBOLS["Aquarius"]="aquarius"
ZODIAC_SYMBOLS["Capricorn"]="capricorn"
ZODIAC_SYMBOLS["Aries"]="aries"
ZODIAC_SYMBOLS["Sagittarius"]="sagittarius"
ZODIAC_SYMBOLS["Virgo"]="virgo"
ZODIAC_SYMBOLS["Scorpio"]="scorpius"
ZODIAC_SYMBOLS["Leo"]="leo"

declare -A ZODIAC_TRAITS
ZODIAC_TRAITS["Aquarius"]="innovative, creative, visionary"
ZODIAC_TRAITS["Capricorn"]="organized, ambitious, disciplined"
ZODIAC_TRAITS["Aries"]="bold, energetic, pioneering"
ZODIAC_TRAITS["Sagittarius"]="adventurous, optimistic, versatile"
ZODIAC_TRAITS["Virgo"]="meticulous, analytical, perfectionist"
ZODIAC_TRAITS["Scorpio"]="intense, watchful, protective"
ZODIAC_TRAITS["Leo"]="confident, commanding, watchful"

# Lucky file types and colors
FILE_TYPES=(".html" ".sh" ".json" ".md" ".py" ".js" ".css" ".ts")
COLORS=("cosmic purple" "stellar blue" "nebula green" "solar gold" "meteor red" "celestial cyan")
HOURS=("03:00" "06:00" "09:00" "12:00" "15:00" "18:00" "21:00" "00:00")

# Positive/negative fortunes
POSITIVE_FORTUNES=(
    "The stars align in your favor"
    "Cosmic energy flows through your code"
    "The universe supports your endeavors"
    "Celestial bodies bring good fortune"
    "Your digital karma is excellent"
    "The tech gods smile upon you"
    "Binary stars illuminate your path"
    "Quantum luck is on your side"
)

CAUTIONARY_FORTUNES=(
    "Proceed with calculated optimism"
    "The cosmos advise thorough testing"
    "Mercury may cause minor turbulence"
    "A debug session may be in your future"
    "The void requires extra validation"
    "Cosmic winds suggest double-checking"
    "The oracle senses edge cases ahead"
    "Planetary alignment suggests patience"
)

CAREER_FORTUNES=(
    "Today brings opportunities for great accomplishments"
    "Your task completion rate will soar"
    "Complex challenges will yield to your efforts"
    "A breakthrough is written in the stars"
    "Your code will flow like cosmic rivers"
    "Success awaits those who commit early"
    "The deployment gods favor the bold"
)

RELATIONSHIP_FORTUNES=(
    "Collaboration energies are strong today"
    "Inter-agent harmony is at peak levels"
    "Handoffs will be smooth and blessed"
    "Communication channels are crystal clear"
    "Trust flows freely between agents"
    "Team synergy reaches new heights"
)

# Agents list
AGENTS=("idea-maker" "project-manager" "developer" "developer2" "tester" "security" "supervisor")

# Function to calculate agent stats from logs
get_agent_stats() {
    local agent=$1
    local log_dir="$ACTORS_DIR/$agent/logs"
    local runs=0
    local successes=0
    local errors=0

    if [[ -d "$log_dir" ]]; then
        # Count recent logs (last 7 days)
        for i in $(seq 0 6); do
            date_prefix=$(date -d "$i days ago" +%Y%m%d 2>/dev/null || date -v-${i}d +%Y%m%d 2>/dev/null)
            if [[ -n "$date_prefix" ]]; then
                shopt -s nullglob
                for log_file in "$log_dir/${date_prefix}_"*.log; do
                    if [[ -f "$log_file" ]]; then
                        runs=$((runs + 1))
                        if grep -qi "error\|failed\|exception" "$log_file" 2>/dev/null; then
                            errors=$((errors + 1))
                        else
                            successes=$((successes + 1))
                        fi
                    fi
                done
                shopt -u nullglob
            fi
        done
    fi

    echo "$runs:$successes:$errors"
}

# Function to generate a random element from array
random_element() {
    local arr=("$@")
    local idx=$((RANDOM % ${#arr[@]}))
    echo "${arr[$idx]}"
}

# Function to get a prediction based on success rate
get_mood() {
    local success_rate=$1
    if [[ $success_rate -ge 90 ]]; then
        echo "excellent"
    elif [[ $success_rate -ge 70 ]]; then
        echo "good"
    elif [[ $success_rate -ge 50 ]]; then
        echo "neutral"
    else
        echo "challenging"
    fi
}

# Function to generate intensity based on day of week
get_cosmic_intensity() {
    case "$DAY_OF_WEEK" in
        Monday) echo "rising";;
        Tuesday) echo "building";;
        Wednesday) echo "peak";;
        Thursday) echo "sustained";;
        Friday) echo "releasing";;
        Saturday) echo "restoring";;
        Sunday) echo "renewing";;
        *) echo "flowing";;
    esac
}

# Start building JSON
cat > "$OUTPUT_FILE" << HEADER
{
  "generated": "$TIMESTAMP",
  "date": "$TODAY",
  "day_of_week": "$DAY_OF_WEEK",
  "cosmic_intensity": "$(get_cosmic_intensity)",
  "moon_phase": "$(random_element "new" "waxing crescent" "first quarter" "waxing gibbous" "full" "waning gibbous" "last quarter" "waning crescent")",
  "system_fortune": "$(random_element "${POSITIVE_FORTUNES[@]}")",
  "agents": [
HEADER

# Generate horoscope for each agent
first=true
for agent in "${AGENTS[@]}"; do
    stats=$(get_agent_stats "$agent")
    runs=$(echo "$stats" | cut -d: -f1)
    successes=$(echo "$stats" | cut -d: -f2)
    errors=$(echo "$stats" | cut -d: -f3)

    # Calculate success rate
    success_rate=75
    if [[ $runs -gt 0 ]]; then
        success_rate=$((successes * 100 / runs))
    fi

    # Get zodiac info
    zodiac="${AGENT_ZODIAC[$agent]}"
    symbol="${ZODIAC_SYMBOLS[$zodiac]}"
    traits="${ZODIAC_TRAITS[$zodiac]}"

    # Calculate prediction scores (1-5)
    career_score=$(((success_rate / 20) + (RANDOM % 2)))
    [[ $career_score -gt 5 ]] && career_score=5
    [[ $career_score -lt 1 ]] && career_score=1

    relationship_score=$((3 + (RANDOM % 3)))
    health_score=$(((100 - errors * 10) / 20 + 1))
    [[ $health_score -gt 5 ]] && health_score=5
    [[ $health_score -lt 1 ]] && health_score=1

    finance_score=$((4 - (RANDOM % 2)))

    # Lucky elements
    lucky_file=$(random_element "${FILE_TYPES[@]}")
    lucky_color=$(random_element "${COLORS[@]}")
    lucky_hour=$(random_element "${HOURS[@]}")
    lucky_number=$((RANDOM % 100 + 1))

    # Get mood
    mood=$(get_mood $success_rate)

    # Generate predictions
    if [[ $success_rate -ge 70 ]]; then
        daily_prediction=$(random_element "${POSITIVE_FORTUNES[@]}")
        career_prediction=$(random_element "${CAREER_FORTUNES[@]}")
    else
        daily_prediction=$(random_element "${CAUTIONARY_FORTUNES[@]}")
        career_prediction="Focus on stability before taking on new challenges"
    fi

    relationship_prediction=$(random_element "${RELATIONSHIP_FORTUNES[@]}")

    # Get agent display name and icon
    case "$agent" in
        idea-maker) name="Idea Maker"; icon="star";;
        project-manager) name="Project Manager"; icon="clipboard-list";;
        developer) name="Developer"; icon="code";;
        developer2) name="Developer 2"; icon="code-bracket";;
        tester) name="Tester"; icon="beaker";;
        security) name="Security"; icon="shield-check";;
        supervisor) name="Supervisor"; icon="eye";;
        *) name="$agent"; icon="user";;
    esac

    # Calculate compatibility (pick 2 random agents)
    compatible_agents=()
    for other in "${AGENTS[@]}"; do
        if [[ "$other" != "$agent" ]]; then
            compatible_agents+=("$other")
        fi
    done
    best_match="${compatible_agents[$((RANDOM % ${#compatible_agents[@]}))]}"

    # Add comma if not first
    if [[ $first == false ]]; then
        echo "," >> "$OUTPUT_FILE"
    fi
    first=false

    cat >> "$OUTPUT_FILE" << AGENT_JSON
    {
      "agent": "$agent",
      "name": "$name",
      "icon": "$icon",
      "zodiac": {
        "sign": "$zodiac",
        "symbol": "$symbol",
        "traits": "$traits"
      },
      "mood": "$mood",
      "daily_prediction": "$daily_prediction",
      "scores": {
        "career": $career_score,
        "relationships": $relationship_score,
        "health": $health_score,
        "finance": $finance_score,
        "overall": $(( (career_score + relationship_score + health_score + finance_score) / 4 ))
      },
      "categories": {
        "career": "$career_prediction",
        "relationships": "$relationship_prediction",
        "health": "$(if [[ $errors -eq 0 ]]; then echo "Your error immunity is strong today"; else echo "Take time to address any lingering issues"; fi)",
        "finance": "$(if [[ $success_rate -ge 80 ]]; then echo "Token efficiency looks promising"; else echo "Consider optimizing your resource usage"; fi)"
      },
      "lucky": {
        "file_type": "$lucky_file",
        "color": "$lucky_color",
        "hour": "$lucky_hour",
        "number": $lucky_number
      },
      "compatibility": {
        "best_match": "$best_match",
        "advice": "Working with $best_match today could yield exceptional results"
      },
      "weekly_forecast": {
        "monday": $((3 + RANDOM % 3)),
        "tuesday": $((3 + RANDOM % 3)),
        "wednesday": $((3 + RANDOM % 3)),
        "thursday": $((3 + RANDOM % 3)),
        "friday": $((3 + RANDOM % 3)),
        "saturday": $((2 + RANDOM % 3)),
        "sunday": $((2 + RANDOM % 3))
      },
      "stats": {
        "runs_7d": $runs,
        "successes_7d": $successes,
        "errors_7d": $errors,
        "success_rate": $success_rate
      }
    }
AGENT_JSON
done

# Close agents array and add footer
cat >> "$OUTPUT_FILE" << FOOTER

  ],
  "oracle_wisdom": [
    "In the realm of bits and bytes, fortune favors the well-tested",
    "A commit message written in haste may cause confusion at leisure",
    "The wise agent checks their dependencies before venturing forth",
    "Remember: today's bug is tomorrow's war story",
    "Not all who wander through logs are lost",
    "The path to deployment is paved with good test coverage"
  ],
  "daily_affirmation": "Today I will embrace both successes and failures as opportunities for growth",
  "cosmic_event": "$(random_element "Meteor shower of commits expected" "Venus aligns with the production server" "The digital moon is full tonight" "Saturn's rings encircle your deployments" "Jupiter brings expansion to your feature set")"
}
FOOTER

# Validate JSON
if python3 -c "import json; json.load(open('$OUTPUT_FILE'))" 2>/dev/null; then
    echo "Horoscope generated successfully: $OUTPUT_FILE"

    # Update history file
    if [[ -f "$HISTORY_FILE" ]]; then
        # Keep last 30 entries
        python3 << PYTHON_UPDATE
import json
from datetime import datetime

history_file = "$HISTORY_FILE"
output_file = "$OUTPUT_FILE"

try:
    with open(history_file, 'r') as f:
        history = json.load(f)
except:
    history = {"horoscopes": []}

with open(output_file, 'r') as f:
    today_data = json.load(f)

# Add today's summary
today_summary = {
    "date": today_data["date"],
    "generated": today_data["generated"],
    "cosmic_intensity": today_data["cosmic_intensity"],
    "moon_phase": today_data["moon_phase"],
    "system_fortune": today_data["system_fortune"]
}

# Check if today already exists
dates = [h["date"] for h in history["horoscopes"]]
if today_data["date"] not in dates:
    history["horoscopes"].insert(0, today_summary)
    # Keep only last 30
    history["horoscopes"] = history["horoscopes"][:30]

    with open(history_file, 'w') as f:
        json.dump(history, f, indent=2)
    print(f"History updated with {today_data['date']}")
PYTHON_UPDATE
    else
        # Create initial history
        cat > "$HISTORY_FILE" << HISTORY_JSON
{
  "horoscopes": []
}
HISTORY_JSON
    fi
else
    echo "Warning: Generated JSON may have syntax errors"
fi

echo "Horoscope: $(date) completed"
