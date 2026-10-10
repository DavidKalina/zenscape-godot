extends RefCounted
## The Genesis canvas: a quiet, misty, gently undulating plain to create on.
## It is still a real world with a curated palette family (scripts/
## palette_families.gd), a sky, and living weather; only the land is empty.
## `world` returns the same shape the cozy generator does (seed, terrain,
## mood, visuals, palette), so `CozyWorldGenerator.apply_mood` dresses it.
const Families = preload("res://scripts/palette_families.gd")
const Generator = preload("res://scripts/cozy_world_generator.gd")
## The creation brushes, in palette order; number keys follow it (1 land,
## 2 water, 3 meadow, 4 forest, 5 path, 6 wind). This is the one list: the editor
## (NativeChunkEditor holds one brush of each `script`; its "land" tool paints
## with whichever is in hand), the shell's number keys (studies/cozy_worlds.gd)
## and the palette (scripts/creation_palette.gd) all read it. Each entry:
## - `brush_id`: the brush; `NativeChunkEditor.select_brush(brush_id)` puts it
##   in hand, and stroke signals carry it as their mode;
## - `title`: the palette's name for it;
## - `hint`: the one-line how-to under the palette;
## - `script`: the brush (scripts/creation_brush.gd documents the interface).
const BRUSHES := [
	{"brush_id":"land","title":"Land","hint":"Drag to raise land  ·  Shift-drag lowers","script":"res://scripts/land_brush.gd"},
	{"brush_id":"water","title":"Water","hint":"Drag to pour water  ·  it runs downhill and pools  ·  Shift-drag drains","script":"res://scripts/water_brush.gd"},
	{"brush_id":"meadow","title":"Meadow","hint":"Drag to lay a meadow  ·  Shift-drag lifts it","script":"res://scripts/meadow_brush.gd"},
	{"brush_id":"forest","title":"Forest","hint":"Sweep to lay pollen in the air, let go and it drifts down  ·  hold still to thicken  ·  the wind and the land decide  ·  Shift-drag clears","script":"res://scripts/forest_brush.gd"},
	{"brush_id":"path","title":"Path","hint":"Drag to wear a path  ·  Shift-drag grows it back","script":"res://scripts/path_brush.gd"},
	{"brush_id":"wind","title":"Wind","hint":"Swipe to send a gust  ·  a quick swipe blows harder  ·  Press and let go for a burst","script":"res://scripts/wind_brush.gd"},
]

static func brush_ids() -> Array:
	return BRUSHES.map(func(entry: Dictionary) -> String: return entry.brush_id)

## The brush a number key picks (KEY_1 is the first), or "" for none.
static func brush_for_key(keycode: int) -> String:
	var index := keycode-KEY_1
	return BRUSHES[index].brush_id if index >= 0 and index < BRUSHES.size() else ""

static func brush_entry(id: String) -> Dictionary:
	for entry: Dictionary in BRUSHES:
		if entry.brush_id == id: return entry
	return {}

static func brush_hint(id: String) -> String:
	return str(brush_entry(id).get("hint",""))

## The plain's colours: the original Fidelity scene's painted green ground,
## earth and bare grey-brown rock (SceneLook.DEFAULT_COLORS), under a clear
## blue day sky. Generated worlds keep drawing from the palette families.
const FIDELITY := {"grass":"5d9e53","foliage":"47764a","rock":"8d8577","earth":"6a503e","water":"397d79",
	"sky":"78aacb","horizon":"b3cad3","glow":"f3dfba","sun":"ffcf8f"}
const FIDELITY_LIGHT := {"ambient":"8fb3d9","bounce":"4a5240","rim":"7fa8c9"}
const FIDELITY_TITLE := "Painted green"

