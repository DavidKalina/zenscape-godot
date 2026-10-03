extends Node
## The shaping tools' and the HUD's sound (docs/scenic/sound.md, "Tool sound").
## Built by studies/fidelity_life.gd next to GenesisAudio when the clay is on.
##
## Two kinds of sound:
## - **Cues**: one-shots asked for by name. The tools call `LandClay.sound`
##   (its `sounded` signal lands here) at their moments: a poke, a pat, a
##   hammer's crack, a chisel's step. The HUD calls the static `cue` for its
##   touches: a tool picked, the tray reached for, a slot hovered.
## - **Voices**: loops whose gain follows the press while it lasts: the thumb's
##   groove and rub, the paddle's sweep and the chisel's scrape by the
##   pointer's speed; a hold's stretch and low rumble by how fast the lift
##   moves; the Wire's cut and grind by how fast its head runs.
## - **Lurches**: the land voice's own cues, fired here rather than by a tool
##   (`_tremble`). Under a rising pull the rumble is a bed, and over it the
##   land gives in lurches (`lurch`: a thud dropping into a darkening rumble,
##   crumbling after), more often and louder the faster it rises, and none
##   while the hold is still. The Wire's cut grinds instead (`grind`: lighter,
##   grittier, no sub). After audio.js's formation rumble in the Electron
##   ZenScape, which fired its lurches with the camera's kicks.
##
## Each cue has a few recorded takes (assets/audio/foley/<clip>-<n>.wav, CC0,
## credited in assets/audio/ATTRIBUTION.md, cut by tools/foley/make_foley.py).
## A take is never played twice running, and each play is nudged in pitch and
## level so repeats don't sound mechanical. A bigger moment (`strength`) is a
## little louder and lower. A cue with no takes on disk is silent, never an
## error.

const GenesisAudio = preload("res://scripts/genesis_audio.gd")
const DIR := "res://assets/audio/foley/"
const MAX_TAKES := 8

## The node playing now, for the static `cue`.
static var current: Node

## Cue → its clip, peak gain, shortest gap between plays (s), and whether it
## is the HUD's (flat, no place) or the land's (placed at the ground).
const CUES := {
	&"poke": {"clip":"poke","gain":0.32,"gap":0.06},
	&"notch": {"clip":"crumble","gain":0.16,"gap":0.25},
	&"pat": {"clip":"pat","gain":0.34,"gap":0.08},
	&"chisel_step": {"clip":"chisel-tick","gain":0.16,"gap":0.09},
	&"chisel_knock": {"clip":"chisel-knock","gain":0.4,"gap":0.08},
	&"mesa_break": {"clip":"mesa-break","gain":0.36,"gap":0.4},
	&"crack": {"clip":"hammer-rock","gain":0.42,"gap":0.06},
	&"knock": {"clip":"hammer-soil","gain":0.36,"gap":0.06},
	&"scree": {"clip":"scree","gain":0.26,"gap":0.2},
	&"crumble": {"clip":"crumble","gain":0.24,"gap":0.3},
	&"rock_settle": {"clip":"pebbles","gain":0.2,"gap":0.3},
	&"trees": {"clip":"trees","gain":0.22,"gap":0.5},
	&"wire_start": {"clip":"wire-start","gain":0.18,"gap":0.2},
	&"water_gather": {"clip":"water-gather","gain":0.22,"gap":0.15},
	&"water_toss": {"clip":"water-toss","gain":0.12,"gap":0.15},
	&"water_pop": {"clip":"water-pop","gain":0.3,"gap":0.1},
	&"water_splash": {"clip":"water-splash","gain":0.4,"gap":0.1},
	&"sow": {"clip":"sow","gain":0.2,"gap":0.12},
	&"stone_drop": {"clip":"stone-drop","gain":0.3,"gap":0.06},
	&"plant": {"clip":"plant","gain":0.18,"gap":0.08},
	&"lurch": {"clip":"land-lurch","gain":0.42,"gap":0.22,"jitter":0.1},
	&"grind": {"clip":"land-grind","gain":0.3,"gap":0.12,"jitter":0.08},
	&"ui_reach": {"clip":"ui-cloth","gain":0.07,"gap":0.6,"ui":true},
	&"ui_hover": {"clip":"ui-tick","gain":0.05,"gap":0.05,"ui":true},
	&"ui_pick": {"clip":"ui-pick","gain":0.2,"gap":0.08,"ui":true},
	&"ui_take": {"clip":"ui-take","gain":0.18,"gap":0.08,"ui":true},
	&"ui_put": {"clip":"ui-put","gain":0.14,"gap":0.08,"ui":true},
	&"ui_size": {"clip":"ui-tick","gain":0.12,"gap":0.05,"ui":true},
	&"ui_refuse": {"clip":"ui-refuse","gain":0.12,"gap":0.2,"ui":true},
	&"ui_undo": {"clip":"ui-undo","gain":0.14,"gap":0.08,"ui":true},
	&"ui_page": {"clip":"ui-page","gain":0.16,"gap":0.15,"ui":true},
	&"ui_shutter": {"clip":"ui-shutter","gain":0.2,"gap":0.3,"ui":true},
}
## Every play: pitch within ±PITCH_JITTER (or the cue's own `jitter`) and level
## within ±GAIN_JITTER dB. A
## full-strength moment plays STRONG_PITCH lower than a faint one, and a faint
## one at FAINT_GAIN of the peak.
const PITCH_JITTER := 0.05
const GAIN_JITTER := 1.5
const STRONG_PITCH := 0.1
const FAINT_GAIN := 0.5
const LAND_POOL := 8
const UI_POOL := 3

