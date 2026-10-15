# The Sun-Keepers, round 1 (2026-10-15)

A playable prototype of card **h1** (`brainstorm/round4-strange-city/
lens1-hunters.md` on the brainstorm branch): figures that can only stand
where light falls, and the torch in your hand is light. Greybox, proved
headless. Not wired into the generator.

## Play it

```sh
godot --path . res://studies/strange_sunkeepers_yard.tscn -- --no-title
./run-strange-sunkeepers.command          # the Mac launcher
```

Flags: `--no-body` (no Olmec), `--olmec-chase` (he hunts you too; off by
default so the yard reads), `--no-sleeper`, `--no-household`,
`--keeper-knob=k=v`, `--body-knob=k=v`, `--underground=haze`.

Keys: **T** (pad **Y**) puts your torch out or lights it again (not while a
Keeper holds it). R all back, K the Keepers back, L the look, 1 to 5 the
stations (start, out on the span, the sleeper, the span's south head, the
sun altar), F1 numbers.

The yard: you start on the south plaza. A 2.2 m causeway runs 34 m north
over the void to the north plaza. There, three Keepers (the household)
stand in their lit cresset's light by the span's head. The cresset at the
span's south head starts unlit; touch it with the torch to light it and give
them a road. A lone Keeper sleeps in the dark west of the start. The sun
altar (two low tiers) is in the north-east, and the whole Olmec is posted
far north.

## What was built

