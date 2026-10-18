extends RefCounted
## The world's islands as units (docs/design/world-editor/spec-world-editor.md):
## each island by a stable name (`island/near`), its land node, its world
## outline (x, z) and what stands on it. The isle registers its islands as
## it builds them (`begin`, `add`); `anchor` gives every placement its
## island, once, the first time the world view opens (scripts/layout_edit.gd),
## so no placer is rewired and nothing runs in play.
##
## Anchoring walks the scene's own nodes from `roots` down. A node whose
## drawn (or collided) footprint stands over one island's outline, within
## its height, is that island's member whole (meta `world_island`). A node
## that spans islands or sky, or stands over none, is looked into: its
## children are tried the same way. A leaf over no island is a free piece;
## a leaf over two is a span (a link's part, for the links step).
## Floating pieces the layout names as rings and slabs are always free.

const FREE_KINDS := ["air_ring","bob_slab","land"]
## Not anchored: the grass and flowers (scripts/kit_isle/kit_flora.gd's
## chunks, cut on a grid, not by island; regrown over the turf when an
## island is let go, not moved) and the editor's own selection box.
const SKIP := ["Flora","LayoutSelection"]
## How far over an island's drawn top and under its keel a member may stand.
const OVER := 25.0
const UNDER := 2.0
## How deep anchoring looks into containers.
const DEPTH := 6

## name -> {node, outline: PackedVector2Array, box: AABB (the land's drawn
## bounds), rect: Rect2 (the outline's x, z bounds), members: Array[Node3D]}
static var islands := {}
## Leaves over two islands: [{node, islands: [names]}].
static var spans: Array = []
## Links (an aqueduct, a bridge: built from island to island) by stable
## name (`link/aqueduct_main`): {nodes: Array[Node3D], islands: [names],
## box: AABB, parts: Array[Node3D] (the loose collision under it)}. No
## island claims them; the links step refits them when an island moves.
static var links := {}
static var anchored := false

static func begin() -> void:
	islands = {}
	links = {}
	spans = []
	anchored = false

## `land` (a KitLand island, its world outline in meta "outline") as `name`;
## `top` its turf's height at the rim (NAN: its drawn top).
static func add(name: String, land: Node3D, top := NAN) -> void:
	var outline := PackedVector2Array(land.get_meta("outline",PackedVector2Array()))
	var rect := Rect2()
	if not outline.is_empty():
		rect = Rect2(outline[0],Vector2.ZERO)
		for p: Vector2 in outline: rect = rect.expand(p)
	islands[name] = {"node":land,"outline":outline,"rect":rect,"box":AABB(),"top":top,"members":[]}
	land.set_meta("world_island_root",name)

## The height an island's rim is drawn at: its turf's, else its drawn top.
static func rim_y(i: Dictionary) -> float:
	if not is_nan(float(i.top)): return float(i.top)
	var box: AABB = i.box
	return box.end.y if box.size != Vector3.ZERO else 0.0

## `nodes` (built in world space) as link `name` between `between`.
static func add_link(name: String, nodes: Array, between: Array) -> void:
	links[name] = {"nodes":nodes,"islands":between,"box":AABB(),"parts":[]}
	for n: Node3D in nodes: n.set_meta("world_link",name)

## The island name `node` is part of ("" none): the land itself, or a member
## (or anything under one).
static func island_of(node: Node) -> String:
	var n := node
	while n != null:
		if n.has_meta("world_island_root"): return str(n.get_meta("world_island_root"))
		if n.has_meta("world_island"): return str(n.get_meta("world_island"))
		n = n.get_parent()
	return ""

## The island whose outline is under world point `p` ("" none).
static func island_under(p: Vector3) -> String:
	for name: String in islands:
		var i: Dictionary = islands[name]
		if (i.rect as Rect2).grow(0.01).has_point(Vector2(p.x,p.z)) and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),i.outline): return name
	return ""

