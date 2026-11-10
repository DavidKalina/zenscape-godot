extends Node3D
## The placed sites: each region's hand list (scripts/endless/world/<id>/
## placed.gd, its SITES; docs/design/endless-flight/wilderness-kit.md, "How a
## region is made") built when the eye comes within a site's reach and
## freed past it, as the land's generated sites are streamed. A site is
## placed only where its own region holds the land (the world profile's
## `at(x, z)`), so a region with no list places nothing, and a world without
## the region (--world=amberlands) places none of its sites.
##
## The lists and their clear footprints are read by scripts/endless/
## placed_list.gd (the land's planners ask it which spots to keep clear).
## Each site's piece is built by its kind (scripts/endless/kinds/kinds.gd),
## stands on the land under (x, z) unless its params say otherwise, and is
## placed through scripts/layout_overrides.gd under its handle: a move in the
## layout file (layouts/endless_flight.json, or --layout=) wins, a deleted
## handle is dropped. No file: the coded spots.
##
## A kind's piece may stand in the flight's way: its node sets meta `solid`
## ({g: a BoxSolid of its own frame, reach: m from its origin that holds
## it}), at build or later (a piece built off-thread), and `ground` and
## `inside` answer the flight with it (plane_ground, _blocked, _solid), the
## way the coast's lighthouse does. Its colliders (layer 1, for the near
## misses' wing rays) are its own.
##
## --no-placed: none built.

const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const PlacedList = preload("res://scripts/endless/placed_list.gd")
const Kinds = preload("res://scripts/endless/kinds/kinds.gd")

## Built within REACH m of the eye (XZ) unless a site's params.reach says
## otherwise; freed past its reach and SLACK.
const REACH := 2600.0
const SLACK := 300.0
## Sites built in one frame, at most (a lane's piece can be heavy).
const BUILDS_PER_FRAME := 1

var field: RefCounted
var world: RefCounted
## The sites in play: every listed one in its own region (placed_list.gd
## `site_of`).
var sites: Array = []
## handle -> the built node.
var _built := {}
## The handles whose kind built nothing (an unknown kind): not asked again.
var _unbuilt := {}
var stats := {"listed":0,"built":0,"freed":0}
## The land's ground material (endless_look.gd `ground`), handed to the
## kinds as site.ground (null: a kind's own plain one).
var ground_material: Material
## The built pieces' solids: handle -> {inv, oy, g, x, z, reach2}.
var _solids := {}

## Whether the placed sites run (--no-placed: off, their clears too).
static func wanted() -> bool:
	return PlacedList.wanted()

func setup(land_field: RefCounted, profile: RefCounted) -> void:
	field = land_field
	world = profile
	sites = PlacedList.in_play(world)
	stats.listed = sites.size()

## Where site `s` stands with no layout file: on the land under its spot
## (params.y, else the land's height plus params.lift), turned to its heading.
static func coded_xform(s: Dictionary, land: RefCounted) -> Transform3D:
	var p: Dictionary = s.params
	var x := float(s.x)
	var z := float(s.z)
	var y: float = float(p.y) if p.has("y") else float(land.height(x,z))+float(p.get("lift",0.0))
	return Transform3D(Basis(Vector3.UP,deg_to_rad(float(s.heading))),Vector3(x,y,z))

## Where site `s` stands: its coded spot, unless the layout file moved it.
static func xform_of(s: Dictionary, land: RefCounted) -> Transform3D:
	return LayoutOverrides.xform(str(s.handle),coded_xform(s,land))

func prime(at: Vector3) -> void:
	_stream(at,1 << 20)

func step(at: Vector3) -> void:
	_stream(at,BUILDS_PER_FRAME)
	_take_solids()

func _stream(at: Vector3, most: int) -> void:
	if not wanted(): return
	var builds := 0
	for s: Dictionary in sites:
		var handle: String = s.handle
		var reach := float((s.params as Dictionary).get("reach",REACH))
		# Where it stands, or will (the layout file's move, else its coded XZ).
		var spot: Vector2 = Vector2((_built[handle] as Node3D).position.x,(_built[handle] as Node3D).position.z) if _built.has(handle) else PlacedList.spot(s)
		var d := Vector2(spot.x-at.x,spot.y-at.z).length()
		if _built.has(handle):
			if d > reach+SLACK: _free(handle)
		elif d <= reach and builds < most and not _unbuilt.has(handle) and not LayoutOverrides.deleted(handle):
			if _build(s): builds += 1

func _build(s: Dictionary) -> bool:
	var handle: String = s.handle
	var coded := coded_xform(s,field)
	var site := s.duplicate()
	site["y"] = coded.origin.y
	site["xform"] = LayoutOverrides.xform(handle,coded)
	site["field"] = field
	site["ground"] = ground_material
	var node := Kinds.build(site)
	if node == null:
		# An unknown kind: never asked again this run.
		_unbuilt[handle] = true
		return false
	node.name = handle.validate_node_name()
	node.set_meta("placed_handle",handle)
	add_child(node)
	node.transform = site.xform
	LayoutOverrides.track(handle,node,"piece",coded)
	_built[handle] = node
	stats.built += 1
	_take_solids()
	return true

func _free(handle: String) -> void:
	var node: Node3D = _built[handle]
	_built.erase(handle)
	_solids.erase(handle)
	LayoutOverrides.entries.erase(handle)
	node.queue_free()
	stats.freed += 1

## The built pieces' solids not yet taken (meta `solid`), each at where its
## node stands.
func _take_solids() -> void:
	for handle: String in _built:
		if _solids.has(handle): continue
		var node: Node3D = _built[handle]
		if not node.has_meta("solid"): continue
		var s: Dictionary = node.get_meta("solid")
		var t := node.transform
		var far := float(s.reach)+BoxSolid.grow_most()+1.0
		_solids[handle] = {"inv":t.affine_inverse(),"oy":t.origin.y,"g":s.g,"x":t.origin.x,"z":t.origin.z,"reach2":far*far}

## SkyGlide's `ground` at `p` over the land `h` (as CoastSites `ground`): a
## piece raises it, a span over it is an underside.
func ground(p: Vector3, h: Variant, pad := 0.4) -> Variant:
	if _solids.is_empty() or not h is float: return h
	var list: Array = []
	for s: Dictionary in _solids.values():
		if Vector2(p.x-float(s.x),p.z-float(s.z)).length_squared() > float(s.reach2): continue
		var l: Vector3 = (s.inv as Transform3D)*p
		BoxSolid.stretches(s.g,l.x,l.z,pad,float(s.oy),list)
	if list.is_empty(): return h
	return LandHalls.over(p,h,BoxSolid.joined(list))

## True inside a piece's solid, grown by `pad`.
func inside(p: Vector3, pad := 0.4) -> bool:
	for s: Dictionary in _solids.values():
		if Vector2(p.x-float(s.x),p.z-float(s.z)).length_squared() > float(s.reach2): continue
		if BoxSolid.inside(s.g,(s.inv as Transform3D)*p,pad): return true
	return false

## The sites built now: [{handle, kind, region, node, xform}].
func standing() -> Array:
	var out: Array = []
	for s: Dictionary in sites:
		if not _built.has(s.handle): continue
		var node: Node3D = _built[s.handle]
		out.append({"handle":s.handle,"kind":s.kind,"region":s.region,"node":node,"xform":node.global_transform})
	return out

## The node built for `handle`, or null.
func node_of(handle: String) -> Node3D:
	return _built.get(handle)
