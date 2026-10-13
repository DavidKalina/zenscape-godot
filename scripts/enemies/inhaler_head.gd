extends "res://scripts/enemies/enemy.gd"
## The inhaler head (docs/design/roguelike/inhaler-head.md, round 2:
## inhaler-head-round2-scoot.md): a colossal carved head of the ruin-
## builders' (scripts/enemies/inhaler_head_look.gd, the Blender model
## art/blender/inhaler_head/), squared Olmec masonry, lost off its body
## (scripts/enemies/headless_body.gd) and stuck on the ground. It can't
## float: it sits on its jaw course on the isle's turf, takes the turf's
## slope, and gets about by heaving itself along, a lurch at a time. It
## can't cross a gap, heave up a face or go off a rim. Shoved or slid off
## one, it falls like the stone it is. Alone it is a pathetic thing that
## still breathes in, and still calls out: its calls when the wanderer is
## near are what its body hears.
##
## How it moves (`_act`, one action at a time, each a curve of key poses,
## then a rest):
##   heave   HEAVE: a little dip, then it rocks back onto its heel (the
##           anticipation), holds there straining, then throws itself
##           forward past flat onto its chin, lurching `heave_step` m: a
##           thud (dust, a squash, the "head_thud"), a bounce, and it rocks
##           back down flat. Then a rest of `rest_min`..`rest_max` s. Each
##           heave's timing and step vary a little; every few heaves it
##           pants a longer rest; `false_start` of them it rocks back,
##           strains and sags back down having got nowhere (SAG).
##   pivot   PIVOT: it turns by grinding notches, not a smooth yaw: one
##           side lifts (the tell), it swivels up to `notch` rad on the
##           other side's edge, drops with a small thud and grinding dust.
##   A heave goes only where it can rest after it (`_can_heave`): turf
##   under its middle and its chin's edge and both sides, no more than
##   `climb` up or `drop` down, no steeper than `slope`, no stone in the
##   way. Where it can't, it turns to its round's next point.
##
## In states (`state`):
##   "scoot"    heaving round its `route` (or a ring round where it was
##              set down), facing where it goes.
##   "notice"   he is within `sight` m, inside its `sight_half` (rad) of its
##              face and nothing stands between its mouth and him: it
##              grinds round to face him (pivots, quicker rests); out of
##              its `reach` it heaves after him; once within `lock_angle`
##              and in reach, the tell. Out of sight `lose` s, it scoots on.
##   "tell"     `tell` s: it rears back on its jaw's hinge as the jaw
##              grinds open (the jaw stays on the ground, so the opening
##              tips the head back), its eyes light, dust starts to stream
##              in; the draw rises to `tell_draw` of full.
##   "inhale"   it slams forward onto its chin (a thud) and draws, up to
##              `inhale` s, grinding a notch toward him after a
##              `track_rest` s rest each time he gets off its face.
##   "gulp"     he reached its mouth: swallowed (PilotMotor `seize`), the
##              jaw slammed shut, held `hold` s while it chews on him,
##              rocking, dust out of its ear flaps. Then:
##   "blast"    the jaw flies open and he is blown out along its face
##              (PilotMotor.knock: `blast_out` m out, `blast_up` m up, laid
##              down `blast_down` s); it rears back with the kick and slides
##              back `recoil` m (off a rim, if it sat by one).
##   "after"    `after` s: it slumps, the jaw grinds shut, the eyes go
##              dark; then it scoots on (or notices him again).
##   "fall"     nothing under its middle: it tumbles under gravity; landed,
##              "dazed" `dazed` s (a heavy rock back upright), or gone
##              below the study's `lost`.
##
## Its calls (`calls`, `calling()`, signal `called`): with him within
## `call_r` m (seen or not) it calls out every `call_every` s, a jaw flap
## and a moan ("head_call"). Its body can hear them (an ask on the body's
## side, inhaler-head-round2-scoot.md).
##
## The pull (`pull_at`, `_pull`) is round 1's, weaker: a cone out of its
## mouth, `cone` rad either side far out, `cone_near` near, reaching `reach`
## m, `pull` / (1 + (d/`pull_d0`)²) m/s at d. Only with nothing between its
## mouth and his chest, never while he rides, swims or stands on it. On the
## ground he is slid toward it (PilotMotor.carry along the walls), braced
## crouched (`brace`), dragged off his feet past `trip_pull` for `trip` s
## (`yank`); hanging from a rim his grip slips (`grip` s); in the air his
## velocity is drawn (`air_pull`); the sail and the plane feel it
## (`sail_wind`, `plane_wind`).
## Its body is a stone (the base's box): he stands on it (it carries him,
## heaves and all), he can't walk through it, it shoves him out moving into
## him. Its lurch onto its chin shoves him if he stands at its face. No
## damage anywhere. Sizes come from the walker's (enemy_field.gd
## `numbers()`).

const Look = preload("res://scripts/enemies/inhaler_head_look.gd")
const Air = preload("res://scripts/enemies/inhaler_head_air.gd")

signal gulped(enemy)
signal blew(enemy)
signal called(enemy)

## The head's placeholder voices (studies/enemy_yard.gd `_synth`: seconds,
## tone Hz, tone at the end, noise share, noise smoothing, attack, flutter
## Hz); the scenes with a head play these.
const VOICES := {
	"head_grind":[0.9,0.0,0.0,1.0,0.07,0.05,13.0],
	"head_inhale":[3.0,0.0,0.0,1.0,0.22,0.9,0.0],
	"head_yank":[0.35,0.0,0.0,1.0,0.4,0.01,0.0],
	"head_gulp":[0.45,70.0,40.0,0.4,0.15,0.005,0.0],
	"head_blast":[0.9,0.0,0.0,1.0,0.55,0.005,0.0],
	"head_thud":[0.4,52.0,34.0,0.55,0.2,0.003,0.0],
	"head_scrape":[0.5,0.0,0.0,1.0,0.12,0.04,22.0],
	"head_strain":[0.7,62.0,74.0,0.35,0.05,0.25,7.0],
	"head_call":[1.1,96.0,64.0,0.3,0.08,0.18,5.0],
}

