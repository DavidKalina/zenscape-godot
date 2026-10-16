extends "res://scripts/city_breaks/stone_break.gd"
## The facing sheet wall, maker_skin: a terrace's
## retaining wall, an earth core faced in sheets of dressed, bossed basalt
## (each sheet three courses of blocks, each a quarry batch's shade). Plumb
## and too tall for the wanderer, up or down (past his fall stun); the
## Olmec climbs it.
##
## It peels a column at a time: the column's two sheets go over outward
## together about their foot (slow, then slamming flat), breaking along
## their courses as they land; then the earth behind slumps into a slope
## from the terrace's edge down over the lower sheet to the upper one lying
## out on the ground. A column down is a way between the yard and the
## terrace for both bodies: the slope to run (or slide) down and climb up,
## the scree at its foot; three side by side are his lane.
##
## The piece's frame: the wall's face toward +Z, its foot on y 0, columns
## along X round x 0; the terrace (its core) behind, to z -CORE_D, top H.
##
## Who peels it:
##   shock  his landing's shockwave: columns within PEEL_SURE of the wave's
##          reach go, those within PEEL_MAY by chance (the nearer, the more
##          likely; decided per wave from the piece's seed).
##   body   his climb: a column he has climbed CLIMB_HOLD s goes, and he
##          falls with it (his landing's wave then peels its neighbours).
##   slam   the wanderer's slam onto the cracked column's top (CRACKED).
## The ride: standing on a column's top as it goes, the wanderer rides it
## down (the motor's rider), standing on its edge, and is put off it ahead
## near the bottom (or jumps off). Under a column coming down he is knocked
## out from the wall (source "maker_skin").
const SHEET_W := 3.0
const COLS := 5
const ROWS := 2
const SHEET_H := COURSE
const SHEET_T := 1.2
const CORE_D := 6.0
## The cracked column (a slam peels it), -1 none.
const CRACKED := 3
## A column's tell, its fall's pull (rad/s² from plumb: a 9.6 m board's
## 3g/2L, eased for the read) and first turn, the earth's slump (s).
const TELL := 0.35
const PULL := 1.9
const W0 := 0.18
const SLUMP_T := 0.8
## The shockwave's share of its reach that peels for sure, may peel.
const PEEL_SURE := 0.5
const PEEL_MAY := 0.8
## Climbing a face this long (s, after his hand has felt it) peels it: he is
## a few metres up as it goes.
const CLIMB_HOLD := 0.7
## The ride: let off at this turn (rad), hopped ahead (m/s ahead, up).
const RIDE_OFF := 1.25
const RIDE_HOP := Vector2(3.0,4.5)
## Under it: knocked out from the wall (m out, m up).
const UNDER := Vector2(4.0,1.0)
const SLAM_LEAST := 0.0
const EARTH := Color(0.43,0.27,0.15)

## Per column: {state ("whole", "tell", "falling", "slump", "down"), t,
## a (rad), w, node (the lower sheet's pivot), upper, core (body),
## sheets (body), rest (body), cause}.
var cols: Array = []
var _ride: Ride = null
var _grips := {}
var _slam_hit := -1

class Ride extends RefCounted:
	var wall
	var col := 0
	var at := Vector3.ZERO
	var last := Vector3.INF
	var vel := Vector3.ZERO
	func ride(walker, delta: float, _want: Vector2, pressed: bool) -> Dictionary:
		var out := {}
		var p: Vector3 = wall.ride_point(col,at)
		if last != Vector3.INF and delta > 0.0: vel = (p-last)/delta
		last = p
		walker.feet = p
		walker.ground_y = p.y
		walker.velocity = vel
		walker.grounded = true
		walker.move = ""
		walker.hold = ""
		if pressed:
			wall.let_off(walker,true)
			out["jumped"] = 1
		return out

static func height() -> float:
	return ROWS*SHEET_H

static func width() -> float:
	return COLS*SHEET_W

