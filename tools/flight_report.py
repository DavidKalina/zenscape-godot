#!/usr/bin/env python3
"""Aggregate the flight study's runs into a report per station.

Reads every run JSON the flight study and its bench saved (scripts/flight_log.gd,
user://flight_runs), groups them by station and station hash (a changed layout
is a new record), and writes:

  flight_report.html  per station: the bots' band and per-skill numbers, the
                      people's runs with their ratings side by side, and a
                      demand-curve strip chart (SVG) of each run against the
                      perfect bot's reference line
  flight_report.md    the same tables as markdown
  flight_runs.csv     one row per run, every summary number flattened, for
                      clustering stations into types later

Examples:
  python3 tools/flight_report.py
  python3 tools/flight_report.py --dir path/to/flight_runs --out /tmp/report
  python3 tools/flight_report.py --open

Runs saved before the threading numbers existed get them from
threading_backfill.json, which tools/flight_threading.gd writes from their
recorded ticks (run headless here automatically when Godot is found; pass
--no-backfill to skip). The run files themselves are only read.

Standard library only.
"""
from __future__ import annotations

import argparse
import csv
import html
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILLS = ["sloppy", "decent", "sharp", "perfect"]
SUMMARY_KEYS = [
    "duration", "collected", "total", "cleared", "bumps",
    "turn_need_peak", "turn_need_mean", "pitch_need_peak", "pitch_need_mean",
    "turn_flown_peak", "turn_flown_mean", "pitch_flown_peak", "pitch_flown_mean",
    "warning_min", "warning_mean", "reversals_per_s", "effort", "full_share",
    "reach", "room_min", "demand_peak", "demand_mean", "demand_spike", "grade",
    "threading_share", "openings", "openings_per_s",
]
THREAD_KEYS = ["threading_share", "openings", "openings_per_s", "threading_s"]
SIDE = "threading_backfill.json"
DEFAULT_GODOT = Path.home() / "Applications" / "Godot.app" / "Contents" / "MacOS" / "Godot"


def user_dir() -> Path:
    """Godot's user:// for this project (macOS, Windows, Linux)."""
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^config/name="(.*)"', text, re.M)
    name = match.group(1) if match else "ZenScape"
    if sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata"
    elif sys.platform.startswith("win"):
        import os
        base = Path(os.environ.get("APPDATA", Path.home())) / "Godot" / "app_userdata"
    else:
        base = Path.home() / ".local" / "share" / "godot" / "app_userdata"
    return base / name / "flight_runs"


