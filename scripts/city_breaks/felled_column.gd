extends Node3D
## The felled column, maker_felled: a free-standing
## drum column of the makers on a stepped plinth (scripts/city_kit_breaks.gd
## has its numbers and its stone). Lure the Olmec into it and the side he
## hits decides which way it goes.
##
## A two-way hinge along its authored fall axis (the piece's X): met by his
## bulk (`met`) or by his landing's shockwave within FELL_SHOCK m (`wave`),
## it goes over to the side away from the hit (the hit's way along the axis;
## square across it, the way he walks). The drums snap off the plinth's
## top, a ragged pale stub left there, and the stack goes over about the
## plinth's edge, slow at first (TOPPLE_W0, a rod's fall under gravity:
## about 2.4 s), its foot kicked off the plinth onto the ground in the last
## quarter. Scripted, not simulated (the three-state rule: its rest is
## authored), so no Jolt bodies:
##   bridge  a gap under its rest line and a rim for its far end: the drums
##           come to rest across it as one span on both rims, their
##           joints opened a hand's width; the capital snaps off and turns
##           over onto its abacus on the far side.
##   ground  ground all along: it bursts where it hits; the three top drums
##           bounce, turn across and roll on along the fall up to 6 m
##           (`maker_drum`, a log trap), the capital turns over past them.
##   abyss   nothing under its far end: it goes over the edge and is gone.
## Settled, the rest is ground and wall to both bodies (not rubble: the
## Olmec doesn't wade a 5.5 m drum), and the bodies' routes read it afresh
## (the hub's `changed`): his planner sees the bridge.
##
## The wanderer: standing on its top when it goes he is tossed off along the
## fall (`toss`); under the falling shaft he is knocked out from under it,
## across the fall (`knock`, source "maker_felled"); in a rolling drum's way,
## knocked along its roll (or tossed on, stunned: source "maker_drum").
const K = preload("res://scripts/city_kit_breaks.gd")
const Dust = preload("res://scripts/breaks/body_dust.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")

## Its first turn (rad/s), more per m/s of his push; the fall's pull (a
## rod's 3g/2L, at this scale), the shockwave's reach to fell it (m).
const TOPPLE_W0 := 0.3
const TOPPLE_PUSH := 0.05
const TOPPLE_PUSH_MOST := 0.12
const PULL := 0.95
const FELL_SHOCK := 10.0
## The foot kicked off the plinth over this span of the turn (rad).
const KICK_FROM := 0.3*PI
## At rest: the bounce (m, s), the joints opened (m a joint, s).
const BOUNCE := Vector2(0.22,0.28)
const SEAM_OPEN := Vector2(0.07,0.2)
## The capital turned over (s), its rebound (rad).
const FLIP_T := 0.6
const FLIP_BACK := 0.12
## The rolls (ground): the top drums, their way across at rest (m) and how
## far each rolls (m), its pace off the burst (m/s).
const ROLLERS := 3
const ROLL := [Vector2(2.0,0.0),Vector2(4.6,5.6),Vector2(6.0,-5.9)]
const ROLL_V := 6.5
## Every rest shape's foot is kept LIFT m clear of what it rests on (drawn
## down to it): the Olmec's planner reads a column's floors top-down and
## measures each one's room by a ray up from 0.1 m over it, so a solid flush
## on the ground left a floor under it with room to its neck. A lying
## drum's collider sits LIE_UP higher and LIE_IN thinner (its crown where
## the drawn barrel's is).
const LIFT := 0.15
const LIE_UP := 0.12
const LIE_IN := 0.04
## The hits on the wanderer: under it (m out, m up, m/s along the fall), a
## rolling drum's (m/s along, m/s up), on it (m/s along, up).
const UNDER := Vector3(7.0,2.0,0.6)
const DRUM_HIT := Vector2(9.0,4.5)
const ON_TOSS := Vector2(5.0,5.0)
## The hit-stop when he meets it (frames, time scale), the ground's shake.
const HITSTOP := 4
const HITSTOP_SCALE := 0.12
const QUAKE_HIT := 0.5
const QUAKE_FALL := 1.4

