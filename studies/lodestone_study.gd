extends Node3D
## Lodestone look study (docs/design/lodestone-study.md): the key item, a
## stone holding a world in miniature (scripts/lodestone.gd), in its three
## moments, under the game's own sky, sun and look pass (as the ruin kit
## gallery lights itself, studies/ruin_kit_gallery.gd):
##   world    found: hovering over the sill of a ruined lancet window on a
##            small sky island, turning in its swirl. The pilot (scripts/
##            pilot_figure.gd) walks up to it and away; it hums as he nears
##            (the glow, the lode, a warm light on the stone, the swirl
##            quickening).
##   inspect  picked up: it floats down off the sill into his raised mitts,
##            the camera pushes in, and the player turns it to look at the
##            place it holds.
##   cradle   on the plane: seated in a placeholder gimbal on the nose
##            (scripts/plane_figure.gd, its look untouched), seen from the
##            chase camera's place, its swirl streaming off toward the
##            place it knows: ahead, aside, up, down.
## Not the game: nothing here is wired into it.
##   V or Tab, pad Back   the next view       M, pad Y   the next miniature
##   Drag, right stick    turn the stone (inspect) or orbit (world, cradle)
##   Wheel                zoom               E, pad A   pick it up (world)
##   W S                  walk the pilot up and back (world; A toggles auto)
##   T, pad X             the next way to point (cradle; P sweeps round)
##   R                    replay the pickup   N   day or night   I   cost
##   ./run-lodestone-study.command [--view=inspect] [--mini=aqueduct]
##   godot --path . res://studies/lodestone_study.tscn -- --no-title --view=cradle --capture=out.png
## --capture=<png> waits (--wait=seconds, default 5), saves the view, prints
## the cost and quits. --near=<m> holds the pilot that far from the stone
## (world); --target=ahead|left|right|up|down|behind (cradle); --yaw=,
## --pitch=, --distance= set the orbit; --turn=yaw,pitch turns the stone.
const Lodestone = preload("res://scripts/lodestone.gd")
const Minis = preload("res://scripts/lodestone_miniatures.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotPose = preload("res://scripts/pilot_pose.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://studies/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")

const VIEWS := ["world","inspect","cradle"]
const VIEW_NAMES := {"world":"Found on a ruin ledge","inspect":"Picked up and inspected","cradle":"Seated in the plane's cradle (placeholder)"}
## The game's look at its noon (as the ruin kit gallery takes it from the
## look tour, tools/capture_look_tour.gd), its cloud deck, and the hours.
const GAME_LOOK := {"version":1,"palette":"Custom","colors":{"grass":[0.3647,0.6196,0.3255],"foliage":[0.2784,0.4627,0.2902],
	"rock":[0.5529,0.5216,0.4667],"earth":[0.4157,0.3137,0.2431],"water":[0.2235,0.4902,0.4745],"sun":[0.9804,0.8392,0.6863],
	"ambient":[0.5608,0.7020,0.8510],"bounce":[0.2902,0.3216,0.2510],"rim":[0.4980,0.6588,0.7882],"fog":[0.8627,0.8863,0.8745],
	"sky":[0.4784,0.6,0.8],"horizon":[0.7529,0.7922,0.7961],"glow":[0.9529,0.7843,0.6667]},
	"settings":{"strength":0.7416,"sun_energy":1.041,"ambient_energy":1.3539,"exposure":1.0896}}
const CLOUD := 0.14
const DECK := Vector2(20.0,12.0)
const DAY := 0.45
const NIGHT := 0.0
## How far round from the sun the island is turned (as the gallery's
## SIDE): the light over the viewer's left shoulder onto the window's face.
const SIDE := 0.55
## The island: its top's radius (m) and its keel's depth; the window
## wall's sill (RuinKit WINDOW.y) and how high over it the stone hovers.
const ISLAND := 9.0
const ISLAND_KEEL := 11.0
static var SILL: float = RuinKit.WINDOW.y
const HOVER := 0.4
const SILL_X := -0.95
## The pilot's walk up to the stone: from APPROACH.x m off the wall to
## APPROACH.y, at WALK m/s; it hums from HUM_FAR m off the stone, fully at
## HUM_NEAR.
const APPROACH := Vector2(7.5,1.25)
const WALK := 1.3
const HUM_FAR := 5.5
const HUM_NEAR := 1.6
## The pickup: seconds for the stone to float down to the mitts and for
## the camera to push in; where the pilot stands (in front of the window,
## turned to face out); the hold over his mitts (m).
const PICKUP := 1.1
const PUSH := 1.8
const PICK_AT := Vector3(1.0,0.0,1.6)
## The way he turns to hold it up (radians about up; 0 faces -Z, toward
## the window): out along the wall, the open sky behind the stone.
const PICK_FACING := -PI*0.5
const HOLD_UP := 0.42
## How the stone is first turned to the eye (yaw, pitch; radians).
const INSPECT_TURN := Vector2(1.95,0.22)
## The raised arms, overhead as an item held up to the sky: the upper
## arms swung out and up (radians about the model's Z), a little forward
## (about X), the forearms bent in over the head.
const ARMS := Vector3(2.9,0.2,0.3)
## The cradle: the plane hangs at CRADLE_AT (the world frame, out off the
## island), the lodestone at this share of its size on its gimbal, the
## gimbal's post and rings (m), how far the stone tips toward its target.
const CRADLE_AT := Vector3(-30.0,6.0,26.0)
const CRADLE_SCALE := 0.42
const POST := 0.05
const RING := 0.1
const TIP := 0.35
## The ways it can point (cradle), in the plane's frame (-Z ahead).
const TARGETS := {"ahead":Vector3(0.25,0.05,-1.0),"left":Vector3(-1.0,0.0,-0.35),"right":Vector3(1.0,0.0,-0.2),
	"up":Vector3(0.15,1.0,-0.5),"down":Vector3(-0.2,-1.0,-0.45),"behind":Vector3(-0.5,0.1,1.0)}
const TARGET_ORDER := ["ahead","left","right","up","down","behind"]
## The stream's reach in the cradle (m, the stone's own frame).
const STREAM_LENGTH := 7.0
## Its strokes' width (m, the stone's frame) and its riders' size there.
const CRADLE_WIDTH := 0.06
## How far the air sweeps the stream back, as a share of its reach.
const DRIFT := 0.45
const CRADLE_MOTES := 2.5

## What the look pass reads off the scene it dresses (scripts/look_pass.gd).
var _environment: Environment
var _lighting: LandscapeLighting
var _display_fog: CanvasLayer = null
var _precipitation := {"ground_texture":null}
var _motion_time := 0.0

var _view := "world"
var _night := false
var _world: Node3D
var _world_yaw := 0.0
var _camera: Camera3D
var _celestial: RefCounted
var _look: Node
var _sun: DirectionalLight3D
var _label: Label
var _help: Label
var _stone: Node3D
var _pilot: Node3D
## The pose the pilot figure reads (scripts/pilot_pose.gd, `drive`): a
## plain walker on flat ground.
var _motor: PilotPose
var _plane: Node3D
var _glide: FakeGlide
var _gimbal_outer: Node3D
var _gimbal_inner: Node3D
var _seat: Node3D
var _sill_point := Vector3.ZERO
## The orbit camera (world, cradle): its focus, yaw, pitch, distance.
var _focus := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.3
var _distance := 7.0
var _orbit_set := false
## The pilot's walk: where along the approach (m off the wall), which way,
## and whether it walks on its own.
var _along := APPROACH.x
var _walk_dir := -1.0
var _auto_walk := true
var _held_near := -1.0
## The pickup's clock (s since it began) and the camera's start.
var _pick := 0.0
var _pick_from_cam := Transform3D.IDENTITY
## Cradle: the target's name, the sweep, its clock.
var _target := "ahead"
var _sweep := false
var _sweep_clock := 0.0
var _capture := ""
var _wait := 5.0
var _cost := {}
## The arms' pose (ARMS; --arms=raise,forward,forearms to try others).
var _arms := ARMS

## The flight the plane figure reads (scripts/plane_figure.gd `update`): a
## steady cruise in place.
class FakeGlide extends RefCounted:
	var position := Vector3.ZERO
	var heading := 0.0
	var pitch := 0.0
	var bank := 0.0
	var speed := 7.0
	var spin := 0.0
	var throttle := 0.6
	var engine := 1.0
	var velocity := Vector3(0.0,0.0,-7.0)
	func forward() -> Vector3:
		return Vector3(-sin(heading),0.0,-cos(heading))

func _ready() -> void:
	var mini := Minis.KINDS[0]
	var turn := Vector2.INF
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--view="): _view = arg.get_slice("=",1)
		elif arg.begins_with("--mini="): mini = arg.get_slice("=",1)
		elif arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
		elif arg.begins_with("--wait="): _wait = float(arg.get_slice("=",1))
		elif arg.begins_with("--near="): _held_near = float(arg.get_slice("=",1))
		elif arg.begins_with("--target="): _target = arg.get_slice("=",1)
		elif arg == "--sweep": _sweep = true
		elif arg.begins_with("--arms="):
			var a := arg.get_slice("=",1).split(",")
			_arms = Vector3(float(a[0]),float(a[1]),float(a[2]))
		elif arg == "--night": _night = true
		elif arg.begins_with("--turn="):
			var p := arg.get_slice("=",1).split(",")
			turn = Vector2(float(p[0]),float(p[1]) if p.size() > 1 else 0.0)
	if not _view in VIEWS: _view = "world"
	if not mini in Minis.KINDS: mini = Minis.KINDS[0]
	if not _target in TARGETS: _target = "ahead"
	_build_world()
	_set_night(_night)
	_build_island()
	_build_plane()
	_stone = Lodestone.new()
	_stone.set_miniature(mini)
	_set_view(_view)
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--yaw="):
			_yaw = float(arg.get_slice("=",1))
			_orbit_set = true
		elif arg.begins_with("--pitch="): _pitch = float(arg.get_slice("=",1))
		elif arg.begins_with("--distance="):
			_distance = float(arg.get_slice("=",1))
			_orbit_set = true
	if turn.is_finite():
		_stone.idle_turn = false
		_stone.turn_by(turn)
	if not _capture.is_empty(): _take_capture()

func _take_capture() -> void:
	await get_tree().create_timer(_wait).timeout
	await _measure_cost()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture)
	print("lodestone study: saved %s" % _capture)
	get_tree().quit()

