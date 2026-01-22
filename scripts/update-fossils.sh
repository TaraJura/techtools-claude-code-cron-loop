#!/bin/bash
# Update Fossils API - Excavates deleted code history from git
# Part of CronLoop Fossil Record Dashboard (TASK-174)
#
# Parses git history for deleted files and generates fossil metadata

set -e

FOSSILS_FILE="/var/www/cronloop.techtools.cz/api/fossils.json"
REPO_DIR="/home/novakj"
TMP_FILE="/tmp/fossils-tmp.json"

# Maximum fossils to include (prevent huge JSON files)
MAX_FOSSILS=100

# Generate fossils data
generate_fossils() {
    cd "$REPO_DIR"

    python3 << 'PYTHON_SCRIPT'
import json
import subprocess
import os
from datetime import datetime, timedelta
from collections import defaultdict
import random

def run_git(args):
    """Run a git command and return output"""
    try:
        result = subprocess.run(
            ['git'] + args,
            capture_output=True,
            text=True,
            cwd='/home/novakj',
            timeout=60
        )
        return result.stdout.strip()
    except Exception as e:
        return ''

def parse_iso_date(date_str):
    """Parse ISO date string"""
    try:
        # Handle various date formats
        if 'T' in date_str:
            # Strip timezone info for simplicity
            date_part = date_str.split('+')[0].split('Z')[0]
            return datetime.fromisoformat(date_part)
        return datetime.now()
    except:
        return datetime.now()

def get_deleted_files():
    """Get list of deleted files from git history"""
    # Get all deleted files with their deletion commits (including ALL file types)
    log_output = run_git([
        'log', '--diff-filter=D', '--summary', '--format=%H|%aI|%s',
        '--all'
    ])

    fossils = []
    current_commit = None
    current_date = None
    current_message = None

    for line in log_output.split('\n'):
        if not line.strip():
            continue

        if '|' in line and not line.startswith(' '):
            # This is a commit header
            parts = line.split('|', 2)
            if len(parts) >= 3:
                current_commit = parts[0][:7]
                current_date = parts[1]
                current_message = parts[2]
        elif 'delete mode' in line:
            # This is a deleted file
            parts = line.strip().split()
            if len(parts) >= 4:
                file_path = parts[-1]

                # Skip binary files and very large extensions
                skip_exts = ['.tar.gz', '.zip', '.gz', '.bin', '.exe', '.png', '.jpg', '.jpeg', '.gif', '.ico', '.woff', '.woff2', '.ttf', '.eot']
                if any(file_path.endswith(ext) for ext in skip_exts):
                    continue

                # Get file creation date (first commit that added it)
                first_commit = run_git([
                    'log', '--diff-filter=A', '--format=%aI',
                    '--follow', '--', file_path
                ])
                created_date = first_commit.split('\n')[0] if first_commit else current_date

                # Calculate lifespan
                try:
                    created = parse_iso_date(created_date)
                    deleted = parse_iso_date(current_date)
                    lifespan_days = max(1, (deleted - created).days)
                except:
                    lifespan_days = 1

                # Determine cause of extinction based on commit message
                cause = 'natural'  # default
                msg_lower = current_message.lower() if current_message else ''
                if any(word in msg_lower for word in ['refactor', 'merge', 'move', 'rename', 'reorganize', 'consolidate']):
                    cause = 'evolution'
                elif any(word in msg_lower for word in ['fix', 'bug', 'broken', 'error', 'fail', 'crash']):
                    cause = 'catastrophic'
                elif any(word in msg_lower for word in ['replace', 'new', 'better', 'upgrade', 'switch', 'use instead']):
                    cause = 'competitive'
                elif any(word in msg_lower for word in ['remove', 'delete', 'clean', 'unused', 'obsolete', 'deprecate']):
                    cause = 'natural'

                # Try to get last content (may fail for old commits)
                last_content = ''
                try:
                    # Get content from the commit before deletion
                    content_output = run_git(['show', f'{current_commit}^:{file_path}'])
                    if content_output and len(content_output) < 10000:
                        last_content = content_output
                except:
                    pass

                # Count deleted lines
                lines_deleted = len(last_content.split('\n')) if last_content else 0

                # Find living relatives (similar files)
                file_ext = os.path.splitext(file_path)[1]
                file_name = os.path.basename(file_path)

                # Search for similar files that still exist
                living_relatives = []
                try:
                    if file_ext:
                        similar_files = run_git(['ls-files', f'*{file_ext}'])
                        for similar in similar_files.split('\n')[:5]:
                            if similar and similar != file_path:
                                living_relatives.append(similar)
                except:
                    pass

                fossils.append({
                    'path': file_path,
                    'created': created_date,
                    'deleted': current_date,
                    'lifespan_days': lifespan_days,
                    'cause': cause,
                    'commit_message': current_message or 'No message',
                    'commit_hash': current_commit,
                    'lines_deleted': lines_deleted,
                    'last_content': last_content[:5000] if last_content else '',  # Limit content size
                    'living_relatives': living_relatives[:3]
                })

    return fossils

def generate_demo_fossils():
    """Generate demonstration fossils when no real ones exist"""
    now = datetime.now()
    demo_fossils = [
        {
            'path': 'scripts/old-backup-script.sh',
            'created': (now - timedelta(days=45)).isoformat(),
            'deleted': (now - timedelta(days=10)).isoformat(),
            'lifespan_days': 35,
            'cause': 'evolution',
            'commit_message': '[developer] Refactored backup system with new maintenance.sh',
            'commit_hash': 'demo001',
            'lines_deleted': 87,
            'last_content': '#!/bin/bash\n# Old backup script\n# Replaced by maintenance.sh\n\necho "Running legacy backup..."\ntar -czf backup.tar.gz /home/novakj\necho "Backup complete"',
            'living_relatives': ['scripts/maintenance.sh']
        },
        {
            'path': 'docs/draft-architecture.md',
            'created': (now - timedelta(days=60)).isoformat(),
            'deleted': (now - timedelta(days=25)).isoformat(),
            'lifespan_days': 35,
            'cause': 'competitive',
            'commit_message': '[project-manager] Replaced draft with official autonomous-system.md',
            'commit_hash': 'demo002',
            'lines_deleted': 156,
            'last_content': '# Draft Architecture\n\nThis is a preliminary design document.\n\n## Early Ideas\n\n- Multi-agent system\n- Cron-based scheduling\n- Self-monitoring capabilities',
            'living_relatives': ['docs/autonomous-system.md', 'docs/engine-guide.md']
        },
        {
            'path': 'actors/helper/prompt.md',
            'created': (now - timedelta(days=30)).isoformat(),
            'deleted': (now - timedelta(days=5)).isoformat(),
            'lifespan_days': 25,
            'cause': 'natural',
            'commit_message': '[supervisor] Removed unused helper agent - functionality merged into developer',
            'commit_hash': 'demo003',
            'lines_deleted': 45,
            'last_content': '# Helper Agent\n\nYou are a helper agent that assists with minor tasks.\n\n## Responsibilities\n\n- Small fixes\n- Documentation updates\n- Code formatting',
            'living_relatives': ['actors/developer/prompt.md', 'actors/developer2/prompt.md']
        },
        {
            'path': 'web/test-dashboard.html',
            'created': (now - timedelta(days=20)).isoformat(),
            'deleted': (now - timedelta(days=3)).isoformat(),
            'lifespan_days': 17,
            'cause': 'evolution',
            'commit_message': '[developer] Merged test dashboard into main index.html',
            'commit_hash': 'demo004',
            'lines_deleted': 234,
            'last_content': '<!DOCTYPE html>\n<html>\n<head><title>Test Dashboard</title></head>\n<body>\n  <h1>Test Dashboard</h1>\n  <p>This was a prototype dashboard for testing new features.</p>\n</body>\n</html>',
            'living_relatives': ['/var/www/cronloop.techtools.cz/index.html']
        },
        {
            'path': 'scripts/debug-logger.py',
            'created': (now - timedelta(days=15)).isoformat(),
            'deleted': (now - timedelta(days=2)).isoformat(),
            'lifespan_days': 13,
            'cause': 'catastrophic',
            'commit_message': '[tester] Removed debug logger - was causing log file bloat',
            'commit_hash': 'demo005',
            'lines_deleted': 67,
            'last_content': '#!/usr/bin/env python3\n"""Debug logger - caused issues with log file size"""\n\nimport logging\nimport sys\n\ndef setup_debug():\n    logging.basicConfig(level=logging.DEBUG)\n    # This logged too much data',
            'living_relatives': []
        }
    ]
    return demo_fossils

def identify_mass_extinctions(fossils):
    """Identify commits that deleted multiple files"""
    by_commit = defaultdict(list)
    commit_info = {}

    for fossil in fossils:
        commit_hash = fossil['commit_hash']
        by_commit[commit_hash].append(fossil)
        if commit_hash not in commit_info:
            commit_info[commit_hash] = {
                'date': fossil['deleted'],
                'message': fossil['commit_message']
            }

    mass_extinctions = []
    for commit_hash, files in by_commit.items():
        if len(files) >= 3:  # 3+ files = mass extinction
            mass_extinctions.append({
                'date': commit_info[commit_hash]['date'],
                'commit_hash': commit_hash,
                'message': commit_info[commit_hash]['message'],
                'files_deleted': len(files),
                'files': [f['path'].split('/')[-1] for f in files][:10]  # Limit to 10
            })

    return sorted(mass_extinctions, key=lambda x: x['files_deleted'], reverse=True)[:10]

def identify_resurrection_candidates(fossils):
    """Identify fossils that might be worth bringing back"""
    candidates = []

    for fossil in fossils:
        score = 0
        reason = []

        # Long-lived code is often useful
        if fossil['lifespan_days'] > 30:
            score += 20
            reason.append('long-lived code')

        # Recent deletions might be recoverable
        try:
            deleted = parse_iso_date(fossil['deleted'])
            days_ago = (datetime.now() - deleted).days
            if days_ago < 30:
                score += 15
                reason.append('recently deleted')
        except:
            pass

        # Code that was replaced might be revisited
        if fossil['cause'] == 'competitive':
            score += 10
            reason.append('replaced by alternative')

        # Substantial code is more likely to be useful
        if fossil['lines_deleted'] > 50:
            score += 15
            reason.append('substantial codebase')

        # Evolution means it was actively maintained
        if fossil['cause'] == 'evolution':
            score += 10
            reason.append('was actively maintained')

        if score >= 35:
            candidates.append({
                **fossil,
                'score': min(100, score + 30),  # Normalize to 0-100 range
                'reason': ' - '.join(reason) if reason else 'Potential utility identified'
            })

    return sorted(candidates, key=lambda x: x['score'], reverse=True)[:10]

def calculate_stats(fossils):
    """Calculate aggregate statistics"""
    if not fossils:
        return {
            'total_fossils': 0,
            'total_lines': 0,
            'avg_lifespan': 0,
            'by_cause': {},
            'by_extension': {}
        }

    by_cause = defaultdict(int)
    by_extension = defaultdict(int)
    total_lines = 0
    total_lifespan = 0

    for fossil in fossils:
        by_cause[fossil['cause']] += 1
        ext = os.path.splitext(fossil['path'])[1].lstrip('.')
        if ext:
            by_extension[ext] += 1
        total_lines += fossil['lines_deleted']
        total_lifespan += fossil['lifespan_days']

    return {
        'total_fossils': len(fossils),
        'total_lines': total_lines,
        'avg_lifespan': total_lifespan // len(fossils) if fossils else 0,
        'by_cause': dict(by_cause),
        'by_extension': dict(by_extension)
    }

# Main execution
print("Excavating fossil records from git history...", flush=True)

fossils = get_deleted_files()

# If no real fossils found, use demonstration data
if not fossils:
    print("No deleted code files found in git history.", flush=True)
    print("Using demonstration fossils for the dashboard.", flush=True)
    fossils = generate_demo_fossils()

# Sort by deletion date (most recent first) and limit
fossils = sorted(fossils, key=lambda x: x['deleted'], reverse=True)[:100]

print(f"Loaded {len(fossils)} fossils", flush=True)

# Generate related data
mass_extinctions = identify_mass_extinctions(fossils)
resurrection_candidates = identify_resurrection_candidates(fossils)
stats = calculate_stats(fossils)

# Build final JSON
result = {
    'fossils': fossils,
    'mass_extinctions': mass_extinctions,
    'resurrection_candidates': resurrection_candidates,
    'stats': stats,
    'is_demo_data': len(get_deleted_files()) == 0,
    'generated_at': datetime.now().isoformat()
}

# Write to temp file
with open('/tmp/fossils-tmp.json', 'w') as f:
    json.dump(result, f, indent=2)

print("Fossil excavation complete!", flush=True)
PYTHON_SCRIPT

    # Move temp file to final location
    if [[ -f "$TMP_FILE" ]]; then
        mv "$TMP_FILE" "$FOSSILS_FILE"
        chmod 644 "$FOSSILS_FILE"
        echo "Updated $FOSSILS_FILE"
    else
        echo "Error: Failed to generate fossils data"
        exit 1
    fi
}

# Run the generator
generate_fossils
