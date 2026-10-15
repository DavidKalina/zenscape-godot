extends "res://scripts/city_breaks/stone_break.gd"
## The corbel vault, maker_corbel (docs/design/roguelike/city-breaks-round2.md;
## card: brainstorm/round3-olmec-city/kit-k4-destruction.md): a gate of the
## makers, a hall his lane wide and tall enough for him, roofed the
## Mesoamerican way (no arch: three courses each jutting a set-off further
## in, a capstone over the slot), its roof a flat walk over solid haunches.
## Its outer bay's capstone is cracked (a dark seam, grit sifting).
##
## Shake it down and that bay's roof, courses and haunch core come in: the
## bay becomes an open trench, a heap of stone in it spilling out of the
## mouth, the west haunch broken to the jamb's top, the east one broken into
## a stair of standing courses that climbs to the inner bay's roof. So the
## gate he walks through stays his (he walks the heap: steps of HEAP_STEP, a
## lane wide, open sky over it), and the roof, out of the wanderer's reach
## while it stood, is now his way up: heap, broken stair, roof, and on to
## whatever the roof meets (in the yard, an upper terrace).
##
## The piece's frame: the hall along Z, the floor on y 0, the cracked bay
## z -BAY_L..0 (toward -Z), the whole bay 0..BAY_L.
##
## Who brings it down:
##   shock  his landing's shockwave starting within SHOCK_NEAR m of the
##          cracked bay (on the floor at its mouth, in the hall, or on the
##          roof), power at least SHOCK_LEAST.
##   slam   the wanderer's slam onto the cracked capstone (its roof).
## What it does to the wanderer: under it on the floor, a hard knock out
## along the hall to the nearer mouth (source "maker_corbel", laid down
## DOWN s); in the spill's way outside the mouth, a knock out of it.
const BAY_L := 1.5*CELL
const HALF := LANE*0.5
## The jambs' height (his bulk with room), the courses (rise, jut), the
## capstone's thickness, the haunches' outer face.
const JAMB_H := 2.0*COURSE
const COURSES := 3
const JUT := CELL*0.25
const CAP := 1.2
const MASS := CELL
## The gate's foundation under its floor (m): the haunches' columns and the
## hall's paving go down this far (it stands on a neck over the void).
const FLOOR_D := COURSE
## The heap: a step's rise (a jump for the walker; low, so its rise within
## his reach stays under his wall rays' knee: he walks it, not climbs), its
## steps in the bay and out of the mouth, its run (m a step).
const HEAP_STEP := 0.5*SET_OFF
const HEAP_RUN := 1.5
## The paving left clear inside the fallen bay by the whole one (m): his
## bulk's front half, so he is down off the heap before his head is under
## the whole bay's courses.
const HEAP_CLEAR := 1.8
const HEAP_IN := 4
const SPILL_WIDE := 1.5*CELL
## The east broken stair: its first top, then a SET_OFF a tread.
const STAIR_FROM := 3.0*SET_OFF
const SHOCK_NEAR := 6.0
const SHOCK_LEAST := 0.4
const SLAM_LEAST := 0.25
## The hits: under it (m out, m up, s laid down), in the spill (m, m).
const UNDER := Vector3(8.0,1.5,1.0)
const SPILL := Vector2(6.0,1.5)

var whole_mesh: MeshInstance3D
var whole_body: StaticBody3D
var broken_mesh: MeshInstance3D
var heap_mesh: MeshInstance3D
var rest_body: StaticBody3D
var crack_mesh: MeshInstance3D
var _rest_boxes: Array = []
var _sift := 0.0
var _shown := false

static func roof() -> float:
	return JAMB_H+COURSES*SET_OFF+CAP

static func outer() -> float:
	return HALF+MASS

func build(seed_in: int, weathered_in := 0.0) -> void:
	_setup("maker_corbel",seed_in,weathered_in)
	_shell()
	_whole()

