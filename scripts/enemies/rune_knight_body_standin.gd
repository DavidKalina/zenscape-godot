extends Node3D
## The rune knight's stand-in body (docs/design/rune-knight/
## spec-rune-knight.md, "The contract"): primitives in the kit's stone,
## behind the body API the mind (scripts/enemies/rune_knight.gd) drives him
## through, so a Blender body can drop in later with the mind unchanged.
##
## - **The API:** `play(clip)`, signal `beat_reached(clip, beat)`,
##   `socket(name) -> Node3D`, `set_effect(name, on)`, and `shape()` (his
##   room, eye, reach, stride and pace, from his height). Clips and beats
##   are CLIPS; sockets SOCKETS; effects `rune_glow`, `wind_gather` and
##   `wind_blade`. `play(clip, form)`: a clip may have forms (KEYS
##   "clip:form"): `gather` "blade" (the right arm raised, the air drawn
##   into the gauntlet), `slash` "level" (wound back low and wide to his
##   right, swept flat across) and "high" (raised over his right
##   shoulder, cut down to his left).
## - **The mind moves him, the body moves its limbs:** the mind sets his
##   parent's transform (the root on the deck, his yaw) and plays `walk` or
##   `turn` while it moves it; the body keeps each foot where it was set and
##   steps the trailing one to where the root will be (planted steps), the
##   hips sinking SETTLE at each plant and coming slowly back (heavy), and
##   swaying over the standing foot. Legs reach their feet by two-bone IK.
##   Each footfall sends `plant`. In `idle` a foot left out of place steps
##   home and he stands.
## - **The other clips** (`notice`, `gather`, `throw`, `catch`, `return`,
##   `stagger`) run their CLIPS length and send their beats at their times,
##   then `end`. Their key poses are KEYS (arms, lean, head, sink), eased
##   key to key; a clip starts from the pose he was in (BLEND s). In
##   `stagger` his feet step after the pushed root in quick STAGGER_STEP
##   steps; falling (the root dropping fast) they hang under him.
## - **hands_mid** follows the midpoint of his fists, so a held shot sits
##   between them wherever the pose puts them.
## - **wind_gather:** streaks of air drawn in from round him to hands_mid
##   (the dragon cyclone's streak), faded in and out with the effect; into
##   `blade` while `wind_blade` is on.
## - **wind_blade:** a blade of air along his right forearm, growing out
##   past the fist over BLADE_GROW s (streaks flickering along it), the
##   `blade` socket in its middle.
## - **His look:** a blocky helm with a visor slit and a crest, a broad
##   chest over a narrow belly, pauldrons, big gauntlets, legs on hip and
##   knee pivots; rune lines on the chest and gauntlets, dim, lit by
##   `rune_glow`.
## - **The skid** (`skid`, beats `plant` as the heels dig in, `end`): the
##   mind slides his root; his feet slide with it, braced one ahead of the
##   other along the way he goes, heels leading, dust off them
##   (scripts/enemies/body_dust.gd) while he moves fast; he leans into the
##   push (the key's lean turned to face it), arms out for balance, low.
## - **The teeter** (`teeter`, `end`): arms windmilling, leaning out over
##   the drop and back (the way his last skid went), runes flickering.
## - **The fall** (`fall`, looping till the mind plays another): arms
##   flung up, legs hanging.
## - **rune_crack** (`set_effect("rune_crack", on, form)`, form `chest`,
##   `hand_l` or `hand_r`): that rune's lines flare, split apart, a dark
##   crack shows across them, they flicker CRACK_FLICKER s and go dark for
##   good (dust off the rune).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const BodyDust = preload("res://scripts/enemies/body_dust.gd")
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")

signal beat_reached(clip: String, beat: String)

