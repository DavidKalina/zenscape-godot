extends RefCounted
## A moment the happenings director fires (scripts/endless/happenings.gd).
## A moment sets its fields in `_init`, then the director asks `unfit` when
## its cue comes, rolls `chance_at` unless it is forced, and calls `start`,
## then `step` each frame until it returns false, then `finish`.
##
## The context (`ctx`, Happenings.context): cue, at (the plane), area,
## velocity, forward (flat), heading, hour, weather, sun (towards it), time.

## Its name: --happen=<name> forces it.
var name := &""
## The cue it listens for (Happenings.CUES).
var cue := &""
## The hours it may fire in (0..24); from > to wraps past midnight.
var hours := Vector2(0.0,24.0)
## The weathers it may fire in.
var weathers: Array[String] = ["clear"]
## Where: predicates `func(ctx: Dictionary, game: Node) -> String`, "" when
## the place fits, else why not (scripts/endless/moments/where.gd).
var where: Array[Callable] = []
## The chance it fires when its cue comes and it fits (0..1).
var chance := 0.1
## Once fired in an area, not again there for this long (s of play).
var cooldown := 600.0

## Why the moment doesn't fit `ctx` now ("" when it does): the hour, the
## weather, then each of `where` in turn.
func unfit(ctx: Dictionary, game: Node) -> String:
	if not in_hours(float(ctx.hour)): return "hour %.1f outside %.1f-%.1f" % [float(ctx.hour),hours.x,hours.y]
	if not weathers.has(str(ctx.weather)): return "weather %s" % ctx.weather
	for test: Callable in where:
		var why: String = test.call(ctx,game)
		if why != "": return why
	return ""

func in_hours(h: float) -> bool:
	if hours.x <= hours.y: return h >= hours.x and h <= hours.y
	return h >= hours.x or h <= hours.y

## The chance at `ctx` (a moment may raise it somewhere: the start's inlet).
func chance_at(_ctx: Dictionary, _game: Node) -> float:
	return chance

## Begins: what it does.
func start(_ctx: Dictionary, _game: Node) -> void:
	pass

## Each frame while it runs; false when it is done.
func step(_delta: float, _game: Node) -> bool:
	return false

## Puts back what it changed (also when the scene goes mid-moment).
func finish(_game: Node) -> void:
	pass
