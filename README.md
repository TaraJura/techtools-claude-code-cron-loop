# PDF Editor — AI-Built Web Application

> **This entire project is built autonomously by Claude Code (AI) with full sudo permissions.**
> 7 AI agents collaborate every 2 hours to design, implement, test, and secure a browser-based PDF editor.
> No human intervention required. The factory builds the product.

---

## What Is This?

An **autonomous AI factory** that builds a professional PDF editor web application:

| Aspect | Description |
|--------|-------------|
| **Product** | Browser-based PDF Editor at https://cronloop.techtools.cz |
| **Engine** | Claude Code (Anthropic's AI CLI tool) |
| **Execution** | 7 agents run every 2 hours via crontab |
| **Permissions** | Full sudo access to the server |
| **Stack** | HTML/CSS/JS + pdf.js + pdf-lib + Tesseract.js |
| **Source** | https://github.com/TaraJura/techtools-claude-code-cron-loop |

**Live App**: [https://cronloop.techtools.cz](https://cronloop.techtools.cz)

---

## PDF Editor Features (Planned)

| Feature | Status | Description |
|---------|--------|-------------|
| PDF Viewer | TODO | View and navigate PDFs with zoom, thumbnails |
| File Upload/Download | TODO | Drag-and-drop upload, save modified PDFs |
| Annotations | TODO | Highlight, underline, strikethrough, comments |
| Merge PDFs | TODO | Combine multiple PDFs into one |
| Split PDF | TODO | Extract page ranges into separate files |
| Page Management | TODO | Reorder, rotate, delete pages |
| OCR | TODO | Extract text from scanned PDFs |
| Form Filling | TODO | Fill interactive PDF form fields |
| Digital Signatures | TODO | Draw/type/upload signatures |
| Text Editing | TODO | Add text overlays to PDF pages |
| Watermarks | TODO | Add text/image watermarks |
| Redaction | TODO | Permanently remove sensitive content |
| Batch Processing | TODO | Apply operations to multiple files |
| Bookmarks | TODO | Navigate and manage PDF bookmarks |

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                    MAIN PIPELINE (Every 2 hours)                      │
│                                                                       │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐         │
│  │IDEA MAKER │─▶│    PM     │─▶│ DEVELOPER │─▶│DEVELOPER 2│         │
│  │           │  │           │  │           │  │           │         │
│  │ Generate  │  │ Assign    │  │ Build PDF │  │ Build PDF │         │
│  │ feature   │  │ tasks     │  │ editor    │  │ editor    │         │
│  │ ideas     │  │           │  │ features  │  │ features  │         │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘         │
│                                      │              │                 │
│                                      ▼              ▼                 │
│                           ┌────────────────────────────────┐         │
│                           │  /var/www/cronloop.techtools.cz │         │
│                           │  PDF Editor Web Application     │         │
│                           └────────────────┬───────────────┘         │
│                                            │                          │
│  ┌───────────┐  ┌───────────┐             │                          │
│  │ SECURITY  │◀─│  TESTER   │◀────────────┘                          │
│  │           │  │           │                                         │
│  │ Review    │  │ Verify    │                                         │
│  │ file      │  │ PDF ops   │                                         │
│  │ handling  │  │ work      │                                         │
│  └───────────┘  └───────────┘                                         │
│       │               │                                               │
│       └───────────────┴──────────▶ tasks.md ──▶ GitHub                │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                    SUPERVISOR (Every 2 hours at :15)                   │
│                                                                       │
│                ┌─────────────────────────────────┐                    │
│                │          SUPERVISOR              │                    │
│                │                                  │                    │
│                │  • Monitors all agents            │                    │
│                │  • Checks system health           │                    │
│                │  • Tracks project progress         │                    │
│                │  • Fixes issues conservatively     │                    │
│                └─────────────────────────────────┘                    │
└──────────────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **PDF Rendering** | pdf.js (Mozilla) | Render PDF pages in the browser |
| **PDF Manipulation** | pdf-lib | Merge, split, modify PDFs |
| **OCR** | Tesseract.js | Extract text from scanned PDFs |
| **Frontend** | HTML/CSS/JavaScript | User interface |
| **Web Server** | Nginx 1.26.3 + SSL | Serve the application |
| **AI Engine** | Claude Code | Autonomous development |
| **Scheduling** | Cron | Run agents every 2 hours |
| **Version Control** | Git + GitHub | Track all changes |

## Agents

### Main Pipeline (Every 2 hours)

| Agent | Role | Description |
|-------|------|-------------|
| **idea-maker** | Ideation | Generates PDF editor feature ideas |
| **project-manager** | Planning | Assigns and prioritizes tasks |
| **developer** | Implementation | Builds PDF editor features |
| **developer2** | Implementation | Builds features in parallel |
| **tester** | QA | Loads the live site in headless Chrome via the `chrome-devtools` MCP, fails the run on any app-origin console error, and uploads an example PDF on every cycle to verify the upload pipeline |
| **security** | Security | Reviews file upload security, XSS prevention |

### Supervisor (Every 2 hours at :15)

| Agent | Role | Description |
|-------|------|-------------|
| **supervisor** | Overseer | Monitors ecosystem health and project progress |

Each agent has a prompt file at `actors/<agent>/prompt.md` defining its behavior.

## Task Lifecycle

```
┌──────────┐    ┌─────────────┐    ┌──────────┐    ┌──────────────┐    ┌──────────┐
│   TODO   │───▶│ IN_PROGRESS │───▶│   DONE   │───▶│   VERIFIED   │───▶│ ARCHIVED │
│          │    │             │    │          │    │              │    │          │
│ PM sets  │    │ Developer   │    │Developer │    │ Tester       │    │ Auto     │
│          │    │ starts      │    │completes │    │ approves     │    │ archive  │
└──────────┘    └─────────────┘    └──────────┘    └──────────────┘    └──────────┘
                                        │
                                        ▼ (if issues)
                                 ┌──────────┐
                                 │  FAILED  │ ──▶ Back to TODO
                                 └──────────┘
```

## Project Structure

```
/home/novakj/
├── CLAUDE.md              # Core system rules
├── README.md              # This file
├── tasks.md               # Task board
├── docs/                  # Documentation
│   ├── autonomous-system.md  # How the AI factory works
│   ├── server-config.md      # Server specs and paths
│   ├── security-guide.md     # PDF security guidelines
│   └── engine-guide.md       # Self-healing and recovery
├── status/                # System state (overwritten each cycle)
│   ├── system.json
│   ├── security.json
│   └── task-counter.txt
├── logs/                  # Execution logs
│   ├── changelog.md
│   └── tasks-archive/
├── actors/                # Agent configurations
│   ├── idea-maker/prompt.md
│   ├── project-manager/prompt.md
│   ├── developer/prompt.md
│   ├── developer2/prompt.md
│   ├── tester/prompt.md
│   ├── security/prompt.md
│   └── supervisor/prompt.md
├── scripts/               # Orchestration scripts
│   ├── cron-orchestrator.sh
│   ├── run-actor.sh
│   ├── run-supervisor.sh
│   ├── maintenance.sh
│   ├── cleanup.sh
│   └── health-check.sh
│
/var/www/cronloop.techtools.cz/  # PDF Editor web app
├── index.html
├── css/
├── js/
├── lib/                   # pdf.js, pdf-lib, Tesseract.js
└── assets/
```

## Scheduled Tasks (Cron)

| Schedule | Script | Description |
|----------|--------|-------------|
| `0 */2 * * *` | `cron-orchestrator.sh` | Run 6 agents sequentially |
| `15 */2 * * *` | `run-supervisor.sh` | Run supervisor agent |
| `0 * * * *` | `maintenance.sh` | Hourly health checks |
| `0 3 * * *` | `cleanup.sh` | Daily log cleanup |

## Server Specs

| Resource | Value |
|----------|-------|
| **OS** | Ubuntu 25.04 |
| **CPU** | 4 cores |
| **RAM** | 7.6 GB |
| **Disk** | 72 GB |
| **Web Server** | Nginx 1.26.3 + Let's Encrypt SSL |

## Security

- File upload validation (magic bytes, MIME type, size limits)
- XSS prevention (no innerHTML with user content)
- Content-Security-Policy headers
- Nginx blocks sensitive paths (`.git`, `.env`, `*.sh`, `*.md`)
- No server-side storage of user PDFs
- Client-side processing only

## Quick Commands

```bash
# Run all agents manually
./scripts/cron-orchestrator.sh

# Run a specific agent
./scripts/run-actor.sh developer

# Check system health
./scripts/health-check.sh

# View recent commits
git log --oneline -10

# Check cron jobs
crontab -l
```

## Self-Improvement

The system learns from mistakes:
1. Tester catches bugs → marks task FAILED with feedback
2. Developer reads feedback → fixes the issue
3. Agent prompts get updated → same mistake never happens again
4. System gets permanently smarter over time

---

*Built autonomously by Claude Code — an AI software factory*
*Project started March 2026*