## Clips: length (s), loop, beats {name: time (s)}. `walk`'s and `turn`'s
## `plant` come from the footfalls themselves (their length is a step's).
const CLIPS := {
	"idle": {"length": 2.0, "loop": true, "beats": {}},
	"walk": {"length": 0.95, "loop": true, "beats": {"plant": -1.0}},
	"turn": {"length": 0.8, "loop": true, "beats": {"plant": -1.0}},
	"notice": {"length": 0.6, "loop": false, "beats": {}},
	"gather": {"length": 1.0, "loop": false, "beats": {"grab": 0.25, "full": 1.0}},
	"throw": {"length": 0.7, "loop": false, "beats": {"release": 0.35}},
	"catch": {"length": 0.6, "loop": false, "beats": {"contact": 0.1, "hold": 0.6}},
	"return": {"length": 0.5, "loop": false, "beats": {"release": 0.22}},
	"stagger": {"length": 1.8, "loop": false, "beats": {"plant": 0.9, "recover": 1.8}},
	"slash": {"length": 1.0, "loop": false, "beats": {"release": 0.52}},
	"skid": {"length": 1.6, "loop": false, "beats": {"plant": 0.1}},
	"teeter": {"length": 1.1, "loop": false, "beats": {}},
	"fall": {"length": 0.8, "loop": true, "beats": {}},
}
const SOCKETS := ["hand_r","hand_l","hands_mid","blade","chest_rune","eye"]
## Key poses: clip -> [[time (s), [arm (rad, forward-up), spread (rad,
## out), forearm (rad, bent), lean (rad, forward), head (rad, up), sink
## (share of tall)]], ...]. REST is idle's (and walk's, under its swing).
## A key may go on: [..., twist (rad, chest to his left), swing_r (rad,
## the right arm's way round from forward, + to his right), raise_r (rad,
## up from level), bend_r (rad, forearm), roll_r (rad, about the arm)]: the
## right arm aimed (BodyStandin `_arm_quat`), not mirrored from the left.
const REST := [0.0,0.12,0.25,0.0,0.0,0.0]
const KEYS := {
	# A jolt: he straightens, arms start out, then settles into a guard.
	"notice": [[0.0,REST],[0.12,[0.35,0.55,0.6,-0.15,0.22,-0.01]],[0.35,[0.3,0.4,1.0,0.1,-0.05,0.035]],[0.6,[0.3,0.35,0.95,0.06,0.0,0.025]]],
	# A dip (anticipation), arms flung up and wide at `grab`, drawn in over
	# his head, fists closing round the ball at `full`.
	"gather": [[0.0,REST],[0.13,[-0.35,0.3,0.5,0.15,-0.1,0.04]],[0.3,[2.45,1.0,0.25,-0.12,0.25,-0.01]],[0.7,[2.75,0.6,0.55,-0.18,0.3,0.0]],[1.0,[2.85,0.22,0.85,-0.2,0.3,0.005]]],
	# Wound back and up (anticipation), a two-handed overhead heave at
	# `release`, the follow-through down and forward, a heavy settle.
	"throw": [[0.0,[2.85,0.22,0.85,-0.2,0.3,0.005]],[0.22,[3.3,0.22,1.15,-0.4,0.38,0.02]],[0.35,[1.7,0.18,0.2,0.3,-0.05,0.04]],[0.5,[0.6,0.24,0.1,0.48,-0.18,0.07]],[0.7,[0.45,0.2,0.2,0.3,-0.08,0.045]]],
	# Both gauntlets thrust out to meet it at `contact`, the blow taken back
	# into the chest (lean back, sink), held there till `hold`.
	"catch": [[0.0,[1.2,0.45,0.3,0.05,0.05,0.02]],[0.1,[1.5,0.3,0.15,0.12,0.0,0.02]],[0.25,[1.05,0.22,1.25,-0.22,0.12,0.07]],[0.42,[1.0,0.2,1.35,-0.12,0.06,0.05]],[0.6,[1.0,0.2,1.3,-0.1,0.05,0.045]]],
	# Drawn in tighter and back (anticipation), a two-handed shove out at
	# `release`, the follow-through leaning after it, back to guard.
	"return": [[0.0,[1.0,0.2,1.3,-0.1,0.05,0.045]],[0.15,[0.75,0.18,1.7,-0.3,0.1,0.06]],[0.22,[1.55,0.15,0.05,0.35,-0.05,0.06]],[0.34,[1.45,0.2,0.05,0.42,-0.1,0.07]],[0.5,[0.35,0.35,0.9,0.1,0.0,0.03]]],
	# Struck: thrown back, arms flung wide, head up; arms wheel as he
	# goes back off balance; a heavy plant (deep sink) at `plant`, hunched;
	# he gathers himself back up to his guard by `recover`.
	# The blade gather: the right arm raised out beside him, forearm up so
	# the blade grows skyward off the gauntlet, the left hand out at you
	# (aiming), the chest turned a touch to his right.
	"gather:blade": [[0.0,REST],[0.15,[0.3,0.2,0.4,0.12,-0.05,0.04,0.0,0.6,-0.9,0.3,0.0]],[0.35,[1.2,0.05,0.25,-0.05,0.1,0.01,-0.25,1.1,0.25,1.2,0.0]],[1.0,[1.35,0.0,0.2,-0.08,0.08,0.02,-0.35,1.25,0.4,1.35,0.0]]],
	# Level: wound back low and wide behind his right (chest turned away,
	# crouched: it will go flat), held a beat, swept flat across at
	# `release` (arm straight at you), followed through far to his left,
	# settled.
	"slash:level": [[0.0,[1.35,0.0,0.2,-0.08,0.08,0.02,-0.35,1.25,0.4,1.35,0.0]],[0.3,[1.0,0.35,0.5,0.1,0.0,0.08,-0.85,2.3,-0.05,0.25,0.0]],[0.44,[1.0,0.4,0.55,0.12,0.0,0.085,-0.9,2.4,-0.08,0.25,0.0]],[0.52,[0.6,0.5,0.4,0.22,-0.05,0.08,-0.05,0.05,-0.12,0.0,0.0]],[0.64,[0.2,0.7,0.3,0.28,-0.05,0.09,0.75,-1.5,-0.18,0.05,0.0]],[1.0,[0.3,0.35,0.9,0.1,0.0,0.04,0.25,-0.5,-0.9,0.6,0.0]]],
	# High: raised over his right shoulder (rising up tall, leaning back),
	# held a beat, cut down across at `release`, followed through low to
	# his left (bent over it), settled.
	"slash:high": [[0.0,[1.35,0.0,0.2,-0.08,0.08,0.02,-0.35,1.25,0.4,1.35,0.0]],[0.3,[0.9,0.3,0.6,-0.22,0.2,-0.01,-0.55,0.9,1.25,0.35,0.0]],[0.44,[0.9,0.3,0.6,-0.25,0.22,-0.015,-0.6,0.95,1.35,0.35,0.0]],[0.52,[0.5,0.45,0.4,0.2,0.0,0.04,-0.1,0.2,0.05,0.0,0.0]],[0.64,[0.15,0.6,0.3,0.45,-0.15,0.09,0.55,-0.85,-1.0,0.05,0.0]],[1.0,[0.3,0.35,0.9,0.12,0.0,0.045,0.25,-0.5,-0.9,0.6,0.0]]],
	# Struck: thrown back for a blink (head up, arms flung forward), then
	# leaning hard into the push (turned to face it), arms out and low for
	# balance, sunk deep, held while he scrapes; straightened back to his
	# guard by `end`.
	"skid": [[0.0,REST],[0.07,[1.1,1.0,0.3,-0.4,0.35,0.03]],[0.25,[0.95,0.9,0.5,0.38,-0.12,0.13]],[0.9,[0.8,0.8,0.6,0.34,-0.06,0.12]],[1.25,[0.45,0.5,0.8,0.15,0.0,0.06]],[1.6,[0.3,0.35,0.95,0.06,0.0,0.025]]],
	# Over the drop: up on his toes, arms wide (they windmill on top of
	# this), leaning out (turned to the drop, rocking on top of this).
	"teeter": [[0.0,[0.8,0.8,0.6,0.34,-0.06,0.12]],[0.15,[1.5,1.2,0.3,0.3,0.25,-0.02]],[1.1,[1.5,1.2,0.3,0.25,0.2,0.0]]],
	# Falling: arms flung up and wide, head back.
	"fall": [[0.0,REST],[0.2,[2.6,1.0,0.2,-0.3,0.4,-0.02]],[0.8,[2.8,0.9,0.3,-0.25,0.35,-0.02]]],
	"stagger": [[0.0,REST],[0.08,[0.9,1.15,0.3,-0.5,0.45,0.0]],[0.4,[1.8,0.95,0.5,-0.38,0.3,0.04]],[0.75,[0.7,0.8,0.4,-0.2,0.0,0.08]],[0.9,[0.25,0.6,0.6,0.25,-0.2,0.11]],[1.3,[0.3,0.45,0.8,0.18,-0.08,0.07]],[1.8,[0.3,0.35,0.95,0.06,0.0,0.025]]],
}
## Steps in `stagger` are quick and short (s).
const STAGGER_STEP := 0.42
## A clip's first BLEND s ease from the pose he was in.
const BLEND := 0.14
## The gather's streaks: how many, how far out they start (shares of tall),
## how fast each runs in (a second), their width (share of tall).
const GATHER_STREAKS := 30
const GATHER_REACH := 1.15
const GATHER_RATE := 1.4
const GATHER_WIDTH := 0.085
## The blade: its streaks, its reach past the elbow at full (share of
## tall), its width (share of tall), how long it takes to grow (s).
const BLADE_STREAKS := 14
const BLADE_REACH := 0.78
const BLADE_WIDTH := 0.085
## The blade's tint: the runes' blue, so it reads apart from the gather's
## white streaks.
const BLADE_TINT := Color(0.55,0.9,1.0)
const BLADE_GROW := 0.8
## The walk, as shares of his height: the swing's share of a step (the rest
## is the plant's settle), the feet's spacing along his line, the swing
## foot's lift, the plant's sink, the hips' sway over the standing foot; a
## foot further than HOME_SLOP (m) from its spot steps in idle.
const SWING_SHARE := 0.62
const STRIDE := 0.3
const LIFT := 0.09
const SETTLE := 0.035
const SWAY := 0.035
const HOME_SLOP := 0.08
## His room's radius and his reach (the catch's range), shares of tall.
const ROOM := 0.24
const REACH := 0.75
## The rune lines' colour and light, dim and lit; how fast the light eases.
const RUNE := Color(0.45,0.85,1.0)
const RUNE_DIM := 0.25
const RUNE_LIT := 4.0
const RUNE_EASE := 6.0
## A crack: the flare (s), the flicker after it (s), how far the lines
## split apart (share of tall).
const CRACK_FLARE := 0.12
const CRACK_FLICKER := 0.9
const CRACK_SPLIT := 0.008
## The skid: how far ahead and behind of his middle the braced feet go
## (shares of tall, along the way he slides); the root speed (m/s) above
## which his heels throw dust, and the dust's gap (s).
const SKID_LEAD := 0.12
const SKID_TRAIL := 0.1
const SKID_DUST := 1.2
const SKID_DUST_GAP := 0.07
## The teeter's windmill (turns a second) and its rock (rad, a second).
const WINDMILL := 1.7
const ROCK := 0.18
## His stone's tones (the kit's, a touch lighter so he reads off the deck).
const STONE := Color("6a645d")
const STONE_DARK := Color("3d3934")

