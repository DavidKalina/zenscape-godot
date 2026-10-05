extends RefCounted
## A table mountain of the hidden land far below (a tepui, as Roraima and
## Auyán-tepui stand over the Gran Sabana), risen through the cloud sea:
## sheer, fluted sandstone walls a few hundred metres tall round a slightly
## uneven summit plateau, and off its rim a giant waterfall, a ribbon that
## breaks into spray as it falls and goes into a glowing plume at the sea
## (scripts/sky_tepuis.gd stands it up and draws the water). Like a sky peak
## (scripts/sky_peak.gd) its foot is under the cloud, where the land is.
##
## The shape is a heightfield, height over the tepui's own (x, z), built the
## way a mesa weathers:
##   the outline: a wandering rim (broad lobes and bays), buttresses
##     standing out of it and vertical flutes, round the middle;
##   the walls: sheer, stepping out a little at every one of the rock's
##     beds (in partial bands: where a bed's tread has worn away it lies
##     flush) and at one or two into a broad ledge, and under the sea a
##     talus slope;
##   the plateau: a rolling surface tilted gently toward the fall, weathered
##     by the plate's own stream-power erosion (scripts/terrain_erosion.gd
##     `erode`, in plate units, the walls held fixed so it drains off the
##     rim), with clusters of eroded rock towers (a labyrinth) and the rim
##     crenellated where the gullies reach it;
##   the water: a stream meandering across the plateau from a spring pool,
##     through pools, to a notch in the rim; a tarn spilling over the rim at
##     another notch; each channel cut into banks, the ground flattened
##     round it;
##   the falls' coves: carved last, a sheer amphitheatre under each lip down
##     past the sea, so the water falls free of rock. The great fall's lip
##     throws it out far enough that at glide height there is a flyable gap
##     between the curtain and the cove's back wall (`gap`).
##
## The heightfield is what the glide reads, and the plateau's mesh; the
## walls and the coves are drawn as rings (`body_arrays`), row by row down
## the beds, on the same heights, so the bedding reads as level courses
## round the mesa. Faces are flat and coloured per face from the world's
## strata (scripts/strata.gd), rock and grass: the walls pale rosy-grey
## sandstone warming to buff and ochre in broad stretches, each layer a
## shade apart, long black algae streaks hanging down them, wet and mossy
## in the coves; muted bog-green on the ledges and in the plateau's hollows,
## weathered dark rock on its crowns.
##
## The frame is the tepui's own: its spot on the islands' plane at the
## origin, the great fall pouring off toward +z, heights the world's.

const SkyPeak = preload("res://scripts/sky_peak.gd")
const Erosion = preload("res://scripts/terrain_erosion.gd")
const SEA := SkyPeak.SEA
const BASE := SkyPeak.BASE
const CUT := SkyPeak.CUT
const BOTTOM := SkyPeak.BOTTOM
## The heightfield's half extent (m), the mesh grid's spacing, and the
## erosion grid's points a side.
const HALF := 560.0
const STEP := 3.5
const ERODE_N := 193
const PLATE_CELL := 0.7
## The rim's mean radius (m), its broad lobes (share of the radius, over
## LOBE_WAVE m of rim), its bays (m deep, BAY_WAVE m), buttresses (m out,
## BUTTRESS_WAVE m) and flutes (m, FLUTE_WAVE m). The labyrinth's joints are
## pushed about by WARP m.
const RADIUS := Vector2(360.0,405.0)
const LOBES := 0.08
const LOBE_WAVE := 420.0
const BAY := 55.0
const BAY_WAVE := 170.0
const BUTTRESS := 15.0
const BUTTRESS_WAVE := 62.0
const FLUTE := 2.6
const FLUTE_WAVE := 26.0
const WARP := 9.0
## The plateau: its height at the middle (m), its rise per metre
## away from it, its roll (m, over ROLL_WAVE m) and hummocks (m).
const PLATEAU := Vector2(150.0,168.0)
const TILT := 0.035
const ROLL := 6.0
const ROLL_WAVE := 150.0
const HUMMOCK := 1.6
## The walls' rise per metre out (sheer), and the beds the ledges stand on:
## each a share of the way from the rim down to the sea, their widths (m)
## where the rock holds out a ledge, and the gentle fall of a ledge outward.
## Under the sea, the talus' fall.
const SHEER := 16.0
const LEDGE_AT := [Vector2(0.42,0.55),Vector2(0.86,0.95)]
const LEDGE := Vector2(0.0,40.0)
const LEDGE_FALL := 0.25
## Between the ledges the walls step out a little at every bed, BED_GAP m
## apart, up to BED_JOG m, so the faces read in courses.
const BED_GAP := Vector2(16.0,30.0)
const BED_JOG := 2.2
const TALUS := 1.1
## The beds' tilt (m a metre).
const BED_TILT := Vector2(0.01,0.03)
## The rim's crenels: m deep, over CRENEL_WAVE m, within RIM_BAND m of the
## edge.
const CRENEL := 9.0
const CRENEL_WAVE := 24.0
const RIM_BAND := 14.0
## Rock towers: one tried a TOWER_CELL m cell, standing where the labyrinth's
## noise passes TOWER_ODDS; their radius (m), height (m), and the crags on
## steep ground (m, CRAG_WAVE m).
const TOWER_CELL := 34.0
const TOWER_ODDS := 0.2
const TOWER_RADIUS := Vector2(8.0,17.0)
const TOWER_HEIGHT := Vector2(16.0,42.0)
## The labyrinth: where its noise passes LABYRINTH.x (whole by .y) the
## plateau's rock is split along its joints (JOINT m apart) into blocks
## standing up to BLOCK m proud, the joints opened into fissures FISSURE m
## deep.
const LABYRINTH := Vector2(-0.1,0.2)
const JOINT := 46.0
const BLOCK := 7.0
const FISSURE := 10.0
const TOWER_CLEAR := 26.0
const CRAG := 2.6
const CRAG_WAVE := 18.0
## The plate's erosion, in plate metres (the "plateau" family's, bolder).
const ERODE := {"detail":0.6,"frequency":0.16,"warp":1.3,"slope_ref":1.2,"iterations":40,"k":0.006,
	"channel_area":6.0,"jitter":0.6,"max_cut":1.6,"deposit":0.6,"deposit_slope":0.35,"deposit_cap":0.12}
## The water: channel half width (m), its depth (m) and the bank over the
## water (m); the ground is flattened BANK_REACH m out from the channel.
## The stream's meanders (m across, how many), its pools (how many,
## radius m), the spring pool's radius, the tarn's radius and how far in
## from the rim it lies (m).
const CHANNEL := 3.2
const DEPTH := 1.8
const BANK := 1.4
const BANK_REACH := 10.0
const MEANDER := Vector2(35.0,60.0)
const MEANDERS := Vector2(1.6,2.4)
const POOLS := Vector2i(2,3)
const POOL := Vector2(8.0,14.0)
const SPRING := Vector2(7.0,10.0)
const TARN := Vector2(13.0,18.0)
const TARN_IN := 70.0
## The great fall's cove (half width, depth m) and the small one's; the
## coves' walls' rise per metre out; how hard each lip throws its water
## (m/s off the lip), and where in the band the second fall sits (radians
## from the first).
const COVE := Vector2(62.0,58.0)
## The falls' half widths at the lip (m: great, small).
const FALL_HALF := Vector2(6.3,3.3)
const SMALL_COVE := Vector2(24.0,16.0)
const COVE_SHEER := 30.0
## How far out past the rim the coves run on as slots (m).
const SLOT := 140.0
const THROW := 7.5
const SMALL_THROW := 3.0
const SECOND_TURN := Vector2(1.5,2.3)
## The glide's band (scripts/sky_glide.gd FLOOR to CEILING), and the gap
## (m) the great fall leaves behind its curtain within it at the least.
const GLIDE_BAND := Vector2(-55.0,95.0)
const GAP := 15.0
## The updraft beside the great fall: how far round the rim from it
## (radians past the cove), its radius (m), and how far over the plateau
## it carries (m).
const UPDRAFT_TURN := 0.42
const UPDRAFT_RADIUS := 12.0
const UPDRAFT_OVER := 45.0
## Colours: plateau green where the vegetation's noise passes GREEN_PATCH
## or near water; ledges green under LEDGE_SLOPE; the walls' streaks over
## STREAK_WAVE m of rim; how far a face's colour is nudged.
const GREEN_PATCH := 0.35
const LEDGE_SLOPE := 0.8
const STREAK_WAVE := 7.0
## The walls as rings: their spacing round the rim (m), the face's rows
## between beds (m), the chamfer where a bed steps (m), the band over the
## top in to the plateau (m), the ribs between flutes and the nudges in and
## out (m), the cracks and the thin beds' thickness within a layer (m).
## The rings start at FOOT, under the cut.
const WALL_SEG := 3.5
const WALL_ROW := 7.0
const WALL_CHAMFER := 0.8
const WALL_CAP := 2.0
const WALL_RIB := 0.55
const WALL_NUDGE := 0.35
const CRACKS := 34
const MINOR_BED := 4.0
const FOOT := CUT-12.0
## The beds' thickness on the walls (m).
const BED := 11.0
const FACE_JITTER := 0.04
## Spruces: tried every TREE_STEP m, on ground under TREE_SLOPE, at most
## TREE_CAP; heights (m) and variants (scripts/hero_trees.gd SPRUCE).
const TREE_STEP := 8.0
const TREE_SLOPE := 0.5
const TREE_CAP := 180
const TREE_HEIGHT := Vector2(3.0,6.5)
const TREE_VARIANTS := [0,1,2,3,4]
## The cloud round the foot (as the peaks').
const WRAP_APART := 50.0
const WRAP_SIZE := Vector2(20.0,55.0)
const Strata = preload("res://scripts/strata.gd")

