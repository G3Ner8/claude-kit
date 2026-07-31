#!/usr/bin/env python3
"""sitrep collector — deterministic scan of local work signals.

Gathers the raw material for a sitrep briefing over a window (--days N rolling,
or --month YYYY-MM calendar):
- Claude Code session JSONLs (~/.claude/projects): per-session gist + token spend,
  clipped to the window (a session spanning the window edge counts only its
  in-window activity), subagent transcripts included in token totals
- git repos from every session cwd PLUS a self-maintaining cross-run cache
  (~/.sitrep/repos.json), so work that shipped in a repo untouched this window
  still surfaces: commits in window, uncommitted files, current branch. Commits
  and MRs/PRs are attributed — a cached repo's history may well be someone
  else's, and a report headed "what I did" must not absorb it
- MR/PR state via glab (GitLab) or gh (GitHub), best-effort: open MRs/PRs
  (current state = open loops) plus MRs/PRs merged inside the window (= what
  shipped, and the positive signal that clears a carried-over open loop)

Emits ONE compact markdown digest on stdout (working data for the composing
session — never pasted into the briefing verbatim). Zero model calls; stdlib
only. Hard caps everywhere, and whatever a cap cuts is counted, never hidden.
"""
import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

TOP_SESSIONS = 10
GIST_CHARS = 160
TAIL_CHARS = 80  # a session's last words rarely carry signal — half the budget
GAP_MIN = 10  # inter-event gaps longer than this don't count as active time
GIT_LOG_CAP = 8
MR_CAP = 8
MERGED_CAP = 5  # merged titles repeat far more than open ones; cap them tighter
TREND_MIN_DAYS = 14  # windows longer than this get the week × project table
REPO_CACHE = Path.home() / ".sitrep" / "repos.json"
REPO_CAP = 20  # each repo costs git + MR/PR calls; bounds worst-case runtime


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


# Session gists are raw user prompt text: API keys, passwords and connection
# strings get pasted into prompts routinely, and from the digest a secret reaches
# a model's context and then a briefing file that may be pasted into a chat or a
# timesheet. Redaction has to happen in the deterministic layer — the model must
# never be handed a live credential and trusted to summarize around it.
SECRET_RE = re.compile(
    r"Bearer\s+[A-Za-z0-9._~+/=-]{12,}"
    r"|\b(?:sk|pk|ghp|gho|ghu|ghs|glpat|awr|xox[bpaes]|npm)[_-][A-Za-z0-9_-]{10,}"
    r"|\bAKIA[0-9A-Z]{12,}"
    r"|\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]*"
    r"|(?P<kw>\b(?:pass(?:word)?|passwd|secret|token|api[_-]?key|auth)\s*[:=]\s*)"
    r"['\"]?[^\s'\"]{8,}"
    r"|\b[a-z][a-z0-9+.-]*://[^\s/@:]+:[^\s/@]+@",
    re.I,
)


def scrub(s):
    """Replace credential-shaped runs with a marker, keeping the label when the
    match was a `key = value` assignment (the fact matters, the value must not)."""
    return SECRET_RE.sub(lambda m: (m.group("kw") or "") + "[redacted]", s or "")


def clip(s, n=GIST_CHARS):
    # scrub before truncating: a secret cut mid-string still leaks its prefix
    s = " ".join(scrub(s).split())
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


def merged_in_window(json_str, ts_field, cutoff, until):
    """Items from a `glab/gh ... -F json` list merged inside the window, newest
    first. `glab mr list --merged` / `gh pr list --state merged` return recent
    merges regardless of date, so the window filter happens here."""
    try:
        items = json.loads(json_str)
    except Exception:
        return []
    hits = [(parse_ts(it.get(ts_field) or ""), it) for it in items]
    hits = [(ts, it) for ts, it in hits if ts and cutoff <= ts < until]
    hits.sort(key=lambda x: -x[0].timestamp())
    return [it for _, it in hits]


