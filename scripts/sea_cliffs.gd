extends RefCounted
## A sea-cliff island (a SkyIslet recipe's `cliffs`, scripts/sky_islet.gd;
## the lower world's cliffs landform, scripts/landform_cliffs.gd): a grassy
## tableland whose edges drop in tall, layered rock walls straight to the
## sea, Hebrides or Faroe fashion. The islet's frame keeps its own rule: the
## shore's rim near RIM_HEIGHT, here just over the sea (SEA), and the land
## lifted off it. Five pieces, each hooked into the islet once:
##   `carve` (after the outline): sea stacks stood off the cliffs, each a
##     lobed little island of its own in the outline a flight's gap off the
##     shore (STACK, GAP), and an arch: a stack joined back to the cliff by
##     a bridge of rock (ARCH); and the cove picked, the most sheltered bay
##     on the low side;
##   `lift` (on the ground, after the islet's own small erosion, so the
##     big shape stays green rather than scoured): the tableland, high on
##     one side and lower on the other (the recipe's `height` and `low`),
##     rolling, a knoll on its high side, and coming down to the cove in a
##     broad glen (COVE) so the land meets the sea there on a beach; the
##     stacks' flat tops, a little under the cliff beside them; the
##     bridge's top running from the cliff to its stack;
##   `hollow` (on the rock): the arch's span opened from the sea up to its
##     soffit, an arched crown under the bridge (the islet's `underside`
##     reads it, so the glide flies through);
##   `side_arrays` (the walls): the islands' shore wall grown tall, in
##     strata: every shore point hangs a column of rings from its rim to the
##     foot, broken at the bed boundaries (BEDS, flat across the island, a
##     whole number of the earth sides' core beds high, so the shader's
##     bands and the facets agree); a hard bed stands out of the soft ones
##     under it in a ledge, a soft one is undercut under a hard cap
##     (BED_OUT); the face leans out a little toward the foot (BATTER),
##     stands out in buttresses and sinks in gullies along the shore
##     (COLUMN), and is notched where the sea works it (NOTCH). Neighbouring
##     columns are stitched rim to foot whatever their rings, so a wall
##     tapers to nothing round the cove and stays whole;
##   `beach` (the top's colour): sand and shingle round the cove's water.
## Built on the islets' own wall and rock (scripts/island_shore.gd `_add`,
## `_outward`) and drawn in the islets' earth-sides material and rock looks
## (scripts/rock_looks.gd, with `bed` set to BEDS' unit), so the cliffs are
## the sky's own rock, only taller.

const IslandShore = preload("res://scripts/island_shore.gd")
const IslandOutline = preload("res://scripts/island_outline.gd")
const PlateMesh = preload("res://scripts/plate_mesh.gd")

