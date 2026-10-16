extends RefCounted
## The serpent's pieces of the underground Olmec city kit:
## kukul_dais, kukul_collar, kukul_ring, kukul_coil and colossus_ashbowl. The rune serpent
## (scripts/rune_serpent.gd) is the city's train and its lamp; these are its
## stops, its harness, the stone it threads and climbs, and the one soft
## floor in the stone city.
##
##   kukul_dais     a waiting dais by a trough the serpent's belly wore: a
##                  shrine house (a tunnel through), a canopy, a calendar
##                  stone, and tick stones across the trough that light one
##                  a second as it comes; you board at a run off the lip
##   kukul_collar   a stone saddle fastened round the serpent's body: walked
##                  (moving ground, PilotMotor `mover`), its rim a handhold,
##                  a lantern cage on its spine (a perch, the ember), and
##                  the shrug that throws a rider off where the line ends
##   kukul_ring     a ring the line threads, its bore the serpent's tube, its
##                  crown courses a ladder of ledges off two stepped
##                  abutments, a perch on its cap
##   kukul_coil     a colossal column with a helical ramp: the line spirals
##                  up beside the ramp, its saddle a step over the ramp's
##                  edge all the way, so riding it is climbing; a cap
##   colossus_ashbowl  a sunk bowl of ash in a court's floor: soft ground
##                  (PilotMotor `soft`): a fall caught, a wade, dust
##
## Every piece is a Node3D with a "Body" (StaticBody3D; the collar is its
## own AnimatableBody3D) and meta: `way` (the serpent's line through it, in
## its own frame: [point, weave, pace, veer] as RuneSerpent.ROUTE), `ports`,
## `triangles`. Runes are the Olmec stone's carved grooves (GiantStone's rune
## surface), each strip its own material, dead stone until the serpent
## comes near (`wake`): a moving string of gold across the city.
##
## Sizes come from the wanderer (RuinKit SET_OFF, STAND at WorldScale's
## size) and from the serpent's own constants (RADIUS times its girth, its
## weave and heave): the bore, the trough and the coil's line are the
## serpent's, never copied metres.
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")

const PIECES := {
	"kukul_dais":"waiting dais by the serpent's trough: tick stones count it in, board at a run",
	"kukul_collar":"stone saddle on the serpent's back: walked, a handhold rim, a lantern cage, the shrug",
	"kukul_ring":"ring the line threads: stepped crown courses off two abutments, a perch on its cap",
	"kukul_coil":"column with a helical ramp the line spirals up beside: riding it is climbing",
	"colossus_ashbowl":"sunk bowl of ash: a fall caught, a wade, dust",
}

## The city kit's cell (RuinKit BAY).
const CELL := RuinKit.BAY
## The crest's height and the flank's half width over the serpent's line, in
## its ring's radius (RuneSerpent._octagon: CREST, SQUASH; the 22.5° corner).
const CREST_SHARE := 0.8304
const FLANK_SHARE := 0.924
const BELLY_SHARE := 0.776
## The saddle stands this far over the dais and the coil's ramp: a step
## down onto it, and its edge a step up off it.
const SADDLE_OVER := 0.3
## A seat row's rise (under the walker's step).
const SEAT := 0.4
## Runes: dead (grooves, a faint warmth) and lit energies; how near the
## serpent wakes them (full within WAKE.x, none past WAKE.y, m); their ease (s).
const RUNE_DEAD := 0.04
const RUNE_LIT := 1.4
const WAKE := Vector2(5.0,16.0)
const WAKE_EASE := 0.6
## Soft ash: the run's share (a wade), the fall it catches (m), the share of
## a landing's flat pace kept, how deep the feet sink (m).
const ASH := {"slow":0.55,"catch":14.0,"keep":0.4,"depth":0.35}

## The wanderer's and the serpent's measures (see `Kit`).
static func set_off() -> float:
	return Kit.set_off()

static func bore(girth: float) -> float:
	return Kit.bore(girth)

static func saddle_top(girth: float) -> float:
	return Kit.saddle_top(girth)

## Wakes `piece`'s rune strips by the serpent's nearness (see `Kit.wake`).
static func wake(piece: Node3D, points: PackedVector3Array, delta: float) -> void:
	Kit.wake(piece,points,delta)

## Piece `id` (PIECES) stood in `parent` at `xform`; `opts` its own (the
## collar's: "serpent", "ring").
static func build(id: String, parent: Node3D, xform: Transform3D, opts := {}) -> Node3D:
	match id:
		"kukul_dais": return dais(parent,xform,opts)
		"kukul_ring": return ring(parent,xform,opts)
		"kukul_coil": return coil(parent,xform,opts)
		"colossus_ashbowl": return ashbowl(parent,xform,opts)
		"kukul_collar":
			var s: Node3D = opts.get("serpent") as Node3D
			if s == null:
				push_error("city serpent: a collar needs opts.serpent")
				return null
			return collar(parent,s,int(opts.get("ring",14)),opts)
	push_error("city serpent: no piece '%s'" % id)
	return null

