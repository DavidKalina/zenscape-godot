# Grass clippings: the wash's kick as blades, not confetti (handoff)

When the plane flies low over grass, the prop wash throws up bits of grass. These bits looked like confetti: broad pale chips spinning fast. They now read as clipped grass blades: long thin slivers in the grass's own greens, lit by the scene, turning slowly and fluttering as they fall.

## What changed

All the changes are in `scripts/endless/endless_motes.gd` (the kick) and `shaders/grass_bit.gdshader`. `WindGrassChaff` is untouched.

- **Shape.** The bits no longer use WindGrassChaff's chaff mesh widened 3x. They use their own strip (`_blade_strip`: 6 rows by 3 vertices, 24 triangles). The shader builds the blade from the instance's custom data (width, length, phase, flutter). The blade is mostly parallel-sided and tapers to a point at the tip, with a blunt cut end. It has a creased midrib, a twist and a bow along it, and a flutter wave that runs down it while the air pulls at it.
  - Sizes: `KICK_LEN` 0.5-1.1 m and `KICK_WIDTH` 6-10 cm. That is about the width of the endless grass's standing blades seen at the same distance.
- **Colour.** The grass's own root and tip greens (`KICK_ROOT`, `KICK_GREEN`), taken from the upper part of the blade (`KICK_TIP`).
  - Multiplied by the ground's grass tint where the bits are thrown (`EndlessPatch.tint`: patches and region). This is worked out once a frame per wash or eddy, not once per bit.
  - A quarter of the bits (`KICK_DRY`) are a little dry, a quarter to a half of the way to straw. There are no pastel tints.
- **Light.** The shader is lit (lambert wrap). The face toward the sun is lit and the other is darker.
  - Light through the leaf (`BACKLIGHT` 0.3) and the sky hemisphere as emission (as the far tufts do it) keep a turning blade from flipping to black.
  - The underside's hemisphere leans to the sky, so a blade's dark side stays green instead of going brown.
  - A little gloss (roughness 0.45) gives a glint when the face lines up with the sun.
  - The bits now receive shadows. They cast none.
- **Motion.**
  - **Launch.** A blade starts near upright, leaning the way it is flung. It spins at 2.5-6 rad/s (`KICK_SPIN`, down from 6-16), end over end about the level line across its way, or rolling about its length (35%).
  - **Spin and settling.** Air drag slows the spin (`KICK_SPIN_DRAG`). From 0.25-1.1 s on (`KICK_SETTLE`), a spring (`KICK_LEVEL`) rocks it toward lying flat, with either face up, and `KICK_STIR` keeps it stirring. The result is a slow side-to-side rock as it falls instead of a tumble.
  - **Falling.** A falling blade catches the air more the flatter it lies (`KICK_FLAT_DRAG`), so it falls slowly when flat and faster edge-on. It also slides toward its low side (`KICK_GLIDE`).
  - **Landing.** Once back on the grass (at a random height in the grass tops), a blade lies still for 0.6 s and goes.
- **Counts.** `KICK_RATE` is now 110 a second at full wash (was 120). Lives are 2.6-4.4 s (were 1.4-2.8). The blades start a little higher (0.9-1.6 m) and are thrown a little harder (`KICK_UP`). `KICK_FALL` is 4.8. The batch keeps its cap of 180, a CPU MultiMesh as before, now with custom data (20 floats an instance).
  - Over a low meadow pass about 125-140 blades are flying (the old version had 130).
  - The median spin is about 1.7 rad/s and the 90th percentile about 3.4. The median flatness (|face normal's y|) rises to about 0.65 as they settle.

## Proof

- Throwaway driver: `scratch/kick_film.gd`. It flies the plane low over the seed-1 meadow from (720, 500), heading 0. As a filming aid, it holds the plane 2.2 m over the ground. It films:
  - the chase camera (`play`);
  - a camera riding beside the wash spot (`near`).

  Run it with `python tools/drive.py scratch/kick_film.gd --rendered -- --tag=after --scene-args --at=720,500 --alt=2.5 --heading=0`. `--every=2 --start=60 --markup=2.8 --near=4.5,0.6,2.5` gives the low view toward the sky.
- Sheets (scratch, git-ignored):
  - Before: `scratch/clip/before/near_sheet.png`, `scratch/clip/before/play_sheet.png`.
  - After: `scratch/clip/after/near_sheet.png`, `scratch/clip/after/play_sheet.png`, `scratch/clip/after_sky/near_sheet.png`, and `scratch/clip/after_sky/strip.png` (consecutive frames, 2 apart).
  - Side by side: `scratch/clip/before_after.png` (top: the near view at the same frame; bottom: the chase view).
- Smoke: `python tools/smoke.py studies/endless_flight.tscn` passes with 0 errors. The driver's runs, headless and rendered, had no script errors.
- No existing test touches the motes.

## Open doubts

- **The chase view.** In the green the blades are much quieter than the pale chips were. Up close they read clearly as blades. From the chase camera, about 25 m back, they show as a few yellow-green slivers over the grass, and many are lost in the grass tops. If the user wants more of them in play, the knobs are `KICK_TIP` (lighter), `KICK_WIDTH`, `KICK_RATE` and `KICK_UP`. A pale or silvery underside, the grass's own silver, would also stand out more.
- **Not filmed.** Rolling, take-off and landing were not filmed, and golden-hour light was not looked at.
- **Model budget.** The strip is already minimal (24 triangles, at most about 4.3k for the batch). Of `docs/art/model-budget.md`'s tricks, only fewer rows would apply: 4 rows would save 8 triangles a blade, a negligible frame-time saving.
