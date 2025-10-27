# Xuan Gong (玄功) - Martial Arts Training App

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
├── app/               (Flutter application)
└── backend/           (Go API server)
```

## Development Approach

Building iteratively with focus on core training loop first:
1. Get timer working perfectly
2. Add video submission
3. Implement feedback system
4. Enhance with additional features

Remember: This is not a generic fitness app. Every feature should serve the specific needs of traditional martial arts practice.
