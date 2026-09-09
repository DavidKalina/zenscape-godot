# A little mischief

Launch `run-god-mode-playground.command` from this worktree. This opens a
preset clearing with an autonomous Bigfoot, a springy tree, a waterfall and
woodland planting. It uses the existing native terrain, atmosphere, navigation,
wind and creature systems.

## Play

- In **Hands**, hover the tall foreground conifer beside Bigfoot. Its root ring
  and cursor hint identify it. Drag its crown sideways to bend it; release to
  let it spring back. Pull farther for more tension. The small meter shows how
  much bend is stored.
- Branches can knock Bigfoot off his feet when their rebound reaches him.
  He watches your first pull, braces after repeated teasing, flails when struck,
  recovers, and looks back toward you. Gentle pulls earn a smaller reaction.
- **Show him the tree** invites him to investigate. Otherwise he explores on
  his own. Carrying him lets you experiment with his position relative to it.
- **Hands / Wind** switches tools. Wind retains the ground-drag gesture,
  strength choices, and **Try a gust** shortcut.
- Drag Bigfoot to carry him, or use **Pick up**. **Call him** gets his attention.
- Right drag orbits; scroll zooms. **P** pauses/resumes. **R** or **Reset** restores
  Bigfoot and the tree. **Esc**, loss of focus, or releasing over the interface
  cancels a tree gesture without causing an impact.
- Try **Meadow light**, **Amber evening**, or **Rose dusk**.

## Implementation

`PlaySpringTree` owns an elastic bend with a fixed root and a damped rebound.
The vertex shader and CPU share a constant-curvature centerline, normalized
against the reference conifer's actual crown height. Cursor picking samples
this bent shape, with terrain occlusion. Released branches use swept spherical
contact proxies around the same centerline. Contact velocity supplies an
impulse to `CreatureActor.receive_impulse`, which reuses the existing rigid
capsule, flailing animation, and safe recovery. An armed release can hit once;
held or canceled trees cannot hit.

The scene coordinates camera-projected dragging and temporary attention, while
the existing brain handles autonomous navigation. A small static root collider
keeps walking/placement away from the tree base. Camera, lighting and gust
controls remain available without entering the editor.

## Validation

- `tests/test_play_spring_tree.gd`: root anchoring, bounded pull, rebound,
  settling, one contact per release, cancellation and reset.
- `tests/test_god_mode_playground.gd`: camera-based pointer gesture, visible
  displacement, recovery, cancellation, focus loss, pause, reset and existing
  gust/carry behavior.
- `tools/film_god_mode_playground.gd`: repeatable pull/release sequence and
  selected rendered frames, with the interface hidden for the recording. Run
  with Forward+ and `--fixed-fps 60`; add
  `--write-movie /tmp/god-mode.avi` to capture a movie. The capture window stays
  visible and on top to prevent macOS from recording repeated, occluded frames.
  Add `-- --screenshots` for optional PNG saves (which add capture overhead).
- `python3 tools/check_god_mode_video.py <video>` checks decoded frame pacing
  for this continuously animated ten-second sequence. The original clip failed
  with 41 repeated frames; the replacement passes with zero. Live profiling
  found no distinct tumble/recovery spike; this does not establish foreground
  gameplay FPS. See `validation/tumble-diagnosis.json` for measurements.
- `validation/results.json`: full-suite results, with per-test logs alongside.

The complete suite plus focused rechecks finished at **135/144 passing** on
Metal / Forward+. Both new tests and all five targeted shared-creature checks
pass. All nine remaining failures also reproduce on the untouched starting
commit `07f2335`; `validation/summary.json` names them and `rechecks.json`
contains the paired baseline results. The first run was 131/144: correcting the
new test's Retina viewport setup and rechecking three unstable graphics tests
accounts for the difference. Existing shutdown resource warnings remain in
scene logs. This was a shared desktop, not an isolated performance benchmark.

Visual inspection covered the bent trunk/crown, branch strike, flailing and
standing recovery. The deterministic recording moves Bigfoot about 2.15 metres;
the pointer integration test measures roughly 2.1–2.4 metres across verified
runs and also confirms that
he resumes exploring. `tree-mischief.mp4` shows the sequence. It is a local
capture (ignored by Git); the capture script is committed for reproduction.
Input verification uses Godot input events and scene controls. A human feel
assessment is still useful; no claim of hands-on player testing is made.

Independent Standards and Spec review findings were addressed and rechecked;
see `REVIEW.md`.

## Limits

This milestone has one elastic tree. Other scenery remains static. The branch
contacts and Bigfoot's body are collision proxies, not articulated branch or
limb physics; limbs may intersect scenery while he tumbles. Bigfoot's reactions
are a small set of performances rather than persistent learned preferences.
Play state is transient. Rain/lightning powers, rock throwing, mountain
destruction and camper integration are future work.

## Water mischief

The same launcher now includes cursor dunking, paddling to shore, shake-off,
and an offended look. See [water mischief](../water-mischief/README.md) for
controls, implementation, and verification.

## Loose-object mischief

The same launcher also includes throwable stones, tumbling/floating logs, and
selected heavy boulders. See [loose-object mischief](../loose-mischief/README.md)
for controls, behavior, and verification.