var seed := 0
var nx := 0
var nz := 0
## The mesh grid's heights, row by row (z rows); what the erosion laid down
## (+) or cut (-); the water's level over each point (NAN where dry) and
## how far each point is from the nearest channel's line, as a share of its
## half width; and what each point is (KIND_*).
var heights := PackedFloat32Array()
## The plateau's surface at each point, run on out past the rim (the
## plateau's mesh is cut at the rim from it), and how far each point is
## inside the rim (m).
var surf := PackedFloat32Array()
var rim_d := PackedFloat32Array()
## The heights before the coves were carved (the plateau's mesh and the
## coves' walls read them).
var uncut := PackedFloat32Array()
var settled := PackedFloat32Array()
var water := PackedFloat32Array()
var wet := PackedFloat32Array()
var kinds := PackedByteArray()
const KIND_PLATEAU := 0
const KIND_WALL := 1
const KIND_TOWER := 2
const KIND_COVE := 3
## The highest point; the rim's mean radius; the plateau's height at the
## great lip; the beds' tilt.
var top := 0.0
var radius := 0.0
var plateau := 0.0
var tilt := Vector2.ZERO
## The ledges' levels (m, at the middle); and every bed the walls step at,
## from the rim down: Vector3(level at the middle, the most it steps out
## (m), 1 for a ledge).
var ledges := PackedFloat32Array()
var beds: Array[Vector3] = []
## The water features: streams as lists of {at (x, z), level, half (m)}, the
## first the great fall's, the second the tarn's spill; and pools as
## Vector4(x, z, radius, level).
var streams: Array = []
var pools: Array[Vector4] = []
## The falls: {lip (x, y, z), out (x, z unit), half (m across), throw (m/s),
## drop (m, to the sea), cove (half width, depth), main}.
var falls: Array = []
## The updraft beside the great fall: its foot (x, y, z) and its top (m).
var updraft := Vector3.ZERO
var updraft_top := 0.0
## The cloud round the foot: (x, y, z, radius); spruces: (x, z, height,
## variant).
var wraps := PackedVector4Array()
var trees: Array[Vector4] = []
## The rock towers: (x, z, radius, height over the plateau).
var towers: Array[Vector4] = []

var _rng := RandomNumberGenerator.new()
var _outline: Array = []
var _roll: FastNoiseLite
var _hummock: FastNoiseLite
var _crenel: FastNoiseLite
var _bed_w: FastNoiseLite
var _flute_reach: FastNoiseLite
var _warp: FastNoiseLite
var _laid := {}
var _cove_flute: FastNoiseLite
var _zone: FastNoiseLite
var _joints: FastNoiseLite
var _blocks: FastNoiseLite

static func make(seed_value: int) -> RefCounted:
	var t: RefCounted = new()
	t._shape(seed_value)
	return t

func _shape(seed_value: int) -> void:
	seed = seed_value
	_rng.seed = seed_value
	_plan()
	var coarse := _coarse()
	_fine(coarse)
	_water()
	_coves()
	_measure()
	_wrap()
	_plant()

# --- The plan -----------------------------------------------------------------

func _plan() -> void:
	radius = _rng.randf_range(RADIUS.x,RADIUS.y)
	plateau = _rng.randf_range(PLATEAU.x,PLATEAU.y)
	tilt = Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(BED_TILT.x,BED_TILT.y)
	_outline = [_noise(3,1.0/LOBE_WAVE,2,FastNoiseLite.FRACTAL_FBM),_noise(5,1.0/BAY_WAVE,1,FastNoiseLite.FRACTAL_NONE),
		_noise(7,1.0/BUTTRESS_WAVE,2,FastNoiseLite.FRACTAL_RIDGED),_noise(11,1.0/FLUTE_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)]
	_warp = _noise(13,1.0/120.0,2,FastNoiseLite.FRACTAL_FBM)
	_roll = _noise(17,1.0/ROLL_WAVE,3,FastNoiseLite.FRACTAL_FBM)
	_hummock = _noise(19,1.0/22.0,2,FastNoiseLite.FRACTAL_FBM)
	_crenel = _noise(23,1.0/CRENEL_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)
	_zone = _noise(41,1.0/170.0,2,FastNoiseLite.FRACTAL_FBM)
	_joints = _cells(FastNoiseLite.RETURN_DISTANCE2_SUB)
	_blocks = _cells(FastNoiseLite.RETURN_CELL_VALUE)
	ledges = PackedFloat32Array()
	for k in range(LEDGE_AT.size()):
		var share := _rng.randf_range(LEDGE_AT[k].x,LEDGE_AT[k].y)
		ledges.append(plateau-share*(plateau-SEA))
	_bed_w = _noise(29,1.0/140.0,2,FastNoiseLite.FRACTAL_FBM)
	_flute_reach = _noise(31,1.0/240.0,1,FastNoiseLite.FRACTAL_NONE)
	beds.clear()
	var y := plateau-_rng.randf_range(BED_GAP.x,BED_GAP.y)
	while y > SEA-25.0:
		beds.append(Vector3(y,BED_JOG,0.0))
		y -= _rng.randf_range(BED_GAP.x,BED_GAP.y)
	# Each ledge takes the place of the bed nearest it.
	for level in ledges:
		var nearest := 0
		for k in range(beds.size()):
			if absf(beds[k].x-level) < absf(beds[nearest].x-level): nearest = k
		beds[nearest] = Vector3(level,LEDGE.y,1.0)
	_plan_water()

## The streams, pools and falls: the great fall's lip at the back of its
## cove on the +z side; the stream from a spring on the far side meandering
## to it through its pools; the tarn near the rim a turn round, spilling
## over a notch of its own.
func _plan_water() -> void:
	streams.clear()
	pools.clear()
	falls.clear()
	# The great fall: its cove's mouth on the rim at +z.
	var way := Vector2(0.0,1.0)
	var rim := rim_radius(way)
	var lip_level := _base(way*(rim-COVE.y-15.0))-BANK
	var lip_at := way*(rim-COVE.y-(lip_level-BASE)/COVE_SHEER-0.5)
	# The spring on the far side.
	var turn := _rng.randf_range(-0.6,0.6)
	var source_way := -way.rotated(turn)
	var source := source_way*rim_radius(source_way)*_rng.randf_range(0.5,0.62)
	var across := Vector2(-(lip_at-source).normalized().y,(lip_at-source).normalized().x)
	var amp := _rng.randf_range(MEANDER.x,MEANDER.y)
	var bends := _rng.randf_range(MEANDERS.x,MEANDERS.y)
	var phase := _rng.randf()*TAU
	var line: Array[Vector2] = []
	var count := 90
	for k in range(count+1):
		var t := float(k)/count
		var p := source.lerp(lip_at,t)
		# Meanders, gentle at both ends; the last stretch runs straight to the
		# lip.
		var m := amp*sin(t*PI*bends*2.0+phase)*sin(PI*t)*(1.0-smoothstep(0.82,0.95,t))
		p += across*m
		# Kept well in from the rim.
		var d := inside(p)
		if d < 40.0 and t < 0.9: p -= p.normalized()*(40.0-d)
		line.append(p)
	# The pools along it: widenings where the stream runs gentlest.
	var pool_count := _rng.randi_range(POOLS.x,POOLS.y)
	var pool_at := []
	var pool_r := []
	for k in range(pool_count):
		pool_at.append(lerpf(0.18,0.78,(float(k)+_rng.randf_range(0.2,0.8))/pool_count))
		pool_r.append(_rng.randf_range(POOL.x,POOL.y))
	var spring := _rng.randf_range(SPRING.x,SPRING.y)
	var stream := []
	var level := INF
	for k in range(line.size()):
		var t := float(k)/count
		var half := CHANNEL
		for k2 in range(pool_at.size()):
			var r: float = pool_r[k2]
			var reach := r*1.5/maxf(source.distance_to(lip_at),1.0)
			var bump := clampf(1.0-absf(t-float(pool_at[k2]))/reach,0.0,1.0)
			half = maxf(half,CHANNEL+(r-CHANNEL)*smoothstep(0.0,1.0,bump))
		if k == 0: half = spring
		elif t < 0.06: half = maxf(half,lerpf(float(stream[0].half),CHANNEL,t/0.06))
		# Spreading over the lip's sill to the fall's width.
		half = maxf(half,lerpf(CHANNEL,FALL_HALF.x*0.85,smoothstep(0.9,1.0,t)))
		# Always downhill: never over the ground's bank, and held level across
		# a pool.
		level = minf(level,_base(line[k])-BANK)
		stream.append({"at":line[k],"level":level,"half":half})
	# Level across each pool: its lowest.
	for k in range(stream.size()):
		if float(stream[k].half) > CHANNEL+1.0:
			var j := k
			while j+1 < stream.size() and float(stream[j+1].half) > CHANNEL+1.0: j += 1
			for m in range(k,j+1): stream[m].level = stream[j].level
	# On past the lip a little, so the channel is cut clean through the rim.
	stream.append({"at":lip_at+way*3.0,"level":level,"half":FALL_HALF.x*0.85})
	streams.append(stream)
	var lip_y := level
	falls.append({"lip":Vector3(lip_at.x,lip_y,lip_at.y),"out":way,"half":FALL_HALF.x,"throw":THROW,"drop":lip_y-(SEA-6.0),"cove":COVE,"main":true})
	# The tarn and its spill, a turn round the rim.
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var tway := way.rotated(side*_rng.randf_range(SECOND_TURN.x,SECOND_TURN.y))
	var trim := rim_radius(tway)
	var tr := _rng.randf_range(TARN.x,TARN.y)
	var tarn := tway*(trim-TARN_IN)
	var tlevel := _base(tarn)-BANK
	var slip := tway*(trim-SMALL_COVE.y-(tlevel-BASE)/COVE_SHEER-0.5)
	var spill := []
	for k in range(13):
		var t := float(k)/12.0
		spill.append({"at":tarn.lerp(slip,t),"level":minf(tlevel,_base(tarn.lerp(slip,t))-BANK),"half":tr if k == 0 else (tr*(1.0-smoothstep(0.0,0.4,t))+CHANNEL*smoothstep(0.0,0.4,t))})
	var slevel := INF
	for s: Dictionary in spill:
		slevel = minf(slevel,float(s.level))
		s.level = slevel
	spill.append({"at":slip+tway*3.0,"level":slevel,"half":CHANNEL})
	streams.append(spill)
	falls.append({"lip":Vector3(slip.x,slevel,slip.y),"out":tway,"half":FALL_HALF.y,"throw":SMALL_THROW,"drop":slevel-(SEA-6.0),"cove":SMALL_COVE,"main":false})

