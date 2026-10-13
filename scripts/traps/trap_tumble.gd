extends "res://scripts/traps/trap.gd"
## The Tumbling Block (the user's idea, docs/design/roguelike/traps-round4-giants.md;
## built to the contract in scripts/traps/trap.gd): a giant stone cube,
## six-odd pilot-heights a side, hung over open void between two decks
## (nothing under it: the yard lays no floor in its lane, `open_below`) and
## turning about a horizontal axis through its middle (across the route, x).
## Its top moves back toward the entry (`dir` +1), so the face he stands on
## tips away from the way out. He is carried round with it (`motor.carry`
## with the block's own transform delta) and the rest is the motor's.
##
## The rhythm (`lurch` > 0, the default): a face rests flat (`rest` s), then
## tips slowly to `tip` (between the motor's SLOPE_SLOW and SLIDE_AUTO: a
## slope he can stand on and fight up) over `tip_time` s, then LURCHES the
## rest of the quarter turn in `lurch` s (about a small hop's airtime) and
## stops dead. The tell, `tell` s before the lurch: the block shudders (its
## look shakes, the colliders don't), dust pours off its top edges, every
## face warms to orange, and it sounds "grind"; "lurch" as it goes, "slam"
## as it stops. The pace ramps the longer he rides (`ramp` a second, up to
## `ramp_top`): shorter rests, quicker tips.
##
## What it does to him:
## - Slick stone: past `slick` the face slides him down its fall line,
##   gaining `slip` m/s² by how steep it is (to `slip_top`), unless he moves
##   uphill faster than `grip`; walking up it, the slide bleeds away. Stood
##   still he is slid to the leading edge in a few seconds.
## - The lurch throws: grounded on a face that tips past `throw_at` while it
##   lurches, he is knocked off (`motor.knock`, tumbling: no ledge catch) at
##   `throw` x the stone's own velocity under him; hanging from a lip whose
##   face tips past it, he is shaken loose (`motor.toss`). Grounded on the
##   block when it stops dead, he is jolted on at `jolt` x the stone's
##   velocity (a knock if over a walk's share). So: in the air through the
##   lurch (jump at the end of the shudder), or in the pocket.
## - Face changes are a jump or a climb: `bevel` 0 by default (a knife-edge
##   cube, the round-4 1 m chamfer that let him walk across is a knob), and
##   the face change is the lurch.
## - Features on the faces, turning into him: face 0 a sweeper, a low bar
##   (`wall_h`) that runs along the face toward the leading edge (`sweep`
##   m/s) while it is up and shoves him off unless he hops it; face 3 the
##   pocket, a rebate at its trailing edge (`pocket` wide, a plate deep) he
##   can drop into: the slick and the lurch don't move him there, but it
##   carries him round, and after the lurch it is a step a hop under the new
##   top's leading lip (hop up, or hang and climb); face 2 the prize (a rune
##   marker, picked up standing by it while face 2 is up: two lurches ridden)
##   and two low walls; face 1 a raised step over its trailing half, whose
##   lip is a handhold. The ends are plain walls (wall kick).
##
## `lurch` 0 is round 4's steady roll: `spin` rad/s, or 90 degree turns with
## a `pause` between. Optional `yaw` (rad/s), a slow turn about the vertical.
##
## Alive and aggressive (the Tumble Run's round 2; every one off at its
## default, so the single `tumble` lane is as it was):
## - `wake` s: he lands on it (after `wake_off` s off it) and it wakes: a
##   short shudder and "wake", and a rest with more than `wake` s left is cut
##   to `wake`, so the tip (the real tell) starts soon after.
## - `feint` s: a fake-out shudder (shake, dust, "grind") that ends at each
##   rest's middle; the face never tips, so the tip stays the honest read.
## - `double`: quarter turns chained onto each lurch: after the slam it rests
##   `chain_rest` s, then tips over `tell` s (all of it shuddering) and
##   lurches again.
## - `dip` m: the slam drops the block and it heaves back up.
## - Motion, carrying him with it (the transform delta): `bob` m up and down
##   over `bob_time` s, `drift` m along its axis (x, toward and away from its
##   neighbours) over `drift_time` s, `sway` rad of yaw wobble over
##   `sway_time` s; `motion_phase` (cycles) offsets them. `middle()` is the
##   centre as it moves.
## - `glow` (0 to 1): the faces glow with the tell, not only warm.
## - The ferry (the Tumble Run's round 3): `shuttle` m along the route (z,
##   + back toward the entry), over `shuttle_time` s: it holds at each end
##   `shuttle_hold` of the cycle and slides between, back at
##   `shuttle_phase` (cycles) 0; `shuttle_ease` 1 eases out of and into its
##   ends, -1 lunges (quickest at its ends, slowest midway, stopping dead
##   with a "dock"). `shuttle_wave()` is +1 back, -1 on. Jumping or
##   stepping off it, he keeps its slide's velocity (`ferry_velocity`);
##   landing on it, that much of his is the ground's (it carries him).
## Cost 4, over the void 5.
##
## Sizes from the pilot: `size` 6.5 of his heights (the body's HEAD x the
## wanderer's size), the plate (pocket depth) from his small jump, the pocket
## (later a step he hops) his small jump, `lurch` a small hop's airtime on
## the flat, the rest and tip from how long a face takes to walk, the angles
## from the motor's own slope angles, `gap` a share of a running small hop's
## reach, the features from his jumps.
const Ground = preload("res://scripts/pilot_physics_ground.gd")
const STONES := [Color(0.42,0.41,0.4),Color(0.46,0.43,0.38),Color(0.38,0.41,0.43),Color(0.43,0.39,0.41)]
const REACH_SHARE := 0.6
const SPIN_WALK := 0.6
## The faces the features are on.
const SWEEP_FACE := 0
const STEP_FACE := 1
const PRIZE_FACE := 2
const POCKET_FACE := 3
## The sweeper bar's thickness along the face (m).
const BAR := 0.4

