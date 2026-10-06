# Godot desktop builds

These builds run the **Godot diorama app**, starting at its main menu. You do
not need Godot, Node.js, or the source repository installed to play.

## Download and run

1. Sign into GitHub and open [Godot desktop builds](https://github.com/DavidKalina/zenscape-godot/actions/workflows/desktop.yml).
2. Choose a successful run. Its commit identifies exactly which game version was built.
3. In the run summary, follow **Download build** to its draft release.
4. Download `ZenScape-windows-x64-<commit>.zip` and extract it. CI builds Windows
   only; for a Mac app, export locally (below).

The ZIP filename includes the build commit. Extract each download into a fresh
folder to avoid launching an older executable or mixing it with another build’s
`.pck`. On Windows, `BUILD.txt` beside the executable identifies the exact commit.

**Windows:** open `ZenScape.exe` from the extracted folder. Keep `ZenScape.pck`
and any DLLs in that folder; copying only the executable will break the game.
This build targets ordinary Intel/AMD 64-bit PCs. If Windows SmartScreen blocks
this personal test build, use **More info → Run anyway** after verifying that
you downloaded it from your own repository's run.

**Mac** (local export): move `ZenScape.app` into Applications. The same app supports Apple
Silicon and Intel. It has an ad-hoc signature, but no Apple notarization. If
macOS blocks it, attempt to open it, then use **System Settings → Privacy &
Security → Open Anyway**. See [Godot's Mac launch instructions](https://docs.godotengine.org/en/stable/tutorials/export/running_on_macos.html).

The app uses the project's Forward+ renderer and existing graphics settings.
Use the in-game quality settings to compare frame rate and appearance. CI
checks startup without a display; it cannot judge GPU performance or mouse feel.
Saved dioramas stay in Godot's user-data directory, outside the extracted app.
Use **Save a copy** and **Open diorama** to move a world between computers.

## Make a new build

The workflow runs after pushes to `main`, version tags (`v*`), and pull requests
targeting `main`. It also runs on `codex/godot-build*` while this setup is being
introduced. Once the workflow is on `main`, choose **Run workflow** on its Actions
page to build a selected branch manually. Each push or manual run creates a **draft release**, with the commit in its title
and a link in the run summary. Pull requests validate exports without creating
downloads. Draft downloads remain available until you delete that draft release;
no public release is created. This avoids the account’s full Actions artifact
storage quota without deleting existing files.

Only committed, pushed files are built. Local uncommitted experiments are not
included. The repository is private; draft releases require signing in with repository
write access (the repository owner can download them).

The workflow pins **Godot 4.7.2**, downloads the official editor and templates,
and verifies their SHA-512 checksums. A Windows runner compiles our C++ terrain
kernel with pinned godot-cpp bindings and SCons 4.8.1, then exports Windows.
Mac builds are made locally (see below) to save Actions minutes.

Before uploading each download, CI launches its actual release executable from
outside the source checkout. It requires the packaged native kernel, compares its
mesh results with GDScript, and checks that the diorama menu appears and New
diorama opens the editor tool tray. A missing kernel fails the build rather than
silently using the fallback. The draft release is created before builds start;
the download appears only after its checks pass. No signing secrets or paid developer
accounts are needed.

`export_presets.cfg` includes JSON data read through `FileAccess`, alongside
Godot resources, and excludes documentation, test tools, and source art. Mac
builds are archived by Godot before upload so executable permissions survive.

## Export locally

Build the matching native debug and release libraries first, following
[Native terrain kernels](../native/terrain_kernels/README.md). For universal Mac
exports, pass `--arch universal` for both builds. Without native libraries, a
clean local checkout still exports the GDScript fallback; the CI pipeline always
requires native libraries.

Install the standard **4.7.2** editor and matching export templates from
**Editor → Manage Export Templates**, then run from the project directory:

```sh
mkdir -p builds/windows
godot --headless --path . --import
godot --headless --path . --export-release Windows
godot --headless --path . --export-release macOS
```

On a Mac where Godot is not on PATH, replace `godot` with
`~/Applications/Godot.app/Contents/MacOS/Godot`. Outputs go into `builds/`.
