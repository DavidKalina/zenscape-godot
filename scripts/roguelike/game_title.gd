extends Control
## The game's title (docs/design/roguelike/game-v1-launcher.md): shown first
## by run-game.command. ZENSCAPE in the isle card's gilt inscription over a
## slowly orbiting 3D scene of the game's own pieces
## (scripts/roguelike/game_title_scene.gd), and one
## quiet line: Press Space / A to begin. Space, Enter or a pad's A begins the
## run (studies/run_layer.tscn with this scene's own launch flags, a seed
## drawn there); Escape or a pad's B quits. No menus, no options.
##
## `begin()` is the one way in, so a scripted check can call it.
const Splash = preload("res://scripts/isle_splash.gd")
const Backdrop = preload("res://scripts/roguelike/game_title_scene.gd")
const SkyShot = preload("res://scripts/roguelike/game_title_sky.gd")
## The first shot (the dark city's stair) holds this long once the title is
## up (s), then the screen goes to black for CUT s while the sky aqueduct
## stands, and the sky shot comes up and stays. `--title-shot=sky|city`
## shows one alone (stills); `--orbit-t=` starts the city's sweep partway.
const HOLD := 11.0
const CUT := 1.1
const RUN_SCENE := "res://studies/run_layer.tscn"
const TITLE := "ZENSCAPE"
const PROMPT := "Press  Space  /  A  to begin"
const INK := Color("e3d7bd")
## Seconds the backdrop and the type take to come up from black.
const FADE := 2.2
## Seconds the screen takes to go to black once begun, before the scene
## changes.
const LEAVE := 0.6

signal began

var age := 0.0
var starting := false
## The scene `begin` goes to (a check sets another).
var run_scene := RUN_SCENE
var scene: Node3D
var sky: Control
## 0 the city, 1 going to black, 2 the sky standing, 3 the sky.
var stage := 0
var stage_t := 0.0
var only := ""
var _bg: ColorRect
var _title: Label
var _rule: ColorRect
var _prompt: Label
var _veil: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--title-shot="): only = a.get_slice("=",1)
	if only != "sky":
		scene = Backdrop.new()
		scene.name = "Backdrop"
		add_child(scene)
	# Black over the 3D view, lifting as the title comes up.
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A soft dark wash down from the top, under the type, so the wordmark
	# holds over the sunlit clouds.
	var wash := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.03,0.02,0.02,0.42),Color(0.03,0.02,0.02,0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0,0.0)
	gt.fill_to = Vector2(0.0,1.0)
	gt.width = 4
	gt.height = 128
	wash.texture = gt
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	wash.anchor_right = 1.0
	wash.anchor_bottom = 0.55
	_title = Label.new()
	var font := Splash.inscription_font()
	font.spacing_glyph = 22
	_title.add_theme_font_override("font",font)
	_title.material = Splash.gilt_material()
	_title.text = TITLE
	_title.add_theme_color_override("font_color",Color.WHITE)
	_title.add_theme_color_override("font_shadow_color",Color(0,0,0,0.5))
	_title.add_theme_constant_override("shadow_offset_y",2)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_rule = ColorRect.new()
	_rule.color = Color(0.89,0.84,0.74,0.5)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)
	_prompt = Label.new()
	_prompt.text = PROMPT
	_prompt.add_theme_font_override("font",Splash.READING)
	_prompt.add_theme_color_override("font_color",INK)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_veil = ColorRect.new()
	_veil.color = Color(0,0,0,0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var px := size.y/1080.0
	var title_size := roundi(96.0*px)
	_title.add_theme_font_size_override("font_size",title_size)
	(_title.material as ShaderMaterial).set_shader_parameter("glyph_scale",96.0*px/58.0)
	_title.position = Vector2(0,size.y*0.30)
	_title.size = Vector2(size.x,title_size*1.4)
	_rule.size = Vector2(420.0*px,maxf(1.0,roundf(px)))
	_rule.position = Vector2((size.x-_rule.size.x)*0.5,size.y*0.30+title_size*1.55)
	_prompt.add_theme_font_size_override("font_size",roundi(24.0*px))
	_prompt.position = Vector2(0,size.y*0.74)
	_prompt.size = Vector2(size.x,40.0*px)

func _process(delta: float) -> void:
	age += delta
	_cover(delta)
	_title.modulate.a = smoothstep(0.6,FADE,age)
	_rule.modulate.a = smoothstep(1.0,FADE+0.4,age)
	# The prompt comes in last, then breathes.
	var breath := 0.62+0.38*(0.5+0.5*sin(age*2.1))
	_prompt.modulate.a = smoothstep(FADE,FADE+1.2,age)*breath
	if starting:
		_veil.color.a = minf(1.0,_veil.color.a+delta/LEAVE)
		if _veil.color.a >= 1.0: _go()

## The black over the 3D view: lifting as the title comes up, then dropping
## for the cut to the sky shot and lifting on it.
func _cover(delta: float) -> void:
	stage_t += delta
	if only == "sky" and stage == 0:
		stage = 2
		stage_t = 0.0
		_stand_sky.call_deferred()
	match stage:
		0:
			_bg.color.a = 1.0-smoothstep(0.0,FADE*0.8,age)
			if only == "" and age >= FADE+HOLD:
				stage = 1
				stage_t = 0.0
		1:
			_bg.color.a = smoothstep(0.0,CUT*0.5,stage_t)
			if stage_t >= CUT*0.5+0.1:
				stage = 2
				stage_t = 0.0
				_stand_sky.call_deferred()
		3:
			_bg.color.a = 1.0-smoothstep(0.0,FADE*0.8,stage_t)

## Past the black: the dark city out, the sky isle stood (blocking), its
## shot lifted.
func _stand_sky() -> void:
	if scene != null:
		scene.queue_free()
		scene = null
	# Two frames so the black is on screen before the freeze.
	await get_tree().process_frame
	await get_tree().process_frame
	# The city's grass grade is on the shared ground and tufts: hand them back
	# to the day's own before the sky isle stands on them.
	preload("res://scripts/underground/ground_cover.gd").grade("")
	sky = SkyShot.new()
	sky.name = "Sky"
	add_child(sky)
	move_child(sky,_bg.get_index())
	sky.build()
	stage = 3
	stage_t = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if starting: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: begin()
			KEY_ESCAPE: get_tree().quit()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A: begin()
		elif event.button_index == JOY_BUTTON_B: get_tree().quit()

## Begins the run: the screen goes to black, then the run's scene opens with
## the flags this one was launched with.
func begin() -> void:
	if starting: return
	starting = true
	began.emit()
	# Headless, no fade to wait for.
	if DisplayServer.get_name() == "headless": _go()

func _go() -> void:
	set_process(false)
	var LaunchArgs = preload("res://scripts/launch_args.gd")
	LaunchArgs.open_scene(get_tree(),run_scene,LaunchArgs.user_args())