## What the lodestone costs in this view: the frame's draws and triangles
## with it and without it (shadows included), and its own triangles.
func _measure_cost() -> void:
	var with := await _frame_info()
	_stone.visible = false
	var without := await _frame_info()
	_stone.visible = true
	await _frame_info()
	_cost = {"draws":with.x-without.x,"primitives":with.y-without.y,"frame_draws":with.x,"frame_primitives":with.y}
	print("lodestone cost [%s, %s]: %d draws, %d primitives in the frame (frame %d draws, %d primitives); miniature %d tris, stone+shards %d tris, scale %.4f, swirl %s" % [_view,_stone.kind,
		_cost.draws,_cost.primitives,_cost.frame_draws,_cost.frame_primitives,int(_stone.info.triangles),int(_stone.info.stone_triangles),float(_stone.info.scale),_stone.info.swirl])
	_say()

func _frame_info() -> Vector2i:
	for i in range(3): await RenderingServer.frame_post_draw
	return Vector2i(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))

# --- The world -------------------------------------------------------------------

func _build_world() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	_lighting = LandscapeLighting.new()
	add_child(_lighting)
	_lighting.setup(source)
	_environment = _lighting.environment
	for light in _lighting.lights: light.directional_shadow_max_distance = 40.0
	_sun = _lighting.lights[0]
	_celestial = Celestial.new()
	_celestial.setup(_lighting.lights)
	_celestial.cycling = false
	_celestial.cloud = CLOUD
	_celestial.look.restore(GAME_LOOK)
	var exposure: float = float(source.exposure)/1.08*float(_celestial.look.settings.exposure)
	_environment.tonemap_exposure = exposure
	RenderingServer.global_shader_parameter_set("zs_exposure",exposure)
	_look = LookPass.new()
	_look.setup(self)
	_look.apply_tier(_look.tier)
	preload("res://scripts/render_resolution.gd").attach(get_viewport())
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.02
	_camera.far = 4000.0
	add_child(_camera)
	_camera.make_current()
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24.0,18.0)
	_label.add_theme_font_size_override("font_size",20)
	_label.add_theme_color_override("font_color",Color(1.0,0.98,0.92,0.85))
	_label.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.4))
	layer.add_child(_label)
	_help = Label.new()
	_help.add_theme_font_size_override("font_size",15)
	_help.add_theme_color_override("font_color",Color(1.0,0.98,0.92,0.5))
	_help.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.3))
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.position = Vector2(24.0,-34.0)
	layer.add_child(_help)

