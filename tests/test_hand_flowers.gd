extends SceneTree
## Flower seed from the hand (scripts/flower_sowing.gd, docs/scenic/handful.md
## "Flower seed"). Headless.
##
## On a flat plate: a handful's landings grow a dense drift of the sown kind
## inside where they fell (packed core, feathered edge, a few companions, the
## ground washed under it), blooming in the order they landed; none on water,
## steep ground, painted rock, under trees or where something stands; a
## second sowing fills rather than doubles; sunflowers stand in rows; the
## wildflower slot sows the wildflower meadow's mix, or a meadow world's own;
## the records save and reopen.
##
## The bar: every flower slot has a faceted icon and a small-caps name, the
## hand sows them as a veil (no scatter), and reeds still scatter.
##
## In the cozy scene (the hand scheme): a poppy sweep's veil settles inside
## its footprint in still air and comes up as a poppy drift, one undo step,
## undone whole; in wind the flower veil drifts further than tree seed's;
## the world saves and reopens with the flowers.
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Materials = preload("res://scripts/hand_materials.gd")
const Palette = preload("res://scripts/command_palette.gd")
const Emergence = preload("res://scripts/emergence.gd")
const Wind = preload("res://scripts/pollen_wind.gd")

var failures := 0
var only := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)
	else:
		print("PASS: "+message)

func _flat_data() -> NativeTerrainData:
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	source.free()
	return data

