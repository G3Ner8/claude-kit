#!/usr/bin/env python3
"""sitrep collector — deterministic scan of local work signals.

Gathers the raw material for a sitrep briefing over a window (--days N rolling,
or --month YYYY-MM calendar):
- Claude Code session JSONLs (~/.claude/projects): per-session gist + token spend,
  clipped to the window (a session spanning the window edge counts only its
  in-window activity), subagent transcripts included in token totals
- git repos discovered from EVERY distinct session cwd: commits in window,
  uncommitted files, current branch
- open MR/PR state via glab (GitLab) or gh (GitHub), best-effort — reflects NOW,
  not the window end

Emits ONE compact markdown digest on stdout (working data for the composing
session — never pasted into the briefing verbatim). Zero model calls; stdlib
only. Hard caps everywhere, and whatever a cap cuts is counted, never hidden.
"""
import argparse
import json
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

TOP_SESSIONS = 10
GIST_CHARS = 160
GAP_MIN = 10  # inter-event gaps longer than this don't count as active time
GIT_LOG_CAP = 8
MR_CAP = 8
TREND_MIN_DAYS = 14  # windows longer than this get the week × project table


def parse_ts(s):
    try:
        ts = datetime.fromisoformat(s.replace("Z", "+00:00"))
        # naive timestamps would make every comparison raise and silently drop
        # the whole file via the outer per-file guard — pin them to UTC instead
        return ts if ts.tzinfo else ts.replace(tzinfo=timezone.utc)
    except Exception:
        return None


def first_text(content):
    """First real text block from a message content list (skips tool results)."""
    if isinstance(content, str):
        return content
    for block in content or []:
        if isinstance(block, dict) and block.get("type") == "text":
            return block.get("text", "")
    return ""


def clip(s, n=GIST_CHARS):
    s = " ".join((s or "").split())
    return s[: n - 1] + "…" if len(s) > n else s


def cell(s, n):
    """clip() for markdown table cells — a raw `|` would break the row."""
    return clip(s, n).replace("|", "¦")


def meaningful(text):
    """A gist-worthy user ask: not a command tag, not a bare file path."""
    t = (text or "").strip()
    if not t or t.startswith("<"):
        return False
    words = t.split()
    if len(words) <= 1 and ("/" in t or t.endswith((".md", ".txt"))):
        return False
    return True


def run(cmd, cwd=None, timeout=15):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def window_from_args(args, now):
    """(cutoff, until, label) — rolling days or a calendar month in local time."""
    if args.month:
        try:
            y, m = map(int, args.month.split("-"))
            local_tz = now.astimezone().tzinfo
            start = datetime(y, m, 1, tzinfo=local_tz)
            end = datetime(y + 1, 1, 1, tzinfo=local_tz) if m == 12 \
                else datetime(y, m + 1, 1, tzinfo=local_tz)
        except (ValueError, TypeError):
            sys.exit("Error: --month expects YYYY-MM, e.g. 2026-07")
        if start >= now:
            sys.exit(f"Error: --month {args.month} has not started yet")
        until = min(end, now)
        label = f"{args.month} calendar month ({start.date()} → {until.date()})"
        return start, until, label
    cutoff = now - timedelta(days=args.days)
    return cutoff, now, f"{cutoff.date()} → {now.date()} ({args.days}d rolling)"


