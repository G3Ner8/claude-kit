#!/usr/bin/env bash
#
# Tests for `mcv-herdr.sh spawn`'s git safety, against a fake herdr that does
# the git work for real (tests/mcv/fixtures/fake-herdr.sh). Needs bash, git
# and jq; no herdr.
# Run: tests/mcv/test-spawn.sh   (exit 0 when every check passes)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
H="$(cd "$HERE/../../plugins/mcv/bin" && pwd -P)/mcv-herdr.sh"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
expect() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/bin"
ln -s "$HERE/fixtures/fake-herdr.sh" "$root/bin/herdr"
export PATH="$root/bin:$PATH" HERDR_ENV=1 MCV_HOME="$root/home" FAKE_DIR="$root/fake"
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
  GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# A remote with main and a branch someone already pushed, and a clone of it
# whose local branches are only main.
git init -q -b main "$root/seed"
git -C "$root/seed" commit -q --allow-empty -m init
git -C "$root/seed" branch feat/taken
git clone -q --bare "$root/seed" "$root/origin.git"
git clone -q "$root/origin.git" "$root/repo"
repo="$root/repo"
git -C "$repo" config push.default upstream

spawn() { "$H" spawn acme "$@"; }
lower_id() { printf '%s' "$1" | tr '[:upper:]/' '[:lower:]-'; }
locks_empty() { [[ -z "$(ls -A "$MCV_HOME/.locks" 2>/dev/null)" ]]; }

# The fake reproduces what makes the upstream fix necessary: a branch made
# from origin/main gets origin/main as its upstream.
"$HERE/fixtures/fake-herdr.sh" worktree create --cwd "$repo" --branch probe --base origin/main \
  --label probe >/dev/null
expect "fake herdr gives a new branch origin/main as upstream, as herdr does" \
  '[[ "$(git -C "$repo" config branch.probe.merge)" == refs/heads/main ]]'
"$HERE/fixtures/fake-herdr.sh" worktree remove --workspace ws-probe >/dev/null
git -C "$repo" branch -D -q probe

# A normal spawn: worktree on the new branch, from origin/main, no upstream.
out="$(spawn t1 "$repo" fix/one 2>&1)"; rc=$?
expect "spawn succeeds" '[[ $rc -eq 0 ]]' "rc=$rc $out"
wt="$(jq -r .worktree <<<"$out" 2>/dev/null)"
expect "spawn reports base origin/main" '[[ "$(jq -r .base <<<"$out")" == origin/main ]]' "$out"
expect "worker branch has no upstream" \
  '[[ -z "$(git -C "$wt" config branch.fix/one.merge)" && -z "$(git -C "$wt" config branch.fix/one.remote)" ]]'
pushout="$(git -C "$wt" push --dry-run 2>&1)"; prc=$?
expect "a plain git push from the worker (push.default=upstream) does not reach main" \
  '[[ $prc -ne 0 && "$pushout" != *"-> main"* ]]' "rc=$prc $pushout"
expect "lock released after a spawn" 'locks_empty'

# Shared branch names are refused before anything is created.
for b in main master develop; do
  out="$(spawn "s-$b" "$repo" "$b" 2>&1)"; rc=$?
  expect "branch '$b' refused" '[[ $rc -eq 1 && "$out" == *"shared branch"* ]]' "rc=$rc $out"
done

# A branch that exists only on the remote is refused, and nothing is left.
out="$(spawn t2 "$repo" feat/taken 2>&1)"; rc=$?
expect "branch that exists only on origin refused" \
  '[[ $rc -eq 1 && "$out" == *"already exists as remotes/origin/feat/taken"* ]]' "rc=$rc $out"
expect "no local branch made for the refused remote branch" \
  '! git -C "$repo" show-ref --verify --quiet refs/heads/feat/taken'
expect "no task left for the refused spawn" '[[ ! -e "$MCV_HOME/acme/tasks/t2" ]]'
expect "lock released after a refused spawn" 'locks_empty'

