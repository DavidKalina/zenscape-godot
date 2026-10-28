# Amberlands, round 1: the look and the land (handoff)

A new world profile, `amberlands` (working name), replaces the overgrown in
the regions mix. It is an old land of ruins with no trees. Amber tall grass
covers broad worn terraces and shallow valleys. Bulky mountain massifs and
tiered plateau chunks break the land up, and ruins gather round them.
Aqueducts run rim to rim across the canyons, or stride out from a rim and end
snapped off over the valley floor. Everything sits under a held low gold sun.
This round uses existing ruin pieces only.

Fly it:

```
.\run-endless-flight.cmd --world=amberlands
.\run-endless-flight.cmd --world=regions                       # wilderness + amberlands
.\run-endless-flight.cmd --world=regions --region-border       # start just short of a border
.\run-endless-flight.cmd --world=overgrown                     # still there, out of the mix
.\run-endless-flight.cmd --regions=wilderness:1:start,amberlands:1,overgrown:1   # all three
```

## What's built

- **Profile** `scripts/endless/world/profiles/amberlands.gd`. The id lives in
  `ID`, the folder `scripts/endless/world/amberlands/` and the registry entry,
  so renaming it means changing those three places.
- **Land** `scripts/endless/world/amberlands/land.gd`. It uses existing recipe
  keys only, so the native kernels need no change:
  - Continents lifted (`continent_lift` 28): a broad interior with less sea
    and more lakes.
  - Longer hills (`hill_scale` 620).
  - Massifs: wide, bulky ranges in clusters (`range_width` 0.26, band
    (-0.5,-0.15), a softened gable, light notches).
  - Terraces over most of the hills: a 7 m step, 74% tread.
  - Three-tier mesas 70 m tall in broad fields (the plateau chunks).
  - Wide, gentle valleys, slightly more meadows, no snow.
- **Look** `scripts/endless/world/amberlands/look.gd`:
  - No trees (`trees` off, forest 0) and no flowers.
  - Grass at 1.15x share and 1.9x height. Its far tone is amber, straw-gold
    near and dark honey at the root, with pale straw undersides.
  - A ripened, gold season (`zs_season`.z 0.6, `zs_autumn` 0.8).
  - Rock sun-bleached (`rock_tint`, less moss).
  - The sea a warm jade.
- **Mood** `amber_hour`:
  - Sky: a pale gold dome going to warm peach at the horizon.
  - Sun and haze: a low gold sun, the haze dusty and warm.
  - Shade: a warm fill, so shadows read warm, not blue.
  - Where it lives: palette family `Amber` (`scripts/scene_look.gd`), preset
    in `scripts/scene_look_presets.gd`, grade numbers in
    `scripts/endless/endless_post.gd`. It is in L's cycle.
  - The world opens at 16.2 h and **holds the clock there** (`paint.still`).
