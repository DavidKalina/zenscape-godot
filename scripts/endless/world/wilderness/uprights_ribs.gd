extends RefCounted
## The wilderness's shipwreck: skin `ribs` of the uprights kind
## (scripts/endless/kinds/uprights.gd). A row of frames along a keel half
## sunk in the sand, each frame two curved wooden ribs standing either side
## of the kind's channel (its width TOY_CHANNEL, below), open at the top,
## a couple broken short on one side, the whole hull listing toward the sea
## (the row's left), a few strakes of its planking left low between the
## frames (under the flown gaps). Its bow broke away: the stem post stands in the
## shallows off the bow end, turned and leaning, with one stub frame.
## The stern end is open, so the channel is flown end to end.
##
## Each rib keeps inside its slot's width along the row (RIB_T at most), so
## the gaps between frames stay at least their openings; each rib's inner
## face stays outside the channel's half width (MARGIN) at every height, so
## the channel is at least its opening.

const UprightsPath := "res://scripts/endless/kinds/uprights.gd"

## The channel's toy width between the two sides (WorldScale `opening`:
## 7 m at the defaults, between the ribs' tips, which curl in; the belly
## about 9.6 m): a hull to fly along, its middle a wingtip's near miss
## (near_miss.gd STONE_REACH) from each side.
const TOY_CHANNEL := 3.5
## Each rib's inner face this far outside the channel's half width (m).
const MARGIN := 0.25
## A rib's thickness along the row (m, at most its slot's width), its root
## buried under the sand (m), the spacing of its curve's rings (m).
const RIB_T := 1.0
const BURY := 2.0
const STEP := 0.7
## A rib's middle line, out from the keel's line (shares of its widest) and
## up (shares of its height): rising out of the sand, the bilge's turn, the
## widest, curving in to its tip. The tip is the narrowest (TIP_IN).
const RIB := [Vector2(0.55,0.0),Vector2(0.84,0.12),Vector2(1.0,0.38),Vector2(0.99,0.6),Vector2(0.92,0.82),Vector2(0.8,1.0)]
const TIP_IN := 0.8
## The middle frames this share wider than the end ones (the hull's belly).
const BULGE := 0.03
## The hull's ends: the frames lower toward them (the end ones this share
## under the middle's: a ribcage's line from the side) and leaning out toward
## them (the end ones CANT deg off upright, fading in from CANT_FROM of the
## way out). The lean is a shear above each frame's foot, along the row, so
## each gap only opens with height and the channel's width stays.
const SHEER := 0.3
const CANT := 20.0
const CANT_FROM := 0.15
## The strakes of planking left, a low wall: their middles over the sand
## under each rib (m) and the chance each run between two frames is there
## (fewer higher up); half their thickness and height (m); of one that is
## there, the chance it ends broken partway.
const STRAKES := [Vector2(0.25,0.95),Vector2(0.85,0.8),Vector2(1.45,0.5)]
const PLANK_HALF := Vector2(0.1,0.31)
const PLANK_BROKEN := 0.35
## The keel: half its height and width (m); its middle this far over the sand
## (0: half sunk).
const KEEL_HALF := Vector2(0.65,0.55)
const KEEL_LIFT := 0.0
## The stem post that broke away: off the bow end (m past it), out to the
## sea side (m past the hull's side), turned (deg) and leaning out (deg).
const BOW_PAST := 6.0
const BOW_OUT := 3.5
const BOW_TURN := 35.0
const BOW_LEAN := 12.0
## A rib that came loose, lying on the sand past the stern on the keel's land
## side: its root (m out from the keel's line, m past the stern's frame), its
## way (deg off the row toward the land), how far its curve is tipped up off
## the sand (deg), its height as a frame (m) and how much is sunk (m).
const LOOSE_AT := Vector2(5.0,8.0)
const LOOSE_TURN := 8.0
const LOOSE_TIP := 30.0
const LOOSE_TALL := 8.0
const LOOSE_SINK := 0.25
## The wood: wet and weedy at the sand, weathered, sun-bleached at the tops;
## some ribs silvered more than others (up to SILVER_MOST of the way).
const WET := Color(0.15,0.17,0.12)
const WOOD := Color(0.36,0.3,0.24)
const BLEACHED := Color(0.8,0.77,0.69)
const SILVER := Color(0.6,0.6,0.58)
const SILVER_MOST := 0.4
## The LOD's error (m): every other ring.
const LOD_ERR := 0.3

