extends SceneTree
const COLLISIONS = preload("res://scripts/native_play_collisions.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	data.place("tree",Vector2(3,0),0,1)
	data.place("rock",Vector2(-3,0),0,1)
	var collisions := COLLISIONS.new()
	root.add_child(collisions)
	collisions.rebuild(data)
	await physics_frame
	await physics_frame
	var space := root.world_3d.direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0,10,0),Vector3(0,-10,0),1)
	var hit := space.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y)<0.001,"Real authored terrain supports downward physics rays")
	check(collisions.get_child_count()==3,"Authored trees and rocks get solid collision alongside terrain")
	ray = PhysicsRayQueryParameters3D.create(Vector3(-3,4,0),Vector3(-3,-2,0),1)
	hit = space.intersect_ray(ray)
	check(not hit.is_empty() and hit.position.y>0.2,"Rock collider lies above terrain at authored position")
	data.brush(Vector2.ZERO,4,2,"raise",0)
	collisions.rebuild(data)
	await physics_frame
	await physics_frame
	ray = PhysicsRayQueryParameters3D.create(Vector3(0,10,0),Vector3(0,-10,0),1)
	hit = space.intersect_ray(ray)
	check(not hit.is_empty() and absf(hit.position.y-float(data.height_at(0,0)))<0.01,"Rebuild follows sculpted triangle surface exactly")
	check(collisions.get_child_count()==3,"Rebuild replaces old colliders instead of accumulating ghosts")
	check(collisions.can_stand(Vector3(0,float(data.height_at(0,0)),0)),"Ground contact alone does not reject standing clearance")
	check(not collisions.can_stand(Vector3(-3,float(data.height_at(-3,0)),0)),"Standing inside a stone is rejected")
	# A wide rotated object must block its actual volume, beyond any fixed
	# distance-from-record shortcut. Rotate local X width onto world Z.
	var wide_pose := NativeObjectPose.make(Basis(Vector3.UP,PI/2).scaled_local(Vector3(5,2,1)),0)
	data.place("rock",Vector2(0,6),0,1,wide_pose)
	collisions.rebuild(data)
	await physics_frame
	await physics_frame
	check(not collisions.can_stand(Vector3(0,float(data.height_at(0,8.5)),8.5)),"Wide rotated authored pose rejects standing inside its distant edge")
	check(collisions.can_stand(Vector3(2,float(data.height_at(2,6)),6)),"Space beside the narrow axis of a rotated prop remains usable")
	collisions.free()
	print("Native play collisions: ",failures," failures")
	quit(1 if failures else 0)