func build(seed_in: int, weathered_in := 0.0) -> void:
	_setup("maker_skin",seed_in,weathered_in)
	_build_cols()

func reset() -> void:
	var m := motor()
	if m != null and m.rider == _ride and _ride != null: m.rider = null
	_ride = null
	for n: Node in get_children():
		if n is Node3D: n.free()
	cols.clear()
	_grips.clear()
	dealt.clear()
	state = "whole"
	cause = ""
	_build_cols()

func col_x(c: int) -> float:
	return (c-(COLS-1)*0.5)*SHEET_W

func _build_cols() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*61+9
	var h := height()
	for c in COLS:
		var x := col_x(c)
		# The earth core behind: drawn as a shell (its face hidden by the
		# sheets), a column of its own.
		var em := Stone.Mesher.new(EARTH,0.0)
		block(em,at(Vector3(x,h*0.5,-CORE_D*0.5)),Vector3(SHEET_W,h,CORE_D),0.0,0.9)
		var core_mesh := mesh_node("Core%d" % c,Stone.mesh_of(em))
		var core := static_body("CoreBody%d" % c,[[at(Vector3(x,h*0.5,-CORE_D*0.5)),Vector3(SHEET_W,h,CORE_D)]])
		# The sheets: the lower's pivot at its foot's outer edge, the upper
		# its child at the lower's top (they go over as one board).
		var lower := Node3D.new()
		lower.name = "Sheet%d" % c
		lower.position = Vector3(x,0.0,SHEET_T)
		add_child(lower)
		var upper := Node3D.new()
		upper.name = "Upper"
		upper.position = Vector3(0.0,SHEET_H,0.0)
		lower.add_child(upper)
		var parts: Array = []
		for r in ROWS:
			var holder: Node3D = lower if r == 0 else upper
			var tone := rng.randf_range(0.82,1.08)
			for k in 3:
				var bm := mesher(0.2)
				var y0 := k*SET_OFF
				var n := 2 if (k+c+r) % 2 == 0 else 3
				var xs := [-SHEET_W*0.5]
				for j in range(1,n): xs.append(-SHEET_W*0.5+SHEET_W*j/n+rng.randf_range(-0.15,0.15))
				xs.append(SHEET_W*0.5)
				var cc := Vector3(0.0,y0+SET_OFF*0.5,-SHEET_T*0.5)
				for j in n:
					var x0: float = xs[j]
					var x1: float = xs[j+1]
					var bc := Vector3((x0+x1)*0.5,cc.y,cc.z)
					block(bm,at(bc-cc),Vector3(x1-x0-0.05,SET_OFF-0.05,SHEET_T),0.1,tone*rng.randf_range(0.93,1.05))
					# The boss: a raised pad on the face.
					block(bm,at(bc-cc+Vector3(0.0,0.0,SHEET_T*0.5+0.06)),Vector3((x1-x0)*0.62,SET_OFF*0.55,0.14),0.06,tone*1.04)
				if k == 1:
					bm.runes(Vector3(-SHEET_W*0.5+0.25,-0.4,SHEET_T*0.5+0.14),Vector3(SHEET_W*0.5-0.25,-0.4,SHEET_T*0.5+0.14),Vector3.UP,Vector3(0.0,0.0,1.0),float(seed_value+c*3+r))
				var mi := MeshInstance3D.new()
				mi.name = "Course%d" % k
				mi.mesh = Stone.mesh_of(bm)
				mi.position = cc
				holder.add_child(mi)
				parts.append(mi)
		var sheets := static_body("SheetBody%d" % c,[[at(Vector3(x,h*0.5,SHEET_T*0.5)),Vector3(SHEET_W,h,SHEET_T)]])
		cols.append({"state":"whole","t":0.0,"a":0.0,"w":0.0,"node":lower,"upper":upper,"core":core,"core_mesh":core_mesh,
			"sheets":sheets,"rest":null,"cause":"","parts":parts,"ramp":null})
	# The cracked column: a pale seam along its top course, grit.
	if CRACKED >= 0 and CRACKED < COLS:
		var m := mesher(0.0)
		block(m,at(Vector3(col_x(CRACKED)+0.3,h-SET_OFF+0.02,SHEET_T+0.03),0.0,0.0,0.25),Vector3(SHEET_W*0.8,0.07,0.06),0.0,FRESH*1.2)
		block(m,at(Vector3(col_x(CRACKED)-0.6,h+0.02,SHEET_T*0.5)),Vector3(0.07,0.05,SHEET_T+0.3),0.0,0.4)
		mesh_node("Seam",Stone.mesh_of(m))

