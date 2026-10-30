extends Node3D
## The rival race's marks in the world (scripts/endless/rival_race.gd shows
## them), all drawn in the world, so the land hides them, never through it:
## - the line: one ribbon along the whole course (rival_course.gd `line`),
##   laid once when the course is planned, so it never moves. Turned to the
##   eye in its shader, LINE_M m wide near and never under LINE_PX px far
##   off; a bright core over a dark soft edge (it reads on land and sky);
##   a slow glint runs along it the way to go. Up to his next gate it is
##   whole, past it LATER as strong; behind him it fades out (BEHIND m);
##   near the eye it fades away (NEAR_FADE m), so flown right on it it never
##   covers the view.
## - the gates: four corner brackets round each gate's mouth; his next one
##   bright gold, the ones after it dim bone; a gate he clears flashes,
##   swells and goes out (FLASH s).
## - his marks on the ground beside the stood rival (rival_strip.gd `spot`):
##   corner ticks laid on the turf, a faint fill and four short posts, so it
##   reads from the air; gold, and bright once he is in them.
## Every stroke keeps at least a few pixels on screen however far it is.

## Colours as drawn in the lit world (the tonemap pales them: the gold is
## deeper than the HUD's to read as the same gold).
const BONE := Color(0.86,0.8,0.66)
const GOLD := Color(1.0,0.6,0.1)
const HOT := Color(1.0,0.86,0.5)
const DARK := Color(0.14,0.07,0.01)
## The line: half its width near (m), and far (px each way, of the window's
## height); how strong past his next gate; how far behind him it fades out
## (m); near the eye, gone at the first and whole from the second (m); the
## glint's speed (m/s) and spacing (m).
const LINE_M := 0.4
const LINE_PX := 6.0
const LATER := 0.55
const BEHIND := Vector2(60.0,5.0)
const NEAR_FADE := Vector2(8.0,32.0)
const GLINT := Vector2(70.0,90.0)
## The gates: their brackets' share of the shorter side, their half width
## (m, and px far), alpha of the next and of later ones; near the eye each
## stroke fades (gone at the first, whole from the second, m); the flash
## (s) and its swell.
const TICK := 0.34
const GATE_M := 0.45
const GATE_PX := 3.0
const NEXT_ALPHA := 1.0
const LATER_ALPHA := 0.45
const GATE_NEAR := Vector2(12.0,45.0)
const FLASH := 0.6
const SWELL := 0.5
## His marks: the ticks' share of each side, their half width (m and px),
## how high they ride over the turf (m, and a share of the distance), the
## posts' height (m, and px far) and half width (px), the fill's alpha.
const SPOT_TICK := 0.3
const SPOT_M := 0.3
const SPOT_PX := 1.8
const SPOT_LIFT := Vector2(0.12,0.0012)
const POST := 8.0
const POST_PX := 40.0
const POST_W := 2.2
const FILL := 0.13

var _line: MeshInstance3D
var _line_mat: ShaderMaterial
## Vertices added to this step's surface.
var _added := 0
var _mesh := ImmediateMesh.new()
var _clock := 0.0
var _course: Dictionary = {}
var _spot: Dictionary = {}
var _spot_pts: Array = []
## Gates flashing: {index: age (s)}.
var _flash := {}
## For checks: what was drawn the last frame.
var gates_shown := 0
var line_shown := false
var spot_shown := false

func _init() -> void:
	name = "RivalMarks"
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_fog = true
	mi.material_override = mat
	# Its box is wherever the race is: never culled.
	mi.extra_cull_margin = 16384.0
	add_child(mi)
	_line = MeshInstance3D.new()
	_line.name = "Line"
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line_mat = ShaderMaterial.new()
	_line_mat.shader = _line_shader()
	_line.material_override = _line_mat
	_line.extra_cull_margin = 16384.0
	_line.visible = false
	add_child(_line)

