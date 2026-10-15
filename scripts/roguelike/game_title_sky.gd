extends SubViewportContainer
## The title's second shot: the sunlit sky aqueduct (studies/aqueduct_isle.tscn,
## "The Aqueduct of Veyl"), the world above the dark city the run starts in,
## stood whole in its own viewport and orbited by a slow high camera as the
## old title orbited it (scripts/kit_isle/front_door.gd).
##
## Building it takes seconds and cannot be spread over frames, so the title
## fades to black first (game_title.gd), calls `build`, and fades the shot up.
## The isle is run as a scene with no title, no pilot input and no HUD; the
## underground flags of the launch are left off its args while it builds, or
## it would dress itself in the dark.
const SCENE := "res://studies/aqueduct_isle.tscn"
const LaunchArgs = preload("res://scripts/launch_args.gd")
## The orbit (front_door.gd's): the eye POLAR rad down from straight above
## the isle's middle, LIFT m over its top, DISTANCE times its half-span (at
## least NEAR m), turning SPEED rad/s. Looser here: lower and a little nearer.
const POLAR := 1.28
const LIFT := 8.0
const DISTANCE := 1.0
const NEAR := 70.0
const SPEED := TAU/60.0*0.22
const FOV := 50.0

signal ready_shot

var isle: Node3D
var viewport: SubViewport
var built_ms := 0
var orbit_middle := Vector3.ZERO
var orbit_distance := NEAR
var orbit_yaw := 0.0
var _live := false

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

## Stands the isle (blocking) and frames the orbit. `yaw0` where the sweep starts.
func build(yaw0 := 0.0) -> void:
	var began := Time.get_ticks_msec()
	var kept: Variant = LaunchArgs.override
	var args := PackedStringArray()
	for a: String in LaunchArgs.user_args():
		if a == "--underground" or a.begins_with("--underground"): continue
		args.append(a)
	if not "--no-title" in args: args.append("--no-title")
	LaunchArgs.set_override(args)
	var packed: PackedScene = load(SCENE)
	isle = packed.instantiate()
	isle.set_meta("no_title",true)
	viewport.add_child(isle)
	LaunchArgs.set_override(kept)
	# Stood in its _ready; the isle is up.
	isle.scripted = true
	for child in isle.get_children():
		if child is CanvasLayer: child.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_frame(yaw0)
	_live = true
	_orbit(0.0)
	built_ms = Time.get_ticks_msec()-began
	print("game title sky: aqueduct isle stood in %d ms" % built_ms)
	ready_shot.emit()

func _frame(yaw0: float) -> void:
	var bounds := AABB()
	var first := true
	var art: Node = isle.get("art")
	if art != null:
		for mesh: MeshInstance3D in art.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null: continue
			var box: AABB = mesh.global_transform*mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
	var top: float = isle.isle_top()
	var start: Vector3 = isle.start
	if first:
		orbit_middle = Vector3(start.x,top,start.z)
	else:
		var centre := bounds.get_center()
		orbit_middle = Vector3(centre.x,top,centre.z)
		orbit_distance = maxf(NEAR,maxf(bounds.size.x,bounds.size.z)*0.5*DISTANCE)
	orbit_yaw = atan2(start.x-orbit_middle.x,start.z-orbit_middle.z)+yaw0

func _process(delta: float) -> void:
	if _live: _orbit(delta)

func _orbit(delta: float) -> void:
	orbit_yaw = wrapf(orbit_yaw+SPEED*delta,-PI,PI)
	var at := orbit_middle+Vector3.UP*LIFT
	var eye := at+Vector3(sin(POLAR)*sin(orbit_yaw),cos(POLAR),sin(POLAR)*cos(orbit_yaw))*orbit_distance
	var camera: Camera3D = isle.camera
	camera.fov = FOV
	camera.look_at_from_position(eye,at)
