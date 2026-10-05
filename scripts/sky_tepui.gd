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
##     standing out of it and fine vertical flutes, so the walls read as
##     fluted from top to bottom (a heightfield's walls are vertical lines);
##   the walls: sheer, stepping out at one or two of the rock's beds into a
##     ledge (gently tilted, as the beds are; where a ledge is pinched out
##     the walls run on down in one face), and under the sea a talus slope;
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
## Faces are flat and coloured per face from the world's own rock, grass and
## the strata's warm tones (scripts/strata.gd), as the peaks' are: on the
## walls the colour runs in vertical streaks (weathered dark rock, the
## world's grey, warm fresh sandstone), wet and mossy in the coves; green on
## the ledges and in the plateau's hollows, bare dark rock on its crowns.
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
## BUTTRESS_WAVE m) and flutes (m, FLUTE_WAVE m); the outline is pushed
## about by WARP m besides.
const RADIUS := Vector2(360.0,405.0)
const LOBES := 0.08
const LOBE_WAVE := 420.0
const BAY := 55.0
const BAY_WAVE := 170.0
const BUTTRESS := 15.0
const BUTTRESS_WAVE := 62.0
const FLUTE := 3.2
const FLUTE_WAVE := 15.0
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
const CHANNEL := 5.5
const DEPTH := 2.4
const BANK := 1.8
const BANK_REACH := 14.0
const MEANDER := Vector2(35.0,60.0)
const MEANDERS := Vector2(1.6,2.4)
const POOLS := Vector2i(2,3)
const POOL := Vector2(13.0,24.0)
const SPRING := Vector2(11.0,16.0)
const TARN := Vector2(16.0,22.0)
const TARN_IN := 70.0
## The great fall's cove (half width, depth m) and the small one's; the
## coves' walls' rise per metre out; how hard each lip throws its water
## (m/s off the lip), and where in the band the second fall sits (radians
## from the first).
const COVE := Vector2(80.0,58.0)
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
const STREAK_WAVE := 16.0
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
	stream.append({"at":lip_at+way*3.0,"level":level,"half":CHANNEL})
	streams.append(stream)
	var lip_y := level
	falls.append({"lip":Vector3(lip_at.x,lip_y,lip_at.y),"out":way,"half":CHANNEL*1.15,"throw":THROW,"drop":lip_y-(SEA-6.0),"cove":COVE,"main":true})
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
		spill.append({"at":tarn.lerp(slip,t),"level":minf(tlevel,_base(tarn.lerp(slip,t))-BANK),"half":tr if k == 0 else (tr*(1.0-smoothstep(0.0,0.4,t))+CHANNEL*0.6*smoothstep(0.0,0.4,t))})
	var slevel := INF
	for s: Dictionary in spill:
		slevel = minf(slevel,float(s.level))
		s.level = slevel
	spill.append({"at":slip+tway*3.0,"level":slevel,"half":CHANNEL*0.6})
	streams.append(spill)
	falls.append({"lip":Vector3(slip.x,slevel,slip.y),"out":tway,"half":CHANNEL*0.6,"throw":SMALL_THROW,"drop":slevel-(SEA-6.0),"cove":SMALL_COVE,"main":false})

## The rim's radius toward `way` (unit, x and z): the lobes, bays,
## buttresses and flutes, read round a circle so they wrap.
func rim_radius(way: Vector2) -> float:
	var c := way*300.0
	var r := radius*(1.0+LOBES*(_outline[0] as FastNoiseLite).get_noise_2d(c.x,c.y))
	r -= BAY*maxf(0.0,(_outline[1] as FastNoiseLite).get_noise_2d(c.x,c.y)-0.15)
	r += BUTTRESS*(_outline[2] as FastNoiseLite).get_noise_2d(c.x,c.y)
	r += FLUTE*(0.35+1.0*maxf(0.0,_flute_reach.get_noise_2d(c.x,c.y)+0.4))*(_outline[3] as FastNoiseLite).get_noise_2d(c.x,c.y)
	return r