var tall := 1.9
var clip := "idle"
var clip_time := 0.0
var effects := {"rune_glow": false, "wind_gather": false, "wind_blade": false}
## The form the clip plays in ("" none; KEYS "clip:form").
var clip_form := ""
var glow := 0.0
## The feet (world, on the ground), 0 left, 1 right.
var feet: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
## The step under way: the foot swinging (-1 none), where from, its clock
## and length.
var _swing := -1
var _swing_from := Vector3.ZERO
var _swing_t := 0.0
var _swing_len := 1.0
var _last_foot := 1
var _settle_t := 9.0
var _root_last := Vector3.ZERO
var _root_v := Vector3.ZERO
var _sent: Dictionary = {}
## The pose now and the one the clip blends from: [floats (KEYS' first
## seven: arms, lean, head, sink, twist), the right forearm's bend, the
## right arm's turn (Quaternion)].
var _now_pose: Array = []
var _from_pose: Array = []
var _blade_fade := 0.0
var _blade_mm: MultiMeshInstance3D
var _gather_fade := 0.0
var _gather_dirs: Array[Vector3] = []
var _gather_phase: Array[float] = []
var _gather_mm: MultiMeshInstance3D
var _clock := 0.0

var _hips: Node3D
var _waist: Node3D
var _head: Node3D
var _thigh: Array[Node3D] = []
var _shin: Array[Node3D] = []
var _foot: Array[Node3D] = []
var _arm: Array[Node3D] = []
var _forearm: Array[Node3D] = []
var _sockets: Dictionary = {}
var _rune_mat: StandardMaterial3D
## Per rune (`chest`, `hand_l`, `hand_r`): its material, its lines and
## their rest, its crack line, and the time since it cracked (-1 whole).
var _rune_mats: Dictionary = {}
var _rune_bars: Dictionary = {}
var _crack_line: Dictionary = {}
var crack_t: Dictionary = {"chest": -1.0, "hand_l": -1.0, "hand_r": -1.0}
var _rng := RandomNumberGenerator.new()
## The way his last skid went (world, flat), the dust's clock.
var _skid_dir := Vector3.BACK
var _dust_t := 0.0
var _stone_mat: Material
var _hip_y := 0.0
var _thigh_len := 0.0
var _shin_len := 0.0
var _ankle := 0.0
var _hip_x := 0.0

func _init() -> void:
	name = "Body"

