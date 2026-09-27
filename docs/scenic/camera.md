# The creation camera

`scripts/camera_rig.gd` drives the camera in the creation shell
(`studies/cozy_worlds.gd` builds it next to photo mode). It answers one
complaint: the camera was hard to use. A first-time player expected to point
at something and go to it, and orbiting meant putting the brush away first.

## Controls

| Input | Mouse | Trackpad (Mac) |
| --- | --- | --- |
| Go to a thing | Double-click it, or point and press **F** | Double-tap / double-click, or **F** |
| Look around (orbit) | Right drag, Ctrl-drag, Alt-drag, a drag off the land; in Look a plain drag | Two-finger swipe; Ctrl or two-finger click-drag |
| Pan | Middle drag; arrows | Shift + two-finger swipe; arrows |
| Turn and tilt by keys | Shift + arrows | Shift + arrows |
| Zoom | Scroll, toward the pointer | Pinch, toward the pointer |
| Overview | **R** | **R** |
| Back to the view before | **Backspace** or **Home** | **Backspace** (the Delete key) |
| Paint the other way | Shift-drag | Shift-drag |

Why this mapping:

- **Double-click is the way to go somewhere.** A single click already paints
  with a brush in hand, and in Look a press bends a tree or picks up a rock, so
  a single click cannot also move the camera. A double-click reads the same in
  both. With a brush in hand, the double-click's first click has already laid
  a dab. If that still click left its own undo step, the camera takes the step
  back out (and drops it from redo), so going somewhere never changes the land.
  The water brush settles after release, so its first click opens no undo step
  yet. That tiny pour stays. **F** does the same without a click.
- **Right drag orbits, always.** Orbiting was the missing always-available
  move. Right drag used to work the brush the other way, which Shift-drag
  already did, so right drags now belong to the camera
  (`NativeChunkEditor.right_works_other_way = false` in the shell; the classic
  build keeps the old behaviour). Every brush hint says "Shift-drag".
- **Trackpads follow Blender's convention: a swipe orbits and a pinch zooms.**
  A trackpad has no easy right drag. The gesture that costs nothing, the
  two-finger swipe, therefore gets the move you need most: looking around the
  thing you just went to. Shift-swipe pans, as in Blender. Panning is needed
  less, because double-clicking the ground goes there. Before this change a
  swipe zoomed, and pinch zoomed too.
- **WASD and Q/E are not used.** **W** is the weather, **E** the season and
  **G** a gust. The arrows are free, so they pan, and Shift+arrows turn.
- **Zoom goes toward the pointer**, so scrolling over a pond moves you to that
  pond. While a creature is followed, zoom stays centred on the creature.

## Pointing and focus

`scripts/scene_inspector.gd` names what is under the pointer. Photo mode names
what a click lands on with the same code. It finds:

- LandLife's creatures (fish, frogspawn, frogs, birds, the heron, deer, the
  grass snake, and a Bigfoot sighting).
- Plants, stones and landmarks, through the object picker. It also finds a
  tree that Look's play has bent and a rock it has thrown; their instance is
  hidden while that play holds them.
- Ponds: the ray has to meet the pond's surface before the ground, and the
  bed has to stay under water all the way to the pond's middle.

Things found are `{kind, title, detail, point, size, base, reach}`.

**Hover.** A soft ring on the ground around the thing, and its name above it.
Both draw on a plain 2D layer, over the fog, and H hides them. In Look the
ring shows at once and the pointer becomes a hand. With a brush in hand it
waits until the pointer has rested for 0.45 s, and it clears as soon as the
pointer moves on, so it does not get in the way of painting. Hover is off
while you drag, while you paint, while something is held and in Craft.

**Focus.** Going to a thing sets the pivot to its centre. The distance fits
the thing: its size / tan(fov/2) × 1.5, between 2.4 and 45 m. The pitch stays
where it was, clamped to 1.0–1.28 rad (a little above the thing), and the yaw
stays where it was unless the land hides the thing. In that case it turns in
steps of 0.45 rad, alternating sides, to the first clear view. After that the
orbit circles the thing. The name and a line of its story (from photo mode's
records) show for 4.5 s.

**Follow.** A creature is followed. The pivot tracks it on a looser spring, so
a walking deer (1.2 m/s) trails by about a metre, and the ring stays under it.
Orbit and zoom keep following, because that is how you look at a creature
from its other side. A pan, a keyboard pan, a new focus, R or Back lets it go,
and so does the creature leaving. This departs from "any input releases follow"
on purpose: circling a heron as it wades is the point.

Double-clicking bare ground moves the pivot there (0.3 m above the ground),
with the same angle and distance.

**History.** Each focus, recentre and overview pushes the view it left, up to
8 views. Backspace and Home glide back through them.

## Feel

