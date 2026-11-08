# Handoff: ship (the Steam build), round 1

Branch `iter/ship`, worktree `../zenscape-ship`. Spec: `spec-ship.md`.
Trail: `git log --grep='^ITER(ship)'`. Date: 2026-11-07.

## What's built

- **Wilderness is the default world.** `--world=doors` still plays the
  two-region world with the amberlands behind the doors.
- **Shell** (`scripts/endless/shell/`): the title's foot row (Settings,
  Controls, Credits, Quit); Pause on Esc or the pad's Menu (Resume,
  Settings, Controls, Quit to Title, Quit) as one more overlay; Settings
  (fullscreen, render resolution, graphics preset, vsync; master, effects,
  ambience, mute, vibration; mouse sensitivity, invert pitch for mouse and
  stick), applied live and saved to the existing config files; a Controls
  page with drawn pad glyphs; Credits with the sound attributions, the
  fonts' OFL and the Godot notice. Quit to Title is a clean scene reload.
- **Economy** (`scripts/endless/money.gd`, `money_hud.gd`, `pilot_book.gd`,
  `shop_stock.gd`): money is 5 per point times the multiplier's square root;
  old books multiply by 1000 once on load. Prices come from one tier table
  in `shop_stock.gd` by minutes of decent flying at 6,000 a minute:
  ribbons 30,000 to 54,000, paints 60,000 to 360,000, plane bodies
  720,000 (2 h) and 1,440,000 (4 h), a spare 2,880,000 tier. Every number
  is formatted with separators. The balance shows top-right in flight; a
  purchase flares and rings the bell; until the first shop is found a
  gold arrow at the top centre points at the nearest one.
- **First flight** (`scripts/endless/first_flight.gd`): on a fresh book
  after the title's Start, a ribbon guides five steps (steer, low pass,
  pull up, one near miss, bank and land) with a hint card; Backspace or
  d-pad down skips; `tutorial_done` in the book. `--first-flight` forces it
  (with `--no-title` it starts in the air), `--first-flight=0` turns it off.
- **Plane bodies** (`art/blender/hero_plane/hero_plane_body.py`,
  `assets/models/highwing/`, `assets/models/racer/`): a high-wing cabin
  monoplane and a stubby racer beside the biplane, same holds, same
  handling, repainted by the shop's liveries; a `plane` slot in the shop
  swaps the body in place.
- **Audio licences:** the six CC BY-SA bird and owl clips are replaced
  with public domain or CC0 recordings (the chickadee is now Black-capped);
  `assets/audio/ATTRIBUTION.md` and the credits page match.
- **Identity:** the game is `ZenScape`, version 0.1.0, with company,
  copyright and file versions in both presets and a new flat biplane icon
  (svg, png, ico, icns). `docs/desktop-builds.md` and `docs/gamepad.md`
  rewritten to the truth.
- **Builds:** `.github/workflows/desktop.yml`'s verify step runs
  `tools/verify_desktop_export.py` (the export launched headless from
  outside the checkout, 400 frames, no errors) instead of a deleted test.
  Both presets export locally; the OFL texts ship in the pack; the Mac
  export carries the universal native kernel once
  `python3 tools/build_native_kernels.py --arch universal --descriptor-only`
  has rewritten the git-ignored descriptor (run it in the main checkout).

## Where to play it

    cd ../zenscape-ship && python3 tools/play.py -- --pilot=fresh

The exports (git-ignored): `builds/ZenScape-mac-universal.zip` (unzip with
`ditto -x -k`; unsigned, so Open Anyway) and `builds/windows/`.

## Proved

Smoke on `studies/endless_flight.tscn` with and without `--first-flight`;
the lanes' drivers re-run on the merged tree (pause and title menus, the
economy's checks, the first flight through all five steps from the title
and the skip, buying and wearing a body with the paint reaching it); stills
of every shell screen at 1440x900 and 1280x800, the shop with the Planes
rows, both bodies on the meadow and in the air, the icon at 1024 and 32 px;
the Mac app run outside the repo, headless 400 frames and rendered 900
frames, 0 errors.

## Not proved, or stood in

- The 6,000-a-minute earn rate is reasoned from the old pay, not measured:
  no bot weaves trees. A hand-flown flight with `--line-log` and
  `tools/line_report.py` calibrates `PilotBook.MONEY_PER_POINT`.
- Fullscreen and vsync toggles were not seen switching in a window.
- The tutorial was flown by a driver following gate centres, not by hand.
- The Windows exe was exported here but not run; the workflow has not run
  on a push since the fix.
- No one has listened to the new bird clips in play; two are rougher
  (the kinglet is faint over hiss, the NPS jay is 16 kHz).
- The plane rows in the shop have blank swatches where paints have chips.
- On seed 1 the nearest shop is 5.4 km from the start.
- The project rename moved `user://` to a new ZenScape folder; old saves
  are not found.

## Open after this round (the user's list)

- A sound pass: the engine bed is loud and grating (the user's words); no
  music yet, which needs a clean licence.
- Steam: partner account, depots, store assets; `--pilot=fresh` and the
  Deck's 1280x800 are already in the harness.
