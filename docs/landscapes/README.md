# Curated landscapes

Open **Landscapes** in the diorama toolbar, or search **Landscapes** in Build.
Choose a card to form its complete ground, planting and water. It replaces the
current terrain and its objects; **Undo terrain** restores the whole previous
landscape, and **Redo** brings the new one back. Colors and atmosphere are kept.

| Preset | Formation | Suggested biome |
| --- | --- | --- |
| Riverfold valley | Broad slopes and a winding river floor | Wildflower meadow |
| Skywater plateau | Steep tableland with a summit lake | Woodland |
| Sleeping volcano | Wide conical skirts and a snowy crown | Alpine |
| Emerald ridgeback | Long, rounded ridge above a sheltered pool | Woodland |
| Silverhorn tarn | Sharp pyramidal peak and a foothill tarn | Alpine |
| Sunstone canyon | Buttressed cliffs enclosing a river | Dry highlands |
| Jade terraces | Three shelves, each retaining its own pool | Lush wetland |

The **Biome** picker works with every family. Alpine, Woodland, Wildflower
meadow, Dry highlands and Lush wetland control tree species and distribution,
ground cover, rock exposure and the elevation at which snow appears. This
changes structural character, without changing the selected color palette.

Changing biome preserves sculpted heights, water, surface paint and hand-placed
objects. It replaces the preset's generated planting and ground cover. Deleting
or moving individual generated plants remains possible with the normal tools;
changing biome regenerates that planting. Biome edits use the same terrain undo
history as sculpting and placement.

**Swap palette…** opens the Landscape color tab. You can also use any of the
complete Looks (including Halloween Hollow); they change colors, lighting and
weather without regenerating the ground. Color edits have their own undo history.

Previews are real Godot renders with suggested looks. They show the composition;
your current colors and weather determine its appearance when you apply it.
All recipes, biome choices, sculpting, plants and water persist in normal diorama
JSON saves. Existing mountain-range and foundation saves remain supported.

## Implementation and checks

- `native_formation_shape.gd`: continuous silhouettes and closed water bowls,
  inspired by the original ZenScape `landforms.js`, `genome.js` and `world.js`.
  Valley/canyon walls rise outside the river floor, cone and horn have different
  flank profiles, and ridgeback height varies along a rounded spine.
- `native_landscape_presets.gd`: complete compositions and deterministic biome
  planting using ordinary garden objects, ponds, streams and ground-cover cells.
- `native_terrain_recipe.gd`: validated formation records and exact JSON encoding.
- `landscape_preset_editor.gd`: visual family gallery and independent biome control.
- `tests/test_landscape_presets.gd`: all families, all 35 family/biome pairings,
  contained water, live formation locking/yielding, save roundtrips, undo/redo,
  preservation of sculpting and user objects, palette independence and small UI.
- `tools/capture_landscape_presets.gd`: generates full renders here and 480×320
  gallery assets in `assets/landscapes`. `--preset=<family>` captures one;
  `--ui-only` captures the gallery after importing the thumbnail assets.

## Connected water and variations

The **Water** picker offers **Connected flow** and **Quiet pools**. Connected
flow carves descending courses: a river and side spring in valleys and canyons,
summit spill on plateaus, snowmelt courses on alpine slopes, and two cascades
linking the three terrace pools. Steep sections have animated, aerated water.
Quiet pools retains the lakes without the connecting courses.

Changing water treatment reforms the landscape. **Another like this** also
reforms it, advancing a saved deterministic variation while keeping the family,
biome, water treatment and palette. Both operations replace manual terrain and
object edits, and each can be undone in one step. Reusing a variation reproduces
its composition. Normal biome changes still preserve manual terrain edits.

The generated pools and streams remain ordinary editable water records.
Sculpting an obstruction hides affected cascade geometry; Undo restores it.
These are authored descending watercourses, not a fluid simulation.

## Favorites

Open **Landscapes → Favorites**, enter a name and choose **Save to Favorites**.
Each entry stores the edited landscape, scene look, weather, camera and a clean
thumbnail in `user://landscape-favorites`. **Restore** loads that discovery;
**Undo restore** and **Redo** restore both terrain and scene settings. Ordinary
terrain undo continues to leave the palette alone. Favorites survive restarting
the app and are separate from normal diorama saves.

**Remove** moves the entry into the library's `.removed` directory. Invalid or
incomplete entries cannot overwrite the current scene.

See [verification](verification.md), [Favorites](favorites.png), and the
[water motion comparison](connected-water-comparison.mp4) (animated left,
frozen right).
