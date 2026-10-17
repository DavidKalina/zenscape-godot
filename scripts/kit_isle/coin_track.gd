extends RefCounted
## The coin track (a kit piece builder, STAND-IN stone): the channel the
## rolling coins lap (scripts/enemies/rolling_coin.gd's track mode, driven by
## scripts/enemies/coin_circuit.gd), built from a track description given as
## data. No class_name: preload it by path.
##
##   const CoinTrack = preload("res://scripts/kit_isle/coin_track.gd")
##   var track := CoinTrack.new(TRACK)     # TRACK: the description below
##   track.build(root)                     # the stone: one mesh, one body
##   var circuit := track.circuit(offset)  # the coins' driver (a Node3D)
##   host.add_child(circuit)
##   circuit.mint(field, s)                # a coin on the lap at s m
##
## The description (a Dictionary, in the caller's frame: x, z flat, y up;
## every height a bed's top):
##   lap_speed   the coins' speed on the beds (m/s)
##   clear       the bed's width between the kerbs (m)
##   kerb        Vector2(width, height over the bed) of the side kerbs
##   cradle_kerb the cradles' kerbs' height (m)
##   bed         the beds' depth under their top (m)
##   lap         the coins' line in lap order, one leg after another, the
##               last ending where the first begins. Each leg {k, ...}:
##     roll  a straight from `a` to `b` (Vector3; its bed height lerped)
##     arc   round `c` (Vector3) at radius `r` from angle `from` to `to`
##           (deg; x cos, z sin), its bed `y` (Vector2) lerped from x to y
##     lip   a roll from `a` to its edge `b`, its bed rising (b.y over a.y)
##           to the edge; at the edge the coin is kicked to `kick`
##           (Vector2: x its speed along the way, y up); `rail` the side
##           (+1 left of the way, -1 right) its side rail stands on
##     fly   the open air, `a` the lip's edge to `b` the cradle's catch
##           point. The coin flies its own ballistic arc (its fly_gravity,
##           39 at its size): pick the kick so that arc ends on `b`.
##     Any leg may carry a `name` (a flight's is the HUD's and checks').
##   cradles     the catch bowls: {name, rim (where the flight comes in),
##               catch (3 m in, where a coin lands), len (6), bowl (its
##               floor's height)}; the lap's legs carry the bed past the
##               catch, the cradle the run-in and its high kerbs
##   gates       (optional) kerb gaps a hunting coin leaves the lap by:
##               {name, field, on (on the line), at (the gap's middle in the
##               kerb), out (unit, toward its field), plaza (optional, the
##               field's height: a sunk bed gets a ramp up to it; 0)}
##   gate_gap    the gaps' width (m)
##   rim_kerbs   (optional) kerbs round a field's rim: arcs {r, from, to
##               (deg), c (optional centre, Vector3: its y the height; the
##               origin)}
##   chicane     (optional) one more such arc
##   hunt        (optional, false) whether the coins leave the lap through
##               the gates to hunt him; hunt_cap (2) how many at once;
##               hub {at (Vector2), r} (optional; the origin, 16) the field
##               a coin rolling home is lost past
##
## The track asks nothing of the land. Cutting the turf to its beds and
## keeping it bare are the caller's, through these hooks:
##   ground(top)  a KitLand.island "ground" callable: `top`, cut down under
##                the beds and bowls (with "cell": CELL, so the cut's edge
##                hides under the kerbs)
##   bare(p)      whether (x, z) is on the track (wear it, grow nothing)
##   solids()     its boxes for a motif's occupancy ([Rect2, lo, hi, null])

