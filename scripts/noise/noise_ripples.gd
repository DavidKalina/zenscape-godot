extends Node3D
## How loud the wanderer is, read in the world (docs/design/roguelike/
## noise-stealth-round1.md): a loud noise of his makes a soft ring of dust
## running out over the ground at his feet, wider and plainer the louder
## (shaders/noise_ripple.gdshader). A sneak or a walk makes none, so the
## quiet reads as the absence of it. No UI: the ring is in the world, low,
## dust-coloured, and gone in under a second.
##   ring(at, loudness)
## Rings start at FROM m of loudness; their size is a small share of how far
## the noise carries (not the hearing radius itself: `--noise-debug` draws
## that).

const SHADER := preload("res://shaders/noise_ripple.gdshader")
## The quietest noise that rings (m), and the loudness of a full ring.
const FROM := 9.0
const FULL := 40.0
## The ring's radius (m) at FROM and at FULL loudness, times the wanderer's size.
const R_FROM := 0.7
const R_FULL := 3.6
## Its life (s) at FROM and FULL.
const LIFE := Vector2(0.45,0.9)
const POOL := 10

var size := 1.0
var _rings: Array = []
var _next := 0

func _ready() -> void:
	name = "NoiseRipples"
	top_level = true
	for i in POOL:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0,2.0)
		quad.orientation = PlaneMesh.FACE_Y
		mi.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("seed",float(i)*7.3)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_rings.append({"mi":mi,"mat":mat,"t":0.0,"life":1.0,"on":false})

## A ring for a noise of `loudness` m at `at` (his feet); none under FROM.
func ring(at: Vector3, loudness: float) -> void:
	if loudness < FROM*size: return
	var k := clampf((loudness/size-FROM)/(FULL-FROM),0.0,1.0)
	var r: Dictionary = _rings[_next]
	_next = (_next+1)%POOL
	var mi: MeshInstance3D = r.mi
	var rad := lerpf(R_FROM,R_FULL,k)*size
	mi.global_position = at+Vector3.UP*0.04
	mi.scale = Vector3(rad,1.0,rad)
	mi.rotation.y = randf()*TAU
	mi.visible = true
	(r.mat as ShaderMaterial).set_shader_parameter("strength",lerpf(0.22,0.6,k))
	(r.mat as ShaderMaterial).set_shader_parameter("k",0.0)
	r.t = 0.0
	r.life = lerpf(LIFE.x,LIFE.y,k)
	r.on = true

func _process(delta: float) -> void:
	for r: Dictionary in _rings:
		if not r.on: continue
		r.t += delta
		var k: float = r.t/r.life
		if k >= 1.0:
			r.on = false
			(r.mi as MeshInstance3D).visible = false
			continue
		(r.mat as ShaderMaterial).set_shader_parameter("k",k)
