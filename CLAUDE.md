# CLAUDE.md - System Instructions

> **This is the core instruction file.** Keep it lean. Details are in `docs/`.

## SYSTEM IDENTITY: AI-Powered PDF Editor Factory

> **This entire server is autonomously maintained by Claude Code with FULL SUDO PERMISSIONS.**

| Aspect | Description |
|--------|-------------|
| **Engine** | Claude Code (Anthropic's AI CLI tool) |
| **Execution** | Runs every 2 hours via crontab |
| **Permissions** | Full sudo access - can do anything on this server |
| **Agents** | 7 specialized AI agents collaborate on tasks |
| **Goal** | Build a professional PDF Editor web application autonomously |
| **Live App** | https://cronloop.techtools.cz |

Everything here - code, configs, documentation, web app - is created and maintained by AI.
No human intervention required. **The machine builds the product.**

For detailed information about the autonomous architecture, see `docs/autonomous-system.md`.

## Project: PDF Editor Web Application

### What We're Building

A full-featured, browser-based PDF editor at https://cronloop.techtools.cz with:

| Feature | Description |
|---------|-------------|
| **PDF Viewer** | Render and navigate PDFs using pdf.js |
| **Annotations** | Highlight, underline, strikethrough, comments, sticky notes |
| **Merge/Split** | Combine multiple PDFs or extract page ranges |
| **Page Management** | Reorder, rotate, delete, insert pages |
| **Form Filling** | Detect and fill PDF form fields |
| **Digital Signatures** | Draw or upload signatures, place on documents |
| **Text Editing** | Add/modify text overlays on PDF pages |
| **OCR** | Extract text from scanned PDFs using Tesseract.js |
| **Conversion** | PDF to/from images, export to other formats |
| **Batch Processing** | Apply operations to multiple files |
| **Templates** | Pre-built document templates |
| **Watermarks** | Add text/image watermarks |
| **Redaction** | Permanently remove sensitive content |
| **Bookmarks** | Navigate and manage PDF bookmarks |

### Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **PDF Rendering** | pdf.js (Mozilla) | View and render PDF pages in browser |
| **PDF Manipulation** | pdf-lib | Merge, split, modify PDF structure |
| **OCR** | Tesseract.js | Optical character recognition |
| **Frontend** | HTML/CSS/JavaScript | UI components and interactions |
| **Build System** | Vite or esbuild (TBD) | Bundle and optimize frontend |
| **Backend** | Node.js (if needed) | Heavy processing, file management |
| **Web Server** | Nginx | Serve the application, handle SSL |
| **Hosting** | Ubuntu 25.04 VPS | cronloop.techtools.cz |

### Web Application Structure

```
/var/www/cronloop.techtools.cz/
├── index.html          # Main application entry point
├── css/                # Stylesheets
├── js/                 # JavaScript modules
│   ├── app.js          # Main application
│   ├── viewer.js       # PDF viewer (pdf.js integration)
│   ├── annotate.js     # Annotation tools
│   ├── merge.js        # Merge/split functionality
│   ├── forms.js        # Form filling
│   ├── signatures.js   # Digital signatures
│   ├── ocr.js          # OCR integration
│   └── convert.js      # Format conversion
├── lib/                # Third-party libraries (pdf.js, pdf-lib, Tesseract.js)
├── assets/             # Icons, images, fonts
├── templates/          # Document templates
└── uploads/            # Temporary file storage (gitignored)
```

## Critical Rules

1. **PRIMARY FOCUS**: Build the PDF Editor web app at `/var/www/cronloop.techtools.cz`
2. **WEB INTEGRATION**: Every feature must work in the browser - no desktop dependencies
3. **STABILITY FIRST**: Never break core files (this file, tasks.md, orchestrator scripts)
4. **DOCUMENT CHANGES**: Log significant changes to `logs/changelog.md`
5. **SELF-IMPROVEMENT**: Learn from every mistake - update instructions to prevent repeating errors
6. **VERIFY EVERYWHERE** (MOST IMPORTANT): When making ANY system change:
   - Update ALL affected files (prompts, docs, scripts, configs)
   - Verify the change works by actually testing it
   - If a change affects multiple agents, update ALL agent prompts
   - Never assume a change is complete until tested end-to-end
7. **KEEP README.md UPDATED** (MANDATORY): When changing the ecosystem:
   - Update `README.md` Architecture diagram if agents/flow changes
   - Update `README.md` feature list if capabilities change
   - Update `README.md` tech stack if dependencies change
   - **README.md is the public face of this project - it must always be accurate!**
8. **SECURITY**: File uploads are dangerous - validate everything, limit sizes, check MIME types
9. **CLIENT-SIDE FIRST**: Process PDFs in the browser when possible to avoid server load
10. **NO DATA PERSISTENCE**: PDFs are processed in-memory or temp storage - never store user files permanently

## System Change Verification Protocol (MANDATORY)

> **This system must be bulletproof and long-term maintainable. Every change must be verified across the entire system.**

When introducing ANY change to the system:

### 1. Identify All Affected Components
```
Ask yourself:
- Which agent prompts need updating?
- Which documentation files reference this?
- Which scripts use this functionality?
- Which web app components are affected?
- Does the README need updating?
```

### 2. Update Everything
- [ ] `CLAUDE.md` - Core rules
- [ ] `actors/*/prompt.md` - All 7 agent prompts that are affected
- [ ] `docs/*.md` - Relevant documentation
- [ ] `README.md` - **CRITICAL**: Architecture diagram, feature list, tech stack
- [ ] Scripts that implement the change
- [ ] Web app code that uses the change

### 3. Test the Change
```bash
# Actually test the affected functionality
# Open the web app and verify features work
# Don't just assume it works - VERIFY IT
```

### 4. Verification Checklist
Before considering any system change complete:
- [ ] All agent prompts updated and consistent
- [ ] Documentation matches implementation
- [ ] **README.md is accurate**
- [ ] Web app features work in the browser
- [ ] No broken references or outdated information
- [ ] Change logged to changelog.md

> **A change that isn't verified everywhere is a bug waiting to happen.**

## Self-Improvement Protocol (CRITICAL)

> **This system MUST improve itself over time.**

### The Core Principle

When ANY agent encounters an error, bug, failure, or suboptimal outcome:

1. **Identify the root cause** - What went wrong and why?
2. **Fix the immediate issue** - Resolve the current problem
3. **Update instructions** - Modify the relevant files to prevent recurrence:
   - `CLAUDE.md` - For system-wide rules
   - `actors/<agent>/prompt.md` - For agent-specific behavior
   - `docs/*.md` - For detailed procedures
4. **Log the learning** - Document what was learned in `logs/changelog.md`

### What Triggers Self-Improvement

| Trigger | Action |
|---------|--------|
| Task marked FAILED by tester | Developer updates own prompt with lesson learned |
| Security vulnerability found | Security agent adds rule to `security-guide.md` |
| Same error occurs twice | Add explicit prevention rule to relevant prompt |
| Agent produces duplicate work | Strengthen deduplication checks in prompt |
| PDF processing failure | Document the edge case and add handling |
| Browser compatibility issue | Add cross-browser testing rule |
| Performance degradation | Add optimization rules |
| Any repeated mistake | **MANDATORY** instruction update |

> **Every mistake is an opportunity to make the system permanently smarter.**

## Documentation Architecture

```
/home/novakj/
├── CLAUDE.md              <- YOU ARE HERE (core rules only)
├── tasks.md               <- Active tasks only (TODO, IN_PROGRESS, DONE, FAILED)
├── docs/
│   ├── autonomous-system.md <- Autonomous AI ecosystem explanation
│   ├── server-config.md   <- Static server info, paths, software
│   ├── security-guide.md  <- Security rules (file upload, XSS, PDF bombs)
│   └── engine-guide.md    <- Self-healing protocols, recovery
├── status/
│   ├── system.json        <- Current system status (OVERWRITE, don't append)
│   ├── security.json      <- Current security state (OVERWRITE, don't append)
│   └── task-counter.txt   <- Next task ID number
└── logs/
    ├── changelog.md       <- Recent changes (last 7 days)
    ├── archive/           <- Monthly changelog archives
    └── tasks-archive/     <- Archived VERIFIED tasks (by month)
```

## Task Management

Tasks are archived to keep `tasks.md` lean and fast to read:

- **Active tasks** stay in `tasks.md` (TODO, IN_PROGRESS, DONE, FAILED)
- **Completed tasks** (VERIFIED) are auto-archived to `logs/tasks-archive/tasks-YYYY-MM.md`
- **Task IDs** are tracked in `status/task-counter.txt` - increment before creating new tasks
- **Archiving** runs automatically via `maintenance.sh` when tasks.md exceeds 100KB

## How to Use This Architecture

### Reading Documentation
- **Start here** (CLAUDE.md) for core rules
- **Read `docs/server-config.md`** for server details, paths, installed software
- **Read `docs/security-guide.md`** for security rules (especially file upload security)
- **Read `docs/engine-guide.md`** for recovery procedures and self-healing

### Updating Status (IMPORTANT)
Status files are **OVERWRITTEN**, not appended:
```bash
# CORRECT: Overwrite the entire file with current state
echo '{"status": "ok", "timestamp": "..."}' > status/system.json

# WRONG: Do NOT append
echo '{"status": "ok"}' >> status/system.json  # NO!
```

### Logging Changes
Log to `logs/changelog.md` ONLY for:
- New PDF editor features implemented
- Bug fixes
- Security incidents (not routine checks)
- Infrastructure changes
- Significant events

**DO NOT log:**
- "All checks passed" messages
- Routine status updates (use status/*.json)
- Repetitive information

## Actor Quick Reference

### Main Pipeline (Every 2 hours)
| Actor | Role | Runs |
|-------|------|------|
| idea-maker | Generate PDF editor feature ideas | 1st |
| project-manager | Assign and prioritize tasks | 2nd |
| developer | Implement PDF editor features | 3rd |
| developer2 | Implement features (parallel) | 4th |
| tester | Verify PDF operations work in a real headless browser via `chrome-devtools` MCP (homepage smoke test + console-error check + example.pdf upload) | 5th |
| security | Security review (file uploads, XSS) | 6th (last) |

### Supervisor (Every 2 hours at :15)
| Actor | Role | Runs |
|-------|------|------|
| supervisor | Ecosystem overseer | Separate schedule |

The **supervisor** is a meta-agent that:
- Monitors all other agents and system health
- Maintains persistent todo list across runs
- Fixes issues but prioritizes stability over changes
- Runs independently from the main pipeline

## Core Protected Files

Never delete or corrupt these:
- `/home/novakj/CLAUDE.md`
- `/home/novakj/tasks.md`
- `/home/novakj/scripts/cron-orchestrator.sh`
- `/home/novakj/scripts/run-actor.sh`
- `/home/novakj/actors/*/prompt.md`

**Recovery**: `git checkout HEAD -- <file>`

## Quick Health Check

```bash
# Check core files exist
ls -la CLAUDE.md tasks.md scripts/*.sh

# Check disk space
df -h / | awk 'NR==2 {print $5}'

# Check cron
systemctl is-active cron

# Check git
git status

# Check web app is serving
curl -s -o /dev/null -w "%{http_code}" https://cronloop.techtools.cz/
```

## Decision Tree

```
START
  |
  +-- Disk >80%? --> Run cleanup first
  +-- Core files missing? --> Restore from git, STOP
  +-- tasks.md corrupt? --> Restore from git
  +-- Emergency in logs? --> Fix it first
  |
  +-- Normal operation:
      - idea-maker: 1 PDF editor feature idea (if backlog <30)
      - PM: assign 1 task (to developer or developer2)
      - developer: complete 1 task (assigned to developer)
      - developer2: complete 1 task (assigned to developer2)
      - tester: verify 1 task (test PDF operations in browser)
      - security: update status/security.json, review file handling
```

## Web Application

- **URL**: https://cronloop.techtools.cz
- **Root**: `/var/www/cronloop.techtools.cz`
- **Stack**: HTML/CSS/JS + pdf.js + pdf-lib + Tesseract.js + Nginx + SSL

## GitHub

https://github.com/TaraJura/techtools-claude-code-cron-loop

---

*For detailed documentation, see the `docs/` directory.*
