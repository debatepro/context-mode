#!/bin/bash
# Miser acceptance harness — see MAINTENANCE-MISER.md. 7/7 PASS required before push.
cd "$(dirname "$0")" || exit 1
export CLAUDE_PLUGIN_ROOT=$PWD
P=0; F=0
ck() { if eval "$2"; then echo "PASS $1"; P=$((P+1)); else echo "FAIL $1"; F=$((F+1)); fi; }

OUT=$(echo '{"session_id":"x","source":"startup"}' | node hooks/sessionstart.mjs); RC=$?
ck "1 sessionstart exit 0"        "[ $RC -eq 0 ]"
BYTES=$(printf '%s' "$OUT" | wc -c | tr -d ' ')
ck "2 rendered <= 2400B ($BYTES)" "[ $BYTES -le 2400 ]"
ck "3 valid JSON"                 "printf '%s' \"\$OUT\" | python3 -c 'import json,sys;json.load(sys.stdin)' 2>/dev/null"
ck "4 block present"              "printf '%s' \"\$OUT\" | grep -q context_window_protection"
ck "5 full prefix documented"     "printf '%s' \"\$OUT\" | grep -q mcp__plugin_context-mode_context-mode__ctx_search"
ck "6 pretooluse exit 0"          "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"},\"session_id\":\"x\"}' | node hooks/pretooluse.mjs >/dev/null 2>&1"
ck "7 exports importable"         "node -e 'import(\"./hooks/routing-block.mjs\").then(m=>process.exit(m.ROUTING_BLOCK&&m.BASH_GUIDANCE?0:1))' 2>/dev/null"

echo "$P/7 PASS"
[ $F -eq 0 ]
