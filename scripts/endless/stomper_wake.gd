extends Node3D
## The stomper's wake (docs/design/endless-flight/spec-stomper.md): what stays
## behind where it has walked, written once a step and left alone.
##
##   prints  footprints bedded in the land: shaders/stomper_print.gdshader, one
##           MultiMesh of boxes that lay their mark on the ground the depth shows.
##   scuff   the same MultiMesh: a band of dusted, trodden ground along the way.
##   grass   a long hold in the push map (GrassReact `shock`): the grass round a
##           foot stays laid over for FLAT_HOLD s. The map is 384 m round the eye,
##           so this one shows close by; the scuff carries it further out.
##   dust    hanging low over the track, in the footfall's MultiMesh
##           (StomperFall `hang`).
##
## It starts with a track already behind the body, so the land is marked from the
## first frame. `--no-stomper-wake` leaves it all out.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const SHADER = preload("res://shaders/stomper_print.gdshader")

## A print's box (m: across, up, along), its life (s) and the seconds it waits
## after the landing, for the foot to lift off it (the stomp clip's stance).
const PRINT := Vector3(66.0,130.0,92.0)
const PRINT_LIFE := 600.0
const PRINT_WAIT := 9.9
## How far off a pond a print stays (m).
const PRINT_POND := 70.0
## The scuff's width and rise (m), the length as a share of a step, its life (s).
const SCUFF := Vector2(380.0,260.0)
const SCUFF_LONG := 2.6
const SCUFF_LIFE := 240.0
## How much of it is there from the first frame, in steps (of 8 s), and the step
## (m along the loop) and hip (m off it) the back-fill walks by.
const BEHIND := 60
const STEP_EVERY := 8.0
const STEP := 46.0
const HIP := 40.0
## The boxes: one ring, a print and a scuff a step, so it holds a print's whole
## life and no print is pushed out before it has worn away.
const MOST := 156
## The grass round a foot: reach (m), lean, front (m/s), seconds held.
const FLAT_REACH := 150.0
const FLAT_LEAN := 1.8
const FLAT_FRONT := 220.0
const FLAT_HOLD := 70.0
## The hanging dust: puffs a landing, how far round the foot, how high (m).
const HANG := 5
const HANG_ROUND := 130.0
const HANG_UP := Vector2(25.0,70.0)
const HANG_SIZE := Vector2(100.0,170.0)
const HANG_DRIFT := 5.0

var enabled := true
var now := 0.0
## For drivers: the marks written, the grass holds stamped.
var stats := {"prints": 0, "scuffs": 0, "holds": 0}

var _study: Node
var _field: RefCounted
var _body: Node3D
var _rng := RandomNumberGenerator.new()
var _sun_of: RefCounted
var _mat: ShaderMaterial
var _boxes: MultiMesh
var _next := 0
var _was_at := Vector3.ZERO

static func wanted() -> bool:
	return not "--no-stomper-wake" in LaunchArgs.user_args()

func setup(study: Node, stomper: Node3D) -> void:
	name = "StomperWake"
	top_level = true
	global_transform = Transform3D.IDENTITY
	_study = study
	_field = study.field
	_body = stomper
	_rng.seed = 17012
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_sun_of = study.look.celestial
	var fog: Environment = study.look.environment
	_mat.set_shader_parameter("haze",Vector3(fog.fog_depth_begin,fog.fog_depth_end,fog.fog_depth_curve))
	_mat.set_shader_parameter("sun",_sun_of.state.zs_sun_direction)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _mat
	_boxes = MultiMesh.new()
	_boxes.transform_format = MultiMesh.TRANSFORM_3D
	_boxes.use_custom_data = true
	_boxes.mesh = box
	_boxes.instance_count = MOST
	for i in range(MOST):
		_boxes.set_instance_transform(i,Transform3D())
		_boxes.set_instance_custom_data(i,Color(-100000.0,0.0,0.0,0.0))
	var all := MultiMeshInstance3D.new()
	all.name = "Track"
	all.multimesh = _boxes
	all.custom_aabb = AABB(Vector3.ONE*-200000.0,Vector3.ONE*400000.0)
	all.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(all)
	_lay_behind()
	stomper.footfall.connect(fell)