## Built `height` m tall; call once it is in the tree under his root.
func setup(height: float) -> void:
	tall = height
	_build()
	_root_last = global_position
	for i in range(2): feet[i] = _home(i,0.0)
	_now_pose = _unpack(REST)
	_from_pose = _now_pose.duplicate()
	_pose(0.0,0.0)

## His shape (m, s): room radius and height, eye height, reach, the feet's
## stride and a walking step's time, and the walking pace they make.
func shape() -> Dictionary:
	var step: float = CLIPS.walk.length
	var stride := STRIDE*tall
	return {"radius":ROOM*tall,"height":tall,"eye":_sockets.eye.position.y if _sockets.has("eye") else 0.9*tall,
		"reach":REACH*tall,"stride":stride,"step_time":step,"pace":stride/step}

# --- The API ------------------------------------------------------------------------

func play(name_: String, form := "") -> void:
	if not CLIPS.has(name_):
		push_warning("rune knight body: no clip %s" % name_)
		return
	if name_ == clip and CLIPS[name_].loop: return
	clip = name_
	clip_form = form
	clip_time = 0.0
	_sent = {}
	_from_pose = _now_pose.duplicate()

func socket(name_: String) -> Node3D:
	return _sockets.get(name_)

func set_effect(name_: String, on: bool, form := "") -> void:
	if name_ == "rune_crack":
		if not crack_t.has(form):
			push_warning("rune knight body: no rune %s" % form)
			return
		crack_t[form] = 0.0 if on else -1.0
		if on: _crack_burst(form)
		return
	effects[name_] = on

# --- The frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if delta <= 0.0: return
	var now := global_position
	_root_v = _root_v.lerp((now-_root_last)/delta,clampf(delta*8.0,0.0,1.0))
	_root_last = now
	clip_time += delta
	var c: Dictionary = CLIPS[clip]
	for beat: String in c.beats:
		var at: float = c.beats[beat]
		if at >= 0.0 and clip_time >= at and not _sent.has(beat):
			_sent[beat] = true
			beat_reached.emit(clip,beat)
	if not c.loop and clip_time >= float(c.length) and not _sent.has("_end"):
		_sent["_end"] = true
		beat_reached.emit(clip,"end")
	_clock += delta
	_gather_fade = move_toward(_gather_fade,1.0 if effects.wind_gather else 0.0,delta*(3.0 if effects.wind_gather else 4.0))
	glow = move_toward(glow,1.0 if effects.rune_glow else 0.0,delta*RUNE_EASE*0.5)
	_blade_fade = move_toward(_blade_fade,1.0 if effects.wind_blade else 0.0,delta/(BLADE_GROW if effects.wind_blade else 0.12))
	for r: String in crack_t:
		if crack_t[r] >= 0.0: crack_t[r] += delta
	var flat_v := Vector3(_root_v.x,0.0,_root_v.z)
	if flat_v.length() > 0.8 and clip == "skid": _skid_dir = flat_v.normalized()
	_step(delta)
	_skid_dust(delta,flat_v.length())
	_draw_gather()
	_draw_blade()

## The feet: a step under way goes on; else in `walk`/`turn` the trailing
## foot steps, in anything else a foot off its spot steps home.
func _step(delta: float) -> void:
	var moving := clip == "walk" or clip == "turn"
	if _swing < 0:
		var pick := -1
		if moving:
			pick = 1-_last_foot
		else:
			var worst := HOME_SLOP
			for i in range(2):
				var off := feet[i].distance_to(_home(i,0.0))
				if off > worst:
					worst = off
					pick = i
		if pick >= 0:
			_swing = pick
			_swing_from = feet[pick]
			_swing_t = 0.0
			_swing_len = float(CLIPS[clip].length) if moving else (STAGGER_STEP if clip == "stagger" else float(CLIPS.walk.length))
	if clip == "skid" or (clip == "teeter" and _swing < 0):
		# Braced, sliding with him: the lead foot (heel first) down the way
		# he goes, the other behind; no steps.
		_swing = -1
		var g := global_transform
		for i in range(2):
			var side := g.basis.x.normalized()*_hip_x*(1.0 if i == 1 else -1.0)
			var lead := _skid_dir*(SKID_LEAD if i == 0 else -SKID_TRAIL)*tall
			feet[i] = g.origin+side*1.3+lead
		_settle_t += delta
		_pose(0.0,0.0)
		return
	var lift := 0.0
	var s := 0.0
	if _root_v.y < -2.0:
		# Falling: the feet hang under him.
		_swing = -1
		for i in range(2): feet[i] = _home(i,0.0)+Vector3.DOWN*0.02*tall
	if _swing >= 0:
		_swing_t += delta
		var swing_time := _swing_len*SWING_SHARE
		s = clampf(_swing_t/swing_time,0.0,1.0)
		var e := s*s*(3.0-2.0*s)
		var lead := maxf(swing_time-_swing_t,0.0)+_swing_len*(1.0-SWING_SHARE*0.5)
		var to := _home(_swing,lead if moving else 0.0)
		var far := _swing_from.distance_to(to)
		feet[_swing] = _swing_from.lerp(to,e)+Vector3.UP*sin(s*PI)*LIFT*tall*clampf(far/(STRIDE*tall),0.3,1.0)
		lift = sin(s*PI)*0.012
		if s >= 1.0:
			feet[_swing] = to
			_last_foot = _swing
			_settle_t = 0.0
			_swing = -1
			if moving: beat_reached.emit(clip,"plant")
	_settle_t += delta
	# The plant's sink: down quick, back up slow.
	var p := _settle_t/(float(CLIPS.walk.length)*(1.0-SWING_SHARE))
	var sink := sin(minf(p*1.6,1.0)*PI*0.5)*(1.0-smoothstep(0.55,1.0,p)) if p < 1.0 else 0.0
	_pose(lift-sink*SETTLE*tall,s)

