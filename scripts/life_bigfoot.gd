extends Node3D
## The rarest moment (docs/scenic/life.md, "Bigfoot"): the ambient Bigfoot
## (assets/models/zenscape-bigfoot-ambient.glb, art/blender/bigfoot/README.md)
## at the edge of a wood. LifeMoments decides when; this node decides where,
## stages what he does and sends him away again.
##
## Three sightings, each a list of beats (a clip, how long, an optional path):
## - "watch": he walks out of the trees, turns to the camera and watches it
##   (Watch), then walks back in glancing over his shoulder (WalkGlance).
## - "listen": the same, but he hears you rather than sees you (Listen), with
##   the camera off to his left where the clip looks.
## - "stride": the 1967 film. He strides out of the wood, across the open ground
##   along its edge and back in, turning to look at the camera mid-stride
##   (Stride, StrideLookL/R).
## Whatever he is doing, he leaves (strides into the trees) if the camera
## closes in or the player paints near him.
##
## The model loads on a worker thread at setup and is built hidden the first
## time LifeMoments polls after it lands, so nothing loads when he appears.
## The AnimationPlayer runs in manual mode on the life clock: a hidden Bigfoot
## costs nothing, and a paced probe sees the clips at its pace.

const Survey = preload("res://scripts/life_survey.gd")
const MODEL := "res://assets/models/zenscape-bigfoot-ambient.glb"
## Rig extras (walk_speed_mps, stride_speed_mps); these are the fallbacks.
const WALK_SPEED := 0.336
const STRIDE_SPEED := 0.971
const STRIDE_CYCLE := 1.4
## Plate half-size he keeps inside, metres.
const PLATE := 12.8
## Footing: steepest rise per metre under him, and trunk clearance.
const MAX_SLOPE := 0.45
const TRUNK_CLEAR := 0.5
const TRUNK_CLEAR_INSIDE := 0.32
## Camera: horizontal distance band, the distance he likes best, the steepest
## camera elevation he is staged for, and the screen margin he stays inside.
const NEAR := 14.0
const FAR := 60.0
const IDEAL := 26.0
const MAX_ELEVATION := deg_to_rad(55.0)
const SCREEN_MARGIN := 0.08
## Open ground toward the camera: no trunk within OPEN_WIDTH of the line for
## OPEN_REACH metres.
const OPEN_REACH := 8.0
const OPEN_WIDTH := 1.1
## Shy: he leaves if the camera comes within SHY_NEAR, or approaches faster
## than SHY_APPROACH m/s while within SHY_WATCH, or a stroke lands within SHY_PAINT.
const SHY_NEAR := 9.0
const SHY_APPROACH := 5.0
const SHY_WATCH := 30.0
const SHY_PAINT := 10.0
## How far out of and into the trees he walks for the edge sightings.
const EDGE_DEPTH := 1.8
const EDGE_OUT := 0.4
const WATCH_TIME := 9.5
const LISTEN_TIME := 9.0
## Listen hears you off to his left: the body turns this far from the camera.
const LISTEN_OFFSET := 0.42
## Stride: half the chord of the arc along the edge, how deep its ends go into
## the trees and how far its middle bulges into the open.
const STRIDE_HALF := 6.0
const STRIDE_DEPTH := 1.8
const STRIDE_BULGE := 3.0
const STRIDE_FACING := 0.62
## Scale-in/out while inside the trees, seconds.
const FADE := 0.6
## Eyes: faint amber at night, from the original game's darkness fade.
const EYE_COLOR := Color(1.0,0.6,0.18)
const EYE_GLOW := 1.4

var moments: Node3D
var life: Node3D
var actor: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var walk_speed := WALK_SPEED
## Filming turns this off so a framed camera does not send him away.
var shy := true
var stride_speed := STRIDE_SPEED
## The sighting on stage, or empty.
var state := {}
## Microseconds the last advance took, and the build (first use) cost.
var last_usec := 0
var build_usec := 0
var _loading := false
var _eyes: ShaderMaterial
var _glow := -1.0
var _camera_distance := -1.0
var _approach := 0.0

func setup(owner: Node3D) -> void:
	moments = owner
	life = owner.life
	name = "Bigfoot"
	visible = false
	_loading = ResourceLoader.load_threaded_request(MODEL,"PackedScene",true) == OK

