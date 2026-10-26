extends RefCounted
## Where the endless land's free-standing rock shapes stand (docs/design/
## endless-flight/rock-shapes-handoff.md): the one registry every kind of
## true-3D rock shape (sea stacks, hoodoos, ...) plugs into. A pure function
## of the seed and a world cell, like scripts/endless/arch_plan.gd, so every
## run, every worker and the trees' planner place the same rocks.
##
## A kind is a script in scripts/endless/rocks/ (rock_kind.gd has the
## contract) listed in KINDS under its layer's name. `plan(field, cx, cz,
## densities)` asks each kind with a density over 0 for the cell's groups
## and names each `endless/rock/<kind>/<cx>_<cz>/<i>` (scripts/
## layout_overrides.gd). scripts/endless/rocks/rock_build.gd builds a
## group's pillars into a mesh, a collider and the flight's solid;
## scripts/endless/land_rocks.gd streams them and answers the flight.
##
## The densities: each kind's world profile layer (`layers.<kind>`, 0 in the
## wilderness), then the flags over it: --rocks=stacks,hoodoos (each at 1;
## `kind:X` for X, `all`), --stacks=X, --hoodoos=X, --no-rocks. In a world
## of regions each group keeps to its region's layer (`_region_takes`),
## unless a flag set that kind for the whole world.

const ArchPlan = preload("res://scripts/endless/arch_plan.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")

## The kinds, by their layer's name. A new kind is one line here.
const KINDS := {
	"stacks":preload("res://scripts/endless/rocks/sea_stacks.gd"),
	"hoodoos":preload("res://scripts/endless/rocks/hoodoos.gd"),
}
## The world cell (m): the arches' own, so the trees' planner reads both
## with one cache.
const CELL := ArchPlan.CELL
## How far a group keeps off an arch, a slot hall's or split mountain's
## cut and a tunnel's site (m past its own reach).
const CLEAR := 60.0

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## Each kind's density (0 none) from the world profile and the flags, and
## which kinds a flag set for the whole world ("forced").
static func flags() -> Dictionary:
	var world: RefCounted = WorldProfile.current()
	var out := {}
	for k: String in KINDS: out[k] = float(world.layer(k,0.0))
	var forced := {}
	for a: String in LaunchArgs.user_args():
		if a == "--no-rocks":
			for k: String in KINDS:
				out[k] = 0.0
				forced[k] = true
		elif a.begins_with("--rocks="):
			for part: String in a.get_slice("=",1).split(",",false):
				var name := part.get_slice(":",0)
				var d := float(part.get_slice(":",1)) if part.contains(":") else 1.0
				for k: String in KINDS:
					if name == k or name == "all":
						out[k] = maxf(0.0,d)
						forced[k] = true
		else:
			for k: String in KINDS:
				if a.begins_with("--%s=" % k):
					out[k] = maxf(0.0,float(a.get_slice("=",1)))
					forced[k] = true
	# --rock-start=K wants K standing.
	var start := start_wanted()
	if start != "" and KINDS.has(start) and float(out[start]) <= 0.0:
		out[start] = 1.0
		forced[start] = true
	out["forced"] = forced
	return out

## Whether any kind is on.
static func any(densities: Dictionary) -> bool:
	for k: String in KINDS:
		if float(densities.get(k,0.0)) > 0.0: return true
	return false

## `--rock-start=K`: the start moved by the nearest group of kind K.
static func start_wanted() -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--rock-start="): return a.get_slice("=",1)
	return ""

## The groups of cell (cx, cz) on `field`'s land: [spec...], each {name,
## kind, seed, pos (world), reach (m round pos), foot (the trees' keep-outs,
## as tree_plan.gd's arches), approach ({at, heading (deg), alt}), ...the
## kind's own}.
static func plan(field: RefCounted, cx: int, cz: int, densities: Dictionary) -> Array:
	var out: Array = []
	var mine := _raw(field,cx,cz,densities)
	var rank := _rank(field,cx,cz)
	for i in range(mine.size()):
		var spec: Dictionary = mine[i]
		var keep := true
		# Not into a group planned before it in this cell...
		for j in range(i):
			if _overlap(spec,mine[j]): keep = false
		# ...nor one of a neighbouring cell that ranks over this one.
		for dz in range(-1,2):
			for dx in range(-1,2):
				if not keep or (dx == 0 and dz == 0): continue
				if _rank(field,cx+dx,cz+dz) < rank: continue
				for other: Dictionary in _raw(field,cx+dx,cz+dz,densities):
					if _overlap(spec,other):
						keep = false
						break
		if keep: out.append(spec)
	return out

## Two groups closer than APART past their reaches.
const APART := 80.0
static func _overlap(a: Dictionary, b: Dictionary) -> bool:
	var p: Vector3 = a.pos
	var q: Vector3 = b.pos
	return Vector2(p.x-q.x,p.z-q.z).length() < float(a.reach)+float(b.reach)+APART

## A cell's rank among its neighbours (the higher keeps its groups).
static func _rank(field: RefCounted, cx: int, cz: int) -> int:
	return hash([int(field.seed),cx,cz,"rock rank"])

