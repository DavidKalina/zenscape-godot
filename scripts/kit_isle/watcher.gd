extends Node3D
## The watcher (a study, docs/design/watcher/round1.md; `--watcher`, off by
## default): a stranger on the aqueduct isle's south rim, a few steps west
## of where the plane stands parked, his telescope up, slowly following
## something far off. Follow his gaze with your own telescope (scripts/
## telescope.gd) and you find it: a glint on the sky folk's ferry's
## foredeck as it shuttles round its isles (scripts/kit_isle/
## airship_ferry.gd; on the rune serpent's back where --serpent flies it).
## Board it and touch the glint to take it. The question: does following
## his gaze lead you to the find, with no text pointing and no aim help?
##
## - **He** is the pilot's own body (scripts/pilot_figure.gd, assets/models/
##   pilot.glb) in his own colours (PALETTE: a teal cap, an olive coat, a
##   mustard scarf), so he reads as a stranger, not a double. He plays the
##   idle; over it his arms lift the brass spyglass to his eye the way the
##   pilot's do (scripts/telescope.gd `make_glass`, `lift_arms`, `hold`),
##   its sections sliding out as it comes up and in as it comes down, with
##   the same swish and click heard near him; his chest and head tilt by
##   the gaze's pitch, and his whole body turns, on an ease (TRACK_EASE),
##   to face the find. Every WATCH_TIME s or so he lowers it a while
##   (REST s) and, if the pilot is within GLANCE_NEAR m, glances at him,
##   then raises it and looks back. When the find is out of his sight
##   (behind the hill or an isle) he lowers it and waits, still turned to
##   it if it's near, else to where its carrier comes home.
## - **Where he stands:** from the isle's own ground, never moving it: a ray
##   march from STAND_FROM south over the turf to the rim's edge, and back
##   STAND_BACK m from it. A column on the parked plane's layer keeps the
##   pilot from walking through him.
## - **The find:** the host's, if it has one (`watched_find`): on the
##   aqueduct isle, the plane's tail fin on the ferry's foredeck
##   (scripts/plane_arc/plane_arc.gd, which places it, makes it glint and
##   takes it; docs/design/plane-arc/round1.md). On foot within TAKE m of it
##   he takes it, and once it's gone (taken now or in an earlier run) the
##   watcher is done. A host with no find of its own gets the old one: a
##   rune token riding RIDE_ARC m back from the serpent's snout, FIND_LIFT m
##   over its back's crest, put with `Telescope.spottable(find)` (no
##   objective: it glints until taken), so it glints only through the
##   telescope; taken, a moments pop, nothing in the ledger.
## - **His line:** within LINE_NEAR m he lowers it, looks at you and a
##   line streams in at the screen's foot (LINE_RATE characters a second),
##   without pausing anything; walk off past LINE_FAR m and it fades.
##
## The host (studies/aqueduct_isle.gd) makes it in `_add_life` when `wanted`.
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Telescope = preload("res://scripts/telescope.gd")
const RuneToken = preload("res://scripts/rune_token.gd")
const HudIcons = preload("res://scripts/hud_icons.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## His paint over the pilot's (scripts/pilot_paint.gd's surface names).
const PALETTE := {
	"pilot_cap": Color("2f5f63"),
	"pilot_jacket": Color("6f7a45"),
	"pilot_hem": Color("4b5430"),
	"pilot_scarf": Color("d6a63a"),
	"pilot_trousers": Color("5b4636"),
	"pilot_mitt": Color("3f3a33"),
}
## Where the march to the rim starts (x, z: west of the parked plane, on
## the turf) and its step; how much the turf may rise or fall a step and
## still be the same terrace; how far back from the edge he stands (m).
const STAND_FROM := Vector2(94.0,4.0)
const STAND_STEP := 0.5
const STAND_RISE := 1.0
const STAND_BACK := 1.6
## His eyes over his feet (m, at size 1), as Telescope.EYE.
const EYE := 0.95
## Seconds his body takes to come round to the gaze (an ease), the
## spyglass up or down; how much of the gaze's pitch his chest takes, the rest his head.
const TRACK_EASE := 0.6
const RAISE := 0.45
const CHEST_PITCH := 0.45
## Watching (s, least and most) between rests, and a rest's length.
const WATCH_TIME := Vector2(7.0,13.0)
const REST := 2.4
## A glance: the pilot within this (m); the head takes up to GLANCE_HEAD
## rad of it, the body the rest, partly.
const GLANCE_NEAR := 14.0
const GLANCE_HEAD := 0.9
## He sees the find within SEE_FAR m with nothing between (checked every
## SEE_EVERY s); out of sight HIDE_AFTER s, he waits for it.
const SEE_FAR := 1400.0
const SEE_EVERY := 0.25
const HIDE_AFTER := 1.5
## Where he waits facing: toward the find while it's within WAIT_NEAR m
## (the ferry resting at home, say), else its carrier's way RETURN_LEAD m
## before home: the serpent's, where it comes out from behind the hill; the
## ferry's, where it comes down to the south edge from the east.
const WAIT_NEAR := 300.0
const RETURN_LEAD := 220.0
## The find: m back from the snout along its body, m over its back's crest,
## its size (m) and spin (rad/s); taken within TAKE m of his middle.
const RIDE_ARC := 45.0
const FIND_LIFT := 0.7
const FIND_SIZE := 0.7
const FIND_SPIN := 1.2
const TAKE := 1.6
## His line: said within LINE_NEAR m, once a LINE_AGAIN s; characters a
## second; held after it's all in (s); fades past LINE_FAR m, over LINE_FADE s.
const LINE := "Something's caught on the old snake's back."
const FERRY_LINE := "Something's glinting on the ferry's deck."
const LINE_NEAR := 4.0
const LINE_AGAIN := 45.0
const LINE_RATE := 32.0
const LINE_HOLD := 3.0
const LINE_FAR := 8.0
const LINE_FADE := 0.4
## The parked plane's layer (studies/kit_isle.gd PARKED_LAYER): only the
## walker and his ground probes see it.
const COLUMN_LAYER := 1 << 13

var isle: Node3D
var serpent: Node3D
## The ferry (scripts/kit_isle/airship_ferry.gd) the host's find rides, or null.
var ferry: Node3D
var body: Node3D
var glass: Node3D
var find: Node3D
var size := 1.0
## "watch" (up, tracking), "rest" (down a while, glancing), "wait" (down,
## the serpent out of sight), "done" (the find taken).
var state := "watch"
## How far up the spyglass is (0 down, 1 at his eyes), his facing and gaze pitch.
var up := 0.0
var facing := 0.0
var pitch := 0.0
## Whether he sees the find now, and since when not.
var sees := true
var taken := false
## The find is the host's (`watched_find`), not his own rune.
var borrowed := false
var _ring := -1
var _state_left := 8.0
var _unseen := 0.0
var _see_left := 0.0
var _head_yaw := 0.0
var _rng := RandomNumberGenerator.new()
var _spin: Node3D
var _line_layer: CanvasLayer
var _line: Label
var _line_t := -1.0
var _line_fade := 0.0
var _said_at := -INF
var _clock := 0.0

static func wanted() -> bool:
	return LaunchArgs.user_args().has("--watcher")

func _init() -> void:
	name = "Watcher"
	# After the serpent (-101) and its rider (-100) move, before the
	# scene's frame (0) reads the telescope's glints.
	process_priority = -50

## Him on the rim of `host` (the aqueduct isle), the find on its serpent.
func setup(host: Node3D) -> void:
	isle = host
	size = float(isle.get("wanderer_scale")) if isle.get("wanderer_scale") != null else 1.0
	_rng.seed = 9187
	_state_left = _rng.randf_range(WATCH_TIME.x,WATCH_TIME.y)
	var sky: Node3D = isle.get("sky")
	serpent = sky.get("serpent") if sky != null else null
	ferry = sky.get("ferry") if sky != null else null
	body = PilotFigure.new()
	body.name = "WatcherBody"
	body.scale = Vector3.ONE*size
	body.size = size
	add_child(body)
	for paint: ShaderMaterial in body._paints:
		if PALETTE.has(paint.resource_name): paint.set_shader_parameter("albedo",PALETTE[paint.resource_name])
	glass = Telescope.make_glass()
	add_child(glass)
	glass.top_level = true
	var column := StaticBody3D.new()
	column.name = "WatcherRoom"
	column.collision_layer = COLUMN_LAYER
	column.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.35*size
	cylinder.height = 1.6*size
	shape.shape = cylinder
	shape.position = Vector3.UP*cylinder.height*0.5
	column.add_child(shape)
	add_child(column)
	position = stand_spot()
	_build_line()
	if isle.has_method("watched_find"):
		borrowed = true
		find = isle.watched_find()
		if find == null:
			taken = true
			_set_state("done")
	elif serpent != null: _build_find()
	facing = PilotMotor.facing_of(Vector2(0.0,1.0))
	if find != null:
		_place_find()
		var to := find.global_position-eye()
		facing = PilotMotor.facing_of(Vector2(to.x,to.z))
	rotation.y = facing
	up = 1.0

## Where he stands: marched from STAND_FROM south over the turf to the
## rim's edge (rays down), STAND_BACK m back from it.
func stand_spot() -> Vector3:
	var space := isle.get_world_3d().direct_space_state
	var last: Variant = _ground(space,STAND_FROM)
	if last == null: return Vector3(STAND_FROM.x,30.0,STAND_FROM.y)
	var z := STAND_FROM.y
	for i in range(200):
		var y: Variant = _ground(space,Vector2(STAND_FROM.x,z+STAND_STEP))
		if y == null or absf(float(y)-float(last)) > STAND_RISE: break
		z += STAND_STEP
		last = y
	var at := Vector2(STAND_FROM.x,z-STAND_BACK)
	var y: Variant = _ground(space,at)
	return Vector3(at.x,float(y) if y != null else float(last),at.y)

static func _ground(space: PhysicsDirectSpaceState3D, p: Vector2) -> Variant:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,80.0,p.y),Vector3(p.x,-40.0,p.y),1|(1 << 11))
	var hit := space.intersect_ray(ray)
	return (hit.position as Vector3).y if not hit.is_empty() else null

