# Manual landing

Round 2 (drift) is on branch `study/manual-landing-drift`, cut from
`study/manual-landing` (61a3adb7) with main (3ecaabec, the isle lock) merged
in. Round 1 is kept below for reference. Its foot, stranded, flaps and
get-out rules all still hold. Round 2 replaces its touch and roll rules. The
game's default play is still unchanged: everything is behind
`--manual-landing`.

## Round 2: hit it hot, drift it to a stop

After flying round 1, the user said:

> I feel like the bounce is too aggressive. Like I really want to feel like
> you can go as hard as you want but you just might be too fast, right? Like
> I want to be able to hit the ground hard fast and then have to drift and
> slide and like power slide to stop. [...] I don't want to feel like you
> have to really slow down and do it right. I want to feel like you can kind
> of be a little chaotic as long as you can brake in time. And then if you
> don't, you just get back in the air.

### Launch

    ./run-landing-study.command                         # the study, station 1, normal approach
    ./run-landing-study.command --station=islet --approach=hot
    ./run-landing-study.command --station=short_ledge --approach=boost --bot=sharp
    ./run-manual-landing.command                        # the real game, by hand

In the study, H cycles the approach: normal, hot, boost. The Scenes picker
entries are the same as round 1's, with new detail text.

Bench, probe and trace, headless:

    godot --headless --path . -s tools/landing_bench.gd -- --runs 10 [--station islet] [--skills sharp] [--approach hot,boost]
    godot --headless --path . -s tools/landing_slide_probe.gd       # stopping distance for each way of stopping
    godot --headless --path . -s tools/landing_trace.gd -- islet sharp 1000 hot

Tests:

    godot --headless --path . --script tests/test_manual_landing.gd        # rules + study, about 3 s
    godot --headless --path . --script tests/test_manual_landing_game.gd   # the live game, about 25 s, tagged slow

### The touch (scripts/manual_landing.gd `grade`)

Almost every touch sticks. The grade decides how it feels, not whether it
lands:

| Grade | When | What happens |
|---|---|---|
| **greaser** | under 10.5 m/s along the ground, sinking under 1.2 m/s, wings within 0.2 rad, nose no lower than -0.2, not in an air drift | Two small settle hops, then a straight, tidy rollout. The study flashes "Greaser!", and the report says "GREASER! A tidy one". The game's hint says "Greaser!". |
| **firm** | within round 1's limits (10.5 m/s, 2.4 sink, 0.35 bank, -0.4 nose) but not a greaser | Sticks with a light thump. |
| **hot** | faster than 10.5 m/s | Sticks. The plane takes the hit (below), and you drift it to a stop. |
| **hard** | sinking over 2.4 m/s, or nose lower than -0.4 | Sticks. Takes the hit. |
| **wingtip** | a wing lower than 0.35 rad (a knife edge too) | Sticks. Takes the hit, and the nose is kicked round by up to 0.6 rad into a slide. This carries an air drift (knife edge + turn) straight into a ground drift. |
| tumble (hop) | mid barrel roll | Hops up with the wings put level, to come down again. Never a crash. |
| rough (hop) | land steeper than 0.4 m/m | Hops, as round 1's bounce did. |

**Taking the hit.** Its strength `k` (0 to 1) is full at 6 m/s of sink,
10 m/s over 10.5, or a wing right down. The hit gives you:
- a squash: the plane dips 0.16 m·k over 0.1 s
- a little hop that stays on the wheels: up 0.3 m·k over 0.34 s, with the
  phase staying ROLL throughout
- a speed loss of 0.25 m/s per m/s of sink
- loose wheels for 0.6 s·k, with grip down to 40%, so a hard touch skitters
  into a slide at the slightest steer
- the thump at a volume that scales with k, a camera shake, a pad pulse,
  and a dust burst (the study's `WheelSpray.burst`, plus the game's own
  `_puff` scaled 1 to 2.5)

**Off the edge** you are flying again, at the speed you had. There's a dip
first (the old drop). A sideways slide carries on as the air drift's `slip`,
so the travel swings back to the nose over about 0.3 s. There's no penalty.
The bots count it as a go-around.

**Calm air near the ground** (round 1's open issue). Rising air (wind.y > 0:
ridge lift, gust fronts) is scaled by smoothstep(1 m, 5 m) of the height over
the land, so nothing lifts at skim height and the full lift returns from
5 m up. Sideways wind is untouched. This is `ManualLanding.calmed`, and it
wraps the flight's `air` in both the study and the game. The live test
passes, but its loop still allows 4 tries per touch and does not count
them, so whether this removed the retries is unmeasured.

### On the wheels: a kart

**Gripping.** The tail wheel steers at 0.9 rad/s (a quarter of that
stopped), and the wheels hold the way the plane points. Rolling drag is
0.9 m/s² and the wheel brakes add up to 4.2 m/s².

**Breaking loose.** It starts sliding when any of these hold:
- the turn asks more than the grip: turn rate × speed > 7 m/s². At full
  stick that's anything over about 7.8 m/s, so a tidy slow rollout steers
  cleanly.
- **Q/E (LB/RB) is held with a real turn** (stick over 0.3): the air drift's
  button, so the two drifts share their controls.
- **Brake and steer at once**: a braked slide, and with the throttle too, a
  power-slide.
- the nose already points more than 0.35 rad off the track (a crab, a
  wingtip kick, or a drift carried down from the air).

**Sliding.** The nose swings to an angle off its track that the stick sets:
- drift: 0.6 rad (34°) at full stick, at 2.6 rad/s
- braked slide (Shift + steer): 0.95 rad (54°) at 2.8 rad/s
- **power-slide (Shift + steer + Space)**: up to 1.45 rad (83°) at
  5.5 rad/s. The prop's wash on the tail whips it round its wheels. A blip
  is enough: while braked, the tail stays where the blip swung it.

