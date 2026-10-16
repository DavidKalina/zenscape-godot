extends RefCounted
## The game-feel round's features (docs/design/roguelike/items-contract.md),
## on by default: `--loot=off` turns them all off, `--no-<name>` one
## (e.g. `--no-merchant`, `--no-linger`). A feature asks `RunFeatures.on(&"merchant")`
## where it would lay or start itself. Cut features (the flyer, the
## Sun-Keepers) ask `RunFeatures.opted(&"flyer")`: off unless `--flyer`.

static var _args := PackedStringArray()
static var _read := false

static func on(feature: StringName) -> bool:
	if not _read:
		_args = OS.get_cmdline_user_args()
		_read = true
	if "--loot=off" in _args: return false
	return not ("--no-%s" % feature) in _args

## A feature cut from the run but kept in the code (run-trim-round1.md): off
## unless `--<name>` is given (e.g. `--flyer`, `--sun-keepers`); `--loot=off`
## still turns it off.
static func opted(feature: StringName) -> bool:
	if not _read:
		_args = OS.get_cmdline_user_args()
		_read = true
	if "--loot=off" in _args: return false
	return ("--%s" % feature) in _args

## A motif's own opt-out: false when `motif` (an isle's) lists `feature` in
## its `without()` (e.g. ["merchant", "beetle"]); every other motif keeps it.
static func motif_lets(feature: StringName, motif: Variant) -> bool:
	if not (motif is Object) or not (motif as Object).has_method("without"): return true
	return not String(feature) in ((motif as Object).call("without") as Array)

## The value of `--<name>=` (`fallback` when not given), e.g. `--linger=serpent`.
static func value(knob: String, fallback := "") -> String:
	if not _read:
		_args = OS.get_cmdline_user_args()
		_read = true
	for a in _args:
		if a.begins_with("--%s=" % knob): return a.get_slice("=",1)
	return fallback