# A worktree create that fails half way, after git made the branch, leaves
# no branch behind, so the same spawn can be retried.
out="$(FAKE_FAIL=create spawn t3 "$repo" fix/three 2>&1)"; rc=$?
expect "failed worktree create exits 1" '[[ $rc -eq 1 ]]' "rc=$rc $out"
expect "failed worktree create leaves no branch" \
  '! git -C "$repo" show-ref --verify --quiet refs/heads/fix/three'
expect "lock released after a failed spawn" 'locks_empty'
out="$(spawn t3 "$repo" fix/three 2>&1)"; rc=$?
expect "the same spawn succeeds on retry" '[[ $rc -eq 0 ]]' "rc=$rc $out"

# Names are compared ignoring case. On macOS, once refs are packed, a new
# loose MAIN is the same file as main, and committing to it moves main.
git -C "$repo" pack-refs --all
for b in MAIN Main Develop MASTER FIX/ONE Feat/Taken; do
  out="$(spawn "c-$(lower_id "$b")" "$repo" "$b" 2>&1)"; rc=$?
  expect "branch '$b' refused (same as an existing or shared name, ignoring case)" \
    '[[ $rc -eq 1 && ( "$out" == *"shared branch"* || "$out" == *"already exists as"* ) ]]' "rc=$rc $out"
done
expect "main did not move" '[[ "$(git -C "$repo" rev-parse main)" == "$(git -C "$repo" rev-parse origin/main)" ]]'
for b in origin/fix-x ORIGIN/fix-x refs/heads/fix-x HEAD head/x; do
  out="$(spawn c-ref "$repo" "$b" 2>&1)"; rc=$?
  expect "branch '$b' refused as ambiguous" \
    '[[ $rc -eq 1 && ( "$out" == *"plain name"* || "$out" == *"not a valid branch name"* ) ]]' "rc=$rc $out"
done
out="$(spawn c-new "$repo" Fix/New-Thing 2>&1)"; rc=$?
expect "a new name with capitals is still taken" '[[ $rc -eq 0 ]]' "rc=$rc $out"

# Claude failing to start keeps the task, its worktree and branch for remove.
out="$(FAKE_FAIL=start spawn t4 "$repo" fix/four 2>&1)"; rc=$?
expect "failed agent start exits 1" '[[ $rc -eq 1 ]]' "rc=$rc $out"
expect "failed agent start keeps the task" '[[ -f "$MCV_HOME/acme/tasks/t4/meta" ]]'
expect "failed agent start keeps the branch its worktree holds" \
  'git -C "$repo" show-ref --verify --quiet refs/heads/fix/four'

# Two spawns in one repository run one after the other, and both succeed.
: >"$FAKE_DIR/order"
FAKE_SLEEP=1 spawn p1 "$repo" fix/p1 >"$root/p1.out" 2>&1 & a=$!
FAKE_SLEEP=1 spawn p2 "$repo" fix/p2 >"$root/p2.out" 2>&1 & b=$!
wait "$a"; ra=$?
wait "$b"; rb=$?
expect "parallel spawns both succeed" '[[ $ra -eq 0 && $rb -eq 0 ]]' \
  "$ra $(cat "$root/p1.out") / $rb $(cat "$root/p2.out")"
order="$(cut -d' ' -f1 "$FAKE_DIR/order" | tr '\n' ' ')"
expect "parallel spawns do not overlap in worktree create" \
  '[[ "$order" == "begin end begin end " ]]' "$order"

# A lock left by a spawn that died is taken over.
sleep 0 & dead=$!
wait "$dead"
key="$(printf '%s' "$(git -C "$repo" rev-parse --show-toplevel)" | cksum | cut -d' ' -f1)"
mkdir -p "$MCV_HOME/.locks/$key"
echo "$dead $(( $(date +%s) - 60 ))" >"$MCV_HOME/.locks/$key/pid"
out="$(spawn t5 "$repo" fix/five 2>&1)"; rc=$?
expect "a stale lock is taken over" '[[ $rc -eq 0 ]]' "rc=$rc $out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
