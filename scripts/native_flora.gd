class_name NativeFlora
extends RefCounted
## Source foliage.js scatter layers and terrain.js rim boulders, regenerated
## from the terrain recipe in source plot space. Placement arithmetic keeps
## doubles until the terrain data packs float32 poses and linear float32 tints,
## which is exactly what the source's Float32 instance buffers held.
const Plate = preload("res://scripts/plate.gd")
## The source plot: the old 28 m square a range landscape sits on. Scatter
## and the site's height range are taken over it.
const SIZE := Plate.LEGACY_HALF*2.0
## Scales the scatter's try budgets; counts come from the recipe (content),
## so this stays 1 whatever the plate's size.
const AREA := 1.0
## The source water field, as NativeRecipeWater's.
const N := Plate.RECIPE_WATER_CELLS
const W := N+1
const CELL := Plate.RECIPE_WATER_HALF*2.0/N
const SAME_WATER := 0.001
const FLOWER_PALETTES := [["#efc34f","#b7a3d5","#fff0cc"],["#a38bdd","#d6a6d9","#f4efe5"],["#de8599","#bc7198","#fff0df"],["#f1e8cf","#b7a3d5","#fff0df"]]
const BLOSSOM_COLORS := ["#f1d7d7","#f4e8ce","#dba6bc"]
const FLOWER_FORMS := ["button","spike","umbel","daisy"]
const FLOWER_KINDS := {"button":"button_flower","spike":"spike_flower","umbel":"umbel_flower","daisy":"daisy_flower"}

# --- The source's mulberry-style RNG, with JS-exact 32-bit integer steps ----
class Rng:
	var state: int
	static func _i32(v: int) -> int:
		v = v & 0xFFFFFFFF
		return v - 0x100000000 if v >= 0x80000000 else v
	static func _ushr(v: int, n: int) -> int: return (v & 0xFFFFFFFF) >> n
	static func _imul(a: int, b: int) -> int:
		a = a & 0xFFFFFFFF
		b = b & 0xFFFFFFFF
		return _i32((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16))
	func _init(seed: int) -> void: state = _i32(seed)
	func next() -> float:
		state = _i32(state + 0x6d2b79f5)
		var t := _imul(state ^ _ushr(state,15), 1 | state)
		t = _i32((t + _imul(t ^ _ushr(t,7), 61 | t)) ^ t)
		return float((t ^ _ushr(t,14)) & 0xFFFFFFFF) / 4294967296.0
	func skip(count: int) -> void:
		for i in range(count): next()

## V8's Math.hypot: normalised Kahan sum, then sqrt times the largest magnitude.
static func _hypot(a: float, b: float) -> float:
	a = absf(a)
	b = absf(b)
	var m := maxf(a,b)
	if m == 0.0: return 0.0
	var sum := 0.0
	var compensation := 0.0
	for v in [a,b]:
		var n: float = v/m
		var summand := n*n - compensation
		var preliminary := sum + summand
		compensation = (preliminary - sum) - summand
		sum = preliminary
	return sqrt(sum)*m
static func _js_round(v: float) -> int: return floori(v+0.5)
static func _clamp01(v: float) -> float: return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)

# --- THREE.Color arithmetic in the linear working space -----------------------
static func _srgb_to_linear(c: float) -> float:
	return c*0.0773993808 if c < 0.04045 else pow(c*0.9478672986+0.0521327014, 2.4)
static func _hex(text: String) -> Array:
	var v := text.trim_prefix("#").hex_to_int()
	return [_srgb_to_linear(float((v >> 16) & 255)/255.0), _srgb_to_linear(float((v >> 8) & 255)/255.0), _srgb_to_linear(float(v & 255)/255.0)]
static func _get_hsl(c: Array) -> Array:
	var r: float = c[0]
	var g: float = c[1]
	var b: float = c[2]
	var mx := maxf(r,maxf(g,b))
	var mn := minf(r,minf(g,b))
	var l := (mn+mx)/2.0
	if mn == mx: return [0.0,0.0,l]
	var delta := mx-mn
	var s := delta/(mx+mn) if l <= 0.5 else delta/(2.0-mx-mn)
	var h: float
	if mx == r: h = (g-b)/delta + (6.0 if g < b else 0.0)
	elif mx == g: h = (b-r)/delta + 2.0
	else: h = (r-g)/delta + 4.0
	return [h/6.0,s,l]
static func _hue2rgb(p: float, q: float, t: float) -> float:
	if t < 0.0: t += 1.0
	if t > 1.0: t -= 1.0
	if t < 1.0/6.0: return p + (q-p)*6.0*t
	if t < 1.0/2.0: return q
	if t < 2.0/3.0: return p + (q-p)*6.0*(2.0/3.0-t)
	return p
static func _set_hsl(h: float, s: float, l: float) -> Array:
	h = fmod(fmod(h,1.0)+1.0,1.0)
	s = clampf(s,0.0,1.0)
	l = clampf(l,0.0,1.0)
	if s == 0.0: return [l,l,l]
	var p := l*(1.0+s) if l <= 0.5 else l+s-(l*s)
	var q := (2.0*l)-p
	return [_hue2rgb(q,p,h+1.0/3.0),_hue2rgb(q,p,h),_hue2rgb(q,p,h-1.0/3.0)]
static func _offset_hsl(c: Array, dh: float, ds: float, dl: float) -> Array:
	var hsl := _get_hsl(c)
	return _set_hsl(hsl[0]+dh,hsl[1]+ds,hsl[2]+dl)
static func _lerp(c: Array, d: Array, alpha: float) -> Array:
	return [c[0]+(d[0]-c[0])*alpha,c[1]+(d[1]-c[1])*alpha,c[2]+(d[2]-c[2])*alpha]
static func _cover_offset(cover: Dictionary, k: float) -> Array:
	var p: float = float(cover.get("parch",0.0))*k
	var c: float = float(cover.get("chill",0.0))*k
	var w: float = float(cover.get("sodden",0.0))*k
	return [-0.075*p + 0.06*c + 0.03*w, -0.38*p - 0.3*c + 0.05*w, 0.1*p + 0.06*c - 0.08*w]
