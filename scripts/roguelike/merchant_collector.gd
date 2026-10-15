extends Node3D
## [merchant] The Collector: what comes for a thief (docs/design/roguelike/
## merchant-round1.md). A stone mask the height of a man's chest, hung with
## strips of the stall's cloth, drifting at him through anything, over any
## gulf, slower than he runs at first and faster the longer he lingers.
## It does not stop and it does not hurry: standing still is how it wins.
## Touch costs a heart; it falls back a little and comes again. It is on
## every layer after the theft.
##
## Dim warm slits for eyes and a faint lamp (art direction: no ember red,
## no horns; menace from weight and restraint).
const SPEED_FROM := 0.5
const SPEED_TO := 0.88
## Seconds of hunting to reach SPEED_TO.
const RAMP := 70.0
## It comes out of the dark this far away (m, flat) and this high over him.
const FAR := 48.0
const HIGH := 5.0
## Its touch: reach (units of his height), the fall back (m) after, the
## knock it gives him.
const TOUCH := 0.55
const BACK := 14.0
const KNOCK := 5.0

var study: Node3D
var motor: Variant
var unit := 1.8
var delay := 0.0
var live := false
var hunted := 0.0
var hits := 0
var _recoil := 0.0
var _sway := 0.0
var _strips: Array = []
var _hum: AudioStreamPlayer3D = null

func _init() -> void:
	name = "Collector"
	visible = false

func setup(scene: Node3D, wait: float, u: float) -> void:
	study = scene
	motor = scene.get("motor")
	unit = u
	delay = wait
	_build()

func step(delta: float) -> void:
	if motor == null: return
	var loop: Variant = study.get("run_loop")
	if loop != null and not (str(loop.state) in ["play","arrive"]): return
	if not live:
		delay -= delta
		if delay > 0.0: return
		_arrive()
	hunted += delta
	_sway += delta
	var mid: Vector3 = motor.feet+Vector3.UP*unit*0.55
	var to := mid-global_position
	var dist := to.length()
	if _recoil > 0.0:
		_recoil -= delta
		global_position -= to.normalized()*float(motor.run)*0.9*delta
		if dist > BACK: _recoil = 0.0
	else:
		var v := float(motor.run)*lerpf(SPEED_FROM,SPEED_TO,clampf(hunted/RAMP,0.0,1.0))
		global_position += to.normalized()*minf(v*delta,dist)
		if dist < TOUCH*unit+0.3:
			_touch(to)
	# Faces him; the cloth hangs and sways.
	var flat := Vector3(to.x,0.0,to.z)
	if flat.length() > 0.1: rotation.y = lerp_angle(rotation.y,atan2(-flat.x,-flat.z),delta*3.0)
	position.y += sin(_sway*1.7)*0.004
	for i in range(_strips.size()):
		(_strips[i] as Node3D).rotation.x = sin(_sway*1.3+float(i)*0.9)*0.12

func _arrive() -> void:
	live = true
	visible = true
	var a := randf()*TAU
	var around: Vector3 = motor.feet
	global_position = around+Vector3(cos(a)*FAR,HIGH,sin(a)*FAR)

func _touch(to: Vector3) -> void:
	hits += 1
	_recoil = 4.0
	var away := Vector2(-to.x,-to.z)
	if away.length() < 0.01: away = Vector2(1.0,0.0)
	motor.harm("thief",1,self)
	var away3 := Vector3(-to.x,0.0,-to.z).normalized()
	motor.knock(away3*KNOCK+Vector3.UP*3.0,self)

func _build() -> void:
	var u := unit
	var stone := StandardMaterial3D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.07
	n.seed = 77
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	var g := Gradient.new()
	g.set_color(0,Color("1f1d1a"))
	g.set_color(1,Color("5d574d"))
	tex.color_ramp = g
	stone.albedo_texture = tex
	stone.roughness = 0.92
	var face := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.34*u
	s.height = 0.68*u
	face.mesh = s
	face.scale = Vector3(0.82,1.22,0.46)
	face.material_override = stone
	add_child(face)
	var brow := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.46*u,0.06*u,0.1*u)
	brow.mesh = b
	brow.position = Vector3(0.0,0.13*u,-0.14*u)
	brow.material_override = stone
	add_child(brow)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.04,0.03,0.02)
	glow.emission_enabled = true
	glow.emission = Color(0.95,0.7,0.34)
	glow.emission_energy_multiplier = 1.3
	for sx: float in [-1.0,1.0]:
		var eye := MeshInstance3D.new()
		var e := BoxMesh.new()
		e.size = Vector3(0.12*u,0.025*u,0.03*u)
		eye.mesh = e
		eye.position = Vector3(sx*0.12*u,0.06*u,-0.15*u)
		eye.material_override = glow
		add_child(eye)
	# Strips of cloth hanging from under the mask, swaying.
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("5a4c36")
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(7):
		var pivot := Node3D.new()
		pivot.position = Vector3((float(i)-3.0)*0.09*u,-0.28*u,0.0)
		add_child(pivot)
		var strip := MeshInstance3D.new()
		var q := BoxMesh.new()
		var len := (0.9+0.5*float((i*5)%4)/3.0)*u
		q.size = Vector3(0.07*u,len,0.012)
		strip.mesh = q
		strip.position = Vector3(0.0,-len*0.5,0.0)
		strip.material_override = cloth
		pivot.add_child(strip)
		_strips.append(pivot)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0,0.76,0.45)
	lamp.light_energy = 0.8
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0,0.0,-0.5*u)
	add_child(lamp)
