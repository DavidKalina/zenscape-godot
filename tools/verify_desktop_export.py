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
        pack = executable.with_suffix('.pck')
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
        pack = packs[0]
        libraries = list(folder.rglob('*zenscape_kernels*.dylib'))
        if not libraries:
            raise RuntimeError('Mac export is missing the native kernel dylib')
        for library in libraries:
            subprocess.run(['lipo', str(library), '-verify_arch', 'arm64', 'x86_64'], check=True)
    for script in ['test_threaded_mesh.gd', 'test_export_entry.gd']:
        # Test scripts are deliberately excluded from exports. All res:// inputs
        # resolve from the shipped pack; the working directory has no project.
        log = root / 'builds' / f'packaged-{script}.log'
        result = subprocess.run([str(executable), '--headless', '--main-pack', str(pack),
                                 '--log-file', str(log), '--script', str(root / 'tests' / script),
                                 '--', '--native-kernels'], cwd=folder, timeout=180,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output = result.stdout.decode(errors='replace')
        if log.exists():
            output += log.read_text(errors='replace')
        print(output, flush=True)
        if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
            raise RuntimeError(f'Packaged {script} failed (exit {result.returncode})')
        if script == 'test_export_entry.gd' and 'PASS: packaged native terrain kernel loaded' not in output:
            raise RuntimeError('Packaged native-kernel assertion did not run')
        if script == 'test_threaded_mesh.gd' and ('MESH_BACKEND native' not in output or 'Threaded mesh: 0 failures' not in output):
            raise RuntimeError('Packaged mesh test did not use the native kernel')
        if script == 'test_export_entry.gd' and 'PASS: packaged main menu and New diorama editor' not in output:
            raise RuntimeError('Packaged menu/editor test did not finish successfully')