var body: StaticBody3D
## The meshes (shaken by the tell); the colliders are the body's.
var look: Node3D
## The block's turn about its axis (x), its yaw, and where in the pause it is.
var roll := 0.0
var yaw := 0.0
var _turned := 0.0
var _pausing := 0.0
## The rhythm: "rest", "tip", "lurch" (or "roll", the steady mode), the
## seconds in it, and the roll the resting face sits at.
var phase := "rest"
var phase_t := 0.0
var _base := 0.0
var _told := false
## The ramp: the rhythm's pace, 1 to `ramp_top`.
var pace := 1.0
## Seconds he has ridden it (since a reset), quarter turns lurched, the prize.
var riding_time := 0.0
var lurches := 0
var prize_taken := false
## How he last left it: "" , "thrown" (the lurch), "jolted" (its stop),
## "shaken" (off a lip), and how often.
var put_off := ""
var thrown := 0
## The slide on the slick stone (m/s down the fall line).
var slide := 0.0
## The sweeper's place along face 0 (face-local z).
var sweep := 0.0
var _sweep_shape: CollisionShape3D
var _sweep_mesh: MeshInstance3D
var _last_mesh: MeshInstance3D
var _prize: MeshInstance3D
var _dust: Array[CPUParticles3D] = []
var _plate_mats: Array[StandardMaterial3D] = []
var _shake_t := 0.0
## Round 2: the motion clock, the chained turns done this cycle, seconds
## since the slam (the dip, the slam's dust), off him, since he woke it.
var _clock := 0.0
var _chain := 0
var _slam_t := INF
var _off_t := INF
var _woke_t := INF
var _was_on := false
var _dock_t := INF
## Its middle's velocity (world, m/s) from its ferry and drift (none
## without a ferry): what he keeps leaving it into the air.
var ferry_velocity := Vector3.ZERO
var feints := 0
var wakes := 0

func _init() -> void:
	super()
	trap_name = "tumble"
	cost = 4
	under = "void"
	verbs = PackedStringArray(["jump","walk","climb"])

func defaults() -> Dictionary:
	var p := pilot()
	var height: float = Ground.HEAD*WorldScale.wanderer
	var size := height*6.5
	var rise := sqrt(2.0*float(p.jumps[0])/p.gravity)
	var reach := p.run*2.0*rise
	# A small hop on the flat: up at his gravity, down at FALL times it.
	var hop := rise*(1.0+1.0/sqrt(p.fall))
	var across := size/p.walk
	return {
		"size":size,"plate":float(p.jumps[0])*0.9,"bevel":0.0,
		"spin":SPIN_WALK*p.walk/size,"dir":1.0,"pause":0.0,"yaw":0.0,
		"rest":across*0.75,"tip":deg_to_rad(lerpf(PilotMotor.SLOPE_SLOW,PilotMotor.SLIDE_AUTO,0.5)),
		"tip_time":across,"lurch":hop,"tell":hop*1.75,
		"slick":deg_to_rad(PilotMotor.SLOPE_SLOW*0.6),"slip":p.gravity*0.6,"slip_top":p.run,"grip":p.walk*0.25,
		"throw_at":deg_to_rad(PilotMotor.SLIDE_AUTO),"throw":0.8,"jolt":0.35,
		"ramp":0.015,"ramp_top":1.8,
		"gap":reach*REACH_SHARE,"top":0.0,"floor":false,
		"wall_h":float(p.jumps[0])*0.7,"step_h":float(p.jumps[0])*0.9,
		"pocket":float(p.jumps[0]),"sweep":p.walk*0.4,"prize":true,
		"shake":height*0.04,
		"wake":0.0,"wake_off":hop*3.0,"feint":0.0,"double":0,"chain_rest":hop,"dip":0.0,
		"bob":0.0,"bob_time":across*1.5,"drift":0.0,"drift_time":across*2.0,
		"sway":0.0,"sway_time":across*1.2,"motion_phase":0.0,"glow":0.0,
		"shuttle":0.0,"shuttle_time":across*2.6,"shuttle_hold":0.2,"shuttle_phase":0.0,"shuttle_ease":1.0,
	}

