extends Node3D
## The pocket sail, drawn (scripts/pocket_sail.gd flies it): the wanderer's
## "float with cap". He holds on to his hat: as the sail opens it comes off
## his head into his raised mitts, and he hangs from it, gripping the brim
## overhead one mitt either side, the hat crown up like a little parasol.
## Held, it does not spin: it sways and tips into a turn on a spring
## (`update`'s `turning`), rocking gently as it floats, and his body swings
## a beat behind under it (`swing`, read by scripts/pilot_figure.gd, which
## also reaches his mitts to `grips()` and lifts his shoulders to it). A
## faint cyan ring glows under the brim's edge, brighter in rising air
## (`lift`, 0 to 1: a thermal ridden): the tech in the cap. Folded, it goes
## back on his head. Put on the pilot's figure (its origin at the feet,
## facing -Z), as his body is: `update` each frame lifts it over OPEN_TIME
## as it opens, brings it down over FOLD_TIME. While it is out his figure
## hides the hat on his head (scripts/pilot_figure.gd), so there is only
## ever one.
##
## The hat is the model's own (assets/models/pilot.glb, its PilotPaint.HAT
## surfaces lifted off the skinned mesh once and kept), in its paint.

const PilotPaint = preload("res://scripts/pilot_paint.gd")
const Spring = preload("res://scripts/person_kit.gd").Spring
## Where the hat sits on his head (m, the model's frame, standing: art/
## blender/pilot/pilot_build.py PILOT_HAT less the rest's 0.029 m) and its
## tip back there (radians, the build's HAT_TILT), and how high over that
## he holds it up (m: round four, clear of his head, as high as his arms
## stretched long reach it; round three's 0.1 left it on his head's top).
## The brim is gripped on its underside GRIP m out from the crown, either
## side and swept GRIP_BACK (radians) round towards the back, so the mitts
## show at its edge to the chase camera behind him.
const ON_HEAD := Vector3(0.0,1.046,0.0)
const REST_HIPS_DROP := 0.029
const TIP := 0.03
const HOLD := 0.26
const GRIP := 0.44
const GRIP_BACK := 0.6
## Held, it tips forward (radians: the brim's back up, its front down, so
## the chase camera behind him sees a little under it).
const HOLD_PITCH := 0.12
## Seconds out and away; the swell over its height as it opens (m).
const OPEN_TIME := 0.18
const FOLD_TIME := 0.12
const SWELL := 0.03
## Held: its tip into a turn (radians at a full turn) on a spring (Hz,
## damping), the body's swing after it on a slower one, the rock of it
## floating (radians, Hz) and its bob (m, Hz).
const LEAN := 0.3
const LEAN_SPRING := Vector2(1.5,0.32)
const SWING := 0.75
const SWING_SPRING := Vector2(0.9,0.38)
const ROCK := 0.05
const ROCK_HZ := 0.55
const BOB := 0.012
const BOB_HZ := 1.1
## The glow round the brim's rolled edge, just under it: how far in and
## down from the edge's outside (m), its thickness, how bright, and how
## much brighter in rising air.
const RING := Vector2(0.012,0.012)
const RING_THICK := 0.007
const RING_ALPHA := 0.45
const RING_LIFT := 0.8

## 0 packed to 1 out (with the swell over it as it opens).
var out := 0.0
## The body's swing under it (radians about his back-to-front axis, as the
## hat's tip: his right side up positive, into a left turn): the hat's tip,
## a beat behind.
var swing := 0.0
var _swell := 0.0
var _time := 0.0
var _lift := 0.0
var _lean := Spring.new(LEAN_SPRING.x,LEAN_SPRING.y)
var _swing := Spring.new(SWING_SPRING.x,SWING_SPRING.y)
var _hat: MeshInstance3D
var _ring: MeshInstance3D
var _ring_paint: StandardMaterial3D
static var _hat_mesh: ArrayMesh
static var _grip_y := NAN

func _init() -> void:
	name = "PocketSail"
	_hat = MeshInstance3D.new()
	_hat.name = "Cap"
	_hat.mesh = hat_mesh()
	_hat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_hat)
	_ring_paint = StandardMaterial3D.new()
	_ring_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_paint.albedo_color = Color(PilotPaint.GLOW,RING_ALPHA)
	_ring = MeshInstance3D.new()
	_ring.name = "Glow"
	_ring.mesh = edge_glow()
	_ring.material_override = _ring_paint
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hat.add_child(_ring)
	visible = false

## The hat, lifted off the model (its PilotPaint.HAT surfaces, unskinned),
## its brim's root at the origin, level, in the pilot's paint.
static func hat_mesh() -> ArrayMesh:
	if _hat_mesh != null: return _hat_mesh
	var at := Transform3D(Basis(Vector3.RIGHT,-TIP),Vector3.ZERO)*Transform3D(Basis(),-(ON_HEAD+Vector3.UP*REST_HIPS_DROP))
	_hat_mesh = PilotPaint.lift(PilotPaint.HAT,at,PilotPaint.outfit())
	return _hat_mesh

static var _edge: ArrayMesh