## The rim's radius toward `way` (unit, x and z): the lobes, bays,
## buttresses and flutes, read round a circle so they wrap.
func rim_radius(way: Vector2) -> float:
	var c := way*300.0
	var r := radius*(1.0+LOBES*(_outline[0] as FastNoiseLite).get_noise_2d(c.x,c.y))
	r -= BAY*maxf(0.0,(_outline[1] as FastNoiseLite).get_noise_2d(c.x,c.y)-0.15)
	r += BUTTRESS*(_outline[2] as FastNoiseLite).get_noise_2d(c.x,c.y)
	r += FLUTE*(0.35+1.0*maxf(0.0,_flute_reach.get_noise_2d(c.x,c.y)+0.4))*(_outline[3] as FastNoiseLite).get_noise_2d(c.x,c.y)
	return r

## How far a point is inside the rim (m; negative outside), along its way
## out from the middle, so the walls (`wall_out`) stand round the middle as
## rings.
func inside(p: Vector2) -> float:
	var l := p.length()
	if l < 0.001: return radius
	return rim_radius(p/l)-l

## The plateau's lie before the weathering: `plateau` high at the middle,
## rising away from the fall (TILT), rolling.
func _base(p: Vector2) -> float:
	return plateau-TILT*p.y+_roll.get_noise_2d(p.x,p.y)*ROLL

# --- The coarse grid: the plateau, the plate's erosion ------------------------

## The plateau's surface on the erosion grid, weathered by the plate's
## erosion with the walls held fixed, so it drains off the rim. Returns the
## erosion's change and the grid.
func _coarse() -> Dictionary:
	var n := ERODE_N
	var span := HALF*2.0
	var cell := span/float(n-1)
	var corner := -Vector2.ONE*HALF
	var scale := cell/PLATE_CELL
	var plate := PackedFloat64Array()
	plate.resize(n*n)
	var fixed := PackedByteArray()
	fixed.resize(n*n)
	for j in range(n):
		for i in range(n):
			var p := corner+Vector2(i,j)*cell
			var d := inside(p)
			var h := _base(p)+_hummock.get_noise_2d(p.x,p.y)*HUMMOCK if d > 0.0 else _base(p)-SHEER*(-d)
			plate[j*n+i] = h/scale
			fixed[j*n+i] = 1 if d < 6.0 else 0
	var settings := ERODE.duplicate()
	settings.merge({"size":n,"cell":PLATE_CELL,"origin":-float(n-1)*0.5*PLATE_CELL,"seed":seed & 0x7fffffff,
		"edge_inner":1.0e5,"edge_outer":1.0e5+1.0})
	var delta := Erosion.erode(plate,fixed,settings)
	var laid := PackedFloat64Array()
	laid.resize(n*n)
	for c in range(n*n): laid[c] = delta[c]*scale if delta.size() == n*n else 0.0
	return {"laid":laid,"n":n,"corner":corner,"cell":cell}

# --- The mesh grid -------------------------------------------------------------

## Every mesh point: the plateau weathered, the towers, the rim's crenels;
## outside the rim the walls stepping down their ledges to the talus.
func _fine(coarse: Dictionary) -> void:
	nx = int(round(HALF*2.0/STEP))+1
	nz = nx
	heights.resize(nx*nz)
	settled.resize(nx*nz)
	kinds.resize(nx*nz)
	var laid: PackedFloat64Array = coarse.laid
	_laid = coarse
	surf.resize(nx*nz)
	rim_d.resize(nx*nz)
	var crag := _noise(37,1.0/CRAG_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)
	_towers()
	for j in range(nz):
		for i in range(nx):
			var c := j*nx+i
			var p := point(i,j)
			var d := inside(p)
			rim_d[c] = d
			var change := SkyPeak._sample(laid,coarse.n,coarse.corner,coarse.cell,p) if d > -4.0 else 0.0
			settled[c] = change
			var surface := _surface(p,d)
			var kind := KIND_PLATEAU
			surface += _labyrinth(p,d)
			var tower := _tower_at(p)
			if tower > 0.0 and d > 6.0:
				surface += tower
				if tower > 2.0: kind = KIND_TOWER
			surf[c] = surface
			var h := surface
			if d < 0.0:
				h = _walls(p,-d,rim_top(p.normalized()))
				kind = KIND_WALL
			# Crags on the steep: the towers and the walls' faces.
			if kind != KIND_PLATEAU: h += CRAG*(crag.get_noise_2d(p.x,p.y)-0.2)
			heights[c] = h
			kinds[c] = kind
	# The flanks run down to BASE at the grid's edge.
	for j in range(nz):
		for i in range(nx):
			var p := point(i,j)
			var edge := HALF-maxf(absf(p.x),absf(p.y))
			heights[j*nx+i] = minf(heights[j*nx+i],BASE+edge*6.0)

## The plateau's surface at a point `d` m inside the rim: its lie, the
## hummocks, the erosion's change and the rim's crenels, notches down into
## its top near the edge (no towers, no labyrinth).
func _surface(p: Vector2, d: float) -> float:
	var change := SkyPeak._sample(_laid.laid,_laid.n,_laid.corner,_laid.cell,p) if d > -4.0 else 0.0
	var h := _base(p)+_hummock.get_noise_2d(p.x,p.y)*HUMMOCK+change
	var rim := 1.0-smoothstep(0.0,RIM_BAND,d)
	if rim > 0.0: h -= CRENEL*rim*smoothstep(0.15,0.55,_crenel.get_noise_2d(p.x,p.y))
	return h

## The rim's top toward `way` (unit): the plateau's surface at the rim.
func rim_top(way: Vector2) -> float:
	return _surface(way*rim_radius(way),0.0)

## The walls' tiers toward `way` (unit): each bed's Vector4(level, where its
## tread starts and ends (m out from the rim), 1 for a ledge), the beds'
## levels tilted as the rock is (read at the rim), and last the talus's
## (level, -, its foot's start, 0). The face above each tier runs down to
## it, then its tread out to its edge; a ledge's face its own flutes. A bed
## whose tread has worn away stands flush with the face above.
func tiers(way: Vector2, rim_h: float) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var edge := 0.0
	var top_h := rim_h
	var lift := tilt.dot(way*rim_radius(way))
	var at := way*300.0
	for k in range(beds.size()):
		var b := beds[k]
		var level := b.x+lift
		var n := _bed_w.get_noise_2d(at.x+k*173.0,at.y-k*71.0)
		var width := b.y*clampf(n*1.5+0.45,0.0,1.0)
		# Over the rim here (the plateau dips), flush in the face just under
		# it, so every way round has the same beds.
		if level > top_h-3.0:
			level = top_h-3.0-k*0.1
			width = 0.0
		edge += (top_h-level)/SHEER+width
		if b.z > 0.5: edge += FLUTE*0.5*(_outline[3] as FastNoiseLite).get_noise_2d(at.x*1.7+k*91.0,at.y*1.7)
		out.append(Vector4(level,edge-width,edge,b.z))
		top_h = level
	var talus := SEA-40.0+lift
	edge += (top_h-talus)/SHEER
	out.append(Vector4(talus,edge,edge,0.0))
	return out

