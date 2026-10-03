# Deliberate woodland movement

This changes decisions and route following in the current Godot diorama. The
model and authored animation clips are unchanged.

The previous scene reduced rests to 0.5–1.2 seconds, selected random wander
points 2–4.5 metres away, and followed every cell of obstacle routes. Automatic
activities could also take ownership partway through a journey. Together these
made the character repeatedly step, turn and restart.

Bigfoot now searches 6–10 metres ahead, preferring his current heading. If that
is blocked he widens his search; only when longer paths fail does he consider
shorter trips within a confined clearing. He observes for 4–8 seconds after
arrival, and scenery inspections last 4.5 seconds. New scenery waits for the
current journey; scheduled daily activities also wait through the arrival pause.
Explicit interaction, carrying and unsafe terrain still interrupt normally.

Navigation removes unnecessary corners only when the full shortcut passes its
existing swept-clearance checks. At runtime it checks the next actual foot
movement rather than rescanning a whole long leg each frame. World edits still
validate the remaining route. If a finer runtime sample rejects a shortcut,
planning falls back to the original grid until the next terrain rebuild, avoiding
repeated attempts at the same failed shortcut. Rejected connections from the
actor to the grid are remembered as well as grid-to-grid edges. No obstacle avoidance or terrain
safety is disabled.

## Evidence

`tests/test_creature_deliberation.gd` (removed) uses the current product scene and its real
brain settings. In a seeded 90-second open-ground simulation, mean uninterrupted
walk duration changes from 3.62 to 8.51 seconds. A controlled obstacle detour
changes from 39 route points to 3, with all segments safe. Tests also cover new
scenery arriving during movement, automatic activity ownership, arrival pauses,
and activities starting after the pause rather than being starved.

Existing brain and navigation tests pass. The native daily-routine test uses a
360-second observation window for the slower pacing, retaining its exploration,
activity completion and safety assertions. It passes: 29.17 metres travelled,
all six activity types completed, zero unsafe positions and no failed approaches.

`comparison.mp4` shows NEW LEFT / PREVIOUS RIGHT over 30 seconds at 24 FPS.
Both use the same current Godot diorama, simplified model, seed, fixed camera,
landmarks and initial position. It isolates free roaming on open ground;
daily activities and curiosity targets are excluded from both reels. This is a
pacing comparison, not a promise that obstructed terrain permits equally long walks.

Reproduce with `tools/film_bigfoot_deliberation.gd` in native Forward+. It renders
fixed-size offscreen frames to `/private/tmp/zs-deliberation-effect` and
`/private/tmp/zs-deliberation-control`. Frozen pre-change scripts in `control/`
are film inputs only and are never loaded by the product.
