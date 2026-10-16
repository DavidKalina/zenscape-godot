extends "res://scripts/enemies/inhaler_head.gd"
## The Olmec boss's head alone, phase 1 (docs/design/olmec-boss/spec-olmec-boss.md
## item 2): the inhaler head (scripts/enemies/inhaler_head.gd) as it is
## everywhere, plus a fight of its own. Only studies/olmec_field.gd spawns
## it; the head elsewhere is untouched.
##
## A lock target (scripts/lock_on/foot_lock.gd, gust_shot.gd): in
## "lock_targets", `aim_point` its brow, `tall`, `lock_reach` across the
## field, and `hit(at, way, strength)`: it rocks back, shudders, dust
## bursts off it. A hit in the absorb's tell or the absorb itself breaks
## it: the air it held bursts out harmless and it reels ("stagger").
##
## Its round (`state`):
##   "ready"        it grinds round to face him, `ready` s (a little less
##                  each round), then the absorb.
##   "absorb_tell"  `tell` s: it rears back on its jaw's hinge, the jaw
##                  grinds open, the eyes light, the draw starts.
##   "absorb"       slammed onto its chin it draws in hard (`absorb` s): the
##                  inhale's streaks, dust, leaves and grass all toward its
##                  mouth, a light pull on him (`pull`), its stone swelling
##                  with what it takes in (`swell`). Drawn into its mouth he
##                  is gulped, held and blown out as ever (the base's
##                  "gulp", "after").
##   "puff_tell"    the puff it picked (`pick_puff`: by his distance, a little
##                  luck), its own tell (scripts/olmec_boss/puffs.gd TELLS):
##                  volley  jaw clamped, cheeks blown out, aimed at him
##                  ring    reared high on its heel, jaw wide, held
##                  whirl   it rocks side to side, jaw half open, winding up
##                  breath  leaning back, jaw slowly open, eyes flaring
##   "puff"         the puff let go (puffs.gd), the swell going out of it.
##   "spent"        `spent` s slumped, jaw shut, eyes low: the window.
##   "stagger"      `stagger` s reeling from a hit that broke an absorb.
##   "cry"          after `phase_hits` hits: it rears and cries out
##                  (`phase_done` emitted once, `phase1_done` true), then
##                  "done": it sits lit and silent, waiting for its body.

const Puffs = preload("res://scripts/olmec_boss/puffs.gd")

signal phase_done(head)
signal puffed(kind: String)

const GROUP := &"lock_targets"
const REACH := Vector2(48.0,58.0)
## The puffs it picks from (puffs.gd builds each).
const PUFF_KINDS := ["volley","ring","whirl","breath"]
const MINE := ["ready","absorb_tell","absorb","puff_tell","puff","spent","stagger","cry","done"]

var hits := 0
var phase1_done := false
var puffs: Puffs
## The puff it is on ("" none) and the one it picks next ("" by its own
## choice: a driver or a test may set it).
var puff := ""
var next_puff := ""
var absorbs := 0
var interrupts := 0
var swell := 0.0
var _swell_want := 0.0
var _rounds := 0
var _ready_for := 1.5
var _hit_rng := RandomNumberGenerator.new()

func default_knobs(n: Dictionary) -> Dictionary:
	var k := super.default_knobs(n)
	k.merge({
		# It sees the whole field, all round.
		"sight":n.unit*60.0,"sight_half":PI,"lose":99.0,
		# A light pull: never off his feet; the gulp only at its lips.
		"pull":n.run*0.6,"trip_pull":n.run*5.0,"reach":n.unit*16.0,"pull_d0":n.unit*6.0,
		"tell":1.3,"absorb":2.6,"ready":2.2,"ready_min":1.1,"spent":1.7,"stagger":0.9,
		"phase_hits":6,"swell":0.14,
		# Pick weights by his distance (m): near the ring, far the volley.
		"near":n.unit*7.0,"far":n.unit*13.0,
	},true)
	return k

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	add_to_group(GROUP)
	_hit_rng.seed = 911
	state = "ready"
	_ready_for = float(knobs.ready)

func _art(root: Node3D) -> void:
	super._art(root)
	puffs = Puffs.new()
	puffs.name = "Puffs"
	add_child(puffs)
	puffs.setup(self,DisplayServer.get_name() != "headless")

# --- The lock's asks ---------------------------------------------------------------------

func aim_point() -> Vector3:
	return global_position+Vector3.UP*height*0.5+face_flat()*length*0.15

func lock_reach() -> Vector2:
	return REACH

func tall() -> float:
	return height*1.05

