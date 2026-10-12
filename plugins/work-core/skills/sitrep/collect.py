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
- a timesheet table for short windows: wall-clock hours per day × project
  (the union of every session's active time, never their sum), meetings from
  an optional --meetings file, and your own commit subjects per cell as the
  raw material for each row's description

Emits ONE compact markdown digest on stdout (working data for the composing
session — never pasted into the briefing verbatim). Zero model calls; stdlib
only. Hard caps everywhere, and whatever a cap cuts is counted, never hidden.
"""
import argparse
import json
import math
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
ATTEND_MIN = 15  # wall-clock hours count only this long after a human turn
GIT_LOG_CAP = 8
MR_CAP = 8
MERGED_CAP = 5  # merged titles repeat far more than open ones; cap them tighter
TREND_MIN_DAYS = 14  # windows longer than this get the week × project table
REPO_CACHE = Path.home() / ".sitrep" / "repos.json"
REPO_CAP = 20  # each repo costs git + MR/PR calls; bounds worst-case runtime
PROJECT_MAP = Path.home() / ".sitrep" / "projects.json"
SUBJECT_CAP = 12  # commit subjects per timesheet cell
LONG_DAY_H = 10  # a day whose wall-clock total passes this is flagged


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


def active_days(s):
    """Local dates a session touched. A session is an interval, not a point: one
    running past midnight belongs to every day it worked, so day/week rollups
    iterate this instead of bucketing on `start`. Falls back to the opening day
    for a session too short to register a gap or a token."""
    return sorted(set(s["per_day"]) | set(s["tok_day"])
                  or {s["start"].astimezone().date()})


def meaningful(text):
    """A gist-worthy user ask: not a command tag, not a bare file path."""
    t = (text or "").strip()
    if not t or t.startswith("<"):
        return False
    words = t.split()
    if len(words) <= 1 and ("/" in t or t.endswith((".md", ".txt"))):
        return False
    return True


def human_turn(ev):
    """An event the person typed: a prompt, a reply or a slash command. Tool
    results, hook output (isMeta) and background task notifications also
    arrive as user events, but nobody was at the keyboard for them."""
    if ev.get("type") != "user" or ev.get("isMeta") or ev.get("isSidechain"):
        return False
    text = first_text((ev.get("message") or {}).get("content")).lstrip()
    return bool(text) and not text.startswith(("<task-notification", "<system-reminder"))


def attended(runs, turns):
    """The parts of `runs` within ATTEND_MIN after a human turn. A session stays
    busy while the agent works alone, so its active time measures the agent's
    day; a timesheet wants the person's, which is the time around their turns."""
    windows = []
    for t in sorted(turns):
        end = t + timedelta(minutes=ATTEND_MIN)
        if windows and t <= windows[-1][1]:
            windows[-1][1] = max(windows[-1][1], end)
        else:
            windows.append([t, end])
    out = []
    for a, b in runs:
        for wa, wb in windows:
            lo, hi = max(a, wa), min(b, wb)
            if lo < hi:
                out.append((lo, hi))
    return out


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


def project_group(path, path_map=PROJECT_MAP):
    """The project a repo or cwd bills to. A timesheet is filled per project,
    not per repo: by default a repo nested inside another repo (a submodule, or
    a workspace repo holding service repos) belongs to the outermost one, so
    `Aware Payroll/pps-web` and `Aware Payroll/pps-ess` land on one row.
    ~/.sitrep/projects.json renames or folds groups: {"<name>": ["<group or
    repo basename>", ...]}. A missing or corrupt map is not an error."""
    outer = Path(path)
    for parent in Path(path).parents:
        if (parent / ".git").exists():
            outer = parent
    group = outer.name
    try:
        for name, members in json.loads(path_map.read_text()).items():
            if group in members or Path(path).name in members:
                return name
    except Exception:
        pass
    return group


def load_meetings(path, cutoff, until):
    """[(start, end, title)] clipped to the window, from a JSON list of
    {"start", "end", "title"}. The composing model writes this file from a
    calendar connector so that the arithmetic stays in this layer. Times
    without an offset are local wall-clock, which is what a calendar shows."""
    if not path:
        return []
    try:
        raw = json.loads(Path(path).read_text())
    except Exception as e:
        sys.exit(f"Error: --meetings {path}: {e}")
    local_tz = datetime.now().astimezone().tzinfo
    out = []
    for m in raw:
        try:
            a = datetime.fromisoformat(m["start"])
            b = datetime.fromisoformat(m["end"])
        except Exception:
            continue
        a = a if a.tzinfo else a.replace(tzinfo=local_tz)
        b = b if b.tzinfo else b.replace(tzinfo=local_tz)
        a, b = max(a, cutoff), min(b, until)
        if a < b:
            out.append((a, b, clip(m.get("title") or "Meeting", 80)))
    return out


def allocate(runs, meetings):
    """Wall-clock minutes per (local date, project) from active runs.

    `runs` is [(start, end, project)] and may overlap freely: sessions run in
    parallel, so summing their active time counts one hour of the person's day
    several times over. A sweep over every boundary instead credits each
    stretch once: a minute shared by N projects gives each 1/N, and a minute
    inside a meeting goes to the meeting alone, since that is where the person
    was. Local midnights are boundaries too, so no stretch straddles two days.
    Returns ({(date, project): minutes}, {(date, "Meeting"): [titles]})."""
    events = []
    for a, b, p in runs:
        events += [(a, 1, p), (b, -1, p)]
    for a, b, t in meetings:
        events += [(a, 1, ("meeting", t)), (b, -1, ("meeting", t))]
    if not events:
        return {}, {}
    first = min(e[0] for e in events).astimezone()
    last = max(e[0] for e in events).astimezone()
    day = first.replace(hour=0, minute=0, second=0, microsecond=0)
    while day <= last:
        events.append((day, 0, None))
        day += timedelta(days=1)
    # ends before starts at the same instant: back-to-back runs must not overlap
    events.sort(key=lambda e: (e[0], e[1]))
    live = defaultdict(int)
    minutes = defaultdict(float)
    titles = defaultdict(list)
    prev = None
    for t, delta, key in events:
        if prev is not None and t > prev:
            span = (t - prev).total_seconds() / 60
            date = prev.astimezone().date()
            meet = [k[1] for k, n in live.items() if n > 0 and isinstance(k, tuple)]
            work = [k for k, n in live.items() if n > 0 and not isinstance(k, tuple)]
            if meet:
                minutes[(date, "Meeting")] += span
                for title in meet:
                    if title not in titles[(date, "Meeting")]:
                        titles[(date, "Meeting")].append(title)
            elif work:
                for p in work:
                    minutes[(date, p)] += span / len(work)
        if key is not None:
            live[key] += delta
        prev = t
    return dict(minutes), dict(titles)


def half_hours(minutes):
    """Round to the nearest half hour, halves up — a timesheet entry unit."""
    return math.floor(minutes / 30 + 0.5) / 2


def main():
    ap = argparse.ArgumentParser(description="sitrep collector")
    ap.add_argument("--days", type=int, default=7, help="rolling window in days (1/7/...)")
    ap.add_argument("--month", help="calendar month YYYY-MM (overrides --days)")
    ap.add_argument("--meetings", help='JSON list of {"start", "end", "title"} for the timesheet')
    args = ap.parse_args()

    now = datetime.now(timezone.utc)
    cutoff, until, label = window_from_args(args, now)
    window_days = (until - cutoff).days or 1
    meetings = load_meetings(args.meetings, cutoff, until)
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
        turns = []  # human turns, including just before the window
        started_before = False
        tok_day = defaultdict(int)  # local date -> output tokens, for spanning sessions
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
                            tok_day[ts.astimezone().date()] += u.get("output_tokens", 0)
                            model = msg.get("model") or model
                            txt = first_text(msg.get("content"))
                            if txt:
                                tail = txt  # last in-window assistant text
                    if not is_main:
                        continue
                    if ts is not None and human_turn(ev):
                        turns.append(ts)
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
        per_day = defaultdict(float)  # local date -> active minutes
        runs = []  # contiguous active stretches, for the wall-clock sweep
        for a, b in zip(times, times[1:]):
            if b - a < timedelta(minutes=GAP_MIN):
                active += b - a
                if runs and runs[-1][1] == a:
                    runs[-1][1] = b
                else:
                    runs.append([a, b])
                # credit the gap to the day it STARTS. A session is not a point in
                # time — one running 29th→31st must land on all three days, not
                # collapse onto whichever day it happened to open on.
                per_day[a.astimezone().date()] += (b - a).total_seconds() / 60
        sessions.append({
            "dir": proj,  # encoded project dir — lossy fallback only (see label pass)
            "cwd": max(cwd_hits, key=cwd_hits.get) if cwd_hits else "",
            "start": times[0],
            "end": times[-1],
            "per_day": dict(per_day),
            "runs": attended(runs, turns),
            "tok_day": dict(tok_day),
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
        s["group"] = project_group(repo_of.get(s["cwd"], s["cwd"])) if s["cwd"] else s["proj"]

    alloc, meeting_titles = allocate(
        [(a, b, s["group"]) for s in sessions for a, b in s["runs"]], meetings)
    wall_min = sum(m for (_, p), m in alloc.items() if p != "Meeting")

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
        a, b = s["start"].astimezone(), s["end"].astimezone()
        day = f"{a:%d %b}" if a.date() == b.date() else f"{a:%d %b}–{b:%d %b}"
        cont = " (cont.)" if s["cont"] else ""
        print(f"- **{s['proj']}** {day}{cont} | {s['active_min']}min | "
              f"{s['out_tok']:,} out-tok | {s['n_user']} prompts | {s['model']}")
        if len(s["per_day"]) > 1:  # timesheet raw material — never a single-day claim
            split = " · ".join(f"{d:%d %b} {m / 60:.1f}h"
                               for d, m in sorted(s["per_day"].items()))
            print(f"  - split: {split}")
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
    print(f"\n**Totals:** ~{wall_min / 60:.1f}h wall-clock attended (~{tot_min / 60:.1f}h "
          f"session-busy, summed across parallel sessions), {tot_out:,} output tokens in main "
          f"sessions + {sub_tok:,} in {sub_files} subagent transcripts, "
          f"{sum(s['n_user'] for s in sessions)} prompts across {len(projects)} projects")

    # ---- per-project rollup (covers what the top-N gist cap cuts)
    print("\n## Projects\n")
    by_proj = defaultdict(list)
    for s in sessions:
        by_proj[s["proj"]].append(s)
    for proj in sorted(by_proj, key=lambda p: -sum(s["out_tok"] for s in by_proj[p])):
        ss = by_proj[proj]
        first = min(s["start"] for s in ss).astimezone()
        last = max(s["end"] for s in ss).astimezone()  # end, not start — see per_day
        span = f"{first:%d %b} → {last:%d %b}"
        print(f"- **{proj}**: {len(ss)} sessions, {sum(s['active_min'] for s in ss) / 60:.1f}h, "
              f"{sum(s['out_tok'] for s in ss):,} out-tok ({span})")

    # ---- week × project trend, long windows only
    if window_days > TREND_MIN_DAYS and sessions:
        print("\n## Weekly effort (week × project)\n")
        print("| week | project | sessions | active | out-tok |")
        print("|---|---|---|---|---|")
        trend = defaultdict(lambda: [0, 0.0, 0])  # (week, proj) -> [sessions, min, tok]
        for s in sessions:
            # same split as the daily log — a session crossing a week boundary
            # belongs to both weeks, not just the one it started in
            for date in active_days(s):
                t = trend["W{:02d}".format(date.isocalendar()[1]), s["proj"]]
                t[0] += 1
                t[1] += s["per_day"].get(date, 0.0)
                t[2] += s["tok_day"].get(date, 0)
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
                   "--format=%h\t%ae\t%aI\t%P\t%s"], top)
        rows = [l.split("\t", 4) for l in log.splitlines() if l.count("\t") >= 4]
        mine = [(h, ae, s) for h, ae, _, _, s in rows if me and ae == me]
        others = [(h, ae, s) for h, ae, _, _, s in rows if not (me and ae == me)]
        # timesheet raw material: your own non-merge commits by local author date.
        # A merge says where work landed, not what was done, so it is left out.
        # `--since` filters on the committer date; a rebase keeps the old author
        # date, so the window is applied again here.
        dated = [(parse_ts(ad).astimezone().date(), scrub(s))
                 for _, ae, ad, parents, s in rows
                 if me and ae == me and len(parents.split()) < 2
                 and parse_ts(ad) and cutoff <= parse_ts(ad) < until]
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
            return name, None, top, dated  # quiet repo
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
        return name, "\n".join(out), top, dated

    quiet = []
    subjects = defaultdict(list)  # (date, project) -> ["repo: subject"]
    with ThreadPoolExecutor(max_workers=8) as pool:
        reports = pool.map(lambda kv: repo_report(*kv), sorted(repos.items()))
    for name, block, top, dated in reports:
        if block is None:
            quiet.append(name)
        else:
            print(block + "\n")
        group = project_group(top)
        for date, subj in sorted(dated):
            line = f"{Path(top).name}: {subj}"
            if line not in subjects[(date, group)]:  # a rebased copy repeats its subject
                subjects[(date, group)].append(line)
    if quiet:
        print(f"({len(quiet)} more repos scanned, no activity in window: {', '.join(sorted(quiet))})")

    # ---- timesheet, short windows only: one cell per day × project
    if window_days <= TREND_MIN_DAYS and (alloc or subjects):
        print_timesheet(alloc, meeting_titles, subjects, bool(args.meetings))
    return 0


KIND_RANK = {"feat": 0, "fix": 1, "perf": 2, "refactor": 3, "build": 4, "ci": 4,
             "test": 5, "docs": 6, "chore": 7}


def pick_subjects(lines, cap):
    """What a cell shows once the cap bites: every repo gets a turn before any
    repo gets a second line, and within a repo feat/fix come before docs and
    chore, because a description is built from what changed, not what was noted."""
    by_repo = defaultdict(list)
    for line in lines:
        repo, subj = line.split(": ", 1)
        kind = re.match(r"(\w+)", subj)
        by_repo[repo].append((KIND_RANK.get(kind.group(1) if kind else "", 8), line))
    queues = [sorted(v) for _, v in sorted(by_repo.items())]
    picked = []
    while len(picked) < cap and any(queues):
        for q in queues:
            if q and len(picked) < cap:
                picked.append(q.pop(0)[1])
    return picked


def print_timesheet(alloc, meeting_titles, subjects, have_meetings):
    print("\n## Timesheet (day × project, wall-clock)\n")
    print(f"Hours are the union of every session's active time within {ATTEND_MIN} min "
          "after a human turn: a stretch shared by N projects gives each 1/N, and a "
          "meeting takes its whole stretch. Each cell is "
          "rounded to the half hour; the exact figure follows in brackets. Subjects are "
          "your own non-merge commits by local author date.")
    if not have_meetings:
        print("\n⚠ No --meetings file: meeting time is not in these hours.")
    days = sorted({d for d, _ in alloc} | {d for d, _ in subjects})
    totals = defaultdict(float)
    for date in days:
        cells = sorted({p for d, p in alloc if d == date} | {p for d, p in subjects if d == date},
                       key=lambda p: (p == "Meeting", -alloc.get((date, p), 0)))
        day_min = sum(alloc.get((date, p), 0) for p in cells)
        flags = []
        if date.weekday() >= 5:
            flags.append("weekend")
        if day_min / 60 > LONG_DAY_H:
            flags.append(f"over {LONG_DAY_H}h")
        flag = f" ⚠ {', '.join(flags)}" if flags else ""
        print(f"\n### {date:%Y-%m-%d %a}: ~{half_hours(day_min)}h ({day_min / 60:.2f}){flag}")
        for p in cells:
            mins = alloc.get((date, p), 0)
            totals[p] += mins
            if not mins:
                hours = "no session time (commits made from another project's session)"
            elif not half_hours(mins):
                hours = f"under 15 min ({mins / 60:.2f})"
            else:
                hours = f"~{half_hours(mins)}h ({mins / 60:.2f})"
            print(f"- **{p}** {hours}")
            if p == "Meeting":
                for title in meeting_titles.get((date, p), []):
                    print(f"  - {title}")
            subj = subjects.get((date, p), [])
            for line in pick_subjects(subj, SUBJECT_CAP):
                print(f"  - {clip(line, 120)}")
            if len(subj) > SUBJECT_CAP:
                print(f"  - (+{len(subj) - SUBJECT_CAP} more commits)")
    print("\n**Window totals (wall-clock):** " + " · ".join(
        f"{p} ~{t / 60:.1f}h" for p, t in sorted(totals.items(), key=lambda x: -x[1])))


if __name__ == "__main__":
    sys.exit(main())
