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
