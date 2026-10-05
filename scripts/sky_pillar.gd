extends RefCounted
## One forest of sandstone pillars of the hidden land far below, risen
## through the cloud sea beside the sky islands (scripts/sky_pillars.gd
## places them): a cluster of very tall, slender columns, the rock between
## them long since worn away along its joints, their feet in the cloud and
## their tops crowned with spruces and grass. The glide slaloms between them.
##
## Each pillar is drawn as real columns of bedded sandstone weather:
##   the plan: its cross-section a rounded square (a superellipse), turned
##     and drawn out, as the joints that cut the rock into blocks leave it;
##   its axis: plumb or leaning a few degrees, wandering a metre or two;
##   its profile: a little flare at the foot, a slow taper or a swelling
##     belly up its height;
##   the beds: the rock laid in horizontal beds a few metres thick (5 to 13
##     m), each set in or out a little from the next, harder ones standing
##     proud as ledges, softer ones worn back into notches, each its own
##     outline. Every bed meets the next at a chamfer, so the bedding reads
##     as crisp lines and ledges, not a smooth tube;
##   the fluting: vertical grooves worn down the faces by rain, long and
##     narrow (ridged noise drawn out up the pillar);
##   the joints: a few deep vertical cracks running much of its height;
##   the top: a low crumbly dome of grass on the last bed, dense with
##     spruces, a few more clinging on the ledges down its sides.
## Pillars are extruded rings (one ring at each bed's foot and top, and in a
## thick bed's middle), flat-faced as the plate's rock, coloured per face
## from the world's palette: the rock's three granite-core tones bed by bed
## and the odd shale band (scripts/strata.gd), streaked dark down the
## flutes, darker under overhangs, grass on the ledges and the tops.
##
## Two or three pillars stand joined at the foot as one fin, splitting as
## they rise. Lanes between every stand are at least LANE m clear across the
## glide's band, the slalom. One way through is the thread, all optional:
## from the face toward the plate, a slot SLOT_GAP m wide between two leaning
## fins, then under a natural bridge between two pillars, to a hidden low
## pillar-top meadow ringed by tall ones, with a jet down the thread and a
## thermal off the meadow up to the tops.
##
## The frame is the forest's own: its middle on the islands' plane at the
## origin, +z out toward the plate, heights the world's. The faces start
## under the sea (FOOT) and the reference material frays them into the cloud
## (sky_peak.gd `sea_cut`); mist puffs wrap their feet and hang in the gaps
## (`wraps`).

const SkyPeak = preload("res://scripts/sky_peak.gd")
const SEA := SkyPeak.SEA
const CUT := SkyPeak.CUT
const BOTTOM := SkyPeak.BOTTOM
## Where every pillar's rings start, under the cut, so no face ends in sight.
const FOOT := CUT-12.0
## The forest's half extents (m: across in x, along z toward the plate).
const REACH := Vector2(280.0,320.0)
## The glide's band (scripts/sky_glide.gd FLOOR to CEILING), and the
## thread's height, where the pillars' centres are set (`axis`).
const GLIDE_BAND := Vector2(-55.0,95.0)
const THREAD_Y := 5.0
## Lanes: every two stands at least LANE m apart across the band, placed
## with LANE_SPARE more for what the weathering adds.
const LANE := 30.0
const LANE_SPARE := 5.0
## Stands tried and the most pillars; pillars' half widths (m, the narrow
## way), how drawn out (the long way over the narrow), how square (the
## superellipse's power), their tops (m) and the share low enough for the
## glide to reach (LOW_TOP).
const TRIES := 1400
const MOST := 30
const SIZE := Vector2(9.5,21.0)
## The most a pillar measures across, its two half widths together (m).
const ACROSS := 45.0
const ASPECT := Vector2(1.0,1.5)
const SQUARE := Vector2(2.4,4.0)
const TOP := Vector2(110.0,250.0)
const LOW_TOPS := 0.3
const LOW_TOP := Vector2(62.0,94.0)
## The profile: the top's width as a share of the foot's, the foot's flare
## (share, over the lowest FLARE_RUN of the height), a belly (share) and
## the axis's wander (m).
const TAPER := Vector2(0.7,0.95)
const FLARE := 0.3
const FLARE_RUN := 0.3
const BULGE := Vector2(-0.08,0.12)
const WANDER := Vector2(0.2,0.9)
## Set-backs: the odds a pillar narrows at a bed (a second at half that),
## to what share, the shoulder it leaves carrying grass and spruces; never
## within SETBACK_CLEAR m of the sea or the top.
const SETBACK_ODDS := 0.7
const SETBACK := Vector2(0.72,0.9)
const SETBACK_CLEAR := 22.0
## The odds a pillar leans, and how far its top stands off plumb (m).
const LEAN_ODDS := 0.4
const LEAN_SHIFT := Vector2(10.0,30.0)
## The odds a stand is a fin of two joined at the foot, and how much they
## lean apart (m a metre).
const FIN_ODDS := 0.15
const FIN_APART := Vector2(0.02,0.04)
## Clumps: the odds a stand is a clump of CLUMP pillars on one shared lower
## body (a small massif, its top a saddle between them), how far apart its
## pillars stand (times their two half widths: a cleft between, from a
## crack to a few metres), the body's top (m), and the odds a clump is two
## pillars split from one body standing most of their height (SPLIT, share
## of the lower's height). The body's plan is its pillars' feet, joined.
const CLUMP_ODDS := 0.7
const CLUMP := Vector2i(2,6)
const CLUMP_APART := Vector2(0.95,1.25)
const BODY_TOP := Vector2(-10.0,100.0)
const SPLIT_ODDS := 0.3
const SPLIT := Vector2(0.45,0.7)
const BODY_PAD := 5.0
## Stubs: the odds a pillar is a stub, its top just out of the cloud (m);
## broken: the odds a pillar's top is snapped off, falling DROP m across.
const STUB_ODDS := 0.12
const STUBS := 5
const STUB_TOP := Vector2(-80.0,30.0)
const BROKEN_ODDS := 0.28
const DROP := Vector2(6.0,16.0)
## Beds: the thick ones (m) that step the outline, each set in or out
## (share), a few a soft band notched deep (NOTCH share, NOTCH_BAND m
## thick); the chamfer where two meet (m); a bed's belly (share). The thin
## beds between (MINOR m) show only in the rock's tones. Rings every RING m
## up a bed, every DEEP_RING m down in the cloud.
const BED := Vector2(14.0,38.0)
const BED_INSET := Vector2(-0.1,0.06)
const NOTCH_ODDS := 0.22
const NOTCH := 0.12
const NOTCH_BAND := Vector2(2.5,5.0)
const CHAMFER := 0.9
const BED_ROUND := 0.015
const MINOR := 4.5
## Each bed sits a little off the one under it (share of the width), so a
## pillar's sides step and wander up its height, not run ruler-straight.
const BED_SHIFT := 0.06
const RING := 4.0
const DEEP_RING := 10.0
## The fluting (m plus share of the width), its grooves' spacing (m) and
## their stretch up the pillar (long ribs); the broad lumps (share) and
## their size (m); the knobbly weathering up a face (m, wavelength m).
const FLUTE := 1.3
const FLUTE_SHARE := 0.05
const FLUTE_WAVE := 7.0
const FLUTE_STRETCH := 0.035
const LUMP := 0.045
const LUMP_WAVE := 75.0
const KNOB := 0.6
const KNOB_WAVE := 11.0
## The joints: how many, how deep (m), how many segments wide.
const CRACKS := Vector2i(2,5)
const CRACK_DEPTH := Vector2(1.4,3.8)
## A segment round a ring is about SEGMENT m, within SEGMENTS.
const SEGMENT := 3.3
const SEGMENTS := Vector2i(24,60)
## The top: its dome's rise (m), its rim's jag (m), the cap's rings (shares
## of the rim), and its bumps (m, wavelength m).
const DOME := Vector2(1.2,3.4)
const JAG := Vector2(-0.8,1.4)
const CAP := [0.93,0.72,0.46,0.2]
const BUMP := 0.6
const BUMP_WAVE := 9.0
## The thread. The slot: its middle along z, its gap (m), the fins' half
## widths and half lengths (m), how they lean (m a metre), their tops.
const SLOT_Z := 185.0
const SLOT_GAP := Vector2(12.5,15.0)
## How far the fins stand into the slot before its walls are cut plumb on
## its line (m): the joint face the slot was weathered along.
const SLOT_CUT := 2.0
const SLOT_HALF := Vector2(9.0,12.0)
const SLOT_LONG := Vector2(30.0,38.0)
const SLOT_LEAN := Vector2(0.05,0.085)
const SLOT_TOPS := Vector2(125.0,215.0)
## The bridge: along z, the gap it spans (m), its pillars' half widths and
## tops, its underside's height at the middle, its thickness there, its
## deck's half width (m) and how much lower and wider it springs from the
## pillars.
const BRIDGE_Z := 72.0
const BRIDGE_GAP := Vector2(32.0,38.0)
const BRIDGE_SIZE := Vector2(12.0,16.0)
const BRIDGE_TOPS := Vector2(115.0,205.0)
const BRIDGE_UNDER := Vector2(30.0,38.0)
const BRIDGE_THICK := Vector2(5.5,7.5)
const BRIDGE_HALF := Vector2(6.0,8.0)
const BRIDGE_ARCH := 16.0
## The meadow: along z, its pillar's half width and top (m), and the
## thermal's base over it (SkyCurrents runs a thermal 70 m under its base
## to 55 over).
const MEADOW_Z := -70.0
const MEADOW_SIZE := Vector2(15.0,18.0)
const MEADOW_TOP := Vector2(-30.0,-18.0)
const THERMAL_BASE := 40.0
## The thread's jet from out past the face to over the meadow (z, m), and
## the thread's corridor kept clear of other stands (m either side).
const THREAD_FROM := REACH.y+110.0
const THREAD_TO := MEADOW_Z+25.0
const THREAD_CLEAR := 24.0
## Spruces: on the tops tried every CAP_TREE_STEP m (kept at these odds),
## on ledges at least LEDGE m wide, at most TREE_CAP; heights (m) and the
## spruce variants (scripts/hero_trees.gd SPRUCE). Clinging to the faces:
## windswept little ones leaning out of the cracks (CRACK_TREE odds a ring)
## and the mossy streaks (FACE_TREE), CLING m tall, leaning out LEAN_OUT
## radians.
const CAP_TREE_STEP := 3.5
const CAP_TREE_ODDS := 0.85
const MEADOW_TREE_ODDS := 0.25
const TREE_HEIGHT := Vector2(5.5,14.0)
const LEDGE := 0.9
const LEDGE_TREE_ODDS := 0.07
const LEDGE_TREE := Vector2(1.6,3.8)
const TREE_VARIANTS := [0,1,2,4]
const TREE_CAP := 3400
const CRACK_TREE := 0.16
const FACE_TREE := 0.05
const CLING := Vector2(1.2,3.6)
const LEAN_OUT := Vector2(0.3,0.85)
const CLING_VARIANTS := [3,1,4,3]
## Mist: a few low puffs where each foot goes into the sea (sizes m); thin
## wisps drawn out along the air (length, thickness m) hugging the feet,
## lying in the gaps within MIST_GAP m, and a few faint layers higher up.
const WRAP_SIZE := Vector2(10.0,20.0)
const HUG := Vector2(30.0,64.0)
const HUG_THICK := Vector2(8.0,16.0)
const GAP_WISP := Vector2(30.0,80.0)
const GAP_THICK := Vector2(3.5,8.0)
const MIST_GAP := 95.0
const LAYERS := 9
const LAYER := Vector2(60.0,130.0)
const LAYER_THICK := Vector2(9.0,16.0)
## Colours: grass on faces whose up is over GRASS_UP, moss-earth over
## EARTH_UP; each face nudged FACE_JITTER; the beds' tones BED_TONE.
const GRASS_UP := 0.62
const EARTH_UP := 0.36
const FACE_JITTER := 0.04
const BED_TONE := 0.35

