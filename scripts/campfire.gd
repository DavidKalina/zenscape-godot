extends RefCounted
## The campfire (docs/scenic/campfire.md): a ring of faceted stones round a
## dark bed of ash, a little teepee of sticks laid in it. Solid and faceted,
## like the stone lamp (scripts/stone_lamp.gd) and the river stone. The fire
## itself (the flame, the glow, the smoke, sparks and light) is not here but
## in scripts/campfire_fire.gd: soft things, drawn over this.
##
## The mesh is drawn by GardenView as asset "campfire" on the stones'
## material (vertex colours, flat faces), one batch for every campfire.
##
## Also where a campfire may stand (`refusal`): the hand asks before it sets
## one down.

## Every size below is times UNIT (m at record scale 1): the ring is about a
## metre across.
const UNIT := 1.0
## The ring: STONES stones at RING m from the middle.
const STONES := 9
const RING := 0.46
const STONE_TONES := [Color("8f8a80"),Color("a39d92"),Color("7d786f")]
const ASH := Color("3a3530")
const BARK := Color("6b4a30")
const CHAR := Color("2b241f")
## The sticks: STICKS leaned in from STICK_FOOT m out, meeting STICK_TOP up.
const STICKS := 5
const STICK_FOOT := 0.25
const STICK_TOP := 0.36
const STICK_RADIUS := 0.032
## Where the flame stands (record space, m): its foot, in the middle.
const FLAME_FOOT := 0.05
## What scripts/campfire_fire.gd needs: the fire's middle height (m).
const FIRE_HEIGHT := 0.28

## Where it may not stand. Slope as rise over run (presets `_slope`); CLEAR m
## to another campfire (foot to foot); a tree's foot keeps TREE_CLEAR m times
## its scale (at least TREE_MIN m) clear, so no fire is set under a crown or
## into a trunk.
const STEEP := 0.45
const CLEAR := 3.0
const TREE_CLEAR := 1.7
const TREE_MIN := 1.1
const TREES := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","joshua","birch","willow","juniper","snag"]

static var _mesh: ArrayMesh

## The campfire, built once and shared.
static func mesh() -> ArrayMesh:
	if _mesh != null: return _mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Fixed, so every campfire is the same campfire (each turned its own way).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	# The bed of ash, a low six-sided mound.
	_prism(surface,7,0.4,0.33,-0.02,0.025,ASH,0.2)
	# The ring: squat faceted stones, each its own size and lean.
	for k in range(STONES):
		var angle := TAU*k/STONES+rng.randf_range(-0.12,0.12)
		var at := Vector2(cos(angle),sin(angle))*(RING+rng.randf_range(-0.03,0.03))
		var size := Vector3(rng.randf_range(0.12,0.16),rng.randf_range(0.085,0.12),rng.randf_range(0.1,0.13))
		var turn := Basis(Vector3.UP,-angle+rng.randf_range(-0.3,0.3))*Basis(Vector3.RIGHT,rng.randf_range(-0.2,0.2))
		_stone(surface,at,size,turn,STONE_TONES[k%STONE_TONES.size()])
	# The sticks, leaned in, charred where they meet the fire.
	for k in range(STICKS):
		var angle := TAU*k/STICKS+0.4+rng.randf_range(-0.15,0.15)
		var foot := Vector3(cos(angle)*STICK_FOOT,0.0,sin(angle)*STICK_FOOT)
		var top := Vector3(cos(angle+0.5)*0.03,STICK_TOP+rng.randf_range(-0.03,0.03),sin(angle+0.5)*0.03)
		_stick(surface,foot,foot.lerp(top,0.55),STICK_RADIUS,BARK)
		_stick(surface,foot.lerp(top,0.55),top,STICK_RADIUS*0.85,CHAR)
	# A short split log lying across the ash.
	_stick(surface,Vector3(-0.17,0.035,0.1),Vector3(0.15,0.04,0.14),0.038,CHAR)
	surface.generate_normals()
	_mesh = surface.commit()
	return _mesh

## An upright n-sided prism from `low` to `high` (m), `bottom` and `top` its
## corner radii, turned `turn` about the up axis.
static func _prism(surface: SurfaceTool, sides: int, bottom: float, top: float, low: float, high: float, colour: Color, turn: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom*UNIT
	cylinder.top_radius = top*UNIT
	cylinder.height = (high-low)*UNIT
	cylinder.radial_segments = sides
	cylinder.rings = 0
	_add(surface,cylinder.get_faces(),Transform3D(Basis(Vector3.UP,turn),Vector3(0.0,(low+high)*0.5*UNIT,0.0)),colour)

## A squat faceted stone at `at` (x, z), half-sizes `size`, sunk a little.
static func _stone(surface: SurfaceTool, at: Vector2, size: Vector3, turn: Basis, colour: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var pose := Transform3D(turn*Basis.from_scale(size*UNIT),Vector3(at.x,size.y*0.55,at.y)*UNIT)
	_add(surface,sphere.get_faces(),pose,colour)

## A six-sided stick from `a` to `b` (m), `radius` thick.
static func _stick(surface: SurfaceTool, a: Vector3, b: Vector3, radius: float, colour: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius*UNIT
	cylinder.bottom_radius = radius*UNIT
	cylinder.height = a.distance_to(b)*UNIT
	cylinder.radial_segments = 6
	cylinder.rings = 0
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side,up,side.cross(up))
	_add(surface,cylinder.get_faces(),Transform3D(basis,(a+b)*0.5*UNIT),colour)

static func _add(surface: SurfaceTool, faces: PackedVector3Array, pose: Transform3D, colour: Color) -> void:
	var linear := colour.srgb_to_linear()
	for vertex in faces:
		surface.set_color(linear)
		surface.add_vertex(pose*vertex)

## Why a campfire may not stand at plate point `p` in `editor`'s world, or
## "" when it may: "water" (live water, a pond, lake or stream), "steep",
## "near" (another campfire within CLEAR m) or "tree" (under or into one).
static func refusal(editor: Node, p: Vector2) -> String:
	var data: NativeTerrainData = editor.data
	if data.ground_height(p) == null: return "water"
	var dry: Callable = editor.fence_dry()
	# The ring's edge as well as its middle: no fire half in a pond.
	for offset in [Vector2.ZERO,Vector2(RING,0.0),Vector2(-RING,0.0),Vector2(0.0,RING),Vector2(0.0,-RING)]:
		if data.ground_height(p+offset) == null or not dry.call(p+offset): return "water"
	if preload("res://scripts/native_landscape_presets.gd")._slope(data,p) > STEEP: return "steep"
	for item: Dictionary in data.objects:
		var foot := Vector2(float(item.x),float(item.z))
		var asset := str(item.asset)
		if asset == "campfire" and foot.distance_to(p) < CLEAR: return "near"
		if asset in TREES and foot.distance_to(p) < maxf(TREE_MIN,TREE_CLEAR*float(item.scale)): return "tree"
	return ""
