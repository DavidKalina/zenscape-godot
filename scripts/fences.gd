extends Node3D
## Fences drawn on the land (docs/scenic/fences.md): the materials tray's
## "fence" specimen (scripts/hand_materials.gd). Press and drag a line over the
## land; on release a rustic split-rail fence follows it, posts every
## POST_SPACING m sunk into the ground, two rails from post to post. End the
## line back where it began (within CLOSE_REACH) and it closes into a pen.
##
## The land decides where it stands, as it decides where a tree can: a post
## stands only on dry ground (not in a pond, a lake or running water) no
## steeper than the land's rock slope, and a span of rails is laid only between
## two standing posts on dry ground that are not a cliff apart (STEP_MAX). What
## is left is cut into runs; each run of two or more posts is one record. Gaps
## are simply left: nothing floats over water or hangs off a rock face.
##
## The records live in the land's data (NativeTerrainData `fences`): {"id",
## "posts" (plate x, z flat, [x0, z0, x1, z1, ...]), "closed"}. So they are in
## every undo snapshot (one drawn fence, however many runs, is one Cmd+Z, laid
## in one stroke by NativeChunkEditor `lay_fence`), in the save, and cleared
## with a new world. Only x and z are kept: every rebuild seats each post on
## the ground under it as it is then, so shaping the land under a fence carries
## its posts up and down with the ground (the editor rebuilds the view on its
## full refresh and on the light refresh a held brush makes, as it lifts the
## landmarks). The trash can takes a fence span by span (`cut`).
##
## This node is the view: one faceted mesh per record, a child of the terrain
## (plate space), and the faint stakes of a line still being drawn (`preview`).

const POST_SPACING := 1.3
## A drawn line ending within CLOSE_REACH m of its start, at least CLOSE_MIN m
## long, closes into a pen.
const CLOSE_REACH := 1.0
const CLOSE_MIN := 4.0
## A line shorter than this lays nothing (a tap).
const MIN_LENGTH := 0.9
## Neighbouring posts more than STEP_MAX m apart in height get no rails.
const STEP_MAX := 0.75
## Slope (rise over run) a post can stand on when the land gives none.
const STEEP := 1.0
## Live water at least this deep (m) keeps a post or a span off.
const WET_DEPTH := 0.02
## At most this many records, and posts to one.
const MAX_FENCES := 256
const MAX_POSTS := 160

## The look: posts POST_HEIGHT m over the ground, sunk POST_SINK, POST_RADIUS
## thick, six-sided with a cut top; two rails at RAIL_HEIGHTS, RAIL_SIZE
## (wide, deep) across, a little crooked. Weathered wood, each piece its own
## shade of WOOD.
const POST_HEIGHT := 0.62
const POST_SINK := 0.12
const POST_RADIUS := 0.055
const RAIL_HEIGHTS := [0.24,0.48]
const RAIL_SIZE := Vector2(0.075,0.05)
const WOOD := [Color("8a7357"),Color("7a6249"),Color("9c8a70"),Color("6f5a44")]
const GHOST := Color(0.93,0.88,0.78,0.45)
const GHOST_OFF := Color(0.85,0.45,0.35,0.35)

var _material: StandardMaterial3D
var _ghost: StandardMaterial3D
var _preview: MeshInstance3D
## Builds, for probes.
var rebuilds := 0

func _init() -> void:
	name = "Fences"
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.92
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost = StandardMaterial3D.new()
	_ghost.vertex_color_use_as_albedo = true
	_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview = MeshInstance3D.new()
	_preview.name = "Preview"
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.material_override = _ghost
	add_child(_preview)

# --- Laying out ---------------------------------------------------------------------

## Whether a drawn `path` closes into a pen.
static func closes(path: PackedVector2Array) -> bool:
	return path.size() >= 4 and path[0].distance_to(path[-1]) <= CLOSE_REACH and length(path) >= CLOSE_MIN

static func length(path: PackedVector2Array) -> float:
	var total := 0.0
	for k in range(1,path.size()): total += path[k-1].distance_to(path[k])
	return total

