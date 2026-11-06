#!/usr/bin/env bash
#
# Tests for plugins/mcv/hooks/hooks.json: every hook does nothing unless
# MCV_TASK is set (CLAUDE.md Section 2), and does its job when it is. The
# commands are taken from hooks.json itself and run the way Claude Code runs
# them, through a shell with CLAUDE_PLUGIN_ROOT set. Needs bash and jq.
# Run: tests/mcv/test-hooks.sh   (exit 0 when every check passes)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/../../plugins/mcv" && pwd -P)"
HOOKS="$ROOT/hooks/hooks.json"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
expect() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

expect "hooks.json exists and parses" 'jq -e . "$HOOKS" >/dev/null 2>&1'
expect "only SessionStart and PreToolUse hooks" \
  '[[ "$(jq -r ".hooks | keys | join(\" \")" "$HOOKS" 2>/dev/null)" == "PreToolUse SessionStart" ]]'
expect "SessionStart has no matcher, so it runs on every source" \
  '[[ "$(jq -r ".hooks.SessionStart[0].matcher // \"none\"" "$HOOKS" 2>/dev/null)" == none ]]'
expect "PreToolUse matches AskUserQuestion only" \
  '[[ "$(jq -r ".hooks.PreToolUse[0].matcher" "$HOOKS" 2>/dev/null)" == AskUserQuestion ]]'

session_cmd="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$HOOKS" 2>/dev/null)"
pre_cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS" 2>/dev/null)"
run() { env CLAUDE_PLUGIN_ROOT="$ROOT" MCV_HOME="$home" "$@"; }

# Unset: silent, exit 0, nothing written.
for name in SessionStart PreToolUse; do
  cmd="$session_cmd"; [[ $name == PreToolUse ]] && cmd="$pre_cmd"
  out="$(run env -u MCV_TASK sh -c "$cmd" </dev/null 2>&1)"; rc=$?
  expect "$name without MCV_TASK: exit 0" '[[ $rc -eq 0 ]]' "rc=$rc"
  expect "$name without MCV_TASK: no output" '[[ -z "$out" ]]' "$out"
  out="$(run MCV_TASK= sh -c "$cmd" </dev/null 2>&1)"; rc=$?
  expect "$name with MCV_TASK empty: silent, exit 0" '[[ $rc -eq 0 && -z "$out" ]]' "rc=$rc $out"
done
expect "no state written by unset hooks" '[[ -z "$(ls -A "$home")" ]]'

# Set: the hooks do their job.
out="$(run MCV_TASK=acme/t1 sh -c "$session_cmd" </dev/null)"
expect "SessionStart with MCV_TASK: worker rules as SessionStart context" \
  '[[ "$(jq -r .hookSpecificOutput.hookEventName <<<"$out" 2>/dev/null)" == SessionStart ]]' "$out"
out="$(run MCV_TASK=acme/t1 sh -c "$pre_cmd" </dev/null)"
expect "PreToolUse with MCV_TASK: deny" \
  '[[ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$out" 2>/dev/null)" == deny ]]' "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
