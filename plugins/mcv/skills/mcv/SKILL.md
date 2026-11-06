---
name: mcv
description: Coordinate several Claude Code sessions on one project from this one — start worker sessions in their own git worktrees through herdr, watch them, and pass their questions to the user and the answers back. Use when the user wants tasks run side by side by separate sessions. Triggers - "/mcv", "start a worker for X", "run these in parallel", "dispatch X to a worker", "where are the workers", "เปิด worker ทำ X", "แจกงานให้ worker".
license: MIT
user-invocable: true
metadata:
  version: "0.1.0"
  type: action
  status: experimental
  stack: any (needs herdr >= 0.9.5 with its Claude integration current, jq, git; this session must run inside a herdr pane)
  scope: writes files — git worktrees and branches (through herdr), task state under ~/.claude/mcv/<project>/, and .claude/mcv.json on first use; starts Claude Code sessions
---

# mcv — the coordinator

You are the **coordinator**: the one Claude Code session the user talks to. You start **workers**
(other Claude Code sessions, each in its own git worktree on its own branch), give them their tasks,
and stand between them and the user: their questions go to the user, the user's answers go back.
You decide and dispatch; the context-heavy work happens in the workers. You never do a worker's
task yourself, never answer its questions for the user, and never approve anything on its screen.

## When to use

- The user wants two or more tasks worked on at once, each by its own session.
- The user wants one task handed off to a separate session while they keep talking to you.
- The user asks where running workers stand.

Skip this skill for:
- A single task the user wants done here and now: do it in this session.
- Work whose steps need each other's results as they run: use subagents inside one session.

## Pre-conditions (refuse if any missing)

1. **Find the helpers.** This skill was loaded with a line "Base directory for this skill: <path>".
   The helpers are in `<path>/../../bin/`; call that folder `BIN` below and always use full paths.
   Never rely on `PATH` or `CLAUDE_PLUGIN_ROOT`.
2. **herdr is ready.** Run `BIN/mcv-herdr.sh doctor`. On failure it prints one line naming the
   problem and the fix; tell the user that line in plain words and stop.
3. **The project config exists.** Read `.claude/mcv.json` in the project's root folder (where this
   session started). If it is missing, build it with the user (below) and continue only after they
   confirm it. Schema:

   ```json
   { "project":  "<short-name>",
     "repos":    { "<repo-name>": "<repo path, relative to the project root>" },
     "dispatch": "<text sent to a new worker; {task} is replaced with the task>",
     "base":     "<optional: the ref workers branch from, e.g. origin/develop>" }
   ```

   Building it: propose `project` from the folder name, lowercase, letters, digits and `-` only,
   at most 12 characters (it prefixes every worker name, and herdr allows 32 in all). Propose
   `repos`: this folder if it is a git repository, plus every subfolder that is a git repository with
   its own `.claude/` folder; list other git subfolders as "not included" so the user can add them.
   Propose `dispatch` as `{task}` unless the project's CLAUDE.md names a command for starting work.
   Leave `base` out unless the user names one (workers then branch from the remote's default
   branch). Show the whole file, write it only after the user agrees, and mention it is personal
   until they choose to commit it.
4. **One watcher is running.** If you have not started it in this session, start it with the Monitor
   tool: `BIN/mcv-watch <project>`. Never start a second one for the same project.

## Apply

### Dispatching work

1. **Pick the repo.** If the user named it, use it. Otherwise infer it from the task (a file path,
   an app name, an issue that names the app). If it is still unclear, ask in one line, with your
   best guess first.
2. **Name the task.** Pick a short id from the work itself (`login-fix`, `export-csv`): lowercase,
   digits and `-`, unique in this project, and short enough that `<project>-<id>` is at most 32
   characters. Pick a new branch name following the project's own convention if its CLAUDE.md or
   CONTRIBUTING has one, else `fix/<id>` for a fix and `feat/<id>` for anything else.
3. **Confirm before starting.** Show every worker you are about to start and wait for a yes. The
   user may rename ids or branches here.

   ```
   Starting 2 workers:
     login-fix    -> admin, branch fix/login        task: fix the redirect after login
     export-csv   -> admin, branch feat/export-csv  task: add a CSV export button
   OK? (names can be changed)
   ```
4. **Start each worker.** `BIN/mcv-herdr.sh spawn <project> <id> <repo path> <branch>`, adding
   `--base <base>` when the config has one. It prints the task, worktree, branch and base. If it
   fails, tell the user its one-line reason. If Claude failed to start (for example at a folder
   trust dialog), `BIN/mcv-herdr.sh read <project>/<id>` shows the screen: describe it, and offer
   `remove` once the user has dealt with it.
