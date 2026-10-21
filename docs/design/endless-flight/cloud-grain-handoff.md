# Endless flight: cloud grain

Only the grain changed; cloud shape, placement, bases and count are as before.

- `shaders/endless_cloud_resolve.glsl` (new, endless-only copy of the isles' resolve, compiled in its place by `endless_cloud_effect.gd`; the isles are untouched). New path: 3x3 gaussian, depth-weighted spatial filter of the march; history clipped to mean +/- 1.5 sigma of that neighbourhood (not min/max); a marched pixel is half its own sample, half the filtered ones.
- `shaders/endless_cloud_march.glsl`: with `P.flash.x = 1` the jitter is interleaved gradient noise on the render pixel plus a golden-ratio step per frame.
- `endless_clouds.gd`: blends 0.5/0.08 became 0.2/0.06.
- Flags: `--cloud-grain=old` (earlier look, exactly), `--cloud-blend=m,u` (marched, upsampled blend by hand).
- Measure (held still, same seed/camera, frame-to-frame luminance diff): 0.0011 old, 0.00014 new (about 8x less flicker). In flight the whole-frame diff is dominated by motion and the by-eye difference is small; no grain seen in either capture at 1280x720, a little more softness on cloud edges in the new one (history 0.2).
- Cost: not measured; the resolve does 9 taps instead of 4 at full res. Full res / more steps / TAA not tried (TAA would ghost against the sheet and cost the whole frame).
- Still shimmers: not judged at the user's resolution in real play; if edges smear in fast turns raise `--cloud-blend=0.3,0.08`.
- Captures: `captures/cloudgrain/{old,new}_{still,fly}.png`; scratch driver `scratch/cap.sh` (git-ignored).
- Breaks no test I know of (none reference the resolve shader or these constants; not run).
