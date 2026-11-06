extends "res://scripts/endless/moments/moment.gd"
## The cloud punch: by day, climbing out of a cloud's top into sun after some
## seconds inside it, a rainbow arcs round the plane's shadow for a few
## seconds (scripts/shared/celestial.gd `moment_bow`: the sky draws it round
## the point straight away from the sun, so the sun must be behind and low
## enough for the bow to stand over the horizon), and frost that formed on
## the canopy in the cloud melts off (scripts/endless/canopy_frost.gd).
## Rare unless forced (--happen=cloud_punch).

const Where = preload("res://scripts/endless/moments/where.gd")
const CanopyFrost = preload("res://scripts/endless/canopy_frost.gd")

## The bow's strength at its height.
const BOW := 0.9
## Seconds: the bow comes up over BOW_IN, holds until BOW_HOLD, gone by BOW_OUT.
const BOW_IN := 1.0
const BOW_HOLD := 6.0
const BOW_OUT := 8.5
## Where the bow's sweep round its ring starts (celestial's grow, 0 to 1 from
## the foot round over the top): past the foot under the horizon, so it
## climbs into view at once.
const SWEEP_FROM := 0.26
## Seconds: the frost reaches in over FROST_IN, holds, melts from MELT_FROM
## until MELT_TO.
const FROST_IN := 0.45
const MELT_FROM := 1.4
const MELT_TO := 5.2

var t := 0.0
var _frost: CanvasLayer = null
var _drops := 0

func _init() -> void:
	name = &"cloud_punch"
	cue = &"cloud_top"
	hours = Vector2(6.0,18.5)
	where = [Where.sun_between(3.0,40.0),Where.sun_behind(70.0)]
	chance = 0.35
	cooldown = 900.0

func start(_ctx: Dictionary, game: Node) -> void:
	t = 0.0
	_drops = 0
	var c: Variant = _celestial(game)
	if c != null: c._rainbow_growth = maxf(float(c._rainbow_growth),SWEEP_FROM)
	if _frost == null or not is_instance_valid(_frost):
		_frost = CanopyFrost.new()
		game.add_child(_frost)
	_frost.set_frost(0.0,0.0)

func step(delta: float, game: Node) -> bool:
	t += delta
	var c: Variant = _celestial(game)
	if c != null: c.moment_bow = bow_at(t)
	if _frost != null and is_instance_valid(_frost):
		_frost.set_frost(cover_at(t),melt_at(t))
	# A few drops left as it melts (the wet layer, when the game has one).
	if t >= MELT_FROM and _drops < 3 and t >= MELT_FROM+float(_drops)*1.1:
		_drops += 1
		var water: Variant = game.get("water")
		if water != null and water.get("screen") != null: water.screen.wet(0.05)
	return t < maxf(BOW_OUT,MELT_TO)

func finish(game: Node) -> void:
	var c: Variant = _celestial(game)
	if c != null: c.moment_bow = 0.0
	if _frost != null and is_instance_valid(_frost): _frost.queue_free()
	_frost = null

static func bow_at(s: float) -> float:
	if s < BOW_IN: return BOW*smoothstep(0.0,BOW_IN,s)
	if s < BOW_HOLD: return BOW
	return BOW*(1.0-smoothstep(BOW_HOLD,BOW_OUT,s))

static func cover_at(s: float) -> float:
	if s < FROST_IN: return smoothstep(0.0,FROST_IN,s)
	if s < MELT_FROM: return 1.0
	return 1.0-smoothstep(MELT_FROM,MELT_TO,s)

static func melt_at(s: float) -> float:
	return smoothstep(MELT_FROM-0.2,MELT_TO-0.6,s)

static func _celestial(game: Node) -> Variant:
	if game.get("look") == null or game.look == null: return null
	return game.look.get("celestial")
