# Check Generation

Every phase's dispatch (the dispatch prompt, `reference/dispatch-prompt-template.md`) also produces
`practice/NN-<phase-slug>/check.sh`. Which of the two strategies below
applies is decided entirely by that phase's `**Side effects:**` line from
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

`source`ing the file, as the example below does, runs any top-level code
in it — including a dispatcher invoked unconditionally at the bottom of
the file (e.g. a bare `main "$@"` with no guard). If the phase's file does
that, sourcing triggers it with no arguments — typically its usage/error
branch — before your assertions ever run, producing a spurious failure
with no useful diagnostic. Check the actual file before choosing to source
it:

- If its dispatcher is guarded (e.g.
  `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`), or there
  is no unconditional dispatcher at all, sourcing is safe — use the
  pattern below.
- If it has an unconditional dispatcher call, don't source it. Instead
  invoke the script through its real entry point — the way Strategy B's
  Technique 1 does (`bash script.sh <subcommand>`) — and assert on its
  stdout/exit code, rather than trying to reach the internal function
  directly. If this phase's code writes any file at all — even a
  project-local write that's `**Side effects:** none` per
  `outline-format.md` (that field only means the write stays inside the
  project workspace, not that there's no write) — run the invocation with
  its cwd set to a scratch directory, same as Strategy B's cwd override in
  Technique 1 step 4, rather than letting it default to
  `practice/NN-<slug>/`; see "Never delete or overwrite anything in the
  learner's `practice/` directory" under "Both strategies" below, which
  applies here too, not just to Strategy B. Only skip the scratch cwd if
  the entry point performs no writes at all (pure stdout/exit-code
  behavior). A `HOME` override is not needed for Strategy A — that's a
  Strategy-B-only concern for effects that resolve through `$HOME`/`~`.
  There is no way to call an internal function without sourcing, and
  sourcing is exactly what re-triggers the dispatcher problem this bullet
  exists to avoid — `bash -c 'source ./script.sh; some_function args'`
  still fires the dispatcher and fails with a spurious usage error, the
  same as sourcing directly. This fallback only applies when the function
  under test is reachable through the CLI entry point; if it's genuinely a
  standalone pure function with no dispatcher wrapping it, plain sourcing
  (the pattern above) is still correct and this fallback doesn't apply.

Example, for a phase whose exercise is "implement `compute_new_total`" in
`practice/02-arithmetic/counter.sh` (this file has no unconditional
dispatcher, so sourcing it is safe):

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/counter.sh"

failed=0

result="$(compute_new_total 5 3 || echo '<error>')"
if [[ "$result" == "8" ]]; then
  echo "PASS: compute_new_total(5, 3) == 8"
else
  echo "FAIL: compute_new_total(5, 3) was '$result', expected 8"
  failed=1
fi

result="$(compute_new_total 0 -4 || echo '<error>')"
if [[ "$result" == "-4" ]]; then
  echo "PASS: compute_new_total(0, -4) == -4"
else
  echo "FAIL: compute_new_total(0, -4) was '$result', expected -4"
  failed=1
fi

exit "$failed"
```

Note the pattern: each assertion sets a `failed` flag instead of exiting
immediately, and the script exits with the accumulated status at the very
end. See "Both strategies" below — this is required, not incidental to
this example.

## Strategy B — Side effects: <described effect>

Never let the dangerous effect actually happen when the check runs. Which
technique achieves that depends on where the effect lands. Read this whole
section before writing a Strategy B check — the two techniques below apply
to *different* situations; they are not interchangeable, and combining
them incorrectly (see "Why you cannot mix them" just below) is what
causes a check to silently perform the real dangerous effect.

**First, decide: is every effect this code performs confined to
`$HOME`-relative paths?**

- If every effect the entry point performs writes only under `$HOME` (e.g.
  `~/.bashrc`, `~/.local/bin`, `~/.config/...`), or is redirected to a
  location of your choosing via an environment variable/argument the
  implementation already honors, use **Technique 1: entry-point invocation
  with `HOME` + cwd override** below. Overriding `HOME` (and cwd) for the
  invocation is sufficient containment, because every path the script
  touches is relative to `HOME`.
- If **any** effect targets something not confined that way — an absolute
  path outside `$HOME` (e.g. `/usr/local/bin`, `/etc/...`), a package
  manager (`apt`, `brew`, `pip install` outside a venv), `sudo` in any
  form, or a network call — the `HOME` override provides **zero**
  containment for that effect. Stubbing is mandatory and an **un-stubbed**
  entry-point invocation is forbidden (Technique 2 still invokes the real
  entry point, as its own step 3 says — but only after the stub is armed,
  never plain). Use **Technique 2: stubbing a dangerous command** below
  instead.

**Why you cannot mix them:** a shell function defined in the check
script's own process does not exist inside a separately-invoked child
process. If the check defines `apt-get() { ... }` and then runs
`bash counter.sh install` (a child `bash` process), that child does not
see the function — the real `apt-get` on `$PATH` runs for real. This is
true regardless of any `HOME` override: `HOME` only affects paths the
script builds from `$HOME`/`~`; it does nothing to contain a package
manager invocation, a `sudo` call, an absolute path outside `$HOME`, or a
network request. Never write a check that defines a stub function and
then invokes the learner's code through a plain child `bash script`
expecting the stub to intercept it — it will not, and the real effect
will run.

### Technique 1: entry-point invocation with `HOME` + cwd override

Use this only when every effect is `$HOME`-relative (see above).

1. Create a scratch directory and register a cleanup trap:
   ```bash
   scratch="$(mktemp -d)"
   trap 'rm -rf "$scratch"' EXIT
   ```
2. Resolve the path to the learner's script to an absolute path *before*
   changing directories (you're about to `cd`, so a relative `dirname`
   lookup done afterward would break):
   ```bash
   script="$(cd "$(dirname "$0")" && pwd)/counter.sh"
   ```
3. Invoke the learner's script through its real entry point (e.g.
   `bash counter.sh install`, the actual subcommand a user would type)
   rather than sourcing it and calling the internal function directly.
   Many CLI scripts run their dispatcher (`main "$@"`) unconditionally at
   the bottom of the file, which fires on `source` too and, with no
   arguments, typically hits a usage/error branch before an internal
   function call ever runs. Invoking the real entry point sidesteps that.
4. Every invocation must set **both** `HOME` and the working directory to
   the scratch directory — not `HOME` alone. `HOME` does not change the
   process's cwd, so a relative-path write (or a relative path the script
   builds from `pwd`) can still land inside the learner's own `practice/`
   directory — where the check script itself lives — if you don't also
   `cd`:
   ```bash
   ( cd "$scratch" && HOME="$scratch" bash "$script" install )
   ```
5. This has no exceptions inside a single check: if the check invokes the
   learner's code more than once (e.g. to assert idempotency by running
   `install` twice), **every** invocation carries the same
   `( cd "$scratch" && HOME="$scratch" ... )` wrapper. There is no bare,
   un-prefixed call to the learner's script anywhere in a Strategy B
   check, ever — a later call that forgets the override hits the real
   `$HOME`.

Example, for a phase whose exercise is "implement `do_install`" (wired
into the `install` subcommand) in `practice/04-install/counter.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
failed=0

script="$(cd "$(dirname "$0")" && pwd)/counter.sh"

if ( cd "$scratch" && HOME="$scratch" bash "$script" install > /dev/null ); then
  echo "PASS: 'counter.sh install' ran without error"
else
  echo "FAIL: running 'counter.sh install' raised an error — check the implementation for a syntax or runtime error"
  failed=1
fi

if [[ -x "$scratch/.local/bin/counter" ]]; then
  echo "PASS: installed an executable to ~/.local/bin/counter"
else
  echo "FAIL: no executable found at ~/.local/bin/counter"
  failed=1
fi

if grep -q '.local/bin' "$scratch/.bashrc" 2>/dev/null; then
  echo "PASS: ~/.bashrc updated to include .local/bin on PATH"
else
  echo "FAIL: ~/.bashrc was not updated"
  failed=1
fi

exit "$failed"
```

This never touches the real `$HOME` — `HOME` (and cwd) are overridden to a
scratch directory for the entire invocation of the learner's script, so
even a learner implementation that hardcodes `$HOME` (rather than
accepting a target-directory argument) can be checked safely. This assumes
the implementation resolves the home directory through `$HOME`/`~`, which
is what learner code normally does; it would *not* catch an implementation
that hardcodes a literal path like `/home/alice` or resolves the home
directory some other way (e.g. `getpwuid`) — that's outside what this
technique can contain, and not a pattern the exercises should invite.

### Technique 2: stubbing a dangerous command

Use this whenever **any** effect the entry point performs is not confined
to `$HOME`-relative paths (see the decision above). Do not invoke the real
entry point in a plain child process here — intercept the dangerous
command itself, using a mechanism that actually crosses into the process
the learner's script runs in:

1. Identify the pure decision logic inside the learner's implementation
   (e.g. "which package would I install, which flags would I pass")
   separately from the call that actually performs the effect (`apt-get`,
   `cp` to an absolute path, `sudo`, a network call).
2. Define a same-named shell function that records what it *would* have
   done, and make it visible to the child process with **`export -f`**:
   ```bash
   export record="$scratch/calls.log"
   apt-get() { echo "$*" >> "$record"; }
   export -f apt-get
   ```
   Note that `export -f` exports the function's *code*, not the variables
   it closes over — any variable the stub body references (`$record`
   above) must be exported too, or the child sees it as unset (and fails
   loudly under `set -u`).
3. Then invoke the learner's script the normal way (entry point, inside
   `( cd "$scratch" && HOME="$scratch" ... )` as in Technique 1 — combine
   both overrides even though `HOME` isn't what's containing this
   particular effect, since it's harmless and guards against any
   incidental `$HOME`-relative writes the same code path also makes).
   Because the function was exported, the child `bash` process resolves
   `apt-get` to the stub instead of the real executable on `$PATH`.
4. Alternative mechanism — **`PATH` prepend**: if `export -f` doesn't fit
   (e.g. the dangerous command is invoked by a *name*, not something
   `export -f`-visible functions intercept cleanly, such as from a
   different shell/interpreter), write a fake executable to a scratch
   directory named exactly like the dangerous command, and prepend that
   directory to `PATH` for just that invocation:
   ```bash
   fakebin="$scratch/fakebin"; mkdir -p "$fakebin"
   printf '#!/usr/bin/env bash\necho "$*" >> "%s/calls.log"\n' "$scratch" \
     > "$fakebin/apt-get"
   chmod +x "$fakebin/apt-get"
   ( cd "$scratch" && PATH="$fakebin:$PATH" HOME="$scratch" bash "$script" provision )
   ```
   (Use `printf` rather than a heredoc here: a heredoc's closing delimiter
   must appear with the exact leading whitespace bash expects — easy to get
   wrong when this snippet is embedded in indented markdown list markup and
   copied verbatim. `printf` has no such hazard: its format string is a
   single quoted argument, so any indentation in front of the line is just
   ordinary leading whitespace before a command, which bash ignores.)
5. Both mechanisms only intercept a command invoked by its bare name
   (resolved via `$PATH`/function lookup). Neither intercepts a call that
   hardcodes the dangerous command's absolute path (e.g.
   `/usr/bin/apt-get ...`) or that explicitly bypasses function lookup
   (e.g. `command apt-get ...`). Read the phase's actual source before
   picking a mechanism; if it hardcodes an absolute path, stubbing the
   bare name won't help — treat that as a sign the exercise itself
   shouldn't invoke the effect directly, and isolate the pure decision
   logic (step 1) as the thing under test instead.

   **`sudo X` is a third escape hatch, and the dangerous one to miss.**
   `export -f` does not help here: `sudo` execs the real target binary
   directly rather than going through a login/interactive shell that would
   consult exported bash functions, so a stubbed `apt-get() { ... }`
   exported into the environment is never consulted for a `sudo apt-get
   ...` call — the real `apt-get` runs, for real, under root. A `PATH`
   prepend aimed at the *inner* command (`apt-get`) is also unreliable:
   `sudo` on many systems resolves commands through its own configured
   `secure_path`, ignoring the caller's `PATH` for the command it execs.
   Do not stub the inner command and assume a `sudo`-wrapped call is
   contained.

   What does work: stub `sudo` itself, not the command after it. The name
   `sudo` is resolved through the *calling* shell's `$PATH` before `sudo`
   ever gets to apply its own `secure_path` to anything, so a fake `sudo`
   script placed on a prepended `PATH` (the same prepend mechanism as step
   4, just naming the fake executable `sudo` instead of `apt-get`) does
   intercept it — verified: a fake `sudo` on a prepended `PATH`, invoked as
   `sudo apt-get install -y jq`, logged `apt-get install -y jq` and exited
   0 without ever calling the real `apt-get`; separately, an `export -f
   apt-get` stub was confirmed to NOT be consulted when the same command
   was invoked as `sudo apt-get ...` — the real `sudo` ran and the stub's
   log stayed empty. If you're uneasy relying on a fake `sudo` (e.g. the
   phase's code branches on `sudo`'s own exit code or output in ways a
   thin fake might not replicate faithfully), the more conservative
   fallback is to not invoke the entry point through `sudo` at all: fall
   back to the pure-decision-logic extraction this section's step 1
   already describes — test what the implementation *would* do (which
   package, which flags) directly, rather than attempting to invoke a
   `sudo`-wrapped entry point at all.

Example, for a phase whose exercise is "implement `do_provision`" (wired
into the `provision` subcommand) in `practice/05-provision/provision.sh`,
where `do_provision` shells out to `apt-get install` — not a `$HOME`-
relative path, so Technique 1 alone would provide no containment:

```bash
#!/usr/bin/env bash
set -euo pipefail

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
failed=0

script="$(cd "$(dirname "$0")" && pwd)/provision.sh"

export record="$scratch/apt-calls.log"
apt-get() { echo "$*" >> "$record"; }
export -f apt-get

if ( cd "$scratch" && HOME="$scratch" bash "$script" provision > /dev/null ); then
  echo "PASS: 'provision.sh provision' ran without error"
else
  echo "FAIL: running 'provision.sh provision' raised an error — check the implementation for a syntax or runtime error"
  failed=1
fi

if [[ -f "$record" ]] && grep -qE '^install .*-y.* jq' "$record"; then
  echo "PASS: provisioning installs jq via apt-get"
else
  echo "FAIL: provisioning did not call apt-get to install jq"
  failed=1
fi

exit "$failed"
```

The real `apt-get` on `$PATH` never runs — the exported function shadows
it inside the child `bash provision.sh provision` process, and the
assertion checks the recorded call instead of any real system state.

## Both strategies

- Print one `PASS:`/`FAIL:` line per assertion — never stop at the first
  failure. Give each assertion its own `if`/`else` that sets a `failed`
  flag (as in both examples above) rather than `exit 1`-ing inline, and
  `exit "$failed"` (or equivalent) once, at the end. A learner who fails
  three assertions needs to see all three `FAIL:` lines in one run, not
  just the first.
- Exit non-zero if any assertion failed.
- Every invocation of the learner's code within a single check — not just
  the first — must use the containment appropriate to that strategy (the
  `HOME`/cwd override, the stub, or both). There is no un-prefixed,
  un-stubbed call to the learner's code anywhere in a Strategy B check.
- Never delete or overwrite anything in the learner's `practice/`
  directory itself — checks read the learner's file, they don't rewrite
  it. This applies regardless of strategy: whenever the code under test
  writes anything, the invocation's working directory must not be
  `practice/NN-.../` itself — a relative-path write the code makes (or
  builds from `pwd`) lands wherever the process's cwd is. Always run the
  invocation with cwd inside a scratch directory (see Technique 1, step 4,
  and Strategy A's entry-point fallback above). `HOME` alone does not
  change cwd and is not a substitute for this — and the `HOME` override
  itself is Strategy-B-only; a Strategy A phase never needs it, only the
  cwd redirect when it writes anything.
- Checks run under `set -euo pipefail`. Guard any command whose natural
  nonzero exit doesn't mean "the assertion failed" — e.g. `grep` on a
  pattern that isn't found, or a file that doesn't exist — inside an
  `if`/`else` (as every assertion above does) rather than letting it run
  bare. A bare failing command outside an `if` condition aborts the whole
  script under `set -e` before its `FAIL:` line ever prints, which looks
  like the check itself crashed rather than reporting a failure. This
  applies just as much to a command substitution captured into a variable
  ahead of the `if` that checks it (e.g. `result="$(some_function args)"`)
  as to a command written directly inside an `if` condition — against a
  broken or untouched learner implementation where `some_function` doesn't
  exist or returns nonzero, a bare capture like that dies silently under
  `set -e` with no `FAIL:` line at all. Guard it the same way:
  `result="$(some_function args || echo '<error>')"`, so the assertion
  below it still runs and reports a diagnostic `FAIL:` instead of the whole
  script exiting with zero output.
