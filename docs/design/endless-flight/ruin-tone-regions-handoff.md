# Ruin tone per region, colosseum placed reliably (2026-10-28)

The regions world (the default since 4dc8bd8a) lost two amberlands looks.

## Basalt ruins

`ruin_tone` and `set_moss` were read from the whole world's profile, which in
the regions world copies the home region's (wilderness) layers. Every ruin
fell back to amber, the amberlands' included.

Now `LandArches.tone_name(at)` / `tone_lift(at)` / `_set_moss(at)` read the
profile of the region at the piece (`WorldProfile.at(x, z)`; a uniform world
answers itself, so nothing changes there). Materials are kept per tone:
LandArches `_stone`, `_gothic_stone`, `_tops_stone`; LandHalls `_stone`, and
for the tunnels' stretches LandHalls `swap_of` (LandTunnels `_dark_materials`,
one table per tone).

## Colosseum

It needs a 472 x 416 m footprint within `spread` m. At 0.22 a set cell and
12 m, seed 1 stood none within 12 km of the start in the regions world (3 in
the amberlands alone). `COLOSSEUM` is now w 1.0, spread 16 (the footings'
depth, `FOUND` 8*K): 14 within 12 km, nearest at (3386, -666), 3.4 km out.
Planning time over those 576 cells rose ~29% (on the workers); boot (smoke
ready) unchanged at 16.7 s. `--colosseum-chance=P`, `--colosseum-spread=M`
to compare.

## Proof

Smoke check of endless flight (0 errors). A throwaway driver started by the
colosseum: it stands with basalt `(1.3, 1.32, 1.42)`, a wilderness arch amber,
an amberlands arch basalt; rendered stills looked right. Halls and tunnels in
the amberlands were not checked by eye. No tests changed.
