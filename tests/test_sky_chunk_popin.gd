extends SceneTree
## A sky chunk shows from afar what it will show once claimed (scripts/
## sky_islands.gd `_bake`, `_stand`), so flying into it nothing pops in.
## Before, a chunk was only its ground and earth sides: its wild tree, the
## ground's form and the shade under the tree all came in at the claim, its
## ground read the plate's maps and the plate's world-placed look, and its
## material was the build brush's copy.
##
## Flown into from the glide, a fixed chunk is claimed. Its far version's
## trees and cover (positions, species, scale) are the ones the live plate
## lays out after the claim; its ground's maps are the ones the plate makes
## for the same land; its ground, earth sides and plants wear the plate's and
## the garden's own materials, reading the look from the plate's spot; the
## island left behind keeps what stood on the plate. The handover keeps to
## the sky's frame share: standing a chunk up stays a few ms, the claim's
## steps and the frame of the swap stay bounded.
##
## Headless measures the scripts only, never the GPU's uploads or pipeline
## builds, and checks arrays and nodes, never pixels; how it looks is
## checked with a rendered glide.
const SkyCommits = preload("res://scripts/sky_commits.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
## Positions agree within this (m), scales within this share.
const NEAR := 0.01
const SCALE := 0.01
## The maps' heights agree within this (m).
const HEIGHT := 0.001
## Each commit, at most (ms): a chunk's nodes (ground, sides, plants and
## two map textures); the claim's steps; the swap's whole frame (uncapped,
## headless). Loose, so a slower machine passes and a stall still fails.
const ISLAND_MS := 4.0
const CLAIM_STEP_MS := 60.0
const SWAP_FRAME_MS := 120.0
const SYNC_MS := 8.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: push_error("sky chunk pop-in test timed out"); quit(2))
	root.unfocusable = true
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-popin-test-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	var editor: NativeChunkEditor = scene._chunk_editor
	var eye: Node = scene.wanderer
	var islands: Node3D = eye.islands
	SkyCommits.log.clear()
	SkyCommits.recording = true
	var waited := 0
	while not islands.sky_ready() and waited < 6000:
		islands.make_ahead(1.0/60.0)
		waited += 1
		await process_frame
	scene.world_clock.running = false
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await process_frame
	eye._launch(6.0,false)
	eye.set_process(false)
	for i in range(10): await process_frame
	var index := 0
	while islands.lands[index] == null: await process_frame
	var island: Node3D = islands._copies[index]
	var land: NativeTerrainData = islands.lands[index]
	var far: Dictionary = island.get_meta("far",{})
	check(not land.objects.is_empty(),"The chunk's plain has its seed's wild tree (%d records)" % land.objects.size())
	print("     on its worker: plants %.1f ms, maps %.1f ms" % [int(far.get("flora_usec",0))/1000.0,int(far.get("maps_usec",0))/1000.0])
	_far_nodes(islands,island,far)
	# The plate's own, before it is left: what stands on it, by part.
	var left_counts := _counts(editor.content._sources)
	var left_home: Vector3 = -islands.origin
	# Into its footprint, as the flight's own frame claims it.
	var target: Vector3 = islands.homes[index]
	var far_flora := _far_transforms(far.get("flora",{}))
	eye.glide.position = islands.offsets[index]+Vector3.UP*30.0
	var frames: Array[float] = []
	var last := Time.get_ticks_usec()
	var fps_was := Engine.max_fps
	Engine.max_fps = 0
	var was_copy := island
	eye._claim(index)
	var swap_ms := 0.0
	while islands.claiming:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-last)/1000.0)
		last = now
	# The frame the swap is drawn in: the far island gone, the plate shown.
	swap_ms = frames[-1] if not frames.is_empty() else 0.0
	await process_frame
	Engine.max_fps = fps_was
	SkyCommits.recording = false
	check(not is_instance_valid(was_copy) or was_copy.is_queued_for_deletion(),"The claimed chunk's far island is let go")
	check(islands.homes.find(target) < 0,"The claimed chunk is the plate now")
	editor.ground_shade.finish()
	# Carrying the plate's and garden's settings over to every far island's
	# copies, as a glide starts and a claim ends.
	var sync_began := Time.get_ticks_usec()
	islands._sync_looks()
	var sync_ms := (Time.get_ticks_usec()-sync_began)/1000.0
	check(sync_ms <= SYNC_MS,"Carrying the materials' settings over to %d far islands takes %.2f ms (at most %.0f)" % [islands.copy_count(),sync_ms,SYNC_MS])
	_live_matches(editor,land,far_flora)
	_maps_match(editor,far.get("maps",{}))
	_left_behind(islands,left_home,left_counts)
	_budget(frames,swap_ms)
	scene.queue_free()
	await process_frame
	print("PASS: sky chunk pop-in" if failures == 0 else "FAIL: sky chunk pop-in")
	quit(1 if failures else 0)

