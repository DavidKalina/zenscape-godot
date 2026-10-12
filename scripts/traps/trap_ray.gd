extends "res://scripts/traps/trap.gd"
## The Sky Ray (the user's idea, a Mario Sunshine sand bird; docs/design/
## roguelike/traps-round4-giants.md; built to the contract in scripts/traps/
## trap.gd): a broad flat creature, greybox, that flies a closed loop (a
## stadium: two straights joined by two turns) round the lane at a steady
## pace. It passes the far deck, then the start deck (the near straight runs
## beside both, level with them, toward the start deck), so a rider who
## boards at the start deck rides the whole loop before the far deck comes
## by: board from the start deck's east edge, get off at the far deck's.
##
## Riding it is a fight to stay on. On its back he is carried with its full
## transform delta (`motor.carry`, his facing turned with it) and he slides
## on its smooth hide: the trap keeps his slide (`slip`, m/s across the
## back) and moves him by it through `carry`, as a moving surface does. The
## slide is pushed by gravity along the tilted back and by the swing of its
## flight (the acceleration of the point under his feet, taken out: a turn
## throws him outward, a climb presses him down, a dive goes light), and
## held by friction, `grip` times how hard he is pressed onto the back. He
## grips harder leaning: walking uphill (`lean` more at `lean_pace`).
## Crouching is no grip here: on any slope over the motor's SLIDE_FROM a
## crouch is its boot-surf, down the back and off. The raised ridges on its
## back stop a slide into them (cover on the low side).
## Slid past the rim fast (over the motor's CATCH_PACE) and not leaning in,
## he is thrown off with the speed he had (`motor.toss`); slower, or leaning
## back in, the motor's own step-off catch takes the rim and he hangs from
## it, carried, to climb back up. Where its back drops away faster than he
## would fall (a dive's plunge) he lifts off (`toss` with its velocity) and
## floats till it pulls up under him. Leaving its back any way, he keeps its
## velocity; landing on it, his own run is taken relative to it.
##
## The rhythm: after the start deck a `pattern` of beats runs over the far
## part of the loop: "L"/"R" a roll that drops that wing (a bank), "D" a
## climb then a dive. Banks grow from (1-`ramp`) x `max_bank` on the first
## to `max_bank` on the last. Tells, `tell` s ahead: the wing that will rise
## lifts and warms to orange before a bank, with a `whoosh`; the head dips
## before a dive's plunge, with a `screech`. `shake` (rad) is a wobble about
## its length that tries to shed a rider. Cost 4, over the void 5.
##
## Sizes from the pilot: the back `width` 6 of his heights, `long` 8,
## `speed` his run, `radius` the turn's, `height` the dive's climb, the
## ridges his first jump x 0.7 high and his body's width thick, the plunge
## his fall's acceleration x `dive`. The tilt is held under the motor's own
## slide angle (SLIDE_AUTO, past which the motor surfs him itself).
const Ground = preload("res://scripts/pilot_physics_ground.gd")
const SKIN := Color(0.42,0.41,0.4)
const RIDGE := Color(0.5,0.46,0.4)
const WING := Color(0.36,0.4,0.46)
const HEAD_COLOUR := Color(0.33,0.36,0.4)
const REACH_SHARE := 0.45
## Under SLIDE_AUTO by this (degrees): the steepest the back tilts.
const TILT_MARGIN := 2.0

var body: StaticBody3D
var head: MeshInstance3D
var wing_l: MeshInstance3D
var wing_r: MeshInstance3D
var wing_mats: Array[StandardMaterial3D] = []
## Distance flown (m, unwrapped: the shake's clock is s / speed), the bank
## and pitch now (rad), the clock (s).
var s := 0.0
var bank := 0.0
var pitch := 0.0
var clock := 0.0
## His slide across the back (m/s, the back's x z), and the last friction
## share and normal load (m/s²) worked out.
var slip := Vector2.ZERO
var last_grip := 0.0
var last_load := 0.0
## Ridges: [Rect2 (x z on the back), top] in the back's frame.
var ridges: Array = []
var riding_time := 0.0
## Counted for tests and tuning: lift-offs (a dive), throws off the rim.
var floats := 0
var throws := 0
var _whoosh_ready := true
var _screech_ready := true
var _was_riding := false
var _tossed := false
var _v_point := Vector3.ZERO
## The beats and the dive's numbers, laid from the knobs (`replan`).
var _plan: Array = []
var _dive := {}