## The island: a faceted chip of sky island (the lodestone's own keel,
## scripts/lodestone.gd `keel_mesh`, at an island's size), on it a weathered
## lancet window wall of the gothic kit with a pier and floor slabs by it,
## the stone hovering over the window's sill; the pilot.
func _build_island() -> void:
	var outline := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in range(18):
		var a := TAU*k/18.0
		outline.append(Vector2(cos(a),sin(a))*ISLAND*rng.randf_range(0.85,1.08)+Vector2(0.0,1.5))
	var land := MeshInstance3D.new()
	land.name = "Island"
	land.mesh = Lodestone.keel_mesh(outline,ISLAND_KEEL,5,false)
	var rock := ShaderMaterial.new()
	rock.shader = Lodestone.STONE_SHADER
	rock.set_shader_parameter("sheen",0.0)
	rock.set_shader_parameter("specular_amount",0.0)
	rock.set_shader_parameter("fill",0.6)
	land.material_override = rock
	land.position.y = -0.02
	_world.add_child(land)
	var wall := RuinKit.piece("lancet_wall",4,0.55)
	wall.name = "LancetWall"
	_world.add_child(wall)
	var pier := RuinKit.piece("pier",9,0.8)
	pier.position = Vector3(-5.2,0.0,-0.6)
	_world.add_child(pier)
	var floor_slabs := RuinKit.piece("floor",6,0.7)
	floor_slabs.position = Vector3(3.2,0.0,2.8)
	floor_slabs.rotation.y = 0.4
	_world.add_child(floor_slabs)
	# Over the left light of the window (its broken mullion stands in the
	# middle).
	_sill_point = Vector3(SILL_X,SILL+HOVER,0.0)
	_pilot = PilotFigure.new()
	_world.add_child(_pilot)
	_motor = PilotPose.new()
	_pilot.settle()