func reset() -> void:
	for n: Node in get_children():
		if n is Node3D and String(n.name) not in ["Shell","ShellBody"]: n.free()
	flights.clear()
	dealt.clear()
	state = "whole"
	cause = ""
	fall_s = 0.0
	_shown = false
	_whole()

# --- The stone -------------------------------------------------------------------------

## A bay's whole structure (z0..z1): the haunch columns, the courses, the
## capstone; as [[xf, size, tone, bevel]] (drawn) and [[xf, size]] (its
## columns, side by side: nothing stood on another's top).
func _bay(z0: float, z1: float, draw: Array, cols: Array, rng: RandomNumberGenerator) -> void:
	var zc := (z0+z1)*0.5
	var zl := z1-z0
	var r := roof()
	for s: float in [-1.0,1.0]:
		# The haunch: coursed blocks up to the roof.
		var rows := int(round(r/SET_OFF))
		for k in rows:
			var y0 := k*r/rows
			var y1 := (k+1)*r/rows
			var cut := zc+rng.randf_range(-0.3,0.3)*zl
			for seg: Vector2 in [Vector2(z0,cut),Vector2(cut,z1)]:
				draw.append([at(Vector3(s*(HALF+MASS*0.5),(y0+y1)*0.5,(seg.x+seg.y)*0.5)),Vector3(MASS-0.04,y1-y0-0.04,seg.y-seg.x-0.04),rng.randf_range(0.88,1.06),0.1])
		cols.append([at(Vector3(s*(HALF+MASS*0.5),(r-FLOOR_D)*0.5,zc)),Vector3(MASS,r+FLOOR_D,zl)])
		draw.append([at(Vector3(s*(HALF+MASS*0.5),-FLOOR_D*0.5,zc)),Vector3(MASS-0.04,FLOOR_D-0.04,zl-0.04),0.8,0.1])
		# The courses: each juts JUT further in, hung from the roof.
		for k in COURSES:
			var y0 := JAMB_H+k*SET_OFF
			var x_in := HALF-JUT*(k+1)
			draw.append([at(Vector3(s*(x_in+JUT*0.5),y0+SET_OFF*0.5,zc)),Vector3(JUT-0.03,SET_OFF-0.04,zl-0.04),rng.randf_range(0.86,1.0),0.14])
			cols.append([at(Vector3(s*(x_in+JUT*0.5),(y0+r)*0.5,zc)),Vector3(JUT,r-y0,zl)])
		# The roof deck over the courses' backs.
		var x_cap := HALF-JUT*COURSES+JUT
		draw.append([at(Vector3(s*(x_cap+(HALF-x_cap)*0.5),r-CAP*0.5,zc)),Vector3(HALF-x_cap-0.04,CAP-0.04,zl-0.04),1.0,0.1])
	# The capstone: one slab over the slot, bearing on the top course.
	var cap_w := 2.0*(HALF-JUT*(COURSES-1))
	draw.append([at(Vector3(0.0,r-CAP*0.5,zc)),Vector3(cap_w-0.06,CAP-0.04,zl-0.06),0.95,0.18])
	cols.append([at(Vector3(0.0,r-CAP*0.5,zc)),Vector3(2.0*(HALF-JUT*COURSES),CAP,zl)])

