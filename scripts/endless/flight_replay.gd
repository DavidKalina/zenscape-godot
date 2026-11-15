class_name FlightReplay
extends RefCounted
## A taped flight (scripts/endless/flight_tape.gd) drawn again: `--replay=FILE`
## on the game's command line, most often through tools/movie.py, which adds
## Godot's Movie Maker and the tape's own launch flags. The game holds one
## (`game.replay`) and, in its tick, asks it for the input (`input`), for the
## landing's step (`step`: the plane and the landing set to the tape's, mixed
## between its two nearest rows, so a tape flown at any frame rate draws
## smoothly at the movie's), for the camera (`frame`) and for the hour
## (`hour`). Nothing flies: no input is read and the plane is not stepped. The
## rest of the tick runs as in the flight, so the land streams, the figure, the
## spray and the sound follow. The HUD is hidden and no book is kept.
##
## Flags:
##   --replay=FILE         the tape
##   --replay-take=N       which take (1, the first)
##   --replay-from=S       seconds into the take to start (0)
##   --replay-to=S         and to end (its end)
##   --replay-cam=NAME     the camera, with its knobs after commas:
##                         `--replay-cam=flyby,dist=20,every=6` (CAMS)
##   --replay-settle=S     seconds held on the first frame while the land
##                         stands and the eye settles (2; tools/movie.py cuts
##                         them off the film)
##   --replay-pace=X       a movie's frames take at least 1/X of their time on
##                         the clock, so the land's workers keep up as they
##                         do in play (1; 0.5 gives them twice as long; 0 no wait)
##   --replay-speed=X      slow motion (0.5: half speed), the world's too
##   --replay-hud          the HUD stays
##   --replay-size=WxH     the window put to this size (a preview; a film's
##                         size is the project's, which tools/movie.py sets)
## It prints `REPLAY first=N` and `REPLAY last=N seconds=S` (the process frames
## of the first and last frames of the take drawn, and the time on the clock
## between them) and quits at the end.

## The cameras. Distances are in metres at the plane's flight size.
##   flown   the eye as it was in the flight (looks around and shakes included)
##   chase   the game's chase camera, following the replayed plane afresh
##   orbit   round the plane: dist, height, rate (degrees a second), fov
##   side    abreast of it: dist, height, lead (ahead), side (1 right, -1 left), fov
##   front   ahead of it, looking back: dist, height, fov
##   top     over it, looking down, the way ahead up the frame: dist, fov
##   flyby   stood still where the plane will pass, turning to watch it go:
##           dist (off its line), height, every (seconds a stand), fov, fill
##           (a long lens follows it in and out: the wingspan kept at least
##           this share of the frame's height, the view never wider than fov;
##           0 keeps fov)
const CAMS := {
	"flown":{},
	"chase":{},
	"orbit":{"dist":4.5,"height":1.0,"rate":24.0,"fov":50.0},
	"side":{"dist":4.0,"height":0.4,"lead":0.8,"side":1.0,"fov":50.0},
	"front":{"dist":4.5,"height":0.8,"fov":50.0},
	"top":{"dist":10.0,"fov":50.0},
	"flyby":{"dist":9.0,"height":1.5,"every":4.0,"fov":40.0,"fill":0.16},
}
## Fields that are angles: mixed the short way round.
const ANGLES: Array[String] = ["heading","pitch","bank","spin"]
## The eye keeps this far over the land and the water.
const EYE_CLEAR := 0.5
## A move between two rows faster than this (m/s) is a jump (a respawn, a
## door): the earlier row is held, not mixed.
const JUMP := 1500.0

var path := ""
var head := {}
var width := 0
var data := PackedFloat32Array()
var times := PackedFloat64Array()
var events := {}
## Seconds into the take now, and where it starts and ends.
var t := 0.0
var from := 0.0
var to := 0.0
var cam := "flown"
var knobs := {}
var settle := 2.0
var pace := 1.0
var hud := false
## The window's size asked for (zero: as it is).
var size := Vector2i.ZERO
var movie := OS.has_feature("movie")
var done := false

var _own := {}
var _plane: Array = []
var _landing: Array = []
var _bound := false
var _row := 0
var _mix := 0.0
var _jump := false
var _started := false
var _roll := 0.0
var _last_usec := 0
var _first_usec := 0
var _layers: Array = []
var _layers_at := 0
var _pos := -1
var _heading := -1
var _stand := Vector3.ZERO
var _stand_until := -INF
var _stand_side := -1.0
var _turned := 0.0