func length() -> float:
	return float(knob("size"))+2.0*float(knob("gap"))

func footprint() -> Rect2:
	var s := float(knob("size"))
	return Rect2(-s*0.5,-length(),s,length())

## No floor a layer down in its lane (the yard asks): a fall is the void.
func open_below() -> bool:
	return not bool(knob("floor"))

## The block's centre in the trap's frame.
func centre() -> Vector3:
	return Vector3(0.0,float(knob("top"))-float(knob("size"))*0.5,-(float(knob("gap"))+float(knob("size"))*0.5))

## Where the middle of the flat top is (world), at roll 0.
func top_point() -> Vector3:
	return to_global(centre()+Vector3(0.0,float(knob("size"))*0.5,0.0))

static func _face_basis(k: int) -> Basis:
	return Basis(Vector3.RIGHT,float(k)*PI*0.5)

## One box of the block, in face `k`'s frame (face-local centre and size):
## its collider on the body, its mesh on the look.
func _box(centre_l: Vector3, size: Vector3, k: int, mat: StandardMaterial3D, turn := 0.0) -> CollisionShape3D:
	var basis := _face_basis(k)*Basis(Vector3.RIGHT,turn)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = Transform3D(basis,_face_basis(k)*centre_l)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.transform = shape.transform
	mesh.material_override = mat
	look.add_child(mesh)
	_last_mesh = mesh
	return shape

func _mat(colour: Color, plate := false) -> StandardMaterial3D:
	var m := paint(colour)
	if plate: _plate_mats.append(m)
	return m

