extends Node3D
## The skydive's canopy (scripts/sky_dive.gd), drawn: a little ram-air wing
## of CELLS cells on an arc, its cloth cream doped like the plane's wings
## (scripts/plane_figure.gd) with terracotta tips and a brass stripe, each
## cell puffed between its ribs so the light falls on it in facets
## (shaders/canopy_cloth.gdshader, which ripples its trailing edge and lets
## the sun glow through it). Fine dark lines run from its underside to the
## pilot's shoulders.
##
## Opening (the dive's `open`, 0 to 1), it streams out of the pilot's back
## as a small bundle up the lines, then fills: the span and the chord swell
## past full and settle, the cloth shaking hard and calming. Under it, it
## rides at the top of the lines (SkyDive `line_basis`), its nose a touch
## down, lifting in the flare.
##
## Landed (`collapse`), it flies on a little over the pilot, sinks, and
## folds down onto the ground, then goes.
##
## Top level: placed in global space from the dive each frame.

const SkyDive = preload("res://scripts/sky_dive.gd")
const CLOTH := preload("res://shaders/canopy_cloth.gdshader")
const CREAM := Color("f3ead6")
const TRIM := Color("c8643b")
const STRIPE := Color("e2b866")
const LINE := Color("3d2a20")
## Cells across, the arc's half angle (radians) and radius (m), the chord
## (m), its thickness (m), and how far each cell's top puffs between the
## ribs (m). The lines' length (m), from the shoulders up.
const CELLS := 7
const ARC := 0.62
const RADIUS := 2.0
const CHORD := 0.92
const THICK := 0.15
const PUFF := 0.045
const LINES := 2.0
## The airfoil's top over the chord line, at fractions along it.
const AIRFOIL := [Vector2(0.0,0.1),Vector2(0.06,0.62),Vector2(0.18,0.95),Vector2(0.34,1.0),Vector2(0.55,0.82),Vector2(0.78,0.45),Vector2(1.0,0.06)]
## Its trim (radians, nose down) and the flare's lift of the nose.
const TRIM_PITCH := -0.08
const FLARE_PITCH := 0.32
## The collapse: seconds it takes, and how far on it drifts (m).
const COLLAPSE := 1.6
const DRIFT := 1.6

var _wing: MeshInstance3D
var _material: ShaderMaterial
var _lines: MeshInstance3D
var _line_mesh: ImmediateMesh
## Where the lines meet the cloth (canopy frame).
var _anchors := PackedVector3Array()
## Collapsing: seconds in (-1 not), the ground it settles on, and the
## pose it collapses from.
var _collapse := -1.0
var _ground := 0.0
var _from := Transform3D.IDENTITY
## Folded away after a landing: hidden until the next dive.
var _spent := false

func _init() -> void:
	name = "Canopy"
	top_level = true
	visible = false
	_material = ShaderMaterial.new()
	_material.shader = CLOTH
	_wing = MeshInstance3D.new()
	_wing.name = "Wing"
	_wing.mesh = _build()
	_wing.material_override = _material
	add_child(_wing)
	_line_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.name = "Lines"
	_lines.mesh = _line_mesh
	_lines.top_level = true
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(LINE,0.75)
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lines.material_override = ink
	add_child(_lines)

## Packed away (a new dive).
func reset() -> void:
	_collapse = -1.0
	visible = false
	_line_mesh.clear_surfaces()

