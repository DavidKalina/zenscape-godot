#!/usr/bin/env python3
"""Build the default native mesh-shading kernel against the installed Godot API."""
import argparse
import os
from pathlib import Path
import platform
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', required=True, help='Godot editor executable')
parser.add_argument('--godot-cpp', required=True, type=Path, help='Official godot-cpp checkout')
parser.add_argument('--scons', default='scons', help='SCons executable')
parser.add_argument('--target', choices=['template_debug', 'template_release'], default='template_debug')
parser.add_argument('--arch', choices=['arm64', 'x86_64', 'universal'], help='Defaults to the host architecture; universal is macOS only')
parser.add_argument('--platform', choices=['windows'], help='Cross-compile for Windows x86_64 with MinGW-w64 (e.g. Homebrew mingw-w64 on a Mac); the host otherwise')
parser.add_argument('--jobs', type=int, default=min(8, max(1, (os.cpu_count() or 2)-2)))
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
project = root / 'native' / 'terrain_kernels'
api_dir = project / 'bin' / 'api'
api_dir.mkdir(parents=True, exist_ok=True)
(api_dir / '.gdignore').touch()
system = {'Darwin':'macos', 'Windows':'windows', 'Linux':'linux'}.get(platform.system())
arch = {'arm64':'arm64', 'aarch64':'arm64', 'x86_64':'x86_64', 'AMD64':'x86_64'}.get(platform.machine())
arch = args.arch or arch
cross = args.platform == 'windows' and system != 'windows'
if cross:
    if args.arch not in (None, 'x86_64'):
        parser.error('--platform windows builds x86_64 only')
    system, arch = 'windows', 'x86_64'
if arch == 'universal' and system != 'macos':
    parser.error('--arch universal requires macOS')
if system is None or arch is None:
    parser.error('Unsupported build host; invoke SCons directly for cross compilation.')
subprocess.run([args.godot, '--headless', '--log-file', str(api_dir/'dump.log'), '--path', str(api_dir), '--dump-extension-api'], check=True)
subprocess.run([args.scons, '-C', str(project), f'platform={system}', f'arch={arch}', f'target={args.target}',
                f'godot_cpp={args.godot_cpp.resolve()}', f'custom_api_file={api_dir / "extension_api.json"}',
                f'build_profile={project / "build_profile.json"}', f'-j{max(1,args.jobs)}'] + (['use_mingw=yes'] if cross else []), check=True)
if cross:
    # The host's descriptor (already listing the Windows libraries) is kept.
    if not (project/'zenscape_kernels.gdextension').exists():
        (project/'zenscape_kernels.gdextension').write_text((project/'zenscape_kernels.gdextension.in').read_text())
    print(f'Built bin/zenscape_kernels.windows.{args.target}.x86_64.dll; copy it and zenscape_kernels.gdextension to the Windows checkout (docs/design/roguelike/native-isles-round1.md).')
    raise SystemExit(0)
descriptor = (project/'zenscape_kernels.gdextension.in').read_text()
if arch == 'universal':
    # Godot's universal exporter must package one library with both slices.
    lines = descriptor.splitlines()
    lines = [line for line in lines if not line.startswith('macos.')]
    for target in ['debug', 'release']:
        lines.append(f'macos.{target} = "res://native/terrain_kernels/bin/libzenscape_kernels.macos.template_{target}.universal.dylib"')
    descriptor = '\n'.join(lines) + '\n'
(project/'zenscape_kernels.gdextension').write_text(descriptor)
print('Built native kernels; ordinary launches now use them automatically. Use --gdscript-kernels to compare the fallback.')
