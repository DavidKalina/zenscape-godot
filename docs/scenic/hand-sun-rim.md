# The hand holds the sun and turns the rim

The first slice of `docs/scenic/hand-world.md`: the bottom scrubber's two jobs, the time of day and the season, move into the world. Drag the sun along its arc for the hour, and drag the diorama's rim round like a dial for the season. Branch `feature/hand-world-sun`, 2026-09-28.

## Trying it

- **The sun.** Put the pointer on the sun's disc (the grab is generous: 64 px or 7 degrees round it). The hint line says "DRAG grab the sun". Press and drag: the disc follows the pointer to the nearest point of its own arc, so a drag anywhere near the arc reads, and the hand reaches up and cups it. Let go and it drifts on a little at the speed you dragged it, slowing, and settles. At night the moon is up in its place (studies/celestial.gd rings it half a day round, on a flatter ring), and it is grabbed and dragged the same way. Grabbing the sun needs it on screen: turn the camera toward it (lower the view with a right-drag) if it is above or behind you.
- **The rim.** Put the pointer on the rim: the top edge of the earth block, the last 0.8 m of land at the plate's border, the block's walls, or just outside the plate's outline (28 px). The hint says "DRAG turn the rim for the season". Press and drag along the rim, round the diorama. Pushing the near rim to the right turns the year on and pushing it left turns it back. A full turn is a year and one side of the plate is about a season. The season follows live, so plants bloom, turn and go bare, and the ground's gold and cold follow. There are gentle detents at the four seasons, so the dial sticks a little at each. Let go and it settles into the nearest season, which is then pinned as the mood drawer's Season would pin it (Winter lays its frost).
- **Everything else is as before.** Dragging the land or empty sky still orbits the camera, and a brush still paints. A press on the sun or the rim belongs to the hand. The camera and the brushes never see it, from press to release. Ctrl-drag (orbit) and double-click (focus) are left to the camera, even over the sun.
- **`--scrubber`** brings back the bottom scrubber (`scripts/lantern_scrubber.gd`) under the hint line. It is hidden by default, and its plate stops blocking the pointer when it is. Both paths pin through `scripts/mood_look.gd`, so they agree.
- `--no-hand` leaves the hand out. The sun and the rim still work, and nothing shows the hold but the world itself.

## Choices made where the direction was open

