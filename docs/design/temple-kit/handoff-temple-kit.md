# Handoff: the temple kit (loop `temple-kit`, 2026-11-12)

Branch `claude/ruins-kit-game-1c8fb0`, not pushed. The trail:
`git log --grep='^ITER(temple-kit)' --format='%B'`. Spec:
[spec-temple-kit.md](spec-temple-kit.md).

## What's built

- **The kit.** Eleven Blender-built pieces in one stone:
  `column`, `column_broken`, `column_drums`, `lintel`, `lintel_broken`,
  `podium`, `podium_corner`, `podium_stair`, `podium_floor`, `wall_door`,
  `wall_broken`. Source `art/blender/temple_kit/` (`temple_lib.py` and one
  build script per family), models `assets/models/temple_kit/`, loader
  `scripts/temple_kit.gd` (`piece`, `lod`, `mesh`, `boxes`), stone
  `shaders/temple_stone.gdshader`. A piece with an `<id>_mid.glb` beside it
  gets a middle model with no code change; `column`, `column_broken` and
  `lintel` have one.
- **The temple** on the island north of the pirate ships, in the old
  belfry's place (`way/isle`, `scripts/endless/temple_site.gd`). One
  straight line flies through it: under the front lintel, through the
  broken porch (the `isle-tower` ring hangs there), through the doorway,
  out over the fallen drums. `--temple=0` puts the belfry back.
- **The lighthouse** on Light Rock, rebuilt in the kit's stone
  (`art/blender/coast/lighthouse_build.py`, `assets/models/lighthouse_stone.*`,
  placed by `scripts/endless/coast_sites.gd`). Lamp, beam, ring and landing
  flat kept. `--lighthouse=old` puts the old model back.

## Where to look

- Gallery: `.\run-temple-kit.cmd` (drag to orbit, wheel to zoom,
  `--hour=17.5` for dusk).
- Temple: `python tools/play.py -- --at=1000,2760`.
- Lighthouse: `python tools/play.py -- --at=2100,3400`.

## Checks run on the final tree (37814bf1 + 7e7f4b51)

- Smoke, all PASS with 0 errors: the gallery; the main scene at the
  default start, at the temple, at the lighthouse, and with
  `--temple=0 --lighthouse=old`.
- Flight through the real play loop at medium weight, cruise and Boost
  (5bc1c64f): the door line clean on the centre and a wing's width left,
  right, up and down (closest 1.5 m), the ring collected; the line along
  the colonnade clean (3.0 m at a wing's width). Run before the corner and
  stair were rebuilt; their solids did not change.
- A landing check found no holes in the temple's floor.
- The lighthouse's solids: stopped by the shaft and the lantern, clean
  through the ring's place (run before its trim; the solids did not change).
- No committed tests were added and the suite was not run. A test that
  pins the belfry or the old ring position at `way/isle` would now fail;
  none was looked for.

## Measured cost (drawn triangles, visible / shadow, rendered run)

| View | Temple, first build | Temple now | Old belfry |
|---|---|---|---|
| 100 m | 51.6k / 168k | 43.0k / 142k | 36.8k / 92k |
| 300 m | 51.6k / 103k | 39.5k / 79k | |
| 340 m and out | 2.6k | 2.4k | 29.8k at 400 m |

The lighthouse draws 22.6k at 30 m, 6.6k from 90 to 320 m and 776 past
that (it was about 50k at every distance before its trim). Frame time was
noise in every run, so there is no frame-time number. The platform corner
and stair were rebuilt after the temple's table was measured.

## Stood in, or open

- **The side front gaps.** Flying between the two outer pairs of front
  columns runs into the inner wall 12.5 m behind the porch. Whether they
  should fly clean through is the user's call.
- **The far models pop** at about 300 m: columns go to smooth, darker
  tubes. The near-to-middle swap shows nothing.
- **Platform middle models** are not built. The build path is in
  `podium_build.py` (`-- --only=podium_mid`), but the first pass read
  darker than the near model on the step fronts, so none was committed.
  Also without one: `podium_stair`, `lintel_broken`, both walls,
  `column_drums`.
- **Close-up changes from the trim:** column flutes are a V notch at 6 m,
  where they were rounded.
- **An exposed lintel end** shows a 0.3 m slot under the frieze (visible on
  the broken stub).
- **From the bay tower's foot** the temple is a small pale cluster, a
  weaker landmark than the 120 m belfry. The user has seen it and prefers
  the temple.
- **Still the old kit:** the other two way towers (`way/bay`, `way/south`)
  and the cracked chamber on Long Isle.
- **Not in the kit:** breaking the new pieces, ivy. The `boxes.json` files
  are read from disk, so an exported build needs `*.json` in its export
  filter.
- `AGENTS.md` and `tools/README.md` still name `tools/kit_piece.py` and
  the yard scenes, which were cut from the repo before this loop.
