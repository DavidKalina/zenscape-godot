# Spec: burrower polish (`burrower-polish`)

Loop slug `burrower-polish`, trail prefix `ITER(burrower-polish):`, branch
`iter/burrower-polish`, from PR 33's head (`b55140ff`). Cap and budget: the
iterate skill's defaults. A prototype round (AGENTS.md, Prototyping): smoke
checks and throwaway checks in `scratch/`, no committed tests, no full suite.
Don't push; the user decides when this reaches the PR.

## Why

A rendered review of PR 33 found the items below. The user agreed to all of
them. The burrower already works end to end; this round changes how it reads,
not what it is. His speed, turning, catching him and his body stay out of scope.

Causes marked **lead** were read from code and not proved. Check one before
building on it.

## Order

The trail comes first, alone, because it sets the ground the other work is seen
against. Then the lanes run at once, each in its own worktree branched from the
trail's commit (`lane/<part>`). The lanes don't need each other. When they land,
the loop's owner merges them, smokes, and writes the handoff.

### Trunk 1: the trail (Sonnet)

What the player sees: a run across dry ground, a beach or a green meadow leaves
torn earth that belongs to that ground, not a painted strip.

- **Strip.** Today a hard-edged rectangle with square ends: bright green on dry
  tan ground, a rug on the beach. `scripts/burrower/game_land.gd` `colour` passes
  meadow as a literal 1.0 to `field.colour`, and `shaders/burrower_ridge.gdshader`
  uses only that vertex colour, with none of the terrain's dry patches, carpet or
  sand texture (`shaders/endless_ground.gdshader`). Match the drawn ground, and
  lose the hard edge and the square ends.
- **Scar.** The brown centre breaks into separated dashes like a road's centre
  line: the hash gates at `burrower_ridge.gdshader` (`ph`, `brk`, `break_len`,
  `break_share`). Keep it torn and uneven; lose the regular dashes.
- Where the trail runs through real long grass it already looks good
  (`wood_26_run` in the review stills). Don't lose that.

### Lane `sight` (Opus): sightings and the plume

What the player sees: flying at 100-200 m, a sighting 280-420 m off is something
they would notice without being told.

- In stills at about 200 m the wood showed only a few leaning trees and the plume
  was invisible. Stills hide motion, so film it or compare frames before deciding.
  `scripts/burrower/tree_shudder.gd`, the gust in `scripts/burrower/burrower.gd`,
  `scripts/endless/burrower_flight.gd`.
- He ran ashore during a sea sighting and the plume stopped (`if plume and wet`,
  `burrower.gd`). A water sighting should stay on the water. His roaming:
  `game_land.gd` `roam_goal`.
- Up close the plume is popcorn: opaque 6-segment spheres, alpha 0.85, no fade
  (`burrower.gd` `SPRAY`, the sphere mesh, `_plume`). It should read as spray.
- The rule: sightings are rare and never on the nose. Don't change that.

### Lane `water` (Sonnet): the wakes

- Sea: the V's shape is good, keep it. Its arms read tan and dashed, not foam.
  **Lead:** partial foam over the sand the water shows, cut by the fleck
  smoothstep (`shaders/endless_sea.gdshader` `zs_wake_track`, the `foamed` mix).
- River: the centre reads as a string of beads over a tan stripe. **Lead:**
  `murk` in `shaders/burrower_wake.gdshader`. The river's dark V is good, and
  the PR calls the river wake faint: it should read better than now, not worse.

### Lane `earth` (Sonnet): clods, the dome, the kicked bits

- Clods: near black from a distance, faceted camouflage rocks up close, dark
  blobs on sand. `burrower.gd` (`SOD`, `SOIL`, `PEBBLE`, the lerp to black),
  `shaders/burrower_soil.gdshader`, `shaders/burrower_grit.gdshaderinc`,
  `scripts/burrower/grit_mesh.gd`. Earth of the ground they came from.
- Dome at the head: a black core. **Lead:** `push_ups.gd` hands a linear colour
  as a Vector3 to a `source_color` uniform. Godot may or may not convert a
  Vector3, so find out before changing it.
- Kicked bits: big cream shards on dry ground (`meadow_18_run`). Source not
  traced. Find it, then size and tint them to the ground.
- Trail leftovers from Trunk 1: on dry ground the strip's fringe and the head
  mound still read greener than the straw ground (`shaders/burrower_ridge.gdshader`;
  the field's vertex colour is greener than the terrain's carpet paint). Also drop
  the unused `break_len` and `break_share` uniforms.

### Lane `trees` (Sonnet): trunk spikes

During the gust, dark trunk tips stand past the crowns in the play view
(`wood_14_run`). Not pinned down. The near spruce's trunk and crown appear to
share the gust (`shaders/conifer_wind.gdshaderinc`), but the trunk mesh's shader
wasn't confirmed (`assets/zen_reference/geometry.scn` is binary), and the sprite
(`shaders/endless_spruce_sprite.gdshader`) bends as one quad. Far and ring crowns
have no gust. Find what's actually drawn at that distance first. `shot_at`'s own
camera may misdraw sprites: judge in the play view.

### Lane `orb` (Opus): orb stretch and the climb-off

- Rising orbs stretch into a flat, tall pill with no shading (`wood_14_run`,
  `sea_15_close`). Settled they're a good round glow. Keep the rise's weight
  without the pill. `scripts/burrower/push_ups.gd`, `shaders/burrower_halo.gdshader`.
