extends "res://scripts/interactables/foot_slab.gd"
## A bobbing slab (docs/design/foot-interactables.md): a floating stone that
## bobs gently on its own (BOB m up and down over BOB_TIME s), sinks SINK
## and tips TILT toward him under his weight, takes a kick down landed on
## hard (GIVE), and springs back as he leaves it, overshooting (its spring
## HZ, damped DAMP). Jumped off on its way back up, its rise goes with him
## (scripts/interactables/foot_pieces.gd: a timed jump off a rebounding
## slab goes higher). The numbers are live (the yard's F4,
## studies/interactables_yard.gd): every slab reads them each frame.

const SINK := 0.24
const TILT := 0.09
const GIVE := 0.05
const HZ := 1.15
const DAMP := 0.28
const BOB := 0.12
const BOB_TIME := 4.6

static var t_sink := SINK
static var t_tilt := TILT
static var t_give := GIVE
static var t_hz := HZ
static var t_damp := DAMP
static var t_bob := BOB
static var t_bob_time := BOB_TIME

func advance(delta: float) -> void:
	sink = t_sink
	tilt = t_tilt
	give = t_give
	hz = t_hz
	damp = t_damp
	bob = t_bob
	bob_time = t_bob_time
	super.advance(delta)
