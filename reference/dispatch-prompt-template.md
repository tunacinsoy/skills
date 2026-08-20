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
