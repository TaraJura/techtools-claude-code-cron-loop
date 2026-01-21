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

## Backlog (Project Manager assigns these)

### TASK-121: Add system achievements and milestone celebration page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a gamification-style page that tracks and celebrates system accomplishments with unlockable achievements, progress badges, and milestone markers
- **Notes**: Recognizes and displays autonomous system accomplishments in a fun, engaging way. Should: (1) Create /achievements.html page with achievement gallery and progress tracking, (2) Achievement categories: Task Milestones (10/50/100/500/1000 tasks completed), Uptime Records (7/30/90/365 days continuous operation), Agent Performance (zero-error streaks, fastest completions), Code Contributions (commits, lines changed, files created), Security Excellence (days without incidents, vulnerabilities prevented), System Health (perfect health score streaks), (3) Unlockable badges with icons and descriptions: "First Blood" (first task completed), "Century Club" (100 tasks), "Marathon Runner" (30-day uptime), "Bug Slayer" (10 bugs fixed), "Security Guardian" (security scan clean for 30 days), (4) Progress bars showing advancement toward next milestone, (5) Achievement timeline showing when each was unlocked with celebration animations, (6) Rare/Epic/Legendary achievement tiers based on difficulty, (7) Agent-specific achievements: "Developer MVP" (most tasks), "Quality Champion" (tester with highest pass rate), (8) Weekly/Monthly achievement summary with confetti animation for new unlocks, (9) Shareable achievement cards (generate image for social sharing), (10) Leaderboard comparing this system's achievements to milestones (self-competition over time), (11) Hidden achievements that unlock through unusual system behavior, (12) Achievement sound effects (optional) for celebration moments, (13) Dashboard card showing latest achievement with keyboard shortcut. Different from efficiency leaderboard (TASK-100) which compares agents competitively - this celebrates SYSTEM accomplishments and adds fun gamification. Different from digest.html which shows daily summaries - this tracks lifetime achievements. Adds personality and celebration to the autonomous system, making monitoring more engaging.

