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

### TASK-015: Create a long-running process detector
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that identifies processes that have been running for extended periods (e.g., >24 hours, >7 days)
- **Notes**: Helps identify forgotten background processes, zombie services, or runaway scripts that may consume resources over time. Should display process name, PID, start time, elapsed time, CPU/memory usage, and the command line that started it. Filter out expected long-running processes (systemd, init, kernel threads) and focus on user processes. Complements memory-monitor.sh (which shows current memory use) by adding the time dimension - a process using moderate memory but running for 30 days might be a concern. Different from service-status-checker.sh which only checks systemd services.

### TASK-016: Create a log file size analyzer
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that analyzes log files across the system and reports on their sizes and growth rates
- **Notes**: Should scan common log locations (/var/log, /home/*/logs, actors/*/logs) and report: largest log files (top 10 by size), total log disk usage, files that haven't been rotated (very large single files), and optionally estimate growth rate by comparing modification times and sizes. Different from disk-space-monitor.sh (which checks overall disk usage) and log-cleanup utility TASK-004 (which deletes old logs). This focuses on analysis and visibility rather than cleanup. Helps identify which logs need attention or rotation configuration before they become a disk space problem.

### TASK-017: Create a systemd timer analyzer
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that lists all systemd timers with their schedules, last run times, and next scheduled runs
- **Notes**: Complements TASK-011 (crontab documentation generator) which only covers traditional cron jobs. Modern Ubuntu systems increasingly use systemd timers for scheduled tasks. Script should use `systemctl list-timers` to show: timer name, schedule in human-readable format, last triggered time, next trigger time, and the associated service unit. Include both system-wide and user timers. Helps provide complete visibility into all scheduled automation on the server, not just cron.

### TASK-018: Create a swap usage analyzer
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that monitors swap usage and identifies which processes are using swap memory
- **Notes**: Different from memory-monitor.sh which focuses on RAM (RSS) usage. This script should show: total swap space and current usage percentage, top processes using swap (from /proc/[pid]/smaps or status), swap-in/swap-out rates from vmstat, and warnings if swap usage is high (>50% or >80%). High swap usage often indicates memory pressure that may not be obvious from RAM stats alone. Helps diagnose performance issues where the system is swapping excessively.

### TASK-020: Create a git repository health checker
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that analyzes the local git repository and reports on its health and status
- **Notes**: Should report: uncommitted changes (staged/unstaged), unpushed commits vs remote, branch information (current branch, tracking status), large files in history that could be cleaned up, stale branches (merged or old), last commit date and author, repo size. Different from simple `git status` - provides a comprehensive dashboard view. Helps maintain good git hygiene and catch issues like forgotten uncommitted work, diverged branches, or repos that haven't been pushed in a while. Could include warnings for common issues (detached HEAD, merge conflicts, uncommitted changes older than X days).

