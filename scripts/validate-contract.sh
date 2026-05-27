#!/usr/bin/env bash
#
# validate-contract.sh — cross-file contract validator for claude-kit
#
# Enforces the Public/Hidden contract from CLAUDE.md Section 11:
#
#   1. Stable / experimental skills MUST be discoverable from a public surface
#      (root README.md OR the plugin's README.md OR plugin.json description).
#   2. Drafts (_in-progress/) and archived skills (_deprecated/) MUST NOT
#      appear in any public README.
#   3. marketplace.json plugin entries MUST point to existing folders.
#
# Pair with `validate-frontmatter.sh` — that script handles per-file fields;
# this one handles cross-file alignment.
#
# Exit codes:
#   0   all contract checks pass
#   1   one or more contract failures (rule 2 or 3 violated)
#   2   bad usage
#
# In Phase 2, rule-1 misses are reported as WARN. They become FAIL in
# Phase 3 (public GA) — bump $RULE_1_SEVERITY below to flip.
#
# Usage:
#   ./scripts/validate-contract.sh
#   ./scripts/validate-contract.sh --strict      # treat rule-1 misses as failures
#   ./scripts/validate-contract.sh --plugin react-core

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_FILTER=""
STRICT=0
RULE_1_SEVERITY="warn"      # 'warn' (Phase 2) or 'error' (Phase 3 GA)

# ─── Args ────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; RULE_1_SEVERITY="error"; shift ;;
    --plugin) PLUGIN_FILTER="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '3,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────

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

# Whole-word grep for a skill name across one or more files. Returns 0 if
# found anywhere. Matches `name`, `/name/`, `(name)`, `"name"`, `\`name\``,
# `name@`, etc. — anything where 'name' appears as a standalone token.
mentioned_in() {
  local needle="$1"; shift
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    if grep -qE "(^|[^a-zA-Z0-9_-])${needle}([^a-zA-Z0-9_-]|$)" "$f"; then
      return 0
    fi
  done
  return 1
}

# ─── Counters ────────────────────────────────────────────────────────────────

fail_count=0
warn_count=0
ok_count=0

# ─── Rule 3: marketplace.json sanity ─────────────────────────────────────────

echo "── rule 3: marketplace.json plugin paths ──"
marketplace="$REPO_ROOT/.claude-plugin/marketplace.json"
if [[ ! -f "$marketplace" ]]; then
  echo "❌ $marketplace not found"
  fail_count=$((fail_count + 1))
else
  # Extract `source` paths (relative to repo root) from marketplace.json.
  while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    abs="$REPO_ROOT/${src#./}"
    if [[ ! -d "$abs" ]]; then
      echo "❌ marketplace.json references missing plugin folder: $src"
      fail_count=$((fail_count + 1))
    else
      echo "✓  marketplace → $src"
      ok_count=$((ok_count + 1))
    fi
  done < <(grep -oE '"source"[[:space:]]*:[[:space:]]*"[^"]+"' "$marketplace" \
             | sed -E 's/.*"source"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
fi

echo ""

# ─── Collect skills (per status bucket) ──────────────────────────────────────

declare -a public_skills      # status=stable or experimental, NOT in _in-progress/_deprecated
declare -a draft_skills=()       # in _in-progress/ folder
declare -a deprecated_skills=()  # in _deprecated/ folder

base="$REPO_ROOT/plugins"
[[ -n "$PLUGIN_FILTER" ]] && base="$REPO_ROOT/plugins/$PLUGIN_FILTER"
[[ -d "$base" ]] || { echo "plugin not found: $PLUGIN_FILTER" >&2; exit 2; }

while IFS= read -r -d '' file; do
  # plugin = first folder under plugins/
  plugin="$(echo "${file#"$REPO_ROOT/plugins/"}" | cut -d/ -f1)"
  folder="$(basename "$(dirname "$file")")"
  block="$(extract_frontmatter "$file")"
  status="$(yaml_get_metadata status "$block")"

  if [[ "$file" == *"/_in-progress/"* ]]; then
    draft_skills+=("$plugin|$folder|$file")
  elif [[ "$file" == *"/_deprecated/"* ]]; then
    deprecated_skills+=("$plugin|$folder|$file")
  elif [[ "$status" == "stable" || "$status" == "experimental" ]]; then
    public_skills+=("$plugin|$folder|$file")
  fi
done < <(find "$base" -type f -name SKILL.md -print0)

# ─── Rule 1: public skills must be discoverable ──────────────────────────────

echo "── rule 1: public skills referenced from a public surface ──"
root_readme="$REPO_ROOT/README.md"

for entry in "${public_skills[@]:-}"; do
  [[ -z "$entry" ]] && continue
  IFS='|' read -r plugin folder file <<< "$entry"
  plug_readme="$REPO_ROOT/plugins/$plugin/README.md"
  plug_manifest="$REPO_ROOT/plugins/$plugin/.claude-plugin/plugin.json"

  if mentioned_in "$folder" "$root_readme" "$plug_readme" "$plug_manifest"; then
    echo "✓  $plugin/$folder"
    ok_count=$((ok_count + 1))
  else
    if [[ "$RULE_1_SEVERITY" == "error" ]]; then
      echo "❌ $plugin/$folder — not referenced in root README, plugin README, or plugin.json"
      fail_count=$((fail_count + 1))
    else
      echo "⚠  $plugin/$folder — not referenced in root README, plugin README, or plugin.json"
      warn_count=$((warn_count + 1))
    fi
  fi
done

echo ""

# ─── Rule 2: hidden skills must NOT appear in public surfaces ────────────────

echo "── rule 2: drafts + deprecated skills NOT advertised publicly ──"

check_hidden() {
  local bucket_label="$1"; shift
  for entry in "$@"; do
    [[ -z "$entry" ]] && continue
    IFS='|' read -r plugin folder _file <<< "$entry"
    plug_readme="$REPO_ROOT/plugins/$plugin/README.md"

    local leaks=()
    [[ -f "$root_readme" ]] && \
      grep -qE "(^|[^a-zA-Z0-9_-])${folder}([^a-zA-Z0-9_-]|$)" "$root_readme" && \
      leaks+=("root README")
    [[ -f "$plug_readme" ]] && \
      grep -qE "(^|[^a-zA-Z0-9_-])${folder}([^a-zA-Z0-9_-]|$)" "$plug_readme" && \
      leaks+=("plugins/$plugin/README.md")

    if [[ ${#leaks[@]} -eq 0 ]]; then
      echo "✓  $bucket_label $plugin/$folder — not advertised"
      ok_count=$((ok_count + 1))
    else
      echo "❌ $bucket_label $plugin/$folder leaked into: ${leaks[*]}"
      fail_count=$((fail_count + 1))
    fi
  done
}

if [[ ${#draft_skills[@]} -eq 0 && ${#deprecated_skills[@]} -eq 0 ]]; then
  echo "   (no _in-progress/ or _deprecated/ skills found)"
else
  check_hidden "[draft]" "${draft_skills[@]:-}"
  check_hidden "[deprecated]" "${deprecated_skills[@]:-}"
fi

echo ""
echo "summary: $ok_count pass · $warn_count warn · $fail_count fail (rule-1 severity: $RULE_1_SEVERITY)"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
exit 0