## Posts evenly along `path`, about POST_SPACING apart, ends on its ends; for a
## pen, round the loop back to its start (the last post is not repeated).
static func posts_along(path: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var line := path.duplicate()
	if closed: line.append(path[0])
	var total := length(line)
	var out := PackedVector2Array()
	if total < MIN_LENGTH: return out
	var spans := maxi(3 if closed else 1,roundi(total/POST_SPACING))
	var count := spans if closed else spans+1
	var at := 0
	var walked := 0.0
	for i in range(count):
		var want := total*float(i)/spans
		while at < line.size()-2 and walked+line[at].distance_to(line[at+1]) < want:
			walked += line[at].distance_to(line[at+1])
			at += 1
		var piece := line[at].distance_to(line[at+1])
		out.append(line[at].lerp(line[at+1],clampf((want-walked)/piece,0.0,1.0) if piece > 1e-6 else 0.0))
	return out

## The runs a line of `posts` breaks into where `span_ok[k]` (the span from
## post k to the next, round to the first for a pen) is false. Each run
## {"posts", "closed"} has two posts or more; a post with no span either side
## is left out.
static func runs(posts: PackedVector2Array, closed: bool, span_ok: Array) -> Array:
	var n := posts.size()
	var out: Array = []
	if n < 2: return out
	if closed:
		var broken := span_ok.find(false)
		if broken < 0: return [{"posts":posts,"closed":true}]
		# Open it after the first break, and walk round as a line.
		var turned := PackedVector2Array()
		var turned_ok: Array = []
		for k in range(n):
			var i := (broken+1+k)%n
			turned.append(posts[i])
			turned_ok.append(span_ok[i])
		return runs(turned,false,turned_ok.slice(0,n-1))
	var run := PackedVector2Array([posts[0]])
	for k in range(n-1):
		if span_ok[k]:
			run.append(posts[k+1])
			continue
		if run.size() >= 2: out.append({"posts":run,"closed":false})
		run = PackedVector2Array([posts[k+1]])
	if run.size() >= 2: out.append({"posts":run,"closed":false})
	return out

## The runs a drawn `path` lays as on `data`'s land: posts along it where
## `stands` (plate point -> bool) allows, spans between them where `dry`
## allows and the ground does not step more than STEP_MAX.
static func plan(data: NativeTerrainData, path: PackedVector2Array, stands: Callable, dry: Callable) -> Array:
	var closed := closes(path)
	var posts := posts_along(path,closed)
	if posts.size() > MAX_POSTS: posts = posts.slice(0,MAX_POSTS)
	var up: Array = []
	for p in posts: up.append(stands.call(p))
	var ok: Array = []
	var spans := posts.size() if closed else posts.size()-1
	for k in range(spans):
		var a := posts[k]
		var b := posts[(k+1)%posts.size()]
		var fine: bool = up[k] and up[(k+1)%posts.size()] and dry.call((a+b)*0.5)
		if fine: fine = absf(float(data.ground_height(a))-float(data.ground_height(b))) <= STEP_MAX
		ok.append(fine)
	return runs(posts,closed,ok)

## The plate points of a record's posts.
static func posts_of(record: Dictionary) -> PackedVector2Array:
	var flat: Array = record.get("posts",[])
	var out := PackedVector2Array()
	for k in range(0,flat.size()-1,2): out.append(Vector2(float(flat[k]),float(flat[k+1])))
	return out

## A record for run `run` with id `id`.
static func record(id: int, run: Dictionary) -> Dictionary:
	var flat: Array = []
	for p: Vector2 in run.posts: flat.append_array([snappedf(p.x,0.001),snappedf(p.y,0.001)])
	return {"id":id,"posts":flat,"closed":bool(run.closed)}

## Whether a saved record is sound: an integer id, 2..MAX_POSTS posts on the
## plate, `closed` a bool.
static func valid(item: Variant) -> bool:
	if not item is Dictionary or not GardenData._integer(item.get("id")) or int(item.id) < 1: return false
	if not item.get("closed") is bool or not item.get("posts") is Array: return false
	var flat: Array = item.posts
	if flat.size()%2 != 0 or flat.size() < 4 or flat.size() > MAX_POSTS*2: return false
	for value in flat:
		if not GardenData._number(value,-14,14): return false
	return true

## The trash can's reach (plate `q`, `radius` m) over `data`'s fences: every
## span it touches goes, and the posts left with no span either side; a run
## cut through the middle becomes two (the second a new record), a pen cut
## opens. Writes `data.fences` (inside the caller's stroke) and returns
## {"changed", "taken" (the plate points of the posts taken)}.
static func cut(data: NativeTerrainData, q: Vector2, radius: float) -> Dictionary:
	var taken := PackedVector2Array()
	var kept: Array[Dictionary] = []
	var changed := false
	for item: Dictionary in data.fences:
		var posts := posts_of(item)
		var closed := bool(item.closed)
		var spans := posts.size() if closed else posts.size()-1
		var ok: Array = []
		var any := false
		for k in range(spans):
			var a := posts[k]
			var b := posts[(k+1)%posts.size()]
			var hit := q.distance_to(Geometry2D.get_closest_point_to_segment(q,a,b)) <= radius
			ok.append(not hit)
			any = any or hit
		if not any:
			kept.append(item)
			continue
		changed = true
		var left := runs(posts,closed,ok)
		var still := {}
		for k in range(left.size()):
			var id := int(item.id) if k == 0 else data.next_id
			if k > 0: data.next_id += 1
			kept.append(record(id,left[k]))
			for p: Vector2 in left[k].posts: still[p] = true
		for p in posts:
			if not still.has(p): taken.append(p)
	if changed: data.fences.assign(kept)
	return {"changed":changed,"taken":taken}

# --- The view -------------------------------------------------------------------------

## Builds every record afresh on the ground as it is now.
func rebuild(data: NativeTerrainData) -> void:
	rebuilds += 1
	for child in get_children():
		if child != _preview: child.free()
	for item: Dictionary in data.fences:
		var mesh := _fence_mesh(data,posts_of(item),bool(item.closed),int(item.id),false,[])
		if mesh == null: continue
		var node := MeshInstance3D.new()
		node.name = "fence_%d" % int(item.id)
		node.mesh = mesh
		node.material_override = _material
		add_child(node)

## The faint stakes of a line being drawn, where it would stand and pale red
## where it would not; an empty `path` clears them.
func preview(data: NativeTerrainData, path: PackedVector2Array, stands: Callable) -> void:
	if path.size() < 2 or length(path) < MIN_LENGTH:
		_preview.mesh = null
		return
	var posts := posts_along(path,closes(path))
	var up: Array = []
	for p in posts: up.append(stands.call(p))
	_preview.mesh = _fence_mesh(data,posts,closes(path),0,true,up)

## The posts' seats on the land now: [plate point, ground height] for each one
## the ground holds, for probes (`seat_of`).
func seats(data: NativeTerrainData, id: int) -> Array:
	var node := get_node_or_null("fence_%d" % id) as MeshInstance3D
	var out: Array = []
	if node == null: return out
	for item: Dictionary in data.fences:
		if int(item.id) == id:
			for p in posts_of(item):
				var h: Variant = data.ground_height(p)
				if h != null: out.append([p,float(h)])
	return out

## The lowest vertex of the drawn mesh within `reach` m of plate point `p`
## (the post's foot), or NAN: what is drawn, for probes.
func foot_at(id: int, p: Vector2, reach := 0.12) -> float:
	var node := get_node_or_null("fence_%d" % id) as MeshInstance3D
	if node == null or node.mesh == null: return NAN
	var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low := INF
	for v in vertices:
		if Vector2(v.x,v.z).distance_to(p) <= reach: low = minf(low,v.y)
	return low if low < INF else NAN

## A post standing at plate `p` as drawn (mesh, material, terrain-local
## transform), for the trash can's flight.
func post_part(data: NativeTerrainData, p: Vector2) -> Dictionary:
	var h: Variant = data.ground_height(p)
	if h == null: return {}
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_post(tool,Vector3.ZERO,7,WOOD[0],false)
	return {"mesh":tool.commit(),"material":_material,"transform":Transform3D(Basis(),Vector3(p.x,float(h),p.y))}

func _fence_mesh(data: NativeTerrainData, posts: PackedVector2Array, closed: bool, seed: int, ghost: bool, up: Array) -> ArrayMesh:
	var n := posts.size()
	if n < 2: return null
	var grounds: Array = []
	for p in posts: grounds.append(data.ground_height(p))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drawn := 0
	for k in range(n):
		if grounds[k] == null: continue
		var standing: bool = up.is_empty() or up[k]
		var tint: Color = (GHOST if standing else GHOST_OFF) if ghost else _shade(seed,k)
		_post(tool,Vector3(posts[k].x,float(grounds[k]),posts[k].y),seed*977+k,tint,ghost)
		drawn += 1
	var spans := n if closed else n-1
	for k in range(spans):
		var j := (k+1)%n
		if grounds[k] == null or grounds[j] == null: continue
		if not up.is_empty() and not (up[k] and up[j]): continue
		var a := Vector3(posts[k].x,float(grounds[k]),posts[k].y)
		var b := Vector3(posts[j].x,float(grounds[j]),posts[j].y)
		for r in range(RAIL_HEIGHTS.size()):
			var tint: Color = GHOST if ghost else _shade(seed+31*r,k+7)
			_rail(tool,a,b,float(RAIL_HEIGHTS[r]),seed*131+k*7+r,tint)
	if drawn == 0: return null
	return tool.commit()

## A shade of weathered wood for piece `k` of fence `seed`.
static func _shade(seed: int, k: int) -> Color:
	var base: Color = WOOD[absi(hash([seed,k]))%WOOD.size()]
	var jitter := float(absi(hash([k,seed,3]))%1000)/1000.0-0.5
	return base.lightened(jitter*0.12) if jitter > 0.0 else base.darkened(-jitter*0.12)

## A six-sided post with its foot at `foot` (plate space), sunk POST_SINK,
## leaning a hair, its top cut on a slant.
func _post(tool: SurfaceTool, foot: Vector3, seed: int, tint: Color, ghost: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed)
	var radius := POST_RADIUS*(rng.randf_range(0.85,1.15) if not ghost else 0.8)
	var height := POST_HEIGHT*rng.randf_range(0.92,1.06)
	var lean := Vector3(rng.randf_range(-0.025,0.025),0.0,rng.randf_range(-0.025,0.025))
	var turn := rng.randf()*TAU
	var slant := Vector3(cos(turn),0.0,sin(turn))
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for s in range(6):
		var a := turn+TAU*s/6.0
		var out := Vector3(cos(a),0.0,sin(a))*radius
		low.append(foot+out+Vector3.DOWN*POST_SINK)
		# The cut top: higher on one side.
		high.append(foot+out*0.92+lean+Vector3.UP*(height+out.dot(slant)*0.6))
	var top := Vector3.ZERO
	for v in high: top += v
	top /= 6.0
	var middle := foot+lean*0.5+Vector3.UP*(height-POST_SINK)*0.5
	for s in range(6):
		var t := (s+1)%6
		_quad(tool,low[s],low[t],high[t],high[s],tint,middle)
		_tri(tool,high[s],high[t],top,tint.lightened(0.08),middle)

## A rail from post foot `a` to post foot `b` at `at` m over the ground, a
## little crooked: square-ish in section, sagging a touch at its middle.
func _rail(tool: SurfaceTool, a: Vector3, b: Vector3, at: float, seed: int, tint: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed)
	var along := Vector3(b.x-a.x,0.0,b.z-a.z)
	if along.length() < 1e-4: return
	var side := Vector3(-along.z,0.0,along.x).normalized()
	var wide := RAIL_SIZE.x*rng.randf_range(0.85,1.15)
	var deep := RAIL_SIZE.y*rng.randf_range(0.85,1.15)
	var twist := rng.randf_range(-0.3,0.3)
	var s := side.rotated(along.normalized(),twist)*deep*0.5
	var u := Vector3.UP.rotated(along.normalized(),twist)*wide*0.5
	# Ends a little past the posts' middles, so they sit into them.
	var dir := (b-a).normalized()
	var ends := [a+Vector3.UP*(at+rng.randf_range(-0.03,0.03))-dir*0.04,(a+b)*0.5+Vector3.UP*(at-0.02),b+Vector3.UP*(at+rng.randf_range(-0.03,0.03))+dir*0.04]
	for piece in range(2):
		var p: Vector3 = ends[piece]
		var q: Vector3 = ends[piece+1]
		var middle := (p+q)*0.5
		var c0 := [p+s+u,p-s+u,p-s-u,p+s-u]
		var c1 := [q+s+u,q-s+u,q-s-u,q+s-u]
		for k in range(4):
			var m := (k+1)%4
			_quad(tool,c0[k],c0[m],c1[m],c1[k],tint.darkened(0.06*k),middle)
		if piece == 0: _quad(tool,c0[3],c0[2],c0[1],c0[0],tint,middle)
		else: _quad(tool,c1[0],c1[1],c1[2],c1[3],tint,middle)

## Unshared corners, each triangle its own face and normal (faceted), turned
## to face away from `centre`, the piece's middle, and wound clockwise seen
## from that side (Godot's front face).
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color, centre: Vector3) -> void:
	var normal := (b-a).cross(c-a)
	if normal.length_squared() < 1e-14: return
	if normal.dot((a+b+c)/3.0-centre) < 0.0:
		normal = -normal
		var swap := b
		b = c
		c = swap
	normal = normal.normalized()
	for v in [a,c,b]:
		tool.set_color(tint)
		tool.set_normal(normal)
		tool.add_vertex(v)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, centre: Vector3) -> void:
	_tri(tool,a,b,c,tint,centre)
	_tri(tool,a,c,d,tint,centre)
