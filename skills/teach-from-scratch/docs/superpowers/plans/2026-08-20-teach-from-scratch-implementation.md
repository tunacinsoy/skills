# teach-from-scratch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `teach-from-scratch` Claude Code skill — given a finished project, it produces a linear, hands-on curriculum (lesson markdowns + a practice workspace with behavioral reference checks) that teaches a developer to rebuild the project from scratch, without AI assistance, in the practice step.

**Architecture:** A single `SKILL.md` drives a two-phase flow. Phase 1 (inline, single pass) analyzes the target repo and produces an outline artifact that the operator must approve before anything else happens. Phase 2 dispatches one fresh subagent per approved phase (via the `dispatching-parallel-agents` pattern) to write that phase's lesson markdown, practice stub, and behavioral check script. Heavy reference material (the outline contract, the lesson template, the dispatch prompt, and the check-generation rules) lives in separate `reference/*.md` files that `SKILL.md` points to, per `superpowers:writing-skills` token-efficiency guidance.

**Tech Stack:** Markdown (skill + reference docs), Bash (fixture project + generated check scripts — the toy fixture used for testing is itself a Bash CLI, matching the kind of side-effecting project the design spec calls out).

**Spec:** `/home/tuna/teach-from-scratch/docs/superpowers/specs/2026-08-20-teach-from-scratch-design.md`

## Global Constraints

- Reference checks are behavioral only — pass/fail must never be gated on a literal text diff against the original source. (spec: Reference Checks / Check generation rules)
- For any phase flagged as having real-world side effects, the generated check must never execute the dangerous path (installs, writes to real dotfiles/system state) — it must extract the testable decision logic and stub the dangerous calls. (spec: Check generation rules)
- Phase 2 must not start until the operator has approved the Phase 1 outline. Hard checkpoint, no auto-proceed. (spec: Phase 1)
- Each Phase 2 subagent receives only its own phase's outline entry, grounding files/commits, and the baseline-level setting — never the other phases' content. (spec: Phase 2)
- No auto-grading of style or idiom quality. No live pairing/tutoring mode — output is static artifacts the learner works through unaided. (spec: Non-goals)
- Output layout is fixed: `docs/curriculum/00-index.md`, `docs/curriculum/NN-<phase-slug>.md`, `practice/NN-<phase-slug>/` containing the learner's stub plus a check script. (spec: Output layout)
- Baseline level (`competent-generalist` or `true-beginner`) is asked once per run and threaded through both phases. (spec: Invocation)

---

### Task 1: Fixture project for testing the skill