## The key poses of a heave, at a heave length of 1 (s; scaled by
## `heave`): [t, pitch (rad, + nose up on its heel, - down on its chin),
## the step's share made, squash (height share), lift (shares of its
## height), the ease into this key]. The thud is at THUD.
const HEAVE := [
	[0.00,0.0,0.0,1.0,0.0,"lin"],
	[0.14,-0.03,0.0,0.985,0.0,"inout"],
	[0.48,0.19,0.0,1.035,0.0,"inout"],
	[0.62,0.205,0.0,1.04,0.0,"lin"],
	[0.71,-0.07,0.6,1.0,0.035,"in"],
	[0.77,-0.2,1.0,0.88,0.0,"in"],
	[0.88,-0.14,1.0,1.03,0.0,"out"],
	[1.08,0.03,1.0,0.995,0.0,"inout"],
	[1.25,0.0,1.0,1.0,0.0,"inout"],
]
const HEAVE_LEN := 1.25
const THUD := 0.77
## When it strains on its heel (the strain's sound and tremble).
const STRAIN := Vector2(0.44,0.64)
## A false start: it rocks back, strains, and sags back having got nowhere.
const SAG := [
	[0.0,0.0,0.0,1.0,0.0,"lin"],
	[0.5,0.1,0.0,1.02,0.0,"inout"],
	[0.85,0.115,0.0,1.025,0.0,"lin"],
	[1.0,-0.035,0.0,0.97,0.0,"in"],
	[1.18,0.01,0.0,1.0,0.0,"out"],
	[1.35,0.0,0.0,1.0,0.0,"inout"],
]
const SAG_LEN := 1.35
## A notch of a turn: [t, roll (rad, + its right side up), the notch's share
## made, squash, lift, ease]. The thud at PIVOT_THUD.
const PIVOT := [
	[0.0,0.0,0.0,1.0,0.0,"lin"],
	[0.18,0.075,0.08,1.02,0.0,"out"],
	[0.4,0.06,1.0,1.02,0.0,"inout"],
	[0.47,0.0,1.0,0.95,0.0,"in"],
	[0.6,0.0,1.0,1.0,0.0,"out"],
]
const PIVOT_LEN := 0.6
const PIVOT_THUD := 0.47

## Whether it holds the pilot now (the study hides the figure).
var swallowed := false
var look: Node3D
var air: Node3D
## Where its round goes (world points; their y is ignored).
var route: Array = []
## The drawn air's share now (0..1), and its pull on him this frame (m/s).
var draw_share := 0.0
var pulling := 0.0
## Gulps, blasts, heaves, turning notches, balks (a heave it couldn't
## make), calls, falls: for the HUD and checks.
var gulps := 0
var blasts := 0
var heaves := 0
var notches := 0
var balks := 0
var calls := 0
var falls := 0
## Set by its headless body (scripts/enemies/headless_body.gd) as they meet:
## the head is carried to its neck (`head_seat()`, `head_facing()`), its
## scoot and its breath stopped, its eyes lit.
var perch: Node3D = null
var _leg := 0
var _home := Vector3.ZERO
var _home_face := 0.0
var _ground := 0.0
var _clock := 0.0
var _unseen := 0.0
var _strain := 0.0
var _grip := 0.0
var _shake := 0.0
var _open := 0.0
var _glow := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _blast_way := Vector3.FORWARD
var _rng := RandomNumberGenerator.new()
# The action now ("", "heave", "sag", "pivot"), its clock, its length (s),
# its step (m) or its notch (rad), where and how it faced when it began.
var _act := ""
var _act_t := 0.0
var _act_len := 1.0
var _act_amount := 0.0
var _act_from := Vector3.ZERO
var _act_face := 0.0
var _act_thud := false
var _act_strained := false
var _rest := 0.0
var _since_pant := 0
# The pose: from the action, from the state (`_lean`, pitch), the slope
# under it, the tumble of a fall; all on the skin.
var _pose := [0.0,0.0,1.0,0.0]
var _lean := 0.0
var _lean_kick := 0.0
var _slope := Vector2.ZERO
var _slope_want := Vector2.ZERO
var _tumble := Vector3.ZERO
var _slide := Vector3.ZERO
var _falling := false
var _call_t := 1.0
var _flap := 0.0
var _last_call := -INF
# Whether it has found turf under it yet: a generated layer stands its
# isles' stone in after its enemies, so till then it waits where it was
# set down (it doesn't fall through stone that isn't there yet).
var _settled := false

