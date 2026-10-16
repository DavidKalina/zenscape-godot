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
}
## The parked plane's layer (studies/kit_isle.gd PARKED_LAYER): only the
## walker and his ground probes see it.
const ROOM_LAYER := 1 << 13

var isle: Node3D
var body: Node3D
var tall := 1.9
## "patrol", "turn", "held" (more come: notice, gather, throw, catch,
## return, stagger).
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
	match state:
		"patrol", "held":
			var fwd := _forward()
			var left := (ends[heading_to]-at).dot(fwd)
			if left <= 0.02:
				heading_to = 1-heading_to
				_turns_left = int(knob("turn_steps"))
				state = "turn"
				body.play("turn")
				_next_turn()
			elif _blocked(fwd):
				if state != "held": body.play("idle")
				state = "held"
			else:
				if state != "patrol": body.play("walk")
				state = "patrol"
				at += fwd*minf(float(_shape.pace)*delta,left)
		"turn":
			pass
	yaw = move_toward(yaw,yaw_goal,knob("turn_rate")*delta)
	transform = Transform3D(Basis(Vector3.UP,yaw),at)
	_room.global_transform = Transform3D(Basis.IDENTITY,at)

func _on_beat(clip: String, beat: String) -> void:
	if clip == "turn" and beat == "plant" and state == "turn":
		if _turns_left > 0: _next_turn()
		elif absf(yaw-yaw_goal) < 0.01:
			state = "patrol"
			body.play("walk")

## The next chunk of the half turn: his yaw's goal comes round by one step.
func _next_turn() -> void:
	_turns_left -= 1
	yaw_goal += PI/knob("turn_steps")

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
