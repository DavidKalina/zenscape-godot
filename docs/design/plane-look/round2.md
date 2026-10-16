# Plane look, round 2: the biplane back, with the craft grime

The plane is the small 1920s biplane again (as it stood before round 1,
commit 2efdd669), in the craft grime the airship got: every paint, cloth and
fitting on `shaders/plane_surface.gdshader` (`shaders/craft_grime.gdshaderinc`
through `folk_surface.gdshaderinc`). The cockpit pilot is still the wanderer.
Prototype round: nothing committed.

## What changed

- `scripts/plane_figure.gd`: restored from `2efdd669^` (the biplane with the
  broken-plane rounds, the plane arc and 5c10fce6 built on it): its geometry,
  `piece`, `damage`, `_split`, the slump onto the lower wingtip, seats,
  `UPPER_Y`/`LOWER_Y`/`STAGGER`/`LOWER_SPAN`. Then, on top of it:
  - The paint: `_paint` makes a `plane_surface.gdshader` material
    (`PAINT_FILL` 1.3, `PAINT_RIM` 0.18, `PAINT_ROUGH` 0.72, `GRIT_SCALE`
    4.5, as the uncommitted monoplane grime had), `_metal` is that paint with
    a sheen, `_finish` sets `wear`, `own` and `shine` per paint from the
    3-column `FINISH` and tarnishes the brass (`BRASS_SHINE_WORN`). The
    biplane's lacquer, clear coat, `RIM_NEW` and `BRASS_METAL` are gone.
    Glass and crazed glass are the biplane's StandardMaterial3Ds as before;
    the gleam and the seat glow are untouched (their uniforms are
    folk_surface's, which plane_surface includes).
  - The palette: the biplane's colours aged (below).
  - Kept from later commits: `PlanePilot.new(outfit, wanderer)` (the
    wanderer when there is no livery), the plain navy scarf tail
    (`_stripes`, `_tail_navy`, from 23e6caa8); livery pilots keep stripes.
  - `PILOT_FIT` 0.8 (was 0.92 inline): the pilot's rig scale is
    `PILOT_FIT * WorldScale.pilot_size`, so his shoulders sit in the slim
    cockpit and the wide brim rides over the upper wing's trailing edge
    instead of over half its chord.
  - Not carried over from the monoplane: `TERRACOTTA`, `CREAM`, `TAN`,
    `CYAN`, `CHARCOAL`, `NAVY`, `GLOW`, `BODY`, `SEAMS`, `SCREEN`,
    `WING_Y`, `WING_Z`, `DIHEDRAL`, `FIN_TALL`, `_body_at`, `_main_wing`,
    the "tan" and "glow" paint keys. No caller outside the file used them
    except `studies/lodestone_study.gd` (`_body_at`).
- `studies/lodestone_study.gd`: the gimbal back on the top wing
  (`UPPER_Y`, `STAGGER`, as before round 1).
- `scripts/sky_traffic.gd`: comment back to "little biplanes".
- Untouched: `scripts/plane_pilot.gd` and its shader, `scripts/soft_mesh.gd`
  and `shaders/plane_paint.gdshader` (the pilot still uses both),
  `scripts/stone_plane_figure.gd`, `scripts/plane_parts.gd`, the airship and
  its shader, `craft_grime.gdshaderinc`, `folk_surface.gdshaderinc`.

## Sizes (toy units; the game draws them at WorldScale.plane)

`scripts/world_scale.gd` untouched. Vertex boxes in the figure's frame,
without the scarf, mark, vapour, prop disc and turning propeller:

| | monoplane (round 1 + wanderer round 3) | biplane (this round) |
|---|---|---|
| plane, no pilot | pos (-0.7, -0.41, -0.76), size (1.4, 0.731, 1.505) | pos (-0.7, -0.41, -0.76), size (1.4, 0.731, 1.505) |
| cockpit pilot | pos (-0.244, 0.097, -0.003), size (0.488, 0.434, 0.488) (rig 0.92) | pos (-0.212, 0.099, 0.028), size (0.424, 0.377, 0.425) (rig 0.8) |
| pilot top | 0.532 | 0.477 |
| upper wing | none | top about 0.328, trailing edge z 0.08 |
| pilot's lowest point over the upper wing's chord | n/a | 0.355 (2.7 cm toy over the cloth) |

Wheel contact -0.41, the tail skid, the span (`SPAN` 1.4, `TOY_SPAN`) and
the seat are as before both rounds.

## Palette

| slot | biplane (2efdd669^) | now |
|---|---|---|
| wood (body) | 8f5234 | 6f4f3d |
| dark (struts, legs, tub) | 6b3b28 | 573a2c |
| trim (cowl, tips, fin, band) | c8643b | a2563f |
| cream (wings, tailplane, rudder) | f3ead6 | c4b596 |
| leather (coaming) | 5e3522 | 4e3428 |
| brass | d6ad62 | b8944f |
| varnish (propeller) | 7a4429 | 663f29 |
| steel (wires, exhaust, tyres) | 3b3430 | 3d3b38 |

The roundels stay, in the dark, trim and cream slots, so they fade with
the rest. Livery colours (`sky_traffic.gd`) are unchanged; the grime's grade
greys them the same way.

## Broken-plane checks

- Throwaway driver `scratch/biplane_parts.gd` (`python tools/drive.py
  scratch/biplane_parts.gd`), on the aqueduct isle's parked plane (the
  PlaneFigure nearest (106.7, 30.7, 12.0)): parked box in its own frame is
  the table's, wheels at -0.41; `set_missing(FOUND)` leaves all six missing,
  slumped not sunk; `set_found` each in turn (90 frames apart) empties
  `missing()`; mended, its world and own-frame boxes equal the parked ones;
  the pilot (fresh figure, `show_pilot(true)`) stays over the upper wing's
  cloth. 8/8 OK, no script errors.
