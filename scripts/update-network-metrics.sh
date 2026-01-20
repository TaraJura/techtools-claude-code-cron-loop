#!/bin/bash
# update-network-metrics.sh - Collect network metrics and update history
# Part of CronLoop web app - provides data for network bandwidth monitor page

set -e

API_DIR="/var/www/cronloop.techtools.cz/api"
NETWORK_FILE="$API_DIR/network-metrics.json"
HISTORY_FILE="$API_DIR/network-history.json"

# Get timestamp
TIMESTAMP=$(date -Iseconds)
EPOCH=$(date +%s)

# Function to parse /proc/net/dev
get_interface_stats() {
    local interface="$1"
    local stats=$(cat /proc/net/dev 2>/dev/null | grep "^\s*${interface}:" | head -1)

    if [ -n "$stats" ]; then
        # Format: interface: rx_bytes rx_packets rx_errs rx_drop ... tx_bytes tx_packets tx_errs tx_drop ...
        echo "$stats" | awk '{
            gsub(":", " ", $0);
            print $2, $3, $4, $5, $10, $11, $12, $13
        }'
    else
        echo "0 0 0 0 0 0 0 0"
    fi
}

# Find primary interface (exclude lo)
get_primary_interface() {
    # Try to get interface with default route
    local iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1)

    if [ -z "$iface" ]; then
        # Fallback: first non-lo interface from /proc/net/dev
        iface=$(cat /proc/net/dev | grep -v "lo:" | grep ":" | head -1 | awk -F: '{print $1}' | tr -d ' ')
    fi

    echo "${iface:-ens3}"
}

PRIMARY_IFACE=$(get_primary_interface)

# Get stats for all interfaces
declare -A interfaces

# Parse all interfaces from /proc/net/dev
while IFS= read -r line; do
    if [[ "$line" == *":"* ]]; then
        iface=$(echo "$line" | awk -F: '{print $1}' | tr -d ' ')
        # Skip if empty
        [ -z "$iface" ] && continue

        read rx_bytes rx_packets rx_errs rx_drop tx_bytes tx_packets tx_errs tx_drop <<< $(get_interface_stats "$iface")
        interfaces["$iface"]="$rx_bytes $rx_packets $rx_errs $rx_drop $tx_bytes $tx_packets $tx_errs $tx_drop"
    fi
done < /proc/net/dev

# Get connection statistics
get_connection_stats() {
    if command -v ss &>/dev/null; then
        local stats=$(ss -s 2>/dev/null)
        local tcp_total=$(echo "$stats" | grep "^TCP:" | awk '{print $2}')
        local tcp_estab=$(echo "$stats" | grep "^TCP:" | grep -oP 'estab \K\d+' || echo "0")
        local tcp_timewait=$(echo "$stats" | grep "^TCP:" | grep -oP 'timewait \K\d+' || echo "0")
        local tcp_orphan=$(echo "$stats" | grep "^TCP:" | grep -oP 'orphaned \K\d+' || echo "0")
        echo "${tcp_total:-0} ${tcp_estab:-0} ${tcp_timewait:-0} ${tcp_orphan:-0}"
    else
        echo "0 0 0 0"
    fi
}

read conn_total conn_estab conn_timewait conn_orphan <<< $(get_connection_stats)

# Get listening ports count
LISTENING_PORTS=$(ss -tuln 2>/dev/null | grep -c LISTEN || echo "0")

# Load previous snapshot to calculate rates
PREV_SNAPSHOT=""
if [ -f "$NETWORK_FILE" ]; then
    PREV_SNAPSHOT=$(cat "$NETWORK_FILE" 2>/dev/null)
fi

# Extract previous values for rate calculation
PREV_RX_BYTES=0
PREV_TX_BYTES=0
PREV_EPOCH=0

if [ -n "$PREV_SNAPSHOT" ]; then
    PREV_RX_BYTES=$(echo "$PREV_SNAPSHOT" | grep -oP '"rx_bytes":\s*\K\d+' | head -1 || echo "0")
    PREV_TX_BYTES=$(echo "$PREV_SNAPSHOT" | grep -oP '"tx_bytes":\s*\K\d+' | head -1 || echo "0")
    PREV_EPOCH=$(echo "$PREV_SNAPSHOT" | grep -oP '"epoch":\s*\K\d+' | head -1 || echo "0")
fi

# Get current stats for primary interface
read rx_bytes rx_packets rx_errs rx_drop tx_bytes tx_packets tx_errs tx_drop <<< $(get_interface_stats "$PRIMARY_IFACE")

# Calculate rates (bytes per second)
TIME_DIFF=$((EPOCH - PREV_EPOCH))
if [ "$TIME_DIFF" -gt 0 ] && [ "$PREV_EPOCH" -gt 0 ]; then
    RX_RATE=$(( (rx_bytes - PREV_RX_BYTES) / TIME_DIFF ))
    TX_RATE=$(( (tx_bytes - PREV_TX_BYTES) / TIME_DIFF ))
    # Handle counter reset or first run
    [ "$RX_RATE" -lt 0 ] && RX_RATE=0
    [ "$TX_RATE" -lt 0 ] && TX_RATE=0
