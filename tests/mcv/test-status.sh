#!/usr/bin/env bash
#
# Tests for plugins/mcv/bin/mcv-status. Needs bash, jq; no herdr.
# Run: tests/mcv/test-status.sh   (exit 0 when every check passes)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN="$(cd "$HERE/../../plugins/mcv/bin" && pwd -P)"
S="$BIN/mcv-status"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
expect() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
log="$home/shop/tasks/t1/status.log"

# Without MCV_TASK: worker kinds refuse, hook outputs stay silent.
out="$(env -u MCV_TASK MCV_HOME="$home" "$S" note hi 2>&1)"; rc=$?
expect "worker kind without MCV_TASK exits 2" '[[ $rc -eq 2 ]]' "rc=$rc"
expect "worker kind without MCV_TASK says so" '[[ "$out" == *"MCV_TASK not set"* ]]' "$out"
out="$(env -u MCV_TASK MCV_HOME="$home" "$S" --contract 2>&1)"; rc=$?
expect "--contract without MCV_TASK: exit 0, no output" '[[ $rc -eq 0 && -z "$out" ]]' "rc=$rc out=$out"
out="$(env -u MCV_TASK MCV_HOME="$home" "$S" --deny-ask 2>&1)"; rc=$?
expect "--deny-ask without MCV_TASK: exit 0, no output" '[[ $rc -eq 0 && -z "$out" ]]' "rc=$rc out=$out"
expect "nothing written without MCV_TASK" '[[ -z "$(ls -A "$home")" ]]'

export MCV_HOME="$home" MCV_TASK=shop/t1

# Question numbering.
q1="$("$S" needs-decision "Which login flow?")"
q2="$("$S" needs-decision "Keep the old route?")"
expect "first question is q1" '[[ "$q1" == q1 ]]' "got '$q1'"
expect "second question is q2" '[[ "$q2" == q2 ]]' "got '$q2'"

# Other kinds print nothing and append one line each.
out="$("$S" note "halfway")"
expect "note prints nothing" '[[ -z "$out" ]]' "$out"
"$S" blocked "cannot reach the database" >/dev/null
"$S" done "login fixed" >/dev/null
"$S" failed "tests will not run" >/dev/null
expect "six lines written" '[[ $(wc -l <"$log") -eq 6 ]]' "$(cat "$log")"

# Line format: four tab-separated fields, timestamp first.
first="$(head -1 "$log")"
expect "line has four fields" '[[ $(awk -F"\t" "{print NF}" <<<"$first") -eq 4 ]]' "$first"
expect "first field is a UTC timestamp" '[[ "$first" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'"'"'\t'"'"' ]]' "$first"
expect "question line carries kind and id" '[[ "$(cut -f2,3 <<<"$first")" == "needs-decision"$'"'"'\t'"'"'q1 ]]' "$first"
expect "non-question line has - for id" '[[ "$(sed -n 3p "$log" | cut -f2,3)" == "note"$'"'"'\t'"'"'- ]]' "$(sed -n 3p "$log")"

# Tabs and newlines in text are folded so one event stays one line.
"$S" note "$(printf 'a\tb\nc\r\nd')" >/dev/null
last="$(tail -1 "$log")"
expect "folded text keeps four fields" '[[ $(awk -F"\t" "{print NF}" <<<"$last") -eq 4 ]]' "$last"
expect "folded text is on one line" '[[ $(wc -l <"$log") -eq 7 ]]'

# Unknown kind and malformed MCV_TASK.
"$S" shout hi >/dev/null 2>&1; rc=$?
expect "unknown kind exits 2" '[[ $rc -eq 2 ]]' "rc=$rc"
MCV_TASK=noslash "$S" note hi >/dev/null 2>&1; rc=$?
expect "malformed MCV_TASK exits 1" '[[ $rc -eq 1 ]]' "rc=$rc"

# The coordinator closes a question.
env -u MCV_TASK "$S" --task shop/t1 answered q1 "use the new flow"; rc=$?
expect "answering q1 succeeds" '[[ $rc -eq 0 ]]' "rc=$rc"
expect "answer line recorded" '[[ "$(tail -1 "$log" | cut -f2,3)" == "answered"$'"'"'\t'"'"'q1 ]]' "$(tail -1 "$log")"
env -u MCV_TASK "$S" --task shop/t1 answered q1 "again" >/dev/null 2>&1; rc=$?
expect "answering q1 twice exits 1" '[[ $rc -eq 1 ]]' "rc=$rc"
env -u MCV_TASK "$S" --task shop/t1 answered q9 "nope" >/dev/null 2>&1; rc=$?
expect "answering an unasked question exits 1" '[[ $rc -eq 1 ]]' "rc=$rc"

# Hook outputs with MCV_TASK set.
c="$("$S" --contract)"
expect "--contract is JSON" 'jq -e . <<<"$c" >/dev/null'
expect "--contract is a SessionStart context" \
  '[[ "$(jq -r .hookSpecificOutput.hookEventName <<<"$c")" == SessionStart ]]'
ctx="$(jq -r .hookSpecificOutput.additionalContext <<<"$c")"
expect "contract names the task" '[[ "$ctx" == *"shop/t1"* ]]'
expect "contract gives the absolute mcv-status path" '[[ "$ctx" == *"$S"* ]]'
expect "contract forbids AskUserQuestion" '[[ "$ctx" == *"AskUserQuestion"* ]]'
expect "contract says to end the turn" '[[ "$ctx" == *"end your turn"* ]]'
expect "contract keeps AskUserQuestion off even when the user types directly" \
  '[[ "$ctx" == *"outranks the coordinator. Even then"*"never AskUserQuestion"* ]]'
expect "contract without meta names no branch" '[[ "$ctx" == *"the branch you started on"* ]]'
expect "contract forbids force-push" '[[ "$ctx" == *"Never force-push"* ]]'
expect "contract defers to project git rules" '[[ "$ctx" == *"they win"* ]]'
printf '{"branch":"fix/login"}\n' >"$home/shop/tasks/t1/meta"
ctx="$("$S" --contract | jq -r .hookSpecificOutput.additionalContext)"
expect "contract names the worker's branch from meta" '[[ "$ctx" == *"Work only on \`fix/login\`"* ]]'

d="$("$S" --deny-ask)"
expect "--deny-ask is JSON" 'jq -e . <<<"$d" >/dev/null'
expect "--deny-ask denies" '[[ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$d")" == deny ]]'
reason="$(jq -r .hookSpecificOutput.permissionDecisionReason <<<"$d")"
expect "deny reason gives the mcv-status path" '[[ "$reason" == *"$S"* ]]'
expect "deny reason names needs-decision" '[[ "$reason" == *"needs-decision"* ]]'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
