extends Node3D
## The guacharo's clips side by side (feature `flyer`), to judge the body and
## its animation by eye: a row per clip (glide flap circle stalk scream fold
## stoop flare carry pull hurt), each bird seeked to a phase of it (a
## one-shot's last bird is its held end).
##   --clip=NAME      only that clip's row, closer (--n=6 phases)
##   --n=N            phases per row (default 5)
##   --view=side|three|front|below|above   the birds' turn to the camera (three)
##   --far=K          the camera K times as far
##   --live           every bird plays its clip from its phase (one-shots
##                    restart every 1.5 s)
## A still: python3 tools/shot.py studies/guacharo_poses.tscn -- --clip=fold
## (the fallback body, with no glb, shows its pose dicts as before).
const Look = preload("res://scripts/enemies/guacharo_look.gd")

const CLIPS := ["glide","flap","circle","stalk","scream","fold","stoop","flare","carry","pull","hurt"]
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
const VIEWS := {"three":Vector3(0.35,0.5,0.0),"side":Vector3(0.0,PI*0.5,0.0),"front":Vector3(0.1,0.0,0.0),
	"below":Vector3(-1.1,0.3,0.0),"above":Vector3(1.2,0.3,0.0)}
const ONE_SHOT_REPLAY := 1.5

var looks: Array = []
var _live := false
var _t := 0.0
## --far=K: the camera K times as far (wings at a distance).
var _far := 1.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_live = "--live" in args
	var only := ""
	var n := 5
	var view := "three"
	for a: String in args:
		if a.begins_with("--clip="): only = a.get_slice("=",1)
		if a.begins_with("--n="): n = maxi(int(a.get_slice("=",1)),1)
		if a.begins_with("--view="): view = a.get_slice("=",1)
		if a.begins_with("--far="): _far = float(a.get_slice("=",1))
	_world()
	var probe: Node3D = Look.new()
	var clips: bool = probe.glb
	probe.free()
	var rows: Array = []
	if clips:
		if only != "" and not "--n=" in " ".join(args): n = 6
		rows = [only] if only != "" else CLIPS
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	if not clips:
		_fallback(cam)
		return
	var dx := 4.6
	var dy := 3.0
	for r in range(rows.size()):
		var label := Label3D.new()
		label.text = rows[r]
		label.font_size = 96
		label.pixel_size = 0.01
		label.modulate = Color(0.12,0.1,0.08)
		label.outline_size = 0
		label.position = Vector3(-(float(n-1)*0.5+0.8)*dx,-float(r)*dy,0.0)
		add_child(label)
		for j in range(n):
			var look: Node3D = Look.new()
			look.size_to(SPAN)
			look.name = "Clip_%s_%d" % [rows[r],j]
			look.position = Vector3((float(j)-float(n-1)*0.5)*dx,-float(r)*dy,0.0)
			look.rotation = VIEWS.get(view,VIEWS.three)
			add_child(look)
			look.clip = rows[r]
			look.drive({})
			var ap: AnimationPlayer = look._ap
			var an := ap.get_animation(rows[r])
			# Straight onto the clip (no crossfade from the glide), seeked.
			ap.play(rows[r],0.0)
			var den := float(n) if an.loop_mode != Animation.LOOP_NONE else float(maxi(n-1,1))
			ap.seek(an.length*float(j)/den,true)
			look.set_meta("phase",an.length*float(j)/den)
			looks.append(look)
	var w := float(n)*dx
	var h := float(rows.size())*dy
	cam.position = Vector3(0.0,-h*0.5+dy*0.5,(w*0.78 if rows.size() == 1 else maxf(w*0.95,h*1.15)+2.0)*_far)

func _process(delta: float) -> void:
	if not _live or looks.is_empty() or not looks[0].glb: return
	_t += delta
	for look: Node3D in looks:
		var ap: AnimationPlayer = look._ap
		if not String(look.clip) in Look.LOOPS and fmod(_t+float(look.get_meta("phase")),ONE_SHOT_REPLAY) < delta:
			ap.play(look.clip,0.0)
			ap.seek(0.0,true)
		look.drive({})

func _world() -> void:
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

## The procedural body's pose dicts (no glb).
func _fallback(cam: Camera3D) -> void:
	for i in range(POSES.size()):
		var look: Node3D = Look.new()
		look.size_to(SPAN)
		look.name = "Pose_%s" % POSES[i][0]
		look.position = Vector3(float(i%4)*4.4-6.6,3.0-float(i/4)*3.6,0.0)
		look.rotation = VIEWS.three
		add_child(look)
		look.drive(POSES[i][1])
		looks.append(look)
	cam.fov = 60.0
	cam.position = Vector3(0.0,1.2,12.5)