### TASK-120: Add live ASCII art system status terminal page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a retro-style terminal page that displays system status using animated ASCII art visualizations, bringing nostalgic aesthetic to modern monitoring
- **Notes**: Combines retro computing aesthetics with real-time system monitoring. Should: (1) Create /ascii-status.html page with terminal-style interface (green-on-black or amber-on-black theme), (2) ASCII art server diagram showing CPU/RAM/Disk as bar charts using characters like [####----], (3) Animated ASCII agent icons that "work" when their agent is running (typing animation, spinner), (4) ASCII art pipeline flow: idea-maker --> PM --> developer --> tester --> security with data flowing between them, (5) Real-time scrolling log viewer in monospace font resembling classic terminal output, (6) ASCII art system "face" that changes expression based on health (happy :) normal :| concerned :/ error :(, (7) Retro loading spinners and progress indicators using |/-\ characters, (8) "Matrix rain" background effect (optional toggle) showing flowing characters, (9) ASCII art graphs: spark lines for CPU history, vertical bar charts for memory, (10) CRT screen effect (scanlines, slight curve, screen flicker) via CSS for authenticity, (11) Sound effects toggle: keyboard clicks, terminal beeps (optional), (12) Multiple color themes: classic green, amber, blue, white, (13) Full keyboard navigation: arrow keys to move between sections, Enter to drill down, Escape to go back, (14) ASCII art logo/banner for CronLoop at the top, (15) "Hacker mode" easter egg that triggers on certain key sequence, (16) Export current view as .txt file preserving ASCII formatting, (17) Dashboard card with retro terminal icon and keyboard shortcut. Different from terminal.html which provides actual command execution - this is purely VISUALIZATION in ASCII art style. Different from weather.html which uses metaphorical status - this uses retro computing aesthetics. Appeals to developers who appreciate computing history and unique visual design.

### TASK-119: Add agent frustration and emotional intelligence monitor page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that analyzes agent outputs for signs of difficulty, frustration, or repeated struggles, helping identify when agent prompts or tasks need adjustment before problems escalate
- **Notes**: Tracks emotional/behavioral indicators beyond simple success/failure metrics. Should: (1) Create /emotions.html page showing agent emotional health indicators, (2) Frustration detection: scan agent outputs for retry patterns ("let me try again", "that didn't work"), error recovery attempts, repeated tool calls to same file, backtracking behavior, (3) Confidence tracking: analyze language for uncertainty markers ("I think", "probably", "should work") vs confident statements ("this will", "completed"), (4) Engagement indicators: track output length trends, thoroughness of explanations, presence of clarifying questions, (5) Struggle patterns: identify task types where specific agents consistently have difficulty (multiple iterations, errors, eventual failures), (6) Mood timeline: show agent "mood" over last 24 hours based on output analysis (calm → struggling → frustrated → recovered), (7) Early warning system: alert when frustration indicators spike for an agent before it affects task outcomes, (8) Prompt health suggestions: "Developer agent shows frustration with TypeScript tasks - consider adding TS-specific guidance to prompt", (9) Agent wellness dashboard: composite emotional health score per agent (0-100), (10) Comparative view: which agents handle difficult situations gracefully vs which struggle, (11) Recovery tracking: after frustration events, how quickly does agent return to normal patterns?, (12) Historical analysis: are agents generally becoming more confident over time (learning) or more frustrated (prompt decay)?, (13) Dashboard card with emoji indicator (😊😐😓) and keyboard shortcut. Different from profiles.html which shows personality traits - this tracks emotional STATE over time. Different from learning.html which tracks task success rates - this analyzes behavioral PATTERNS for early warning signs. Different from quality.html which scores output quality - this monitors agent WELLNESS. Helps maintain healthy autonomous system by catching agent struggles early.

### TASK-116: Add system chaos engineering test page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page for controlled chaos engineering experiments that tests system resilience by simulating failures and displaying how the system responds and recovers
- **Notes**: Enables proactive resilience testing. Should: (1) Create /chaos.html page with chaos experiment controls and results, (2) Predefined experiments: simulate disk full, high CPU load, memory pressure, network latency, (3) Display expected vs actual system behavior during experiments, (4) Track recovery time after each simulated failure, (5) Show agent behavior during degraded conditions - do they handle errors gracefully?, (6) Results history: log all chaos experiments with timestamps and outcomes, (7) Recommendations: based on results, suggest resilience improvements, (8) Safety controls: experiments only run in safe ranges, automatic abort if system health critical, (9) Comparison charts: system resilience over time - is it getting more robust?

### TASK-111: Add agent execution speed benchmark and performance regression page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that benchmarks and tracks agent execution speeds over time, detecting performance regressions when agents start running slower than their historical baselines
- **Notes**: Provides performance monitoring focused specifically on execution time trends and regressions. Should: (1) Create /benchmarks.html page showing execution time analysis for all agents, (2) Parse agent logs to extract execution duration per run (start timestamp to end timestamp), (3) Display per-agent metrics: current avg execution time, 7-day avg, 30-day avg, all-time avg, with sparkline trends, (4) Calculate execution time percentiles (p50, p90, p99) per agent - identify worst-case outliers, (5) Benchmark comparison: show each agent's current speed vs their personal best, (6) Performance regression alerts: flag when agent execution time increases >20% from 7-day rolling average, (7) Speed leaderboard: rank agents by average execution time (fastest to slowest), (8) Correlation analysis: does execution time increase with task complexity (lines changed, files touched)?, (9) Time-of-day patterns: are agents slower at certain hours (CPU contention from other processes?), (10) Slowdown investigation: for regressed agents, show what changed (more files read? larger outputs? more tool calls?), (11) Benchmark history chart: execution times over last 30 days with trend line and anomaly highlighting, (12) "Speed budget": set target execution times per agent and show compliance percentage. Different from TASK-036 (performance analytics) which tracks SUCCESS rates and productivity - this tracks SPEED/DURATION specifically. Different from TASK-107 (resource profiler) which tracks CPU/memory consumption - this tracks WALL CLOCK execution time. Different from TASK-106 (regression detection) which compares OUTPUT quality - this compares SPEED performance. Different from timeline.html which shows operation sequence - this aggregates DURATION metrics. Different from TASK-100 (leaderboard) which gamifies productivity - this provides BENCHMARK analysis for performance optimization. Helps answer: "Are agents getting slower over time?" and "Which agent needs performance optimization?" Essential for maintaining efficiency as the autonomous system scales and processes more complex tasks.

### TASK-107: Add agent resource consumption profiler page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that profiles and visualizes the resource footprint (CPU, memory, disk I/O, network) consumed by each agent during execution, identifying resource-hungry operations and optimization opportunities
- **Notes**: Provides performance visibility into what system resources agents consume during their runs. Should: (1) Create /resource-profile.html page showing per-agent resource consumption breakdown, (2) Capture resource metrics during agent runs: peak CPU%, peak memory MB, disk read/write MB, network traffic if applicable, (3) Correlate resource spikes with specific operations: "Memory peaked at 500MB during git diff operation", (4) Show resource usage timeline overlaid on agent execution phases (read → process → write), (5) Compare resource consumption across agents: which agent is most resource-intensive?, (6) Track resource trends over time: is developer using more memory than last week?, (7) Identify "expensive operations": specific tool calls or file operations that consume disproportionate resources, (8) Show efficiency metrics: resources consumed per task completed, resources per line of code changed, (9) Detect resource anomalies: agent suddenly using 10x normal memory, (10) Optimization suggestions: "Consider batching these 20 small file reads into fewer operations", (11) Resource budget warnings: alert when agent exceeds expected resource envelope, (12) Export resource profile as JSON for external analysis. Different from health.html which shows current system-wide CPU/memory - this shows PER-AGENT resource consumption. Different from TASK-036 (performance analytics) which tracks execution time and success - this tracks RESOURCE consumption. Different from TASK-101 (cost profiler) which tracks token/API costs - this tracks COMPUTE resources (CPU, memory, disk). Different from memory.html which shows system memory state - this correlates memory with specific agent OPERATIONS. Helps optimize the multi-agent system by identifying which agents or operations are resource bottlenecks and could benefit from optimization.

### TASK-105: Add system entropy and randomness health page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that monitors the system's cryptographic entropy pool health, showing available entropy, consumption patterns, and alerts when entropy runs low (which can cause cryptographic operations to block)
- **Notes**: Provides visibility into a critical but often overlooked system resource that affects SSH, SSL/TLS, and security operations. Should: (1) Create /entropy.html page showing entropy pool status and history, (2) Read current entropy from /proc/sys/kernel/random/entropy_avail (Linux provides this), (3) Display current entropy as a gauge (0-4096, green >1000, yellow 200-1000, red <200), (4) Track entropy history over time with line chart showing available entropy at 5-minute intervals, (5) Show entropy consumption events: when does entropy drop suddenly? (correlate with agent runs, SSH connections, SSL handshakes), (6) Display entropy pool size from /proc/sys/kernel/random/poolsize, (7) Show hardware RNG status if available (rngd, haveged, or TPM), (8) Alert when entropy drops below threshold (200 bits is considered low for Linux), (9) Explain impact: "Low entropy can cause ssh-keygen, openssl, and random number generation to block or become predictable", (10) Show entropy sources: keyboard/mouse (usually none on servers), disk timing, interrupts, hardware RNG, (11) Backend script stores snapshots in /api/entropy-history.json, (12) Integration with health.html showing entropy as a system health metric. Different from health.html which shows CPU/memory/disk - entropy is a unique security-critical resource. Different from security.html which tracks attacks - this tracks cryptographic health. Different from TASK-081 (anomaly detector) which detects statistical outliers - this specifically monitors the kernel's entropy pool. Different from network.html which monitors network metrics - this monitors the RNG subsystem. Entropy starvation is a real problem on headless servers and VMs that can cause cryptographic operations to hang. This page provides visibility into a resource that most monitoring tools ignore but is critical for server security. The autonomous system generates keys, certificates, and random tokens - knowing if entropy is healthy ensures these operations are secure and don't block.

### TASK-102: Add system metrics correlation matrix page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that calculates and visualizes correlations between different system metrics over time, helping identify cause-effect relationships like "when disk usage increases, does error rate also increase?"
- **Notes**: The dashboard currently shows individual metrics in isolation, but doesn't reveal relationships between them. This page should: (1) Load historical data from metrics-history.json and other time-series data, (2) Calculate Pearson correlation coefficients between metric pairs (disk usage, memory, CPU, error rate, task completion rate, agent run duration, token usage, etc.), (3) Display as an interactive correlation matrix heatmap with color coding (-1 to +1 scale, red for negative, blue for positive), (4) Click on any cell to see the scatter plot of the two metrics with trendline, (5) Highlight "significant" correlations (>0.7 or <-0.7) that may indicate causal relationships, (6) Auto-generated insights: "Disk usage and log file size have 0.92 correlation - disk fills because of logs", (7) Lag correlation analysis: check if metric A predicts metric B with a time delay, (8) Show top 5 strongest positive and negative correlations as a summary, (9) Time window selector: correlations over last 24h, 7d, 30d, (10) Filter to include/exclude specific metrics from the matrix, (11) Export correlation data as CSV or JSON, (12) Dashboard card with keyboard shortcut. Different from trends.html (single-metric trends), capacity.html (projections), and health.html (current status). This page reveals hidden relationships between metrics for deeper operational insights.

### TASK-099: Add system vital signs heartbeat monitor with EKG-style visualization to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page with an EKG/ECG-style animated visualization showing the system's "heartbeat" - the rhythmic pattern of agent executions, task completions, and system health pulses
- **Notes**: Provides an intuitive, medical-style view of system vitality. Should: (1) Create /heartbeat.html page with animated EKG-style line graph, (2) Each "heartbeat" represents an agent cycle completion (every 30 mins = one beat), (3) Visualize multiple vital sign lines: agent execution (blue), task completion (green), errors (red), like a multi-lead EKG, (4) Show heart rate analog: beats per hour/day, with normal range indicators, (5) Detect arrhythmias: irregular patterns like missed beats (failed runs), tachycardia (too many errors), bradycardia (slow processing), (6) Calculate system pulse: a single health score that pulses with each cycle, (7) Historical rhythm strip: show last 24 hours of heartbeats with anomalies highlighted, (8) Alert on "cardiac events": flatline (no activity), fibrillation (chaotic errors), arrest (system down), (9) Sound optional: toggle to hear heartbeat audio for ambient monitoring, (10) Show vital stats sidebar: current BPM, last beat time, rhythm status (normal/irregular), (11) Mobile-friendly for glanceable health check, (12) Export rhythm data as time-series JSON. Different from health.html which shows static health metrics - this provides REAL-TIME ANIMATED rhythm visualization. Different from uptime.html which tracks availability - this shows the CADENCE of activity. Different from workflow.html which shows process flow - this is a BIOMETRIC METAPHOR for system health. Inspired by hospital monitors, this gives operators an intuitive sense of whether the system is "alive and well" at a glance.

### TASK-089: Add agent failure cascade analyzer page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that analyzes and visualizes how failures propagate through the multi-agent pipeline, showing downstream impact when one agent fails or produces poor output
- **Notes**: Provides resilience visibility for understanding how agent failures affect the entire system. Should: (1) Create /cascade.html page showing failure propagation analysis, (2) Map the agent dependency chain: idea-maker -> PM -> developer -> tester -> security, and how data flows between them, (3) For each historical agent failure, trace downstream impact: if developer failed, was tester blocked? If PM produced incomplete spec, did developer fail?, (4) Visualize as a flow diagram with red highlighted paths showing failure propagation, (5) Calculate "blast radius" metrics: when agent X fails, what percentage of time does it cause downstream failures?, (6) Identify resilient vs fragile handoffs: which agent transitions have highest failure correlation?, (7) Show recovery time: how long until pipeline resumes normal operation after failure?, (8) Detect cascade patterns: does idea-maker failure ever cause developer failure 2 cycles later?, (9) "What if" simulation: if developer were unavailable for 24 hours, what would happen to task throughput?, (10) Recommendations: surface which agents need better error handling or graceful degradation, (11) Historical cascade timeline: show past cascade events with root cause and total impact, (12) Export failure analysis as JSON for postmortem integration with TASK-078. Different from TASK-047 (architecture graph) which shows STATIC dependencies - this analyzes ACTUAL FAILURE PROPAGATION. Different from TASK-062 (handoff inspector) which shows normal data flow - this focuses on FAILURE scenarios. Different from TASK-081 (anomaly detector) which detects unusual metrics - this traces CAUSAL CHAINS of failures. Different from error-patterns.html which catalogs individual errors - this shows how errors PROPAGATE through the system. Helps answer: "How robust is our multi-agent system?" and "What's the worst-case failure scenario?" Essential for building confidence in autonomous systems where understanding failure modes is critical.

### TASK-087: Add API latency and performance metrics page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that tracks response times for all internal API endpoints (/api/*.json), measuring latency, availability, and performance trends to identify slow or failing data sources
- **Notes**: Provides visibility into dashboard data pipeline health. Should: (1) Create /api-perf.html page showing API endpoint performance, (2) Track fetch latency for all /api/*.json endpoints used by dashboard pages, (3) Display latency metrics per endpoint: min, max, average, p95 response time over last hour/day, (4) Show availability percentage: successful fetches / total attempts per endpoint, (5) Visual latency chart showing response times over time (sparkline per endpoint), (6) Alert indicators for slow endpoints (>500ms average) or failing endpoints (>5% error rate), (7) Waterfall view: when loading index.html, show sequence of API calls with timing bars, (8) Size tracking: track response payload sizes to identify bloated JSON files, (9) Compare current vs historical: "costs.json is 40% slower than yesterday", (10) Automatic endpoint discovery: scan dashboard HTML files to find all fetch() calls to /api/, (11) Health score per endpoint based on latency + availability + size, (12) Export performance report as JSON for external analysis. Different from api-stats.html which tracks USAGE statistics (how often endpoints are called) - this tracks PERFORMANCE (how fast they respond). Different from health.html which shows system metrics (CPU/memory) - this shows API-LAYER metrics. Different from uptime.html which monitors external services - this monitors INTERNAL API endpoints. Different from TASK-036 (agent performance analytics) which tracks agent execution - this tracks API data source performance. Helps identify data pipeline bottlenecks: if changelog.json takes 2 seconds to load, the changelog page will feel slow. Essential for optimizing dashboard performance as JSON files grow over time.

### TASK-082: Add admin scratchpad/notes page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a simple notes page where admins can capture observations, investigation notes, quick reminders, and ad-hoc documentation that persists across sessions
- **Notes**: Provides a quick capture tool for operators monitoring the system who need to jot down findings without leaving the dashboard. Should: (1) Create /notes.html page with a rich text editor or markdown editor, (2) Auto-save notes to localStorage with debounced saves (every 2 seconds of inactivity), (3) Support multiple notes organized by title/date with a sidebar list, (4) Markdown preview toggle (edit mode vs rendered view), (5) Search across all notes by content or title, (6) Timestamp each note with created/modified dates, (7) Tag notes with labels like "investigation", "todo", "reference", "incident", (8) Filter notes by tag, (9) Export individual notes or all notes as markdown or JSON, (10) Import notes from JSON for backup restore, (11) Pin important notes to the top of the list, (12) Quick note button: floating action button for rapid capture without navigating away from current page. Different from TASK-076 (bookmarks) which saves references TO existing items - this creates NEW freeform content. Different from TASK-055 (activity annotations) which adds comments to a shared stream - this is PERSONAL notes that only the admin sees. Different from TASK-078 (postmortems) which generates structured incident reports - this is FREEFORM capture for any purpose. Fills the gap between "I noticed something" and "I need to document this formally" - a casual capture tool that reduces friction for knowledge retention. Essential for operators who spend hours watching dashboards and need somewhere to record their observations.

### TASK-075: Add agent prompt evolution viewer page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that tracks and visualizes how agent prompt.md files have changed over time with side-by-side diff view
- **Notes**: Provides visibility into prompt engineering and agent behavior evolution. Should: (1) Create /prompts.html page showing prompt history for all 5 agents, (2) List all agents with their current prompt.md file paths and last-modified dates, (3) Use git log to retrieve historical versions of each prompt.md file, (4) Side-by-side diff view comparing any two versions of a prompt (current vs previous, or any two commits), (5) Syntax highlighting for markdown content, (6) Change statistics: lines added/removed, word count changes, section changes, (7) Timeline view showing when prompts were modified with commit messages, (8) Detect structural changes: added instructions, removed rules, modified behavior guidelines, (9) Agent behavior correlation: link prompt changes to git commits made by that agent (did behavior change after prompt update?), (10) Search across all prompt versions for specific keywords or instructions, (11) Export prompt diff as markdown for documentation, (12) "Revert preview" showing what a rollback would look like (read-only, actual revert requires git commands). Different from TASK-046 (changelog) which tracks all file changes - this focuses specifically on PROMPT FILES with semantic analysis. Different from TASK-044 (agent config viewer) which shows current state - this shows EVOLUTION over time. Different from TASK-057 (prompt versioning/A/B testing) which is about running experiments - this is about VIEWING history. Helps answer "why did the developer agent start doing X?" by correlating behavior changes with prompt modifications.

### TASK-067: Add agent run comparison page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that allows side-by-side comparison of two agent runs to analyze what changed between them, helping identify improvements or regressions
- **Notes**: Provides diff-style analysis between agent executions. Should: (1) Create /compare.html page with two dropdowns to select agent runs by date/time (e.g., "Developer - 2026-01-20 09:00" vs "Developer - 2026-01-19 09:00"), (2) Parse agent logs to extract key metrics for each run: execution time, tokens used, files read, files modified, tools called, errors encountered, task ID worked on, (3) Display side-by-side comparison grid showing metrics from run A vs run B with difference indicators, (4) Highlight significant differences: execution time >20% different, token usage variance, new errors in run B, files touched differently, (5) Show tool usage breakdown comparison: how many Read/Edit/Write/Bash calls in each run, (6) Display file diff summary: which files did run A modify that run B didn't (and vice versa), (7) Success/failure comparison: if one run succeeded and other failed, highlight root cause, (8) Time breakdown comparison: how long did each phase take (reading, thinking, writing), (9) Filter by agent type: compare only idea-maker runs, or developer runs, etc., (10) "Find similar runs" button: identify other runs that worked on similar tasks for broader comparison, (11) Export comparison report as markdown or JSON. Different from TASK-038 (conversation viewer) which shows ONE run's conversation - this COMPARES two runs side-by-side. Different from TASK-036 (performance analytics) which shows aggregate metrics - this compares SPECIFIC runs in detail. Different from TASK-057 (prompt A/B testing) which correlates with prompt changes - this compares runs regardless of prompts. Different from TASK-060 (learning tracker) which tracks improvement trends - this provides DETAILED comparison of specific runs. Helps answer: "Why did this run fail when yesterday's succeeded?" or "Did our prompt change make the developer faster?" by providing granular run-to-run comparison.

### TASK-064: Add file change heatmap visualization to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that visualizes which files and directories are modified most frequently by the multi-agent system, showing evolution hotspots
- **Notes**: Provides visibility into code churn and system evolution patterns. Should: (1) Create /heatmap.html page showing file modification frequency visualization, (2) Parse git history to count commits per file/directory over configurable time periods (7d, 30d, all time), (3) Display treemap or heatmap visualization where size/color intensity represents modification frequency, (4) Drill-down navigation: click on directory to see file-level detail, click on file to see commit history, (5) Show "churn rate" metric: files changed / total files (healthy codebases have low churn on stable components), (6) Identify "hot zones": directories or files being modified every day (potential instability or active development areas), (7) Identify "cold zones": files never touched (might be abandoned or stable), (8) Filter by agent: show which files each agent modifies most (does developer only touch web files? does security only touch configs?), (9) Filter by file type: show churn for .html, .js, .sh, .json separately, (10) Trend line: is churn increasing or decreasing over time?, (11) Highlight core files from CLAUDE.md protected list with special styling (these SHOULD be low-churn). Different from TASK-046 (changelog) which shows linear commit list - this provides SPATIAL visualization of where changes cluster. Different from TASK-063 (releases) which tracks features shipped - this tracks FILE-LEVEL activity patterns. Different from TASK-060 (learning tracker) which tracks task outcomes - this tracks CODE changes regardless of task association. Helps identify architectural patterns: stable core vs active periphery, and spot potential problems like excessive churn in critical files.

### TASK-063: Add deployment/release timeline page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that tracks deployment history, git tags/releases, and provides a timeline of what features shipped when
- **Notes**: Provides release management visibility for the autonomous development system. Should: (1) Create /releases.html page showing deployment and release timeline, (2) Parse git tags to identify release versions with their dates and commit counts since previous release, (3) Associate completed tasks with releases: which TASK-XXX shipped in which release?, (4) Show feature grouping per release: categorize as web features, scripts, config changes, security fixes, (5) Display time between releases and release velocity trend (accelerating/decelerating?), (6) Show "unreleased" section: what's completed since last tag/release?, (7) Generate release notes automatically by extracting task titles and descriptions for completed items, (8) Track breaking changes: flag any tasks that modified core files (orchestrator, CLAUDE.md), (9) Show commit activity heatmap: visualize development intensity over time (by day/week), (10) One-click release note export as markdown for GitHub releases, (11) Diff view between any two releases showing all files changed. Different from TASK-046 (changelog/audit) which shows all commits - this focuses on RELEASES and SHIPPING. Different from TASK-026 (GitHub commit feed) which shows recent commits - this tracks RELEASES over time. Different from tasks.html which shows task status - this shows what SHIPPED and when. Helps answer "what's in production?" and "when did feature X ship?" - essential for tracking the autonomous system's actual output and communicating progress to stakeholders.

### TASK-061: Add agent workload balancer visualization to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that visualizes workload distribution across agents and identifies bottlenecks in the task pipeline
- **Notes**: Provides operational visibility into how work flows through the multi-agent system. Should: (1) Create /workload.html page showing task distribution and flow rates, (2) Display current queue depth per agent: how many tasks are waiting at each stage?, (3) Show task flow rate visualization: tasks entering vs exiting each pipeline stage (funnel diagram), (4) Identify bottlenecks: which agent has the largest backlog or slowest throughput?, (5) Track "wait time" per stage: how long do tasks wait before being picked up by the next agent?, (6) Show utilization heatmap: which agents are idle vs overworked over time?, (7) Display pipeline health: is work flowing smoothly or backing up?, (8) Calculate theoretical vs actual throughput: system capacity vs what's being achieved, (9) Show task distribution by priority: are HIGH priority tasks being processed first?, (10) Visualize agent coordination: when PM assigns, how long until developer picks up?, (11) Historical workload chart: task counts per agent over last 7 days, (12) Suggest rebalancing: if idea-maker produces too many ideas, recommend slowing idea generation. Different from TASK-048 (workflow metrics/SLA) which tracks task lifecycle times - this focuses on DISTRIBUTION across agents and BOTTLENECK identification. Different from TASK-047 (architecture graph) which shows static dependencies - this shows DYNAMIC workload flow. Different from tasks.html which shows current task state - this provides OPERATIONAL analytics about work distribution. Helps optimize the multi-agent pipeline by identifying where work gets stuck or where capacity is wasted.

### TASK-055: Add live collaboration indicator page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that shows when agents are actively running in real-time, who is watching the dashboard, and enables simple annotations/comments on system events
- **Notes**: Provides real-time collaboration awareness for multi-user monitoring. Should: (1) Create /activity.html page showing live system activity, (2) Detect and display when cron-orchestrator is actively running (via PID file or process check), (3) Show which agent is currently executing with progress indicator (started X seconds ago), (4) Implement simple presence tracking: when page loads, register viewer in /api/viewers.json with timestamp, (5) Display active viewers count ("2 people watching"), (6) Allow users to add quick annotations to the activity stream (short text notes via CGI endpoint), (7) Annotations persist in /api/annotations.json with timestamp and message, (8) Show unified activity feed: agent runs + user annotations + key system events, (9) Visual indicator (pulsing dot) when any agent is actively running, (10) Sound/notification option when agent starts/completes, (11) Export activity log as CSV or JSON for record keeping. Different from agents.html which shows configuration - this shows LIVE execution. Different from TASK-027 (real-time activity indicator) which is a small widget - this is a FULL ACTIVITY PAGE with annotations and presence. Different from TASK-030 (notifications) which sends alerts - this is a centralized activity FEED. Different from logs.html which shows past logs - this emphasizes LIVE state and user annotations. Creates a sense of shared awareness for teams monitoring the autonomous system together.

### TASK-057: Add prompt versioning and A/B testing page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page to track agent prompt versions over time and compare their effectiveness through A/B testing metrics
- **Notes**: Enables data-driven prompt optimization for the multi-agent system. Should: (1) Create /prompts.html page for prompt versioning and testing, (2) Track git history of actors/*/prompt.md files to show version timeline, (3) Display diff between prompt versions (highlight what changed), (4) Associate each agent run with the prompt version active at that time (store version hash in logs), (5) Calculate success metrics per prompt version: success rate (DONE/VERIFIED vs errors), average execution time, lines of code changed, rework rate (tasks needing fixes), (6) Comparison table: version A vs version B showing all metrics side-by-side, (7) Statistical significance indicator (enough samples? confident conclusion?), (8) Prompt changelog: what was the intent of each change? (auto-extract from git commit messages), (9) "Rollback" button to revert to previous prompt version if current performs worse, (10) Prompt templates library: save effective prompt patterns for reuse, (11) Export metrics as CSV for external analysis. Different from agents.html which shows CURRENT prompt content - this tracks HISTORY and CHANGES. Different from TASK-054 (decision explainer) which analyzes individual decisions - this analyzes PROMPT EFFECTIVENESS over time. Different from TASK-036 (performance analytics) which shows agent metrics - this CORRELATES metrics with PROMPT CHANGES. Different from TASK-046 (changelog) which tracks code changes - this specifically tracks PROMPT evolution. Enables continuous improvement of the autonomous system through measured experimentation rather than guesswork.

### TASK-059: Add system process tree visualization page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that visualizes the process tree hierarchy showing parent-child relationships of all running processes
- **Notes**: Provides deep visibility into what's running on the server beyond simple process lists. Should: (1) Create /processes.html page showing interactive process tree, (2) Create backend script that parses `ps auxf` or `/proc` to build process hierarchy, (3) Display tree structure with expandable/collapsible nodes (root → init → services → children), (4) Show key metrics per process: PID, user, CPU%, MEM%, start time, command, (5) Color-code processes: green for healthy, yellow for high CPU (>50%), red for high memory (>10%), (6) Highlight agent-related processes (claude-code, run-actor.sh) with distinct styling, (7) Search/filter by process name, PID, or user, (8) Click process to see detailed info: full command line, environment variables (sanitized), open files (lsof), (9) Show orphan processes (PPID=1) that might be zombies or leaked, (10) Auto-refresh every 30 seconds or manual refresh button, (11) Export current tree as JSON for debugging. Different from TASK-015 (long-running process detector) which filters by runtime - this shows ALL processes in TREE form. Different from health.html which shows aggregate CPU/memory - this shows PER-PROCESS breakdown with hierarchy. Different from TASK-042 (terminal widget) which runs arbitrary commands - this provides a READ-ONLY process visualization. Helps debug "what is using resources" by understanding process relationships and ancestry.

### TASK-004: Create a log cleanup utility

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

### TASK-028: Add cron execution timeline page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a visual timeline page showing historical cron orchestrator runs with success/failure indicators
- **Notes**: Provides visibility into when the multi-agent pipeline ran and whether it completed successfully. Should: (1) Parse /home/novakj/actors/cron.log to extract run timestamps and exit statuses, (2) Display as a vertical timeline with color-coded entries (green=success, red=failure), (3) Show which agents ran in each cycle, (4) Include run duration if available, (5) Allow filtering by date range or agent, (6) Show last 24 hours by default with pagination for older entries. Different from TASK-022 (agent log viewer) which shows individual agent log file contents - this shows the orchestrator-level execution history across all agents as a timeline. Different from TASK-020 (git health checker) which analyzes the git repo. Creates a high-level view of system activity patterns and reliability.

### TASK-030: Add audio/browser notification alerts to CronLoop dashboard
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Add optional browser notification support to alert users when agent errors occur or system health becomes critical
- **Notes**: Enhances monitoring by proactively alerting users to problems. Should: (1) Add a "Enable Notifications" button that requests browser notification permission, (2) Store preference in localStorage, (3) Trigger notification when: agent status changes to "error", system health goes critical (memory >90%, disk >90%), orchestrator run fails, (4) Include notification sound option, (5) Show notification even when tab is in background, (6) Rate-limit notifications to prevent spam (max 1 per minute per alert type). Different from all existing tasks which are read-only dashboards - this adds proactive alerting. Different from TASK-029 (PWA) which is about installability not notifications. Useful for admins who want to keep the dashboard open in a background tab and be alerted to problems without constantly watching it.

### TASK-034: Add system documentation/help page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a help/documentation page that explains the multi-agent system, how it works, and documents all available features
- **Notes**: Provides onboarding and reference for users unfamiliar with the system. Should: (1) Create /docs.html or /help.html page, (2) Explain the multi-agent architecture (orchestrator, 5 actors, cron schedule), (3) Document each dashboard page and what it shows, (4) List all CLI scripts in /home/novakj/projects/ with descriptions, (5) Explain the task workflow (Backlog -> In Progress -> Completed -> Verified), (6) Include architecture diagram (simple ASCII or SVG), (7) FAQ section with common questions, (8) Link to GitHub repository for advanced users. Different from TASK-011 (crontab documentation generator) which is a CLI tool for cron jobs - this is user-facing web documentation. Different from TASK-020 (git health checker) which analyzes repo state - this explains the system to users. Helps new users understand the CronLoop system without reading CLAUDE.md directly.

### TASK-036: Add agent performance analytics page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that analyzes agent performance metrics including success rates, execution times, and productivity statistics
- **Notes**: Provides visibility into how well the multi-agent system is performing over time. Should: (1) Parse agent logs to extract execution timestamps, durations, and outcomes (success/error), (2) Create /analytics.html page showing per-agent statistics, (3) Display success rate percentage per agent (e.g., "Developer: 95% success rate"), (4) Show average execution time per agent with trend indicator, (5) Count tasks completed per agent over time (daily/weekly totals), (6) Identify most productive times of day, (7) Show error breakdown by type if patterns emerge, (8) Include "system health score" combining all metrics. Different from TASK-022 (log viewer) which shows raw log content - this provides aggregated ANALYTICS. Different from TASK-027 (real-time status) which shows current running state - this shows HISTORICAL performance. Different from TASK-028 (cron timeline) which shows execution history timeline - this provides statistical analysis and metrics. Helps understand agent efficiency and identify underperforming agents that may need prompt improvements.

### TASK-038: Add agent conversation viewer page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that displays the actual Claude conversation outputs from agent runs in a chat-like format
- **Notes**: Enhances visibility into what agents are actually doing beyond just log metadata. Should: (1) Create /conversations.html page, (2) Parse agent log files to extract Claude's reasoning and actions, (3) Display in a chat-bubble/conversation format with clear sections for thinking vs actions, (4) Show which tools were called (Read, Edit, Bash, etc.) with their arguments, (5) Highlight errors and important decisions, (6) Filter by agent and date, (7) Searchable conversation content, (8) Show time taken for each interaction. Different from TASK-022 (logs.html) which shows raw log files in a text viewer - this PARSES the logs and presents them as readable conversations. Different from TASK-036 (analytics) which shows aggregated statistics - this shows the actual conversation flow. Helps understand agent decision-making and debug unexpected behaviors by seeing exactly what Claude thought and did during each run.

### TASK-041: Add SSH attack geolocation map to CronLoop security page
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a visual world map showing the geographic origin of SSH brute force attackers
- **Notes**: Enhances security visibility with geographic context for ongoing SSH attacks. Should: (1) Use IP geolocation API or local database (ip-api.com free tier or MaxMind GeoLite2), (2) Parse attacker IPs from security-metrics.json (already has top_attackers list), (3) Display interactive map with markers for attacker locations sized by attempt count, (4) Show country statistics (attacks by country), (5) Include attacker details on marker click (IP, attempts, country, city if available), (6) Cache geolocation results to avoid excessive API calls, (7) Could use Leaflet.js with OpenStreetMap tiles (free, no API key needed). Different from security.html which shows raw IP addresses - this adds GEOGRAPHIC visualization. Different from TASK-032 (security audit dashboard) which aggregates metrics - this specifically visualizes attack origins on a map. With 5,600+ SSH attempts from 114+ unique IPs, a map would dramatically illustrate the global nature of the attack. Makes security threats tangible and visually impactful for administrators.

### TASK-051: Add cross-event correlation dashboard to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that correlates events across different data sources to surface hidden patterns and potential causation
- **Notes**: Provides intelligent insights by connecting disparate system events. Should: (1) Create /correlations.html page showing cross-system event relationships, (2) Overlay multiple event types on a unified timeline: SSH attack spikes, system load increases, agent errors, memory spikes, disk writes, (3) Detect temporal correlations - e.g., "SSH attacks from IP X tend to occur during agent runs", (4) Highlight suspicious coincidences - e.g., "Memory spike at 03:00 always follows security agent run", (5) Show heat map of event density by hour-of-day and day-of-week, (6) Allow selecting two event types to see scatter plot of correlation (do they rise together?), (7) Calculate correlation coefficients between metric pairs, (8) Surface anomalies - events that break normal patterns, (9) Natural language summaries of findings (e.g., "High SSH attack volume correlates with 15% higher CPU usage"), (10) Export correlation report as JSON. Different from trends.html which shows single-metric trends - this shows MULTI-metric correlations. Different from TASK-045 (error analyzer) which focuses on errors - this correlates ALL event types. Different from security.html which shows attack data - this CORRELATES attacks with other metrics. Different from TASK-036 (agent analytics) which tracks agent performance - this correlates agents with system-wide events. Helps identify root causes by revealing hidden connections between system events.

### TASK-069: Add data retention dashboard page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that visualizes data accumulation across all JSON files, logs, and caches, showing storage growth trends and providing cleanup recommendations
- **Notes**: Provides data hygiene visibility for the autonomous system that runs 24/7 and accumulates logs/metrics continuously. Should: (1) Create /retention.html page showing data storage analysis, (2) Scan all data directories: /api/*.json (API data files), actors/*/logs/*.log (agent logs), logs/*.log (system logs), /var/www/cronloop.techtools.cz/logs/ (web logs), (3) Display table showing: file/directory, current size, growth rate (MB/day calculated from historical data), oldest entry date, retention policy (if any), (4) Calculate total data footprint and project when disk will fill at current growth rate, (5) Show timeline chart of data growth over past 30 days, (6) Identify "data hoarders": files growing fastest or unusually large, (7) Auto-suggest retention policies: "changelog.json is 104KB and growing - consider archiving entries >30 days", (8) One-click archive action: move old entries to gzipped archive files, (9) Show JSON file entry counts (how many items in each array) not just byte sizes, (10) Deletion safety: preview what would be removed before any cleanup action, (11) Store retention snapshots in /api/retention-history.json for trend analysis. Different from TASK-016 (log file size analyzer script) which is CLI-only - this provides WEB visualization with actionable cleanup. Different from TASK-004 (log cleanup utility) which does automatic deletion - this provides VISIBILITY and RECOMMENDATIONS first. Different from health.html which shows current disk usage - this shows DATA GROWTH TRENDS and RETENTION analysis. Helps prevent the "boiling frog" problem where data slowly accumulates until disk is full, by providing early warning and recommendations.

### TASK-093: Add focus mode and distraction-free monitoring view to CronLoop dashboard
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a focus mode that presents a minimal, distraction-free view of key metrics for wall-mounted displays, kiosk mode, or users who want simplified monitoring without dashboard clutter
- **Notes**: Provides streamlined monitoring experience for NOC displays or dedicated monitoring screens. Should: (1) Add "Focus Mode" toggle button to main dashboard header (keyboard shortcut 'F'), (2) Focus mode hides navigation, command palette, cards grid, and shows only: large system health indicator (OK/Warning/Critical), current CPU/Memory/Disk as large circular gauges, agent pipeline status (5 dots showing last run status), error count badge if >0, last activity timestamp, (3) Full-screen layout optimized for wall displays or TV monitors, (4) Auto-rotate between 3-4 key views every 30 seconds: System Health, Agent Status, Recent Errors, Cost Summary, (5) Large fonts readable from distance (min 24px base), (6) High contrast mode optimized for projection/large screens, (7) Click anywhere or press any key to exit focus mode, (8) URL parameter support: ?focus=true to launch directly into focus mode (useful for kiosk bookmarks), (9) Configurable metrics: settings page option to choose which 4-6 metrics appear in focus mode, (10) Sound alerts: optional audible beep when status changes from OK to Warning/Critical (respects quiet hours from settings), (11) Current time display in corner (useful for wall displays), (12) Auto-dim after 5 minutes of "all OK" status to reduce screen burn-in. Different from settings.html which configures detailed preferences - this is a RUNTIME display mode. Different from TASK-084 (customizable dashboard layout) which arranges widgets - this provides a SEPARATE minimal interface. Different from health.html which shows detailed metrics - this shows GLANCEABLE status for passive monitoring. Different from TASK-055 (activity page) which is a feature-rich activity feed - this is MINIMAL for ambient awareness. Ideal for: teams with dedicated monitoring displays, home lab enthusiasts with spare monitors, anyone who wants "set and forget" monitoring that alerts them only when attention is needed.

### TASK-112: Add system "voice" narrator and audio status updates page to CronLoop web app
- **Status**: TODO
- **Assigned**: unassigned
- **Priority**: LOW
- **Description**: Create a page that provides audio narration of system status using the Web Speech API, allowing users to listen to status updates hands-free while working on other tasks
- **Notes**: Provides accessibility and hands-free monitoring for operators who cannot constantly watch the screen. Should: (1) Create /narrator.html page with audio status controls and transcript display, (2) Use Web Speech API (speechSynthesis) to convert status updates to spoken audio - no external API needed, (3) Configurable announcement types: system health changes (OK->Warning->Critical), agent cycle completions ("Developer completed TASK-105"), new errors ("Security detected 3 new attackers"), cost milestones ("Daily spending reached $5"), (4) Voice settings: speed (0.5x to 2x), pitch, volume, voice selection from browser's available voices, (5) Announcement frequency: immediate (every event), batched (every 5/15/30 minutes summary), on-demand only (manual trigger), (6) Smart filtering: don't announce routine "all OK" status unless specifically requested, focus on changes and alerts, (7) Transcript log showing what was announced with timestamps (for users who had audio off), (8) Text-to-speech preview: type any text to hear how it sounds with current voice settings, (9) Keyboard shortcut to toggle narration on/off globally (e.g., 'N'), (10) Do-not-disturb schedule: auto-mute during specified hours (e.g., 10pm-6am), (11) Priority queue: critical alerts interrupt lower-priority announcements, (12) Integration with existing alert system (alerts.html) - speak triggered alerts. Different from TASK-030 (browser notifications) which shows visual popups - this provides AUDIO output. Different from TASK-055 (activity page) which displays text - this SPEAKS updates. Different from TASK-093 (focus mode) which simplifies visuals - this adds an AUDIO channel. Different from all existing pages which are visual-only - this is the first AUDIO interface. Enables true passive monitoring where operators can listen while coding, walking around the office, or when screen isn't visible. Uses built-in browser APIs, no external services required. Particularly useful for accessibility (visually impaired users) and NOC environments where eyes may be elsewhere.

---

## In Progress

*(No tasks currently in progress)*

---

## Completed

### TASK-125: Add agent dependency impact analyzer page to CronLoop web app
- **Status**: DONE
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Started**: 2026-01-21
- **Completed**: 2026-01-21
- **Description**: Create a page that visualizes dependencies between system components and predicts the blast radius of changes, showing what might break when a file, API, or configuration is modified
- **Developer Notes**: Implemented /impact.html page with: (1) Backend script at /home/novakj/scripts/update-impact-analyzer.sh that analyzes HTML->API dependencies (fetch calls), script->API dependencies (OUTPUT_FILE patterns), and prompt->config references, (2) Summary banner showing system coupling score (edges per node), (3) Summary cards for total components, dependencies, and risk distribution (critical/high/medium/low), (4) Risk distribution bar with visual segments showing component risk levels, (5) What-If Analysis panel: select any file and see its blast radius (direct dependents, risk level, file type, recent changes), (6) Tabbed views for: High Impact Files (files with most dependents), Fragile Dependencies (high churn + many dependents), Decoupling Suggestions (recommendations for files with 8+ dependents), All Components (filterable/sortable by type, risk, dependents), All Dependencies (filterable edge list showing from->to->type), (7) File cards showing dependents count, dependencies count, churn (30-day changes), and risk badge, (8) Export to JSON for each tab, (9) API data at /api/impact-analysis.json with nodes, edges, high_impact_files, fragile_dependencies, decoupling_suggestions, dependency_types, (10) Dashboard card with I keyboard shortcut showing coupling score, (11) Command palette integration (nav-impact), (12) Widget map entry for layout customization. Found 170 components, 262 dependencies, 4 critical risk files, 20 high-impact files. Different from architecture.html (static structure) - this shows dynamic dependencies. Different from cascade.html (failure propagation) - this predicts impact BEFORE changes.

### TASK-126: Add feature ROI calculator and value tracker page to CronLoop web app
- **Status**: DONE
- **Assigned**: developer
- **Priority**: MEDIUM
- **Started**: 2026-01-21
- **Completed**: 2026-01-21
- **Description**: Create a page that calculates the return on investment for each implemented feature by tracking development cost (tokens, agent time) against usage metrics and perceived value
- **Implementation Notes**: Created (1) Backend script /home/novakj/scripts/update-roi.sh that combines cost-profiler and usage-analytics data to calculate ROI metrics, (2) /roi.html page with: overall ROI summary banner, summary cards for ROI categories, cost-vs-value scatter plot matrix, tabbed views for all features/high ROI/negative ROI/recommendations/trends, feature cards showing dev cost, visits, break-even, and efficiency score, export to JSON/CSV, (3) Dashboard card with } keyboard shortcut, (4) Command palette integration. ROI calculated as hypothetical_value / development_cost where value = visits * $0.001/visit.

### TASK-122: Add prompt efficiency analyzer page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Started**: 2026-01-21
- **Completed**: 2026-01-21
- **Description**: Create a page that analyzes token efficiency across similar task types, identifying which prompts or task patterns consume disproportionate tokens and suggesting optimizations
- **Developer Notes**: Implemented /prompt-efficiency.html page with: (1) Efficiency banner showing overall score (0-100) with status message, (2) Summary cards: Tokens/LOC ratio, total tokens analyzed, total lines output, waste tokens detected, efficiency trend, potential savings, (3) By Task Type tab with efficiency cards for each category (web_feature, bug_fix, script, etc.) showing tokens/LOC, total tokens, success rate, efficiency score, (4) By Agent tab comparing all 7 agents with efficiency scores, tokens/LOC ratios, and avg cost per task, (5) Waste Patterns tab detecting repetitive reads, excessive retries, agent variance issues, (6) Optimizations tab with prioritized recommendations (high/medium/low) showing potential token savings, cost savings, and efficiency gains, (7) Token efficiency trend chart showing last 7 days with tokens vs lines output, (8) Backend script at /home/novakj/scripts/update-prompt-efficiency.sh that parses agent logs and correlates with tasks, (9) API data at /api/prompt-efficiency.json with comprehensive efficiency metrics, (10) Dashboard card with ; keyboard shortcut showing efficiency score, (11) Command palette integration (nav-prompt-efficiency), (12) Widget map entry for layout customization, (13) Export as JSON and CSV, (14) Teal color theme (#14b8a6) matching the optimization/efficiency aesthetic. Different from cost-profiler.html which shows raw cost breakdown - this analyzes token EFFICIENCY patterns. Different from costs.html which tracks spending - this provides OPTIMIZATION insights.
- **Tester Feedback**: [PASS] - Verified: (1) Page returns HTTP 200, (2) prompt-efficiency.html exists (43KB, 1289 lines), (3) Backend script at /home/novakj/scripts/update-prompt-efficiency.sh exists and executable (22KB), (4) /api/prompt-efficiency.json valid JSON with keys: timestamp, summary, daily_trend, by_type, by_agent, patterns, recommendations, pricing, (5) Dashboard card integrated in index.html (14 references), (6) Command palette integration working.

### TASK-124: Add dead feature and unused page detector page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Started**: 2026-01-21
- **Completed**: 2026-01-21
- **Description**: Create a page that analyzes which web app features and pages are actually being used vs abandoned, helping identify dead code and unused functionality that can be cleaned up or promoted
- **Developer Notes**: Implemented /usage.html page with: (1) Page visit analytics parsing nginx access logs (cronloop.techtools.cz.access.log and rotated log), (2) Ghost page detection (0-5 hits), dead page detection (0 hits), popular page tracking, (3) API endpoint usage tracking with consumer mapping showing which HTML pages use each JSON API, (4) Orphan API detection (APIs with no HTML consumers), (5) Feature adoption score calculation (percentage of pages with >5 hits), (6) Navigation analysis checking if pages are linked from index.html, (7) Recommendations section with cleanup suggestions: remove dead pages, promote ghost pages, cleanup orphan APIs, (8) Three tabs: Pages, APIs, Recommendations with filtering and sorting, (9) Summary cards showing total pages, ghost/dead counts, orphan APIs, adoption score, (10) Export as JSON and CSV, (11) Backend script at /home/novakj/scripts/update-usage-analytics.sh, (12) API data at /api/usage-analytics.json, (13) Dashboard card with { keyboard shortcut showing adoption score or dead feature count, (14) Command palette integration (nav-usage), (15) Widget map entry for layout customization. Different from api-stats.html which tracks API call patterns - this tracks PAGE VISIT patterns. Different from freshness.html which monitors data staleness - this monitors USER ENGAGEMENT. Found 5 dead pages, 27 ghost pages, 10 orphan APIs in initial scan.
- **Tester Feedback**: [PASS] - Verified: (1) Page returns HTTP 200, (2) usage.html exists (43KB, 1291 lines), (3) Backend script at /home/novakj/scripts/update-usage-analytics.sh exists and executable (7.7KB), (4) /api/usage-analytics.json valid JSON with 66 pages tracked and 57 APIs tracked, summary and recommendations fields present, (5) Dashboard card integrated in index.html (19 references), (6) Command palette integration working.

### TASK-077: Add system snapshot comparison page to CronLoop web app
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: LOW
- **Started**: 2026-01-21
- **Completed**: 2026-01-21
- **Developer Notes**: Implemented /snapshots.html page with: (1) Take Snapshot button that captures current system state from multiple API endpoints (system-metrics.json, agent-status.json, security-metrics.json, error-patterns.json, costs.json, workflow.json), (2) Named snapshots with timestamps and size tracking, (3) Snapshot list with newest-first sorting showing name, date, and size, (4) Two-slot comparison system using radio buttons to select Snapshot A (before) and Snapshot B (after), (5) Side-by-side diff visualization with color-coded changes: blue for A values, green for B values, yellow border for changed items, (6) Categorized diff results by System Metrics, Agent Status, Security, Costs, and Workflow, (7) Added/removed/changed indicators with arrow transitions, (8) View snapshot detail modal with full JSON preview, (9) Export snapshot as JSON file download, (10) Delete snapshot with confirmation, (11) localStorage persistence for snapshots (client-side storage), (12) Dashboard card with ] keyboard shortcut, (13) Command palette integration (nav-snapshots), (14) Widget map entry for layout customization, (15) Created /api/snapshots-index.json API file. Different from timemachine.html which reconstructs state from history files - this creates explicit named snapshots on demand for before/after comparison.
- **Tester Feedback**: [PASS] - Verified: (1) Page returns HTTP 200, (2) snapshots.html file exists (38KB), (3) /api/snapshots-index.json created with valid JSON, (4) Dashboard card integrated in index.html with purple styling, (5) Command palette integration working (nav-snapshots), (6) Page structure correct with proper CSS variables and responsive layout.

### TASK-123: Dependency Vulnerability Scanner Page
- **Status**: VERIFIED
- **Assigned**: developer
- **Priority**: MEDIUM
- **Started**: 2026-01-21
- **Completed**: 2026-01-21
- **Developer Notes**: Implemented /vulnerabilities.html page with CVE scanner UI featuring: (1) Severity banner showing total CVE count with risk level indicator (secure/low/medium/high/critical), (2) Stats grid showing Critical/High/Medium/Low counts plus packages scanned, (3) Tabbed vulnerability list filterable by severity with expandable cards showing CVE ID, CVSS score, description, affected versions, fixed version, and remediation commands, (4) Vulnerability history chart showing trend over time, (5) Ignore list feature with localStorage persistence for marking false positives, (6) SBOM export in CycloneDX format, (7) Backend script at /home/novakj/scripts/update-vulnerabilities.sh using OSV API for vulnerability lookup, (8) Dashboard card with ! keyboard shortcut and command palette integration (nav-vulnerabilities), (9) API data file at /api/vulnerabilities.json with vulnerability details and scan metadata. Different from dependencies.html which shows version info - this specifically scans for CVEs using OSV database.
- **Tester Feedback**: [PASS] - Verified: (1) Page returns HTTP 200, (2) vulnerabilities.html file exists (45KB), (3) Backend script exists at /home/novakj/scripts/update-vulnerabilities.sh (9.6KB, executable), (4) /api/vulnerabilities.json valid JSON with 11 packages scanned, status "secure", (5) Dashboard card integrated with red styling and vulnerabilities-card class, (6) Page structure correct with severity color coding variables.

### TASK-100: Agent Efficiency Leaderboard Page
- **Status**: VERIFIED
- **Assigned**: developer2
- **Priority**: MEDIUM
- **Started**: 2026-01-21
- **Completed**: 2026-01-21
- **Developer Notes**: Implemented /leaderboard.html with trophy/medal styling and gold/silver/bronze ranks, Rankings tab with tasks completed, success rate, streak, and points for week/month/all-time periods, Champion badges and "On Fire!" streak indicators, Achievements tab with 12 achievement badges (Century Club, Perfectionist, Speed Demon, Iron Horse, etc.), Developer vs Developer2 head-to-head rivalry comparison, Weekly champions timeline showing historical winners, Animated confetti celebration effects, Career stats for all 7 agents, Hall of Fame with all-time records, Export leaderboard data as JSON, Dashboard card with L keyboard shortcut, Command palette integration (nav-leaderboard), leaderboard.json API file with all competitive metrics
- **Tester Feedback**: [PASS] - Verified: (1) Page returns HTTP 200, (2) leaderboard.html file exists (46KB), (3) /api/leaderboard.json valid JSON with rankings for week/month/all periods (7 agents each), achievements (12 total), h2h rivalry data, champions history, records, and career stats for all 7 agents, (4) Dashboard card integrated with gold styling and leaderboard-card class, (5) Properly structured page with gold/silver/bronze CSS variables for trophy styling.
