# Handoff: wild-kit (the wilderness kit's first build)

Spec: `spec-wild-kit.md` (beside this). Branch
`claude/game-world-expansion-2d681e`, draft PR #45, worktree
`/Users/davidkalina/Documents/Projects/zenscape-wilderness-kit`. The trail
is `git log --grep='^ITER(wild-kit)'`: each commit lists its decisions,
checks and stills. The master list is `wilderness-kit.md`.

The build is step 0 (placed sites), five lanes merged in (director,
uprights, falls, elk-body, elk-mind), and four trunk rounds (the real elk,
the herd off the stones, headings agree, a flight past every piece). The
user flew it on 2026-11-06 and kept it ("pretty great effect").

## Play each piece

Run from the worktree. Each line starts with:

```
cd /Users/davidkalina/Documents/Projects/zenscape-wilderness-kit && python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/wild-kit-pilot.json
```

Then add the piece's flags:

| Piece | Flags | How to fly it |
|---|---|---|
| The wreck's channel, stern to bow | `--at=103,211 --heading=-47 --alt=4` | Hold Boost and stay low. |
| The stone ring, in under gap 0's lintel | `--at=579,69 --heading=90 --alt=12` | Go in under the lintel and out gap 7 on the far side. |
| The herd, a run beside | `--at=60,145 --heading=90 --alt=40` | The herd is 600 m ahead. Drop under 24 m at cruise, without Boost, with the herd 20-40 m off your right. |
| The falls, in through the sheet | `--at=2350,30 --heading=-82 --alt=40` | Aim low at the sheet's middle, then bank gently left inside the cave. The exit gully is short, so don't drop low there. |
| The waterfowl takeoff | drop `--no-title`, add `--happen=waterfowl`, press Start | Ducks or a heron go off the stream ahead-right at the lift. Add `--fowl=duck` or `--fowl=heron` to pick the birds. |
| The cloud punch | `--happen=cloud_punch --hour=16.5` | Fly into a tall cloud, then climb out of its top with the sun behind you. |

Other flags: `--happen=off` turns the director off, `--elk=off` puts back
the herd's marker post, `--elk-body=standin` swaps in the stand-in elk, and
`--no-placed` drops every placed site.

Without `--happen=`, both moments are rare. The waterfowl fire at a quarter
of takeoffs near water. The cloud punch fires on a third of the climbs out
of a cloud's top in the right light. Each then rests 10-15 minutes within
1 km of where it fired.

## What's built

- **Placed sites** (engine): `scripts/endless/world/wilderness/placed.gd`
  is the hand list, one row a site: `[handle, kind, skin, x, z, heading,
  params]`. A row's heading turns the same way as `--heading`: clockwise
  from north, 90 is east. `scripts/endless/placed_sites.gd` builds each site
  as the plane nears it and frees it as it streams out. Moves and deletes in
  `layouts/endless_flight.json` win over the coded spot. A `clear` param
  keeps trees, rocks and generated sites out of a radius. A placed piece's
  `solid` answers the flight's crash test. `scripts/endless/kinds/kinds.gd`
  maps each kind's name to its script.
- **The happenings director** (engine): `scripts/endless/happenings.gd` and
  `scripts/endless/moments/`. It runs one moment at a time, keyed to place,
  hour and the sun, with seeded rolls and a cooldown per area.
  `scripts/endless/life_reacts.gd` holds the shared reactions: flush, bolt,
  look up, follow. Two moments so far:
  - the cloud punch: a double rainbow, and frost on the canopy that melts
    to a wet film;
  - the waterfowl takeoff: 4-7 mallards or a heron.

  See `wild-kit-director-handoff.md`.
- **Uprights** (kind, two skins): `scripts/endless/kinds/uprights.gd`.
  - `stones`: a ring of standing stones with a fallen one, lintels over
    some gaps, at `wild/meadow_ring` (770, 70).
  - `ribs`: a shipwreck's frames on the inlet's sand, plus a loose rib, at
    `wild/inlet_wreck` (15, 128).

  The gaps are sized by `WorldScale.opening`. The flats beside both pieces
  were proven by hand landings. The lane's last commit is 48920b54.
- **Curtain** (kind, `waterfall` skin): `scripts/endless/kinds/curtain*.gd`
  and `world/wilderness/waterfall.gd`, at `wild/river_falls` (1940, -25).
  The land is cut to an alcove with a 61.5 m drop and a plunge pool. A cave
  runs behind the sheet, through the hill and out to a gully on its south
  flank. The punch wets the screen, splashes, throws spray and drops the
  roar inside. See `wild-kit-falls-handoff.md`.
