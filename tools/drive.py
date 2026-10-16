#!/usr/bin/env python3
"""Runs a driver (a script extending tools/harness/drive.gd), headless, and
prints what it reported: its check lines, ROW and RESULT lines, the errors,
and a summary. The rest of the log goes to --log or is dropped.

  python tools/drive.py scratch/gap_check.gd
  python tools/drive.py scratch/gap_check.gd -- --seed=2 --scene-args --shape=ring
  python tools/drive.py scratch/gap_check.gd --all       # the whole log
  python tools/drive.py scratch/gap_check.gd --rendered  # a window, for shot()
  python tools/drive.py --api [WORD]   # the helpers a driver has (no Godot run)

A script that doesn't parse fails in a second with its error (and a hint for
the untyped `:=` warning the project treats as an error). Exit: the driver's
(0 all checks passed, 1 a check failed, 2 its timeout), or 1 on errors.
Throwaway drivers go in scratch/ (git-ignored, Godot doesn't scan it).
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402


def res_path(script: str) -> str:
    s = script.replace("\\", "/")
    if s.startswith("res://"):
        return s
    p = Path(s).resolve()
    try:
        return "res://" + p.relative_to(godot.ROOT).as_posix()
    except ValueError:
        return p.as_posix()  # outside the project: by its own path


# --- --api: the helpers, read from the harness scripts themselves ------------

HARNESS = Path(__file__).resolve().parent / "harness"
API_FILES = ["drive.gd", "chain.gd", "stations.gd"]
INDEX_BEGIN = "## Index (`python tools/drive.py --api [word]` adds the docs; `--api --update` rewrites it):"
INDEX_END = "## (end of index)"
_SECTION = re.compile(r"^# -+ (.+?) -*$")
_FUNC = re.compile(r"^(?:static )?func ([A-Za-z]\w*)\((.*)\)\s*(?:->\s*(.+?))?\s*:\s*$")
_FIELD = re.compile(r"^(?:var|const) ([A-Za-z]\w*)\s*(:\s*[^=]+?)?\s*(:?=)\s*(.*)$")


def api_items(path: Path) -> tuple[str, list[dict]]:
    """The file's `##` header, and its public funcs (and documented fields),
    each {group, name, sig, short, doc, notes}: `group` is its `# --- X ---`
    section, `notes` that section's `#` comment block."""
    lines = path.read_text(encoding="utf-8").splitlines()
    header: list[str] = []
    for line in lines[1:]:
        if not line.startswith("##"):
            break
        header.append(line)
    items: list[dict] = []
    group, notes, doc = "The driver", [], []
    in_notes = False
    for line in lines[1 + len(header):]:
        m = _SECTION.match(line)
        if m:
            group, notes, doc, in_notes = m.group(1), [], [], True
            continue
        if in_notes and line.startswith("#") and not line.startswith("##"):
            notes.append(line[1:].removeprefix(" ") if line != "#" else "")
            continue
        if line.strip():
            in_notes = False
        if line.startswith("##"):
            doc.append(line[2:].strip())
            continue
        f, v = _FUNC.match(line), _FIELD.match(line)
        if f and not f.group(1).startswith("_"):
            ret = f" -> {f.group(3)}" if f.group(3) else ""
            short = re.sub(r"\s*:\s*[^,=]+?(\s*:?=|,|$)", lambda x: x.group(1).replace(":=", "=").replace(" =", " ="), f.group(2))
            short = re.sub(r"\s*:?=\s*", " = ", short)
            items.append({"group": group, "name": f.group(1), "sig": f"{f.group(1)}({f.group(2)}){ret}",
                          "short": f"{f.group(1)}({short}){ret}", "doc": " ".join(doc), "notes": notes})
        elif v and not v.group(1).startswith("_") and doc:
            typ = (v.group(2) or "").replace(" ", "").replace(":", ": ")
            val = v.group(4)
            short_val = val if len(val) <= 24 and not val.endswith(("{", "[", "(")) else "..."
            sig = f"{v.group(1)}{typ}" if typ else f"{v.group(1)} := {short_val}"
            items.append({"group": group, "name": v.group(1), "sig": sig, "short": sig, "doc": " ".join(doc),
                          "notes": notes, "field": True})
        if not line.startswith("#"):
            doc = []
    return "\n".join(header), items


def api_index(items: list[dict]) -> list[str]:
    """drive.gd's header index: a line per helper, grouped by section."""
    out, group = [INDEX_BEGIN], None
    for it in items:
        if it.get("field"):
            continue
        if it["group"] != group:
            group = it["group"]
            out.append(f"##   {group}")
        out.append(f"##     {it['short']}")
    return out + [INDEX_END]