func _init() -> void:
	super()
	trap_name = "ray"
	cost = 4
	under = "void"
	verbs = PackedStringArray(["jump","balance","hang"])

func defaults() -> Dictionary:
	var p := pilot()
	var height: float = Ground.HEAD*WorldScale.wanderer
	var reach := p.run*2.0*sqrt(2.0*p.jumps[0]/p.gravity)
	return {
		"width":height*6.0,"long":height*8.0,"thick":0.8,
		# The hide at the rim (m thick); the thick body starts his hang and
		# his body's width in from it.
		"hide":0.2,"inset":p.hang_out+Ground.RADIUS*2.0*WorldScale.wanderer,
		"speed":p.run,"radius":height*7.5,
		# The beats: banks (rad), the dive's climb (m, s), its plunge (his
		# fall's acceleration x dive, for plunge s), the roll's times (s).
		"pattern":"RDLDR","max_bank":0.72,"ramp":0.7,"turn_bank":0.0,
		"roll":0.5,"hold":1.0,"height":height*7.0,"climb":2.0,
		"dive":1.4,"plunge":0.35,"max_pitch":0.25,
		"shake":0.04,"shake_rate":4.0,"tell":1.0,
		# His footing: friction standing, more leaning in (at lean_pace
		# uphill, his walk x 0.5), gravity's and the swing's shares, and the
		# rim's catch pace (the motor's).
		"grip":0.3,"lean":0.8,"lean_pace":p.walk*0.5,"pull":1.0,"swing":1.0,
		"catch_pace":PilotMotor.CATCH_PACE,
		"ride":height*20.0,"edge_x":5.0,"gap":reach*REACH_SHARE,
		"lead_in":10.0,"lead_out":10.0,"arrive":3.0,
	}

func length() -> float:
	return float(knob("ride"))

## Room the loop takes to the east of the lane (m past the deck's edge),
## for a yard that lays lanes side by side.
func lane_extra() -> float:
	return float(knob("gap"))+float(knob("width"))+2.0*float(knob("radius"))

# ---- the path: a stadium in x z, flown in this order: the near straight
# north (+z, past the far deck then the start deck), a left turn east, the
# far straight south, a left turn back ----

## x of the near straight (the ray's middle line).
func line_x() -> float:
	return float(knob("edge_x"))+float(knob("gap"))+float(knob("width"))*0.5

func _z_north() -> float:
	return float(knob("lead_in"))

func _z_south() -> float:
	return -(float(knob("ride"))+float(knob("lead_out")))

func straight() -> float:
	return _z_north()-_z_south()

func _semi() -> float:
	return PI*float(knob("radius"))

func loop_length() -> float:
	return 2.0*straight()+2.0*_semi()

## Where along the loop (m) it is level with world-local z `z` on the near
## straight.
func near_at(z: float) -> float:
	return z-_z_south()

## Position on the loop at distance `d` (local, x z; y the dives').
func path_at(d: float) -> Vector3:
	d = fposmod(d,loop_length())
	var r := float(knob("radius"))
	var leg := straight()
	var x0 := line_x()
	var out := Vector3.ZERO
	var semi := _semi()
	if d < leg:
		out = Vector3(x0,0.0,_z_south()+d)
	elif d < leg+semi:
		var phi := (d-leg)/r
		out = Vector3(x0+r-r*cos(phi),0.0,_z_north()+r*sin(phi))
	elif d < 2.0*leg+semi:
		out = Vector3(x0+2.0*r,0.0,_z_north()-(d-leg-semi))
	else:
		var phi := (d-2.0*leg-semi)/r
		out = Vector3(x0+r+r*cos(phi),0.0,_z_south()-r*sin(phi))
	out.y = _dive_y(d)
	return out