## The whole bay (z 0..BAY_L), never broken, and its faces' glyphs.
func _shell() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*41+7
	var draw: Array = []
	var cols: Array = []
	_bay(0.0,BAY_L,draw,cols,rng)
	# The hall's paving, both bays (it never breaks).
	for k in 6:
		var z0 := -BAY_L+k*BAY_L/3.0
		draw.append([at(Vector3(0.0,-0.3,z0+BAY_L/6.0)),Vector3(LANE-0.06,0.6,BAY_L/3.0-0.06),rng.randf_range(0.85,1.0),0.06])
	draw.append([at(Vector3(0.0,-FLOOR_D*0.5-0.3,0.0)),Vector3(LANE-0.06,FLOOR_D-0.6,2.0*BAY_L-0.06),0.8,0.1])
	cols.append([at(Vector3(0.0,-FLOOR_D*0.5,0.0)),Vector3(LANE,FLOOR_D,2.0*BAY_L)])
	var runes: Array = []
	var r := roof()
	for s: float in [-1.0,1.0]:
		var xf := s*(outer()+0.01)
		runes.append([Vector3(xf,r-2.6,BAY_L-0.4),Vector3(xf,r-2.6,0.4),Vector3.UP,Vector3(s,0.0,0.0),float(seed_value)+s])
	runes.append([Vector3(-HALF-MASS+0.4,r-2.4,BAY_L+0.01),Vector3(HALF+MASS-0.4,r-2.4,BAY_L+0.01),Vector3.UP,Vector3(0.0,0.0,1.0),float(seed_value)+3.0])
	mesh_node("Shell",part_mesh(draw,Transform3D.IDENTITY,0.3,runes))
	static_body("ShellBody",cols)

## The cracked bay standing, its seam.
func _whole() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*43+11
	var draw: Array = []
	var cols: Array = []
	_bay(-BAY_L,0.0,draw,cols,rng)
	var runes: Array = []
	var r := roof()
	for s: float in [-1.0,1.0]:
		runes.append([Vector3(s*(outer()+0.01),r-2.6,-0.4),Vector3(s*(outer()+0.01),r-2.6,-BAY_L+0.4),Vector3.UP,Vector3(s,0.0,0.0),float(seed_value)+s*2.0])
	runes.append([Vector3(HALF+MASS-0.4,r-2.4,-BAY_L-0.01),Vector3(-HALF-MASS+0.4,r-2.4,-BAY_L-0.01),Vector3.UP,Vector3(0.0,0.0,-1.0),float(seed_value)+5.0])
	whole_mesh = mesh_node("Whole",part_mesh(draw,Transform3D.IDENTITY,0.3,runes))
	whole_body = static_body("WholeBody",cols)
	# The seam: a dark crack along the capstone's underside and its top,
	# the grit trickling from it.
	var m := mesher(0.0)
	var slot := 2.0*(HALF-JUT*COURSES)
	for y: float in [r-CAP-0.02,r+0.02]:
		block(m,at(Vector3(0.15,y,-BAY_L*0.5),0.05),Vector3(0.08,0.05,BAY_L-0.6),0.0,0.35)
	block(m,at(Vector3(-slot*0.3,r-CAP-0.02,-BAY_L*0.62),0.9),Vector3(0.07,0.05,2.6),0.0,0.35)
	crack_mesh = mesh_node("Seam",Stone.mesh_of(m))
	broken_mesh = null
	heap_mesh = null

# --- The rest ----------------------------------------------------------------------------

## The heap's tops along the hall (piece frame z, -Z out of the mouth):
## [z_from, z_to, top, wide].
func heap_runs() -> Array:
	var out: Array = []
	# Clear of the whole bay by HEAP_CLEAR (his bulk's front half and a
	# little: on a step his head would meet its courses), then up in even
	# runs to the plateau at the mouth.
	var z := -HEAP_CLEAR
	var run := (BAY_L-HEAP_CLEAR)/HEAP_IN
	for k in range(1,HEAP_IN+1):
		var z1 := z-run if k < HEAP_IN else -BAY_L
		out.append([z1,z,HEAP_STEP*k,LANE])
		z = z1
	for k in range(HEAP_IN-1,0,-1):
		var z1 := z-HEAP_RUN
		out.append([z1,z,HEAP_STEP*k,LANE+2.0*SPILL_WIDE*float(HEAP_IN-k)/HEAP_IN])
		z = z1
	return out

## The east broken stair: [z_from, z_to, top], a SET_OFF a tread up to the
## whole bay's roof.
func stair_runs() -> Array:
	var out: Array = []
	var top := STAIR_FROM
	var steps := int(ceil((roof()-SET_OFF*0.75-STAIR_FROM)/SET_OFF))+1
	var tread := BAY_L/steps
	for k in steps:
		var z0 := -BAY_L+k*tread
		out.append([z0,z0+tread,minf(top,roof()-SET_OFF*0.75)])
		top += SET_OFF
	return out