- Stills: broken (all six damage pieces, the right gear folded, slumped onto
  the lower wingtip, dust wear), a find mid-seat (the wheel easing in, the
  ring and the puff), mended.
- Seen in `tools/view_plane.gd`: prop disc, navy scarf, ailerons and
  elevator, the pilot's hat behind the upper wing.

## Stills (git-ignored)

- `scratch/biplane/mended.png`, `scratch/biplane/broken.png`,
  `scratch/biplane/find.png` (broken_plane_gallery, `--plane=3/0`, `--plane=1
  --find=1 --capture-after=1.6`)
- `scratch/biplane/isle_close.png` (`--at 108.2,31.6,9.6 --look
  106.7,31.0,12`), `scratch/biplane/isle.png`, `scratch/biplane/isle2.png`
- `scratch/biplane/view/*.png` (tools/view_plane.gd `--shots`, flying)
- Before: `scratch/restyle/plane_after.png`, `plane_after_broken.png`,
  `a3_plane.png`

## Smoke and tests

Headless import; `tools/smoke.py` aqueduct_isle, broken_plane_gallery,
plane_parts_gallery, lodestone_study: 4/4 PASS.

Tests run (headless): test_aqueduct_isle_plane, test_glide_camera,
test_glide_feel, test_hollow_keel_isle, test_isle_lodestone,
test_kit_isle_landing, test_lodestone_study, test_pierced_isle,
test_plane_arc, test_plane_flight, test_plane_landing, test_ruin_kit,
test_sky_plane, test_sky_traffic, test_world_scale_guard,
test_world_scale_fit pass (test_pierced_isle failed once on its time
budget under 8 jobs, passed alone). test_collision_audit fails on two
DragonTower stones resting on nothing; not plane geometry, and not checked
against HEAD. Full suite not run.

## Model budget (docs/art/model-budget.md)

Counts from a throwaway (`scratch/biplane_tris.gd`): biplane 4,502
triangles in 14 draws (joined per material); the grime monoplane was 16,624
in 14. The cockpit pilot is 37,924 (the walker's head and hat lifted off
pilot.glb), eight times the plane.

- **Import LODs / visibility ranges:** applies, mostly to the pilot. A
  generated LOD of his lifted head and hat (~38k to ~4k past a few metres)
  saves ~30k triangles per plane in the chase view and more for the sky's
  traffic (livery pilots use the folk's faceted head, already small). Plane
  itself: a visibility range dropping the wires, rivets and louvres for
  distant traffic saves ~1.5k triangles each. Frame time: well under
  0.1 ms per plane on this GPU either way; worth it for traffic counts.
- **Vertex-colour grime:** applies. The grime is computed per pixel in
  `craft_grime` (four noise calls a fragment); baking the washes and the
  underside dirt into vertex colours would cut that to the fine grain, at
  no triangle cost. Estimated saving small (~0.05 ms at 1440p with the
  plane filling the view).
- **Silhouette geometry:** already how it is built: torn cloth, the bare
  engine and the snapped spars are real geometry; nothing to save.
- **Sculpt high, bake low; parallax depth; rigid parts on bones:** do not
  apply (no sculpt, no textures or UVs, no skinning).

## Follow-up: the cockpit pilot

`scripts/plane_pilot.gd`: the walker's hat in the cockpit has its brim
drawn in (`_trim_brim`: points past `CROWN` 0.11 from the head's axis come
in to `BRIM_FIT` 0.5 of their reach, so the brim's reach goes from 0.22 to
about 0.165, head frame; crown and band unchanged), and its felt is
`HAT_FELT` #8C4A37 at `HAT_FILL` 2.2 (the walker's own hat on foot is
unchanged). His coat, scarf and mitts take the walker's worn colours
(NAVY #3B4A6B, JACKET #534739, MITT #6C4632) on `shaders/plane_surface.gdshader`
with the craft grime (`GRIT` 0.7, `GRIT_SCALE` 9); the scarf's tails
follow NAVY (the stone plane's too). Stills: `scratch/biplane/hat2/`.
