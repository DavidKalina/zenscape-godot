extends RefCounted
## A ship's sails: hands the shared sail shader (assets/models/pirate_ship/
## ship_cloth.gdshader, written by art/blender/ship/ship_build.py) what it can't
## get from the world's wind, per ship, as instance uniforms so every ship may
## share the one material: her bow, her speed, her turn, and how slack she's gone.
## The cloth's shape, wind and gusts all live in the shader.

## How far the shader may throw the cloth past its flat sheet (m), for culling:
## the belly of the 20 m deep courses, or their swing in a sink.
const REACH := 22.0
## Past this generated LODs would flatten the sheet the shader shapes.
const NO_LOD := 1000.0
## Seconds for the turn the cloth feels to follow hers, and for her to go slack.
const TURN_LAG := 2.5
const SLACK_S := 3.0
## She jumped: a return, not a speed.
const JUMP := 40.0

var _sails: Array[GeometryInstance3D] = []
var _was := Vector3.INF
var _was_way := Vector2.ZERO
var _speed := 0.0
var _turn := 0.0
var _slack := 0.0
var _sent := Vector4.INF
var _sent_slack := 0.0

## Every Sail_* under `model`.
func _init(model: Node) -> void:
	for n: Node in model.find_children("Sail_*","MeshInstance3D",true,false):
		var sail := n as GeometryInstance3D
		sail.extra_cull_margin = REACH
		sail.lod_bias = NO_LOD
		_sails.append(sail)

## One frame: `at` and `way` her place and bow (x, z), `sinking` her cloth let go.
func step(delta: float, at: Vector3, way: Vector2, sinking: bool) -> void:
	if delta <= 0.0: return
	if _was != Vector3.INF and _was.distance_to(at) < JUMP:
		_speed = Vector2(at.x-_was.x,at.z-_was.z).length()/delta
		var turn := _was_way.angle_to(way)/delta
		_turn = lerpf(_turn,turn,1.0-exp(-delta/TURN_LAG))
	_was = at
	_was_way = way
	_slack = move_toward(_slack,1.0 if sinking else 0.0,delta/SLACK_S)
	var send := Vector4(way.x,way.y,_speed,_turn)
	if not send.is_equal_approx(_sent):
		_sent = send
		for sail: GeometryInstance3D in _sails: sail.set_instance_shader_parameter("ship_way",send)
	if _slack != _sent_slack:
		_sent_slack = _slack
		for sail: GeometryInstance3D in _sails: sail.set_instance_shader_parameter("ship_slack",_slack)