## The rest's columns (piece frame): the west haunch to the jamb's top,
## the east stair, the heap. [[xf, size]].
func rest_boxes() -> Array:
	var out: Array = []
	out.append([at(Vector3(-HALF-MASS*0.5,(JAMB_H-FLOOR_D)*0.5,-BAY_L*0.5)),Vector3(MASS,JAMB_H+FLOOR_D,BAY_L)])
	for s: Array in stair_runs():
		var z0: float = s[0]
		var z1: float = s[1]
		var top: float = s[2]
		out.append([at(Vector3(HALF+MASS*0.5,(top-FLOOR_D)*0.5,(z0+z1)*0.5)),Vector3(MASS,top+FLOOR_D,z1-z0)])
	for h: Array in heap_runs():
		var z0: float = h[0]
		var z1: float = h[1]
		var top: float = h[2]
		var wide: float = h[3]
		out.append([at(Vector3(0.0,(top+LIFT)*0.5,(z0+z1)*0.5)),Vector3(wide,top-LIFT,z1-z0)])
	return out

func _lay_broken() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*47+5
	var draw: Array = []
	# The west haunch: coursed to the jamb's top, its top ragged and pale.
	var rows := int(round(JAMB_H/SET_OFF))
	for k in rows:
		var y0 := k*JAMB_H/rows
		var y1 := (k+1)*JAMB_H/rows
		var top_row := k == rows-1
		draw.append([at(Vector3(-HALF-MASS*0.5,(y0+y1)*0.5,-BAY_L*0.5),rng.randf_range(-0.02,0.02)*float(top_row)),Vector3(MASS-0.04,y1-y0-0.04,BAY_L-0.04),FRESH if top_row else rng.randf_range(0.88,1.05),0.12])
	# The east stair: each tread a column of courses, its top course pale.
	for s: Array in stair_runs():
		var z0: float = s[0]
		var z1: float = s[1]
		var top: float = s[2]
		var n := maxi(1,int(round(top/SET_OFF)))
		for k in n:
			var y0 := k*top/n
			var y1 := (k+1)*top/n
			var last := k == n-1
			draw.append([at(Vector3(HALF+MASS*0.5+rng.randf_range(-0.05,0.05)*float(last),(y0+y1)*0.5,(z0+z1)*0.5)),Vector3(MASS-0.04-rng.randf_range(0.0,0.3)*float(last),y1-y0-0.04,z1-z0-0.04),FRESH if last else rng.randf_range(0.88,1.05),0.12])
	for sx: float in [-1.0,1.0]:
		draw.append([at(Vector3(sx*(HALF+MASS*0.5),-FLOOR_D*0.5,-BAY_L*0.5)),Vector3(MASS-0.04,FLOOR_D-0.04,BAY_L-0.04),0.8,0.1])
	broken_mesh = mesh_node("Broken",part_mesh(draw,Transform3D.IDENTITY,0.15))
	# The heap: pale chunks tumbled over each walk box.
	var m := mesher(0.0)
	for h: Array in heap_runs():
		var z0: float = h[0]
		var z1: float = h[1]
		var top: float = h[2]
		var wide: float = h[3]
		block(m,at(Vector3(0.0,top*0.5-0.05,(z0+z1)*0.5)),Vector3(wide-0.3,top-0.1,z1-z0-0.05),0.3,0.72)
		var n := maxi(3,int(wide*(z1-z0)/4.5))
		for k in n:
			var cs := Vector3(rng.randf_range(1.0,2.8),rng.randf_range(0.5,1.1),rng.randf_range(0.9,2.0))
			var p := Vector3(rng.randf_range(-wide*0.5+0.7,wide*0.5-0.7),top-cs.y*0.5+rng.randf_range(-0.1,0.25),rng.randf_range(z0+0.4,z1-0.4))
			block(m,Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.15,0.15),rng.randf_range(-PI,PI),rng.randf_range(-0.15,0.15))),p),cs,0.2,FRESH*rng.randf_range(0.62,0.95))
	heap_mesh = mesh_node("Heap",Stone.mesh_of(m))
	heap_mesh.visible = false

