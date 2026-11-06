#!/usr/bin/env bash
#
# Tests for spawn when it is interrupted, races another spawn, or finds
# leftovers: nothing may be left that `remove` cannot clean up, and two
# spawns may never both own one task or worker name. Runs against
# tests/mcv/fixtures/fake-herdr.sh. Needs bash, git and jq.
# Run: tests/mcv/test-interrupt.sh   (exit 0 when every check passes)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN="$(cd "$HERE/../../plugins/mcv/bin" && pwd -P)"
H="$BIN/mcv-herdr.sh"
S="$BIN/mcv-status"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
expect() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

tmp="$(mktemp -d)"
root="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$root/bin" "$root/slow"
ln -s "$HERE/fixtures/fake-herdr.sh" "$root/bin/herdr"
# A cp that takes its time, to interrupt a spawn while it copies.
real_cp="$(command -v cp)"
printf '#!/usr/bin/env bash\nsleep 3\nexec %q "$@"\n' "$real_cp" >"$root/slow/cp"
chmod +x "$root/slow/cp"
export PATH="$root/bin:$PATH" HERDR_ENV=1 MCV_HOME="$root/home" FAKE_DIR="$root/fake"
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
  GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

repo="$root/repo"
git init -q -b main "$repo"
printf 'qa/.env\n' >"$repo/.gitignore"
git -C "$repo" add .gitignore
git -C "$repo" commit -q -m init
mkdir -p "$repo/qa"
echo "PASS=x" >"$repo/qa/.env"
echo "qa/.env" >"$repo/.worktreeinclude"

worktrees() { git -C "$repo" worktree list --porcelain | grep -c '^worktree '; }
has_branch() { git -C "$repo" show-ref --verify --quiet "refs/heads/$1"; }
wait_for() { local i; for i in $(seq 1 50); do eval "$1" && return 0; sleep 0.1; done; return 1; }

# Killed outright (no cleanup can run) while copying .worktreeinclude files:
# the task is already written, so `remove` cleans up and the id is free.
PATH="$root/slow:$PATH" "$H" spawn acme k1 "$repo" feat/k1 >/dev/null 2>&1 &
pid=$!
wait_for '[[ -f "$MCV_HOME/acme/tasks/k1/meta" ]]'
kill -9 "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
expect "spawn killed while copying left a task" '[[ -f "$MCV_HOME/acme/tasks/k1/meta" ]]'
out="$("$H" remove acme/k1 2>&1)"; rc=$?
expect "remove cleans up after a killed spawn" '[[ $rc -eq 0 && $(worktrees) -eq 1 ]]' "rc=$rc $out"
sleep 2
out="$("$H" spawn acme k1 "$repo" feat/k1b 2>&1)"; rc=$?
expect "the id can be spawned again (the dead spawn's claim is taken over)" '[[ $rc -eq 0 ]]' "rc=$rc $out"

# Stopped with TERM while herdr creates the worktree: herdr finishes, the
# spawn then exits before reading its answer; cleanup still finds and
# removes the worktree, the branch and the task.
FAKE_SLEEP=2 "$H" spawn acme k2 "$repo" feat/k2 >/dev/null 2>&1 &
pid=$!
wait_for 'grep -q "begin acme-k2" "$FAKE_DIR/order" 2>/dev/null'
kill -TERM "$pid"
wait "$pid"; rc=$?
expect "TERM during worktree create: exit 143" '[[ $rc -eq 143 ]]' "rc=$rc"
expect "TERM during worktree create: no worktree left" '! git -C "$repo" worktree list | grep -q "acme-k2"'
expect "TERM during worktree create: no branch left" '! has_branch feat/k2'
expect "TERM during worktree create: no task, claim or lock left" \
  '[[ ! -e "$MCV_HOME/acme/tasks/k2" && ! -e "$MCV_HOME/.claims/acme-k2" && -z "$(ls -A "$MCV_HOME/.locks")" ]]'

# Stopped with TERM while copying: everything this spawn made is removed.
PATH="$root/slow:$PATH" "$H" spawn acme k3 "$repo" feat/k3 >/dev/null 2>&1 &
pid=$!
wait_for '[[ -f "$MCV_HOME/acme/tasks/k3/meta" ]]'
kill -TERM "$pid"
wait "$pid"; rc=$?
expect "TERM while copying: exit 143" '[[ $rc -eq 143 ]]' "rc=$rc"
expect "TERM while copying: worktree, branch and task removed" \
  '! git -C "$repo" worktree list | grep -q "acme-k3" && ! has_branch feat/k3 && [[ ! -e "$MCV_HOME/acme/tasks/k3" ]]'

# Two spawns of one task at once: exactly one wins.
FAKE_SLEEP=1 "$H" spawn acme same "$repo" feat/same-a >"$root/a.out" 2>&1 &
a=$!
FAKE_SLEEP=1 "$H" spawn acme same "$repo" feat/same-b >"$root/b.out" 2>&1 &
b=$!
wait "$a"; ra=$?
wait "$b"; rb=$?
expect "two spawns of one task: exactly one succeeds" '[[ $((ra + rb)) -eq 1 ]]' \
  "$ra $(cat "$root/a.out") / $rb $(cat "$root/b.out")"
expect "the loser says why in one line" \
  '[[ "$(cat "$root/a.out" "$root/b.out" | grep -c "^mcv-herdr: ")" -eq 1 ]]'
expect "only the winner's branch exists" '[[ $( (has_branch feat/same-a && echo 1) ; (has_branch feat/same-b && echo 1) ) == 1 ]]'

# Two tasks whose worker names join the same, at once: exactly one wins.
FAKE_SLEEP=1 "$H" spawn x-y z "$repo" feat/xyz-a >"$root/a.out" 2>&1 &
a=$!
FAKE_SLEEP=1 "$H" spawn x y-z "$repo" feat/xyz-b >"$root/b.out" 2>&1 &
b=$!
wait "$a"; ra=$?
wait "$b"; rb=$?
expect "x-y/z and x/y-z at once: exactly one succeeds" '[[ $((ra + rb)) -eq 1 ]]' \
  "$ra $(cat "$root/a.out") / $rb $(cat "$root/b.out")"

# A task folder without meta (a crashed spawn, an old version) is cleared:
# the new worker's first question is q1, not q2.
mkdir -p "$MCV_HOME/acme/tasks/old"
printf '2026-01-01T00:00:00Z\tneeds-decision\tq1\tleft over\n' >"$MCV_HOME/acme/tasks/old/status.log"
out="$("$H" spawn acme old "$repo" feat/old 2>&1)"; rc=$?
q="$(MCV_TASK=acme/old "$S" needs-decision "first question" 2>&1)"
expect "a leftover folder is cleared: the first question is q1" '[[ $rc -eq 0 && "$q" == q1 ]]' "rc=$rc q=$q $out"

# Branch names outside ASCII are refused.
out="$(LC_ALL=C "$H" spawn acme uni "$repo" "feat/é" 2>&1)"; rc=$?
expect "a non-ASCII branch name is refused" '[[ $rc -eq 1 && "$out" == *"ASCII"* ]]' "rc=$rc $out"

# When removing a failed worktree fails too, the message says so.
out="$(FAKE_FAIL=partial FAKE_FAIL_REMOVE=1 "$H" spawn acme rmf "$repo" feat/rmf 2>&1)"; rc=$?
expect "a failed cleanup is reported, not claimed done" \
  '[[ $rc -eq 1 && "$out" == *"removing the worktree failed too"* && "$out" != *"was removed"* ]]' "rc=$rc $out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
