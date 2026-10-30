extends Node3D
## The ground the burrower runs in (burrower.gd, push_ups.gd,
## tree_shudder.gd): what they ask of the land. The study's land
## (burrower_land.gd) and endless flight's (game_land.gd) fill it in.

## Trees to steer beside and shudder (Node3D each, at its trunk's foot).
var trees: Array = []
## The water's shader to feed the wake (null: no pond to draw it on).
var pond_material: ShaderMaterial

## The land's height at (x, z) (a lake's or the sea's bed, not its water).
func height(_x: float, _z: float) -> float:
	return 0.0

## The ground's normal at (x, z).
func normal(x: float, z: float) -> Vector3:
	var e := 0.75
	return Vector3(height(x-e,z)-height(x+e,z),2.0*e,height(x,z-e)-height(x,z+e)).normalized()

## The ground mesh's own height as drawn, for things laid on it.
func mesh_height(x: float, z: float) -> float:
	return height(x,z)

## The ground's colour (sRGB) at (x, z), of height `y` and normal `nm`.
func colour(_x: float, _z: float, _y: float, _nm: Vector3) -> Color:
	return Color("466b30")

## The water's surface over (x, z) (under the ground where there is none).
func water_y(_x: float, _z: float) -> float:
	return -INF

## How far inside the edge of where it may run `at` lies (m; INF: no edge).
func room(_at: Vector2) -> float:
	return INF

## The way back in from the edge at `at` (unit; zero with no edge).
func inward(_at: Vector2) -> Vector2:
	return Vector2.ZERO

## Stone to steer round: {"at": Vector2 (xz), "reach": m} each.
func stone() -> Array:
	return []

## Whether it can run through (x, z) (`at`). The study lists its stone and
## trees and keeps it in by the rim, so it says yes; a land with no such
## lists (the game's) answers here, and sets `probes` so the creature feels
## ahead with it.
var probes := false
func open(_at: Vector2) -> bool:
	return true

## A wall at (x, z) it can't run on through (a cliff, a ruin wall, stone),
## where it sounds rather than steer (a land that `probes`).
func wall(_at: Vector2) -> bool:
	return false

## The stood trees within `r` m of `at`, 4 floats each (x, z, foot y, height),
## for a land with no tree nodes (`probes`): to weave and to shudder.
func trees_near(_at: Vector2, _r: float) -> PackedFloat32Array:
	return PackedFloat32Array()

## The top (world y) of the tallest tree within `r` m of `at`, or -INF: a
## forest's roof, for a plane skimming it and a push-up rising through it.
func canopy_top(_at: Vector2, _r: float) -> float:
	return -INF

## The middle of the thickest stand of trees ahead of `at` along `fwd`
## (unit), within `most` m (NAN when none).
func stand_ahead(_at: Vector2, _fwd: Vector2, _most: float) -> Vector2:
	return Vector2(NAN,NAN)

## The pond for the dust to fade into (x, z, radius, water y; radius < 0: none).
func pond_rect() -> Vector4:
	return Vector4(0.0,0.0,-1.0,0.0)
