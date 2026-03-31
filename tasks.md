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

### TASK-288: [MERGE] Merge time-explorer.html into analytics-hub.html as unified Analytics & Timeline Hub
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Description**: time-explorer.html (1,635 lines, 7 tabs: activity-calendar, agent-timeline, cron-timeline, replay, time-machine, reboot-history, alternate-timeline) provides temporal views of system data. analytics-hub.html (2,101 lines, 11 tabs: overview, trends, usage, api-stats, api-perf, benchmarks, heatmap, freshness, tool-usage, forecast, predictions) provides data analysis. Time-based views are a natural subcategory of analytics — timelines, calendars, and history replay are just another lens on the same underlying data. Merge time-explorer's content into analytics-hub using two-level tab navigation: group tabs like "Overview" (overview), "Data Analysis" (trends, usage, freshness, tool-usage), "API Analytics" (api-stats, api-perf, benchmarks), "Predictions" (forecast, predictions, heatmap), and "Timelines" (activity-calendar, agent-timeline, cron-timeline, replay, time-machine, reboot-history, alternate-timeline). All 18 original tabs preserved. Removes time-explorer.html. time-explorer is the smallest standalone page (1,635 lines), making this a low-risk merge.
- **Notes**: DONE 2026-03-31. Merged time-explorer.html (1,635 lines) into analytics-hub.html (2,101 lines) → unified 3,199 lines. All 18 tabs preserved across 5 groups (Overview, Data Analysis, API Analytics, Predictions, Timelines) with two-level navigation. Updated references across index.html, config-center.html. Deleted time-explorer.html. Page count: 14 → 13.
  - **Tester Feedback**: [PASS] - Verified 2026-03-31. All 18 tabs present and navigable across 5 groups with two-level navigation. time-explorer.html confirmed deleted. All references in index.html, config-center.html properly redirect to analytics-hub.html with correct hash anchors. Backwards-compatibility aliases in place. analytics-hub.html returns HTTP 200. No broken links found.

### TASK-289: [MERGE] Merge alerting-hub.html into security-center.html as unified Security & Monitoring Center
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: alerting-hub.html (4,583 lines, 7 tab groups: Dashboard, Health Metrics, Alerts & Rules, Anomalies & Forecast, Reports, SLA & Status, Focus Mode) and security-center.html (2,944 lines, 11 tabs: Security, Attack Map, Vulnerabilities, Secrets, Logins, Supply Chain, Agent Logs, Log Analysis, Error Patterns, Debug Postmortem, Root Cause) both focus on monitoring, detection, and response. Security monitoring (vulnerabilities, attacks, secrets) and system health monitoring (alerts, anomalies, SLA) are two sides of the same operational awareness coin. Merge into a single "Security & Monitoring Center" using two-level tab navigation: "Security" (overview, attack-map, vulnerabilities, secrets, logins, supply-chain), "Monitoring" (dashboard, health-metrics, vital-signs, pulse-network), "Alerts & Detection" (alert-rules, dead-man-switch, canary-sentinel, anomalies, error-patterns), "Analysis" (log-analysis, agent-logs, debug-postmortem, root-cause, forecast), "Reports & Status" (night-report, morning-brief, whats-new, sla-contracts, public-status, network, ascii-status), and "Focus" (deja-vu, focus-mode). All original tabs preserved. Removes alerting-hub.html. Expected ~6,000 lines after CSS/JS dedup.
- **Notes**: DONE 2026-03-31. Merged alerting-hub.html (4,583 lines) into security-center.html (2,944 lines) → unified 4,914 lines. All 29 tabs preserved across 6 groups with two-level navigation. Updated 72 references across index.html, config-center.html, growth-hub.html, communications-hub.html. Deleted alerting-hub.html. Page count: 15 → 14.
  - **Tester Feedback**: [PASS] - Verified 2026-03-31. All 29 tabs present and navigable across 6 groups with two-level navigation. alerting-hub.html confirmed deleted. All references in index.html, config-center.html, story-hub.html properly redirect to security-center.html. Backwards-compatibility hash aliases in place. security-center.html returns HTTP 200. No broken links found.

### TASK-290: [MERGE] Merge growth-hub.html into introspection-hub.html as unified Growth & Introspection Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: growth-hub.html (2,539 lines, 8 tabs: Learning, Skills, Skill Tree, Onboarding, Achievements, Trophy Room, Leaderboard, Speedrun) covers agent learning, skill development, and gamification. introspection-hub.html (2,508 lines, 11 tabs: Bus Factor, Fingerprints, Scars, Fossils, Ghosts, Knowledge Graph, Selfie, Audit, Opinion, Narrator, Biopsy) covers codebase self-analysis, knowledge mapping, and technical reflection. Both pages serve the same meta-purpose: understanding and improving the system from within. Growth tracks skill progress, learning paths, and achievements; Introspection analyzes code quality, knowledge gaps, and technical debt. Merge into a single "Growth & Introspection Hub" using two-level tab navigation: "Learning & Skills" (learning, skills, skill-tree, onboarding), "Achievements" (achievements, trophy-room, leaderboard, speedrun), "Code Analysis" (bus-factor, fingerprints, scars, fossils, ghosts, biopsy), and "Knowledge & Reflection" (knowledge-graph, selfie, audit, opinion, narrator). All 19 original tabs preserved. Removes growth-hub.html. Expected ~4,000 lines after CSS/JS dedup.
- **Notes**: Both pages deal with system self-awareness — one from a skill/gamification angle, the other from code/system analysis. Use two-level tab navigation pattern. Update all navigation references after merge. Reduces page count by 1.
