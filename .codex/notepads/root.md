# Root orchestration notepad — control-plane reset

## Objective

Restore the clean GCC devcontainer and admitted OpenSymphony workflow before starting another C++
product subsystem. Canonical checklist: `.codex/goals/standalone-cpp26-v2.md`.

## Repository identity

- Root: `/Users/rmanaloto/dev/symphony-cpp`
- Branch: `codex/implementation`
- Local HEAD: `b0b9d8b8f832f0c55688cd571688172dfdde8b51`
- Upstream/remote: `b0b9d8b8f832f0c55688cd571688172dfdde8b51`
- Divergence: ahead 0, behind 0
- Remote: `git@github.com:ray-manaloto/symphony-cpp.git`
- Published checkpoint: reviewed, publication-scanned, and Source-CI-green
  `CONTROL-EVIDENCE-DOMAIN-001`

## Active phase

`R1 — Make orchestration mechanically efficient`.

R0 is complete. `R1-GOAL-RESET-001B` is the active atomic slice after two archived partial
attempts. It owns the reset documents, dependency evidence, exact Git index/worktree guard, and
hostile fixtures together. A first normal review found ignored-untracked and Git-diagnostic false
accepts; corrected bytes now pass Bash syntax, ShellCheck, the real repository guard, and all 12
valid/hostile cases. Complete quick preflight, archive hashes, executable modes, dependency
policy, diff hygiene, and line ceilings pass on exactly 19 staged paths. Next, freeze one immutable
snapshot, obtain a fresh corrected normal/adversarial pair, and commit without pushing. A normal
review of tree `8609e520…` subsequently found a missing modified-tracked fixture and a valid
`ls-files` error-handling gap. Corrected focused tests now pass all 14 cases, but the full
preflight, dependency policy, archive hashes, executable modes, diff hygiene, and line ceilings
also pass on exactly 19 staged paths with no unstaged drift. Freeze a new immutable snapshot for the
fresh normal/adversarial pair. The normal review of tree `f9ffff79…` then found a non-index-only
fixture and caller-directory coupling. Corrected focused tests prove true index-only rejection and
pass from both the repository root and `/tmp`; full-preflight/snapshot evidence is invalidated.
Stage and revalidate before a new review. Do not split the guard again or start
publisher/verifier work first.

## Reset evidence

- Pre-reset goal: 1,800+ lines; archived at
  `.codex/goals/archive/standalone-cpp26-2026-07-26-pre-reset.md`.
- Pre-reset notepad: 946 lines; archived at
  `.codex/notepads/archive/root-2026-07-26-pre-reset.md`.
- Five terminal blocked audits came from granular authority exhaustion, not product impasse.
- Four publication attempts lost idle SSH behind 12–16 minute unconditional Docker pre-push gates.
- Normal seven-command review: 272,331 cumulative input tokens.
- Adversarial three-command review: 109,495 tokens, 59.8% lower, same zero-finding result.
- A broad xhigh reset adversary again exceeded repeated stop requests and was terminated without
  evidence; packet shape, not more effort, is the controlling correction.

## Environment state

- Running GCC container was created by Dev Container CLI but uses prohibited historical
  `symphony-dev:edge` digest `d4ee55fe…`.
- Its embedded metadata predates current mise/pre-commit mounts.
- Checked-in GCC devcontainer still names the mutable prohibited tag.
- Analysis and clang-p2996 admitted devcontainer images are unavailable.
- Dev Container CLI is exactly 0.88.0.
- OpenSymphony qualified image is absent; `memory-status` fails closed before container startup.
- Upstream #227 remains open; upstream `main` remains pinned v2.10.0 commit `0cc21ddd…`.

## Authority

- Standing bounded read-only review envelope is defined in the reset goal.
- The historical pre-reset canary is consumed. The owner-provided native reset objective
  separately authorizes exactly one post-reset fixture-only OpenSymphony canary after every
  admission gate and forbids a second post-reset canary.
- No current authority for image publication, an OpenSymphony upstream PR, tracker mutation,
  deployment, credentials inspection, force-push, or rebase.
- LINEAR_API_KEY value must never be retrieved, printed, inspected, or committed.

## Counters carried across reset

- Historical review/process failures and token use do not reset; see archived ledger.
- Current reset advisors: one completed xhigh report; one broad xhigh adversary terminated for
  noncompliant latency/stop behavior.
- Bounded reset-document reviewer found one R0/R1 receipt-ordering P1; corrected by separating the
  one-time legacy retry from future reusable receipt machinery.
- Fresh bounded reset adversary found and the goal now corrects: missing-telemetry rollover,
  slice-wide cumulative retry budgets, and mandatory reproducible slice capsules.
- First atomic-tree normal review found two P1 routing false accepts: ignored untracked references
  and Git object-read diagnostics reported with exit status 1. Corrected fixtures now cover both;
  a fresh identical-byte review pair remains required.
- Corrected-tree normal review found one coverage gap and one `ls-files` diagnostic gap. A new
  tracked-worktree case disproves the claimed false accept; the valid diagnostic gap is fixed.
- Final-tree normal review found two P2 fixture defects: index-only restoration used the index, and
  checker lookup depended on the caller's directory. Both are corrected and focused-regressed.
- Credential safety incident: a process diagnostic emitted inherited environment data into this
  task's tool output. No values were written to the repository. Treat affected credentials as
  exposed and rotate them outside repository scope; never repeat their values.
- Current native context utilization/compaction telemetry: unavailable; do not estimate.
- Missing-telemetry fallback: one atomic slice, 12 controller tool calls, or 30 minutes per turn,
  followed by a durable checkpoint and fresh turn/process.
- Expensive pre-push result passed once for exact `b0b9d8b8…`; the exception was consumed.
- Source CI `30222627774`: success; preflight 23s, GCC 16.1 job 4m20s, total execution 4m46s.

## Stop conditions

- Stop the R0 retry on identity drift, reviewed-byte change, staged paths, unexpected dirty paths,
  or failed Source CI. Require the durable receipt binding for every later push.
- Keep OpenSymphony fail-closed without exact upstream suite and image labels.
- Do not use the stale devcontainer as final conformance evidence.
- Do not append history here; replace this checkpoint and keep the file below 150 lines.
