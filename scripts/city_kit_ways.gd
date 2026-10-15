extends RefCounted
## The city kit's crossings (docs/design/roguelike/layer-round15-city-
## crossings.md): the pieces the generator's crossings between city places
## are drawn with (scripts/roguelike/city_crossings.gd, the plan's shapes in
## scripts/roguelike/city_ways.gd), in the kit's weathered basalt (scripts/
## city_kit_stone.gd) on a CityKit `Piece`:
##   span        a causeway span between two joints, in its state: whole
##               (paved, curbed, a fret down its faces), gone (two broken
##               stubs, the fallen deck lodged on a pier far below), sagged
##               (two halves down into a cracked V), slumped (dropped flat
##               between two pier caps)
##   joint_pier  the pier under a joint: a capping course, corbels, a
##               battered shaft into the haze
##   drum_pier   a staggered pier: a stack of eight-sided drums, each a
##               little off the one under it, the top one the walked one
##   step_drum   a low broken column stump (a step on the slow line)
##   chute       the spillway: a swept channel (floor, banked; a ramp each
##               side up to a coping curb), one trimesh for the walked faces,
##               on hex piers, roots off its soffit
## Collision is clean (boxes, hulls, one trimesh); drawn stone is chipped
## and coursed. Roots are gathered (`roots`, Vector4 as HangingRoots
## `batch` takes) for the caller to hang once.
const CityKit = preload("res://scripts/city_kit.gd")
const Stone = preload("res://scripts/city_kit_stone.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## A causeway's deck: width, thickness, its curbs (width, height over the
## deck); a paving slab about this long; a curb block about this long and
## the share missing.
const DECK := 3.0
const DECK_THICK := 1.1
const CURB := Vector2(0.4,0.3)
const SLAB := Vector2(1.4,2.2)
const CURB_RUN := Vector2(1.2,2.4)
const CURB_GONE := 0.15
## A joint's pier: its cap's depth along (m, the cap's top flush with the
## deck), how far down (m), its shaft's share of the deck's width.
const CAP := 1.4
const PIER_DOWN := Vector2(30.0,55.0)
const PIER_IN := 0.62
## A whole span longer than this gets piers between its joints too.
const PIER_EVERY := 9.0
## A drum pier: a course's height (m), how many drawn courses, the shaft
## under them (m), how far a course sits off the one under it (share of
## the radius), its sides.
const COURSE := Vector2(0.8,1.3)
const COURSES := Vector2i(3,6)
const DRUM_DOWN := Vector2(26.0,50.0)
const COURSE_OFF := 0.05
const DRUM_SIDES := 8
## The chute: the floor's thickness under its middle, the coping (width,
## height over the ramp's top: a parapet over his step-up, so a carve into
## the wall rides along it, never over), a pier about every CHUTE_PIER m.
const CHUTE_THICK := 1.0
const COPE := Vector2(0.5,PilotMotor.STEP_UP*1.35)
const CHUTE_PIER := 10.0
## A chute pier goes this far down (m): into the haze, its foot never seen.
const CHUTE_DOWN := Vector2(34.0,60.0)

# --- Causeway spans --------------------------------------------------------------------

## The frame of a deck from `a` to `z` (deck tops): [basis (x across, y up,
## z along), its length, along (unit), across (unit), up (unit)].
static func _frame(a: Vector3, z: Vector3) -> Array:
	var along := z-a
	var length := along.length()
	var dir := along/maxf(length,1e-4)
	var flat := Vector3(dir.x,0.0,dir.z).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	var up := dir.cross(side).normalized()
	if up.y < 0.0: up = -up
	return [Basis(side,up,dir),length,dir,side,up]

## A deck from `a` to `z` (its top's middle line): collided clean, drawn as
## paving slabs, curbs a hand high (drawn, some gone), a carved fret down
## each face. `chips` the slabs' wear. `cut_a`/`cut_z`: the ends broken (no
## slab runs flush there; ragged teeth).
static func deck(b: CityKit.Piece, a: Vector3, z: Vector3, chips := 0.7, cut_a := false, cut_z := false) -> void:
	var f := _frame(a,z)
	var basis: Basis = f[0]
	var length: float = f[1]
	if length < 0.3: return
	var dir: Vector3 = f[2]
	var side: Vector3 = f[3]
	var up: Vector3 = f[4]
	var hw := DECK*0.5
	b.walk_box(Transform3D(basis,(a+z)*0.5-up*DECK_THICK*0.5),Vector3(hw,DECK_THICK*0.5,length*0.5))
	# The paving, slab by slab along (each a little off its neighbour).
	var at := 0.0
	while at < length-0.05:
		var l := minf(b.rng.randf_range(SLAB.x,SLAB.y),length-at)
		var mid := a+dir*(at+l*0.5)-up*(DECK_THICK*0.5+b.rng.randf_range(0.0,0.03))
		b.block(Stone.box(Transform3D(basis,mid),Vector3(hw-0.02,DECK_THICK*0.5,l*0.5-0.025),0.07),false,null,chips)
		at += l
	# The curbs.
	for s: float in [-1.0,1.0]:
		var c := 0.0
		while c < length-0.2:
			var l := minf(b.rng.randf_range(CURB_RUN.x,CURB_RUN.y),length-c)
			if b.rng.randf() >= CURB_GONE:
				var mid := a+dir*(c+l*0.5)+side*s*(hw-CURB.x*0.5)+up*CURB.y*0.5
				b.block(Stone.box(Transform3D(basis,mid),Vector3(CURB.x*0.5,CURB.y*0.5,l*0.5-0.03),0.05),false,null,1.2)
			c += l
		var e := 0.4 if length > 1.6 else 0.0
		b.runes(a+dir*e+side*s*hw-up*(DECK_THICK*0.55),z-dir*e+side*s*hw-up*(DECK_THICK*0.55),up,side*s,0.45)
	# Broken ends: ragged teeth a little under the top.
	for end: Array in [[cut_a,a,dir],[cut_z,z,-dir]]:
		if not bool(end[0]): continue
		var p: Vector3 = end[1]
		var inward: Vector3 = end[2]
		for k in range(b.rng.randi_range(2,4)):
			var w := b.rng.randf_range(0.3,0.7)
			var at2 := p+side*b.rng.randf_range(-hw+w,hw-w)-inward*b.rng.randf_range(0.0,0.35)-up*b.rng.randf_range(0.2,0.6)
			var turn := Basis(up,b.rng.randf_range(-0.4,0.4))*basis
			b.block(Stone.box(Transform3D(turn,at2),Vector3(w,b.rng.randf_range(0.2,0.4),b.rng.randf_range(0.2,0.45)),0.05),false,null,2.0)

## A joint's pier at `top` (the deck's top there), the way `dir` along:
## a cap (flush with the deck, collided), corbels, a battered shaft.
static func joint_pier(b: CityKit.Piece, top: Vector3, dir: Vector3, roots: Array) -> void:
	var flat := Vector3(dir.x,0.0,dir.z).normalized()
	var turn := Basis(Vector3.UP,atan2(flat.x,flat.z))
	var hw := DECK*0.5
	b.block(Stone.box(Transform3D(turn,top-Vector3.UP*DECK_THICK*0.5),Vector3(hw+0.12,DECK_THICK*0.5,CAP*0.5),0.08),true,null,0.8)
	var y := top.y-DECK_THICK
	for c in range(2):
		var h := Vector3(hw*(0.95-0.15*c),0.35,CAP*0.5+0.35-0.2*c)
		b.block(Stone.box(Transform3D(turn,Vector3(top.x,y-h.y,top.z)),h,0.06),false,null,0.6)
		y -= h.y*2.0
	var down := b.rng.randf_range(PIER_DOWN.x,PIER_DOWN.y)
	var r := hw*PIER_IN
	b.block(Stone.drum(Transform3D(turn,Vector3(top.x,y-down,top.z)),4,r*1.12,r,down,0.1,PI/4.0),true,null,0.5)
	for side: float in [-1.0,1.0]:
		var face := Vector3(top.x,0.0,top.z)+turn.z*side*(r*0.72+0.02)
		var across := turn.x*r*0.6
		b.runes(Vector3(face.x,y-2.4,face.z)-across*side,Vector3(face.x,y-2.4,face.z)+across*side,Vector3.UP,turn.z*side,1.1)
	for k in range(b.rng.randi_range(1,3)):
		roots.append(Vector4(top.x+b.rng.randf_range(-r,r),y-b.rng.randf_range(0.0,1.5),top.z+b.rng.randf_range(-r,r),b.rng.randf_range(2.0,8.0)))

## A span of the plan (city_ways.gd `_whole`/`_broken`: {a, b, state, ...})
## between its joints; `lip_a`/`lip_z` whether its ends are the places'
## lips (no pier, the deck run a little onto the rim).
static func span(b: CityKit.Piece, s: Dictionary, lip_a: bool, lip_z: bool, roots: Array) -> void:
	var a: Vector3 = s.a
	var z: Vector3 = s.b
	var f := _frame(a,z)
	var dir: Vector3 = f[2]
	var flat := Vector3(dir.x,0.0,dir.z).normalized()
	var on_a := a-flat*(0.4 if lip_a else 0.0)
	var on_z := z+flat*(0.4 if lip_z else 0.0)
	match str(s.state):
		"whole":
			deck(b,on_a,on_z)
			var length := a.distance_to(z)
			var n := int(floor(length/PIER_EVERY))
			for k in range(1,n+1): joint_pier(b,a.lerp(z,float(k)/(n+1)),dir,roots)
		"gone":
			var sa := float(s.stub_a)
			var sb := float(s.stub_b)
			deck(b,on_a,a+flat*sa,0.9,false,true)
			deck(b,z-flat*sb,on_z,0.9,true,false)
			# The fallen deck, lodged far down against a pier, tilted.
			var gap := float(s.gap)
			var mid := (a+z)*0.5+Vector3.DOWN*b.rng.randf_range(12.0,20.0)+flat*b.rng.randf_range(-0.3,0.3)*gap
			var tilt := Basis(Vector3.UP.cross(flat).normalized(),b.rng.randf_range(0.2,0.5)*(1.0 if b.rng.randf() < 0.5 else -1.0))
			var fb := tilt*Basis(Vector3.UP,atan2(flat.x,flat.z)+b.rng.randf_range(-0.4,0.4))
			b.block(Stone.box(Transform3D(fb,mid),Vector3(DECK*0.45,DECK_THICK*0.5,gap*0.4),0.08),false,null,2.5)
			b.block(Stone.box(Transform3D(fb.rotated(Vector3.UP,0.7),mid+Vector3.DOWN*2.0+flat*0.8),Vector3(0.6,0.4,0.5),0.06),false,null,2.0)
		"sagged":
			var m := (a+z)*0.5+Vector3.DOWN*float(s.sag)
			deck(b,on_a,m-(m-a).normalized()*0.04,0.8,false,true)
			deck(b,m+(z-m).normalized()*0.04,on_z,0.8,true,false)
			# The crack: one clean box under the V so his feet never find it.
			var cf := _frame(m-flat*0.5,m+flat*0.5)
			b.walk_box(Transform3D(cf[0],m-Vector3.UP*(DECK_THICK*0.5+0.02)),Vector3(DECK*0.5,DECK_THICK*0.5,0.5))
			# A wedge of fallen fill in the crack.
			b.block(Stone.box(Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU),m-Vector3.UP*0.35),Vector3(0.45,0.3,0.4),0.05),false,null,2.0)
		"slumped":
			var dn := float(s.drop_near)
			var df := float(s.drop_far)
			var a2 := a+flat*CAP*0.5+Vector3.DOWN*dn
			var z2 := z-flat*CAP*0.5+Vector3.DOWN*df
			deck(b,a2,z2,1.0,true,true)
			# The slumped deck's own broken piers under it, shorter.
			var mid := (a2+z2)*0.5
			var down := b.rng.randf_range(PIER_DOWN.x,PIER_DOWN.y)
			b.block(Stone.drum(Transform3D(Basis.IDENTITY,mid-Vector3.UP*(DECK_THICK+down)),4,DECK*0.35,DECK*0.3,down-0.05,0.1,PI/4.0),true,null,1.2)
	# The joint's pier at its near end (none at a place's lip; the next
	# span lays the far one).
	if not lip_a: joint_pier(b,a,dir,roots)

