# Native wind response

The wind now uses weather.js gustAt for the strength envelope and wind.js's
integrated scalar travel distance for both noise octaves. Water, fog and plants
read the same field, including the manual gust contribution before the source
field clamp and gale conversion.

Foliage retains the captured per-material tuning and now follows foliage.js's
quadratic steady lean, two-frequency flap, crosswind flutter, high-gust shiver,
arc shortening and exposed pale-side tint. Deformation is in local coordinates,
matching the original's instance rotation and scale; wet sag and growth follow
it in source order. The previous normalized inverse-transform direction and
fixed 0.15 vertical cap were native approximations.

Validation: export_wind.mjs extracts the original gustAt function into numerical
fixtures. test_wind.gd checks those samples, travel, heading changes and pause;
test_fidelity.gd passes in native Forward+. The six-second wind-response-comparison.mp4
shows new native behavior LEFT, prior native behavior RIGHT at wind 2, same
camera and time. Frames at 1, 3 and 5.97 seconds were inspected; the foreground
flower stand shows the stronger changing lean. This is a before/after check,
not a matched Three.js motion proof. Both recordings report six seconds and
identical cloud drift.

Remaining: full matched source motion capture. Weather dial smoothing was subsequently aligned to the source .55 response, including preset-linked wind. Model-space
normal handling also remains as in the source sway material.

Lake-ray investigation: the imported seed-7 source scene contains no lake:rays
objects (live browser traversal using the saved scene query). lake-rays.js
builds above-water shafts only for qualifying large/deep lakes with shoreline
clearance. That separate module remains unported; adding arbitrary shafts to
this captured lake would not establish parity with its source scene.

The thunder downburst ring and storm scheduling were subsequently added; see
LIGHTNING.md. Its source timing is tested; dedicated field motion footage remains.

Manual gust follow-up: G now invokes the source six-slot parcel lifecycle.
Recent presses merge into the youngest gust (bounded at .8); a new parcel is
born five units upwind, fades in over 1.5 units of air travel, holds through
30 units and fades out by 52. Empty slots are reused before the oldest live
parcel is replaced. All consumers read the same parcel field before clamping.

export_puffs.mjs executes the original wind.js lifecycle and field functions.
test_puffs.gd matches all six slots and four field samples across merging,
replacement and retirement, and checks pause. Native test_fidelity.gd passes.
gust-comparison.mp4 is a four-second close-up of the left bank: manual gust
LEFT, no-gust control RIGHT, wind 1.2. The full frame is gust-wide.mp4. Both
sequences report exactly four seconds and identical cloud drift. The comparison
was inspected at two seconds; foliage tips on the bank differ, with about 4%
of pixels above a 12-channel-level threshold in the strongest bank tile.
The foreground right flowers lie outside this parcel and show almost no change.

Capture now supports --film-dir with --film-frames: JPEGs are saved after each
rendered frame, avoiding movie-writer repeats when macOS occludes the window.
The sequence has no audio. This provides native effect/control evidence, not a
matched source GPU film; CPU fixture agreement does not prove full pixel parity.
