extends Node3D
## The sky's cloud (docs/scenic/sky-cloud.md): where the modeless hand's water
## comes from. A small faceted cloud floats over the far side of the diorama,
## always in the sky behind it, so you can see where water lives before you
## press anything. Press it and pull: it stretches after the hand like taffy,
## heavier the further you go, trembling near the end. Pull far enough and a
## tuft tears free in the hand, the cloud recoiling and jiggling back. Carried
## over the land the tuft condenses into the water ball (NativeChunkEditor
## `ball_from_sky`), which fills from the cloud while it is held: drops run from
## the cloud's belly into the ball and the cloud thins as it gives. Let go short
## of the tear and it springs back; let a tuft go over the sky and it drifts
## home. A cloud wrung dry will stretch but not tear, and fills again with time.
##
## The cloud is part of the sky, not the diorama: it floats in the room, so it
## does not turn with the world or ride the flip. World coordinates throughout.
## scripts/hand_reach.gd drives it (`hit`, `grab`, `pull`, `let_go`,
## `into_ball`) and hands `supply` to the editor for the ball's filling.
##
## **Summoned** (the default; docs/scenic/sky-cloud.md "Summoned"). The cloud
## is not in the sky at rest. A still hold in empty sky calls it
## (`summon`): droplets and wisps swirl in round the hand and the puffs swell
## from nothing with an overshoot, already in the hand's pinch, so the same
## press pulls and tears. It lingers while it is used, then drifts off on the
## wind and thins away (`presence`). On the session's first world it shows
## itself once, unasked (the demo). `--always-cloud` keeps the old cloud that
## is always behind the diorama.

## Where it floats: FAR metres from the plate's middle toward the far rim (away
## from the camera), at its kind's height and side (KINDS), swaying its sway
## either side over SWAY_SECONDS and bobbing BOB metres at BOB_RATE hertz. It follows
## the camera round at BEARING_RATE (1/s), so it stays behind the diorama.
const FAR := 9.0
const SWAY_SECONDS := 70.0
const BOB := 0.35
const BOB_RATE := 0.12
const BEARING_RATE := 0.6
## The cloud's puffs: metres in its own frame (x across the view, y up, z away
## from the camera) and radius, when full.
const CLOUD_PUFFS := [
	Vector4(-3.4,0.0,0.2,1.25),Vector4(-1.8,-0.15,-0.3,1.45),Vector4(0.0,-0.2,0.2,1.55),Vector4(1.9,-0.1,-0.2,1.4),Vector4(3.4,0.05,0.25,1.15),
	Vector4(-2.3,1.0,0.1,1.45),Vector4(-0.5,1.45,-0.1,1.9),Vector4(1.4,1.2,0.2,1.6),Vector4(2.9,0.9,-0.1,1.1),
	Vector4(-0.9,0.5,1.0,1.3),Vector4(0.9,0.55,-1.0,1.3),
]
## Each kind: where it floats (`side` metres across from the plate's middle
## line, `height` over the plate, `sway` metres either side, `phase` of its
## sway), what it holds (a full `capacity`, `refill` a second, and what a tear
## takes, `tear`, m³ of water, the ball's first), `shrunk` (its size held
## empty), the neck's and tuft's puff radii, and its colours: the top, the
## belly full and dry, and the share of each puff that is belly low and high.
const KINDS := {
	"cloud":{"side":-2.0,"height":15.0,"sway":4.0,"phase":0.0,"capacity":30.0,"refill":0.5,"tear":0.6,"shrunk":0.6,
		"neck":0.75,"tuft":0.7,"top":Color(0.98,0.98,0.96),"full":Color(0.6,0.66,0.75),"dry":Color(0.9,0.91,0.92),"belly":Vector2(0.35,1.0)},
}
## Small puffs strung between the body and the pulled tuft, the torn tuft's
## own puffs, and the wisps a tear throws off.
const NECK := 4
const TUFT := 4
const WISPS := 3
## How the look follows what it holds (1/s).
const SHOW_RATE := 3.0
## "cloud", and that kind's settings (KINDS), set in `setup`.
var kind := "cloud"
var BODY := 0
var PUFFS := 0
var CAPACITY := 30.0
var REFILL := 0.5
var TEAR_TAKES := 0.6
var SHRUNK := 0.6
var NECK_RADIUS := 0.75
var TUFT_RADIUS := 0.7
var BELLY_FULL := Color.WHITE
var BELLY_DRY := Color.WHITE
var _settings := {}
var _layout: Array = []
## The pull: the pointer's travel, as a share of the view's height, that tears
## a tuft. The pulled puffs follow the pointer's own travel (at the cloud's
## depth) at most STRETCH metres, easing toward it, so the hand, which holds
## the tuft, lags the pointer more the harder it pulls. The whole cloud leans
## SAG of the way after it; puffs within GRAB_REACH metres of the press go with
## the tuft. Near the tear it trembles up to TREMBLE metres.
const TEAR_REACH := 0.16
const STRETCH := 4.5
const SAG := 0.15
const GRAB_REACH := 2.6
const TREMBLE := 0.12
## A press counts within HIT_SLACK of a puff's radius.
const HIT_SLACK := 1.25
## Each puff springs back to rest (1/s², 1/s), a little under critical, so it
## jiggles; a tear kicks the pulled puffs back at RECOIL m/s.
const SPRING := 90.0
const DAMP := 7.0
const RECOIL := 9.0
## The torn tuft follows the pointer on a spring (1/s², 1/s); into a ball it
## condenses over INTO_SECONDS (the ball's own condense); let go over the sky
## it drifts home and rejoins within RETURN_SECONDS.
const TUFT_FOLLOW := 70.0
const TUFT_DAMP := 13.0
const INTO_SECONDS := 0.35
const RETURN_SECONDS := 1.4
const WISP_SECONDS := 0.6
## Drops running from the belly into a filling ball: at most DROPS at once,
## DROP_RATE a second at the ball's full rate, each taking DROP_SECONDS.
const DROPS := 40
const DROP_RATE := 34.0
const DROP_SECONDS := 0.7
## The rate (m³/s) the drops count as full: the water brush's default.
const FULL_FEED := 3.0