## A handful's landings: `count` motes spread evenly over a disc of `radius`
## round `centre`, landing over 4 s.
static func handful(centre: Vector2, radius: float, count: int, salt: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var points := PackedVector2Array()
	var times := PackedFloat32Array()
	for i in range(count):
		points.append(centre+Vector2.from_angle(rng.randf()*TAU)*radius*sqrt(rng.randf()))
		times.append(6.0+rng.randf()*4.0)
	return [points,times]

## A sweep's landings: a band `width` across along a to b.
static func band(a: Vector2, b: Vector2, width: float, per_metre: float, salt: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var points := PackedVector2Array()
	var times := PackedFloat32Array()
	var length := a.distance_to(b)
	var across := (b-a).normalized().orthogonal()
	for i in range(int(length*per_metre)):
		var t := rng.randf()
		points.append(a.lerp(b,t)+across*(rng.randf()-0.5)*width+Vector2(rng.randfn(0.0,0.15),rng.randfn(0.0,0.15)))
		times.append(6.0+t*0.6+rng.randf()*3.5)
	return [points,times]

func _sown(data: NativeTerrainData, ids: Array) -> Array:
	var out := []
	for item: Dictionary in data.objects:
		if int(item.id) in ids: out.append(item)
	return out

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if only.is_empty() or only == "unit":
		units()
		veils()
		bar()
	if only.is_empty() or only == "scene":
		await in_scene()
	print("Hand flowers: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)

# --- The drift on a flat plate ------------------------------------------------------

func units() -> void:
	var data := _flat_data()
	var sowing := FlowerSowing.new(data,"poppy",4242)
	var centre := Vector2(-3.0,2.0)
	var landed: Array = handful(centre,1.6,110,1)
	var now := Emergence.time
	data.begin_stroke()
	var grown: Dictionary = sowing.grow(landed[0],landed[1],1,now)
	check(data.end_stroke(),"A sowing is one undo step")
	var flowers := _sown(data,grown.placed)
	var poppies := flowers.filter(func(item: Dictionary) -> bool: return item.asset == "poppy").size()
	var outside := flowers.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(centre) > 1.6+FlowerSowing.KERNEL*1.5).size()
	var core := flowers.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(centre) < 0.8).size()
	print("handful: %d flowers (%d poppies), %d in the 0.8 m core, kinds %s, %d cells washed" % [flowers.size(),poppies,core,str(grown.kinds),grown.washed])
	check(flowers.size() >= 90,"A handful of poppy seed comes up as a dense drift (%d flowers on ~8 m²)" % flowers.size())
	check(core >= int(PI*0.64/(0.2*0.2)*MeadowTypes.packing("poppy")*0.75),"Its core is packed (%d in the middle 0.8 m)" % core)
	check(poppies >= flowers.size()*0.8 and poppies < flowers.size(),"It is poppies with a few companions (%d of %d)" % [poppies,flowers.size()])
	check(outside == 0,"Every flower stands where the seed came down (%d outside)" % outside)
	check(int(grown.washed) > 0,"The ground under the drift is washed toward the poppies (%d cells)" % grown.washed)
	var hand := flowers.all(func(item: Dictionary) -> bool: return item.get("source") == "hand")
	check(hand,"Sown flowers are hand work, so emergence leaves them")
	# It blooms in the order it landed, over BLOOM seconds.
	var births: Array = flowers.map(func(item: Dictionary) -> float: return float(item.born)-now)
	births.sort()
	check(births[0] >= 0.0 and births.back() <= FlowerSowing.BLOOM_DELAY+FlowerSowing.BLOOM+FlowerSowing.BLOOM_JITTER+0.01 and births.back()-births[0] > 1.0,
		"It grows in visibly, from %.2f to %.2f s" % [births[0],births.back()])
	# Its edge feathers: the outer ring is thinner than the core.
	var ring := flowers.filter(func(item: Dictionary) -> bool: var d := Vector2(item.x,item.z).distance_to(centre); return d > 1.3 and d < 1.9).size()
	var ring_area := PI*(1.9*1.9-1.3*1.3)
	check(float(ring)/ring_area < float(core)/(PI*0.64)*0.75,"Its edge is softer than its core (%.1f against %.1f a m²)" % [ring/ring_area,core/(PI*0.64)])
	# A second sowing over it fills, never doubles.
	var before := data.objects.size()
	var again: Array = handful(centre,1.6,110,2)
	data.begin_stroke()
	var second: Dictionary = sowing.grow(again[0],again[1],2,now)
	data.end_stroke()
	var crowded := 0
	var all := _sown(data,grown.placed+second.placed)
	for i in range(all.size()):
		for j in range(i+1,all.size()):
			if Vector2(all[i].x,all[i].z).distance_to(Vector2(all[j].x,all[j].z)) < FlowerSowing.ROOM*0.99: crowded += 1
	print("second sowing: +%d" % (data.objects.size()-before))
	check(crowded == 0 and data.objects.size()-before < flowers.size(),"A second sowing fills the gaps (+%d) and stacks none (%d too close)" % [data.objects.size()-before,crowded])
	# Undo takes the sowing and its wash away.
	var tint := data.tint.duplicate()
	data.undo()
	check(data.objects.size() == before and data.tint != tint,"Undo takes the second sowing back whole")
	# Saves: object records, reopened as they were (births only animate).
	var reopened := _flat_data()
	check(reopened.load_document(JSON.parse_string(JSON.stringify(data.to_document()))),"A world with sown flowers saves and reopens")
	var same := reopened.objects.size() == data.objects.size()
	for i in range(mini(reopened.objects.size(),data.objects.size())):
		var a: Dictionary = data.objects[i].duplicate()
		a.erase("born")
		if JSON.stringify(a) != JSON.stringify(reopened.objects[i]): same = false
	check(same and reopened.tint == data.tint,"Its flowers and wash reopen as they were")

	# The ground decides: none on water, a steep peak, painted rock, under trees.
	var ground := _flat_data()
	ground.ponds.append({"x":4.0,"z":-4.0,"level":0.4})
	ground.mountain(Vector2(-5.0,-5.0),2.4,6.0)
	var rock: Color = ground._palette.rock[0]
	for i in range(8): ground.paint_tint(Vector2(5.0,5.0),3.4,rock,1.0)
	for k in range(6): ground.place("broadleaf",Vector2(-5.0,5.0)+Vector2.from_angle(k*TAU/6.0)*1.1,0.0,1.0)
	ground.place("broadleaf",Vector2(-5.0,5.0),0.0,1.0)
	ground.place("rock",Vector2(0.0,-5.0),0.0,1.0)
	var refuse := FlowerSowing.new(ground,"poppy",4242)
	for spot: Array in [["water",Vector2(4.0,-4.0),0.9],["a steep peak",Vector2(-5.0,-5.0),1.0],["painted rock",Vector2(5.0,5.0),0.7],["dense forest",Vector2(-5.0,5.0),1.0]]:
		var on: Array = handful(spot[1],float(spot[2]),110,3)
		var made: Dictionary = refuse.grow(on[0],on[1],3,now)
		var steep := 0
		if spot[0] == "a steep peak":
			for item in _sown(ground,made.placed):
				if preload("res://scripts/native_landscape_presets.gd")._slope(ground,Vector2(item.x,item.z)) > FlowerSowing.STEEP: steep += 1
			check(steep == 0,"No flower takes on a slope over %.2f (%d did)" % [FlowerSowing.STEEP,steep])
		else:
			check(made.placed.size() == 0,"No flower takes on %s (%d did, %d refused)" % [spot[0],made.placed.size(),made.refused])
	var stone := refuse.grow(handful(Vector2(0.0,-5.0),0.6,60,4)[0],handful(Vector2(0.0,-5.0),0.6,60,4)[1],4,now)
	var on_stone := _sown(ground,stone.placed).filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(Vector2(0.0,-5.0)) < FlowerSowing.STONE*0.99).size()
	check(on_stone == 0,"Nothing grows on a stone (%d did)" % on_stone)

	# Each slot grows its kinds: dandelions with their clocks, cosmos,
	# sunflowers in rows, and the wildflower meadow's mix.
	for slot: String in ["dandelion","cosmos","sunflower","wildflower"]:
		var plate := _flat_data()
		var sow := FlowerSowing.new(plate,slot,777)
		var swept: Array = band(Vector2(-7.0,-1.0),Vector2(7.0,1.0),2.6,110.0,5)
		var began := Time.get_ticks_usec()
		var made: Dictionary = sow.grow(swept[0],swept[1],5,now)
		var took := (Time.get_ticks_usec()-began)/1000.0
		print("%s sweep: %d flowers %s, grown in %.0f ms from %d landings" % [slot,made.placed.size(),str(made.kinds),took,swept[0].size()])
		var expect: Array = {"dandelion":["dandelion","dandelion_clock"],"cosmos":["cosmos"],"sunflower":["sunflower"],"wildflower":["oxeye_daisy","buttercup","poppy"]}[slot]
		var main := 0
		for kind: String in expect: main += int(made.kinds.get(kind,0))
		check(made.placed.size() >= 120 and main >= made.placed.size()*0.75,"A %s sweep comes up as %s (%d of %d)" % [slot," and ".join(expect),main,made.placed.size()])
		if slot == "dandelion": check(int(made.kinds.get("dandelion",0)) > 0 and int(made.kinds.get("dandelion_clock",0)) > 0,"Dandelions come with seed clocks")
		if slot == "wildflower": check(made.kinds.size() >= 3,"The wildflower slot sows a mix (%d kinds)" % made.kinds.size())
		if slot == "sunflower":
			var rows := 0
			for item in _sown(plate,made.placed):
				if item.asset == "sunflower" and sow.meadow.on_row(Vector2(item.x,item.z),"sunflower"): rows += 1
			check(rows == int(made.kinds.get("sunflower",0)) and made.placed.size() < 600,"Sunflowers stand in rows, a stand not a carpet (%d)" % rows)
	# In a meadow world the wildflower slot sows the world's own meadow.
	var cosmos_world := _flat_data()
	cosmos_world._recipe_settings = {"kind":"inland","biome":"meadow","meadow":"cosmos"}
	check(FlowerSowing.type_for("wildflower",cosmos_world._recipe_settings) == "cosmos" and FlowerSowing.type_for("poppy",cosmos_world._recipe_settings) == "wildflower",
		"In a cosmos meadow the wildflower slot sows cosmos; poppy stays poppy")