Speed is scrubbed by the larger of SCRUB (8.5 m/s²) × sin²(slip) and the
brakes' share along the wheels, plus rolling drag. So the more sideways it
goes, the harder it stops, and a power-slide beats a straight brake. The path
bends toward the nose at 1.1 rad/s: 80% less braked, 40% more with the lean.
So a drift curves round, and a power-slide goes nearly straight on while it
scrubs. Let the stick go and the nose swings back. It grips again within
0.12 rad. Throttle without the brake pushes along the nose, so you power out
of a drift. A touch-and-go needs gripping wheels, Boost and no brake at
9.5 m/s, so throttle held in a drift won't lift you off by surprise.

**Grit and hiss.** The wheels throw grit (`grit`, 0 to 1) at
speed × |sin slip| / 7 m/s while sliding. A straight brake throws up to 0.3
of it, full at 14 m/s. `scripts/wheel_spray.gd` turns this into a stream of
soft low-poly balls, kicked back and up by the slide and tinted by the
ground: turf in the study, `_puff`'s surface tints in the game. A looping
low-passed noise hiss rises with it.

**Stopped** means under 0.25 m/s for 0.25 s. It also counts with the
throttle held, as long as the brake is held (a power-slide that ends in
place). Stopped, Boost rolls off again only without the brake. Getting out
works as in round 1.

**Lean out of a slide:** the plane banks 0.12 rad per rad of slip, toward
the outside.

### Measured: stopping from a touch (tools/landing_slide_probe.gd)

Flat field, a firm touch, the input held until it stops. "On m" is how far
it went along the touch's way.

| touch m/s | way | on m | time s | peak slip ° | off line m |
|---|---|---|---|---|---|
| 8 | straight brake | 10.0 | 2.2 | 0 | 0.0 |
| 8 | brake slide (Shift + steer) | 8.4 | 1.8 | 54 | 1.1 |
| 8 | power-slide (+ Space held) | 6.9 | 1.4 | 83 | 0.7 |
| 8 | power-slide, 0.3 s blip | 6.6 | 1.4 | 83 | 0.6 |
| 14 (cruise) | coast | 107.6 | 15.5 | 0 | 0.0 |
| 14 | straight brake | 18.9 | 2.9 | 0 | 0.0 |
| 14 | drift, full stick held (curves round) | 3.9 | 5.3 | 33 | 15.0 |
| 14 | brake slide | 15.5 | 2.4 | 54 | 2.6 |
| 14 | power-slide | 12.6 | 1.9 | 83 | 1.6 |
| 14 | power-slide, blip | 12.0 | 1.9 | 83 | 1.5 |
| 22 (boost) | straight brake | 41.5 | 4.2 | 0 | 0.0 |
| 22 | brake slide | 32.6 | 3.4 | 54 | 8.0 |
| 22 | power-slide | 26.4 | 2.7 | 83 | 5.0 |
| 22 | power-slide, blip | 25.8 | 2.8 | 83 | 4.9 |

A power-slide stops in about two thirds of a straight brake's distance. A
drift held at full stick with no brake is a U-turn: it scrubs only gently
(about 3.4 m/s² at 34°), and the path curls round.

### Controls

| | Keys | Pad |
|---|---|---|
| Brake (straight, tidy) | Shift | LT |
| Drift | steer hard at speed, or hold Q/E and steer | LS hard, or LB/RB + LS |
| Braked slide | Shift + steer | LT + LS |
| Power-slide | Shift + steer + a blip or hold of Space | LT + LS + RT |
| Power out of a drift | Space (no brake) | RT |
| Touch-and-go | Space, straight, no brake, at 9.5 m/s | RT |

Everything else is as in round 1 (flaps F/Y, out F/Y once stopped, X eject).

### The study

- **Approaches (H, `--approach=`):**
  - normal: 170 m out, 24 m up, cruise. Time to slow down.
  - hot: 100 m out, 12 m up, cruise. You arrive fast.
  - boost: 150 m out, 14 m up, at 22 m/s. Hold Space to keep it.
- **The islet is now 24 m across** (it was 18). At 18 m, nothing could
  stop from cruise: a power-slide needs about 12.6 m plus your reaction. At
  24 m, a sharp pilot saves a cruise touch onto its rim, and only a perfect
  one saves a boost touch. The short field (30 m, ending at its ledge) is
  unchanged. A straight brake saves a cruise touch there, and a boost
  touch needs a power-slide.
- **F1 overlay.** The bars are now against a greaser's limits. In the air
  it shows what a touch now would be (a GREASER, firm, HOT: drift it, HARD:
  it sticks, a HOP). On the wheels it shows gripping, sliding or
  POWER-SLIDE, the slip, the grit, and the metres to the edge along the way
  you're going.
- **Report.** It shows the grade (GREASER! or "Stuck it: hot"), metres to
  spare at the stop, metres slid, peak slip and power-slides.
- **Run JSON** is format 2. It adds slip and grit ticks; slide, caught,
  thump and greaser events; and metrics for the approach, grade, greaser,
  slide_distance, peak_slip, power_slides, stop_margin and first_try.
- The touchdown mark under a low plane is now lit for "a touch now would be
  a greaser" (`would_grease`), in both the study and the game.

### The bots (scripts/landing_bot.gd, VERSION 2)

The bots' pace follows the approach:
- normal → **slow**: round 1's careful pilot, with brakes, flaps and flare.
- hot → **cruise**: no brake, no flaps, no flare. It aims 1.5 m in from the
  near rim and slams the wheels on.