var seed := 0
## The pillars: dictionaries {c (centre at THREAD_Y), lean (m a metre),
## wander (amp, freq, phase), a, b (half widths), rot, n, top, taper, bulge,
## bulge_at, dome, beds (bounds), insets, cracks, seg, group, role, keep
## (Vector3(side, half gap, lean): the slot's wall) or null; then as built:
## ys, bed_of (per ring), centres, radii (ring by ring), bound}.
var pillars: Array = []
## The bridge {a, b (its pillars), from, to (xz), under, thick, half, deck}.
var bridge := {}
## The slot {a, b (its fins), gap, lean (m a metre in x), z0, z1}.
var slot := {}
## The meadow pillar's index.
var meadow := -1
## Spruces (x, y, z, height), their variants and their lean (a rotation:
## axis times radians); mist puffs (x, y, z, size); wisps (x, y, z, half
## length) and their (half thickness, strength, seed).
var trees := PackedVector4Array()
var tree_variants := PackedInt32Array()
var tree_leans := PackedVector3Array()
var wraps := PackedVector4Array()
var wisps := PackedVector4Array()
var wisp_looks := PackedVector3Array()
## The tallest top.
var top := 0.0

## The faces being laid: flat, three vertices each.
class Faces:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

var _rng := RandomNumberGenerator.new()
var _stubs := 0
var _flute: FastNoiseLite
var _lump: FastNoiseLite
var _bedline: FastNoiseLite
var _bump: FastNoiseLite

## The forest for `seed_value` (a hash of its spot).
static func make(seed_value: int) -> RefCounted:
	var forest: RefCounted = new()
	forest._shape(seed_value)
	return forest

func _shape(seed_value: int) -> void:
	seed = seed_value
	_rng.seed = seed_value
	_flute = _noise(5,1.0/FLUTE_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)
	_lump = _noise(9,1.0/LUMP_WAVE,2,FastNoiseLite.FRACTAL_FBM)
	_bedline = _noise(13,1.0/9.0,2,FastNoiseLite.FRACTAL_FBM)
	_bump = _noise(17,1.0/BUMP_WAVE,2,FastNoiseLite.FRACTAL_FBM)
	pillars.clear()
	_thread()
	_scatter()
	for i in range(pillars.size()): _rings(i)
	top = -INF
	for p: Dictionary in pillars: top = maxf(top,float(p.top))
	_bridge_shape()
	_plant()
	_mist()

# --- The plan -------------------------------------------------------------------

## A pillar's numbers, its centre `c` at THREAD_Y, its half widths `a` (the
## long way, turned `rot`) and `b`, its top.
func _pillar(c: Vector2, a: float, b: float, rot: float, top_y: float, group: int, role := "") -> Dictionary:
	var p := {"c":c,"lean":Vector2.ZERO,"a":a,"b":b,"rot":rot,"n":_rng.randf_range(SQUARE.x,SQUARE.y),"top":top_y,
		"taper":lerpf(TAPER.y,_rng.randf_range(TAPER.x,TAPER.y),clampf((top_y-LOW_TOP.x)/(TOP.y-LOW_TOP.x),0.0,1.0)),"bulge":_rng.randf_range(BULGE.x,BULGE.y),"bulge_at":_rng.randf_range(0.3,0.75),
		"wander":Vector3(_rng.randf_range(WANDER.x,WANDER.y),TAU/_rng.randf_range(60.0,140.0),_rng.randf()*TAU),
		"dome":_rng.randf_range(DOME.x,DOME.y),"group":group,"role":role,"keep":null,"salt":pillars.size()*1013+7,
		"broken":Vector3.ZERO,"plan":PackedFloat32Array()}
	# The beds, from the foot up, the last ending at the top.
	var beds := PackedFloat32Array([FOOT])
	var insets := PackedFloat32Array()
	var y := FOOT
	while true:
		var notch := _rng.randf() < NOTCH_ODDS and y > SEA
		var next := y+(_rng.randf_range(NOTCH_BAND.x,NOTCH_BAND.y) if notch else _rng.randf_range(BED.x,BED.y))
		insets.append(-NOTCH if notch else _rng.randf_range(BED_INSET.x,BED_INSET.y))
		if next >= top_y-BED.x*0.4:
			beds.append(top_y)
			break
		beds.append(next)
		y = next
	p.beds = beds
	p.insets = insets
	var shifts := PackedVector2Array()
	var mean_w := (a+b)*0.5
	for k in range(insets.size()):
		# The thread's walls hold true through the glide's band, wandering
		# only over it.
		var still := role in ["meadow","massif"] or (role in ["slot","bridge"] and beds[k] < GLIDE_BAND.y+10.0)
		shifts.append(Vector2.ZERO if still else Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.0,BED_SHIFT)*mean_w)
	p.shifts = shifts
	# Set-backs at a bed or two, the thread's pillars plumb-sided.
	var steps := []
	var kept := 1.0
	if role in ["","fin","clump","slot","bridge"]:
		var thread := role in ["slot","bridge"]
		for k in range(2):
			if _rng.randf() > SETBACK_ODDS*(1.0 if k == 0 else 0.5): break
			var at := beds[_rng.randi_range(1,beds.size()-2)] if beds.size() > 2 else top_y
			if at < SEA+SETBACK_CLEAR or at > top_y-SETBACK_CLEAR or (thread and at < GLIDE_BAND.y+10.0): continue
			# Never so far in that a slender one goes thinner than its kind.
			var scale := maxf(_rng.randf_range(SETBACK.x,SETBACK.y),(SIZE.x*2.0+2.0)/(a+b)/kept)
			if scale > 0.94: continue
			kept *= scale
			# Stepped in on one side, the other running on up flush.
			var shift := Vector2.from_angle(_rng.randf()*TAU)*(1.0-scale)*minf(a,b)*0.9
			steps.append(Vector4(at,scale,shift.x,shift.y))
		steps.sort_custom(func(u: Vector4, w: Vector4) -> bool: return u.x < w.x)
	p.steps = steps
	var mean := (a+b)*0.5
	p.seg = clampi(int(round(TAU*mean*1.1/SEGMENT)),SEGMENTS.x,SEGMENTS.y)
	var cracks := []
	for k in range(_rng.randi_range(CRACKS.x,CRACKS.y)):
		var from := lerpf(FOOT,top_y,_rng.randf_range(0.0,0.5))
		cracks.append({"s":_rng.randi_range(0,int(p.seg)-1),"depth":_rng.randf_range(CRACK_DEPTH.x,CRACK_DEPTH.y),
			"wide":1 if _rng.randf() < 0.6 else 2,"from":from,"to":lerpf(from,top_y,_rng.randf_range(0.6,1.0))})
	p.cracks = cracks
	return p

