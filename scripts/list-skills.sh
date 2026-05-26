#!/usr/bin/env bash
#
# list-skills.sh — enumerate every SKILL.md across all plugins
#
# Outputs a table with plugin · name · type · status · version · location.
# By default skips _in-progress/ and _deprecated/; pass --all to include.
#
# Exit codes:
#   0   listing produced
#   2   no skills found
#
# Usage:
#   ./scripts/list-skills.sh                    # stable + experimental only (not draft / deprecated)
#   ./scripts/list-skills.sh --all              # include _in-progress/ + _deprecated/
#   ./scripts/list-skills.sh --plugin react-core
#   ./scripts/list-skills.sh --type gate
#   ./scripts/list-skills.sh --status experimental

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDE_ALL=0
PLUGIN_FILTER=""
TYPE_FILTER=""
STATUS_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) INCLUDE_ALL=1; shift ;;
    --plugin) PLUGIN_FILTER="${2:-}"; shift 2 ;;
    --type) TYPE_FILTER="${2:-}"; shift 2 ;;
    --status) STATUS_FILTER="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

extract_frontmatter() {
  awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$1"
}

yaml_get_metadata() {
  local key="$1" block="$2"
  printf '%s\n' "$block" | awk -v k="$key" '
    /^metadata:[[:space:]]*$/ { in_meta = 1; next }
    in_meta && /^[^[:space:]]/ { in_meta = 0 }
    in_meta {
      if (match($0, "^[[:space:]]+" k ":[[:space:]]+")) {
        val = substr($0, RLENGTH + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
        gsub(/"/, "", val)
        print val
        exit
      }
    }
  '
}

base="$REPO_ROOT/plugins"
if [[ -n "$PLUGIN_FILTER" ]]; then
  base="$REPO_ROOT/plugins/$PLUGIN_FILTER"
  [[ -d "$base" ]] || { echo "plugin not found: $PLUGIN_FILTER" >&2; exit 2; }
fi

files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(find "$base" -type f -name SKILL.md -print0)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "no SKILL.md files found" >&2
  exit 2
fi

printf "%-25s %-20s %-12s %-14s %-8s %s\n" "SKILL" "PLUGIN" "TYPE" "STATUS" "VERSION" "PATH"
printf "%-25s %-20s %-12s %-14s %-8s %s\n" "-----" "------" "----" "------" "-------" "----"

shown=0
for f in "${files[@]}"; do
  if [[ $INCLUDE_ALL -eq 0 ]]; then
    [[ "$f" == *"/_in-progress/"* ]] && continue
    [[ "$f" == *"/_deprecated/"* ]] && continue
  fi

  rel="${f#"$REPO_ROOT/"}"
  plugin="$(echo "$rel" | awk -F/ '{print $2}')"
  skill_name="$(basename "$(dirname "$f")")"
  block="$(extract_frontmatter "$f")"
  type="$(yaml_get_metadata type "$block")"
  status="$(yaml_get_metadata status "$block")"
  version="$(yaml_get_metadata version "$block")"

  [[ -n "$TYPE_FILTER"   && "$type"   != "$TYPE_FILTER"   ]] && continue
  [[ -n "$STATUS_FILTER" && "$status" != "$STATUS_FILTER" ]] && continue

  printf "%-25s %-20s %-12s %-14s %-8s %s\n" \
    "$skill_name" "$plugin" "${type:-?}" "${status:-?}" "${version:-?}" "$rel"
  shown=$((shown + 1))
done

echo ""
echo "$shown skill(s) shown"
