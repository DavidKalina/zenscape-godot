# Opal night: status notes

Branch: worktree-agent-a2c83d4f790d9a9ff (based on 1f34b2e5). Work in progress.

## Where it stands
`shaders/night_opal.gdshaderinc` is rewritten (v2, never rendered):
- Dome: blue-violet overhead to teal at the horizon, pearl glow on the horizon line.
- Milky Way: moonstone haze, detail noise stretched along the band, soft dark lanes, a whisper of mother-of-pearl (`zs_opal_pearl`), plus very faint pastel veils gated by one low noise (rare, slow).
- Stars: 22% toward pearl tints.
- Planet: pearl body with milky bands bent by noise, pastel sheen near the limb; rings of 3 scales of 1-D noise with a gap, iridescent tint; soft pearl-lilac glow.
- Two gated (style == 1 only) edits outside the file: `sky_planet_body.gdshader` multiplies alpha by `zs_opal_planet_edge` (antialiased limb, which the night mix would otherwise discard); `sky_planet_rings.gdshader` softens the planet shadow with a smoothstep.
- `tools/_opal_planet.gd`: a throwaway backdrop capture that points the camera at the planet (fov 55/22/9) at 23:00. Never run successfully; its camera look_at may fight scene._update_camera.
- `test_night_styles.gd` prints PASS (headless).

## Stills
- Baseline (old look): /private/tmp/zs-night/opal/r0/sky-*.png (b1-up shows the old brownish blobby band).
- v1: /private/tmp/zs-night/opal/r1/sky-*.png and r1-backdrop/{low,wide,overview}-2300.png. v1 band (b1-up) was too bright and flat grey-blue, with its dark lanes reading as blots. v2 stretches the noise along the band, halves brightness and thins the lanes to fix this; unverified.
- The planet did not appear in any v1 still: the ground eye cannot look below the horizon and the overview framing misses it. It has not been seen yet.

## Next steps
1. Render r2 (sky stills, one run) and judge band brightness, lane softness, pearl whisper.
2. Get a planet view (run tools/_opal_planet.gd, or fix the pose); check limb AA, rings, shadow softness, glow.
3. Check the dome colours in b2-up/b3-up and the horizon pearl.
4. Tune star tint; consider faint extra nebula veils if the band alone feels empty.
5. Delete tools/_opal_planet.gd before merging.
