extends Node3D
## The wind tool's gust (docs/scenic/wind-gust.md). With wind in hand, the
## hand blows: press and drag, and the stroke's direction and speed set the
## gust's heading and strength. While the hand blows, the ground shows the
## promise (docs/scenic/handful.md): a pale lane from the press along the
## swipe, as wide as the air will be and as far as it will run
## (shaders/wind_gust_ground.gdshader). Let go and the gust goes: the air
## draws back a moment, then rolls along the lane, quick at first and easing
## as it spends itself, and fades at the lane's end. A press let go without
## moving is a burst instead: a ring that grows while held, then runs out
## round the press.
##
## The gust moves the world's shared air, so everything that already answers
## a passing gust answers it:
## - one of the atmosphere's six travelling parcels (studies/wind_puffs.gd,
##   globals zs_puff_N), steered along the lane with its own heading
##   (zs_puff_heading_N): the fog parts, water ripples, the grass and trees'
##   gust field swells where it passes;
## - one steered gust in the resident's LocalWindField (zs_local_gust_*),
##   riding with the head: foliage, trees, conifers and water bend and push
##   along the gust's true direction, and leaf litter blows with it;
## - a burst is the clap ring (zs_clap) with four steered gusts pushing out.
## And it shows itself: ribbons of moving air ride just behind the head
## (shaders/wind_gust_trail.gdshader), loose leaves and motes gathered by the
## press are carried along and settle after, and a band of dappled shade and
## sheen runs along the ground under it. It passes: nothing about the
## weather changes, unless --gust-nudges (see `nudge`).
##
## Lives under the terrain node: its points are the plate's.

## A gust went: its record (see `gusts`).
signal sent(gust: Dictionary)

# --- The gesture --------------------------------------------------------------
## Metres the pointer may wander from the press and still make a burst.
const STILL_DRAG := 0.6
## Seconds of pointer history the swipe's speed is read over.
const SWIPE_WINDOW := 0.12
## Ground speed (m/s) of a swipe that blows the weakest and a full gust.
const SWIPE_SPEED := Vector2(1.5,24.0)
## The weakest gust's power (0..1).
const MIN_POWER := 0.15
## Per second: how fast the aimed power follows a quickening swipe, and eases
## back when it slows or stops, so a flick that ends still keeps most of it.
const POWER_RISE := 18.0
const POWER_FALL := 2.5
## How fast (1/s) the aimed heading turns to follow the swipe.
const HEADING_FOLLOW := 20.0

# --- The run ------------------------------------------------------------------
## Metres the weakest and a full gust run, and their head's cruising speed
## (m/s). A swipe longer than its gust's run stretches the run to match.
const REACH := Vector2(8.0,30.0)
const CRUISE := Vector2(7.0,15.0)
## Metres the air keeps back from the land's edge.
const EDGE_MARGIN := 0.5
## Anticipation: seconds the air draws back before it goes, and how far (m)
## at full power.
const WIND_UP := 0.14
const PULL_BACK := 0.6
## The run: the head leaves at LAUNCH times cruise and eases to a stop at the
## lane's end; the air builds over BUILD of the run and fades over FADE.
const LAUNCH := 1.3
const BUILD := 0.18
const FADE := Vector2(0.55,1.0)
## Seconds after the run for ribbons to thin and leaves to land.
const SETTLE := 1.1
## Gusts in flight at once; one more hastens the oldest to its fade.
const MAX_GUSTS := 4

# --- What it gives the shared air ----------------------------------------------
## Parcel weight at weakest and full (wind_puffs.gd: 0.45 is a painting
## stroke's full puff, 0.8 the cap).
const PUFF := Vector2(0.35,0.8)
## Air travel (m) the steered parcel is held at: past its birth ramp (1.5)
## and short of its retirement (30), so its weight is all ours.
const PARCEL_AGE := 8.0
## LocalWindField push (m/s) at weakest and full, how high above the ground
## it rides, and its reach in lane half widths.
const LOCAL := Vector2(8.0,22.0)
const LOCAL_LIFT := 1.2
const LOCAL_REACH := 1.6

# --- The burst ----------------------------------------------------------------
## Metres a burst reaches, gathered over BURST_GATHER s of still press, and
## its ring's cruising speed (m/s). Its clap ring (zs_clap) weight at weakest
## and full, and the steered gusts pushing out round it.
const BURST_REACH := Vector2(4.0,12.0)
const BURST_GATHER := 1.2
const BURST_CRUISE := Vector2(8.0,12.0)
const BURST_CLAP := Vector2(0.5,0.9)
const BURST_SPOKES := 4
## The ring starts this far out, and draws in by PULL_BACK before it goes.
const RING_START := 0.9

# --- How it looks ---------------------------------------------------------------
## Ribbons: strands along a lane, spokes of a burst, how much of each shows
## behind the head (m), and their width (m) at weakest and full.
const STRANDS := 5
const SPOKES := 10
const TRAIL_LENGTH := 9.0
const RIBBON_WIDTH := Vector2(0.08,0.16)
## The mark's box leaves room for the lane's arrow tip, which flares wider
## than the lane (the shader's TIP_FLARE).
const TIP_WIDTH := 1.3
## Metres between a ribbon's points, and between ground samples under a gust.
const RIBBON_STEP := 0.5
const GRID_STEP := 1.0
## Loose leaves and motes: the most at once, and how many a press gathers.
const MOTES := 64
const PRESS_MOTES := 14
## Their size (m); big enough to read from the creation camera, 50 m off.
const MOTE_SIZE := Vector2(0.16,0.3)
## Share that are leaves (the rest are pale motes, seed fluff).
const LEAF_SHARE := 0.6
## The carry spring (1/s²) and damping (1/s): under critical, so a mote
## overshoots the air a little and drops back (follow-through).
const CARRY := 38.0
const CARRY_DAMP := 7.5
## m/s a mote falls once the air has left it.
const MOTE_FALL := 0.9

