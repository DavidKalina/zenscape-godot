# Watercolour meadow: the high ground as washes, not a rug

What changed (`shaders/endless_ground.gdshader`, ground/carpet part only; no river code touched)
- From height over ground `high_paint_alt` (now 20..75 m, was 35..120) the turf melts the small
  patches (tuft/fine/mid/clump) to its broad-scale colour, then lays domain-warped washes:
  yellow-green / cool blue-green / olive pigments that bleed into each other, darker pooled wet
  edges where washes meet, pale paper-light crowns, deeper cooler pools in low washes, pigment
  collected along river banks. Carpet speckle, wind sheen (-85%) and the painted flower dots are
  gone there; flowers become soft low blooms (38 m blobs).
- The near-tuft "under" paint is faded out with altitude too (it drew a ring round the eye that
  showed against the washes).
- Knobs (shader uniforms, set from the command line with `--sheen-set=NAME=v`): `wc_paint` (1;
  0 = off, the old high-ground look), `wc_scale` (170 m), `wc_edge` (0.5), `wc_paper` (0.5),
  `high_paint_alt`. Example: `--sheen-set=wc_paint=0`.
- Not done: forest-edge darkening (needs the flora mask); far tufts' colour (tufts are gone by 80 m).

Captures (seed 2, heading 200, altitude 60/150/300; `captures/wc/`, git-ignored): `pair_150.png`
(before on top, after below), `pair_60.png`, `pair_300.png`; singles `before_s2_*.png`,
`after_s2_*.png`. `before_s2_15.png` / `a8_s2_15.png`: near view still tufted.

Smoke: endless_flight.tscn PASS. Renders showed no missing ground. No tests touched.