enum {GROOVE, RUB, SWEEP, SCRAPE, STRETCH, RUMBLE, CUT, GRIND, VOICES}
## Each voice's loop and peak gain.
const VOICE_CLIPS := ["groove-loop","rub-loop","sweep-loop","scrape-loop","stretch-loop","","cut-loop","land-grind-loop"]
const VOICE_GAIN := [0.22,0.16,0.2,0.2,0.2,0.38,0.22,0.24]
## Voices other things drive by name (`voice`), each a loop and its peak gain:
## the water ball's swirl while it is held.
## The watering can's stream borrows the swirl's loop until it has its own.
const OTHER_VOICES := {&"water_swirl": {"clip":"water-swirl-loop","gain":0.2},&"water_pour": {"clip":"water-swirl-loop","gain":0.16}}
## The held rumble's bed (tools/generate_nature_audio.py --land): audio.js's
## strain, a body under 180 Hz with a 430 Hz grind on it that small speakers
## can play. Genesis's own rumble (genesis-rumble.wav) is nearly all under
## 150 Hz and steady, so on a laptop it was close to silent.
const RUMBLE_CLIP := DIR+"land-bed-loop.wav"
## A drag's voices come in from SPEED.x px/s and are full at SPEED.y; a hold's
## from 0 to LIFT_RATE m/s of lift; the Wire's cut at CUT_RATE of its path a
## second.
const SPEED := Vector2(40.0,900.0)
const LIFT_RATE := 6.0
const CUT_RATE := 0.8
## Lurches come in at LURCH_RISE.x m/s of rise and are at their most at
## LURCH_RISE.y, from LURCH_PACE.x to LURCH_PACE.y a second; at most
## LURCH_STACK sound at once. A pull's first comes FIRST_LURCH of a beat after
## the land starts moving. The Wire's grinds run GRIND_PACE a second by its
## cut's pace (or a slice's), at most GRIND_STACK at once.
const LURCH_RISE := Vector2(0.4,6.0)
const LURCH_PACE := Vector2(1.4,4.5)
const LURCH_STACK := 4
const FIRST_LURCH := 0.25
const GRIND_PACE := Vector2(2.0,6.0)
const GRIND_STACK := 3
## Gains ease in at ATTACK and out at RELEASE (1/s), as GenesisAudio's do.
const ATTACK := 9.0
const RELEASE := 3.5

var clay: Node
## Plays and drops per cue, for probes: {cue: [played, dropped]}.
var counts := {}

