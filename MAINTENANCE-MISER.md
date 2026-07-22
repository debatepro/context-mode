# Miser patch process (local fork maintenance)

**Read this before updating context-mode.** This checkout is Jeremy's mirror
(`origin` = debatepro/context-mode), not the author's repo
(`upstream` = mksglu/context-mode, author Mert Koseoğlu). It carries local
patches that a naive upgrade would regress.

## Local patches on main

1. `fix(batch)`: NODE_OPTIONS export on its own line (5f1e6e5)
2. `trim`: compact sessionstart routing block, 4801B → 2277B rendered (f70cf43)
   — same routing policy, half the tokens; prefix named once, prose compressed.

## Update procedure

```sh
git fetch upstream
# content-diff, ignoring bundle/CI noise (history counts are meaningless — mirror is a squash):
git diff --stat HEAD upstream/main -- . ':!*.bundle.mjs' ':!*stats*'
git merge upstream/main        # resolve in hooks/routing-block.mjs in favor of the compact form
bash miser-acceptance.sh       # must print 7/7 PASS
git push origin main
```

If upstream changed the injected prose (`hooks/routing-block.mjs`), show Jeremy
the before/after **text** for approval — he QAs wording and logic, not code.
Code correctness is the acceptance script's job, never his.

## Acceptance harness

`miser-acceptance.sh` — checks: sessionstart exits 0, rendered block ≤ 2400 B,
valid JSON, block present, full tool prefix documented, pretooluse exits 0,
all routing-block exports importable. Any FAIL blocks the push.
