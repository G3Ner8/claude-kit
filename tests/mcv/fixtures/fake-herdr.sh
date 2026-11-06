#!/usr/bin/env bash
#
# Stand-in for the herdr command in spawn and remove tests. It does the git
# work herdr does, for real, so git behaves as it does under herdr:
#   worktree create --cwd <repo> --branch <b> [--base <ref>] --label <l> --no-focus
#       runs `git worktree add -b`, which makes a remote-tracking base the
#       branch's upstream, as herdr's worktree create does.
#   worktree remove --workspace <ws>
#   agent start <name> ...   adds <name> to FAKE_DIR/agents
#   agent get <name>         idle if <name> is in FAKE_DIR/agents, else agent_not_found
#   agent prompt <name> ...  reports working
#   pane read <pane> ...     prints "screen of <pane>"
# State lives in FAKE_DIR. Every call appends its arguments to FAKE_DIR/calls.
# FAKE_FAIL=create makes worktree create fail after creating the branch, as a
# git lock failure half way does; FAKE_FAIL=start makes agent start fail;
# FAKE_FAIL=notready makes agent prompt fail as it does once Claude has exited.
# FAKE_FAIL=partial makes worktree create report a workspace id but no pane;
# FAKE_FAIL=garbage makes it print something that is not JSON (both after
# creating the worktree).
#   status --json            FAKE_STATUS, or a healthy herdr 0.9.5
#   integration status       FAKE_INTEG, or "claude: current (v11)"
#   agent list               FAKE_AGENT_LIST, or no agents
# FAKE_SLEEP=<s> makes worktree create take that long.

set -euo pipefail

D="${FAKE_DIR:?FAKE_DIR not set}"
mkdir -p "$D/ws"
printf '%s\n' "$*" >>"$D/calls"

fail() { printf '{"error":{"code":"%s","message":"%s"}}\n' "$1" "$2" >&2; exit 1; }

case "${1:-} ${2:-}" in
  "worktree create")
    shift 2
    cwd="" branch="" base="HEAD" label=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --cwd) cwd="$2"; shift 2 ;;
        --branch) branch="$2"; shift 2 ;;
        --base) base="$2"; shift 2 ;;
        --label) label="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    printf 'begin %s\n' "$label" >>"$D/order"
    [[ -z "${FAKE_SLEEP:-}" ]] || sleep "$FAKE_SLEEP"
    if [[ "${FAKE_FAIL:-}" == create ]]; then
      git -C "$cwd" branch "$branch" "$base" >/dev/null 2>&1
      printf 'end %s\n' "$label" >>"$D/order"
      fail git_failed "could not lock config file"
    fi
    wt="$D/wt/$label"
    git -C "$cwd" worktree add -q -b "$branch" "$wt" "$base" >/dev/null 2>&1
    printf '%s\t%s\n' "$cwd" "$wt" >"$D/ws/ws-$label"
    printf 'end %s\n' "$label" >>"$D/order"
    case "${FAKE_FAIL:-}" in
      partial) printf '{"result":{"workspace":{"workspace_id":"ws-%s"}}}\n' "$label"; exit 0 ;;
      garbage) echo "Segmentation fault"; exit 0 ;;
    esac
    jq -cn --arg ws "ws-$label" --arg wt "$wt" '{result: {
      root_pane: {pane_id: ($ws + ":p1")},
      workspace: {workspace_id: $ws, worktree: {is_linked_worktree: true}},
      worktree: {path: $wt}}}'
    ;;
  "worktree remove")
    ws="$4"
    [[ -f "$D/ws/$ws" ]] || fail workspace_not_found "workspace $ws not found"
    IFS=$'\t' read -r repo wt <"$D/ws/$ws"
    git -C "$repo" worktree remove --force "$wt"
    rm -f "$D/ws/$ws"
    echo '{"result":{}}'
    ;;
  "agent start")
    [[ "${FAKE_FAIL:-}" != start ]] || fail agent_not_ready "claude did not start"
    printf '%s\n' "$3" >>"$D/agents"
    echo '{"result":{}}'
    ;;
  "agent get")
    grep -qxF "$3" "$D/agents" 2>/dev/null || fail agent_not_found "agent $3 not found"
    echo '{"result":{"agent":{"agent_status":"idle"}}}'
    ;;
  "status --json")
    if [[ -n "${FAKE_STATUS:-}" ]]; then printf '%s\n' "$FAKE_STATUS"; else
      echo '{"client":{"version":"0.9.5"},"server":{"status":"running","version":"0.9.5","endpoint_compatible":true}}'
    fi
    ;;
  "integration status")
    if [[ -n "${FAKE_INTEG:-}" ]]; then printf '%s\n' "$FAKE_INTEG"; else echo 'claude: current (v11)'; fi
    ;;
  "agent list")
    if [[ -n "${FAKE_AGENT_LIST:-}" ]]; then printf '%s\n' "$FAKE_AGENT_LIST"; else echo '{"result":{"agents":[]}}'; fi
    ;;
  "pane read")
    echo "screen of $3"
    ;;
  "agent prompt")
    [[ "${FAKE_FAIL:-}" != notready ]] || fail agent_not_ready "$3 is not an active named agent"
    echo '{"result":{"agent":{"agent_status":"working"}}}'
    ;;
  *)
    fail unsupported "fake-herdr does not support: $*"
    ;;
esac
