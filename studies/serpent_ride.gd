extends "res://studies/character_study.gd"
## Serpent ride: a greybox for running about on the back of the giant rune
## serpent (scripts/rune_serpent.gd, docs/scenic/rune-serpent.md) as it
## flies a slow loop of open sky. The serpent is the real one, with its
## look; everything round it is greybox: a grid floor far below, a start
## tower it passes close beside, a row of tall pillars it slaloms round, an
## arch it flies through, and small grey markers hung in the air along its
## way, so its speed reads.
##
## The pilot is the character study's (studies/character_study.gd, which
## this extends): the same motor (scripts/pilot_motor.gd), figure, steps,
## puffs, physics bridge, walker camera, pad, F1 numbers and F2 feel
## sliders. Only the ground is new.
##
## Its way (RIDE_ROUTE, about 2.4 km, some three and a half minutes a lap):
## north past the start tower, a 25° dive into a 22° climb, a long gentle
## curve west, a slalom round five pillars, south through the arch, a long
## gentle curve east, and back past the tower.
##
## Riding. Its skin between every two rings is a convex hull, rebuilt from
## the rings each frame (studies/serpent_back.gd), so the bridge stands him
## on its back, stops him at its flanks and hangs him from its shoulders'
## edges, as drawn. Each frame the serpent moves first, then he is carried:
##   - On it (stood, or hanging from it), he is held as a place on the body
##     (its arc back from the snout, across, up). The body's move at that
##     place since the last frame carries everything the motor keeps (his
##     feet, a lip, his pace, his facing: PilotMotor `carry`), so he goes
##     with it exactly, turned as it turns, up and down as it dives. Then
##     the motor steps as ever, on its back as it is now.
##   - In the air he keeps the velocity he left with, its carry included:
##     a frame moving at the body's velocity where he left it, so a jump
##     straight up comes down about where it left from while the body
##     turns or banks under him.
##   - Landing on it takes up its motion at once (his own pace kept), as a
##     platformer's moving ground does.
## The camera is carried with him, and takes up the body's turn over
## CAM_TURN, a boat's sway rather than a snap, while the sky, the floor,
## the pillars and the markers stream past at its speed.
##
## Falling off, more than LOST_DROP under where he left, the view fades
## softly and he is set back on its back where he last stood (or on the
## tower, if he never got on). F1 counts the falls.
##
## Keys: 1 on its neck behind the collar, 2 mid-back, 3 near the tail, 4 on
## the start tower with it coming (time the jump); R back to the start
## (the tower); F1 numbers (speed over the ground and on its back, its
## speed, what he is on, falls, the slope under him); F2 the feel's sliders.
## Flags, after --:
##   --girth=<x>         its girth times x (GIRTH: 1.5)
##   --ride-roll=<x>     the share of its roll kept while ridden (RIDE_ROLL)
##   --serpent-speed=<x> its pace times x
##   --no-glance         it never glances back at you
##   ./run-serpent-ride.command
##   godot --path . res://studies/serpent_ride.tscn -- --no-title
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const SerpentBack = preload("res://studies/serpent_back.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Variety = preload("res://scripts/seeded_variety.gd")

## Its way here: a closed cubic B-spline through these control points, each
## [point, weave share, pace share, veer share] as rune_serpent.gd's ROUTE.
## North (−z) up the east leg: level past the start tower (2), a 25° dive
## (4-8, five points in a line, so two stretches of it run straight), its
## bottom (9) and a 22° climb (10-14); a long gentle curve west (15-21,
## about 150 m round); south down the west leg in a slalom round PILLARS
## (23-27, ±36 m, so ±12 to 18 m at the curve), straight through the arch
## (30); a long gentle curve east (32-37) and home. The weave is held in by
## the tower, the pillars and the arch.
const RIDE_ROUTE := [
	[Vector3(150.0,140.0,330.0),0.3,1.0,0.0],
	[Vector3(150.0,140.0,280.0),0.1,1.0,0.0],
	[Vector3(150.0,140.0,230.0),0.1,1.0,0.0],
	[Vector3(150.0,140.0,180.0),0.1,1.0,0.0],
	[Vector3(150.0,140.0,130.0),0.4,1.0,0.0],
	[Vector3(150.0,119.0,85.0),0.5,1.0,0.0],
	[Vector3(150.0,98.0,40.0),0.5,1.0,0.0],
	[Vector3(150.0,77.0,-5.0),0.5,1.0,0.0],
	[Vector3(150.0,56.0,-50.0),0.5,1.0,0.0],
	[Vector3(150.0,49.0,-95.0),0.5,1.0,0.0],
	[Vector3(150.0,56.0,-140.0),0.5,1.0,0.0],
	[Vector3(150.0,74.0,-185.0),0.5,1.0,0.0],
	[Vector3(150.0,92.0,-230.0),0.5,1.0,0.0],
	[Vector3(150.0,110.0,-275.0),0.5,1.0,0.0],
	[Vector3(150.0,128.0,-320.0),0.5,1.0,0.0],
	[Vector3(150.0,140.0,-410.0),0.6,1.0,0.0],
	[Vector3(130.0,140.0,-485.0),0.6,1.0,0.0],
	[Vector3(75.0,140.0,-540.0),0.6,1.0,0.0],
	[Vector3(0.0,140.0,-560.0),0.6,1.0,0.0],
	[Vector3(-75.0,140.0,-540.0),0.6,1.0,0.0],
	[Vector3(-130.0,140.0,-485.0),0.6,1.0,0.0],
	[Vector3(-150.0,140.0,-410.0),0.4,1.0,0.0],
	[Vector3(-150.0,140.0,-360.0),0.25,1.0,0.0],
	[Vector3(-114.0,140.0,-300.0),0.25,1.0,0.0],
	[Vector3(-186.0,140.0,-220.0),0.25,1.0,0.0],
	[Vector3(-114.0,140.0,-140.0),0.25,1.0,0.0],
	[Vector3(-186.0,140.0,-60.0),0.25,1.0,0.0],
	[Vector3(-114.0,140.0,20.0),0.25,1.0,0.0],
	[Vector3(-150.0,140.0,90.0),0.2,1.0,0.0],
	[Vector3(-150.0,140.0,150.0),0.2,1.0,0.0],
	[Vector3(-150.0,140.0,210.0),0.2,1.0,0.0],
	[Vector3(-150.0,140.0,270.0),0.4,1.0,0.0],
	[Vector3(-150.0,140.0,330.0),0.6,1.0,0.0],
	[Vector3(-130.0,140.0,405.0),0.6,1.0,0.0],
	[Vector3(-75.0,140.0,460.0),0.6,1.0,0.0],
	[Vector3(0.0,140.0,480.0),0.6,1.0,0.0],
	[Vector3(75.0,140.0,460.0),0.6,1.0,0.0],
	[Vector3(130.0,140.0,405.0),0.6,1.0,0.0],
]
## Places on its way, by control point.
const RIDE_MARKS := {"tower":2,"dive":5,"bottom":9,"climb":11,"north":18,"pillars":23,"arch":30,"south":35}

## The floor far below: its height (m), its grid's cell (m: a line every
## cell, a stronger one every five) and its reach either way from the
## middle (m).
const FLOOR_Y := 0.0
const FLOOR_CELL := 10.0
const FLOOR_HALF := 2400.0
## The slalom's pillars (x, z), on the west leg's middle line, each inside
## a bend of the slalom; their half width and their top (m).
const PILLARS := [Vector2(-150.0,-296.7),Vector2(-150.0,-220.0),Vector2(-150.0,-140.0),Vector2(-150.0,-60.0),Vector2(-150.0,18.3)]
const PILLAR_HALF := 2.5
const PILLAR_TOP := 215.0
## The arch at its mark: the gap from its flank at its widest (and its
## weave) to each post, the posts' half width, how far over its back the
## lintel's underside is (high enough that the camera passes under it
## too), and the lintel's depth (m).
const ARCH_GAP := 5.0
const ARCH_POST := 2.5
const ARCH_CLEAR := 9.0
const ARCH_DEPTH := 5.0
## The start tower, beside its way at the tower mark: its half width, the
## gap kept from its flank at its widest and its weave as it passes, and
## how far the tower's top stands over its back's crest (m).
const TOWER_HALF := 4.0
const TOWER_GAP := 1.2
const TOWER_RISE := 1.2
## Set on the tower, the serpent's head is set down this far (m) back
## along its way from the tower: its head comes by in about five seconds,
## its middle in about eight.
const TOWER_LEAD := 60.0
## Where keys 1, 2 and 3 set him on its back (m back from the snout): just
## behind the collar on the neck, mid-back, near the tail.
const NECK_AT := 11.0
const MID_AT := 45.0
const TAIL_AT := 70.0
## Its girth, times rune_serpent.gd's (--girth=): 1.5 makes its back's top
## 1.9 m across and 5.5 m to the shoulders' edges (1: 1.3 and 3.7 m).
const GIRTH := 1.5
## The share of its roll into turns it keeps while ridden (--ride-roll=),
## and the seconds after he leaves its back it still counts as ridden.
const RIDE_ROLL := 0.4
const RIDDEN_AFTER := 3.0
## Falling: this far (m) under the frame he left in, he is lost. The fade
## out, the beat held, the fade in (s); its colour, the sky's horizon.
const LOST_DROP := 14.0
const FADE_OUT := 0.35
const FADE_HOLD := 0.2
const FADE_IN := 0.5
const FADE_COLOUR := Color("dfe6e4")
## The camera takes up the body's turn over this many seconds.
const CAM_TURN := 0.6
## How far the eye sees (m): the floor and the pillars across the loop.
const FAR := 5000.0
## Markers hung in the air along its way, so its speed reads: one every
## MARKER_EVERY m, either side in turn, MARKER_OFF m out (least, most) and
## up to MARKER_RISE m over or under its way; MARKER_SIZE m through; none
## within MARKER_CLEAR m of a pillar, the arch or the tower.
const MARKER_EVERY := 24.0
const MARKER_OFF := Vector2(16.0,34.0)
const MARKER_RISE := 7.0
const MARKER_SIZE := 1.2
const MARKER_CLEAR := 22.0

## The serpent, and its body as ground.
var serpent: Node3D
var back: SerpentBack
var girth := GIRTH
var ride_roll := RIDE_ROLL
var glance := true
## What he is on: "serpent" (stood on it or hanging from it), "still"
## (standing ground: the tower), "air".
var riding_on := "still"
## His place on the body (arc, across, up) while on it, and the last place
## he stood on it; whether he has been on it since he was last set down.
var anchor := Vector3.ZERO
var last_on := Vector3(MID_AT,0.0,0.0)
var rode := false
## Times he has fallen off and been set back.
var falls := 0
## The frame he left in, in the air (m/s), and his feet's carry on the
## body this frame (m/s).
var air_v := Vector3.ZERO
var carry_v := Vector3.ZERO
## The start tower's top middle, the way across to its way (x, z), and
## the way he is set facing on it (toward the serpent as it comes).
var tower_top := Vector3.ZERO
var tower_out := Vector2(1.0,0.0)
var tower_face := Vector2(1.0,0.0)
## The serpent watches for these (rune_serpent.gd `watcher`): never flying.
var flying := false
var plane: Variant = null
var _air_ref := 0.0
var _turn_owed := 0.0
var _since_ridden := 99.0
var _fade_t := -1.0
var _set_back := false
var _fade: ColorRect
var _arch_at := Vector3.ZERO

func _init() -> void:
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--girth="): girth = clampf(float(arg.get_slice("=",1)),0.5,3.0)
		elif arg.begins_with("--ride-roll="): ride_roll = clampf(float(arg.get_slice("=",1)),0.0,1.0)
		elif arg == "--no-glance": glance = false
	# The floor is a backstop under everything; the fall is caught well
	# before (LOST_DROP).
	lost = FLOOR_Y+5.0

# --- The sky ------------------------------------------------------------------------

func _build_light() -> void:
	super._build_light()
	camera.far = FAR

func _build_room() -> void:
	_build_serpent()
	_build_floor()
	_build_tower()
	for p: Vector2 in PILLARS: _box(Rect2(p.x-PILLAR_HALF,p.y-PILLAR_HALF,PILLAR_HALF*2.0,PILLAR_HALF*2.0),FLOOR_Y,PILLAR_TOP,"grey")
	_build_arch()
	_build_markers()
	_build_fade()

## The real serpent on this scene's way, driven from `tick` (its own
## process off), its capsules left out (its back's hulls stand in).
func _build_serpent() -> void:
	serpent = RuneSerpent.new()
	serpent.route = RIDE_ROUTE
	serpent.route_marks = RIDE_MARKS
	serpent.start_mark = "tower"
	serpent.girth = girth
	serpent.solid = false
	serpent.look_back = glance
	add_child(serpent)
	serpent.setup(self)
	serpent.set_process(false)
	serpent.set_physics_process(false)
	back = SerpentBack.new(serpent,self)

func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(FLOOR_HALF*2.0,2.0,FLOOR_HALF*2.0)
	shape.shape = slab
	shape.position = Vector3(0.0,FLOOR_Y-1.0,0.0)
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(FLOOR_HALF*2.0,FLOOR_HALF*2.0)
	mesh.mesh = plane_mesh
	mesh.position = Vector3(0.0,FLOOR_Y,0.0)
	var grid := ShaderMaterial.new()
	grid.shader = GRID
	grid.set_shader_parameter("tint",COLOURS.floor)
	grid.set_shader_parameter("cell",FLOOR_CELL)
	mesh.material_override = grid
	floor_body.add_child(mesh)
	add_child(floor_body)

## Where its body passes at route arc `at`: its path with the weave (as
## its rings pass through it), the way along it and across it (flat).
func _way_at(at: float) -> Array:
	var p: Vector3 = serpent._path(at)[0]
	var way: Vector3 = serpent.route_point(at+2.0)-serpent.route_point(at-2.0)
	way = Vector3(way.x,0.0,way.z).normalized()
	return [p,way,way.cross(Vector3.UP).normalized()]

## Its body's half width at its widest (m) and its weave's reach at `at`.
func _clear_at(at: float) -> float:
	return back.half_width(MID_AT)+serpent.weave_reach()*serpent.route_shares(at).x

## The start tower beside its way, on the left as it comes, its top a lip
## a little over its back.
func _build_tower() -> void:
	var at: float = serpent.marks()["tower"]
	var w := _way_at(at)
	var p: Vector3 = w[0]
	var right: Vector3 = w[2]
	var middle := p-right*(_clear_at(at)+TOWER_GAP+TOWER_HALF)
	tower_top = Vector3(middle.x,p.y+back.top(MID_AT).z+TOWER_RISE,middle.z)
	var way: Vector3 = w[1]
	tower_out = Vector2(right.x,right.z)
	tower_face = (tower_out-Vector2(way.x,way.z)*0.8).normalized()
	_box(Rect2(middle.x-TOWER_HALF,middle.z-TOWER_HALF,TOWER_HALF*2.0,TOWER_HALF*2.0),FLOOR_Y,tower_top.y,"lip")
	_label(tower_top+Vector3(0.0,0.5,0.0)-right*2.0,"START · 4 · R",36)

## The arch at its mark: two posts either side of its way and a lintel
## across, high over its back.
func _build_arch() -> void:
	var at: float = serpent.marks()["arch"]
	var w := _way_at(at)
	var p: Vector3 = w[0]
	var right: Vector3 = w[2]
	var out := _clear_at(at)+ARCH_GAP+ARCH_POST
	var under := p.y+back.top(MID_AT).z+ARCH_CLEAR
	var lintel := ARCH_DEPTH
	var yaw := rad_to_deg(atan2(-right.z,right.x))
	for side: float in [-1.0,1.0]:
		var foot := p+right*side*out
		_obox(Vector3(foot.x,(FLOOR_Y+under+lintel)*0.5,foot.z),Vector3(ARCH_POST*2.0,under+lintel-FLOOR_Y,ARCH_POST*2.0),yaw,"grey")
	_obox(Vector3(p.x,under+lintel*0.5,p.z),Vector3((out+ARCH_POST)*2.0,lintel,ARCH_POST*2.0),yaw,"grey")
	_arch_at = Vector3(p.x,under,p.z)

## Small grey markers hung in the air along its way, either side in turn.
func _build_markers() -> void:
	var places: Array[Vector3] = []
	var keep_off: Array[Vector2] = [Vector2(tower_top.x,tower_top.z),Vector2(_arch_at.x,_arch_at.z)]
	for p: Vector2 in PILLARS: keep_off.append(p)
	var at := 0.0
	var side := 1.0
	var i := 0
	while at < serpent.route_length:
		var w := _way_at(at)
		var p: Vector3 = w[0]
		var out := lerpf(MARKER_OFF.x,MARKER_OFF.y,Variety.unit([i,3]))
		var spot: Vector3 = p+(w[2] as Vector3)*side*out+Vector3.UP*(Variety.unit([i,5])*2.0-1.0)*MARKER_RISE
		var clear := true
		for k: Vector2 in keep_off:
			if Vector2(spot.x,spot.z).distance_to(k) < MARKER_CLEAR: clear = false
		if clear: places.append(spot)
		at += MARKER_EVERY
		side = -side
		i += 1
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*MARKER_SIZE
	multi.mesh = cube
	multi.instance_count = places.size()
	for n in range(places.size()):
		multi.set_instance_transform(n,Transform3D(Basis(Vector3.UP,Variety.unit([n,7])*TAU),places[n]))
	var markers := MultiMeshInstance3D.new()
	markers.name = "Markers"
	markers.multimesh = multi
	markers.material_override = _material("dark")
	markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(markers)

## A soft full-screen fade for a fall.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(FADE_COLOUR,0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

# --- Setting him down ---------------------------------------------------------------

## The start: on the tower, the serpent coming.
func respawn() -> void:
	to_tower()

## 1 on its neck behind the collar, 2 mid-back, 3 near the tail, 4 the
## tower.
func go_to(key: int) -> void:
	match key:
		1: set_on_back(NECK_AT)
		2: set_on_back(MID_AT)
		3: set_on_back(TAIL_AT)
		4: to_tower()

## On the tower's top, facing the serpent as it comes, its head TOWER_LEAD m
## off.
func to_tower() -> void:
	serpent.place(fposmod(float(serpent.marks()["tower"])-TOWER_LEAD,serpent.route_length))
	back.reset()
	place(tower_top,tower_face)
	_still_now()
	rode = false
	_since_ridden = 99.0

## On the middle of its back's top at arc `a`, facing its head.
func set_on_back(a: float) -> void:
	var c := back.top(a)
	var at := back.place(c)
	place(at,back.ahead(a))
	riding_on = "serpent"
	anchor = back.locate(at,a)
	last_on = anchor
	rode = true
	_since_ridden = 0.0
	air_v = Vector3.ZERO
	var along := back.frame(a).basis.z.normalized()
	carry_v = along*float(serpent.speed())
	_turn_owed = 0.0

func _still_now() -> void:
	riding_on = "still"
	air_v = Vector3.ZERO
	carry_v = Vector3.ZERO
	_turn_owed = 0.0

# --- A frame ------------------------------------------------------------------------

## The serpent moves on; he is carried with it (or with the frame he left
## it in); then the character study's own frame (the motor's step over
## what is there now, the figure, its puffs and steps, the camera); then
## what he stands on now, and whether he has fallen.
func tick(delta: float) -> void:
	var step := minf(delta,RuneSerpent.MAX_STEP)
	serpent.bank_share = ride_roll if _since_ridden < RIDDEN_AFTER else 1.0
	serpent.advance(step)
	back.update()
	_carry(step)
	var take := _turn_owed*(1.0-exp(-delta/CAM_TURN))
	_yaw += take
	_turn_owed -= take
	super.tick(delta)
	_contact(delta)
	_fall(delta)

## Carried over `step`: on it, by the body's move where he is; in the air,
## by the frame he left in (slid round what stands in the way, as his own
## steps are).
func _carry(step: float) -> void:
	if step <= 0.0: return
	var was := motor.feet
	if riding_on == "serpent":
		var turn := back.turn(anchor.x)
		motor.carry(back.moved(anchor),turn)
		carry_v = (motor.feet-was)/step
		_carry_camera(was,motor.feet-was,turn)
	elif riding_on == "air" and air_v != Vector3.ZERO:
		var go := air_v*step
		var slid: Vector3 = ground.slide(was,Vector2(go.x,go.z))
		var moved := Vector3(slid.x-was.x,go.y,slid.z-was.z)
		motor.carry(Transform3D(Basis.IDENTITY,moved),0.0)
		_air_ref += go.y
		_carry_camera(was,moved,0.0)

## The camera's follow point carried with him (moved, and turned about
## him), the turn owed to its yaw, taken up over CAM_TURN.
func _carry_camera(about: Vector3, moved: Vector3, turn: float) -> void:
	var pivot := Vector3(_cam_at.x,_cam_y,_cam_at.y)
	pivot = about+moved+(pivot-about).rotated(Vector3.UP,turn)
	_cam_at = Vector2(pivot.x,pivot.z)
	_cam_y = pivot.y
	var pace := Vector3(_cam_pace.x,0.0,_cam_pace.y).rotated(Vector3.UP,turn)
	_cam_pace = Vector2(pace.x,pace.z)
	_turn_owed += turn

## What he is on after the step: its back (held as a place on it), still
## ground, or the air (leaving its back, the frame he leaves in is its
## carry).
func _contact(delta: float) -> void:
	var was := riding_on
	if motor.on_ledge():
		var on_lip := motor.lip-Vector3(motor.lip_out.x,0.0,motor.lip_out.y)*0.1
		riding_on = "serpent" if _rid_under(on_lip) == back.rid() else "still"
	elif motor.grounded: riding_on = "serpent" if _rid_under(motor.feet) == back.rid() else "still"
	else: riding_on = "air"
	match riding_on:
		"serpent":
			anchor = back.locate(motor.lip if motor.on_ledge() else motor.feet,anchor.x if was == "serpent" else -1.0)
			if motor.grounded: last_on = anchor
			rode = true
			_since_ridden = 0.0
			air_v = Vector3.ZERO
		"air":
			if was != "air":
				air_v = carry_v if was == "serpent" else Vector3.ZERO
				_air_ref = motor.feet.y
			_since_ridden += delta
		_:
			air_v = Vector3.ZERO
			carry_v = Vector3.ZERO
			_since_ridden += delta

## What is right under `p` (its body's RID), or none.
func _rid_under(p: Vector3) -> RID:
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*0.35,ground.mask)
	var hit := ground.space.intersect_ray(ray)
	return hit.rid if not hit.is_empty() else RID()