## The kit's helpers (inner classes reach them as `Kit.x`): the wanderer's
## measures, the serpent's, the stone, runes and collision.
class Kit extends RefCounted:
	static func size() -> float:
		return WorldScale.wanderer

	static func set_off() -> float:
		return RuinKit.SET_OFF*size()

	static func stand() -> float:
		return (RuinKit.STAND+0.12)*size()

	## A flight's rise / a drop under the fall stun (the city kit's COURSE).
	static func course() -> float:
		return 3.0*set_off()

	# --- The serpent's measures -------------------------------------------------------------

	static func radius(girth: float) -> float:
		return RuneSerpent.RADIUS*girth

	## Its crest over its line (m).
	static func crest(girth: float) -> float:
		return radius(girth)*CREST_SHARE

	## The dais's trough: the body's width at its belly and half a metre
	## either side, so a saddle over its middle is a running jump off the lip.
	static func trough_width(girth: float) -> float:
		return radius(girth)*2.0*1.12+1.0

	## A collar's saddle top over the line: the crest and a SET_OFF.
	static func saddle_top(girth: float) -> float:
		return crest(girth)+set_off()

	## The tube it needs where its weave is held (ring, coil): its girth, the
	## weave and heave at their most (RuneSerpent's own WAVE, WEAVE, HEAVE), a
	## margin. About 7 m at girth 1 (the card's KUKUL_BORE).
	static func bore(girth: float) -> float:
		var weave := RuneSerpent.WAVE*tan(RuneSerpent.WEAVE)/TAU
		var heave := RuneSerpent.HEAVE_WAVE*tan(RuneSerpent.HEAVE)/TAU
		return radius(girth)*1.08+weave+heave+0.25

	# --- Shared stone, runes, collision ---------------------------------------------------------

	## A fresh rune material (GiantStone's rune surface, its own energy), dead.
	static func rune_material() -> ShaderMaterial:
		GiantStone.warm()
		var m: ShaderMaterial = GiantStone._runes.duplicate()
		m.set_shader_parameter("energy",RUNE_DEAD)
		return m

	## The rune surface gathered in `m` (its `runes` calls) as a mesh of its own.
	static func rune_mesh(m: GiantStone.Mesher, material: Material) -> ArrayMesh:
		if m.rv.is_empty(): return null
		var out := ArrayMesh.new()
		var ra := []
		ra.resize(Mesh.ARRAY_MAX)
		ra[Mesh.ARRAY_VERTEX] = m.rv
		ra[Mesh.ARRAY_NORMAL] = m.rn
		ra[Mesh.ARRAY_COLOR] = m.rcol
		ra[Mesh.ARRAY_TEX_UV] = m.ruv
		ra[Mesh.ARRAY_TEX_UV2] = m.ruv2
		ra[Mesh.ARRAY_CUSTOM0] = m.rc0
		ra[Mesh.ARRAY_CUSTOM1] = m.rc1
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ra,[],{},
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
		out.surface_set_material(0,material)
		return out

	static func mesh_node(parent: Node3D, mesh: Mesh, node_name: String) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = mesh
		parent.add_child(mi)
		return mi

	## A box shape `size_m` at `place` (its middle, turned as it is).
	static func box_shape(size_m: Vector3, place: Transform3D) -> Array:
		var b := BoxShape3D.new()
		b.size = size_m
		return [b,place]

	static func at(p: Vector3) -> Transform3D:
		return Transform3D(Basis.IDENTITY,p)

	## A StaticBody3D named `node_name` of `shapes` ([Shape3D, Transform3D]).
	static func solid(parent: Node3D, shapes: Array, node_name := "Body") -> StaticBody3D:
		var body := StaticBody3D.new()
		body.name = node_name
		for s: Array in shapes:
			var c := CollisionShape3D.new()
			c.shape = s[0]
			c.transform = s[1]
			body.add_child(c)
		parent.add_child(body)
		return body

	## A box `size_m` in the stone (drawn) and collided: `place` its middle.
	static func block(m: GiantStone.Mesher, shapes: Array, place: Transform3D, size_m: Vector3, bevel := 0.12, tone := 1.0) -> void:
		m.box(place,size_m,bevel,NAN,tone)
		shapes.append(box_shape(size_m,place))

	## A box from `lo` to `hi` (axis-aligned in the piece's frame).
	static func span(m: GiantStone.Mesher, shapes: Array, lo: Vector3, hi: Vector3, bevel := 0.12, tone := 1.0) -> void:
		block(m,shapes,at((lo+hi)*0.5),(hi-lo).abs(),bevel,tone)

	## A strip of runes: its own mesh and material in `piece`, woken by the
	## serpent near `middle` (the piece's frame). Returns the material.
	static func strip(piece: Node3D, rm: GiantStone.Mesher, middle: Vector3, node_name: String) -> ShaderMaterial:
		var mat := rune_material()
		var mesh := rune_mesh(rm,mat)
		if mesh == null: return mat
		mesh_node(piece,mesh,node_name)
		var strips: Array = piece.get_meta("strips",[])
		strips.append({"mat":mat,"at":middle,"lit":0.0,"hold":0.0})
		piece.set_meta("strips",strips)
		return mat

	## Wakes `piece`'s rune strips by the serpent's nearness: `points` the
	## serpent's ring places (world, every few), over `delta`. A strip's `hold`
	## (0 to 1, set by the piece: the tick stones) lights it whatever.
	static func wake(piece: Node3D, points: PackedVector3Array, delta: float) -> void:
		var strips: Array = piece.get_meta("strips",[])
		var xf := piece.global_transform
		for s: Dictionary in strips:
			var p: Vector3 = xf*(s.at as Vector3)
			var near := INF
			for q in points: near = minf(near,p.distance_squared_to(q))
			var want := 1.0-smoothstep(WAKE.x,WAKE.y,sqrt(near))
			want = maxf(want,float(s.hold))
			var lit := move_toward(float(s.lit),want,delta/WAKE_EASE)
			if absf(lit-float(s.lit)) > 0.0005 or s.lit == 0.0:
				s.lit = lit
				(s.mat as ShaderMaterial).set_shader_parameter("energy",lerpf(RUNE_DEAD,RUNE_LIT,lit*lit*(3.0-2.0*lit)))

	## The piece's stone mesh from `m` (GiantStone's materials), its triangles
	## counted into the meta.
	static func stone_node(piece: Node3D, m: GiantStone.Mesher, node_name := "Mesh") -> MeshInstance3D:
		var mi := mesh_node(piece,GiantStone.mesh_of(m),node_name)
		piece.set_meta("triangles",int(piece.get_meta("triangles",0))+m.triangles())
		return mi

	## Ground cover (the underground's: dust, grass, moss) on a walked top.
	static func cover(piece: Node3D, area: Rect2, y: float, seed_value: int, tufts := 1.0) -> void:
		GroundCover.cover(piece,area,"",y+0.002,seed_value,{"tufts":tufts,"under":tufts,"fade":0.25})

	## A ring of `n` boxes from radius `r_in` to `r_out`, `y0` to `y1`, round
	## the piece's y axis at `centre` (an annulus as boxes, for collision and
	## the stone); `from`/`to` the angles it spans (radians, x toward -z).
	static func ring_boxes(m: GiantStone.Mesher, shapes: Array, centre: Vector3, r_in: float, r_out: float, y0: float, y1: float, n: int, from := 0.0, to := TAU, tone := 1.0) -> void:
		var step := (to-from)/n
		for k in n:
			var a := from+step*(k+0.5)
			var mid := (r_in+r_out)*0.5
			var chord := 2.0*r_out*sin(step*0.5)+0.04
			var place := Transform3D(Basis(Vector3.UP,a+PI*0.5),centre+Vector3(cos(a)*mid,(y0+y1)*0.5,-sin(a)*mid))
			var sz := Vector3(chord,y1-y0,r_out-r_in)
			m.box(place,sz,0.06,NAN,tone)
			shapes.append(box_shape(sz,place))



# --- kukul_dais -----------------------------------------------------------------------------

## The waiting dais in `parent` at `xform`: its middle on the ground it is
## approached from (y 0), the line along its +x side running toward -z.
## opts: "girth" (the serpent's, 1), "seed", "trough_len" (its own trough's
## length, the dais's), "cover" (true).
static func dais(parent: Node3D, xform: Transform3D, opts := {}) -> Dais:
	var d := Dais.new()
	d.name = str(opts.get("name","KukulDais"))
	d.transform = xform
	parent.add_child(d)
	d.build(opts)
	return d