## The sea's level in the islet's frame (m): the cove's beach meets it and
## the walls' notch is cut at it.
const SEA := 0.0
## The tableland: its high side's height over the sea comes in the recipe;
## the low side stands this share of it. The roll (share of the height,
## over waves this share of the radius long) and the knoll on the high side
## (share of the height, its reach a share of the radius).
const ROLL := Vector2(0.07,0.7)
const KNOLL := Vector2(0.12,0.28)
const KNOLL_REACH := Vector2(0.3,0.45)
## The cove: its glen reaches this share of the radius in (at least
## COVE_RISE m a metre of height it comes down, at most COVE_MOST of the
## radius), the beach the inner share of it; sand on ground under
## BEACH_TOP m over the sea.
const COVE := Vector2(0.55,0.75)
const COVE_RISE := 2.2
const COVE_MOST := 1.2
const GLEN_ACROSS := 0.6
const BEACH_SHARE := 0.28
const BEACH_TOP := 1.1
## Grass holds on the top's slopes up to this steep (rise over run), a
## shade darker (STEEP_SHADE); steeper is the world's rock.
const STEEP_GRASS := 1.6
const STEEP_SHADE := 0.85
## Everything stands this much higher (m), so the beach's rim, slumped and
## weathered, still meets the sea over its level.
const FLOOR := 0.4
## Sea stacks: radius (m, times the island's size share), the gap to the
## cliff (m, a flight between), how much each stands under the cliff beside
## it (share), its lobes (share of its radius).
const STACK := Vector2(2.6,5.0)
const GAP := Vector2(6.0,12.0)
const STACK_TOP := Vector2(0.6,0.95)
const STACK_LOBE := 0.2
## The arch: the span from the cliff to its stack (m), the bridge's half
## width (m), its crown over the sea (share of the lower top, keeping
## ARCH_ROOF m of rock over it).
const ARCH_SPAN := Vector2(7.0,11.0)
const ARCH_HALF := Vector2(2.2,3.0)
const ARCH_CROWN := Vector2(0.45,0.62)
const ARCH_ROOF := 3.5
## The walls. The beds: each a whole number of BED units high (the recipe's
## `bed` m), by weight, each hard or soft; a hard bed stands BED_OUT.x m out
## of the mean face, a soft one sinks BED_OUT.y m in; a boundary is a step
## BED_STEP m high. A bed taller than BED_SPLIT m has a ring part way down.
const BEDS := [[1,0.35],[2,0.4],[3,0.25]]
const BED_OUT := Vector2(0.55,-0.35)
const BED_STEP := 0.18
const BED_SPLIT := 2.6
## The face leans out this far a metre down; buttresses stand out and
## gullies sink in by up to COLUMN m, over waves COLUMN_WAVE (1/m); each
## ring's point wanders JITTER m more.
const BATTER := 0.02
const COLUMN := 0.85
const COLUMN_WAVE := 0.16
const JITTER := 0.14
## Each bed wanders in and out along the shore by up to BED_WANDER m, over
## waves BED_WAVE times the buttresses' length.
const BED_WANDER := 0.5
const BED_WAVE := 1.6
## Each ring's point slips along the shore by up to this share of the
## grid's step, and the bed boundaries wander up and down by BED_SWAY m
## along the shore.
const SLIP := 0.3
const BED_SWAY := 0.4
## The brow: the turf's lip, this far under the rim (m), standing out
## (m); the wave-cut notch at the sea (its top over SEA, its depth in), and
## the foot's talus (m out).
const BROW := Vector2(0.35,0.8)
const BROW_OUT := Vector2(-0.05,0.25)
const NOTCH := Vector2(0.9,0.55)
const TALUS := 0.5
## Rings closer than this (m) to the last are let go.
const RING_GAP := 0.3
## The cove's driftwood, stones and bank grass: how many of each.
const DRIFT := Vector2i(1,3)
const BEACH_STONES := Vector2i(2,5)
const BANK := Vector2i(5,10)

var seed := 0
## The islet's radius (m).
var radius := 20.0
## The tableland: its high and low sides' heights over the sea (m), the
## way to the high side, the knoll (x, z, reach, height).
var high := 24.0
var low := 12.0
var tilt := Vector2.RIGHT
var knoll := Vector4.ZERO
## The cove: its shore point, its way out to sea, its glen's reach (m);
## no cove with zero reach.
var cove := Vector2.ZERO
var cove_out := Vector2.ZERO
var cove_reach := 0.0
## The stacks: (x, z, radius, top over the sea), and their lobes' phases.
var stacks: Array[Vector4] = []
var lobes: Array[Vector2] = []
## The arch, empty if none: {from (the cliff's shore point), out (its way
## out), to (the stack's middle), span (m), half (the bridge's half width),
## stack (its index in `stacks`), crown (m over the sea)}.
var arch := {}
## Each grid point's part: 0 off the land, 1 the island, 2 a stack, 3 the
## arch's bridge.
var part := PackedByteArray()
## The beds' floors over the sea (m), bottom up, and each bed's hardness
## (0 soft to 1 hard); the unit (m).
var floors := PackedFloat32Array()
var hardness := PackedFloat32Array()
var bed := 1.8
var _roll: FastNoiseLite
var _lean: FastNoiseLite
var _patch: FastNoiseLite

## The cliffs for `islet`, its outline just made: stacks and the arch added
## to the outline, the cove picked, its shore worked out again.
static func carve(islet: RefCounted) -> RefCounted:
	var made: RefCounted = new()
	made._carve(islet)
	return made

