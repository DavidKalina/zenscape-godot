extends SceneTree
## Timing for the edge falls (scripts/edge_falls.gd) on the square plate and
## on an island with an outline: the water's step, the spills read (every
## READ_SECONDS), a fall's side profile (once, as its lip moves) and its
## rings (every frame), with springs pouring off the land. Prints each
## fall's lip, way out and face drop too, so runs before and after a change
## can be compared. Headless, CPU only; the edge falls' stand-in editor holds
## the authored earth sides (square) or the shore wall (island).
##   godot --headless --path . --script tools/probe_shore_falls_timing.gd
const Genesis = preload("res://scripts/genesis_canvas.gd")
const EdgeFalls = preload("res://scripts/edge_falls.gd")
const READS := 200
const FRAMES := 400

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var skirt: MeshInstance3D = source.get_node("skirt")
	for island in [false,true]:
		var data := NativeTerrainData.new()
		data.setup(source.get_node("terrain").mesh)
		Genesis.shape(data,31,Vector2.ZERO,island)
		var flow: RefCounted = preload("res://scripts/water_flow.gd").new(data)
		await flow.setup()
		var spots := [Vector2(13.6,-3.0),Vector2(-13.6,4.0),Vector2(2.0,13.6)]
		if island: spots = [Vector2(-2.7,-0.35),_inside(data,Vector2(1,0)),_inside(data,Vector2(0,1))]
		for spot: Vector2 in spots: flow.springs.append({"x":spot.x,"z":spot.y,"rate":0.06,"radius":0.5,"age":100.0})
		var step_usec := 0
		for k in range(150):
			flow.run(4)
			step_usec += flow.last_step_usec
		var sides: Mesh = skirt.mesh
		var offset := skirt.position
		if island:
			sides = preload("res://scripts/island_shore.gd").build(data,Transform3D(Basis(),offset),null)
		var editor := _stand_in(data,sides,offset)
		var falls: Node3D = EdgeFalls.new()
		falls.setup(flow,editor)
		var read_worst := 0
		var read_sum := 0
		var spill_sum := 0
		for k in range(READS):
			var t := Time.get_ticks_usec()
			flow.spills(EdgeFalls.DETECT)
			spill_sum += Time.get_ticks_usec()-t
			falls._read(0.25)
			read_sum += falls.last_read_usec
			read_worst = maxi(read_worst,falls.last_read_usec)
		falls._ease(10.0)
		var t := Time.get_ticks_usec()
		var first := 0
		for fall: Dictionary in falls._falls:
			if fall.shown: falls._rings(fall,1.0,falls._strength(fall.now.flux))
		first = Time.get_ticks_usec()-t
		t = Time.get_ticks_usec()
		var count := 0
		for k in range(FRAMES):
			for fall: Dictionary in falls._falls:
				if not fall.shown: continue
				falls._rings(fall,1.0,falls._strength(fall.now.flux))
				count += 1
		var rings_usec := float(Time.get_ticks_usec()-t)/maxi(count,1)
		print("%s: step %.0f us, spills %.1f us, read %.1f us (worst %d), first rings+profile %.2f ms for %d falls, rings %.1f us per fall per frame" % [
			"island" if island else "square",float(step_usec)/150.0,float(spill_sum)/READS,float(read_sum)/READS,read_worst,first/1000.0,falls.shown_count(),rings_usec])
		for fall: Dictionary in falls._falls:
			if not fall.shown: continue
			var rings: Dictionary = fall.rings if fall.has("rings") else falls._rings(fall,1.0,falls._strength(fall.now.flux))
			var course := Vector3.ZERO
			for point: Vector3 in rings.points: course += point
			print("  fall: side %d lip %s normal %s flux %.4f face %.2f m bottom %.2f, ring points sum to %s" % [fall.now.side,fall.now.lip,fall.now.normal,fall.now.flux,float(rings.face_drop),float(fall.bottom),course])
		falls.free()
		editor.free()
		data.release_listeners()
	source.free()
	quit()

## A point 1.2 m inside the shore along `way` from the middle.
static func _inside(data: NativeTerrainData, way: Vector2) -> Vector2:
	var r := 0.0
	while data.ground_height(way*(r+0.1)) != null and r < 14.0: r += 0.1
	return way*maxf(r-1.2,0.0)

func _stand_in(data: NativeTerrainData, sides: Mesh, offset: Vector3) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar terrain: Node3D\nvar _skirt: MeshInstance3D\nvar data: NativeTerrainData\n"
	script.reload()
	var editor: Node = script.new()
	editor.terrain = Node3D.new()
	editor._skirt = MeshInstance3D.new()
	editor._skirt.mesh = sides
	editor._skirt.position = offset
	editor.data = data
	editor.add_child(editor.terrain)
	editor.add_child(editor._skirt)
	root.add_child(editor)
	return editor
