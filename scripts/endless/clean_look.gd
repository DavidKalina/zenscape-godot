extends Node
## The clean look, an experiment (docs/design/endless-flight/clean-look-handoff.md):
## calmer ground paint, cool shadows, one light model, whiter clouds, lifted
## snags, layered haze, simpler water and a light grade, all mixed by the
## global shader uniform `zs_clean` (0 the look as it was, 1 the clean one),
## which the shaders read, with the Environment's haze and glow moved in code
## to match. Off by default.
##
## Flags: --look=clean starts in it; --edges=1 starts with the edge line
## (ridges and silhouettes, in the haze's colour). Keys: K flips the look,
## J the edges (also F6 and F7); a note says which is on.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const CleanPost = preload("res://scripts/endless/clean_post.gd")
const EndlessLook = preload("res://scripts/endless/endless_look.gd")

## The Environment's haze in the clean look: clear to CLEAN_BEGIN m, then
## thicker through the middle distance, bluer by the aerial share.
const CLEAN_FOG_BEGIN := 260.0
const CLEAN_FOG_CURVE := 0.58
const CLEAN_AERIAL := 0.6
const CLEAN_GLOW := 0.06
## Seconds the flip takes (the uniform eases, so the change is seen).
const FADE := 0.35
## The edge line's strength.
const EDGE_STRENGTH := 0.4

var look: Node3D
var camera: Camera3D
var amount := 0.0
var target := 0.0
var edges := false
var post: CompositorEffect
var _env: Environment
var _base := {}
var _agx := false

static func wanted_look() -> bool:
	return "--look=clean" in LaunchArgs.user_args()

static func wanted_edges() -> bool:
	return "--edges=1" in LaunchArgs.user_args()

func setup(look_node: Node3D, view: Camera3D) -> void:
	name = "CleanLook"
	look = look_node
	camera = view
	_env = look.environment
	_base = {"begin":_env.fog_depth_begin,"curve":_env.fog_depth_curve,"aerial":_env.fog_aerial_perspective,"glow":_env.glow_intensity}
	if CleanPost.available():
		post = CleanPost.new()
		post.camera = camera
	target = 1.0 if wanted_look() else 0.0
	amount = target
	edges = wanted_edges()
	_apply()

## K: the other look. Returns the note to show.
func flip_look() -> String:
	target = 1.0 - target
	return note()

## J: the edge line on or off.
func flip_edges() -> String:
	edges = not edges
	_apply()
	return "Edges: %s" % ("on" if edges else "off")

func note() -> String:
	return "Look: %s" % ("clean" if target > 0.5 else "as it was")

func _process(delta: float) -> void:
	if is_equal_approx(amount,target) and not _dirty: return
	amount = move_toward(amount,target,delta/FADE)
	_apply()

var _dirty := false

func _apply() -> void:
	_dirty = false
	RenderingServer.global_shader_parameter_set("zs_clean",amount)
	RenderingServer.global_shader_parameter_set("zs_edges",1.0 if edges else 0.0)
	if _env != null:
		_env.fog_depth_begin = lerpf(_base.begin,CLEAN_FOG_BEGIN*1.0,amount)
		_env.fog_depth_curve = lerpf(_base.curve,CLEAN_FOG_CURVE,amount)
		_env.fog_aerial_perspective = lerpf(_base.aerial,CLEAN_AERIAL,amount)
		_env.glow_intensity = lerpf(_base.glow,CLEAN_GLOW,amount)
	if post != null:
		post.grade_strength = amount
		post.edge_strength = EDGE_STRENGTH if edges else 0.0
		# The haze's colour, lifted a little, so the line is mist not ink.
		var c := _env.fog_light_color.srgb_to_linear() * _env.fog_light_energy
		var top := maxf(maxf(c.r,c.g),maxf(c.b,1e-4))
		post.edge_colour = Vector3(c.r,c.g,c.b)/top*0.9*minf(top,1.0)*1.0
		post.refresh()

func _exit_tree() -> void:
	if post != null: post.free_buffers()
