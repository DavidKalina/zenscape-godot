extends RefCounted
## The old glider's figure is gone (round 7 of docs/design/consolidation-
## audit.md): the plane flies, drawn by scripts/plane_figure.gd, and the
## meshes and soft textures it shared moved to scripts/facet_mesh.gd. This
## stub stays only because studies/kit_isle.gd still preloads it for
## `_soft_ring`; point that at FacetMesh.soft_ring and delete this file.

static func _soft_ring() -> Texture2D:
	return preload("res://scripts/facet_mesh.gd").soft_ring()