## Lost (LOST_DROP under the frame he left in): the view fades out, he is
## set back on its back where he last stood (on the tower if he never got
## on), and it fades in.
func _fall(delta: float) -> void:
	if _fade_t < 0.0:
		if riding_on == "air" and _air_ref-motor.feet.y > LOST_DROP:
			falls += 1
			_fade_t = 0.0
			_set_back = false
		return
	_fade_t += delta
	var a := 1.0
	if _fade_t < FADE_OUT: a = smoothstep(0.0,1.0,_fade_t/FADE_OUT)
	elif _fade_t > FADE_OUT+FADE_HOLD: a = 1.0-smoothstep(0.0,1.0,(_fade_t-FADE_OUT-FADE_HOLD)/FADE_IN)
	if not _set_back and _fade_t >= FADE_OUT+FADE_HOLD*0.5:
		_set_back = true
		if rode: set_on_back(clampf(last_on.x,NECK_AT,TAIL_AT))
		else: to_tower()
	_fade.color = Color(FADE_COLOUR,a)
	if _fade_t >= FADE_OUT+FADE_HOLD+FADE_IN:
		_fade_t = -1.0
		_fade.color = Color(FADE_COLOUR,0.0)

## Whether he is being set back after a fall.
func fading() -> bool:
	return _fade_t >= 0.0

