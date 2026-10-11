extends RefCounted
## The pierced isle: one big sky island mass (about 150 to 230 m across and
## 120 m from its summit to its keel's tip), a landmark seen from far, with
## holes right through it to fly through: a natural arch through a flank,
## a cavern in its heart reached down a skylight from the top and left by
## windows out its sides, and an eye through the hanging keel. Seeded and
## laid by rule (`make`), every hole checked flyable before it is kept.
##
## Two parts, one mass:
##   the lid: a real sky islet (scripts/sky_islet.gd `author`, a big hills
##     islet on a 2 m grid) for the top: its ground, erosion, grass, trees
##     and flowers, its shore wall in the earth sides' strata, walked on
##     foot and perched on as any islet; its keel left off (`keel` 0) and
##     its skylight punched through its outline (the recipe's `holes`);
##   the body: a rock field (`field`, a signed distance, negative in rock)
##     under the lid's base: the lid's own outline (`outline_sd`) carried
##     down, its strata stepping out in ledges, narrowing to a keel and a
##     couple of hanging lobes, lumped and cragged by noise; then the holes
##     carved out of it. Drawn as faceted faces by scripts/pierced_mesh.gd
##     in the lid's own side material, so the strata run on down.
##
## The holes (`holes`, each {kind, name, points (its middle line, lid
## frame), r (carved radius), squash (the cross-section's height over its
## width is 1/squash), floor (a flat floor's height, or -INF), clear (the
## radius kept free of rock round the middle line, mesh slack and the walls'
## roughness allowed for)}):
##   arch: a natural arch through a flank, short and tall, chosen where the
##     rock along its chord is ARCH_ROCK long: sky through it from afar;
##   cavern: a long, flat-floored hall in the rock, its floor FLOOR_SHARE
##     down its height;
##   shaft: the skylight, straight down through the lid, then slanting into
##     the cavern's roof toward the window the dive leaves by;
##   window: from the cavern out through a side, WINDOWS of them; one tight;
##   eye: through the keel, low down.
## The routes (`routes`, each {name, points (lid frame), holes}): lines a
## flight can follow through them (scripts/pierced_pilot.gd flies them):
## arch, eye, dive (from over the top down the skylight, through the
## cavern and out its window), thread (in one window, out another).
##
## A plan is well formed when `problems` is empty: every hole's tube
## (its middle line and a ring CLEAR out round it) is air, every route's
## corridor is clear of rock, the lid and the ruins' boxes, and rock stands
## WALL between holes that do not open into each other.
##
## The frame is the lid's: its grid's middle at the origin, y up, its rim
## near SkyIslet.RIM_HEIGHT; the body hangs to `tip_y`.

const SkyIslet = preload("res://scripts/sky_islet.gd")
const IslandOutline = preload("res://scripts/island_outline.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RockLooks = preload("res://scripts/rock_looks.gd")

## The lid: its radius (m, the islet's own `radius`), its grid's step, and
## its foot (m under the rim: a thin crust of the islet's own wall, the
## rock drawn on below it).
const RADIUS := Vector2(66.0,76.0)
const STEP := 2.0
const LID_BASE := 4.5
## The outline's distance raster: its cell (m) and the margin it reaches
## past the grid.
const RASTER := 2.0
const RASTER_MARGIN := 24.0
## The body: how far over the lid's base its top stands (hidden in the lid),
## how far in from the lid's outline its face stands, the cliff band under
## the lid (m) before it narrows, how deep the whole hangs under the base
## (m), and the narrowing's power (over 1: it keeps its width, then goes).
const TOP_OVER := 1.5
const INSET := 0.9
const BAND := Vector2(14.0,20.0)
const DEPTH := Vector2(100.0,110.0)
const TAPER := 2.0
## The strata's ledges: how far a bed's top is set back (m), its height (m)
## and how far that wanders (m).
const LEDGE := Vector3(2.2,8.5,3.0)
## Noise on the face: broad lumps and small crags (m, 1/m).
const LUMP := Vector2(3.4,0.028)
const CRAG := Vector2(1.2,0.11)
## Buttresses and gullies down the face: depth (m), how often across (1/m),
## and how far they run down (the noise's height squashed this much).
const FLUTE := Vector3(2.4,0.06,0.18)
## A hole's mouth flares this much wider (share of its radius) over the
## last metres of rock (m) before the face.
const FLARE := Vector2(0.4,9.0)
## Hanging lobes: how many, their radius at the top (m), how deep their tips
## hang under the base (m), how far out from the middle (share of the
## deepest inland distance), and the blend into the body (m).
const LOBES := Vector2i(2,3)
const LOBE_R := Vector2(18.0,28.0)
const LOBE_TIP := Vector2(48.0,74.0)
const LOBE_OUT := Vector2(0.35,0.7)
const LOBE_BLEND := 8.0
## A hole's wall: its roughness (m), the drawn faces' slack past the field
## (m, half a mesh cell and a little), and the rock kept between holes.
const ROUGH := 1.5
const SLACK := 1.0
const WALL := 7.0
## The arch: carved radius, squash, how far under the lid's base its crown
## stays, and the rock its chord crosses (m: short, so it reads as an arch).
const ARCH_R := Vector2(16.0,19.5)
const ARCH_SQUASH := 0.82
const ARCH_UNDER := 7.0
const ARCH_ROCK := Vector2(24.0,56.0)
## The cavern: radius, half length, squash (flatter than round), its middle
## under the base (m), and its flat floor's place down its half height.
const CAVERN_R := Vector2(15.0,18.0)
const CAVERN_LONG := Vector2(10.0,15.0)
const CAVERN_SQUASH := 1.25
const CAVERN_DOWN := Vector2(36.0,42.0)
const FLOOR_SHARE := 0.7
## The skylight: carved radius, the lid's hole under it (that much smaller,
## so the field's rock never stands in the lid's own hole), how far it
## stands off the cavern's middle (m, so the shaft slants toward the dive's
## window) and how far into the land its rim keeps (m).
const SHAFT_R := Vector2(11.5,13.0)
const LID_HOLE := 1.8
const SHAFT_OFF := Vector2(10.0,16.0)
const SHAFT_INLAND := 10.0
## The skylight's tube starts this high (m, over every hill of the lid).
const SHAFT_TOP := 60.0
## The windows: how many, carved radius (wide ones), the tight one's, their
## height over the cavern's middle (m).
const WINDOWS := 3
const WINDOW_R := Vector2(7.6,9.0)
const TIGHT_R := 5.4
const WINDOW_UP := Vector2(6.5,8.5)
## The eye: carved radius, the rock kept under it to the keel's tip and
## round it (m).
const EYE_R := Vector2(8.0,9.5)
const EYE_ROOM := 9.0
## The routes: the corridor kept clear round each (m: half of
## scripts/world_scale.gd gap(SNUG), the plane's half span and 1.2 m past
## its tip; it was 0.9) and how far each runs on past a mouth (m).
static var ROUTE_CLEAR: float = WorldScale.gap(WorldScale.SNUG)*0.5
const LEAD := 45.0
## The plane through a hole: the least room (m) past its wingtips either
## side of the tube's middle line, wide and tight.
const ROOM_WIDE := 2.5
const ROOM_TIGHT := 1.2
## The lid's dome (m over its ground, inland).
const DOME := 2.5
## The colour (`tint`): the beds' height (m) and wander (m), their shade
## spread, the warm and cool patches, the pale streaks (share of joints,
## strength) and their tone, turf on ledges facing up past LEDGE_UP, the
## holes' inside a little lighter and warmer, and the mist toward the tip
## (the last MIST_UP m).
const BED_H := 5.5
const BED_WAVE := 2.5
const BED_TONE := Vector2(1.0,1.45)
const WARM := 0.3
const STREAK := Vector2(0.18,0.55)
const PALE := Color(0.33,0.32,0.3)
const TURF := Color(0.12,0.24,0.07)
const LEDGE_UP := 0.72
const INSIDE := Color(1.22,1.14,1.04)
## The sky's rock looks lean cool (RockLooks COOL); this one's beds are
## warmed back, so its shade reads stone-grey, not navy, under the sky's
## blue fill.
const WARMTH := Color(1.16,1.05,0.86)
const MIST := Color(0.36,0.42,0.52)
const MIST_UP := 30.0
## The shelter's rays: their steps out (m) and reach.
const SHELTER_STEPS := [2.0,4.5,8.0,13.0,20.0,30.0]
const SHELTER_REACH := 32.0
## The dive comes in this high over the skylight's ground (m).
const DIVE_HIGH := 32.0
## The ruins (`_lay_ruins`, built by scripts/pierced_ruins.gd): how
## weathered; the feed (the aqueduct over the top to the skylight's lip):
## its spans, how far back from the hole's edge its last pier stands (m),
## how far inland its run keeps (m) and how much the ground may climb along
## it (m); the hall: its bays, how far its mouth stands back from the
## hole's edge (m); the cavern's run.
const WEATHERED := Vector2(0.55,0.85)
const FEED_SPANS := Vector2i(3,4)
const FEED_EDGE := 1.2
const FEED_INLAND := 4.0
const FEED_CLIMB := 6.0
## The spout past the last pier (scripts/pierced_ruins.gd SPOUT) and the
## least fall the feed's water takes down the shaft (m).
const FEED_SPOUT := 1.8
const FEED_DROP := 24.0
const HALL_BAYS := 3
## The cavern's run: at most this many spans.
const RUN_SPANS := 3
## The run keeps this far (m, flat) off the dive's pull-out line.
const RUN_CLEAR := 6.0
const HALL_BACK := 12.0
## The turns (rad) off the dive's way a hall is tried at, in order.
const HALL_TURNS := [0.0,0.35,-0.35,0.7,-0.7]
## The gate stands this far in from the tight window's mouth (m).
const GATE_IN := 2.5
## Layouts tried for a seed before its last is kept, problems and all.
const DRAWS := 8
## Tries per hole before it is given up.
const TRIES := 40

var seed := 0
## The draw the plan was laid from (`make`).
var draw := 0
var radius := 70.0
## The lid's recipe (SkyIslet `author`), holes and clearings included.
var recipe := {}
## The lid's base (its underside) and the body's top, the keel's tip.
var base := -18.0
var top_y := -16.5
var tip_y := -110.0
var band := 16.0
var depth := 92.0
## The lid's land as faces and its mounds (for the lid's top's estimate).
var mounds: Array[Vector4] = []
## The outline's signed distance (m, + outside), on a raster.
var sd := PackedFloat32Array()
var sd_n := 0
var sd_origin := Vector2.ZERO
## The deepest point inland and how deep.
var inner := Vector2.ZERO
var inner_max := 40.0
var lobes: Array[Vector4] = []
var holes: Array[Dictionary] = []
var routes: Array[Dictionary] = []
## The ruins' places (scripts/pierced_ruins.gd lays them): each {kind, at
## (Transform3D, lid frame), and its own}.
var ruins: Array[Dictionary] = []
## The ruins' bulk, kept clear of routes: each {xform (its middle and turn,
## lid frame), half (its half size)}.
var blockers: Array[Dictionary] = []
var problems: Array[String] = []
var _lump: FastNoiseLite
var _crag: FastNoiseLite
var _rough: FastNoiseLite
var _ledge: FastNoiseLite
var _flute: FastNoiseLite
var _tones := PackedColorArray()
## Ground the ruins keep the trees off and level (into the recipe).
var _clear: Array[Vector3] = []
var _pads: Array[Vector4] = []
var _taper_k := 0.0
## The holes' segments, flat for the field: per hole its first segment and
## count, and per segment a, b.
var _seg_a := PackedVector3Array()
var _seg_b := PackedVector3Array()

## The plan for `seed_value`.
## Always well formed: a seed whose first layout has a problem is laid
## again from its next draw (`draw`), up to DRAWS times.
static func make(seed_value: int) -> RefCounted:
	var plan: RefCounted
	for draw in range(DRAWS):
		plan = new()
		plan._lay(seed_value,draw)
		if plan.problems.is_empty(): return plan
	return plan

func _lay(seed_value: int, draw_value := 0) -> void:
	seed = seed_value
	draw = draw_value
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,draw_value,"pierced isle"])
	radius = rng.randf_range(RADIUS.x,RADIUS.y)
	base = -LID_BASE
	top_y = base+TOP_OVER
	band = rng.randf_range(BAND.x,BAND.y)
	depth = rng.randf_range(DEPTH.x,DEPTH.y)
	tip_y = base-depth
	_noises()
	_outline()
	_taper_k = (inner_max-INSET)/pow(depth-band,TAPER)
	_lay_lobes(rng)
	_lay_holes(rng)
	# The hall first, so the hills keep off it and the skylight.
	ruins.clear()
	blockers.clear()
	_pads.clear()
	_clear.clear()
	_lay_hall_first(rng)
	_lay_mounds(rng)
	_lay_ruins(rng)
	_lay_recipe(rng)
	_lay_routes()
	verify()