func build() -> void:
	body = StaticBody3D.new()
	body.transform = Transform3D(Basis.IDENTITY,centre())
	add_child(body)
	look = Node3D.new()
	body.add_child(look)
	var s := float(knob("size"))
	var half := s*0.5
	var pl := float(knob("plate"))
	var bev := clampf(float(knob("bevel")),0.0,pl*2.0)
	var pocket := clampf(float(knob("pocket")),0.0,half)
	# The core: the cube less its plates, full width across the axis.
	var cshape := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(s,s-2.0*pl,s-2.0*pl)
	cshape.shape = cbox
	body.add_child(cshape)
	var cmesh := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = cbox.size
	cmesh.mesh = cbm
	cmesh.material_override = paint(Color(0.3,0.3,0.32))
	look.add_child(cmesh)
	var wall_h := float(knob("wall_h"))
	var step_h := float(knob("step_h"))
	for k in range(4):
		var m := _mat(STONES[k],true)
		var ruin := _mat(STONES[k].darkened(0.2))
		# Plate along the face, from its trailing end (-z) to its leading
		# (+z). The pocket's face starts it `pocket` in; the face before it
		# (whose leading end is that corner) stops a plate short, so the
		# pocket is open on top and to the trailing side.
		var from := -(half-bev)
		var to := half-bev
		if pocket > 0.0 and k == POCKET_FACE: from = -half+pocket
		if pocket > 0.0 and k == (POCKET_FACE+3)%4: to = minf(to,half-pl)
		_box(Vector3(0.0,half-pl*0.5,(from+to)*0.5),Vector3(s,pl,to-from),k,m)
		# The bevel toward the next face: a 45 degree slab across the edge.
		if bev > 0.0 and not (pocket > 0.0 and k == (POCKET_FACE+3)%4):
			var w := bev*sqrt(2.0)
			_box(Vector3(0.0,half-bev*0.5-pl*0.35,half-bev*0.5-pl*0.35),Vector3(s,pl,w),k,m,PI*0.25)
		match k:
			SWEEP_FACE:
				_sweep_shape = _box(Vector3(0.0,half+wall_h*0.5,-half+BAR),Vector3(s,wall_h,BAR),k,ruin)
				_sweep_mesh = _last_mesh
			STEP_FACE: _box(Vector3(0.0,half+step_h*0.5,-(half-bev)*0.5),Vector3(s,step_h,half-bev),k,ruin)
			PRIZE_FACE:
				_box(Vector3(0.0,half+wall_h*0.5,half*0.55),Vector3(s*0.5,wall_h,0.4),k,ruin)
				_box(Vector3(0.0,half+wall_h*0.5,-half*0.55),Vector3(s*0.5,wall_h,0.4),k,ruin)
	if bool(knob("prize")):
		# The prize: a rune marker standing on face 2 (a look only).
		_prize = MeshInstance3D.new()
		var gem := PrismMesh.new()
		gem.size = Vector3(0.5,0.8,0.5)
		_prize.mesh = gem
		var glow := paint(Color(0.35,0.8,1.0))
		glow.emission_enabled = true
		glow.emission = Color(0.3,0.7,1.0)
		_prize.material_override = glow
		_prize.transform = Transform3D(_face_basis(PRIZE_FACE),_face_basis(PRIZE_FACE)*Vector3(0.0,half+0.6,0.0))
		look.add_child(_prize)
	for z: float in [-1.0,1.0]:
		var dust := CPUParticles3D.new()
		dust.amount = 24
		dust.lifetime = 0.9
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(half,0.05,0.1)
		dust.direction = Vector3(0.0,-1.0,z*0.4)
		dust.spread = 25.0
		dust.initial_velocity_min = 0.3
		dust.initial_velocity_max = 0.9
		dust.gravity = Vector3(0.0,-6.0,0.0)
		var grain := SphereMesh.new()
		grain.radius = 0.06
		grain.height = 0.12
		dust.mesh = grain
		dust.material_override = paint(Color(0.7,0.68,0.62))
		dust.position = centre()+Vector3(0.0,half,z*half)
		dust.emitting = false
		add_child(dust)
		_dust.append(dust)
	sweep = _sweep_start()
	_pose()

## The block's pose: roll about x, then yaw, at its centre (moved by its
## bob, drift and dip).
func _transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw+sway_now())*Basis(Vector3.RIGHT,roll),centre()+motion())

## Its own clock on a cycle of `period` s, as a sine (0 at the start).
func _wave(period: float) -> float:
	if period <= 0.0: return 0.0
	return sin(TAU*(_clock/period+float(knob("motion_phase"))))

## Where its middle is moved to now (the trap's frame, from `centre()`).
func motion() -> Vector3:
	var down := 0.0
	var dip := float(knob("dip"))
	if dip > 0.0 and is_finite(_slam_t):
		# A quick drop at the slam, then a heave back up.
		down = dip*(clampf(_slam_t/0.06,0.0,1.0)*clampf(1.0-(_slam_t-0.06)/0.5,0.0,1.0))
	return Vector3(float(knob("drift"))*_wave(float(knob("drift_time"))),
		float(knob("bob"))*_wave(float(knob("bob_time")))-down,float(knob("shuttle"))*shuttle_wave())

## The ferry's place now: +1 held back (toward the entry), -1 held on,
## eased or lunging between (`shuttle_ease`); `at` (s of its clock) if given.
func shuttle_wave(at := -1.0) -> float:
	var period := float(knob("shuttle_time"))
	if float(knob("shuttle")) == 0.0 or period <= 0.0: return 0.0
	var f := fposmod((_clock if at < 0.0 else at)/period+float(knob("shuttle_phase")),1.0)
	var e := minf(f,1.0-f)
	var hold := clampf(float(knob("shuttle_hold")),0.0,0.45)
	var v := clampf((e-hold*0.5)/(0.5-hold),0.0,1.0)
	var ease := clampf(float(knob("shuttle_ease")),-1.0,1.0)
	return 1.0-2.0*(v-ease*sin(TAU*v)/TAU)

## Held at one of its ends now (the ferry's hold).
func docked() -> bool:
	return float(knob("shuttle")) != 0.0 and absf(shuttle_wave()) >= 0.999

