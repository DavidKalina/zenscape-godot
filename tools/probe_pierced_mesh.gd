extends SceneTree
## Probe: the pierced isle's body mesh (scripts/pierced_mesh.gd) for a few
## seeds, near and far: samples, faces, time.
##   godot --headless --path . --script tools/probe_pierced_mesh.gd -- [--seeds=1-3]
const PiercedIsle = preload("res://scripts/pierced_isle.gd")
const PiercedMesh = preload("res://scripts/pierced_mesh.gd")

func _initialize() -> void:
	var lo := 1
	var hi := 3
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			var parts := a.trim_prefix("--seeds=").split("-")
			lo = int(parts[0])
			hi = int(parts[1]) if parts.size() > 1 else lo
	for s in range(lo,hi+1):
		var t := Time.get_ticks_usec()
		var plan: RefCounted = PiercedIsle.make(s)
		var plan_ms := (Time.get_ticks_usec()-t)/1000.0
		var near := {}
		var far := {}
		PiercedMesh.arrays(plan,PiercedMesh.CELL,near)
		PiercedMesh.arrays(plan,PiercedMesh.FAR_CELL,far)
		print("seed %d draw %d: plan %.0f ms; near %d faces, %d samples, %.0f ms; far %d faces, %.0f ms" % [s,plan.draw,plan_ms,near.faces,near.samples,near.usec/1000.0,far.faces,far.usec/1000.0])
	quit()
