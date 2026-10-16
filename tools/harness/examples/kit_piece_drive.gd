extends "res://tools/harness/drive.gd"
## Skeleton: a route on one kit piece in studies/kit_piece_yard.tscn, real
## input. Copy into scratch/, then
##   python tools/drive.py scratch/x_drive.gd -- --route=front --scene-args --piece=<id> --seed=3 --weathered=0.4
## The piece is `first("Piece")` at the origin (front +Z); its meta (lines,
## tops, ropes) gives the targets. Ropes hang in the yard's "RopeHost".

func drive() -> void:
	await open("studies/kit_piece_yard.tscn")
	var piece: Node3D = first("Piece")
	check(piece != null, "the piece stands")
	if piece == null: return
	note("meta: %s" % str(piece.get_meta_list()))
	var box := (piece.get_node("Mesh") as MeshInstance3D).get_aabb()
	# Stand in front, face it, walk at it and jump halfway (a first lip).
	await place(Vector3(box.get_center().x, 0.0, box.end.z + 3.0), Vector2(0, -1))
	var got := await walk_to(Vector3(box.get_center().x, 0.0, box.end.z - 0.2), 400, 0.5, 0.5)
	check(got or motor.feet.y > 0.3, "reached the piece's front", "feet %s" % motor.feet)
	result("feet_y", motor.feet.y)
