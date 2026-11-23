#!/usr/bin/env python3
"""Build the Mac download on this Mac and post it beside the Windows one.

CI builds Windows only (macOS runners cost 10x the minutes), so the Mac app is
made here and uploaded by hand to the release the README links to:

  python3 tools/release_mac.py                 # build, check, upload
  python3 tools/release_mac.py --no-upload     # build and check only
  python3 tools/release_mac.py --any-commit    # allow a HEAD that isn't origin/main

Steps: refuse unless HEAD is origin/main (the release says it's main's
build); rebuild the universal native kernels when their stamp is stale
(tools/native_stamp.py; needs a godot-cpp checkout at the pinned revision,
--godot-cpp or ../godot-cpp, and SCons, installed into scratch/scons-venv on
first use); import; export the "macOS" preset; run the export from outside
the checkout (tools/verify_desktop_export.py); package the app with
docs/desktop-builds.md and BUILD.txt as builds/ZenScape-mac-universal.zip;
upload it with `gh release upload --clobber` to the `windows-latest` release
(the one `releases/latest/download/` serves). CI's next push to main replaces
only the Windows zip, so the Mac zip stays until this is run again: rerun
after changes worth shipping to Mac players.
"""
import argparse
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile

import godot
import native_stamp

ROOT = Path(__file__).resolve().parents[1]
TAG = 'windows-latest'
ARCHIVE = ROOT / 'builds' / 'ZenScape-mac-universal.zip'
KERNELS = ROOT / 'native' / 'terrain_kernels' / 'bin'
VENV = ROOT / 'scratch' / 'scons-venv'

p = argparse.ArgumentParser(description='Build the Mac download here and post it beside the Windows one.')
p.add_argument('--godot-cpp', type=Path, default=ROOT.parent / 'godot-cpp', help='godot-cpp checkout at the pinned revision')
p.add_argument('--no-upload', action='store_true', help='build and check only')
p.add_argument('--any-commit', action='store_true', help="allow a HEAD that isn't origin/main")
p.add_argument('--rebuild-kernels', action='store_true', help='rebuild the kernels even when their stamp is current')
args = p.parse_args()


def step(text: str) -> None:
    print(f'== {text}', flush=True)


def fail(text: str) -> None:
    print(f'FAIL: {text}', flush=True)
    raise SystemExit(1)


def git(*a: str) -> str:
    return subprocess.run(['git', '-C', str(ROOT), *a], check=True, capture_output=True, text=True).stdout.strip()


def workflow_value(name: str) -> str:
    text = (ROOT / '.github' / 'workflows' / 'desktop.yml').read_text()
    m = re.search(rf'^\s*{name}:\s*(\S+)', text, re.M)
    if not m:
        fail(f'{name} not found in desktop.yml')
    return m.group(1)


if platform.system() != 'Darwin':
    fail('this builds the Mac app; run it on a Mac')

# 1. The commit: the release is main's build.
sha = git('rev-parse', 'HEAD')
if not args.any_commit:
    git('fetch', '--quiet', 'origin', 'main')
    if sha != git('rev-parse', 'origin/main'):
        fail('HEAD is not origin/main; pull (or push) first, or pass --any-commit')
dirty = git('status', '--porcelain', '--untracked-files=no')
if dirty:
    print(f'   note: uncommitted changes are built in:\n{dirty}')

# 2. Godot and its templates, the version CI pins.
version = workflow_value('GODOT_VERSION')
exe = godot.find_godot()
have = subprocess.run([exe, '--version'], capture_output=True, text=True).stdout.strip()
if not have.startswith(version):
    fail(f'Godot here is {have}; the build pins {version} (set $GODOT)')
templates = Path.home() / 'Library/Application Support/Godot/export_templates' / f'{version}.stable' / 'macos.zip'
if not templates.exists():
    fail(f'no {templates}; install the {version} export templates (Editor > Manage Export Templates)')
step(f'commit {sha[:7]}, Godot {have}')

# 3. Universal native kernels, rebuilt when the C++ moved on.
universal = [KERNELS / f'libzenscape_kernels.macos.template_{t}.universal.dylib' for t in ('debug', 'release')]
now = native_stamp.source_hash()
current = all(lib.exists() and native_stamp.stamp_path(lib).exists()
              and native_stamp.stamp_path(lib).read_text().strip() == now for lib in universal)
