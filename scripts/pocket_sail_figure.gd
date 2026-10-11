extends Node3D
## The pocket sail, drawn (scripts/pocket_sail.gd flies it): a square-ish
## sheet of cloth, a handkerchief held overhead by its corners on short
## lines to a bar, in the plane's livery (cream cloth, a terracotta hem). Not
## a stiff wing: a soft sheet arched deep across (its sides hang well down
## from its middle) and domed along, puffed up by the air under it. Put on
## the pilot's figure (its origin at the feet, facing -Z); `update` each
## frame pops it out over OPEN_TIME as it opens (crumpled to full, swelling
## past it and settling), folds it away over FOLD_TIME, billows the sheet,
## ripples its trailing edge in waves running back, flexes it into a turn
## (rolled, the inside side pulled down and its back corner fluttering) and
## puffs it fuller in rising air (`lift`, 0 to 1: a thermal ridden).
##
## The sheet is a GRID by GRID mesh rebuilt each frame (ImmediateMesh, smooth
## normals): a greybox's worth, cheap at one per pilot.

## Its width across and depth along (m), how high its middle stands over the
## feet, how far its sides hang below its middle (the arc across) and its
## front and back edges (the dome along), all m; the squares across its
## sheet; how many squares in from the edge the hem runs.
const WIDTH := 1.25
const DEPTH := 1.05
const HIGH := 2.0
const ARC := 0.42
const DOME := 0.14
const GRID := 10
const HEM := 1
## The bar the mitts hold (m over the feet), and its half width.
const BAR := 1.3
const BAR_HALF := 0.2
## Seconds out and away; the swell past full as it opens.
const OPEN_TIME := 0.22
const FOLD_TIME := 0.12
const SWELL := 0.18
## The billow: how far the sheet breathes (m) and its pace (Hz); the
## trailing edge's ripple (m), its pace (Hz) and its waves across; the lean
## into a turn (radians) and how far the inside side pulls down (m); how much
## fuller it puffs in rising air (share of DOME and of the billow).
const BILLOW := 0.035
const BILLOW_HZ := 1.6
const RIPPLE := 0.06
const RIPPLE_HZ := 3.4
const RIPPLE_WAVES := 1.6
const LEAN := 0.35
const PULL := 0.16
const PUFF := 0.9
const CLOTH := Color("efe4cf")
const TIPS := Color("c4673f")
const LINE := Color("4a3a2e")

## 0 packed to 1 out (with the swell over it as it opens).
var out := 0.0
var _swell := 0.0
var _time := 0.0
var _lean := 0.0
var _turn := 0.0
var _lift := 0.0
var _wing: MeshInstance3D
var _lines: MeshInstance3D

func _init() -> void:
	name = "PocketSail"
	_wing = MeshInstance3D.new()
	_wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 0.9
	cloth.backlight_enabled = true
	cloth.backlight = Color(0.45,0.36,0.26)
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
	_turn = 0.0
	_lift = 0.0
	visible = false

## One frame: `open` whether it is out, `turning` -1 right to 1 left,
## `lift` 0 to 1 how hard rising air holds it up.
func update(delta: float, open: bool, turning := 0.0, lift := 0.0) -> void:
	var was := out
	out = move_toward(out,1.0 if open else 0.0,delta/(OPEN_TIME if open else FOLD_TIME))
	if open and was < 1.0 and out >= 1.0: _swell = SWELL
	_swell = move_toward(_swell,0.0,delta*0.8)
	_time += delta
	_turn = lerpf(_turn,clampf(turning,-1.0,1.0),1.0-exp(-delta/0.25))
	_lean = _turn*LEAN
	_lift = lerpf(_lift,clampf(lift,0.0,1.0),1.0-exp(-delta/0.4))
	visible = out > 0.01
	if visible: _draw()

