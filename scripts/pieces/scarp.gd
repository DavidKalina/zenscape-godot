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
## `height(x, z)`, `rock(x, z)` (0 grass .. 1 bare rock), `tree_spots()`,
## and `slab_face(x, z)` (1 on a flatiron's face) or both at once, `sample`;
## `rise` and `reach` stamp it into a map (scripts/endless/land_pieces.gd).
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
# The flatirons: thin plates of rock leaning on the block faces, each on a
# buttress of its own. A row is [block index, x offset of the foot's middle
# from the block's middle, base width, how far the tip stands above the
# scarp under it (m), front tilt (deg), how far the tip leans aside (m),
# plate thickness (m, square to the face), how far behind the bench edge the
# tip stands (m; negative brings it forward and down the cliff)]. The foot
# lies where the tilted face meets the approach, so the steeper the slab,
# the nearer the cliff's base. The plate is whatever the face stands proud
# of: the buttress under it (the face's plane, a plate's thickness down) or
# the cliff and bench, whichever is higher. Rows later in the table lie on
# top of earlier ones (block 1's pair overlaps like shingles: the second's
# tip stands in front of the first's face). Keep them off the gully mouths.
const FLATIRONS := [
	[0, -10.0, 170.0, 30.0, 70.0, 14.0, 22.0, 5.0],
	[1, -30.0, 170.0, 38.0, 69.0, -18.0, 22.0, 6.0],
	[1, 30.0, 90.0, 34.0, 66.0, 10.0, 16.0, -10.0],
	[2, 0.0, 120.0, 20.0, 67.0, -10.0, 18.0, 2.0],
	[3, 5.0, 150.0, 26.0, 71.0, 16.0, 20.0, 4.0],
]
# The face's outline is a shield: a pointed tip, the sides bowing out to
# full shoulders. FLATIRON_FULL is how full: 1 a straight triangle, 2 the
# fullest (sides square to the base at the foot). FLATIRON_BACK_DEG is the
# steep back behind the tip.
const FLATIRON_FULL := 1.6
const FLATIRON_BACK_DEG := 76.0
# A plate's sides: how steeply they fall from the face's edges (rise per m,
# on average; the fall's top and foot are rounded), and over how far (m)
# the face's paint fades into the sides'.
const FLATIRON_EDGE_DROP := 4.0
const FACE_FADE := 4.0
# The fillet (m) where a plate meets the land, rounding the crease at its foot.
const FLATIRON_FILLET := 4.0
# The buttress under a plate: how far its top runs out past the plate's
# edges (m), then how wide its sides fan out and down into the cliff (m).
# The fan dies away within BUTTRESS_GULLY_GAP m of a gully's floor, so the
# gully mouths stay open.
const BUTTRESS_SHOULDER := 4.0
const BUTTRESS_FAN := 70.0
const BUTTRESS_GULLY_GAP := 15.0
# The notch behind each tip: a dip in the bench this deep (m), this long
# (m, along the path) and this wide either side of the tip (m).
const NOTCH_DEPTH := 8.0
const NOTCH_RUN := 28.0
const NOTCH_HALF := 30.0
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
# Stamped into a map (`rise`, scripts/endless/land_pieces.gd): the map's own
# ground stands in for the approach, the bench and their roll; the scarp's
# level change is taken back off by a smooth ramp from MAP_FRONT m in front of
# the face to MAP_BACK m behind it (eased in and out over MAP_EASE of that), so
# the stamp is 0 at both ends and gathers the climb the map's ground already
# has over that run into the cliff. MAP_BACK must clear the gullies' heads.
const MAP_FRONT := 350.0
const MAP_BACK := 950.0
const MAP_EASE := 0.3
# The footprint (local x0, u0 .. x1, u1 as a Rect2 in x, z).
const MARGIN_SIDE := 350.0
const MARGIN_BACK := 260.0
const MARGIN_FRONT := 150.0
static var EXTENT := Rect2(-SCARP_W*0.5-MARGIN_SIDE,-(BENCH_DEPTH+FACE_RUN+MARGIN_BACK),
	SCARP_W+2.0*MARGIN_SIDE,BENCH_DEPTH+FACE_RUN+MARGIN_BACK+APPROACH_LEN+MARGIN_FRONT)