static func _cover_ramp(v: float) -> float:
	var t := minf(1.0,maxf(0.0,(v-0.45)/0.4))
	return t*t*(3.0-2.0*t)
static func _cover_ramps(cover: Dictionary) -> Dictionary:
	return {"sand":_cover_ramp(float(cover.get("parch",0.0))),"marsh":_cover_ramp(float(cover.get("sodden",0.0))),"tundra":_cover_ramp(float(cover.get("chill",0.0)))}

# --- THREE.Quaternion / Matrix4.compose ---------------------------------------
static func _quat(axis: Vector3, angle: float) -> Array:
	var half := angle/2.0
	var s := sin(half)
	return [axis.x*s,axis.y*s,axis.z*s,cos(half)]
static func _quat_mul(a: Array, b: Array) -> Array:
	var qax: float = a[0]
	var qay: float = a[1]
	var qaz: float = a[2]
	var qaw: float = a[3]
	var qbx: float = b[0]
	var qby: float = b[1]
	var qbz: float = b[2]
	var qbw: float = b[3]
	return [qax*qbw + qaw*qbx + qay*qbz - qaz*qby, qay*qbw + qaw*qby + qaz*qbx - qax*qbz, qaz*qbw + qaw*qbz + qax*qby - qay*qbx, qaw*qbw - qax*qbx - qay*qby - qaz*qbz]
static func _compose(px: float, py: float, pz: float, q: Array, sx: float, sy: float, sz: float) -> PackedFloat64Array:
	var x: float = q[0]
	var y: float = q[1]
	var z: float = q[2]
	var w: float = q[3]
	var x2 := x+x
	var y2 := y+y
	var z2 := z+z
	var xx := x*x2
	var xy := x*y2
	var xz := x*z2
	var yy := y*y2
	var yz := y*z2
	var zz := z*z2
	var wx := w*x2
	var wy := w*y2
	var wz := w*z2
	return PackedFloat64Array([(1.0-(yy+zz))*sx,(xy+wz)*sx,(xz-wy)*sx,0.0,(xy-wz)*sy,(1.0-(xx+zz))*sy,(yz+wx)*sy,0.0,(xz+wy)*sz,(yz-wx)*sz,(1.0-(xx+yy))*sz,0.0,px,py,pz,1.0])
static func _upright(px: float, py: float, pz: float, rot: float, sx: float, sy: float, sz: float) -> PackedFloat64Array:
	return _compose(px,py,pz,_quat(Vector3.UP,rot),sx,sy,sz)
static func _entry(asset: String, m: PackedFloat64Array, color: Variant = null, pivot := false) -> Dictionary:
	return {"asset":asset,"m":m,"color":color,"pivot":pivot}

# --- The water field (source water.js buildWaterField) in plot space ----------
## `ground` is the analytic plot height; ponds and streams are plot-space
## records. Authored ponds flood like the source lake: no spill promises and no
## pond-area cap, since a plot standing alone promises nothing at its borders.
static func water_field(ground: Callable, ponds: Array, streams: Array) -> Dictionary:
	var h := PackedFloat32Array()
	h.resize(W*W)
	for j in range(W):
		for i in range(W):
			h[j*W+i] = ground.call(-Plate.RECIPE_WATER_HALF+i*CELL,-Plate.RECIPE_WATER_HALF+j*CELL)
	var wet := PackedByteArray()
	wet.resize(W*W)
	var kind := PackedByteArray()
	kind.resize(W*W)
	var dep := PackedFloat32Array()
	dep.resize(W*W)
	var bodies: Array = []
	for body in ponds:
		var bi := _js_round((float(body.x)+Plate.RECIPE_WATER_HALF)/CELL)
		var bj := _js_round((float(body.z)+Plate.RECIPE_WATER_HALF)/CELL)
		var best := INF
		var bk := -1
		for dj in [-1,0,1]:
			for di in [-1,0,1]:
				var i: int = bi+di
				var j: int = bj+dj
				if i < 0 or j < 0 or i >= W or j >= W: continue
				var k := j*W+i
				if h[k] < best:
					best = h[k]
					bk = k
		var level: float = body.level
		if bk < 0 or best >= level: continue
		var covered := false
		for other in bodies:
			if other.mask[bk] and other.level >= level-SAME_WATER: covered = true
		if covered: continue
		var mask := PackedByteArray()
		mask.resize(W*W)
		mask[bk] = 1
		var stack: Array[int] = [bk]
		while not stack.is_empty():
			var k: int = stack.pop_back()
			var i := k % W
			var j := (k-i)/W
			for d in [[1,0],[-1,0],[0,1],[0,-1]]:
				var ni: int = i+d[0]
				var nj: int = j+d[1]
				if ni < 0 or nj < 0 or ni >= W or nj >= W: continue
				var nk := nj*W+ni
				if mask[nk] or h[nk] >= level: continue
				mask[nk] = 1
				stack.append(nk)
		for k in range(W*W):
			if not mask[k]: continue
			wet[k] = 1
			kind[k] = 1
			dep[k] = maxf(dep[k],level-h[k])
		bodies.append({"mask":mask,"level":level})
	preload("res://scripts/native_recipe_water.gd").stamp_streams(streams,wet,dep,kind)
	var sd: PackedFloat32Array = preload("res://scripts/native_recipe_water.gd").signed_distance(wet,kind)
	return {"shore":sd,"depth":dep,"kind":kind}
static func _sample(values: PackedFloat32Array, x: float, z: float, fallback: float) -> float:
	var fi := (x+Plate.RECIPE_WATER_HALF)/CELL
	var fj := (z+Plate.RECIPE_WATER_HALF)/CELL
	if fi < 0.0 or fj < 0.0 or fi > N or fj > N: return fallback
	var i := mini(N-1,floori(fi))
	var j := mini(N-1,floori(fj))
	var u := fi-i
	var v := fj-j
	var k := j*W+i
	return values[k]*(1.0-u)*(1.0-v) + values[k+1]*u*(1.0-v) + values[k+W]*(1.0-u)*v + values[k+W+1]*u*v
