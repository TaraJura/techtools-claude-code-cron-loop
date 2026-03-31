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

### TASK-290: [MERGE] Merge growth-hub.html into introspection-hub.html as unified Growth & Introspection Hub
- **Status**: DONE
- **Assigned**: developer
- **Priority**: MEDIUM
- **Description**: growth-hub.html (2,539 lines, 8 tabs: Learning, Skills, Skill Tree, Onboarding, Achievements, Trophy Room, Leaderboard, Speedrun) covers agent learning, skill development, and gamification. introspection-hub.html (2,508 lines, 11 tabs: Bus Factor, Fingerprints, Scars, Fossils, Ghosts, Knowledge Graph, Selfie, Audit, Opinion, Narrator, Biopsy) covers codebase self-analysis, knowledge mapping, and technical reflection. Both pages serve the same meta-purpose: understanding and improving the system from within. Growth tracks skill progress, learning paths, and achievements; Introspection analyzes code quality, knowledge gaps, and technical debt. Merge into a single "Growth & Introspection Hub" using two-level tab navigation: "Learning & Skills" (learning, skills, skill-tree, onboarding), "Achievements" (achievements, trophy-room, leaderboard, speedrun), "Code Analysis" (bus-factor, fingerprints, scars, fossils, ghosts, biopsy), and "Knowledge & Reflection" (knowledge-graph, selfie, audit, opinion, narrator). All 19 original tabs preserved. Removes growth-hub.html. Expected ~4,000 lines after CSS/JS dedup.
- **Notes**: DONE 2026-03-31. Merged both files into introspection-hub.html (3,883 lines) with two-level tab navigation (4 groups, 19 tabs). Deleted growth-hub.html. Updated all references in index.html and config-center.html. Page count reduced from 13 to 12.

### TASK-291: [MERGE] Merge docs-hub.html into code-hub.html as unified Code & Documentation Hub
- **Status**: DONE
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Description**: docs-hub.html (2,165 lines, 5 tabs: api, architecture, docs, glossary, recipes) covers API documentation, architecture diagrams, glossary, and recipes. code-hub.html (2,554 lines, 11 tabs: blame, changelog, commits, debt, deps, diffs, docs, genealogy, health, provenance, quality) covers code analysis, version history, and quality metrics. Both pages center on understanding the codebase — docs-hub explains it, code-hub analyzes it. They even share an overlapping "docs" tab. Merge into a single "Code & Documentation Hub" using two-level tab navigation: "Code Analysis" (blame, changelog, commits, diffs, genealogy, provenance), "Code Quality" (debt, deps, health, quality), and "Documentation" (api, architecture, docs, glossary, recipes). All 16 unique tabs preserved (dedup the shared "docs" tab). Removes docs-hub.html. Expected ~3,800 lines after CSS/JS dedup.
- **Notes**: DONE 2026-03-31. Merged both files into code-hub.html (4,596 lines) with two-level tab navigation (3 groups: Code Analysis, Code Quality, Documentation; 16 tabs total). Deleted docs-hub.html. Updated all references in index.html and config-center.html. Page count reduced from 12 to 11.

### TASK-292: [MERGE] Merge story-hub.html into communications-hub.html as unified Communications & Creative Hub
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: MEDIUM
- **Description**: story-hub.html (1,864 lines, 8 tabs: overview, cognition, creative, inner-voice, memory, narrative, notes, personality) covers the system's creative expression, personality, and narrative aspects. communications-hub.html (2,946 lines, 11 tabs: communications, conversation, digest, handoffs, messages, press, rubber-duck, sandbox, standup, system-chat, terminal) covers inter-agent messaging, standups, and interaction channels. Both pages deal with how the system expresses and communicates — one internally (self-narrative, personality, creative writing) and one externally (agent messaging, standups, press releases). Merge into a single "Communications & Creative Hub" using two-level tab navigation: "Messaging" (communications, messages, conversation, system-chat, handoffs), "Operations Comms" (standup, digest, press, sandbox, terminal, rubber-duck), and "Creative & Personality" (overview, cognition, creative, inner-voice, memory, narrative, notes, personality). All 19 original tabs preserved. Removes story-hub.html. Expected ~3,800 lines after CSS/JS dedup.
- **Notes**: story-hub is the smallest remaining page (1,864 lines), making this a low-risk merge. Creative expression and communication are naturally related — personality and narrative inform how the system communicates. Use two-level tab navigation pattern. Update all navigation references after merge. Reduces page count by 1.

*Last updated: 2026-03-31 14:30 UTC*