## The walls `out` m outside the rim under a rim at `rim_h`: the highest of
## the tiers, each a ledge falling gently out to its edge and then a sheer
## face; under the sea the talus.
func _walls(p: Vector2, out: float, rim_h: float) -> float:
	var list := tiers(p.normalized(),rim_h)
	var h := rim_h-SHEER*out
	for k in range(list.size()-1):
		var t := list[k]
		h = maxf(h,minf(t.x-LEDGE_FALL*maxf(0.0,out-t.y),t.x-SHEER*(out-t.z)))
	var talus := list[list.size()-1]
	return maxf(h,minf(talus.x,talus.x-TALUS*(out-talus.z)))

## How far out from the rim (m) the walls stand at height `y`, under a rim
## at `rim_h` with these `tiers`: `_walls` turned about, so the wall rings
## (`wall_arrays`) lie on the heights the glide reads.
static func wall_out(list: Array[Vector4], rim_h: float, y: float) -> float:
	var out := (rim_h-y)/SHEER
	for k in range(list.size()-1):
		var t := list[k]
		if y <= t.x: out = maxf(out,minf(t.y+(t.x-y)/LEDGE_FALL,t.z+(t.x-y)/SHEER))
	var talus := list[list.size()-1]
	if y <= talus.x: out = maxf(out,talus.z+(talus.x-y)/TALUS)
	return out

## The towers: one tried in each TOWER_CELL cell, standing where the
## labyrinth's noise passes TOWER_ODDS, clear of the rim and the water.
func _towers() -> void:
	towers.clear()
	var zone := _zone
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*11+5
	var n := int(ceil(HALF/TOWER_CELL))
	for cj in range(-n,n+1):
		for ci in range(-n,n+1):
			var at := (Vector2(ci,cj)+Vector2(rng.randf_range(0.15,0.85),rng.randf_range(0.15,0.85)))*TOWER_CELL
			var odds := zone.get_noise_2d(at.x,at.y)
			var roll := rng.randf()
			var r := rng.randf_range(TOWER_RADIUS.x,TOWER_RADIUS.y)
			var tall := rng.randf_range(TOWER_HEIGHT.x,TOWER_HEIGHT.y)
			if odds < TOWER_ODDS or roll > smoothstep(TOWER_ODDS,TOWER_ODDS+0.3,odds)*0.9: continue
			if inside(at) < TOWER_CLEAR+r or _near_water(at) < BANK_REACH+r+6.0: continue
			towers.append(Vector4(at.x,at.y,r,tall*(0.6+0.4*smoothstep(TOWER_ODDS,TOWER_ODDS+0.35,odds))))

## The labyrinth's lift at a point `d` m inside the rim: each block of the
## jointed rock a little proud of the plateau, the joints between opened
## into fissures; only where the labyrinth's noise allows and clear of the
## rim (the water's banks are flattened over it later).
func _labyrinth(p: Vector2, d: float) -> float:
	var zone := smoothstep(LABYRINTH.x,LABYRINTH.y,_zone.get_noise_2d(p.x,p.y))*smoothstep(20.0,45.0,d)
	if zone <= 0.0: return 0.0
	var q := p+Vector2(_warp.get_noise_2d(p.x*2.0,p.y*2.0),_warp.get_noise_2d(p.x*2.0+97.0,p.y*2.0-41.0))*WARP*0.7
	var edge := _joints.get_noise_2d(q.x,q.y)+1.0
	var block := _blocks.get_noise_2d(q.x,q.y)*0.5+0.5
	return zone*(BLOCK*block-FISSURE*(1.0-smoothstep(0.08,0.2,edge)))

