#!/usr/bin/env bash
#
# Tests for what a worker gets beyond its worktree: `spawn --context` (the
# project folder opened with --add-dir) and `.worktreeinclude` (ignored files
# copied from the main checkout), plus a project whose path has spaces.
# Runs against tests/mcv/fixtures/fake-herdr.sh. Needs bash, git and jq.
# Run: tests/mcv/test-context.sh   (exit 0 when every check passes)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
H="$(cd "$HERE/../../plugins/mcv/bin" && pwd -P)/mcv-herdr.sh"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; }
expect() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

# Spaces everywhere a user's paths may have them.
tmp="$(mktemp -d)"
root="$(cd "$tmp" && pwd -P)/My Projects"
mkdir -p "$root/bin"
trap 'rm -rf "$tmp"' EXIT
ln -s "$HERE/fixtures/fake-herdr.sh" "$root/bin/herdr"
export PATH="$root/bin:$PATH" HERDR_ENV=1 MCV_HOME="$root/mcv home" FAKE_DIR="$root/fake dir"
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
  GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# A project folder holding an app repository, as in a multi-repo workspace.
ws="$root/Acme Workspace"
app="$ws/buyer app"
mkdir -p "$ws"
echo "workspace rules" >"$ws/CLAUDE.md"
git init -q -b main "$app"
cat >"$app/.gitignore" <<'EOF'
qa/.env
.env.local
secrets/
linked.env
notes.txt
EOF
mkdir -p "$app/qa"
echo "tracked config" >"$app/config.env"
git -C "$app" add .gitignore config.env
git -C "$app" commit -q -m init
echo "BUYER_PASS=s3cret" >"$app/qa/.env"
chmod 600 "$app/qa/.env"
echo "LOCAL=1" >"$app/.env.local"
mkdir -p "$app/secrets/deep"
echo "key" >"$app/secrets/deep/my key.pem"
echo "not ignored" >"$app/untracked.env"
ln -s "$app/.env.local" "$app/linked.env"
echo "ignored, not listed" >"$app/notes.txt"
cat >"$app/.worktreeinclude" <<'EOF'
qa/.env
.env.local
secrets/
*.env
EOF
calls() { cat "$FAKE_DIR/calls" 2>/dev/null; }
start_line() { grep '^agent start' "$FAKE_DIR/calls" | tail -1; }

# spawn with --context and .worktreeinclude, all paths with spaces.
out="$("$H" spawn acme t1 "$app" feat/one --context "$ws" 2>&1)"; rc=$?
expect "spawn with --context succeeds on paths with spaces" '[[ $rc -eq 0 ]]' "rc=$rc $out"
wt="$(jq -r .worktree <<<"$out" 2>/dev/null)"
meta="$MCV_HOME/acme/tasks/t1/meta"
expect "meta records the context as an absolute path" '[[ "$(jq -r .context "$meta")" == "$ws" ]]' "$(cat "$meta" 2>/dev/null)"
expect "spawn output names the context" '[[ "$(jq -r .context <<<"$out")" == "$ws" ]]' "$out"
line="$(start_line)"
expect "agent start passes --add-dir with the context" '[[ "$line" == *"--add-dir $ws --settings "* ]]' "$line"
settings="$(sed -E 's/.*--settings (\{.*\}).*/\1/' <<<"$line")"
expect "settings turn on CLAUDE.md loading from added folders" \
  '[[ "$(jq -r .env.CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD <<<"$settings")" == 1 ]]' "$settings"
expect "settings deny Claude's file edits under the context" \
  '[[ "$(jq -c .permissions.deny <<<"$settings")" == "[\"Edit(/$ws/**)\"]" ]]' "$settings"
expect "settings still carry MCV_TASK and MCV_HOME" \
  '[[ "$(jq -r .env.MCV_TASK <<<"$settings")" == acme/t1 && "$(jq -r .env.MCV_HOME <<<"$settings")" == "$MCV_HOME" ]]' "$settings"

# .worktreeinclude: ignored files that match are copied, nothing else.
expect "spawn reports 3 files copied" '[[ "$(jq -r .copied <<<"$out")" == 3 ]]' "$out"
expect "copied exactly the ignored files that match" \
  '[[ -f "$wt/.env.local" && -f "$wt/qa/.env" && -f "$wt/secrets/deep/my key.pem" ]]'
