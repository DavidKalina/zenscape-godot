extends Node3D
## The burrower in a sunk tunnel (docs/design/endless-flight/spec-burrower-chase.md):
## what happens after `plunge`. He is never drawn. Where he is: `s`, the distance along
## the path, and BoreLine `angle_at(s)`, the angle round the bore there. What shows is a
## ridge of heaved rock on the bore's real surface, winding round the tube ahead of the
## plane, the spurs he leaves behind him (scripts/endless/bore_spurs.gd) and the plume he
## leaves the far mouth in (scripts/endless/bore_plume.gd). A rumble says where he is
## round the tube (`_feel`). A placeholder sound: the stone grind, pitched down.
##
## The ridge is laid out ahead of him in rows (`_lay`, a few a frame), joined into pooled
## chunks that never change again: `shaders/burrower_bore_ridge.gdshader` raises each row
## from how far he's past it, so a frame only sets `head_s`. Nothing touches the bore's
## own mesh or collision.
##
## His pace (`_pace`): PACE, what a plane on Boost holds through the spurs, under its level
## best, so a clean line closes on him and a scrappy one falls back. Crowded inside LEAD.x
## he pulls away by CROWD_GAIN, so he settles at LEAD.x and anything faster closes on him
## (a surge). Past LEAD.y he eases off and lets the plane come. A scrape costs the plane
## speed and he stretches away by that alone.