# --- Sound --------------------------------------------------------------------
## A looped wind bed (assets/audio/wind-bed.wav) on the Genesis bus: its gain
## while a gust runs and while the hand blows, and pitch at weakest and full.
const VOICE_CLIP := "res://assets/audio/wind-bed.wav"
const VOICE_GAIN := 0.34
const AIM_GAIN := 0.07
const VOICE_PITCH := Vector2(0.85,1.18)
const VOICES := 2

## The terrain's height at a plate x, z (a Vector2), or null off the land.
var ground_at := Callable()
## The land's plate bounds; lanes stop EDGE_MARGIN inside them.
var land := Rect2(-1000.0,-1000.0,2000.0,2000.0)
## The shared air: the atmosphere (studies/atmosphere.gd), the resident's
## LocalWindField, and the lightning that owns the clap ring. Any may be null.
var atmosphere: Node
var field: LocalWindField
var lightning: Node
## The scene, for its `_paused`.
var scene: Node
## Lasting wind, an open option (off unless --gust-nudges): the share of a
## sent gust's power that turns the steady breeze toward its heading and
## freshens it. It writes the atmosphere's dials, so it is saved with the place.
var nudge := 0.25 if "--gust-nudges" in OS.get_cmdline_user_args() else 0.0
## Gusts in flight: {"kind" ("lane" or "burst"), "origin" (plate x, z),
## "heading" (plate, unit), "reach", "half", "power", "t" (s since release),
## "run" (s), "head" (m along or out), "air" (0..1 now), "speed" (m/s),
## "slot" (parcel), "local" (LocalWindField ids), and its nodes}.
var gusts: Array[Dictionary] = []
## Microseconds spent last frame and at most, and on the last release.
var last_usec := 0
var worst_usec := 0
var send_usec := 0
var clock := 0.0

## While the hand blows: {"start", "start_y", "pointer", "samples", "held",
## "moved", "heading", "power", "half", "scale"}; empty otherwise.
var _aim := {}
var _aim_mark: MeshInstance3D
var _marks: Array[MeshInstance3D] = []
var _motes: Array[Dictionary] = []
var _mote_node: MultiMeshInstance3D
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_gain := PackedFloat32Array()
var _voice_goal := PackedFloat32Array()
var _clap_owner: Dictionary = {}
var _rng := RandomNumberGenerator.new()
const LEAF_COLORS := [Color("8fb35a"),Color("a9b957"),Color("c7b35c"),Color("6f9a4c"),Color("b98f4a")]
const MOTE_COLOR := Color("ece6d2")