static var _noise: FastNoiseLite
static var _layout: Dictionary = {}
## Each flatiron's box (x0, x1, u0, u1: its buttress and notch), a quick test.
static var _boxes := PackedFloat64Array()

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
	_layout = {"blocks": blocks, "gullies": gullies, "irons": irons}
	# Each plate's face is the plane through its tip (ut, H) falling `tan`
	# per m toward the approach, down to its foot (uf, hf) on the approach.
	for f: Array in FLATIRONS:
		var b: Dictionary = blocks[int(f[0])]
		var ix := float(b.mid)+float(f[1])
		var tilt := deg_to_rad(float(f[4]))
		var t := tan(tilt)
		var fl := _face(ix+float(f[5]))
		var ut := fl+FACE_RUN+float(f[7])
		var top := _tilt(ut)+_cliff(ut,fl)+float(f[3])
		var uf := ut
		for _r in 4: uf = ut-(top-_tilt(uf))/t
		var thick := float(f[6])/cos(tilt)
		irons.append({"x": ix, "half": float(f[2])*0.5, "tan": t, "skew": float(f[5]),
			"thick": thick, "ut": ut, "top": top, "uf": uf, "hf": _tilt(uf), "rise": float(f[3])})
		var reach := float(f[2])*0.5+absf(float(f[5]))+thick/FLATIRON_EDGE_DROP+BUTTRESS_SHOULDER+BUTTRESS_FAN
		var back := ut+(float(f[3])+NOTCH_DEPTH+20.0)/tan(deg_to_rad(FLATIRON_BACK_DEG))+NOTCH_RUN
		_boxes.append_array([ix-reach,ix+reach,uf-10.0,back])
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
	return sample(x,z).x

## How much (x, z) lies on a flatiron's face (1) rather than its sides, its
## buttress or the land (0): for painting the faces apart.
static func slab_face(x: float, z: float) -> float:
	return sample(x,z).y

## The height at local (x, z) and how much it lies on a flatiron's face.
static func sample(x: float, z: float) -> Vector2:
	return _shape(x,z,true)

## `sample`, with the study's own ground (the roll and the back hills) or,
## without `land`, the scarp alone on its tilt (for `rise`).
static func _shape(x: float, z: float, land: bool) -> Vector2:
	var u := -z
	var L := layout()
	var n := _n()
	var h := _tilt(u)
	# Gentle roll on the open ground.
	if land: h += ROLL*n.get_noise_2d(x/140.0,u/140.0)
	var span := _span(x)
	var rise := _cliff(u,_face(x))
	if rise > 0.0: rise *= 1.0+0.015*n.get_noise_2d(x/70.0,u/70.0)
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
	if land and u > back: h += BACK_HILLS*smoothstep(back,back+MARGIN_BACK,u)*(0.7+0.3*n.get_noise_1d(x/180.0))
	# The notches: a dip in the bench just behind each tip.
	var back_tan := tan(deg_to_rad(FLATIRON_BACK_DEG))
	var near: Array[int] = []
	for i in _boxes.size()/4:
		if x > _boxes[i*4] and x < _boxes[i*4+1] and u > _boxes[i*4+2] and u < _boxes[i*4+3]: near.append(i)
	if near.is_empty(): return Vector2(h,0.0)
	var irons: Array = L.irons
	for i: int in near:
		var f: Dictionary = irons[i]
		var nu := float(f.ut)+float(f.rise)/back_tan+NOTCH_RUN*0.5
		var du := absf(u-nu)/(NOTCH_RUN*0.5)
		var dx := absf(x-float(f.x)-float(f.skew))/NOTCH_HALF
		if du < 1.0 and dx < 1.0:
			h -= NOTCH_DEPTH*(1.0-smoothstep(0.0,1.0,du))*(1.0-smoothstep(0.0,1.0,dx))
	# The flatirons: each a plate whose face is a plane tilted toward the
	# approach, outlined as a shield (the base's width at the foot, a point at
	# the tip, leant `skew` aside), its back falling steeply behind the tip.
	# Past the outline the plate's sides drop by its thickness onto its
	# buttress (the face's plane that much lower), whose own sides then fall
	# away to the cliff and the approach.
	var face := 0.0
	for i: int in near:
		var f: Dictionary = irons[i]
		var half := float(f.half)
		var thick := float(f.thick)
		var edge := thick/FLATIRON_EDGE_DROP
		var top := float(f.top)
		var front := top-(float(f.ut)-u)*float(f.tan)
		var ridge := minf(front,top-(u-float(f.ut))*back_tan)
		if ridge <= h: continue
		var down := clampf((top-front)/(top-float(f.hf)),0.0,1.0)
		var hw := half*(1.0-pow(1.0-down,FLATIRON_FULL))
		var out := absf(x-float(f.x)-float(f.skew)*(1.0-down))-hw
		# The side falls the plate's thickness, or less where the land beside
		# stands nearer (up by the tip, or on a plate below), at one slope.
		var drop := minf(thick,ridge-h)
		var run := drop/FLATIRON_EDGE_DROP
		var s := ridge
		if out > run:
			var fan := 1.0-smoothstep(0.0,BUTTRESS_FAN,out-edge-BUTTRESS_SHOULDER)
			for g: Dictionary in L.gullies:
				fan *= smoothstep(float(g.w)*0.5,float(g.w)*0.5+BUTTRESS_GULLY_GAP,absf(x-float(g.mid)))
			s = h+maxf(ridge-thick-h,0.0)*fan
		elif out > 0.0:
			s = ridge-drop*smoothstep(0.0,run,out)
		# A small fillet where the plate (not its fan, already smooth) meets
		# the land: a smooth max.
		var gap := s-h
		var lift := maxf(FLATIRON_FILLET-absf(gap),0.0) if out <= run else 0.0
		if gap <= 0.0 and lift <= 0.0: continue
		h = maxf(s,h)+lift*lift/(4.0*FLATIRON_FILLET)
		if gap > 0.0:
			# The face's paint: full inside the outline, below the tip; the
			# plate's sides half, the buttress none.
			var on := 1.0-0.4*smoothstep(-FACE_FADE,FACE_FADE,out)
			face = on*(1.0-smoothstep(run*0.6,run+0.01,out))*smoothstep(0.0,3.0,float(f.ut)-u)
	return Vector2(h,face)

