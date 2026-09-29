# Turning the world like a lazy Susan

One slice of the hand-world direction (`docs/scenic/hand-world.md`, "Turn it like a lazy Susan"). A drag on the land or on empty space moves the camera, and the camera move now reads as grabbing the world and pushing it round. Built on 2026-09-28 on `feature/hand-world-turn`. It has only been checked headless, so nobody has yet judged how it feels on screen.

## Try it

Open the game as usual (`studies/cozy_worlds.tscn`) and put a world up.

- **Turn.** Right-drag (or Ctrl-drag) anywhere. With the brush put away (Look), a plain drag works too, and so does a drag off the land with a brush in hand. The ground you pressed keeps its bearing round the pivot under the pointer. The near side of the world follows the pointer and the far side goes the other way, as a turntable does. Up and down still tilt, as before.
- **Flick.** Let go while moving and the world spins on like a basketball on a finger: 1.6 times the speed it had, up to about two turns a second, slowing over several seconds and easing to a stop by itself. A drag that stops before you let go does not spin.
- **Bat.** Flick again the same way while it spins and the new flick adds to the spin, so you can keep it going. A click, or a flick the other way, catches it instead.
- **Catch.** Press anywhere on the world while it spins. The world carries on a few degrees against the hand, comes back to where you caught it and settles. If the press goes on into a drag, that drag turns the world from there.
- **The hand.** When the drag starts on the land, the God Hand lays its palm flat on the grabbed ground with its fingers spread and leans into the push. When you let go it peels off with a follow-through, and it slaps down to catch a spin. It shows in Look too, but only while it holds the world. Off the land (on empty space or the sky) the world still turns, but the hand stays away.
- **A/B.** `--classic-orbit` turns all of this off, and the rig orbits by pixels again (a screen height is a full turn, with the old 35 % fling).
- Unchanged: trackpad swipes (they have no pointer to grab with, and macOS supplies the momentum), Shift+arrows, pinch and wheel zoom, glides, and Space's idle drift. A swipe, Shift+arrows, a glide, the idle drift or a pose set from outside all stop a spin dead.

## How it works

`scripts/world_turn.gd` belongs to the camera rig (`scripts/camera_rig.gd`), which is the camera that is live in the creation shell. The rig calls `advance` each frame after its springs have stepped, and the yaw that `advance` writes is the one the scene reads.

- **The grab.** When the scene starts an orbiting mouse drag (`scene._orbiting`), the ground under the press is taken as the grab point. Off the land, the point on the pivot's level is used instead. Each frame, the pointer's ray (using the rig's pose for that frame, not the camera's last transform) meets the grab point's level. The yaw then turns by the difference in bearing round the pivot, so the grab point's bearing matches the pointer's exactly. There is no gain and no spring behind the yaw during a grab: the rig's yaw is written directly. The rig still takes the drag's vertical movement as tilt, and the old horizontal gain is skipped (`takes_orbit`).
- **Near the pivot**, a bearing swings wildly with a small move. Closer than `NEAR` (0.1 of the view's half height at the pivot), the turn falls back to pixels (a screen height is a turn), blending back to the true grab by twice that. The grab takes up the ground now under the pointer as it goes, so nothing jumps when the true grab resumes. The same fallback applies when the pointer goes above the horizon.
- **Flick.** The drag's turning speed is read over 0.05 s. At release, above `FLICK_MIN` (0.35 rad/s), the world spins at that speed, up to `MAX_SPIN` (4 rad/s). The spin's drag is exponential (`SPIN_DRAG` 0.9 s) plus a dry friction (`FRICTION` 0.3 rad/s²). The friction fades out below `FRICTION_SOFT` (0.25 rad/s), so the last of the spin eases away instead of stopping on a step.
- **Catch.** A left or right press on the world during a spin is only watched, never consumed, so the press still does whatever it does: it paints, bends a tree or starts a drag. The spin's speed (up to `MAX_CATCH`, 2.2 rad/s) goes into an underdamped spring (`CATCH_W` 13/s, `CATCH_ZETA` 0.55) as a yaw offset on top of the turn, and the spring brings it back to zero. During a grab the offset sits on top of the exact hold, so a catch that goes on into a drag wobbles round the pointer and then locks.
- **The hand.** `god_hand.reach_gesture` is `"turn"`, or `"catch"` when the press caught a spin. `reach_point` is the grab point in plate coordinates, at ground height. The new `god_hand.reach_push` is the grabbed ground's velocity across the view (the world turns by minus the camera's yaw), and the gripping hand leans into it at `TURN_LEAN` (0.03 rad per m/s, at most 0.24) about its palm. The lean spring is underdamped, so the hand rocks back through upright when the push stops or lets go. A catch whose press starts painting keeps the brush's own gesture. Everything is cleared on letting go (a caught click holds the hand down for at least 0.4 s), and also whenever the rig stands aside.
- **In `god_hand.gd`**, `turn` and `catch` (`GRIPS`) ride the land's height like the pinch and the press, tilt fully with the slope, and are never lifted clear. The lean's pivot eases down to the palm while the hand grips.