## The joints' cells (FastNoiseLite's cellular noise, JOINT m apart),
## returning `what`.
func _cells(what: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed*13+59
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 1.0/JOINT
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_jitter = 0.9
	n.cellular_return_type = what
	return n

## How far a point is from the water's lines and pools (m, past their half
## widths).
func _near_water(p: Vector2) -> float:
	var best := INF
	for s: Array in streams:
		for k in range(s.size()-1):
			var a: Vector2 = s[k].at
			var b: Vector2 = s[k+1].at
			var ab := b-a
			var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
			best = minf(best,p.distance_to(a+ab*t)-lerpf(float(s[k].half),float(s[k+1].half),t))
	return best

## The towers' height at a point (m over the plateau): steep sided, a little
## domed, their outlines ragged.
var _tower_rag: FastNoiseLite
var _tower_bins := {}
func _tower_at(p: Vector2) -> float:
	if _tower_rag == null:
		_tower_rag = _noise(43,1.0/9.0,2,FastNoiseLite.FRACTAL_FBM)
		for t: Vector4 in towers:
			var b := Vector2i(floori(t.x/TOWER_CELL),floori(t.y/TOWER_CELL))
			if not _tower_bins.has(b): _tower_bins[b] = []
			_tower_bins[b].append(t)
	var h := 0.0
	var near := []
	var at := Vector2i(floori(p.x/TOWER_CELL),floori(p.y/TOWER_CELL))
	for dz in range(-1,2):
		for dx in range(-1,2): near.append_array(_tower_bins.get(at+Vector2i(dx,dz),[]))
	for t: Vector4 in near:
		var dx := absf(p.x-t.x)
		var dz := absf(p.y-t.y)
		if dx > t.z*1.5 or dz > t.z*1.5: continue
		var d := Vector2(dx,dz).length()/t.z+_tower_rag.get_noise_2d(p.x,p.y)*0.25
		var body := 1.0-smoothstep(0.9,1.04,d)
		h = maxf(h,t.w*body*(1.0-0.05*d*d))
	return h

# --- The water ------------------------------------------------------------------

## Each channel cut into the plateau and the ground round it flattened to
## banks; the water's level over each point where it lies.
func _water() -> void:
	water.resize(nx*nz)
	water.fill(NAN)
	wet.resize(nx*nz)
	wet.fill(INF)
	var best := PackedFloat32Array()
	best.resize(nx*nz)
	best.fill(INF)
	var level_at := PackedFloat32Array()
	level_at.resize(nx*nz)
	var half_at := PackedFloat32Array()
	half_at.resize(nx*nz)
	for s: Array in streams:
		for k in range(s.size()-1):
			var a: Vector2 = s[k].at
			var b: Vector2 = s[k+1].at
			var ha := float(s[k].half)
			var hb := float(s[k+1].half)
			var reach := maxf(ha,hb)+BANK_REACH+2.0
			var lo := cell_of(Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2.ONE*reach)
			var hi := cell_of(Vector2(maxf(a.x,b.x),maxf(a.y,b.y))+Vector2.ONE*reach)
			var ab := b-a
			for j in range(lo.y,hi.y+1):
				for i in range(lo.x,hi.x+1):
					var p := point(i,j)
					var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
					var d := p.distance_to(a+ab*t)
					var half := lerpf(ha,hb,t)
					var c := j*nx+i
					if d-half < best[c]:
						best[c] = d-half
						level_at[c] = lerpf(float(s[k].level),float(s[k+1].level),t)
						half_at[c] = half
	for c in range(nx*nz):
		if best[c] == INF: continue
		var d := best[c]+half_at[c]
		var half := half_at[c]
		var level := level_at[c]
		wet[c] = d/half
		var p := point(c % nx,c/nx)
		# Flattened toward the banks, inside the rim only.
		var keep := smoothstep(half+4.0,half+BANK_REACH,d)
		var bank := maxf(_base(p),level+BANK)
		var flat := lerpf(bank,heights[c],keep)
		if kinds[c] == KIND_PLATEAU or kinds[c] == KIND_TOWER:
			heights[c] = flat
			if keep < 0.5: kinds[c] = KIND_PLATEAU
		# Cut at least a grid cell wide, so a narrow creek is never lost
		# between the grid's points.
		var bed := maxf(half,STEP*1.1)
		if d < bed:
			var depth := DEPTH+(half-CHANNEL)*0.12
			heights[c] = minf(heights[c],level-depth*(1.0-(d/bed)*(d/bed))-0.05)
		if d < half+STEP: water[c] = level

## The coves, carved last: under each lip a sheer amphitheatre from past the
## sea up to the rim, so its fall pours free of rock; their rims crenellated
## but for the notch.
func _coves() -> void:
	_cove_flute = _noise(47,1.0/11.0,2,FastNoiseLite.FRACTAL_RIDGED)
	uncut = heights.duplicate()
	for f: Dictionary in falls:
		var way: Vector2 = f.out
		var rim := rim_radius(way)
		var middle := way*rim
		var size: Vector2 = f.cove
		var across := Vector2(way.y,-way.x)
		var reach := maxf(size.x,size.y)+(plateau+80.0-BASE)/COVE_SHEER+SLOT
		var lo := cell_of(middle-Vector2.ONE*reach)
		var hi := cell_of(middle+Vector2.ONE*reach)
		for j in range(lo.y,hi.y+1):
			for i in range(lo.x,hi.x+1):
				var p := point(i,j)
				var cove := cove_floor(f,p)
				var c := j*nx+i
				if cove < heights[c]:
					heights[c] = cove
					kinds[c] = KIND_COVE
					if not is_nan(water[c]) and cove < water[c]-DEPTH-1.0: water[c] = NAN

## Fall `f`'s cove's floor under a point (x, z): a sheer amphitheatre
## (COVE_SHEER) round the ellipse at the back of the cove, and past the rim
## a slot running on out through the ledges, so none stands as a sliver in
## front of the fall; INF where the cove does not reach.
func cove_floor(f: Dictionary, p: Vector2) -> float:
	var way: Vector2 = f.out
	var middle := way*rim_radius(way)
	var size: Vector2 = f.cove
	var o := p-middle
	var u := o.dot(Vector2(way.y,-way.x))
	var v := -o.dot(way)
	if v < -SLOT: return INF
	var e := sqrt((u/size.x)*(u/size.x)+(v/size.y)*(v/size.y)) if v > 0.0 else absf(u)/size.x
	var out := (e-1.0)*size.y+_cove_wobble(f,u,v)
	return BASE+COVE_SHEER*maxf(0.0,out)

## The flutes down a cove's walls (m, in its floor's run), none at the lip.
func _cove_wobble(f: Dictionary, u: float, v: float) -> float:
	var size: Vector2 = f.cove
	var notch := smoothstep(float(f.half)+2.0,float(f.half)+12.0,absf(u))
	return _cove_flute.get_noise_2d(atan2(u,v)*size.y,0.0)*2.2*notch

## The lowest cove floor under a point over all the falls.
func _coves_floor(p: Vector2) -> float:
	var h := INF
	for f: Dictionary in falls: h = minf(h,cove_floor(f,p))
	return h

# --- Measuring --------------------------------------------------------------------

func _measure() -> void:
	top = -INF
	for h in heights: top = maxf(top,h)
	# The updraft: past the great cove's side, out from the wall until the
	# air round it is open from under the glide's floor.
	var f: Dictionary = falls[0]
	var way: Vector2 = f.out
	var rim := rim_radius(way)
	var side := 1.0 if Vector2(way.y,-way.x).dot(Vector2(falls[1].out)) < 0.0 else -1.0
	var uway := way.rotated(side*(float(f.cove.x)/rim+UPDRAFT_TURN))
	var r := rim_radius(uway)
	var found := uway*(r+60.0)
	while r < HALF-UPDRAFT_RADIUS*2.0:
		var at := uway*r
		var open := true
		for k in range(8):
			var h: Variant = height_at(at+Vector2.from_angle(TAU*k/8.0)*UPDRAFT_RADIUS*1.6)
			if h != null and float(h) > GLIDE_BAND.x-25.0: open = false
		if open and (height_at(at) == null or float(height_at(at)) < GLIDE_BAND.x-25.0):
			found = at+uway*6.0
			break
		r += 3.0
	updraft = Vector3(found.x,GLIDE_BAND.x-15.0,found.y)
	updraft_top = top+UPDRAFT_OVER*0.6

## The cloud round the foot: puffs along the line where the walls go into
## the sea, WRAP_APART apart, set a little out (as SkyPeak `_wrap`), and a
## few in the coves.
func _wrap() -> void:
	wraps = PackedVector4Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*7+3
	var line := SEA+6.0
	var spots := []
	for j in range(1,nz-2,2):
		for i in range(1,nx-2,2):
			var h := heights[j*nx+i]
			if (h-line)*(heights[j*nx+i+2]-line) < 0.0 or (h-line)*(heights[(j+2)*nx+i]-line) < 0.0: spots.append(Vector2i(i,j))
	var order := range(spots.size())
	for k in range(order.size()-1,0,-1):
		var m := rng.randi_range(0,k)
		var t: int = order[k]
		order[k] = order[m]
		order[m] = t
	var kept: Array[Vector2] = []
	for k: int in order:
		var s: Vector2i = spots[k]
		var p := point(s.x,s.y)
		var ok := true
		for q in kept:
			if q.distance_to(p) < WRAP_APART:
				ok = false
				break
		if not ok: continue
		kept.append(p)
		var g := _gradient(heights,s.x,s.y)
		var down := -g.normalized() if g.length() > 0.001 else p.normalized()
		var size := rng.randf_range(WRAP_SIZE.x,WRAP_SIZE.y)
		var at := p+down*size*0.35
		wraps.append(Vector4(at.x,SEA+rng.randf_range(-4.0,6.0)+size*rng.randf_range(0.0,0.3),at.y,size))

## Spruces, few and low: in the plateau's sheltered hollows near the water
## and on the ledges, never on the towers or in the channels.
func _plant() -> void:
	trees.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*17+5
	var stands := _noise(83,1.0/90.0,2,FastNoiseLite.FRACTAL_FBM)
	var z := -HALF+TREE_STEP
	while z < HALF-TREE_STEP:
		var x := -HALF+TREE_STEP
		while x < HALF-TREE_STEP:
			var p := Vector2(x,z)+Vector2(rng.randf_range(-0.45,0.45),rng.randf_range(-0.45,0.45))*TREE_STEP
			x += TREE_STEP
			var c := cell_of(p)
			var ci := c.y*nx+c.x
			if kinds[ci] == KIND_TOWER or kinds[ci] == KIND_COVE or wet[ci] < 1.6: continue
			var h: Variant = height_at(p)
			if h == null or float(h) < GLIDE_BAND.x: continue
			if _gradient(heights,c.x,c.y).length() > TREE_SLOPE: continue
			var near := 1.0-smoothstep(1.6,5.0,wet[ci])
			var on_ledge := kinds[ci] == KIND_WALL
			if stands.get_noise_2d(p.x,p.y)+near*0.6+(0.3 if on_ledge else 0.0) < 0.38: continue
			trees.append(Vector4(p.x,p.y,rng.randf_range(TREE_HEIGHT.x,TREE_HEIGHT.y),TREE_VARIANTS[rng.randi() % TREE_VARIANTS.size()]))
			if trees.size() >= TREE_CAP: return
		z += TREE_STEP

# --- Reading it -------------------------------------------------------------------

func point(i: int, j: int) -> Vector2:
	return Vector2(-HALF+i*STEP,-HALF+j*STEP)

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x+HALF)/STEP)),0,nx-1),clampi(int(floor((p.y+HALF)/STEP)),0,nz-1))

func covers(p: Vector2) -> bool:
	return height_at(p) != null

## The ground's height at a point (the faces as built), or null off the grid
## or where the faces were left out under the sea (as SkyPeak `height_at`).
func height_at(p: Vector2) -> Variant:
	var fx := (p.x+HALF)/STEP
	var fz := (p.y+HALF)/STEP
	if fx < 0.0 or fz < 0.0 or fx >= nx-1 or fz >= nz-1: return null
	var i := int(fx)
	var j := int(fz)
	var u := fx-i
	var v := fz-j
	var h00 := heights[j*nx+i]
	var h10 := heights[j*nx+i+1]
	var h01 := heights[(j+1)*nx+i]
	var h11 := heights[(j+1)*nx+i+1]
	if maxf(maxf(h00,h10),maxf(h01,h11)) < CUT: return null
	if SkyPeak._split(h00,h10,h01,h11):
		if u >= v: return h00+(h10-h00)*u+(h11-h10)*v
		return h00+(h11-h01)*u+(h01-h00)*v
	if u+v <= 1.0: return h00+(h10-h00)*u+(h01-h00)*v
	return h11+(h01-h11)*(1.0-u)+(h10-h11)*(1.0-v)

func _gradient(field: PackedFloat32Array, i: int, j: int) -> Vector2:
	var l := field[j*nx+maxi(i-1,0)]
	var r := field[j*nx+mini(i+1,nx-1)]
	var d := field[maxi(j-1,0)*nx+i]
	var u := field[mini(j+1,nz-1)*nx+i]
	return Vector2((r-l)/(2.0*STEP),(u-d)/(2.0*STEP))

## The tepui's reach from its middle over the sea's top (m).
func reach() -> float:
	var r := 0.0
	for j in range(0,nz,3):
		for i in range(0,nx,3):
			if heights[j*nx+i] > SEA: r = maxf(r,point(i,j).length())
	return r

## Where fall `f`'s water is `d` m under its lip (the tepui's frame): thrown
## off the lip at its throw, falling free.
static func fall_point(f: Dictionary, d: float) -> Vector3:
	var lip: Vector3 = f.lip
	var way: Vector2 = f.out
	var away := float(f.throw)*sqrt(2.0*maxf(d,0.0)/9.81)
	return lip+Vector3(way.x*away,-d,way.y*away)

## The fall's half width (m) `d` m under its lip: it spreads as it falls.
static func fall_half(f: Dictionary, d: float) -> float:
	return float(f.half)*(1.0+d*0.003)+d*0.016

## The fall's half thickness (m) toward and away from the wall.
static func fall_thick(f: Dictionary, d: float) -> float:
	return 1.0+d*0.012

## The flyable gap behind the great fall at height `y`: the open air (m)
## between its curtain's inner face and the rock straight behind it.
func gap(y: float) -> float:
	var f: Dictionary = falls[0]
	var lip: Vector3 = f.lip
	var d := lip.y-y
	var at := fall_point(f,d)
	var way: Vector2 = f.out
	var inner := Vector2(at.x,at.z)-way*fall_thick(f,d)
	var back := inner
	while back.distance_to(inner) < 120.0:
		var h: Variant = height_at(back)
		if h != null and float(h) >= y: break
		back -= way*0.5
	return back.distance_to(inner)

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