func _noises() -> void:
	_lump = FastNoiseLite.new()
	var base_seed := lid_seed()
	_lump.seed = base_seed+1
	_lump.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_lump.frequency = LUMP.y
	_lump.fractal_octaves = 2
	_crag = FastNoiseLite.new()
	_crag.seed = base_seed+2
	_crag.noise_type = FastNoiseLite.TYPE_CELLULAR
	_crag.frequency = CRAG.y
	_crag.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	_crag.fractal_type = FastNoiseLite.FRACTAL_NONE
	_rough = FastNoiseLite.new()
	_rough.seed = base_seed+3
	_rough.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_rough.frequency = 0.085
	_rough.fractal_type = FastNoiseLite.FRACTAL_NONE
	_flute = FastNoiseLite.new()
	_flute.seed = base_seed+5
	_flute.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_flute.frequency = FLUTE.y
	_flute.fractal_octaves = 2
	_ledge = FastNoiseLite.new()
	_ledge.seed = base_seed+4
	_ledge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ledge.frequency = 0.02
	_ledge.fractal_type = FastNoiseLite.FRACTAL_NONE

# --- The outline --------------------------------------------------------------------

## The lid's outline, as SkyIslet makes it for this radius and seed (the
## same grid and IslandOutline `mask`), rasterised, and its signed distance
## (EDT both ways).
func _outline() -> void:
	var n := ceili((radius*SkyIslet.REACH+SkyIslet.MARGIN)/STEP)
	var grid: Dictionary = SkyIslet._grid(n,STEP)
	var points: PackedVector2Array = grid.points
	var ids: PackedInt32Array = grid.ids
	var half: float = grid.half
	var mask := IslandOutline.mask(points,ids,lid_seed(),-1.0,half,PI*radius*radius)
	sd_origin = Vector2(-half-RASTER_MARGIN,-half-RASTER_MARGIN)
	sd_n = ceili((half+RASTER_MARGIN)*2.0/RASTER)+1
	var land := PackedByteArray()
	land.resize(sd_n*sd_n)
	for f in range(ids.size()/3):
		if mask[f] != 0: continue
		var a := points[ids[f*3]]
		var b := points[ids[f*3+1]]
		var c := points[ids[f*3+2]]
		var lo := Vector2(minf(a.x,minf(b.x,c.x)),minf(a.y,minf(b.y,c.y)))
		var hi := Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.y,maxf(b.y,c.y)))
		var i0 := maxi(ceili((lo.x-sd_origin.x)/RASTER),0)
		var i1 := mini(floori((hi.x-sd_origin.x)/RASTER),sd_n-1)
		var j0 := maxi(ceili((lo.y-sd_origin.y)/RASTER),0)
		var j1 := mini(floori((hi.y-sd_origin.y)/RASTER),sd_n-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var p := sd_origin+Vector2(i,j)*RASTER
				var w := SkyIslet._barycentric(p,a,b,c)
				if w.x >= -0.001 and w.y >= -0.001 and w.z >= -0.001: land[j*sd_n+i] = 1
	var inside := _edt(land,0)
	var outside := _edt(land,1)
	sd.resize(sd_n*sd_n)
	inner_max = 0.0
	for k in range(sd_n*sd_n):
		var d := (sqrt(outside[k])-0.5)*RASTER if land[k] == 0 else -(sqrt(inside[k])-0.5)*RASTER
		sd[k] = d
		if -d > inner_max:
			inner_max = -d
			inner = sd_origin+Vector2(k % sd_n,k/sd_n)*RASTER

## The lid islet's seed: its outline and ground (the plan's own).
func lid_seed() -> int:
	return hash([seed,draw,"lid"]) & 0x7fffffff

## Squared distances (in cells) from each cell to the nearest cell whose
## value in `mask` is `to`: Felzenszwalb's exact transform, rows then
## columns.
func _edt(mask: PackedByteArray, to: int) -> PackedFloat32Array:
	var n := sd_n
	var big := 1.0e9
	var g := PackedFloat32Array()
	g.resize(n*n)
	for k in range(n*n): g[k] = 0.0 if mask[k] == to else big
	var f := PackedFloat32Array()
	f.resize(n)
	for j in range(n):
		for i in range(n): f[i] = g[j*n+i]
		var d := _edt_1d(f,n)
		for i in range(n): g[j*n+i] = d[i]
	for i in range(n):
		for j in range(n): f[j] = g[j*n+i]
		var d := _edt_1d(f,n)
		for j in range(n): g[j*n+i] = d[j]
	return g

static func _edt_1d(f: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(n)
	var v := PackedInt32Array()
	v.resize(n)
	var z := PackedFloat32Array()
	z.resize(n+1)
	var k := 0
	v[0] = 0
	z[0] = -1.0e20
	z[1] = 1.0e20
	for q in range(1,n):
		var s := ((f[q]+q*q)-(f[v[k]]+v[k]*v[k]))/(2.0*q-2.0*v[k])
		while s <= z[k]:
			k -= 1
			s = ((f[q]+q*q)-(f[v[k]]+v[k]*v[k]))/(2.0*q-2.0*v[k])
		k += 1
		v[k] = q
		z[k] = s
		z[k+1] = 1.0e20
	k = 0
	for q in range(n):
		while z[k+1] < q: k += 1
		d[q] = (q-v[k])*(q-v[k])+f[v[k]]
	return d

## The outline's signed distance at (x, z): + outside the lid's land.
func outline_sd(x: float, z: float) -> float:
	var fx := (x-sd_origin.x)/RASTER
	var fz := (z-sd_origin.y)/RASTER
	var i := floori(fx)
	var j := floori(fz)
	if i < 0 or j < 0 or i >= sd_n-1 or j >= sd_n-1: return RASTER_MARGIN
	var tx := fx-i
	var tz := fz-j
	var k := j*sd_n+i
	var top := lerpf(sd[k],sd[k+1],tx)
	var bottom := lerpf(sd[k+sd_n],sd[k+sd_n+1],tx)
	return lerpf(top,bottom,tz)

# --- The field ----------------------------------------------------------------------

## How far in from the outline the body's face stands at `t` m under the
## lid's base: a little, with each bed's top set back in a ledge; past the
## band, narrowing to nothing at the tip.
func inset(t: float, wander: float, ledges := 1.0) -> float:
	var s := INSET
	if t > 0.0:
		var bed := fposmod((t+wander)/LEDGE.y,1.0)
		s += LEDGE.x*ledges*(1.0-smoothstep(0.0,0.45,bed))*smoothstep(0.0,4.0,t)
		if t > band: s += _taper_k*pow(t-band,TAPER)
	return s

## The body's rock before the holes: negative in rock (m, about the
## distance to its face).
func body(p: Vector3) -> float:
	var d2 := outline_sd(p.x,p.z)
	if d2 > 30.0: return d2
	var t := base-p.y
	# The ledges stand out bold in places and fade out in others.
	var ledges := clampf(0.55+_ledge.get_noise_2d(p.x*2.3+71.0,p.z*2.3)*1.1,0.0,1.3)
	var f := d2+inset(t,_ledge.get_noise_2d(p.x,p.z)*LEDGE.z,ledges)
	for l: Vector4 in lobes:
		if p.y < l.z or p.y > top_y: continue
		var share := (p.y-l.z)/(top_y-l.z)
		var r := l.w*pow(share,0.75)
		var cone := Vector2(p.x-l.x,p.z-l.y).length()-r
		f = _smin(f,cone,LOBE_BLEND)
	f += _lump.get_noise_3d(p.x,p.y*1.4,p.z)*LUMP.x
	# Buttresses and gullies running down the face.
	f += _flute.get_noise_3d(p.x,p.y*FLUTE.z,p.z)*FLUTE.x
	f -= (_crag.get_noise_3d(p.x,p.y*1.6,p.z)+0.5)*CRAG.x
	return maxf(f,p.y-top_y)

## The holes' carved air at `p`: negative inside a hole (m, about the
## distance to its wall), INF far from all.
func carved(p: Vector3, rock := NAN) -> float:
	# Near the rock's face (`rock`, the body's field there, when known) a
	# hole's mouth flares, worn wider as caves are.
	var flare := 1.0
	if not is_nan(rock): flare += FLARE.x*smoothstep(-FLARE.y,0.0,rock)
	var best := INF
	for h: Dictionary in holes:
		var box: AABB = h.box
		if not box.has_point(p): continue
		var q := p
		var squash := float(h.squash)
		if squash != 1.0: q.y = float(h.mid_y)+(p.y-float(h.mid_y))*squash
		var d := INF
		for s in range(int(h.first),int(h.first)+int(h.count)):
			d = minf(d,_segment(q,_seg_a[s],_seg_b[s]))
		d -= float(h.r)*flare
		if float(h.floor) > -INF: d = maxf(d,float(h.floor)-p.y)
		best = minf(best,d)
	if best < ROUGH*3.0: best += _rough.get_noise_3d(p.x,p.y,p.z)*ROUGH
	return best

## The rock: negative in rock, the holes carved out of the body.
func field(p: Vector3) -> float:
	var b := body(p)
	if b > 3.0: return b
	return maxf(b,-carved(p,b))

## The field's gradient (its way out of the rock), by central differences.
func normal(p: Vector3, e := 0.4) -> Vector3:
	var g := Vector3(field(p+Vector3(e,0,0))-field(p-Vector3(e,0,0)),field(p+Vector3(0,e,0))-field(p-Vector3(0,e,0)),field(p+Vector3(0,0,e))-field(p-Vector3(0,0,e)))
	return g.normalized() if g.length() > 0.0001 else Vector3.UP

static func _segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.000001),0.0,1.0)
	return p.distance_to(a+ab*t)

