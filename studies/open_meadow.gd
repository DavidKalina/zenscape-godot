extends "res://studies/fidelity_life.gd"
## A separate editable garden: open walking space framed by small woodland
## groups, a shallow pond and flowers. Fidelity's existing garden is untouched.
func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Quiet Meadow"
	_chunk_editor.save_path = "user://quiet-meadow.json"
	_celestial.cycling = false
	_celestial.set_phase(0.48)
	_atmosphere.strength = 0.35
	_atmosphere._air_strength = 0.35
	_auto_orbit = false
	_ui.visible = false
	var panel = _life_status.get_parent()
	panel.scale = Vector2.ONE*0.65
	panel.get_child(panel.get_child_count()-1).visible = false
	var overview := Button.new()
	overview.text = "Whole meadow"
	overview.pressed.connect(_frame_meadow)
	panel.add_child(overview)
	_frame_meadow()

func _frame_meadow() -> void:
	target = Vector3(0,0.8,0)
	distance = 39.0
	yaw = 0.35
	polar = 0.82
	_update_camera()

func _choose_inhabited_shore() -> void:
	var data: NativeTerrainData = _chunk_editor.data
	data.reset_flat()
	for i in range(data.points.size()):
		var p := data.points[i]
		var basin := Vector2((p.x-5.0)/3.5,(p.y+3.0)/2.9).length_squared()
		data.heights[i] = 0.35+0.16*sin(p.x*0.2)+0.12*cos(p.y*0.24)-1.15*exp(-basin*1.1)+1.7*exp(-p.distance_squared_to(Vector2(-8,-9))/38.0)+0.9*exp(-p.distance_squared_to(Vector2(10,8))/30.0)
	data.grass.fill(0.8)
	data.add_pond(Vector2(5,-3),0.12)
	var trees := [Vector2(-10,-9),Vector2(-7.5,-11),Vector2(-4,-10.5),Vector2(0,-11),Vector2(8,-10.5),Vector2(11,-8),Vector2(-11,-3),Vector2(-10,3.5),Vector2(-10,8),Vector2(10,6),Vector2(11,10)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	for i in range(trees.size()):
		for offset in [Vector2.ZERO,Vector2(1.5,-0.6),Vector2(-0.8,1.5)]:
			var kind := "broadleaf" if i%3==0 else "tree"
			data.place(kind,trees[i]+offset,rng.randf()*TAU,rng.randf_range(1.0,1.6),{},NativeObjectPose.encode_tint(Color("78945f").srgb_to_linear()))
		data.place("shrub",trees[i]+Vector2(1.0,0.5),rng.randf()*TAU,0.8)
	for p in [Vector2(-8,-8),Vector2(-5,-10),Vector2(9,-7),Vector2(-10,6),Vector2(10,8)]:
		data.place("boulder_2",p,0.4,0.45)
	for i in range(110):
		var p := Vector2(rng.randf_range(-12,12),rng.randf_range(-12,12))
		if p.length()<5.0 or p.distance_to(Vector2(5,-3))<4.3: continue
		var kind: String = ["grass_tuft","daisy_flower","button_flower","spike_flower"][i%4]
		data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.45,0.8))
	for center in [Vector2(-8,-6),Vector2(-6,7),Vector2(9,7),Vector2(1,-10),Vector2(8,-9)]:
		data.paint_blades(center,2.1,0.35)
		for i in range(24):
			var angle := rng.randf()*TAU
			var p: Vector2 = center+Vector2.from_angle(angle)*rng.randf_range(0.1,1.8)
			data.place("daisy_flower" if i%3 else "button_flower",p,angle,rng.randf_range(0.9,1.4))
	for i in range(11):
		var angle := float(i)/11.0*TAU
		var p := Vector2(5,-3)+Vector2(cos(angle)*3.65,sin(angle)*3.15)
		data.place("reeds",p,angle,0.38)
	data.place("log",Vector2(-7,7),0.75,0.55)
	_chunk_editor.refresh()
	_refresh_habitat()
	creature.reset_at(navigation.nearest_safe(Vector3(-2,0,1)))
	brain.reset_behavior()
	# Replace the source pond's inhabitants with fish in this authored pond.
	for item in fish.population: item.node.free()
	fish.population.clear()
	for p in [Vector2(4,-3),Vector2(6,-3),Vector2(5,-1.7)]:
		fish._add_fish(Vector3(p.x,0.04,p.y))
	data._undo.clear()
	data._redo.clear()
