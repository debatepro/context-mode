# Miser patch process (local fork maintenance)

**Read this before updating context-mode.** This checkout is Jeremy's mirror
(`origin` = debatepro/context-mode), not the author's repo
(`upstream` = mksglu/context-mode, author Mert Koseoğlu). It carries local
patches that a naive upgrade would regress.

## Local patches on main

1. `fix(batch)`: NODE_OPTIONS export on its own line (5f1e6e5)
2. `trim`: compact sessionstart routing block, 4801B → 2277B rendered (f70cf43)
   — same routing policy, half the tokens; prefix named once, prose compressed.
3. `trim`: per-call guidance tips + skill frontmatter to one-liners
   (4e46dd0, e1bc87b — formerly mirror-only 84f6691/c2d391d, upstreamed 2026-07-28)
4. `fix(shell)`: zsh word-split prelude + stderr surfaced on all ctx_execute
   paths (f207719) — silent-empty-grep bug.
5. `fix(hooks)`: breadcrumb sweep uses unlinkSync for symlinks (1d488a8) —
   `rmSync` on a dangling symlink is a **silent no-op on Node 24.9–24.12**;
   also adds sweep failure logging + widens CI to node 22.5 + 24.
6. `test`: assertions aligned with the trimmed routing-block wording (ef317d2).
7. `feat(hooks)`: Precedence bullet in the routing block - the user's CLAUDE.md
   routing policy outranks ctx boundaries and raw-Bash harness modes (9ed7df9),
   compacted 2026-09-01 to re-fit the 2400B rendered budget (2507B -> 2393B).

Released as **v1.0.171** (fork version, bumped ahead of upstream's 1.0.169 —
see the version-collision note below).

## Update procedure

```sh
git fetch upstream
# content-diff, ignoring bundle/CI noise (history counts are meaningless — mirror is a squash):
git diff --stat HEAD upstream/main -- . ':!*.bundle.mjs' ':!*stats*'
git merge upstream/main        # resolve in hooks/routing-block.mjs in favor of the compact form
bash miser-acceptance.sh       # must print 7/7 PASS
npm test                       # full suite — MANDATORY since 2026-07-28 (see CI note)
git push origin main           # push triggers fork CI (3 OS × node 22.5 + 24)
```

If upstream changed the injected prose (`hooks/routing-block.mjs`), show Jeremy
the before/after **text** for approval — he QAs wording and logic, not code.
Code correctness is the acceptance script's job, never his.

**Version-collision warning:** the fork's version (1.0.170) is now ahead of
upstream's. When upstream ships its own 1.0.170+, the merge will conflict in
all 11 version manifests — resolve by taking upstream's number, then re-bump
with `npm version patch` (it syncs every manifest and tags). Never hand-edit
version fields; there are 11 of them.

## Fork CI (enabled 2026-07-28 — was NEVER running before)

The fork had **zero Actions runs in its history**: GitHub silently drops
workflow triggers on forks until enabled once in the web UI (done). Every
mirror patch before this date shipped untested — the first-ever run caught 20
stale test assertions from the 07-22 trims. Now: push to main triggers CI
(3 OS × node 22.5 + 24, matching `engines >=22.5.0`). `miser-acceptance.sh`
remains the fast local pre-push gate; the full suite is the real one.

## Deploy: push-based (primary) or hand-copy (same-session only)

**Primary path (since 2026-07-28):** commit → `npm version patch` → push →
the marketplace clone (`~/.claude/plugins/marketplaces/context-mode`) pulls on
plugin update → Claude Code builds a fresh cache version dir. The clone MUST
stay clean: `cli.ts` skips `git pull` when it has local edits, which silently
wedges all future updates (this happened; unwedged 2026-07-28).

**Hand-copy (only to test a patch in the current session, before a release):**
Claude Code executes hooks from the installed-plugin cache, **not** this
checkout: `~/.claude/plugins/cache/context-mode/context-mode/<version>/hooks/`.

```sh
V=$(ls ~/.claude/plugins/cache/context-mode/context-mode/ | sort -V | tail -1)
cp hooks/routing-block.mjs ~/.claude/plugins/cache/context-mode/context-mode/$V/hooks/
# verify the deployed copy renders compact:
echo '{}' | node ~/.claude/plugins/cache/context-mode/context-mode/$V/hooks/sessionstart.mjs | head -c 400
```

Never hand-copy into the marketplace clone (it dirties the git tree and wedges
updates — see above). Anything hand-copied into the cache must land on fork
main in the same sitting, or the next cache rebuild silently reverts it.

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

Re-run /usage-audit after every Claude Code version bump - mechanized since
2026-09-01 by `~/.claude/hooks/version-tripwire.py` (SessionStart, fires only
on mismatch vs `~/.claude/last-audited-version`). The measurement method lives
in this repo: `miser-floor-diff.sh` (jq-filter variants of settings.json,
headless floor + deltas; read its GOTCHA comments before trusting any number).
Floors are model-, cwd-, and version-sensitive - record all three with every
reading; $HOME is the reference cwd.

History: the 2026-07 bloat (27.9k total) was harness-side, not user config;
post-trim baseline 19.3k (2026-07-22). 2026-09-01: interactive floor on Sonnet
39.8k stock, 26.9k under `claude-lean` (denies Artifact at 9.9k plus
WebFetch/WebSearch/NotebookEdit/Agent/Task at 2.9k combined; wrapper
regenerates its profile from live settings.json each launch); headless 20,661
from $HOME. Full numbers and changelog: OpenBrain-Wiki/Miser Stack.md.

## CBM auto-index hook (2026-07-22)

`~/.claude/hooks/cbm-auto-index` (SessionStart startup+resume) refreshes the
current repo's CBM graph in the background; log at
$CBM_CACHE_DIR/auto-index.log. Repos >10k files stay manual (terminal CLI).
Follow-up filed here: the CBM warm server caches project graphs in RAM at
first query — a server-side DB-mtime invalidation would close mid-session
staleness; revisit on next CBM binary update.
