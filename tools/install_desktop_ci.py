#!/usr/bin/env python3
"""Install checksum-verified official Godot tools on desktop CI runners."""
import hashlib
import os
from pathlib import Path
import platform
import subprocess
import zipfile

version = os.environ['GODOT_VERSION']
workspace = Path(os.environ['RUNNER_TEMP']) / 'zenscape-godot'
workspace.mkdir(parents=True, exist_ok=True)
is_windows = platform.system() == 'Windows'
editor_name = f'Godot_v{version}-stable_' + ('win64.exe.zip' if is_windows else 'macos.universal.zip')
templates_name = f'Godot_v{version}-stable_export_templates.tpz'
subprocess.run(['gh', 'release', 'download', f'{version}-stable', '--repo', 'godotengine/godot-builds',
                '--pattern', editor_name, '--pattern', templates_name, '--pattern', 'SHA512-SUMS.txt',
                '--dir', str(workspace), '--clobber'], check=True)
checksums = {}
for line in (workspace / 'SHA512-SUMS.txt').read_text().splitlines():
    digest, filename = line.split(maxsplit=1)
    checksums[filename.lstrip('*')] = digest
for name in [editor_name, templates_name]:
    with (workspace / name).open('rb') as archive:
        actual = hashlib.file_digest(archive, 'sha512').hexdigest()
    if checksums.get(name) != actual:
        raise RuntimeError(f'Checksum mismatch: {name}')
if is_windows:
    with zipfile.ZipFile(workspace / editor_name) as archive:
        archive.extractall(workspace)
    editor = workspace / editor_name.removesuffix('.zip')
    templates = Path(os.environ['APPDATA']) / 'Godot' / 'export_templates'
else:
    subprocess.run(['ditto', '-x', '-k', str(workspace / editor_name), str(workspace)], check=True)
    editor = workspace / 'Godot.app' / 'Contents' / 'MacOS' / 'Godot'
    templates = Path.home() / 'Library' / 'Application Support' / 'Godot' / 'export_templates'
templates = templates / f'{version}.stable'
templates.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(workspace / templates_name) as archive:
    for name in ['version.txt', 'windows_release_x86_64.exe', 'windows_debug_x86_64.exe'] if is_windows else ['version.txt', 'macos.zip']:
        (templates / name).write_bytes(archive.read(f'templates/{name}'))
with open(os.environ['GITHUB_ENV'], 'a') as output:
    output.write(f'GODOT={editor.as_posix()}\n')
subprocess.run([str(editor), '--version'], check=True)
