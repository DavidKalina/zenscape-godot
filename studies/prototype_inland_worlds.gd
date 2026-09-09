extends "res://studies/prototype_valley_rock.gd"
## Integration lab. Writes ordinary editable terrain records, not a new save format.
const Desert = preload("res://scripts/prototype_desert_landscape.gd")
var desert_map: ImageTexture
var desert_details: Node3D
const Genome = preload("res://scripts/prototype_inland_genome.gd")
var genome: Dictionary = {}
var world_seed := 7
var choices: Dictionary = {}
var world_label: Label
var world_ready := false
var choice_controls: Dictionary = {}

func _ready() -> void:
	if "--desert" in OS.get_cmdline_user_args(): choices = {"composition":"salt-basin"}
	super._ready()
	mountain_material.shader = preload("res://shaders/prototype_inland_surface.gdshader")
	set_rock_style(0)
	_chunk_editor.content._water_material.shader = preload("res://shaders/prototype_inland_water.gdshader")
	_planar_water.clear()
	_planar_water.revision = -1
	world_ready = true
	_sync_rock_habitat()
	if genome.composition in Desert.KINDS: set_scale_variant(0)
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
	elif genome.composition == "salt-basin":
		var level := 0.8+0.99*0.65*float(genome.relief)
		for z in range(-10,12,2):
			for x in range(-10,12,2):
				var f := Desert.field(genome,Vector2(x,z))
				if f.z>0.85 and f.x<level:
					data.ponds.append({"x":float(x),"z":float(z),"level":level})
	elif genome.composition == "marsh":
		for pool in genome.wetland:
			data.ponds.append({"x":pool.x,"z":pool.z,"level":pool.level})
	elif genome.composition in ["basin","mountain","massif","foothills"]:
		var p := Vector2(0,0) if genome.composition == "basin" else Vector2(2.5,6.0)
		var radius: float = genome.lake.radius if genome.composition == "basin" else 3.4
		if genome.composition == "basin": p = Vector2(genome.lake.x,genome.lake.z)
		data.ponds.append({"x":p.x,"z":p.y,"level":1.7,"basin":[radius,radius*float(genome.lake.stretch)]})
	var recipe = preload("res://scripts/prototype_inland_recipe.gd").new(genome,data.ponds,water)
	# Local headwater and tributary courses use the same monotone level plan as the original formation water.
	if genome.composition in ["mountain","massif"] and not data.ponds.is_empty():
		var pool: Dictionary = data.ponds[0]
		var start := Vector2(-0.5,-2.0)
		var end := Vector2(pool.x,pool.z)
		var level: float = maxf(pool.level,recipe.height(start.x,start.y)+0.06)
		var anchors: Array = []
		for i in range(17):
			var t := float(i)/16.0
			var point := start.lerp(end,t)+Vector2(sin(t*PI)*0.7,0.0)
			level = maxf(pool.level,minf(level,recipe.height(point.x,point.y)+0.06))
			anchors.append([point.x,point.y,level])
		anchors[-1][2] = pool.level
		water._add(anchors,0.85,true,false)
	elif genome.composition == "valley":
		var z := -5.5
		var receiving := 1.12+(11.0-z)*0.009
		var x: float = Genome.channel(genome,z)
		var head := Vector2(x-4.5,z-2.0)
		var level := maxf(receiving+0.6,recipe.height(head.x,head.y)+0.06)
		water._add([[head.x,head.y,level],[x-2.0,z-0.7,receiving+0.25],[x,z,receiving]],0.65,true,false)
	data.streams.assign(water.routes.duplicate(true))
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
	if genome.composition in ["marsh","salt-basin"]:
		# Flood each connected component once: joined pools must not draw coplanar water twice.
		var masks: Array = []
		var unique: Array[Dictionary] = []
		for pond in data.ponds:
			var field: Dictionary = NativeRecipeWater.field(data,pond)
			if field.is_empty(): continue
			var duplicate := false
			for mask in masks:
				if mask == field.wet: duplicate = true; break
			if not duplicate:
				masks.append(field.wet)
				unique.append(pond)
		data.ponds = unique

	# Independent planting stream; habitat changes cannot alter terrain or water.
	var rng := RandomNumberGenerator.new()
	rng.seed = genome.plant_seed
	var budget: int = {"alpine":int(genome.tree_count),"woodland":int(genome.tree_count)+int(genome.broadleaf_count),"meadow":0 if genome.composition == "meadow" else 15,"wetland":0,"arid":12,"redwood":70}[genome.habitat]
	budget = int(budget*float(genome.tree_density))
	var planted := 0
	var occupied: Array[Vector2] = []
	var habitat_noise := FastNoiseLite.new()
	habitat_noise.seed = genome.plant_seed
	habitat_noise.frequency = 0.22
	for i in range(1600 if budget>0 else 0):
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-10.5,10.5))
		var angle := rng.randf()*TAU
		var size := rng.randf_range(0.6,1.05)
		var pick := rng.randf()
		var h: float = data.ground_height(p)
		if p.distance_to(actor_point)<1.4 or _is_wet(p) or _is_salt(p): continue
		if preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.85: continue
		var treeline := float(genome.treeline) if genome.habitat == "alpine" else 10.0
		if h>treeline: continue
		if habitat_noise.get_noise_2d(p.x,p.y)<-0.15: continue
		var crowded := false
		for other in occupied:
			if other.distance_squared_to(p)<1.2: crowded = true; break
		if crowded: continue
		var kind: String = "tree"
		if genome.habitat == "woodland": kind = "broadleaf" if pick<0.6 else "tree"
		elif genome.habitat == "redwood": kind = "redwood"
		elif genome.habitat == "arid": kind = "shrub"
		elif genome.habitat == "wetland": kind = "reeds"
		if data.place(kind,p,angle,size)>=0:
			planted += 1
			occupied.append(p)
		if planted>=budget: break
	# Low cover gives marsh/meadow their own habitat beyond a palette swap.
	for i in range(25 if genome.habitat == "arid" else 620 if genome.habitat == "wetland" else 250):
		var p := Vector2(rng.randf_range(-11,11),rng.randf_range(-10.5,10.5))
		if _is_salt(p): continue
		if (_is_wet(p) and not (genome.habitat == "wetland" and float(data.ground_height(p))>1.30)) or preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.6: continue
		if data.ground_height(p)>5.0: continue
		var kind: String = "reeds" if genome.habitat == "wetland" else ["daisy_flower","button_flower","spike_flower","grass_tuft"][i%4] if genome.habitat == "meadow" else "shrub" if genome.habitat == "arid" else "grass_tuft"
		if genome.habitat in ["woodland","redwood"]:
			if i%29 == 0: kind = "log"
			elif i%31 == 0: kind = "stump"
			elif i%37 == 0: kind = "snag"
			elif i%11 == 0: kind = "fern"
			elif i%13 == 0: kind = "mushroom"
		if genome.habitat == "wetland" and float(data.ground_height(p))>1.65: kind = "bank_grass"
		data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.5,0.9))
	_build_desert_map()
	data.objects_revision += 1
	_chunk_editor.refresh()
	actor.position = Vector3(actor_point.x,float(data.ground_height(actor_point)),actor_point.y)
	_update_world_label()
	if world_ready: _sync_rock_habitat()
	if desert_details != null:
		desert_details.free()
		desert_details = null
	if genome.composition in Desert.KINDS and world_ready:
		desert_details = preload("res://scripts/prototype_desert_details.gd").new()
		add_child(desert_details)
		desert_details.build(genome,recipe,mountain_material)
	print("INLAND seed=",world_seed," ",genome.composition," / ",genome.landform," / ",genome.habitat)

