# Plane look, round 1: the sheet's monoplane

Reference: the character sheet's "Fly in a plane" shot (wanderer-proto.png,
bottom left). The 1920s wooden biplane is now a chunky toy low-wing
monoplane, painted and rounded, not faceted, with the wanderer in the
cockpit drawn as the sheet's chibi.

## What changed

- `scripts/plane_figure.gd`: the shapes and the paint.
  - One low wing (`WING_Y`, `WING_Z`, a little `DIHEDRAL`), broader and
    thicker, rounded tips, a finer airfoil. The upper wing, struts, wires,
    cabane, roundels, louvres and exhaust stacks are gone.
  - A fat round cream fuselage (`BODY`), three tan panel seams with rivet
    rows, a cream tub and turtle deck, a brown coaming.
  - The cowl: a cream drum, a charcoal lip with the cyan ring glowing in it
    (emissive, `GLOW`), a dark face, rivets. Terracotta spinner, two broad
    wooden blades.
  - Fixed fat round tyres (torus) on two short brown legs from under the
    wing, cream hubs with terracotta caps. The gear's lost-wheel damage is
    the leg buckled with a bare stub axle.
  - Terracotta fin and rudder with rounded edges, the wanderer's hat on both
    sides of the fin in cream with a brown band; terracotta tailplane.
  - Smooth and painterly: every mesh goes through the new
    `scripts/soft_mesh.gd` (Catmull-Rom eased hulls, smooth normals under a
    crease angle, tori, bevelled slabs, all cached by their arguments). The
    paint is the new `shaders/plane_paint.gdshader`, a sibling of
    `pilot_paint.gdshader`: toon bands, warm light, cool shade, mottle and
    streaks laid in mesh space (no UVs needed), a gentle rim, no gloss.
    Wear (dust, fade, scuffs), the mended gleam and a soft painted
    highlight for metal (`shine`) are in it. The damage pieces (torn skin,
    shards) stay crisp on purpose.
  - Public API unchanged: `piece`, `damage`, `paints`, `PAINT_COLOURS`,
    `SEATS`, `FOUND`, `set_wear`, `set_missing`, `set_found`, `park`,
    `show_pilot`, `twitch_prop`, the control surfaces. The paint keys are
    the old ones ("wood" = body, "cream" = wings), plus "tan" (seams) and
    "glow" (the cowl's ring; a livery may pass `glow`). `UPPER_Y`,
    `LOWER_Y`, `STAGGER` and `LOWER_SPAN` are gone (only
    `studies/lodestone_study.gd` used them; its gimbal now sits on the nose).
- `scripts/plane_pilot.gd`: `PlanePilot.new(outfit, wanderer := true)`. The
  wanderer is soft and painted: a big round dark head (`WANDERER_HEAD`
  1.45, as wide as the shoulders), two cyan pill eyes that blink every 2 to
  5.5 s (sometimes twice), the terracotta wide-brimmed hat with a brown
  band (brim about twice the shoulder width), two chunky navy scarf rings
  and a knot, a charcoal coat, brown mitts. Springs, leans, glances and
  waves unchanged. A livery's pilots (`sky_traffic`) keep the folk's
  faceted cap and goggles. The rig's scale is unchanged
  (0.92 * WorldScale.pilot_size); the bigger head is inside it.
- The trailing scarf is navy and plain for the wanderer (the stone plane's
  too); livery pilots keep their colour and pale stripes.
- `scripts/sky_traffic.gd`, `scripts/plane_parts.gd`: comments only.

## Sizes (toy units; the game draws them at WorldScale.plane, 2.0)

`scripts/world_scale.gd` is untouched. AABBs of the figure's meshes in its
own frame, without the scarf, mark, vapour and prop disc:

| | old biplane | new monoplane |
|---|---|---|
| plane, no pilot | pos (-0.7, -0.41, -0.76), size (1.4, 0.731, 1.505) | pos (-0.7, -0.41, -0.76), size (1.4, 0.731, 1.505) |
| cockpit pilot | pos (-0.134, 0.099, 0.151), size (0.267, 0.371, 0.180) | pos (-0.255, 0.097, -0.015), size (0.510, 0.526, 0.510) |
| whole | size (1.4, 0.880, 1.505) | size (1.4, 1.033, 1.505) |

Span, length, height, wheel contact (-0.41), the tail skid, the seat and
the collision constants (`SPAN`) are as before; the fin is drawn
`FIN_TALL` taller so its top stands where the upper wing's did. The pilot
is taller and wider than the old one by his hat: the hat's top is about
0.15 (toy) over the old cap's, and the brim reaches 0.25 each side. Nothing
collides with the pilot, but `WorldScale.TOY_TALL`'s comment ("the upper
wing's top") is now stale; left alone as asked.

## Palette (as the sheet)

terracotta #C9644A (wings, tail, spinner, hat), brown #5A3A2C (legs,
coaming, hat band, mitts), cream #E9DFCB (fuselage, cowl, fin emblem, hubs),
tan #D9BC9C (panel seams), navy #2E4FA3 (scarf), cyan #5FE6E6 (cowl ring,
eyes, emissive), charcoal #4A4848 (cowl lip and face, tyres, rivets, coat).
Prop wood #8A5636 and the head's dark #33251F are not on the sheet's
swatches.

## Still differs from the sheet

- The sheet's fuselage is shorter and stubbier; the length was kept for the
  footprint, so it reads longer.
- Rivets are small dark dots; the sheet's are subtler.
- The cockpit has no visible seat back or instrument detail; the wanderer's
  coat has no strap, belt, bracelet or cape.
- The cream reads cool and grey in tools/view_plane.gd's plain sky; it
  reads warm in the game's light. The paint's `fill`/`cool`/`sun` were
  tuned by eye only on those two.
- The found parts' hovering "piece" style (plane_parts.gd) draws them pale
  in its own glow material, so the new paint barely shows there.
- Livery planes and the stone plane's scarf: the stone plane's trailing
  scarf is navy but still striped.

## Checks run

Headless import; headless loads of studies/zenscape.tscn,
studies/plane_parts_gallery.tscn, studies/broken_plane_gallery.tscn and
studies/lodestone_study.tscn (one zenscape run printed one error line that
did not repeat on two reruns). Tests: test_plane_*, test_sky_plane,
test_sky_traffic, test_world_scale_guard/fit, test_glide_camera,
test_glide_feel, test_isle_lodestone, test_collision_audit, test_ruin_kit,
test_kit_isle_landing, test_aqueduct_isle_plane, test_hollow_keel_isle,
test_pierced_isle, test_manual_landing_game: all pass (two with the known
exit_leak). Full suite not run.

Captures (gitignored, in the worktree): captures/plane-look-before/ and
captures/plane-look-after/ (tools/view_plane.gd's five views, plus
broken-row.png, broken-close.png, parts-gallery.png).

## Next steps

- Judge in the game's chase camera at speed and at night (the cyan glow);
  tune the paint's `fill`, `cool`, `sun` against the on-foot wanderer once
  his paint settles, so the two match side by side.
- A shorter, stubbier fuselage if the footprint may change.
- Coat details from the sheet (strap, bracelet glow) once the on-foot
  wanderer's are final, so the cockpit pilot borrows them.
- The parts' hovering style could take the plane paint.
