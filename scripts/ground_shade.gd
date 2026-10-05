extends Node
## The shade trees lay on the ground (docs/scenic/grass-look.md, "Round
## five"): a soft field over the plate, darkest under a crown and thinning
## past its drip line, that the ground's shader (shaders/ground_look.gdshaderinc,
## zs_ground_shaded) turns into the darker, cooler floor of a wood.
## A lone tree leaves a soft pool; a grove's pools run together.
##
## The field is baked from the tree records (NativeTerrainData.objects) into
## a small two-channel texture, the global `zs_ground_shade`: red the shade,
## green held at 0 so an unset texture (Godot's white default) reads as no
## shade. It is read again only when the records change (at most every
## READ_SECONDS), and baked only when the trees among them changed, on the
## worker pool, so painting flowers costs a walk of the records and
## painting a wood never holds a frame.
## Made and owned by NativeChunkEditor (`ground_shade`), so every native
## world has it.

## Texels a side over the maps' span (Plate.MAP_SPAN, 32 m): 0.5 m each.
const Plate := preload("res://scripts/plate.gd")
const SIZE := Plate.SHADE_SIZE
const HALF := Plate.MAP_HALF
const TEXEL := HALF * 2.0 / SIZE
## Each kind's crown radius at scale 1 (m), from the catalog meshes' bounds.
## Desert plants (joshua, cactus) cast too thin a shade to darken the sand.
const CROWN := {"tree":0.65,"layered_tree":2.7,"redwood":2.3,"broadleaf":0.95,"bigfoot_tree":2.0,"birch":0.75,"willow":1.3,"juniper":1.2,"shrub":0.35}
## How far past the crown the shade thins out (share of the radius, plus m).
const REACH := 1.7
const REACH_PAD := 0.8
## Shade under the heart of one crown; groves add up to 1.
const DEPTH := 0.62
## Seconds between reads of the records (a stroke changes them every frame).
const READ_SECONDS := 0.2

var editor: Node
var texture: ImageTexture
## The image last handed to the texture.
var image: Image
## The baked field (SIZE x SIZE, 0..1), for probes and tests.
var field := PackedFloat32Array()
var bakes := 0
## Microseconds the last bake took on its worker.
var last_bake_usec := 0
var _revision := -1
var _count := -1
var _trees := PackedFloat32Array()
var _read_in := 0.0
## The bake in flight on the worker pool (-1 none), what it bakes, and what
## it hands back (written on the worker, read once it is done).
var _task := -1
var _baking := PackedFloat32Array()
var _baked := PackedFloat32Array()
var _baked_usec := 0

func setup(owner_editor: Node) -> void:
	Plate.publish_shader_globals()
	editor = owner_editor
	name = "GroundShade"
	field.resize(SIZE * SIZE)
	field.fill(0.0)
	image = _image(field)
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("zs_ground_shade", texture)
	refresh()

func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task): _collect()
	_read_in -= delta
	if _read_in > 0.0: return
	refresh()

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## Reads the records if they changed, and starts a bake on the worker pool
## if the trees among them did (one at a time; a change while one is in
## flight is read again once it lands).
func refresh() -> void:
	if editor == null or editor.get("data") == null or _task >= 0: return
	var data = editor.data
	if data.objects_revision == _revision and data.objects.size() == _count: return
	_read_in = READ_SECONDS
	_revision = data.objects_revision
	_count = data.objects.size()
	var trees := tree_list(data.objects)
	if trees == _trees: return
	_trees = trees
	_baking = trees
	_task = WorkerThreadPool.add_task(_bake_on_worker, false, "Ground shade")

func _bake_on_worker() -> void:
	var start := Time.get_ticks_usec()
	_baked = bake(_baking)
	_baked_usec = Time.get_ticks_usec() - start

## Lays a finished bake into the texture the ground reads.
func _collect() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	field = _baked
	last_bake_usec = _baked_usec
	image = _image(field)
	texture.update(image)
	bakes += 1
	# Anything that changed while it baked is read on the next beat.
	_read_in = 0.0

## Reads the records now and waits for any bake (probes and tests).
func finish() -> void:
	if _task >= 0: _collect()
	refresh()
	if _task >= 0: _collect()

## The trees among `objects` as (x, z, crown radius) triples, plate metres.
static func tree_list(objects: Array) -> PackedFloat32Array:
	var trees := PackedFloat32Array()
	for item: Dictionary in objects:
		var crown: float = CROWN.get(str(item.get("asset", "")), 0.0)
		if crown <= 0.0: continue
		trees.append(float(item.x))
		trees.append(float(item.z))
		trees.append(crown * float(item.get("scale", 1.0)))
	return trees

## The shade field for `trees` (tree_list triples): each crown a soft pool
## of DEPTH, flat-topped under the crown and easing out past it; pools
## overlap toward 1 rather than adding past it.
static func bake(trees: PackedFloat32Array) -> PackedFloat32Array:
	var light := PackedFloat32Array()
	light.resize(SIZE * SIZE)
	light.fill(1.0)
	for t in range(0, trees.size(), 3):
		var cx := trees[t]
		var cz := trees[t + 1]
		var crown := trees[t + 2]
		var reach := crown * REACH + REACH_PAD
		var x0 := maxi(0, int(floor((cx - reach + HALF) / TEXEL)))
		var x1 := mini(SIZE - 1, int(floor((cx + reach + HALF) / TEXEL)))
		var z0 := maxi(0, int(floor((cz - reach + HALF) / TEXEL)))
		var z1 := mini(SIZE - 1, int(floor((cz + reach + HALF) / TEXEL)))
		for z in range(z0, z1 + 1):
			var dz := (z + 0.5) * TEXEL - HALF - cz
			for x in range(x0, x1 + 1):
				var dx := (x + 0.5) * TEXEL - HALF - cx
				var d := sqrt(dx * dx + dz * dz)
				if d >= reach: continue
				var s := 1.0 - smoothstep(crown * 0.5, reach, d)
				var i := z * SIZE + x
				light[i] *= 1.0 - DEPTH * s
	for i in range(light.size()): light[i] = 1.0 - light[i]
	return light

## The shade at plate point `p` (bilinear, as the shader reads it).
func shade_at(p: Vector2) -> float:
	return field_at(field, p)

## `values` (a baked field) at plate point `p`, bilinear; 0 off the plate.
static func field_at(values: PackedFloat32Array, p: Vector2) -> float:
	if absf(p.x) > HALF or absf(p.y) > HALF: return 0.0
	var t := (p + Vector2.ONE * HALF) / TEXEL - Vector2.ONE * 0.5
	var i := Vector2i(floori(t.x), floori(t.y))
	var f := t - Vector2(i)
	var a := values[clampi(i.y, 0, SIZE - 1) * SIZE + clampi(i.x, 0, SIZE - 1)]
	var b := values[clampi(i.y, 0, SIZE - 1) * SIZE + clampi(i.x + 1, 0, SIZE - 1)]
	var c := values[clampi(i.y + 1, 0, SIZE - 1) * SIZE + clampi(i.x, 0, SIZE - 1)]
	var d := values[clampi(i.y + 1, 0, SIZE - 1) * SIZE + clampi(i.x + 1, 0, SIZE - 1)]
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)

static func _image(values: PackedFloat32Array) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(SIZE * SIZE * 2)
	for i in range(values.size()):
		bytes[i * 2] = int(round(clampf(values[i], 0.0, 1.0) * 255.0))
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RG8, bytes)
