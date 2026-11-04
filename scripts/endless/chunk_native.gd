extends RefCounted
## A land chunk's build past the field in C++ (native/terrain_kernels/
## chunk_pass_bind.h): each tunnel site's carve (ZenScapeTunnelCarve, made
## when the site is made, tunnel_sites.gd `go_native`) and the passes over a
## chunk's arrays (ZenScapeChunkPass: the tunnels' pass, the river's channel
## frame and its ring of samples, the rock's shape, the portals' holes).
## The GDScript stays the reference and the fallback: `--chunk-native=0`,
## `--land-native=0` or `--gdscript-kernels`, no library, or one older than
## the versions here.

const Ponds = preload("res://scripts/endless/land_ponds.gd")
const CARVE_CLASS := &"ZenScapeTunnelCarve"
const PASS_CLASS := &"ZenScapeChunkPass"
const CARVE_VERSION := 1
const PASS_VERSION := 1

static var _state := -1
static var _lock := Mutex.new()
static var _pass: Object = null

## Whether the flags and the library allow the native chunk passes.
static func wanted() -> bool:
	if _state >= 0: return _state == 1
	_lock.lock()
	if _state < 0:
		var ok := true
		for a: String in preload("res://scripts/launch_args.gd").user_args():
			if a == "--chunk-native=0" or a == "--land-native=0" or a == "--gdscript-kernels": ok = false
		if ok:
			var path := "res://native/terrain_kernels/zenscape_kernels.gdextension"
			if not ClassDB.class_exists(CARVE_CLASS) and FileAccess.file_exists(path): GDExtensionManager.load_extension(path)
			ok = _version(CARVE_CLASS) == CARVE_VERSION and _version(PASS_CLASS) == PASS_VERSION
		if ok:
			_pass = ClassDB.instantiate(PASS_CLASS)
			var Tunnels: Script = load("res://scripts/endless/tunnel_sites.gd")
			_pass.setup(Tunnels.get_script_constant_map())
			_pass.setup_ponds((load("res://scripts/endless/land_ponds.gd") as Script).get_script_constant_map())
		_state = 1 if ok else 0
	_lock.unlock()
	return _state == 1

static func _version(cls: StringName) -> int:
	if not ClassDB.class_exists(cls): return 0
	var probe: Object = ClassDB.instantiate(cls)
	return int(probe.version()) if probe.has_method("version") else 0

## The shared pass (read only after setup), or null.
static func pass_kernel() -> Object:
	return _pass if wanted() else null

## A tunnel site's carve from its pack (tunnel_sites.gd `native_pack`).
static func tunnel_carve(pack: Dictionary, consts: Dictionary) -> Object:
	if not wanted(): return null
	var c: Object = ClassDB.instantiate(CARVE_CLASS)
	c.setup(pack,consts)
	return c

## A FastNoiseLite's settings for the native twin ({} for none).
static func noise_pack(n: FastNoiseLite) -> Dictionary:
	if n == null: return {}
	if n.domain_warp_enabled or n.offset != Vector3.ZERO: push_warning("chunk_native: a noise with warp or offset; the native carve ignores them")
	return {"seed":n.seed,"noise_type":n.noise_type,"frequency":n.frequency,"fractal_type":n.fractal_type,
		"fractal_octaves":n.fractal_octaves,"fractal_lacunarity":n.fractal_lacunarity,"fractal_gain":n.fractal_gain,
		"fractal_weighted_strength":n.fractal_weighted_strength,"fractal_ping_pong_strength":n.fractal_ping_pong_strength}

## The native carves of tunnel sites `ts`, or empty when any lacks one.
static func carves_of(ts: Array) -> Array:
	var out: Array = []
	for t: RefCounted in ts:
		if t.native == null: return []
		out.append(t.native)
	return out

## The native field that alone shapes the land over the box (x0, z0)..(x1, z1)
## but for the tunnels there (no pond, hall or split reaches it, nor the Peak
## or the isles), and those tunnels' native carves: [field, carves], or []
## where the box needs LandField's own sampling. With the ponds there by
## their square (LandField `_pond_for`): [field, carves, cells, ponds]; a
## grid read off the field alone needs carves and ponds empty.
static func plain_in(f: RefCounted, x0: float, z0: float, x1: float, z1: float) -> Array:
	if not wanted(): return []
	var kid: Object = f.native_impl_in(x0,z0,x1,z1)
	if kid == null: return []
	if not (f.halls_in(x0,z0,x1,z1) as Array).is_empty(): return []
	if not (f.splits_in(x0,z0,x1,z1) as Array).is_empty(): return []
	var ts: Array = f.tunnels_in(x0,z0,x1,z1)
	var cs := carves_of(ts)
	if cs.size() != ts.size(): return []
	# The ponds by their square, as LandField `_pond_for` finds them.
	var cells := PackedInt32Array()
	var ps: Array = []
	if f.ponds > 0.0 and not (f.ponds_in(x0,z0,x1,z1) as Array).is_empty():
		var size: float = Ponds.CELL
		for cj in range(floori(z0/size),floori(z1/size)+1):
			for ci in range(floori(x0/size),floori(x1/size)+1):
				var p: PackedFloat32Array = f._pond_for((ci+0.5)*size,(cj+0.5)*size)
				if p.is_empty(): continue
				cells.append_array([ci,cj])
				ps.append(p)
	return [kid,cs,cells,ps]