def load(folder: Path) -> tuple[list[dict], list[dict], dict]:
    runs, benches, bands = [], [], {}
    for path in sorted(folder.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            print(f"skipped {path.name}: {error}", file=sys.stderr)
            continue
        if path.name == SIDE:
            continue
        if path.name == "bands.json":
            bands = data
        elif data.get("kind") == "bench":
            benches.append(data)
        elif "station" in data and "metrics" in data:
            data["_file"] = path.name
            runs.append(data)
    # Threading for runs saved before it was measured, from the side file
    # (tools/flight_threading.gd); the run files themselves are never touched.
    side = folder / SIDE
    if side.is_file():
        try:
            filled = json.loads(side.read_text(encoding="utf-8")).get("runs", {})
        except (OSError, json.JSONDecodeError):
            filled = {}
        for run in runs:
            if "threading_share" not in run["metrics"] and run["_file"] in filled:
                run["metrics"].update({k: filled[run["_file"]].get(k) for k in THREAD_KEYS})
                run["_threading_backfilled"] = True
    return runs, benches, bands


def godot_binary() -> str | None:
    import os
    import shutil
    for candidate in (os.environ.get("GODOT_BIN"), str(DEFAULT_GODOT), shutil.which("godot"), shutil.which("Godot")):
        if candidate and Path(candidate).is_file():
            return candidate
    return None


def backfill(folder: Path) -> None:
    """Runs tools/flight_threading.gd headless if some run lacks the threading
    numbers and isn't in the side file yet."""
    runs, _, _ = load(folder)
    missing = [r for r in runs if "threading_share" not in r["metrics"]]
    if not missing:
        return
    godot = godot_binary()
    if not godot:
        print(f"{len(missing)} run(s) have no threading numbers and Godot wasn't found (set GODOT_BIN)", file=sys.stderr)
        return
    subprocess.run([godot, "--headless", "--path", str(ROOT), "-s", "tools/flight_threading.gd", "--", "--dir", str(folder)],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def num(value, digits=2) -> str:
    if value is None or value == "":
        return "-"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, (int, float)):
        return f"{value:.{digits}f}" if isinstance(value, float) else str(value)
    return str(value)


def mean(values):
    values = [v for v in values if isinstance(v, (int, float)) and not isinstance(v, bool)]
    return sum(values) / len(values) if values else None


def is_bot(run: dict) -> bool:
    return str(run.get("pilot", "")).startswith("bot:")


def skill_of(run: dict) -> str:
    return str(run.get("pilot", "")).split(":", 1)[-1]


def strip_chart(reference: dict | None, people: list[dict], width=760, height=150) -> str:
    """An SVG of each run's demand curve over time; the reference dashed."""
    curves = []
    if reference:
        curves.append(("perfect bot", reference["metrics"].get("curve", []), "#888", "5,4"))
    palette = ["#d9534f", "#2a7ab9", "#5cb85c", "#f0ad4e", "#8e5ea2", "#3cbac8", "#c45850"]
    for i, run in enumerate(people):
        label = run.get("started", "")[:16]
        curves.append((label, run["metrics"].get("curve", []), palette[i % len(palette)], ""))
    span = max([c[-1][0] for _, c, _, _ in curves if c] + [8.0])
    pad = 30
    plot_w, plot_h = width - pad - 10, height - 30
    parts = [f'<svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg" style="background:#fafaf7;border:1px solid #ddd">']
    for level in (0.35, 0.55, 0.75):
        y = 10 + plot_h * (1 - level / 1.2)
        parts.append(f'<line x1="{pad}" y1="{y:.1f}" x2="{width-10}" y2="{y:.1f}" stroke="#e4e4e0"/>')
        parts.append(f'<text x="2" y="{y+4:.1f}" font-size="10" fill="#999">{level:.2f}</text>')
    for second in range(0, int(span) + 1, 2):
        x = pad + plot_w * second / span
        parts.append(f'<text x="{x:.1f}" y="{height-4}" font-size="10" fill="#999">{second}s</text>')
    for label, curve, colour, dash in curves:
        if not curve:
            continue
        points = " ".join(f"{pad + plot_w * p[0] / span:.1f},{10 + plot_h * (1 - min(p[1], 1.2) / 1.2):.1f}" for p in curve)
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        parts.append(f'<polyline points="{points}" fill="none" stroke="{colour}" stroke-width="2"{dash_attr}><title>{html.escape(label)}</title></polyline>')
    parts.append("</svg>")
    return "".join(parts)


def build(folder: Path, out: Path) -> tuple[Path, Path, Path]:
    runs, benches, bands = load(folder)
    groups: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for run in runs:
        groups[(run["station"], run.get("station_hash", ""))].append(run)
    benches.sort(key=lambda b: b.get("when", ""))
    order = {}
    for run in runs:
        order.setdefault(run["station"], len(order))

    md = ["# Flight study report", "", f"From {len(runs)} runs in `{folder}`.", ""]
    fun_rows: list[dict] = []
    body = []
    overview = []
    csv_rows = []
    for (station, digest), group in sorted(groups.items(), key=lambda kv: (order.get(kv[0][0], 99), kv[0][1])):
        name = group[0].get("station_name", station)
        intent = group[0].get("intent", "")
        band_info = bands.get(station, {})
        band = band_info.get("band") if band_info.get("hash") == digest else None
        bench_row = None
        for bench in reversed(benches):
            row = bench.get("stations", {}).get(station)
            if row and row.get("hash") == digest:
                bench_row = row
                break
        if bench_row and not band:
            band = bench_row.get("band")
        bots = [r for r in group if is_bot(r)]
        people = sorted([r for r in group if not is_bot(r)], key=lambda r: r.get("started", ""))
        perfect = [r for r in bots if skill_of(r) == "perfect"]
        reference = None
        if perfect:
            reference = max(perfect, key=lambda r: (r["metrics"]["collected"], -r["metrics"]["bumps"], -r["metrics"]["duration"]))
        ref = reference["metrics"] if reference else {}
        ratings_d = [r.get("rating", {}).get("difficulty") for r in people]
        ratings_f = [r.get("rating", {}).get("fun") for r in people]
        overview.append([name, station, digest, intent, band or "-", num(ref.get("duration")), num(ref.get("demand_peak")),
                         num(ref.get("demand_mean")), num(ref.get("demand_spike")), num(ref.get("turn_need_peak")),
                         num(ref.get("warning_min")), num(ref.get("room_min")), str(len(people)),
                         num(mean([r["metrics"]["duration"] for r in people])), num(mean(ratings_d), 1), num(mean(ratings_f), 1),
                         pct(mean([r["metrics"].get("threading_share") for r in people])), num(mean([r["metrics"].get("openings_per_s") for r in people])),
                         pct(ref.get("threading_share"))])
        for r in people:
            rating = r.get("rating", {})
            if rating.get("fun") is not None:
                m = r["metrics"]
                fun_rows.append({"station": station, "name": name, "flown": r.get("started", "")[:19], "threading": m.get("threading_share"),
                                 "openings": m.get("openings_per_s"), "difficulty": rating.get("difficulty"), "fun": rating.get("fun"),
                                 "backfilled": r.get("_threading_backfilled", False)})
        # Bots, per skill, over every bot run of this layout (all sessions).
        bot_rows = []
        versions = sorted({r.get("skill", {}).get("version", 0) for r in bots})
        for version, skill in [(v, s) for v in versions for s in SKILLS]:
            mine = [r for r in bots if skill_of(r) == skill and r.get("skill", {}).get("version", 0) == version]
            if not mine:
                continue
            ms = [r["metrics"] for r in mine]
            bot_rows.append([f"{skill} v{num(version, 0)}", str(len(mine)), num(sum(1 for m in ms if m["cleared"]) / len(ms)), num(mean([m["duration"] for m in ms])),
                             num(mean([m["collected"] for m in ms]), 1), num(mean([m["demand_peak"] for m in ms])), num(mean([m["demand_mean"] for m in ms])),
                             num(mean([m["turn_flown_peak"] for m in ms])), num(mean([m["reversals_per_s"] for m in ms])),
                             num(mean([m["effort"] for m in ms])), num(mean([m["bumps"] for m in ms]), 1),
                             pct(mean([m.get("threading_share") for m in ms])), num(mean([m.get("openings_per_s") for m in ms]))])
        person_rows = []
        for r in people:
            m = r["metrics"]
            rating = r.get("rating", {})
            person_rows.append([r.get("started", "")[:19], num(m["duration"]), f'{m["collected"]}/{m["total"]}', str(m["bumps"]),
                                num(m["demand_peak"]), num(m["demand_mean"]), num(m["demand_spike"]), m.get("grade", ""),
                                num(m["turn_need_peak"]), num(m["turn_flown_peak"]), num(m["warning_min"]), num(m["room_min"]),
                                num(m["reversals_per_s"]), num(m["effort"]), f'{round(m["full_share"] * 100)}%',
                                pct(m.get("threading_share")), num(m.get("openings_per_s")),
                                num(rating.get("difficulty"), 0), num(rating.get("fun"), 0)])
        gap_rows = []
        for g in ref.get("gaps", []):
            gap_rows.append([str(g["token"]), num(g["length"], 1), num(g["turn"]), num(g["pitch"]), num(g["commit"]),
                             num(g.get("warning")), num(g["room"]), num(g["demand"])])
        bot_head = ["skill", "runs", "clear rate", "time s", "tokens", "demand peak", "demand mean", "turn flown", "rev/s", "effort/s", "bumps",
                    "threading", "openings/s"]
        person_head = ["flown", "time s", "tokens", "bumps", "demand peak", "mean", "spike", "grade", "turn need", "turn flown",
                       "warning min s", "room min m", "rev/s", "effort/s", "full", "threading", "openings/s", "felt diff", "fun"]
        gap_head = ["token", "length m", "turn", "pitch", "commit s", "warning s", "room m", "demand"]
        md += [f"## {name} (`{station}` {digest})", "", f"Intent **{intent}** · bot band **{band or 'not benched'}**", ""]
        for head, rows, title in ((bot_head, bot_rows, "Bots"), (person_head, person_rows, "People"), (gap_head, gap_rows, "Reference line per gap (perfect bot)")):
            md += [f"**{title}**", ""]
            if rows:
                md += ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
                md += ["| " + " | ".join(row) + " |" for row in rows]
            else:
                md.append("none yet")
            md.append("")
        body.append(f'<h2>{html.escape(name)} <small><code>{station}</code> {digest}</small></h2>')
        body.append(f'<p>Intent <b>{html.escape(intent)}</b> · bot band <b class="band">{html.escape(band or "not benched")}</b></p>')
        body.append(strip_chart(reference, people))
        body.append('<p class="legend">Demand per gap over the run (0 to 1.2; lines at 0.35, 0.55, 0.75 grade easy, medium, hard). Dashed: the perfect bot. Hover a line for its run.</p>')
        for head, rows, title in ((bot_head, bot_rows, "Bots (all sessions)"), (person_head, person_rows, "People"), (gap_head, gap_rows, "Reference line per gap")):
            body.append(f"<h3>{title}</h3>")
            body.append(table(head, rows) if rows else "<p>none yet</p>")
        for r in group:
            row = {"file": r["_file"], "station": station, "station_hash": digest, "intent": intent, "band": band or "",
                   "pilot": r.get("pilot", ""), "started": r.get("started", ""),
                   "rating_difficulty": r.get("rating", {}).get("difficulty", ""), "rating_fun": r.get("rating", {}).get("fun", "")}
            for key in SUMMARY_KEYS:
                row[key] = r["metrics"].get(key, "")
            csv_rows.append(row)

    over_head = ["station", "id", "hash", "intent", "bot band", "ref time s", "ref demand peak", "mean", "spike", "turn need",
                 "warning min s", "room min m", "people runs", "their time s", "felt diff", "fun", "their threading", "their openings/s",
                 "ref threading"]
    fun_head, fun_table, fun_note = threading_vs_fun(fun_rows)
    md[4:4] = (["| " + " | ".join(over_head) + " |", "|" + "---|" * len(over_head)] + ["| " + " | ".join(row) + " |" for row in overview] + [""]
               + ["## Threading vs fun (rated runs)", "", THREAD_RULE, ""]
               + (["| " + " | ".join(fun_head) + " |", "|" + "---|" * len(fun_head)] + ["| " + " | ".join(row) + " |" for row in fun_table] if fun_table else ["none yet"])
               + ["", fun_note, ""])
    out.mkdir(parents=True, exist_ok=True)
    md_path, html_path, csv_path = out / "flight_report.md", out / "flight_report.html", out / "flight_runs.csv"
    md_path.write_text("\n".join(md) + "\n", encoding="utf-8")
    fun_html = (f"<h2>Threading vs fun (rated runs)</h2><p class=\"legend\">{html.escape(THREAD_RULE)}</p>"
                + (table(fun_head, fun_table) if fun_table else "<p>none yet</p>") + f"<p>{html.escape(fun_note)}</p>")
    html_path.write_text(HTML.format(count=len(runs), folder=html.escape(str(folder)), overview=table(over_head, overview) + fun_html, body="\n".join(body)), encoding="utf-8")
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        fields = ["file", "station", "station_hash", "intent", "band", "pilot", "started", "rating_difficulty", "rating_fun"] + SUMMARY_KEYS
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(csv_rows)
    return md_path, html_path, csv_path


THREAD_RULE = ("Threading: a tick threads when a solid lies within 8 m both left and right of the plane (level rays square to its heading) "
               "or within 12 m straight above it; the share is threading ticks over all ticks; an opening is one spell of threading "
               "(spells under 0.2 s apart joined), per second of the run. Backfilled (*) from the recorded ticks for runs saved before it existed.")


def pct(value) -> str:
    if value is None or isinstance(value, bool) or not isinstance(value, (int, float)):
        return "-"
    return f"{round(value * 100)}%"


def pearson(xs, ys):
    pairs = [(x, y) for x, y in zip(xs, ys) if isinstance(x, (int, float)) and isinstance(y, (int, float))]
    if len(pairs) < 3:
        return None
    mx = sum(p[0] for p in pairs) / len(pairs)
    my = sum(p[1] for p in pairs) / len(pairs)
    sx = sum((p[0] - mx) ** 2 for p in pairs) ** 0.5
    sy = sum((p[1] - my) ** 2 for p in pairs) ** 0.5
    if sx == 0 or sy == 0:
        return None
    return sum((p[0] - mx) * (p[1] - my) for p in pairs) / (sx * sy)


def threading_vs_fun(rows: list[dict]):
    """Every rated person's run: its threading next to its ratings, sorted by
    threading, and how well threading tracks fun (Pearson r over the runs)."""
    head = ["station", "flown", "threading", "openings/s", "felt diff", "fun"]
    out = []
    for r in sorted(rows, key=lambda r: (r["threading"] if isinstance(r["threading"], (int, float)) else -1, r["station"])):
        mark = "*" if r["backfilled"] else ""
        out.append([r["station"], r["flown"], pct(r["threading"]) + mark, num(r["openings"]) + mark, num(r["difficulty"], 0), num(r["fun"], 0)])
    r_share = pearson([r["threading"] for r in rows], [r["fun"] for r in rows])
    r_open = pearson([r["openings"] for r in rows], [r["fun"] for r in rows])
    note = (f"{len(rows)} rated runs. Pearson r with fun: threading share {num(r_share)}, openings/s {num(r_open)}"
            " (few runs, one person: a hint, not a finding).")
    return head, out, note


def table(head, rows) -> str:
    out = ["<table><tr>" + "".join(f"<th>{html.escape(h)}</th>" for h in head) + "</tr>"]
    for row in rows:
        out.append("<tr>" + "".join(f"<td>{html.escape(str(c))}</td>" for c in row) + "</tr>")
    out.append("</table>")
    return "".join(out)


HTML = """<!doctype html><html><head><meta charset="utf-8"><title>Flight study report</title>
<style>
body{{font:14px/1.4 -apple-system,Helvetica,Arial,sans-serif;margin:24px;color:#222;max-width:1200px}}
table{{border-collapse:collapse;margin:6px 0 14px}} td,th{{border:1px solid #ddd;padding:3px 7px;text-align:right}}
th{{background:#f1f0eb}} td:first-child,th:first-child{{text-align:left}} h2{{margin-top:36px;border-top:2px solid #333;padding-top:10px}}
small{{color:#888;font-weight:normal}} .band{{text-transform:uppercase}} .legend{{color:#777;font-size:12px}}
</style></head><body>
<h1>Flight study report</h1><p>{count} runs from <code>{folder}</code>.</p>
{overview}
{body}
</body></html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dir", type=Path, default=None, help="the runs folder (default: the project's user://flight_runs)")
    parser.add_argument("--out", type=Path, default=None, help="where the report goes (default: the runs folder)")
    parser.add_argument("--open", action="store_true", help="open the HTML report when done")
    parser.add_argument("--no-backfill", action="store_true", help="don't run tools/flight_threading.gd (headless Godot) for runs without threading numbers")
    args = parser.parse_args()
    folder = args.dir or user_dir()
    if not folder.is_dir():
        print(f"no runs folder at {folder}", file=sys.stderr)
        return 1
    if not args.no_backfill:
        backfill(folder)
    md_path, html_path, csv_path = build(folder, args.out or folder)
    print(f"report: {html_path}\n        {md_path}\n        {csv_path}")
    if args.open:
        subprocess.run(["open", str(html_path)], check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
