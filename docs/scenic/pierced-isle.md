# Pierced isle: handoff

Branch `feature/pierced-isle` (from `feature/ruins` a39b3c7d). Not merged, not pushed.

The ask: a big sky island mass with holes through it to fly through, dressed with the ruin kit and aqueducts. This round builds one, seeded and laid by rule, reachable in the real game with `--pierced`.

## What was built

One mass about 150–230 m across and about 130 m from summit to keel tip. Its rim stands at about +50 m (home y 46–54). That keeps the holes clear of the cloud sea and the summit under the sky's ceiling.

- **Lid** (the top). A real `SkyIslet` (`author`), a big hills islet on a 2 m grid. It has the islands' outline, erosion, grass, 160–220 trees, flower drifts, two or three hills and a ridged rocky summit. It is registered in the islets' `built` as a fixed record, so the glide skims it, the wanderer perches and walks on it, and it bobs like any islet.
  - Its foot is only 4.5 m under the rim (new recipe key `base`). Its keel is off (`keel` 0).
  - Its skylight is punched through its outline (new recipe key `holes`).
- **Body** (the rock under the lid). `PiercedIsle.field` is a signed distance:
  - the lid's own outline (rasterised, exact EDT), carried down;
  - strata ledges that step out bold in places and fade in others;
  - buttresses and gullies running down the face, lumps and crags;
  - narrowing to a keel, with two or three hanging lobes.
  - The holes are carved out of it. Their walls are rough, and their mouths flare wider near the face, as caves do.
- **Body mesh.** Drawn by surface nets (`scripts/pierced_mesh.gd`, 2.6 m cell; a 6.5 m far LOD past 520 m) as flat faceted faces. Each face is painted:
  - beds of the lid's rock look, warmed so shade reads stone-grey, not navy;
  - pale streaks, turf on ledges, and mist toward the tip.
  - It is lit by the ruin stone shader, with stronger fill and shelter bounce. Each face's sky openness is baked into vertex alpha by short rays, so caverns are dim but readable, and keel undersides take a little cloud-sea glow. The lid's wall is repainted the same way, so lid and body read as one mass.
- **Holes.** Each is laid by rule with rejection, and kept only if its tube is air and its approach (`LEAD` m past each mouth) is clear. Clear widths for seed 3 are in brackets.
  - **arch** (~27–34 m): a natural arch through a flank, chosen where the rock along its chord is 24–56 m, so sky shows through from afar.
  - **cavern** (~25 m): a long, flat-floored hall near the deepest inland point.
  - **shaft** (~17–19 m): the skylight. It goes straight down through the lid, then slants into the cavern roof toward the dive's window.
  - **windows** (3): out of the cavern through the sides. Two are wide (12–14 m). One is tight (7 m, flat floor) and has the gothic gate in it.
  - **eye** (~13–14 m): through the keel, low down.
  - Rock is kept 7 m between holes that don't open into each other.
- **Ruins** (`scripts/pierced_ruins.gd`, built on the worker). They are laid in the plan and settled on the lid's real ground (`PiercedIsle.settle`).
  - **feed**: an aqueduct of 3–4 spans from its head over the top to the skylight's lip. A spout carries the channel past the last pier, and its water spills 24 m or more down the shaft as a crafted fall into a pool.
  - **gate**: the gothic pointed arch standing in the tight window (a 4.2 m opening), its gable and buttresses buried in the rock round the mouth.
  - **hall**: a 2–3 bay colossus hall on the top, its lane lined up with the skylight, so you come out of the nave and dive. It is in about 15 of 20 seeds.
  - **run**: an aqueduct across the cavern floor, kept 6 m (flat) off the dive's pull-out line. It is in about 12 of 20 seeds.
  - Trees keep off the ruins' ground; the hall stands on a levelled pad.
