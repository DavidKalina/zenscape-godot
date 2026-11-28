extends RefCounted
## A level piece: a gullied scarp with flatirons (studies/piece_scarp.tscn flies it).
##
## Local frame: x runs across the flight path, z along it; the plane flies
## toward -z, uphill. `u = -z` is the distance uphill. The scarp's middle foot
## is the origin (u = 0, height 0): the approach lies at u < 0 and falls away
## gently to its low end at u = -APPROACH_LEN, the bench lies behind the scarp
## at u > 0. EXTENT is the piece's footprint.
##
## Everything here is a pure function of (x, z) and the constants below, free
## of scene state, so a later round can stamp the piece into a map:
## `height(x, z)`, `rock(x, z)` (0 grass .. 1 bare rock), `tree_spots()`.
##
## Every size is a first guess; retune here.

# The approach: open grass that rises toward the scarp.
const APPROACH_LEN := 1000.0
const APPROACH_SLOPE_DEG := 4.0
# The scarp: its height, its width across the path, the horizontal run of a
# cliff face (150 m over 40 m is about 75 degrees at its steepest), and how
# far past its ends its height dies away into the land.
const SCARP_H := 150.0
const SCARP_W := 1200.0
const FACE_RUN := 40.0
const END_FADE := 260.0
# The blocks the gullies split it into, left (-x) to right: their widths
# (scaled so blocks and gullies fill SCARP_W) and how far each block's face
# stands forward toward the approach (m; negative stands back).
const BLOCK_WIDTHS := [250.0, 280.0, 180.0, 240.0]
const BLOCK_FORWARD := [35.0, -25.0, 90.0, 5.0]
# The gullies between the blocks (one fewer than the blocks): their floor
# widths, and how far each cuts back into the scarp, which is the run of its
# ramp from the approach up to the bench. GULLY_WALL is the run of a
# gully's side walls (m), GULLY_DIP how much its floor's middle sags.
const GULLY_WIDTHS := [70.0, 100.0, 80.0]
const GULLY_DEPTH := [380.0, 480.0, 420.0]
const GULLY_WALL := 22.0
const GULLY_DIP := 5.0
# The flatirons: tilted slabs leaning on the block faces. Each is
# [block index, x offset from the block's middle, base width, how far its tip
# stands above the bench edge, front tilt in degrees, how far its tip leans
# aside (m)]. Their height from the approach is then SCARP_H + that tip
# (about 165-190 m: the asked-for 80-150 m can't put a tip above a 150 m
# edge). FLATIRON_BACK_DEG is the steep back's slope; FLATIRON_STANDOFF how
# far in front of the face's foot the tip stands; FLATIRON_FULL < 1 fills
# the outline's shoulders out (1: a straight triangle).
const FLATIRONS := [
	[0, -30.0, 105.0, 25.0, 50.0, 12.0],
	[1, 60.0, 120.0, 35.0, 48.0, -15.0],
	[2, 0.0, 90.0, 15.0, 52.0, 8.0],
	[3, -50.0, 115.0, 30.0, 50.0, -10.0],
]
const FLATIRON_FULL := 0.75
const FLATIRON_BACK_DEG := 72.0
const FLATIRON_STANDOFF := 6.0
# A slab's sides: how steeply they fall from its front's edges (rise per m)
# and how far out that fall is drawn.
const FLATIRON_EDGE_DROP := 3.5
const FLATIRON_EDGE_RUN := 60.0
# The bench on top: how deep it runs before the land rolls up into low hills
# at the piece's back, and its own gentle uphill slope.
const BENCH_DEPTH := 400.0
const BENCH_SLOPE_DEG := 3.0
const BACK_HILLS := 60.0
# Ground roughness (m) on the approach and bench, and the face line's wobble.
const ROLL := 2.0
const FACE_WOBBLE := 7.0
# Rock where the ground's normal points up less than this (cos of ~42 deg).
const ROCK_UP := 0.74
# Scattered trees.
const APPROACH_TREES := 14
const BENCH_TREES := 10
const TREE_SEED := 31
# The footprint (local x0, u0 .. x1, u1 as a Rect2 in x, z).
const MARGIN_SIDE := 350.0
const MARGIN_BACK := 260.0
const MARGIN_FRONT := 150.0
static var EXTENT := Rect2(-SCARP_W*0.5-MARGIN_SIDE,-(BENCH_DEPTH+FACE_RUN+MARGIN_BACK),
	SCARP_W+2.0*MARGIN_SIDE,BENCH_DEPTH+FACE_RUN+MARGIN_BACK+APPROACH_LEN+MARGIN_FRONT)

