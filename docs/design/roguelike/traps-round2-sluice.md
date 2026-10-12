# Traps, round 2: Sluice Flush (2026-10-12)

> Greybox. First built on `feature/trap-sluice` (off `roguelike`) to the
> round-1 contract (traps-round1.md), no contract change. Put in context on
> `enhance/sluice-aqueduct` after the user played the yard lane: "I don't
> get the sluice. It'll probably be better in context."
> Files: `scripts/traps/trap_sluice.gd` (the trap), `scripts/traps/sluice_aqueduct.gd`
> (placing it on the aqueduct isle), tests `tests/test_trap_sluice.gd` (the
> yard lane) and `tests/test_trap_sluice_aqueduct.gd` (on the isle), one
> flag-gated line in `studies/aqueduct_isle.gd`, one line in `studies/trap_yard.gd`.

## In context: the aqueduct's channel (`--sluice`)

With `--sluice` on the aqueduct isle (or the game, studies/zenscape.tscn,
which extends it) the trap sits on the real channel. Without it nothing is
laid and nothing changes. All sizes come from studies/aqueduct_isle_art.gd
(derived, not copied):

- **The gate** is at the channel's head, where the parapets start (z -2.4,
  aqueduct-map.md's "head"): a gatehouse on the west parapet, the
  castellum's feed coming into its back (a greybox trough off the water
  tower's crown), its leaf in the face toward the channel.
- **The plate** is 4.3 m in (a run's 0.9 s): a walker coming up the rubble
  slope onto the head steps on it. It is a darker flagstone with a ring.
- **The channel** is the trap's floor: the clear between the parapets (1.5 m),
  from the gate to the snap (52.1 m). The wave covers the whole deck (2.4 m)
  at 0.6 m, over the 0.42 m parapets, so standing on a parapet is not safe.
- **The fallen span** (z -54.5 to -57.5, 3 m) is the trap's gap; the far run
  past it to the deck's end (14.5 m) is floor too. The wave spills over the
  gap (spray cascade at the lip), runs on along the far run and spills off
  the end.

### How it plays

1. Walk up the rubble slope and along the channel: the plate clicks down.
2. **The tell, 3 s.** The channel's water drains away down its length (its
   tail runs from the gate toward the gap, what is left sinks to a trickle),
   the leaf rattles and grinds up in jerks, spray bursts from under it, a
   deep rumble rises (with a quickening rattle in it), three gurgles, and the
   gatehouse's lintel flashes orange.
3. **The wave**: a translucent foamy slab with a white crest and front and
   spray, running down the channel at 9.6 m/s (twice the run). Standing in it,
   he is carried: moved with the water, his own pace a wade (2.4 m/s) against
   it, the body leaning back and rocking. Carried over the snap he is flung
   off at the water's pace, a little up, tumbling, and drops through the
   fallen span (no lip catch, no jump; a twirl or the sail still work).
4. **Counters**:
   - **Get above it.** The gatehouse's top (1.0 m, over the 0.6 m wave),
     right behind the plate: turn round and jump onto it (one jump from the
     floor, the test does it in 0.8 s of the 3 s tell). A fallen block on the
     west parapet over the first open pier (z -31), the same height, for
     someone who ran on: running on from the plate reaches it before the wave
     does. With the foot pieces (default) the rope beams over the east
     parapet (z -29.4, -47.0, 0.92 m) are over the wave too. The castellum's
     high step (west of the head, off the deck) is dry.
   - **Ride it.** Anything that leaves the water ahead of it leaves at its
     pace (as a slab's pace goes with him off it): a jump taken while carried,
     or running out past its front, keeps 9.6 m/s plus his own. Jump at the
     snap and the leap (about 12 m/s) clears the 3 m gap onto the far run,
     where the wave catches him again and runs him off the end (twirl or sail
     from there). A rider who does not jump is flung short and drops.

### Windowed command

    /Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/aqueduct_isle.tscn -- --no-title --sluice=head

`--sluice=head` starts at the top of the rubble slope facing up the channel;
plain `--sluice` keeps the isle's start (the slope's foot, walk up). In the
game: `... Godot --path . -- --no-title --sluice`.
`--sluice-knob=<key>=<value>` (repeatable) overrides a knob, e.g.
`--sluice-knob=tell_time=4 --sluice-knob=speed=7.2`.

## The yard lane (the bare version)

    godot --path . res://studies/trap_yard.tscn -- --no-title --trap=sluice

