extends Node3D
## The lesson's guide as lines the plane emits (lesson_ribbon.gd lays the
## way; this draws it): two lines out of the plane's wingtips, redrawn from
## them every frame, that run ahead along the way to fly. Off the way they
## bend from the plane back onto it (a curve leaving the tip along the
## flight and meeting the way JOIN m on, further the further off), then
## follow it LANE m either side of it to the leg's end. A new way grows out
## of the plane (GROW m/s); the one it replaces fades (FADE s).
## Drawn in the world (the land hides them): a gold core over a dark soft
## edge, thin at the tip and widening, never under a few px far off, with
## glints running out from the plane.

const PlaneFigure = preload("res://scripts/plane_figure.gd")
## Colours as drawn in the lit world (rival_marks.gd's gold and dark).
const GOLD := Color(1.0,0.6,0.1)
const HOT := Color(1.0,0.86,0.5)
const DARK := Color(0.14,0.07,0.01)
## Which way to draw (--guide=): "tips", two lines out of the upper wing's
## tips (the default), or "tail", one line (from the chase eye it rises
## through the upper wing like a pole and its swoop folds into one stroke;
## two lines a lane apart keep the swoop's depth).
static var mode := _mode()
## The lines either side of the way (m) once they meet it.
const LANE := 3.5
## Where the lines meet the way: this far along it from the plane's spot
## (m), plus this times the plane's distance off it, at most JOIN.z.
const JOIN := Vector3(45.0,2.5,260.0)
## How far the curve leaves the tip along the flight and comes into the
## way along it (shares of its length).
const BEND := 0.4
## Points along the curve and the way (m).
const STEP := 4.0
## Past this far along from the plane (m) every other point of the way.
const SPARSE := 150.0
## Growth of a new way out of the plane (m/s), the old one's fade (s).
const GROW := 380.0
const FADE := 0.45
## The line's half width: at the tip and from WIDEN m out (m); far off
## never under LINE_PX px each way of the window's height.
const TIP_M := 0.03
const LINE_M := 0.32
const WIDEN := 30.0
const LINE_PX := 5.0
## Near the eye: gone at the first, whole from the second (m) (the chase
## eye rides ~5 m behind the tips).
const NEAR_FADE := Vector2(1.5,3.0)
## The head (the drawn end) fades over this (m).
const HEAD := 40.0
## Glints running out of the plane: speed (m/s) and spacing (m).
const GLINT := Vector2(55.0,70.0)
## The tail line's point on the figure (local, toy metres).
const TAIL := Vector3(0.0,0.12,0.62)

var _mesh := ArrayMesh.new()
## This frame's strips: vertices, tangents, UV (across, m from the plane),
## UV2 (the strip's length), colours, indices.
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()
var _mat: ShaderMaterial
var _mi: MeshInstance3D
var _way := PackedVector3Array()
var _cum := PackedFloat32Array()
var _sides := PackedVector3Array()
var _old := PackedVector3Array()
var _old_cum := PackedFloat32Array()
var _old_sides := PackedVector3Array()
var _age := 0.0
var _old_age := 0.0
## For checks and drivers: each line drawn the last frame (from the plane
## out), the plane's spot along the way (m), its distance off it (m).
var drawn: Array = []
var along := 0.0
var off := 0.0

static func _mode() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--guide="): return a.trim_prefix("--guide=")
	return "tips"

func _init() -> void:
	name = "GuideLines"
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = _shader()
	_mi.material_override = _mat
	_mi.extra_cull_margin = 16384.0
	add_child(_mi)

## The way to fly (empty: none). The one before fades out.
func set_way(pts: PackedVector3Array) -> void:
	if _way.size() >= 2:
		_old = _way
		_old_cum = _cum
		_old_sides = _sides
		_old_age = 0.0
	_way = pts
	_cum = _cumulative(pts)
	_sides = PackedVector3Array()
	for i in range(pts.size()): _sides.append(_side(_tangent_i(pts,i)))
	_age = 0.0

func has_way() -> bool:
	return _way.size() >= 2

static func _cumulative(pts: PackedVector3Array) -> PackedFloat32Array:
	var c := PackedFloat32Array()
	c.resize(pts.size())
	var s := 0.0
	for i in range(pts.size()):
		if i > 0: s += pts[i].distance_to(pts[i-1])
		c[i] = s
	return c