## True once the model is built. Polls the threaded load; `wait` blocks for
## it (probes and forced sightings).
func ready_to_show(wait := false) -> bool:
	if actor != null: return true
	if not _loading:
		# The threaded request failed to start; load in place.
		_build(load(MODEL) as PackedScene)
		return actor != null
	var status := ResourceLoader.load_threaded_get_status(MODEL)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not wait: return false
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_loading = false
		push_warning("Bigfoot model failed to load: "+MODEL)
		return false
	_build(ResourceLoader.load_threaded_get(MODEL) as PackedScene)
	_loading = false
	return actor != null

func _build(packed: PackedScene) -> void:
	if packed == null: return
	var began := Time.get_ticks_usec()
	actor = packed.instantiate()
	add_child(actor)
	var rig := actor.find_child("BigfootRig",true,false)
	if rig != null and rig.has_meta("extras"):
		var extras: Dictionary = rig.get_meta("extras")
		walk_speed = float(extras.get("walk_speed_mps",WALK_SPEED))
		stride_speed = float(extras.get("stride_speed_mps",STRIDE_SPEED))
	skeleton = actor.find_child("Skeleton3D",true,false)
	player = actor.find_child("AnimationPlayer",true,false)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["Walk","Stride"]:
		if player.has_animation(clip): player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# The painted look: the scene's surface shader over the coat's vertex
	# colours, and the eyes' own vertex colour with a night glow.
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://shaders/reference_surface.gdshader")
	_eyes = ShaderMaterial.new()
	_eyes.shader = coat.shader
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface)
			var eye := source != null and "eye" in source.resource_name.to_lower()
			mesh.set_surface_override_material(surface,_eyes if eye else coat)
	build_usec = Time.get_ticks_usec()-began

func showing() -> bool:
	return not state.is_empty()

func hide_now() -> void:
	state = {}
	visible = false

# --- Placement ----------------------------------------------------------------

## Stage a sighting of `kind` ("watch", "listen", "stride", or "" for the
## dice) at one of `edges`. `in_view` requires the spot to be on screen and in
## the camera's distance band; forced sightings fall back to any good edge.
## False when no edge gives him footing.
func begin(kind: String, edges: Array, min_trees: int, in_view: bool) -> bool:
	if not ready_to_show(true): return false
	var rng: RandomNumberGenerator = life._rng
	if kind == "":
		var roll := rng.randf()
		kind = "stride" if roll < 0.4 else ("watch" if roll < 0.8 else "listen")
	var trunks := _trunks()
	var eye := _eye()
	var picks := []
	for edge: Dictionary in edges:
		if int(edge.trees) < min_trees: continue
		var p: Vector2 = edge.p
		var into: Vector2 = edge.into
		var offset := Vector2(eye.x,eye.z)-p
		var distance := offset.length()
		# Seen from the open side: the camera is on the side the wood is not.
		if offset.dot(into) > -0.2*distance: continue
		if in_view and (distance < NEAR or distance > FAR): continue
		# A real edge, not a gap inside the wood: no trunk between him and the
		# camera for OPEN_REACH metres.
		if not _open_view(p-into*EDGE_OUT,offset/distance,trunks): continue
		var score := absf(distance-IDEAL)+rng.randf()*6.0
		if in_view:
			var centre := _on_screen(Vector3(p.x,moments._ground(p)+1.4,p.y))
			if centre < 0.0: continue
			var rise := atan2(eye.y-moments._ground(p),distance)
			if rise > MAX_ELEVATION: continue
			score += centre*12.0
		picks.append([score,edge])
	picks.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var order: Array[String] = [kind]
	for other in ["stride","watch","listen"]:
		if other not in order: order.append(other)
	for option in order:
		for pick in picks.slice(0,24):
			var beats := _stride(pick[1],trunks,eye) if option == "stride" else _edge(pick[1],trunks,eye,option)
			if beats.is_empty(): continue
			_start(option,pick[1],beats)
			return true
	return false

