extends "res://studies/prototype_mountain_clouds.gd"
## Disposable Nahanni-inspired compositions, not a geographic reconstruction.
const VALLEYS := ["1 · Open valley", "2 · Limestone canyon", "3 · Valley into gorge"]
var valley_width := 10.0
var valley_mist: FogVolume

func _ready() -> void:
	mountain_height = 16.0
	cloud_altitude = 9.0
	actor_point = Vector2(4.0,8.5)
	super._ready()
	get_window().title = "ZenScape visual lab · Nahanni-inspired valleys"

func river_x(z: float) -> float:
	return 1.35*sin(z*0.23)+0.45*sin(z*0.48+0.6)

func set_scale_variant(index: int) -> void:
	variant = posmod(index,3)
	var data = _chunk_editor.data
	data._restore(baseline)
	data.objects.clear()
	data.ponds.clear()
	data.streams.clear()
	data.blades.fill(0.0)
	data.meadow.fill(0.0)
	var water = preload("res://scripts/native_formation_water.gd").new()
	var anchors: Array = []
	for i in range(49):
		var z := -12.0+i*0.5
		anchors.append([river_x(z),z,0.95+(12.0-z)*0.012])
	water._add(anchors,2.1,false,false)
	data.streams.assign(water.routes.duplicate(true))
	peak = 0.0
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		var across := absf(p.x-river_x(p.y)*0.65)
		var half := valley_width*0.5
		if variant == 1: half *= 0.55
		if variant == 2: half *= lerpf(0.42,1.25,smoothstep(-7.0,6.0,p.y))
		var rise := smoothstep(half,half+(2.2 if variant == 1 else 4.1),across)
		var crest := 0.70+0.17*sin(p.y*0.47+p.x*0.22)+0.10*sin(p.y*0.93-p.x*0.36)
		var h := 1.55+(12.0-p.y)*0.012+rise*mountain_height*crest
		# Broad shoulders and irregular summits, with an open river entrance.
		h = lerpf(1.3,h,1.0-smoothstep(9.8,13.2,p.y))
		h = water.carve(p.x,p.y,h)
		data.heights[i] = h
		peak = maxf(peak,h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 741
	for i in range(500):
		var p := Vector2(rng.randf_range(-11.3,11.3),rng.randf_range(-11.3,10.5))
		if absf(p.x-river_x(p.y))<1.8 or p.distance_to(actor_point)<1.5: continue
		var h: float = data.ground_height(p)
		var slope: float = preload("res://scripts/native_landscape_presets.gd")._slope(data,p)
		if slope>0.85 or h>6.0: continue
		data.place("tree",p,rng.randf()*TAU,rng.randf_range(0.55,0.95))
	data.objects_revision += 1
	_chunk_editor.refresh()
	actor.position = Vector3(actor_point.x,float(data.ground_height(actor_point)),actor_point.y)
	mountain_material.set_shader_parameter("study_snowline",60.0)
	_update_stats()
	if _display_fog != null: _display_fog.forget()
	print("VALLEY ",variant," width=",valley_width," wall=",mountain_height," peak=",peak)

func _make_clouds() -> void:
	super._make_clouds()
	valley_mist = FogVolume.new()
	valley_mist.name = "RiverMist"
	valley_mist.size = Vector3(15,3,27)
	valley_mist.position = Vector3(0,2.5,0)
	var mist := cloud_material.duplicate() as ShaderMaterial
	mist.set_shader_parameter("cloud_density",0.10)
	valley_mist.material = mist
	add_child(valley_mist)

func _sync_clouds() -> void:
	super._sync_clouds()
	if valley_mist != null:
		valley_mist.visible = clouds_enabled
		valley_mist.material.set_shader_parameter("cloud_time",cloud_clock)

func reset_lab_camera() -> void:
	target = Vector3(0,7.0,0)
	distance = 69.0
	yaw = 0.30
	polar = 0.93
	_auto_orbit = false
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _update_stats() -> void:
	if stats != null: stats.text = "%s · Floor width %.1f · Wall height %.0f · Clouds %.1f" % [VALLEYS[variant],valley_width,mountain_height,cloud_altitude]

func _make_lab_ui() -> void:
	super._make_lab_ui()
	var panel: PanelContainer = lab_ui.get_child(0).get_child(0)
	var column: VBoxContainer = panel.get_child(0)
	var row: HBoxContainer = column.get_child(0)
	for i in range(3): row.get_child(i).text = VALLEYS[i]
	var widths := HBoxContainer.new()
	widths.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(widths)
	column.move_child(widths,1)
	for entry in [["Narrow floor",5.0],["Broad floor",10.0],["Wide floor",13.0]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func() -> void:
			valley_width = entry[1]
			set_scale_variant(variant))
		widths.add_child(button)
	panel.offset_top = -185