**Files:**
- Create: `tests/fixtures/build-toy-counter.sh`
- Test: run the script itself and inspect its output (no separate test file — this task's deliverable IS the test fixture used by every later task)

**Interfaces:**
- Consumes: nothing (first task)
- Produces: a script `build-toy-counter.sh <target-dir>` that initializes a fresh git repo at `<target-dir>` containing a 4-commit history building up a small Bash CLI called `counter.sh`. Later tasks run this script into a scratch directory to get a realistic, small, git-history-bearing project to exercise Phase 1 and Phase 2 against. The 4 phases deliberately mix a side-effect-free phase (local file read/write) with one genuinely dangerous phase (writes to `$HOME/.bashrc` and `$HOME/.local/bin`), so later tasks can validate both check-generation branches from the spec.

- [ ] **Step 1: Create the fixture-builder script**

Create `tests/fixtures/build-toy-counter.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: build-toy-counter.sh <target-dir>}"
rm -rf "$target"
mkdir -p "$target"
cd "$target"
git init -q
git config user.email "fixture@example.com"
git config user.name "Fixture Builder"

# Commit 1: scaffold arg parsing
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

cmd="${1:-}"
case "$cmd" in
  add|show|install) ;;
  *) usage; exit 1 ;;
esac
EOF
chmod +x counter.sh
git add counter.sh
git commit -q -m "scaffold: arg parsing skeleton"

# Commit 2: pure arithmetic
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current + delta))"
}

cmd="${1:-}"
case "$cmd" in
  add|show|install) ;;
  *) usage; exit 1 ;;
esac
EOF
git add counter.sh
git commit -q -m "feat: pure arithmetic for computing new totals"

# Commit 3: local persistence
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current + delta))"
}

read_counter() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo 0
  fi
}

write_counter() {
  local file="$1" value="$2"
  echo "$value" > "$file"
}

main() {
  local cmd="${1:-}"
  local counter_file="${COUNTER_FILE:-./counter.txt}"
  case "$cmd" in
    add)
      local delta="${2:-1}"
      local current new_total
      current="$(read_counter "$counter_file")"
      new_total="$(compute_new_total "$current" "$delta")"
      write_counter "$counter_file" "$new_total"
      echo "$new_total"
      ;;
    show)
      read_counter "$counter_file"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
EOF
git add counter.sh
git commit -q -m "feat: persist counter to a local counter.txt"

# Commit 4: install subcommand (the dangerous phase)
cat > counter.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: counter.sh <add|show|install> [amount]"
}

compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current + delta))"
}

read_counter() {
  local file="$1"
  if [[ -f "$file" ]]; then
    cat "$file"
  else
    echo 0
  fi
}

write_counter() {
  local file="$1" value="$2"
  echo "$value" > "$file"
}

do_install() {
  local bin_dir="$HOME/.local/bin"
  local rc_file="$HOME/.bashrc"
  mkdir -p "$bin_dir"
  cp "$0" "$bin_dir/counter"
  chmod +x "$bin_dir/counter"
  if ! grep -q '.local/bin' "$rc_file" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
  fi
  echo "Installed to $bin_dir/counter"
}

main() {
  local cmd="${1:-}"
  local counter_file="${COUNTER_FILE:-./counter.txt}"
  case "$cmd" in
    add)
      local delta="${2:-1}"
      local current new_total
      current="$(read_counter "$counter_file")"
      new_total="$(compute_new_total "$current" "$delta")"
      write_counter "$counter_file" "$new_total"
      echo "$new_total"
      ;;
    show)
      read_counter "$counter_file"
      ;;
    install)
      do_install
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
EOF
git add counter.sh
git commit -q -m "feat: install subcommand copies script to ~/.local/bin and updates PATH in ~/.bashrc"

echo "Fixture built at $target"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/fixtures/build-toy-counter.sh
```

- [ ] **Step 3: Run it into a scratch dir and verify the history**

Run: `./tests/fixtures/build-toy-counter.sh /tmp/toy-counter-check && git -C /tmp/toy-counter-check log --oneline`
Expected: 4 lines of output, oldest-last, ending with `scaffold: arg parsing skeleton` and starting with `feat: install subcommand copies script to ~/.local/bin and updates PATH in ~/.bashrc`.

- [ ] **Step 4: Verify the built CLI actually works**

Run:
```bash
cd /tmp/toy-counter-check
./counter.sh add 5
./counter.sh add 3
./counter.sh show
```
Expected: prints `5`, then `8`, then `8`.

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/build-toy-counter.sh
git commit -m "test: add toy-counter fixture builder for exercising the skill"
```

---

### Task 2: SKILL.md skeleton

**Files:**
- Create: `SKILL.md`

**Interfaces:**
- Consumes: nothing
- Produces: the skill's frontmatter (`name: teach-from-scratch`) and top-level sections (Overview, When to Use, Baseline level, Two-phase flow summary) that later tasks extend in place. Later tasks add the detailed Phase 1 and Phase 2 sections and the `## Reference` links — this task establishes everything around them.

- [ ] **Step 1: Write the skeleton**

Create `SKILL.md`:

```markdown
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
```

- [ ] **Step 2: Verify frontmatter is well-formed and within limits**

Run:
```bash
head -5 SKILL.md
wc -c SKILL.md | awk '{print $1}'
```
Expected: the frontmatter block prints exactly `---`, `name: teach-from-scratch`, `description: ...`, `---` as the first four lines; the byte count printed is well under 1024 for the frontmatter portion (visually confirm the `---`...`---` block alone is short — the full-file byte count is expected to be larger since it includes the body, that's fine).

- [ ] **Step 3: Verify the name field matches the directory convention**

Run: `grep '^name:' SKILL.md`
Expected: `name: teach-from-scratch` — letters and hyphens only, matching the eventual directory name `teach-from-scratch/`.

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "feat: scaffold SKILL.md with frontmatter and overview"
```

---

### Task 3: Phase 1 — outline contract and instructions

**Files:**
- Create: `reference/outline-format.md`
- Modify: `SKILL.md` (replace the `<!-- Phase 1 ... -->` placeholder with the real Phase 1 section, add a link under `## Reference`)

**Interfaces:**
- Consumes: `tests/fixtures/build-toy-counter.sh` (Task 1) for the validation step
- Produces: the exact structure of `docs/curriculum/OUTLINE.md` that Phase 1 must write and that Phase 2 (Task 4+) reads from — field names `Phase N: <slug>`, `**Teaches:**`, `**Grounded in:**`, `**Side effects:**` are the contract later tasks depend on verbatim.

- [ ] **Step 1: Write the outline contract**

Create `reference/outline-format.md`:

```markdown
# Outline Format

Phase 1 produces exactly one artifact: `docs/curriculum/OUTLINE.md` in the
target project. Nothing in Phase 2 starts until the operator has approved
it (or you've applied their requested changes and they've approved the
revision).

## Structure

```markdown
# <Project Name> — Curriculum Outline

**Baseline level:** <competent-generalist | true-beginner>
**Derived from:** <git history | codebase structure only>

## Phase 1: <phase-slug>
**Teaches:** <one paragraph — what this phase teaches, and why it's needed
at this point in the build, not just what the code does>
**Grounded in:** <file paths, and commit hashes or a commit range>
**Side effects:** <none | a plain description of the real-world effect:
installs packages, writes to dotfiles or system config, makes a network
call with side effects, etc.>

## Phase 2: <phase-slug>
...
```

## Rules

- Order phases the way the project was actually built. If `**Derived from**`
  is "codebase structure only" (history too thin, squashed, or missing),
  order them the way a learner would need to build them so each phase's
  dependencies already exist by the time it starts.
- Every phase gets an explicit `**Side effects**` line, even when the answer
  is "none" — Phase 2 picks its check-generation strategy from this line
  alone (see `check-generation.md`), so it must be accurate. When in doubt,
  describe the effect rather than guessing none/some.
- Let the phase count fall out of natural boundaries in the commit
  clustering. Don't pad or compress to hit a round number.
- Cluster consecutive commits touching the same area into one phase
  candidate before reading full commit bodies — for a large history, skim
  `git log --oneline --stat` first to find the clusters, then read bodies
  only for the commits inside each cluster.

## Stop condition

After writing `docs/curriculum/OUTLINE.md`, show it to the operator and
wait. Do not begin Phase 2 in the same turn. If they request changes, apply
them and show the outline again before proceeding.
```

- [ ] **Step 2: Add the Phase 1 section to SKILL.md**

In `SKILL.md`, replace `<!-- Phase 1 and Phase 2 sections are added by later tasks. -->` with:

```markdown
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
```

Also replace `<!-- Links to reference/*.md are added by later tasks. -->` under `## Reference` with:

```markdown
- `reference/outline-format.md` — the Phase 1 output contract
```

- [ ] **Step 3: Validate Phase 1 against the fixture with a subagent**

Build the fixture fresh, then dispatch a subagent that has only the
skill content written so far (it should read `SKILL.md` and
`reference/outline-format.md` directly rather than being told their
contents, so the test reflects what a real invocation would see):

```bash
./tests/fixtures/build-toy-counter.sh /tmp/toy-counter-phase1-check
```

Dispatch a general-purpose agent with this prompt:

```
Read the skill at /home/tuna/teach-from-scratch/SKILL.md and
/home/tuna/teach-from-scratch/reference/outline-format.md. Then follow
the "Phase 1: Analysis & Outline" section against the project at
/tmp/toy-counter-phase1-check (baseline level: competent-generalist).
Write the resulting docs/curriculum/OUTLINE.md into
/tmp/toy-counter-phase1-check/. Do not do anything beyond writing that one
file and stopping — report back the full contents of the file you wrote
plus one sentence confirming you stopped there.
```

- [ ] **Step 4: Check the subagent's output against acceptance criteria**

Read `/tmp/toy-counter-phase1-check/docs/curriculum/OUTLINE.md` and confirm:
- It has 4 phases (matching the 4 fixture commits), in build order.
- Every phase has all four fields (`**Teaches:**`, `**Grounded in:**`,
  `**Side effects:**`, plus the `Phase N: <slug>` heading).
- The phase corresponding to the `install` commit has a non-"none"
  `**Side effects:**` line describing the `~/.bashrc`/`~/.local/bin`
  mutation.
- The other three phases say `**Side effects:** none`.
- The subagent's report confirms it stopped after writing the file (did
  not proceed to generate any lesson content).

If any of these are wrong, fix the wording in `SKILL.md` or
`reference/outline-format.md` and re-run Steps 3–4 until they hold.

- [ ] **Step 5: Commit**

```bash
git add SKILL.md reference/outline-format.md
git commit -m "feat: add Phase 1 analysis and outline instructions"
```

---

### Task 4: Phase 2 — lesson template and dispatch prompt

**Files:**
- Create: `reference/lesson-template.md`
- Create: `reference/dispatch-prompt-template.md`
- Modify: `SKILL.md` (add the Phase 2 section, add reference links)

**Interfaces:**
- Consumes: `reference/outline-format.md` (Task 3) field names; the fixture builder (Task 1)
- Produces: the 4-part lesson structure (`Concept` / `Walkthrough` / `Exercise` / `Check`) that every generated lesson file must follow, and the exact dispatch prompt template later tasks (5, 6) extend with check-generation and index-generation instructions.

- [ ] **Step 1: Write the lesson template**

Create `reference/lesson-template.md`:

```markdown
# Lesson Template

Every lesson file (`docs/curriculum/NN-<phase-slug>.md`) follows this
structure. Write for the baseline level you were given — competent
generalist gets stack syntax/idioms explained from scratch; true beginner
also gets the underlying programming concepts explained as they come up.

## 1. Concept

The problem this phase solves and why it's needed at this point in the
build — not a restatement of what the code does line by line. Ground this
in the phase's `**Teaches**` field from the outline.

## 2. Walkthrough

Show the real original code for this phase (from the phase's
`**Grounded in**` files/commits) and explain it: syntax, the
algorithmic/design decision made at each step, and *why this way and not
another way* — including plausible alternatives that weren't chosen, when
you can tell what those were from context (e.g. "a lookup table would also
work here, but a case statement matches how the rest of the file dispatches
on command name").

## 3. Exercise

Instruct the learner to close this lesson and rebuild this phase from
scratch, blind, in `practice/NN-<phase-slug>/`. Be concrete about the
entry point and expected interface (function names, file names) so the
check in step 4 has something well-defined to test against — but do not
give away the implementation.

## 4. Check

Tell the learner how to run this phase's check script and how to read a
failure (which behavior didn't match, not which lines differ). Remind them
a passing check means their solution is behaviorally correct even if it
doesn't look like the original — and that they can view a literal diff
against the original afterward purely to compare style, never as the grade.
```

- [ ] **Step 2: Write the dispatch prompt template**

Create `reference/dispatch-prompt-template.md`:

```markdown
# Dispatch Prompt Template

Used once per approved outline phase, per
`superpowers:dispatching-parallel-agents`. Each dispatch is a **fresh**
subagent (not a fork) — it must not see the other phases' content, so that
its lesson stays focused and doesn't shrink in quality for later phases.

Fill in the placeholders and dispatch with `subagent_type: general-purpose`:

```
Read /home/tuna/.claude/skills/teach-from-scratch/reference/lesson-template.md
before writing anything.

You are writing lesson {phase_number} of a curriculum that teaches a
developer to rebuild the project at {target_repo_path} from scratch.

This phase's outline entry (from docs/curriculum/OUTLINE.md):
**Teaches:** {teaches}
**Grounded in:** {grounding_files_and_commits}
**Side effects:** {side_effects}

Baseline level for this learner: {baseline_level}

Read the grounding files/commits above from the target repo directly —
don't rely on this prompt to have quoted them in full.

Write:
1. `docs/curriculum/{NN}-{phase_slug}.md` following the lesson template
   exactly (Concept, Walkthrough, Exercise, Check).
2. A stub directory `practice/{NN}-{phase_slug}/` containing whatever
   starter scaffolding the exercise in your lesson refers to (e.g. an
   empty file with the right name and a comment saying what goes here —
   not a partial implementation).

Do not write a check script yet — that's a separate step. Report back the
paths you wrote and a one-paragraph summary of what the lesson teaches.
```
```

- [ ] **Step 3: Add the Phase 2 section to SKILL.md**

In `SKILL.md`, after the Phase 1 section, add:

```markdown
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
```

Also replace the single bullet under `## Reference` (added in Task 3) with
the full list:

```markdown
- `reference/outline-format.md` — the Phase 1 output contract
- `reference/lesson-template.md` — the 4-part structure every lesson follows
- `reference/dispatch-prompt-template.md` — the Phase 2 subagent dispatch prompt
```

- [ ] **Step 4: Validate Phase 2 against the fixture with a subagent**

Reuse the outline from Task 3's validation (or rebuild fresh):

```bash
./tests/fixtures/build-toy-counter.sh /tmp/toy-counter-phase2-check
```

Dispatch a general-purpose agent to run Phase 1 first (same prompt shape as
Task 3 Step 3, targeting `/tmp/toy-counter-phase2-check`), then, using the
resulting outline's second phase (`compute_new_total` / pure arithmetic —
pick the side-effect-free one for this task; the side-effecting phase is
validated in Task 5), dispatch a second agent with the filled-in
`reference/dispatch-prompt-template.md` prompt for that one phase.

