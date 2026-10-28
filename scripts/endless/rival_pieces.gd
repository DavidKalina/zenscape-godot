extends RefCounted
## The rival's lines through the amberlands' set pieces and bridges
## (scripts/endless/rival_line.gd `_candidates`): what of a standing piece
## (LandArches `standing`: a set piece from set_plan.gd, a bridge from
## bridge_plan.gd) it may take as a race's gate.
##
## A piece's openings in the world (`openings`): a set piece's from its kit
## (RuinKitGothic `openings`, or RuinKitColosseum's for the colosseum, the
## record's node placing them, so a layout move carries them), a road bridge's as its built run keeps them
## (RuinKitBridge `piece`'s "openings"), an aqueduct bridge's derived from
## its spec as bridge_build.gd lays the run (each standing arch of the
## under-arcade, over the land's highest under it, and a broken run's gap).
##
## Its lines (`lines`): the openings that line up on one way (their ways
## within ALIGN, their middles within CROSS of each other's line across,
## their heights overlapping and no steeper than SLOPE between), each a gate
## the rival can fly level: no knife slot (it never rolls onto a wingtip),
## at least WIDE wingspans across and TALL up (a lane, the nave's, a
## flank's, the deck's, is no gate: the gates down it make its line). A line
## that would put the rival through a knife slot, or whose middle line (IN m
## before its first gate to OUT m past its last, where it is flown level)
## runs into the flight's solid or the land, is left out. Each line is
## flown both ways.
##
## A line: {id (the piece's name and its first gate's), kind ("set" or
## "bridge"), gates ([{name, c (world, where it is flown: `_heights`), half
## (Vector3: across, up, along), head, lo, hi (its floor and its head's
## top, world y)}], in order along `way`), way (world XZ, unit), room (the
## least half width)}.

