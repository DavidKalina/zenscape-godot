class_name GardenData
extends LandscapeData
## The saved garden is independent of meshes, scene nodes and animation clocks.
## Meadow cells have stable seeds; objects retain explicit positions and IDs.

const MAX_OBJECTS := 20000
const MAX_PONDS := 256
const ASSETS := ["tree", "rock", "flower"]
const WEATHER := ["Clear", "Mist", "Rain", "Snow"]
var meadow := PackedFloat32Array()
var objects: Array[Dictionary] = []
var ponds: Array[Dictionary] = []
var weather := "Clear"
var next_id := 1

func _init() -> void:
	super()
	meadow.resize(CELLS * CELLS)
	meadow.fill(0.0)

func paint_meadow(center: Vector2, radius: float, amount: float) -> void:
	for z in range(CELLS):
		for x in range(CELLS):
			var point := grid_position(x, z) + Vector2.ONE * STEP * 0.5
			var distance := point.distance_to(center)
			if distance < radius:
				var index := z * CELLS + x
				meadow[index] = clampf(meadow[index] + amount * (1.0 - smoothstep(0.0, radius, distance)), 0.0, 1.0)

func place(kind: String, point: Vector2, angle := 0.0, size := 1.0) -> int:
	if kind not in ASSETS or not contains(point) or objects.size() >= MAX_OBJECTS or next_id >= 2147483647 or not _number(angle, -TAU * 100, TAU * 100) or not _number(size, 0.1, 5.0):
		return -1
	var id := next_id
	next_id += 1
	objects.append({"id": id, "asset": kind, "x": point.x, "z": point.y, "angle": angle, "scale": size})
	return id

func object_position(item: Dictionary) -> Vector3:
	var point := Vector2(item.x, item.z)
	return Vector3(point.x, height_at(point), point.y)

func erase_objects(point: Vector2, radius: float) -> void:
	objects = objects.filter(func(item: Dictionary) -> bool: return Vector2(item.x, item.z).distance_to(point) > radius)

func add_pond(point: Vector2, level: float) -> bool:
	if not contains(point) or not is_finite(level) or level <= height_at(point) or level > MAX_HEIGHT:
		return false
	for pond: Dictionary in ponds:
		if Vector2(pond.x, pond.z).is_equal_approx(point):
			pond.level = level
			return true
	if ponds.size() >= MAX_PONDS:
		return false
	ponds.append({"x": point.x, "z": point.y, "level": level})
	return true

func reset_flat() -> void:
	heights.fill(0.0)
	meadow.fill(0.0)
	objects.clear()
	ponds.clear()
	weather = "Clear"
	next_id = 1

func _snapshot() -> Dictionary:
	return {"heights": heights.duplicate(), "meadow": meadow.duplicate(), "objects": objects.duplicate(true), "ponds": ponds.duplicate(true), "weather": weather, "next_id": next_id}

func _restore(snapshot: Dictionary) -> void:
	heights = snapshot.heights.duplicate()
	meadow = snapshot.meadow.duplicate()
	objects.assign(snapshot.objects.duplicate(true))
	ponds.assign(snapshot.ponds.duplicate(true))
	weather = snapshot.weather
	next_id = snapshot.next_id

func to_document() -> Dictionary:
	return {"version": 2, "cells": CELLS, "width": WIDTH, "heights": Array(heights), "meadow": Array(meadow), "objects": objects.duplicate(true), "ponds": ponds.duplicate(true), "weather": weather, "next_id": next_id}

func load_document(document: Variant) -> bool:
	if not document is Dictionary:
		return false
	# Validate in a temporary model so a bad field cannot partially replace a garden.
	var ground := LandscapeData.new()
	var terrain_document: Dictionary = document.duplicate(true)
	if not _integer(document.get("version")) or int(document.version) not in [1, 2]:
		return false
	terrain_document.version = 1
	if not ground.load_document(terrain_document):
		return false
	var candidate := GardenData.new()
	candidate.heights = ground.heights
	if document.version == 2:
		var values: Variant = document.get("meadow")
		if not values is Array or values.size() != CELLS * CELLS:
			return false
		for i in range(values.size()):
			if not _number(values[i], 0.0, 1.0):
				return false
			candidate.meadow[i] = values[i]
		if document.get("weather") not in WEATHER:
			return false
		candidate.weather = document.weather
		if not document.get("objects") is Array or document.objects.size() > MAX_OBJECTS:
			return false
		var ids := {}
		for item: Variant in document.objects:
			if not item is Dictionary or item.get("asset") not in ASSETS or not _point_valid(item):
				return false
			if not _number(item.get("angle"), -TAU * 100, TAU * 100) or not _number(item.get("scale"), 0.1, 5.0):
				return false
			if not _integer(item.get("id")) or item.id < 1 or ids.has(item.id):
				return false
			ids[item.id] = true
			var restored: Dictionary = item.duplicate(true)
			restored.id = int(item.id)
			candidate.objects.append(restored)
		if not _integer(document.get("next_id")) or document.next_id < 1:
			return false
		for id: Variant in ids:
			if id >= document.next_id:
				return false
		candidate.next_id = int(document.next_id)
		if not document.get("ponds") is Array or document.ponds.size() > MAX_PONDS:
			return false
		for pond: Variant in document.ponds:
			if not pond is Dictionary or not _point_valid(pond) or not _number(pond.get("level"), MIN_HEIGHT, MAX_HEIGHT):
				return false
			candidate.ponds.append(pond.duplicate(true))
	_restore(candidate._snapshot())
	_undo.clear()
	_redo.clear()
	_before = {}
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

static func _integer(value: Variant) -> bool:
	return _number(value, 0, 2147483647) and float(value) == floor(float(value))

static func _point_valid(value: Dictionary) -> bool:
	return _number(value.get("x"), -WIDTH * 0.5, WIDTH * 0.5) and _number(value.get("z"), -WIDTH * 0.5, WIDTH * 0.5)