- **`scripts/enemies/sun_keeper.gd`**, an `enemy.gd`, spawned through
  `EnemyField` like the ram.
  - **Light as floor.** `SunKeeper.light_on(tree, p)` returns what lights
    floor point `p`: a lit SightLight reaching it at 0.12 or more (a
    cresset, a beacon, a held sun, a dropped torch), `&"torch"` (the
    wanderer's pool, 4 m flat round his flame), or null. By day with no
    look, everything is lit. This is the "light queries on the torch" the
    round 4 README asks for, kept in this file.
  - **Planted walk.** Before each stride it checks where the foot will land
    (lit, a floor, no wall). If it's dark there, it stops at the rim with
    that foot raised over the dark, swaying ("rim").
  - **Light out vs light away.** If the light under it goes **out** (your
    torch doused, its cresset doused or barged over), it topples, stiff as a
    plank. If its head would land over the void, it goes over and is gone.
    On a floor it lies as a heap you can stand on, and once lit for 1.2 s it
    gets up. If the light goes **away** (you walked off with the torch lit),
    it freezes as a statue and wakes when lit again. Mid-stride, either foot
    being lit counts.
  - **Hunting.** It wakes in light and turns to your lit torch within 24 m.
    Its mica disc flashes by how squarely it faces you, which is the
    far-off tell. Then it walks: lift, swing, plant (a squash and a dry
    creak), and a stork hold on the back foot, a beat too long. Its pace
    is 0.67 of your walk, so you can walk away from it.
  - **The knock.** At about 1.25 m it winds up for 0.5 s: it leans back
    and draws its arms behind, then thrusts them out. The first touch is
    `shove_pilot`: a 3 m knock and **1 heart** (cause `"a Sun-Keeper"`).
    The second touch takes the torch.
  - **The steal (built).** The torch is a state: the look's `torch` node is
    hidden, and the Keeper shows a torch prop on its raised hand with a lit
    `Beacon` (draw 60 m). It walks the yard's `keeper_goal` route (span
    head, span head, altar), slipping past its own household on the span.
    Every Olmec in draw turns to it. If it is knocked down (an Olmec
    walking into it, or you running or sliding into it at a full run's
    pace), it drops the torch as a `DroppedTorch`. That torch is a small
    pool of light of its own, and you walk over it to take it back. If it
    goes into the void with the torch, the torch is gone, and you light a
    new one at any fire (the city fires' existing touch-to-relight rule).
    When a Keeper loses the torch, its count of touches starts over.
  - **Look.** Greybox: lime-plaster boxes and drums, with ochre clay showing
    where the plaster has flaked off. It uses the city stone mesher, so the
    vertex-colour occlusion and moss come with it. A metallic mica disc
    for a face, about 1.5 times his height. No horns, spikes or red glow.
    The poses are procedural key poses eased quickly toward their targets,
    not Blender clips. Sounds are synth placeholders (`VOICES`).
- **`scripts/pad.gd`**: a new action, `walk_torch` (T, pad Y). Before this
  there was no player douse in the game. Only the city yards had a T key in
  their own `_unhandled_input`, and the run layer had nothing. This yard
  polls the action. The other yards keep their key.
- **`studies/strange_sunkeepers_yard.{gd,tscn}`** (the city_*_yard idiom on
  `character_study`) and `run-strange-sunkeepers.command`.

## Proof (headless, throwaway `scratch/sunkeepers_drive.gd`, real loop and input)

- `--phase=span`, 22/22 checks:
  - Short of their light, they wake to the torch and stop at the rim of the
    cresset's light, one foot raised (z -24.4).
  - Walked out by the stick, the lead Keeper steps into the pool. It stands
    lit only by the torch, and no heart is lost yet.
  - T (the action) puts the torch out. It topples that frame, goes over
    the side, and is gone in 122 frames. The two still in the cresset's
    light keep standing.
  - With the torch lit again, the next one steps out. He runs off and it
    freezes as a statue on the span (no topple, no drift).
  - He walks back. It wakes, and the shove costs a heart and knocks him.
    The second touch takes the torch: the torch is out and its held sun is
    lit. The thief walks toward the altar, and T won't relight the torch.
- `--phase=sleeper`, 8/8: asleep in the dark, his pool wakes it, and it
  comes. Doused, it topples into a heap on the paving, not gone, and stays
  a heap in the dark. Lit again, it rises after 71 frames and comes on.
- `--phase=fire`: dousing the household's cresset topples all three into
  heaps.
- `--phase=steal`, with the Olmec:
  - A Keeper takes the torch.
  - The Olmec heeds its held sun 12 frames later and closes from 28 m to
    5 m.
  - He walks into the thief, it topples, and it drops the torch.
  - He walks over the torch and it's lit again.
  - The Olmec camping by the torch swats him on the way in (3 hearts).
- Smoke: `studies/strange_sunkeepers_yard.tscn` passes, 0 errors.

## Unverified

There was no display in this round, so nothing was looked at rendered:
- the poses' read
- the mica flash
- the topple's arc
- the yard's light and darkness, and whether the 4 m pool reads on screen

The numbers (pool 4 m, pace 0.67, reach, 3 m shove) haven't been tuned by
play.

## Seams

- **The douse is the yard's only.** To make it game-wide, move the
  `walk_torch` poll into `scripts/underground/underground.gd` (the torch's
  owner) and drop the city yards' own T handlers. If both stay, a press
  toggles twice.
- **Torch pool vs `LightLevel`.** The pool is a flat 4 m disc in
  `sun_keeper.gd`. `LightLevel` only knows the torch on the wanderer
  himself. If more cards need "is this point lit" (x5, p2, t2, a6), move
  `light_on` / `in_torch_pool` into `LightLevel`. There's no occlusion: a
  pool lights through walls, as SightLights already do.
- **Generator.** Not wired. A household would want a lit cresset by a
  narrow span (a city motif's slot) and the run's `keeper_goal` (the
  layer's highest reachable point).
- **Thief route.** The route is the yard's waypoints. Off them it walks
  straight, stopping at void rims.
- **Hearts.** The yard keeps its own count from `PilotMotor.harmed`. In a
  run, RunLoop's hearts take the same signal, and the death card would read
  "by a Sun-Keeper" (the cause falls through `WORDS.causes`).
- **Clips.** Per AGENTS.md, the look and animation want a Blender rig
  (step, stork hold, topple, reach) once the rule is liked.
- **Model budget** (`docs/art/model-budget.md`). About 1k triangles a
  Keeper, in about 14 mesh instances.
  - **Rigid parts on bones:** applies. One skinned mesh would cut it to 1
    to 2 draw calls a Keeper, about 50 fewer for a household of 4.
  - **Vertex-colour grime:** already in, from the mesher.
  - **Silhouette chips** for the flaking plaster: for the turf pass.
  - **Bake low, LODs, parallax:** not worth it at 1k triangles.
