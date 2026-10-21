extends RefCounted
## Where the endless land's arches stand (docs/design/endless-flight/
## arches-handoff.md): a pure function of the seed and a world cell, read
## from the land's shape (scripts/endless/land_field.gd `shape`), so every
## run and every worker places the same arches. `plan(field, cx, cz)` gives
## the cell's arches as specs, which scripts/endless/arch_build.gd builds.
##
## Kinds:
##   rock     a natural span on a range's flank or crest, its legs on
##            ground of about one height (its span across the slope's
##            contour), opening faced up and down the slope. Single,
##            tall and narrow, wide and low, or a double.
##   narrows  a rock span across a valley where it runs narrow through a
##            range, its legs up the valley's sides, flown down the valley.
##   aqueduct a ruined aqueduct run (RuinKit) across a valley's floor
##            through the hills, its arches flown along the valley.
##   gate     a RuinKit arch, or a short broken run, at a lowland
##            meadow's edge (not on the meadow's flat).
## Every opening is sized from a toy width (WorldScale.opening). Each spec
## names its arch `endless/arch/<cx>_<cz>/<i>` (scripts/layout_overrides.gd).
##
## A spec: {name, kind, seed, pos (world, at the ground), yaw (local +x
## along Basis(UP,yaw)), ...the kind's sizes, foot: [[centre XZ, half XZ,
## yaw], ...] the parts that stand on the ground (for the flats check)}.

const WorldScale = preload("res://scripts/world_scale.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

## The world cell (m) and the candidate spots tried in each, at density 1.
const CELL := 480.0
const TRIES := 6
## At most this many arches a cell, and at least this far apart (m).
const MOST := 2
const APART := 200.0
## Kept this far inside the cell (m), so a cell's arches stay its own.
const MARGIN := 40.0
## The chance a fitting spot takes an arch, by kind.
const TAKE := {"rock":0.55,"narrows":1.0,"aqueduct":0.75,"gate":0.45}
## Toy widths of the rock openings: single (a range), tall and narrow
## (the tight one), wide and low.
const TOY_ROCK := Vector2(8.0,13.0)
const TOY_TALL := Vector2(5.0,6.5)
const TOY_WIDE := Vector2(14.0,22.0)
## The ruins' openings (toy): the aqueduct's and the gate's. The kit's own
## (4.7 and 4.2) is the tight one; the rest scale the piece up to fit.
const TOY_RUIN := [4.7,6.5,6.5,8.0]
const TOY_GATE := [4.2,6.0,7.0]
## An aqueduct run's most arches; a wider floor grows them up to RUIN_GROW x.
const RUN_MOST := 5
const RUIN_GROW := 2.4
## The rise a narrows' legs climb to (m over the floor), the most it spans.
const NARROW_RISE := Vector2(12.0,28.0)
const NARROW_MOST := 340.0

## The cell's key for a world XZ point.
static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## The arches of cell (cx, cz) on `field`'s land, `density` x as many
## tries, `rock`/`ruin` x the chance a fitting spot takes a rock or a
## ruin arch (0: none of that family).
static func plan(field: RefCounted, cx: int, cz: int, density := 1.0, rock := 1.0, ruin := 1.0) -> Array:
	var out: Array = []
	if density <= 0.0: return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),cx,cz,"endless arches"])
	var tries := int(round(TRIES*density))
	var taken: Array = []
	for t in range(tries):
		var x := (cx+0.0)*CELL+rng.randf_range(MARGIN,CELL-MARGIN)
		var z := (cz+0.0)*CELL+rng.randf_range(MARGIN,CELL-MARGIN)
		var roll := rng.randf()
		var pick := rng.randi()
		if taken.size() >= MOST: break
		var near := false
		for p: Vector2 in taken:
			if p.distance_to(Vector2(x,z)) < APART: near = true
		if near: continue
		var s: Dictionary = field.shape(x,z)
		if float(s.height) < -38.0: continue
		var m := float(s.mountain)
		var v := float(s.valley)
		var half := float(s.half)
		var spec := {}
		var sub := RandomNumberGenerator.new()
		sub.seed = pick
		if v < half*0.6 and m > 0.15 and half < WorldScale.opening(50.0)*0.5*1.3:
			if roll < TAKE.narrows*rock: spec = _narrows(field,x,z,s,sub)
		elif m > 0.22 and m < 0.95 and v > half+float(s.side)*0.35:
			if roll < TAKE.rock*rock: spec = _rock(field,x,z,sub)
		elif v < half*0.5 and m < 0.15 and float(s.inland) > 0.9:
			if roll < TAKE.aqueduct*ruin: spec = _aqueduct(field,x,z,s,sub)
		elif float(s.meadow) > 0.06 and float(s.meadow) < 0.7 and m < 0.1 and v > half+30.0 and float(s.inland) > 0.8:
			if roll < TAKE.gate*ruin: spec = _gate(field,x,z,sub)
		if spec.is_empty(): continue
		spec["name"] = "endless/arch/%d_%d/%d" % [cx,cz,out.size()]
		spec["seed"] = pick
		taken.append(Vector2(x,z))
		out.append(spec)
	return out