## Foot `i`'s spot under the root now, or `ahead` s on at the root's pace.
func _home(i: int, ahead: float) -> Vector3:
	var g := global_transform
	var side := g.basis.x.normalized()*_hip_x*(1.0 if i == 1 else -1.0)
	var flat := Vector3(_root_v.x,0.0,_root_v.z)
	return g.origin+side+flat*ahead

# --- The pose -----------------------------------------------------------------------

## The body `lift` m up, the legs reaching the feet; `swing` (0..1) the
## step's swing for the sway and the arms.
func _pose(lift: float, swing: float) -> void:
	var sway := 0.0
	if _swing >= 0:
		var stand := 1-_swing
		sway = (1.0 if stand == 1 else -1.0)*sin(swing*PI)*SWAY*tall
	var kp := _key_pose()
	var k: Array = kp[0]
	_hips.position = Vector3(sway,_hip_y+lift-float(k[5])*tall,0.0)
	_hips.rotation.z = -sway*0.6
	_waist.rotation = Vector3(-float(k[3]),float(k[6]),sway*0.9)
	var u := Vector3.ZERO
	if clip == "skid" or clip == "teeter":
		# The lean turned: into the push in a skid, out over the drop
		# (rocking back) teetering.
		var d := global_transform.basis.inverse()*_skid_dir
		d = Vector3(d.x,0.0,d.z).normalized()
		var amt := float(k[3])
		if clip == "teeter":
			u = d
			amt = amt*0.6+ROCK*sin(clip_time*TAU*1.3)
		else:
			u = -d
		_waist.rotation.x = amt*u.z
		_waist.rotation.z = -amt*u.x+sway*0.9
	for i in range(2): _reach(i)
	var arm := 0.0
	if _swing >= 0 and clip == "walk":
		arm = sin(swing*PI)*0.22*(1.0 if _swing == 0 else -1.0)
	_arm[0].rotation = Vector3(float(k[0])+arm,0.0,-float(k[1]))
	_forearm[0].rotation.x = float(k[2])+maxf(arm,0.0)*0.5
	var rq: Quaternion = kp[2]
	if arm != 0.0: rq = rq*Quaternion(Vector3.RIGHT,-arm)
	_arm[1].quaternion = rq
	_forearm[1].rotation.x = float(kp[1])+maxf(-arm,0.0)*0.5
	if clip == "teeter":
		# Windmilling: each arm round and round at his side, out of step.
		var w := clip_time*TAU*WINDMILL
		var spread := float(k[1])
		_arm[0].rotation = Vector3(float(k[0])+sin(w)*1.6,0.0,-spread+cos(w)*0.3)
		_forearm[0].rotation.x = 0.3
		_arm[1].quaternion = Basis.from_euler(Vector3(float(k[0])+sin(w+PI)*1.6,0.0,spread-cos(w+PI)*0.3),EULER_ORDER_ZXY).get_rotation_quaternion()
		_forearm[1].rotation.x = 0.3
	_head.rotation.x = -lift*2.5+float(k[4])
	var hl: Node3D = _sockets.hand_l
	var hr: Node3D = _sockets.hand_r
	(_sockets.hands_mid as Node3D).global_position = (hl.global_position+hr.global_position)*0.5
	_light_runes()

## The clip's key pose now (REST for a clip with none), eased from the
## pose he was in over its first BLEND s.
func _key_pose() -> Array:
	var want: Array = _unpack(REST)
	var label := clip+":"+clip_form
	if not KEYS.has(label): label = clip
	if KEYS.has(label):
		var keys: Array = KEYS[label]
		want = _unpack(keys[keys.size()-1][1])
		for j in range(keys.size()-1):
			var t0: float = keys[j][0]
			var t1: float = keys[j+1][0]
			if clip_time < t1:
				var u := clampf((clip_time-t0)/maxf(t1-t0,0.001),0.0,1.0)
				want = _blend(_unpack(keys[j][1]),_unpack(keys[j+1][1]),u*u*(3.0-2.0*u))
				break
	var b := clampf(clip_time/BLEND,0.0,1.0)
	_now_pose = _blend(_from_pose,want,b*b*(3.0-2.0*b))
	return _now_pose

## A key (KEYS' layout, six values or eleven) as [floats (seven: the six
## and twist), the right forearm's bend, the right arm's Quaternion]: six
## mirror the left arm onto the right.
static func _unpack(key: Array) -> Array:
	var f := []
	for i in range(6): f.append(float(key[i]))
	f.append(float(key[6]) if key.size() > 6 else 0.0)
	if key.size() >= 11:
		return [f,float(key[9]),_arm_quat(float(key[7]),float(key[8]),float(key[10]))]
	var euler := Basis.from_euler(Vector3(float(key[0]),0.0,float(key[1])),EULER_ORDER_ZXY)
	return [f,float(key[2]),euler.get_rotation_quaternion()]

## The right arm turned to point `swing` round from forward (+ to his
## right) and `raise` up from level, rolled `roll` about itself (its
## forearm bends up from there).
static func _arm_quat(swing: float, raise: float, roll: float) -> Quaternion:
	return (Basis(Vector3.UP,-swing)*Basis(Vector3.RIGHT,PI*0.5+raise)*Basis(Vector3.UP,roll)).get_rotation_quaternion()

static func _blend(a: Array, b: Array, u: float) -> Array:
	return [_mix(a[0],b[0],u),lerpf(float(a[1]),float(b[1]),u),(a[2] as Quaternion).slerp(b[2] as Quaternion,u)]

static func _mix(a: Array, b: Array, u: float) -> Array:
	var out := []
	for i in range(a.size()): out.append(lerpf(float(a[i]),float(b[i]),u))
	return out

