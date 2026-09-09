extends SceneTree
const Desert = preload("res://scripts/prototype_desert_landscape.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size()>0,"Pass the source fixture JSON path after --")
	var samples: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var maximum := 0.0
	for sample in samples:
		var g := {"seed":int(sample.seed),"composition":sample.kind,"breadth":1.0,"relief":1.0}
		var result := Desert.field(g,Vector2(sample.x,sample.z))
		var error := absf(result.x-float(sample.height))
		maximum = maxf(maximum,error)
		assert(error<0.002,"Source height mismatch: %s / %s / %s" % [sample.kind,sample.seed,error])
		assert(absf(result.z-float(sample.salt))<0.002,"Source salt mask mismatch")
	print("PASS ",samples.size()," original desert samples; max height difference=",maximum)
	quit()
