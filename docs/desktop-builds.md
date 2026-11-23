# ZenScape for Windows and Mac

Fly a small plane over land that never ends, and land anywhere flat.

## Install and run on Windows

1. Download **ZenScape-windows-x64.zip** and extract it to a folder of its own
   (right-click → **Extract All**).
2. Open **`ZenScape.exe`** in that folder. Keep `ZenScape.pck` and the DLL
   beside it; the exe alone won't start.
3. This is an unsigned test build, so Windows SmartScreen may stop it the first
   time: click **More info → Run anyway**.

Needs a 64-bit Windows PC with a graphics card that runs DirectX 12 or Vulkan
(most from the last ten years). To update, delete the old folder and extract
the new zip; your progress is kept outside it.

## Install and run on Mac

1. Download **ZenScape-mac-universal.zip** and open it; it unzips to
   **`ZenScape.app`** (plus this README and `BUILD.txt`).
2. Drag **`ZenScape.app`** to **Applications** and open it.
3. This is an unsigned test build, so the first time macOS says it can't be
   opened: click **Done**, then go to **System Settings → Privacy & Security**,
   scroll down to the note about ZenScape and click **Open Anyway**. After that it
   opens normally. (Or in Terminal:
   `xattr -dr com.apple.quarantine /Applications/ZenScape.app`.)

Runs on Apple silicon and Intel Macs. To update,
replace the app with the new one; your progress is kept outside it. The Mac
build is posted by hand, so it can be a little older than the Windows one:
`BUILD.txt` names its commit.

## Controls

| | Keyboard and mouse |
|---|---|
| Bank and pitch | **W A S D** (W is nose down) |
| Steer | mouse |
| Boost / brake | **Space** / **Shift** |
| Knife edge | hold **Q** or **E**; tap twice for a barrel roll |
| Flaps, land | **F** |
| Look round | hold the right mouse button |
| Map / logbook | **M** / **J** |
| Back up in the air | **R** |
| Free the mouse | **Esc** |

Land on any flat grass. Once you've stopped, **Space** takes off again. A
gamepad works too.

`BUILD.txt` beside the exe names the exact commit, which helps when you report
something.

---

## For the developer: how builds are made

`.github/workflows/desktop.yml` builds Windows on a GitHub runner: it installs
the pinned Godot 4.7.2 editor and templates (checksums verified), compiles the
native terrain kernel, imports, checks the kernel against the GDScript
version, exports, then runs the exported exe from outside the checkout for 400
frames from the title (`tools/verify_desktop_export.py`). Each step's log is
judged by `tools/ci_log_check.py`, which ignores Godot's exit-leak reports.

- A push to `main` that passes replaces the files of one published release,
  `windows-latest`, so
  `https://github.com/DavidKalina/zenscape-godot/releases/latest/download/ZenScape-windows-x64.zip`
  always gets the newest build.
- Other branches (via **Run workflow**) and `v*` tags get a draft release per
  run, linked from the run summary. Pull requests build without uploading.
- The repository is private: a download needs a GitHub account added as a
  collaborator (read access is enough for the published release; drafts need
  write access).

The Mac app is not built in CI (macOS runners cost 10x the minutes). It is
built on a Mac and posted to the same release, beside the Windows zip, by
`python3 tools/release_mac.py` (on main, pulled). That rebuilds the universal
native kernels if the C++ changed, exports the `macOS` preset, runs the app
from outside the checkout, packages `ZenScape-mac-universal.zip` and uploads it
(`--no-upload` stops before that). CI's pushes replace only the Windows zip, so
rerun it when Mac players should get the newer build.

To export Windows locally, build the native kernels first
([native/terrain_kernels/README.md](../native/terrain_kernels/README.md)),
install the 4.7.2 export templates, then:

```sh
mkdir -p builds/windows
godot --headless --path . --import
godot --headless --path . --export-release Windows builds/windows/ZenScape.exe
python3 tools/verify_desktop_export.py --platform windows   # files only on a Mac
```