## The face on top now, as it lies: {x0, x1, z0, z1} its extent in the
## trap's frame (x, z) and y0, y1 its height at z0 and z1 (it tips about x,
## so its height runs along z).
func top_span() -> Dictionary:
	var half := float(knob("size"))*0.5
	var k := top_face()
	var t := _transform()
	var pts := []
	for c: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		pts.append(position+t*(_face_basis(k)*Vector3(c.x*half,half,c.y*half)))
	var out := {"x0":INF,"x1":-INF,"z0":INF,"z1":-INF,"y0":0.0,"y1":0.0}
	for q: Vector3 in pts:
		out.x0 = minf(out.x0,q.x)
		out.x1 = maxf(out.x1,q.x)
		if q.z < out.z0:
			out.z0 = q.z
			out.y0 = q.y
		if q.z > out.z1:
			out.z1 = q.z
			out.y1 = q.y
	return out

## The yaw wobble now (rad).
func sway_now() -> float:
	return float(knob("sway"))*_wave(float(knob("sway_time")))

## The middle now (world), moving.
func middle() -> Vector3:
	return to_global(centre()+motion())

func _pose() -> void:
	if body != null: body.transform = _transform()

## `p` (world) in the block's own frame.
func block_local(p: Vector3) -> Vector3:
	return _transform().affine_inverse()*to_local(p)

## `p` (world) in face `k`'s frame (its top at +y, half the size up).
func face_local(k: int, p: Vector3) -> Vector3:
	return _face_basis(k).inverse()*block_local(p)

## Face `k`'s outward normal (world).
func face_normal(k: int) -> Vector3:
	return (global_transform.basis*(_transform().basis*(_face_basis(k)*Vector3.UP))).normalized()

## How far face `k` is tipped from flat (rad, 0 up, PI/2 a side).
func face_tilt(k: int) -> float:
	return acos(clampf(face_normal(k).y,-1.0,1.0))

## The face whose plane `p` (world) is out along (0 to 3; the ends aside).
func face_at(p: Vector3) -> int:
	var l := block_local(p)
	var dots := [l.y,l.z,-l.y,-l.z]
	var best := 0
	for k in range(1,4):
		if dots[k] > dots[best]: best = k
	return best

## The face on top now.
func top_face() -> int:
	var best := 0
	for k in range(1,4):
		if face_normal(k).y > face_normal(best).y: best = k
	return best

## Is `feet` (world) on the block: near its outside, in its own frame?
func on_block(feet: Vector3) -> bool:
	var l := block_local(feet)
	var half := float(knob("size"))*0.5
	var m := maxf(absf(l.y),absf(l.z))
	return absf(l.x) <= half+0.2 and absf(l.y) <= half+1.0 and absf(l.z) <= half+1.0 and m >= half-float(knob("plate"))-0.8 and m <= half+1.0

## The surface normal under the feet (world): the block's nearest face axis.
func normal_at(feet: Vector3) -> Vector3:
	return face_normal(face_at(feet))

## The face on top and its tilt (rad, 0 flat).
func top_tilt() -> float:
	return fposmod(roll+PI*0.25,PI*0.5)-PI*0.25

## Whether `p` (world) is in the pocket (or the step it becomes), and the
## pocket still holds: from its floor up (its face the top) till its riser
## is (its face the leading side, the riser a step); neither faces down.
func in_pocket(p: Vector3) -> bool:
	var pocket := float(knob("pocket"))
	if pocket <= 0.0: return false
	var half := float(knob("size"))*0.5
	var pl := float(knob("plate"))
	var l := face_local(POCKET_FACE,p)
	if l.z < -half-0.4 or l.z > -half+pocket+0.4 or l.y < half-pl-0.4 or l.y > half+0.25: return false
	var riser := (global_transform.basis*(_transform().basis*(_face_basis(POCKET_FACE)*Vector3.FORWARD))).normalized()
	return face_normal(POCKET_FACE).y > -0.05 and riser.y > -0.05

## The stone's velocity (world, m/s) at `p` turning at `omega` rad/s.
func surface_velocity(p: Vector3, omega: float) -> Vector3:
	var axis := (global_transform.basis*(Basis(Vector3.UP,yaw+sway_now())*Vector3.RIGHT)).normalized()
	return (axis*omega).cross(p-middle())

## The lurch's turn rate (rad/s, signed).
func lurch_rate() -> float:
	return signf(float(knob("dir")))*(PI*0.5-float(knob("tip")))/maxf(float(knob("lurch")),0.05)

## Seconds left of the shudder before the lurch (INF outside it), and
## whether it is shuddering now.
func until_lurch() -> float:
	if phase == "rest": return tip_len()+rest_len()-phase_t
	if phase == "tip": return tip_len()-phase_t
	return INF

## This rest's and this tip's length (s): the ramped rhythm's, or, chained
## onto a lurch (`double`), `chain_rest` and a tip that is all tell.
func rest_len() -> float:
	return float(knob("chain_rest")) if _chain > 0 else float(knob("rest"))/pace

