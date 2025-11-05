# Claude Code Task & Session Tracking System

This directory contains session logs and context files to help Claude Code (and developers) maintain context across conversations and understand the project state.

---

## Directory Structure

```
.claude/tasks/
├── README.md           # This file - system documentation
├── sessions/           # Conversation session logs
│   └── YYYY-MM-DD_topic-slug.md
└── context/            # Quick reference context files
    ├── architecture.md # Tech stack and patterns
    ├── features.md     # Feature catalog
    ├── recent-work.md  # Last 10 changes (rolling log)
    └── decisions.md    # Architectural decision records
```

---

## Purpose

### Why This System Exists

1. **Context Preservation**: Claude Code sessions have token limits. Context files ensure important information isn't lost.
2. **Onboarding**: New team members (or new Claude sessions) can quickly understand the project.
3. **Decision History**: Track why architectural choices were made.
4. **Work Tracking**: Know what was done recently and what's next.

### Who Uses This

- **Claude Code**: Reads context before starting work
- **Developers**: Understand project structure and decisions
- **New Team Members**: Onboarding reference
- **Future You**: Remember why you made certain choices

---

## File Descriptions

### Context Files (Always Up-to-Date)

#### `context/architecture.md`
**Purpose**: Technical foundation and patterns
**Contents**:
- Tech stack (Flutter, Go, PostgreSQL, K8s)
- Architectural patterns (singletons, conditional imports)
- Deployment architecture
- Background processing approach
- Security considerations

**When to Read**: New to project, making architectural changes, onboarding

**When to Update**: Adding new tech, changing patterns, deployment changes

---

#### `context/features.md`
**Purpose**: What exists and where to find it
**Contents**:
- Complete feature catalog
- Implementation status (✅/⏳)
- File locations for each feature
- Quick reference table

**When to Read**: Looking for existing functionality, before implementing features

**When to Update**: New features added, features modified significantly

---

#### `context/recent-work.md`
**Purpose**: Rolling log of recent changes
**Contents**:
- Last 10 significant changes (most recent first)
- Files modified per change
- Deployment status
- Known issues
- Next steps

**When to Read**: ALWAYS - Before starting any work

**When to Update**: ALWAYS - After significant work

**Maintenance**: Remove entries older than 2-3 weeks

---

#### `context/decisions.md`
**Purpose**: Why things are the way they are
**Contents**:
- Architectural Decision Records (ADR format)
- Context, decision, consequences, alternatives
- Numbered sequentially (ADR-001, ADR-002, etc.)

**When to Read**: Understanding "why", making similar decisions

**When to Update**: Making architectural/technical decisions

---

### Session Files (Historical Record)

#### `sessions/YYYY-MM-DD_topic-slug.md`
**Purpose**: Document conversation outcomes
**Contents**:
- Session metadata (date, duration, focus)
- Research and planning phases
- Implementation details
- Files created/modified
- Decisions made
- Challenges and solutions
- Next steps

**When to Create**: After significant work or major conversations

**Naming Format**: `2025-11-02_background-timer.md`
- Date: YYYY-MM-DD
- Topic: Short slug describing the work

---

## Workflows

### Context-First Workflow (Claude Code)

**Before starting ANY work**:
1. ✅ Read `context/recent-work.md` - What was done recently?
2. ✅ Check relevant session files - What happened in last conversation?
3. ✅ Consult `context/decisions.md` - What decisions were made?
4. ✅ Review `context/features.md` - What already exists?

**After significant work**:
1. ✅ Update `context/recent-work.md` - Add what you did
2. ✅ Update `context/decisions.md` - Document decisions
3. ✅ Update `context/features.md` - New features added
4. ✅ Create session file - Document the conversation

---

### Onboarding Workflow (New Developers)

**Day 1**:
1. Read `CLAUDE.md` - Project overview, philosophy, constraints
2. Read `context/architecture.md` - Technical foundation
3. Read `context/features.md` - What exists
4. Read `context/recent-work.md` - Current state

