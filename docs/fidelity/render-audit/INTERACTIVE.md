# Interactive comparison

The shared world is the existing imported seed-7 mountain, not an approximation
generated independently in Godot. The current rebuilt Electron terrain, arch,
skirt, and sampled named vegetation/prop meshes and placements were checked
against the import fixture. Godot's import check passed 42 mesh groups and all
5,366 instance positions.

Launch:

- Source checkout: `run-electron-comparison.command`
- Godot checkout: `run-godot-comparison.command`

Both launchers open real interactive applications. Electron uses the rebuilt
`dist` through its real application protocol and shell, with a fresh temporary
profile per launch. It does not open the normal writing/world profile. Rebuild
with `pnpm build` in the source checkout after future source changes.

On the current Retina display, both render at 2400×1500 physical pixels. The
starting camera is `43,1.13,1.8893,0,3,0`, time 0.35, mist 0.02, haze 0.03,
cloud 0.06, shroud 0, and wind 0.4. Day cycling and automatic orbit are off;
world animation runs normally, with independent clocks.

F6 (Fn-F6 if required by the keyboard settings) restores the common camera.
The Godot window also supports F7 to compare revised/previous camera response
and F8 to compare filtered/previous shadows; its title shows both active modes.
Switch applications with Cmd-Tab. Left-drag orbits and the wheel zooms. Pan
with right-drag in Electron and middle-drag in Godot. Compare at equal window
sizes, preferably one focused application at a time. Both applications running
simultaneously share GPU resources; this setup is for interactive visual feel,
not an isolated performance benchmark.

The geometry is shared, but water/wildlife animation and rendering are native
implementations and are not expected to match pixel for pixel. Godot's normal
editor controls are hidden for the comparison (`--clean`); H reveals them.
The Godot launcher does not load or overwrite the saved edited garden.
