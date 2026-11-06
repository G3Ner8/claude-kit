#!/usr/bin/env bash
#
# mcv-herdr.sh: start, prompt, read and remove mcv worker sessions through herdr.
#
# A worker is a separate Claude Code session that herdr starts in its own
# terminal pane, inside a new git worktree. Every command, doctor included,
# must run inside a herdr pane.
#
# Worker states, as herdr reports them: working (busy), blocked (waiting at an
# approval or question dialog), done (stopped, output not yet viewed), idle
# (stopped), unknown (herdr cannot tell).
#
# Commands:
#   doctor
#       Check that herdr, its server, its Claude integration and jq are ready.
#   spawn <project> <id> <repo-path> <new-branch> [--base <ref>] [-- <claude-args>...]
#       Fetch, then create a git worktree of <repo-path> on a branch that must
#       not exist yet, starting from <ref> (default: the remote's default
#       branch, e.g. origin/main; a repository with no remote uses its current
#       HEAD). herdr chooses the folder, under ~/.herdr/worktrees/. Then start
#       an idle Claude in it with MCV_TASK=<project>/<id> set. Send it work with `prompt`. Arguments after
#       `--` go to claude, e.g. -- --permission-mode default. If Claude fails to
#       start, the task is left in place; run `remove` before reusing the id.
#   prompt <project>/<id> <text> [--no-wait] [--timeout <ms>]
#       Send text and wait until the worker stops (default 10 minutes). Prints
#       only the worker's new state; use `read` to see what it said. Refused
#       unless the worker is idle or done. With --no-wait, return as soon as
#       the worker has started (state working, or blocked at a dialog), within
#       seconds. Without it, when run from Claude Code's Bash tool, give the
#       tool a timeout longer than --timeout.
#   read <project>/<id> [<lines>]
#       Print the last lines of the worker's terminal (default 80), plain text.
#   agents
#       Every herdr agent, not only mcv workers, one per line, tab-separated:
#       pane id, state, a counter that increases on every state change (compare
#       two calls to see whether anything changed), and the agent name (mcv
#       workers are named <project>-<id>; "-" when unnamed).
#   remove <project>/<id>
#       Close the worker, delete its worktree folder and the task's mcv state.
#       Refused while the worktree has uncommitted or untracked files. The
#       branch is kept, as a local branch; push it first if you need it.
#
# <project> and <id>: lowercase letters, digits, - and _; <project> starts with
# a letter; "<project>-<id>" is at most 32 characters (it becomes the herdr
# agent name).
#
# Output: one JSON object, except `read` and `agents`. Errors: one line on
# stderr, "mcv-herdr: <command>: <reason>", exit 1. Unknown command: this text,
# exit 2. Task state: ${MCV_HOME:-~/.claude/mcv}/<project>/tasks/<id>/meta.

# For maintainers: this is the only file in mcv that calls herdr. Every other
# mcv file goes through it, so a change in herdr's CLI is fixed here alone.

set -euo pipefail

MIN_HERDR="0.9.5"
MCV_HOME="${MCV_HOME:-$HOME/.claude/mcv}"
PROJECT_RE='^[a-z][a-z0-9_-]*$'
ID_RE='^[a-z0-9][a-z0-9_-]*$'
CMD="${1:-}"

die() { printf 'mcv-herdr: %s: %s\n' "${CMD:-usage}" "$*" >&2; exit 1; }

need_herdr_pane() {
  [[ "${HERDR_ENV:-}" == 1 ]] \
    || die "not inside a herdr pane; start this Claude session from a herdr pane"
}

# Run herdr and return its stdout. On failure, turn herdr's JSON error
# (stderr, exit 1) into one line naming the herdr command.
h() {
  local err out
  err="$(mktemp)"
  if out="$(herdr "$@" 2>"$err")"; then
    rm -f "$err"
    printf '%s' "$out"
    return 0
  fi
  local msg
  msg="$(jq -r '.error | "\(.code): \(.message)"' <"$err" 2>/dev/null || true)"
  [[ -n "$msg" && "$msg" != "null: null" ]] || msg="$(head -1 "$err")"
  rm -f "$err"
  die "herdr $1 ${2:-}: $msg"
}

# True when version $1 >= version $2 (dotted numbers only).
version_ge() {
  local IFS=.
  local -a a=($1) b=($2)
  local i
  for i in 0 1 2; do
    local x="${a[$i]:-0}" y="${b[$i]:-0}"
    (( x > y )) && return 0
    (( x < y )) && return 1
  done
  return 0
}

