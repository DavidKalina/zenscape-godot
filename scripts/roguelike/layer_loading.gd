extends Node
## Holds play behind a loading screen until the generator's layer stands
## whole (docs/design/roguelike/loading-screen-round1.md). The study
## (studies/run_layer.gd) makes one of these when it is rendered and
## unscripted (`wanted`); `--no-loading-screen` leaves the layer to stream
## in round the player as before.
##
## While `active`:
##   - the study does not tick the pilot, the run loop stands still
##     (`holding`), and keys are dropped; the world is drawn under the screen;
##   - the sky's frame budget (scripts/sky_commits.gd `lifted`) is LIFT_USEC
##     rather than 4 ms, so the isles' main-thread stages (parts stood,
##     colliders put back, turf, plants, life) go as fast as the machine
##     allows; the main thread may block for a slice, so the screen redraws
##     at about 15-20 fps rather than freezing;
##   - the next region is laid at once (scripts/roguelike/next_region_loader.gd
##     `eager`), not after the isles stand;
##   - it waits for every motif isle to be up, the Broken Viaduct stood
##     (scripts/roguelike/layer_hazards.gd `_waiting`) and the next region
##     stood; the screen's line is driven by those real stages;
##   - then the materials are warmed (`_warm`): the camera is moved over the
##     stood layer, a view at a time for a couple of frames, so every
##     shader and pipeline the layer draws is built under the screen.
## Then the screen fades away and play begins. A new layer (the gate, a new
## climb) raises it again (`begin_change`); a layer laid behind the fall
## card while it is read joins it at the isles (`begin_late`).
const LoadingScreen = preload("res://scripts/roguelike/loading_screen.tscn")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")

## The sky's frame budget while loading (usec): a frame of about this long.
const LIFT_USEC := 45000
## Frames each warm-up view is held (the first builds the pipeline, the
## rest let shadow and specialisation passes catch up).
const WARM_FRAMES := 2
## Seconds the screen takes to come up over a layer that was playing, and to
## go.
const FADE_IN := 0.45
const FADE_OUT := 1.0
## The most a warm-up may take (s) before it gives up and drops the screen.
const WARM_MOST := 90.0
## How far each stage of an isle is on its way to up (0..1), by its
## `stage`.
const WEIGHT := {"waiting":0.0,"building":0.12,"built":0.3,"standing":0.4,"turf":0.5,"flora":0.62,"life":0.88,"up":1.0}
const RANK := {"waiting":0,"building":1,"built":2,"standing":3,"turf":4,"flora":5,"life":6,"up":7}
## The bar: where the isles' share ends, and where the extras' ends (the
## warm-up takes the rest).
const BAR_PLAN := 0.03
const BAR_ISLES := 0.80
const BAR_EXTRAS := 0.88

var study: Node3D
var screen: CanvasLayer
## True while play is held.
var active := false
## "plan", "isles", "extras", "warm", "".
var phase := ""
## When the stages were reached (ms since the engine started), for the log.
var times := {}
var _layers_at := 0
var _began := 0
var _first := false
var _warm_share := 0.0
var _flat := ""
## Warm-up done once for the session: the plane, the dragon, a body.
static var warmed_extras := false

## Whether this scene should hold play behind the screen: rendered, not
## scripted, and not `--no-loading-screen`.
static func wanted(scene: Node) -> bool:
	if DisplayServer.get_name() == "headless": return false
	if bool(scene.get("scripted")): return false
	return not "--no-loading-screen" in preload("res://scripts/launch_args.gd").user_args()

## The full sweep (every isle, the plane, the dragon, a body): on by default
## except on macOS, where round 1 measured no gain from it (Metal's shader
## cache and ubershaders); --shader-warmup asks for it there,
## --no-shader-warmup turns it off anywhere. Without it the pilot's own view
## is still drawn WARM_SELF frames under the screen before it goes.
static func warm_wanted() -> bool:
	var args := preload("res://scripts/launch_args.gd").user_args()
	if "--no-shader-warmup" in args: return false
	if "--shader-warmup" in args: return true
	return OS.get_name() != "macOS"

