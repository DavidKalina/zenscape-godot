extends SceneTree
## Meadow types (scripts/meadow_types.gd, docs/scenic/meadows.md): worlds
## without one dress byte-for-byte as before; every type dresses, keeps
## itself through a save, is its own meadow, grows in drifts rather than
## confetti, and grows its own flowers on new ground; the flower kit's keys
## fall back to the old forms until the kit is in.
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Probe = preload("res://tools/probe_meadow_digests.gd")
const Lands = preload("res://scripts/world_lands.gd")
const Library = preload("res://scripts/world_library.gd")
const Emergence = preload("res://scripts/emergence.gd")
## tools/probe_meadow_digests.gd on b1e74ec, the commit before meadow types:
## objects, grass, meadow, blades and painted ground of each case. Pinned
## again when the plate grew to 48 m and its mesh became made (plate/48):
## every point, cell and array changed under them; the counts of what each
## case dresses stayed those of b1e74ec within a few per cent.
const BEFORE := {
	"generated 79":"fefdb5d03658","generated 105":"f751be66997c","generated 177":"d41f3ca60582",
	"generated 58":"819137542726","generated 198":"767ed9a6c579","generated 33":"00079c868440",
	"single 79":"ba3ffe7dfea8","single 177":"f1490d33e615","plain_recipe 58":"2e35f9c9579a","isle 4021":"be6dada046c8",
	"formation valley":"ce8a4446e12d","formation terraced_pools":"d52ab18cdc3a","formation redwood_grove":"21b0a163f5a3",
}
const SEED := 2081
const FLOWER_ASSETS := ["daisy_flower","button_flower","spike_flower","umbel_flower"]
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	await checks()
	# Quit once the checks (and the terrain they held) are gone.
	await process_frame
	print("Meadow types: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

func checks() -> void:
	create_timer(900).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	var data := Probe.terrain()
	# Old worlds: every case in the probe's order, as on the commit before.
	for case: Array in Probe.CASES:
		await Probe.dress(data,case)
		var name := "%s %s" % [case[0],str(case[1])]
		var digest := Probe.digest(data)
		check(digest == BEFORE[name],"%s dresses as before (%s, was %s)" % [name,digest,BEFORE[name]])
	check_keys()
	check_lands()
	var looks := {}
	var grounds := {}
	var heights := {}
	for type_id: String in MeadowTypes.ORDER:
		var recipe := MeadowTypes.recipe(type_id,SEED)
		check(NativeTerrainRecipe.valid(recipe),"%s: its recipe is valid" % type_id)
		check(recipe.get("meadow") == type_id and recipe.biome == "meadow" and recipe.get("variety") == 1,"%s: the recipe names its type" % type_id)
		check(MeadowTypes.recipe(type_id,SEED) == recipe,"%s: the same seed plans the same recipe" % type_id)
		var decoded: Variant = NativeTerrainRecipe.decode(JSON.parse_string(JSON.stringify(NativeTerrainRecipe.encode(recipe))))
		check(decoded is Dictionary and decoded == recipe,"%s: the recipe survives JSON" % type_id)
		var started := Time.get_ticks_usec()
		var land = preload("res://scripts/inland_landscape.gd").new()
		await land.form(data,recipe)
		var ms := (Time.get_ticks_usec()-started)/1000.0
		var flowers := data.objects.filter(func(item: Dictionary) -> bool: return item.asset in FLOWER_ASSETS or MeadowTypes.FLOWER_KEYS.has(item.asset))
		print("%s: %d records, %d flowers, dressed in %.0f ms (%s)" % [type_id,data.objects.size(),flowers.size(),ms,preload("res://scripts/biome_blend.gd").title(recipe)])
		check(flowers.size() >= 400,"%s: a meadow of flowers (%d)" % [type_id,flowers.size()])
		check(not NativeTerrainTint.empty(data.tint),"%s: its ground is painted" % type_id)
		# Every flower stands on the type's meadow, as one of the type's kinds.
		var allowed := {}
		for entry: Array in MeadowTypes.TYPES[type_id].flowers: allowed[MeadowTypes.asset(entry[0])] = true
		var strays := flowers.filter(func(item: Dictionary) -> bool: return not allowed.has(item.asset))
		check(strays.is_empty(),"%s: only its own kinds (%d others)" % [type_id,strays.size()])
		var counted := {}
		var tall := PackedFloat32Array()
		for item: Dictionary in flowers:
			var look := look_of(item)
			counted[look] = counted.get(look,0)+1
			tall.append(height_of(item))
		tall.sort()
		looks[type_id] = counted
		heights[type_id] = tall[int(tall.size()*0.9)]
		grounds[type_id] = mean_ground(data)
		# Salt and pepper would put a flower beside its own kind only as often
		# as the mix's shares squared; drifts do far better.
		var chance := 0.0
		for look: String in counted: chance += pow(float(counted[look])/flowers.size(),2.0)
		var beside := drifts(flowers)
		print("   beside their own %.2f (by chance %.2f), open meadow %.2f, tallest tenth %.2f m" % [beside,chance,gaps(land,flowers),heights[type_id]])
		check(beside >= chance+0.12 and beside >= 0.5,"%s: flowers stand in drifts of one kind (%.2f beside their own, %.2f by chance)" % [type_id,beside,chance])
		var open := gaps(land,flowers)
		check(open >= 0.08 and open <= 0.6,"%s: soft gaps of grass between drifts, neither a carpet nor bare (%.2f of the meadow open)" % [type_id,open])
		# A save keeps the type and every record.
		var copy := NativeTerrainData.new()
		copy.setup(data.source_mesh)
		check(copy.load_document(JSON.parse_string(JSON.stringify(data.to_document()))),"%s: its save loads" % type_id)
		check(copy._recipe_settings.get("meadow") == type_id and copy.objects.size() == data.objects.size() and copy.tint == data.tint,"%s: the save keeps the type, its records and its ground" % type_id)
		check_emergence(type_id,data)
	# Each type is its own meadow.
	for a: String in MeadowTypes.ORDER:
		for b: String in MeadowTypes.ORDER:
			if a >= b: continue
			check(dominant(looks[a]) != dominant(looks[b]) or looks[a].keys().size() != looks[b].keys().size(),"%s and %s grow different flowers" % [a,b])
			check(Vector3(grounds[a].r,grounds[a].g,grounds[a].b).distance_to(Vector3(grounds[b].r,grounds[b].g,grounds[b].b)) > 0.004,"%s and %s paint different ground" % [a,b])
	check(looks.wildflower.size() >= 5,"The wildflower meadow mixes five kinds or more (%d)" % looks.wildflower.size())
	check(looks.cosmos.size() >= 3,"The cosmos field sweeps in three colours or more (%d)" % looks.cosmos.size())
	check(looks.dandelion.has("umbel_flower f4f2ea") or looks.dandelion.keys().any(func(look: String) -> bool: return look.begins_with("dandelion_clock ")),"The dandelion meadow has seed clocks")
	for type_id: String in MeadowTypes.ORDER:
		if type_id != "sunflower": check(heights.sunflower > 1.5*heights[type_id],"Sunflowers stand tallest (%.2f m against %s %.2f m)" % [heights.sunflower,type_id,heights[type_id]])
	check(heights.alpine < heights.wildflower,"Alpine flowers stand low (%.2f m against %.2f m)" % [heights.alpine,heights.wildflower])
	var alpine := MeadowTypes.recipe("alpine",SEED)
	check(alpine.get("blend",[]).any(func(layer: Dictionary) -> bool: return layer.biome == "alpine"),"The alpine meadow lies under alpine ground")

## The flower kit's keys: one fallback each, every kind a type asks for has
## one, and the kit's own key wins once the catalog has it.
func check_keys() -> void:
	for kind: String in MeadowTypes.FLOWER_KEYS:
		var entry: Dictionary = MeadowTypes.FLOWER_KEYS[kind]
		check(entry.fallback in NativeTerrainData.ASSETS and MeadowTypes.FALLBACK_FORMS.has(entry.fallback),"%s falls back to a form the catalog has" % kind)
		var expected: String = kind if kind in NativeTerrainData.ASSETS else entry.fallback
		check(MeadowTypes.asset(kind) == expected,"%s places %s" % [kind,expected])
		var shaped := MeadowTypes.form(kind,1.0,0.0)
		if MeadowTypes.standing_in(kind):
			var basis := NativeObjectPose.decode_basis(shaped[1])
			var top: float = MeadowTypes.FALLBACK_FORMS[entry.fallback][0]
			check(is_equal_approx(basis.y.length()*top,float(entry.height)),"A stand-in %s stands %.2f m tall" % [kind,float(entry.height)])
		else:
			check(shaped[1].is_empty() and shaped[0] == 1.0,"The kit's %s takes its own size" % kind)
	for type_id: String in MeadowTypes.TYPES:
		for entry: Array in MeadowTypes.TYPES[type_id].flowers:
			check(MeadowTypes.FLOWER_KEYS.has(entry[0]),"%s's %s has a key" % [type_id,entry[0]])
	check(not NativeTerrainRecipe.valid(MeadowTypes.recipe("wildflower",SEED).merged({"biome":"woodland"},true)),"A meadow type needs a meadow habitat")
	check(not NativeTerrainRecipe.valid(MeadowTypes.recipe("wildflower",SEED).merged({"meadow":"tulip"},true)),"An unknown type is refused")

## Every type is a land New world forms, listed in the library.
func check_lands() -> void:
	for type_id: String in MeadowTypes.ORDER:
		var land := MeadowTypes.land_id(type_id)
		check(land in Lands.IDS,"%s forms from the land %s" % [type_id,land])
		check(MeadowTypes.type_of_land(land) == type_id,"%s's land maps back" % type_id)
		check(Library.LANDS.any(func(entry: Dictionary) -> bool: return entry.id == land and entry.get("group") == "meadow"),"%s is listed among the meadows" % land)
	check(MeadowTypes.type_of_land("canyon").is_empty() and MeadowTypes.of({}).is_empty(),"Other lands and recipes have no type")

## Emergence grows the type's own flowers on meadow ground; a world without a
## type grows the old mix.
func check_emergence(type_id: String, data: NativeTerrainData) -> void:
	var emergence = Emergence.new(data,7)
	var allowed := {"grass_tuft":true}
	for entry: Array in MeadowTypes.TYPES[type_id].flowers: allowed[MeadowTypes.asset(entry[0])] = true
	var grown := {}
	for i in range(200):
		var p := Vector2(randf_range(-8,8),randf_range(-8,8))
		var kind: String = emergence._shrub_kind("meadow",p,float(i)/200.0,[7,i])
		grown[kind] = grown.get(kind,0)+1
		check(allowed.has(kind),"%s: emergence grows its own kinds (%s)" % [type_id,kind])
		if kind != "grass_tuft": check(emergence._flower_look.size() == 5,"%s: an emerged flower carries its own look" % type_id)
	check(grown.size() >= 2,"%s: emergence grows flowers and grass (%s)" % [type_id,grown])
	# Emergence listens to the terrain; let go so neither outlives the test.
	for signal_info: Dictionary in data.get_signal_list():
		for connection: Dictionary in data.get_signal_connection_list(signal_info.name): data.disconnect(signal_info.name,connection.callable)

## A flower's kind and colour, from its asset and tint.
static func look_of(item: Dictionary) -> String:
	return "%s %s" % [item.asset,NativeObjectPose.decode_tint(item.tint).linear_to_srgb().to_html(false) if item.has("tint") else ""]

static func height_of(item: Dictionary) -> float:
	# The kit's own meshes stand at their kind's height at size 1.
	if not item.has("pose"): return float(item.scale)*(float(MeadowTypes.FLOWER_KEYS[item.asset].height) if MeadowTypes.FLOWER_KEYS.has(item.asset) else 0.25)
	var fallback: Array = MeadowTypes.FALLBACK_FORMS.get(item.asset,[0.25,0.1])
	return NativeObjectPose.decode_basis(item.pose).y.length()*float(fallback[0])

static func dominant(counted: Dictionary) -> String:
	var best := ""
	for look: String in counted:
		if best.is_empty() or counted[look] > counted[best]: best = look
	return best

## Share of flowers whose nearest flower is of their own kind and colour.
static func drifts(flowers: Array) -> float:
	var same := 0
	for item: Dictionary in flowers:
		var best := INF
		var nearest: Dictionary = {}
		for other: Dictionary in flowers:
			if other.id == item.id: continue
			var d := Vector2(other.x-item.x,other.z-item.z).length_squared()
			if d < best:
				best = d
				nearest = other
		if not nearest.is_empty() and look_of(nearest) == look_of(item): same += 1
	return float(same)/maxf(1.0,flowers.size())

## Share of open meadow ground (on a 0.5 m grid inside the plate): two
## flowers or fewer within a metre, grass with at most a stray in it.
static func gaps(land: RefCounted, flowers: Array) -> float:
	var cells := {}
	for item: Dictionary in flowers: cells[Vector2i(floori(item.x),floori(item.z))] = cells.get(Vector2i(floori(item.x),floori(item.z)),[])+[Vector2(item.x,item.z)]
	var open := 0
	var total := 0
	for z in range(-18,18):
		for x in range(-18,18):
			var p := Vector2(x,z)*0.5+Vector2(0.25,0.25)
			if land._is_wet(p) or land._habitat(p) != "meadow": continue
			total += 1
			var near := 0
			for dz in range(-1,2):
				for dx in range(-1,2):
					for q: Vector2 in cells.get(Vector2i(floori(p.x)+dx,floori(p.y)+dz),[]):
						if q.distance_to(p) < 1.0: near += 1
			if near <= 2: open += 1
	return float(open)/maxf(1.0,total)

## The meadow's painted ground colour, weighted.
static func mean_ground(data: NativeTerrainData) -> Color:
	var sum := Vector3.ZERO
	var weight := 0.0
	for cell in range(data.MEADOW_CELLS*data.MEADOW_CELLS):
		var w := NativeTerrainTint.weight_at(data.tint,cell)
		if w <= 0.0: continue
		var c := NativeTerrainTint.color_at(data.tint,cell)
		sum += Vector3(c.r,c.g,c.b)*w
		weight += w
	sum /= maxf(weight,0.0001)
	return Color(sum.x,sum.y,sum.z)
