extends Node3D
## The pocket sail, drawn (scripts/pocket_sail.gd flies it): a small cloth
## wing held overhead on a bar, in the plane's livery (cream cloth,
## terracotta tips), a greybox's worth. Put on the pilot's figure (its
## origin at the feet, facing -Z); `update` each frame pops it out over
## OPEN_TIME as it opens (swelling past full and settling), folds it away
## over FOLD_TIME, billows its cells, ripples its trailing edge and leans it
## into a turn.

## Its span and chord (m), how high its middle stands over the feet, how
## far its tips droop (m), and its cells.
const SPAN := 1.8
const CHORD := 0.55
const HIGH := 1.75
const DROOP := 0.28
const CELLS := 6
## The bar the mitts hold (m over the feet), and its half width.
const BAR := 1.32
const BAR_HALF := 0.2
## Seconds out and away; the swell past full as it opens.
const OPEN_TIME := 0.18
const FOLD_TIME := 0.12
const SWELL := 0.12
## The billow (m) and its pace (Hz), the lean into a turn (radians).
const BILLOW := 0.025
const BILLOW_HZ := 2.3
const LEAN := 0.35
const CLOTH := Color("efe4cf")
const TIPS := Color("c4673f")
const LINE := Color("4a3a2e")

## 0 packed to 1 out (with the swell over it as it opens).
var out := 0.0
var _swell := 0.0
var _time := 0.0
var _lean := 0.0
var _wing: MeshInstance3D
var _lines: MeshInstance3D

func _init() -> void:
	name = "PocketSail"
	_wing = MeshInstance3D.new()
	_wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 0.85
	cloth.backlight_enabled = true
	cloth.backlight = Color(0.35,0.28,0.2)
	_wing.material_override = cloth
	add_child(_wing)
	_lines = MeshInstance3D.new()
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = LINE
	_lines.material_override = ink
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	visible = false

## Packed away at once.
func reset() -> void:
	out = 0.0
	_swell = 0.0
	_lean = 0.0
	visible = false

## One frame: `open` whether it is out, `turning` -1 right to 1 left.
func update(delta: float, open: bool, turning := 0.0) -> void:
	var was := out
	out = move_toward(out,1.0 if open else 0.0,delta/(OPEN_TIME if open else FOLD_TIME))
	if open and was < 1.0 and out >= 1.0: _swell = SWELL
	_swell = move_toward(_swell,0.0,delta*0.6)
	_time += delta
	_lean = lerpf(_lean,clampf(turning,-1.0,1.0)*LEAN,1.0-exp(-delta/0.25))
	visible = out > 0.01
	if visible: _draw()

func _draw() -> void:
	var span := SPAN*(0.15+0.85*smoothstep(0.0,1.0,out))*(1.0+_swell)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean := Basis(Vector3.FORWARD,_lean)
	for i in range(CELLS):
		var a := _edge(float(i)/CELLS,span)
		var b := _edge(float(i+1)/CELLS,span)
		var tip := i == 0 or i == CELLS-1
		var colour := TIPS if tip else CLOTH
		# Each cell puffs up in its middle, the trailing edge rippling.
		var mid := (a+b)*0.5+Vector3.UP*(0.05+BILLOW*sin(_time*TAU*BILLOW_HZ+i*1.3))
		var ripple := Vector3.UP*BILLOW*0.6*sin(_time*TAU*BILLOW_HZ*1.7+i)
		var front := Vector3.FORWARD*CHORD*0.45
		var back := Vector3.BACK*CHORD*0.55
		var quad: Array[Vector3] = [a+front,b+front,mid+front*0.9+Vector3.UP*0.03,a+back+ripple,b+back+ripple,mid+back+ripple]
		for k in range(quad.size()): quad[k] = lean*quad[k]+Vector3.UP*HIGH
		_tri(mesh,quad[0],quad[2],quad[3],colour)
		_tri(mesh,quad[2],quad[5],quad[3],colour)
		_tri(mesh,quad[2],quad[1],quad[5],colour)
		_tri(mesh,quad[1],quad[4],quad[5],colour)
	mesh.surface_end()
	_wing.mesh = mesh
	# The bar the mitts hold, and a line from each end of it to each tip.
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var left := lean*_edge(0.0,span)+Vector3.UP*HIGH
	var right := lean*_edge(1.0,span)+Vector3.UP*HIGH
	var bar_l := Vector3(-BAR_HALF,BAR,0.0)
	var bar_r := Vector3(BAR_HALF,BAR,0.0)
	for pair: Array in [[bar_l,bar_r],[bar_l,left],[bar_r,right],[bar_l,lean*Vector3(-span*0.18,0.0,0.0)+Vector3.UP*HIGH],[bar_r,lean*Vector3(span*0.18,0.0,0.0)+Vector3.UP*HIGH]]:
		lines.surface_add_vertex(pair[0])
		lines.surface_add_vertex(pair[1])
	lines.surface_end()
	_lines.mesh = lines

## A point along the wing's middle line (0 the left tip to 1 the right),
## its arc drooping to the tips, round its middle.
func _edge(u: float, span: float) -> Vector3:
	var x := (u-0.5)*span
	var k := 2.0*u-1.0
	return Vector3(x,-DROOP*k*k*(span/SPAN),0.0)

static func _tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var n := (b-a).cross(c-a).normalized()
	for p in [a,b,c]:
		mesh.surface_set_normal(n)
		mesh.surface_set_color(colour)
		mesh.surface_add_vertex(p)