## The plane, out off the island, cruising in place; its gimbal on the
## nose, before the windscreen: a post, an outer ring turning about its up,
## an inner ring tipping in it, the stone's seat in the middle. Brass, as the plane's
## fittings (scripts/plane_figure.gd `_metal`).
func _build_plane() -> void:
	_plane = PlaneFigure.new()
	_plane.name = "Plane"
	_world.add_child(_plane)
	_glide = FakeGlide.new()
	_glide.position = CRADLE_AT
	_plane.reset(_glide)
	_plane._mark.visible = false
	_plane._vapour.visible = false
	var brass := PlaneFigure._metal(PlaneFigure.BRASS,0.35)
	var mount := Node3D.new()
	mount.name = "Cradle"
	mount.position = Vector3(0.0,PlaneFigure._body_at(-0.3).z,-0.3)
	_plane.add_child(mount)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.008
	post_mesh.bottom_radius = 0.016
	post_mesh.height = POST
	post_mesh.radial_segments = 6
	post_mesh.rings = 1
	post.mesh = post_mesh
	post.material_override = brass
	post.position.y = POST*0.5
	mount.add_child(post)
	var foot := MeshInstance3D.new()
	var foot_mesh := CylinderMesh.new()
	foot_mesh.top_radius = 0.025
	foot_mesh.bottom_radius = 0.032
	foot_mesh.height = 0.008
	foot_mesh.radial_segments = 8
	foot_mesh.rings = 1
	foot.mesh = foot_mesh
	foot.material_override = brass
	mount.add_child(foot)
	_gimbal_outer = Node3D.new()
	_gimbal_outer.name = "Outer"
	_gimbal_outer.position.y = POST+RING
	mount.add_child(_gimbal_outer)
	_gimbal_outer.add_child(_ring(RING,brass,Basis(Vector3.RIGHT,PI*0.5)))
	_gimbal_inner = Node3D.new()
	_gimbal_inner.name = "Inner"
	_gimbal_outer.add_child(_gimbal_inner)
	_gimbal_inner.add_child(_ring(RING*0.86,brass,Basis(Vector3.FORWARD,PI*0.5)*Basis(Vector3.RIGHT,PI*0.5)))
	_seat = Node3D.new()
	_seat.name = "Seat"
	_gimbal_inner.add_child(_seat)