## Ended: `why` is "out" (the far mouth), "left" (the plane didn't follow him in),
## "lost" (the plane fell back or left the bore) or "down" (a landing or a crash, which
## flies on as a new plane: the study's `crash`, so any plane but this chase's ends it).
signal ended(why: StringName)

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const BoreLine = preload("res://scripts/endless/bore_line.gd")
const BoreSpurs = preload("res://scripts/endless/bore_spurs.gd")
const BorePlugs = preload("res://scripts/endless/bore_plug.gd")
const BorePlume = preload("res://scripts/endless/bore_plume.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const RIDGE_SHADER = preload("res://shaders/burrower_bore_ridge.gdshader")

## How far ahead of the plane he runs (m along the bore): about 2 s at speed.
const LEAD := Vector2(90.0,150.0)
## The plane on Boost through the spurs (m/s; 57.7 level and straight, 52-55 weaving), and
## how fast he can go (m/s).
const PACE := 54.0
const PACE_MOST := 95.0
const PACE_LEAST := 20.0
## Crowded: m/s more for each m inside LEAD.x. Left behind: m/s less for each m past
## LEAD.y. His acceleration (m/s/s).
const CROWD_GAIN := 0.6
const WAIT_GAIN := 0.5
const ACCEL := 35.0
## Gone: the plane this far behind him (m), or this long out of the bore after following
## him in. It has this long (s) from `begin` to follow him in at all.
const LOST_M := 300.0
const OUT_S := 3.0
const FOLLOW_S := 5.0

## The rows: every ROW_M m (the rock's rings are 2 m), ACROSS points HALF_W m each side
## of his line, CHUNK rows to a mesh.
const ROW_M := 2.0
const ACROSS := 9
const HALF_W := 3.2
const CHUNK := 24
## Laid out to REACH_M m past his head, at most ROWS_A_FRAME rows a frame.
const REACH_M := 200.0
const ROWS_A_FRAME := 3
## Rows behind the plane by this much (m) are done with.
const PAST_M := 60.0
## The bow rises this far ahead of him (m; the shader's `bow`).
const BOW_M := 18.0
## The ridge sinks back this long (s) after the chase ends.
const SINK_S := 4.0
## The glow he throws on the rock round his head.
const GLOW_RANGE := 34.0
const GLOW_ENERGY := 5.0
const GLOW_TINT := Color(1.0,0.62,0.36)

## The rumble: it plays from his angle round the bore but RUMBLE_AHEAD m ahead of the plane,
## since from his real 90-150 m a tube's width is a few degrees and the pan wouldn't move.
## Its gain with him at LEAD.x and at LOST_M, for a plane that hasn't followed him in, and
## its pitch at PACE_LEAST and PACE_MOST.
const RUMBLE_CLIP := "res://assets/audio/kit/stone-grind-loop.wav"
const RUMBLE_AHEAD := 14.0
const RUMBLE_GAIN := Vector2(0.6,0.2)
const RUMBLE_OUTSIDE := 0.5
const RUMBLE_PITCH := Vector2(0.45,0.75)
## The sounds of the plume: the blast and what comes down after it. Heard anywhere.
const PLUME_GAIN := 1.0
const PLUME_PITCH := 0.6

## This chase's tunnel (null: no chase), the way he's going along it (1 from mouth A), his
## distance along it, his pace, how far he leads the plane.
var site: Tunnels.Site
var way := 1.0
var s := 0.0
var pace := 0.0
var lead := 0.0
var _plane: RefCounted
var _followed := false
var _wait := 0.0
var _out := 0.0
var _grain: FastNoiseLite
## The next row, the rows not yet in a mesh (their arrays), the rows' centres by index.
var _row := 0
var _rows := 0
var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _box := AABB()
var _centres := PackedVector3Array()
## The chunks in use, oldest first ({node, far (the distance along its far end)}), spares.
var _chunks: Array = []
var _spare: Array[MeshInstance3D] = []
var _index := PackedInt32Array()
var _mat: ShaderMaterial
var _glow: OmniLight3D
## The spurs, tunnel by tunnel, and the plume.
var spurs: BoreSpurs
var plugs: BorePlugs
var plume: BorePlume
## The rumble's voice (FlightSound Bed) and where it plays from now.
var rumble_at := Vector3.ZERO
var _rumble: RefCounted
var _rng := RandomNumberGenerator.new()
## After the chase: the sink's time left.
var _sinking := 0.0
var _time := 0.0
## For drivers: the row-laying's worst frame (us), this chase's ending.
var stats := {"worst_us": 0, "rows": 0, "why": ""}

func _init() -> void:
	name = "BurrowerBore"
	top_level = true

func setup(tunnels: Node3D) -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = RIDGE_SHADER
	_mat.set_shader_parameter("bow",BOW_M)
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.omni_range = GLOW_RANGE
	_glow.light_energy = GLOW_ENERGY
	_glow.light_color = GLOW_TINT
	_glow.light_cull_mask = LandTunnels.UNDER_LAYER
	_glow.shadow_enabled = false
	_glow.light_specular = 0.2
	_glow.visible = false
	add_child(_glow)
	_index = _strip_index()
	spurs = BoreSpurs.new()
	add_child(spurs)
	spurs.setup(tunnels)
	plugs = BorePlugs.new()
	add_child(plugs)
	plugs.setup(tunnels,spurs.tell(),spurs.rubble())
	plume = BorePlume.new()
	add_child(plume)
	plume.setup()

## The chase is on.
func running() -> bool:
	return site != null

## Nothing left of the last chase to do.
func settled() -> bool:
	return site == null and _sinking <= 0.0

## He's in, at mouth `end` (0: the path's start) of `t`, with `plane` after him.
func begin(t: Tunnels.Site, end: int, plane: RefCounted) -> void:
	_clear()
	site = t
	_plane = plane
	way = 1.0 if end == 0 else -1.0
	s = 0.0 if end == 0 else t.length
	pace = PACE
	lead = 0.0
	_followed = false
	_wait = FOLLOW_S
	_out = 0.0
	_sinking = 0.0
	_grain = LandTunnels.rock_grain(t)
	_rng.seed = hash([t.seed,"bore ridge"])
	_row = 0
	_rows = int(t.length/ROW_M)+1
	_time = 0.0
	stats = {"worst_us": 0, "rows": 0, "why": ""}
	_mat.set_shader_parameter("way",way)
	_mat.set_shader_parameter("sink",0.0)
	_mat.set_shader_parameter("head_s",s)
	_lay(ROWS_A_FRAME)
	spurs.begin(t,way)
	plugs.begin(t,way)

## One frame.
func step(delta: float, game: Node3D) -> void:
	_time += delta
	spurs.step(delta,game.plane.position,game.sound)
	plugs.step(delta,game.plane.position,game.sound)
	plume.step(delta)
	if _sinking > 0.0: _sink(delta)
	if site == null: return
	_mat.set_shader_parameter("now",_time)
	var p: Vector3 = game.plane.position
	var plane_s := Tunnels.local(site,p.x,p.z).x
	lead = (s-plane_s)*way
	var why := _gone(delta,game,p)
	if why != &"":
		finish(why)
		return
	_pace(delta,game,plane_s)
	s += pace*delta*way
	if (s-(site.length if way > 0.0 else 0.0))*way >= 0.0:
		_leave(game)
		return
	var began := Time.get_ticks_usec()
	_lay(ROWS_A_FRAME)
	spurs.passing(s)
	plugs.passing(s)
	stats.worst_us = maxi(int(stats.worst_us),Time.get_ticks_usec()-began)
	_mat.set_shader_parameter("head_s",s)
	_drop_past(plane_s)
	_place_glow()
	_feel(game,plane_s)

## Why the chase is over now, or "".
func _gone(delta: float, game: Node3D, p: Vector3) -> StringName:
	if game.plane != _plane or not game.hand_landing.flying(): return &"down"
	var b := Tunnels.bore_at(site,p.x,p.z)
	var inside := not is_nan(b.x) and p.y < b.y+2.0
	if inside:
		_followed = true
		_out = 0.0
	elif not _followed:
		_wait -= delta
		if _wait <= 0.0: return &"left"
	else:
		_out += delta
		if _out > OUT_S: return &"lost"
	if _followed and lead > LOST_M: return &"lost"
	return &""

## He's out of the far mouth: the plume, and the chase is over.
func _leave(game: Node3D) -> void:
	plume.burst(site,1 if way > 0.0 else 0)
	var at: Vector3 = plume.stats.at
	game.sound.shot("crash",PLUME_GAIN,PLUME_PITCH,at,FlightSound.SFX,true)
	game.sound.shot("debris",PLUME_GAIN,PLUME_PITCH,at,FlightSound.SFX,true)
	finish(&"out")

## The rumble, from where he is round the tube (the constants').
func _feel(game: Node3D, plane_s: float) -> void:
	if _rumble == null: _rumble = game.sound.bed_in_world(RUMBLE_CLIP)
	rumble_at = BoreLine.about(site,clampf(plane_s+way*RUMBLE_AHEAD,0.0,site.length),BoreLine.angle_at(site,s))
	if _rumble.player != null: _rumble.player.global_position = rumble_at
	var gain := remap(clampf(lead,LEAD.x,LOST_M),LEAD.x,LOST_M,RUMBLE_GAIN.x,RUMBLE_GAIN.y)
	_rumble.goal = gain*(1.0 if _followed else RUMBLE_OUTSIDE)
	_rumble.pitch_goal = remap(pace,PACE_LEAST,PACE_MOST,RUMBLE_PITCH.x,RUMBLE_PITCH.y)

## His pace for now (the header).
func _pace(delta: float, game: Node3D, plane_s: float) -> void:
	var v: Vector3 = game.plane.velocity
	var along := Vector2(v.x,v.z).dot(Tunnels.at_s(site,plane_s)[1] as Vector2)*way
	var want := PACE
	if lead < LEAD.x: want = PACE+(LEAD.x-lead)*CROWD_GAIN
	elif lead > LEAD.y: want = along-(lead-LEAD.y)*WAIT_GAIN
	pace = move_toward(pace,clampf(want,PACE_LEAST,PACE_MOST),ACCEL*delta)

## The chase is over: the ridge stops where he left it and sinks back.
func finish(why: StringName) -> void:
	if site == null: return
	site = null
	_plane = null
	spurs.ended()
	plugs.ended()
	_glow.visible = false
	if _rumble != null: _rumble.goal = 0.0
	stats.why = why
	_sinking = SINK_S
	ended.emit(why)

func _sink(delta: float) -> void:
	_sinking -= delta
	_mat.set_shader_parameter("sink",1.0-clampf(_sinking/SINK_S,0.0,1.0))
	if _sinking <= 0.0: _clear()

## Everything back in the pool.
func _clear() -> void:
	for c: Dictionary in _chunks:
		var node: MeshInstance3D = c.node
		node.visible = false
		_spare.append(node)
	_chunks.clear()
	_verts.clear()
	_normals.clear()
	_uv.clear()
	_uv2.clear()
	_centres.clear()
	_sinking = 0.0

## The distance along the path of row `i`, from his mouth.
func _row_s(i: int) -> float:
	return float(i)*ROW_M if way > 0.0 else site.length-float(i)*ROW_M

## Up to `most` more rows, as far as REACH_M past him.
func _lay(most: int) -> void:
	for i in most:
		if _row >= _rows or (_row_s(_row)-s)*way > REACH_M: return
		_lay_row(_row_s(_row))
		_row += 1
		stats.rows = _row
		if _verts.size() >= CHUNK*ACROSS or _row >= _rows: _join()

## One row of the ridge at distance `at`: on the rock, across his line. The rock's ring
## is walked by metres from the angle's point, ACROSS points over HALF_W each side.
func _lay_row(at: float) -> void:
	var ring := BoreLine.ring(site,_grain,at)
	var metres := BoreLine.round_m(ring)
	var u0 := fposmod(BoreLine.angle_at(site,at)/TAU,1.0)*metres[metres.size()-1]
	var centre := BoreLine.on_ring(ring,metres,u0)
	var up := (BoreLine.middle(site,at)-centre).normalized()
	if _centres.is_empty(): _box = AABB(centre,Vector3.ZERO)
	for j in ACROSS:
		var u := -1.0+2.0*j/(ACROSS-1)
		var v := BoreLine.on_ring(ring,metres,u0+u*HALF_W)
		# A shaft's opening has no rock to heave.
		var whole := 0.0 if Tunnels.shaft_at(site,v.x,v.z,Tunnels.SHAFT_R-LandTunnels.SHAFT_CUT) >= 0 else 1.0
		_verts.append(v)
		_normals.append(up)
		_uv.append(Vector2(u,at))
		_uv2.append(Vector2(whole,_rng.randf()))
		_box = _box.expand(v)
	_centres.append(centre)

## The rows so far into a chunk; its last row starts the next.
func _join() -> void:
	var rows := _verts.size()/ACROSS
	if rows < 2: return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_INDEX] = _index.slice(0,(rows-1)*(ACROSS-1)*6)
	var node := _take()
	var mesh: ArrayMesh = node.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = _box.grow(HALF_W)
	node.visible = true
	_chunks.append({"node": node, "far": _uv[_uv.size()-1].y})
	var keep := _verts.size()-ACROSS
	_verts = _verts.slice(keep)
	_normals = _normals.slice(keep)
	_uv = _uv.slice(keep)
	_uv2 = _uv2.slice(keep)
	_box = AABB(_verts[0],Vector3.ZERO)
	for v: Vector3 in _verts: _box = _box.expand(v)