## `--sound-log`: print every cue as it plays, is held back or is dropped.
var log_cues := "--sound-log" in OS.get_cmdline_user_args()
var _rng := RandomNumberGenerator.new()
var _takes := {}
var _last_take := {}
var _last_at := {}
var _land: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _gain := PackedFloat32Array()
var _target := PackedFloat32Array()
var _lift := 0.0
## Other voices: name -> {player, gain, target}; a target not set again this
## frame falls back to 0.
var _other := {}
var _cut := 0.0
## Each trembling cue's beat, 0..1: it fires at 1 (`_tremble`).
var _beat := {&"lurch": 1.0-FIRST_LURCH,&"grind": 1.0-FIRST_LURCH}

func setup(land_clay: Node) -> void:
	name = "ClaySound"
	clay = land_clay
	current = self
	_rng.randomize()
	GenesisAudio.ensure_buses()
	for i in range(LAND_POOL): _land.append(_player3d(null))
	for i in range(UI_POOL):
		var player := AudioStreamPlayer.new()
		player.bus = GenesisAudio.BUS
		add_child(player)
		_ui.append(player)
	_gain.resize(VOICES)
	_target.resize(VOICES)
	for v in range(VOICES):
		var path := RUMBLE_CLIP if v == RUMBLE else DIR+str(VOICE_CLIPS[v])+".wav"
		var player := _player3d(_loop(path) if ResourceLoader.exists(path) else null)
		player.volume_db = -80.0
		if player.stream != null:
			player.play(_rng.randf()*player.stream.get_length())
			player.stream_paused = true
		_voices.append(player)
	clay.sounded.connect(_on_sounded)

func _exit_tree() -> void:
	if current == self: current = null

## The HUD's way in: play `name` if a ClaySound is running.
static func cue(cue_name: StringName, strength := 1.0) -> void:
	if current != null and is_instance_valid(current): current.play(cue_name,Vector3.ZERO,strength)

## A land cue from anything in the world, at `at` (global).
static func cue_at(cue_name: StringName, at: Vector3, strength := 1.0) -> void:
	if current != null and is_instance_valid(current): current.play(cue_name,at,strength)

## Hold an OTHER_VOICES loop at `gain` 0..1 this frame, at `at` (global).
## Call it every frame the voice should sound; it eases out once the calls stop.
static func voice(voice_name: StringName, gain: float, at: Vector3) -> void:
	if current != null and is_instance_valid(current): current._hold_other(voice_name,gain,at)

func _hold_other(voice_name: StringName, gain: float, at: Vector3) -> void:
	if not _other.has(voice_name):
		var spec: Dictionary = OTHER_VOICES.get(voice_name,{})
		var path := DIR+str(spec.get("clip",""))+".wav"
		if spec.is_empty() or not ResourceLoader.exists(path):
			_other[voice_name] = {}
			return
		var player := _player3d(_loop(path))
		player.volume_db = -80.0
		player.play(_rng.randf()*player.stream.get_length())
		_other[voice_name] = {"player":player,"gain":0.0,"target":0.0,"peak":float(spec.gain)}
	var entry: Dictionary = _other[voice_name]
	if entry.is_empty(): return
	entry.target = clampf(gain,0.0,1.0)
	(entry.player as AudioStreamPlayer3D).global_position = at

func _on_sounded(cue_name: StringName, at: Vector3, strength: float) -> void:
	play(cue_name,clay.editor.terrain.to_global(at),strength)

