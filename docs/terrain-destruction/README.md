# Explosives in the main game

Run `./run-diorama.command` from this worktree. Explosives are part of the shared native editor, available in the main game and scenes built on the fidelity editor.

1. Enter **Build**. Pick **Explosive** from the Place shelf, or search for it with Cmd/Ctrl K.
2. Set the blast radius (1–6 m) and optionally enable **Hide under leaves** on the remote, then click to plant a charge.
3. To bury one, use **Lower** to dig, plant the charge, then use **Raise** to cover it. Its elevation stays fixed while terrain changes; the remote reports it as buried.
4. Switch tools or return to **Enjoy**. Select one charge or **All charges** in the remote, then click **Detonate** or press **X**. Clicking a visible charge with Select also targets it in the remote.
5. **Undo last blast** restores the exact pre-blast terrain, water/cover records, scenery, and armed charges. Normal Undo/Redo also works. Each salvo is one history entry; later edits use the normal history sequence.

The remote's radius and camouflage controls edit the selected charge. With All charges selected while holding the Explosive tool, they configure new placements. Buried charges remain accessible through the remote even when the terrain occludes them. Charge identity, fixed elevation, camouflage, and radius survive save/load.

Blasts deform the existing irregular terrain mesh and refresh the collision used by world physics. Nearby authored scenery is removed from the landscape and launched as physical copies of its real meshes. Legacy imported reference trees, logs, and boulders are migrated into ordinary records before destruction; undo restores their source representation too. Dirt fragments, dust, flash, and synthesized rumble accompany detonation.

Up to 32 charges can be armed at once; a salvo launches at most 100 bodies. Flying wreckage is transient and clears after 18 seconds, on another blast, or on editing/restoring/changing the world. Saved damage includes the crater and removed scenery; flying wreckage is not saved as newly placed objects. Undo history is session-local, like other editor operations.

Blasts carve the heightfield; the Tunnel tool below adds enclosed bores beneath it. Very deeply buried or elevated charges outside the blast's vertical reach cannot deform the surface. Native terrain retains its existing -1.5 to 64 m bounds. Asteroids remain a future use of the shared blast operation.

## Mountain collapses

An explosive near a high, steep summit can now trigger a rockslide beyond its crater. Try a 3.5 m charge near the top of **Silverhorn tarn**, **Sleeping volcano**, **Skywater plateau**, or **Emerald ridgeback**. Flat ground still receives an ordinary crater.

Damage loosens connected steep terrain. A gravity-driven relaxation lowers the unstable sections and deposits their volume farther downhill; scenery on displaced ground joins the slide even outside the direct blast. The changed slopes and rubble deposits are saved as ordinary native terrain. Up to 32 chunks per collapse are cut from the mountain's actual surface triangles with matching rock/snow vertex colors. They detach over a short stagger, tumble under physics, and raise dust. All collapse chunks share the existing 100-body budget, with room reserved for scenery and blast debris.

The blast and collapse are one undo transaction. **Undo last blast** restores the original summit, vegetation, objects, and charges, including while slabs are still falling. Pause holds their delayed release and motion. Redo restores the altered terrain without replaying the transient effects.

This models local slope failure in the existing terrain surface, rather than structural support inside a voxel mountain. The collapse solver does not generate new caves or overhangs. Eligibility follows height, slope connectivity, and blast damage, so custom sculpted mountains can participate without a special terrain-type flag.

## Verification

Run with the local Godot executable and `--headless --path . --script`:

- `tests/test_mountain_collapse.gd`: flat-ground exclusion, summit and near-summit collapse on four mountain families, downhill volume conservation, failure beyond the crater, physical chunks, scenery outside the direct blast, pause, save/load, and exact undo/redo.
- `tests/test_native_explosives.gd`: real main-game placement, burial and occlusion, leaf rendering, save/reopen, malformed data rejection, pause, individual and X-key all-charge detonation, moving scenery, crater collision, exact undo/redo, and world cleanup.
- `tests/test_explosive_landscapes.gd`: all eight curated families (redwood grove, valley, plateau, cone, ridgeback, horn, canyon, terraced pools), charge budgets, and the legacy fidelity scene including reference scenery destruction/restoration.
- `tests/test_native_object_editing.gd`: existing object editing/persistence regression.
- `tests/test_command_palette.gd` (removed): existing palette interaction regression; requires graphics because it captures a viewport image.

