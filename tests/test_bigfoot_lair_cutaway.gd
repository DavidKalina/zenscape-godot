extends SceneTree
## Standalone cave-room checks: closed walls dissolve one at a time when inspected.
const Lair = preload("res://scripts/bigfoot_lair_room.gd")
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1

func settle(room: Node3D) -> void:
	for frame in range(90): room.advance_cutaway(1.0/60.0)

func run() -> void:
	var room := Lair.new()
	room.position = Vector3(0,-11,0)
	root.add_child(room)
	var walls: Array = room.get_node("RockWalls").get_children()
	check(walls.size()==4 and room.wall_reveal.max()==0.0,"The lower story starts as four closed walls")
	var middle: Vector3 = room.global_position+Vector3(0,4,0)
	var aim := func(from: Vector3) -> int: return room.side_under_ray(from,(middle-from).normalized())
	check(aim.call(Vector3(0,-7,60))==0 and aim.call(Vector3(60,-7,0))==1 and aim.call(Vector3(0,-7,-60))==2 and aim.call(Vector3(-60,-7,0))==3,"Pointing at a side picks that wall")
	check(room.side_under_ray(Vector3(3,40,2),Vector3.DOWN)==-1,"Pointing down through the surface chunk never opens the cave")
	check(room.side_under_ray(Vector3(0,-7,60),Vector3.BACK)==-1,"Pointing away from the room opens nothing")
	room.open_wall(1)
	settle(room)
	check(room.wall_reveal[1]==1.0 and room.wall_reveal[0]+room.wall_reveal[2]+room.wall_reveal[3]==0.0,"Only the inspected wall dissolves")
	var earth: Array = walls.map(func(wall: Node) -> Node: return wall.get_node("Earth"))
	check(walls[1].material_override.get_shader_parameter("cutaway_reveal")==1.0 and walls[0].material_override.get_shader_parameter("cutaway_reveal")==0.0,"The dissolve reaches that wall's rock alone")
	check(earth[1].material_override.get_shader_parameter("cutaway_reveal")==1.0 and earth[0].material_override.get_shader_parameter("cutaway_reveal")==0.0,"Its earth face dissolves with it")
	room.open_wall(2)
	settle(room)
	check(room.wall_reveal[1]==0.0 and room.wall_reveal[2]==1.0,"Moving to another wall closes the first")
	room.open_wall(-1)
	settle(room)
	check(room.wall_reveal.max()==0.0,"Looking away closes the cave again")
	check(room.side_facing(Vector3(-50,-5,3))==3,"A framed view opens the wall nearest the camera")
	var outer: MeshInstance3D = walls[0].get_node("Earth")
	check(outer.material_override.shader.resource_path.ends_with("reference_surface.gdshader") and outer.layers==1,"Outer faces are skirt earth, lit like the skirt")
	check(room.stratum(Lair.CEILING+0.5)==room.strata[2] and room.stratum(Lair.CEILING-2.0)==room.strata[0] and room.stratum(Lair.CEILING-4.0)==room.strata[1],"Walls continue the skirt's low bed, then soil and middle beds")
	var probe := SurfaceTool.new()
	probe.begin(Mesh.PRIMITIVE_TRIANGLES)
	var painted := [Color(0.3,0.2,0.1),Color(0.1,0.2,0.3),Color(0.05,0.05,0.05)]
	for band in range(3):
		probe.set_color(painted[band])
		var y: float = [0.0,-2.6,-4.0][band]
		for point in [Vector3(0,y,0),Vector3(1,y,0),Vector3(0,y,1)]: probe.add_vertex(point)
	var sampled: Array = Lair.strata_from(probe.commit())
	var close := func(a: Color, b: Color) -> bool: return absf(a.r-b.r)<0.01 and absf(a.g-b.g)<0.01 and absf(a.b-b.b)<0.01
	check(close.call(sampled[0],painted[0]) and close.call(sampled[1],painted[1]) and close.call(sampled[2],painted[2]),"Skirt strata are sampled by depth from its top")
	room.queue_free()
	await process_frame
	print("BIGFOOT LAIR CUTAWAY: failures=",failures)
	quit(1 if failures else 0)