func _ready() -> void:
	_rng.seed = 5171
	var leaf := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	# A small diamond leaf, 1 m long, lying in its xz plane.
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5,0,0),Vector3(0,0,-0.22),Vector3(0.5,0,0),Vector3(0,0,0.22)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	leaf.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	material.backlight_enabled = true
	material.backlight = Color(0.35,0.4,0.2)
	var motes := MultiMesh.new()
	motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.use_colors = true
	motes.instance_count = MOTES
	motes.visible_instance_count = 0
	motes.mesh = leaf
	# A new MultiMesh's transforms are all zero; without this it draws nothing.
	for i in range(MOTES): motes.set_instance_transform(i,Transform3D.IDENTITY)
	_mote_node = MultiMeshInstance3D.new()
	_mote_node.name = "Motes"
	_mote_node.multimesh = motes
	_mote_node.material_override = material
	_mote_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mote_node.top_level = true
	_mote_node.custom_aabb = AABB(Vector3(-400,-100,-400),Vector3(800,300,800))
	add_child(_mote_node)
	var stream: AudioStreamWAV = null
	if ResourceLoader.exists(VOICE_CLIP):
		stream = (load(VOICE_CLIP) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	for i in range(VOICES):
		var player := AudioStreamPlayer3D.new()
		player.stream = stream
		player.bus = &"Genesis" if AudioServer.get_bus_index(&"Genesis") >= 0 else &"Master"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		player.panning_strength = 0.6
		player.volume_db = -80.0
		add_child(player)
		if stream != null:
			player.play(_rng.randf()*stream.get_length())
			player.stream_paused = true
		_voices.append(player)
	_voice_gain.resize(VOICES)
	_voice_goal.resize(VOICES)

# --- The gesture -----------------------------------------------------------------

## The hand presses at `point` (plate, on the ground) with a lane `half` m to
## each side; `scale` (the brush's strength) scales how hard it blows.
func press(point: Vector3, half: float, scale := 1.0) -> void:
	if aiming(): cancel()
	var start := Vector2(point.x,point.z)
	_aim = {"start":start,"start_y":point.y,"pointer":start,"samples":[Vector3(start.x,start.y,clock)],"held":0.0,"moved":0.0,
		"heading":Vector2.ZERO,"power":MIN_POWER,"half":half,"scale":scale,"voice":_free_voice()}
	_aim_mark = _take_mark()
	# The hand stirs the air where the gust will start: leaves and motes lift
	# and swirl in round the press.
	for i in range(PRESS_MOTES): _add_mote(start,point.y)

func aiming() -> bool:
	return not _aim.is_empty()

## Follow the pointer's ground point (plate, or null off the land).
func aim(point: Variant) -> void:
	if not aiming() or point == null: return
	var at := Vector2(point.x,point.z)
	_aim.pointer = at
	_aim.moved = maxf(_aim.moved,at.distance_to(_aim.start))
	_aim.samples.append(Vector3(at.x,at.y,clock))

## What the gust will do if the hand lets go now: {"kind", "origin",
## "heading", "reach", "half", "power"}. The mark draws exactly this, and
## `release` sends exactly this.
func promise() -> Dictionary:
	if not aiming(): return {}
	var start: Vector2 = _aim.start
	if _aim.moved < STILL_DRAG:
		var gathered := smoothstep(0.0,BURST_GATHER,float(_aim.held))
		return {"kind":"burst","origin":start,"heading":Vector2.ZERO,"reach":_room_round(start,lerpf(BURST_REACH.x,BURST_REACH.y,gathered)),
			"half":float(_aim.half),"power":clampf(lerpf(0.4,1.0,gathered)*float(_aim.scale),0.0,1.0)}
	var heading: Vector2 = _aim.heading
	if heading == Vector2.ZERO: heading = (Vector2(_aim.pointer)-start).normalized()
	var power := clampf(float(_aim.power)*float(_aim.scale),0.0,1.0)
	var swept := maxf((Vector2(_aim.pointer)-start).dot(heading),0.0)
	var reach := clampf(maxf(lerpf(REACH.x,REACH.y,power),swept),0.0,REACH.y)
	return {"kind":"lane","origin":start,"heading":heading,"reach":minf(reach,_room(start,heading)),"half":float(_aim.half),"power":power}

## Let go: the gust goes, as promised. Returns its record ({} if none).
func release() -> Dictionary:
	if not aiming(): return {}
	var began := Time.get_ticks_usec()
	var plan := promise()
	var g := plan.duplicate()
	g.merge({"t":0.0,"head":0.0,"air":0.0,"speed":0.0,"slot":-1,"local":[],"y":float(_aim.start_y),"voice":-1,"done":false})
	var travel: float = float(g.reach)+PULL_BACK*float(g.power) if g.kind == "lane" else float(g.reach)-RING_START+PULL_BACK*float(g.power)
	var cruise := lerpf(CRUISE.x,CRUISE.y,g.power) if g.kind == "lane" else lerpf(BURST_CRUISE.x,BURST_CRUISE.y,g.power)
	g.run = maxf(0.4,2.0*travel/(LAUNCH*cruise))
	g.mark = _aim_mark
	_aim_mark = null
	# Too many in flight: the oldest hastens to its fade.
	var flying := gusts.filter(func(other: Dictionary) -> bool: return not other.done)
	if flying.size() >= MAX_GUSTS:
		var oldest: Dictionary = flying[0]
		oldest.t = maxf(float(oldest.t),WIND_UP+float(oldest.run)*FADE.x)
	var mark_usec := Time.get_ticks_usec()
	_sample_ground(g)
	var ground_usec := Time.get_ticks_usec()
	g.ribbons = _ribbons(g)
	var ribbon_usec := Time.get_ticks_usec()
	_claim_air(g)
	var air_usec := Time.get_ticks_usec()
	for mote: Dictionary in _motes:
		if mote.gust == null and mote.state == "gather": _board(mote,g)
	g.cost_usec = {"promise":mark_usec-began,"ground":ground_usec-mark_usec,"ribbons":ribbon_usec-ground_usec,"air":air_usec-ribbon_usec,"motes":Time.get_ticks_usec()-air_usec}
	# The breath the hand drew goes on as the gust's voice.
	g.voice = _aim.voice
	_aim = {}
	gusts.append(g)
	_nudge(g)
	send_usec = Time.get_ticks_usec()-began
	sent.emit(g)
	return g

## Drop the hand's blow without sending anything.
func cancel() -> void:
	if not aiming(): return
	_aim = {}
	_give_mark(_aim_mark)
	_aim_mark = null
	for mote: Dictionary in _motes:
		if mote.gust == null: mote.state = "fall"

## Every gust stops at once and gives the shared air back (a new world).
func clear() -> void:
	cancel()
	for g: Dictionary in gusts: _retire(g)
	gusts.clear()
	_motes.clear()
	_mote_node.multimesh.visible_instance_count = 0

## The gusts' push at a plate x, z (m/s, plate x, z): each lane along its
## heading and each burst outward, as strong as it is passing there now. For
## anything that drifts on the air and wants to be carried (seeds, pollen).
func wind_at(point: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for g: Dictionary in gusts:
		if g.done or g.air <= 0.0: continue
		var strength: float = lerpf(LOCAL.x,LOCAL.y,g.power)*g.air
		if g.kind == "lane":
			var head: Vector2 = g.origin+g.heading*g.head
			var reach: float = g.half*LOCAL_REACH
			push += g.heading*strength*(1.0-smoothstep(0.0,1.0,point.distance_to(head)/reach))
		else:
			var out := point-Vector2(g.origin)
			var from_ring := absf(out.length()-float(g.head))
			push += out.normalized()*strength*0.8*(1.0-smoothstep(0.0,1.0,from_ring/maxf(2.5,float(g.head)*0.45)))
	return push

# --- Every frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	var began := Time.get_ticks_usec()
	delta = minf(delta,0.05)
	var paused: bool = scene != null and scene.get("_paused") == true
	if paused: delta = 0.0
	clock += delta
	if aiming(): _step_aim(delta)
	for g: Dictionary in gusts: _step_gust(g,delta)
	for i in range(gusts.size()-1,-1,-1):
		if gusts[i].done and float(gusts[i].t) >= WIND_UP+float(gusts[i].run)+SETTLE:
			_retire(gusts[i])
			gusts.remove_at(i)
	_step_motes(delta)
	_step_voices(delta)
	if not gusts.is_empty() and atmosphere != null and atmosphere.get("puffs") != null: atmosphere.puffs.publish()
	if field != null and _steering(): field.publish()
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)

func _steering() -> bool:
	for g: Dictionary in gusts:
		if not g.local.is_empty(): return true
	return false

func _step_aim(delta: float) -> void:
	_aim.held = float(_aim.held)+delta
	var samples: Array = _aim.samples
	while samples.size() > 2 and float(samples[0].z) < clock-SWIPE_WINDOW: samples.pop_front()
	var first: Vector3 = samples[0]
	var last: Vector3 = samples.back()
	var shift := Vector2(last.x-first.x,last.y-first.y)
	var span := last.z-first.z
	var speed := shift.length()/span if span > 0.0001 else 0.0
	if _aim.moved >= STILL_DRAG:
		var goal: Vector2 = shift.normalized() if shift.length() > 0.05 else _aim.heading
		if _aim.heading == Vector2.ZERO: _aim.heading = (Vector2(_aim.pointer)-Vector2(_aim.start)).normalized() if goal == Vector2.ZERO else goal
		elif goal != Vector2.ZERO: _aim.heading = Vector2(_aim.heading).slerp(goal,1.0-exp(-HEADING_FOLLOW*delta)).normalized()
		var target := lerpf(MIN_POWER,1.0,clampf(inverse_lerp(SWIPE_SPEED.x,SWIPE_SPEED.y,speed),0.0,1.0))
		var rate := POWER_RISE if target > _aim.power else POWER_FALL
		_aim.power = lerpf(_aim.power,target,1.0-exp(-rate*delta))
	var plan := promise()
	_paint(_aim_mark,plan,1.0,-1000.0,0.0,0.0,_aim_span(plan))
	var voice: int = _aim.voice
	_voice_goal[voice] = AIM_GAIN*(float(plan.power) if plan.kind == "lane" else 0.4+0.6*smoothstep(0.0,BURST_GATHER,float(_aim.held)))
	_voices[voice].global_position = _world(Vector3(plan.origin.x,float(_aim.start_y),plan.origin.y))

func _step_gust(g: Dictionary, delta: float) -> void:
	g.t = float(g.t)+delta
	var t: float = g.t
	var power: float = g.power
	var from := -PULL_BACK*power if g.kind == "lane" else RING_START-PULL_BACK*power
	var start := 0.0 if g.kind == "lane" else RING_START
	if t < WIND_UP:
		# Anticipation: the air draws back and takes a breath.
		var k := t/WIND_UP
		g.head = lerpf(start,from,sin(k*PI*0.5))
		g.air = 0.25*smoothstep(0.0,1.0,k)
		g.speed = 0.0
	else:
		var u := clampf((t-WIND_UP)/float(g.run),0.0,1.0)
		var span: float = float(g.reach)-from
		g.head = from+span*(1.0-pow(1.0-u,2.0))
		g.speed = 2.0*span*(1.0-u)/float(g.run)
		g.air = lerpf(0.25,1.0,smoothstep(0.0,BUILD,u))*(1.0-smoothstep(FADE.x,FADE.y,u))
		if u >= 1.0 and not g.done:
			g.done = true
			g.air = 0.0
			_release_air(g)
	if not g.done: _feed_air(g)
	var settle := clampf((t-WIND_UP-float(g.run))/SETTLE,0.0,1.0)
	_paint(g.mark,g,1.0-smoothstep(0.0,0.6,settle),float(g.head),float(g.air),float(g.speed),Vector2(g.floor,g.ceiling))
	var ribbons: MeshInstance3D = g.ribbons
	var material := ribbons.material_override as ShaderMaterial
	material.set_shader_parameter("head",float(g.head))
	material.set_shader_parameter("clock",clock)
	material.set_shader_parameter("opacity",0.85*maxf(float(g.air),0.35*(1.0-settle)*float(t > WIND_UP)))
	material.set_shader_parameter("flow",float(g.speed)*0.5+2.0)
	if g.voice >= 0 and not g.done:
		_voice_goal[g.voice] = VOICE_GAIN*lerpf(0.6,1.0,power)*maxf(float(g.air),0.0)
		_voices[g.voice].pitch_scale = lerpf(VOICE_PITCH.x,VOICE_PITCH.y,power)*(0.94+0.08*clampf(float(g.speed)/20.0,0.0,1.0))
		var at: Vector2 = _head_point(g)
		_voices[g.voice].global_position = _world(Vector3(at.x,g.y,at.y))

func _head_point(g: Dictionary) -> Vector2:
	return Vector2(g.origin)+Vector2(g.heading)*float(g.head) if g.kind == "lane" else Vector2(g.origin)

# --- The shared air ----------------------------------------------------------------

## A lane takes a parcel slot and a steered local gust; a burst takes the
## clap ring and BURST_SPOKES steered gusts.
func _claim_air(g: Dictionary) -> void:
	var up := Vector3.UP*LOCAL_LIFT
	var at := _world(Vector3(g.origin.x,g.y,g.origin.y))
	if g.kind == "lane":
		if atmosphere != null and atmosphere.get("puffs") != null: g.slot = atmosphere.puffs.hold_slot()
		if field != null:
			var id := field.emit_steered(at+up,_world_way(g.heading),0.0001,float(g.half)*LOCAL_REACH)
			if id >= 0: g.local.append(id)
	else:
		_clap_owner = g
		if field != null:
			for i in range(BURST_SPOKES):
				var way := Vector2.RIGHT.rotated(TAU*float(i)/BURST_SPOKES+0.4)
				var id := field.emit_steered(at+up,_world_way(way),0.0001,2.5)
				if id >= 0: g.local.append(id)

func _feed_air(g: Dictionary) -> void:
	var power: float = g.power
	var air: float = g.air
	var up := Vector3.UP*LOCAL_LIFT
	if g.kind == "lane":
		var head := _head_point(g)
		var world := _world(Vector3(head.x,_grid_height(g,float(g.head),0.0),head.y))
		var way := _world_way(g.heading)
		if g.slot >= 0 and atmosphere != null:
			var travel: float = atmosphere._gust_distance
			var heading := Vector2(way.x,way.z)
			var origin := Vector2(world.x,world.z)-heading*PARCEL_AGE
			atmosphere.puffs.steer(g.slot,Vector4(origin.x,origin.y,travel-PARCEL_AGE,lerpf(PUFF.x,PUFF.y,power)*air),heading)
		for id: int in g.local:
			field.steer(id,world+up,way,lerpf(LOCAL.x,LOCAL.y,power)*air,float(g.half)*LOCAL_REACH)
	else:
		var center := _world(Vector3(g.origin.x,g.y,g.origin.y))
		var radius: float = g.head
		if is_same(_clap_owner,g): _set_clap(Vector4(center.x,center.z,maxf(radius,0.0),lerpf(BURST_CLAP.x,BURST_CLAP.y,power)*air))
		for i in range(g.local.size()):
			var way := Vector2.RIGHT.rotated(TAU*float(i)/BURST_SPOKES+0.4)
			var point: Vector2 = Vector2(g.origin)+way*radius
			var world := _world(Vector3(point.x,_grid_height(g,radius,way.angle()),point.y))
			field.steer(g.local[i],world+up,_world_way(way),lerpf(LOCAL.x,LOCAL.y,power)*air*0.8,maxf(2.5,radius*0.45))

## Give the parcel slot, the steered gusts and the clap ring back.
func _release_air(g: Dictionary) -> void:
	if g.slot >= 0 and atmosphere != null: atmosphere.puffs.let_go(g.slot)
	g.slot = -1
	if field != null:
		for id: int in g.local: field.let_go(id)
	g.local = []
	if is_same(_clap_owner,g):
		_set_clap(Vector4.ZERO)
		_clap_owner = {}

func _set_clap(clap: Vector4) -> void:
	# The lightning keeps and publishes the clap every frame; write through it.
	if lightning != null and lightning.get("clap") != null: lightning.clap = clap
	RenderingServer.global_shader_parameter_set("zs_clap",clap)

func _retire(g: Dictionary) -> void:
	_release_air(g)
	g.done = true
	_give_mark(g.mark)
	if is_instance_valid(g.get("ribbons")): g.ribbons.queue_free()
	for mote: Dictionary in _motes:
		if is_same(mote.gust,g): mote.state = "gone"

## Lasting wind (`nudge`): a lane turns the steady breeze toward it.
func _nudge(g: Dictionary) -> void:
	if nudge <= 0.0 or atmosphere == null or g.kind != "lane": return
	var way := _world_way(g.heading)
	var share := nudge*float(g.power)
	atmosphere.direction_angle = rad_to_deg(lerp_angle(deg_to_rad(atmosphere.direction_angle),atan2(way.z,way.x),share))
	atmosphere.strength = minf(float(atmosphere.strength)+share*0.2,1.4)

# --- Ground ------------------------------------------------------------------------

func _ground(point: Vector2, fallback: float) -> float:
	if not ground_at.is_valid(): return fallback
	var h: Variant = ground_at.call(point)
	return float(h) if h != null else fallback

## Metres from `start` along `heading` to EDGE_MARGIN inside the land.
func _room(start: Vector2, heading: Vector2) -> float:
	var inner := land.grow(-EDGE_MARGIN)
	var best := INF
	if absf(heading.x) > 0.0001:
		best = minf(best,((inner.end.x if heading.x > 0.0 else inner.position.x)-start.x)/heading.x)
	if absf(heading.y) > 0.0001:
		best = minf(best,((inner.end.y if heading.y > 0.0 else inner.position.y)-start.y)/heading.y)
	return maxf(best,0.0)

## A burst's reach, kept to the land's nearest edge.
func _room_round(start: Vector2, reach: float) -> float:
	var inner := land.grow(-EDGE_MARGIN)
	var room := minf(minf(start.x-inner.position.x,inner.end.x-start.x),minf(start.y-inner.position.y,inner.end.y-start.y))
	return clampf(minf(reach,room),BURST_REACH.x*0.5,reach)

## Ground heights under a gust, sampled once when it goes, on a grid: along
## the lane by GRID_STEP m at five places across, or round a burst at twelve
## angles. Ribbons, leaves and the mark's height range read it.
func _sample_ground(g: Dictionary) -> void:
	var y: float = g.y
	var rows := PackedFloat32Array()
	var low := y
	var high := y
	if g.kind == "lane":
		g.grid_from = -3.0
		g.grid_rows = int(ceil((float(g.reach)+5.0)/GRID_STEP))+1
		g.grid_cols = 5
		var side := Vector2(-g.heading.y,g.heading.x)
		for i in range(g.grid_rows):
			for j in range(g.grid_cols):
				var across := lerpf(-1.2,1.2,float(j)/4.0)*float(g.half)
				var point: Vector2 = Vector2(g.origin)+Vector2(g.heading)*(g.grid_from+i*GRID_STEP)+side*across
				var h := _ground(point,y)
				rows.append(h)
				low = minf(low,h)
				high = maxf(high,h)
	else:
		g.grid_from = 0.0
		g.grid_rows = int(ceil((float(g.reach)+2.0)/GRID_STEP))+1
		g.grid_cols = 12
		for i in range(g.grid_rows):
			for j in range(g.grid_cols):
				var point: Vector2 = Vector2(g.origin)+Vector2.RIGHT.rotated(TAU*j/12.0)*(i*GRID_STEP)
				var h := _ground(point,y)
				rows.append(h)
				low = minf(low,h)
				high = maxf(high,h)
	g.grid = rows
	g.floor = low-0.6
	g.ceiling = high+0.6

## Ground height under a gust: `along` m along its lane (or out from a
## burst), `across` m to the side (or the angle round a burst).
func _grid_height(g: Dictionary, along: float, across: float) -> float:
	var grid: PackedFloat32Array = g.get("grid",PackedFloat32Array())
	if grid.is_empty(): return float(g.y)
	var rows: int = g.grid_rows
	var cols: int = g.grid_cols
	var fi := clampf((along-float(g.grid_from))/GRID_STEP,0.0,rows-1.0001)
	var i := int(fi)
	var fj: float
	if g.kind == "lane":
		fj = clampf((across/float(g.half)+1.2)/2.4*4.0,0.0,cols-1.0001)
	else:
		fj = fposmod(across/TAU*12.0,12.0)
	var j := int(fj)
	var j1 := (j+1)%cols if g.kind != "lane" else j+1
	var a := lerpf(grid[i*cols+j],grid[i*cols+j1],fj-j)
	var b := lerpf(grid[(i+1)*cols+j],grid[(i+1)*cols+j1],fj-j)
	return lerpf(a,b,fi-i)

# --- The mark ------------------------------------------------------------------------

func _take_mark() -> MeshInstance3D:
	var node: MeshInstance3D = _marks.pop_back() if not _marks.is_empty() else null
	if node == null:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/wind_gust_ground.gdshader")
		material.render_priority = -1
		node = MeshInstance3D.new()
		node.name = "Mark"
		node.mesh = BoxMesh.new()
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		add_child(node)
	node.visible = true
	return node

func _give_mark(node: MeshInstance3D) -> void:
	if node == null: return
	node.visible = false
	_marks.append(node)

## The heights the aimed mark may paint: its start and a few points along it.
func _aim_span(plan: Dictionary) -> Vector2:
	var y: float = _aim.start_y
	var low := y
	var high := y
	var steps := 4
	for i in range(1,steps+1):
		var point: Vector2
		if plan.kind == "lane": point = Vector2(plan.origin)+Vector2(plan.heading)*float(plan.reach)*i/steps
		else: point = Vector2(plan.origin)+Vector2.RIGHT.rotated(TAU*i/steps)*float(plan.reach)
		var h := _ground(point,y)
		low = minf(low,h)
		high = maxf(high,h)
	return Vector2(low-1.5,high+1.5)

## Place and draw a mark for `plan` (a promise or a gust): `shown` of it,
## the air's head at `passed`, passing at `air`, moving at `speed` m/s.
func _paint(node: MeshInstance3D, plan: Dictionary, shown: float, passed: float, air: float, speed: float, span: Vector2) -> void:
	if node == null: return
	var material := node.material_override as ShaderMaterial
	var origin: Vector2 = plan.origin
	var reach: float = plan.reach
	var half: float = plan.half
	var height := span.y-span.x
	var center_y := (span.x+span.y)*0.5
	var box: Transform3D
	var parent := get_parent() as Node3D
	if plan.kind == "lane":
		var heading: Vector2 = plan.heading
		var middle := origin+heading*(reach-half)*0.5
		var local := Transform3D(Basis(Vector3(heading.x,0,heading.y)*(reach+half+1.0),Vector3.UP*height,Vector3(-heading.y,0,heading.x)*(half*TIP_WIDTH+1.0)*2.0),Vector3(middle.x,center_y,middle.y))
		box = parent.global_transform*local if parent != null else local
	else:
		var local := Transform3D(Basis.from_scale(Vector3((reach+1.5)*2.0,height,(reach+1.5)*2.0)),Vector3(origin.x,center_y,origin.y))
		box = parent.global_transform*local if parent != null else local
	node.global_transform = box
	var world_origin := _world(Vector3(origin.x,center_y,origin.y))
	var way := _world_way(plan.heading) if plan.kind == "lane" else Vector3.RIGHT
	var scale := _world_scale()
	material.set_shader_parameter("shape",0 if plan.kind == "lane" else 1)
	material.set_shader_parameter("origin",Vector2(world_origin.x,world_origin.z))
	material.set_shader_parameter("heading",Vector2(way.x,way.z))
	material.set_shader_parameter("reach",reach*scale)
	material.set_shader_parameter("half_width",half*scale)
	material.set_shader_parameter("promise",shown)
	material.set_shader_parameter("power",float(plan.power))
	material.set_shader_parameter("passed",passed*scale if passed > -999.0 else passed)
	material.set_shader_parameter("air",air)
	material.set_shader_parameter("head_speed",speed*scale)
	material.set_shader_parameter("age",clock)
	material.set_shader_parameter("breath",sin(clock*TAU*0.55))
	material.set_shader_parameter("floor_y",_world(Vector3(origin.x,span.x,origin.y)).y)
	material.set_shader_parameter("ceiling",_world(Vector3(origin.x,span.y,origin.y)).y)

# --- Ribbons -------------------------------------------------------------------------

## Ribbons for a gust that has gone, laid over the ground it will cross.
func _ribbons(g: Dictionary) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var lifts := [0.55,1.15,0.35,1.55,0.8,1.3,0.45,0.95,1.7,0.6]
	var lags := [0.0,1.4,0.7,2.4,1.9,0.4,1.1,2.8,0.2,1.7]
	var count := STRANDS if g.kind == "lane" else SPOKES
	for k in range(count):
		var lag: float = lags[k%lags.size()]
		var lift: float = lifts[k%lifts.size()]
		var phase := _rng.randf()
		var first := vertices.size()
		var way: Vector2
		var side: Vector2
		var across := 0.0
		var from := -1.5
		var to: float = float(g.reach)+1.0
		var angle := 0.0
		if g.kind == "lane":
			way = g.heading
			side = Vector2(-way.y,way.x)
			across = lerpf(-0.7,0.7,float(k)/maxf(count-1.0,1.0))*float(g.half)+_rng.randf_range(-0.2,0.2)
		else:
			angle = TAU*float(k)/count+_rng.randf_range(-0.2,0.2)
			way = Vector2.RIGHT.rotated(angle)
			side = Vector2(-way.y,way.x)
			from = RING_START*0.5
			to = float(g.reach)+1.5
		var steps := int(ceil((to-from)/RIBBON_STEP))
		for s in range(steps+1):
			var a := from+s*RIBBON_STEP
			var sway := sin(a*0.3+k*1.7)*0.35
			var point: Vector2 = Vector2(g.origin)+way*a+side*(across+sway)
			var ground := _grid_height(g,a,across+sway) if g.kind == "lane" else _grid_height(g,a,angle)
			var world := _world(Vector3(point.x,ground+lift+sin(a*0.21+k)*0.15,point.y))
			for edge in [0.0,1.0]:
				vertices.append(world)
				uvs.append(Vector2(a,edge))
				colors.append(Color(lag,phase,0,1))
			if s > 0:
				var base := first+(s-1)*2
				indices.append_array(PackedInt32Array([base,base+1,base+3,base,base+3,base+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/wind_gust_trail.gdshader")
	material.set_shader_parameter("width",lerpf(RIBBON_WIDTH.x,RIBBON_WIDTH.y,g.power))
	material.set_shader_parameter("trail_length",TRAIL_LENGTH*(1.0 if g.kind == "lane" else 0.6))
	material.set_shader_parameter("opacity",0.0)
	var node := MeshInstance3D.new()
	node.name = "Ribbons"
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.extra_cull_margin = 2.0
	add_child(node)
	node.global_transform = Transform3D.IDENTITY
	return node

# --- Leaves and motes ------------------------------------------------------------

## A leaf or mote lifts and swirls in round a press at `start`.
func _add_mote(start: Vector2, y: float) -> void:
	if _motes.size() >= MOTES:
		# The one that has been resting longest makes room.
		for i in range(_motes.size()):
			if _motes[i].state in ["rest","gone"]:
				_motes.remove_at(i)
				break
		if _motes.size() >= MOTES: return
	var leaf := _rng.randf() < LEAF_SHARE
	var color: Color = LEAF_COLORS[_rng.randi()%LEAF_COLORS.size()] if leaf else MOTE_COLOR
	_motes.append({"gust":null,"state":"gather","center":start,"y0":y,"rho":_rng.randf_range(0.6,1.6),"theta":_rng.randf()*TAU,
		"u":0.0,"v":0.0,"vu":0.0,"vv":0.0,"y":_rng.randf_range(0.05,0.2),"lift":_rng.randf_range(0.35,1.9),"lag":_rng.randf_range(-0.5,4.5),
		"home":0.0,"size":_rng.randf_range(MOTE_SIZE.x,MOTE_SIZE.y)*(1.0 if leaf else 0.7),"spin":_rng.randf()*TAU,"phase":_rng.randf()*TAU,
		"leaf":leaf,"color":color,"shown":0.0,"rest":0.0})

## A gathered mote rides the gust that just went.
func _board(mote: Dictionary, g: Dictionary) -> void:
	mote.gust = g
	mote.state = "ride"
	var at := Vector2(mote.center)+Vector2(cos(mote.theta),sin(mote.theta))*float(mote.rho)
	var rel := at-Vector2(g.origin)
	if g.kind == "lane":
		mote.u = rel.dot(g.heading)
		mote.v = rel.dot(Vector2(-g.heading.y,g.heading.x))
		mote.home = _rng.randf_range(-0.8,0.8)*float(g.half)
	else:
		mote.u = rel.length()
		mote.v = rel.angle()
		mote.home = mote.v
	mote.vu = 0.0
	mote.vv = 0.0

func _step_motes(delta: float) -> void:
	var multimesh := _mote_node.multimesh
	var shown := 0
	for i in range(_motes.size()-1,-1,-1):
		if _motes[i].state == "gone" and float(_motes[i].shown) <= 0.0: _motes.remove_at(i)
	for mote: Dictionary in _motes:
		var g: Variant = mote.gust
		var world: Vector3
		var tumble := 0.0
		if g == null:
			# Gathering: they swirl in round the press, a little higher and
			# quicker the longer the hand holds.
			var hold := float(_aim.get("held",0.0)) if aiming() else 1.0
			mote.theta = float(mote.theta)+delta*(2.0+1.6/maxf(float(mote.rho),0.4))
			mote.rho = lerpf(float(mote.rho),0.5+0.4*sin(float(mote.phase)),1.0-exp(-0.8*delta))
			var goal_y := float(mote.lift)*0.35*smoothstep(0.0,0.6,hold)+0.1
			if mote.state == "fall": goal_y = 0.03
			mote.y = lerpf(float(mote.y),goal_y,1.0-exp(-3.0*delta))
			var at := Vector2(mote.center)+Vector2(cos(mote.theta),sin(mote.theta))*float(mote.rho)
			world = _world(Vector3(at.x,_ground(at,float(mote.y0)) if mote.state == "fall" else float(mote.y0),at.y)+Vector3.UP*float(mote.y))
			tumble = 3.0
			if mote.state == "fall" and float(mote.y) < 0.05: mote.state = "gone"
		else:
			var air: float = g.air
			var riding: bool = not g.done and air > 0.08
			if riding:
				# Picked up when the head reaches it, then carried on a spring
				# that overshoots and drops back.
				var target := maxf(float(mote.u),float(g.head)-float(mote.lag))
				if g.kind == "burst": target = maxf(float(mote.u),float(g.head)-float(mote.lag)*0.5)
				var pull := target-float(mote.u)
				mote.vu = float(mote.vu)+(CARRY*pull-CARRY_DAMP*float(mote.vu))*delta
				mote.y = lerpf(float(mote.y),float(mote.lift)*(0.35+0.65*air),1.0-exp(-4.0*delta))
			else:
				# The air has gone: they coast, slow, flutter and fall.
				mote.vu = float(mote.vu)*exp(-2.2*delta)
				mote.y = maxf(float(mote.y)-MOTE_FALL*delta*(0.6+0.4*sin(clock*4.0+float(mote.phase))),0.03)
			mote.u = float(mote.u)+float(mote.vu)*delta
			var limit: float = float(g.reach)+1.0
			mote.u = clampf(float(mote.u),-1.5 if g.kind == "lane" else 0.0,limit)
			var at: Vector2
			var ground: float
			if g.kind == "lane":
				var wander := sin(clock*2.6+float(mote.phase))*0.35*air
				mote.v = lerpf(float(mote.v),float(mote.home)+wander,1.0-exp(-2.5*delta))
				mote.v = clampf(float(mote.v),-0.95*float(g.half),0.95*float(g.half))
				at = Vector2(g.origin)+Vector2(g.heading)*float(mote.u)+Vector2(-g.heading.y,g.heading.x)*float(mote.v)
				ground = _grid_height(g,float(mote.u),float(mote.v))
			else:
				mote.v = float(mote.v)+sin(clock*2.0+float(mote.phase))*0.15*air*delta
				at = Vector2(g.origin)+Vector2.RIGHT.rotated(float(mote.v))*float(mote.u)
				ground = _grid_height(g,float(mote.u),float(mote.v))
			world = _world(Vector3(at.x,ground+float(mote.y),at.y))
			tumble = 2.0+absf(float(mote.vu))*0.6
			if not riding and float(mote.y) <= 0.035:
				mote.state = "rest"
				mote.rest = float(mote.rest)+delta
		var goal_shown := 1.0
		if mote.state == "gone" or float(mote.rest) > 0.4: goal_shown = 0.0
		mote.shown = move_toward(float(mote.shown),goal_shown,delta*(4.0 if goal_shown > 0.0 else 1.6))
		if mote.state == "rest" and float(mote.shown) <= 0.0: mote.state = "gone"
		mote.spin = float(mote.spin)+delta*tumble*(1.0 if mote.state != "rest" else 0.0)
		if shown >= MOTES: continue
		var size: float = float(mote.size)*smoothstep(0.0,1.0,float(mote.shown))
		var basis := Basis(Vector3.UP,float(mote.spin)*0.7+float(mote.phase))
		if mote.state != "rest":
			basis = basis*Basis(Vector3.RIGHT,float(mote.spin)*(1.3 if mote.leaf else 0.4))*Basis(Vector3.FORWARD,sin(clock*5.0+float(mote.phase))*0.6)
		multimesh.set_instance_transform(shown,Transform3D(basis.scaled(Vector3.ONE*maxf(size,0.0001)),world))
		multimesh.set_instance_color(shown,mote.color)
		shown += 1
	multimesh.visible_instance_count = shown
	_mote_node.visible = shown > 0

# --- Sound ---------------------------------------------------------------------------

func _step_voices(delta: float) -> void:
	for i in range(VOICES):
		var goal := _voice_goal[i]
		var gain := lerpf(_voice_gain[i],goal,1.0-exp(-delta*(6.0 if goal > _voice_gain[i] else 2.2)))
		if goal == 0.0 and gain < 0.0005: gain = 0.0
		_voice_gain[i] = gain
		var player := _voices[i]
		if player.stream == null: continue
		var silent := gain <= 0.0 or delta <= 0.0
		if player.stream_paused != silent: player.stream_paused = silent
		if not silent: player.volume_db = linear_to_db(gain)
	var busy := _busy_voices()
	for i in range(VOICES):
		if busy[i] == 0: _voice_goal[i] = 0.0

## Which voices a running gust or the blowing hand holds.
func _busy_voices() -> PackedByteArray:
	var busy := PackedByteArray()
	busy.resize(VOICES)
	for g: Dictionary in gusts:
		if g.voice >= 0 and not g.done: busy[g.voice] = 1
	if aiming(): busy[int(_aim.voice)] = 1
	return busy

## A voice no running gust holds, else the one the oldest gust holds.
func _free_voice() -> int:
	var busy := _busy_voices()
	for i in range(VOICES):
		if busy[i] == 0: return i
	for g: Dictionary in gusts:
		if g.voice >= 0 and not g.done:
			var voice: int = g.voice
			g.voice = -1
			return voice
	return 0

# --- Plate and world -------------------------------------------------------------

func _world(point: Vector3) -> Vector3:
	var parent := get_parent() as Node3D
	return parent.to_global(point) if parent != null else point

func _world_way(way: Vector2) -> Vector3:
	var parent := get_parent() as Node3D
	var turned := parent.global_basis*Vector3(way.x,0,way.y) if parent != null else Vector3(way.x,0,way.y)
	turned.y = 0.0
	return turned.normalized() if turned.length_squared() > 0.000001 else Vector3.RIGHT

func _world_scale() -> float:
	var parent := get_parent() as Node3D
	return parent.global_basis.get_scale().x if parent != null else 1.0