static func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5+0.5*(b-a)/k,0.0,1.0)
	return lerpf(b,a,h)-k*h*(1.0-h)

## The lid's top, estimated before it is made (its mounds and peaks, and a
## margin): a route over the lid keeps over this.
func lid_top(x: float, z: float) -> float:
	var h := SkyIslet.GROUND+DOME+1.5
	for m: Vector4 in mounds:
		var r := Vector2(x-m.x,z-m.y).length()/m.z
		if r < 1.0: h += m.w*maxf((1.0-r*r)*(1.0-r*r),pow(1.0-r,1.2))+SkyIslet.RIDGE
	return h

## True where the lid's land stands at `p` (by the estimate): inside its
## outline, out of its holes, between its base and its top.
func lid_solid(p: Vector3) -> bool:
	if p.y < base or p.y > lid_top(p.x,p.z): return false
	if outline_sd(p.x,p.z) > 0.5: return false
	for h: Dictionary in holes:
		if h.kind != "shaft": continue
		var top: Vector3 = (h.points as PackedVector3Array)[0]
		if Vector2(p.x-top.x,p.z-top.z).length() < float(h.lid)+0.6: return false
	return true

## True where anything solid stands (the rock, the lid, a ruin's box).
func solid(p: Vector3, margin := 0.0) -> bool:
	if field(p) < margin: return true
	if lid_solid(p): return true
	for box: Dictionary in blockers:
		var q: Vector3 = (box.xform as Transform3D).affine_inverse()*p
		var half: Vector3 = box.half
		if absf(q.x) < half.x+margin and absf(q.y) < half.y+margin and absf(q.z) < half.z+margin: return true
	return false

## A ruin's bulk kept clear of the routes: the box `half` about `centre`,
## both in the frame `frame` (lid frame).
func block(frame: Transform3D, centre: Vector3, half: Vector3) -> void:
	blockers.append({"xform":frame*Transform3D(Basis.IDENTITY,centre),"half":half,"ruin":ruins.size()-1})

## The ruins stood on the lid's real ground (`lid`, its SkyIslet shape, once
## made): each ruin's height from the ground under it (the plan laid them
## on its estimate), its bulk moved with it, the routes laid again.
func settle(lid: RefCounted) -> void:
	for i in range(ruins.size()):
		var r: Dictionary = ruins[i]
		var at: Transform3D = r.at
		var y := at.origin.y
		match str(r.kind):
			"hall":
				y = lid.ground_at(r.foot)
			"feed":
				y = -INF
				var head := Vector2(at.origin.x,at.origin.z)
				var edge := head+Vector2(at.basis.x.x,at.basis.x.z)*float(r.spans)*6.4
				for k in range(13):
					var p := head.lerp(edge,k/12.0)
					if lid.inside(p): y = maxf(y,lid.ground_at(p))
				if y == -INF: y = at.origin.y
				y -= 0.6
			_:
				continue
		var dy := y-at.origin.y
		at.origin.y = y
		r.at = at
		if r.has("lane"):
			var lane: PackedVector3Array = r.lane
			for k in range(lane.size()): lane[k].y += dy
			r.lane = lane
		for box: Dictionary in blockers:
			if int(box.ruin) == i: box.xform = (box.xform as Transform3D).translated(Vector3(0.0,dy,0.0))
	_lay_routes()

# --- Laying it out ------------------------------------------------------------------

