#!/bin/bash
# update-connectivity.sh - Test network connectivity, DNS resolution, and gateway reachability
# Part of CronLoop web app - provides data for network connectivity tester

set -e

API_DIR="/var/www/cronloop.techtools.cz/api"
CONNECTIVITY_FILE="$API_DIR/connectivity.json"
HISTORY_FILE="$API_DIR/connectivity-history.json"

# Get timestamp
TIMESTAMP=$(date -Iseconds)
EPOCH=$(date +%s)

# Hosts to ping for connectivity testing
PING_HOSTS=(
    "8.8.8.8:Google DNS"
    "1.1.1.1:Cloudflare DNS"
    "9.9.9.9:Quad9 DNS"
)

# Domains for DNS resolution testing
DNS_DOMAINS=(
    "google.com"
    "cloudflare.com"
    "github.com"
    "anthropic.com"
)

# Function to ping host and get latency
ping_host() {
    local host="$1"
    local result

    # Run ping with timeout
    if result=$(ping -c 3 -W 2 "$host" 2>/dev/null); then
        # Extract statistics
        local stats=$(echo "$result" | grep -E "^(rtt|round-trip)" | head -1)
        local loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)' || echo "0")

        # Parse min/avg/max/mdev
        local avg_latency=$(echo "$stats" | grep -oP '\d+\.\d+(?=/\d+\.\d+/\d+\.\d+)' | head -1 || echo "0")
        local min_latency=$(echo "$stats" | grep -oP '= \K\d+\.\d+' | head -1 || echo "0")
        local max_latency=$(echo "$stats" | grep -oP '/\K\d+\.\d+' | tail -1 || echo "0")

        # If parsing failed, try alternate format
        if [ -z "$avg_latency" ] || [ "$avg_latency" = "0" ]; then
            avg_latency=$(echo "$stats" | awk -F'/' '{print $5}' 2>/dev/null || echo "0")
            min_latency=$(echo "$stats" | awk -F'/' '{print $4}' | awk -F'= ' '{print $2}' 2>/dev/null || echo "0")
            max_latency=$(echo "$stats" | awk -F'/' '{print $6}' 2>/dev/null || echo "0")
        fi

        echo "reachable ${loss:-0} ${avg_latency:-0} ${min_latency:-0} ${max_latency:-0}"
    else
        echo "unreachable 100 0 0 0"
    fi
}

# Function to test DNS resolution
test_dns() {
    local domain="$1"
    local start_time=$(date +%s%N)

    if ip=$(dig +short +time=3 "$domain" A 2>/dev/null | head -1); then
        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))

        if [ -n "$ip" ] && [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "resolved ${duration_ms} ${ip}"
        else
            echo "failed 0 -"
        fi
    else
        echo "failed 0 -"
    fi
}

# Function to get default gateway
get_gateway() {
    local gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)
    echo "${gateway:-unknown}"
}

# Test gateway reachability
test_gateway() {
    local gateway="$1"

    if [ "$gateway" = "unknown" ]; then
        echo "unknown 0 0"
        return
    fi

    if result=$(ping -c 3 -W 2 "$gateway" 2>/dev/null); then
        local loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)' || echo "0")
        local avg=$(echo "$result" | grep -E "^(rtt|round-trip)" | grep -oP '\d+\.\d+(?=/\d+\.\d+/\d+\.\d+)' | head -1 || echo "0")

        # Alternate parsing
        if [ -z "$avg" ] || [ "$avg" = "0" ]; then
            avg=$(echo "$result" | grep -E "^(rtt|round-trip)" | awk -F'/' '{print $5}' 2>/dev/null || echo "0")
        fi

        echo "reachable ${loss:-0} ${avg:-0}"
    else
        echo "unreachable 100 0"
    fi
}

# Get DNS servers configured on system
get_dns_servers() {
    local servers=""

    # Try resolv.conf
    if [ -f /etc/resolv.conf ]; then
        servers=$(grep -E "^nameserver" /etc/resolv.conf | awk '{print $2}' | head -3 | tr '\n' ' ')
    fi

    # Fallback to systemd-resolve if available
    if [ -z "$servers" ] && command -v resolvectl &>/dev/null; then
        servers=$(resolvectl status 2>/dev/null | grep "DNS Servers" | awk -F: '{print $2}' | head -1)
    fi

    echo "${servers:-unknown}"
}

# Build ping results JSON array
PING_RESULTS="["
first_ping=true
overall_status="healthy"
total_latency=0
successful_pings=0

