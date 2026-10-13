# Headless body, round 2 (greybox)

Round 1 is in `headless-body-round1.md`. This round adds three things:
ledge-to-ledge jumps, shockwaves on every heavy landing, and bodies that
come up the side of an isle. Search, climb, reunion and the contact shove
are unchanged.

## What's in

1. **Ledge-to-ledge jumps.** At an edge, the body first looks across the
   gap for a ledge at about its own height. If the far rim is within
   `jump_gap` (3 head heights, about 10 m) and its top is no more than
   `jump_rise` higher or `jump_sink` lower, it jumps there. The arc is
   longer and flatter than a drop and peaks at `jump_arc` of the jump's
   length. Only when no such ledge is in reach does it fall back to round
   1's drop onto a lower floor.
2. **Shockwaves.** Every leap or drop landing sends a wave along the
   ground, and so does the end of a mantle (a smaller one).
   - **What you see:** a thin bright ring at the front, a dust wall behind
     it that rises and sinks, ten stone chips kicked up, a bigger camera
     quake, and a deep thump (`body_shock`).
   - **Size:** a harder landing makes a bigger wave. Power runs from 0.6
     to 1.5, and a fall of one head height is 1.
   - **What it does to you:** the wave reaches you at about 18 m/s. If
     you're on the ground in its band, it throws you back and up through
     `PilotMotor.knock`, less the farther out you are. If you're more than
     `shock_air` off the ground as it passes, you're clear, so you can
     jump it. Riding his shoulders, you ride it out.
   - It does no damage. It replaces round 1's instant landing shove.
3. **Cliff-side spawns.** The body can now start on a cliff face, already
   climbing, with its raised hands `cling` (1 m) under the lip. It hauls
   itself over, slams down a mantle wave and starts searching.
   - The study has seven spawn points (`CLIFFS`, one is under the south
     rim of A by your start). By default the body is no longer stood on
     A. It comes up the A south cliff about 2 s in, in front of you.
   - **One body per head: a spawn replaces the body.** There is still one
     head and one body. A spawn takes the current body away, and if that
     body had its head, the head goes back to its ring. When the head
     has no body (at the start, after R, or after the body falls off the
     world), a new one comes up the best cliff after `wait` s.

The study layout changed so it shows all three on the way to the head:

| Isle | Top | What happens there |
|---|---|---|
| A, the low isle | 0 m | You start here; the body comes up its south cliff |
| B, the mesa | 16 m | It climbs B |
| E, the step | 16 m | 6 m gap from B: it **jumps** across, level |
| F, the far pillar | 16 m | 12 m gap from E, too wide: it **drops** onto C instead |
| C, the shelf | 6 m | The floor under the gaps. It climbs F's south face from here |
| D, the crown | 17 m | 4 m gap from F, 1 m higher: it **jumps up**. The head is here |

There's a ramp up the west side of B, and one from C up to D. The pocket
sail does the rest.

## Run it

    ./run-headless-body.command
    ./run-headless-body.command --body-start=stand              # round 1's start: the body stood on A
    ./run-headless-body.command --spawn-knob=natural=0          # only G spawns
    ./run-headless-body.command --body-knob=jump_gap=2 --body-knob=shock_r=6

- **G** brings a body up a cliff now. It picks the best cliff that meets
  the rules. If none does, it picks the one that comes closest. New key.
- **R** takes you back to the start with the head back and the body gone,
  so a new one comes up the cliff again.
- **F1** now also shows jumps, the last leap's kind (jump or drop), the
  shocks sent and how many threw you, the jump gap in metres, the cliff
  spawns, and which cliff would fire next while there is no body.

## New knobs

Lengths are in head heights (Hh, 3.36 m at `head_size` 3) or in your
`unit` (1.12 m).

**Body (`--body-knob=`)**

| Knob | Default | What it sets |
|---|---|---|
| `jump_gap` | 3.0 Hh (10.1 m) | Widest gap it jumps ledge to ledge |
| `jump_rise` / `jump_sink` | 0.5 / 1.5 Hh | How much higher or lower the far ledge can be |
| `jump_arc` | 0.22 | Arc peak as a share of the jump's length (at least `leap_up`) |
| `shock_r` | 4.0 Hh (13.4 m) | Wave radius at power 1 (× √power) |
| `shock_speed` | unit × 16 (17.9 m/s) | How fast the front runs out |
| `shock_out` / `shock_up` | unit × 9 / unit × 2.2 | Throw at the middle, at power 1 (m out, m up) |
| `shock_edge` | 0.2 | Share of the throw left at the rim |
| `shock_band` | unit × 1.7 | How far above or below the wave's ground you can be and still be hit |
| `shock_air` | unit × 0.45 | Height off the ground that clears the wave |
| `shock_mantle` | 0.5 | Power of the mantle's wave |
| `cling` | 1.0 m | How far under the lip its hands start on a cliff spawn |
| `haul` | 0.55 | Climb pace once its hands are on the lip (was fixed at 0.55) |

