class_name StreamLog
extends RefCounted
## One row per streamed piece (a land chunk, a tree block, a rock cell, a
## grass cell) that came to be drawn during a flight: how long it took from
## first wanted to drawn, and where the time went. On with `--frame-log=FILE`,
## written beside it as FILE.stream.csv with the frame log's clock. Read it
## with tools/stream_report.py. Main thread only; off, a call costs one
## static read at the call site (`if StreamLog.on`).
##
## A row's parts (ms): queue (wanted, waiting to be asked of the pool), pool
## (asked, waiting for a worker thread), build (the worker's work), commit
## (built, waiting for the main thread's budget), hold (a mesh, not yet drawn:
## a land chunk waits for its three siblings).

static var on := false
static var _file: FileAccess
static var _seen := {}     # layer -> {key: [want_usec, want_dist, ask_usec, ended_usec, build_ms, commit_usec]}
static var _rows := 0

static func begin(args: PackedStringArray) -> void:
	if on: return
	for a in args:
		if a.begins_with("--frame-log="):
			_file = FileAccess.open(a.get_slice("=",1)+".stream.csv",FileAccess.WRITE)
			if _file == null: return
			_file.store_line("t,layer,level,dist_want,dist_show,queue_ms,pool_ms,build_ms,commit_ms,hold_ms,total_ms")
			on = true

## First wanted, `dist` m from the eye. Again for the same key: nothing.
static func want(layer: StringName, key: Variant, dist: float) -> void:
	var d: Dictionary = _seen.get_or_add(layer,{})
	if not d.has(key): d[key] = [Time.get_ticks_usec(),dist,0,0,0.0,0]

## Asked of the worker pool.
static func ask(layer: StringName, key: Variant) -> void:
	var e: Variant = (_seen.get(layer,{}) as Dictionary).get(key)
	if e != null and e[2] == 0: e[2] = Time.get_ticks_usec()

## Picked up by the main thread: the worker took `build_ms` and ended at
## `ended_usec` (Time.get_ticks_usec on the worker).
static func built(layer: StringName, key: Variant, build_ms: float, ended_usec: int) -> void:
	var e: Variant = (_seen.get(layer,{}) as Dictionary).get(key)
	if e == null or e[5] != 0: return
	e[3] = ended_usec
	e[4] = build_ms
	e[5] = Time.get_ticks_usec()

## Drawn, `dist` m from the eye: its row written.
static func show(layer: StringName, key: Variant, level: int, dist: float) -> void:
	var d: Dictionary = _seen.get(layer,{})
	var e: Variant = d.get(key)
	if e == null: return
	d.erase(key)
	# The load before the first frame is not a flight's streaming.
	if FrameLog._last < 0 or e[2] == 0 or e[5] == 0: return
	var now := Time.get_ticks_usec()
	var ended: int = e[3] if e[3] > 0 else e[5]
	_file.store_line("%.3f,%s,%d,%.0f,%.0f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f" % [
		(now-FrameLog._start)/1000000.0,layer,level,e[1],dist,
		(e[2]-e[0])/1000.0,maxf((ended-e[2])/1000.0-float(e[4]),0.0),e[4],
		(e[5]-ended)/1000.0,(now-e[5])/1000.0,(now-e[0])/1000.0])
	_rows += 1
	if _rows % 64 == 0: _file.flush()

## Keys neither in `a` nor `b` forgotten (no longer wanted: a later want
## starts their clock again).
static func keep(layer: StringName, a: Dictionary, b: Dictionary) -> void:
	var d: Dictionary = _seen.get(layer,{})
	for key: Variant in d.keys():
		if not a.has(key) and not b.has(key): d.erase(key)

static func stop() -> void:
	if not on: return
	on = false
	_file.close()
	_file = null
