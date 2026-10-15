# The ruin kit, weathered

Ask: reskin the ruin kit's stone to match the Olmec's weathered basalt
(`olmec-weathered.md`), so the ruins and the Olmec read as one stone. Surface
only: no change to shapes, collision, sizes or the generator's layout.

## What the kit carried
- Kit stone is `shaders/ruin_stone.gdshader`, which is `folk_surface.gdshaderinc`
  coloured by the vertices. It is one shared material (`RuinKit.Build.materials().stone`,
  dressed by `RuinStoneStyle.dress`), which `pierced_mesh`, `way_lights`,
  `start_spot` and the night lights duplicate.
- The kit's vertex COLOR.rgb is the face's tone (`RuinStoneStyle.shade`).
  COLOR.a is the halls' **shelter** (1 open air), not an occlusion.
  There are **no UVs and no rest position**.
- The stone stands still, so the piece's own model space serves as its rest pose.
  I added no new mesh data.

## What changed
- New `shaders/kit_weather.gdshaderinc`: the Olmec's weathering, fitted to the
  kit. `folk_surface.gdshaderinc` calls it under `ZS_STONE_WEATHER`, which only
  `ruin_stone.gdshader` defines. The layers:
  - broad washes at two scales (a wall's length, then a block's),
  - rain streaks down the upright faces,
  - light and dark flecks and pits,
  - sparse cracks,
  - worn high points made paler and chipped: the tops, plus the faces the
    eroded look tipped between a top and a side (its worn arrises and chips),
  - grime under the overhangs, in the halls' shelter and at the feet of the streaks,
  - dry lichen blooms on the tops.

  With no baked occlusion, crevices are read from the facing (undersides) and the shelter.
- Pixel-footprint fades work as on the Olmec (fine, mid and far). Grain and
  cracks are gone once a pixel is a hand across, so whole isles stay calm.
- Cost: at most two cellular lookups a pixel (the Olmec takes four). Each one
  runs only where its mask is on and near enough to see: cracks where the crack
  mask runs, chips only on worn high points. Everything else is value noise.
  The rendered bench (`tools/bench_run_layer.gd`, sprawl 1, 1080p, RTX 4070 Super)
  measured GPU ms smooth → weathered of spawn 4.81 → 4.89, gulf 3.57 → 3.26,
  mid 4.67 → 4.70 and next 2.89 → 2.52, all within noise. The kit's own share at
  spawn went from 0.47 to 0.53 ms.
- The knob is `--kit-stone=weathered|smooth|<0..2>`, weathered (1.0) by default.
  `RuinStoneStyle.weather()` reads it and `dress` sets the `stone_weather`
  uniform. `RuinKit` re-dresses when the look or the amount changes.
  The shader's default is 0, so other users of `ruin_stone.gdshader` that build
  their own material (`stone_plane_figure.gd`) keep the old look.
- The uniform is called `stone_weather`, not `weather`, because `Style.dress`
  also dresses the Olmec's material, which has its own `weather`.

## See it
- `studies/inhaler_isle.tscn`: the Olmec and the kit side by side.
- `studies/run_layer.tscn -- --shape=sprawl --seed=1`
- `studies/motif_yard.tscn -- --motif=bell_spires --sky`
- Add `--kit-stone=smooth` to any of them for the old look.

## Captures (gitignored `captures/kitstone/`)
- `sheet_inhaler_isle.png`: smooth | weathered, close on the Olmec and the
  cover pieces, then along the aqueduct wall.
- `sheet_layer_yard.png`: the layer at gameplay range before | after, then the
  bell spires in the yard.
- Other stills are in the same folder: `before_*`, `smooth_*`, `weathered_*`,
  `after_*`, `w2_*` and `weathered_c17_close` (the Olmec and the wall together, very close).

## Verified
- Headless smoke with no errors: `inhaler_isle`, `headless_body_isle`,
  `aqueduct_isle`, `motif_yard` (bell_spires, both looks), and `run_layer`
  sprawl 1.