# --- The meshes ---------------------------------------------------------------------

## The tepui's faces as surface arrays for the plate's ground material,
## coloured per face from the world's `grass` and `rock` (linear) and its
## `gravel`, laid `shift` off (as SkyPeak `body_arrays`). Safe on a worker.
## Three parts, one surface:
##   the plateau: the heightfield, cut clean at the rim (each face clipped
##     where the rim crosses it), so no grid's staircase shows at the edge;
##   the walls (`_wall_faces`): rings round the middle, row by row down the
##     rock's beds, so the bedding reads as level courses;
##   the coves: round each fall, the heightfield whole, cove, walls and all
##     (the rings stop at the cove's sides, the heightfield's faces running a
##     little under them).
func body_arrays(grass: Array, rock: Array, gravel: Color, shift := Vector3.ZERO) -> Array:
	var look := _look(grass,rock,gravel)
	var out := Faces.new()
	_plateau_faces(out,look)
	_wall_faces(out,look)
	for f: Dictionary in falls: _cove_faces(f,out,look)
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

## Faces as they are laid: positions, normals, colours.
class Faces:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

## The colours and fields every face reads. The walls' sandstone: a pale
## rosy grey, a paler buff, a warm ochre and a cool grey, from the world's
## strata (scripts/strata.gd) and rock, and the black of the algae that
## streak a tepui's walls. Greens muted toward the world's darker foliage,
## as the boggy tops are.
func _look(grass: Array, rock: Array, gravel: Color) -> Dictionary:
	var strata := SkyPeak._strata_colours()
	var stone := (rock[0] as Color).lerp(rock[rock.size()-1],0.5)
	var rose: Color = (strata.core_b as Color).lerp(strata.clay,0.34)
	var buff: Color = (strata.sand as Color).lerp(strata.core_b,0.55)
	var ochre: Color = (strata.sand as Color).lerp(strata.clay,0.45)
	var grey: Color = (strata.core_a as Color).lerp(stone,0.35)
	var greens := []
	for g: Color in grass:
		var lum := (g.r+g.g+g.b)/3.0
		greens.append(g.lerp(Color(lum,lum,lum),0.45).lerp(strata.topsoil,0.15)*0.62)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*31+7
	return {"strata":strata,"stone":stone,"sands":[rose,buff,ochre,rose.lerp(grey,0.5),grey],"algae":(strata.shale_dark as Color)*0.32,
		"greens":greens,"gravel":gravel,"rng":rng,
		"patch":_noise(67,1.0/60.0,3,FastNoiseLite.FRACTAL_FBM),"streak":_noise(73,1.0/STREAK_WAVE,2,FastNoiseLite.FRACTAL_FBM),
		"run":_noise(77,1.0/90.0,1,FastNoiseLite.FRACTAL_NONE),"mix":_noise(79,1.0/45.0,2,FastNoiseLite.FRACTAL_FBM),
		"veg":_noise(89,1.0/55.0,2,FastNoiseLite.FRACTAL_FBM)}

## The plateau's faces: every heightfield triangle cut where it leaves the
## plateau, at the rim and at the coves' edges (the walls are rings).
func _plateau_faces(out: Faces, look: Dictionary) -> void:
	var normals := PackedVector3Array()
	normals.resize(nx*nz)
	var keep := PackedFloat32Array()
	keep.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var c := j*nx+i
			var g := _gradient(uncut,i,j)
			normals[c] = Vector3(-g.x,1.0,-g.y).normalized()
			keep[c] = rim_d[c]
			if rim_d[c] > -STEP*2.0:
				var floor_h := _coves_floor(point(i,j))
				if floor_h < INF: keep[c] = minf(keep[c],(floor_h-uncut[c])/COVE_SHEER)
	for j in range(nz-1):
		for i in range(nx-1):
			var corners := [j*nx+i,j*nx+i+1,(j+1)*nx+i,(j+1)*nx+i+1]
			var ds := []
			var hs := []
			var any := false
			for c: int in corners:
				ds.append(keep[c])
				hs.append(uncut[c] if rim_d[c] >= 0.0 else surf[c])
				any = any or keep[c] >= 0.0
			if not any: continue
			var ps := [_v(i,j,hs[0]),_v(i+1,j,hs[1]),_v(i,j+1,hs[2]),_v(i+1,j+1,hs[3])]
			var tris: Array
			if SkyPeak._split(hs[0],hs[1],hs[2],hs[3]): tris = [[0,3,1],[0,2,3]]
			else: tris = [[0,2,1],[1,2,3]]
			for t: Array in tris:
				var a: Vector3 = ps[t[0]]
				var b: Vector3 = ps[t[1]]
				var d: Vector3 = ps[t[2]]
				var ia: int = corners[t[0]]
				var ib: int = corners[t[1]]
				var id: int = corners[t[2]]
				var n := (b-a).cross(d-a).normalized()
				if n.y < 0.0: n = -n
				var lie := (normals[ia]+normals[ib]+normals[id]+n*1.2).normalized()
				var kind := maxi(kinds[ia],maxi(kinds[ib],kinds[id]))
				if kind == KIND_COVE or kind == KIND_WALL: kind = KIND_PLATEAU
				var tone := _ground_tone((a+b+d)/3.0,lie,(settled[ia]+settled[ib]+settled[id])/3.0,minf(wet[ia],minf(wet[ib],wet[id])),kind,look)
				var poly := _clip([a,b,d],[ds[t[0]],ds[t[1]],ds[t[2]]])
				for k in range(1,poly.size()-1): _tri(out,poly[0],poly[k],poly[k+1],Vector3.UP,tone)

## The part of a triangle (`points`) where `d` (at each corner) is not
## under 0, read as varying straight along its edges.
static func _clip(points: Array, d: Array) -> Array:
	var out := []
	for k in range(3):
		var a: Vector3 = points[k]
		var b: Vector3 = points[(k+1) % 3]
		var da: float = d[k]
		var db: float = d[(k+1) % 3]
		if da >= 0.0: out.append(a)
		if (da >= 0.0) != (db >= 0.0): out.append(a.lerp(b,da/(da-db)))
	return out

## A face wound clockwise seen from the side `facing` points to (Godot's
## front), coloured `tone`, with its own normal.
static func _tri(out: Faces, a: Vector3, b: Vector3, d: Vector3, facing: Vector3, tone: Color) -> void:
	var n := (b-a).cross(d-a)
	if n.length_squared() < 1e-8: return
	n = n.normalized()
	if n.dot(facing) < 0.0:
		var swap := b
		b = d
		d = swap
		n = -n
	for v in [a,d,b]:
		out.v.append(v)
		out.n.append(n)
		out.c.append(tone)

## The rock's layer at a point (x, z) and height `y`: how many beds stand
## over it there (each layer its own sandstone).
func layer_at(p: Vector2, y: float) -> int:
	var lift := tilt.dot(p)
	var k := 0
	for b in beds: k += int(b.x+lift > y)
	return k