- A meadow run ended as `climb` at 15.7 s, most likely because the plane flew
  level off a cliff and the ground fell away (`burrower_flight.gd` `_running`,
  `_clear`). Prove that first. Leaving the ground that way shouldn't count as
  climbing off. Actual climbing still ends the run.

### Trunk last: merge

The loop's owner merges the lanes, smokes both scenes, looks at the stills and
writes `burrower-polish-handoff.md`.

## Round 2 (the user, after playing it)

Three lanes, branched from the merge of round 1. The user queued all three.

### Lane `dust` (Opus): the dust cloud reads like a GIF

The user: from up above, the dust cloud he leaves "reads like a GIF. It's at a low
frame rate, it pauses and then it repeats." Find which effect that is first: it may
be the run's dust (`shaders/burrower_dust.gdshader`, `_step_dust` in
`scripts/burrower/burrower.gd`), the sighting's chaff, thrown in gouts from the same
quads (lane `sight`), or a stepped update from the frame-rate cuts. A film at play speed
from about 100-200 m over him, compared frame to frame, should show it. What done looks
like: it moves smoothly at the game's frame rate, with no visible loop or hold.

### Lane `gust` (Opus): only the trees he's actually touching

The user: "the trees waking is great", but he isn't that wide, and trees far enough
off that he couldn't touch them wake too. "Tighten the radius of the trees that
actually wake in its path", so the ground he's working on is what moves them. His
trail is about 5-6 m wide. Today the gust is wide (a sighting's reaches 110 m each side,
with a gain from distance, `scripts/burrower/tree_shudder.gd`, `gust_strip` and
`gust_disc` in `scripts/endless/grass_react.gd`, `burrower_flight.gd`). The run's and the
sighting's both tighten, to a narrow band along his path: start from trees within about
8-10 m of his line and judge by eye.

That width was what made sightings read from altitude, so re-check them with
`scratch/pr33_see.gd`. The chaff and plume carry the sighting now: strengthen them if the
narrow line stops reading, rather than widening the gust. The lean and spring-back
themselves are good. Don't change them.

### Lane `move` (Opus): keep the player on their toes

This lifts the spec's "his speed and turning" out of scope, for this lane only. Flying
close behind him in a straight line takes the orbs without trying. The user wants him
to curve more, not fully erratic. In the game only: `at_head` runs, not the study.

1. **Orbs off the line.** `push_ups.gd` `_due_head` releases when he's within
   `HEAD_CROSS` (3.5 m) of the plane's line. Release as he's run on past it, about 8-15 m
   to the side, so reaching it takes a turn.
2. **Catch radius.** Cut or drop `ORB_MORE` (2.5 m), `burrower_flight.gd`.
3. **S-curves.** A slow left-right swing on his course in `_run_on`
   (`scripts/burrower/burrower.gd`), with more room before the pull back to the nose
   (`RUN_OFF`, `OFF_TURN`, `WANDER`). Long smooth arcs, not twitchy jinks.

An orb must stay reachable: never where the plane can't turn to in time at its speed.
Proof, through the stick: a bot flying straight takes 0-1 of 3; a bot chasing him takes
most. Add launch flags for the three numbers so the user can tune them while playing, and
list them in Look at. Feel is the user's call.

## Working rules, every agent

- **Look through the real thing.** `scratch/pr33_look.gd` and `scratch/pr33_see.gd`
  (copied into this worktree, uncommitted; a lane copies them to its own `scratch/`)
  find a spot and fly a run. `--kind=meadow|wood|sea|inland`, e.g.
  `python3 tools/drive.py scratch/pr33_look.gd --rendered --timeout=170 --log /tmp/x.log -- --kind=meadow --scene-args --seed=1 --alt=150 --pilot=fresh`.
  The meadow spot is the dry ground, the sea run crosses the beach. Stills land in
  `scratch/pr33/`. The review's originals, for before and after, are in
  `/Users/davidkalina/Documents/Projects/zenscape-burrower-review/scratch/pr33/`.
- **One window at a time, across every agent.** Wrap each rendered run:
  `python3 /tmp/zs_window.py -- python3 tools/drive.py ...`. It waits its turn.
- **The real save stays out of it.** Every run, smoke included, carries
  `--pilot=fresh` (`python3 tools/smoke.py studies/x.tscn -- --pilot=fresh`).
- **Don't flatten.** Judge at PC fidelity as well as the Mac's: at least one still
  at `--win=2560x1440`. Calming noise reads better on the Mac and loses depth on the
  PC. The look stays stylised, not realistic.
- **First rough look, then stop.** About 30-45 minutes to a labelled before and after
  a person can judge. Small commits. Don't polish past the first good read.
- No frame-time reads in lanes: parallel runs make them noise. Say what you added
  per frame, if anything, in Notes.
- No `git stash` (the stash list is shared and holds the user's work).
- Keep edits to shared files small. End a lane's commit with **Notes for merge**.
- macOS has no `timeout` and the machine has `python3`, not `python`.
- For a big still, pass `--win=2560x1440` after the driver's `--` (`tools/drive.py`,
  The window). Don't fork the tools.

## Proof

- Smoke: `studies/endless_flight.tscn` and `studies/burrower_study.tscn`, both PASS,
  0 errors. The study keeps working: the shared scripts drive it too.
- Each item: a before and after pair of rendered stills, looked at.
