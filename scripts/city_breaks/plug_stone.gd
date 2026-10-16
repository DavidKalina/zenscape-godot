extends "res://scripts/city_breaks/stone_break.gd"
## The plug-stone, colossus_plug: a colossal
## keystone jammed in a gate of a wall too tall for anyone to climb. A wall,
## not an obstacle, until he strikes it. Lure him into it and run through
## the hole he leaves.
##
## The piece's frame: the wall along X, its faces toward +Z and -Z, the
## gate's opening (his lane wide, taller than he is) round x 0, its sill on
## y 0. The wall stands WALL_H, past his climb.
##
## Who breaks it: only the Olmec.
##   body   his bulk meets the plug moving (a pounce coming down on you
##          where you stood at its face, a charge): it goes at once, away
##          from him.
##   shock  his landing's shockwave starting within SHOCK_NEAR m of its
##          face: the first cracks it (the pale cracks show, the top right
##          quarter slips, dust sifts), the second breaks it, away from
##          where he landed.
## The wanderer's slam is nothing to it (the contrarian tell).
##
## The standing plug is air to his rays and his planner (the hub's
## `standing_rids`, as round 1's column): he walks and pounces into it. Its
## four quarters topple out the way he pushed and burst on the ground; the
## rest is a low heap through the gate and out both sides, steps of
## HEAP_STEP (under the walker's STEP_UP: walked, not climbed) and his lane's
## width, ground to both. A quarter coming down by the wanderer knocks him
## (`knock`, source "colossus_plug", stunned DOWN s).
const WALL_H := 24.0
const OPEN_H := 12.0
const JAMB := 2.0*CELL
const THICK := CELL
## A shockwave starting this near its face (m) counts (card: within 8 m).
const SHOCK_NEAR := 8.0
## His bulk moving at least this fast (m/s) breaks it.
const BODY_PACE := 0.8
## The heap: a step's rise (m: the walker's STEP_UP is 0.45), its top over
## the sill, how far it runs out each side (m: the far side, the near).
const HEAP_STEP := 0.4
const HEAP_TOP := 1.6
const HEAP_OUT := Vector2(13.0,5.0)
## The quarters: the top two go first, the foot two DELAY s later; each
## falls over FALL_T s.
const DELAY := 0.35
const FALL_T := Vector2(1.1,0.8)
## A quarter landing within HIT_R m of the wanderer knocks him (m out, m
## up, s down).
const HIT_R := 3.5
const KNOCK := Vector3(3.0,1.0,0.5)

## Shockwaves it has taken (2 breaks it).
var shocks := 0
## +1: it fell toward +Z, -1 toward -Z (0 standing).
var push_sign := 0.0
var standing: StaticBody3D
var wall: StaticBody3D
var quarters: Array[MeshInstance3D] = []
var cracks: MeshInstance3D
var heap_mesh: MeshInstance3D
var rest_body: StaticBody3D
var _heap: Array = []
var _sift := 0.0

func build(seed_in: int, weathered_in := 0.0) -> void:
	_setup("colossus_plug",seed_in,weathered_in)
	_wall()
	_plug()

func reset() -> void:
	for n: Node in get_children():
		if n is Node3D and String(n.name) not in ["Wall","WallBody"]: n.free()
	quarters.clear()
	flights.clear()
	_heap.clear()
	state = "whole"
	cause = ""
	shocks = 0
	push_sign = 0.0
	fall_s = 0.0
	dealt.clear()
	rest_body = null
	heap_mesh = null
	_plug()