# --- Triggers ----------------------------------------------------------------------------

## Flat distance (m) from world `p` to the cracked bay's footprint.
func _off_bay(p: Vector3) -> float:
	var q := to_local(p)
	var dx := maxf(absf(q.x)-outer(),0.0)
	var dz := maxf(maxf(q.z,-BAY_L-q.z),0.0)
	return Vector2(dx,dz).length()

func _wave(_b: Node3D, w: Dictionary) -> bool:
	if state != "whole": return true
	var origin: Vector3 = w.at
	var d := _off_bay(origin)
	var y := to_local(origin).y
	if d > SHOCK_NEAR or float(w.power) < SHOCK_LEAST: return true
	if absf(y) > 3.0 and absf(y-roof()) > 3.0: return true
	if float(w.r) < d: return false
	fall("shock")
	return true

func _slam(at_p: Vector3, _radius: float, strength: float) -> void:
	if state != "whole" or strength < SLAM_LEAST: return
	var q := to_local(at_p)
	if absf(q.y-roof()) < 1.0 and q.z < 0.0 and q.z > -BAY_L and absf(q.x) < outer(): fall("slam")

## It comes down.
func fall(why: String) -> void:
	if state != "whole": return
	state = "falling"
	cause = why
	fall_s = 0.0
	whole_body.free()
	whole_mesh.visible = false
	crack_mesh.visible = false
	_lay_broken()
	_rest_boxes = rest_boxes()
	# The pieces: the capstone in two, each haunch's courses and core in
	# three slabs a side, each in two along the bay; they drop into the
	# hall and burst there, under the dust.
	var r := roof()
	var parts: Array = []
	for half_z: Vector2 in [Vector2(-BAY_L,-BAY_L*0.5),Vector2(-BAY_L*0.5,0.0)]:
		var zc := (half_z.x+half_z.y)*0.5
		var zl := half_z.y-half_z.x-0.1
		var cap_w := 2.0*(HALF-JUT*(COURSES-1))
		parts.append([Vector3(0.0,r-CAP*0.5,zc),Vector3(cap_w,CAP,zl),0.0])
		for s: float in [-1.0,1.0]:
			parts.append([Vector3(s*(HALF-JUT*2.0+MASS)*0.5+s*JUT,r-0.9,zc),Vector3(HALF+MASS-JUT*2.0,1.8,zl),0.15])
			parts.append([Vector3(s*(HALF-JUT*1.5+MASS*0.5),JAMB_H+SET_OFF*1.5,zc),Vector3(JUT*1.5+MASS*0.7,SET_OFF*1.6,zl),0.35])
			parts.append([Vector3(s*(HALF-JUT*0.5+MASS*0.4),JAMB_H+SET_OFF*0.5,zc),Vector3(JUT+MASS*0.6,SET_OFF,zl),0.55])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*53+1
	for i in parts.size():
		var c: Vector3 = parts[i][0]
		var size: Vector3 = parts[i][1]
		var delay: float = parts[i][2]+rng.randf_range(0.0,0.12)
		var mi := mesh_node("Piece%d" % i,part_mesh([[at(c),size,0.95,0.15]],at(c),0.2),at(c))
		var land := Vector3(c.x*0.35+rng.randf_range(-1.2,1.2),HEAP_STEP*2.0,clampf(c.z+rng.randf_range(-2.5,0.5),-BAY_L-3.0,-0.8))
		var drop := c.y-land.y
		var t := sqrt(2.0*drop/14.0)
		fly(mi,Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.9,0.9),rng.randf_range(-0.6,0.6),rng.randf_range(-0.9,0.9))),land),delay,t,0.3,{"i":i})
	var mid := to_global(Vector3(0.0,r,-BAY_L*0.5))
	_sound(&"ruin_crack",mid)
	_sound(&"ruin_fall",mid)
	_shake(1.0)
	_pause(3,0.2)
	Dust.plume(get_parent(),to_global(Vector3(0.0,r,-BAY_L*0.5)),6.0)
	Dust.rocks(get_parent(),mid,Vector3.DOWN,24,0.5)
	# Under it: a hard knock out along the hall.
	var m := motor()
	if m != null and not m.seized():
		var q := to_local(m.feet)
		if absf(q.x) < HALF and q.z < 0.3 and q.z > -BAY_L-0.3 and q.y < JAMB_H:
			var way := 1.0 if q.z > -BAY_L*0.5 else -1.0
			var dir := global_transform.basis.z*way
			hit(m,"maker_corbel","under",m.knock_velocity(Vector2(dir.x,dir.z),UNDER.x,UNDER.y),false,UNDER.z)
		elif absf(q.y-r) < 1.0 and q.z < 0.0 and q.z > -BAY_L and absf(q.x) < outer():
			hit(m,"maker_corbel","roof",Vector3(0.0,2.0,0.0)-global_transform.basis.z*2.0,true)

