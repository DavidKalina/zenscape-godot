extends "res://scripts/city_breaks/stone_break.gd"
## The chocked slab, maker_chock: the makers'
## half-done work. A slab his lane wide stands on its end at a gap's near
## rim, leaning out over the gap, held back by a rope to a timber lever
## whose foot is jammed by a chock. Strike the chock's plate and the lever
## springs, the rope goes slack, and the slab swings down across the gap
## onto the far rim's socket: a bridge flush with both rims. One shot.
##
## The piece's frame: the gap along +Z from the near rim (z 0) to the far
## (z GAP); both abutments' tops on y 0, their sockets cut SLAB.y deep so
## the lying slab's top is flush. The plate, the lever and the striker's
## block stand on the near side, behind the slab.
##
## Who drops it:
##   slam   the wanderer's slam (scripts/slam.gd) onto the plate: the
##          card's verb, his own way to open the gap. A stunned wanderer
##          thrown down onto the plate counts too (the card's 0.4 shock).
##   shock  the Olmec's landing within SHOCK_NEAR m of the plate (the
##          chock is cracked: any power over SHOCK_LEAST).
##   body   the Olmec's feet over the plate.
## A tell (TELL s: the chock flies, the lever springs, the slab rocks back),
## then the swing (a rod about its foot under SWING_PULL, slow at the top,
## slamming down: about a second), the boom, the dust down its length.
##
## The trap: anything on the far rim under its landing is knocked out from
## under it along the swing (source "maker_chock"); an Olmec there is set
## on it, staggered. At rest it is ground to both (in his rays: his
## planner sees the bridge) and the bodies' routes read it again.
const SLAB := Vector3(2.0*CELL,SET_OFF,3.5*CELL)
## The bearing on each rim (m): the gap is the slab's length less two.
const BEAR := 0.25*CELL
## The abutments: how far back each runs from its rim, how deep it goes.
const PIER := CELL
const PIER_DEPTH := 26.0
## Its lean out over the gap, standing (rad from plumb).
const LEAN := 0.17
## The tell's length (s), the swing's pull (rad/s² at the flat: a rod's
## 3g/2L, quickened for the read) and its first turn (rad/s).
const TELL := 0.6
const SWING_PULL := 7.0
const SWING_W0 := 0.25
## The plate: its side (m, the wanderer's scale), its rise, how far behind
## the rim it lies (its middle), off the slab's axis (x).
const PLATE := 2.4
const PLATE_RISE := 0.3
const PLATE_AT := Vector2(0.0,-7.0)
## The striker's block behind the plate (its two tiers' tops, m: a mantle
## and a mantle, then a jump off it with the slam's air), its gap to the
## plate (m).
const STRIKER := Vector2(1.2,2.4)
const STRIKER_GAP := 0.6
const SHOCK_NEAR := 10.0
const SHOCK_LEAST := 0.4
## The knock out from under it (m out, m up), and the slam's least.
const UNDER := Vector2(6.0,1.5)
const SLAM_LEAST := 0.0

## The slab's turn from flat (rad): standing PI/2-LEAN.
var phi := PI*0.5-LEAN
var omega := 0.0
var tell_t := 0.0
var slab: MeshInstance3D
var slab_body: StaticBody3D
var rope: MeshInstance3D
var lever: MeshInstance3D
var chock: MeshInstance3D
var weight: MeshInstance3D
var plate: MeshInstance3D
var _bounce := -1.0

static func gap() -> float:
	return SLAB.z-2.0*BEAR

func build(seed_in: int, weathered_in := 0.0) -> void:
	_setup("maker_chock",seed_in,weathered_in)
	_abutments()
	_stand()

func reset() -> void:
	for n: Node in get_children():
		if n is Node3D and not String(n.name).begins_with("Pier"): n.free()
	flights.clear()
	dealt.clear()
	state = "whole"
	cause = ""
	fall_s = 0.0
	_bounce = -1.0
	_stand()

## Where the slab turns (piece frame): its top near edge, at the near
## socket's back.
func pivot() -> Vector3:
	return Vector3(0.0,0.0,-BEAR)

## The slab's transform (piece frame) at `a` rad from flat.
func slab_xf(a: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY,pivot())*Transform3D(Basis(Vector3.RIGHT,-a),Vector3.ZERO)*Transform3D(Basis.IDENTITY,Vector3(0.0,-SLAB.y*0.5,SLAB.z*0.5))