## A faceted ring (a torus of few sides) of radius `r`, turned by `turn`.
func _ring(r: float, material: Material, turn: Basis) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = r-0.006
	mesh.outer_radius = r+0.006
	mesh.rings = 20
	mesh.ring_segments = 4
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.basis = turn
	return node

# --- Views ------------------------------------------------------------------------

func _set_view(view: String) -> void:
	_view = view
	if _stone.get_parent() != null: _stone.get_parent().remove_child(_stone)
	_stone.stream_goal = 0.0
	_stone.scale = Vector3.ONE
	_stone.show_light(view != "cradle")
	_pilot.visible = view != "cradle"
	match view:
		"world":
			_world.add_child(_stone)
			_stone.position = _sill_point
			_stone.basis = Basis.IDENTITY
			_stone.idle_turn = true
			_stone.reset_turn()
			if not _orbit_set:
				_focus = Vector3(-0.6,1.55,0.7)
				_yaw = 0.5
				_pitch = 0.3
				_distance = 2.6
			if _held_near >= 0.0: _along = clampf(_held_near,APPROACH.y,APPROACH.x)
		"inspect":
			_world.add_child(_stone)
			_stone.position = _sill_point
			_stone.idle_turn = true
			_pick = 0.0
			# Turned three-quarters on to the eye, tipped a little toward it,
			# so the place shows its length and its top.
			_stone.reset_turn()
			_stone.turn_by(Vector2(INSPECT_TURN.x-_stone._yaw,INSPECT_TURN.y))
			_pilot.position = PICK_AT
			_pilot.rotation.y = PICK_FACING
			_pilot.settle()
			_motor.velocity = Vector3.ZERO
			_motor.facing = PICK_FACING
			_motor.feet = PICK_AT
			var front := _pick_frame()
			_pick_from_cam = _world.global_transform*Transform3D(Basis.IDENTITY,PICK_AT+front*Vector3(1.6,1.5,3.6)).looking_at(PICK_AT+Vector3(0.0,1.3,0.0))
			if not _capture.is_empty(): _pick = PICKUP+PUSH
		"cradle":
			_seat.add_child(_stone)
			_stone.position = Vector3.ZERO
			_stone.basis = Basis.IDENTITY
			_stone.scale = Vector3.ONE*CRADLE_SCALE
			_stone.idle_turn = true
			_stone.reset_turn()
			_stone.stream_goal = 1.0
			_stone.hum_goal = 0.7
			_stone._ribbon_material.set_shader_parameter("stream_length",STREAM_LENGTH)
			_stone._motes_material.set_shader_parameter("stream_length",STREAM_LENGTH)
			if not _orbit_set:
				_yaw = 0.0
				_pitch = 0.27
				_distance = 5.4
			if not _capture.is_empty(): _stone.stream = 1.0
	# In the cradle, seen from the chase camera's distance, the strokes and
	# riders are drawn bolder.
	var bold := view == "cradle"
	_stone._ribbon_material.set_shader_parameter("width",CRADLE_WIDTH if bold else 0.012)
	_stone._motes_material.set_shader_parameter("sizes",Vector4(0.006,0.012,0.016,0.07)*(CRADLE_MOTES if bold else 1.0))
	if not bold:
		for material: ShaderMaterial in [_stone._ribbon_material,_stone._motes_material]: material.set_shader_parameter("stream_drift",Vector3.ZERO)
		_stone._ribbon_material.set_shader_parameter("stream_length",1.2)
		_stone._motes_material.set_shader_parameter("stream_length",1.2)
	_say()