func _carve(islet: RefCounted) -> void:
	seed = int(islet.seed)
	var spec: Dictionary = islet.recipe.cliffs
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,"sea cliffs"])
	high = float(spec.get("height",24.0))
	low = high*float(spec.get("low",0.5))
	bed = float(spec.get("bed",1.8))
	tilt = Vector2.from_angle(float(spec.get("tilt",rng.randf()*TAU)))
	radius = islet.radius
	_noises()
	var size := clampf((radius-15.0)/30.0,0.0,1.0)
	var points: PackedVector2Array = islet.points
	var outward: Dictionary = IslandShore._outward(points,islet.shore_edges)
	var shore: Array = outward.keys()
	shore.sort()
	# The cove: the most sheltered bay on the low side.
	if spec.get("cove",true):
		var best := -INF
		for i: int in shore:
			var p := points[i]
			var score := -p.dot(tilt)/radius-p.length()/radius*0.8+rng.randf()*0.15
			if score > best:
				best = score
				cove = p
				cove_out = outward[i]
		cove_reach = minf(maxf(radius*rng.randf_range(COVE.x,COVE.y),_table(cove,false)*COVE_RISE),radius*COVE_MOST)
	var knoll_at := tilt.rotated(rng.randf_range(-0.6,0.6))*radius*rng.randf_range(0.2,0.45)
	knoll = Vector4(knoll_at.x,knoll_at.y,radius*rng.randf_range(KNOLL_REACH.x,KNOLL_REACH.y),high*rng.randf_range(KNOLL.x,KNOLL.y))
	# Shore points a stack or the arch may stand off: away from the cove,
	# not on the low side's far end, in a seeded order.
	var spots: Array = []
	for i: int in shore:
		var p := points[i]
		if cove_reach > 0.0 and p.distance_to(cove) < cove_reach*1.15: continue
		if p.dot(tilt)/radius < -0.45: continue
		spots.append([rng.randf(),i])
	spots.sort()
	var room: float = islet.half-2.0*float(islet.step)
	var taken: Array[Vector3] = []
	# The arch first: it wants a straight bit of cliff.
	if spec.get("arch",false):
		for entry: Array in spots:
			var i: int = entry[1]
			var from := points[i]
			var out: Vector2 = outward[i]
			var span := rng.randf_range(ARCH_SPAN.x,ARCH_SPAN.y)
			var r := rng.randf_range(STACK.x,STACK.y)*lerpf(1.0,1.25,size)
			var to := from+out*(span+r)
			if not _clear(to,r,span*0.75,points,shore,from,span*0.9,taken,room): continue
			stacks.append(Vector4(to.x,to.y,r,0.0))
			lobes.append(Vector2(rng.randf()*TAU,rng.randf()*TAU))
			arch = {"from":from,"out":out,"to":to,"span":span,"half":rng.randf_range(ARCH_HALF.x,ARCH_HALF.y),"stack":stacks.size()-1,
				"crown":rng.randf_range(ARCH_CROWN.x,ARCH_CROWN.y)}
			taken.append(Vector3(to.x,to.y,r+span))
			break
	var want := int(spec.get("stacks",2))
	for entry: Array in spots:
		if stacks.size()-(1 if not arch.is_empty() else 0) >= want: break
		var i: int = entry[1]
		var out: Vector2 = outward[i]
		var r := rng.randf_range(STACK.x,STACK.y)*lerpf(0.85,1.3,size)
		var gap := rng.randf_range(GAP.x,GAP.y)
		var at: Vector2 = points[i]+out.rotated(rng.randf_range(-0.35,0.35))*(gap+r)
		if not _clear(at,r,gap*0.85,points,shore,Vector2.INF,0.0,taken,room): continue
		stacks.append(Vector4(at.x,at.y,r,0.0))
		lobes.append(Vector2(rng.randf()*TAU,rng.randf()*TAU))
		taken.append(Vector3(at.x,at.y,r+gap))
	# Each stack's top: a share of the cliff beside it, the arch's stack a
	# little under the cliff it is joined to.
	for k in range(stacks.size()):
		var s := stacks[k]
		var beside := _table(Vector2(s.x,s.y)-Vector2(s.x,s.y).normalized()*(s.z+GAP.x),true)
		var share := rng.randf_range(0.85,0.95) if not arch.is_empty() and k == int(arch.stack) else rng.randf_range(STACK_TOP.x,STACK_TOP.y)
		stacks[k] = Vector4(s.x,s.y,s.z,maxf(beside*share,4.0))
	if not arch.is_empty():
		var top := minf(_table(arch.from,true),stacks[int(arch.stack)].w)
		arch.crown = minf(top*float(arch.crown),top-ARCH_ROOF)
		if arch.crown < 4.0: arch = {}
	_mark(islet)
	islet.shore_distance = IslandOutline.shore_distance(points,islet.ids,islet.outline)
	islet.shore_edges = IslandOutline.shore_edges(islet.ids,islet.outline)
	_beds(rng)
	_dress_recipe(islet,rng)