func _init() -> void:
	cost = 3
	tags = PackedStringArray(["pulls","grounded","loud"])
	tell_sound = &"head_grind"

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"size":3.0,"ring":n.unit*6.0,
		"heave":1.0,"heave_step":n.unit*0.72,"rest_min":0.3,"rest_max":0.95,"false_start":0.18,
		"pant_every":4,"pant":1.6,"notch":0.32,"pivot":1.0,
		"climb":n.unit*0.4,"drop":n.unit*0.75,"slope":0.42,
		"sight":n.unit*11.0,"sight_half":1.0,"lose":1.8,"lock_angle":0.16,"notice_rest":0.2,
		"tell":1.8,"tell_draw":0.15,"inhale":3.5,"track_rest":0.55,
		"reach":n.unit*9.5,"cone":0.5,"cone_near":1.3,
		"pull":n.run*1.05,"pull_d0":n.unit*3.5,"air_pull":2.0,"brace":0.5,
		"trip":0.55,"trip_pull":n.run*0.75,"grip":2.2,"yank":n.run*1.2,"yank_up":n.unit*1.2,
		"gulp_reach":n.unit*1.15,"hold":1.2,
		"blast_out":n.unit*15.0,"blast_up":n.unit*1.8,"blast_down":1.0,"recoil":n.unit*0.6,"after":3.5,
		"shove_out":n.unit*2.2,"shove_up":n.unit*0.5,
		"call_r":n.unit*15.0,"call_every":3.0,"call_hold":4.0,
		"dazed":2.4,"stone_skid":n.unit*7.0,
		"sail_wind":1.6,"plane_wind":2.2,
	}

## Chin to crown `size` of his heights; as wide as the model, as deep.
func _size(n: Dictionary) -> void:
	height = float(knobs.size)*n.unit
	width = height*1.04
	length = height*0.84

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	_rng.seed = hash([at.x,at.z])
	_home = at
	_home_face = facing
	_ground = at.y
	route = knobs.get("route",[])
	if route.is_empty():
		for i in range(5):
			var a := TAU*i/5.0+facing
			route.append(at+Vector3(sin(a),0.0,cos(a))*float(knobs.ring))
	grounded = true
	state = "scoot"
	_rest = _rng.randf_range(0.2,1.0)

func _art(root: Node3D) -> void:
	look = Look.new()
	look.name = "Look"
	root.add_child(look)
	look.build(height)
	air = Air.new()
	air.name = "Air"
	add_child(air)
	air.setup(self,float(knobs.reach),float(knobs.cone),DisplayServer.get_name() != "headless")

func _ready() -> void:
	# Set down on the turf under it (its spot's height may be a guess).
	var g := _settle_floor()
	if g != -INF:
		position.y = g
		_ground = g
		_home.y = g
		_settled = true

# --- What the air visuals and its body ask -------------------------------------------

func mouth() -> Vector3:
	return look.mouth()

## The way its face looks, flat (unit).
func face_flat() -> Vector3:
	var f := PilotMotor.forward(facing)
	return Vector3(f.x,0.0,f.y)

## The turf's height under it (the last seen, while it falls).
func ground_y() -> float:
	return _ground

## The turf's height under `p`, -INF over nothing.
func ground_at(p: Vector3) -> float:
	return field.floor_under(Vector3(p.x,_ground,p.z),6.0,12.0,body.get_rid())

## Where it rests: its jaw's foot, on the turf (its body lifts it from
## here).
func rest_point() -> Vector3:
	return Vector3(position.x,_ground,position.z)

## Whether it sits on the ground now (not carried, not falling).
func on_ground() -> bool:
	return perch == null and not _falling and not gone

## Where it was set down: its body (scripts/enemies/body_spawner.gd) knows
## it by this.
func home() -> Vector3:
	return _home

## Off its body's neck and back home on the turf (the body that had it
## taken away: scripts/enemies/body_spawner.gd).
func go_home() -> void:
	perch = null
	vel = Vector3.ZERO
	_slide = Vector3.ZERO
	_falling = false
	_ground = _home.y
	position = _home
	facing = _home_face
	_leg = 0
	_act = ""
	_rest = 0.5
	_go("scoot")
	rotation.y = facing

## Whether it called out lately (within `call_hold` s): its body hears it.
func calling() -> bool:
	return _clock-_last_call <= float(knobs.call_hold)

# --- A frame ---------------------------------------------------------------------------