## The thread's pillars: the slot's two leaning fins, the bridge's two
## pillars and the meadow's low one, on the line x = 0.
func _thread() -> void:
	var gap := _rng.randf_range(SLOT_GAP.x,SLOT_GAP.y)
	var lean := _rng.randf_range(SLOT_LEAN.x,SLOT_LEAN.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
	var tall := _rng.randf_range(SLOT_TOPS.x,SLOT_TOPS.y)
	var long := 0.0
	for side in [-1.0,1.0]:
		var half := _rng.randf_range(SLOT_HALF.x,SLOT_HALF.y)
		var length := _rng.randf_range(SLOT_LONG.x,SLOT_LONG.y)
		long = maxf(long,length)
		var c := Vector2(side*(gap*0.5+half-SLOT_CUT),SLOT_Z+_rng.randf_range(-6.0,6.0))
		var p := _pillar(c,length,half,PI*0.5+_rng.randf_range(-0.05,0.05),tall if side < 0.0 else lerpf(SLOT_TOPS.x,SLOT_TOPS.y,_rng.randf()),pillars.size(),"slot")
		p.lean = Vector2(lean,_rng.randf_range(-0.01,0.01))
		p.wander = Vector3.ZERO
		p.keep = Vector3(side,gap*0.5,lean)
		pillars.append(p)
	slot = {"a":0,"b":1,"gap":gap,"lean":lean,"z0":SLOT_Z-long-6.0,"z1":SLOT_Z+long+6.0}
	var span := _rng.randf_range(BRIDGE_GAP.x,BRIDGE_GAP.y)
	for side in [-1.0,1.0]:
		var half := _rng.randf_range(BRIDGE_SIZE.x,BRIDGE_SIZE.y)
		var p := _pillar(Vector2(side*(span*0.5+half),BRIDGE_Z),half*_rng.randf_range(1.0,1.2),half,_rng.randf_range(-0.3,0.3),
			_rng.randf_range(BRIDGE_TOPS.x,BRIDGE_TOPS.y),pillars.size(),"bridge")
		p.keep = Vector3(side,span*0.5,0.0)
		pillars.append(p)
	bridge = {"a":2,"b":3,"span":span,"under":_rng.randf_range(BRIDGE_UNDER.x,BRIDGE_UNDER.y),"thick":_rng.randf_range(BRIDGE_THICK.x,BRIDGE_THICK.y),
		"half":_rng.randf_range(BRIDGE_HALF.x,BRIDGE_HALF.y)}
	var m := _rng.randf_range(MEADOW_SIZE.x,MEADOW_SIZE.y)
	var low := _pillar(Vector2(0.0,MEADOW_Z),m*1.1,m,_rng.randf()*PI,_rng.randf_range(MEADOW_TOP.x,MEADOW_TOP.y),pillars.size(),"meadow")
	low.dome = 1.2
	low.wander = Vector3.ZERO
	meadow = pillars.size()
	pillars.append(low)

## The rest, scattered through the forest's oval: clumps on shared bodies,
## lone pillars, fins of two, now and then a stub or a snapped top; each
## stand kept a lane clear of every other and of the thread's corridor.
## Clumps and lone ones come as they come, so the forest is dense in places
## and open in others.
func _scatter() -> void:
	var group := pillars.size()
	var count := 0
	for p: Dictionary in pillars:
		if p.role != "massif": count += 1
	for t in range(TRIES):
		if count >= MOST: return
		var at := Vector2.from_angle(_rng.randf()*TAU)*sqrt(_rng.randf())
		var c := Vector2(at.x*REACH.x,at.y*REACH.y)
		var stand: Array
		var roll := _rng.randf()
		if roll < CLUMP_ODDS: stand = _clump(c,group,mini(MOST-count,CLUMP.y))
		else: stand = _lone(c,group,MOST-count)
		if stand.is_empty() or not _fits(stand): continue
		for p: Dictionary in stand:
			p.salt = pillars.size()*1013+7
			pillars.append(p)
			if p.role != "massif": count += 1
			if p.role == "stub": _stubs += 1
		group += 1

## A pillar's half widths and top for the scatter: tall, low or a stub.
func _size(stub_odds := STUB_ODDS) -> Vector3:
	var b := _rng.randf_range(SIZE.x,SIZE.y)
	var a := minf(b*_rng.randf_range(ASPECT.x,ASPECT.y),ACROSS-b)
	var roll := _rng.randf()
	if _stubs >= STUBS: stub_odds = 0.0
	var top_y := _rng.randf_range(STUB_TOP.x,STUB_TOP.y) if roll < stub_odds \
		else _rng.randf_range(LOW_TOP.x,LOW_TOP.y) if roll < stub_odds+LOW_TOPS else _rng.randf_range(TOP.x,TOP.y)
	return Vector3(a,b,top_y)

## Snaps a pillar's top off at the odds: a slanting break, DROP m across.
func _maybe_broken(p: Dictionary) -> void:
	if _rng.randf() >= BROKEN_ODDS or float(p.top) > TOP.y-25.0: return
	var way := Vector2.from_angle(_rng.randf()*TAU)
	p.broken = Vector3(way.x,way.y,_rng.randf_range(DROP.x,DROP.y))
	p.dome = 0.6

## One pillar, maybe leaning, maybe a fin of two, maybe a stub or broken.
func _lone(c: Vector2, group: int, room: int) -> Array:
	var size := _size()
	var a := size.x
	var b := size.y
	var top_y := size.z
	var rot := _rng.randf()*PI
	var stand := [_pillar(c,a,b,rot,top_y,group,"stub" if top_y < LOW_TOP.x else "")]
	if top_y >= LOW_TOP.x and _rng.randf() < LEAN_ODDS:
		stand[0].lean = Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(LEAN_SHIFT.x,LEAN_SHIFT.y)/(top_y-FOOT)
	_maybe_broken(stand[0])
	if top_y >= LOW_TOP.x and _rng.randf() < FIN_ODDS and room >= 2:
		# A second pillar along the long way, joined at the foot, leaning
		# apart as they rise.
		var way := Vector2.from_angle(rot)*(1.0 if _rng.randf() < 0.5 else -1.0)
		var b2 := maxf(b*_rng.randf_range(0.7,1.0),SIZE.x)
		var apart := _rng.randf_range(FIN_APART.x,FIN_APART.y)
		var c2 := c+way*((a+b2)*0.78+apart*(THREAD_Y-FOOT))
		var second := _pillar(c2,minf(b2*_rng.randf_range(1.0,1.3),ACROSS-b2),b2,rot+_rng.randf_range(-0.3,0.3),
			clampf(top_y*_rng.randf_range(0.6,0.9),LOW_TOP.x,TOP.y),group,"fin")
		second.lean = stand[0].lean+way*apart
		stand[0].role = "fin"
		_maybe_broken(second)
		stand.append(second)
	return stand

## A clump: two to five pillars a cleft apart round `c`, on one body whose
## top is the saddle between them; or two split from one body standing most
## of their height. The body comes first in the stand.
func _clump(c: Vector2, group: int, room: int) -> Array:
	if room < 2: return []
	var split := _rng.randf() < SPLIT_ODDS
	var want := 2 if split else _rng.randi_range(CLUMP.x,mini(CLUMP.y,room))
	var members := []
	var tries := 0
	while members.size() < want and tries < 40:
		tries += 1
		var size := _size(0.0 if members.is_empty() or split else STUB_ODDS)
		var at := c
		if not members.is_empty():
			var from: Dictionary = members[_rng.randi() % members.size()]
			var mean := (size.x+size.y)*0.5+(float(from.a)+float(from.b))*0.5
			at = (from.c as Vector2)+Vector2.from_angle(_rng.randf()*TAU)*mean*_rng.randf_range(CLUMP_APART.x,CLUMP_APART.y)*(0.85 if split else 1.0)
			var close := false
			for m: Dictionary in members:
				if at.distance_to(m.c) < ((size.x+size.y)*0.5+(float(m.a)+float(m.b))*0.5)*0.95: close = true
			if close: continue
		members.append(_pillar(at,size.x,size.y,_rng.randf()*PI,size.z,group,"stub" if size.z < LOW_TOP.x else "clump"))
	if members.size() < 2: return []
	var lowest := INF
	for m: Dictionary in members:
		if m.role != "stub": lowest = minf(lowest,float(m.top))
	# The body's top: a saddle under the lowest, high for a split pair; the
	# stubs that would stand buried in it let go.
	var body_top := lowest*_rng.randf_range(SPLIT.x,SPLIT.y) if split and lowest > 0.0 else _rng.randf_range(BODY_TOP.x,BODY_TOP.y)
	body_top = minf(body_top,lowest-12.0)
	if body_top < SEA+12.0: return []
	members = members.filter(func(m: Dictionary) -> bool: return float(m.top) > body_top+8.0)
	if members.size() < 2: return []
	var middle := Vector2.ZERO
	for m: Dictionary in members: middle += (m.c as Vector2)/members.size()
	for m: Dictionary in members:
		# Leaning a little apart, out from the body's middle.
		var out := ((m.c as Vector2)-middle).normalized()
		if float(m.top) > LOW_TOP.x: m.lean = out*_rng.randf_range(0.0,0.05)
		if not split: _maybe_broken(m)
	for m: Dictionary in members: m.under = body_top
	var body := _pillar(middle,1.0,1.0,0.0,body_top,group,"massif")
	body.wander = Vector3.ZERO
	body.steps = []
	body.bulge = 0.0
	body.taper = _rng.randf_range(0.82,0.95)
	body.dome = _rng.randf_range(1.5,4.0)
	_plan(body,members)
	return [body]+members

## A body's plan: per angle round its middle, the far side of its pillars'
## feet (padded), joined across the clefts, then smoothed round.
func _plan(body: Dictionary, members: Array) -> void:
	var middle: Vector2 = body.c
	var far := 0.0
	var feet := []
	for m: Dictionary in members:
		var d: Vector2 = axis(m,SEA)-middle
		var r := (float(m.a)+float(m.b))*0.5*1.05+BODY_PAD
		feet.append(Vector3(d.x,d.y,r))
		far = maxf(far,d.length()+r)
	var mean := far*0.8
	body.a = mean
	body.b = mean
	body.seg = clampi(int(round(TAU*mean*1.1/SEGMENT)),SEGMENTS.x,SEGMENTS.y+12)
	var seg: int = body.seg
	var plan := PackedFloat32Array()
	plan.resize(seg)
	for s in range(seg):
		var u := Vector2.from_angle(TAU*s/seg)
		var best := 6.0
		for f: Vector3 in feet:
			var d := Vector2(f.x,f.y)
			var along := d.dot(u)
			var off2 := d.length_squared()-along*along
			var r2 := f.z*f.z
			# Through a foot, out to its far side; past one, the hull's
			# reach toward it.
			if off2 <= r2: best = maxf(best,along+sqrt(r2-off2))
			else: best = maxf(best,along+f.z*0.55)
		plan[s] = best
	for k in range(3):
		var smooth := plan.duplicate()
		for s in range(seg): smooth[s] = (plan[(s+seg-1) % seg]+plan[s]*2.0+plan[(s+1) % seg])*0.25
		plan = smooth
	body.plan = plan
	body.cracks = []

## True if a stand is a lane clear of every other stand across the band and
## of the thread's corridor, and stands within the forest.
func _fits(stand: Array) -> bool:
	for p: Dictionary in stand:
		var bound := _bound(p)
		for y: float in [GLIDE_BAND.x,-20.0,15.0,50.0,GLIDE_BAND.y]:
			if y > float(p.top)+4.0: continue
			var at := axis(p,y)
			if absf(at.x) < bound+THREAD_CLEAR and at.y > MEADOW_Z-40.0 and at.y < THREAD_FROM+40.0: return false
			if Vector2(at.x/(REACH.x+40.0),at.y/(REACH.y+40.0)).length() > 1.0 or at.length()+bound > REACH.y+40.0: return false
			for q: Dictionary in pillars:
				if y > float(q.top)+4.0: continue
				if at.distance_to(axis(q,y)) < bound+_bound(q)+LANE+LANE_SPARE: return false
	return true

## How far a pillar's rock may reach from its axis (m), with the weathering.
func _bound(p: Dictionary) -> float:
	var widest := maxf(float(p.a),float(p.b))
	var plan: PackedFloat32Array = p.plan
	if not plan.is_empty():
		widest = 0.0
		for r in plan: widest = maxf(widest,r)
		return widest*(1.0+FLARE+LUMP)+FLUTE+2.0
	return widest*1.22*(1.12+maxf(float(p.bulge),0.0)+LUMP+BED_SHIFT)+FLUTE+(p.wander as Vector3).x

## A pillar's axis at height y: its centre at THREAD_Y, leaning and
## wandering.
func axis(p: Dictionary, y: float) -> Vector2:
	var w: Vector3 = p.wander
	var lean: Vector2 = p.lean
	var c: Vector2 = p.c
	for step: Vector4 in p.get("steps",[]):
		if y >= step.x: c += Vector2(step.z,step.w)
	return c+lean*(y-THREAD_Y)+Vector2(sin(y*w.y+w.z),cos(y*w.y*0.8+w.z*1.7))*w.x

# --- The rings ------------------------------------------------------------------

## A pillar's rings: one at each bed's foot, one in a thick bed's middle,
## one a chamfer under its top; the last at the pillar's top.
func _rings(i: int) -> void:
	var p: Dictionary = pillars[i]
	var beds: PackedFloat32Array = p.beds
	var ys := PackedFloat32Array()
	var bed_of := PackedInt32Array()
	for k in range(beds.size()-1):
		var b0 := beds[k]
		var b1 := beds[k+1]
		var end := b1 if k == beds.size()-2 else b1-CHAMFER
		var step := DEEP_RING if b1 < SEA-15.0 else RING
		var count := maxi(1,int(round((end-b0)/step)))
		for m in range(count+1):
			ys.append(lerpf(b0,end,float(m)/count))
			bed_of.append(k)
	var seg: int = p.seg
	var centres := PackedVector2Array()
	var radii := PackedFloat32Array()
	radii.resize(ys.size()*seg)
	var bound := 0.0
	var shifts: PackedVector2Array = p.shifts
	for r in range(ys.size()):
		var y := ys[r]
		var c := axis(p,y)+shifts[bed_of[r]]
		centres.append(c)
		# The profile runs over what stands in the sky, the foot's flare
		# down in the cloud.
		var t := clampf((y-SEA)/(float(p.top)-SEA),0.0,1.0)
		var k := bed_of[r]
		var beds_t := clampf((y-beds[k])/maxf(beds[k+1]-beds[k],0.1),0.0,1.0)
		for s in range(seg):
			var theta := TAU*s/seg
			var rr := _radius(p,theta,y,t,k,beds_t)
			# The slot's and the bridge's walls: never past the thread's line.
			if p.keep != null:
				var keep: Vector3 = p.keep
				var line := keep.z*(y-THREAD_Y)
				var d := cos(theta)
				if d*keep.x < -0.01:
					var limit := (line+keep.x*keep.y-c.x)/d
					rr = minf(rr,maxf(limit,2.0))
			radii[r*seg+s] = rr
			bound = maxf(bound,rr+shifts[bed_of[r]].length())
	p.ys = ys
	p.bed_of = bed_of
	p.centres = centres
	p.radii = radii
	p.bound = bound+0.5

## A pillar's radius out from its axis at angle `theta`, height y (t of its
## height), in bed k (beds_t up it): the rounded square's outline, the
## profile, the bed's set and own outline, the flutes, the lumps, the joints.
func _radius(p: Dictionary, theta: float, y: float, t: float, k: int, beds_t: float) -> float:
	var n: float = p.n
	var u := absf(cos(theta-float(p.rot)))/float(p.a)
	var v := absf(sin(theta-float(p.rot)))/float(p.b)
	var outline := 1.0/pow(pow(u,n)+pow(v,n),1.0/n)
	var plan: PackedFloat32Array = p.plan
	if not plan.is_empty():
		var f := fposmod(theta,TAU)/TAU*plan.size()
		var i := int(f) % plan.size()
		outline = lerpf(plan[i],plan[(i+1) % plan.size()],f-floorf(f))
	var mean := (float(p.a)+float(p.b))*0.5
	var profile := lerpf(1.0,float(p.taper),t)+FLARE*pow(1.0-smoothstep(0.0,FLARE_RUN,t),2.0)+float(p.bulge)*exp(-pow((t-float(p.bulge_at))/0.22,2.0))
	var round_x := cos(theta)*mean
	var round_z := sin(theta)*mean
	var salt: float = p.salt
	var insets: PackedFloat32Array = p.insets
	# A bed steps in or out only on a side or two, fading out round the
	# rest, so no bed runs round a pillar as a ring.
	var side := clampf(_bedline.get_noise_2d(cos(theta)*mean*0.5+float(k)*41.0+salt,sin(theta)*mean*0.5)*2.4+0.15,0.0,1.0)
	var bed := 1.0+insets[k]*side+0.025*_bedline.get_noise_3d(round_x,float(k)*23.0+salt,round_z)+BED_ROUND*sin(PI*beds_t)
	var r := outline*profile*bed
	for step: Vector4 in p.steps:
		if y >= step.x: r *= step.y
	# Ribs between sharp grooves, long up the face.
	r += (FLUTE+FLUTE_SHARE*mean)*(0.3-_flute.get_noise_3d(round_x+salt,y*FLUTE_STRETCH,round_z)*0.5-0.5)
	r += KNOB*_bump.get_noise_3d(round_x*1.3,y*BUMP_WAVE/KNOB_WAVE,round_z*1.3+salt)
	r *= 1.0+LUMP*_lump.get_noise_3d(round_x,y+salt,round_z)
	var seg: int = p.seg
	var s := int(round(theta*seg/TAU)) % seg
	for crack: Dictionary in p.cracks:
		if y < float(crack.from) or y > float(crack.to): continue
		var off := absi(s-int(crack.s))
		off = mini(off,seg-off)
		if off < int(crack.wide):
			var fade := smoothstep(float(crack.from),float(crack.from)+12.0,y)*(1.0-smoothstep(float(crack.to)-12.0,float(crack.to),y))
			r -= float(crack.depth)*fade*(1.0 if off == 0 else 0.45)
	return maxf(r,mean*0.3)

## The cap's height at share `s` of the way out to the rim (1) at angle
## `theta`, over a point `at` (xz).
func cap_y(p: Dictionary, theta: float, s: float, at: Vector2) -> float:
	var t := float(p.top)
	var inner := minf(s,CAP[0])/CAP[0]
	var mean := (float(p.a)+float(p.b))*0.5
	var jag := lerpf(JAG.x,JAG.y,_bedline.get_noise_2d(cos(theta)*mean*1.6+float(p.salt),sin(theta)*mean*1.6)*0.5+0.5)
	var h := t+float(p.dome)*(1.0-inner*inner)+jag*smoothstep(0.55,1.0,inner)+BUMP*_bump.get_noise_2d(at.x,at.y)*(1.0-inner*0.5)
	if s > CAP[0]: h = lerpf(h,t,(s-CAP[0])/(1.0-CAP[0]))
	return h+snap(p,at)

## How far a snapped top falls at a point (xz): nothing on its high side,
## DROP m at its low rim, a little ragged.
func snap(p: Dictionary, at: Vector2) -> float:
	var broken: Vector3 = p.broken
	if broken.z <= 0.0: return 0.0
	var c := axis(p,float(p.top))
	var mean := (float(p.a)+float(p.b))*0.5*float(p.taper)
	var along := Vector2(broken.x,broken.y).dot(at-c)/maxf(mean,1.0)
	return -broken.z*clampf(along*0.5+0.5,0.0,1.0)*(1.0+0.25*_bump.get_noise_2d(at.x*2.0,at.y*2.0))

## A wall vertex's height, its ring's lifted or let down to meet a snapped
## top over the last metres, so the break runs down the wall with it.
func _wall_y(p: Dictionary, y: float, at: Vector2) -> float:
	var broken: Vector3 = p.broken
	if broken.z <= 0.0: return y
	var run := broken.z*2.4
	var from := float(p.top)-run
	if y <= from: return y
	return y+snap(p,at)*(y-from)/run

# --- The bridge -----------------------------------------------------------------

## The bridge's line: from inside one of its pillars to the other, at deck
## height; its underside arches, springing lower and wider at the pillars.
func _bridge_shape() -> void:
	var a: Dictionary = pillars[bridge.a]
	var b: Dictionary = pillars[bridge.b]
	var y := float(bridge.under)+float(bridge.thick)
	bridge.from = axis(a,y)
	bridge.to = axis(b,y)

## The bridge at t (0 to 1 from pillar a's axis to b's): Vector3(underside,
## top, half width).
func bridge_at(t: float) -> Vector3:
	var a: Vector2 = bridge.from
	var b: Vector2 = bridge.to
	var length := a.distance_to(b)
	# Distance in from the nearer pillar's face, roughly: the arch is whole
	# over the gap's middle, springing at its sides.
	var span := float(bridge.span)
	var from_mid := absf(t-0.5)*length
	# The arch: a half ellipse over the gap, springing from the pillars'
	# faces BRIDGE_ARCH lower; the deck sags a little to the middle.
	var u := clampf(from_mid/(span*0.5+3.0),0.0,1.0)
	var under := float(bridge.under)-BRIDGE_ARCH*(1.0-sqrt(maxf(0.0,1.0-u*u)))
	var top_y := float(bridge.under)+float(bridge.thick)+2.5*u*u
	var half := float(bridge.half)*(1.0+0.9*pow(u,3.0))
	return Vector3(under,top_y,half)

# --- The tops' spruces, the mist --------------------------------------------------

func _plant() -> void:
	trees = PackedVector4Array()
	tree_variants = PackedInt32Array()
	tree_leans = PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*17+5
	var moss := _noise(83,1.0/7.0,2,FastNoiseLite.FRACTAL_FBM)
	for i in range(pillars.size()):
		var p: Dictionary = pillars[i]
		var odds := MEADOW_TREE_ODDS if i == meadow else CAP_TREE_ODDS*(0.45 if (p.broken as Vector3).z > 0.0 else 1.0)
		var ys: PackedFloat32Array = p.ys
		var last := ys.size()-1
		var c: Vector2 = (p.centres as PackedVector2Array)[last]
		var reach: float = p.bound
		var x := -reach
		while x < reach:
			var z := -reach
			while z < reach:
				var at := c+Vector2(x,z)+Vector2(rng.randf_range(-0.4,0.4),rng.randf_range(-0.4,0.4))*CAP_TREE_STEP
				z += CAP_TREE_STEP
				var s := _share(p,last,at)
				if s > 0.96 or rng.randf() > odds: continue
				var theta := (at-c).angle()
				var y := cap_y(p,theta,s,at)
				if p.role == "massif" and _buried(i,Vector3(at.x,y+0.3,at.y)): continue
				# Toward the rim, shorter: windswept, clinging to the edge.
				var tall := rng.randf_range(TREE_HEIGHT.x,TREE_HEIGHT.y)*lerpf(1.0,0.35,smoothstep(0.7,0.96,s))
				_tree(Vector3(at.x,y-0.15,at.y),tall,rng)
			x += CAP_TREE_STEP
		var seg: int = p.seg
		var radii: PackedFloat32Array = p.radii
		var centres: PackedVector2Array = p.centres
		var bed_of: PackedInt32Array = p.bed_of
		var hidden: float = p.get("under",-INF)
		var cracked := {}
		for crack: Dictionary in p.cracks: cracked[int(crack.s)] = crack
		for r in range(1,ys.size()-1):
			if ys[r] < SEA+10.0 or ys[r] < hidden+2.0 or ys[r] > float(p.top)-5.0: continue
			for s in range(seg):
				var dir := Vector2.from_angle(TAU*s/seg)
				# Clinging on the ledges: where a bed stands out past the one
				# over it.
				if bed_of[r+1] != bed_of[r]:
					var low := radii[r*seg+s]
					var high := radii[(r+1)*seg+s]
					if low-high >= LEDGE and rng.randf() < LEDGE_TREE_ODDS+0.12*clampf((low-high-1.5)/3.0,0.0,1.0):
						var at := centres[r]+dir*(high+(low-high)*0.55)
						if not _buried(i,Vector3(at.x,ys[r+1],at.y)): _tree(Vector3(at.x,ys[r+1]-0.1,at.y),rng.randf_range(LEDGE_TREE.x,LEDGE_TREE.y),rng)
						continue
				# Out of the cracks and the mossy streaks, little windswept
				# ones leaning out over the drop.
				var in_crack := cracked.has(s) and ys[r] > float(cracked[s].from) and ys[r] < float(cracked[s].to)
				var face := centres[r]+dir*radii[r*seg+s]
				var mossy := moss.get_noise_3d(face.x,ys[r]*0.12,face.y)
				var chance := CRACK_TREE if in_crack else FACE_TREE*smoothstep(0.15,0.45,mossy)
				if rng.randf() >= chance: continue
				var at := centres[r]+dir*(radii[r*seg+s]-0.45)
				if _buried(i,Vector3(at.x,ys[r],at.y)): continue
				var out := Vector3(dir.x,0.0,dir.y)
				_tree(Vector3(at.x,_wall_y(p,ys[r],at),at.y),rng.randf_range(CLING.x,CLING.y),rng,Vector3.UP.cross(out)*rng.randf_range(LEAN_OUT.x,LEAN_OUT.y),CLING_VARIANTS)
		if trees.size() >= TREE_CAP: return
	# A few on the bridge's deck.
	for k in range(rng.randi_range(3,6)):
		var t := rng.randf_range(0.3,0.7)
		var b := bridge_at(t)
		var at := (bridge.from as Vector2).lerp(bridge.to,t)+_across()*rng.randf_range(-0.5,0.5)*b.z
		_tree(Vector3(at.x,b.y-0.2,at.y),rng.randf_range(LEDGE_TREE.y,TREE_HEIGHT.y*0.8),rng)

func _tree(at: Vector3, height: float, rng: RandomNumberGenerator, lean := Vector3.ZERO, variants := TREE_VARIANTS) -> void:
	if trees.size() >= TREE_CAP: return
	trees.append(Vector4(at.x,at.y,at.z,height))
	tree_variants.append(variants[rng.randi() % variants.size()])
	tree_leans.append(lean)

## The way across the bridge (unit, xz).
func _across() -> Vector2:
	var way := ((bridge.to as Vector2)-(bridge.from as Vector2)).normalized()
	return Vector2(-way.y,way.x)

## Mist: a few low puffs where each foot goes into the sea, and thin wisps:
## drawn out round the feet, lying across the gaps between near stands, and
## a few faint layers higher up through the forest.
func _mist() -> void:
	wraps = PackedVector4Array()
	wisps = PackedVector4Array()
	wisp_looks = PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*7+3
	for p: Dictionary in pillars:
		if p.has("under"): continue
		var c := axis(p,SEA)
		var mean := (float(p.a)+float(p.b))*0.5
		# Small puffs ringing the foot just where it goes in, so the rock
		# ends in cloud, not on a line.
		var count := 4+int(mean/6.0)
		var turn := rng.randf()*TAU
		for k in range(count):
			var size := rng.randf_range(WRAP_SIZE.x,WRAP_SIZE.y)
			var at := c+Vector2.from_angle(turn+TAU*k/count+rng.randf_range(-0.3,0.3))*(mean*1.05+size*0.15)
			wraps.append(Vector4(at.x,SEA+rng.randf_range(1.0,6.0),at.y,size))
		for k in range(rng.randi_range(2,3)):
			var length := rng.randf_range(HUG.x,HUG.y)*0.5
			var at := c+Vector2.from_angle(rng.randf()*TAU)*(mean*0.9+length*0.4)
			_wisp(Vector3(at.x,SEA+rng.randf_range(2.0,22.0),at.y),length,rng.randf_range(HUG_THICK.x,HUG_THICK.y)*0.5,rng.randf_range(0.6,0.95),rng)
	for i in range(pillars.size()):
		for j in range(i+1,pillars.size()):
			var p: Dictionary = pillars[i]
			var q: Dictionary = pillars[j]
			if p.group == q.group or p.has("under") or q.has("under"): continue
			var a := axis(p,SEA)
			var b := axis(q,SEA)
			var gap := a.distance_to(b)-float(p.bound)-float(q.bound)
			if gap > MIST_GAP or rng.randf() < 0.3: continue
			var mid := a.lerp(b,(float(p.bound)+gap*0.5)/maxf(a.distance_to(b),1.0))
			var length := clampf(gap+rng.randf_range(10.0,30.0),GAP_WISP.x,GAP_WISP.y)*0.5
			_wisp(Vector3(mid.x,SEA+rng.randf_range(5.0,34.0),mid.y),length,rng.randf_range(GAP_THICK.x,GAP_THICK.y)*0.5,rng.randf_range(0.45,0.8),rng)
			if rng.randf() < 0.3:
				_wisp(Vector3(mid.x+rng.randf_range(-12.0,12.0),SEA+rng.randf_range(38.0,70.0),mid.y+rng.randf_range(-12.0,12.0)),length*0.8,rng.randf_range(GAP_THICK.x,GAP_THICK.y)*0.8,rng.randf_range(0.2,0.35),rng)
	for k in range(LAYERS):
		var at := Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*REACH
		_wisp(Vector3(at.x,rng.randf_range(SEA+40.0,40.0),at.y),rng.randf_range(LAYER.x,LAYER.y)*0.5,rng.randf_range(LAYER_THICK.x,LAYER_THICK.y)*0.5,rng.randf_range(0.15,0.3),rng)

func _wisp(at: Vector3, half: float, thick: float, strength: float, rng: RandomNumberGenerator) -> void:
	wisps.append(Vector4(at.x,at.y,at.z,half))
	wisp_looks.append(Vector3(thick,strength,rng.randf()))

# --- Reading it -----------------------------------------------------------------

## The ring under height y and how far up to the next (index, share).
func _ring_at(p: Dictionary, y: float) -> Vector2:
	var ys: PackedFloat32Array = p.ys
	var last := ys.size()-1
	if y <= ys[0]: return Vector2(0,0.0)
	if y >= ys[last]: return Vector2(last,0.0)
	var k := ys.bsearch(y,true)-1
	k = clampi(k,0,last-1)
	return Vector2(k,(y-ys[k])/maxf(ys[k+1]-ys[k],0.001))

## A ring's radius toward a point `at` (xz), along the straight edge
## between the ring's two vertices either side of it.
func _edge(p: Dictionary, r: int, at: Vector2) -> float:
	var seg: int = p.seg
	var c: Vector2 = (p.centres as PackedVector2Array)[r]
	var theta := fposmod((at-c).angle(),TAU)
	var step := TAU/seg
	var s := int(theta/step) % seg
	var radii: PackedFloat32Array = p.radii
	var r1 := radii[r*seg+s]
	var r2 := radii[r*seg+(s+1) % seg]
	var off := theta-s*step
	return r1*r2*sin(step)/maxf(r1*sin(off)+r2*sin(step-off),1e-5)

## How far out a point lies on ring r: 0 at the axis, 1 at the rock's face.
func _share(p: Dictionary, r: int, at: Vector2) -> float:
	var c: Vector2 = (p.centres as PackedVector2Array)[r]
	return at.distance_to(c)/_edge(p,r,at)

## True if a point (the forest's frame) is in pillar i's rock (or over its
## top within its rim, `capped`).
func inside(i: int, point: Vector3, capped := false) -> bool:
	var p: Dictionary = pillars[i]
	var y := clampf(point.y,FOOT,float(p.top))
	if not capped and point.y > float(p.top): return false
	var at := Vector2(point.x,point.z)
	var near := axis(p,y)
	if at.distance_to(near) > float(p.bound)+2.0: return false
	var k := _ring_at(p,y)
	var r := int(k.x)
	var last := (p.ys as PackedFloat32Array).size()-1
	if r >= last: return _share(p,last,at) <= 1.0
	return lerpf(_share(p,r,at),_share(p,r+1,at),k.y) <= 1.0

## The rock under a point (the forest's frame) as a solid: Vector2(its top's
## height there, its underside), or null in open air. A pillar is solid from
## far under the cloud to its cap; the bridge is a slab with air under it.
func solid_at(point: Vector3) -> Variant:
	var best := -INF
	for i in range(pillars.size()):
		if not inside(i,point,true): continue
		var p: Dictionary = pillars[i]
		var last := (p.ys as PackedFloat32Array).size()-1
		var at := Vector2(point.x,point.z)
		var c: Vector2 = (p.centres as PackedVector2Array)[last]
		var s := _share(p,last,at)
		# Off under its cap (a leaning pillar's side), the cap's height
		# stands for its top: over the point, so it is never ridden onto.
		# Over a clump's body, the highest of its rock there.
		best = maxf(best,cap_y(p,(at-c).angle(),s,at) if s <= 1.0 else float(p.top)+float(p.dome))
	if best > -INF: return Vector2(best,BOTTOM)
	return bridge_solid(point)

## True if a point (the forest's frame) is in the rock of a pillar other
## than `i` (a clump's body and its pillars hide each other's ground).
func _buried(i: int, point: Vector3) -> bool:
	var group: int = pillars[i].group
	for j in range(pillars.size()):
		if j == i or pillars[j].group != group: continue
		if point.y < float(pillars[j].top)+0.5 and inside(j,point,true): return true
	return false

## The bridge's slab over a point (xz), Vector2(top, underside), or null.
func bridge_solid(point: Vector3) -> Variant:
	var a: Vector2 = bridge.from
	var ab: Vector2 = (bridge.to as Vector2)-a
	var at := Vector2(point.x,point.z)
	var t := (at-a).dot(ab)/maxf(ab.length_squared(),1e-4)
	if t < 0.0 or t > 1.0: return null
	var b := bridge_at(t)
	if absf((at-a-ab*t).dot(_across())) > b.z*0.92: return null
	return Vector2(b.y,b.x)

## The ring outline of pillar i at height y as points (xz), for measuring.
func outline(i: int, y: float) -> PackedVector2Array:
	var p: Dictionary = pillars[i]
	var k := _ring_at(p,y)
	var r := int(k.x)
	var last := (p.ys as PackedFloat32Array).size()-1
	var r2 := mini(r+1,last)
	var seg: int = p.seg
	var radii: PackedFloat32Array = p.radii
	var centres: PackedVector2Array = p.centres
	var out := PackedVector2Array()
	for s in range(seg):
		var dir := Vector2.from_angle(TAU*s/seg)
		out.append((centres[r]+dir*radii[r*seg+s]).lerp(centres[r2]+dir*radii[r2*seg+s],k.y))
	return out

## The thread: points (x, y, z) from out past the face, through the slot,
## under the bridge, to over the meadow.
func thread_line(y := THREAD_Y, count := 48) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in range(count):
		var z := lerpf(THREAD_FROM,THREAD_TO,float(k)/(count-1))
		out.append(Vector3(slot_x(y) if z > float(slot.z0)-30.0 else 0.0,y,z))
	return out

## The slot's middle line's x at height y (it leans with its fins).
func slot_x(y: float) -> float:
	return float(slot.lean)*(y-THREAD_Y)

## The thermal off the meadow (its base, the forest's frame).
func thermal_base() -> Vector3:
	var p: Dictionary = pillars[meadow]
	var c := axis(p,float(p.top))
	return Vector3(c.x,THERMAL_BASE,c.y)

## The forest's reach from its middle over the sea's top (m).
func reach() -> float:
	var r := 0.0
	for p: Dictionary in pillars: r = maxf(r,axis(p,SEA).length()+float(p.bound))
	return r

func _noise(salt: int, frequency: float, octaves: int, fractal: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed*13+salt
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.1
	n.fractal_gain = 0.5
	if fractal == FastNoiseLite.FRACTAL_RIDGED: n.fractal_weighted_strength = 0.5
	return n

# --- The mesh -------------------------------------------------------------------

## The forest's faces as surface arrays for the plate's ground material,
## coloured per face from the world's `grass` and `rock` (linear) and its
## `gravel`, every vertex laid `shift` off (SkyPeaks OFF_MAP). Safe on a
## worker.
func body_arrays(grass: Array, rock: Array, gravel: Color, shift := Vector3.ZERO) -> Array:
	var out := Faces.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*31+7
	var look := {"grass":grass,"rock":rock,"gravel":gravel,"strata":SkyPeak._strata_colours(),"rng":rng,
		"mix":_noise(67,1.0/90.0,2,FastNoiseLite.FRACTAL_FBM),"green":_noise(73,1.0/40.0,2,FastNoiseLite.FRACTAL_FBM),
		"streak":_noise(79,1.0/12.0,2,FastNoiseLite.FRACTAL_FBM),"moss":_noise(83,1.0/7.0,2,FastNoiseLite.FRACTAL_FBM)}
	for i in range(pillars.size()): _pillar_faces(i,out,look)
	_bridge_faces(out,look)
	var vertices := out.v
	for k in range(vertices.size()): vertices[k] += shift
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv.resize(vertices.size())
	uv2.resize(vertices.size())
	uv.fill(Vector2(0.0,1.0))
	for k in range(vertices.size()): uv2[k] = Vector2(0.5,vertices[k].y)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = out.n
	arrays[Mesh.ARRAY_COLOR] = out.c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays

func _pillar_faces(i: int, out: Faces, look: Dictionary) -> void:
	var p: Dictionary = pillars[i]
	var ys: PackedFloat32Array = p.ys
	var seg: int = p.seg
	var radii: PackedFloat32Array = p.radii
	var centres: PackedVector2Array = p.centres
	var bed_of: PackedInt32Array = p.bed_of
	var insets: PackedFloat32Array = p.insets
	# Each vertex a little up or down its ring, so the faces are irregular
	# facets, not a grid; never at a bed's chamfer, the foot or the top.
	var last_ring := ys.size()-1
	var vert := func(r: int, s: int) -> Vector3:
		var d := Vector2.from_angle(TAU*(s % seg)/seg)*radii[r*seg+(s % seg)]+centres[r]
		var y := ys[r]
		if r > 0 and r < last_ring and bed_of[r-1] == bed_of[r] and bed_of[r+1] == bed_of[r]:
			var room := minf(ys[r]-ys[r-1],ys[r+1]-ys[r])*0.3
			y += room*_bump.get_noise_2d(float(r)*9.7+float(p.salt),float(s % seg)*13.1)*1.6
		return Vector3(d.x,_wall_y(p,y,d),d.y)
	# A clump's pillars are hidden inside their body up to its top.
	var hidden: float = p.get("under",-INF)-3.0
	for r in range(ys.size()-1):
		if ys[r+1] < CUT or ys[r+1] < hidden: continue
		var c := centres[r].lerp(centres[r+1],0.5)
		var middle := Vector3(c.x,(ys[r]+ys[r+1])*0.5,c.y)
		# Up this ring is a bed's chamfer: a ledge or an overhang.
		var chamfer := bed_of[r] != bed_of[r+1]
		for s in range(seg):
			var a: Vector3 = vert.call(r,s)
			var b: Vector3 = vert.call(r,s+1)
			var d: Vector3 = vert.call(r+1,s+1)
			var e: Vector3 = vert.call(r+1,s)
			var bed := bed_of[r+1] if chamfer else bed_of[r]
			if insets[bed] <= -NOTCH+0.001: bed = -1
			_quad(out,a,b,d,e,middle,look,bed,float(p.top))
	# The cap: rings in from the rim to a middle.
	var last := ys.size()-1
	var c: Vector2 = centres[last]
	var rings := [1.0]
	rings.append_array(CAP)
	var cap_point := func(k: int, s: int) -> Vector3:
		var theta := TAU*(s % seg)/seg
		var share: float = rings[k]
		var at := c+Vector2.from_angle(theta)*radii[last*seg+(s % seg)]*share
		return Vector3(at.x,cap_y(p,theta,share,at),at.y)
	var bed := bed_of[last]
	for k in range(rings.size()-1):
		for s in range(seg):
			var a: Vector3 = cap_point.call(k,s)
			var b: Vector3 = cap_point.call(k,s+1)
			var d: Vector3 = cap_point.call(k+1,s+1)
			var e: Vector3 = cap_point.call(k+1,s)
			_quad(out,a,b,d,e,Vector3(c.x,ys[last]-50.0,c.y),look,bed,float(p.top))
	var mid := Vector3(c.x,cap_y(p,0.0,0.0,c),c.y)
	for s in range(seg):
		_tri(out,cap_point.call(rings.size()-1,s),cap_point.call(rings.size()-1,s+1),mid,Vector3(c.x,ys[last]-50.0,c.y),look,bed,float(p.top))

## The bridge: sections across its line every few metres, a rough rounded
## outline flat on top, from inside one pillar to inside the other.
func _bridge_faces(out: Faces, look: Dictionary) -> void:
	var a: Vector2 = bridge.from
	var b: Vector2 = bridge.to
	var across := _across()
	var stations := maxi(int(a.distance_to(b)/2.5),4)
	var corners := 10
	var bumps := _noise(91,1.0/6.0,2,FastNoiseLite.FRACTAL_FBM)
	var sections := []
	var middles := []
	for k in range(stations+1):
		var t := float(k)/stations
		var bt := bridge_at(t)
		var at := a.lerp(b,t)
		var mid_y := (bt.x+bt.y)*0.5
		var half_h := (bt.y-bt.x)*0.5
		var ring := []
		for m in range(corners):
			var phi := TAU*m/corners
			var lift := clampf(sin(phi)*1.12,-1.0,1.0)
			var wide := cos(phi)*bt.z
			var jitter := bumps.get_noise_2d(t*40.0,m*11.0)*1.1
			var p := at+across*(wide+signf(wide)*jitter)
			ring.append(Vector3(p.x,mid_y+lift*half_h+(jitter*0.6 if lift < 0.99 else jitter*0.25),p.y))
		sections.append(ring)
		middles.append(Vector3(at.x,mid_y,at.y))
	for k in range(stations):
		var middle: Vector3 = (middles[k]+middles[k+1])*0.5
		for m in range(corners):
			var p0: Vector3 = sections[k][m]
			var p1: Vector3 = sections[k][(m+1) % corners]
			var q0: Vector3 = sections[k+1][m]
			var q1: Vector3 = sections[k+1][(m+1) % corners]
			var bed := floori((p0.y-FOOT)/9.0)
			_quad(out,p0,p1,q1,q0,middle,look,bed,float(bridge.under))

## A quad (a, b, d, e round it) out from `inside`, as two faces of one
## colour, so the rock reads facet by facet, not triangle by triangle.
func _quad(out: Faces, a: Vector3, b: Vector3, d: Vector3, e: Vector3, inside: Vector3, look: Dictionary, bed: int, top_y: float) -> void:
	var n := (d-a).cross(e-b)
	var centre := (a+b+d+e)*0.25
	if n.dot(centre-inside) < 0.0: n = -n
	if n.length_squared() < 1e-8: return
	var tone := _tone(centre,n.normalized(),bed,top_y,look)
	_tri(out,a,b,d,inside,look,bed,top_y,tone)
	_tri(out,a,d,e,inside,look,bed,top_y,tone)

## A face out from `inside`, wound clockwise seen from outside (Godot's
## front), coloured (its own colour, unless given one).
func _tri(out: Faces, a: Vector3, b: Vector3, d: Vector3, inside: Vector3, look: Dictionary, bed: int, top_y: float, given := Color(-1.0,0.0,0.0)) -> void:
	var n := (b-a).cross(d-a)
	if n.length_squared() < 1e-8: return
	n = n.normalized()
	var centre := (a+b+d)/3.0
	var outward := centre-inside
	if n.dot(outward) < 0.0:
		var swap := b
		b = d
		d = swap
		n = -n
	var tone := given if given.r >= 0.0 else _tone(centre,n,bed,top_y,look)
	for v in [a,d,b]:
		out.v.append(v)
		out.n.append(n)
		out.c.append(tone)

## A face's colour: grass on the tops and broad ledges, moss-earth on the
## narrow ones; the rock bed by bed in the granite core's three tones and
## now and then a shale band, streaked darker down the flutes, darker under
## an overhang, greened a little in damp patches low down.
func _tone(at: Vector3, n: Vector3, bed: int, top_y: float, look: Dictionary) -> Color:
	var rng: RandomNumberGenerator = look.rng
	var grass: Array = look.grass
	var rock: Array = look.rock
	var strata: Dictionary = look.strata
	var jitter := 1.0+rng.randf_range(-FACE_JITTER,FACE_JITTER)
	var mix_rock := (look.mix as FastNoiseLite).get_noise_3d(at.x,at.y*0.5,at.z)*0.5+0.5
	var mix_green := (look.green as FastNoiseLite).get_noise_3d(at.x,at.y,at.z)*0.5+0.5
	var stone := (rock[0] as Color).lerp(rock[rock.size()-1],smoothstep(0.3,0.7,mix_rock))
	var green := (grass[0] as Color).lerp(grass[2 if grass.size() > 2 else 0],smoothstep(0.25,0.75,mix_green))
	var earthy: Color = (strata.topsoil as Color).lerp(strata.clay,0.35)
	var cap := at.y > top_y-0.6
	# Ledges hold grass and moss in patches a few metres long.
	var moss := (look.moss as FastNoiseLite).get_noise_3d(at.x,at.y,at.z)*0.5+0.5
	if n.y > GRASS_UP and (cap or moss > 0.5):
		# Under the spruces the grass is deep and patched with earth and
		# needles; on a ledge, thinner over the rock.
		var deep := (grass[grass.size()-1] as Color).lerp(earthy,0.35)*0.85
		return green.lerp(deep,0.45+0.45*smoothstep(0.25,0.75,moss)).lerp(stone,0.1 if cap else 0.35)*jitter
	if n.y > EARTH_UP and (cap or moss > 0.58):
		return green.lerp(earthy,0.5).lerp(stone,0.4)*jitter
	# The thin beds' tones, a little wavy, bed by bed through the core's
	# three; now and then a shale band; the soft notched beds darker.
	var minor := floori((at.y+2.0*(look.mix as FastNoiseLite).get_noise_2d(at.x*3.0,at.z*3.0))/MINOR)
	var beds := ["core_a","core_b","core_c"]
	var core_a: Color = strata.core_a
	var tone: Color = strata[beds[posmod(minor*7+(minor >> 2)+seed,3)]]
	var shade := (tone.r+tone.g+tone.b)/(core_a.r+core_a.g+core_a.b)
	if posmod(minor*5+seed,11) == 0: shade *= 0.8
	if bed < 0: shade *= 0.85
	# The bands show in patches and fade out round the rock.
	var showing := smoothstep(-0.2,0.35,(look.mix as FastNoiseLite).get_noise_3d(at.x*2.2,at.y*0.35+float(minor)*13.0,at.z*2.2))
	var colour := stone*lerpf(1.0,shade,BED_TONE*showing)
	if n.y > GRASS_UP: colour *= 1.08
	# Streaks down the faces: rain's dark stains, drawn out up the pillar.
	var streak := (look.streak as FastNoiseLite).get_noise_3d(at.x,at.y*0.06,at.z)
	colour *= lerpf(1.04,0.84,smoothstep(-0.05,0.55,streak))
	# Darker under an overhang, and toward the cloud a little damp-green.
	if n.y < -0.25: colour *= 0.88
	if at.y < top_y-30.0 and mix_green > 0.68: colour = colour.lerp(green*0.8,0.22)
	# Moss in long streaks down the faces, where the little spruces cling
	# (the same field `_plant` reads), thickest out of the cloud's damp.
	var drip := (look.moss as FastNoiseLite).get_noise_3d(at.x,at.y*0.12,at.z)
	var mossy := (grass[grass.size()-1] as Color).lerp(earthy,0.25)*0.62
	colour = colour.lerp(mossy,0.62*smoothstep(0.1,0.42,drip))
	return colour*jitter