## The gather's streaks: each runs in from round him to hands_mid and
## starts again, faded by the effect.
func _draw_gather() -> void:
	if _gather_mm == null: return
	var mm := _gather_mm.multimesh
	if _gather_fade <= 0.001:
		mm.visible_instance_count = 0
		return
	var cam := get_viewport().get_camera_3d()
	var into: Node3D = _sockets.hand_r if effects.wind_blade else _sockets.hands_mid
	var mid: Vector3 = into.global_position
	var eye := cam.global_position if cam != null else mid+Vector3(0,0,10)
	var reach := GATHER_REACH*tall
	for i in range(GATHER_STREAKS):
		var u := fposmod(_clock*GATHER_RATE+_gather_phase[i],1.0)
		var d: Vector3 = _gather_dirs[i]
		var head := mid+d*reach*pow(1.0-u,1.3)
		var long := reach*0.45*(1.0-u*0.6)
		var along := -d*long
		var way := along.normalized()
		var across := way.cross((eye-head).normalized())
		if across.length() < 0.01: across = Vector3.UP.cross(way)
		across = across.normalized()
		var w := GATHER_WIDTH*tall*(1.0-u*0.5)*(0.6 if effects.wind_blade else 1.0)
		mm.set_instance_transform(i,Transform3D(Basis(along,across*w,way.cross(across).normalized()),head-along*0.5))
		mm.set_instance_custom_data(i,Color(_gather_fade*sin(u*PI)*(0.6 if effects.wind_blade else 0.95),0,0,0))
		mm.set_instance_color(i,Color(0.86,0.95,1.0))
	mm.visible_instance_count = GATHER_STREAKS

## The blade of air along the right forearm: streaks from the elbow out
## past the fist, reaching farther as it grows, flickering, its edge
## brightest; faded by the effect.
func _draw_blade() -> void:
	if _blade_mm == null: return
	var mm := _blade_mm.multimesh
	if _blade_fade <= 0.001:
		mm.visible_instance_count = 0
		return
	var cam := get_viewport().get_camera_3d()
	var fore: Node3D = _forearm[1]
	var root := fore.global_position
	var way := (fore.global_basis*Vector3.DOWN).normalized()
	var edge := (fore.global_basis*Vector3.FORWARD).normalized()
	var eye := cam.global_position if cam != null else root+Vector3(0,0,10)
	var grow := 1.0-pow(1.0-_blade_fade,2.0)
	var reach := tall*lerpf(0.2,BLADE_REACH,grow)
	for i in range(BLADE_STREAKS):
		var lane := float(i%3)
		var seg := float(i/3)
		var segs := ceilf(float(BLADE_STREAKS)/3.0)
		var u0 := seg/segs
		var u1 := (seg+1.0)/segs
		var wob := sin(_clock*(23.0+lane*7.0)+float(i)*1.7)*0.012*tall
		var off := edge*(lane-1.0)*0.025*tall+edge*wob
		var a := root+way*(0.05*tall+reach*u0)+off
		var b := root+way*(0.05*tall+reach*u1*1.08)+off
		var along := b-a
		var w := BLADE_WIDTH*tall*(1.0-u0*0.55)*(1.25 if lane == 1.0 else 0.7)
		var dir := along.normalized()
		var across := dir.cross((eye-a).normalized())
		if across.length() < 0.01: across = Vector3.UP.cross(dir)
		across = across.normalized()
		mm.set_instance_transform(i,Transform3D(Basis(along,across*w,dir.cross(across).normalized()),(a+b)*0.5))
		mm.set_instance_custom_data(i,Color(_blade_fade*(1.0 if lane == 1.0 else 0.6),0,0,0))
		mm.set_instance_color(i,Color(0.92,0.98,1.0) if lane == 1.0 else BLADE_TINT)
	mm.visible_instance_count = BLADE_STREAKS
	(_sockets.blade as Node3D).position = Vector3(0.0,-(0.05*tall+reach*0.55),0.0)

## Leg `i` (0 left) reaching its foot: two-bone IK in his walking plane.
func _reach(i: int) -> void:
	var hip := _hips.position+Vector3(_hip_x*(1.0 if i == 1 else -1.0),0.0,0.0)
	var foot := global_transform.affine_inverse()*feet[i]+Vector3.UP*_ankle
	var d := foot-hip
	var fwd := -d.z
	var down := -d.y
	var a := _thigh_len
	var b := _shin_len
	var reach := clampf(sqrt(fwd*fwd+down*down),0.05,a+b-0.002)
	var base := atan2(fwd,down)
	var alpha := acos(clampf((a*a+reach*reach-b*b)/(2.0*a*reach),-1.0,1.0))
	var gamma := acos(clampf((a*a+b*b-reach*reach)/(2.0*a*b),-1.0,1.0))
	_thigh[i].position = hip-_hips.position
	_thigh[i].rotation = Vector3(base+alpha,0.0,0.0)
	_shin[i].rotation = Vector3(-(PI-gamma),0.0,0.0)
	_foot[i].rotation = Vector3(-(base+alpha)+(PI-gamma),0.0,0.0)

# --- The build ----------------------------------------------------------------------

