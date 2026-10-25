extends "res://scripts/endless/world/world_profile.gd"
## Regions: one world stitched from the registered regions
## (scripts/endless/world/regions.gd), a patchwork of irregular cells about
## 6 km across (scripts/endless/world/region_map.gd), each one region's
## world profile, easing into the next over a border band
## (--world=regions; docs/design/endless-flight/spec-world-regions.md).
##
## Not uniform: the engine asks `at`, `weights_at` and `layer_at` per unit of
## work. Its own tables are the start region's: the land, flora and paint
## that stand where no per-spot answer reaches yet.
##
## Knobs (the registry only sets defaults):
##   --region-size=M    a region's mean width (Regions.SIZE)
##   --region-blend=M   the border band's width (Regions.BLEND)
##   --region-seed=N    the layout's own seed (default the land's --seed=)
##   --regions=id:share[:start],...   the registry's list and shares
##   --region-border    start short of the nearest border, heading across it
##   --region-debug     show the region and its weights under the eye

const Base = preload("res://scripts/endless/world/world_profile.gd")
const Registry = preload("res://scripts/endless/world/regions.gd")
const RegionMap = preload("res://scripts/endless/world/region_map.gd")

## The child profiles, by region index (the map's).
var regions: Array[RefCounted] = []
## Whether the start may lie in each region.
var startable: Array[bool] = []
var map: RefCounted
## The start's region index.
var start_region := 0
## --region-border: the start sits short of a border, heading across it.
var border_start := false
## Where the --region-border start's border lies (NAN when none was found).
var border_at := Vector2(NAN,NAN)

func _init() -> void:
	id = "regions"
	title = "Regions"
	uniform = false
	var size := Registry.SIZE
	var band := Registry.BLEND
	var layout_seed := 1
	var seed_given := false
	var list: Array = Registry.REGISTRY.duplicate(true)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--region-size="): size = a.get_slice("=",1).to_float()
		elif a.begins_with("--region-blend="): band = a.get_slice("=",1).to_float()
		elif a.begins_with("--region-seed="):
			layout_seed = a.get_slice("=",1).to_int()
			seed_given = true
		elif a.begins_with("--seed=") and not seed_given: layout_seed = a.get_slice("=",1).to_int()
		elif a.begins_with("--regions="): list = _parse_list(a.get_slice("=",1))
		elif a == "--region-border": border_start = true
	var shares := PackedFloat32Array()
	for e: Dictionary in list:
		var rid := str(e.id)
		if rid == id:
			push_error("regions: a region can't be the regions world itself; skipped")
			continue
		var p: RefCounted = Base.make(rid)
		if p.uniform == false:
			push_error("regions: '%s' is not a one-profile world; skipped" % rid)
			continue
		regions.append(p)
		startable.append(bool(e.get("start",false)))
		shares.append(float(e.get("share",1.0)))
	if regions.is_empty():
		regions.append(Base.make(DEFAULT))
		startable.append(true)
		shares.append(1.0)
	if not startable.has(true): startable[0] = true
	map = RegionMap.new(size,band,layout_seed,shares)
	_place_start()
	eye_weights = map.weights(spawn.at.x,spawn.at.y)
	# The tables where no per-spot answer reaches: the start region's.
	var home: RefCounted = regions[start_region]
	land = home.land.duplicate(true)
	flora = home.flora.duplicate(true)
	paint = home.paint.duplicate(true)
	layers = home.layers.duplicate(true)
	# A region's own layers (halls, tunnels, arches, splits) run at the densest
	# region's density; each site then keeps to the regions that grow it
	# (halls and tunnels wholly inside one, clear of the band: LandBlend
	# `site_ok`; arches by the region at the spot: ArchPlan).
	for key: String in ["halls","tunnels","arches","splits"]:
		var most := 0.0
		for p: RefCounted in regions: most = maxf(most,float(p.layers.get(key,1.0 if key == "arches" else 0.0)))
		layers[key] = most