## One frame: posed on `dive` (a SkyDive), the lines down to `shoulders`
## (global; the hips and a little up if not given).
func update(delta: float, dive: RefCounted, shoulders := Vector3.INF) -> void:
	if _collapse >= 0.0:
		_fold(delta)
		return
	var open := float(dive.open)
	if dive.falling(): _spent = false
	visible = not dive.falling() and open > 0.0 and not _spent
	if not visible:
		_line_mesh.clear_surfaces()
		return
	var lines: Basis = dive.line_basis()
	var hips: Vector3 = dive.position
	if shoulders == Vector3.INF: shoulders = hips+lines.y*0.3
	# Streaming out up the lines, then filling past full and settling.
	var out := smoothstep(0.0,0.35,open)
	var fill := smoothstep(0.2,1.0,open)
	var swell := _overshoot(fill)
	var span := lerpf(0.12,1.0,swell)
	var chord := lerpf(0.3,1.0,swell)
	var thick := lerpf(2.5,1.0,fill)
	var nose := TRIM_PITCH+FLARE_PITCH*float(dive.flare)
	var at := shoulders+lines.y*lerpf(0.25,LINES,out)
	transform = Transform3D(lines*Basis(Vector3.RIGHT,nose)*Basis.from_scale(Vector3(span,thick*chord,chord)),at)
	_material.set_shader_parameter("flutter",lerpf(1.6,0.35,fill)+0.25*float(dive.flare))
	_draw_lines(shoulders,lines)

## Landed: the canopy flies on a little and folds down on `ground` (global
## height).
func collapse(ground: float) -> void:
	if not visible:
		reset()
		_spent = true
		return
	_collapse = 0.0
	_ground = ground
	_from = transform

func collapsing() -> bool:
	return _collapse >= 0.0

func _fold(delta: float) -> void:
	_collapse += delta
	var k := clampf(_collapse/COLLAPSE,0.0,1.0)
	if k >= 1.0:
		reset()
		_spent = true
		return
	var ahead := -_from.basis.z.normalized()
	ahead.y = 0.0
	var at := _from.origin+ahead.normalized()*DRIFT*smoothstep(0.0,1.0,k)
	at.y = lerpf(_from.origin.y,_ground+0.08,smoothstep(0.0,0.8,k))
	var flat := 1.0-0.85*smoothstep(0.1,0.9,k)
	var basis := Basis(Vector3.UP,atan2(-ahead.x,-ahead.z))*Basis(Vector3.RIGHT,-0.5*smoothstep(0.2,1.0,k))
	var size := _from.basis.get_scale()
	var shrink := 1.0-0.5*smoothstep(0.6,1.0,k)
	transform = Transform3D(basis*Basis.from_scale(Vector3(size.x*shrink,size.y*flat*shrink,size.z*shrink)),at)
	_material.set_shader_parameter("flutter",1.2*(1.0-k))
	_line_mesh.clear_surfaces()

## The swell past full and back: an ease out with a little overshoot.
static func _overshoot(t: float) -> float:
	var c := 1.6
	var x := t-1.0
	return 1.0+(c+1.0)*x*x*x+c*x*x

## From each anchor on the cloth down to the nearer shoulder's riser.
func _draw_lines(shoulders: Vector3, lines: Basis) -> void:
	_line_mesh.clear_surfaces()
	var side := lines.x.normalized()*0.09
	var risers := [shoulders-side,shoulders+side]
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(_anchors.size()):
		var p := transform*_anchors[i]
		var left := (transform.basis.inverse()*(p-transform.origin)).x < 0.0
		var riser: Vector3 = risers[0] if left else risers[1]
		# A short riser webbing, then the lines fanning out.
		var fan := riser+lines.y.normalized()*0.35
		_line_mesh.surface_add_vertex(fan)
		_line_mesh.surface_add_vertex(p)
	for r: Vector3 in risers:
		_line_mesh.surface_add_vertex(r)
		_line_mesh.surface_add_vertex(r+lines.y.normalized()*0.35)
	_line_mesh.surface_end()

# --- Building ---------------------------------------------------------------------

## A point on the wing: across at `s` (0 left tip to 1 right), along the
## chord at `u` (0 the nose), `h` over the chord line (m, outward).
static func _point(s: float, u: float, h: float) -> Vector3:
	var a := lerpf(-ARC,ARC,s)
	var r := RADIUS+h
	return Vector3(r*sin(a),r*cos(a)-RADIUS,(u-0.35)*CHORD)