func _abutments() -> void:
	var g := gap()
	var w := SLAB.x+2.0*CELL*0.5
	var socket := SLAB.x+0.2
	for far: bool in [false,true]:
		var z0 := g if far else -PIER
		var z1 := g+PIER if far else 0.0
		var sz0 := g if far else -BEAR
		var sz1 := g+BEAR if far else 0.0
		var boxes: Array = []
		var plain := Vector2(z0,sz0) if not far else Vector2(sz1,z1)
		boxes.append([at(Vector3(0.0,-PIER_DEPTH*0.5,(plain.x+plain.y)*0.5)),Vector3(w,PIER_DEPTH,plain.y-plain.x)])
		boxes.append([at(Vector3(0.0,-SLAB.y-(PIER_DEPTH-SLAB.y)*0.5,(sz0+sz1)*0.5)),Vector3(w,PIER_DEPTH-SLAB.y,sz1-sz0)])
		for s: float in [-1.0,1.0]:
			var side := (w-socket)*0.5
			boxes.append([at(Vector3(s*(socket*0.5+side*0.5),-SLAB.y*0.5,(sz0+sz1)*0.5)),Vector3(side,SLAB.y,sz1-sz0)])
		var name_s := "PierFar" if far else "PierNear"
		var m := mesher(0.3)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value*17+(2 if far else 1)
		for b: Array in boxes:
			var xf: Transform3D = b[0]
			var size: Vector3 = b[1]
			# Coursed: a block a SET_OFF tall, two across.
			var rows := maxi(1,int(round(size.y/SET_OFF)))
			for r in rows:
				var h := size.y/rows
				var y := xf.origin.y-size.y*0.5+h*(r+0.5)
				var cut := rng.randf_range(-0.25,0.25)*size.x
				for seg: Vector2 in [Vector2(-size.x*0.5,cut),Vector2(cut,size.x*0.5)]:
					block(m,at(Vector3(xf.origin.x+(seg.x+seg.y)*0.5,y,xf.origin.z)),Vector3(seg.y-seg.x-0.04,h-0.04,size.z-0.04),0.1,rng.randf_range(0.88,1.08)*(1.0-0.25*float(r < rows-3)))
		var mi := MeshInstance3D.new()
		mi.name = name_s
		mi.mesh = Stone.mesh_of(m)
		add_child(mi)
		var body := static_body(name_s+"Body",boxes)
		body.name = name_s+"Body"

## As built: standing, held.
func _stand() -> void:
	phi = PI*0.5-LEAN
	omega = 0.0
	tell_t = 0.0
	var runes: Array = []
	for s: float in [-1.0,1.0]:
		var y := s*(SLAB.y*0.5+0.01)
		runes.append([Vector3(-SLAB.x*0.5+0.6,y,SLAB.z*0.5-2.6),Vector3(SLAB.x*0.5-0.6,y,SLAB.z*0.5-2.6),Vector3(0.0,0.0,1.0),Vector3(0.0,s,0.0),float(seed_value)+s])
	# The slab, its chisel line and rope scars (pale cuts) drawn in.
	var blocks: Array = [[Transform3D.IDENTITY,SLAB,1.0,0.3]]
	blocks.append([at(Vector3(0.0,SLAB.y*0.5,SLAB.z*0.5-1.4)),Vector3(SLAB.x-0.4,0.06,0.14),FRESH*1.2,0.0])
	for s: float in [-1.0,1.0]:
		blocks.append([at(Vector3(s*(SLAB.x*0.5-1.6),0.0,SLAB.z*0.5-0.35)),Vector3(0.5,SLAB.y+0.04,0.25),FRESH,0.05])
	slab = mesh_node("Slab",part_mesh(blocks,Transform3D.IDENTITY,0.2,runes),slab_xf(phi))
	slab_body = StaticBody3D.new()
	slab_body.name = "SlabBody"
	add_child(slab_body)
	box_shape(slab_body,SLAB,Transform3D.IDENTITY)
	slab_body.transform = slab_xf(phi)
	# The hinge stones either side of its foot.
	var hinge: Array = []
	for s: float in [-1.0,1.0]:
		hinge.append([at(Vector3(s*(SLAB.x*0.5+0.55),0.45,-BEAR)),Vector3(0.9,0.9,1.4),0.95,0.2])
	mesh_node("Hinge",part_mesh(hinge,Transform3D.IDENTITY,0.2))
	# The plate on the chock, the striker's block, the lever and its rope.
	var pc := Vector3(PLATE_AT.x,PLATE_RISE*0.5,PLATE_AT.y)
	plate = mesh_node("Plate",part_mesh([[at(pc),Vector3(PLATE,PLATE_RISE,PLATE),FRESH*0.9,0.06]],at(pc),0.0),at(pc))
	var sb := striker_boxes()
	var sblocks: Array = []
	for b: Array in sb: sblocks.append([b[0],b[1],0.95,0.12])
	mesh_node("Striker",part_mesh(sblocks,Transform3D.IDENTITY,0.3))
	var bodies_boxes: Array = [[at(Vector3(pc.x,(PLATE_RISE+LIFT)*0.5,pc.z)),Vector3(PLATE,PLATE_RISE-LIFT,PLATE)]]
	bodies_boxes.append_array(sb)
	static_body("Works",bodies_boxes)
	var cc := Vector3(PLATE_AT.x+PLATE*0.5+0.5,0.45,PLATE_AT.y)
	chock = mesh_node("Chock",part_mesh([[Transform3D(Basis(Vector3(0.0,0.0,1.0),0.35),cc),Vector3(1.2,0.7,1.6),0.8,0.1]],at(cc),0.0),at(cc))
	var lv := lever_top()
	var wood := Stone.Mesher.new(Color(0.3,0.22,0.15),0.0)
	for s: float in [-1.0,1.0]:
		var foot := Vector3(PLATE_AT.x+s*1.0,0.0,PLATE_AT.y+1.4)
		var mid := (foot+lv)*0.5
		var len := foot.distance_to(lv)
		var up := (lv-foot).normalized()
		var bxx := up.cross(Vector3(0.0,0.0,1.0))
		if bxx.length() < 0.01: bxx = Vector3.RIGHT
		bxx = bxx.normalized()
		block(wood,Transform3D(Basis(bxx,up,bxx.cross(up).normalized()),mid),Vector3(0.35,len,0.35),0.08)
	block(wood,at(lv),Vector3(2.6,0.4,0.4),0.08)
	lever = mesh_node("Lever",Stone.mesh_of(wood))
	var wc := lv+Vector3(0.0,-2.2,-0.6)
	weight = mesh_node("Weight",part_mesh([[at(wc),Vector3(1.4,1.2,1.4),0.85,0.3]],at(wc),0.1),at(wc))
	rope = MeshInstance3D.new()
	rope.name = "Rope"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	rope.mesh = cyl
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.42,0.34,0.22)
	rm.roughness = 1.0
	rope.material_override = rm
	add_child(rope)
	_rope()

