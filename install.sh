#!/bin/bash
# install.sh - Setup speedtest-monitor
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_ROOT="/var/www/html"
CRON_SCHEDULE="0 * * * *"

echo "=== Speed Monitor Setup ==="

# 1. Install speedtest-cli
if ! command -v speedtest-cli &>/dev/null; then
    echo "[1/4] Installing speedtest-cli..."
    pip3 install speedtest-cli
else
    echo "[1/4] speedtest-cli already installed"
fi

# Verify jq is available
if ! command -v jq &>/dev/null; then
    echo "[!] jq is required. Installing..."
    sudo apt-get install -y jq
fi

# 2. Make scripts executable
echo "[2/4] Setting permissions..."
chmod +x "$SCRIPT_DIR/speedtest.sh"

# 3. Symlink to web root
echo "[3/4] Deploying to $WEB_ROOT..."
sudo ln -sf "$SCRIPT_DIR/index.html" "$WEB_ROOT/speedtest.html"

# Initialize data file if needed
if [ ! -f "$WEB_ROOT/speedtest-data.json" ]; then
    echo '{"results":[],"updated":""}' | sudo tee "$WEB_ROOT/speedtest-data.json" > /dev/null
    sudo chmod 644 "$WEB_ROOT/speedtest-data.json"
fi

# 4. Setup cron job
echo "[4/4] Setting up cron job (hourly)..."
CRON_CMD="$CRON_SCHEDULE $SCRIPT_DIR/speedtest.sh"
(crontab -l 2>/dev/null | grep -v "speedtest.sh"; echo "$CRON_CMD") | crontab -

echo ""
echo "=== Setup complete ==="
echo "Dashboard: http://$(hostname -I | awk '{print $1}')/speedtest.html"
echo "Cron: hourly ($CRON_SCHEDULE)"
echo ""
echo "Run first test: $SCRIPT_DIR/speedtest.sh"