## A chunk's node from the pool.
func _take() -> MeshInstance3D:
	if not _spare.is_empty(): return _spare.pop_back()
	var node := MeshInstance3D.new()
	node.mesh = ArrayMesh.new()
	node.material_override = _mat
	node.layers = LandTunnels.UNDER_LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

## Chunks wholly behind the plane back in the pool.
func _drop_past(plane_s: float) -> void:
	while not _chunks.is_empty() and (plane_s-float(_chunks[0].far))*way > PAST_M:
		var node: MeshInstance3D = (_chunks.pop_front() as Dictionary).node
		node.visible = false
		_spare.append(node)

## His head's glow on the rock, off the ridge toward the bore's middle.
func _place_glow() -> void:
	var f := absf(s-_row_s(0))/ROW_M
	var i := int(f)
	if i+1 >= _centres.size():
		_glow.visible = false
		return
	var at := _centres[i].lerp(_centres[i+1],f-i)
	var c: Vector2 = Tunnels.at_s(site,s)[0]
	var mid := Vector3(c.x,Tunnels.floor_at(site,s)+Tunnels.profile(site,s).z*BoreLine.MIDDLE,c.y)
	_glow.position = at.lerp(mid,0.18)
	_glow.visible = true

## His head (world).
func head() -> Vector3:
	return _glow.position

## The strip's triangles for the most rows a chunk holds.
func _strip_index() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize((CHUNK-1)*(ACROSS-1)*6)
	var n := 0
	for r in CHUNK-1:
		for c in ACROSS-1:
			var a := r*ACROSS+c
			var b := a+ACROSS
			for i: int in [a,b,a+1,a+1,b,b+1]:
				out[n] = i
				n += 1
	return out