## A point of the sheet, `u` across (-1 left to 1 right) and `v` along (-1
## front to 1 back), its size `size` of full, in the wing's frame before the
## lean (its middle at 0).
func _point(u: float, v: float, size: float) -> Vector3:
	var open := smoothstep(0.0,1.0,out)
	# Crumpled as it pops out: deeper, narrower, rumpled.
	var arc := ARC*(1.0+0.6*(1.0-open))
	var dome := DOME*(1.0+PUFF*_lift)+_swell*0.25
	var y := -arc*u*u-dome*v*v
	var t := _time*TAU
	# The sheet breathes, the middle most; fuller and faster in rising air.
	var breathe := BILLOW*(1.0+PUFF*_lift)
	y += breathe*(1.0-u*u)*(1.0-v*v)*sin(t*BILLOW_HZ*(1.0+0.4*_lift)+u*0.8)
	# The trailing edge ripples, waves running back off it, the corners
	# flapping most; more in a turn.
	var back := smoothstep(0.1,1.0,v)
	var ripple := RIPPLE*(1.0+0.8*absf(_turn)+0.5*_lift)*(0.6+0.4*u*u)
	y += ripple*back*back*sin(t*RIPPLE_HZ-v*2.2+u*PI*RIPPLE_WAVES)
	# In a turn the inside side pulls down, its back corner most.
	var inside := maxf(-u*signf(_turn),0.0)*absf(_turn)
	y -= PULL*inside*(0.6+0.4*maxf(v,0.0))
	# The sides tuck in where they hang: a sheet, not a flat board.
	var x := u*WIDTH*0.5*(1.0-0.08*u*u)
	var z := v*DEPTH*0.5+0.04*sin(t*RIPPLE_HZ*0.5+u*2.0)*back
	if out < 1.0: y += 0.05*(1.0-open)*sin(u*7.0+v*5.0)
	return Vector3(x*size,y*size,z*size)

func _draw() -> void:
	var size := (0.15+0.85*smoothstep(0.0,1.0,out))*(1.0+_swell)
	var lean := Basis(Vector3.FORWARD,_lean)
	var n := GRID+1
	var points := PackedVector3Array()
	points.resize(n*n)
	for j in range(n):
		for i in range(n):
			var u := 2.0*float(i)/GRID-1.0
			var v := 2.0*float(j)/GRID-1.0
			points[j*n+i] = lean*_point(u,v,size)+Vector3.UP*HIGH
	# Smooth normals (soft cloth), from each point's neighbours.
	var normals := PackedVector3Array()
	normals.resize(n*n)
	for j in range(n):
		for i in range(n):
			var across := points[j*n+mini(i+1,GRID)]-points[j*n+maxi(i-1,0)]
			var along := points[mini(j+1,GRID)*n+i]-points[maxi(j-1,0)*n+i]
			normals[j*n+i] = along.cross(across).normalized()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(GRID):
		for i in range(GRID):
			var hem := i < HEM or j < HEM or i >= GRID-HEM or j >= GRID-HEM
			var colour := TIPS if hem else CLOTH
			var a := j*n+i
			var b := a+1
			var c := a+n
			var d := c+1
			for k in [a,c,b,b,c,d]:
				mesh.surface_set_normal(normals[k])
				mesh.surface_set_color(colour)
				mesh.surface_add_vertex(points[k])
	mesh.surface_end()
	_wing.mesh = mesh
	# The bar the mitts hold, and a line from each end of it to the two
	# corners on its side.
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var bar_l := Vector3(-BAR_HALF,BAR,0.0)
	var bar_r := Vector3(BAR_HALF,BAR,0.0)
	var corners := [points[0],points[GRID],points[GRID*n],points[GRID*n+GRID]]
	for pair: Array in [[bar_l,bar_r],[bar_l,corners[0]],[bar_l,corners[2]],[bar_r,corners[1]],[bar_r,corners[3]]]:
		lines.surface_add_vertex(pair[0])
		lines.surface_add_vertex(pair[1])
	lines.surface_end()
	_lines.mesh = lines