## One take of `cue_name`, at `at` for the land's cues; false if it has no
## takes, is inside its gap, or every player is busy.
func play(cue_name: StringName, at: Vector3, strength := 1.0) -> bool:
	var spec: Dictionary = CUES.get(cue_name,{})
	var takes := _takes_for(str(spec.clip)) if not spec.is_empty() else []
	if takes.is_empty():
		if log_cues: print("[sound] %s: no takes" % cue_name)
		return false
	var now := Time.get_ticks_msec()*0.001
	if now-float(_last_at.get(cue_name,-INF)) < float(spec.gap):
		if log_cues: print("[sound] %s: inside its gap" % cue_name)
		return false
	var ui := bool(spec.get("ui",false))
	var player = null
	for candidate in (_ui if ui else _land):
		if not candidate.playing:
			player = candidate
			break
	var tally: Array = counts.get(cue_name,[0,0])
	counts[cue_name] = tally
	if player == null:
		tally[1] += 1
		if log_cues: print("[sound] %s: dropped, every player busy" % cue_name)
		return false
	var pick := _rng.randi_range(0,takes.size()-1)
	if takes.size() > 1 and pick == int(_last_take.get(cue_name,-1)): pick = (pick+1)%takes.size()
	_last_take[cue_name] = pick
	_last_at[cue_name] = now
	strength = clampf(strength,0.0,1.0)
	player.stream = takes[pick]
	player.volume_db = linear_to_db(float(spec.gain)*lerpf(FAINT_GAIN,1.0,strength))+_rng.randf_range(-GAIN_JITTER,GAIN_JITTER)
	var jitter := float(spec.get("jitter",PITCH_JITTER))
	player.pitch_scale = (1.0+STRONG_PITCH*(0.5-strength))*(1.0+_rng.randf_range(-jitter,jitter))
	if not ui: (player as AudioStreamPlayer3D).global_position = at
	player.play()
	tally[0] += 1
	if log_cues: print("[sound] %s take %d at %.1f dB" % [cue_name,pick+1,player.volume_db])
	return true

func _takes_for(clip: String) -> Array:
	if not _takes.has(clip):
		var found := []
		for n in range(1,MAX_TAKES+1):
			var path := DIR+"%s-%d.wav" % [clip,n]
			if not ResourceLoader.exists(path): break
			found.append(load(path))
		_takes[clip] = found
	return _takes[clip]

