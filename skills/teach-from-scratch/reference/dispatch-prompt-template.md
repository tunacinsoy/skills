# Dispatch Prompt Template

Used once per approved outline phase, dispatched in parallel where the
harness supports it. Each dispatch is a **fresh** subagent (not a fork) —
it must not see the other phases' content, so that its lesson stays
focused and doesn't shrink in quality for later phases.

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
3. `practice/{NN}-{phase_slug}/check.sh` — read
   /home/tuna/.claude/skills/teach-from-scratch/reference/check-generation.md
   first, then write this following whichever strategy matches this
   phase's **Side effects:** line above (`none` → Strategy A, anything
   else → Strategy B). Make it executable (`chmod +x`).

Report back the paths you wrote and a one-paragraph summary of what the
lesson teaches.
```
