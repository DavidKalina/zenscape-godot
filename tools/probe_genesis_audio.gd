extends SceneTree
## Headless wiring probe for Genesis sound (scripts/genesis_audio.gd,
## docs/scenic/sound.md). The dummy audio driver mixes nothing, so this checks
## what would play and how loud, not how it sounds: each brush's stroke voice
## rises while the brush is down and falls after release, a pour's glugs and
## trickle follow its fill, creation beds follow the survey, one-shots stay
## sparse, and GenesisAudio's own time per frame stays small.
##   godot --headless --path . -s res://tools/probe_genesis_audio.gd
var scene: Node3D
var editor: NativeChunkEditor
var audio: Node
var frames: Array[float] = []
var own: Array[float] = []

func _initialize() -> void: run.call_deferred()

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.001),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.001),"max":snappedf(sorted.back(),0.001)}

func gains() -> Array:
	var out := []
	for gain in audio._gain: out.append(snappedf(gain,0.001))
	return out

func frame() -> void:
	var previous := Time.get_ticks_usec()
	await process_frame
	frames.append((Time.get_ticks_usec()-previous)/1000.0)
	own.append(audio.last_usec/1000.0)

func hit(p: Vector2) -> Vector3:
	var ground: Variant = editor.data.ground_height(p)
	return Vector3(p.x,float(ground) if ground != null else 0.0,p.y)

## One held stroke with the creation brush `brush`, emitting the stroke signals
## the pointer path would. Prints the voice gains at their peak and after release.
func stroke(brush: String, a: Vector2, b: Vector2, count := 30) -> void:
	editor.select_brush(brush)
	editor._level = 0.0
	editor._land_lower = false
	var settles: bool = editor.creation_brush().settles
	if not settles: editor.data.begin_stroke()
	editor._stroke_first_id = editor.data.next_id
	editor.creation_brush().prepare(editor.data,editor.land_seed)
	editor.creation_brush().begin()
	editor._painting = true
	editor._emit_stroke(0,hit(a),editor.brush_radius(),0.0)
	var peak := PackedFloat32Array()
	peak.resize(audio.VOICES)
	for dab in range(count):
		var point := a.lerp(b,float(dab)/(count-1))
		editor.land_dab(point,editor.brush_strength()/30.0)
		if not settles:
			editor._touch(point,editor.brush_radius())
			editor.refresh()
		editor._emit_stroke(1,hit(point),editor.brush_radius(),editor.brush_strength()/30.0)
		await frame()
		await frame()
		for i in range(audio.VOICES): peak[i] = maxf(peak[i],audio._gain[i])
	editor.finish_stroke()
	var after := []
	for second in range(4):
		for _i in range(30): await frame()
		after.append(gains())
	var rounded := []
	for value in peak: rounded.append(snappedf(value,0.001))
	print("SOUND stroke ",JSON.stringify({"brush":brush,"voices":audio.VOICE_CLIPS,"peak":rounded,"after_seconds":after}))

func run() -> void:
	create_timer(170).timeout.connect(func() -> void: push_error("Genesis audio probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-sound-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.get("shell_ready"): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	audio = scene.genesis_audio
	editor.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	for _i in range(60): await frame()
	var buses := []
	for i in range(AudioServer.bus_count): buses.append([AudioServer.get_bus_name(i),AudioServer.get_bus_send(i),AudioServer.get_bus_effect_count(i)])
	print("SOUND buses ",JSON.stringify(buses))
	print("SOUND bare ",JSON.stringify({"active":audio._active,"plain":snappedf(audio._plain_target,0.001),"rustle":snappedf(audio._rustle_target,0.001),"song":audio._nature().song_presence,"cricket":audio._nature().cricket_presence}))
	await stroke("land",Vector2(-4,-2.5),Vector2(3,2))
	await stroke("water",Vector2(4,4),Vector2(6,5),20)
	# The emergence clock (ponds rising, streams running) ticks in the editor.
	editor.set_process(true)
	# Wait for the pour to settle and report its glug and trickle windows.
	var waited := 0
	while (editor.water_settling or audio._fill.y < 0.0) and waited < 600:
		editor.set_process(true)
		await frame()
		waited += 1
	var fill_peak := 0.0
	var run_peak := 0.0
	var pitch := []
	for _i in range(360):
		await frame()
		fill_peak = maxf(fill_peak,audio._gain[audio.FILL])
		run_peak = maxf(run_peak,audio._gain[audio.RUN])
		if _i%60 == 0: pitch.append(snappedf(audio._voices[audio.FILL].pitch_scale,0.01))
	print("SOUND pour ",JSON.stringify({"fill_window":[snappedf(audio._fill.x,0.1),snappedf(audio._fill.y,0.1)],"run_window":[snappedf(audio._run.x,0.1),snappedf(audio._run.y,0.1)],"fill_peak":snappedf(fill_peak,0.001),"run_peak":snappedf(run_peak,0.001),"fill_pitch":pitch,"after":gains()}))
	editor.set_process(false)
	await stroke("forest",Vector2(-8,4),Vector2(-3,7))
	await stroke("meadow",Vector2(-6,-8),Vector2(0,-6))
	await stroke("path",Vector2(0,-9),Vector2(6,-6))
	editor.set_process(true)
	# Let emergence grow the wood and LandLife survey it.
	var until := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec() < until: await frame()
	var nature: Node = audio._nature()
	print("SOUND grown ",JSON.stringify({"trees":audio._trees,"shrubs":audio._shrubs,"water_m2":snappedf(audio._water_area,0.1),"wood_points":audio._wood.size(),"plain":snappedf(audio._plain_target,0.001),"rustle":snappedf(audio._rustle_target,0.001),"song":snappedf(nature.song_presence,0.01),"cricket":snappedf(nature.cricket_presence,0.01),"frog":nature.frog_presence,"song_points":nature.song_points.size(),"played":audio.played}))
	# Moments and arrivals, fed straight in: sparse, pooled, and the hush.
	var at: Vector3 = editor.terrain.global_transform*hit(Vector2(-5,5))
	audio._quiet = 0.0
	audio._on_arrived("fish",at)
	audio._on_arrived("fish",at)
	audio._on_arrived("frog",at)
	for _i in range(100): await frame()
	audio._on_arrived("frog",at)
	audio._on_moment("heron",at)
	audio._on_moment("deer",at)
	audio._on_moment("rainbow",at)
	for _i in range(100): await frame()
	audio._rng.seed = 1
	audio._on_moment("bigfoot",at)
	for _i in range(60*8): await frame()
	print("SOUND moments ",JSON.stringify({"played":audio.played,"pending":audio._pending.size(),"hush":snappedf(audio._hush,0.1),"song_after_bigfoot":snappedf(nature.song_presence,0.01)}))
	print("SOUND frames ",JSON.stringify({"all_ms":stats(frames),"genesis_audio_ms":stats(own),"worst_ms":audio.worst_usec/1000.0}))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()
