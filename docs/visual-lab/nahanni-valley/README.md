# Nahanni-inspired valley experiment

Question: can a compact diorama suggest a broad northern river valley and immense enclosing walls, while retaining narrower canyons as a separate composition?

Run `./run-nahanni-valley.command`. This is a disposable visual study, not a geographic reconstruction. The reference is Nahanni's combination of mountain valleys and deep river canyons, described by [Parks Canada](https://parks.canada.ca/pn-np/nt/nahanni/nature).

## Explore

- 1 / 2 / 3: open valley, limestone canyon, valley narrowing into gorge.
- Narrow / Broad / Wide floor: independent width settings (5 / 10 / 13 engine units before composition-specific narrowing).
- Short / Tall / Extreme: wall amplitude 12 / 24 / 32. Bracket keys adjust height. The initial view uses 16 for more breathing room.
- Cloud altitude slider moves the upper band; K toggles atmosphere and P freezes drift. A lighter low fog volume sits along the river corridor.
- C resets the overview; F focuses Bigfoot; Space orbits. Standard mouse navigation remains available.

## Construction and limits

A continuous winding water course carves its own bed through the new terrain. Forest placement avoids the river, steep slopes, and high walls. The original mountain/cloud prototype supplies camera controls, scale reference, shaders, and cloud animation; earlier studies remain available unchanged.

The first render with narrow floor and 24-unit walls was too enclosed to represent an open valley. The default now uses a wider floor and 16-unit walls. Tall and extreme settings deliberately explore exaggerated canyon proportions. Rock is currently the existing faceted material: geological strata, talus slopes, gravel bars, tributary valleys, and a larger multi-chunk river landscape remain future work. Forest uses existing conifers, not a new tree-variety system. The river is an authored descending course, not a hydrological simulation.

## Verification

Native Godot Metal Forward+ captures cover all three compositions at heights 12, 16, and 24; separate captures vary floor width at a fixed height. Clouds-off and two animation-time images support visual comparison. These are visual smoke checks, not a performance benchmark. The inherited scene may report its existing six ObjectDB leaks at shutdown.

[Comparison gallery](index.html). Generated PNGs stay local; regenerate with `tools/prototype_capture_nahanni_valley.gd` using the native Godot executable and Forward+ rendering.

User verdict: pending exploration.