# --- Queries -------------------------------------------------------------------------------

## The column under world `p` (by x), -1 none.
func col_at(p: Vector3) -> int:
	var q := to_local(p)
	var c := int(floor(q.x/SHEET_W+COLS*0.5))
	return c if c >= 0 and c < COLS else -1

## World point on column `c`'s top (the upper sheet's top end) for a
## rider who stood at local `at` (x within the column, z within the sheet).
func ride_point(c: int, at_l: Vector3) -> Vector3:
	var upper: Node3D = cols[c].upper
	return upper.global_transform*Vector3(at_l.x,SHEET_H,clampf(at_l.z-SHEET_T,-SHEET_T,0.0))

func down_count() -> int:
	var n := 0
	for col: Dictionary in cols:
		if col.state != "whole": n += 1
	return n

## A hit's mark (stone_break.gd take_hit): a column peeled is a change.
func _mark() -> String:
	return "%s %d" % [state,down_count()]

# --- Triggers ------------------------------------------------------------------------------

func _wave(_b: Node3D, w: Dictionary) -> bool:
	var origin: Vector3 = w.at
	var q := to_local(origin)
	if absf(q.y) > 3.0 and absf(q.y-height()) > 3.0: return true
	var reach: float = w.max
	var done := true
	var key := "skin_%d" % get_instance_id()
	var seen: Dictionary = w.get(key,{})
	w[key] = seen
	for c in COLS:
		if seen.has(c) or cols[c].state != "whole": continue
		var foot := Vector2(col_x(c),SHEET_T)
		var d := Vector2(q.x,q.z).distance_to(foot)
		if d > reach*PEEL_MAY:
			seen[c] = true
			continue
		if float(w.r) < d:
			done = false
			continue
		seen[c] = true
		var sure := d <= reach*PEEL_SURE
		var chance := 1.0-(d/reach-PEEL_SURE)/(PEEL_MAY-PEEL_SURE)
		var roll := float(absi(hash([seed_value,c,int(origin.x*10.0),int(origin.z*10.0)])) % 1000)/1000.0
		if sure or roll < chance: peel(c,"shock")
	return done

func _met(b: Node3D) -> void:
	if b.state != "climb":
		_grips.erase(b.get_instance_id())
		return
	var fwd: Vector3 = b._forward3()
	var chest: Vector3 = b.position+Vector3.UP*float(b.neck_h)*0.55+fwd*3.0
	var q := to_local(chest)
	if q.z < -1.0 or q.z > SHEET_T+4.0 or q.y < 0.0 or q.y > height(): return
	var c := col_at(chest)
	if c < 0 or cols[c].state != "whole": return
	var key := b.get_instance_id()
	var g: Array = _grips.get(key,[c,0.0])
	if int(g[0]) != c: g = [c,0.0]
	g[1] = float(g[1])+get_physics_process_delta_time()
	_grips[key] = g
	if float(g[1]) >= CLIMB_HOLD:
		_grips.erase(key)
		peel(c,"body")
		# Off the face with it: he falls (his landing's wave peels more).
		if b.state == "climb":
			b.position += global_transform.basis.z*1.2
			if b.has_method("_fall"): b._fall()