## --regions=wilderness:2:start,overgrown:1 into registry entries.
static func _parse_list(text: String) -> Array:
	var out: Array = []
	for part in text.split(",",false):
		var bits := part.split(":")
		var e := {"id":bits[0],"share":1.0,"start":false}
		if bits.size() >= 2 and bits[1] != "": e.share = bits[1].to_float()
		if bits.size() >= 3: e.start = bits[2] == "start" or bits[2] == "1"
		out.append(e)
	if not out.is_empty():
		var any := false
		for e: Dictionary in out: any = any or bool(e.start)
		if not any: out[0].start = true
	return out

# --- Per spot ------------------------------------------------------------------------

func at(x: float, z: float) -> RefCounted:
	return regions[map.dominant(x,z)]

func weights_at(x: float, z: float) -> Dictionary:
	var w: PackedFloat32Array = map.weights(x,z)
	var out := {}
	for r in w.size():
		if w[r] > 0.0: out[regions[r]] = w[r]
	return out

## The regions' weights at (x, z) by region index (the map's own answer).
func weights_by_index(x: float, z: float) -> PackedFloat32Array:
	return map.weights(x,z)

## One line for --region-debug: the region, its cell and the weights.
func describe(x: float, z: float) -> String:
	var w: PackedFloat32Array = map.weights(x,z)
	var c: Vector2i = map.cell_at(x,z)
	var parts := PackedStringArray()
	for r in w.size():
		if w[r] > 0.001: parts.append("%s %.2f" % [regions[r].id,w[r]])
	return "region %s  ·  cell %d, %d  ·  %s" % [at(x,z).title,c.x,c.y,"  ".join(parts)]

# --- The start -----------------------------------------------------------------------

## The start: the nearest startable cell to the origin, well inside it, a
## border within about a minute's flight (or, --region-border, just short of
## the nearest border, heading across it).
func _place_start() -> void:
	var cell := _nearest_startable()
	start_region = map.region_of(cell.x,cell.y)
	var site := _unwarp(map.site(cell.x,cell.y))
	# The nearest border into another region, from the cell's middle.
	var cross := _nearest_border(site,start_region)
	var at_xz := site
	var dir := Vector2(0.0,-1.0)
	if not is_nan(cross.x):
		dir = (cross-site).normalized()
		var reach := site.distance_to(cross)
		if border_start:
			# In the band's outer edge, its middle about 20 s off at cruise.
			at_xz = cross-dir*(map.blend*0.4)
			border_at = cross
		else:
			# Well inside (1.5 km past the band), a border under a minute off.
			var keep: float = map.blend*0.5+1500.0
			if reach > keep: at_xz = site+dir*(reach-keep)
	spawn = {"at":at_xz,"alt":45.0,"heading":-rad_to_deg(atan2(-dir.x,-dir.y)) if border_start else 0.0}

func _nearest_startable() -> Vector2i:
	var home: Vector2i = map.cell_at(0.0,0.0)
	for ring in 12:
		var best := Vector2i.MAX
		var best_d := INF
		for dj in range(-ring,ring+1):
			for di in range(-ring,ring+1):
				if maxi(absi(di),absi(dj)) != ring: continue
				var c := home+Vector2i(di,dj)
				if not startable[map.region_of(c.x,c.y)]: continue
				var d: float = map.site(c.x,c.y).length_squared()
				if d < best_d:
					best_d = d
					best = c
		if best != Vector2i.MAX: return best
	return home

## The world point that warps onto warped point q (the warp moves under a
## third of a size per size, so the fixed point converges).
func _unwarp(q: Vector2) -> Vector2:
	var p := q
	for i in 12:
		p += q-map.warp(p.x,p.y)
	return p

## The nearest point from `from` (36 headings, 100 m steps, then halved
## down to a few metres) where another region than `home` takes over; NAN
## when none lies within two sizes.
func _nearest_border(from: Vector2, home: int) -> Vector2:
	var best := Vector2(NAN,NAN)
	var best_d := INF
	var step := 100.0
	for k in 36:
		var a := TAU*k/36.0
		var d := Vector2(cos(a),sin(a))
		var t := 0.0
		while t < minf(map.size*2.0,best_d):
			t += step
			var p := from+d*t
			if map.weights(p.x,p.y)[home] >= 0.5: continue
			var lo := t-step
			var hi := t
			for i in 5:
				var mid := (lo+hi)*0.5
				var m := from+d*mid
				if map.weights(m.x,m.y)[home] >= 0.5: lo = mid
				else: hi = mid
			if hi < best_d:
				best_d = hi
				best = from+d*hi
			break
	return best

