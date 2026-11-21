#!/usr/bin/env python3
"""Check an exported desktop build from outside the checkout.

Copies the export to a fresh temp folder, checks it holds what it must (one
pack, the native kernel library), then launches the release binary there for a
few hundred frames with a fresh user data folder (so it opens on the title, a
fresh pilot book), and judges the log the way tools/smoke.py does: exit 0 and
no SCRIPT ERROR or ERROR line, bar the exit noise tools/godot.py drops (leak
reports at exit). A kernel library that fails to load logs the engine's
"Can't open GDExtension dynamic library" errors (seen: the app still exits 0),
so a pass means the native kernels loaded; `-- --native-kernels` is passed too,
for the game's own check where it asks for the kernel.

  python3 tools/verify_desktop_export.py                      # the host's build, headless
  python3 tools/verify_desktop_export.py --platform windows   # on a Mac: files only
  python3 tools/verify_desktop_export.py --rendered           # a window, -- --no-title

The Windows build is launched only on Windows; elsewhere its files are checked
and the launch is reported as not run. Exits 1 on any failure.
"""
import argparse
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import tempfile

from godot import NOISE  # the exit noise smoke and the harness drop

root = Path(__file__).resolve().parents[1]
host = 'windows' if platform.system() == 'Windows' else 'macos'
p = argparse.ArgumentParser(description='Check an exported desktop build from outside the checkout.')
p.add_argument('--platform', choices=['windows', 'macos'], default=host)
p.add_argument('--frames', type=int, default=400)
p.add_argument('--rendered', action='store_true', help='open a window (with -- --no-title) instead of --headless')
p.add_argument('--keep', action='store_true', help='keep the temp folder and print its path')
args = p.parse_args()


def size(path: Path) -> str:
    return f'{path.stat().st_size / 1e6:.1f} MB'


def fail(message: str) -> None:
    print(f'FAIL {args.platform}: {message}', flush=True)
    raise SystemExit(1)


folder = Path(tempfile.mkdtemp(prefix='zenscape-export-check-'))
try:
    if args.platform == 'windows':
        source = root / 'builds/windows'
        if not (source / 'ZenScape.exe').exists():
            fail(f'no {source}/ZenScape.exe; export the "Windows" preset first')
        game = folder / 'windows'
        shutil.copytree(source, game)
        executable = game / 'ZenScape.exe'
        if not (game / 'ZenScape.pck').exists():
            fail('ZenScape.pck is missing beside the exe')
        if not list(game.rglob('*zenscape_kernels*release*.dll')):
            fail('the native kernel DLL (release) is missing')
        for item in sorted(game.rglob('*')):
            if item.is_file():
                print(f'  {item.relative_to(game)}  {size(item)}')
    else:
        archive = root / 'builds/ZenScape-mac-universal.zip'
        if not archive.exists():
            fail(f'no {archive}; export the "macOS" preset first')
        subprocess.run(['ditto', '-x', '-k', str(archive), str(folder)], check=True)
        bundles = list(folder.glob('*.app'))
        if len(bundles) != 1:
            fail(f'expected one app, found {bundles}')
        contents = bundles[0] / 'Contents'
        with (contents / 'Info.plist').open('rb') as info:
            executable = contents / 'MacOS' / plistlib.load(info)['CFBundleExecutable']
        packs = list((contents / 'Resources').glob('*.pck'))
        if len(packs) != 1:
            fail(f'expected one pack, found {packs}')
        kernels = list(contents.rglob('*zenscape_kernels*.dylib'))
        if not kernels:
            fail('the native kernel dylib is missing')
        for library in kernels:
            archs = subprocess.run(['lipo', '-archs', str(library)], check=True, capture_output=True, text=True).stdout.split()
            if not {'arm64', 'x86_64'} <= set(archs):
                fail(f'{library.name} is not universal: {archs}')
        print(f'  {bundles[0].name}: {executable.name} {size(executable)}, {packs[0].name} {size(packs[0])}, '
              + ', '.join(f'{k.name} {size(k)}' for k in kernels))
    if args.platform != host:
        print(f'FILES OK {args.platform}: launch not run (needs a {args.platform} host)')
        raise SystemExit(0)

    # A fresh user:// : Godot puts it under HOME on macOS, APPDATA on Windows.
    env = dict(os.environ)
    home = folder / 'home'
    if host == 'macos':
        (home / 'Library' / 'Application Support').mkdir(parents=True)
        env['HOME'] = str(home)
    else:
        home.mkdir()
        env['APPDATA'] = str(home)
    # Release templates reject --path, --main-pack and --script, so the game
    # runs its own main scene; --quit-after ends it after the frame count.
    # --log-file too: the Windows release exe is a GUI program whose stdout
    # may not reach a pipe.
    log = folder / 'game.log'
    command = [str(executable), '--log-file', str(log), '--quit-after', str(args.frames)]
    user = ['--', '--native-kernels']
    if args.rendered:
        command += ['--windowed', '--resolution', '1440x900']
        user.append('--no-title')
    else:
        command.insert(1, '--headless')
    result = subprocess.run(command + user, cwd=folder, env=env, timeout=600,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = result.stdout.decode(errors='replace')
    if log.exists():
        output += '\n--- game.log ---\n' + log.read_text(errors='replace')
    errors = [line for line in output.splitlines()
              if ('SCRIPT ERROR' in line or 'ERROR:' in line) and not NOISE.match(line)]
    dropped = sum(1 for line in output.splitlines() if NOISE.match(line))
    print(output.rstrip(), flush=True)
    written = sorted(f.name for f in home.rglob('app_userdata/*/*') if f.is_file())
    print(f'  exit-noise lines dropped (tools/godot.py NOISE): {dropped}')
    print(f'  fresh user data after the run: {written or "nothing written"}')
    if result.returncode or errors:
        for line in errors[:20]:
            print(f'  {line}')
        fail(f'exit {result.returncode}, {len(errors)} errors')
    mode = 'rendered' if args.rendered else 'headless'
    print(f'PASS {args.platform}: {mode}, {args.frames} frames, native kernels, 0 errors, exit 0, run from {folder}')
finally:
    if args.keep:
        print(f'kept {folder}')
    else:
        shutil.rmtree(folder, ignore_errors=True)