const CoinCircuit = preload("res://scripts/enemies/coin_circuit.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

## The lap's samples' spacing (m).
const STEP := 0.5
## How far either side of the line the turf is cut to its bed (m: under
## the kerb), how far under the bed's top (under the slab), the turf's grid
## on a track's isles (fine enough that the cut's edge hides under the
## kerbs), and how far either side the turf is kept bare.
const CUT := 1.45
const SINK := 0.15
const CELL := 0.8
const BARE := 2.2
## The lip's slab, deeper than a bed's (a stone tongue, not a paving).
const LIP_DEPTH := 0.6
## The side rail beside a lip: deep, up over the lip's foot.
const RAIL := Vector2(0.6,1.0)
## The gate's flared kerb ends: long, turned out from the kerb's line (deg).
const GATE_WING := Vector2(1.2,40.0)
## The stone's tones' seed.
const STONE_SEED := 7100

## The description.
var data: Dictionary
var _lap: Array = []
var _beds := {}
var _boxes: Array = []

func _init(track: Dictionary) -> void:
	data = track

# --- The lap -------------------------------------------------------------------------

## The lap sampled every STEP m, in lap order from lap 0: each {p (Vector3:
## on the bed), s (m along the lap), leg (its index in `lap`), k (its kind),
## way (Vector3: flat, along)}. A flight's samples run the straight chord
## (the coin's arc is the track mode's).
func lap_line() -> Array:
	if not _lap.is_empty(): return _lap
	var out: Array = []
	var s := 0.0
	var legs: Array = data.lap
	for n in legs.size():
		var leg: Dictionary = legs[n]
		var length := leg_length(leg)
		var count := maxi(1,ceili(length/STEP))
		for j in count:
			var t := float(j)/count
			out.append({"p":leg_point(leg,t),"s":s+length*t,"leg":n,"k":str(leg.k),"way":leg_way(leg,t)})
		s += length
	_lap = out
	return out

## The lap's whole length (m).
func lap_length() -> float:
	var s := 0.0
	for leg: Dictionary in data.lap: s += leg_length(leg)
	return s

static func leg_length(leg: Dictionary) -> float:
	if str(leg.k) == "arc": return float(leg.r)*absf(deg_to_rad(float(leg.to)-float(leg.from)))
	var a: Vector3 = leg.a
	var b: Vector3 = leg.b
	return Vector2(b.x-a.x,b.z-a.z).length()

## A leg's point at `t` (0..1) along it, on its bed.
static func leg_point(leg: Dictionary, t: float) -> Vector3:
	if str(leg.k) == "arc":
		var c: Vector3 = leg.c
		var ang := deg_to_rad(lerpf(float(leg.from),float(leg.to),t))
		var y: Vector2 = leg.y
		return Vector3(c.x+cos(ang)*float(leg.r),lerpf(y.x,y.y,t),c.z+sin(ang)*float(leg.r))
	return (leg.a as Vector3).lerp(leg.b,t)

## A leg's flat way along at `t`.
static func leg_way(leg: Dictionary, t: float) -> Vector3:
	if str(leg.k) == "arc":
		var ang := deg_to_rad(lerpf(float(leg.from),float(leg.to),t))
		var turn := signf(float(leg.to)-float(leg.from))
		return Vector3(-sin(ang),0.0,cos(ang))*turn
	var d: Vector3 = (leg.b as Vector3)-(leg.a as Vector3)
	return Vector3(d.x,0.0,d.z).normalized()

## The kick that flies a coin from `a` to `b` under `gravity` with up speed
## `up`: Vector2(speed along, up), for a lip's `kick`.
static func kick_for(a: Vector3, b: Vector3, up: float, gravity := 39.0) -> Vector2:
	var drop := a.y-b.y
	var t := (up+sqrt(up*up+2.0*gravity*drop))/gravity
	return Vector2(Vector2(b.x-a.x,b.z-a.z).length()/t,up)

## The lowest bed within `reach` of (x, z) (INF: none): the lap's rolled
## samples and the cradles' run-ins, hashed by 2 m cell.
func bed_at(p: Vector2, reach: float) -> float:
	if _beds.is_empty(): _hash_beds()
	var k := Vector2i(floori(p.x/2.0),floori(p.y/2.0))
	var best := INF
	var r := ceili(reach/2.0)
	for dx in range(-r,r+1):
		for dz in range(-r,r+1):
			for q: Vector3 in _beds.get(k+Vector2i(dx,dz),[]):
				if q.y < best and Vector2(q.x,q.z).distance_to(p) <= reach: best = q.y
	return best

func _hash_beds() -> void:
	var beds := {}
	var pts: Array[Vector3] = []
	for q: Dictionary in lap_line():
		if q.k != "fly": pts.append(q.p)
	for c: Dictionary in data.cradles:
		var rim: Vector3 = c.rim
		var catch_at: Vector3 = c.catch
		var way := Vector3(catch_at.x-rim.x,0.0,catch_at.z-rim.z).normalized()
		var d := 0.0
		while d <= float(c.len)+0.01:
			pts.append(Vector3(rim.x,float(c.bowl),rim.z)+way*d)
			d += STEP
	for q in pts:
		var k := Vector2i(floori(q.x/2.0),floori(q.z/2.0))
		if not beds.has(k): beds[k] = []
		beds[k].append(q)
	_beds = beds

# --- The land's hooks ---------------------------------------------------------------------

## A KitLand.island "ground": flat at `top`, cut under the beds and bowls.
func ground(top: float) -> Callable:
	return func(x: float, z: float) -> float: return minf(top,bed_at(Vector2(x,z),CUT)-SINK)

## Whether (x, z) is on the track (keep it bare).
func bare(p: Vector2) -> bool:
	return bed_at(p,BARE) < INF

## Its boxes for a motif's occupancy: [Rect2 (x, z), lo, hi, null].
func solids() -> Array:
	var out: Array = []
	for t: Array in track_boxes():
		var b: AABB = (t[0] as Transform3D)*AABB(-(t[1] as Vector3)*0.5,t[1])
		out.append([Rect2(b.position.x,b.position.z,b.size.x,b.size.z),b.position.y,b.end.y,null])
	return out

# --- The stone ----------------------------------------------------------------------------

## The track's stand-in stone as boxes: each [Transform3D (its middle),
## size, part]. Beds (`clear` wide, `bed` deep), kerbs (`kerb` over the
## bed; `cradle_kerb` at the cradles), the lips (a tilted tongue LIP_DEPTH
## deep, its rail RAIL up), the gates (`gate_gap` gaps, flared ends, a ramp
## up from a sunk bed), the rim kerbs and the chicane.
func track_boxes() -> Array:
	if not _boxes.is_empty(): return _boxes
	var out: Array = []
	var tr := data
	var clear := float(tr.clear)
	var kerb: Vector2 = tr.kerb
	var side_at := clear*0.5+kerb.x*0.5
	var bed := float(tr.bed)
	for leg: Dictionary in tr.lap:
		var k := str(leg.k)
		if k == "fly": continue
		# The leg in chords (an arc's every 6 deg at most).
		var pieces := 1 if k != "arc" else maxi(1,ceili(absf(float(leg.to)-float(leg.from))/6.0))
		for j in pieces:
			var a := leg_point(leg,float(j)/pieces)
			var b := leg_point(leg,float(j+1)/pieces)
			var over := 0.08 if k == "arc" else 0.05
			out.append(_stretch(a,b,0.0,clear,0.0,LIP_DEPTH if k == "lip" else bed,"lip" if k == "lip" else "bed",over))
			for side: float in [1.0,-1.0]:
				if k == "lip" and side == float(leg.rail):
					# The side rail: flat, RAIL.y over the lip's foot.
					var edge := Vector3(b.x,a.y,b.z)
					out.append(_stretch(a,edge,side*(clear*0.5+RAIL.x*0.5),RAIL.x,RAIL.y,bed,"rail",0.0))
					continue
				for span: Vector2 in _kerb_spans(a,b,side):
					out.append(_stretch(a.lerp(b,span.x),a.lerp(b,span.y),side*side_at,kerb.x,kerb.y,bed,"kerb",over))
	# The cradles: their run-in bed (the lap's legs carry the rest) and
	# their high kerbs the whole length.
	for c: Dictionary in tr.cradles:
		var rim: Vector3 = c.rim
		var catch_at: Vector3 = c.catch
		var way := Vector3(catch_at.x-rim.x,0.0,catch_at.z-rim.z).normalized()
		var end := rim+way*float(c.len)
		out.append(_stretch(rim,catch_at,0.0,clear,0.0,bed,"cradle",0.0))
		for side: float in [1.0,-1.0]:
			out.append(_stretch(rim,end,side*side_at,kerb.x,float(tr.cradle_kerb),bed,"cradle_kerb",0.0))
	# The gates: flared ends either side of the gap, and a ramp from the
	# plaza down into a sunk bed.
	for g: Dictionary in tr.get("gates",[]):
		var on: Vector3 = g.on
		var out_way: Vector3 = g.out
		var plaza := float(g.get("plaza",0.0))
		var along := Vector3.UP.cross(out_way).normalized()
		var half := float(tr.gate_gap)*0.5
		for e: float in [1.0,-1.0]:
			var root := on+out_way*side_at+along*e*(half+kerb.x*0.5)
			var flare := (out_way*cos(deg_to_rad(GATE_WING.y))+along*e*sin(deg_to_rad(GATE_WING.y))).normalized()
			var tip := root+flare*GATE_WING.x
			out.append(_stretch(root,Vector3(tip.x,root.y,tip.z),0.0,kerb.x,kerb.y,bed,"gate",0.0))
		if on.y < plaza-0.01:
			var low := on+out_way*(clear*0.5)
			var high := Vector3(on.x,plaza,on.z)+out_way*(side_at+1.6)
			out.append(_stretch(low,high,0.0,float(tr.gate_gap),0.0,bed,"gate_ramp",0.0))
	# The fields' rim kerbs and the chicane: arcs round their centre.
	var arcs: Array = (tr.get("rim_kerbs",[]) as Array).duplicate()
	if tr.has("chicane"): arcs.append(tr.chicane)
	for r: Dictionary in arcs:
		var c: Vector3 = r.get("c",Vector3.ZERO)
		var radius := float(r.r)
		var a0 := float(r.from)
		var a1 := float(r.to)
		var n := maxi(1,ceili((a1-a0)/6.0))
		for j in n:
			var t0 := deg_to_rad(lerpf(a0,a1,float(j)/n))
			var t1 := deg_to_rad(lerpf(a0,a1,float(j+1)/n))
			out.append(_stretch(c+Vector3(cos(t0),0.0,sin(t0))*radius,c+Vector3(cos(t1),0.0,sin(t1))*radius,0.0,kerb.x,kerb.y,bed,"rim_kerb",0.08))
	_boxes = out
	return out

## The kerb's spans (0..1 along a to b) on `side`, less any gate's gap on
## that side of that stretch.
func _kerb_spans(a: Vector3, b: Vector3, side: float) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(0.0,1.0)]
	var flat := Vector2(b.x-a.x,b.z-a.z)
	var length := flat.length()
	if length < 0.01: return spans
	var way := Vector3(flat.x,0.0,flat.y)/length
	var left := Vector3.UP.cross(way)
	for g: Dictionary in data.get("gates",[]):
		var on: Vector3 = g.on
		var rel := Vector3(on.x-a.x,0.0,on.z-a.z)
		if absf(rel.dot(left)) > 0.2 or signf((g.out as Vector3).dot(left)) != side: continue
		var t := rel.dot(way)/length
		var half := float(data.gate_gap)*0.5/length
		if t+half < 0.0 or t-half > 1.0: continue
		var cut: Array[Vector2] = []
		for sp in spans:
			if sp.x < t-half: cut.append(Vector2(sp.x,minf(sp.y,t-half)))
			if sp.y > t+half: cut.append(Vector2(maxf(sp.x,t+half),sp.y))
		spans = cut
	return spans

