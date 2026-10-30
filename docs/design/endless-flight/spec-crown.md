# The crown: rebuilding the Peak

Loop `crown`, trail prefix `ITER(crown):`, branch
`claude/mountain-peak-visual-polish-e79633` (main's frame-rate work plus the
Peak branch, merged). Read `docs/design/endless-flight/peak-handoff.md` for
what stands today; this spec replaces its "Next rounds".

The Peak has a sound body and a bad face. From the meadow it is a wide table
with a cone on it; flown, it is a huge smooth lump of clay. The user wants a
mysterious summit that feels like scaling something epic: a little fantasy, a
little menacing, somewhere a dragon could live but maybe doesn't, a place
that will one day be a portal to another world.

## What done looks like

1. **From the meadow:** three great towers, uneven, leaning in toward each
   other, the tallest off centre, one side of the mountain falling away.
   No flat crest, no tub. It reads as a crown from any side.
2. **Spirals:** each tower has its own spiral of cloud coiling up around it,
   and it reads as a spiral, not as the land's puffy clouds. It is visible
   from the meadow and turning.
3. **The mouth:** a giant rock prow splits the way in. Choose a side: an ice
   gorge or a rock gorge. They rejoin at a high saddle.
4. **Inside the mountain, not over it:** the gorges are walls passing above
   the wings. They hide the summit, then you come out and it is right there.
5. **Snow:** a real snow surface, carved by wind, blue in shade, glittering
   at low sun, that answers the plane: skim it and powder blows up and a
   furrow stays behind for a while. Spindrift streams off ridges and tips.
6. **Ice:** a tongue following the gorge, broken blue seracs, dark rock
   stripes running down the flow. Not a rectangle, not mint-green pancakes.
7. **The lake:** dark and still between the towers, cracked ice at its edge,
   and it reflects a sky that isn't this one. Not a picnic blanket.
8. **Flags:** strings of weathered flags waving in the wind up the stair,
   at the saddle and the lake, some across gaps you can fly under.
9. **The rock stays as good as the side views are today** (the user likes
   `scratch/peak/meadow2/try1/rim.png` in the Peak worktree): dark, edge-lit,
   sun to one side. Get that light onto the approach.

## Keep

- The user likes the staircase. It moves into the rock gorge, it stays.
- Landing on the summit (`place/peak`, the landing card, the logbook) and a
  flat strip there long enough to land by hand (236 x 44 m today).
- Nothing gated. Straight up stays allowed. Every weight can reach the top
  one way: a chosen, telegraphed lift in the rock gorge (the couloir's lift
  moved) gets heavy there. The couloir itself goes; do not fix its
  regression (peak-handoff.md, Open), its ground is being replaced.
- The sky above with its own hour, by height near the Peak.
- Handles: `peak/massif`, `peak/tarn`, `peak/stair/<n>`. New ones
  `peak/tower/<n>`.
- AGENTS.md's Sizes (`WorldScale.opening`) and Meadows and flats.

## Taste the user has already ruled on

- Gritty, not edgy: weathered stone, no horns, no lava, nothing cartoon evil.
- No fine high-frequency grain on the shared rock shader
  (`endless_rock.gdshaderinc`): it was hated on the cliffs. The land's rock
  paint is liked. Sea stacks (`scripts/endless/rocks/sea_stacks.gd`) are the
  reference for rock forms that work: big, squarish, banded.
- Depth comes from detail that shrinks with distance, warm near against cool
  far, and value contrast. Calming noise loses it. A/B any look against the
  same frames before calling it better.
- Nothing outside the Peak's zone changes unless this spec says so.
- Fly-through places must be hand-flyable: prove them with wobble and margin,
  not one exact autopilot line.

## Why it looks wrong now (traced in code, 2026-10-30)

- Snow and ice run through the rock shader: the normal is snapped to 9x6
  direction buckets with no distance fade and light is cut to 3 tones
  (`shaders/endless_rock.gdshaderinc:263,266,283-295`, called from
  `shaders/endless_ground.gdshader:1085`). Good on rock, plaster on snow.
- Height detail stops near 11 m: one 4-octave FBM from 90 m, no ridged or
  eroded term (`peak_massif.gd:302,509`, `_h`). Mesh blocks are 32 m cells.
- Ice and scree are straight smoothstep bands along the massif's axis
  (`endless_ground.gdshader:660-686`), so the ice is a rectangle.
- Spires are 34-92 m round lofts on a 1400 m mountain.
- The collar is one flat annulus with one base and top (`collar_inside`,
  `endless_cloud_march.glsl:882-909`); field clouds are one slab per layer
  under a 1250 m cap. It cannot wrap a tower. Its front also fails to draw
  from 2 km out.
- The tarn is a field depression painted by the ground shader's river path:
  still water loses its streaks, reflection is a fresnel term.

## Lanes (parallel, one Opus or Sonnet agent each, branched from the merge)