## Summoned (docs/scenic/sky-cloud.md "Summoned"). The summoned cloud stands
## FORM_REACH (in its own metres) behind the hand's pinch, so the hand holds
## its near face; it is sized by its depth over REFERENCE_DEPTH (about the
## always-there cloud's depth, so it reads the same size on screen), within
## SIZE_RANGE.
const GRIP := Vector3(0.0,0.1,-1.6)
const REFERENCE_DEPTH := 60.0
const SIZE_RANGE := Vector2(0.25,1.2)
## Forming: droplets (GATHER_BEADS of the drops) and the wisps swirl in
## from GATHER_SPREAD times the cloud's size over GATHER_SECONDS, turning
## SWIRL radians as they come; then from PUFF_START seconds the puffs swell
## out from the pinch outward, each PUFF_STAGGER later by its distance from
## it, each over PUFF_SECONDS on an underdamped spring (SWELL_DAMP, SWELL_FREQ:
## about 13% overshoot, then a small undershoot), gathering in from
## PUFF_SPREAD times their place. A pull tears once TEAR_FORM seconds have
## formed (the middle puffs are there).
const GATHER_BEADS := 28
const GATHER_SPREAD := 2.4
const GATHER_SECONDS := 0.34
const SWIRL := 2.4
const PUFF_START := 0.12
const PUFF_STAGGER := 0.22
const PUFF_SECONDS := 0.45
const PUFF_SPREAD := 1.7
const SWELL_DAMP := 11.0
const SWELL_FREQ := 17.0
## How quickly (1/s) a puff gathers in to its place: within about 1% by the
## end of its PUFF_SECONDS.
const GATHER_RATE := 14.0
const FORM_SECONDS := PUFF_START+PUFF_STAGGER+PUFF_SECONDS
const TEAR_FORM := 0.35
## Lingering and leaving: left alone LINGER seconds (DEMO_LINGER for the
## demo), or DRY_LINGER once wrung dry, it drifts off on the sky's wind at
## DRIFT (m/s at no wind to a strong one, times its size), rising RISE m/s,
## and thins away over LEAVE_SECONDS, outer puffs first. Under LEAVE_GRAB of
## the way gone a press calls it back.
const LINGER := 10.0
const DEMO_LINGER := 6.0
const DRY_LINGER := 3.0
const DRIFT := Vector2(1.2,4.0)
const RISE := 0.35
const LEAVE_SECONDS := 4.0
const LEAVE_GRAB := 0.6
## The demo: DEMO_DELAY seconds into the session's first calm world it forms
## by itself where the always-there cloud floats.
const DEMO_DELAY := 4.0
## True once this session's demo has shown (or `--no-cloud-demo`).
static var demo_shown := "--no-cloud-demo" in OS.get_cmdline_user_args()

