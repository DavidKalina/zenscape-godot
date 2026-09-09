extends "res://studies/prototype_valley_rock.gd"
## Integration lab. Writes ordinary editable terrain records, not a new save format.
const Genome = preload("res://scripts/prototype_inland_genome.gd")
var genome: Dictionary = {}
var world_seed := 7
var choices: Dictionary = {}
var world_label: Label
var world_ready := false
var choice_controls: Dictionary = {}

func _ready() -> void:
	super._ready()
	mountain_material.shader = preload("res://shaders/prototype_inland_surface.gdshader")
	set_rock_style(0)
	_chunk_editor.content._water_material.shader = preload("res://shaders/prototype_inland_water.gdshader")
	_planar_water.clear()
	_planar_water.revision = -1
	world_ready = true
	_sync_rock_habitat()
	get_window().title = "ZenScape visual lab · Inland genome"

func set_scale_variant(_index: int) -> void:
	genome = Genome.sample(world_seed,choices)
	var data = _chunk_editor.data
	data._recipe = null
	data._restore(baseline)
	data.objects.clear()
	data.ponds.clear()
	data.streams.clear()
	data.blades.fill(0.0)
	data.meadow.fill(0.0)
	data._recipe_settings.biome = genome.habitat
	var water = preload("res://scripts/native_formation_water.gd").new()
	if genome.composition == "valley":
		var anchors: Array = []
		for i in range(45):
			var z := -11.0+i*0.5
			anchors.append([Genome.channel(genome,z),z,1.12+(11.0-z)*0.009])
		water._add(anchors,genome.river_width,false,false)
		data.streams.assign(water.routes.duplicate(true))
	elif genome.composition == "marsh":
		for p in [Vector2(-4,-3),Vector2(3,-2),Vector2(0,5)]:
			data.ponds.append({"x":p.x,"z":p.y,"level":1.45,"basin":[3.4,2.7]})
	elif genome.composition in ["basin","mountain","massif","foothills"]:
		var p := Vector2(0,0) if genome.composition == "basin" else Vector2(2.5,6.0)
		data.ponds.append({"x":p.x,"z":p.y,"level":1.7,"basin":[3.4,2.8]})
	var recipe = preload("res://scripts/prototype_inland_recipe.gd").new(genome,data.ponds,water)
	data._recipe = recipe
	data._recipe_height_cache.clear()
	data._water_grid_h.clear()
	data._recipe_gradients.clear()
	peak = 0.0
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		data.heights[i] = recipe.height(p.x,p.y)
		peak = maxf(peak,data.heights[i])
	data._recipe_heights = data.heights.duplicate()
	for i in range(data._face_x.size()):
		var x: float = data._face_x[i]
		var z: float = data._face_z[i]
		data._recipe_gradients.append(Vector2((recipe.height(x+0.25,z)-recipe.height(x-0.25,z))/0.5,(recipe.height(x,z+0.25)-recipe.height(x,z-0.25))/0.5))
	data.discard_cache()
	# Independent planting stream; habitat changes cannot alter terrain or water.
	var rng := RandomNumberGenerator.new()
	rng.seed = genome.plant_seed
	var budget: int = {"alpine":70,"woodland":115,"meadow":25,"wetland":15,"arid":12,"redwood":70}[genome.habitat]
	budget = int(budget*float(genome.tree_density))
	var planted := 0
	for i in range(1000):
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-10.5,10.5))
		var angle := rng.randf()*TAU
		var size := rng.randf_range(0.6,1.05)
		var pick := rng.randf()
		var h: float = data.ground_height(p)
		if p.distance_to(actor_point)<1.4 or _is_wet(p): continue
		if preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.85: continue
		var treeline := 5.0 if genome.habitat == "alpine" else 9.0
		if h>treeline: continue
		var kind: String = "tree"
		if genome.habitat == "woodland": kind = "broadleaf" if pick<0.6 else "tree"
		elif genome.habitat == "redwood": kind = "redwood"
		elif genome.habitat == "arid": kind = "shrub"
		elif genome.habitat == "wetland": kind = "reeds"
		if data.place(kind,p,angle,size)>=0: planted += 1
		if planted>=budget: break
	# Low cover gives marsh/meadow their own habitat beyond a palette swap.
	for i in range(25 if genome.habitat == "arid" else 150):
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-10.5,10.5))
		if _is_wet(p) or preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.6: continue
		if data.ground_height(p)>5.0: continue
		var kind := "reeds" if genome.habitat == "wetland" else "daisy_flower" if genome.habitat == "meadow" else "shrub" if genome.habitat == "arid" else "grass_tuft"
		data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.5,0.9))
	data.objects_revision += 1
	_chunk_editor.refresh()
	actor.position = Vector3(actor_point.x,float(data.ground_height(actor_point)),actor_point.y)
	_update_world_label()
	if world_ready: _sync_rock_habitat()
	print("INLAND seed=",world_seed," ",genome.composition," / ",genome.landform," / ",genome.habitat)

