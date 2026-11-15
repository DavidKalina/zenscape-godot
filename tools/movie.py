#!/usr/bin/env python3
"""Film a taped flight: a replay drawn by Godot's Movie Maker, frame by frame.

Tape a flight by flying it (it writes scratch/flights/<date>.flight):

    python tools/play.py -- --record

Then, from that tape, as often as you like and from any camera:

    python tools/movie.py --list                       # the tapes and their takes
    python tools/movie.py last --preview               # watch it in a window, no film
    python tools/movie.py last --from 12 --to 20       # the eye as flown, 1920x1080 at 60
    python tools/movie.py last --from 12 --to 20 --cam flyby,dist=20 --size 2560x1440
    python tools/movie.py scratch/flights/a.flight --cam orbit --speed 0.5 -- --no-clouds

The film is a JPEG per frame (`--quality`, 0.95) and a WAV of the sound, in
captures/movie/<name>/ (an editor opens them as one clip), and an .mp4 beside
them when ffmpeg is on the PATH. `--lossless` writes PNGs instead, at about
half a second a frame. Every frame is drawn in full however long it takes, so
the film never drops one. The frames before the take starts (the land
standing, the eye settling) are cut off, and the sound with them. The window
is borderless, so the size can pass the screen's (3840x2160 on a 1440p
screen); if a window ever stops short of it, the tool says so.

The game is launched on the tape's own seed, world, weight and flags, on the
Full preset unless `--preset` says otherwise, with no title, no HUD and no
book. Flags after `--` go to the game (`--hour=17`, `--no-clouds`, a look to
try). The cameras and their knobs: scripts/endless/flight_replay.gd (CAMS).
One window at a time (the harness's lock). A long film: run it under
tools/bg.py.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import struct
import subprocess
import sys
import threading
import time
from pathlib import Path

import godot

ROOT = godot.ROOT
FLIGHTS = ROOT / "scratch" / "flights"
OUT = ROOT / "captures" / "movie"
# Flags of the taped launch a replay must not carry over: where it started
# (the replay starts on the tape), the logs, and what it sets itself.
# Movie Maker films at the project's own window size, whatever --resolution
# says, and scales every frame to it: the film's size goes in an override.cfg
# (Godot reads it over project.godot at launch) that is taken away again as
# soon as the first frame is written.
OVERRIDE = ROOT / "override.cfg"
MARK = "; written by tools/movie.py for one launch; safe to delete"
DROP = ("--record", "--replay", "--frame-log", "--stream-log", "--line-log", "--ground-tally", "--at=", "--alt=",
        "--heading=", "--seed=", "--world=", "--weight=", "--no-title", "--uncapped", "--max-fps=", "--numbers",
        "--pilot", "--fresh", "--open-settings")


def takes(path: Path) -> list[dict]:
    """The takes in a tape: [{head, frames, seconds}] (scripts/endless/flight_tape.gd)."""
    data = path.read_bytes()
    if data[:4] != b"ZFT1":
        raise SystemExit(f"{path}: not a flight tape")
    out: list[dict] = []
    i = 4
    while i + 5 <= len(data):
        kind, n = data[i], struct.unpack_from("<I", data, i + 1)[0]
        i += 5
        if i + n > len(data):
            break
        if kind == 1:
            out.append({"head": json.loads(data[i:i + n].decode("utf-8")), "frames": 0, "seconds": 0.0})
        elif kind == 2 and out:
            if out[-1]["frames"]:
                out[-1]["seconds"] += struct.unpack_from("<f", data, i)[0]
            out[-1]["frames"] += 1
        i += n
    return out


def tapes() -> list[Path]:
    return sorted(FLIGHTS.glob("*.flight"), key=lambda p: p.stat().st_mtime) if FLIGHTS.is_dir() else []


def show(path: Path) -> None:
    print(path.relative_to(ROOT) if path.is_relative_to(ROOT) else path)
    for n, t in enumerate(takes(path), 1):
        h = t["head"]
        print(f"  take {n}: {t['seconds']:7.1f} s, {t['frames']} frames, seed {h.get('seed')}, world {h.get('world')}, "
              f"weight {h.get('weight')}, flown {h.get('at', '?')}")


def trim(folder: Path, stem: str, first: int, last: int, fps: int) -> tuple[int, str]:
    """Keeps the film's frames `first`..`last` (process frames), numbered from 1,
    and the sound over them. Returns the frames kept and a note on the sound."""
    frames = sorted(folder.glob(f"{stem}[0-9]*.png"))
    if not frames:
        return 0, "no frames written"
    # Movie Maker writes one frame per process frame, from the engine's first.
    base = int(re.search(r"(\d+)\.png$", frames[0].name).group(1))
    kept = 0
    for f in frames:
        at = int(re.search(r"(\d+)\.png$", f.name).group(1)) - base
        if at < first or at > last:
            f.unlink()
            continue
        kept += 1
        f.rename(folder / f"frame{kept:06d}.png")
    wav = folder / f"{stem}.wav"
    if not wav.is_file():
        return kept, "no sound written"
    data = wav.read_bytes()
    fmt, at = data.find(b"fmt "), data.find(b"data")
    if fmt < 0 or at < 0:
        return kept, "sound left whole (not a plain WAV)"
    rate, = struct.unpack_from("<I", data, fmt + 12)
    block, = struct.unpack_from("<H", data, fmt + 20)
    body = data[at + 8:]
    a = min(len(body), int(round(first * rate / fps)) * block)
    b = min(len(body), int(round((last + 1) * rate / fps)) * block)
    cut = body[a:b]
    head = bytearray(data[:at + 8])
    struct.pack_into("<I", head, at + 4, len(cut))
    struct.pack_into("<I", head, 4, len(head) - 8 + len(cut))
    (folder / "sound.wav").write_bytes(bytes(head) + cut)
    wav.unlink()
    return kept, f"sound.wav {len(cut) / block / rate:.2f} s at {rate} Hz"


def cut_avi(folder: Path, first: int, last: int, fps: int) -> tuple[int, str]:
    """Movie Maker's raw.avi (a JPEG and a block of sound per process frame)
    unpacked: frames `first`..`last` as frame000001.jpg on, and their sound.
    Returns the frames kept and a note on the sound."""
    avi = folder / "raw.avi"
    if not avi.is_file():
        return 0, "no film written"
    kept, at, sound, wave = 0, 0, bytearray(), b""
    with avi.open("rb") as f:
        end = avi.stat().st_size

        def walk(pos: int, stop: int) -> None:
            nonlocal kept, at, wave
            while pos + 8 <= stop:
                f.seek(pos)
                name, size = f.read(4), struct.unpack("<I", f.read(4))[0]
                if name == b"LIST":
                    kind = f.read(4)
                    # An unfinished list (size never written back) runs to the end.
                    walk(pos + 12, pos + 8 + size if size else stop)
                    if kind == b"movi" and not size:
                        return
                elif name == b"strf" and size in (16, 18) and not wave:
                    wave = f.read(16)
                elif name in (b"00db", b"00dc"):
                    if first <= at <= last:
                        kept += 1
                        (folder / f"frame{kept:06d}.jpg").write_bytes(f.read(size))
                    at += 1
                elif name == b"01wb" and first <= at - 1 <= last:
                    sound.extend(f.read(size))
                pos += 8 + size + (size & 1)

        walk(12, end)
    avi.unlink()
    if not wave or not sound:
        return kept, "no sound written"
    rate, = struct.unpack_from("<I", wave, 4)
    block, = struct.unpack_from("<H", wave, 12)
    head = b"RIFF" + struct.pack("<I", 36 + len(sound)) + b"WAVEfmt " + struct.pack("<I", 16) + wave + b"data" + struct.pack("<I", len(sound))
    (folder / "sound.wav").write_bytes(head + bytes(sound))
    return kept, f"sound.wav {len(sound) / block / rate:.2f} s at {rate} Hz"


def size_override(size: str, folder: Path, quality: float) -> None:
    """Writes the override.cfg that gives the film its size and its JPEGs their
    quality, and takes it away once the game is up (its first frame written),
    or after a minute."""
    if OVERRIDE.is_file() and MARK not in OVERRIDE.read_text(encoding="utf-8", errors="replace"):
        raise SystemExit(f"{OVERRIDE} is not this tool's: move it away to film at {size}")
    w, h = size.lower().split("x")
    lines = [MARK, "[display]", "", f"window/size/viewport_width={int(w)}", f"window/size/viewport_height={int(h)}",
             "window/size/mode=0", "window/size/borderless=true", "", "[editor]", "", f"movie_writer/video_quality={quality}", ""]
    OVERRIDE.write_text("\n".join(lines), encoding="utf-8")

    def lift() -> None:
        until = time.time() + 60
        while time.time() < until and not any(folder.glob("raw*")):
            time.sleep(0.25)
        OVERRIDE.unlink(missing_ok=True)

    threading.Thread(target=lift, daemon=True).start()


def jpg_size(path: Path) -> str:
    data = path.read_bytes()
    i = 2
    while i + 9 < len(data) and data[i] == 0xFF:
        if data[i + 1] in (0xC0, 0xC1, 0xC2):
            h, w = struct.unpack_from(">HH", data, i + 5)
            return f"{w}x{h}"
        i += 2 + struct.unpack_from(">H", data, i + 2)[0]
    return "?"


def png_size(path: Path) -> str:
    w, h = struct.unpack_from(">II", path.read_bytes()[:24], 16)
    return f"{w}x{h}"


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argv = sys.argv[1:]
    scene_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, scene_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("tape", nargs="?", help="a .flight file, or `last` for the newest in scratch/flights")
    p.add_argument("--list", action="store_true", help="the tapes in scratch/flights and their takes")
    p.add_argument("--take", type=int, default=1)
    p.add_argument("--from", dest="start", type=float, default=0.0, help="seconds into the take")
    p.add_argument("--to", dest="end", type=float, help="seconds into the take (its end)")
    p.add_argument("--cam", default="flown", help="flown, chase, orbit, side, front, top, flyby; knobs after commas")
    p.add_argument("--size", default="1920x1080")
    p.add_argument("--fps", type=int, default=60)
    p.add_argument("--speed", type=float, default=1.0, help="slow motion: 0.5 is half speed")
    p.add_argument("--settle", type=float, default=2.0, help="seconds held on the first frame before filming")
    p.add_argument("--pace", type=float, default=1.0, help="frames take at least 1/PACE of real time (0: no wait)")
    p.add_argument("--preset", default="full", help="the graphics preset (performance, quality, full)")
    p.add_argument("--hud", action="store_true", help="keep the HUD")
    p.add_argument("--name", help="the film's folder under captures/movie")
    p.add_argument("--out", help="the film's folder (instead of captures/movie/<name>)")
    p.add_argument("--preview", action="store_true", help="play it in a window in real time; nothing written")
    p.add_argument("--lossless", action="store_true", help="PNG frames, not JPEG: about half a second a frame")
    p.add_argument("--quality", type=float, default=0.95, help="the JPEG frames' quality, 0 to 1")
    p.add_argument("--raw", action="store_true", help="keep the film as written (raw.avi, or raw*.png), uncut")
    p.add_argument("--no-mp4", action="store_true", help="leave the frames and the sound; no ffmpeg")
    p.add_argument("--timeout", type=int, help="wall-clock seconds (a guess from the length)")
    args = p.parse_args(argv)

    if args.list or not args.tape:
        for path in tapes():
            show(path)
        if not tapes():
            print(f"no tapes in {FLIGHTS.relative_to(ROOT)}: fly one with `python tools/play.py -- --record`")
        return 0
    if args.tape == "last":
        if not tapes():
            raise SystemExit(f"no tapes in {FLIGHTS}")
        tape = tapes()[-1]
    else:
        tape = Path(args.tape)
        tape = tape if tape.is_absolute() else (ROOT / tape if (ROOT / tape).is_file() else Path.cwd() / tape)
    if not tape.is_file():
        raise SystemExit(f"{tape}: no such tape")
    all_takes = takes(tape)
    if not 1 <= args.take <= len(all_takes):
        raise SystemExit(f"{tape.name} has {len(all_takes)} take(s)")
    take = all_takes[args.take - 1]
    head = take["head"]
    start = max(0.0, min(args.start, take["seconds"]))
    end = take["seconds"] if args.end is None else max(start, min(args.end, take["seconds"]))
    if end - start < 0.05:
        raise SystemExit(f"nothing to film: take {args.take} is {take['seconds']:.1f} s")

    flags = [a for a in head.get("args", []) if not a.startswith(DROP) and not a.startswith("--preset=")]
    flags += [f"--seed={head.get('seed', 1)}", f"--world={head.get('world', 'doors')}", f"--preset={args.preset}", "--no-title"]
    if head.get("weight"):
        flags.append(f"--weight={head['weight']}")
    flags += [f"--replay={tape.as_posix()}", f"--replay-take={args.take}", f"--replay-from={start:.3f}",
              f"--replay-to={end:.3f}", f"--replay-cam={args.cam}", f"--replay-settle={args.settle}",
              f"--replay-pace={args.pace}", f"--replay-speed={args.speed}"]
    if args.hud:
        flags.append("--replay-hud")
    # The 3D at the window's own resolution, not drawn smaller and scaled up.
    if not any(a.startswith("--render-scale=") for a in scene_args):
        flags.append("--render-scale=1")
    if args.preview:
        flags.append(f"--replay-size={args.size}")
    flags += scene_args

    window = ["--rendering-method", "forward_plus", "--windowed", "--resolution", args.size]
    length = (end - start) / max(args.speed, 0.05)
    if args.preview:
        run_args = [*window, "--", *flags]
        timeout = args.timeout or int(length + args.settle + 120)
        folder = None
    else:
        name = args.name or f"{tape.stem}_t{args.take}_{start:.0f}-{end:.0f}_{args.cam.split(',')[0]}"
        folder = Path(args.out) if args.out else OUT / name
        if folder.is_dir():
            for old in [*folder.glob("*.png"), *folder.glob("*.jpg"), *folder.glob("*.wav"), *folder.glob("*.avi")]:
                old.unlink()
        folder.mkdir(parents=True, exist_ok=True)
        run_args = ["--write-movie", str(folder / ("raw.png" if args.lossless else "raw.avi")), "--fixed-fps", str(args.fps), *window, "--", *flags]
        # A PNG frame can take a second or more to draw and save at a large size.
        timeout = args.timeout or int(180 + (length + args.settle) * args.fps * (1.5 if args.lossless else 0.5))
    why = godot.import_needed()
    if why:
        print(f"== import needed: {why}", flush=True)
        godot.run_import(godot.find_godot())
    import shot  # its window lock: one window at a time
    print(f"== {'preview' if args.preview else 'filming'} {tape.name} take {args.take}, {start:.1f} to {end:.1f} s, "
          f"camera {args.cam}, {args.size}{'' if args.preview else f' at {args.fps} fps'} (up to {timeout} s)", flush=True)
    shot.window_lock()
    try:
        if folder is not None:
            size_override(args.size, folder, args.quality)
        r = godot.run(run_args, rendered=True, timeout=timeout, check_import=False)
    finally:
        shot.LOCK.unlink(missing_ok=True)
        if folder is not None:
            OVERRIDE.unlink(missing_ok=True)
    shown, dropped = godot.filtered(r["output"], only=True)
    print("\n".join(line for line in r["output"].splitlines() if line.startswith("REPLAY")))
    print("\n".join(shown))
    print(godot.summary(r, dropped))
    if args.preview or folder is None:
        return godot.status(r)
    first = re.search(r"^REPLAY first=(\d+)", r["output"], re.M)
    last = re.search(r"^REPLAY last=(\d+) seconds=([\d.]+)", r["output"], re.M)
    if not first or not last:
        print("== the replay did not run to its end: the frames are left as written, uncut")
        return godot.status(r) or 1
    if args.raw:
        print(f"== uncut, the take is process frames {first.group(1)} to {last.group(1)}: {folder}")
        return godot.status(r)
    ext = "png" if args.lossless else "jpg"
    if args.lossless:
        kept, sound = trim(folder, "raw", int(first.group(1)), int(last.group(1)), args.fps)
    else:
        kept, sound = cut_avi(folder, int(first.group(1)), int(last.group(1)), args.fps)
    want = int(last.group(1)) - int(first.group(1)) + 1
    frames = sorted(folder.glob(f"frame*.{ext}"))
    size = (png_size(frames[0]) if args.lossless else jpg_size(frames[0])) if frames else "?"
    print(f"== {kept} frames ({kept / args.fps:.2f} s at {args.fps} fps, {size}), {sound}: {folder}")
    print(f"== drawn and saved in {float(last.group(2)):.0f} s ({float(last.group(2)) / max(kept, 1):.2f} s a frame)")
    if kept != want:
        print(f"== expected {want} frames: the cut may be off by {want - kept}")
    if size != args.size:
        print(f"== the frames are {size}, not {args.size}")
    window = re.search(r"^REPLAY size=(\d+x\d+) screen=(\d+x\d+)", r["output"], re.M)
    if window and window.group(1) != args.size:
        print(f"== the window only reached {window.group(1)} on a {window.group(2)} screen: every frame was drawn at that "
              f"size and scaled to {args.size}. Film at the screen's size or under.")
    ffmpeg = shutil.which("ffmpeg")
    if frames and ffmpeg and not args.no_mp4:
        mp4 = folder.with_suffix(".mp4")
        command = [ffmpeg, "-y", "-loglevel", "error", "-framerate", str(args.fps), "-i", str(folder / f"frame%06d.{ext}")]
        if (folder / "sound.wav").is_file():
            command += ["-i", str(folder / "sound.wav"), "-c:a", "aac", "-b:a", "320k"]
        command += ["-c:v", "libx264", "-crf", "14", "-preset", "slow", "-pix_fmt", "yuv420p", str(mp4)]
        done = subprocess.run(command)
        print(f"== {mp4}" if done.returncode == 0 else f"== ffmpeg failed ({done.returncode}); the frames are in {folder}")
    elif frames and not ffmpeg:
        print("== no ffmpeg on the PATH: no .mp4; open the frames as an image sequence with sound.wav")
    return godot.status(r)


if __name__ == "__main__":
    raise SystemExit(main())
