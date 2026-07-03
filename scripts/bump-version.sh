#!/usr/bin/env bash
#
# bump-version.sh — one-command plugin version bump
#
# Does the bookkeeping ritual from CLAUDE.md Section 12 (steps 2-4) in one shot:
#   1. bumps plugins/<plugin>/.claude-plugin/plugin.json (the consumers' cache key)
#   2. mirrors the new version into .claude-plugin/marketplace.json
#   3. inserts a CHANGELOG.md stub under ## [Unreleased] (fill in the TODO)
#
# The skill's own metadata.version stays manual — you bump it in the same edit
# that changes the skill. Verify the result with ./scripts/validate-contract.sh
# (rule 4 checks the plugin/marketplace mirror).
#
# Usage:
#   ./scripts/bump-version.sh <plugin> <patch|minor|major>
#   ./scripts/bump-version.sh dev-core minor
#
# Exit codes: 0 bumped · 2 bad usage / unknown plugin

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '3,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

if [[ $# -ne 2 ]]; then usage; exit 2; fi
case "$1" in -h|--help) usage; exit 0 ;; esac

plugin="$1"
part="$2"

pj="$REPO_ROOT/plugins/$plugin/.claude-plugin/plugin.json"
mp="$REPO_ROOT/.claude-plugin/marketplace.json"
cl="$REPO_ROOT/CHANGELOG.md"

[[ -f "$pj" ]] || { echo "unknown plugin: $plugin ($pj not found)" >&2; exit 2; }
case "$part" in
  patch|minor|major) ;;
  *) echo "bump part must be patch|minor|major, got: $part" >&2; exit 2 ;;
esac

cur="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$pj" | head -1 | sed -E 's/.*"([^"]+)"/\1/')"
IFS='.' read -r maj min pat <<< "$cur"
case "$part" in
  major) new="$((maj + 1)).0.0" ;;
  minor) new="$maj.$((min + 1)).0" ;;
  patch) new="$maj.$min.$((pat + 1))" ;;
esac

# 1. plugin.json — first "version" line
tmp="$(mktemp)"
awk -v old="\"$cur\"" -v newv="\"$new\"" '
  !done && /"version"/ { sub(old, newv); done = 1 }
  { print }
' "$pj" > "$tmp" && mv "$tmp" "$pj"

# 2. marketplace.json — the "version" inside this plugin entry
tmp="$(mktemp)"
awk -v needle="\"name\": \"$plugin\"" -v newv="$new" '
  index($0, needle) { hit = 1 }
  hit && /"version"/ { sub(/"[0-9]+\.[0-9]+\.[0-9]+"/, "\"" newv "\""); hit = 0 }
  { print }
' "$mp" > "$tmp" && mv "$tmp" "$mp"

# verify the mirror landed (same extraction rule 4 uses)
mver="$(grep -A8 "\"name\"[[:space:]]*:[[:space:]]*\"$plugin\"" "$mp" \
          | grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' \
          | sed -E 's/.*"([^"]+)"/\1/')"
if [[ "$mver" != "$new" ]]; then
  echo "❌ marketplace.json mirror failed (entry for $plugin not updated — check its formatting)" >&2
  exit 2
fi

# 3. CHANGELOG stub under [Unreleased]; drop the _Nothing yet._ placeholder
tmp="$(mktemp)"
awk -v plug="$plugin" -v newv="$new" '
  /^_Nothing yet\._$/ { next }
  { print }
  /^## \[Unreleased\]$/ {
    print ""
    print "### `" plug "` " newv
    print "- TODO: describe the change"
  }
' "$cl" > "$tmp" && mv "$tmp" "$cl"

echo "✓  $plugin $cur → $new"
echo "   plugin.json + marketplace.json updated; CHANGELOG stub inserted."
echo "   remaining manual steps:"
echo "   - bump the changed skill's metadata.version in its SKILL.md"
echo "   - replace the TODO line in CHANGELOG.md"
echo "   - run ./scripts/validate-contract.sh"
