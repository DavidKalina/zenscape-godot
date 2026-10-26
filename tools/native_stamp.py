#!/usr/bin/env python3
"""Whether the native terrain kernels were built from the C++ that is here.

  python tools/native_stamp.py           # says whether this machine's build is current
  python tools/native_stamp.py --mark    # records this machine's build as current

The built libraries (native/terrain_kernels/bin/) are git-ignored, so a pull
brings new C++ but not a new build, and the game quietly keeps running the
old one. tools/build_native_kernels.py writes a stamp beside each library it
builds (`<library>.sources`: a hash of the C++ sources, line endings
normalised so a Mac build and a Windows checkout agree); `check` compares it
with the sources now. A library with no stamp (built before stamps) is
judged by date: older than the last commit to the C++ is likely stale.
`--mark` stamps the libraries here as built from the sources here, for a
build known to be current. tools/play.py runs `check` before each launch.
"""
from __future__ import annotations
from datetime import datetime
from pathlib import Path
import hashlib
import platform
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "native" / "terrain_kernels"
BIN = PROJECT / "bin"
SOURCES = ["*.h", "*.cpp", "SConstruct", "build_profile.json", "*.gdextension.in"]
LIBRARY = {"Windows": ("windows", (".dll",)), "Darwin": ("macos", (".dylib", ".framework")), "Linux": ("linux", (".so",))}


def source_hash() -> str:
    h = hashlib.sha256()
    files = sorted({p for pattern in SOURCES for p in PROJECT.glob(pattern) if p.is_file()})
    for p in files:
        h.update(p.name.encode())
        h.update(b"\0")
        h.update(p.read_bytes().replace(b"\r\n", b"\n"))
        h.update(b"\0")
    return h.hexdigest()


def libraries(system: str | None = None) -> list[Path]:
    """This machine's built libraries (or `system`'s: windows, macos, linux)."""
    if not BIN.is_dir():
        return []
    name, exts = LIBRARY.get(platform.system(), ("", ()))
    if system is not None:
        name, exts = next(((n, e) for n, e in LIBRARY.values() if n == system), ("", ()))
    return sorted(p for p in BIN.iterdir() if f".{name}." in p.name and p.name.endswith(exts))


def stamp_path(library: Path) -> Path:
    return library.with_name(library.name + ".sources")


def mark(library: Path) -> None:
    stamp_path(library).write_text(source_hash() + "\n", encoding="utf-8")


def _last_source_commit() -> float | None:
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "log", "-1", "--format=%ct", "--", "native/terrain_kernels",
                              ":(exclude)native/terrain_kernels/bin"],
                             capture_output=True, text=True, timeout=20).stdout.strip()
        return float(out) if out else None
    except (OSError, subprocess.SubprocessError, ValueError):
        return None


def check() -> tuple[str, str]:
    """("current" | "stale" | "maybe" | "missing", a line to show)."""
    libs = libraries()
    if not libs:
        return "missing", "no native terrain kernels built here: the game runs the slower GDScript ones (docs/desktop-builds.md)"
    now = source_hash()
    stale = []
    unstamped = []
    for lib in libs:
        s = stamp_path(lib)
        if not s.exists():
            unstamped.append(lib)
        elif s.read_text(encoding="utf-8").strip() != now:
            stale.append(lib)
    if stale:
        return "stale", (f"the native terrain kernels are out of date: the C++ changed since {stale[0].name} was built, "
                         "and the game keeps running the old build. Rebuild with tools/build_native_kernels.py (docs/desktop-builds.md)")
    if unstamped:
        last = _last_source_commit()
        built = min(p.stat().st_mtime for p in unstamped)
        if last is not None and last > built:
            when = datetime.fromtimestamp(last).strftime("%Y-%m-%d %H:%M")
            return "maybe", (f"the native terrain kernels may be out of date: {unstamped[0].name} is older than the last C++ change ({when}). "
                             "Rebuild with tools/build_native_kernels.py, or if this build is current, `python tools/native_stamp.py --mark`")
    return "current", "native terrain kernels current"


def main(argv: list[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv and argv[0] == "--mark":
        libs = libraries()
        if not libs:
            print("no native libraries here to mark")
            return 1
        for lib in libs:
            mark(lib)
            print(f"marked {lib.name} as built from the C++ here")
        return 0
    state, line = check()
    print(line)
    return 0 if state in ("current", "missing") else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