- **Hold or turn after the sun is let go.** If the day was held, the new hour is held. It is pinned as a *held hour* (`MoodLook.held_hour`, a Time of day pin `"at:0.5230"`), which any rebuild applies again. The scrubber used to snap to the nearest of six hours, and the hand can leave the sun anywhere. If the day was turning (the creation plain, or Turning day pinned), it turns on from where the sun is left and nothing is pinned. `MoodLook.pin_hour` sets the pin without rebuilding the world, since the hour is already on screen. A running mood fade lands on the new hour too. Pinning the hour this way does not reset the weather's drift the way a rebuild would.
- **Where the hand is when it holds the sun.** The sun is at infinity, so the hand is held `SUN_REACH` (12 m) from the camera along the ray to the disc, at its normal size (2.5 m). At that distance the Reach clips' cup is about the disc's size on screen. The hand is a big presence in the sky, about a quarter of the view tall (12 degrees of 45), and is meant to cup the disc without covering it (unverified on screen). God Hand turns it square to the camera (`FACE`, `_square_to_camera`), since the clips are made for a level view and the sky is seen from below. This was preferred over a hand scaled to the screen, which would have needed a second size rule in the hand.
- **The moon's arc.** The scene has a moon, but celestial.gd rings it opposite the sun on a ring tilted three quarters as much. So "on the same arc" means its own ring, half a day round. The reach holds whichever disc was grabbed for the whole drag, so dragging the sun below the horizon carries on smoothly into the night, with the moon rising elsewhere on its own.
- **The dial's gearing.** Four seasons a turn, measured as the pointer's angle round the plate's middle, where its ray meets the rim's height (or round the plate's middle on screen when the pointer is above the horizon). From the usual camera, one side of the plate, corner to corner, is a season. The detents sit on living weather's mid-season values (0.14, 0.375, 0.64, 0.87), and between them the season runs piecewise, so a detent always lands exactly on the value the drawer pins. The stickiness is a smooth easing on the dial (`DETENT` 0.6: 0.4 of the pointer's movement at a detent, 1.6 between detents), not a snap.
- **The hint line** says what the pointer is near, and stops once each thing has been held twice (`HINT_UNTIL`). While the hand holds something, the line goes back to its usual text. In the glass palette (`--classic-shell`) the hint goes to the editor's status line.
- **The rim's band.** The last 0.8 m of land at the border is the rim's. A brush stroke has to start inside it, though it may run out across it.

## For the sibling slices

`scripts/hand_reach.gd` is on the scene as `scene.hand_reach`. It decides what the pointer is reaching (`reach_at(point)`: "sun", "rim" or ""), holds it (`holding`), and drives the hand through `god_hand.reach_gesture` / `reach_point`. It takes presses in `_input`, as the scene's last child, so the orbit (`studies/fidelity.gd`) and the brushes never see them. `studies/fidelity.gd` only gains the setup lines.

- **Rim hooks for the snow-globe shake:** `rim_grabbed(screen_pos)`, `rim_dragged(screen_delta, delta)` once per pointer move, and `rim_released()`. When a shake fires, call `revert_season_to_grab()`. It puts the dial and the world clock's season back to where the rim was taken. Called while the rim is held, the let-go then leaves the season alone. Called after the let-go, it also restores the season pin as it was (`grab_season_pin`). `holding_changed(what)` tells anyone else.
- **God Hand:** `GESTURES` gains `"sun":"Reach"` and `"rim":"Rim"`, `LOOPS` gains their Holds, `TILT` gains 0 for both, and there are a few small additions. `FACE` / `_square_to_camera` squares the hand to the camera for the sun. The rim hand leans into its travel like a free hand, so a push along the rim shows its direction. The rim hand is not lifted clear of the land, because its fingertips hang over the edge.
- **Clips** (`tools/blender_hand/god_hand_clips.py`, their own section, joined to `CLIPS` by `CLIPS.update(SUN_RIM_CLIPS)`; the review checks `SUN_RIM_HANDOFFS`):
  - **ReachIn** (1.2 s): it gathers, dropping with the fingers curling in, swings up open and long past the disc, and closes round it with an overshoot.
  - **ReachHold** (3.2 s): the hand stands beside the disc in a C, the fingers arched over and the thumb curled under. It rocks round the disc like turning a warm coin, the fingers roll a slow wave and once a loop ease out from the warmth, the thumb strokes under it, and it breathes.
  - **ReachOut**: it lets go, the fingers blooming open, draws back off the disc and shakes the warmth from its fingers.
  - **RimIn**: it rises and draws back, opening, then swoops onto the edge from outside, its fingertips biting over it.
  - **RimHold** (2.4 s): the grip, fingertips on the plate's top, working the dial with a shove along the edge and back twice a loop. The fingertips keep hold and dig in on each shove, and the wrist leads.
  - **RimOut**: a last press, then the fingertips peel off, the hand pops up and back, and it flicks its fingers loose.
  - `god_hand_review.py --check`: every hand-off is 0.0000. The review stills show a disc stand-in for Reach and an earth block for Rim.

## Checks

- `Godot --headless --fixed-fps 60 --path . --script res://tools/probe_hand_reach.gd` runs against stand-ins: the real sky rig, world clock and God Hand, with a flat plate and a stand-in mood. It checks:
  - the dial's arithmetic and detents, and held-hour pins;
  - that a press on the sun or the moon is taken before the scene sees it, but not over a UI panel;
  - that dragging along the arc sets the hour, a let-go drifts and slows and then pins the held hour, and a turning day turns on;
  - the rim's reach: the band, the walls, and the land inside it not counting;
  - that a rim drag turns the dial by the angle turned, sticks at a detent, emits `rim_dragged`, settles into autumn and pins it;
  - `revert_season_to_grab`;
  - the hand's `reach_gesture`, `reach_point` and clips (ReachIn, ReachHold, RimIn, RimOut);
  - the hint lines;
  - that the scrubber is hidden without the flag.
- Headless launches of `studies/cozy_worlds.tscn` found the reach, the hand and the shell wired. They found the scrubber hidden, and shown with `--scrubber`. A rim drag in the real scene turned the dial without moving the camera or leaving an undo step, and pinned the season it settled on. `tools/probe_mood_look.gd` still passes.
- **Unverified on screen.** Nothing was run with a renderer, so nobody has yet seen:
  - how the hand reads cupping the sun 12 m out, or gripping the rim;
  - whether the disc shows through the cup;
  - whether 64 px is the right grab;
  - how the drift and the detents feel in motion.
  The clips were only checked as Blender stills and numbers.
