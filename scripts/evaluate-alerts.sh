#!/bin/bash
# Alert Rules Evaluator - Evaluates alert rules against current metrics
# Part of CronLoop Alert Rules Builder (TASK-073)

set -e

# Paths
API_DIR="/var/www/cronloop.techtools.cz/api"
RULES_FILE="$API_DIR/alert-rules.json"
METRICS_FILE="$API_DIR/system-metrics.json"
SECURITY_FILE="$API_DIR/security-metrics.json"
COSTS_FILE="$API_DIR/costs.json"
ERRORS_FILE="$API_DIR/error-patterns.json"

# Ensure rules file exists
if [[ ! -f "$RULES_FILE" ]]; then
    echo '{"rules":[],"alertHistory":[],"lastUpdated":null,"lastEvaluated":null}' > "$RULES_FILE"
    echo "Created empty rules file"
    exit 0
fi

# Run evaluation with Python for JSON handling
python3 << 'PYTHON_SCRIPT'
import json
import os
from datetime import datetime, timedelta

API_DIR = "/var/www/cronloop.techtools.cz/api"

def load_json(filename):
    """Load JSON file safely"""
    path = os.path.join(API_DIR, filename)
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except:
        return {}

def get_current_metrics():
    """Gather all current metrics for evaluation"""
    metrics = {}

    # System metrics
    sys_data = load_json('system-metrics.json')
    if sys_data:
        disks = sys_data.get('disk', [])
        metrics['disk_percent'] = disks[0].get('percent', 0) if disks else 0
        metrics['memory_percent'] = sys_data.get('memory', {}).get('percent', 0)
        metrics['cpu_load'] = sys_data.get('cpu', {}).get('load_1m', 0)

    # Security metrics
    sec_data = load_json('security-metrics.json')
    if sec_data:
        ssh_attacks = sec_data.get('ssh_attacks', {})
        metrics['ssh_attempts'] = ssh_attacks.get('total_attempts', 0)
        metrics['unique_attackers'] = ssh_attacks.get('unique_ips', 0)

    # Cost metrics
    cost_data = load_json('costs.json')
    if cost_data:
        metrics['daily_cost'] = cost_data.get('summary', {}).get('total_cost_usd', 0)
        metrics['total_tokens'] = cost_data.get('aggregate', {}).get('total_tokens', 0)

    # Error metrics
    err_data = load_json('error-patterns.json')
    if err_data:
        by_agent = err_data.get('by_agent', {})
        metrics['agent_errors'] = sum(a.get('error_count', 0) for a in by_agent.values())

    return metrics

def evaluate_condition(condition, metrics):
    """Evaluate a single condition against metrics"""
    metric_name = condition.get('metric')
    operator = condition.get('operator')
    threshold = condition.get('value')

    if metric_name not in metrics:
        return False

    value = metrics[metric_name]

    if operator == '>':
        return value > threshold
    elif operator == '<':
        return value < threshold
    elif operator == '>=':
        return value >= threshold
    elif operator == '<=':
        return value <= threshold
    elif operator == '==':
        return value == threshold
    elif operator == '!=':
        return value != threshold

    return False

def evaluate_conditions(conditions, operator, metrics):
    """Evaluate all conditions with AND/OR logic"""
    if not conditions:
        return False

    results = [evaluate_condition(c, metrics) for c in conditions]

    if operator == 'OR':
        return any(results)
    else:  # AND
        return all(results)

def main():
    # Load rules
    rules_data = load_json('alert-rules.json')
    rules = rules_data.get('rules', [])
    alert_history = rules_data.get('alertHistory', [])

    if not rules:
        print("No alert rules configured")
        return

    # Get current metrics
    metrics = get_current_metrics()
    now = datetime.utcnow()
    now_iso = now.isoformat() + 'Z'

    triggered_count = 0
    resolved_count = 0

    # Evaluate each rule
    for rule in rules:
        if not rule.get('enabled', True):
            continue

        # Check if snoozed
        snoozed_until = rule.get('snoozedUntil')
        if snoozed_until:
            try:
                snooze_time = datetime.fromisoformat(snoozed_until.replace('Z', '+00:00'))
                if snooze_time.replace(tzinfo=None) > now:
                    continue
                else:
                    rule['snoozedUntil'] = None
            except:
                pass

        was_triggered = rule.get('triggered', False)
        conditions = rule.get('conditions', [])
        logical_op = rule.get('logicalOperator', 'AND')
        duration = rule.get('duration', 0)

        is_triggered = evaluate_conditions(conditions, logical_op, metrics)

        # Handle duration requirement
        if duration > 0 and is_triggered:
            triggered_since = rule.get('triggeredSince')
            if not triggered_since:
                rule['triggeredSince'] = now_iso
                is_triggered = False  # Not triggered until duration passes
            else:
                try:
                    start_time = datetime.fromisoformat(triggered_since.replace('Z', '+00:00'))
                    elapsed = (now - start_time.replace(tzinfo=None)).total_seconds()
                    is_triggered = elapsed >= duration
                except:
                    rule['triggeredSince'] = now_iso
                    is_triggered = False
        else:
            if not is_triggered:
                rule['triggeredSince'] = None

        rule['triggered'] = is_triggered

        if is_triggered:
            triggered_count += 1

            # Add to history if newly triggered
            if not was_triggered:
                alert_history.insert(0, {
                    'ruleId': rule.get('id'),
                    'ruleName': rule.get('name'),
                    'severity': rule.get('severity'),
                    'triggeredAt': now_iso,
                    'resolved': False,
                    'metrics': {k: metrics.get(k) for k in [c['metric'] for c in conditions]}
                })
        elif was_triggered:
            resolved_count += 1
            # Mark as resolved in history
            for entry in alert_history:
                if entry.get('ruleId') == rule.get('id') and not entry.get('resolved'):
                    entry['resolved'] = True
                    entry['resolvedAt'] = now_iso
                    break

    # Keep only last 50 history entries
    alert_history = alert_history[:50]

    # Save updated rules
    rules_data['rules'] = rules
    rules_data['alertHistory'] = alert_history
    rules_data['lastEvaluated'] = now_iso

    with open(os.path.join(API_DIR, 'alert-rules.json'), 'w') as f:
        json.dump(rules_data, f, indent=2)

    print(f"Alert evaluation completed: {triggered_count} triggered, {resolved_count} resolved")

    # Return status for action processor
    if triggered_count > 0:
        print(f"WARNING: {triggered_count} alert(s) currently triggered!")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

echo "Alert evaluation script completed"