These checks passed. Main-game renders of exposed, leaf-covered, buried, detonated, and restored charges were inspected with Forward+. The remote occupies the lower-left corner to avoid the existing right-side tree controls and status text.

The broader `test_native_chunk_editor.gd` has three existing failures: blank ground-map water clearing, an authored-tree terrain-following assertion, and authored-water map sampling. The same three failures reproduce on unchanged main at b93160a. Some existing graphical/scene test shutdowns report resource cleanup warnings; the main explosives integration test finishes without script errors or leaked-object warnings.

## Original playground

`./run-destruction-playground.command` (removed) still opens the original isolated Blast Garden. It uses click to plant, Space to detonate, Shift-click for an instant blast, and R for full reset. Its 12-charge budget and small grid terrain are separate from the main game's native model. `tests/test_terrain_destruction.gd` (removed) verifies that experiment.

### Bigfoot blast reactions

Nearby charges launch Bigfoot into a physical tumble. Radius and distance control
his speed: small charges pop him up; large close blasts can throw him off the
island. He gets back up after landing, or respawns on safe ground near the center
if he falls into the void. His existing airborne and landing animations keep the
reaction playful. A held Bigfoot stays in your hand.

Pause freezes the flight. Undo last blast restores his pre-blast position along
with the terrain. Flight is transient and uses the existing resident collision
proxy; normal wind behavior is preserved. Terrain rebuilds leave his flight alone.

Validation: `tests/test_bigfoot_explosions.gd` (removed) exercises the actual main-game remote,
launch, landing, power scaling, pause, off-map respawn, safe placement, undo,
out-of-range immunity, and carrying. `tests/test_creature_wind.gd` covers existing
wind and recovery behavior.

### Explosion performance

The live remote publishes flash and rumble before loose-prop flushing or legacy
scenery migration. Those preparatory refreshes use the same frame budget as the
rest of the editor. Carving, internal rupture, and mountain relaxation run on a
detached terrain snapshot in a worker; they retain their original ordered math.

The main thread uploads prepared chunks and builds cleaned convex hulls from
retained CPU vertices. Bodies remain hidden, frozen, and non-colliding while
staged. Each debris group becomes visible when its matching terrain, scenery,
or landmark source is replaced. Physics releases only after the complete
refresh and crater collision are ready. A rejected refresh is retried; clearing
the world invalidates the pending blast. Heavy debris carries mass-scaled
impulses that are applied exactly once on release.

Jolt Physics is the project physics engine. The worker collapse, detached face
probes, native mesh-shading default, and CPU collision/hull optimizations from
PR #7 remain in place. Flash and dust no longer cast opaque shadows. Tests and
offline tools can call `detonate()` synchronously; the remote uses
`detonate(true)` and waits on `requested`/`firing` across frames.

`tools/profile_explosions.gd` runs three fixed-seed horn blasts through the live
remote at 1440×900, with a 100-body cap. Use its `--capture` mode to inspect the
source/debris transition separately from timing; image readback changes frame
costs. Historical optimization measurements and their limits are recorded in
[the performance acceptance report](../performance/threading-acceptance.md).

After integrating Jolt and debris interactions onto PR #7, three native-enabled
Balanced runs on Apple M5 Pro / Forward+ Metal at 1440×900 completed in
307.5 / 291.0 / 281.0 ms, with worst frames 47.2 / 46.0 / 48.3 ms and p95
25.0 / 23.0 / 22.6 ms. This remains close to the preceding 45–47 ms worst-frame
range; it does not reach a steady 16.7 ms frame budget. GPU timings remain
unavailable (the engine reports zero). These are local measurements, not a
cross-platform Jolt speedup claim.

## Debris strikes