## The level way at a point: the unit XZ direction along which the ground
## changes least over `reach` m either side.
static func _contour(field: RefCounted, x: float, z: float, reach: float) -> Vector2:
	var gx: float = field.height(x+6.0,z)-field.height(x-6.0,z)
	var gz: float = field.height(x,z+6.0)-field.height(x,z-6.0)
	var g := Vector2(gx,gz)
	if g.length() < 0.01: return Vector2.RIGHT
	var along := Vector2(-g.y,g.x).normalized()
	# Fine-tune over the arch's own reach: the most level of a few ways
	# round the gradient's contour.
	var best := along
	var least := INF
	for k in range(-2,3):
		var d := along.rotated(k*0.2)
		var diff := absf(float(field.height(x+d.x*reach,z+d.y*reach))-float(field.height(x-d.x*reach,z-d.y*reach)))
		if diff < least:
			least = diff
			best = d
	return best

static func _yaw(dir: Vector2) -> float:
	return atan2(-dir.y,dir.x)

## A rock arch on a range: single, tall, wide or double.
static func _rock(field: RefCounted, x: float, z: float, rng: RandomNumberGenerator) -> Dictionary:
	var r := rng.randf()
	var kind := "single"
	var w := 0.0
	var h := 0.0
	if r < 0.22:
		kind = "tall"
		w = WorldScale.opening(rng.randf_range(TOY_TALL.x,TOY_TALL.y))
		h = w*rng.randf_range(1.9,2.6)
	elif r < 0.45:
		kind = "wide"
		w = WorldScale.opening(rng.randf_range(TOY_WIDE.x,TOY_WIDE.y))
		h = w*rng.randf_range(0.42,0.6)
	else:
		w = WorldScale.opening(rng.randf_range(TOY_ROCK.x,TOY_ROCK.y))
		h = w*rng.randf_range(0.85,1.35)
		if r > 0.85: kind = "double"
	var thick := clampf(w*rng.randf_range(0.3,0.42),6.0,20.0)
	var depth := thick*rng.randf_range(1.2,1.9)
	var flare := rng.randf_range(0.8,1.5)
	var leg := thick*0.5*(1.0+flare)
	var reach := w*0.5+leg
	var arches := 2 if kind == "double" else 1
	var span := reach*2.0+(w+leg*1.4)*(arches-1)
	var dir := _contour(field,x,z,span*0.5)
	# Too steep along its own line (the legs' ground apart in height): none.
	var hl: float = field.height(x-dir.x*span*0.5,z-dir.y*span*0.5)
	var hr: float = field.height(x+dir.x*span*0.5,z+dir.y*span*0.5)
	if absf(hl-hr) > maxf(h*0.45,10.0): return {}
	var spec := {"kind":"rock","form":kind,"w":w,"h":h,"thick":thick,"depth":depth,"flare":flare,"arches":arches,
		"pos":Vector3(x,field.height(x,z),z),"yaw":_yaw(dir),"lean":rng.randf_range(-0.12,0.12)}
	spec["foot"] = _rock_feet(spec,span,leg,depth)
	return spec