## --- Stamped into a map (scripts/endless/land_pieces.gd) ---------------------
## The scarp on the map's ground: its cliff, gullies, flatirons and notches
## (the study's own tilt, roll and back hills left out), less the ramp
## `level` of the same height, so in front of the face the ground is let down
## and behind it lifted, and 0 at both ends of the reach and past the ends of
## the scarp (its END_FADE).

## The scarp's rise over the map's ground at local (x, z) (m; negative in
## front of the face, where the stamp lowers the ground).
static func rise(x: float, z: float) -> float:
	var u := -z
	if u <= -MAP_FRONT or u >= MAP_BACK or absf(x) >= SCARP_W*0.5+END_FADE: return 0.0
	var span := _span(x)
	var h := 0.0
	var clear := _map_clear()
	if u < clear.x:
		# In front of every face, gully mouth and flatiron: the ramp alone
		# (what `_shape` gives there, without its cost).
		h = -span*SCARP_H*level(u)
	elif u > clear.y:
		# Behind every face, gully head and notch: the bench, the cliff's
		# wobble and the gullies' full height (as `_shape` has it there).
		var top := SCARP_H*(1.0+0.015*_n().get_noise_2d(x/70.0,u/70.0))
		for g: Dictionary in layout().gullies:
			var half := float(g.w)*0.5
			var inside := smoothstep(half+GULLY_WALL*0.5,half-GULLY_WALL*0.5,absf(x-float(g.mid)))
			if inside > 0.0: top = lerpf(top,SCARP_H,inside)
		h = span*(top-SCARP_H*level(u))
	else:
		h = _shape(x,z,false).x-_tilt(u)-span*SCARP_H*level(u)
	# The cliff's own small wobble, left at the ends, eased off.
	return h*smoothstep(-MAP_FRONT,-MAP_FRONT+80.0,u)*smoothstep(MAP_BACK,MAP_BACK-80.0,u)

static var _clear := Vector2.ZERO

## The u in front of which `_shape` has no scarp at all, and behind which it
## has only the bench at full height (the faces' wobble and end bend, the
## gully mouths' wobble and sag, the heads, the flatirons' boxes counted).
static func _map_clear() -> Vector2:
	if _clear != Vector2.ZERO: return _clear
	var L := layout()
	var lo := INF
	var hi := -INF
	for b: Dictionary in L.blocks:
		lo = minf(lo,float(b.face)-FACE_WOBBLE)
		hi = maxf(hi,float(b.face)+FACE_WOBBLE+END_FADE*0.6+FACE_RUN)
	for g: Dictionary in L.gullies:
		lo = minf(lo,float(g.mouth)-4.0-60.0)
		hi = maxf(hi,float(g.mouth)+4.0+float(g.depth))
	for i in _boxes.size()/4:
		lo = minf(lo,_boxes[i*4+2])
		hi = maxf(hi,_boxes[i*4+3])
	_clear = Vector2(lo-1.0,hi+1.0)
	return _clear

## The local box `rise` is 0 outside of.
static func reach() -> Rect2:
	var half := SCARP_W*0.5+END_FADE
	return Rect2(-half,-MAP_BACK,half*2.0,MAP_BACK+MAP_FRONT)

## The share (0..1) of the level change made up by distance `u` uphill: 0 at
## -MAP_FRONT, 1 at MAP_BACK, at an even slope between eased ends.
static func level(u: float) -> float:
	var t := clampf((u+MAP_FRONT)/(MAP_FRONT+MAP_BACK),0.0,1.0)
	var e := MAP_EASE*0.5
	var p := 1.0/(1.0-e)
	if t < e: return p*t*t/(2.0*e)
	if t > 1.0-e: return 1.0-p*(1.0-t)*(1.0-t)/(2.0*e)
	return p*(t-e*0.5)

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