var scene: Node3D
## Summoned (the default) or always there (`--always-cloud`).
var summoned := not "--always-cloud" in OS.get_cmdline_user_args()
## "gone", "forming", "here" or "leaving" (summoned only; always "here" else).
var presence := "gone"
## The cloud's size (1 the always-there cloud's), seconds formed, seconds left
## alone, how long it may be, share of the way gone, and whether it was wrung
## dry since it came.
var size := 1.0
var _form_time := 0.0
var _idle := 0.0
var _linger := LINGER
var _leave := 0.0
var wrung := false
## True while the hand could call the demo (hand_reach sets it: a world is
## open and nothing is held); the demo's wait; summons made, for probes.
var calm := false
var demo := false
var _demo_wait := 0.0
var summons := 0
## Where the summoned cloud floats before its bob, its drift while leaving,
## and the bob's own clock (it stops while held, so a let-go does not jump).
var _anchor := Vector3.ZERO
var _drift := Vector3.ZERO
var _bob_time := 0.0
## Forming: each puff's start (seconds), and where and how big it starts
## (world); the point the droplets gather to, and their starts and turns.
var _delay := PackedFloat32Array()
var _form_from := PackedVector3Array()
var _form_from_r := PackedFloat32Array()
var _focus := Vector3.ZERO
var _beads: Array[Vector4] = []
## The order the puffs thin in when it leaves (0 first).
var _thin := PackedFloat32Array()
## Water held now (m³), and what the look shows (eased).
var water := CAPACITY
var shown := 1.0
## "idle", "held" (pressed, stretching), "carried" (a torn tuft in hand),
## "into" (the tuft condensing into the ball) or "returning" (a tuft let go).
var state := "idle"
## 0..1 of the pull toward a tear, and true while a dry cloud is pulled to the
## end of its stretch.
var tension := 0.0
var dry := false
## Tears made, and water given to balls (m³), for probes.
var tears := 0
var given := 0.0
## The cloud's middle (world) and its frame: x across the view, z away.
var centre := Vector3.ZERO
var frame := Basis.IDENTITY
var _bearing: Variant = null
var _time := 0.0
var _rest := PackedVector3Array()
var _radius := PackedFloat32Array()
var _spin: Array[Basis] = []
var _offset := PackedVector3Array()
var _speed := PackedVector3Array()
var _weight := PackedFloat32Array()
## Puffs as drawn this frame (world), for the hit.
var _at := PackedVector3Array()
var _size := PackedFloat32Array()
## The press: the grabbed point (world, on the cloud as it stood), the
## screen press, and where the pointer's ray meets the plane through the grab
## facing the camera.
var _grab := Vector3.ZERO
var _grab_rest := Vector3.ZERO
var _press := Vector2.ZERO
var _pointer := Vector3.ZERO
var _stretch := Vector3.ZERO
## The tuft: its middle, speed, water, age in its state, and where it goes.
var _tuft := Vector3.ZERO
var _tuft_speed := Vector3.ZERO
var _tuft_water := 0.0
var _tuft_age := 0.0
var _tuft_from := Vector3.ZERO
var _ball: Node3D
## Wisps thrown off by a tear: [position, velocity, age].
var _wisps: Array[Array] = []
## Feeding a held ball: what it took this frame, and drops in flight
## [t, lateral jitter].
var _feeding := false
var _fed := 0.0
var _feed_rate := 0.0
var _drop_due := 0.0
var _drops: Array[Vector3] = []
var _puffs: MultiMeshInstance3D
var _drop_node: MultiMeshInstance3D

func setup(owner_scene: Node3D, which := "cloud") -> void:
	scene = owner_scene
	kind = which
	name = "SkyCloud"
	_settings = KINDS[kind]
	_layout = CLOUD_PUFFS
	BODY = _layout.size()
	PUFFS = BODY+NECK+TUFT+WISPS
	CAPACITY = _settings.capacity
	REFILL = _settings.refill
	TEAR_TAKES = _settings.tear
	SHRUNK = _settings.shrunk
	NECK_RADIUS = _settings.neck
	TUFT_RADIUS = _settings.tuft
	BELLY_FULL = _settings.full
	BELLY_DRY = _settings.dry
	water = CAPACITY
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(PUFFS):
		var p: Vector4 = _layout[i] if i < BODY else Vector4(0,0,0,NECK_RADIUS if i < BODY+NECK else TUFT_RADIUS)
		_rest.append(Vector3(p.x,p.y,p.z))
		_radius.append(p.w)
		# Each puff turned its own way, so the facets do not line up.
		_spin.append(Basis(Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized(),rng.randf()*TAU))
		_offset.append(Vector3.ZERO)
		_speed.append(Vector3.ZERO)
		_weight.append(0.0)
		_at.append(Vector3.ZERO)
		_size.append(0.0)
		_delay.append(0.0)
		_form_from.append(Vector3.ZERO)
		_form_from_r.append(0.0)
	var widest := 0.0
	for i in range(BODY): widest = maxf(widest,Vector2(_rest[i].x,_rest[i].y*1.6).length())
	for i in range(BODY): _thin.append(1.0-Vector2(_rest[i].x,_rest[i].y*1.6).length()/maxf(widest,0.001))
	if not summoned: presence = "here"
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sky_cloud.gdshader")
	material.set_shader_parameter("cloud_top",_settings.top)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var puffs := MultiMesh.new()
	puffs.transform_format = MultiMesh.TRANSFORM_3D
	puffs.use_colors = true
	puffs.instance_count = PUFFS
	puffs.mesh = sphere
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "Puffs"
	_puffs.multimesh = puffs
	_puffs.material_override = material
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_puffs)
	# The drops are the water ball's own beads.
	var bead_material := ShaderMaterial.new()
	bead_material.shader = preload("res://shaders/water_bead.gdshader")
	bead_material.render_priority = 2
	var bead := SphereMesh.new()
	bead.radius = 1.0
	bead.height = 2.0
	bead.radial_segments = 8
	bead.rings = 4
	var drops := MultiMesh.new()
	drops.transform_format = MultiMesh.TRANSFORM_3D
	drops.use_colors = true
	drops.instance_count = DROPS
	drops.visible_instance_count = 0
	drops.mesh = bead
	_drop_node = MultiMeshInstance3D.new()
	_drop_node.name = "Drops"
	_drop_node.multimesh = drops
	_drop_node.material_override = bead_material
	_drop_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drop_node)
	visible = false

