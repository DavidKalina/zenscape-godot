extends RefCounted
## Named placements a scene's layout file can override (docs/design/
## layout-edit/layout-edit-handoff.md). A placer asks `xform(name, coded)`
## for each object it places (its coded transform back unless the file moved
## it), skips the names `deleted` lists, and `track`s what it placed, so the
## in-game layout editor (scripts/layout_edit.gd) can find, move and save
## it. With no file, every answer is the coded one.
##
## The file (res://layouts/<scene>.json, or `--layout=<path>`):
##   {"version": 1,
##    "moved":   {"ring_route/ring_a": {"pos": [x, y, z], "rot": [x, y, z]}},
##    "added":   [{"name": "added/air_ring_1", "kind": "air_ring", "pos": [...], "rot": [...]}],
##    "deleted": ["ring_route/chain_slab_2"],
##    "islands": {"island/near": {"pos": [x, y, z], "rot": [x, y, z]}}}
## An island's entry (scripts/world_islands.gd) is its move from where it
## is coded (the whole island and what stands on it carried by it), only
## for islands off their coded place; a file without them has none.
## `rot` is the basis's Euler angles in degrees (Godot's YXZ order). Each
## moved object is kept at its absolute transform; nothing follows it.
##
## Kinds: "air_ring" and "bob_slab" (foot_pieces.gd pieces, their rest pose
## set by `layout_place`), "land" (a KitLand crag built in world space: its
## node is offset by the move from its coded transform). `spawn` makes the
## kinds the file can add (air_ring, bob_slab).

const VERSION := 1
const ADDABLE := ["air_ring","bob_slab"]

## The scene's file, its parsed data, and what was placed under each name:
## {node, kind, coded: Transform3D, host, pumps}.
static var path := ""
static var data := {}
static var entries := {}

## A fresh start for scene `scene_id`: its file read (if there is one), the
## names placed before forgotten.
static func begin(scene_id: String) -> void:
	path = "res://layouts/%s.json" % scene_id
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--layout="): path = a.substr(9)
	entries = {}
	data = {"version":VERSION,"moved":{},"added":[],"deleted":[]}
	if not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("layout %s: not a JSON object, ignored" % path)
		return
	var d: Dictionary = parsed
	for k: String in ["moved","added","deleted","islands"]:
		if d.has(k): data[k] = d[k]

## The file's island moves: name -> Transform3D (from coded).
static func islands() -> Dictionary:
	var out := {}
	var saved: Dictionary = data.get("islands",{})
	for name: String in saved: out[name] = from_json(saved[name])
	return out

## The transform `name` stands at: the file's, else `coded`.
static func xform(name: String, coded: Transform3D) -> Transform3D:
	var moved: Dictionary = data.get("moved",{})
	if not moved.has(name): return coded
	return from_json(moved[name])

static func deleted(name: String) -> bool:
	var gone: Array = data.get("deleted",[])
	return name in gone

## What a placer placed under `name` (its coded transform: where it stands
## with no file). `extra` keeps what `spawn` needs to copy it (the host, a
## slab's spring pumps).
static func track(name: String, node: Node3D, kind: String, coded: Transform3D, extra := {}) -> void:
	var e := {"node":node,"kind":kind,"coded":coded}
	e.merge(extra)
	entries[name] = e
	node.set_meta("layout_name",name)

## Where `name`'s object stands now (by its own measure: a ring's or a
## slab's rest pose, a land's coded transform carried by its offset).
static func current(name: String) -> Transform3D:
	var e: Dictionary = entries[name]
	var node: Node3D = e.node
	if node.has_method("layout_pose"): return node.layout_pose()
	if str(e.kind) == "land": return node.transform*(e.coded as Transform3D)
	return node.global_transform

## `name`'s object set at `t` (only its own transform: nothing rebuilt).
static func apply(name: String, t: Transform3D) -> void:
	var e: Dictionary = entries[name]
	var node: Node3D = e.node
	if node.has_method("layout_place"): node.layout_place(t)
	elif str(e.kind) == "land": node.transform = t*(e.coded as Transform3D).affine_inverse()
	else: node.global_transform = t

## A land's outline (x, z) as moved by `t` from `coded` (for the turf's
## registration: flora and the gap test read world outlines).
static func moved_outline(outline: PackedVector2Array, coded: Transform3D, t: Transform3D) -> PackedVector2Array:
	var m := t*coded.affine_inverse()
	if m.is_equal_approx(Transform3D.IDENTITY): return outline
	var out := PackedVector2Array()
	for p: Vector2 in outline:
		var q := m*Vector3(p.x,0.0,p.y)
		out.append(Vector2(q.x,q.z))
	return out

## The file's added objects made on `host` (foot_pieces.gd), each tracked.
static func build_added(host: Node3D) -> void:
	var added: Array = data.get("added",[])
	for a: Dictionary in added:
		var kind := str(a.get("kind",""))
		if not kind in ADDABLE: continue
		spawn(host,str(a.name),kind,from_json(a),float(a.get("pumps",0.0)))

