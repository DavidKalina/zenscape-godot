# Spec: mountain tunnels (loop `mountain-tunnels`)

The build is `overgrown-tunnels-brief.md` beside this file: everything in it,
in its order (one tunnel by flag, dress it, place many). Read the brief in
full; this file only adds the loop's rules.

## Done

The brief's **Proof the user will want**, every line, seen:

- `--world=overgrown --tunnel-test` starts a few hundred metres from a raised
  massif. A winding bore runs through it, 1.4 to 2.1 km along the path, of
  hall stretches and rock caverns, lit by torch lines, and flies through on
  the real input path in 30 to 45 s at boost.
- With no flag, `--world=overgrown` streams tunnels from the seed, with
  their massifs, holes at the mouths that agree at every LOD, handles, and
  the flats kept.
- Wilderness hashes, stills and frame time unchanged.

## Where

- Branch `claude/overgrown-tunnels-mountain-b0bdd5`, worktree
  `C:\Users\Tenut\zenscape-godot\.claude\worktrees\overgrown-tunnels-mountain-b0bdd5`
  (Windows). It already holds `world/overgrown-slot-halls` merged under
  main; read `overgrown-halls-handoff.md` first.
- One trunk, no lanes: the massif, the bore's path, its solid, the mesh holes
  and the torches all hang off the same path.

## Checks each iteration

- Smoke (`tools/smoke.py`) of `studies/endless_flight.tscn` with
  `--world=overgrown` (and `--tunnel-test` once it exists), `--on-foot`, and
  the default world.
- Flight and walking through the real play loop (`tools/drive.py`), left in
  `scratch/`.
- Stills (`tools/shot.py`, `-- --no-title`) for anything seen; look at them
  and fix before committing.
- Once the massif exists: `tools/land_hash.py` for wilderness (seed 1
  `c515311f…`, seed 7 `cd244951…`) and the flats check from the brief.

Cap: the skill's default.
