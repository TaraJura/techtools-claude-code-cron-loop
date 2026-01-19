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

### TASK-006: Create a failed SSH login detector
- **Status**: IN_PROGRESS
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Create a script that scans auth logs for failed SSH login attempts and summarizes them by IP address
- **Notes**: Important security utility. Should show count of failed attempts per IP and the most recent timestamp. Helps identify potential brute-force attacks. Output should be sorted by number of attempts descending. **Assigned by PM on 2026-01-19.**

---

## Completed

### TASK-001: Create a hello world script
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Create a simple hello.py script that prints "Hello from the AI agent system!"
- **Notes**: This is our first test task. Assigned by PM on 2026-01-19.
- **Completed**: 2026-01-19 by developer. Created `/home/novakj/projects/hello.py`
- **Tester Feedback**: [PASS] - Script executed successfully with `python3 /home/novakj/projects/hello.py`. Output was exactly "Hello from the AI agent system!" as expected. Code is clean with proper shebang and docstring.

---

*Last updated: 2026-01-19 17:30 (project-manager run)*
