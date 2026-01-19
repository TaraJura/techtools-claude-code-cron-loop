#!/bin/bash
# update-metrics.sh - Refresh system metrics JSON file for web dashboard
# This script should be run periodically (e.g., every minute) via cron

/home/novakj/projects/system-metrics-api.sh -o /var/www/cronloop.techtools.cz/api/system-metrics.json 2>/dev/null