## A seeded fair morning or day in Fidelity's colours, with a clear sky and a
## little low mist.
static func world(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["genesis",seed_value])
	# Morning or full day: dusk and night hide the land.
	var hour := 0 if rng.randf() < 0.35 else 1
	var phase := rng.randf_range(0.31,0.35) if hour == 0 else rng.randf_range(0.38,0.5)
	var colors := fidelity_colors(rng,hour)
	var encoded := {}
	for key in colors: encoded[key] = colors[key].to_html(false)
	var mood := {"colors":encoded,"phase":phase,"weather":"fair","wind":rng.randf_range(.15,.35),"wind_direction":rng.randf_range(0,360),
		"clouds":rng.randf_range(.12,.26),"mist":rng.randf_range(.16,.26),"haze":rng.randf_range(.1,.16),"rays":rng.randf_range(.45,.8),
		"summit_mist":rng.randf_range(.12,.22),"strength":rng.randf_range(.72,.84),"exposure":rng.randf_range(1.04,1.1),
		"ambient_energy":rng.randf_range(1.35,1.6),"sun_energy":rng.randf_range(.95,1.1),"night_fill":1.45,"cold":0.0,"snow":0.0,
		"ice":0.0,"wet":0.0,"humidity":.45,"autumn":0.0,"aurora":0.0,"rainbow":0.0}
	# A thin ground mist that strokes part, well short of a misty world's.
	var visuals := {"fog_density":rng.randf_range(.12,.2),"fog_height":rng.randf_range(2.5,3.5),
		"peak_density":rng.randf_range(.08,.14),"peak_altitude":rng.randf_range(3.5,5.5),"rock_style":1,"rock_detail":.65}
	return {"seed":seed_value,"terrain":{},"mood":mood,"visuals":visuals,"palette":"fidelity","genesis":true}

## Fidelity's land exactly, and its sky drawn for the hour like a family's.
static func fidelity_colors(rng: RandomNumberGenerator, hour: int) -> Dictionary:
	var colors := Families.vary(rng,FIDELITY,hour,false)
	for key in Families.LAND: colors[key] = Color(FIDELITY[key])
	Families.derive(colors)
	for key in FIDELITY_LIGHT: colors[key] = Color(FIDELITY_LIGHT[key])
	return colors

## "Painted green" for the classic badge; older plains name their family.
static func palette_title(world_value: Dictionary) -> String:
	var palette := str(world_value.get("palette",""))
	if palette == "fidelity": return FIDELITY_TITLE
	var family: Dictionary = Families.FAMILIES.get(palette,{})
	return str(family.get("title","Open plain"))

## Standing-blade cover on the plain (`data.blades`, eight tufts a cell at
## 1.0): the base, and how much tussocks add. None: the plain's grass is the
## faceted painted ground, as in Fidelity (user choice, 2026-09-26).
const GENESIS_BLADES := Vector2(0.0,0.0)
## Flower-drift cover (`data.meadow`): each of its tufts in four carries a
## flower. None, for the same reason.
const GENESIS_FLOWERS := 0.0

## The plain as an island: its outline from its seed (scripts/
## island_outline.gd, which sizes it by the seed too, unless asked for a
## size: a new world's first island is `first_size`), and its ground easing
## to RIM_HEIGHT metres over the last RIM_EASE metres before the shore, so
## every shore meets its wall at one height instead of wherever the swells
## stood. Points off the island stand at the rim height as well. Run with
## --square-islands for the full square plate as before.
const RIM_HEIGHT := 0.2
const RIM_EASE := 2.5

## The size a new world's first island is asked for, whatever its seed
## (scripts/island_outline.gd `first_size`): room to learn the tools on.
static func first_size() -> float:
	return preload("res://scripts/island_outline.gd").first_size()

static func square_islands() -> bool:
	return "--square-islands" in preload("res://scripts/launch_args.gd").user_args()