- boost → **boost**: Boost held until 3 m over the land, then as cruise.

After any go-around, every bot comes back in slow.

On the wheels, after `brake_delay`, a bot compares the room ahead along its
way (`edge_margin`) with a straight brake's distance × `judge`, plus 3 m
spare. With room to spare it brakes straight. Without, it power-slides to
the roomier side, with `blip` seconds of throttle. `slide_let` is the chance
it lets the stick go too soon.

| skill | brake_delay s | judge | blip | slide_let |
|---|---|---|---|---|
| sloppy | 1.0 | 0.7 | none (braked slide only) | 0.3 |
| decent | 0.4 | 0.9 | 0.25 s | 0.1 |
| sharp | 0.15 | 1.05 | held | 0 |
| perfect | 0 | 1.15 | held | 0 |

### Bot metrics (10 runs each; perfect flies once)

From `tools/landing_bench.gd --runs 10`. Columns:
- **first try**: stopped on the first approach (no go-around, nothing off
  the edge, no touch-and-go)
- **touch m/s**: the entry speed it stopped from (mean over stopped runs)
- **saved m/s**: the fastest touch it stopped from first time
- **margin m**: metres to the edge at the stop

Hops were 0 throughout.

| station | approach | skill | stopped | first try | time s | touch m/s | saved m/s | greasers | slid m | peak slip ° | margin m | go-arounds | off edge |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| long_field | normal | sloppy | 10/10 | 10/10 | 18.0 | 10.3 | 13.2 | 3/10 | 0.0 | 0 | 54.5 | 0.0 | 0.0 |
| long_field | normal | sharp | 10/10 | 10/10 | 22.1 | 8.5 | 8.5 | 10/10 | 0.0 | 0 | 54.5 | 0.0 | 0.0 |
| long_field | hot | sloppy | 10/10 | 10/10 | 12.3 | 14.7 | 14.8 | 0/10 | 0.0 | 0 | 45.6 | 0.0 | 0.0 |
| long_field | boost | sloppy | 10/10 | 10/10 | 13.2 | 18.5 | 18.6 | 0/10 | 1.1 | 2 | 26.1 | 0.0 | 0.0 |
| short_ledge | normal | sloppy | 9/10 | 8/10 | 21.3 | 10.3 | 13.2 | 3/9 | 3.4 | 30 | 7.9 | 0.1 | 0.1 |
| short_ledge | normal | decent | 9/10 | 8/10 | 23.7 | 9.0 | 9.3 | 5/9 | 1.8 | 24 | 9.0 | 0.1 | 0.1 |
| short_ledge | normal | sharp | 10/10 | 10/10 | 27.1 | 5.8 | 6.0 | 10/10 | 0.0 | 0 | 19.2 | 0.0 | 0.0 |
| short_ledge | hot | sloppy | 8/10 | 1/10 | 44.3 | 10.5 | 14.8 | 2/8 | 15.1 | 54 | 9.6 | 0.9 | 0.9 |
| short_ledge | hot | decent | 10/10 | 10/10 | 10.1 | 14.7 | 14.7 | 0/10 | 4.6 | 38 | 5.5 | 0.0 | 0.0 |
| short_ledge | hot | sharp | 10/10 | 10/10 | 10.1 | 14.7 | 14.7 | 0/10 | 0.0 | 0 | 6.0 | 0.0 | 0.0 |
| short_ledge | boost | sloppy | 9/10 | 0/10 | 47.9 | 10.1 | - | 6/9 | 14.5 | 54 | 10.8 | 1.0 | 1.0 |
| short_ledge | boost | decent | 9/10 | 6/10 | 24.0 | 15.2 | 18.5 | 3/9 | 20.6 | 76 | 5.1 | 0.4 | 0.4 |
| short_ledge | boost | sharp | 10/10 | 10/10 | 9.4 | 18.2 | 18.3 | 0/10 | 20.2 | 83 | 6.0 | 0.0 | 0.0 |
| short_ledge | boost | perfect | 1/1 | 1/1 | 9.2 | 18.2 | 18.2 | 0/1 | 20.4 | 83 | 9.2 | 0.0 | 0.0 |
| slope_field | hot | sloppy | 10/10 | 10/10 | 11.2 | 14.7 | 14.7 | 0/10 | 0.0 | 0 | 14.9 | 0.0 | 0.0 |
| slope_field | boost | sloppy | 10/10 | 10/10 | 10.9 | 18.4 | 18.7 | 0/10 | 12.1 | 51 | 8.3 | 0.0 | 0.0 |
| slope_field | boost | sharp | 10/10 | 10/10 | 10.1 | 18.2 | 18.2 | 0/10 | 0.0 | 0 | 19.9 | 0.0 | 0.0 |
| islet | normal | sloppy | 9/10 | 5/10 | 38.0 | 10.3 | 13.3 | 3/9 | 8.2 | 52 | 7.7 | 0.5 | 0.5 |
| islet | normal | decent | 9/10 | 7/10 | 27.8 | 9.1 | 9.3 | 6/9 | 1.8 | 23 | 7.0 | 0.2 | 0.1 |
| islet | normal | sharp | 10/10 | 10/10 | 26.9 | 5.8 | 6.0 | 10/10 | 0.0 | 0 | 14.8 | 0.0 | 0.0 |
| islet | hot | sloppy | 5/10 | 0/10 | 47.6 | 10.2 | - | 2/5 | 12.6 | 54 | 7.7 | 1.0 | 1.0 |
| islet | hot | decent | 9/10 | 8/10 | 14.3 | 14.0 | 14.7 | 1/9 | 13.1 | 76 | 4.8 | 0.2 | 0.2 |
| islet | hot | sharp | 10/10 | 10/10 | 9.1 | 14.7 | 14.7 | 0/10 | 13.2 | 83 | 6.4 | 0.0 | 0.0 |
| islet | boost | sloppy | 8/10 | 0/10 | 51.9 | 9.8 | - | 3/8 | 7.8 | 43 | 7.8 | 1.1 | 1.1 |
| islet | boost | decent | 7/10 | 0/10 | 49.9 | 8.8 | - | 6/7 | 18.1 | 76 | 10.9 | 1.0 | 1.0 |
| islet | boost | sharp | 10/10 | 0/10 | 59.4 | 5.7 | - | 10/10 | 21.7 | 83 | 18.8 | 1.0 | 1.0 |
| islet | boost | perfect | 1/1 | 1/1 | 9.2 | 18.2 | 18.2 | 0/1 | 20.4 | 83 | 1.8 | 0.0 | 0.0 |
| crosswind | boost | sloppy | 10/10 | 8/10 | 20.4 | 16.5 | 18.6 | 0/10 | 13.2 | 54 | 5.0 | 0.2 | 0.2 |
| crosswind | boost | sharp | 10/10 | 10/10 | 10.7 | 18.1 | 18.1 | 0/10 | 0.1 | 0 | 25.6 | 0.0 | 0.0 |