## The striker's block (piece frame): two tiers behind the plate.
func striker_boxes() -> Array:
	var z_edge := PLATE_AT.y-PLATE*0.5-STRIKER_GAP
	var deep := 2.4
	return [[at(Vector3(PLATE_AT.x,(STRIKER.y+LIFT)*0.5,z_edge-deep*0.5)),Vector3(3.0,STRIKER.y-LIFT,deep)],
		[at(Vector3(PLATE_AT.x,(STRIKER.x+LIFT)*0.5,z_edge-deep-1.2)),Vector3(3.0,STRIKER.x-LIFT,2.4)]]

func lever_top() -> Vector3:
	return Vector3(PLATE_AT.x,6.4,PLATE_AT.y+1.4)

## The rope from the slab's crown to the lever (standing).
func _rope() -> void:
	if not is_instance_valid(rope): return
	var a := slab_xf(phi)*Vector3(0.0,SLAB.y*0.5,SLAB.z*0.5-0.6)
	var b := lever_top()
	var mid := (a+b)*0.5
	var up := (a-b).normalized()
	var side := up.cross(Vector3.RIGHT).normalized()
	rope.transform = Transform3D(Basis(up.cross(side).normalized(),up*a.distance_to(b),side),mid)

# --- Triggers ---------------------------------------------------------------------------

func standing_rids() -> Array[RID]:
	var out: Array[RID] = []
	if state == "falling" and is_instance_valid(slab_body): out.append(slab_body.get_rid())
	return out

func _on_plate(p: Vector3, margin: float) -> bool:
	var q := to_local(p)
	return absf(q.x-PLATE_AT.x) <= PLATE*0.5+margin and absf(q.z-PLATE_AT.y) <= PLATE*0.5+margin and absf(q.y-PLATE_RISE) < 1.2

func _met(b: Node3D) -> void:
	if state != "whole": return
	if _on_plate(b.position,0.4): release("body")

func _wave(_b: Node3D, w: Dictionary) -> bool:
	if state != "whole": return true
	var origin: Vector3 = w.at
	var q := to_local(origin)
	var d := Vector2(q.x-PLATE_AT.x,q.z-PLATE_AT.y).length()
	if d > SHOCK_NEAR or absf(q.y) > 4.0 or float(w.power) < SHOCK_LEAST: return true
	if float(w.r) < d: return false
	release("shock")
	return true

func _slam(at_p: Vector3, _radius: float, strength: float) -> void:
	if state != "whole" or strength < SLAM_LEAST: return
	if _on_plate(at_p,0.6): release("slam")