- [ ] **Step 5: Check the generated lesson against acceptance criteria**

Read the generated `docs/curriculum/02-*.md` (or whichever number the
arithmetic phase landed at) and confirm:
- All four sections (`## 1. Concept` through `## 4. Check`) are present.
- The Walkthrough quotes/shows the real `compute_new_total` function from
  the fixture, not a paraphrase.
- The Exercise names a concrete function/file the learner must produce in
  `practice/`.
- The corresponding `practice/NN-*/` directory exists with a stub (not a
  working implementation — spot-check that it doesn't already contain
  `compute_new_total`'s logic).

If any of these are wrong, fix the wording in `reference/lesson-template.md`
or `reference/dispatch-prompt-template.md` and re-run Steps 4–5.

- [ ] **Step 6: Commit**

```bash
git add SKILL.md reference/lesson-template.md reference/dispatch-prompt-template.md
git commit -m "feat: add Phase 2 lesson generation template and dispatch prompt"
```

---

### Task 5: Behavioral check generation

**Files:**
- Create: `reference/check-generation.md`
- Modify: `reference/dispatch-prompt-template.md` (add the check-script step back in)

**Interfaces:**
- Consumes: the `**Side effects**` field from `reference/outline-format.md` (Task 3); the fixture (Task 1)
- Produces: the rule set later Phase 2 dispatches use to decide which of the two check strategies (direct execution vs. stub-and-assert) applies, and the requirement that every dispatch produces a `check.sh` alongside its lesson and stub.

- [ ] **Step 1: Write the check-generation rules**

Create `reference/check-generation.md`:

```markdown
# Check Generation

Every phase's dispatch (Task 4's prompt) also produces
`practice/NN-<phase-slug>/check.sh`. Which of the two strategies below
applies is decided entirely by that phase's `**Side effects**` line from
the outline — never by re-judging it during generation.

Checks are **always behavioral**. Never gate pass/fail on a literal text
diff against the original source — a correct-but-differently-styled
solution must still pass. A literal diff may be offered separately as a
study aid the learner can request after the check runs, but the check
script itself never uses one to decide pass/fail.

## Strategy A — Side effects: none

Run the learner's implementation directly and assert on its observable
output, exit code, or (if the original project has tests covering this
phase) the original test expectations, adapted to call the learner's
version.

Example, for a phase whose exercise is "implement `compute_new_total`" in
`practice/02-arithmetic/counter.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/counter.sh"

result="$(compute_new_total 5 3)"
if [[ "$result" == "8" ]]; then
  echo "PASS: compute_new_total(5, 3) == 8"
else
  echo "FAIL: compute_new_total(5, 3) was '$result', expected 8"
  exit 1
fi

result="$(compute_new_total 0 -4)"
if [[ "$result" == "-4" ]]; then
  echo "PASS: compute_new_total(0, -4) == -4"
else
  echo "FAIL: compute_new_total(0, -4) was '$result', expected -4"
  exit 1
fi
```

## Strategy B — Side effects: <described effect>

Never execute the dangerous path. Instead:

1. Identify the pure decision logic inside the learner's implementation
   (e.g. "which path would I copy to, which line would I append, would I
   append it at all") separately from the calls that actually perform the
   effect (`cp`, `>>` to a real dotfile, `apt install`, network calls).
2. In the check script, stub the dangerous calls (shadow the real command
   with a function that records what it *would* have done instead of doing
   it, or point the implementation's target paths at a scratch directory
   via an environment variable/argument if the implementation already
   supports that) and assert on what got recorded.
3. If the learner's implementation has no way to redirect its target
   (no env var, no parameter — it hardcodes `$HOME`), the check must still
   avoid touching the real `$HOME`: run it with `HOME` itself overridden to
   a scratch directory for the duration of the check, so `~` inside the
   learner's script resolves somewhere disposable, and clean that directory
   up afterward regardless of pass/fail.

Example, for a phase whose exercise is "implement `do_install`" in
`practice/04-install/counter.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

HOME="$scratch" bash -c '
  source "'"$(dirname "$0")"'/counter.sh"
  do_install
' _ "$0"

if [[ -x "$scratch/.local/bin/counter" ]]; then
  echo "PASS: installed an executable to ~/.local/bin/counter"
else
  echo "FAIL: no executable found at ~/.local/bin/counter"
  exit 1
fi

if grep -q '.local/bin' "$scratch/.bashrc" 2>/dev/null; then
  echo "PASS: ~/.bashrc updated to include .local/bin on PATH"
else
  echo "FAIL: ~/.bashrc was not updated"
  exit 1
fi
```

This never touches the real `$HOME` — `HOME` is overridden to a scratch
directory for the subshell that sources and calls the learner's code, so
even a learner implementation that hardcodes `$HOME` (rather than accepting
a target-directory argument) can be checked safely.

## Both strategies

- Print one `PASS:`/`FAIL:` line per assertion, not just a final verdict —
  the learner needs to know *which* behavior didn't match.
- Exit non-zero on any failure.
- Never delete or overwrite anything in the learner's `practice/`
  directory itself — checks read the learner's file, they don't rewrite it.
```

- [ ] **Step 2: Fold check-script generation back into the dispatch prompt**

In `reference/dispatch-prompt-template.md`, replace:

```
Do not write a check script yet — that's a separate step. Report back the
paths you wrote and a one-paragraph summary of what the lesson teaches.
```

with:

```
Also read
/home/tuna/.claude/skills/teach-from-scratch/reference/check-generation.md
and write `practice/{NN}-{phase_slug}/check.sh` following whichever
strategy matches this phase's **Side effects** line above (`none` →
Strategy A, anything else → Strategy B). Make it executable
(`chmod +x`).

Report back the paths you wrote and a one-paragraph summary of what the
lesson teaches.
```

- [ ] **Step 3: Validate Strategy A (side-effect-free) against the fixture**

Using the same `/tmp/toy-counter-phase2-check` project and generated lesson
from Task 4, dispatch a subagent to add the check script per the updated
prompt (or regenerate that one phase's dispatch fresh). Then:

Write a correct implementation into the practice stub and run the check:

```bash
cat > /tmp/toy-counter-phase2-check/practice/02-*/counter.sh <<'EOF'
compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current + delta))"
}
EOF
bash /tmp/toy-counter-phase2-check/practice/02-*/check.sh
echo "exit: $?"
```
Expected: all `PASS:` lines, `exit: 0`.

Then write a broken implementation and confirm the check catches it:

```bash
cat > /tmp/toy-counter-phase2-check/practice/02-*/counter.sh <<'EOF'
compute_new_total() {
  local current="$1" delta="$2"
  echo "$((current - delta))"
}
EOF
bash /tmp/toy-counter-phase2-check/practice/02-*/check.sh
echo "exit: $?"
```
Expected: at least one `FAIL:` line, non-zero exit.

- [ ] **Step 4: Validate Strategy B (side-effecting) against the fixture**

Build a fresh fixture and run full Phase 1 + a Phase 2 dispatch targeting
the `install` phase specifically:

```bash
./tests/fixtures/build-toy-counter.sh /tmp/toy-counter-install-check
```

Dispatch Phase 1 (as in Task 3 Step 3) against
`/tmp/toy-counter-install-check`, then dispatch Task 4's prompt filled in
for the `install` phase.

Write a correct implementation into the generated practice stub (matching
`do_install` from the fixture's final commit) and run the generated check:

```bash
bash /tmp/toy-counter-install-check/practice/04-*/check.sh
echo "exit: $?"
ls "$HOME/.local/bin/counter" 2>/dev/null && echo "DANGER: real HOME was touched"
```
Expected: `PASS:` lines, `exit: 0`, and the `ls`/echo line must NOT print
"DANGER" — confirming the real `$HOME` was never touched.

Then write a broken implementation (e.g. `do_install` that only does the
`cp` but skips the `.bashrc` line) and confirm the check catches the
specific missing behavior without touching real `$HOME` either time.

If Steps 3 or 4 fail, fix `reference/check-generation.md` and/or
`reference/dispatch-prompt-template.md` and re-run until both hold.

- [ ] **Step 5: Commit**

```bash
git add reference/check-generation.md reference/dispatch-prompt-template.md
git commit -m "feat: add behavioral check generation rules for both side-effect strategies"
```

---

### Task 6: End-to-end run and output layout

**Files:**
- Modify: `SKILL.md` (add an explicit Output Layout section)

**Interfaces:**
- Consumes: everything from Tasks 1–5
- Produces: confirmation that a full, unattended-after-approval run over all 4 fixture phases produces the exact tree the spec requires.

- [ ] **Step 1: Add the Output Layout section to SKILL.md**

After the Phase 2 section, add:

```markdown
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
```

- [ ] **Step 2: Run the full flow end-to-end against a fresh fixture**

```bash
./tests/fixtures/build-toy-counter.sh /tmp/toy-counter-e2e
```

Dispatch one subagent with this prompt:

```
Read /home/tuna/teach-from-scratch/SKILL.md and follow it completely
against the project at /tmp/toy-counter-e2e. Baseline level:
competent-generalist. Run Phase 1, then present the outline and — for the
purposes of this test only — treat it as immediately approved without
waiting (a real run would stop and wait for a human; skip that pause here
so this single dispatch can validate the full pipeline). Continue through
Phase 2 for all phases and write 00-index.md. Report the full file tree
you produced under docs/curriculum/ and practice/.
```

- [ ] **Step 3: Verify the output tree matches the spec**

Run: `find /tmp/toy-counter-e2e/docs/curriculum /tmp/toy-counter-e2e/practice -type f | sort`

Expected:
- `docs/curriculum/OUTLINE.md`, `docs/curriculum/00-index.md`, and one
  numbered lesson file per fixture phase (4 lessons).
- One `practice/NN-<slug>/` directory per phase, each containing at least
  `check.sh` plus whatever stub file(s) that phase's exercise refers to.
- Numbering in `docs/curriculum/` and `practice/` matches 1:1 by phase.

Run each generated `check.sh` against its own stub (which will be blank,
so they're all expected to `FAIL:`, not error out or hang):
```bash
for f in /tmp/toy-counter-e2e/practice/*/check.sh; do
  echo "=== $f ==="
  bash "$f" || true
done
```
Expected: each prints readable `FAIL:` lines (not a bash syntax error, not
a crash, not a hang) — confirming every generated check is at least
well-formed and runnable, even against an empty stub.

If anything is missing or malformed, fix the relevant `SKILL.md` or
`reference/*.md` section and re-run Steps 2–3.

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "feat: document output layout and verify end-to-end fixture run"
```

---

### Task 7: Deploy

**Files:**
- Create: `~/.claude/skills/teach-from-scratch` (symlink to this repo)

**Interfaces:**
- Consumes: everything from Tasks 1–6
- Produces: the skill live and loadable by Claude Code from its actual skills directory.

- [ ] **Step 1: Symlink the skill into place**

```bash
mkdir -p ~/.claude/skills
ln -s /home/tuna/teach-from-scratch ~/.claude/skills/teach-from-scratch
```

A symlink (not a copy) means future edits to this repo take effect
immediately without a separate deploy step.

- [ ] **Step 2: Verify Claude Code picks it up**

Run: `ls -la ~/.claude/skills/teach-from-scratch/SKILL.md`
Expected: resolves through the symlink to the real file without error.

- [ ] **Step 3: Final commit**

```bash
git add -A
git status
```
Expected: working tree clean except for anything intentionally left
uncommitted (e.g. scratch test output under `/tmp`, which was never inside
this repo). If `git status` shows unexpected untracked files, review and
commit or `.gitignore` them before finishing.
