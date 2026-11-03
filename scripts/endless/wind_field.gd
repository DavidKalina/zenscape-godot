extends RefCounted
## The wind over the land by place and hour (docs/design/endless-flight/
## spec-wild-wind.md): how strong the wind blows at a point now, in the
## isles' 0..2 strength the shaders read as zs_wind_strength.
##
##   strength = DAY curve (the hour) x the day's temper (calm, breezy,
##              gusty, rolled per day from the land seed)
##              x (the place's exposure + the drifting patches)
##              x a slow breath (its depth the temper's)
##
## The exposure comes from the land's shape, baked once over the whole world
## (the coast's rounded square and its sea ring) at CELL m: ridges, tops and
## high open ground windy, valley floors and hollows sheltered, open water
## and its shores windy. Patches: PATCHES broad windy blobs drifting downwind
## across the world at PATCH_SPEED m/s, each fading out in the open sea
## before it wraps round, so nothing pops.
##
## Everything here is a function of the land seed, the hour, the day and the
## wind's clock (seconds), so the same seed and time give the same wind on
## every machine. `wind_at(x, z)` is the query for GDScript (the plane, the
## sound, the leaves); the shaders get the baked exposure and the patches'
## blobs (shaders/wind_field.gdshaderinc, published by EndlessLook).
##
## Flags: --wind=calm|breezy|gusty (every day's temper), --wind=X (strength
## X everywhere, no hour, no place), --wind=off (the old single wind, the
## mood's), --wind-map (the field's map in the top-right corner).

const Field = preload("res://scripts/endless/land_field.gd")
const TreePlan = preload("res://scripts/endless/tree_plan.gd")

## The bake's cell (m) and how far past the coast's half side it reaches.
const CELL := 125.0
const SEA_RING := 2500.0
## Exposure: open water's, and the rise over the land round (m) that makes
## a full ridge or a full hollow.
const OPEN_WATER := 0.85
const RIDGE := 30.0
const HOLLOW := 20.0
## The woods' shelter: a cell all dense forest takes FOREST_SHELTER off its
## exposure (a grove's clump GROVE_SHELTER of that), the woods' share blurred
## FOREST_REACH cells each way so their lee and their clearings are calmer too.
## A forested ridge still blows (its ridge term is larger). --wind-forest=0 none.
const FOREST_SHELTER := 0.3
const GROVE_SHELTER := 0.4
const FOREST_REACH := 1
## Past the bake the field gives way to the world's own wind over this (m).
const REACH_FADE := 3000.0
## The day's curve: [hour, share of the peak], round the clock (Catmull-Rom,
## wrapping): still at dawn, building through the morning to an afternoon
## peak, easing through golden hour and dusk, near still in the blue hour.
const DAY := [[0.0,0.05],[4.0,0.04],[6.0,0.06],[8.0,0.22],[10.0,0.5],[12.0,0.78],[14.5,1.0],[16.5,0.86],[18.0,0.52],[19.5,0.22],[21.0,0.09],[23.0,0.05]]
## The tempers: [name, scale, breath depth, odds].
const TEMPERS := [["calm",0.45,0.10,0.3],["breezy",0.85,0.18,0.45],["gusty",1.25,0.32,0.25]]
## The strength at the peak hour, on a breezy day, at full exposure.
const PEAK := 1.3
## The floor a sheltered spot keeps of the local wind (exposure 0).
const SHELTER := 0.12
## The patches: how many, their radius range (m), what they add (share of
## PEAK), their drift (m/s) and the span they wrap round (m, downwind).
const PATCHES := 5
const PATCH_R := Vector2(1800.0,3200.0)
const PATCH_ADD := 0.55
const PATCH_SPEED := 7.0
const PATCH_SPAN := 28000.0
## The heading's wander (rad) and its period's rate.
const WANDER := 0.35
const WANDER_RATE := 0.013