## One frame, after the plane's figure was posed: the lines from `figure`'s
## tips flying `vel`, seen from `camera`, at `alpha`.
func step(delta: float, figure: Node3D, vel: Vector3, camera: Camera3D, alpha: float) -> void:
	_age += delta
	_old_age += delta
	_mesh.clear_surfaces()
	drawn = []
	if _old.size() >= 2 and _old_age >= FADE: _old = PackedVector3Array()
	if camera == null or figure == null or alpha <= 0.0 or (_way.size() < 2 and _old.size() < 2):
		_mi.visible = false
		return
	_mi.visible = true
	var view_h := maxf(get_viewport().get_visible_rect().size.y,1.0)
	var px := 2.0*tan(deg_to_rad(camera.fov)*0.5)/view_h
	_mat.set_shader_parameter("px_k",px*LINE_PX)
	var xf := figure.global_transform
	var starts := []
	if mode == "tail": starts = [xf*TAIL]
	else:
		for hand: float in [-1.0,1.0]:
			starts.append(xf*Vector3(0.5*hand*PlaneFigure.SPAN,PlaneFigure.UPPER_Y,-0.03))
	var fwd := vel.normalized() if vel.length() > 1.0 else -xf.basis.z.normalized()
	_v.clear()
	_n.clear()
	_uv.clear()
	_uv2.clear()
	_c.clear()
	_i.clear()
	if _old.size() >= 2:
		_lines(_old,_old_cum,_old_sides,starts,fwd,INF,alpha*(1.0-_old_age/FADE),false)
	if _way.size() >= 2:
		_lines(_way,_cum,_sides,starts,fwd,_age*GROW,alpha,true)
	if _i.is_empty():
		_mi.visible = false
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_INDEX] = _i
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

## The lines over `way` from `starts`, at most `most` m long.
func _lines(way: PackedVector3Array, cum: PackedFloat32Array, sides: PackedVector3Array, starts: Array, fwd: Vector3, most: float, a: float, record: bool) -> void:
	var mid := Vector3.ZERO
	for s: Vector3 in starts: mid += s
	mid /= float(starts.size())
	var s0 := _project(way,cum,mid)
	var total := cum[cum.size()-1]
	if s0 >= total-1.0: return
	var w0 := _at(way,cum,s0)
	var o := mid.distance_to(w0)
	if record:
		along = s0
		off = o
	var sj := minf(s0+minf(JOIN.x+JOIN.y*o,JOIN.z),total)
	var wj := _at(way,cum,sj)
	var tj := _tangent(way,cum,sj)
	var lane := LANE if starts.size() > 1 else 0.0
	var j0 := _first_after(cum,sj)
	for k in range(starts.size()):
		var hand := 0.0 if starts.size() == 1 else (-1.0 if k == 0 else 1.0)
		var pts := PackedVector3Array()
		var p0: Vector3 = starts[k]
		var p3 := wj+_side(tj)*hand*lane
		# Across the ground a curve leaving the tip along the flight and
		# coming into the way along it; in height the way's own rise and
		# fall, the tip's height off it eased away by the meeting point (a
		# curve in height too would hump up to a way still above a plane
		# that dives early, then down its swoop).
		var f0 := Vector2(p0.x,p0.z)
		var f3 := Vector2(p3.x,p3.z)
		var span := maxf(f0.distance_to(f3),1.0)
		var h := Vector2(fwd.x,fwd.z)
		h = h.normalized() if h.length() > 0.01 else Vector2(tj.x,tj.z).normalized()
		var f1 := f0+h*span*BEND
		var f2 := f3-Vector2(tj.x,tj.z).normalized()*span*BEND
		var e := p0.y-w0.y
		var n := maxi(ceili(span/STEP),2)
		for i in range(n+1):
			var t := float(i)/float(n)
			var u := 1.0-t
			var f := f0*u*u*u+f1*3.0*u*u*t+f2*3.0*u*t*t+f3*t*t*t
			var y := _at(way,cum,lerpf(s0,sj,t)).y+e*(1.0-smoothstep(0.0,1.0,t))
			pts.append(Vector3(f.x,y,f.y))
		for i in range(j0,way.size()):
			# Far off every other point (the way's are STEP apart).
			if cum[i]-s0 > SPARSE and (i-j0)%2 == 1 and i < way.size()-1: continue
			pts.append(way[i]+sides[i]*(hand*lane))
		var line := _cut(pts,most)
		if record: drawn.append(line)
		_strip(line,a)

