# Blender for ZenScape

Keep editable Blender sources in `art/blender/`. That folder has a `.gdignore`
so Godot imports only the deliberate exports in `assets/models/`.

## First editing session

- Select an object, then press Tab to enter Edit Mode.
- Press 1 on the number row for vertex selection; select a vertex and use G to move it.
- G moves, R rotates, S scales. Follow with X, Y, or Z to constrain an operation.
- Left-click confirms; Esc cancels. Tab returns to Object Mode.
- Middle-drag orbits; Shift-middle-drag pans; scroll zooms.
- Without a middle mouse button, enable Preferences > Input > Emulate 3 Button Mouse.
  Option-left-drag then orbits. These preferences are personal; the project does not change them.
- Without a numpad, use the viewport axis gizmo for front/side/top views.

## Export to Godot

1. Save the `.blend` source.
2. In Object Mode, select the objects belonging to the asset.
3. Apply Rotation & Scale through Object > Apply when appropriate for a static mesh.
   Do this before rigging for animated assets.
4. Choose File > Export > glTF 2.0 and format glTF Binary (`.glb`).
5. Enable Selected Objects, keep the default +Y Up conversion, and export to
   `assets/models/` under the asset's name.
6. Return to Godot and let it reimport. Drag the `.glb` from its FileSystem dock
   into a practice scene. Add gameplay and collision in a Godot wrapper scene.

Use one Blender unit as one meter, with the object's origin at its ground contact.
Blender is Z-up; the glTF exporter handles Godot's Y-up convention.
Use simple Principled BSDF materials for transferable base color and roughness.
Arbitrary Blender shader nodes do not become Godot shaders: bake textures or
recreate specialized effects in Godot. Judge final colors under the game's lighting.

Keep terrain editing and world placement in Godot; use Blender for individual
plants, rocks, landmarks, creatures, rigs, and animation clips.

Reference: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