## The replay the launch flags ask for, or null.
static func from_args(args: PackedStringArray) -> FlightReplay:
	var file := ""
	var want := {}
	for a in args:
		if a.begins_with("--replay="): file = a.get_slice("=",1)
		elif a == "--replay-hud": want["hud"] = "1"
		elif a.begins_with("--replay-"): want[a.get_slice("=",0).trim_prefix("--replay-")] = a.substr(a.find("=")+1)
	if file == "": return null
	var takes := FlightTape.read(file)
	var n := clampi(int(want.get("take","1")),1,maxi(1,takes.size()))
	if takes.is_empty() or (takes[n-1].times as PackedFloat64Array).size() < 2:
		push_error("--replay: no flight in %s" % file)
		return null
	var r := FlightReplay.new()
	var take: Dictionary = takes[n-1]
	r.path = file
	r.head = take.head
	r.width = int(take.width)
	r.data = take.data
	r.times = take.times
	r.events = take.events
	var length := r.times[r.times.size()-1]
	r.from = clampf(float(want.get("from","0")),0.0,length)
	r.to = clampf(float(want.get("to",str(length))),r.from,length)
	r.t = r.from
	r.settle = maxf(0.0,float(want.get("settle","2")))
	r.pace = maxf(0.0,float(want.get("pace","1")))
	r.hud = want.has("hud")
	var wh := str(want.get("size","")).split("x")
	if wh.size() == 2: r.size = Vector2i(int(wh[0]),int(wh[1]))
	var speed := clampf(float(want.get("speed","1")),0.05,4.0)
	if speed != 1.0: Engine.time_scale = speed
	var parts := str(want.get("cam","flown")).split(",")
	if not CAMS.has(parts[0]):
		push_warning("--replay-cam=%s: not one of %s" % [parts[0],CAMS.keys()])
		parts[0] = "flown"
	r.cam = parts[0]
	r.knobs = (CAMS[r.cam] as Dictionary).duplicate()
	for i in range(1,parts.size()):
		var kv := parts[i].split("=")
		if kv.size() == 2 and r.knobs.has(kv[0]): r.knobs[kv[0]] = kv[1].to_float()
		else: push_warning("--replay-cam: %s has no knob %s" % [r.cam,parts[i]])
	var own: Array = r.head.get("own",[])
	for i in own.size(): r._own[str(own[i])] = i
	var at := own.size()
	for f: Array in r.head.get("plane",[]):
		if str(f[0]) == "position": r._pos = at
		if str(f[0]) == "heading": r._heading = at
		at += FlightTape.width_of([f])
	r._seek()
	print("REPLAY %s take %d: %.2f to %.2f s of %.2f, camera %s" % [file,n,r.from,r.to,length,r.cam])
	return r

## The seed the take was flown on.
func seed_of() -> int:
	return int(head.get("seed",1))

## Where the plane is at the start (to stand the land round), and its heading.
func start_at() -> Vector3:
	return place(from)

func start_heading() -> float:
	return float(data[_row*width+_heading]) if _heading >= 0 else 0.0

## The plane's place `at` seconds into the take.
func place(at: float) -> Vector3:
	if _pos < 0: return Vector3.ZERO
	var s := clampf(at,0.0,times[times.size()-1])
	var i := clampi(times.bsearch(s)-1,0,times.size()-2)
	var a := i*width+_pos
	var b := a+width
	var k := clampf((s-times[i])/maxf(times[i+1]-times[i],1e-6),0.0,1.0)
	var pa := Vector3(data[a],data[a+1],data[a+2])
	var pb := Vector3(data[b],data[b+1],data[b+2])
	if pa.distance_to(pb) > JUMP*maxf(times[i+1]-times[i],1e-3): return pa
	return pa.lerp(pb,k)

## The flat way the plane goes round `at` (over a second of its path: the
## cameras stay steady through a roll), or the way it heads when it stands.
func way(at: float) -> Vector3:
	var d := place(at+0.5)-place(at-0.5)
	d.y = 0.0
	if d.length() > 0.5 and d.length() < JUMP: return d.normalized()
	var h := start_heading() if _heading < 0 else float(data[_row*width+_heading])
	return Vector3(-sin(h),0.0,-cos(h))

## The input this frame: none of it read, the tape's.
func input() -> Dictionary:
	var out := {"turn":_col("turn"),"pitch":_col("pitch"),"look":Vector2(_col("look_x"),_col("look_y")),"lean":_col("lean"),
		"boost":_col("boost"),"brake":_col("brake"),"roll":_roll}
	_roll = 0.0
	return out