func _editor() -> Node:
	return scene.get("_chunk_editor") if scene != null else null

## True while a world is open.
func _world_open() -> bool:
	var editor := _editor()
	return editor != null and scene.camera != null and scene.get("_has_world") != false

## True while the cloud is in the sky: a world is open, and summoned, it has
## been called and has not gone.
func present() -> bool:
	return _world_open() and presence != "gone"

## True while a summoned cloud is still forming.
func forming() -> bool:
	return presence == "forming"

## True while it can be torn: formed enough to hold a tuft.
func formed_enough() -> bool:
	return presence != "forming" or _form_time >= TEAR_FORM

# --- Summoned: coming and going ----------------------------------------------------

## A still hold in empty sky calls the cloud: it forms round `at` (world, the
## hand's pinch on the pointer's ray) with the pointer at `point`, already in
## hand. A cloud still in the sky flies in and re-forms there, keeping its
## water.
func summon(point: Vector2, at: Vector3) -> void:
	var camera: Camera3D = scene.camera
	var fresh := presence == "gone"
	var away := -camera.global_basis.z
	away.y = 0.0
	if away.length_squared() < 0.0001: away = camera.global_basis.y*Vector3(1,0,1)
	var z := away.normalized()
	frame = Basis(Vector3.UP.cross(z),Vector3.UP,z)
	size = clampf(camera.global_position.distance_to(at)/REFERENCE_DEPTH,SIZE_RANGE.x,SIZE_RANGE.y)
	centre = at-frame*(GRIP*size)
	_anchor = centre
	summons += 1
	# A tuft on its way home is taken back first.
	if state == "returning":
		water = minf(CAPACITY,water+_tuft_water)
		_tuft_water = 0.0
	_start_form(fresh,at)
	grab(point,at)

## The demo: the session's first calm world shows the cloud once, unasked,
## where the always-there cloud floated; it hangs a while and drifts off.
func show_demo() -> void:
	demo_shown = true
	var editor := _editor()
	var middle: Vector3 = (editor.terrain as Node3D).global_position
	var away: Vector3 = middle-scene.camera.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001: away = Vector3.FORWARD
	var z := away.normalized()
	frame = Basis(Vector3.UP.cross(z),Vector3.UP,z)
	size = 1.0
	centre = middle+z*FAR+frame.x*float(_settings.side)+Vector3.UP*float(_settings.height)
	_anchor = centre
	_start_form(true,centre)
	demo = true
	_linger = DEMO_LINGER

## Forming starts: from nothing (`fresh`), or from the cloud as it is drawn.
func _start_form(fresh: bool, focus: Vector3) -> void:
	presence = "forming"
	_form_time = 0.0
	_idle = 0.0
	_leave = 0.0
	_linger = LINGER
	demo = false
	_focus = focus
	if fresh:
		water = CAPACITY
		shown = 1.0
		wrung = false
		state = "idle"
		_wisps.clear()
		_drops.clear()
	var grip := frame.inverse()*(focus-centre)/maxf(size,0.001)
	var farthest := 0.0
	for i in range(BODY): farthest = maxf(farthest,_rest[i].distance_to(grip))
	for i in range(BODY):
		_delay[i] = PUFF_START+PUFF_STAGGER*_rest[i].distance_to(grip)/maxf(farthest,0.001)
		_offset[i] = Vector3.ZERO
		_speed[i] = Vector3.ZERO
		if fresh or _size[i] <= 0.0:
			var out := Vector3(_rest[i].x,_rest[i].y,_rest[i].z)*PUFF_SPREAD+Vector3(randf_range(-0.6,0.6),randf_range(-0.3,0.3),randf_range(-0.6,0.6))
			_form_from[i] = centre+frame*(out*size)
			_form_from_r[i] = 0.0
		else:
			_form_from[i] = _at[i]
			_form_from_r[i] = _size[i]
	_beads.clear()
	for k in range(GATHER_BEADS):
		# [angle, reach (of the cloud's size), start (s), height].
		_beads.append(Vector4(TAU*k/GATHER_BEADS+randf_range(-0.2,0.2),GATHER_SPREAD*randf_range(0.75,1.2),randf_range(0.0,0.1),randf_range(-0.6,0.6)))

## Coming, lingering and leaving, and the demo's wait.
func _step_presence(delta: float) -> void:
	if presence == "gone":
		if not demo_shown and calm and _world_open():
			_demo_wait += delta
			if _demo_wait >= DEMO_DELAY: show_demo()
		return
	if presence == "forming":
		_form_time += delta
		if _form_time >= FORM_SECONDS: presence = "here"
	var touched := state != "idle" or _feeding
	_idle = 0.0 if touched else _idle+delta
	if touched: _linger = LINGER
	if presence == "here" and not touched and (_idle >= _linger or (wrung and _idle >= DRY_LINGER)): _begin_leave()
	if presence == "leaving":
		_leave += delta/LEAVE_SECONDS
		if _leave >= 1.0: _gone()

