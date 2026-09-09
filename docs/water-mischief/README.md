# A very unplanned bath

Open `run-god-mode-playground.command` from this worktree. Use **Hands** mode,
press Bigfoot and drag him over the pool. The cursor lowers him into the water;
a cyan marker shows the pool target. Release to let him bob, paddle to shore,
shake off, and follow your cursor with an offended look. After a short pause,
he returns to his own exploration. You can grab him again while he swims or
shakes off. His head stays above water; there is no drowning or injury system.

The elastic tree, gust strengths, lighting choices, right-drag orbit, and
scroll zoom remain available. **P** pauses the interaction and effects. **R**
resets Bigfoot and clears splashes. **Esc**, focus loss, switching tools, or
releasing over controls/outside the window cancels a held dunk and returns him
to safe ground. Pausing a carry holds its position until you resume.

## Implementation

The playground deepens the existing waterfall pool without changing other
presets. `play_water_mischief.gd` caches the actual pond triangles for cursor
picking. On release, it searches for a dry exit and samples the entire approach
for solid props, missing terrain, and abrupt height changes. It prefers an
approach toward the camera so the shore reaction remains visible. If no route
is available, the existing safe-placement fallback handles the release.

`CreatureActor` adds swimming and shaking states. Swimming eases toward a
buoyant height, paddles toward the checked shore, and follows the sloping floor
as it leaves the water. Authored clips, additive hand targets, bobbing and a
brief torso shake provide the performance. These states suspend wind tumbling
and autonomous walking; ordinary pickup/reset can interrupt them. The scene
owns the brief cursor attention afterward.

Splashes reuse 64 droplets and eight ripple meshes. Terrain, navigation, and
particle resources are not rebuilt on dunking. This is a stylized animation
and movement system, not a fluid simulation or articulated swimming physics.

## Verification and capture

`tests/test_water_mischief.gd` covers camera-projected pickup and release,
submersion, splashes, swimming, safe shore, shake-off, reaction, autonomous
exploration, pause, repeat dunking, mid-swim/mid-shake pickup, reset, focus loss,
Escape, UI/outside release, and tool switching. See `validation.json` for the
executed checks and evidence. Existing scene shutdown resource warnings remain.

Reproduce the local demonstration with:

```sh
Godot --path . --rendering-method forward_plus --windowed --resolution 1440x960 \
  --fixed-fps 60 --write-movie /tmp/water-mischief.avi \
  --script res://tools/film_water_mischief.gd
ffmpeg -i /tmp/water-mischief.avi -c:v libx264 -crf 20 -pix_fmt yuv420p \
  -c:a aac -movflags +faststart docs/water-mischief/water-mischief.mp4
python3 tools/check_god_mode_video.py docs/water-mischief/water-mischief.mp4
```

Keep the recording window visible. Optional `-- --screenshots` adds PNG saves
through the shared capture helper; those files go to `docs/god-mode-playground`.
The MP4 is a local, ignored artifact. Decoded frame pacing checks recording
stutter; it does not establish live gameplay FPS. Validation uses automated
Godot input and visual inspection, not a hands-on player feel assessment.

## Limits

This milestone targets the playground's pond. Rivers and waterfall streams
do not initiate swimming. The loose-object update also connects physical
tumbles into the pond to swimming and shore recovery. Carrying
over the pool automatically dunks him; independent vertical cursor control,
water powers, wet-fur shading, and dedicated splash sounds are future work.