## Struck: the tell, then the swing.
func release(why: String) -> void:
	if state != "whole": return
	state = "cracked"
	cause = why
	tell_t = 0.0
	fall_s = 0.0
	var pc := to_global(Vector3(PLATE_AT.x,PLATE_RISE,PLATE_AT.y))
	_sound(&"ruin_crack",pc)
	_shake(0.5)
	Dust.puff(get_parent(),pc,2.0)
	# The plate gives (the striker rides it down a hand), the chock flies.
	plate.position.y -= 0.12
	var c0 := chock.transform
	fly(chock,Transform3D(Basis.from_euler(Vector3(1.4,0.8,2.2)),c0.origin+Vector3(4.5,-0.1,1.5)),0.0,0.45,1.6,{"kind":"chock"})
	fly(weight,Transform3D(Basis.from_euler(Vector3(0.2,0.4,0.1)),Vector3(weight.position.x,0.6,weight.position.z)),0.05,0.4,0.0,{"kind":"weight"})
	if is_instance_valid(rope): rope.visible = false
	Dust.puff(get_parent(),to_global(slab_xf(phi)*Vector3(0.0,SLAB.y*0.5,SLAB.z*0.5-0.6)),2.5)

func _step(delta: float) -> void:
	if not flights.is_empty(): fly_step(delta)
	match state:
		"whole":
			var m := motor()
			# A stunned body thrown down onto the plate: its weight counts.
			if m != null and m.grounded and m.move == "tumble" and _on_plate(m.feet,0.2): release("toss")
		"cracked":
			tell_t += delta
			fall_s += delta
			# It rocks back a hair as the rope goes, then goes over.
			var back := sin(PI*clampf(tell_t/TELL,0.0,1.0))*0.03
			_set_phi(PI*0.5-LEAN+back)
			if tell_t >= TELL:
				state = "falling"
				omega = SWING_W0
				_sound(&"ruin_fall",to_global(slab_xf(phi)*Vector3.ZERO))
		"falling":
			fall_s += delta
			if _bounce >= 0.0:
				_bounce += delta
				var k := clampf(_bounce/0.3,0.0,1.0)
				_set_phi(0.025*sin(PI*k))
				if k >= 1.0: _rest()
				return
			omega += SWING_PULL*cos(phi)*delta
			phi -= omega*delta
			if phi <= 0.0:
				phi = 0.0
				_impact()
			_set_phi(phi)

func _set_phi(a: float) -> void:
	var xf := slab_xf(a)
	slab.transform = xf
	slab_body.transform = xf

## Down across the gap: the boom, the dust down its length, the trap.
func _impact() -> void:
	_bounce = 0.0
	var a := to_global(Vector3(0.0,0.0,0.0))
	var b := to_global(Vector3(0.0,0.0,gap()))
	dust_line(a,b,5.0,3.0)
	Dust.rocks(get_parent(),to_global(Vector3(0.0,0.5,gap()+BEAR)),global_transform.basis.z,20,0.4)
	_sound(&"ruin_boom",(a+b)*0.5)
	_shake(1.4)
	_pause(4,0.15)
	var m := motor()
	if m != null and not m.seized():
		var q := to_local(m.feet)
		if absf(q.x) < SLAB.x*0.5+0.6 and q.z > gap()-1.0 and q.z < gap()+BEAR+2.5 and absf(q.y) < 2.5:
			var out := global_transform.basis.z
			hit(m,"maker_chock","under",m.knock_velocity(Vector2(out.x,out.z),UNDER.x,UNDER.y))
	var boxes := rest_boxes()
	lift_bodies(boxes)

## Its rest (piece frame): the slab flat in its sockets, top flush.
func rest_boxes() -> Array:
	return [[slab_xf(0.0)*Transform3D(Basis.IDENTITY,Vector3(0.0,LIFT*0.5,0.0)),SLAB-Vector3(0.0,LIFT,0.0)]]

func _rest() -> void:
	state = "fallen"
	_set_phi(0.0)
	# The swinging body becomes the rest: its shape trimmed off the
	# sockets' floors (LIFT), ground to both.
	for c: Node in slab_body.get_children(): c.free()
	box_shape(slab_body,SLAB-Vector3(0.0,LIFT,0.0),Transform3D(Basis.IDENTITY,Vector3(0.0,LIFT*0.5,0.0)))
	tell(world_box(rest_boxes(),4.0))

## For the yard's printout: [name, value, against, ok].
static func fit(body_jump_gap: float) -> Array:
	var grab := RuinKit.GRAB_TOP*WorldScale.wanderer
	return [
		["chock: gap past his jump (m)",gap(),body_jump_gap,gap() > body_jump_gap],
		["chock: slab his lane wide (m)",SLAB.x,LANE,SLAB.x >= LANE],
		["chock: striker tiers under the walker's grab (m)",STRIKER.y-STRIKER.x,grab,STRIKER.y-STRIKER.x < grab and STRIKER.x < grab],
		["chock: striker top over the slam's air (m)",STRIKER.y+PilotMotor.JUMPS[0]-PLATE_RISE,Slam.LOW,STRIKER.y+PilotMotor.JUMPS[0]-PLATE_RISE > Slam.LOW],
	]
