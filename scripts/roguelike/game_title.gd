extends Control
## The game's title (docs/design/roguelike/game-v1-launcher.md): shown first
## by run-game.command. ZENSCAPE in the isle card's gilt inscription over a
## dark underground backdrop (shaders/game_title_backdrop.gdshader), and one
## quiet line: Press Space / A to begin. Space, Enter or a pad's A begins the
## run (studies/run_layer.tscn with this scene's own launch flags, a seed
## drawn there); Escape or a pad's B quits. No menus, no options.
##
## `begin()` is the one way in, so a scripted check can call it.
const Splash = preload("res://scripts/isle_splash.gd")
const BACKDROP = preload("res://shaders/game_title_backdrop.gdshader")
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
var _bg: ColorRect
var _title: Label
var _rule: ColorRect
var _prompt: Label
var _veil: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = ColorRect.new()
	_bg.material = ShaderMaterial.new()
	(_bg.material as ShaderMaterial).shader = BACKDROP
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var m := _bg.material as ShaderMaterial
	m.set_shader_parameter("aspect",size.x/maxf(size.y,1.0))
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
	(_bg.material as ShaderMaterial).set_shader_parameter("fade_in",smoothstep(0.0,FADE*0.8,age))
	_title.modulate.a = smoothstep(0.6,FADE,age)
	_rule.modulate.a = smoothstep(1.0,FADE+0.4,age)
	# The prompt comes in last, then breathes.
	var breath := 0.62+0.38*(0.5+0.5*sin(age*2.1))
	_prompt.modulate.a = smoothstep(FADE,FADE+1.2,age)*breath
	if starting:
		_veil.color.a = minf(1.0,_veil.color.a+delta/LEAVE)
		if _veil.color.a >= 1.0: _go()

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
