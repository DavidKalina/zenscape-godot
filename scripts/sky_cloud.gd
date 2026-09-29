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

var scene: Node3D
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

## True while the cloud is in the sky: a world is open.
func present() -> bool:
	var editor := _editor()
	return editor != null and scene.camera != null and scene.get("_has_world") != false

# --- The hand's verbs ------------------------------------------------------------

## The point on the cloud under a pointer (world), or null: the nearest puff
## the pointer's ray meets, a little generously. Only a cloud at rest is taken.
func hit(point: Vector2) -> Variant:
	if not visible or state != "idle": return null
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
	state = "held"
	_press = point
	_grab = at
	_grab_rest = frame.inverse()*(at-centre)
	_pointer = at
	_stretch = Vector3.ZERO
	tension = 0.0
	dry = false
	for i in range(BODY):
		var d := _at[i].distance_to(at)/GRAB_REACH
		_weight[i] = exp(-d*d)

## The pointer moved while the cloud (or a torn tuft) is in hand.
func pull(point: Vector2) -> void:
	_pointer = _on_plane(point)
	if state != "held": return
	var height := maxf(scene.get_viewport().get_visible_rect().size.y,1.0)
	tension = clampf(point.distance_to(_press)/(TEAR_REACH*height),0.0,1.0)
	if tension >= 1.0:
		if water >= TEAR_TAKES:
			_tear()
		else:
			dry = true

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
	_release_weights(RECOIL)
	for k in range(NECK):
		var i := BODY+k
		var v := back*randf_range(1.0,3.0)+Vector3(randf_range(-1,1),randf_range(-0.5,1),randf_range(-1,1))
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
	visible = present()
	if not visible: return
	delta = minf(delta,0.1)
	_time += delta
	var editor := _editor()
	# It gathers water back only while it is left alone, not while it gives.
	if (state == "idle" or state == "returning") and not _feeding: water = minf(CAPACITY,water+REFILL*delta)
	shown = lerpf(shown,water/CAPACITY,1.0-exp(-SHOW_RATE*delta))
	_place(editor)
	_step_puffs(delta)
	_step_tuft(delta)
	_step_feed(editor,delta)
	_draw()

## The cloud's middle and frame: behind the plate from the camera, easing
## round after it, swaying and bobbing. Held, it stays where it was taken.
func _place(editor: Node) -> void:
	if state == "held" or state == "carried": return
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
		_stretch = reach/length*STRETCH*(1.0-exp(-length/STRETCH)) if length > 0.001 else Vector3.ZERO
	var tremble := TREMBLE*pow(tension,3.0)
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
		if _tuft.distance_to(home) < 0.8 or _tuft_age > RETURN_SECONDS:
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
	for i in range(BODY):
		var breath := 1.0+0.035*sin(_time*0.7+i*1.7)
		_at[i] = centre+frame*(_rest[i]*scale)+_offset[i]
		_size[i] = _radius[i]*scale*breath
		# Low puffs are belly all over; high ones only underneath.
		var share: Vector2 = _settings.belly
		var low := clampf(0.9-_rest[i].y*0.45,share.x,share.y)
		_set_puff(puffs,i,_at[i],_size[i],Color(1,1,1).lerp(belly,low))
	# The neck, strung from the cloud to the pulled tuft, thinning as it goes.
	var stretched := _stretch.length()
	var root := centre+frame*_grab_rest
	for k in range(NECK):
		var f := (k+1.0)/(NECK+1.0)
		var r := NECK_RADIUS*scale*(1.0-0.55*tension)*(1.0-0.3*absf(f-0.5)*2.0)
		if state != "held" or stretched < 0.4: r = 0.0
		_set_puff(puffs,BODY+k,root.lerp(root+_stretch,f),r,belly)
	# The tuft: in hand, condensing into the ball, or drifting home.
	var tuft := 0.0
	if state in ["carried","returning"]: tuft = 1.0
	elif state == "into": tuft = 1.0-clampf(_tuft_age/INTO_SECONDS,0.0,1.0)
	var tuft_offsets := [Vector3(-0.45,0.0,0.1),Vector3(0.4,0.1,-0.1),Vector3(0.0,0.4,0.0),Vector3(0.05,-0.1,0.45)]
	for k in range(TUFT):
		var wobble := sin(_time*9.0+k*1.9)*0.06
		_set_puff(puffs,BODY+NECK+k,_tuft+frame*(tuft_offsets[k] as Vector3)*maxf(tuft,0.2),TUFT_RADIUS*tuft*(1.0+wobble),belly)
	for k in range(WISPS):
		var i := BODY+NECK+TUFT+k
		if k < _wisps.size():
			var wisp: Array = _wisps[k]
			var fade := 1.0-float(wisp[2])/WISP_SECONDS
			_set_puff(puffs,i,wisp[0],NECK_RADIUS*0.6*fade,belly)
		else:
			_set_puff(puffs,i,centre,0.0,belly)
	_draw_drops()

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
	var from := centre+Vector3.DOWN*1.1*lerpf(SHRUNK,1.0,shown)
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