## "standing", "falling", "settled".
var state := "standing"
## The rest it went to: "bridge", "ground", "abyss" ("" standing).
var how := ""
## Along +X (1) or -X (-1), its piece frame; what felled it ("body", "shock").
var fall_sign := 0.0
var cause := ""
## The fall's angle (rad) and turn (rad/s); time since it hit (s, -1 not yet).
var theta := 0.0
var omega := 0.0
var since_hit := -1.0
## The hits it dealt the wanderer: [source, kind].
var dealt: Array = []
## Seconds from the hit to coming to rest (for the handoff).
var fall_s := 0.0
var seed_value := 1
var weathered := 0.0

var mesh: MeshInstance3D
var body: StaticBody3D
var shaft: Node3D
var shaft_body: StaticBody3D
var fallen: StaticBody3D
var drums: Array[MeshInstance3D] = []
var capital: MeshInstance3D
## Live pieces past the hit: {node, kind ("roll", "flip"), from (Transform3D), ...}.
var _live: Array = []
var _yaws: Array[float] = []
var _hub: Node = null
var _hit_kinds := {}
var _on_top := false
## The sources the wanderer is hit by (the motor's per-source stun gap).
var src_felled: Node
var src_drum: Node
static var _drum_mesh: ArrayMesh = null
static var _capital_mesh: ArrayMesh = null

func build(seed_in: int, weathered_in := 0.0) -> void:
	seed_value = seed_in
	weathered = weathered_in
	name = "maker_felled"
	add_to_group(K.BREAKABLE)
	src_felled = Node.new()
	src_felled.name = "maker_felled"
	add_child(src_felled)
	src_drum = Node.new()
	src_drum.name = "maker_drum"
	add_child(src_drum)
	_stand()

## As built: whole, on its plinth.
func _stand() -> void:
	state = "standing"
	how = ""
	theta = 0.0
	omega = 0.0
	since_hit = -1.0
	fall_s = 0.0
	dealt.clear()
	_hit_kinds.clear()
	_live.clear()
	for n in [mesh,body,shaft,shaft_body,fallen,capital,spall]:
		if is_instance_valid(n): (n as Node).free()
	for n in get_children():
		if String(n.name).begins_with("Drum"): n.free()
	fallen = null
	shaft_body = null
	spall = null
	drums.clear()
	if _drum_mesh == null: _drum_mesh = K.drum_mesh(7)
	if _capital_mesh == null: _capital_mesh = K.capital_mesh(7)
	mesh = MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = K.plinth_mesh(false,seed_value)
	add_child(mesh)
	body = StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	var rise := K.plinth_rise()
	for i in K.PLINTH.size():
		var half: float = K.PLINTH[i]
		_shape(body,_box(Vector3(half*2.0,rise-LIFT,half*2.0)),Transform3D(Basis.IDENTITY,Vector3(0.0,rise*(i+0.5)+LIFT*0.5,0.0)))
	shaft = Node3D.new()
	shaft.name = "Shaft"
	add_child(shaft)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*31+5
	_yaws.clear()
	var top := K.plinth_top()
	for k in K.DRUMS:
		var d := MeshInstance3D.new()
		d.name = "Drum%d" % k
		d.mesh = _drum_mesh
		_yaws.append(rng.randf_range(-PI,PI))
		d.transform = Transform3D(Basis(Vector3.UP,_yaws[k]),Vector3(0.0,top+(k+0.5)*K.DRUM_H,0.0))
		shaft.add_child(d)
		drums.append(d)
	capital = MeshInstance3D.new()
	capital.name = "Capital"
	capital.mesh = _capital_mesh
	capital.transform = Transform3D(Basis(Vector3.UP,rng.randf_range(-0.2,0.2)),Vector3(0.0,top+K.DRUMS*K.DRUM_H,0.0))
	shaft.add_child(capital)
	# Standing: the shaft and the capital, one body (air to the Olmec: the
	# hub leaves it out of his rays, so he walks into it).
	shaft_body = StaticBody3D.new()
	shaft_body.name = "ShaftBody"
	add_child(shaft_body)
	var tall := K.DRUMS*K.DRUM_H
	_shape(shaft_body,_cyl(K.DRUM_R,tall),Transform3D(Basis.IDENTITY,Vector3(0.0,top+tall*0.5,0.0)))
	_shape(shaft_body,_cyl(K.DRUM_R+K.ECHINUS.y*0.6,K.ECHINUS.x),Transform3D(Basis.IDENTITY,Vector3(0.0,top+tall+K.ECHINUS.x*0.5,0.0)))
	_shape(shaft_body,_box(Vector3(K.ABACUS.x,K.ABACUS.y,K.ABACUS.x)),Transform3D(Basis.IDENTITY,Vector3(0.0,top+tall+K.ECHINUS.x+K.ABACUS.y*0.5,0.0)))