`shock_r`, `shock_out` and `shock_up` replace round 1's landing shove
numbers. `shock_r` is now in Hh, not metres.

**Spawns (`--spawn-knob=`)**

A natural spawn needs all of these. G ignores any it can't meet.

| Knob | Default | Rule |
|---|---|---|
| `wait` | 2 s | How long the head has had no body |
| `near` / `far` | 8 / 40 m | Your flat distance to the lip (so you aren't standing over it) |
| `level` | 3.5 m | Your feet within this of the lip's height (you're up on that isle) |
| `view` | 1.0 rad | The lip within this of the camera's look (you'll see it come over) |
| `hidden` | 1 | The camera's line to where the body hangs is blocked by the cliff |
| `natural` | 1 | 0: only G spawns |

## Verified (headless, Godot 4.7.2)

- The headless import is clean. `studies/headless_body_isle.tscn` ran 600
  frames with no script errors (the run includes a natural spawn).
  `studies/inhaler_isle.tscn` ran 400 frames with no errors.
- `test_enemy_ram.gd`, `test_world_scale_guard.gd` and
  `test_world_scale_fit.gd` pass. The full suite was not run.
- **Throwaway checks.** They are in `scratch_hb2/` and not committed.
  Each drives the study's own `tick` with real physics and rays. You are
  only set down at the start of a bout, and G is sent as a real
  `InputEventKey`.
  - **Whole way from a natural spawn.**
    - The body spawned under A's south lip at 2.0 s. Its hands were
      0.08 m under the lip and the camera's line to it was blocked.
    - It climbed and mantled onto A at 11.6 s (the mantle wave fired),
      then searched and climbed B.
    - It **jumped B→E** and landed at y 16.0 on E (z −32).
    - At E→F it **dropped** instead and landed at y 6.0 on C.
    - It climbed F, **jumped up F→D**, landed at y 17.0, homed in and
      reunited at 114 s.
    - `--body-start=stand` (round 1's start) took the same jump, drop,
      jump and reached the head.
  - **Shockwaves on you:**

    | Landing | Your distance | Result |
    |---|---|---|
    | Jump | 7.8 m | Knocked, thrown 4.0 m flat, 1.0 m up |
    | Jump | 7.2 m | Knocked and tumbling, 7.9 m flat |
    | Mantle | 5.2 m | Knocked, 2.9 m |
    | Drop | 8.5 m | Knocked, 8.6 m flat, 2.2 m up |

    A hop pressed as the front came within 3 m (0.74 m off the ground)
    **cleared it, with no knock**. A hop pressed at touchdown came down
    before the front arrived and was hit.
  - **Spawn rules and G:**
    - There was no spawn before `wait`.
    - With you standing at A's south lip looking out, no spawn came in 4 s.
    - On D facing east, D east fired.
    - G with a body about kept one body (5 spawns, 1 body).
    - G on a whole, perched body sent the head back to drift at its home.

## Not verified

- **Looks.** Nothing was rendered. The ring, dust wall, chips and the
  quake have not been seen, and their sizes and fades are first guesses.
  The cliff reveal (hands, then the stump, then the shoulders over the
  lip) has not been seen either.
- The sounds have not been heard.
- How the shockwave and the reveal feel in play. Their numbers are
  checked, but the feel isn't.
- Only this layout and seed 1 were checked.

## Open questions for you

1. **The reveal is slow.** With its hands on the lip it hauls at 0.55 ×
   climb, so it takes about 8 s from spawn to over the top. Its shoulders
   only clear the lip after about 5 s. Is that dread or drag? `haul` and
   `cling` tune it.
2. **Should spawns be the only way bodies arrive?** The default is now
   cliff-first, with `--body-start=stand` keeping round 1's. Or should
   there be more heads and bodies in a scene?
3. **Shockwave strength.** It throws you about 4–9 m and stuns if you're
   close. Should a drop off a mesa ever throw you off an isle? It can now
   near a rim.
4. **Jumping the wave.** It's dodgeable with a hop timed to the front.
   Is that the right counterplay, or should it be unavoidable near the
   middle?
5. **Should it jump to you?** Ledge jumps only fire on its way to its
   head (or roaming whole).

## Changed files

- `scripts/enemies/headless_body.gd`: the ledge jump (`_ledge`,
  `jump_gap()`), the shockwaves (`_shock`, `_shocks`, `_shock_meets`),
  the cliff spawn (`cling`), the new knobs and counters.
- `scripts/enemies/enemy_field.gd`: a new `add()`, an unremembered
  spawn that `reset` takes away. Nothing else uses it yet.
- `studies/headless_body_isle.gd`: the new layout, `CLIFFS`, the spawner
  and its rules, G, the HUD and the `body_shock` voice.

## Existing tests

No existing test should break. Nothing in `tests/` references the body,
its study or `EnemyField.add`. The enemy field change is additive, and
`test_enemy_ram.gd` still passes.
