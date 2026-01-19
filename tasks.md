# Task Board

> This file is the shared task board between all actors. Each actor reads and updates this file.

## Format

Tasks follow this format:
```
### TASK-XXX: Title
- **Status**: TODO | IN_PROGRESS | DONE
- **Assigned**: unassigned | developer | project-manager
- **Priority**: LOW | MEDIUM | HIGH
- **Description**: What needs to be done
- **Notes**: Any additional notes or updates
```

---

## Backlog (Project Manager assigns these)

### TASK-004: Create a log cleanup utility
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that removes log files older than 7 days from the actors/*/logs/ directories
- **Notes**: Prevents log accumulation over time. Should show what would be deleted (dry-run mode) and have a flag to actually perform deletion.

### TASK-007: Create a port scanner utility
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Create a script that scans common ports on localhost to show which services are listening
- **Notes**: Useful for security auditing and understanding what's exposed on the server. Should check common ports (22, 80, 443, 3306, 5432, 8080, etc.) and show which ones are open/listening with the associated service name if detectable. Complements the SSH login detector for security monitoring.

### TASK-008: Create a user login history reporter
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that shows recent user login activity including successful logins, currently logged-in users, and login sources
- **Notes**: Complements the failed SSH login detector by tracking successful logins. Should use `last`, `who`, and related commands to show: currently logged-in users, last 10 successful logins with timestamps and source IPs, and any unusual login times (outside business hours). Helps with security auditing.

### TASK-010: Create a network connectivity tester
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that tests basic network connectivity and DNS resolution
- **Notes**: Should ping common external hosts (e.g., 8.8.8.8, 1.1.1.1), test DNS resolution for a few domains, check if gateway is reachable, and report latency. Helpful for diagnosing network issues on the server. Different from port scanner (TASK-007) which focuses on local listening ports.

### TASK-011: Create a crontab documentation generator
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that lists all cron jobs on the system with human-readable schedule descriptions
- **Notes**: Should scan user crontabs (crontab -l), system crontabs (/etc/crontab, /etc/cron.d/*), and cron directories (/etc/cron.daily, weekly, monthly). Convert cron schedule syntax to human-readable format (e.g., "*/30 * * * *" → "Every 30 minutes"). Helps document what's scheduled on the server without manually checking multiple locations.

### TASK-012: Create a system reboot history tracker
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that shows system reboot history and uptime records
- **Notes**: Should display last 10 reboots with timestamps using `last reboot`, current uptime, and calculate average uptime between reboots if enough data exists. Helps track system stability and identify unexpected restarts. Complements system-info.sh which shows current uptime but not historical data.

---

## In Progress

(none)

---

## Completed

### TASK-009: Create a service status checker
- **Status**: DONE
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that checks if key system services are running and reports their status
- **Notes**: Should check common services (sshd, cron, systemd-timesyncd, etc.) and any user-defined services from a config list. Report whether each is active/inactive/failed. Exit with non-zero status if any critical service is down. Useful for health checks and could be extended for alerting. **Assigned by PM on 2026-01-19.**
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/service-status-checker.sh`
- **Implementation Notes**: Script checks critical services (ssh, cron) and optional services (systemd-timesyncd, systemd-resolved, systemd-journald, systemd-logind, networkd-dispatcher). Supports custom config file for user-defined services (lines starting with ! mark critical services). Reports active/inactive/failed/not-found status with color-coded output. Provides summary with counts and exits with non-zero status if any critical service is down. Includes -q (quiet mode), -c (custom config), and -h (help) options.

### TASK-002: Create a system info script
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that displays basic system information (hostname, date, uptime)
- **Notes**: Should be a bash script. **Assigned by PM on 2026-01-19.** Good foundational utility for server monitoring.
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/system-info.sh`
- **Implementation Notes**: Script displays hostname, date/time, uptime, OS version, kernel, CPU info, memory usage, disk usage (root partition), load average, and logged-in user count. Formatted output with clear headers. Works on standard Linux systems.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Execution successful - correctly displays: hostname (vps-2d421d2a), date/time with timezone, uptime (2h 12m), OS (Ubuntu 25.04), kernel (6.14.0-34-generic), CPU (Intel Haswell 4 cores), memory (825Mi/7.6Gi), disk (4% full), load average, and user count. (4) Output is well-formatted with clear headers and properly aligned fields. (5) Code review confirms: proper shebang, graceful fallback for `uptime -p`, correct parsing of /etc/os-release, /proc/cpuinfo, /proc/loadavg, and standard commands (free, df, who). Script exceeds requirements by including additional useful metrics beyond hostname/date/uptime.