def main():
    ap = argparse.ArgumentParser(description="sitrep collector")
    ap.add_argument("--days", type=int, default=7, help="rolling window in days (1/7/...)")
    ap.add_argument("--month", help="calendar month YYYY-MM (overrides --days)")
    args = ap.parse_args()

    now = datetime.now(timezone.utc)
    cutoff, until, label = window_from_args(args, now)
    window_days = (until - cutoff).days or 1
    proj_root = Path.home() / ".claude" / "projects"
    if not proj_root.is_dir():
        print("Error: ~/.claude/projects not found — no session data to report on.")
        return 1

    sessions = []
    sub_tok = 0
    sub_files = 0
    all_cwds = set()

    for f in proj_root.rglob("*.jsonl"):
        rel = f.relative_to(proj_root)
        if "memory" in rel.parts:
            continue
        try:
            if datetime.fromtimestamp(f.stat().st_mtime, timezone.utc) < cutoff:
                continue  # file untouched since before the window — nothing in range
        except OSError:
            continue  # deleted mid-scan
        proj = rel.parts[0]
        is_main = len(rel.parts) == 2  # deeper files are subagent transcripts
        ask, tail, model = "", "", ""
        out_tok = n_user = 0
        times = []
        started_before = False
        try:
            with open(f, errors="replace") as fh:
                for line in fh:
                    # subagent files: only assistant usage matters — skip the
                    # JSON parse for everything else (cheap substring gate)
                    if not is_main and '"assistant"' not in line:
                        continue
                    try:
                        ev = json.loads(line)
                    except Exception:
                        continue
                    ts = parse_ts(ev.get("timestamp", ""))
                    in_window = ts is not None and cutoff <= ts < until
                    if ts is not None and ts < cutoff:
                        started_before = True
                    msg = ev.get("message") or {}
                    if ev.get("type") == "assistant" and in_window:
                        u = msg.get("usage") or {}
                        out_tok += u.get("output_tokens", 0)
                        if is_main:
                            model = msg.get("model") or model
                            txt = first_text(msg.get("content"))
                            if txt:
                                tail = txt  # last in-window assistant text
                    if not is_main:
                        continue
                    if in_window:
                        times.append(ts)
                        if ev.get("cwd"):
                            all_cwds.add(ev["cwd"])
                    if ev.get("type") == "user" and not ev.get("isSidechain"):
                        txt = first_text(msg.get("content"))
                        if meaningful(txt):
                            if in_window:
                                n_user += 1
                            if not ask:
                                ask = txt  # session purpose — may predate the window
        except Exception as e:
            print(f"<!-- skipped {rel}: {e} -->", file=sys.stderr)
            continue
        if not is_main:
            if out_tok:
                sub_tok += out_tok
                sub_files += 1
            continue
        if not times:
            continue  # no in-window activity
        times.sort()
        active = timedelta()
        for a, b in zip(times, times[1:]):
            if b - a < timedelta(minutes=GAP_MIN):
                active += b - a
        sessions.append({
            "proj": proj,  # full dir name; mapped to a display name after the scan
            "start": times[0],
            "active_min": int(active.total_seconds() / 60),
            "out_tok": out_tok,
            "n_user": n_user,
            "model": model.split("-2")[0] if model else "?",
            "ask": clip(ask),
            "tail": clip(tail),
            "cont": started_before,
        })

    # ---- display names: last path segment, widened to two segments on collision
    # (two project dirs ending in the same segment must not merge silently)
    disp = {p: p.strip("-").split("-")[-1] for p in {s["proj"] for s in sessions}}
    seen = defaultdict(list)
    for p, d in disp.items():
        seen[d].append(p)
    for d, ps in seen.items():
        if len(ps) > 1:
            for p in ps:
                disp[p] = "-".join(p.strip("-").split("-")[-2:])
    for s in sessions:
        s["proj"] = disp[s["proj"]]

    # ---- emit digest
    print(f"# sitrep digest — {label}")
    print(f"\n## Sessions ({len(sessions)} with in-window activity, top {TOP_SESSIONS} "
          f"by output tokens; stats are window-clipped)\n")
    sessions.sort(key=lambda s: -s["out_tok"])
    shown, rest = sessions[:TOP_SESSIONS], sessions[TOP_SESSIONS:]
    for s in shown:
        day = s["start"].astimezone().strftime("%d %b")
        cont = " (cont.)" if s["cont"] else ""
        print(f"- **{s['proj']}** {day}{cont} | {s['active_min']}min | "
              f"{s['out_tok']:,} out-tok | {s['n_user']} prompts | {s['model']}")
        print(f"  - ask: {s['ask']}")
        print(f"  - end: {s['tail']}")
    if rest:
        print(f"- (+{len(rest)} smaller sessions: {sum(s['active_min'] for s in rest)}min, "
              f"{sum(s['out_tok'] for s in rest):,} out-tok total)")
    if not sessions:
        print("- (no session activity in this window)")

    tot_out = sum(s["out_tok"] for s in sessions)
    tot_min = sum(s["active_min"] for s in sessions)
    projects = sorted({s["proj"] for s in sessions})
    print(f"\n**Totals:** ~{tot_min / 60:.1f}h active, {tot_out:,} output tokens in main "
          f"sessions + {sub_tok:,} in {sub_files} subagent transcripts, "
          f"{sum(s['n_user'] for s in sessions)} prompts across {len(projects)} projects")

    # ---- per-project rollup (covers what the top-N gist cap cuts)
    print("\n## Projects\n")
    by_proj = defaultdict(list)
    for s in sessions:
        by_proj[s["proj"]].append(s)
    for proj in sorted(by_proj, key=lambda p: -sum(s["out_tok"] for s in by_proj[p])):
        ss = by_proj[proj]
        days = sorted(s["start"] for s in ss)
        span = f"{days[0].astimezone().strftime('%d %b')} → {days[-1].astimezone().strftime('%d %b')}"
        print(f"- **{proj}**: {len(ss)} sessions, {sum(s['active_min'] for s in ss) / 60:.1f}h, "
              f"{sum(s['out_tok'] for s in ss):,} out-tok ({span})")

    # ---- day × project log, short windows only (timesheet raw material)
    if window_days <= TREND_MIN_DAYS and sessions:
        print("\n## Daily log (day × project)\n")
        print("| day | project | sessions | active | top ask |")
        print("|---|---|---|---|---|")
        daylog = defaultdict(lambda: [0, 0, None])  # (day, proj) -> [sessions, min, biggest]
        for s in sessions:
            d = daylog[(s["start"].astimezone().strftime("%Y-%m-%d %a"), s["proj"])]
            d[0] += 1
            d[1] += s["active_min"]
            if d[2] is None or s["out_tok"] > d[2]["out_tok"]:
                d[2] = s
        for (day, proj), (n, mins, big) in sorted(daylog.items()):
            print(f"| {day} | {proj} | {n} | {mins / 60:.1f}h | {cell(big['ask'], 70)} |")

    # ---- week × project trend, long windows only
    if window_days > TREND_MIN_DAYS and sessions:
        print("\n## Weekly effort (week × project)\n")
        print("| week | project | sessions | active | out-tok |")
        print("|---|---|---|---|---|")
        trend = defaultdict(lambda: [0, 0, 0])  # (week, proj) -> [sessions, min, tok]
        for s in sessions:
            wk = "W{:02d}".format(s["start"].astimezone().isocalendar()[1])
            t = trend[(wk, s["proj"])]
            t[0] += 1
            t[1] += s["active_min"]
            t[2] += s["out_tok"]
        for (wk, proj), (n, mins, tok) in sorted(trend.items()):
            print(f"| {wk} | {proj} | {n} | {mins / 60:.1f}h | {tok:,} |")

    # ---- git: every distinct session cwd resolved to its repo toplevel
    repos = {}
    for cwd in all_cwds:
        top = run(["git", "-C", cwd, "rev-parse", "--show-toplevel"])
        if top:
            repos[top] = Path(top).name
    print(f"\n## Git ({label})\n")
    since, until_arg = cutoff.isoformat(), until.isoformat()

    def repo_report(top, name):
        """Full report block for one repo — runs in a worker thread because the
        MR/PR lookups are network calls; serial repos made the whole scan crawl."""
        log = run(["git", "log", "--oneline", "--since", since, "--until", until_arg, "--all"], top)
        dirty = run(["git", "status", "--porcelain"], top)
        branch = run(["git", "branch", "--show-current"], top) or "detached"
        remote = run(["git", "remote", "get-url", "origin"], top)
        mr_lines = []
        if "gitlab" in remote:
            mrs = run(["glab", "mr", "list"], top, timeout=12)
            if mrs:
                opens = [l for l in mrs.splitlines() if l.strip().startswith("!")]
                mr_lines = [f"- ⚠ open MR: {clip(l, 120)}" for l in opens[:MR_CAP]] \
                    or ["- open MRs: none"]
            else:
                mr_lines = ["- (MR state unavailable — glab missing or failed; blind spot)"]
        elif "github" in remote:
            prs = run(["gh", "pr", "list", "--state", "open",
                       "--json", "number,title,headRefName"], top, timeout=12)
            if prs and prs != "[]":
                try:
                    parsed = json.loads(prs)
                except Exception:
                    parsed = []
                mr_lines = [f"- ⚠ open PR #{p['number']}: {p['title']} ({p['headRefName']})"
                            for p in parsed[:MR_CAP]]
        has_open = any(l.startswith("- ⚠") for l in mr_lines)
        if not log and not dirty and not has_open:
            return name, None  # quiet repo
        out = [f"### {name} (on `{branch}`)"]
        if log:
            lines = log.splitlines()
            out += [f"- {l}" for l in lines[:GIT_LOG_CAP]]
            if len(lines) > GIT_LOG_CAP:
                out.append(f"- (+{len(lines) - GIT_LOG_CAP} more commits)")
        else:
            out.append("- (no commits in window)")
        if dirty:
            out.append(f"- ⚠ uncommitted: {len(dirty.splitlines())} files")
        out += mr_lines
        return name, "\n".join(out)

    quiet = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        reports = pool.map(lambda kv: repo_report(*kv), sorted(repos.items()))
    for name, block in reports:
        if block is None:
            quiet.append(name)
        else:
            print(block + "\n")
    if quiet:
        print(f"({len(quiet)} more repos scanned, no activity in window: {', '.join(sorted(quiet))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