func _is_wet(p: Vector2) -> bool:
	for route in _chunk_editor.data.streams:
		for point in route.pts:
			if p.distance_squared_to(Vector2(point.x,point.z))<pow(float(route.width)*0.6+0.4,2.0): return true
	for pool: Dictionary in _chunk_editor.data.ponds:
		if genome.composition in ["marsh","salt-basin"]:
			if float(_chunk_editor.data.ground_height(p))<float(pool.level)+0.08: return true
		elif Vector2((p.x-pool.x)/pool.basin[0],(p.y-pool.z)/pool.basin[1]).length()<1.05: return true
	return false

func _is_salt(p: Vector2) -> bool:
	return genome.composition == "salt-basin" and Desert.field(genome,p).z>0.25

func _build_desert_map() -> void:
	if genome.composition not in Desert.KINDS:
		desert_map = null
		return
	var image := Image.create(192,192,false,Image.FORMAT_RGBA8)
	for z in range(192):
		for x in range(192):
			var p := Vector2(-14.0+(x+0.5)*28.0/192.0,-14.0+(z+0.5)*28.0/192.0)
			var f := Desert.field(genome,p)
			image.set_pixel(x,z,Color(f.y,f.z,0,1))
	desert_map = ImageTexture.create_from_image(image)

func _sync_rock_habitat() -> void:
	mountain_material.set_shader_parameter("desert_enabled",genome.composition in Desert.KINDS or genome.habitat=="arid")
	mountain_material.set_shader_parameter("desert_has_map",desert_map!=null)
	mountain_material.set_shader_parameter("desert_geology",desert_map)
	mountain_material.set_shader_parameter("desert_band_height",0.85*float(genome.relief)*(0.65 if genome.composition in ["monuments","salt-basin","desert-mountains"] else 1.0))
	_chunk_editor.content._water_material.set_shader_parameter("salt_pool",genome.composition=="salt-basin")
	# Dune crests are sand, even when tall. Other terrain retains exposed rock.
	mountain_material.set_shader_parameter("inland_rock_amount",0.0 if genome.composition == "dunes" else 1.0)
	var snowline: float = genome.snowline*float(genome.relief) if genome.habitat == "alpine" else 99.0
	if genome.landform in ["tall-massif","volcanic-crown"] and genome.habitat == "alpine": snowline = peak*0.68
	mountain_material.set_shader_parameter("inland_snowline",snowline)

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
