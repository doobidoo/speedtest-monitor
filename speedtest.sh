#!/bin/bash
# speedtest.sh - Run speedtest and append result to JSON data file
# Called by cron every hour

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_FILE="/var/www/html/speedtest-data.json"
LOCK_FILE="/tmp/speedtest-monitor.lock"
MAX_AGE_DAYS=30
LOG_TAG="speedtest-monitor"
SPEEDTEST="$SCRIPT_DIR/.venv/bin/speedtest-cli"

# Fallback to system speedtest-cli if venv doesn't exist
if [ ! -x "$SPEEDTEST" ]; then
    SPEEDTEST="speedtest-cli"
fi

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        logger -t "$LOG_TAG" "Already running (PID $pid), skipping"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Initialize data file if missing
if [ ! -f "$DATA_FILE" ] || [ ! -s "$DATA_FILE" ]; then
    echo '{"results":[],"updated":""}' > "$DATA_FILE"
fi

# Run speedtest
logger -t "$LOG_TAG" "Starting speedtest using $SPEEDTEST..."
raw=$($SPEEDTEST --json --secure 2>&1)
rc=$?

if [ $rc -ne 0 ] || [ -z "$raw" ] || ! echo "$raw" | jq . >/dev/null 2>&1; then
    logger -t "$LOG_TAG" "ERROR: speedtest-cli failed (rc=$rc): $(echo "$raw" | head -1)"
    exit 1
fi

# Parse results (speedtest-cli outputs bits/s, convert to Mbit/s)
timestamp=$(echo "$raw" | jq -r '.timestamp')
download_bps=$(echo "$raw" | jq -r '.download')
upload_bps=$(echo "$raw" | jq -r '.upload')
ping_ms=$(echo "$raw" | jq -r '.ping')
server=$(echo "$raw" | jq -r '.server.sponsor + " (" + .server.name + ")"')
isp=$(echo "$raw" | jq -r '.client.isp')

# Convert bits/s to Mbit/s with 2 decimal places
download_mbps=$(echo "$download_bps" | awk '{printf "%.2f", $1 / 1000000}')
upload_mbps=$(echo "$upload_bps" | awk '{printf "%.2f", $1 / 1000000}')
ping_rounded=$(echo "$ping_ms" | awk '{printf "%.1f", $1}')

# Build new entry
new_entry=$(jq -n \
    --arg ts "$timestamp" \
    --argjson dl "$download_mbps" \
    --argjson ul "$upload_mbps" \
    --argjson ping "$ping_rounded" \
    --arg srv "$server" \
    --arg isp "$isp" \
    '{timestamp: $ts, download_mbps: $dl, upload_mbps: $ul, ping_ms: $ping, server: $srv, isp: $isp}')

# Calculate cutoff timestamp (30 days ago)
cutoff=$(date -d "-${MAX_AGE_DAYS} days" -Iseconds 2>/dev/null || date -v-${MAX_AGE_DAYS}d -Iseconds 2>/dev/null)

# Append to data file and rotate old entries
updated=$(date -Iseconds)
tmp=$(mktemp)
jq --argjson entry "$new_entry" --arg cutoff "$cutoff" --arg updated "$updated" '
    .results += [$entry] |
    .results |= map(select(.timestamp > $cutoff)) |
    .updated = $updated
' "$DATA_FILE" > "$tmp" && mv "$tmp" "$DATA_FILE"

chmod 644 "$DATA_FILE"

logger -t "$LOG_TAG" "Done: ${download_mbps} Mbit/s down, ${upload_mbps} Mbit/s up, ${ping_rounded} ms ping"
