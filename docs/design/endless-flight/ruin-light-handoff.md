# Ruin lighting round: handoff

The first round from the model audit (`docs/art/model-audit.md`,
recommendations 1 and 2): code only, no Blender. Every RuinKit piece is
affected (set pieces, bridges, land arches, halls, rival gates).

## What changed

- **Sky seen, baked per vertex** (`scripts/ruin_ao.gd` `bake`, called in
  `RuinKit.Build.finish` on the builder's thread). The piece's triangles
  are stamped into a 0.7 m grid. Seven short rays (out to 5 m) leave
  each vertex round its normal, and rays below the piece's ground count
  as blocked. The vertex colour is darkened by up to `STRENGTH` 0.7.
  This is the "vertex-colour grime" trick from `model-budget.md`: the
  stone's shade light is emission, which SSAO can't darken, so it has to
  go into the colour.
- **Rounded chamfers** (`ruin_ao.gd` `soften`). Faces under 0.16 m across
  take at each corner the mean of their own normal and the normals of
  the faces meeting there, so the light runs across an arris instead of
  drawing a hard line. Wide faces stay flat.
- **A brightness ceiling on the stone** (`shaders/folk_surface.gdshaderinc`,
  `stone_knee` 0.3 / `stone_cap` 0.48, on every `ZS_STONE_WEATHER`
  shader: ruin, gothic and tunnel stone). The Amberlands lift (sRGB 3.0,
  about 13x linear) put the bare stone between the moss above an albedo
  of 1, and it blew out to white.

Flags: `--ruin-ao=0` (off) or `--ruin-ao=X` (strength), `--ruin-soft=0`,
and `--ruin-ao-log` (prints each bake's and soften's cost). The ceiling has
no flag; set `stone_knee` to 0 to turn it off.

## What it looks like

Stills were taken in the Amberlands at seed 1 (`scratch/audit/cmp_ao*`,
before on the left; driver `scratch/sets/sshots.gd`, mode `near`).

- The nave's ledges, wall feet and buttress returns read deeper.
- The colosseum's ambulatory has a gradient instead of one flat slab.
- The pale blotches are toned down: the 99th-percentile pixel on the
  colosseum steps went from 250 to 234.
- The change is modest. The blotchy look comes from the moss paint
  itself (cream bare stone between olive moss) and from the lack of
  block-scale detail. That's the material round: audit recommendation
  3, a Blender stone material.

## Cost

Build time on worker threads, not frame time. Over one Amberlands run's
81 pieces, the bake took 6.4 s and the softening 1.3 s in total. The
largest pieces (100-160k vertices) take about 1.1 s longer to appear.
Moving the bake into the native kernel would remove most of that if it
matters.

## Checks

- Smoke PASS, 0 errors: default, `--world=amberlands`, `--world=regions`.
- `tests/test_ruin_kit.gd`: already failing before this round (48 FAILs on
  the round-2 pieces, in 160 s). It now also **times out** at 180 s from
  the extra build time. Lock-in round.
- Not seen in stills: the default world's halls and tunnels (they take
  the bake and the ceiling too).

## Open

- The bright yellow shards on the colosseum ambulatory's wall and the
  plank-looking vault underside are still there (audit item 7).
- Next per the audit: the Blender stone material (3), then ivy cards (4).