func _lay_mounds(rng: RandomNumberGenerator) -> void:
	# Two or three broad hills inland and a ridged summit: the top to swoop
	# over. The skylight's ground is kept low (`_lay_recipe` clears it).
	mounds.clear()
	var sky := Vector3.INF
	var shaft := hole("shaft")
	if not shaft.is_empty(): sky = Vector3((shaft.points as PackedVector3Array)[0].x,(shaft.points as PackedVector3Array)[0].z,float(shaft.lid))
	var hall := ruin("hall")
	var keep: Array[Vector3] = []
	if sky != Vector3.INF: keep.append(sky)
	if not hall.is_empty(): keep.append(Vector3((hall.foot as Vector2).x,(hall.foot as Vector2).y,float(hall.reach)))
	for k in range(rng.randi_range(2,3)):
		var r := rng.randf_range(24.0,38.0)
		var at := _inland_point(rng,inner_max*0.3,keep,r*0.75)
		mounds.append(Vector4(at.x,at.y,r,rng.randf_range(5.0,11.0)))
	var summit_r := rng.randf_range(20.0,28.0)
	var summit := _inland_point(rng,inner_max*0.45,keep,summit_r)
	mounds.append(Vector4(summit.x,summit.y,summit_r,rng.randf_range(13.0,19.0)))

## A seeded point at least `least` m inland, and `room` m clear of the
## skylight's rim (`sky`: x, z, radius) if it can be.
func _inland_point(rng: RandomNumberGenerator, least: float, keep: Array[Vector3] = [], room := 0.0) -> Vector2:
	var fallback := Vector2.INF
	for k in range(300):
		var p := inner+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,inner_max*1.2)
		if -outline_sd(p.x,p.y) < least: continue
		if fallback == Vector2.INF: fallback = p
		if keep.any(func(c: Vector3) -> bool: return p.distance_to(Vector2(c.x,c.y)) < c.z+room+6.0): continue
		return p
	return fallback if fallback != Vector2.INF else inner

func _lay_lobes(rng: RandomNumberGenerator) -> void:
	lobes.clear()
	var turn := rng.randf()*TAU
	var count := rng.randi_range(LOBES.x,LOBES.y)
	for k in range(count):
		var a := turn+TAU*k/count+rng.randf_range(-0.5,0.5)
		var at := inner+Vector2.from_angle(a)*inner_max*rng.randf_range(LOBE_OUT.x,LOBE_OUT.y)
		lobes.append(Vector4(at.x,at.y,base-rng.randf_range(LOBE_TIP.x,LOBE_TIP.y),rng.randf_range(LOBE_R.x,LOBE_R.y)))

## A hole, its tube's segments added to the field's lists.
func _add_hole(h: Dictionary) -> void:
	var points: PackedVector3Array = h.points
	h.first = _seg_a.size()
	h.count = points.size()-1
	for i in range(points.size()-1):
		_seg_a.append(points[i])
		_seg_b.append(points[i+1])
	var box := AABB(points[0],Vector3.ZERO)
	for p in points: box = box.expand(p)
	var reach := float(h.r)/minf(float(h.squash),1.0)+ROUGH+1.0
	h.box = box.grow(reach)
	if not h.has("mid_y"): h.mid_y = points[0].y
	if not h.has("floor"): h.floor = -INF
	holes.append(h)

func _drop_hole(name_: String) -> void:
	for i in range(holes.size()):
		if holes[i].name != name_: continue
		var h: Dictionary = holes[i]
		holes.remove_at(i)
		# Its segments stay in the lists, unread.
		return

func hole(name_: String) -> Dictionary:
	for h: Dictionary in holes:
		if h.name == name_: return h
	return {}

## The clear radius of a hole of carved radius `r`: the rock's roughness
## and the drawn faces' slack allowed for.
static func clear_of(r: float) -> float:
	return r-ROUGH-SLACK

func _lay_holes(rng: RandomNumberGenerator) -> void:
	holes.clear()
	_lay_cavern(rng)
	_lay_arch(rng)
	_lay_windows(rng)
	_lay_shaft(rng)
	_lay_eye(rng)

## The cavern near the deepest inland point, lying along a seeded way.
func _lay_cavern(rng: RandomNumberGenerator) -> void:
	for k in range(TRIES):
		var r := rng.randf_range(CAVERN_R.x,CAVERN_R.y)
		var half_long := rng.randf_range(CAVERN_LONG.x,CAVERN_LONG.y)
		var way := Vector2.from_angle(rng.randf()*TAU)
		var mid2 := inner+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,8.0)
		var y := base-rng.randf_range(CAVERN_DOWN.x,CAVERN_DOWN.y)
		var a := Vector3(mid2.x-way.x*half_long,y,mid2.y-way.y*half_long)
		var b := Vector3(mid2.x+way.x*half_long,y,mid2.y+way.y*half_long)
		var high := r/CAVERN_SQUASH
		# Rock WALL thick round it, all the way.
		var ok := true
		for s in range(9):
			var c := a.lerp(b,s/8.0)
			for q in range(8):
				var dir := Vector2.from_angle(TAU*q/8.0)
				var edge := c+Vector3(dir.x*(r+WALL),0.0,dir.y*(r+WALL))
				if body(edge) > -1.0: ok = false
			if body(c+Vector3.DOWN*(high+WALL)) > 0.0: ok = false
		if not ok: continue
		_add_hole({"kind":"cavern","name":"cavern","points":PackedVector3Array([a,b]),"r":r,"squash":CAVERN_SQUASH,"mid_y":y,
			"floor":y-high*FLOOR_SHARE,"clear":clear_of(r)/CAVERN_SQUASH,"high":high})
		return
	problems.append("no room for the cavern")

## The windows out of the cavern: WINDOWS of them, spread round, each out
## through the side at about the cavern's height, one tight. Each is kept
## only if its mouth opens to the sky and the way out past it is clear.
func _lay_windows(rng: RandomNumberGenerator) -> void:
	var cav := hole("cavern")
	if cav.is_empty(): return
	var mid: Vector3 = ((cav.points as PackedVector3Array)[0]+(cav.points as PackedVector3Array)[1])*0.5
	var turn := rng.randf()*TAU
	var tight := rng.randi_range(0,WINDOWS-1)
	for w in range(WINDOWS):
		var placed := false
		for k in range(TRIES):
			var a := turn+TAU*w/WINDOWS+rng.randf_range(-0.8,0.8)
			var dir := Vector3(cos(a),0.0,sin(a))
			var r := TIGHT_R if w == tight else rng.randf_range(WINDOW_R.x,WINDOW_R.y)
			var y := mid.y+rng.randf_range(WINDOW_UP.x,WINDOW_UP.y)
			var from := Vector3(mid.x,y,mid.z)
			# Out along the way to past the body's face at this height.
			var out := _exit(from,dir,r)
			if out == Vector3.INF: continue
			var h := {"kind":"window","name":"window%d" % w,"points":PackedVector3Array([from,out]),"r":r,"squash":1.0,
				"clear":clear_of(r),"tight":w == tight,"dir":dir}
			# The tight one has a flat floor (a gate can stand on it).
			if w == tight: h.floor = y-3.4
			if not _apart(h,["cavern"]): continue
			_add_hole(h)
			if not _tube_ok(h) or not _lead_ok(out,dir,h.clear):
				_drop_hole(h.name)
				continue
			placed = true
			break
		if not placed: problems.append("window%d: no clear way out" % w)

## From a point in the rock, the point LEAD/3 past where a line along `dir`
## leaves the body for good (its rock past r+WALL behind), or INF if it
## never does within reach.
func _exit(from: Vector3, dir: Vector3, r: float) -> Vector3:
	var d := 0.0
	var last_rock := 0.0
	while d < 260.0:
		var p := from+dir*d
		if body(p) < r*0.6: last_rock = d
		d += 1.5
		if d-last_rock > 30.0: break
	if d >= 260.0: return Vector3.INF
	return from+dir*(last_rock+r+6.0)

## The skylight: straight down through the lid from a point off the
## cavern's middle, then slanting into its roof toward the window the dive
## leaves by (the wide window best lined up), so diving down it the plane
## is already heading out.
func _lay_shaft(rng: RandomNumberGenerator) -> void:
	var cav := hole("cavern")
	if cav.is_empty(): return
	var mid: Vector3 = ((cav.points as PackedVector3Array)[0]+(cav.points as PackedVector3Array)[1])*0.5
	var out := _dive_window()
	if out.is_empty():
		problems.append("no window for the dive")
		return
	var dir: Vector3 = out.dir
	for k in range(TRIES):
		var r := rng.randf_range(SHAFT_R.x,SHAFT_R.y)
		var back := dir.rotated(Vector3.UP,rng.randf_range(-0.35,0.35))
		var s := mid-back*rng.randf_range(SHAFT_OFF.x,SHAFT_OFF.y)
		var lid_r := r-LID_HOLE
		if -outline_sd(s.x,s.z) < lid_r+SHAFT_INLAND: continue
		var roof := mid.y+float(cav.high)*0.55
		var points := PackedVector3Array([Vector3(s.x,SHAFT_TOP,s.z),Vector3(s.x,base-6.0,s.z),Vector3(mid.x,roof,mid.z)+dir*4.0])
		var h := {"kind":"shaft","name":"shaft","points":points,"r":r,"squash":1.0,"clear":minf(clear_of(r),lid_r-1.6),"lid":lid_r}
		if not _apart(h,["cavern",out.name]): continue
		_add_hole(h)
		if not _tube_ok(h):
			_drop_hole("shaft")
			continue
		return
	problems.append("no room for the skylight")