static var _noise: FastNoiseLite
static var _layout: Dictionary = {}

static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 17
		_noise.frequency = 1.0
		_noise.fractal_octaves = 3
	return _noise

## The blocks' spans and faces and the gullies' middles, from the constants.
static func layout() -> Dictionary:
	if not _layout.is_empty(): return _layout
	var total := 0.0
	for w: float in BLOCK_WIDTHS: total += w
	for w: float in GULLY_WIDTHS: total += w
	var k := SCARP_W/total
	var blocks: Array = []
	var gullies: Array = []
	var x := -SCARP_W*0.5
	for i in BLOCK_WIDTHS.size():
		var bw: float = BLOCK_WIDTHS[i]*k
		blocks.append({"x0": x, "x1": x+bw, "mid": x+bw*0.5, "face": -float(BLOCK_FORWARD[i])})
		x += bw
		if i < GULLY_WIDTHS.size():
			var gw: float = GULLY_WIDTHS[i]*k
			gullies.append({"mid": x+gw*0.5, "w": gw, "depth": float(GULLY_DEPTH[i])})
			x += gw
	for i in gullies.size():
		# The ramp starts at the more recessed of its two blocks' faces.
		gullies[i]["mouth"] = maxf(blocks[i].face,blocks[i+1].face)
	var irons: Array = []
	for f: Array in FLATIRONS:
		var b: Dictionary = blocks[int(f[0])]
		irons.append({"x": float(b.mid)+float(f[1]), "half": float(f[2])*0.5, "tip": float(f[3]),
			"tan": tan(deg_to_rad(float(f[4]))), "skew": float(f[5]), "face": float(b.face)})
	_layout = {"blocks": blocks, "gullies": gullies, "irons": irons}
	return _layout

## The land's slope term alone (no scarp): approach and bench (m at u).
static func _tilt(u: float) -> float:
	var a := tan(deg_to_rad(APPROACH_SLOPE_DEG))
	var b := tan(deg_to_rad(BENCH_SLOPE_DEG))
	return u*lerpf(a,b,smoothstep(-40.0,40.0,u))

## Which block's face line (u) stands at x, wobbled, and its end fade.
static func _face(x: float) -> float:
	var L := layout()
	var blocks: Array = L.blocks
	var gullies: Array = L.gullies
	var i := 0
	while i < gullies.size() and x > float(gullies[i].mid): i += 1
	var f: float = blocks[i].face
	f += FACE_WOBBLE*_n().get_noise_1d(x/55.0+3.0)
	# Past the ends the face bends back as it dies away.
	var out := maxf(absf(x)-SCARP_W*0.5,0.0)
	return f+out*0.6

## The scarp's height multiplier across x (1 along its width, 0 past the fade).
static func _span(x: float) -> float:
	return smoothstep(SCARP_W*0.5+END_FADE,SCARP_W*0.5,absf(x))

## The cliff's rise at u behind a face line `f`: 0 in front, SCARP_H behind.
static func _cliff(u: float, f: float) -> float:
	return SCARP_H*smoothstep(0.0,1.0,(u-f)/FACE_RUN)

## A gully's ramp: 0 at its mouth, SCARP_H at its head, near linear between.
static func _ramp(t: float) -> float:
	var c := clampf(t,0.0,1.0)
	return SCARP_H*(0.55*c+0.45*smoothstep(0.0,1.0,c))

