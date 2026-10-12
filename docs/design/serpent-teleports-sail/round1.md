# Serpent teleports, the aqueduct pop, the sail from low jumps: round 1

Branch `fix/serpent-teleports-sail`, from main at 5d2af458. Three things from
the user's playtest of main.

## 1. Sent home while riding the rune serpent

**Cause.** The hypothesis was half right. The off-the-edge rule
(`studies/kit_isle.gd` `_check_step_off` → `_step_off` → `_watch_off_edge`
→ `_strand` → `_return_to_plane`) is what sent him home, but it fired
because he really had come down beside the serpent. The step-off ray sees
the serpent fine: its hulls are on layer 1. The `lost` respawn in
`character_study.gd` never fired either. No frame had him grounded on it
while the rider said "still".

The real fault was in `scripts/kit_isle/serpent_rider.gd`. In the air off
its back he was carried by a frame held straight: the body's velocity
where he left it, kept constant. In the dip the serpent slithers at full
weave and turns south-west, so during a hop and a twirl (about 1 s) its
back slid 2 to 3 m sideways out from under him. His back's half width is
about 2.75 m. He came down past its flank and fell. Then he was more than
4 m under where he last stood with 12 m of open air below, so the step-off
rule fired. Another 20 m down he was stranded, and 3 s later he was put
back beside the parked plane on the home isle.

Headless, a rider on its spine with the stick let go, hopping every
1.15 s and twirling on two hops in three, fell off within 7 hops on main.
He was moved 166 m home in one frame.

**Fix.** While he is in the air over its back after leaving it, he goes
on with the place on its back under him, as if he still stood there. That
means within `AIR_OVER` (0.6 m) past its back's edge and under `AIR_HOLD`
(6 m) over its crest. Each frame he is moved by that place's move
(`SerpentBack.place` now against then), and his way and pace turn with
the body's turn. A hop or twirl comes down where it went on its back,
however the body slithers, turns or dives. Past its edge, or under the
sail, the old held-then-fading frame takes over from the last of that
move, so a jump off its side still carries its pace. `carries()` reports
"on it, or in the air over it", in case the isle ever wants it.

## 2. Walking under the aqueduct pops him onto its top

**Cause.** The hypotheses were wrong: it was not the ground ray, the step
smoothing or the motor's step-up. It was the water. The channel's pool
(`aqueduct_isle_art.gd` `pools`, its top at the deck plus 6 cm) is a flat
rect. `PilotPhysicsGround.depth` took that top minus the ground under his
feet. Under the arches the ground under his feet is the turf 10 m below
the deck, so it read 10 m of water over him. He swam, floated up at up to
33 m/s, and surfaced on the deck. Arches 2 and 3, over the near island,
did it all along their width. Arch 6's turf lies past the channel's
snapped end, so it never did.

**Fix.** `scripts/pilot_physics_ground.gd` `depth` now also reads the
pool's own bed, the ground seen from its surface. When the ground he
stands on lies more than `BED_UNDER` (0.3 m) under that bed, the pool is
over him, not around him: no water. Up on the deck the bed and his ground
are the same, so the channel wades as before.

## 3. The sail from low jumps

Jump and twirl timings are unchanged. Only the gate was loosened
(`scripts/pocket_sail.gd` `can_open`: room over the ground more than
`CLEAR + fall speed × CLEAR_AHEAD`).

| | CLEAR | CLEAR_AHEAD | from a plain jump over flat ground |
|---|---|---|---|
| before | 1.6 m | 0.2 s | never (the pump tops out at 1.5 m) |
| after | 0.25 m | 0.25 s | from about 0.04 s into the jump until just past its top (about 0.26 s of a 0.45 s airtime) |

Measured on flat ground with Space again near the top:
- held jump: opens at 0.79 m, glides 0.93 s and 2.6 m on;
- tapped jump (cut short): opens at 0.52 m, glides 0.77 s and 1.9 m on;
- running jump: glides 0.93 s and 4.9 m on.

Every one lands at the sail's sink (1.5 m/s), packed, and stays down. The
kick once an airtime is unchanged, so it pops up about 0.3 m first.