if args.rebuild_kernels or not current:
    pin = workflow_value('GODOT_CPP_REVISION')
    cpp = args.godot_cpp.resolve()
    if not (cpp / 'SConstruct').exists():
        fail(f'no godot-cpp at {cpp}; clone godotengine/godot-cpp at {pin} and pass --godot-cpp')
    at = subprocess.run(['git', '-C', str(cpp), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
    if at != pin:
        fail(f'godot-cpp at {cpp} is {at[:12]}; the build pins {pin[:12]}')
    scons = VENV / 'bin' / 'scons'
    if not scons.exists():
        step('installing SCons 4.8.1 into scratch/scons-venv')
        subprocess.run([sys.executable, '-m', 'venv', str(VENV)], check=True)
        subprocess.run([str(VENV / 'bin' / 'pip'), 'install', '--quiet', 'scons==4.8.1'], check=True)
    for target in ('template_debug', 'template_release'):
        step(f'building the native kernels ({target}, universal)')
        subprocess.run([sys.executable, str(ROOT / 'tools' / 'build_native_kernels.py'), '--godot', exe,
                        '--godot-cpp', str(cpp), '--scons', str(scons), '--target', target, '--arch', 'universal'],
                       check=True)
else:
    step('universal native kernels current')
for lib in universal:
    archs = subprocess.run(['lipo', '-archs', str(lib)], check=True, capture_output=True, text=True).stdout.split()
    if not {'arm64', 'x86_64'} <= set(archs):
        fail(f'{lib.name} is not universal: {archs}')

# 4. Import and export.
if godot.run_import(exe):
    fail('import failed')
ARCHIVE.parent.mkdir(exist_ok=True)
ARCHIVE.unlink(missing_ok=True)
step('exporting the macOS preset')
log = ROOT / 'builds' / 'mac-export.log'
with log.open('w') as out:
    subprocess.run([exe, '--headless', '--path', str(ROOT), '--export-release', 'macOS', str(ARCHIVE)],
                   stdout=out, stderr=subprocess.STDOUT)
if subprocess.run([sys.executable, str(ROOT / 'tools' / 'ci_log_check.py'), str(log)]).returncode or not ARCHIVE.exists():
    fail(f'export failed; see {log}')

# 5. The export run from outside the checkout, headless, 400 frames.
step('running the exported app outside the checkout')
if subprocess.run([sys.executable, str(ROOT / 'tools' / 'verify_desktop_export.py'), '--platform', 'macos']).returncode:
    fail('the exported app did not pass')

# 6. Package: the app, the player README and BUILD.txt, flat in the zip like Windows.
folder = Path(tempfile.mkdtemp(prefix='zenscape-mac-'))
try:
    subprocess.run(['ditto', '-x', '-k', str(ARCHIVE), str(folder)], check=True)
    # The bundle is named after the project ("ZenScape — Landscape Sandbox");
    # the folder name isn't signed, so it's renamed to the short one.
    bundles = list(folder.glob('*.app'))
    if len(bundles) != 1:
        fail(f'expected one app in the export, found {bundles}')
    if bundles[0].name != 'ZenScape.app':
        bundles[0].rename(folder / 'ZenScape.app')
    shutil.copy(ROOT / 'docs' / 'desktop-builds.md', folder / 'README.md')
    (folder / 'BUILD.txt').write_text(f'Commit: {sha}\nGodot: {version}\nNative terrain kernel: required and verified\n')
    ARCHIVE.unlink()
    subprocess.run(['ditto', '-c', '-k', '--norsrc', str(folder), str(ARCHIVE)], check=True)
finally:
    shutil.rmtree(folder, ignore_errors=True)
step(f'packaged {ARCHIVE.relative_to(ROOT)} ({ARCHIVE.stat().st_size / 1e6:.0f} MB)')

# 7. Upload beside the Windows zip.
if args.no_upload:
    step('not uploaded (--no-upload)')
    raise SystemExit(0)
step(f'uploading to the {TAG} release')
subprocess.run(['gh', 'release', 'upload', TAG, str(ARCHIVE), '--clobber'], check=True, cwd=ROOT)
repo = subprocess.run(['gh', 'repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner'],
                      check=True, capture_output=True, text=True, cwd=ROOT).stdout.strip()
step(f'posted: https://github.com/{repo}/releases/latest/download/{ARCHIVE.name}')
