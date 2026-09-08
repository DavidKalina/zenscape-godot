# Waterfall drips and pool rings

Sparse droplets peel away from editable waterfall edges. Each follows a short
fall into the adjacent pool, producing three tiny splash beads and a thin ring
that expands and fades over 1.35 seconds. Emitters have staggered phases and
different intervals of roughly three to five seconds.

Placement uses the waterfall's actual strand geometry and pond surface. Paths
through terrain are rejected, and ring footprints are checked against the pool
and nearby ground. Terrain rebuilds reseed the effect. This first pass supports
waterfall-to-pond drips; it does not identify arbitrary wet rocks or foliage.

The effect pauses with the diorama and stays hidden during terrain/water growth
and when ice exceeds 0.1.
Three MultiMeshes cap the population at 12 falling drops, 36 splash beads, and
12 rings. It adds no saved state. Rings render after transparent water, with
depth testing retained. Separate performance profiling remains to be done.

## Evidence

`comparison.mp4`: drips LEFT, same scene without drips RIGHT. Eight seconds at
24 FPS. Look below the waterfall tip: first impact is around 0.55 seconds,
followed by impacts around 3.65 and 6.75 seconds. The benchmark accepts two
emitters, one per waterfall, at normal production density.

Reproduce with native Forward+ and `tools/film_waterfall_drips.gd`. Frames go
to `/private/tmp/zs-drips-effect` and `/private/tmp/zs-drips-control`.

`tests/test_waterfall_drips.gd` passed on Godot 4.7.2 / Metal. It checks falling,
impact, ring expansion and fading, splash/ring expiry, pause, population bounds,
and stale-effect cleanup. It requires native rendering because the headless
renderer does not retain the MultiMesh transforms/colors inspected by the test.
