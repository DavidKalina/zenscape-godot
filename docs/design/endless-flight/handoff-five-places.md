# Handoff: five places (loop `five-places`, 2026-11-16)

Spec: `spec-five-places.md`. Branch `claude/game-kit-ideas-7fac96`, not pushed.

## Built and merged

| Place | Centre (x, z) | Off switch | Lane commit | Files |
|---|---|---|---|---|
| Map page (M, pause menu) | | | ee3c78a7 | `scripts/endless/ui/map_page.gd`, `tools/map_bake.py` |
| The viaduct | -3245, -3404 | `--viaduct=0` | ffb3e28f | `viaduct_site.gd`, `viaduct_build.py` |
| Great dome | -960, -2030 | `--dome=0` | 4a8722a8 | `dome_site.gd`, `dome_build.py` |
| Great bridge | 1226, 1287 | `--bridge=0` | 37cc4063 | `bridge_site.gd`, `bridge_build.py` |

Site scripts are under `scripts/endless/`, builds under `art/blender/temple_kit/`.
All three places are on the map page.

## Not merged

- **Windmill ridge**: built and flown on branch `worktree-agent-a7fa06d78da6d985e`
  (873c189d). The user saw the stills and rejected it. Left on its branch.
- **The harbour and its sea gate**: merged, flown by the user and rejected
  ("freaking sucked"); the merge is reverted (38fa901a). It is on branch
  `worktree-agent-ab265860292ad27cc` (f4588942), centre 865, -2030.
- **Colossus**: a script-sculpted figure at the harbour mouth, rejected and
  removed; the sea gate stands in its place. A try at standing the Amberlands
  giant there was stopped at the user's word.

## Proof run

- Smoke check with the three places in, after the harbour revert: PASS, 0 errors.
- The user flew a 27 minute flight past all of them with `--frame-log`; the
  viaduct, dome and bridge were "solid".
- Map page driver, rendered: 19 checks, 0 failures.
- Each lane flew its openings through the real play loop on medium weight, with
  and without Boost, off-centre and slanted, by scripted driver (drivers are in
  each lane worktree's `scratch/`, uncommitted). Nothing was hand-flown.

## Open

- Bridge: 4 of 12 slanted off-centre Boost lines through the west bay fail
  (the gorge forces a bend 60 m before it). The lowest deck lines pass the
  gate jambs by 2.1 to 3.2 m. The arch is hidden by its gorge from most sides
  at 2 km.
- Dome: the pull-up out of the eye is tight with Boost. Seen from the north it
  sits against the Peak's flank.
- Viaduct: one fallen-top span is tighter than the rest (2.5 m on the worst
  line). The plain under it is flat, so the piers are all one height.
- 985 "Parameter material is null" errors from one early viaduct flight run
  were not reproduced; they appeared only while several Godot processes ran at
  once.
- A 260 ms frame on a rendered approach to the bridge, not the bridge's own
  frame, untraced.
- Frame cost of the four places has not been measured on a flown flight.
- The merge moved the viaduct's setup out of the citadel's block in
  `way_towers.gd` (the lane had put it between the citadel and the tombs).
- The harness has no shared flight follower; every lane wrote its own.
