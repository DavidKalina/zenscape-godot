# City fires, round 1: fire on high

The fire pieces of the underground Olmec city kit (cards in
`brainstorm/round3-olmec-city/`: `maker_cresset`, `maker_runnel`,
`maker_wickspire` in kit-k6-light.md, `ol_beacon` in kit-k7-vertical.md),
and the mechanic the beacons round faked: the wanderer lights a fire by
touching it with his torch.

Branch `kit/city-fires`, off `roguelike` 2b0e2e0e (with city-breaks and the
underground ground cover).

## Play it

    ./run-city-fires.command                         # torch look (the default)
    ./run-city-fires.command --underground=haze      # L flips torch / haze; G the ground cover

This opens `studies/city_fires_yard.tscn`, a basalt plaza over the abyss.
A whole Olmec hunts there (chase, periscope, chase routes) and a headless
body roams.

- **The great cresset** stands in the plaza's middle. Climb its two tiers
  and it catches. Every Olmec within reach turns to it and comes to look.
  Chased past it, he barges it over: the bowl falls, and a lit one leaves
  a burning spill on his lane.
- **The fuse wall** is west. Walk up to the feed port at the terrace
  wall's foot. The flame runs along the wall, climbs beside the giant
  steps, crosses the terrace top and lights the terrace cresset.
