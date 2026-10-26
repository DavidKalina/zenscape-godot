extends "res://tools/harness/drive.gd"
## Stills of endless flight (seed 1) from held views, plane hidden, no HUD, for
## tools/look_measure.py (docs/art/look-breakdown.md). --views=a,b (SPOTS below),
## --out=DIR --tag=SUFFIX --hold=300; scene args (--hour=12.5) after --scene-args.
## The SUN views look along the sun's bearing (toward it, or away with its
## light behind the eye) from a fixed eye, whatever the hour.
## --win=WxH sizes the window (drive.gd fit_window; 1440x900 by default);
## --time=N also prints a ROW of the frame time over N frames per view;
## --full-size keeps the still at the window's size (else 1440x900).
##   python tools/drive.py tools/harness/look_views.gd --rendered -- --out=DIR --scene-args --no-title
const Field = preload("res://scripts/endless/land_field.gd")
# name: [eye x,z,above, look x,z,above]
const SPOTS := {
	"meadow_low": [720,500,5, 720,380,3],
	"hills": [120,-40,45, 120,-200,15],
	"rock": [40,-90,40, 40,-200,20],
	"coast": [0,40,25, 0,200,-10],
	"river": [0,40,18, 0,-60,0],
	"cruise": [720,520,45, 720,380,10],
	"high": [720,560,260, 720,400,0],
	"forest": [330,-150,14, 330,-300,4],
}
# name: [eye x,z,above, how far ahead the look is (m), its drop (m), its
# bearing from the sun's (degrees: 0 toward it, 180 away, 90 across)]
const SUN := {
	"sun_toward": [720,520,40, 600,60, 0],
	"sun_away": [720,520,40, 600,60, 180],
	"sun_side": [720,520,40, 600,60, 90],
	"sun_toward_low": [720,500,6, 300,4, 0],
	"sun_away_low": [720,500,6, 300,4, 180],
}
const ALL := "meadow_low,hills,rock,coast,river,cruise,high"
func drive() -> void:
	await open("studies/endless_flight.tscn")
	study.walk_ready = false
	if study.plane_figure != null: study.plane_figure.visible = false
	var names: PackedStringArray = str(arg("views",ALL)).split(",")
	for n in names:
		aim(n)
		await _hold(arg_int("hold",300))
		if arg_int("time",0) > 0: row(await frame_time(n,arg_int("time",0)))
		await shot("%s/%s%s.png" % [arg("out","scratch/lb/shots"),n,arg("tag","")],false,Vector2i.ZERO if flag("full-size") else Vector2i(1440,900))
		await frames(2)
	finish()

## The study's camera to view `n` (SPOTS or SUN).
func aim(n: String) -> void:
	var cam: Camera3D = study.camera
	var field: RefCounted = study.field
	if SUN.has(n):
		var s: Array = SUN[n]
		var sun: Vector3 = study.look.celestial.state.zs_sun_direction
		var flat := Vector3(sun.x,0.0,sun.z).normalized().rotated(Vector3.UP,deg_to_rad(float(s[5])))
		var e := Vector3(s[0],field.height(s[0],s[1])+s[2],s[1])
		cam.global_position = e
		cam.look_at(e+flat*float(s[3])-Vector3(0.0,float(s[4]),0.0),Vector3.UP)
		return
	var v: Array = SPOTS[n]
	cam.global_position = Vector3(v[0],field.height(v[0],v[1])+v[2],v[1])
	cam.look_at(Vector3(v[3],field.height(v[3],v[4])+v[5],v[4]),Vector3.UP)

## The frame time (ms) over `count` frames held at view `n`: --time=N (a
## rendered run, vsync off, the window's own pace: drive.py's fixed fps only
## fixes the step, so a frame takes what it costs). `wall_ms` is the median
## time from frame to frame, `gpu_ms` the GPU's own where the driver reports
## it (0 on Metal).
func frame_time(n: String, count: int) -> Dictionary:
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	await _hold(30)
	var wall: Array[float] = []
	var gpu: Array[float] = []
	var t := Time.get_ticks_usec()
	for i in count:
		await _hold(1)
		var now := Time.get_ticks_usec()
		wall.append((now-t)/1000.0)
		t = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	RenderingServer.viewport_set_measure_render_time(rid,false)
	wall.sort()
	gpu.sort()
	var mean := 0.0
	for w in wall: mean += w
	return {"view":n,"wall_ms":snappedf(wall[wall.size()/2],0.01),"wall_mean_ms":snappedf(mean/wall.size(),0.01),
		"wall_p90_ms":snappedf(wall[int(wall.size()*0.9)],0.01),"gpu_ms":snappedf(gpu[gpu.size()/2],0.01),
		"size":str(root.size),"scale3d":snappedf(root.scaling_3d_scale,0.01)}

func _hold(n: int) -> void:
	var cam: Camera3D = study.camera
	for i in n:
		var eye := cam.global_position
		var fwd := -cam.global_basis.z
		study.land.step(eye)
		study.arches.step(eye)
		if study.grass != null: study.grass.step(eye,fwd)
		if study.look != null: study.look.step(1.0/60.0,eye,fwd,cam)
		if study.react == null: study.sea.position = Vector3(snappedf(eye.x,64.0),Field.SEA_Y,snappedf(eye.z,64.0))
		await frames(1)