def api_stale(path: Path, header: str, items: list[dict]) -> str:
    """Why the file's header index is out of date with its code ("" if not)."""
    if path.name == "drive.gd":
        lines = path.read_text(encoding="utf-8").splitlines()
        if INDEX_BEGIN not in lines or INDEX_END not in lines:
            return f"it has no index (the lines {INDEX_BEGIN!r} .. {INDEX_END!r})"
        a, b = lines.index(INDEX_BEGIN), lines.index(INDEX_END)
        return "" if lines[a:b + 1] == api_index(items) else "its index differs from the code; run `python tools/drive.py --api --update`"
    if path.name == "chain.gd":
        missing = [it["name"] for it in items if not it.get("field") and not re.search(rf"\b{it['name']}\b", header)]
        return f"its header doesn't name {', '.join(missing)}; add them there" if missing else ""
    return ""


def api_update(path: Path, items: list[dict]) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    a, b = lines.index(INDEX_BEGIN), lines.index(INDEX_END)
    lines[a:b + 1] = api_index(items)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def api(argv: list[str]) -> int:
    """`--api [WORD] [--update]`: every helper's signature and first doc
    sentence, read from the scripts; WORD keeps the helpers or sections whose
    name has it, with their whole docs and each section's notes (opts, what
    it returns). Exits 1 if a header index is out of date with the code."""
    update = "--update" in argv
    words = [a.lower() for a in argv if not a.startswith("--")]
    stale = []
    for name in API_FILES:
        path = HARNESS / name
        header, items = api_items(path)
        if update and path.name == "drive.gd":
            api_update(path, items)
            print(f"== wrote the index in {path.relative_to(godot.ROOT).as_posix()}")
        why = api_stale(path, header, items)
        if why:
            stale.append(f"{name}: {why}")
        if words:
            items = [it for it in items if any(w in it["name"].lower() or w in it["group"].lower() for w in words)]
            if not items:
                continue
        first_doc = header.splitlines()[0][2:].strip() if header else ""
        print(f"\n## tools/harness/{name}: {first_doc}")
        if name == "stations.gd":
            print("\n".join("   " + l[2:] for l in header.splitlines()[1:]))
            continue
        group = None
        for it in items:
            if it["group"] != group:
                group = it["group"]
                print(f"\n  {group}")
                if words and it["notes"]:
                    print("\n".join(f"    | {n}".rstrip() for n in it["notes"]))
            print(f"    {it['sig']}")
            if it["doc"]:
                # The first sentence; a WORD gets the whole doc.
                doc = it["doc"] if words else re.split(r"(?<!e\.g\.)(?<=\.)\s+(?=[A-Z`])", it["doc"])[0]
                print(f"        {doc}")
    if not words:
        print("\n`--api WORD` (route, watch, ray, open...): those helpers' whole docs and their section's notes (opts, what it returns).")
    for s in stale:
        print(f"== stale header: {s}")
    return 1 if stale else 0


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argv = sys.argv[1:]
    if "--api" in argv[:1] or ("--api" in argv and "--" not in argv[:argv.index("--api")]):
        return api([a for a in argv if a != "--api"])
    driver_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, driver_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("script")
    p.add_argument("--timeout", type=int, default=240, help="wall-clock seconds")
    p.add_argument("--rendered", action="store_true", help="a window (shots); one at a time")
    p.add_argument("--all", action="store_true", help="print the whole log (noise dropped)")
    p.add_argument("--log", help="write the full log here")
    p.add_argument("--no-fixed-fps", action="store_true", help="real time, not --fixed-fps 60")
    args = p.parse_args(argv)
    script = res_path(args.script)
    why = godot.import_needed()
    if why:
        print(f"== import needed: {why}", flush=True)
        godot.run_import(godot.find_godot())
    run_args = ["-s", script]
    if not args.no_fixed_fps:
        run_args += ["--fixed-fps", "60"]
    if args.rendered:
        run_args += ["--rendering-method", "forward_plus", "--windowed", "--resolution", "1440x900"]
    run_args += ["--", f"--timeout={args.timeout}", *driver_args]
    if args.rendered:
        import shot  # its window lock: one window at a time
        shot.window_lock()
    try:
        r = godot.run(run_args, rendered=args.rendered, timeout=args.timeout + 30, check_import=False)
    finally:
        if args.rendered:
            shot.LOCK.unlink(missing_ok=True)
    if args.log:
        Path(args.log).parent.mkdir(parents=True, exist_ok=True)
        Path(args.log).write_text(r["output"], encoding="utf-8")
    shown, dropped = godot.filtered(r["output"], only=not args.all)
    print("\n".join(shown))
    if "inferred from a Variant value" in r["output"] or "Cannot infer the type" in r["output"]:
        print("== hint: type it: `var x: T = ...` (or `var x: Variant = ...`), not `var x := ...`")
    print(godot.summary(r, dropped))
    return godot.status(r)


if __name__ == "__main__":
    raise SystemExit(main())