for host_entry in "${PING_HOSTS[@]}"; do
    host="${host_entry%%:*}"
    name="${host_entry#*:}"

    read status loss avg min max <<< $(ping_host "$host")

    [ "$first_ping" = false ] && PING_RESULTS+=","
    first_ping=false

    PING_RESULTS+="{\"host\":\"$host\",\"name\":\"$name\",\"status\":\"$status\",\"packet_loss\":$loss,\"latency_avg\":$avg,\"latency_min\":$min,\"latency_max\":$max}"

    if [ "$status" = "reachable" ]; then
        successful_pings=$((successful_pings + 1))
        total_latency=$(echo "$total_latency + $avg" | bc)
    else
        if [ "$overall_status" = "healthy" ]; then
            overall_status="warning"
        fi
    fi
done
PING_RESULTS+="]"

# Calculate average latency
if [ "$successful_pings" -gt 0 ]; then
    avg_overall_latency=$(echo "scale=2; $total_latency / $successful_pings" | bc)
else
    avg_overall_latency="0"
    overall_status="critical"
fi

# Build DNS results JSON array
DNS_RESULTS="["
first_dns=true
dns_success_count=0

for domain in "${DNS_DOMAINS[@]}"; do
    read status duration ip <<< $(test_dns "$domain")

    [ "$first_dns" = false ] && DNS_RESULTS+=","
    first_dns=false

    DNS_RESULTS+="{\"domain\":\"$domain\",\"status\":\"$status\",\"duration_ms\":$duration,\"resolved_ip\":\"$ip\"}"

    if [ "$status" = "resolved" ]; then
        dns_success_count=$((dns_success_count + 1))
    else
        if [ "$overall_status" = "healthy" ]; then
            overall_status="warning"
        fi
    fi
done
DNS_RESULTS+="]"

# Test gateway
GATEWAY=$(get_gateway)
read gw_status gw_loss gw_latency <<< $(test_gateway "$GATEWAY")

if [ "$gw_status" = "unreachable" ]; then
    overall_status="critical"
fi

# Get DNS servers
DNS_SERVERS=$(get_dns_servers)

# Determine health status
if [ "$successful_pings" -eq 0 ]; then
    overall_status="critical"
elif [ "$successful_pings" -lt ${#PING_HOSTS[@]} ] || [ "$dns_success_count" -lt ${#DNS_DOMAINS[@]} ]; then
    if [ "$overall_status" = "healthy" ]; then
        overall_status="warning"
    fi
fi

# Build connectivity JSON
cat > "$CONNECTIVITY_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "epoch": $EPOCH,
  "overall_status": "$overall_status",
  "average_latency_ms": $avg_overall_latency,
  "gateway": {
    "ip": "$GATEWAY",
    "status": "$gw_status",
    "packet_loss": $gw_loss,
    "latency_ms": $gw_latency
  },
  "dns_servers": "$DNS_SERVERS",
  "ping_tests": $PING_RESULTS,
  "dns_tests": $DNS_RESULTS,
  "summary": {
    "ping_success": $successful_pings,
    "ping_total": ${#PING_HOSTS[@]},
    "dns_success": $dns_success_count,
    "dns_total": ${#DNS_DOMAINS[@]}
  }
}
EOF

# Update history file (keep last 96 entries = 24 hours at 15-min intervals)
MAX_HISTORY=96

SNAPSHOT=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "status": "$overall_status",
  "avg_latency": $avg_overall_latency,
  "ping_success": $successful_pings,
  "dns_success": $dns_success_count
}
EOF
)

if [ ! -f "$HISTORY_FILE" ]; then
    cat > "$HISTORY_FILE" <<EOF
{
  "last_updated": "$TIMESTAMP",
  "retention_hours": 24,
  "snapshots": [$SNAPSHOT]
}
EOF
else
    python3 << PYEOF
import json

try:
    with open("$HISTORY_FILE", "r") as f:
        history = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    history = {"last_updated": "$TIMESTAMP", "retention_hours": 24, "snapshots": []}

new_snapshot = json.loads('''$SNAPSHOT''')

if "snapshots" not in history or not isinstance(history["snapshots"], list):
    history["snapshots"] = []

history["snapshots"].append(new_snapshot)

MAX_HISTORY = $MAX_HISTORY
if len(history["snapshots"]) > MAX_HISTORY:
    history["snapshots"] = history["snapshots"][-MAX_HISTORY:]

history["last_updated"] = "$TIMESTAMP"

with open("$HISTORY_FILE", "w") as f:
    json.dump(history, f, indent=2)
PYEOF
fi

echo "Connectivity test completed: $CONNECTIVITY_FILE"
echo "Status: $overall_status | Ping: $successful_pings/${#PING_HOSTS[@]} | DNS: $dns_success_count/${#DNS_DOMAINS[@]} | Avg Latency: ${avg_overall_latency}ms"
