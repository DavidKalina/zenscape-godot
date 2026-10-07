extends SceneTree
const Generator = preload("res://scripts/cozy_world_generator.gd")
const World = preload("res://scripts/inland_world.gd")
const Places = preload("res://scripts/inland_places.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var worst := Vector2.ONE
	var started := Time.get_ticks_msec()
	for seed_value in range(100):
		var settings: Dictionary = Generator.sample(seed_value*7919).terrain
		var world = World.new(settings)
		var q: Dictionary = Places.quality(world.sampler)
		worst.x = minf(worst.x,q.usable)
		worst.y = minf(worst.y,q.connected)
		# Worlds are kept by beauty, not usable ground (5e5e93f9): three places, no floor.
		check(q.places==3,"Three places seed %s %s: %s"%[seed_value,settings.composition,q])
		var legacy := settings.duplicate(true)
		legacy.version = 3
		var old = World.new(legacy)
		check(old.sampler.places.is_empty(),"Legacy recipes do not acquire terraces")
		check(NativeTerrainRecipe.decode(JSON.parse_string(JSON.stringify(NativeTerrainRecipe.encode(settings))))==settings,"Recipe roundtrip")
		check(world.sampler.places==World.new(settings).sampler.places,"Place layout is deterministic")
		for route: Dictionary in world.streams:
			check(preload("res://scripts/native_stream_record.gd").valid(route),"Water remains downhill")
	print("QUALITY worst=",worst," sampling_ms=",Time.get_ticks_msec()-started)
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	for habitat in ["woodland","redwood","meadow","alpine","wetland","arid"]:
		var settings := {"kind":"inland","version":4,"seed":7,"composition":{"woodland":"massif","redwood":"valley","meadow":"foothills","alpine":"mountain","wetland":"marsh","arid":"buttes"}[habitat],"archetype":"range","landform":"original","biome":habitat,"relief":1.0,"breadth":1.0}
		await preload("res://scripts/inland_landscape.gd").new().form(data,settings)
		for place: Dictionary in data._recipe.inland.sampler.places:
			var detail := 0
			for item: Dictionary in data.objects:
				var p := Vector2(item.x,item.z)
				if p.distance_to(place.center)<3.2: detail += 1
			check(detail>=20,"Each place receives detail: %s %s"%[habitat,detail])
		var before := data._snapshot()
		check(data.load_document(JSON.parse_string(JSON.stringify(data.to_document(),"",true,true))),"Save/reopen inhabited world")
		check(data.heights==before.heights,"Terrain survives save")
		check(data.objects.size()==before.objects.size(),"All details survive save")
		for i in range(data.objects.size()):
			var a: Dictionary = data.objects[i]
			var b: Dictionary = before.objects[i]
			check(a.id==b.id and a.asset==b.asset,"Saved object identity")
			for key in ["x","z","angle","scale"]:
				check(is_equal_approx(a[key],b[key]),"Saved object transform")
	check(await Generator.sample_async(7919,{},self)==Generator.sample(7919),"Worker selection matches synchronous generation")
	print("INLAND PLACES failures=",failures)
	quit(1 if failures else 0)