- **Ground escort** (kind, `elk` skin): the herd at `wild/meadow_herd`
  (660, 145), 8 elk with 2 bulls.
  - The mind is `scripts/endless/kinds/ground_escort.gd`. The herd watches
    you, runs beside you, leaps now and then, scatters to the trees,
    halts, looks back and drifts home. See `wild-kit-elk-handoff.md`.
  - The body is `scripts/endless/world/wilderness/elk_body.gd` on
    `assets/models/elk/elk.glb`. It has nine clips and LODs, and far elk
    are posed less often. Blender sources are in `art/blender/elk/`; the
    lane's last commit is 667fc35a.
  - The trunk added three things. Feet stand on the real land: the body
    pitches to the slope and each leg bends to it. The herd keeps out of
    placed pieces' solids, so it runs between the ring's uprights, never
    through them. The dust and the coat are lit when seen against the sun.

## Stood in

- **The falls' roar**: band noise pitched down. A real waterfall recording
  is an asset ask. Nobody has listened to it yet.
- **No quack**: the assets have no duck clip.
- **The herd's drift home is a trot**: the contract has no walk clip.
- **The stand-in elk** (`scripts/endless/kinds/escort_standin.gd`) stays
  behind `--elk-body=standin`.
- **The `marker` kind** stays for `--elk=off` and for new spots.

## Open

From the director:
- **The start's waterfowl can't be seen sitting.** They sit 60 m off at
  the lift, on the stream behind tall grass. The flight past every piece
  saw the same. A `rolling` cue (the takeoff roll) could place them before
  the lift.
- **The flock rousing as you pass to one side isn't driven.** Sounds were
  checked started, not heard.

From the falls:
- **The spray burst** is hard to see from the chase camera.
- **A thin blue zigzag strip** shows on the cliff right of the pool. Its
  likely cause is per-vertex water reads.
- **Looks:**
  - dark turf on the tube's floor;
  - tall grass in the exit gully;
  - jagged cliff triangles beside the exit face;
  - a clean rectangular sheet seen from the valley;
  - the thinned sheet reads like icicles from behind.
- **A build hitch of about 35-45 ms on the main thread** each time the
  falls stream in. Keeping the built piece, or building the solid off the
  thread, would remove it.
- **Model budget:** next would be vertex-colour grime in the cave, and a
  visibility range on the cave, mist and foam.

From the uprights:
- **For the user to judge:** the ribs' brown on the PC.
- **Possible LOD savings on the wreck:** drop its planking past about
  400 m, and add a second, coarser LOD.

From the elk:
- **The neck base creases** at the chest when the head turns far back.
- **One draw call per extra mesh:** a bull draws 3 meshes, so merging them
  would save 2 draws a pass.
- **Met in the wood's edge**, 1-2 elk can stay tucked, or one peels in the
  open.
- **The leap is the clip's height**, 0.43 m over the sprint's top. The mind
  could add an arc if it should go higher. `scratch/elk/beside.gd`'s one
  FAIL is this, against the stand-in's +0.6 m.
- **A herd that wakes again starts calm on its spots.** Its state isn't
  saved.
- **The run beside scores nothing yet.** The elk handoff has a plan for a
  `herd run` line move.

Judged good enough for now by the user:
- the frost's long streaks (branching would read more like ice ferns);
- the wreck's thin look side on.

The harness:
- `tools/harness/drive.gd`'s `let_go` leaves `fly_boost` and `fly_brake`
  held, so a driver must release them itself.

## Tests this build may break

The branch changes files that existed before it:
- `scripts/endless/arch_plan.gd`, `land_field.gd`, `land_stream.gd`,
  `rocks/rock_plan.gd` and `tree_plan.gd`;
- `studies/endless_flight.gd`.

The other changed files are new. One test under `tests/` reads any of the
changed files: `tests/test_cloud_shade_steady.gd`, which reads
`studies/endless_flight.gd`. It is `## suite: gpu`, so headless runs skip
it (`run_tests.py`: "Every matched test is skipped in this mode"). **It is
unverified.** It needs a rendered run, which the user has to ask for. No
other test names these files.

The smoke check of `studies/endless_flight.tscn` passes: 400 frames, 0
errors. The full suite wasn't run (prototyping).

## Drivers (git-ignored, in this worktree's scratch/)

- **The whole route:** `scratch/tour/tour.gd`. The command is in 97676c7c's
  Checks.
- **The elk:** `scratch/elk/`, with `beside`, `straight`, `home`,
  `senses`, `feet`, `ring` and `cost_beside`. Each needs
  `--layout=/tmp/wk-nowreck.json`, a layout file that deletes
  `wild/inlet_wreck` (d9095697 has its text).
- **The lanes' main drivers:**
  - `scratch/merge/fly_ring.gd` and `fly_cave.gd`;
  - `scratch/lanes/fly_wreck.gd`;
  - `scratch/lanes/fowl.gd` and `punch.gd` (the director's).

Run drivers one at a time: two at once have timed out.