## The way it flies at `d` (x z, unit).
func _way(d: float) -> Vector2:
	d = fposmod(d,loop_length())
	var r := float(knob("radius"))
	var leg := straight()
	var semi := _semi()
	if d < leg: return Vector2(0.0,1.0)
	if d < leg+semi:
		var phi := (d-leg)/r
		return Vector2(sin(phi),cos(phi))
	if d < 2.0*leg+semi: return Vector2(0.0,-1.0)
	var phi2 := (d-2.0*leg-semi)/r
	return Vector2(-sin(phi2),-cos(phi2))

func heading_at(d: float) -> float:
	var w := _way(d)
	return atan2(-w.x,-w.y)

## Turn rate of the heading at `d`: 0 straight, 1/r in a turn (both left).
func curvature_at(d: float) -> float:
	d = fposmod(d,loop_length())
	var leg := straight()
	var semi := _semi()
	if (d >= leg and d < leg+semi) or d >= 2.0*leg+semi: return 1.0/float(knob("radius"))
	return 0.0

# ---- the beats ----

## The beats in order: {kind "L"/"R"/"D", at (m along the loop it starts),
## size (rad, a bank), long (m it lasts), plunge (m along it the dive's
## plunge starts)}. Spread over the loop from just into the first turn to
## its last turn, so the near straight past both decks is calm.
func beats() -> Array:
	if _plan.is_empty(): _plan = _lay_beats()
	return _plan

func _lay_beats() -> Array:
	var pattern := String(knob("pattern"))
	var out: Array = []
	var n := pattern.length()
	if n == 0: return out
	var v := float(knob("speed"))
	var from := straight()+v*1.0
	var to := loop_length()-v*3.0
	for i in range(n):
		var kind := pattern[i]
		var at := from+(to-from)*(float(i)/float(n-1) if n > 1 else 0.0)
		var share := 1.0-float(knob("ramp"))*(1.0-(float(i)/float(n-1) if n > 1 else 1.0))
		var beat := {"kind":kind,"at":at,"size":float(knob("max_bank"))*share}
		if kind == "D":
			var dive := _dive_numbers()
			beat["long"] = (float(knob("climb"))+dive.plunge+dive.out)*v
			beat["plunge"] = float(knob("climb"))*v
		else:
			beat["long"] = (2.0*float(knob("roll"))+float(knob("hold")))*v
		out.append(beat)
	return out

## The dive: climb `height`, then down at A (his fall's acceleration x
## dive) for `plunge` s, then pulled out at B to level where it began.
func _dive_numbers() -> Dictionary:
	if not _dive.is_empty(): return _dive
	var p := pilot()
	var a := p.gravity*p.fall*float(knob("dive"))
	var tp := float(knob("plunge"))
	var v1 := a*tp
	var d1 := 0.5*a*tp*tp
	var rest := maxf(float(knob("height"))-d1,0.1)
	var b := v1*v1/(2.0*rest)
	_dive = {"a":a,"plunge":tp,"v1":v1,"d1":d1,"b":b,"out":v1/b}
	return _dive

## Height (m) of the dives at `d` (0 level).
func _dive_y(d: float) -> float:
	var y := 0.0
	var v := float(knob("speed"))
	for beat: Dictionary in beats():
		if beat.kind != "D": continue
		var t: float = (d-float(beat.at))/v
		var dv := _dive_numbers()
		var tc := float(knob("climb"))
		var h := float(knob("height"))
		if t <= 0.0 or t >= tc+dv.plunge+dv.out: continue
		if t < tc: y += h*smoothstep(0.0,1.0,t/tc)
		elif t < tc+dv.plunge:
			var u: float = t-tc
			y += h-0.5*dv.a*u*u
		else:
			var u: float = t-tc-dv.plunge
			y += h-dv.d1-(dv.v1*u-0.5*dv.b*u*u)
	return y

