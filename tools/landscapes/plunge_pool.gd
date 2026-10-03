extends "res://tools/landscapes/harness.gd"
## Plunge pool: high ground at the back from a low Mountain pull, a Chisel
## shelf dragged across the plate to make a cliff, a Ravine gorge notching the
## lip, a Mountain crater for a pool at the cliff's foot, water poured on the
## high ground. (Until 2026-10-02 the high ground and the pool were Paddle
## swells; "The roll, revised", docs/design/tools/PLAN.md, cut the swell.) Tests: can the tools make a real cliff, and does water drop off it
## into the pool.

const UPLAND := Vector2(0.0,-7.0)
const LIP := Vector2(0.0,-1.9)
const POOL := Vector2(0.0,1.2)
## Take 2: the shelf is pressed on the swell's face (its level is the press's
## height) and drawn out to each side; take 1 pressed at the plate's flat
## side and cut the swell's front off at 1.2 m.
const SHELF_W := [Vector2(0.0,-3.5),Vector2(-4.0,-3.5),Vector2(-9.0,-3.5)]
const SHELF_E := [Vector2(0.0,-3.5),Vector2(4.0,-3.5),Vector2(9.0,-3.5)]
## Take 2: a short, shallow (Shift) wire notch at the lip only; take 1's long
## full-depth gorge from the upland cut the cliff away.
const GORGE := [Vector2(0.0,-4.8),Vector2(0.0,-3.4),Vector2(0.0,-1.9)]

func title() -> String: return "plunge_pool"

func build() -> void:
	await still("start")
	# The upland: a broad low pull at the back.
	await take_tool("mountain")
	await size(3)
	await hold_to(UPLAND,4.0)
	heights_at({"upland":UPLAND,"lip":LIP,"pool":POOL})
	# The cliff: a Chisel shelf across the swell's front slope.
	await take_tool("chisel")
	await size(3)
	await take_mode("shelf")
	await brisk_drag(SHELF_W,3.0)
	await brisk_drag(SHELF_E,3.0)
	heights_at({"shelf":Vector2(0,-3.5),"lip":LIP,"below lip":LIP+Vector2(0,1.0),"foot":LIP+Vector2(0,2.5)})
	# The pool at the foot: a Crater pulled down.
	await take_tool("crater")
	await size(1)
	var was := height(POOL)
	await hold_to(POOL,was-1.2)
	measure_verbs()
	if height(POOL) > was-0.3:
		# Take 2's swell-down left the ground untouched (402 px of pull, no
		# verb reported): a player would try again.
		log_line("pool swell did nothing; pressing again")
		await hold_to(POOL+Vector2(0.3,0.0),was-1.2)
	# The notch: a Ravine gorge from the upland out over the lip.
	await take_tool("wire")
	await size(1)
	await brisk_drag(GORGE,3.0,true)
	await settle()
	heights_at({"upland":UPLAND,"gorge mid":GORGE[1],"lip":LIP,"below lip":LIP+Vector2(0,1.0),"pool":POOL,"pool rim s":POOL+Vector2(0,2.5)})
	measure_verbs()
	await overview()
	await still("shaped")
	await view(LIP,16.0,scene.yaw,1.15)
	await still("cliff")
	# Take 2 pours on the shelf just behind the notch: take 1's pour on the
	# upland crown ran off the swell's back, away from the cliff.
	await pour(Vector2(0.0,-4.2),3.0)
	await put_down()
	await let_world_run(15.0)
	measure_water("upland",UPLAND,2.5)
	measure_water("gorge",GORGE[1],1.5)
	measure_water("pool",POOL,2.5)
	measure_water("whole plate",Vector2.ZERO,30.0)
	await view(LIP,16.0,scene.yaw,1.15)
	await still("fall")
	await overview()
	await still("overview")
	await view(POOL,12.0,scene.yaw+0.8,1.3)
	await still("low")


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
