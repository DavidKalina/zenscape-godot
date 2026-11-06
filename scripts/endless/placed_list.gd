extends RefCounted
## The regions' hand lists of placed sites (scripts/endless/world/<id>/
## placed.gd, its SITES) read as sites, and their clear footprints: the one
## part of the placed sites the land's planners read. scripts/endless/
## placed_sites.gd streams the sites' pieces; this script knows nothing of
## the kinds, so the land (land_field.gd, the tree, rock and arch plans) can
## ask it without loading them.
##
## A site's clear (params.clear, m) keeps trees, rock groups (stacks,
## hoodoos, boulders), arches and the land's cut sites (slot halls, split
## mountains, tunnels) out of the circle that radius round its spot, after
## the layout file's move; a deleted site keeps none. The clears are a pure
## function of the lists, the world and the layout file, so every machine
## with the same ones stands the same land. --no-placed: no clears either.

const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const WORLD := "res://scripts/endless/world/"

## Whether the placed sites run (--no-placed: off, their clears too).
static func wanted() -> bool:
	return not "--no-placed" in LaunchArgs.user_args()

## Every listed site whose coded spot its own region holds in world
## `profile`, as `site_of` dictionaries.
static func in_play(profile: RefCounted) -> Array:
	var out: Array = []
	var lists := region_lists()
	for region: String in lists:
		for row: Array in lists[region]:
			var s := site_of(row,region)
			if s.is_empty(): continue
			if str(profile.at(float(s.x),float(s.z)).id) != region: continue
			out.append(s)
	return out

static var _lists := {}
static var _listed := false
static var _lock := Mutex.new()

## Each region's list: region id -> its SITES rows, for every world profile
## with a scripts/endless/world/<id>/placed.gd. Read once.
static func region_lists() -> Dictionary:
	_lock.lock()
	if not _listed:
		for id: String in WorldProfile.ids():
			var path := WORLD+id+"/placed.gd"
			if not ResourceLoader.exists(path): continue
			var script: GDScript = load(path)
			var rows: Variant = script.get_script_constant_map().get("SITES",[])
			if rows is Array: _lists[id] = rows
		_listed = true
	_lock.unlock()
	return _lists

## A list row as a site: {handle, kind, skin, x, z, heading, params, region};
## {} (with a warning) for a row that isn't one.
static func site_of(row: Array, region: String) -> Dictionary:
	if row.size() < 7 or not row[6] is Dictionary:
		push_warning("placed %s: a row is [handle, kind, skin, x, z, heading, params]: %s" % [region,str(row)])
		return {}
	return {"handle":str(row[0]),"kind":str(row[1]),"skin":str(row[2]),"x":float(row[3]),"z":float(row[4]),
		"heading":float(row[5]),"params":row[6],"region":region}

## Where site `s` stands in XZ: its coded spot, unless the layout file moved it.
static func spot(s: Dictionary) -> Vector2:
	var p := LayoutOverrides.xform(str(s.handle),Transform3D(Basis(),Vector3(float(s.x),0.0,float(s.z)))).origin
	return Vector2(p.x,p.z)

static var _clears: Array = []
static var _clears_of: Array = []
static var _clears_lock := Mutex.new()

## The clear footprints of the sites in play in world `profile`:
## [Vector3(x, z, radius)...] at each one's spot after the layout file's
## move. Made once per world and layout file (LayoutOverrides.begin reads
## the file before the land is first looked at); the planners' workers ask
## at once.
static func clears(profile: RefCounted) -> Array:
	if profile == null or not wanted(): return []
	_clears_lock.lock()
	if _clears_of.size() != 2 or not is_same(_clears_of[0],profile) or not is_same(_clears_of[1],LayoutOverrides.data):
		var out: Array = []
		for s: Dictionary in in_play(profile):
			var r := float((s.params as Dictionary).get("clear",0.0))
			if r <= 0.0 or LayoutOverrides.deleted(str(s.handle)): continue
			var at := spot(s)
			out.append(Vector3(at.x,at.y,r))
		_clears = out
		_clears_of = [profile,LayoutOverrides.data]
	var got := _clears
	_clears_lock.unlock()
	return got

## Whether a thing of reach `r` at (x, z) keeps out of every clear in world
## `profile`.
static func clear_of(profile: RefCounted, x: float, z: float, r := 0.0) -> bool:
	for c: Vector3 in clears(profile):
		var dx := x-c.x
		var dz := z-c.y
		var far := c.z+r
		if dx*dx+dz*dz < far*far: return false
	return true

## The clears near the box (x0, z0)..(x1, z1) as the trees' keep-outs
## (tree_plan.gd `_arches_near`: [centre, cos, sin, half span, half depth]
## past its `clear`): each circle as columns `COLUMN` m wide, every half span
## under `clear` so none has an approach lane.
const COLUMN := 12.0
static func tree_keepouts(profile: RefCounted, x0: float, z0: float, x1: float, z1: float, clear: float) -> Array:
	var out: Array = []
	for c: Vector3 in clears(profile):
		var r := c.z
		if c.x+r < x0 or c.x-r > x1 or c.y+r < z0 or c.y-r > z1: continue
		var half := COLUMN*0.5
		var n := int(ceil(r/COLUMN))
		for i in range(-n,n+1):
			var d := i*COLUMN
			if absf(d) >= r+half: continue
			# The column's length: the circle's chord at its nearer edge.
			var near := maxf(absf(d)-half,0.0)
			if near >= r: continue
			var chord := sqrt(r*r-near*near)
			out.append([Vector2(c.x+d,c.y),1.0,0.0,half-clear,chord-clear])
	return out
