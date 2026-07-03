#!/usr/bin/env bash
#
# link-check.sh — verify relative markdown links point at existing files
#
# Scans every git-tracked *.md file for [text](target) links and checks that
# each relative target resolves from the linking file's directory (a leading
# "/" resolves from the repo root). Skips external URLs (http/https/mailto),
# pure anchors (#...), and template placeholders (targets containing
# < > { } $ * or "..."). A relative target's own #anchor is stripped — the
# file is checked, the heading is not.
#
# Motivated by the _archive/ removal: two dead links sat in a README and only
# a manual grep caught them.
#
# Usage:
#   ./scripts/link-check.sh
#
# Exit codes: 0 all links resolve · 1 broken link(s) found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail=0
checked=0

while IFS= read -r file; do
  dir="$(dirname "$file")"
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    case "$target" in
      http://*|https://*|mailto:*|"#"*) continue ;;
    esac
    [[ "$target" == *"..."* ]] && continue
    [[ "$target" == *[\<\>\{\}\$\*]* ]] && continue
    target="${target%%#*}"          # strip anchor; check the file only
    [[ -z "$target" ]] && continue
    checked=$((checked + 1))
    if [[ "$target" == /* ]]; then
      resolved="$REPO_ROOT$target"
    else
      resolved="$dir/$target"
    fi
    if [[ ! -e "$resolved" ]]; then
      echo "❌ $file → $target (missing)"
      fail=$((fail + 1))
    fi
  done < <(grep -oE '\]\([^)]+\)' "$file" 2>/dev/null | sed -E 's/^\]\((.*)\)$/\1/')
done < <(git ls-files '*.md')

echo "checked $checked relative link(s) across $(git ls-files '*.md' | wc -l | tr -d ' ') markdown file(s)"
if [[ $fail -gt 0 ]]; then
  echo "broken: $fail"
  exit 1
fi
echo "all resolve ✓"