## It drifts off on the sky's wind, rising a little.
func _begin_leave() -> void:
	presence = "leaving"
	_leave = 0.0
	var way := frame.x
	var strength := 0.0
	var air: Node = scene.get("_atmosphere")
	if air != null:
		var angle: float = float(air.get("_air_angle")) if air.get("_air_angle") != null else deg_to_rad(float(air.direction_angle))
		strength = float(air.get("_air_strength")) if air.get("_air_strength") != null else float(air.strength)
		if strength > 0.02: way = Vector3(cos(angle),0.0,sin(angle))
	_drift = way*lerpf(DRIFT.x,DRIFT.y,clampf(strength/1.4,0.0,1.0))*size
	# The trailing side lags as it sets off (overlap): the puffs are kicked back.
	for i in range(BODY):
		_speed[i] -= _drift.normalized()*0.8*size*(0.5+0.5*_thin[i])

## Gone: the next call forms afresh.
func _gone() -> void:
	presence = "gone"
	state = "idle"
	demo = false
	_leave = 0.0
	tension = 0.0
	dry = false
	_wisps.clear()
	_drops.clear()
	for i in range(PUFFS):
		_offset[i] = Vector3.ZERO
		_speed[i] = Vector3.ZERO
		_size[i] = 0.0
	water = CAPACITY
	visible = false

# --- The hand's verbs ------------------------------------------------------------

## The point on the cloud under a pointer (world), or null: the nearest puff
## the pointer's ray meets, a little generously. Only a cloud at rest is taken.
func hit(point: Vector2) -> Variant:
	if not visible or state != "idle": return null
	if summoned and (presence == "gone" or _leave > LEAVE_GRAB): return null
	var camera: Camera3D = scene.camera
	var origin := camera.project_ray_origin(point)
	var ray := camera.project_ray_normal(point)
	var nearest := INF
	var found: Variant = null
	for i in range(BODY):
		var r := _size[i]*HIT_SLACK
		var to := _at[i]-origin
		var along := to.dot(ray)
		var miss := to.length_squared()-along*along
		if along <= 0.0 or miss > r*r: continue
		var t := along-sqrt(r*r-miss)
		if t < nearest:
			nearest = t
			found = origin+ray*t
	return found

## The hand takes the cloud at `at` (world, from `hit`) with the pointer at
## `point`: the puffs near it will follow the pull.
func grab(point: Vector2, at: Vector3) -> void:
	# A leaving cloud taken again swells back where it is.
	if presence == "leaving": _start_form(false,at)
	demo = false
	state = "held"
	_press = point
	_grab = at
	_grab_rest = frame.inverse()*(at-centre)
	_pointer = at
	_stretch = Vector3.ZERO
	tension = 0.0
	dry = false
	for i in range(BODY):
		# Forming, a puff is weighed where it will stand.
		var from := _at[i] if presence != "forming" else centre+frame*(_rest[i]*lerpf(SHRUNK,1.0,shown)*size)
		var d := from.distance_to(at)/(GRAB_REACH*size)
		_weight[i] = exp(-d*d)

## The pointer moved while the cloud (or a torn tuft) is in hand.
func pull(point: Vector2) -> void:
	_pointer = _on_plane(point)
	if state != "held": return
	var height := maxf(scene.get_viewport().get_visible_rect().size.y,1.0)
	tension = clampf(point.distance_to(_press)/(TEAR_REACH*height),0.0,1.0)
	if tension >= 1.0:
		if water < TEAR_TAKES:
			dry = true
		elif formed_enough():
			_tear()

## True once a tuft is torn off and in hand.
func torn() -> bool:
	return state == "carried"

## Where the hand holds (world): the tuft being stretched out, or the torn one.
func hand_point() -> Vector3:
	if state == "held": return centre+frame*_grab_rest+_stretch
	return _tuft

## The hand lets go. A stretch springs back; a torn tuft over the sky drifts
## home and gives its water back.
func let_go() -> void:
	if state == "held":
		state = "idle"
		_release_weights(0.0)
	elif state == "carried":
		state = "returning"
		_tuft_age = 0.0
	tension = 0.0
	dry = false

## The torn tuft became the editor's water ball: it condenses into it, and the
## ball fills from the cloud while it is held (`supply`).
func into_ball(ball: Node3D) -> void:
	if state != "carried": return
	state = "into"
	_tuft_age = 0.0
	_tuft_from = _tuft
	_ball = ball
	given += _tuft_water
	_tuft_water = 0.0
	_feeding = true

## The held ball asks for `amount` m³ more; the cloud gives what it has.
func supply(amount: float) -> float:
	var granted := clampf(amount,0.0,water)
	water -= granted
	if water < TEAR_TAKES: wrung = true
	given += granted
	_fed += granted
	return granted