## The mode: "field" (the default), "fixed" (--wind=X), "off" (--wind=off).
var mode := "field"
var fixed := 0.75
## A forced temper index (--wind=calm...), -1: rolled per day.
var forced_temper := -1
var land_seed := 0
## The wind's heading at no wander (rad), from the seed as EndlessLook had it.
var base_angle := 0.0
## The bake: origin (x, z of cell 0), cells each way, exposure 0..1, heights.
var origin := Vector2.ZERO
var n := 0
var exposure := PackedFloat32Array()
var heights := PackedFloat32Array()
var water := PackedByteArray()
var baked := false
var bake_ms := 0.0
var grid_ms := 0.0
var forest_ms := 0.0
## The woods' share a cell (0..1, before the blur; empty: no shelter), and the
## share of FOREST_SHELTER they take off (--wind-forest=X).
var forest := PackedFloat32Array()
var forest_shelter := FOREST_SHELTER
## The woods' flags (LandTrees.flags: on, share, meadows), read on the main thread.
var _woods := {}
## The bake's worker task (-1: none), and how far the field has come in
## since it landed (0..1 over FADE_IN s: the world's own wind gives way).
var _task := -1
var _in := 0.0
const FADE_IN := 4.0
## Now: the wind's clock (s), the hour (0..24), the day (count of cycles).
var clock := 0.0
var hour := 12.0
var day := 0
## Share of the cycle into the day (0..1): the temper eases in from the
## day before over the first TEMPER_EASE of it (the blue hour's still).
var day_share := 0.5
const TEMPER_EASE := 0.12
## This frame's: the global factor (curve x temper x breath) and the
## patches' blobs (x, z, radius, amount 0..1).
var now := 1.0
var blobs: Array[Vector4] = []
var heading := 0.0
var direction := Vector2.RIGHT

static func wanted_mode(args: PackedStringArray) -> String:
	for a: String in args:
		if a == "--wind=off": return "off"
	return "field"

func setup(seed_value: int, field: RefCounted, args: PackedStringArray) -> void:
	land_seed = seed_value
	base_angle = float(absi(hash(seed_value))%6283)/1000.0
	for a: String in args:
		if a.begins_with("--wind-forest="): forest_shelter = maxf(0.0,float(a.get_slice("=",1)))*FOREST_SHELTER
		if not a.begins_with("--wind="): continue
		var v := a.get_slice("=",1)
		if v == "off": mode = "off"
		elif v.is_valid_float():
			mode = "fixed"
			fixed = maxf(v.to_float(),0.0)
		else:
			for i in TEMPERS.size():
				if TEMPERS[i][0] == v: forced_temper = i
	if mode == "field" and field != null:
		var e: Vector4 = field.edge()
		var centre := Vector2(e.x,e.y) if e.z > 0.0 else Vector2.ZERO
		var half := (e.z if e.z > 0.0 else 8500.0)+SEA_RING
		n = int(ceil(2.0*half/CELL))+1
		origin = centre-Vector2(half,half)
		_woods = (load("res://scripts/endless/land_trees.gd") as GDScript).call("flags")
		# On a worker (about 1.4 s over the doors world's blend): the world's
		# own wind blows till it lands.
		_task = WorkerThreadPool.add_task(bake.bind(field))
	step(0.0,clock,hour,day,day_share)

## Wait for the bake (a driver; the game polls in `step`).
func finish_bake() -> void:
	if _task < 0: return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	baked = true
	_in = 1.0

