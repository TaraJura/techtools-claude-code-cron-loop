# Autonomous AI PDF Editor Factory

> **This entire server is maintained autonomously by Claude Code with full sudo permissions.**
> 7 AI agents collaborate to build a professional PDF Editor web application.

## What This System Is

This is an autonomous software factory where AI agents:
1. **Generate ideas** for PDF editor features
2. **Prioritize and assign** tasks to developers
3. **Implement** features using HTML/CSS/JavaScript + PDF libraries
4. **Test** implementations for correctness
5. **Review security** of file handling and web code
6. **Supervise** the overall ecosystem health

All of this happens automatically, every 2 hours, via crontab.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN PIPELINE (Every 2 hours)                     │
│                                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │  IDEA    │─▶│   PM     │─▶│   DEV    │─▶│  DEV 2   │            │
│  │  MAKER   │  │          │  │          │  │          │            │
│  │          │  │ Assign   │  │ Build    │  │ Build    │            │
│  │ Generate │  │ tasks    │  │ features │  │ features │            │
│  │ ideas    │  │          │  │          │  │          │            │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │
│                                    │              │                  │
│                                    ▼              ▼                  │
│                         ┌──────────────────────────────┐            │
│                         │  /var/www/cronloop.techtools.cz/          │
│                         │  PDF Editor Web Application  │            │
│                         └──────────────┬───────────────┘            │
│                                        │                            │
│  ┌──────────┐  ┌──────────┐           │                            │
│  │ SECURITY │◀─│  TESTER  │◀──────────┘                            │
│  │          │  │          │                                         │
│  │ Review   │  │ Verify   │                                         │
│  │ code     │  │ features │                                         │
│  └──────────┘  └──────────┘                                         │
│       │              │                                               │
│       └──────────────┴─────────▶ tasks.md ──▶ GitHub                │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    SUPERVISOR (Every 2 hours at :15)                  │
│                                                                      │
│              ┌───────────────────────────────────┐                   │
│              │          SUPERVISOR                │                   │
│              │                                    │                   │
│              │  • Monitor all agents              │                   │
│              │  • Check system health             │                   │
│              │  • Fix issues conservatively       │                   │
│              │  • Track project progress          │                   │
│              └───────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────┘
```

## How It Works

### The Loop

Every 2 hours, `cron-orchestrator.sh` runs:
1. **idea-maker** reads the backlog, proposes a new PDF editor feature
2. **project-manager** assigns an unassigned task to a developer
3. **developer** picks up a task and implements it in the web app
4. **developer2** does the same in parallel
5. **tester** verifies a completed task (loads https://cronloop.techtools.cz/ in headless Chrome via the `chrome-devtools` MCP, fails on any app-origin console error, and uploads `/home/novakj/test-fixtures/example.pdf` to verify the upload pipeline still works end-to-end)
6. **security** reviews code for vulnerabilities (especially file upload handling)

After each agent, changes are committed to GitHub automatically.

### The Product

The agents are building a PDF editor at https://cronloop.techtools.cz with features like:
- PDF viewing and navigation
- Annotations (highlight, underline, comments)
- Merge and split PDFs
- Page reorder, rotate, delete
- Form filling
- Digital signatures
- OCR text extraction
- Format conversion

### Self-Improvement

When an agent makes a mistake:
1. The tester catches it and marks the task FAILED
2. The developer reads the feedback and fixes the issue
3. The agent's prompt gets updated to prevent the same mistake
4. The system becomes permanently smarter

## Why a PDF Editor?

A PDF editor is a substantial, real-world web application that:
- Has clear, well-defined features to implement
- Requires significant frontend engineering
- Involves file handling security challenges
- Can be incrementally built feature by feature
- Is useful to actual users
- Demonstrates the factory's capability to build real products