func think(delta: float) -> void:
	_clock += delta
	state_t += delta
	if perch != null:
		_perched(delta)
		return
	var m: PilotMotor = field.motor
	var chest := _chest(m)
	if not _settled:
		air.draw(0.0,delta)
		return
	if _falling or state in ["fall","dazed"]:
		_fallen(delta)
		return
	var sees := _sees(m,chest)
	_unseen = 0.0 if sees else _unseen+delta
	var want_open := 0.0
	var want_glow := 0.0
	var want_draw := 0.0
	var want_lean := 0.0
	match state:
		"scoot":
			_scoot(delta)
			if sees and _act != "heave": _go("notice")
		"notice":
			want_glow = 0.3
			want_lean = 0.0
			_notice(chest,delta)
		"tell":
			_track(chest,delta,float(knobs.track_rest)*1.5)
			var k := clampf(state_t/float(knobs.tell),0.0,1.0)
			want_open = smoothstep(0.0,1.0,k)*0.7
			want_glow = lerpf(0.4,1.0,k)
			want_draw = float(knobs.tell_draw)*k
			want_lean = 0.07*smoothstep(0.0,0.7,k)
			_shake = 0.008*k
			if state_t >= float(knobs.tell):
				_go("inhale")
				# Slammed forward onto its chin, and the draw kicks in.
				_lean_kick = -0.11
				_thud(face_flat(),0.8)
		"inhale":
			_track(chest,delta,float(knobs.track_rest))
			want_open = 0.78+0.04*sin(_clock*17.0)
			want_glow = 1.0
			want_draw = 1.0
			want_lean = -0.035+0.012*sin(_clock*9.0)
			_shake = 0.008
			if _unseen > float(knobs.lose) or state_t >= float(knobs.inhale): _go("after")
		"gulp":
			want_open = 0.0
			want_glow = 1.0
			# Chewing on him: rocking on its chin, shuddering.
			want_lean = -0.03+0.05*maxf(sin(state_t*TAU*2.6),0.0)
			_shake = 0.03*(1.0-smoothstep(0.0,float(knobs.hold),state_t))+0.012
			_hold(m)
			if fmod(state_t,0.25) < delta:
				var side := Vector3(-face_flat().z,0.0,face_flat().x)*width*0.55
				var flaps := global_position+Vector3.UP*height*0.45
				air.swallowing(flaps-side,flaps+side,face_flat())
			if state_t >= float(knobs.hold): _blast(m)
		"after":
			var k := clampf(state_t/float(knobs.after),0.0,1.0)
			want_open = 0.0 if state_t > 0.6 else 1.1*(1.0-state_t/0.6)
			want_glow = 1.0-k
			# Slumped forward, spent, then back flat.
			want_lean = -0.05*(1.0-smoothstep(0.5,1.0,k)) if state_t > 0.5 else 0.0
			_shake = 0.0
			if state_t >= float(knobs.after):
				_go("scoot")
				_rest = 0.4
				rest()
	if state != "inhale" and state != "tell" and state != "gulp": _shake = move_toward(_shake,0.0,delta*0.1)
	_calls(m,delta)
	if _flap > 0.0:
		_flap = maxf(0.0,_flap-delta)
		want_open = maxf(want_open,0.32*sin(clampf(1.0-_flap/0.55,0.0,1.0)*PI))
	# The jaw and the eyes, heavy: the jaw grinds (snaps shut in a gulp,
	# flaps as it calls).
	var jaw_rate := 9.0 if state == "gulp" or (state == "after" and state_t < 0.6) else (4.0 if _flap > 0.0 else 1.4)
	_open = move_toward(_open,want_open,jaw_rate*delta)
	_glow = move_toward(_glow,want_glow,1.5*delta)
	_lean = lerpf(_lean,want_lean,1.0-exp(-5.0*delta))
	_lean_kick = move_toward(_lean_kick,0.0,delta*0.5)
	look.open(_open)
	look.glow(_glow)
	draw_share = move_toward(draw_share,want_draw,(3.0 if want_draw > draw_share else 2.0)*delta)
	air.draw(draw_share,delta)
	_pull(m,chest,delta)

## Carried by its body: the jaw shut, no draw, the eyes lit.
func _perched(delta: float) -> void:
	state = "perched"
	vel = Vector3.ZERO
	_slide = Vector3.ZERO
	_act = ""
	_falling = false
	_shake = 0.0
	_open = move_toward(_open,0.0,1.6*delta)
	_glow = move_toward(_glow,1.0,1.0*delta)
	look.open(_open)
	look.glow(_glow)
	draw_share = 0.0
	pulling = 0.0
	air.draw(0.0,delta)

func _go(to: String) -> void:
	state = to
	state_t = 0.0
	_strain = 0.0

# --- Its calls -------------------------------------------------------------------------

## With him near (seen or not), a call every `call_every` s: a jaw flap and
## a moan. Not while it draws or holds him.
func _calls(m: PilotMotor, delta: float) -> void:
	if state in ["tell","inhale","gulp"] or swallowed: return
	var d := Vector2(m.feet.x-position.x,m.feet.z-position.z).length()
	if d > float(knobs.call_r):
		_call_t = minf(_call_t,0.8)
		return
	_call_t -= delta
	if _call_t > 0.0: return
	_call_t = float(knobs.call_every)*_rng.randf_range(0.8,1.25)*(0.7 if state == "notice" else 1.0)
	calls += 1
	_last_call = _clock
	_flap = 0.55
	_lean_kick = maxf(_lean_kick,0.04)
	field.sound(&"head_call",mouth())
	air.call_out(mouth(),face_flat())
	called.emit(self)

# --- Heaving and turning ---------------------------------------------------------------

func _scoot(delta: float) -> void:
	if _acting(delta): return
	if _rest > 0.0:
		_rest -= delta
		return
	var goal: Vector3 = route[_leg%route.size()]
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	if to.length() < float(knobs.heave_step)*0.8:
		_leg += 1
		return
	_toward(to.normalized(),1.0)

## The next action toward `way` (x, z, unit): a notch round if it's off its
## face, else a heave if it can make one (now and then a sag that gets
## nowhere); balked, its round's next point. Rests scaled by `pace`.
func _toward(way: Vector2, pace: float) -> bool:
	var off := angle_difference(facing,PilotMotor.facing_of(way))
	if absf(off) > float(knobs.notch)*0.6:
		_begin("pivot",signf(off)*minf(absf(off),float(knobs.notch)),pace)
		return true
	var step := float(knobs.heave_step)*_rng.randf_range(0.8,1.15)
	if not _can_heave(face_flat(),step):
		step *= 0.5
		if not _can_heave(face_flat(),step):
			balks += 1
			_leg += 1
			# A sag in place: it tried.
			_begin("sag",0.0,pace)
			return false
	if _rng.randf() < float(knobs.false_start): _begin("sag",0.0,pace)
	else: _begin("heave",step,pace)
	return true

func _begin(what: String, amount: float, pace: float) -> void:
	_act = what
	_act_t = 0.0
	_act_amount = amount
	_act_from = position
	_act_face = facing
	_act_thud = false
	_act_strained = false
	var vary := _rng.randf_range(0.9,1.12)
	match what:
		"heave": _act_len = HEAVE_LEN*float(knobs.heave)*vary
		"sag": _act_len = SAG_LEN*float(knobs.heave)*vary
		"pivot": _act_len = PIVOT_LEN*float(knobs.pivot)*vary
	# Its rest after: uneven, and a pant every few heaves.
	_rest = _rng.randf_range(float(knobs.rest_min),float(knobs.rest_max))*pace
	if what == "heave":
		_since_pant += 1
		if _since_pant >= int(knobs.pant_every)+_rng.randi_range(-1,1):
			_since_pant = 0
			_rest += float(knobs.pant)*pace
	elif what == "pivot": _rest = minf(_rest,0.35)*pace

