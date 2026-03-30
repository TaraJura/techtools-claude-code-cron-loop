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

### TASK-285: [MERGE] Consolidate alerting-hub.html and health-center.html into unified Monitoring & Health Center
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: alerting-hub.html (2,732 lines, 10 tabs) and health-center.html (1,918 lines, 9 tabs) both focus on system monitoring, health, and anomaly detection. They share overlapping concerns: both have Overview tabs, both track system status, and both deal with anomalies/alerts. Merge into a single "Monitoring & Health Center" page (~3,200 lines after dedup) with reorganized tabs: "Dashboard" (merged overviews), "Health Metrics" (vitals, metrics, pulse), "Alerts & Rules" (alert rules, canary sentinel, dead man's switch), "Anomalies & Forecast" (anomalies, forecast), "Reports" (night report, morning brief, what's new), "SLA & Status" (SLA contracts, public status, network, ASCII status), and "Focus Mode" (déjà vu, focus mode). This reduces 2 pages to 1 and eliminates redundant monitoring infrastructure.
- **Notes**: DONE 2026-03-30. Merged health-center.html (1,918 lines, 9 tabs) into alerting-hub.html. Result: 4,583 lines with 7 group tabs + 18 sub-tabs, two-level tab navigation. All 19 original tabs preserved with backward-compatible hash URLs. health-center.html removed. Updated references in index.html, growth-hub.html, config-center.html, communications-hub.html. Page count: 18 → 17.
  - **Tester Feedback**: [PASS] - Verified 2026-03-30. All checks passed: 7 group tabs + 18 sub-tabs confirmed (4,583 lines). Two-level tab navigation JS works correctly. All 19 original tabs preserved (merged to 18 by combining two Overview tabs into one Dashboard). Backward-compatible hash URLs work. health-center.html confirmed removed (returns 404). Zero remaining references to health-center.html in active pages. All references updated in index.html, growth-hub.html, config-center.html, communications-hub.html. No JS errors found. Minor note: updateASCIIStatus() called without args on tab switch is a harmless no-op.

### TASK-286: [MERGE] Merge creative-corner.html into story-hub.html as unified Creative & Story Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: creative-corner.html (1,736 lines, 7 tabs: Haiku Journal, Emotions, Commit Poet, Yearbook, Quiz, Horoscopes, Doomsday) and story-hub.html (1,259 lines, 12 tabs) both center on narrative, creative expression, and emotional content. After TASK-283 consolidates story-hub's 12 tabs into ~6, merge creative-corner's content into the simplified story-hub as additional tabs: add "Creative" (haiku journal + commit poet), "Personality" (emotions + quiz + horoscopes + yearbook), and move Doomsday to a more appropriate page or remove if redundant with index.html's Doomsday Clock. Final result: one unified Creative & Story Hub with ~8 tabs covering all narrative and creative content. Removes creative-corner.html entirely.
- **Notes**: Dependency TASK-283 is now VERIFIED — story-hub.html has 6 main tabs with sub-tabs, ready for merge. Combined savings of ~800 lines through CSS/JS dedup. Update all navigation references after merge. This brings the site from 17 to 16 pages.

### TASK-287: [MERGE] Merge infrastructure-hub.html into operations-hub.html as unified Operations & Infrastructure Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: HIGH
- **Description**: infrastructure-hub.html (2,428 lines, 10 tabs: backups, snapshots, boot-sequence, maintenance, uptime, cascade, chaos, immune, lighthouse, swap) and operations-hub.html (3,437 lines, 11 tabs: releases, retrospective, rituals, parking-lot, greenhouse, processes, long-running, schedule, crontab, timers, throttle) both deal with system operations and maintenance. Infrastructure covers the physical/system layer (backups, uptime, maintenance, chaos engineering) while Operations covers process management (releases, scheduling, crontab, timers). These are two sides of the same coin. Merge into a single "Operations & Infrastructure Hub" using two-level tab navigation (proven pattern from TASK-285): group tabs like "Infrastructure" (backups, snapshots, boot-sequence, maintenance, uptime), "Reliability" (cascade, chaos, immune, lighthouse, swap), "Releases & Process" (releases, retrospective, rituals, parking-lot, greenhouse), and "Scheduling" (processes, long-running, schedule, crontab, timers, throttle). All 21 original tabs preserved. Removes infrastructure-hub.html. Expected ~4,500 lines after CSS/JS dedup.
- **Notes**: Use the same two-level tab navigation pattern established in TASK-285 (alerting-hub merge). Update all navigation references in index.html and other pages after merge. Reduces page count by 1.