func _build() -> void:
	var h := tall
	_stone_mat = RuinKit.materials().stone
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.12,0.16,0.18)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = RUNE
	_rune_mat.emission_energy_multiplier = RUNE_DIM
	_thigh_len = 0.22*h
	_shin_len = 0.21*h
	_ankle = 0.045*h
	_hip_x = 0.085*h
	_hip_y = _ankle+(_thigh_len+_shin_len)*0.97
	_hips = _pivot(self,"Hips",Vector3(0.0,_hip_y,0.0))
	_box(_hips,"Pelvis",Vector3.ZERO,Vector3(0.3,0.09,0.17)*h,STONE_DARK)
	_box(_hips,"Tasset",Vector3(0.0,-0.06*h,-0.02*h),Vector3(0.32,0.08,0.2)*h,STONE,Vector3(0.12,0,0))
	for i in range(2):
		var sx := 1.0 if i == 1 else -1.0
		var thigh := _pivot(_hips,"Thigh%d" % i,Vector3(_hip_x*sx,0.0,0.0))
		_box(thigh,"ThighMesh",Vector3(0.0,-_thigh_len*0.5,0.0),Vector3(0.12*h,_thigh_len*1.02,0.13*h),STONE)
		var shin := _pivot(thigh,"Shin",Vector3(0.0,-_thigh_len,0.0))
		_box(shin,"Knee",Vector3(0.0,0.0,-0.02*h),Vector3(0.11,0.07,0.09)*h,STONE_DARK)
		_box(shin,"ShinMesh",Vector3(0.0,-_shin_len*0.5,0.0),Vector3(0.115*h,_shin_len,0.125*h),STONE)
		var foot := _pivot(shin,"Foot",Vector3(0.0,-_shin_len,0.0))
		_box(foot,"Sabaton",Vector3(0.0,-_ankle*0.5,-0.035*h),Vector3(0.13*h,_ankle,0.22*h),STONE_DARK)
		_thigh.append(thigh)
		_shin.append(shin)
		_foot.append(foot)
	# Torso: a narrow belly under a broad chest.
	_waist = _pivot(_hips,"Waist",Vector3(0.0,0.03*h,0.0))
	_box(_waist,"Belly",Vector3(0.0,0.07*h,0.0),Vector3(0.24,0.12,0.16)*h,STONE_DARK)
	_box(_waist,"Chest",Vector3(0.0,0.21*h,-0.005*h),Vector3(0.38,0.18,0.22)*h,STONE,Vector3(-0.05,0,0))
	_box(_waist,"Gorget",Vector3(0.0,0.31*h,0.0),Vector3(0.16,0.04,0.14)*h,STONE_DARK)
	var front := -0.117*h
	_rune(_waist,Vector3(0.0,0.2*h,front),Vector3(0.012,0.12,0.01)*h,0.0,"chest")
	_rune(_waist,Vector3(-0.035*h,0.255*h,front),Vector3(0.012,0.07,0.01)*h,0.75,"chest")
	_rune(_waist,Vector3(0.035*h,0.255*h,front),Vector3(0.012,0.07,0.01)*h,-0.75,"chest")
	_rune(_waist,Vector3(0.0,0.14*h,front),Vector3(0.08,0.012,0.01)*h,0.0,"chest")
	_crack(_waist,Vector3(0.004*h,0.21*h,front-0.004*h),Vector3(0.012,0.17,0.008)*h,0.45,"chest")
	_sockets.chest_rune = _pivot(_waist,"chest_rune",Vector3(0.0,0.2*h,front))
	_sockets.hands_mid = _pivot(_waist,"hands_mid",Vector3(0.0,0.2*h,-0.35*h))
	# Head.
	_head = _pivot(_waist,"Head",Vector3(0.0,0.33*h,0.0))
	_box(_head,"Helm",Vector3(0.0,0.08*h,0.005*h),Vector3(0.14,0.15,0.16)*h,STONE)
	_box(_head,"Brow",Vector3(0.0,0.115*h,-0.075*h),Vector3(0.15,0.035,0.03)*h,STONE_DARK)
	_box(_head,"Visor",Vector3(0.0,0.085*h,-0.076*h),Vector3(0.11,0.016,0.01)*h,Color(0.05,0.05,0.05))
	_box(_head,"Crest",Vector3(0.0,0.165*h,0.015*h),Vector3(0.022,0.03,0.15)*h,STONE_DARK)
	_sockets.eye = _pivot(_head,"eye",Vector3(0.0,0.085*h,-0.08*h))
	# Arms: pauldron, upper arm, forearm, gauntlet.
	for i in range(2):
		var sx := 1.0 if i == 1 else -1.0
		var shoulder := Vector3(0.23*h*sx,0.27*h,0.0)
		_box(_waist,"Pauldron%d" % i,shoulder+Vector3(0.02*h*sx,0.035*h,0.0),Vector3(0.13,0.06,0.19)*h,STONE_DARK,Vector3(0,0,-0.45*sx))
		_box(_waist,"PauldronLame%d" % i,shoulder+Vector3(0.065*h*sx,-0.015*h,0.0),Vector3(0.1,0.05,0.17)*h,STONE,Vector3(0,0,-0.9*sx))
		var arm := _pivot(_waist,"Arm%d" % i,shoulder)
		arm.rotation_order = EULER_ORDER_ZXY
		_box(arm,"UpperArm",Vector3(0.0,-0.08*h,0.0),Vector3(0.09,0.17,0.1)*h,STONE)
		var fore := _pivot(arm,"Forearm",Vector3(0.0,-0.16*h,0.0))
		_box(fore,"ForearmMesh",Vector3(0.0,-0.065*h,0.0),Vector3(0.095,0.14,0.1)*h,STONE)
		var hand := _pivot(fore,"Gauntlet",Vector3(0.0,-0.15*h,0.0))
		_box(hand,"Fist",Vector3(0.0,-0.035*h,0.0),Vector3(0.13,0.12,0.13)*h,STONE_DARK)
		_box(hand,"Cuff",Vector3(0.0,0.035*h,0.0),Vector3(0.14,0.04,0.14)*h,STONE)
		var rn := "hand_r" if i == 1 else "hand_l"
		_rune(hand,Vector3(0.0,-0.03*h,-0.066*h),Vector3(0.012,0.08,0.01)*h,0.0,rn)
		_rune(hand,Vector3(0.016*h,-0.005*h,-0.066*h),Vector3(0.012,0.04,0.01)*h,-0.8,rn)
		_rune(hand,Vector3(-0.016*h,-0.005*h,-0.066*h),Vector3(0.012,0.04,0.01)*h,0.8,rn)
		_crack(hand,Vector3(0.003*h,-0.02*h,-0.07*h),Vector3(0.01,0.1,0.008)*h,-0.5,rn)
		_sockets["hand_r" if i == 1 else "hand_l"] = _pivot(hand,"hand_r" if i == 1 else "hand_l",Vector3(0.0,-0.035*h,0.0))
		if i == 1: _sockets.blade = _pivot(fore,"blade",Vector3(0.0,-0.4*h,0.0))
		arm.rotation.z = 0.12*sx
		_arm.append(arm)
		_forearm.append(fore)
	_build_gather()
	_build_blade()