## True if a stack of radius `r` at `at` stands `gap` m clear of the shore
## (but the shore within `near` of `except`, where an arch joins), off the
## others in `taken`, and inside `room` of the grid.
func _clear(at: Vector2, r: float, gap: float, points: PackedVector2Array, shore: Array, except: Vector2, near: float, taken: Array[Vector3], room: float) -> bool:
	if absf(at.x)+r*(1.0+STACK_LOBE) > room or absf(at.y)+r*(1.0+STACK_LOBE) > room: return false
	for t in taken:
		if at.distance_to(Vector2(t.x,t.y)) < t.z+r+gap*0.5: return false
	for i: int in shore:
		var p := points[i]
		if except != Vector2.INF and p.distance_to(except) < near: continue
		if p.distance_to(at) < r*(1.0+STACK_LOBE)+gap: return false
	return true

## The stacks' and the bridge's faces laid into the outline, and every
## point's part.
func _mark(islet: RefCounted) -> void:
	var points: PackedVector2Array = islet.points
	var ids: PackedInt32Array = islet.ids
	var outline: PackedByteArray = islet.outline
	var faces := outline.size()
	# The part of each face: 1 the island's own, 2 a stack, 3 the bridge.
	var parts := PackedByteArray()
	parts.resize(faces)
	for f in range(faces):
		if outline[f] == 0:
			parts[f] = 1
			continue
		var c := (points[ids[f*3]]+points[ids[f*3+1]]+points[ids[f*3+2]])/3.0
		if _in_stack(c) >= 0: parts[f] = 2
		elif _on_bridge(c): parts[f] = 3
		if parts[f] != 0: outline[f] = 0
	islet.outline = outline
	part.resize(points.size())
	part.fill(0)
	for f in range(faces):
		if parts[f] == 0: continue
		for k in range(3):
			var i := ids[f*3+k]
			if part[i] == 0 or parts[f] < part[i]: part[i] = parts[f]

## The stack holding `p` (its lobed outline), or -1.
func _in_stack(p: Vector2) -> int:
	for k in range(stacks.size()):
		var s := stacks[k]
		var d := p-Vector2(s.x,s.y)
		var a := d.angle()
		var lobe := lobes[k]
		var r := s.z*(1.0+STACK_LOBE*(0.6*sin(3.0*a+lobe.x)+0.4*sin(5.0*a+lobe.y)))
		if d.length() <= r: return k
	return -1

## True on the arch's bridge: within its half width of the line from a
## little inside the cliff to its stack's middle.
func _on_bridge(p: Vector2) -> bool:
	if arch.is_empty(): return false
	var from: Vector2 = arch.from-(arch.out as Vector2)*2.0
	var way: Vector2 = arch.to-from
	var t := clampf((p-from).dot(way)/way.length_squared(),0.0,1.0)
	return p.distance_to(from+way*t) <= float(arch.half)

## How far along the arch's open span `p` is: 0 at the cliff's face, 1 at
## the stack's.
func _along(p: Vector2) -> float:
	var span: float = arch.span
	return clampf((p-(arch.from as Vector2)).dot(arch.out)/span,0.0,1.0)

## The beds up the walls, from the foot to over the highest top: each a
## whole number of units, hard or soft, hard beds never two alike in a row
## for long.
func _beds(rng: RandomNumberGenerator) -> void:
	var y := SEA
	var top := high+knoll.w+2.0
	floors.clear()
	hardness.clear()
	var hard := rng.randf() < 0.5
	while y < top:
		floors.append(y)
		hardness.append(rng.randf_range(0.65,1.0) if hard else rng.randf_range(0.0,0.35))
		var roll := rng.randf()
		var units := 1
		for b: Array in BEDS:
			roll -= float(b[1])
			if roll <= 0.0:
				units = int(b[0])
				break
		y += units*bed
		hard = not hard if rng.randf() < 0.75 else hard