## The wide window most in line with a dive from the top.
func _dive_window() -> Dictionary:
	var best := {}
	var best_r := 0.0
	for h: Dictionary in holes:
		if h.kind != "window" or bool(h.tight): continue
		if float(h.r) > best_r:
			best_r = float(h.r)
			best = h
	return best

## The arch: a short, tall tube through a flank, its crown ARCH_UNDER under
## the lid's base, where the rock along its chord is ARCH_ROCK long.
func _lay_arch(rng: RandomNumberGenerator) -> void:
	var tally := {}
	for k in range(TRIES*2):
		var r := rng.randf_range(ARCH_R.x,ARCH_R.y)
		var y := base-ARCH_UNDER-r/ARCH_SQUASH-rng.randf_range(0.0,5.0)
		var a := rng.randf()*TAU
		var along := Vector3(cos(a),0.0,sin(a))
		var across := Vector3(-along.z,0.0,along.x)
		# Out from the middle across the chord's way until the rock it
		# crosses is short enough to read as an arch.
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var found := false
		for step in range(2,40):
			var off := float(step)*3.0
			var centre := Vector3(inner.x,y,inner.y)+across*off*side
			var rock := _rock_along(centre,along,r)
			if rock < 0.0: break
			if rock > ARCH_ROCK.y: continue
			if rock < ARCH_ROCK.x:
				_tally(tally,"thin")
				break
			var span: Vector2 = _rock_span(centre,along,r)
			var p0 := centre+along*(span.x-r-8.0)
			var p1 := centre+along*(span.y+r+8.0)
			var h := {"kind":"arch","name":"arch","points":PackedVector3Array([p0,p1]),"r":r,"squash":ARCH_SQUASH,"mid_y":y,
				"clear":clear_of(r),"dir":along}
			if not _apart(h,[]):
				_tally(tally,"near a hole")
				break
			_add_hole(h)
			if not _tube_ok(h):
				_tally(tally,"tube")
				_drop_hole("arch")
				break
			if not _lead_ok(p0,-along,h.clear) or not _lead_ok(p1,along,h.clear):
				_tally(tally,"lead")
				_drop_hole("arch")
				break
			found = true
			break
		if found: return
	problems.append("no flank for the arch %s" % tally)

## The rock a line through `centre` along `along` crosses (m), from its
## first rock to its last; -1 if none.
func _rock_along(centre: Vector3, along: Vector3, r: float) -> float:
	var span := _rock_span(centre,along,r)
	if span.x > span.y: return -1.0
	return span.y-span.x

func _rock_span(centre: Vector3, along: Vector3, r: float) -> Vector2:
	var first := INF
	var last := -INF
	var d := -200.0
	while d <= 200.0:
		var p := centre+along*d
		if body(p) < -r*0.25:
			first = minf(first,d)
			last = maxf(last,d)
		d += 2.0
	return Vector2(first,last)

## The eye through the keel: low, where the keel is still thick enough
## round it, WALL under the cavern's floor.
func _lay_eye(rng: RandomNumberGenerator) -> void:
	var cav := hole("cavern")
	var under := float(cav.floor) if not cav.is_empty() else base-40.0
	var tally := {}
	for k in range(TRIES):
		var r := rng.randf_range(EYE_R.x,EYE_R.y)
		var y := under-WALL-r-rng.randf_range(1.0,6.0)
		var t := base-y
		var room := inner_max-inset(t,0.0)
		if room < r+EYE_ROOM:
			_tally(tally,"keel too thin")
			continue
		if y-r-EYE_ROOM < tip_y:
			_tally(tally,"under the tip")
			continue
		var a := rng.randf()*TAU
		var along := Vector3(cos(a),0.0,sin(a))
		var centre := Vector3(inner.x,y,inner.y)
		var span := _rock_span(centre,along,r)
		if span.x > span.y:
			_tally(tally,"no rock")
			continue
		var p0 := centre+along*(span.x-r-8.0)
		var p1 := centre+along*(span.y+r+8.0)
		var h := {"kind":"eye","name":"eye","points":PackedVector3Array([p0,p1]),"r":r,"squash":1.0,"clear":clear_of(r),"dir":along}
		if not _apart(h,[]):
			_tally(tally,"near a hole")
			continue
		_add_hole(h)
		if not _tube_ok(h):
			_tally(tally,"tube")
			_drop_hole("eye")
			continue
		if not _lead_ok(p0,-along,h.clear) or not _lead_ok(p1,along,h.clear):
			_tally(tally,"lead")
			_drop_hole("eye")
			continue
		return
	problems.append("no room for the eye %s" % tally)

## True if hole `h` keeps WALL of rock from every other hole, but where it
## opens into one of those named in `joins` (its line within WALL of their
## walls, as a window leaving the cavern): there it may meet anything else
## that opens into them too.
func _apart(h: Dictionary, joins: Array) -> bool:
	var points: PackedVector3Array = h.points
	var reach := float(h.r)/minf(float(h.squash),1.0)
	for i in range(points.size()-1):
		var n := maxi(1,ceili(points[i].distance_to(points[i+1])/1.5))
		for s in range(n+1):
			var c := points[i].lerp(points[i+1],float(s)/n)
			var joined := false
			for other: Dictionary in holes:
				if other.name in joins and _gap(c,other) < reach+WALL: joined = true
			if joined: continue
			for other: Dictionary in holes:
				if other.name in joins: continue
				if _gap(c,other) < reach+WALL: return false
	return true

## About how far a point stands from hole `h`'s wall (m, never more than
## the truth): its distance to the middle line, squashed as the hole is.
static func _gap(p: Vector3, h: Dictionary) -> float:
	var op: PackedVector3Array = h.points
	var squash := float(h.squash)
	var q := p
	if squash != 1.0: q.y = float(h.mid_y)+(p.y-float(h.mid_y))*squash
	var best := INF
	for j in range(op.size()-1): best = minf(best,_segment(q,op[j],op[j+1]))
	return (best-float(h.r))/maxf(squash,1.0)

static func _tally(tally: Dictionary, why: String) -> void:
	tally[why] = int(tally.get(why,0))+1

