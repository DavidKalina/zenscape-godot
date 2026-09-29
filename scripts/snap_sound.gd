extends AudioStreamPlayer
## The finger snap's sound (docs/scenic/modeless.md "Void slice"): a dry, bright
## crack with a small room, played by the hand reach the moment a snap fires,
## which is the frame the middle finger starts its slam (SnapOut's SNAP_HIT is
## its first frame after the loaded hold). It is heard wherever the hand is, at
## one level: the snap is the player's own hand, not a sound in the world.
##
## The three takes are baked by `tools/generate_nature_audio.py --snap`. Each
## snap picks a take other than the last one and varies its pitch and level a
## little, so a run of snaps never sounds mechanical. A Shift-snap (stepping the
## golden hours) is a lighter snap: quieter and a touch higher, as a smaller,
## quicker flick is. It plays on the "Genesis" bus (the Sound volume), with the
## world's other sounds.

const Audio = preload("res://scripts/genesis_audio.gd")
const TAKES := ["finger-snap-1","finger-snap-2","finger-snap-3"]
## Linear gain of a full snap, before the Sound volume (about -8 dB: louder
## than the world's one-shots, as it answers the player's click).
const GAIN := 0.4
## A light (Shift) snap's share of GAIN.
const LIGHT := 0.55
## Pitch scale ranges, full and light.
const PITCH := Vector2(0.93,1.07)
const LIGHT_PITCH := Vector2(1.08,1.18)
## The level varies by up to this many dB either way.
const LEVEL_JITTER_DB := 1.5

var _takes: Array[AudioStream] = []
var _last := -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "SnapSound"
	Audio.ensure_buses()
	bus = Audio.BUS
	max_polyphony = 2
	_rng.randomize()
	for take: String in TAKES:
		_takes.append(load("res://assets/audio/"+take+".wav"))

## Play one snap; `light` for a Shift-snap.
func snap(light := false) -> void:
	if _takes.is_empty(): return
	var pick := _rng.randi_range(0,_takes.size()-1)
	if pick == _last and _takes.size() > 1: pick = (pick+1)%_takes.size()
	_last = pick
	stream = _takes[pick]
	var spread := LIGHT_PITCH if light else PITCH
	pitch_scale = _rng.randf_range(spread.x,spread.y)
	volume_db = linear_to_db(GAIN*(LIGHT if light else 1.0))+_rng.randf_range(-LEVEL_JITTER_DB,LEVEL_JITTER_DB)
	play()
