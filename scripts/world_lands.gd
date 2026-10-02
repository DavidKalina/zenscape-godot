extends RefCounted
## The lands a new world starts from (scripts/world_library.gd LANDS), formed
## in the scene from a seed. Plain and canyon are existing recipes; the isle
## and the hollow have no recipe of their own yet and borrow the closest one
## under their own mood:
## - plain: the Genesis quiet plain (scripts/genesis_canvas.gd `world`).
## - canyon: the arid canyon formation (scripts/native_landscape_presets.gd
##   "canyon", the title showcase's canyon), its authored desert mood.
## - isle: the inland marsh (wetland), under low cloud, mist and grey water.
## - hollow: the redwood grove formation, under the Hollow palette in deep
##   shade, thick mist and damp ground.
const Genesis = preload("res://scripts/genesis_canvas.gd")
const IDS := ["plain","canyon","isle","hollow"]
const ISLE := {"phase":0.37,"weather":"mist","clouds":0.66,"mist":0.58,"haze":0.24,"summit_mist":0.45,"rays":0.2,"wind":0.3,
	"rainbow":0.0,"wet":0.35,"humidity":0.85,"sun_energy":0.82,"ambient_energy":1.45,"exposure":1.06,
	"colors":{"sky":"98a5ab","horizon":"a9b1b1","glow":"d8d6cb","sun":"e8e2d2","ambient":"aebbc1","water":"8b9da1","grass":"7c9a80","foliage":"5d7e6e"}}
const HOLLOW := {"phase":0.335,"weather":"mist","clouds":0.42,"mist":0.62,"haze":0.24,"summit_mist":0.3,"rays":0.85,"wind":0.18,
	"wet":0.5,"humidity":0.85,"sun_energy":0.72,"ambient_energy":1.2,"exposure":1.02,
	"colors":{"sky":"5f8a8e","horizon":"4b6c69","glow":"b2c7a8","ambient":"8fae9e","grass":"5c8a63","foliage":"3f7356","earth":"4f3f30","water":"4c8584"}}

## Forms `land` from `seed_value` in the scene's editor, with its mood. Returns
## {"plain":bool,"world":Genesis world or {}} for the regrowth controller.
static func form(scene: Node3D, land: String, seed_value: int, live := true) -> Dictionary:
	var editor: NativeChunkEditor = scene._chunk_editor
	scene.restore_cave_state({})
	match land:
		"canyon":
			await editor.form_landscape("canyon","arid",live,1+seed_value%999)
			_settle(scene,{"mood":{"weather":"clear"}})
		"isle":
			var recipe := {"kind":"inland","version":preload("res://scripts/inland_genome.gd").VERSION,"seed":seed_value%1000000,"composition":"marsh",
				"archetype":"range","landform":"original","biome":"wetland","relief":0.85,"breadth":1.15}
			await editor.form_inland(recipe,live,false)
			_mood(scene,"after_the_rain",ISLE,{"fog_density":0.55,"fog_height":3.5,"peak_density":0.24})
		"hollow":
			await editor.form_landscape("redwood_grove","redwood",live,1+seed_value%999,"connected",false)
			_mood(scene,"enchanted_forest",HOLLOW,{"fog_density":0.5,"fog_height":3.0,"peak_density":0.12})
		_:
			var world := Genesis.world(seed_value)
			await Genesis.form(editor,world,false)
			Genesis.apply_mood(scene,world)
			editor.data._undo.clear()
			editor.data._redo.clear()
			return {"plain":true,"world":world}
	# A new world's first undo is not the world before it.
	editor.data._undo.clear()
	editor.data._redo.clear()
	return {"plain":false,"world":{}}

static func _mood(scene: Node3D, preset: String, overrides: Dictionary, visuals: Dictionary) -> void:
	_settle(scene,{"mood":overrides})
	SceneLookPresets.apply(scene,preset,overrides)
	scene._world_visuals.restore()
	scene._world_visuals.rock_style = 1
	for key in visuals: scene._world_visuals.set(key,visuals[key])
	scene._world_visuals.peak_altitude = clampf(Array(scene._chunk_editor.data.heights).max()*0.6,2.0,24.0)
	scene._world_visuals.sync(scene)

## Living weather starts its drift from this world's sky, nothing pinned.
static func _settle(scene: Node3D, world: Dictionary) -> void:
	if scene.has_method("establish_world_weather"): scene.establish_world_weather(world)
