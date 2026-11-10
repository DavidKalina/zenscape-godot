extends Node3D
## Kind `uprights` (docs/design/endless-flight/spec-wild-kit-uprights.md): a
## set of upright pieces stood in a ring or a row, with gaps to thread. The
## kind lays them out from the site's params; a skin (the site's `skin`)
## brings the pieces: SKINS below, a script of static functions:
##
##   defaults() -> Dictionary      the skin's params, under the site's own
##   pieces(layout) -> Array       the pieces built for `layout` (below), on a
##                                 worker: plain data, no nodes; each
##                                 {arrays (indexed, one surface), lods
##                                 ({error: indices}), faces (the collider's
##                                 triangles, a PackedVector3Array), material
##                                 (a key: "bare" the land's rock with no
##                                 turf, "ground" with it, else the skin's
##                                 own `material(key)`)}
##   material(key) -> Material     a key's material (main thread), for keys
##                                 other than "bare" and "ground"
##
## The layout ({shape, slots, spans, params, seed}): `slots`, one an upright,
## each {at (Vector3, its foot's middle in the piece's frame, y the land's
## under it), along (Vector3, the path's way there, level), out (Vector3,
## level, away from the ring's middle, or the row's right), wide (m along
## the path), tall (m), depth (m, across it), lean (rad, toward `out`),
## short (1 whole, under 1 broken to that share), fallen (bool), held (in a
## span: whole, upright, its top level with its pair's), lie_y (the land's
## height half its height out, where a fallen one lies), seed, index};
## `spans`, the pairs that carry a piece across their tops ([i, j]); `gaps`,
## each gap's width (m, the one after slot k).
##
## Params (the site's, over the skin's defaults):
##   shape    "ring" (a closed circle round the foot) or "row" (a line along
##            the heading, -Z, centred on the foot)
##   count    uprights
##   radius   the ring's (m, to the uprights' middles); length: the row's
##   tall     the uprights' height (m); jitter: share each varies by
##   gap      the flown gap's toy width (WorldScale `opening`), TOY_GAP; a
##            ring's spans and its wide gaps are TOY_SPAN_GAP and TOY_WIDE
##   wide     how many gaps are TOY_WIDE (the rest `gap`)
##   spans    how many pairs carry a span (a ring's lintels)
##   lean     the leaners' lean (deg); leaners: how many
##   fallen   how many lie fallen; broken: how many stand broken short
##   depth    an upright's thickness (m, across the path)
##   channel  a row's channel's toy width (WorldScale `opening`), 0 none: its
##            uprights stand either side of it (a wreck's ribs), the
##            skin's own named width
##   land     the step (m) of the land's heights the kind reads under the
##            piece for the skin (0 none)
##
## Every flown gap is at least its opening: an upright's width is what the
## path leaves after them, and the skin's pieces stay inside `wide` (their
## weathering included). The pieces are solid: a collider on layer 1 (the
## near misses' wing rays) and the flight's solid (meta `solid`, which
## scripts/endless/placed_sites.gd hands to plane_ground).
##
## Built off the main thread (a WorkerThreadPool task, started on entering
## the tree), the mesh and solid added when it is done; kept per site and
## spot for the run, so a piece streamed out and back is built once.

const WorldScale = preload("res://scripts/world_scale.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")

const SKINS := {
	"stones": preload("res://scripts/endless/world/wilderness/uprights_stones.gd"),
	"ribs": preload("res://scripts/endless/world/wilderness/uprights_ribs.gd"),
}

## The flown gaps' toy widths (WorldScale `opening`: x2 at the defaults):
## the plain gap between two uprights (the ruin kit's thread), a ring's
## wide gaps, and the gap under a span (a lintel's pair).
const TOY_GAP := 3.5
const TOY_WIDE := 5.0
const TOY_SPAN_GAP := 4.5
## The collider's layer (the land's stone's: near misses' wing rays).
const LAYER := 1

const PLAIN := {"shape":"ring","count":12,"radius":30.0,"length":120.0,"tall":20.0,"jitter":0.15,
	"gap":TOY_GAP,"wide":0,"spans":0,"lean":0.0,"leaners":0,"fallen":0,"broken":0,"depth":3.0,"channel":0.0,"land":0.0}

## The built data by site and spot ({key: built}), and the tasks running.
static var _made := {}
static var _bare := {}

