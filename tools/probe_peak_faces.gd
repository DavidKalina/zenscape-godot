extends SceneTree
## Faces a sky range draws at each stride (scripts/sky_peak.gd `body_arrays`),
## and how long the shape and each stride take. Headless:
##   Godot --headless --path . -s res://tools/probe_peak_faces.gd
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")

func _initialize() -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var grass := [Color("5d9e53"),Color("7fb069")]
	var rock := [Color("8d8577"),Color("6f6a5f")]
	var began := Time.get_ticks_msec()
	var shape: RefCounted = SkyPeak.make(SkyPeaks.seed_of(Vector2i.ZERO),1.0,true)
	print("home range shape %d ms" % (Time.get_ticks_msec()-began))
	for stride in [1,2,3,4,8]:
		began = Time.get_ticks_msec()
		var arrays: Array = shape.body_arrays(grass,rock,Color.GRAY,SkyPeaks.OFF_MAP,stride)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		print("stride %d: %d faces, %d ms" % [stride,verts.size()/3,Time.get_ticks_msec()-began])
	quit(0)