- **Routes** (`plan.routes`, lid frame):
  - **arch** and **eye**: straight through each.
  - **dive**: in high over the top, down the skylight, through the cavern and out its window. That is three holes in one line.
  - **thread**: in one window and out the most nearly opposite one.
  - **grand**: through the hall's lane, over the lip and into the dive.
- **Always well formed.** `PiercedIsle.make(seed)` relays a seed from its next draw (up to 8) if its first layout has a problem. Of 32 seeds probed, none were left with problems.

## Flying it

```
godot --path . -- --no-title --pierced                  # one isle near the home (ring 440 m+ out)
godot --path . -- --no-title --pierced --pierced-seed=5 # another seed (default 3)
godot --path . -- --no-title --no-pierced               # no random ones
```

- Without flags, random isles stand rarely: at most one per 3200 m cell, 35% of cells, none within 1500 m of home. They keep clear of islands (280 m), ranges, walls and band (180 m), haze, cumulus towers and forested isles.
- The seeded islets and the clusters keep 270 m off each isle (`SkyPierced.blocks`). The clouds part round it (`keep_spots`).
- **Collision.** `SkyPierced.bump` runs after each glide step (one added line in `scripts/wanderer_eye.gd`).
  - The rock is probed analytically: the field at the plane's middle, wingtips, nose and tail, turned with heading, pitch, bank and roll. The ruins are probed as a wing-wide box against their hulls (physics layer 20, `PiercedRuins.LAYER`).
  - On contact the plane is pushed out along the face, turned along it and slowed: bump and recover, never a crash.
  - The lid is the islets' usual column solid, so its hole lets the plane drop through.
  - The chase camera keeps out of the rock (`_solid`).
- **On foot.** You can land or perch on the lid's grass and walk it like any islet. The ruins are not walkable (the motor reads the lid's heightfield only).

## Files

- New:
  - `scripts/pierced_isle.gd`: plan, field, holes, routes, ruins layout, colour, shelter, verify.
  - `scripts/pierced_mesh.gd`: surface nets, painting, material.
  - `scripts/pierced_ruins.gd`: ruin builder.
  - `scripts/sky_pierced.gd`: placement, streaming, standing, bump.
  - `tests/test_pierced_isle.gd`.
  - Tools: `tools/capture_pierced.gd` and the probes `tools/probe_pierced.gd`, `probe_pierced_mesh.gd`, `probe_pierced_lid.gd`, `probe_pierced_make.gd`.
- Shared edits (small, additive):
  - `scripts/sky_islet.gd`: recipe `holes` (`_punch`) and `base`.
  - `scripts/sky_islands.gd`: creates, resets, advances and clears `pierced`; clouds keep off.
  - `scripts/sky_clusters.gd`: `SkyPierced.blocks` in both spot checks.
  - `scripts/wanderer_eye.gd`: the bump after `glide.step`, and the rock in `_solid`.

## Costs

From `tools/probe_pierced_make.gd` and the test (seeds 1–4):

| Part | Triangles | Time (worker) |
|---|---|---|
| Rock, near (2.6 m) | 31–39k | 1.0–1.3 s (with shelter rays) |
| Rock, far (6.5 m, past 520 m) | 4.6–5.8k | 0.05 s |
| Lid (top + wall) | 15–19k | 0.6–0.7 s |
| Ruins (all) | 77–130k | ~0.5 s |
| … feed (3–4 spans + head + spout) | 50–65k | |
| … gate | 12–15k | |
| … hall (2–3 bays) | 17–19k | |
| … run (2–3 spans, bare) | ~27k | |
| Near in all | 134–180k | 2.5–5 s per isle |
| Ruin hulls | 1.3–2.8k convex shapes | |
| Lid plants | ~2–2.8k instances (multimesh) | |

- Ruins draw to 480 m, plants per the islets' ranges. Past 520 m the isle costs about 5k rock faces plus its lid.
- The main thread stands an isle in four parts, one a frame within `SkyCommits`: lid, rock, far rock, ruins.
- The test budget: rock near 50k, rock far 8k, lid 24k, ruins 140k, near total 220k, made in under 8 s.

