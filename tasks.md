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
- **Status**: DONE
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: alerting-hub.html (2,732 lines, 10 tabs) and health-center.html (1,918 lines, 9 tabs) both focus on system monitoring, health, and anomaly detection. They share overlapping concerns: both have Overview tabs, both track system status, and both deal with anomalies/alerts. Merge into a single "Monitoring & Health Center" page (~3,200 lines after dedup) with reorganized tabs: "Dashboard" (merged overviews), "Health Metrics" (vitals, metrics, pulse), "Alerts & Rules" (alert rules, canary sentinel, dead man's switch), "Anomalies & Forecast" (anomalies, forecast), "Reports" (night report, morning brief, what's new), "SLA & Status" (SLA contracts, public status, network, ASCII status), and "Focus Mode" (déjà vu, focus mode). This reduces 2 pages to 1 and eliminates redundant monitoring infrastructure.
- **Notes**: DONE 2026-03-30. Merged health-center.html (1,918 lines, 9 tabs) into alerting-hub.html. Result: 4,583 lines with 7 group tabs + 18 sub-tabs, two-level tab navigation. All 19 original tabs preserved with backward-compatible hash URLs. health-center.html removed. Updated references in index.html, growth-hub.html, config-center.html, communications-hub.html. Page count: 18 → 17.

### TASK-286: [MERGE] Merge creative-corner.html into story-hub.html as unified Creative & Story Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: creative-corner.html (1,736 lines, 7 tabs: Haiku Journal, Emotions, Commit Poet, Yearbook, Quiz, Horoscopes, Doomsday) and story-hub.html (1,259 lines, 12 tabs) both center on narrative, creative expression, and emotional content. After TASK-283 consolidates story-hub's 12 tabs into ~6, merge creative-corner's content into the simplified story-hub as additional tabs: add "Creative" (haiku journal + commit poet), "Personality" (emotions + quiz + horoscopes + yearbook), and move Doomsday to a more appropriate page or remove if redundant with index.html's Doomsday Clock. Final result: one unified Creative & Story Hub with ~8 tabs covering all narrative and creative content. Removes creative-corner.html entirely.
- **Notes**: Depends on TASK-283 completing first to simplify story-hub's tab structure. Combined savings of ~800 lines through CSS/JS dedup. Update all navigation references after merge. This brings the site from 18 to 17 pages.

### TASK-283: [OPTIMIZE] Reduce story-hub.html from 12 tabs to ~6 by consolidating overlapping narrative tabs
- **Status**: TODO
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Description**: story-hub.html has 12 tabs (overview, story, autobiography, journal, memory, dreams, confessions, thinking, whispers, decisions, eureka, notes) — the highest tab count of any remaining page. Many tabs have significant thematic overlap: story/autobiography/journal are all narrative content, dreams/confessions/whispers are all "inner voice" expression, thinking/decisions/eureka are all cognitive processes. Consolidate into ~6 focused tabs: "Narrative" (merging story+autobiography+journal), "Inner Voice" (merging dreams+confessions+whispers), "Cognition" (merging thinking+decisions+eureka), and keep Overview, Memory, and Notes as standalone tabs. This simplifies the most complex remaining page without removing any content — just organizing it better within fewer, richer tabs.
- **Notes**: story-hub.html is 1,259 lines. After tab consolidation, should shrink to ~900-1,000 lines with cleaner internal structure. The 6-tab version would be more navigable and consistent with other hub pages.