# --- Paint by the eye ----------------------------------------------------------------
#
# The paint (the ground's and the far tuft ring's uniforms, the grass's
# underside hue, the sea's tints, the shader globals, the mood and hour) is
# each region's, blended by the region weights under the eye: it eases over
# the band as the eye crosses it. Every material the engine hands to an
# apply_* is kept (weakly) with the value each key had before the paint (its
# base: the engine's own, which a region without that key keeps), and
# repainted when the eye's weights move. A key something else sets after the
# paint (a --ground-set=, --far-set=, --sea-set= flag, a tuning key) is left
# to it from then on.

## The region weights under the eye the paint stands at (by region index).
var eye_weights := PackedFloat32Array()
## [WeakRef material, channel, {key: [base, value last written]}].
var _painted: Array = []
## The shader globals' bases (their project values, the season reset's).
var _global_base := {}
## Whether paint_eye has run (its first call always paints: the eye may
## start off the spawn, --at=).
var _eye_seen := false
## How far a weight moves before the paint is redone.
const PAINT_STEP := 0.0005

func apply_ground(material: ShaderMaterial) -> void:
	_register(material,"ground")

func apply_far(material: ShaderMaterial) -> void:
	_register(material,"far")

func apply_sea(material: ShaderMaterial) -> void:
	_register(material,"sea")

func apply_silver(material: ShaderMaterial) -> void:
	_register(material,"silver")

func apply_globals() -> void:
	_global_base.clear()
	for k: String in _keys_of("globals"):
		var path := "shader_globals/%s" % k
		_global_base[k] = (ProjectSettings.get_setting(path) as Dictionary).get("value") if ProjectSettings.has_setting(path) else RenderingServer.global_shader_parameter_get(k)
	_paint_globals()

## The eye at world XZ (x, z): the paint follows its weights. True when the
## paint changed (the look then blends its moods: moods_at_eye).
func paint_eye(x: float, z: float) -> bool:
	_spot_tick(x,z)
	var w: PackedFloat32Array = map.weights(x,z)
	var moved := w.size() != eye_weights.size() or not _eye_seen
	_eye_seen = true
	if not moved:
		for r in w.size():
			# A step past PAINT_STEP, or the last one home to exactly 0 or 1.
			if absf(w[r]-eye_weights[r]) > PAINT_STEP or ((w[r] == 0.0 or w[r] == 1.0) and w[r] != eye_weights[r]):
				moved = true
				break
	if not moved: return false
	eye_weights = w
	var keep: Array = []
	for e: Array in _painted:
		if _paint_entry(e): keep.append(e)
	_painted = keep
	_paint_globals()
	return true

## The moods meeting under the eye: [[mood id, hour, weight], ...].
func moods_at_eye() -> Array:
	var out: Array = []
	for r in eye_weights.size():
		if eye_weights[r] <= 0.0: continue
		var p: Dictionary = regions[r].paint
		out.append([str(p.get("mood","alpine_morning")),float(p.get("hour",-1.0)),eye_weights[r]])
	return out

## The keys of `channel` any region paints.
func _keys_of(channel: String) -> Array:
	var keys := {}
	for p: RefCounted in regions:
		if channel == "silver":
			if p.paint.has("silver_colour"): keys["grass_silver_colour"] = true
			continue
		var t: Variant = p.paint.get(channel,{})
		if t is Dictionary:
			for k: String in t: keys[k] = true
	return keys.keys()

## Region `p`'s value of `key` in `channel` (null: it keeps the base).
func _value_of(p: RefCounted, channel: String, key: String) -> Variant:
	if channel == "silver": return p.paint.get("silver_colour")
	if channel == "globals" or channel == "ground" or channel == "far" or channel == "sea":
		var t: Variant = p.paint.get(channel,{})
		return (t as Dictionary).get(key) if t is Dictionary else null
	return null