## The pitch the dives give at `d` (+ nose up): up through the climb, down
## through the plunge and the pull-out, each a smooth swell to max_pitch
## (the path's own slope is far steeper: a back that followed it would be
## a wall).
func _dive_pitch(d: float) -> float:
	var v := float(knob("speed"))
	var tc := float(knob("climb"))
	var most := float(knob("max_pitch"))
	var out := 0.0
	for beat: Dictionary in beats():
		if beat.kind != "D": continue
		var dv := _dive_numbers()
		var t: float = (d-float(beat.at))/v
		var down: float = dv.plunge+dv.out
		if t <= 0.0 or t >= tc+down: continue
		if t < tc: out += most*sin(PI*t/tc)
		else: out -= most*sin(PI*(t-tc)/down)
	return out

## The bank the beats ask at `d` (+ right wing up, left low).
func _beat_bank(d: float) -> float:
	var v := float(knob("speed"))
	var roll := maxf(float(knob("roll")),0.05)
	var hold := float(knob("hold"))
	var out := 0.0
	for beat: Dictionary in beats():
		if beat.kind == "D": continue
		var t: float = (d-float(beat.at))/v
		if t <= 0.0 or t >= 2.0*roll+hold: continue
		var k := smoothstep(0.0,1.0,t/roll)*(1.0-smoothstep(0.0,1.0,(t-roll-hold)/roll))
		out += k*float(beat.size)*(1.0 if beat.kind == "L" else -1.0)
	return out

## Banked into the turns by `turn_bank` (rad), eased in and out over its
## roll.
func _turn_bank(d: float) -> float:
	var tb := float(knob("turn_bank"))
	if tb == 0.0: return 0.0
	var ease := float(knob("speed"))*float(knob("roll"))
	var sum := 0.0
	for i in range(5):
		sum += curvature_at(d+ease*(float(i)/4.0-0.5))
	return tb*sum/5.0*float(knob("radius"))

## The ray's frame (local to the trap) at `d` (m, unwrapped).
func pose_at(d: float) -> Transform3D:
	var dw := fposmod(d,loop_length())
	var p := path_at(dw)
	var ptch := _dive_pitch(dw)
	var wobble := float(knob("shake"))*sin(d/float(knob("speed"))*float(knob("shake_rate")))
	var bk := _beat_bank(dw)+_turn_bank(dw)+wobble
	# Held under the motor's own slide angle.
	var steepest := deg_to_rad(PilotMotor.SLIDE_AUTO-TILT_MARGIN)
	var most := acos(clampf(cos(steepest)/cos(ptch),-1.0,1.0))
	bk = clampf(bk,-most,most)
	var basis := Basis(Vector3.UP,heading_at(dw))*Basis(Vector3.RIGHT,ptch)*Basis(Vector3(0.0,0.0,1.0),bk)
	return Transform3D(basis,p)

## The beats laid afresh from the knobs (after changing them).
func replan() -> void:
	_plan = []
	_dive = {}

func build() -> void:
	replan()
	s = near_at(0.0)-float(knob("speed"))*float(knob("arrive"))
	var w := float(knob("width"))
	var l := float(knob("long"))
	var th := float(knob("thick"))
	body = StaticBody3D.new()
	add_child(body)
	# A thin hide out to the rim over a thick body inset from it, as a
	# ray's wings thin to their edge: slid past the rim there is nothing
	# under his feet to stand on, only the lip to catch.
	var hide := float(knob("hide"))
	var inset := float(knob("inset"))
	_add(Vector3(0.0,-hide*0.5,0.0),Vector3(w,hide,l),paint(SKIN),true)
	_add(Vector3(0.0,-hide-(th-hide)*0.5,0.0),Vector3(w-2.0*inset,th-hide,l-2.0*inset),paint(SKIN),true)
	# Ridges on its back: two along it, near each rim, the left one forward
	# and the right one aft with open back between (cover from a bank's
	# slide, if he gets behind the right one in time), two across it (from
	# a pitch's).
	var rh: float = pilot().jumps[0]*0.7
	var rt: float = Ground.RADIUS*2.0*WorldScale.wanderer
	ridges = []
	for r: Array in [[-w*0.3,-l*0.25,rt,l*0.3],[w*0.3,l*0.25,rt,l*0.3],[w*0.12,-l*0.38,w*0.3,rt],[-w*0.12,l*0.38,w*0.3,rt]]:
		_add(Vector3(r[0],rh*0.5,r[1]),Vector3(r[2],rh,r[3]),paint(RIDGE),true)
		ridges.append([Rect2(r[0]-r[2]*0.5,r[1]-r[3]*0.5,r[2],r[3]),rh])
	# The head (it dips), a tail, and the wing edges (they lift).
	head = _add(Vector3(0.0,-th*0.5,-l*0.5-0.9),Vector3(w*0.3,th*0.8,1.8),paint(HEAD_COLOUR),false)
	_add(Vector3(0.0,-th*0.5,l*0.5+1.4),Vector3(0.4,th*0.5,2.8),paint(HEAD_COLOUR),false)
	for side in [-1.0,1.0]:
		var m := paint(WING)
		wing_mats.append(m)
		var wing := _add(Vector3(side*(w*0.5+0.5),-th*0.5,0.0),Vector3(1.0,th*0.4,l*0.8),m,false)
		if side < 0.0: wing_l = wing
		else: wing_r = wing
	_pose()