class Dais extends Node3D:
	## Its side (3 CELL), its top (a SET_OFF), the trough's width and depth
	## under the top (a course), the line's x and height.
	var side := CELL*3.0
	var top := 1.6
	var trough_w := 7.0
	var trough_floor := -3.2
	var line_x := 0.0
	var line_y := 0.0
	var girth := 1.0
	## The tick stones' strips, south (+z, the way it comes from) first.
	var ticks: Array = []
	var lit_ticks := 0
	## Seconds a tick stone stands for.
	const TICK := 1.0
	const TICKS := 8

	func build(opts: Dictionary) -> void:
		girth = float(opts.get("girth",1.0))
		var so: float = Kit.set_off()
		top = so
		side = CELL*3.0
		var h := side*0.5
		# The trough: the body's width at its belly and a stand either side.
		trough_w = Kit.trough_width(girth)
		trough_floor = top-Kit.course()
		line_x = h+trough_w*0.5
		line_y = top+SADDLE_OVER-Kit.saddle_top(girth)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(opts.get("seed",11))
		var m := GiantStone.mesher()
		var shapes: Array = []
		# The paving: nine slabs a CELL each on the platform.
		for i in 3:
			for j in 3:
				var c := Vector3(-h+CELL*(i+0.5),top*0.5,-h+CELL*(j+0.5))
				m.box(Kit.at(c+Vector3(0.0,-rng.randf_range(0.0,0.03),0.0)),Vector3(CELL-0.06,top,CELL-0.06),0.08,0.0,rng.randf_range(0.86,1.05))
		shapes.append(Kit.box_shape(Vector3(side,top,side),Kit.at(Vector3(0.0,top*0.5,0.0))))
		# Its face into the trough, down to the trough's floor.
		Kit.span(m,shapes,Vector3(h-0.6,trough_floor,-h),Vector3(h,0.0,h),0.06,0.9)
		# The trough's floor and its far bank (up to the approach's ground).
		var floor_lo := trough_floor-2.0
		Kit.span(m,shapes,Vector3(h,floor_lo,-h),Vector3(h+trough_w,trough_floor,h),0.04,0.75)
		Kit.span(m,shapes,Vector3(h+trough_w,floor_lo,-h),Vector3(h+trough_w+2.4,0.0,h),0.06,0.9)
		# The approach steps up the west face (four 0.4 m risers, the
		# walker's), into the shrine's back mouth.
		var risers := 4
		for k in range(1,risers):
			var y := top*float(k)/risers
			Kit.span(m,shapes,Vector3(-h-0.8*(risers-k),0.0,-3.0),Vector3(-h,y,3.0),0.05)
		# The canopy: four posts, a lintel frame (a grab), a frieze of runes.
		var post := 0.9
		var post_at := h-1.1
		var canopy := top+4.0*so
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				var p := Vector3(sx*post_at,0.0,sz*post_at)
				Kit.span(m,shapes,Vector3(p.x-post*0.5,top,p.z-post*0.5),Vector3(p.x+post*0.5,canopy,p.z+post*0.5),0.1)
				# A plinth course at its foot.
				m.box(Kit.at(Vector3(p.x,top+0.2,p.z)),Vector3(post+0.3,0.4,post+0.3),0.06)
		var lint := 0.8
		for sz: float in [-1.0,1.0]:
			Kit.span(m,shapes,Vector3(-post_at-post*0.5,canopy,sz*post_at-post*0.5),Vector3(post_at+post*0.5,canopy+lint,sz*post_at+post*0.5),0.08)
		for sx: float in [-1.0,1.0]:
			Kit.span(m,shapes,Vector3(sx*post_at-post*0.5,canopy,-post_at+post*0.5),Vector3(sx*post_at+post*0.5,canopy+lint,post_at-post*0.5),0.08)
		# The feathered frieze: stone feathers along the lintels' outer tops.
		for k in 18:
			var u := -post_at+2.0*post_at*float(k)/17.0
			for sz: float in [-1.0,1.0]:
				m.box(Transform3D(Basis(Vector3.RIGHT,sz*0.35),Vector3(u,canopy+lint+0.22,sz*(post_at+0.15))),Vector3(0.5,0.5,0.14),0.04,NAN,0.95)
		var fr := GiantStone.mesher()
		for sz: float in [-1.0,1.0]:
			var face := sz*(post_at+post*0.5+0.01)
			var a := Vector3(-post_at,canopy+0.02,face)
			var b := Vector3(post_at,canopy+0.02,face)
			if sz < 0.0: fr.runes(b,a,Vector3.UP,Vector3(0.0,0.0,sz),3.0)
			else: fr.runes(a,b,Vector3.UP,Vector3(0.0,0.0,sz),3.0)
		Kit.strip(self,fr,Vector3(0.0,canopy,0.0),"Frieze")
		# The shrine house at the west: a tunnel through, a low door each end.
		var sh := Vector3(-h+2.6,top,0.0)
		var half := 2.2
		var wall := 0.5
		var room := 2.4
		var door := Vector2(1.4,1.7)
		for sz: float in [-1.0,1.0]:
			Kit.span(m,shapes,Vector3(sh.x-half,top,sz*half-wall*0.5),Vector3(sh.x+half,top+room,sz*half+wall*0.5),0.06)
		for sx: float in [-1.0,1.0]:
			var x0 := sh.x+sx*half-wall*0.5
			var x1 := sh.x+sx*half+wall*0.5
			Kit.span(m,shapes,Vector3(x0,top,-half),Vector3(x1,top+room,-door.x*0.5),0.06)
			Kit.span(m,shapes,Vector3(x0,top,door.x*0.5),Vector3(x1,top+room,half),0.06)
			Kit.span(m,shapes,Vector3(x0,top+door.y,-door.x*0.5),Vector3(x1,top+room,door.x*0.5),0.04)
		Kit.span(m,shapes,Vector3(sh.x-half-0.3,top+room,-half-0.3),Vector3(sh.x+half+0.3,top+room+0.6,half+0.3),0.12)
		# Its roof's stepped crest.
		m.box(Kit.at(Vector3(sh.x,top+room+0.85,0.0)),Vector3(half*1.4,0.5,half*1.4),0.1)
		# The calendar stone, flush in the paving: a kerb ring and its day
		# signs in a ring (runes on the floor).
		var cal := Vector3(1.6,top,0.0)
		Kit.ring_boxes(m,[],cal,2.0,2.3,top-0.02,top+0.08,16,0.0,TAU,0.8)
		var cr := GiantStone.mesher()
		var signs := 13
		for k in signs:
			var a0 := TAU*float(k)/signs
			var a1 := TAU*(float(k)+0.8)/signs
			var r := 1.25
			var p0 := cal+Vector3(cos(a0)*r,0.012,-sin(a0)*r)
			var p1 := cal+Vector3(cos(a1)*r,0.012,-sin(a1)*r)
			var inward := (cal-(p0+p1)*0.5)
			inward.y = 0.0
			cr.runes(p0,p1,inward.normalized(),Vector3.UP,float(k))
		Kit.strip(self,cr,cal,"Calendar")
		# The trough's wall runes: its glow as the serpent goes by.
		var tw := GiantStone.mesher()
		tw.runes(Vector3(h+0.01,trough_floor+1.4,h-0.4),Vector3(h+0.01,trough_floor+1.4,-h+0.4),Vector3.UP,Vector3.RIGHT,5.0)
		Kit.strip(self,tw,Vector3(h,trough_floor+1.8,0.0),"TroughRunes")
		# The tick stones on the far bank, facing the dais: day-sign stelae,
		# south first.
		var bank := h+trough_w+0.9
		for i in TICKS:
			var z := (h-0.9)-(side-1.8)*float(i)/float(TICKS-1)
			var tall := 1.5+0.12*float(i%3)
			m.box(Kit.at(Vector3(bank,tall*0.5,z)),Vector3(0.6,tall,0.75),0.08,0.0,0.95)
			shapes.append(Kit.box_shape(Vector3(0.6,tall,0.75),Kit.at(Vector3(bank,tall*0.5,z))))
			var tr := GiantStone.mesher()
			tr.runes(Vector3(bank-0.31,0.45,z-0.3),Vector3(bank-0.31,0.45,z+0.3),Vector3.UP,Vector3.LEFT,20.0+i)
			ticks.append(Kit.strip(self,tr,Vector3(bank,1.0,z),"Tick%d" % i))
		Kit.stone_node(self,m)
		Kit.solid(self,shapes)
		if bool(opts.get("cover",true)): Kit.cover(self,Rect2(-h,-h,side,side),top,int(opts.get("seed",11)))
		var way: Array = []
		for z: float in [side*1.5,side*0.5,0.0,-side*0.5,-side*1.5]:
			way.append([Vector3(line_x,line_y,z),0.0,1.0,0.0])
		set_meta("way",way)
		set_meta("ports",{"top":Vector3(0.0,top,0.0),"lip":Vector3(h,top,0.0),"approach":Vector3(-h-3.2,0.0,0.0),"line":Vector3(line_x,line_y,0.0)})

	## The countdown: `ahead` the seconds before its head is at the dais's
	## middle (INF far off), `passing` while its body goes by. A tick stone
	## a second from TICKS out, south first; all held lit while it passes.
	func update(ahead: float, passing: bool) -> void:
		var strips: Array = get_meta("strips",[])
		lit_ticks = TICKS if passing else clampi(TICKS-int(floor(ahead/TICK)),0,TICKS)
		for i in TICKS:
			for s: Dictionary in strips:
				if s.mat == ticks[i]: s.hold = 1.0 if i < lit_ticks else 0.0

