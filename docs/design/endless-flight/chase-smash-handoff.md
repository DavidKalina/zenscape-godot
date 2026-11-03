# Smash through the chase, and a live meter: handoff

Spec: `spec-chase-smash.md`. Branch `iter/chase-smash`, not merged. Follow him into a sunk
tunnel. Spurs come as singles, pairs, gates and corkscrews. A surge on a full meter shatters
a spur into rubble and flies on. He brings a plug of rubble down behind him, a wall across
the bore with one hole: thread the hole, or surge and smash the whole wall. The meter now
climbs as each moment scores, not when the line banks.

## Fly it

```
cd /Users/davidkalina/Documents/Projects/zenscape-chase-smash && python3 tools/play.py -- --no-title --pilot-file=/tmp/chase-smash.json --at=3400,4384 --heading=90 --alt=60
```

That meets him on the axis of mouth `1_1/a`. `1_1`'s plug is at s 1230 (about 23 s in).
From the side, into `-1_1/a` (plugs at s 330 and 1005):

```
cd /Users/davidkalina/Documents/Projects/zenscape-chase-smash && python3 tools/play.py -- --no-title --pilot-file=/tmp/chase-smash2.json --at=-1486,6874 --heading=56.7 --alt=80
```

Surge is B, or Z (the roll) on a full meter. A full meter is spent over 2.5 s
(`SURGE_TIME`), and the smash stays hot until it's empty.

## What each commit did

- `40d5537b` The surge shatters spurs: `scripts/endless/bore_rubble.gd` (pooled bursts, two
  shaders), `BoreSpurs.struck/smash`, `SurgeSmash._spur`, the `smash` moment
  (`LineMoves.smash`, `line_tune.json` base `smash` 2.0).
- `7431b007` Spur patterns in `BoreSpurs.plan()`: single, pair, gate, corkscrew. The gap
  rule is checked per spot.
- `7ae45020` Plugs: `scripts/endless/bore_plug.gd`. The tell, the drop, the hole, the crash
  outside it, a thread through it (`BorePlugs.crossed`, read in NearMiss).
- `f0591281` The surge smashes the whole plug: two rubble bursts, a `smash` moment marked
  `smashed: "plug"`.
- `fba84e78` / `341b40e9` Lane `meter`, merged: the meter fills live (`near_miss.gd`), the
  bank only scores, `lose()` keeps the meter, no refill while surging, and the HUD flares
  on each rise.
- This round: pacing (below), and one fix. A surge pressed just after threading a plug
  smashed it as well, so the plug was scored twice. `BorePlugs.struck` now skips a plug
  whose middle the plane has passed.

## Pacing

Changed:

- `line_tune.json` `meter_full` 10 -> **16** units (1600 points to fill).
- `bore_plug.gd` `PLUG_COUNT` 1 -> **2** (at most), `PLUG_APART` 300 -> **600** m,
  `PLUG_ROOM` 32 -> **60** m off any spur. At 32 m, `1_1`'s plug sat 53 m (1 s) past
  the cavern's big spur at s 442, with its hole 8 m off the middle. The scripted pilot
  scraped or crashed there in most runs.

Plugs per tunnel now: `1_1` one (s 1230), `-1_1` two (330, 1005), `-2_1` two (1295,
2015), `1_-1` one (520). With 60 m kept clear of spurs, spots are scarce, so the second
plug only fits in some tunnels. A lower `PLUG_APART` would give more tunnels a second
plug, but it would also move `-1_1`'s second one.

Pattern weights are unchanged (`WEIGHT_SINGLE` .35, `PAIR` .2, `GATE` .25, `CORKSCREW`
.2): the fill rate already lands in the target, and how the mix feels is for you to judge
by flying it.

Measured with the scripted pilot through the real input (stick, Boost, the surge key held
through `fly_surge`), flown from inside mouth A. Each run starts with an empty meter. A
fill means the meter reached full during the chase. The pilot spends a full meter on the
next thing ahead that's within 60 m.

| Tunnel | Pilot | Chase | Fills in the chase | Crashes | Notes |
|---|---|---|---|---|---|
| `1_1` | wide (8 m past each spur) | 37.7 s | 1 (at 21.5 s) | 0 | 1 scrape. The surge smashed the plug |
| `1_1` | close (2.5 m off spurs) | 36.5 s | 2 (6.4 s, 20.8 s) | 0 | the plug smashed |
| `1_1` | close (3.5 m) | 36.6 s | 2 (6.4 s, 20.9 s) | 0 | a 3rd fill 2.6 s after the far mouth |
| `-1_1` | close (2.5 m) | 29.8 s | 2 (5.8 s, 20.4 s) | 0 | both plugs threaded, a spur smashed, a 3rd fill after the mouth |