## Frames the pilot's own view is drawn under the screen before it goes.
const WARM_SELF := 4

func _init() -> void:
	name = "LayerLoading"
	process_priority = 100

## The first layer: the screen at once, over a window the scene has not
## drawn yet.
func begin_first() -> void:
	_first = true
	_start("laying the way")
	_layers_at = 0
	screen.reveal(0.0)

## A new layer asked for over a layer being played: the screen fades up.
func begin_change() -> void:
	if active: return
	_first = false
	_start("laying the way")
	_layers_at = int(study.get("layers"))
	screen.reveal(FADE_IN)

## The player has asked to go on while a layer laid behind the card is still
## standing: the screen over it, picking up at the isles.
func begin_late() -> void:
	if active: return
	if _all_up(): return
	_first = false
	_start("")
	phase = "isles"
	_layers_at = int(study.get("layers"))-1
	screen.reveal(FADE_IN)

func _start(line: String) -> void:
	active = true
	phase = "plan"
	_began = Time.get_ticks_msec()
	times = {"begin":_began}
	_warm_share = 0.0
	if screen == null:
		screen = LoadingScreen.instantiate()
		study.add_child(screen)
	screen.set_progress(0.0)
	screen.set_line(line)
	SkyCommits.lifted = LIFT_USEC
	if "--loading-trace" in preload("res://scripts/launch_args.gd").user_args(): SkyCommits.recording = true
	set_process(true)

func holding() -> bool:
	return active

func _exit_tree() -> void:
	SkyCommits.lifted = 0
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
		screen = null

func _process(_delta: float) -> void:
	if not active or study == null: return
	match phase:
		"plan":
			screen.set_progress(0.0 if _first else 0.01)
			if int(study.get("layers")) > _layers_at and study.get("stage") != null:
				phase = "isles"
				times.planned = Time.get_ticks_msec()
				_ready_next()
		"isles":
			var info := _isles()
			screen.set_progress(BAR_PLAN+(BAR_ISLES-BAR_PLAN)*float(info.share))
			screen.set_line(str(info.line))
			if bool(info.done):
				phase = "extras"
				times.isles = Time.get_ticks_msec()
		"extras":
			var info := _extras()
			screen.set_progress(BAR_ISLES+(BAR_EXTRAS-BAR_ISLES)*float(info.share))
			screen.set_line(str(info.line))
			if bool(info.done):
				phase = "warm"
				times.extras = Time.get_ticks_msec()
				_warm()
		"warm":
			pass

## The next region is laid now, not after the isles stand.
func _ready_next() -> void:
	var stage: Node = study.get("stage")
	if stage == null: return
	var loader := stage.get_node_or_null("NextRegionLoader")
	if loader != null: loader.set("eager",true)

func _motifs() -> Node:
	var sky: Variant = study.get("sky")
	return sky.get("motifs") if sky != null else null

func _all_up() -> bool:
	var motifs := _motifs()
	if motifs == null: return true
	for isle: Node3D in motifs.isles:
		if not isle.is_up(): return false
	return not (motifs.isles as Array).is_empty() or study.get("stage") != null

## Where the isles are: {share (0..1), line, done}.
func _isles() -> Dictionary:
	var motifs := _motifs()
	if motifs == null: return {"share":1.0,"line":"","done":true}
	var list: Array = motifs.isles
	var n := list.size()
	if n == 0: return {"share":1.0,"line":"","done":true}
	var sum := 0.0
	var built := 0
	var grown := 0
	var up := 0
	for isle: Node3D in list:
		var s: String = isle.stage
		sum += float(WEIGHT.get(s,0.0))
		var r := int(RANK.get(s,0))
		if r >= 2: built += 1
		if r >= 6: grown += 1
		if r >= 7: up += 1
	var line := ""
	if built < n: line = "raising isles  %d / %d" % [built,n]
	elif grown < n: line = "growing flora  %d / %d" % [grown,n]
	else: line = "waking the ruins  %d / %d" % [up,n]
	return {"share":sum/float(n),"line":line,"done":up >= n}