## The wall and the gate's frame: coursed jambs, the lintel, a glyph band.
func _wall() -> void:
	var half := LANE*0.5
	var blocks: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*31+3
	var course := SET_OFF
	var rows := int(round(WALL_H/course))
	for r in rows:
		var y0 := r*course
		var y1 := y0+course
		for side: float in [-1.0,1.0]:
			# The jamb's blocks: three a course, staggered.
			var x0 := half
			var x1 := half+JAMB
			var cut := lerpf(x0,x1,0.33 if r % 2 == 0 else 0.6)+rng.randf_range(-0.4,0.4)
			for seg: Vector2 in [Vector2(x0,cut),Vector2(cut,x1)]:
				blocks.append([at(Vector3(side*(seg.x+seg.y)*0.5,(y0+y1)*0.5,0.0)),Vector3(seg.y-seg.x-0.04,course-0.04,THICK),rng.randf_range(0.9,1.1)])
		if y0 >= OPEN_H-0.01:
			var cut2 := rng.randf_range(-1.5,1.5)
			for seg: Vector2 in [Vector2(-half,cut2),Vector2(cut2,half)]:
				blocks.append([at(Vector3((seg.x+seg.y)*0.5,(y0+y1)*0.5,0.0)),Vector3(seg.y-seg.x-0.04,course-0.04,THICK),rng.randf_range(0.9,1.1)])
	# The great lintel over the opening: one long stone, proud of the face.
	var lintel := [at(Vector3(0.0,OPEN_H+1.2,0.0)),Vector3(LANE+3.0,2.4,THICK+0.5),1.05,0.25]
	blocks.append(lintel)
	var runes: Array = []
	for s: float in [-1.0,1.0]:
		var zf := s*(THICK*0.5+0.27)
		runes.append([Vector3(-s*(LANE*0.5+1.2),OPEN_H+0.5,zf),Vector3(s*(LANE*0.5+1.2),OPEN_H+0.5,zf),Vector3.UP,Vector3(0.0,0.0,s),float(seed_value)+s])
	mesh_node("Wall",part_mesh(blocks,Transform3D.IDENTITY,0.2,runes))
	# Its collision: two jambs and the lintel, plumb, his and the walker's.
	var boxes: Array = []
	for side: float in [-1.0,1.0]:
		boxes.append([at(Vector3(side*(half+JAMB*0.5),WALL_H*0.5,0.0)),Vector3(JAMB,WALL_H,THICK)])
	boxes.append([at(Vector3(0.0,(OPEN_H+WALL_H)*0.5,0.0)),Vector3(LANE,WALL_H-OPEN_H,THICK)])
	wall = static_body("WallBody",boxes)

