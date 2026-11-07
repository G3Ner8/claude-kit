# mcv

> **Experimental, not yet tried end to end (0.1.0).** Every part is written and checked on its own:
> the `/mcv` skill the coordinator follows, the hooks that set up a worker, `bin/mcv-herdr.sh`,
> `bin/mcv-status` and `bin/mcv-watch`. A full run on a real project, from the first task to a merge
> request, has not been done yet. Expect rough edges.

mcv lets you run several Claude Code sessions on one project at once, while you talk to only one of
them.

You work in one Claude Code session, the **coordinator**. When a task can run on its own, the
coordinator starts a **worker**: another Claude Code session, in its own git worktree on its own
branch, so workers never touch your checkout or each other's. A worker asks its questions by writing
them to a **status log**; a **watcher** script notices new lines there, and notices when a worker
stops, and wakes the coordinator, which asks you and sends your answer back.

mcv stands for Multi-session Coordination Vantage.

## Who it is for

- You already split work into tasks that can run side by side (two bugs, a feature and its tests).
- You want those tasks to run in parallel without opening and watching several terminals yourself.
- You want each task isolated on its own branch, and every question from every task in one place.

Not for: a single task (just use Claude Code), or work that needs results passed between tasks as they
run (use Claude Code subagents inside one session).

## What you need