## Heights, grass, a carpet of standing blades and a few flower drifts for a
## blank plain.
## Everything else (objects, water, recipe) is cleared. `origin` is the
## chunk's centre in world metres: atlas chunks (scripts/chunk_atlas.gd) sample
## one field, so neighbouring plains roll into each other. `islanded` gives
## the plain its seed's outline (unless --square-islands); atlas chunks,
## which meet their neighbours, stay square. `size` (0..1) asks for an
## island's size; left out, the seed's own.
static func shape(data: NativeTerrainData, seed_value: int, origin := Vector2.ZERO, islanded := true, size := -1.0, outline := PackedByteArray()) -> void:
	var mask := PackedByteArray()
	if islanded and not square_islands():
		# `outline`: the very mask this seed gives, worked out already (a sky
		# chunk's plain, baked on a worker: SkyIslands `claim`).
		mask = outline if not outline.is_empty() else preload("res://scripts/island_outline.gd").mask(data.points,data.vertex_ids,seed_value,size)
	data.reset_flat(mask)
	var swell := FastNoiseLite.new()
	swell.seed = seed_value
	swell.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	swell.frequency = 0.045
	swell.fractal_octaves = 2
	var ripple := FastNoiseLite.new()
	ripple.seed = seed_value+17
	ripple.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ripple.frequency = 0.14
	ripple.fractal_octaves = 2
	var heights := data.heights
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]+origin
		# Broad swells about a metre tall, with a faint ripple over them.
		heights[i] = 0.35+swell.get_noise_2d(p.x,p.y)*0.55+ripple.get_noise_2d(p.x,p.y)*0.12
		if not data.shore_distance.is_empty():
			heights[i] = lerpf(RIM_HEIGHT,heights[i],smoothstep(0.0,RIM_EASE,maxf(data.shore_distance[i],0.0)))
	data.heights = heights
	data.grass.fill(1.0)
	# A meadow carpet of standing tufts (about seven a square metre, see
	# GardenInstanceSamples) that thickens into tussocks (up to about
	# sixteen), with small drifts of flowers. A few patches only read as bare
	# stubble from the diorama camera, so the whole plain carries tufts.
	var tufts := FastNoiseLite.new()
	tufts.seed = seed_value+31
	tufts.frequency = 0.18
	var drifts := FastNoiseLite.new()
	drifts.seed = seed_value+47
	drifts.frequency = 0.11
	var blades := data.blades
	var meadow := data.meadow
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			var p := data.meadow_position(x,z)+Vector2.ONE*data.MEADOW_STEP*0.5+origin
			var index := z*data.MEADOW_CELLS+x
			blades[index] = GENESIS_BLADES.x+GENESIS_BLADES.y*smoothstep(-0.05,0.4,tufts.get_noise_2d(p.x,p.y))
			meadow[index] = GENESIS_FLOWERS*smoothstep(0.2,0.4,drifts.get_noise_2d(p.x,p.y))
	data.blades = blades
	data.meadow = meadow
	# Under the hand, one wild tree stands on the plain: the forest's first
	# source, flicked for its spores (docs/scenic/sky-cloud.md "Seeds").
	if preload("res://scripts/modeless_input.gd").enabled(): _wild_tree(data,seed_value)

## The plain's one wild tree: a mature tree of WILD_KINDS, WILD_RING m out
## from the middle, the way the seed turns; on an island smaller than the
## 28 m square (WILD_LAND m^2) the ring draws in with its radius.
const WILD_KINDS := ["broadleaf","tree","birch"]
const WILD_RING := Vector2(3.0,6.5)
const WILD_LAND := 784.0
const WILD_SIZE := 1.35
## On an island the way turns on (by a golden angle) until it finds land.
static func _wild_tree(data: NativeTerrainData, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value+83
	var ring := WILD_RING*minf(sqrt(data.land_area()/WILD_LAND),1.0)
	var at := Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(ring.x,ring.y)
	var kind: String = WILD_KINDS[rng.randi()%WILD_KINDS.size()]
	var angle := rng.randf()*TAU
	for turn in range(12):
		var spot := at.rotated(turn*2.39996)
		var inland: Variant = data.sample(spot,data.shore_distance) if not data.shore_distance.is_empty() else null
		if inland != null and float(inland) < 1.0: continue
		if data.place(kind,spot,angle,WILD_SIZE) > 0: return

## Form the plain as one undoable operation that also restores the previous
## scene look, as `form_inland` does for generated worlds.
## `size` and `outline` as `shape` takes them.
static func form(editor: NativeChunkEditor, world_value: Dictionary, live := true, origin := Vector2.ZERO, islanded := true, size := -1.0, outline := PackedByteArray()) -> void:
	if editor.forming: return
	editor.finish_stroke()
	editor.selected_object_id = -1
	editor.forming = true
	editor.formation_started.emit()
	editor.data.begin_stroke()
	editor.data._before["favorite_scene"] = NativeGardenStore.capture(editor.scene)
	shape(editor.data,int(world_value.seed),origin,islanded,size,outline)
	editor.data.end_stroke()
	await editor.refresh(editor.get_tree() if live else null)
	editor.land_seed = int(world_value.seed)
	editor.forming = false

static func apply_mood(scene: Node3D, world_value: Dictionary) -> void:
	Generator.apply_mood(scene,world_value)
