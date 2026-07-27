# R1-RECEIPT-ATOMIC-READ-001 — atomic receipt verification

## Observable contract

Receipt verification opens the configured receipt path exactly once with no symlink following,
checks regular-file type, mode `0600`, and the 64-KiB bound on that descriptor, reads bounded bytes
from the same descriptor, and rejects descriptor metadata changes during the read. The pre-push
path verifies the receipt once before and once immediately after its final Git-context check.

## Failure-first fixtures

- Replace the receipt path after the descriptor opens: the current read must retain the original
  descriptor bytes and the next verification must reject the replacement.
- Mutate the receipt after the first hook verification: the second verification must reject it.
- Preserve all missing, symlink, wrong-mode, oversized, malformed, stale, future, forged,
  ref-movement, multiple-destination, and golden local-bare-push fixtures.

## Maintained mechanism

Use pinned Node.js built-ins `openSync(O_RDONLY | O_NOFOLLOW)`, `fstatSync`, bounded `readSync`, and
`closeSync`; use existing Git context resolution and receipt schema. No new dependency or custom
storage protocol is introduced. The decision is recorded before implementation in
`docs/dependency-decisions.md`.

## Owned paths

- `.codex/goals/standalone-cpp26-v2.md`
- `.codex/notepads/root.md`
- `.codex/notepads/r1-change-routed-hook-001.md`
- `.codex/notepads/r1-receipt-atomic-read-001.md`
- `docs/dependency-decisions.md`
- `docs/implementation-log.md`
- `scripts/check-push-route.mjs`
- `scripts/test-push-route.mjs`

## Validation and pass condition

- `node scripts/test-push-route.mjs --quick`
- `node scripts/test-push-route.mjs`
- `./scripts/check-local-preflight.sh quick`
- Exact immutable snapshot receives normal/high and adversarial/xhigh PASS reviews.

Pass only when both deterministic race fixtures fail before the implementation, pass afterward,
all inherited fixtures remain green, and reviewed bytes match the staged tree.

## Evidence

- Failure-first quick run: failed at the reopened replacement with `publication receipt is
  malformed`.
- Implemented quick fixtures: PASS, 23.15 seconds.
- Full integration: PASS, 40.77 seconds.
- Complete quick preflight: PASS, 52.97 seconds, no Docker.
- Normal/xhigh and bounded adversarial/xhigh reviews: PASS on tree `0a47fd0d…`.
- Commit `3b17751887f5192e7b0b2bbe4be7a4faaaf77463` has exact tree `0a47fd0d…`.

## Stop conditions

Stop on any false receipt acceptance, descriptor leak, hook duration above five seconds, unexpected
path drift, changed reviewed bytes, or four cumulative review inferences. Do not broaden this slice
into general publication, OpenSymphony, devcontainer, C++, workflow, tracker, or credential work.