## The viaduct stood and the next region laid: {share, line, done}.
func _extras() -> Dictionary:
	var stage: Node = study.get("stage")
	var hazards: Variant = stage.get("hazards") if stage != null else null
	var viaduct_waits: bool = hazards != null and not (hazards._waiting as Dictionary).is_empty()
	var loader: Node = stage.get_node_or_null("NextRegionLoader") if stage != null else null
	var next_waits: bool = loader != null and not bool(loader.get("done"))
	var share := 0.0
	if not viaduct_waits: share += 0.5
	if not next_waits: share += 0.5
	var line := "raising the viaduct" if viaduct_waits else "laying the far region"
	return {"share":share,"line":line,"done":not viaduct_waits and not next_waits}

# --- The warm-up ---------------------------------------------------------------------

## Every material the layer draws, drawn once under the screen: the camera
## is moved over the stood layer, a view at a time (WARM_FRAMES each), the
## real camera first (the start), then a hidden one over each isle (from
## above and standing on it), the four ways from the start, the plane, the
## roost's dragon and a headless body set before it for a moment. `current`
## goes back to the pilot's camera after.
func _warm() -> void:
	var began := Time.get_ticks_msec()
	if warm_wanted():
		await _sweep()
	else:
		screen.set_line("readying the light")
		await _hold(WARM_SELF)
		times.views = 1
	times.warm = Time.get_ticks_msec()-began
	_finish()

func _sweep() -> void:
	var real: Camera3D = study.get("camera")
	var cam := Camera3D.new()
	cam.name = "WarmCamera"
	cam.fov = real.fov
	cam.near = real.near
	cam.far = real.far
	cam.environment = real.environment
	cam.attributes = real.attributes
	cam.cull_mask = real.cull_mask
	cam.keep_aspect = real.keep_aspect
	study.add_child(cam)
	var views := _views()
	var body := _body_in()
	var extras := _extra_views(body)
	var total := views.size()+extras.size()+1
	var step := 0
	var limit := Time.get_ticks_msec()+int(WARM_MOST*1000.0)
	# The pilot's own view first (the start; the grass, the base, the plane).
	await _hold(WARM_FRAMES)
	step += 1
	_warm_progress(step,total)
	cam.make_current()
	for view: Array in views+extras:
		if Time.get_ticks_msec() > limit: break
		cam.global_transform = Transform3D(Basis.looking_at((view[1] as Vector3)-(view[0] as Vector3),Vector3.UP),view[0])
		await _hold(WARM_FRAMES)
		step += 1
		_warm_progress(step,total)
	real.make_current()
	cam.queue_free()
	_body_out(body)
	await _hold(2)
	times.views = step

func _warm_progress(step: int, total: int) -> void:
	screen.set_progress(BAR_EXTRAS+(1.0-BAR_EXTRAS)*float(step)/float(total))
	screen.set_line("readying the light  %d / %d" % [step,total])

func _hold(frames: int) -> void:
	for i in range(frames): await get_tree().process_frame

## [eye, look] over each isle: from above and back, and standing on it.
func _views() -> Array:
	var out: Array = []
	var motifs := _motifs()
	if motifs != null:
		var k := 0
		for isle: Node3D in motifs.isles:
			var c: Vector3 = isle.circle()
			var top: float = isle.isle_top()
			var centre := Vector3(c.x,top,c.y)
			var reach := maxf(c.z,12.0)
			var way := Vector3.FORWARD.rotated(Vector3.UP,float(k)*2.4)
			out.append([centre+way*reach*1.5+Vector3.UP*(reach*0.6+5.0),centre+Vector3.UP*reach*0.1])
			out.append([centre+way*reach*0.3+Vector3.UP*2.4,centre-way*reach*0.6+Vector3.UP*2.0])
			if reach > 36.0:
				out.append([centre-way*reach*0.5+Vector3.UP*2.4,centre+way*reach*0.5+Vector3.UP*3.0])
			k += 1
	# The four ways from the start, at the pilot's height.
	var spawn: Vector3 = (study.get("layer") as Dictionary).spawn.at
	for q in range(4):
		var way := Vector3.FORWARD.rotated(Vector3.UP,float(q)*PI*0.5+0.4)
		out.append([spawn+Vector3.UP*2.2,spawn+Vector3.UP*4.0+way*80.0])
	return out

