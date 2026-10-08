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
##     foot, broken at the bed boundaries (BEDS, each its own thickness,
##     dipping across the island and waving, thickening and pinching out
##     along the shore: DIP, WAVE, PINCH); a hard bed stands out of the soft
##     ones in a ledge, a soft one is undercut and notched under a hard cap
##     (BED_OUT, NOTCH_DEEP); the face leans out a little toward the foot
##     (BATTER), stands out in buttresses (COLUMN), breaks into joint blocks
##     (JOINT) and is cut by gullies from the brow down (GULLY); the turf
##     overhangs the top in a lip over bare peat (LIP, PEAT); and it is
##     notched where the sea works it (NOTCH). Neighbouring columns are
##     stitched rim to foot whatever their rings, so a wall tapers to
##     nothing round the cove and stays whole. Each face carries its own
##     colour (`_tint`): its bed's band of the rock look, warmer or cooler
##     in patches, pale streaks down some joints, turf on the lip and the
##     wide ledges, the foot wet and dark;
##   `beach` (the top's colour): sand and shingle round the cove's water.
## Built on the islets' own wall and rock (scripts/island_shore.gd `_add`,
## `_outward`) and drawn in the islets' earth-sides material and rock looks
## (scripts/rock_looks.gd, with `bed` set: the walls' colours their own,
## the shader's `side_painted`), so the cliffs are the sky's own rock, only
## taller.

const IslandShore = preload("res://scripts/island_shore.gd")
const IslandOutline = preload("res://scripts/island_outline.gd")
const PlateMesh = preload("res://scripts/plate_mesh.gd")
const RockLooks = preload("res://scripts/rock_looks.gd")

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
## `bed` m, by weight) drawn THICK times over, so no two are alike, each
## hard or soft; a hard bed stands BED_OUT.x m out of the mean face, a soft
## one sinks BED_OUT.y m in, its hardness wandering by HARD_WANDER along the
## shore so a ledge widens, narrows and fades out; a boundary is a step
## BED_STEP m high. A bed taller than BED_SPLIT m has a ring part way down.
const BEDS := [[1,0.35],[2,0.4],[3,0.25]]
const THICK := Vector2(0.6,1.55)
const BED_OUT := Vector2(0.55,-0.4)
const HARD_WANDER := 0.4
const BED_STEP := 0.18
const BED_SPLIT := 2.6
## The beds' lie: they dip DIP m a metre (drawn within it) toward a seeded
## way and wave up and down WAVE.x m over WAVE.y m; each boundary wanders
## on its own by PINCH of the bed under it (over waves 1/PINCH_WAVE m),
## never under the boundary below, so beds thicken, thin and pinch out.
const DIP := Vector2(0.05,0.11)
const WAVE := Vector2(1.8,28.0)
const PINCH := 0.65
const PINCH_WAVE := 0.045
## A soft bed is eaten in by up to NOTCH_DEEP m more where its own wave runs
## over NOTCH_AT, under the hard bed over it: overhangs and caves.
const NOTCH_DEEP := 1.4
const NOTCH_AT := 0.25
## Vertical joints: the wall breaks into blocks some JOINT m along the
## shore, each stood out or in by up to JOINT_OUT m (a soft bed's half).
const JOINT := 4.5
const JOINT_OUT := 0.55
## Gullies: where a ridged wave along the shore (GULLY_WAVE 1/m) peaks over
## GULLY_AT the wall is cut in by up to GULLY m, full from GULLY_FADE m
## under the rim, half as deep at the foot.
const GULLY := 2.8
const GULLY_WAVE := 0.04
const GULLY_AT := 0.72
const GULLY_FADE := 2.5
## The face leans out this far a metre down; buttresses stand out and
## gullies sink in by up to COLUMN m, over waves COLUMN_WAVE (1/m); each
## ring's point wanders JITTER m more.
const BATTER := 0.02
const COLUMN := 0.9
const COLUMN_WAVE := 0.16
const JITTER := 0.14
## Each bed wanders in and out along the shore by up to BED_WANDER m, over
## waves BED_WAVE times the buttresses' length.
const BED_WANDER := 0.5
const BED_WAVE := 1.6
## Each ring's point slips along the shore by up to this share of the
## grid's step.
const SLIP := 0.3
## The brow: the turf's lip LIP m under the rim, overhanging the rock by
## LIP_OUT m, and the bare peat under it PEAT m under the rim, PEAT_IN m
## in; the wave-cut notch at the sea (its top over SEA, its depth in), and
## the foot's talus (m out).
const LIP := Vector2(0.2,0.4)
const LIP_OUT := Vector2(0.25,0.6)
const PEAT := Vector2(0.8,1.3)
const PEAT_IN := 0.25
const NOTCH := Vector2(0.9,0.55)
const TALUS := 0.5
## The rock's colours, face by face (the earth sides' `side_painted`): each
## bed one of its look's bands (scripts/rock_looks.gd; hard beds the paler
## ones), a share lighter or darker (BED_TONE); warmer and cooler in
## patches by up to WARM over waves 1/WARM_WAVE m; pale streaks down from
## the ledges in some joints (STREAK: the share of them, how pale), not
## near the sea; the turf of a lip or a wide ledge (TURF, faces lying back
## more than LEDGE_UP), the peat under the lip; the foot dark and wet to
## WET m over the sea (WET_DARK) with a black lichen band over it (TAR).
const BED_TONE := Vector2(0.9,1.4)
const WARM := 0.34
const WARM_WAVE := 0.035
const STREAK := Vector2(0.2,0.7)
const PALE := Color(0.36,0.35,0.32)
const TURF := Color(0.11,0.22,0.06)
const LEDGE_UP := 0.7
## Ledge turf only where a slow patch noise runs over LEDGE_PATCH.
const LEDGE_PATCH := -0.15
const PEAT_TONE := Color(0.075,0.055,0.04)
const WET := Vector2(0.5,1.9)
const WET_DARK := 0.48
const TAR := Vector2(1.9,3.4)
const TAR_DARK := 0.72
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
## The beds' dip: its way, times metres a metre.
var dip := Vector2.ZERO
var _roll: FastNoiseLite
var _lean: FastNoiseLite
var _patch: FastNoiseLite
var _wave: FastNoiseLite
var _pinch: FastNoiseLite
var _joint: FastNoiseLite
var _gully: FastNoiseLite
var _streak: FastNoiseLite
## What each segment of the last column (`_column`) is, ring by ring down:
## a bed's index, or TURF_KIND, PEAT_KIND.
var _kinds := PackedInt32Array()
const TURF_KIND := -1
const PEAT_KIND := -2

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
	_beds()
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