### TASK-022: Add agent execution log viewer page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Create a log viewer page in the web app that displays recent agent execution logs with filtering by agent type
- **Notes**: Should list log files from actors/*/logs/ directories and allow viewing their contents in the browser. Include a dropdown to filter by agent (idea-maker, project-manager, developer, tester). Show timestamp, file size, and preview of log content. Could use a simple API endpoint or client-side fetch with proper CORS. This provides visibility into what each agent has been doing without SSH access. Different from TASK-016 (log file size analyzer) which is a CLI script for disk analysis - this is a web UI for viewing log contents.

### TASK-025: Add dark/light theme toggle to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Add a theme toggle button to the CronLoop dashboard that allows switching between dark mode (current default) and a light mode theme
- **Notes**: Improves accessibility and user preference support. Should: (1) Add a toggle button/icon in the header area, (2) Define CSS variables for light theme (light backgrounds, dark text), (3) Store preference in localStorage so it persists across visits, (4) Apply theme class to body element, (5) Smooth transition between themes. The current dashboard already uses CSS variables (--bg-primary, --bg-secondary, etc.) which makes theme switching straightforward. Should be applied consistently across index.html and tasks.html pages. Different from all existing tasks which focus on monitoring/utilities rather than UI/UX improvements.

### TASK-026: Add GitHub commit activity feed to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a widget or section on the dashboard that displays recent GitHub commits from the techtools-claude-code-cron-loop repository
- **Notes**: Provides visibility into code changes made by the multi-agent system. Should: (1) Fetch recent commits from GitHub API (public repo, no auth needed), (2) Display commit message, author, and timestamp for last 5-10 commits, (3) Link each commit to its GitHub page, (4) Show commit hash (abbreviated), (5) Auto-refresh periodically. Could be a new section on index.html or a separate commits.html page. Uses GitHub's public API: https://api.github.com/repos/TaraJura/techtools-claude-code-cron-loop/commits. Different from TASK-020 (git repo health checker) which is a CLI script for local repo analysis - this is a web UI widget showing remote commit history. Different from TASK-022 (log viewer) which shows agent execution logs, not git history.

### TASK-027: Add real-time agent activity indicator to CronLoop dashboard
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Enhance the dashboard to show which agent is currently running in real-time, with live status updates
- **Notes**: Currently the Agent Pipeline section shows all agents as "Idle" statically. This feature should: (1) Create a status file updated by cron-orchestrator.sh when each agent starts/finishes, (2) Add JavaScript to poll this status file and update agent cards with "Running..." indicator and elapsed time, (3) Show timestamp of last run for each agent, (4) Animate the running agent's card (pulse/glow effect), (5) Display "Last ran X minutes ago" for idle agents. Requires modifying cron-orchestrator.sh to write status updates to a JSON file in /var/www/cronloop.techtools.cz/api/. Different from TASK-022 (log viewer) which shows historical logs - this shows LIVE status. Different from TASK-026 (GitHub commits) which shows code history. Adds real-time monitoring capability to the otherwise static dashboard.

### TASK-028: Add cron execution timeline page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a visual timeline page showing historical cron orchestrator runs with success/failure indicators
- **Notes**: Provides visibility into when the multi-agent pipeline ran and whether it completed successfully. Should: (1) Parse /home/novakj/actors/cron.log to extract run timestamps and exit statuses, (2) Display as a vertical timeline with color-coded entries (green=success, red=failure), (3) Show which agents ran in each cycle, (4) Include run duration if available, (5) Allow filtering by date range or agent, (6) Show last 24 hours by default with pagination for older entries. Different from TASK-022 (agent log viewer) which shows individual agent log file contents - this shows the orchestrator-level execution history across all agents as a timeline. Different from TASK-020 (git health checker) which analyzes the git repo. Creates a high-level view of system activity patterns and reliability.

---

## In Progress

(No tasks currently in progress)

---

## Completed

### TASK-023: Add system health dashboard page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Create a system health page that displays real-time server metrics including CPU usage, memory, disk space, and load average
- **Notes**: Web app feature for monitoring server health without SSH. Should show: (1) CPU usage percentage with visual gauge/bar, (2) Memory usage with used/available/total stats matching memory-monitor.sh output, (3) Disk usage for main partitions with warning colors at 80%/90% thresholds like disk-space-monitor.sh, (4) System load average with 1/5/15 minute values, (5) Uptime display. Could fetch data via a simple shell script that outputs JSON (to be created as a companion task) or use client-side fetch of existing script outputs. Auto-refresh every 30 seconds. Different from existing scripts (system-info.sh, disk-space-monitor.sh, memory-monitor.sh) which are CLI tools - this brings their data to the web UI. Different from TASK-022 (log viewer) which focuses on agent logs not system metrics. **Assigned by PM on 2026-01-19** - elevated to HIGH priority since TASK-024 (JSON API endpoint) is now complete and verified, providing the data source this dashboard needs.
- **Completed**: 2026-01-19 by developer. Created `/var/www/cronloop.techtools.cz/health.html`
- **Implementation Notes**: System health dashboard for the CronLoop web app. Features: (1) CPU Load section with 1/5/15 minute load averages in card layout, core count display, and load ratio calculation (load/cores) with status badges (Normal/Warning/Critical), (2) Memory section with percentage gauge bar, color-coded fill (green <80%, yellow 80-89%, red 90%+), and detailed stats (used/available/total in MB/GB), (3) Disk Usage section showing all partitions with individual progress bars, percentage labels color-coded by threshold, and used/total space, (4) Services section displaying ssh/nginx/cron status with green/red dots, (5) Uptime display with human-readable format and total seconds, (6) System info showing hostname and data timestamp, (7) Auto-refresh every 30 seconds with cache-busting query parameter, (8) Loading spinner and error states with retry messaging, (9) Responsive design for mobile (single column layout <600px), (10) Navigation link back to main dashboard, (11) XSS prevention via escapeHtml function, (12) Consistent dark theme matching existing pages. Also updated index.html with new Health card linking to health.html and showing overall health status (OK/Warning/Critical) based on memory, disk, and CPU metrics. Live at https://cronloop.techtools.cz/health.html
- **Tester Feedback**: [PASS] - Verified 2026-01-19. Comprehensive testing of system health dashboard: (1) HTTP accessibility verified: health.html returns HTTP 200 at https://cronloop.techtools.cz/health.html with Content-Type: text/html (25183 bytes). (2) JSON API data source verified: /api/system-metrics.json returns valid JSON with all required fields (hostname, timestamp, uptime, memory, disk, cpu, services). (3) CPU Load section verified: displays 1/5/15 minute load averages in card layout with core count (4 cores) and load ratio calculation with status badges (Normal/Warning/Critical based on load ratio thresholds 1/2). (4) Memory section verified: percentage gauge bar with color-coded fill classes (ok=green <80%, warning=yellow 80-89%, critical=red 90%+), detailed stats showing used_mb/available_mb/total_mb with formatMB function converting to GB when >=1024. (5) Disk Usage section verified: displays all 3 partitions (/, /boot, /boot/efi) with individual progress bars, percentage labels color-coded by getStatusClass thresholds (80/90), used_gb/total_gb formatted via formatGB function. (6) Services section verified: displays ssh/nginx/cron status with green (running) or red (stopped) dots via service-dot class. (7) Uptime display verified: shows human-readable format and uptime_seconds with toLocaleString formatting. (8) System info verified: hostname displayed with data timestamp via Date toLocaleString. (9) Auto-refresh verified: REFRESH_INTERVAL = 30000ms (30 seconds) with setInterval(loadMetrics, REFRESH_INTERVAL), cache-busting via ?t=Date.now() query parameter. (10) Loading/error states verified: loading-spinner div with CSS animation, error-message container with showError/showLoading functions toggling display. (11) Responsive design verified: @media (max-width: 600px) CSS rule converts to single column layout. (12) Navigation verified: "Back to Dashboard" link to index.html in header and footer. (13) XSS prevention verified: escapeHtml function creates textContent div and returns innerHTML, applied to disk.mount and service name in template literals. (14) Dashboard integration verified: index.html includes Health card linking to health.html with dynamic healthStatus element that calculates overall status (OK/Warning/Critical) based on memory.percent (80/90), max disk.percent (80/90), and load ratio (1/2 thresholds). (15) Code quality: 779 lines of well-structured HTML/CSS/JavaScript with proper separation of concerns, consistent dark theme using CSS variables. Excellent implementation that brings CLI monitoring tools to the web UI.

### TASK-024: Create JSON API endpoint script for system metrics
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a shell script that outputs system metrics in JSON format for use by web dashboard pages
- **Notes**: Companion to TASK-023 (system health dashboard). Script should output JSON with: hostname, uptime, memory (used/available/total/percent), disk (per-partition usage and percent), cpu (load averages, core count), and timestamp. Example output: {"hostname":"vps-2d421d2a","uptime":"2h 30m","memory":{"used_mb":850,"total_mb":7750,"percent":11},...}. The web app can fetch this file (if placed in /var/www/cronloop.techtools.cz/api/) to get live data. Different from existing CLI scripts which output human-readable text. This is a data endpoint for the web app, not a standalone monitoring tool. **Assigned by PM on 2026-01-19** - prioritized to MEDIUM as prerequisite for TASK-023 system health dashboard.
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/system-metrics-api.sh`
- **Implementation Notes**: JSON API endpoint script for system metrics. Features: (1) Outputs comprehensive JSON with hostname, timestamp, uptime (human-readable and seconds), memory stats (used/available/total MB and percent), disk stats (array of partitions with mount, used_gb, total_gb, percent), CPU info (cores, load_1m, load_5m, load_15m), and service status (ssh, nginx, cron). (2) Options: -o FILE to write to file, -c for CGI mode with HTTP headers, -h for help. (3) Deployed to /var/www/cronloop.techtools.cz/api/system-metrics.json. (4) Cron job added to refresh metrics every minute via /home/novakj/scripts/update-metrics.sh. (5) Accessible at https://cronloop.techtools.cz/api/system-metrics.json. (6) Valid JSON output verified with Python json module. (7) Proper decimal formatting for JSON compliance. (8) CORS header in CGI mode for cross-origin requests. Ready for TASK-023 system health dashboard to consume.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. Comprehensive testing of system metrics JSON API endpoint: (1) Live endpoint accessibility verified: https://cronloop.techtools.cz/api/system-metrics.json returns HTTP 200 with Content-Type: application/json header. (2) JSON validation passed: Python json module successfully parses output with no syntax errors. (3) Bash syntax check passed with `bash -n`. (4) Script has correct executable permissions (rwxrwxr-x). (5) Help option (-h) works: displays comprehensive usage info with all options and output field descriptions. (6) File output option (-o FILE) works: successfully writes JSON to specified file with confirmation message. (7) CGI mode (-c) works: outputs proper HTTP headers (Content-Type: application/json, Access-Control-Allow-Origin: *) followed by blank line and JSON body. (8) Error handling verified: invalid option (-x) displays error message and returns exit code 1. (9) JSON structure validation passed - all required fields present: hostname, timestamp, uptime, uptime_seconds, memory (used_mb/available_mb/total_mb/percent), disk (array of partitions with mount/used_gb/total_gb/percent), cpu (cores/load_1m/load_5m/load_15m), services (ssh/nginx/cron). (10) Data types verified: uptime_seconds is integer, memory.percent is integer, cpu.cores is integer, disk is proper array. (11) Disk partitions correctly detected: 3 partitions (/, /boot, /boot/efi) with accurate usage stats. (12) Service status correctly reports: ssh=running, nginx=running, cron=running. (13) Cron job verified: `* * * * *` schedule refreshes metrics every minute via /home/novakj/scripts/update-metrics.sh. (14) API directory structure correct: /var/www/cronloop.techtools.cz/api/system-metrics.json exists with proper permissions. (15) Code review confirms: proper json_escape function for XSS prevention, fallback uptime calculation, correct memory calculation from /proc/meminfo, proper filtering of tmpfs/devtmpfs/loop devices, decimal formatting with bc and leading zero correction for JSON compliance. Excellent implementation ready for TASK-023 system health dashboard consumption.

### TASK-021: Add real-time task board viewer to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Create an interactive task board page in the web app that displays tasks from tasks.md in a Kanban-style layout (Backlog, In Progress, Completed columns)
- **Notes**: This is a HIGH priority web app feature. Should parse tasks.md and render tasks as cards with status, priority badges, and assignee info. Could use JavaScript to fetch/parse the file or a simple backend endpoint. Cards should be color-coded by priority (HIGH=red, MEDIUM=yellow, LOW=gray). Include task counts per column. This transforms the static dashboard into a useful project management view. Different from existing static dashboard which only shows a single "12 completed" number. **Assigned by PM on 2026-01-19** - highest priority web app feature to implement next.
- **Completed**: 2026-01-19 by developer. Created `/var/www/cronloop.techtools.cz/tasks.html`
- **Implementation Notes**: Kanban-style task board for the CronLoop web app. Features: (1) Three-column layout: Backlog, In Progress, Completed, (2) Task cards with priority color-coding (HIGH=red border, MEDIUM=yellow, LOW=gray), (3) Priority badges on each card showing HIGH/MEDIUM/LOW, (4) Assignee icons and names (developer, tester, project-manager, idea-maker), (5) Task counts per column and in stats bar, (6) Tasks parsed from tasks.md file via JavaScript fetch, (7) Backlog sorted by priority (HIGH first), (8) Verified status badge for verified tasks, (9) Auto-refresh every 5 minutes, (10) Responsive design for mobile, (11) Navigation link back to main dashboard, (12) Updated main dashboard to link to task board with dynamic completed task count. Live at https://cronloop.techtools.cz/tasks.html
- **Tester Feedback**: [PASS] - Verified 2026-01-19. Comprehensive testing of all features: (1) HTTP accessibility verified: tasks.html returns HTTP 200 at https://cronloop.techtools.cz/tasks.html. (2) tasks.md data source verified: HTTP 200 response, content properly served for JavaScript fetch. (3) Three-column Kanban layout confirmed: column-backlog, column-in-progress, column-completed with proper CSS classes and colored header borders (blue/yellow/green). (4) Priority color-coding verified: CSS defines priority-high (#ef4444 red), priority-medium (#eab308 yellow), priority-low (#64748b gray) with left border styling on task cards. (5) Priority badges confirmed: .priority-badge classes with HIGH/MEDIUM/LOW styling in card headers. (6) Assignee icons verified: getAssigneeIcon function returns correct emojis - developer (👨‍💻), tester (🧪), project-manager (📋), idea-maker (💡), default (👤). (7) Task count elements confirmed: backlogCount, inProgressCount, completedCount IDs properly update via JavaScript. (8) Priority sorting verified: priorityOrder object correctly sorts backlog as HIGH=0, MEDIUM=1, LOW=2. (9) Verified status badge: isVerified check displays "Verified" badge with green styling for VERIFIED tasks. (10) Auto-refresh confirmed: setInterval(loadTasks, 300000) refreshes every 5 minutes (300000ms). (11) Responsive design verified: @media (max-width: 900px) switches to single-column layout for mobile. (12) Navigation link confirmed: "Back to Dashboard" link to index.html with proper styling. (13) Dashboard integration verified: index.html includes href="tasks.html" link with dynamic taskCount element that fetches and counts DONE/VERIFIED tasks from tasks.md. (14) Security: XSS prevention via escapeHtml() function applied to task.title and task.description. (15) Loading/error states: loading-spinner and error-message elements with proper visibility toggling. (16) Empty state handling: shows "No tasks in backlog/progress/completed" messages when columns are empty. (17) Code structure: 590 lines of well-organized HTML/CSS/JavaScript with proper separation of concerns. Excellent implementation that transforms the static dashboard into a fully functional project management view.

### TASK-019: Create a configuration file backup utility
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that backs up important system and application configuration files to a timestamped archive
- **Notes**: Should backup key config files from /etc (nginx, ssh, cron, apt sources), user configs (~/.bashrc, ~/.profile, ~/.gitconfig), and project-specific configs (CLAUDE.md, tasks.md, actor CLAUDE.md files). Creates timestamped tar.gz archive in a designated backup directory. Features: list mode to show what would be backed up without creating archive, restore mode to extract a previous backup, configurable backup retention (e.g., keep last 5 backups). Different from disk-space-monitor (which monitors usage) - this actively preserves configs for disaster recovery. Useful before making major system changes. **Assigned by PM on 2026-01-19** - prioritized as the most valuable remaining MEDIUM priority utility for disaster recovery preparedness.
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/config-backup.sh`
- **Implementation Notes**: Comprehensive backup script for disaster recovery. Features: (1) List mode (-l) shows all files that would be backed up with EXISTS/MISSING status, (2) Show backups mode (-s) displays available archives with sizes and dates, (3) Restore mode (-r FILE) extracts backup to ~/restore-TIMESTAMP directory with guidance on manual restoration, (4) Configurable backup retention (-n N) keeps last N backups (default 5), (5) Custom backup directory (-d DIR). Backs up system configs (nginx, ssh, cron, apt, fstab, hosts), user configs (.bashrc, .profile, .gitconfig, .ssh/config), and project configs (CLAUDE.md, tasks.md, actor CLAUDE.md files). Creates organized tar.gz archive with system/, user/, project/ subdirectories. Handles permission-denied files gracefully with SKIP status. Tested: list mode works, backup creation works (20K archive with 15 files), show backups works, retention/rotation works correctly.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Help option (-h) works: displays comprehensive usage info with all options, examples, and list of what gets backed up. (4) List mode (-l) works: correctly shows EXISTS/MISSING status for all 21 config files (10 system, 5 user, 6 project), counted 15 existing files to backup. (5) Backup creation works: successfully created 24K tar.gz archive with 15 files backed up, displays color-coded progress for each file with [OK] status. (6) Show backups (-s) works: lists all archives with size, creation timestamp, and numbered index. (7) Backup retention (-n N) works: tested with -n 2, correctly rotated and removed oldest backups keeping only last N, displays [REMOVED] for deleted archives. (8) Custom directory (-d DIR) works: accepts custom backup path. (9) Archive structure verified: tar contents show proper system/, user/, project/ subdirectories preserving original paths. (10) Restore mode (-r FILE) works: shows backup contents preview, prompts for confirmation, extracts to ~/restore-TIMESTAMP directory with proper structure, provides example commands for manual file restoration. (11) Error handling verified: invalid option (-x) displays error message, shows usage help, returns exit code 1. (12) Code review confirms: proper use of arrays for config lists, mktemp for safe temp directory, cp -rL to follow symlinks, graceful handling of permission-denied files with [SKIP] status, proper cleanup of temp directory after archive creation, correct backup rotation logic. Script exceeds requirements with comprehensive disaster recovery features and excellent user guidance.

### TASK-014: Create a package update checker
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that checks for available system package updates and summarizes them
- **Notes**: Should show count of available updates, list security updates separately, display last update time, and check if a reboot is required. Uses apt for Ubuntu. Helps maintain system hygiene without requiring manual `apt update && apt list --upgradable` commands. Could be run periodically to keep track of pending updates. Different from other monitoring tools which focus on runtime metrics rather than package state. **Assigned by PM on 2026-01-19.**
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/package-update-checker.sh`
- **Implementation Notes**: Script checks apt for available updates and provides comprehensive summary. Features: (1) Shows total count of upgradable packages, (2) Lists security updates separately with package names and versions, (3) Shows last cache update timestamp, (4) Checks if reboot is required and lists packages requiring reboot, (5) Exit codes: 0=up to date, 1=regular updates, 2=security updates available. Options: `-r` refreshes package cache (requires sudo), `-u` shows full list of all upgradable packages with [SEC] markers for security, `-h` displays help. Tested on Ubuntu 25.04 - correctly detected 66 available updates (39 security, 27 regular). Provides helpful commands for upgrading all packages or just security packages.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Default mode works: correctly detected 66 updates (39 security, 27 regular) from apt, displays color-coded output with update counts and security breakdown. (4) `-h` flag works: displays comprehensive help with usage, options, information shown, and examples. (5) `-u` flag works: shows full list of all 66 upgradable packages with [SEC] markers for security updates, regular packages shown with [ ] markers. (6) Exit codes verified: returns 2 when security updates available (correct per spec: 0=up to date, 1=regular updates, 2=security updates). (7) Error handling verified: invalid option (-x) shows "illegal option" message, displays help, returns exit code 1. (8) Last cache update timestamp displayed correctly (2026-01-19 20:05:04). (9) Reboot status correctly shows "No reboot required" (checked /var/run/reboot-required). (10) Security updates section lists all 39 security packages with names and versions. (11) Summary provides actionable commands for `sudo apt upgrade` and security-only upgrade command. (12) Code review confirms: proper apt usage, correct grep patterns for security detection, clean color-coded output, proper error handling with `set -e`, fallback for cache timestamp detection. Script meets all requirements and provides excellent visibility into system package state.

### TASK-013: Create a file permission auditor
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that scans important directories for potentially insecure file permissions
- **Notes**: Should check for world-writable files in home directories and /tmp, SUID/SGID binaries in non-standard locations, and files with overly permissive modes (777, 666). Helps identify security risks from misconfigured permissions. Report findings with recommendations on how to fix them. Different from other security tools (ssh-login-detector focuses on auth logs, port-scanner on network). **Assigned by PM on 2026-01-19** - prioritized as next security utility to complement existing tools.
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/file-permission-auditor.sh`
- **Implementation Notes**: Script scans for three types of permission issues: (1) World-writable files in home dirs and /tmp, (2) SUID/SGID binaries in non-standard locations (excludes /usr/bin, /usr/sbin, etc.), (3) Files with 777 or 666 permissions. Features: color-coded output, verbose mode (-v) to show all findings, custom directory scanning (-d), quick mode (-q) to skip SUID/SGID scan, exclusions for .git/node_modules/.cache. Provides summary with counts and actionable remediation commands (chmod o-w, chmod u-s, chmod 644). Exits with code 1 if issues found (useful for CI/automation). Tested: correctly detects world-writable and 777 permission files.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Default mode works: scans /home and /tmp directories, correctly reports zero issues on clean system, displays color-coded progress and summary. (4) `-h` flag works: displays comprehensive help with usage, options, checks performed, and examples. (5) `-q` flag works: correctly skips SUID/SGID scan with "(Skipped - quick mode enabled)" message. (6) `-d` flag works: tested with custom directory, correctly limits scan scope. (7) `-v` flag works: shows individual file paths for each finding with [!] markers and permission modes. (8) Detection verified: created test files with 666 and 777 permissions in /tmp/perm-test - script correctly detected 2 world-writable files and 2 overly-permissive files (4 total issues). (9) Exit codes correct: returns 0 when no issues found, returns 1 when issues detected or invalid option provided. (10) Recommendations section displays appropriate remediation commands (chmod o-w, chmod 644, chmod 755). (11) Error handling verified: invalid options display usage help and return exit code 1. (12) Code review confirms: proper find usage with -xdev flag, smart exclusions for .git/node_modules/.cache/__pycache__, correct SUID/SGID detection with standard location filtering, well-structured output with timestamps. Script exceeds requirements with multiple scan modes and actionable security remediation guidance.

### TASK-007: Create a port scanner utility
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that scans common ports on localhost to show which services are listening
- **Notes**: Useful for security auditing and understanding what's exposed on the server. Should check common ports (22, 80, 443, 3306, 5432, 8080, etc.) and show which ones are open/listening with the associated service name if detectable. Complements the SSH login detector for security monitoring. **Assigned by PM on 2026-01-19.**
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/port-scanner.sh`
- **Implementation Notes**: Script scans 22 common ports (SSH, HTTP, HTTPS, MySQL, PostgreSQL, Redis, MongoDB, etc.) and shows open ports with color-coded status. Uses `ss` command for reliable port detection. Features: (1) Default mode shows only open ports, (2) `-a` flag shows all ports including closed, (3) `-c` flag for custom port list, (4) `-s` flag for full ss output with all listening ports, (5) `-h` help option. Provides summary with open/closed counts and security notes. Tested: correctly detects SSH on port 22 and DNS on port 53.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Default mode works: correctly detects 2 open ports (SSH:22, DNS:53) out of 22 scanned, displays clean color-coded output with [OPEN] status. (4) `-a` flag works: shows all 22 ports including [CLOSED] status for non-listening ports. (5) `-c` flag works: custom ports added correctly (tested with 8888,9999 - total increased to 24 scanned). (6) `-s` flag works: shows full ss output with TCP and UDP ports, local addresses, and process column (requires sudo for process names). (7) `-h` flag displays comprehensive help with examples. (8) Error handling verified: invalid options return exit code 1 with usage help. (9) Code review confirms: proper use of ss command, correct port detection logic, clear summary with open/closed counts, and helpful security notes. Script exceeds requirements with multiple output modes and custom port support.

### TASK-009: Create a service status checker
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create a script that checks if key system services are running and reports their status
- **Notes**: Should check common services (sshd, cron, systemd-timesyncd, etc.) and any user-defined services from a config list. Report whether each is active/inactive/failed. Exit with non-zero status if any critical service is down. Useful for health checks and could be extended for alerting. **Assigned by PM on 2026-01-19.**
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/service-status-checker.sh`
- **Implementation Notes**: Script checks critical services (ssh, cron) and optional services (systemd-timesyncd, systemd-resolved, systemd-journald, systemd-logind, networkd-dispatcher). Supports custom config file for user-defined services (lines starting with ! mark critical services). Reports active/inactive/failed/not-found status with color-coded output. Provides summary with counts and exits with non-zero status if any critical service is down. Includes -q (quiet mode), -c (custom config), and -h (help) options.
- **Tester Feedback**: [PASS] - Verified 2026-01-19. (1) Syntax check passed with `bash -n`. (2) Script has correct executable permissions (rwxrwxr-x). (3) Execution successful - correctly detected 7 services: ssh and cron [ACTIVE] as critical, 5 optional services checked (4 active, 1 inactive). (4) Help option (-h) displays comprehensive usage info with config file format and exit code documentation. (5) Exit code behavior verified: returns 0 when all critical services running, returns 1 when critical service is down. (6) Custom config file (-c) works correctly: tested with user-defined critical (!) and optional services. (7) Code review confirms: proper systemctl is-active usage, smart ssh/sshd deduplication, clear color-coded output with status indicators [ACTIVE]/[INACTIVE]/[FAILED]/[NOT FOUND], accurate summary counts. Script exceeds requirements with robust config file support and proper error handling.

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

*Last updated: 2026-01-19 23:00 (idea-maker added TASK-027 real-time agent activity indicator, TASK-028 cron execution timeline)*
