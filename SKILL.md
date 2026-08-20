---
name: teach-from-scratch
description: Use when a finished project should become a linear, hands-on curriculum that teaches a developer to rebuild it from scratch without AI assistance — for internalizing the algorithmic decisions, syntax, and reasoning behind an existing codebase, not just reading it.
---

# Teach From Scratch

## Overview

Turns a finished project into a numbered series of lessons plus a practice
workspace, so a learner can rebuild it phase by phase and actually
internalize the decisions behind it — not just read about them. Each lesson
shows the real original code as the teaching example, then sends the learner
off to reproduce that phase from scratch, blind, checked by a behavioral
test rather than a text diff.

## When to Use

- A finished project (yours or someone else's) needs to become a teaching
  curriculum for a junior developer.
- Someone wants to internalize *how* a codebase was built, not just read it —
  the syntax, the algorithmic decisions, the reasoning at each step.
- Explicitly requested: "make a lesson series for this", "teach me to rebuild
  this from scratch", "turn this into a curriculum".

Not for: live pairing/tutoring in the moment, or auto-grading code style —
see the design spec's Non-goals if asked why.

## Baseline Level

Before starting Phase 1, ask the operator which baseline the lessons should
assume:

- **Competent generalist, new to this stack** — assume general programming
  fundamentals; teach this stack's syntax/idioms from scratch. (default)
- **True beginner** — also build up general programming concepts as they
  come up, not just this project's specifics.

Carry the answer through both phases below.

## Two-Phase Flow

1. **Phase 1 — Analysis & Outline.** One pass, inline, over the target
   repo's structure and git history. Produces an outline artifact. Stop and
   get operator approval before Phase 2. See "Phase 1" below.
2. **Phase 2 — Lesson Generation.** One fresh subagent per approved phase,
   dispatched per `superpowers:dispatching-parallel-agents`, each writing
   whatever `reference/dispatch-prompt-template.md` currently asks for
   (today: a lesson + practice stub; that template is the source of truth
   for the exact deliverable list, including whether a check script is
   part of it). See "Phase 2" below.

## Phase 1: Analysis & Outline

Read, in this order:
1. The target repo's file tree and top-level structure.
2. `git log --oneline --stat` (or equivalent) to find clusters of
   consecutive commits touching the same area — these become phase
   candidates. Read full commit bodies only within a cluster you're
   already investigating.
3. Existing tests/docs, if present, for extra grounding.

If the history is too thin, squashed, or missing to derive real phases,
fall back to deriving phases from the final codebase's structure and
internal dependency order alone, and say so in the outline's
`**Derived from**` line.

Write the outline following `reference/outline-format.md` exactly, save it
to `docs/curriculum/OUTLINE.md`, and **stop** — present it to the operator
and wait for approval before touching Phase 2.

## Phase 2: Lesson Generation

Only after the operator has approved `docs/curriculum/OUTLINE.md`: for each
phase in the outline, dispatch one fresh subagent using
`reference/dispatch-prompt-template.md`, filling in that phase's fields
from the outline. Dispatch phases in parallel where the harness supports it
(`superpowers:dispatching-parallel-agents`) — phases don't depend on each
other's generation, only on the shared outline.

After all lessons are generated, write `docs/curriculum/00-index.md`: a
short preamble explaining the mechanic (open-book lesson → closed-book
exercise → behavioral check → diff available afterward as a study aid
only) plus a linear list linking every lesson in order.

## Output Layout

Inside the target project's repo:

```
docs/curriculum/
  OUTLINE.md          # Phase 1 artifact, kept after Phase 2 for reference
  00-index.md
  01-<phase-slug>.md
  02-<phase-slug>.md
  ...
practice/
  01-<phase-slug>/
    check.sh
    ... (learner stub files)
  02-<phase-slug>/
    check.sh
    ...
```

Lesson and practice-directory numbering matches the outline's phase order.

## Reference

- `reference/outline-format.md` — the Phase 1 output contract
- `reference/lesson-template.md` — the 4-part structure every lesson follows
- `reference/dispatch-prompt-template.md` — the Phase 2 subagent dispatch prompt
