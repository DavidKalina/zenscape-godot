extends RefCounted
## The snap (docs/scenic/modeless.md "Void slice"): it is instantly day or
## night. Shift steps the golden hours instead: dawn, noon, dusk, night, dawn.
## Since 2026-09-30 it is the almanac's Time pocket (scripts/almanac.gd). The
## void's click, the hand snapping its fingers with a sound, is kept behind
## `--void-snap` (`enabled`); without it a click in the void does nothing.
##
## The cut is instant (SNAP_BLEND 0): the world clock is wound forward to the
## new hour at once, the way scripts/spin_time.gd winds it (the day moves on,
## nothing runs backwards), and every smoothing between the hour and the
## screen is bypassed for it:
## - a mood cross-fade in flight is landed first (`mood_look.finish_fade`),
##   or it would carry the old hour back in over 1.2 s;
## - a skip in progress (`WorldClock.skip_to`, the N key's easing) is dropped
##   by setting the time outright;
## - the celestial rig is rebuilt at once (`update_rig`), so the lights, the
##   sky's and fog's globals and everything reading `state` are the new hour's
##   this frame, not the next;
## - the sky's radiance map, which normally refreshes over several frames
##   (Sky.PROCESS_MODE_INCREMENTAL, scripts/landscape_lighting.gd), runs in
##   real time for RADIANCE_SECONDS so the reflections follow at once;
## - the wildlife calls (studies/nature_audio.gd) that belong to the other half
##   of the day are faded out, and the new half's first call comes soon. The
##   cricket and frog beds already follow daylight every frame.
## - the life notices (scripts/life_notice.gd): night wakes the fireflies in
##   a wave, and day brings a dawn chorus.
##
## Pins behave as they do for a spin: a clock that was running keeps running
## from the new hour; a held clock is pinned again at it (`mood_look.pin_hour`).

## The hours (celestial phases) a snap lands on: mood_look's Night and Morning.
const NIGHT := 0.035
const DAY := 0.345
## Shift: the golden hours in order (mood_look's Dawn, Midday, Dusk, Night).
const STEPS := [0.275,0.47,0.705,0.035]
## A phase this close ahead of a step counts as on it, so a step always moves.
const STEP_EPSILON := 0.01
## Seconds of real-time radiance after a snap.
const RADIANCE_SECONDS := 0.3
const Disturbance = preload("res://scripts/disturbance.gd")
## mood_look's Time of day ids for the hours a snap lands on, to pin them.
const PINS := {0.035:"night",0.345:"morning",0.275:"dawn",0.47:"midday",0.705:"dusk"}

## True with `--void-snap`: a click in the void snaps, as before the almanac.
static func enabled() -> bool:
	return "--void-snap" in OS.get_cmdline_user_args()

## The mood_look Time of day id of an hour a snap lands on ("" for others).
static func pin_id(phase: float) -> String:
	for at: float in PINS:
		if absf(at-phase) < 0.0005: return PINS[at]
	return ""

## The phase a snap from `phase` lands on.
static func target_phase(phase: float, step: bool) -> float:
	if step:
		var best := INF
		var choice: float = STEPS[0]
		for candidate: float in STEPS:
			var gap := fposmod(candidate-phase,1.0)
			if gap > STEP_EPSILON and gap < best:
				best = gap
				choice = candidate
		return choice
	return DAY if is_night(phase) else NIGHT

## Night is the sun under the horizon.
static func is_night(phase: float) -> bool:
	return WorldClock.elevation_for_phase(phase) < 0.0

## Snap the world to the next day or night (or golden hour, with `step`).
## Returns the phase it landed on.
static func snap(scene: Node, step: bool) -> float:
	var clock: WorldClock = scene.get("world_clock")
	var sky: Object = scene.get("_celestial")
	var mood: Node = scene.get("mood_look")
	if mood != null: mood.finish_fade()
	var was_night := is_night(clock.phase)
	var goal := target_phase(clock.phase,step)
	var hours := fposmod(WorldClock.hour_for_phase(goal)-clock.hour,WorldClock.HOURS_PER_DAY)
	var total := float(clock.day)*WorldClock.HOURS_PER_DAY+clock.hour+hours
	clock.set_time(int(floor(total/WorldClock.HOURS_PER_DAY)),fposmod(total,WorldClock.HOURS_PER_DAY))
	if not clock.running and mood != null: mood.pin_hour(goal)
	elif sky != null: sky.set_phase(goal)
	if scene.get("_season_shown") != null: scene.set("_season_shown",clock.season)
	if sky != null: sky.update_rig()
	_radiance_now(scene)
	_wildlife(scene,is_night(goal))
	_disturb(scene,was_night,is_night(goal))
	return goal

## Refresh the sky's radiance every frame for a moment, then as before.
static func _radiance_now(scene: Node) -> void:
	var environment: Environment = scene.get("_environment")
	if environment == null or environment.sky == null: return
	var sky := environment.sky
	if not sky.has_meta("snap_mode"): sky.set_meta("snap_mode",sky.process_mode)
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	var count := int(sky.get_meta("snap_count",0))+1
	sky.set_meta("snap_count",count)
	scene.get_tree().create_timer(RADIANCE_SECONDS).timeout.connect(func() -> void:
		if not is_instance_valid(sky) or int(sky.get_meta("snap_count",0)) != count: return
		sky.process_mode = int(sky.get_meta("snap_mode"))
		sky.remove_meta("snap_mode"))

## Night falling wakes the fireflies in a wave; day breaking brings a dawn
## chorus (scripts/disturbance.gd, scripts/life_notice.gd).
static func _disturb(scene: Node, was_night: bool, night: bool) -> void:
	if was_night == night: return
	var target: Variant = scene.get("target")
	Disturbance.raise(target if target is Vector3 else Vector3.ZERO,0.0,1.0,"night" if night else "dawn")

## The other half of the day's calls fade out; the new half's first comes soon.
static func _wildlife(scene: Node, night: bool) -> void:
	var audio: Node = scene.get("_ambient_audio")
	var nature: Node = audio.get("nature") if audio != null else null
	if nature != null and nature.has_method("snap_to"): nature.snap_to(night)
