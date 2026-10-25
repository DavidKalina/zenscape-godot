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
##   "cry"          after `phase_hits` stomps: it rears and cries out
##                  (`phase_done` emitted once, `phase1_done` true), then
##                  "done": it sits lit and silent, waiting for its body.

const Puffs = preload("res://scripts/olmec_boss/puffs.gd")
const Slam = preload("res://scripts/slam.gd")
const Dust = preload("res://scripts/breaks/body_dust.gd")
const Glint = preload("res://scripts/kit_isle/kit_cache_glint.gd")

## The stomp (docs/design/olmec-boss/spec-olmec-knockoff.md item 1): its
## crown is the weak spot. Only the slam (scripts/slam.gd, it joins its
## GROUP) touching down on top of it counts (`stomp`): hit-stop (the
## study's `hit_stop`), chips off the crown, the stone squashed down and
## springing back, a long reel, and him bounced off clear. `phase_hits`
## stomps end phase 1. Anything else (the gust shot's `hit`, a slam beside
## it) only glances (`glance`): the crown's glint flares and puffs dust, the
## kit caches' "not with that" (scripts/kit_isle/kit_caches.gd); a gust shot
## in an absorb still breaks it. The glint (kit_cache_glint.gd) sits on the
## crown all fight, faint, catching now and then: the spot.

signal phase_done(head)
signal puffed(kind: String)
signal stomped(head, n: int)

const GROUP := &"lock_targets"
const REACH := Vector2(48.0,58.0)
## The puffs it picks from (puffs.gd builds each).
const PUFF_KINDS := ["volley","ring","whirl","breath"]
const MINE := ["ready","absorb_tell","absorb","puff_tell","puff","spent","stagger","cry","done"]

## Stomps that counted (the card's pips; `phase_hits` ends phase 1).
var hits := 0
## Blows that only glanced off (gust shots, slams beside it).
var glances := 0
## The last stomp: {at, strength, n, bounce}.
var last_stomp := {}
var crown_glint: Node3D
var _squash := 0.0
var _squash_v := 0.0
var _reel_for := 0.9
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
		"phase_hits":3,"swell":0.14,
		# The stomp: the reel after it (s), how far off the crown's edge (m)
		# and how high (m over the crown) he is bounced, how much the stone
		# squashes, the hit-stop (s, real).
		"stomp_reel":1.9,"bounce_out":n.unit*1.6,"bounce_up":n.unit*0.7,
		"stomp_squash":0.3,"hit_stop":0.11,
		# The crown: his feet at least this share of its height up.
		"crown_up":0.72,
		# Pick weights by his distance (m): near the ring, far the volley.
		"near":n.unit*7.0,"far":n.unit*13.0,
	},true)
	return k

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	add_to_group(GROUP)
	add_to_group(Slam.GROUP)
	_hit_rng.seed = 911
	state = "ready"
	_ready_for = float(knobs.ready)

func _art(root: Node3D) -> void:
	super._art(root)
	puffs = Puffs.new()
	puffs.name = "Puffs"
	add_child(puffs)
	puffs.setup(self,DisplayServer.get_name() != "headless")
	# The weak spot's tell: one faint point on the crown, pale gold.
	var g: Sprite3D = (load("res://scripts/kit_isle/kit_cache_glint.gd") as GDScript).new()
	g.name = Glint.NODE_NAME
	g.position = Vector3(0.0,height+Glint.PROUD*4.0,length*0.05)
	g.set_instance_shader_parameter("tint",Color(1.0,0.93,0.7))
	g.rng.seed = 4711
	g.wait = 1.0
	root.add_child(g)
	crown_glint = g

## Knocked off once (spec-olmec-knockoff.md "Coming back cracked"): the
## face cracked and off-kilter, the art lane's cracked head
## (inhaler_head_build.py --cracked) built in place of the whole one.
const CRACKED := "res://assets/models/inhaler_head_cracked.glb"
var cracked := false

func crack() -> void:
	if cracked or look == null: return
	cracked = true
	var old: Node3D = look
	var parent := old.get_parent()
	var opened: float = old.opened()
	var t := old.transform
	parent.remove_child(old)
	old.queue_free()
	look = Look.new()
	look.name = "Look"
	look.model_path = CRACKED
	parent.add_child(look)
	look.transform = t
	look.build(height)
	look.open(opened)
	var crack_mesh := look.model.get_node_or_null("Crack") as MeshInstance3D
	if crack_mesh != null: crack_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("boss head: cracked")

# --- The lock's asks ---------------------------------------------------------------------

func aim_point() -> Vector3:
	return global_position+Vector3.UP*height*0.5+face_flat()*length*0.15

func lock_reach() -> Vector2:
	return REACH

