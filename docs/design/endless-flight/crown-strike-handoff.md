# The Peak's strike: handoff

Round of 2026-10-31 on `claude/mountain-peak-visual-polish-d83e07`, not pushed. Lightly proved on purpose: the user will
judge it by flying it, and a proofs round comes after that. Frames are in the git-ignored `scratch/strike/shots/`.

## What it does

While you climb the mountain, the tip of a spiral notices you and comes down after you. One strike runs at a time.

1. **Gather** (1.5-2 s): the spiral spins faster, its tip draws in, and a head runs on along the coil.
2. **Rear** (0.9-1.2 s): the head leaves the coil, turns to you and holds, swaying.
3. **Run:** it hunts at 125-145 m/s. It swings wide so the body shows side on, weaves, hugs the land, leans into gullies
   and goes round the towers. It leads you and steers at a limited rate.
4. **Lunge:** from 380 m it goes straight at 160 m/s for where you'd be if you held your line. Hold it and you're hit;
   leave it and you aren't. Rock in its way breaks it.
5. **Recoil:** it spools back up its line and the spiral goes back to idle.

The body is the ribbon's own formula, same noise and same light, with the tower's axis swapped for a bent line, so it's a
twisted rope of the spiral's cloud with a fat head. The idle spirals don't change; the new `tip_left` uniform is 1 at idle.

**The hit** is a push of wind through the air callable, not damage: back and down, away from the mountain, the nose
dropped and the wings tipped. The stick stays live. It tries seven ways round for one clear of rock, and lifts off land
coming at it. Cues: the `jet` camera kick, a low whoosh at the tip, a roar that builds (`fall-roar-loop`), a slam
(`wind-slam`), and pad rumble.

**When:** only while climbing (over 4-12 m/s up) above 520 m over the sea and near the crown. It waits 2.5 s, then 15 s
between strikes at the shoulders and 7 s at the spires, each times 0.8-1.3, counted only while you climb there. It picks
the spire most ahead of you and avoids repeating one. Under 30% of the way up, strikes are warnings aimed 170 m wide. It
reaches 140 m over the highest tip and no higher.

**Backing off:** it goes home if you land, leave, or come inside 420 m of the plateau under 170 m over the strip. No
strike starts there and no shove lands there. A stream crossing the plateau stays 70 m over the strip.

## Flags

- `--peak-strike=0`: none.
- `--peak-strike=SECONDS`: forces a strike that long after launch and every SECONDS after, wherever you are. Don't pass 1,
  which means on. `--peak-strike-spire=0|1|2` picks the spire.
- For a driver: `study.strike.force(i)`.

## Numbers to tune

All at the top of `scripts/endless/peak_strike.gd`:

| What | Constants |
|---|---|
| Cadence | `FIRST_WAIT`, `GAP`, `GAP_SPREAD`, `SHOULDER`, `SPIRE_FOOT`, `WATCH`, `CLIMB`, `RANGE` |
| Telegraph | `GATHER_TIME`, `REAR_TIME`, `REAR_OUT` |
| Hunt | `SPEED`, `TURN`, `LEAD_MAX`, `LEAD_SHARE`, `SWING`, `WEAVE`, `RUN_MAX` |
| Dodge window | `LUNGE_FROM`, `LUNGE_SPEED`, `LUNGE_TURN`, `HIT_R`, `NECK` |
| Shove | `WIND`, `RISE`, `FALL`, `DOWN`, `NOSE_DOWN`, `NOSE_TURN`, `WINGS` |
| Land | `HUG`, `HUG_NEAR`, `GULLY_TURN`, `REACH_OVER` |
| Look | `GIRTH`, `SLITHER`, `FLOW`; `PITCH`, `COIL`, `WIDE`, `THICK` in `shaders/peak_strike.gdshader` |
| Keep-out | `KEEP_R`, `KEEP_OVER`, `KEEP_FLOOR` |

Roar: `STRIKE_ROAR` in `flight_sound.gd`. Spiral spin-up: `ROUSE_SPIN`, `ROUSE_TIP` in `peak_spirals.gd`.

## Proved, lightly

Seed 1, medium, a bot on the real stick with a wobble, climbing up the front. The sweep stopped at the user's word, so
these are one partial run, not a table. Dodge bots break 0.25 s after the lunge begins.

- Strikes fire on the game's own trigger and reach the plane. Holding the line was hit nearly every time.
- Shove, measured 3 s after a hit: about 135 m off the path, 95-100 m of it back, with the plane 6-37 m lower than at the
  hit despite climbing. Speed recovered in that time (53 m/s with Boost, 33 without). No crashes or scrapes in any run.
- Far from the spires: about 11 s from the first notice to arrival, 8-9 s of it visible running, from about 1350 m.
- Turning away: 4 of 6 dodged with Boost, 3 of 9 without. Diving: 5 of 8 with Boost, 4 of 9 without.
- Smoke passes on `endless_flight`, `--world=regions` and `--peak-strike=0`, 0 errors.
- Frames: the rope uncoiling off the tip and running out reads well from a distance. From the plane, the head seen coming
  head-on reads as a swirling ball growing.

## Tests

No test under `tests/` names the spirals or `flight_sound`, so I know of none this breaks. The suite wasn't run.

## Weak

- **Dodging without Boost is hard** at the bot's late break. The plane moves too little in the lunge. Try a longer
  `LUNGE_FROM` or a slower `LUNGE_SPEED`.
- **Near the spires** the run can start already inside `LUNGE_FROM`, so it goes straight to the lunge: the 2.5-3 s of
  gather and rear, then about 2 s. That's the shortest warning in the game.
- **Coursing the land:** it hugs the land, but frames show much of it in open air. It follows no real ridge or gully
  route, only feelers. It doesn't take a gorge on purpose.
- Head-on from the plane the body hides behind the head; only the swing shows it.
- The stream draws over the spirals whichever is nearer. The lighting block is a copy of the spiral's.
- The body itself doesn't push; only the head and the last 70 m do.

## Not verified

- Flown by hand, or motion at full frame rate. Frames were one every 0.4 s.
- Frame cost. The shader on a big stream and the first-strike compile hitch were not measured. The material is drawn
  for 8 frames at load to build its shader; whether that prevents a hitch is unknown. Land reads are 42 us each: 4 at
  10 Hz in a run, up to 21 once on a hit, by estimate.
- Landing on the strip with no interference, and strikes in the gorges. The gating is read, not flown. A wall close by
  is the likeliest place for a bad shove.
- Rock as shelter, warning strikes, recoil and rock-break frames. Sound and rumble by ear or hand.
- Other hours of the day. Other flight proofs (`crown_matrix`, tours) now meet strikes unless passed `--peak-strike=0`.
