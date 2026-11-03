# Spec: building the redesigned pirate ship (loop `ship-build`)

Trail prefix `ITER(ship-build):`. Branch `iter/ship-build`, worktree
`/Users/davidkalina/Documents/Projects/zenscape-ship-build`. Opus every iteration.
Cap: the skill's default.

## Done looks like

The user opens endless flight by a ship and sees both ships in the new look: the
raked, sheered dark hull with its pointed prow; tall masts with big filled sails
carrying two brush-painted glyphs; pennants and an ensign; a small carved figurehead
at the bow. They ride the swell (merged from `iter/ship-rock`). The plane bursts in
through the stern plate, flies the gun deck, bursts the bow plate and comes out
through the tunnel cut in the prow, with the wood it meets matching the wood it
sees. Three hull guns a side fire straight; deck guns lob (once `iter/ship-guns` is
merged). Sinking, the return, two ships and `--ship-blocks` all still work.

Play it:
```
cd /Users/davidkalina/Documents/Projects/zenscape-ship-build && python3 tools/play.py -- --no-title --pilot-file=/tmp/ship-build.json --ship-start --full-meter
```

## Inputs (read before working)

- The concept: `docs/design/endless-flight/ship-look-concept.md` (shape numbers, what
  the build must change in collision, plugs and checks, the model-budget table) and
  its stills in `ship-look-concept/` (`sheet_tar_slate.jpg`, `glyph_options.jpg`).
  Its blockout script: `art/blender/ship/ship_concept_build.py`.
- The current model: `art/blender/ship/ship_build.py`, its handoff
  `pirate-ship-model-handoff.md` (pipeline, node names, the build's self-checks,
  retuning) and `pirate-ship-handoff.md` (gameplay, flags, two ships).
- The rocking: `ship-rock-handoff.md` (merged here; her transform tilts, the ship
  records in `land_arches.gd` read a tilted frame).

## The user's direction (from the concept rounds, 2026-11-03)

- Scheme **tar and slate**: near-black tarred hull, grey stone and iron, no colour.
  The user asked for "a dark brown, grey combo. No yellow. Minimal red. Darker
  palette." The first saturated palette was "way too clown-like".
- Grey canvas warmed toward beige in direct sun in the concept: keep the sails
  cool grey in the game's sun, never beige or yellow. Tone down the light key-pattern
  band along the hull; in the concept it is the brightest thing on her.