const Gothic = preload("res://scripts/ruin_kit_gothic.gd")
const Colosseum = preload("res://scripts/ruin_kit_colosseum.gd")
const Road = preload("res://scripts/ruin_kit_bridge.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## A gate the rival takes: across and up (wingspans).
const WIDE := 2.0
const TALL := 2.2
## Lining up: ways within ALIGN (cos), middles within CROSS m across of the
## other's line, their heights overlapping, a rise between two no steeper
## than SLOPE.
const ALIGN := 0.97
const CROSS := 1.5
const SLOPE := 0.2
## Where in a gate it flies (`_heights`): no higher than its box's top and
## this share of its head, no nearer its floor or that top than MARGIN
## wingspans.
const HEAD_AIM := 0.35
const MARGIN := 0.75
## The line is flown level from IN m before its first gate's face to OUT m
## past its last's (rival_line.gd's lead-in and run out, both ways), and
## checked clear of the solid (padded by half a wingspan) and over the land
## all that way, every CLEAR_STEP m.
const IN := 60.0
const OUT := 60.0
const CLEAR_STEP := 1.5

## Where the last line `_clear` turned down met the land or stone (for
## checks): {at, what}.
static var blocked := {}

## The openings of record `r` in the world: [{name, kind, f (Transform3D,
## world), size, head, knife, lane, forgive}], [] when it is not a set
## piece or a bridge.
static func openings(game: Node, r: Dictionary) -> Array:
	var spec: Dictionary = r.spec
	var node: Node3D = r.node
	var out: Array = []
	if spec.has("set"):
		var kind := String(spec.kind)
		if kind == "colosseum":
			for o: Dictionary in Colosseum.openings(kind,int(spec.seed),float(spec.weathered)):
				out.append(_colosseum_world(o,node.global_transform*(o.frame as Transform3D)))
			return out
		for o: Dictionary in Gothic.openings(kind,int(spec.seed),float(spec.weathered)):
			out.append(_world(o,node.global_transform*(o.frame as Transform3D)))
	elif spec.has("bridge"):
		var b: Dictionary = spec.bridge
		var shift := -float(Aqueduct.SPAN)*int(spec.count)*0.5
		if str(b.get("style","")) == "road":
			# The built run keeps its openings (RuinKitBridge `piece`), in
			# its own frame; planned again only if not.
			var run := _with_openings(node)
			if run != null:
				for o: Dictionary in run.get_meta("openings"): out.append(_world(o,run.global_transform*(o.frame as Transform3D)))
				return out
			var ground := _run_ground(game,spec,node.global_transform,shift)
			var p := Road.full_plan(int(spec.seed),float(spec.weathered),float(spec.length),float(b.gap),float(spec.drop),bool(b.broken),ground)
			var place := node.global_transform*Transform3D(Basis.IDENTITY,Vector3(shift,0.0,0.0))
			for o: Dictionary in Road.openings(p): out.append(_world(o,place*(o.frame as Transform3D)))
		else:
			_aqueduct(game,spec,node.global_transform,shift,out)
	return out

## `node` or the first node under it that keeps its "openings".
static func _with_openings(node: Node) -> Node3D:
	if node is Node3D and node.has_meta("openings"): return node
	for child in node.get_children():
		var found := _with_openings(child)
		if found != null: return found
	return null

static func _world(o: Dictionary, f: Transform3D) -> Dictionary:
	return {"name":String(o.name),"kind":String(o.kind),"f":f,"size":o.size,"head":float(o.get("head",0.0)),
		"knife":bool(o.get("knife",false)),"lane":bool(o.get("lane",false)),"forgive":bool(o.get("forgive",false))}

## A colosseum opening (RuinKitColosseum `openings`) as the rival reads it:
## the ambulatory's bays are a lane (a curving lap, no straight line
## through them); the trench's two ends are open overhead (the plane's
## wings ride under the arena's floor), so their box's height is no bar.
static func _colosseum_world(o: Dictionary, f: Transform3D) -> Dictionary:
	var w := _world(o,f)
	if String(o.kind) == "ambulatory": w.lane = true
	if String(o.kind) == "trench" and not bool(o.lane): w["open_top"] = true
	return w

## The run's ground (bridge_build.gd `run_ground`), from the placed node.
static func _run_ground(game: Node, spec: Dictionary, xf: Transform3D, shift: float) -> Callable:
	var field: RefCounted = game.field
	var oy := xf.origin.y
	return func(x: float, z: float) -> float:
		var w := xf*Vector3(x+shift,0.0,z)
		return float(field.height(w.x,w.z))-oy

## An aqueduct bridge's under-arcade arches and gap (as scratch's flyability
## driver derived them, checked flown in 30c0934b).
static func _aqueduct(game: Node, spec: Dictionary, xf: Transform3D, shift: float, out: Array) -> void:
	var b: Dictionary = spec.bridge
	var grow := float(spec.grow)
	var count := int(spec.count)
	var tier := bool(b.tier)
	var cut := int(b.cut)
	var miss := int(b.miss)
	var span: float = Aqueduct.SPAN
	var basis := xf.basis.orthonormalized()
	var depth := (Aqueduct.PIER.y*0.5+Aqueduct.CUTWATER.x+0.5)*2.0*grow
	var spring: float = (Aqueduct.LOWER_SPRING if tier else Aqueduct.SPRING)*grow
	var clear: float = Aqueduct.CLEAR*grow
	var field: RefCounted = game.field
	for i in range(count):
		if cut >= 0 and i >= cut-1 and i <= cut+miss: continue
		var mid: Vector3 = xf*(Vector3(span*(i+0.5)+shift,0.0,0.0)*grow)
		var floor_y := -INF
		for sx: float in [-0.35,0.0,0.35]:
			for sz: float in [-0.5,0.0,0.5]:
				var p: Vector3 = mid+basis.x*sx*clear+basis.z*sz*depth
				var top := float(field.height(p.x,p.z))
				for st: Vector2 in game.arches.stretches(Vector3(p.x,top,p.z),0.0):
					if st.x <= top+0.6 and st.y < mid.y+spring: top = maxf(top,st.y)
				floor_y = maxf(floor_y,top)
		var lo := floor_y+1.5
		var hi := mid.y+spring
		if hi-lo < 3.0: continue
		out.append({"name":"arch_%d" % i,"kind":"arch","f":Transform3D(basis,Vector3(mid.x,(lo+hi)*0.5,mid.z)),
			"size":Vector3(clear-1.0,hi-lo,depth),"head":Aqueduct.CLEAR*0.866*grow*0.8,"knife":false,"lane":false,"forgive":false})
	if cut >= 0:
		# The gap between the snapped spans, through the deck's height: as
		# wide as it is open there.
		var g: Vector3 = xf*(Vector3(span*(cut+miss*0.5)+shift,Aqueduct.DECK-3.0,0.0)*grow)
		var half := 0.0
		while half < span*(miss+2)*grow:
			var hit := false
			for yy: float in [-3.0,0.0,3.0]:
				for zz: float in [-0.5,0.0,0.5]:
					for sx: float in [-1.0,1.0]:
						if _solid(game,g+basis.x*sx*half+Vector3.UP*yy*grow+basis.z*zz*depth): hit = true
			if hit: break
			half += 0.25
		out.append({"name":"gap","kind":"gap","f":Transform3D(basis,g),"size":Vector3(half*2.0,6.0*grow,depth+4.0),
			"head":0.0,"knife":false,"lane":false,"forgive":false})

## The land or the flight's solid (unpadded) at `p`.
static func _solid(game: Node, p: Vector3) -> bool:
	if float(game.field.height(p.x,p.z)) > p.y: return true
	return bool(game.arches.inside(p,0.0))

## Lines by record name, kept while its node stands: {id (the node's
## instance id), lines}.
static var _kept := {}

## `lines`, kept for the record's node (a race plans from them again).
static func lines_of(game: Node, r: Dictionary) -> Array:
	var name := String(r.name)
	var id := (r.node as Node).get_instance_id()
	var had: Variant = _kept.get(name)
	if had != null and int((had as Dictionary).id) == id: return (had as Dictionary).lines
	if _kept.size() > 128: _kept.clear()
	var ls := lines(game,r)
	_kept[name] = {"id":id,"lines":ls}
	return ls

## The lines of record `r` the rival may take (the header).
static func lines(game: Node, r: Dictionary) -> Array:
	var ops := openings(game,r)
	var gates: Array = []
	var knives: Array = []
	var span: float = WorldScale.span
	for o: Dictionary in ops:
		var s: Vector3 = o.size
		if bool(o.knife): knives.append(o)
		elif bool(o.lane): continue
		elif s.x >= span*WIDE and (s.y >= span*TALL or bool(o.get("open_top",false))): gates.append(o)
	var out: Array = []
	var seen := {}
	for g: Dictionary in gates:
		var way := _way(g)
		# Every gate on g's line, sorted along it.
		var on: Array = []
		for q: Dictionary in gates:
			if q == g or _on_line(g,way,q): on.append(q)
		on.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.f as Transform3D).origin.dot(way) < (b.f as Transform3D).origin.dot(way))
		# A line through gates open overhead (the colosseum's trench) is also
		# flown without them, level over them (the arena skimmed).
		var ways: Array = [on]
		var open: Array = on.filter(func(q: Dictionary) -> bool: return bool(q.get("open_top",false)))
		if not open.is_empty() and open.size() < on.size():
			ways.append(on.filter(func(q: Dictionary) -> bool: return not bool(q.get("open_top",false))))
		for these: Array in ways:
			var line := _line(game,r,these,way,knives,seen)
			if not line.is_empty(): out.append(line)
	return out