func _slam(at_p: Vector3, _radius: float, strength: float) -> void:
	if CRACKED < 0 or strength < SLAM_LEAST: return
	var q := to_local(at_p)
	if absf(q.y-height()) > 0.8 or q.z < -1.0 or q.z > SHEET_T+0.4: return
	var c := col_at(at_p)
	if c == CRACKED and cols[c].state == "whole":
		_slam_hit = c
		peel(c,"slam")

## Column `c` goes.
func peel(c: int, why: String) -> void:
	var col: Dictionary = cols[c]
	if col.state != "whole": return
	col.state = "tell"
	col.t = 0.0
	col.cause = why
	if state == "whole":
		state = "falling"
		cause = why
	var top := to_global(Vector3(col_x(c),height(),SHEET_T))
	_sound(&"ruin_crack",top)
	Dust.puff(get_parent(),top,2.2,global_transform.basis.z)
	_shake(0.35)
	if c == CRACKED:
		var seam := get_node_or_null("Seam")
		if seam != null: seam.queue_free()

func _step(delta: float) -> void:
	var m := motor()
	for c in COLS:
		var col: Dictionary = cols[c]
		match String(col.state):
			"tell":
				col.t = float(col.t)+delta
				if float(col.t) >= TELL: _go_over(c,m)
			"falling":
				col.t = float(col.t)+delta
				col.w = float(col.w)+PULL*sin(float(col.a)+0.02)*delta
				col.a = minf(float(col.a)+float(col.w)*delta,PI*0.5)
				(col.node as Node3D).rotation.x = float(col.a)
				if _ride != null and _ride.col == c and float(col.a) >= RIDE_OFF and m != null: let_off(m,false)
				if float(col.a) >= PI*0.5: _impact(c,m)
			"slump":
				col.t = float(col.t)+delta
				var k := clampf(float(col.t)/SLUMP_T,0.0,1.0)
				var ramp: Node3D = col.ramp
				ramp.position = Vector3(0.0,(1.0-k*k)*2.5,-(1.0-k*k)*4.0)
				var parts: Array = col.parts
				for i in parts.size():
					var pc: Node3D = parts[i]
					if pc.has_meta("jit"):
						var j: Vector3 = pc.get_meta("jit")
						pc.position = (pc.get_meta("rest") as Vector3)+j*smoothstep(0.0,0.3,float(col.t))
				if k >= 1.0: _rest(c)
	var busy := false
	for col: Dictionary in cols:
		if col.state in ["tell","falling","slump"]: busy = true
	if state == "falling":
		fall_s += delta
		if not busy: state = "fallen"

## The tell over: the column goes over; the core's front comes away; a
## rider on its top is taken.
func _go_over(c: int, m: PilotMotor) -> void:
	var col: Dictionary = cols[c]
	col.state = "falling"
	col.t = 0.0
	col.a = 0.0
	col.w = W0
	(col.sheets as Node).free()
	col.sheets = null
	_sound(&"ruin_fall",to_global(Vector3(col_x(c),height()*0.6,SHEET_T)))
	if m != null and _ride == null and m.move != "tumble" and not m.seized() and m.rider == null:
		var q := to_local(m.feet)
		if q.y-height() > -0.3 and q.y-height() < 0.6 and absf(q.x-col_x(c)) < SHEET_W*0.5+0.15 and q.z > -0.5 and q.z < SHEET_T+0.3:
			_ride = Ride.new()
			_ride.wall = self
			_ride.col = c
			_ride.at = Vector3(clampf(q.x-col_x(c),-SHEET_W*0.5+0.3,SHEET_W*0.5-0.3),0.0,clampf(q.z,0.1,SHEET_T-0.1))
			m.rider = _ride
			m.hold = ""
			m.move = ""
			dealt.append(["maker_skin","ride"])
	# Climbing it: off it (his own falls are his).
	for b in bodies():
		if b.state == "climb" and col_at(b.position+b._forward3()*3.0) == c:
			b.position += global_transform.basis.z*1.2
			if b.has_method("_fall"): b._fall()