static func shore_at(field: Dictionary, x: float, z: float) -> float: return _sample(field.shore,x,z,40.0)
static func depth_at(field: Dictionary, x: float, z: float) -> float: return _sample(field.depth,x,z,0.0)
static func kind_at(field: Dictionary, x: float, z: float) -> int:
	var i := _js_round((x+Plate.RECIPE_WATER_HALF)/CELL)
	var j := _js_round((z+Plate.RECIPE_WATER_HALF)/CELL)
	if i < 0 or j < 0 or i > N or j > N: return 0
	return field.kind[j*W+i]

# --- The site field (source site.js makeSite) ---------------------------------
class Site:
	var ground: Callable
	var fbm: Callable
	var shore_of: Callable
	var step := 0.125
	var n := roundi(Plate.SIZE/step)+1
	var half := Plate.HALF
	var grid := PackedFloat32Array()
	var lo := INF
	var hi := -INF
	var span := 0.001
	var alpine_span := 0.001
	var tree_span := 0.001
	var moisture_bias := 0.0
	static func _c01(v: float) -> float: return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)
	static func _hyp(a: float, b: float) -> float:
		a = absf(a)
		b = absf(b)
		var m := maxf(a,b)
		if m == 0.0: return 0.0
		var sum := 0.0
		var compensation := 0.0
		for v in [a,b]:
			var q: float = v/m
			var summand := q*q - compensation
			var preliminary := sum + summand
			compensation = (preliminary - sum) - summand
			sum = preliminary
		return sqrt(sum)*m
	func _init(ground_at: Callable, noise: Callable, treeline: float, shore: Callable, bias: float, treeline_drop: float) -> void:
		ground = ground_at
		fbm = noise
		shore_of = shore
		moisture_bias = bias
		grid.resize(n*n)
		grid.fill(NAN)
		for i in range(33):
			for j in range(33):
				var h := lattice((i/32.0-0.5)*SIZE,(j/32.0-0.5)*SIZE)
				if h < lo: lo = h
				if h > hi: hi = h
		span = maxf(0.001,hi-lo)
		alpine_span = maxf(0.001,treeline-lo)
		tree_span = alpine_span*(1.0-_c01(treeline_drop)*0.999)
	func _at(i: int, j: int) -> float:
		var k := i*n+j
		var v := grid[k]
		if is_nan(v):
			grid[k] = ground.call(-half+i*step,-half+j*step)
			v = grid[k]
		return v
	## Lattice-memoised ground, bilinear in Float32 samples, exactly as the source reads it.
	func lattice(x: float, z: float) -> float:
		var fx := (x+half)/step
		var fz := (z+half)/step
		if not (fx >= 0.0 and fz >= 0.0 and fx <= n-1 and fz <= n-1): return ground.call(x,z)
		var i := int(fx)
		var j := int(fz)
		if i >= n-1: i = n-2
		if j >= n-1: j = n-2
		var tx := fx-i
		var tz := fz-j
		var top := _at(i,j)*(1.0-tx) + _at(i+1,j)*tx
		var bot := _at(i,j+1)*(1.0-tx) + _at(i+1,j+1)*tx
		return top*(1.0-tz) + bot*tz
	func slope(x: float, z: float) -> float:
		var dx := lattice(x+0.25,z) - lattice(x-0.25,z)
		var dz := lattice(x,z+0.25) - lattice(x,z-0.25)
		return _hyp(dx,dz)/(2.0*0.25)
	func at(x: float, z: float) -> Dictionary:
		var hl := lattice(x,z)
		var s := slope(x,z)
		var elev01 := _c01((hl-lo)/span)
		var tree01 := (hl-lo)/tree_span
		var alpine01 := (hl-lo)/alpine_span
		var shore: float = shore_of.call(x,z)
		var exposure := _c01(_c01(tree01)*(0.45+0.55*_c01(s)))
		var near_water := 1.0-smoothstep(0.0,5.5,shore)
		var around := (lattice(x+1.7,z) + lattice(x-1.7,z) + lattice(x,z+1.7) + lattice(x,z-1.7))*0.25
		var hollow := _c01((around-hl)/0.7)
		var lowland := 1.0-smoothstep(0.05,0.55,elev01)
		var damp := _c01(fbm.call(x*0.12+31.0,z*0.12+31.0)*1.4)
		var moisture := _c01(maxf(near_water,lowland*(0.18+0.55*hollow+0.34*damp)+moisture_bias))
		return {"slope":s,"elev01":elev01,"tree01":tree01,"alpine01":alpine01,"shore":shore,"exposure":exposure,"moisture":moisture}

static func _landmark_clearing(l: Variant, x: float, z: float) -> bool:
	if not l is Dictionary or l.is_empty(): return false
	var rx: float = x-l.x
	var rz: float = z-l.z
	var u: float = rx*l.dx + rz*l.dz
	var v: float = -rx*l.dz + rz*l.dx
	if l.kind == "arch": return absf(u) < 5.4 and absf(v) < 2.8
	if l.kind == "slot-basin" or l.kind == "terraced-pools": return absf(u) < 3.4 and absf(v) < 5.7
	return _hypot(u,v) < (4.7 if l.kind == "great-tree" else 3.2)

## Source flowering.js field: the openings the trees leave for flowers.
class Flowering:
	var gene: Dictionary
	var fbm: Callable
	var ca := 1.0
	var sa := 0.0
	func _init(value: Variant, noise: Callable) -> void:
		gene = value if value is Dictionary else {}
		fbm = noise
		if not gene.is_empty():
			ca = cos(gene.angle)
			sa = sin(gene.angle)
	func active() -> bool: return not gene.is_empty()
	func flag(key: String) -> bool: return bool(gene.get(key,false))
	func _habitat(site: Dictionary) -> float:
		var open := flag("open")
		return (1.0-smoothstep(0.3,0.52,site.slope)) * ((0.65+0.35*smoothstep(0.08,0.32,site.moisture)) if open else smoothstep(0.3,0.58,site.moisture)) * (1.0 if open else 1.0-smoothstep(0.55,0.85,site.tree01)) * smoothstep(0.3,1.1,site.shore)
	func _edge(x: float, z: float) -> float:
		return smoothstep(0.6,1.3 if flag("open") else 3.0,SIZE/2.0-maxf(absf(x),absf(z)))
	func meadow_at(x: float, z: float, site: Dictionary) -> float:
		if gene.is_empty(): return 0.0
		var u := x*ca + z*sa
		var v := z*ca - x*sa
		var n: float = fbm.call(u*gene.frequency+37.0,v*gene.frequency*gene.stretch-19.0)
		var shore := (0.08+0.92*(1.0-smoothstep(1.2,5.0,site.shore))) if flag("lakeside") else 1.0
		return shore*float(gene.meadow)*((0.55+0.45*n) if flag("open") else smoothstep(0.32,0.65,n))*_habitat(site)*_edge(x,z)
	func grove_at(x: float, z: float, site: Dictionary) -> float:
		if gene.is_empty(): return 0.0
		var n: float = fbm.call(x*0.13-71.0,z*0.13+43.0)
		return float(gene.blossom)*smoothstep(0.36,0.62,n)*_habitat(site)*_edge(x,z)