## Watch or Listen: out of the trees, a long look, back in over the shoulder.
func _edge(edge: Dictionary, trunks: PackedVector2Array, eye: Vector3, kind: String) -> Array:
	var p: Vector2 = edge.p
	var into: Vector2 = edge.into
	var start := p+into*EDGE_DEPTH
	var stand := p-into*EDGE_OUT
	var out := _line(start,stand)
	if not _walkable(out,trunks,p,into): return []
	if _clearance(stand,trunks) < TRUNK_CLEAR+0.1: return []
	var home := stand+into*(walk_speed*10.0)
	var back := _line(stand,home)
	if not _walkable(back,trunks,p,into): return []
	var toward := atan2(eye.x-stand.x,eye.z-stand.y)
	var clip := "Watch" if kind == "watch" else "Listen"
	var face := toward if kind == "watch" else toward-LISTEN_OFFSET
	return [
		{"clip":"Walk","length":_length(out)/walk_speed,"path":out,"speed":walk_speed,"blend":0.0},
		{"clip":clip,"length":WATCH_TIME if kind == "watch" else LISTEN_TIME,"face":face,"blend":0.8},
		{"clip":"WalkGlance","length":_length(back)/walk_speed,"path":back,"speed":walk_speed,"blend":0.9,"fade":"out"},
	]

## The film: an arc out of the wood, along its edge in the open and back in.
func _stride(edge: Dictionary, trunks: PackedVector2Array, eye: Vector3) -> Array:
	var p: Vector2 = edge.p
	var into: Vector2 = edge.into
	var along := into.orthogonal()
	var view := (p-Vector2(eye.x,eye.z)).normalized()
	# Side-on to the camera, or the famous look is lost.
	if absf(along.dot(view)) > STRIDE_FACING: return []
	for direction: float in ([1.0,-1.0] if life._rng.randf() < 0.5 else [-1.0,1.0]):
		var a := p+into*STRIDE_DEPTH-along*direction*STRIDE_HALF
		var c := p+into*STRIDE_DEPTH+along*direction*STRIDE_HALF
		var b := p-into*STRIDE_BULGE
		var path := PackedVector2Array()
		for i in range(33): path.append(_quad(a,b,c,float(i)/32.0))
		if not _walkable(path,trunks,p,into): continue
		var total := _length(path)/stride_speed
		var middle := (path[16]+path[15])*0.5
		var heading := (path[17]-path[15]).normalized()
		var left := Vector2(heading.y,-heading.x)
		var look := "StrideLookL" if left.dot(Vector2(eye.x,eye.z)-middle) > 0.0 else "StrideLookR"
		# The look's turn peaks about 3.5 s into its clip: centre it on the arc.
		var lead := maxf(0.0,roundf((total*0.5-3.5)/STRIDE_CYCLE))*STRIDE_CYCLE
		var rest := total-lead-7.0
		if rest < 1.0: continue
		return [
			{"clip":"Stride","length":lead,"path":path,"speed":stride_speed,"blend":0.0,"travel":0.0},
			{"clip":look,"length":7.0,"path":path,"speed":stride_speed,"blend":0.0,"travel":lead*stride_speed},
			{"clip":"Stride","length":rest,"path":path,"speed":stride_speed,"blend":0.0,"fade":"out","travel":(lead+7.0)*stride_speed},
		]
	return []

static func _quad(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b,t).lerp(b.lerp(c,t),t)

