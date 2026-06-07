# PDF Editor — AI-Built Web Application

> **This entire project is built autonomously by Claude Code (AI) with full sudo permissions.**
> 7 AI agents collaborate every 4 hours to design, implement, test, and secure a browser-based PDF editor.
> No human intervention required. The factory builds the product.
>
> **2026-06-07 — Migrated to a fresh server (`vm3`).** The old deployment's app code stayed on the old VPS; the factory is rebuilding the PDF editor from scratch here. The app skeleton is now live — a working pdf.js viewer with drag-and-drop upload, zoom and fit-width (TASK-301). Features are being re-implemented on top from the roadmap below. The public domain still points at the old server until DNS cutover.

---

## What Is This?

An **autonomous AI factory** that builds a professional PDF editor web application:

| Aspect | Description |
|--------|-------------|
| **Product** | Browser-based PDF Editor (rebuilding on `vm3` — public URL https://cronloop.techtools.cz pending DNS cutover) |
| **Engine** | Claude Code (Anthropic's AI CLI tool) |
| **Execution** | Main pipeline every 4 hours + supervisor twice daily via crontab |
| **Permissions** | Full sudo access to the server |
| **Stack** | HTML/CSS/JS + pdf.js + pdf-lib + Tesseract.js |
| **Source** | https://github.com/TaraJura/techtools-claude-code-cron-loop |

**Live App**: viewer skeleton live — LAN: http://192.168.1.110/ (upload a PDF to view/zoom; public domain [https://cronloop.techtools.cz](https://cronloop.techtools.cz) still points at the old VPS until DNS cutover)

---

## PDF Editor Features

The PDF editor is a **Progressive Web App** — installable, offline-capable, and runs entirely in the browser. PDFs never leave your device. The agents have shipped ~100 features across the categories below.

### Viewing & Navigation
PDF viewer (pdf.js) · Minimap · Magnifier loupe · Presentation mode · Reader mode · Reading-progress tracker · Search · Find & replace · Bookmarks (browse + edit) · Auto table of contents · Multi-document tabs · Visual compare with side-by-side & slider diff

### Annotation & Markup
Highlight / underline / strikethrough · Free draw · Built-in stamps · Custom stamp creator and library · Sticky notes · Text overlays · Edit existing PDF text · Annotation summary list · FDF/XFDF import & export · Annotation presets · Multi-select · Color picker

### Document Manipulation
Merge · Interleave pages from two PDFs · Split by ranges, bookmarks, or file size · Reorder / rotate / delete / duplicate pages · Resize pages to standard formats · Insert blank or existing pages · Manual & auto crop · Deskew scanned pages · Brightness / contrast / grayscale adjust

### Forms & Signatures
Fill interactive PDF forms · Form data import/export (FDF, XFDF, JSON) · Form-field creator · Auto-detect fields on flat PDFs · Draw / type / upload digital signatures · Verify embedded digital signatures

### Conversion & Export
OCR (Tesseract.js) · PDF ↔ Image (PNG / JPEG) · Image to PDF · Extract images · Extract tables to CSV / XLSX · Export to **DOCX**, **PPTX**, **HTML**, **Markdown**, **EPUB**, **SVG**

### Security & Privacy
Password protection / encryption · Manual redaction · Smart PII auto-redaction (worker-based) · Sanitize (strip JS, embedded files, hidden layers) · Flatten annotations into pages

### Document Enhancements
Text & image watermarks · Bates numbering (legal) · Page numbers · Custom page labels (i, ii, A1, …) · Headers & footers · Backgrounds & borders · Hyperlinks & link manager · QR / barcode generation and scanning

### Optimization & Compliance
Compress PDFs · PDF/A archival conversion · Print preparation (bleed, marks) · Repair corrupted PDFs · Font inspector · Document statistics · Metadata editor

### Productivity
Batch processing · Document templates · Snipping tool · Distance / area measurements · Rulers and snap guides · OCG layer management · Attached-file manager · Duplicate-page detection · Image catalog · Clipboard helpers · Global undo / redo · Autosave to local storage

### UI & Accessibility
ARIA / screen-reader support · Keyboard shortcuts · Cmd/Ctrl+K command palette · Right-click context menu · Customizable toolbars · Light / dark theme · Touch gestures · Text-to-speech

### Integration & Storage
Drag-and-drop upload · Open from URL · Cloud storage integration · PWA install + offline service worker · Central action registry · Inter-module event bus

> The full per-module feature table is in [CLAUDE.md](CLAUDE.md).

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
| **DOCX Export** | docx.umd.js | Word document export |
| **PPTX Export** | pptxgenjs | PowerPoint export |
| **Spreadsheets** | xlsx (SheetJS) | Table extraction → XLSX/CSV |
| **Archives** | JSZip | EPUB / DOCX / zip packaging |
| **QR / Barcode** | qrcode-generator, jsBarcode, jsQR | Generate and scan codes |
| **Frontend** | HTML/CSS + native ES modules | User interface (no build step) |
| **PWA** | Service Worker + manifest.json | Installable, offline-capable |
| **Web Server** | Nginx 1.26.3 + Let's Encrypt SSL | Serve the application |
| **AI Engine** | Claude Code | Autonomous development |
| **Scheduling** | Cron | Run agents every 2 hours |
| **Version Control** | Git + GitHub | Track all changes |

> 100% client-side. No backend, no bundler — modules are loaded directly by the browser. PDFs never leave the user's device.

## Agents

### Main Pipeline (Every 2 hours)

| Agent | Role | Description |
|-------|------|-------------|
| **idea-maker** | Ideation | Generates PDF editor feature ideas |
| **project-manager** | Planning | Assigns and prioritizes tasks |
| **developer** | Implementation | Builds PDF editor features |
| **developer2** | Implementation | Builds features in parallel |
| **tester** | QA | Runs a 6-phase browser smoke test in headless Chrome (`chrome-devtools` MCP) every cycle: homepage console check → example.pdf upload → post-upload geometry/visibility check (catches layout regressions where state says "loaded" but the user sees nothing) → tool-tab interaction sweep → zoom/fit-width viewer interaction → cleanup. Files SYSTEM CRITICAL entries on any failure — never patches bugs itself. |
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
/home/novakj/techtools-claude-code-cron-loop/
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
/var/www/cronloop.techtools.cz/  # PDF Editor web app (PWA)
├── index.html             # Single-page app entry point
├── manifest.json          # PWA manifest
├── sw.js                  # Service worker (offline cache)
├── offline.html           # Offline fallback page
├── css/
│   ├── main.css
│   ├── viewer.css
│   └── tools.css
├── js/                    # ~100 ES module feature files
│   ├── app.js                  # Bootstrap & wiring
│   ├── event-bus.js            # Inter-module pub/sub
│   ├── action-registry.js      # Central action registry
│   ├── viewer.js               # pdf.js viewer
│   ├── annotate.js             # Highlight/underline/strikethrough
│   ├── merge.js / split.js     # Combine / split docs
│   ├── forms.js / signatures.js
│   ├── ocr.js                  # Tesseract OCR
│   ├── redact.js / smart-redact.js
│   ├── docx-export.js / pptx-export.js / epub-export.js / ...
│   └── ... (~80 more)          # See CLAUDE.md for the full table
├── lib/                   # Vendored libraries (no build step)
│   ├── pdf.min.mjs / pdf.worker.min.mjs   # pdf.js
│   ├── pdf-lib.min.js                     # PDF manipulation
│   ├── tesseract.min.js                   # OCR
│   ├── jszip.min.js                       # ZIP/EPUB/DOCX
│   ├── docx.umd.js                        # DOCX export
│   ├── pptxgenjs.bundle.js                # PPTX export
│   ├── xlsx.full.min.js                   # Spreadsheet I/O
│   ├── qrcode-generator.min.js / jsbarcode.min.js / jsqr.min.js
│   └── ...
├── assets/
│   ├── icons/             # PWA + UI icons
│   └── fonts/             # Embedded fonts
└── templates/             # Document templates
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