# --- kukul_collar ----------------------------------------------------------------------------

## A collar on `serpent` at its ring `k` (RuneSerpent stations), in
## `parent` (it follows the ring in the world each `follow`). opts:
## "lamp" (true: its own OmniLight), "name".
static func collar(parent: Node3D, serpent: Node3D, k: int, opts := {}) -> Collar:
	var c := Collar.new()
	c.name = str(opts.get("name","KukulCollar"))
	c.serpent = serpent
	c.k = k
	parent.add_child(c)
	c.build(opts)
	c.follow(0.0)
	return c

class Collar extends AnimatableBody3D:
	var serpent: Node3D
	var k := 14
	## Over the line in its ring's frame: the crest, the saddle's top; the
	## saddle's width (across) and length (along).
	var crest := 1.66
	var saddle := 3.26
	var saddle_w := 2.6
	var saddle_l := 5.0
	var cage_h := 1.9
	## The shrug: its seconds and roll (radians), and where it is.
	const SHRUG_TIME := 0.7
	const SHRUG_ROLL := 0.45
	var shrug_t := -1.0
	var shrug_side := 1.0
	var shrugs := 0
	var ember: MeshInstance3D
	var lamp: OmniLight3D

	func build(opts: Dictionary) -> void:
		sync_to_physics = false
		collision_layer = 1
		collision_mask = 0
		PhysicsGround.mark_moving(self)
		var radii: PackedFloat32Array = serpent.radii()
		var r: float = radii[clampi(k,0,radii.size()-1)]
		crest = r*CREST_SHARE
		saddle = crest+Kit.set_off()
		var m := GiantStone.mesher()
		var shapes: Array = []
		var lo := crest-0.6
		# The saddle: a slab over the crest, its rim the handhold.
		Kit.span(m,shapes,Vector3(-saddle_w*0.5,lo,-saddle_l*0.5),Vector3(saddle_w*0.5,saddle,saddle_l*0.5),0.1)
		# Its rim: a lip course round the top, a hand's width proud.
		for sx: float in [-1.0,1.0]:
			m.box(Kit.at(Vector3(sx*(saddle_w*0.5+0.06),saddle-0.18,0.0)),Vector3(0.14,0.3,saddle_l-0.2),0.04,NAN,1.08)
		# Carved handles on its flanks (a pump's catch from the back).
		for sx: float in [-1.0,1.0]:
			for z: float in [-1.2,1.2]:
				m.box(Kit.at(Vector3(sx*(saddle_w*0.5+0.2),saddle-0.75,z)),Vector3(0.18,0.5,0.18),0.04)
				m.box(Kit.at(Vector3(sx*(saddle_w*0.5+0.2),saddle-0.5,z)),Vector3(0.18,0.14,0.7),0.03)
		# The collar band round the body under the saddle: eight blocks.
		var band_r := r*1.1
		for j in 8:
			var a := TAU*(j+0.5)/8.0
			var p := Vector3(cos(a)*band_r,sin(a)*band_r*0.9,0.0)
			var place := Transform3D(Basis(Vector3.BACK,a-PI*0.5),p)
			m.box(place,Vector3(band_r*0.78,0.4,1.2),0.06,NAN,0.92)
		# The lantern cage at the saddle's tail end, low enough that the chase
		# camera clears it behind a rider on the saddle's fore half: four
		# posts, two rings of bars (ledges), a cap (a perch); the ember inside.
		var cz := -saddle_l*0.5+0.8
		var cw := 1.4
		var base := saddle
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,1.0]:
				m.box(Kit.at(Vector3(sx*(cw*0.5-0.08),base+cage_h*0.5,cz+sz*(cw*0.5-0.08))),Vector3(0.16,cage_h,0.16),0.03)
		for ring_y: float in [base+0.12,base+Kit.set_off(),base+cage_h-0.1]:
			for sz: float in [-1.0,1.0]:
				m.box(Kit.at(Vector3(0.0,ring_y,cz+sz*(cw*0.5-0.08))),Vector3(cw,0.14,0.14),0.02)
			for sx: float in [-1.0,1.0]:
				m.box(Kit.at(Vector3(sx*(cw*0.5-0.08),ring_y,cz)),Vector3(0.14,0.14,cw),0.02)
		# The lattice's diagonals, two a face.
		for f in 4:
			var ang := TAU*f/4.0
			var out := Vector3(sin(ang),0.0,cos(ang))*(cw*0.5-0.08)
			for t: float in [-1.0,1.0]:
				var place := Transform3D(Basis(out.normalized(),t*0.62),Vector3(0.0,base+cage_h*0.5,cz)+out)
				m.box(place,Vector3(0.1,cage_h*0.92,0.1),0.02)
		Kit.span(m,[],Vector3(-cw*0.5-0.1,base+cage_h,cz-cw*0.5-0.1),Vector3(cw*0.5+0.1,base+cage_h+0.25,cz+cw*0.5+0.1),0.06)
		shapes.append(Kit.box_shape(Vector3(cw,cage_h+0.25,cw),Kit.at(Vector3(0.0,base+(cage_h+0.25)*0.5,cz))))
		Kit.stone_node(self,m)
		for s: Array in shapes:
			var c := CollisionShape3D.new()
			c.shape = s[0]
			c.transform = s[1]
			add_child(c)
		# The ember: a cut-jade lantern's hot amber.
		ember = MeshInstance3D.new()
		ember.name = "Ember"
		var ball := SphereMesh.new()
		ball.radius = 0.32
		ball.height = 0.56
		ember.mesh = ball
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.albedo_color = Color(1.0,0.62,0.26)
		hot.emission_enabled = true
		hot.emission = Color(1.0,0.55,0.2)
		hot.emission_energy_multiplier = 3.0
		ember.material_override = hot
		ember.position = Vector3(0.0,base+cage_h*0.45,cz)
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ember)
		if bool(opts.get("lamp",true)):
			lamp = OmniLight3D.new()
			lamp.name = "Lamp"
			lamp.light_color = Color(1.0,0.62,0.3)
			lamp.light_energy = 3.2
			lamp.omni_range = 16.0
			lamp.shadow_enabled = false
			lamp.position = ember.position
			add_child(lamp)
		set_meta("ports",{"saddle":Vector3(0.0,saddle,saddle_l*0.25),"cage_top":Vector3(0.0,base+cage_h+0.25,cz)})

	## Onto its ring as posed now (its breath's scale taken out), rolled by
	## the shrug.
	func follow(delta: float) -> void:
		if serpent == null: return
		var f: Transform3D = serpent.ring_frame(k)
		var b := f.basis.orthonormalized()
		var roll := 0.0
		if shrug_t >= 0.0:
			shrug_t += delta
			if shrug_t >= SHRUG_TIME: shrug_t = -1.0
			else: roll = shrug_side*SHRUG_ROLL*sin(PI*shrug_t/SHRUG_TIME)
		if roll != 0.0: b = b*Basis(Vector3.BACK,roll)
		global_transform = serpent.global_transform*Transform3D(b,f.origin)

	## The shrug: a roll of the collar to `side` (+1 its right), and back.
	func shrug(side := 1.0) -> void:
		shrug_side = side
		shrug_t = 0.0
		shrugs += 1

	## Whether `node` (a motor's platform) is part of this collar.
	func carries(node: Node) -> bool:
		return node != null and (node == self or node.get_parent() == self)

	## The saddle's top middle in the world (where a rider is set).
	func saddle_point(along := 1.0) -> Vector3:
		return global_transform*Vector3(0.0,saddle,along)

	func forward() -> Vector3:
		return global_transform.basis.z.normalized()