## What the recipe wants kept clear (the stacks, the bridge: grass only),
## and what lies on the cove's beach: driftwood, stones, bank grass.
func _dress_recipe(islet: RefCounted, rng: RandomNumberGenerator) -> void:
	var recipe: Dictionary = (islet.recipe as Dictionary).duplicate()
	var clear: Array = (recipe.get("clear",[]) as Array).duplicate()
	for s in stacks: clear.append(Vector3(s.x,s.y,s.z*(1.0+STACK_LOBE)+1.0))
	if not arch.is_empty():
		var middle: Vector2 = ((arch.from as Vector2)+(arch.to as Vector2))*0.5
		clear.append(Vector3(middle.x,middle.y,float(arch.span)*0.5+float(arch.half)))
	recipe.clear = clear
	var objects: Array = (recipe.get("objects",[]) as Array).duplicate()
	if cove_reach > 0.0:
		var inward := -cove_out
		var across := Vector2(-inward.y,inward.x)
		var beach := cove_reach*BEACH_SHARE
		var lay := func(asset: String, depth: Vector2, size: Vector2) -> void:
			var at := cove+inward*rng.randf_range(depth.x,depth.y)*beach+across*rng.randf_range(-0.8,0.8)*beach
			objects.append({"asset":asset,"x":at.x,"z":at.y,"angle":rng.randf()*TAU,"scale":rng.randf_range(size.x,size.y),"inset":0.6})
		for n in range(rng.randi_range(DRIFT.x,DRIFT.y)): lay.call("log",Vector2(0.15,0.6),Vector2(0.7,1.0))
		for n in range(rng.randi_range(BEACH_STONES.x,BEACH_STONES.y)): lay.call(["boulder_1","boulder_2","boulder_3","rock"][rng.randi() % 4],Vector2(0.1,0.9),Vector2(0.35,0.9))
		for n in range(rng.randi_range(BANK.x,BANK.y)): lay.call("bank_grass",Vector2(0.75,1.2),Vector2(0.7,1.1))
	recipe.objects = objects
	islet.recipe = recipe

func _noises() -> void:
	_roll = FastNoiseLite.new()
	_roll.seed = seed+211
	_roll.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_roll.fractal_octaves = 2
	_roll.frequency = 1.0/(radius*ROLL.y)
	_lean = FastNoiseLite.new()
	_lean.seed = seed+223
	_lean.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_lean.frequency = COLUMN_WAVE
	_lean.fractal_octaves = 2
	_patch = FastNoiseLite.new()
	_patch.seed = seed+227
	_patch.frequency = 0.35

# --- The ground -----------------------------------------------------------------

## The tableland's height over the sea at `p` (m): low side to high, rolling,
## the knoll; with `glen`, brought down to the cove.
func _table(p: Vector2, glen: bool) -> float:
	var s := p.dot(tilt)/maxf(radius,1.0)
	var h := lerpf(low,high,smoothstep(-1.0,1.0,s))
	h += _roll.get_noise_2d(p.x,p.y)*ROLL.x*high
	if knoll.z > 0.0:
		var r := p.distance_to(Vector2(knoll.x,knoll.y))/knoll.z
		if r < 1.0: h += knoll.w*(1.0-r*r)*(1.0-r*r)
	if glen and cove_reach > 0.0:
		# The glen opens wide across the cove's mouth (GLEN_ACROSS), a broad
		# side coming down rather than a cleft.
		var off := p-cove
		var d := Vector2(off.dot(cove_out),off.dot(cove_out.orthogonal())*GLEN_ACROSS).length()
		d += _roll.get_noise_2d(p.x+91.0,p.y-37.0)*cove_reach*0.12
		# Gentle at the beach, steepening up the glen, eased into the top.
		var u := clampf((d-cove_reach*BEACH_SHARE)/(cove_reach*(1.0-BEACH_SHARE)),0.0,1.0)
		h *= lerpf(u*u,smoothstep(0.0,1.0,u),0.6)
	return h

