#!/usr/bin/env bash
#
# Tests for plugins/mcv/bin/mcv-watch, one poll at a time (--once) against a
# stub herdr. Needs bash and jq; no herdr.
# Run: tests/mcv/test-watch.sh   (exit 0 when every check passes)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
W="$(cd "$HERE/../../plugins/mcv/bin" && pwd -P)/mcv-watch"
STATUS="$(dirname "$W")/mcv-status"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
expect() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export MCV_HOME="$root/home" MCV_HERDR="$HERE/fixtures/stub-herdr.sh" STUB_AGENTS="$root/agents"
export MCV_WATCH_STATE="$root/state"
mkdir -p "$MCV_WATCH_STATE"

# A task as spawn leaves it: a meta file naming its pane.
task() { # <id> <pane>
  mkdir -p "$MCV_HOME/acme/tasks/$1"
  printf '{"task":"acme/%s","pane_id":"%s"}\n' "$1" "$2" >"$MCV_HOME/acme/tasks/$1/meta"
}
agents() { printf '%s' "$*" | tr '|' '\n' | tr ',' '\t' >"$STUB_AGENTS"; }  # "p1,working,3,acme-a|..."
say() { MCV_TASK="acme/$1" "$STATUS" "$2" "$3" >/dev/null; }                  # <id> <kind> <text>
poll() { "$W" acme --once; }
count() { if [[ -z "$1" ]]; then echo 0; else printf '%s\n' "$1" | wc -l | tr -d ' '; fi; }

# Without a state folder, --once refuses.
out="$(env -u MCV_WATCH_STATE "$W" acme --once 2>&1)"; rc=$?
expect "--once without MCV_WATCH_STATE exits 2" '[[ $rc -eq 2 ]]' "rc=$rc $out"

# First poll: report only tasks already blocked or done; never replay old lines.
task a w:p1; task b w:p2; task c w:p3
say a note "old line before the watcher started"
agents "w:p1,working,1,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "first poll: two events" '[[ $(count "$out") -eq 2 ]]' "$out"
expect "first poll reports b done" '[[ "$out" == *"acme/b"$'"'"'\t'"'"'"state"$'"'"'\t'"'"'"done"* ]]' "$out"
expect "first poll reports c blocked" '[[ "$out" == *"acme/c"$'"'"'\t'"'"'"state"$'"'"'\t'"'"'"blocked"* ]]' "$out"
expect "first poll does not replay old log lines" '[[ "$out" != *"old line"* ]]' "$out"

# Nothing changed: nothing printed.
out="$(poll)"
expect "no change: no events" '[[ -z "$out" ]]' "$out"

# needs-decision, then the turn ends: one event, the question.
say a needs-decision "Session or query string?"
agents "w:p1,done,2,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "question then turn end: one event" '[[ $(count "$out") -eq 1 ]]' "$out"
expect "that event is the question, with its id" \
  '[[ "$out" == *"acme/a"$'"'"'\t'"'"'"needs-decision"$'"'"'\t'"'"'"q1"$'"'"'\t'"'"'"Session or query string?" ]]' "$out"

# The question arrives in one poll and the turn end in the next: still suppressed.
agents "w:p1,working,3,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "working is never printed" '[[ -z "$out" ]]' "$out"
say a needs-decision "Keep the old route?"
out="$(poll)"
expect "question in its own poll: one event" '[[ $(count "$out") -eq 1 ]]' "$out"
agents "w:p1,done,4,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "turn end after a question in an earlier poll: no event" '[[ -z "$out" ]]' "$out"

# note, then the turn ends: two events.
agents "w:p1,working,5,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
poll >/dev/null
say a note "halfway"
agents "w:p1,done,6,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "note then turn end: two events" '[[ $(count "$out") -eq 2 ]]' "$out"
expect "note comes first, then state done" \
  '[[ "$(printf "%s\n" "$out" | cut -f3 | tr "\n" " ")" == "note state " ]]' "$out"

# A turn that ends with no log line at all: one state done (the safety net).
agents "w:p1,working,7,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
poll >/dev/null
agents "w:p1,done,8,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "silent turn end: one state done" \
  '[[ $(count "$out") -eq 1 && "$out" == *"state"$'"'"'\t'"'"'"done" ]]' "$out"

# A whole turn between two polls (done -> working -> done) is still seen.
agents "w:p1,done,10,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "turn missed between polls: state done from the counter" \
  '[[ $(count "$out") -eq 1 && "$out" == *"state"$'"'"'\t'"'"'"done" ]]' "$out"

# done -> idle (output viewed) is not printed.
agents "w:p1,idle,11,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "idle is never printed" '[[ -z "$out" ]]' "$out"

