extends Node3D
## The guacharo's key poses side by side (feature `flyer`, docs/design/
## roguelike/flyer-round1.md), to judge the body and its poses by eye:
## glide, the downbeat, the upbeat, the scream (thrown up), the fold (the
## teardrop), the stoop, the flare (the strike) and the carry. `--live`
## flaps the first one. A still: python3 tools/shot.py studies/guacharo_poses.tscn
const Look = preload("res://scripts/enemies/guacharo_look.gd")

const POSES := [
	["glide",{}],
	["downbeat",{"elev":-0.65,"sweep":0.2,"wrist":0.15,"droop":0.25,"spread":0.65,"tail":0.65}],
	["upbeat",{"elev":0.95,"sweep":-0.05,"wrist":0.75,"droop":-0.25,"spread":0.9,"tail":0.65}],
	["scream",{"elev":1.15,"sweep":-0.15,"wrist":0.05,"droop":0.25,"spread":1.0,"tail":1.0,"pitch":0.45,"head":-0.2,"jaw":1.0,"stretch":0.86}],
	["fold",{"elev":0.32,"sweep":1.2,"wrist":2.5,"droop":0.1,"spread":0.0,"tail":0.0,"pitch":-0.35,"head":0.35,"jaw":0.6,"stretch":1.12}],
	["stoop",{"elev":0.3,"sweep":1.25,"wrist":2.6,"droop":0.05,"spread":0.0,"tail":0.0,"head":0.15,"jaw":0.3,"stretch":1.28}],
	["flare",{"elev":0.55,"sweep":-0.25,"wrist":0.0,"droop":0.3,"spread":1.0,"tail":1.0,"pitch":0.9,"head":-0.3,"jaw":0.8,"talons":1.0,"stretch":0.82}],
	["carry",{"elev":0.6,"sweep":0.0,"wrist":0.3,"spread":0.9,"tail":1.0,"pitch":0.5,"head":0.4,"talons":1.0}],
]
const SPAN := 3.4

var looks: Array = []
var _t := 0.0
var _live := false

func _ready() -> void:
	_live = "--live" in OS.get_cmdline_user_args()
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
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9,0.6,0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	for i in range(POSES.size()):
		var look: Node3D = Look.new()
		look.size_to(SPAN)
		look.name = "Pose_%s" % POSES[i][0]
		look.position = Vector3(float(i%4)*4.4-6.6,3.0-float(i/4)*3.6,0.0)
		look.rotation = Vector3(0.35,0.5,0.0)
		add_child(look)
		look.drive(POSES[i][1])
		looks.append(look)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0,1.2,12.5)
	cam.fov = 60.0
	add_child(cam)
	cam.make_current()
	# --close=<pose>: the camera close on one, from above and behind it
	# (--from=below under it).
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--close="):
			for look: Node3D in looks:
				if look.name == "Pose_"+a.get_slice("=",1):
					look.rotation = Vector3.ZERO
					var below := "--from=below" in OS.get_cmdline_user_args()
					var near := 0.35 if "--near" in OS.get_cmdline_user_args() else 1.0
					cam.look_at_from_position(look.position+Vector3(0.6*(1.0-near)*2.0,(-3.0 if below else 3.2)*near,3.4*near),look.position+Vector3(1.2*(1.0-near)*2.0,0.0,0.0),Vector3.UP)

func _process(delta: float) -> void:
	if not _live: return
	_t += delta
	var s := sin(_t*2.0*TAU)
	var c := cos(_t*2.0*TAU)
	looks[0].drive({"elev":0.15+0.85*s,"sweep":0.1-0.15*s,"wrist":0.15+0.6*maxf(c,0.0),"droop":-0.25*s,"spread":0.8+0.2*s,"tail":0.65})
