extends "res://tools/landscapes/harness.gd"
## Rice terraces: a big Paddle swell, then Chisel drags round its near flank at
## stepped heights (a flight of terraces, top down), then water poured on the
## crown. Tests: does the chisel make a readable flight of steps on a dome,
## and does water step down the terraces or just run off.

const CROWN := Vector2(0.0,-2.0)
## Take 1 was [2.4,4.2,6.0,7.8] at full depth, spread 1.4. Take 2: closer
## rings, Shift (half-depth faces), wider arcs, for paddies rather than a ziggurat.
const RADII := [2.0,3.3,4.6,5.9,7.2,8.5]
const FINE := true
const SPREAD := 1.9

func title() -> String: return "rice_terraces"

## The plate bearing (radians) from the crown toward the camera.
func toward_camera() -> float:
	var cam: Vector3 = editor.terrain.to_local(scene.camera.global_position)
	return (Vector2(cam.x,cam.z)-CROWN).angle()

## An arc round the crown at `radius`, `spread` radians either side of `mid`.
func arc(radius: float, mid: float, spread: float, count := 14) -> Array:
	var path := []
	for i in range(count+1):
		var a := mid-spread+2.0*spread*i/count
		path.append(CROWN+Vector2.from_angle(a)*radius)
	return path

func transect(label: String, bearing: float) -> void:
	var parts: PackedStringArray = []
	for r in range(0,11):
		parts.append("%.2f" % height(CROWN+Vector2.from_angle(bearing)*r))
	log_line("transect %s r=0..10: %s" % [label," ".join(parts)])

func build() -> void:
	var near := toward_camera()
	log_line("camera bearing %.2f rad" % near)
	await take_tool("paddle")
	await size(3)
	await hold_to(CROWN,5.0)
	transect("swell",near)
	await overview()
	await still("swell")
	await take_tool("chisel")
	await size(2)
	for r: float in RADII:
		await drag(arc(r,near,SPREAD,18),3.0,FINE)
		heights_at({"r%.1f" % r:CROWN+Vector2.from_angle(near)*r})
	transect("terraced",near)
	transect("side",near+PI*0.5)
	measure_verbs()
	await overview()
	await still("terraced")
	await view(CROWN+Vector2.from_angle(near)*4.0,16.0,scene.yaw,1.15)
	await still("terraces-low")
	await pour(CROWN,3.0)
	await put_down()
	await let_world_run(20.0)
	for r: float in RADII:
		measure_water("shelf r%.1f" % r,CROWN+Vector2.from_angle(near)*(r+0.6),1.2)
	measure_water("crown",CROWN,1.5)
	measure_water("whole plate",Vector2.ZERO,30.0)
	await overview()
	await still("water")
	await view(CROWN+Vector2.from_angle(near)*4.0,16.0,scene.yaw,1.15)
	await still("water-low")
