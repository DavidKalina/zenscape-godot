extends Node3D
## The crow's key poses side by side (scripts/crow_body.gd), to judge the
## body and its poses by eye: sat, cocked, the caw, the peck, the hop, the
## launch, the down- and up-stroke, the glide, the flare and the touchdown's
## squash. `--live` plays one crow through a kit bird's states (sat with
## glances, flicks and caws, a hop, the launch, flaps and glides round a
## loop, the flare, the touchdown, foraging) instead. `--close=<pose>` puts
## the camera close on one; `--capture=<dir>` saves a frame every
## `--every=<n>` frames (default 4) for `--frames=<n>` frames, then quits.
## A still: python tools/shot.py studies/crow_poses.tscn -- --no-title
const Crow = preload("res://scripts/crow_body.gd")

const POSES := [
	["sat",{}],
	["cocked",{"head_yaw":0.6,"head_tilt":0.45}],
	["caw",{"neck":0.9,"head_nod":0.5,"jaw":1.0,"pitch":0.0,"tail_up":0.4,"tail_fan":0.5,"flick":0.55,"crouch":0.3}],
	["peck",{"pitch":-0.3,"head_nod":1.0,"neck":0.9,"tail_up":0.25,"crouch":0.15}],
	["hop",{"open":1.0,"elev":0.5,"sweep":-0.05,"wrist":0.3,"spread":0.75,"legs":0.4,"stretch":1.12,"tail_fan":0.6,"pitch":0.15}],
	["launch",{"open":1.0,"pitch":0.6,"elev":1.1,"spread":0.8,"legs":0.2,"stretch":1.12,"tail_fan":0.7,"tail_up":-0.2}],
	["downbeat",{"open":1.0,"legs":1.0,"pitch":0.0,"elev":-0.6,"sweep":-0.1,"droop":-0.3,"tail_fan":0.3}],
	["upbeat",{"open":1.0,"legs":1.0,"pitch":0.0,"elev":0.9,"sweep":0.3,"wrist":1.0,"droop":0.35,"spread":0.45,"tail_fan":0.3}],
	["glide",{"open":1.0,"legs":1.0,"pitch":0.0,"elev":0.07,"wrist":0.12,"droop":-0.14,"spread":1.0,"tail_fan":0.6}],
	["flare",{"open":1.0,"pitch":0.75,"elev":0.7,"sweep":-0.3,"spread":1.0,"tail_fan":1.0,"tail_up":-0.45,"legs":-1.0,"head_nod":-0.35}],
	["squash",{"crouch":0.8,"stretch":0.82,"tail_up":0.35,"tail_fan":0.7,"open":0.6,"elev":0.75,"sweep":0.4,"wrist":0.6,"spread":0.4}],
	["back",{}],
]
const GAP := 0.62

var crows: Array = []
var cam: Camera3D
var _live: Node3D
var _bird := {}
var _t := 0.0
var _frame := 0
var _capture := ""
var _every := 4
var _frames := 240
var _yaw := 0.0
var _follow := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--capture="): _capture = a.get_slice("=",1)
		if a.begins_with("--every="): _every = int(a.get_slice("=",1))
		if a.begins_with("--frames="): _frames = int(a.get_slice("=",1))
	_follow = "--follow" in args
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.42,0.52,0.66)
	mat.sky_horizon_color = Color(0.78,0.74,0.66)
	mat.ground_horizon_color = Color(0.6,0.55,0.48)
	mat.ground_bottom_color = Color(0.3,0.27,0.22)
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8,0.7,0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0,40.0)
	ground.mesh = plane
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55,0.52,0.47)
	stone.roughness = 0.95
	ground.material_override = stone
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	if "--live" in args:
		_live = Crow.new()
		_live.build("crow")
		add_child(_live)
		_bird = {"state":"perched","v":Vector3.ZERO,"look_goal":0.0,"hop":{},"peck":0.0}
		cam.look_at_from_position(Vector3(1.1,0.45,1.3),Vector3(0.0,0.25,0.0),Vector3.UP)
		return
	for i in range(POSES.size()):
		var crow: Node3D = Crow.new()
		crow.build("crow")
		crow.name = "Pose_%s" % POSES[i][0]
		var col := i%4
		var row := i/4
		var air := 0.18 if (POSES[i][1] as Dictionary).get("open",0.0) > 0.5 else 0.0
		crow.position = Vector3(float(col)*GAP-GAP*1.5,air,float(row)*GAP-GAP)
		add_child(crow)
		crow.rotation.y = -0.9 if POSES[i][0] != "back" else 2.4
		crow.apply(POSES[i][1])
		crows.append(crow)
	cam.look_at_from_position(Vector3(0.0,1.5,2.6),Vector3(0.0,0.1,-0.1),Vector3.UP)
	for a: String in args:
		if a.begins_with("--close="):
			for crow: Node3D in crows:
				if crow.name == "Pose_"+a.get_slice("=",1):
					var from := "--from=" in ",".join(args)
					var off := Vector3(0.55,0.28,0.45)
					for b: String in args:
						if b == "--from=below": off = Vector3(0.3,-0.35,0.5)
						if b == "--from=above": off = Vector3(0.2,0.75,0.35)
						if b == "--from=front": off = Vector3(-0.55,0.15,-0.2)
					var _f := from
					cam.look_at_from_position(crow.position+off,crow.position+Vector3(0.0,0.12,0.0),Vector3.UP)