## Every span of an edge in order, the joints' piers once.
static func causeway(b: CityKit.Piece, spans: Array, roots: Array) -> void:
	for i in range(spans.size()):
		var s: Dictionary = spans[i]
		var last := i == spans.size()-1
		span(b,s,i == 0,last,roots)

# --- Drums -----------------------------------------------------------------------------

## A staggered pier: its top's middle `top`, `d` across, turned `yaw`:
## COURSES of drums, each a little off and turned from the one under it, a
## shaft under them into the haze. Collided: the top drum and the shaft,
## clean.
static func drum_pier(b: CityKit.Piece, top: Vector3, d: float, yaw: float, roots: Array) -> void:
	var r := d*0.5
	var courses := b.rng.randi_range(COURSES.x,COURSES.y)
	var y := top.y
	var turn := yaw
	var off := Vector3.ZERO
	var first_h := 0.0
	for k in range(courses):
		var h := b.rng.randf_range(COURSE.x,COURSE.y)
		var rk := r*(1.0 if k == 0 else b.rng.randf_range(0.9,0.98))
		var at := Vector3(top.x,y-h,top.z)+(off if k > 0 else Vector3.ZERO)
		var planes := Stone.drum(Transform3D(Basis.IDENTITY,at),DRUM_SIDES,rk*0.99,rk,h-0.03,0.08 if k == 0 else 0.04,turn)
		if k == 0:
			first_h = h
			b.block(planes,true,null,0.7)
		else:
			b.block(planes,false,null,1.1)
		y -= h
		turn += b.rng.randf_range(-0.25,0.25)
		off = Vector3(b.rng.randf_range(-1.0,1.0),0.0,b.rng.randf_range(-1.0,1.0))*r*COURSE_OFF
	var down := b.rng.randf_range(DRUM_DOWN.x,DRUM_DOWN.y)
	var rs := r*0.86
	b.block(Stone.drum(Transform3D(Basis.IDENTITY,Vector3(top.x,y-down,top.z)),DRUM_SIDES,rs*1.04,rs,down,0.0,turn),true,null,0.6)
	# Collided clean between the top drum and the shaft.
	b.walk_box(Transform3D(Basis.IDENTITY,Vector3(top.x,(top.y-first_h+y)*0.5,top.z)),Vector3(rs*0.9,maxf((top.y-first_h-y)*0.5,0.05),rs*0.9))
	for k in range(b.rng.randi_range(2,4)):
		var a := b.rng.randf()*TAU
		roots.append(Vector4(top.x+cos(a)*r*0.95,top.y-b.rng.randf_range(0.3,2.5),top.z+sin(a)*r*0.95,b.rng.randf_range(1.5,7.0)))