(Selected rows. Every station × approach × skill row comes from the bench
command above.) The rows left out are all 10/10 first try: long_field and
slope_field at every approach and skill except those shown, and crosswind
normal and hot.

**How much entry speed each skill can save first time:**

| skill | short field (30 m to a ledge) | islet (24 m) |
|---|---|---|
| sloppy | none reliably (1/10 hot) | none |
| decent | cruise 14.7 (10/10), boost 18.5 (6/10) | cruise 14.7 (8/10) |
| sharp | cruise and boost (18.3) every time | cruise every time; boost never |
| perfect | boost 18.2 | boost 18.2, with 1.8 m to spare |

How to read it:
- Chaos is allowed. The long, sloped and crosswind fields take a boost
  touch from anyone. Time to stop falls from about 20 s (round 1's slow
  approach) to about 10 s.
- The short field and the islet are where drift skill shows. Sloppy, late
  and without a throttle blip, runs off and goes round. That costs about
  35 s, not a crash. Decent saves most cruise touches with a 0.25 s blip.
  Sharp holds the throttle through the slide and saves everything up to
  boost on the short field. Only perfect judgement saves a boost touch on
  the islet.
- Greasers are still what the slow, careful approach earns: sharp and
  perfect grease 10/10 on normal approaches.

### Tuning constants (scripts/manual_landing.gd, round 2)

