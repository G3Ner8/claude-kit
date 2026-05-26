#!/usr/bin/env bash
#
# link-skills.sh — symlink every stable skill into ~/.claude/skills/
#
# For local development — lets you exercise a SKILL.md directly via the
# user-invocable slash command (/skill-name) without going through the
# marketplace install flow.
#
# Skips _in-progress/ and _deprecated/ skills. Pass --all to include them.
# Pass --dry-run to preview what would be linked without touching the
# filesystem. Pass --unlink to remove links this script previously created.
#
# Exit codes:
#   0   success
#   1   one or more links failed
#   2   bad usage
#
# Usage:
#   ./scripts/link-skills.sh                  # link stable + experimental
#   ./scripts/link-skills.sh --dry-run
#   ./scripts/link-skills.sh --all
#   ./scripts/link-skills.sh --unlink

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
INCLUDE_ALL=0
DRY_RUN=0
UNLINK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) INCLUDE_ALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --unlink) UNLINK=1; shift ;;
    --target) TARGET_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '3,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ $DRY_RUN -eq 0 ]] && mkdir -p "$TARGET_DIR"

linked=0
skipped=0
failed=0
removed=0

while IFS= read -r -d '' skill_md; do
  if [[ $INCLUDE_ALL -eq 0 ]]; then
    [[ "$skill_md" == *"/_in-progress/"* ]] && { skipped=$((skipped + 1)); continue; }
    [[ "$skill_md" == *"/_deprecated/"* ]] && { skipped=$((skipped + 1)); continue; }
  fi

  src_dir="$(dirname "$skill_md")"
  name="$(basename "$src_dir")"
  link_path="$TARGET_DIR/$name"

  if [[ $UNLINK -eq 1 ]]; then
    if [[ -L "$link_path" ]]; then
      target="$(readlink "$link_path")"
      if [[ "$target" == "$src_dir" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
          echo "would unlink $link_path"
        else
          rm "$link_path"
          echo "✓ unlinked $name"
        fi
        removed=$((removed + 1))
      fi
    fi
    continue
  fi

  if [[ -L "$link_path" ]]; then
    existing="$(readlink "$link_path")"
    if [[ "$existing" == "$src_dir" ]]; then
      echo "✓ $name (already linked)"
      linked=$((linked + 1))
      continue
    else
      echo "❌ $name — different link exists: $existing" >&2
      failed=$((failed + 1))
      continue
    fi
  fi

  if [[ -e "$link_path" ]]; then
    echo "❌ $name — non-symlink already exists at $link_path" >&2
    failed=$((failed + 1))
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "would link $name → $src_dir"
  else
    ln -s "$src_dir" "$link_path"
    echo "✓ linked $name"
  fi
  linked=$((linked + 1))
done < <(find "$REPO_ROOT/plugins" -type f -name SKILL.md -print0)

echo ""
if [[ $UNLINK -eq 1 ]]; then
  echo "summary: $removed removed · $skipped skipped"
else
  echo "summary: $linked linked · $skipped skipped (drafts/deprecated) · $failed failed"
fi

[[ $failed -gt 0 ]] && exit 1
exit 0