# --- kukul_ring ------------------------------------------------------------------------------

## The threading ring in `parent` at `xform`: its middle the bore's (the
## line's) middle, its axis along z (the line runs toward -z through it).
## opts: "girth" (1), "ground" (the ground's y under it, its frame;
## default its foot), "seed".
static func ring(parent: Node3D, xform: Transform3D, opts := {}) -> Ring:
	var r := Ring.new()
	r.name = str(opts.get("name","KukulRing"))
	r.transform = xform
	parent.add_child(r)
	r.build(opts)
	return r

class Ring extends Node3D:
	var bore := 7.0
	var outer := 8.4
	var deep := 2.2
	var ground := -8.4
	var crown := 9.2
	var abut_top := 4.4
	const VOUSSOIRS := 8
	const FACETS := 4

	## The rim's x at height y (the ring's outside), 0 past its top.
	func rim_x(y: float) -> float:
		return sqrt(maxf(outer*outer-y*y,0.0))

	func build(opts: Dictionary) -> void:
		var girth := float(opts.get("girth",1.0))
		var so: float = Kit.set_off()
		bore = Kit.bore(girth)
		outer = bore+1.4
		ground = float(opts.get("ground",-outer))
		var m := GiantStone.mesher()
		var shapes: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = int(opts.get("seed",21))
		# The voussoirs: eight coils of scales, each four facets, a joint's
		# hairline between them; the outer face banded (scale rings).
		var n := VOUSSOIRS*FACETS
		var joint := 0.012
		for v in VOUSSOIRS:
			var rm := GiantStone.mesher()
			var tone := rng.randf_range(0.9,1.04)
			for f in FACETS:
				var i := v*FACETS+f
				var a0 := TAU*float(i)/n+PI*0.5+(joint if f == 0 else 0.0)
				var a1 := TAU*float(i+1)/n+PI*0.5-(joint if f == FACETS-1 else 0.0)
				var o := outer+(0.12 if f%2 == 0 else 0.0)
				var d0 := Vector3(cos(a0),sin(a0),0.0)
				var d1 := Vector3(cos(a1),sin(a1),0.0)
				var zb := deep*0.5
				var pts_in := [d0*bore,d1*bore]
				var pts_out := [d0*o,d1*o]
				m._centre = (d0+d1)*0.5*(bore+o)*0.5
				m._foot = -INF
				m._tone = tone
				var c := m._centre
				# Inner (bore), outer, front, back faces.
				m._poly(Transform3D.IDENTITY,[pts_in[0]+Vector3(0,0,zb),pts_in[1]+Vector3(0,0,zb),pts_in[1]-Vector3(0,0,zb),pts_in[0]-Vector3(0,0,zb)],c*1.6)
				m._poly(Transform3D.IDENTITY,[pts_out[0]+Vector3(0,0,zb),pts_out[1]+Vector3(0,0,zb),pts_out[1]-Vector3(0,0,zb),pts_out[0]-Vector3(0,0,zb)],c*0.2)
				for sz: float in [-1.0,1.0]:
					m._poly(Transform3D.IDENTITY,[pts_in[0]+Vector3(0,0,sz*zb),pts_in[1]+Vector3(0,0,sz*zb),pts_out[1]+Vector3(0,0,sz*zb),pts_out[0]+Vector3(0,0,sz*zb)],c-Vector3(0,0,sz))
				if f == 0 or f == FACETS-1:
					var d := d0 if f == 0 else d1
					var t := Vector3(-d.y,d.x,0.0)*(1.0 if f == FACETS-1 else -1.0)
					m._poly(Transform3D.IDENTITY,[d*bore+Vector3(0,0,zb),d*o+Vector3(0,0,zb),d*o-Vector3(0,0,zb),d*bore-Vector3(0,0,zb)],d*(bore+o)*0.5-t)
				# Collision: a box per facet over the annulus.
				var mid := (d0+d1).normalized()
				var chord := 2.0*outer*sin(TAU/n*0.5)+0.05
				var place := Transform3D(Basis(Vector3(-mid.y,mid.x,0.0),mid,Vector3.BACK),mid*(bore+outer)*0.5)
				shapes.append(Kit.box_shape(Vector3(chord,outer-bore,deep),place))
				# The bore's runes: a band round its middle.
				var b0 := d0*(bore-0.01)
				var b1 := d1*(bore-0.01)
				rm.runes(b1-Vector3(0,0,0.4),b0-Vector3(0,0,0.4),Vector3.BACK,-mid,float(i))
			var vm := TAU*(v+0.5)/VOUSSOIRS+PI*0.5
			Kit.strip(self,rm,Vector3(cos(vm),sin(vm),0.0)*bore,"Runes%d" % v)
		# The crown courses: from each abutment's top, steps a SET_OFF up
		# that follow the rim, and the cap over the top (its perch).
		var levels: Array[float] = []
		var y := ground
		while y < outer:
			levels.append(y)
			y += so
		# The abutment's top: the first level from which each step up has a
		# tread a stand and more.
		abut_top = levels[levels.size()-1]
		for li in range(levels.size()-1):
			var l := levels[li]
			if l < 0.0: continue
			var ok := true
			var yy := l
			while yy+so < outer:
				if rim_x(yy)-rim_x(yy+so) < Kit.stand()+0.3: ok = false
				yy += so
			if ok:
				abut_top = l
				break
		var step_tops: Array[float] = []
		y = abut_top+so
		while y < outer:
			step_tops.append(y)
			y += so
		crown = y
		for sx: float in [-1.0,1.0]:
			var lo_y := abut_top
			for t in step_tops:
				var x_out := rim_x(t-so)
				var x_in := rim_x(t)
				var lo := Vector3(minf(sx*x_in,sx*x_out),lo_y-0.3,-deep*0.5)
				var hi := Vector3(maxf(sx*x_in,sx*x_out),t,deep*0.5)
				Kit.span(m,shapes,lo,hi,0.08,0.96)
				lo_y = t-so
			# The abutment: steps a SET_OFF a course from the ground out to
			# the rim at its top.
			var courses := int(roundf((abut_top-ground)/so))
			var x0 := rim_x(abut_top)-0.3
			for j in courses:
				var t := abut_top-so*j
				var x_a := x0+1.0*j
				var x_b := x0+1.0*(j+1)
				Kit.span(m,shapes,Vector3(minf(sx*x_a,sx*x_b),ground,-deep*0.5-0.6),Vector3(maxf(sx*x_a,sx*x_b),t,deep*0.5+0.6),0.1,0.9)
		# The cap: over the top, from the last step's inner edge; its head (a
		# serpent biting its tail) on the front.
		var cx := rim_x(crown-so)
		Kit.span(m,shapes,Vector3(-cx,outer-1.2,-deep*0.5-0.2),Vector3(cx,crown,deep*0.5+0.2),0.12,1.04)
		m.box(Kit.at(Vector3(0.0,crown+0.35,deep*0.5+0.1)),Vector3(2.2,0.7,0.9),0.12)
		m.box(Kit.at(Vector3(0.0,crown-0.3,deep*0.5+0.75)),Vector3(1.8,0.9,1.1),0.14)
		for sx: float in [-1.0,1.0]:
			m.box(Kit.at(Vector3(sx*0.62,crown+0.05,deep*0.5+0.95)),Vector3(0.36,0.3,0.5),0.06,NAN,0.7)
			m.box(Kit.at(Vector3(sx*0.5,crown-0.85,deep*0.5+1.15)),Vector3(0.16,0.5,0.16),0.03,NAN,1.15)
		Kit.stone_node(self,m)
		Kit.solid(self,shapes)
		set_meta("way",[[Vector3(0.0,0.0,outer),0.0,1.0,0.0],[Vector3(0.0,0.0,0.0),0.0,1.0,0.0],[Vector3(0.0,0.0,-outer),0.0,1.0,0.0]])
		set_meta("ports",{"crown":Vector3(0.0,crown,0.0),"abutment_l":Vector3(-rim_x(abut_top)-0.6,abut_top,0.0),"abutment_r":Vector3(rim_x(abut_top)+0.6,abut_top,0.0),
			"foot_l":Vector3(-rim_x(abut_top)+0.3-1.0*int(roundf((abut_top-ground)/so))-0.8,ground,0.0)})