- **The beacon tower** is east. Climb its giant steps to light its crown.
- **The wick spire** is south-west. Its glyph steps spiral up to a cresset
  in the crown cup (Mudge's future home).
- **The layers above** are six far pillars in the abyss, each with a lit
  tower: you read the layers by their lights.

Keys:
- T: your torch out (you are dark to him) or lit again. Touching any
  burning fire also relights it.
- K: every fire out, and the tipped ones stood again.
- R: everything back. B: the bodies back.
- J: his sight overlay. F1: numbers, including the light on you and each
  body's beacon.

Flags: `--day` (no underground look), `--body-at=x,z`, `--body-face=x,z`,
`--body-knob=`, `--head-knob=`, `--no-body`, `--no-headless`,
`--sight-overlay`.

## The lighting mechanic

No button and no menu: **touch it with the torch.** Each unlit piece checks,
every physics frame, where the underground look's torch flame is
(`Underground.flame`, carried by the figure). If the flame is within the
reach below, the piece lights.

- **A bowl.** The flame must be within `TOUCH` 0.7 m of the bowl's rim
  (flat) and between 1.2 m under the lip and 1.6 m over it. In play that
  means standing on the plinth's top tier beside the bowl, or catching the
  bowl's lip. Hanging from the plinth's edge is not enough, so lighting is
  a small climb.
- **A runnel's feed port** (a small cup at about hip height): walking up
  to it lights it.

The torch:
- A doused torch (the look's `torch` node hidden, T in the yard) is lit
  again by touching any burning bowl or spill, the same way.
- With no underground look there is no torch. The pieces then light only
  from each other (a runnel) or from code (`light()`, `burn()`).

On lighting:
- The fire flares: its height overshoots by 45% over 0.9 s, then settles,
  with a burst of 16 embers.
- The plinth's glyph runes flare from a faint 0.06 to 0.7.
- The yard says "<piece> catches".
- `Cresset.torch_lightings` counts the times the torch did it.

## Pieces and APIs

`scripts/city_kit_fires.gd` (preload it; no `class_name`):

- `PIECES` (id to a one-line description) and `build(id, parent, xform,
  opts)`.
- Builders: `cresset`, `tower`, `runnel`, `spire`.
- Torch helpers: `torch_point(tree)`, `torch_lit(tree)`,
  `set_torch(tree, on)`, `touches(p, rim, radius)`.
- `cover_ring(parent, outer, inner, y, seed, tufts)` lays the underground
  ground cover on a walk top less what stands on it.
- `olmecs(tree)` returns the bodies of every EnemyField.

### `Cresset`

`cresset(parent, xform, {size, lit, seed, barge, walker, pull, draw, beam})`

**Sizes** (`size`):

| size | plinth tiers (side m / top) | bowl lip radius | lip height |
|---|---|---|---|
| `cresset` | 3.6 / 1.6 | 1.1 | 2.6 |
| `great` | 6.4 / 1.6, 4.6 / 3.2 | 1.6 | 4.4 |
| `crown` | none (sits on a tower or spire) | 0.95 | 0.75 over its shelf |

All heights are in SET_OFF and stands at his size (`RuinKit` times
`WorldScale.wanderer`):
- Every tier top is 1.6 m over the last, so one plain jump catches it.
- Each tier's ring round the next is at least 0.7 m (STAND plus a margin).
- The great cresset's lip is 1.2 m over its top tier.

**Lit, it is three things:**
- **A light:** a `CityFire` with an OmniLight3D.
  - great: 34 m, energy 10, the only one with shadows.
  - cresset: 24 m, energy 6.
  - crown: 22 m, energy 5.
- **A `SightLight`:** radius 12 m for the great cresset, 9 m for the rest.
- **A `Beacon`:** it draws Olmecs from radius × 8 (96 m and 72 m).
  - `gather` is half the plinth plus 3 m, so he comes to look from beside
    the plinth and not into it.

**API:**
- `light()`, `burn()` (lit with no flare), `douse()`, `tip(dir)`,
  `touched_by(p)`, `rim()`.
- `lit`, `broken`, `torch_lightings`, `spill`, `spill_beacon`.
- Signals `lit_changed(on)` and `tipped(dir)`.

**Breaks.** It is in the `breakable` group, so it speaks the city-breaks
hub's protocol (`scripts/kit_isle/breakables.gd`):
- `standing_rids`: standing, the plinth and bowl are air to his routes.
  He plans straight through, so chasing you past it he barges it.
- `met(hub, body)`: his bulk box against the plinth tips it his way, with
  a stagger, a hit-stop and a shake.
- `wave(hub, body, w)`: his landing's shockwave, inside 0.62 of its reach,
  tips it away from where he landed.
- `rubble_rids`: the fallen bowl.

The tip is scripted, uses no Jolt bodies, and takes 0.75 s:
- It goes over slowly at first, then falls, with a small bounce.
- The bowl lands lying beside the plinth.
- `hub.changed(box)` then tells the bodies' routes.
- A lit bowl leaves a **spill**: a wide low fire (1.4× the light) and its
  own Beacon on the ground where it fell, burning `SPILL` 14 s, then out.

**Without a hub** (a scene with no breaker), the cresset is plain stone
that he walks round. `walker: true` makes it walker-only stone with its own
barge check instead.

### `Tower`

`tower(parent, xform, {tiers 3, tier 3, base 8.0, lit, steps true, beam})`

- **Tiers.** Each tier is `tier` × SET_OFF (4.8 m) tall.
- **Giant steps.** On the local +z face, each tier carries a run of giant
  steps:
  - Each step is SET_OFF higher than the last, 1.4 m wide and two stands
    (1.4 m) deep.
  - At that depth you stand clear of the tier's face, so a jump along the
    run catches the next step instead of starting a wall run. Round one's
    0.7 m steps caused exactly that wall run.
  - Each run starts where the last one ended. It turns back when the tier
    is too narrow.
- **Set-backs** are one step-run plus a stand on the stepped face and
  0.25 m round the rest. A far tower (`steps: false`) tapers evenly.
- **Crown.** Its `crown` is a `crown` Cresset with no `barge`.
- **`beam`** widens the crown's halo for far towers. In the yard the far
  ones use 3, with `draw` 1 so that no Olmec here heeds another layer's
  light.
- At the defaults the shelf is 14.4 m up.

### `Runnel`

`runnel(parent, xform, points, normals, {speed 3, afterglow 4, ember 0.3, width 0.3, tail, broken})`

- **The channel** is a strip along the polyline (UV.x is metres from the
  head), drawn by `shaders/city_runnel.gdshader`:
  - Unlit, it is glossy black resin between dark cut walls.
  - Lit, a white-gold tongue runs at the front. Behind it the channel
    churns orange, then settles over `afterglow` to an ember glow that
    stays, so the line and the holds beside it stay readable.
- **The front.** A small `CityFire` (with a 9 m light) and a 6 m
  `SightLight` ride the front.
- **The trail.** It lights a low trail light every 4 m as it passes. These
  have no shadows and settle to ember.
- **The end.** At the end it calls `tail.light()` and emits `arrived`.
- **`broken`** takes stretches (from, to in metres). The flame stops at
  the first one.
- **`head()`** is the feed port, a small basalt cup.

### `Spire`

`spire(parent, xform, {tall 16, radius 1.6, lit})`

- A drum one SET_OFF high, then a six-sided shaft.
- **Glyph steps** spiral up the shaft: blocks SET_OFF apart, 30° round
  each, a stand deep.
- **The crown cup** is wide enough to perch on round the bowl, and holds a
  `crown` Cresset.
- Its climb was not driven. It is optional this round.

### `CityFire`

`scripts/city_fire.gd` is the fire itself, on the campfire's shaders, so
the city's fires and the hearths are one fire. It has:
- Eight flame cards in one MultiMesh (`campfire_flame`): five body tongues
  and three licks.
- A coal bed (`campfire_coals`).
- A camera-facing halo (`stone_lamp_halo`).
- Up to 28 embers (`fire_ember`), simulated only within 70 m of the
  camera.
- One OmniLight3D. Its flicker is two noises: a slow breath and a quick
  lick.

Its knobs are `flame`, `bed`, `light_range`, `light_energy`, `shadows`,
`halo`, `halo_glow`, `flicker` and `embers`.

### Ground cover

The underground ground cover (`GroundCover.cover`, via `cover_ring`) goes
on every flat walk top:
- The cresset tiers get root and tufts on the lower ring. The top ring by
  the bowl gets a skin only, with no tufts (nothing grows in its heat).
- The tower gets cover on its set-backs and its crown shelf.
- The yard covers the plaza and the terrace.

It is null with the look off.

## Registering in the city kit

```gdscript
const CityFires = preload("res://scripts/city_kit_fires.gd")
# in the family's PIECES:  ... + CityFires.PIECES.keys()
# to stand one:
var node := CityFires.build(id, parent, xform, opts)   # opts per builder above
```

A scene that wants the Olmec to barge cressets needs the city-breaks hub
(`breakables.gd`) as each body's `breaker`. See the `Slot` in
`studies/city_fires_yard.gd` or `studies/city_breaks_yard.gd`. Without it
nothing breaks, and the rest works.

## Proof through the real play loop

The drivers are uncommitted in `scratch/`. All pass headless with 0
errors, on the stick and the jump.

**`fires_light.gd`** (yard defaults, both bodies):
- He walks to the great cresset, jump-climbs tier 1 (1.6 m) and then tier
  2 (3.2 m). On the frame he lands on tier 2 the torch (at 4.63 m, 1.7 m
  from the axis) lights it. `torch_lightings` is 1.
- He walks 30 m away.
- The whole Olmec turned to it while he walked off, and came from 61.7 m
  to 5.0 m. There it spotted him and chased.
- The headless body turned too and came from 35.4 m to 6.1 m.

**`fires_runnel.gd`** (`--no-body --no-headless`):
- He walks to the feed port and it lights.
- The flame runs the 28.5 m runnel in 9.5 s and lights the terrace
  cresset. `torch_lightings` stays 0: it was the runnel. All 7 trail
  lights came on.
- He then climbs the giant steps beside it to the 6.4 m terrace top.

**`fires_tower.gd`**: he climbs the beacon tower's nine steps and ledges,
1.6 m each, to its 14.4 m crown shelf. The torch lights the crown.

**`fires_barge.gd`** (the lit great cresset, the Olmec 26 m north, you
behind it):
- He chases and pounces through it, and it tips at 8.7 s.
- The bowl rests beside the plinth.
- A lit spill lies on his lane as a Beacon. The bowl's own fire is out.
- The spill burns out after 14 s.

**`fires_sight.gd`**: is he plainer by the lit cresset?
- The setup: the whole Olmec held still (walk 0, turn 0, chase speed 0,
  beacons off), facing the cresset. He walks by the stick to its east side
  and stands for 12 s.

| look | torch | Olmec off | cresset | light on him | spotted |
|---|---|---|---|---|---|
| torch | out | 24 m | out | 0.10 | never |
| torch | out | 24 m | **lit** | 0.94 | **0.5 s** |
| torch | lit | 24 m | either | 0.95 / 1.0 | at once |
| haze | out | 24 m | out / lit | 0.45 / 1.00 | 0.9 s / at once |
| haze | lit | 42 m | out | 0.79 | never |
| haze | lit | 42 m | **lit** | 1.00 | **0.7 s** |

So in the dark, the cresset's light is what gives you away. Under the torch
look your own torch already does, at 24 m and at 42 m.

**Smoke** (`tools/smoke.py`, 400 frames), 0 errors each:
- `studies/run_layer.tscn` sprawl seed 1, and seed 7 with
  `--underground=torch`.
- The yard with no flags (torch), `--underground=haze` and `--day`.

Also run: headless import, and `tests/test_world_scale_guard.gd` (passes).

## Stills

Taken rendered with the bodies off, in `docs/design/roguelike/city-fires-round1/`.
That folder is in this round's worktree and not committed: `/docs/**/*.png`
is gitignored. Retake them with `scratch/fires_shots.gd --rendered`.
- `great_before_after_torch_haze.png`: the great cresset before and after
  he lights it, torch (top) and haze (bottom). Lit, a warm pool spreads on
  the dust, the plinth casts its shadow and the runes flare.
- `great_close_torch.png`: the bowl, the flame and the embers close up.
- `runnel_and_far_towers.png`:
  - Top left: the runnel running, its front tongue climbing beside the
    giant steps.
  - Top right: the runnel run, the terrace cresset lit, in haze.
  - Bottom: the far towers on their pillars, from the beacon tower's
    height, in torch and haze. The layers read as lit dots stacked in the
    dark.

The full sets are in `captures/city_fires/{torch,haze}/` (gitignored).
Another unsaved still showed the Olmec standing at the lit cresset looking,
his eyes lit.

What I tuned by eye:
- The fire's light was raised: it hardly warmed the floor at first.
- The far pillars got a broad stepped isle on top and a leaning lesser
  column. As bare columns they read as sticks.
- Far crowns get a 3× halo.
- A cover drum that hid the runnel was moved.
- The yard sets the stone's hemisphere fill to the look's ambient (torch
  0.12, haze 0.55). The day's fill made the basalt glow. The generator may
  want the same: its Olmec stone still takes the day clock's hemisphere
  underground.

## Model budget

The pieces are procedural. Triangle counts as built:

| piece | triangles |
|---|---|
| cresset | 524 (bowl 476) |
| great cresset | 568 |
| beacon tower | 864 (its crown included) |
| far tower | 636 |
| spire | 976 |
| runnel | about 37 a metre (a strip and its port cup) |
| the yard's ground, pillars included | one mesh |

What applies:
- **Silhouette geometry: applied.**
  - The bowl's lip is bitten at random segments (35% of 18), with real
    walls on each bite, so the rim reads chipped against the flame. That
    is about 40 triangles.
  - Everything else is flat chamfered blocks, with the grain from
    `olmec_stone`.
  - Saving: against a sculpted chipped rim (about 2k triangles), about
    1.9k a bowl.
- **Vertex-colour grime: applied.**
  - The Mesher's occlusion darkens each block's foot.
  - The bowl's inside is toned 0.45 for soot and resin.
  - Saving: free, about 0.1 ms against an AO pass or extra textures on
    several pieces.
- **Import LODs and visibility ranges: apply next.** The far towers are
  seen 150-300 m off. Two cuts:
  - A 4-triangle tapered box with the halo would save about 600 triangles
    and two draws each, about 3.6k triangles for the yard's six.
  - The ember sim already stops past 70 m.
  - The far crowns' OmniLights are the real cost: six unshadowed lights.
    Culling them past 120 m (keeping the emissive halo, which reads alone)
    saves an estimated 0.1-0.3 ms on the forward+ clustered pass.
  - Not done: the user should first judge whether the far light on the
    tower tops matters.
- **Sculpt high, bake low: would apply** to the card's crouching bearer
  under the bowl (shared with a throne figure). The shaft is a stand-in
  drum with a helmet ring. A 2-3k-triangle baked figure would be the
  model's cost, against about 25k sculpted.
- **Parallax depth: optional** for the runnel's groove. It would read
  deeper for no triangles, about 0.1 ms for its pixels. Not done: the
  shader's dark cut walls read as a groove at play range.
- **Rigid parts on bones: doesn't apply.** Nothing is rigged. The tipping
  bowl is one node moved by script.

**Light budget.**
- The great cresset is the only shadowed light.
- A runnel adds one moving light and one low light per 4 m, none
  shadowed.
- With everything in the yard lit, that is about 20 OmniLights. In the
  generator, lights past 60 m should be culled or pooled, as the card asks.

## Limits

- **The torch.** It is the underground look's prop: no look, no torch.
  - Nothing douses it in play: no snuff trough, wind or long fall. T in
    the yard stands in.
  - There is no thrown torch or flung ember to light a far decoy cresset.
- **The touch reach is generous on purpose.** Standing on the great
  cresset's top tier always catches it, even with your back to the bowl.
- **Not lights or beacons yet:**
  - The heat updraft over a lit bowl.
  - Slam or sluice dousing.
  - Shade volumes.
  - The SightLight still lights through walls (beacons round 1's limit).
- **The tower and spire don't break.** The card's tower topple onto a
  rubble bridge and the spire's set-piece topple are not built.
- **A runnel's `broken` stretches are data only.** No break makes them,
  and a spent runnel has no refill.
- **The crouching bearer is a stand-in drum.** No Blender model.
- **Not placed by the generator.** Only the yard stands these pieces, and
  `scripts/city_kit.gd` (another agent's) doesn't register them yet.
- **Turn times.** The beacon-turn times in `fires_light.gd` are counted
  from when he finished walking away (about 3 s after lighting). Both
  bodies had already turned by then.
- **Ground-cover motes.** With them on, rendered runs end with the cover's
  known exit noise ("1 shaders of type ParticlesShaderRD were never
  freed").

## Tests broken

None expected. The round adds new files only:
- `scripts/city_kit_fires.gd`
- `scripts/city_fire.gd`
- `shaders/city_runnel.gdshader`
- `studies/city_fires_yard.*`
- `run-city-fires.command`

No shared script was edited. The full suite was not run (prototyping
rules).

## Open questions

- **Is the touch rule right?** Two choices are open:
  - Climbing onto the plinth lights it, which is generous. Should he have
    to face the bowl, or catch its lip?
  - Should T (put your torch out to hide) become a real move?
- **The flame's look.** The campfire's three-band flame cards read
  Nintendo-bold. Is that right for a great cresset, or does it want a
  taller, softer column and smoke in the haze?
- **The runes.** Lit, the plinth's glyph runes flare. Unlit they keep a
  faint glow (0.06), a "light me" hint in the dark. Is that too much, or
  too little?
- **The spill.** Should it hurt (burn him on his lane, or burn you), or
  stay a light and a lure?
- **Far tower lights.** Keep the real light on far tower tops, or go to
  halo-only past 120 m?