## The least distance between two segments (sampled; holes are long and
## few).
static func _segments(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var best := INF
	var n := maxi(2,ceili(a0.distance_to(a1)/1.5))
	for i in range(n+1):
		best = minf(best,_segment(a0.lerp(a1,float(i)/n),b0,b1))
	return best

## True if hole `h`'s tube is air: along its middle line every 1.5 m, its
## middle and a ring at its clear radius (squashed as the hole is).
func _tube_ok(h: Dictionary) -> bool:
	return tube_problem(h).is_empty()

## What blocks hole `h`'s tube, or "".
func tube_problem(h: Dictionary) -> String:
	var points: PackedVector3Array = h.points
	var clear := float(h.clear)
	var squash := float(h.squash)
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var along := (b-a).normalized()
		var side := along.cross(Vector3.UP)
		if side.length() < 0.1: side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(along).normalized()
		var n := maxi(1,ceili(a.distance_to(b)/1.5))
		for s in range(n+1):
			var c := a.lerp(b,float(s)/n)
			if field(c) < 0.0: return "%s: rock on its middle line at %s" % [h.name,c]
			for q in range(8):
				var ang := TAU*q/8.0
				var off := side*cos(ang)*clear+up*sin(ang)*clear/squash
				var p := c+off
				if float(h.floor) > -INF and p.y < float(h.floor)+0.4: continue
				if field(p) < 0.0: return "%s: rock %.1f m off its middle line at %s" % [h.name,clear,p]
	return ""

## True if the way on past a mouth (LEAD m along `dir`, clear `clear`) is
## open air (no rock, no lid).
func _lead_ok(from: Vector3, dir: Vector3, clear: float) -> bool:
	var side := dir.cross(Vector3.UP).normalized()
	var d := 0.0
	while d <= LEAD:
		var c := from+dir*d
		for p in [c,c+side*clear*0.7,c-side*clear*0.7,c+Vector3.UP*clear*0.7,c+Vector3.DOWN*clear*0.7]:
			if solid(p): return false
		d += 2.0
	return true

# --- Routes -------------------------------------------------------------------------

## The lines through the holes. Each runs LEAD m on past its mouths.
func _lay_routes() -> void:
	routes.clear()
	for name_ in ["arch","eye"]:
		var h := hole(name_)
		if h.is_empty(): continue
		var p: PackedVector3Array = h.points
		var along := (p[1]-p[0]).normalized()
		routes.append({"name":name_,"points":PackedVector3Array([p[0]-along*LEAD,p[0],p[1],p[1]+along*LEAD]),"holes":[name_]})
	var cav := hole("cavern")
	var shaft := hole("shaft")
	if cav.is_empty(): return
	var mid: Vector3 = ((cav.points as PackedVector3Array)[0]+(cav.points as PackedVector3Array)[1])*0.5
	var windows: Array = holes.filter(func(h: Dictionary) -> bool: return h.kind == "window")
	# The dive: in high over the top, down the skylight, through the cavern
	# and out its window.
	if not shaft.is_empty():
		var out := _dive_window()
		var sp: PackedVector3Array = shaft.points
		var wp: PackedVector3Array = out.points
		var dir: Vector3 = out.dir
		var top := sp[0]
		var ground := lid_top(top.x,top.z)
		var high := maxf(ground+DIVE_HIGH,_highest_top()+8.0)
		var start := Vector3(top.x,high,top.z)-dir*90.0
		var over := Vector3(top.x,high,top.z)-dir*28.0
		var lip := Vector3(top.x,ground+6.0,top.z)-dir*5.0
		var low := Vector3(mid.x,wp[0].y+1.0,mid.z)
		var tail := PackedVector3Array([sp[1],sp[2],low,wp[1],wp[1]+dir*LEAD])
		routes.append({"name":"dive","points":PackedVector3Array([start,over,lip])+tail,"holes":["shaft","cavern",out.name]})
		# The grand line: in low through the hall's lane, out over the lip
		# and straight down the skylight (flown over the lid's real ground,
		# so checked in flight, not here: `low`).
		for r: Dictionary in ruins:
			if r.kind != "hall": continue
			var lane: PackedVector3Array = r.lane
			var lip_low := Vector3(top.x,lane[1].y+0.5,top.z)-dir*(float(shaft.lid)-1.0)
			routes.append({"name":"grand","points":PackedVector3Array([lane[0]-dir*LEAD,lane[0],lane[1],lip_low])+tail,"holes":["hall","shaft","cavern",out.name],"low":true})
	# The thread: in by one window, out by the one most nearly opposite.
	var best := []
	var best_dot := 1.0
	for a: Dictionary in windows:
		for b: Dictionary in windows:
			if a == b: continue
			var d: float = (a.dir as Vector3).dot(b.dir as Vector3)
			if d < best_dot:
				best_dot = d
				best = [a,b]
	if not best.is_empty() and best_dot < -0.3:
		var a: Dictionary = best[0]
		var b: Dictionary = best[1]
		var ap: PackedVector3Array = a.points
		var bp: PackedVector3Array = b.points
		var in_dir: Vector3 = -(a.dir as Vector3)
		var mid_y := (ap[0].y+bp[0].y)*0.5
		routes.append({"name":"thread","points":PackedVector3Array([ap[1]-in_dir*LEAD,ap[1],Vector3(mid.x,mid_y,mid.z),bp[1],bp[1]+(b.dir as Vector3)*LEAD]),"holes":[a.name,"cavern",b.name]})

func _highest_top() -> float:
	var h := 0.0
	for m: Vector4 in mounds: h = maxf(h,lid_top(m.x,m.y))
	return h

func route(name_: String) -> Dictionary:
	for r: Dictionary in routes:
		if r.name == name_: return r
	return {}

## What blocks route `r`'s corridor (ROUTE_CLEAR round its line), or "".
## Corners are eased as a flight takes them (a plane turns in about 9 m).
func route_problem(r: Dictionary) -> String:
	if bool(r.get("low",false)): return ""
	var points: PackedVector3Array = r.points
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var n := maxi(1,ceili(a.distance_to(b)/1.0))
		for s in range(n+1):
			var c := a.lerp(b,float(s)/n)
			if solid(c,ROUTE_CLEAR*0.5): return "%s: blocked at %s" % [r.name,c]
			for off in [Vector3(ROUTE_CLEAR,0,0),Vector3(-ROUTE_CLEAR,0,0),Vector3(0,0,ROUTE_CLEAR),Vector3(0,0,-ROUTE_CLEAR),Vector3(0,ROUTE_CLEAR*0.6,0),Vector3(0,-ROUTE_CLEAR*0.6,0)]:
				if solid(c+off): return "%s: blocked %.1f m off its line at %s" % [r.name,ROUTE_CLEAR,c+off]
	return ""

# --- The lid's recipe ----------------------------------------------------------------

func _lay_recipe(rng: RandomNumberGenerator) -> void:
	var looks := {"slate":1.0,"basalt_warm":0.8,"basalt":0.5}
	var total := 0.0
	for k in looks: total += float(looks[k])
	var roll := rng.randf()*total
	var palette := "slate"
	for k: String in looks:
		roll -= float(looks[k])
		if roll <= 0.0:
			palette = k
			break
	var smooth: Array[Vector4] = []
	var peaks: Array[Vector4] = []
	for i in range(mounds.size()):
		if i == mounds.size()-1: peaks.append(mounds[i])
		else: smooth.append(mounds[i])
	var lid_holes: Array[Vector3] = []
	var clear: Array[Vector3] = []
	var shaft := hole("shaft")
	if not shaft.is_empty():
		var s: Vector3 = (shaft.points as PackedVector3Array)[0]
		lid_holes.append(Vector3(s.x,s.z,float(shaft.lid)))
		clear.append(Vector3(s.x,s.z,float(shaft.lid)+4.0))
	recipe = {"kind":"hills","radius":radius,"step":STEP,"base":LID_BASE,"mounds":smooth,"peaks":peaks,"dome":DOME,"keel":0.0,
		"trees":Vector2i(160,220),"tree_pool":{"tree":1.0,"broadleaf":0.5,"birch":0.5,"juniper":0.45,"redwood":0.12},
		"mixed":true,"tree_size":Vector2(0.9,1.6),"apart":1.0,"drifts":Vector2i(8,12),"undergrowth":0.4,"tufts":0.3,
		"erode":{"detail":0.06,"k":0.014,"max_cut":0.5},
		"rock":{"palette":palette,"tone":rng.randf_range(0.9,1.08),"vary":rng.randf()},
		"holes":lid_holes,"clear":clear+_clear,"pads":_pads.duplicate()}

## Ground the lid's planting keeps off (a ruin's footprint): x, z, radius.
func keep_clear(at: Vector2, r: float) -> void:
	_clear.append(Vector3(at.x,at.y,r))

## A level pad on the lid (a ruin stands on it): x, z, radius, lift.
func level(at: Vector2, r: float, lift := 0.0) -> void:
	_pads.append(Vector4(at.x,at.y,r,lift))

# --- The ruins ----------------------------------------------------------------------

## The ruins, each a record for scripts/pierced_ruins.gd: {kind, at (its
## frame, lid frame, y estimated: the builder reads the real ground), seed,
## weathered, and its own}:
##   feed: an aqueduct over the top from its head to the skylight's lip,
##     its water spilling down the shaft into the cavern;
##   gate: a gothic arch standing in the tight window, its opening the way
##     through (the window's tube centred on it);
##   hall: a short colossus hall on the top, its lane lined up with the
##     skylight, so a flight comes out of the nave and dives;
##   run: an aqueduct across the cavern's flat floor, under the flights.
## Each keeps the lid's trees off its ground and its bulk off the routes.
func _lay_ruins(rng: RandomNumberGenerator) -> void:
	var shaft := hole("shaft")
	var out := _dive_window()
	if shaft.is_empty() or out.is_empty(): return
	var sp: PackedVector3Array = shaft.points
	var sky := Vector2(sp[0].x,sp[0].z)
	var lid_r := float(shaft.lid)
	var dive := Vector2((out.dir as Vector3).x,(out.dir as Vector3).z).normalized()
	_lay_feed(rng,sky,lid_r,dive)
	_lay_gate(rng)
	_lay_run(rng)

## The hall, laid before the hills (they keep off it).
func _lay_hall_first(rng: RandomNumberGenerator) -> void:
	var shaft := hole("shaft")
	var out := _dive_window()
	if shaft.is_empty() or out.is_empty(): return
	var sp: PackedVector3Array = shaft.points
	_lay_hall(rng,Vector2(sp[0].x,sp[0].z),float(shaft.lid),Vector2((out.dir as Vector3).x,(out.dir as Vector3).z).normalized())

## The frame turned so +X runs along `way` (x, z), at `at`.
static func frame_along(way: Vector2, at: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,atan2(-way.y,way.x)),at)

