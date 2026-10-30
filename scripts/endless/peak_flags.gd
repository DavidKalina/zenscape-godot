## The climbers' flags on the Peak (docs/design/endless-flight/spec-crown.md,
## lane flags): strings of weathered cloth on a sagging rope, single pennants
## on leaning poles, a cairn at a pole's foot. One mesh, one surface, one
## shader (shaders/peak_flags.gdshader), no colliders; everything that moves
## moves in the shader, on the land's wind (zs_wind_direction,
## zs_wind_strength, zs_motion_time), so past the build this costs no CPU.
##
## The trunk's API:
##   var flags := PeakFlags.new(); add_child(flags)
##   flags.add_string(a, b, sag, {opts})      a string from A to B
##   flags.add_pole(p, {opts})                a pole at P; returns its top
##   flags.commit()                           builds the mesh (once, after the adds)
## `setup` hangs the lane's proof strings on today's stair and cirque.
extends Node3D

const PeakMassif = preload("res://scripts/endless/peak_massif.gd")
const FlagShader = preload("res://shaders/peak_flags.gdshader")

## A cloth's rows (attached to free; the shader's ROWS) and columns.
const ROWS := 10
const COLS := 4
## Metres between a rope's points.
const ROPE_STEP := 4.0
## The climbers' dye, each a linear albedo, in the order a string repeats: a
## dull indigo, bone, oxblood, lichen, old ochre.
const DYES := [Color(0.075,0.1,0.17),Color(0.52,0.47,0.37),Color(0.2,0.055,0.04),Color(0.17,0.2,0.14),Color(0.38,0.25,0.085)]
## Hemp and wood, weathered.
const ROPE := Color(0.21,0.175,0.13)
const WOOD := Color(0.16,0.125,0.09)
## Cairn stone.
const STONE := Color(0.25,0.24,0.225)
## How fast a gust runs through (m/s), and which way: fixed at the build (the
## land's wind turns slowly, and a string shows only that a gust runs along it).
const GUST_SPEED := 22.0
const GUST_WAY := Vector2(0.8,0.6)
## The baked gusts: the shader's GUST_N texels, GUST_DT s each.
const GUST_N := 512
const GUST_DT := 0.25

## Where the strings hang, for stills: {a, b, sag}, world.
var hung: Array = []
## The poles' tops, for stills.
var tops: Array = []
## Build counters: strings, poles, cloths, verts, tris, build_ms.
var stats := {"strings":0, "poles":0, "cloths":0, "verts":0, "tris":0, "build_ms":0.0}

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _col := PackedColorArray()
var _c0 := PackedFloat32Array()
var _c1 := PackedFloat32Array()
var _ix := PackedInt32Array()
var _box := AABB()
var _rng := RandomNumberGenerator.new()
var _strings := 0
var _poles := 0
var _cloths := 0

func _init() -> void:
	name = "PeakFlags"
	_rng.seed = hash("peak/flags")

## Hangs the proof strings (the trunk replaces this with its own adds).
func setup(peak: RefCounted, ground: Callable, seed_value: int, stair: Node3D = null) -> void:
	_rng.seed = hash([seed_value,"peak/flags"])
	var t0 := Time.get_ticks_usec()
	_proof_stair(peak,ground,stair)
	_proof_rim(peak,ground)
	commit()
	stats.build_ms = (Time.get_ticks_usec()-t0)/1000.0

