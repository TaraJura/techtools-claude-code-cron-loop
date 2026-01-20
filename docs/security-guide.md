# Security Guide

> Security guidelines, checklists, and incident response procedures.

## Critical Rule

**The web application must NEVER expose sensitive system data.** Hackers must not be able to access internal files through the web interface.

## Sensitive Data (NEVER expose to web)

| Path | Contains | Risk if exposed |
|------|----------|-----------------|
| `/home/novakj/CLAUDE.md` | System instructions, architecture | Full system compromise |
| `/home/novakj/tasks.md` | Task board, internal plans | Information leak |
| `/home/novakj/.ssh/` | SSH private keys | Server takeover |
| `/home/novakj/.git/` | Git history, credentials | Code/secret exposure |
| `/home/novakj/scripts/` | System scripts | Attack vectors |
| `/home/novakj/actors/*/prompt.md` | Actor instructions | System understanding |
| `/etc/` | System configs | Server compromise |
| `/var/log/auth.log` | Auth attempts, IPs | Security intel |

## Web Security Rules

### 1. Path Restrictions (nginx must enforce)
```nginx
# BLOCK access to sensitive file types
location ~ /\. { deny all; }           # Hidden files (.git, .env)
location ~ \.md$ { deny all; }         # Markdown files
location ~ \.sh$ { deny all; }         # Shell scripts
location ~ \.py$ { deny all; }         # Python scripts
location ~ \.log$ { deny all; }        # Log files
```

### 2. Safe API Design
- API endpoints return ONLY sanitized, public data
- Never pass user input directly to file paths
- Never execute shell commands with user input
- Always validate and sanitize all inputs

### 3. Content Security
- No server-side scripting in web root (no PHP, CGI)
- Static files only unless explicitly needed
- If API needed, use a separate backend with proper auth

### 4. Data Isolation
- Web app reads data through controlled scripts (e.g., system-metrics-api.sh)
- Scripts output sanitized JSON only
- Never direct file access from web

## Security Checklist

Run these checks before any deployment:

```bash
# 1. Check no sensitive files in web root
find /var/www/cronloop.techtools.cz -name "*.md" -o -name "*.sh" -o -name "*.py" -o -name ".git*"

# 2. Check no symlinks to outside web root
find /var/www/cronloop.techtools.cz -type l -exec ls -la {} \;

# 3. Check nginx config blocks sensitive paths
grep -E "deny|location.*\\\." /etc/nginx/sites-enabled/*

# 4. Check file permissions (should not be world-writable)
find /var/www/cronloop.techtools.cz -perm -002 -type f

# 5. Check for exposed secrets in JS files
grep -r -i "password\|secret\|api_key\|token" /var/www/cronloop.techtools.cz/*.js 2>/dev/null

# 6. Check no sensitive paths accessible
curl -s https://cronloop.techtools.cz/.git/config | head -5  # Should fail
curl -s https://cronloop.techtools.cz/CLAUDE.md | head -5    # Should fail
```

## Incident Response

If a security issue is detected:

1. **IMMEDIATE**: Remove/block the vulnerable endpoint
2. **ASSESS**: Determine what data may have been exposed
3. **FIX**: Patch the vulnerability
4. **VERIFY**: Run security checklist again
5. **LOG**: Document incident in `logs/changelog.md`
6. **ROTATE**: If credentials exposed, rotate them immediately

## Security Actor Responsibilities

The security actor runs LAST in the orchestration cycle and must:
- Review all new code for vulnerabilities
- Check nginx config after any web changes
- Verify no secrets committed to git
- Monitor auth.log for suspicious activity
- Update `status/security.json` with current state

## Security Actor Logging Rules

**DO NOT** log repetitive "all checks passed" messages to changelog.

**DO** update `status/security.json` with current state (overwrites previous).

**DO** log to changelog ONLY when:
- A new vulnerability is found
- A security incident occurs
- A significant change in attack patterns (e.g., 50%+ increase)
- A new mitigation is implemented
- Something was FIXED

## Expected File Permissions

| Path | Permission | Notes |
|------|------------|-------|
| `CLAUDE.md` | 664 | Readable by all, writable by owner/group |
| `.ssh/` | 700 | Owner only |
| `.ssh/id_ed25519` | 600 | Private key, owner only |
| Web files | 644 | Readable by all, writable by owner |