expect "qa/.env copied with its contents" '[[ "$(cat "$wt/qa/.env")" == "BUYER_PASS=s3cret" ]]'
expect "qa/.env keeps its mode 600" '[[ "$(stat -c %a "$wt/qa/.env" 2>/dev/null || stat -f %Lp "$wt/qa/.env")" == 600 ]]'
expect "a file in a listed folder, name with a space, copied" '[[ -f "$wt/secrets/deep/my key.pem" ]]'
expect "an untracked file that git does not ignore is not copied" '[[ ! -e "$wt/untracked.env" ]]'
expect "an ignored file not listed is not copied" '[[ ! -e "$wt/notes.txt" ]]'
expect "an ignored symlink is not copied" '[[ ! -e "$wt/linked.env" && ! -L "$wt/linked.env" ]]'
expect "a tracked file matching a pattern keeps its committed content" '[[ "$(cat "$wt/config.env")" == "tracked config" ]]'
expect "the worktree's git status stays clean (copies are ignored)" '[[ -z "$(git -C "$wt" status --porcelain)" ]]'
expect "meta records how many files were copied" '[[ "$(jq -r .copied "$meta")" == 3 ]]'

# The rest of the cycle works on the spaced paths.
echo "acme-t1" >>"$FAKE_DIR/agents"
out="$("$H" prompt acme/t1 "go" --no-wait 2>&1)"; rc=$?
expect "prompt works with spaced paths" '[[ $rc -eq 0 ]]' "rc=$rc $out"
out="$("$H" read acme/t1 2>&1)"; rc=$?
expect "read works with spaced paths" '[[ $rc -eq 0 ]]' "rc=$rc $out"
out="$("$H" remove acme/t1 2>&1)"; rc=$?
expect "remove works with spaced paths (copied ignored files do not block it)" '[[ $rc -eq 0 && ! -d "$wt" ]]' "rc=$rc $out"

# Without --context and without .worktreeinclude: nothing extra.
mv "$app/.worktreeinclude" "$root/wti.bak"
out="$("$H" spawn acme t2 "$app" feat/two 2>&1)"; rc=$?
expect "spawn without --context succeeds" '[[ $rc -eq 0 ]]' "rc=$rc $out"
line="$(start_line)"
expect "no --add-dir without --context" '[[ "$line" != *"--add-dir"* ]]' "$line"
expect "no CLAUDE.md-loading variable without --context" '[[ "$line" != *CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD* ]]' "$line"
expect "no context in meta" '[[ "$(jq -r .context "$MCV_HOME/acme/tasks/t2/meta")" == "" ]]'
expect "nothing copied without .worktreeinclude" '[[ "$(jq -c .copied <<<"$out")" == 0 ]]' "$out"
mv "$root/wti.bak" "$app/.worktreeinclude"

# The worktree's git decides, not the main checkout's. The base branch
# (develop here) tracks app.env and does not ignore local.env; the main
# checkout, on another branch, ignores both and has secret copies.
git -C "$app" checkout -q -b develop
echo "committed app.env" >"$app/app.env"
git -C "$app" add app.env
git -C "$app" commit -q -m "track app.env"
git -C "$app" checkout -q main
printf 'app.env\nlocal.env\n' >>"$app/.gitignore"
git -C "$app" commit -q -am "ignore app.env and local.env on main"
echo "SECRET in main checkout" >"$app/app.env"
echo "SECRET local" >"$app/local.env"
printf 'app.env\nlocal.env\n' >>"$app/.worktreeinclude"
out="$("$H" spawn acme t6 "$app" feat/six --base develop 2>&1)"; rc=$?
wt6="$(jq -r .worktree <<<"$out" 2>/dev/null)"
expect "spawn from a base that tracks a listed file succeeds" '[[ $rc -eq 0 ]]' "rc=$rc $out"
expect "a file the base tracks keeps its committed content" '[[ "$(cat "$wt6/app.env")" == "committed app.env" ]]'
expect "a file the base does not ignore is not copied" '[[ ! -e "$wt6/local.env" ]]'
expect "the worktree stays clean, so nothing secret can be committed by git add -A" \
  '[[ -z "$(git -C "$wt6" status --porcelain)" ]]' "$(git -C "$wt6" status --porcelain)"
out="$("$H" remove acme/t6 2>&1)"; rc=$?
expect "remove is not blocked by the copy" '[[ $rc -eq 0 ]]' "rc=$rc $out"

# Too many files: refused in one line, nothing left behind.
mkdir -p "$app/many"
for i in $(seq 1 101); do : >"$app/many/f$i"; done
printf 'many/\n' >>"$app/.gitignore"
git -C "$app" commit -q -am "ignore many/"
printf 'many/\n' >>"$app/.worktreeinclude"
out="$("$H" spawn acme t7 "$app" feat/seven 2>&1)"; rc=$?
expect "more than 100 listed files: refused in one line" \
  '[[ $rc -eq 1 && $(printf "%s\n" "$out" | wc -l) -eq 1 && "$out" == *"more than 100"* ]]' "rc=$rc $out"
