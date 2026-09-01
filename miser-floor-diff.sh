#!/usr/bin/env bash
# miser-floor-diff.sh - measure Claude Code's fixed per-session token overhead,
# and the delta a settings change makes to it.
#
# Born from the 2026-09-01 miser audit, where the method mattered more than the
# numbers: the first attempt measured the wrong thing three separate ways. The
# script exists so the next audit does not re-derive it (the original lived in a
# session scratchpad and died with the session).
#
# Usage:
#   ./miser-floor-diff.sh                       # baseline floor only
#   ./miser-floor-diff.sh '.disableWorkflows = true'
#   ./miser-floor-diff.sh 'del(.hooks)' '.permissions.deny += ["Artifact"]'
#
# Each argument is a jq filter applied to a COPY of ~/.claude/settings.json,
# producing one variant; every variant is measured and diffed against baseline.
#
# WHAT THIS DOES NOT MEASURE: the interactive-only surface. The 2026-09-01 audit
# found the headless floor FLAT (20,183 vs 20,654 in July) while the interactive
# floor regressed 19.3K -> 27.1K. Headless proves whether USER CONFIG degraded.
# Interactive drift needs a fresh interactive session and /context. Do both.

set -uo pipefail

PROMPT="${MISER_DIFF_PROMPT:-say ok}"
RUNS="${MISER_DIFF_RUNS:-1}"
BASE_SETTINGS="${MISER_DIFF_SETTINGS:-$HOME/.claude/settings.json}"

command -v jq >/dev/null || { echo "FATAL: jq required" >&2; exit 1; }
command -v claude >/dev/null || { echo "FATAL: claude required" >&2; exit 1; }
[ -f "$BASE_SETTINGS" ] || { echo "FATAL: no settings at $BASE_SETTINGS" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# GOTCHA 1: Claude Code ranks ANTHROPIC_API_KEY above the claude.ai login and
# does not fall back when the key fails, so a broken key anywhere in the
# environment kills the run (exit 1, no API call, zero tokens). The key was
# deleted from Infisical dev on 2026-09-01; this line stays as a guard, because
# any key that reaches the environment reproduces the failure.
run_claude() {
  env -u ANTHROPIC_API_KEY claude -p "$PROMPT" \
    --output-format json --settings "$1" 2>/dev/null
}

# GOTCHA 2: totals must sum cache_creation + cache_read + input. Prompt caching
# moves the same fixed preamble between those buckets run to run; reading
# cache_creation alone reports a "drop" that is really a cache hit.
total_tokens() {
  jq -r '(.usage.input_tokens // 0)
       + (.usage.cache_creation_input_tokens // 0)
       + (.usage.cache_read_input_tokens // 0)' 2>/dev/null
}

measure() {
  local settings_file="$1" label="$2" best="" t out
  for _ in $(seq 1 "$RUNS"); do
    out="$(run_claude "$settings_file")"
    t="$(printf '%s' "$out" | total_tokens)"
    if [ -z "$t" ] || [ "$t" = "null" ] || [ "$t" -eq 0 ] 2>/dev/null; then
      echo "  ! measurement failed for $label (auth? see GOTCHA 1)" >&2
      printf '%s' "$out" | head -c 300 >&2; echo >&2
      return 1
    fi
    # Lowest run is the honest floor: retries and tool calls only add.
    if [ -z "$best" ] || [ "$t" -lt "$best" ]; then best="$t"; fi
  done
  printf '%s' "$best"
}

# GOTCHA 4: the floor is cwd-sensitive - project context (CLAUDE.md, .claude/)
# loads into headless runs too. 2026-09-01: 20,661 from $HOME vs 23,143 from
# inside dev-resources/context-mode, same settings, same version. Compare
# baselines only against readings taken from the same cwd; $HOME is the
# reference.
echo "settings : $BASE_SETTINGS"
echo "prompt   : $PROMPT   (runs per variant: $RUNS)"
echo "claude   : $(claude --version 2>/dev/null | head -1)"
# GOTCHA 5: the floor is model-dependent - Fable defers most built-in tool
# schemas that Sonnet loads in full, and the settings `model` key rides along
# into every variant copy. Record the model with every reading.
echo "model    : $(jq -r '.model // "unset"' "$BASE_SETTINGS")"
echo "cwd      : $PWD"
echo

# GOTCHA 3: --settings REPLACES the settings file, it does not merge. Measuring
# "current config plus one change" means jq-merging a full copy and passing
# that. Passing a one-key file measures a machine with no user config at all.
cp "$BASE_SETTINGS" "$TMP/baseline.json"
baseline="$(measure "$TMP/baseline.json" baseline)" || exit 1
printf 'baseline  %8s tokens\n' "$baseline"

i=0
for filter in "$@"; do
  i=$((i + 1))
  variant="$TMP/variant-$i.json"
  if ! jq "$filter" "$BASE_SETTINGS" > "$variant" 2>"$TMP/jqerr"; then
    echo "  ! bad jq filter: $filter" >&2; cat "$TMP/jqerr" >&2; continue
  fi
  v="$(measure "$variant" "variant $i")" || continue
  printf 'variant %d  %8s tokens  (%+d vs baseline)  %s\n' \
    "$i" "$v" "$((v - baseline))" "$filter"
done

echo
echo "Record the result: wiki OpenBrain-Wiki/Miser Stack.md (Invocation layer"
echo "baseline line) and ~/.claude/last-audited-version. /usage-audit does both."
