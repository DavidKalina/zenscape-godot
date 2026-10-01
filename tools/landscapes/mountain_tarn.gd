extends "res://tools/landscapes/harness.gd"
## Mountain tarn: a tall peak pulled up with the Modeller's pinch on a broad
## paddle swell, its top sliced level with the Wire (take 1 cut the pit into
## the horn's flank and it drained downhill), a small Chisel pit cut into that
## level summit, water poured in. Tests: does a hole high on a mountain hold
## water, and does its overflow run off as a fall.

const PEAK := Vector2(-1.0,-2.0)
const TARN := Vector2(-1.0,-2.0)

func title() -> String: return "mountain_tarn"

func build() -> void:
	await still("start")
	heights_at({"peak":PEAK,"tarn":TARN})
	# Shoulders first, so the peak stands on a massif, not a spike on the flat.
	await take_tool("paddle")
	await size(3)
	await hold_to(PEAK,3.5)
	# The peak itself: the Modeller's pinch, drawn up into a horn.
	await take_tool("hand")
	await size(3)
	await hold_to(PEAK,9.0)
	heights_at({"peak":PEAK,"tarn":TARN,"tarn+1":TARN+Vector2(1,1),"foot":PEAK+Vector2(5,5)})
	await overview()
	await still("peak")
	# Take 2: a level summit to cut into. The Wire's slice, pulled down.
	await take_tool("wire")
	await size(1)
	# Take 3: sliced lower, for a summit flat wide enough to hold a pit whole
	# (take 2's 7 m slice left a flat about 1.5 m across; the pit broke its
	# front edge, which made the fall but left a 0.2 m tarn).
	await hold_to(PEAK,6.0)
	heights_at({"peak":PEAK,"tarn":TARN,"edge of flat":PEAK+Vector2(2.5,0)})
	# The tarn: a small Chisel pit on the shoulder below the summit.
	await take_tool("chisel")
	await size(1)
	var before := height(TARN)
	await hold_to(TARN,before-1.5)
	heights_at({"peak":PEAK,"tarn":TARN,"tarn rim n":TARN+Vector2(0,-1.6),"tarn rim s":TARN+Vector2(0,1.6),"tarn rim e":TARN+Vector2(1.6,0),"tarn rim w":TARN+Vector2(-1.6,0)})
	measure_verbs()
	await view(TARN,16.0,scene.yaw,0.9)
	await still("pit")
	await pour(TARN,3.0)
	await put_down()
	await let_world_run(15.0)
	measure_water("tarn",TARN,2.0)
	measure_water("mountain",PEAK,7.0)
	measure_water("whole plate",Vector2.ZERO,30.0)
	await view(TARN,16.0,scene.yaw,0.9)
	await still("tarn")
	await overview()
	await still("overview")
	await view(PEAK+Vector2(0,2),22.0,scene.yaw+1.0,1.25)
	await still("low")