## Steps the action now; false once it is done (or there is none).
func _acting(delta: float) -> bool:
	if _act == "": return false
	_act_t += delta
	var u := _act_t/_act_len
	match _act:
		"heave":
			var p := _keys(HEAVE,u*HEAVE_LEN)
			_pose = [p[0],0.0,p[2],p[3]]
			var dest := _act_from+face_flat()*_act_amount*float(p[1])
			position.x = dest.x
			position.z = dest.z
			if not _act_strained and u*HEAVE_LEN >= STRAIN.x:
				_act_strained = true
				field.sound(&"head_strain",mouth())
			if u*HEAVE_LEN > STRAIN.x and u*HEAVE_LEN < STRAIN.y: _shake = 0.006
			elif _shake <= 0.006: _shake = 0.0
			if not _act_thud and u*HEAVE_LEN >= THUD:
				_act_thud = true
				heaves += 1
				_thud(face_flat(),1.0)
		"sag":
			var p := _keys(SAG,u*SAG_LEN)
			_pose = [p[0],0.0,p[2],p[3]]
			if not _act_strained and u*SAG_LEN >= 0.45:
				_act_strained = true
				field.sound(&"head_strain",mouth())
			if u*SAG_LEN > 0.5 and u*SAG_LEN < 0.85: _shake = 0.007
			elif _shake <= 0.007: _shake = 0.0
			if not _act_thud and u*SAG_LEN >= 1.0:
				_act_thud = true
				_thud(face_flat(),0.4)
		"pivot":
			var p := _keys(PIVOT,u*PIVOT_LEN)
			# The roll lifts the side away from the turn: it swivels on the
			# other edge.
			_pose = [0.0,p[0]*-signf(_act_amount),p[2],p[3]]
			facing = wrapf(_act_face+_act_amount*float(p[1]),-PI,PI)
			if not _act_thud and u*PIVOT_LEN >= PIVOT_THUD:
				_act_thud = true
				notches += 1
				var side := Vector3(-face_flat().z,0.0,face_flat().x)*width*0.45*signf(_act_amount)
				air.grind(rest_point()+side+Vector3.UP*0.2)
				air.grind(rest_point()-side+Vector3.UP*0.2)
				field.sound(&"head_scrape",position)
	if u >= 1.0:
		_act = ""
		_pose = [0.0,0.0,1.0,0.0]
		_shake = 0.0 if state in ["scoot","notice"] else _shake
		return false
	return true

## Whether harm: its lurch onto its chin, him at its face.
func harmful() -> bool:
	if _act != "heave": return false
	var u := _act_t/_act_len*HEAVE_LEN
	return u > 0.64 and u < THUD+0.04

## A thud on the turf: dust off its chin's edge (`way` its face), a squash
## already in the pose, the sound; `size` 1 a full heave.
func _thud(way: Vector3, size: float) -> void:
	var chin := rest_point()+way*height*0.5
	air.thud(chin,way,size,width*0.8)
	field.sound(&"head_thud",chin)

## Facing him: notches round to him; out of reach it heaves after him; on
## him and in reach, the tell.
func _notice(chest: Vector3, delta: float) -> void:
	if _acting(delta): return
	if _unseen > float(knobs.lose):
		_go("scoot")
		_rest = 0.5
		return
	var to := Vector2(chest.x-position.x,chest.z-position.z)
	var off := angle_difference(facing,PilotMotor.facing_of(to.normalized()))
	var near := mouth().distance_to(chest) <= float(knobs.reach)*0.8
	if absf(off) < float(knobs.lock_angle) and near:
		_go("tell")
		tell()
		field.sound(&"head_inhale",global_position)
		return
	if _rest > 0.0:
		_rest -= delta
		return
	if absf(off) >= float(knobs.lock_angle):
		_begin("pivot",signf(off)*minf(absf(off),float(knobs.notch)),1.0)
		_rest = float(knobs.notice_rest)
	elif not _toward(to.normalized(),0.6): _rest = 1.0

## Telling and drawing: a notch toward him when he's off its face, after a
## `rest` s rest between notches.
func _track(chest: Vector3, delta: float, rest_s: float) -> void:
	if _acting(delta): return
	var off := _aim_off(chest)
	if absf(off) < float(knobs.lock_angle)*0.6: return
	if _rest > 0.0:
		_rest -= delta
		return
	_begin("pivot",signf(off)*minf(absf(off),float(knobs.notch)*0.8),1.0)
	_rest = rest_s

## How far off its face `p` is (rad, flat).
func _aim_off(p: Vector3) -> float:
	var to := Vector2(p.x-position.x,p.z-position.z)
	if to.length() < 0.01: return 0.0
	return angle_difference(facing,PilotMotor.facing_of(to.normalized()))

## A key pose curve `keys` at `t` (s): [pitch or roll, share, squash, lift].
static func _keys(keys: Array, t: float) -> Array:
	var last: Array = keys[keys.size()-1]
	if t >= float(last[0]): return [last[1],last[2],last[3],last[4]]
	for i in range(1,keys.size()):
		var b: Array = keys[i]
		if t > float(b[0]): continue
		var a: Array = keys[i-1]
		var k := clampf((t-float(a[0]))/maxf(float(b[0])-float(a[0]),0.0001),0.0,1.0)
		match str(b[5]):
			"in": k = k*k
			"out": k = 1.0-(1.0-k)*(1.0-k)
			"inout": k = k*k*(3.0-2.0*k)
		return [lerpf(a[1],b[1],k),lerpf(a[2],b[2],k),lerpf(a[3],b[3],k),lerpf(a[4],b[4],k)]
	return [last[1],last[2],last[3],last[4]]

