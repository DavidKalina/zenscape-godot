# Hitboxes and rock fields (handoff)

The plane hit stone it wasn't touching. Its hitbox against arches, rocks,
halls and bores is now its real shape at its real bank. Sea stacks and hoodoo
pockets (slalom fields) are on in the wilderness by default. This is a
prototype round: smoke checks and throwaway drivers in `scratch/`. No tests
were committed.

## Play it

```
.\run-endless-flight.cmd --rock-start=hoodoos          # a hoodoo pocket ahead, down its lane
.\run-endless-flight.cmd --rock-start=stacks           # a stack group, low over the sea
.\run-endless-flight.cmd --at=-372,-3376 --heading=-60 --alt=30   # seed 1, a rock arch
.\run-endless-flight.cmd --world=overgrown --at=-3903,-3168 --heading=151 --alt=20   # a slot hall
.\run-endless-flight.cmd --no-rocks                    # the land without them, to compare
```

## Why it hit

The flight's solid is analytic (SkyGlide reads `plane_ground`), and two
paddings stacked:

1. Every stone solid was grown by half the span (1.4 m) round the plane's
   middle, whatever its bank. On its side the plane reaches 0.9 m (the
   keel), not 1.4.
2. NearMiss's body points (nose, tail, wingtips) were tested against that
   same grown solid. A wingtip already on the plane's edge was grown by
   another half span, so it touched with up to 2.8 m of air.

On top of that the solids were fat. Arch columns were 1 m bins, joined
across gaps under 1.5 m, 3 m depth bands, and rock arches were AABBs of
whole rings. Hall cells were 1 m. Rock sectors were widened to their
neighbours and took the wider of two rings for each band.

## What changed

- `scripts/world_scale.gd`: `TOY_KEEL` (0.45 toy, the wheels' bottom) and
  `reach_rolled(roll)`: the plane's reach sideways off its middle, half the
  span wings level and the keel on its side.
- `studies/endless_flight.gd`: `plane_ground(p, pad := -1.0)` passes a pad to
  every stone layer. By default the pad is `solid_pad`, set each frame from
  `reach_rolled(bank + spin)` before the plane's step.
- `scripts/endless/near_miss.gd`: the body points ask `plane_ground(p, 0)`,
  the stone ungrown. The belly point under the middle still asks as the
  glide does.
- `scripts/endless/box_solid.gd` (new): exact boxes in a 2 m grid of box
  indices, grown at query time by the asked pad, with `joined` for the
  stretches. `from_faces` samples a skin with upright lines every 0.5 m,
  pairs their crossings into stretches, and runs them into boxes along x
  then z. It stays within 0.25 m of the skin.
- `land_arches.gd`: a rock arch's solid comes from its mesh (`from_faces`)
  and a ruin's from its stones' boxes. `stretches/ground/inside` take `pad`.
  The physics colliders are unchanged.
- `land_halls.gd`: a section's solid is its boxes (`BoxSolid`), and
  `stretches/ground/inside` take `pad`. `GRID/MOST/STRIDE` are gone.
- `rocks/rock_build.gd` and `land_rocks.gd`: a ring's sector radii are the
  outline's true reach in that turn, at the points and where edges cross the
  sector sides, not widened. The stretches follow the skin straight from
  ring to ring, as it is lofted, and the cap's dome narrows toward its rim.
  `stretches/ground/inside` take `pad`.
- `land_tunnels.gd`: `ground(p, h, pad)` shrinks the bore by the pad.
- Every other caller (camera, rival line, rolling wheels, contact grading)
  keeps the wingtip pad by default, as before.
- `world/profiles/wilderness.gd`: stacks 1.5 and hoodoos 2.5. Past 2.5 the
  hoodoos run out of badland floors (they keep off meadows, rivers and
  steep ground, so the flats stay). Seed 1–3, 5.8 km square: 7–11 hoodoo
  pockets, 18–29 stack groups. From a point over land, the nearest group is
  a median 425–725 m away.

## Proof (throwaway drivers, `scratch/`)

`hitprobe.gd` sets the plane beside real faces at a known true clearance
and asks the game's checks: the glide's solid at the middle (G) and
NearMiss `touching` (T). Counts are touches out of the faces probed.

| | before | after |
|---|---|---|
| arches, wings level, 1.0 m clear | 50/50 | 7/50 |
| arches, on its side, 1.0 m | 50/50 | 7/50 |
| hoodoos, wings level, 1.0 m | 11/11 | 3/29 |
| halls (overgrown), wings level, 1.0 m | 53/53 | 9/53 |
| halls, on its side, 0.6 m | 53/53 | 14/53 |
| arches/hoodoos/halls, 0.1–0.3 m into the face | all | all (G every time) |

What's left at 1–2 m holds steady with distance: those probe spots sit
near another part of the same thing (a column, the roof, the next pillar).
The solids follow the visible skin, which stands up to about 0.3 m past the
coarser physics collider the probe measures from.

`passfly.gd` flies 24 frames of the real loop past hoodoo faces with no
input. Stone touches at 1.0 m: 32/40 before, 9/29 after with wings level;
39/40 before, 20/29 after on its side. The plane drifts and rolls back
toward level during the pass, so these are rougher than the probe.

Cost: an arch query is about 36 µs, up from 6. A frame flying past arches
costs the same within noise (5.4–5.6 ms after, 5.7–6.0 before, headless).
Rock commits are unchanged (0.8 ms worst).

Smoke: endless flight (default, `--world=regions`, `--rocks=stacks,hoodoos`)
and the flight study pass with 0 errors. `test_world_scale_guard` passes.
No existing test reads the changed solids, so none should break. The full
suite wasn't run.

## Not done

- On its side, the belly has no body point (NearMiss `BODY` has none on the
  plane's down axis). The glide's rolled pad (0.9 m) is what stops it.
- Hall boxes are AABBs of the kit's hulls in the hall's frame, so a round
  column's box corners and a fallen beam's box over-cover.
- The rival doesn't thread stacks or hoodoos (`rival_line.gd`
  `_candidates`), as before.
- The land's hash changes with the hoodoos on (trees keep out of the
  pockets): `tools/land_hash.py` compares need both machines on this.
