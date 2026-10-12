extends "res://scripts/traps/trap.gd"
## Flip Platforms (the user's idea, docs/design/roguelike/traps-round3-roll-flip.md;
## built to the contract in scripts/traps/trap.gd): a row of stone slabs over
## a drop, each turning over 180 degrees about its long axis (across the
## route) on a rhythm. A slab is flat for most of its `period`, then tells
## (`tell` s: it shudders, clicks, and warms to orange), then flips in
## `flip` s: the pilot on it is carried round with it until the slab is
## steeper than `knock_angle`, then thrown off (back along the route, up a
## little, with the slab's own pace) -- the slab rotating from under him.
## It lands upside down: its other face (a different colour) is the top
## until the next flip. Slab i starts `stagger` s after slab i-1, so the
## flips run down the row like a wave and there is always a flat next slab:
## the crossing is hop, hop, hop, each onto a slab that has just flipped
## (flat time `period - tell - flip` is the window).
##
## The underside (`underside`): "safe" (walkable), "slick" (walkable but it
## carries him back at `slick` m/s) or "gone" (no collision while that face
## is up: a hole). The rhythm speeds up the longer he is on the slabs
## (`speedup` per s, capped at `max_rate` x). Cost 3 over a layer, 4 over
## the void.
##
## Sizes from the pilot: `length` (along the route) his half second walking,
## `width` his half second running, `gap` a share of a running small hop's
## reach (0.3). Knobs: `count`, `length`, `width`, `gap`, `thick`, `period`,
## `tell`, `flip`, `stagger`, `underside`, `slick`, `knock`, `knock_angle`,
## `speedup`, `max_rate`.
const STONE := Color(0.42,0.41,0.4)
const UNDER := Color(0.28,0.36,0.46)
const REACH_SHARE := 0.3

const FLAT := 0
const TELLING := 1
const FLIPPING := 2

## One record per slab: body, both face materials, local centre (x 0, z),
## cycle time, completed flips, phase.
var slabs: Array[Dictionary] = []
var clock := 0.0
## Pilot tossed off by a flip (count).
var knocks := 0
var mats: Array[StandardMaterial3D] = []

func _init() -> void:
	super()
	trap_name = "flip"
	cost = 3
	under = "layer"
	verbs = PackedStringArray(["jump"])

func defaults() -> Dictionary:
	var p := pilot()
	var reach := p.run*2.0*sqrt(2.0*p.jumps[0]/p.gravity)
	return {
		"count":7,"length":p.walk*0.5,"width":p.run*0.5,"gap":reach*REACH_SHARE,"thick":0.3,
		"period":2.4,"tell":0.5,"flip":0.22,"stagger":0.6,
		"underside":"safe","slick":p.walk*0.6,
		"knock":p.walk*0.8,"knock_angle":1.0,
		"speedup":0.04,"max_rate":1.6,
	}

func length() -> float:
	var n := float(knob("count"))
	return n*(float(knob("length"))+float(knob("gap")))+float(knob("gap"))

func footprint() -> Rect2:
	var w := float(knob("width"))
	return Rect2(-w*0.5,-length(),w,length())

func build() -> void:
	var thick := float(knob("thick"))
	var slab_len := float(knob("length"))
	var wide := float(knob("width"))
	for i in range(int(knob("count"))):
		var z := -(float(knob("gap"))+float(i)*(slab_len+float(knob("gap")))+slab_len*0.5)
		var body := StaticBody3D.new()
		body.position = Vector3(0.0,-thick*0.5,z)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(wide,thick,slab_len)
		shape.shape = box
		body.add_child(shape)
		# Two half-thickness bodies of different colours: the face up and its underside.
		var top_mat := paint(STONE)
		var bottom_mat := paint(UNDER)
		for half in range(2):
			var mesh := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(wide,thick*0.5,slab_len)
			mesh.mesh = bm
			mesh.position.y = thick*0.25*(1.0 if half == 0 else -1.0)
			mesh.material_override = top_mat if half == 0 else bottom_mat
			body.add_child(mesh)
		add_child(body)
		slabs.append({"body":body,"top_mat":top_mat,"bottom_mat":bottom_mat,"z":z,"t":-float(i)*float(knob("stagger")),"flips":0,"phase":FLAT,"u":0.0})
	_pose_all()

func _rate() -> float:
	return minf(1.0+float(knob("speedup"))*clock,float(knob("max_rate")))

## Seconds of cycle at which the tell and the flip begin.
func _tell_at() -> float:
	return float(knob("period"))-float(knob("tell"))-float(knob("flip"))

func _flip_at() -> float:
	return float(knob("period"))-float(knob("flip"))

## How long slab `i` stays flat before it begins to tell (0 if not flat),
## in real seconds at the present rate.
func flat_for(i: int) -> float:
	var s: Dictionary = slabs[i]
	if int(s.phase) != FLAT: return 0.0
	return maxf(_tell_at()-float(s.t),0.0)/_rate()