## A box of the creature: with collision if `solid`.
func _add(at: Vector3, size: Vector3, mat: StandardMaterial3D, solid: bool) -> MeshInstance3D:
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = at
	mesh.material_override = mat
	body.add_child(mesh)
	return mesh

func _pose() -> void:
	if body == null: return
	body.transform = pose_at(s)
	# Straight to the physics server: a node's move reaches it only when the
	# tree flushes its transform notifications, after this frame's step, so
	# the motor's ground rays would read the back where it was a frame ago.
	if body.is_inside_tree(): PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
	var b := body.transform.basis
	pitch = asin(clampf(b.z.y*-1.0,-1.0,1.0))
	bank = atan2(b.x.y,b.y.y)

## Is `feet` (world) on its back (grounded there)?
func on_back(feet: Vector3) -> bool:
	var l := local_of(feet)
	return absf(l.x) <= float(knob("width"))*0.5+0.1 and absf(l.z) <= float(knob("long"))*0.5+0.1 and l.y >= -0.3 and l.y <= pilot().jumps[0]*0.7+0.4

## `p` (world) in the back's frame (its top at y 0).
func local_of(p: Vector3) -> Vector3:
	return body.transform.affine_inverse()*to_local(p)

## Is he holding its rim (catching, hanging, climbing onto it)?
func holds_rim() -> bool:
	if motor == null or not motor.on_ledge(): return false
	var l := local_of(motor.lip)
	return absf(l.x) <= float(knob("width"))*0.5+0.3 and absf(l.z) <= float(knob("long"))*0.5+0.3 and absf(l.y) <= 0.4

## The world point that is `local` (the back's frame) at `d`.
func _point(d: float, local: Vector3) -> Vector3:
	return global_transform*(pose_at(d)*local)

## The velocity (m/s) and acceleration (m/s²) of the back's point `local`,
## at `d` (m along the loop; now if NAN).
func velocity_of(local: Vector3, d := NAN) -> Vector3:
	if is_nan(d): d = s
	var v := float(knob("speed"))
	var e := v/60.0
	return (_point(d+e,local)-_point(d-e,local))/(2.0*e)*v

func acceleration_of(local: Vector3, d := NAN) -> Vector3:
	if is_nan(d): d = s
	var v := float(knob("speed"))
	var e := v/60.0
	return (_point(d+e,local)-2.0*_point(d,local)+_point(d-e,local))/(e*e)*v*v

## The back's up (world).
func normal() -> Vector3:
	return (global_transform.basis*body.transform.basis*Vector3.UP).normalized()