static func _crowded(list: Array, x: float, z: float, gap: float) -> bool:
	var g2 := gap*gap
	for o in list:
		var dx: float = o.x-x
		var dz: float = o.z-z
		if dx*dx+dz*dz < g2: return true
	return false

## Every scatter layer of source foliageJob for a plot standing alone, plus the
## genome's rim boulders. Returns placements in source order per mesh.
static func build(ground: Callable, source: RefCounted, field: Dictionary) -> Array:
	var g: Dictionary = source.g
	var fbm: Callable = source.fbm
	var landmark: Variant = source.landmark
	var pool: Dictionary = source.pool
	var out: Array = []
	var seed := int(g.seed)
	var S := SIZE
	var ramps := _cover_ramps(g.cover)
	var shore_of := func(x: float, z: float) -> float: return shore_at(field,x,z)
	var site := Site.new(ground,fbm,float(g.trees.maxH),shore_of,0.45*ramps.marsh-0.45*ramps.sand,0.55*ramps.tundra)
	var flowering := Flowering.new(g.understory.get("flowering"),fbm)
	var kind_sand: float = ramps.sand
	var kind_marsh: float = ramps.marsh
	var cover_at := func(k: float) -> Array: return _cover_offset(g.cover,k)
	var r_tree := Rng.new(seed ^ 20260828)
	var r_ground := Rng.new(seed ^ 0x27d4eb2f)
	var r_broad := Rng.new(seed ^ 0x165667b1)
	var r_shrub := Rng.new(seed ^ 0x5bf03635)
	var r_flower := Rng.new(seed ^ 0x85ebca6b)
	var U: Dictionary = g.understory

	# --- trees ---------------------------------------------------------------
	var spots: Array = []
	var giant: float = float(g.trees.get("giant",0.0))
	var blue: float = float(g.trees.get("blue",0.0))
	var count := int(g.trees.count)
	if flowering.active() and flowering.flag("open"): count = 0
	var GAP := 1.15*(1.0+1.1*giant)
	var tries := 0
	while spots.size() < count and tries < 9000*AREA:
		tries += 1
		var x := (r_tree.next()-0.5)*(S-3.0)
		var z := (r_tree.next()-0.5)*(S-3.0)
		if _landmark_clearing(landmark,x,z): continue
		var s := site.at(x,z)
		if flowering.active() and flowering.meadow_at(x,z,s) > 0.18: continue
		if flowering.active() and flowering.grove_at(x,z,s) > 0.22: continue
		if s.slope > 0.7: continue
		if s.shore < 1.0: continue
		if s.tree01 > 1.0: continue
		var oasis := r_tree.next()
		if kind_sand > 0.0 and oasis < kind_sand*(1.0-smoothstep(0.2,0.5,s.moisture)): continue
		var thin: float = smoothstep(0.70,1.0,s.tree01)*(0.55+0.45*s.exposure)
		if r_tree.next() < thin: continue
		var grove := _clamp01(fbm.call(x*0.16-11.0,z*0.16-11.0)*1.6)
		var gap := GAP*(1.45-0.7*grove)
		if _crowded(spots,x,z,gap): continue
		var stunt: float = smoothstep(0.55,1.0,s.tree01)
		var lowland: float = 1.0-smoothstep(0.25,1.0,s.tree01)
		var giant_scale := 1.0/(1.0+2.0*giant*(1.0-lowland))
		var size: float = (0.78+0.34*s.moisture)*(1.0-0.42*stunt)*giant_scale*(0.88+r_tree.next()*0.28)
		var lank := r_tree.next()
		spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":r_tree.next()*PI*2.0,"s":size,"lank":lank,"site":s})
	var CANOPY := _lerp(_lerp(_hex("#3e7a44"),_hex("#2e6a3c"),giant),_hex("#5b8088"),0.85*blue)
	var trees: Array = []
	for spot in spots:
		var sy: float = spot.s*(0.9+(0.3+0.3*giant)*spot.lank)
		var sx: float = spot.s*(1.1-0.25*spot.lank)
		var m := _upright(spot.x,spot.h-0.05,spot.z,spot.rot,sx,sy,sx)
		var o: Array = cover_at.call(0.3)
		var tint := _offset_hsl(CANOPY,o[0],o[1],o[2])
		var exposure: float = spot.site.exposure
		var moisture: float = spot.site.moisture
		var a := 0.035*exposure - 0.02*moisture + (r_tree.next()-0.5)*0.02
		var b := -0.16*exposure + 0.06*moisture + (r_tree.next()-0.5)*0.06
		var c := 0.06*exposure - 0.04*moisture + (r_tree.next()-0.5)*0.05
		trees.append(_entry("tree",m,_offset_hsl(tint,a,b,c)))
	out.append_array(trees)

	# --- grass ---------------------------------------------------------------
	var g_spots: Array = []
	var g_count := int(g.grass.count)
	var threshold: float = g.grass.threshold
	tries = 0
	while g_spots.size() < g_count and tries < 30000*AREA:
		tries += 1
		var x := (r_ground.next()-0.5)*(S-2.0)
		var z := (r_ground.next()-0.5)*(S-2.0)
		var n: float = fbm.call(x*0.3+5.0,z*0.3+5.0)
		if n < threshold-0.14: continue
		var s := site.at(x,z)
		if n < threshold - 0.14*s.moisture + 0.10*s.exposure: continue
		if s.slope > 0.55: continue
		if s.shore < 0.2: continue
		if r_ground.next() < smoothstep(0.80,1.02,s.alpine01): continue
		var rot := r_ground.next()*PI*2.0
		var size: float = (0.62+0.36*s.moisture)*(0.85+r_ground.next()*0.5)
		g_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size})
	for spot in g_spots:
		out.append(_entry("grass_tuft",_upright(spot.x,spot.h-0.02,spot.z,spot.rot,spot.s,spot.s,spot.s)))

	# --- broadleaves ---------------------------------------------------------
	var b_spots: Array = []
	tries = 0
	while b_spots.size() < int(U.broadleafCount) and tries < 22000*AREA:
		tries += 1
		var x := (r_broad.next()-0.5)*(S-3.0)
		var z := (r_broad.next()-0.5)*(S-3.0)
		if _landmark_clearing(landmark,x,z): continue
		var s := site.at(x,z)
		if flowering.active() and not flowering.flag("canopy") and flowering.meadow_at(x,z,s) > 0.3: continue
		if s.slope > 0.62: continue
		if s.shore < 1.2: continue
		if s.tree01 > float(U.broadleafMax): continue
		var moisture: float = maxf(s.moisture,0.56) if flowering.active() and flowering.flag("canopy") else s.moisture
		if moisture < 0.46: continue
		if r_broad.next() > smoothstep(0.46,0.78,moisture): continue
		if _crowded(b_spots,x,z,1.5): continue
		if _crowded(spots,x,z,1.1): continue
		var slender := r_broad.next()
		var rot := r_broad.next()*PI*2.0
		b_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"sy":(0.82+0.3*s.moisture)*(0.86+slender*0.5),"sx":(0.86+0.26*s.moisture)*(1.16-slender*0.42),"slender":slender,"site":s})
	# broadleafCanopyGeometry draws from the same stream before the tints
	for i in range(3):
		r_broad.next()
		if i != 0: r_broad.next()
		r_broad.next()
	var BROAD := _hex("#6f9c46")
	for spot in b_spots:
		var m := _upright(spot.x,spot.h-0.05,spot.z,spot.rot,spot.sx,spot.sy,spot.sx)
		var o: Array = cover_at.call(0.8)
		var tint := _offset_hsl(BROAD,o[0],o[1],o[2])
		var a: float = 0.03*spot.slender - 0.02*spot.site.moisture + (r_broad.next()-0.5)*0.03
		var b: float = -0.08*spot.slender + (r_broad.next()-0.5)*0.08
		var c: float = 0.07*spot.slender + (r_broad.next()-0.5)*0.05
		tint = _offset_hsl(tint,a,b,c)
		var bloom := flowering.grove_at(spot.x,spot.z,spot.site)
		if bloom > 0.12:
			tint = _lerp(tint,_hex(BLOSSOM_COLORS[int(flowering.gene.get("blossomColor",0))]),smoothstep(0.12,0.32,bloom))
		out.append(_entry("broadleaf",m,tint))

	# --- shrubs --------------------------------------------------------------
	var s_spots: Array = []
	tries = 0
	while s_spots.size() < int(U.shrubCount) and tries < 48000*AREA:
		tries += 1
		var x := (r_shrub.next()-0.5)*(S-2.0)
		var z := (r_shrub.next()-0.5)*(S-2.0)
		if fbm.call(x*0.42-3.0,z*0.42-3.0) < 0.44: continue
		var s := site.at(x,z)
		if s.slope > 1.05: continue
		if s.shore < 0.5: continue
		if s.tree01 > 1.5: continue
		var want: float = maxf(smoothstep(0.55,1.15,s.tree01),smoothstep(0.58,0.95,s.slope))
		if want < 0.05: continue
		if r_shrub.next() > want: continue
		var rot := r_shrub.next()*PI*2.0
		var size := 0.72+r_shrub.next()*0.62
		s_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size,"site":s})
	_skip_shrub_geometry(r_shrub)
	var SHRUB := _hex("#5c7a3e")
	for spot in s_spots:
		var m := _upright(spot.x,spot.h-0.03,spot.z,spot.rot,spot.s,spot.s,spot.s)
		var o: Array = cover_at.call(0.7)
		var tint := _offset_hsl(SHRUB,o[0],o[1],o[2])
		var exposure: float = spot.site.exposure
		var a := -0.07*exposure + (r_shrub.next()-0.5)*0.04
		var b := 0.1*exposure + (r_shrub.next()-0.5)*0.1
		var c := -0.02*exposure + (r_shrub.next()-0.5)*0.06
		out.append(_entry("shrub",m,_offset_hsl(tint,a,b,c)))

	# --- the water's edge ----------------------------------------------------
	var r_reed := Rng.new(seed ^ 0x9e3779b1)
	var r_bank := Rng.new(seed ^ 0x6a09e667)
	var re_spots: Array = []
	tries = 0
	while re_spots.size() < int(U.reedCount) and tries < 60000*AREA:
		tries += 1
		var x := (r_reed.next()-0.5)*(S-2.0)
		var z := (r_reed.next()-0.5)*(S-2.0)
		var shore := shore_at(field,x,z)
		var margin := shore <= 0.85 and shore >= -1.6
		if not margin:
			if kind_marsh <= 0.0 or shore < 0.85: continue
			if r_reed.next() > kind_marsh: continue
		if depth_at(field,x,z) > (0.14 if kind_at(field,x,z) == 2 else 0.4): continue
		var s := site.at(x,z)
		if s.slope > 0.95: continue
		if not margin:
			if s.slope > 0.45: continue
			if s.moisture < 0.82: continue
		if fbm.call(x*0.5+63.0,z*0.5+63.0) < 0.42 + 0.16*smoothstep(-0.4,0.8,shore): continue
		var rot := r_reed.next()*PI*2.0
		var base: float = (0.78+0.42*(1.0-smoothstep(-0.5,0.85,shore))) if margin else (0.7+0.2*s.moisture)
		var size := base*(0.82+r_reed.next()*0.45)
		re_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size})
	for spot in re_spots:
		out.append(_entry("reeds",_upright(spot.x,spot.h-0.02,spot.z,spot.rot,spot.s,spot.s,spot.s)))
	var bk_spots: Array = []
	tries = 0
	while bk_spots.size() < int(U.bankCount) and tries < 30000*AREA:
		tries += 1
		var x := (r_bank.next()-0.5)*(S-2.0)
		var z := (r_bank.next()-0.5)*(S-2.0)
		var shore := shore_at(field,x,z)
		if shore < 0.45 or shore > 2.8: continue
		var s := site.at(x,z)
		if s.slope > 0.8: continue
		if s.tree01 > 0.9: continue
		if r_bank.next() > 1.0-smoothstep(0.6,2.8,shore): continue
		if _crowded(bk_spots,x,z,0.85): continue
		var rot := r_bank.next()*PI*2.0
		var size := 1.5+r_bank.next()*1.1
		bk_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size,"site":s})
	_skip_shrub_geometry(r_bank)
	var BANK := _hex("#4e7c3c")
	for spot in bk_spots:
		var m := _upright(spot.x,spot.h-0.04,spot.z,spot.rot,spot.s*1.15,spot.s,spot.s*1.15)
		var o: Array = cover_at.call(0.4)
		var tint := _offset_hsl(BANK,o[0],o[1],o[2])
		var a: float = (r_bank.next()-0.5)*0.05 - 0.02*spot.site.moisture
		var b: float = (r_bank.next()-0.5)*0.1
		var c: float = (r_bank.next()-0.5)*0.08
		out.append(_entry("bank_grass",m,_offset_hsl(tint,a,b,c)))

	# --- flowers: patches, then the meadow drift -----------------------------
	var f_spots := {"button":[],"spike":[],"umbel":[],"daisy":[]}
	var hue: Array = [0.0,0.0,0.0]
	var patches := 0
	var flower_hue: float = U.flowerHue
	var flower_per := int(U.flowerPer)
	var palette_index := int(flowering.gene.get("palette",0)) if flowering.active() else 0
	tries = 0
	while patches < int(U.flowerPatches) and tries < 4000*AREA:
		tries += 1
		var cx := (r_flower.next()-0.5)*(S-4.0)
		var cz := (r_flower.next()-0.5)*(S-4.0)
		var c := site.at(cx,cz)
		if c.slope > 0.42 or c.shore < 0.6 or c.tree01 > 0.72: continue
		if c.moisture < 0.58: continue
		patches += 1
		var roll := r_flower.next()
		var form: String
		if roll < 0.2 + 0.25*smoothstep(0.6,0.9,c.moisture): form = "spike"
		elif roll > 0.78 - 0.2*(1.0-smoothstep(0.55,0.8,c.moisture)): form = "umbel"
		else: form = "button"
		if form == "umbel":
			var h := fmod(flower_hue + patches*0.17,1.0)
			var s := 0.18+r_flower.next()*0.2
			var l := 0.84+r_flower.next()*0.1
			hue = _set_hsl(h,s,l)
		elif form == "spike":
			var h := 0.62 + fmod(flower_hue + patches*0.17 + r_flower.next()*0.05,1.0)*0.3
			var s := 0.5+r_flower.next()*0.3
			var l := 0.55+r_flower.next()*0.15
			hue = _set_hsl(h,s,l)
		else:
			var h := fmod(flower_hue + patches*0.17 + r_flower.next()*0.05,1.0)
			var s := 0.5+r_flower.next()*0.28
			var l := 0.6+r_flower.next()*0.16
			hue = _set_hsl(h,s,l)
		if flowering.active():
			hue = _hex(FLOWER_PALETTES[palette_index][1 if form == "spike" else (2 if form == "umbel" else 0)])
		var radius := 0.9+r_flower.next()*1.5
		for k in range(flower_per):
			var rr := radius*pow(r_flower.next(),0.65)
			var a := r_flower.next()*PI*2.0
			var x := cx+cos(a)*rr
			var z := cz+sin(a)*rr
			var s := site.at(x,z)
			if s.slope > 0.55 or s.shore < 0.3 or s.tree01 > 0.85: continue
			var rot := r_flower.next()*PI*2.0
			var size := 1.0*(0.7+r_flower.next()*0.6)
			f_spots[form].append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size,"stem":2.1 if form == "spike" else 1.0,"c":hue.duplicate()})
	if flowering.active() and float(flowering.gene.get("meadow",0.0)) > 0.0:
		var rf := Rng.new(seed ^ 0xbb67ae85)
		var palette: Array = FLOWER_PALETTES[palette_index]
		var meadow: float = flowering.gene.meadow
		var budget := int(round(15000.0*AREA*meadow))
		var limit := int(round((5200.0 if flowering.flag("open") else 2600.0)*AREA*meadow))
		var planted := 0
		var height: float = flowering.gene.height
		var i := 0
		while i < budget and planted < limit:
			i += 1
			var x := (rf.next()-0.5)*(S-1.2)
			var z := (rf.next()-0.5)*(S-1.2)
			if _landmark_clearing(landmark,x,z): continue
			var s := site.at(x,z)
			var density := flowering.meadow_at(x,z,s)
			if density < 0.12 or rf.next() > density*1.8: continue
			var near := false
			for o in spots:
				if _hypot(o.x-x,o.z-z) < 0.85:
					near = true
					break
			if not near:
				for o in b_spots:
					if _hypot(o.x-x,o.z-z) < 0.9:
						near = true
						break
			if near: continue
			var n: float = fbm.call(x*0.22+113.0,z*0.22-51.0)
			var band := 0 if n < 0.43 else (1 if n < 0.59 else 2)
			var form: String = "daisy" if band == 0 else ("spike" if band == 1 else "umbel")
			var rot := rf.next()*PI*2.0
			var size := height*(0.75+rf.next()*0.55)
			f_spots[form].append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size,"stem":2.1 if form == "spike" else (1.15 if form == "daisy" else 1.0),"c":_hex(palette[band])})
			planted += 1
	var cushions := 0
	tries = 0
	while cushions < int(U.get("cushionPatches",0)) and tries < 6000*AREA:
		tries += 1
		var cx := (r_flower.next()-0.5)*(S-4.0)
		var cz := (r_flower.next()-0.5)*(S-4.0)
		var c := site.at(cx,cz)
		if c.slope > 0.6 or c.shore < 0.6: continue
		if c.alpine01 < 0.45 or c.alpine01 > 1.05: continue
		cushions += 1
		var h := fmod(flower_hue + 0.5 + cushions*0.23 + r_flower.next()*0.05,1.0)
		var s := 0.7+r_flower.next()*0.25
		var l := 0.62+r_flower.next()*0.12
		hue = _set_hsl(h,s,l)
		var radius := 0.45+r_flower.next()*0.6
		for k in range(int(round(flower_per*1.5))):
			var rr := radius*pow(r_flower.next(),0.65)
			var a := r_flower.next()*PI*2.0
			var x := cx+cos(a)*rr
			var z := cz+sin(a)*rr
			var site_k := site.at(x,z)
			if site_k.slope > 0.55 or site_k.shore < 0.3 or site_k.tree01 > 99.0: continue
			var rot := r_flower.next()*PI*2.0
			var size := 0.5*(0.7+r_flower.next()*0.6)
			f_spots.button.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size,"stem":1.0,"c":hue.duplicate()})
	for form in FLOWER_FORMS:
		for spot in f_spots[form]:
			out.append(_entry(FLOWER_KINDS[form],_upright(spot.x,spot.h-0.02,spot.z,spot.rot,spot.s,spot.s,spot.s),spot.c))

	# --- the litter ----------------------------------------------------------
	var r_litter := Rng.new(seed ^ 0x1f83d9ab)
	var woody: Array = spots + b_spots
	var l_spots: Array = []
	tries = 0
	while l_spots.size() < int(U.get("logCount",0)) and tries < 9000*AREA:
		tries += 1
		var x := (r_litter.next()-0.5)*(S-4.0)
		var z := (r_litter.next()-0.5)*(S-4.0)
		if not _crowded(woody,x,z,3.0): continue
		var s := site.at(x,z)
		if s.slope > 0.7: continue
		if s.shore < 0.8: continue
		if s.tree01 > 1.05: continue
		var length := 1.3+r_litter.next()*1.5
		var r := 0.15+r_litter.next()*0.09
		var yaw := r_litter.next()*PI*2.0
		var dx := cos(yaw)
		var dz := -sin(yaw)
		var blocked := false
		for t in [-0.5,0.0,0.5]:
			if _crowded(woody,x+dx*length*t,z+dz*length*t,0.75):
				blocked = true
				break
		if blocked or _crowded(l_spots,x,z,2.2): continue
		var h1: float = ground.call(x-dx*length*0.5,z-dz*length*0.5)
		var h2: float = ground.call(x+dx*length*0.5,z+dz*length*0.5)
		var fits := true
		for t in [-0.3,-0.15,0.0,0.15,0.3]:
			var line: float = (h1+h2)*0.5+(h2-h1)*t
			var floor_h: float = ground.call(x+dx*length*t,z+dz*length*t)
			if line-floor_h > 0.4*r or floor_h-line > 0.7*r:
				fits = false
				break
		if not fits: continue
		l_spots.append({"x":x,"z":z,"h":(h1+h2)*0.5,"yaw":yaw,"pitch":atan2(h2-h1,length),"len":length,"r":r,"site":s})
	var t_spots: Array = []
	tries = 0
	while t_spots.size() < int(U.get("stumpCount",0)) and tries < 6000*AREA:
		tries += 1
		var x := (r_litter.next()-0.5)*(S-4.0)
		var z := (r_litter.next()-0.5)*(S-4.0)
		if not _crowded(woody,x,z,3.2): continue
		var s := site.at(x,z)
		if s.slope > 0.65: continue
		if s.shore < 0.8: continue
		if s.tree01 > 1.0: continue
		if _crowded(woody,x,z,0.9) or _crowded(t_spots,x,z,2.5): continue
		if not _clear_of_logs(l_spots,x,z,0.5): continue
		var rot := r_litter.next()*PI*2.0
		var size := 0.8+r_litter.next()*0.5
		t_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"s":size,"site":s})
	var n_spots: Array = []
	tries = 0
	while n_spots.size() < int(U.get("snagCount",0)) and tries < 9000*AREA:
		tries += 1
		var x := (r_litter.next()-0.5)*(S-3.0)
		var z := (r_litter.next()-0.5)*(S-3.0)
		var s := site.at(x,z)
		if s.slope > 0.75: continue
		if s.shore < 1.0: continue
		if s.tree01 > 1.2: continue
		var band: float = smoothstep(0.55,0.95,s.tree01)*(0.4+0.6*s.exposure)
		var among := 0.22 if _crowded(woody,x,z,2.6) else 0.0
		if r_litter.next() > maxf(band,among): continue
		if kind_sand > 0.5 and s.moisture < 0.4: continue
		if _crowded(woody,x,z,1.5) or _crowded(n_spots,x,z,2.4): continue
		if not _clear_of_logs(l_spots,x,z,0.5) or _crowded(t_spots,x,z,0.8): continue
		var stunt: float = smoothstep(0.55,1.0,s.tree01)
		var rot := r_litter.next()*PI*2.0
		var lean := r_litter.next()*0.14
		var lean_dir := r_litter.next()*PI*2.0
		var sy := (2.6+r_litter.next()*1.6)*(1.0-0.45*stunt)
		var sx := 0.9+r_litter.next()*0.4
		n_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"lean":lean,"leanDir":lean_dir,"sy":sy,"sx":sx,"site":s})
	var m_spots: Array = []
	var hosts: Array = []
	for o in b_spots: hosts.append({"x":o.x,"z":o.z,"site":o.site,"r":0.3*o.sx,"log":null})
	for o in spots: hosts.append({"x":o.x,"z":o.z,"site":o.site,"r":0.42*o.s,"log":null})
	for o in l_spots: hosts.append({"x":o.x,"z":o.z,"site":o.site,"r":o.r+0.05,"log":o})
	var clusters := 0
	var t := 0
	while not hosts.is_empty() and clusters < int(U.get("fungusClusters",0)) and t < 400:
		t += 1
		var host: Dictionary = hosts[int(floor(r_litter.next()*hosts.size()))]
		if host.site.moisture < 0.45: continue
		if r_litter.next() > smoothstep(0.45,0.8,host.site.moisture): continue
		if _crowded(m_spots,host.x,host.z,3.0): continue
		clusters += 1
		var roll := r_litter.next()
		var base: String = "#b4642f" if roll < 0.42 else ("#d9c9a0" if (roll < 0.84 or host.site.alpine01 > 0.6) else "#b03a2c")
		var n := 3+int(floor(r_litter.next()*5.0))
		for i in range(n):
			var a := r_litter.next()*PI*2.0
			var d: float = host.r+0.05+r_litter.next()*0.35
			var x: float = host.x+cos(a)*d
			var z: float = host.z+sin(a)*d
			if host.log != null:
				var log: Dictionary = host.log
				var t2: float = (r_litter.next()-0.5)*log.len*0.8
				var side_sign := -1.0 if r_litter.next() < 0.5 else 1.0
				var side: float = side_sign*(log.r+0.05+r_litter.next()*0.2)
				var dx := cos(log.yaw)
				var dz := -sin(log.yaw)
				x = host.x + dx*t2 - dz*side
				z = host.z + dz*t2 + dx*side
			var s := site.at(x,z)
			if s.shore < 0.2 or s.slope > 0.8: continue
			var a1 := (r_litter.next()-0.5)*0.03
			var b1 := (r_litter.next()-0.5)*0.1
			var c1 := (r_litter.next()-0.5)*0.12
			var cap := _offset_hsl(_hex(base),a1,b1,c1)
			var rot := r_litter.next()*PI*2.0
			var tilt := r_litter.next()*0.25
			var size := 0.55+r_litter.next()*0.75
			m_spots.append({"x":x,"z":z,"h":ground.call(x,z),"rot":rot,"tilt":tilt,"s":size,"c":cap})
	# logGeometry draws from the litter stream before the log tints
	r_litter.next()
	var stubs := 2+int(floor(r_litter.next()*2.0))
	r_litter.skip(stubs*5)
	for spot in l_spots:
		var q := _quat_mul(_quat(Vector3.UP,spot.yaw),_quat(Vector3(0,0,1),spot.pitch))
		var m := _compose(spot.x,spot.h+spot.r*0.55,spot.z,q,spot.len,spot.r/0.16,spot.r/0.16)
		var wet: float = spot.site.moisture
		var a := 0.02*wet + (r_litter.next()-0.5)*0.02
		var b := 0.1*wet
		var c := -0.12*wet + (r_litter.next()-0.5)*0.08
		out.append(_entry("log",m,_offset_hsl([1.0,1.0,1.0],a,b,c)))
	for spot in t_spots:
		var m := _upright(spot.x,spot.h-0.02,spot.z,spot.rot,spot.s,spot.s,spot.s)
		var c: float = -0.1*spot.site.moisture + (r_litter.next()-0.5)*0.08
		out.append(_entry("stump",m,_offset_hsl([1.0,1.0,1.0],0.0,0.0,c)))
	# snagGeometry draws before the snag tints
	var limbs := 3+int(floor(r_litter.next()*3.0))
	r_litter.skip(limbs*4)
	for spot in n_spots:
		var q := _quat_mul(_quat_mul(_quat(Vector3.UP,spot.leanDir),_quat(Vector3(1,0,0),spot.lean)),_quat(Vector3.UP,spot.rot-spot.leanDir))
		var m := _compose(spot.x,spot.h-0.05,spot.z,q,spot.sx,spot.sy,spot.sx)
		var exposure: float = spot.site.exposure
		var c: float = 0.08*exposure - 0.06*spot.site.moisture + (r_litter.next()-0.5)*0.06
		out.append(_entry("snag",m,_offset_hsl([1.0,1.0,1.0],0.0,-0.05*exposure,c)))
	for spot in m_spots:
		var q := _quat_mul(_quat(Vector3.UP,spot.rot),_quat(Vector3(1,0,0),spot.tilt))
		out.append(_entry("mushroom",_compose(spot.x,spot.h-0.01,spot.z,q,spot.s,spot.s,spot.s),spot.c))

	# --- the genome's rim boulders (source terrain.js) -----------------------
	var index := 0
	for boulder in g.get("boulders",[]):
		index += 1
		var rx: float = boulder.x
		var rz: float = boulder.z
		var size: float = boulder.s
		var bx := rx
		var bz := rz
		var ok := false
		if boulder.get("flank",false):
			ok = _analytic_slope(ground,bx,bz) < 2.2
		else:
			for step in range(5):
				var tt := step*0.14
				bx = rx + (float(pool.x)-rx)*tt
				bz = rz + (float(pool.z)-rz)*tt
				if _analytic_slope(ground,bx,bz) < 1.5:
					ok = true
					break
		if not ok: continue
		if absf(bx) > S/2.0-size or absf(bz) > S/2.0-size: continue
		var m := PackedFloat64Array([1,0,0,0,0,1,0,0,0,0,1,0,bx,ground.call(bx,bz)+size*0.4,bz,1])
		out.append(_entry("boulder_%d" % index,m,null,true))
	return out

static func _analytic_slope(ground: Callable, x: float, z: float) -> float:
	var e := 0.25
	var dx: float = ground.call(x+e,z) - ground.call(x-e,z)
	var dz: float = ground.call(x,z+e) - ground.call(x,z-e)
	return _hypot(dx,dz)/(2.0*e)
static func _skip_shrub_geometry(r: Rng) -> void:
	var n := 3+int(floor(r.next()*2.0))
	r.skip(n*4)
static func _clear_of_logs(logs: Array, x: float, z: float, gap: float) -> bool:
	for o in logs:
		var dx: float = cos(o.yaw)
		var dz: float = -sin(o.yaw)
		for t in [-0.4,-0.2,0.0,0.2,0.4]:
			var px: float = o.x + dx*o.len*t - x
			var pz: float = o.z + dz*o.len*t - z
			var g2: float = (gap+o.r)*(gap+o.r)
			if px*px+pz*pz < g2: return false
	return true
