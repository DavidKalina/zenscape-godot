extends RefCounted
## Dynamic resolution: the 3D drawn at fewer pixels while the GPU can't hold
## TARGET_FPS (the frame cap, when that is lower), and at more again when it
## can, never above the player's own 3D resolution (GameSettings.ceiling: the
## scale RenderResolution last gave the window, from Settings > 3D resolution,
## --render-scale or the preset's lines).
##
##     var dyn := DynamicResolution.new()
##     dyn.begin(get_viewport())     # after GameSettings.begin
##     dyn.tick(delta)               # every frame (`hold`: at the ceiling, photo mode)
##     dyn.sync()                    # after the player changes a setting
##
## RenderResolution sets the window's scale again whenever the window is
## resized: `tick` sees the scale is no longer its own and reads the ceiling
## again.
##
## It reads the GPU's time for the viewport's last frame (the flight turns
## the measuring on) and moves through STEPS. Down when the time has sat over
## DOWN of the frame's budget for DOWN_HOLD s: straight to the first step
## that should fit (DOWN_WITH of the GPU's time taken to follow the pixel
## count), so a dive from height is one change, not three. Up one when the
## time it would take a step up (UP_WITH of it following the pixels) has sat
## under UP of the budget for UP_HOLD s. (Measured at 2560x1440 on an RTX
## 4070 SUPER: 0.68 to 0.84 of the time follows the pixels from 400 m up,
## 0.42 low among trees; down guesses high and up guesses high too, so it
## neither overshoots down nor climbs back into trouble.) A change rebuilds
## the viewport's buffers (a frame of 25 to 35 ms there), so the frames just
## after it are not counted (SETTLE s), nor is the load's first START s. It sets the viewport's scale and leaves
## RenderResolution.scale_override (the player's choice) alone, so a scene
## that starts again starts at the player's own.
##
## Settings > Dynamic resolution turns it off (look.cfg [display] dynamic_3d);
## --dynamic-res=0 or =1 for one run, --dynamic-fps=N the frame rate held.
## The scale is a column of the frame log (scripts/frame_log.gd `scale`).
## Off in headless and harness (-s) runs unless --dynamic-res=1, so a
## measurement draws what it asked for.

const GameSettings = preload("res://scripts/endless/ui/game_settings.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const STEPS := [1.0,0.85,0.75,0.67,0.58,0.5]
const TARGET_FPS := 60.0
const DOWN := 0.95
const UP := 0.82
const DOWN_HOLD := 0.35
const UP_HOLD := 2.5
const SETTLE := 0.4
const START := 2.0
const DOWN_WITH := 0.85
const DOWN_FIT := 0.92
const UP_WITH := 0.75
## The GPU's time is smoothed over about this long (s).
const SMOOTH := 0.2

var on := false
## The scale in force (the viewport's), and the most it may be.
var scale := 1.0
var ceiling := 1.0
## The GPU's time, smoothed (ms), and the steps taken this flight.
var gpu_ms := 0.0
var steps_down := 0
var steps_up := 0

var _viewport: Viewport
var _budget := 1000.0/TARGET_FPS
var _own_fps := false
var _forced := -1
var _over := 0.0
var _under := 0.0
var _settle := 0.0

func begin(viewport: Viewport) -> void:
	_viewport = viewport
	scale = viewport.scaling_3d_scale
	_settle = START
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--dynamic-res="): _forced = 1 if a.get_slice("=",1) != "0" else 0
		elif a.begins_with("--dynamic-fps="):
			_budget = 1000.0/clampf(a.get_slice("=",1).to_float(),20.0,240.0)
			_own_fps = true
	sync()

## The player's settings read again: on or off, and the ceiling. Off (or a
## lower ceiling) puts the viewport at the ceiling at once.
func sync() -> void:
	if _viewport == null: return
	var args := OS.get_cmdline_args()
	var script_run := DisplayServer.get_name() == "headless" or "-s" in args or "--script" in args
	on = GameSettings.dynamic_resolution() and not script_run
	if _forced >= 0: on = _forced == 1
	ceiling = GameSettings.ceiling()
	# (A new choice has already set the viewport: scripts/endless/ui/game_settings.gd.)
	scale = _viewport.scaling_3d_scale
	if not on or scale > ceiling: _step_to(ceiling)

func tick(delta: float, hold := false) -> void:
	if not on or _viewport == null: return
	# Set by another hand (the window resized, RenderResolution.apply): the
	# ceiling may have moved with it.
	if absf(_viewport.scaling_3d_scale-scale) > 0.001:
		sync()
		_step_to(scale)
	if hold:
		if scale < ceiling-0.005: _step_to(ceiling)
		return
	# No faster than the frame cap in force (a preset's 45 has 22 ms a frame).
	if not _own_fps:
		var fps := minf(TARGET_FPS,float(Engine.max_fps)) if Engine.max_fps > 0 else TARGET_FPS
		# Locked 60 (GameSettings): room under the cap, so a heavy view doesn't miss a frame.
		if Engine.max_fps > 0 and GameSettings.lock_60(): fps *= GameSettings.LOCK_MARGIN
		_budget = 1000.0/clampf(fps,20.0,240.0)
	var now := RenderingServer.viewport_get_measured_render_time_gpu(_viewport.get_viewport_rid())
	if now <= 0.0: return
	if _settle > 0.0:
		_settle -= delta
		gpu_ms = now
		return
	gpu_ms = lerpf(gpu_ms,now,clampf(delta/SMOOTH,0.0,1.0)) if gpu_ms > 0.0 else now
	if gpu_ms > _budget*DOWN:
		_under = 0.0
		_over += delta
		if _over >= DOWN_HOLD and scale > STEPS[-1]+0.005:
			steps_down += 1
			_step_to(_fit_down())
		return
	_over = 0.0
	var up := _step_up()
	if up < 0.0:
		_under = 0.0
		return
	if _at(up,UP_WITH) < _budget*UP:
		_under += delta
		if _under >= UP_HOLD:
			steps_up += 1
			_step_to(up)
	else: _under = 0.0

## The GPU's time at scale `s`, taking `with` of it to follow the pixel count.
func _at(s: float, with: float) -> float:
	var ratio := (s/scale)*(s/scale)
	return gpu_ms*(1.0+with*(ratio-1.0))

## The first step below the scale that should fit the budget (the last if
## none does).
func _fit_down() -> float:
	for s: float in STEPS:
		if s < scale-0.005 and _at(s,DOWN_WITH) < _budget*DOWN_FIT: return s
	return STEPS[-1]

## The next scale up: the lowest step over the scale that the ceiling allows,
## else the ceiling itself (it lies between two steps), or -1 at the ceiling.
func _step_up() -> float:
	if scale >= ceiling-0.005: return -1.0
	var best := ceiling
	for s: float in STEPS:
		if s > scale+0.005 and s < best: best = s
	return best

func _step_to(s: float) -> void:
	scale = minf(s,ceiling)
	_over = 0.0
	_under = 0.0
	_settle = maxf(_settle,SETTLE)
	if _viewport != null and absf(_viewport.scaling_3d_scale-scale) > 0.001: _viewport.scaling_3d_scale = scale

## For the numbers line: "" while off or at the ceiling.
func note() -> String:
	if not on: return ""
	return " (dynamic, %d%% chosen)" % roundi(ceiling*100.0) if scale < ceiling-0.005 else " (dynamic)"
