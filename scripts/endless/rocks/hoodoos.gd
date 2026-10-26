extends "res://scripts/endless/rocks/rock_kind.gd"
## Hoodoos (a rock kind, scripts/endless/rocks/rock_plan.gd): eroded pillars
## with caps, crowded in pockets of badland on valley floors and sides,
## laid out as slalom fields.
##
## A pocket is an ellipse (POCKET half length along, POCKET_WIDE across),
## its long way down the valley on a floor, along the slope's contour on a
## side. A lane winds down its length (TOY_LANE clear, swinging LANE_SWING
## of the half width across): the safe line through. The rest is darted
## full of hoodoos (DARTS tries, MOST at most), each kept TOY_GAP (its own
## roll) off its neighbours' surfaces at their widest: the riskier lines
## between them. They stand tallest in the pocket's middle and shrink to
## its rim. None on a meadow (its flat stays a flat), in a river or on
## ground steeper than STEEP; the pocket's own middle is no meadow either.
##
## The shape (`--hoodoo-shape=`): `squat` (Drumheller: a short stem waisted
## under a broad flat cap), `tall` (Bryce: tall banded spires, a small cap
## or a point), a number from 0 (squat) to 1 (tall), or `mix` (the
## default: each pocket one end or the other).

const WorldScale = preload("res://scripts/world_scale.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const ArchPlan = preload("res://scripts/endless/arch_plan.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## Tries a cell at density 1, and the chance a fitting spot takes a pocket.
const TRIES := 3
const TAKE := 0.45
## The pocket (m: half length, half width), its lane (toy width clear),
## how far the lane swings (share of the half width) and its wavelength
## (shares of the half length).
const POCKET := Vector2(110.0,210.0)
const POCKET_WIDE := Vector2(60.0,105.0)
const TOY_LANE := Vector2(12.0,16.0)
const LANE_SWING := Vector2(0.12,0.32)
const LANE_WAVE := Vector2(1.0,1.6)
## The gaps between hoodoos (toy widths; squat stands wider, their broad
## caps stand at the plane's height), the darts thrown, the most kept, the
## fewest a pocket needs.
const TOY_GAP_SQUAT := Vector2(7.0,12.0)
const TOY_GAP := Vector2(5.5,10.0)
## Clumps: the pocket's hoodoos crowd round CLUMPS spots (CLUMP_R m, shares
## of the half width), so it reads as stands to thread with glades between;
## a dart away from them takes with LONER's chance.
const CLUMPS := Vector2i(3,6)
const CLUMP_R := Vector2(0.6,1.0)
const LONER := 0.18
## Families: a dart that lands on one neighbour (its middle FUSED of their
## widest apart) grows into it, FUSE of the time (two at most a hoodoo):
## one rock, no gap between them to fly.
const FUSE := 0.35
const FUSED := Vector2(0.55,0.85)
const DARTS := 900
const MOST := 55
const FEWEST := 8
## Where they may stand: the most meadow, the steepest ground (rise per
## m), the least height over the sea (m), the land's mountain share.
const MEADOW_MOST := 0.12
const STEEP := 0.75
const ABOVE_SEA := 8.0
const MOUNTAIN := Vector2(0.02,0.75)
## Squat (0) to tall (1): height (m), stem radius (m), the cap's radius over
## the stem's, the bands' swell, the waist under the cap.
const HEIGHT := Vector2(17.0,38.0)
const STEM := Vector2(4.8,3.6)
const CAP := Vector2(1.7,1.25)
const BANDS := Vector2(0.04,0.2)
const WAIST := Vector2(0.25,0.1)
## The chance a tall one wears a cap (else it ends in a point).
const TALL_CAPPED := 0.65
## The weathering's push (rock_build.gd), and the most it adds to a radius.
const LUMPS := 0.08
const GRAIN := 0.04
const LEDGES := 0.06
const FLUTES := 0.07
const NOISE := 0.26
## Where --rock-start puts the plane: this far back along the lane (m),
## this high over the ground.
const START_BACK := 380.0
const START_ALT := 14.0

## The shape knob: a number 0..1, or -1 for each pocket its own end.
static var shape: float = _shape_flag()

static func _shape_flag() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--hoodoo-shape="):
			var v := a.get_slice("=",1)
			if v == "squat": return 0.0
			if v == "tall": return 1.0
			if v == "mix": return -1.0
			return clampf(float(v),0.0,1.0)
	return -1.0

static func plan_cell(field: RefCounted, cx: int, cz: int, density: float, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var tries := int(round(TRIES*density))
	for t in range(tries):
		var a := rng.randf_range(POCKET.x,POCKET.y)
		var x := (cx+0.0)*cell+rng.randf_range(a*0.5+20.0,cell-a*0.5-20.0)
		var z := (cz+0.0)*cell+rng.randf_range(a*0.5+20.0,cell-a*0.5-20.0)
		var roll := rng.randf()
		var sub := RandomNumberGenerator.new()
		sub.seed = rng.randi()
		if not out.is_empty() or roll > TAKE: continue
		var h: float = field.height(x,z)
		if h < Field.SEA_Y+ABOVE_SEA+4.0: continue
		var s: Dictionary = field.shape(x,z)
		var m := float(s.mountain)
		if m < MOUNTAIN.x or m > MOUNTAIN.y or float(s.meadow) > 0.05 or float(s.inland) < 0.85: continue
		var spec := _pocket(field,x,z,a,s,sub)
		if not spec.is_empty(): out.append(spec)
	return out

## A pocket's tallness: the knob, or one end or the other.
static func _tallness(rng: RandomNumberGenerator) -> float:
	if shape >= 0.0: return shape
	return rng.randf_range(0.0,0.2) if rng.randf() < 0.5 else rng.randf_range(0.8,1.0)

## A pocket of half length `a` round (x, z).
static func _pocket(field: RefCounted, x: float, z: float, a: float, s: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := rng.randf_range(POCKET_WIDE.x,POCKET_WIDE.y)
	# Its long way: down the valley on its floor, along the contour on a side.
	var axis := Vector2.ZERO
	if float(s.valley) < float(s.half)*1.2:
		var across: Vector2 = s.across
		axis = Vector2(-across.y,across.x)
	else:
		axis = ArchPlan._contour(field,x,z,a)
	if axis.length_squared() < 0.01: axis = Vector2.RIGHT
	axis = axis.normalized()
	var side := Vector2(-axis.y,axis.x)
	var t := _tallness(rng)
	var swing := b*rng.randf_range(LANE_SWING.x,LANE_SWING.y)
	var wave := a*rng.randf_range(LANE_WAVE.x,LANE_WAVE.y)
	var phase := rng.randf()*TAU
	var lane := WorldScale.opening(rng.randf_range(TOY_LANE.x,TOY_LANE.y))*0.5
	var centre := Vector2(x,z)
	var clumps: Array = []
	for k in range(rng.randi_range(CLUMPS.x,CLUMPS.y)):
		clumps.append(Vector3(rng.randf_range(-a,a)*0.85,rng.randf_range(-b,b)*0.85,b*rng.randf_range(CLUMP_R.x,CLUMP_R.y)))
	var placed: Array = []   # [XZ, widest, gap, rim share, size roll, ground, fused]
	for _dart in range(DARTS):
		if placed.size() >= MOST: break
		var u := rng.randf_range(-a,a)
		var w := rng.randf_range(-b,b)
		var rho := (u*u)/(a*a)+(w*w)/(b*b)
		var gap := WorldScale.opening(rng.randf_range(lerpf(TOY_GAP_SQUAT.x,TOY_GAP.x,t),lerpf(TOY_GAP_SQUAT.y,TOY_GAP.y,t)))
		var size_roll := rng.randf()
		var keep_roll := rng.randf()
		if rho > 1.0: continue
		var near := 0.0
		for cl: Vector3 in clumps: near = maxf(near,exp(-(Vector2(u-cl.x,w-cl.y).length_squared())/(cl.z*cl.z)))
		if keep_roll > maxf(near,LONER): continue
		var rim := 1.0-rho
		var widest := _widest(t,rim,size_roll)
		var lane_w := swing*sin(u/wave*TAU+phase)
		if absf(w-lane_w) < lane+widest: continue
		var q := centre+axis*u+side*w
		var ok := true
		var fused := -1
		var fuse_roll := rng.randf()
		for i in range(placed.size()):
			var o: Array = placed[i]
			var d := (o[0] as Vector2).distance_to(q)
			if d >= widest+float(o[1])+maxf(gap,float(o[2])): continue
			var share := d/(widest+float(o[1]))
			if fused < 0 and fuse_roll < FUSE and share > FUSED.x and share < FUSED.y and int(o[6]) < 2: fused = i
			else:
				ok = false
				break
		if not ok: continue
		var got: Vector2 = field.sample(q.x,q.y)
		if got.y > MEADOW_MOST or got.x < Field.SEA_Y+ABOVE_SEA: continue
		if float(field.last_river) < Field.RIVER_CLEAR+widest+4.0: continue
		var gx: float = float(field.height(q.x+3.0,q.y))-got.x
		var gz: float = float(field.height(q.x,q.y+3.0))-got.x
		if Vector2(gx,gz).length()/3.0 > STEEP: continue
		if fused >= 0: placed[fused][6] = int(placed[fused][6])+1
		placed.append([q,widest,gap,rim,size_roll,got.x,1 if fused >= 0 else 0])
	if placed.size() < FEWEST: return {}
	var pos := Vector3(x,float(field.height(x,z)),z)
	var pillars: Array = []
	var reach := 0.0
	for o: Array in placed:
		var q: Vector2 = o[0]
		pillars.append(_hoodoo(field,pos,q,t,float(o[3]),float(o[4]),rng))
		reach = maxf(reach,q.distance_to(centre)+float(o[1])*1.6)
	var yaw := atan2(-axis.y,axis.x)
	var spec := {"pos":pos,"reach":reach,"pillars":pillars,"form":"squat" if t < 0.5 else "tall","tallness":t,
		"axis":axis,"half":Vector2(a,b),"lane":lane,"lane_wave":Vector3(swing,wave,phase),"bare":true,"foot":_keepouts(centre,axis,yaw,a,b)}
	# The approach: down the pocket's long way, from past its end.
	var way := axis if rng.randf() < 0.5 else -axis
	var start := centre-way*(a+START_BACK)
	# High enough over the start to clear the ground on the way in.
	var g0: float = maxf(float(field.height(start.x,start.y)),Field.SEA_Y)
	var high := g0
	var d := 0.0
	while d < START_BACK:
		var q := start+way*d
		high = maxf(high,float(field.height(q.x,q.y)))
		d += 20.0
	spec["approach"] = {"at":start,"heading":rad_to_deg(atan2(way.x,-way.y)),"alt":maxf(START_ALT,high-g0+START_ALT)}
	return spec

## The trees kept out of the pocket: strips across it every STRIP m, each
## an arch box with no span (tree_plan.gd `_by_arch`: 18 m either side of
## its line, its half width plus 18 across; no approach lane).
const STRIP := 30.0
static func _keepouts(centre: Vector2, axis: Vector2, yaw: float, a: float, b: float) -> Array:
	var out: Array = []
	var u := -a
	while u <= a+0.1:
		var k := clampf(u/a,-1.0,1.0)
		var c := centre+axis*u
		out.append([c,cos(yaw),sin(yaw),0.0,b*sqrt(1.0-k*k)+10.0])
		u += STRIP
	return out

## A hoodoo's sizes at tallness `t`, `rim` (1 the pocket's middle, 0 its
## edge) and its own roll: {h, r, cap, bands, waist}.
static func _sizes(t: float, rim: float, roll: float) -> Dictionary:
	var big := lerpf(0.5,1.0,clampf(rim*1.4,0.0,1.0))*lerpf(0.75,1.25,roll)
	return {"h":lerpf(HEIGHT.x,HEIGHT.y,t)*big,"r":lerpf(STEM.x,STEM.y,t)*lerpf(0.8,1.15,roll)*lerpf(0.75,1.0,rim),
		"cap":lerpf(CAP.x,CAP.y,t),"bands":lerpf(BANDS.x,BANDS.y,t),"waist":lerpf(WAIST.x,WAIST.y,t)}

## The most a hoodoo reaches from its middle over its stem (not its foot's
## apron): its cap or its bands' swell, weathered.
static func _widest(t: float, rim: float, roll: float) -> float:
	var s := _sizes(t,rim,roll)
	return float(s.r)*maxf(float(s.cap),1.0+float(s.bands))*(1.0+NOISE)

## One hoodoo at world XZ `q`.
static func _hoodoo(field: RefCounted, pos: Vector3, q: Vector2, t: float, rim: float, roll: float, rng: RandomNumberGenerator) -> Dictionary:
	var s := _sizes(t,rim,roll)
	var h := float(s.h)
	var r := float(s.r)
	var apron := lerpf(1.7,2.1,t)
	# Its foot: the lowest ground round its apron, sunk by the slope.
	var low := INF
	var high := -INF
	for k in range(9):
		var d := Vector2.ZERO if k == 0 else Vector2.from_angle(TAU*k/8.0)*r*apron
		var g: float = field.height(q.x+d.x,q.y+d.y)
		low = minf(low,g)
		high = maxf(high,g)
	var bury := 1.5+(high-low)
	var capped := t < 0.5 or rng.randf() < TALL_CAPPED
	var cap_lo := h*lerpf(0.78,0.88,t)
	var cap_r := r*float(s.cap)
	var period := rng.randf_range(4.5,8.0)
	var phase := rng.randf()*TAU
	var fall := h*lerpf(0.12,0.08,t)
	var profile: Array = []
	var stem := func(y: float) -> float:
		var k := 1.0+(apron-1.0)*exp(-maxf(y,0.0)/fall)
		k *= 1.0-float(s.waist)*smoothstep(h*0.3,cap_lo,y)
		k *= 1.0+float(s.bands)*sin(TAU*y/period+phase)
		if not capped: k *= 1.0-0.65*smoothstep(h*0.55,h,y)
		return r*k
	var aspect := rng.randf_range(1.0,1.35)
	var ax := sqrt(aspect)
	var add := func(y: float, rr: float) -> void:
		profile.append([y,rr*ax,rr/ax,0.0,0.0])
	add.call(-bury,r*apron)
	var y := 0.0
	var top := h if capped else h
	var stem_top := cap_lo if capped else h
	while y < stem_top-0.01:
		add.call(y,stem.call(y))
		y += 0.6
	if capped:
		add.call(cap_lo,stem.call(cap_lo))
		# The cap: a sharp lip out, a slab, its top rounded off.
		add.call(cap_lo+0.3,cap_r*0.92)
		add.call(cap_lo+0.8,cap_r)
		add.call(lerpf(cap_lo,top,0.7),cap_r*0.97)
		add.call(top,cap_r*0.8)
	else:
		add.call(top,stem.call(top))
	# A lean, most at the top.
	var lean := Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,0.04)*h
	for c: Array in profile:
		var u := clampf(float(c[0])/h,0.0,1.0)
		c[3] = lean.x*u*u
		c[4] = lean.y*u*u
	return {"at":Vector3(q.x-pos.x,low-pos.y,q.y-pos.z),"profile":profile,"yaw":rng.randf()*TAU,
		"dome":rng.randf_range(0.2,0.6) if capped else rng.randf_range(0.8,2.0),
		"square":rng.randf_range(0.8,0.95),"lump":clampf(r*1.2,2.5,6.0),"lumps":LUMPS,"grain":GRAIN,"ledges":LEDGES,"flutes":FLUTES,
		"bed":rng.randf_range(1.2,2.6),"ring_every":lerpf(0.8,1.25,t),"segments":12,"seed":rng.randi()}