## Put off the ride: hopped ahead (or jumped).
func let_off(m: PilotMotor, jumped: bool) -> void:
	if _ride == null: return
	var v := _ride.vel
	var out := global_transform.basis.z
	var hop := Vector3(out.x,0.0,out.z)*RIDE_HOP.x+Vector3.UP*RIDE_HOP.y
	if jumped: hop += Vector3.UP*2.0
	if m.rider == _ride:
		m.rider = null
		m.grounded = false
		m.toss(Vector3(v.x*0.3,maxf(v.y*0.2,0.0),v.z*0.3)+hop)
	dealt.append(["maker_skin","off"])
	var h := hub()
	if h != null: h.knocked("maker_skin","ride_off",hop)
	_ride = null

## Flat on the ground: it breaks along its courses, the boom, the dust;
## the earth behind it slumps.
func _impact(c: int, m: PilotMotor) -> void:
	var col: Dictionary = cols[c]
	col.state = "slump"
	col.t = 0.0
	if _ride != null and _ride.col == c and m != null: let_off(m,false)
	var x := col_x(c)
	var a := to_global(Vector3(x,0.3,SHEET_T))
	var b := to_global(Vector3(x,0.3,SHEET_T+height()))
	dust_line(a,b,4.0,2.4)
	Dust.rocks(get_parent(),b,global_transform.basis.z,14,0.4)
	_sound(&"ruin_boom",(a+b)*0.5)
	_shake(1.0)
	_pause(3,0.2)
	# Its courses apart: each slid a little, turned a little.
	var parts: Array = col.parts
	for i in parts.size():
		var pc: Node3D = parts[i]
		pc.set_meta("rest",pc.position)
		pc.set_meta("jit",Vector3(_rng.randf_range(-0.12,0.12),_rng.randf_range(-0.1,0.25),_rng.randf_range(-0.05,0.05)))
		pc.rotation = Vector3(_rng.randf_range(-0.04,0.04),_rng.randf_range(-0.08,0.08),_rng.randf_range(-0.06,0.06))
	# Under it on the ground: knocked out from the wall.
	if m != null and not m.seized() and m.rider == null:
		var q := to_local(m.feet)
		if absf(q.x-x) < SHEET_W*0.5+0.5 and q.z > SHEET_T-0.3 and q.z < SHEET_T+height()+0.5 and q.y < 2.5:
			var out := global_transform.basis.z
			hit(m,"maker_skin","under",m.knock_velocity(Vector2(out.x,out.z),UNDER.x,UNDER.y))
	# The core comes away and the earth slumps: drawn sliding down into
	# its slope (under the dust).
	(col.core as Node).free()
	col.core = null
	(col.core_mesh as Node).free()
	var ramp := Node3D.new()
	ramp.name = "Slump%d" % c
	add_child(ramp)
	var mi := MeshInstance3D.new()
	mi.mesh = _earth_mesh(c)
	ramp.add_child(mi)
	ramp.position = Vector3(0.0,2.5,-4.0)
	col.ramp = ramp
	Dust.plume(get_parent(),to_global(Vector3(x,height()*0.5,0.0)),6.0)

## The slope's section (piece frame, y z): from the terrace's edge to the
## lower sheet's far end, down to LIFT.
func slope_points() -> PackedVector2Array:
	var top := Vector2(height(),-CORE_D)
	var toe := Vector2(SHEET_T,SHEET_T+SHEET_H)
	return PackedVector2Array([top,toe,Vector2(LIFT,toe.y),Vector2(LIFT,top.y)])