### Clips

The clips live in `tools/blender_hand/god_hand_clips.py`, in the section "turn and catch". They are TurnIn (14 frames, touching down at frame 6), TurnHold (a 2 s loop), TurnOut (30), CatchIn (12, touching down at frame 4), CatchHold (the same loop) and CatchOut (the same as TurnOut). `god_hand_review.py --check` checks their hand-offs, and every gap is 0. Their peak accelerations are within the range of the existing clips. According to `--heights`, the kneading hold presses the ring and little fingertips up to 0.06 hand lengths into the ground (about 15 cm). The soft contact in the shader should hide this, but it has not been seen on a GPU.

## A fixed room

On screen, orbiting the camera and turning the world look the same, except for everything that belongs to the room rather than the diorama. So since 2026-09-28 the room follows the camera: the sky, the sun and the lights stay put while the diorama spins under them, like a model on a turntable under a fixed lamp in front of a fixed backdrop. The world's nodes are not moved. Terrain, water, creatures, physics, particles and the wind all stay in world space, and only the room turns with the camera.

- **The room's yaw.** `world_turn.gd` keeps `room_yaw`, which is how far the rig has turned the camera's yaw since the scene started. Every yaw change the rig makes while it drives the camera counts, and so does Space's idle drift (the scene adds it after the rig writes the pose). That covers a grab, a spin, a catch, a bat, a swipe, Shift+arrows, a glide and a focus. Tilt and zoom are still camera moves. Poses set from outside, such as a regrowth, the menu's Overview, photo mode or a capture tool writing `scene.yaw`, move the camera but not the room. The room's yaw is not saved: each launch starts with the room where the source put it.
- **What turns with the room.** `studies/celestial.gd` has a `room_yaw`, added to the ring's own yaw, so the sun and moon, the key light (`_sun`), the rim light (turned from its set-up orientation) and everything published from them follow: `zs_sun_direction`, `zs_moon_direction`, `zs_moon_shadow_direction`, `zs_key_direction`, `zs_rim_direction`, `zs_cloud_direction`, `zs_alpen_direction`, the rainbow, the sky's dusk glow and Belt of Venus, the water's sun glints and sky reflections, and the look pass's sun shafts. It also turns the aurora's heading (`zs_aurora.w`) and the meteor's streak. It publishes the new global `zs_room_yaw`, which the sky shader (`shaders/reference_sky.gdshader`) uses to turn the view direction back (`zsRoomDir` in `reference_sky_common.gdshaderinc`) before it looks up the Milky Way, the stars and the horizon hills. The hand's sun grab (`hand_reach.gd` `body_direction`) goes through the same ring, so it finds the disc where the sky draws it.
- **What stays with the diorama.** The cloud deck (`reference_cloud_field` / `reference_cloud_march`) is a 3D field over the plate. It casts its shadows on the land, is lifted over the plate's highest peak, and drifts with the wind, so it turns with the diorama, although it is lit from the room's sun. The peak clouds, mist and fog volumes hug the terrain and turn with it too.
- **Known limits.** These are in world space although they arguably belong to the room: the wind's direction (foliage lean, the drift of the cloud deck, blown leaves, pollen), the fall of rain and snow (along the wind), the lightning's placement, and the rainbow's faint drop texture. When the world turns, the wind turns with it. The cloud deck turning with the diorama is a choice, and the first thing to look at if the sky still reads as swinging round.
- **Cost.** One more global uniform, written once a frame. The rim light is set only when the room has turned, and nothing is baked again.
- `--classic-orbit` leaves `room_yaw` at 0, so everything is exactly as before.

