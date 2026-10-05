extends SceneTree
const Plate = preload("res://scripts/plate.gd")
const Walkways = preload("res://scripts/log_walkways.gd")
class RiverHabitat extends "res://scripts/fidelity_habitat.gd":
	func ground_height(point: Vector2) -> Variant:
		return -0.8 if absf(point.x)<0.85 else 0.0
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var habitat := RiverHabitat.new()
	var catalog := NativePlayCollisions.new()
	catalog._load_bounds()
	var pose := Transform3D(Basis.from_scale(Vector3(4,0.8,4)),Vector3(0,-0.07,0))
	var box: AABB = pose*catalog._bounds.log
	habitat.walkways.add(1,pose,box,habitat.ground_height)
	check(habitat.walkways.surfaces.size()==1,"A broad log resting on both banks qualifies")
	var center: Dictionary = habitat.walkways.at(Vector2.ZERO)
	check(not center.is_empty() and center.height>0.0,"Feet use the visible log top above water")
	check(habitat.walkways.at(Vector2(0,1.0)).is_empty(),"No invisible support beside the log")
	habitat.solids.append(box)
	habitat._index_solids()
	habitat.streams.append({"pts":[{"x":0.0,"z":-Plate.HALF,"h":-0.5},{"x":0.0,"z":Plate.HALF,"h":-0.5}],"width":0.6,"surface":0.0})
	var nav := CreatureNavigation.new()
	nav.rebuild(habitat,habitat.clear_at,0.35,0.3)
	var route := nav.path(Vector3(-3,0,0),Vector3(3,0,0))
	check(not route.is_empty(),"Normal navigation finds a dry route across the placed log")
	for i in range(1,route.size()):
		check(nav.segment_safe(route[i-1],route[i]),"Every returned crossing segment is swept and supported")
	var snapshot = habitat.navigation_snapshot()
	check(not snapshot.walkways.at(Vector2.ZERO).is_empty(),"Worker snapshots retain the same real log support")
	habitat.walkways.disabled[1] = true
	check(habitat.walkways.at(Vector2.ZERO).is_empty(),"A log in physical motion immediately loses its stored support")
	check(not snapshot.walkways.at(Vector2.ZERO).is_empty(),"Worker snapshot support is isolated from later live edits")
	var disabled_snapshot = habitat.navigation_snapshot()
	check(disabled_snapshot.walkways.at(Vector2.ZERO).is_empty(),"New snapshots honor physically displaced logs")
	habitat.walkways.disabled.clear()
	# An unrelated obstacle still blocks the crossing deck.
	habitat.solids.append(AABB(Vector3(-0.4,0,-1),Vector3(0.8,3,2)))
	habitat._index_solids()
	nav.rebuild(habitat,habitat.clear_at,0.35,0.3)
	check(nav.path(Vector3(-3,0,0),Vector3(3,0,0)).is_empty(),"Other solids cannot be ignored on a log")
	habitat.solids.clear()
	habitat._index_solids()
	habitat.walkways.surfaces.clear()
	nav.rebuild(habitat,habitat.clear_at,0.35,0.3)
	check(nav.path(Vector3(-3,0,0),Vector3(3,0,0)).is_empty(),"Deleting the log disconnects the banks")
	pose.origin.y += 1.0
	habitat.walkways.add(2,pose,pose*catalog._bounds.log,habitat.ground_height)
	check(habitat.walkways.surfaces.is_empty(),"A floating log never grants a crossing")
	catalog.free()
	print("LOG WALKWAYS: failures=",failures)
	quit(1 if failures else 0)