## Views of what is not on an isle: the parked plane, the roost's dragon
## and his air, a body set before the camera.
func _extra_views(body: Node3D) -> Array:
	var out: Array = []
	var plane: Variant = study.get("plane_figure")
	if plane is Node3D and (plane as Node3D).is_inside_tree():
		var at := (plane as Node3D).global_position
		out.append([at+Vector3(7.0,3.0,7.0),at+Vector3.UP*1.0])
	var dragon: Variant = study.get("roost_dragon")
	if dragon is Node3D and (dragon as Node3D).is_inside_tree():
		var at := (dragon as Node3D).global_position
		out.append([at+Vector3(22.0,10.0,22.0),at])
		out.append([at+Vector3(-30.0,6.0,10.0),at])
	if body != null:
		var at := body.global_position
		out.append([at+Vector3(5.0,2.5,5.0),at+Vector3.UP*2.0])
	return out

## A headless body set down on the base ahead of the start for the sweep
## (its materials are first drawn when the first one climbs up, in play).
func _body_in() -> Node3D:
	var stage: Node = study.get("stage")
	if stage == null or stage.get("enemies") == null or warmed_extras: return null
	var field: Node = stage.enemies
	var spawn: Vector3 = (study.get("layer") as Dictionary).spawn.at
	var face: Vector3 = (study.get("layer") as Dictionary).spawn.face
	var body: Node3D = field.add(HeadlessBody,spawn+face*7.0,Vector2(-face.x,-face.z))
	return body

func _body_out(body: Node3D) -> void:
	warmed_extras = true
	if body == null or not is_instance_valid(body): return
	var stage: Node = study.get("stage")
	var field: Node = stage.enemies
	(field.enemies as Array).erase(body)
	if body.get_parent() != null: body.get_parent().remove_child(body)
	body.queue_free()

func _finish() -> void:
	SkyCommits.lifted = 0
	active = false
	phase = ""
	times.done = Time.get_ticks_msec()
	screen.set_progress(1.0)
	var run_loop: Variant = study.get("run_loop")
	if run_loop != null: run_loop.loading_done()
	print("loading screen: layer %d held play %d ms (laid %d, isles %d, extras %d, materials %d ms over %d views); since launch %d ms" % [
		int(study.get("layer_seed")),Time.get_ticks_msec()-_began,int(times.get("planned",_began))-_began,int(times.get("isles",_began))-_began,
		int(times.get("extras",_began))-_began,int(times.get("warm",0)),int(times.get("views",0)),Time.get_ticks_msec()])
	if SkyCommits.recording:
		var sums := {}
		var per_frame := {}
		for e: Array in SkyCommits.log:
			var key := str(e[1])
			sums[key] = int(sums.get(key,0))+int(e[2])
			per_frame[e[0]] = int(per_frame.get(e[0],0))+int(e[2])
		var keys := sums.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return sums[a] > sums[b])
		for k in keys.slice(0,14): print("loading trace: %s %d ms" % [k,int(sums[k])/1000])
		for isle: Node3D in _motifs().isles: print("loading trace: isle %s timings %s" % [isle.name,str(isle.timings)])
		print("loading trace: %d frames with commits, loading frames in all %d" % [per_frame.size(),Engine.get_process_frames()])
	study.call("_loading_done")
	screen.conceal(FADE_OUT)