# Resolve "<project>/<id>" to its task folder; die when the task is unknown.
task_dir() {
  local task="$1"
  [[ "$task" == */* ]] || die "expected <project>/<id>, got '$task'"
  local d="$MCV_HOME/${task%%/*}/tasks/${task#*/}"
  [[ -f "$d/meta" ]] || die "no task '$task' (nothing at $d/meta)"
  printf '%s' "$d"
}

# die() inside a command substitution only leaves the subshell, so every
# caller assigns first and exits on failure before using the value.
agent_of() {
  local d
  d="$(task_dir "$1")" || exit 1
  jq -r '.agent' "$d/meta"
}

agent_status() {
  h agent get "$1" | jq -r '.result.agent.agent_status'
}

cmd_doctor() {
  need_herdr_pane
  command -v jq >/dev/null || die "jq not found; install jq"
  command -v herdr >/dev/null || die "herdr not found; install it from https://herdr.dev"

  local st client server_status server_version compatible
  st="$(h status --json)"
  client="$(jq -r '.client.version' <<<"$st")"
  server_status="$(jq -r '.server.status' <<<"$st")"
  server_version="$(jq -r '.server.version' <<<"$st")"
  compatible="$(jq -r '.server.endpoint_compatible' <<<"$st")"

  version_ge "$client" "$MIN_HERDR" || die "herdr $client is older than $MIN_HERDR; run: herdr update"
  [[ "$server_status" == running ]] \
    || die "herdr server is not running (status: $server_status); start herdr by running: herdr"
  [[ "$compatible" == true ]] \
    || die "herdr server $server_version does not match herdr $client; restart herdr after updating"
  version_ge "$server_version" "$MIN_HERDR" \
    || die "herdr server $server_version is older than $MIN_HERDR; restart herdr after updating"

  local integ
  integ="$(h integration status | grep '^claude:' || true)"
  [[ "$integ" == "claude: current"* ]] \
    || die "herdr's Claude integration is not current (${integ:-missing}); run: herdr integration install claude"

  jq -cn --arg c "$client" --arg s "$server_version" \
    '{ok: true, herdr: $c, server: $s, integration: "current"}'
}

cmd_spawn() {
  need_herdr_pane
  [[ $# -ge 4 ]] || die "usage: spawn <project> <id> <repo-path> <new-branch> [--base <ref>] [-- <claude-args>...]"
  local project="$1" id="$2" repo="$3" branch="$4" base=""
  shift 4
  if [[ "${1:-}" == "--base" ]]; then
    base="${2:?--base needs a ref, e.g. origin/main}"
    shift 2
  fi
  [[ "${1:-}" == "--" ]] && shift

  [[ "$project" =~ $PROJECT_RE ]] \
    || die "project '$project': use lowercase letters, digits, - and _, starting with a letter"
  [[ "$id" =~ $ID_RE ]] \
    || die "id '$id': use lowercase letters, digits, - and _"
  local name="$project-$id"
  (( ${#name} <= 32 )) || die "'$name' is ${#name} characters; <project>-<id> may be at most 32"

  local dir="$MCV_HOME/$project/tasks/$id"
  [[ ! -e "$dir/meta" ]] || die "task $project/$id already exists; pick another id or remove it first"

  local root
  root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || die "not a git repository: $repo"

  # herdr reuses an existing branch without complaint, even main, so a worker
  # could end up committing to it. Only a branch that does not exist is taken.
  if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
    die "branch '$branch' already exists in $root; give the worker a new branch name"
  fi

  # Start from the latest remote state, as a person would pull before
  # branching: fetch, then branch from --base, or from the remote's default
  # branch. A repository with no remote branches from its current HEAD.
  local remote
  if [[ -z "$base" ]] && git -C "$root" remote get-url origin >/dev/null 2>&1; then
    git -C "$root" remote set-head origin --auto >/dev/null 2>&1 || true
    base="$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  fi
  if [[ -n "$base" ]]; then
    remote="${base%%/*}"
    if git -C "$root" remote get-url "$remote" >/dev/null 2>&1; then
      git -C "$root" fetch --quiet "$remote" || die "git fetch $remote failed in $root"
    fi
    git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null \
      || die "base '$base' is not a commit in $root"
  fi

  local created ws pane wt linked
  created="$(h worktree create --cwd "$root" --branch "$branch" ${base:+--base "$base"} \
    --label "$name" --no-focus)"
  ws="$(jq -r '.result.workspace.workspace_id' <<<"$created")"
  pane="$(jq -r '.result.root_pane.pane_id' <<<"$created")"
  wt="$(jq -r '.result.worktree.path' <<<"$created")"
  linked="$(jq -r '.result.workspace.worktree.is_linked_worktree' <<<"$created")"

  # A worker must never run in the user's own checkout. A separate worktree
  # has its own git dir, distinct from the repository's shared one.
  local own common
  own="$(cd "$wt" && cd "$(git rev-parse --git-dir)" && pwd -P)"
  common="$(cd "$wt" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
  if [[ "$linked" != true || "$own" == "$common" ]]; then
    herdr worktree remove --workspace "$ws" >/dev/null 2>&1 || true
    die "refusing: herdr opened $wt, which is the repository's main checkout, not a separate worktree"
  fi

  mkdir -p "$dir"
  local meta
  meta="$(jq -cn --arg task "$project/$id" --arg agent "$name" --arg ws "$ws" --arg pane "$pane" \
    --arg wt "$wt" --arg repo "$root" --arg branch "$branch" --arg base "${base:-HEAD}" \
    --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{task: $task, agent: $agent, workspace_id: $ws, pane_id: $pane, worktree: $wt,
      repo: $repo, branch: $branch, base: $base, created: $created}')"
  printf '%s\n' "$meta" >"$dir/meta"

  # MCV_TASK goes in through Claude's own settings, not the pane's shell, so
  # nothing is typed into the shell before Claude starts.
  local settings
  settings="$(jq -cn --arg t "$project/$id" '{env: {MCV_TASK: $t}}')"
  h agent start "$name" --kind claude --pane "$pane" --timeout 60000 \
    -- --settings "$settings" ${1+"$@"} >/dev/null

  jq -c '{task, agent, worktree, branch, base}' <<<"$meta"
}

cmd_prompt() {
  need_herdr_pane
  [[ $# -ge 2 ]] || die "usage: prompt <project>/<id> <text> [--no-wait] [--timeout <ms>]"
  local task="$1" text="$2" timeout=600000 nowait=""
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-wait) nowait=1; shift ;;
      --timeout) timeout="${2:?--timeout needs a value in ms}"; shift 2 ;;
      *) die "unknown option '$1'" ;;
    esac
  done

  local name status
  name="$(agent_of "$task")" || exit 1
  status="$(agent_status "$name")" || exit 1
  [[ "$status" == idle || "$status" == done ]] \
    || die "worker $task is $status; prompt is only sent to a worker that has stopped (idle or done)"

  if [[ -n "$nowait" ]]; then
    # Return as soon as the worker has started (or stopped at a dialog);
    # herdr itself fails the call if neither happens within 5 seconds.
    h agent prompt "$name" "$text" --wait --until working --until blocked --timeout 15000 \
      | jq -c '{state: .result.agent.agent_status}'
  else
    h agent prompt "$name" "$text" --wait --timeout "$timeout" \
      | jq -c '{state: .result.agent.agent_status}'
  fi
}

cmd_read() {
  need_herdr_pane
  [[ $# -ge 1 ]] || die "usage: read <project>/<id> [<lines>]"
  local name
  name="$(agent_of "$1")" || exit 1
  h agent read "$name" --source recent-unwrapped --lines "${2:-80}"
}

cmd_agents() {
  need_herdr_pane
  h agent list | jq -r '.result.agents[]
    | [.pane_id, .agent_status, (.state_change_seq // 0 | tostring), (.name // "-")] | @tsv'
}

cmd_remove() {
  need_herdr_pane
  [[ $# -eq 1 ]] || die "usage: remove <project>/<id>"
  local dir wt ws branch
  dir="$(task_dir "$1")" || exit 1
  wt="$(jq -r '.worktree' "$dir/meta")"
  ws="$(jq -r '.workspace_id' "$dir/meta")"
  branch="$(jq -r '.branch' "$dir/meta")"
  if [[ -d "$wt" && -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then
    die "refusing: $wt has uncommitted changes; commit or discard them first"
  fi
  h worktree remove --workspace "$ws" >/dev/null
  rm -rf "$dir"
  jq -cn --arg b "$branch" '{removed: true, branch_kept: $b}'
}

case "$CMD" in
  doctor|spawn|prompt|read|agents|remove)
    shift
    "cmd_$CMD" "$@" ;;
  *)
    awk 'NR >= 3 && /^# For maintainers/ { exit } NR >= 3' "${BASH_SOURCE[0]}" \
      | sed 's/^#$//; s/^# //' >&2
    exit 2 ;;
esac