# --- The ground ------------------------------------------------------------------------

## The turf under `p` within its climb over its ground and its drop under.
func _floor(p: Vector3) -> float:
	return field.floor_under(Vector3(p.x,_ground,p.z),float(knobs.climb)+0.35,float(knobs.drop)+0.35,body.get_rid())

## The turf under where it was set down, looked for wide (6 m over,
## its height under), or -INF.
func _settle_floor() -> float:
	return field.floor_under(position,6.0,height*3.0,body.get_rid())

## Where its jaw's edges are: its chin's edge ahead, its heel's behind, its
## sides (m from its middle).
func _edges() -> Vector3:
	return Vector3(height*0.5,height*0.34,height*0.38)

## Whether a heave of `step` m along `way` ends where it can rest.
func _can_heave(way: Vector3, step: float) -> bool:
	var e := _edges()
	var rid := body.get_rid()
	# Stone in the way over what it can heave onto.
	if field.blocked(position+Vector3.UP*(float(knobs.climb)+0.15),way*(e.x+step+0.1),rid): return false
	if field.blocked(position+Vector3.UP*height*0.6,way*(e.x+step+0.1),rid): return false
	var to := position+way*step
	var mid := _floor(to)
	if mid == -INF or mid-_ground > float(knobs.climb) or _ground-mid > float(knobs.drop): return false
	var chin := _floor(to+way*e.x)
	if chin == -INF or absf(chin-mid) > float(knobs.climb)+e.x*tan(float(knobs.slope)): return false
	var side := Vector3(-way.z,0.0,way.x)
	for s: float in [-1.0,1.0]:
		var at := _floor(to+side*e.z*s+way*e.x*0.5)
		if at == -INF or absf(at-mid) > float(knobs.climb)+e.z*tan(float(knobs.slope)): return false
	return true

# --- Seeing him -------------------------------------------------------------------------

func _chest(m: PilotMotor) -> Vector3:
	return m.feet+Vector3.UP*field.study.ground.head_top*0.55

## Whether it sees him: near enough, inside its sight (wider once it has
## him), nothing between its mouth and his chest.
func _sees(m: PilotMotor, chest: Vector3) -> bool:
	if swallowed: return true
	var mouth_at := mouth()
	if mouth_at.distance_to(chest) > float(knobs.sight): return false
	var half := float(knobs.sight_half)*(1.6 if state in ["notice","tell","inhale"] else 1.0)
	if absf(_aim_off(chest)) > half: return false
	return _clear(mouth_at,chest)

## Nothing stands between `a` and `b` (its own body left out).
func _clear(a: Vector3, b: Vector3) -> bool:
	_ray.from = a
	_ray.to = b
	_ray.collision_mask = field.study.ground.mask
	_ray.exclude = [body.get_rid()]
	return field.study.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()

# --- The pull ----------------------------------------------------------------------------

## The pull (m/s, toward the mouth) at `p` at a full draw: the cone, the
## reach, the falloff; no cover counted.
func pull_at(p: Vector3) -> float:
	var mouth_at := mouth()
	var off := p-mouth_at
	var d := off.length()
	if d > float(knobs.reach) or d < 0.001: return 0.0
	var half := lerpf(float(knobs.cone_near),float(knobs.cone),smoothstep(0.0,float(knobs.reach)*0.5,d))
	var flat_off := Vector3(off.x,0.0,off.z)
	var angle := face_flat().angle_to(flat_off/maxf(flat_off.length(),0.001)) if flat_off.length() > 0.3 else 0.0
	var in_cone := 1.0-smoothstep(half*0.7,half,angle)
	var fade := 1.0-smoothstep(float(knobs.reach)*0.75,float(knobs.reach),d)
	var k := d/float(knobs.pull_d0)
	return float(knobs.pull)*in_cone*fade/(1.0+k*k)

## The air it draws at `p` for the sail and the plane: toward the mouth,
## `scale` times the pull there, cover counted.
func air_at(p: Vector3, scale: float) -> Vector3:
	if draw_share <= 0.0 or gone: return Vector3.ZERO
	var s := pull_at(p)*draw_share
	if s <= 0.0 or not _clear(mouth(),p): return Vector3.ZERO
	return (mouth()-p).normalized()*s*scale

func _pull(m: PilotMotor, chest: Vector3, delta: float) -> void:
	pulling = 0.0
	if swallowed or draw_share <= 0.0: return
	if m.rider != null or m.swimming or m.seized(): return
	# Stood on the head itself: out of its air.
	if m.feet.y > position.y+height*0.8: return
	var mouth_at := mouth()
	var to := mouth_at-chest
	var d := to.length()
	if Vector2(Vector2(to.x,to.z).length(),to.y*0.5).length() <= float(knobs.gulp_reach):
		_gulp(m)
		return
	var p := pull_at(chest)*draw_share
	if p <= 0.01 or not _clear(mouth_at,chest):
		_grip = maxf(0.0,_grip-delta)
		return
	if m.on_ledge():
		# Hanging from a rim he holds on, his hands slipping: torn off
		# toward it after `grip` s of the pull at `trip_pull`.
		pulling = p
		_grip += delta*p/float(knobs.trip_pull)
		if _grip >= float(knobs.grip):
			_grip = 0.0
			m.knock(to/d*float(knobs.yank)+Vector3.UP*sqrt(2.0*m.gravity*float(knobs.yank_up)*0.5),self)
			field.sound(&"head_yank",chest)
		return
	_grip = maxf(0.0,_grip-delta)
	if m.grounded and m.move != "tumble":
		var braced := m.crouch
		if braced: p *= float(knobs.brace)
		pulling = p
		var flat := Vector2(to.x,to.z).normalized()*p*delta
		var dest: Vector3 = field.study.ground.slide(m.feet,flat)
		m.carry(Transform3D(Basis.IDENTITY,Vector3(dest.x-m.feet.x,0.0,dest.z-m.feet.z)),0.0)
		# Too strong to stand in: dragged off his feet.
		if not braced and p >= float(knobs.trip_pull): _strain += delta
		else: _strain = maxf(0.0,_strain-delta)
		if _strain >= float(knobs.trip):
			_strain = 0.0
			var way := to.normalized()
			m.knock(way*float(knobs.yank)+Vector3.UP*sqrt(2.0*m.gravity*float(knobs.yank_up)),self)
			field.sound(&"head_yank",chest)
	else:
		pulling = p
		m.velocity += to/d*p*float(knobs.air_pull)*delta

