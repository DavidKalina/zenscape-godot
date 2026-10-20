# Big isle: greybox handoff

**Built.** `studies/wreck_cluster_big_isle.gd`, wired into `studies/wreck_cluster.gd` (`_build_big_isle`). Greybox KitLand turf on hanging keels (home-isle style, made with `Art.hang_rings`/`hang_rock`), no flora or dressing. After the user said the first pass looked too boxy, it was rebuilt to match the reference arrangement: a mother isle (turf 66) with a seven-fang keel. On its south half stands a cliff-sided crown (turf 106) with ruins on its rims. On the crown's east end a summit stack (158) carries a tower as the landmark. Around them are satellites at 88 to 150 (sat_e, sat_ne, sat_s, sat_far, sat_nw), a pair of arch islets with a rock lintel, and 9 floating rocks. A stepping chain (low_islet 46, step_a 51, step_b 56, step_c 61, mother 66) is joined by four live rope bridges, and all four were walked.

**Where.** South of the stretch, south-east of home. The mother isle is centred at (-470, -250) and the low islet at (-667, -78). From the home start it is in view on the left, past the plane. Flying home to the low islet with a circuit took 25 s, and touching down took 47 s in total.

**Flag.** On by default. `--no-big-isle` leaves it out (see the scene header). It also builds with `--wreck-start --no-stretch`.

**Flown openings** (`WorldScale.opening`): the gaps in the chain use `STEP_TOY` 6 (12 m), set out by their extent along the chain's direction so no gap is narrower. The arch islets stand `ARCH_TOY` 7 (14 m) apart under the lintel.

**Handles** (all under `big_isle/`):
- Islands: `big_isle/{mother,crown,summit,low_islet,step_a,step_b,step_c,sat_e,sat_ne,sat_s,sat_far,sat_nw,arch_w,arch_e}`.
- Pieces: `big_isle/{crown_tower,summit_turret,crown_turret_e,crown_turret_w,crown_gable,crown_arch_w,crown_pier_s,mother_arch,mother_wall,arch_lintel,floater_01..09}`.
- Treasures: `big_isle/treasure_01..05`.
- The bridges are not tracked by the layout system (nor is the cluster's StripBridge), so they stay put if their islets are moved.

**Landing turfs** (longest clear run from the scene's `longest_run`; each landed by an input autopilot and stopped):
- `low_islet` (46): 147 m along z -78. Easy, nearest home, the far end of the chain.
- `mother` (66): 209 m, run along z -200. The deep treasure is about 46 m from the stop.
- `crown` (106): 141 m, run along z -270. High, about 80 m from the best treasure.

**Treasures** (the carry spot rows, `BigIsle.spots()`):
- 01 idol, light: low islet's west end, easy.
- 02 urn, medium: step_b, low and in the chain.
- 03 urn, medium: mother's west rim.
- 04 egg, heavy: deep on the mother, under the crown's north cliff.
- 05 chalice, light: crown top at the summit's foot, the best.

Lifting each one woke the 40-strong brood. No brood code changed: `rim_spots` works on this land as is.

**Other code change.** `scripts/carry/carry_host.gd`: a treasure id containing "/" is used as its full layout name, and node names swap "/" for "_". This is additive; existing ids behave as before.

**Proof.**
- Smoke passes: default, `--no-big-isle`, and `--wreck-start --no-stretch`.
- `scratch/big_isle_fly.gd` (uncommitted, git-ignored) passes 18/18:
  - board at home, take off, fly out and land on low_islet, all by real input;
  - walk to treasure_01, lift it with E, brood wakes;
  - fly_from to the mother's and crown's approaches, land, get out, lift 04 and 05, brood wakes.
- `--lifts` lifts all five, and `--bridges` walks all four bridges.

**Stills** (`captures/shots/big_isle/`): `start_own.png` (the home start), `approach.png` (from the stretch), `aerial.png`, `lap_south.png`.

**Tests broken.** None known. No test references the wreck cluster or its treasures; the full suite was not run.

**Harness gaps.** No flight or landing helper for the kit isles. The driver carries its own small autopilot (steer, glide path, flare, brake); a `fly_to`/`land_on(run)` in drive.gd would help later rounds.

**Open.** The tower on the summit is small at a distance, and the keels' tiers read as stacked bands. A look pass could fix both. Bridge 1 is 42 m long because the low islet is elongated.
