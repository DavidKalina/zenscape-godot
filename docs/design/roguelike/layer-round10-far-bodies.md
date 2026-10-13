# The generated layer, round 10: far bodies (2026-10-13)

> On `feature/layer-bodies`, from fd9c1ad4 (round 9 plus the weathered
> Olmec stone). Builds on layer-round9-bodies.md.

The ask: on sprawl 2 the user saw no bodies at all, because a body only
spawned 8-40 m from the walker, in view but hidden. They want spectacle
too: now and then, a body should come up a cliff far off, in plain view,
so you can watch the whole climb and haul from across a gulf.

## See a far spawn quickly

```sh
godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=2 --knob=spawn_far_share=1
```

1. Wait about 15 s after you can walk. The far isles come in one a frame
   after the start, and the cliffs need their ground.
2. **Press B.** It sets you down on a ledge by the bell spires, at about
   (-197, 153, 151), about 90 m off the sundered gorge's east face, facing
   it. Head 0's body starts
   10 m down that face, in the middle of the screen.
3. Watch for about 10 s of climbing, with a puff and falling stones at
   every handhold. Then the hands slam onto the lip, a cloud blows up off
   the top, it hauls over, and a shockwave ring and plume follow. About
   10 s later it has its head.
   - If B says "no spot found", the isles aren't built yet. Press it
     again.
   - Each press tries the next head. On sprawl 2 only head 0 has a spot
     B can find (see open questions), so the next press is head 0 again.

`spawn_far_share=1` makes every natural spawn a far one too. Without it,
3 in 10 are far (the default). B works at any share.

On sprawl 2 the heads are 300-430 m from the layer's start (the survey
below). That is probably why the user saw no body there: nothing spawns
until you are near one of the head's cliffs, and they are several
crossings away.

## What's in