## The line through gates `on` (sorted along `way`), or {} when it is one
## already `seen`, unsteady, through a knife slot or not clear (`lines`).
static func _line(game: Node, r: Dictionary, on: Array, way: Vector3, knives: Array, seen: Dictionary) -> Dictionary:
	var names: Array = on.map(func(q: Dictionary) -> String: return String(q.name))
	names.sort()
	var key := ",".join(names)
	if seen.has(key): return {}
	seen[key] = true
	var row := _heights(on)
	if not _steady(row,way): return {}
	# A knife slot on the way (its way along the line's, the line inside
	# its box) puts it out; one crossed side on (the buttress slots' lane
	# down a flank, crossed in a bay) is left to the clear check.
	for k: Dictionary in knives:
		if absf(_way(k).dot(way)) >= 0.7 and _crosses(row,way,k): return {}
	var room := INF
	var by := ""
	for q: Dictionary in on:
		room = minf(room,(q.size as Vector3).x*0.5)
		if by == "" and bool(q.get("open_top",false)): by = "_by_"+String(q.name).get_file()
	var line := {"id":"%s/%s%s" % [String(r.name),String(row[0].name).get_file(),by],"kind":"set" if (r.spec as Dictionary).has("set") else "bridge",
		"gates":row,"way":way,"room":room}
	if not _clear(game,line): return {}
	return line