- **Ruins**: the layers are arches 1.8, halls 1.3, tunnels 1.0, splits,
  stacks and hoodoos off. `arch_plan.gd` gained four per-spot layer knobs,
  all absent in wilderness and overgrown, which plan exactly as before:
  - `rock_arches` 0.35 and `ruin_arches` 1.6: fewer natural rock arches, more
    ruins.
  - `ruin_near` 700: aqueducts and gates only within 700 m of ground 30 m
    above them, so ruins gather round the massifs and plateaus.
  - `aqueduct_span` 0.8: an aqueduct site whose valley climbs 20 to 80 m on
    both sides becomes a rim-to-rim span. The deck is level with the lower
    rim and the ends are buried where each rim's ground meets the deck. The
    arches grow to the drop (1.6 to 4.2x) and the piers grow down to the
    floor (the kit's `ground` contract), up to 18 arches. Where only one side
    climbs, a "reach" run strides out from that rim past the floor's middle
    and its last span is snapped off, with the water spilling.
  - Seed 1, 8 km square: 59 valley aqueducts, 32 gates, 9 reaches, 1 to 2
    spans, 54 rock arches, 7 halls and 3 tunnels. Wilderness has 7 aqueducts,
    2 gates and 55 rock arches.
- **Regions**: `scripts/endless/world/regions.gd` now lists wilderness
  (start) and amberlands. Overgrown is untouched and still plays by itself.
- **Engine bits**:
  - `endless_look.gd`: a uniform world whose paint says `still` keeps its
    clock held; `--day` runs it.
  - `endless_ground.gdshader`: a new `rock_tint` uniform (default 1).

## Knobs added

| Where | Knob | Note |
|---|---|---|
| profile `layers` | `rock_arches`, `ruin_arches` | x the chance a fitting spot takes a rock or ruin arch (multiplies the existing `--rock-arches=` / `--ruin-arches=`) |
| profile `layers` | `ruin_near` (m) | ruins only near high ground (`ArchPlan.RUIN_RISE` 30 m); 0 = anywhere |
| profile `layers` | `aqueduct_span` (0..1) | chance an aqueduct tries a rim-to-rim span / one-rim reach (`ArchPlan.SPAN_*`, `REACH_PAST`) |
| profile `paint` | `still` | hold the clock in a one-profile world (the regions world keeps the start region's clock) |
| ground uniform | `rock_tint` | a world's tone over the land's rock (`paint.ground`) |
| mood | `amber_hour` | `--mood=amber_hour` works in any world |

## Proof

- **Smoke**: `--world=amberlands`, `--world=regions`, the default world and
  `--world=overgrown` all pass headless with 0 errors.
  - `--world=overgrown` failed 2 of about 14 runs, with 6 to 7 errors in the
    headless dummy renderer's mesh storage (`rid_owner.h` `get_or_null` /
    `initialize_rid`, `mesh_add_surface`).
  - This is a worker-thread mesh race in the dummy renderer. Overgrown's arch
    path is unchanged (its layers have none of the new keys), so I take it as
    pre-existing. I did not verify that against main.
- **Flats** (`scratch/amberlands/flats.gd`, the earlier rounds' check: 6 km
  square, 192 m strips no steeper than 0.06, land blocks more than 400 m /
  more than 600 m from a strip, worst block):

  | seed | wilderness (overgrown handoff) | amberlands |
  |---|---|---|
  | 1 | 42 / 11, worst 1735 m | 22 / 2, worst 626 m |
  | 3 | 36 / 19, worst 1195 m | 13 / 1, worst 659 m |
  | 7 | 18 / 4, worst 729 m | 17 / 1, worst 648 m |
  | 42 | 10 / 3, worst 1082 m | 13 / 3, worst 986 m |

  Strips cover 20 to 25% of the land (wilderness 13 to 19%). Terrace treads,
  mesa tops and the wide valley floors add flats, so the meadows rule holds
  with more room to spare than wilderness.
- **Clock**: amberlands opens `amber_hour` with the clock held at 16.2 h. The
  regions world's clock runs as before.
- **Regions blend**: at the border band's middle and 1.8 km into amberlands,
  the paint, sky and land ease over (`regions_border_*.png`).
- **Stills** (rendered, Forward+, RTX PC) are in `captures/amberlands/`
  (git-ignored):
  - `terraces_low_amber.png`: low over the terraces.
  - `massif_skim_amber.png`: skimming a massif's foot with a ruined gate.
  - `span_amber.png`: an 18-arch rim-to-rim span.
  - `reach_amber.png`, `reach2_amber.png`: one-rim runs snapped off over the
    floor.
  - `tunnel_amber.png`: a reach, a gate, the tunnel's mouth and a massif.
  - `high_amber.png`: from 800 m.
  - `*_wild.png`: the same views in wilderness. `ab_sheet_1.png` is the side
    by side, `spans_sheet.png` the aqueducts.
  - `map_amberlands.png` / `map_wilderness.png`: top-down maps with the
    arches as dots (red ruins, white rock, magenta spans and reaches).
- **Land hash**: native and GDScript differ for amberlands on this PC (exact
  `b2092e…` against `f17692…`), and they differ the same way for overgrown
  (`76e2b9…` against `a5d884…`), with `native_stamp` saying the kernels are
  current. So the native/GDScript parity gap on Windows is pre-existing, not
  this round's, and I did not chase it.

## Unverified (GPU or play)

- The look was judged in held stills only, not in flight. The palette is
  strongly warm and saturated; the user should judge it in play.
  - Where it could go: the upper sky still leans a little khaki, and the
    massifs' shaded faces read red-brown against the sun.
- **Frame time** was not measured. A span is one merged run of up to 18
  arches grown 3x. One cell with a big run took about 1.2 s to build on a
  worker headless, but its main-thread commit was 0.27 ms. Hitches when
  streaming spans in are unchecked.
- **Collision** through the grown span openings is not flown. Openings are
  `CLEAR` x grow (about 14 to 35 m wide), and the piers below the springing
  stand up to 40 m tall.
- **Landing on amberlands' flats** by hand through the real play loop was not
  driven. The flats check is from the field.
- **Mid-band sky**: crossing the regions border, the sky passes through a
  pale lavender (`EndlessLook.mix_hue` goes round by violet between the
  alpine blue and the amber gold). That is the existing blend's rule; check
  that it reads well in flight.
- I saw one `Trying to assign invalid previously freed instance` error
  storm, once, in a throwaway driver that teleported the camera kilometres
  between views in wilderness with `arches.prime`. It did not come back in
  two reruns, and it is not in any smoke run.

## Tests

- No committed tests (prototype round). I did not run the full suite.
- A grep of `tests/` finds nothing on the regions registry, the mood lists,
  `ArchPlan` or the ground shader's uniforms, so I know of no test this
  change breaks.
- Wilderness's arches are planned exactly as before: every new key reads its
  old default.

## Round 2 needs

- **Giant semi-gothic set pieces** with needle-precise openings, and bridge
  spans: new RuinKit pieces (`tools/kit_piece.py`). Give them stable piece ids
  and `KIND_OF` entries if they break.
- **A placer for standalone structures**: aqueducts and bridges that connect
  chunk to chunk.
  - Today's spans only start at an aqueduct site on a valley floor
    (`ArchPlan._span`), and they run straight across the valley's `across`.
  - A real placer would find pairs of plateau tops, massif shoulders or
    terrace shelves within reach of each other at matched heights, whatever
    lies between. That means reading the mesa field the land doesn't expose
    yet (`last_mesa`: the overgrown handoff suggests it), choosing its own
    cells (spans cross the arches' 480 m cells), and building spans whose two
    ends are both rims.
  - It should also give chunk-to-chunk lines that are flown along, not only
    across.
- **Two-tier aqueducts** for the tall drops: the kit has `two_tier`, but
  `Aqueduct.run` only lays single arcades. Past a drop of about 40 m the
  single piers get very tall.
- **The amberlands' own halls**: today's halls are wilderness's slot halls on
  the massifs' crests.

## Harness gaps

- Tools for this round's checks are uncommitted, in `scratch/amberlands/`:
  - `views.gd`: held-view stills from a list of eye and look points relative
    to the ground; `--prime` builds the arches there first.
  - `map.gd`: a top-down map with arch dots.
  - `census.gd`: the arch kinds, and where the spans, halls and tunnels are.
  - `flats.gd`: a copy of the earlier rounds' flats check.
  - `border.gd`: a still across a regions border.
- **What the harness lacked**:
  - `look_views.gd` has fixed spots and doesn't stream halls, tunnels or rocks
    or paint the regions by the eye. A general "stills at these points in
    world X" driver with arch priming would have saved time.
  - The flats check has been copied from worktree to worktree for three
    rounds. It belongs in `tools/`.

## Round 1b: muted gold, no rivers

The user played round 1 and found it too orange: it read as a desert, with a
flat khaki-orange sky, grass like sand from afar and white-and-red massifs.
They asked for a soft, hazy late-gold light over an old land, warm but muted,
and for no rivers.

### What changed

- **No rivers** (`amberlands/land.gd` `rivers` 0.0). Only amberlands is
  affected; the lakes (`ponds` 0.6), coast and sea stay.
  - The valley floors are dry. Nothing needed a river to be there:
    - `ArchPlan` reads `river_w` only to slide a run, or to turn a site down
      when its openings can't clear the water.
    - Halls, tunnels and ponds only keep away from rivers.
    - In the border band, `LandBlend` weights the river reads like any other
      read, so a wilderness river thins out as it crosses into amberlands.
    - `EndlessLook._river_water` takes its on/off from the start region, so
      `--world=regions` still draws wilderness's rivers.
  - With no river turning sites down, the arch mix moves. Seed 1, 8 km square
    (`scratch/amberlands/census.gd`), before and after:
    - Aqueduct runs 59 to 50, gates 32 to 34, rim-to-rim spans 1 to 0, reaches
      9 to 24.
    - Over 12 km, spans run 4 to 8 a seed (seeds 1, 3, 7, 42).
    - Round 1's 18-arch span at (-2227, 2712) is now a plain run.
    - Seed 1 has a broken 16-arch span over a dry floor at (-2227, -4063)
      (`span_dry_r2.png`).
- **Two new ground uniforms** (`endless_ground.gdshader`). Both default to 0,
  which changes nothing, so wilderness and overgrown paint as before.
  - `carpet_hue` (vec3): the grass paint takes this colour's hue at its own
    light, after the tones. The colour's luma sets how much of the paint's own
    hue gives way.
    - A tone can only multiply, so on green paint it gives orange or mauve.
      This can mute the paint.
    - It has a per-spot `carpet_hue_r[4]`, so in a regions world each
      region's grass keeps its own hue (`regions.gd` picks the array up by
      name).
  - `rock_hue`: the same for the land's rock, before `rock_tint`. It is
    blended at the eye, like `rock_tint`.
- **Paint** (`amberlands/look.gd`):
  - Grass: `carpet_hue` (0.67, 0.63, 0.32), about 62% of the paint's own hue
    turned to straw, the rest left as an olive undertone. The tones are now
    near 1 and only darken it a little.
  - Rock: `rock_hue` (0.85, 0.80, 0.72), mostly grey-beige. `rock_tint` 0.72
    darkens it, `rock_rich` 0.7 and `rock_follow` 0.5 calm the rust beds and
    the lean toward the sun's hue, and `rock_moss` is 0.6.
  - Far tufts: an olive-straw root and tip. Their own instance colour already
    carries warmth, so a straw tip shows orange.
  - Near tufts: `zs_autumn` 0 (it was the red-orange), `zs_season.z` 0.8 and
    `zs_palette_grass` (0.92, 1, 0.88).
  - Sea: muted grey-green shallow, mid, deep and abyss.
- **Mood** `amber_hour`:
  - The clock is held at **16.7 h**, not 16.2. The lower sun gathers the haze
    glow toward itself (golden-hour light follow) and casts longer shadows.
  - Sky (palette `Amber`): a dusty grey-blue to lilac upper sky, a near-grey
    horizon and a pale, low glow, so distance greys rather than oranges.
  - Light: a soft pale-gold sun, a cool grey fill (`ambient` a8acb4), ambient
    energy 1.0 for deeper shade, haze 0.32, mist 0.12.
  - The post grade numbers are less saturated too (they apply only with
    `--post=1`).
  - The palette's grass, rock and water entries don't reach the endless
    flight. It resets the `zs_palette_*` globals to 1, so a profile's
    `globals` are the lever there.

### Stills

`captures/amberlands/` (git-ignored), rendered Forward+ on the RTX PC from
round 1's eye points:

- `ab_sheet_r2.png`: round 1 on the left, now on the right, five rows
  (terraces, massif skim, span, tunnel, from high).
- `*_r2.png`: the single stills, plus:
  - `span_dry_r2.png`: a broken rim-to-rim span over a dry floor.
  - `reach_dry_r2.png`: an 18-arch reach seen across a dry valley.
- `spans_sheet_r2.png`: round 1's reach and span against the dry ones (not
  the same spots).
- `regions_sheet_r2.png`: the border band's middle and 1.8 km past it,
  round 1 against now.
  - The middle no longer goes through the bright violet. It passes from
    alpine blue to grey-lilac.
  - Past the border, the regions world keeps wilderness's clock, so the light
    is earlier and paler there than in `--world=amberlands`.

### Proof

- Headless import: 0 errors.
- Smoke: `--world=amberlands`, `--world=regions`,
  `--world=regions --region-border` and the default world all pass, 0 errors.
- Every rendered driver run had 0 script errors.
- No committed tests, and the full suite not run. A grep of `tests/` finds
  nothing on the palette, the mood or the ground uniforms.

### Unverified

- Judged in held stills only, not in flight.
- The tuft colour moves with the view (straw-gold with the sun behind,
  paler and greyer against it) and between runs as the far ring streams in.
- Frame cost of the two `hued()` calls is unmeasured. Each is one luma and
  one mix per grass or rock pixel.
- Collision through the dry spans, and landing by hand, are not flown.
