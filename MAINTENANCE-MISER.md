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

## Deploy to the running cache (mandatory — patches don't take effect without it)

Claude Code executes hooks from the installed-plugin cache, **not** this checkout:
`~/.claude/plugins/cache/context-mode/context-mode/<version>/hooks/`. Patching
and pushing here changes nothing at session start until the patched files are
copied into the current cache version dir:

```sh
V=$(ls ~/.claude/plugins/cache/context-mode/context-mode/ | sort -V | tail -1)
cp hooks/routing-block.mjs ~/.claude/plugins/cache/context-mode/context-mode/$V/hooks/
# verify the deployed copy renders compact:
echo '{}' | node ~/.claude/plugins/cache/context-mode/context-mode/$V/hooks/sessionstart.mjs | head -c 400
```

**`ctx upgrade` does NOT deploy the mirror.** Verified 2026-07-22 against the
v1.0.169 cli bundle: it git-resets this checkout to `origin/HEAD` (mirror — safe),
but rebuilds the cache from a fresh clone of **upstream mksglu/context-mode**,
and only when upstream's version is newer. Consequences:

- Same upstream version → cache untouched; patches must be hand-copied (above).
- Newer upstream version → cache rebuilt **unpatched** into a new version dir.
  After any `ctx upgrade`, re-run the merge procedure and re-deploy to the new
  `$V` dir, then re-verify.

## Acceptance harness

`miser-acceptance.sh` — checks: sessionstart exits 0, rendered block ≤ 2400 B,
valid JSON, block present, full tool prefix documented, pretooluse exits 0,
all routing-block exports importable. Any FAIL blocks the push.

## Token-budget watch

Re-run /usage-audit after every Claude Code version bump. The 2026-07 bloat
(27.9k total) was harness-side — system tools grew 8.7k→15.9k across two
weeks — not user config. Baseline after trims (2026-07-22): 19.3k total
(system tools 8.2k with disableWorkflows:true + ReportFindings denied).

## CBM auto-index hook (2026-07-22)

`~/.claude/hooks/cbm-auto-index` (SessionStart startup+resume) refreshes the
current repo's CBM graph in the background; log at
$CBM_CACHE_DIR/auto-index.log. Repos >10k files stay manual (terminal CLI).
Follow-up filed here: the CBM warm server caches project graphs in RAM at
first query — a server-side DB-mtime invalidation would close mid-session
staleness; revisit on next CBM binary update.
