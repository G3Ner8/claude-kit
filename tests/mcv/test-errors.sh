#!/usr/bin/env bash
#
# Tests for how mcv's scripts refuse bad input and report failures: one line
# on stderr and exit 1 (2 for usage in mcv-watch), never a raw shell or jq
# error, and nothing left half made. Runs against
# tests/mcv/fixtures/fake-herdr.sh. Needs bash, git and jq; no herdr.
# Run: tests/mcv/test-errors.sh   (exit 0 when every check passes)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN="$(cd "$HERE/../../plugins/mcv/bin" && pwd -P)"
H="$BIN/mcv-herdr.sh"
W="$BIN/mcv-watch"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
expect() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }
# One line, starting "mcv-herdr: ", exit 1.
one_line() { [[ $rc -eq 1 && "$out" == "mcv-herdr: "* && $(printf '%s\n' "$out" | wc -l) -eq 1 ]]; }

root="$(mktemp -d)"
trap 'chmod -R u+rwx "$root" 2>/dev/null; rm -rf "$root"' EXIT
mkdir -p "$root/bin"
ln -s "$HERE/fixtures/fake-herdr.sh" "$root/bin/herdr"
export PATH="$root/bin:$PATH" HERDR_ENV=1 MCV_HOME="$root/home" FAKE_DIR="$root/fake"
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
  GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

git init -q -b main "$root/seed"
git -C "$root/seed" commit -q --allow-empty -m init
git clone -q --bare "$root/seed" "$root/origin.git"
git clone -q "$root/origin.git" "$root/repo"
repo="$root/repo"
no_task_left() { [[ ! -e "$MCV_HOME/acme/tasks/$1" ]]; }
no_branch() { ! git -C "$repo" show-ref --verify --quiet "refs/heads/$1"; }

# spawn arguments.
out="$("$H" spawn acme t1 "$repo" fix/a --base 2>&1)"; rc=$?
expect "spawn --base with no ref: one line" 'one_line && [[ "$out" == *"--base needs a ref"* ]]' "rc=$rc $out"
out="$("$H" spawn acme t1 "$repo" fix/a --bsae origin/main 2>&1)"; rc=$?
expect "spawn with a misspelt option: refused, not dropped" 'one_line && [[ "$out" == *"unknown option"* ]]' "rc=$rc $out"
out="$("$H" spawn acme t1 "$repo" fix/a extra 2>&1)"; rc=$?
expect "spawn with an extra argument: refused" 'one_line' "rc=$rc $out"
for b in "-x" "a..b" "a b" "x.lock" "@" "fix/"; do
  out="$("$H" spawn acme t1 "$repo" "$b" 2>&1)"; rc=$?
  expect "branch name '$b' refused before herdr is called" \
    'one_line && [[ "$out" == *"not a valid branch name"* ]]' "rc=$rc $out"
done
expect "no herdr call for refused arguments" '[[ ! -s "$FAKE_DIR/calls" ]] || ! grep -q "worktree create" "$FAKE_DIR/calls"'

# spawn when origin's default branch cannot be found: refused, not a quiet
# branch from the local HEAD.
git clone -q "$root/origin.git" "$root/offline"
git -C "$root/offline" remote set-url origin "$root/gone.git"
git -C "$root/offline" symbolic-ref --delete refs/remotes/origin/HEAD
out="$("$H" spawn acme t1 "$root/offline" fix/a 2>&1)"; rc=$?
expect "offline with no origin/HEAD: refused with a hint" \
  'one_line && [[ "$out" == *"pass --base"* ]]' "rc=$rc $out"

# herdr worktree create with unexpected output: one line, nothing left.
out="$(FAKE_FAIL=partial "$H" spawn acme t2 "$repo" fix/partial 2>&1)"; rc=$?
expect "worktree create without a pane: one line" 'one_line && [[ "$out" == *"unexpected output"* ]]' "rc=$rc $out"
expect "its worktree was removed" '[[ ! -d "$FAKE_DIR/wt/acme-t2" ]]'
expect "its branch was deleted" 'no_branch fix/partial'
expect "no task left" 'no_task_left t2'
out="$(FAKE_FAIL=garbage "$H" spawn acme t3 "$repo" fix/garbage 2>&1)"; rc=$?
expect "worktree create printing garbage: one line naming the workspace to close" \
  'one_line && [[ "$out" == *"acme-t3"* ]]' "rc=$rc $out"
expect "no task left" 'no_task_left t3'

# prompt and read arguments.
"$H" spawn acme t4 "$repo" fix/t4 >/dev/null 2>&1
for t in "abc" "0" "-5" ""; do
  out="$("$H" prompt acme/t4 hi --timeout "$t" 2>&1)"; rc=$?
  expect "prompt --timeout '$t' refused" 'one_line && [[ "$out" == *"milliseconds"* ]]' "rc=$rc $out"