- Not "legos", not "too clean": no box-and-tile-grid construction, no perfect panels.
  A little hand-made irregularity (the concept's wobbled strakes, beveled corners)
  stays. Rich detail stays too: a calmed, flattened look lost depth at PC fidelity.
- Sails: "the patterns on the sails are a bit much". Two glyphs only: the **wind
  spiral on the fore course** and the **sun with curved rays on the main course**;
  plain bordered canvas on the rest. Glyphs keep their own aspect (never stretched to
  the sail) and are brush-painted, uneven, worn into the canvas. No square box faces.
- The big carved head with jaws round the exit is parked (`--head` in the concept
  script stays off). Instead, "a small figure head at the bow. Nothing crazy."
- The user liked the concept's shape: "Looks solid."

## Lanes

- `iter/ship-rock`: done, merged (1fec5532).
- `iter/ship-guns`: running in its own worktree (hull guns cut to three a side, deck
  guns that lob, trail, muzzle blast, splash). The coordinator merges it here as
  `ITER(ship-build): merge ship-guns`. Its handoff (`ship-guns-handoff.md`) says what
  a deck gun model must provide. The guns task waits for that merge.

## Trunk tasks (in order; split any that won't fit one iteration)

1. **Figurehead options.** On the concept blockout (tar and slate, head off), three
   small figurehead options at the stem head under the bowsprit, a few metres tall,
   clear of the exit and the lips. For example: a serpent head, a bird's head, a small
   mask. Carved dark wood in the Mesoamerican manner, not boxy. Stills: three-quarter bow at 150 m and a close view, each
   option labelled, plus one side-by-side sheet. **Spec change (user):** "we shouldn't
   go for the crude style. Instead, something more wooden and carved". So: carved
   wood, cleanly and skilfully carved like a ship carver's work, with smooth
   flowing forms and crisp detail, not crude, rough or chipped, and wood, not stone.
   This is a checkpoint for the user's
   pick; the loop goes on without waiting. The coordinator writes the pick into this
   spec under "Picks".
2. **The model, hull.** Port the concept's hull, sheer, castles, raked stern counter
   and prow with its tunnel and lips into the real build (`ship_build.py`, same
   pipeline: painted textures, `.tres` materials, the glb's node contract), in tar and
   slate. Plugs stay at z ±56.5. The build's own checks pass, with the corridor check
   running through the prow tunnel. Export, import with 0 errors, stills in the game.
3. **The model, rig and sails.** Masts, yards, nine square sails and the jib, rigging,
   pennants, ensign. The two glyphs in the cloth's albedo at their own aspect. Retune
   the cloth for the bigger sails (`SAIL_CELL`, the size in vertex colour,
   `ship_sails.gd`'s cull margin) so they fill on the wind. Stills, including a sail
   filling.
4. **Collision and the fly-through.** `solids()`, `inside()`, the bow pad, the
   tunnel walls and lips, castles, the wider beam, per the concept note. The bow
   plate's shards clear the tunnel roof. Prove it on real input with rocking on:
   both ships, stern to bow and bow to stern, the wall and roof glances, a sink, the
   camera through the tunnel. Drivers are in `scratch/ship_rock/` (`rock_fly.gd`,
   `ship.gd`, `ship_wall.gd`, `ship_sink.gd`, `ship_two.gd`).
   **Spec change (coordinator, after 268f116b):** the tunnel (x ±10.4) is wider than
   the gun deck (±9), so a 1.4 m ring round the bow plate faces a plane coming in from
   the bow, and an off-centre plane glancing along the tunnel wall crashes on it. Funnel
   it: chamfer that ring in the model and in the collision so the plane is guided into
   the gun deck and glances, not crashes. Prove it with an off-centre bow-to-stern pass.
5. **Guns.** Only after the `merge ship-guns` commit is in the trail; until then skip
   to the next task. Three hull guns a side at the new muzzles (`Gun_*_01..03`) and
   the deck guns modelled to the guns handoff's contract (`DeckGun_*_01..02`).
6. **The figurehead.** Dropped (see Picks): skip. Build the pick
   properly and place it.
7. **Finish.** Visibility ranges and import LODs per the concept's model-budget
   table; `--ship-blocks` and `--one-ship` still work; final stills at 30, 100 and
   300 m, the chase camera, the fly-through, sunset; triangle and draw counts, no frame
   times (other agents share the GPU). The handoff `ship-build-handoff.md`, with the
   model-budget table (AGENTS.md, Models).

## Picks

- Figurehead: **none.** The user saw the three options (e6b007e6) and said "Looks rough. Let's axe it for now." Task 6 is dropped: no figurehead on the build. Leave the options in the concept script behind `--fig` (off); don't port them.

## Checks every iteration

- `python3 tools/smoke.py studies/endless_flight.tscn`, and the same with
  `-- --ship-start --full-meter`. Once the model is in: with `--ship-blocks` too.
- Blender builds exit 0 with their self-checks:
  `python3 tools/blender.py run art/blender/ship/ship_build.py`, then
  `python3 tools/godot.py --headless --editor --import` with 0 errors.
- Anything seen: rendered stills, looked at and fixed before committing. Stills go
  in `docs/design/endless-flight/ship-build-stills/` (images under `docs/` are
  git-ignored: force-add them, with a `.gdignore`, as `pirate-ship-stills/` does).

## Gotchas

- Never `git stash` / `git stash pop` (the list is shared and holds the user's work);
  compare with `git show <rev>:<path>`.
- Drivers and play runs save to /tmp only (`--pilot-file=/tmp/...`).
- One rendered window at a time, short, quit by a watchdog, `-- --no-title`. A hung
  rendered run can leave a stale window lock: check its process is dead before
  removing the lock.
- With `--ship-start`, Godot sometimes hangs on quit after a clean run. That was there
  before this loop (it happens at `--ship-rock=0`); note it, don't chase it.
- The sun and the sky's fill lift dark albedo about two stops in the game; set values
  by eye in the game, not in Blender. The chase view is often backlit, so her stern
  reads near black there.
- No game pitch or comparisons to other games in docs or comments (AGENTS.md).