## A box from `a` to `b` (each on its bed), `off` to the left of the way,
## `width` across, `up` over the bed and `down` under it, tilted with the
## bed's slope, `over` more at each end.
static func _stretch(a: Vector3, b: Vector3, off: float, width: float, up: float, down: float, part: String, over: float) -> Array:
	var along := (b-a).normalized()
	var left := Vector3.UP.cross(Vector3(along.x,0.0,along.z)).normalized()
	var lift := along.cross(left).normalized()
	var size := Vector3(width,up+down,a.distance_to(b)+over*2.0)
	var mid := (a+b)*0.5+left*off+lift*(up-down)*0.5
	return [Transform3D(Basis(left,lift,along),mid),size,part]

## The look `build` needs, made on the main thread (a motif's `warm`).
func warm() -> void:
	RuinKit.materials()
	lap_line()
	bed_at(Vector2.ZERO,1.0)
	track_boxes()

## The track built into `root`: its boxes in one mesh of RuinKit stone and
## one body (no kit meta: a coin crashes into it, it never breaks). Returns
## the holder ("STANDIN_Track": Drawn, Stone).
func build(root: Node3D) -> Node3D:
	var holder := Node3D.new()
	holder.name = "STANDIN_Track"
	root.add_child(holder)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "Stone"
	holder.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = STONE_SEED
	for t: Array in track_boxes():
		_stone_box(st,t[0],t[1],rng)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = t[1]
		shape.shape = box
		shape.transform = t[0]
		body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "Drawn"
	mesh.mesh = st.commit()
	mesh.material_override = RuinKit.materials().stone
	holder.add_child(mesh)
	return holder

