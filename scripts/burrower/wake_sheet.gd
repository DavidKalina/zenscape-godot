extends MeshInstance3D
## The burrower's wake on the game's water. Rivers and lakes are drawn in the
## ground, with no place to feed a wake in, so there this is a clear ribbon
## laid along the head's track, each section at the water's own level where
## the head passed, as wide as the water there (the banks hide the rest);
## shaders/burrower_wake.gdshader draws the wake on it, fed as the study's pond
## is (burrower.gd `_feed_pond`). The sea's waves would cut a ribbon up, so on
## the sea the track goes to the sea's own wake instead (EndlessSea
## `other_track`). `busy` is false once the last section has aged out; nothing
## here runs dry.

const SHADER = preload("res://shaders/burrower_wake.gdshader")

## Sections live LIFE s (as long as the rings the shader draws); a time gap
## past GAP s ends a stretch. Each stretch gets a cap CAP m past its ends, for
## the rings to spread onto; the head's end goes AHEAD m past it, under the
## bulge.
const LIFE := 5.5
const GAP := 0.35
const CAP := 26.0
const AHEAD := 16.0
## The ribbon's half width: the water probed at PROBES m out on each side,
## PAST m on over the first bank, WIDEST at most.
const WIDEST := 34.0
const PROBES := [9.0,18.0,27.0]
const PAST := 11.0
## Over the water (m), so its small waves don't cut it up.
const LIFT := 0.1
## After the sea, on it (endless_look.gd SEA_PRIORITY is lower).
const PRIORITY := 2

var land: Node3D
var _mesh := ArrayMesh.new()
## Oldest first: {at (xz), y, born, way, left, right}.
var _sections: Array[Dictionary] = []
## Oldest first: (x, z, born, strength) for the sea's track, 1 in SEA_EVERY.
var _sea: Array[Vector4] = []
var _sea_serial := 0
## The head's way, as of the last frame.
var _way := Vector2.RIGHT
## The track on the sea: SEA_POINTS points, the shader's most, across LIFE s.
const SEA_EVERY := 2
const SEA_POINTS := 40
## Ribbons built (for drivers).
var built := 0

func setup(the_land: Node3D) -> void:
	land = the_land
	name = "BurrowerWake"
	top_level = true
	mesh = _mesh
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.render_priority = PRIORITY
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func wake_material() -> ShaderMaterial:
	return material_override

func busy() -> bool:
	return not _sections.is_empty() or not _sea.is_empty()

func sections() -> int:
	return _sections.size()

## A wake point at `at`, `now` on the head's clock, of strength `k`.
func point(at: Vector2, now: float, k: float) -> void:
	if land.on_sea(at):
		_sea_serial += 1
		if _sea_serial % SEA_EVERY == 0: _sea.append(Vector4(at.x,at.y,now,minf(k,1.0)))
		return
	_sections.append({"at": at, "y": land.water_y(at.x,at.y), "born": now, "way": _way,
		"left": _width(at,_way.orthogonal()), "right": _width(at,-_way.orthogonal())})

## How far the water reaches along `side` from `at`, and a bank's width on.
func _width(at: Vector2, side: Vector2) -> float:
	var to := 0.0
	for d: float in PROBES:
		var q := at+side*d
		if land.height(q.x,q.y) >= land.water_y(q.x,q.y): break
		to = d
	return minf(to+PAST,WIDEST)

## One frame: drop what has aged out and lay the ribbon, to the head while it
## is in the water (`wet` > 0).
func tick(now: float, head: Vector2, way: Vector2, wet: float) -> void:
	_way = way
	while not _sea.is_empty() and now-_sea[0].z > LIFE: _sea.pop_front()
	_feed_sea(now,head,wet)
	while not _sections.is_empty() and now-float(_sections[0].born) > LIFE: _sections.pop_front()
	if _sections.is_empty():
		if visible:
			visible = false
			_mesh.clear_surfaces()
		return
	visible = true
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var i := 0
	while i < _sections.size():
		var j := i
		while j+1 < _sections.size() and float(_sections[j+1].born)-float(_sections[j].born) <= GAP: j += 1
		_stretch(i,j,j == _sections.size()-1 and wet > 0.0,head,way,verts,uvs,index)
		i = j+1
	_mesh.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	built += 1

## The sea's points, newest first as (x, z, age, strength), from the head
## while it is on the sea.
func _feed_sea(now: float, head: Vector2, wet: float) -> void:
	var out: Array[Vector4] = []
	if wet > 0.0 and not _sea.is_empty() and land.on_sea(head): out.append(Vector4(head.x,head.y,0.0,wet))
	for i in range(_sea.size()-1,-1,-1):
		if out.size() >= SEA_POINTS: break
		var q := _sea[i]
		out.append(Vector4(q.x,q.y,now-q.z,q.w))
	land.sea_track(out,head)

## The sections i..j as one strip, capped at both ends.
func _stretch(i: int, j: int, to_head: bool, head: Vector2, way: Vector2, verts: PackedVector3Array, uvs: PackedVector2Array, index: PackedInt32Array) -> void:
	var a: Dictionary = _sections[i]
	var b: Dictionary = _sections[j]
	var back: Vector2 = _sections[mini(i+1,j)].way
	_section((a.at as Vector2)-back*CAP,float(a.y),back,float(a.left),float(a.right),0.0,false,verts,uvs,index)
	for k in range(i,j+1):
		var s: Dictionary = _sections[k]
		var w: Vector2 = (s.way as Vector2)+(_sections[mini(k+1,j)].way as Vector2)
		_section(s.at,float(s.y),w.normalized() if w.length() > 0.01 else (s.way as Vector2),float(s.left),float(s.right),1.0,true,verts,uvs,index)
	var end_way: Vector2 = way if to_head else (b.way as Vector2)
	var end: Vector2 = head+way*AHEAD if to_head else (b.at as Vector2)+end_way*CAP
	_section(end,float(b.y),end_way,float(b.left),float(b.right),1.0 if to_head else 0.0,true,verts,uvs,index)

## One cross-section, joined to the one before when `joined`.
func _section(at: Vector2, y: float, way: Vector2, left: float, right: float, v: float, joined: bool, verts: PackedVector3Array, uvs: PackedVector2Array, index: PackedInt32Array) -> void:
	var n := verts.size()
	var side := way.orthogonal()
	var l := at+side*left
	var r := at-side*right
	verts.append(Vector3(l.x,y+LIFT,l.y))
	verts.append(Vector3(r.x,y+LIFT,r.y))
	uvs.append(Vector2(-1.0,v))
	uvs.append(Vector2(1.0,v))
	if joined: index.append_array(PackedInt32Array([n-2,n-1,n,n,n-1,n+1]))