## The section's eight points (a chamfered square, unit half sizes).
const SECTION := [Vector2(1.0,0.55),Vector2(0.55,1.0),Vector2(-0.55,1.0),Vector2(-1.0,0.55),
	Vector2(-1.0,-0.55),Vector2(-0.55,-1.0),Vector2(0.55,-1.0),Vector2(1.0,-0.55)]

static var _wood: Material

static func defaults() -> Dictionary:
	return {"shape":"row","count":9,"length":74.0,"tall":11.0,"jitter":0.1,"wide":1,"spans":0,
		"lean":0.0,"leaners":0,"fallen":0,"broken":2,"depth":1.0,"channel":TOY_CHANNEL,"land":3.0,"list":7.0}

static func material(_key: String) -> Material:
	if _wood == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.92
		_wood = m
	return _wood

## The wreck's frames, keel and bow (uprights.gd `pieces`), on a worker.
static func pieces(layout: Dictionary) -> Array:
	var kind: GDScript = load(UprightsPath)
	var land := func(x: float, z: float) -> float: return float(kind.call("land_y",layout,x,z))
	var p: Dictionary = layout.params
	var slots: Array = layout.slots
	var half_c := float(layout.channel)*0.5
	var half_len := float(p.length)*0.5
	var list := deg_to_rad(float(p.get("list",0.0)))
	var out: Array = []
	var b_end := 0.0
	var sides: Array = []
	for slot: Dictionary in slots:
		var at: Vector3 = slot.at
		var rd := float(slot.depth)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(slot.seed)
		# The narrowest a frame's rib comes in is its tip.
		var b_min := (half_c+MARGIN+rd*0.5*0.75)/TIP_IN
		var u := at.z/half_len
		var b := b_min*(1.0+BULGE*(1.0-u*u))
		if b_end == 0.0: b_end = b_min
		# A broken frame snaps one side short.
		var cut := Vector2.ONE
		if float(slot.short) < 1.0:
			if rng.randf() < 0.5: cut.x = float(slot.short)
			else: cut.y = float(slot.short)
		# Lower toward the ends, leaning out toward its end (+Z the stern).
		var h := float(slot.tall)*(1.0-SHEER*u*u)
		var cant := signf(u)*deg_to_rad(CANT)*smoothstep(CANT_FROM,1.0,absf(u))
		var piece := _new_piece()
		sides.append(_frame(piece,at,Vector3.RIGHT,Vector3.FORWARD,b,h,list+rng.randf_range(-1.5,1.5)*PI/180.0,
			cut,rd,minf(float(slot.wide),RIB_T),land,cant))
		out.append(_done(piece))
	out.append(_done(_planks(slots,sides,int(layout.seed),land)))
	out.append(_done(_keel(slots,half_len,land)))
	out.append(_done(_bow(Vector3(-(b_end+BOW_OUT),0.0,-(half_len+BOW_PAST)),float(p.tall),int(layout.seed),land)))
	var stern: Vector3 = (slots[0] as Dictionary).at
	out.append(_done(_loose(Vector3(LOOSE_AT.x,0.0,stern.z+LOOSE_AT.y),b_end,int(layout.seed),land)))
	return out