## His eyes, in the world.
func eye() -> Vector3:
	return global_position+Vector3.UP*EYE*size

# --- The find -------------------------------------------------------------------------

func _build_find() -> void:
	find = Node3D.new()
	find.name = "SerpentFind"
	_spin = Node3D.new()
	find.add_child(_spin)
	var tint := Color(HudIcons.item("rune").tint)
	_spin.add_child(RuneToken.diamond(FIND_SIZE,tint))
	var ring := RuneToken.ring(FIND_SIZE,tint)
	_spin.add_child(ring)
	isle.add_child(find)
	Telescope.spottable(find)
	var arcs: PackedFloat32Array = serpent.stations()
	var best := INF
	for k in range(arcs.size()):
		if absf(arcs[k]-RIDE_ARC) < best:
			best = absf(arcs[k]-RIDE_ARC)
			_ring = k

## The find on the serpent's back where it is now: over the middle of its
## crest at ring `_ring`, FIND_LIFT m up off its back.
func _place_find() -> void:
	if borrowed:
		var arc: Node3D = isle.get("plane_arc")
		if arc != null: arc.place_fin()
		return
	var frame: Transform3D = serpent.ring_frame(_ring)
	var corners: Array[Vector3] = serpent.ring_corners(_ring)
	var crest := frame*((corners[0]+corners[1])*0.5)
	find.global_position = crest+frame.basis.y.normalized()*FIND_LIFT

