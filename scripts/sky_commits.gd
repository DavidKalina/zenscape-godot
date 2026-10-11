extends RefCounted
## The one budget every part of the sky that streams in mid-glide shares on
## the main thread: the islets, clusters, ranges, cumulus and forested isles
## each have their shapes and meshes made on
## workers, and only stand them up here, as nodes. One of them stands up in
## a frame at most once that frame has spent BUDGET_USEC on them: the first
## always may, so the sky always fills in, but two never pile into one
## frame. Each commit is timed, and kept for the record when `recording`.

## Microseconds a frame may spend standing the sky's parts up.
const BUDGET_USEC := 4000

static var _frame := -1
static var _used := 0
## While set, every commit is kept: [process frame, what, usec].
static var recording := false
static var log: Array = []
## While `recording`, the steps timed for the record only, never spent:
## [process frame, what, usec].
static var trace: Array = []

## True while this frame may stand one more part up.
static func open() -> bool:
	_roll()
	return _used < BUDGET_USEC

## A part stood up this frame, `usec` long.
static func spend(what: String, usec: int) -> void:
	_roll()
	# Never zero, so a frame's first commit closes it for the next heavy one.
	_used += maxi(usec,1)
	if recording: log.append([_frame,what,usec])

## A step timed for the record only (`trace`), while `recording`.
static func note(what: String, usec: int) -> void:
	if recording: trace.append([Engine.get_process_frames(),what,usec])

## This frame's spend so far (usec).
static func used() -> int:
	_roll()
	return _used

static func _roll() -> void:
	var f := Engine.get_process_frames()
	if f == _frame: return
	_frame = f
	_used = 0