## In the landing's step's place: the take moved on by `delta`, the plane and
## the landing set to it. Returns the events of the rows passed.
func step(delta: float, game: Node) -> Dictionary:
	if not _bound: _bind(game)
	_wait(delta)
	if not hud: _hide(game)
	var out := {}
	if settle > 0.0:
		settle -= delta
		_fit(game.get_window())
	else:
		if not _started:
			_started = true
			var window: Window = game.get_window()
			print("REPLAY size=%dx%d screen=%dx%d scale=%.2f" % [window.size.x,window.size.y,DisplayServer.screen_get_size().x,DisplayServer.screen_get_size().y,window.scaling_3d_scale])
			print("REPLAY first=%d" % Engine.get_process_frames())
			_first_usec = Time.get_ticks_usec()
		var was := _row
		t = minf(t+delta,to)
		_seek()
		for r in range(was+1,_row+1):
			if events.has(r): out.merge(events[r],true)
			var roll := float(data[r*width+int(_own.get("roll",0))])
			if roll != 0.0: _roll = roll
	_pose(game.plane,_plane)
	_pose(game.hand_landing,_landing)
	game.flaps = _col("flaps") > 0.5
	if t >= to and not done:
		done = true
		print("REPLAY last=%d seconds=%.1f" % [Engine.get_process_frames(),(Time.get_ticks_usec()-_first_usec)/1000000.0])
		game.get_tree().quit()
	return out

## After the game's own camera: the eye put where this replay's camera has it.
func frame(delta: float, game: Node) -> void:
	var camera: Camera3D = game.camera
	if cam == "chase": return
	if cam == "flown":
		var a := _row*width
		var b := a+(0 if _jump else width)
		var x := int(_own.cam_x)
		var q := int(_own.cam_qx)
		var qa := Quaternion(data[a+q],data[a+q+1],data[a+q+2],data[a+q+3]).normalized()
		var qb := Quaternion(data[b+q],data[b+q+1],data[b+q+2],data[b+q+3]).normalized()
		camera.global_transform = Transform3D(Basis(qa.slerp(qb,_mix)),Vector3(data[a+x],data[a+x+1],data[a+x+2]).lerp(Vector3(data[b+x],data[b+x+1],data[b+x+2]),_mix))
		camera.fov = _col("fov")
		return
	var size: float = game.ground_scale.size()
	var plane_at: Vector3 = game.plane.position+game.ground_scale.lift()
	var ahead := way(t)
	var right := ahead.cross(Vector3.UP).normalized()
	var dist := float(knobs.get("dist",6.0))*size
	var height := float(knobs.get("height",0.0))*size
	var eye := plane_at
	var up := Vector3.UP
	match cam:
		"orbit":
			_turned += deg_to_rad(float(knobs.rate))*delta
			eye = plane_at+(ahead*cos(_turned)+right*sin(_turned))*-dist+Vector3.UP*height
		"side":
			eye = plane_at+right*dist*signf(float(knobs.side))+ahead*float(knobs.lead)*size+Vector3.UP*height
		"front":
			eye = plane_at+ahead*dist+Vector3.UP*height
		"top":
			eye = plane_at+Vector3.UP*dist
			up = ahead
		"flyby":
			if t >= _stand_until:
				var every := maxf(1.0,float(knobs.every))
				var mid := t+every*0.5
				_stand_side = -_stand_side
				_stand = place(mid)+way(mid).cross(Vector3.UP).normalized()*dist*_stand_side+Vector3.UP*height
				_stand.y = maxf(_stand.y,float(game.eye_floor(_stand))+EYE_CLEAR)
				_stand_until = t+every
			eye = _stand
	if cam != "flyby": eye.y = maxf(eye.y,float(game.eye_floor(eye))+EYE_CLEAR)
	if eye.distance_to(plane_at) < 0.05: eye += Vector3(0.0,0.1,0.1)
	camera.global_position = eye
	camera.look_at(plane_at,up)
	var fov := float(knobs.get("fov",50.0))
	var fill := float(knobs.get("fill",0.0))
	if fill > 0.0: fov = clampf(rad_to_deg(2.0*atan(preload("res://scripts/world_scale.gd").TOY_SPAN*size/(2.0*fill*maxf(eye.distance_to(plane_at),0.1)))),3.0,fov)
	camera.fov = fov

