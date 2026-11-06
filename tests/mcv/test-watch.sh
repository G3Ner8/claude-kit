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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
