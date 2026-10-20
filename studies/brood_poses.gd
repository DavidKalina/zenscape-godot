extends Node3D
## The stone guy's clips side by side (docs/design/brood/body-contract.md),
## to judge the body and its animation by eye: a row per clip, each guy
## seeked to a phase of it (a one-shot's row runs start to end).
##   --clips=a,b      only those rows (default: all)
##   --n=N            phases per row (default 6)
##   --view=three|side|front|back   the guys' turn to the camera (three)
##   --live           every guy plays his clip from his phase
##   --close          one guy, big (the first clip's first phase)
## A still: python3 tools/shot.py studies/brood_poses.tscn -- --clips=walk,climb
const Body = preload("res://scripts/brood/stone_guy_body.gd")

## (His front is -z: turned PI he faces the camera.)
const VIEWS := {"three":PI-0.7,"side":PI*0.5,"front":PI,"back":0.0}
const DX := 1.25
const DY := 1.35

var bodies: Array = []
var _live := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_live = "--live" in args
	var n := 6
	var view := "three"
	var only: PackedStringArray = []
	for a: String in args:
		if a.begins_with("--n="): n = maxi(int(a.get_slice("=",1)),1)
		if a.begins_with("--view="): view = a.get_slice("=",1)
		if a.begins_with("--clips="): only = a.get_slice("=",1).split(",")
	_world()
	var table: Dictionary = Body.table().get("clips",{})
	var rows: Array = []
	for c: String in ["idle","look","wake","peek","rise","sink","walk","haul","climb","mantle","drop","land","fall","shake","cling","leap","ride"]:
		if table.has(c) and (only.is_empty() or c in only): rows.append(c)
	var close := "--close" in args
	if close: n = 1
	for r: int in rows.size():
		var c: String = rows[r]
		var info: Dictionary = table[c]
		var length := float(info.length)
		var loop := bool(info.loop)
		var label := Label3D.new()
		label.text = c
		label.font_size = 64
		label.pixel_size = 0.004
		label.modulate = Color(0.1,0.08,0.06)
		label.position = Vector3(-(float(n-1)*0.5+0.9)*DX,-float(r)*DY+0.1,0.0)
		add_child(label)
		for j: int in n:
			var b := Body.new()
			b.name = "Clip_%s_%d" % [c,j]
			add_child(b)
			b.setup(1.0)
			b.position = Vector3((float(j)-float(n-1)*0.5)*DX,-float(r)*DY,0.0)
			b.rotation.y = float(VIEWS.get(view,VIEWS.three))
			var den := float(n) if loop else float(maxi(n-1,1))
			var t := length*float(j)/den
			b.player.play(c,0.0)
			b.clip = c
			b.player.advance(t)
			b.set_meta("phase",t)
			bodies.append(b)
			var floor_ := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.0,0.8)
			floor_.mesh = pm
			floor_.position = b.position+Vector3(0,-0.5,0)
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(0.55,0.5,0.42)
			floor_.material_override = fm
			add_child(floor_)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	var w := float(n)*DX+1.6
	var h := float(rows.size())*DY
	if close: cam.position = Vector3(0.0,0.15,2.6)
	else: cam.position = Vector3(0.0,-h*0.5+DY*0.5,maxf(w*1.3,h*1.4)+0.5)

func _process(delta: float) -> void:
	if not _live: return
	for b: Node3D in bodies:
		b.advance(delta,delta)

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
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8,0.7,0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
