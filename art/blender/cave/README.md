# Approved cave design

Open `zenscape-cave-study.blend` in Blender. The user approved this visual design. Its clean game export is
`assets/models/zenscape-cave.glb`; placement in the Fidelity world remains separate.

The shape is a broad, faceted rock outcrop with an uneven entrance brow,
embedded shoulder rocks, a continuous floor and a recessed passage bending to
one side. Darkness comes from the enclosed geometry and lighting. The opening
is approximately 3.7 m wide and 3.6 m high; the separate Bigfoot reference is
normalized to 2.8 m tall for this study.

Collections separate editable stone and moss from the display floor, plants,
Bigfoot reference and studio lighting. Select `Entrance - weathered brow and
shoulders` to adjust the mouth; edit `Mass - low asymmetric hillside rock` to
change the silhouette. The interior is a separate mesh for easy access.

`cave-study.png` is the three-quarter preview; `cave-entrance.png` is the front
view. These are Blender studio renders. Terrain blending, game lighting,
collision and Bigfoot behavior are not validated by this study.

The GLB contains only editable cave stone, interior and moss. Its origin is the
entrance floor, in metres, with Godot +Z facing out of the entrance. Studio
scenery, lighting and the reference character are excluded. Re-export with
`blender --background --python tools/export_cave.py`; this reads the approved
source without saving over it. `export-validation.json` records the GLB content
check.

`tools/build_cave_study.py` records construction. It refuses to overwrite an
existing blend unless explicitly passed `--replace-generated`; do not use that
flag after manual edits you want to keep.
