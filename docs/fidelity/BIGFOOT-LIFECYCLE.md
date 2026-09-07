# Automatic Bigfoot encounters

The native encounter now follows current source `bigfoot.js` admission rules:
30-second checks, 5% chance per check, camera distance 4–35, complete growth,
one automatic encounter per session, and a persistent seven-day cooldown.
A ConfigFile reservation is saved before the actor becomes visible; unreadable
or unwritable storage rejects admission. Manual B previews do not reserve or
consume cooldown and retain the native sandbox's existing 16-second duration.

Admission and retirement use the actual posed mesh vertices. Visible vertices
must be concealed by the source tapered trunk volume; offscreen vertices do not
prevent admission. After 13.2 seconds the pose holds while concealment is checked
once per second. Exposed actors stay present instead of disappearing visibly.
The source .1-second timestep cap, pause and growth-reset behavior are preserved.
The encounter tree now persists independently of the actor, as in the source.

Current source `bigfoot.js` schedules a peek, not a wandering passage. The native
rig still supports walking poses separately; walking is not added to this source
encounter lifecycle.

## Verification

Native `test_bigfoot_lifecycle.gd` passes actual-mesh concealment, admission,
reserve-before-show, failed-reservation rejection, pause, step clamp, exposed
retention, concealed retirement, growth clearing, one-play gating and manual
preview bypass. A separate temporary ConfigFile verifies cooldown persistence
across a fresh instance and expiry; the user's cooldown is untouched.
Native `test_fidelity.gd` also passes.

`bigfoot-automatic.mp4` films 15 seconds of the real automatic actor path at
30 fps using deterministic chance and a test reservation. Admission begins
concealed and the final state is inactive/played. Frames at 3, 8 and 15 seconds
were inspected: the peek is visible around the trunk's right edge, partly
occluded by existing scenery, and the actor is gone after hiding. Background
weather is held; this is a lifecycle demonstration, not matched source footage.

## Remaining scope

The saved seed lacks a source encounter anchor. This scene uses the existing
native dry-clearing/tree fixture; source anchor generation remains unported.
Mist >= .65 selects the source standing-look stance and material multiplier
#626762. Native fog footage is inspected; matched source fog framing remains. Source forced previews loop;
native manual previews intentionally retain their prior bounded sandbox behavior.
The natural chance, cooldown and camera concealment mean sightings remain rare.

## Fog silhouette follow-up

`reference_bigfoot.gd` now retains its coat material and applies source #626762
for fog silhouettes; switching back to the normal preview restores white so the
authored per-vertex coat colors remain intact. The standing stance is source
(1.05,0,1.05) rather than the trunk-peek position. Both automatic mist encounters
and explicit `--bigfoot-fog` previews use this path. The latter frames the standing
actor and sets mist .75 without consuming cooldown.

The lifecycle test additionally checks standing placement, exact material
multiplier, normal-preview restoration and reservation isolation. It passes.
`bigfoot-fog-silhouette.mp4` records 90 frames at 30 fps; frame 60 was inspected.
The native actor reads as a dark standing silhouette beside its persistent tree.
This fixture is close to the camera and not fully enveloped in pooled mist;
source anchor placement and matched distant fog framing remain open.