# A worker reaching a dialog: state blocked.
agents "w:p1,blocked,12,acme-a|w:p2,done,4,acme-b|w:p3,blocked,2,acme-c"
out="$(poll)"
expect "blocked is printed" '[[ $(count "$out") -eq 1 && "$out" == *"state"$'"'"'\t'"'"'"blocked" ]]' "$out"

# The coordinator's own answer lines are never printed.
env -u MCV_TASK "$STATUS" --task acme/a answered q1 "session" >/dev/null
out="$(poll)"
expect "answered lines are not printed" '[[ -z "$out" ]]' "$out"

# A pane that disappears: gone, once.
agents "w:p1,blocked,12,acme-a|w:p2,done,4,acme-b"
out="$(poll)"
expect "vanished pane: gone" '[[ $(count "$out") -eq 1 && "$out" == *"acme/c"$'"'"'\t'"'"'"gone"* ]]' "$out"
out="$(poll)"
expect "gone is printed once" '[[ -z "$out" ]]' "$out"

# A task spawned after the watcher started: its log is followed from the start.
task d w:p4
agents "w:p1,blocked,12,acme-a|w:p2,done,4,acme-b|w:p4,idle,1,acme-d"
say d note "first words"
out="$(poll)"
expect "new task: its first log line is printed" '[[ "$out" == *"acme/d"$'"'"'\t'"'"'"note"$'"'"'\t'"'"'"-"$'"'"'\t'"'"'"first words" ]]' "$out"

# Every line: five tab-separated fields for log events, four for state events.
say d failed "giving up"
out="$(poll)"
expect "log event has five fields" '[[ $(awk -F"\t" "{print NF}" <<<"$out") -eq 5 ]]' "$out"
expect "event starts with a UTC timestamp" '[[ "$out" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]' "$out"

# A worker spawn is still starting (marker set, not yet an agent) is not gone.
task e w:p5
: >"$MCV_HOME/acme/tasks/e/starting"
out="$(poll)"
expect "starting worker missing from the agent list: no gone" '[[ "$out" != *"acme/e"* ]]' "$out"
agents "w:p1,blocked,12,acme-a|w:p2,done,4,acme-b|w:p4,idle,1,acme-d|w:p5,idle,1,acme-e"
out="$(poll)"
expect "started worker seen idle: nothing printed" '[[ "$out" != *"acme/e"* ]]' "$out"
# Once seen, a worker that disappears is gone even if the marker remains.
agents "w:p1,blocked,12,acme-a|w:p2,done,4,acme-b|w:p4,idle,1,acme-d"
out="$(poll)"
expect "seen worker that vanishes is gone despite the marker" '[[ "$out" == *"acme/e"$'"'"'\t'"'"'"gone"* ]]' "$out"

# A task removed and spawned again under the same id within one poll: the new
# worker's first question is printed though its log is shorter than the old.
base_agents="w:p1,blocked,12,acme-a|w:p2,done,4,acme-b|w:p4,idle,1,acme-d"
task f w:p6
agents "$base_agents|w:p6,working,1,acme-f"
say f note one; say f note two; say f note three
poll >/dev/null
rm -rf "$MCV_HOME/acme/tasks/f"
task f w:p7
agents "$base_agents|w:p7,working,1,acme-f"
say f needs-decision "which db?"
out="$(poll)"
expect "respawned id: the new worker's question is printed" '[[ "$out" == *"needs-decision"$'"'"'\t'"'"'"q1"$'"'"'\t'"'"'"which db?" ]]' "$out"

# A log that was started again (shorter than what was read) is followed from
# its start. mcv only appends, so this is a log cut by hand.
say f note x; say f note y
poll >/dev/null
printf '' >"$MCV_HOME/acme/tasks/f/status.log"
say f note "after truncation"
out="$(poll)"
expect "truncated log: its new line is printed" '[[ "$out" == *"after truncation" ]]' "$out"

# A damaged state line or a damaged meta does not stop the watcher.
: >"$MCV_WATCH_STATE/acme/f"
say d note "still here"
out="$(poll 2>"$root/err")"; rc=$?
expect "damaged state: the poll still succeeds" '[[ $rc -eq 0 ]]' "rc=$rc"
expect "damaged state: other tasks still report" '[[ "$out" == *"still here" ]]' "$out"
expect "damaged state: a warning on stderr" 'grep -q "acme/f: state was damaged" "$root/err"' "$(cat "$root/err")"
mkdir -p "$MCV_HOME/acme/tasks/g"
echo 'not json' >"$MCV_HOME/acme/tasks/g/meta"
say d note "and here"
out="$(poll 2>&1)"; rc=$?
expect "damaged meta: the poll still succeeds and reports others" '[[ $rc -eq 0 && "$out" == *"and here" ]]' "rc=$rc $out"
rm -rf "$MCV_HOME/acme/tasks/g"

