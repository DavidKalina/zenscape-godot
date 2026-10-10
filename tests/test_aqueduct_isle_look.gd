extends SceneTree
## The aqueduct isle in the game's look (studies/aqueduct_isle.gd,
## studies/aqueduct_isle_flora.gd), headless: the game's grass tufts and
## meadow flowers grow on the turf, drawn as the catalog's multimeshes with
## its plant materials, kept off the paths' middles, off the crags and off
## anything standing; and every look preset the edit mode offers applies
## through the game's own SceneLookPresets.apply and reads back as applied
## (SceneLookPresets.matches), L steps through them in the editor's order,
## a bad --look id falls back, and First snow lays snow on the ground.
##   godot --headless --path . --script tests/test_aqueduct_isle_look.gd
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Flora = preload("res://studies/aqueduct_isle_flora.gd")
## The fewest tufts and flowers that still make a meadow, and the most
## instanced triangles the plants may draw.
const MIN_TUFTS := 4000
const MIN_FLOWERS := 150
const MAX_FLOWERS := 1500
const TRIANGLE_BUDGET := 1200000
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("aqueduct isle look test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	_flora()
	_presets()
	print("PASS: aqueduct isle look" if failures == 0 else "FAIL: aqueduct isle look (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _flora() -> void:
	var flora: Node3D = study.flora
	var counts: Dictionary = flora.get_meta("counts")
	var tufts := int(counts.get("grass_tuft",0))
	var flowers := 0
	for kind: String in ["buttercup","lupine","oxeye_daisy","dandelion"]: flowers += int(counts.get(kind,0))
	check(tufts >= MIN_TUFTS,"%d grass tufts grow on the turf (at least %d)" % [tufts,MIN_TUFTS])
	check(flowers >= MIN_FLOWERS and flowers <= MAX_FLOWERS,"%d meadow flowers, a sowing not a carpet (%d to %d)" % [flowers,MIN_FLOWERS,MAX_FLOWERS])
	var tris := int(flora.get_meta("triangles"))
	check(tris < TRIANGLE_BUDGET,"The plants draw %d instanced triangles at most (budget %d)" % [tris,TRIANGLE_BUDGET])
	# Drawn as the game draws them: the catalog's grass tuft and flower kit
	# meshes, its plant materials (the shader that sways them), in tiles.
	var grass := 0
	var petals := 0
	var swaying := true
	for batch: Node in flora.get_children():
		var mmi := batch as MultiMeshInstance3D
		if mmi == null: continue
		var part: String = mmi.get_meta("part","")
		if part.begins_with("grass_tuft"): grass += mmi.multimesh.instance_count
		if part.contains("meadow-flower"): petals += mmi.multimesh.instance_count
		var material := mmi.material_override as ShaderMaterial
		if material == null or not material.shader.resource_path.ends_with("reference_surface.gdshader"): swaying = false
		if mmi.visibility_range_end <= 0.0: swaying = false
	check(grass == tufts and petals > 0,"Tufts and flowers drawn as the catalog's multimeshes (%d tufts, %d flower heads)" % [grass,petals])
	check(swaying,"Every plant batch wears the game's plant shader and fades out by range")
	check(flora.get_child_count() > 20,"The plants are tiled (%d batches), so each tile culls" % flora.get_child_count())
	# Where they stand: on the paths' middles nowhere, on crag faces nowhere,
	# and every root on the turf the ground probe finds.
	var on_path := 0
	var steep := 0
	var off_ground := 0
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	var limit := float(Art.palette().rock_slope)
	for item: Dictionary in flora.get_meta("records"):
		var p := Vector2(item.x,item.z)
		if Art.path_wear(p) > Flora.PATH_BARE: on_path += 1
		ray.from = Vector3(p.x,Art.TOP+60.0,p.y)
		ray.to = Vector3(p.x,Art.TOP-8.0,p.y)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or not study._turf.has(hit.collider):
			off_ground += 1
			continue
		var n: Vector3 = hit.normal
		if sqrt(maxf(0.0,1.0-n.y*n.y))/maxf(n.y,0.001) > limit: steep += 1
	check(on_path == 0,"No plant on a path's middle (%d)" % on_path)
	check(steep == 0,"No plant on a crag face (%d)" % steep)
	check(off_ground == 0,"Every plant roots on open turf, nothing standing over it (%d off)" % off_ground)
	check(study.wake != null and study.wake.motor == study.motor,"The pilot's wake parts the plants")

func _presets() -> void:
	check(study.look_id == study.START_LOOK and SceneLookPresets.matches(study,study.START_LOOK),"The isle opens in %s" % study.START_LOOK)
	var ids: Array = SceneLookPresets.PRESETS.keys()
	var bad: Array = []
	for id: String in ids:
		study.apply_look(id)
		for i in range(3): study._process(1.0/60.0)
		if not SceneLookPresets.matches(study,id) or study.look_id != id: bad.append(id)
	check(bad.is_empty(),"All %d look presets apply as the look editor applies them %s" % [ids.size(),bad])
	study.apply_look("first_snow")
	for i in range(30): study._process(1.0/60.0)
	check(study._precipitation.surface_weather.snow_cover > 0.3,"First snow lays snow on the ground (cover %.2f)" % study._precipitation.surface_weather.snow_cover)
	check(study._celestial.look.palette == "Custom" and study._environment.tonemap_exposure > 0.0,"The preset's scene look and exposure are on")
	study.apply_look("nordic_night")
	check(study._celestial.sun_height < 0.0,"Nordic night puts the sun down (height %.2f)" % study._celestial.sun_height)
	study.step_look(1)
	check(study.look_id == ids[(ids.find("nordic_night")+1)%ids.size()],"L steps to the next preset in the editor's order (%s)" % study.look_id)
	study.step_look(-1)
	check(study.look_id == "nordic_night","Shift+L steps back")
	study.apply_look("no_such_look")
	check(study.look_id == "nordic_night","An unknown preset id changes nothing")
	check(study._look_toast != null and study._look_toast.text.begins_with("Nordic night"),"The preset's name shows on a change")