## A tear: a tuft comes away in the hand with the first of the water, the
## pulled puffs snap back and jiggle, and the neck breaks into wisps.
func _tear() -> void:
	_tuft = hand_point()
	state = "carried"
	tears += 1
	water -= TEAR_TAKES
	_tuft_water = TEAR_TAKES
	_tuft_speed = Vector3.ZERO
	var back := -_stretch.normalized() if _stretch.length() > 0.01 else Vector3.UP
	_release_weights(RECOIL*size)
	for k in range(NECK):
		var i := BODY+k
		var v := (back*randf_range(1.0,3.0)+Vector3(randf_range(-1,1),randf_range(-0.5,1),randf_range(-1,1)))*size
		_wisps.append([_at[i],v,0.0])
	while _wisps.size() > WISPS: _wisps.pop_front()
	tension = 0.0

## The pulled puffs let go, kicked back toward the cloud at `kick` m/s by how
## hard they were held.
func _release_weights(kick: float) -> void:
	var back := -_stretch.normalized() if _stretch.length() > 0.01 else Vector3.ZERO
	for i in range(BODY):
		_speed[i] += back*kick*_weight[i]
		_weight[i] = 0.0
	_stretch = Vector3.ZERO

## Where the pointer's ray meets the plane through the grab, facing the camera.
func _on_plane(point: Vector2) -> Vector3:
	var camera: Camera3D = scene.camera
	var origin := camera.project_ray_origin(point)
	var ray := camera.project_ray_normal(point)
	var normal := -camera.global_basis.z
	var across := ray.dot(normal)
	if absf(across) < 0.0001: return _pointer
	return origin+ray*((_grab-origin).dot(normal)/across)

# --- Frames ------------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.1)
	if summoned: _step_presence(delta)
	visible = present()
	if not visible: return
	_time += delta
	# A held tuft waiting on the forming cloud tears as soon as it can.
	if state == "held" and tension >= 1.0 and water >= TEAR_TAKES and formed_enough(): _tear()
	var editor := _editor()
	# It gathers water back only while it is left alone, not while it gives.
	if (state == "idle" or state == "returning") and not _feeding: water = minf(CAPACITY,water+REFILL*delta)
	shown = lerpf(shown,water/CAPACITY,1.0-exp(-SHOW_RATE*delta))
	_place(editor,delta)
	_step_puffs(delta)
	_step_tuft(delta)
	_step_feed(editor,delta)
	_draw()

## The cloud's middle and frame: behind the plate from the camera, easing
## round after it, swaying and bobbing. Held, it stays where it was taken.
func _place(editor: Node, delta: float) -> void:
	if state == "held" or state == "carried": return
	if summoned:
		# Summoned it stays where it was called, bobbing, till it leaves.
		if presence == "leaving": _anchor += (_drift*smoothstep(0.0,0.35,_leave)+Vector3.UP*RISE*size)*delta
		_bob_time += delta
		centre = _anchor+Vector3.UP*sin(_bob_time*TAU*BOB_RATE)*BOB*size
		return
	var middle: Vector3 = (editor.terrain as Node3D).global_position
	var camera: Camera3D = scene.camera
	var away := middle-camera.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001: away = Vector3.FORWARD
	var bearing := atan2(away.x,away.z)
	if _bearing == null: _bearing = bearing
	_bearing = lerp_angle(float(_bearing),bearing,1.0-exp(-BEARING_RATE*get_process_delta_time()))
	var z := Vector3(sin(float(_bearing)),0.0,cos(float(_bearing)))
	var x := Vector3.UP.cross(z)
	frame = Basis(x,Vector3.UP,z)
	var sway := sin(_time*TAU/SWAY_SECONDS+float(_settings.phase))*float(_settings.sway)
	var bob := sin(_time*TAU*BOB_RATE+float(_settings.phase))*BOB
	centre = middle+z*FAR+x*(float(_settings.side)+sway)+Vector3.UP*(float(_settings.height)+bob)

## Each body puff springs toward its pull (or rest) and jiggles.
func _step_puffs(delta: float) -> void:
	if state == "held":
		var reach := _pointer-_grab
		var length := reach.length()
		var most := STRETCH*size
		_stretch = reach/length*most*(1.0-exp(-length/most)) if length > 0.001 else Vector3.ZERO
	var tremble := TREMBLE*size*pow(tension,3.0)
	for i in range(BODY):
		var goal := Vector3.ZERO
		if state == "held":
			goal = _stretch*(SAG+(1.0-SAG)*_weight[i])
			if tremble > 0.0: goal += Vector3(sin(_time*53.0+i*2.1),sin(_time*47.0+i*1.3),sin(_time*59.0+i*0.7))*tremble
		_speed[i] += ((goal-_offset[i])*SPRING-_speed[i]*DAMP)*delta
		_offset[i] += _speed[i]*delta
	var aged: Array[Array] = []
	for wisp in _wisps:
		wisp[2] = float(wisp[2])+delta
		wisp[1] = Vector3(wisp[1])*exp(-2.0*delta)
		wisp[0] = Vector3(wisp[0])+Vector3(wisp[1])*delta
		if float(wisp[2]) < WISP_SECONDS: aged.append(wisp)
	_wisps = aged

