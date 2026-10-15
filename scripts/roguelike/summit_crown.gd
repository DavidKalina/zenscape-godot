extends Node3D
## [summit] The sun's gate, far above: a lit temple crown at the sky's edge
## ahead of the climb (a billboard at the sky's distance, so it never
## parallaxes), small and pale on the first layer, larger, warmer and lower
## on the horizon each layer on. Dim warm light, a stone silhouette with a
## shaft of light below it; no horns, no embers. On the summit layer it
## stands a halo behind the real gate too, and the win (`flare`) blooms it
## to fill the view. Cheap: two quads, one unlit shader, no textures.
const Summit = preload("res://scripts/roguelike/summit.gd")

## The crown's sky distance floor (m); it keeps inside the camera's far.
const DIST := 1700.0
## First layer to summit layer: the gate's half-width as a visual angle
## (deg), the elevation over the horizon (deg), the light's strength.
const SIZE_FAR := 0.7
const SIZE_NEAR := 3.2
## Where in the upper half of the view it hangs (share of the half-fov over
## the view's middle): near the top edge first, lower at the summit.
const VIEW_FAR := 0.8
const VIEW_NEAR := 0.58
const BRIGHT_FAR := 0.5
const BRIGHT_NEAR := 1.0
## How fast it comes nearer after a gate (progress per second).
const EASE := 0.22
## The quad is this many times the gate's half-size (the glow's room).
const QUAD := 5.8

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform float bright = 0.6;
uniform float flare = 0.0;
uniform float seed = 0.0;
uniform float gate_on = 1.0;
varying vec2 pos;
float box(vec2 p, vec2 c, vec2 h) { vec2 d = abs(p - c) - h; return max(d.x, d.y); }
void vertex() { pos = UV * 2.0 - 1.0; pos.y = -pos.y; }
void fragment() {
	vec2 p = pos;
	float r = length(p);
	float a = atan(p.y, p.x);
	// The sun-white heart and the broad warm wash round it.
	float glow = exp(-r * r * 26.0) * 0.95 + exp(-r * 4.2) * 0.30;
	float rays = pow(0.5 + 0.5 * sin(a * 11.0 + seed + TIME * 0.05), 4.0) * exp(-r * 4.5) * 0.30;
	rays += pow(0.5 + 0.5 * sin(a * 5.0 - seed * 1.7 - TIME * 0.03), 6.0) * exp(-r * 2.8) * 0.18;
	// The shaft: a column of light below it, a faint one above.
	float col = exp(-p.x * p.x * 700.0);
	float shaft = col * (p.y < 0.0 ? exp(p.y * 1.5) * 0.55 : exp(-p.y * 5.0) * 0.30);
	float light = (glow + rays * (1.0 + flare) + shaft) * bright * (1.0 + flare * 1.6);
	// The crown in gate space (|g| ~ 1 is its size): steps, two piers, a
	// lintel and a low roof, dark warm stone against the light.
	vec2 g = p / 0.17;
	float steps = min(box(g, vec2(0.0, -0.85), vec2(1.15, 0.12)), min(box(g, vec2(0.0, -0.6), vec2(0.88, 0.14)), box(g, vec2(0.0, -0.36), vec2(0.62, 0.12))));
	float piers = min(box(g, vec2(-0.42, 0.1), vec2(0.13, 0.5)), box(g, vec2(0.42, 0.1), vec2(0.13, 0.5)));
	float lintel = box(g, vec2(0.0, 0.66), vec2(0.66, 0.1));
	float roof = box(g, vec2(0.0, 0.84), vec2(0.4, 0.07));
	float s = min(min(steps, piers), min(lintel, roof));
	float w = fwidth(s) + 0.002;
	float m = (1.0 - smoothstep(-w, w, s)) * gate_on;
	m *= 1.0 - smoothstep(0.55, 1.0, flare);
	// The opening between the piers burns brightest.
	float open_ = (1.0 - smoothstep(-w, w, box(g, vec2(0.0, 0.05), vec2(0.29, 0.4)))) * gate_on;
	vec3 warm = vec3(1.0, 0.80, 0.52);
	vec3 white = vec3(1.0, 0.96, 0.86);
	vec3 lcol = mix(warm, white, clamp(exp(-r * r * 40.0) + open_ + flare, 0.0, 1.0));
	vec3 stone = vec3(0.17, 0.115, 0.075);
	// A rim of light along the stone's top edge.
	stone += vec3(0.5, 0.36, 0.2) * smoothstep(0.1, 0.0, abs(g.y - 0.0)) * 0.0;
	float la = clamp(light, 0.0, 1.0);
	float ma = clamp(m * (1.0 - open_ * 0.85), 0.0, 1.0);
	ALBEDO = mix(lcol * (1.0 + flare), stone, ma * (1.0 - la * 0.25));
	ALPHA = max(la * (1.0 - smoothstep(0.85, 1.0, r)), ma * 0.96);
}
"""

var camera: Camera3D
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _halo: MeshInstance3D
var _halo_mat: ShaderMaterial
var _halo_at := Vector3.ZERO
## Shown progress (0..1) and the one it eases to; the win's bloom (0..1).
var _p := 0.0
var _want := 0.0
var _flare := 0.0
## The horizontal heading it stands in, eased toward the gate's.
var _heading := Vector3(0.0,0.0,-1.0)
var _heading_want := Vector3(0.0,0.0,-1.0)
var _player: AudioStreamPlayer

func _init() -> void:
	name = "SummitCrown"

func _ready() -> void:
	_mat = _make_mat(1.0)
	_mesh = _quad(_mat)
	add_child(_mesh)

func _make_mat(gate: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("gate_on",gate)
	m.set_shader_parameter("seed",float(hash(name)%97))
	m.render_priority = -3
	return m

func _quad(m: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4000.0
	return mi

## Where the climb stands: the progress to ease to (`snap` at once), the
## heading toward the way on (the gate's facing).
func set_progress(p: float, snap := false) -> void:
	_want = clampf(p,0.0,1.0)
	if snap: _p = _want

func set_heading(h: Vector3) -> void:
	h.y = 0.0
	if h.length() < 0.01: return
	_heading_want = h.normalized()

## The win's bloom: 0 none, 1 the view full of light.
func set_flare(f: float) -> void:
	_flare = clampf(f,0.0,1.0)

## The summit layer's gate gets a halo behind it, for the last stretch.
func set_halo(at: Vector3) -> void:
	_halo_at = at
	if _halo == null:
		_halo_mat = _make_mat(0.0)
		_halo = _quad(_halo_mat)
		_halo.top_level = true
		add_child(_halo)

func clear_halo() -> void:
	if _halo != null:
		_halo.queue_free()
		_halo = null

## The chord, once (the win).
func sound() -> void:
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.stream = Summit.chime()
		_player.volume_db = -5.0
		add_child(_player)
	_player.play()

func step(delta: float) -> void:
	if camera == null or _mesh == null: return
	_p = move_toward(_p,_want,delta*EASE)
	_heading = _heading.slerp(_heading_want,clampf(delta*0.8,0.0,1.0)) if _heading.dot(_heading_want) > -0.99 else _heading_want
	var cam_pos := camera.global_position
	var far := maxf(camera.far,1.0)
	var dist := minf(DIST,far*0.82)
	var k := smoothstep(0.0,1.0,_p)
	var half := deg_to_rad(lerpf(SIZE_FAR,SIZE_NEAR,k))*(1.0+_flare*1.6)
	# The play camera looks steeply down, so the true sky is out of frame: the
	# light hangs at the view's upper edge, sliding sideways with the gate's
	# bearing, and sinking toward the view's middle as the summit nears.
	var fwd := -camera.global_transform.basis.z
	var fh := Vector3(fwd.x,0.0,fwd.z)
	fh = fh.normalized() if fh.length() > 0.01 else _heading
	var bearing := clampf(fh.signed_angle_to(_heading,Vector3.UP),-deg_to_rad(38.0),deg_to_rad(38.0))
	var vhalf := deg_to_rad(camera.fov)*0.5
	var elev := maxf(asin(clampf(fwd.y,-1.0,1.0))+vhalf*lerpf(VIEW_FAR,VIEW_NEAR,k)-_flare*vhalf*0.35,deg_to_rad(-80.0))
	var dir := (fh.rotated(Vector3.UP,bearing)*cos(elev)+Vector3.UP*sin(elev)).normalized()
	var size := 2.0*dist*tan(half*QUAD)
	_mesh.global_transform = Transform3D(Basis.looking_at(dir,Vector3.UP).scaled(Vector3(size,size,size)),cam_pos+dir*dist)
	_mat.set_shader_parameter("bright",lerpf(BRIGHT_FAR,BRIGHT_NEAR,k))
	_mat.set_shader_parameter("flare",_flare)
	# Far off it is only a glow (the form resolves as it nears).
	_mat.set_shader_parameter("gate_on",smoothstep(0.15,0.7,k))
	if _halo != null:
		var to := _halo_at-cam_pos
		var d := maxf(to.length(),1.0)
		var hs := minf(d*0.9,160.0)
		var back := (_halo_at+Vector3.UP*5.0)
		_halo.global_transform = Transform3D(Basis.looking_at((back-cam_pos).normalized(),Vector3.UP).scaled(Vector3(hs,hs,hs)),back)
		_halo_mat.set_shader_parameter("bright",0.55+0.5*_flare)
		_halo_mat.set_shader_parameter("flare",_flare*0.8)