func _say() -> void:
	var cost := ""
	if not _cost.is_empty(): cost = "   ·   lodestone %d draws, %d tris on screen" % [_cost.draws,_cost.primitives]
	var info: Dictionary = _stone.info
	var extra := ""
	match _view:
		"world": extra = "   ·   pilot %.1f m off   ·   hum %.2f" % [_stone_distance(),_stone.hum]
		"cradle": extra = "   ·   pointing %s%s" % [_target," (sweeping)" if _sweep else ""]
	_label.text = "%s   ·   %s%s\nminiature %d tris, stone %d tris, at %.4f of its size%s" % [VIEW_NAMES[_view],info.name,extra,info.triangles,info.stone_triangles,info.scale,cost]
	match _view:
		"world": _help.text = "V next view · M next miniature · W S walk the pilot (A auto) · E pick up · Drag orbit · Wheel zoom · N night · I cost"
		"inspect": _help.text = "V next view · M next miniature · Drag or right stick turn the stone · Wheel zoom · R replay the pickup · N night · I cost"
		"cradle": _help.text = "V next view · M next miniature · T next way to point · P sweep round · Drag orbit · Wheel zoom · N night · I cost"

func _set_night(on: bool) -> void:
	_night = on
	_celestial.set_phase(NIGHT if on else DAY)
	var toward: Vector3 = _sun.global_basis.z
	var flat := Vector2(toward.x,toward.z)
	if flat.length() > 0.01: _world_yaw = atan2(flat.x,flat.y)-SIDE
	_world.rotation.y = _world_yaw
	if _label != null and _stone != null: _say()

func _stone_distance() -> float:
	var p: Vector3 = _pilot.position
	return Vector2(p.x-_sill_point.x,p.z-_sill_point.z).length()

# --- Frames ------------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	_motion_time += delta
	_celestial.advance(delta,true)
	match _view:
		"world": _step_world(delta)
		"inspect": _step_inspect(delta)
		"cradle": _step_cradle(delta)
	RenderingServer.global_shader_parameter_set("zs_camera_position",_camera.global_position)
	RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
	RenderingServer.global_shader_parameter_set("zs_flow_time",_motion_time)
	_look.update(_camera,_celestial)
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(_celestial.cloud,0.0,DECK.x,DECK.y))
	if Engine.get_process_frames()%20 == 0: _say()

func _orbit_camera() -> void:
	var at := _focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance
	_camera.global_transform = _world.global_transform*Transform3D(Basis.IDENTITY,at).looking_at(_focus)