func tip_len() -> float:
	return float(knob("tell")) if _chain > 0 else float(knob("tip_time"))/pace

## In a rest's fake-out shudder (`feint`): the `feint` s up to its middle.
func feinting() -> bool:
	var feint := float(knob("feint"))
	if feint <= 0.0 or phase != "rest" or _chain > 0: return false
	var mid := rest_len()*0.5
	return phase_t >= mid-feint and phase_t < mid

func shuddering() -> bool:
	return phase == "tip" and until_lurch() <= float(knob("tell"))

## The prize's place (world), on face 2's top.
func prize_point() -> Vector3:
	var half := float(knob("size"))*0.5
	return to_global(_transform()*(_face_basis(PRIZE_FACE)*Vector3(0.0,half,0.0)))

func _advance(delta: float) -> void:
	yaw += float(knob("yaw"))*delta
	if float(knob("lurch")) <= 0.0:
		_advance_steady(delta)
		return
	var dir := signf(float(knob("dir")))
	var tip := float(knob("tip"))
	phase_t += delta
	match phase:
		"rest":
			roll = _base
			if feinting() and not _told:
				_told = true
				feints += 1
				tell_sound(&"grind",middle())
			if phase_t >= rest_len():
				phase = "tip"
				phase_t = 0.0
				_told = false
		"tip":
			var tt := tip_len()
			roll = _base+dir*tip*minf(phase_t/tt,1.0)
			if not _told and shuddering():
				_told = true
				tell_sound(&"grind",middle())
			if phase_t >= tt:
				phase = "lurch"
				phase_t = 0.0
				tell_sound(&"lurch",middle())
		"lurch":
			var k := minf(phase_t/maxf(float(knob("lurch")),0.05),1.0)
			roll = _base+dir*(tip+(PI*0.5-tip)*k)
			if k >= 1.0:
				_base = fposmod(_base+dir*PI*0.5+PI,TAU)-PI
				roll = _base
				lurches += 1
				phase = "rest"
				phase_t = 0.0
				_told = false
				_slam_t = 0.0
				_chain = _chain+1 if _chain < int(knob("double")) else 0
				tell_sound(&"slam",middle())

## Round 4's roll: continuous at `spin`, or quarter turns with a `pause`.
func _advance_steady(delta: float) -> void:
	phase = "roll"
	var w := float(knob("spin"))*float(knob("dir"))
	var pause := float(knob("pause"))
	if pause <= 0.0:
		roll += w*delta
		_turned += absf(w)*delta
		if _turned >= PI*0.5:
			_turned -= PI*0.5
			tell_sound(&"grind",to_global(centre()))
	else:
		if _pausing > 0.0:
			_pausing -= delta
			if _pausing <= 0.0: tell_sound(&"grind",to_global(centre()))
		else:
			var step := w*delta
			var left := PI*0.5-_turned
			if absf(step) >= left:
				step = signf(w)*left
				_pausing = pause
				_turned = 0.0
			else:
				_turned += absf(step)
			roll += step
	roll = fposmod(roll+PI,TAU)-PI

## Whether he is on it: standing on it, or holding one of its lips.
func riding() -> bool:
	if motor == null or motor.rider != null or motor.swimming: return false
	if motor.grounded: return on_block(motor.feet)
	if motor.on_ledge(): return on_block(motor.lip)
	return false

func before(delta: float) -> void:
	if body == null or delta <= 0.0: return
	var on := riding()
	if on and not _was_on: _wake()
	# Its ferry's way, as any moving ground's: leaving it into the air (a
	# jump, a step off) he keeps it; landing on it, it is the ground's, no
	# longer his (it carries him). Only what it slides, not its turn (that
	# is the throw's).
	var fv := Vector3(ferry_velocity.x,0.0,ferry_velocity.z)
	if _was_on and not on and motor != null and not motor.grounded and not motor.on_ledge() and motor.move != "tumble": motor.velocity += fv
	elif on and not _was_on and motor.grounded: motor.velocity -= fv
	_was_on = on
	_off_t = 0.0 if on else _off_t+delta
	var was := _transform()
	var was_yaw := yaw+sway_now()
	var was_phase := phase
	var was_docked := docked()
	var was_mid := middle()
	_clock += delta
	_slam_t += delta
	_woke_t += delta
	_advance(delta)
	_pose()
	ferry_velocity = (middle()-was_mid)/delta if float(knob("shuttle")) != 0.0 else Vector3.ZERO
	_dock_t += delta
	if docked() and not was_docked:
		_dock_t = 0.0
		tell_sound(&"dock",middle())
	if on:
		riding_time += delta
		pace = minf(1.0+float(knob("ramp"))*riding_time,maxf(float(knob("ramp_top")),1.0))
		var moved := global_transform*(_transform()*was.affine_inverse())*global_transform.affine_inverse()
		motor.carry(moved,yaw+sway_now()-was_yaw)
		if motor.grounded: _underfoot(delta,was_phase == "lurch" and phase == "rest")
		elif motor.on_ledge(): _on_lip()
	else: slide = 0.0
	_sweep_step(delta)
	_tell(delta)