## The cell's groups before they keep off each other: each kind's, kept to
## its region, off the cuts, the tunnels and the arches, named. Cached (a
## pure function of the seed, cell and densities; every neighbour asks).
static var _raw_cache := {}
static var _raw_lock := Mutex.new()
static func _raw(field: RefCounted, cx: int, cz: int, densities: Dictionary) -> Array:
	var key := [int(field.seed),cx,cz,densities.hash(),str(field.get("world").id) if field.get("world") != null else ""]
	_raw_lock.lock()
	var got: Variant = _raw_cache.get(key)
	_raw_lock.unlock()
	if got != null: return got
	var out: Array = []
	var world: Variant = field.get("world")
	var regions := world != null and not bool(world.uniform)
	var forced: Dictionary = densities.get("forced",{})
	for k: String in KINDS:
		var d := float(densities.get(k,0.0))
		if d <= 0.0: continue
		var kind: Script = KINDS[k]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(field.seed),cx,cz,"endless rocks",k])
		var i := 0
		for spec: Dictionary in kind.plan_cell(field,cx,cz,d,rng):
			var pos: Vector3 = spec.pos
			if regions and not forced.has(k) and not _region_takes(world,k,pos.x,pos.z,d,hash([int(field.seed),cx,cz,k,i,"rock region"])): continue
			if _crowded(field,spec): continue
			spec["kind"] = k
			spec["name"] = "endless/rock/%s/%d_%d/%d" % [k,cx,cz,i]
			if not spec.has("seed"): spec["seed"] = hash([int(field.seed),cx,cz,k,i])
			out.append(spec)
			i += 1
	_raw_lock.lock()
	if _raw_cache.size() > 3000: _raw_cache.clear()
	_raw_cache[key] = out
	_raw_lock.unlock()
	return out

## Whether a group would stand in or by a slot hall's or split mountain's
## cut, a tunnel's site or an arch (arch_plan.gd's, for this land).
static func _crowded(field: RefCounted, spec: Dictionary) -> bool:
	var pos: Vector3 = spec.pos
	var reach := float(spec.reach)+CLEAR
	if field.has_method("hall_at") and not (field.hall_at(pos.x,pos.z,reach) as PackedFloat32Array).is_empty(): return true
	if field.has_method("split_at") and not (field.split_at(pos.x,pos.z,reach,ArchPlan.SPLIT_LANE) as PackedFloat32Array).is_empty(): return true
	if field.has_method("tunnels_in") and float(field.get("tunnels")) > 0.0 and not (field.tunnels_in(pos.x-reach,pos.z-reach,pos.x+reach,pos.z+reach) as Array).is_empty(): return true
	if not bool(spec.get("by_arches",true)): return false
	var a := _arches()
	if float(a.density) <= 0.0: return false
	var c0 := cell_of(pos.x-reach,pos.z-reach)
	var c1 := cell_of(pos.x+reach,pos.z+reach)
	for z in range(c0.y,c1.y+1):
		for x in range(c0.x,c1.x+1):
			for arch: Dictionary in ArchPlan.plan(field,x,z,float(a.density),float(a.rock),float(a.ruin)):
				var at: Vector3 = arch.pos
				if Vector2(at.x-pos.x,at.z-pos.z).length() < reach+float(arch.get("w",40.0)): return true
	return false

static var _arch_flags := {}
static func _arches() -> Dictionary:
	if _arch_flags.is_empty(): _arch_flags = preload("res://scripts/endless/land_arches.gd").flags()
	return _arch_flags

## Whether the region at (x, z) in the world of regions `world` takes a
## group of kind `kind` planned at the world's density `density` (arch_plan
## `_region_takes`, by the kind's layer).
static func _region_takes(world: RefCounted, kind: String, x: float, z: float, density: float, roll: int) -> bool:
	var d := float(world.at(x,z).layers.get(kind,0.0))
	if d <= 0.0: return false
	if d >= density: return true
	return float(roll & 0xffffff)/16777216.0 < d/density

## The nearest group of kind `kind` to world XZ `at` (cells ringed outward
## to RINGS), or {}.
static func nearest(field: RefCounted, at: Vector2, kind: String, densities: Dictionary, rings := 24) -> Dictionary:
	var c := cell_of(at.x,at.y)
	for r in range(rings+1):
		var best: Dictionary = {}
		var best_d := INF
		for dz in range(-r,r+1):
			for dx in range(-r,r+1):
				if maxi(absi(dx),absi(dz)) != r: continue
				for spec: Dictionary in plan(field,c.x+dx,c.y+dz,densities):
					if spec.kind != kind: continue
					var p: Vector3 = spec.pos
					var d := Vector2(p.x,p.z).distance_to(at)
					if d < best_d:
						best_d = d
						best = spec
		if not best.is_empty(): return best
	return {}

## The trees' keep-outs near a world rectangle, as tree_plan.gd's arches
## ([centre XZ, cos, sin, half x, half z]).
static func tree_keepouts(field: RefCounted, cx: int, cz: int, densities: Dictionary) -> Array:
	var out: Array = []
	for spec: Dictionary in plan(field,cx,cz,densities): out.append_array(spec.get("foot",[]))
	return out
