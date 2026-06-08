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
| `/var/www/cronloop.techtools.cz/` | Web application root (PDF editor) — **LIVE, source of truth** |
| `/home/novakj/techtools-claude-code-cron-loop/web/` | Git-tracked **mirror** of the live web root (recoverability backup — see below). Auto-generated; never hand-edit. |
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

## Web Root Backup & Recovery (TASK-311)

The live web root `/var/www/cronloop.techtools.cz/` is **mirrored into the repo** at
`web/` so the app code (HTML/CSS/JS + the vendored `lib/`) is version-controlled and
pushed to GitHub every pipeline tick. Before this, the auto-commit backed up only
`docs/`/`scripts/`/`status/`/`actors/`/`tasks.md` — none of the rebuilt app code — the
same recoverability gap that made the vm3 migration painful.

**Source-of-truth direction — ONE WAY only (`live → repo`):**

- The **live web root is the single source of truth.** The developer agents keep editing
  `/var/www/cronloop.techtools.cz/` directly (no agent-prompt changes were needed).
- `scripts/mirror-webroot.sh` does a read-only `rsync -rlptD --delete` of the live root
  into `web/`. It **never writes to `/var/www`**, so it cannot destabilize the live site.
- The orchestrator calls it **once per tick**, after the developer agents and before the
  tester, so the tester's & security's `run-actor.sh` auto-commits push `web/`.
- **Do NOT** add a `repo → live` deploy direction. A two-way sync would race the agents
  editing the live root and clobber changes. `web/` is a backup mirror, not an edit target
  — never hand-edit `web/` (the next mirror overwrites it).

**Dry-run restore (rebuild `/var/www` from the repo on a fresh box):**

```bash
# 1. Clone the repo (contains web/ with index.html, css/, js/, lib/, assets/)
git clone git@github.com:TaraJura/techtools-claude-code-cron-loop.git
cd techtools-claude-code-cron-loop

# 2. Recreate the live web root from the tracked mirror (self-contained — lib/ included)
sudo mkdir -p /var/www/cronloop.techtools.cz
sudo rsync -a --delete web/ /var/www/cronloop.techtools.cz/

# 3. Re-apply ownership + permissions nginx needs
sudo chown -R novakj:www-data /var/www/cronloop.techtools.cz
sudo find /var/www/cronloop.techtools.cz -type d -exec chmod 755 {} \;
sudo find /var/www/cronloop.techtools.cz -type f -exec chmod 644 {} \;

# 4. Validate (nginx vhost setup itself is in /home/novakj/CLAUDE.md)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/   # expect 200
```
