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

# A task that does not exist (no meta) is not a worker: kinds refuse, hooks
# stay silent, nothing is written.
out="$("$S" note hi 2>&1)"; rc=$?
expect "worker kind for a task with no meta exits 1" '[[ $rc -eq 1 && "$out" == *"no task"* ]]' "rc=$rc $out"
for t in shop/t1 garbage "shop/../x" "SHOP/t1" "shop/t1/x"; do
  out="$(MCV_TASK="$t" "$S" --contract 2>&1)$(MCV_TASK="$t" "$S" --deny-ask 2>&1)"; rc=$?
  expect "hooks silent for MCV_TASK '$t' with no task behind it" '[[ $rc -eq 0 && -z "$out" ]]' "rc=$rc $out"
done
expect "nothing written for a task with no meta" '[[ -z "$(ls -A "$home")" ]]'

# The task as spawn leaves it.
mkdir -p "$home/shop/tasks/t1"
echo '{}' >"$home/shop/tasks/t1/meta"

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
expect "contract with no branch in meta names none" '[[ "$ctx" == *"the branch you started on"* ]]'
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

# Question ids are q<n>, matched literally: no regex, no forged lines.
for q in "q." "q1.*" "$(printf 'q1\nanswered')" "x1" "q0"; do
  env -u MCV_TASK "$S" --task shop/t1 answered "$q" "x" >/dev/null 2>&1; rc=$?
  expect "answered refuses question id '$(printf '%s' "$q" | tr '\n' ' ')'" '[[ $rc -eq 1 ]]' "rc=$rc"
done
expect "no forged line in the log" '! grep -q "^answered" "$log"'

# Concurrent writers: question numbers never repeat, a question is answered
# once, long lines never interleave.
mkdir -p "$home/shop/tasks/t2"
echo '{}' >"$home/shop/tasks/t2/meta"
log2="$home/shop/tasks/t2/status.log"
for i in $(seq 1 20); do MCV_TASK=shop/t2 "$S" needs-decision "question $i" >"$home/q$i" & done
wait
ids="$(cat "$home"/q* | sort | uniq | wc -l | tr -d ' ')"
expect "20 concurrent questions get 20 different ids" '[[ "$ids" -eq 20 ]]' "$(cat "$home"/q* | sort | tr '\n' ' ')"
rm -f "$home"/q*
for i in $(seq 1 5); do env -u MCV_TASK "$S" --task shop/t2 answered q3 "answer $i" >/dev/null 2>&1 & done
wait
expect "5 concurrent answers to one question: one recorded" \
  '[[ "$(cut -f2,3 "$log2" | grep -c "^answered"$'"'"'\t'"'"'"q3$")" -eq 1 ]]'
big="$(printf 'x%.0s' $(seq 1 20000))"
for i in $(seq 1 8); do MCV_TASK=shop/t2 "$S" note "$i$big" & done
wait
expect "8 concurrent 20 KB lines: each line whole" \
  '[[ "$(awk -F"\t" "NF == 4 && \$2 == \"note\" && \$4 ~ /^[1-8]x+\$/ && length(\$4) == 20001" "$log2" | wc -l | tr -d " ")" -eq 8 ]]'
expect "no lock left behind" '[[ ! -e "$log2.lock" ]]'

# A lock left by a writer that died is taken over.
sleep 0 & dead=$!
wait "$dead"
mkdir "$log2.lock" && echo "$dead $(( $(date +%s) - 60 ))" >"$log2.lock/pid"
MCV_TASK=shop/t2 "$S" note "after a stale lock" >/dev/null 2>&1; rc=$?
expect "a stale lock is taken over" '[[ $rc -eq 0 && "$(tail -1 "$log2")" == *"after a stale lock" ]]' "rc=$rc"

# A lock just taken (under 2 seconds old) is never taken over, even when its
# pid has exited: that pid may have just released it to another writer.
mkdir "$log2.lock" && echo "$dead $(date +%s)" >"$log2.lock/pid"
( sleep 1; echo "released by holder" >>"$log2"; rm -rf "$log2.lock" ) &
MCV_TASK=shop/t2 "$S" note "after a fresh lock" >/dev/null 2>&1; rc=$?
wait
expect "a fresh lock is waited for, not taken over" \
  '[[ $rc -eq 0 && "$(tail -2 "$log2" | head -1)" == "released by holder" && "$(tail -1 "$log2")" == *"after a fresh lock" ]]' \
  "rc=$rc $(tail -2 "$log2")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
