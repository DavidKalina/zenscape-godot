extends Node3D
## The rune knight's mind (a greybox enemy, docs/design/rune-knight/
## spec-rune-knight.md; `--rune-knight` on the aqueduct isle, off by
## default): a stone knight KNOBS.tall_ratio times the wanderer's height
## (scripts/world_scale.gd `wanderer_tall`), patrolling the aqueduct's deck
## end to end.
##
## - **His body** is behind the contract's API (`play`, `beat_reached`,
##   `socket`, `set_effect`, `shape`): today the stand-in
##   (scripts/enemies/rune_knight_body_standin.gd), later a Blender body.
##   The mind touches it only through those.
## - **The patrol:** he walks the deck's line (studies/aqueduct_isle_art.gd
##   `AQ`, from the head to the snap, KNOBS.end_margin m short of each) at
##   the body's pace (`shape().pace`), playing `walk`. At an end he plays
##   `turn` and his yaw comes round in KNOBS.turn_steps chunks, one set
##   going at each `plant` beat (planted steps), then walks back.
## - **His room:** a column on the parked plane's layer (what the walker
##   sees and walks round, as scripts/kit_isle/watcher.gd's), sized by the
##   body's shape and moved with him, so you can't walk through him.
##   Someone on the deck just ahead of him holds him up: he stands (`idle`)
##   till the way is clear.
## - **Sense:** from his `eye` socket, the wanderer's chest within
##   KNOBS.sight m with nothing of stone or turf between (the deck or the
##   meadow below; looking down, past his deck's lip, KNOBS.lip). Patrolling, he notices you in front of him (within
##   KNOBS.notice_cone of his facing) or anywhere within KNOBS.near m: he
##   stops and plays `notice`, turning to you; then he tracks you (`idle`,
##   his yaw following you). Unseen KNOBS.give_up s, he turns back to his
##   patrol (planted steps) and walks on.
## - **The gather and the throw:** tracking you, faced (within
##   KNOBS.face_ok) and KNOBS.throw_gap s after his last throw, he plays
##   `gather` with `wind_gather` on: a shot (scripts/enemies/wind_shot.gd)
##   sits on `hands_mid`, growing from `grab` (where `rune_glow` comes on).
##   At `full` he plays `throw`; at `release` the shot leaves on a lob
##   that comes down through where your chest was last seen,
##   KNOBS.shot_pace m/s along the ground at most, pulled down
##   KNOBS.shot_fall, climbing KNOBS.shot_rise first; at
##   `end` he tracks again. A shot that meets you knocks you (the gust's).
##
## The host (studies/aqueduct_isle.gd) makes him in `_add_life` when
## `wanted`. His knobs are the one dictionary below so a field (enemy.gd)
## or the motif editor can adopt him later.
const WorldScale = preload("res://scripts/world_scale.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const BodyStandin = preload("res://scripts/enemies/rune_knight_body_standin.gd")

const KNOBS := {
	# His height over the wanderer's.
	"tall_ratio": 1.6,
	# The patrol's ends kept off the deck's ends (m); how many planted steps
	# make his half turn; how fast his yaw eases to each step's (rad/s).
	"end_margin": 1.6,
	"turn_steps": 3,
	"turn_rate": 2.6,
	# How near ahead (m past his room) someone on the deck holds him up.
	"blocked": 0.7,
	# Sight (m); the half angle in front he notices you in (rad); how near
	# he notices you anyway (m); unseen this long (s) he gives you up.
	"sight": 28.0,
	"notice_cone": 1.05,
	"near": 5.0,
	"give_up": 4.0,
	# Looking down at someone below, he looks past his own deck's lip (its
	# buttresses): the sight starts this far out (m) toward them.
	"lip": 5.0,
	# Faced this near (rad) he gathers; the rest from a throw's end to the
	# next gather (s).
	"face_ok": 0.3,
	"throw_gap": 2.2,
	# The lob: its pace along the ground (m/s), its pull down (m/s/s), its
	# time aloft's bounds (s), the knock's share of the gust's.
	"shot_pace": 8.0,
	"shot_fall": 9.0,
	"shot_time_min": 0.9,
	"shot_time_max": 4.0,
	# It always climbs at least this far (m) over his hands first, so a lob
	# down off the deck clears its lip.
	"shot_rise": 1.5,
	"shot_strength": 1.0,
}
## What hides you from him: stone (layer 1) and turf (layer 11).
const SIGHT_MASK := 1 | (1 << 11)
const WindShot = preload("res://scripts/enemies/wind_shot.gd")
## The parked plane's layer (studies/kit_isle.gd PARKED_LAYER): only the
## walker and his ground probes see it.
const ROOM_LAYER := 1 << 13

var isle: Node3D
var body: Node3D
var tall := 1.9
## "patrol", "turn", "held", "notice", "track", "gather", "throw" (more
## come: catch, return, stagger).
var state := "patrol"
## His yaw (he faces -Z of Basis(UP, yaw)) and the one it eases to.
var yaw := 0.0
var yaw_goal := 0.0
## The patrol's two ends (world, deck height) and which he walks to.
var ends: Array[Vector3] = []
var heading_to := 1
var _turns_left := 0
var _shape: Dictionary = {}
var _room: StaticBody3D
## The half turn's chunk (rad) and the state a turn ends in.
var _turn_step := 0.0
## Whether he sees the wanderer this frame, how long unseen (s), where his
## chest was last seen, the rest left before a gather (s), the shot in his
## hands (null none) and the count thrown.
var sees := false
var unseen := 0.0
var last_seen := Vector3.INF
var cool := 0.0
var shot: Node3D = null
var throws := 0

static func wanted() -> bool:
	return LaunchArgs.user_args().has("--rune-knight")

func _init() -> void:
	name = "RuneKnight"
	# Before his body (0), which reads where he went this frame.
	process_priority = -10

func knob(key: String) -> float:
	return float(KNOBS[key])

## Him on `host`'s aqueduct deck (the aqueduct isle), at the head end,
## facing along it.
func setup(host: Node3D) -> void:
	isle = host
	tall = WorldScale.wanderer_tall*knob("tall_ratio")
	var margin := knob("end_margin")
	ends = [Art.AQ*Vector3(Art.HEAD+margin,Art.DECK,0.0),Art.AQ*Vector3(Art.SNAP-margin,Art.DECK,0.0)]
	yaw = _yaw_to(ends[1]-ends[0])
	yaw_goal = yaw
	transform = Transform3D(Basis(Vector3.UP,yaw),ends[0])
	body = BodyStandin.new()
	add_child(body)
	body.setup(tall)
	body.beat_reached.connect(_on_beat)
	_shape = body.shape()
	_build_room()
	body.play("walk")

func _process(delta: float) -> void:
	var at := position
	_sense()
	cool = maxf(0.0,cool-delta)
	unseen = 0.0 if sees else unseen+delta
	if state in ["patrol","held","turn"] and sees and _noticeable():
		state = "notice"
		body.play("notice")
	match state:
		"patrol", "held":
			var fwd := _forward()
			var left := (ends[heading_to]-at).dot(fwd)
			if left <= 0.02:
				heading_to = 1-heading_to
				_turn_to(_yaw_to(ends[heading_to]-at))
			elif _blocked(fwd):
				if state != "held": body.play("idle")
				state = "held"
			else:
				if state != "patrol": body.play("walk")
				state = "patrol"
				at += fwd*minf(float(_shape.pace)*delta,left)
		"turn":
			pass
		"notice", "track", "gather", "throw":
			if last_seen != Vector3.INF and state != "throw":
				yaw_goal = yaw+wrapf(_yaw_to(last_seen-at)-yaw,-PI,PI)
			if state == "track":
				if unseen > knob("give_up"):
					_turn_to(_yaw_to(ends[heading_to]-at))
				elif sees and cool <= 0.0 and absf(yaw_goal-yaw) < knob("face_ok"):
					_gather()
	yaw = move_toward(yaw,yaw_goal,knob("turn_rate")*delta)
	transform = Transform3D(Basis(Vector3.UP,yaw),at)
	_room.global_transform = Transform3D(Basis.IDENTITY,at)

func _on_beat(clip: String, beat: String) -> void:
	if clip == "turn" and beat == "plant" and state == "turn":
		if _turns_left > 0: _next_turn()
		elif absf(yaw-yaw_goal) < 0.01:
			state = "patrol"
			body.play("walk")
	elif clip == "notice" and beat == "end" and state == "notice":
		state = "track"
		body.play("idle")
	elif clip == "gather" and state == "gather":
		if beat == "grab":
			body.set_effect("rune_glow",true)
			if shot != null: shot.grow()
		elif beat == "full":
			body.set_effect("wind_gather",false)
			state = "throw"
			body.play("throw")
	elif clip == "throw" and state == "throw":
		if beat == "release": _release()
		elif beat == "end":
			state = "track"
			cool = knob("throw_gap")
			body.play("idle")

## Turned to `want` (yaw) in planted steps, each at most a
## 1/KNOBS.turn_steps half turn, then walking his patrol.
func _turn_to(want: float) -> void:
	var diff := wrapf(want-yaw,-PI,PI)
	var chunks := maxi(1,ceili(absf(diff)/(PI/knob("turn_steps"))-0.01))
	_turn_step = diff/float(chunks)
	_turns_left = chunks
	yaw_goal = yaw
	state = "turn"
	body.play("turn")
	_next_turn()

## The next chunk of the turn: his yaw's goal comes round by one step.
func _next_turn() -> void:
	_turns_left -= 1
	yaw_goal += _turn_step

# --- Sense --------------------------------------------------------------------------

## The wanderer's chest, or INF when he isn't on foot.
func _target() -> Vector3:
	var motor = isle.get("motor") if isle != null else null
	if motor == null or motor.get("rider") != null: return Vector3.INF
	return (motor.feet as Vector3)+Vector3.UP*0.6*WindShot.walker_tall()

## Whether he sees the wanderer: in sight range, nothing of stone or turf
## between his eye and the chest. Sets `sees` and `last_seen`.
func _sense() -> void:
	sees = false
	var chest := _target()
	if chest == Vector3.INF or not is_inside_tree(): return
	var eye: Vector3 = body.socket("eye").global_position
	if eye.distance_to(chest) > knob("sight"): return
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = SIGHT_MASK
	ray.from = eye
	if chest.y < position.y-1.5:
		var flat := Vector3(chest.x-eye.x,0.0,chest.z-eye.z)
		ray.from = eye+flat.normalized()*minf(knob("lip"),flat.length()*0.5)
	ray.to = chest
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
	sees = true
	last_seen = chest

## Whether a patrolling knight notices what he sees: in front of him or near.
func _noticeable() -> bool:
	var off := last_seen-position
	if Vector2(off.x,off.z).length() < knob("near"): return true
	return absf(wrapf(_yaw_to(off)-yaw,-PI,PI)) < knob("notice_cone")

# --- The gather and the throw -------------------------------------------------------

func _gather() -> void:
	state = "gather"
	body.play("gather")
	body.set_effect("wind_gather",true)
	shot = WindShot.new()
	isle.add_child(shot)
	shot.shooter = self
	shot.strength = knob("shot_strength")
	shot.target = isle.get("motor")
	shot.hold(body.socket("hands_mid"))

## The shot leaves his hands on a lob down through where he last saw you.
func _release() -> void:
	body.set_effect("rune_glow",false)
	if shot == null or not is_instance_valid(shot): return
	var from: Vector3 = shot.global_position
	var to := last_seen if last_seen != Vector3.INF else from+_forward()*10.0
	var flat := Vector2(to.x-from.x,to.z-from.z).length()
	# Long enough aloft to climb shot_rise first (v up >= sqrt(2 g rise)).
	var g := knob("shot_fall")
	var v_up := sqrt(2.0*g*knob("shot_rise"))
	var climb := (v_up+sqrt(maxf(v_up*v_up-2.0*g*(to.y-from.y),0.0)))/g
	var t := clampf(maxf(flat/knob("shot_pace"),climb),knob("shot_time_min"),knob("shot_time_max"))
	shot.launch(WindShot.lob(from,to,t,knob("shot_fall")),knob("shot_fall"))
	throws += 1
	print("rune knight: throws at (%.1f, %.1f, %.1f), %.1f m off, %.1f s aloft" % [to.x,to.y,to.z,flat,t])
	shot = null

## Whether the walker stands on the deck just ahead of him.
func _blocked(fwd: Vector3) -> bool:
	var motor = isle.get("motor") if isle != null else null
	if motor == null: return false
	var feet: Vector3 = motor.feet
	if absf(feet.y-position.y) > tall*0.6: return false
	var off := feet-position
	var ahead := off.dot(fwd)
	var room: float = _shape.radius
	return ahead > 0.0 and ahead < room+knob("blocked")+0.4 and absf(off.dot(Basis(Vector3.UP,yaw).x)) < room+0.4

func _forward() -> Vector3:
	return -(Basis(Vector3.UP,yaw).z)

static func _yaw_to(way: Vector3) -> float:
	return atan2(-way.x,-way.z)

func _build_room() -> void:
	_room = StaticBody3D.new()
	_room.name = "RuneKnightRoom"
	_room.collision_layer = ROOM_LAYER
	_room.collision_mask = 0
	_room.top_level = true
	var shape := CollisionShape3D.new()
	var column := CylinderShape3D.new()
	column.radius = float(_shape.radius)
	column.height = float(_shape.height)
	shape.shape = column
	shape.position = Vector3.UP*column.height*0.5
	_room.add_child(shape)
	add_child(_room)
	_room.global_transform = Transform3D(Basis.IDENTITY,position)