## A frame at `at` (its foot's middle, y the land's there): two ribs either
## side across `across`, in the plane of `across` and up, `b` the widest
## middle of a rib from the line, `h` tall, listed `list` (rad, its top
## toward -across), each side cut to `cut` (x the -across side's share),
## leaning `cant` (rad) toward +Z above its foot (a shear: heights kept).
## Gives each side's whole middle line ([-across side, +across side]).
static func _frame(piece: Dictionary, at: Vector3, across: Vector3, along: Vector3, b: float, h: float, list: float,
		cut: Vector2, rd: float, rt: float, land: Callable, cant := 0.0) -> Array:
	var cl := cos(list)
	var sl := sin(list)
	var shear := tan(cant)
	var silver := _silver(int(absf(at.z)*53.0))
	var lines: Array = []
	for s: float in [-1.0,1.0]:
		var ctrl: Array = []
		for k: Vector2 in RIB:
			var x := s*k.x*b
			var y := k.y*h
			# Listed: turned about the keel's line, the top toward -across.
			ctrl.append(Vector2(x*cl-y*sl,x*sl+y*cl))
		var first: Vector2 = ctrl[0]
		var root_x := first.x-s*0.12*b
		var w0 := at+across*root_x
		var under := minf(first.y,float(land.call(w0.x,w0.z))-at.y)-BURY
		ctrl.insert(0,Vector2(root_x,under))
		var pts := PackedVector3Array()
		for c: Vector2 in ctrl: pts.append(at+across*c.x+Vector3.UP*c.y+Vector3.BACK*maxf(c.y,0.0)*shear)
		pts = _curve(pts,STEP)
		lines.append(pts)
		var share := cut.x if s < 0.0 else cut.y
		if share < 1.0: pts = _cut(pts,share)
		var n := pts.size()
		var ha := PackedFloat32Array()
		var hb := PackedFloat32Array()
		var cols := PackedColorArray()
		var tint := _tint(int(absf(at.z)*131.0+s*17.0))
		for i in range(n):
			var t := float(i)/maxf(1.0,n-1.0)
			ha.append(rt*0.5*lerpf(1.0,0.85,t))
			hb.append(rd*0.5*lerpf(1.1,0.75,t))
			cols.append(_wood_at((pts[i].y-at.y)/h).lerp(SILVER,silver*smoothstep(0.1,0.4,(pts[i].y-at.y)/h))*tint)
		_timber(piece,pts,ha,hb,along,cols,0.15 if share >= 1.0 else 0.0,share < 1.0)
	return lines

## The planking left: on each side, between each pair of frames, the strakes
## that are there, on the ribs' outside at their height over the sand under
## each rib; some end broken partway.
static func _planks(slots: Array, sides: Array, seed_value: int, land: Callable) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value+11
	var piece := _new_piece()
	for k in range(slots.size()-1):
		var a: Dictionary = slots[k]
		var b: Dictionary = slots[k+1]
		for side in range(2):
			var s := -1.0 if side == 0 else 1.0
			var ga := _sand(sides[k][side],a.at as Vector3,land)
			var gb := _sand(sides[k+1][side],b.at as Vector3,land)
			for st: Vector2 in STRAKES:
				if rng.randf() > st.y: continue
				var y := st.x
				var pa := _at_height(sides[k][side],ga+y)
				var pb := _at_height(sides[k+1][side],gb+y)
				# On the ribs' outside.
				pa.x += s*(float(a.depth)*0.5+PLANK_HALF.x)
				pb.x += s*(float(b.depth)*0.5+PLANK_HALF.x)
				# From the rib's face (or past it), half the time from the other end.
				if rng.randf() < PLANK_BROKEN:
					var keep := rng.randf_range(0.3,0.7)
					if rng.randf() < 0.5: pb = pa.lerp(pb,keep)
					else: pa = pb.lerp(pa,keep)
				var col := _wood_at(y/8.0)*_tint(rng.randi())
				var pts := PackedVector3Array([pa,pb])
				_timber(piece,pts,PackedFloat32Array([PLANK_HALF.x,PLANK_HALF.x]),PackedFloat32Array([PLANK_HALF.y,PLANK_HALF.y]),
					Vector3(s,0.0,0.0),PackedColorArray([col,col]),0.0,false)
	return piece