var site: Dictionary
var layout: Dictionary
## What it cost: pieces, triangles a level, the solid's boxes, the worker's
## build and the main thread's finish (ms), whether it was kept from before.
var stats := {"pieces":0,"tris":0,"lod_tris":[],"boxes":0,"build_ms":0.0,"finish_ms":0.0,"cached":false}
var _skin: GDScript
var _key := ""
var _task := -1
var _out: Dictionary = {}

## The kind's entry (scripts/endless/kinds/kinds.gd).
static func build(s: Dictionary) -> Node3D:
	var skin := str(s.get("skin",""))
	if not SKINS.has(skin):
		push_warning("placed site %s: uprights has no skin '%s'" % [s.get("handle","?"),skin])
		return null
	var n: Node3D = (load("res://scripts/endless/kinds/uprights.gd") as GDScript).new()
	n.site = s
	n._skin = SKINS[skin]
	return n

func _enter_tree() -> void:
	if not layout.is_empty(): return
	var params: Dictionary = (_skin.call("defaults") as Dictionary).duplicate()
	params.merge(site.get("params",{}),true)
	var xf: Transform3D = site.get("xform",Transform3D.IDENTITY)
	_key = "%s|%s|%s" % [site.get("handle",""),var_to_str(params),var_to_str(xf)]
	layout = lay_out(params,xf,site.get("field"),hash(str(site.get("handle",""))))
	if _made.has(_key):
		stats.cached = true
		_finish(_made[_key])
		return
	_task = WorkerThreadPool.add_task(_work.bind(layout,_skin))

func _process(_dt: float) -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task): return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_made[_key] = _out
	_finish(_out)

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_made[_key] = _out

## The pieces built and merged (on a worker): {arrays by material key, lods,
## shapes, boxes, reach, tris, ms}.
func _work(lay: Dictionary, skin: GDScript) -> void:
	_out = make(lay,skin)

static func make(lay: Dictionary, skin: GDScript) -> Dictionary:
	var began := Time.get_ticks_usec()
	var by := {}
	var shapes: Array = []
	var boxes: Array = []
	var reach := 0.0
	for piece: Dictionary in skin.call("pieces",lay):
		var key := str(piece.get("material","bare"))
		if not by.has(key): by[key] = []
		(by[key] as Array).append(piece)
		var faces: PackedVector3Array = piece.faces
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shapes.append(shape)
		boxes.append_array(BoxSolid.from_faces(faces))
		for v in faces: reach = maxf(reach,Vector2(v.x,v.z).length())
	var surfaces: Array = []
	var tris := [0,0,0]
	for key: String in by:
		var m := merge(by[key])
		m["material"] = key
		surfaces.append(m)
		for l in range(3): tris[l] += int(m.tris[l]) if l < (m.tris as Array).size() else 0
	return {"surfaces":surfaces,"shapes":shapes,"solid":{"g":BoxSolid.build(boxes),"reach":reach},
		"boxes":boxes.size(),"pieces":shapes.size(),"tris":tris,"ms":(Time.get_ticks_usec()-began)/1000.0}

## Pieces' surfaces joined into one (one draw): their arrays end to end, each
## level's indices after the first piece's level keys (sorted by error).
static func merge(pieces: Array) -> Dictionary:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var shape := PackedByteArray()
	var with_shape := true
	var idx := PackedInt32Array()
	var keys: Array = []
	var levels: Array = []
	for piece: Dictionary in pieces:
		var a: Array = piece.arrays
		if a[Mesh.ARRAY_CUSTOM3] == null: with_shape = false
		var lods: Dictionary = piece.get("lods",{})
		if keys.is_empty():
			keys = lods.keys()
			keys.sort()
			for k in keys: levels.append(PackedInt32Array())
	for piece: Dictionary in pieces:
		var a: Array = piece.arrays
		var base := v.size()
		v.append_array(a[Mesh.ARRAY_VERTEX])
		n.append_array(a[Mesh.ARRAY_NORMAL])
		c.append_array(a[Mesh.ARRAY_COLOR])
		if with_shape: shape.append_array(a[Mesh.ARRAY_CUSTOM3])
		for i: int in a[Mesh.ARRAY_INDEX]: idx.append(base+i)
		var lods: Dictionary = piece.get("lods",{})
		var own: Array = lods.keys()
		own.sort()
		for l in range(levels.size()):
			# A piece with fewer levels gives its last.
			var src: PackedInt32Array = lods[own[mini(l,own.size()-1)]] if not own.is_empty() else a[Mesh.ARRAY_INDEX]
			var out: PackedInt32Array = levels[l]
			for i: int in src: out.append(base+i)
			levels[l] = out
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	if with_shape: arrays[Mesh.ARRAY_CUSTOM3] = shape
	var lods := {}
	var tris := [idx.size()/3]
	for l in range(keys.size()):
		lods[keys[l]] = levels[l]
		tris.append((levels[l] as PackedInt32Array).size()/3)
	return {"arrays":arrays,"lods":lods,"tris":tris}

