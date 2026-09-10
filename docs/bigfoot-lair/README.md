# Inspectable Bigfoot lair study

Run `run-bigfoot-lair.command`. Invite **Visit the cave**, then select
**Inspect lair** to look beneath the surface. **Return to forest** restores the
surface camera. **Another rock arrangement** changes the deterministic dressing;
the dry sleeping spot and puddle stay in place. P pauses the resident and drips.

This first playable study explores one room under the existing cave. It reuses
Fidelity's terrain noise and rock palette, the garden water shader, waterfall
droplets, and Bigfoot's existing sleep animation. The chamber is a procedural
cutaway mesh, not yet an editable extension of NativeTerrainData: that system
represents one surface elevation, not an enclosed underground volume.

The same resident transfers to the bed after disappearing through the black
mouth, then returns behind the mouth before walking outside. Surface navigation
continues to own the entrance; the underground rest does not claim to simulate
a connecting staircase or tunnel walk. Rain and hibernation use existing visit
durations. Saving during a visit retains a safe surface position.

Scope: a dry sleeping nook, a shallow puddle with drips and splash rings,
seeded stalactites/stalagmites, and reversible room inspection. Food storage,
carrying objects downstairs, terrain brushes, persistent room customization,
and a full cave network are not implemented. The main game's saved cave world
continues to work as before; this room is launched through the separate study.

Verification: `tests/test_bigfoot_lair.gd` exercises the real resident entering,
sleeping underground, inspection, pause, redressing, saving an exterior position,
returning to the surface, and cancellation. Native screenshots are written to
`/private/tmp/bigfoot-lair.png` by that test.

Native Metal checks passed: lair lifecycle/inspection (16 assertions), existing
cave lifecycle, and main-game cave save/reopen. Review found camera-mode and
growth-visibility issues; both were fixed and covered by the lair test.
