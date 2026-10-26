extends Node
## The clean look, an experiment (docs/design/endless-flight/clean-look-handoff.md):
## calmer ground paint, cool shadows, one light model, lighter clouds, lifted
## snags, layered haze, simpler water and a light grade, each its own switch,
## each a global shader uniform (zs_cl_paint, zs_cl_shadow, zs_cl_light,
## zs_cl_cloud, zs_cl_snag, zs_cl_dist, zs_cl_water) eased on a flip, with the
## Environment's haze and glow moved in code to match. All off by default, and
## then the look is the main one.
##
## Flags: --look=clean starts with every item on; --clean=paint,shadows,...
## starts with those only (paint, shadows, light, clouds, snags, distance,
## water, grade, edges); the clouds are never in --look=clean or K: they stay
## as they were until --clouds=cream|white or key 4 (white when on and not said); --edges=1 starts with the edge line. Keys (in
## studies/endless_flight.gd): K the master flip, O (F8) the panel, 1-9 one
## item each, J the edge line.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const CleanPost = preload("res://scripts/endless/clean_post.gd")
const EndlessLook = preload("res://scripts/endless/endless_look.gd")

## The Environment's haze in the clean look: clear to CLEAN_BEGIN m, then
## thicker through the middle distance, bluer by the aerial share.
const CLEAN_FOG_BEGIN := 260.0
const CLEAN_FOG_CURVE := 0.52
const CLEAN_AERIAL := 0.7
const CLEAN_GLOW := 0.06
## Seconds the flip takes (the uniform eases, so the change is seen).
const FADE := 0.35
## The edge line's strength.
const EDGE_STRENGTH := 0.55

## The items in key order (1-9): name, label, the global it drives ("" none).
const ITEMS := [
	["paint","Ground paint","zs_cl_paint"],
	["shadows","Cool shadows","zs_cl_shadow"],
	["light","One light model","zs_cl_light"],
	["clouds","Clouds","zs_cl_cloud"],
	["snags","Snags","zs_cl_snag"],
	["distance","Distance layers","zs_cl_dist"],
	["water","Water","zs_cl_water"],
	["grade","Grade",""],
	["edges","Edges",""],
]
const CLOUD_NAMES := ["as it was","cream","white"]

var look: Node3D
var camera: Camera3D
## Each item's target (0 off, 1 on; the clouds 0 / 1 cream / 2 white) and its eased value.
var target := {}
var amount := {}
var post: CompositorEffect
var panel: Label
var _env: Environment
var _base := {}
var _base_agx := false
var _cloud_pick := 2
var _dirty := true
## AgX in place of ACES was tried and turned the greens khaki and the spruce tan
## (the palette is built against ACES), so it is off: --clean-agx puts it back.
var AGX := "--clean-agx" in LaunchArgs.user_args()

static func _arg(prefix: String) -> String:
	for a in LaunchArgs.user_args():
		if a.begins_with(prefix): return a.substr(prefix.length())
	return ""

static func wanted_look() -> bool:
	return "--look=clean" in LaunchArgs.user_args()

static func wanted_edges() -> bool:
	return "--edges=1" in LaunchArgs.user_args()

func setup(look_node: Node3D, view: Camera3D) -> void:
	name = "CleanLook"
	look = look_node
	camera = view
	_env = look.environment
	_base_agx = _env.tonemap_mode == Environment.TONE_MAPPER_AGX
	_base = {"begin":_env.fog_depth_begin,"curve":_env.fog_depth_curve,"aerial":_env.fog_aerial_perspective,"glow":_env.glow_intensity}
	if CleanPost.available():
		post = CleanPost.new()
		post.camera = camera
	for it in ITEMS:
		target[it[0]] = 0.0
		amount[it[0]] = 0.0
	var clouds := _arg("--clouds=")
	if clouds in ["cream","white"]: _cloud_pick = 1 if clouds == "cream" else 2
	var on: Array = []
	if wanted_look():
		for it in ITEMS: if it[0] != "edges" and it[0] != "clouds": on.append(it[0])
	var list := _arg("--clean=")
	if not list.is_empty(): on.append_array(list.split(",",false))
	if wanted_edges(): on.append("edges")
	if not clouds.is_empty() and clouds != "beige" and not on.has("clouds") and (wanted_look() or not list.is_empty()): on.append("clouds")
	for n in on:
		if target.has(n): target[n] = float(_cloud_pick) if n == "clouds" else 1.0
	if clouds == "beige": target["clouds"] = 0.0
	for k in target: amount[k] = target[k]
	_build_panel()
	_apply()

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	panel = Label.new()
	panel.position = Vector2(16,16)
	panel.visible = false
	panel.add_theme_font_size_override("font_size",15)
	panel.add_theme_color_override("font_outline_color",Color(0,0,0,0.9))
	panel.add_theme_constant_override("outline_size",5)
	layer.add_child(panel)

func _state_text(n: String) -> String:
	if n == "clouds": return CLOUD_NAMES[int(round(target[n]))]
	return "on" if target[n] > 0.5 else "off"

func _refresh_panel() -> void:
	var t := "Clean look  (K all on/off, O close, J edges)\n"
	var i := 1
	for it in ITEMS:
		t += "%d  %s: %s\n" % [i,it[1],_state_text(it[0])]
		i += 1
	panel.text = t

func toggle_panel() -> String:
	panel.visible = not panel.visible
	_refresh_panel()
	return "Clean look panel: %s" % ("open" if panel.visible else "closed")

func any_on() -> bool:
	for k in target: if target[k] > 0.0: return true
	return false

