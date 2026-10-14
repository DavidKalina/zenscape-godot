extends Node
## The motif editor's feel (round 3): the early game's tool sound
## (scripts/clay_sound.gd) and tremor (scripts/clay_tremor.gd over
## scripts/reference_tremor.gd) run unchanged, fed by this node standing in
## for the clay they listen to (scripts/land_clay.gd: its `state`, `tool_id`,
## `tool` with its `lift`, the Ravine's `busy`/`cut_share`, and `sounded`).
## The editor says what the hand is doing (`hold`, `cutting`, `rest`) and
## asks for one-shots (`cue`); the camera's shake is `shake(base)`.
##
## Also the palette's thumbnails, rendered from the real meshes as the old
## build palette rendered its tiles (scripts/native_build_palette.gd
## `_render`): a small world each, lit, the camera framing the piece.

const ClaySound = preload("res://scripts/clay_sound.gd")
const ClayTremor = preload("res://scripts/clay_tremor.gd")
const ReferenceTremor = preload("res://scripts/reference_tremor.gd")

signal sounded(cue_name: StringName, at: Vector3, strength: float)

enum State { IDLE, PENDING, DRAG, HOLD, RUN, PAINT }

## What ClaySound and ClayTremor read off the clay.
var state: int = State.IDLE
var tool_id := ""
var tool: Hand = null
var verb := ""
var speed := 0.0
var rub := 0.0
var last_plate = null
var center := Vector3.ZERO
var scene = null
var editor: Hand = null

var sound: Node
var trembler: Node
var tremor: RefCounted

## The tool in hand as the sound and tremor read it.
class Hand extends RefCounted:
	var lift := 0.0
	var head := 0.0
	var share := -1.0
	var length := 1.0
	var terrain: Node3D
	func busy() -> bool: return share >= 0.0 and share < 1.0
	func cut_share() -> float: return maxf(share,0.0)
	func cut_length() -> float: return length

func setup(owner_scene: Node3D) -> void:
	name = "EditorFeel"
	editor = Hand.new()
	editor.terrain = owner_scene
	tool = Hand.new()
	sound = ClaySound.new()
	add_child(sound)
	sound.setup(self)
	tremor = ReferenceTremor.new()
	trembler = ClayTremor.new()
	add_child(trembler)
	trembler.setup(self,tremor)

func ground_at(p: Variant) -> Vector3:
	return p if p is Vector3 else center

## A stamp held and sized: its lift (m; a crater's is down) at `at`.
func hold(id: String, lift: float, at: Vector3) -> void:
	state = State.HOLD
	tool_id = id
	tool.lift = lift
	tool.share = -1.0
	center = at

## The Ravine's cut running: `share` of its `length` (m) drawn, at `at`.
func cutting(share: float, length: float, at: Vector3) -> void:
	state = State.RUN
	tool_id = "wire"
	tool.share = share
	tool.length = length
	center = at

func rest() -> void:
	state = State.IDLE
	tool.lift = 0.0
	tool.share = -1.0

func cue(cue_name: StringName, at: Vector3, strength := 1.0) -> void:
	if sound != null: sound.play(cue_name,at,strength)

func kick(amount: float) -> void:
	tremor.add(amount)

## The camera's shake over `base`, advanced by `delta`.
func shake(base: Transform3D, delta: float) -> Transform3D:
	tremor.advance(delta,false)
	return tremor.apply(base)

# --- Thumbnails ---------------------------------------------------------------------

const ICON := 160

## `model` rendered once into a texture (kept live in its viewport).
func render(model: Node3D) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON,ICON)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.78,0.76,0.72)
	environment.environment.ambient_light_energy = 1.4
	# Round 4: lit brighter for the palette's tiles (a key, a cool fill
	# from the other side, filmic and opened up), so dark stone reads.
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.tonemap_exposure = 1.0
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-42.0),deg_to_rad(-38.0),0.0)
	light.light_energy = 2.4
	light.light_color = Color(1.0,0.93,0.82)
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0),deg_to_rad(150.0),0.0)
	fill.light_energy = 0.7
	fill.light_color = Color(0.8,0.88,1.0)
	viewport.add_child(fill)
	viewport.add_child(model)
	var bounds := AABB()
	var first := true
	for node: VisualInstance3D in model.find_children("*","VisualInstance3D",true,false):
		if not node is GeometryInstance3D: continue
		var box := node.global_transform*node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var centre := bounds.get_center()
	var radius := maxf(bounds.size.length()*0.5,0.05)
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.05
	camera.far = radius*20.0+50.0
	viewport.add_child(camera)
	var away := Vector3(0.62,0.46,1.0).normalized()*(radius/tan(deg_to_rad(camera.fov*0.5))*1.02)
	camera.look_at_from_position(centre+away,centre,Vector3.UP)
	return viewport.get_texture()