Every pose value is a critically damped spring toward a goal: the pivot, and
yaw, pitch and log distance. The distance eases in log space so a zoom from
60 m to 2 m feels even. There is no overshoot and no jerk at the start. A new
goal (another drag, a new focus) takes the move over from wherever it is,
velocity included.

| Spring | Frequency | 95 % | Settled (1 %) |
| --- | --- | --- | --- |
| Glide (focus, recentre, R, Back) | 7.5 /s | 0.63 s | 0.89 s |
| Hand (drags, swipes, wheel, pinch, keys) | 16 /s | 0.30 s | 0.42 s |
| Follow (the pivot on a creature) | 3.2 /s | 1.5 s | — |

- **Inertia.** A released mouse drag carries on at 35 % of the hand's speed
  (capped at 2.5 rad/s) and fades over 0.22 s. A slow drag ends where it was
  let go; a flick keeps turning a little. Trackpad swipes get no fling from the
  rig, because macOS sends its own momentum.
- **Limits.** Pitch runs from 0.22 to 1.45 rad and distance from 1.6 to 110 m
  (further only if the overview needs it). The pivot stays within 1.4 × the
  plate.
- **Ground.** The camera stays 0.7 m above the ground beneath it. When it
  would dip lower, the pitch lifts. Right over a steep rise, the distance
  grows instead. When a pan slides the pivot over the land, the pivot keeps
  its height above the ground (at most 4 m), so it climbs hills.

## How it drives the scene

The rig works the way photo mode does. It runs before the scene each frame
(`process_priority` −9; photo mode is −10). It writes its eased pose into the
scene's own orbit (`target`, `yaw`, `polar`, `distance`), and the scene places
the camera from that orbit as always. The fog, reflections, look pass and
`reference_tremor.gd` therefore read the same camera as before. The tremor is
still applied to the camera transform after the orbit.

- **Drags.** The scene still pools drag deltas (`_orbit_delta`, `_pan_delta`)
  from its own input handling, so Alt-drag, drag-off-the-land and Look drags
  are unchanged. The rig takes those pools each frame as goal changes and
  empties them, so the scene's old 5 %-per-frame easing has nothing left to
  apply. Scroll, pinch and swipe are taken in the rig's `_input`, before the
  scene's instant zoom sees them.
- **Poses set from outside.** A regrowth, the World menu's Overview, a new
  plain or a restored favourite sets a pose directly. The rig adopts that pose
  as it stands.
- **When it stands aside.** The rig is off in photo mode and during photo
  mode's return glide, behind the menu, during a regrowth, while a landscape
  is forming, and in the classic build. In Craft only the camera moves work;
  pointing, focus and the arrows are off there, and Backspace deletes as before.

## First session

One calm line under the top edge says: "Double-click anything to go there ·
right-drag or swipe with two fingers to look around · pinch or scroll to zoom
· Backspace goes back". It goes away for good in any of three ways: its ×
is pressed, the player has gone somewhere and also orbited, or it has been on
screen for a minute. H hides it with the rest of the chrome. The flag is kept
in `user://camera.cfg`. Probes (`movie_capture`) and the packaged self-check
never write the flag. The label, ring and hint are plain text and lines, laid
out from data, for the UI restyle to take over.

## Checks

`tools/probe_camera_focus.gd` (headless, `--fixed-fps 60`) builds a hill, a
pond and a small wood on the plain. It then drives the camera with
synthesized input:

- A double-click on a tree, with the land brush in hand.
- A right drag and its release.
- Swipes, Shift-swipes and a pinch.
- A 80-notch wheel dive into the hill, and a low tilt.
- R, then Backspace.
- A double-click on the ground and one on the pond.
- A stand-in deer walking away while it is followed.

For each glide it prints the settle time, the largest per-frame step and
change of step, direction reversals, the final distance and pivot, and the
least clearance above the ground.

```
godot --headless --fixed-fps 60 --path . -s res://tools/probe_camera_focus.gd
```

Results on 2026-09-27:

- The tree glide settles in 0.67 s with no reversal.
- The double-click's dab is taken back, with undo and redo unchanged.
- A right drag paints nothing.
- The wheel dive stops at 1.6 m, 0.87 m above the hill.
- Overview 1.1 s, Back 0.52 s, ground recentre 0.88 s, pond 0.8 s.
- The followed deer trails by at most 0.99 m.
- One hover inspect costs about 2 ms: about 1 ms is the terrain ray, which
  the brush pays every frame anyway. It runs at most every 0.12 s.

**Not verified headless:**

- The instance pick of drawn trees and rocks. The dummy renderer keeps no
  MultiMesh transforms, so the probe frames the tree from its record.
- Whether the ring, label and hint look right.
- The trackpad's real gesture scale and sign (`SWIPE`, `SWIPE_SIGN`: macOS
  reports 0.03 per point, and natural scrolling is assumed).
- Whether Godot turns a Mac Ctrl-click into a right click. The rig treats
  Ctrl + left drag as an orbit either way.
- How any of it feels in motion.