## Taken: gone, and a pop.
func _take() -> void:
	taken = true
	if borrowed:
		# The host takes it (the fin to the pilot's side) and says so.
		var arc: Node3D = isle.get("plane_arc")
		if arc != null: arc.take("fin")
		find = null
		_set_state("done")
		return
	find.queue_free()
	find = null
	var moments: Node = isle.get("_moments")
	if moments != null:
		moments.pop("A rune, caught in the old serpent's ridges",2.6)
		moments.blip(2)
	_set_state("done")

# --- Each frame -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if isle == null or delta <= 0.0: return
	_clock += delta
	# The host's find gone from the serpent (the pilot took it): done.
	if borrowed and find != null and isle.watched_find() != find:
		find = null
		taken = true
		_set_state("done")
	if find != null:
		_place_find()
		if _spin != null: _spin.rotation.y += FIND_SPIN*delta
		_check_take()
	_see(delta)
	var pilot := _pilot()
	var near := pilot.distance_to(global_position) if pilot.is_finite() else INF
	_line_frame(delta,near)
	_states(delta,near)
	_turn(delta,pilot,near)
	_draw_pose(delta)

## The pilot's feet, or INF while he flies.
func _pilot() -> Vector3:
	if bool(isle.get("flying")) or isle.get("motor") == null: return Vector3.INF
	return isle.motor.feet