- **herdr** >= 0.9.5 ([herdr.dev](https://herdr.dev)). herdr is a terminal workspace manager built
  for coding agents: it runs each agent in its own terminal pane, creates git worktrees, and lets a
  script start an agent, send it a prompt, read its screen, and see whether it is busy, waiting for
  approval, or finished. mcv does all of that through herdr. Tested with herdr 0.9.5.
- **herdr's Claude integration**, which is how herdr tells whether a Claude session is busy or
  finished. Install or refresh it with `herdr integration install claude`; `herdr integration status`
  must show `claude: current`. Updating herdr does not refresh it, so run the install again after
  every herdr update.
- **Claude Code runs inside herdr.** Start herdr (run `herdr` in a terminal), then start Claude Code in
  one of its panes. Every mcv command refuses to run from a plain terminal, `doctor` included.
- `jq` 1.5 or newer, `git` 2.17 or newer, and bash 3.2 or newer. Written on macOS (stock bash
  3.2); the tests also pass on Ubuntu 24.04, and the main commands were checked with jq 1.5 and
  git 2.17. Running the tests needs git 2.28 or newer. herdr itself is tested only on macOS here.

## Install

```
/plugin marketplace add G3Ner8/claude-kit
/plugin install mcv@claude-kit
```

## Use it

In a Claude Code session started inside a herdr pane, in your project's folder, type `/mcv` (the
slash menu shows it as `/mcv:mcv`). The first time, the coordinator checks herdr, proposes a project
config, and writes `.claude/mcv.json` once you agree:

```json
{ "project":  "acme",
  "repos":    { "admin": "admin", "storefront": "storefront" },
  "dispatch": "{task}" }
```

`project` is a short name that prefixes every worker; `repos` are the repositories workers may be
started in; `dispatch` is the text a new worker receives, with `{task}` replaced by its task.
Optional fields:

- `base`, for example `origin/develop`: where worker branches start. Without it they start from the
  remote's default branch, which on many projects is `main` while work starts from `develop`; the
  coordinator proposes it when it sees that.
- `context`, for example `"."`: a folder workers may read, for a project folder that holds several
  repositories. See [What a worker has](#what-a-worker-has).
- `max_workers` (default 2): how many workers run at once; the coordinator queues the rest.

Then ask for work in plain words ("fix the login redirect in admin, and add a CSV export"). Before
starting anything, the coordinator shows each worker it plans, with its task id, repo and branch, and
waits for your yes. Questions arrive labelled by task, for example `login-fix #1`; answer in plain
words. The coordinator never answers a worker's question or approves a worker's dialog for you.

## Run the helper by hand

Everything the coordinator does goes through `bin/mcv-herdr.sh`, which you can also run yourself.
It is not on your `PATH`. Find it once:

```
find ~/.claude/plugins -name mcv-herdr.sh
```

and call it by that full path, either by asking Claude to run it or by typing it after `!` in Claude
Code. Below, `H` stands for that path.

```
H doctor                                     # herdr, its server, the integration, jq
H spawn shop t1 ~/code/shop fix/login        # new worktree on new branch fix/login, idle Claude in it
H prompt shop/t1 "Fix the login redirect bug"
H read shop/t1                               # what the worker said
H remove shop/t1                             # close it; the branch is kept
```

Run `H` with no arguments for every command and option.

- `shop` is a **project** name and `t1` a **task id**; you choose both. Use lowercase letters, digits,
  `-` and `_`; the project starts with a letter; `<project>-<id>` is at most 32 characters.
- `spawn` needs a branch name that does not exist yet, locally or on a remote; `main`, `master` and
  `develop` are always refused. It fetches first, then starts the branch from the remote's default
  branch (for example `origin/main`), or from `--base <ref>` if you give one, so a worker never starts
  from a stale or unrelated checkout. A repository with no remote starts from its current HEAD; a
  `--base` that names a local branch is used as it is. If the remote's default branch cannot be found
  (for example offline), `spawn` stops and asks for `--base` rather than branch from a stale HEAD. The
  new branch has no upstream, so a plain `git push` from the worker cannot reach the base branch; the
  worker sets one when it first pushes its own branch. Two spawns in the same repository run one
  after the other. `--context <folder>` and `.worktreeinclude`: see
  [What a worker has](#what-a-worker-has). The worktree goes under `~/.herdr/worktrees/`. If no herdr workspace is open for
  that repository yet, herdr also opens one for its main checkout.
- If `spawn` fails while starting Claude, the task is left in place. The usual cause is Claude's
  folder trust dialog, shown the first time Claude opens a folder; its default answer is "No, exit",
  so pick "Yes" in the worker's herdr pane, and `prompt` then works. Otherwise run `remove` before
  using the same id again.
- `prompt` waits until the worker stops, up to 10 minutes by default (`--timeout <ms>`). It prints only
  the worker's new state; `read` shows what the worker said. When Claude runs the helper for you, its
  Bash tool stops waiting after 2 minutes unless given a longer timeout, so for long work use
  `prompt --no-wait`, which returns as soon as the worker has started, and check back with `read`.
- `remove` refuses while the worktree has uncommitted or untracked files, or when git cannot read it.
  Files your `.gitignore` ignores (build output, dependencies, a local `.env`) are deleted with the
  worktree. The branch stays as a local branch; push it first if you need it elsewhere. It also works after you have closed the worker's
  herdr workspace yourself.
- `read` shows the worker's screen even after Claude has exited there; `prompt` then says the worker
  is no longer running Claude.
- Task state is kept outside every repository, in `~/.claude/mcv/<project>/tasks/<id>/`; set
  `MCV_HOME` to keep it elsewhere (`spawn` passes it on to each worker).

Worker states, as herdr reports them:

| State | Meaning | `prompt` accepted? |
|---|---|---|
| `working` | busy | no |
| `blocked` | waiting at an approval or question dialog | no |
| `done` | stopped; its output not yet viewed | yes |
| `idle` | stopped | yes |
| `unknown` | herdr cannot tell | no |

## What a worker has

A worker's worktree is made from git, under `~/.herdr/worktrees/`, so it starts with what is
committed on its base branch and nothing else.

| | In the worker |
|---|---|
| The repo's committed files, including its `CLAUDE.md`, `.claude/skills`, `.claude/agents`, `.claude/settings.json` | yes, as they are on the base branch (a skill only on your local branch is missing) |
| Your own `~/.claude/` (personal `CLAUDE.md`, plugins, user-level MCP servers) | yes |
| The repo's Claude Code memory | yes, shared with the main checkout |
| Files git ignores (`.env`, `qa/.env`, the repo's own `CLAUDE.local.md`) | only those listed in the repo's `.worktreeinclude` (below) |
| `node_modules` and other installed dependencies | no: the worker installs them (`npm ci` and the like) |
| The project folder around the repo: its `CLAUDE.md`, `CLAUDE.local.md`, skills, plans | only with `context` in the config (below) |
| A path that leaves the repo, such as `../other-repo` | no: from a worktree it points elsewhere; the coordinator gives such paths in full in the task |
| `.claude/settings.local.json` (permissions you allowed locally) | only if listed in `.worktreeinclude` |

**`.worktreeinclude`.** A file at the repo's root, in `.gitignore` syntax, naming ignored files to
copy into every new worktree from the main checkout, for example:

```
qa/.env
.env.development.local
```

`spawn` copies a file only when it matches a line, is a regular file (not a symlink), and the
worktree's own git ignores it and has no file there yet. The worktree is on the base branch, which
may track or not ignore a file your checkout ignores; such a file is left alone, so a secret never
overwrites committed content or turns up as a new file for `git add -A`. It is the same file Claude
Code reads for its own worktrees, so one list serves both. It is for a few small files: more than
100 matches and `spawn` stops; dependencies are installed, not copied.

**`context`.** When `.claude/mcv.json` sits in a folder that holds several repositories, a worker
in one of them loses that folder's `CLAUDE.md`, `CLAUDE.local.md` and skills, because its worktree
lives elsewhere. With `"context": "."` the worker is started with that folder added (Claude's
`--add-dir`, with `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`), so it reads them as a session
opened in the repo's own folder would. `--add-dir` would also let it edit there, so the worker's
settings deny Claude's file-editing tools anywhere in that folder (checked: an edit there is
refused), and its rules tell it to treat the folder as read-only; a shell command could still write
there, as in any session. `spawn` refuses a context inside the repository, `/`, and one that holds
the worker's own worktree (your home folder, for instance). Leave it out
when that folder's notes are too broad for a single task; the coordinator then puts what the worker
needs into the task text.

## Permissions

herdr starts each worker as a new Claude Code process with only the arguments `spawn` passes, so a
worker takes its permission mode from your Claude Code settings files, not from the flags you started
your own session with. If your settings default to auto mode, workers run in auto mode, with no one
watching them.

To make a worker ask before acting, pass Claude's own flag after `--`:

```
H spawn shop t1 ~/code/shop fix/login -- --permission-mode default
```

In 0.1.0 such a worker stops in the `blocked` state at each approval dialog, and the helper cannot
answer it: switch to the worker's herdr pane and approve or deny there.

## Git rules for workers

Every worker is told two sets of git rules when it starts.

Always, whatever the project says:
- work only on its own branch; never commit to, push to or merge into any other branch, and never
  to `main`, `master`, `develop` or a protected branch;
- never force-push (`--force-with-lease` on its own branch only);
- never commit secrets.

Everything else follows the project's own git rules (its `CLAUDE.md` or `CONTRIBUTING`), which win.
Where a project says nothing, the worker uses common practice: small Conventional Commits, the
project's tests and linters before committing, a rebase onto the latest base branch, and at the end a
push of its own branch and a **draft** pull or merge request for a person to review.

Your own Claude Code rules apply to workers too, since they run as you: if your `CLAUDE.md` says never
to push without being told, workers will not push.

## How it fits together

- herdr does the process work: creating worktrees, starting Claude, sending prompts, reporting each
  session's state.
- mcv keeps the bookkeeping: which task each worker has, its questions and your answers.
- A worker is marked by the environment variable `MCV_TASK=<project>/<id>`, set only in that worker's
  Claude process. mcv's hooks act only when `MCV_TASK` names a task mcv started, so installing mcv
  does not change your other Claude Code sessions.
