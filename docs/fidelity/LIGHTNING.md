# Native lightning checkpoint

L (or Lightning) strikes at the camera target. Storm weather also schedules
strikes using the source countdown and random gap formula; fair weather does
not. Source timing drives 2–4 return pulses, exponential flash decay, delayed
thunder events and the half-second delay before a ground-level downburst.

The bolt uses four midpoint-displacement passes, downward branches, centripetal
Catmull-Rom curves, five-sided core tubes and wider glow tubes. Native tube
frames are tangent-based rather than Three's transported frames; the random
sequence also differs. An OmniLight supplies terrain illumination and shadows.
Cloud/fog shaders contain the source internal-flash terms. Point-light energy
is a native adaptation (12 times flash), not validated candela parity. The
native fog history leaves some light trailing the pulse and still needs a
matched source rendering check.

The downburst enters the shared wind field: a 12-unit/second ring, sharp ahead,
long behind, drifting with wind and decaying over 2.6 seconds. It retires after
70 units or when weak. Pause holds all simulation clocks. A new strike replaces
the bolt and pending downburst while preserving already scheduled thunder.
Thunder signals use distance/28 delay and now play the original recordings with
source distance-dependent gain, pitch and low-pass cutoff. Each overlapping
voice has its own filter/panner bus, removed on completion or scene teardown.
The Thunder sound toggle mutes voices without resetting their timelines.
The original chunk.js listener routes thunder to audio, not camera trauma, so
this port leaves the existing manual/growth tremor behavior separate.

Validation: native test_lightning.gd verifies geometry presence, pulse counts,
pause, delayed front radius/decay, one-shot thunder dispatch, cleanup and storm
scheduling. test_fidelity.gd checks the integrated scene. lightning-comparison.mp4
shows a native strike LEFT and the same weather without a strike RIGHT at 30 FPS
for six seconds. Both recordings report identical six-second motion and cloud
drift. Early, return-flash and settling frames were inspected. This shows the
new behavior; it is not evidence of full source visual parity or a dedicated
visual proof of the downburst field.

Audio verification: test_thunder_audio.gd checks decoded original clips, exact
near/far treatment endpoints, overlapping isolated buses, pause, mute, voice
retirement and teardown. An integrated native run captured nonzero thunder
(first signal ~1.02 seconds, peak 7075/32768, no clipping). Its movie writer
inserted duplicate frames while occluded, so that A/V recording is withheld;
it does not prove audiovisual synchronization. The simulation's distance delay
is separately covered by test_lightning.gd. Godot's filter response is an
adaptation of WebAudio's biquad and has not been acoustically matched. Full
ambient audio, animal calls and water remain unported.