# --- The gulp and the blast ---------------------------------------------------------

func _gulp(m: PilotMotor) -> void:
	swallowed = true
	gulps += 1
	m.seize()
	_hold(m)
	_go("gulp")
	_act = ""
	_pose = [0.0,0.0,1.0,0.0]
	draw_share = 0.0
	field.sound(&"head_gulp",mouth())
	gulped.emit(self)

## Held in its mouth: his feet just inside the lips.
func _hold(m: PilotMotor) -> void:
	m.feet = mouth()-Vector3.UP*field.study.ground.head_top*0.5-face_flat()*0.3
	m.velocity = Vector3.ZERO

func _blast(m: PilotMotor) -> void:
	swallowed = false
	blasts += 1
	_blast_way = face_flat()
	m.feet = mouth()+_blast_way*(float(knobs.radius)+0.4)-Vector3.UP*field.study.ground.head_top*0.5
	m.feet.y = maxf(m.feet.y,_ground+0.1)
	var v := m.knock_velocity(Vector2(_blast_way.x,_blast_way.z),float(knobs.blast_out),float(knobs.blast_up))
	m.knock(v,self,float(knobs.blast_down))
	_open = 1.1
	air.blast(mouth(),_blast_way)
	# The kick: reared back, slid back along the turf.
	_lean_kick = 0.12
	_slide = -_blast_way*sqrt(2.0*float(knobs.stone_skid)*float(knobs.recoil))
	_shake = 0.04
	field.sound(&"head_blast",mouth())
	blew.emit(self)
	_go("after")

## Shoved `v` (m/s): it skids on its stone; over a rim, it falls.
func shove(v: Vector3) -> void:
	if perch != null or gone: return
	_act = ""
	_slide = Vector3(v.x,0.0,v.z)
	if v.y > 0.5:
		_falling = true
		vel = v
		_go("fall")

# --- Falling --------------------------------------------------------------------------

## Falling, then dazed on the turf it landed on: rocks itself upright.
func _fallen(delta: float) -> void:
	draw_share = move_toward(draw_share,0.0,3.0*delta)
	air.draw(draw_share,delta)
	_open = move_toward(_open,0.25 if _falling else 0.0,2.0*delta)
	_glow = move_toward(_glow,0.0,1.0*delta)
	look.open(_open)
	look.glow(_glow)
	pulling = 0.0
	if state == "dazed":
		var k := clampf(state_t/float(knobs.dazed),0.0,1.0)
		# Rocking itself upright: a wobble that dies away.
		_lean = 0.08*sin(k*TAU*1.5)*(1.0-k)
		if state_t >= float(knobs.dazed):
			_go("scoot")
			_rest = 0.6

# --- Moving -----------------------------------------------------------------------------

func _move(delta: float) -> void:
	if perch != null:
		position = perch.head_seat()
		facing = perch.head_facing()
		rotation.y = facing
		_ground = position.y
		look.open(_open)
		skin.transform = Transform3D(Basis.from_euler(perch.head_tilt()),Vector3.ZERO)
		return
	if _falling:
		_fall_step(delta)
		if gone: return
	else: _ground_step(delta)
	rotation.y = facing
	_pose_skin()

## On the turf: a skid (a shove or the blast's kick), then the turf under
## it: its height and slope. Nothing under its middle: it falls.
func _ground_step(delta: float) -> void:
	if _slide.length() > 0.01:
		var step := _slide*delta
		var way := _slide.normalized()
		if field.blocked(position+Vector3.UP*(float(knobs.climb)+0.15),way*(height*0.45+step.length()),body.get_rid()):
			_slide = Vector3.ZERO
		else:
			position += step
			_slide = _slide.move_toward(Vector3.ZERO,float(knobs.stone_skid)*delta)
	if not _settled:
		var g := _settle_floor()
		if g == -INF: return
		_settled = true
		position.y = g
		_ground = g
		_home.y = g
	var mid := _floor(position)
	if mid == -INF:
		_falling = true
		falls += 1
		_act = ""
		vel = Vector3(_slide.x,0.0,_slide.z)
		if vel.length() < 0.5: vel += face_flat()*-0.5
		_slide = Vector3.ZERO
		_go("fall")
		field.sound(&"head_scrape",position)
		return
	_ground = mid
	# Its slope: its chin and heel, its sides (a side over nothing is level).
	var e := _edges()
	var fwd := face_flat()
	var side := Vector3(-fwd.z,0.0,fwd.x)
	var f := _floor(position+fwd*e.x*0.9)
	var b := _floor(position-fwd*e.y*0.9)
	var r := _floor(position+side*e.z*0.9)
	var l := _floor(position-side*e.z*0.9)
	if f == -INF: f = mid
	if b == -INF: b = mid
	if r == -INF: r = mid
	if l == -INF: l = mid
	var lim := float(knobs.slope)
	_slope_want = Vector2(clampf(atan2(f-b,(e.x+e.y)*0.9),-lim,lim),clampf(atan2(r-l,e.z*1.8),-lim,lim))
	_slope = _slope.lerp(_slope_want,1.0-exp(-10.0*delta))
	var want_y := maxf(mid,(f+b)*0.5)
	# Down a step it drops at once (the thud lands it); up one it heaves.
	position.y = want_y if want_y < position.y else lerpf(position.y,want_y,1.0-exp(-14.0*delta))
	_ground = position.y
	_tumble = _tumble.lerp(Vector3.ZERO,1.0-exp(-6.0*delta))