func _finish(out: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	for s: Dictionary in out.surfaces:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,s.arrays,[],s.lods,RockShape.format(s.arrays))
		mesh.surface_set_material(0,_material(str(s.material)))
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_%s" % s.material
		mi.mesh = mesh
		add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = LAYER
	body.collision_mask = 0
	for shape: Shape3D in out.shapes:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	add_child(body)
	set_meta("solid",out.solid)
	stats.pieces = int(out.pieces)
	stats.tris = int(out.tris[0])
	stats.lod_tris = out.tris
	stats.boxes = int(out.boxes)
	stats.build_ms = float(out.ms)
	stats.finish_ms = (Time.get_ticks_usec()-began)/1000.0

func _material(key: String) -> Material:
	var ground: Material = site.get("ground")
	if key == "ground" and ground != null: return ground
	if key == "bare" or key == "ground":
		if ground is ShaderMaterial:
			if not _bare.has(ground):
				# As LandRocks `bare`: every face the land's rock, no turf.
				var b := (ground as ShaderMaterial).duplicate() as ShaderMaterial
				b.set_shader_parameter("rock_up",1.2)
				b.set_shader_parameter("thin_up",1.3)
				b.set_shader_parameter("peak_ice_solid",-1.0)
				_bare[ground] = b
			return _bare[ground]
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.vertex_color_is_srgb = true
		plain.roughness = 1.0
		return plain
	return _skin.call("material",key)

# --- The layout ----------------------------------------------------------------

