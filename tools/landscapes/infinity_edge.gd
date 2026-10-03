extends "res://tools/landscapes/harness.gd"
## Infinity edge: a palm-pressed pond near the near rim, a Modeller groove run
## out through the rim to notch it, water poured in. Tests: does the pond spill
## through the notch and fall off the plate edge into the void.

const POND := Vector2(2.0,9.0)
const SPILL := [Vector2(2.0,9.5),Vector2(2.0,11.5),Vector2(2.0,13.9)]

func title() -> String: return "infinity_edge"

func build() -> void:
	await still("start")
	heights_at({"pond":POND,"rim":Vector2(2.0,13.5)})
	# The pond: Modeller palm (Shift+drag) pressed in a small circle, twice.
	await take_tool("hand")
	await take_mode("groove")
	await size(3)
	var ring := [POND+Vector2(-1.5,0),POND+Vector2(0,-1.5),POND+Vector2(1.5,0),POND+Vector2(0,1.0),POND+Vector2(-1.5,0)]
	await brisk_drag(ring,1.5,true)
	await brisk_drag(ring,1.5,true)
	heights_at({"pond":POND,"pond rim n":POND+Vector2(0,-3),"pond rim s":POND+Vector2(0,3)})
	# The notch: a slow Modeller groove out across the near rim.
	await size(2)
	await brisk_drag(SPILL,2.0)
	log_line("rim notches %d, last %s" % [clay.notches,clay.last_notch])
	heights_at({"pond":POND,"spill":SPILL[1],"lip":Vector2(2.0,13.6),"rim beside":Vector2(5.0,13.6)})
	measure_verbs()
	await overview()
	await still("shaped")
	await pour(POND,3.0)
	await put_down()
	await let_world_run(15.0)
	measure_water("pond",POND,2.5)
	measure_water("spill",SPILL[1],1.5)
	measure_water("whole plate",Vector2.ZERO,30.0)
	var falls: Node = scene.find_child("*dge*all*",true,false)
	log_line("edge falls node %s, spills %s" % [falls,editor.flow.spills({}) if editor.flow != null and editor.flow.has_method("spills") else "?"])
	await overview()
	await still("overview")
	await view(Vector2(2.0,12.5),14.0,scene.yaw,1.25)
	await still("edge")
	await view(Vector2(2.0,13.0),16.0,scene.yaw+0.7,1.45)
	await still("edge-low")


## The harness's drag, with a brisk start: the pointer jumps BRISK_PX along
## the path in the first frame after the press. A windowed run renders slower
## than 60 fps, the harness moves a fixed share a frame, so a slow drag stayed
## under the clay's 6 px for its 0.3 s hold time and was read as a hold (a
## pinch). A player starting a stroke moves off the press at once.
const BRISK_PX := 14.0

func brisk_drag(path: Array, speed := 3.0, fine := false) -> void:
	var points: Array[Vector2] = []
	for p: Vector2 in path: points.append(screen(p))
	await glide(points[0],25)
	if fine: shift(true)
	button(pointer,true)
	await frames(1)
	var first: Vector2 = points[0]+(points[1]-points[0]).normalized()*BRISK_PX
	move(first,true)
	await frames(1)
	points[0] = first
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var steps := maxi(1,int(a.distance_to(b)/speed*60.0))
		for k in range(steps):
			move(points[i].lerp(points[i+1],float(k+1)/steps),true)
			await frames(1)
	await frames(2)
	button(pointer,false)
	if fine: shift(false)
	await frames(2)
	await settle()
