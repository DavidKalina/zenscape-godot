extends RefCounted
## Where the cameras look: the island's land (NativeTerrainData `land_rect`,
## plate XZ), not the plate's grid, so a small island fills the view and the
## biggest one still fits. Distances tuned on the old 28 m square
## (Plate.LEGACY_HALF each way) are scaled by `scale`, and reaches are read
## off the land's own sides, so that square frames as it always did.

const Plate = preload("res://scripts/plate.gd")
## The square every camera was tuned on.
const LEGACY := Rect2(-Plate.LEGACY_HALF,-Plate.LEGACY_HALF,Plate.LEGACY_HALF*2.0,Plate.LEGACY_HALF*2.0)

## The land's bounds in plate XZ; the old square with no land to read.
static func rect(data: NativeTerrainData) -> Rect2:
	if data == null or data.vertex_ids.is_empty(): return LEGACY
	var bounds := data.land_rect()
	return bounds if bounds.has_area() else LEGACY

## The middle of the land's bounds, in plate XZ.
static func centre(data: NativeTerrainData) -> Vector2:
	return rect(data).get_center()

## Half the land's longer side (m): 14 on the old square.
static func half(data: NativeTerrainData) -> float:
	var size := rect(data).size
	return maxf(size.x,size.y)*0.5

## How much bigger the land is than the old square (1 on it).
static func scale(data: NativeTerrainData) -> float:
	return half(data)/Plate.LEGACY_HALF

## How far the cameras' pivot may wander: each side of the land, `inset` m
## in, stretched by `stretch` from the middle, and, given a `room`, never
## less than that many metres past the shore, so the shore can always be
## looked at. On the old square (inset 0.5, stretch 1.4, room 4.9) that is
## the 18.9 m either way the shell's camera always had.
static func reach(data: NativeTerrainData, inset := 0.5, stretch := 1.0, room := -INF) -> Rect2:
	var bounds := rect(data)
	var middle := bounds.get_center()
	var halves := bounds.size*0.5
	var out := Vector2(maxf((halves.x-inset)*stretch,halves.x+room),maxf((halves.y-inset)*stretch,halves.y+room))
	return Rect2(middle-out,out*2.0)

## A plate point (x and z of `local`) put inside `area`.
static func clamp_local(local: Vector3, area: Rect2) -> Vector3:
	local.x = clampf(local.x,area.position.x,area.end.x)
	local.z = clampf(local.z,area.position.y,area.end.y)
	return local

## Whether a plate point (x and z of `local`) lies strictly inside `area`.
static func holds(area: Rect2, local: Vector3) -> bool:
	return local.x > area.position.x and local.x < area.end.x and local.z > area.position.y and local.z < area.end.y

## A spot on the land to aim for: the bounds' middle, or, where that is off
## the island (a crescent, a ring), the land nearest it, `inset` m in.
static func middle(data: NativeTerrainData, inset := 0.5) -> Vector2:
	var at := centre(data)
	if data == null or data.vertex_ids.is_empty() or data.has_land(at): return at
	var land := data.nearest_land(at,inset)
	if land == Vector2.INF: land = data.nearest_land(at)
	return land if land != Vector2.INF else at