func _register(material: ShaderMaterial, channel: String) -> void:
	if material == null: return
	var keys := _keys_of(channel)
	if keys.is_empty(): return
	var entry: Array = []
	for e: Array in _painted:
		if e[1] == channel and e[0].get_ref() == material:
			entry = e
			break
	if entry.is_empty():
		entry = [weakref(material),channel,{}]
		_painted.append(entry)
	var own: Dictionary = entry[2]
	for k: String in keys:
		var now: Variant = material.get_shader_parameter(k)
		# Still what the paint wrote: its base stands; else the engine set a
		# new base since (or it is new).
		if own.has(k) and own[k][1] != null and _same(now,own[k][1]): continue
		var base: Variant = now
		if base == null and material.shader != null: base = RenderingServer.shader_get_parameter_default(material.shader.get_rid(),k)
		if base == null: continue
		own[k] = [base,null]
	_paint_entry(entry)
	_paint_spots(entry)

## Paints one kept material at the eye's weights; false once it is gone.
func _paint_entry(entry: Array) -> bool:
	var m: ShaderMaterial = entry[0].get_ref()
	if m == null: return false
	var own: Dictionary = entry[2]
	for k: String in own.keys():
		var slot: Array = own[k]
		if slot[1] != null and not _same(m.get_shader_parameter(k),slot[1]):
			own.erase(k)
			# Its per-spot array (if it has one) takes the new value everywhere.
			_spot_array(m,entry[1],k,m.get_shader_parameter(k),true)
			continue
		m.set_shader_parameter(k,_blend(entry[1],k,slot[0]))
		slot[1] = m.get_shader_parameter(k)
	return true

func _paint_globals() -> void:
	for k: String in _global_base:
		RenderingServer.global_shader_parameter_set(k,_blend("globals",k,_global_base[k]))

## `key` of `channel` at the eye's weights, each region's value or `base`.
func _blend(channel: String, key: String, base: Variant) -> Variant:
	var t := typeof(base)
	var numeric := t in [TYPE_FLOAT,TYPE_INT,TYPE_VECTOR2,TYPE_VECTOR3,TYPE_VECTOR4,TYPE_COLOR]
	var acc: Variant = null
	var heaviest := -1.0
	for r in eye_weights.size():
		var w := eye_weights[r]
		if w <= 0.0: continue
		var v: Variant = _value_of(regions[r],channel,key)
		v = base if v == null else _as(v,t)
		if not numeric:
			if w > heaviest:
				heaviest = w
				acc = v
			continue
		if t == TYPE_INT: v = float(v)
		acc = v*w if acc == null else acc+v*w
	if acc == null: return base
	return int(roundf(acc)) if t == TYPE_INT else acc

## `v` as type `t` where the two are a colour and a vector of three.
static func _as(v: Variant, t: int) -> Variant:
	if t == TYPE_COLOR and v is Vector3: return Color(v.x,v.y,v.z)
	if t == TYPE_VECTOR3 and v is Color: return Vector3(v.r,v.g,v.b)
	if t == TYPE_FLOAT and v is int: return float(v)
	return v

static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b

# --- Paint per spot --------------------------------------------------------------------
#
# The far paint (the ground's carpet tones, the far tuft ring's root and tip,
# the grass's underside hue) is each region's at its own spot, not the eye's:
# a material whose shader has a `<key>_r` array (shaders/region_paint.
# gdshaderinc) gets each region's value of that key there, and the shader
# mixes them by zs_region_map, the region weights round the eye (rgba =
# regions 0..3, SPOT_CELL m a texel, drawn on a worker, redrawn on the same
# texel grid once the eye is SPOT_RECENTRE from its middle). Until the first
# map is drawn (or past its rim, clamped) the key's eye blend stands.