## A thin glowing tube round the brim's edge, under it, following its
## droop and ripple (read off the hat's mesh: its outermost point in each
## of 128 slices round), made once.
static func edge_glow() -> ArrayMesh:
	if _edge != null: return _edge
	var slices := 128
	var far: Array[Vector3] = []
	far.resize(slices)
	var reach := PackedFloat32Array()
	reach.resize(slices)
	var mesh := hat_mesh()
	for s in range(mesh.get_surface_count()):
		var points: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in points:
			var r := Vector2(p.x,p.z).length()
			var k := int(fposmod(atan2(p.x,-p.z)/TAU,1.0)*slices)%slices
			if r > reach[k] or (r > reach[k]-0.004 and p.y < far[k].y):
				reach[k] = maxf(r,reach[k])
				far[k] = p
	var path: Array[Vector3] = []
	for k in range(slices):
		var p := far[k]
		var out := Vector3(p.x,0.0,p.z).normalized()
		path.append(p-out*RING.x+Vector3.DOWN*RING.y)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	for k in range(slices):
		var a := path[k]
		var b := path[(k+1)%slices]
		var along_a := (path[(k+1)%slices]-path[(k-1+slices)%slices]).normalized()
		var along_b := (path[(k+2)%slices]-path[k]).normalized()
		for i in range(sides):
			var corners: Array[Vector3] = []
			for c in [[a,along_a,i],[b,along_b,i],[b,along_b,i+1],[a,along_a,i+1]]:
				var at: Vector3 = c[0]
				var along: Vector3 = c[1]
				var side := along.cross(Vector3.UP).normalized()
				var up := side.cross(along).normalized()
				var t := TAU*float(c[2])/sides
				corners.append(at+(side*cos(t)+up*sin(t))*RING_THICK)
			for j in [0,1,2,0,2,3]: tool.add_vertex(corners[j])
	_edge = tool.commit()
	return _edge

## How far under the brim's root its underside is at the grips (m, the
## hat's frame), read off the mesh once.
static func grip_drop() -> float:
	if not is_nan(_grip_y): return _grip_y
	var low := 0.0
	var found := false
	var mesh := hat_mesh()
	for s in range(mesh.get_surface_count()):
		var points: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in points:
			if absf(absf(p.x)-GRIP*cos(GRIP_BACK)) < 0.02 and absf(p.z-GRIP*sin(GRIP_BACK)) < 0.03 and (not found or p.y < low):
				low = p.y
				found = true
	_grip_y = low if found else -0.05
	return _grip_y

## Where his mitts hold the brim (world): left, right; empty when packed.
func grips() -> Array[Vector3]:
	if not visible: return []
	var y := grip_drop()
	var x := GRIP*cos(GRIP_BACK)
	var z := GRIP*sin(GRIP_BACK)
	return [_hat.global_transform*Vector3(-x,y,z),_hat.global_transform*Vector3(x,y,z)]

## Packed away at once.
func reset() -> void:
	out = 0.0
	_swell = 0.0
	_lift = 0.0
	swing = 0.0
	for spring: Spring in [_lean,_swing]:
		spring.x = 0.0
		spring.v = 0.0
	visible = false

## One frame: `open` whether it is out, `turning` -1 right to 1 left,
## `lift` 0 to 1 how hard rising air holds it up.
func update(delta: float, open: bool, turning := 0.0, lift := 0.0) -> void:
	var was := out
	out = move_toward(out,1.0 if open else 0.0,delta/(OPEN_TIME if open else FOLD_TIME))
	if open and was < 1.0 and out >= 1.0: _swell = SWELL
	_swell = move_toward(_swell,0.0,delta*0.25)
	_time += delta
	_lift = lerpf(_lift,clampf(lift,0.0,1.0),1.0-exp(-delta/0.4))
	var lean := _lean.step(clampf(turning,-1.0,1.0)*LEAN*out,delta)
	swing = _swing.step(lean*SWING,delta)
	visible = out > 0.01
	if visible: _draw(lean)

func _draw(lean: float) -> void:
	var up := smoothstep(0.0,1.0,out)
	# Off his head and up into his hands: tipped into a turn, rocking and
	# bobbing a little as it floats.
	var t := _time*TAU
	var height := ON_HEAD.y+(HOLD+_swell+BOB*sin(t*BOB_HZ))*up
	var rock := Basis(Vector3.RIGHT,ROCK*up*sin(t*ROCK_HZ))*Basis(Vector3.BACK,0.4*ROCK*up*sin(t*ROCK_HZ*0.7+1.0))
	var tip := Basis(Vector3.RIGHT,TIP*(1.0-up)-HOLD_PITCH*up)
	_hat.transform = Transform3D(Basis(Vector3.BACK,lean)*rock*tip,Vector3(0.0,height,0.0))
	# The ring glows once it is off his head, breathing, brighter in rising
	# air.
	var shine := smoothstep(0.35,1.0,out)
	_ring.visible = shine > 0.01
	_ring_paint.albedo_color = Color(PilotPaint.GLOW,RING_ALPHA*shine*(1.0+RING_LIFT*_lift)*(0.85+0.15*sin(t*1.5)))
