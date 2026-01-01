# ShiftPro - Agent Instructions

## Project Overview

**ShiftPro** is an iOS app for shift workers to manage schedules, track hours, and sync with calendars.

### Tech Stack
- **Platform:** iOS 17.0+
- **UI:** SwiftUI
- **Data:** SwiftData + CloudKit (optional sync)
- **Architecture:** MVVM + Clean Architecture
- **Key Frameworks:** EventKit, StoreKit 2, UserNotifications, LocalAuthentication, TipKit

### Core Features
1. **Shift Management** - Create, edit, track shifts with patterns (weekly/rotating)
2. **Calendar Integration** - Two-way sync with iOS Calendar via EventKit
3. **Hours Tracking** - Pay period calculations with rate multipliers (1.0x, 1.3x, 1.5x, 2.0x)
4. **Patterns** - Support for rotating rosters (4-on/2-off, Pitman, etc.)
5. **Export** - CSV, ICS, PDF, JSON backup

### Key Data Models
- `UserProfile` - User settings, pay rules, base rate
- `ShiftPattern` - Weekly or cycling shift patterns
- `Shift` - Individual shift instances with actual/scheduled times
- `PayPeriod` - Aggregated hours and estimated pay
- `PayRuleset` - Configurable rules (unpaid breaks, multipliers)
- `CalendarEvent` - EventKit sync mapping

### Architecture Layers
```
Presentation  → SwiftUI Views, ViewModels
Business      → Use Cases, Domain Models
Data          → Repositories, SwiftData
Infrastructure → CloudKit, EventKit, StoreKit
```

### Important Files (to be created)
- `/ShiftPro/Models/SwiftDataModels.swift` - Data models
- `/ShiftPro/Services/ShiftManager.swift` - Business logic
- `/ShiftPro/Services/CalendarIntegrationService.swift` - EventKit
- `/ShiftPro/Views/DashboardView.swift` - Main UI
- `/ShiftPro/Repositories/ShiftRepository.swift` - Data access

### Reference Documents
- `ARCHITECTURE_PLAN.md` - Full technical specification

---

## Beads Workflow

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds


<!-- bv-agent-instructions-v1 -->

---

## Beads Workflow Integration

This project uses [beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) for issue tracking. Issues are stored in `.beads/` and tracked in git.

### Essential Commands

```bash
# View issues (launches TUI - avoid in automated sessions)
bv

# CLI commands for agents (use these instead)
bd ready              # Show issues ready to work (no blockers)
bd list --status=open # All open issues
bd show <id>          # Full issue details with dependencies
bd create --title="..." --type=task --priority=2
bd update <id> --status=in_progress
bd close <id> --reason="Completed"
bd close <id1> <id2>  # Close multiple issues at once
bd sync               # Commit and push changes
```

### Workflow Pattern

1. **Start**: Run `bd ready` to find actionable work
2. **Claim**: Use `bd update <id> --status=in_progress`
3. **Work**: Implement the task
4. **Complete**: Use `bd close <id>`
5. **Sync**: Always run `bd sync` at session end

### Key Concepts

- **Dependencies**: Issues can block other issues. `bd ready` shows only unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers, not words)
- **Types**: task, bug, feature, epic, question, docs
- **Blocking**: `bd dep add <issue> <depends-on>` to add dependencies

### Session Protocol

**Before ending any session, run this checklist:**

```bash
git status              # Check what changed
git add <files>         # Stage code changes
bd sync                 # Commit beads changes
git commit -m "..."     # Commit code
bd sync                 # Commit any new beads changes
git push                # Push to remote
```

### Best Practices

- Check `bd ready` at session start to find available work
- Update status as you work (in_progress → closed)
- Create new issues with `bd create` when you discover tasks
- Use descriptive titles and set appropriate priority/type
- Always `bd sync` before ending session

<!-- end-bv-agent-instructions -->


---

## Commit Discipline (Multi-Agent)

When multiple agents share the same working tree, commit discipline prevents confusion.

### Core Rules

1. **Commit frequently, not just at task end**
   - Commit after each logical change (file created, function added, bug fixed)
   - Other agents see progress, not mystery uncommitted files

2. **Pull before editing any file you didn't create**
   ```bash
   git pull --rebase
   ```

3. **All work on main branch**
   - No feature branches, no worktrees
   - Use advisory file reservations via agent-mail to avoid conflicts

4. **Conventional commit format**
   ```
   type(scope): description
   
   [optional body]
   
   Refs: <bead-id>
   ```
   Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

5. **Push immediately after committing**
   - Don't leave commits sitting locally
   - Other agents need to see your changes

### If You See Uncommitted Changes You Didn't Make

- Check `git log` to see recent commits
- Check agent-mail for who's working on what
- Ask before modifying files with uncommitted changes from others

### Commit Prompts

See `command_palette.md` for detailed commit prompts:
- `git_commit` - Detailed multi-file commit
- `git_commit_wip` - Quick WIP checkpoint
- `git_selective_commit` - Group changes by area
- `git_error_checkpoint` - Record lint/type error counts

### Full Git Workflow Guide

For comprehensive multi-agent git patterns, commit agent setup, and troubleshooting:
→ [git-multi-agent-workflow.md](~/clawd/docs/git-multi-agent-workflow.md)
