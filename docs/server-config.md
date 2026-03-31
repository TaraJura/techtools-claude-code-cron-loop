# Server Configuration

> Static server information for the PDF Editor factory. Update only when hardware/software changes.

## Server Specs

| Resource | Value |
|----------|-------|
| **Hostname** | vps-2d421d2a |
| **OS** | Ubuntu 25.04 (Plucky Puffin) |
| **Kernel** | Linux 6.14.0-34-generic |
| **CPU** | 4 cores |
| **RAM** | 7.6 GB |
| **Disk** | 72 GB (68 GB available) |

## Software

| Software | Version | Purpose |
|----------|---------|---------|
| **Nginx** | 1.26.3 | Web server for PDF editor app |
| **Node.js** | (install if needed) | Backend processing |
| **Git** | 2.48.1 | Version control |
| **Claude Code** | v2.1.12+ | AI agent engine |
| **SSL** | Let's Encrypt | HTTPS for cronloop.techtools.cz |

## Key Paths

| Path | Purpose |
|------|---------|
| `/home/novakj/` | Project root, agent configs, scripts |
| `/var/www/cronloop.techtools.cz/` | Web application root (PDF editor) |
| `/home/novakj/scripts/` | Orchestration and maintenance scripts |
| `/home/novakj/actors/` | Agent prompt files and logs |
| `/home/novakj/docs/` | Documentation |
| `/home/novakj/status/` | System status JSON files |
| `/home/novakj/logs/` | Execution and maintenance logs |

## Nginx Configuration

- Serves static files from `/var/www/cronloop.techtools.cz/`
- SSL via Let's Encrypt (auto-renewal)
- Blocks access to sensitive files: `.git`, `.env`, `*.sh`, `*.py`, `*.log`, `*.md`
- MIME types configured for JavaScript modules (`.mjs`)
- CORS headers if needed for PDF.js worker

## Cron Schedule

| Schedule | Script | Purpose |
|----------|--------|---------|
| `0 */2 * * *` | `cron-orchestrator.sh` | Run main agent pipeline (6 agents) |
| `15 */2 * * *` | `run-supervisor.sh` | Run supervisor agent |
| `0 * * * *` | `maintenance.sh` | Hourly maintenance |
| `0 3 * * *` | `cleanup.sh` | Daily cleanup at 3 AM |

## PDF Editor Dependencies

Libraries to include in `/var/www/cronloop.techtools.cz/lib/`:

| Library | Version | Purpose | CDN/Source |
|---------|---------|---------|------------|
| **pdf.js** | Latest stable | PDF rendering | mozilla.github.io/pdf.js |
| **pdf-lib** | Latest stable | PDF manipulation | pdf-lib.js.org |
| **Tesseract.js** | Latest stable | OCR | tesseract.projectnaptha.com |

## GitHub

- **Repo**: https://github.com/TaraJura/techtools-claude-code-cron-loop
- **Branch**: main
- **Auto-push**: After each agent run via `run-actor.sh`
