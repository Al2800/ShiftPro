# ShiftPro Project - Agent Instructions

## Skills (MUST READ)

Before starting work, read these skill documents:

1. **Beads** (Task Management): ~/.claude/skills/beads/SKILL.md
2. **Agent Mail** (Coordination): ~/.claude/skills/agent-mail/SKILL.md

## Multi-Agent Workflow

### Session Start
1. Register with agent-mail using project_key="/home/agent/projects/shift-app"
2. Check inbox for pending messages
3. Run `bd ready --json` to see available tasks

### Before Working
1. Check `bd list --status in_progress --json` - skip tasks already claimed
2. Claim your task: `bd update <id> --status in_progress --json`
3. Reserve files via agent-mail before editing

### After Completing Work
1. Add detailed comment: `bd comment <id> "IMPLEMENTATION: ..."`
2. Close the bead: `bd close <id> -r "Summary"`
3. Release file reservations
4. Check inbox before picking next task

## Project Context

ShiftPro is an iOS app for shift workers. Key directories:
- ShiftPro/ - Main app code
- ShiftProCore/ - Core functionality
- ShiftProTests/ - Unit tests