## How far a point is inside the rim (m; negative outside), read at the
## point pushed about by WARP.
func inside(p: Vector2) -> float:
	var q := p+Vector2(_warp.get_noise_2d(p.x,p.y),_warp.get_noise_2d(p.x+311.0,p.y-173.0))*WARP
	var l := q.length()
	if l < 0.001: return radius
	return rim_radius(q/l)-l

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
	var crag := _noise(37,1.0/CRAG_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)
	_towers()
	for j in range(nz):
		for i in range(nx):
			var c := j*nx+i
			var p := point(i,j)
			var d := inside(p)
			var change := SkyPeak._sample(laid,coarse.n,coarse.corner,coarse.cell,p) if d > -4.0 else 0.0
			settled[c] = change
			var surface := _base(p)+_hummock.get_noise_2d(p.x,p.y)*HUMMOCK+change
			var kind := KIND_PLATEAU
			# The rim's crenels: notches down into its top near the edge.
			var rim := 1.0-smoothstep(0.0,RIM_BAND,d)
			if rim > 0.0: surface -= CRENEL*rim*smoothstep(0.15,0.55,_crenel.get_noise_2d(p.x,p.y))
			surface += _labyrinth(p,d)
			var tower := _tower_at(p)
			if tower > 0.0 and d > 6.0:
				surface += tower
				if tower > 2.0: kind = KIND_TOWER
			var h := surface
			if d < 0.0:
				h = _walls(p,-d,surface)
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

## The walls `out` m outside the rim under a rim at `rim_h`: the highest of
## the beds' tiers, each a ledge falling gently out to its edge and then a
## sheer face; under the sea the talus.
func _walls(p: Vector2, out: float, rim_h: float) -> float:
	var h := rim_h-SHEER*out
	var edge := 0.0
	var top_h := rim_h
	var lift := tilt.dot(p)
	var way := p.normalized()*300.0
	for k in range(beds.size()):
		var b := beds[k]
		var level := b.x+lift
		var n := _bed_w.get_noise_2d(way.x+k*173.0,way.y-k*71.0)
		var width := b.y*clampf(n*1.5+0.45,0.0,1.0)
		# The face above runs down to this bed, then its tread out to its
		# edge; a ledge's face its own flutes.
		edge += (top_h-level)/SHEER+width
		if b.z > 0.5: edge += FLUTE*0.5*(_outline[3] as FastNoiseLite).get_noise_2d(way.x*1.7+k*91.0,way.y*1.7)
		var from := edge-width
		h = maxf(h,minf(level-LEDGE_FALL*maxf(0.0,out-from),level-SHEER*(out-edge)))
		top_h = level
	var talus := SEA-40.0+lift
	edge += (top_h-talus)/SHEER
	h = maxf(h,minf(talus,talus-TALUS*(out-edge)))
	return h

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
	var q := p+Vector2(_warp.get_noise_2d(p.x*2.0,p.y*2.0),_warp.get_noise_2d(p.x*2.0+97.0,p.y*2.0-41.0))*6.0
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
		if d < half:
			var depth := DEPTH+(half-CHANNEL)*0.12
			heights[c] = minf(heights[c],level-depth*(1.0-(d/half)*(d/half))-0.05)
		if d < half+STEP: water[c] = level

