extends RefCounted
## Where the wonders in sight of the plate stand: one of each kind risen
## through the cloud sea round the plate's first home, laid out together so
## none stands on another, on a fixed island or in the islands' currents,
## and each in its own direction, so a first flight off the plate meets a
## different one whichever way it goes (tests/test_sky_layout.gd). Home
## coordinates (the plate at the origin); each turn is radians about y.
##
## Each kind reads its HOME, HOME_TURN and KEEP from here (scripts/
## sky_peaks.gd, sky_pillars.gd, sky_tepuis.gd, sky_towers.gd,
## sky_forest_isles.gd); and every kind scattered through the far cells
## keeps off all of them (`blocks`). Nothing of the sky is preloaded here, so
## any kind may read it without a preload cycle, and the look pass reads the
## ring's switch here without reaching the sky world (scripts/look_pass.gd).

## The mountain range: out along +x, a little toward -z, ~1210 m off; its
## crest square to the plate, its long face and the gorge's mouth looking
## back at it.
const RANGE := Vector3(1105.0,0.0,-492.0)
const RANGE_TURN := -1.1519
const RANGE_KEEP := 720.0
## The pillar forest: toward +z and -x, ~1050 m off; its face and thread
## turned to the plate.
const PILLARS := Vector3(-525.0,0.0,909.0)
const PILLARS_TURN := 2.6178
const PILLARS_KEEP := 470.0
## The tepui: straight out along -z, ~1210 m off; its great fall pouring
## toward the plate, turned a little off it (0.216 rad) so it is seen
## three-quarter on.
const TEPUI := Vector3(-42.0,0.0,-1209.0)
const TEPUI_TURN := 0.2507
const TEPUI_KEEP := 580.0
## The towering cumulus: toward +x and +z, ~460 m off, inside the
## archipelago between its islands, near enough that the haze leaves it
## clear.
const TOWER := Vector3(331.0,0.0,320.0)
const TOWER_KEEP := 340.0
## The forested isle: out along -x, a little toward -z, ~700 m off, out
## past the archipelago's currents; its long side square to the plate.
const ISLE := Vector3(-658.0,-14.0,-239.0)
const ISLE_TURN := 1.2224
const ISLE_KEEP := 300.0

## Whether the wonders stand at all. None of the stone ones do by default:
## the game dropped the mountain ranges (`peaks`: the one in sight of the
## plate and the ring round the world's edge, scripts/sky_world.gd), and
## the pillar forests, the tepui and the forested isles clash with the
## islands' minimal look. The code is kept, reached only by its flags
## (`read_flags`): --peak-ring stands the ranges and the ring round them,
## --peaks the ranges alone (scattered through the cells, the sky open and
## endless), --wonders every stone wonder and the isles (`stone`, `isles`;
## scripts/sky_islands.gd). Tests and captures of a kind turn it on
## themselves. The towering cumulus always stands.
static var peaks := false
static var stone := false
static var isles := false
## The ring, the bounds and the edge wind (scripts/sky_world.gd), with the
## ranges they are made of: off unless --peak-ring.
static var ring := false

static var _flags_read := false

## Reads --peak-ring and --peaks from the command line, once, whoever asks
## first (the look pass sets the sky before the glide's islands exist).
static func read_flags() -> void:
	if _flags_read: return
	_flags_read = true
	use_flags(preload("res://scripts/launch_args.gd").user_args())

## Turns on what `args` ask for (never off): the run's flags, or a test's
## (tests of the ring run under `use_flags(["--peak-ring"])`).
static func use_flags(args: PackedStringArray) -> void:
	if "--peak-ring" in args:
		ring = true
		peaks = true
	if "--peaks" in args: peaks = true

## True while the ring, the bounds and the edge wind stand.
static func ring_on() -> bool:
	read_flags()
	return ring and (peaks or stone)

## How much of the Opal cloud sea's painted distant peaks to draw (shaders/
## sky_cloud_sea_opal.gdshaderinc `sea_peaks`): none while the ring's real
## ranges stand (they travel with the eye and read wrong beside them).
static func sea_peaks() -> float:
	return 0.0 if ring_on() else 1.0

## How much of the sky dome's painted horizon ridges to draw (shaders/
## reference_sky.gdshader `horizon_ridges`, scripts/look_pass.gd): none
## while the ring's real ranges stand, in the build view and the glide;
## they showed through its notches and passes as flat grey bands.
static func painted_ridges() -> float:
	return 0.0 if ring_on() else 1.0

## Every home wonder standing: [middle, keep-out (m, plate plane)].
static func spots() -> Array:
	var out := [[TOWER,TOWER_KEEP]]
	if peaks or stone: out.append([RANGE,RANGE_KEEP])
	if stone: out.append_array([[PILLARS,PILLARS_KEEP],[TEPUI,TEPUI_KEEP]])
	if isles: out.append([ISLE,ISLE_KEEP])
	return out

## True if a home point lies within a home wonder's keep-out (plus
## `margin`): where a kind scattered through the far cells must not stand.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	for s: Array in spots():
		var at: Vector3 = s[0]
		if Vector2(at.x-home.x,at.z-home.z).length() < float(s[1])+margin: return true
	return false
