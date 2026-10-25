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
##    "added":   [{"name": "added/air_ring_1", "kind": "air_ring", "pos": [...], "rot": [...]},
##                {"name": "chunk/ring_run_1/air_ring_1", ..., "on": "island/near"}],
##    "deleted": ["ring_route/chain_slab_2"],
##    "islands": {"island/near": {"pos": [x, y, z], "rot": [x, y, z]}},
##    "sizes":   {"ring_route/ring_a": 2.5, "foot_route/bob_slab_1": [3.0, 0.7, 2.8]},
##    "knobs":   {"stair_clouds/slab_cut": {"count": 6, "rise": 1.2}},
##    "tunes":   {"ring_route/ring_a": {"boost": 8.0}, "foot_route/drift_slab_1": {"pace": 3.2}}}
## A piece's tunes (its own knobs: a ring's boost, a bob slab's spring
## pumps, a drifting slab's pace; the node's `layout_tunes`) are kept only
## off their coded values; an added piece keeps its own as "tunes" (a bob
## slab's pumps as "pumps").
## A build's knobs (scripts/layout_knobs.gd) are kept only off their
## defaults; the build reads them when it places its pieces.
## An added piece's name is `added/<kind>_<n>`, or `chunk/<chunk>_<n>/...`
## for a stamped chunk (scripts/layout_chunks.gd). One with "on" belongs to
## that island (moves with it; others are free); it is saved where it stands
## in the world and put back there after the islands' moves (`reapply`).
## A size (the world view's [ / ]) is a ring's radius or a slab's block
## (m), only for those off their coded size; an added piece keeps its own
## as "size". A node takes it by `layout_size` / `layout_resize`.
## An island's entry (scripts/world_islands.gd) is its move from where it
## is coded (the whole island and what stands on it carried by it), only
## for islands off their coded place; a file without them has none.
## `rot` is the basis's Euler angles in degrees (Godot's YXZ order). Each
## moved object is kept at its absolute transform; nothing follows it.
##
## Kinds: "air_ring", "bob_slab", "sink_slab" and "drift_slab" (foot_pieces.gd
## pieces, their rest pose set by `layout_place`); every other kind ("land",
## a KitLand crag; "balustrade", "rope", "stones": foot_pieces.gd's named
## pieces) is built in world space and moved by its node's offset from its
## coded transform (a rope's anchor follows its node, swing_rope.gd). The
## POSED kinds ("piece", a RuinKit piece such as a kit cache; "token", a
## token's holder) stand at their own transform: their coded one is where
## the node itself stood, and a move sets the node's world transform. `spawn` makes the
## kinds the file can add (air_ring, bob_slab, islet: a small free islet,
## scripts/shared/islet.gd, its size and seed its tunes).

const VERSION := 1
const ADDABLE := ["air_ring","bob_slab","islet"]
const POSED := ["piece","token"]

## The scene's file, its parsed data, and what was placed under each name:
## {node, kind, coded: Transform3D, host, pumps}.
static var path := ""
static var data := {}
static var entries := {}
## The builds' knobs off their defaults: build -> {key: value}.
static var knobs := {}

## A fresh start for scene `scene_id`: its file read (if there is one), the
## names placed before forgotten.
static func begin(scene_id: String) -> void:
	path = "res://layouts/%s.json" % scene_id
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--layout="): path = a.substr(9)
	entries = {}
	knobs = {}
	data = {"version":VERSION,"moved":{},"added":[],"deleted":[]}
	if not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("layout %s: not a JSON object, ignored" % path)
		return
	var d: Dictionary = parsed
	for k: String in ["moved","added","deleted","islands","sizes","tunes"]:
		if d.has(k): data[k] = d[k]
	if d.get("knobs") is Dictionary: knobs = (d.knobs as Dictionary).duplicate(true)

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

## True for a name the file keeps under "added" (not a coded piece's).
static func is_added(name: String) -> bool:
	return name.begins_with("added/") or name.begins_with("chunk/")

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
	_track_tunes(name,node,e)
	if not node.has_method("layout_size"): return
	e["size0"] = node.layout_size()
	var sizes: Dictionary = data.get("sizes",{})
	if sizes.has(name): node.layout_resize(size_from_json(sizes[name],e.size0))

