class_name NativeTerrainTint
extends RefCounted
## Painted ground colour, four float32 per meadow cell: linear RGB plus a blend
## weight. A zero-weight cell contributes nothing, so an untouched layer leaves
## every vertex colour byte-identical to the unpainted build.
const STRIDE := 4

static func make(cells: int) -> PackedFloat32Array:
	var layer := PackedFloat32Array()
	layer.resize(cells*STRIDE)
	layer.fill(0.0)
	return layer

## True while no cell carries weight, which is the state saves and fresh chunks
## start in and the one the renderer short-circuits on.
static func empty(layer: PackedFloat32Array) -> bool:
	for i in range(STRIDE-1,layer.size(),STRIDE):
		if layer[i] != 0.0:
			return false
	return true

static func weight_at(layer: PackedFloat32Array, cell: int) -> float:
	return layer[cell*STRIDE+3]

static func color_at(layer: PackedFloat32Array, cell: int) -> Color:
	var k := cell*STRIDE
	return Color(layer[k],layer[k+1],layer[k+2])

## Lerp the palette colour toward the painted one, carrying the face's own
## shimmer offset into the target so shading detail survives a full-weight coat.
static func blend(base: Color, layer: PackedFloat32Array, cell: int, shimmer: float) -> Color:
	var weight := layer[cell*STRIDE+3]
	if weight <= 0.0:
		return base
	var k := cell*STRIDE
	var target := Color(layer[k]+shimmer,layer[k+1]+shimmer,layer[k+2]+shimmer)
	return base.lerp(target,minf(weight,1.0))

## Over-composite a dab: the new coat takes the share of the resulting weight it
## contributed, so a first stroke lands its colour outright and later strokes mix.
static func paint(layer: PackedFloat32Array, cells: int, step: float, center: Vector2, radius: float, color: Color, amount: float) -> void:
	if radius <= 0.0 or amount <= 0.0:
		return
	var origin := -0.5*float(cells)*step+step*0.5
	var strength := clampf(amount,0.0,1.0)
	for z in range(cells):
		for x in range(cells):
			var distance := Vector2(origin+float(x)*step,origin+float(z)*step).distance_to(center)
			if distance >= radius:
				continue
			var added := strength*(1.0-smoothstep(0.0,radius,distance))
			var k := (z*cells+x)*STRIDE
			var before := layer[k+3]
			var after := before+added*(1.0-before)
			if after <= 0.0:
				continue
			var share := (after-before)/after
			layer[k] = lerpf(layer[k],color.r,share)
			layer[k+1] = lerpf(layer[k+1],color.g,share)
			layer[k+2] = lerpf(layer[k+2],color.b,share)
			layer[k+3] = minf(after,1.0)

## Raise one cell's weight to at least `weight` over what it carried in `base`,
## mixing `color` in by the share the coat adds, as `paint` does. Coating again
## from the same base rewrites the cell, so the caller only ever deepens it.
static func coat(layer: PackedFloat32Array, base: PackedFloat32Array, cell: int, color: Color, weight: float) -> void:
	var k := cell*STRIDE
	var before := base[k+3]
	var after := minf(weight,1.0)
	if after <= before:
		return
	var share := (after-before)/after
	layer[k] = lerpf(base[k],color.r,share)
	layer[k+1] = lerpf(base[k+1],color.g,share)
	layer[k+2] = lerpf(base[k+2],color.b,share)
	layer[k+3] = after

## Wipe painted colour back out, matching the cover brushes' falloff.
static func erase(layer: PackedFloat32Array, cells: int, step: float, center: Vector2, radius: float, amount: float) -> void:
	if radius <= 0.0 or amount <= 0.0:
		return
	var origin := -0.5*float(cells)*step+step*0.5
	for z in range(cells):
		for x in range(cells):
			var distance := Vector2(origin+float(x)*step,origin+float(z)*step).distance_to(center)
			if distance >= radius:
				continue
			var k := (z*cells+x)*STRIDE
			layer[k+3] = maxf(0.0,layer[k+3]-clampf(amount,0.0,1.0)*(1.0-smoothstep(0.0,radius,distance)))
			if layer[k+3] == 0.0:
				layer[k] = 0.0
				layer[k+1] = 0.0
				layer[k+2] = 0.0

## Saved layers are plain number arrays of `cells*STRIDE` values in 0..1.
static func decode(values: Variant, cells: int) -> Variant:
	if not values is Array or values.size() != cells*STRIDE:
		return null
	for value: Variant in values:
		if not GardenData._number(value,0.0,1.0):
			return null
	return PackedFloat32Array(values)
