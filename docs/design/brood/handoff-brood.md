# Handoff: the stone brood (loop `brood`)

Branch `iter/brood` (worktree `../zenscape-brood`), off `iter/carry` with
carry merged in at 6a0db8b6 (the bag and its load). Spec:
`spec-brood.md`. Greybox only.

## Play it

`./run-wreck-cluster.command -- --plane-fixed`, from the brood worktree.
Lift a treasure (E), watch the rim, run, load it into the bag behind the
plane, take off, bank, skim or thread a gap to shed riders.

Flags: `--brood-count=N` (default 40), `--brood-one` (one guy that chases
you), `--no-brood` (off; carry's own drivers need it on this branch).

## What's built

- **Stone guy** (`scripts/brood/stone_guy.gd`): a box figure about 0.55 m,
  no physics body, 2–3 rays a step. Walks, climbs faces and overhangs,
  mantles, drops ledges up to 7 m, never jumps: a gap or the rim stops him.
- **The wake** (`scripts/brood/brood_host.gd`): the first lift in a deal
  brings 40 up over the isle's rim near the treasure (spots found by rays),
  hands then head then the heave over. N puts them away.
- **Grab and shove:** up to 8 cling to the holder, each slows him, they
  shove; 5 on for 1 s knock the treasure loose (carry's `drop`). A jump
  throws them off. No damage.
- **Mob and haul:** a loose treasure is lifted by 2–4 by weight and carried
  home slowly, the rest as escort. E lifts it back; running into the crew
  knocks haulers off. Home, they settle.
- **Numbers:** 40–50 with a crowd step; rendered on the Mac at 40, vsync on,
  60 fps held; the brood costs about 0.4 ms a frame.
- **Riders:** loading the bag wakes 10 more from the strip's rim (the 40
  can't cross the gap to the strip). Boarding, up to 5 leap onto the bag,
  2.5 kg each through carry's load (capped below the takeoff limit). A hard
  bank, a low skim, a cliff close by, a narrow gap or a bag hit sheds them.

All numbers: `scripts/brood/brood_knobs.gd`. Carry edits are small and
additive: `set_slow(k)` and `set_riders_kg`.

## How it was proved

Throwaway drivers through real input, in `scratch/` (uncommitted):
`brood_one`, `brood_wake`, `brood_grab`, `brood_haul`, `brood_perf`,
`brood_ride` (bank, calm, skim, side, gap). The skim, side and gap runs
teleport the plane into place, so they prove the shedding, not the flying
to it. The stuck-haul give-up (8 s) never fired in a run.

## Open

- Balance: standing still you lose the treasure in about a second; on the
  causeway the haul home is short.
- The second wake at the strip: an agent's call so the riders exist. If the
  strip should be safe once you've crossed, drop it (one knob) and let
  riders come only from guys who reached the plane.
- The first 40 stand at the strip's gap edge for the rest of the deal.
- Riders grab the bag only, not the plane.
- Tall grass hides a knee-high guy; the stone has a small glow so it reads
  in the isle's deep shade.
- Looks, clips, sound: a later round (skill `enemy-build`, body lane).