## The map's texels a side, their size (m) and how far the eye goes from the
## map's middle before it is redrawn round it: 24.6 km square, redrawn every
## 4 km (8 km of it still ahead), ~1.5 s on a worker (37k weights()).
const SPOT_N := 192
const SPOT_CELL := 128.0
const SPOT_RECENTRE := 4000.0
## The map's middle (INF: none yet) and the one being drawn.
var _spot_centre := Vector2(INF,INF)
var _spot_next := Vector2.ZERO
var _spot_task := -1
var _spot_bytes := PackedByteArray()
var _spot_tex: ImageTexture
## Shader RID -> {uniform name: true}.
var _uniforms := {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _spot_task >= 0: WorkerThreadPool.wait_for_task_completion(_spot_task)
		_spot_task = -1
		if _spot_tex != null: RenderingServer.global_shader_parameter_set("zs_region_rect",Vector4.ZERO)

## The region map round the eye: publishes a drawn one, starts the next.
func _spot_tick(x: float, z: float) -> void:
	if _spot_task >= 0:
		if not WorkerThreadPool.is_task_completed(_spot_task): return
		WorkerThreadPool.wait_for_task_completion(_spot_task)
		_spot_task = -1
		_spot_publish()
	if Vector2(x,z).distance_to(_spot_centre) <= SPOT_RECENTRE: return
	_spot_next = Vector2(x,z).snapped(Vector2(SPOT_CELL,SPOT_CELL))
	_spot_task = WorkerThreadPool.add_task(_spot_draw.bind(_spot_next),false,"region paint map")

## The weights of regions 0..3 at each texel's middle, as bytes (a worker).
func _spot_draw(centre: Vector2) -> void:
	var bytes := PackedByteArray()
	bytes.resize(SPOT_N*SPOT_N*4)
	var lo := centre-Vector2.ONE*(SPOT_N*SPOT_CELL*0.5)
	var at := 0
	for j in SPOT_N:
		var pz := lo.y+(j+0.5)*SPOT_CELL
		for i in SPOT_N:
			var w: PackedFloat32Array = map.weights(lo.x+(i+0.5)*SPOT_CELL,pz)
			for c in 4:
				bytes[at+c] = roundi(clampf(w[c],0.0,1.0)*255.0) if c < w.size() else 0
			at += 4
	_spot_bytes = bytes

func _spot_publish() -> void:
	var img := Image.create_from_data(SPOT_N,SPOT_N,false,Image.FORMAT_RGBA8,_spot_bytes)
	if _spot_tex == null:
		_spot_tex = ImageTexture.create_from_image(img)
		RenderingServer.global_shader_parameter_set("zs_region_map",_spot_tex)
	else: _spot_tex.update(img)
	_spot_centre = _spot_next
	var lo := _spot_next-Vector2.ONE*(SPOT_N*SPOT_CELL*0.5)
	RenderingServer.global_shader_parameter_set("zs_region_rect",Vector4(lo.x,lo.y,SPOT_N*SPOT_CELL,1.0))

## Each region's value of every kept key on a kept material, into its
## `<key>_r` array where its shader has one.
func _paint_spots(entry: Array) -> void:
	var m: ShaderMaterial = entry[0].get_ref()
	if m == null: return
	var own: Dictionary = entry[2]
	for k: String in own: _spot_array(m,entry[1],k,own[k][0],false)

## `key`'s `<key>_r` array on `m` (if its shader has one): each region's
## value (or `base`), or `base` for all when `all_base`.
func _spot_array(m: ShaderMaterial, channel: String, key: String, base: Variant, all_base: bool) -> void:
	if m.shader == null or not (base is Vector3 or base is Color): return
	var rid := m.shader.get_rid()
	if not _uniforms.has(rid):
		var names := {}
		for u: Dictionary in m.shader.get_shader_uniform_list(true): names[str(u.name)] = true
		_uniforms[rid] = names
	if not (_uniforms[rid] as Dictionary).has(key+"_r"): return
	var arr := PackedVector3Array()
	arr.resize(4)
	for r in 4:
		var v: Variant = base
		if not all_base and r < regions.size():
			var own: Variant = _value_of(regions[r],channel,key)
			if own != null: v = own
		arr[r] = _as(v,TYPE_VECTOR3) if v is Color or v is Vector3 else _as(base,TYPE_VECTOR3)
	m.set_shader_parameter(key+"_r",arr)
	if (_uniforms[rid] as Dictionary).has("region_paint_on"): m.set_shader_parameter("region_paint_on",true)
