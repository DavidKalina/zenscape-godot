# Softer eddies, flower heads, pollen and kicked-up grass (handoff)

Three tweaks to endless flight's meadows. Prototype: smoke checks pass (flying and `--on-foot`), no tests added, none known to break.

## The eddies press less

The eddies' swept bands laid the grass flat. Their lean was moderate, but their press, which lowers a blade by up to 75 % of its height, saturated: just behind a low head the press was a median 0.64 and fully flat (1.0) at p90 (`scratch/eddy_peak.gd`, `GrassReact.push_at`).

- Each react stamp now carries a press share (`"press"`, default 1). It goes in the stamp's CUSTOM.x, and the stamp shader reads the reach from the quad's own size (`px_per_m`). The wash and the walker are unchanged.
- The eddies' stamps press at `GrassReact.EDDY_PRESS` 0.25: median press 0.21, p90 0.54, and the lean is as before. `--eddy-press=X` tunes it (1 is the old look), and `--eddy-push=X` (3) still scales lean and press together. At `--eddy-push=2.2 --eddy-press=0.2` the lean p90 drops from 0.84 to 0.41.

## Flower heads

The endless grass is `TALL` (4) times the isles', and the flowers' stems are lifted to match by a taller y scale. That stretched the heads too: lupines became purple blade-like streaks and daisies were a few pixels. Now, on endless flowers only, `reference_surface` `flower_head_grow` undoes the y stretch on the head (its offset from the neck), so each head keeps its own shape, and grows it by `EndlessGrass.FLOWER_HEAD` (2.4). `--flower-head=X` tunes it, and 0 gives the old stretched heads. The isles leave the uniform at 0 and are unchanged. Past 22 to 55 m the drifts are still the far tufts' wash colour and the ground's painted dots.

## Motes (`scripts/endless/endless_motes.gd`, new)

- **Pollen**: 260 lit soft specks (the existing `shaders/pollen_speck.gdshader`) drift on the breeze 0.4 to 5 m over the grass round the eye, while it is within 30 m of grassy land. The disc is led ahead along the eye's travel, so a low pass flies through them.
- **Kick**: pale bits of grass blade (WindGrassChaff's blade, 3x wider, `shaders/grass_bit.gdshader` lit both sides) are thrown up from the grass tops where the prop wash comes down (`GrassReact.wash_spot`). The rate is up to 120 a second at full wash. The plane's wake carries them along at first, so they stream back past the chase view. A few also come off any eddy skimming within 1.2 m of the grass.
- Flags: `--no-motes`, `--no-pollen`, `--no-grass-kick`, `--pollen=X`, `--grass-kick=X`.

## Not checked

- The frame cost of the motes' GDScript step (about 440 instances written a frame) was not measured.
- At cruise speed, kicked bits are in the chase view for about a second. They read best when rolling, taking off and landing, which I did not capture.
- One rendered run crashed Godot (0xC0000374) right after the shader edit; the rerun was clean.

Throwaway drivers in `scratch/` (git-ignored): `eddy_peak.gd` (the press numbers), `flower_look.gd`, `motes_look.gd`, `eddy_play.gd` (stills).