## He lands on it after a while off it: it wakes (`wake`), shudders and
## cuts its rest short.
func _wake() -> void:
	var wake := float(knob("wake"))
	if wake <= 0.0 or _off_t < float(knob("wake_off")): return
	wakes += 1
	_woke_t = 0.0
	tell_sound(&"wake",middle())
	if phase == "rest" and _chain == 0: phase_t = maxf(phase_t,rest_len()-wake)

## Stood on it: thrown by the lurch, jolted by its stop, slid on the slick.
func _underfoot(delta: float, stopped: bool) -> void:
	var feet := motor.feet
	var held := in_pocket(feet)
	var k := face_at(feet)
	var tilt := face_tilt(k)
	if not held and stopped:
		var v := surface_velocity(feet,lurch_rate())*float(knob("jolt"))
		if v.length() > motor.walk*0.5:
			_put_off("jolted",v)
			return
	if not held and phase == "lurch" and tilt > float(knob("throw_at")):
		_put_off("thrown",surface_velocity(feet,lurch_rate())*float(knob("throw")))
		return
	var slick := float(knob("slick"))
	if held or tilt <= slick or tilt >= PI*0.5:
		slide = move_toward(slide,0.0,float(knob("slip"))*2.0*delta)
		return
	var n := face_normal(k)
	var down := Vector3(n.x,0.0,n.z).normalized()
	var uphill := -Vector2(down.x,down.z).dot(Vector2(motor.velocity.x,motor.velocity.z))
	if uphill > float(knob("grip")): slide = move_toward(slide,0.0,float(knob("slip"))*2.0*delta)
	else: slide = minf(slide+float(knob("slip"))*(sin(tilt)-sin(slick))*delta,float(knob("slip_top")))
	if slide > 0.0: motor.carry(Transform3D(Basis.IDENTITY,down*slide*delta),0.0)

## Hanging from one of its lips: shaken loose as that face tips past
## `throw_at` (the lurch's speed with him).
func _on_lip() -> void:
	var inward := Vector3(-motor.lip_out.x,0.0,-motor.lip_out.y)*0.15
	var k := face_at(motor.lip+inward-Vector3.UP*0.05)
	if face_tilt(k) <= float(knob("throw_at")): return
	var omega := lurch_rate() if phase == "lurch" else 0.0
	put_off = "shaken"
	thrown += 1
	slide = 0.0
	motor.toss(surface_velocity(motor.lip,omega)*float(knob("throw"))+Vector3(motor.lip_out.x,0.0,motor.lip_out.y)*0.6)

func _put_off(how: String, v: Vector3) -> void:
	put_off = how
	thrown += 1
	slide = 0.0
	motor.knock(v+Vector3.UP*0.5)

func _sweep_start() -> float:
	var half := float(knob("size"))*0.5
	return -signf(float(knob("dir")))*(half-BAR)

## The sweeper runs along face 0 toward its leading edge while face 0 is
## up (and not lurching), and shoves him along before it; back to the
## trailing edge once face 0 has turned away.
func _sweep_step(delta: float) -> void:
	if _sweep_shape == null: return
	var half := float(knob("size"))*0.5
	var dir := signf(float(knob("dir")))
	var was := sweep
	if top_face() != SWEEP_FACE: sweep = _sweep_start()
	elif phase != "lurch": sweep = move_toward(sweep,dir*(half-BAR*0.5),float(knob("sweep"))*pace*delta)
	if sweep != was:
		var wall_h := float(knob("wall_h"))
		var t := Transform3D(Basis.IDENTITY,Vector3(0.0,half+wall_h*0.5,sweep))
		_sweep_shape.transform = t
		_sweep_mesh.transform = t
	if motor == null or not motor.grounded or not on_block(motor.feet) or face_at(motor.feet) != SWEEP_FACE: return
	if top_face() != SWEEP_FACE: return
	var l := face_local(SWEEP_FACE,motor.feet)
	var r := Ground.RADIUS*WorldScale.wanderer
	var ahead := (l.z-sweep)*dir
	var push := 0.0
	if l.y >= half+float(knob("wall_h"))-0.1:
		# Stood on the bar: carried along it.
		if absf(l.z-sweep) <= BAR*0.5+0.05: push = sweep-was
	elif ahead > -BAR*0.25 and ahead < BAR*0.5+r:
		push = dir*(BAR*0.5+r+0.01-ahead)
	if absf(push) > 1e-5:
		var way := global_transform.basis*(_transform().basis*(_face_basis(SWEEP_FACE)*Vector3(0.0,0.0,push)))
		motor.carry(Transform3D(Basis.IDENTITY,Vector3(way.x,0.0,way.z)),0.0)