func _check_take() -> void:
	var at := _pilot()
	if not at.is_finite(): return
	if (at+Vector3.UP*0.5*size).distance_to(find.global_position) < TAKE: _take()

## Whether he sees the find (a ray, every SEE_EVERY s), and how long not.
func _see(delta: float) -> void:
	if find == null:
		sees = false
		return
	_see_left -= delta
	if _see_left <= 0.0:
		_see_left = SEE_EVERY
		var from := eye()
		var at := find.global_position
		var far := from.distance_to(at)
		sees = far < SEE_FAR
		if sees:
			var ray := PhysicsRayQueryParameters3D.create(from,from.move_toward(at,far-2.0))
			var past: Array[RID] = []
			if serpent != null and serpent.has_method("solid_rid"): past.append(serpent.solid_rid())
			if ferry != null: past.append(ferry.body.get_rid())
			ray.exclude = past
			sees = isle.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	_unseen = 0.0 if sees else _unseen+delta

func _set_state(next: String) -> void:
	state = next
	if next == "watch": _state_left = _rng.randf_range(WATCH_TIME.x,WATCH_TIME.y)
	elif next == "rest": _state_left = REST

func _states(delta: float, near: float) -> void:
	_state_left -= delta
	var speaking := _line_t >= 0.0
	match state:
		"watch":
			if _unseen > HIDE_AFTER: _set_state("wait")
			elif speaking or _state_left <= 0.0: _set_state("rest")
		"rest":
			if speaking: _state_left = maxf(_state_left,0.6)
			elif _state_left <= 0.0: _set_state("watch" if _unseen <= HIDE_AFTER else "wait")
		"wait":
			if sees: _set_state("watch")
	var raised := state == "watch"
	var was := Telescope.extension(up)
	up = move_toward(up,1.0 if raised else 0.0,delta/RAISE)
	_slide_sounds(was,Telescope.extension(up))

## His body and head round to the gaze: the find while watching, the way it
## comes home while waiting, the pilot (partly) in a glance.
func _turn(delta: float, pilot: Vector3, near: float) -> void:
	var target := Vector3.INF
	if find != null and (state != "wait" or eye().distance_to(find.global_position) < WAIT_NEAR): target = find.global_position
	elif state != "done" and borrowed and ferry != null:
		target = ferry.point(float(ferry.stop("home").get("arc",0.0))-RETURN_LEAD)
	elif serpent != null and state != "done":
		var home := float(serpent.marks().get("home",0.0))
		target = serpent.route_point(fposmod(home-RETURN_LEAD,float(serpent.route_length)))
	var want_facing := facing
	var want_pitch := 0.0
	if target.is_finite():
		var to := target-eye()
		want_facing = PilotMotor.facing_of(Vector2(to.x,to.z))
		want_pitch = atan2(to.y,Vector2(to.x,to.z).length())
	if state == "wait": want_pitch = 0.0
	var head := 0.0
	if (state == "rest" or state == "done" or _line_t >= 0.0) and near < GLANCE_NEAR:
		var to := pilot+Vector3.UP*EYE*size-eye()
		var at := PilotMotor.facing_of(Vector2(to.x,to.z))
		var off := angle_difference(want_facing,at)
		head = clampf(off,-GLANCE_HEAD,GLANCE_HEAD)
		want_facing += off-head
		want_pitch = atan2(to.y,Vector2(to.x,to.z).length())
	var ease := 1.0-exp(-delta/TRACK_EASE)
	facing = lerp_angle(facing,want_facing,ease)
	pitch = lerpf(pitch,clampf(want_pitch,-0.9,0.9),ease)
	_head_yaw = lerpf(_head_yaw,head,1.0-exp(-delta/0.25))
	rotation.y = facing