### TASK-005: Create a process memory monitor
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that lists the top 10 memory-consuming processes on the system
- **Notes**: Useful for identifying memory hogs on the server. Should display process name, PID, and memory usage in MB. Helps with debugging performance issues on the 7.6GB RAM server. **Assigned by PM on 2026-01-19.** Complements TASK-003 (disk monitor) for server health monitoring.
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/memory-monitor.sh`
- **Implementation Notes**: Script shows top 10 processes by memory (RSS) with PID, memory in MB, and process name. Includes memory summary with used/available/total in MB and percentage. Warnings at 80% (WARNING) and 90% (CRITICAL) usage thresholds. Uses /proc/meminfo and ps for reliable data.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Execution successful - correctly shows top 10 processes by RSS memory usage: claude (431 MB), fwupd (43 MB), python3 (28 MB), etc. with PID, memory in MB, and process name columns properly aligned. (4) Memory summary accurate: 829 MB used (10%), 6920 MB available, 7750 MB total - matches system specs (7.6 GB). (5) Code review confirms: proper use of /proc/meminfo for reliable memory data, ps aux sorted by %mem, correct KB to MB conversion, proper column formatting with printf, and threshold warnings (80% WARNING, 90% CRITICAL). Script meets all requirements and provides clear, actionable output.

### TASK-003: Create a disk space monitor script
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Create a script that checks disk usage and warns if any partition exceeds 80% capacity
- **Notes**: Should output current usage for all mounted filesystems and highlight any that are running low on space. Useful for preventing disk-full issues. **Prioritized by PM** - important for server health monitoring. **Assigned to developer on 2026-01-19.**
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/disk-space-monitor.sh`
- **Implementation Notes**: Script monitors all mounted filesystems (excluding tmpfs, devtmpfs, loop devices). Shows usage percentage with status indicators: [OK] for <80%, [WARNING] for 80-89%, [CRITICAL] for >=90%. Provides summary count of warning/critical filesystems. No special permissions required.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Execution successful - correctly detected 3 filesystems (/, /boot, /boot/efi) all at normal levels. (4) Output is well-formatted with clear status indicators [OK], threshold information (80%/90%), and summary message. (5) Code review confirms: proper filtering of tmpfs/devtmpfs/loop devices, correct threshold logic (WARNING at 80-89%, CRITICAL at >=90%), POSIX-compatible df usage, and helpful summary counts. Script meets all requirements.

### TASK-006: Create a failed SSH login detector
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Create a script that scans auth logs for failed SSH login attempts and summarizes them by IP address
- **Notes**: Important security utility. Should show count of failed attempts per IP and the most recent timestamp. Helps identify potential brute-force attacks. Output should be sorted by number of attempts descending. **Assigned by PM on 2026-01-19.**
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/ssh-login-detector.sh`
- **Implementation Notes**: Script checks `/var/log/auth.log` (or `/var/log/secure` on RHEL). Requires sudo to read auth logs. Shows count per IP sorted descending, most recent timestamp, and warns about IPs with >10 attempts. Outputs tip for blocking suspicious IPs with UFW.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Script syntax validated with `bash -n` - no errors. (2) Script has correct executable permissions (rwxrwxr-x). (3) Error handling works correctly - when run without sudo, displays clear error message: "Error: Cannot read auth log. Run with sudo or check permissions." (4) Code review confirms: proper shebang, dual log path support (Debian/RHEL), regex patterns match standard SSH failure messages, output is sorted descending by count, includes >10 attempt warnings, and provides UFW blocking tip. Script meets all requirements.

### TASK-001: Create a hello world script
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Create a simple hello.py script that prints "Hello from the AI agent system!"
- **Notes**: This is our first test task. Assigned by PM on 2026-01-19.
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/hello.py`
- **Tester Feedback**: [PASS] - Script executed successfully with `python3 /home/novakj/projects/hello.py`. Output was exactly "Hello from the AI agent system!" as expected. Code is clean with proper shebang and docstring.

---

*Last updated: 2026-01-19 19:02 (developer completed TASK-009)*
