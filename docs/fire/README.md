# Fire

Run `./run-diorama.command`. Fire is part of the shared world, not a mode: it starts from lightning, from an explosion, or from an ember you drop yourself, and then it belongs to the weather and the wind like everything else.

A storm is the usual way in. Most strikes land in rain and hiss out, because rain, wet ground and snow smother ignition outright; a strike on dry grass catches, and the front starts walking downwind. Wind decides the shape of it — a front runs roughly four times faster downwind than upwind, and in a strong wind a burning cell can throw an ember three to eight cells ahead and start a second fire across a gap. Ponds, streams and the sea are inert: the simulation reads the same surface map the rain and fog read, and a cell whose water stands above its ground never burns.

What burns depends on what is standing there. Grass, flowers, ferns and reeds go in about four seconds and leave ash. Shrubs and cacti take twelve. Trees burn for forty seconds, take their neighbours with them canopy to canopy, and are left as snags with the same pose and scale they had. Logs, stumps and snags char and stay. Rock, arches and waterfalls do nothing at all. An explosive charge caught by fire cooks off after half a second and detonates through the ordinary remote path, crater, debris and all — so a fire running into a minefield is a chain of blasts, and each blast leaves more fire behind it.

Ash is temporary. Once the neighbourhood is cold, cover grows back and the scorch fades over about four minutes, ending on exactly the values the cell had before it burned.

## Starting one yourself

- **Ember**: press Cmd/Ctrl K and search for *Ember*, or take it from the Weather group in the build palette. It is a special like Fireflies and the Fog bank: it leaves no record behind, it simply drops a live coal where you click. Wet ground and snow smother it, so it is a real test of how dry the meadow is.
- **Explosives**: every detonation ignites its own crater rim. The crater itself has no cover left to burn, so the fire starts in the ring of grass just outside it.
- **Lightning**: press L in the study scene, or wait out a storm in the diorama.

## Undo and saving

One fire is one undo step, exactly like one salvo of charges. The bracket opens when the first cell catches and closes when the last one dies, so a single Undo puts back the cover, the tint and the tree records the fire swapped for snags — and puts the simulation itself back to cold, since a half-burnt field restored under a running fire would be neither state. A detonation during a fire folds into that same step, and fire started by a blast belongs to that blast. Ordinary terrain edits close the current fire step first; subsequent burning opens a new step so Undo never skips across a user edit. Redo restores the corresponding simulation state, including pre-existing char and recovering ash.

Fire is saved as an optional `"fire"` sub-document inside the garden's scene state, and it is sparse: only cells the fire has touched, the values they had before they burned, the objects currently alight, and settled partial char. A garden that has never burned writes nothing, and a garden saved before fire existed loads unchanged.

## Implementation

`scripts/fire_field.gd` (`FireField`) is the simulation and the whole contract. It is a plain object owned by `studies/fidelity.gd`, created once the chunk editor's `NativeTerrainData` exists and advanced from `_process` immediately after `_lightning.advance`, so a strike is consumed on the frame it lands. It freezes on pause and while an edit, blast worker, or refresh owns the terrain, and still republishes its appearance. A short refresh delay is caught up after publication.

Wiring lives in `studies/fidelity.gd::_setup_fire`. The field's three samplers are injected rather than looked up: wind comes from `_resident_wind.field.sample` when the product subclass provides it and falls back to the scene's prevailing air angle and strength otherwise; weather comes from `_precipitation.surface_weather.ground_wet` / `snow_cover` and `_precipitation.state.x`; water comes from the editor's own copy of the surface map image, where alpha above green means standing water. The water mask is read on rebuild, never per tick, and the cached image is refreshed at most every two seconds.

`_advance_fire` publishes `total_intensity()` to the `zs_fire` global shader parameter every frame (registered in `project.godot` and declared in `shaders/reference_globals.gdshaderinc`) and keeps the same number in `scene._fire_intensity`, because `global_shader_parameter_get` is editor-only. The burnt look (`scripts/fire_look.gd`) and the flames (`scripts/fire_effects.gd`) are separate sub-projects, loaded through a guarded `ResourceLoader.exists` + `load()` and called duck-typed, so a build without them still simulates, saves and undoes fire correctly.

The field writes cover and tint straight into the terrain data on its 8 Hz tick. Only a `refresh()` turns those into mesh colours and flora batches, so a burning world refreshes twice a second from `_refresh_fire_ground`; the editor's incremental mesh path already spots a repainted cell, so no cache is discarded and only the changed region is rebuilt.

`scripts/native_explosives.gd` ignites at the end of `detonate` and exposes `ignite_charge(id)`, which `FireField.explosive_triggered` calls; queued charges cook off one live transaction at a time through the same worker preparation and staged publication as the remote, so undo, debris and collision behave exactly as they do for a hand-fired salvo. One deviation from the design: `carve_native` zeroes cover inside the blast radius, so the crater has no fuel of its own and only the ring outside it can catch. The design's `radius * 1.2` at strength 1.0 puts that ring below the ignition threshold; `radius * 1.6` at strength 1.5 lays a cell-wide band of grass over it.

