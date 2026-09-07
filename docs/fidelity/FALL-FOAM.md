# Waterfall foam motion

The seven source foam clusters now bob, tumble and settle with the original
waterfall.js equations. Their individual travel-time gates also control growth:
the ledge cluster appears early, while the plunge cluster waits until the
fall reaches it. The generic water-detail visibility gate no longer overrides
the foam's own reveal.

`export_fall_foam.mjs` matches each original blob to imported geometry by its
vertex positions, exports its base height, gate and rotation, and records full
transforms after calls to the original water.grow/setIce/update methods.
`fall_foam.gd` keeps this motion separate from mesh-based terrain contacts.
At full freeze the blobs settle at base height and stop tumbling. Pause freezes
motion while retaining explicit growth-control updates.

Source rotation is frame-dependent: waterfall.js adds .004 radians per update
rather than scaling by delta. The native implementation preserves that behavior;
it should only change if the original behavior is intentionally revised.

`test_fall_foam.gd` compares all seven transforms at five source states spanning
open water, partial/full freeze and early/late growth. Maximum component-vector
error is 2.32764e-7; visibility, pause and terrain gates pass. The integrated
fidelity scene also passes. These are source-state checks, not a claim that all
waterfall rendering has reached parity. Surface reflection ordering, complete
waterfall visual comparison and broader scene growth choreography remain.

`fall-foam-motion.mp4` shows five seconds of the integrated plunge, camera
`4,.9,1.9,4.8,.4,-3.6`. Frames 30 and 120 inspected: the foreground foam's
facets rotate and its height changes while the waterfall and mist continue.
This is native motion footage; source validation is the transform fixture above.