## The far island's nodes: its ground in a copy of the plate's own ground
## material reading its own maps, its sides, its plants in copies of the
## garden's own, all reading the look from the plate's spot.
func _far_nodes(islands: Node3D, island: Node3D, far: Dictionary) -> void:
	var editor: NativeChunkEditor = islands.editor
	var garden: GardenView = editor.content
	var ground := island.get_child(0) as MeshInstance3D
	var sides := island.get_child(1) as MeshInstance3D
	var flora := island.get_node_or_null("Flora") as Node3D
	check(flora != null and flora.get_child_count() > 0,"From afar the chunk shows what stands on it (%d batches)" % (flora.get_child_count() if flora != null else 0))
	var shift: Vector3 = island.global_position
	var material := ground.material_override as ShaderMaterial
	check(material != null and bool(material.get_shader_parameter("own_maps")) and material.get_shader_parameter("own_water_map") is Texture2D and material.get_shader_parameter("own_ground_shade") is Texture2D,"Its ground reads its own maps, never the plate's")
	check(material != null and _same_params(material,islands.plate_ground_material() as ShaderMaterial,["own_maps","own_water_map","own_ground_shade","look_shift"]),"Its ground wears the plate's own ground material (not the build brush's copy)")
	check(ground.cast_shadow == editor.terrain.cast_shadow,"Its ground casts shadow as the plate's does")
	var looks: Array = [material,sides.material_override]
	var species_ok := flora != null
	if flora != null:
		for batch: MultiMeshInstance3D in flora.get_children():
			var key: String = batch.get_meta("part")
			var own := batch.material_override as ShaderMaterial
			looks.append(own)
			species_ok = species_ok and batch.multimesh.mesh == garden._meshes.get(key) and own != null and _same_params(own,garden._materials.get(key),SkyIslands.FAR_OFF+["look_shift"])
			for flag: String in SkyIslands.FAR_OFF: species_ok = species_ok and not bool(own.get_shader_parameter(flag))
		check(flora.transform.is_equal_approx(garden.global_transform),"Its plants stand where the garden's own do, from the island")
	check(species_ok,"Its plants are drawn with the garden's own meshes, and its own materials but for what reads the plate's spot")
	var shifted := true
	for look: Variant in looks: shifted = shifted and look is ShaderMaterial and ((look as ShaderMaterial).get_shader_parameter("look_shift") as Vector3).is_equal_approx(shift)
	check(shifted,"Its ground, sides and plants read the look the plate's spot gives (look_shift %s)" % shift)

## Every shader parameter of `a` is `b`'s, but `skip` (one never set reads
## as the shader's default; headless knows none, so unset reads as the
## other's type's zero, as an unset bool's false).
func _same_params(a: ShaderMaterial, b: ShaderMaterial, skip: Array) -> bool:
	if a == null or b == null or a.shader != b.shader: return false
	for u: Dictionary in a.shader.get_shader_uniform_list():
		var name: String = u.name
		if name in skip: continue
		var fallback: Variant = RenderingServer.shader_get_parameter_default(a.shader.get_rid(),name)
		var x: Variant = a.get_shader_parameter(name)
		var y: Variant = b.get_shader_parameter(name)
		if x == null: x = fallback if fallback != null or y == null else type_convert(0,typeof(y))
		if y == null: y = fallback if fallback != null or x == null else type_convert(0,typeof(x))
		if x != y:
			print("     differs: %s %s / %s" % [name,x,y])
			return false
	return true