func tall() -> float:
	return height*1.05

## Hit by the gust shot: it glances off (`glance`); in the absorb's tell
## or the absorb it still breaks it: the air it held bursts out harmless
## and it reels.
func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	if gone or phase1_done: return
	glance(at,strength)
	if state in ["absorb_tell","absorb"]:
		interrupts += 1
		print("boss head: gust shot broke the absorb in %s" % state)
		air.blast(mouth(),face_flat())
		_swell_want = 0.0
		draw_share = 0.0
		_reel_for = float(knobs.stagger)
		_go("stagger")
		field.sound(&"head_blast",mouth())

## Not with that: the crown's glint flares, dust puffs off it, a small
## shudder. Counts nothing.
func glance(at: Vector3, strength := 1.0) -> void:
	if gone or phase1_done: return
	glances += 1
	_lean_kick = maxf(_lean_kick,0.03*strength)
	_shake = maxf(_shake,0.012)
	if crown_glint != null and is_instance_valid(crown_glint):
		crown_glint.call("flare")
		Dust.puff(self,crown_glint.global_position,0.7,Vector3.UP)
	air.grind(at)
	field.sound(&"head_thud",at)
	print("boss head: glanced (%.2f) in %s, %d glances" % [strength,state,glances])

## The slam's push (scripts/slam.gd `blast`): on the crown a stomp; near
## it a glance.
func slam(at: Vector3, radius: float, strength: float) -> void:
	if gone or phase1_done or perch != null or swallowed: return
	if on_crown(at):
		stomp(at,strength)
		return
	var s := Slam.share(at,radius,global_position+Vector3.UP*height*0.5)
	if s > 0.0: glance(at,s*strength)

## Whether feet at `at` are on top of it (over its footprint, high up).
func on_crown(at: Vector3) -> bool:
	var flat := Vector2(at.x-global_position.x,at.z-global_position.z).length()
	if flat > maxf(width,length)*0.55: return false
	return at.y >= global_position.y+height*float(knobs.crown_up)

## A slam on its crown: the big hit. Phase 1 counts these.
func stomp(at: Vector3, strength: float) -> void:
	hits += 1
	var n := int(knobs.phase_hits)
	_squash = float(knobs.stomp_squash)*clampf(0.6+strength*0.6,0.6,1.2)
	_squash_v = 0.0
	_lean_kick = maxf(_lean_kick,0.16)
	_shake = maxf(_shake,0.06)
	_glow = 1.0
	_flap = 0.5
	# Chips off the crown, dust off its brow and down its sides.
	for i in range(4):
		var a := TAU*i/4.0+_hit_rng.randf_range(-0.4,0.4)
		var out := Vector3(cos(a),0.0,sin(a))
		Dust.rocks(self,at+out*width*0.25,out+Vector3.UP*0.8,4,0.14*height/2.6)
		Dust.puff(self,global_position+out*width*0.5+Vector3.UP*height*0.7,1.2,out)
	air.thud(rest_point()+face_flat()*width*0.45,face_flat(),1.0,width*0.9)
	field.sound(&"head_thud",at)
	field.sound(&"head_blast",mouth())
	if crown_glint != null and is_instance_valid(crown_glint): crown_glint.call("flare")
	var study: Object = field.study if field != null else null
	if study != null and study.has_method("hit_stop"): study.call("hit_stop",float(knobs.hit_stop))
	# Whatever it was on, broken off.
	puffs.stop()
	puff = ""
	_swell_want = 0.0
	draw_share = 0.0
	var v := _bounce(at)
	last_stomp = {"at":at,"strength":strength,"n":hits,"bounce":v}
	print("boss head: STOMP %d/%d (%.2f) in %s, bounced %s" % [hits,n,strength,state,v])
	stomped.emit(self,hits)
	if hits >= n:
		_cry()
		return
	_reel_for = float(knobs.stomp_reel)
	_go("stagger")

## Him thrown off the crown, clear of its edge, the way he stands from its
## middle (behind it if dead on).
func _bounce(at: Vector3) -> Vector3:
	var m: PilotMotor = field.motor
	if m == null: return Vector3.ZERO
	var out := Vector3(at.x-global_position.x,0.0,at.z-global_position.z)
	out = out.normalized() if out.length() > 0.25 else -face_flat()
	var reach := maxf(width,length)*0.5+float(knobs.bounce_out)
	var v := m.knock_velocity(Vector2(out.x,out.z),reach,float(knobs.bounce_up),height)
	m.launch(v,height+float(knobs.bounce_up))
	return v