A walled channel (the kit aqueduct's `CHANNEL` and `PARAPET` at the
wanderer's size) over a drop, the gate a header over its head, a refuge
shelf in the east wall. Same trap, same tell and wave, its own floor and
walls, 2 s tell; no lean or tumble on the body (the yard's TrapField has no
`pose`). `--knob=<key>=<value>` as ever.

## Knobs (defaults at wanderer 1.0: yard / on the aqueduct)

| knob | yard | aqueduct | meaning |
|---|---|---|---|
| length | 28.8 m (run x 6) | 52.1 (gate to snap) | channel floor before the gap |
| gap | 2.4 m (walk) | 3.0 (RESUME - SNAP) | the open end's gap |
| beyond | 0 | 14.5 (RESUME to END) | floor past the gap the wave runs on |
| end | "open" | "open" | "pool": a wall, swept against it |
| walls | true | false | lay its own floor and parapets |
| width | 1.5 (kit CHANNEL) | 1.5 (between parapets) | channel clear |
| parapet | (0.4, 0.42) | (0.4, 0.42) | thickness, height |
| cover | 1.15 | 1.2 (Art FACE) | half width the wave covers |
| wave_height | 0.6 m (jump 0.8 x 0.75) | 0.6 | carried below this |
| wave_length | 3.6 m (walk x 1.5) | 7.2 (run x 1.5) | |
| speed | 9.6 m/s (run x 2) | 9.6 | |
| wade | 2.4 m/s (walk) | 2.4 | his own pace in the water |
| tell_time | 2.0 s | 3.0 | |
| trigger | "plate" | "plate" | or "timer": `period` s (4) in the channel |
| plate_at | 4.3 m (run x 0.9) | 4.3 | down the channel |
| second_wave / second_gap | false / 1.5 s | same | |
| refuge | 1 | 1 | 0: no refuges |
| refuges | [[14.4, +1]] | [[28.6, -1]] (over pier 2) | [m down, side] blocks on a parapet |
| refuge_top | 0.8 (jump) | 1.0 (jump x 1.25) | |
| gate | "header" | "side" | posts and header / a gatehouse whose top is a refuge |
| gate_side | -1 | -1 (west) | |
| gate_up | 2.4 (pump x 1.6) | (unused) | header height |
| flow | 0.21 m | 0.06 (Art WATER_LIFT) | idle water depth |

## Checks

    godot --headless --path . --script tests/test_trap_sluice_aqueduct.gd
    godot --headless --path . --script tests/test_trap_sluice.gd

The aqueduct test runs the isle with `--sluice=head` through the real play
loop (unscripted study frames, InputMap actions): the trap is sized from the
isle; walking up from the head he steps on the plate; the tell (water
drained 81% of the way down at half time, the leaf, the spray, the rumble,
the gurgles) precedes the wave by 3.0 s; standing still he is swept 50 m to
the gap and drops through the fallen span; on either refuge the wave passes
under him; from the plate he gets onto the gatehouse in 0.8 s; running on
into the wave and jumping at the snap he leaves at 12.3 m/s and lands on
the far run. Both tests pass; headless loads of the isle with and without
`--sluice` are clean.

## Unverified

- Nothing was looked at in a window: the look of the wave (slab, crest,
  front, spray), the draining film against the channel's real water (it
  swaps the real water for a greybox film at the tell's start, and back after
  the wave; with `--old-water` the old film is not hidden), the cascades, the
  feed trough's placement by the castellum, the rocking and the tumble.
- No sound was heard: the rumble is a synthesized placeholder
  (AudioStreamWAV built at load, played from the gatehouse); the gurgle,
  surge and spill `tell_sound`s still have no audio hook.
- Feel: whether 3 s reads as enough and 9.6 m/s as dramatic rather than
  unfair; whether the carried pace reads as swept; the jump window at the
  snap (about 1 m before the lip, 0.1 s) may be tight for a rider standing
  still in the wave (the test's rider runs with it); the second wave, timer
  trigger and pool end are built but not exercised on the isle.
- The wave has no collision and does not change the water's depth for
  wading or swimming (PilotPhysicsGround pools are untouched).
- The fallen block over pier 2 is reached in the tell only in arithmetic, not
  in a test; the rope beams as refuges are untested.
- The yard lane's lean/tumble pose is missing (TrapField has no `pose`; left
  alone, it is shared).