## Per part, the instance transforms a far island's packed buffers hold.
func _far_transforms(flora: Dictionary) -> Dictionary:
	var out := {}
	for key: String in flora:
		var buffer: PackedFloat32Array = flora[key].buffer
		var list: Array[Transform3D] = []
		for i in range(int(flora[key].count)):
			var o := i*20
			list.append(Transform3D(Vector3(buffer[o],buffer[o+4],buffer[o+8]),Vector3(buffer[o+1],buffer[o+5],buffer[o+9]),Vector3(buffer[o+2],buffer[o+6],buffer[o+10]),Vector3(buffer[o+3],buffer[o+7],buffer[o+11])))
		out[key] = list
	return out

## The live plate's garden after the claim, per part, from what it
## published (its sources: each record's spot, basis and part pose), read
## against the live land: the same parts, the same instances, in the same
## spots at the same scale.
func _live_matches(editor: NativeChunkEditor, land: NativeTerrainData, far: Dictionary) -> void:
	var data := editor.data
	var same_records := data.objects.size() == land.objects.size()
	for i in range(mini(data.objects.size(),land.objects.size())):
		var a: Dictionary = data.objects[i]
		var b: Dictionary = land.objects[i]
		same_records = same_records and a.asset == b.asset and Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z)) < NEAR and absf(float(a.scale)-float(b.scale)) < SCALE
	check(same_records,"The plate holds the records the far island was laid out from (%d)" % data.objects.size())
	var live := {}
	for key: String in editor.content._sources:
		var list: Array[Transform3D] = []
		for source: Dictionary in editor.content._sources[key]:
			var at: Vector3
			if source.item != null: at = data.object_position(source.item)
			else: at = Vector3(float(source.x),float(data.ground_height(Vector2(source.x,source.z))),float(source.z))
			var t := Transform3D(source.basis,at)
			if source.get("pose") != null: t = t*(source.pose as Transform3D)
			t.origin.y += float(source.get("lift",0.0))
			list.append(t)
		if not list.is_empty(): live[key] = list
	var far_keys := far.keys()
	var live_keys := live.keys()
	far_keys.sort()
	live_keys.sort()
	check(far_keys == live_keys,"Far and live draw the same parts (species): %s / %s" % [far_keys,live_keys])
	var worst_spot := 0.0
	var worst_scale := 0.0
	var compared := 0
	var counts_ok := true
	for key: String in live:
		var a: Array = far.get(key,[])
		var b: Array = live[key]
		counts_ok = counts_ok and a.size() == b.size()
		for t: Transform3D in b:
			var best := INF
			var pick: Transform3D
			for u: Transform3D in a:
				var d := u.origin.distance_to(t.origin)
				if d < best:
					best = d
					pick = u
			if best == INF: continue
			worst_spot = maxf(worst_spot,best)
			worst_scale = maxf(worst_scale,absf(pick.basis.get_scale().y/maxf(t.basis.get_scale().y,0.0001)-1.0))
			worst_scale = maxf(worst_scale,(pick.basis.orthonormalized().get_rotation_quaternion().angle_to(t.basis.orthonormalized().get_rotation_quaternion())))
			compared += 1
	check(counts_ok and compared > 0,"Far and live draw as many of each part (%d instances)" % compared)
	check(worst_spot <= NEAR,"Each far instance stands where the live one does (worst %.4f m)" % worst_spot)
	check(worst_scale <= SCALE,"Each far instance is the live one's scale and turn (worst %.4f)" % worst_scale)
	# And the live batches' own buffers, where the renderer keeps them.
	var buffers_ok := true
	var read := 0
	for batch: MultiMeshInstance3D in editor.content._batches:
		var key: String = batch.get_meta("part")
		var buffer := batch.multimesh.buffer
		if buffer.is_empty() or not far.has(key): continue
		var mine: Array = _far_transforms({key:{"buffer":buffer,"count":batch.multimesh.instance_count}})[key]
		for i in range(mini(mine.size(),(far[key] as Array).size())):
			buffers_ok = buffers_ok and (mine[i] as Transform3D).is_equal_approx(far[key][i])
		read += 1
	print("     live batch buffers read back: %d (headless may keep none)" % read)
	check(buffers_ok,"Where the live batches' buffers read back, they are the far island's")

