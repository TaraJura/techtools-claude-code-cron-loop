# CLAUDE.md - System Instructions

> **This is the core instruction file.** Keep it lean. Details are in `docs/`.

## SYSTEM IDENTITY: AI-Powered PDF Editor Factory

> **This entire server is autonomously maintained by Claude Code with FULL SUDO PERMISSIONS.**

| Aspect | Description |
|--------|-------------|
| **Engine** | Claude Code (Anthropic's AI CLI tool) |
| **Execution** | Main pipeline every 4 hours, supervisor 2x/day via crontab |
| **Permissions** | Full sudo access - can do anything on this server |
| **Agents** | 7 specialized AI agents collaborate on tasks |
| **Goal** | Build a professional PDF Editor web application autonomously |
| **Live App** | https://cronloop.techtools.cz |

Everything here - code, configs, documentation, web app - is created and maintained by AI.
No human intervention required. **The machine builds the product.**

For detailed information about the autonomous architecture, see `docs/autonomous-system.md`.

## Project: PDF Editor Web Application

### What We're Building

A full-featured, browser-based PDF editor at https://cronloop.techtools.cz. The app is a **Progressive Web App** (installable, offline-capable via service worker) with ~100 features already shipped, organized into the following categories:

#### Viewing & Navigation
| Feature | Module | Description |
|---------|--------|-------------|
| **PDF Viewer** | `viewer.js` | Render PDFs via pdf.js, zoom, pan, rotate |
| **Minimap** | `minimap.js` | Document overview minimap |
| **Magnifier** | `magnifier.js` | Loupe/zoom magnifier |
| **Presentation Mode** | `present.js` | Full-screen presentation |
| **Reader Mode** | `reader.js` | Distraction-free reading view |
| **Reading Progress** | `reading-progress.js` | Persistent reading position tracker |
| **Search** | `search.js` | Find text in document |
| **Find & Replace** | `find-replace.js` | Search and replace text |
| **Bookmarks** | `bookmarks.js`, `bookmark-editor.js` | Navigate and edit PDF bookmarks |
| **Table of Contents** | `toc.js` | Auto-generate / browse TOC |
| **Tabs** | `tabs.js`, `page-tabs.js` | Multi-document tabs |
| **Compare** | `compare.js`, `comparison-slider.js` | Visual diff between PDFs |

#### Annotation & Markup
| Feature | Module | Description |
|---------|--------|-------------|
| **Highlight / Underline / Strikethrough** | `annotate.js` | Standard text markup |
| **Free Draw** | `drawing.js` | Pen/brush free-draw |
| **Stamps** | `stamps.js` | Built-in approval/status stamps |
| **Custom Stamps** | `custom-stamps.js` | User-created stamp library |
| **Sticky Notes** | `sticky-notes.js` | Comment notes on pages |
| **Text Overlay** | `text-overlay.js` | Add text on top of PDFs |
| **Text Edit** | `text-edit.js` | Edit existing PDF text |
| **Annotation Summary** | `annotation-summary.js` | List/jump to all annotations |
| **Annotation Exchange** | `annotation-exchange.js` | Import/export annotations (FDF/XFDF) |
| **Annotation Presets** | `annotation-presets.js` | Saveable annotation styles |
| **Multi-Select** | `multiselect.js` | Select multiple annotations |
| **Color Picker** | `color-picker.js` | Annotation color picker |

#### Document Manipulation
| Feature | Module | Description |
|---------|--------|-------------|
| **Merge** | `merge.js` | Combine multiple PDFs |
| **Interleave** | `interleave.js` | Interleave pages from two PDFs |
| **Split (Ranges)** | `split.js` | Split into page ranges |
| **Split by Bookmarks** | `split-bookmarks.js` | Split at bookmark boundaries |
| **Split by Size** | `split-by-size.js` | Split into chunks under N MB |
| **Page Management** | `pages.js` | Reorder, rotate, delete, duplicate |
| **Page Resize** | `page-resize.js` | Resize pages to standard formats |
| **Insert Pages** | `insert-pages.js` | Insert blank/existing pages |
| **Crop** | `crop.js`, `auto-crop.js` | Manual and auto crop margins |
| **Deskew** | `deskew.js` | Straighten skewed scans |
| **Color Adjust** | `color-adjust.js` | Brightness/contrast/grayscale |

#### Forms & Signatures
| Feature | Module | Description |
|---------|--------|-------------|
| **Form Filling** | `forms.js` | Fill interactive PDF forms |
| **Form Data Import/Export** | `form-data.js` | FDF/XFDF/JSON round-trip |
| **Form Creator** | `form-creator.js` | Create new form fields |
| **Form Detect** | `form-detect.js` | Auto-detect fields on flat PDFs |
| **Digital Signatures** | `signatures.js` | Draw/type/upload signatures |
| **Signature Verification** | `verify-signatures.js` | Verify embedded digital signatures |

#### Conversion & Export
| Feature | Module | Description |
|---------|--------|-------------|
| **OCR** | `ocr.js` | Tesseract.js text recognition |
| **PDF ↔ Image** | `convert.js` | Render pages to PNG/JPEG |
| **Image to PDF** | `img2pdf.js` | Build PDF from images |
| **Extract Images** | `extract-images.js` | Pull all images out of a PDF |
| **Extract Tables** | `tables.js` | Detect and export tables (CSV/XLSX) |
| **DOCX Export** | `docx-export.js` | Export to Word (`docx`) |
| **PPTX Export** | `pptx-export.js` | Export to PowerPoint (`pptxgenjs`) |
| **HTML Export** | `html-export.js` | Export to HTML |
| **Markdown Export** | `markdown-export.js` | Export to Markdown |
| **EPUB Export** | `epub-export.js` | Export to EPUB |
| **SVG Export** | `svg-export.js` | Export pages as SVG |

#### Security & Privacy
| Feature | Module | Description |
|---------|--------|-------------|
| **Password Protect** | `protect.js` | Encrypt PDFs with a password |
| **Manual Redaction** | `redact.js` | Black-box redact regions |
| **Smart Redaction** | `smart-redact.js`, `smart-redact-worker.js` | Auto-detect and redact PII (worker-based) |
| **Sanitize** | `sanitize.js` | Strip JS, embedded files, hidden layers |
| **Flatten** | `flatten.js` | Bake annotations and form data into pages |

#### Document Enhancements
| Feature | Module | Description |
|---------|--------|-------------|
| **Watermarks** | `watermark.js` | Text/image watermarks |
| **Bates Numbering** | `bates.js` | Legal-style Bates numbering |
| **Page Numbers** | `page-numbers.js` | Add page numbers |
| **Page Labels** | `page-labels.js` | Custom page labels (i, ii, A1, ...) |
| **Headers & Footers** | `headers-footers.js` | Page headers/footers |
| **Backgrounds & Borders** | `bg-borders.js` | Page backgrounds and borders |
| **Hyperlinks** | `hyperlinks.js`, `link-manager.js` | Add/manage internal & external links |
| **QR / Barcode** | `qrbarcode.js` | Generate / scan QR codes and barcodes |

#### Optimization & Compliance
| Feature | Module | Description |
|---------|--------|-------------|
| **Compress** | `compress.js` | Reduce PDF file size |
| **PDF/A** | `pdfa.js` | Convert to PDF/A archival format |
| **Print Prep** | `printprep.js` | Print preparation (bleed, marks) |
| **Repair** | `repair.js` | Repair corrupted PDFs |
| **Font Inspector** | `font-inspector.js` | Inspect embedded fonts |
| **Statistics** | `statistics.js` | Document analytics (pages, fonts, sizes) |
| **Metadata** | `metadata.js` | Edit title/author/subject/keywords |

#### Productivity
| Feature | Module | Description |
|---------|--------|-------------|
| **Batch Processing** | `batch.js` | Apply ops to many files |
| **Templates** | `templates.js` | Pre-built document templates |
| **Snip** | `snip.js` | Snipping tool / region capture |
| **Measure** | `measure.js` | Distance/area measurements |
| **Guides** | `guides.js` | Rulers and snap guides |
| **Layers** | `layers.js` | Optional Content Group (OCG) management |
| **Attachments** | `attachments.js` | Attached file manager |
| **Duplicate Detect** | `duplicate-detect.js` | Find duplicate pages |
| **Image Manager** | `image-manager.js` | Catalog images in a doc |
| **Clipboard** | `clipboard.js` | Copy/paste helpers |
| **Undo/Redo** | `undo-redo.js` | Global undo stack |
| **Autosave** | `autosave.js` | Auto-save edits to local storage |

#### UI & Accessibility
| Feature | Module | Description |
|---------|--------|-------------|
| **Accessibility** | `accessibility.js` | ARIA, screen-reader support |
| **Keyboard Shortcuts** | `keyboard-shortcuts.js` | Hotkey system |
| **Command Palette** | `command-palette.js` | Cmd/Ctrl+K command runner |
| **Context Menu** | `context-menu.js` | Right-click menus |
| **Toolbar Manager** | `toolbar-manager.js` | Customizable toolbars |
| **Theme** | `theme.js` | Light/dark theme switcher |
| **Touch Gestures** | `touch.js` | Mobile/tablet touch input |
| **Text-to-Speech** | `tts.js` | Read PDF aloud |

#### Integration & Storage
| Feature | Module | Description |
|---------|--------|-------------|
| **Drag-and-Drop Upload** | `upload.js` | Local file ingest |
| **Open from URL** | `open-url.js` | Load PDFs from a URL |
| **Cloud Storage** | `cloud-storage.js` | Cloud provider integration |
| **PWA** | `pwa.js`, `sw.js`, `manifest.json` | Installable, offline-capable |
| **Action Registry** | `action-registry.js` | Central command registry |
| **Event Bus** | `event-bus.js` | Inter-module messaging |

### Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **PDF Rendering** | pdf.js (Mozilla) | View and render PDF pages in browser |
| **PDF Manipulation** | pdf-lib | Merge, split, modify PDF structure |
| **OCR** | Tesseract.js | Optical character recognition |
| **DOCX Export** | docx.umd.js | Export PDFs to Word documents |
| **PPTX Export** | pptxgenjs | Export PDFs to PowerPoint |
| **Spreadsheet I/O** | xlsx (SheetJS) | Table extraction to XLSX/CSV |
| **Archive Handling** | JSZip | EPUB/DOCX/zip packaging |
| **QR / Barcodes** | qrcode-generator, jsBarcode, jsQR | Generate and scan codes |
| **Frontend** | HTML / CSS / Vanilla ES Modules | UI components and interactions |
| **No Build Step** | Native ES modules | Scripts loaded directly via `<script type="module">` |
| **PWA** | Service Worker + manifest.json | Installable, offline-capable |
| **Web Server** | Nginx + Let's Encrypt SSL | Serve the application |
| **Hosting** | Ubuntu 25.04 VPS | cronloop.techtools.cz |

> **Architecture note**: The app is 100% client-side. There is no backend, no build step, and no bundler — modules are loaded natively by the browser. PDFs never leave the user's device.

### Web Application Structure

```
/var/www/cronloop.techtools.cz/
├── index.html          # Main application entry (single-page app)
├── manifest.json       # PWA manifest
├── sw.js               # Service worker (offline cache)
├── offline.html        # Offline fallback page
├── favicon.ico
├── css/
│   ├── main.css        # Layout, header, app shell
│   ├── viewer.css      # PDF viewer styles
│   └── tools.css       # Tool panels and dialogs
├── js/                 # ~100 ES module feature files
│   ├── app.js                  # Bootstrap & wiring
│   ├── event-bus.js            # Inter-module pub/sub
│   ├── action-registry.js      # Central action registry
│   ├── viewer.js               # pdf.js viewer
│   ├── upload.js               # Drag-and-drop upload
│   ├── annotate.js             # Highlight/underline/strikethrough
│   ├── drawing.js              # Free draw
│   ├── stamps.js               # Built-in stamps
│   ├── custom-stamps.js        # Custom stamp creator
│   ├── sticky-notes.js         # Sticky note comments
│   ├── text-overlay.js         # Add text overlays
│   ├── text-edit.js            # Edit existing PDF text
│   ├── merge.js / split.js     # Document combine / split
│   ├── pages.js                # Reorder/rotate/delete
│   ├── forms.js / form-*.js    # Form filling, creating, detecting
│   ├── signatures.js           # Draw/upload signatures
│   ├── verify-signatures.js    # Verify embedded signatures
│   ├── ocr.js                  # Tesseract OCR
│   ├── redact.js               # Manual redaction
│   ├── smart-redact*.js        # PII auto-redact (worker)
│   ├── compress.js             # PDF compression
│   ├── watermark.js            # Watermarks
│   ├── pdfa.js                 # PDF/A conversion
│   ├── batch.js                # Batch processing
│   ├── pwa.js                  # PWA installer
│   └── ... (~80 more)          # See feature table above
├── lib/                # Third-party libraries (no build step)
│   ├── pdf.min.mjs             # pdf.js viewer
│   ├── pdf.worker.min.mjs      # pdf.js worker
│   ├── pdf-lib.min.js          # PDF manipulation
│   ├── tesseract.min.js        # OCR
│   ├── jszip.min.js            # ZIP/EPUB/DOCX packaging
│   ├── docx.umd.js             # DOCX export
│   ├── pptxgenjs.bundle.js     # PPTX export
│   ├── xlsx.full.min.js        # Spreadsheet I/O
│   ├── qrcode-generator.min.js # QR generation
│   ├── jsbarcode.min.js        # Barcode generation
│   └── jsqr.min.js             # QR scanning
├── assets/
│   ├── icons/                  # PWA icons + UI icons
│   └── fonts/                  # Embedded fonts
└── templates/                  # Document templates
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

### Main Pipeline (Every 4 hours)
| Actor | Role | Runs |
|-------|------|------|
| idea-maker | Generate PDF editor feature ideas | 1st |
| project-manager | Assign and prioritize tasks | 2nd |
| developer | Implement PDF editor features | 3rd |
| developer2 | Implement features (parallel) | 4th |
| tester | Verify PDF operations work in a real headless browser via `chrome-devtools` MCP. Runs a 6-phase smoke test every tick: (1) homepage load + console check, (2) example.pdf upload, (3) post-upload **visibility/geometry** check (`#pdf-pages` width ≥ 300, visible canvases), (4) tool interaction sweep (click rotation of tool tabs, verify panels activate, no new errors), (5) viewer interaction (zoom, fit-width, geometry still sane), (6) cleanup. Files SYSTEM CRITICAL entries on any failure — NEVER fixes bugs itself. | 5th |
| security | Security review (file uploads, XSS) | 6th (last) |

### Supervisor (Twice daily: 8 AM & 8 PM)
| Actor | Role | Runs |
|-------|------|------|
| supervisor | Ecosystem overseer | 2x/day (8:15 AM, 8:15 PM) |

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
