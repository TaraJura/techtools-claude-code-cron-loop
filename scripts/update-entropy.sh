#!/bin/bash
# update-entropy.sh - Gathers entropy pool data for the CronLoop dashboard
# Called periodically to update /var/www/cronloop.techtools.cz/api/entropy.json

API_DIR="/var/www/cronloop.techtools.cz/api"
ENTROPY_FILE="$API_DIR/entropy.json"
HISTORY_FILE="$API_DIR/entropy-history.json"

# Ensure API directory exists
mkdir -p "$API_DIR"

# Get current entropy values
ENTROPY_AVAIL=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
POOL_SIZE=$(cat /proc/sys/kernel/random/poolsize 2>/dev/null || echo "256")

# Check for hardware RNG
HWRNG_AVAILABLE="false"
HWRNG_NAME=""
if [ -c /dev/hwrng ]; then
    HWRNG_AVAILABLE="true"
    HWRNG_NAME="Hardware RNG"
elif [ -d /sys/class/misc/hw_random ]; then
    HWRNG_AVAILABLE="true"
    if [ -f /sys/class/misc/hw_random/rng_current ]; then
        HWRNG_NAME=$(cat /sys/class/misc/hw_random/rng_current 2>/dev/null || echo "hwrng")
    else
        HWRNG_NAME="Hardware RNG"
    fi
fi

# Check for entropy daemons
HAVEGED_RUNNING="false"
RNGD_RUNNING="false"
if pgrep -x haveged >/dev/null 2>&1; then
    HAVEGED_RUNNING="true"
fi
if pgrep -x rngd >/dev/null 2>&1; then
    RNGD_RUNNING="true"
fi

# Check for input devices (keyboard/mouse - usually none on servers)
INPUT_DEVICES="false"
if ls /dev/input/event* >/dev/null 2>&1; then
    INPUT_DEVICES="true"
fi

# Get timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Load or initialize history
if [ -f "$HISTORY_FILE" ]; then
    HISTORY=$(cat "$HISTORY_FILE")
else
    HISTORY="[]"
fi

# Add current reading to history
NEW_ENTRY="{\"timestamp\":\"$TIMESTAMP\",\"entropy\":$ENTROPY_AVAIL}"
HISTORY=$(echo "$HISTORY" | jq --argjson entry "$NEW_ENTRY" '. + [$entry]')

# Keep only last 24 hours (288 entries at 5-minute intervals, or ~1440 at 1-minute)
# We'll keep 500 entries max
HISTORY=$(echo "$HISTORY" | jq '.[-500:]')

# Save history
echo "$HISTORY" | jq '.' > "$HISTORY_FILE"

# Calculate statistics from history
STATS=$(echo "$HISTORY" | jq '{
    average: (if length > 0 then ([.[].entropy] | add / length) else 0 end),
    min: (if length > 0 then ([.[].entropy] | min) else 0 end),
    max: (if length > 0 then ([.[].entropy] | max) else 0 end),
    low_events: ([.[] | select(.entropy < 200)] | length)
}')

# Detect consumption events (sudden drops > 50 bits)
CONSUMPTION_EVENTS="[]"
if [ $(echo "$HISTORY" | jq 'length') -gt 1 ]; then
    CONSUMPTION_EVENTS=$(echo "$HISTORY" | jq '
        [range(1; length) as $i |
         if (.[$i-1].entropy - .[$i].entropy) > 50 then
            {
                timestamp: .[$i].timestamp,
                drop: (.[$i-1].entropy - .[$i].entropy),
                cause: (
                    if (.[$i-1].entropy - .[$i].entropy) > 200 then "Heavy crypto operation (key generation)"
                    elif (.[$i-1].entropy - .[$i].entropy) > 100 then "SSL/TLS handshake or key operation"
                    else "Minor crypto operation"
                    end
                )
            }
         else empty
         end
        ] | .[-10:]
    ')
fi

# Build the final JSON
cat > "$ENTROPY_FILE" << EOF
{
    "timestamp": "$TIMESTAMP",
    "current": {
        "available": $ENTROPY_AVAIL,
        "poolsize": $POOL_SIZE,
        "percent": $(echo "scale=1; $ENTROPY_AVAIL * 100 / $POOL_SIZE" | bc)
    },
    "stats": $STATS,
    "sources": {
        "hwrng": $HWRNG_AVAILABLE,
        "hwrng_name": "$HWRNG_NAME",
        "haveged": $HAVEGED_RUNNING,
        "rngd": $RNGD_RUNNING,
        "input_devices": $INPUT_DEVICES,
        "disk_io": true,
        "interrupts": true
    },
    "consumption_events": $CONSUMPTION_EVENTS,
    "history": $(echo "$HISTORY" | jq '.[-48:]')
}
EOF

# Output status for logging
echo "Entropy updated: $ENTROPY_AVAIL / $POOL_SIZE bits ($(date))"