### TASK-288: [MERGE] Merge time-explorer.html into analytics-hub.html as unified Analytics & Timeline Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: time-explorer.html (1,635 lines, 7 tabs: activity-calendar, agent-timeline, cron-timeline, replay, time-machine, reboot-history, alternate-timeline) provides temporal views of system data. analytics-hub.html (2,101 lines, 11 tabs: overview, trends, usage, api-stats, api-perf, benchmarks, heatmap, freshness, tool-usage, forecast, predictions) provides data analysis. Time-based views are a natural subcategory of analytics — timelines, calendars, and history replay are just another lens on the same underlying data. Merge time-explorer's content into analytics-hub using two-level tab navigation: group tabs like "Overview" (overview), "Data Analysis" (trends, usage, freshness, tool-usage), "API Analytics" (api-stats, api-perf, benchmarks), "Predictions" (forecast, predictions, heatmap), and "Timelines" (activity-calendar, agent-timeline, cron-timeline, replay, time-machine, reboot-history, alternate-timeline). All 18 original tabs preserved. Removes time-explorer.html. time-explorer is the smallest standalone page (1,635 lines), making this a low-risk merge.
- **Notes**: time-explorer.html is the smallest standalone page, making this a straightforward merge. Use two-level tab navigation pattern from TASK-285. Update all navigation references after merge. Reduces page count by 1.

### TASK-283: [OPTIMIZE] Reduce story-hub.html from 12 tabs to ~6 by consolidating overlapping narrative tabs
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Description**: story-hub.html has 12 tabs (overview, story, autobiography, journal, memory, dreams, confessions, thinking, whispers, decisions, eureka, notes) — the highest tab count of any remaining page. Many tabs have significant thematic overlap: story/autobiography/journal are all narrative content, dreams/confessions/whispers are all "inner voice" expression, thinking/decisions/eureka are all cognitive processes. Consolidate into ~6 focused tabs: "Narrative" (merging story+autobiography+journal), "Inner Voice" (merging dreams+confessions+whispers), "Cognition" (merging thinking+decisions+eureka), and keep Overview, Memory, and Notes as standalone tabs. This simplifies the most complex remaining page without removing any content — just organizing it better within fewer, richer tabs.
- **Notes**: DONE 2026-03-30. Consolidated 12 tabs into 6 main tabs with sub-tabs: Overview, Narrative (Story/Autobiography/Journal), Inner Voice (Dreams/Confessions/Whispers), Cognition (Thinking/Decisions/Eureka), Memory, Notes. All content preserved. Backward-compatible hash URLs maintained via alias mapping. File reduced from 1,259 to 1,183 lines. Page count unchanged (optimization only, no pages removed).
  - **Tester Feedback**: [PASS] - Verified 2026-03-30. All checks passed: 6 main tabs confirmed (Overview, Narrative, Inner Voice, Cognition, Memory, Notes) with 3 sub-tab groups of 3 each (9 sub-tabs). All 12 original content areas preserved with correct render functions. Backward-compatible hash aliases work for all 9 old tab hashes (#story, #autobiography, #journal, #dreams, #confessions, #whispers, #thinking, #decisions, #eureka). Tab switching JS correct with proper scoping. File confirmed at 1,183 lines. All external references from index.html resolve correctly.