## The beds up the walls, from the foot to over the highest top (and the
## dip's and waves' reach): each a whole number of units drawn THICK times
## over, hard or soft, hard beds never two alike in a row for long; and
## the dip. On their own draws, so the stacks and the cove stand as drawn.
func _beds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,"sea cliff beds"])
	dip = Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(DIP.x,DIP.y)
	var y := SEA
	var top := high+knoll.w+2.0+radius*DIP.y+WAVE.x
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
		y += units*bed*rng.randf_range(THICK.x,THICK.y)
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
	_wave = _smooth(229,1.0/WAVE.y)
	_pinch = _smooth(233,PINCH_WAVE)
	_gully = _smooth(239,GULLY_WAVE)
	_joint = FastNoiseLite.new()
	_joint.seed = seed+241
	_joint.noise_type = FastNoiseLite.TYPE_CELLULAR
	_joint.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_joint.cellular_jitter = 0.9
	_joint.frequency = 1.0/JOINT
	_streak = _joint.duplicate()
	_streak.seed = seed+251
	_streak.frequency = 1.0/(JOINT*0.6)

func _smooth(salt: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed+salt
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	return n

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
## (`_column`) stitched rim to foot, and the rock under the land; each face
## coloured as the rock it cuts weathers (`_tint`, in the islet's rock look).
func side_arrays(islet: RefCounted) -> Array:
	var into := Transform3D.IDENTITY
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var kinds := PackedInt32Array()
	var points: PackedVector2Array = islet.points
	var edges: PackedInt32Array = islet.shore_edges
	var heights: PackedFloat32Array = islet.heights
	var keel: PackedFloat32Array = islet.keel
	var ids: PackedInt32Array = islet.ids
	var base: float = islet.base
	var outward: Dictionary = IslandShore._outward(points,edges)
	var columns := {}
	var column_kinds := {}
	for k in range(0,edges.size(),3):
		for i in [edges[k],edges[k+1]]:
			if not columns.has(i):
				columns[i] = _column(islet,i,outward[i])
				column_kinds[i] = _kinds
	for k in range(0,edges.size(),3):
		var a := edges[k]
		var b := edges[k+1]
		var out: Vector2 = ((outward[a] as Vector2)+(outward[b] as Vector2)).normalized()
		var face := Vector3(out.x,0.0,out.y)
		var ha := heights[a]
		var hb := heights[b]
		var ca: Array = columns[a]
		var cb: Array = columns[b]
		var ka: PackedInt32Array = column_kinds[a]
		var kb: PackedInt32Array = column_kinds[b]
		# Stitched down: each step takes the next ring of the column whose
		# next ring stands higher.
		var i := 0
		var j := 0
		while i < ca.size()-1 or j < cb.size()-1:
			var down_a := j >= cb.size()-1 or (i < ca.size()-1 and (ca[i+1] as Vector3).y >= (cb[j+1] as Vector3).y)
			if down_a:
				IslandShore._add(vertices,uvs,into,[ca[i],cb[j],ca[i+1]],face,[ha,hb,ha],0.0)
				kinds.append(ka[i])
				i += 1
			else:
				IslandShore._add(vertices,uvs,into,[ca[i],cb[j],cb[j+1]],face,[ha,hb,hb],0.0)
				kinds.append(kb[j])
				j += 1
	# Standing in the sea (SkyIslet `sea_foot`), only the arch's raised
	# underside is drawn: the rest stands on the bed.
	var in_sea := not (islet.sea_bed as PackedFloat32Array).is_empty()
	for f: int in islet.land:
		if in_sea and (keel[ids[f*3]] >= 0.0 or keel[ids[f*3+1]] >= 0.0 or keel[ids[f*3+2]] >= 0.0): continue
		var tri := []
		for k in range(3):
			var i := ids[f*3+k]
			tri.append(Vector3(points[i].x,base-keel[i],points[i].y))
		IslandShore._add(vertices,uvs,into,tri,Vector3.DOWN,[],0.0)
		kinds.append(0)
	var tones := _bed_tones(islet)
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	normals.resize(vertices.size())
	colours.resize(vertices.size())
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		var tint := _tint(kinds[i/3],(vertices[i]+vertices[i+1]+vertices[i+2])/3.0,normal,tones)
		for j in range(3):
			normals[i+j] = normal
			colours[i+j] = tint
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays

## Shore point `i`'s column, rim to foot: the rim, the turf's lip standing
## out over the rock and the peat under it, two rings at each bed boundary
## between (the bed over it and the bed under it, each stood out or in by
## its hardness, `_bed_out`), a ring part way down a tall bed, the notch at
## the sea, and the foot with its talus. Every rock ring is stood out along
## `out` by the column's buttress or gully, its joint block and the batter.
## What each segment under a ring is goes in `_kinds`.
func _column(islet: RefCounted, i: int, out: Vector2) -> Array:
	var p: Vector2 = islet.points[i]
	var top: float = islet.heights[i]
	var foot: float = float(islet.base)-float(islet.keel[i])
	var salt := seed % 7919
	var lean := _lean.get_noise_2d(p.x,p.y)*COLUMN
	var block := _joint.get_noise_2d(p.x,p.y)*JOINT_OUT
	var gully := GULLY*smoothstep(GULLY_AT,0.98,1.0-absf(_gully.get_noise_2d(p.x,p.y)))
	var bounds := _bounds(p)
	var along := out.orthogonal()*float(islet.step)
	# The rings wanted, top down: (height, reach out of the mean face, what
	# lies under it).
	var wanted: Array[Vector3] = []
	var top_bed := _bed_at(bounds,top-1.0)
	var lip_out := lerpf(LIP_OUT.x,LIP_OUT.y,PlateMesh._hash(i,salt,5))+maxf(_bed_out(top_bed,i,p),0.0)+maxf(block,0.0)
	wanted.append(Vector3(top-lerpf(LIP.x,LIP.y,PlateMesh._hash(i,salt,3)),lip_out,PEAT_KIND))
	wanted.append(Vector3(top-lerpf(PEAT.x,PEAT.y,PlateMesh._hash(i,salt,9)),-PEAT_IN+_bed_out(top_bed,i,p)*0.5,top_bed))
	for b in range(bounds.size()-1,0,-1):
		var y := bounds[b]
		if y > top-PEAT.x or y < foot: continue
		var over := _bed_out(b,i,p)
		var under := _bed_out(b-1,i,p)
		var height := minf(bounds[b+1] if b+1 < bounds.size() else top,top)-y
		if height > BED_SPLIT: wanted.append(Vector3(y+height*lerpf(0.4,0.6,PlateMesh._hash(i,salt+b,7)),over*0.7,b))
		# The step between: the ledge's top if the bed under stands out.
		wanted.append(Vector3(y+BED_STEP,over,b-1 if under > over else b))
		wanted.append(Vector3(y-BED_STEP,under,b-1))
	# The notch the sea cuts.
	if top > SEA+NOTCH.x+1.0:
		wanted.append(Vector3(SEA+NOTCH.x,_bed_out(0,i,p)-NOTCH.y,0))
		wanted.append(Vector3(SEA-0.6,_bed_out(0,i,p)-NOTCH.y*0.4,0))
	var col: Array = [Vector3(p.x,top,p.y)]
	_kinds = PackedInt32Array([TURF_KIND])
	var last := top
	for w in wanted:
		if w.x > last-RING_GAP or w.x < foot+RING_GAP: continue
		var o := w.y+lean+(top-w.x)*BATTER
		if int(w.z) >= 0:
			# The rock: its joint block (a soft bed's less) and the gully,
			# cut in from under the rim.
			var hard := hardness[clampi(int(w.z),0,hardness.size()-1)]
			o += block*lerpf(0.5,1.0,hard)
			o -= gully*clampf((top-w.x)/GULLY_FADE,0.0,1.0)*lerpf(1.0,0.5,clampf((top-w.x)/maxf(top-foot,1.0),0.0,1.0))
		# Each ring's point slips a little along the shore, so no two faces
		# of a bed lie in one plane.
		var slip := along*(PlateMesh._hash(i,salt+col.size()*7,17)-0.5)*2.0*SLIP
		col.append(Vector3(p.x+out.x*o+slip.x,w.x,p.y+out.y*o+slip.y))
		_kinds.append(int(w.z))
		last = w.x
	# The foot: its talus under the sea; under the arch, the soffit's edge.
	var o := _bed_out(0,i,p)+TALUS+lean+(top-foot)*BATTER
	col.append(Vector3(p.x+out.x*o,foot,p.y+out.y*o) if foot < SEA else Vector3(p.x,foot,p.y))
	_kinds.append(0)
	return col

## The bed boundaries' heights over `p`, bottom up: the beds' floors dipped
## and waved, each wandering on its own (PINCH), never under the one below.
func _bounds(p: Vector2) -> PackedFloat32Array:
	var shift := p.dot(dip)+_wave.get_noise_2d(p.x,p.y)*WAVE.x
	var out := PackedFloat32Array()
	out.resize(floors.size())
	if floors.is_empty(): return out
	out[0] = floors[0]
	for b in range(1,floors.size()):
		var thick := floors[b]-floors[b-1]
		var y := floors[b]+shift+_pinch.get_noise_2d(p.x+b*71.0,p.y-b*43.0)*PINCH*thick
		out[b] = maxf(y,out[b-1])
	return out

## The bed holding height `y` (its index; the lowest under them all).
static func _bed_at(bounds: PackedFloat32Array, y: float) -> int:
	for b in range(bounds.size()-1,0,-1):
		if y >= bounds[b]: return b
	return 0

## Bed `b`'s reach out of the mean face at shore point `i` (at `p`, m): by
## its hardness, itself wandering along the shore (HARD_WANDER), a soft
## bed eaten into notches (NOTCH_DEEP); wandering in and out (BED_WANDER,
## each bed on its own wave so the beds run on unbroken), and a little
## more at the point.
func _bed_out(b: int, i: int, p: Vector2) -> float:
	var hard := clampf(hardness[clampi(b,0,hardness.size()-1)]+_pinch.get_noise_2d(p.x*2.0-b*37.0,p.y*2.0+b*61.0)*HARD_WANDER,0.0,1.0)
	var wander := _lean.get_noise_2d(p.x*BED_WAVE+b*53.0,p.y*BED_WAVE-b*29.0)*BED_WANDER
	var reach := lerpf(BED_OUT.y,BED_OUT.x,hard)+wander+(PlateMesh._hash(i,seed % 7919+b*13,11)-0.5)*2.0*JITTER
	if hard < 0.5:
		var eaten := smoothstep(NOTCH_AT,NOTCH_AT+0.3,_pinch.get_noise_2d(p.x*1.6+b*19.0,p.y*1.6-b*23.0))
		reach -= NOTCH_DEEP*eaten*(1.0-hard*2.0)
	return reach

## Each bed's colour: one of the islet's rock look's bands (scripts/
## rock_looks.gd `colour_of`), the paler ones for the hard beds, a share
## lighter or darker (BED_TONE). Linear.
func _bed_tones(islet: RefCounted) -> PackedColorArray:
	var rock: Dictionary = (islet.recipe as Dictionary).get("rock",{})
	var look := str(rock.get("palette","basalt"))
	var tone := float(rock.get("tone",1.0))
	var vary := float(rock.get("vary",0.5))
	var pale: Array = [RockLooks.colour_of(look,"core_a",tone,vary),RockLooks.colour_of(look,"core_b",tone,vary)]
	var dark: Array = [RockLooks.colour_of(look,"core_c",tone,vary),RockLooks.colour_of(look,"bedrock",tone,vary)*1.25,RockLooks.colour_of(look,"core_a",tone,vary)]
	var out := PackedColorArray()
	for b in range(hardness.size()):
		var pick := absi(hash([seed,b,"bed tone"]))
		var from: Array = pale if hardness[b] > 0.5 else dark
		var c: Color = from[pick%from.size()]
		out.append(c*lerpf(BED_TONE.x,BED_TONE.y,float(pick/7%101)/100.0))
	return out

## A wall face's colour (linear): its kind (a bed, the turf, the peat), at
## `at`, facing `normal`, the beds' `tones`. Turf on the lip and on a
## ledge lying back; a bed's rock warmer or cooler in patches, pale streaks
## down some joints; the foot wet and dark, a black band of lichen over it.
func _tint(kind: int, at: Vector3, normal: Vector3, tones: PackedColorArray) -> Color:
	if kind == TURF_KIND or (kind >= 0 and normal.y > LEDGE_UP and at.y > SEA+TAR.y and _patch.get_noise_2d(at.x*0.25,at.z*0.25) > LEDGE_PATCH):
		return TURF*(1.0+0.18*_patch.get_noise_2d(at.x*0.7,at.z*0.7))
	if kind == PEAT_KIND: return PEAT_TONE
	var c: Color = tones[clampi(kind,0,tones.size()-1)] if not tones.is_empty() else Color(0.1,0.1,0.11)
	var warm_wave := 1.0/(WARM_WAVE*WAVE.y)
	var w := _wave.get_noise_3d(at.x*warm_wave,at.y*warm_wave*1.5,at.z*warm_wave)
	c = Color(c.r*(1.0+WARM*w),c.g*(1.0+WARM*0.3*w),c.b*(1.0-WARM*w))
	var streak := _streak.get_noise_2d(at.x,at.z)*0.5+0.5
	if streak > 1.0-STREAK.x:
		var run := clampf((streak-(1.0-STREAK.x))/STREAK.x,0.0,1.0)
		c = c.lerp(PALE,STREAK.y*run*smoothstep(SEA+TAR.y,SEA+TAR.y+4.0,at.y))
	var wet := 1.0-smoothstep(SEA+WET.x,SEA+WET.y,at.y+_patch.get_noise_2d(at.x,at.z)*0.4)
	var tar := 1.0-smoothstep(SEA+TAR.x,SEA+TAR.y,at.y+_patch.get_noise_2d(at.x*0.5,at.z*0.5)*0.6)
	c *= lerpf(1.0,TAR_DARK,tar)
	c = c.lerp(Color(c.r*0.92,c.g,c.b*0.9),wet)*lerpf(1.0,WET_DARK,wet)
	return c
