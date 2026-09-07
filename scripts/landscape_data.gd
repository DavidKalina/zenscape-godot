class_name LandscapeData
extends RefCounted
## Editable ground. No scene, renderer, or input dependencies.
## A stroke is one history entry, regardless of how many brush dabs it contains.

const CELLS := 48
const WIDTH := 24.0
const STEP := WIDTH / CELLS
const SIDE := CELLS + 1
const MIN_HEIGHT := -0.65
const MAX_HEIGHT := 8.0
const HISTORY_LIMIT := 50

var heights := PackedFloat32Array()
var _undo: Array[PackedFloat32Array] = []
var _redo: Array[PackedFloat32Array] = []
var _before := PackedFloat32Array()

func _init() -> void:
	heights.resize(SIDE * SIDE)
	for z in range(SIDE):
		for x in range(SIDE):
			var p := grid_position(x, z)
			var hill := exp(-((p.x + 4.0) ** 2 + (p.y + 3.0) ** 2) / 38.0)
			heights[z * SIDE + x] = 0.25 + hill * 0.8 + sin(p.x * 0.32) * cos(p.y * 0.27) * 0.10

static func grid_position(x: int, z: int) -> Vector2:
	return Vector2(x * STEP - WIDTH * 0.5, z * STEP - WIDTH * 0.5)

func contains(p: Vector2) -> bool:
	return absf(p.x) <= WIDTH * 0.5 and absf(p.y) <= WIDTH * 0.5

func height_at(p: Vector2) -> float:
	# Match the two triangles in TerrainView, including their shared diagonal.
	var g := (p + Vector2.ONE * WIDTH * 0.5) / STEP
	g = g.clamp(Vector2.ZERO, Vector2.ONE * CELLS)
	var x := mini(int(g.x), CELLS - 1)
	var z := mini(int(g.y), CELLS - 1)
	var u := g.x - x
	var v := g.y - z
	var a := heights[z * SIDE + x]
	var b := heights[z * SIDE + x + 1]
	var c := heights[(z + 1) * SIDE + x]
	var d := heights[(z + 1) * SIDE + x + 1]
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)

func begin_stroke() -> void:
	if _before.is_empty():
		_before = heights.duplicate()

func end_stroke() -> bool:
	if _before.is_empty():
		return false
	var changed := _before != heights
	if changed:
		_undo.append(_before)
		if _undo.size() > HISTORY_LIMIT:
			_undo.pop_front()
		_redo.clear()
	_before = PackedFloat32Array()
	return changed

func brush(center: Vector2, radius: float, strength: float, delta: float, mode: String, level: float) -> void:
	if radius <= 0.0 or delta <= 0.0 or strength <= 0.0:
		return
	var previous := heights.duplicate() if mode == "smooth" else heights
	var g := (center + Vector2.ONE * WIDTH * 0.5) / STEP
	var reach := radius / STEP
	for z in range(maxi(0, int(floor(g.y - reach))), mini(CELLS, int(ceil(g.y + reach))) + 1):
		for x in range(maxi(0, int(floor(g.x - reach))), mini(CELLS, int(ceil(g.x + reach))) + 1):
			var distance := grid_position(x, z).distance_to(center)
			if distance >= radius:
				continue
			var weight := 1.0 - smoothstep(0.0, radius, distance)
			var index := z * SIDE + x
			var value := heights[index]
			match mode:
				"raise": value += strength * delta * weight
				"lower": value -= strength * delta * weight
				"flatten": value = move_toward(value, level, strength * delta * weight)
				"smooth":
					var total := 0.0
					var count := 0
					for nz in range(maxi(0, z - 1), mini(CELLS, z + 1) + 1):
						for nx in range(maxi(0, x - 1), mini(CELLS, x + 1) + 1):
							total += previous[nz * SIDE + nx]
							count += 1
					value = lerpf(value, total / count, 1.0 - exp(-strength * delta * weight * 5.0))
			heights[index] = clampf(value, MIN_HEIGHT, MAX_HEIGHT)

func undo() -> bool:
	end_stroke()
	if _undo.is_empty():
		return false
	_redo.append(heights.duplicate())
	heights = _undo.pop_back()
	return true

func redo() -> bool:
	end_stroke()
	if _redo.is_empty():
		return false
	_undo.append(heights.duplicate())
	heights = _redo.pop_back()
	return true

func to_document() -> Dictionary:
	return {"version": 1, "cells": CELLS, "width": WIDTH, "heights": Array(heights)}

func load_document(document: Variant) -> bool:
	# Validate everything before replacing the existing landscape.
	if not document is Dictionary:
		return false
	if document.get("version") != 1 or document.get("cells") != CELLS or document.get("width") != WIDTH:
		return false
	var values: Variant = document.get("heights")
	if not values is Array or values.size() != SIDE * SIDE:
		return false
	var loaded := PackedFloat32Array()
	for value: Variant in values:
		if not (value is float or value is int):
			return false
		if not is_finite(float(value)) or value < MIN_HEIGHT or value > MAX_HEIGHT:
			return false
		loaded.append(float(value))
	heights = loaded
	_undo.clear()
	_redo.clear()
	_before = PackedFloat32Array()
	return true