# --- kukul_coil ------------------------------------------------------------------------------

## The coil pillar in `parent` at `xform`: its axis the frame's y, y 0 its
## ramp's foot. Angles go from +x toward -z (counter-clockwise seen from
## above); the ramp rises that way from `foot`. opts: "girth" (1), "shaft"
## (7.5), "lane" (2 CELL), "turns" (2), "rise" (a turn's rise, 6 SET_OFF),
## "foot" (radians, -PI/2: +z), "depth" (the shaft's reach down), "seed".
static func coil(parent: Node3D, xform: Transform3D, opts := {}) -> Coil:
	var c := Coil.new()
	c.name = str(opts.get("name","KukulCoil"))
	c.transform = xform
	parent.add_child(c)
	c.build(opts)
	return c

class Coil extends Node3D:
	var shaft := 7.5
	var lane := 8.8
	var turns := 2.0
	var rise := 9.6
	var foot := -PI*0.5
	var thick := 1.6
	var top := 19.2
	var girth := 1.0
	## The line: its radius (the body's flank a clear metre off the ramp's
	## edge) and its height under the ramp (the saddle SADDLE_OVER over it).
	var line_r := 19.5
	var line_under := 2.96
	## The cap's sector past the ramp's end (radians): it roofs the last
	## whorl only where the headroom under it is ample.
	var cap_span := deg_to_rad(150.0)
	const SEGMENT := 2.2

	func outer() -> float:
		return shaft+lane

	## The ramp's top at angle `a` along it (radians from `foot`, unwrapped).
	func ramp_y(a: float) -> float:
		return clampf(rise*a/TAU,0.0,top)

	## The point at angle `theta` (absolute, from +x toward -z), radius `r`,
	## height `y`, in the coil's frame.
	static func polar(theta: float, r: float, y: float) -> Vector3:
		return Vector3(cos(theta)*r,y,-sin(theta)*r)

	## The line's height coupled to the ramp at `a` (from `foot`).
	func line_y(a: float) -> float:
		return ramp_y(a)-line_under

	func build(opts: Dictionary) -> void:
		girth = float(opts.get("girth",1.0))
		var so: float = Kit.set_off()
		shaft = float(opts.get("shaft",7.5))
		lane = float(opts.get("lane",CELL*2.0))
		turns = float(opts.get("turns",2.0))
		rise = float(opts.get("rise",so*6.0))
		foot = float(opts.get("foot",-PI*0.5))
		thick = so
		top = rise*turns
		line_r = outer()+Kit.radius(girth)*FLANK_SHARE+1.35
		line_under = Kit.saddle_top(girth)-SADDLE_OVER
		var depth := float(opts.get("depth",70.0))
		var m := GiantStone.mesher()
		var shapes: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = int(opts.get("seed",31))
		# The shaft: a drum from the haze to the cap, a ring of courses.
		var shaft_lo := -depth
		var seg := 28
		m.cylinder(Kit.at(Vector3(0.0,(shaft_lo+top)*0.5,0.0)),shaft,top-shaft_lo,seg,0.2,shaft_lo,0.92)
		var cyl := CylinderShape3D.new()
		cyl.radius = shaft
		cyl.height = top-shaft_lo
		shapes.append([cyl,Kit.at(Vector3(0.0,(shaft_lo+top)*0.5,0.0))])
		# Courses banding the shaft (silhouette), one a SET_OFF*3 down.
		var y := top-so*3.0
		while y > shaft_lo+4.0:
			m.cylinder(Kit.at(Vector3(0.0,y,0.0)),shaft+0.18,0.35,seg,0.08,NAN,0.85)
			y -= so*3.0
		# The ramp: a hull a SEGMENT along its middle, its outer face carved
		# with a rune band a quarter turn a strip. A level landing at its
		# foot (the bridge's) and at its end.
		var mid_r := shaft+lane*0.5
		var total := TAU*turns
		var da := SEGMENT/mid_r
		var nseg := int(ceil(total/da))
		da = total/nseg
		var r_in := shaft-0.25
		var r_out := outer()
		var quarter := -1
		var rm: GiantStone.Mesher = null
		var rm_mid := Vector3.ZERO
		var strips_made := 0
		var landing := deg_to_rad(18.0)
		for k in range(-int(ceil(landing/da)),nseg):
			var a0 := da*k
			var a1 := da*(k+1)
			var y0 := ramp_y(a0)
			var y1 := ramp_y(a1)
			var t0 := foot+a0
			var t1 := foot+a1
			var pts := [polar(t0,r_in,y0),polar(t0,r_out,y0),polar(t1,r_out,y1),polar(t1,r_in,y1)]
			var low := [polar(t0,r_in,y0-thick),polar(t0,r_out,y0-thick),polar(t1,r_out,y1-thick),polar(t1,r_in,y1-thick)]
			var c := polar((t0+t1)*0.5,(r_in+r_out)*0.5,(y0+y1)*0.5-thick*0.5)
			m._centre = c
			m._foot = (y0+y1)*0.5-thick
			m._tone = rng.randf_range(0.9,1.03)
			m._poly(Transform3D.IDENTITY,pts,c)
			m._poly(Transform3D.IDENTITY,low,c)
			m._poly(Transform3D.IDENTITY,[pts[1],pts[2],low[2],low[1]],c)
			if k == -int(ceil(landing/da)): m._poly(Transform3D.IDENTITY,[pts[0],pts[1],low[1],low[0]],c)
			if k == nseg-1: m._poly(Transform3D.IDENTITY,[pts[2],pts[3],low[3],low[2]],c)
			var hull := ConvexPolygonShape3D.new()
			hull.points = PackedVector3Array(pts+low)
			shapes.append([hull,Transform3D.IDENTITY])
			# The outer face's runes: a quarter turn a strip.
			if k >= 0:
				var q := int(floor(a0/(PI*0.5)))
				if q != quarter:
					if rm != null:
						Kit.strip(self,rm,rm_mid,"Spiral%d" % strips_made)
						strips_made += 1
					rm = GiantStone.mesher()
					quarter = q
					rm_mid = polar(foot+(q+0.5)*PI*0.5,r_out,ramp_y((q+0.5)*PI*0.5)-thick*0.5)
				var o0 := polar(t0,r_out+0.01,y0-thick*0.5-0.4)
				var o1 := polar(t1,r_out+0.01,y1-thick*0.5-0.4)
				var out := polar((t0+t1)*0.5,1.0,0.0)
				rm.runes(o0,o1,Vector3.UP,out.normalized(),float(k))
		if rm != null: Kit.strip(self,rm,rm_mid,"Spiral%d" % strips_made)
		# Day-sign frieze: a stone band on the parapet-less outer edge's
		# top, every other segment a feather (silhouette).
		# The cap: the shaft's top drum, and a sector over the last whorl
		# from the ramp's end on.
		var end_t := foot+total
		var cap_n := 10
		for k in cap_n:
			var a0 := end_t+cap_span*float(k)/cap_n
			var a1 := end_t+cap_span*float(k+1)/cap_n
			var pts := [polar(a0,r_in,top),polar(a0,r_out,top),polar(a1,r_out,top),polar(a1,r_in,top)]
			var low := [polar(a0,r_in,top-thick),polar(a0,r_out,top-thick),polar(a1,r_out,top-thick),polar(a1,r_in,top-thick)]
			var c := polar((a0+a1)*0.5,(r_in+r_out)*0.5,top-thick*0.5)
			m._centre = c
			m._foot = top-thick
			m._tone = 1.02
			m._poly(Transform3D.IDENTITY,pts,c)
			m._poly(Transform3D.IDENTITY,low,c)
			m._poly(Transform3D.IDENTITY,[pts[1],pts[2],low[2],low[1]],c)
			if k == cap_n-1: m._poly(Transform3D.IDENTITY,[pts[2],pts[3],low[3],low[2]],c)
			var hull := ConvexPolygonShape3D.new()
			hull.points = PackedVector3Array(pts+low)
			shapes.append([hull,Transform3D.IDENTITY])
		# On the cap: a stepped drum (two 0.4 m tiers) and a stela with the
		# coil's own runes; the serpent's face looking out over the end.
		m.cylinder(Kit.at(Vector3(0.0,top+0.2,0.0)),shaft-1.0,0.4,seg,0.08,top,1.0)
		var t1 := CylinderShape3D.new()
		t1.radius = shaft-1.0
		t1.height = 0.4
		shapes.append([t1,Kit.at(Vector3(0.0,top+0.2,0.0))])
		m.cylinder(Kit.at(Vector3(0.0,top+0.6,0.0)),shaft-3.2,0.4,seg,0.08,top,1.04)
		var t2 := CylinderShape3D.new()
		t2.radius = shaft-3.2
		t2.height = 0.4
		shapes.append([t2,Kit.at(Vector3(0.0,top+0.6,0.0))])
		var st := Vector3(0.0,top+0.8,0.0)
		Kit.block(m,shapes,Kit.at(st+Vector3(0.0,1.4,0.0)),Vector3(1.2,2.8,0.8),0.12,0.96)
		var sr := GiantStone.mesher()
		var face_t := end_t+cap_span*0.5
		var face := polar(face_t,1.0,0.0)
		var side := Vector3(-face.z,0.0,face.x)
		sr.runes(st+face*0.41+side*0.45+Vector3(0.0,1.0,0.0),st+face*0.41-side*0.45+Vector3(0.0,1.0,0.0),Vector3.UP,face,7.0)
		sr.runes(st-face*0.41-side*0.45+Vector3(0.0,1.0,0.0),st-face*0.41+side*0.45+Vector3(0.0,1.0,0.0),Vector3.UP,-face,8.0)
		Kit.strip(self,sr,st+Vector3(0.0,1.4,0.0),"CapStela")
		# The serpent's face at the cap's far edge, looking out.
		var fe := polar(end_t+cap_span-0.12,r_out-1.4,top)
		var fb := Basis(Vector3.UP,end_t+cap_span-0.12)
		m.box(Transform3D(fb,fe+Vector3(0.0,0.6,0.0)),Vector3(2.4,1.2,2.0),0.16,top)
		m.box(Transform3D(fb,fe+fb*Vector3(0.0,0.35,1.2)),Vector3(1.8,0.7,1.0),0.12,top)
		for sx: float in [-1.0,1.0]:
			m.box(Transform3D(fb,fe+fb*Vector3(sx*0.62,1.0,0.95)),Vector3(0.4,0.32,0.3),0.05,top,0.7)
		Kit.stone_node(self,m)
		Kit.solid(self,shapes)
		if bool(opts.get("cover",true)):
			Kit.cover(self,Rect2(-shaft*0.7,-shaft*0.7,shaft*1.4,shaft*1.4),top+0.8,int(opts.get("seed",31)),0.5)
		set_meta("way",way(0.0))
		set_meta("ports",{"foot":polar(foot,mid_r,0.0),"cap":Vector3(0.0,top+0.8,0.0),"end":polar(end_t,mid_r,top),
			"cap_edge":polar(end_t+cap_span*0.4,r_out-0.6,top)})

	## The line coupled to the ramp, as control points (B-spline: their
	## radius widened so the curve lies on `line_r`), from `from` (radians
	## along the ramp from its foot) to its end and `over` past it at the
	## cap's height, every `every` radians; weave 0.
	func way(from: float, over := deg_to_rad(60.0), every := deg_to_rad(30.0)) -> Array:
		var shrink := (4.0+2.0*cos(every))/6.0
		var out: Array = []
		var a := from
		var end := TAU*turns+over
		while a <= end+0.001:
			out.append([polar(foot+a,line_r/shrink,line_y(minf(a,TAU*turns))),0.0,1.0,0.0])
			a += every
		return out

