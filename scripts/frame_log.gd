class_name FrameLog
extends RefCounted
## One row per frame of a real flight, for finding stutter: `--frame-log=FILE`
## on the game's command line, a hand flight or a driven one. A row has the
## time from frame to frame, the engine's own parts, the plane's place and the
## ms of each `mark`ed part of the study's tick. Read it with
## tools/frame_report.py. Off, a mark costs one static read.

static var on := false
static var _file: FileAccess
static var _parts: PackedStringArray = []
static var _ms := PackedFloat32Array()
static var _index := {}
static var _at := 0
static var _start := 0
static var _last := -1
static var _physics := 0
static var _compiled := 0.0
static var _cols := -1
static var _drawn := 0
static var _rows := 0

## Starts the log when the launch flags ask for it. Once only: the scene
## stood again (a door, a restart) keeps writing the same log rather than
## opening it again over itself.
static func begin(args: PackedStringArray) -> void:
	if on: return
	for a in args:
		if a.begins_with("--frame-log="): _open(a.get_slice("=",1))

static func _open(path: String) -> void:
	_file = FileAccess.open(path,FileAccess.WRITE)
	if _file == null:
		push_warning("--frame-log: can't write %s" % path)
		return
	on = true
	RenderingServer.viewport_set_measure_render_time(Engine.get_main_loop().root.get_viewport_rid(),true)

## The frame's work starts.
static func start() -> void:
	if not on: return
	if GroundTally.on: GroundTally.file(&"outside")
	_at = Time.get_ticks_usec()

## The part just done, named: the time since the last mark.
static func mark(part: StringName) -> void:
	if not on: return
	if GroundTally.on: GroundTally.file(part)
	var now := Time.get_ticks_usec()
	var i: int = _index.get(part,-1)
	if i < 0:
		i = _parts.size()
		_index[part] = i
		_parts.append(part)
		_ms.append(0.0)
	_ms[i] += (now-_at)/1000.0
	_at = now

## `ms` spent where no mark sees it (a slice of work between frames), under `part`.
static func add(part: StringName, ms: float) -> void:
	if not on: return
	var i: int = _index.get(part,-1)
	if i < 0:
		i = _parts.size()
		_index[part] = i
		_parts.append(part)
		_ms.append(0.0)
	_ms[i] += ms

## The frame's row. Headed once the frame has been through every part.
static func end(tick_ms: float, plane_at: Vector3, speed: float) -> void:
	if not on: return
	var now := Time.get_ticks_usec()
	if _last < 0:
		_last = now
		_start = now
		_physics = Engine.get_physics_frames()
		return
	var frames: int = Engine.get_physics_frames()
	var rid: RID = Engine.get_main_loop().root.get_viewport_rid()
	var compiled := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)+Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
	if _cols != _parts.size():
		_cols = _parts.size()
		_file.store_line("t,frame,tick,drawn,physics_steps,physics_ms,render_cpu,render_gpu,pipelines,draws,objects,nodes,vram_mb,x,y,z,speed,scale,"+",".join(_parts))
	var row := PackedStringArray([
		"%.3f" % ((now-_start)/1000000.0),"%.2f" % ((now-_last)/1000.0),"%.2f" % tick_ms,
		str(Engine.get_frames_drawn()-_drawn),str(frames-_physics),"%.2f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0),
		"%.2f" % RenderingServer.viewport_get_measured_render_time_cpu(rid),"%.2f" % RenderingServer.viewport_get_measured_render_time_gpu(rid),
		str(int(compiled-_compiled)),str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),
		str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))),str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))),
		"%.0f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0),
		"%.0f" % plane_at.x,"%.0f" % plane_at.y,"%.0f" % plane_at.z,"%.1f" % speed,
		"%.0f" % ((Engine.get_main_loop() as SceneTree).root.scaling_3d_scale*100.0)])
	for i in _parts.size():
		row.append("%.2f" % _ms[i])
		_ms[i] = 0.0
	_file.store_line(",".join(row))
	_rows += 1
	if _rows % 240 == 0: _file.flush()
	_last = now
	_physics = frames
	_drawn = Engine.get_frames_drawn()
	_compiled = compiled

static func stop() -> void:
	if not on: return
	on = false
	_file.close()
	_file = null