## Bake the exposure over the world's square (`origin`, `n`): the land's
## heights without halls, tunnels and splits (as LandHorizon bakes them), its
## ponds and the Peak's massif.
func bake(field: RefCounted) -> void:
	var t0 := Time.get_ticks_usec()
	var got: Dictionary = field._grid(origin.x,origin.y,CELL,n,n)
	var ps: Array = field.ponds_in(origin.x,origin.y,origin.x+n*CELL,origin.y+n*CELL)
	if not ps.is_empty(): Field.Ponds.apply_grid(got,ps,origin.x,origin.y,CELL,n,n,0)
	field.peak_grid(got,origin.x,origin.y,CELL,n,n)
	grid_ms = float(Time.get_ticks_usec()-t0)/1000.0
	heights = got.heights
	var rivers: PackedFloat32Array = got.get("river",PackedFloat32Array())
	water.resize(n*n)
	var sea_y: float = Field.SEA_Y
	for k in n*n:
		var wet := heights[k] < sea_y+1.0
		# The river's (a pond's) edge distance: under 0 on its water.
		if not wet and k < rivers.size() and rivers[k] < 0.0: wet = true
		water[k] = 1 if wet else 0
	# Where the ground stands over its neighbourhood (a ridge, a top) or
	# under it (a valley floor, a hollow), at two reaches (about 600 m and
	# 2 km across).
	# The water's flat top, not its floor, counts round a shore.
	var top := heights.duplicate()
	for k in n*n: top[k] = maxf(top[k],sea_y)
	var near := _blur(top,2)
	var far := _blur(top,8)
	var wet_f := PackedFloat32Array()
	wet_f.resize(n*n)
	for k in n*n: wet_f[k] = float(water[k])
	var open := _blur(wet_f,2)
	var raw := PackedFloat32Array()
	raw.resize(n*n)
	for k in n*n:
		var h := heights[k]
		if water[k] == 1:
			raw[k] = OPEN_WATER
			continue
		var rise := (h-near[k])*0.5+(h-far[k])*0.5
		var ridge := smoothstep(2.0,RIDGE,rise)
		var hollow := smoothstep(-2.0,-HOLLOW,rise)
		var high := smoothstep(sea_y+40.0,sea_y+400.0,h)
		raw[k] = 0.38+0.55*ridge+0.3*high+0.45*open[k]-0.4*hollow
	if forest_shelter > 0.0:
		_bake_forest(field)
		var lee := _blur(forest,FOREST_REACH)
		for k in n*n:
			if water[k] == 0: raw[k] -= forest_shelter*lee[k]
	for k in n*n: raw[k] = clampf(raw[k],0.0,1.0)
	# A cell's blur, so ridges read as bands, not specks.
	exposure = _blur(raw,1)
	bake_ms = float(Time.get_ticks_usec()-t0)/1000.0

## The woods' share of each land cell (TreePlan's mask at its middle: the dense
## woods all, a grove's clump GROVE_SHELTER), from the land's shape there.
func _bake_forest(field: RefCounted) -> void:
	var t0 := Time.get_ticks_usec()
	forest.resize(n*n)
	forest.fill(0.0)
	var f := _woods
	if not bool(f.get("on",false)):
		forest = PackedFloat32Array()
		return
	var plan: RefCounted = TreePlan.new(land_seed,float(f.share))
	plan.meadows = float(f.meadows)
	for j in range(1,n-1):
		for i in range(1,n-1):
			var k := j*n+i
			if water[k] == 1: continue
			var x := origin.x+i*CELL
			var z := origin.y+j*CELL
			var s: Dictionary = field.shape(x,z)
			# None on the Peak's massif (TreePlan.area), and the up over the
			# plan's own slot, so its steep ground stays bare here too.
			if s.has("peak"): continue
			var h := float(s.height)
			var gx: float = (float(field.height(x+TreePlan.SLOT,z))-h)/TreePlan.SLOT
			var gz: float = (float(field.height(x,z+TreePlan.SLOT))-h)/TreePlan.SLOT
			var up := 1.0/sqrt(1.0+gx*gx+gz*gz)
			var m: Vector3 = plan.mask(field,x,z,s,up)
			forest[k] = clampf(m.x+m.y*GROVE_SHELTER,0.0,1.0)
	forest_ms = float(Time.get_ticks_usec()-t0)/1000.0