## Tumbling under gravity, turning over its way; landed on turf, a big
## thud and dazed; under the study's `lost`, gone.
func _fall_step(delta: float) -> void:
	vel.y -= float(knobs.gravity)*delta
	var was := position
	position += vel*delta
	var flat := Vector2(vel.x,vel.z)
	var spin := clampf(flat.length()*0.6+1.0,1.0,3.0)
	var about := Vector3(-flat.y,0.0,flat.x).normalized() if flat.length() > 0.05 else Vector3.RIGHT
	var local := Basis(Vector3.UP,facing).inverse()*about
	_tumble += local*spin*delta*-1.0
	if vel.y <= 0.0:
		var g: float = field.floor_under(position,was.y-position.y+0.1,0.05,body.get_rid())
		if g != -INF:
			position.y = g
			_ground = g
			_falling = false
			vel = Vector3.ZERO
			_slide = Vector3.ZERO
			_tumble = Vector3.ZERO
			_pose = [0.0,0.0,0.82,0.0]
			_lean_kick = -0.1
			_thud(face_flat(),1.8)
			_go("dazed")
			return
	if position.y < field.lost:
		gone = true
		field.gone_count += 1
		fell.emit(self)
		queue_free()

## The skin posed: the slope under it, its action's pose and its state's
## lean (pitched on its chin's edge or its heel's, rolled on a side's),
## the jaw's opening (the jaw stays on the turf, so the head tips back on
## the hinge), a fall's tumble, the shudder.
func _pose_skin() -> void:
	var e := _edges()
	var pitch: float = float(_pose[0])+_lean+_lean_kick
	var roll: float = _pose[1]
	var squash: float = _pose[2]
	var lift: float = float(_pose[3])*height
	var t := Transform3D(Basis.from_scale(Vector3(1.0+(1.0-squash)*0.5,squash,1.0+(1.0-squash)*0.5)),Vector3.ZERO)
	# The jaw's opening: the head tips back about the hinge, the jaw kept on
	# the turf.
	var hinge: Vector3 = look.hinge()
	var open: float = float(Look.JAW_OPEN)*look.opened()
	t = Transform3D(Basis(Vector3.RIGHT,open),hinge)*Transform3D(Basis.IDENTITY,-hinge)*t
	var pz := e.y if pitch > 0.0 else -e.x
	var pivot := Vector3(0.0,0.0,pz)
	t = Transform3D(Basis(Vector3.RIGHT,pitch),pivot)*Transform3D(Basis.IDENTITY,-pivot)*t
	var px := -e.z if roll > 0.0 else e.z
	var side := Vector3(px,0.0,0.0)
	t = Transform3D(Basis(Vector3.BACK,roll),side)*Transform3D(Basis.IDENTITY,-side)*t
	t = Transform3D(Basis.from_euler(Vector3(_slope.x,0.0,_slope.y)),Vector3.UP*lift)*t
	if _tumble != Vector3.ZERO:
		var mid := Vector3.UP*height*0.45
		t = Transform3D(Basis.from_euler(_tumble),mid)*Transform3D(Basis.IDENTITY,-mid)*t
	var shake := Vector3(sin(_clock*53.0),sin(_clock*41.0+1.3),sin(_clock*47.0+2.1))*_shake
	t.basis = Basis.from_euler(Vector3(shake.x,0.0,shake.z)*0.6)*t.basis
	t.origin += shake*height*0.3
	skin.transform = t

# --- The base's contact, as a stone -------------------------------------------------

## It can't be knocked about by him; its lurch onto its chin shoves him if
## he stands at its face.
func touch(m: PilotMotor, _v_pre: Vector3) -> void:
	if gone or perch != null or swallowed or _cool > 0.0 or not harmful(): return
	if m.seized() or m.recovering() or m.on_ledge(): return
	var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
	var r := float(knobs.radius)
	if absf(local.x) > width*0.5+r or local.z > 0.0 or local.z < -(_edges().x+r+0.5): return
	if m.feet.y > position.y+height-0.1 or m.feet.y < position.y-0.6: return
	var way := PilotMotor.forward(facing)
	shove_pilot(m,way,float(knobs.shove_out),float(knobs.shove_up))

## Never pushed about by him.
func pilot_pushes(_m: PilotMotor, _way: Vector2, _speed: float) -> void:
	pass

## A rider on its crown stays on, except in the blast's kick and a fall.
func bucks() -> bool:
	return _falling or (state == "after" and state_t < 0.4)

func push_out(m: PilotMotor, slide: Callable, body_low: float, head: float) -> void:
	if swallowed: return
	super.push_out(m,slide,body_low,head)

## Its sail wind and plane wind (m/s) at `p`.
func sail_wind(p: Vector3) -> Vector3:
	return air_at(p,float(knobs.sail_wind))

func plane_wind(p: Vector3) -> Vector3:
	return air_at(p,float(knobs.plane_wind))