## Gates `on` as a line's rows (the header), each flown at one height
## where it can be: the gates' middles' mean, kept MARGIN wingspans inside
## each box (its head counted to HEAD_AIM), so a line is as level as its
## gates let it be; a gate too low for the margin flown at its middle.
static func _heights(on: Array) -> Array:
	var m: float = WorldScale.span*MARGIN
	var mean := 0.0
	var lo := -INF
	var hi := INF
	for q: Dictionary in on:
		var f: Transform3D = q.f
		var h: Vector3 = (q.size as Vector3)*0.5
		mean += f.origin.y/on.size()
		lo = maxf(lo,f.origin.y-h.y+m)
		hi = minf(hi,f.origin.y+h.y+float(q.head)*HEAD_AIM-m)
	var y := clampf(mean,lo,hi) if lo <= hi else mean
	var row: Array = []
	for q: Dictionary in on:
		var f: Transform3D = q.f
		var h: Vector3 = (q.size as Vector3)*0.5
		var a := f.origin.y-h.y+m
		var b := f.origin.y+h.y+float(q.head)*HEAD_AIM-m
		var c := f.origin
		c.y = clampf(y,a,b) if a <= b else f.origin.y+float(q.head)*HEAD_AIM
		row.append({"name":String(q.name),"c":c,"half":h,"head":float(q.head),"lo":f.origin.y-h.y,"hi":f.origin.y+h.y+float(q.head),"f":f,"size":q.size})
	return row

## Gate `o`'s way through, flat (world XZ, unit).
static func _way(o: Dictionary) -> Vector3:
	var z := (o.f as Transform3D).basis.z
	return Vector3(z.x,0.0,z.z).normalized()

## Whether gate `q` is on gate `g`'s line going `way`.
static func _on_line(g: Dictionary, way: Vector3, q: Dictionary) -> bool:
	if absf(_way(q).dot(way)) < ALIGN: return false
	var d: Vector3 = (q.f as Transform3D).origin-(g.f as Transform3D).origin
	var across := way.cross(Vector3.UP)
	if absf(d.dot(across)) > CROSS: return false
	# One over the other (the belfry over the tracery) is two lines.
	var gy := _span_y(g)
	var qy := _span_y(q)
	return gy.x < qy.y and qy.x < gy.y

## Gate `o`'s floor and top (its head counted to HEAD_AIM), world y.
static func _span_y(o: Dictionary) -> Vector2:
	var f: Transform3D = o.f
	var h := float((o.size as Vector3).y)*0.5
	return Vector2(f.origin.y-h,f.origin.y+h+float(o.head)*HEAD_AIM)

## No rise between two gates steeper than SLOPE.
static func _steady(on: Array, way: Vector3) -> bool:
	for i in range(1,on.size()):
		var a: Vector3 = on[i-1].c
		var b: Vector3 = on[i].c
		var run := absf((b-a).dot(way))
		if run > 0.5 and absf(b.y-a.y)/run > SLOPE: return false
	return true

## Whether the line through gates `on` passes inside opening `k`'s box.
static func _crosses(on: Array, way: Vector3, k: Dictionary) -> bool:
	var inv := (k.f as Transform3D).affine_inverse()
	var h: Vector3 = (k.size as Vector3)*0.5
	var a: Vector3 = (on[0].c as Vector3)-way*60.0
	var b: Vector3 = (on[on.size()-1].c as Vector3)+way*60.0
	var n := ceili(a.distance_to(b)/0.5)
	for i in range(n+1):
		var l := inv*a.lerp(b,float(i)/n)
		if absf(l.x) <= h.x+1.0 and absf(l.y) <= h.y+1.0 and absf(l.z) <= h.z: return true
	return false

## Whether the rival's middle line through `line` keeps out of the flight's
## solid (padded by half a wingspan) and over the land, from IN m before its
## first gate to OUT m past its last (the longer of the two each end, as it
## is flown both ways).
static func _clear(game: Node, line: Dictionary) -> bool:
	var gates: Array = line.gates
	var way: Vector3 = line.way
	var pad: float = WorldScale.span*0.5
	var pts: Array = []
	var g0: Dictionary = gates[0]
	var g1: Dictionary = gates[gates.size()-1]
	pts.append((g0.c as Vector3)-way*((g0.half as Vector3).z+maxf(IN,OUT)))
	for g: Dictionary in gates:
		pts.append((g.c as Vector3)-way*(g.half as Vector3).z)
		pts.append((g.c as Vector3)+way*(g.half as Vector3).z)
	pts.append((g1.c as Vector3)+way*((g1.half as Vector3).z+maxf(IN,OUT)))
	for i in range(1,pts.size()):
		var a: Vector3 = pts[i-1]
		var b: Vector3 = pts[i]
		var n := maxi(1,ceili(a.distance_to(b)/CLEAR_STEP))
		for k in range(n+1):
			var p := a.lerp(b,float(k)/n)
			if float(game.field.height(p.x,p.z))+1.0 > p.y:
				blocked = {"at":p,"what":"land","line":line.id}
				return false
			if bool(game.arches.inside(p,pad)):
				blocked = {"at":p,"what":"stone","line":line.id}
				return false
	return true