## The layout of `params` at `xf` over the land `field` (main thread: it
## reads the land's height under each upright).
static func lay_out(params: Dictionary, xf: Transform3D, field: RefCounted, seed_value: int) -> Dictionary:
	var p := PLAIN.duplicate()
	p.merge(params,true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ring := str(p.shape) == "ring"
	var count := maxi(2,int(p.count))
	var gaps := count if ring else count-1
	# Each gap's width: the plain one, the spans' and the wide ones picked.
	var gap := PackedFloat32Array()
	gap.resize(gaps)
	for k in range(gaps): gap[k] = WorldScale.opening(float(p.gap))
	var spans: Array = []
	var picks := _spread(gaps,int(p.spans),0)
	for k: int in picks:
		gap[k] = WorldScale.opening(TOY_SPAN_GAP)
		spans.append([k,(k+1)%count])
	var free: Array = []
	for k in range(gaps):
		if not k in picks: free.append(k)
	for k: int in _pick(free,int(p.wide),rng):
		gap[k] = WorldScale.opening(TOY_WIDE)
	# The path's length and each upright's share of it.
	var path := TAU*float(p.radius) if ring else float(p.length)
	var gaps_total := 0.0
	for k in range(gaps): gaps_total += gap[k]
	var share := (path-gaps_total)/count
	var wides := PackedFloat32Array()
	wides.resize(count)
	var total := 0.0
	for i in range(count):
		wides[i] = maxf(1.0,share*rng.randf_range(0.8,1.2))
		total += wides[i]
	for i in range(count): wides[i] *= (path-gaps_total)/total
	# Their states: the spans' pair stand whole and level; the others may
	# lean, break or lie fallen.
	var held := {}
	for s: Array in spans:
		held[s[0]] = true
		held[s[1]] = true
	var loose: Array = []
	for i in range(count):
		if not held.has(i): loose.append(i)
	var fallen := _pick(loose,int(p.fallen),rng)
	for i: int in fallen: loose.erase(i)
	var leaners := _pick(loose,int(p.leaners),rng)
	for i: int in leaners: loose.erase(i)
	var broken := _pick(loose,int(p.broken),rng)
	var tall := float(p.tall)
	var slots: Array = []
	var s_at := 0.0
	var inv := xf.affine_inverse()
	# A ring turns so its first gap's middle (the first span's) is on the heading.
	var zero := wides[0]+gap[0]*0.5
	for i in range(count):
		var mid := s_at+wides[i]*0.5
		s_at += wides[i]+(gap[i] if i < gaps else 0.0)
		var at: Vector3
		var along: Vector3
		var out: Vector3
		if ring:
			# Round from the heading (-Z), the first gap's middle on it.
			var ang := -PI*0.5+(mid-zero)/float(p.radius)
			out = Vector3(cos(ang),0.0,sin(ang))
			at = out*float(p.radius)
			along = Vector3(-out.z,0.0,out.x)
		else:
			along = Vector3(0.0,0.0,-1.0)
			out = Vector3(1.0,0.0,0.0)
			at = along*(mid-path*0.5)
		at.y = _local_ground(at,xf,inv,field)
		var t := tall*(1.0+rng.randf_range(-1.0,1.0)*float(p.jitter))
		if held.has(i): t = tall
		slots.append({"index":i,"at":at,"held":held.has(i),
			# The land where a fallen one lies, half its height out.
			"lie_y":_local_ground(at+out*t*0.5,xf,inv,field),"along":along,"out":out,"wide":wides[i],"tall":t,"depth":float(p.depth)*rng.randf_range(0.85,1.15),
			"lean":deg_to_rad(float(p.lean))*rng.randf_range(0.7,1.0) if i in leaners else 0.0,
			"short":rng.randf_range(0.35,0.6) if i in broken else 1.0,"fallen":i in fallen,"seed":rng.randi()})
	# A span's pair: their tops level, at the higher.
	for sp: Array in spans:
		var a: Dictionary = slots[sp[0]]
		var b: Dictionary = slots[sp[1]]
		var top := maxf((a.at as Vector3).y+float(a.tall),(b.at as Vector3).y+float(b.tall))
		a.tall = top-(a.at as Vector3).y
		b.tall = top-(b.at as Vector3).y
	var channel := WorldScale.opening(float(p.channel)) if float(p.channel) > 0.0 else 0.0
	var land := {}
	if float(p.land) > 0.0:
		# Round the piece: a ring's stones and what falls from them, a row's
		# length and its sides, with room past each end.
		var half := Vector2(float(p.radius)+tall,float(p.radius)+tall) if ring else \
			Vector2(channel*0.5+float(p.depth)+tall,path*0.5+tall*1.2)
		land = _land(Vector2(-half.x,-half.y),half*2.0,float(p.land),xf,inv,field)
	return {"shape":str(p.shape),"slots":slots,"spans":spans,"gaps":gap,"channel":channel,"land":land,"params":p,"seed":seed_value}

## The land's heights in the piece's frame over the box from `lo`, `size`
## (local XZ), every `step` m.
static func _land(lo: Vector2, size: Vector2, step: float, xf: Transform3D, inv: Transform3D, field: RefCounted) -> Dictionary:
	var nx := int(ceil(size.x/step))+1
	var nz := int(ceil(size.y/step))+1
	var h := PackedFloat32Array()
	h.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			h[j*nx+i] = _local_ground(Vector3(lo.x+i*step,0.0,lo.y+j*step),xf,inv,field)
	return {"x0":lo.x,"z0":lo.y,"step":step,"nx":nx,"nz":nz,"h":h}

## The land's height at local (x, z) from `layout.land` (bilinear; the
## nearest edge past it; 0 with none). Any thread.
static func land_y(lay: Dictionary, x: float, z: float) -> float:
	var g: Dictionary = lay.get("land",{})
	if g.is_empty(): return 0.0
	var nx := int(g.nx)
	var nz := int(g.nz)
	var fx := clampf((x-float(g.x0))/float(g.step),0.0,nx-1.001)
	var fz := clampf((z-float(g.z0))/float(g.step),0.0,nz-1.001)
	var i := int(fx)
	var j := int(fz)
	var h: PackedFloat32Array = g.h
	var tx := fx-i
	var tz := fz-j
	return lerpf(lerpf(h[j*nx+i],h[j*nx+i+1],tx),lerpf(h[(j+1)*nx+i],h[(j+1)*nx+i+1],tx),tz)

## The land's height under local `at` (in the piece's frame).
static func _local_ground(at: Vector3, xf: Transform3D, inv: Transform3D, field: RefCounted) -> float:
	var world := xf*at
	var ground := float(field.height(world.x,world.z)) if field != null else xf.origin.y
	return (inv*Vector3(world.x,ground,world.z)).y

## `n` of `count` gaps spread round evenly from `first`.
static func _spread(count: int, n: int, first: int) -> Array:
	var out: Array = []
	if n <= 0: return out
	for k in range(n):
		var at := (first+int(round(float(k)*count/n)))%count
		if not at in out: out.append(at)
	return out

## `n` of `list` by chance.
static func _pick(list: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var pool := list.duplicate()
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	return out
