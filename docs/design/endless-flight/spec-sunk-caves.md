# Sunk caves, round 2

Seed 1's wilderness has four natural caves that dive under the land and come
back up. The land is a heightmap with holes at the mouths; the cave is a 3D
mesh and collider underneath (`scripts/endless/tunnel_sites.gd`,
`scripts/endless/land_tunnels.gd`, `shaders/tunnel_cave.gdshader`). The
scanned spots live in `SUNK_SITES`. The user flew one and liked the inside.
This round fixes what they saw.

They stay natural caves: no RuinKit pieces, gates, sconces or straight cuts,
and no long ramp to the mouth.

## Done looks like

1. **No blue strips.** The strips the user saw along the top of the tunnel
   are gone in all four caves. They suspected the water shaders leaking
   through, which is unconfirmed: find the real cause before fixing it. A
   small teal slab with a thin rod was seen near the vault about 20% into the
   cave at (4640, 4384) and was never explained; it may or may not be the
   same fault. Show the same stretch before and after in rendered stills.
2. **No checkered entrance.** The rock around each mouth reads as one natural
   face with the land and the cave's rock, with no tile or checker pattern,
   in daylight, from the approach and from close up. The mouth rock is built
   in `_build_mouth` from cells of `LIP_CELL` and shaded by the plain
   `_portal_material` branch for sunk sites.
3. **Up and down as well as left and right.** A flight through a cave asks
   for pitch as well as turns: left and up a bit, down a bit, up a bit. Each
   cave has several distinct climbs and dips, enough that holding a straight
   level line hits rock. They stay flyable by hand at full speed (about
   57 m/s on Boost, medium weight), and they read as the rock's own shape,
   not a sine wave. The profile lives in `_cave_path` and `_cave_profile`.
   Land cover over the roof and `SUNK_LOWEST` limit how far it can go; if a
   limit gets in the way, change it or say so in the Notes. If the path
   stops fitting a stored spot, rescan and update `SUNK_SITES`
   (`scratch/tunnel_scan.gd`).
4. **The cave is there when you arrive.** The user said it "seemed to take
   forever to render". We don't yet know which wait they meant, so measure
   each: added time from launch to flying with caves on and off (the land
   hash and the massif roll may matter too), how long after arriving near a
   mouth the land, rock and cave appear, and any long frames while that
   happens. Start from `.\run-endless-flight.cmd --at=4200,4384 --heading=90`
   and also from a normal start. Fix what the numbers point to. A cave is
   about 1.4M triangles, so thinning is on the table, keeping the look the
   user liked. Report before and after numbers. Note in the Notes which wait
   was biggest, so the user can say if that matches what they saw.

Do these in whatever order works. Do item 4 after item 3, since the path
changes the mesh.

## Proof

Prototyping rules (AGENTS.md): no committed tests, no full suite.

- Smoke: `studies/endless_flight.tscn` through `tools/smoke.py` must pass.
- Flight: `scratch/tunnel_fly.gd` is the existing autopilot (stick and Boost,
  `--name=`, `--shots`). Fly all four caves end to end, on the real play loop
  and with the driven line deliberately off centre: a clean exact line does
  not prove a cave can be flown by hand. If a dip or climb has too little
  margin, ease it.
- Stills: `tools/shot.py` or rendered captures with `-- --no-title`. Look at
  them and iterate before committing. Rendered captures are allowed without
  asking, one window at a time.
- Frame numbers: a rendered run, compared with round 1's: about 100 fps,
  median 9 ms, p95 15.5, p99 25.5, worst 48.5, tunnels tick 0.19 ms; 660 ms
  worst build on the worker, 57 ms worst placing a cave.

## Practical notes

- Other scratch drivers: `scratch/tunnel_scan.gd`, `tunnel_census.gd`,
  `tunnel_cells.gd`, `land_hist.gd`. Scratch is git-ignored; leave drivers
  there.
- About 390 `.import` files show as modified in this worktree. That is noise
  from the import, not this work. Never stage them.
- `land_tunnels.gd` has LF line endings in this worktree. Keep each file's
  own line endings. Bash heredocs have mangled patches here before, so
  prefer the Edit tool or a patch script saved as a file.
- `E` is reserved in Godot shaders.
- Mouths: (4640, 4384), (4896, -1504), (-6880, 5408), (-480, 5920).
- The model-budget assessment (AGENTS.md, Models, `docs/art/model-budget.md`)
  applies to the cave and mouth meshes: list which tricks apply in the
  handoff notes.

Lanes: none. All four items work in the same two files, so they run as one
trunk. The cap is the skill's default.