## A stand-in atmosphere: one steady breeze, no gusts (scripts/pollen_wind.gd
## reads these).
class StillAir extends Node:
	var _air_angle := 0.0
	var _air_strength := 0.5
	var swell := 0.0
	var _wind_time := 0.0
	var _gust_distance := 0.0
	func gust_at(_t: float) -> float: return 1.0

class Stage extends Node:
	var _atmosphere: Node

## The flower veil on one steady breeze, beside a tree's: it drifts
## FlowerSowing.CARRY times as far, and falls closer to its sweep.
func veils() -> void:
	var stage := Stage.new()
	stage._atmosphere = StillAir.new()
	var plate := Node3D.new()
	root.add_child(plate)
	var drifts := {}
	var widths := {}
	for kind: String in ["tree","flower"]:
		var cloud: Node3D = preload("res://scripts/pollen_cloud.gd").new()
		cloud.scene = stage
		plate.add_child(cloud)
		cloud.set_process(false)
		var look := {} if kind == "tree" else {"spread":FlowerSowing.SPREAD,"carry":FlowerSowing.CARRY,"colour":FlowerSowing.look("poppy")}
		cloud.gather(Vector3(-4.0,0.0,0.0),FlowerSowing.RADIUS,1.0,"broadleaf",77,look)
		for i in range(30):
			cloud.hold(Vector3(-4.0+i*0.1,0.0,0.0))
			cloud._process(1.0/30.0)
		var out := {}
		cloud.settled.connect(func(c: Dictionary) -> void: out.merge(c))
		cloud.release()
		for i in range(900):
			if not out.is_empty(): break
			cloud._process(1.0/60.0)
		drifts[kind] = (out.drift as Vector2).length()
		var spread := 0.0
		for q: Vector2 in out.points: spread = maxf(spread,absf(q.y))
		widths[kind] = spread
	print("veils on one breeze: tree drift %.2f m, half-width %.2f m; flower drift %.2f m, half-width %.2f m" % [drifts.tree,widths.tree,drifts.flower,widths.flower])
	check(drifts.tree > 1.0 and absf(drifts.flower/drifts.tree-FlowerSowing.CARRY) < 0.05,"Flower fluff rides the air %.2fx as far as tree seed (%.2f)" % [FlowerSowing.CARRY,drifts.flower/maxf(drifts.tree,0.001)])
	check(widths.flower < widths.tree,"It comes down closer to its sweep (%.2f m against %.2f m)" % [widths.flower,widths.tree])
	plate.queue_free()
	stage._atmosphere.free()
	stage.free()

