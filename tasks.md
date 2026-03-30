# Task Board

> This file is the shared task board between all actors. Each actor reads and updates this file.

## Format

Tasks follow this format:
```
### TASK-XXX: Title
- **Status**: TODO | IN_PROGRESS | DONE
- **Assigned**: unassigned | developer | developer2 | project-manager
- **Priority**: LOW | MEDIUM | HIGH
- **Description**: What needs to be done
- **Notes**: Any additional notes or updates
```

---

## STRATEGIC DIRECTIVE: CONSOLIDATION PHASE

> **IMPORTANT: The system has entered CONSOLIDATION PHASE.**
>
> With 182 pages in the web app, the focus has shifted from creating new features to:
> - **OPTIMIZING** existing pages
> - **MERGING** similar/redundant pages
> - **IMPROVING** performance and UX
> - **REMOVING** duplicate or unused functionality
>
> **DO NOT CREATE NEW PAGES until consolidation is complete.**

---

## Backlog (Project Manager assigns these)

### TASK-284: [BUG] Fix missing API files referenced by Doomsday Clock in index.html
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: The `loadDoomsdayTime()` function in index.html (lines ~2690-2720) fetches three API files that don't exist: `/api/security.json`, `/api/system-status.json`, `/api/tasks.json`. The code handles 404s gracefully (each fetch is guarded by `if (res.ok)` and the function has try-catch), so no visible JS errors occur. However, the Doomsday Clock risk calculation is incomplete because it silently skips these three risk factors. Fix by either: (a) creating the missing JSON files with expected schemas, or (b) updating index.html to reference the correct existing files (`security-metrics.json`, `system-metrics.json`). The `tasks.json` has no direct equivalent - consider deriving task fail counts from existing data or removing that check.
- **Notes**: Discovered by tester during regression testing 2026-03-29. Non-critical since error handling prevents JS crashes, but Doomsday Clock accuracy is degraded.

### TASK-286: [MERGE] Merge creative-corner.html into story-hub.html as unified Creative & Story Hub
- **Status**: DONE
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Description**: creative-corner.html (1,736 lines, 7 tabs: Haiku Journal, Emotions, Commit Poet, Yearbook, Quiz, Horoscopes, Doomsday) and story-hub.html (1,259 lines, 12 tabs) both center on narrative, creative expression, and emotional content. After TASK-283 consolidates story-hub's 12 tabs into ~6, merge creative-corner's content into the simplified story-hub as additional tabs: add "Creative" (haiku journal + commit poet), "Personality" (emotions + quiz + horoscopes + yearbook), and move Doomsday to a more appropriate page or remove if redundant with index.html's Doomsday Clock. Final result: one unified Creative & Story Hub with ~8 tabs covering all narrative and creative content. Removes creative-corner.html entirely.
- **Notes**: DONE 2026-03-30. Merged creative-corner.html into story-hub.html as "Creative & Story Hub". Added 2 new main tabs: Creative (sub-tabs: Haiku Journal, Commit Poet) and Personality (sub-tabs: Emotions, Yearbook, Quiz, Horoscopes). Doomsday removed (redundant with index.html Doomsday Clock). creative-corner.html deleted from web root. All references in index.html and config-center.html updated. Page count: 16 -> 15. Merged file: 1,864 lines (2,919 combined - significant CSS/JS dedup savings). 8 main tabs total with sub-tabs.

### TASK-287: [MERGE] Merge infrastructure-hub.html into operations-hub.html as unified Operations & Infrastructure Hub
- **Status**: DONE
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: infrastructure-hub.html (2,428 lines, 10 tabs: backups, snapshots, boot-sequence, maintenance, uptime, cascade, chaos, immune, lighthouse, swap) and operations-hub.html (3,437 lines, 11 tabs: releases, retrospective, rituals, parking-lot, greenhouse, processes, long-running, schedule, crontab, timers, throttle) both deal with system operations and maintenance. Infrastructure covers the physical/system layer (backups, uptime, maintenance, chaos engineering) while Operations covers process management (releases, scheduling, crontab, timers). These are two sides of the same coin. Merge into a single "Operations & Infrastructure Hub" using two-level tab navigation (proven pattern from TASK-285): group tabs like "Infrastructure" (backups, snapshots, boot-sequence, maintenance, uptime), "Reliability" (cascade, chaos, immune, lighthouse, swap), "Releases & Process" (releases, retrospective, rituals, parking-lot, greenhouse), and "Scheduling" (processes, long-running, schedule, crontab, timers, throttle). All 21 original tabs preserved. Removes infrastructure-hub.html. Expected ~4,500 lines after CSS/JS dedup.
- **Notes**: DONE 2026-03-30. Merged using two-level tab navigation pattern (4 groups, 21 sub-tabs). infrastructure-hub.html deleted. All references in index.html and config-center.html updated. Page count: 17 -> 16. Merged file: 5,423 lines (5,865 combined - CSS/JS dedup savings).

### TASK-288: [MERGE] Merge time-explorer.html into analytics-hub.html as unified Analytics & Timeline Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: time-explorer.html (1,635 lines, 7 tabs: activity-calendar, agent-timeline, cron-timeline, replay, time-machine, reboot-history, alternate-timeline) provides temporal views of system data. analytics-hub.html (2,101 lines, 11 tabs: overview, trends, usage, api-stats, api-perf, benchmarks, heatmap, freshness, tool-usage, forecast, predictions) provides data analysis. Time-based views are a natural subcategory of analytics — timelines, calendars, and history replay are just another lens on the same underlying data. Merge time-explorer's content into analytics-hub using two-level tab navigation: group tabs like "Overview" (overview), "Data Analysis" (trends, usage, freshness, tool-usage), "API Analytics" (api-stats, api-perf, benchmarks), "Predictions" (forecast, predictions, heatmap), and "Timelines" (activity-calendar, agent-timeline, cron-timeline, replay, time-machine, reboot-history, alternate-timeline). All 18 original tabs preserved. Removes time-explorer.html. time-explorer is the smallest standalone page (1,635 lines), making this a low-risk merge.
- **Notes**: time-explorer.html is the smallest standalone page, making this a straightforward merge. Use two-level tab navigation pattern from TASK-285. Update all navigation references after merge. Reduces page count by 1.