## Whole again (a study's reset).
func reset() -> void:
	_stand()

func _shape(on: CollisionObject3D, shape: Shape3D, xf: Transform3D) -> void:
	var c := CollisionShape3D.new()
	c.shape = shape
	c.transform = xf
	on.add_child(c)

func _cyl(r: float, h: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	return s

func _box(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s

# --- What the hub asks ---------------------------------------------------------------------

func standing_rids() -> Array[RID]:
	var out: Array[RID] = []
	if state == "standing" and shaft_body != null and is_instance_valid(shaft_body): out.append(shaft_body.get_rid())
	return out

func rubble_rids() -> Array[RID]:
	return []

## The world's axis (flat, unit) it falls along.
func axis() -> Vector3:
	var x := global_transform.basis.x
	return Vector3(x.x,0.0,x.z).normalized()

## His bulk (the box his push-out has) against the shaft standing.
func met(hub: Node, b: Node3D) -> void:
	if state != "standing": return
	var hh: float = b.hh
	var low: float = b.position.y+0.3
	var high: float = b.position.y+float(b._bulk_top())
	var base := global_position.y+K.plinth_top()
	if high < base or low > global_position.y+K.column_h(): return
	var c := global_position
	var rel := Basis(Vector3.UP,float(b.facing)).inverse()*(c-b.position)
	if absf(rel.x) > hh*HeadlessBody.BULK_W+K.DRUM_R or absf(rel.z) > hh*HeadlessBody.BULK_L+K.DRUM_R: return
	var ax := axis()
	var along := (c-b.position).dot(ax)
	if absf(along) < 0.8: along = (b._forward3() as Vector3).dot(ax)
	var push := Vector2(b.vel.x,b.vel.z).length()
	b.stagger(0.6)
	hub.pause(HITSTOP,HITSTOP_SCALE)
	hub.shake(QUAKE_HIT)
	fell(hub,1.0 if along >= 0.0 else -1.0,"body",push)

## His landing's shockwave `w` (at, r its front, max, power) reaching it
## within FELL_SHOCK m: it goes over away from where he landed.
func wave(hub: Node, _b: Node3D, w: Dictionary) -> void:
	if state != "standing": return
	var at: Vector3 = w.at
	var c := global_position
	var d := Vector2(c.x-at.x,c.z-at.z).length()
	if d > float(w.r) or d > minf(FELL_SHOCK,float(w.max))+K.DRUM_R or absf(at.y-c.y) > 6.0: return
	var along := (c-at).dot(axis())
	if absf(along) < 1.0: return
	hub.shake(QUAKE_HIT)
	fell(hub,signf(along),"shock",1.0)

## The hub's `hit` from a breaker that is on (scripts/breaks/breakables.gd):
## taken as his landing's shockwave at `at`, grown to `radius`, of power
## `strength` (it fells away from the hit, as ever). The slam is nothing to
## a column. True if it went over.
func take_hit(hub: Node, at: Vector3, radius: float, strength: float, source: StringName) -> bool:
	if state != "standing" or source == &"slam": return false
	wave(hub,null,{"at":at,"r":radius,"max":radius,"power":strength,"t":0.0})
	return state != "standing"

## A brute's veer (as the colonnade's piers): standing just off his way
## ahead, it draws him round into it, a little.
func veer(_hub: Node, b: Node3D, heading: float) -> float:
	if state != "standing": return heading
	var p: Vector3 = b.position
	var fwd := PilotMotor.forward(heading)
	var right := Vector2(-fwd.y,fwd.x)
	var hw: float = float(b.hh)*HeadlessBody.BULK_W
	var rel := Vector2(global_position.x-p.x,global_position.z-p.z)
	var ahead := rel.dot(fwd)
	var off := rel.dot(right)
	if ahead < 1.0 or ahead > 10.0 or absf(off) < hw*0.5 or absf(off) > hw+K.DRUM_R+3.0: return heading
	var want := PilotMotor.facing_of((rel-right*signf(off)*hw*0.5).normalized())
	return wrapf(heading+clampf(angle_difference(heading,want),-0.3,0.3),-PI,PI)

func takes_shock(_hub: Node, _b: Node3D, _w: Dictionary) -> bool:
	return false

# --- The fall --------------------------------------------------------------------------------

## Felled toward `sign` (its X), by `why`, his push `push` m/s.
func fell(hub: Node, sign: float, why: String, push := 0.0) -> void:
	if state != "standing": return
	_hub = hub
	state = "falling"
	fall_sign = sign
	cause = why
	theta = 0.0
	omega = TOPPLE_W0+minf(TOPPLE_PUSH*push,TOPPLE_PUSH_MOST)
	how = _rest_kind()
	shaft_body.free()
	shaft_body = null
	# The stub left on the plinth: ragged, pale, ground.
	mesh.mesh = K.plinth_mesh(true,seed_value)
	_shape(body,_cyl(K.DRUM_R,K.STUB-LIFT),Transform3D(Basis.IDENTITY,Vector3(0.0,K.plinth_top()+(K.STUB+LIFT)*0.5,0.0)))
	# The drums into the hinge's frame (where they stood).
	for k in K.DRUMS:
		drums[k].transform = Transform3D(Basis(Vector3.UP,_yaws[k]),Vector3(-K.DRUM_R,(k+0.5)*K.DRUM_H,0.0))
	capital.transform = Transform3D(capital.transform.basis,Vector3(-K.DRUM_R,K.DRUMS*K.DRUM_H,0.0))
	shaft.transform = _frame(0.0)
	var at := to_global(Vector3(0.0,K.plinth_top(),0.0))
	Dust.plume(get_parent(),at,6.0)
	Dust.rocks(get_parent(),at+Vector3.UP*0.5,_dir_world(),14,0.35)
	hub.sound(&"ruin_crack",at)
	hub.sound(&"ruin_fall",at+Vector3.UP*8.0)
	# On its top as it goes: thrown off along the fall.
	var m: PilotMotor = hub.motor()
	if m != null and m.grounded and _on_shaft_top(m.feet):
		var dw := _dir_world()
		_hit(m,"on",Vector3(dw.x*ON_TOSS.x,ON_TOSS.y,dw.z*ON_TOSS.x),true)

func _dir_world() -> Vector3:
	return axis()*fall_sign

## Its rest by the ground along the line it will lie on: "bridge" (a gap
## spanned, rims under both ends), "ground" or "abyss".
func _rest_kind() -> String:
	var space := get_world_3d().direct_space_state
	var from := K.felled_from()
	var length := K.felled_length()
	var gap := false
	var near_rim := false
	var far_rim := false
	var u := from+0.3
	while u <= from+length-0.2:
		var p := to_global(Vector3(fall_sign*u,0.0,0.0))
		var q := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.0,p+Vector3.DOWN*3.0,1,[body.get_rid()])
		var hit := space.intersect_ray(q)
		var ground := not hit.is_empty()
		if u < from+K.BEARING and ground: near_rim = true
		if u > from+length-K.BEARING and ground: far_rim = true
		if not ground: gap = true
		u += 0.5
	if not gap: return "ground"
	return "bridge" if near_rim and far_rim else "abyss"

## The hinge's frame (piece space) at angle `t`: about the plinth's edge,
## the foot kicked off it onto the ground (KICK_FROM on).
func _frame(t: float) -> Transform3D:
	var x := Vector3(fall_sign,0.0,0.0)
	var b0 := Basis(x,Vector3.UP,x.cross(Vector3.UP))
	var p0 := Vector3(fall_sign*K.DRUM_R,K.plinth_top(),0.0)
	var p1 := Vector3(fall_sign*K.felled_from(),0.0,0.0)
	var s := smoothstep(KICK_FROM,PI*0.5,t) if how != "abyss" else 0.0
	return Transform3D(b0*Basis(Vector3(0.0,0.0,1.0),-t),p0.lerp(p1,s))

var _changed_box := AABB()
var _changed_in := 0

func _physics_process(delta: float) -> void:
	if _changed_in > 0:
		_changed_in -= 1
		if _changed_in == 0 and _hub != null: _hub.changed(_changed_box)
	if state != "falling": return
	fall_s += delta
	var m: PilotMotor = _hub.motor() if _hub != null else null
	if since_hit < 0.0:
		omega += PULL*sin(theta+0.05)*delta
		theta += omega*delta
		if how == "abyss":
			shaft.transform = _frame(theta)
			if theta > PI*0.5: shaft.position.y -= (theta-PI*0.5)*8.0
			if theta > PI*1.1:
				shaft.visible = false
				_rest()
			return
		if theta >= PI*0.5:
			theta = PI*0.5
			_impact()
		else:
			shaft.transform = _frame(theta)
			if m != null and theta > 0.12: _under(m)
		return
	since_hit += delta
	var base := _frame(PI*0.5)
	var bounce := BOUNCE.x*sin(PI*minf(since_hit/BOUNCE.y,1.0))*(1.0 if since_hit < BOUNCE.y else 0.0)
	base.origin.y += bounce
	shaft.transform = base
	var open := smoothstep(0.0,SEAM_OPEN.y,since_hit)*SEAM_OPEN.x
	for k in K.DRUMS:
		if not drums[k].get_parent() == shaft: continue
		var t: Transform3D = drums[k].transform
		t.origin = Vector3(-K.DRUM_R,(k+0.5)*K.DRUM_H+k*open,0.0)
		drums[k].transform = t
	var busy := false
	for p: Dictionary in _live:
		if _step_live(p,delta,m): busy = true
	if not busy and since_hit > BOUNCE.y+0.1: _rest()

## Its top along the fall hits the ground: dust down the line, the shake,
## the capital and (on the ground) the top drums go on.
func _impact() -> void:
	since_hit = 0.0
	var dw := _dir_world()
	var from := K.felled_from()
	var u := from
	while u <= from+K.felled_length()+0.1:
		var p := to_global(Vector3(fall_sign*u,0.0,0.0))
		Dust.plume(get_parent(),p+Vector3.UP*0.3,4.5+u*0.12)
		u += 3.0
	Dust.rocks(get_parent(),to_global(Vector3(fall_sign*(from+K.felled_length()),1.0,0.0)),dw,18,0.4)
	_hub.sound(&"ruin_boom",to_global(Vector3(fall_sign*(from+K.felled_length()*0.5),0.0,0.0)))
	_hub.sound(&"ruin_thud",to_global(Vector3(fall_sign*from,0.0,0.0)))
	_hub.shake(QUAKE_FALL)
	_hub.pause(3,0.2)
	# The bottom drum's foot spalls off as the shaft kicks off the plinth: a
	# pale chunk wedged between the plinth and the shaft's end, the authored
	# step from the stub up onto the crown.
	if how != "abyss":
		_lay_spall()
	# The capital snaps off: turned over onto its abacus past the end.
	var cx := capital.global_transform
	shaft.remove_child(capital)
	add_child(capital)
	capital.global_transform = cx
	var lift := maxf(0.0,K.ABACUS.x*0.5-K.DRUM_R)
	var c0 := capital.transform
	c0.origin.y += lift
	var pivot := Vector3(fall_sign*(from+K.felled_length()+K.capital_h()),0.0,0.0)
	_live.append({"node":capital,"kind":"flip","from":c0,"pivot":pivot,"t":0.0})
	if how == "ground":
		for i in ROLLERS:
			var k := K.DRUMS-ROLLERS+i
			var d := drums[k]
			var dx := d.global_transform
			shaft.remove_child(d)
			add_child(d)
			d.global_transform = dx
			var at := d.position
			var roll: Vector2 = ROLL[i]
			var to := Vector3(at.x+fall_sign*roll.x,K.DRUM_R,roll.y)
			_live.append({"node":d,"kind":"roll","at":at,"to":to,"t":0.0,"T":2.0*roll.x/ROLL_V+0.35,"yaw":_yaws[k],"v":0.0})

## The spall's size (m: along the fall, up, across) and its top under the
## crown (a hop up onto the drums from it).
const SPALL := Vector3(1.6,3.3,3.6)
## Its collision's height (its foot kept clear of the plinth's step under it).
const SPALL_TALL := 2.9
const SPALL_UNDER := 0.85
var spall: MeshInstance3D

func _lay_spall() -> void:
	var m := K.Mesher.new()
	m.box(Transform3D.IDENTITY,SPALL,0.25,-SPALL.y*0.5,1.3)
	spall = MeshInstance3D.new()
	spall.name = "Spall"
	spall.mesh = K.mesh_of(m)
	var top := K.DRUM_R*2.0-SPALL_UNDER
	var x := K.felled_from()-SPALL.x*0.5-0.05
	spall.transform = Transform3D(Basis(Vector3(0.0,0.0,1.0),fall_sign*0.06)*Basis(Vector3.UP,0.08),Vector3(fall_sign*x,top-SPALL.y*0.5,0.0))
	add_child(spall)
	Dust.plume(get_parent(),to_global(Vector3(fall_sign*x,0.5,0.0)),4.0)

## A piece after the hit, a frame: true while it moves.
func _step_live(p: Dictionary, delta: float, m: PilotMotor) -> bool:
	p.t += delta
	var node: Node3D = p.node
	var t: float = p.t
	if p.kind == "flip":
		# Over about its abacus's edge, gravity's ease-in, then a rebound.
		var a := 0.0
		if t < FLIP_T: a = PI*0.5*pow(t/FLIP_T,2.0)
		elif t < FLIP_T+0.3: a = PI*0.5-FLIP_BACK*sin(PI*(t-FLIP_T)/0.3)
		else: a = PI*0.5
		var axis_l := Vector3(0.0,1.0,0.0).cross(Vector3(fall_sign,0.0,0.0)).normalized()
		var r := Transform3D(Basis(axis_l,a),Vector3.ZERO)
		var piv: Vector3 = p.pivot
		var from: Transform3D = p.from
		node.transform = Transform3D(Basis.IDENTITY,piv)*r*Transform3D(Basis.IDENTITY,-piv)*from
		if t >= FLIP_T and not p.get("landed",false):
			p["landed"] = true
			Dust.plume(get_parent(),to_global(piv+Vector3(fall_sign*K.ABACUS.x*0.5,0.3,0.0)),5.0)
			_hub.sound(&"ruin_thud",node.global_position)
			_hub.shake(QUAKE_HIT)
		return t < FLIP_T+0.3
	# A drum: bounced off the burst, turned across, then rolling on.
	var at: Vector3 = p.at
	var to: Vector3 = p.to
	var hop := 0.35
	var big_t: float = p.T
	var yaw: float = p.yaw
	var across := Basis(Vector3.RIGHT,PI*0.5)
	var along_b := Basis(Vector3(0.0,0.0,1.0),-fall_sign*PI*0.5)
	if t < hop:
		var k := t/hop
		var pos := at.lerp(at+Vector3(fall_sign*0.6,0.0,(to.z-at.z)*0.1),k)
		pos.y = at.y+0.7*sin(PI*k)
		node.transform = Transform3D(along_b.slerp(across,smoothstep(0.0,1.0,k))*Basis(Vector3.UP,yaw),pos)
		p.v = ROLL_V
		return true
	var rt := minf((t-hop)/(big_t-hop),1.0)
	var k2 := 1.0-pow(1.0-rt,2.0)
	var start := at+Vector3(fall_sign*0.6,0.0,(to.z-at.z)*0.1)
	start.y = K.DRUM_R
	var pos2 := start.lerp(to,k2)
	var dist := start.distance_to(pos2)
	p.v = 2.0*start.distance_to(to)/maxf(big_t-hop,0.01)*(1.0-rt)
	node.transform = Transform3D(Basis(Vector3(0.0,0.0,1.0),-fall_sign*dist/K.DRUM_R)*across*Basis(Vector3.UP,yaw),pos2)
	if m != null and float(p.v) > 1.0: _rolled_into(m,node.global_position)
	return rt < 1.0

## The wanderer under the falling shaft: knocked out from under it, across.
func _under(m: PilotMotor) -> void:
	if _hit_kinds.has("under"): return
	var a := shaft.global_transform*Vector3(-K.DRUM_R,0.0,0.0)
	var b := shaft.global_transform*Vector3(-K.DRUM_R,K.DRUMS*K.DRUM_H+K.capital_h(),0.0)
	var q := m.feet+Vector3.UP*0.8*m.size
	var ab := b-a
	var t := clampf((q-a).dot(ab)/ab.length_squared(),0.0,1.0)
	var near := a+ab*t
	var reach := K.DRUM_R+0.35 if t < 0.88 else K.ABACUS.x*0.5+0.35
	if q.distance_to(near) > reach: return
	var dw := _dir_world()
	var side := dw.cross(Vector3.UP).normalized()
	var s := (q-global_position).dot(side)
	if absf(s) < 0.3: s = m.velocity.dot(side) if absf(m.velocity.dot(side)) > 0.2 else 1.0
	var away := side*signf(s)
	var v := m.knock_velocity(Vector2(away.x,away.z),UNDER.x,UNDER.y)+dw*UNDER.z
	_hit(m,"under",v,false)

## A rolling drum at `c` meeting him: knocked along the roll (tossed on, stunned).
func _rolled_into(m: PilotMotor, c: Vector3) -> void:
	var dw := _dir_world()
	var rel := m.feet-c
	var along := rel.dot(dw)
	var across := rel.dot(dw.cross(Vector3.UP).normalized())
	if absf(along) > K.DRUM_R+0.3 or absf(across) > K.DRUM_H*0.5+0.3 or m.feet.y > c.y+K.DRUM_R or m.feet.y < c.y-K.DRUM_R-0.5: return
	if _hit_kinds.has("drum") and fall_s-float(_hit_kinds.drum) < 1.2: return
	_hit_kinds["drum"] = fall_s
	var v := dw*DRUM_HIT.x+Vector3.UP*DRUM_HIT.y
	if m.move == "tumble": m.toss(v)
	else:
		m.knock(v,src_drum)
		m.harm("stone",1,src_drum)
	dealt.append(["maker_drum","roll"])
	if _hub != null: _hub.knocked("maker_drum","roll",v)

## A hit on him from the column: `toss` (on it) or `knock`.
func _hit(m: PilotMotor, kind: String, v: Vector3, toss: bool) -> void:
	_hit_kinds[kind] = true
	if toss: m.toss(v)
	else:
		m.knock(v,src_felled)
		m.harm("stone",1,src_felled)
	dealt.append(["maker_felled",kind])
	if _hub != null: _hub.knocked("maker_felled",kind,v)

## Standing on the shaft's top (the abacus), in its square.
func _on_shaft_top(feet: Vector3) -> bool:
	var top := global_position.y+K.column_h()
	var local := to_local(feet)
	return absf(feet.y-top) < 0.6 and absf(local.x) < K.ABACUS.x*0.5+0.2 and absf(local.z) < K.ABACUS.x*0.5+0.2

## At rest: the authored rest's collision, ground to both bodies; their
## routes read it afresh.
func _rest() -> void:
	state = "settled"
	_live.clear()
	if how == "abyss":
		_hub.changed(AABB(global_position-Vector3(8,4,8),Vector3(16,30,16)))
		return
	fallen = StaticBody3D.new()
	fallen.name = "Fallen"
	add_child(fallen)
	var from := K.felled_from()
	var inline := K.DRUMS if how == "bridge" else K.DRUMS-ROLLERS
	var open := SEAM_OPEN.x
	var length := inline*K.DRUM_H+open*(inline-1)
	var along_b := Basis(Vector3(0.0,0.0,1.0),-fall_sign*PI*0.5)
	_shape(fallen,_cyl(K.DRUM_R-LIE_IN,length),Transform3D(along_b,Vector3(fall_sign*(from+length*0.5),K.DRUM_R+LIE_UP,0.0)))
	if spall != null: _shape(fallen,_box(Vector3(SPALL.x,SPALL_TALL,SPALL.z)),spall.transform*Transform3D(Basis.IDENTITY,Vector3(0.0,(SPALL.y-SPALL_TALL)*0.5,0.0)))
	for n: Node in get_children():
		if n is MeshInstance3D and n != mesh and n != capital and String(n.name).begins_with("Drum"):
			_shape(fallen,_cyl(K.DRUM_R-LIE_IN,K.DRUM_H),Transform3D((n as Node3D).transform.basis.orthonormalized(),(n as Node3D).position+Vector3.UP*LIE_UP))
	# The capital upside down: its abacus on the ground, the echinus over it.
	var cx := capital.transform
	var up := cx.basis.y.normalized()
	var foot := cx.origin
	_shape(fallen,_cyl(K.DRUM_R+K.ECHINUS.y*0.5,K.ECHINUS.x),Transform3D(cx.basis.orthonormalized(),foot+up*K.ECHINUS.x*0.5))
	_shape(fallen,_box(Vector3(K.ABACUS.x,K.ABACUS.y-LIFT,K.ABACUS.x)),Transform3D(cx.basis.orthonormalized(),foot+up*(K.ECHINUS.x+(K.ABACUS.y-LIFT)*0.5)))
	var box := AABB(global_position+Vector3(-4.5,0.0,-4.5),Vector3(9.0,8.0,9.0))
	box = box.expand(to_global(Vector3(fall_sign*(from+length+K.capital_h()+K.ABACUS.x),0.0,7.0)))
	box = box.expand(to_global(Vector3(0.0,0.0,-7.0)))
	# Told once the new shapes are in the physics space (read the same frame,
	# the columns came back as they were).
	_changed_box = box
	_changed_in = 2
	_hub.sound(&"ruin_thud",global_position)

## The crown of the felled line at `u` m along it (world), for checks: its
## top's world point.
func crown(u: float) -> Vector3:
	return to_global(Vector3(fall_sign*(K.felled_from()+u),K.DRUM_R*2.0,0.0))
