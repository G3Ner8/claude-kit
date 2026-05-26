#!/usr/bin/env bash
#
# validate-frontmatter.sh — strict frontmatter validator for claude-kit
#
# Scans every plugins/*/skills/*/SKILL.md and verifies required fields per
# CLAUDE.md Section 10. By default skips _in-progress/ and _deprecated/
# folders; pass --include-drafts to include them as warnings (never fails).
#
# Exit codes:
#   0   all skills valid
#   1   one or more skills failed validation
#   2   bad usage / no skills found
#
# Usage:
#   ./scripts/validate-frontmatter.sh                # scan stable skills only
#   ./scripts/validate-frontmatter.sh --include-drafts
#   ./scripts/validate-frontmatter.sh --plugin react-core
#   ./scripts/validate-frontmatter.sh path/to/SKILL.md

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDE_DRAFTS=0
PLUGIN_FILTER=""
EXPLICIT_FILE=""

# ─── Args ────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-drafts) INCLUDE_DRAFTS=1; shift ;;
    --plugin) PLUGIN_FILTER="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '3,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      if [[ -f "$1" ]]; then EXPLICIT_FILE="$1"; shift
      else echo "unknown arg: $1" >&2; exit 2
      fi ;;
  esac
done

# ─── Constants ───────────────────────────────────────────────────────────────

REQUIRED_FIELDS=(name description license user-invocable)
REQUIRED_METADATA=(version type status)
VALID_TYPES=(gate reference action)
VALID_STATUSES=(stable experimental deprecated)
SEMVER_RE='^"?[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?"?$'
GATE_REF_BODY_RE='^## When to use'
ACTION_BODY_RE='^## Pre-conditions'

# ─── Helpers ─────────────────────────────────────────────────────────────────

# Extract YAML frontmatter block (text between the first two `---` lines).
extract_frontmatter() {
  awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$1"
}

# Look up a key=value in a flat YAML-ish block. Returns the value or empty.
yaml_get() {
  local key="$1" block="$2"
  printf '%s\n' "$block" | sed -nE "s/^${key}:[[:space:]]+(.*)\$/\1/p" | head -1
}

# Look up a key inside the metadata: block (next non-blank indented line).
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

contains() {
  local needle="$1"; shift
  for candidate in "$@"; do
    [[ "$candidate" == "$needle" ]] && return 0
  done
  return 1
}

# ─── Per-file validation ─────────────────────────────────────────────────────

fail_count=0
warn_count=0
ok_count=0
skipped_count=0

validate_skill() {
  local file="$1"
  local rel_path="${file#"$REPO_ROOT/"}"
  local folder_name; folder_name="$(basename "$(dirname "$file")")"

  # Skip draft / deprecated folders unless --include-drafts.
  if [[ "$file" == *"/_in-progress/"* || "$file" == *"/_deprecated/"* ]]; then
    if [[ $INCLUDE_DRAFTS -eq 0 ]]; then
      skipped_count=$((skipped_count + 1))
      return 0
    fi
  fi

  local block; block="$(extract_frontmatter "$file")"

  if [[ -z "$block" ]]; then
    echo "❌ $rel_path — no YAML frontmatter found"
    fail_count=$((fail_count + 1))
    return
  fi

  local errors=()
  local warnings=()

  # 1. Required top-level fields
  for f in "${REQUIRED_FIELDS[@]}"; do
    if [[ -z "$(yaml_get "$f" "$block")" ]]; then
      errors+=("missing required field: $f")
    fi
  done

  # 2. Required metadata.* fields
  for f in "${REQUIRED_METADATA[@]}"; do
    if [[ -z "$(yaml_get_metadata "$f" "$block")" ]]; then
      errors+=("missing metadata.$f")
    fi
  done

  # 3. name matches folder name
  local name; name="$(yaml_get name "$block")"
  if [[ -n "$name" && "$name" != "$folder_name" ]]; then
    errors+=("name '$name' does not match folder '$folder_name'")
  fi

  # 4. metadata.type enum
  local type; type="$(yaml_get_metadata type "$block")"
  if [[ -n "$type" ]] && ! contains "$type" "${VALID_TYPES[@]}"; then
    errors+=("metadata.type '$type' not in {${VALID_TYPES[*]}}")
  fi

  # 5. metadata.status enum
  local status; status="$(yaml_get_metadata status "$block")"
  if [[ -n "$status" ]] && ! contains "$status" "${VALID_STATUSES[@]}"; then
    errors+=("metadata.status '$status' not in {${VALID_STATUSES[*]}}")
  fi

  # 6. metadata.version SemVer
  local version; version="$(yaml_get_metadata version "$block")"
  if [[ -n "$version" ]] && ! [[ "$version" =~ $SEMVER_RE ]]; then
    errors+=("metadata.version '$version' is not SemVer")
  fi

  # 7. Body skeleton check (gate + reference → 'When to use'; action → 'Pre-conditions')
  local body_ok=0
  if [[ "$type" == "action" ]]; then
    grep -qE "$ACTION_BODY_RE" "$file" && body_ok=1
    [[ $body_ok -eq 0 ]] && warnings+=("missing '## Pre-conditions' section (action skill)")
  else
    grep -qE "$GATE_REF_BODY_RE" "$file" && body_ok=1
    [[ $body_ok -eq 0 ]] && warnings+=("missing '## When to use' section")
  fi

  # 8. _in-progress/ should be status: experimental (warn, don't fail)
  if [[ "$file" == *"/_in-progress/"* && "$status" != "experimental" ]]; then
    warnings+=("skill in _in-progress/ should have status: experimental (got '$status')")
  fi

  # 9. _deprecated/ should be status: deprecated
  if [[ "$file" == *"/_deprecated/"* && "$status" != "deprecated" ]]; then
    warnings+=("skill in _deprecated/ should have status: deprecated (got '$status')")
  fi

  if [[ ${#errors[@]} -eq 0 && ${#warnings[@]} -eq 0 ]]; then
    echo "✓  $rel_path  [type=$type status=$status v$version]"
    ok_count=$((ok_count + 1))
  elif [[ ${#errors[@]} -eq 0 ]]; then
    echo "⚠  $rel_path"
    for w in "${warnings[@]}"; do echo "     warn: $w"; done
    warn_count=$((warn_count + 1))
    ok_count=$((ok_count + 1))
  else
    echo "❌ $rel_path"
    for e in "${errors[@]}"; do echo "     error: $e"; done
    for w in "${warnings[@]}"; do echo "     warn:  $w"; done
    fail_count=$((fail_count + 1))
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────

# Collect skill files
files=()
if [[ -n "$EXPLICIT_FILE" ]]; then
  files=("$EXPLICIT_FILE")
else
  base="$REPO_ROOT/plugins"
  if [[ -n "$PLUGIN_FILTER" ]]; then
    base="$REPO_ROOT/plugins/$PLUGIN_FILTER"
    [[ -d "$base" ]] || { echo "plugin not found: $PLUGIN_FILTER" >&2; exit 2; }
  fi
  while IFS= read -r -d '' f; do files+=("$f"); done < <(find "$base" -type f -name SKILL.md -print0)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "no SKILL.md files found" >&2
  exit 2
fi

echo "scanning ${#files[@]} skill file(s)..."
echo ""

for f in "${files[@]}"; do
  validate_skill "$f"
done

echo ""
echo "summary: $ok_count valid · $warn_count with warnings · $fail_count failed · $skipped_count skipped (drafts)"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