## A new `kind` piece on `host` at `t`, tracked as `name`.
static func spawn(host: Node3D, name: String, kind: String, t: Transform3D, pumps := 0.0) -> Node3D:
	var seed_value := absi(hash(name))%100000
	var node: Node3D = null
	if kind == "air_ring": node = host.air_ring(t.origin,seed_value,0.0)
	elif kind == "bob_slab":
		node = host.bob_slab(t.origin,Vector3(2.3,0.7,2.2),0.0,seed_value)
		if pumps > 0.0: node.spring_pumps = pumps
	if node == null: return null
	node.layout_place(t)
	var extra := {"host":host}
	if kind == "bob_slab": extra["pumps"] = float(node.spring_pumps)
	track(name,node,kind,t,extra)
	return node

## A name for a new `kind` not yet in use.
static func fresh_name(kind: String) -> String:
	var i := 1
	while entries.has("added/%s_%d" % [kind,i]): i += 1
	return "added/%s_%d" % [kind,i]

## The file written from what is tracked now: every coded object off its
## coded transform as moved, the added ones as added, `gone` as deleted,
## `moved_islands` (name -> Transform3D from coded) as islands, those off
## their coded place. Returns the error.
static func save(gone: Array, moved_islands := {}) -> Error:
	var moved := {}
	var added: Array = []
	var names: Array = entries.keys()
	names.sort()
	for name: String in names:
		var e: Dictionary = entries[name]
		if not is_instance_valid(e.node): continue
		var t := current(name)
		if name.begins_with("added/"):
			var a := to_json(t)
			a["name"] = name
			a["kind"] = e.kind
			if e.has("pumps") and float(e.pumps) != float(preload("res://scripts/interactables/bob_slab.gd").SPRING_PUMPS): a["pumps"] = e.pumps
			added.append(a)
		elif not _same(t,e.coded): moved[name] = to_json(t)
	var kept: Array = []
	for g: String in gone:
		if not g.begins_with("added/") and not g in kept: kept.append(g)
	kept.sort()
	data = {"version":VERSION,"moved":moved,"added":added,"deleted":kept}
	var isl := {}
	var isl_names: Array = moved_islands.keys()
	isl_names.sort()
	for name: String in isl_names:
		if not _same(moved_islands[name],Transform3D.IDENTITY): isl[name] = to_json(moved_islands[name])
	if not isl.is_empty(): data["islands"] = isl
	if path.begins_with("res://"): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	else: DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(_text(data))
	f.close()
	return OK

## The file's text: one object a line, to read and diff by hand.
static func _text(d: Dictionary) -> String:
	var lines := PackedStringArray()
	var moved: Dictionary = d.moved
	var keys: Array = moved.keys()
	for k: String in keys: lines.append("\t\t%s: %s" % [JSON.stringify(k),JSON.stringify(moved[k])])
	var added := PackedStringArray()
	for a: Dictionary in d.added: added.append("\t\t"+JSON.stringify(a))
	var gone := PackedStringArray()
	for g: String in d.deleted: gone.append("\t\t"+JSON.stringify(g))
	var out := "{\n\t\"version\": %d,\n" % VERSION
	out += "\t\"moved\": {\n%s\n\t},\n" % ",\n".join(lines) if not lines.is_empty() else "\t\"moved\": {},\n"
	out += "\t\"added\": [\n%s\n\t],\n" % ",\n".join(added) if not added.is_empty() else "\t\"added\": [],\n"
	out += "\t\"deleted\": [\n%s\n\t]" % ",\n".join(gone) if not gone.is_empty() else "\t\"deleted\": []"
	var isl: Dictionary = d.get("islands",{})
	if isl.is_empty(): return out+"\n}\n"
	var rows := PackedStringArray()
	for k: String in isl: rows.append("\t\t%s: %s" % [JSON.stringify(k),JSON.stringify(isl[k])])
	return out+",\n\t\"islands\": {\n%s\n\t}\n}\n" % ",\n".join(rows)

static func _same(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.005 and a.basis.get_euler().distance_to(b.basis.get_euler()) < 0.001

static func to_json(t: Transform3D) -> Dictionary:
	var e := t.basis.get_euler()
	return {"pos":[snappedf(t.origin.x,0.001),snappedf(t.origin.y,0.001),snappedf(t.origin.z,0.001)],
		"rot":[snappedf(rad_to_deg(e.x),0.01),snappedf(rad_to_deg(e.y),0.01),snappedf(rad_to_deg(e.z),0.01)]}

static func from_json(d: Dictionary) -> Transform3D:
	var p: Array = d.get("pos",[0.0,0.0,0.0])
	var r: Array = d.get("rot",[0.0,0.0,0.0])
	var b := Basis.from_euler(Vector3(deg_to_rad(float(r[0])),deg_to_rad(float(r[1])),deg_to_rad(float(r[2]))))
	return Transform3D(b,Vector3(float(p[0]),float(p[1]),float(p[2])))