## A step on the slow line: a low hex column `d` across at `top`, its shaft
## down into the haze.
static func step_drum(b: CityKit.Piece, top: Vector3, d: float, yaw: float) -> void:
	var r := d*0.5
	var tall := b.rng.randf_range(0.6,0.9)
	b.block(Stone.drum(Transform3D(Basis.IDENTITY,top-Vector3.UP*tall),6,r,r*0.97,tall,0.06,yaw),true,null,1.0)
	var down := b.rng.randf_range(DRUM_DOWN.x*0.8,DRUM_DOWN.y*0.8)
	b.block(Stone.drum(Transform3D(Basis.IDENTITY,top-Vector3.UP*(tall+down)),6,r*0.88,r*0.85,down-0.02,0.0,yaw+0.2),true,null,1.6)

# --- The chute -------------------------------------------------------------------------

## The spillway of the plan (city_ways.gd `_slide`'s chute): at each sample
## its cross-section (the floor banked by `lean`, a ramp each side `ramp`
## degrees up to its wall's height, a coping curb on top), swept from sample
## to sample. One trimesh collides every walked face; drawn as strips, the
## coping as chipped blocks; hex piers under it, roots off it.
static func chute(b: CityKit.Piece, c: Dictionary, roots: Array) -> void:
	var pts: Array = c.pts
	var heads: Array = c.heads
	var n := pts.size()
	if n < 2: return
	var hw := float(c.floor)*0.5
	var slope := tan(deg_to_rad(float(c.ramp)))
	var secs: Array = []
	for i in range(n):
		var p: Vector3 = pts[i]
		var h: Vector3 = heads[i]
		var right := Vector3(-h.z,0.0,h.x)
		var l := float(c.lean[i])
		var el := p-right*hw+Vector3.UP*(-hw*l)
		var er := p+right*hw+Vector3.UP*(hw*l)
		var wl := maxf(float(c.wall_l[i]),0.02)
		var wr := maxf(float(c.wall_r[i]),0.02)
		var tl := el-right*(wl/slope)+Vector3.UP*wl
		var tr := er+right*(wr/slope)+Vector3.UP*wr
		var bot := minf(el.y,er.y)-CHUTE_THICK
		secs.append({"p":p,"right":right,"el":el,"er":er,"tl":tl,"tr":tr,"cl":tl-right*COPE.x,"cr":tr+right*COPE.x,"bot":bot,"h":h})
	# The walked faces, one trimesh: the floor, both ramps, the copings'
	# inner faces and tops.
	var tris: Array = []
	var add := func(q0: Vector3, q1: Vector3, q2: Vector3, q3: Vector3) -> void:
		tris.append_array([q0,q1,q2,q0,q2,q3])
	for i in range(n-1):
		var s0: Dictionary = secs[i]
		var s1: Dictionary = secs[i+1]
		add.call(s0.el,s1.el,s1.er,s0.er)
		add.call(s0.tl,s1.tl,s1.el,s0.el)
		add.call(s0.er,s1.er,s1.tr,s0.tr)
		var u := Vector3.UP*COPE.y
		add.call(s0.tl+u,s1.tl+u,s1.tl,s0.tl)
		add.call(s0.tr,s1.tr,s1.tr+u,s0.tr+u)
		add.call(s0.cl+u,s1.cl+u,s1.tl+u,s0.tl+u)
		add.call(s0.tr+u,s1.tr+u,s1.cr+u,s0.cr+u)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(PackedVector3Array(tris))
	var holder := CollisionShape3D.new()
	holder.shape = shape
	b.body.add_child(holder)
	# Drawn: the floor and ramps lit from above (their foot under them, so
	# only the ramps' feet darken), the outer faces and soffit.
	for i in range(n-1):
		var s0: Dictionary = secs[i]
		var s1: Dictionary = secs[i+1]
		var lo := minf(float(s0.bot),float(s1.bot))
		var tone := 1.0+0.05*sin(float(i)*1.7)
		b.m.quad(s0.el,s1.el,s1.er,s0.er,Vector3.UP,(s0.p as Vector3).y-1.6,tone)
		b.m.quad(s0.tl,s1.tl,s1.el,s0.el,Vector3.UP+(s0.right as Vector3),(s0.el as Vector3).y-0.6,tone)
		b.m.quad(s0.er,s1.er,s1.tr,s0.tr,Vector3.UP-(s0.right as Vector3),(s0.er as Vector3).y-0.6,tone)
		# Outer faces (under the coping) and the soffit.
		for sd: Array in [[s0.cl,s1.cl,-(s0.right as Vector3)],[s0.cr,s1.cr,s0.right]]:
			var q0: Vector3 = sd[0]
			var q1: Vector3 = sd[1]
			var out: Vector3 = sd[2]
			b.m.quad(q0,q1,Vector3(q1.x,float(s1.bot),q1.z),Vector3(q0.x,float(s0.bot),q0.z),out,lo,0.92)
		var cl0: Vector3 = s0.cl
		var cl1: Vector3 = s1.cl
		var cr0: Vector3 = s0.cr
		var cr1: Vector3 = s1.cr
		b.m.quad(Vector3(cl0.x,s0.bot,cl0.z),Vector3(cl1.x,s1.bot,cl1.z),Vector3(cr1.x,s1.bot,cr1.z),Vector3(cr0.x,s0.bot,cr0.z),Vector3.DOWN,lo-2.0,0.8)
	# The ends' faces.
	for e: Array in [[secs[0],-(secs[0].h as Vector3)],[secs[n-1],secs[n-1].h]]:
		var s: Dictionary = e[0]
		var out: Vector3 = e[1]
		var cl: Vector3 = s.cl
		var cr: Vector3 = s.cr
		b.m.quad(cl,cr,Vector3(cr.x,s.bot,cr.z),Vector3(cl.x,s.bot,cl.z),out,float(s.bot),0.9)
	# The coping: chipped blocks along each wall's top, a few gone.
	for side: String in ["l","r"]:
		var i := 0
		while i < n-1:
			var run := b.rng.randi_range(1,2)
			var j := mini(i+run,n-1)
			var s0: Dictionary = secs[i]
			var s1: Dictionary = secs[j]
			var t0: Vector3 = s0["t"+side]
			var t1: Vector3 = s1["t"+side]
			var o0: Vector3 = s0["c"+side]
			var o1: Vector3 = s1["c"+side]
			if b.rng.randf() > 0.08:
				var mid := (t0+t1+o0+o1)*0.25+Vector3.UP*COPE.y*0.5
				var along := ((t1+o1)-(t0+o0))*0.5
				var len := along.length()
				if len > 0.05:
					var z := along/len
					var x := Vector3.UP.cross(z).normalized()
					var y := z.cross(x).normalized()
					b.block(Stone.box(Transform3D(Basis(x,y,z),mid),Vector3(COPE.x*0.5+0.04,COPE.y*0.5+0.02,len*0.5-0.03),0.05),false,null,1.3)
			i = j
	# Carved frets down the outer faces, a chord every few samples.
	for side: float in [-1.0,1.0]:
		var i := 1
		while i < n-3:
			var j := mini(i+3,n-2)
			var s0: Dictionary = secs[i]
			var s1: Dictionary = secs[j]
			var q0: Vector3 = s0.cl if side < 0.0 else s0.cr
			var q1: Vector3 = s1.cl if side < 0.0 else s1.cr
			var out: Vector3 = (s0.right as Vector3)*side
			var y0 := minf(q0.y,q1.y)-0.75
			if side > 0.0: b.runes(Vector3(q0.x,y0,q0.z),Vector3(q1.x,y0,q1.z),Vector3.UP,out,0.5)
			else: b.runes(Vector3(q1.x,y0,q1.z),Vector3(q0.x,y0,q0.z),Vector3.UP,out,0.5)
			i = j+1
	# Hex piers under it, roots off its soffit.
	var walked := 0.0
	var next := CHUTE_PIER*0.6
	for i in range(1,n-2):
		walked += (pts[i] as Vector3).distance_to(pts[i-1])
		var s: Dictionary = secs[i]
		if b.rng.randf() < 0.3:
			var side := 1.0 if b.rng.randf() < 0.5 else -1.0
			var at: Vector3 = (s.cr if side > 0.0 else s.cl)
			roots.append(Vector4(at.x,float(s.bot)+b.rng.randf_range(0.2,0.8),at.z,b.rng.randf_range(1.5,7.0)))
		if walked < next: continue
		next += CHUTE_PIER*b.rng.randf_range(0.85,1.2)
		var p: Vector3 = s.p
		var top := float(s.bot)
		var r := hw*b.rng.randf_range(0.95,1.15)
		var yaw := atan2((s.h as Vector3).x,(s.h as Vector3).z)
		b.block(Stone.box(Transform3D(Basis(Vector3.UP,yaw),Vector3(p.x,top-0.35,p.z)),Vector3(hw+0.6,0.35,0.9),0.06),true,null,0.6)
		var down := b.rng.randf_range(CHUTE_DOWN.x,CHUTE_DOWN.y)
		b.block(Stone.drum(Transform3D(Basis.IDENTITY,Vector3(p.x,top-0.7-down,p.z)),6,r*1.18,r,down,0.08,yaw),true,null,0.5)
		roots.append(Vector4(p.x+b.rng.randf_range(-r,r),top-b.rng.randf_range(0.7,2.0),p.z+b.rng.randf_range(-r,r),b.rng.randf_range(3.0,9.0)))