## `name`'s tunes kept at track: their coded values, the file's applied.
static func _track_tunes(name: String, node: Node, e: Dictionary) -> void:
	if not node.has_method("layout_tunes"): return
	var t0 := {}
	for s: Array in node.layout_tunes(): t0[str(s[0])] = float(node.layout_tune(str(s[0])))
	if t0.is_empty(): return
	e["tune0"] = t0
	var saved: Dictionary = data.get("tunes",{})
	if saved.get(name) is Dictionary: retune_all(name,saved[name])

## `name`'s tune `key` set to `v` (a bob slab's pumps kept for its copies too).
static func retune(name: String, key: String, v: float) -> void:
	var e: Dictionary = entries[name]
	(e.node as Node).layout_retune(key,v)
	if key == "pumps": e["pumps"] = float((e.node as Node).layout_tune(key))

static func retune_all(name: String, vals: Dictionary) -> void:
	var t0: Dictionary = entries[name].get("tune0",{})
	for k: String in vals:
		if t0.has(k): retune(name,k,float(vals[k]))

## `name`'s tunes now: key -> value ({} none).
static func tunes_now(name: String) -> Dictionary:
	var e: Dictionary = entries[name]
	var out := {}
	for k: String in e.get("tune0",{}): out[k] = float((e.node as Node).layout_tune(k))
	return out

## `name`'s tunes off their coded values (`skip`: keys kept elsewhere).
static func tunes_off(name: String, skip := []) -> Dictionary:
	var e: Dictionary = entries[name]
	var t0: Dictionary = e.get("tune0",{})
	var out := {}
	var now := tunes_now(name)
	for k: String in now:
		if k in skip: continue
		if absf(float(now[k])-float(t0[k])) > 0.004: out[k] = snappedf(float(now[k]),0.001)
	return out
## `name`'s size now (a ring's radius, a slab's block), null if it has none.
static func size_of(name: String) -> Variant:
	var node: Node = entries[name].node
	return node.layout_size() if node.has_method("layout_size") else null

## A size as the file keeps it (a number, or [x, y, z]).
static func size_to_json(v: Variant) -> Variant:
	if v is Vector3: return [snappedf(v.x,0.001),snappedf(v.y,0.001),snappedf(v.z,0.001)]
	return snappedf(float(v),0.001)

## A size read from the file, shaped as `like` (a Vector3 or a float).
static func size_from_json(d: Variant, like: Variant) -> Variant:
	if like is Vector3:
		if d is Array and (d as Array).size() == 3: return Vector3(float(d[0]),float(d[1]),float(d[2]))
		return like
	return float(d) if d is float or d is int else like

static func _same_size(a: Variant, b: Variant) -> bool:
	if a is Vector3 and b is Vector3: return (a as Vector3).distance_to(b) < 0.005
	return absf(float(a)-float(b)) < 0.005

## Where `name`'s object stands now (by its own measure: a ring's or a
## slab's rest pose, a land's coded transform carried by its offset).
static func current(name: String) -> Transform3D:
	var e: Dictionary = entries[name]
	var node: Node3D = e.node
	if node.has_method("layout_pose"): return node.layout_pose()
	if str(e.kind) in POSED: return node.global_transform if node.is_inside_tree() else node.transform
	return node.transform*(e.coded as Transform3D)

## `name`'s object set at `t` (only its own transform: nothing rebuilt).
static func apply(name: String, t: Transform3D) -> void:
	var e: Dictionary = entries[name]
	var node: Node3D = e.node
	if node.has_method("layout_place"): node.layout_place(t)
	elif str(e.kind) in POSED:
		if node.is_inside_tree(): node.global_transform = t
		else: node.transform = t
	else: node.transform = t*(e.coded as Transform3D).affine_inverse()

