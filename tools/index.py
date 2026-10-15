#!/usr/bin/env python3
"""The tools in tools/, each with the first line of its header and its usage
line, filtered by words (all must match the name or the header).

  python tools/index.py                 # all of them
  python tools/index.py capture sky     # tools whose name or header has both
  python tools/index.py --full rope     # the whole header
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

TOOLS = Path(__file__).resolve().parent


def header(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()[:60]
    out: list[str] = []
    if path.suffix == ".py":
        text = "\n".join(lines)
        m = re.search(r'"""(.*?)"""', text, re.S)
        return [l.strip() for l in m.group(1).splitlines()] if m else []
    for line in lines:
        s = line.strip()
        if s.startswith(("##", "//", "#")) and not s.startswith("#!"):
            out.append(s.lstrip("#/ ").rstrip())
        elif out and not s.startswith(("extends", "class_name", "@tool")):
            break
    return out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = sys.argv[1:]
    full = "--full" in args
    words = [a.lower() for a in args if a != "--full"]
    files = sorted(p for p in TOOLS.rglob("*") if p.suffix in (".gd", ".py", ".mjs", ".sh")
                   and "__pycache__" not in p.parts and p.is_file())
    shown = 0
    for p in files:
        h = header(p)
        hay = (p.name + " " + " ".join(h)).lower()
        if not all(w in hay for w in words):
            continue
        shown += 1
        rel = p.relative_to(TOOLS.parent).as_posix()
        if full:
            print(f"== {rel}\n" + "\n".join("   " + l for l in h) + "\n")
            continue
        first = next((l for l in h if l), "")
        usage = next((l for l in h if re.search(r"(godot|python|node|\.command)\b.*(--|-s |tools/)", l, re.I)), "")
        print(f"{rel:48} {first[:100]}")
        if usage and words:
            print(f"{'':48}   {usage[:120]}")
    print(f"== {shown} tools")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
