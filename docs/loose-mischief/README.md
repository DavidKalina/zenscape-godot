# Things to throw

Use the existing `run-god-mode-playground.command` launcher in this worktree.
In **Hands** mode, hover a loose object for a glow and its name, then press and
drag. Swing the cursor and release to throw; hold it still before releasing
for a quiet drop. Small stones sit in the foreground, a log lies to the right,
and two larger boulders sit on the left slope. Other scenery stays anchored.

Stones follow the hand quickly and give Bigfoot a light flinch and glare. Logs
lag behind the hand, tumble and roll, and can take his feet out. Boulders take
more effort to move and roll downhill after release. When Bigfoot spots one
approaching, he tries to scramble to clear ground beside its path. If there
is no safe way to dodge, heavier contact uses his existing tumble/recovery. If an impact sends him into the pond, he switches to swimming,
paddles ashore, and shakes off.

Throw stones low and fast across the pond to skip them. Logs splash and float,
settling toward a horizontal orientation. Settled objects you have dropped
nearby can attract Bigfoot's attention and investigation.

**Esc**, focus loss, tool switching, or release over controls/outside the
viewport restores a grabbed prop without throwing it. **P** cancels a held
prop gesture and freezes physics; press again to resume. **R** resets Bigfoot,
all loose props, and water effects. Right-drag orbit, scroll zoom, lighting,
tree bending, wind and dragging Bigfoot into the pool remain available.

## Implementation

`play_loose_body.gd` owns solver-driven flight, rolling, contact properties and
water response. Stones and boulders use sphere collision proxies; the log uses
a horizontal capsule with two buoyancy points. All use the existing reference
scenery meshes and surface shader. Continuous collision detection handles fast
throws against terrain and anchored props.

`play_loose_props.gd` owns picking, bounded hand following, a short history of
held positions for release velocity, cancellation, and character interaction.
Swept contact proxies connect moving objects to Bigfoot's flinch and physical
tumble. Boulder anticipation predicts a near-term crossing and only chooses a
side-step when the terrain/navigation checks accept it. New settled objects
invite investigation through the existing creature brain.

Recovery chooses nearby clear footing if a rolling prop has occupied the
previous safe spot. The physical props share the solid collision layer, so live navigation checks
and landing clearance see their current locations. No terrain or navigation
rebuild is performed per throw. Objects leaving the small playground return
to their spawn locations. Selected boulders stay parked until grabbed, then use normal physics, so
the initial composition remains intact.

## Verification

The focused headless checks pass. `test_loose_props.gd`
exercises cursor throwing, stone contact/skipping, log contact/buoyancy, boulder
avoidance/downhill rolling, dropped-object investigation, distinct hand
weights, quiet drops, cancellation, pause and reset. Tree and water interaction
regressions pass. The full Metal/Forward+ recording was visually inspected;
its 2,708 decoded frames contain zero repeats. See `validation.json` and
`video-pacing.json` for evidence. Existing scene shutdown warnings remain.

## Limits

Contact shapes approximate the meshes; this is cartoon physics, not detailed
limb or fluid simulation. Boulder dodging needs safe neighboring ground.
Skipping depends on entry speed/angle and is limited to four bounces per toss.
There are six reusable loose props, with no inventory or prop-spawning tool.


## Reproduce the demonstration

```sh
Godot --path . --rendering-method forward_plus --windowed --resolution 1440x960 \
  --fixed-fps 60 --write-movie /tmp/loose-mischief.avi \
  --script res://tools/film_loose_mischief.gd
ffmpeg -i /tmp/loose-mischief.avi -c:v libx264 -crf 20 -pix_fmt yuv420p \
  -c:a aac -movflags +faststart docs/loose-mischief/loose-mischief.mp4
python3 tools/check_god_mode_video.py docs/loose-mischief/loose-mischief.mp4
```

The capture keeps its window visible and disables routine screenshot saves.
It demonstrates a real cursor-derived stone throw and boulder drag; later
scenarios stage physical releases to keep comparison and framing repeatable.
The MP4 and inspected images are local artifacts ignored by Git. Decoded-frame
checks detect held video frames, not foreground gameplay FPS. Controls and
complete sequences are visually inspected; no hands-on player feel testing is
claimed. Dedicated prop impact sounds are not included in this milestone.