## A rock span across a valley's narrows.
static func _narrows(field: RefCounted, x: float, z: float, s: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var across: Vector2 = s.across
	var floor_y := float(s.height)
	var rise := rng.randf_range(NARROW_RISE.x,NARROW_RISE.y)
	var reach := [0.0,0.0]
	for side in range(2):
		var sgn := -1.0 if side == 0 else 1.0
		var d := 8.0
		while d < NARROW_MOST*0.5:
			if float(field.height(x+across.x*d*sgn,z+across.y*d*sgn)) >= floor_y+rise: break
			d += 6.0
		if d >= NARROW_MOST*0.5: return {}
		reach[side] = d
	var mid := (float(reach[1])-float(reach[0]))*0.5
	var cx := x+across.x*mid
	var cz := z+across.y*mid
	var a := (float(reach[0])+float(reach[1]))*0.5
	var thick := clampf(a*rng.randf_range(0.17,0.24),10.0,30.0)
	var flare := rng.randf_range(0.4,0.9)
	var leg := thick*0.5*(1.0+flare)
	var w := a*2.0-leg*0.6
	if w < WorldScale.opening(20.0): return {}
	var h := rise+rng.randf_range(12.0,36.0)
	var depth := thick*rng.randf_range(1.1,1.6)
	var spec := {"kind":"rock","form":"narrows","w":w,"h":h,"thick":thick,"depth":depth,"flare":flare,"arches":1,
		"pos":Vector3(cx,field.height(cx,cz),cz),"yaw":_yaw(across),"lean":rng.randf_range(-0.08,0.08)}
	spec["foot"] = _rock_feet(spec,a*2.0+leg*2.0,leg,depth)
	return spec

## A rock arch's feet on the ground (its legs; the whole span when its
## opening stands low).
static func _rock_feet(spec: Dictionary, span: float, leg: float, depth: float) -> Array:
	var yaw := float(spec.yaw)
	var dir := Vector2(cos(yaw),-sin(yaw))
	var at := Vector2(spec.pos.x,spec.pos.z)
	var out: Array = []
	if float(spec.h) < 15.0:
		out.append([at,Vector2(span*0.5+3.0,depth*0.5+3.0),yaw])
		return out
	var n := int(spec.arches)+1
	for i in range(n):
		var t := float(i)/float(n-1)
		out.append([at+dir*lerpf(-span*0.5+leg,span*0.5-leg,t),Vector2(leg+3.0,depth*0.5*1.4+3.0),yaw])
	return out

## The scale a RuinKit piece of kit opening `kit` grows by to `toy`'s.
static func _grow(kit: float, toy: float) -> float:
	return maxf(1.0,WorldScale.opening(toy)/kit)

## A ruined aqueduct across a valley's floor.
static func _aqueduct(field: RefCounted, x: float, z: float, s: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var toy: float = TOY_RUIN[rng.randi()%TOY_RUIN.size()]
	var room := float(s.half)*2.0*0.9
	# A wide floor grows the arches (up to RUIN_GROW) rather than adding
	# more than RUN_MOST of them.
	var grow := clampf(maxf(_grow(Aqueduct.CLEAR,toy),room/(Aqueduct.SPAN*RUN_MOST)),1.0,maxf(RUIN_GROW,_grow(Aqueduct.CLEAR,toy)))
	var span: float = Aqueduct.SPAN*grow
	var across: Vector2 = s.across
	var count := clampi(int(room/span),2,RUN_MOST+1)
	var head := rng.randf() < 0.6
	var length := span*count
	var spec := {"kind":"aqueduct","grow":grow,"count":count,"head":head,"break_at":(rng.randi_range(1,count-1) if rng.randf() < 0.45 else -1),
		"weathered":rng.randf_range(0.2,0.6),"yaw":_yaw(across),"length":length}
	spec["pos"] = _level(field,x,z,across,length*0.5,2.8*grow)
	spec["foot"] = [[Vector2(x,z),Vector2(length*0.5+6.0*grow,3.0*grow+4.0),float(spec.yaw)]]
	return spec

## A RuinKit arch (or a short broken run) at a meadow's edge.
static func _gate(field: RefCounted, x: float, z: float, rng: RandomNumberGenerator) -> Dictionary:
	var dir := _contour(field,x,z,12.0)
	var spec := {}
	if rng.randf() < 0.55:
		var toy: float = TOY_GATE[rng.randi()%TOY_GATE.size()]
		var grow := _grow(RuinKit.ARCH_SPAN,toy)
		var foot := RuinKit.arch_foot()*grow
		spec = {"kind":"gate","grow":grow,"weathered":rng.randf_range(0.2,0.8),"yaw":_yaw(dir)}
		spec["pos"] = _level(field,x,z,dir,foot.x,foot.y)
		spec["foot"] = [[Vector2(x,z),foot+Vector2(4.0,4.0),float(spec.yaw)]]
	else:
		var toy: float = TOY_RUIN[rng.randi()%TOY_RUIN.size()]
		var grow := _grow(Aqueduct.CLEAR,toy)
		var count := rng.randi_range(2,4)
		var length: float = Aqueduct.SPAN*grow*count
		spec = {"kind":"aqueduct","grow":grow,"count":count,"head":false,"break_at":count-1,
			"weathered":rng.randf_range(0.3,0.7),"yaw":_yaw(dir),"length":length}
		spec["pos"] = _level(field,x,z,dir,length*0.5,2.8*grow)
		spec["foot"] = [[Vector2(x,z),Vector2(length*0.5+6.0*grow,3.0*grow+4.0),float(spec.yaw)]]
	return spec

## The piece's ground: the highest ground under its line (half length
## `along`, half depth `deep`), so it stands on it with nothing buried.
static func _level(field: RefCounted, x: float, z: float, dir: Vector2, along: float, deep: float) -> Vector3:
	var top := -INF
	var side := Vector2(-dir.y,dir.x)
	var n := maxi(2,int(along/4.0))
	for i in range(-n,n+1):
		var t := float(i)/n*along
		for k: float in [-1.0,0.0,1.0]:
			var p := Vector2(x,z)+dir*t+side*deep*k
			top = maxf(top,float(field.height(p.x,p.y)))
	return Vector3(x,top,z)