## The pilot walks up to the window and away (or holds --near), the stone
## humming as he nears; it bobs over the sill.
func _step_world(delta: float) -> void:
	var speed := 0.0
	if _held_near < 0.0:
		var push := 0.0
		if Input.is_key_pressed(KEY_W): push = -1.0
		elif Input.is_key_pressed(KEY_S): push = 1.0
		if push != 0.0: _walk_dir = push
		elif _auto_walk:
			if _along <= APPROACH.y+0.01: _walk_dir = 1.0
			elif _along >= APPROACH.x-0.01: _walk_dir = -1.0
		if push != 0.0 or _auto_walk:
			var was := _along
			_along = clampf(_along+_walk_dir*WALK*delta,APPROACH.y,APPROACH.x)
			speed = absf(_along-was)/maxf(delta,1e-4)
	_pilot.position = Vector3(SILL_X+0.5,0.0,_along)
	_motor.feet = _pilot.position
	_motor.facing = 0.0 if _walk_dir < 0.0 else PI
	_motor.velocity = Vector3(0.0,0.0,_walk_dir*speed)
	_pilot.rotation.y = _motor.facing
	_pilot.drive(_motor,delta)
	var near := _stone_distance()
	_stone.hum_goal = clampf(inverse_lerp(HUM_FAR,HUM_NEAR,near),0.0,1.0)
	if _held_near >= 0.0: _stone.hum = _stone.hum_goal
	_stone.position = _sill_point+Vector3(0.0,sin(_motion_time*0.9)*0.015,0.0)
	_orbit_camera()

## The pickup: the pilot turned out from the window raises his mitts, the
## stone floats down off the sill into them on an arc, and the camera
## pushes in from a medium shot to the stone held up before him.
func _step_inspect(delta: float) -> void:
	_pick += delta
	_pilot.drive(_motor,delta)
	var raise := smoothstep(0.0,0.6,_pick)
	_raise_arms(raise)
	var hands: Vector3 = _world.global_transform.affine_inverse()*((_pilot.mitt(0)+_pilot.mitt(1))*0.5)
	var hold := hands+Vector3(0.0,HOLD_UP,0.0)
	var t := smoothstep(0.15,PICKUP,_pick)
	var arc := _sill_point.lerp(hold,t)+Vector3(0.0,sin(t*PI)*0.35,0.0)
	_stone.position = arc
	_stone.hum_goal = 1.0
	if _pick > PICKUP and _stone.hum < 0.95: _stone.hum = move_toward(_stone.hum,1.0,delta)
	# The camera: from the medium shot to close on the stone, a little
	# above it and to the side, the pilot's face below it in the frame.
	var close := Transform3D(Basis.IDENTITY,hold+_pick_frame()*(Vector3(0.22,0.07,0.82)*_distance_scale())).looking_at(hold+Vector3(0.0,-0.02,0.0))
	var push := smoothstep(PICKUP*0.4,PICKUP+PUSH,_pick)
	var to := _world.global_transform*close
	_camera.global_transform = _pick_from_cam.interpolate_with(to,push)
	var stick := Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.2:
		_stone.idle_turn = false
		_stone.turn_by(stick*delta*1.8)

## The frame the pickup is framed in: +Z out the way the pilot faces.
func _pick_frame() -> Basis:
	return Basis(Vector3.UP,PICK_FACING+PI)

func _distance_scale() -> float:
	return clampf(_distance/7.5,0.5,2.5) if _orbit_set else 1.0

## Bends the pilot's arms up over the clips' pose: the mitts raised before
## him, cupped in toward each other (`amount` 0 hanging to 1 raised).
func _raise_arms(amount: float) -> void:
	if amount <= 0.0: return
	var arms: Array[int] = _pilot._upper_arms
	var forearms: Array[int] = _pilot._forearms
	if arms.has(-1): return
	_pilot._turn_bone(arms[0],Vector3.BACK,-_arms.x*amount)
	_pilot._turn_bone(arms[1],Vector3.BACK,_arms.x*amount)
	_pilot._turn_bone(arms[0],Vector3.RIGHT,_arms.y*amount)
	_pilot._turn_bone(arms[1],Vector3.RIGHT,_arms.y*amount)
	if not forearms.has(-1):
		_pilot._turn_bone(forearms[0],Vector3.BACK,_arms.z*amount)
		_pilot._turn_bone(forearms[1],Vector3.BACK,-_arms.z*amount)