func _process(delta: float) -> void:
	if _capture != "":
		_frame += 1
		if _frame%_every == 0 and _frame > 8:
			DirAccess.make_dir_recursive_absolute(_capture)
			get_viewport().get_texture().get_image().save_png("%s/f_%04d.png" % [_capture,_frame])
		if _frame >= _frames: get_tree().quit()
	if _live == null: return
	delta = 1.0/60.0 if _capture != "" else delta
	_t += delta
	_script(delta)
	_live.animate(_bird,delta,_yaw)
	if _follow:
		var p := _live.global_position
		cam.look_at_from_position(p+Vector3(1.0,0.35,1.1),p+Vector3(0.0,0.15,0.0),Vector3.UP)

## The live crow's day: a kit bird's states on a clock.
func _script(delta: float) -> void:
	var t := _t
	var p := _live.global_position
	_bird.hop = {}
	if t < 4.0:
		_bird.state = "perched"
		_bird.look_goal = [0.0,0.7,-0.5,0.2,-0.8][int(t/0.8)%5]
		if absf(t-1.6) < delta*0.5: _live.tail_flick = 1.0
	elif t < 4.35:
		_bird.state = "hopping"
		_bird.hop = {"t":(t-4.0)/0.35}
		_live.global_position = Vector3(0.0,sin((t-4.0)/0.35*PI)*0.12,-(t-4.0)/0.35*0.6)
	elif t < 6.0:
		_bird.state = "perched"
		_bird.look_goal = 0.4 if t < 5.0 else -0.3
	elif t < 11.0:
		# Up, round a loop, and back down.
		var u := t-6.0
		_bird.state = "flying" if u < 4.3 else "landing"
		var a := u/4.3*TAU
		var r := 1.8
		var c := Vector3(-r,0.0,-0.6)
		var want := c+Vector3(cos(a)*r,0.9*sin(a*0.5)+0.05,-sin(a)*r)
		if u > 4.3:
			want = Vector3(0.0,0.0,-0.6)
		var v := (want-p)/maxf(delta,0.001)
		v = v.limit_length(4.5)
		_bird.v = v
		_live.global_position = p+v*delta
		var flat := Vector2(v.x,v.z)
		if flat.length() > 0.3: _yaw = atan2(-v.x,-v.z)
		if u > 4.3 and p.distance_to(want) < 0.03:
			_t = 11.0
	elif t < 16.0:
		_bird.state = "perched"
		_bird.look_goal = 0.0 if t < 13.0 else 0.5
	elif t < 22.0:
		_bird.state = "ground"
		var u := fmod(t-16.0,1.0)
		if u < 0.16:
			_bird.hop = {"t":u/0.16}
			_live.global_position = p+Vector3(0.0,0.0,-0.6*delta)
		_bird.peck = fmod(t,1.0)*1.2
	else:
		_t = 0.0
		_live.global_position = Vector3.ZERO
