#!/usr/bin/env bash
#
# validate-on-edit.sh — PostToolUse hook: run the repo validators the moment a
# contract-bearing file changes, instead of hoping someone remembers CLAUDE.md
# Section 10 before committing.
#
# Wired from .claude/settings.json (PostToolUse, matcher Write|Edit). Reads the
# hook payload on stdin and no-ops for any path that isn't a SKILL.md,
# plugin.json, or marketplace.json — every other edit costs one `case` test.
#
# On failure it emits decision:"block" with the validator output as the reason,
# so the model gets the error back and fixes it in the same turn.
#
# Exit 0 always — a hook that dies must never be mistaken for a clean check.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

path="$(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); raise SystemExit(0)
ti = d.get("tool_input") or {}
tr = d.get("tool_response") or {}
print(tr.get("filePath") or ti.get("file_path") or "")
' 2>/dev/null)"

case "$path" in
  */SKILL.md|*/plugin.json|*/marketplace.json) ;;
  *) exit 0 ;;
esac

fm_out="$("$REPO_ROOT/scripts/validate-frontmatter.sh" 2>&1)"; fm=$?
ct_out="$("$REPO_ROOT/scripts/validate-contract.sh" 2>&1)"; ct=$?

if [[ $fm -eq 0 && $ct -eq 0 ]]; then
  exit 0
fi

# Only the failing validator's tail is worth feeding back — the pass lines are noise.
REASON="$(
  { [[ $fm -ne 0 ]] && printf 'validate-frontmatter.sh failed:\n%s\n' "$(printf '%s' "$fm_out" | grep -E '❌|error:|warn:|summary:' | tail -20)"
    [[ $ct -ne 0 ]] && printf 'validate-contract.sh failed:\n%s\n' "$(printf '%s' "$ct_out" | grep -E '❌|FAIL|error:|summary:' | tail -20)"
  } 2>/dev/null
)" \
REASON="$REASON" python3 -c '
import json, os
print(json.dumps({
    "decision": "block",
    "reason": "claude-kit validators failed after this edit — fix before continuing (CLAUDE.md Section 10):\n"
              + os.environ.get("REASON", "").strip(),
    "systemMessage": "claude-kit: contract validators failed — see the blocked reason",
}))
'
exit 0