- **Far spawns** (`scripts/enemies/body_spawner.gd`). Each time a head
  goes bodiless, one roll decides whether the spawn will be far
  (`far_share`) or near (round 9's rules, unchanged). A far spawn needs a
  cliff that is:
  - `far_from`-`far_to` m from the walker (flat), and within `far_view`
    rad of the camera's look;
  - on screen, with its haul point at least 12% in from the screen's
    edges (`ON_SCREEN`);
  - facing his way (`FAR_FACING`);
  - **not hidden**: the camera's lines to the hanging body's hands and
    chest at the lip must both be clear. Its start, lower down the face,
    may sit under his own rim.

  Far cliffs come from round 9's planned, reachable cliffs
  (`layer_bodies.gd`), fitted to the face as before, so a far body can
  still reach its head. A far body **starts down the face** as far as
  the face goes, up to `far_climb` m (found by rays: steep, and never
  stepping more than 1.5 m in or out per metre). It climbs hand over hand
  before the haul. If `far_wait` s pass after `wait` with no spawn of the
  rolled kind, either kind is taken, except at share 0 or 1. The search
  runs every 0.25 s, not every frame.
- **Tells for distance** (`scripts/enemies/body_dust.gd`, new). These are
  one-shot CPUParticles3D that free themselves. Dust is billboards of one
  painted blob (a soft round broken by noise, so the clouds read as
  brushed, not as discs). Stones are plain boxes.
  - Climbing: a puff off the face at each handhold, and 3-4 stones
    falling away.
  - Hauling: the feet scrabble, giving a puff and 2 pebbles every
    0.45 s.
  - The hands slam onto the lip: a cloud off the top, and 10 stones down
    the face.
  - Over the lip (the end of the mantle): a plume, on top of round 2's
    shockwave ring.
  - Landings: a big plume, on top of the ring.
  - The tells grow with the camera's distance: 1x within 60 m, up to 2.5x
    (`TELL_NEAR`, `TELL_MOST` in `headless_body.gd`).
  - **Rumble:** a new low voice, `body_rumble`. It plays when a far body
    sets off, at the slam, and at landings. It carries further (unit size
    90 m, `BodySpawner.REACH`), and so do `body_shock` (30) and
    `body_land` (24).
- **Distance LODs:**
  - **The import LODs are back.** Round 3's stone dressing
    (`inhaler_head_look.gd` `_dressed`, shared by the head and the body)
    rebuilt each mesh as a plain ArrayMesh, which **dropped the glb's
    LODs**. So the head and the body drew every triangle at any distance.
    The dressing now builds an ImporterMesh and generates LODs again: 11
    levels on the body, the same as the import. One-time cost: about
    35 ms for the body and 20 ms per head part.
  - **Posing less often far off.** Past 90 m from the camera, the body's
    clip blend and hand IK run at 30 Hz; past 180 m, at 20 Hz
    (`ANIM_FAR`). Measured in play: at about 106 m, 559 of 1118 frames
    were posed.
- **run_layer:**
  - `--knob=spawn_<rule>=<value>` sets any of BodySpawner's `RULES` over
    the generator's own (`LayerBodies.SPAWN`, `far_share` 0.3).
  - The new **B** key (above).
- `LayerEnemies.build` takes the spawn rules. The study's spawner keeps
  `far_share` 0, so the study is unchanged. Use `--spawn-knob=far_share=1`
  to try far spawns there.

## Knobs

Spawner `RULES`. These are `--knob=spawn_<rule>=` on run_layer and
`--spawn-knob=<rule>=` in the study.

| Rule | Default | What |
|---|---|---|
| `far_share` | 0 (generator 0.3) | Share of bodiless spells rolled far. 1 is every spawn far, 0 is none. |
| `far_from`, `far_to` | 60, 250 m | Distance band from the walker (flat). |
| `far_view` | 0.45 rad | Cone off the camera's look. |
| `far_climb` | 10 m | Most of the face climbed before the haul. |
| `far_wait` | 20 s | Past `wait` with no spawn, either kind is taken. |

Round 9's `wait`, `near`, `far`, `level`, `view`, `hidden`, `natural` and
`stale` work as before, now also as `spawn_<rule>` knobs.

Constants:

- `ON_SCREEN` 0.12, `FAR_FACING` 0.2, `FAR_EVERY` 0.25 s and `VANTAGE`
  (B's stand distances) are in the spawner.
- `TELL_NEAR`, `TELL_MOST` and `ANIM_FAR` are in the body.

## Model budget (docs/art/model-budget.md)

The body is about 84.7k triangles plus 4.2k for the neck cut. The head is
about 66k over its parts.

- **Import LODs: applied, and the big win.** Godot picks a LOD by screen
  size (threshold 1 px). At 1080p a pixel is about 0.11 m at 100 m and
  0.23 m at 200 m.
  - At those distances the body draws its 10.6k-5.3k and 5.3k-2.6k
    levels instead of 84.7k: **about 88-97% fewer triangles** for a far
    body.
  - Up close it gains too: at 20-30 m it already drops to the 42k level.
  - With 2 heads and 2 bodies on a layer, that is about 300k triangles
    cut to under 30k when they're far off.
  - The cut isn't free: skinning still runs over every vertex (Godot
    skins the full mesh before it picks a LOD). LODs cut raster and index
    work, not skinning.
  - Frame time was not measured. Headless can't render, and no profiled
    rendered run was done.
- **Posing less often far off** (not in the doc's list; a CPU trick).
  This halves or thirds the AnimationTree blend (15 clips) and the IK for
  far bodies. Its frame-time saving wasn't measured. Round 9 saw 4-6 ms
  headless frames with one body, and the posing is part of that.
- **Sculpt high, bake low: applies, not done.** A 10-15k baked body
  would cut skinning cost about 6x at every distance, which LODs can't
  do. It is the next lever if bodies show up in a profile.
- **Rigid parts on bones: applies, not done.** The body is masonry. Its
  blocks could be rigid meshes on BoneAttachment3Ds instead of skinned,
  which cuts skinning to bone transforms. This would mean redoing the
  Blender build.
- **Silhouette geometry, parallax, vertex-colour grime.** No change. The
  weathered stone shader already does the surface, and the dressing bakes
  occlusion into vertex colour.
- **Visibility ranges: not used.** The camera's far plane is 400 m, past
  which nothing draws anyway, and the far band ends at 250 m.

## Captures

These are in the worktree, at
`captures/layer-round10-far-bodies/`, which is gitignored (`captures/`;
checked with `git check-ignore`). Each shot has a `_zoom` crop beside it,
centred on the body.

| Files | What |
|---|---|
| `s2h0_*` | Sprawl 2 head 0, from about 107 m (B's stand). |
| `s2h0_far_*` | Sprawl 2 head 0, from about 165 m, across the gulf. |
| `dust_t*.png` | The dust and stones alone, on grey. |

How it reads:

- **At about 107 m** the body reads clearly on the face while it climbs.
  The handhold puffs show as pale smudges on the dark face. The slam,
  the haul plume and the ring are unmistakable (`s2h0_09`).
- **At about 165 m** the climbing body is a small dark figure with a
  smudge of dust. You'd spot it if you were looking that way. The haul
  plume and ring (`s2h0_far_09`) and the landing plume (`s2h0_far_11`)
  read from across the gulf without hunting for them.
- The grown landing plume is big at 165 m (2.5x). It might be too much;
  `TELL_MOST` sets it.
- The climbing puffs sometimes veil the body itself at 107 m.

## Verified, and not

Verified:

- **Headless import, then the smoke check.** `run_layer` sprawl 2,
  `run_layer` ring 1 and `headless_body_isle` each loaded and played 400
  frames with no script errors.
- **Throwaway play-loop checks**, in `scratch_lb/`, uncommitted
  (`far_check.gd`, `far_capture.gd`, `far_survey.gd`, `dust_look.gd`).
  Sprawl 2, through the study's own frame at `--fixed-fps 60`:
  - **The real input path:** B was pressed as an input event and set the
    walker down 90 m off. A far spawn came 10 m down the face. It was on
    screen and in clear sight for every one of its 613-676 climb and
    mantle frames. It hauled over at 10-11 s, went on to its head and was
    whole. The run did this twice.
  - With `spawn_far_share=1` and the walker stood 90 m off (not through
    B), the natural rules spawned it and it was whole too.
  - The body's mesh has 11 LODs in play.
- **Rendered captures:** windowed and `--no-title`, one at a time, each
  quit by a wall-clock watchdog thread. Two earlier capture windows froze
  when macOS throttled them unfocused, so the watchdog replaces
  `--quit-after`.

Not verified:

- **B on other seeds.** On ring 1, B found no spot in 60 s. On sprawl 2,
  head 1 (up the stair and the bell spires, 112-147 m over the start)
  has none either. B's stands are ground 70-210 m out along a cliff's
  face, and the follow camera looks down. From the ground a cliff high
  above isn't on screen, and the near rims block the low ones. Natural
  far spawns have the same limit, and the camera's pitch decides much of
  it.
- From the start of sprawl 2, 3, 5 and 11, no far spawn fires. Either
  the heads are past 250 m, or the start isle's own walls and hills block
  the line.
- Frame time: no rendered profile. The LOD savings above are estimated
  from the LOD table and screen size.
- **The rumble wasn't listened to.** Headless has no audio, and the
  captures are stills.
- Near spawns are unchanged in code. Only the smoke check exercised them
  this round.

## Open questions

1. **The far share.** Is 3 in 10 about right, and is "rolled once per
   bodiless spell" the right rule? The other option is a far spawn
   whenever one is possible.
2. **The far rules versus the follow camera.** The camera looks down, so
   high far cliffs rarely count as on screen. Should the rule allow
   "just above the screen", hoping the player looks up? Or should B (and
   the rules) stand you higher?
3. Should the tells grow with distance (now up to 2.5x), or stay true to
   size?
4. Is B worth keeping as a dev key, or should it go once you've seen it?
5. The landing plume at 2.5x is big. Is it spectacle or too much?

## Existing tests

No test references the spawner, the body, the heads' look, the layer's
enemies or `knobs_from`. `spawn_<rule>` knobs don't enter `KNOBS`, so
the plans and their fingerprints are unchanged. Nothing should break, but
the suite wasn't run (prototyping: no suite run unless asked).