## True if the ground along a line (x, z) from `a` to `b`, `half` m either
## side, is land at least `inland` m in, climbing no more than `climb` m.
func _ground_ok(a: Vector2, b: Vector2, half: float, inland: float, climb: float) -> bool:
	var way := (b-a).normalized()
	var side := Vector2(-way.y,way.x)
	var lo := INF
	var hi := -INF
	var n := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(n+1):
		for k: float in [-1.0,0.0,1.0]:
			var p := a.lerp(b,float(i)/n)+side*half*k
			if -outline_sd(p.x,p.y) < inland: return false
			var y := lid_top(p.x,p.y)
			lo = minf(lo,y)
			hi = maxf(hi,y)
	return hi-lo <= climb

## True if a box (centre and half, x z) keeps `room` m off every ruin laid.
func _ruin_room(centre: Vector2, half: float, room: float) -> bool:
	for r: Dictionary in ruins:
		var c: Vector2 = r.foot
		if c.distance_to(centre) < float(r.reach)+half+room: return false
	return true

## The hall: HALL_BAYS bays on the top, its lane's middle line running on
## through the skylight's middle along the dive's way, its far mouth
## HALL_BACK m short of the hole.
func _lay_hall(rng: RandomNumberGenerator, sky: Vector2, lid_r: float, dive: Vector2) -> void:
	const Hall = preload("res://scripts/ruin_kit_hall.gd")
	var lane_z := (Hall.LANE.x+Hall.LANE.y)*0.5
	# Along the dive's way in, or turned a little off it (the flight bends
	# into the dive), its full bays or one fewer: the first that stands on
	# land.
	var found := false
	var way := dive
	var bays := HALL_BAYS
	var origin := Vector2.ZERO
	var centre := Vector2.ZERO
	for tried_bays: int in [HALL_BAYS,HALL_BAYS-1]:
		for turn: float in HALL_TURNS:
			way = dive.rotated(turn)
			var length_try := Hall.BAY*tried_bays
			# +Z in the hall's frame (its right, looking down the nave).
			var r3: Vector3 = Basis(Vector3.UP,atan2(-way.y,way.x))*Vector3.BACK
			var right := Vector2(r3.x,r3.z)
			var end_lane := sky-way*(lid_r+HALL_BACK)
			origin = end_lane-way*length_try-right*lane_z
			centre = origin+way*length_try*0.5
			if _ground_ok(origin-way*2.0,origin+way*(length_try+2.0),Hall.WALL_Z+2.0,3.0,4.0):
				found = true
				bays = tried_bays
				break
		if found: break
	if not found: return
	var length := Hall.BAY*bays
	var y := lid_top(centre.x,centre.y)
	var at := frame_along(way,Vector3(origin.x,y,origin.y))
	var r := {"kind":"hall","at":at,"seed":rng.randi(),"weathered":rng.randf_range(WEATHERED.x,WEATHERED.y),"bays":bays,
		"foot":centre,"reach":length*0.5+Hall.WALL_Z,
		"lane":PackedVector3Array([at*Vector3(0.0,Hall.LANE_Y.x+1.3,lane_z),at*Vector3(length,Hall.LANE_Y.x+1.3,lane_z)])}
	ruins.append(r)
	level(centre,length*0.5+4.0)
	keep_clear(centre,length*0.5+Hall.WALL_Z)
	# Its bulk: the walls, columns and roof either side of the lane and
	# over it; the lane itself open.
	var top := Hall.ROOF_TOP+Hall.GABLE_RISE
	block(at,Vector3(length*0.5,top*0.5,(-Hall.WALL_Z-1.0+Hall.LANE.x-0.2)*0.5),Vector3(length*0.5+0.5,top*0.5+1.0,(Hall.WALL_Z+1.0+Hall.LANE.x-0.2)*0.5))
	block(at,Vector3(length*0.5,top*0.5,(Hall.WALL_Z+1.0+Hall.LANE.y+0.2)*0.5),Vector3(length*0.5+0.5,top*0.5+1.0,(Hall.WALL_Z+1.0-Hall.LANE.y-0.2)*0.5))
	block(at,Vector3(length*0.5,(Hall.LANE_Y.y+0.2+top)*0.5,lane_z),Vector3(length*0.5+0.5,(top-Hall.LANE_Y.y-0.2)*0.5+1.0,(Hall.LANE.y-Hall.LANE.x)*0.5+0.2))

## The feed: an aqueduct from its head over the top to the skylight's lip,
## coming in from the side (never down the dive's way in, nor along the
## hall), its last pier FEED_EDGE m back from the hole's edge; its water
## spills off the channel's end into the shaft.
func _lay_feed(rng: RandomNumberGenerator, sky: Vector2, lid_r: float, dive: Vector2) -> void:
	const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
	for k in range(TRIES):
		var n := rng.randi_range(FEED_SPANS.x,FEED_SPANS.y)
		# From the side: 70 to 160 degrees off the dive's way.
		var turn := rng.randf_range(deg_to_rad(70.0),deg_to_rad(160.0))*(1.0 if rng.randf() < 0.5 else -1.0)
		var way := dive.rotated(turn)
		var edge := sky-way*(lid_r+FEED_EDGE)
		var head := edge-way*Aqueduct.SPAN*n
		if not _ground_ok(head-way*6.0,edge-way*1.5,Aqueduct.DECK_WIDTH,FEED_INLAND,FEED_CLIMB): continue
		var foot := (head+edge)*0.5
		if not _ruin_room(foot,Aqueduct.SPAN*n*0.5,6.0): continue
		# Its water falls clear down the shaft, a long way.
		var lip := edge+way*(Aqueduct.PIER.x*0.5+FEED_SPOUT)
		var lip_y := lid_top(edge.x,edge.y)+Aqueduct.DECK
		if lip_y-fall_from(Vector3(lip.x,lip_y,lip.y)).y < FEED_DROP: continue
		var top := -INF
		var steps := ceili(head.distance_to(edge)/2.0)
		for i in range(steps+1):
			var p := head.lerp(edge,float(i)/steps)
			top = maxf(top,lid_top(p.x,p.y))
		var at := frame_along(way,Vector3(head.x,top,head.y))
		ruins.append({"kind":"feed","at":at,"seed":rng.randi(),"weathered":rng.randf_range(WEATHERED.x,WEATHERED.y),"spans":n,
			"foot":foot,"reach":Aqueduct.SPAN*n*0.5+4.0,"floor":float(hole("cavern").get("floor",base-40.0))})
		for i in range(steps+1):
			keep_clear(head.lerp(edge,float(i)/steps),3.5)
		keep_clear(head-way*3.0,5.0)
		var length := Aqueduct.SPAN*n
		block(at,Vector3(length*0.5-2.0,(Aqueduct.DECK+1.0)*0.5,0.0),Vector3(length*0.5+4.0,(Aqueduct.DECK+1.0)*0.5+1.0,Aqueduct.PIER.y*0.5+Aqueduct.CUTWATER.x))
		return

## The gate: a gothic arch standing a little in from the tight window's
## mouth on its flat floor, facing out, its opening on the window's middle.
func _lay_gate(rng: RandomNumberGenerator) -> void:
	const RuinKit = preload("res://scripts/ruin_kit.gd")
	for h: Dictionary in holes:
		if h.kind != "window" or not bool(h.get("tight",false)): continue
		var p: PackedVector3Array = h.points
		var dir: Vector3 = h.dir
		# The mouth: where the line leaves the rock for good, walking in.
		var mouth := p[1]
		var d := 0.0
		var length := p[0].distance_to(p[1])
		while d < length:
			if body(p[1]-dir*d) < 0.0:
				mouth = p[1]-dir*d
				break
			d += 0.5
		var at_line := mouth-dir*GATE_IN
		var at := Transform3D(Basis(Vector3.UP.cross(dir).normalized(),Vector3.UP,dir),Vector3(at_line.x,float(h.floor),at_line.z))
		ruins.append({"kind":"gate","at":at,"seed":rng.randi(),"weathered":rng.randf_range(0.35,0.6),"foot":Vector2(at_line.x,at_line.z),"reach":6.0,"window":h.name})
		h.gate = true
		var half := RuinKit.ARCH_SPAN*0.5
		var crown := RuinKit.SPRING+half*1.732
		var depth := RuinKit.ARCH_DEPTH*0.5+0.6
		# Its piers and buttresses either side of the opening, and the head
		# over it (the pointed arch narrows from its springing).
		for side: float in [-1.0,1.0]:
			block(at,Vector3(side*(half+3.0),crown*0.5+1.0,0.0),Vector3(3.0,crown*0.5+2.5,depth))
			block(at,Vector3(side*(half-0.2),(RuinKit.SPRING+1.6+crown+4.0)*0.5,0.0),Vector3(0.6,(crown+4.0-RuinKit.SPRING-1.6)*0.5,depth))
		block(at,Vector3(0.0,crown+2.0,0.0),Vector3(half+3.0,2.0,depth))

