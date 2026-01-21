#!/bin/bash
# update-process-tree.sh - Generate process tree JSON for web dashboard
# This script should be run periodically (e.g., every minute) via cron

OUTPUT_FILE="/var/www/cronloop.techtools.cz/api/process-tree.json"

# Get process list with detailed info
# Using ps with custom format to get all needed fields
ps_output=$(ps -eo pid,ppid,user,stat,%cpu,%mem,vsz,rss,lstart,time,comm,args --sort=-pcpu 2>/dev/null)

# Parse process data into JSON
python3 << 'PYTHON_SCRIPT'
import json
import subprocess
import sys
from datetime import datetime

def get_process_list():
    """Get process list using ps command"""
    try:
        result = subprocess.run(
            ['ps', '-eo', 'pid,ppid,user,stat,%cpu,%mem,vsz,rss,lstart,time,comm,args', '--sort=-pcpu'],
            capture_output=True, text=True
        )
        lines = result.stdout.strip().split('\n')
        if len(lines) < 2:
            return []

        processes = []
        header = lines[0]

        for line in lines[1:]:
            # Parse each line - lstart takes up multiple columns
            parts = line.split()
            if len(parts) < 12:
                continue

            try:
                pid = int(parts[0])
                ppid = int(parts[1])
                user = parts[2]
                state = parts[3]
                cpu = float(parts[4])
                mem = float(parts[5])
                vsz = int(parts[6])
                rss = int(parts[7])
                # lstart is like "Mon Jan 20 15:30:00 2026" - 5 fields
                start_parts = parts[8:13]
                start_time = ' '.join(start_parts)
                cpu_time = parts[13]
                comm = parts[14]
                # args is everything after comm
                args = ' '.join(parts[15:]) if len(parts) > 15 else comm

                processes.append({
                    'pid': pid,
                    'ppid': ppid,
                    'user': user,
                    'state': state,
                    'cpu': cpu,
                    'mem': mem,
                    'vsz': vsz,
                    'rss': rss,
                    'start_time': start_time,
                    'cpu_time': cpu_time,
                    'name': comm,
                    'command': args[:500]  # Limit command length
                })
            except (ValueError, IndexError):
                continue

        return processes
    except Exception as e:
        print(f"Error getting process list: {e}", file=sys.stderr)
        return []

def build_tree(processes):
    """Build hierarchical tree from flat process list"""
    by_pid = {}
    for p in processes:
        by_pid[p['pid']] = {**p, 'children': []}

    roots = []
    for p in processes:
        node = by_pid[p['pid']]
        if p['ppid'] in by_pid:
            by_pid[p['ppid']]['children'].append(node)
        else:
            roots.append(node)

    return roots

def calculate_stats(processes):
    """Calculate summary statistics"""
    stats = {
        'total_processes': len(processes),
        'running': 0,
        'sleeping': 0,
        'zombie': 0,
        'stopped': 0,
        'total_cpu': 0.0,
        'total_mem': 0.0
    }

    for p in processes:
        state = p.get('state', '')
        if state.startswith('R'):
            stats['running'] += 1
        elif state.startswith('S') or state.startswith('I'):
            stats['sleeping'] += 1
        elif state.startswith('Z'):
            stats['zombie'] += 1
        elif state.startswith('T'):
            stats['stopped'] += 1

        stats['total_cpu'] += p.get('cpu', 0)
        stats['total_mem'] += p.get('mem', 0)

    return stats

def main():
    processes = get_process_list()
    tree = build_tree(processes)
    stats = calculate_stats(processes)

    output = {
        'timestamp': datetime.now().isoformat(),
        'stats': stats,
        'tree': tree,
        'processes': processes  # Also include flat list for searching
    }

    # Write to file
    output_file = '/var/www/cronloop.techtools.cz/api/process-tree.json'
    try:
        with open(output_file, 'w') as f:
            json.dump(output, f, indent=2)
        print(f"Process tree updated: {stats['total_processes']} processes")
    except Exception as e:
        print(f"Error writing output: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
PYTHON_SCRIPT
