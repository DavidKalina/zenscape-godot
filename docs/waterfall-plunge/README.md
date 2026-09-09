# Waterfall plunge

Every authored waterfall now lands with three things, built by
`scripts/waterfall_plunge.gd` as a child of the fall mesh so the falls node
still holds exactly one mesh and one spray per waterfall:

- **Droplet spray.** A `GPUParticles3D` burst at the landing point: 24–64
  spheres depending on flow, thrown upward in a 55° cone at 1.4–3 m/s (scaled
  by the fall's size), under gravity, fading from foam white over 0.8 s.
- **Foam blobs.** Bobbing white icosahedron-style blobs following the source
  app's `foamCluster`: count 4+3·flow, ring radius (0.35..1.25)·spread with
  spread 0.5+0.5·flow, size (0.12..0.30)·(0.7+0.25·flow), resting 0.04 m above
  the water and bobbing by |sin(2t + 1.7i)|·0.08 m.
- **Ripple rings.** When the fall lands in a pond, four rings roll outward from
  the plunge on a 1.15 s cycle using the shared `drip_ring` shader. Dry landings
  get spray and foam only.

Flow is `clamp(scale·0.5, 0.2, 1)` from the waterfall record's scale. Pause
holds the spray and the animation. The receiving pond's splash pool now holds
16 rings so blast debris, thrown props and the resident can all splash at once.

Not done yet: the spray does not lean with the wind field, and the imported
reference waterfall in the fidelity scene keeps its original mist only.

Validation: `tests/test_waterfall_plunge.gd`; debris splashes are in
`tests/test_debris_strikes.gd`.