## The coves, carved last: under each lip a sheer amphitheatre from past the
## sea up to the rim, so its fall pours free of rock; their rims crenellated
## but for the notch.
func _coves() -> void:
	var flute := _noise(47,1.0/11.0,2,FastNoiseLite.FRACTAL_RIDGED)
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
				var o := p-middle
				var u := o.dot(across)
				var v := -o.dot(way)
				if v < -SLOT: continue
				# Past the rim the cove runs on out as a slot through the
				# ledges, so none stands as a sliver in front of the fall.
				var e := sqrt((u/size.x)*(u/size.x)+(v/size.y)*(v/size.y)) if v > 0.0 else absf(u)/size.x
				var a := atan2(u,v)
				var notch := smoothstep(float(f.half)+2.0,float(f.half)+12.0,absf(u))
				var out := (e-1.0)*size.y+flute.get_noise_2d(a*size.y,0.0)*2.2*notch
				var cove := BASE+COVE_SHEER*maxf(0.0,out)
				var c := j*nx+i
				if cove < heights[c]:
					heights[c] = cove
					kinds[c] = KIND_COVE
					if not is_nan(water[c]) and cove < water[c]-DEPTH-1.0: water[c] = NAN

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
func body_arrays(grass: Array, rock: Array, gravel: Color, shift := Vector3.ZERO) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*31+7
	var fields := [_noise(67,1.0/60.0,3,FastNoiseLite.FRACTAL_FBM),_noise(73,1.0/STREAK_WAVE,2,FastNoiseLite.FRACTAL_FBM),
		_noise(79,1.0/45.0,2,FastNoiseLite.FRACTAL_FBM),_noise(89,1.0/55.0,2,FastNoiseLite.FRACTAL_FBM)]
	var normals := PackedVector3Array()
	normals.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var g := _gradient(heights,i,j)
			normals[j*nx+i] = Vector3(-g.x,1.0,-g.y).normalized()
	var strata := SkyPeak._strata_colours()
	var vertices := PackedVector3Array()
	var normal_list := PackedVector3Array()
	var colour_list := PackedColorArray()
	for j in range(nz-1):
		for i in range(nx-1):
			var c00 := j*nx+i
			var c10 := c00+1
			var c01 := c00+nx
			var c11 := c01+1
			var h00 := heights[c00]
			var h10 := heights[c10]
			var h01 := heights[c01]
			var h11 := heights[c11]
			if maxf(maxf(h00,h10),maxf(h01,h11)) < CUT: continue
			var p00 := _v(i,j,h00)
			var p10 := _v(i+1,j,h10)
			var p01 := _v(i,j+1,h01)
			var p11 := _v(i+1,j+1,h11)
			var tris: Array
			if SkyPeak._split(h00,h10,h01,h11): tris = [[p00,p11,p10,c00,c11,c10],[p00,p01,p11,c00,c01,c11]]
			else: tris = [[p00,p01,p10,c00,c01,c10],[p10,p01,p11,c10,c01,c11]]
			for t: Array in tris:
				var a: Vector3 = t[0]
				var b: Vector3 = t[1]
				var d: Vector3 = t[2]
				var ia: int = t[3]
				var ib: int = t[4]
				var id: int = t[5]
				var n := (b-a).cross(d-a).normalized()
				if n.y < 0.0:
					var swap := b
					b = d
					d = swap
					var turn := ib
					ib = id
					id = turn
					n = -n
				var lie := (normals[ia]+normals[ib]+normals[id]+n*1.2).normalized()
				var kind := maxi(kinds[ia],maxi(kinds[ib],kinds[id]))
				var tone := _tone((a+b+d)/3.0,lie,n,(settled[ia]+settled[ib]+settled[id])/3.0,minf(wet[ia],minf(wet[ib],wet[id])),kind,grass,rock,gravel,strata,fields,rng)
				for q in [[a,ia],[d,id],[b,ib]]:
					vertices.append((q[0] as Vector3)+shift)
					normal_list.append(normals[q[1]])
					colour_list.append(tone)
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv.resize(vertices.size())
	uv2.resize(vertices.size())
	uv.fill(Vector2(0.0,1.0))
	for k in range(vertices.size()): uv2[k] = Vector2(0.5,vertices[k].y)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normal_list
	arrays[Mesh.ARRAY_COLOR] = colour_list
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays

func _v(i: int, j: int, h: float) -> Vector3:
	var p := point(i,j)
	return Vector3(p.x,h,p.y)