func step(delta: float) -> void:
	if not enabled: return
	now += delta
	_mat.set_shader_parameter("now",now)
	_mat.set_shader_parameter("sun",_sun_of.state.zs_sun_direction)

## A landing: the print for when the foot lifts, the scuff, the held grass, dust.
func fell(at: Vector3, _side: int) -> void:
	if not enabled: return
	var yaw: float = _body.rotation.y
	_print(at,yaw,now+PRINT_WAIT)
	var here: Vector2 = _body.route.at(_body.along)
	var mid := Vector3(here.x,at.y,here.y)
	_scuff(_was_at,mid,now)
	_was_at = mid
	var react: Node = _study.react
	if react != null:
		react.shock(Vector2(at.x,at.z),FLAT_REACH,FLAT_FRONT,FLAT_LEAN,FLAT_HOLD)
		stats.holds = int(stats.holds)+1
	var fall: Node3D = _body.fall
	if fall == null: return
	for i in range(HANG):
		var off := Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(20.0,HANG_ROUND)
		var x := at.x+off.x
		var z := at.z+off.y
		var y := float(_field.height(x,z))+_rng.randf_range(HANG_UP.x,HANG_UP.y)
		var drift := Vector2.from_angle(_rng.randf()*TAU)*HANG_DRIFT
		fall.hang(Vector3(x,y,z),Vector3(drift.x,0.8,drift.y),_rng.randf_range(HANG_SIZE.x,HANG_SIZE.y))

## The track already walked when the world opens, aged as it would be.
func _lay_behind() -> void:
	var route: RefCounted = _body.route
	var along: float = _body.along
	var from := _point(route,along-STEP*float(BEHIND+1))
	for i in range(BEHIND,0,-1):
		var s: float = along-STEP*float(i)
		var dir: Vector2 = route.way(fposmod(s,route.length))
		var to := _point(route,s)
		var born := -STEP_EVERY*float(i)
		var side := (-1.0 if i%2 == 0 else 1.0)*HIP
		var foot := Vector2(to.x,to.z)+Vector2(-dir.y,dir.x)*side
		_print(Vector3(foot.x,float(_field.height(foot.x,foot.y)),foot.y),atan2(-dir.x,-dir.y),born)
		if i*8 <= int(SCUFF_LIFE): _scuff(from,to,born)
		from = to
	_was_at = from

func _point(route: RefCounted, s: float) -> Vector3:
	var p: Vector2 = route.at(fposmod(s,route.length))
	return Vector3(p.x,float(_field.height(p.x,p.y)),p.y)

func _print(at: Vector3, yaw: float, born: float) -> void:
	# A pond's bed is what the depth shows there: nothing to press through water.
	if not _field.ponds_in(at.x-PRINT_POND,at.z-PRINT_POND,at.x+PRINT_POND,at.z+PRINT_POND).is_empty(): return
	var b := Basis(Vector3.UP,yaw).scaled_local(PRINT)
	_write(Transform3D(b,at),Color(born,PRINT_LIFE,0.0,_rng.randf()*40.0))
	stats.prints = int(stats.prints)+1

func _scuff(from: Vector3, to: Vector3, born: float) -> void:
	var way := Vector2(to.x-from.x,to.z-from.z)
	var long := maxf(way.length(),STEP)*SCUFF_LONG
	var yaw := atan2(-way.x,-way.y)
	var b := Basis(Vector3.UP,yaw).scaled_local(Vector3(SCUFF.x,SCUFF.y+absf(to.y-from.y),long))
	_write(Transform3D(b,(from+to)*0.5),Color(born,SCUFF_LIFE,1.0,_rng.randf()*40.0))
	stats.scuffs = int(stats.scuffs)+1

func _write(t: Transform3D, data: Color) -> void:
	_boxes.set_instance_transform(_next,t)
	_boxes.set_instance_custom_data(_next,data)
	_next = (_next+1)%MOST