func before(delta: float) -> void:
	if body == null or delta <= 0.0: return
	var riding := motor != null and motor.rider == null and not motor.swimming and not motor.recovering() \
		and ((motor.grounded and on_back(motor.feet)) or holds_rim())
	_was_riding = riding
	_tossed = false
	var was := body.transform
	var was_d := s
	# Where he is on its back, before it moves.
	var lp := local_of(motor.lip if riding and motor.on_ledge() else motor.feet) if riding else Vector3.ZERO
	s += float(knob("speed"))*delta
	clock = s/float(knob("speed"))
	_pose()
	if not riding:
		slip = Vector2.ZERO
		_tells()
		return
	riding_time += delta
	# Its velocity under him as the frame begins: what he keeps leaving it.
	_v_point = velocity_of(lp,was_d)
	# On his feet: lifted off, slid, or thrown over the rim, worked out
	# before the carry (off, he flies on from where he was at its velocity
	# as the frame began, as it moves on under him).
	var to := lp
	if motor.grounded:
		to = _slide(delta,lp,was_d)
		if _tossed:
			_tells()
			return
	else: slip = Vector2.ZERO
	var moved := global_transform*(body.transform*was.affine_inverse())*global_transform.affine_inverse()
	motor.carry(moved,wrapf(heading_at(s)-heading_at(was_d),-PI,PI))
	if to != lp: motor.carry(Transform3D(Basis.IDENTITY,global_transform.basis*(body.transform.basis*(to-lp))),0.0)
	_tells()

## On its back at `lp` (its frame): lifted off where it drops away faster
## than he falls, else slid by gravity along the back and the swing of its
## flight, held by friction, stopped by the ridges; over the rim fast,
## thrown, slower left to the motor's catch. Where he slides to (its frame).
func _slide(delta: float, lp: Vector3, was_d: float) -> Vector3:
	var on := Vector3(lp.x,0.0,lp.z)
	var a := acceleration_of(on,was_d+float(knob("speed"))*delta*0.5)
	var n := normal()
	var g_air: float = motor.gravity*(motor.fall if _v_point.y <= 0.0 else 1.0)
	if (a-Vector3.DOWN*g_air).dot(n) < 0.0:
		# Lighter than nothing: off it, floating with its way.
		_off(_v_point,false)
		return lp
	if motor.move == "slide":
		# Surfing (crouched on a slope): the motor slides him itself.
		slip = Vector2.ZERO
		return lp
	var g := Vector3.DOWN*motor.gravity
	var load := (a-g).dot(n)
	last_load = load
	var along := float(knob("pull"))*(g-g.dot(n)*n)-float(knob("swing"))*(a-a.dot(n)*n)
	var to_back := (global_transform.basis*body.transform.basis).inverse()
	var pl := to_back*along
	var pull := Vector2(pl.x,pl.z)
	var hl := to_back*Vector3(motor.velocity.x,0.0,motor.velocity.z)
	var walk := Vector2(hl.x,hl.z)
	var lean := 0.0
	if pull.length() > 1e-3: lean = clampf(walk.dot(-pull.normalized())/maxf(float(knob("lean_pace")),0.01),0.0,1.0)
	var mu := float(knob("grip"))+float(knob("lean"))*lean
	last_grip = mu
	var cap := mu*maxf(load,0.0)
	if slip.length() < 0.05 and pull.length() <= cap:
		slip = Vector2.ZERO
	else:
		slip += pull*delta
		var pace := maxf(slip.length()-cap*delta,0.0)
		slip = slip.normalized()*pace if slip.length() > 1e-5 else Vector2.ZERO
	if slip == Vector2.ZERO: return lp
	var to := lp+Vector3(slip.x,0.0,slip.y)*delta
	to = _ridged(lp,to,lp.y)
	var w := float(knob("width"))*0.5
	var l := float(knob("long"))*0.5
	if (absf(to.x) > w or absf(to.z) > l) and slip.length() > float(knob("catch_pace")) and lean < 0.3:
		# Over the rim too fast to take it: thrown off.
		throws += 1
		_off(_v_point+global_transform.basis*(body.transform.basis*Vector3(slip.x,0.0,slip.y)),true)
		return lp
	return to

## A slide from `from` to `to` (the back's frame) stopped by the ridges:
## his body (its radius) kept out of them, the slide into one ended.
func _ridged(from: Vector3, to: Vector3, y: float) -> Vector3:
	var rad: float = Ground.RADIUS*WorldScale.wanderer
	for r: Array in ridges:
		if y > float(r[1])-0.1: continue
		var box: Rect2 = (r[0] as Rect2).grow(rad)
		var p := Vector2(to.x,to.z)
		if not box.has_point(p): continue
		var was := Vector2(from.x,from.z)
		if was.x <= box.position.x or was.x >= box.end.x:
			to.x = box.position.x-0.001 if was.x <= box.position.x else box.end.x+0.001
			slip.x = 0.0
		elif was.y <= box.position.y or was.y >= box.end.y:
			to.z = box.position.y-0.001 if was.y <= box.position.y else box.end.y+0.001
			slip.y = 0.0
	return to