done
out="$("$H" prompt acme/t4 hi --timeout 2>&1)"; rc=$?
expect "prompt --timeout with no value: one line" 'one_line' "rc=$rc $out"
for n in "abc" "0" "-1"; do
  out="$("$H" read acme/t4 "$n" 2>&1)"; rc=$?
  expect "read lines '$n' refused" 'one_line' "rc=$rc $out"
done
out="$("$H" read acme/t4 10 extra 2>&1)"; rc=$?
expect "read with an extra argument: refused" 'one_line' "rc=$rc $out"
out="$("$H" agents extra 2>&1)"; rc=$?
expect "agents with an argument: refused" 'one_line' "rc=$rc $out"
out="$("$H" doctor extra 2>&1)"; rc=$?
expect "doctor with an argument: refused" 'one_line' "rc=$rc $out"

# Unexpected herdr output elsewhere.
out="$(FAKE_AGENT_LIST='not json' "$H" agents 2>&1)"; rc=$?
expect "agents with garbage from herdr: one line" 'one_line && [[ "$out" == *"unexpected output"* ]]' "rc=$rc $out"
out="$(FAKE_STATUS='not json' "$H" doctor 2>&1)"; rc=$?
expect "doctor with garbage from herdr status: one line" 'one_line' "rc=$rc $out"

# doctor's version and integration checks.
st() { printf '{"client":{"version":"%s"},"server":{"status":"running","version":"%s","endpoint_compatible":true}}' "$1" "$2"; }
out="$("$H" doctor 2>&1)"; rc=$?
expect "doctor passes on a healthy herdr" '[[ $rc -eq 0 && "$(jq -r .ok <<<"$out")" == true ]]' "rc=$rc $out"
out="$(FAKE_STATUS="$(st 0.10.0-beta 0.10.0-beta)" "$H" doctor 2>&1)"; rc=$?
expect "doctor accepts a version with a suffix" '[[ $rc -eq 0 ]]' "rc=$rc $out"
out="$(FAKE_STATUS="$(st 0.9.4 0.9.4)" "$H" doctor 2>&1)"; rc=$?
expect "doctor refuses an old herdr" 'one_line && [[ "$out" == *"older than"* ]]' "rc=$rc $out"
out="$(FAKE_INTEG='claude: currently not installed' "$H" doctor 2>&1)"; rc=$?
expect "doctor does not read 'currently not installed' as current" \
  'one_line && [[ "$out" == *"not current"* ]]' "rc=$rc $out"
out="$(FAKE_INTEG='claude: current' "$H" doctor 2>&1)"; rc=$?
expect "doctor accepts a bare 'claude: current'" '[[ $rc -eq 0 ]]' "rc=$rc $out"

# A damaged meta: one line, not a jq error.
d="$MCV_HOME/acme/tasks/t4"
cp "$d/meta" "$root/meta.bak"
echo 'not json' >"$d/meta"
for c in "prompt acme/t4 hi" "read acme/t4" "remove acme/t4"; do
  out="$("$H" $c 2>&1)"; rc=$?
  expect "$c with a damaged meta: one line" 'one_line && [[ "$out" == *"damaged meta"* ]]' "rc=$rc $out"
done
cp "$root/meta.bak" "$d/meta"

# remove does not delete a worktree git cannot read.
wt="$(jq -r .worktree "$d/meta")"
echo x >"$wt/file"
git -C "$wt" add file
git -C "$wt" commit -q -m file
mv "$wt/.git" "$wt/.git.away"
out="$("$H" remove acme/t4 2>&1)"; rc=$?
expect "remove refuses a worktree git cannot read" \
  'one_line && [[ "$out" == *"cannot read"* && -f "$wt/file" ]]' "rc=$rc $out"
mv "$wt/.git.away" "$wt/.git"

# mcv-watch arguments and interval.
mkdir -p "$MCV_HOME/acme/tasks"
for a in "--bogus" "--once extra"; do
  out="$(MCV_WATCH_STATE="$root/ws" "$W" acme $a 2>&1)"; rc=$?
  expect "mcv-watch acme $a refused" '[[ $rc -eq 2 && "$out" == *"unexpected arguments"* ]]' "rc=$rc $out"
done
for i in abc 0 -1; do
  out="$(MCV_WATCH_INTERVAL="$i" MCV_WATCH_STATE="$root/ws" "$W" acme --once 2>&1)"; rc=$?
  expect "MCV_WATCH_INTERVAL=$i refused" '[[ $rc -eq 2 && "$out" == *"MCV_WATCH_INTERVAL"* ]]' "rc=$rc $out"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