# --- Numbers ------------------------------------------------------------------------

## His velocity over the ground (m/s): his own and the frame he is in.
func ground_velocity() -> Vector3:
	var frame := carry_v if riding_on == "serpent" else (air_v if riding_on == "air" else Vector3.ZERO)
	return frame+motor.velocity

func _show_hud() -> void:
	if not _hud.visible: return
	var over := ground_velocity()
	var where := "on the tower"
	if riding_on == "serpent": where = "on its back · %.1f m from the snout, %+.2f across" % [anchor.x,anchor.y]
	elif riding_on == "air": where = "in the air · %.1f m under where he left" % maxf(_air_ref-motor.feet.y,0.0)
	var lines := PackedStringArray([
		"on        %s" % where,
		"over the ground %.2f m/s" % Vector2(over.x,over.z).length(),
		"on its back     %.2f m/s" % motor.speed(),
		"serpent         %.2f m/s" % serpent.speed(),
		"state     %s" % state(),
		("slope     %.0f°" % motor.steepness()) if motor.grounded else "slope     -",
		"surf      %.2f m/s%s · top %.2f m/s" % [motor.speed() if motor.move == "slide" else 0.0,"  (surfing)" if motor.move == "slide" else "",slide_top],
		"falls     %d" % falls,
		"girth %.1f× · roll kept %.2f while ridden (now %.2f rad) · %s" % [girth,ride_roll,serpent.spring(RuneSerpent.S_BANK),serpent.mode],
	])
	if long_chain > 0: lines.append("long chain %d · fastest %.2f m/s" % [long_chain,long_chain_top])
	_hud.text = "\n".join(lines)

func _hint_text() -> String:
	return "WASD run · Space jump (on landing: pump) · Shift/C crouch: at a run slide, + Space long jump; on a slope (its back in the dive) surf · X twirl · 1 neck · 2 mid-back · 3 tail · 4 the tower (time the jump) · R start · F1 numbers · F2 feel · Esc mouse"

func _unhandled_input(event: InputEvent) -> void:
	# No recordings here: a replay can't put the serpent back where it was.
	if event is InputEventKey and (event as InputEventKey).keycode in [KEY_F5,KEY_F6,KEY_F7,KEY_F8]: return
	super._unhandled_input(event)
