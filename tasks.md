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

### TASK-227: Audit all 182 pages and identify redundant/overlapping functionality
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: HIGH
- **Description**: Review all 182 HTML pages in the web app and create a consolidation report identifying: (1) pages that do essentially the same thing, (2) pages that could be merged, (3) pages that are never used/visited, (4) pages that duplicate functionality
- **Notes**: This is the first step of consolidation. Output should be a clear list of merge/remove recommendations.

### TASK-228: Merge monitoring/metrics pages into unified dashboard
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: HIGH
- **Description**: Identify all pages related to system monitoring (health.html, metrics.html, pulse.html, nerve-center.html, etc.) and consolidate them into a single comprehensive monitoring view with tabs/sections instead of separate pages
- **Notes**: Too many monitoring pages creates confusion. Users need one place for system health.

### TASK-229: Consolidate agent-related pages into single agent hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: HIGH
- **Description**: Merge agent-related pages (agents.html, agent-knowledge.html, agent-quotas.html, profiles.html, etc.) into a unified Agent Hub with tabbed navigation
- **Notes**: Agent information is scattered across too many pages.

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

---

## In Progress

---

## Completed

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

*Last updated: 2026-01-23 14:45 by supervisor (CONSOLIDATION PHASE INITIATED)*

---