Checked headless with `tools/probe_fixed_room.gd` (and `-- --classic-orbit`), 2026-09-28, both passing:

- **Grab** (-142.9°), **flick** (-1861.8°) and **idle drift** (4.7°). The room turned by exactly the camera's yaw. The aurora's heading turned by the same amount. The sun, moon, key, rim, alpen and cloud directions turned about the vertical by the camera's yaw (worst error 2e-6), so seen from the camera none of them moved.
- The hand's sun and moon directions match the sky's exactly.
- A pose written from outside (+57°) left the room unturned.
- `--classic-orbit`: a drag of 83° left the room at 0 and every direction unchanged.
- All 69 shaders in `shaders/` parse under the headless renderer with no errors.

**Not verified:** anything on screen. The sky is not rendered headless, so the stars, the horizon hills, the shadows and the shading have not been seen turning with the room.

## Choices made where the direction was open

- **Tilt stays on pixels, as before.** A true grab could also solve the tilt so that the grab point stays exactly under the pointer. The trouble is that the tilt's direction would then depend on where you grabbed: the near ground and the far ground pull opposite ways. The side-to-side is the lazy Susan, and up and down stays the familiar tilt.
- **The grab holds the bearing, not the screen point.** Only the yaw turns, so the grab point keeps its bearing exactly but slides in or out along it while a straight drag leaves the ground's circle. The hand stays on the grabbed ground and the pointer slides radially. This slide is measured below and is the first thing to judge on screen. If it feels loose, the next step is to also slide the pivot along the bearing (a small pan) so the point stays exactly under the pointer.
- **The far side turns the other way**, which is what a real turntable does. The old orbit always went the same way whatever you grabbed. It is also slower per pixel away from the pivot. Flicks make up for that.
- **Any press catches**, including one that paints. The catch is small (at most about 5°), so a stroke drifts a little at most.
- **No hand off the land.** A hand pressing on empty space reads wrong.
- **The flick keeps full speed.** The old fling carried on at 35 % for 0.22 s. The lazy Susan keeps the speed it was given, because that is the "weight".

## Checks

```
godot --headless --fixed-fps 60 --path . -s res://tools/probe_world_turn.gd
godot --headless --fixed-fps 60 --path . -s res://tools/probe_world_turn.gd -- --classic-orbit
```

Results from 2026-09-28, all passing:

**Grab.** A right drag of 360 px across the near land turned the world 86°.
- The grab point's bearing error stayed under 0.0001°.
- Its screen distance from the pointer grew to 27 px over the first 60 px of drag and 41 px over the whole drag. All of it is radial slip, collinear with the pivot.
- A grab on the far side, dragged the same way, turned the world the other way (18°).
- A drag held still for 0.2 s before release did not spin.

**Hand.**
- It gripped with `turn`, played TurnIn into TurnHold, and leaned 0.28 rad into the push.
- It let go afterwards.

**Flick.**
- A flick at 3.9 rad/s spun on 164°.
- The spin slowed every frame and ran down by itself in 3.65 s.
- Its last frame moved less than 0.004°.

**Catch.**
- A click mid-spin at 3.0 rad/s stopped the spin.
- The world overshot by 4.5°, came back past by 0.5°, and settled at exactly the catch yaw in 0.85 s.
- The hand played `catch` and let go.

**Painting.**
- A left drag with the land brush painted (one undo step).
- It did not turn the world, and the hand did not grip.

**Idle drift and A/B.**
- Space's idle drift still turned the world, and a grab stopped it.
- `--classic-orbit`: turn off, and a right drag orbited by the old pixel gain.

`studies/cozy_worlds.tscn` launched headless for 240 frames with no new errors.

**Not verified:** anything on screen. Nobody has judged how the grab, the spin, the catch or the hand feel in motion. That includes whether the radial slip reads as loose, whether the hand's grip looks planted, and whether its fingers sink too far into the ground.