else
    RX_RATE=0
    TX_RATE=0
fi

# Convert to KB/s for display
RX_RATE_KB=$((RX_RATE / 1024))
TX_RATE_KB=$((TX_RATE / 1024))

# Convert totals to human-readable
format_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "scale=2; $bytes / 1073741824" | bc | sed 's/^\./0./'
    elif [ "$bytes" -ge 1048576 ]; then
        echo "scale=2; $bytes / 1048576" | bc | sed 's/^\./0./'
    else
        echo "scale=2; $bytes / 1024" | bc | sed 's/^\./0./'
    fi
}

RX_HUMAN=$(format_bytes $rx_bytes)
TX_HUMAN=$(format_bytes $tx_bytes)

# Determine unit for human readable
get_unit() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "MB"
    else
        echo "KB"
    fi
}

RX_UNIT=$(get_unit $rx_bytes)
TX_UNIT=$(get_unit $tx_bytes)

# Build interface JSON array
IFACES_JSON="["
first=true
for iface in "${!interfaces[@]}"; do
    read i_rx_bytes i_rx_packets i_rx_errs i_rx_drop i_tx_bytes i_tx_packets i_tx_errs i_tx_drop <<< "${interfaces[$iface]}"

    [ "$first" = false ] && IFACES_JSON+=","
    first=false

    IFACES_JSON+="{\"name\":\"$iface\",\"rx_bytes\":$i_rx_bytes,\"rx_packets\":$i_rx_packets,\"rx_errors\":$i_rx_errs,\"rx_dropped\":$i_rx_drop,\"tx_bytes\":$i_tx_bytes,\"tx_packets\":$i_tx_packets,\"tx_errors\":$i_tx_errs,\"tx_dropped\":$i_tx_drop}"
done
IFACES_JSON+="]"

# Build current metrics JSON
cat > "$NETWORK_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "primary_interface": "$PRIMARY_IFACE",
  "rx_bytes": $rx_bytes,
  "tx_bytes": $tx_bytes,
  "rx_rate_bytes": $RX_RATE,
  "tx_rate_bytes": $TX_RATE,
  "rx_rate_kb": $RX_RATE_KB,
  "tx_rate_kb": $TX_RATE_KB,
  "rx_human": "$RX_HUMAN $RX_UNIT",
  "tx_human": "$TX_HUMAN $TX_UNIT",
  "rx_packets": $rx_packets,
  "tx_packets": $tx_packets,
  "rx_errors": $rx_errs,
  "tx_errors": $tx_errs,
  "rx_dropped": $rx_drop,
  "tx_dropped": $tx_drop,
  "connections": {
    "total": $conn_total,
    "established": $conn_estab,
    "time_wait": $conn_timewait,
    "orphaned": $conn_orphan
  },
  "listening_ports": $LISTENING_PORTS,
  "interfaces": $IFACES_JSON
}
EOF

# Update history file
MAX_HISTORY=672  # 7 days at 15-min intervals

# Create snapshot for history
SNAPSHOT=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "rx_bytes": $rx_bytes,
  "tx_bytes": $tx_bytes,
  "rx_rate_kb": $RX_RATE_KB,
  "tx_rate_kb": $TX_RATE_KB,
  "connections": $conn_estab
}
EOF
)

# Initialize or update history
if [ ! -f "$HISTORY_FILE" ]; then
    cat > "$HISTORY_FILE" <<EOF
{
  "last_updated": "$TIMESTAMP",
  "retention_days": 7,
  "snapshots": [$SNAPSHOT]
}
EOF
else
    # Use Python to safely read and update JSON history
    python3 << PYEOF
import json
import sys

try:
    with open("$HISTORY_FILE", "r") as f:
        history = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    # Invalid JSON, start fresh
    history = {"last_updated": "$TIMESTAMP", "retention_days": 7, "snapshots": []}

# Parse new snapshot
new_snapshot = json.loads('''$SNAPSHOT''')

# Ensure snapshots array exists
if "snapshots" not in history or not isinstance(history["snapshots"], list):
    history["snapshots"] = []

# Add new snapshot
history["snapshots"].append(new_snapshot)

# Limit to max history
MAX_HISTORY = $MAX_HISTORY
if len(history["snapshots"]) > MAX_HISTORY:
    history["snapshots"] = history["snapshots"][-MAX_HISTORY:]

# Update timestamp
history["last_updated"] = "$TIMESTAMP"

# Write back
with open("$HISTORY_FILE", "w") as f:
    json.dump(history, f, indent=2)
PYEOF
fi

echo "Network metrics updated: $NETWORK_FILE"