At the old `meter_full` of 10, the same pilots got 2 fills in `1_1` (wide) and 3 (close),
and 2 in `-1_1` before a crash. A person who grazes more than this pilot fills faster.

Where the meter comes from in a tunnel (close pilot, `1_1`): canyon runs about 1200-1500
points, pull-outs 900-1100, grazes 500-700, the plug's thread about 500. The canyon run is
the biggest earner in the bore, more than the spurs. Grazes are few: in a corkscrew near
the crown, the crown is the nearest stone, so the stone tracker stays on (never re-arms)
and a graze isn't counted as a spur's. A spur and a plug smash each score base `smash`
(about 390-420 points), but while the surge is hot they add to the score, not the meter.

`meter_full` is global, so the open world now takes 1.6x as much flying to fill as well.

## Checks on the final code

- Smoke of `studies/endless_flight.tscn`: PASS, 400 frames, 0 errors.
- The four whole runs above (`scratch/spurs.gd --pace`): 0 errors, chase ended "out" in
  each.
- Plug plan per sunk tunnel (`scratch/plug_plan.gd`): every tunnel has at least one, 4
  checks, 0 failures.
- The thread-then-surge fix: in `-1_1`, the meter filled on the plug's thread and the
  surge was pressed 11 frames later. The plug wasn't smashed or scored a second time. A
  surge from in front still smashes it (`1_1`, both close runs).
- Earlier rounds' checks (patterns' gap per spot, the spur smash, plug thread, ram and
  smash, stills) are in their commits. They ran before this round's constants and weren't
  rerun.

## Unproven

- **Whether a person fills it once or twice.** The pilot's grazes are few and its fills
  come from canyon runs and pull-outs. A close-flying person may fill faster.
- **The scripted pilot is fragile.** With these constants, the wide pilot crashed into
  `-1_1`'s plug at s 330. One close run crashed into a spur in `1_1`'s cavern (s 594)
  without the pair-aware line (`--spots`). The patterns-aware runs above made it. In
  earlier rounds every crash I read was the pilot's line, not a forced one. Flying it
  yourself is the test.
- The pilot's surge at 60 m short of `1_1`'s spur 4 smashed nothing: it didn't turn in
  in time. A surge that hits nothing spends the whole meter.
- `1_-1` and `-2_1` not flown this round.
- Not run: the full suite (prototype rules). No test in `tests/` reads `meter_full`, the
  bore's plugs or spurs, so none is known broken.

## Loose ends

- The smash's dust whites out the view for about 10 frames as you fly through a plug.
  It reads as flying through the wall. Trim it if it bothers you.
- A plug and a spur both score base `smash`. A plug might deserve its own key.
- A spur grazed and then smashed by a surge just behind scores both (`BoreSpurs.struck`
  pads the sweep). The plug case is fixed. The spur case was left alone.
- The plug's wall reads flat and dark up close. A rubble look is a later pass.
- Headless runs now and then print `Parameter "m" is null` from `shop_sites.gd`
  (dummy renderer, known).

## Knobs

`scripts/endless/line_tune.json`: `meter_full` 16, base `smash` 2.0.
`scripts/endless/near_miss.gd`: `SURGE_TIME` 2.5.
`scripts/endless/bore_spurs.gd`: `WEIGHT_*`, `AFTER_*` (room after each pattern),
`CORK_STEP` 24, `CORK_TURN` 0.14, `TOY_GATE` 5, `TOY_PAST` 4.
`scripts/endless/bore_plug.gd`: `PLUG_COUNT` 2, `PLUG_APART` 600, `PLUG_ROOM` 60,
`PLUG_ENDS` 170, `TOY_PLUG_HOLE` 6, `HOLE_OFF_MOST` 8, `HOLD_S` 1.1, `DROP_S` 0.42,
`SMASH_*`.
`scripts/endless/surge_smash.gd`: `SPUR_KICK`/`SPUR_STOP`, `PLUG_KICK`/`PLUG_STOP`.

## Throwaway drivers

`scratch/spurs.gd` is the pilot. New this round: `--pace` (logs every moment and the
meter, counts fills, and on a full meter surges at whatever is within `--press` m, 60 by
default, aiming into a spur), `--grazeall --tip=M` (pass every spur M m off),
`--spots` (aims clear of every spur at a pair's or gate's spot), `--stonelog=S0,S1`
(the stone tracker per frame), `--nosurge`, `--noram`. Older ones: `--plugthread`,
`--plugram`, `--plugsmash`, `--smash=N`, `--patshots`, `--plugshots`.
`scratch/plug_plan.gd` lists plugs and spur patterns per sunk tunnel. `scratch/spurs_gap.gd`
checks the gap.

Under zsh, pass a pilot's flags as separate words: an unsplit `"--grazeall --tip=2.5"`
is read as one unknown flag.
