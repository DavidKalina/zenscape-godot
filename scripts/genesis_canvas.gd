extends RefCounted
## The Genesis canvas: a quiet, misty, gently undulating plain to create on.
## It is still a real world with a curated palette family (scripts/
## palette_families.gd), a sky, and living weather; only the land is empty.
## `world` returns the same shape the cozy generator does (seed, terrain,
## mood, visuals, palette), so `CozyWorldGenerator.apply_mood` dresses it.
const Families = preload("res://scripts/palette_families.gd")
const Generator = preload("res://scripts/cozy_world_generator.gd")

## The creation brushes, in palette order; number keys follow it (1 land,
## 2 water, 3 meadow, 4 forest, 5 path). The palette (scripts/
## creation_palette.gd) shows whatever is listed here. Each entry is a
## Dictionary, or a brush object or script exposing the same names:
## - `brush_id`: the NativeChunkEditor mode that paints it; picking the brush
##   calls `select_tool(brush_id)`.
## - `title`: the palette's name for it.
## - `hint`: optional one-line how-to under the palette.
## - `size` / `strength`: optional editor properties that `[ ]` and
##   Shift+`[ ]` step; by default the SETTINGS entries titled "Brush size" and
##   "Strength" for the mode.
## Brush branches append their own entry.
const BRUSHES := [
	{"brush_id":"land","title":"Land","hint":"Drag to raise land  ·  Shift or right drag lowers"},
]

## A seeded misty morning or soft day over a meadow palette.
static func world(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["genesis",seed_value])
	# Dawn or full day: low light reads well through mist; dusk and night hide the land.
	var hour := 0 if rng.randf() < 0.5 else 1
	var phase := rng.randf_range(0.28,0.34) if hour == 0 else rng.randf_range(0.38,0.52)
	var drawn: Dictionary = Families.draw(seed_value,false,"meadow",hour,"mist",false)
	var encoded := {}
	for key in drawn.colors: encoded[key] = drawn.colors[key].to_html(false)
	var mood := {"colors":encoded,"phase":phase,"weather":"mist","wind":rng.randf_range(.1,.3),"wind_direction":rng.randf_range(0,360),
		"clouds":rng.randf_range(.46,.6),"mist":rng.randf_range(.4,.56),"haze":rng.randf_range(.16,.26),"rays":rng.randf_range(.45,.85),
		"summit_mist":rng.randf_range(.2,.34),"strength":rng.randf_range(.72,.84),"exposure":rng.randf_range(1.08,1.14),
		"ambient_energy":rng.randf_range(1.45,1.7),"sun_energy":rng.randf_range(.85,1.05),"night_fill":1.45,"cold":0.0,"snow":0.0,
		"ice":0.0,"wet":0.0,"humidity":.8,"autumn":0.0,"aurora":0.0,"rainbow":0.0}
	# Ground mist, kept thinner than a generated misty world so strokes stay legible.
	var visuals := {"fog_density":rng.randf_range(.3,.44),"fog_height":rng.randf_range(3.0,4.5),
		"peak_density":rng.randf_range(.12,.2),"peak_altitude":rng.randf_range(3.5,5.5),"rock_style":1,"rock_detail":.65}
	return {"seed":seed_value,"terrain":{},"mood":mood,"visuals":visuals,"palette":drawn.family,"genesis":true}

## "Spring meadow" for the badge.
static func palette_title(world_value: Dictionary) -> String:
	var family: Dictionary = Families.FAMILIES.get(str(world_value.get("palette","")),{})
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
## Everything else (objects, water, recipe) is cleared.
static func shape(data: NativeTerrainData, seed_value: int) -> void:
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
		var p: Vector2 = data.points[i]
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
			var p := data.meadow_position(x,z)+Vector2.ONE*data.MEADOW_STEP*0.5
			var index := z*data.MEADOW_CELLS+x
			blades[index] = GENESIS_BLADES.x+GENESIS_BLADES.y*smoothstep(-0.05,0.4,tufts.get_noise_2d(p.x,p.y))
			meadow[index] = GENESIS_FLOWERS*smoothstep(0.2,0.4,drifts.get_noise_2d(p.x,p.y))
	data.blades = blades
	data.meadow = meadow

## Form the plain as one undoable operation that also restores the previous
## scene look, as `form_inland` does for generated worlds.
static func form(editor: NativeChunkEditor, world_value: Dictionary, live := true) -> void:
	if editor.forming: return
	editor.finish_stroke()
	editor.selected_object_id = -1
	editor.forming = true
	editor.formation_started.emit()
	editor.data.begin_stroke()
	editor.data._before["favorite_scene"] = NativeGardenStore.capture(editor.scene)
	shape(editor.data,int(world_value.seed))
	editor.data.end_stroke()
	await editor.refresh(editor.get_tree() if live else null)
	editor.land_seed = int(world_value.seed)
	editor.forming = false

static func apply_mood(scene: Node3D, world_value: Dictionary) -> void:
	Generator.apply_mood(scene,world_value)
