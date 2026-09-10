# One animation: a shy tree peek

Open `run-bigfoot-tree-hug.command` for the isolated study. Space pauses;
R replays the same variation; Left/Right step by 0.1 seconds; the slider scrubs
through the whole performance. Escape closes the study.

This pass focuses on the tree interaction before applying its motion treatment to other
activities. Three sub-agents contributed animation direction, motion curves
and regression tests, and the isolated visual study. The broad environment
contact sheet remains a record of the earlier implementation.

## Acting

The character notices the tree, rocks back slightly, leads with one hand,
follows with the other, and settles his chest after the palms meet the bark.
He hides behind the trunk, leads with his gaze, leans sideways to peek toward
the viewer, then withdraws before releasing one hand after the other. A short recovery lets the action finish before ordinary
idle resumes. It takes approximately 9 seconds, plus arrival and rest.

The movement uses anticipation, contrasting slow/quick timing, curved reaches,
a single soft overshoot, and overlapping body/hand timing. Variation is sampled
once per performance: timing, amplitude, follow-hand delay and head tilt.
There is no per-frame random noise or perpetual sine-wave swaying.

## Integration

- `scripts/bigfoot_tree_hug.gd`: pure, deterministic performance sampler.
- `scripts/bigfoot_environment.gd`: hand trajectories, palm orientation, starting
  elbow capture, contact, approach, ownership and interruption.
- `scripts/creature_actor.gd`: neutral `TreeHugBase`, preservation of the settled
  lower-body pose, and additive chest/head performance. No root bobbing.
- `scripts/creature_tree_peek.gd`: upper-body offset and conservative head clearance.
- `tools/film_bigfoot_tree_hug.gd`: the replayable production-actor study.

The prior Idle clip carried its own glances and weight shifts, which conflicted
with the hug. The new base lets this action own its acting. A brief arrival
settle and per-performance lower-body capture eliminate sliding when entering
from a walking/turning pose. Body motion runs before hand IK, so palms stay
fixed while the chest settles.

## Verification

`tests/test_bigfoot_tree_hug.gd` exercises the actual actor after a navigated
approach. It checks fixed hand contact during settling, planted feet, smooth
entry/release, deterministic variation, cleanup, and 30/60/120 Hz behavior.
The current run measures approximately 0.003 mm foot drift, less than 0.002 mm
contact error, and matching poses between sampled frame rates.
`tests/test_bigfoot_tree_peek.gd` independently skins all 783 head vertices
across both peek directions and two trunk radii. Minimum measured bark clearance
is 5.76 cm, with approximately 33 cm of sideways reveal and retreat.
The approach levels his gaze before reaching, avoiding an inherited downward
head tilt. Releasing hands lower over 2.2 seconds with a 0.3-second stagger. Evenly
spaced vertical path controls avoid doubling the timing ease into a fast
central drop. During the final descent, shoulders then forearms settle into
their authored local rotations before IK fades; wrists follow the forearms.

Headless runs retain the previously observed Godot shutdown resource warnings.
Passing geometry tests establish contact and continuity; visual judgment still
belongs to the isolated real-time performance.

To record the study:

```
./run-bigfoot-tree-hug.command -- --film
ffmpeg -framerate 30 -i /private/tmp/bigfoot-tree-hug-frames/%04d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart \
  docs/bigfoot-tree-hug/gentle-reset.mp4
```

Generated frames, the hero pose and the video stay local under the repository's
existing capture ignore policy. Source and tests remain reviewable in Git.