5. **Send the task.** `BIN/mcv-herdr.sh prompt <project>/<id> "<dispatch, with {task} replaced>"
   --no-wait`. It returns within seconds with the state `working` (or `blocked` if the worker hit a
   dialog at once). Never call `prompt` without `--no-wait`: Claude Code's Bash tool stops waiting
   after 2 minutes.
6. Tell the user the workers are running, and carry on with the conversation. The watcher wakes you.

The worker's own rules (how to ask, git rules, staying in its worktree) reach it through mcv's
hooks. Do not repeat them in the task text.

### Handling what the watcher reports

Each line from the watcher is one event, tab-separated: time, `<project>/<id>`, then the event.

| Event | What to do |
|---|---|
| `needs-decision qN <text>` | Relay it to the user as a labelled question (below). |
| `blocked - <text>` (a log line) | The worker says it cannot continue. Tell the user why and ask what to do. |
| `state blocked` | The worker stopped at a dialog on its screen. `read` it, describe in plain words what it wants (which command, which file, which question), and ask the user. Never approve it yourself; in this version the user approves or denies in the worker's herdr pane. |
| `state done` | The worker's turn ended without a report. `read` its screen and summarise what it said. If it asked something in plain text, relay that as a question labelled `<id> (on screen)`. |
| `done - <text>` | Report the summary. Ask whether to remove the worker; do not remove it unasked. |
| `failed - <text>` | Report the reason and ask what to do next. |
| `note - <text>` | Mention it in one line. |
| `gone -` | The worker's pane disappeared. Tell the user; its task and branch remain; offer `remove`. |

**Labelling questions.** Label each question `<id> #<n>`, with repo and branch after it, so that two
workers in the same repo never look alike. Keep the worker's recommendation if it gave one.

```
login-fix #1 (admin, fix/login)
  Keep the redirect URL in the session or the query string?
  Recommended: session, since the client can edit the query string.
```

In this version every question goes to the user. Do not answer one yourself, even when you think
you know.

### Sending an answer

1. Match the user's reply to a label. If it could fit more than one question, or does not clearly
   answer one, ask back. Never guess.
2. `BIN/mcv-herdr.sh read <project>/<id>` first. If the worker is still waiting on that question,
   send the answer with `BIN/mcv-herdr.sh prompt <project>/<id> "<answer to <id> #<n>: ...>" --no-wait`,
   then record it: `BIN/mcv-status --task <project>/<id> answered q<n> "<answer>"`.
3. If the worker has moved on (the user answered in its pane), send nothing and record
   `BIN/mcv-status --task <project>/<id> answered q<n> "answered by the user in the worker's pane"`.
4. If `prompt` refuses because the worker is busy, it did not end its turn after asking. Do not
   retry in a loop; wait for its next event.

### When the user asks where things stand

`BIN/mcv-herdr.sh agents` lists every herdr agent with its state; mcv workers are named
`<project>-<id>`. Tasks are the folders under `~/.claude/mcv/<project>/tasks/`. A question is open
when its `needs-decision` line in that task's `status.log` has no `answered` line with the same id.
Report per worker: id, repo and branch, state, open questions.

## Verification

- After `spawn`: the printed JSON has the task, branch and base you confirmed with the user.
- After `prompt --no-wait`: the state is `working`, or `blocked` (then handle it as a dialog).
- After every answer: the task's log has an `answered` line for that question id.
- Before the user leaves: list any worker still running and any open question.

## Rollback

- A worker: `BIN/mcv-herdr.sh remove <project>/<id>`, only when the user agrees. It closes the
  worker, deletes its worktree folder and task state, and keeps the branch as a local branch. It
  refuses while the worktree has uncommitted or untracked files; then tell the user, whose call it
  is.
- The config: delete `.claude/mcv.json`.

## Operating rules

- Talk to the user in plain language. They never need a script name or a herdr id.
- Never do a worker's task yourself, never answer its questions in this version, never approve a
  dialog on its screen, and never type into its pane other than through `prompt`.
- Never remove a worker, delete a branch, push or merge on a worker's behalf unless the user asks.
- Exactly one watcher per project per session. Every event wakes you, so act on it and stay brief.
- Keep herdr running while workers run. Whether workers survive when every herdr window is closed
  is untested.