## K: the master, all items on, or all off when all are on already (a mixed
## set goes to all on). Returns the note.
func flip_look() -> String:
	var off := true
	for k in target: if k != "edges" and k != "clouds" and target[k] == 0.0: off = false
	for it in ITEMS:
		var n: String = it[0]
		if n == "edges": continue
		# The clouds stay as they were unless asked (key 4, --clouds=); the
		# master only switches them off with the rest.
		if n == "clouds":
			if off: target[n] = 0.0
			continue
		target[n] = 0.0 if off else 1.0
	_changed()
	return "Look: %s" % ("as it was" if off else "clean")

## 1-9: one item. Returns the note.
func flip_item(index: int) -> String:
	if index < 0 or index >= ITEMS.size(): return ""
	var n: String = ITEMS[index][0]
	if n == "clouds":
		target[n] = float((int(round(target[n]))+1) % 3)
		if target[n] > 0.0: _cloud_pick = int(target[n])
	else:
		target[n] = 1.0 - target[n]
	_changed()
	return "%s: %s" % [ITEMS[index][1],_state_text(n)]

## J: the edge line on or off.
func flip_edges() -> String:
	return flip_item(8)

func _changed() -> void:
	_dirty = true
	if panel != null: _refresh_panel()

## The haze's own colour (scene linear), eased toward white: mist, not ink.
func _edge_colour() -> void:
	if post == null or _env == null: return
	var c := _env.fog_light_color.srgb_to_linear()
	var e := _env.fog_light_energy
	post.edge_colour = Vector3(c.r,c.g,c.b)*e*0.75+Vector3(0.125,0.125,0.125)

## The clean look's tints from the published light (celestial.state), each
## frame: the sun side from the key's colour, the shade from the sky's fill,
## the distance planes and the grade from both and the haze. Hue only, eased
## toward the plain colour, so the strength stays what the look chose.
## (At alpine_morning, hour 9.6, they come to the round 2 constants.)
const LUMA := Vector3(0.2126,0.7152,0.0722)
static func _rel(c: Vector3) -> Vector3:
	return c / maxf(c.dot(LUMA),0.02)

func _tints() -> void:
	if look == null or look.get("celestial") == null: return
	var st: Dictionary = look.celestial.state
	if not (st.has("zs_key_irradiance") and st.has("zs_hemi_sky")): return
	var sun_y := (st.zs_sun_direction as Vector3).y if st.has("zs_sun_direction") else 0.5
	var low := smoothstep(0.45,0.1,sun_y)
	var sun_rel := _rel(st.zs_key_irradiance)
	var sky_rel := _rel(st.zs_hemi_sky)
	var warm := Vector3.ONE.lerp(sun_rel,lerpf(0.12,0.30,low))
	var cool := Vector3.ONE.lerp(sky_rel,0.66)*Vector3(1.0,0.885,1.0)
	var haze := Vector3.ONE
	if _env != null:
		var h := _env.fog_light_color.srgb_to_linear()
		haze = _rel(Vector3(h.r,h.g,h.b)).clamp(Vector3(0.35,0.35,0.35),Vector3(2.2,2.2,2.2))
	var mid := Vector3.ONE.lerp(haze,0.12)*0.95
	var far := Vector3.ONE.lerp(haze,0.22)*0.84
	_publish_vec("zs_cl_warm",warm)
	_publish_vec("zs_cl_cool",cool)
	_publish_vec("zs_cl_haze_mid",mid)
	_publish_vec("zs_cl_haze_far",far)
	if post != null:
		post.tint_warm = Vector3.ONE.lerp(sun_rel,lerpf(0.15,0.28,low))*Vector3(1.0,1.03,1.0)
		post.tint_cool = Vector3.ONE.lerp(sky_rel,0.22)*Vector3(0.975,0.975,1.0)

static func _publish_vec(n: String, v: Vector3) -> void:
	RenderingServer.global_shader_parameter_set(n,v)

func _process(delta: float) -> void:
	_tints()
	if target["edges"] > 0.0: _edge_colour()
	var moving := _dirty
	for k in target:
		if not is_equal_approx(amount[k],target[k]):
			amount[k] = move_toward(amount[k],target[k],delta/FADE*(2.0 if k == "clouds" else 1.0))
			moving = true
	if moving: _apply()

func _apply() -> void:
	_dirty = false
	for it in ITEMS:
		if it[2] != "": RenderingServer.global_shader_parameter_set(it[2],amount[it[0]])
	RenderingServer.global_shader_parameter_set("zs_edges",1.0 if target["edges"] > 0.0 else 0.0)
	var grade: float = amount["grade"]
	var dist: float = amount["distance"]
	if _env != null:
		# AgX over ACES (which yellows the brights), at the half way mark.
		if AGX and grade > 0.5 and _env.tonemap_mode != Environment.TONE_MAPPER_AGX:
			_env.tonemap_mode = Environment.TONE_MAPPER_AGX
			_env.tonemap_agx_white = 16.0
			_env.tonemap_agx_contrast = 1.25
		elif grade <= 0.5 and _env.tonemap_mode == Environment.TONE_MAPPER_AGX and not _base_agx:
			_env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_env.fog_depth_begin = lerpf(_base.begin,CLEAN_FOG_BEGIN*1.0,dist)
		_env.fog_depth_curve = lerpf(_base.curve,CLEAN_FOG_CURVE,dist)
		_env.fog_aerial_perspective = lerpf(_base.aerial,CLEAN_AERIAL,dist)
		_env.glow_intensity = lerpf(_base.glow,CLEAN_GLOW,grade)
	if post != null:
		post.grade_strength = grade
		post.edge_strength = EDGE_STRENGTH * amount["edges"]
		_edge_colour()
		post.refresh()

func _exit_tree() -> void:
	if post != null: post.free_buffers()
