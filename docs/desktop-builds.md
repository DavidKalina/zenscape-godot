# Godot desktop builds

These builds run the **Godot diorama app**, starting at its main menu. You do
not need Godot, Node.js, or the source repository installed to play.

## Download and run

1. Sign into GitHub and open [Godot desktop builds](https://github.com/DavidKalina/zenscape-godot/actions/workflows/desktop.yml).
2. Choose a successful run. Its commit identifies exactly which game version was built.
3. Under **Artifacts**, download **ZenScape-windows-x64** or **ZenScape-mac-universal**.
4. Extract the download, then extract the game ZIP inside it.

**Windows:** open `ZenScape.exe` from the extracted folder. Keep `ZenScape.pck`
and any DLLs in that folder; copying only the executable will break the game.
This build targets ordinary Intel/AMD 64-bit PCs. If Windows SmartScreen blocks
this personal test build, use **More info → Run anyway** after verifying that
you downloaded it from your own repository's run.

**Mac:** move `ZenScape.app` into Applications. The same app supports Apple
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
page to build a selected branch manually. Downloads are retained for 30 days;
run it again if an old download has expired. No public release is created.

Only committed, pushed files are built. Local uncommitted experiments are not
included. The repository is private, so downloads require GitHub access.

The workflow pins **Godot 4.7.2**, downloads the official editor and templates,
verifies their SHA-512 checksums, and caches the desktop tools. Linux exports
both platforms; separate Windows and Mac jobs launch the actual exports to
check for startup errors. No signing secrets or paid developer accounts are needed.

`export_presets.cfg` includes JSON data read through `FileAccess`, alongside
Godot resources, and excludes documentation, test tools, and source art. Mac
builds are archived by Godot before upload so executable permissions survive.

## Export locally

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
