# Opal night: status notes

Finished as a first full pass; branch worktree-agent-a2c83d4f790d9a9ff, merged with look/night-styles. All in `shaders/night_opal.gdshaderinc` (no edits to other shaders).

## Look
- Dome: blue-violet overhead to teal at the horizon, pearl glow on the horizon line.
- Milky Way: moonstone haze, detail stretched along the band, few soft dust lanes, a whisper of lilac/mint/peach (`zs_opal_pearl`), rare slow pastel veils. About 10 octaves in the band, 1 noise elsewhere.
- Stars: a fifth of the way to pearl tints.
- Planet: pearl body, milky noise-bent bands, pastel limb sheen; rings of fine lanes with gaps and faint iridescence; soft pearl glow (toned down at the end, unrendered).

## Stills (best)
- /private/tmp/zs-night/opal/r0 baseline (old look)
- /private/tmp/zs-night/opal/r5/sky-b1-up.png, sky-b1-low.png (Milky Way), planet.png (edge-on, glow was too violet; since reduced)
- /private/tmp/zs-night/opal/r3/planet.png (tilted rings, best planet view)

## Weaknesses / next steps
- The band is smooth and soft but has little fine structure; stars do not crowd into it (star data is shared). A grain of tiny pastel points or a denser star field inside the band would help.
- The pearl iridescence is nearly invisible in the band; raise the `tone * pearl` mix a touch if wanted.
- One or two dark lane swooshes still read as isolated strokes.
- Planet glow and ring shading were last tuned without a render.