expect "the refused spawn left no task, branch or worktree" \
  '[[ ! -e "$MCV_HOME/acme/tasks/t7" && ! -d "$FAKE_DIR/wt/acme-t7" ]] && ! git -C "$app" show-ref --verify --quiet refs/heads/feat/seven'

# A file that cannot be read: refused in one line. root reads any file, so
# this case only exists for a normal user.
rm -rf "$app/many"
if [[ "$(id -u)" -eq 0 ]]; then
  ok "an unreadable listed file (skipped: running as root)"
  ok "nothing left behind (skipped: running as root)"
else
chmod 000 "$app/qa/.env"
out="$("$H" spawn acme t8 "$app" feat/eight 2>&1)"; rc=$?
chmod 600 "$app/qa/.env"
expect "an unreadable listed file: refused in one line naming it" \
  '[[ $rc -eq 1 && $(printf "%s\n" "$out" | wc -l) -eq 1 && "$out" == *"could not copy qa/.env"* ]]' "rc=$rc $out"
expect "nothing left behind" '[[ ! -e "$MCV_HOME/acme/tasks/t8" ]] && ! git -C "$app" show-ref --verify --quiet refs/heads/feat/eight'
fi

# Claude's own arguments still come last, after --settings.
out="$("$H" spawn acme t3 "$app" feat/three --context "$ws" -- --permission-mode default 2>&1)"; rc=$?
line="$(start_line)"
expect "claude args after -- follow --settings" '[[ $rc -eq 0 && "$line" == *"--settings "*"} --permission-mode default" ]]' "rc=$rc $line"

# --context refusals.
for c in "$root/nope" "$app" "$app/qa"; do
  out="$("$H" spawn acme t4 "$app" feat/four --context "$c" 2>&1)"; rc=$?
  expect "--context '${c#$root/}' refused" '[[ $rc -eq 1 && $(printf "%s\n" "$out" | wc -l) -eq 1 ]]' "rc=$rc $out"
done
out="$("$H" spawn acme t4 "$app" feat/four --context 2>&1)"; rc=$?
expect "--context with no folder refused" '[[ $rc -eq 1 && "$out" == *"needs a folder"* ]]' "rc=$rc $out"
expect "refused spawns left no task and no branch" \
  '[[ ! -e "$MCV_HOME/acme/tasks/t4" ]] && ! git -C "$app" show-ref --verify --quiet refs/heads/feat/four'

# More --context refusals: the whole disk, a folder holding the worker's
# own worktree, the repository spelt in another case, given twice.
out="$("$H" spawn acme t9 "$app" feat/nine --context / 2>&1)"; rc=$?
expect "--context / refused" '[[ $rc -eq 1 && "$out" == *"whole disk"* ]]' "rc=$rc $out"
out="$("$H" spawn acme t9 "$app" feat/nine --context "$root" 2>&1)"; rc=$?
expect "--context holding the worktree refused" '[[ $rc -eq 1 && "$out" == *"holds the worker"* ]]' "rc=$rc $out"
expect "that refusal left no task, branch or worktree" \
  '[[ ! -e "$MCV_HOME/acme/tasks/t9" && ! -d "$FAKE_DIR/wt/acme-t9" ]] && ! git -C "$app" show-ref --verify --quiet refs/heads/feat/nine'
upper="$(printf '%s' "$app" | sed 's#buyer app$#BUYER APP#')"
out="$("$H" spawn acme t9 "$app" feat/nine --context "$upper" 2>&1)"; rc=$?
expect "--context naming the repository in another case refused" '[[ $rc -eq 1 ]]' "rc=$rc $out"
out="$("$H" spawn acme t9 "$app" feat/nine --context "$ws" --context "$ws" 2>&1)"; rc=$?
expect "--context given twice refused" '[[ $rc -eq 1 && "$out" == *"twice"* ]]' "rc=$rc $out"
out="$("$H" spawn acme 2>&1)"; rc=$?
expect "spawn's usage line names --context" '[[ $rc -eq 1 && "$out" == *"--context <folder>"* ]]' "rc=$rc $out"

# A relative --context ignores CDPATH.
mkdir -p "$root/decoy/Acme Workspace"
out="$(cd "$root" && CDPATH="$root/decoy" "$H" spawn acme t10 "$app" feat/ten --context "Acme Workspace" 2>&1)"; rc=$?
expect "a relative --context is not looked up through CDPATH" \
  '[[ $rc -eq 0 && "$(jq -r .context <<<"$out")" == "$ws" ]]' "rc=$rc $out"

# A relative --context is taken from the current folder.
out="$(cd "$root" && "$H" spawn acme t5 "$app" feat/five --context "Acme Workspace" 2>&1)"; rc=$?
expect "a relative --context resolves to an absolute path" \
  '[[ $rc -eq 0 && "$(jq -r .context <<<"$out")" == "$ws" ]]' "rc=$rc $out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