func _is_wet(p: Vector2) -> bool:
	if genome.composition == "valley" and absf(p.x-Genome.channel(genome,p.y))<genome.river_width*0.6+0.5: return true
	for pool: Dictionary in _chunk_editor.data.ponds:
		if Vector2((p.x-pool.x)/pool.basin[0],(p.y-pool.z)/pool.basin[1]).length()<1.05: return true
	return false

func _sync_rock_habitat() -> void:
	# Dune crests are sand, even when tall. Other terrain retains exposed rock.
	mountain_material.set_shader_parameter("inland_rock_amount",0.0 if genome.composition == "dunes" else 1.0)

func _update_world_label() -> void:
	for key in choice_controls:
		var option: OptionButton = choice_controls[key]
		option.select(0)
		for i in range(1,option.item_count):
			if option.get_item_text(i) == choices.get(key,""): option.select(i)
	if world_label != null: world_label.text = "Seed %d · %s / %s / %s / %s" % [world_seed,genome.composition,genome.archetype,genome.landform,genome.habitat]

func _make_lab_ui() -> void:
	super._make_lab_ui()
	var panel := PanelContainer.new()
	lab_ui.get_child(0).add_child(panel)
	panel.position = Vector2(15,140)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var seed_control := SpinBox.new()
	seed_control.min_value = 0
	seed_control.max_value = 99999
	seed_control.value = world_seed
	seed_control.prefix = "Seed "
	seed_control.value_changed.connect(func(v: float) -> void:
		world_seed = int(v)
		set_scale_variant(0))
	column.add_child(seed_control)
	_choice(column,"composition",Genome.COMPOSITIONS)
	_choice(column,"archetype",Genome.ARCHETYPES)
	_choice(column,"landform",Genome.LANDFORMS)
	_choice(column,"habitat",Genome.HABITATS)
	for entry in [["Relief","relief",0.5,1.6],["Breadth","breadth",0.65,1.25]]:
		var slider := HSlider.new()
		slider.min_value = entry[2]
		slider.max_value = entry[3]
		slider.step = 0.05
		slider.value = 1.0
		var label := Label.new()
		label.text = entry[0]
		column.add_child(label)
		column.add_child(slider)
		slider.drag_ended.connect(func(changed: bool) -> void:
			if changed:
				choices[entry[1]] = slider.value
				set_scale_variant(0))
	world_label = Label.new()
	world_label.add_theme_font_size_override("font_size",12)
	world_label.custom_minimum_size.x = 230
	world_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(world_label)
	var hint := Label.new()
	hint.text = "Auto follows seed; choices override it.\nLandforms apply to compatible compositions.\n1–9 change mood; T changes rock."
	column.add_child(hint)

func _choice(column: VBoxContainer,key: String,values: Array) -> void:
	var option := OptionButton.new()
	choice_controls[key] = option
	option.add_item(key.capitalize()+": Auto")
	for value in values: option.add_item(value)
	option.item_selected.connect(func(index: int) -> void:
		if index == 0: choices.erase(key)
		else: choices[key] = values[index-1]
		set_scale_variant(0))
	column.add_child(option)