## Hit by the gust shot: a rock back, a shudder, dust; an absorb broken.
func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	if gone or phase1_done: return
	hits += 1
	_lean_kick = maxf(_lean_kick,0.09*strength)
	_shake = maxf(_shake,0.035)
	_glow = 1.0
	_flap = 0.5
	var out := (at-global_position)
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else face_flat()
	for i in range(3): air.grind(at+Vector3(_hit_rng.randf_range(-0.6,0.6),_hit_rng.randf_range(-0.6,0.4),_hit_rng.randf_range(-0.6,0.6)))
	air.thud(rest_point()+out*width*0.45,out,0.7,width*0.6)
	field.sound(&"head_thud",at)
	var broke := state in ["absorb_tell","absorb"]
	print("boss head: hit %d/%d (%.2f) in %s%s" % [hits,int(knobs.phase_hits),strength,state," - absorb broken" if broke else ""])
	if hits >= int(knobs.phase_hits):
		_cry()
		return
	if broke:
		interrupts += 1
		# What it held bursts out of it, harmless.
		air.blast(mouth(),face_flat())
		_swell_want = 0.0
		draw_share = 0.0
		_go("stagger")
		field.sound(&"head_blast",mouth())
	elif state in ["ready","spent"]:
		_go("stagger")

func _cry() -> void:
	phase1_done = true
	puffs.stop()
	puff = ""
	_swell_want = 0.0
	_go("cry")
	field.sound(&"head_call",mouth())
	print("boss head: phase 1 done after %d hits" % hits)
	phase_done.emit(self)

# --- Arena -------------------------------------------------------------------------------

## A blow on the arena's pieces, if the study has an arena
## (`arena.hit_at(point, radius, strength)`); else nothing.
func hit_arena(point: Vector3, radius: float, strength: float) -> void:
	var study: Object = field.study if field != null else null
	if study == null: return
	var arena: Variant = study.get("arena")
	if arena is Object and is_instance_valid(arena) and (arena as Object).has_method("hit_at"):
		(arena as Object).call("hit_at",point,radius,strength)

# --- A frame -----------------------------------------------------------------------------

func think(delta: float) -> void:
	if perch != null or _falling or not (state in MINE):
		super.think(delta)
		# Its own round again once the base's gulp and blow-out are done.
		if perch == null and state in ["scoot","notice"]: _go("ready")
		swell = move_toward(swell,0.0,delta*2.0)
		puffs.step(delta)
		return
	_clock += delta
	state_t += delta
	var m: PilotMotor = field.motor
	var chest := _chest(m)
	var want_open := 0.0
	var want_glow := 0.35
	var want_draw := 0.0
	var want_lean := 0.0
	match state:
		"ready":
			_track(chest,delta,0.25)
			want_glow = 0.45
			if state_t >= _ready_for and absf(_aim_off(chest)) < 0.4 and _act == "":
				_go("absorb_tell")
				tell()
				field.sound(&"head_inhale",global_position)
		"absorb_tell":
			_track(chest,delta,0.4)
			var k := clampf(state_t/float(knobs.tell),0.0,1.0)
			want_open = smoothstep(0.0,1.0,k)*0.75
			want_glow = lerpf(0.5,1.0,k)
			want_draw = float(knobs.tell_draw)*k
			want_lean = 0.09*smoothstep(0.0,0.7,k)
			_shake = 0.008*k
			if state_t >= float(knobs.tell):
				_go("absorb")
				absorbs += 1
				_lean_kick = -0.12
				_thud(face_flat(),0.9)
		"absorb":
			_track(chest,delta,float(knobs.track_rest))
			var k := clampf(state_t/float(knobs.absorb),0.0,1.0)
			want_open = 0.8+0.04*sin(_clock*17.0)
			want_glow = 1.0
			want_draw = 1.0
			want_lean = -0.035+0.012*sin(_clock*9.0)
			_shake = 0.006+0.006*k
			_swell_want = k
			puffs.absorbing(draw_share,delta)
			if state_t >= float(knobs.absorb):
				puff = next_puff if next_puff != "" else pick_puff(chest)
				next_puff = ""
				_go("puff_tell")
				puffs.tell(puff)
				field.sound(&"head_strain",mouth())
		"puff_tell":
			var span: float = puffs.tell_len(puff)
			var k := clampf(state_t/span,0.0,1.0)
			var p: Dictionary = puffs.tell_pose(puff,k,_clock)
			want_open = float(p.open)
			want_lean = float(p.lean)
			want_glow = 1.0
			_shake = float(p.shake)
			_swell_want = 1.0+float(p.swell)
			if bool(p.aim): _track(chest,delta,0.15)
			elif _act == "pivot": _acting(delta)
			if _act == "": _pose = [0.0,float(p.get("roll",0.0)),1.0,0.0]
			if state_t >= span:
				_pose = [0.0,0.0,1.0,0.0]
				_go("puff")
				puffs.release(puff,chest)
				puffed.emit(puff)
		"puff":
			var p: Dictionary = puffs.puff_pose(puff,state_t,_clock)
			want_open = float(p.open)
			want_lean = float(p.lean)
			want_glow = 1.0
			_shake = float(p.shake)
			_swell_want = maxf(0.0,1.0-state_t/maxf(puffs.puff_len(puff),0.1))
			if bool(p.aim): _track(chest,delta,0.6)
			elif _act == "pivot": _acting(delta)
			if state_t >= puffs.puff_len(puff):
				_go("spent")
				puff = ""
		"spent":
			var k := clampf(state_t/float(knobs.spent),0.0,1.0)
			want_open = 0.0 if state_t > 0.4 else 0.5*(1.0-state_t/0.4)
			want_glow = lerpf(0.2,0.45,k)
			want_lean = -0.06*(1.0-smoothstep(0.5,1.0,k))
			_swell_want = 0.0
			if _act == "pivot": _acting(delta)
			if state_t >= float(knobs.spent): _next_round()
		"stagger":
			var k := clampf(state_t/float(knobs.stagger),0.0,1.0)
			# Reeling: rocked back, a wobble dying away, the jaw slack.
			want_lean = 0.1*sin(k*TAU*1.25)*(1.0-k)
			want_open = 0.45*(1.0-k)
			want_glow = 0.6*(1.0-k)+0.2
			_shake = 0.02*(1.0-k)
			_swell_want = 0.0
			if _act == "pivot": _acting(delta)
			if state_t >= float(knobs.stagger): _next_round()
		"cry":
			var k := clampf(state_t/2.6,0.0,1.0)
			# Reared right back, jaw at its widest, howling; then down.
			want_lean = 0.2*smoothstep(0.0,0.2,k)*(1.0-smoothstep(0.75,1.0,k))
			want_open = 1.1*smoothstep(0.0,0.15,k)*(1.0-smoothstep(0.8,1.0,k))
			want_glow = 1.0
			_shake = 0.03*(1.0-k)+0.01
			if fmod(state_t,0.3) < delta:
				air.call_out(mouth(),face_flat())
				air.swallowing(mouth()-Vector3(-face_flat().z,0,face_flat().x)*width*0.5,mouth()+Vector3(-face_flat().z,0,face_flat().x)*width*0.5,face_flat())
			if state_t > 0.9 and state_t-delta <= 0.9: field.sound(&"head_call",mouth())
			if state_t >= 2.6: _go("done")
		"done":
			want_glow = 1.0
			want_lean = 0.01*sin(_clock*1.3)
			_shake = 0.0
	_flap = maxf(0.0,_flap-delta)
	if _flap > 0.0: want_open = maxf(want_open,0.35*sin(clampf(1.0-_flap/0.5,0.0,1.0)*PI))
	var fast := state in ["puff","stagger"] or (state == "puff_tell" and puff == "ring" and state_t > puffs.tell_len(puff)*0.6)
	var jaw_rate := 9.0 if fast else (5.0 if _flap > 0.0 or state == "cry" else 1.6)
	_open = move_toward(_open,want_open,jaw_rate*delta)
	_glow = move_toward(_glow,want_glow,2.0*delta)
	_lean = lerpf(_lean,want_lean,1.0-exp(-(14.0 if fast else 5.0)*delta))
	_lean_kick = move_toward(_lean_kick,0.0,delta*0.5)
	if state != "absorb" and state != "absorb_tell" and state != "puff_tell": _shake = move_toward(_shake,0.0,delta*0.05)
	look.open(_open)
	look.glow(_glow)
	swell = move_toward(swell,_swell_want,delta*(1.2 if _swell_want > swell else 2.5))
	draw_share = move_toward(draw_share,want_draw,(3.0 if want_draw > draw_share else 2.5)*delta)
	air.draw(draw_share,delta)
	_pull(m,chest,delta)
	puffs.step(delta)