func _cry() -> void:
	phase1_done = true
	puffs.stop()
	puff = ""
	_swell_want = 0.0
	_go("cry")
	field.sound(&"head_call",mouth())
	print("boss head: phase 1 done after %d stomps (%d glances)" % [hits,glances])
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
	# The stomp's squash springs back, overshooting a little.
	if _squash != 0.0 or _squash_v != 0.0:
		_squash_v += (-240.0*_squash-9.0*_squash_v)*delta
		_squash += _squash_v*delta
		if absf(_squash) < 0.002 and absf(_squash_v) < 0.02:
			_squash = 0.0
			_squash_v = 0.0
	if _worn_puff:
		if perch != null and is_instance_valid(perch) and not swallowed:
			_worn_frame(delta)
			return
		_end_worn()
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
			var k := clampf(state_t/_reel_for,0.0,1.0)
			# Reeling: rocked back, a wobble dying away, the jaw slack.
			want_lean = 0.1*sin(k*TAU*1.25)*(1.0-k)
			want_open = 0.45*(1.0-k)
			want_glow = 0.6*(1.0-k)+0.2
			_shake = 0.02*(1.0-k)
			_swell_want = 0.0
			if _act == "pivot": _acting(delta)
			if state_t >= _reel_for: _next_round()
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
	if _squash != 0.0:
		var q := _squash
		skin.transform.basis = skin.transform.basis*Basis.from_scale(Vector3(1.0+q*0.45,1.0-q,1.0+q*0.45))
	if swell <= 0.001: return
	var s := swell*float(knobs.swell)
	skin.transform.basis = skin.transform.basis*Basis.from_scale(Vector3(1.0+s,1.0+s*0.55,1.0+s*0.8))

## Being caught: never during its own puffs (the base's calls are off too).
func _calls(m: PilotMotor, delta: float) -> void:
	if state in MINE: return
	super._calls(m,delta)

# --- Worn: puffs from his neck (phase 2) ---------------------------------------------------
## His body (scripts/olmec_boss/boss_body.gd) asks for a puff (`worn_puff`)
## while he hunts: a short absorb on the neck ("w_absorb", WORN_ABSORB s,
## the jaw wide, dust drawn up to it, the stone swelling), the puff's own
## tell at WORN_QUICK of its length, then the puff, aimed from up there
## while he moves (the body turns it; the volley aims itself at him). A
## gust shot on him in the absorb or the tell breaks it (`break_worn`).
## Then back to "perched".

const WORN_KINDS := ["volley","whirl","breath"]
const WORN_ABSORB := 0.7
const WORN_QUICK := 0.6
## How far it pitches up on his neck (share of the lean the tells ask).
const WORN_LEAN := 0.7

var worn_puffs := 0
var worn_breaks := 0
var _worn_puff := false

## A puff from his neck: `kind` one of WORN_KINDS ("" its own pick). False
## if it can't now.
func worn_puff(kind := "") -> bool:
	if perch == null or _worn_puff or swallowed or gone: return false
	var m: PilotMotor = field.motor
	puff = kind if kind != "" else (next_puff if next_puff in WORN_KINDS else pick_worn(_chest(m)))
	next_puff = ""
	_worn_puff = true
	puffs.quick = WORN_QUICK
	if perch.get("body") != null: puffs.see_through_also(perch.body.get_rid())
	_go("w_absorb")
	absorbs += 1
	field.sound(&"head_inhale",mouth())
	print("boss head: worn puff %s (absorb)" % puff)
	return true

## Whether a worn puff is on (absorb, tell or puff).
func worn_puffing() -> bool:
	return _worn_puff

## In its absorb or tell (a hit breaks it).
func worn_winding() -> bool:
	return _worn_puff and state in ["w_absorb","puff_tell"]

## What it is on, for the card: "" none, else "<kind> absorb/tell/puff".
func worn_doing() -> String:
	if not _worn_puff: return ""
	return "%s %s" % [puff,{"w_absorb":"absorb","puff_tell":"tell","puff":"puff"}.get(state,state)]

## A hit on him in the absorb or tell: what it held bursts out harmless.
func break_worn() -> bool:
	if not worn_winding(): return false
	worn_breaks += 1
	interrupts += 1
	air.blast(mouth(),face_flat())
	field.sound(&"head_blast",mouth())
	print("boss head: worn %s broken in %s" % [puff,state])
	_end_worn()
	_flap = 0.5
	return true

func _end_worn() -> void:
	_worn_puff = false
	puff = ""
	puffs.quick = 1.0
	_swell_want = 0.0
	draw_share = 0.0
	state = "perched"
	state_t = 0.0

