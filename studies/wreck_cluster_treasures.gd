extends RefCounted
## The wreck cluster's treasures (docs/design/carry/spec-carry.md): where
## each rests and what it weighs, for scripts/carry/carry_host.gd. Rows:
## [id, model kind (scripts/carry/treasure_models.gd), weight class
## (scripts/carry/carry_weights.gd), foot (world, settled onto what's under
## it), yaw (deg)]. Each is named `wreck_cluster/<id>` for the world view.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")

static func spots() -> Array:
	return [
		# On the spine's south bench, east of the footbridge's top.
		["treasure_01","idol","light",Spine.bench_point(117.0),200.0],
	]