## The course to show ({} none): its ribbon laid now, once.
func set_course(course: Dictionary) -> void:
	_course = course
	_flash.clear()
	if course.is_empty():
		_line.mesh = null
		_line.visible = false
		return
	var pts: PackedVector3Array = course.line
	var step := float(course.get("line_step",4.0))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var n := pts.size()
	for i in range(n):
		var t := pts[mini(i+1,n-1)]-pts[maxi(i-1,0)]
		t = t.normalized() if t.length() > 0.001 else Vector3.FORWARD
		for side: float in [-1.0,1.0]:
			verts.append(pts[i])
			normals.append(t)
			uvs.append(Vector2(side,i*step))
		if i > 0:
			var a := (i-1)*2
			index.append_array([a,a+1,a+2,a+1,a+3,a+2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var box := AABB(pts[0],Vector3.ZERO)
	for p in pts: box = box.expand(p)
	mesh.custom_aabb = box.grow(40.0)
	_line.mesh = mesh
	_line.visible = true

## His marks to show ({} none): `strip` rival_strip.gd's; the turf's
## heights read now, once.
func set_spot(strip: Dictionary, field: RefCounted) -> void:
	_spot = {}
	_spot_pts = []
	if strip.is_empty(): return
	var spot: Dictionary = strip.spot
	var c: Vector3 = spot.centre
	var axis: Vector3 = strip.axis
	var across: Vector3 = strip.across
	var hl := float(spot.half_len)
	var hw := float(spot.half_wide)
	_spot = {"c":c,"axis":axis,"across":across,"hl":hl,"hw":hw}
	# The outline's points, every few metres, on the turf.
	for k in range(4):
		var corner := c+axis*hl*(1.0 if k < 2 else -1.0)+across*hw*(1.0 if k == 1 or k == 2 else -1.0)
		corner.y = float(field.height(corner.x,corner.z))
		_spot_pts.append(corner)

## A gate cleared: it flashes and goes out.
func cleared(i: int) -> void:
	_flash[i] = 0.0

## One frame. `show`: {next (his next gate, -1 none), progress (m along, his),
## in_spot (he is in his marks), spot (show them), alpha}.
func step(delta: float, camera: Camera3D, show: Dictionary) -> void:
	_clock += delta
	_mesh.clear_surfaces()
	gates_shown = 0
	line_shown = false
	spot_shown = false
	for i: int in _flash.keys(): _flash[i] = float(_flash[i])+delta
	var alpha := float(show.get("alpha",1.0))
	if camera == null or alpha <= 0.0:
		_line.visible = false
		return
	var eye := camera.global_position
	var view_h := maxf(get_viewport().get_visible_rect().size.y,1.0)
	# Metres a pixel is, a metre out.
	var px := 2.0*tan(deg_to_rad(camera.fov)*0.5)/view_h
	var began := false
	_added = 0
	if not _course.is_empty():
		var next := int(show.get("next",0))
		var gates: Array = _course.gates
		_line.visible = alpha > 0.0
		line_shown = _line.visible
		_line_mat.set_shader_parameter("width_m",LINE_M)
		_line_mat.set_shader_parameter("px_k",px*LINE_PX)
		_line_mat.set_shader_parameter("behind_s",float(show.get("progress",-1000.0)))
		_line_mat.set_shader_parameter("next_s",float(gates[next].s) if next >= 0 and next < gates.size() else 1e9)
		_line_mat.set_shader_parameter("alpha_all",alpha)
		for i in range(gates.size()):
			var g: Dictionary = gates[i]
			var age := float(_flash.get(i,-1.0))
			if i < next and (age < 0.0 or age > FLASH): continue
			if next < 0: continue
			if not began:
				_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				began = true
			if age >= 0.0 and age <= FLASH:
				var k := age/FLASH
				_gate(g,eye,px,HOT.lerp(GOLD,k),(1.0-k*k)*alpha,1.0+SWELL*smoothstep(0.0,1.0,k))
			elif i == next:
				_gate(g,eye,px,GOLD,NEXT_ALPHA*alpha*(0.88+0.12*sin(_clock*TAU*0.9)),1.0)
			else:
				_gate(g,eye,px,BONE,LATER_ALPHA*alpha*(1.0 if i == next+1 else 0.7),1.0)
			gates_shown += 1
	else: _line.visible = false
	if not _spot.is_empty() and bool(show.get("spot",false)):
		if not began:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			began = true
		_draw_spot(eye,px,bool(show.get("in_spot",false)),alpha)
		spot_shown = true
	if began:
		# Every bracket faded out (far, high or flown through): one empty
		# triangle, as a surface with no vertices is an error.
		if _added == 0: _tri(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Color(0.0,0.0,0.0,0.0))
		_mesh.surface_end()

## A gate's four corner brackets in its mouth's plane, each over a dark
## edge, `swell` times its size.
func _gate(g: Dictionary, eye: Vector3, px: float, col: Color, a: float, swell: float) -> void:
	var dir: Vector3 = g.dir
	var across := dir.cross(Vector3.UP).normalized()
	if across.length() < 0.5: across = Vector3.RIGHT
	var p: Vector3 = g.p
	var lo := float(g.lo)
	var hi := float(g.hi)
	var c := Vector3(p.x,(lo+hi)*0.5,p.z)
	var hw := float(g.half_w)*swell
	var hh := (hi-lo)*0.5*swell
	var w := maxf(GATE_M,eye.distance_to(c)*px*GATE_PX)
	var t := minf(hw,hh)*TICK*2.0
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			var corner := c+across*hw*sx+Vector3.UP*hh*sy
			# Each bracket fades near the eye (flown through, it never
			# fills the view).
			var k := a*smoothstep(GATE_NEAR.x,GATE_NEAR.y,eye.distance_to(corner))
			if k <= 0.01: continue
			var dark := Color(DARK.r,DARK.g,DARK.b,0.5*k)
			var bright := Color(col.r,col.g,col.b,k)
			for pass_i in range(2):
				var ww := w*(2.0 if pass_i == 0 else 1.0)
				var cc := dark if pass_i == 0 else bright
				_bar(corner+across*sx*ww*0.5,corner-across*sx*t,Vector3.UP*ww*0.5,cc)
				_bar(corner+Vector3.UP*sy*ww*0.5,corner-Vector3.UP*sy*t,across*ww*0.5,cc)

## His marks: corner ticks and a faint fill on the turf, and four posts.
func _draw_spot(eye: Vector3, px: float, inside: bool, alpha: float) -> void:
	var col := HOT if inside else GOLD
	var pulse := 0.8+0.2*sin(_clock*TAU*(1.6 if inside else 0.7))
	var a := alpha*pulse
	var c: Vector3 = _spot.c
	var d := eye.distance_to(c)
	var lift := Vector3.UP*(SPOT_LIFT.x+d*SPOT_LIFT.y)
	var w := maxf(SPOT_M,d*px*SPOT_PX)
	var pts: Array = _spot_pts
	# The fill.
	var fill := Color(col.r,col.g,col.b,FILL*a*(1.6 if inside else 1.0))
	_tri(pts[0]+lift,pts[1]+lift,pts[2]+lift,fill)
	_tri(pts[2]+lift,pts[3]+lift,pts[0]+lift,fill)
	# The corner ticks along each side, laid flat.
	var bright := Color(col.r,col.g,col.b,0.95*a)
	var dark := Color(DARK.r,DARK.g,DARK.b,0.4*a)
	for k in range(4):
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[(k+1)%4]
		var p3: Vector3 = pts[(k+3)%4]
		for other: Vector3 in [p1,p3]:
			var end := p0.lerp(other,SPOT_TICK)
			var along := (end-p0).normalized()
			var flat := along.cross(Vector3.UP).normalized()
			_bar(p0+lift-along*w,end+lift,flat*w*1.8,dark)
			_bar(p0+lift-along*w,end+lift+Vector3.UP*0.02,flat*w,bright)
		# A post, fading up.
		var up := Vector3.UP*maxf(POST,d*px*POST_PX)
		var side := (eye-p0).cross(Vector3.UP).normalized()*maxf(SPOT_M,d*px*POST_W)
		var mid := Color(bright.r,bright.g,bright.b,bright.a*0.85)
		_quad(p0-side,p0+side,p0+up*0.65+side,p0+up*0.65-side,bright,mid)
		_quad(p0+up*0.65-side,p0+up*0.65+side,p0+up+side,p0+up-side,mid,Color(bright.r,bright.g,bright.b,0.0))

## A flat bar from `a` to `b`, `half` its half width.
func _bar(a: Vector3, b: Vector3, half: Vector3, col: Color) -> void:
	_tri(a-half,a+half,b+half,col)
	_tri(b+half,b-half,a-half,col)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color) -> void:
	for v: Array in [[a,low],[b,low],[c,high],[c,high],[d,high],[a,low]]:
		_mesh.surface_set_color(v[1])
		_mesh.surface_add_vertex(v[0])
		_added += 1

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	_added += 3
	for v: Vector3 in [a,b,c]:
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(v)

## The line's shader: each pair of points (UV.x -1, 1 across; UV.y m along)
## turned to the eye about the line's way (NORMAL), its width kept to at
## least a few px.
static func _line_shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, world_vertex_coords;
uniform float width_m = 0.7;
uniform float px_k = 0.005;
uniform float behind_s = -1000.0;
uniform float next_s = 1e9;
uniform float alpha_all = 1.0;
uniform float later = %f;
uniform vec2 behind = vec2(%f, %f);
uniform vec2 near_fade = vec2(%f, %f);
uniform vec2 glint = vec2(%f, %f);
uniform vec3 core_col = vec3(%f, %f, %f);
uniform vec3 hot_col = vec3(%f, %f, %f);
uniform vec3 edge_col = vec3(%f, %f, %f);
varying float v_s;
varying float v_d;
varying float v_x;
void vertex() {
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 c = VERTEX;
	vec3 to_eye = eye - c;
	float d = max(length(to_eye), 0.001);
	vec3 side = cross(normalize(NORMAL), to_eye / d);
	side = length(side) > 0.001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float w = max(width_m, d * px_k);
	VERTEX = c + side * w * UV.x;
	v_s = UV.y;
	v_d = d;
	v_x = UV.x;
}
void fragment() {
	float x = abs(v_x);
	float core = 1.0 - smoothstep(0.36, 0.56, x);
	float edge = 1.0 - smoothstep(0.6, 1.0, x);
	float ahead = smoothstep(behind_s - behind.x, behind_s + behind.y, v_s);
	float past = mix(1.0, later, smoothstep(next_s, next_s + 30.0, v_s));
	float near = smoothstep(near_fade.x, near_fade.y, v_d);
	float g = fract((v_s - TIME * glint.x) / glint.y);
	float shine = smoothstep(0.0, 0.08, g) * (1.0 - smoothstep(0.08, 0.3, g));
	vec3 col = mix(edge_col, mix(core_col, hot_col, shine), core);
	ALBEDO = col;
	ALPHA = clamp(max(core * (0.9 + 0.1 * shine), edge * 0.5), 0.0, 1.0) * ahead * past * near * alpha_all;
}
""" % [LATER,BEHIND.x,BEHIND.y,NEAR_FADE.x,NEAR_FADE.y,GLINT.x,GLINT.y,GOLD.r,GOLD.g,GOLD.b,HOT.r,HOT.g,HOT.b,DARK.r,DARK.g,DARK.b]
	return s