# --- The bar --------------------------------------------------------------------------

func bar() -> void:
	var ids: Array = Tray.SPECIMENS.map(func(entry: Dictionary) -> String: return entry.id)
	for slot: String in ["wildflower","dandelion","poppy","cosmos","sunflower"]:
		check(slot in ids and FlowerSowing.has(slot) and Materials.sows(slot) and not Materials.SCATTER.has(slot),"%s has a slot and is sown as a veil" % slot)
		var item := Icons.item(slot)
		check(not item.is_empty() and str(item.label).contains(" · ") and Icons.texture(slot,"icon",44.0) != null,"%s has its faceted icon and name (%s)" % [slot,item.get("label","")])
		check(Palette.SEEDS.any(func(entry: Array) -> bool: return entry[0] == slot),"%s is in the command palette" % slot)
	check(Materials.SCATTER.has("reed") and Materials.SCATTER.has("stone") and "reed" in ids,"Reeds and stones still scatter")
	var seeds: Array = Tray.SPECIMENS.filter(func(entry: Dictionary) -> bool: return entry.group == 0)
	check(seeds.size() == 9,"Nine seeds in the seed group (%d)" % seeds.size())

# --- The cozy scene ---------------------------------------------------------------------

var scene: Node3D
var editor: Node

func screen_of(point: Vector2) -> Vector2:
	var data: NativeTerrainData = editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(point.x,float(data.sample(point,data.heights)),point.y)))

var reach: Node
var materials: Node

## The pointer at `at` (viewport), pressed or not, as the hand scheme reads it.
func button(at: Vector2, pressed: bool) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

func set_wind(strength: float, degrees: float) -> void:
	var air = scene._atmosphere
	air.strength = strength
	air._air_strength = strength
	air.swell = 0.0
	air.direction_angle = degrees
	air._air_angle = deg_to_rad(degrees)
	# No gust parcels: the same air everywhere.
	if air.get("puffs") != null:
		var none := PackedVector4Array()
		none.resize(air.puffs.parcels.size())
		air.puffs.parcels = none

## Sow `kind` (a flower slot, or a tree's seed: "oak") along `path` (plate)
## over `seconds` through the hand: take it in hand, press on the land, drag,
## let go; then wait for the veil to settle and be written. The settled cloud.
func sow(kind: String, path: Array, seconds: float) -> Dictionary:
	var settled := {}
	check(materials.take(kind) and materials.held == kind,"%s seed is taken in hand" % kind)
	var start := screen_of(path[0])
	point(start)
	for i in range(30): await process_frame
	var serial := str(editor.last_sowing.get("id",""))
	button(start,true)
	await process_frame
	check(editor._handful_holding,"A press on the land with %s in hand lays its veil" % kind)
	var catch := func(cloud: Dictionary) -> void: settled.merge(cloud)
	if editor.handful != null: editor.handful.settled.connect(catch)
	var began := Time.get_ticks_msec()
	var was := start
	while (Time.get_ticks_msec()-began)/1000.0 < seconds:
		var t := (Time.get_ticks_msec()-began)/1000.0/maxf(seconds,0.001)
		var at := screen_of(Vector2(path[0]).lerp(path[-1],clampf(t,0.0,1.0)))
		motion(at,at-was)
		was = at
		await process_frame
	button(was,false)
	began = Time.get_ticks_msec()
	while settled.is_empty() and Time.get_ticks_msec()-began < 20000: await process_frame
	if editor.handful != null: editor.handful.settled.disconnect(catch)
	# The write follows the settle within a frame or two.
	began = Time.get_ticks_msec()
	while str(editor.last_sowing.get("id","")) == serial and Time.get_ticks_msec()-began < 5000: await process_frame
	for i in range(4): await process_frame
	materials.put_back()
	return settled