## The idle, then the gaze's tilt, the head's glance and the spyglass raised.
func _draw_pose(delta: float) -> void:
	body._advance(delta)
	if body._chest < 0 or body._head < 0: return
	body._turn_bone(body._chest,Vector3.RIGHT,pitch*CHEST_PITCH)
	body._turn_bone(body._head,Vector3.RIGHT,pitch*(1.0-CHEST_PITCH))
	body._turn_bone(body._head,Vector3.UP,_head_yaw)
	var amount := smoothstep(0.0,0.7,up)
	glass.visible = amount > 0.05
	if amount <= 0.0 or not Telescope.lift_arms(body,amount): return
	var f := PilotMotor.forward(facing)
	Telescope.hold(glass,body,Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch)),size)
	Telescope.extend(glass,Telescope.extension(up))

## The spyglass's swish as it starts out or in, its click as it locks out
## or shuts (from `was` to `out` of its extension), heard where he stands.
func _slide_sounds(was: float, out: float) -> void:
	var audio: Node = isle.get("audio") if isle != null else null
	if audio == null or not audio.has_method("shot") or was == out: return
	var at := eye()
	if out > was and was <= 0.0: audio.shot("swish",0.05,1.7,at)
	elif out < was and was >= 1.0: audio.shot("swish",0.04,1.5,at)
	if out >= 1.0: audio.shot("tick",0.22,0.75,at)
	elif out <= 0.0: audio.shot("tick",0.14,0.9,at)

## Which way he looks now (unit, world): the body's facing and the gaze's pitch.
func gaze() -> Vector3:
	var f := PilotMotor.forward(facing)
	return Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))

# --- His line -------------------------------------------------------------------------

func _build_line() -> void:
	_line_layer = CanvasLayer.new()
	_line_layer.name = "WatcherLine"
	_line_layer.layer = 2
	add_child(_line_layer)
	_line = Label.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_line.offset_left = -600.0
	_line.offset_right = 600.0
	_line.offset_top = -150.0
	_line.offset_bottom = -110.0
	_line.add_theme_font_size_override("font_size",26)
	_line.add_theme_color_override("font_color",Color(1.0,0.97,0.9))
	_line.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.75))
	_line.add_theme_constant_override("outline_size",6)
	_line.text = FERRY_LINE if ferry != null and isle.has_method("watched_find") else LINE
	_line.visible = false
	_line_layer.add_child(_line)

## Said within LINE_NEAR m (not since LINE_AGAIN s, nor once the find is
## taken), streamed in, held, faded; walked off past LINE_FAR, faded early.
func _line_frame(delta: float, near: float) -> void:
	if _line_t < 0.0:
		if not taken and near < LINE_NEAR and _clock-_said_at > LINE_AGAIN:
			_line_t = 0.0
			_line_fade = 0.0
			_said_at = _clock
			_line.visible = true
			_line.modulate.a = 1.0
		return
	_line_t += delta
	_line.visible_characters = int(_line_t*LINE_RATE)
	var done := float(_line.text.length())/LINE_RATE+LINE_HOLD
	if near > LINE_FAR or _line_t > done: _line_fade += delta/LINE_FADE
	_line.modulate.a = 1.0-clampf(_line_fade,0.0,1.0)
	if _line_fade >= 1.0:
		_line_t = -1.0
		_line.visible = false

## Whether his line shows now (tests).
func speaking() -> bool:
	return _line_t >= 0.0
