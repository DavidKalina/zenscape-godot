# The Hollow Child, round 1

Card x5-hollow, round 4 "strange city" (`brainstorm/round4-strange-city/
lens3-exploitable.md`, on the `brainstorm/round4-strange-city` branch). A
prototype to play in its own yard. It isn't in the generator.

"It is fed on the light of whoever sits with it. When it is full, it cries."

## Play it

```
godot --path . res://studies/strange_hollow_child_yard.tscn -- --no-title
./run-strange-hollow-child.command          # the Mac launcher
```

The yard opens in the underground torch look (`--underground=haze` for the
haze, `--day` for none). You start south-west. A lit route runs north, then
east across the Olmec's front, then north to a gate behind him. The child
sits on the route about 24 m in front of his post, in his sight, with an
unlit cresset beside it.

- **T**: your torch out or lit. Relight it at any lit cresset.
- **H**: the child empty again. **K**: the side cresset out.
- **R**: back to the start (the Olmec and the child too).
- **B**: the Olmec back. **J**: his sight overlay. **L**: the look. **F1**: numbers.

The HUD shows the child's state, fill and what it drinks, the light on you
(and how much is drunk), and the beacon the Olmec heeds.

Knobs: `--hollow-knob=<k>=<v>` (`reach`, `torch_fill`, `flame_fill`, `leak`,
`breath`, `cry`, `spent`, `cry_radius`, `cry_pull`, `cry_draw`, `lean`).
The Olmec's knobs are `--body-knob=`, as in the other city yards.

## The rule, on the real sight and beacon code

- **`LightDrinker`** (`scripts/enemies/light_drinker.gd`) is the negative of
  a `SightLight`. It drinks a share of the light within `radius`: all of it
  within 0.75 of the radius, falling to none at the edge.
- **`LightLevel`** (two small additive edits): the torch on him and every
  sight light are scaled by `1 - drunk`. `drunk` is the most any drinker
  drinks at his chest, or at that light's own flame. So beside the child he
  reads as the ambient only, torch lit or not. A cresset whose flame stands in
  the child's reach lights nothing. With no drinker in the tree it's the old
  sum exactly.
- **`Beacon.all_lit`** (one additive edit): a beacon whose flame is half or
  more drunk draws no one. So the child "eats" a cresset: lit beside it, it
  neither lights you nor lures him.
