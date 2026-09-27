#!/usr/bin/env python3
"""Exercise the exported release binary and its native kernel, outside the checkout."""
from pathlib import Path
import platform
import plistlib
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='zenscape-export-check-') as temporary:
    folder = Path(temporary)
    if platform.system() == 'Windows':
        executable = root / 'builds/windows/ZenScape.exe'
        if not list(executable.parent.rglob('*zenscape_kernels*.dll')):
            raise RuntimeError('Windows export is missing the native kernel DLL')
    else:
        subprocess.run(['ditto', '-x', '-k', str(root / 'builds/ZenScape-mac-universal.zip'), str(folder)], check=True)
        bundles = list(folder.rglob('*.app'))
        if len(bundles) != 1:
            raise RuntimeError(f'Expected one exported app, found {bundles}')
        contents = bundles[0] / 'Contents'
        with (contents / 'Info.plist').open('rb') as info:
            executable = contents / 'MacOS' / plistlib.load(info)['CFBundleExecutable']
        packs = list((contents / 'Resources').glob('*.pck'))
        if len(packs) != 1:
            raise RuntimeError(f'Expected one exported pack, found {packs}')
        libraries = list(folder.rglob('*zenscape_kernels*.dylib'))
        if not libraries:
            raise RuntimeError('Mac export is missing the native kernel dylib')
        for library in libraries:
            subprocess.run(['lipo', str(library), '-verify_arch', 'arm64', 'x86_64'], check=True)
    # Official release templates reject --path, --main-pack and --script.
    # Launch normally and request the in-package check through user arguments.
    log = root / 'builds' / 'packaged-release.log'
    result = subprocess.run([str(executable), '--headless', '--log-file', str(log),
                             '--', '--native-kernels', '--verify-desktop-build'],
                            cwd=folder, timeout=240,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = result.stdout.decode(errors='replace')
    if log.exists():
        output += log.read_text(errors='replace')
    print(output, flush=True)
    if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
        raise RuntimeError(f'Packaged self-check failed (exit {result.returncode})')
    for marker in ['PASS: packaged native terrain kernel loaded',
                   'PASS: packaged native mesh equivalence',
                   'PASS: packaged creation shell, Look, Craft and main menu']:
        if marker not in output:
            raise RuntimeError(f'Packaged self-check did not finish: {marker}')
