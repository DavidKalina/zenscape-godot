# Fire, round 1: real flames

Ask: a really good fire for torches, bonfires and flames in general, gritty and slightly realistic. The old campfire flame (`shaders/campfire_flame.gdshader`) is deliberately toon-banded card art and is left alone. This round is a new, shared fire.

## What it is
- `shaders/flame_volume.gdshader`: a flame as a volume. It is drawn on the back faces of a unit box and marches the view ray through it (22 jittered steps), summing a teardrop of fire torn by three scales of rising noise. Licks break off the tip, and the colour comes from heat along a blackbody ramp: dark red, orange, gold, a cream heart. It stops at the scene's depth, so logs and stone inside it occlude correctly. It reads as fire from any angle, including the high play camera. Additive and unshaded: **its colour goes in ALBEDO**, because EMISSION is ignored in unshaded shaders (the first build drew nothing for that reason).
- `scripts/flame.gd`: one node per fire with `kind` torch, brazier, bonfire or candle (KINDS: the flame volumes with offsets, sizes and seeds; turbulence; the light's reach and day/night strength; sparks; smoke; shadows), plus `scale_by`, `wind` and `night`. It also builds round warm sparks (GPUParticles3D), a faint grey smoke from the bigger fires, and one flickering OmniLight3D set above the fuel so the logs don't shadow it.
- `studies/fire_study.tscn` (`run-fire-study.command`): a bonfire in a stone ring, a stone brazier, two torches on posts and a candle on a block, on the aqueduct isle's turf. `--phase=0..1` sets the time of day (0.45 day, 0.9 night) and `--fire-wind=x,z` leans the flames. Its props are plain stand-ins, so the fire is what gets judged.

## Verified
Headless smoke of `studies/fire_study.tscn` passes. Judged by eye in rendered stills at day and night: close, wide and from above. Not played by hand, and the motion (flicker, licks, sparks) has only been seen frozen in stills.

## Open
- Nothing in the game uses it yet: the roguelike's way lanterns, the kit isles' night lanterns and the native campfires could each take a Flame.
- Cost: about 22 steps of three noise lookups per flame pixel, fine for a handful of fires close up. Many fires on screen would want fewer steps at range.
- The brazier's own bowl casts a hard ring of shadow under it from its light.
- Smoke is faint by day. Heat shimmer and a coal bed under the bonfire are not done.