# herdr failing: log lines are still passed on; the warning comes once.
say d note "herdr is down"
out="$(STUB_DOWN=1 poll 2>"$root/err")"; rc=$?
expect "herdr down: log lines still printed" '[[ $rc -eq 0 && "$out" == *"herdr is down" ]]' "rc=$rc $out"
expect "herdr down: one warning" 'grep -q "worker states unavailable" "$root/err"' "$(cat "$root/err")"
out="$(STUB_DOWN=1 poll 2>"$root/err")"
expect "herdr still down: no second warning" '[[ ! -s "$root/err" ]]' "$(cat "$root/err")"
out="$(poll 2>&1)"
expect "herdr back: no gone for workers it lists" '[[ "$out" != *gone* ]]' "$out"

# Two projects sharing one state folder do not reset each other.
mkdir -p "$MCV_HOME/other/tasks"
"$W" other --once >/dev/null
out="$(poll)"
expect "another project's poll in the same state folder: nothing replayed" '[[ -z "$out" ]]' "$out"

# A watcher started after questions were asked shows the ones still open,
# once, and nothing else from the past.
export MCV_WATCH_STATE="$root/state2"
mkdir -p "$MCV_WATCH_STATE"
task h w:p8
agents "w:p8,done,5,acme-h"
say h needs-decision "first?"
env -u MCV_TASK "$STATUS" --task acme/h answered q1 "yes" >/dev/null
say h note "progress"
say h needs-decision "second?"
out="$(poll 2>/dev/null)"
expect "new watcher: the open question is shown" '[[ "$out" == *"acme/h"$'"'"'\t'"'"'"needs-decision"$'"'"'\t'"'"'"q2"$'"'"'\t'"'"'"second?" ]]' "$out"
expect "new watcher: the answered question and the note are not" '[[ "$out" != *"first?"* && "$out" != *progress* ]]' "$out"
expect "new watcher: no state done on top of the open question" '[[ "$out" != *"acme/h"$'"'"'\t'"'"'"state"* ]]' "$out"
out="$(poll 2>/dev/null)"
expect "the open question is shown once" '[[ "$out" != *"second?"* ]]' "$out"

# Damaged state shows the open questions again rather than losing them.
: >"$MCV_WATCH_STATE/acme/h"
out="$(poll 2>/dev/null)"
expect "damaged state: the open question is shown again" '[[ "$out" == *"second?" ]]' "$out"

# A blank line in a log is not an event and does not lose what follows.
printf '\n' >>"$MCV_HOME/acme/tasks/h/status.log"
out="$(poll 2>/dev/null)"
expect "a blank log line prints nothing" '[[ "$out" != *"acme/h"* ]]' "$out"
say h needs-decision "third?"
out="$(poll 2>&1)"
expect "the question after a blank line is shown, with no state warning" \
  '[[ "$out" == *"third?" && "$out" != *damaged* ]]' "$out"

# A log that cannot be read skips that task; the others are still reported.
if [[ "$(id -u)" -ne 0 ]]; then
  task i w:p9
  agents "w:p8,done,5,acme-h|w:p9,idle,1,acme-i"
  poll >/dev/null 2>&1
  say i note "unreadable soon"
  chmod 000 "$MCV_HOME/acme/tasks/i/status.log"
  say h note "still flowing"
  out="$(poll 2>&1)"; rc=$?
  chmod 600 "$MCV_HOME/acme/tasks/i/status.log"
  expect "an unreadable log does not stop the watcher" '[[ $rc -eq 0 && "$out" == *"still flowing" ]]' "rc=$rc $out"
  out="$(poll 2>&1)"
  expect "once readable again, its line is shown" '[[ "$out" == *"unreadable soon" ]]' "$out"
else
  ok "an unreadable log (skipped: running as root)"
  ok "once readable again (skipped: running as root)"
fi

# The long-running watcher stops at once on TERM, not after its interval.
MCV_WATCH_INTERVAL=30 env -u MCV_WATCH_STATE "$W" acme >/dev/null 2>&1 &
wpid=$!
sleep 1
start=$(date +%s)
kill -TERM "$wpid"
wait "$wpid" 2>/dev/null
took=$(( $(date +%s) - start ))
expect "TERM stops the watcher within 2 seconds (interval 30)" '[[ $took -le 2 ]]' "took ${took}s"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