## The walls as rings: WALL_SEG m apart round the rim, each ring a row down
## the rock (where a cove's slot cuts through, its faces left out). Down from the rim's top, every
## bed brings three rows: its chamfer's top, its tread's middle and its
## tread's edge with the chamfer under it, so where the rock steps out it
## does so crisply, and where its tread has worn away the rows lie flush in
## the face; between beds the face's rows every WALL_ROW m or so, each
## vertex nudged up or down its row and in or out so the facets are
## irregular. The flutes come down from the rim's own (`rim_radius`), the
## ribs between them wander a little down the face, and cracks open here
## and there. Over the top, a narrow band in from the rim to the plateau's
## cut edge, so no seam shows.
func _wall_faces(out: Faces, look: Dictionary) -> void:
	var seg := int(round(TAU*radius/WALL_SEG))
	var rib := _noise(97,1.0/9.0,2,FastNoiseLite.FRACTAL_RIDGED)
	var nudge := _noise(101,1.0/5.0,1,FastNoiseLite.FRACTAL_NONE)
	# The rows' plan, the same round the whole rim: for each gap between
	# anchors how many face rows, from the beds' levels as drawn.
	var nominal := [plateau]
	for b in beds: nominal.append(b.x)
	nominal.append(SEA-40.0)
	var gaps := []
	for k in range(nominal.size()-1):
		var room: float = float(nominal[k])-float(nominal[k+1])
		gaps.append(maxi(0,int(round(room/(WALL_ROW if float(nominal[k+1]) > SEA-15.0 else WALL_ROW*2.0)))-1))
	var cracks := _cracks(seg)
	var rings := []
	var keys := []
	for s in range(seg+1):
		var theta := TAU*float(s % seg)/seg
		var way := Vector2.from_angle(theta)
		var rho := rim_radius(way)
		var top := rim_top(way)
		var list := tiers(way,top)
		var rows := []
		# The band over the top, then the rim.
		var inner := way*(rho-WALL_CAP)
		rows.append([Vector3(inner.x,_surface(inner,WALL_CAP)+0.06,inner.y),-1,0])
		rows.append([Vector3(way.x*rho,top,way.y*rho),0,0])
		var above := top
		for k in range(list.size()):
			var t := list[k]
			var talus := k == list.size()-1
			var y1 := minf(t.x+WALL_CHAMFER,above-0.5)
			for m in range(gaps[k]):
				var y := lerpf(above,y1,float(m+1)/(gaps[k]+1))
				y += (y1-above)/(gaps[k]+1)*0.28*nudge.get_noise_2d(float(s)*7.3,float(rows.size())*11.0)
				rows.append(_ring_point(way,rho,top,list,y,k,1))
			rows.append(_ring_point(way,rho,top,list,y1,k,2))
			if talus:
				for y: float in [t.x-WALL_CHAMFER,SEA-60.0,FOOT]: rows.append(_ring_point(way,rho,top,list,y,k+1,1))
				break
			var drop := LEDGE_FALL*(t.z-t.y)
			rows.append(_ring_point(way,rho,top,list,t.x-drop*0.5,k+1,3 if t.w > 0.5 else 2))
			var y3 := t.x-drop-WALL_CHAMFER
			rows.append(_ring_point(way,rho,top,list,y3,k+1,2))
			above = y3
		# The ribs and cracks: in or out along the way, face rows only.
		for r in range(2,rows.size()):
			var row: Array = rows[r]
			var at: Vector3 = row[0]
			var push := WALL_RIB*(rib.get_noise_2d(theta*rho/1.0,at.y*0.08)-0.3)
			if int(row[2]) == 1: push += WALL_NUDGE*nudge.get_noise_2d(float(s)*3.1+at.y,at.y*0.7)
			for crack: Vector4 in cracks:
				if absi(s-int(crack.x)) <= 0 and at.y < crack.y and at.y > crack.z: push -= crack.w*smoothstep(crack.z,crack.z+10.0,at.y)*(1.0-smoothstep(crack.y-10.0,crack.y,at.y))
			row[0] = at+Vector3(way.x,0.0,way.y)*push
		var cut := []
		for row: Array in rows:
			var at: Vector3 = row[0]
			cut.append(_coves_floor(Vector2(at.x,at.z)) < at.y-0.3)
		rings.append(rows)
		keys.append(cut)
	var count: int = (rings[0] as Array).size()
	for s in range(seg):
		var a: Array = rings[s]
		var b: Array = rings[s+1]
		if a.size() != count or b.size() != count: continue
		for r in range(count-1):
			var p0: Vector3 = a[r][0]
			var p1: Vector3 = b[r][0]
			var q0: Vector3 = a[r+1][0]
			var q1: Vector3 = b[r+1][0]
			if maxf(maxf(p0.y,p1.y),maxf(q0.y,q1.y)) < CUT: continue
			if keys[s][r] and keys[s+1][r] and keys[s][r+1] and keys[s+1][r+1]: continue
			var centre := (p0+p1+q0+q1)*0.25
			var outward := Vector3(centre.x,0.0,centre.z).normalized()
			var n := (q1-p0).cross(q0-p1)
			if n.dot(outward) < 0.0: n = -n
			if n.length_squared() < 1e-8: continue
			n = n.normalized()
			var tone: Color
			if int(a[r][1]) < 0:
				tone = _ground_tone(centre,Vector3.UP,0.0,INF,KIND_PLATEAU,look)
			else:
				var ledge := int(a[r+1][2]) == 3 or int(a[r][2]) == 3
				tone = _wall_tone(centre,n,int(a[r+1][1]),ledge,false,look)
			var facing := outward if absf(n.y) < 0.7 else Vector3.UP*signf(n.y)
			_tri(out,p0,p1,q1,facing,tone)
			_tri(out,p0,q1,q0,facing,tone)

## A cove's walls, as rings of their own: its path round from the far end
## of the slot on one side, along the slot, round the amphitheatre at the
## back and out along the slot on the other, WALL_SEG m a step; down it rows
## level with the beds (so the layers run on round the cove) and between,
## each row the cove's floor turned about (`cove_floor`: where it stands at
## that height). A row's top is the ground the cove cut into there; rows
## over it fold onto it.
func _cove_faces(f: Dictionary, out: Faces, look: Dictionary) -> void:
	var way: Vector2 = f.out
	var middle := way*rim_radius(way)
	var size: Vector2 = f.cove
	var across := Vector2(way.y,-way.x)
	var path := []
	var slot_n := int(SLOT/WALL_SEG)
	for k in range(slot_n,0,-1): path.append(Vector2(-1.0,-k*WALL_SEG))
	var arc_n := int(PI*(size.x+size.y)*0.5*1.3/WALL_SEG)
	for k in range(arc_n+1): path.append(Vector2(0.0,lerpf(-PI*0.5,PI*0.5,float(k)/arc_n)))
	for k in range(1,slot_n+1): path.append(Vector2(1.0,-k*WALL_SEG))
	var lift := tilt.dot(middle)
	var ys := [plateau+TILT*radius+ROLL+12.0]
	for b in beds:
		var level: float = b.x+lift
		var above: float = ys[ys.size()-1]
		var n := maxi(0,int(round((above-level)/(WALL_ROW if level > SEA-15.0 else WALL_ROW*2.0)))-1)
		for m in range(n): ys.append(lerpf(above,level+WALL_CHAMFER,float(m+1)/(n+1)))
		ys.append(level+WALL_CHAMFER)
		ys.append(level-WALL_CHAMFER)
	for y: float in [SEA-40.0,SEA-60.0,FOOT]: ys.append(y)
	var rings := []
	for entry: Vector2 in path:
		var at := func(y: float) -> Vector2: return _cove_point(f,middle,across,entry,y)
		# The top: the uncut ground where the wall stands, found in a few
		# steps.
		var top := plateau
		for k in range(5):
			var h: Variant = _uncut_at(at.call(top))
			if h == null:
				top = -INF
				break
			top = float(h)
		var rows := []
		for y: float in ys:
			var yy := minf(y,top)
			var q: Vector2 = at.call(yy)
			rows.append(Vector3(q.x,yy,q.y))
		rings.append(rows)
	for k in range(path.size()-1):
		var a: Array = rings[k]
		var b: Array = rings[k+1]
		var entry: Vector2 = path[k]
		for r in range(ys.size()-1):
			var p0: Vector3 = a[r]
			var p1: Vector3 = b[r]
			var q0: Vector3 = a[r+1]
			var q1: Vector3 = b[r+1]
			if maxf(maxf(p0.y,p1.y),maxf(q0.y,q1.y)) < CUT: continue
			var centre := (p0+p1+q0+q1)*0.25
			var inward := (Vector3(middle.x,centre.y,middle.y)-centre) if entry.x == 0.0 else Vector3(across.x,0.0,across.y)*-entry.x
			var n := (q1-p0).cross(q0-p1)
			if n.length_squared() < 1e-6: continue
			if n.dot(inward) < 0.0: n = -n
			var tone := _wall_tone(centre,n.normalized(),layer_at(Vector2(centre.x,centre.z),centre.y),false,true,look)
			_tri(out,p0,p1,q1,inward,tone)
			_tri(out,p0,q1,q0,inward,tone)

## Where a cove's wall stands at height `y` along its path (`entry`: x -1
## or 1 a slot's side with y how far out, 0 the amphitheatre with y its
## angle): `cove_floor` turned about.
func _cove_point(f: Dictionary, middle: Vector2, across: Vector2, entry: Vector2, y: float) -> Vector2:
	var size: Vector2 = f.cove
	var way: Vector2 = f.out
	var run := (y-BASE)/COVE_SHEER
	var u: float
	var v: float
	if entry.x == 0.0:
		var e0 := 1.0+run/size.y
		var e := 1.0+(run-_cove_wobble(f,size.x*e0*sin(entry.y),size.y*e0*cos(entry.y)))/size.y
		u = size.x*e*sin(entry.y)
		v = size.y*e*cos(entry.y)
	else:
		v = entry.y
		var e0 := 1.0+run/size.y
		var e := 1.0+(run-_cove_wobble(f,entry.x*size.x*e0,v))/size.y
		u = entry.x*size.x*e
	return middle+across*u-way*v

## The uncut heights at a point (x, z), read as `height_at` reads, or null
## off the grid.
func _uncut_at(p: Vector2) -> Variant:
	var fx := (p.x+HALF)/STEP
	var fz := (p.y+HALF)/STEP
	if fx < 0.0 or fz < 0.0 or fx >= nx-1 or fz >= nz-1: return null
	var i := int(fx)
	var j := int(fz)
	var u := fx-i
	var v := fz-j
	return lerpf(lerpf(uncut[j*nx+i],uncut[j*nx+i+1],u),lerpf(uncut[(j+1)*nx+i],uncut[(j+1)*nx+i+1],u),v)

## A ring's row: the point toward `way` at height `y` on the walls (rim at
## `rho`, its top `top`, these tiers), its layer and what it is (1 a face
## row, 2 a chamfer's edge, 3 a ledge's tread).
func _ring_point(way: Vector2, rho: float, top: float, list: Array[Vector4], y: float, layer: int, what: int) -> Array:
	var r := rho+wall_out(list,top,y)
	return [Vector3(way.x*r,y,way.y*r),layer,what]

## The cracks: Vector4(ring, top, foot, depth m), a few round the rim.
func _cracks(seg: int) -> Array[Vector4]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*41+9
	var out: Array[Vector4] = []
	for k in range(CRACKS):
		var top := rng.randf_range(plateau-30.0,plateau+10.0)
		out.append(Vector4(rng.randi_range(0,seg-1),top,top-rng.randf_range(60.0,200.0),rng.randf_range(1.5,4.0)))
	return out

