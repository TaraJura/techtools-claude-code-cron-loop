# Server Configuration

> Static server information for the PDF Editor factory. Update only when hardware/software changes.
> **Migrated 2026-06-07** from the old VPS (`vps-2d421d2a`) to `vm3`. Server-level ops doc lives at `/home/novakj/CLAUDE.md` (outside this repo) — read it too; its rules apply to all agents.

## Server Specs

| Resource | Value |
|----------|-------|
| **Hostname** | vm3 (KVM guest, LAN: 192.168.1.110/24) |
| **OS** | Ubuntu 26.04 LTS (resolute) |
| **Kernel** | Linux 7.0.0-22-generic |
| **CPU** | 2 vCPU |
| **RAM** | 1.6 GB + 2 GB swap — **LOW: run heavy tools (Chrome, OCR) one at a time** |
| **Disk** | 15 GB LVM root (~40% used fresh) — **SMALL: watch `df -h` before big downloads** |

## Software

| Software | Version | Purpose |
|----------|---------|---------|
| **Nginx** | 1.28.3 | Web server for PDF editor app (HTTP :80, LAN only) |
| **Git** | 2.53.0 | Version control |
| **Claude Code** | 2.1.168 | AI agent engine (`/home/novakj/.local/bin/claude`) |
| **Python** | 3.14.4 | System Python |
| **Node.js / npm** | 24.16.0 / 11.13.0 | Installed 2026-06-07 (NodeSource LTS) for the tester's `chrome-devtools` MCP |
| **Chrome for Testing** | 149.0.7827.54 | Headless browser at `~/.cache/puppeteer/chrome/` for the tester MCP (one browser only) |
| **SSL** | — | **Deferred** — Let's Encrypt requires the `cronloop.techtools.cz` DNS cutover to this host first |

## Key Paths

| Path | Purpose |
|------|---------|
| `/home/novakj/techtools-claude-code-cron-loop/` | Project root (this repo), agent configs, scripts |
| `/var/www/cronloop.techtools.cz/` | Web application root (PDF editor) |
| `/home/novakj/techtools-claude-code-cron-loop/scripts/` | Orchestration and maintenance scripts |
| `/home/novakj/techtools-claude-code-cron-loop/actors/` | Agent prompt files and logs |
| `/home/novakj/techtools-claude-code-cron-loop/docs/` | Documentation |
| `/home/novakj/techtools-claude-code-cron-loop/status/` | System status JSON files |
| `/home/novakj/techtools-claude-code-cron-loop/logs/` | Execution and maintenance logs |
| `/home/novakj/CLAUDE.md` | Server-level ops doc (NOT in this repo — server changes go in its Changelog) |

## Nginx Configuration

- Vhost: `/etc/nginx/sites-available/cronloop.techtools.cz` (symlinked in `sites-enabled`, default vhost removed)
- Serves static files from `/var/www/cronloop.techtools.cz/`
- HTTP only on :80 for now (LAN); SSL via Let's Encrypt **after** DNS cutover
- Blocks access to sensitive files: dotfiles/`.git`, `*.sh`, `*.py`, `*.log`, `*.md`
- MIME type for ES modules: `.mjs` served as `text/javascript`
- Test + reload: `sudo nginx -t && sudo systemctl reload nginx`

## Cron Schedule

Installed in the `novakj` user crontab (`crontab -l`):

| Schedule | Script | Purpose |
|----------|--------|---------|
| `0 */4 * * *` | `cron-orchestrator.sh` | Run main agent pipeline (6 agents) |
| `15 8,20 * * *` | `run-supervisor.sh` | Run supervisor agent (twice daily) |
| `0 * * * *` | `maintenance.sh` | Hourly maintenance (log trim, archive check) |
| `0 3 * * *` | `cleanup.sh` | Daily cleanup at 3 AM |

## PDF Editor Dependencies

Libraries to vendor into `/var/www/cronloop.techtools.cz/lib/` (no CDN at runtime):

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| **pdf.js** | Latest stable | PDF rendering | mozilla.github.io/pdf.js |
| **pdf-lib** | Latest stable | PDF manipulation | pdf-lib.js.org |
| **Tesseract.js** | Latest stable | OCR | tesseract.projectnaptha.com |

## GitHub

- **Repo**: https://github.com/TaraJura/techtools-claude-code-cron-loop
- **Branch**: main
- **Auto-push**: After each agent run via `run-actor.sh` (SSH key auth as `TaraJura` — verified working)