func _next_round() -> void:
	_rounds += 1
	_ready_for = maxf(float(knobs.ready_min),float(knobs.ready)-0.2*_rounds)*_hit_rng.randf_range(0.85,1.15)
	_go("ready")
	rest()

## Which puff now, by his distance (a little luck in it); never the same
## one three times running.
func pick_puff(chest: Vector3) -> String:
	var d := Vector2(chest.x-position.x,chest.z-position.z).length()
	var near := float(knobs.near)
	var far := float(knobs.far)
	var w := {"ring":3.0 if d < near else (1.2 if d < far else 0.4),
		"volley":0.8 if d < near else (2.0 if d < far else 3.0),
		"whirl":1.0 if d < far else 1.6,
		"breath":1.6 if d < near else (1.4 if d < far else 0.6)}
	var hist: Array = puffs.history
	if hist.size() >= 2 and hist[-1] == hist[-2]: w[hist[-1]] = 0.0
	var total := 0.0
	for k: String in w: total += float(w[k])
	var r := _hit_rng.randf()*total
	for k: String in w:
		r -= float(w[k])
		if r <= 0.0: return k
	return "volley"

## Swollen with what it drew in: its stone blown out a little round.
func _pose_skin() -> void:
	super._pose_skin()
	if swell <= 0.001: return
	var s := swell*float(knobs.swell)
	skin.transform.basis = skin.transform.basis*Basis.from_scale(Vector3(1.0+s,1.0+s*0.55,1.0+s*0.8))

## Being caught: never during its own puffs (the base's calls are off too).
func _calls(m: PilotMotor, delta: float) -> void:
	if state in MINE: return
	super._calls(m,delta)