`scripts/native_build_palette.gd` adds `ember` beside `fireflies` and `fog_bank` as a Weather special with a drawn flame glyph, routed through `_take_special` / `_place_special`; dropping it calls `ignite(point, 0.6, 1.0)` and records nothing. `scripts/native_chunk_editor.gd` carries its hint text and closes active fire before stepping history. `NativeTerrainData` captures an optional fire companion state for history only; worker snapshots remain terrain-only. Restoring terrain resets the field to that companion state, never replays the previous world’s saved cover onto newly loaded terrain. Fire reset also clears pending cook-offs, render caches, and transient effects. `scripts/native_garden_store.gd` carries the optional sub-document through `document()` / `valid()` / `restore()`, following the `world_visuals` pattern.

`FireField.object_char` owns settled charring; `FireLook` publishes it without maintaining a second simulation. The optional `charred` save array preserves partial char after rain. Batch and landmark publication refresh physical-play source references immediately; promoted objects keep their bodies and their replacement authored copies stay hidden. Authored batches explicitly opt into custom fire channels, leaving bird flap/phase data alone. Physical props and blast debris receive the same char/heat through owned material uniforms.

## Verification

See [integration validation](integration-validation.md) for the current main integration, regression coverage, and native/fallback frame timings.

Run with the local Godot binary from this worktree.

Simulation, headless:

- `"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_fire_field.gd`
  — spread and wind bias against the measured targets, suppression and the hard wet/snow stalls, object burn durations and the snag swap, seeded ember spotting, regrowth back to bit-exact cover and tint, the sparse save document, pause, and the undo bracket. 0 failures.

Integration, with a renderer (the fidelity scene hangs headless):

- `"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script res://tests/test_fire_integration.gd`
  — a manual lightning strike on dry ground starting a fire and raising `zs_fire`, the same strike under rain doing nothing, a detonation setting the meadow alight, an explosive standing in a fire cooking off, the fire's undo step restoring cover, tint and the pre-swap tree record exactly, the ember tool dropping a live coal without leaving a record, an active fire round-tripping through save and reopen, and a save with no `"fire"` key still loading. 30 checks, 0 failures.

Regressions run alongside, all with a renderer, all 0 failures:

- `"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script res://tests/test_native_explosives.gd`
- `"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script res://tests/test_command_palette.gd` (removed)
- `"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . --rendering-method forward_plus --script res://tests/test_diorama_flow.gd` (removed)

Additional transaction and physical-appearance regressions are in `tests/test_fire_transactions.gd` and `tests/test_fire_visual_state.gd` (removed). `tools/profile_fire.gd` measures idle and active fire at Balanced 1440×900 (launch with `--windowed --resolution 1440x900`), with optional `--gdscript-kernels` for the fallback; it performs no image readback during timing.

The other sub-projects carry their own checks: `tests/test_fire_look.gd` for per-instance char and the burnt shader path, `tests/test_fire_effects.gd` for flames, smoke, embers and lights, and `tests/test_bigfoot_fire.gd` for the flee, watch and warm-hands behaviour.

## The A/B film

`tools/film_fire.gd` films the same twenty seconds twice in one process — same world, same camera, same weather, same fixed 1/30 s step, same seeds. The left pass takes the lightning strike but has its `struck` connection cut, so `ignite` is never called; the right pass lets the strike catch dry grass upwind of a stand of trees so the front runs into them.

```
"$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
  --rendering-method forward_plus --script res://tools/film_fire.gd

ffmpeg -y -framerate 30 -i /private/tmp/fire-film/left/%04d.jpg \
       -framerate 30 -i /private/tmp/fire-film/right/%04d.jpg \
       -filter_complex "[0:v]scale=900:560,setsar=1[l];[1:v]scale=900:560,setsar=1[r];[l][r]hstack=inputs=2,fps=30" \
       -c:v libx264 -preset slow -pix_fmt yuv420p -crf 26 docs/fire/ab-fire.mp4

for f in 0015 0240 0570; do
  ffmpeg -y -i /private/tmp/fire-film/left/$f.jpg -i /private/tmp/fire-film/right/$f.jpg \
         -filter_complex "[0:v]scale=900:560[l];[1:v]scale=900:560[r];[l][r]hstack=inputs=2" \
         -q:v 3 docs/fire/ab-fire-$f.jpg
done
```

`docs/fire/ab-fire.mp4` plus stills at frames 15 (the strike), 240 (the front mid-run) and 570 (the aftermath). Recorded before the look and effects sub-projects merged, so the right strip shows the fire only through the ground — cover burning away and the tint going to ash, a scar that ends up covering most of the hill. Flames, smoke, embers, charring canopies and snag silhouettes arrive with those merges; re-run the commands above afterwards for the full picture.

## Limits

Fire on Bigfoot's coat, smoke tinting the sky and fog, a campfire object, a water bucket, and autumn burning hotter are all out of scope for this pass. A large fire refreshes the terrain twice a second while it runs, which rebuilds the flora batches for the changed region; that is the one ongoing cost fire adds to a frame. Undo history is session-local, like every other editor operation.