Debris carries rock-like mass (about 400 kg/m³ of its bounds, clamped to
0.5–400 kg) and collides with the resident's tumble proxy. A body moving at
4 m/s or faster with a bounding radius of at least 0.25 m knocks a standing
Bigfoot into the same physical tumble a blast does, scaled by its mass, and
loses about half its speed doing so; small dirt and slow slabs pass harmlessly.
Once airborne he keeps colliding with the rockfall through the solver. The same
debris unseats authored props it hits: the prop is promoted to a loose body and
takes the hit, so saving after a slide records where knocked rocks came to rest.
Undo last blast still restores Bigfoot's pre-blast position. Debris that reaches
a pond splashes it once and then wallows under heavy damping instead of skating
across the surface. `tests/test_debris_strikes.gd` (removed) covers these interactions through
the live remote, plus frozen/non-colliding staging, restored collision masks,
mass-independent launch velocity, and exactly-once impulse application.

The integrated branch passes graphical Forward+/Metal suites for debris strikes,
waterfall plunge, native explosives, mountain collapse, internal blast, tunnels,
Bigfoot explosions, creature wind, threaded refresh and lifecycle, world play,
water mischief, and all explosive landscapes. Native explosives also passes with
`--gdscript-kernels` to force the unbuilt-checkout fallback.

## Mountain tunnels

In **Build → Sculpt → Tunnel**, aim at a steep mountainside and click. The bore
runs horizontally into the slope along the camera's viewing direction. Width is
available on the tool card; Adjust also exposes depth. A successful bore retains
the summit above a flat floor, side walls, ceiling, and closed back wall.

1. Click **Plant charge inside** on the Tunnel card, or select **Explosive** and
   click the visible interior floor to choose the position yourself.
2. Click **Seal last tunnel**. The bore fills back in with the original rock skin,
   leaving the explosive at its underground elevation. The remote changes from
   “in tunnel” to “buried.” Deep charges may need a larger blast radius (up to 6 m).
3. Press **X** or use the remote to detonate. **Undo last blast** restores the
   sealed mountain and armed charge. **Reopen last tunnel** exposes it again.

Tunnels have real rendered and physics surfaces, not transparent terrain. Their
records are saved in native format version 10; earlier version 3–9 worlds still
load. Opening, sealing, and charge placement each use normal undo transactions.

This first version supports up to six separate, straight, rectangular bores. The
seal/reopen/quick-charge buttons target the last tunnel. The existing surface
sculpt tools and Bigfoot navigation still follow the upper heightfield. Curved or
intersecting tunnels, arbitrary underground furnishings, and the hinged mountain
cap are future extensions.

`tests/test_native_tunnels.gd` covers the actual pointer tools, retained summit,
portal/back wall, interior floor and ceiling, matching physics collision,
underground charge elevation, sealing, reopening, persistence and malformed-save
rejection, detonation, and exact blast undo. Existing explosives, mountain collapse,
play collision, and incremental terrain-refresh checks also pass.

## Inside-out buried blasts

Charges with substantial rock above them now use a confined rupture instead of
starting with the surface crater/landslide path. Pressure fractures the surrounding
cap, including material removed by the initial blast. Those actual terrain chunks
launch radially away from the buried origin, lifting the roof before gravity brings
them down. The chunk budget reserves coverage around the charge so selecting the
largest pieces cannot reduce the burst to one mountainside. Surface dust marks
breakout points even when the central flash is hidden underground.

Pressure attenuates through thick overburden and with distance. A small deep charge
cannot remove an arbitrarily large mountain. This remains a stylized heightfield
cap-fracture approximation, with instantaneous permanent terrain changes; flying
fragments supply the outward motion. Surface charges retain their original craters
and gravity-driven landslides. The existing fast convex hull generation, body cap,
undo, and save behavior are unchanged.

`tests/test_internal_blast.gd` checks four-sided ejection for a centered charge,
upward/outward velocity, immediate release, inclusion of original blast material,
roof breakthrough, bounded fragments, weak-charge attenuation, and exact undo.
The main-game tunnel test also checks pressure fragments from a sealed tunnel.

### Buried blast power tuning

Confined blasts now have a finite displaced-rock budget proportional to the cube
of the radius, plus a maximum fracture depth per column. Medium charges eject
smaller surface sections and preserve most of the summit. Fragment launch speeds
are lower; increasing radius still increases both reach and breakable volume.
A deeply buried charge too weak to reach the surface stays contained instead of
falling back to the old full-depth crater excavation. The internal-blast tests
cover the rock budget, summit retention, smaller sections, and stronger large
charges, alongside the sealed-tunnel workflow.