## The hour as it was in the flight: the day's clock held, the sun put there.
func hour(look: Node) -> void:
	if not _own.has("phase"): return
	look.cycle.held = true
	look.celestial.phase = _col("phase")

## The row pair round `t` and how far between them it is.
func _seek() -> void:
	_row = clampi(_row,0,times.size()-2)
	while _row < times.size()-2 and times[_row+1] <= t: _row += 1
	while _row > 0 and times[_row] > t: _row -= 1
	var gap := maxf(times[_row+1]-times[_row],1e-6)
	_mix = clampf((t-times[_row])/gap,0.0,1.0)
	_jump = false
	if _pos >= 0:
		var a := _row*width+_pos
		var b := a+width
		_jump = Vector3(data[a],data[a+1],data[a+2]).distance_to(Vector3(data[b],data[b+1],data[b+2])) > JUMP*maxf(gap,1e-3)
	if _jump: _mix = 0.0

## One of the frame's own columns now.
func _col(name: String) -> float:
	if not _own.has(name): return 0.0
	var c := int(_own[name])
	var a := float(data[_row*width+c])
	if name in ["flaps","roll"]: return a
	return _between(a,float(data[(_row+1)*width+c]),false)

func _between(a: float, b: float, angle: bool) -> float:
	if a == b or _mix <= 0.0: return a
	if not is_finite(a) or not is_finite(b): return a if _mix < 0.5 else b
	return lerp_angle(a,b,_mix) if angle else lerpf(a,b,_mix)

## The tape's columns matched to the fields the plane and the landing have
## now: [[name, type, column, angle], ...]. A field the tape has and the code
## no longer does (or holds as another type) is left be.
func _bind(game: Node) -> void:
	_bound = true
	var at := (head.get("own",[]) as Array).size()
	for pair: Array in [[game.plane,"plane"],[game.hand_landing,"landing"]]:
		var o: Object = pair[0]
		var has := {}
		for f: Array in FlightTape.fields_of(o): has[f[0]] = f[1]
		var bound := []
		for f: Array in head.get(pair[1],[]):
			var name := str(f[0])
			var type := int(f[1])
			if int(has.get(name,-1)) == type: bound.append([name,type,at,name in ANGLES])
			at += FlightTape.width_of([f])
		if pair[1] == "plane": _plane = bound
		else: _landing = bound

func _pose(o: Object, fields: Array) -> void:
	var a := _row*width
	var b := a+width
	for f: Array in fields:
		var c := int(f[2])
		match int(f[1]):
			TYPE_VECTOR3:
				var va := Vector3(data[a+c],data[a+c+1],data[a+c+2])
				var vb := Vector3(data[b+c],data[b+c+1],data[b+c+2])
				o.set(f[0],va.lerp(vb,_mix) if va.is_finite() and vb.is_finite() else va)
			TYPE_VECTOR2:
				var va := Vector2(data[a+c],data[a+c+1])
				var vb := Vector2(data[b+c],data[b+c+1])
				o.set(f[0],va.lerp(vb,_mix) if va.is_finite() and vb.is_finite() else va)
			TYPE_BOOL: o.set(f[0],data[a+c] > 0.5)
			TYPE_INT: o.set(f[0],int(data[a+c]))
			_: o.set(f[0],_between(float(data[a+c]),float(data[b+c]),bool(f[3])))

## The window at the size asked for, while the first frame is held.
func _fit(window: Window) -> void:
	if size == Vector2i.ZERO or DisplayServer.get_name() == "headless": return
	if window.mode != Window.MODE_WINDOWED: window.mode = Window.MODE_WINDOWED
	elif window.size != size: window.size = size

## A movie's frame waits out its share of the clock, so the land's workers
## get the time they have in play.
func _wait(delta: float) -> void:
	if not movie or pace <= 0.0: return
	var want := int(1000000.0*delta/maxf(Engine.time_scale,0.05)/pace)
	var now := Time.get_ticks_usec()
	if _last_usec > 0 and now-_last_usec < want: OS.delay_usec(want-(now-_last_usec))
	_last_usec = Time.get_ticks_usec()

## Every layer of words the game shows, hidden (the look's grade is not one).
func _hide(game: Node) -> void:
	if Engine.get_process_frames() >= _layers_at:
		_layers_at = Engine.get_process_frames()+30
		_layers = game.find_children("*","CanvasLayer",true,false)
	for node: Variant in _layers:
		if is_instance_valid(node) and (node as CanvasLayer).visible and (node as CanvasLayer).name != "LookGrade": (node as CanvasLayer).visible = false