**Day 2**:
5. Read `context/decisions.md` - Understand "why"
6. Browse recent session files - See how work happens
7. Start contributing!

---

## Subagent Usage Policy (STRICT)

When using Claude Code's Task tool with Plan/Explore subagents:

### ✅ ALLOWED (Research)
- Read files
- Search code (Glob, Grep)
- Gather information
- Create implementation plans
- Analyze architecture

### ❌ FORBIDDEN (Implementation)
- Edit files
- Write files
- Run commands that modify state
- Make code changes

### Why This Policy?
- Main agent maintains full context
- Session continuity preserved
- Proper documentation of changes
- Consistent code quality
- Clear separation between research and implementation

**Exception**: Readonly tools (Read, Glob, Grep, WebFetch) always allowed.

---

## Maintenance Guidelines

### `recent-work.md` - Rolling Log
- ✅ Add entries at the top (reverse chronological)
- ✅ Keep last 10-15 entries
- ✅ Remove entries older than 2-3 weeks
- ✅ Format: Date, title, status, changes, files

### `decisions.md` - ADR Log
- ✅ Add ADRs at the bottom (sequential numbering)
- ✅ Never delete ADRs (mark as superseded instead)
- ✅ Use template provided in file
- ✅ Include context, decision, consequences, alternatives

### `features.md` - Feature Catalog
- ✅ Update status when features complete
- ✅ Add new features to appropriate section
- ✅ Keep location references accurate
- ✅ Mark planned features with ⏳

### `architecture.md` - Technical Docs
- ✅ Update when tech stack changes
- ✅ Document new patterns as they emerge
- ✅ Keep deployment info current
- ✅ Stable content (update less frequently)

### Session Files
- ✅ Create after significant work
- ✅ Include files changed, decisions made
- ✅ Never delete (historical record)
- ✅ Use date + topic naming

---

## Git Tracking

**Tracked** (committed to repository):
- ✅ `context/` - All context files
- ✅ `sessions/` - All session logs
- ✅ `README.md` - This file

**Ignored** (`.gitignore`):
- ❌ `.claude/settings.local.json` - Local permissions config

**Why Git-Tracked?**
- Team visibility
- Version control for documentation
- Onboarding resource
- Decision history preservation

---

## Examples

### Example: Starting a New Feature

```
1. Read context/recent-work.md
   → See that background timer was just added

2. Read context/features.md
   → Check if video upload already exists (it doesn't)

3. Read context/decisions.md
   → Understand how file uploads should work

4. Start work on video upload feature

5. After completion:
   → Update recent-work.md
   → Update features.md (add video upload section)
   → Create decisions.md ADR if architectural choices made
   → Create session file documenting the work
```

### Example: Investigating a Bug

```
1. Read context/recent-work.md
   → Check if related changes were made recently

2. Check relevant session file
   → Understand context of recent changes

3. Read context/architecture.md
   → Understand system architecture

4. Fix bug

5. After fix:
   → Update recent-work.md (add bug fix entry)
   → Update session file if major investigation
```

---

## Tips for Claude Code

1. **Always context-first**: Read recent-work.md before ANY work
2. **Use subagents wisely**: Research only, never implement
3. **Document decisions**: If you make a choice, add an ADR
4. **Keep recent-work current**: Update after every significant change
5. **Session files for major work**: Document conversations that result in significant changes

---

## Tips for Developers

1. **Read before coding**: Context files save time
2. **Update after merging**: Keep recent-work.md current
3. **Document decisions**: Use ADR format in decisions.md
4. **Review sessions**: Understand how AI-assisted development happened
5. **Onboard with context**: Use these files for new team members

---

## Questions?

See `CLAUDE.md` for overall project context and philosophy.

See session files in `sessions/` for examples of how this system is used.

---

*Last updated: 2025-11-02*
*System version: 1.0*