- **The child** (`scripts/city_hollow_child.gd`) carries a drinker of 6 m
  (at the wanderer's size) and a `Beacon` at its mouth, unlit. Its states:

| State | What it does |
|---|---|
| empty | Pale and cold. It drinks: flames in reach are drunk. |
| drinking | Fills from what it drinks: the torch alone in 25 s, a cresset (strength 1) in 8 s, both faster. |
| breath | Full: 2 s, a rising hiss, its eyes and mouth glow, it swells. You're still hidden. |
| cry | A rising clay-whistle wail. Its Beacon lights: 12 m of light at full strength, pull 2, draw 160 m. It drinks nothing now, so you stand in the brightest place. 20 s. |
| spent | Cold and quiet for 60 s. Flames burn normally. Then empty again. |

**What empties it**, decided per the card: the cry pours everything out
(full to empty at once), and it goes cold for 60 s. Unfed (no flame in
reach) it also leaks back to empty, from full in 60 s. So you can top it up,
walk away and come back, but not bank it forever. Putting your torch out
beside it (T) stops the filling at once.

**The tell**, readable from the high camera:
- Every flame it drinks leans toward its mouth. That's the flame shader's
  `wind`, set in the flame's own frame, and your torch gutters a little.
- Motes of warm light stream from each flame into its mouth.
- The glow inside climbs the clay from its feet to its eyes, brightest
  through the thin cheeks and belly, and a small warm light under it grows.
- Its head turns slowly toward the nearest flame.
- A low clay-whistle hum rises in pitch and loudness as it fills.
- The breath gives a 2 s warning.

Sounds are synthesized placeholders.

## The model

The model is `scripts/city_hollow_child_mesh.gd`, baked by
`tools/bake_hollow_child.gd` to `art/hollow_child/hollow_child_{body,head}.res`.
- It's a signed distance field (blended ellipsoids and tapered capsules)
  meshed by surface nets, its normals from the field's gradient. The eyes,
  the open down-turned mouth and the navel are cut in.
- The head is its own mesh about the neck, so it can turn.
- It's about 1.05 m seated at the wanderer's size: a crouched wanderer's
  height.
- It's 10.4k triangles for the body and 6.6k for the head, with Godot's
  generated LODs.
- The vertex colours carry baked crevice grime, wear, thinness and the
  mouth's cavity.

The material is `shaders/hollow_child_clay.gdshader`:
- Burnished kaolin slip with mottling and a broad wash.
- Grey fire-clouds from the firing.
- Crazing, faded by pixel footprint.
- The slip worn through to red clay at the knees, toes, knuckles, nose tip,
  cheekbones, belly and crown, plus some flakes.
- Ochre dust on its tops and low down, and grime in the folds.
- The underground's stone fill.
- No horns, spikes or red glow. The glow is warm amber, dim until the cry.

## How it was proved

All through the real play loop, with throwaway drivers in `scratch/`:
`hollow_child_check.gd --part=sight|cry|cresset`. The wanderer walks by the
stick, and the torch is put out with the real T key.

- **Sight** (Olmec held, `--body-knob=walk=0 --body-knob=turn=0`):
  - He walks about beside the child for 9.7 s, torch lit, 26 m from the
    Olmec. His sight reads him lit at most 0.14 (the ambient is 0.1),
    awareness 0.00, never spotted.
  - Out of its reach (13.5 m from it, 26.6 m from the Olmec), the same torch
    reads 0.95 and he's spotted at once.
  - Control, `--hollow-knob=reach=0`, the same walk: lit 0.95, spotted.
- **Cry** (Olmec free, roaming):
  - On the torch alone it filled in 24.9 s. Not seen, though the Olmec
    roamed to 14 m.
  - At the breath: T, then he runs west. It cried 2.0 s later. The Olmec
    heeded its beacon 0.2 s after that and walked from 14.4 m to 4.5 m of
    it, standing and looking (one visit).
- **Cresset**: the side cresset lit (by code, standing in for the torch
  touch) filled it in 8.0 s, and its beacon was out of `Beacon.all_lit`.
  Control (`reach=0`): it's listed, and the Olmec heeds it.
- **Smoke**: the yard passes. city_fires, city_refuges, city_light2 and
  whole_body_chase still pass (they use the edited light and beacon code).
- **Tests**: test_world_scale_guard, test_world_scale_fit, test_dragon_sight
  and test_enemy_ram pass. No test covers LightLevel or Beacon directly.
- **Stills**: GL compatibility under Xvfb, so not the Forward+ look. They
  were used to judge the model and the fill read. The flame volume doesn't
  draw in that renderer, so the flame lean is unverified by eye.

## Seams

- **Not in the generator.** The child's natural places are a shrine niche, a
  hall's dark side bay, or beside a cresset on the Olmec's route. It needs a
  socket in the city kit.
- **The child drinks through walls**, as SightLights light through walls
  (round 1's limit).
- **Its cry is a beacon, not a sound the Olmec hears.** When the noise bus
  lands (another agent's round), the wail and the breath should also be
  noises.
- **Lighting the side cresset** uses the fires kit's torch touch: climb its
  plinth or catch its lip.
- **Carrying it** (the card's later hook) waits on carrying.
- **It drinks a lit cresset forever.** Placed by one, it fills, cries,
  spends, refills, and cries again every ~90 s: a clockwork lure. The yard's
  side cresset starts unlit for that reason.
- **The route's cressets have no draw here** (`beacon.draw = 1`). They light
  you but don't pull him about, so the child is the only lure.