# --- Voices ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if clay == null or delta <= 0.0: return
	for entry: Dictionary in _other.values():
		if entry.is_empty(): continue
		var player: AudioStreamPlayer3D = entry.player
		var goal: float = entry.target
		entry.gain = move_toward(float(entry.gain),goal,delta*(ATTACK if goal > float(entry.gain) else RELEASE))
		entry.target = 0.0
		var on := float(entry.gain) > 0.002
		player.volume_db = linear_to_db(float(entry.gain)*float(entry.peak)) if on else -80.0
		if on != not player.stream_paused: player.stream_paused = not on
	_target.fill(0.0)
	var state: int = clay.state
	var id: String = clay.tool_id
	var tool: Object = clay.tool
	var at := Vector3.ZERO
	# How hard the land is giving this frame, 0..1: a rising pull's lurches,
	# the Wire's grinding, and how big a lurch is (`heft`).
	var lurch := 0.0
	var heft := 0.0
	var grit := 0.0
	if state == clay.State.DRAG:
		var pace := smoothstep(SPEED.x,SPEED.y,float(clay.speed))
		match id:
			"hand":
				if clay.verb == "palm": _target[SWEEP] = pace
				else:
					var rub := clampf(float(clay.rub),0.0,1.0)
					_target[GROOVE] = pace*(1.0-rub)
					_target[RUB] = pace*rub
			"paddle": _target[SWEEP] = pace
			"chisel": _target[SCRAPE] = pace
		if clay.last_plate != null: at = clay.ground_at(clay.last_plate)
	elif state == clay.State.PAINT:
		# The Sculpt works while held: the land stretching as it rises or
		# sinks, a rub as it smooths. Its hills knock in as cues of their own.
		# The Hills and the Bowl only sound while the pointer moves; the
		# Brush whispers at rest and rubs as it travels.
		var pace := smoothstep(SPEED.x,SPEED.y,float(clay.speed))
		match str(clay.verb):
			"raise", "lower": _target[STRETCH] = 0.6
			"smooth", "flatten": _target[RUB] = 0.6
			"hills", "fine_hills": _target[STRETCH] = 0.3+0.5*pace
			"bowl", "fine_bowl": _target[SWEEP] = 0.3+0.5*pace
			"grass", "rock", "earth", "wipe": _target[RUB] = 0.15+0.35*pace
		if str(clay.verb) in ["raise","hills"]: _target[RUMBLE] = 0.3
		if clay.last_plate != null: at = clay.ground_at(clay.last_plate)
	elif state == clay.State.HOLD and tool != null:
		var lift := float(tool.lift)
		var moved := (lift-_lift)/delta
		var rate := smoothstep(0.0,LIFT_RATE,absf(moved))
		_lift = lift
		if id == "chisel": _target[SCRAPE] = rate*0.7
		elif id != "hammer": _target[STRETCH] = rate
		# The Wire's slice grinds through. The land groans as it rises, not as
		# it sinks, and gives in lurches the faster it rises.
		if id == "wire":
			_target[GRIND] = rate*0.8
			grit = rate
		elif lift > 0.0 and id != "hammer":
			heft = smoothstep(0.0,3.0,lift)
			_target[RUMBLE] = rate*heft
			lurch = smoothstep(LURCH_RISE.x,LURCH_RISE.y,moved)
		at = clay.ground_at(clay.center)
	else:
		_lift = 0.0
	if id == "wire" and tool != null and tool.busy():
		var share := float(tool.cut_share())
		var pace := smoothstep(0.0,CUT_RATE,(share-_cut)/delta)
		_target[CUT] = pace
		_target[GRIND] = maxf(_target[GRIND],pace*0.8)
		grit = maxf(grit,pace)
		_cut = share
		at = clay.ground_at(clay.center)
	else:
		_cut = 0.0
	var place: Vector3 = clay.editor.terrain.to_global(at) if at != Vector3.ZERO else Vector3.INF
	var here: Vector3 = place if place != Vector3.INF else clay.editor.terrain.global_position
	_tremble(&"lurch",lurch,LURCH_PACE,LURCH_STACK,lerpf(0.35,1.0,lurch)*lerpf(0.6,1.0,heft),delta,here)
	_tremble(&"grind",grit,GRIND_PACE,GRIND_STACK,lerpf(0.4,1.0,grit),delta,here)
	for v in range(VOICES):
		var player := _voices[v]
		if player.stream == null: continue
		var goal := _target[v]
		_gain[v] = move_toward(_gain[v],goal,delta*(ATTACK if goal > _gain[v] else RELEASE))
		var on := _gain[v] > 0.002
		if on and player.stream_paused: player.stream_paused = false
		elif not on and not player.stream_paused:
			# Silent too, in case the pause has not taken (it doesn't, the frame
			# a player starts).
			player.volume_db = -80.0
			player.stream_paused = true
		if not on: continue
		player.volume_db = linear_to_db(_gain[v]*float(VOICE_GAIN[v]))
		if v == RUMBLE: player.pitch_scale = lerpf(0.82,1.0,_gain[v])
		else: player.pitch_scale = lerpf(0.94,1.06,_gain[v])
		if place != Vector3.INF: player.global_position = place

## Fire `cue_name` on its beat while `drive` (0..1) holds: the beat runs from
## pace.x to pace.y a second with the drive, and each give sets it back a
## little at random, so the gives don't tick evenly. At most `stack` of its
## takes sound at once. With no drive the beat waits FIRST_LURCH short of a
## give, so land that starts moving again gives almost at once.
func _tremble(cue_name: StringName, drive: float, pace: Vector2, stack: int, strength: float, delta: float, at: Vector3) -> void:
	if drive <= 0.0:
		_beat[cue_name] = 1.0-FIRST_LURCH
		return
	_beat[cue_name] = float(_beat[cue_name])+delta*lerpf(pace.x,pace.y,drive)
	if float(_beat[cue_name]) < 1.0: return
	_beat[cue_name] = _rng.randf_range(-0.3,0.25)
	var takes := _takes_for(str(CUES[cue_name].clip))
	var sounding := 0
	for player in _land:
		if player.playing and takes.has(player.stream): sounding += 1
	if sounding < stack: play(cue_name,at,strength)

# --- Players -----------------------------------------------------------------------

## Attenuation off and gentle panning, as the Genesis stroke voices: a tool is
## in the hand, so it is heard at its level wherever the camera stands.
func _player3d(stream: AudioStream) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = GenesisAudio.BUS
	player.panning_strength = 0.6
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	add_child(player)
	return player

func _loop(path: String) -> AudioStreamWAV:
	var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	return stream
