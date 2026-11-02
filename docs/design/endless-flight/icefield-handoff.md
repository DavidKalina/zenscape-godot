# Icefield: handoff (2026-11-01)

The Peak's glacier, populated: the spec is `spec-icefield.md`, the trail is
`git log --grep='^ITER(icefield)'` on `claude/game-collectibles-brainstorm-357237`
(126003d0 .. this commit). Nothing is pushed.

## Where to play it

`.\run-endless-flight.cmd`, seed 1, fly at the three spires. The glacier is
the white tongue under them, toe (a 3100) to the mouth's spill (a 2050).
Fly it up low from the toe. To start on the ice:
`.\run-endless-flight.cmd -- --rock-start=ice-forms` (from a 2900, down the line).

Positions below are the massif's frame: `a` along the glacier (falling toward
the spires), `vr` across it from the valley's middle (`peak.world(a, peak._valley_mid(a)+vr)`).

## What's built

**The carve** (the height field, both sides): `scripts/endless/peak_massif.gd`
`_ice_carve` and its twin in `native/terrain_kernels/peak_massif.h`
(`peak_massif_bind.h`), `NATIVE_VERSION` 6. It all runs in `height()`, so
chunks, grids, collision and flight read it.
- The toe: a 3100-2850 a smooth 4.8 % rise (63 -> 77 m), flat across.
- The long crevasse: a 2480-2845 at vr ~-85, 29 m at the lip, 19 m floor,
  28 m deep, open at both ends.
- Ten bands across the flow (`ICE_BANDS`): four at the head's bend
  (a 2252-2340), six below the step (a 2575-2790). They wobble, break en
  echelon, and widen and lose their blue paint far off (`BAND_AA`,
  `BAND_PAINT_STEP`).
- The icefall step: a 2390-2470, 50 m down in staggered, tilted, slumped
  blocks with cracks between columns.
- The medial moraine ridge (vr ~+20), three meltwater grooves.
- Two lead crevasses (`LEADS`) from above the step (a ~2378) to the mouth's
  ranks (a 2180): lead 0 is flown (26 m lip, 20 deep), lead 1 a narrow crack.
- Paint: slots blue, ridge dark, through the chunks' carve bytes into
  `shaders/peak_ice.gdshaderinc` (`endless_ground.gdshader` passes `carve`).

**The forms** (standing ice, rock kind `ice-forms`):
`scripts/endless/rocks/peak_ice_forms.gd`, listed in `rocks/rock_plan.gd`.
Ranks at a 2790, 2505, 2240 (towers leaning, lanes between); fin runs
a 2745-2595 and 2455-2315 (split blades, two points each); arches at
a 2560 and 2290 (two serac legs, a heavy bridge of slabs, column solid,
18 m under); tumbled blocks along both moraines. A 7 m lane stays open on
the line. The serac ice reads less white (shared material, so the valley
seracs changed too). `line_moves.gd` `_fin_at` counts any rock pillar for a
slalom. The mesher's heavy loops are C++: `ZenScapeSerac`
(`native/terrain_kernels/serac_mesh.h`, registered in `kernels.cpp`), called
from `rocks/peak_serac.gd`; GDScript mirror kept.

**The three ways up**:
- The slot: lead 0 from the step's top into the ice gorge, whose bowls are
  denser (`rocks/peak_valley.gd` `HEAP_STEP` 22, `BOWL`).
- The ramp: the rock gorge, untouched.
- The tunnel: `scripts/endless/peak_tunnel.gd` (the line, bore, hole mask)
  and `scripts/endless/land_ice_tunnel.gd` (the tube mesh, cold lights,
  collider, flight queries). Mouth A in the -v bank at about a 2185,
  v -290; a chamber with a window (s 1030-1140); an open gully crossing
  (s 1500-1600) that cuts the Slot line at a ~865; mouth B at the spine's
  end, 40 m under the saddle, then out to the saddle. Hooks in
  `studies/endless_flight.gd` (`bore_guide`, `bore_keep` and the ground
  chain), `land_field.gd`, `land_stream.gd`, `hall_doors.gd`. Mouth A is
  marked with climbers' flags: a stake gate, two 48 m masts and pole lines
  on the bank (`scripts/endless/peak_flag_sites.gd`, handles
  `peak/flags/tunnel/...`).

**The finds** (`scripts/endless/finds.gd` anchors, `finds_table.gd` rows,
`find_marks.gd`); ids and `finds/<id>` handles kept:
- `ice-skim`: down the long crevasse, 8 m over its floor (a ~2660).
- `bend-ring`: under arch 1 (a 2290). Title "The ring under the ice arch".
- `tunnel-deep` (new relic): in the tunnel's chamber, 18 m over its floor.
- `gorge-run`: 18 gates, two in lead 0, two at the gorge's mouth, then up the
  ice gorge. Mark 58 s (Boost bot 56 s).