func _earth_mesh(c: int) -> ArrayMesh:
	var x := col_x(c)
	var s := slope_points()
	var m := Stone.Mesher.new(EARTH,0.0)
	var planes: Array = []
	# The prism's planes: its two ends (x), the slope, the toe, the foot, the back.
	planes.append(Plane(Vector3.RIGHT,x+SHEET_W*0.5-0.02))
	planes.append(Plane(Vector3.LEFT,-(x-SHEET_W*0.5+0.02)))
	var top := Vector3(0.0,s[0].x,s[0].y)
	var toe := Vector3(0.0,s[1].x,s[1].y)
	var along := (toe-top).normalized()
	var nrm := Vector3.RIGHT.cross(along).normalized()
	if nrm.y < 0.0: nrm = -nrm
	planes.append(Plane(nrm,nrm.dot(top)))
	planes.append(Plane(Vector3(0.0,0.0,1.0),toe.z))
	planes.append(Plane(Vector3.DOWN,-0.0))
	planes.append(Plane(Vector3(0.0,0.0,-1.0),CORE_D))
	m.solid(planes,NAN,1.0)
	# Roots: dark strands down the slope.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*71+c
	for i in 4:
		var u := rng.randf_range(0.1,0.7)
		var p := top.lerp(toe,u)+Vector3(x+rng.randf_range(-1.1,1.1),0.0,0.0)+nrm*0.04
		var l := rng.randf_range(1.5,3.5)
		var xf := Transform3D(Basis(Vector3.RIGHT,-atan2(along.y,along.z)).rotated(Vector3.UP,rng.randf_range(-0.3,0.3)),p+along*l*0.5)
		block(m,xf,Vector3(0.09,0.07,l),0.0,0.35)
	return Stone.mesh_of(m)

## The rest's shapes for column `c` (piece frame): the slope prism and the
## upper sheet lying beyond its toe. [[xf, size]] for boxes; the prism apart.
func rest_boxes(c: int) -> Array:
	var x := col_x(c)
	var z0 := SHEET_T+SHEET_H
	var z1 := SHEET_T+2.0*SHEET_H
	return [[at(Vector3(x,(SHEET_T+LIFT)*0.5,(z0+z1)*0.5)),Vector3(SHEET_W,SHEET_T-LIFT,z1-z0)]]

func _rest(c: int) -> void:
	var col: Dictionary = cols[c]
	col.state = "down"
	(col.ramp as Node3D).position = Vector3.ZERO
	var body := static_body("Rest%d" % c,rest_boxes(c))
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	var x := col_x(c)
	for q: Vector2 in slope_points():
		for sx: float in [-SHEET_W*0.5,SHEET_W*0.5]: pts.append(Vector3(x+sx,q.x,q.y))
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	col.rest = body
	var boxes := rest_boxes(c)
	boxes.append([at(Vector3(x,height()*0.5,0.0)),Vector3(SHEET_W,height(),CORE_D*2.0)])
	tell(world_box(boxes,3.0))

## The slope's top at world `p` (y), -INF off it: for checks.
func slope_y(p: Vector3) -> float:
	var q := to_local(p)
	var s := slope_points()
	if q.z < s[0].y or q.z > s[1].y: return -INF
	var k := (q.z-s[0].y)/(s[1].y-s[0].y)
	return to_global(Vector3(0.0,lerpf(s[0].x,s[1].x,k),0.0)).y

## For the yard's printout: [name, value, against, ok].
static func fit(climb_max: float) -> Array:
	var grab := RuinKit.GRAB_TOP*WorldScale.wanderer
	var stun := PilotMotor.FALL_STUN_PUMPS*PilotMotor.JUMPS[1]*WorldScale.wanderer
	var drop := height()-SHEET_T
	var run := CORE_D+SHEET_T+SHEET_H
	var deg := rad_to_deg(atan2(drop,run))
	return [
		["skin: wall past the walker's fall stun (m)",height(),stun,height() > stun],
		["skin: wall under his climb (m)",height(),climb_max,height() < climb_max],
		["skin: slope (deg) under the motor's slide-off",deg,PilotMotor.SLIDE_AUTO,deg < PilotMotor.SLIDE_AUTO],
		["skin: scree under the walker's grab (m)",SHEET_T,grab,SHEET_T < grab],
		["skin: three columns his lane (m)",3.0*SHEET_W,LANE,3.0*SHEET_W >= LANE],
	]
