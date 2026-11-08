# Desktop builds

`export_presets.cfg` has two presets. Both build the endless flight
(`studies/endless_flight.tscn`) and leave out `docs`, `tests`, `tools`, `art`
and `builds`.

| Preset | Output | Notes |
|---|---|---|
| Windows | `builds/windows/ZenScape.exe` plus `ZenScape.pck` (keep them together) | x86_64. Sets the file version, product name, company, copyright and icon (`icon.ico`) on the exe, which needs `rcedit` (Godot's Export settings). |
| macOS | `builds/ZenScape-mac-universal.zip` holding `ZenScape.app` | Universal (Apple Silicon and Intel). Ad-hoc signed, not notarized. Icon `icon.icns`. |

The version is `config/version` in `project.godot`; the presets repeat it
(`0.1.0`, Windows `0.1.0.0`). Change all of them together.

## Export locally

Install the standard Godot **4.7.2** editor and its export templates (Editor,
Manage Export Templates). Build the native terrain kernels for the target
first ([native/terrain_kernels/README.md](../native/terrain_kernels/README.md),
`--arch universal` for the Mac); without them the export carries the GDScript
fallback. Then, from the project directory:

```sh
mkdir -p builds/windows
godot --headless --path . --import
godot --headless --path . --export-release "Windows" builds/windows/ZenScape.exe
godot --headless --path . --export-release "macOS" builds/ZenScape-mac-universal.zip
```

On a Mac where Godot is not on PATH, use
`~/Applications/Godot.app/Contents/MacOS/Godot`.

## CI

What the GitHub workflow (`.github/workflows/desktop.yml`) builds and checks
is covered by a later task of the ship build.

## Opening the Mac app

The app is not notarized. If macOS blocks it, try to open it, then use System
Settings, Privacy & Security, Open Anyway
([Godot's notes](https://docs.godotengine.org/en/stable/tutorials/export/running_on_macos.html)).
On Windows, SmartScreen may block an unsigned build: More info, Run anyway.