## The sand under a rib (its middle line `pts` rising from the frame's foot
## `at`): the land where the rib comes up through the foot's height.
static func _sand(pts: PackedVector3Array, at: Vector3, land: Callable) -> float:
	var p := _at_height(pts,at.y)
	return float(land.call(p.x,p.z))

## The point on the rising line `pts` at height `y` (its first crossing; its
## top if it never gets there).
static func _at_height(pts: PackedVector3Array, y: float) -> Vector3:
	for i in range(pts.size()-1):
		if pts[i].y <= y and pts[i+1].y > y:
			return pts[i].lerp(pts[i+1],(y-pts[i].y)/(pts[i+1].y-pts[i].y))
	return pts[pts.size()-1]

## The keel: a timber along the line through the frames' feet, past each end,
## half sunk.
static func _keel(slots: Array, half_len: float, land: Callable) -> Dictionary:
	var pts := PackedVector3Array()
	var z_end := half_len+2.5
	pts.append(Vector3(0.0,float(land.call(0.0,z_end))+KEEL_LIFT,z_end))
	for slot: Dictionary in slots:
		var at: Vector3 = slot.at
		pts.append(Vector3(0.0,at.y+KEEL_LIFT,at.z))
	pts.append(Vector3(0.0,float(land.call(0.0,-z_end))+KEEL_LIFT,-z_end))
	pts = _curve(pts,2.0)
	var ha := PackedFloat32Array()
	var hb := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(pts.size()):
		ha.append(KEEL_HALF.x)
		hb.append(KEEL_HALF.y)
		cols.append(WET.lerp(WOOD,0.35))
	var piece := _new_piece()
	_timber(piece,pts,ha,hb,Vector3.UP,cols,0.0,true)
	return piece

## The bow that broke away: the stem post curving up and forward, turned and
## leaning out to sea, and one stub frame behind it.
static func _bow(foot: Vector3, tall: float, seed_value: int, land: Callable) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value+7
	var turn := deg_to_rad(BOW_TURN)
	# Forward: the row's way (-Z), turned toward the sea (-X).
	var fwd := Vector3(-sin(turn),0.0,-cos(turn))
	var side := fwd.cross(Vector3.UP).normalized()
	var lean := tan(deg_to_rad(BOW_LEAN))
	foot.y = float(land.call(foot.x,foot.z))
	var k := tall/10.5
	var pts := PackedVector3Array()
	for c: Vector2 in [Vector2(0.0,-BURY*1.5),Vector2(0.0,0.0),Vector2(0.6,4.0),Vector2(2.2,9.0),Vector2(4.6,13.5),Vector2(6.6,16.0)]:
		var up := c.y*k
		# Leaning out: toward the sea (-side is the post's left, out of the hull).
		pts.append(foot+fwd*c.x*k+Vector3.UP*up-side*maxf(up,0.0)*lean)
	pts = _curve(pts,STEP)
	var n := pts.size()
	var ha := PackedFloat32Array()
	var hb := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(n):
		var t := float(i)/maxf(1.0,n-1.0)
		ha.append(lerpf(0.6,0.45,t))
		hb.append(lerpf(0.85,0.6,t))
		cols.append(_wood_at((pts[i].y-foot.y)/(16.0*k)))
	var piece := _new_piece()
	_timber(piece,pts,ha,hb,side,cols,0.3,false)
	# A stub frame behind the post, narrow (the bow's), broken both sides.
	var at := foot-fwd*3.0
	at.y = float(land.call(at.x,at.z))
	_frame(piece,at,side,fwd,2.6,6.0,deg_to_rad(BOW_LEAN),Vector2(rng.randf_range(0.45,0.7),rng.randf_range(0.6,0.85)),0.7,RIB_T,land)
	return piece