## Off its back at `v` (world, m/s) with his own run on it, facing kept.
func _off(v: Vector3, thrown: bool) -> void:
	if not thrown: floats += 1
	var face: float = motor.facing
	motor.toss(v+Vector3(motor.velocity.x,0.0,motor.velocity.z))
	motor.facing = face
	slip = Vector2.ZERO
	_tossed = true

## After his step: off its back by his own doing (a jump, a step off, let
## go), he keeps its velocity; landed on it, his run is taken relative to it.
func after(_delta: float, events: Dictionary) -> void:
	if body == null or motor == null: return
	if _was_riding and not _tossed and not motor.grounded and not motor.on_ledge() and not motor.swimming:
		motor.velocity += _v_point
	if events.has("landed") and motor.grounded and on_back(motor.feet):
		var v := velocity_of(local_of(motor.feet))
		motor.velocity.x -= v.x
		motor.velocity.z -= v.z
		slip = Vector2.ZERO

## The beat coming (or under way, for a bank's roll-in), and how far off:
## {beat, lead (s to its moment: a bank's start, a dive's plunge)}, or {}.
func next_beat() -> Dictionary:
	var v := float(knob("speed"))
	var d := fposmod(s,loop_length())
	var best := {}
	for beat: Dictionary in beats():
		var moment: float = float(beat.at)+(float(beat.plunge) if beat.kind == "D" else 0.0)
		var lead := (moment-d)/v
		var after_by := float(knob("roll")) if beat.kind != "D" else 0.0
		if lead < -after_by: continue
		if best.is_empty() or lead < float(best.lead): best = {"beat":beat,"lead":lead}
	return best

## Head down before a dive, the wing that will rise up before a bank.
func _tells() -> void:
	var tell := maxf(float(knob("tell")),0.05)
	var dive := 0.0
	var lift := 0.0
	var rising: MeshInstance3D = null
	var coming := next_beat()
	if not coming.is_empty():
		var beat: Dictionary = coming.beat
		var amount := clampf(1.0-float(coming.lead)/tell,0.0,1.0)
		if beat.kind == "D": dive = amount
		else:
			lift = amount
			rising = wing_l if beat.kind == "R" else wing_r
	head.rotation.x = -dive*0.6
	head.position.y = -float(knob("thick"))*0.5-dive*0.5
	for wing: MeshInstance3D in [wing_l,wing_r]:
		var up := lift if wing == rising else 0.0
		wing.rotation.z = up*0.5*(1.0 if wing == wing_r else -1.0)
		wing.position.y = -float(knob("thick"))*0.5+up*0.5
	wing_mats[0].albedo_color = WING.lerp(TELL,lift if rising == wing_l else 0.0)
	wing_mats[1].albedo_color = WING.lerp(TELL,lift if rising == wing_r else 0.0)
	if lift > 0.05 and _whoosh_ready:
		_whoosh_ready = false
		tell_sound(&"whoosh",to_global(body.position))
	elif lift == 0.0: _whoosh_ready = true
	if dive > 0.05 and _screech_ready:
		_screech_ready = false
		tell_sound(&"screech",to_global(body.position))
	elif dive == 0.0: _screech_ready = true
	tell_sight(maxf(lift,dive))

func reset() -> void:
	super()
	replan()
	# Coming up the near straight, at the start deck `arrive` s from now.
	s = near_at(0.0)-float(knob("speed"))*float(knob("arrive"))
	clock = 0.0
	slip = Vector2.ZERO
	riding_time = 0.0
	floats = 0
	throws = 0
	_whoosh_ready = true
	_screech_ready = true
	_was_riding = false
	_tossed = false
	_pose()