func _v(i: int, j: int, h: float) -> Vector3:
	var p := point(i,j)
	return Vector3(p.x,h,p.y)

## A wall face's colour. Each layer of the rock its own sandstone (pale
## rosy grey, buff, ochre or grey, by a hash of the layer), thin beds within
## it a shade lighter or darker; long black streaks of algae hanging down
## from the rim and the treads, broken off here and there; a tread's top
## lit paler, the underside of a step in shadow; a broad ledge carrying
## muted green in soft patches; in a cove wet, darker and mossy; toward the
## cloud a little damp.
func _wall_tone(at: Vector3, n: Vector3, layer: int, ledge: bool, cove: bool, look: Dictionary) -> Color:
	var rng: RandomNumberGenerator = look.rng
	var jitter := 1.0+rng.randf_range(-FACE_JITTER,FACE_JITTER)
	var p := Vector2(at.x,at.z)
	var along := atan2(p.y,p.x)*radius
	# The rock is mostly the pale rosy grey; broad stretches of the wall
	# warm to buff or ochre or cool to grey, and each layer only nudges it.
	var sands: Array = look.sands
	var h := fposmod(sin(float(layer)*12.9898+float(seed % 101)*1.7)*43758.5453,1.0)
	var mix: float = (look.mix as FastNoiseLite).get_noise_2d(along*0.3,at.y*0.2)
	var zone: float = (look.run as FastNoiseLite).get_noise_2d(along*0.35+931.0,at.y*0.15)
	var sand: Color = sands[0]
	sand = sand.lerp(sands[1 if zone > 0.0 else 4],smoothstep(0.1,0.5,absf(zone))*0.6)
	sand = sand.lerp(sands[2],smoothstep(0.35,0.7,zone)*0.5)
	sand = sand.lerp(sands[1+int(h*3.0)],0.22)
	sand *= 1.0+0.07*(h*2.0-1.0)
	var minor := floori((at.y+1.5*mix)/MINOR_BED)
	sand *= 1.0+0.035*(fposmod(float(minor)*0.618,1.0)*2.0-1.0)
	var greens: Array = look.greens
	var green: Color = (greens[0] as Color).lerp(greens[greens.size()-1],smoothstep(-0.3,0.3,mix))
	if n.y > 0.55:
		var veg := (look.veg as FastNoiseLite).get_noise_2d(at.x,at.z)
		if ledge: return sand.lerp(green,smoothstep(-0.35,0.15,veg))*jitter
		return sand.lerp(green,smoothstep(0.2,0.55,veg)*0.6)*1.03*jitter
	var colour := sand
	if n.y > 0.3: colour *= 1.05
	# The algae: long and narrow, hanging from where the water runs off.
	var streak: float = (look.streak as FastNoiseLite).get_noise_2d(along,at.y*0.012)
	var run: float = (look.run as FastNoiseLite).get_noise_2d(along*0.7,at.y)
	var black := smoothstep(0.18,0.48,streak)*smoothstep(-0.25,0.15,run)
	colour = colour.lerp(look.algae,black*0.82)
	if n.y < -0.2: colour *= 0.72
	if cove:
		var wetness := 1.0-smoothstep(SEA,plateau,at.y)*0.6
		colour = colour.lerp((look.algae as Color)*1.6,0.4*wetness).lerp(green,smoothstep(0.0,0.5,mix)*0.3)
	colour = colour.lerp(green*0.9,(1.0-smoothstep(SEA,SEA+60.0,at.y))*smoothstep(0.3,0.6,mix)*0.25)
	return colour*jitter

## A plateau face's colour: the tops weathered dark grey-black, pale gravel
## where the erosion laid it or the crowns are scoured, and the bog's muted
## green in the hollows and by the water, its patches fading over a few
## faces; the towers their layers' sandstone, weathered dark.
func _ground_tone(at: Vector3, lie: Vector3, laid: float, wet_share: float, kind: int, look: Dictionary) -> Color:
	var rng: RandomNumberGenerator = look.rng
	var jitter := 1.0+rng.randf_range(-FACE_JITTER,FACE_JITTER)
	var p := Vector2(at.x,at.z)
	var patch: float = (look.patch as FastNoiseLite).get_noise_2d(p.x,p.y)
	var stone: Color = look.stone
	var dark: Color = (look.sands[4] as Color).lerp(look.algae,0.7)
	var rock := dark.lerp(stone,0.18+0.2*smoothstep(-0.2,0.4,patch))
	var greens: Array = look.greens
	var green: Color = (greens[0] as Color).lerp(greens[greens.size()-1],smoothstep(-0.3,0.3,(look.mix as FastNoiseLite).get_noise_2d(p.x,p.y)))
	var slope := sqrt(maxf(0.0,1.0-lie.y*lie.y))/maxf(lie.y,0.001)
	if kind == KIND_TOWER and slope > LEDGE_SLOPE:
		return _wall_tone(at,lie,layer_at(p,at.y),false,false,look).lerp(dark,0.45)
	var near := 1.0-smoothstep(1.2,3.5,wet_share)
	var veg := (look.veg as FastNoiseLite).get_noise_2d(p.x,p.y)+near*0.8-maxf(laid,0.0)*0.02
	var base := rock
	if laid > 1.0 or veg < -0.42: base = rock.lerp(look.gravel,0.22)
	var colour := base.lerp(green,smoothstep(GREEN_PATCH-0.16,GREEN_PATCH+0.14,veg))
	if slope > LEDGE_SLOPE: colour = colour.lerp(rock,0.6)
	return colour*jitter

## The water's surface arrays over every wet point (the pools, the streams,
## the tarn), each cell a flat quad at its water's level, for the islets'
## pond water (SkyIslet WATER_FORMAT: the fetch toward the shore in eight
## ways, the depth). Laid `shift` off. Safe on a worker.
func water_arrays(color: Color, shift := Vector3.ZERO) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	var ways := [Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1)]
	for j in range(nz-1):
		for i in range(nx-1):
			var c := j*nx+i
			var level := water[c]
			if is_nan(level):
				for o in [1,nx,nx+1]:
					if not is_nan(water[c+o]):
						level = water[c+o]
						break
			if is_nan(level): continue
			var corners := [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]
			# Never out over a drop (the lip, the cove).
			var over := false
			for q: Vector2i in corners: over = over or heights[q.y*nx+q.x] < level-DEPTH-3.0
			if over: continue
			var spots := []
			for q: Vector2i in corners:
				var p := point(q.x,q.y)
				# Each corner at its own level where it has one, so a stream
				# running down slopes smoothly rather than stepping.
				var own := water[q.y*nx+q.x]
				var at_level := level if is_nan(own) else own
				var depth := maxf(at_level-heights[q.y*nx+q.x],0.0)
				var runs := []
				for w: Vector2i in ways:
					var run := 0.0
					for s in range(1,4):
						var k := q+w*s
						if k.x < 0 or k.y < 0 or k.x >= nx or k.y >= nz or is_nan(water[k.y*nx+k.x]) or heights[k.y*nx+k.x] > at_level: break
						run = float(s)*STEP*(1.4142 if w.x != 0 and w.y != 0 else 1.0)
					runs.append(minf(run,9.0))
				spots.append([Vector3(p.x,at_level,p.y),depth,runs])
			for tri in [[0,2,1],[0,3,2]]:
				for k: int in tri:
					var s: Array = spots[k]
					vertices.append((s[0] as Vector3)+shift)
					normals.append(Vector3.UP)
					colors.append(color)
					uv.append(Vector2(float(s[1])*2.5,0.0))
					uv2.append(Vector2(float(s[1]),0.0))
					var r: Array = s[2]
					fetch_a.append_array([r[0],r[1],r[2],r[3]])
					fetch_b.append_array([r[4],r[5],r[6],r[7]])
	if vertices.is_empty(): return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	return arrays

## A fall's ribbon as surface arrays for shaders/sky_tepui_fall.gdshader:
## rows down its course, each row's two vertices on its line (the shader
## turns the ribbon to face the eye about the line), the line's way in the
## normal, UV (side -1 or 1, metres fallen along it), UV2 (half width, share
## of the drop). `widen` scales its width (the spray veil's wider).
static func fall_arrays(f: Dictionary, rows: int, widen := 1.0) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	var drop := float(f.drop)
	var travel := 0.0
	var last := fall_point(f,0.0)
	for r in range(rows+1):
		var share := pow(float(r)/rows,1.5)
		var d := drop*share
		var at := fall_point(f,d)
		var tangent := (fall_point(f,d+0.5)-fall_point(f,maxf(d-0.5,0.0))).normalized()
		travel += at.distance_to(last)
		last = at
		var half := fall_half(f,d)*lerpf(1.0,widen,smoothstep(0.0,0.6,share))
		for side in [-1.0,1.0]:
			vertices.append(at)
			normals.append(tangent)
			uv.append(Vector2(side,travel))
			uv2.append(Vector2(half,share))
		if r > 0:
			var k := r*2
			indices.append_array([k-2,k-1,k,k-1,k+1,k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