| Constant | Value | What |
|---|---|---|
| GREASE_SINK, GREASE_BANK, GREASE_NOSE, GREASE_SLIP | 1.2 m/s, 0.2 rad, -0.2 rad, 0.12 rad | a greaser (also under TOUCH_FAST 10.5) |
| TOUCH_FAST, TOUCH_SINK, TOUCH_BANK, TOUCH_NOSE, TOUCH_SLOPE | 10.5, 2.4, 0.35, -0.4, 0.4 | round 1's limits: firm against hot, hard or wingtip; steeper ground hops |
| THUMP_SINK, THUMP_FAST | 6 m/s, 10 m/s | the hit's full (sink; over TOUCH_FAST) |
| THUMP_SCRUB | 0.25 | m/s lost per m/s of sink |
| SQUASH, SQUASH_TIME | 0.16 m, 0.1 s | the squash at a full hit |
| HOP, HOP_TIME | 0.3 m, 0.34 s | the grounded hop after it |
| LOOSE_TIME, LOOSE_GRIP | 0.6 s, 0.6 | loose wheels after a full hit; grip lost |
| WINGTIP_KICK | 0.6 rad | nose kicked round by a knife-edge touch |
| GRIP | 7 m/s² | sideways grip before the tail lets go |
| SLIDE_MIN, POWER_MIN | 2, 1.5 m/s | slowest drift; slowest power-slide |
| DRIFT_ONSET | 0.3 | stick that starts a drift with the lean held (as the air drift's) |
| SLIDE_SLIP, CATCH | 0.35, 0.12 rad | already that far off its track slides; grips again within |
| SLIDE_ANGLE, PIVOT | 0.6 rad, 2.6 rad/s | drift |
| BRAKE_ANGLE, BRAKE_PIVOT | 0.95 rad, 2.8 rad/s | braked slide |
| POWER_ANGLE, POWER_PIVOT | 1.45 rad, 5.5 rad/s | power-slide (throttle open) |
| SCRUB | 8.5 m/s² | scrub fully sideways (× sin² slip) |
| SLIDE_BEND, BRAKE_BEND, LEAN_BEND | 1.1 rad/s, 0.8, 0.4 | the path bends toward the nose; less braked, more with the lean |
| SPRAY_FULL, SPRAY_BRAKE, SPRAY_BRAKE_AT, EASE_GRIT | 7 m/s, 0.3, 14 m/s, 0.08 s | grit |
| SLIDE_LEAN | 0.12 | bank out per rad of slip |
| TAIL_DOWN | 1.2 s | tail comes down after the touch |
| CALM_LOW, CALM_HIGH | 1 m, 5 m | rising air calmed near the land |
| BOUNCE_* | as round 1 | now only the hop (tumble, rough), which also levels the wings |

Unchanged: ROLL_DRAG 0.9, WHEEL_BRAKE 4.2, PUSH 4.5, SLOPE_PULL 7 (now a 2D
gradient, so cross-slopes pull too), TAXI_TURN 0.9, TAXI_FULL 3,
LIFT_SPEED 9.5, STOP_SPEED 0.25, STOP_HOLD 0.25, SETTLE, LOW_PASS,
GO_AROUND.

scripts/wheel_spray.gd: AMOUNT 64, LIFE 0.75 s, SIZE 0.12 to 0.34 m,
KICK 4.5 m/s, HISS_DB -8, BURST 22 balls at 5 m/s.

### Files (round 2)

- `scripts/manual_landing.gd`: the rules, rewritten. The API changes:
  - `judge` is now `grade` plus `sticks` and `thump`
  - `would_land` is now `would_grease`, and `grade_now` is new
  - new: `sliding`, `slip`, `power`, `grit`, `calmed`, `edge_margin`
  - the `settled` event is now a {grade, k} dictionary
- `scripts/wheel_spray.gd` (new): the grit stream, the burst and the hiss.
- `scripts/landing_course.gd`: APPROACHES; the islet is now 24 m.
- `scripts/landing_run.gd`: the approach, format 2 metrics and ticks, and
  `going()`.
- `scripts/landing_bot.gd`: paces and the ground skill.
- `studies/landing_study.gd`: H, the HUD, the report, the spray and the
  scaled thump.
- `tools/landing_bench.gd` (approaches, new columns), `tools/landing_trace.gd`
  (an approach argument), `tools/landing_slide_probe.gd` (new).
- `scripts/wanderer_eye.gd`: `--manual-landing` events (hit scaled, burst,
  spray, hints for keys and pad), header paragraph.
- `scripts/scene_catalog.gd`: both entries' detail text.
- `tests/test_manual_landing.gd`, `tests/test_manual_landing_game.gd`.

### Unverified (round 2)

- **Nothing was looked at or heard rendered.** That leaves unseen and
  unheard:
  - the spray's look (ball size, count, tint, how it reads at speed)
  - the burst, the squash and hop pose, and the lean out of a slide
  - how the chase camera frames a plane sliding sideways (it follows the
    velocity, so the nose should swing across the view)
  - the hiss and the scaled thump
- **The feel.** All the angles, rates and scrubs are tuned against the bots
  and the probe only.
- **Pad.** The rumble scaling and LB/RB as the drift button on the ground
  haven't been tried on hardware.
- **Only the import and the two manual-landing tests were run**, both
  passing. The scene picker, plane, skydive, landing, gamepad and other
  tests weren't. Default play is unchanged by construction: every change in
  wanderer_eye.gd is behind `_hand()`.
- **Game specifics:**
  - A slide into a tree, rock or water still stops dead with a thump, as
    round 1's roll did. A hot slide on a wooded island will hit things often.
  - On real terrain the stop margin isn't shown. Only the study's HUD shows
    it.
  - Calm air near the ground is checked only by a unit test and by the
    live test passing (its retries are not counted). Whether slow
    approaches still feel floaty in strong wind is for the user to judge.
- The test run warns that 4 ObjectDB instances leaked at exit (round 1's
  run warned of 2). This was not chased. It is probably the spray's
  particle resources when the study is freed mid-run.

### Feel choices to judge

1. **Grip 7 m/s².** Full stick breaks loose above about 7.8 m/s. Lower
   makes everything slidier; higher makes drifts need the lean or the brake.
2. **The power-slide's swing** (83° at 5.5 rad/s) and that a blip holds it.
   Is the tail whip too fast or too much?
3. **Scrub 8.5 m/s² sideways** against a straight brake's 5.1. A
   power-slide stops in about two thirds of the distance. Is that enough
   reward?
4. **A drift without brake scrubs gently and curls round.** Steer and the
   lean together make a tight U-turn. Is that fun, or should a drift go
   straighter?
5. **The hit** (squash 0.16 m, hop 0.3 m, 0.6 s of loose wheels). Enough
   "took the hit", or too floaty?
6. **Islet 24 m.** Cruise is savable by sharp play, boost only by perfect
   play. Was 18 m with hot approaches being impossible the better tension?
7. **Hops only for a barrel roll into the ground or too-steep ground.** A
   wingtip-first touch sticks and kicks into a slide (air drift → ground
   drift). Should a full knife-edge touch hop instead?
8. **Greaser limits** (sink 1.2, bank 0.2, nose -0.2). Hard or easy enough
   to feel earned?

### Next steps

- Fly both: `./run-landing-study.command --station=islet --approach=hot`,
  then `./run-manual-landing.command`. Judge the feel choices above.
- Look at the spray and camera rendered, then tune the spray's look.
- In the game, consider letting a slide brush past small plants and only
  stop on trunks and rocks, so hot landings on wooded islands slide rather
  than stop dead.
- Maybe a small reward for a greaser: a sound, a token, or a count on the
  isle card.
- Round 1's open decisions still stand: the stranded rule, islets as
  landing spots, and making the flag the default.

---

'''

## Round 1 (for reference; its touch and roll rules are replaced above)

Branch: `study/manual-landing` (from main 3ecaabec). This round puts the
"true landing" into a greybox study first, as asked, and then into the real
game behind `--manual-landing`. The game's default play is unchanged.

The user asked for this:

> I really want the player to have to find a spot on the island. And
> actually land and like slow down and kind of come to a brake and then
> only then can they get out. I also want them to have to get back into the
> plane to fly.

### Launch

    ./run-landing-study.command                       # the greybox study, station 1
    ./run-landing-study.command --station=islet --bot=sharp
    ./run-landing-study.command --stranded=pickup     # the plane comes for you instead (see below)
    ./run-manual-landing.command                      # the real game, by hand, in the plane over home
    ./run-manual-landing.command --resume             # the same in your last world

Both are also in the title's Scenes picker: "Manual landing" under Flight
greyboxes, and "Landing by hand" under The game.

Bench and trace, headless:

    godot --headless --path . -s tools/landing_bench.gd -- --runs 20 [--station islet] [--skills sloppy,decent] [--save]
    godot --headless --path . -s tools/landing_trace.gd -- short_ledge sloppy 1000

Tests:

    godot --headless --path . --script tests/test_manual_landing.gd        # rules + study, about 2 s
    godot --headless --path . --script tests/test_manual_landing_game.gd   # the live game, about 20 s, tagged slow

### The rules (scripts/manual_landing.gd)

- **No auto-land.** F and the pad's Y never land the plane. In the air they
  lower and raise the flaps. On the wheels they ask to get out.
- **The touch is judged** on the step before the wheels meet the land. It
  is good only if all of these hold:
  - slower than 10.5 m/s along the ground
  - sinking slower than 2.4 m/s
  - wings within 0.35 rad of level, and not mid-roll
  - nose no lower than -0.4 rad
  - ground no steeper than 0.4 m per m
- **A bad touch bounces**, never crashes. It thumps, shakes the camera and
  pulses the pad, and the plane is kicked back up to go round. The kick is
  3.2 m/s plus half the sink, the nose goes up to 0.3 rad, it loses 1 m/s,
  and the wheels don't count for 0.7 s. It rises about 1 to 2.5 m. The
  hint or flash says why: too fast, too steep, wings not level, nose
  first, or ground too steep.
- **A good touch settles** with a small double hop, then rolls on its
  wheels:
  - It slows by 0.9 m/s² rolling, and up to 4.2 m/s² more with Brake held.
    From 8 m/s that is about 35 m with no brakes and 6 m with full brakes.
  - Slopes pull on it: uphill stops sooner.
  - The stick steers the tail wheel.
  - Boost pushes at 4.5 m/s², and with Boost held it lifts off at
    9.5 m/s (a touch-and-go).
  - Rolling off the land's edge, it flies again after a moment's drop.
  - Rolling into a tree, rock or water stops it dead with a thump (game
    only).
- **Stopped** means under 0.25 m/s for 0.25 s. The brakes hold and the
  engine idles. It never gets out by itself. F asks to get out: the engine
  spins down, the pilot hops out, and the plane stays parked where it
  stopped. F while rolling or flying is refused ("Stop first"). Boost
  stopped rolls it off again.
- **Nothing summons the plane** (game, and the study's walker):
  - A jump is only a jump. The held-jump flight is gone.
  - Walking off an island's edge (or an islet's) drops the pilot, carried
    on at their run, and the skydive canopy opens by itself 0.8 s later
    (X sooner). The plane stays parked. No other island is claimed on the
    way down.
  - Come down on the plane's own island and you walk back to it.
  - Once 20 m under the edge, or down anywhere else (another island, an
    islet, the sea, the island's rock skirt), you are **stranded**. After
    3 s you are back on foot beside the parked plane, still to board it.
  - Space by the plane boards it and takes off, using the old takeoff
    (BOARD, TAXI, ROLL, LIFT).
- **Ejecting (X) works as before**: the plane flies itself and lands near
  you on the island, and an eject into the sea is picked up by the plane.

#### What I chose on the open points

- **Air brake: flaps on F / Y, a toggle.** They suit a pad better than a
  hold, because the triggers are already busy. With flaps down:
  - the engine holds 5.5 m/s and the floor drops from 7 to 5 m/s
  - it sinks 0.5 m/s more
  - Boost overrides them, for a go-around

  Shift's brake alone gets the plane to 8 m/s, which is enough to land.
  Flaps are for short fields: the touch drops to about 5.7 m/s and the
  rollout to about 4 m. This is a new optional `flaps` input on
  `SkyPlane.step`. It is 0 unless asked for, so the plane flies exactly as
  before everywhere else.
- **Where a canopy landing puts you: back beside the plane.** A canopy only
  sinks, and an island's top is the highest land near it. So a step off
  the edge almost never lands back on the plane's island. A plane pickup
  would have you flying without boarding, which breaks "get back into the
  plane to fly". So a stranded pilot waits 3 s (the study fades to dark)
  and stands beside the parked plane, facing it.
- **The sea pickup by the plane** is kept only as a study variant
  (`--stranded=pickup`: wait 3 s, then you are flying, nose up over where
  you came down), for comparing the two. After an eject (X) the old instant
  pickup is unchanged, in the game and as the user asked.
- **No auto guidance.** The bots read the field like a pilot. The one cue
  is the game's existing touchdown mark under a low plane, which is now lit
  brighter when the hand judge says a touch now would land. That's a
  judgement call; it's one line to turn off (`would_land` passed to the
  plane figure's `update` in both scenes).
- **Stepping in with no plane parked** (the game, flag on) parks one beside
  the pilot. Otherwise a new world would have no plane at all. A flight
  set from outside (`--skydive`'s start, a set piece's N hop) takes the
  parked plane, so there is only ever one.

### Controls

| | Keys | Pad |
|---|---|---|
| Turn, pitch (W noses down) | WASD | left stick |
| Boost (and on the wheels, power) | Space | RT / A |
| Brake (and on the wheels, the wheel brakes) | Shift | LT |
| Flaps down or up (air) / get out (stopped) | F | Y |
| Knife edge, twice: barrel roll | Q E | LB RB |
| Open the canopy sooner | X | X |
| On foot: walk / board by the plane / hop | WASD / Space / Space | left stick / A / A |
| Study: stations, again, next, who flies, numbers | 1-5, R, N, B, F1 | |

### The study (studies/landing_study.tscn)

Five greybox fields, 500 m apart over a sea at -60 m. You start 170 m short
of each field, 24 m up, flying at it at cruise:

| Key | Station | What |
|---|---|---|
| 1 | long_field | 90 × 24 m, flat |
| 2 | short_ledge | 30 × 18 m, ending at a ledge; a lower shelf 22 m down beyond it |
| 3 | slope_field | 50 × 20 m, rising 1 in 7 away from you |
| 4 | islet | round, 18 m across |
| 5 | crosswind | 60 × 10 m strip, wind across it from the west, 2.5 ± 1 m/s gusting |

Each approach is a run (scripts/landing_run.gd). It ends when the plane
stops, or after 120 s. Its JSON goes to `user://landing_runs/`, and a report
shows:
- the time to stop and the rollout
- the good touch's speed and sink, and the first touch's if they differ
- bounces and why, go-arounds, touch-and-gos, rolls off the edge, and
  exits asked too early
- where it stopped

F1 shows the live numbers: speed, sink and bank bars against the limits,
height over the land, flaps, and "a touch now would LAND / bounce". After a
takeoff or a pickup, the next approach is a new run on the nearest field.

B cycles the pilot: you, then the sloppy, decent, sharp and perfect bots
(scripts/landing_bot.gd). A bot:
- holds the middle line by pursuit on its ground track, so it crabs in wind
- comes down a fixed glide path, flares (or forgets to), and brakes
- goes round after a bounce with little field left, a roll off the edge,
  or overshooting
- gets out once stopped

Skill sets when it descends and how steep, when it brakes, whether it uses
flaps, flare height, the chance of missing the flare, aim error and stick
noise.

#### Bot metrics per station (20 runs each; perfect flies once)

Means over the runs; time, touch, sink and rollout over the stopped runs.

| station | skill | stopped | time to stop s | touch m/s | sink m/s | bounces | go-arounds | rollout m | off edge |
|---|---|---|---|---|---|---|---|---|---|
| long_field | sloppy | 20/20 | 19.3 | 9.1 | 0.58 | 0.8 | 0.0 | 19.5 | 0.0 |
| long_field | decent | 20/20 | 19.8 | 8.8 | 0.88 | 0.0 | 0.0 | 10.4 | 0.0 |
| long_field | sharp | 20/20 | 21.9 | 8.5 | 0.55 | 0.0 | 0.0 | 8.0 | 0.0 |
| long_field | perfect | 1/1 | 30.1 | 5.6 | 0.53 | 0.0 | 0.0 | 3.0 | 0.0 |
| short_ledge | sloppy | 2/20 | 18.1 | 10.0 | 1.00 | 1.5 | 1.6 | 22.8 | 1.2 |
| short_ledge | decent | 19/20 | 25.5 | 9.0 | 1.01 | 0.0 | 0.1 | 10.3 | 0.1 |
| short_ledge | sharp | 20/20 | 26.7 | 5.8 | 0.56 | 0.0 | 0.0 | 3.9 | 0.0 |
| short_ledge | perfect | 1/1 | 28.9 | 5.7 | 0.53 | 0.0 | 0.0 | 3.2 | 0.0 |
| slope_field | sloppy | 18/20 | 17.3 | 9.3 | 0.85 | 0.8 | 0.0 | 15.4 | 0.0 |
| slope_field | decent | 20/20 | 18.2 | 9.2 | 0.90 | 0.0 | 0.0 | 9.3 | 0.0 |
| slope_field | sharp | 20/20 | 19.9 | 8.8 | 0.54 | 0.0 | 0.0 | 7.1 | 0.0 |
| slope_field | perfect | 1/1 | 29.1 | 5.7 | 0.53 | 0.0 | 0.0 | 2.6 | 0.0 |
| islet | sloppy | 0/20 | - | - | - | 1.4 | 2.0 | - | 0.7 |
| islet | decent | 13/20 | 46.4 | 9.3 | 1.44 | 0.0 | 1.0 | 9.5 | 0.7 |
| islet | sharp | 20/20 | 26.5 | 5.9 | 0.57 | 0.0 | 0.0 | 3.9 | 0.0 |
| islet | perfect | 1/1 | 28.8 | 5.8 | 0.53 | 0.0 | 0.0 | 3.2 | 0.0 |
| crosswind | sloppy | 19/20 | 21.5 | 8.8 | 0.59 | 0.7 | 0.1 | 18.1 | 0.1 |
| crosswind | decent | 20/20 | 20.1 | 8.3 | 0.87 | 0.0 | 0.0 | 9.4 | 0.0 |
| crosswind | sharp | 20/20 | 22.4 | 8.3 | 0.54 | 0.0 | 0.0 | 7.6 | 0.0 |
| crosswind | perfect | 1/1 | 23.0 | 8.4 | 0.50 | 0.0 | 0.0 | 6.8 | 0.0 |

How to read it:
- The long field forgives everything. Sloppy bounces about once and still
  stops.
- The short field and the islet are where skill shows. Without flaps and
  prompt brakes a good touch still rolls off the end. Sloppy stops on the
  islet 0 times in 20, decent 13 times.
- The sloped field is a little easier than the flat one, because uphill
  stops you.
- The crosswind strip barely bites at 2.5 ± 1 m/s with the bots' crab. The
  rules don't judge drift at the touch: in this flight model the sideways
  part of the velocity is the wind's and can't be flown out. Its difficulty
  is staying on a 10 m strip.
- Perfect is the slowest to stop, because it uses flaps everywhere but the
  wind.

### Tuning constants (round 1 values)

scripts/manual_landing.gd:

| Constant | Value | What |
|---|---|---|
| TOUCH_FAST | 10.5 m/s | fastest good touch, along the ground |
| TOUCH_SINK | 2.4 m/s | hardest good sink |
| TOUCH_BANK | 0.35 rad | most bank (any barrel roll bounces) |
| TOUCH_NOSE | -0.4 rad | lowest nose |
| TOUCH_SLOPE | 0.4 m/m | steepest ground |
| BOUNCE_UP, BOUNCE_GIVE | 3.2 m/s, 0.5 of the sink | the kick back up |
| BOUNCE_PULL | 9.0 m/s² | how fast the kick dies |
| BOUNCE_NOSE | 0.3 rad | nose thrown up to |
| BOUNCE_SCRUB | 1.0 m/s | speed lost |
| BOUNCE_GRACE | 0.7 s | before the wheels count again (after a lift-off too) |
| ROLL_DRAG | 0.9 m/s² | rolling, throttle closed |
| WHEEL_BRAKE | 4.2 m/s² | full wheel brakes |
| PUSH | 4.5 m/s² | throttle on the wheels (PlaneLanding PUSH) |
| SLOPE_PULL | 7.0 m/s² per m/m | slope's pull |
| TAXI_TURN, TAXI_FULL | 0.9 rad/s, from 3 m/s | tail-wheel steering (a quarter of it stopped) |
| LIFT_SPEED | 9.5 m/s | touch-and-go lift-off (PlaneLanding LIFT_SPEED) |
| STOP_SPEED, STOP_HOLD | 0.25 m/s, 0.25 s | what counts as stopped |
| SETTLE, SETTLE_TIME | 0.09 / 0.025 m, 0.26 / 0.16 s | the good touch's two small hops |
| LOW_PASS, GO_AROUND | 3 m, 8 m | a go-around: under LOW_PASS over the land, then over GO_AROUND without stopping |

The getting out reuses PlaneLanding BEAT_TIME 0.35 s, HOP_TIME 0.5 s and
SPIN 0.35 s.

scripts/sky_plane.gd (new, off unless `flaps` is given): FLAP_SPEED
5.5 m/s, FLAP_SLOW 5.0 m/s, FLAP_SINK 0.5 m/s.

scripts/wanderer_eye.gd, under the flag:

| Constant | Value |
|---|---|
| STEP_OFF_OPEN | 0.8 s |
| STRAND_BELOW | 20 m |
| STRANDED_WAIT | 3 s |
| SHAKE_TIME, SHAKE | 0.4 s, 0.3 m |

studies/landing_study.gd: the same step-off numbers (STEP_OFF_OPEN 0.8,
STRAND_BELOW 20, PICKUP_WAIT 3, FADE 0.5); SHAKE 0.35 m. The thump is a
0.22 s, 58 Hz decaying sine.

### Files

- `scripts/manual_landing.gd`: the rules, as plain state and maths.
- `scripts/sky_plane.gd`: the `flaps` input.
- `scripts/landing_course.gd`, `landing_run.gd`, `landing_bot.gd`: the
  study's fields, runs and CPU pilot.
- `studies/landing_study.gd` / `.tscn`, `run-landing-study.command`.
- `tools/landing_bench.gd`, `tools/landing_trace.gd`.
- `scripts/wanderer_eye.gd`: `--manual-landing`. See the header paragraph
  and the "By hand" section. Every change is behind `manual` or `_hand()`.
- `run-manual-landing.command`, `scripts/scene_catalog.gd` (two entries).
- `tests/test_manual_landing.gd`, `tests/test_manual_landing_game.gd`
  (slow).

### Unverified

- **Nothing was looked at rendered.** Everything ran headless only. That
  leaves unseen:
  - the greybox fields' look
  - the camera framing on the roll (`chase.cine`), the shake and the hop out
  - the study's capsule walker, its foot camera, and the canopy and its
    camera over the study
  - the fade and the touchdown mark's new brightness
  - how the thump sounds
- **The pad's rumble and Y as flaps/exit** haven't been tried on hardware.
- **How it feels to a person.** The thresholds are tuned against the bots
  only.
- **Only the import and the two new tests were run** (and the scene picker's
  entry checks, which also smoke-run both new entries for 6 to 9 s without
  script errors). The existing plane, skydive, landing and gamepad tests
  weren't. Default play is unchanged by construction: every new path is
  behind the flag, and flaps default to 0. Those tests have not confirmed
  it.
- **Game findings worth a look:**
  - Over the island the wind's ridge lift and gust fronts lift by up to
    6.5 m/s. That can hold a slow plane up just over the ground. The live
    test needed retries and a push of the nose to touch down on some seeds.
    Landings into a windward slope may feel floaty, or impossible in a
    strong wind.
  - The plane rides over tree crowns as before, so it can't land among
    trees. It floats over a wood and on off the island.
  - The island's solid reaches a little past the walkable land outline.
    Stepping just off the shore onto that rock skirt counts as stranded.
  - Islets: the plane can't land on one under the flag. It skims them and
    the old perch from the plane is off. Under `--below` the old rules hold.
  - After an eject, the plane still lands itself near you on the island
    (kept, as asked). That's the one way the plane still comes to you.

### Next steps

- Fly both. Judge the thresholds, the bounce's height and the brake
  strength first.
- Decide stranded "return" against "pickup" (`--stranded=pickup` in the
  study).
- Decide whether the touchdown mark's "would land" brightness stays.
- Calm the ridge lift and gusts within a few metres of the ground for a
  slow plane, or decide they are part of the challenge.
- Give the plane somewhere to land on an islet (park on islets), or rule
  islets out of landing for good.
- If it stays, make the flag the default and retire PlaneLanding's line-up
  half and the old F landing, keeping its takeoff.
- Optionally, a crosswind rule that judges the crab (nose off the track at
  the touch) rather than the drift.