## The plug: four quarters, the rune brow across them, its cracks.
func _plug() -> void:
	var half := LANE*0.5
	var seam := 0.05
	var mid := OPEN_H*0.55
	var spans := [[Vector2(-half,0.0),Vector2(0.0,mid)],[Vector2(0.0,half),Vector2(0.0,mid)],
		[Vector2(-half,0.0),Vector2(mid,OPEN_H)],[Vector2(0.0,half),Vector2(mid,OPEN_H)]]
	for i in 4:
		var sx: Vector2 = spans[i][0]
		var sy: Vector2 = spans[i][1]
		var c := Vector3((sx.x+sx.y)*0.5,(sy.x+sy.y)*0.5,0.0)
		var size := Vector3(sx.y-sx.x-seam,sy.y-sy.x-seam,THICK-0.1)
		var runes: Array = []
		if i >= 2:
			# The brow: one huge closed rune across the top two, both faces.
			for s: float in [-1.0,1.0]:
				var zf := s*(THICK*0.5-0.03)
				runes.append([Vector3(sx.x+0.3,mid+1.4,zf),Vector3(sx.y-0.3,mid+1.4,zf),Vector3.UP,Vector3(0.0,0.0,s),float(seed_value*3+i)])
		var q := mesh_node("Quarter%d" % i,part_mesh([[at(c),size,1.12,0.3]],at(c),0.15,runes),at(c))
		quarters.append(q)
	# The cracks: pale lines out from the brow's middle (shown once cracked).
	var m := mesher(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7+1
	for s: float in [-1.0,1.0]:
		var zf := s*(THICK*0.5-0.02)
		var o := Vector3(rng.randf_range(-0.6,0.6),mid+0.4,zf)
		for k in 7:
			var a := TAU*k/7.0+rng.randf_range(-0.3,0.3)
			var len := rng.randf_range(2.5,5.5)
			var p := o
			for j in 3:
				var d := Vector3(cos(a),sin(a),0.0)
				var q2 := p+d*len/3.0
				q2.x = clampf(q2.x,-half+0.2,half-0.2)
				q2.y = clampf(q2.y,0.3,OPEN_H-0.3)
				var mid2 := (p+q2)*0.5
				var l := p.distance_to(q2)
				block(m,Transform3D(Basis(Vector3(0.0,0.0,1.0),atan2(q2.y-p.y,q2.x-p.x)),mid2),Vector3(l,0.09,0.06),0.0,FRESH*1.2)
				p = q2
				a += rng.randf_range(-0.5,0.5)
	cracks = mesh_node("Cracks",Stone.mesh_of(m))
	cracks.visible = false
	standing = static_body("Standing",[[at(Vector3(0.0,OPEN_H*0.5,0.0)),Vector3(LANE,OPEN_H,THICK)]])

# --- The hub ----------------------------------------------------------------------------

func standing_rids() -> Array[RID]:
	var out: Array[RID] = []
	if state in ["whole","cracked"] and is_instance_valid(standing): out.append(standing.get_rid())
	return out

## Its rect's nearest point to world `p` (piece frame, flat): the distance.
func _off_face(p: Vector3) -> float:
	var q := to_local(p)
	var dx := maxf(absf(q.x)-LANE*0.5,0.0)
	var dz := maxf(absf(q.z)-THICK*0.5,0.0)
	return Vector2(dx,dz).length()

func _met(b: Node3D) -> void:
	if state not in ["whole","cracked"]: return
	var q := to_local(b.position)
	if q.y > OPEN_H or q.y+float(b._bulk_top()) < 0.5: return
	var hh: float = b.hh
	var along := absf(q.z)-THICK*0.5
	var across := absf(q.x)-LANE*0.5
	# His bulk (front half-length, half breadth) over its face.
	if along > hh*HeadlessBody.BULK_L+0.3 or across > hh*HeadlessBody.BULK_W*0.5: return
	var pace := Vector2(b.vel.x,b.vel.z).length()
	if pace < BODY_PACE and b.state not in ["leap","land"]: return
	if b.has_method("stagger"): b.stagger(0.8)
	_pause(5,0.1)
	_shake(1.0)
	fall(-signf(q.z) if absf(q.z) > 0.2 else 1.0,"body")

func _wave(_b: Node3D, w: Dictionary) -> bool:
	if state not in ["whole","cracked"]: return true
	var origin: Vector3 = w.at
	var d := _off_face(origin)
	if d > SHOCK_NEAR or absf(to_local(origin).y) > 4.0: return true
	if float(w.r) < d: return false
	shocks += 1
	var away := -signf(to_local(origin).z)
	if away == 0.0: away = 1.0
	if shocks >= 2: fall(away,"shock")
	else: crack()
	return true

## The tell: its cracks show, the top right quarter slips, dust.
func crack() -> void:
	if state != "whole": return
	state = "cracked"
	cracks.visible = true
	quarters[3].position += Vector3(0.0,-0.12,0.0)
	quarters[3].rotation.z = -0.012
	var at_w := to_global(Vector3(0.0,OPEN_H*0.6,0.0))
	_sound(&"ruin_crack",at_w)
	_shake(0.4)
	for s: float in [-1.0,1.0]: Dust.puff(get_parent(),to_global(Vector3(0.0,OPEN_H*0.6,s*THICK*0.6)),3.0,global_transform.basis.z*s)

## It goes, toward `sign` (its Z).
func fall(sign: float, why: String) -> void:
	if state not in ["whole","cracked"]: return
	state = "falling"
	cause = why
	push_sign = sign
	fall_s = 0.0
	if is_instance_valid(standing):
		standing.free()
	cracks.visible = false
	_lay_heap()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*13+int(sign)
	for i in 4:
		var q := quarters[i]
		var top := i >= 2
		var c := q.position
		# Toppled out along the push, turned over it, onto the heap.
		var out_z := sign*(THICK*0.5+(9.0 if top else 4.0)+rng.randf_range(-0.6,0.6))
		var to_p := Vector3(c.x*1.15+rng.randf_range(-0.6,0.6),HEAP_TOP*0.5,out_z)
		var tilt := Basis(Vector3.RIGHT,sign*(PI*0.5+rng.randf_range(-0.2,0.2)))*Basis(Vector3.UP,rng.randf_range(-0.4,0.4))
		fly(q,Transform3D(tilt,to_p),0.0 if top else DELAY,FALL_T.x if top else FALL_T.y,1.2 if top else 0.4,{"i":i})
	var at_w := to_global(Vector3(0.0,OPEN_H*0.5,0.0))
	_sound(&"ruin_crack",at_w)
	_sound(&"ruin_fall",at_w)
	_shake(1.2)
	Dust.plume(get_parent(),to_global(Vector3(0.0,0.5,0.0)),7.0)
	Dust.rocks(get_parent(),at_w,global_transform.basis.z*sign,22,0.5)

## The rest: the heap's walk boxes (piece frame), ground to both, and its
## pale rubble.
func _heap_boxes(sign: float) -> Array:
	var out: Array = []
	var t := THICK*0.5
	# [from, to] along the push (out from the wall's middle), its top.
	var runs := [[-t-5.0,-t-3.0,1],[-t-3.0,-t-1.0,2],[-t-1.0,-t,3],[-t,t,4],
		[t,t+2.0,4],[t+2.0,t+4.4,3],[t+4.4,t+7.2,2],[t+7.2,t+HEAP_OUT.x-2.6,1]]
	for r: Array in runs:
		var a: float = r[0]
		var b: float = r[1]
		var top := HEAP_STEP*int(r[2])
		var inside := absf(a+b)*0.5 < t
		var wide := LANE-0.1 if inside else LANE+2.4
		var mid := sign*(a+b)*0.5
		out.append([at(Vector3(0.0,(top+LIFT)*0.5,mid)),Vector3(wide,top-LIFT,b-a)])
	return out

func _lay_heap() -> void:
	_heap = _heap_boxes(push_sign)
	var m := mesher(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*5+2
	for b: Array in _heap:
		var xf: Transform3D = b[0]
		var size: Vector3 = b[1]
		var top := xf.origin.y+size.y*0.5
		# Chunks over the walk box: pale, tumbled, their tops near its top.
		var n := maxi(2,int(size.x*size.z/5.0))
		for k in n:
			var cs := Vector3(rng.randf_range(1.2,2.6),rng.randf_range(0.6,1.2),rng.randf_range(1.0,2.2))
			var p := Vector3(rng.randf_range(-size.x*0.5+0.6,size.x*0.5-0.6),top-cs.y*0.5+rng.randf_range(-0.1,0.25),rng.randf_range(-size.z*0.5+0.4,size.z*0.5-0.4))+Vector3(xf.origin.x,0.0,xf.origin.z)
			block(m,Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.12,0.12),rng.randf_range(-PI,PI),rng.randf_range(-0.12,0.12))),p),cs,0.2,FRESH*rng.randf_range(0.62,0.95))
		block(m,Transform3D(Basis.IDENTITY,Vector3(xf.origin.x,top*0.5-0.05,xf.origin.z)),Vector3(size.x-0.3,top-0.1,size.z-0.1),0.25,0.72)
	heap_mesh = mesh_node("Heap",Stone.mesh_of(m))
	heap_mesh.visible = false

