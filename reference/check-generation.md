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
4. Prefer invoking the implementation through its real entry point (e.g.
   `bash counter.sh install`, the actual subcommand a user would type) over
   sourcing the file and calling the internal function directly. Many CLI
   scripts invoke their dispatch function (`main "$@"`) unconditionally at
   the bottom of the file, which fires immediately on `source` — with no
   arguments, that dispatch typically hits its usage/error branch and exits
   before a separately-invoked internal function ever runs. Running the
   script through its real entry point sidesteps this entirely and exercises
   the same path a learner (or the original project) actually uses.

Example, for a phase whose exercise is "implement `do_install`" (wired into
the `install` subcommand) in `practice/04-install/counter.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

if ! HOME="$scratch" bash "$(dirname "$0")/counter.sh" install > /dev/null; then
  echo "FAIL: running 'counter.sh install' raised an error — check the implementation for a syntax or runtime error"
  exit 1
fi

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
directory for the entire invocation of the learner's script, so even a
learner implementation that hardcodes `$HOME` (rather than accepting a
target-directory argument) can be checked safely. Running the script
through its `install` subcommand, rather than sourcing it and calling
`do_install` directly, also means the check works regardless of whether the
script's dispatch runs unconditionally on source.

## Both strategies

- Print one `PASS:`/`FAIL:` line per assertion, not just a final verdict —
  the learner needs to know *which* behavior didn't match.
- Exit non-zero on any failure.
- Never delete or overwrite anything in the learner's `practice/`
  directory itself — checks read the learner's file, they don't rewrite it.
