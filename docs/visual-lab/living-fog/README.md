# Living fog atmosphere experiment

Run `./run-living-fog.command`. This extends the inland visual lab with a native Godot FogVolume and a scratchpad on the right. Terrain, habitat, seed, moods, and existing mountain clouds remain available.

- **Rolling bank:** persistent low cloud that drifts, billows and opens under gusts. Writing stirs it without clearing it away.
- **Writing veil:** starts covered, then opens in irregular wind-shaped patches as characters accumulate. It clears after roughly 180 freshly typed characters plus a short settling period.
- **Off:** removes the added bank and restores the initial wind setting.
- Density and bank height adjust the atmosphere independently of the landscape.
- **Gather fog again** resets the writing meter and lets the veil gather. The scratchpad is memory-only; typing never writes journal text or changes terrain records. Paste-sized changes are ignored by the rhythm meter.

## What the Electron effect does

`writing.js` converts typing pace into an eight-second rate meter with a 2.5-second rise and six-second decay. `wind.js` adds word-triggered gust parcels to the shared wind field. `fogbank.js` and the shroud in `weather.js` use this field to open holes, retain patches in quieter air, and carry remnants downwind during a reveal. Chunk presence separately controls gathering and disappearance; typing rhythm is not the whole reveal system.

Godot already had shared integrated wind travel and gust parcels in `studies/atmosphere.gd` and `reference_wind.gdshaderinc`. This prototype reuses them so foliage, water and fog receive the same gust. A native fog shader adds cloud volume, wind-shaped gaps, and gradual coverage. Wind travel is integrated rather than multiplying elapsed time by a changing speed, preventing texture jumps when typing accelerates.

The typing meter uses the source's fixed initial 260 CPM baseline. Personal pace learning/persistence, production journal wiring, and the original empty-chunk/frontier presence lifecycle are not part of this experiment. The writing veil demonstrates the dissipation on an existing world; it does not generate a chunk or reproduce the archive reveal flow. This is an atmosphere exploration, not a complete source fogbank port.

## Verification

`tools/prototype_capture_living_fog.gd` renders the native Forward+ scene and checks that sustained typing builds wind, the veil clears, rest decays the writing signal, and the terrain snapshot remains identical. Captures show calm, active wind, whole veil, tearing veil, cleared veil and controls. Final native capture completed without script or shader errors. Existing shutdown ObjectDB warnings are unchanged.

No production performance claim; volumetric fog needs Forward+. Assess movement in the running lab, since a still cannot show the gust timing. The desired aesthetic verdict is whether the bank feels alive at rest and responsive without becoming distracting during writing.