def repo_set(discovered, path=REPO_CACHE):
    """(repos to scan, n from cache, n cut by the cap) — this run's discoveries
    unioned with every repo seen on a previous run.

    Session cwds only reveal repos opened locally, so work that shipped in a repo
    untouched this window (a teammate's merge, an agent's MR) would be invisible.
    The cache is self-maintaining: entries whose path is gone are dropped, and it
    is rewritten every run. A missing or corrupt cache is not an error.
    """
    known = set()
    try:
        known = {p for p in json.loads(path.read_text()) if isinstance(p, str)}
    except Exception:
        pass
    live = {p for p in known | discovered if Path(p, ".git").exists()}
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(sorted(live), indent=0))
    except OSError:
        pass  # cache is an optimisation; failing to persist must not fail the run
    # this run's own repos always win a contested cap slot — they are the active ones
    active = sorted(live & discovered)
    extra = sorted(live - discovered)
    kept = active + extra[: max(0, REPO_CAP - len(active))]
    return kept, len(extra), len(live) - len(kept)


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
    oldest_log = None  # earliest mtime seen, incl. files skipped as out-of-window

    for f in proj_root.rglob("*.jsonl"):
        rel = f.relative_to(proj_root)
        if "memory" in rel.parts:
            continue
        try:
            mtime = datetime.fromtimestamp(f.stat().st_mtime, timezone.utc)
        except OSError:
            continue  # deleted mid-scan
        if oldest_log is None or mtime < oldest_log:
            oldest_log = mtime
        if mtime < cutoff:
            continue  # file untouched since before the window — nothing in range
        proj = rel.parts[0]
        is_main = len(rel.parts) == 2  # deeper files are subagent transcripts
        ask, tail, model = "", "", ""
        out_tok = n_user = 0
        times = []
        started_before = False
        cwd_hits = defaultdict(int)  # this session's own cwds — the label source
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
                            cwd_hits[ev["cwd"]] += 1
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
            "dir": proj,  # encoded project dir — lossy fallback only (see label pass)
            "cwd": max(cwd_hits, key=cwd_hits.get) if cwd_hits else "",
            "start": times[0],
            "active_min": int(active.total_seconds() / 60),
            "out_tok": out_tok,
            "n_user": n_user,
            "model": model.split("-2")[0] if model else "?",
            "ask": clip(ask),
            "tail": clip(tail, TAIL_CHARS),
            "cont": started_before,
        })

    # ---- resolve every session cwd to its git toplevel. Done here rather than
    # with the git section because labels depend on it: the encoded project dir
    # name is LOSSY — `/` became `-`, so a hyphen inside a real directory name
    # is indistinguishable from a separator (`…-Workspace-claude-kit` → "kit",
    # `…-Aware-Payroll-pps-web` → "web"). The cwd on each event is the real path.
    repo_of = {}
    for cwd in all_cwds:
        top = run(["git", "-C", cwd, "rev-parse", "--show-toplevel"])
        if top:
            repo_of[cwd] = top

    repo_tops, n_cached, repo_cut = repo_set(set(repo_of.values()))

    # ---- display names: repo (or cwd) basename, widened to two segments on
    # collision — matched case-insensitively, since `Workspace` and `workspace`
    # read as the same project to a human even though they differ as dict keys
    label_paths = {repo_of.get(c, c) for c in all_cwds} | set(repo_tops)
    disp = {p: Path(p).name for p in label_paths}
    seen = defaultdict(list)
    for p, d in disp.items():
        seen[d.lower()].append(p)
    for d, ps in seen.items():
        if len(ps) > 1:
            for p in ps:
                disp[p] = "/".join(Path(p).parts[-2:])
    for s in sessions:
        # a session with no cwd on any in-window event falls back to the lossy
        # dir name — marked `?` so the briefing never presents it as exact
        s["proj"] = disp.get(repo_of.get(s["cwd"], s["cwd"])) \
            or (s["dir"].strip("-").split("-")[-1] + "?")

    # ---- emit digest
    print(f"# sitrep digest — {label}")

    # A window reaching back past the oldest surviving log is a measurement gap,
    # not a quiet week — Claude Code prunes session logs after cleanupPeriodDays
    # (default 30). Declare it; effort stats below are a floor, not a total.
    if oldest_log and (oldest_log - cutoff).days >= 1:
        print(f"\n⚠ **Log horizon:** oldest session log on disk is "
              f"{oldest_log.astimezone().date()}, {(oldest_log - cutoff).days}d after the "
              f"window opens. Nothing survives for {cutoff.date()} → "
              f"{oldest_log.astimezone().date()} (unused, or pruned by `cleanupPeriodDays`, "
              f"default 30) — session/effort figures for that span are MISSING, not zero. "
              f"Git and MR/PR data below are unaffected.")

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

    # ---- git: session-cwd repos plus the cross-run cache
    repos = {top: disp.get(top, Path(top).name) for top in repo_tops}
    src = f"{len(set(repo_of.values()))} from session cwds"
    if n_cached:
        src += f" + {n_cached} from cache (`~/.sitrep/repos.json`)"
    if repo_cut:
        src += f"; **{repo_cut} cached repos NOT scanned** ({REPO_CAP}-repo cap)"
    print(f"\n## Git ({label}) — {len(repos)} repos: {src}\n")
    since, until_arg = cutoff.isoformat(), until.isoformat()

    def repo_report(top, name):
        """Full report block for one repo — runs in a worker thread because the
        MR/PR lookups are network calls; serial repos made the whole scan crawl."""
        # Authorship is not optional here. A cached repo is by definition one this
        # window's sessions never opened, so its history is as likely to be a
        # teammate's as yours — and a report headed "what I did" must not absorb
        # it. Commits are split by author email against this repo's own identity.
        me = run(["git", "config", "user.email"], top)
        log = run(["git", "log", "--since", since, "--until", until_arg, "--all",
                   "--format=%h\t%ae\t%s"], top)
        rows = [l.split("\t", 2) for l in log.splitlines() if l.count("\t") >= 2]
        mine = [r for r in rows if me and r[1] == me]
        others = [r for r in rows if not (me and r[1] == me)]
        dirty = run(["git", "status", "--porcelain"], top)
        branch = run(["git", "branch", "--show-current"], top) or "detached"
        remote = run(["git", "remote", "get-url", "origin"], top)
        mr_lines = []
        if "gitlab" in remote:
            opens = run(["glab", "mr", "list"], top, timeout=12)
            if opens:
                ol = [l for l in opens.splitlines() if l.strip().startswith("!")]
                mr_lines += [f"- ⚠ open MR: {clip(l, 120)}" for l in ol[:MR_CAP]]
            else:
                mr_lines.append("- (open-MR state unavailable — glab missing or failed; blind spot)")
            merged = merged_in_window(
                run(["glab", "mr", "list", "--merged", "-F", "json", "--per-page", "40"], top, timeout=12),
                "merged_at", cutoff, until)
            mr_lines += [f"- ✓ merged !{m['iid']} by {(m.get('author') or {}).get('username', '?')}"
                         f": {clip(m['title'], 100)}" for m in merged[:MERGED_CAP]]
        elif "github" in remote:
            opens = run(["gh", "pr", "list", "--state", "open",
                         "--json", "number,title,headRefName"], top, timeout=12)
            if opens and opens != "[]":
                try:
                    parsed = json.loads(opens)
                except Exception:
                    parsed = []
                mr_lines += [f"- ⚠ open PR #{p['number']}: {p['title']} ({p['headRefName']})"
                             for p in parsed[:MR_CAP]]
            merged = merged_in_window(
                run(["gh", "pr", "list", "--state", "merged", "--json",
                     "number,title,mergedAt,author", "--limit", "40"], top, timeout=12),
                "mergedAt", cutoff, until)
            mr_lines += [f"- ✓ merged PR #{m['number']} by {(m.get('author') or {}).get('login', '?')}"
                         f": {clip(m['title'], 100)}" for m in merged[:MERGED_CAP]]
        has_mr = any(l.startswith(("- ⚠", "- ✓")) for l in mr_lines)
        if not rows and not dirty and not has_mr:
            return name, None  # quiet repo
        out = [f"### {name} (on `{branch}`)"]
        if mine:
            out += [f"- {h} {scrub(s)}" for h, _, s in mine[:GIT_LOG_CAP]]
            if len(mine) > GIT_LOG_CAP:
                out.append(f"- (+{len(mine) - GIT_LOG_CAP} more of your commits)")
        elif not rows:
            out.append("- (no commits in window)")
        if others:
            # named, counted, never listed as yours — an agent identity committing
            # on your behalf shows up here too, which is why they are not dropped
            who = defaultdict(int)
            for _, ae, _ in others:
                who[ae.split("@")[0]] += 1
            ranked = sorted(who.items(), key=lambda x: -x[1])[:3]
            # one author needs no count — it equals the total already stated
            top_who = ranked[0][0] if len(who) == 1 else \
                ", ".join(f"{a} {n}" for a, n in ranked)
            out.append(f"- ⓘ NOT yours: {len(others)} commits by {top_who}"
                       + (f" (+{len(who) - 3} more authors)" if len(who) > 3 else ""))
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