func after(_delta: float, _events: Dictionary) -> void:
	if prize_taken or _prize == null or motor == null or not motor.grounded: return
	if top_face() != PRIZE_FACE or not on_block(motor.feet): return
	if motor.feet.distance_to(prize_point()) <= Ground.HEAD*WorldScale.wanderer:
		prize_taken = true
		_prize.visible = false
		tell_sound(&"prize",prize_point())

## The tell: the shudder (the look shaken), dust off the top edges, the
## faces warming; the face coming up warms first as it tips.
func _tell(delta: float) -> void:
	var loud := 0.0
	var coming := 0.0
	if phase == "lurch": loud = 1.0
	elif feinting(): loud = clampf(1.0-(rest_len()*0.5-phase_t)/float(knob("feint")),0.3,1.0)
	elif phase == "tip":
		coming = clampf(phase_t/maxf(tip_len(),0.01),0.0,1.0)
		var tell := float(knob("tell"))
		if tell > 0.0: loud = clampf(1.0-until_lurch()/tell,0.0,1.0) if shuddering() else 0.0
	elif phase == "roll":
		var pause := float(knob("pause"))
		if pause > 0.0 and _pausing > 0.0: loud = clampf(1.0-_pausing/minf(float(knob("tell")),pause),0.0,1.0)
	# Woken: a short startled shudder.
	var woke := clampf(1.0-_woke_t/maxf(float(knob("tell"))*0.5,0.01),0.0,1.0) if float(knob("wake")) > 0.0 else 0.0
	_shake_t += delta
	var a := float(knob("shake"))*maxf(loud if phase in ["tip","rest"] else 0.0,woke)
	if look != null: look.position = Vector3(sin(_shake_t*53.0),sin(_shake_t*71.0)*0.5,sin(_shake_t*61.0))*a
	var slammed := (float(knob("dip")) > 0.0 and _slam_t < 0.35) or _dock_t < 0.3
	for i in range(_dust.size()):
		_dust[i].emitting = loud > 0.0 or slammed
		_dust[i].position = centre()+motion()+Vector3(0.0,float(knob("size"))*0.5,(-1.0 if i == 0 else 1.0)*float(knob("size"))*0.5)
	loud = maxf(loud,woke)
	var dir := signf(float(knob("dir")))
	for k in range(_plate_mats.size()):
		# The face rising to the top: its normal swinging up from the
		# trailing side.
		var n := face_normal(k)
		var rising := n.y > -0.2 and n.y < 0.9 and Vector3(0.0,0.0,-dir).dot(global_transform.basis.inverse()*n) > 0.3
		var share := maxf(loud*0.7,coming if rising else 0.0)
		_plate_mats[k].albedo_color = STONES[k].lerp(TELL,share)
		var glow := float(knob("glow"))
		if glow > 0.0:
			_plate_mats[k].emission_enabled = true
			_plate_mats[k].emission = TELL*share*glow
	tell_sight(loud)

func reset() -> void:
	super()
	roll = 0.0
	yaw = 0.0
	_turned = 0.0
	_pausing = 0.0
	_base = 0.0
	phase = "rest"
	phase_t = 0.0
	_told = false
	pace = 1.0
	riding_time = 0.0
	lurches = 0
	put_off = ""
	thrown = 0
	slide = 0.0
	prize_taken = false
	_clock = 0.0
	_chain = 0
	_slam_t = INF
	_off_t = INF
	_woke_t = INF
	_dock_t = INF
	ferry_velocity = Vector3.ZERO
	_was_on = false
	feints = 0
	wakes = 0
	if _prize != null: _prize.visible = true
	sweep = _sweep_start()
	if _sweep_shape != null:
		var t := Transform3D(Basis.IDENTITY,Vector3(0.0,float(knob("size"))*0.5+float(knob("wall_h"))*0.5,sweep))
		_sweep_shape.transform = t
		_sweep_mesh.transform = t
	_pose()