## A face's colour. On the walls and towers the rock runs in vertical
## streaks, read round the rim and barely changing with height (water and
## lichen stain a tepui's walls top to bottom): weathered dark rock, the
## world's grey, and warm fresh sandstone where a slab has come away, with
## the beds lightening and darkening it faintly; in the coves the rock is
## wet, dark and mossy. Gentle ground: green on the ledges, and on the
## plateau green in the hollows and near water, bare dark rock and pale
## gravel on the crowns.
func _tone(at: Vector3, lie: Vector3, face: Vector3, laid: float, wet_share: float, kind: int, grass: Array, rock: Array, gravel: Color, strata: Dictionary, fields: Array, rng: RandomNumberGenerator) -> Color:
	var slope := sqrt(maxf(0.0,1.0-lie.y*lie.y))/maxf(lie.y,0.001)
	var p := Vector2(at.x,at.z)
	var patch: float = (fields[0] as FastNoiseLite).get_noise_2d(p.x,p.y)
	var jitter := 1.0+rng.randf_range(-FACE_JITTER,FACE_JITTER)
	var stone := (rock[0] as Color).lerp(rock[rock.size()-1],smoothstep(-0.3,0.3,patch))
	var dark := (strata.shale_dark as Color).lerp(stone,0.3)*0.55
	var warm: Color = (strata.clay as Color).lerp(strata.topsoil,0.4).lerp(stone,0.35)
	var green := (grass[0] as Color).lerp(grass[2 if grass.size() > 2 else 0],smoothstep(-0.3,0.3,(fields[2] as FastNoiseLite).get_noise_2d(p.x,p.y)))
	var moss := green.lerp(dark,0.35)
	if slope < LEDGE_SLOPE and kind != KIND_COVE:
		if kind == KIND_WALL:
			# A ledge: green, thinning to earth at its lip.
			return moss.lerp(green,0.3).lerp(stone,0.2+0.4*smoothstep(0.4,LEDGE_SLOPE,slope))*jitter
		# The plateau: bare dark rock, pale gravel where the erosion laid it
		# or the crowns are scoured, and green bog in the hollows and by the
		# water.
		var near := 1.0-smoothstep(1.2,3.5,wet_share)
		var veg := (fields[3] as FastNoiseLite).get_noise_2d(p.x,p.y)+near*0.8-maxf(laid,0.0)*0.02
		if veg > GREEN_PATCH: return green.lerp(moss,0.55+0.3*smoothstep(0.0,-0.4,patch))*jitter
		if laid > 1.0 or veg < -0.42: return gravel.lerp(dark,0.5)*jitter
		return dark.lerp(stone,0.25+0.25*smoothstep(-0.2,0.4,patch))*jitter
	# The walls: the beds in faint bands (each its own tone, tilted as the
	# beds are), long vertical joints read round the rim, and blots of warm
	# fresh sandstone where slabs have come away.
	var along := atan2(p.y,p.x)*radius
	var bed_at := 0
	for bk in beds: bed_at += int(bk.x+tilt.dot(p) > at.y)
	var bed_tone := fposmod(sin(float(bed_at)*12.9898+float(seed % 101))*43758.5453,1.0)*2.0-1.0
	var joint: float = (fields[1] as FastNoiseLite).get_noise_2d(along,at.y*0.025)
	var blot: float = (fields[2] as FastNoiseLite).get_noise_2d(along*0.6,at.y*0.9)
	var tone := dark.lerp(stone,clampf(0.2+0.22*bed_tone+0.28*smoothstep(-0.35,0.35,joint),0.0,1.0))
	tone = tone.lerp(warm,smoothstep(0.28,0.6,blot)*0.75)
	if kind == KIND_COVE:
		var wetness := 1.0-smoothstep(SEA,plateau,at.y)*0.5
		tone = tone.lerp(dark*0.8,0.45*wetness).lerp(moss,smoothstep(0.0,0.5,joint)*0.35)
	if slope < 1.6 and kind == KIND_TOWER: tone = tone.lerp(moss,0.3)
	return tone*jitter

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
