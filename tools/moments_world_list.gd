extends SceneTree
## Lists the moments set pieces the sky world lays for a seed (scripts/
## sky_world.gd `_moments`, --moments), headless: each one's index (as the
## game's N and --moments-at=N count them), its station, where its entry
## stands (home), its turn and whether it is mirrored, how far it is from
## the plate's first home, and how long the layout took.
##   godot --headless --path . -s tools/moments_world_list.gd [-- --sky-seed=N]
const SkyWorld = preload("res://scripts/sky_world.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")

func _initialize() -> void:
	SkyWorld.moments = true
	var s := SkyWorld.seed_flag()
	SkyWorld.seed = s if s >= 0 else SkyWorld.LEGACY_SEED
	var began := Time.get_ticks_msec()
	var laid := SkyWorld.moment_spots()
	print("Seed %d: %d moments set pieces (layout %d ms, of it the set pieces %.0f ms)" % [SkyWorld.seed,laid.size(),Time.get_ticks_msec()-began,SkyWorld.moments_ms])
	for k in range(laid.size()):
		var p: Dictionary = laid[k]
		print("  %2d  %-15s  entry (%6.0f, %3.0f, %6.0f)  turn %5.1f deg%s  %5.0f m from home" % [k,Plan.footprint(int(p.layout)).name,p.at.x,p.at.y,p.at.z,
			rad_to_deg(float(p.turn)),"  mirrored" if p.mirror else "          ",Vector2(p.box_at.x,p.box_at.z).length()])
	quit()