static func _line(a: Vector2, b: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	var steps := maxi(2,ceili(a.distance_to(b)/0.4))
	for i in range(steps+1): path.append(a.lerp(b,float(i)/steps))
	return path

static func _length(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1,path.size()): total += path[i-1].distance_to(path[i])
	return total

## Every point on dry ground inside the plate, gentle underfoot and clear of
## trunks (a little closer is allowed inside the wood).
func _walkable(path: PackedVector2Array, trunks: PackedVector2Array, edge: Vector2, into: Vector2) -> bool:
	var survey: RefCounted = life.survey
	for i in range(path.size()):
		var q := path[i]
		if absf(q.x) > PLATE or absf(q.y) > PLATE: return false
		if life.data.ground_height(q) == null: return false
		if survey != null and survey.wet_at(q): return false
		if _slope(q) > MAX_SLOPE: return false
		var inside := (q-edge).dot(into) > 0.6
		if _clearance(q,trunks) < (TRUNK_CLEAR_INSIDE if inside else TRUNK_CLEAR): return false
	return true

func _slope(q: Vector2) -> float:
	var s := 0.35
	var dx: float = moments._ground(q+Vector2(s,0))-moments._ground(q-Vector2(s,0))
	var dz: float = moments._ground(q+Vector2(0,s))-moments._ground(q-Vector2(0,s))
	return Vector2(dx,dz).length()/(2.0*s)

static func _open_view(from: Vector2, toward: Vector2, trunks: PackedVector2Array) -> bool:
	for t in trunks:
		var d := t-from
		var along := d.dot(toward)
		if along > 0.2 and along < OPEN_REACH and absf(d.cross(toward)) < OPEN_WIDTH: return false
	return true

static func _clearance(q: Vector2, trunks: PackedVector2Array) -> float:
	var best := INF
	for t in trunks: best = minf(best,q.distance_squared_to(t))
	return sqrt(best)

func _trunks() -> PackedVector2Array:
	var result := PackedVector2Array()
	for item: Dictionary in life.data.objects:
		if str(item.get("asset","")) in Survey.TREES: result.append(Vector2(float(item.x),float(item.z)))
	return result

## The camera in plate metres.
func _eye() -> Vector3:
	var camera: Camera3D = life.scene.camera
	return life.to_local(camera.global_position)

## How far off centre `point` (plate metres) sits on screen, 0 centre to 1
## at the margin; -1 when it is off screen or behind the camera.
func _on_screen(point: Vector3) -> float:
	var camera: Camera3D = life.scene.camera
	var world := life.to_global(point)
	if camera.is_position_behind(world): return -1.0
	var size := camera.get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0: return -1.0
	var at := camera.unproject_position(world)/size*2.0-Vector2.ONE
	var reach := maxf(absf(at.x),absf(at.y))/(1.0-SCREEN_MARGIN)
	return reach if reach <= 1.0 else -1.0

# --- Staging --------------------------------------------------------------------

func _start(kind: String, edge: Dictionary, beats: Array) -> void:
	state = {"kind":kind,"edge":edge.p,"into":edge.into,"beats":beats,"i":-1,"t":0.0,"age":0.0,"p":Vector2.ZERO,"yaw":0.0,"size":0.0,"left":"","clip":""}
	var first: Dictionary = beats[0]
	var path: PackedVector2Array = first.path
	state.p = path[0]
	state.yaw = _heading(path,0.0)
	_camera_distance = -1.0
	_approach = 0.0
	visible = true
	_next_beat(0.0)
	_place()

func _next_beat(leftover: float) -> void:
	state.i = int(state.i)+1
	state.t = leftover
	if int(state.i) >= (state.beats as Array).size():
		hide_now()
		return
	var beat: Dictionary = state.beats[state.i]
	state.clip = beat.clip
	player.play(beat.clip,float(beat.blend))
	player.advance(leftover)

## Leave now, into the trees at a stride. `why` is kept for probes.
func leave(why: String) -> void:
	if state.is_empty() or state.left != "": return
	state.left = why
	var p: Vector2 = state.p
	var into: Vector2 = state.into
	var path := _line(p,p+into*3.4)
	state.beats = [{"clip":"Stride","length":_length(path)/stride_speed,"path":path,"speed":stride_speed,"blend":0.35,"fade":"out"}]
	state.i = -1
	_next_beat(0.0)

func advance(step: float, real_step: float) -> void:
	if state.is_empty(): return
	var began := Time.get_ticks_usec()
	state.age = float(state.age)+step
	state.t = float(state.t)+step
	var beat: Dictionary = state.beats[state.i]
	if float(state.t) >= float(beat.length):
		_next_beat(float(state.t)-float(beat.length))
		if state.is_empty():
			last_usec = Time.get_ticks_usec()-began
			return
		beat = state.beats[state.i]
	else:
		player.advance(step)
	var t: float = state.t
	if beat.has("path"):
		var path: PackedVector2Array = beat.path
		var travel := float(beat.get("travel",0.0))+t*float(beat.speed)
		state.p = _along(path,travel)
		state.yaw = lerp_angle(float(state.yaw),_heading(path,travel),minf(1.0,step*5.0))
	else:
		state.yaw = lerp_angle(float(state.yaw),float(beat.face),minf(1.0,step*1.6))
	# He grows out of the trees as he appears and shrinks back into them.
	var size := smoothstep(0.0,FADE,float(state.age))
	if str(beat.get("fade","")) == "out": size *= smoothstep(0.0,FADE,float(beat.length)-t)
	state.size = size
	_place()
	_watch_camera(real_step)
	last_usec = Time.get_ticks_usec()-began

func _place() -> void:
	var p: Vector2 = state.p
	position = Vector3(p.x,moments._ground(p),p.y)
	rotation = Vector3(0,float(state.yaw),0)
	scale = Vector3.ONE*maxf(float(state.size),0.001)
	var glow := EYE_GLOW*(1.0-smoothstep(0.03,0.28,life._daylight()))
	if absf(glow-_glow) > 0.004:
		_glow = glow
		_eyes.set_shader_parameter("emissive_color",Vector3(EYE_COLOR.r,EYE_COLOR.g,EYE_COLOR.b)*glow)

## Shy of a camera that comes too close or too fast.
func _watch_camera(real_step: float) -> void:
	if state.left != "" or not shy: return
	var eye := _eye()
	var distance := Vector2(eye.x-position.x,eye.z-position.z).length()
	if _camera_distance >= 0.0 and real_step > 0.0:
		var rate := (_camera_distance-distance)/real_step
		_approach = lerpf(_approach,rate,minf(1.0,real_step*6.0))
	_camera_distance = distance
	if distance < SHY_NEAR: leave("camera near")
	elif distance < SHY_WATCH and _approach > SHY_APPROACH: leave("camera closing")

## A stroke at `point` (plate metres): too close and he goes.
func stroke(point: Vector3) -> void:
	if state.is_empty(): return
	if Vector2(point.x-position.x,point.z-position.z).length() < SHY_PAINT: leave("painting near")

## A bone's head height above the soles in the rest pose.
func _sole(index: int) -> float:
	return (skeleton.global_transform*skeleton.get_bone_global_rest(index).origin).y-skeleton.global_position.y if scale.y > 0.99 else 0.0

static func _along(path: PackedVector2Array, distance: float) -> Vector2:
	for i in range(1,path.size()):
		var piece := path[i-1].distance_to(path[i])
		if distance <= piece or i == path.size()-1:
			return path[i-1].lerp(path[i],clampf(distance/maxf(piece,0.0001),0.0,1.0))
		distance -= piece
	return path[path.size()-1]

static func _heading(path: PackedVector2Array, distance: float) -> float:
	var a := _along(path,distance)
	var b := _along(path,distance+0.3)
	if b.distance_to(a) < 0.01:
		a = _along(path,maxf(0.0,distance-0.3))
		b = path[path.size()-1]
	return atan2(b.x-a.x,b.y-a.y)

# --- Probes -----------------------------------------------------------------------

## Where he is and what he is doing: plate position, clip, distances to the
## edge and camera, and each foot's lowest point above the ground under it
## (bone heads less their rest height, so 0 is the sole on the ground).
func report() -> Dictionary:
	if state.is_empty(): return {}
	var p: Vector2 = state.p
	var eye := _eye()
	var feet := {}
	for side in ["L","R"]:
		var lowest := INF
		for bone in ["Foot_","Toes_"]:
			var index := skeleton.find_bone(bone+side)
			if index < 0: continue
			var at := life.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(index).origin)
			lowest = minf(lowest,at.y-moments._ground(Vector2(at.x,at.z))-_sole(index))
		feet[side] = snappedf(lowest,0.001)
	return {"kind":state.kind,"clip":player.current_animation,"clip_t":snappedf(player.current_animation_position,0.01),"beat":state.i,"age":snappedf(float(state.age),0.01),
		"p":[snappedf(p.x,0.01),snappedf(position.y,0.01),snappedf(p.y,0.01)],"size":snappedf(float(state.size),0.01),
		"edge_m":snappedf(p.distance_to(state.edge),0.01),"outside_m":snappedf(-(p-(state.edge as Vector2)).dot(state.into),0.01),
		"camera_m":snappedf(Vector2(eye.x,eye.z).distance_to(p),0.1),"on_screen":snappedf(_on_screen(position+Vector3.UP*1.4),0.01),
		"wet":life.survey.wet_at(p) if life.survey != null else false,"slope":snappedf(_slope(p),0.01),"feet":feet,"left":state.left,"eye_glow":snappedf(_glow,0.01)}