## The plane cruises in place; the gimbal turns the stone a little toward
## where it points, and the swirl streams off it that way.
func _step_cradle(delta: float) -> void:
	_glide.bank = sin(_motion_time*0.4)*0.06
	_glide.pitch = sin(_motion_time*0.27)*0.03
	_plane.update(delta,_glide,0.0,Callable(),false)
	if _sweep:
		_sweep_clock += delta
	var way: Vector3 = (TARGETS[_target] as Vector3).normalized()
	if _sweep:
		var a := _sweep_clock*0.5
		way = Vector3(sin(a),sin(_sweep_clock*0.31)*0.8,-cos(a)).normalized()
	# The gimbal: the outer ring turns to face the way across, the inner
	# leans the stone's top toward it (TIP at most, level ways the most);
	# up or down, the stream does the pointing.
	var flat := Vector2(way.x,way.z)
	var heading := atan2(-way.x,-way.z) if flat.length() > 0.05 else _gimbal_outer.rotation.y
	_gimbal_outer.rotation.y = lerp_angle(_gimbal_outer.rotation.y,heading,1.0-exp(-3.0*delta))
	_gimbal_inner.rotation.x = lerpf(_gimbal_inner.rotation.x,-TIP*flat.length(),1.0-exp(-3.0*delta))
	var world_way: Vector3 = _plane.global_basis.orthonormalized()*way
	_stone.stream_dir = (_stone.global_basis.orthonormalized().inverse()*world_way).normalized()
	# The air sweeps the stream back past the tail (the plane's +Z).
	var drift: Vector3 = _stone.global_basis.orthonormalized().inverse()*(_plane.global_basis.orthonormalized()*Vector3(0.0,0.0,STREAM_LENGTH*DRIFT))
	for material: ShaderMaterial in [_stone._ribbon_material,_stone._motes_material]: material.set_shader_parameter("stream_drift",drift)
	_focus = _plane.position+_plane.basis*Vector3(0.0,0.3,-1.2)
	var behind := _plane.basis*Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))
	var at := _focus+behind*_distance
	_camera.global_transform = _world.global_transform*Transform3D(Basis.IDENTITY,at).looking_at(_focus)
	_camera.fov = 70.0

# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _view == "inspect":
			_stone.idle_turn = false
			_stone.turn_by(Vector2(event.relative.x*0.008,event.relative.y*0.006))
		else:
			_yaw -= event.relative.x*0.006
			_pitch = clampf(_pitch+event.relative.y*0.005,-1.2,1.4)
			_orbit_set = true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(0.6,_distance*0.92)
			_orbit_set = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(60.0,_distance*1.08)
			_orbit_set = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_BACK: _next_view()
			JOY_BUTTON_Y: _next_miniature()
			JOY_BUTTON_X: _next_target()
			JOY_BUTTON_A: if _view == "world": _set_view("inspect")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V, KEY_TAB: _next_view()
			KEY_M: _next_miniature()
			KEY_T: _next_target()
			KEY_P:
				_sweep = not _sweep
				_say()
			KEY_E: if _view == "world": _set_view("inspect")
			KEY_R: if _view == "inspect": _set_view("inspect")
			KEY_A: _auto_walk = not _auto_walk
			KEY_N: _set_night(not _night)
			KEY_I: _measure_cost()

func _next_view() -> void:
	_orbit_set = false
	_set_view(VIEWS[(VIEWS.find(_view)+1)%VIEWS.size()])

func _next_miniature() -> void:
	_stone.set_miniature(Minis.KINDS[(Minis.KINDS.find(_stone.kind)+1)%Minis.KINDS.size()])
	_cost = {}
	_set_view(_view)

func _next_target() -> void:
	_sweep = false
	_target = TARGET_ORDER[(TARGET_ORDER.find(_target)+1)%TARGET_ORDER.size()]
	_say()
