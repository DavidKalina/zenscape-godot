# Endless eddies (handoff)

Endless flight's gusts now work as the aqueduct isle's eddies do, in place of the ring landings.

## What the isle uses

The visible eddies are `scripts/breeze_ribbons.gd` (BreezeRibbons): painterly strokes, each the trace of a mote of air that flows downwind, meanders, rides over the ground, curls through eddy loops and now and then dives to skim the grass and kick up off it (sweeps). The atmosphere (`studies/atmosphere.gd`) owns one, and brings ribbons in along its gust fronts (`scripts/shared/gust_fronts.gd`, `carry_front`). Each head is published as `zs_ribbon_0..7`, and `zs_ribbon_wake` (`shaders/reference_wind.gdshaderinc`) bows the plants behind it. `disturbance.gd` and `wind_leaf_litter.gd` are not the eddies (leaf litter reads `air_at`).

## What was brought over

- `scripts/endless/endless_eddies.gd` (new, owned by `studies/endless_flight.gd` as `eddies`): runs the isle's BreezeRibbons whole (unchanged), with the ground probe = `field.height`, bounds following the eye. Every `--eddy-every` s (3, +-2) a front of 3 to 5 ribbons comes into view 40 to 130 m ahead of the eye, one with a sweep. Its width and tail are scaled up to read from cruise (x10 wide, x3 tail).
- Grass reaction (reworked in the wild-wind loop, 2026-11-03): each low ribbon head rolls a band through the grass: a train of stamps every 0.3 s along its last 2.1 s of path, moved every frame (`GrassReact.set_flows`, `scripts/endless/grass_react.gd`), the push highest at the head and easing back with a little swing past rest behind it, fading with height (none above 8 m), stronger when it skims. A head that fades out leaves its band to roll out along its last way. (It used to drop a fixed stamp every 2 m, each popping in over 0.1 s, so the grass moved in steps three or four times a second; `GrassReact.eddy` is still there, unused.)
- With the wind field (`look.wind`, wild-wind loop) fronts and lone ribbons come by the local wind (`EndlessEddies.rate_of`): none in calm hollows or still hours, about twice the old rate on windy ridges and coasts, along the wind's heading there. `--wind=off` and worlds without a field keep the old rate. Why stamps rather than the endless shaders reading `zs_ribbon_wake`: the endless grass, far ring and ground paint already read one map, the map also gives the pale/dark sheen from the air, and the ribbon's heads are only 8 slots (capacity here is 14). The ribbons still publish `zs_ribbon_N`, so any shader that includes reference_wind also bows under the first 8.
- No fronts or atmosphere were added: ribbons are born by the eddies node directly (`_birth`).
- The prop wash and the walker are untouched. The ring landings (and their zs_puff parcel) are off by default, back under `--gusts=rings`.

## Flags

`--gusts=eddies|rings|both` (default eddies), `--eddy-every=S`, `--eddy-scale=X` (stroke width, 10), `--eddy-tail=X` (3), `--eddy-reach=M` (7), `--eddy-push=X` (3), `--eddy-radius=M` (150). Existing: `--no-grass-gusts` also silences eddy stamps, `--grass-gusts=X` scales them. Isle's `--ribbon-opacity=`, `--ribbon-glow=`, `--sweeps=`, `--wake=` apply too.

## See it

`godot --path . studies/endless_flight.tscn -- --no-title --seed=1` (compare `--gusts=rings`). Captures in `scratch/endless-eddies/` (git-ignored): `h_*` / `eddies_sheet.png` (hovering over a meadow, strokes with an eddy loop and bowed grass), `rings_sheet.png` (same spot, rings: barely visible from cruise), `isle_sheet.png` (isle reference).

## Notes

- Grass bowing from cruise is subtle; push and reach are the knobs (`--eddy-push`, `--eddy-reach`).
- A ribbon is a thin hairline at the isle's own width; the x10 is for cruise height. Judge in the real flight.
- Smoke check passes for eddies, rings and both. No tests added; none known to break.