static func _top(u: float) -> float:
	for i in range(AIRFOIL.size()-1):
		var a: Vector2 = AIRFOIL[i]
		var b: Vector2 = AIRFOIL[i+1]
		if u <= b.x: return lerpf(a.y,b.y,(u-a.x)/maxf(b.x-a.x,0.0001))*THICK
	return 0.0

func _cell_color(cell: int) -> Color:
	if cell == 0 or cell == CELLS-1: return TRIM
	if cell == CELLS/2: return STRIPE
	return CREAM

## The cells: each a puffed top (ribs at its sides, its middle lifted) and
## a flatter underside, the nose's mouth a shade darker; the lines'
## anchors under the ribs.
func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var chords := [0.0,0.06,0.18,0.34,0.55,0.78,1.0]
	for cell in range(CELLS):
		var color := _cell_color(cell)
		var under := color.darkened(0.18)
		var s0 := float(cell)/CELLS
		var s1 := float(cell+1)/CELLS
		var spans := [s0,(s0+s1)*0.5,s1]
		for j in range(chords.size()-1):
			var u0: float = chords[j]
			var u1: float = chords[j+1]
			for k in range(2):
				var a: float = spans[k]
				var b: float = spans[k+1]
				var puff_a := PUFF*float(k == 1)*sin(PI*u0)
				var puff_b := PUFF*float(k == 0)*sin(PI*u0)
				var puff_a1 := PUFF*float(k == 1)*sin(PI*u1)
				var puff_b1 := PUFF*float(k == 0)*sin(PI*u1)
				var p00 := _point(a,u0,_top(u0)+puff_a)
				var p10 := _point(b,u0,_top(u0)+puff_b)
				var p01 := _point(a,u1,_top(u1)+puff_a1)
				var p11 := _point(b,u1,_top(u1)+puff_b1)
				_quad(st,p00,p10,p11,p01,color,Vector2(a,u0),Vector2(b,u0),Vector2(b,u1),Vector2(a,u1))
				# The underside, a little hollow.
				var q00 := _point(a,u0,-0.012*sin(PI*u0))
				var q10 := _point(b,u0,-0.012*sin(PI*u0))
				var q01 := _point(a,u1,-0.012*sin(PI*u1))
				var q11 := _point(b,u1,-0.012*sin(PI*u1))
				_quad(st,q00,q01,q11,q10,under,Vector2(a,u0),Vector2(a,u1),Vector2(b,u1),Vector2(b,u0))
		# The mouth at the nose, and the ribs' ends at the tips.
		var mouth := under.darkened(0.35)
		_quad(st,_point(s0,0.0,0.0),_point(s0,0.0,_top(0.0)),_point(s1,0.0,_top(0.0)),_point(s1,0.0,0.0),mouth,Vector2(s0,0.0),Vector2(s0,0.0),Vector2(s1,0.0),Vector2(s1,0.0))
		if cell == 0 or cell == CELLS-1:
			var s := s0 if cell == 0 else s1
			for j in range(chords.size()-1):
				var u0: float = chords[j]
				var u1: float = chords[j+1]
				_quad(st,_point(s,u0,0.0),_point(s,u0,_top(u0)),_point(s,u1,_top(u1)),_point(s,u1,0.0),color,Vector2(s,u0),Vector2(s,u0),Vector2(s,u1),Vector2(s,u1))
	for rib in range(CELLS+1):
		var s := float(rib)/CELLS
		for u: float in [0.12,0.62]: _anchors.append(_point(s,u,0.0))
	st.generate_normals()
	return st.commit()

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	for v: Array in [[a,ua],[b,ub],[c,uc],[a,ua],[c,uc],[d,ud]]:
		st.set_color(color)
		st.set_uv(v[1])
		st.add_vertex(v[0])
