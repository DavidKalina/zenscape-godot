extends Node3D
## Collectible gallery: the HUD glyphs as 3D tokens (scripts/glyph_token.gd)
## hanging in an open sky, for judging their look before they go into the
## world. One token turns in the middle; the rest ring round it.
##   Drag            orbit          Wheel   zoom
##   Left / Right    next glyph     Space   collect it (the pickup)
##   Tab             ring view      F       freeze the turning
##   L               line: walk through a row of them, picking each up
##   ./run-collectibles.command [--glyph=sun] [--ring] [--line]
##   godot --path . res://studies/collectible_gallery.tscn -- --capture=out.png
## --capture=<png> waits a moment, saves the view and quits;
## --collect-frames=<dir> plays the pickup and saves a frame every 0.1 s.
const GlyphToken = preload("res://scripts/glyph_token.gd")
const HudIcons = preload("res://scripts/hud_icons.gd")
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")

## The glyphs on show, the hero's first.
const IDS := ["sun","moon","crystal","feather","snow","wildflower","oak","dandelion","sunflower","rainbow","island","mountain","deer","heron","lamp","can"]
const HERO_SIZE := 2.0
const RING_SIZE := 1.1
const RING_RADIUS := 7.0
## The line: how many tokens, how far apart (m), how big, and the walk (m/s).
const LINE_COUNT := 12
const LINE_STEP := 1.5
const LINE_SIZE := 0.9
const WALK := 4.0

var _hero_index := 0
var _hero: Node3D
var _ring: Array[Node3D] = []
var _yaw := 0.5
var _pitch := 0.12
var _distance := 5.5
var _ring_view := false
var _frozen := false
var _collecting := false
var _camera: Camera3D
var _label: Label
var _capture := ""
var _collect_frames := ""
var _line_mode := false
var _line: Array[Node3D] = []
var _walker := 0.0

func _ready() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--glyph="): _hero_index = maxi(0,IDS.find(arg.get_slice("=",1)))
		elif arg == "--ring": _ring_view = true
		elif arg == "--line": _line_mode = true
		elif arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
		elif arg.begins_with("--collect-frames="): _collect_frames = arg.get_slice("=",1)
	_build_world()
	for i in range(IDS.size()):
		var holder := _holder(IDS[i],RING_SIZE)
		var a := TAU*i/IDS.size()
		holder.position = Vector3(cos(a),0.0,sin(a))*RING_RADIUS+Vector3(0.0,-0.4,0.0)
		holder.phase = a
		add_child(holder)
		_ring.append(holder)
	_show_hero()
	if _line_mode: _start_line()
	if not _capture.is_empty():
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture)
		get_tree().quit()
	elif not _collect_frames.is_empty():
		await get_tree().create_timer(1.0).timeout
		if not _line_mode: _collect()
		for i in range(20):
			await get_tree().create_timer(0.1).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_collect_frames.path_join("f%02d.png" % i))
		get_tree().quit()

func _build_world() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("2c5a8e")
	sky_material.sky_horizon_color = Color("7d9cba")
	sky_material.ground_horizon_color = Color("7d9cba")
	sky_material.ground_bottom_color = Color("5f7d9c")
	sky_material.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("e6d9c4")
	env.ambient_light_sky_contribution = 0.35
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("7d9cba")
	env.fog_density = 0.0015
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_label = Label.new()
	_label.position = Vector2(24.0,20.0)
	_label.add_theme_font_size_override("font_size",22)
	_label.add_theme_color_override("font_color",Color("3a2f24"))
	var layer := CanvasLayer.new()
	layer.add_child(_label)
	var help := Label.new()
	help.text = "Drag orbit · Wheel zoom · ←/→ glyph · Space collect · Tab ring · L line · F freeze"
	help.add_theme_color_override("font_color",Color("5a4c3c"))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.position = Vector2(24.0,-40.0)
	layer.add_child(help)
	add_child(layer)