A press falling within the motor's jump buffer (0.15 s) of the touch is
still the buffered jump, never the sail, for both the plain jump and the
pump. That holds because the room asked grows with the fall speed faster
than the buffer's fall. The slam, the updraft and the off-the-edge sail
are untouched, and their tests pass. The skydive's sail shares the gate:
it can now open closer to the ground, and its test passes.

Tunables: `PocketSail.CLEAR`, `PocketSail.CLEAR_AHEAD`;
`SerpentRider.AIR_OVER` (and `AIR_HOLD`, `AIR_FADE` as before);
`PilotPhysicsGround.BED_UNDER`.

## Tests

- New `tests/test_serpent_hops.gd`: rides the dip hopping and twirling, at
  even and uneven frame rates (with 0.1 s hitches). Every hop lands on its
  back, nothing counts as off the edge or strands him, nothing moves him in
  a frame, and `lost` stays set aside. It fails on main (10 checks).
- New `tests/test_aqueduct_under.gd`: walks across through each open arch
  over turf at five points both ways, and along under the spans pier to
  pier, with no rise and no swim. It also walks the channel on the deck,
  wading. It fails on main (2 checks).
- `tests/test_pocket_sail.gd`: the old "Jump mashed over flat ground never
  opens it" became a plain jump over flat ground (held, tapped, running)
  opening it, gliding a little and setting him down soft. "Pressed just
  over the ground falling, it jumps on the touch" is kept and passes.
  `tests/test_pilot_motor.gd` keeps its check (Space again two frames into
  a jump: too close, no sail), relabelled.
- `docs/design/pocket-sail.md` was updated for the new gate.
- Also run, all passing: `test_serpent_route`, `test_serpent_ride`,
  `test_pilot_motor`, `test_slam`, `test_sky_dive`,
  `test_pocket_sail_study`, `test_plane_arc`, `test_walker_step_smooth`,
  `test_aqueduct_isle`, `test_aqueduct_isle_sail`. The headless import and
  the zenscape load check are clean. `test_aqueduct_isle_sail` failed once
  of three runs on "A gust front pushes harder" (1.46 m/s). That check
  reads gust timing, not the gate, and passed on the next two runs and on
  main.
- **Recordings shifted by the sail gate (not re-recorded):**
  `test_character_recordings` fails 3 on this branch against 1 on main.
  "Tech. Fun, fluid, movement" already fails on main. The two new failures
  are "village 1: long jump chain round the fountain, side flip, terrace
  (expert)", which ends 2.53 m off and strays at 1.68 s, and "village 5:
  surf the barn roof, long jump and twirl to the garden (expert)", which
  ends 4.08 m off and strays at 3.32 s. Both are Jump presses mid-jump that
  now open the sail. Putting back only `pocket_sail.gd`'s old CLEAR and
  CLEAR_AHEAD clears both. Re-record them if the new gate stays.

## How to try it

Windowed:
`/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path <wt> -- --no-title`

- `--serpent-board=home` starts on the home ledge with the serpent coming.
  Jump onto its back, ride into the dip, and hop and twirl on it.
- Walk under the aqueduct's arches on the near island, then up the rubble
  slope onto the deck and along the channel.
- Jump on flat ground and press Space again near the top. Off the
  serpent's back alongside the tarn, a jump and Space opens it straight
  away.
- `--part-at=fin` starts by the fin part, as before.

## What's rough

- Jump mashed through a long-jump chain now opens the sail mid-jump
  instead of only buffering the next jump. That is the cost of opening
  from any jump. The buffer is still protected near the touch.
- The kick at a low open is a small pop up. It reads as a little float,
  not a stall, headless, but it needs judging by hand.
- Hopping off its back while steering hard sideways (the twirl's push)
  still takes him off its side. That is a real step off, and the stranding
  rule still applies: more than 20 m under where he last stood, he goes
  back to the plane.
- The serpent fix carries him by its body's move at the place under him.
  It isn't judged by eye yet: a hop near its head while it swings may look
  stuck to the head.