## The file's moved names put back where it has them (after the islands'
## saved moves carried what stands on them: the file keeps where each
## stands in the world). Returns the nodes set.
static func reapply() -> Array:
	var out: Array = []
	var moved: Dictionary = data.get("moved",{})
	for name: String in moved:
		if not entries.has(name) or not is_instance_valid(entries[name].node): continue
		apply(name,from_json(moved[name]))
		out.append(entries[name].node)
	# The added pieces an island carried (their "on").
	for a: Dictionary in data.get("added",[]):
		var name := str(a.get("name",""))
		if str(a.get("on","")) == "" or not entries.has(name) or not is_instance_valid(entries[name].node): continue
		apply(name,from_json(a))
		out.append(entries[name].node)
	return out

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
		spawn(host,str(a.name),kind,from_json(a),float(a.get("pumps",0.0)),a.get("size",null),str(a.get("on","")),a.get("tunes",{}) if a.get("tunes") is Dictionary else {})

## A new `kind` piece on `host` at `t`, tracked as `name`; `size` (as the
## file keeps it, or a node's own) if given; `on`: the island it belongs to
## ("" free).
static func spawn(host: Node3D, name: String, kind: String, t: Transform3D, pumps := 0.0, size: Variant = null, on := "", tunes := {}) -> Node3D:
	var seed_value := absi(hash(name))%100000
	var node: Node3D = null
	if kind == "air_ring": node = host.air_ring(t.origin,seed_value,0.0)
	elif kind == "bob_slab":
		node = host.bob_slab(t.origin,Vector3(2.3,0.7,2.2),0.0,seed_value)
		if pumps > 0.0: node.spring_pumps = pumps
	elif kind == "islet":
		node = preload("res://scripts/shared/islet.gd").new()
		node.name = name.replace("/","_")
		host.add_child(node)
		node.setup(t)
	if node == null: return null
	node.layout_place(t)
	var extra := {"host":host}
	if kind == "bob_slab": extra["pumps"] = float(node.spring_pumps)
	if on != "": extra["on"] = on
	track(name,node,kind,t,extra)
	if size != null and node.has_method("layout_resize"): node.layout_resize(size_from_json(size,node.layout_size()) if not size is Vector3 else size)
	if not tunes.is_empty(): retune_all(name,tunes)
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
	var sizes := {}
	var tunes := {}
	var added: Array = []
	var names: Array = entries.keys()
	names.sort()
	for name: String in names:
		var e: Dictionary = entries[name]
		if not is_instance_valid(e.node): continue
		var t := current(name)
		if is_added(name):
			var a := to_json(t)
			a["name"] = name
			a["kind"] = e.kind
			if e.has("pumps") and float(e.pumps) != float(preload("res://scripts/shared/bob_slab.gd").SPRING_PUMPS): a["pumps"] = e.pumps
			if e.has("size0") and not _same_size(size_of(name),e.size0): a["size"] = size_to_json(size_of(name))
			if str(e.get("on","")) != "": a["on"] = str(e.on)
			var off := tunes_off(name,["pumps"])
			if not off.is_empty(): a["tunes"] = off
			added.append(a)
		else:
			if not _same(t,e.coded): moved[name] = to_json(t)
			if e.has("size0") and not _same_size(size_of(name),e.size0): sizes[name] = size_to_json(size_of(name))
			var off := tunes_off(name)
			if not off.is_empty(): tunes[name] = off
	var kept: Array = []
	for g: String in gone:
		if not is_added(g) and not g in kept: kept.append(g)
	kept.sort()
	data = {"version":VERSION,"moved":moved,"added":added,"deleted":kept}
	var isl := {}
	var isl_names: Array = moved_islands.keys()
	isl_names.sort()
	for name: String in isl_names:
		if not _same(moved_islands[name],Transform3D.IDENTITY): isl[name] = to_json(moved_islands[name])
	if not isl.is_empty(): data["islands"] = isl
	if not sizes.is_empty(): data["sizes"] = sizes
	if not tunes.is_empty(): data["tunes"] = tunes
	if not knobs.is_empty(): data["knobs"] = knobs.duplicate(true)
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
	for block: String in ["islands","sizes","tunes","knobs"]:
		var rows_of: Dictionary = d.get(block,{})
		if rows_of.is_empty(): continue
		var rows := PackedStringArray()
		for k: String in rows_of: rows.append("\t\t%s: %s" % [JSON.stringify(k),JSON.stringify(rows_of[k])])
		out += ",\n\t\"%s\": {\n%s\n\t}" % [block,",\n".join(rows)]
	return out+"\n}\n"

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
