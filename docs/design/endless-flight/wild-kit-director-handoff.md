# Handoff: the happenings director (loop `wild-kit`, lane `wk-director`)

Spec: `spec-wild-kit-director.md` (beside this). Branch `lane/wk-director`,
worktree `/Users/davidkalina/Documents/Projects/zenscape-wk-director`. Each
step's commit (`git log --grep='^ITER(wild-kit): lane director'`) has its
decisions, checks and stills.

## Play it

From the worktree (`--pilot-file` keeps your own save out of it):

```
cd /Users/davidkalina/Documents/Projects/zenscape-wk-director
# The waterfowl: the title's Start takes off by the start's stream; ducks or a heron go off it ahead-right.
python3 tools/play.py --no-pull -- --pilot-file=/tmp/wild-kit-pilot.json --happen=waterfowl
# add --fowl=heron or --fowl=duck to pick the birds
# The cloud punch: fly into a tall cloud, then climb out of its top with the sun at your back.
python3 tools/play.py --no-pull -- --no-title --pilot-file=/tmp/wild-kit-pilot.json --happen=cloud_punch --hour=16.5
```

Without `--happen=` both are rare: the waterfowl fires at a takeoff near
water a quarter of the time (nine times in ten within 600 m of the start),
the cloud punch a third of the times you climb out of a cloud's top in the
right light; each then rests 10-15 minutes within 1 km.

## What's built

- **The director** (`scripts/endless/happenings.gd`, node `Happenings` in
  the endless scene). Moments (`scripts/endless/moments/moment.gd`)
  register with a name, the cue they listen for, an hour window, weathers
  (always "clear" until weather exists), where-predicates
  (`moments/where.gd`: region, near a placed site, the sun's height, the
  sun behind the plane), a chance and a cooldown. It watches two cues off
  the plane's own state, `lifted` (a takeoff) and `cloud_top` (out of a
  cloud's top, climbing, after 2 s inside), and asks only that cue's
  moments. One runs at a time. Rolls are seeded by the seed, the moment,
  the 1 km area and the try, so a replayed flight fires the same moments.
  The cooldown holds within 1 km of where a moment last fired.
- **Life reacts** (`scripts/endless/life_reacts.gd`): flush (up and away),
  bolt (off along the ground), look up (turn to track the plane), follow
  (trail along). A creature lists what it does in a `reacts` array; it
  poses its own body from `phase`, `velocity`, `facing` and `look`. With
  the knob `near` a flush, bolt or follow sits tight, watching, until the
  plane is that near (or `hold` s pass, or `rouse()`). Only the waterfowl
  use it so far; the elk lane can take up bolt and look up.
- **The cloud punch** (`moments/cloud_punch.gd`): by day (06-18:30, the sun
  3-40 deg up and behind the plane), out of a cloud's top: a double
  rainbow sweeps in and holds about 6 s (`celestial.moment_bow`), and frost
  grows in from the canopy's edges and melts to a wet film over about 5 s
  (`scripts/endless/canopy_frost.gd`, `shaders/canopy_frost.gdshader`),
  leaving drops on the wet layer.
- **The waterfowl takeoff** (`moments/waterfowl_takeoff.gd`,
  `scripts/endless/waterfowl.gd`): at a takeoff, it looks for open water
  ahead, preferring a spot about 25 m to one side of the plane's line
  (dead ahead, the plane hides them from the camera). 4-7 mallards, or a
  grey heron where it is under 0.6 m deep. They sit tight with heads
  turned to the plane until it is 60 m off (the heron 80 m) or going by
  to one side, then go as one, each a beat after the last: a run along the
  water with splashes and rings (the fish's, `endless_fish.gd`), a flurry
  of wingbeats (the heron croaks first), and a climb away, leaning along
  the plane's way so they stay in view. Built at the moment's start and
  freed at its end.

## Flags

- `--happen=<name>[,<name>]`: fire these moments every time their cue
  comes and their hour and place fit, past chance and cooldown. Names:
  `cloud_punch`, `waterfowl`. An unknown name warns with the list.
- `--happen=off`: no director.
- `--fowl=duck` / `--fowl=heron`: which birds (a heron needs shallows).

## The grass flush

`scripts/endless/grass_birds.gd` stays as it is. It draws nothing itself:
it picks a spot and hands a covey to `endless_birds.gd` on a read of speed,
height and meadow ahead every 0.25 s, with its own 45 s gap. It could move
onto the director as a moment (cue: low and fast over meadow; the
director's chance and area cooldown replacing its gap), but it fires often
by design and its read is a scan, so it would want a cheap cue of its own
first. Leave it unless asked.

## Open

- The start's flock appears at the lift, 60 m off, on a stream behind
  tall grass, so it isn't seen sitting before it goes. A `rolling` cue
  (the takeoff roll) could put the birds there before the lift.
- No quack: there is no duck clip in the assets.
- The frost's fronds are long streaks; branching would read more like ice
  ferns.
- Not driven: the flock rousing as the plane goes by to one side (no
  driven takeoff passed water that way). The sounds were checked started,
  not heard.

## Cost

Idle: two dictionary checks a frame and one cloud test every 0.1 s against
the cloud list the pilot's tallies already keep; no nodes. Running: the
frost is one canvas layer with one full-screen quad; the waterfowl are a
pivot and 4-5 MeshInstance3Ds and one AudioStreamPlayer3D a bird, a water
and land sample a bird a frame, no shadows. A takeoff's search tries at
most 132 spots (up to 5 water samples each), stopping early past the best.
