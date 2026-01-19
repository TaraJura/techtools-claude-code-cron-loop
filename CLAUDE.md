# CLAUDE.md - Server Knowledge Base

> **CRITICAL RULE**: Every change made on this server MUST be documented in this file. Update the relevant sections and add entries to the Change Log.

## Server Overview

- **Hostname**: vps-2d421d2a
- **Role**: Production Development Server
- **Managed by**: Claude (DevOps + Senior Developer)
- **Primary User**: novakj (with sudo privileges)
- **Last Updated**: 2026-01-19

## System Specifications

| Resource | Value |
|----------|-------|
| OS | Ubuntu 25.04 (Plucky Puffin) |
| Kernel | Linux 6.14.0-34-generic |
| CPU Cores | 4 |
| RAM | 7.6 GB |
| Disk | 72 GB (70 GB available) |
| Platform | linux |

## Current Server Status

- **Status**: Operational
- **Environment**: Production
- **Services Running**: (none configured yet)

---

## Users

| Username | Role | Sudo | Shell | Home |
|----------|------|------|-------|------|
| novakj | Primary Admin/Developer | Yes | /bin/bash | /home/novakj |
| ubuntu | System User | Yes | /bin/bash | /home/ubuntu |

---

## Installed Software & Services

### System Packages
- Base Ubuntu 25.04 installation

### Development Tools
- (to be documented as installed)

### Databases
- (none installed yet)

### Web Servers
- (none installed yet)

### Other Services
- (none installed yet)

---

## Projects

| Project | Path | Description | Status |
|---------|------|-------------|--------|
| (none yet) | - | - | - |

---

## Important Paths

| Path | Purpose |
|------|---------|
| `/home/novakj` | Primary home directory, main workspace |
| `/home/novakj/CLAUDE.md` | This knowledge base file |
| `/home/ubuntu` | Ubuntu system user home |
| `/etc/nginx/` | Nginx configuration (when installed) |
| `/var/www/` | Web root (when configured) |
| `/var/log/` | System logs |

---

## Configuration Standards

### Security Best Practices
- Always use SSH key authentication (no password auth)
- Keep system packages updated regularly
- Use UFW firewall with minimal open ports
- Run services with least privilege
- Store secrets in environment variables or secure vaults, never in code

### Development Standards
- Use version control (Git) for all projects
- Follow semantic versioning
- Write meaningful commit messages
- Document all APIs and configurations
- Use environment-specific configurations

### Deployment Standards
- Test changes in staging when possible
- Use systemd for service management
- Implement proper logging
- Set up monitoring and alerts
- Create backups before major changes

---

## Firewall Rules (UFW)

| Port | Service | Status |
|------|---------|--------|
| 22 | SSH | (to be configured) |

---

## Scheduled Tasks (Cron)

| Schedule | Task | Description |
|----------|------|-------------|
| (none configured) | - | - |

---

## Environment Variables

Document any global environment variables set on the server:

```bash
# (none configured yet)
```

---

## Backups

| What | Location | Frequency |
|------|----------|-----------|
| (none configured) | - | - |

---

## Change Log

All changes to this server must be logged here in reverse chronological order.

### 2026-01-19
- **[USER]** Created user `novakj` with home directory `/home/novakj`
- **[USER]** Set password for `novakj`
- **[USER]** Added `novakj` to sudo group for admin privileges
- **[CONFIG]** Moved CLAUDE.md to `/home/novakj/CLAUDE.md`
- **[CONFIG]** Set novakj as primary admin user
- **[INIT]** Created CLAUDE.md knowledge base file
- **[INIT]** Server baseline documented
- **[INIT]** Established documentation standards and best practices

---

## Pending Tasks

- [ ] Configure UFW firewall
- [ ] Set up automatic security updates
- [ ] Install development tools as needed
- [ ] Configure backup strategy

---

## Notes

- This is a production server - exercise caution with all changes
- Always update this file after making any server modifications
- When in doubt, document it

---

*This file serves as the single source of truth for this server's configuration and state.*
