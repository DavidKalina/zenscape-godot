class_name BridgeConstruction
extends RefCounted
## The bridge gets built. This is the thing that decides when the next board
## goes down, and nothing else.
##
## It owns one number -- `rate`, planks per world hour -- and turns the world
## clock into planks on a `SuspensionBridge`. It does not know where the wood
## comes from, what it costs, or whether anyone is holding it. That is
## deliberate and is the open question: see "Built over time" in
## `docs/campsite-life/README.md`. The rate here is a placeholder chosen so the
## build is watchable in a study, not an economy.
##
## Two ways a plank gets laid:
##
##   * on the timer. `advance(world_hour, delta)` accumulates fractional planks
##     and lays whole ones as they come due. This is the floor: pacing stays a
##     knob whatever else is or is not happening.
##   * by hand. When `builder` is set it is asked first, and if it answers true
##     it has taken the job -- a camper is walking out to the frontier with a
##     board -- and must call `lay()` when it gets there. If it does not within
##     `grace` seconds the timer lays the plank anyway, so a camper who wandered
##     off, was eaten, or ran out of wood cannot stall the crossing forever.
##
## World time, not engine time, because the build is meant to be measured in
## days of the world and a study that pauses should not build while paused.
## `advance` takes the absolute world hour (`day * 24 + hour`); it ignores
## anything that is not an increase, so a scrubbed or reloaded clock never lays
## a thousand planks at once.

## Planks per world hour. Placeholder: at the default 480 s world day that is a
## world hour every 20 real seconds, so the study's ~109-slot span takes about
## nine world hours, three real minutes. Nothing downstream depends on it.
const DEFAULT_RATE := 12.0
## Seconds a hand-laid plank may be in transit before the timer gives up on the
## builder and lays it itself.
const DEFAULT_GRACE := 40.0
## The most world hours one `advance` may spend, so a day skipped in one frame
## does not build the whole bridge in that frame.
const MAX_STEP := 2.0

var bridge: SuspensionBridge
var rate := DEFAULT_RATE
var grace := DEFAULT_GRACE
## `-> bool`: a builder saying "I have this one". Optional.
var builder := Callable()
## `(String) -> void`: one line of world event. Optional.
var on_event := Callable()

var _hour := -1.0
var _credit := 0.0
var _claimed := false
var _waited := 0.0
var _started := false
## The last quarter announced, 0..4, so each milestone is spoken once.
var _spoken := 0

## Take charge of a bridge from `world_hour` onward. Nothing is laid here.
func bind(a_bridge: SuspensionBridge, world_hour: float) -> void:
	bridge = a_bridge
	_hour = world_hour
	_credit = 0.0
	_claimed = false
	_waited = 0.0
	_started = bridge != null and bridge.laid_count() > 0
	_spoken = int(floor(progress() * 4.0)) if _started else 0

func total() -> int:
	return bridge.plank_count() if bridge != null else 0

func laid() -> int:
	return bridge.laid_count() if bridge != null else 0

func is_complete() -> bool:
	return bridge != null and bridge.is_complete()

func progress() -> float:
	var slots := total()
	return 1.0 if slots <= 0 else clampf(float(laid()) / float(slots), 0.0, 1.0)

## A one-line status for a study readout.
func readout() -> String:
	if bridge == null: return "no bridge"
	if is_complete(): return "bridge complete (%d planks)" % total()
	return "bridge %d%% built (%d/%d planks, %.0f/world hour)" % [roundi(progress() * 100.0), laid(), total(), rate]

## World time moves; the deck grows. `delta` is the engine seconds that passed
## with it, and is only used to time the builder out. Returns planks laid now.
func advance(world_hour: float, delta: float) -> int:
	if bridge == null or is_complete(): return 0
	if _hour < 0.0 or not is_finite(world_hour):
		_hour = world_hour
		return 0
	var step := clampf(world_hour - _hour, 0.0, MAX_STEP)
	_hour = world_hour
	_credit += step * maxf(0.0, rate)
	if _claimed:
		_waited += maxf(0.0, delta)
		if _waited < grace: return 0
		# The builder never arrived. Lay it on the timer and stop waiting.
		_claimed = false
		_waited = 0.0
		return _place(1)
	# A hair of slack, so ten tenths of an hour are ten planks and not nine.
	var due := int(floor(_credit + 0.000001))
	if due <= 0: return 0
	_credit -= float(due)
	if builder.is_valid() and bool(builder.call()):
		_claimed = true
		_waited = 0.0
		# One plank is in a camper's arms; any others due this step still go
		# down on the timer, so a slow walk cannot cap the rate.
		return _place(due - 1)
	return _place(due)

## Lay `planks` immediately, whatever the clock says. For tests and for the
## study's "finish it now" key.
func advance_by(planks: int) -> int:
	return _place(planks)

## Finish the bridge here and now. Returns how many planks that took.
func complete() -> int:
	return _place(total() - laid())

## A builder reporting that the board it took is down. False when nobody had
## taken one, or the timer already gave up on it.
func lay() -> bool:
	if not _claimed: return false
	_claimed = false
	_waited = 0.0
	return _place(1) > 0

## The builder is giving the job back (no wood, no route, it fell in the chasm).
func release() -> void:
	_claimed = false
	_waited = 0.0

func _place(planks: int) -> int:
	if bridge == null or planks <= 0: return 0
	var before := laid()
	if not _started and before == 0 and planks > 0:
		_started = true
		_say("the first plank goes down on the bridge")
	bridge.set_laid(before + planks)
	var placed := laid() - before
	_milestones()
	return placed

## A quarter of the deck, half of it, three quarters, and the last board. Said
## once each, in order, however the build got there.
func _milestones() -> void:
	var quarter := int(floor(progress() * 4.0))
	while _spoken < quarter:
		_spoken += 1
		match _spoken:
			1: _say("a quarter of the bridge is planked")
			2: _say("the bridge is planked half way")
			3: _say("three quarters of the bridge is planked")
			4: _say("the bridge is complete; the crossing is open")

func _say(message: String) -> void:
	if on_event.is_valid(): on_event.call(message)
	else: print("BRIDGE: ", message)