func _landed(f: Dictionary) -> void:
	var node: Node3D = f.node
	var p := node.global_position
	# It bursts where it lands: dust, stones, the boom; the heap shows.
	Dust.plume(get_parent(),Vector3(p.x,global_position.y+0.3,p.z),6.5)
	Dust.rocks(get_parent(),p+Vector3.UP*0.5,global_transform.basis.z*push_sign,16,0.45)
	_sound(&"ruin_boom",p)
	_shake(0.9)
	node.visible = false
	if not heap_mesh.visible:
		heap_mesh.visible = true
		_rest()
	var m := motor()
	if m != null and not m.seized():
		var off := Vector2(m.feet.x-p.x,m.feet.z-p.z)
		if off.length() < HIT_R and absf(m.feet.y-global_position.y) < 3.0:
			var dir := global_transform.basis.z*push_sign
			var away := Vector2(dir.x,dir.z)+off.normalized()*0.5
			hit(m,"colossus_plug","fall",m.knock_velocity(away,KNOCK.x,KNOCK.y),false,KNOCK.z)

## The rest's collision in: ground to both bodies, their routes read again.
func _rest() -> void:
	rest_body = static_body("Rest",_heap)
	lift_bodies(_heap)
	tell(world_box(_heap,3.0).merge(AABB(to_global(Vector3(-LANE,0.0,-THICK)),Vector3(LANE*2.0,OPEN_H,THICK*2.0))))

func _step(delta: float) -> void:
	if state == "cracked":
		_sift -= delta
		if _sift <= 0.0:
			_sift = _rng.randf_range(1.2,2.4)
			var s := 1.0 if _rng.randf() < 0.5 else -1.0
			Dust.puff(get_parent(),to_global(Vector3(_rng.randf_range(-3.0,3.0),_rng.randf_range(4.0,OPEN_H-1.0),s*THICK*0.55)),1.4,global_transform.basis.z*s)
	if state != "falling": return
	fall_s += delta
	if not fly_step(delta):
		state = "fallen"
		tell(world_box(_heap,3.0))

## The heap's walk boxes (piece frame), for checks: [[xf, size]].
func heap() -> Array:
	return _heap

## For the yard's printout: [name, value, against, ok].
static func fit(body_top: float, body_wide: float, climb_max: float) -> Array:
	var step := PilotMotor.STEP_UP*WorldScale.wanderer
	return [
		["plug: opening over his bulk with the heap (m)",OPEN_H-HEAP_TOP,body_top,OPEN_H-HEAP_TOP > body_top],
		["plug: opening wide over his bulk (m)",LANE,body_wide,LANE > body_wide],
		["plug: wall past his climb (m)",WALL_H,climb_max,WALL_H > climb_max],
		["plug: heap step under the walker's step up (m)",HEAP_STEP,step,HEAP_STEP < step],
	]
