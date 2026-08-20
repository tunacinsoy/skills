# teach-from-scratch

A [Claude Code](https://claude.com/claude-code) skill that turns a finished project into a
hands-on curriculum for rebuilding it yourself — no AI in the loop for the actual practice
work.

Point it at any repo. It reads the code and the git history, breaks the build into real
phases, and produces a numbered set of lessons plus a practice workspace. Each lesson shows
you the real original code as the teaching example — the syntax, the algorithmic decisions,
*why this way and not another way* — then sends you off to rebuild that phase from scratch,
blind, checked by a behavioral test rather than a line-by-line diff.

The point is to close the gap between "I used an AI to build this" and "I could build this
again myself."

## Why

It's easy to ship something you didn't fully understand when an AI wrote most of it. This
skill is a deliberate corrective: it doesn't explain the codebase to you passively, it makes
you reproduce each piece of it yourself before telling you how close you got. The check on
each exercise verifies *behavior*, not text similarity, so a correct-but-differently-written
solution still passes — the goal is understanding, not memorization.

## How it works

Two phases, with a hard stop in between:

1. **Analysis & Outline.** Reads the target repo's structure and clusters its git history
   into natural build phases (not a fixed template — the phase count and boundaries come
   from how the project was actually built). Writes an outline and **stops** for your
   approval before generating anything.
2. **Lesson Generation.** Once you approve the outline, one fresh subagent per phase writes
   that phase's lesson, a practice stub, and a behavioral check script — each subagent sees
   only its own phase, so lesson quality doesn't degrade for later chapters the way it would
   in a single long pass.

Every lesson follows the same four-part shape: **Concept** (why this phase exists), **Walkthrough**
(the real original code, explained), **Exercise** (rebuild it blind), **Check** (run the
behavioral test).

### Reference checks are behavioral, not textual

A generated check never grades you on how closely your code matches the original's text —
it runs your implementation and asserts on observable behavior (output, exit codes, side
effects), then offers a literal diff afterward purely as a study aid, never as the grade.

For phases whose original code has real side effects — installers, dotfile writers, package
managers — the check never executes the dangerous path against your actual machine. It either
isolates the testable decision logic and stubs the dangerous calls, or runs your code inside a
scratch `$HOME`/working directory so nothing real gets touched. This mechanism went through
multiple rounds of adversarial review with live execution proof before being trusted (see
`reference/check-generation.md` if you want the details).

## Installation

This skill lives in [tunacinsoy/skills](https://github.com/tunacinsoy/skills) — see that
repo's README for how to install it (as a Claude Code plugin, or by symlinking this
directory directly into `~/.claude/skills/`).

## Usage

From inside the repo you want to turn into a curriculum:

```
/teach-from-scratch
```

or just ask for it in conversation — "teach me to rebuild this from scratch." Claude will
ask what baseline to assume (a generalist new to this stack, or a true beginner), then run
the two-phase flow described above.

### Output

Everything lands inside the target project's own repo:

```
docs/curriculum/
  OUTLINE.md          # the approved Phase 1 artifact, kept for reference
  00-index.md          # how the curriculum works + a linear reading order
  01-<phase-slug>.md
  02-<phase-slug>.md
  ...
practice/
  01-<phase-slug>/
    check.sh
    ...               # your stub files go here
  02-<phase-slug>/
    check.sh
    ...
```

Commit it, gitignore it, or delete it when you're done — it's not required by anything else
in the project.

## Requirements

- [Claude Code](https://claude.com/claude-code) (or another agent runtime that reads
  `~/.claude/skills/`).
- No other dependencies. Lesson generation dispatches subagents in parallel where the
  harness supports it, and falls back to sequential dispatch otherwise — either way works.

## Directory layout

```
SKILL.md                              # the skill itself — entry point Claude Code reads
reference/
  outline-format.md                   # Phase 1's output contract
  lesson-template.md                  # the 4-part lesson structure
  dispatch-prompt-template.md         # the Phase 2 subagent dispatch prompt
  check-generation.md                 # behavioral check rules, including the safety design
tests/fixtures/build-toy-counter.sh   # a small toy project used to exercise the skill end-to-end
```

## Status

Built and validated end-to-end against a toy fixture project. Not yet run against a large
real-world codebase — if you try it on one, feedback on where the phase-clustering or
check-generation logic breaks down is welcome.
