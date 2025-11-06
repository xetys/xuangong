# Xuan Gong (玄功) - Martial Arts Training App

---

## ⚠️ MANDATORY STARTUP SEQUENCE ⚠️

**BEFORE responding to ANY user request, you MUST:**

1. **Load TODOs** - Read and parse `.claude/todos.json` and load into TodoWrite tool
2. **Read Context** - Review `.claude/tasks/context/recent-work.md` to understand recent changes
3. **Check Agents** - Determine if this request requires agent consultation (see Agent Policy below)

---

## 🤖 AGENT USAGE POLICY (STRICT)

**Agents are for PLANNING and RESEARCH ONLY. They MUST NOT implement changes.**

### When to Use Agents (AUTOMATIC TRIGGERS)

**Use `go-backend-architect` agent when:**
- Any Go code changes in `backend/` directory
- Database schema or migration work
- API endpoint design or modification
- Backend testing or test structure
- Performance optimization of Go code

**Use `flutter-dev-expert` agent when:**
- Any Dart/Flutter code changes in `app/` directory
- UI/UX implementation or modification
- State management decisions
- Widget architecture or layout
- Platform-specific features

**Use `Explore` agent when:**
- Broad codebase exploration needed
- Understanding how systems connect
- Finding all instances of a pattern
- Architectural understanding

### Agent Workflow

1. **IDENTIFY** - Does request match agent triggers above?
2. **CONSULT** - If yes, launch appropriate agent for plan/research
3. **REVIEW** - Wait for agent's plan/findings
4. **IMPLEMENT** - Main Claude executes the implementation
5. **DOCUMENT** - Update session logs and context

**Agents can:**
- ✅ Read files, search code, gather information
- ✅ Create implementation plans and recommendations
- ✅ Use readonly tools (Read, Glob, Grep, WebFetch)

**Agents cannot:**
- ❌ Edit or write files
- ❌ Run commands that modify state
- ❌ Implement changes directly

---

## Project Context

Xuan Gong is a specialized training application for the Xuan Gong Fu Academy in Berlin, a school teaching Wudang internal martial arts (Tai Chi, Ba Gua Zhang, Xing Yi Quan, Qi Gong). The app replaces generic interval timers with a purpose-built solution for traditional martial arts practice.

## Problem We're Solving

Currently, students in the academy's intensive programs receive personalized training routines that they practice alone. They use generic fitness timer apps and WhatsApp for feedback. This app provides:
- Specialized timer for martial arts exercises
- Video submission system for form corrections
- Progress tracking for long-term goals
- Direct instructor-student feedback loop

## Core User Flows

### Student Journey
1. Receives assigned training program from instructor
2. Practices daily using guided timer with audio cues
3. Records videos of their form during practice
4. Submits videos for instructor feedback
5. Reviews corrections and improves
6. Tracks progress over time

### Instructor Journey
1. Creates training programs from exercise library
2. Assigns programs to individual students
3. Reviews submitted practice videos
4. Provides corrective feedback
5. Monitors student progress and consistency

## Design Philosophy

### Martial Arts Principles
- **Simplicity**: Interface should not distract from practice
- **Discipline**: Features should encourage consistent daily training
- **Precision**: Timing must be exact for meditation and form work
- **Tradition**: Respect the cultural context while using modern technology

### Visual Identity
- Primary color: #9B1C1C (dark burgundy from Xuan Gong Fu Academy)
- Minimalist, clean aesthetic inspired by Chinese ink painting
- Generous whitespace for visual breathing room
- Focus on readability during physical practice

## Technical Decisions

### Backend: Go + PostgreSQL
- Go for performance and simplicity
- PostgreSQL for flexible data modeling
- JWT authentication
- RESTful API design

### Frontend: Flutter
- Cross-platform (iOS/Android) from single codebase
- Excellent timer/audio capabilities
- Good offline support
- Material Design base with custom theming

## Feature Scope

### MVP (Phase 1)
- User authentication (admin/student roles)
- Program management (CRUD operations)
- Exercise timer with audio cues
- Basic video upload
- Text-based feedback
- Practice logging

### Near Future (Phase 2)
- Wuwei mode (distraction-free timer)
- Progress calendar
- Offline mode with sync
- Video compression

### Vision (Phase 3+)
- Form analysis with AI
- Live streaming classes
- Multi-language support (German, English, Chinese)
- Wearable integration
- Social features

## Important Constraints

### Offline-First
Many students practice in spaces without reliable internet. The app must:
- Work completely offline for timer functions
- Cache programs locally
- Queue uploads for when connection returns
- Never lose practice data

### Audio Precision
Audio cues are critical for meditation and form work:
- 3-beep countdown before exercise starts
- Bell at 50% completion
- Gong at exercise end
- Must be frame-accurate, no delays

## User Personas

### Student: Li Wei
- Full-time martial arts student
- Practices 4-6 hours daily
- Needs reliable timer and clear feedback
- Values simplicity and focus

### Instructor: Stefan Müller  
- Teaches 20+ students
- Creates individualized programs
- Reviews 10-15 videos daily
- Needs efficient workflow

## Success Metrics
- Students complete daily practice consistently
- Instructors spend less time on administrative tasks
- Video feedback turnaround under 24 hours
- Zero data loss from offline practice

## Project Structure
```
xuangong/
├── CLAUDE.md          (this file)
├── .claude/           (Claude Code configuration)
│   ├── tasks/         (Session and context tracking)
│   │   ├── sessions/  (Conversation session logs)
│   │   └── context/   (Quick reference context files)
│   └── settings.local.json
├── app/               (Flutter application)
└── backend/           (Go API server)
```


## Session & Context Management

### Context Files
- `.claude/tasks/context/recent-work.md` - Rolling log of recent changes
- `.claude/tasks/context/decisions.md` - Architectural and technical decisions
- `.claude/tasks/context/features.md` - Feature documentation
- `.claude/tasks/sessions/` - Individual session logs

### Session Documentation

After significant work or at session end:
1. **Update session file** - Document what was accomplished, decisions made, files changed
2. **Update `recent-work.md`** - Add latest changes to rolling log
3. **Update `decisions.md`** - Record any architectural or technical decisions
4. **Update `features.md`** - Document new features or significant changes

Session files use naming format: `YYYY-MM-DD_topic-slug.md`

See `.claude/tasks/README.md` for detailed documentation.

## Development Approach

Building iteratively with focus on core training loop first:
1. Get timer working perfectly
2. Add video submission
3. Implement feedback system
4. Enhance with additional features

Remember: This is not a generic fitness app. Every feature should serve the specific needs of traditional martial arts practice.
