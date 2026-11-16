#!/usr/bin/env python3
"""A skin's sheet: the hero plane wearing it, frozen in flight over the
endless land, from a few angles by day and (when it glows) by night, in one
image to look at (Read the PNG) and judge.

  python tools/skin_sheet.py paint/moonstone                   # captures/skins/paint_moonstone.png
  python tools/skin_sheet.py paint/harbour paint/night --night # night row too, though no glow
  python tools/skin_sheet.py sheen:satin sheen:gloss sheen:matte sheen:metal --no-night
  python tools/skin_sheet.py sheen:metal@paint/ochre --views port,chase

A skin is a ShopStock id (any batch), or sheen:NAME[@id]: that skin's
livery (Harbour's by default) in the sheen alone, to compare finishes, or
glow:HEX[*POWER][@id]: that livery with trim and body glowing (power 1);
when the skin has a decal, the decal lit in its own colours instead.
Each skin's sheet is a row of views by day, then the same by night; with
several skins, --out (captures/skins/sheet.png) stacks their rows in the
order given. Views (plane's own frame): port, starboard, quarter (ahead,
above), top, tail, chase (about where the play camera sits: flying
distance). Default port,quarter,top,chase.

Two windows, one after the other (day, then night): Forward+, short, a
watchdog, `--no-title` (tools/harness/skin_sheet.gd; the window lock is
shot.py's). --day-hour / --night-hour pick the hours (11 and 1).
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402
import shot  # noqa: E402

DRIVER = "res://tools/harness/skin_sheet.gd"
RAW = "captures/skins/raw"


def safe(skin: str) -> str:
    return skin.replace("/", "_").replace(":", "_").replace("@", "_").replace("*", "x")


def shoot(skins: list[str], tag: str, hour: float, views: str, timeout: int, size: str = "720x450") -> tuple[int, dict[str, bool]]:
    """One window at `hour`: every skin's views to RAW. Its status, and each
    skin's glow (from the SKIN lines)."""
    args = ["-s", DRIVER, "--fixed-fps", "60", "--rendering-method", "forward_plus",
            "--windowed", "--resolution", "1440x900", "--",
            f"--timeout={timeout}", f"--skins={','.join(skins)}", f"--tag={tag}",
            f"--dir={RAW}", f"--views={views}", f"--size={size}", "--scene-args", "--no-title", f"--hour={hour:g}"]
    print(f"== {tag}: --hour={hour:g}, {len(skins)} skin(s)", flush=True)
    shot.window_lock()
    try:
        r = godot.run(args, rendered=True, timeout=timeout + 30, check_import=False)
    finally:
        shot.LOCK.unlink(missing_ok=True)
    glow = {m.group(1): m.group(2) == "1" for m in re.finditer(r"^SKIN (\S+) glow=(\d)", r["output"], re.M)}
    light = re.search(r"^LIGHT .*$", r["output"], re.M)
    shown, dropped = godot.filtered(r["output"], only=True)
    print("\n".join([light.group(0)] if light else []) + ("\n" if light else "") + "\n".join(shown))
    print(godot.summary(r, dropped))
    return godot.status(r), glow


def sheet(files: list[Path], out: str, cols: int) -> int:
    r = godot.run(["-s", "res://tools/harness/sheet.gd", "--",
                   "--in=" + ",".join(str(f.resolve()) for f in files), f"--out={out}",
                   f"--cols={cols}", "--width=480"], check_import=False)
    shown, _ = godot.filtered(r["output"], only=True)
    print("\n".join(shown))
    return godot.status(r)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("skins", nargs="+")
    night = p.add_mutually_exclusive_group()
    night.add_argument("--night", action="store_true", help="a night row for every skin")
    night.add_argument("--no-night", action="store_true", help="no night row, even for a glow")
    p.add_argument("--views", default="port,quarter,top,chase")
    p.add_argument("--day-hour", type=float, default=11.0)
    p.add_argument("--night-hour", type=float, default=1.0)
    p.add_argument("--out", default="captures/skins/sheet.png", help="the stacked sheet (several skins)")
    p.add_argument("--timeout", type=int, default=240)
    p.add_argument("--size", default="720x450", help="a still's size (the window is 1440x900)")
    args = p.parse_args()
    views = [v for v in args.views.split(",") if v]
    why = godot.import_needed()
    if why:
        print(f"== import needed: {why}", flush=True)
        godot.run_import(godot.find_godot())
    root = godot.ROOT
    for s in args.skins:  # no stale still stands in for one that failed
        for f in (root / RAW).glob(f"{safe(s)}_*.png"):
            f.unlink()
    worst, glow = shoot(args.skins, "day", args.day_hour, ",".join(views), args.timeout, args.size)
    at_night = [] if args.no_night else [s for s in args.skins if args.night or glow.get(s)]
    if at_night:
        code, _ = shoot(at_night, "night", args.night_hour, ",".join(views), args.timeout, args.size)
        worst = worst or code
    stacked: list[Path] = []
    for s in args.skins:
        rows = ["day"] + (["night"] if s in at_night else [])
        files = [root / RAW / f"{safe(s)}_{tag}_{v}.png" for tag in rows for v in views]
        missing = [f for f in files if not f.is_file()]
        if missing:
            print(f"FAIL {s}: missing {', '.join(f.name for f in missing)}")
            worst = worst or 1
            continue
        out = f"captures/skins/{safe(s)}.png"
        code = sheet(files, out, len(views))
        worst = worst or code
        print(f"SHEET {s}: {out} (rows {', '.join(rows)}; views {', '.join(views)})")
        stacked += files
    if len(args.skins) > 1 and stacked:
        code = sheet(stacked, args.out, len(views))
        worst = worst or code
        print(f"SHEET all: {args.out} (rows in the order given)")
    return worst


if __name__ == "__main__":
    raise SystemExit(main())
