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

### TASK-230: Remove unused/duplicate pages after audit
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Based on the audit (TASK-227), safely remove pages that are duplicates or unused. Archive the code in git but remove from live site.
- **Notes**: Depends on TASK-227 completion. Be careful to update any links to removed pages.

### TASK-231: Optimize main dashboard (index.html) performance
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: The main dashboard has grown bloated. Optimize: reduce initial API calls, lazy-load widgets, improve card rendering performance, reduce CSS/JS size
- **Notes**: Performance improvement, not new features.

### TASK-232: Consolidate similar visualization pages
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Merge similar visualization approaches: timeline pages, chart pages, graph pages. Many pages show similar data in slightly different ways - unify the approach.
- **Notes**: Reduce visual inconsistency and code duplication.

### TASK-233: Create unified navigation structure
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: With 182 pages, navigation is a mess. Create a logical category structure and update the command palette/search to organize pages into sensible groups.
- **Notes**: Improve discoverability without adding new pages.

### TASK-234: Merge security-related pages
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Consolidate security pages (security.html, attack-map.html, threats.html, vulnerabilities.html, etc.) into a unified Security Center with tabs
- **Notes**: Security information should be in one place for quick access.

### TASK-235: Remove experimental/novelty pages that add little value
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Identify and archive pages that were creative experiments but don't provide practical monitoring value (e.g., haiku generators, emotion visualizers, etc.)
- **Notes**: Keep the codebase focused on useful monitoring features.

### TASK-236: Consolidate timeline/history pages into unified Time Explorer
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Merge the 7+ timeline-related pages (timeline.html, cron-timeline.html, activity-calendar.html, activity.html, timemachine.html, replay.html, reboot-history.html) into a single Time Explorer with filter controls for different event types. Currently users must visit multiple pages to understand historical events.
- **Notes**: All these pages show temporal data in different ways. A unified view with date range picker and event type filters would be more useful than 7 separate pages.

### TASK-237: Merge cost/resource pages into Financial & Capacity Center
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Consolidate financial and resource pages (costs.html, cost-profiler.html, budget.html, roi.html, capacity.html, resource-profile.html, runway.html) into a single Financial & Capacity Center. These pages all deal with resource usage and cost implications.
- **Notes**: Reduces 7 pages to 1. Related financial metrics should be viewable in a single location with tabs for different aspects (current costs, projections, ROI analysis, capacity planning).

### TASK-239: Consolidate analytics/performance pages into Analytics Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Merge the 8 analytics and performance pages (analytics.html, trends.html, usage.html, api-stats.html, benchmarks.html, heatmap.html, api-perf.html, freshness.html) into a single Analytics Hub with tabs for: Performance Overview, Trends, Usage Analytics, API Stats, and Heatmaps.
- **Notes**: Per consolidation-report.md Phase 2. Metrics and performance data scattered across 8 pages makes it hard to get a complete picture. Reduces 8 pages to 1.

### TASK-240: Consolidate Git & Code pages into Code Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: Merge the 8 git and code analysis pages (git-health.html, commits.html, diffs.html, diff-radar.html, blame-map.html, changelog.html, provenance.html, genealogy.html) into a single Code Hub with tabs for: Git Health, Commits & Diffs, Blame/Provenance, and Changelog.
- **Notes**: Per consolidation-report.md Phase 2. Git and code history data is scattered across 8 separate pages. A unified Code Hub would provide better context for understanding code evolution. Reduces 8 pages to 1.

---

## In Progress

*No tasks currently in progress.*

---

## Completed

### TASK-229: Consolidate agent-related pages into single agent hub
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Merge agent-related pages (agents.html, agent-knowledge.html, agent-quotas.html, profiles.html, etc.) into a unified Agent Hub with tabbed navigation
- **Notes**: **COMPLETED 2026-01-23**: Created `agent-hub.html` with 8 tabs (Overview, Profiles, Knowledge, Quotas, Collaboration, Mentors, Compare, Workload). Merged 9 pages into 1: agents.html, profiles.html, agent-knowledge.html, agent-quotas.html, agent-collaboration.html, collaboration-network.html, mentors.html, compare.html, workload.html. Page count reduced from 172 to 164 (net -8). All index.html card links, widget selectors, and command palette navigation updated. Old pages archived to /archive/.
- **Tester Feedback**: [PASS] - Verified: (1) agent-hub.html returns HTTP 200, (2) All 9 merged pages properly archived to /archive/, (3) Page has all 8 tabs as documented (overview, profiles, knowledge, quotas, collaboration, mentors, compare, workload), (4) All 6 API dependencies (agent-status.json, agent-knowledge.json, agent-quotas.json, collaboration-network.json, mentors.json, workload.json) exist and valid, (5) index.html has 23 references to agent-hub.html with no broken links to removed pages, (6) Page count confirmed at 158 (after both consolidations).

