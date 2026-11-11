extends Node3D
## The railroad's trestles and bridges (spec-railroad.md, lane line): each
## span (trestles and bridges end to end, RailLine.spans()) is a deck along
## the line that the track lies on, held up by a structure of one of three
## kinds, chosen per span by rule from the line and the land under it (so a
## re-laid line gets its kinds on its own), and ending on a stone abutment
## at each end, where the bed's bank spills round it (rail_bed.gd's cone).
##
## - ARCH, a stone arch bridge: a span mostly over water (the line's
##   "bridge" stretches) whose deck stands under VIADUCT_FROM m over it (the
##   creeks). Segmental arches of about ARCH_WANT m on piers with cutwaters,
##   the arch rings proud of the spandrels, a parapet each side.
## - TRESTLE, a framed timber trestle: the rest under TIMBER_MOST m. Bents of
##   four posts, the outer two battered, on stone pedestals (a stone pier with
##   cutwaters where a bent stands in water); a girt across each bent every
##   TIER m down and sway braces in the outer bays; a cap and stringers under a
##   plank deck with a handrail. Over TOWER_FROM m the bents pair into towers
##   (TOWER_BAY apart, braced along the line on every row of posts) with an
##   open bay between towers, its rows tied by girts at each tier.
## - VIADUCT, a stone viaduct: a span mostly over water standing VIADUCT_FROM m
##   or more over it, or any span over TIMBER_MOST m. Battered piers with
##   cutwaters rising to the parapet as pilasters, round arches between them,
##   and, as tall as it stands, tiers: a gallery passage through every pier
##   along the line under the arches' springing, and under it an arcade
##   between the piers whose top is the gallery's floor, then the next
##   gallery and arcade down, while they fit (an arcade only over a fair
##   opening, TOY_BAY tall, to fly under).
##
## The flown openings (WorldScale.opening, so they hold at any plane scale):
## the trestle's corridor along the line between its inner posts (TOY_BAY:
## 8 m) through each bent's tier windows (TIER - GIRT_D tall), its open bays
## across the line between towers (TOY_OPEN: 17 m), the top tier under the
## deck; the viaduct's gallery passages (TOY_BAY wide, TOY_PASS tall), the
## arches over each gallery floor and the arcades under it.
##
## Every member is a convex hull of two matching rings of corners (a beam's
## ends, a pier band's bottom and top, an arch slice's cut faces). The same
## hull is drawn, is the collider (its drawn faces; physics layer 1 as the
## arches, within COLLIDE of the plane) and answers the flight: its face
## planes give the stretch of a vertical line inside it (`_hull_y`), so what
## you see is what you hit. The deck and the abutments answer as before:
## `ground` gives the deck's top over it and Vector2(top, underside) under
## it; `inside` keeps the camera and the rolling plane out; `land_y` puts
## the wheels and the eye on the deck. A pass over the deck scores as a
## graze over stone, under it or through a window as a passage, and the wing
## rays read every member as stone (NearMiss `_what`).
##
## Built in PIECE m pieces, each a near mesh (to NEAR_END m, casting
## shadows) and a far one past it without the handrail's posts and mid rail
## or the arches' ring bands, casting none.
##
## Seed 1's wilderness, with the bed (RailTrack.wanted); `--no-railroad`
## leaves it out. `setup(field, line)` takes another line (a driver's test
## line with `across`), for spans laid anywhere.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const RailBed = preload("res://scripts/endless/rail_bed.gd")
const RailTrack = preload("res://scripts/endless/rail_track.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const RailStops = preload("res://scripts/endless/rail_stops.gd")
const TIMBER_SHADER = preload("res://shaders/rail_timber.gdshader")
const STONE_SHADER = preload("res://shaders/rail_stone.gdshader")

const LAYER := 1
## The deck's frames (m of s) and its pieces (m of s): one mesh and one
## collider each.
const FRAME := 4.0
const PIECE := 64.0
## The near mesh to NEAR_END m, the far one from there to VISIBLE m;
## colliders within COLLIDE of the plane, freed past FREE_AT x that.
const VISIBLE := 6000.0
const NEAR_END := 900.0
const COLLIDE := 120.0
const FREE_AT := 1.25
const SEA_Y := -40.0
## The deck: its depth under the sleepers' foot; its half width past the
## widest car's side (RailLine.CAR_WIDTH) at either track.
const DECK_DEPTH := 1.8
const DECK_PAST := 1.4
## The parapet (stone) or handrail (timber) along each edge: its height over
## the deck's top and its thickness in from the edge.
const PARAPET_H := 1.1
const PARAPET_T := 0.6
## The abutments: from ABUT_BACK m before a span's end (under the bed) to
## ABUT_IN m into it, ABUT_PAST m wider than the bed's flat each side.
const ABUT_BACK := 3.0
const ABUT_IN := 5.0
const ABUT_PAST := 1.0
## Feet sink this far under the ground.
const SINK := 2.0

# --- The kinds -------------------------------------------------------------------
const ARCH := 0
const TRESTLE := 1
const VIADUCT := 2
const KIND_NAMES := ["arch","trestle","viaduct"]
## A span is over water when at least WET_SHARE of it is the line's "bridge";
## over water it is a viaduct from VIADUCT_FROM m over the water (its deck's
## top), an arch bridge under it; any span over TIMBER_MOST m is a viaduct.
const WET_SHARE := 0.5
const VIADUCT_FROM := 18.0
const TIMBER_MOST := 62.0

# --- The trestle ------------------------------------------------------------------
## The corridor between the inner posts (toy width TOY_BAY: 8 m at the
## defaults); the open bay between towers (TOY_OPEN: 17 m); the plain bents'
## spacing on a low trestle (TOY_PLAIN between them).
const TOY_BAY := 4.0
const TOY_OPEN := 8.5
const TOY_PLAIN := 4.5
## Towers from TOWER_FROM m tall: two bents TOWER_BAY m apart.
const TOWER_FROM := 16.0
const TOWER_BAY := 7.0
## A post's side; the outer posts' batter (m out per m down); their tops in
## from the deck's edge.
const POST := 0.9
const BATTER := 1.0/6.0
const OUTER_IN := 1.5
## The cap under the deck (deep, along) and how far it runs past the outer
## posts.
const CAP_D := 0.8
const CAP_ALONG := 1.1
const CAP_PAST := 0.8
## A girt (deep, thick) on each face of a bent every TIER m down from the
## cap: the tier's window TIER - GIRT_D tall (TIER from the corridor's width).
const GIRT_D := 0.45
const GIRT_T := 0.3
const GIRT_PAST := 0.35
## Braces: in the bent's plane (wide) and across it (thick).
const BRACE_W := 0.34
const BRACE_T := 0.24
## The stone pedestal under each post: its side and its top over the ground.
const PED := 1.9
const PED_UP := 0.7
## A bent in water stands on a stone pier to WET_UP m over the water, past
## its outer posts by WET_PAST m, with cutwaters WET_NOSE m out.
const WET_UP := 3.0
const WET_PAST := 1.4
const WET_ALONG := 1.5
const WET_NOSE := 2.6
## Stringers under the deck's planks (wide), the planks' depth.
const STRINGER_W := 0.7
const PLANK_D := 0.35

# --- The arch bridge -----------------------------------------------------------------
## Arches about ARCH_WANT m clear between piers PIER_T m thick, springing
## SPRING_UP m over the water or ground, their ring RING m deep.
const ARCH_WANT := 9.0
const PIER_T := 2.6
const SPRING_UP := 0.5
const RING := 0.7
## The spandrels in from the deck's edge (under its string course), the ring
## bands proud of them.
const SPANDREL_IN := 0.3
const BAND_OUT := 0.14

# --- The viaduct -----------------------------------------------------------------------
## Pier spacing: VIA_PITCH x the span's height, between VIA_PITCH_MIN and
## VIA_PITCH_MAX m; a pier's thickness along the line at the arches'
## springing, its batter (m out per m down) along and across.
const VIA_PITCH := 0.75
const VIA_PITCH_MIN := 22.0
const VIA_PITCH_MAX := 36.0
const VIA_T := 4.0
const VIA_BATTER_A := 0.025
const VIA_BATTER_W := 0.02
const VIA_RING := 1.2
## The gallery passage through each pier (TOY_BAY wide, TOY_PASS tall: 8 x 12
## m), its head PASS_HEAD m under the springing, its sill at least
## PASS_FLOOR m over the ground or water; the arcade under it BAND m deep.
const TOY_PASS := 6.0
const PASS_HEAD := 1.5
const PASS_FLOOR := 2.5
const BAND := 2.4
## The tide line: stone under it DAMP_UP m over the water is darker.
const DAMP_UP := 1.2

# --- Colours ------------------------------------------------------------------------
## Over the ruins' stone (its vertex colour) and the timber's grain. The
## alpha is the shelter (the stone's bounce under a roof: 1 open air, 0 deep
## under it): faces turned down read in the deck's shade instead of black.
const TIMBER_C := Color(0.50,0.39,0.29,0.85)
const TIMBER_DARK := Color(0.40,0.31,0.24,0.85)
const DECK_TOP_C := Color(0.48,0.41,0.33)
const TRACK_C := Color(0.36,0.31,0.26)
const STONE_C := Color(0.80,0.74,0.65,0.65)
const STONE_LIGHT := Color(0.88,0.83,0.74,0.7)
const STONE_DAMP := Color(0.64,0.62,0.56,0.6)
const IRON_C := Color(0.25,0.24,0.23)
const TRACK_STRIP := 0.3
const TRACK_UP := RailTrack.BALLAST_TOP-RailTrack.SLEEPER_BASE
const UNDER_SHELTER := 0.3
## Materials.
const STONE := 0
const WOOD := 1
const PAINT := 2

## A hull's flags: its first or second ring's face hidden (a cut inside
## stone), one of its sides hidden (SIDE << i), near only (not in the far
## mesh).
const HIDE_A := 1
const HIDE_B := 2
const NEAR_ONLY := 4
const SIDE := 8

var line: RefCounted
var field: RefCounted
var _bed: RefCounted
var _across: Callable
## Half the deck's width, the bed's flat half (RailBed.HALF).
var _deck_half := 10.9
var _half := 12.5
var _top_up := RailTrack.SLEEPER_BASE
## The spans: s0, s1 each, kind, its most height over the ground or water,
## and a coarse grid of CELL m squares listing the spans whose reach meets
## them.
const CELL := 64.0
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _kind := PackedInt32Array()
var _tall := PackedFloat32Array()
var _cells := {}
var _abut_foot := PackedVector2Array()

## The hulls: two rings each (`_hn` corners, at `_hv0` in `_hv`), colour,
## material, flags, mid s, span; their face planes (nx, ny, nz, o: inside
## where n.p <= o) at `_hp0` (`_hpn` of them) in `_hp`; their XZ boxes
## (x0, z0, x1, z1, y0, y1); and a grid of HCELL m squares in (s, d) listing the
## hulls within HMARGIN of each.
const HCELL := 4.0
const HMARGIN := 3.0
var _hv := PackedVector3Array()
var _hv0 := PackedInt32Array()
var _hn := PackedInt32Array()
var _hcol := PackedColorArray()
var _hmat := PackedByteArray()
var _hflag := PackedInt32Array()
var _hs := PackedFloat32Array()
var _hk := PackedInt32Array()
var _hp := PackedFloat32Array()
var _hp0 := PackedInt32Array()
var _hpn := PackedInt32Array()
var _hbox := PackedFloat32Array()
var _hcells := {}

## The pieces: centre, radius, origin, faces (relative to the origin), body.
var _pc := PackedVector3Array()
var _po := PackedVector3Array()
var _pr := PackedFloat32Array()
var _faces: Array = []
var _body: Array = []
var _mats: Array[Material] = []
## What was built (a driver's count).
var supports := 0
var tris := 0
var far_tris := 0
var build_ms := 0.0
var plan_ms := 0.0
var kinds := PackedInt32Array([0,0,0])

## A level frame on the line at s: the bed's centre, along (level) and right.
class Fr:
	var s := 0.0
	var c := Vector3.ZERO
	var f := Vector3.ZERO
	var r := Vector3.ZERO
	## The point `d` m right, `a` m along, at height y.
	func at(d: float, y: float, a := 0.0) -> Vector3:
		return Vector3(c.x+r.x*d+f.x*a,y,c.z+r.z*d+f.z*a)

func setup(land_field: RefCounted, a_line: RefCounted = null) -> void:
	var t0 := Time.get_ticks_usec()
	field = land_field
	line = a_line if a_line != null else RailLine.shared()
	if a_line != null and a_line.has_method("across"):
		_across = Callable(a_line,"across")
	else:
		_bed = RailBed.new()
		_across = Callable(_bed,"across")
	_half = RailBed.HALF
	var gap: float = line.track_gap()
	_deck_half = gap*0.5+RailLine.CAR_WIDTH*0.5+DECK_PAST
	var stone: ShaderMaterial = RuinKit.materials().stone
	stone = stone.duplicate() as ShaderMaterial
	stone.shader = STONE_SHADER
	stone.set_shader_parameter("rim",0.05)
	stone.set_shader_parameter("rail_fill",0.75)
	stone.set_shader_parameter("stone_knee",0.4)
	stone.set_shader_parameter("stone_cap",0.62)
	stone.set_shader_parameter("roughness_value",0.8)
	stone.set_shader_parameter("stone_tile_bump",1.5)
	stone.set_shader_parameter("stone_tile_tone",0.55)
	stone.set_shader_parameter("stone_tile_mortar",0.6)
	var wood := stone.duplicate() as ShaderMaterial
	wood.shader = TIMBER_SHADER
	wood.set_shader_parameter("stone_weather",0.0)
	wood.set_shader_parameter("grit",0.9)
	wood.set_shader_parameter("grit_scale",0.7)
	wood.set_shader_parameter("grit_grade",0.15)
	wood.set_shader_parameter("roughness_value",0.8)
	wood.set_shader_parameter("grain",1.6)
	wood.set_shader_parameter("rail_fill",0.6)
	wood.set_shader_parameter("stone_knee",0.3)
	wood.set_shader_parameter("stone_cap",0.44)
	_mats = [stone,wood,RailStops.paint()]
	for sp: Array in line.spans():
		_s0.append(float(sp[0]))
		_s1.append(float(sp[1]))
	for k in _s0.size():
		_choose(k)
		_grid(k)
		_abut_foot.append(Vector2(_abut_bottom(_s0[k]),_abut_bottom(_s1[k])))
		match _kind[k]:
			TRESTLE: _plan_trestle(k)
			ARCH: _plan_arches(k,false)
			VIADUCT: _plan_arches(k,true)
		kinds[_kind[k]] += 1
	plan_ms = (Time.get_ticks_usec()-t0)/1000.0
	_build_all()
	build_ms = (Time.get_ticks_usec()-t0)/1000.0

## Each frame: colliders near the plane, freed far from it.
func step(_eye: Vector3, plane_at: Vector3) -> void:
	for i in _pc.size():
		var d := plane_at.distance_to(_pc[i])-_pr[i]
		if _body[i] == null:
			if d < COLLIDE: _collide(i)
		elif d > COLLIDE*FREE_AT:
			_body[i].queue_free()
			_body[i] = null

## Span k's kind (KIND_NAMES).
func kind_of(k: int) -> String:
	return KIND_NAMES[_kind[k]]

## The span holding s, or -1.
func span_at(s: float) -> int:
	for k in _s0.size():
		if s >= _s0[k] and s <= _s1[k]: return k
	return -1

# --- The land under it ------------------------------------------------------------

## The water's level at (x, z): a river's, the sea's where the land is under
## it, else NAN.
func _water(x: float, z: float) -> float:
	var ry: float = field.river_y(x,z)
	if not is_nan(ry): return ry
	return SEA_Y if float(field.height(x,z)) < SEA_Y else NAN

## The ground or the water's top at (x, z), whichever is higher.
func _base(x: float, z: float) -> float:
	var g: float = field.height(x,z)
	var w := _water(x,z)
	return g if is_nan(w) else maxf(g,w)

## The ground's lowest and highest under a square of half side `h` at p.
func _ground_box(p: Vector3, fa: Vector3, fb: Vector3, h: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for e: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2.ZERO]:
		var q := p+fa*(e.x*h)+fb*(e.y*h)
		var g: float = field.height(q.x,q.z)
		lo = minf(lo,g)
		hi = maxf(hi,g)
	return Vector2(lo,hi)

## The ground's lowest and highest under a stretch d0..d1 across and a0..a1
## along frame fr.
func _ground_under(fr: Fr, d0: float, d1: float, a0: float, a1: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var nd := maxi(2,ceili((d1-d0)/3.0))
	for i in nd+1:
		for j in 3:
			var q := fr.at(lerpf(d0,d1,float(i)/nd),0.0,lerpf(a0,a1,j*0.5))
			var g: float = field.height(q.x,q.z)
			lo = minf(lo,g)
			hi = maxf(hi,g)
	return Vector2(lo,hi)

func _fr(s: float) -> Fr:
	var q := Fr.new()
	q.s = s
	q.c = line.centre(s)
	var t: Vector3 = line.tangent(s)
	q.f = Vector3(t.x,0.0,t.z).normalized()
	q.r = q.f.cross(Vector3.UP).normalized()
	return q

## The deck's top (the sleepers' foot) and underside at s.
func _deck_top(s: float) -> float:
	return float(line.bed(s))+_top_up

func _deck_under(s: float) -> float:
	return _deck_top(s)-DECK_DEPTH

## Span k's kind, by the rule in the header, from its height over the ground
## or water and how much of it is over water.
func _choose(k: int) -> void:
	var wet := 0
	var n := 0
	var tall := 0.0
	var tall_wet := 0.0
	var s := _s0[k]
	while s <= _s1[k]:
		var c: Vector3 = line.centre(s)
		var h := _deck_top(s)-_base(c.x,c.z)
		tall = maxf(tall,h)
		if str(line.kind(s)) == "bridge":
			wet += 1
			tall_wet = maxf(tall_wet,h)
		n += 1
		s += FRAME
	_tall.append(tall)
	var over_water := float(wet) >= WET_SHARE*float(maxi(n,1))
	if tall >= TIMBER_MOST or (over_water and tall_wet >= VIADUCT_FROM): _kind.append(VIADUCT)
	elif over_water: _kind.append(ARCH)
	else: _kind.append(TRESTLE)

## An abutment's foot at a span's end: under the bed's spill cone at its
## front and corners (rail_bed.gd).
func _abut_bottom(s: float) -> float:
	return float(line.bed(s))-Vector2(ABUT_PAST*RailBed.FILL_SLOPE,ABUT_IN*RailBed.SPILL_SLOPE).length()-SINK

func _grid(k: int) -> void:
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	var s := _s0[k]-ABUT_BACK
	while true:
		var c: Vector3 = line.centre(s)
		lo = lo.min(Vector2(c.x,c.z))
		hi = hi.max(Vector2(c.x,c.z))
		if s >= _s1[k]+ABUT_BACK: break
		s = minf(s+FRAME*4.0,_s1[k]+ABUT_BACK)
	var grow := maxf(_half+ABUT_PAST,_tall[k]*BATTER+_deck_half+PED)+12.0
	for cz in range(floori((lo.y-grow)/CELL),floori((hi.y+grow)/CELL)+1):
		for cx in range(floori((lo.x-grow)/CELL),floori((hi.x+grow)/CELL)+1):
			var key := Vector2i(cx,cz)
			var l: PackedInt32Array = _cells.get(key,PackedInt32Array())
			l.append(k)
			_cells[key] = l

# --- Hulls -------------------------------------------------------------------------

## A hull between two rings of corners (each convex, in matching order), ring
## a on frame fa's cut and ring b on fb's (for its place in s and d).
func _hull(k: int, ra: PackedVector3Array, rb: PackedVector3Array, fa: Fr, fb: Fr, col: Color, mat: int, flags := 0) -> void:
	var n := ra.size()
	var id := _hn.size()
	_hv0.append(_hv.size())
	_hn.append(n)
	_hv.append_array(ra)
	_hv.append_array(rb)
	_hcol.append(_toned(col,mat,ra[0]))
	_hmat.append(mat)
	_hflag.append(flags)
	_hk.append(k)
	var cen := Vector3.ZERO
	for v: Vector3 in ra: cen += v
	for v: Vector3 in rb: cen += v
	cen /= float(2*n)
	# One plane a face, in the faces' order (`_face`), a degenerate face's
	# a zero normal (it bounds nothing).
	_hp0.append(_hp.size()/4)
	for fi in n+2:
		var nv := Vector3.ZERO
		var pc := Vector3.ZERO
		if fi < 2:
			var ring := ra if fi == 0 else rb
			nv = _newell(ring)
			for v: Vector3 in ring: pc += v
			pc /= float(n)
		else:
			var i := fi-2
			var j := (i+1)%n
			# A quad's normal across its diagonals (its mean plane's).
			nv = (rb[j]-ra[i]).cross(rb[i]-ra[j])
			pc = (ra[i]+ra[j]+rb[i]+rb[j])*0.25
		var o := 0.0
		if nv.length_squared() > 1e-10:
			nv = nv.normalized()
			o = nv.dot(pc)
			if nv.dot(cen) > o:
				nv = -nv
				o = -o
		else: nv = Vector3.ZERO
		_hp.append_array([nv.x,nv.y,nv.z,o])
	_hpn.append(n+2)
	# Its place: s and d on its frames, the XZ box.
	var s_lo := INF
	var s_hi := -INF
	var d_lo := INF
	var d_hi := -INF
	var x0 := INF
	var z0 := INF
	var x1 := -INF
	var z1 := -INF
	var y0 := INF
	var y1 := -INF
	for i in 2*n:
		var v: Vector3 = ra[i] if i < n else rb[i-n]
		var fr: Fr = fa if i < n else fb
		var o := v-fr.c
		var sv := fr.s+o.x*fr.f.x+o.z*fr.f.z
		var dv := o.x*fr.r.x+o.z*fr.r.z
		s_lo = minf(s_lo,sv)
		s_hi = maxf(s_hi,sv)
		d_lo = minf(d_lo,dv)
		d_hi = maxf(d_hi,dv)
		x0 = minf(x0,v.x)
		z0 = minf(z0,v.z)
		x1 = maxf(x1,v.x)
		z1 = maxf(z1,v.z)
		y0 = minf(y0,v.y)
		y1 = maxf(y1,v.y)
	_hbox.append_array([x0,z0,x1,z1,y0,y1])
	_hs.append((s_lo+s_hi)*0.5)
	for cs in range(floori((s_lo-HMARGIN)/HCELL),floori((s_hi+HMARGIN)/HCELL)+1):
		for cd in range(floori((d_lo-HMARGIN)/HCELL),floori((d_hi+HMARGIN)/HCELL)+1):
			var key := Vector2i(cs,cd)
			var l: PackedInt32Array = _hcells.get(key,PackedInt32Array())
			l.append(id)
			_hcells[key] = l

## A hull's face fi: ring a, ring b, then side i between them.
static func _face(ra: PackedVector3Array, rb: PackedVector3Array, fi: int) -> PackedVector3Array:
	var n := ra.size()
	if fi == 0: return ra
	if fi == 1: return rb
	var i := fi-2
	var j := (i+1)%n
	return PackedVector3Array([ra[i],ra[j],rb[j],rb[i]])

static func _newell(p: PackedVector3Array) -> Vector3:
	var nv := Vector3.ZERO
	for i in p.size():
		var a := p[i]
		var b := p[(i+1)%p.size()]
		nv += Vector3((a.y-b.y)*(a.z+b.z),(a.z-b.z)*(a.x+b.x),(a.x-b.x)*(a.y+b.y))
	return nv

## A beam from a to b, `w` wide across it toward `hint` x its axis and `h`
## deep the other way (a post: hint along the line, w across it; a level
## member: hint up, w the level way).
func _beam(k: int, a: Vector3, b: Vector3, w: float, h: float, hint: Vector3, fa: Fr, fb: Fr, col: Color, flags := 0) -> void:
	var ax := b-a
	if ax.length_squared() < 0.01: return
	var side := ax.cross(hint).normalized()*(w*0.5)
	var up := side.cross(ax).normalized()*(h*0.5)
	_hull(k,_ring4(a,side,up),_ring4(b,side,up),fa,fb,col,WOOD,flags)

static func _ring4(c: Vector3, x: Vector3, y: Vector3) -> PackedVector3Array:
	return PackedVector3Array([c-x-y,c+x-y,c+x+y,c-x+y])

## A level box on frame fr: d0..d1 across, a0..a1 along, y0..y1.
func _block(k: int, fr: Fr, d0: float, d1: float, a0: float, a1: float, y0: float, y1: float, col: Color, mat: int, flags := 0) -> void:
	if y1-y0 < 0.01: return
	var lo := PackedVector3Array([fr.at(d0,y0,a0),fr.at(d1,y0,a0),fr.at(d1,y0,a1),fr.at(d0,y0,a1)])
	var hi := PackedVector3Array([fr.at(d0,y1,a0),fr.at(d1,y1,a0),fr.at(d1,y1,a1),fr.at(d0,y1,a1)])
	_hull(k,lo,hi,fr,fr,col,mat,flags)

## The column of stone a vertical line at (x, z) meets in hull i grown by
## `pad`: Vector2(bottom, top), x > y if none. Its faces' planes moved out by
## the pad, held in its box grown by the pad (where two faces meet at a
## sharp edge, as an arch's slice by its springing, the planes alone would
## run on far past it).
func _hull_y(i: int, x: float, z: float, pad: float) -> Vector2:
	var lo := _hbox[i*6+4]-pad
	var hi := _hbox[i*6+5]+pad
	var at := _hp0[i]*4
	for q in _hpn[i]:
		var ny := _hp[at+1]
		var r := _hp[at+3]+pad-_hp[at]*x-_hp[at+2]*z
		at += 4
		if absf(ny) < 1e-6:
			if r < 0.0: return Vector2(1.0,0.0)
			continue
		if ny > 0.0: hi = minf(hi,r/ny)
		else: lo = maxf(lo,r/ny)
		if lo > hi: return Vector2(1.0,0.0)
	return Vector2(lo,hi)

# --- The trestle ---------------------------------------------------------------------

## Span k's bents (towers when it stands TOWER_FROM m or more), their
## members, and between them the towers' bracing and the open bays' girts.
func _plan_trestle(k: int) -> void:
	var s0 := _s0[k]
	var s1 := _s1[k]
	var span := s1-s0
	var towers := _tall[k] >= TOWER_FROM
	var at := PackedFloat32Array()
	var first := PackedByteArray()
	if towers:
		var pitch := TOWER_BAY+WorldScale.opening(TOY_OPEN)
		var n := maxi(1,roundi(span/pitch))
		var p := span/n
		for i in n:
			var mid := s0+p*(i+0.5)
			at.append(mid-TOWER_BAY*0.5)
			first.append(1)
			at.append(mid+TOWER_BAY*0.5)
			first.append(0)
	else:
		var n := maxi(1,roundi(span/(WorldScale.opening(TOY_PLAIN)+POST)))
		for i in n:
			at.append(s0+span*(i+0.5)/n)
			first.append(0)
	var bents: Array[Dictionary] = []
	for i in at.size():
		bents.append(_bent(k,at[i]))
	for i in range(bents.size()-1):
		if bents[i].is_empty() or bents[i+1].is_empty(): continue
		_bay(k,bents[i],bents[i+1],towers and first[i] == 1)

## A post's x across at height y (its top at the cap's underside `under`).
static func _post_x(post: Vector3, under: float, y: float) -> float:
	return post.x+post.y*(under-y)

## The bent at s: four posts (Vector3(x at the cap, lean, foot's top)) on
## pedestals or a wet pier, its cap, girts every TIER m down, sway braces in
## the outer bays. Returns {fr, under, posts, tiers} for the bays beside it,
## or {} where the deck is too near the ground for one.
func _bent(k: int, s: float) -> Dictionary:
	var fr := _fr(s)
	var top := _deck_under(s)
	var under := top-CAP_D
	var c := fr.at(0.0,0.0)
	var mid_ground: float = field.height(c.x,c.z)
	if top-mid_ground < 0.6: return {}
	supports += 1
	var xi := WorldScale.opening(TOY_BAY)*0.5+POST*0.5
	var xo := _deck_half-OUTER_IN
	var xs := [-xo,-xi,xi,xo]
	var leans := [-BATTER,0.0,0.0,BATTER]
	# The water under it: a stone pier to WET_UP over it.
	var wet := -INF
	for d: float in [-xo,0.0,xo]:
		var q := fr.at(d,0.0)
		var w := _water(q.x,q.z)
		if not is_nan(w): wet = maxf(wet,w)
	var pier_top := wet+WET_UP if wet > -INF else -INF
	if pier_top > under-1.5: pier_top = -INF
	var posts: Array[Vector3] = []
	var ground_lo := INF
	for i in 4:
		var x: float = xs[i]
		var lean: float = leans[i]
		var foot := under-6.0
		var g := Vector2.ZERO
		for _pass in 3:
			var xf := x+lean*(under-foot)
			g = _ground_box(fr.at(xf,0.0),fr.r,fr.f,PED*0.5)
			foot = maxf(g.y+PED_UP,pier_top+0.4 if pier_top > -INF else -INF)
			foot = minf(foot,under)
		ground_lo = minf(ground_lo,g.x)
		posts.append(Vector3(x,lean,foot))
		if pier_top == -INF:
			# The pedestal: stone from under the ground to the foot.
			var xf := x+lean*(under-foot)
			_block(k,fr,xf-PED*0.5,xf+PED*0.5,-PED*0.5,PED*0.5,g.x-SINK,foot,STONE_C,STONE,HIDE_A)
	if pier_top > -INF:
		# The wet pier under the whole bent, its sill on top.
		var wx := absf(_post_x(posts[0],under,pier_top))+WET_PAST
		_pier(k,fr,ground_lo-SINK,pier_top,wx,WET_ALONG,WET_NOSE,0.04,0.02,wet,-1.0,-1.0)
		_beam(k,fr.at(-wx+0.4,pier_top+0.2),fr.at(wx-0.4,pier_top+0.2),CAP_ALONG,0.4,Vector3.UP,fr,fr,TIMBER_DARK)
	# The cap.
	var cx := xo+CAP_PAST+POST*0.5
	_beam(k,fr.at(-cx,under+CAP_D*0.5),fr.at(cx,under+CAP_D*0.5),CAP_ALONG,CAP_D,Vector3.UP,fr,fr,TIMBER_DARK)
	# The posts.
	for i in 4:
		var p := posts[i]
		if under-p.z < 0.3: continue
		var a := fr.at(_post_x(p,under,p.z-0.15),p.z-0.15)
		var b := fr.at(_post_x(p,under,under+0.2),under+0.2)
		_beam(k,a,b,POST,POST,fr.f,fr,fr,_jitter(TIMBER_C,s*7.0+i))
	# Girts on both faces at every tier, bay by bay where both posts stand
	# under it; sway braces in the outer bays, one diagonal on each face.
	var tiers := PackedFloat32Array()
	var tier := WorldScale.opening(TOY_BAY)+2.0
	var face := POST*0.5+GIRT_T*0.5
	var bf := POST*0.5+BRACE_T*0.5
	var lowest := INF
	for bay in 3: lowest = minf(lowest,maxf(posts[bay].z,posts[bay+1].z))
	var j := 1
	while j < 40:
		var y := under-tier*j
		var y_top := under if j == 1 else under-tier*(j-1)-GIRT_D
		if y_top < lowest+2.5: break
		var any := false
		for bay in 3:
			var pa := posts[bay]
			var pb := posts[bay+1]
			var floor_y := maxf(pa.z,pb.z)
			if y-GIRT_D > floor_y+0.6:
				any = true
				var yc := y-GIRT_D*0.5
				var xa := _post_x(pa,under,yc)-POST*0.5-GIRT_PAST
				var xb := _post_x(pb,under,yc)+POST*0.5+GIRT_PAST
				for side: float in [-1.0,1.0]:
					_beam(k,fr.at(xa,yc,side*face),fr.at(xb,yc,side*face),GIRT_T,GIRT_D,Vector3.UP,fr,fr,TIMBER_C)
			if bay == 1: continue
			var yb := maxf(y,floor_y+0.4)
			if y_top-yb < 2.5: continue
			var inner := pb if bay == 0 else pa
			var outer := pa if bay == 0 else pb
			_beam(k,fr.at(_post_x(inner,under,y_top),y_top,bf),fr.at(_post_x(outer,under,yb),yb,bf),BRACE_W,BRACE_T,fr.f,fr,fr,TIMBER_C)
			_beam(k,fr.at(_post_x(outer,under,y_top),y_top,-bf),fr.at(_post_x(inner,under,yb),yb,-bf),BRACE_W,BRACE_T,fr.f,fr,fr,TIMBER_C)
		if not any: break
		tiers.append(y)
		j += 1
	return {"fr":fr,"under":under,"posts":posts,"tiers":tiers}

## Between two neighbouring bents: girts along every row of posts under
## each tier's (on the row's outer side, so the corridor keeps its width)
## and, in a tower, a cross of braces in each row's plane per tier.
func _bay(k: int, a: Dictionary, b: Dictionary, tower: bool) -> void:
	var fa: Fr = a.fr
	var fb: Fr = b.fr
	var ua: float = a.under
	var ub: float = b.under
	var pa: Array[Vector3] = a.posts
	var pb: Array[Vector3] = b.posts
	var ta: PackedFloat32Array = a.tiers
	var tb: PackedFloat32Array = b.tiers
	var n := mini(ta.size(),tb.size())
	var out := POST*0.5+GIRT_T*0.5
	var off := out+GIRT_T*0.5+BRACE_T*0.5
	var hint := (fa.r+fb.r).normalized()
	for row in 4:
		var sgn := -1.0 if row < 2 else 1.0
		var foot_a := pa[row].z
		var foot_b := pb[row].z
		for t in n:
			var ya := ta[t]-GIRT_D*1.5
			var yb := tb[t]-GIRT_D*1.5
			if ya < foot_a+0.5 or yb < foot_b+0.5: continue
			_beam(k,fa.at(_post_x(pa[row],ua,ya)+sgn*out,ya,-POST*0.5),fb.at(_post_x(pb[row],ub,yb)+sgn*out,yb,POST*0.5),GIRT_T,GIRT_D,Vector3.UP,fa,fb,TIMBER_C)
		if not tower: continue
		for t in n+1:
			var top_a := ua if t == 0 else ta[t-1]-GIRT_D*2.0
			var top_b := ub if t == 0 else tb[t-1]-GIRT_D*2.0
			var bot_a := maxf(ta[t]-GIRT_D if t < n else foot_a,foot_a)+0.3
			var bot_b := maxf(tb[t]-GIRT_D if t < n else foot_b,foot_b)+0.3
			if top_a-bot_a < 2.5 or top_b-bot_b < 2.5: continue
			var p0 := fa.at(_post_x(pa[row],ua,top_a)+sgn*off,top_a)
			var p1 := fb.at(_post_x(pb[row],ub,bot_b)+sgn*off,bot_b)
			var p2 := fa.at(_post_x(pa[row],ua,bot_a)+sgn*(off+BRACE_T),bot_a)
			var p3 := fb.at(_post_x(pb[row],ub,top_b)+sgn*(off+BRACE_T),top_b)
			_beam(k,p0,p1,BRACE_W,BRACE_T,hint,fa,fb,TIMBER_C)
			_beam(k,p2,p3,BRACE_W,BRACE_T,hint,fa,fb,TIMBER_C)

# --- Stone -----------------------------------------------------------------------------

## A pier on frame fr from y0 to y1: across half `w` and along half `a` at
## its top, battered `bw` across and `ba` along per m down, with cutwaters
## `nose` m past its sides (0: none). With `pass_w` > 0 a passage that wide
## runs through it along the line from `pass_lo` to `pass_hi` (its head a
## half round). Under the water's `wet` + DAMP_UP its stone is darker.
func _pier(k: int, fr: Fr, y0: float, y1: float, w: float, a: float, nose: float, bw: float, ba: float, wet: float, pass_lo: float, pass_hi: float, pass_w := 0.0) -> void:
	var cuts := PackedFloat32Array([y0,y1])
	pass_lo = maxf(pass_lo,y0)
	var damp := wet+DAMP_UP if wet > -INF else -INF
	if damp > y0+0.5 and damp < y1-0.5: cuts.append(damp)
	var has_pass := pass_w > 0.0 and pass_hi-pass_lo > pass_w*0.5 and pass_lo >= y0-0.01 and pass_hi < y1
	var pass_spring := pass_hi-pass_w*0.5
	if has_pass:
		for v: float in [pass_lo,pass_spring,pass_hi]: cuts.append(v)
	cuts.sort()
	for i in range(cuts.size()-1):
		var ya := cuts[i]
		var yb := cuts[i+1]
		if yb-ya < 0.05: continue
		var col := STONE_DAMP if yb <= damp+0.01 else STONE_C
		var in_pass := has_pass and ya >= pass_lo-0.01 and yb <= pass_hi+0.01
		# Faces between bands are inside the stone, but for a passage's sill.
		var under_pass := has_pass and absf(yb-pass_lo) < 0.01
		var flags := HIDE_A | (HIDE_B if i < cuts.size()-2 and not under_pass else 0)
		if not in_pass:
			_hull(k,_pier_ring(fr,ya,y1,w,a,nose,bw,ba,-INF,INF),_pier_ring(fr,yb,y1,w,a,nose,bw,ba,-INF,INF),fr,fr,col,STONE,flags)
			continue
		# The passage's walls either side.
		var hw := pass_w*0.5
		_hull(k,_pier_ring(fr,ya,y1,w,a,nose,bw,ba,-INF,-hw),_pier_ring(fr,yb,y1,w,a,nose,bw,ba,-INF,-hw),fr,fr,col,STONE,flags)
		_hull(k,_pier_ring(fr,ya,y1,w,a,nose,bw,ba,hw,INF),_pier_ring(fr,yb,y1,w,a,nose,bw,ba,hw,INF),fr,fr,col,STONE,flags)
		if ya < pass_spring-0.01: continue
		# The head: slices across from its half round up to its top.
		var m := 8
		for q in m:
			var d0 := -hw+pass_w*q/m
			var d1 := -hw+pass_w*(q+1)/m
			var ra := _head_ring(fr,d0,hw,pass_spring,yb,y1,a,ba)
			var rb := _head_ring(fr,d1,hw,pass_spring,yb,y1,a,ba)
			_hull(k,ra,rb,fr,fr,col,STONE,HIDE_A|HIDE_B|(SIDE << 2))

## The pier's level section at y (its top at `top`) between d_lo and d_hi:
## a hexagon (the cutwaters' points at either end across) or its part.
func _pier_ring(fr: Fr, y: float, top: float, w0: float, a0: float, nose: float, bw: float, ba: float, d_lo: float, d_hi: float) -> PackedVector3Array:
	var down := top-y
	var w := w0+bw*down
	var a := a0+ba*down
	var nz := a if nose > 0.0 else 0.0
	nz = minf(nz,nose)
	var out := PackedVector3Array()
	# Round from the right point, anticlockwise seen from above (d, a).
	var pts: Array[Vector2] = []
	if d_hi == INF:
		if nz > 0.0: pts.append(Vector2(w+nz,0.0))
		pts.append(Vector2(w,a))
	else: pts.append(Vector2(d_hi,a))
	if d_lo == -INF:
		pts.append(Vector2(-w,a))
		if nz > 0.0: pts.append(Vector2(-w-nz,0.0))
		pts.append(Vector2(-w,-a))
	else:
		pts.append(Vector2(d_lo,a))
		pts.append(Vector2(d_lo,-a))
	if d_hi == INF: pts.append(Vector2(w,-a))
	else: pts.append(Vector2(d_hi,-a))
	for p: Vector2 in pts: out.append(fr.at(p.x,y,p.y))
	return out

## A slice of a passage's head at d: from its half round (radius hw, springing
## at `spring`) up to `yt`, the pier's thickness along there.
func _head_ring(fr: Fr, d: float, hw: float, spring: float, yt: float, top: float, a0: float, ba: float) -> PackedVector3Array:
	var y := spring+sqrt(maxf(hw*hw-d*d,0.0))
	var a_lo := a0+ba*(top-y)
	var a_hi := a0+ba*(top-yt)
	return PackedVector3Array([fr.at(d,y,-a_lo),fr.at(d,y,a_lo),fr.at(d,yt,a_hi),fr.at(d,yt,-a_hi)])

## Span k's arches: an arch bridge's (`tall` false) or a viaduct's bays,
## piers, galleries and arcades. Each bay's arch springs from its piers'
## faces; a pier stands to the lower of its two bays' springings.
func _plan_arches(k: int, tall: bool) -> void:
	var a0 := _s0[k]+ABUT_IN
	var a1 := _s1[k]-ABUT_IN
	var span := a1-a0
	var t := VIA_T if tall else PIER_T
	var want := clampf(_tall[k]*VIA_PITCH,VIA_PITCH_MIN,VIA_PITCH_MAX) if tall else ARCH_WANT+PIER_T
	var n := maxi(1,roundi((span+t)/want))
	var p := (span+t)/n
	var wb := _deck_half-SPANDREL_IN
	var pass_w := WorldScale.opening(TOY_BAY)
	var pass_h := WorldScale.opening(TOY_PASS)
	var bays: Array[Dictionary] = []
	for i in n:
		bays.append(_bay_plan(a0+p*i,a0+p*(i+1)-t if i < n-1 else a1,tall))
	var piers: Array[Dictionary] = []
	for i in range(1,n):
		var sp := a0+p*i-t*0.5
		var fr := _fr(sp)
		var c := fr.at(0.0,0.0)
		var g := _ground_box(c,fr.r,fr.f,t*0.5)
		var w := _water(c.x,c.z)
		g.x = _ground_under(fr,-wb-t*0.5,wb+t*0.5,-t*0.5,t*0.5).x
		var base := maxf(g.y,w) if not is_nan(w) else g.y
		var top := INF
		for b: Dictionary in [bays[i-1],bays[i]]:
			if b.arch: top = minf(top,float(b.spring))
		if top == INF: top = _deck_under(sp)
		var pr := {"fr":fr,"lo":g.x,"base":base,"wet":w if not is_nan(w) else -INF,"top":top}
		piers.append(pr)
		supports += 1
		_arch_pier(k,pr,tall,wb,t,pass_w,pass_h)
	for i in n:
		_bay_arches(k,bays[i],piers[i-1] if i > 0 else {},piers[i] if i < n-1 else {},tall,wb,pass_h)

## A bay from sa to sb (its piers' faces): its base (the ground or water's
## highest under it), crown, springing, and whether an arch fits.
func _bay_plan(sa: float, sb: float, tall: bool) -> Dictionary:
	var mid := (sa+sb)*0.5
	var base := -INF
	var ground_lo := INF
	var wb := _deck_half-SPANDREL_IN
	for s: float in [sa,mid,sb]:
		var fr := _fr(s)
		base = maxf(base,_base(fr.c.x,fr.c.z))
		ground_lo = minf(ground_lo,_ground_under(fr,-wb,wb,-0.5,0.5).x)
	var crown := _deck_under(mid)-(VIA_RING if tall else RING)
	# A viaduct's arches spring clear of the water; a low bridge's are round
	# and may spring under the bank, as a bank built up against them.
	var spring := crown-(sb-sa)*0.5
	if tall: spring = maxf(spring,base+SPRING_UP)
	return {"sa":sa,"sb":sb,"base":base,"lo":ground_lo,"crown":crown,"spring":spring,"arch":crown-base >= 1.2 and crown-spring >= 1.0 and sb-sa >= 2.0}

## A pier: an arch bridge's cutwater pier to its top and the spandrel over
## it; a viaduct's battered pier with its galleries, its cutwaters rising
## over the springing to the string course as pilasters.
func _arch_pier(k: int, pr: Dictionary, tall: bool, wb: float, t: float, pass_w: float, pass_h: float) -> void:
	var fr: Fr = pr.fr
	var top: float = pr.top
	var y0: float = float(pr.lo)-SINK
	var wet: float = pr.wet
	var head := _deck_under(fr.s)
	if not tall:
		if top > y0+SINK: _pier(k,fr,y0,top,wb,t*0.5,t*0.5,0.03,0.0,wet,-1.0,-1.0)
		_block(k,fr,-wb,wb,-t*0.5,t*0.5,maxf(top,y0),head,STONE_C,STONE,HIDE_A)
		return
	_pier(k,fr,top,head,wb,t*0.5,t*0.5,0.0,0.0,-INF,-1.0,-1.0)
	var cut := top
	for g: Vector2 in _galleries(top,float(pr.base),pass_h):
		_via_seg(k,fr,g.x,cut,top,wb,t*0.5,wet,g.x,g.y,pass_w)
		cut = g.x
	_via_seg(k,fr,y0,cut,top,wb,t*0.5,wet,-1.0,-1.0,0.0)

## A viaduct pier's stretch y0..y1, battered from its springing `spring`
## (wb across, a along there), with a gallery from pass_lo to pass_hi.
func _via_seg(k: int, fr: Fr, y0: float, y1: float, spring: float, wb: float, a: float, wet: float, pass_lo: float, pass_hi: float, pass_w: float) -> void:
	if y1-y0 < 0.05: return
	var w1 := wb+VIA_BATTER_W*(spring-y1)
	var a1 := a+VIA_BATTER_A*(spring-y1)
	# The cutwaters' points square (as long as the pier is thick there), so
	# their faces stay planes as it widens down.
	_pier(k,fr,y0,y1,w1,a1,INF,VIA_BATTER_W,VIA_BATTER_A,wet,pass_lo,pass_hi,pass_w)

## A viaduct pier's galleries from the top down: Vector2(sill, head) each,
## the first PASS_HEAD under the springing, each next under the arcade below
## the one before (BAND deep over its half round), while the sill stands
## PASS_FLOOR over the ground or water.
func _galleries(spring: float, base: float, pass_h: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var head := spring-PASS_HEAD
	for _i in 6:
		var sill := head-pass_h
		if sill < base+PASS_FLOOR: break
		out.append(Vector2(sill,head))
		head = sill-BAND-PASS_HEAD
	return out

## A bay's arch under the deck (or a wall where none fits) and, in a
## viaduct, an arcade under each gallery's sill, its top the gallery's floor.
func _bay_arches(k: int, bay: Dictionary, pa: Dictionary, pb: Dictionary, tall: bool, wb: float, pass_h: float) -> void:
	var sa: float = bay.sa
	var sb: float = bay.sb
	if not bay.arch:
		_wall(k,sa,sb,float(bay.lo)-SINK,wb)
		return
	_arch(k,sa,sb,float(bay.spring),float(bay.crown),INF,wb,VIA_RING if tall else RING,STONE_C)
	# Arcades only between two piers.
	if not tall or pa.is_empty() or pb.is_empty(): return
	var p_top := 0.0
	var n := 0
	for pr: Dictionary in [pa,pb]:
		if pr.is_empty(): continue
		p_top += float(pr.top)
		n += 1
	p_top /= n
	var base: float = bay.base
	for g: Vector2 in _galleries(p_top,base,pass_h):
		var top := g.x
		var a_crown := top-BAND
		# The piers are thicker down there: the arcade spans between them.
		var grow := VIA_BATTER_A*(p_top-a_crown)
		var aa := sa+(grow if not pa.is_empty() else 0.0)
		var ab := sb-(grow if not pb.is_empty() else 0.0)
		var a_spring := maxf(a_crown-(ab-aa)*0.5,base+SPRING_UP)
		# Only over a fair opening (TOY_BAY) to fly under it.
		if a_crown-base < WorldScale.opening(TOY_BAY) or a_crown-a_spring < 1.5: break
		# Its faces plumb, flush with the piers' at its top, its ends into
		# them so its top meets their galleries' sills.
		var aw := wb+VIA_BATTER_W*(p_top-top)
		_arch(k,aa-0.6,ab+0.6,a_spring,a_crown,top,aw,BAND*0.6,STONE_C)

## A wall from sa to sb, its foot at y0, to the deck's underside.
func _wall(k: int, sa: float, sb: float, y0: float, wb: float) -> void:
	var m := maxi(1,ceili((sb-sa)/FRAME))
	for q in m:
		var s0 := lerpf(sa,sb,float(q)/m)
		var s1 := lerpf(sa,sb,float(q+1)/m)
		var f0 := _fr(s0)
		var f1 := _fr(s1)
		var ra := PackedVector3Array([f0.at(-wb,y0),f0.at(wb,y0),f0.at(wb,_deck_under(s0)),f0.at(-wb,_deck_under(s0))])
		var rb := PackedVector3Array([f1.at(-wb,y0),f1.at(wb,y0),f1.at(wb,_deck_under(s1)),f1.at(-wb,_deck_under(s1))])
		_hull(k,ra,rb,f0,f1,STONE_C,STONE,HIDE_A|HIDE_B|(SIDE << 2))

## An arch from sa to sb along the line: its soffit a circle's segment
## through the springing at both ends and the crown, the spandrels filled
## from the soffit up to `top` (INF: the deck's underside), `half` m each side
## of the line at its top (wider by `batter` a m down); its ring `ring`
## deep, the ring's bands proud of each face.
func _arch(k: int, sa: float, sb: float, spring: float, crown: float, top: float, half: float, ring: float, col: Color, batter := 0.0) -> void:
	var c := (sb-sa)*0.5
	var rise := crown-spring
	var r := (c*c+rise*rise)/(2.0*rise)
	var cy := crown-r
	var m := clampi(ceili((sb-sa)/1.8),6,24)
	var prev: Fr = null
	var prev_y := 0.0
	var prev_o := 0.0
	var prev_t := 0.0
	for q in m+1:
		var s := lerpf(sa,sb,float(q)/m)
		var x := s-(sa+sb)*0.5
		var fr := _fr(s)
		var y := cy+sqrt(maxf(r*r-x*x,0.0))
		var yo := cy+sqrt(maxf((r+ring)*(r+ring)-x*x,0.0))
		var yt := _deck_under(s) if top == INF else top
		yo = minf(yo,yt)
		if prev != null:
			var hp := half+batter*(prev_t-prev_y)
			var hy := half+batter*(yt-y)
			var hpt := half
			var ra := PackedVector3Array([prev.at(-hp,prev_y),prev.at(hp,prev_y),prev.at(hpt,prev_t),prev.at(-hpt,prev_t)])
			var rb := PackedVector3Array([fr.at(-hy,y),fr.at(hy,y),fr.at(hpt,yt),fr.at(-hpt,yt)])
			# Its top hidden under the deck; an arcade's is a gallery's floor.
			_hull(k,ra,rb,prev,fr,Color(col.darkened(0.06),0.55),STONE,HIDE_A|HIDE_B|((SIDE << 2) if top == INF else 0))
			# The ring's bands, proud of each face.
			for sd: float in [-1.0,1.0]:
				var ba := PackedVector3Array([prev.at(sd*hp,prev_y),prev.at(sd*(hp+BAND_OUT),prev_y),prev.at(sd*(half+batter*(prev_t-prev_o)+BAND_OUT),prev_o),prev.at(sd*(half+batter*(prev_t-prev_o)),prev_o)])
				var bb := PackedVector3Array([fr.at(sd*hy,y),fr.at(sd*(hy+BAND_OUT),y),fr.at(sd*(half+batter*(yt-yo)+BAND_OUT),yo),fr.at(sd*(half+batter*(yt-yo)),yo)])
				_hull(k,ba,bb,prev,fr,STONE_LIGHT,STONE,HIDE_A|HIDE_B|NEAR_ONLY)
		prev = fr
		prev_y = y
		prev_o = yo
		prev_t = yt

# --- Building ------------------------------------------------------------------------

## Every span's pieces: the deck, its edges, the hulls and the abutments,
## PIECE m of s each.
func _build_all() -> void:
	var by_piece := {}
	var piece_of := PackedInt32Array()
	var starts: Array = []
	for k in _s0.size():
		var a := _s0[k]-ABUT_BACK
		var b := _s1[k]+ABUT_BACK
		var n := maxi(ceili((b-a)/PIECE),1)
		var first := starts.size()
		for q in n:
			starts.append([k,lerpf(a,b,float(q)/n),lerpf(a,b,float(q+1)/n),q == 0,q == n-1])
		piece_of.append(first)
	for h in _hn.size():
		var k := _hk[h]
		var first := piece_of[k]
		var a := _s0[k]-ABUT_BACK
		var b := _s1[k]+ABUT_BACK
		var n := maxi(ceili((b-a)/PIECE),1)
		var q := clampi(floori((_hs[h]-a)/(b-a)*n),0,n-1)
		var key := first+q
		var l: PackedInt32Array = by_piece.get(key,PackedInt32Array())
		l.append(h)
		by_piece[key] = l
	for i in starts.size():
		var st: Array = starts[i]
		_build_piece(int(st[0]),float(st[1]),float(st[2]),bool(st[3]),bool(st[4]),by_piece.get(i,PackedInt32Array()))

## Span k's stretch a..b of s: the deck's frames in it, its hulls, an
## abutment at the span's start or end if it holds one.
func _build_piece(k: int, a: float, b: float, first: bool, last: bool, hulls: PackedInt32Array) -> void:
	var o: Vector3 = line.centre((a+b)*0.5)
	var near: Array[_M] = [_M.new(o),_M.new(o),_M.new(o)]
	var far: Array[_M] = [_M.new(o),_M.new(o),_M.new(o)]
	# The deck, from the span's start to its end.
	var d0 := maxf(a,_s0[k])
	var d1 := minf(b,_s1[k])
	if d1 > d0:
		var steps := maxi(ceili((d1-d0)/FRAME),1)
		var prev := {}
		for q in steps+1:
			var f := _frame(lerpf(d0,d1,float(q)/steps))
			if not prev.is_empty():
				_deck(near,prev,f,_kind[k],q-1)
				_deck(far,prev,f,_kind[k],-1)
			prev = f
	for h in hulls:
		_draw_hull(near,h)
		if not _hflag[h] & NEAR_ONLY: _draw_hull(far,h)
	if first:
		for m: Array[_M] in [near,far]: _abutment(m[STONE],_s0[k],1.0,_abut_foot[k].x)
	if last:
		for m: Array[_M] in [near,far]: _abutment(m[STONE],_s1[k],-1.0,_abut_foot[k].y)
	var faces := PackedVector3Array()
	var mesh := ArrayMesh.new()
	var far_mesh := ArrayMesh.new()
	for mat in 3:
		near[mat].add_to(mesh,_mats[mat])
		far[mat].add_to(far_mesh,_mats[mat])
		faces.append_array(near[mat].v)
		far_tris += far[mat].v.size()/3
	if faces.is_empty(): return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = o
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.visibility_range_end = NEAR_END
	add_child(mi)
	var fi := MeshInstance3D.new()
	fi.mesh = far_mesh
	fi.position = o
	fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fi.visibility_range_begin = NEAR_END
	fi.visibility_range_end = VISIBLE
	add_child(fi)
	tris += faces.size()/3
	# Its bounds, for the collider's distance.
	var box := AABB(faces[0],Vector3.ZERO)
	for v: Vector3 in faces: box = box.expand(v)
	_pc.append(o+box.get_center())
	_po.append(o)
	_pr.append(box.size.length()*0.5)
	_faces.append(faces)
	_body.append(null)

## Hull h's drawn faces into its material's mesh.
func _draw_hull(m: Array[_M], h: int) -> void:
	var n := _hn[h]
	var v0 := _hv0[h]
	var ra := _hv.slice(v0,v0+n)
	var rb := _hv.slice(v0+n,v0+2*n)
	var flags := _hflag[h]
	var col := _hcol[h]
	var ca := Vector3.ZERO
	var cb := Vector3.ZERO
	for q in n:
		ca += ra[q]
		cb += rb[q]
	var ax := (cb-ca)
	ax = ax.normalized() if ax.length_squared() > 1e-6 else Vector3.UP
	var mm: _M = m[_hmat[h]]
	var at := _hp0[h]*4
	for fi in n+2:
		if fi == 0 and flags & HIDE_A: continue
		if fi == 1 and flags & HIDE_B: continue
		if fi >= 2 and flags & (SIDE << (fi-2)): continue
		var q := at+fi*4
		var nv := Vector3(_hp[q],_hp[q+1],_hp[q+2])
		if nv == Vector3.ZERO: continue
		var poly := _face(ra,rb,fi)
		var c := col
		if nv.y < -0.3: c.a = minf(c.a,lerpf(1.0,UNDER_SHELTER,clampf(-nv.y,0.0,1.0)))
		mm.poly(poly,nv,c,ax)

## The line's frame at s: the centre, its right (level), up and along.
func _frame(s: float) -> Dictionary:
	var fwd: Vector3 = line.tangent(s)
	var up := (Vector3.UP-fwd*fwd.y).normalized()
	return {"c":line.centre(s),"r":fwd.cross(up).normalized(),"u":up,"f":fwd,"s":s}

## The deck between two frames by its kind: a trestle's plank deck on
## stringers with a handrail, a stone deck with its string course and
## parapets. Frame `q` (-1 in the far mesh) sets where the handrail's posts
## stand.
func _deck(m: Array[_M], f0: Dictionary, f1: Dictionary, kind: int, q: int) -> void:
	var h := _deck_half
	var a: Vector3 = f0.c+f0.u*_top_up
	var b: Vector3 = f1.c+f1.u*_top_up
	var ra: Vector3 = f0.r
	var rb: Vector3 = f1.r
	var ua: Vector3 = f0.u
	var ub: Vector3 = f1.u
	var along: Vector3 = (b-a).normalized()
	var timber := kind == TRESTLE
	var top_m: _M = m[WOOD] if timber else m[PAINT]
	var side_m: _M = m[WOOD] if timber else m[STONE]
	var top_c := DECK_TOP_C if timber else Color(0.52,0.48,0.42)
	# The top in strips across: deck, a track's bed, between, the other's, deck.
	var g := float(line.track_gap())*0.5
	var w := RailTrack.SLEEPER_HALF+TRACK_STRIP
	var inner := h-PARAPET_T
	var cuts := [-inner,-g-w,-g+w,g-w,g+w,inner]
	for i in cuts.size()-1:
		var x0: float = cuts[i]
		var x1: float = cuts[i+1]
		if x1 <= x0: continue
		if i%2 == 0:
			top_m.quad(a+ra*x0,b+rb*x0,b+rb*x1,a+ra*x1,ua,top_c,along)
			continue
		var la: Vector3 = ua*TRACK_UP
		var lb: Vector3 = ub*TRACK_UP
		m[PAINT].quad(a+ra*x0+la,b+rb*x0+lb,b+rb*x1+lb,a+ra*x1+la,ua,TRACK_C,along)
		m[PAINT].quad(a+ra*x0,b+rb*x0,b+rb*x0+lb,a+ra*x0+la,-ra,TRACK_C,along)
		m[PAINT].quad(a+ra*x1,b+rb*x1,b+rb*x1+lb,a+ra*x1+la,ra,TRACK_C,along)
	var da: Vector3 = -ua*DECK_DEPTH
	var db: Vector3 = -ub*DECK_DEPTH
	if timber:
		# The planks' edge, their underside between the stringers, the stringers.
		var pa: Vector3 = -ua*PLANK_D
		var pb: Vector3 = -ub*PLANK_D
		for sd: float in [-1.0,1.0]:
			side_m.quad(a+ra*(h*sd),b+rb*(h*sd),b+rb*(h*sd)+pb,a+ra*(h*sd)+pa,ra*sd,TIMBER_DARK,along)
		side_m.quad(a-ra*h+pa,b-rb*h+pb,b+rb*h+pb,a+ra*h+pa,-ua,Color(TIMBER_DARK,UNDER_SHELTER),along)
		var xs := [-h+STRINGER_W*0.5+0.25,-g-1.1,-g+1.1,-STRINGER_W*1.2,STRINGER_W*1.2,g-1.1,g+1.1,h-STRINGER_W*0.5-0.25]
		for x: float in xs:
			var l0: Vector3 = a+ra*(x-STRINGER_W*0.5)+pa
			var l1: Vector3 = a+ra*(x+STRINGER_W*0.5)+pa
			var m0: Vector3 = b+rb*(x-STRINGER_W*0.5)+pb
			var m1: Vector3 = b+rb*(x+STRINGER_W*0.5)+pb
			var dd: Vector3 = -ua*(DECK_DEPTH-PLANK_D)
			var de: Vector3 = -ub*(DECK_DEPTH-PLANK_D)
			side_m.quad(l0,m0,m0+de,l0+dd,-ra,TIMBER_C,along)
			side_m.quad(l1,m1,m1+de,l1+dd,ra,TIMBER_C,along)
			side_m.quad(l0+dd,m0+de,m1+de,l1+dd,-ua,Color(TIMBER_C.darkened(0.15),UNDER_SHELTER),along)
		# The handrail: a curb, posts every other frame, a top and a mid rail.
		for sd: float in [-1.0,1.0]:
			var x0 := sd*(h-PARAPET_T)
			var x1 := sd*h
			_rail_box(side_m,a,b,ra,rb,ua,ub,x0,x1,0.0,0.35,TIMBER_DARK,along)
			_rail_box(side_m,a,b,ra,rb,ua,ub,x0+sd*0.15,x1-sd*0.15,PARAPET_H-0.22,PARAPET_H,TIMBER_C,along)
			if q >= 0: _rail_box(side_m,a,b,ra,rb,ua,ub,x0+sd*0.2,x1-sd*0.2,PARAPET_H*0.5-0.08,PARAPET_H*0.5+0.08,TIMBER_C,along)
			if q >= 0 and q%2 == 0:
				var c: Vector3 = a+ra*((x0+x1)*0.5)
				var post_c := c+ua*(PARAPET_H*0.5)
				side_m.box(post_c,ra*0.13,along*0.13,ua*(PARAPET_H*0.5),TIMBER_C)
		return
	# Stone: the deck's face as a string course, its underside, the parapets.
	for sd: float in [-1.0,1.0]:
		side_m.quad(a+ra*(h*sd),b+rb*(h*sd),b+rb*(h*sd)+db,a+ra*(h*sd)+da,ra*sd,STONE_LIGHT,along)
	side_m.quad(a-ra*h+da,b-rb*h+db,b+rb*h+db,a+ra*h+da,-ua,Color(STONE_C.darkened(0.2),UNDER_SHELTER),along)
	for sd: float in [-1.0,1.0]:
		var x0 := sd*(h-PARAPET_T)
		var x1 := sd*h
		_rail_box(side_m,a,b,ra,rb,ua,ub,x0,x1,0.0,PARAPET_H-0.2,STONE_C,along)
		_rail_box(side_m,a,b,ra,rb,ua,ub,x0-sd*0.08,x1+sd*0.1,PARAPET_H-0.2,PARAPET_H,STONE_LIGHT,along)

## A strip along the deck's edge from x0 to x1 across, y0 to y1 over its top.
func _rail_box(m: _M, a: Vector3, b: Vector3, ra: Vector3, rb: Vector3, ua: Vector3, ub: Vector3, x0: float, x1: float, y0: float, y1: float, col: Color, along: Vector3) -> void:
	var lo := minf(x0,x1)
	var hi := maxf(x0,x1)
	var p := [a+ra*lo+ua*y0,a+ra*hi+ua*y0,a+ra*hi+ua*y1,a+ra*lo+ua*y1]
	var q := [b+rb*lo+ub*y0,b+rb*hi+ub*y0,b+rb*hi+ub*y1,b+rb*lo+ub*y1]
	m.quad(p[3],q[3],q[2],p[2],ua,col,along)
	m.quad(p[0],q[0],q[3],p[3],-ra,col,along)
	m.quad(p[1],q[1],q[2],p[2],ra,col,along)
	m.quad(p[0],q[0],q[1],p[1],-ua,col,along)

## The abutment at a span's end s (`into` +1 at its start, -1 at its end):
## a block from ABUT_BACK under the bed to ABUT_IN into the span, its top at
## the bed's, its foot under the bank's spill, a coping on its face.
func _abutment(m: _M, s: float, into: float, foot: float) -> void:
	var f := _frame(s)
	var along: Vector3 = f.f*into
	var mid_s := s+into*(ABUT_IN-ABUT_BACK)*0.5
	var top: float = float(line.bed(s))-0.02
	var c: Vector3 = line.centre(mid_s)
	c.y = (top+foot)*0.5
	var flat := Vector3(along.x,0.0,along.z).normalized()
	var right := flat.cross(Vector3.UP).normalized()
	m.box(c,right*(_half+ABUT_PAST),flat*((ABUT_IN+ABUT_BACK)*0.5),Vector3.UP*((top-foot)*0.5),STONE_C)

## A colour a little off `c` by `seed` (each member its own tone).
static func _jitter(c: Color, seed_v: float) -> Color:
	var h := fposmod(sin(seed_v*12.9898)*43758.5453,1.0)
	return c.lightened((h-0.5)*0.12) if h > 0.5 else c.darkened((0.5-h)*0.16)

## A hull's drawn colour: each timber member its own tone (some greyer, some
## browner), each stone piece a little off its neighbours.
static func _toned(c: Color, mat: int, at: Vector3) -> Color:
	if mat == PAINT: return c
	var seed_v := at.x*0.731+at.y*1.377+at.z*0.519
	var h := fposmod(sin(seed_v*12.9898)*43758.5453,1.0)
	var h2 := fposmod(sin(seed_v*78.233+1.7)*24634.6345,1.0)
	if mat == WOOD:
		var t := c.lightened((h-0.5)*0.3) if h > 0.5 else c.darkened((0.5-h)*0.42)
		return t.lerp(Color(0.42,0.4,0.37,c.a),maxf(0.0,h2-0.72)*0.9)
	return c.lightened((h-0.5)*0.14) if h > 0.5 else c.darkened((0.5-h)*0.2)

func _collide(i: int) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_faces[i])
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.position = _po[i]
	_body[i] = body

# --- The flight -------------------------------------------------------------------

## The stretches of stone at `p` grown by `pad`, as Vector2(bottom, top),
## sorted and joined. The deck's and the abutments' tops grow by the pad
## only past their sides (`_up`; at their ends the bed carries on at their
## height): over them the plane rides them as land, so its wheels can touch
## down on the deck (wings level, the pad is the plane's reach sideways,
## not down). The parapets or handrails stand PARAPET_H over its edges.
func _stretches(p: Vector3, pad: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cell: Variant = _cells.get(Vector2i(floori(p.x/CELL),floori(p.z/CELL)))
	if cell == null: return out
	var q: Vector3 = _across.call(p.x,p.z)
	if is_nan(q.x): return out
	var s := q.x
	var d := q.y
	var bed := q.z
	var ad := absf(d)
	var any := false
	for k: int in cell:
		if s < _s0[k]-ABUT_BACK-pad-HMARGIN or s > _s1[k]+ABUT_BACK+pad+HMARGIN: continue
		any = true
		# The deck, its parapets.
		if s >= _s0[k]-pad and s <= _s1[k]+pad and ad <= _deck_half+pad:
			var top := bed+_top_up
			if ad >= _deck_half-PARAPET_T-pad: top += PARAPET_H+pad
			else: top += _up(ad-_deck_half,pad)
			out.append(Vector2(bed+_top_up-DECK_DEPTH-pad,top))
		# The abutments.
		var ah := _half+ABUT_PAST+pad
		if ad <= ah:
			var side := ad-_half-ABUT_PAST
			if s >= _s0[k]-ABUT_BACK-pad and s <= _s0[k]+ABUT_IN+pad: out.append(Vector2(_abut_foot[k].x,bed+_up(side,pad)))
			if s >= _s1[k]-ABUT_IN-pad and s <= _s1[k]+ABUT_BACK+pad: out.append(Vector2(_abut_foot[k].y,bed+_up(side,pad)))
	if not any: return out
	# The members near (s, d).
	var hl: Variant = _hcells.get(Vector2i(floori(s/HCELL),floori(d/HCELL)))
	if hl != null:
		for h: int in hl:
			var b := h*6
			if p.x < _hbox[b]-pad or p.z < _hbox[b+1]-pad or p.x > _hbox[b+2]+pad or p.z > _hbox[b+3]+pad: continue
			var y := _hull_y(h,p.x,p.z,pad)
			if y.x <= y.y: out.append(y)
	if out.size() < 2: return out
	out.sort()
	var joined: Array[Vector2] = [out[0]]
	for i in range(1,out.size()):
		var last := joined[joined.size()-1]
		if out[i].x <= last.y+0.05: joined[joined.size()-1] = Vector2(last.x,maxf(last.y,out[i].y))
		else: joined.append(out[i])
	return joined

## A top's growth `past` m beyond its edge (<= 0 over it): none over it,
## the pad's share past it.
static func _up(past: float, pad: float) -> float:
	return clampf(past,0.0,pad)

## SkyGlide's `ground` at `p` over `h` (as LandArches `ground`): a float
## (the land, raised by a member or an abutment, or the deck's top over it)
## or Vector2(top, underside) under a deck or a member. `h` passed back as it
## is if it isn't a height.
func ground(p: Vector3, h: Variant, pad := 0.0) -> Variant:
	if not h is float or _s0.is_empty(): return h
	var list := _stretches(p,maxf(pad,0.0))
	if list.is_empty(): return h
	var top: float = h
	var under := -INF
	for st: Vector2 in list:
		if st.x <= top+0.6:
			top = maxf(top,st.y)
			continue
		if p.y >= st.y:
			top = st.y
			under = st.x
			continue
		if p.y >= (top+st.x)*0.5: return Vector2(st.y,st.x)
		break
	return top if under == -INF else Vector2(top,under)

## In the stone or timber (the camera keeps out, the rolling plane is
## blocked).
func inside(p: Vector3) -> bool:
	if _s0.is_empty(): return false
	for st: Vector2 in _stretches(p,0.0):
		if p.y >= st.x and p.y <= st.y: return true
	return false

## The solid's top under `p` over the land's `h` (the wheels' and the eye's
## floor): the deck's top when over its middle height, a member's or an
## abutment's top.
func land_y(p: Vector3, h: float) -> float:
	if _s0.is_empty(): return h
	for st: Vector2 in _stretches(p,0.0):
		if p.y >= (st.x+st.y)*0.5 and st.y > h: h = st.y
	return h

## A line for a driver: what was built.
func note() -> String:
	return "%d spans (%d arch, %d trestle, %d viaduct), %d supports, %d members, %d pieces, %d tris (far %d), built in %.1f ms (planned in %.1f)" % [_s0.size(),kinds[ARCH],kinds[TRESTLE],kinds[VIADUCT],supports,_hn.size(),_pc.size(),tris,far_tris,build_ms,plan_ms]

## A mesh in the making about an origin: flat-shaded triangles with vertex
## colours and a UV along each face's grain (m), its corners relative to `o`.
class _M:
	var o := Vector3.ZERO
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()

	func _init(origin: Vector3) -> void:
		o = origin

	## A convex polygon facing `nn` (outward), its grain along `ax`.
	func poly(p: PackedVector3Array, nn: Vector3, col: Color, ax: Vector3) -> void:
		var t := nn.cross(ax)
		if t.length_squared() < 1e-4: t = nn.cross(Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT)
		t = t.normalized()
		var u := t.cross(nn).normalized()
		var a0 := p[0]-o
		for i in range(1,p.size()-1):
			var b := p[i]-o
			var cc := p[i+1]-o
			if (b-a0).cross(cc-a0).dot(nn) > 0.0:
				var tmp := b
				b = cc
				cc = tmp
			for q: Vector3 in [a0,b,cc]:
				v.append(q)
				n.append(nn)
				c.append(col)
				uv.append(Vector2(q.dot(u),q.dot(t)))

	## The quad a b c d (in order round it), facing `face`'s side.
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, face: Vector3, col: Color, ax: Vector3) -> void:
		var nn := (b-a).cross(cc-a)
		if nn.length_squared() < 1e-10: return
		nn = nn.normalized()
		if nn.dot(face) < 0.0: nn = -nn
		poly(PackedVector3Array([a,b,cc,d]),nn,col,ax)

	## A box at `cc` with half axes x, z (level) and y (up), no floor.
	func box(cc: Vector3, x: Vector3, z: Vector3, y: Vector3, col: Color) -> void:
		var top := cc+y
		var bot := cc-y
		quad(top-x-z,top+x-z,top+x+z,top-x+z,y,col,z)
		quad(bot-x-z,bot+x-z,top+x-z,top-x-z,-z,col,y)
		quad(bot-x+z,bot+x+z,top+x+z,top-x+z,z,col,y)
		quad(bot-x-z,bot-x+z,top-x+z,top-x-z,-x,col,y)
		quad(bot+x-z,bot+x+z,top+x+z,top+x-z,x,col,y)

	func add_to(mesh: ArrayMesh, mat: Material) -> void:
		if v.is_empty(): return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
