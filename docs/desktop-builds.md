# Desktop builds

`export_presets.cfg` has two presets. Both build the endless flight
(`studies/endless_flight.tscn`) and leave out `docs`, `tests`, `tools`, `art`
and `builds`.

| Preset | Output | Notes |
|---|---|---|
| Windows | `builds/windows/ZenScape.exe` plus `ZenScape.pck` (keep them together) | x86_64. Sets the file version, product name, company, copyright and icon (`icon.ico`) on the exe; Godot 4.7 writes these itself, no `rcedit` needed. Ships with `zenscape_kernels.windows.template_release.x86_64.dll` beside the exe. |
| macOS | `builds/ZenScape-mac-universal.zip` holding `ZenScape.app` | Universal (Apple Silicon and Intel). Ad-hoc signed, not notarized. Icon `icon.icns`. |

The version is `config/version` in `project.godot`; the presets repeat it
(`0.1.0`, Windows `0.1.0.0`). Change all of them together.

## Export locally

Install the standard Godot **4.7.2** editor and its export templates (Editor,
Manage Export Templates, or the official
`Godot_v4.7.2-stable_export_templates.tpz` from the `godotengine/godot-builds`
release, checked against its `SHA512-SUMS.txt`, unzipped into
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`). Build
the native terrain kernels for the target first
([native/terrain_kernels/README.md](../native/terrain_kernels/README.md),
`--arch universal` for the Mac); without them the export carries the GDScript
fallback.

The Mac export is universal, so `native/terrain_kernels/zenscape_kernels.gdextension`
must name the universal dylibs (`macos.debug` / `macos.release` lines). A
checkout whose descriptor has per-arch `macos.*.arm64` lines exports with
`ERROR: Failed to open ...x86_64.dylib` and no kernel in the app, yet exit 0.
Rewrite it without rebuilding:

```sh
python3 tools/build_native_kernels.py --arch universal --descriptor-only
```

Then, from the project directory:

```sh
mkdir -p builds/windows
godot --headless --path . --import
godot --headless --path . --export-release "Windows" builds/windows/ZenScape.exe
godot --headless --path . --export-release "macOS" builds/ZenScape-mac-universal.zip
```

On a Mac where Godot is not on PATH, use
`~/Applications/Godot.app/Contents/MacOS/Godot`.

## Check an export

```sh
python3 tools/verify_desktop_export.py                     # the host's build
python3 tools/verify_desktop_export.py --platform windows  # on a Mac: files only
python3 tools/verify_desktop_export.py --rendered          # a window, -- --no-title
```

It copies the build to a fresh temp folder (outside the checkout), checks it
holds one pack and the release kernel library (universal on the Mac), then
runs the release binary there with a fresh user folder for 400 frames,
headless, and fails on a non-zero exit or any `SCRIPT ERROR` / `ERROR` line
bar the exit leak reports `tools/godot.py` drops. A kernel library that does
not load logs `ERROR` lines, so a pass means the native kernels ran.

## CI

`.github/workflows/desktop.yml` runs on pushes to `main` and `v*` tags, on
pull requests to `main`, and by hand. It builds **Windows only** (a
`windows-latest` runner): it installs the official 4.7.2 editor and templates
checked against Godot's SHA-512 sums (`tools/install_desktop_ci.py`),
compiles the debug and release kernels against pinned godot-cpp, imports,
checks the native kernel against the GDScript one
(`tests/test_threaded_mesh.gd -- --native-kernels`), exports
`builds/windows/ZenScape.exe`, runs it outside the checkout with
`tools/verify_desktop_export.py`, and zips `builds/windows` (with this file as
`README.md` and a `BUILD.txt`) as `ZenScape-windows-x64-<sha>.zip` onto a
draft release (not on pull requests). Any `ERROR` line in the import, the
kernel check or the export fails the run. The Mac build is made locally
(above); the workflow's matrix has no macOS entry.

## Opening the Mac app

The app is not notarized. If macOS blocks it, try to open it, then use System
Settings, Privacy & Security, Open Anyway
([Godot's notes](https://docs.godotengine.org/en/stable/tutorials/export/running_on_macos.html)).
On Windows, SmartScreen may block an unsigned build: More info, Run anyway.
