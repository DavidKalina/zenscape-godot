# Handoff: home base (loop `home`)

Spec: `spec-home.md`. Trail: `git log --grep='^ITER(home)'` on branch
`iter/home` (worktree `/Users/davidkalina/Documents/Projects/zenscape-home`),
five tasks and one spec change (the isle's shape and the start camera in the
look pass), not merged.

## Play it

`./run-home-base.command` (the wreck cluster study with `--home`; it keeps
its tally in `$TMPDIR/zenscape-home-base-ledger.json`; add `--fresh-ledger`
to start over, or your own `--ledger=`). You start on foot behind the parked
plane at the home strip's west end, looking east down the strip toward the
stretch. Fly east 700 m to the wreck cluster, load the bag (E, pad B), fly
back, then either land and roll onto the sand pad north of the strip by the
vault and stop, or come in low and slow over the drop field south of the
strip and press E (pad B) in the air. N re-deals the cluster; R respawns at
home.

## What's built

- **The home isle** (`studies/wreck_cluster_home.gd`, world view
  `island/home`, pieces `home/<piece>`): a KitLand landform west of the
  stretch's `rocks_e`, a tongue in the east widening west, turf at 26 m. The
  strip runs along z 16 from x -762 to -927 (165 m, 7 m either side kept
  flat); a loaded (20 kg) plane touches down about 27 m past the rim and
  stops some 12 m later. Under it a sheer band, two overhanging tiers and
  seven fangs leaning east. Two stacks stand off it as their own lands
  (`island/home_spire_s`, `island/home_spire_n`, an arch and a pier on
  them). A bluff with an arch at the NW, a hummock at the SW, a knoll on
  the tongue's south rim.
- **The vault** (`home/vault`): RuinKit floor, three walls (open south),
  four piers, three buttresses, weathered and grown over; banked treasures
  stand on its floor (16 spots, two layers). The tally board (a slate in a
  stone frame) stands outside its door.
- **The deposit pad** (`home/deposit_pad`, drawn only): sand in a stone kerb,
  red chevrons pointing in. Stop on it on the wheels and the bag gives up
  its treasures one by one (0.9 s apart, an arc into the vault, a chime).
  A treasure carried in by hand banks too. Brood riders count as nothing.
- **The drop field** (`home/drop_field`, drawn only, 52 x 16 m): sand,
  straw heaps, tufts and bales, two rope nets, a kerb, four red pennants.
  The drop action (`fly_drop`, E / pad B, flying only) opens the bag; the
  bag stays on its rope. Each treasure's hit (fall speed plus the run's
  speed at RUN_SHARE) under SAFE lands soft and banks; past it a chance to
  break rising to sure at SURE (shards, dust, a crack, "-N"; lost till N).
  Off the field they lie where they fall.
- **The tally:** one value table (`scripts/home/vault_host.gd` VALUES: idol
  40, urn 60, dragon egg 150, chalice 30). The ledger keeps the total,
  counts and the banked kinds (`vault` in `scripts/ledger/ledger.gd`), so
  the board and display last across runs. A banked treasure leaves the
  cluster's deal; N stands a fresh one on its spot. The study without
  `--ledger=` keeps the ledger in memory.

## Open items for tuning

- Drop pass numbers (`scripts/home/drop_pass.gd`): SAFE 13 m/s, SURE 20,
  RUN_SHARE 0.7. A brake pass at about 3.5 m bag height and 9 m/s hits
  8.3-8.5 (all soft); a boost pass 22 m over hits about 17.5 (64% break
  each). Air damping eats much of the run speed on long falls.
- Whether hard ground off the field should break things (it doesn't; a
  drop off the field acts as a spill).
- Per-kind fragility (the egg could be more fragile, the idol less).
- The drop hint text ("Drop field: E / B opens the bag. Low and slow lands
  soft.").
- The keel's tiers read as two very even stripes from the side (KitLand
  rings are uniform per ring; irregular tiers need per-point drops in
  `Art.hang_rings`).
- The turf's tone looks green in some runs and ochre in others (seen in
  start stills before and after the landform change; cause unknown).
- The board's text is one Label3D; the rows "idol x1    urn x1" are set in
  `VaultHost._show_board`.
- The straw is primitives: 60 heaps sharing one low sphere (10x5), 2200
  tufts in one MultiMesh, 30 mats and some bales as boxes, all drawn only
  and without shadows. If the field ever costs frame time, the mats and
  bales can merge into one mesh.

## Checks (last run)

- Smoke `studies/wreck_cluster.tscn` plain, `--home --ledger=/tmp/...`,
  `--no-stretch`: PASS.
- Drivers (uncommitted, `scratch/` in the worktree): `home_start.gd`
  (start, strip, take-off, the stretch; `--land`), `home_vault.gd` (carry
  in, land/taxi and unload; `--land`, `--shot`), `home_ledger.gd`
  (`--step=bank`, then `--step=again` in a new process), `home_drop.gd`
  (`--mode=slow|fast|off`, `--shot`). Headless they pass. Under
  `drive.py --rendered` their scripted flying runs at the window's frame
  rate and can miss: one rendered `home_vault.gd` run failed to stop on the
  pad and one rendered `home_drop.gd --mode=fast` dropped its load off the
  field; rerun headless for the verdict.
- Stills: `captures/home/` (start, approach, isle_low, vault, vault_full,
  look_board, look_vault_w, pad_air, deposit, field_air, look_field_close;
  drop_break is from before the field's look pass).
