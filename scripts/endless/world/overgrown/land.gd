extends RefCounted
## Overgrown's land recipe (scripts/endless/world/profiles/overgrown.gd).
## For now wilderness's land exactly; the land forms round gives it its own.

const Field = preload("res://scripts/endless/land_field.gd")

static func recipe() -> Dictionary:
	var land := Field.recipe_defaults()
	land.merge({"mountains":1.0,"peaks":1.0,"valleys":1.0,"carve":1.0,"carve_blocks":1.0,"carve_ledges":1.0,"carve_gullies":1.0,
		"rivers":1.0,"river_width":1.0,"river_drop":1.0,"river_cut":1.0,"river_fill":1.0,"river_mouth":1.0,"river_flare":1.0,"ponds":1.0})
	return land
