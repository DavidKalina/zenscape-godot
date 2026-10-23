extends SceneTree
## The endless land's fingerprint for a seed (tools/land_hash.py runs it):
## heights, meadows and the river at a fixed set of spots, and whole chunks
## as the stream builds them, hashed (SHA-256 over the raw float bits) and
## dumped one line a spot, so two machines can be compared (co-op sends only
## the seed: docs/design/endless-flight/native-land-handoff.md).
##
##   godot --headless --path . --script res://tools/land_hash.gd -- --seed=1 [--dump=FILE] [land flags]
##
## The land flags are the field's own (--land-native=0, --old-land, ...).
## Prints `LAND_HASH {json}`: the field (native or gdscript), the machine,
## the exact hash, a hash of the heights rounded to the millimetre, and the
## spots' count.

const Field = preload("res://scripts/endless/land_field.gd")
const Stream = preload("res://scripts/endless/land_stream.gd")

## The spots: a GRID_SPAN m square round the origin every GRID_STEP m at
## full detail, PATCH_N^2 points 1 m apart round each PATCHES spot, and the
## stream's chunks at CHUNK_LEVELS round CHUNK_AT.
const GRID_SPAN := 12000.0
const GRID_STEP := 48.0
const PATCH_N := 48
const PATCHES := [Vector2(-700,-300),Vector2(400,-1065),Vector2(-760,-1700),Vector2(1640,580),Vector2(-3410,-2024),Vector2(548,-731),Vector2(200,900)]
const CHUNK_AT := Vector2(-700,-300)
const CHUNK_LEVELS := [0,1,2,3,4,6]

func _init() -> void:
	var land_seed := 1
	var dump := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): land_seed = int(a.get_slice("=",1))
		elif a.begins_with("--dump="): dump = a.get_slice("=",1)
	var began := Time.get_ticks_msec()
	var f: RefCounted = Field.new(land_seed)
	var exact := HashingContext.new()
	exact.start(HashingContext.HASH_SHA256)
	var rounded := HashingContext.new()
	rounded.start(HashingContext.HASH_SHA256)
	var lines := PackedStringArray()
	var spots := 0
	var points: Array[Vector2] = []
	var n := int(GRID_SPAN/GRID_STEP)
	for j in n:
		for i in n:
			points.append(Vector2(-GRID_SPAN*0.5+i*GRID_STEP,-GRID_SPAN*0.5+j*GRID_STEP))
	for p: Vector2 in PATCHES:
		for j in PATCH_N:
			for i in PATCH_N:
				points.append(Vector2(p.x-PATCH_N*0.5+i,p.y-PATCH_N*0.5+j))
	var row := PackedFloat32Array()
	row.resize(6)
	var mm := PackedInt64Array()
	mm.resize(1)
	for p: Vector2 in points:
		var s: Vector2 = f.sample(p.x,p.y)
		row[0] = s.x
		row[1] = s.y
		row[2] = f.last_river_w
		row[3] = f.last_river_y if f.last_river_y > -INF else -1e9
		row[4] = f.last_cavity
		row[5] = f.last_ridge
		exact.update(row.to_byte_array())
		mm[0] = roundi(s.x*1000.0)
		rounded.update(mm.to_byte_array())
		if dump != "": lines.append("%s %s %s %s %s" % [p.x,p.y,_bits(s.x),"%.6f" % s.x,"%.6f" % s.y])
		spots += 1
	# Whole chunks' heights as the stream builds them (land_stream `_build`):
	# the native call when the field is native, else the field sampled the
	# same way (the same numbers, so the two fields' hashes agree).
	var chunks := 0
	for level: int in CHUNK_LEVELS:
		var size := Stream.size_of(level)
		var key := Vector3i(level,floori(CHUNK_AT.x/size),floori(CHUNK_AT.y/size))
		var c: RefCounted = Field.new(land_seed)
		var step := size/Stream.CELLS
		var x0 := key.y*size
		var z0 := key.z*size
		var hs := PackedFloat32Array()
		if c.native_on():
			var made: Dictionary = c.build_chunk(x0,z0,step,Stream.CELLS,step*Stream.SKIRT+Stream.SKIRT_MIN,Stream.RIVER_FLOW_MAX)
			hs = made.heights
		else:
			c.detail = step
			var cn := Stream.CELLS+1
			hs.resize(cn*cn)
			for j in cn:
				for i in cn:
					hs[j*cn+i] = c.sample(x0+i*step,z0+j*step).x
		exact.update(hs.to_byte_array())
		for h: float in hs:
			mm[0] = roundi(h*1000.0)
			rounded.update(mm.to_byte_array())
		if dump != "": lines.append("chunk %d %d %d %s" % [key.x,key.y,key.z,hs.to_byte_array().hex_encode().sha256_text()])
		chunks += 1
	var out := {
		"seed":land_seed,
		"field":"native" if f.native_on() else "gdscript",
		"machine":"%s %s" % [OS.get_name(),Engine.get_architecture_name()],
		"godot":Engine.get_version_info().string,
		"exact":exact.finish().hex_encode(),
		"mm":rounded.finish().hex_encode(),
		"spots":spots,
		"chunks":chunks,
		"seconds":(Time.get_ticks_msec()-began)/1000.0,
	}
	if dump != "":
		var file := FileAccess.open(dump,FileAccess.WRITE)
		if file == null: push_error("can't write %s" % dump)
		else:
			file.store_line("# land_hash %s" % JSON.stringify(out))
			file.store_string("\n".join(lines)+"\n")
			file.close()
			out.dump = dump
	print("LAND_HASH %s" % JSON.stringify(out))
	quit()

## A float's 32 bits, hex.
static func _bits(v: float) -> String:
	var a := PackedFloat32Array([v])
	return a.to_byte_array().hex_encode()
