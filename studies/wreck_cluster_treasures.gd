extends RefCounted
## The wreck cluster's treasures (docs/design/carry/spec-carry.md): where
## each rests and what it weighs, for scripts/carry/carry_host.gd. Rows:
## [id, model kind (scripts/carry/treasure_models.gd), weight class
## (scripts/carry/carry_weights.gd), foot (world, settled onto what's under
## it), yaw (deg)]. They stand on stone, off the grass carpet (whose tufts
## would bury them). Each is named `wreck_cluster/<id>` for the world view.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const Art = preload("res://studies/wreck_cluster_art.gd")

static func spots() -> Array:
	return [
		# On the spine's south bench, east of the footbridge's top.
		["treasure_01","idol","light",Spine.bench_point(117.0),200.0],
		# In the cella, on its paved floor before the east wall (the grass
		# grows wild at the walls; part spot 01 is by the altar, west of it).
		["treasure_02","urn","medium",Spine.at3(37.6,-0.8,Art.TOP+Spine.PODIUM),210.0],
		# On the knight's snapped causeway, near its tip: carried home past
		# him (part spot 16 is in the lee of the last pier, nearer the tip).
		["treasure_03","egg","heavy",Vector3(Art.CAUSEWAY_TIP+5.0,Art.causeway_top(),Art.STRIP_Z-0.6),90.0],
		# On the tower's lookout, by its root: the top of the climb (part
		# spot 11 is on the east wall's head beside it); a light load sails.
		["treasure_04","chalice","light",Art.lookout_tip()+Vector3(-0.6,0.0,0.0),30.0],
	]