- `gorge-room`: unchanged.
Each anchor answers nothing with its lane off, so its row waits unplaced.

## Flags

`--ice-carve=0`, `--ice-forms=0`, `--ice-tunnel=0` (each lane off),
`--native-serac=0` (the serac mesher's GDScript loops), `--native-peak=0`
(the massif's GDScript side), `--rock-start=ice-forms`.

## Numbers

- Rendered frame time, Full preset, 1440x900, uncapped, the glacier low on
  Boost (a 2190-2930): ice on median 8.2-8.7 ms, p95 12.1-12.4; off 7.4-7.5,
  p95 11.0. About +0.8 ms median, +1.2 p95. No hitches from the ice.
- Tick: the ice adds ~0.55 ms (camera, near, figure, landing queries).
- Chunk build near the glacier, native 10-12 ms L0-L5, 17-19 ms L6-L7; the
  carve costs nothing measurable.
- Forms cell on a worker: plan 17-24 ms (GDScript), build 5-7 ms (C++).
- Room past a wingtip, least, medium, wobble, seeds 1-3, Boost on and off,
  0 crashes everywhere: long crevasse 6.1 m; forms line 3.9 m (fins 0,
  Boost); slot way 3.8 m (lead 0's climb-out, Boost); tunnel bore 5.9 m,
  open gully 4.5 m; ramp 12.8 m. Plateau landing out of the slot way 6/6,
  the ramp 6/6, mouth B 3/3 with Boost and 3/3 without.
- Toe landing (this round, `scratch/icefield/toe_land.gd`, medium): 3/3
  landed at vr 0, -120, 120 (touch a 2954-2965, stopped a 2939-2949). The
  toe's surface has local grain (8-14 % over 10 m on the middle line, less
  than without the carve).

## Stood in or stubbed

- The arches' and fins' ice is the serac mesher's shards; no textures.
- Mouth A's markers are the crown's flags reused.
- The ranks' side lanes were never flown.
- Fin run 1 has only 2 fins on the carved floor (its step fins fail the foot
  check).

## Open for the user

- Slalom scoring on the fins: `_fin_at` counts any rock pillar abeam, and the
  line tune skips slaloms by default (`line_tune.json` "skip").
- `gorge-run`'s 58 s mark.
- The Peak basalt tint darkens the tunnel's gully crossing walls
  (`endless_ground.gdshader` `PEAK_BASALT_TINT`, `PEAK_GULLY`); changing it
  changes the Peak's rock everywhere.
- The fins from the side (never framed in a still).
- Mouth A's tell from the toe: masts and string show, still small at 870 m.
  A strong read needs mass (a cairn tower or a notch: Peak maths).
- `bend-ring`'s hint ("Under the ice at the glacier's head").
- `_day_material` in `land_ice_tunnel.gd` is defined but unused.
- The forms' plan at 17-24 ms a big cell on the worker, once a session;
  next to port: `_turn`/`_fit` in `peak_ice_forms.gd`.
- Lead 0 ends in a 60 m ramp the bot climbs out of early; a longer ramp is
  Peak maths (version bump, parity).

## Native kernels

Version 6 plus `ZenScapeSerac` are built only in this worktree's git-ignored
`native/terrain_kernels/bin`. Main's bin is version 1; without the new DLLs
the GDScript runs (slow, same result). Copy both DLLs and their `.sources`
stamps from here, or rebuild (scons needs Python 3.11):

```
python3.11 tools/build_native_kernels.py --godot <console exe> --godot-cpp .claude/worktrees/agent-aa61725b479fe1f00/builds/godot-cpp --scons <Python311>\Scripts\scons.exe --target template_debug
(the same with --target template_release)
python tools/native_stamp.py
```

Parity (`scratch/native_peak/parity.gd --a0=2150 --a1=2950 --vw=400`) is
0 differing values after this round's fix (the GDScript was missing the
bands' far paint fade).

## Tests

None run (prototype rounds). No test names the changed files. Tests that
read the Peak's land or paint and may move: `test_native_mountain_shape`,
`test_native_paint`, `test_sky_peak_look`, `test_landscape`.

## Drivers (git-ignored)

`scratch/icefield/`: `toe_land.gd`, `forms_thread.gd`,
`slot_way.gd`, `ramp_way.gd`, `tun_fly_ice.gd`, `saddle_land.gd`,
`finds_take.gd`, `finds_tun.gd`, `cost_fly.gd` (+ `cost_cut.py`),
`serac_parity.gd`, `merged_stills.gd` (`--out --only`), `sheet.py`;
`scratch/native_peak/parity.gd`.