func _landed(f: Dictionary) -> void:
	var node: Node3D = f.node
	var p := node.global_position
	Dust.plume(get_parent(),Vector3(p.x,p.y-0.5,p.z),5.0)
	_sound(&"ruin_boom",p)
	_shake(0.8)
	node.visible = false
	if not _shown:
		_shown = true
		heap_mesh.visible = true
		Dust.rocks(get_parent(),to_global(Vector3(0.0,HEAP_STEP*2.0,-BAY_L-1.0)),-global_transform.basis.z,24,0.5)
		rest_body = static_body("Rest",_rest_boxes)
		lift_bodies(_rest_boxes)
		var m := motor()
		if m != null and not m.seized():
			var q := to_local(m.feet)
			if absf(q.x) < HALF+SPILL_WIDE and q.z < -BAY_L and q.z > -BAY_L-HEAP_RUN*HEAP_IN and q.y < 2.0:
				var dir := -global_transform.basis.z
				hit(m,"maker_corbel","spill",m.knock_velocity(Vector2(dir.x,dir.z),SPILL.x,SPILL.y))
		tell(world_box(_rest_boxes,3.0))

func _step(delta: float) -> void:
	if state == "whole":
		_sift -= delta
		if _sift <= 0.0:
			_sift = _rng.randf_range(1.5,3.0)
			Dust.puff(get_parent(),to_global(Vector3(_rng.randf_range(-0.8,0.8),roof()-CAP-0.1,-_rng.randf_range(0.8,BAY_L-0.8))),0.9,Vector3.DOWN)
		return
	if state != "falling": return
	fall_s += delta
	if not fly_step(delta):
		state = "fallen"
		tell(world_box(_rest_boxes,3.0))

## For the yard's printout: [name, value, against, ok].
static func fit(body_top: float, body_wide: float) -> Array:
	var grab := RuinKit.GRAB_TOP*WorldScale.wanderer
	var stair_rise := SET_OFF
	return [
		["corbel: jambs over his bulk (m)",JAMB_H,body_top,JAMB_H > body_top],
		["corbel: lowest course over his breadth (m clear)",2.0*(HALF-JUT),body_wide,2.0*(HALF-JUT) > body_wide*0.95],
		["corbel: heap step under his stride and the walker's grab (m)",HEAP_STEP,minf(OLMEC_STEP,grab),HEAP_STEP < minf(OLMEC_STEP,grab)],
		["corbel: heap top to the stair's first tread (m), a grab",STAIR_FROM-HEAP_STEP*HEAP_IN,grab,STAIR_FROM-HEAP_STEP*HEAP_IN < grab],
		["corbel: stair rise under the walker's grab (m)",stair_rise,grab,stair_rise < grab],
		["corbel: roof (m), out of the walker's reach standing",roof(),grab,roof() > grab*3.0],
	]