## The far island's ground maps are the ones the plate makes for its land.
func _maps_match(editor: NativeChunkEditor, maps: Dictionary) -> void:
	check(not maps.is_empty(),"The far island has its ground's maps")
	if maps.is_empty(): return
	var a: Image = maps.ground
	var b: Image = editor._map_ground
	var worst := 0.0
	var water := 0.0
	var same_size := b != null and a.get_size() == b.get_size()
	if same_size:
		for z in range(a.get_height()):
			for x in range(a.get_width()):
				var p := a.get_pixel(x,z)
				var q := b.get_pixel(x,z)
				worst = maxf(worst,absf(p.g-q.g))
				water = maxf(water,absf(p.a-q.a))
	check(same_size and worst <= HEIGHT and water <= HEIGHT,"Its height and water map is the plate's for the same land (worst %.5f m, water %.5f m)" % [worst,water])
	var field: PackedFloat32Array = maps.shade_field
	var live: PackedFloat32Array = editor.ground_shade.field
	var shade := 0.0
	for i in range(mini(field.size(),live.size())): shade = maxf(shade,absf(field[i]-live[i]))
	var shaded := 0
	for v in field: if v > 0.01: shaded += 1
	check(field.size() == live.size() and shade <= 0.001 and shaded > 0,"Its trees' shade is the plate's for the same trees (%d texels shaded, worst %.4f)" % [shaded,shade])

## The island left at the claim keeps what stood on the plate.
func _left_behind(islands: Node3D, home: Vector3, counts: Dictionary) -> void:
	var at: int = islands.homes.find(home)
	check(at >= 0,"The island left behind stands where the plate was")
	if at < 0: return
	var far: Dictionary = (islands._copies[at] as Node3D).get_meta("far",{})
	var mine := {}
	for key: String in far.get("flora",{}): mine[key] = int(far.flora[key].count)
	check(mine == counts and not counts.is_empty(),"The island left behind shows what stood on the plate: %s" % [mine])

func _counts(sources: Dictionary) -> Dictionary:
	var out := {}
	for key: String in sources:
		if not (sources[key] as Array).is_empty(): out[key] = (sources[key] as Array).size()
	return out

## The sky's frame share through the bake and the claim (SkyCommits).
func _budget(frames: Array[float], swap_ms: float) -> void:
	var commits: Array = SkyCommits.log.duplicate()
	var spent := {}
	var late := 0
	var island_ms: Array[float] = []
	var claim_ms := 0.0
	for c: Array in commits:
		if (c[1] as String).begins_with("claim:"):
			claim_ms = maxf(claim_ms,c[2]/1000.0)
			continue
		if int(spent.get(c[0],0)) >= SkyCommits.BUDGET_USEC: late += 1
		spent[c[0]] = int(spent.get(c[0],0))+maxi(int(c[2]),1)
		if c[1] == "island": island_ms.append(c[2]/1000.0)
	island_ms.sort()
	var worst := 0.0
	for f in frames: worst = maxf(worst,f)
	print("     chunk stand-ups (ms): %s" % [island_ms])
	print("     claim: %d frames, worst %.1f ms, swap frame %.1f ms, worst claim step %.1f ms" % [frames.size(),worst,swap_ms,claim_ms])
	check(late == 0,"No frame stands a part up once its share is spent (%d did)" % late)
	check(not island_ms.is_empty() and island_ms[-1] <= ISLAND_MS,"Standing a chunk up, plants, maps and all, takes %.2f ms at most (at most %.1f)" % [island_ms[-1] if not island_ms.is_empty() else -1.0,ISLAND_MS])
	check(claim_ms <= CLAIM_STEP_MS,"Each step of the claim takes %.1f ms (at most %.0f)" % [claim_ms,CLAIM_STEP_MS])
	check(swap_ms <= SWAP_FRAME_MS and worst <= SWAP_FRAME_MS,"The swap's frame takes %.1f ms, the claim's worst %.1f ms (at most %.0f)" % [swap_ms,worst,SWAP_FRAME_MS])
