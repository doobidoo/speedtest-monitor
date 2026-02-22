# Speed Monitor

Lightweight internet speed monitoring dashboard. Cron + speedtest-cli + static HTML.

## Architecture

```
Cron (hourly) → speedtest-cli → speedtest.sh → /var/www/html/speedtest-data.json
                                                        ↑
Browser → Nginx → /var/www/html/speedtest.html ─────────┘
```

## Setup

```bash
./install.sh
```

This will:
- Install `speedtest-cli` (via pip3)
- Symlink `index.html` → `/var/www/html/speedtest.html`
- Set up hourly cron job

## Manual Test

```bash
./speedtest.sh
```

## Dashboard

`http://<server-ip>/speedtest.html`

Features: dark theme, download/upload/ping charts, time range filter (24h/7d/30d), auto-refresh.

## Data

- JSON file: `/var/www/html/speedtest-data.json`
- Auto-rotates entries older than 30 days
- ~100KB for 30 days of hourly measurements
