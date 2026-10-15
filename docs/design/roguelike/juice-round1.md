# Juice, round 1: hits and finds land (2026-10-15)

Feature `juice` (`RunFeatures.on(&"juice")`, off with `--no-juice` or `--loot=off`).

## What it is

- `scripts/roguelike/juice.gd`: a node the run loop adds (one marked hook in `run_loop.gd setup`). It polls hearts, state and the camera, so nothing else is hooked.
  - **Hit**: a hit-stop (time scale 0.03 for 0.07 s real), a camera kick (Camera3D `h_offset`/`v_offset`, damped ring) the way the blow went (a fall: down), a muffled thud. **Last heart**: hold 0.3 s at 0.06 then a 0.6 s ease, heavier kick, a long low thud.
  - **One heart**: a heartbeat sound locked to the corner heart's beat (`overlay._beat`) and a faint madder vignette pulsing (lub, softer dub).
  - **Item** (`item_taken`): time holds (longer by rarity), the item's glyph rises from him with a soft glow and glints, a warm chord (triad, +7th at rarity 2, +9th/octave at 3), a warm lamp at his feet. The caption is the run loop's.
  - **Gate**: a soft rising breath as the light comes up, a bell and the view settling down on arrival.
- `scripts/roguelike/juice_sounds.gd`: the sounds, synthesised (no assets), on the Genesis bus.
- `scripts/roguelike/item_glyphs.gd` + rewritten `item_strip.gd`: hand-jittered stroke glyphs (own marks: wallrun hand, lantern, heart; by kind: verb arrow, passive ring, cursed jagged diamond). Unknown ids wear their kind's mark plus 1-4 pips from their name. A new item swells with a flash and its name shows 3 s beside the row. The strip now sits under the hearts (it overlapped them before).

## Play

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --give=wallrun
```
Get hurt by a fall or the Olmec to feel the hit; at one heart the pulse starts. Take any item (`run.give_item`) for the find; `--no-juice` to compare.

## Knobs

Consts at the top of `juice.gd` (STOP_*, LAST_*, KICK*, VIG_*, FIND_*, RISE, GAIN_*), `item_strip.gd` (LEFT, TOP, GLYPH, SWELL).

## Rough

- Not heard by me: sounds are untested by ear. Audio may be pitched with Engine.time_scale during holds (AudioServer reported 1.0 speed in a probe, so probably not).
- The rising glyph can sit over the caption's upper edge.
- Camera kick uses h/v_offset, so anything else setting those would fight it (none found).
- Gate beat is sound plus a settle only; the warm veil is the existing flash.
- Hit direction needs the harm's `source`; most harms pass none, so the kick is sideways-random then.
- The strip glyph set is guesses; other agents' items get kind marks until given their own in `item_glyphs.gd`.

## Tests it may break

None expected (no test reads the strip's label). Checked with `scratch/juice_check.gd` (headless and rendered) and the smoke.
