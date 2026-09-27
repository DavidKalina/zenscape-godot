extends RefCounted
## The Genesis canvas: a quiet, misty, gently undulating plain to create on.
## It is still a real world with a curated palette family (scripts/
## palette_families.gd), a sky, and living weather; only the land is empty.
## `world` returns the same shape the cozy generator does (seed, terrain,
## mood, visuals, palette), so `CozyWorldGenerator.apply_mood` dresses it.
const Families = preload("res://scripts/palette_families.gd")
const Generator = preload("res://scripts/cozy_world_generator.gd")
## The creation brushes, in palette order; number keys follow it (1 land,
## 2 water, 3 meadow, 4 forest, 5 path). This is the one list: the editor
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
	{"brush_id":"forest","title":"Forest","hint":"Drag to grow forest  ·  Shift-drag clears","script":"res://scripts/forest_brush.gd"},
	{"brush_id":"path","title":"Path","hint":"Drag to wear a path  ·  Shift-drag grows it back","script":"res://scripts/path_brush.gd"},
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
const FIDELITY_TITLE := "Fidelity green"

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

## "Fidelity green" for the badge; older plains name their family.
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

## Heights, grass, a carpet of standing blades and a few flower drifts for a
## blank plain.
## Everything else (objects, water, recipe) is cleared. `origin` is the
## chunk's centre in world metres: atlas chunks (scripts/chunk_atlas.gd) sample
## one field, so neighbouring plains roll into each other.
static func shape(data: NativeTerrainData, seed_value: int, origin := Vector2.ZERO) -> void:
	data.reset_flat()
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

## Form the plain as one undoable operation that also restores the previous
## scene look, as `form_inland` does for generated worlds.
static func form(editor: NativeChunkEditor, world_value: Dictionary, live := true, origin := Vector2.ZERO) -> void:
	if editor.forming: return
	editor.finish_stroke()
	editor.selected_object_id = -1
	editor.forming = true
	editor.formation_started.emit()
	editor.data.begin_stroke()
	editor.data._before["favorite_scene"] = NativeGardenStore.capture(editor.scene)
	shape(editor.data,int(world_value.seed),origin)
	editor.data.end_stroke()
	await editor.refresh(editor.get_tree() if live else null)
	editor.land_seed = int(world_value.seed)
	editor.forming = false

static func apply_mood(scene: Node3D, world_value: Dictionary) -> void:
	Generator.apply_mood(scene,world_value)