## A token in a holder that turns and bobs, with its halo and motes
## (scripts/glyph_pickup.gd).
func _holder(id: String, size: float) -> Node3D:
	return GlyphPickup.make(id,size)

func _show_hero() -> void:
	if _hero: _hero.queue_free()
	var id: String = IDS[_hero_index]
	_hero = _holder(id,HERO_SIZE)
	add_child(_hero)
	var it := HudIcons.item(id)
	_label.text = "Line · walking through %d" % LINE_COUNT if _line_mode else "%s · %s   (%d/%d)" % [it.name,it.sub,_hero_index+1,IDS.size()]
	for i in range(_ring.size()): _ring[i].visible = (i != _hero_index or _ring_view) and not _line_mode
	_hero.visible = not _line_mode

func _process(delta: float) -> void:
	for holder: Node3D in _ring+_line+[_hero]:
		if holder != null and is_instance_valid(holder): holder.turning = not _frozen
	if _line_mode:
		_walk(delta)
		return
	var target_distance := 19.0 if _ring_view else _distance
	var focus := Vector3(0.0,-0.2,0.0)
	var d := lerpf(_camera.position.distance_to(focus),target_distance,minf(1.0,delta*4.0)) if _camera.position != Vector3.ZERO else target_distance
	_camera.position = focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*d
	_camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x*0.008
		_pitch = clampf(_pitch+event.relative.y*0.006,-1.2,1.3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance = maxf(2.2,_distance*0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance = minf(16.0,_distance*1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_RIGHT:
				_hero_index = (_hero_index+1)%IDS.size()
				_show_hero()
			KEY_LEFT:
				_hero_index = (_hero_index+IDS.size()-1)%IDS.size()
				_show_hero()
			KEY_TAB:
				_ring_view = not _ring_view
				_show_hero()
			KEY_F: _frozen = not _frozen
			KEY_L:
				_line_mode = not _line_mode
				if _line_mode: _start_line()
				else: _clear_line()
				_show_hero()
			KEY_SPACE: _collect()

## The hero's pickup, and after a beat a fresh one pops back in.
func _collect() -> void:
	if _collecting or _hero == null: return
	_collecting = true
	var hero := _hero
	var tween := _pickup(hero,HERO_SIZE,_hero_index)
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void:
		_collecting = false
		if hero != _hero: return
		_show_hero()
		var fresh := _hero.get_node("Spin") as Node3D
		fresh.scale = Vector3.ONE*0.01
		create_tween().tween_property(fresh,"scale",Vector3.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

## A pickup (scripts/glyph_pickup.gd `take`): a short twist that winds
## faster as the token lifts a touch and brightens, then, still spinning, it
## shrinks away into a wisp (scripts/glyph_puff.gd). Returns the tween, so
## the caller can chain what follows.
func _pickup(holder: Node3D, _size: float, seed: int) -> Tween:
	return holder.take(seed,self,false)

## The line: a row of tokens along x, walked from before the first.
func _start_line() -> void:
	_clear_line()
	for i in range(LINE_COUNT):
		var holder := _holder(IDS[i%IDS.size()],LINE_SIZE)
		holder.position = Vector3(i*LINE_STEP,0.0,0.0)
		holder.phase = i*0.6
		add_child(holder)
		_line.append(holder)
	_walker = -4.0

func _clear_line() -> void:
	for holder in _line: holder.queue_free()
	_line.clear()

## Walk the line, the camera low behind and beside the walker, picking each
## token up as he reaches it; a fresh line once he's past the end.
func _walk(delta: float) -> void:
	_walker += WALK*delta
	for i in range(_line.size()):
		var holder := _line[i]
		if not holder.has_meta("taking") and holder.position.x < _walker: _pickup(holder,LINE_SIZE,i)
	if _walker > LINE_COUNT*LINE_STEP+2.0: _start_line()
	_camera.position = Vector3(_walker-4.2,1.4,2.4)
	_camera.look_at(Vector3(_walker+2.5,0.0,0.0))