## Lifts the islet's ground (its rim near RIM_HEIGHT, just over the sea) to
## the tableland, the stacks' tops and the bridge.
func lift(islet: RefCounted) -> void:
	var points: PackedVector2Array = islet.points
	var heights: PackedFloat32Array = islet.heights
	var distance: PackedFloat32Array = islet.shore_distance
	for i in range(points.size()):
		if distance[i] < 0.0: continue
		var p := points[i]
		var up := 0.0
		match part[i]:
			2:
				var k := _nearest_stack(p)
				var s := stacks[k]
				up = s.w+0.25*(1.0-minf(p.distance_to(Vector2(s.x,s.y))/s.z,1.0))
			3:
				var t := smoothstep(0.0,1.0,_along(p))
				up = lerpf(_table(arch.from,true),stacks[int(arch.stack)].w,t)
			_:
				up = _table(p,true)
		heights[i] += up+FLOOR
	islet.heights = heights

func _nearest_stack(p: Vector2) -> int:
	var best := 0
	var near := INF
	for k in range(stacks.size()):
		var d := p.distance_to(Vector2(stacks[k].x,stacks[k].y))-stacks[k].z
		if d < near:
			near = d
			best = k
	return best

## The arch's span opened under its bridge: the rock's underside raised
## from the sea at either end to its crown in the middle.
func hollow(islet: RefCounted) -> void:
	if arch.is_empty(): return
	var keel: PackedFloat32Array = islet.keel
	var base: float = islet.base
	var points: PackedVector2Array = islet.points
	for i in range(points.size()):
		if part[i] != 3: continue
		var t := _along(islet.points[i])
		var soffit := SEA+float(arch.crown)*pow(sin(PI*clampf(t,0.0,1.0)),0.55)
		keel[i] = minf(keel[i],base-soffit)
	islet.keel = keel

## True where the cliffs paint the top themselves (`paint`): the cove's
## beach, and grass too steep for the world's palette (past `rock_slope`)
## but under STEEP_GRASS, which holds on a sea cliff's slopes.
func paints(at: Vector2, y: float, slope: float, rock_slope: float) -> bool:
	return _beach(at,y) or (slope > rock_slope and slope < STEEP_GRASS)

## The top's colour at `at` (a face `y` up, `slope` steep, `tone` the
## islet's own): the beach sand, shingle in drifts; steep grass a darker
## green of the palette's (`palette` as SkyIslet `top_arrays` takes it).
func paint(at: Vector2, y: float, slope: float, tone: Color, palette: Dictionary) -> Color:
	if _beach(at,y): return palette.gravel if _patch.get_noise_2d(at.x*2.0,at.y*2.0) > 0.2 else palette.sand
	var grass: Array = palette.grass
	return (grass[grass.size()-1] as Color).lerp(tone,0.35)*STEEP_SHADE

func _beach(at: Vector2, y: float) -> bool:
	if cove_reach <= 0.0: return false
	return y < SEA+BEACH_TOP+_patch.get_noise_2d(at.x,at.y)*0.3 and at.distance_to(cove) < cove_reach*BEACH_SHARE*1.6

# --- The walls --------------------------------------------------------------------

## The sides' surface arrays (as SkyIslet `side_arrays` makes them, for the
## earth sides' material): every shore edge's wall, two columns of rings
## (`_column`) stitched rim to foot, and the rock under the land.
func side_arrays(islet: RefCounted) -> Array:
	var into := Transform3D.IDENTITY
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var points: PackedVector2Array = islet.points
	var edges: PackedInt32Array = islet.shore_edges
	var heights: PackedFloat32Array = islet.heights
	var keel: PackedFloat32Array = islet.keel
	var ids: PackedInt32Array = islet.ids
	var base: float = islet.base
	var outward: Dictionary = IslandShore._outward(points,edges)
	var columns := {}
	for k in range(0,edges.size(),3):
		for i in [edges[k],edges[k+1]]:
			if not columns.has(i): columns[i] = _column(islet,i,outward[i])
	for k in range(0,edges.size(),3):
		var a := edges[k]
		var b := edges[k+1]
		var out: Vector2 = ((outward[a] as Vector2)+(outward[b] as Vector2)).normalized()
		var face := Vector3(out.x,0.0,out.y)
		var ha := heights[a]
		var hb := heights[b]
		var ca: Array = columns[a]
		var cb: Array = columns[b]
		# Stitched down: each step takes the next ring of the column whose
		# next ring stands higher.
		var i := 0
		var j := 0
		while i < ca.size()-1 or j < cb.size()-1:
			var down_a := j >= cb.size()-1 or (i < ca.size()-1 and (ca[i+1] as Vector3).y >= (cb[j+1] as Vector3).y)
			if down_a:
				IslandShore._add(vertices,uvs,into,[ca[i],cb[j],ca[i+1]],face,[ha,hb,ha],0.0)
				i += 1
			else:
				IslandShore._add(vertices,uvs,into,[ca[i],cb[j],cb[j+1]],face,[ha,hb,hb],0.0)
				j += 1
	for f: int in islet.land:
		var tri := []
		for k in range(3):
			var i := ids[f*3+k]
			tri.append(Vector3(points[i].x,base-keel[i],points[i].y))
		IslandShore._add(vertices,uvs,into,tri,Vector3.DOWN,[],0.0)
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3): normals[i+j] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays

## Shore point `i`'s column, rim to foot: the rim, the brow's turf lip, two
## rings at each bed boundary between (the bed over it and the bed under
## it, each stood out or in by its hardness), a ring part way down a tall
## bed, the notch at the sea, and the foot with its talus. Every ring is
## stood out along `out` by the column's buttress or gully and the batter.
func _column(islet: RefCounted, i: int, out: Vector2) -> Array:
	var p: Vector2 = islet.points[i]
	var top: float = islet.heights[i]
	var foot: float = float(islet.base)-float(islet.keel[i])
	var salt := seed % 7919
	var lean := _lean.get_noise_2d(p.x,p.y)*COLUMN
	var sway := _lean.get_noise_2d(p.x*0.6+411.0,p.y*0.6-97.0)*BED_SWAY
	var along := out.orthogonal()*float(islet.step)
	# The rings wanted, top down: (height, reach out of the mean face).
	var wanted: Array[Vector2] = []
	var brow := top-lerpf(BROW.x,BROW.y,PlateMesh._hash(i,salt,3))
	wanted.append(Vector2(brow,lerpf(BROW_OUT.x,BROW_OUT.y,PlateMesh._hash(i,salt,5))-lean))
	for b in range(floors.size()-1,0,-1):
		var y := floors[b]+sway
		var over := _bed_out(b,i,p)
		var height := (floors[b+1] if b+1 < floors.size() else high+knoll.w+2.0)-y
		if height > BED_SPLIT: wanted.append(Vector2(y+height*lerpf(0.4,0.6,PlateMesh._hash(i,salt+b,7)),over*0.7))
		wanted.append(Vector2(y+BED_STEP,over))
		wanted.append(Vector2(y-BED_STEP,_bed_out(b-1,i,p)))
	# The notch the sea cuts.
	if top > SEA+NOTCH.x+1.0:
		wanted.append(Vector2(SEA+NOTCH.x,_bed_out(0,i,p)-NOTCH.y))
		wanted.append(Vector2(SEA-0.6,_bed_out(0,i,p)-NOTCH.y*0.4))
	var col: Array = [Vector3(p.x,top,p.y)]
	var last := top
	for w in wanted:
		if w.x > last-RING_GAP or w.x < foot+RING_GAP: continue
		var o := w.y+lean+(top-w.x)*BATTER
		# Each ring's point slips a little along the shore, so no two faces
		# of a bed lie in one plane.
		var slip := along*(PlateMesh._hash(i,salt+col.size()*7,17)-0.5)*2.0*SLIP
		col.append(Vector3(p.x+out.x*o+slip.x,w.x,p.y+out.y*o+slip.y))
		last = w.x
	# The foot: its talus under the sea; under the arch, the soffit's edge.
	var o := _bed_out(0,i,p)+TALUS+lean+(top-foot)*BATTER
	col.append(Vector3(p.x+out.x*o,foot,p.y+out.y*o) if foot < SEA else Vector3(p.x,foot,p.y))
	return col

## Bed `b`'s reach out of the mean face at shore point `i` (at `p`, m): by
## its hardness, wandering in and out along the shore (BED_WANDER, each bed
## on its own wave so the beds run on unbroken), and a little more at the
## point.
func _bed_out(b: int, i: int, p: Vector2) -> float:
	var hard := hardness[clampi(b,0,hardness.size()-1)]
	var wander := _lean.get_noise_2d(p.x*BED_WAVE+b*53.0,p.y*BED_WAVE-b*29.0)*BED_WANDER
	return lerpf(BED_OUT.y,BED_OUT.x,hard)+wander+(PlateMesh._hash(i,seed % 7919+b*13,11)-0.5)*2.0*JITTER