Each keeps its code in its own new files, edits shared files small and
additive, carries a flag to switch it off, and ends its commit with **Notes
for merge** (the shared lines it touched). `endless_ground.gdshader` is
shared by three lanes: each puts its work in its own `.gdshaderinc` and adds
a hook of a few lines. Each lane proves itself on today's massif, because the
crown's ground doesn't exist yet, and leaves its API for the trunk.

- **towers** (Opus). `scripts/endless/rocks/peak_towers.gd`: a hero tower
  from a table: base point and height, tip height, lean direction and amount,
  girth, seed. 300-600 m tall, cross-section squarish and irregular with big
  planes, bands and buttresses, not a lathe. Near mesh, LODs, collider, and a
  far version drawn beyond the 8 km rock streaming so the crown is always on
  the skyline (`land_rocks.gd:34,37`). Today's limits to break: 20-24
  segments a ring, lumps capped at 12 m, group reach under the 480 m cell.
  Rock paint from the existing bare shader. Assess `docs/art/model-budget.md`
  in the handoff.
- **spirals** (Opus). `scripts/endless/peak_spirals.gd` + a shader: one
  continuous coiling ribbon of cloud per tower, thinning toward the tip, each
  with its own speed, one turning the other way. It must read as a spiral
  from 4.5 km and hold up flown through (soft, no collision). Not the cloud
  march. API: a list of axes (base, tip, radius). Proves on three test axes
  over today's massif. Collar stays for now; the trunk turns it off.
- **snow** (Opus). `shaders/peak_snow.gdshaderinc`: out of the rock shader's
  buckets and tones; wind-carved ripples, blue shade, warm sun, glitter at
  grazing sun, all shrinking with distance. The plane's wash reaches it
  (reuse `scripts/endless/grass_react.gd` and `grass_react.gdshaderinc`) and
  leaves a furrow that fills in; low passes throw powder (the kicked bits in
  `scripts/endless/endless_motes.gd`). Peak zone only.
- **ice** (Opus). `shaders/peak_ice.gdshaderinc`: glacier ice with depth,
  blue in cracks and shade, sheen, flow stripes, driven by a mask term the
  trunk can reshape. New seracs: blocky, broken, undercut, tumbled
  (`scripts/endless/rocks/peak_valley.gd` holds today's).
- **lake** (Sonnet). `shaders/peak_tarn.gdshaderinc`: dark still water, a
  mirror of another sky (not this hour's), cracked ice at the edge, a shore
  that isn't a white disc. Reads the tarn's own centre and level, since the
  trunk moves it.
- **flags** (Opus). `scripts/endless/peak_flags.gd` + a shader: strings of
  weathered cloth on poles or between two points, waving on the global wind
  (`zs_wind_direction`, `zs_wind_strength`, `zs_motion_time`), one batched
  draw, no colliders. API: a string from A to B with a sag. Proves on the
  stair today.

## Trunk (in order, Opus, one task an iteration)

1. **Crown.** Lower and break the crest, drop one side away, take the horn
   off, place the three towers (`peak/tower/<n>`), the lake between them,
   the summit strip. Tallest tip ~1400 m; lower the lake and plateau as far
   as it takes the towers to stand 400 m or more over them. Today's 14 spires
   stay only where they help.
2. **Split.** The prow, both gorges, the saddle. The stair and lift in the
   rock gorge. Hand-flyable by margin and wobble, both ways, every weight.
   **The loop stops here for the user to fly it,** before anything is built
   on the shape. Don't go on without their word.
3. **Ice in place.** The tongue down the ice gorge, seracs, dark moraine
   stripes; the ice and boulder rectangles go.
4. **Rock detail.** Ridged, eroded height on the Peak only, at the scales the
   plane flies past. A/B. Watch chunk cost (40-76 ms near the Peak today).
5. **Light.** Side light on the approach at the default hour, by the massif's
   facing or the Peak's own hour, whichever keeps the land's clock honest.
6. **Flags and spindrift.** Place the strings. Spindrift off ridges and tips.
7. **Far and cost.** The crown from every distance and side; collar off by
   default; rendered frame times along the flight against today; load time.

## Checks

- `python tools/smoke.py studies/endless_flight.tscn`, and with
  `-- --world=regions`, for every task.
- Stills for anything seen. The Peak round's drivers are git-ignored:
  copy `scratch/peak_meadow2.gd`, `peak_stills.gd`, `peak_helpers.gd` and
  `peak_couloir2.gd` from
  `C:\Users\Tenut\zenscape-godot\.claude\worktrees\game-direction-architecture-fe6e13\scratch\`
  into your own `scratch/`. Same views before and after, seed 1.
- Windows are one at a time across all worktrees (`tools/shot.py`'s lock).
  Keep them short: other lanes are queued behind you.
- Prototyping rules: no committed tests, no full suite.

## Cap and budget

The skill's defaults.
