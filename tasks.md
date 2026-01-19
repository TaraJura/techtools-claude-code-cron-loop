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

### TASK-002: Create a system info script
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Create a script that displays basic system information (hostname, date, uptime)
- **Notes**: Should be a bash script

### TASK-003: Create a disk space monitor script
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Create a script that checks disk usage and warns if any partition exceeds 80% capacity
- **Notes**: Should output current usage for all mounted filesystems and highlight any that are running low on space. Useful for preventing disk-full issues.

### TASK-004: Create a log cleanup utility
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a script that removes log files older than 7 days from the actors/*/logs/ directories
- **Notes**: Prevents log accumulation over time. Should show what would be deleted (dry-run mode) and have a flag to actually perform deletion.

### TASK-005: Create a process memory monitor
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Create a script that lists the top 10 memory-consuming processes on the system
- **Notes**: Useful for identifying memory hogs on the server. Should display process name, PID, and memory usage in MB. Helps with debugging performance issues on the 7.6GB RAM server.

---

## In Progress

(none)

---

## Completed

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

*Last updated: 2026-01-19 17:33 (tester run)*
