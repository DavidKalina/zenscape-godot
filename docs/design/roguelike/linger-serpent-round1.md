# The linger serpent, round 1 (prototype)

Spelunky's ghost for the Olmec city. Stay on a layer and a colossal stone
serpent climbs up out of the void toward you, coiling round a column of
open air off the isles. There is no timer on screen. You read the clock by
looking back. On by default, gated by `RunFeatures.on(&"linger")` and
`RunFeatures.value("linger","serpent") == "serpent"`, so `--linger=colossus`
(another agent's threat) and `--no-linger` / `--loot=off` leave it out.

## What it is

- **The body**: `scripts/roguelike/linger_serpent.gd` extends the rune
  serpent (`scripts/rune_serpent.gd`). It wears the same pebbled Olmec
  basalt, the same chain of rings on the head's traced path, and the same
  neck S, look springs, breath and tongue. The node is scaled x2.4, so it
  is about 215 m long and 10 m through, with a 15 m head. Its runes are cut
  in and barely lit (`RUNE_DIM`), its pebbles are finer
  (`PEBBLE_K`), and its eyes light warm when it fixes on you. Kukulkan's
  ruff is two rows of broad, blunt stone feather plates on the head bone,
  fanned back over the neck. It flies no route. The threat steers its head
  (`go_to`), and every ring follows where the head has been, so the coils,
  the body waves and the rising all come from the head's path. `rewind`
  takes the head back along its own path for the wind-up and the recoil.
  It is not solid and never touches an isle.
- **The threat**: `scripts/roguelike/linger.gd`, laid by one hook in
  `run_loop.gd` `layer_stood` (`# [linger]`) as a child of the layer's
  stage. It is freed with the stage, so every layer starts it again.
  1. **Below** (from the start; coils begin to rise at `STIR` 20 s): coiled
     deep in the haze about 240 m under you, 95-145 m off, behind you from
     the gate. You glimpse it from near a rim. Stone grinding and scale
     loops play low at the ring nearest you.
  2. **Rising** (`SEARCH` 95 s): its head clears your level far off and
     rears up to about 22 m over it, with the body hanging in a helix
     below. The head sweeps slowly over your isles. Sight is a cone plus
     rays to your feet, chest and head (stone between hides you), falling
     off with distance. Crouching (x0.35), standing still (x0.55) and
     creeping (x0.7) keep you hidden longer; being in the air makes you
     plainer. A loud noise on the NoiseBus (9 m or louder, heard within
     5x its loudness) turns its sweep there and raises its awareness.
  3. **It sees you** (awareness reaches 1): it dives under the isles if
     it must cross, comes up under a void poise 30 m off your isle's edge,
     rears up into it and nods over toward you (the hold). Then:
     - **Fix**: about 1.9 s the first time, 1.0 s after. The eyes light
       and the jaw cracks.
     - **Wind**: 0.75 s. The head draws 7 m back along its own body, the
       jaw opens and the head squashes to 0.84.
     - **Hold**: 0.28 s.
     - **Snap**: 72 m/s at where you stood, with 0.1 s of lead, stretching
       to 1.28.
     - **Bite**: the jaw shuts in 0.07 s.
     - **Recoil**: back along the path.

     A hit is one heart (`motor.harm("serpent")`, the card says "by the
     risen serpent") plus a knock that throws you 7 m and leaves you down
     0.6 s. Stone more than 4 m short of you stops the snap (cover); a lip
     at your feet doesn't. Between strikes it sways by its poise. It gives
     up when its awareness drains under 0.3.
  4. **Level** (`LEVEL` 150 s): its column moves in to 48-70 m. It coils
     about your level, rising and sinking 18 m. It sees you twice as fast
     and forgets half as fast. The fix is 0.7 s, the wind 0.55 s, the
     hold 0.18 s and the rest 2.2 s, so it strikes about every 7 s. The
     gate is the only way out.

## Play it

```sh
# the whole climb, from the start (about 2.5 min to level)
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11
# fast-forward: rising (it searches), or level (it strikes)
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --linger-at=110
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --linger-at=150 --linger-debug
```

| Knob | Does |
|---|---|
| `--linger-at=<s>` | start its clock this far on (0; 100 rising, 150 level) |
| `--linger-pace=<x>` | it all runs x times as fast, to fast-forward the whole thing |
| `--linger-scale=<x>` | its size, as the rune serpent's times x (2.4) |
| `--linger-debug` | its stage and act changes, sightings and snaps in the log |
| `--no-linger`, `--linger=colossus`, `--loot=off` | leave it out |

The timings, heights, rings, sight and strike numbers are constants at the
top of `linger.gd`.

## Proved

- Smoke: `run_layer` sprawl seed 11 (plain, and with `--linger-at=150`) and
  ring seed 3 `--linger-at=150` each ran 900 frames with 0 errors.
- `scratch/linger_check.gd` drove the real loop, headless and rendered.
  - **Stages**: at `--linger-pace=4` it goes from deep to rising to seeing
    to striking. The head climbs from -240 m to level and the stage goes
    1, 2, 3, 4.
  - **Standing at level**: it saw him in about 2-10 s and struck every
    about 7 s. A strike from a clear line hits (one heart, a knock).
  - **Dodge through the stick**: running sideways from the wind's start
    dodged 2 strikes of 3, after moving 2.8-4.3 m.
  - **Off switches**: `--no-linger` and `--linger=colossus` lay nothing.
  - **Cost**: about 0.4 ms a frame, 2.3 ms at worst (a column re-pick's
    rays).
- Rendered stills (`scratch/linger_shots.gd`, judged by eye):
  - **Looking back at 128 s**: a huge helix of the serpent stands past the
    rim with its head and ruff on top. This is the image the brief asked
    for.
  - **The strike over his shoulder**: it rears in a loop and fixes with
    lit eyes, then the jaws come at the camera.
  - **Side views**: the body dives under the isles and rears up into an S
    neck.

## Rough

- The opened jaw and tongue are the rune serpent's: a flat slab of a lower
  jaw that reads blocky up close in the wind-up. A proper hinged jaw with
  fangs would help most.
- Sound is not heard (headless). It uses existing kit clips: the scrape
  is `stone-grind-loop` and `serpent-scales-loop` pitched down, the fix is
  a cut of `dragon-growl-loop`, and the snap and bite are `whoosh` and
  `dragon-slam`. The levels are guesses.
- The first approach takes 7-9 s (dive, come under, rear). It looks
  deliberate, but it is slow if he is already near a rim.
- The void column check uses the plan's occupancy and down-rays. The head's
  path between a column and the poise can still pass the edge of an isle's
  underside, and the snap's neck crosses the rim by design.
- No grass cover: cover is stone (rays) plus posture. There is no grass
  density check yet.
- With the head 16 m under the rim at level, it can lose sight of him in an
  isle's middle until it rears. That reads well, but it means his position
  matters a lot.
- Only the coil-and-strike behaviour; it never coils round a real pillar.
- Feathers are on the ruff only; no body plumes.

## Model budget (docs/art/model-budget.md)

The body is the rune serpent's mesh (48 rings, about 2-3k triangles); the
ruff adds about 500. Assessed:

- **Sculpt high, bake low**: not needed. The weathering and pebbles are the
  procedural `olmec_stone` shader, with no texture memory.
- **Import LODs / visibility ranges**: it would apply. At 100-250 m the
  pebbles fade by footprint already; a 24-ring LOD would save about 1.5k
  triangles, which is negligible (under 0.05 ms).
- **Silhouette geometry**: the ruff's blunt jagged plates already use it.
- **Rigid parts on bones**: the ruff rides the head bone (`BoneAttachment3D`)
  with no skinning cost.
- **Parallax depth**: not used. The pebbles' bump is enough at this range.
- **Vertex-colour grime**: used. The feathers' occlusion and tip tone are
  in their vertex colours, as the body's are.

## Existing tests it may break

None were run (prototype). The tests most at risk are those that play a
sprawl run for more than about 95 s of layer time with him standing in the
open, such as `test_run_layer.gd` and long `run_loop` scripted runs. There
the serpent can see and strike him, which costs a heart and knocks him.
Pass `--no-linger` in such tests if needed.
