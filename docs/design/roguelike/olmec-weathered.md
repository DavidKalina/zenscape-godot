# The Olmec, weathered

Ask: the hovering stone inhaler head and its detached body read smooth; make them weathered and grainy, as one figure.

## What changed
- New `shaders/olmec_stone.gdshader`: the kit stone's lighting (hemisphere emission, Lambert) plus a painted weathering in solid noise over the model's REST pose: broad light/dark washes, rain streaks, stippled flecks and pits (with a small normal nudge), sparse cracks, chipped pale high points, grime in crevices and undersides, and a hint of dry lichen on sheltered tops. Fine layers fade with pixel footprint (no shimmer at distance); washes, streaks, cracks and flecks carry it at gameplay range. Knobs: `weather` (0 = the old smooth stone, up to 2), `bump_strength`.
- `scripts/enemies/inhaler_head_look.gd`: `stone_material()` (one shared material for head and body); `_dressed` now writes the rest position into UV/UV2 (so grain rides on the skinned body) and the baked occlusion into vertex alpha.
- `scripts/enemies/headless_body_look.gd`: uses `HeadLook.stone_material()`.
- No change to Blender scripts, glbs, rigs, clips, sizes or collision. No new geometry.

## See it
`./run-headless-body.command` and `./run-inhaler-head.command`.

## Captures (gitignored `captures/olmec/`, in the worktree)
`before_*` and `after_*` for head (gameplay, close, side) and body (gameplay, close, side). Taken in game with a throwaway camera-follow study (deleted).

## Verified
Headless import; `headless_body_isle` and `inhaler_isle` each run 400 frames headless with no script or shader errors. Judged by eye in rendered captures. No tests run or added; no existing test was touched (a test that asserts the stone material is the kit's would break, none known).

## Open questions
- Is the amount right? It is bold on purpose to read at distance; `weather` 0.6-0.8 would calm it. The head's blocky chip cells and the body's dark pit speckle are the busiest bits.
- The head sits in the warm aqueduct light and the body in the grey greybox light, so they look differently tinted in the studies; the stone itself is the same.
- Lichen is subtle; no real geometric chipping at block edges (texture only).

## The rune serpent wears it too (look/serpent-olmec)
- `scripts/rune_serpent.gd` builds its body with `shaders/olmec_stone.gdshader` (its own material, `runes` on), at the Olmec's amount (`weather` 1.0, `bump_strength` 0.8). Its own fill and rim stay (1.6, 0.4: the sky folk's rule, so it reads against the sky).
- The mesh now carries what the Olmec's does: the rest position (x, y round the ring, metres back from the snout, times GRAIN 0.75, a little coarser than the Olmec's grain for a creature seen at range) in UV/UV2, and an occlusion in the colour's alpha (by where a corner sits round its ring: belly 0.5 to back 0.98, give or take 0.1). The rune data moved to CUSTOM0/CUSTOM1.
- The runes (spine line, flank bands, collar, brow sigil), eyes, mouth and tongue moved from `shaders/rune_serpent.gdshader` (deleted) into `shaders/rune_serpent_runes.gdshaderinc`, which the shared shader includes. Behind the `runes` knob (off by default, so the Olmec is unchanged), they are cut into the weathered stone as lit grooves: the groove darkens the stone round its light, dents the normal (`rune_cut` 0.6), and keeps lichen off; their light is added on top unchanged. Eyes, mouth and tongue stay smooth (no weathering).
- No change to its geometry, skeleton, motion or capsules.

### The serpent's eyes, round 2
- Covered and one distorted: each eye was a flat quad stood 0.05 m off the head's face between its jowls and brow, but that face is not flat (its brow corners raised) and quad() splits it along a diagonal that runs one way on the left and the other on the right. So the left eye's quad (face 1) went through the stone: its middle 3 mm under, a corner 5 cm under, the stone cutting across the almond; the right (face 7) stood 0.04-0.15 m clear. Both were also a dark parallelogram on the new busier stone.
- Now the eye is a 10 x 8 grid laid 3 cm over the face's own two triangles (`_eye_patch`), with their normals, tone, occlusion and grain rest, so outside the eye it is the face; its square runs back to front and foot to brow the same on both sides.
- It is carved as the Olmec's (`rs_eye`): an almond eyeball of the Olmec's pale polished stone (EYE_STONE, roughness 0.35), set back, swelling, darker under a heavy upper lid that droops at its back corner, a thin lower lid, a dark crease round both. No slit pupil. Its light is the Olmec's lock-on: a faint warm glow at rest (0.3 by day, 1.2 at night), lit to the Olmec's 3.2 (albedo warmed half way to the glow) while it watches or paces you, eased over 0.6 s; the haze round it follows (0.04 day, 0.35 night, +0.3 lit).
