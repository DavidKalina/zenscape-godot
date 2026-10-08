# Ruin kit: handoff

Branch `look/ruin-kit-ext` (from `look/ruin-kit-gothic`). Not merged.

The user's verdict so far: the aqueducts are "amazing". The halls "have potential" and should become long halls you weave through. No glowing ornaments: the mask, the floor medallion and the glyph stone were removed. What the kit is for: big lower-world landforms full of halls and aqueducts, set into real terrain.

## What's built

| Family | Script | Pieces (`RuinKit.piece(id, seed, weathered)`) | Builder |
|---|---|---|---|
| Gothic abbey | `scripts/ruin_kit.gd` | 12: pier, arch, lancet_wall, rose_gable, buttress, wall, stairs, turret, vault, fallen_pier, tomb_chest, floor | none |
| Aqueduct | `scripts/ruin_kit_aqueduct.gd` | aqueduct_span, _two_tier, _broken (spills a crafted fall into a pool), _stump, _end (stepped abutment, cistern, arched mouth) | `run(seed, w, count, break_at, with_head, ground, merged)` |
| Colossus hall | `scripts/ruin_kit_hall.gd` | hall_column, hall_beam, hall_slab, hall_bay | `hall(seed, w, bays, ground, merged)`, planned by `plan(rng, w, bays)` |

- **Every piece:** a Node3D with "Mesh" (one vertex-coloured surface, `shaders/ruin_stone.gdshader`) and "Body" (a StaticBody3D of convex hulls).
  - Its foot is at y 0 and its front faces +Z.
  - `weathered` runs from 0 (centuries old, never new-built) to 1 (romantic ruin).
- **Building:** every block is one convex solid cut from planes (`Build.solid`). Wear, chips, moss, ivy and tufts all live in `Build`.
- **Water:** the channel and pools use the islets' pond water (`shaders/islet_pond.gdshader`). The broken span's spill is the waterfall strand (`SkyIslets.curtain` with `shaders/flow_fall.gdshader`).

### Hall layout

The hall runs along +X, with bay lines BAY (8 m) apart.

- **Columns:** outer rows at z ±ROW_Z (9.4). Inner columns are staggered, at z ∈ {-2.6, 0, 2.6}, sometimes in pairs (narrows).
- **Ties:** low ties (soffit 4.0) and high ties (soffit 6.0) at bay lines.
- **Fallen beams:** they lie across the left of the nave and act as 30° ramps up onto the low ties.
- **Roof:** six slab strips per bay. Gaps are open nave strips you can fly out of and back in through.
- **Screens:** walls at some bay lines carry knife-edge slits, 1.15 × 3.3 m.
- **Walls and buttresses:** side walls with lancets. Outside, a stepped buttress near each end climbs to the roof.
- **The generous line:** the LANE (z 4–8, y 1.0–3.6 over the floor) is always clear from end to end. Every tighter line is optional.

## Contracts (for a layout pass)

- **`ground`** is an optional `Callable(x, z) -> y` in the builder's frame. Without it, the ground is flat at y 0.
  - Aqueduct decks stay level. Piers grow down to the ground plus FOOTING (0.6 m below it), so across a valley the middle piers are tall and the end piers short.
  - The head's abutment steps down into the hillside; treads that are buried get dropped.
  - Hall columns get a foundation (1.2 m) and walls start below grade. A hall run into a hill gets buried there, its lane is cut short, and the far mouth is marked `open: false`.
- **Metadata** on each piece, run and hall, in its own frame:
  - `bounds` (AABB)
  - `feet` (Vector3s that sit below the ground)
  - `walk` (Array of `{from, to, width}`)
  - `corridors` (AABBs where terrain and props must stay out: the arch corridors, the hall lane)
  - `ends` (`{at, heading, height, kind|open}`): the connection points used for chaining hall → aqueduct → hall
  - halls only: `weave` (low/high ties, fallen beams, gaps, slits, narrows), `plans`, `length`
- **Cost:**
  - Runs and halls are merged into one mesh and one body (`RuinKit.merge`); water and the spill stay separate nodes.
  - `RuinKit.set_detail(0..1)` thins ivy, moss, tufts and rubble; the stone and the collision never change.
  - `RuinKit.triangles(node)` counts triangles.
  - Measured triangle counts:

| Build | Detail 1 | Detail 0 |
|---|---|---|
| Weathered aqueduct span | ~44k | 11k |
| Weathered hall bay | ~100k | 48k |
| Weathered hall column | 25k | 3k |
| 12-bay long hall, weathered 0.6 | ~820k | ~470k (all stone) |
| 12-bay long hall, weathered 0 | 590k | ~470k |
| Run of head + 4 spans, weathered 0.6 | 145k | 44k |

