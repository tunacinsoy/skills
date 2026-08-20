# teach-from-scratch: design spec

## Problem

After finishing a project (often with heavy AI assistance), a developer hasn't
necessarily internalized the algorithmic decisions, syntax, or reasoning that
went into it. This skill turns a *finished* project into a linear, hands-on
curriculum that teaches a junior developer to rebuild it from scratch — no AI
tool involved in doing the actual practice work — in the voice of a senior
engineer giving a focused 1:1.

## Goals

- Given any finished project's repo, produce a linear series of markdown
  lessons plus a practice workspace that lets a learner rebuild the project
  phase by phase.
- Ground every lesson in what the project's real code and history actually
  did — not a generic template for "how to build an X."
- Force real recall: each lesson shows the real code as the teaching example,
  then requires the learner to reproduce that phase from scratch, blind,
  before revealing how close they got.
- Make the check for "did you get it right" behavioral, not textual, so
  valid alternative implementations aren't penalized.
- Work safely on projects whose code has real side effects (installers,
  system-config scripts) without ever executing anything dangerous.

## Non-goals

- Not a live pairing/tutoring mode — this generates static artifacts the
  learner works through on their own.
- Not an auto-grader that scores style or idiom quality — checks are pass/fail
  on observable behavior only.
- Not responsible for teaching general programming fundamentals unless the
  operator explicitly selects the "true beginner" baseline for a given run.

## Invocation

A personal skill at `~/.claude/skills/teach-from-scratch/SKILL.md`, invoked
as `/teach-from-scratch` (or via natural-language request) from within the
target project's repo. It is stack-agnostic: language-specific teaching
content comes from Claude's own knowledge when a lesson is written, not from
hardcoded per-language templates.

At invocation, the skill asks the operator for the learner's baseline level
for this run:

- **Competent generalist, new to this stack** — assume general programming
  fundamentals, teach this stack's syntax/idioms from scratch.
- **True beginner** — also build up general programming concepts.

This selection is threaded through both phases below.

## Phase 1 — Analysis & Outline

Runs as a single Claude pass in the main conversation (not subagents — this
step needs the whole shape of the project in view at once, which per-lesson
subagents in Phase 2 deliberately won't have).

Inputs:
- Final codebase structure and file tree.
- `git log`, clustered by feature/directory rather than read commit-by-commit
  — consecutive commits touching the same area are grouped into one phase
  candidate. For large histories, cluster before reading commit bodies in
  full.
- Existing tests/docs, if present.

Fallback: if history is too thin, squashed, or missing to derive real build
phases, Phase 1 falls back to deriving phases from the final codebase's
structure and internal dependency order alone, and the outline says so
explicitly so the operator knows the phases are inferred, not historical.

Output: a **lesson outline** — an ordered list of phases, each with:
- A one-paragraph description of what it teaches.
- The files/commits that ground it.
- A note on whether this phase involves real-world side effects (see Phase 2
  check-generation rules below).

The outline is presented to the operator for approval or adjustment before
any lesson content is generated. This is a hard checkpoint: Phase 2 does not
start until the outline is approved, the same way `writing-plans` gates
before `subagent-driven-development`.

## Phase 2 — Lesson Generation (dispatched)

Once the outline is approved, one subagent is dispatched per phase (via the
`dispatching-parallel-agents` pattern). Each subagent receives only:

- Its phase's outline entry.
- The specific files/commits grounding that phase.
- The baseline-level setting for this run.
- The fixed lesson template (below).

It is deliberately *not* given the other phases' content — this keeps each
lesson focused and keeps context small enough that later lessons don't get
shallower treatment than earlier ones (the failure mode of the rejected
single-pass approach).

Each subagent writes one numbered markdown file:
`docs/curriculum/<NN>-<phase-slug>.md`

### Lesson template

1. **Concept** — the problem this phase solves and why it's needed at this
   point in the build, not just what the code does.
2. **Walkthrough** — the real original code for this phase, shown and
   explained: syntax, the algorithmic/design decisions made, and *why this
   way and not another way* (including alternatives that were plausible but
   not chosen, when that's derivable from context).
3. **Exercise** — instructions to close the lesson and rebuild this phase
   from scratch, blind, in the practice workspace (see below).
4. **Check** — how to run this phase's reference check, and how to interpret
   a failure.

A generated `docs/curriculum/00-index.md` ties the lessons together: linear
reading order, plus a short preamble explaining the mechanic (open-book
lesson → closed-book exercise → behavioral check → diff available afterward
as a study aid, never as the grading mechanism).

## Practice Workspace & Reference Checks

A `practice/` folder, sibling to `docs/curriculum/`, contains one stub
directory per phase for the learner to fill in, plus a generated check
script per phase.

### Check generation rules

For each phase, Phase 1's outline already flags whether it involves
real-world side effects (installs, package managers, writes to real dotfiles
or system state, network calls with side effects, etc.).

- **Side-effect-free phases**: the check runs the learner's implementation
  directly and asserts on output, exit codes, or existing test expectations
  reused/adapted from the original project.
- **Side-effect-having phases**: the check does not execute the dangerous
  path at all. Instead it extracts the testable decision logic into isolated,
  callable units and stubs the dangerous calls (e.g. `apt install`, real file
  writes, `curl | bash`), asserting on *what the learner's code would have
  done* — which command it would have run, which file it would have written
  and with what content — without it actually happening.

In both cases, checks are **behavioral only**. A literal diff against the
original source is available on request after a check runs (pass or fail),
purely as a study aid — it never gates pass/fail, so a correct-but
differently-styled solution still passes.

## Output layout

Inside the target project's repo (this is what the operator is teaching
from — the curriculum travels with the project, and the operator decides
whether to commit or gitignore it):

```
docs/curriculum/
  00-index.md
  01-<phase-slug>.md
  02-<phase-slug>.md
  ...
practice/
  01-<phase-slug>/        # learner's stub + workspace for this phase
    check.sh (or check.<ext>)
  02-<phase-slug>/
  ...
```

## Open risks / known limitations

- **Commit clustering quality** depends on how atomic the target project's
  history is. A repo with large, unfocused commits will produce coarser
  phases; the outline-approval checkpoint is the mitigation, not full
  automation of judgment.
- **Stub extraction for side-effect-having phases** requires the Phase 2
  subagent to correctly identify what's "pure decision logic" vs. "the
  dangerous call itself" in code that was never written with testability in
  mind. This is inherently judgment-heavy; a subagent may occasionally stub
  too much or too little. No automated safeguard beyond the subagent's own
  analysis is specified in this v1 — flagged as a place to revisit if it
  proves unreliable in practice.
- **True beginner baseline** is supported by the design (threaded through
  both phases) but not separately elaborated here; its lesson depth/pacing
  differences are left to the subagent's judgment at generation time rather
  than specified as a separate template.