- `test_ruin_floating`, `test_ruin_growth` and `test_ruin_kit` pass headless.
  These tests check the material's identity, which is unchanged. No test breaks.
- The shader compiles in Forward+ (all rendered stills, 0 errors). I judged it
  by eye at gameplay range, mid range and close.
- I couldn't check shimmer in motion from stills. The fades are the Olmec's.

## Open questions
- The amount: walls now carry clear cracks and stipple close up. 0.7–0.8
  (`--kit-stone=0.75`) would calm it if it reads busy in play.
- The cracks run straight across block joints, because they are painted and
  know nothing of the blocks. Per-block cracks would need a block id in the mesh.
- Lichen is ochre-green on the wall heads. It sits alongside the kit's own moss
  and ivy growth, which is unchanged.
- The isles' cliff rock (`KitLook` rock, faceted blue-grey) and the earth sides
  are still flat. Next to weathered stone they now read cleaner than the ruins.
  That could be a follow-up.
- The stone plane figure (`stone_plane_figure.gd`) uses the kit shader with its
  own material, so it stays smooth for now.

## Round 2: the isles' rock
Ask: the isles' rock walls read too simple next to the weathered ruins. Make
them grittier and keep the grass as it is.
- The rock is `shaders/reference_surface.gdshader`, the world's shared terrain
  shader, used through two KitLook materials: `rock_material` (earth sides and
  keels, colours painted per face) and `ground_material` (turf, whose steep
  bare faces are rock). It now includes `kit_weather.gdshaderinc` and weathers:
  - every earth-side face,
  - the ground's faces that are both not grass (`zs_ground_grassness`) and
    steep (world normal y under about 0.55 to 0.8).
  
  Rest is the isle's own frame, `rock_grain` 0.6 (coarser than the stone).
  `stone_weather` is 0 by default, so every other user of the shader is unchanged.
- Rock is bolder than the stone (`KitLook.ROCK_GRIT`): washes and flecks ×1.6,
  rain streaks ×1.8 and cracks ×1.6, through the new `weather_tone`,
  `weather_streak` and `weather_crack` uniforms (1 on the ruin stone). Its
  facet light and dark spread (`side_facets`) eases to 0.6 of FACETS, so the
  grain carries the face rather than the triangles.
- The knob is `--kit-rock=weathered|smooth|<0..2>`, separate from `--kit-stone`.
- Cost (same bench): GPU ms smooth → weathered of spawn 4.94 → 4.98,
  gulf 3.62 → 3.78, mid 4.80 → 5.13 and next 2.57 → 2.70.
- Sheet: `captures/kitstone/sheet_rock.png`, before | after for the tier cliff
  close, the tiers and the keel from the side.
- Checks:
  - Smokes clean: inhaler_isle, aqueduct_isle, motif_yard.
  - The main world (`studies/zenscape.tscn`) renders with 0 errors.
  - Not verified: the shader compiling on Metal or the Mac. reference_surface is
    at the Metal varying limit; this adds no varyings, only uniforms.
- Suite: the full run was cut off at test 19 of 320. These failed, and still
  fail when run alone:
  - `test_collectibles_pickup`: non-finite Control size.
  - `test_trap_seesaw`: landing. Fails the same way on clean HEAD.
  - `test_sundered_hall`: streaming timing.
  - `test_motif_families`: colonnade_spine and broken_ring isle hashes.
  - `test_isle_loop_played`, `test_lower_world`, `test_run_layer`,
    `test_layer_sprawl`, `test_sky_world`, `test_serpent_route`,
    `test_moments_world`, `test_scene_picker_entries`: not checked one by one.
  
  All of these are gameplay, geometry or timing checks, which a material
  change can't move. I couldn't get a clean baseline for the others: a fresh
  HEAD worktree fails them differently while its import is incomplete.
- Open: the keels are navy because down-facing faces take the sky's blue
  bounce, not because of the rock colour. They are weathered now but still
  read blue.