## Every placement under `roots` given its island (once; again with `force`).
static func anchor(roots: Array, force := false) -> void:
	if anchored and not force: return
	spans = []
	for name: String in islands:
		var i: Dictionary = islands[name]
		for m: Node3D in i.members:
			if is_instance_valid(m): m.remove_meta("world_island")
		i.members = []
		i.box = drawn_box(i.node)
	for name: String in links:
		var l: Dictionary = links[name]
		for p: Node3D in l.parts:
			if is_instance_valid(p): p.remove_meta("world_link")
		l.parts = []
		var box := AABB()
		for n: Node3D in l.nodes:
			var b := drawn_box(n)
			if b.size != Vector3.ZERO: box = b if box.size == Vector3.ZERO else box.merge(b)
		l.box = box
	# The land and pieces first, then the loose collision bodies: one inside
	# a member's bounds is that member's island's (its own collision), one
	# inside a link's (and no member's) the link's, the rest tried alike.
	var bodies: Array = []
	for r: Node in roots:
		if r is StaticBody3D: bodies.append(r)
		elif r is Node3D: _anchor(r as Node3D,0)
	var boxes: Array = []
	for name: String in islands:
		for m: Node3D in islands[name].members: boxes.append([drawn_box(m).grow(0.5),name])
	for body: StaticBody3D in bodies:
		var b := drawn_box(body)
		var owner := ""
		for mb: Array in boxes:
			if (mb[0] as AABB).encloses(b):
				owner = mb[1]
				break
		if owner != "":
			islands[owner].members.append(body)
			body.set_meta("world_island",owner)
			continue
		for name: String in links:
			if (links[name].box as AABB).grow(0.5).encloses(b):
				owner = name
				break
		if owner != "":
			links[owner].parts.append(body)
			body.set_meta("world_link",owner)
			continue
		_anchor(body,0)
	anchored = true

static func _anchor(n: Node3D, depth: int) -> void:
	if n.has_meta("world_island_root") or n.has_meta("world_link") or n.name in SKIP: return
	if n.has_meta("layout_name") and _free_kind(str(n.get_meta("layout_name"))): return
	var box := drawn_box(n)
	if box.size != Vector3.ZERO or n.get_child_count() == 0:
		var over := _over(box)
		if over.size() == 1:
			var name: String = over[0]
			islands[name].members.append(n)
			n.set_meta("world_island",name)
			return
		if n.get_child_count() == 0 or depth >= DEPTH:
			if over.size() > 1: spans.append({"node":n,"islands":over})
			return
	for c: Node in n.get_children():
		if c is Node3D: _anchor(c as Node3D,depth+1)

static func _free_kind(layout_name: String) -> bool:
	var e: Dictionary = preload("res://scripts/layout_overrides.gd").entries.get(layout_name,{})
	return str(e.get("kind","")) in FREE_KINDS

## The islands `box`'s footprint stands over: its middle and corners, each
## over an island within its height. One name: it is wholly that island's
## (its corners over that island or over the sky); more: it spans them;
## none: free. A footprint wider than the island's own is never one island's.
static func _over(box: AABB) -> Array:
	if box.size == Vector3.ZERO: return []
	var mid := box.get_center()
	var out: Array = []
	var foot := [Vector2(mid.x,mid.z),Vector2(box.position.x,box.position.z),Vector2(box.end.x,box.position.z),
		Vector2(box.position.x,box.end.z),Vector2(box.end.x,box.end.z)]
	var mid_on := ""
	for k in range(foot.size()):
		var p: Vector2 = foot[k]
		for name: String in islands:
			var i: Dictionary = islands[name]
			var ibox: AABB = i.box
			if mid.y < ibox.position.y-UNDER or box.position.y > ibox.end.y+OVER: continue
			if not (i.rect as Rect2).has_point(p) or not Geometry2D.is_point_in_polygon(p,i.outline): continue
			if k == 0: mid_on = name
			if not name in out: out.append(name)
	if out.size() == 1:
		if mid_on == "": return []
		var r: Rect2 = islands[out[0]].rect
		if box.size.x > r.size.x*1.05 or box.size.z > r.size.y*1.05: return []
	return out

## `node`'s drawn bounds in the world (its visuals; else its collision
## shapes), AABB() if it has neither.
static func drawn_box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var vis: Array = node.find_children("*","VisualInstance3D",true,false)
	if node is VisualInstance3D: vis.append(node)
	for c: Node in vis:
		var v := c as VisualInstance3D
		if v.name == "LayoutSelection" or not v.visible: continue
		var b := v.global_transform*v.get_aabb()
		if b.size == Vector3.ZERO: continue
		box = b if first else box.merge(b)
		first = false
	if not first: return box
	var shapes: Array = node.find_children("*","CollisionShape3D",true,false)
	if node is CollisionShape3D: shapes.append(node)
	for c: Node in shapes:
		var s := c as CollisionShape3D
		if s.shape == null: continue
		var m := s.shape.get_debug_mesh()
		if m == null: continue
		var b := s.global_transform*m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## A short count of what anchoring found.
static func summary() -> String:
	var parts := PackedStringArray()
	for name: String in islands: parts.append("%s %d" % [name,(islands[name].members as Array).size()])
	for name: String in links: parts.append("%s %d+%d parts" % [name,(links[name].nodes as Array).size(),(links[name].parts as Array).size()])
	return ", ".join(parts)+(", spans %d" % spans.size())
