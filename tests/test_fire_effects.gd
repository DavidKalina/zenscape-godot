extends SceneTree
## FireEffects on the real fidelity scene: batches grow while a fire burns,
## return to nothing once it is out, lights stay hidden when idle, and a flame
## reads brighter than the ground it stands on under the default Balanced
## preset (no glow, display fog on).

var failures := 0
var scene: Node
var field: FireField
var effects: FireEffects
var wind := Vector3(2.4,0.0,0.9)
var rain := 0.0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
		print("FAIL: ",message)
	else:
		print("PASS: ",message)

func air(_point: Vector3) -> Vector3: return wind
func weather() -> Dictionary: return {"ground_wet":0.0,"snow_cover":0.0,"rain":rain}

func tick(seconds: float, step := 0.05) -> void:
	for i in range(int(seconds/step)):
		field.advance(step,false)
		effects.advance(step,false)

func shot() -> Image:
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	return root.get_texture().get_image()

func run() -> void:
	root.size = Vector2i(960,600)
	root.content_scale_size = root.size
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	scene._ui.visible = false
	check(not scene._environment.glow_enabled,"Fixture runs the Balanced preset with bloom off")
	var data: NativeTerrainData = scene._chunk_editor.data
	# A dry grass patch around the origin; the scene's own cover is irrelevant.
	var side := data.meadow_side()
	for z in range(side/2-8,side/2+9):
		for x in range(side/2-8,side/2+9):
			data.grass[z*side+x] = 1.0
	field = FireField.new()
	field.setup(data,air,weather,Callable(),91)
	effects = FireEffects.new()
	scene.add_child(effects)
	effects.setup(field,scene)
	check(effects.audio_source == scene._ambient_audio,"Crackle follows the scene's ambience toggle and volume")
	effects.audio_source = null
	effects.muted = true

	check(effects.get_node("Flames").multimesh.visible_instance_count == 0,"Idle world draws no flame quads")
	check(not effects.get_node("Smoke").visible and not effects.get_node("Embers").visible,"Idle world hides the smoke and ember batches")
	var lit_when_idle := 0
	for light: OmniLight3D in effects._lights:
		if light.visible: lit_when_idle += 1
	check(lit_when_idle == 0,"All four firelights are hidden when idle")
	effects.advance(0.05,false)
	check(effects._clock == 0.0,"An inactive field costs one check and no per-frame work")

	var center := field.cell_center(field.cell_at(Vector3.ZERO))
	field.ignite(center,1.2,1.0)
	tick(3.0)
	var flames: int = effects.get_node("Flames").multimesh.visible_instance_count
	var smoke: int = effects.get_node("Smoke").multimesh.visible_instance_count
	check(flames > 0,"Flame quads appear over the burning cells (%d)" % flames)
	check(smoke > 0,"Smoke puffs rise from the fire (%d)" % smoke)
	check(effects.get_node("Flames").visible and effects.get_node("Smoke").visible,"Both batches are visible while the fire burns")
	var lit := 0
	for light: OmniLight3D in effects._lights:
		if light.visible: lit += 1
	check(lit > 0 and lit <= 4,"Between one and four firelights burn (%d)" % lit)
	check(effects._lights.size() == 4,"The Forward+ light pool stays at four omnis")

	tick(4.0)
	var grown: int = effects.get_node("Flames").multimesh.visible_instance_count
	check(grown > flames,"The front spreads and the flame count grows (%d -> %d)" % [flames,grown])
	check(effects.get_node("Embers").multimesh.visible_instance_count > 0,"Hot cells throw embers")
	check(effects.get_node("Flames").multimesh.visible_instance_count <= FireEffects.FLAME_CAP,"Flames respect the 384 cap")

	# One pixel: the flame column against the same view with the batch hidden.
	var fire := field.cell_center(field.burning_cells()[0])
	scene.camera.global_position = fire+Vector3(0.0,1.1,4.2)
	scene.camera.look_at(fire+Vector3(0.0,0.55,0.0))
	if scene._display_fog != null:
		scene._display_fog.update_view()
	var lit_shot: Image = await shot()
	effects.get_node("Flames").visible = false
	effects.get_node("Smoke").visible = false
	effects.get_node("Embers").visible = false
	var bare: Image = await shot()
	effects.get_node("Flames").visible = true
	effects.get_node("Smoke").visible = true
	effects.get_node("Embers").visible = true
	# The pixel the flame batch changes most, then the same coordinate in the
	# flameless shot. No projection maths, so the proof survives whatever the
	# window manager does to the backbuffer size.
	var point := Vector2i.ZERO
	var best := 0.0
	for y in range(0,lit_shot.get_height(),2):
		for x in range(0,lit_shot.get_width(),2):
			var gain := lit_shot.get_pixel(x,y).r-bare.get_pixel(x,y).r
			if gain > best:
				best = gain
				point = Vector2i(x,y)
	var hot := lit_shot.get_pixelv(point)
	var cold := bare.get_pixelv(point)
	print("  flame pixel %s: %.3f,%.3f,%.3f over %.3f,%.3f,%.3f" % [point,hot.r,hot.g,hot.b,cold.r,cold.g,cold.b])
	check(hot.r > cold.r+0.15 and hot.r > hot.b*1.5 and hot.r > hot.g,"A flame reads brighter and warmer than the ground behind it")

	# Rain out, then wait for the smoulder and the last puff to expire.
	rain = 1.0
	tick(14.0)
	check(not field.active(),"Rain puts the fire out")
	tick(30.0)
	check(effects.get_node("Flames").multimesh.visible_instance_count == 0,"No flame quads survive the fire")
	check(effects.get_node("Smoke").multimesh.visible_instance_count == 0,"Smoke and smoulder clear after twenty seconds")
	check(effects.get_node("Embers").multimesh.visible_instance_count == 0,"Embers clear")
	check(not effects.get_node("Flames").visible and not effects.get_node("Smoke").visible,"The batches hide themselves again")
	var relit := 0
	for light: OmniLight3D in effects._lights:
		if light.visible: relit += 1
	check(relit == 0,"Firelights go out with the fire")
	var mark := effects._clock
	effects.advance(0.05,false)
	check(effects._clock == mark,"An extinguished field returns to the idle fast path")

	effects.clear()
	check(effects._puffs.is_empty() and effects._sparks.is_empty(),"clear() drops every particle")
	print("FIRE EFFECTS: failures=",failures)
	scene.free()
	effects = null
	field = null
	quit(1 if failures else 0)