## One stand-in box drawn in the kit's stone (its vertex colour, linear, as
## RuinKit's blocks are: the stone shader multiplies by it; uncoloured it
## draws white): each box a tone between RuinKit.STONE and STONE_COOL,
## each face a little off it, the tops toward the worn EDGE stone (the
## coins' polish), the undersides and the damp foot darker.
static func _stone_box(st: SurfaceTool, xf: Transform3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tone := RuinKit.STONE.lerp(RuinKit.STONE_COOL,rng.randf())
	tone = tone*(1.0+rng.randf_range(-0.5,0.5)*RuinKit.BLOCK_TONE)
	var faces := {}
	for i in index:
		var n := (xf.basis*normals[i]).normalized()
		var key := Vector3i(roundi(n.x*4.0),roundi(n.y*4.0),roundi(n.z*4.0))
		if not faces.has(key):
			var c := tone*(1.0+rng.randf_range(-0.5,0.5)*RuinKit.FACETS)
			if n.y > 0.7: c = c.lerp(RuinKit.EDGE,0.3)
			elif n.y < -0.7: c = c*RuinKit.UNDER
			else: c = c.lerp(c*RuinKit.DAMP,0.35)
			c.a = 1.0
			faces[key] = c.srgb_to_linear()
		st.set_color(faces[key])
		st.set_normal(n)
		st.add_vertex(xf*verts[i])

# --- What moves ---------------------------------------------------------------------------

## The coins' driver (scripts/enemies/coin_circuit.gd) on this track, set
## into the world at `offset`: add it to the scene, then `mint` its coins.
func circuit(offset := Vector3.ZERO) -> Node3D:
	var c: Node3D = CoinCircuit.new()
	c.name = "CoinCircuit"
	c.setup_track(self,offset)
	return c