## The rib that came loose: lying with its root at `root` (y from the land)
## and its tip along the row past it, turned LOOSE_TURN toward the land, its
## curve's bulge tipped LOOSE_TIP up off the sand toward the land, both ends
## in the sand. `b` the frames' widest (its curve is theirs).
static func _loose(root: Vector3, b: float, seed_value: int, land: Callable) -> Dictionary:
	var turn := deg_to_rad(LOOSE_TURN)
	var way := Vector3(sin(turn),0.0,cos(turn))
	var flat := Vector3(way.z,0.0,-way.x)
	var tip := deg_to_rad(LOOSE_TIP)
	var bulge := flat*cos(tip)+Vector3.UP*sin(tip)
	# The rib's curve, measured from its root along its chord and out from it.
	var r0 := Vector2((RIB[0] as Vector2).x*b,0.0)
	var r1 := Vector2((RIB[RIB.size()-1] as Vector2).x*b,LOOSE_TALL)
	var c := (r1-r0).normalized()
	var n := Vector2(c.y,-c.x)
	var ctrl := PackedVector3Array()
	for k: Vector2 in RIB:
		var q := Vector2(k.x*b,k.y*LOOSE_TALL)-r0
		var w := root+way*q.dot(c)+bulge*absf(q.dot(n))
		w.y = float(land.call(w.x,w.z))-LOOSE_SINK+(bulge*absf(q.dot(n))).y
		ctrl.append(w)
	var pts := _curve(ctrl,STEP)
	var m := pts.size()
	var ha := PackedFloat32Array()
	var hb := PackedFloat32Array()
	var cols := PackedColorArray()
	var tint := _tint(seed_value+29)
	for i in range(m):
		var t := float(i)/maxf(1.0,m-1.0)
		ha.append(RIB_T*0.5*lerpf(1.0,0.85,t))
		hb.append(0.5*lerpf(1.1,0.75,t))
		cols.append(WOOD.lerp(BLEACHED,0.45).lerp(SILVER,0.3)*tint)
	var piece := _new_piece()
	_timber(piece,pts,ha,hb,way.cross(bulge).normalized(),cols,0.1,true)
	return piece

# --- Timber -------------------------------------------------------------------

static func _new_piece() -> Dictionary:
	return {"v":PackedVector3Array(),"n":PackedVector3Array(),"c":PackedColorArray(),
		"idx":PackedInt32Array(),"lod":PackedInt32Array()}

## A timber along `pts` (its middle line): at each point a section `ha` half
## wide along `hint` (kept square to the line) and `hb` across, coloured
## `cols`. Both ends capped, the far one pushed out `tip` (m) to a point
## (`split`: off to one side, a splinter).
static func _timber(piece: Dictionary, pts: PackedVector3Array, ha: PackedFloat32Array, hb: PackedFloat32Array,
		hint: Vector3, cols: PackedColorArray, tip: float, split: bool) -> void:
	var v: PackedVector3Array = piece.v
	var nn: PackedVector3Array = piece.n
	var cc: PackedColorArray = piece.c
	var idx: PackedInt32Array = piece.idx
	var lod: PackedInt32Array = piece.lod
	var n := pts.size()
	var m := SECTION.size()
	var base := v.size()
	var axes: Array = []
	for i in range(n):
		var t := (pts[mini(i+1,n-1)]-pts[maxi(i-1,0)]).normalized()
		var a := (hint-t*hint.dot(t)).normalized()
		var bb := t.cross(a)
		axes.append([a,bb,t])
		for q: Vector2 in SECTION:
			v.append(pts[i]+a*q.x*ha[i]+bb*q.y*hb[i])
			nn.append((a*q.x/ha[i]+bb*q.y/hb[i]).normalized())
			cc.append(cols[i])
	# The sides: every ring, and every other ring for the LOD.
	var rings: Array = range(n)
	var half: Array = []
	for i in range(0,n,2): half.append(i)
	if half.back() != n-1: half.append(n-1)
	for pass_lod: bool in [false,true]:
		var list: Array = half if pass_lod else rings
		for r in range(list.size()-1):
			var i0: int = list[r]
			var i1: int = list[r+1]
			for q in range(m):
				var a0 := base+i0*m+q
				var a1 := base+i0*m+(q+1)%m
				var b0 := base+i1*m+q
				var b1 := base+i1*m+(q+1)%m
				var two := _tri(v,nn,a0,a1,b1)
				two.append_array(_tri(v,nn,a0,b1,b0))
				if pass_lod: lod.append_array(two)
				else: idx.append_array(two)
	# The caps: a point a little past each end, the far one `tip` out.
	for end: int in [0,n-1]:
		var ax: Array = axes[end]
		var t: Vector3 = ax[2]
		var dir := -t if end == 0 else t
		var push := 0.05 if end == 0 else maxf(tip,0.05)
		var centre := pts[end]+dir*push
		if end == n-1 and split: centre += (ax[0] as Vector3)*ha[end]*0.6+dir*0.35
		var c0 := v.size()
		v.append(centre)
		nn.append(dir)
		cc.append(cols[end])
		var ring0 := v.size()
		for q in range(m):
			v.append(v[base+end*m+q])
			nn.append((nn[base+end*m+q]+dir).normalized())
			cc.append(cols[end])
		for q in range(m):
			var one := _tri(v,nn,c0,ring0+q,ring0+(q+1)%m)
			idx.append_array(one)
			lod.append_array(one)
	piece.v = v
	piece.n = nn
	piece.c = cc
	piece.idx = idx
	piece.lod = lod