## The torn tuft: after the pointer, into the ball, or home.
func _step_tuft(delta: float) -> void:
	if state == "carried":
		_tuft_speed += ((_pointer-_tuft)*TUFT_FOLLOW-_tuft_speed*TUFT_DAMP)*delta
		_tuft += _tuft_speed*delta
	elif state == "into":
		_tuft_age += delta
		var goal := _tuft
		if is_instance_valid(_ball): goal = _ball.global_position
		var f := clampf(_tuft_age/INTO_SECONDS,0.0,1.0)
		_tuft = _tuft_from.lerp(goal,f*f)
		if f >= 1.0: state = "idle"
	elif state == "returning":
		_tuft_age += delta
		var home := centre+frame*_grab_rest
		_tuft_speed += ((home-_tuft)*TUFT_FOLLOW*0.25-_tuft_speed*TUFT_DAMP*0.5)*delta
		_tuft += _tuft_speed*delta
		if _tuft.distance_to(home) < 0.8*size or _tuft_age > RETURN_SECONDS:
			water = minf(CAPACITY,water+_tuft_water)
			_tuft_water = 0.0
			state = "idle"
			# The cloud takes it back with a little jiggle.
			for i in range(BODY): _speed[i] += Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*1.2

## While the ball it gave is held and filling, drops run from the belly into it.
func _step_feed(editor: Node, delta: float) -> void:
	if _feeding and not (editor.get("_ball_holding") == true and is_instance_valid(_ball)):
		_feeding = false
		_ball = null
	_feed_rate = lerpf(_feed_rate,_fed/maxf(delta,0.001),1.0-exp(-8.0*delta))
	_fed = 0.0
	if _feeding and _feed_rate > 0.01:
		_drop_due += delta*DROP_RATE*clampf(_feed_rate/FULL_FEED,0.25,1.0)
		while _drop_due >= 1.0 and _drops.size() < DROPS:
			_drop_due -= 1.0
			_drops.append(Vector3(0.0,randf_range(-1,1),randf_range(-1,1)))
	var kept: Array[Vector3] = []
	for drop in _drops:
		drop.x += delta/DROP_SECONDS
		if drop.x < 1.0 and is_instance_valid(_ball): kept.append(drop)
	_drops = kept

# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	var puffs := _puffs.multimesh
	var scale := lerpf(SHRUNK,1.0,shown)
	var belly := BELLY_DRY.lerp(BELLY_FULL,shown)
	# Leaving, it pales as it thins.
	if presence == "leaving": belly = belly.lerp(Color(1,1,1),_leave*0.6)
	for i in range(BODY):
		var breath := 1.0+0.035*sin(_time*0.7+i*1.7)
		_at[i] = centre+frame*(_rest[i]*scale*size)+_offset[i]
		_size[i] = _radius[i]*scale*breath*size
		if presence == "forming":
			# Gathering in from wide and swelling from nothing, with an
			# overshoot and a settle.
			var tau := _form_time-_delay[i]
			if tau <= 0.0:
				_at[i] = _form_from[i]
				_size[i] = _form_from_r[i]
			else:
				_at[i] = _form_from[i].lerp(_at[i],_gather(tau))
				_size[i] = lerpf(_form_from_r[i],_size[i],_swell(tau))
		elif presence == "leaving":
			# Outer puffs first, drifting apart as they go.
			var o := _thin[i]
			_at[i] += frame*(_rest[i]*size*0.35*_leave)
			_size[i] *= 1.0-smoothstep(o*0.5,o*0.5+0.5,_leave)
		# Low puffs are belly all over; high ones only underneath.
		var share: Vector2 = _settings.belly
		var low := clampf(0.9-_rest[i].y*0.45,share.x,share.y)
		_set_puff(puffs,i,_at[i],_size[i],Color(1,1,1).lerp(belly,low))
	# The neck, strung from the cloud to the pulled tuft, thinning as it goes.
	var stretched := _stretch.length()
	var root := centre+frame*_grab_rest
	for k in range(NECK):
		var f := (k+1.0)/(NECK+1.0)
		var r := NECK_RADIUS*size*scale*(1.0-0.55*tension)*(1.0-0.3*absf(f-0.5)*2.0)
		if state != "held" or stretched < 0.4: r = 0.0
		_set_puff(puffs,BODY+k,root.lerp(root+_stretch,f),r,belly)
	# The tuft: in hand, condensing into the ball, or drifting home.
	var tuft := 0.0
	if state in ["carried","returning"]: tuft = 1.0
	elif state == "into": tuft = 1.0-clampf(_tuft_age/INTO_SECONDS,0.0,1.0)
	var tuft_offsets := [Vector3(-0.45,0.0,0.1),Vector3(0.4,0.1,-0.1),Vector3(0.0,0.4,0.0),Vector3(0.05,-0.1,0.45)]
	for k in range(TUFT):
		var wobble := sin(_time*9.0+k*1.9)*0.06
		_set_puff(puffs,BODY+NECK+k,_tuft+frame*(tuft_offsets[k] as Vector3)*maxf(tuft,0.2)*size,TUFT_RADIUS*size*tuft*(1.0+wobble),belly)
	for k in range(WISPS):
		var i := BODY+NECK+TUFT+k
		if k < _wisps.size():
			var wisp: Array = _wisps[k]
			var fade := 1.0-float(wisp[2])/WISP_SECONDS
			_set_puff(puffs,i,wisp[0],NECK_RADIUS*size*0.6*fade,belly)
		elif presence == "forming" and _form_time < GATHER_SECONDS+0.1:
			# Forming, the wisps curl in to the pinch and are drawn into it.
			var u := clampf(_form_time/(GATHER_SECONDS+0.1),0.0,1.0)
			var angle := TAU*(k+0.3)/WISPS+SWIRL*u
			var out := Vector3(cos(angle),sin(angle)*0.55,sin(angle)*0.4)*GATHER_SPREAD*1.1*(1.0-_gather(u*PUFF_SECONDS))
			_set_puff(puffs,i,_focus+frame*(out*size),NECK_RADIUS*size*0.55*sin(PI*u),Color(1,1,1).lerp(belly,0.3))
		else:
			_set_puff(puffs,i,centre,0.0,belly)
	if _drops.is_empty() and presence == "forming": _draw_gather()
	else: _draw_drops()