## Which puff from up high, by his distance; never the same three times.
func pick_worn(chest: Vector3) -> String:
	var d := Vector2(chest.x-position.x,chest.z-position.z).length()
	var w := {"volley":1.0 if d < 14.0 else 2.6,
		"breath":2.2 if d < 20.0 else 0.5,
		"whirl":1.4}
	var hist: Array = puffs.history
	if hist.size() >= 2 and hist[-1] == hist[-2] and w.has(hist[-1]): w[hist[-1]] = 0.0
	var total := 0.0
	for k: String in w: total += float(w[k])
	var r := _hit_rng.randf()*total
	for k: String in w:
		r -= float(w[k])
		if r <= 0.0: return k
	return "volley"

func _worn_frame(delta: float) -> void:
	_clock += delta
	state_t += delta
	var m: PilotMotor = field.motor
	var chest := _chest(m)
	var want_open := 0.0
	var want_draw := 0.0
	var want_lean := 0.0
	var fast := false
	match state:
		"w_absorb":
			var k := clampf(state_t/WORN_ABSORB,0.0,1.0)
			want_open = 0.85*smoothstep(0.0,0.3,k)+0.04*sin(_clock*17.0)
			want_draw = 1.0
			want_lean = 0.08*smoothstep(0.0,0.4,k)
			_shake = 0.01*k
			_swell_want = k
			puffs.absorbing(maxf(draw_share,0.6),delta)
			if state_t >= WORN_ABSORB:
				_go("puff_tell")
				puffs.tell(puff)
				field.sound(&"head_strain",mouth())
		"puff_tell":
			var span: float = puffs.tell_len(puff)
			var k := clampf(state_t/span,0.0,1.0)
			var p: Dictionary = puffs.tell_pose(puff,k,_clock)
			want_open = float(p.open)
			want_lean = float(p.lean)
			_shake = float(p.shake)*1.4
			_swell_want = 1.0+float(p.swell)
			_roll = float(p.get("roll",0.0))
			if state_t >= span:
				_roll = 0.0
				_go("puff")
				puffs.release(puff,chest)
				worn_puffs += 1
				puffed.emit(puff)
		"puff":
			fast = true
			var p: Dictionary = puffs.puff_pose(puff,state_t,_clock)
			want_open = float(p.open)
			want_lean = float(p.lean)
			_shake = float(p.shake)
			_swell_want = maxf(0.0,1.0-state_t/maxf(puffs.puff_len(puff),0.1))
			if state_t >= puffs.puff_len(puff):
				_end_worn()
		_:
			_end_worn()
	_flap = maxf(0.0,_flap-delta)
	_open = move_toward(_open,want_open,(9.0 if fast else 4.0)*delta)
	_glow = move_toward(_glow,1.0,2.0*delta)
	_lean = lerpf(_lean,want_lean*WORN_LEAN,1.0-exp(-(14.0 if fast else 6.0)*delta))
	_lean_kick = move_toward(_lean_kick,0.0,delta*0.5)
	look.open(_open)
	look.glow(_glow)
	swell = move_toward(swell,_swell_want,delta*(1.6 if _swell_want > swell else 2.5))
	draw_share = move_toward(draw_share,want_draw,(4.0 if want_draw > draw_share else 3.0)*delta)
	air.draw(draw_share,delta)
	puffs.step(delta)

var _roll := 0.0

## On his neck the turf is under his feet, not under its chin: looked for
## from his feet's height, through his body.
func ground_at(p: Vector3) -> float:
	if perch == null or not is_instance_valid(perch): return super.ground_at(p)
	return field.floor_under(Vector3(p.x,perch.position.y,p.z),6.0,12.0,perch.body.get_rid())

func rest_point() -> Vector3:
	if perch == null or not is_instance_valid(perch): return super.rest_point()
	return Vector3(position.x,perch.position.y,position.z)

## On his neck: the perch's pose, and over it (worn puffing) the tell's
## pitch and roll, a tremble and the swell.
func _move(delta: float) -> void:
	super._move(delta)
	if perch == null: return
	if not _worn_puff:
		_lean = move_toward(_lean,0.0,delta*0.5)
		swell = move_toward(swell,0.0,delta*2.0)
		if absf(_lean) < 0.001 and swell < 0.001: return
	var b := skin.transform.basis
	b = b*Basis(Vector3.RIGHT,_lean+_lean_kick)*Basis(Vector3.FORWARD,_roll)
	var s := swell*float(knobs.swell)
	if s > 0.001: b = b*Basis.from_scale(Vector3(1.0+s,1.0+s*0.55,1.0+s*0.8))
	var shake := Vector3.ZERO
	if _shake > 0.0: shake = Vector3(sin(_clock*53.0),sin(_clock*47.0+1.0),sin(_clock*59.0+2.0))*_shake*height
	skin.transform = Transform3D(b,skin.transform.origin+shake)