## The land's height at local (x, z).
static func height(x: float, z: float) -> float:
	var u := -z
	var L := layout()
	var n := _n()
	var h := _tilt(u)
	# Gentle roll on the open ground.
	h += ROLL*n.get_noise_2d(x/140.0,u/140.0)
	var span := _span(x)
	var rise := _cliff(u,_face(x))*(1.0+0.015*n.get_noise_2d(x/70.0,u/70.0))
	for g: Dictionary in L.gullies:
		var dx := absf(x-float(g.mid))
		var half := float(g.w)*0.5
		var inside := smoothstep(half+GULLY_WALL*0.5,half-GULLY_WALL*0.5,dx)
		if inside <= 0.0: continue
		var mouth := float(g.mouth)+4.0*n.get_noise_1d(x/20.0)
		var gr := _ramp((u-mouth)/float(g.depth))
		var sag := GULLY_DIP*(1.0-clampf(dx/half,0.0,1.0)**2)*(1.0-clampf((u-mouth)/float(g.depth),0.0,1.0))
		gr -= sag*smoothstep(mouth-60.0,mouth,u)
		rise = lerpf(rise,gr,inside)
	h += rise*span
	# The back of the bench rolls up into low hills, closing the piece.
	var back := BENCH_DEPTH+FACE_RUN
	h += BACK_HILLS*smoothstep(back,back+MARGIN_BACK,u)*(0.7+0.3*n.get_noise_1d(x/180.0))
	# The flatirons: slabs with a sloped front, a steep back, a pointed top.
	for f: Dictionary in L.irons:
		var half := float(f.half)
		if absf(x-float(f.x)) >= half+absf(float(f.skew))+FLATIRON_EDGE_RUN: continue
		var tip_u := float(f.face)+FLATIRON_STANDOFF
		var tip_h := _tilt(tip_u+FACE_RUN)+SCARP_H+float(f.tip)
		var tall := tip_h-_tilt(tip_u)
		var front := tip_h-(tip_u-u)*float(f.tan)
		var rear := tip_h-(u-tip_u)*tan(deg_to_rad(FLATIRON_BACK_DEG))
		var slab := minf(front,rear)
		# The front face's outline: as wide as the base at the foot, a point
		# at the tip, the shoulders a little full (a flatiron's), the tip
		# leant `skew` m aside; past its edges the slab's sides fall away.
		var down := clampf((tip_h-slab)/tall,0.0,1.0)
		var hw := half*pow(down,FLATIRON_FULL)
		var a := absf(x-float(f.x)-float(f.skew)*(1.0-down))
		if a > hw: slab -= (a-hw)*FLATIRON_EDGE_DROP
		if slab > h: h = slab
	return h

## The ground's normal at (x, z), by finite steps of `e` m.
static func normal(x: float, z: float, e := 1.5) -> Vector3:
	return Vector3(height(x-e,z)-height(x+e,z),2.0*e,height(x,z-e)-height(x,z+e)).normalized()

## Bare rock (1) or grass (0) at (x, z), by the slope.
static func rock(x: float, z: float) -> float:
	return rock_of(normal(x,z))

## The same from a normal already found.
static func rock_of(nm: Vector3) -> float:
	return smoothstep(ROCK_UP+0.06,ROCK_UP-0.06,nm.y)

## Where the trees stand (local x, z): APPROACH_TREES on the approach,
## BENCH_TREES on the bench, all on grass, clear of the gullies and slabs.
static func tree_spots() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var out: Array = []
	var L := layout()
	var want := [[APPROACH_TREES, -APPROACH_LEN+60.0, -220.0], [BENCH_TREES, FACE_RUN+80.0, FACE_RUN+BENCH_DEPTH-20.0]]
	for w: Array in want:
		var placed := 0
		var tries := 0
		while placed < int(w[0]) and tries < 2000:
			tries += 1
			var x := rng.randf_range(-SCARP_W*0.5,SCARP_W*0.5)
			var u := rng.randf_range(float(w[1]),float(w[2]))
			var ok := rock(x,-u) < 0.05
			for g: Dictionary in L.gullies:
				if absf(x-float(g.mid)) < float(g.w)*0.5+GULLY_WALL+15.0 and u > float(g.mouth)-30.0: ok = false
			for t: Vector2 in out:
				if t.distance_to(Vector2(x,-u)) < 45.0: ok = false
			if not ok: continue
			out.append(Vector2(x,-u))
			placed += 1
	return out