## The plane's spot along the way (m): the nearest point on the ground.
static func _project(way: PackedVector3Array, cum: PackedFloat32Array, p: Vector3) -> float:
	var q := Vector2(p.x,p.z)
	var best := INF
	var s := 0.0
	for i in range(way.size()-1):
		var a := Vector2(way[i].x,way[i].z)
		var b := Vector2(way[i+1].x,way[i+1].z)
		var ab := b-a
		var k := clampf((q-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
		var dd := q.distance_squared_to(a+ab*k)
		if dd < best:
			best = dd
			s = lerpf(cum[i],cum[i+1],k)
	return s

static func _index(cum: PackedFloat32Array, s: float) -> int:
	var i := cum.bsearch(s)
	return clampi(i-1,0,cum.size()-2)

static func _at(way: PackedVector3Array, cum: PackedFloat32Array, s: float) -> Vector3:
	var i := _index(cum,s)
	var k := clampf((s-cum[i])/maxf(cum[i+1]-cum[i],0.0001),0.0,1.0)
	return way[i].lerp(way[i+1],k)

static func _tangent(way: PackedVector3Array, cum: PackedFloat32Array, s: float) -> Vector3:
	var i := _index(cum,s)
	return (way[i+1]-way[i]).normalized()

static func _tangent_i(way: PackedVector3Array, i: int) -> Vector3:
	var t := way[mini(i+1,way.size()-1)]-way[maxi(i-1,0)]
	return t.normalized() if t.length() > 0.001 else Vector3.FORWARD

static func _first_after(cum: PackedFloat32Array, s: float) -> int:
	var i := cum.bsearch(s)
	while i < cum.size() and cum[i] <= s+STEP*0.5: i += 1
	return i

## Across the way, level (its right as flown).
static func _side(t: Vector3) -> Vector3:
	var s := t.cross(Vector3.UP)
	s.y = 0.0
	return s.normalized() if s.length() > 0.001 else Vector3.RIGHT

## `pts` cut to `most` m along.
static func _cut(pts: PackedVector3Array, most: float) -> PackedVector3Array:
	if most == INF: return pts
	var out := PackedVector3Array()
	var s := 0.0
	out.append(pts[0])
	for i in range(1,pts.size()):
		var l := pts[i].distance_to(pts[i-1])
		if s+l >= most:
			out.append(pts[i-1].lerp(pts[i],clampf((most-s)/maxf(l,0.0001),0.0,1.0)))
			return out
		s += l
		out.append(pts[i])
	return out

## A strip along `line` (UV.x -1..1 across, UV.y m from the plane, UV2.x its
## length), turned to the eye in the shader.
func _strip(line: PackedVector3Array, a: float) -> void:
	var n := line.size()
	if n < 2: return
	var us := PackedFloat32Array()
	us.resize(n)
	for i in range(1,n): us[i] = us[i-1]+line[i].distance_to(line[i-1])
	var length := us[n-1]
	var col := Color(1.0,1.0,1.0,clampf(a,0.0,1.0))
	var base := _v.size()
	for i in range(n):
		var t := line[mini(i+1,n-1)]-line[maxi(i-1,0)]
		t = t/maxf(t.length(),0.0001)
		var c := line[i]
		var uu := us[i]
		_v.append(c)
		_v.append(c)
		_n.append(t)
		_n.append(t)
		_uv.append(Vector2(-1.0,uu))
		_uv.append(Vector2(1.0,uu))
		_uv2.append(Vector2(length,0.0))
		_uv2.append(Vector2(length,0.0))
		_c.append(col)
		_c.append(col)
		if i > 0:
			var k := base+(i-1)*2
			_i.append(k)
			_i.append(k+1)
			_i.append(k+2)
			_i.append(k+1)
			_i.append(k+3)
			_i.append(k+2)

static func _shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, world_vertex_coords;
uniform float px_k = 0.005;
uniform float tip_m = %f;
uniform float line_m = %f;
uniform float widen = %f;
uniform float head = %f;
uniform vec2 near_fade = vec2(%f, %f);
uniform vec2 glint = vec2(%f, %f);
uniform vec3 core_col = vec3(%f, %f, %f);
uniform vec3 hot_col = vec3(%f, %f, %f);
uniform vec3 edge_col = vec3(%f, %f, %f);
varying float v_u;
varying float v_len;
varying float v_d;
varying float v_x;
varying float v_a;
void vertex() {
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 c = VERTEX;
	vec3 to_eye = eye - c;
	float d = max(length(to_eye), 0.001);
	vec3 side = cross(normalize(NORMAL), to_eye / d);
	side = length(side) > 0.001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float grow = smoothstep(0.0, widen, UV.y);
	float w = max(mix(tip_m, line_m, grow), d * px_k * mix(0.4, 1.0, grow));
	VERTEX = c + side * w * UV.x;
	v_u = UV.y;
	v_len = UV2.x;
	v_d = d;
	v_x = UV.x;
	v_a = COLOR.a;
}
void fragment() {
	float x = abs(v_x);
	float core = 1.0 - smoothstep(0.36, 0.56, x);
	float edge = 1.0 - smoothstep(0.6, 1.0, x);
	float near = smoothstep(near_fade.x, near_fade.y, v_d);
	float tip = 1.0 - smoothstep(v_len - head, v_len, v_u);
	float g = fract((v_u - TIME * glint.x) / glint.y);
	float shine = smoothstep(0.0, 0.08, g) * (1.0 - smoothstep(0.08, 0.3, g));
	vec3 col = mix(edge_col, mix(core_col, hot_col, shine), core);
	ALBEDO = col;
	ALPHA = clamp(max(core * (0.9 + 0.1 * shine), edge * 0.5), 0.0, 1.0) * near * tip * v_a;
}
""" % [TIP_M,LINE_M,WIDEN,HEAD,NEAR_FADE.x,NEAR_FADE.y,GLINT.x,GLINT.y,GOLD.r,GOLD.g,GOLD.b,HOT.r,HOT.g,HOT.b,DARK.r,DARK.g,DARK.b]
	return s