# --- colossus_ashbowl ----------------------------------------------------------------------

## The ash bowl in `parent` at `xform`: its middle on the court's floor (y
## 0), sunk in it. It fills its own square (half `reach()` a side) down to
## the floor's top: lay the court round it. opts: "radius" (the ash's, 8),
## "rows" (2 seat rows down into it), "seed".
static func ashbowl(parent: Node3D, xform: Transform3D, opts := {}) -> AshBowl:
	var b := AshBowl.new()
	b.name = str(opts.get("name","AshBowl"))
	b.transform = xform
	parent.add_child(b)
	b.build(opts)
	return b

class AshBowl extends Node3D:
	var radius := 8.0
	var rows := 2
	var row := 0.9
	## The ash's top as seen and as stood on (the feet sink in it).
	var ash_y := -1.35
	var stand_y := -1.7
	var ash_body: StaticBody3D
	var ash_mesh: MeshInstance3D

	func reach() -> float:
		return radius+row*rows+0.6

	func build(opts: Dictionary) -> void:
		radius = float(opts.get("radius",8.0))
		rows = int(opts.get("rows",2))
		var riser := SEAT
		stand_y = -riser*(rows+2)
		ash_y = stand_y+float(ASH.depth)
		var m := GiantStone.mesher()
		var shapes: Array = []
		var c := Vector3.ZERO
		# The rim (a kerb a step over the ash), the seat rows stepping up to
		# the floor, and the square's corners at the floor.
		var r := radius
		Kit.ring_boxes(m,shapes,c,r,r+0.6,stand_y-1.0,stand_y+riser,28,0.0,TAU,0.95)
		r += 0.6
		for j in rows:
			var y_top := stand_y+riser*(j+2)
			Kit.ring_boxes(m,shapes,c,r,r+row,stand_y-1.0,y_top,32,0.0,TAU,0.9+0.04*j)
			r += row
		# The square's corners round it, at the floor (a hair under it, so
		# the court's own paving wins where they meet).
		Kit.ring_boxes(GiantStone.mesher(),shapes,c,r,r*1.43,-1.0,-0.01,24)
		# Drawn flush and seamless: the floor between the last row and the
		# square's edge, sector by sector.
		var half := reach()
		var n_sec := 32
		m._foot = -1.0
		m._tone = 0.86
		for k in n_sec:
			var a0 := TAU*float(k)/n_sec
			var a1 := TAU*float(k+1)/n_sec
			var pts: Array = [Vector3(cos(a0)*r,0.0,-sin(a0)*r)]
			for a: float in [a0,a1]:
				var d := Vector2(cos(a),-sin(a))
				var t := half/maxf(absf(d.x),absf(d.y))
				pts.append(Vector3(d.x*t,0.0,d.y*t))
				if a == a0:
					# A square's corner inside the sector.
					for cc: Vector2 in [Vector2(half,half),Vector2(-half,half),Vector2(-half,-half),Vector2(half,-half)]:
						var ca := fposmod(atan2(-cc.y,cc.x),TAU)
						if ca > a0 and ca < a1: pts.append(Vector3(cc.x,0.0,cc.y))
			pts.append(Vector3(cos(a1)*r,0.0,-sin(a1)*r))
			m._centre = Vector3(cos((a0+a1)*0.5),0.0,-sin((a0+a1)*0.5))*(r+half)*0.5
			m._poly(Transform3D.IDENTITY,pts,m._centre-Vector3.UP)
		# The stele at the middle, its top snapped off and lying in the ash.
		Kit.block(m,shapes,Kit.at(Vector3(0.0,stand_y+2.2,0.0)),Vector3(1.2,4.4,1.2),0.1,0.94)
		var fallen := Transform3D(Basis(Vector3(0.4,0.0,1.0).normalized(),1.25),Vector3(2.4,ash_y+0.25,1.3))
		Kit.block(m,shapes,fallen,Vector3(1.2,1.8,1.2),0.12,0.98)
		var sr := GiantStone.mesher()
		sr.runes(Vector3(-0.45,stand_y+2.0,0.61),Vector3(0.45,stand_y+2.0,0.61),Vector3.UP,Vector3.BACK,4.0)
		sr.runes(Vector3(0.45,stand_y+2.0,-0.61),Vector3(-0.45,stand_y+2.0,-0.61),Vector3.UP,Vector3.FORWARD,9.0)
		Kit.strip(self,sr,Vector3(0.0,stand_y+2.4,0.0),"SteleRunes")
		Kit.stone_node(self,m)
		Kit.solid(self,shapes)
		# The ash: soft ground (a cylinder the feet stand in, ASH.depth under
		# its seen top), drawn as a pale disc of drifts, his footprints in a
		# line across it.
		ash_body = StaticBody3D.new()
		ash_body.name = "Ash"
		var cs := CollisionShape3D.new()
		var ac := CylinderShape3D.new()
		ac.radius = radius+0.05
		ac.height = 2.0
		cs.shape = ac
		cs.position = Vector3(0.0,stand_y-1.0,0.0)
		ash_body.add_child(cs)
		PhysicsGround.mark_soft(ash_body,ASH)
		add_child(ash_body)
		ash_mesh = mesh_node_ash(self,radius+0.1,ash_y,int(opts.get("seed",5)))
		set_meta("ports",{"ash":Vector3(0.0,ash_y,0.0),"rim":Vector3(radius+0.3,stand_y+riser,0.0),"floor":Vector3(reach(),0.0,0.0)})

	## The ash's disc: drifts and his footprints, pale bone-grey.
	static func mesh_node_ash(parent: Node3D, r: float, y: float, seed_value: int) -> MeshInstance3D:
		var noise := FastNoiseLite.new()
		noise.seed = seed_value
		noise.frequency = 0.18
		var rings := 10
		var sides := 40
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prints: Array[Vector3] = []
		for i in 5:
			var t := -0.8+0.4*i
			prints.append(Vector3(t*r+0.6*(i%2*2-1),0.0,t*r*0.35-1.2+1.1*(i%2)))
		var pt := func(rr: float, a: float) -> Vector3:
			var p := Vector3(cos(a)*rr,0.0,-sin(a)*rr)
			var h := noise.get_noise_2d(p.x,p.z)*0.12+noise.get_noise_2d(p.x*4.0,p.z*4.0)*0.025
			# The rim's drift banked up, the middle settled.
			h += smoothstep(r*0.7,r,rr)*0.12
			for f: Vector3 in prints:
				var d := Vector2((p.x-f.x)/1.1,(p.z-f.z)/0.7)
				h -= 0.16*maxf(0.0,1.0-d.length_squared())
			return Vector3(p.x,y+h,p.z)
		var shade := func(p: Vector3) -> Color:
			var v := 0.5+(p.y-y)*1.6+noise.get_noise_2d(p.x*2.0,p.z*2.0)*0.09+noise.get_noise_2d(p.x*7.0,p.z*7.0)*0.04
			return Color(v*1.02,v*0.99,v*0.93)
		for i in rings:
			var r0 := r*float(i)/rings
			var r1 := r*float(i+1)/rings
			for k in sides:
				var a0 := TAU*float(k)/sides
				var a1 := TAU*float(k+1)/sides
				var q: Array[Vector3] = [pt.call(r0,a0),pt.call(r1,a0),pt.call(r1,a1),pt.call(r0,a1)]
				for tri: Array in [[0,2,1],[0,3,2]]:
					for idx: int in tri:
						var p: Vector3 = q[idx]
						st.set_color(shade.call(p))
						st.set_normal(Vector3.UP)
						st.add_vertex(p)
		st.generate_normals()
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(0.74,0.71,0.66)
		# Fine grain over the drifts (the ash's own speckle, by the world).
		var grain := NoiseTexture2D.new()
		var gn := FastNoiseLite.new()
		gn.frequency = 0.02
		gn.seed = seed_value+3
		grain.noise = gn
		var ramp := Gradient.new()
		ramp.set_color(0,Color(0.8,0.79,0.77))
		ramp.set_color(1,Color(1.0,1.0,1.0))
		grain.color_ramp = ramp
		grain.seamless = true
		grain.width = 256
		grain.height = 256
		mat.albedo_texture = grain
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.15,0.15,0.15)
		mat.detail_enabled = false
		mat.roughness = 1.0
		mat.metallic_specular = 0.1
		var mi := MeshInstance3D.new()
		mi.name = "AshMesh"
		mi.mesh = st.commit()
		mi.material_override = mat
		parent.add_child(mi)
		return mi
