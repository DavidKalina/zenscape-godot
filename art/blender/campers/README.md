# Camper art studies — v01

Open `zenscape-campers-v01.blend` for the editable tent and two camper concepts.
`campers-v01.png` shows the set; `campers-detail-v01.png` shows faces and gear.
`current-bigfoot-comparison-v01.png` compares them with the editor's actual
`zenscape-bigfoot-breathing.glb` under the same studio lighting, at asset scale.
The bear is not an art reference. Runtime lighting and final relative scale still need review.

- Field photographer: tall silhouette, brimmed hat, muted teal shirt, camera and satchel; about 2 m including hat.
- Trail backpacker: shorter, broader silhouette, rust cap and shirt, teal pack and rolled sleeping pad; about 1.76 m including cap.
- Ochre ridge tent: 2.24 m wide, 2.30 m deep, 1.53 m tall, with open folded flaps, poles, stakes, ropes, groundsheet and sleeping mat. Ropes extend beyond the footprint.

Each subject has its own EDIT collection. Parts, materials and meshes are editable.
The studio is excluded from the three GLB exports under `assets/models/`:
`zenscape-camper-photographer-v01.glb`, `zenscape-camper-backpacker-v01.glb`,
and `zenscape-tent-ochre-v01.glb`.
Exports are centered at ground level, with Blender -Y forward / Godot +Z forward.
The Blender review layout offsets subjects for presentation; exports retain local origins.

These are static design studies. They do not yet have rigs, animations, collision,
cloth behavior, or connections to the campsite simulation. Face proportions,
headwear and gear are intentionally easy to revise before rigging.

`tools/build_camper_studies.py` builds and renders the first pass and refuses to
replace the Blender file. Preserve manual edits; create a new version for changes.
`tools/review_camper_studies.py` renders the current Bigfoot comparison and
reimports all three exports to check triangles, material presence and bounds.
The two validation JSON files record source counts and actual exported counts.

Worktree: `codex/camper-models`, created from main at `b93160a`.
The older `codex/campsite-experiment` and all of its uncommitted work are preserved.
No gameplay code was changed or ported for this art pass.

## Runtime prototype

The art is now used by `run-campsite.command` in this worktree. Runtime rigid-part
posing lives in `scripts/camper_visual.gd`; the Blender sources remain static and
editable. See `docs/campsite-life/README.md` for the interaction loop and limits.
