extends "res://scripts/traps/trap_seesaw.gd"
## Seesaw, dropped on: the
## pilot stands on the low end; a heavy block hangs on a hook above the other
## (high) end and is let fall, landing as a blow whose momentum is the
## block's (`drop_hit`): he is flung up and along.
##   - `plate` true (the catapult route): the far end of the slab carries a
##     plate; standing on it for `fuse` s lets the block go. The ledge past
##     the exit (`ledge`) is set where the launch arc comes down on it.
##   - `plate` false (the timed trap, trap_seesaw_dropper.gd): the block falls
##     every `period` s on its own, over the near end; a pilot on the far half
##     is flung on and `veer` sideways, off the span.
## The tell: the plate warms with the fuse / the block warms for `warn` s
## before it falls; `thunk` on the landing. Knobs (over the seesaw's):
## `block_mass`, `block` (m a side), `hook` (m above the deck), `fuse`,
## `period`, `warn`, `rest` (s after a drop before the block is hung again),
## `ledge` (top of the landing ledge, in second-jump heights; 0 none),
## `hook_far` (the hook over the far end).
const BLOCK := Color(0.36,0.35,0.34)
const PLATE := Color(0.5,0.47,0.42)

var block: RigidBody3D
var plate_mat: StandardMaterial3D
var released := false
var drops := 0
var _fuse_t := 0.0
var _clock := 0.0
var _peak := 0.0
var _gone_t := 0.0

func _init() -> void:
	super()
	trap_name = "seesaw_drop"

func defaults() -> Dictionary:
	var d := super()
	var p := pilot()
	# Heavy and from high, so the catapult throws past his own best boost
	# (tried in play 2026-10-12: 600 kg from 12 m, the cap x3).
	d.merge({"block_mass":600.0,"block":p.jumps[0]*1.1,"hook":p.jumps[1]*8.0,"fuse":1.0,"period":4.0,
		"warn":0.8,"rest":2.5,"plate":true,"ledge":2.0,"cap_mul":3.0,"hook_far":false},true)
	return d

## z of the block's hook (local), over the end opposite the plate.
func hook_z() -> float:
	var arm := length()*0.5*0.8
	return pivot_z()-arm if bool(knob("hook_far")) else pivot_z()+arm

func build() -> void:
	super()
	block = make_block(float(knob("block_mass")),float(knob("block")),BLOCK)
	add_child(block)
	loads.append(block)
	block.body_entered.connect(_touched)
	# The hook: a post beside the slab.
	var post := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var hook := float(knob("hook"))
	bm.size = Vector3(0.3,hook+1.0,0.3)
	post.mesh = bm
	post.material_override = paint(STUMP)
	post.position = Vector3(float(knob("width"))*0.5+0.9,(hook+1.0)*0.5-THICK,hook_z())
	add_child(post)
	if bool(knob("plate")):
		var plate := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(float(knob("width"))*0.8,0.06,1.0)
		plate.mesh = pm
		plate_mat = paint(PLATE)
		plate.material_override = plate_mat
		plate.position = Vector3(0.0,0.03,launch_z())
		body.add_child(plate)
	if float(knob("ledge")) > 0.0: _build_ledge()
	_hang()

## Metres along the route the launch arc covers by the time it is `rise` m up on the way down.
func arc_reach(rise: float) -> float:
	var p := pilot()
	var v := _launch_cap()*float(knob("cap_mul"))
	# Up on his gravity, down on his falling gravity (heavier), as he flies.
	var peak := v*v/(2.0*p.gravity)
	if peak < rise: return 0.0
	var t := v/p.gravity+sqrt(2.0*(peak-rise)/(p.gravity*p.fall))
	return v*float(knob("along"))*t

## Where the pilot stands to be flung (local z): the plate.
func launch_z() -> float:
	return -length()+0.9

func ledge_top() -> float:
	return float(knob("ledge"))*pilot().jumps[1]

func _build_ledge() -> void:
	var low := _surface_y(launch_z())
	var top := ledge_top()
	var reach := arc_reach(top-low)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Deep enough to catch a big throw's spread (his steering, the blow's share).
	box.size = Vector3(float(knob("width"))*2.0,top,maxf(3.0,reach*0.5))
	cs.shape = box
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = box.size
	mi.mesh = bmesh
	mi.material_override = paint(STONE)
	sb.add_child(mi)
	# He flies a little past the estimate (his steering in the air): centred
	# a tenth beyond it.
	sb.position = Vector3(0.0,top*0.5,launch_z()-reach*1.1)
	add_child(sb)

func _hang() -> void:
	released = false
	_fuse_t = 0.0
	_clock = 0.0
	_peak = 0.0
	_gone_t = 0.0
	block.freeze = true
	block.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	block.linear_velocity = Vector3.ZERO
	block.angular_velocity = Vector3.ZERO
	block.transform = Transform3D(Basis.IDENTITY,Vector3(0.0,float(knob("hook")),hook_z()))

## Let the block go.
func release() -> void:
	if released: return
	released = true
	drops += 1
	_gone_t = 0.0
	_peak = 0.0
	block.freeze = false
	block.sleeping = false
	tell_sound(&"click",to_global(block.position))

func _touched(other: Node) -> void:
	if other != body or not released or _peak <= 0.0: return
	if _peak > float(knob("hard")):
		var fall := _peak
		_peak = 0.0
		drop_hit(block,fall)

func before(delta: float) -> void:
	super(delta)
	if block == null or delta <= 0.0: return
	if released:
		_peak = maxf(_peak,-block.linear_velocity.y)
		_gone_t += delta
		if _gone_t > float(knob("rest")) and _settled():
			_hang()
		return
	var warm := 0.0
	if bool(knob("plate")):
		var on := motor != null and motor.rider == null and motor.grounded and on_slab(motor.feet) and arm_of(to_local(motor.feet)) > length()*0.5*0.6
		_fuse_t = _fuse_t+delta if on else maxf(_fuse_t-delta*2.0,0.0)
		warm = clampf(_fuse_t/maxf(float(knob("fuse")),0.05),0.0,1.0)
		if plate_mat != null: plate_mat.albedo_color = PLATE.lerp(TELL,warm)
		if _fuse_t >= float(knob("fuse")): release()
	else:
		_clock += delta
		warm = clampf((_clock-(float(knob("period"))-float(knob("warn"))))/maxf(float(knob("warn")),0.05),0.0,1.0)
		if _clock >= float(knob("period")): release()
	var mat := block.get_child(1).material_override as StandardMaterial3D
	if mat != null: mat.albedo_color = BLOCK.lerp(TELL,warm)

func _settled() -> bool:
	return block.linear_velocity.length() < 0.5 or block.position.y < -20.0

func reset() -> void:
	super()
	drops = 0
	if block != null: _hang()
