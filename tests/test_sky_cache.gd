extends SceneTree
## The sky's disk cache (scripts/sky_cache.gd): a range's skyline and the
## world's layout read back exactly as made; the key changes with every
## input that shapes a skyline (its range's seed, stature, height, stride,
## the palette baked in it) and with the code that shapes it (any script
## reached from the roots through its preloads, the erosion among them); a
## corrupt, partial or misplaced file is found, deleted and made again; and
## a SkyRing warmed twice reads every skyline back the second time. Kept in
## a directory of its own, so the game's cache is untouched. Headless.
const SkyCache = preload("res://scripts/sky_cache.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	SkyCache.dir = "user://sky_cache_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SkyCache.dir))
	SkyCache.wipe()
	_round_trip()
	_keys()
	_corrupt()
	await _ring()
	SkyCache.wipe()
	print("PASS: sky cache" if failures == 0 else "FAIL: sky cache (%d)" % failures)
	quit(1 if failures else 0)

## The same arrays back, slot by slot, and the same layout.
func _round_trip() -> void:
	var peaks: Node3D = SkyPeaks.new()
	peaks.ring.peaks = peaks
	var cell: Vector2i = SkyPeaks.ring_cells()[3]
	var made: Array = peaks.ring.inputs(cell)
	var arrays: Array = SkyRing._shape(made)
	var key := SkyCache.key("skyline",made)
	SkyCache.save_arrays(key,arrays)
	var back := SkyCache.load_arrays(key)
	var same := back.size() == arrays.size()
	for slot in range(arrays.size()):
		if not same: break
		if arrays[slot] == null: same = back[slot] == null
		else: same = typeof(back[slot]) == typeof(arrays[slot]) and back[slot] == arrays[slot]
	var raw := 0
	for a: Variant in arrays:
		if a != null: raw += var_to_bytes(a).size()
	var on_disk := FileAccess.get_size("%s/%s.zsc" % [SkyCache.dir,key])
	check(same and (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 1000,"A skyline reads back exactly as made (%d vertices; %.0f KB on disk of %.0f KB)" % [(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),on_disk/1024.0,raw/1024.0])
	var enc: Dictionary = SkyCache.encode(arrays).slots
	check((enc[Mesh.ARRAY_COLOR] as Dictionary).has("face") and (enc[Mesh.ARRAY_TEX_UV2] as Dictionary).has("xy") and (enc[Mesh.ARRAY_TEX_UV2].xy[1] as Dictionary).has("height"),"Its colours are kept once a face, its second UV's y by the height")
	# The seasons' snow need (UV.x) and shade (UV2.x) read back exactly,
	# varied as they are.
	var need: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var shade: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var needs := {}
	var shades := {}
	for k in range(0,need.size(),97):
		needs[need[k].x] = true
		shades[shade[k].x] = true
	check(needs.size() > 3 and shades.size() > 1 and back[Mesh.ARRAY_TEX_UV] == need and back[Mesh.ARRAY_TEX_UV2] == shade,"The seasons' snow need and shade (UV.x, UV2.x: %d and %d kinds sampled) read back exactly" % [needs.size(),shades.size()])
	# A mesh from the read-back arrays matches one from the made.
	var a := SkyPeaks.SkyPeak.mesh_from(arrays,null)
	var b := SkyPeaks.SkyPeak.mesh_from(back,null)
	check(a.surface_get_array_len(0) == b.surface_get_array_len(0) and a.get_aabb() == b.get_aabb(),"Its mesh matches the one made")
	var layout := SkyWorld._compute()
	var lkey := SkyCache.key("layout",[SkyWorld._key_now()])
	SkyCache.save_value(lkey,layout)
	# A sea's summit: its faces (their snow moved by its season share) and
	# its solid, read back as made.
	var laid: Array = layout.get("summits",[])
	if laid.is_empty(): check(false,"The layout has sea summits to cache")
	else:
		var made_summit: Array = [int(laid[0].seed),float(laid[0].show),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),SkyPeaks.OFF_MAP]
		var skey := SkyCache.key("summit",made_summit)
		var first := {}
		SkyRing._make_summit_cached(made_summit,skey,first)
		var fresh := {}
		SkyRing._make_summit(int(made_summit[0]),float(made_summit[1]),made_summit[2],made_summit[3],made_summit[4],made_summit[5],made_summit[6],fresh)
		var hits_before := SkyCache.hits
		var again := {}
		SkyRing._make_summit_cached(made_summit,skey,again)
		var mesh_a := SkyPeaks.SkyPeak.mesh_from(fresh.arrays,null)
		var same_summit: bool = SkyCache.hits == hits_before+1 and var_to_bytes(again.solid) == var_to_bytes(fresh.solid) and again.sink == fresh.sink and again.over == fresh.over and again.top == fresh.top
		var faces_back: Array = (again.mesh as ArrayMesh).surface_get_arrays(0)
		check(same_summit and (again.mesh as ArrayMesh).surface_get_array_len(0) == mesh_a.surface_get_array_len(0) and faces_back[Mesh.ARRAY_VERTEX] == fresh.arrays[Mesh.ARRAY_VERTEX],"A sea's summit reads back as made: its faces, its solid, how far it is sunk (%d vertices)" % mesh_a.surface_get_array_len(0))
		var kept: Dictionary = SkyCache.load_value(skey)
		var faces: Variant = SkyCache.decode(kept.faces)
		check(faces is Array and faces[Mesh.ARRAY_TEX_UV] == fresh.arrays[Mesh.ARRAY_TEX_UV] and faces[Mesh.ARRAY_TEX_UV2] == fresh.arrays[Mesh.ARRAY_TEX_UV2] and faces[Mesh.ARRAY_COLOR] == fresh.arrays[Mesh.ARRAY_COLOR],"... its season-shifted snow need and shade exactly")
	var lback: Variant = SkyCache.load_value(lkey)
	check(lback is Dictionary and var_to_bytes(lback) == var_to_bytes(layout),"The layout reads back exactly as worked out (%d ranges)" % layout.ranges.size())
	peaks.free()

## The key moves with every input and with the code.
func _keys() -> void:
	var peaks: Node3D = SkyPeaks.new()
	peaks.ring.peaks = peaks
	var cell: Vector2i = SkyPeaks.ring_cells()[3]
	var made: Array = peaks.ring.inputs(cell)
	var key := SkyCache.key("skyline",made)
	var moved := 0
	var names := ["seed","stature","gorge","height","stride","grass","rock","gravel","snow","off map"]
	for k in range(made.size()):
		var other := made.duplicate(true)
		match typeof(other[k]):
			TYPE_INT: other[k] = int(other[k])+1
			TYPE_FLOAT: other[k] = float(other[k])+0.001
			TYPE_BOOL: other[k] = not other[k]
			TYPE_COLOR: other[k] = (other[k] as Color).lightened(0.01)
			TYPE_VECTOR3: other[k] = other[k]+Vector3(1,0,0)
			TYPE_ARRAY: other[k] = (other[k] as Array).duplicate(); other[k][0] = (other[k][0] as Color).darkened(0.01)
		if SkyCache.key("skyline",other) != key: moved += 1
		else: print("     unmoved by ",names[k])
	check(moved == made.size(),"The skyline's key changes with each of its %d inputs (%d did)" % [made.size(),moved])
	check(SkyCache.key("skyline",made) == key and SkyCache.key("layout",[SkyWorld._key_now()]) != SkyCache.key("layout",["%d|x" % (SkyWorld.seed+1)]),"The same inputs keep the same key; another seed's layout another")
	# The code: every script that shapes each kind, followed through preloads.
	var skyline := SkyCache.scripts_of("skyline",SkyCache._source)
	var layout := SkyCache.scripts_of("layout",SkyCache._source)
	var wanted := ["res://scripts/sky_peak.gd","res://scripts/terrain_erosion.gd","res://scripts/strata.gd","res://scripts/sky_ring.gd"]
	check(wanted.all(func(p: String) -> bool: return p in skyline),"A skyline's code hash reads the range's shape, its erosion and strata, and the skyline's making (%d scripts)" % skyline.size())
	check(["res://scripts/sky_world.gd","res://scripts/sky_homes.gd","res://scripts/sky_cells.gd","res://scripts/sky_peak.gd"].all(func(p: String) -> bool: return p in layout),"The layout's reads the layout, the homes, the cells and the ranges' plan (%d scripts)" % layout.size())
	var base := SkyCache.code_from(SkyCache._source,"skyline")
	check(base == SkyCache.code("skyline") and SkyCache.code("skyline") != SkyCache.code("layout"),"Each kind's code hash is steady, and its own")
	var changed := SkyCache.code_from(func(path: String) -> PackedByteArray:
		var text := SkyCache._source(path)
		if path == "res://scripts/sky_peak.gd": text.append_array("\n# const STEP := 4.5".to_utf8_buffer())
		return text,"skyline")
	var erosion := SkyCache.code_from(func(path: String) -> PackedByteArray:
		var text := SkyCache._source(path)
		if path == "res://scripts/terrain_erosion.gd": text.append_array(" ".to_utf8_buffer())
		return text,"skyline")
	var ring := SkyCache.code_from(func(path: String) -> PackedByteArray:
		var text := SkyCache._source(path)
		if path == "res://scripts/sky_ring.gd": text.append_array(" ".to_utf8_buffer())
		return text,"skyline")
	check(SkyCache.code("summit") != base and "res://scripts/sky_ring.gd" in SkyCache.scripts_of("summit",SkyCache._source),"The sea's summits are a kind of their own, read through the range's shape and the ring")
	check(changed != base and erosion != base and ring != base,"A change to the range's shape, the erosion it reads or the skyline's making gives a new code hash, so no old skyline is read")
	peaks.free()

## Broken files found, deleted and made again.
func _corrupt() -> void:
	var arrays := [PackedVector3Array([Vector3(1,2,3),Vector3(4,5,6),Vector3(7,8,9)])]
	arrays.resize(Mesh.ARRAY_MAX)
	var cases := {
		"a flipped byte":func(b: PackedByteArray) -> PackedByteArray: b[b.size()-3] = b[b.size()-3]^0x5a; return b,
		"cut short":func(b: PackedByteArray) -> PackedByteArray: return b.slice(0,b.size()/2),
		"empty":func(_b: PackedByteArray) -> PackedByteArray: return PackedByteArray(),
		"another format":func(b: PackedByteArray) -> PackedByteArray: b[3] = 0x39; return b,
	}
	for label: String in cases:
		var key := SkyCache.key("test",[label])
		SkyCache.save_arrays(key,arrays)
		var path := "%s/%s.zsc" % [SkyCache.dir,key]
		var bytes := FileAccess.get_file_as_bytes(path)
		var f := FileAccess.open(path,FileAccess.WRITE)
		f.store_buffer(cases[label].call(bytes))
		f.close()
		var broken_before := SkyCache.broken
		var calls := [0]
		var got := SkyCache.arrays(key,func() -> Array:
			calls[0] += 1
			return arrays)
		var again := SkyCache.load_arrays(key)
		check(SkyCache.broken == broken_before+1 and calls[0] == 1 and got == arrays and again == arrays,"A broken file (%s) is found, made again and kept anew" % label)
	# One under another key's name: read as broken, never as that key's.
	var a := SkyCache.key("test",["a"])
	var b := SkyCache.key("test",["b"])
	SkyCache.save_arrays(a,arrays)
	DirAccess.copy_absolute(ProjectSettings.globalize_path("%s/%s.zsc" % [SkyCache.dir,a]),ProjectSettings.globalize_path("%s/%s.zsc" % [SkyCache.dir,b]))
	check(SkyCache.load_value(b) == null and not FileAccess.file_exists("%s/%s.zsc" % [SkyCache.dir,b]),"A file under another key's name is not read")
	# Pruned: another code's entries go.
	var stale := "%s/skyline_0123456789abcdef_x.zsc" % SkyCache.dir
	var g := FileAccess.open(stale,FileAccess.WRITE)
	g.store_string("old")
	g.close()
	SkyCache.prune(true)
	check(not FileAccess.file_exists(stale) and FileAccess.file_exists("%s/%s.zsc" % [SkyCache.dir,a]),"Entries from other code are pruned, this code's kept")

## A SkyRing warmed cold makes and keeps every skyline; warmed again (a
## new world started), every one is read back, the same.
func _ring() -> void:
	SkyCache.wipe()
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	var began := Time.get_ticks_msec()
	peaks.ring.warm(peaks)
	peaks.ring.flush()
	var cold := Time.get_ticks_msec()-began
	var count: int = peaks.ring.line_count()
	var faces := {}
	for key in peaks.ring.lines: faces[key] = (peaks.ring.lines[key].node.get_node("Body").mesh as ArrayMesh).surface_get_array_len(0)
	var size := SkyCache.size()
	peaks.free()
	await process_frame
	var hits := SkyCache.hits
	var misses := SkyCache.misses
	peaks = SkyPeaks.new()
	root.add_child(peaks)
	began = Time.get_ticks_msec()
	peaks.ring.warm(peaks)
	peaks.ring.flush()
	var warm := Time.get_ticks_msec()-began
	var same: bool = peaks.ring.line_count() == count
	for key in peaks.ring.lines:
		if (peaks.ring.lines[key].node.get_node("Body").mesh as ArrayMesh).surface_get_array_len(0) != faces.get(key,-1): same = false
	print("     the skyline: %d ranges, made cold in %.1f s, read back in %.2f s; %.1f MB on disk" % [count,cold/1000.0,warm/1000.0,size/1048576.0])
	var summits: int = peaks.ring.summit_count()
	check(same and summits == SkyWorld.layout().get("summits",[]).size() and SkyCache.hits-hits == count+summits and SkyCache.misses == misses,"Warmed again, every skyline (%d) and sea summit (%d) is read back from disk, the same" % [count,summits])
	check(warm*4 < cold,"Reading back is much quicker than making (%.2f s against %.1f s)" % [warm/1000.0,cold/1000.0])
	check(size < 32*1024*1024,"The cache holds %.1f MB" % (size/1048576.0))
	peaks.free()
	await process_frame