## A string of flags on a rope from `a` to `b`, sagging `sag` m at its middle
## (below 0: 6% of the span). Opts, all optional:
##   width (3.4), length (4.2)   a cloth (m)
##   gap (0.9)                   rope between cloths (m)
##   missing (0.14)              the share of cloths gone
##   wear (0.5)                  how worn the string is, 0..1
##   tails (true)                a frayed end of rope hanging at each end
##   ends (6.0)                  bare rope kept at each end (m)
##   seed
func add_string(a: Vector3, b: Vector3, sag := -1.0, opts := {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed",_rng.randi()))
	var span := a.distance_to(b)
	if span < 1.0: return
	if sag < 0.0: sag = span*0.06
	var swing := clampf(sag*0.32+span*0.012,0.3,7.0)
	var jitter := rng.randf()*0.6
	var at := func(t: float) -> Vector3:
		return a.lerp(b,t)+Vector3.DOWN*(sag*4.0*t*(1.0-t))
	var weight := func(t: float) -> float:
		return 4.0*t*(1.0-t)*swing
	# The rope.
	var n := maxi(2,int(ceil(span/ROPE_STEP)))
	var start := _v.size()
	for k in n+1:
		var t := float(k)/n
		var p: Vector3 = at.call(t)
		var q: Vector3 = at.call(minf(t+0.01,1.0))
		var r: Vector3 = at.call(maxf(t-0.01,0.0))
		var way := (q-r).normalized()
		for side: float in [-1.0,1.0]:
			_vert(p,way,Vector2(side,t*span),Vector2(2.0,0.0),ROPE,_delay(p)+jitter,float(weight.call(t)),t*span,rng.randf(),[0.045,0.0,0.0,0.0])
		if k > 0:
			var i := start+(k-1)*2
			_quad(i,i+1,i+3,i+2)
	# The cloths.
	var width: float = opts.get("width",3.4)
	var length: float = opts.get("length",4.2)
	var gap: float = opts.get("gap",0.9)
	var ends: float = opts.get("ends",6.0)
	var wear: float = opts.get("wear",0.5)
	var missing: float = opts.get("missing",0.14)
	var pitch := width+gap
	var count := int((span-ends*2.0)/pitch)
	var from := (span-count*pitch+gap)*0.5
	var first_dye := rng.randi()%DYES.size()
	for i in count:
		var dye: Color = DYES[(first_dye+i)%DYES.size()]
		if rng.randf() < missing: continue
		var w := width*rng.randf_range(0.92,1.04)
		var h := length*rng.randf_range(0.82,1.08)
		var worn := clampf(wear+rng.randf_range(-0.3,0.35),0.05,1.0)
		if rng.randf() < 0.14:
			# Rotted short.
			h *= rng.randf_range(0.45,0.7)
			worn = maxf(worn,0.75)
		var t0 := (from+i*pitch)/span
		var t1 := (from+i*pitch+w)/span
		var dye_at := Color(dye.r,dye.g,dye.b,clampf(rng.randf_range(0.15,0.8)+0.3*(wear-0.5),0.0,1.0))
		var seed01 := rng.randf()
		var way: Vector3 = (Vector3(at.call(t1))-Vector3(at.call(t0))).normalized()
		var tied_by_one := rng.randf() < 0.07
		var spread := 0.0
		var first := _v.size()
		for c in COLS+1:
			var cu := float(c)/COLS
			var t := lerpf(t0,t1,cu)
			if tied_by_one:
				# One tie gone: it hangs from a corner, opening to its full width.
				t = lerpf(t0,t0+0.4/span,cu)
				spread = w-0.4
			var p: Vector3 = at.call(t)
			for r in ROWS+1:
				var ts := float(r)/ROWS
				_vert(p,way,Vector2(cu,ts),Vector2(0.0,0.0),dye_at,_delay(p)+jitter,float(weight.call(t)),t*span,seed01,[w,h,spread,worn])
		_grid(first)
		_cloths += 1
	if bool(opts.get("tails",true)):
		_tail(a,(b-a).normalized(),_delay(a)+jitter,rng)
		_tail(b,(a-b).normalized(),_delay(b)+jitter,rng)
	_grow(a,maxf(length,swing)+sag+2.0)
	_grow(b,maxf(length,swing)+sag+2.0)
	_grow(at.call(0.5),length+swing+2.0)
	hung.append({"a":a,"b":b,"sag":sag})
	_strings += 1

## A leaning pole at `p` (its foot, on the ground) with a pennant at its top.
## Returns the top's point, for a string to tie to. Opts, all optional:
##   height (24.0), lean (degrees, 3..11), lean_way (a Vector2; random)
##   radius (0.22)
##   hoist (3.4), fly (10.0)     the pennant: along the pole, and its length (m)
##   pennant (true), cairn (true)
##   wear (0.5), seed
func add_pole(p: Vector3, opts := {}) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed",_rng.randi()))
	var height: float = opts.get("height",24.0)
	var radius: float = opts.get("radius",0.22)
	var lean := deg_to_rad(float(opts.get("lean",rng.randf_range(3.0,11.0))))
	var a0 := rng.randf()*TAU
	var lean_way: Vector2 = opts.get("lean_way",Vector2(cos(a0),sin(a0)))
	lean_way = lean_way.normalized()
	var axis := (Vector3.UP*cos(lean)+Vector3(lean_way.x,0.0,lean_way.y)*sin(lean)).normalized()
	var foot := p-axis*2.0
	var top := p+axis*height
	var start := _v.size()
	var n := 5
	var bow := rng.randf_range(0.2,0.6)
	var at := func(t: float) -> Vector3:
		return foot.lerp(top,t)+Vector3(-lean_way.y,0.0,lean_way.x)*bow*sin(t*PI)
	var sw := height*0.015
	for k in n+1:
		var t := float(k)/n
		var q: Vector3 = at.call(t)
		for side: float in [-1.0,1.0]:
			_vert(q,axis,Vector2(side,t*height),Vector2(3.0,0.0),WOOD,_delay(q),sw*t*t,0.0,rng.randf(),[radius*lerpf(1.0,0.6,t),0.0,0.0,0.0])
		if k > 0:
			var i := start+(k-1)*2
			_quad(i,i+1,i+3,i+2)
	if bool(opts.get("pennant",true)):
		var hoist: float = opts.get("hoist",3.4)
		var fly: float = opts.get("fly",10.0)
		var wear: float = opts.get("wear",0.5)
		var dye: Color = DYES[rng.randi()%DYES.size()]
		dye.a = rng.randf_range(0.15,0.75)
		var seed01 := rng.randf()
		var first := _v.size()
		for c in COLS+1:
			var cu := float(c)/COLS
			var q := top-axis*(0.3+hoist*(1.0-cu))
			for r in ROWS+1:
				_vert(q,axis,Vector2(cu,float(r)/ROWS),Vector2(1.0,0.0),dye,_delay(q),sw,0.0,seed01,[hoist,fly,-hoist*0.55,wear])
		_grid(first)
		_cloths += 1
		_grow(top,fly+2.0)
	if bool(opts.get("cairn",true)): _cairn(p,rng)
	_grow(p,4.0)
	_grow(top,3.0)
	tops.append(top)
	_poles += 1
	return top

## Builds the mesh from everything added. Call once after the adds.
func commit() -> void:
	if _ix.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_COLOR] = _col
	arrays[Mesh.ARRAY_CUSTOM0] = _c0
	arrays[Mesh.ARRAY_CUSTOM1] = _c1
	arrays[Mesh.ARRAY_INDEX] = _ix
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
	mesh.custom_aabb = _box
	var mat := ShaderMaterial.new()
	mat.shader = FlagShader
	var gust := _gust_texture(int(_rng.randi()))
	mat.set_shader_parameter("gust_tex",gust.texture)
	mat.set_shader_parameter("gust_dt",GUST_DT)
	mat.set_shader_parameter("gust_cycles",gust.cycles)
	var inst := MeshInstance3D.new()
	inst.name = "Flags"
	inst.mesh = mesh
	inst.material_override = mat
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(inst)
	stats.strings = _strings
	stats.poles = _poles
	stats.cloths = _cloths
	stats.verts = _v.size()
	stats.tris = _ix.size()/3

# --- The gusts ---------------------------------------------------------------

## The baked gusts (the shader's header says what each channel is): a loop of
## GUST_N * GUST_DT seconds of gusts at uneven gaps, a sharp rise and a slower
## fall on a slowly breathing air, with the two springs' answers and the
## integrated phase worked out here, once. {texture, cycles}.
static func _gust_texture(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var loop := GUST_N*GUST_DT
	var onsets := PackedFloat32Array()
	var powers := PackedFloat32Array()
	var t := rng.randf_range(0.0,3.0)
	while t < loop-1.5:
		onsets.append(t)
		powers.append(rng.randf_range(0.35,1.0))
		t += rng.randf_range(1.8,8.5)+(rng.randf_range(4.0,9.0) if rng.randf() < 0.22 else 0.0)
	var air := func(x: float) -> float:
		var g := 0.2+0.1*sin(TAU*x/loop*3.0)+0.06*sin(TAU*x/loop*7.0+1.3)
		for i in onsets.size():
			for shift: float in [-loop,0.0]:
				var age: float = x-(onsets[i]+shift)
				if age < 0.0 or age > 14.0: continue
				g += powers[i]*smoothstep(0.0,0.3,age)*exp(-age/1.9)
		return minf(g,1.2)
	var dt := 1.0/120.0
	var steps := int(round(GUST_DT/dt))
	var lift := 0.3
	var lift_v := 0.0
	var rope := 0.3
	var rope_v := 0.0
	var data := PackedFloat32Array()
	data.resize(GUST_N*4)
	var phase := 0.0
	var since := 0.0
	# Twice round: the first lap settles the springs so the loop closes.
	for lap in 2:
		phase = 0.0
		for i in GUST_N:
			var x := i*GUST_DT
			var onset := -1.0
			for k in onsets.size():
				if onsets[k] >= x and onsets[k] < x+GUST_DT: onset = onsets[k]
			if onset >= 0.0: since = 0.0
			if lap == 1:
				data[i*4] = lift
				data[i*4+1] = phase
				data[i*4+2] = since
				data[i*4+3] = rope
			for _s in steps:
				var g: float = air.call(x)
				lift_v += ((g-lift)*46.0-lift_v*7.5)*dt
				lift += lift_v*dt
				rope_v += ((g-rope)*2.4-rope_v*1.1)*dt
				rope += rope_v*dt
				phase += (0.55+2.2*clampf(lift,0.0,1.1))*dt
			since += GUST_DT
	var cycles := roundf(phase)
	var scale_to := cycles/phase
	for i in GUST_N: data[i*4+1] *= scale_to
	var image := Image.create_from_data(GUST_N,1,false,Image.FORMAT_RGBAF,data.to_byte_array())
	return {"texture":ImageTexture.create_from_image(image),"cycles":cycles}

# --- Writing the mesh --------------------------------------------------------

func _vert(p: Vector3, n: Vector3, uv: Vector2, uv2: Vector2, c: Color, delay: float, swing: float, along: float, seed01: float, c1: Array) -> void:
	_v.append(p)
	_n.append(n)
	_uv.append(uv)
	_uv2.append(uv2)
	_col.append(c)
	_c0.append(delay)
	_c0.append(swing)
	_c0.append(along)
	_c0.append(seed01)
	for x: float in c1: _c1.append(x)

func _quad(a: int, b: int, c: int, d: int) -> void:
	_ix.append(a)
	_ix.append(b)
	_ix.append(c)
	_ix.append(a)
	_ix.append(c)
	_ix.append(d)

## Indices for a cloth's (COLS+1) x (ROWS+1) grid starting at `first`.
func _grid(first: int) -> void:
	for c in COLS:
		for r in ROWS:
			var i := first+c*(ROWS+1)+r
			_quad(i,i+1,i+ROWS+2,i+ROWS+1)

func _grow(p: Vector3, reach: float) -> void:
	var b := AABB(p-Vector3.ONE*reach,Vector3.ONE*reach*2.0)
	_box = b if _box.size == Vector3.ZERO else _box.merge(b)

## When a gust reaches `p` (s), so a string takes it from one end to the other.
func _delay(p: Vector3) -> float:
	return (p.x*GUST_WAY.x+p.z*GUST_WAY.y)/GUST_SPEED

## A frayed end of rope: a thin plain cloth hanging off the anchor.
func _tail(p: Vector3, along_rope: Vector3, delay: float, rng: RandomNumberGenerator) -> void:
	var at := p+along_rope*rng.randf_range(0.2,0.8)
	var c := Color(ROPE.r*1.4,ROPE.g*1.4,ROPE.b*1.4,0.5)
	var long := rng.randf_range(2.5,7.0)
	var seed01 := rng.randf()
	var first := _v.size()
	for cn in COLS+1:
		var cu := float(cn)/COLS
		for r in ROWS+1:
			_vert(at+along_rope*(cu-0.5)*0.25,along_rope,Vector2(cu,float(r)/ROWS),Vector2(0.0,0.0),c,delay,0.0,0.0,seed01,[0.25,long,0.1,-0.75])
	_grid(first)
	_grow(at,long+1.0)

## A cairn round a pole's foot: flat slabs stacked by hand, wide at the bottom,
## each course smaller and turned off the last.
func _cairn(p: Vector3, rng: RandomNumberGenerator) -> void:
	var y := -0.5
	var courses := rng.randi_range(4,6)
	for k in courses:
		var t := float(k)/courses
		var wide := lerpf(2.5,0.9,t)
		var count := 4 if k < courses-2 else 3
		var thick := rng.randf_range(0.34,0.55)
		for i in count:
			var a := (i+rng.randf_range(-0.2,0.2))/count*TAU+k*0.7
			var c := p+Vector3(cos(a)*wide*0.6,y+thick*0.5,sin(a)*wide*0.6)
			_slab(c,Vector3(wide*rng.randf_range(0.5,0.75),thick,wide*rng.randf_range(0.4,0.6)),a+rng.randf_range(-0.4,0.4),rng)
		y += thick*0.9

## One slab: a box of `size`, turned `yaw`, its corners knocked about, its
## faces flat.
func _slab(c: Vector3, size: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP,yaw).rotated(Vector3.RIGHT,rng.randf_range(-0.09,0.09))
	var corners: Array[Vector3] = []
	for i in 8:
		var d := Vector3(1.0 if i&1 else -1.0,1.0 if i&2 else -1.0,1.0 if i&4 else -1.0)*0.5
		var k := Vector3(rng.randf_range(0.8,1.1),rng.randf_range(0.8,1.15),rng.randf_range(0.8,1.1))
		corners.append(c+b*(d*size*k))
	var tint := STONE*rng.randf_range(0.75,1.3)
	tint.a = 0.0
	for f: Array in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
		var p0: Vector3 = corners[f[0]]
		var n := (Vector3(corners[f[2]])-p0).cross(Vector3(corners[f[1]])-p0).normalized()
		var first := _v.size()
		for q: int in f:
			_vert(corners[q],n,Vector2.ZERO,Vector2(4.0,0.0),tint,0.0,0.0,0.0,0.0,[0.0,0.0,0.0,0.0])
		_quad(first,first+1,first+2,first+3)

# --- The proof strings (the trunk places the real ones) ----------------------

## Strings up the stair, post to post along its flank, and one across the
## couloir over it.
func _proof_stair(peak: RefCounted, ground: Callable, stair: Node3D) -> void:
	if stair == null: return
	var flights: Array = stair.get("flights")
	if flights.size() < 8: return
	var side := 1.0
	var k := 2
	var strings := 0
	while k+4 < flights.size() and strings < 4:
		var f0: Dictionary = flights[k]
		var f1: Dictionary = flights[k+3]
		var a := _flank(f0,side,ground)
		var b := _flank(f1,side,ground)
		var ta := add_pole(a,{"height":15.0,"lean":4.0})
		var tb := add_pole(b,{"height":15.0,"lean":4.0})
		add_string(ta,tb,-1.0,{"wear":0.45+0.15*strings})
		k += 5
		strings += 1
		side = -side
	# One high across the slot, wall to wall.
	var a_at := lerpf(PeakMassif.COULOIR_FOOT.x,PeakMassif.COULOIR_TOP.x,0.45)
	var half: float = float(peak.couloir().half_width)*1.05
	var mid := PeakMassif._couloir_mid(a_at)
	var w0: Vector2 = peak.world(a_at,mid-half)
	var w1: Vector2 = peak.world(a_at,mid+half)
	var p0 := Vector3(w0.x,float(ground.call(w0.x,w0.y))+4.0,w0.y)
	var p1 := Vector3(w1.x,float(ground.call(w1.x,w1.y))+4.0,w1.y)
	add_string(p0,p1,-1.0,{"wear":0.7,"tails":false,"width":4.4,"length":6.0})

## A flight's flank at `side` (+1, -1), on the ground.
func _flank(f: Dictionary, side: float, ground: Callable) -> Vector3:
	var xf: Transform3D = f.xf
	var p := xf.origin+xf.basis.x.normalized()*side*(float(f.half)*8.0+2.5)
	return Vector3(p.x,float(ground.call(p.x,p.z)),p.z)

## Strings along the cirque's rim, away from the head, and a pole between
## each, with one pennant on its own.
func _proof_rim(peak: RefCounted, ground: Callable) -> void:
	var angles: Array = [1.9,2.3,2.75,3.25,3.75,4.2]
	var rim: Array[Vector3] = []
	for phi: float in angles:
		var rho: float = peak._cq_r(phi)
		var w: Vector2 = peak.world(rho*cos(phi),rho*sin(phi))
		var p := Vector3(w.x,float(ground.call(w.x,w.y)),w.y)
		rim.append(add_pole(p,{"height":18.0,"pennant":rim.size()%2 == 0}))
	for i in rim.size()-1:
		add_string(rim[i],rim[i+1],-1.0,{"wear":0.35+0.1*i})