## The blade's streak batch (world space).
func _build_blade() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = DragonCyclone._streak_mesh()
	mm.instance_count = BLADE_STREAKS
	mm.visible_instance_count = 0
	_blade_mm = MultiMeshInstance3D.new()
	_blade_mm.name = "WindBlade"
	_blade_mm.multimesh = mm
	_blade_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade_mm.extra_cull_margin = 50.0
	_blade_mm.top_level = true
	add_child(_blade_mm)
	_blade_mm.global_transform = Transform3D.IDENTITY

## The gather's streak batch (world space) and each streak's way in.
func _build_gather() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(GATHER_STREAKS):
		# Round him, more from the sides and above than below.
		var a := float(i)/float(GATHER_STREAKS)*TAU+rng.randf_range(-0.2,0.2)
		_gather_dirs.append(Vector3(cos(a),rng.randf_range(-0.35,0.9),sin(a)).normalized())
		_gather_phase.append(rng.randf())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = DragonCyclone._streak_mesh()
	mm.instance_count = GATHER_STREAKS
	mm.visible_instance_count = 0
	_gather_mm = MultiMeshInstance3D.new()
	_gather_mm.name = "WindGather"
	_gather_mm.multimesh = mm
	_gather_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gather_mm.extra_cull_margin = 50.0
	_gather_mm.top_level = true
	add_child(_gather_mm)
	_gather_mm.global_transform = Transform3D.IDENTITY

func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.position = at
	parent.add_child(n)
	return n

## A stone box of `size` about `at` under `parent`, turned by `rot` (rad),
## coloured by its vertices (the kit's stone shader reads them).
func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, tone: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var colors := PackedColorArray()
	colors.resize(n)
	colors.fill(Color(tone.r,tone.g,tone.b,1.0))
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var m := MeshInstance3D.new()
	m.name = label
	m.mesh = mesh
	m.material_override = _stone_mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m

## A rune line of rune `group`: a thin lit bar of `size` at `at`, turned
## `roll` in its face.
func _rune(parent: Node3D, at: Vector3, size: Vector3, roll: float, group: String) -> void:
	var box := BoxMesh.new()
	box.size = size
	var m := MeshInstance3D.new()
	m.name = "Rune"
	m.mesh = box
	if not _rune_mats.has(group):
		_rune_mats[group] = _rune_mat.duplicate()
		_rune_bars[group] = []
	m.material_override = _rune_mats[group]
	(_rune_bars[group] as Array).append([m,at,roll])
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	m.rotation.z = roll
	parent.add_child(m)

## Rune `group`'s crack: a dark line across its lines, hidden till it cracks.
func _crack(parent: Node3D, at: Vector3, size: Vector3, roll: float, group: String) -> void:
	var line := _box(parent,"Crack",at,size,Color(0.03,0.03,0.03),Vector3(0.0,0.0,roll))
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.visible = false
	_crack_line[group] = line

## Each rune's light: lit by `rune_glow` while whole (flickering while he
## teeters); a cracked one flares, splits, flickers and goes dark.
func _light_runes() -> void:
	var lit := lerpf(RUNE_DIM,RUNE_LIT,glow)
	if clip == "teeter": lit *= 1.0 if sin(clip_time*47.0)+sin(clip_time*29.0) > -0.3 else 0.35
	for group: String in _rune_mats:
		var mat: StandardMaterial3D = _rune_mats[group]
		var t: float = crack_t[group]
		if t < 0.0:
			mat.emission_energy_multiplier = lit
			continue
		var split := smoothstep(0.0,CRACK_FLARE,t)
		var base: Vector3 = Vector3.ZERO
		var bars: Array = _rune_bars[group]
		for b: Array in bars: base += b[1] as Vector3
		base /= float(bars.size())
		for j in range(bars.size()):
			var b: Array = bars[j]
			var off := (b[1] as Vector3)-base
			off.z = 0.0
			var out := off.normalized() if off.length() > 0.0001 else Vector3(1.0 if j%2 == 0 else -1.0,0.0,0.0)
			(b[0] as Node3D).position = (b[1] as Vector3)+out*CRACK_SPLIT*tall*split
			(b[0] as Node3D).rotation.z = float(b[2])+(0.18 if j%2 == 0 else -0.18)*split
		(_crack_line[group] as Node3D).visible = true
		if t < CRACK_FLARE:
			mat.emission_energy_multiplier = RUNE_LIT*1.8
		elif t < CRACK_FLARE+CRACK_FLICKER:
			var fade := 1.0-(t-CRACK_FLARE)/CRACK_FLICKER
			mat.emission_energy_multiplier = (RUNE_LIT*fade if _rng.randf() < 0.45 else 0.04)
		else:
			mat.emission_energy_multiplier = 0.0
			mat.albedo_color = Color(0.06,0.06,0.065)

## The crack's dust off the rune.
func _crack_burst(group: String) -> void:
	var at: Node3D = _sockets.chest_rune if group == "chest" else _sockets[group]
	var host := get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else self
	BodyDust.puff(host,at.global_position,0.12*tall,-global_transform.basis.z)

## Dust off his heels while he skids fast.
func _skid_dust(delta: float, speed: float) -> void:
	if clip != "skid" or speed < SKID_DUST:
		_dust_t = 0.0
		return
	_dust_t -= delta
	if _dust_t > 0.0: return
	_dust_t = SKID_DUST_GAP
	var host := get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else self
	for i in range(2):
		BodyDust.puff(host,feet[i]+Vector3.UP*0.12*tall,clampf(speed*0.07,0.2,0.5)*tall*0.6,-_skid_dir*0.6+Vector3.UP*1.3)
	if not _sent.has("_dug"):
		# The heels dig in: a cloud thrown up off them.
		_sent["_dug"] = true
		BodyDust.plume(host,(feet[0]+feet[1])*0.5+Vector3.UP*0.12*tall,0.3*tall)