## A triangle wound to face out along its normals (Godot's front faces are
## clockwise seen from the front).
static func _tri(v: PackedVector3Array, n: PackedVector3Array, a: int, b: int, c: int) -> PackedInt32Array:
	var face := (v[b]-v[a]).cross(v[c]-v[a])
	if face.dot(n[a]+n[b]+n[c]) > 0.0: return PackedInt32Array([a,c,b])
	return PackedInt32Array([a,b,c])

## A piece's data as the kind takes it (uprights.gd `pieces`).
static func _done(piece: Dictionary) -> Dictionary:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = piece.v
	arrays[Mesh.ARRAY_NORMAL] = piece.n
	arrays[Mesh.ARRAY_COLOR] = piece.c
	arrays[Mesh.ARRAY_INDEX] = piece.idx
	var faces := PackedVector3Array()
	var v: PackedVector3Array = piece.v
	for i: int in piece.idx: faces.append(v[i])
	return {"arrays":arrays,"lods":{LOD_ERR:piece.lod},"faces":faces,"material":"wood"}

# --- Curves and colour --------------------------------------------------------

## A Catmull-Rom curve through `ctrl`, sampled about every `step` m.
static func _curve(ctrl: PackedVector3Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := ctrl.size()
	for i in range(n-1):
		var p0 := ctrl[maxi(i-1,0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i+1]
		var p3 := ctrl[mini(i+2,n-1)]
		var k := maxi(1,int(ceil(p1.distance_to(p2)/step)))
		for j in range(k):
			var t := float(j)/k
			out.append(0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t))
	out.append(ctrl[n-1])
	return out

## The first `share` of the curve `pts` by length.
static func _cut(pts: PackedVector3Array, share: float) -> PackedVector3Array:
	var total := 0.0
	for i in range(pts.size()-1): total += pts[i].distance_to(pts[i+1])
	var want := total*share
	var out := PackedVector3Array([pts[0]])
	var run := 0.0
	for i in range(pts.size()-1):
		var d := pts[i].distance_to(pts[i+1])
		if run+d >= want:
			out.append(pts[i].lerp(pts[i+1],(want-run)/maxf(d,1e-5)))
			break
		run += d
		out.append(pts[i+1])
	return out

## The wood's colour at `t` of the way up (0 the sand, 1 the top).
static func _wood_at(t: float) -> Color:
	if t < 0.15: return WET.lerp(WOOD,clampf(t/0.15,0.0,1.0))
	return WOOD.lerp(BLEACHED,smoothstep(0.25,0.95,t))

## How silvered a rib is (0 to SILVER_MOST), by its seed.
static func _silver(seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf()*SILVER_MOST

static func _tint(seed_value: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var k := rng.randf_range(0.92,1.06)
	return Color(k*rng.randf_range(0.97,1.03),k,k*rng.randf_range(0.95,1.02))
