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
   one lesson + practice stub + check script. See "Phase 2" below.

<!-- Phase 1 and Phase 2 sections are added by later tasks. -->

## Reference

<!-- Links to reference/*.md are added by later tasks. -->