## Is the pilot's feet (world) on slab `i`: near its face that is up?
func on_slab(feet: Vector3, i: int) -> bool:
	var s: Dictionary = slabs[i]
	var body: Node3D = s.body
	var local := body.transform.affine_inverse()*to_local(feet)
	var thick := float(knob("thick"))
	return absf(local.x) <= float(knob("width"))*0.5 and absf(local.z) <= float(knob("length"))*0.5 \
		and absf(absf(local.y)-thick*0.5) < 0.3 and to_local(feet).y > body.position.y

## The slab the feet are on, or -1.
func slab_at(feet: Vector3) -> int:
	for i in range(slabs.size()):
		if on_slab(feet,i): return i
	return -1

## The slab's angle about its long axis and the face up (0 stone, 1 under).
func _angle(s: Dictionary) -> float:
	return float(s.flips)*PI+_ease(float(s.u))*PI

func _ease(u: float) -> float:
	return u*u*(3.0-2.0*u)

func upside_down(s: Dictionary) -> bool:
	return fposmod(_angle(s)+PI*0.5,TAU) >= PI

func _pose(s: Dictionary, shudder: float) -> void:
	var body: Node3D = s.body
	body.rotation.x = _angle(s)+shudder
	var solid := not (str(knob("underside")) == "gone" and upside_down(s) and int(s.phase) != FLIPPING)
	(body as StaticBody3D).collision_layer = 1 if solid else 0

func _pose_all() -> void:
	for s: Dictionary in slabs: _pose(s,0.0)

func before(delta: float) -> void:
	if delta <= 0.0 or slabs.is_empty(): return
	var riding := -1
	if motor != null and motor.rider == null and not motor.swimming and motor.grounded:
		riding = slab_at(motor.feet)
	if riding >= 0: clock += delta
	var step := delta*_rate()
	var loud := 0.0
	for i in range(slabs.size()):
		var s: Dictionary = slabs[i]
		var body: Node3D = s.body
		var was := body.transform
		s.t += step
		if float(s.t) >= float(knob("period")):
			s.t -= float(knob("period"))
			s.flips += 1
		var t := float(s.t)
		var phase := FLAT
		var share := 0.0
		var u := 0.0
		if t >= _flip_at():
			phase = FLIPPING
			u = clampf((t-_flip_at())/float(knob("flip")),0.0,1.0)
		elif t >= _tell_at():
			phase = TELLING
			share = clampf((t-_tell_at())/float(knob("tell")),0.0,1.0)
		# A flip that just completed leaves u at 0 on the next count.
		if phase != int(s.phase):
			if phase == TELLING: tell_sound(&"click",to_global(body.position))
			elif phase == FLIPPING: tell_sound(&"clack",to_global(body.position))
		s.phase = phase
		s.u = u
		loud = maxf(loud,share)
		_pose(s,sin(t*70.0)*0.05*share)
		# Faces: the one up warms to the tell.
		var up_mat: StandardMaterial3D = s.bottom_mat if int(s.flips)%2 == 1 else s.top_mat
		var down_mat: StandardMaterial3D = s.top_mat if int(s.flips)%2 == 1 else s.bottom_mat
		var base_up := UNDER if int(s.flips)%2 == 1 else STONE
		var base_down := STONE if int(s.flips)%2 == 1 else UNDER
		up_mat.albedo_color = base_up.lerp(TELL,share)
		down_mat.albedo_color = base_down
		if i == riding: _ride(s,was,delta)
	tell_sight(loud)

## The pilot on slab `s`: carried round with its flip; thrown off past the
## knock angle; on an upside-down "slick" face slid back.
func _ride(s: Dictionary, was: Transform3D, delta: float) -> void:
	var body: Node3D = s.body
	var moved := global_transform*(body.transform*was.affine_inverse())*global_transform.affine_inverse()
	motor.carry(moved,0.0)
	if int(s.phase) == FLIPPING:
		var turned := _ease(float(s.u))*PI
		if turned >= float(knob("knock_angle")):
			var k := float(knob("knock"))
			var rel := to_local(motor.feet)-body.position
			var omega := PI*6.0*float(s.u)*(1.0-float(s.u))/maxf(float(knob("flip")),0.02)
			# The slab's own pace at his point (axis across the route), back along it.
			var tangent := Vector3(0.0,-rel.z,rel.y)*omega
			var up := sqrt(2.0*motor.gravity*motor.jumps[0]*0.5)
			var out := global_transform.basis*Vector3(0.0,up,k)+global_transform.basis*tangent
			motor.toss(out)
			knocks += 1
	elif str(knob("underside")) == "slick" and upside_down(s):
		motor.carry(Transform3D(Basis.IDENTITY,global_transform.basis*Vector3(0.0,0.0,float(knob("slick"))*delta)),0.0)

func reset() -> void:
	super()
	clock = 0.0
	knocks = 0
	for i in range(slabs.size()):
		var s: Dictionary = slabs[i]
		s.t = -float(i)*float(knob("stagger"))
		s.flips = 0
		s.phase = FLAT
		s.u = 0.0
		(s.top_mat as StandardMaterial3D).albedo_color = STONE
		(s.bottom_mat as StandardMaterial3D).albedo_color = UNDER
	_pose_all()
