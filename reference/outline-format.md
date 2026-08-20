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
**Side effects:** <none | a plain description of the effect that reaches
outside the project's own workspace: installs packages, writes to dotfiles
or system config outside the project directory, modifies global PATH/state,
makes a network call with side effects, etc.>

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
- "Side effects" means effects that reach outside the project's own
  workspace — the operator's home directory, dotfiles, global PATH, system
  packages, or the network. A phase whose code only reads or writes files
  inside the project directory (its own data files, config, source) is
  `**Side effects:** none` — that's the tool's normal, sandboxed behavior
  being taught, not a side effect to warn the operator about.
- Write the `**Side effects:**` line as exactly `none`, with nothing else
  on the line, whenever there is no external effect — Phase 2 matches this
  field verbatim to pick its check-generation strategy, so it must be
  literally parseable, not "none" plus a trailing justification. Put any
  reasoning about why a phase is side-effect-free in `**Teaches:**` instead.
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