## Checks

- `tests/test_pierced_isle.gd` passes headless (about 19 s):
  - 20 seeds are well formed;
  - every hole's tube is air and leaves wingtip room (wide 2.5 m or more, tight 1.2 m or more);
  - the gate stands on the tight window's floor;
  - the routes are clear;
  - the game's `SkyPlane`, on an autopilot over the real lid, flies the arch, eye, dive and thread routes for seeds 1–3 without touching rock or ruin bulk, and reaches the grand route's end;
  - the budgets hold.
- Also pass headless: `test_sky_islets`, `test_sky_plane`, `test_cluster_motifs`, and `test_sky_clusters` (one known engine message). The import is clean.
- Rendered captures were judged by eye from `captures/pierced/final/*.png`:
  - from afar: `far`, `far-arch`;
  - at plane height: `arch`, `eye`, `window-out`, `gate-front`;
  - inside: `through`, `cavern`, `window`, `gate`, `run`;
  - on top: `top`, `skylight`, `feed`, `hall`, `hall-lane`, `spill`.
- To recapture:

  ```
  Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_pierced.gd -- --no-title --pierced --out=captures/pierced/x [--shots=far,cavern] [--pierced-trace]
  ```

## Known issues

- **Not flown by hand.** Bump feel, hole sizes at speed and the dive's steepness have only been checked by the autopilot and stills.
  - The grand line (the hall's 2.6 m lane from outside, then the dive) bumps the hall a few frames on the autopilot. It is meant to be tight.
- **Ruin hulls are not tested in flight.** The test flies against the ruins' planned boxes, not their physics hulls; the game's bump uses the hulls.
  - The gate's 4.2 m opening has not been flown through by physics query. Nor has the knife-edge slit inside the hall's screens.
- **No real knife-edge hole in the rock.** Surface nets at 2.6 m can't cut a 1.1 m slit. The tight lines are the gate (4.2 m), the tight window (7 m) and the hall's slits.
- **The cavern's aqueduct and the ruins in the cavern read dark.** The ruin pieces' faces carry no shelter, so they take only the stone's fill. The rock in tunnels is readable, but blue-brown and dim.
- **The spill is a single pale ribbon.** It has no mist at its foot. Where the water lands depends on the shaft's slant, and it sometimes lands on a ledge rather than the cavern floor.
- **The rock still shows horizontal banding from afar,** and its sunlit side is quite pale against its shade.
- **Streaming hitches are not measured.** The ruins part adds up to about 2.8k convex shapes in one frame, which may hitch. That part could be split per piece.
- **A blocked main thread can deadlock a worker.** This was found while fixing captures: `RuinKit.merge` reads meshes back from the rendering server. On a worker that waits for the main thread, so a main thread blocked on that worker (`wait_for_task_completion`) deadlocks. The runs and hall are therefore built unmerged (a mesh per span or bay, about 12 more draw calls).
  - `plan_now` now builds on the calling thread.
  - `_forget` and `clear()` still wait on a worker that is mid-make. That is safe now that the worker makes no readbacks.
- **The lid's ruins aren't walkable,** and the hall's floor isn't a perch.
- **The skylight sometimes sits on a hill's flank,** where the rim eases steeply down to the hole.

## Next steps

1. Fly it by hand: dive steepness (`DIVE_HIGH`), hole sizes, bump feel, and whether the arch reads as an arch from the approach.
2. Light the ruins in the holes: write shelter into the ruin pieces' vertex alpha (as the hall does), and add mist at the spill's foot.
3. Split the ruins' stand per piece, and measure the frame cost of standing an isle in flight.
4. A cleft or gorge in the top that an aqueduct actually spans (the lid would need a cut, like the ravine's).
5. More hole kinds: a natural bridge between the mass and a split-off pillar, and a curving through-tunnel.
6. Collectible lines threaded through the routes (`plan.routes` are ready for it).