func in_scene() -> void:
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-hand-flowers-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	# The creation state the game enters off the title (cozy_worlds `_run_title`).
	# The world grows in first.
	var waited := Time.get_ticks_msec()
	while scene._growth.terrain < 0.995 and Time.get_ticks_msec()-waited < 30000: await process_frame
	if not editor.active: scene.set_building(false)
	check(editor.active,"The land takes presses")
	scene.world_clock.running = false
	reach = scene.hand_reach
	materials = reach.get("materials")
	check(materials != null,"The hand scheme's materials are in the scene")
	if materials != null:
		check(materials.take("poppy") and materials.held == "poppy","Poppy seed can be taken in hand")
		check(materials.hint("land")[1] == Materials.FLOWER_HINT,"Its hint says to drag to sow")
		materials.put_back()
	var data: NativeTerrainData = editor.data
	# Still air: a sweep settles inside its footprint and comes up poppies.
	set_wind(0.0,0.0)
	for i in range(120): await process_frame
	var steps: int = data._undo.size()
	var count := data.objects.size()
	var tint := data.tint.duplicate()
	var cloud: Dictionary = await sow("poppy",[Vector2(-4.0,3.0),Vector2(2.0,3.0)],1.0)
	var grown: Dictionary = editor.last_sowing.get("flowers",{})
	print("poppy sweep: motes %d, landed %d, worst %.2f, outside %d, grown %s" % [int(cloud.get("motes",0)),cloud.get("points",[]).size(),float(cloud.get("worst",0.0)),int(cloud.get("outside",0)),str(grown.get("kinds",{}))])
	check(not cloud.is_empty() and int(cloud.outside) == 0 and float(cloud.worst) <= 1.0001,"In still air every mote settles inside its footprint (worst %.2f)" % float(cloud.get("worst",INF)))
	var placed: Array = grown.get("placed",[])
	var poppies := int(grown.get("kinds",{}).get("poppy",0))
	check(placed.size() >= 150 and poppies >= placed.size()*0.8,"It comes up as a dense poppy drift (%d flowers, %d poppies)" % [placed.size(),poppies])
	check(data._undo.size() == steps+1,"One undo step for the sweep (%d)" % (data._undo.size()-steps))
	var stray := 0
	for item: Dictionary in _sown(data,placed):
		var p := Vector2(item.x,item.z)
		var near := INF
		for q: Vector2 in cloud.points: near = minf(near,p.distance_to(q))
		if near > FlowerSowing.KERNEL*2.0: stray += 1
	check(stray == 0,"Every flower stands where seed came down (%d far from any)" % stray)
	editor.undo()
	for i in range(4): await process_frame
	check(data.objects.size() == count and data.tint == tint,"Undo takes the drift and its wash away")
	editor.redo()
	for i in range(4): await process_frame
	# Wind: flower fluff rides it further than tree seed. The air held steady
	# (its clock stopped) so both veils fall on the same breeze.
	set_wind(0.6,0.0)
	scene._atmosphere.set_process(false)
	var oak: Dictionary = await sow("oak",[Vector2(-6.0,-6.0),Vector2(-6.0,-3.0)],0.6)
	var cosmos: Dictionary = await sow("cosmos",[Vector2(-6.0,-2.0),Vector2(-6.0,1.0)],0.6)
	var oak_drift: float = (oak.get("drift",Vector2.ZERO) as Vector2).length()
	var cosmos_drift: float = (cosmos.get("drift",Vector2.ZERO) as Vector2).length()
	scene._atmosphere.set_process(true)
	print("drift in a steady breeze of 0.6: tree seed %.2f m over %.2f s, cosmos fluff %.2f m over %.2f s" % [oak_drift,float(oak.get("seconds",0.0)),cosmos_drift,float(cosmos.get("seconds",0.0))])
	check(oak_drift > 3.0 and cosmos_drift > oak_drift,"In a breeze the flower veil drifts well downwind, further than tree seed (%.2f m against %.2f m)" % [cosmos_drift,oak_drift])
	set_wind(0.0,0.0)
	# Saves and reopens with the flowers.
	var document: Dictionary = data.to_document()
	var reopened := NativeTerrainData.new()
	reopened.setup(data.source_mesh)
	check(reopened.load_document(JSON.parse_string(JSON.stringify(document))) and reopened.objects.size() == data.objects.size(),"The world saves and reopens with its sown flowers")
	scene.queue_free()
	await process_frame
	await process_frame