## A box blur `r` cells each way (running sums along rows, then columns).
func _blur(src: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(n*n)
	var out := PackedFloat32Array()
	out.resize(n*n)
	var w := 1.0/float(2*r+1)
	for j in n:
		var row := j*n
		var s := 0.0
		for d in range(-r,r+1): s += src[row+clampi(d,0,n-1)]
		for i in n:
			tmp[row+i] = s*w
			s += src[row+mini(i+r+1,n-1)]-src[row+maxi(i-r,0)]
	for i in n:
		var s := 0.0
		for d in range(-r,r+1): s += tmp[clampi(d,0,n-1)*n+i]
		for j in n:
			out[j*n+i] = s*w
			s += tmp[mini(j+r+1,n-1)*n+i]-tmp[maxi(j-r,0)*n+i]
	return out

## One frame: the clock, the hour (0..24), the day count and the share of
## the cycle into it.
func step(delta: float, at_clock: float, at_hour: float, at_day: int, share: float, delta_real := 0.0) -> void:
	clock = at_clock+delta if delta > 0.0 else at_clock
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		baked = true
	if baked: _in = minf(_in+delta_real/FADE_IN,1.0)
	hour = at_hour
	day = at_day
	day_share = share
	heading = base_angle+WANDER*sin(clock*WANDER_RATE)
	direction = Vector2(cos(heading),sin(heading))
	var t := temper_now()
	var breath := 1.0-t.y+t.y*(0.5+0.5*sin(clock*0.21)*sin(clock*0.077)+0.5*sin(clock*0.53)*sin(clock*0.31))
	now = day_curve(hour)*t.x*breath
	_place_blobs()

## The share of the peak at `h` (0..24).
static func day_curve(h: float) -> float:
	var x := fposmod(h,24.0)
	var k := DAY.size()
	var i := 0
	while i < k-1 and float(DAY[i+1][0]) <= x: i += 1
	var a: Array = DAY[i]
	var b: Array = DAY[(i+1)%k]
	var span := fposmod(float(b[0])-float(a[0]),24.0)
	var f := fposmod(x-float(a[0]),24.0)/span
	var p0 := float(DAY[(i-1+k)%k][1])
	var p3 := float(DAY[(i+2)%k][1])
	var p1 := float(a[1])
	var p2 := float(b[1])
	# Catmull-Rom (the keys near even, so the uniform form holds).
	var f2 := f*f
	var f3 := f2*f
	return maxf(0.5*(2.0*p1+(-p0+p2)*f+(2.0*p0-5.0*p1+4.0*p2-p3)*f2+(-p0+3.0*p1-3.0*p2+p3)*f3),0.0)

## A 32-bit integer mix (the same on every machine, unlike `hash`).
static func mix(a: int, b: int, c := 0) -> int:
	var h := (a*374761393+b*668265263+c*2246822519+0x27d4eb2f) & 0xffffffff
	h = ((h ^ (h >> 15))*0x2c1b3c6d) & 0xffffffff
	h = ((h ^ (h >> 12))*0x297a2d39) & 0xffffffff
	return h ^ (h >> 15)

## 0..1 from a mix.
static func unit(a: int, b: int, c := 0) -> float:
	return float(mix(a,b,c) & 0xffffff)/float(0xffffff)

## Day `d`'s temper index (TEMPERS), rolled from the seed.
func temper_index(d: int) -> int:
	if forced_temper >= 0: return forced_temper
	var r := unit(land_seed,d,77)
	for i in TEMPERS.size():
		r -= float(TEMPERS[i][3])
		if r <= 0.0: return i
	return TEMPERS.size()-1

func temper_name(d := day) -> String:
	return str(TEMPERS[temper_index(d)][0])

## (scale, breath depth) now: yesterday's easing into today's after midnight.
func temper_now() -> Vector2:
	var a: Array = TEMPERS[temper_index(day-1)]
	var b: Array = TEMPERS[temper_index(day)]
	var w := smoothstep(0.0,TEMPER_EASE,day_share)
	return Vector2(lerpf(float(a[1]),float(b[1]),w),lerpf(float(a[2]),float(b[2]),w))

func _place_blobs() -> void:
	blobs.clear()
	var centre := origin+Vector2(n,n)*CELL*0.5
	var along_dir := Vector2(cos(base_angle),sin(base_angle))
	var across_dir := Vector2(-along_dir.y,along_dir.x)
	for i in PATCHES:
		var run := unit(land_seed,i,11)*PATCH_SPAN+PATCH_SPEED*clock
		var lap := int(floor(run/PATCH_SPAN))
		var along := fposmod(run,PATCH_SPAN)-PATCH_SPAN*0.5
		var across := (unit(land_seed,i*31+lap,13)*2.0-1.0)*9000.0
		var r := lerpf(PATCH_R.x,PATCH_R.y,unit(land_seed,i*31+lap,17))
		var amount := 1.0-smoothstep(0.32,0.5,absf(along)/PATCH_SPAN)
		var at := centre+along_dir*along+across_dir*across
		blobs.append(Vector4(at.x,at.y,r,amount))

## The baked exposure at (x, z), 0..1 (bilinear; 0.5 before the bake, the
## bake easing in over FADE_IN s once it lands).
func exposure_at(x: float, z: float) -> float:
	if not baked: return 0.5
	var k := smoothstep(0.0,1.0,_in)
	if k < 1.0: return lerpf(0.5,_exposure_at(x,z),k)
	return _exposure_at(x,z)

## How far the baked exposure has come in (0..1): the shaders' zs_wind_field.y.
func come_in() -> float:
	return smoothstep(0.0,1.0,_in) if baked else 0.0

func _exposure_at(x: float, z: float) -> float:
	var u := (x-origin.x)/CELL
	var v := (z-origin.y)/CELL
	if u < 0.0 or v < 0.0 or u > n-1 or v > n-1: return 0.8
	var i := mini(int(u),n-2)
	var j := mini(int(v),n-2)
	var fu := u-i
	var fv := v-j
	var a := lerpf(exposure[j*n+i],exposure[j*n+i+1],fu)
	var b := lerpf(exposure[(j+1)*n+i],exposure[(j+1)*n+i+1],fu)
	return lerpf(a,b,fv)

## How far (x, z) is inside the bake's land (1) rather than past it (0, past
## REACH_FADE m beyond the bake's square): there the world's own wind holds
## (the doors' amberlands half). Before the bake lands the field blows with an
## even exposure (exposure_at), so nothing pops when it does.
func reach(x: float, z: float) -> float:
	if mode == "fixed" or n < 2: return 1.0
	var half := (n-1)*CELL*0.5
	var c := origin+Vector2(half,half)
	var d := maxf(absf(x-c.x),absf(z-c.y))-half
	return 1.0-smoothstep(0.0,REACH_FADE,d)

## The shaders' zs_wind_rect: x, z of the exposure texture's corner, its side
## (m; cell k's centre at origin + k CELL), the bake's half side.
func rect() -> Vector4:
	return Vector4(origin.x-CELL*0.5,origin.y-CELL*0.5,n*CELL,(n-1)*CELL*0.5)

## The baked exposure as a texture (n x n, R8, cell centres at texel centres).
func texture() -> ImageTexture:
	if not baked or n < 2: return null
	var bytes := PackedByteArray()
	bytes.resize(n*n)
	for k in n*n: bytes[k] = clampi(int(round(exposure[k]*255.0)),0,255)
	return ImageTexture.create_from_image(Image.create_from_data(n,n,false,Image.FORMAT_R8,bytes))

## The breeze plants lean in (zs_breeze's scale; 0.53 a light day) for wind
## strength `w` (shaders/wind_field.gdshaderinc zs_wind_breeze_of).
static func breeze_of(w: float) -> float:
	return clampf(0.06+0.7*w,0.06,1.8)

## How far grass blows as one (a share of the world's grass_swell) for wind
## strength `w` (zs_wind_swell_of): calm grass stands, windy grass rolls.
static func swell_of(w: float) -> float:
	return smoothstep(0.25,0.95,w)

## The patches' windiness at (x, z) now, 0..1.
func patch_at(x: float, z: float) -> float:
	var p := 0.0
	for b in blobs:
		var dx := x-b.x
		var dz := z-b.y
		p += b.w*exp(-(dx*dx+dz*dz)/(b.z*b.z))
	return minf(p,1.0)

## The patches' sum round (x, z) to second order, for the shaders' near
## reads (wind_field.gdshaderinc zs_wind_spots_near): [Vector4(x, z, sum,
## d2/dxdz), Vector4(d/dx, d/dz, d2/dx2, d2/dz2)], unclamped. The blobs are
## 1800 m and more across, so within 400 m it is the sum to under 0.007 a blob.
func spots_near(x: float, z: float) -> Array[Vector4]:
	var s := 0.0
	var g := Vector2.ZERO
	var hxx := 0.0
	var hzz := 0.0
	var hxz := 0.0
	for b in blobs:
		var dx := x-b.x
		var dz := z-b.y
		var r2 := b.z*b.z
		var f := b.w*exp(-(dx*dx+dz*dz)/r2)
		s += f
		g += Vector2(dx,dz)*(-2.0*f/r2)
		var k := 4.0*f/(r2*r2)
		hxx += k*dx*dx-2.0*f/r2
		hzz += k*dz*dz-2.0*f/r2
		hxz += k*dx*dz
	return [Vector4(x,z,s,hxz),Vector4(g.x,g.y,hxx,hzz)]

## The wind's strength at (x, z) now (zs_wind_strength's scale).
func wind_at(x: float, z: float) -> float:
	if mode == "fixed": return fixed
	var place := lerpf(SHELTER,1.0,exposure_at(x,z))+PATCH_ADD*patch_at(x,z)
	return PEAK*now*place

## The wind's heading now (unit xz).
func direction_at(_x: float, _z: float) -> Vector2:
	return direction