## The run: an aqueduct across the cavern's flat floor along its length,
## its deck under the flights through the cavern.
func _lay_run(rng: RandomNumberGenerator) -> void:
	const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
	var cav := hole("cavern")
	var shaft := hole("shaft")
	var out := _dive_window()
	if cav.is_empty() or shaft.is_empty() or out.is_empty(): return
	var cp: PackedVector3Array = cav.points
	var way3 := (cp[1]-cp[0]).normalized()
	var way := Vector2(way3.x,way3.z).normalized()
	var across := Vector2(-way.y,way.x)
	var mid := (cp[0]+cp[1])*0.5
	var floor_y := float(cav.floor)
	var long := cp[0].distance_to(cp[1])+float(cav.r)*0.9
	# The dive comes down the shaft into the cavern and pulls out toward its
	# window: the run keeps RUN_CLEAR off that line (flat), so a plane
	# pulling out of the dive never meets its deck.
	var bottom: Vector3 = (shaft.points as PackedVector3Array)[2]
	var dive := Vector2((out.dir as Vector3).x,(out.dir as Vector3).z).normalized()
	var d0 := Vector2(bottom.x,bottom.z)-dive*6.0
	var d1 := Vector2(mid.x,mid.z)+dive*float(cav.r)
	for n in range(clampi(floori(long/Aqueduct.SPAN),2,RUN_SPANS),1,-1):
		var length := Aqueduct.SPAN*n
		var slack := maxf(long-length,0.0)*0.5
		for shift: Vector2 in [Vector2.ZERO,Vector2(slack,0.0),Vector2(-slack,0.0),Vector2(slack,3.0),Vector2(-slack,-3.0),Vector2(slack,-3.0),Vector2(-slack,3.0)]:
			var centre := Vector2(mid.x,mid.z)+way*shift.x+across*shift.y
			var a := centre-way*length*0.5
			var b := centre+way*length*0.5
			if _flat_gap(a,b,d0,d1) < RUN_CLEAR: continue
			var at := frame_along(way,Vector3(a.x,floor_y,a.y))
			ruins.append({"kind":"run","at":at,"seed":rng.randi(),"weathered":rng.randf_range(WEATHERED.x,WEATHERED.y),"spans":n,
				"foot":centre,"reach":length*0.5})
			block(at,Vector3(length*0.5,(Aqueduct.DECK+1.0)*0.5,0.0),Vector3(length*0.5+1.0,(Aqueduct.DECK+1.0)*0.5+0.3,Aqueduct.PIER.y*0.5+Aqueduct.CUTWATER.x))
			return

## The least distance between two flat segments (sampled).
static func _flat_gap(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> float:
	var best := INF
	for i in range(21):
		var p := a0.lerp(a1,i/20.0)
		var ab := b1-b0
		var k := clampf((p-b0).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
		best = minf(best,p.distance_to(b0+ab*k))
	return best

## Where water poured from `lip` (lid frame) lands: straight down to the
## first rock (or the keel's tip).
func fall_from(lip: Vector3) -> Vector3:
	var p := lip
	while p.y > tip_y:
		p.y -= 1.0
		if field(p) < 0.0 or lid_solid(p): return p+Vector3.UP*0.5
	return p

## The ruin of `kind`, or {}.
func ruin(kind: String) -> Dictionary:
	for r: Dictionary in ruins:
		if r.kind == kind: return r
	return {}

# --- Its colour ---------------------------------------------------------------------

## The rock's colour on a face at `p` facing `n` (linear; the ruin stone's
## lighting, scripts/ruin_kit.gd): beds of the lid's rock look stacked
## BED_H high, each its own shade, warmer or cooler in patches, pale streaks
## run down some joints, turf on the ledges lying back outside, a little
## lighter and warmer in the holes (`inside`), going to the void's mist
## toward the keel's tip.
func tint(p: Vector3, n: Vector3, inside: bool) -> Color:
	if _tones.is_empty(): _make_tones()
	var wave := _ledge.get_noise_2d(p.x*0.8,p.z*0.8)*BED_WAVE
	var bed := floori((p.y+wave)/BED_H)
	var c: Color = _tones[posmod(bed*7+(bed*bed) % 5,_tones.size())]*WARMTH
	c *= lerpf(BED_TONE.x,BED_TONE.y,fposmod(sin(float(bed)*12.9898)*43758.5453,1.0))
	var w := _lump.get_noise_3d(p.x*0.6,p.y*0.9,p.z*0.6)
	c = Color(c.r*(1.0+WARM*w),c.g*(1.0+WARM*0.3*w),c.b*(1.0-WARM*w))
	var streak := _rough.get_noise_2d(p.x*0.35,p.z*0.35)*0.5+0.5
	if streak > 1.0-STREAK.x: c = c.lerp(PALE,STREAK.y*clampf((streak-(1.0-STREAK.x))/STREAK.x,0.0,1.0))
	if not inside and n.y > LEDGE_UP and _ledge.get_noise_2d(p.x*3.0,p.z*3.0) > -0.35 and p.y > tip_y+25.0:
		return TURF*(1.0+0.2*_crag.get_noise_2d(p.x,p.z))
	if inside: c = Color(c.r*INSIDE.r,c.g*INSIDE.g,c.b*INSIDE.b)
	var mist := 1.0-smoothstep(tip_y+2.0,tip_y+MIST_UP,p.y)
	return c.lerp(MIST,mist*0.65)

func _make_tones() -> void:
	var rock: Dictionary = recipe.get("rock",{"palette":"slate","tone":1.0,"vary":0.5})
	for key in ["core_b","core_a","bedrock","core_c","clay","core_b","shale"]:
		_tones.append(RockLooks.colour_of(str(rock.palette),key,float(rock.tone),float(rock.vary)))

## How sheltered a face at `p` facing `n` is, 0 (open sky) to 1 (deep in
## the rock): of a few rays out round its normal, the share the rock stops
## within SHELTER_REACH, nearer counting more.
func shelter(p: Vector3, n: Vector3) -> float:
	var side := n.cross(Vector3.UP)
	if side.length() < 0.1: side = n.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(n).normalized()
	var dirs := [n,(n+side*1.4).normalized(),(n-side*1.4).normalized(),(n+up*1.4).normalized(),(n-up*1.4).normalized(),(n+Vector3.UP).normalized()]
	var stopped := 0.0
	for d: Vector3 in dirs:
		for step: float in SHELTER_STEPS:
			if field(p+d*step) < 0.0:
				stopped += 1.0-0.5*step/SHELTER_REACH
				break
	return clampf(stopped/dirs.size(),0.0,1.0)

# --- Checking it --------------------------------------------------------------------

## Fills `problems` with what is wrong: holes missing or blocked, routes
## blocked, holes the plane cannot pass.
func verify() -> Array[String]:
	for name_ in ["cavern","shaft","arch"]:
		if hole(name_).is_empty() and not problems.any(func(p: String) -> bool: return p.contains(name_)): problems.append("no %s" % name_)
	for h: Dictionary in holes:
		var why := tube_problem(h)
		if not why.is_empty(): problems.append(why)
		var room := float(h.clear)-WorldScale.span*0.5
		if h.kind == "cavern": room = float(h.clear)-WorldScale.span*0.5
		if room < (ROOM_TIGHT if bool(h.get("tight",false)) else ROOM_WIDE): problems.append("%s: only %.1f m past the wingtips" % [h.name,room])
	for r: Dictionary in routes:
		var why := route_problem(r)
		if not why.is_empty(): problems.append(why)
	if route("dive").is_empty(): problems.append("no dive route")
	return problems

## The hole kinds and their room past the wingtips (m), for the record.
func summary() -> Array:
	var out := []
	for h: Dictionary in holes:
		out.append({"name":h.name,"kind":h.kind,"across":float(h.clear)*2.0,"room":float(h.clear)-WorldScale.span*0.5,"tight":bool(h.get("tight",false))})
	return out

## The whole mass's box in the lid frame (lid and body).
func bounds() -> AABB:
	var reach := 0.0
	for k in range(sd_n*sd_n):
		if sd[k] < 0.0: reach = maxf(reach,(sd_origin+Vector2(k % sd_n,k/sd_n)*RASTER).length())
	return AABB(Vector3(-reach-4.0,tip_y-4.0,-reach-4.0),Vector3(reach*2.0+8.0,_highest_top()+8.0-tip_y,reach*2.0+8.0))