## A puff's gathering in, 0 to 1 over its PUFF_SECONDS, `tau` seconds in: a
## critically damped ease, still at both ends.
func _gather(tau: float) -> float:
	if tau >= PUFF_SECONDS: return 1.0
	return 1.0-exp(-GATHER_RATE*tau)*(1.0+GATHER_RATE*tau)

## A puff's swelling, `tau` seconds in: an underdamped spring from 0 to 1 that
## overshoots once and settles.
func _swell(tau: float) -> float:
	if tau >= PUFF_SECONDS: return 1.0
	return 1.0-exp(-SWELL_DAMP*tau)*cos(SWELL_FREQ*tau)

## Forming: droplets spiral in from round the cloud to the pinch, speeding up
## as they come, stretched along their way, and vanish into it.
func _draw_gather() -> void:
	var drops := _drop_node.multimesh
	var count := 0
	for bead in _beads:
		if count >= DROPS: break
		var u := (_form_time-bead.z)/GATHER_SECONDS
		if u <= 0.0 or u >= 1.0: continue
		var at := _bead_at(bead,u)
		var ahead := _bead_at(bead,minf(u+0.03,1.0))-at
		var r := 0.08*size*(1.0-0.5*u)
		var basis := Basis.from_scale(Vector3.ONE*r)
		if ahead.length() > 0.0001:
			var along := ahead.normalized()
			var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
			basis = Basis(side,along,side.cross(along))*Basis.from_scale(Vector3(r,r*(1.5+2.5*u),r))
		drops.set_instance_transform(count,Transform3D(basis,at))
		drops.set_instance_color(count,Color(1,1,1,smoothstep(0.0,0.2,u)))
		count += 1
	drops.visible_instance_count = count

## A gathering droplet `u` of the way in: round the pinch in the cloud's own
## frame, turning SWIRL as it closes, the reach easing in (slow, then quick).
func _bead_at(bead: Vector4, u: float) -> Vector3:
	var angle := bead.x+SWIRL*u
	var reach := bead.y*(1.0-u*u)
	return _focus+frame*(Vector3(cos(angle),sin(angle)*0.6+bead.w*(1.0-u),sin(angle)*0.5)*reach*size)

## A puff at `at` of radius `r` (hidden at nothing: a MultiMesh instance must
## keep a transform that is not all zero).
func _set_puff(puffs: MultiMesh, i: int, at: Vector3, r: float, color: Color) -> void:
	puffs.set_instance_transform(i,Transform3D(_spin[i].scaled(Vector3.ONE*maxf(r,0.0001)),at))
	puffs.set_instance_color(i,color)

## Drops along a sagging arc from the belly into the ball.
func _draw_drops() -> void:
	var drops := _drop_node.multimesh
	var count := mini(_drops.size(),DROPS)
	drops.visible_instance_count = count
	if count == 0 or not is_instance_valid(_ball): return
	var from := centre+Vector3.DOWN*1.1*size*lerpf(SHRUNK,1.0,shown)
	var to := _ball.global_position+Vector3.UP*float(_ball.get("radius"))
	var middle := from.lerp(to,0.5)+Vector3.UP*2.0
	var across := frame.x
	for i in range(count):
		var drop := _drops[i]
		var t := drop.x
		# Loose at the belly, gathering into one thread toward the ball.
		var spread := (1.0-t)*0.8
		var at := from.lerp(middle,t).lerp(middle.lerp(to,t),t)+across*drop.y*spread+Vector3.UP*drop.z*spread*0.4
		var ahead := from.lerp(middle,t+0.02).lerp(middle.lerp(to,t+0.02),t+0.02)-at
		var size := 0.09
		var basis := Basis.from_scale(Vector3.ONE*size)
		if ahead.length() > 0.0001:
			var along := ahead.normalized()
			var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
			basis = Basis(side,along,side.cross(along))*Basis.from_scale(Vector3(size,size*2.4,size))
		drops.set_instance_transform(i,Transform3D(basis,at))
		drops.set_instance_color(i,Color(1,1,1,smoothstep(0.0,0.15,t)))
