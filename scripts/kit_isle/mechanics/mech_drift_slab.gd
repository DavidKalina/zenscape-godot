extends "res://scripts/kit_isle/mechanics/mechanic.gd"
## A drifting slab, the ferry (scripts/interactables/drift_slab.gd, laid by
## FootPieces `drift_slab`): its top's middle `lift` m over the spot, then
## to the point (`to_x`, `to_y`, `to_z`) m from there in the slab's own
## frame (along the arrow is -z), then on through `more` ("x,y,z; x,y,z":
## more points the same way, from the first), there and back easing at each
## end, or round (`loop`) at an even pace; `pace` m/s along the way, `spin`
## rad/s about its middle. The way shows as a line while editing.

func _init() -> void:
	super()
	trap_name = "drift_slab"
	verbs = PackedStringArray(["jump","ride"])

func defaults() -> Dictionary:
	return {"lift":1.0,"to_x":0.0,"to_y":0.0,"to_z":-10.0,"more":"","pace":2.0,"loop":false,"spin":0.0,
		"width":2.4,"thick":0.6,"depth":2.4,"seed":0}

## The path's points in the trap's frame.
func local_path() -> PackedVector3Array:
	var first := Vector3(0.0,float(knobs.lift),0.0)
	var out := PackedVector3Array([first,first+Vector3(float(knobs.to_x),float(knobs.to_y),float(knobs.to_z))])
	for part: String in str(knobs.get("more","")).split(";",false):
		var xyz := part.strip_edges().split(",",false)
		if xyz.size() != 3: continue
		out.append(first+Vector3(xyz[0].to_float(),xyz[1].to_float(),xyz[2].to_float()))
	return out

func world_path(frame: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in local_path(): out.append(frame*p)
	return out

func lay(pieces: Node3D, frame: Transform3D) -> void:
	var path := world_path(frame)
	var loop := bool(knobs.loop) and path.size() > 2
	var total := 0.0
	for i in range(1,path.size()): total += path[i-1].distance_to(path[i])
	if loop: total += path[path.size()-1].distance_to(path[0])
	var period := (total if loop else total*2.0)/maxf(float(knobs.pace),0.1)
	pieces.drift_slab(path,period,loop,float(knobs.spin),Vector3(float(knobs.width),float(knobs.thick),float(knobs.depth)),yaw_of(frame),int(knobs.seed))

func hint_path() -> PackedVector3Array:
	var out := PackedVector3Array([global_position])
	out.append_array(world_path(global_transform))
	if bool(knobs.loop) and out.size() > 3: out.append(out[1])
	return out
