# Arch fit on the motif isles (handoff)

Measured by `scratch/arch_margin.gd` (throwaway, not committed): rays down from
each arch's foot points (arch_foot, and low mesh vertices) to the ground in a
band round the piece's base; margin = metres of ground beyond the point
(negative = out over the void).

| Isle | Before | After | How |
|---|---|---|---|
| cloister_tarn | NE arch -2.5 m (pier and buttress hung off the 5.8 m islet); west lancet wall -2.75 | arch +1.25 m; lancet -0.25 (one stone), p10 +1.25 | NE satellite r 5.8 -> 10.0, centre 3.2 m further out (rim to the mother and the bridge stay put); west satellite r 5.2 -> 7.4, centre 2.4 m out; lancet centred. REACH 54 -> 62 |
| broken_ring | arch -1.25, lancet -2.25, rose gable -6.0 | arch +1.5, lancet +0.25 (p10 +1.0), gable +1.5 | SATS: arch isle 7 -> 9.8 (dist 26 -> 30.5), lancet isle 7.6 -> 8.0 (27.5), gable isle 7.5 -> 12.5 (35.5); lancet and gable centred (6th field 0.0). REACH 38 -> 50 |
| bell_spires | arches +0.75 m (already fitted by `_fit_arch`) | unchanged | |
| sundered_gorge | gate +1.5 m | unchanged | rose gable has one stone -0.75 at the lip |
| colonnade_spine | portal piers +1.5..2.25 m; temple walls step down at the terrace edge | unchanged | not an overhang of the arches |
| drowned_nave, hollow_keel | +8 m / +2.25 m | unchanged | hollow_keel's negative corners are the shaft hole, not the rim |

Rim-to-rim gaps of the ring (nominal, m): bridge 0-1 5.6 -> 4.9, stones 2-3 4.5 -> 4.4,
jump 3-4 1.4 -> 1.5, jump 6-7 2.0 -> 2.0, break 9.4 -> 8.3. The cloister west islet
is kept at r 7.4: at 8.0 test_motif_sky's open-run scan finds a "run" on it and the
plane cannot land there.

Not done: rolled rings (layer generator) still put the same notes on small rolled
islets; only the authored sky ring was fitted.

Existing tests the change breaks
- `tests/test_motif_families.gd`: broken_ring's two "builds today's isle" fingerprints
  (expected, the isle changed). Its colonnade_spine fingerprint fails too; colonnade
  is untouched by this round.
Passing: test_cloister_tarn_isle, test_motif_sky, test_aqueduct_isle_sky, test_ledger,
test_serpent_route, test_airship_ferry, test_plane_arc, test_world_scale_fit.
Smoke: aqueduct_isle and motif_yard --motif=broken_ring, 0 errors.