- **Jolt:** hulls thinner than HULL_THIN (6 cm) are skipped. Wear may never grow a block past its unworn extent.

## Scale and clearance

These come from `scripts/pilot_motor.gd`, `scripts/plane_figure.gd` and `scripts/sky_glide.gd`. All are pinned in `tests/test_ruin_kit.gd`.

| Constant | Value | Origin and use |
|---|---|---|
| STEP_UP | 0.45 | Step height. Parapets (0.42), plinths and paving sit under it. |
| GRAB_TOP | 1.875 | One jump catches this. SET_OFF 1.6 for treads and buttress steps. |
| CHAIN_TOP | 2.625 | A jump chain catches this. |
| STAND | 0.58 | Minimum depth of a tread or ledge. |
| TOP_ROOM | 1.16 | Width of a walkable top. Channel 1.5, beam tops 1.7. |
| THREAD | 3.5 | Plane span (1.4) × 2.5, for any corridor meant to be flown. Aqueduct arches clear 4.7 m. |
| Hall LANE | 4 m wide | Over THREAD; runs end to end. |
| KNIFE | 1.15 wide | Wider than the plane on its wingtip (~1 m), narrower than its span (1.4). A level plane cannot pass. |

## Gallery

```
./run-ruin-kit.command [--family=hall] [--centre] [--fly[=seconds]] [--night] [--no-shafts]
godot --path . res://studies/ruin_kit_gallery.tscn -- --no-title --capture=out.png [--at=x,y,z --look=x,y,z]
```

- **Layout:** hall | gothic | aqueduct. The aqueduct area has its run over water and, behind it, a run across a valley. The hall area has the 12-bay long hall and, behind it, a hall run into a hillside.
- **Keys:**
  - F1, F2, F3: frame a family. 1–9: a piece. C: the centrepiece. Space: the whole layout.
  - W: intact/weathered. R: reseed. N: night. L: shafts.
  - G: fly mode.
- **Fly mode** uses the game's SkyPlane, PlaneFigure and GlideCamera with the game's input actions (`Pad.ensure()`).
  - Controls: A/D bank, W/S pitch (W is nose down), the mouse steers, Space boosts, Shift brakes, Q/E barrel roll, hold right mouse to look round, G or Esc exits.
  - Hitting stone bumps and recovers: a sphere query backs the plane out along the face, turns it along the face and costs speed. It never crashes.
  - `--fly=N` flies an autopilot down the lane for captures.
  - There is no knife-edge lean on this branch (it lives on another branch).
- **Shafts:** a FogVolume fills only the long hall's interior, with ambient inject 0 and the sun's `light_volumetric_fog_energy` set. This gives crisp beams through the gaps and lancets.

## Known issues

- **The hall is very dark inside.** The mood is right, but the stone reads close to black. It needs a little bounce or ambient in the interior.
- **The hall reads plain from outside:** a long walled barn. Its flat roof slabs read as too clean, and the roof moss is blotchy.
- **Floating fragments:** snapped buttress pinnacles and gablets can float above walls, visible in the hillside demo.
- **The terrain demos are crude:** a block of faceted ground with sheer sides.
- **Fly mode is barely tested:**
  - One `--fly=5.5` capture came back with the plane out over the clouds at night; I didn't track down why.
  - Bump response is untested by hand. The autopilot's signs were found by trial.
  - The plane's skim uses the plate as its ground, not the ruins' tops.
- **Weave routes are untested in play:** routes on foot (fallen-beam ramps, tie tops, the buttress stair to the roof) and the slits are checked only as geometry.
- **Cost:** the long hall's stone alone is ~470k triangles. Walls and paving are the bulk; there is no LOD yet.
- **Captures sometimes hang:** a rendered capture hung once (killed after 150 s, then fine on a retry).

## Next steps (prioritised)

1. Fly the hall by hand. Tune bump feel, lane width, tie heights and roof-gap pop-outs; make the plane skim the ruins' tops.
2. Interior light: a touch of ambient or bounce in the hall so the carving reads, keeping the shafts crisp.
3. Hall exterior and roof: break the long walls (buttress rhythm, collapsed stretches) and give the roof more ruin.
4. Cost: drop hidden faces (wall cores, foundation tops, paving undersides) and add a far LOD (merged, detail 0, fewer chamfers).
5. Feed the metadata to a landform layout pass (scripts/landforms.gd, the SkyIslet recipes) and chain hall → aqueduct → hall over real terrain.
6. Fix the floating pinnacle and gablet fragments on snapped buttresses.