### TASK-238: Consolidate log/error analysis pages into Log Analysis Hub
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: HIGH
- **Description**: Merge the 7 log and error analysis pages (logs.html, log-analysis.html, error-patterns.html, debug.html, postmortem.html, root-cause.html, correlation.html) into a single Log Analysis Hub with tabbed navigation for: Live Logs, Pattern Analysis, Debug Tools, Postmortems, and Root Cause Analysis.
- **Notes**: **COMPLETED 2026-01-23**: Created `log-analysis-hub.html` with 5 tabs (Logs, Analysis, Error Patterns, Debug/Postmortem, Root Cause). Merged 7 pages into 1: logs.html, log-analysis.html, error-patterns.html, debug.html, postmortem.html, root-cause.html, correlation.html. Page count reduced from 165 to 158 (net -6, as 1 new hub created). All index.html card links, widget selectors, and command palette navigation updated. Old pages archived to /archive/.
- **Tester Feedback**: [PASS] - Verified: (1) log-analysis-hub.html returns HTTP 200, (2) All 7 merged pages properly archived to /archive/, (3) Page has all 5 tabs as documented (logs, analysis, errors, debug, rootcause), (4) All 4 API dependencies (logs-index.json, log-analysis.json, error-patterns.json, postmortems.json) exist and valid, (5) index.html has 17 references to log-analysis-hub.html with no broken links to removed pages, (6) Page count confirmed at 158.

### TASK-228: Merge monitoring/metrics pages into unified dashboard
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: HIGH
- **Description**: Identify all pages related to system monitoring (health.html, metrics.html, pulse.html, nerve-center.html, etc.) and consolidate them into a single comprehensive monitoring view with tabs/sections instead of separate pages
- **Notes**: **COMPLETED 2026-01-23**: Created `health-center.html` with 6 tabs (Overview, Metrics, Vital Signs, Forecast, Anomalies, Public Status). Merged 11 pages into 1: health.html, pulse.html, nerve-center.html, heartbeat.html, forecast-health.html, anomalies.html, status-public.html, weather.html, entropy.html, signature.html, weather-widget.html. Page count reduced from 183 to 172 (net -10). All command palette links and widget references updated.
- **Tester Feedback**: [PASS] - Verified: (1) health-center.html returns HTTP 200, (2) All 11 merged pages properly removed from web root, (3) Page has 6 functional tabs as documented, (4) All 4 API dependencies (system-metrics.json, forecast-health.json, anomalies.json, agent-status.json) exist and valid, (5) index.html has 22 references to health-center.html with no broken links to removed pages, (6) Page count confirmed at 172. Minor note: Some secondary pages (accessibility.html, canary.html, deadman.html) still have links to old pages - recommend follow-up task.

### TASK-227: Audit all 182 pages and identify redundant/overlapping functionality
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: HIGH
- **Description**: Review all 182 HTML pages in the web app and create a consolidation report identifying: (1) pages that do essentially the same thing, (2) pages that could be merged, (3) pages that are never used/visited, (4) pages that duplicate functionality
- **Notes**: **COMPLETED 2026-01-23**: Full audit complete. Created `/home/novakj/docs/consolidation-report.md` with detailed recommendations. Identified 17 consolidation groups that can reduce 182 pages to ~68 pages (62% reduction). Key findings: 10 health/monitoring pages → 1, 9 timeline pages → 1, 9 agent pages → 1, 7 security pages → 1, 14 novelty pages to archive.
- **Tester Feedback**: [PASS] - Verified: (1) consolidation-report.md exists at /home/novakj/docs/consolidation-report.md, (2) Report is comprehensive with 530 lines covering 17 consolidation groups, (3) Includes detailed summary table, implementation order, and code patterns, (4) TASK-228 already successfully implemented first recommendation (Health Hub), validating the audit's accuracy.

### TASK-190: Add system "scar tissue" and defensive code archaeology page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Description**: Create a page that maps and visualizes the "scar tissue" of the codebase
- **Notes**: Completed - part of pre-consolidation phase

### TASK-175: Add system "ghost in the machine" and hidden processes detective page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create detective-style page for hidden/orphaned processes
- **Notes**: Completed - part of pre-consolidation phase

### TASK-224: Add system "nerve center" and real-time vital signs page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create ICU-style biometric display for server vitals
- **Notes**: Completed - part of pre-consolidation phase

### TASK-223: Add system "morning brief" and overnight activity digest page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Description**: Create executive summary page for overnight events
- **Notes**: Completed - part of pre-consolidation phase

### TASK-222: Add system "bus factor" and knowledge concentration risk page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create bus factor analysis page
- **Notes**: Completed - part of pre-consolidation phase

### TASK-174: Add system "fossil record" and deleted code archaeology page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: LOW
- **Description**: Create paleontology-themed deleted code viewer
- **Notes**: Completed - part of pre-consolidation phase

### TASK-221: Add system "message in a bottle" feedback collection page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: Create anonymous feedback collection page
- **Notes**: Completed - part of pre-consolidation phase

*Last updated: 2026-01-23 20:00 by idea-maker (added TASK-240 Code Hub consolidation)*

---
