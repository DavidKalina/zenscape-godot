extends "res://scripts/lock_on/olmec_target.gd"
## The Olmec boss's body (docs/design/olmec-boss/spec-olmec-boss.md, phase
## 2): the lock-on Olmec (scripts/lock_on/olmec_target.gd) the Olmec field
## brings up the rim for its head. Till his head is on he is the plain
## target body (climbing, crossing, reaching). Whole (`phase_two`, the
## field calls it), he hunts the wanderer and is much more dangerous:
##   - quicker: he runs harder (PHASE2 knobs), turns sharper, swats and
##     pounces sooner;
##   - the bound: from BOUND_NEAR..BOUND_FAR m off, a deep crouch aimed at
##     him (BOUND_WINDUP s, locked the last pounce_lock s), then a leap
##     across the field onto where he stands; it comes down with a big
##     shockwave (BOUND_SHOCK) that throws him unless he is off the ground;
##   - the slam: from SLAM_NEAR..SLAM_FAR m (out of his swat's reach), both
##     fists high (SLAM_WINDUP s, turned to him), then down on the turf in
##     front of him: a shockwave (SLAM_SHOCK) rolls out; jump it. A gust
##     shot in the windup stops it;
##   - the charge: from CHARGE_NEAR..CHARGE_FAR m, a tell (planted, the
##     shoulder dropped, the back foot scraping dust twice, a held beat:
##     "charge_tell"), then he barrels at him shoulder first, fast
##     (CHARGE_RUN x the walker's run), steering only a little and not at
##     all the last CHARGE_LOCK m ("charge"), smashing the arena pieces in
##     his path. Caught, the wanderer is thrown hard (CHARGE_THROW). A late
##     sidestep beats it: he overruns, skids and stumbles to a stop, a hand
##     on the turf ("charge_skid", the window to shoot him). A big piece
##     (arena.gd BIG) or the rim's edge ahead: he stops short with a
##     stagger ("charge_stagger");
##   - the swat as before, quicker.
##   - the tilt (the set piece, spec "The tilt"): first at TILT_AT_HITS
##     hits, again no sooner than TILT_REST s after, he makes for the rim
##     (the field's `tilt_spot`: never over the plane's run), running
##     ("tilt_run") till a bound reaches it, bounds there (a "jump"), turns
##     in, both fists up and down on the rim ("tilt_slam"), and stays
##     braced on it, fists on the turf, leaning his weight on it
##     ("tilt_brace"): the field (`tilt_begin`) tips steeply toward him and
##     the wanderer slides down to him. Braced, he sends volleys of air
##     arcs up the slope at him (the field's `tilt_arcs`: ARC_FIRST s in,
##     then every ARC_EVERY s, ARC_N at a time). TILT_BREAK gust shots
##     into him braced break his brace (the field's `tilt_broken`). The
##     brace broken (or his TILT_HOLD up), the field drops him
##     (`tilt_drop`): he staggers back off the rim ("tilt_off", the
##     charge's stagger), falls out of sight ("tilt_gone", hidden under the
##     rim) and, the field level again, climbs back up a crag as in his
##     arrival (the field's `climb_back`: "climb", "mantle", then the hunt).
##     Let go any other way (`tilt_let_go`) he stands up off it
##     ("tilt_let") and hunts again;
## His fists, landings and slams hit the arena (scripts/olmec_boss/arena.gd
## `hit_at`), and his shockwaves break what they pass as they always have
## (the hub is his breaker). `move` names the attack he is on ("" none),
## for the card.
##
## Phase 2's weak spot is his back (spec-olmec-knockoff.md, phase 2): only
## the side slam (scripts/side_slam.gd, its `slam` to the slam's group, the
## wanderer in its "lunge") from behind him (within BACK_ARC of dead
## behind) counts (`back_hit`): a hit-stop, chips off his back, a lurch
## forward ("back_hit", BACK_STAGGER s) and a shove BACK_SHOVE m the way he
## faces (stopped at the field's edge). From the front or side, and every
## gust shot, it only glances (`glance`): the glint on his back flares,
## dust puffs, a small rock. With the rim near ahead a back hit sends him
## to it, teetering; another takes him over (the edge, below: EDGE_NEAR);
## away from it a back hit only cracks him. KNOCK_OFFS knock-offs end him.
## The ground pound plays no part. The tilt is out of
## his mix unless the field asks for it (its `tilt_mix`, `--tilt`).

const Slam = preload("res://scripts/slam.gd")
const Glint = preload("res://scripts/kit_isle/kit_cache_glint.gd")
## The back hit: how far behind him the wanderer must be (cos off dead
## behind: 0.45 ~ 63 deg either side), the shove (m, the way he faces),
## the lurch (s), the hit-stop (s, real), how near his middle a side slam
## must land to be his (m past his half width).
const BACK_ARC := 0.45
const BACK_SHOVE := 3.5
const BACK_STAGGER := 1.5
const BACK_HIT_STOP := 0.13
const BACK_NEAR := 1.6
## The edge (spec "The edge"): a back hit with the rim within EDGE_NEAR m
## past the shove (m from his front) sends him to it, teetering
## ("teeter", TEETER_HOLD s, windmilling over it). Another back slam in it
## takes him over; so does a back hit with his front already within
## TEETER_TIP m of the drop (hit right at the rim). Else he steps back off it
## (TEETER_BACK m) and turns on you. Over ("knock_off"): tipping forward
## and down (KNOCK_OUT m/s out, KNOCK_UP up), out of sight
## ("knocked_gone", KNOCK_GONE s), then a leap back up over the rim
## ("leap_back": from KNOCK_BELOW m under it, LEAP_OVER m over it at the
## top, landing LEAP_IN m in) and a heavy landing (KNOCK_SHOCK): jump it.
## Each knock-off he comes back angrier (ANGER per knock-off on his chase,
## swat and charge rests). KNOCK_OFFS of them end him (a crumble on the
## landing, a stand-in for the finish's rune).
const EDGE_NEAR := 2.5
const TEETER_HOLD := 2.4
const TEETER_TIP := 1.0
const TEETER_BACK := 1.4
const KNOCK_OUT := 2.6
const KNOCK_UP := 1.5
const KNOCK_GONE := 1.8
const KNOCK_BELOW := 9.0
const LEAP_OVER := 5.0
const LEAP_IN := 6.5
const KNOCK_SHOCK := 1.7
const KNOCK_OFFS := 3
const ANGER := 0.1
## The art lane's knock-off clips (headless_body_build.py, its knock-off
## section): the edge clips pivot at his toes TOES m (model, times the
## look's k) ahead of his root, so the teeter stands him that far back from
## the rim; the topple's node drop from TOPPLE_GO s (past 45 deg); the
## back-hit clip's lurch from BACK_LURCH s (the rest of the shove then);
## the heavy landing's fists in the ground at RIM_SLAM s (the shockwave).
const TOES := 0.85
const TOPPLE_GO := 0.75
const BACK_LURCH := 0.27
const RIM_SLAM := 0.07
## Slammed over in the teeter, the topple from here (s): the held "uh-oh"
## is for losing it on his own.
const TOPPLE_SLAMMED := 0.3
## States he is off the field in (nothing hits him there; he moves himself).
const OVER := ["knock_off","knocked_gone","leap_back"]
var _shove_due := Vector3.ZERO
var _teeter_to := Vector3.ZERO
var _topple_from := 0.0
var _fell := false
var _leap_t := 1.0
var _rim_shocked := false
var knock_offs := 0
var cracks := 0
var teeters := 0
var last_edge := {}
var _to_edge := false
var _teeter_over := false
var _rim_at := Vector3.ZERO
var _rim_out := Vector3.ZERO
var _leap_v := Vector3.ZERO
var _up_to := Vector3.ZERO
## Phase 2's knobs over the body's own (scaled by the field's numbers in
## `phase_two`: speeds by the walker's run).
const PHASE2 := {"chase_turn":2.8,"accel":5.5,"swat_windup":0.42,"swat_after":0.5,
	"pounce_windup":0.6,"pounce_rest":2.0,"land":0.7,"suck_rest":10.0}
## His hunt's pace: this times the walker's run.
const CHASE_RUN := 1.12
## The bound: its reach (m off him), its crouch (s), its rest (s), the
## shock it lands with (1 a leap's landing).
const BOUND_NEAR := 13.0
const BOUND_FAR := 32.0
const BOUND_WINDUP := 0.95
const BOUND_REST := 6.0
const BOUND_SHOCK := 1.5
## The slam: its reach (m off him), the fists up (s), after (s), its rest
## (s), the shock (1 a leap's landing) and how far ahead his fists land
## (share of the way to him, at most SLAM_AHEAD m).
const SLAM_NEAR := 5.5
const SLAM_FAR := 15.0
const SLAM_WINDUP := 0.85
const SLAM_AFTER := 0.75
const SLAM_REST := 4.5
const SLAM_SHOCK := 1.25
const SLAM_AHEAD := 4.0
## What his blows do to the arena: [radius (m), strength] (columns are
## tough 0.5, walls, gate and stones 0.6).
const FIST_HIT := [2.5,0.7]
const SLAM_HIT := [4.0,1.0]
const LAND_HIT := [4.5,1.0]
## The charge: its reach (m off him), its rest (s), the first after the
## triumph (s), its pace (x the walker's run) and how quickly he gets up to
## it (m/s²), his steering (rad/s) and the last stretch he no longer
## steers (m), its longest run (s), what a catch throws (x the swat's out
## and up, and the time laid down), his breaking ahead ([radius, strength],
## looked CHARGE_SMASH_AHEAD s ahead) and the clips' beats (the build's).
const CHARGE_NEAR := 9.0
const CHARGE_FAR := 26.0
const CHARGE_REST := 7.0
const CHARGE_FIRST := 4.0
const CHARGE_RUN := 2.0
const CHARGE_ACCEL := 22.0
const CHARGE_TURN := 0.55
const CHARGE_LOCK := 10.0
const CHARGE_MOST := 2.8
const CHARGE_THROW := [1.7,1.4,1.25]
const CHARGE_HIT := [3.2,1.0]
## How far past his shoulder's side a catch still reaches (m), and how
## long he carries on past a catch before he digs in (s).
const CHARGE_SIDE := -0.4
const CHARGE_CARRY := 0.3
const CHARGE_SMASH_AHEAD := 0.3
const CHARGE_TELL := 1.25
const CHARGE_SCRAPES := [0.6,0.84]
const CHARGE_SLIDE := 0.62
const CHARGE_SKID := 2.3
const CHARGE_STAGGER := 1.7

## Puffs from up high (his head's, scripts/olmec_boss/boss_head.gd
## `worn_puff`): his reach (m off him), the rest between (s), the first
## after the triumph (s), and his pace while his head winds up and lets go
## (share of his hunt's).
const PUFF_NEAR := 11.0
const PUFF_FAR := 34.0
const PUFF_REST := 5.0
const PUFF_FIRST := 3.5
const PUFF_PACE := 0.55

var phase2 := false
## Back hits (they bring him down), glances (count nothing), the last back
## hit ({at, behind, shove}), the glint on his back.
var back_hits := 0
var glances := 0
var last_back := {}
var back_glint: Sprite3D = null
var _slam_frame := -1
var _back_from := Vector3.ZERO
## The attack he is on now ("bound", "slam", "swat", "pounce", "suck"; ""
## none), and counts for checks.
var move := ""
var bounds := 0
var slams := 0
var slam_shocks := 0
var _bound := false
var _slam := false
var _slam_hit := false
var _bound_ready := 0.0
var _slam_ready := 0.0
var _swat_knobs := []
var _pounce_shock := 0.0
var _puff_ready := 0.0
var _hunt_pace := 0.0
var puffs_asked := 0
## The charge: counts for checks (charges, caught, overrun, stopped short
## and why), its ready time, its way (rad) and the pace it ended at.
var charges := 0
var charge_hits := 0
var charge_overruns := 0
var charge_stops := 0
var charge_stop_why := ""
var _charge_ready := 0.0
var _charge_way := 0.0
var _charge_v := 0.0
var _charge_smash_t := 0.0
var _scraped := 0
var _charge_caught := -1.0

## Whole: the boss's moveset on, his hits counted afresh.
## The tilt: first at this many hits (phase 2), then no sooner than
## TILT_REST s after the last; a bound reaches the rim from TILT_LEAP m at
## most (else he runs nearer first); the slam's windup and its fists down
## (s), the beat after the field let him go (s).
const TILT_AT_HITS := 3
const TILT_REST := 40.0
const TILT_LEAP := 28.0
const TILT_WINDUP := 0.9
const TILT_LET := 1.4
var tilts := 0
var _tilt_ready := INF
var _tilt_step := ""
var _tilt_at := Vector3.INF
## Where he braces (the field at rest: the field's tilt turns it).
var tilt_rest := Vector3.INF
var _tilt_hit := false
## Braced: his air arcs (the first after ARC_FIRST s, then every ARC_EVERY
## s, ARC_N a volley, a heave of his weight as each goes) and the shots
## that break his brace (TILT_BREAK; `brace_hits` so far this brace).
const ARC_FIRST := 1.4
const ARC_EVERY := 1.8
const ARC_N := 3
const TILT_BREAK := 3
var brace_hits := 0
var volleys := 0
var brace_broken := false
var _arc_next := 0.0
## Dropped off the rim (`tilt_drop`): his stagger back (s, m/s out), his
## fall (m/s² down, m/s out), how far under his brace he is out of sight
## (m) and the least time (s) he is gone before the climb back.
const OFF_STAGGER := 0.85
const OFF_BACK := 3.4
const OFF_GRAVITY := 24.0
const OFF_OUT := 3.0
const OFF_DEEP := 16.0
const OFF_GONE := 2.2
var _off_rest := Vector3.INF
var _off_v := Vector3.ZERO
var drops := 0
var climbs_back := 0

func phase_two() -> void:
	if phase2: return
	phase2 = true
	hits = 0
	back_hits = 0
	glances = 0
	knock_offs = 0
	cracks = 0
	teeters = 0
	# Knock-offs end him, not hits.
	most_hits = 1000000
	add_to_group(Slam.GROUP)
	_make_back_glint()
	knobs.merge(PHASE2,true)
	var run: float = field.motor.run
	knobs.chase_speed = run*CHASE_RUN
	knobs.relentless = 1
	knobs.chase = 1
	# He hunts shoulder first (the "shoulder_run" clip), no arms out.
	run_clip = "shoulder_run"
	# A beat after the triumph before the big moves.
	_bound_ready = _clock+2.0
	_slam_ready = _clock+1.0
	_puff_ready = _clock+PUFF_FIRST
	_charge_ready = _clock+CHARGE_FIRST
	_hunt_pace = float(knobs.chase_speed)
	print("olmec boss: phase 2, chase %.1f m/s (walker run %.1f), hh %.2f, neck %.2f, width %.2f, length %.2f" % [float(knobs.chase_speed),run,hh,neck_h,width,length])

func _arena() -> Node:
	if field == null or field.study == null: return null
	return field.study.get("arena")

func _hit_arena(at: Vector3, what: Array) -> void:
	var a := _arena()
	if a != null: a.hit_at(at,float(what[0]),float(what[1]))

## Phase 2's picks first (the slam and the bound), then the body's own
## (the swat, the pounce, the suck).
func _attack(m: PilotMotor, flat: float, dy: float) -> bool:
	if not phase2: return super._attack(m,flat,dy)
	if m.seized(): return false
	# Laid down by a blow, he gets up before the next comes (no stun lock):
	# the Olmec closes in meanwhile.
	if m.move == "tumble": return false
	# His head puffing: he comes on, slower, and only swats.
	if _head_puffing():
		if flat <= float(knobs.catch_reach)*hh and absf(dy) < neck_h*0.6: return super._attack(m,flat,dy)
		return false
	if _tilt_due():
		tilt_now()
		return true
	var level := absf(dy) < neck_h*0.6
	if level and flat >= CHARGE_NEAR and flat <= CHARGE_FAR and _clock >= _charge_ready:
		_start_charge()
		return true
	if level and flat >= SLAM_NEAR and flat <= SLAM_FAR and _clock >= _slam_ready:
		_start_slam()
		return true
	# From up high his head puffs at him as he comes on (before a bound:
	# the bound comes ready again meanwhile, so they take turns).
	if flat >= PUFF_NEAR and flat <= PUFF_FAR and _clock >= _puff_ready and _puff_try(): return false
	if flat >= BOUND_NEAR and flat <= BOUND_FAR and _clock >= _bound_ready and dy <= float(knobs.pounce_rise)*hh and dy >= -float(knobs.pounce_sink)*hh:
		var at := _pounce_spot(m)
		if at != Vector3.INF and _arc_clear(at,"pounce"):
			_bound = true
			bounds += 1
			move = "bound"
			_bound_ready = _clock+BOUND_REST
			_up_to = at
			leap_kind = "pounce"
			_go("windup")
			field.sound(&"body_windup",position)
			chase_beat.emit("bound")
			print("olmec boss: bound from %.1f m" % flat)
			return true
		_bound_ready = _clock+0.5
	var went := super._attack(m,flat,dy)
	if went: move = {"swat":"swat","windup":"pounce","plant":"suck"}.get(state,"")
	return went

func _boss_head() -> Node:
	if head == null or not is_instance_valid(head) or head.get("perch") != self or not head.has_method("worn_puff"): return null
	return head

func _head_puffing() -> bool:
	var h := _boss_head()
	return h != null and h.worn_puffing()

## His head puffs at him from up high, as he comes on.
func _puff_try() -> bool:
	var h := _boss_head()
	if h == null or not h.worn_puff(): return false
	_puff_ready = _clock+PUFF_REST
	puffs_asked += 1
	knobs.chase_speed = _hunt_pace*PUFF_PACE
	chase_beat.emit("puff")
	return true

func think(delta: float) -> void:
	super.think(delta)
	if not phase2: return
	var h := _boss_head()
	var doing: String = h.worn_doing() if h != null else ""
	if doing != "":
		if move == "" or move.begins_with("puff"): move = "puff "+doing
	else:
		if move.begins_with("puff"): move = ""
		if _hunt_pace > 0.0: knobs.chase_speed = _hunt_pace

## Braced on the rim, tipping the field: the lock takes him from anywhere
## on it (scripts/lock_on/foot_lock.gd), and the gust shot reaches him.
func lock_anywhere() -> bool:
	return phase2 and not crumbled and state == "tilt_brace" and not brace_broken

## A gust shot in his head's absorb or tell breaks the puff. Whole, a hit
## only glances (the side slam's own `hit`, after its `slam`, is passed over).
func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	# Off the rim and out of sight: nothing to hit.
	if state in ["tilt_off","tilt_gone"] or state in OVER: return
	if phase2 and _slam_frame == Engine.get_physics_frames(): return
	if phase2 and not crumbled and state == "tilt_brace":
		brace_hits += 1
		glance(at,strength)
		print("olmec boss: shot braced, %d/%d" % [brace_hits,TILT_BREAK])
		if brace_hits >= TILT_BREAK and not brace_broken and not crumbled:
			brace_broken = true
			var st: Node = field.study if field != null else null
			if st != null and st.has_method("tilt_broken"): st.tilt_broken(self)
		return
	if phase2 and not crumbled:
		var h := _boss_head()
		if h != null and h.break_worn(): _puff_ready = maxf(_puff_ready,_clock+PUFF_REST*0.5)
		glance(at,strength,way)
		return
	super.hit(at,way,strength)

# --- His back -------------------------------------------------------------------

## The weak spot's tell: one faint point between his shoulder blades.
func _make_back_glint() -> void:
	if back_glint != null and is_instance_valid(back_glint): return
	var g: Sprite3D = (load("res://scripts/kit_isle/kit_cache_glint.gd") as GDScript).new()
	g.name = "BackGlint"
	g.set_instance_shader_parameter("tint",Color(1.0,0.93,0.7))
	g.rng.seed = 5113
	g.wait = 1.5
	add_child(g)
	back_glint = g
	_place_back_glint()

## On his back, at his chest's height (the chest bone, as it moves).
func _back_spot() -> Vector3:
	var up := global_position+Vector3.UP*(legs_h+torso_h*0.6)
	if look != null and look.skeleton != null:
		var b := look.skeleton.find_bone("chest")
		if b >= 0: up = look.skeleton.global_transform*look.skeleton.get_bone_global_pose(b).origin
	return up-_forward3()*(length*0.5+0.12)

func _place_back_glint() -> void:
	if back_glint == null or not is_instance_valid(back_glint) or not is_inside_tree(): return
	back_glint.global_position = _back_spot()

func step(delta: float) -> void:
	super.step(delta)
	if phase2 and not crumbled: _place_back_glint()
	if not _arm_rubble.is_empty() and _arm_rubble_t < ARM_SETTLE:
		_arm_rubble_t += delta
		if _arm_rubble_t >= ARM_SETTLE:
			for rb: RigidBody3D in _arm_rubble:
				if is_instance_valid(rb): rb.freeze = true

## The slam's group (scripts/slam.gd, side_slam.gd): the side slam (him in
## its lunge) from behind is a back hit, else it glances; the ground pound
## plays no part in phase 2.
func slam(at: Vector3, radius: float, strength: float) -> void:
	if not phase2 or crumbled or gone or state.begins_with("tilt") or state in OVER: return
	var m: PilotMotor = field.motor
	if m == null or str(m.move) != "lunge": return
	var flat := Vector2(at.x-position.x,at.z-position.z).length()
	if flat > maxf(width,length)*0.5+radius+BACK_NEAR: return
	_slam_frame = Engine.get_physics_frames()
	var d := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	var behind := -d.normalized().dot(PilotMotor.forward(facing)) if d.length() > 0.05 else 0.0
	if behind >= BACK_ARC: back_hit(at,behind,strength)
	else:
		print("olmec boss: side slam glanced (behind %.2f)" % behind)
		glance(at,strength,Vector3(-d.x,0.0,-d.y))

## Not with that: the glint on his back flares, dust puffs where it struck,
## a small rock away from it. Counts nothing.
func glance(at: Vector3, strength := 1.0, way := Vector3.ZERO) -> void:
	glances += 1
	if back_glint != null and is_instance_valid(back_glint): back_glint.call("flare")
	Dust.puff(field,at,0.8,Vector3.UP)
	var flat := Vector3(way.x,0.0,way.z)
	if flat.length() > 0.01:
		var axis_local := (global_transform.basis.inverse()*Vector3.UP.cross(flat.normalized())).normalized()
		if absf(_tip) < 0.001: _tip_axis = axis_local
		_tip_v += KICK*0.25*clampf(strength,0.0,1.0)*signf(_tip_axis.dot(axis_local)+0.001)
	quake = maxf(quake,0.15)
	field.sound(&"body_step",at)
	print("olmec boss: glanced (%.2f) in %s, %d glances" % [strength,state,glances])

## The side slam in his back: the big read, a lurch forward and a shove
## the way he faces. Teetering at the rim, it takes him over; with the rim
## near ahead, it sends him to it (the teeter); else it only cracks him.
func back_hit(at: Vector3, behind := 1.0, strength := 1.0) -> void:
	back_hits += 1
	var fwd := _forward3()
	if state == "teeter":
		print("olmec boss: BACK HIT %d in the teeter: over he goes" % back_hits)
		var st0: Node = field.study if field != null else null
		if st0 != null and st0.has_method("hit_stop"): st0.call("hit_stop",BACK_HIT_STOP)
		if back_glint != null and is_instance_valid(back_glint): back_glint.call("flare")
		for i in range(3):
			var o := (-fwd+_right3()*float(i-1)*0.7+Vector3.UP*0.9).normalized()
			Dust.rocks(field,at+o*0.3,o,4,0.16*hh)
		field.sound(&"body_rumble",at)
		last_edge["how"] = "slammed"
		knock_off(TOPPLE_SLAMMED)
		return
	var rim := _rim_ahead(fwd,BACK_SHOVE+length*0.5+EDGE_NEAR+1.0)
	_to_edge = rim-length*0.5 <= BACK_SHOVE+EDGE_NEAR
	_teeter_over = rim-length*0.5 <= TEETER_TIP
	if not _to_edge: cracks += 1
	last_back = {"at":at,"behind":behind,"n":back_hits,"from":position}
	_back_from = position
	var st: Node = field.study if field != null else null
	if st != null and st.has_method("hit_stop"): st.call("hit_stop",BACK_HIT_STOP)
	if back_glint != null and is_instance_valid(back_glint): back_glint.call("flare")
	# Chips off his back, dust round his feet.
	for i in range(3):
		var out := (-fwd+_right3()*float(i-1)*0.7+Vector3.UP*0.9).normalized()
		Dust.rocks(field,at+out*0.3,out,4,0.16*hh)
	_puff(position+fwd*length*0.4,hh*1.4)
	field.sound(&"body_rumble",at)
	# The rock, the push (the target's hit: counts it, may bring him down),
	# then the rest of the shove.
	super.hit(at,fwd,strength)
	print("olmec boss: BACK HIT %d (behind %.2f) at (%.1f, %.1f), his front %.1f m from the drop: %s" % [back_hits,behind,position.x,position.z,rim-length*0.5,"to the edge" if _to_edge else "cracked"])
	if crumbled: return
	# The rest of the shove comes with the clip's lurch (BACK_LURCH s in).
	_shove_due = fwd*maxf(BACK_SHOVE-PUSH*strength,0.0)/PUSH_EASE
	quake = maxf(quake,0.9)
	move = ""
	_end_slam()
	_go("back_hit")
	chase_beat.emit("back hit")

## Lurched forward off the blow, stumbling, a hand down; then he turns on
## him. The shove stops at the field's edge.
func _back_lurch(delta: float) -> void:
	vel.x = 0.0
	vel.z = 0.0
	if state_t >= BACK_LURCH and _shove_due != Vector3.ZERO:
		_push += _shove_due
		_shove_due = Vector3.ZERO
	if _push.length() > 0.01:
		var ahead := position+_push.normalized()*(length*0.5+0.4)
		if _floor(ahead+Vector3.UP*1.0,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF:
			var left := (_push.length()+_shove_due.length())*PUSH_EASE
			_push = Vector3.ZERO
			_shove_due = Vector3.ZERO
			print("olmec boss: shove stopped at the edge, %.1f m of it left" % left)
			if _to_edge:
				_teeter(_teeter_over)
				return
	if state_t < 0.5 and fmod(state_t,0.1) < delta: _puff(position+_forward3()*(length*0.3),hh*0.6)
	if state_t >= BACK_STAGGER:
		last_back["shove"] = Vector2(position.x-_back_from.x,position.z-_back_from.z).length()
		print("olmec boss: shoved %.1f m" % float(last_back.shove))
		move = ""
		# Sent for the edge but stopped short of it: still at the rim, he teeters.
		if _to_edge and _rim_ahead(_forward3(),length*0.5+EDGE_NEAR) <= length*0.5+EDGE_NEAR*0.6:
			_teeter(_teeter_over)
			return
		_go(_resume())

# --- The edge -------------------------------------------------------------------

## How far (m, from his middle) the field runs on the way `way` (flat)
## before the floor gives out; `most` if it doesn't within it.
func _rim_ahead(way: Vector3, most: float) -> float:
	var w := Vector3(way.x,0.0,way.z).normalized()
	var d := 0.5
	while d <= most:
		if _floor(position+w*d+Vector3.UP*1.0,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: return d
		d += 0.4
	return most

## At the rim, onto his toes, windmilling: a held window ("teeter_catch"
## into the "teeter" loop). Stood with his toes on the rim (TOES ahead of
## his root, the clips' pivot). `over`: he won't get it back (he goes over
## at its end).
func _teeter(over: bool) -> void:
	teeters += 1
	_teeter_over = over
	last_edge = {"n":teeters,"over":over,"at":position,"how":""}
	move = ""
	_push = Vector3.ZERO
	_shove_due = Vector3.ZERO
	skin.transform = Transform3D.IDENTITY
	var fwd := _forward3()
	_teeter_to = position+fwd*(_rim_exact(fwd)-TOES*look.k)
	_teeter_to.y = position.y
	_go("teeter")
	field.sound(&"body_windup",position)
	quake = maxf(quake,0.4)
	chase_beat.emit("teeter")
	print("olmec boss: teetering at the rim (%.1f, %.1f), toes %.2f m to it%s" % [position.x,position.z,(_teeter_to-position).length(),", he won't get it back" if over else ""])

## The rim the way `way` (m from his middle), to a few cm.
func _rim_exact(way: Vector3) -> float:
	var far := _rim_ahead(way,length*0.5+EDGE_NEAR+BACK_SHOVE+1.0)
	var near := maxf(far-0.4,0.0)
	var w := Vector3(way.x,0.0,way.z).normalized()
	for i in range(6):
		var mid := (near+far)*0.5
		if _floor(position+w*mid+Vector3.UP*1.0,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: far = mid
		else: near = mid
	return (near+far)*0.5

## The window's end: TEETER_HOLD at least, cut over at the loop's start
## (the topple and the step back both start from the teeter's time 0).
func _teeter_end() -> float:
	var catch := float(look.lengths.teeter_catch)
	var loop := float(look.lengths.teeter)
	return catch+ceilf(maxf(TEETER_HOLD-catch,0.0)/loop)*loop

func _teeter_think(delta: float) -> void:
	vel.x = 0.0
	vel.z = 0.0
	# Thrown onto his toes at the lip: the last of the way there.
	position = position.lerp(Vector3(_teeter_to.x,position.y,_teeter_to.z),1.0-exp(-12.0*delta))
	if fmod(state_t,0.35) < delta: Dust.rocks(field,_teeter_to+_forward3()*(TOES*look.k)+Vector3.UP*0.1,_forward3()+Vector3.DOWN,2,0.08*hh)
	if state_t < _teeter_end(): return
	if _teeter_over:
		last_edge["how"] = "lost it"
		knock_off()
		return
	# Got it back: rocked back onto his heels, a step back, then on you.
	last_edge["how"] = "recovered"
	print("olmec boss: got his balance back")
	_go("teeter_back")

## Rocked back off the rim: the step back with the clip, then he turns on you.
func _teeter_back(delta: float) -> void:
	vel.x = 0.0
	vel.z = 0.0
	var clip := float(look.lengths.teeter_back)
	var was := clampf((state_t-delta)/clip,0.0,1.0)
	var now := clampf(state_t/clip,0.0,1.0)
	# The step back mid-clip (0.35..0.7 of it), smooth.
	var k0 := smoothstep(0.35,0.7,was)
	var k1 := smoothstep(0.35,0.7,now)
	position -= _forward3()*TEETER_BACK*(k1-k0)
	if state_t >= clip: _go(_resume())

## Over the rim: the topple, pivoting at his toes on the lip, then down
## past TOPPLE_GO, out of sight. `from`: where in the topple he starts.
func knock_off(from := 0.0) -> void:
	knock_offs += 1
	_rim_at = position
	_rim_out = _forward3()
	_topple_from = from
	_fell = false
	_push = Vector3.ZERO
	_shove_due = Vector3.ZERO
	skin.transform = Transform3D.IDENTITY
	move = ""
	_end_slam()
	_go("knock_off")
	field.sound(&"body_windup",position)
	quake = maxf(quake,0.7)
	chase_beat.emit("knocked off")
	print("olmec boss: KNOCKED OFF %d/%d at (%.1f, %.1f)" % [knock_offs,KNOCK_OFFS,position.x,position.z])

func _knock_fall(delta: float) -> void:
	vel = Vector3.ZERO
	if not _fell:
		# Tipping on his toes at the lip: the clip does it, he stays put.
		if state_t+_topple_from < TOPPLE_GO: return
		_fell = true
		grounded = false
		_off_v = _rim_out*KNOCK_OUT+Vector3.UP*KNOCK_UP
		Dust.rocks(field,_rim_at+_rim_out*(TOES*look.k)+Vector3.UP*0.1,_rim_out+Vector3.DOWN,6,0.14*hh)
	_off_v.y -= OFF_GRAVITY*delta
	position += _off_v*delta
	if _rim_at.y-position.y >= OFF_DEEP:
		_shown(false)
		_go("knocked_gone")

## Under the rim a beat, then up: from below it, out from where he went
## off, a leap over it onto the field.
func _knocked_gone(_delta: float) -> void:
	vel = Vector3.ZERO
	# Out of sight, the first knock-off's crack (he comes back up with it).
	if knock_offs >= 1 and damage < 1: take_damage(1)
	if state_t < KNOCK_GONE: return
	var from := _rim_at+_rim_out*2.0+Vector3.DOWN*KNOCK_BELOW
	var to := _rim_at-_rim_out*LEAP_IN
	var g := _floor(to+Vector3.UP*3.0,6.0,8.0)
	to.y = g if g != -INF else _rim_at.y
	var top := maxf(_rim_at.y,to.y)+LEAP_OVER
	var vy := sqrt(2.0*OFF_GRAVITY*(top-from.y))
	var t := vy/OFF_GRAVITY+sqrt(2.0*(top-to.y)/OFF_GRAVITY)
	_leap_v = Vector3((to.x-from.x)/t,vy,(to.z-from.z)/t)
	_leap_t = t
	_up_to = to
	position = from
	facing = PilotMotor.facing_of(Vector2(-_rim_out.x,-_rim_out.z))
	rotation.y = facing
	_shown(true)
	_go("leap_back")
	field.sound(&"body_windup",_rim_at)
	print("olmec boss: leaps back up for (%.1f, %.1f)" % [to.x,to.z])

func _leap_back(delta: float) -> void:
	vel = Vector3.ZERO
	_leap_v.y -= OFF_GRAVITY*delta
	position += _leap_v*delta
	if _leap_v.y < 0.0 and position.y <= _up_to.y:
		position = _up_to
		_heavy_land()

## Down heavy, back on the field ("rim_land"): squashed, fists in the
## ground (the big shockwave to jump, RIM_SLAM s in), the roar, angrier.
func _heavy_land() -> void:
	grounded = true
	vel = Vector3.ZERO
	_rim_shocked = false
	_go("rim_land")
	_puff(position,hh*2.6)
	Dust.plume(field,position,hh*4.0)
	field.sound(&"body_land",position)
	quake = 1.0
	last_edge["back"] = position
	print("olmec boss: back up, landed heavy at (%.1f, %.1f), knock-offs %d" % [position.x,position.z,knock_offs])

func _rim_land(_delta: float) -> void:
	vel.x = 0.0
	vel.z = 0.0
	if not _rim_shocked and state_t >= RIM_SLAM:
		_rim_shocked = true
		field.sound(&"body_rumble",position)
		_shock(position,KNOCK_SHOCK)
		_hit_arena(position,LAND_HIT)
		weighed.emit(position,KNOCK_SHOCK,"land")
		quake = 1.0
		if knock_offs >= KNOCK_OFFS:
			# The finish's stand-in: he crumbles at the top of the rim.
			crumble()
			return
		# The second knock-off's landing snaps his arm off.
		if knock_offs >= 2 and not arm_off: take_damage(2)
		_angrier()
	if state_t >= float(look.lengths.rim_land): _go(_resume())

## Each knock-off: hunts harder, swats sooner, charges again sooner.
func _angrier() -> void:
	var k := 1.0+ANGER
	_hunt_pace *= k
	knobs.chase_speed = _hunt_pace
	knobs.swat_windup = float(knobs.swat_windup)/k
	_charge_ready = minf(_charge_ready,_clock+CHARGE_FIRST)

# --- Coming back cracked ---------------------------------------------------------
# Each knock-off leaves him worse (spec-olmec-knockoff.md "Coming back
# cracked"): after the first his face is cracked and off-kilter (his head
# rebuilt from the cracked glb while he is out of sight); after the second
# his right arm snaps off at the shoulder as he lands back (the arm's
# blocks left on the field as rubble, the raw break on his shoulder): his
# swat is his left fist only (on his right he can't reach you) and his
# charge pulls to his right, the side he lost.

const DAMAGE_GLB := "res://assets/models/headless_body_damage.glb"
const LOST_ARM := "R"
const ARM_PIECES := {"ArmRubble_R_upper":"upper_arm.R","ArmRubble_R_fore":"forearm.R","ArmRubble_R_hand":"hand.R"}
## The one-armed swat: how far to his right (m past his middle) is out of
## his left fist's reach; how far left of his middle its fist lands (share
## of his width). The charge's pull to the lost side (rad/s, even locked).
const ONE_ARM_SAFE := 0.1
const ONE_ARM_FIST := 0.3
const CHARGE_PULL := 0.32
## The rubble's fling off the shoulder (m/s out, up) and its settle (s).
const ARM_FLING := Vector2(3.0,2.5)
const ARM_SETTLE := 5.0
var damage := 0
var arm_off := false
var _arm_rubble: Array[RigidBody3D] = []
var _arm_rubble_t := 0.0
var _arm_bone := -1

## His damage brought to `n` knock-offs' worth (1 cracked, 2 the arm off).
## `fling`: the arm snaps off now and is thrown off him (else it lies at
## his side already, `--knocked=2`).
func take_damage(n: int, fling := true) -> void:
	if n >= 1 and damage < 1:
		var h: Node = head if head != null and is_instance_valid(head) else null
		if h != null and h.has_method("crack"): h.call("crack")
	if n >= 2 and not arm_off: _lose_arm(fling)
	damage = maxi(damage,n)

## Start phase 2 already knocked off `n` times (the field's `--knocked=N`):
## his damage and his anger as if they had happened.
func set_knocked(n: int) -> void:
	n = clampi(n,0,KNOCK_OFFS-1)
	knock_offs = n
	for i in range(n): _angrier()
	take_damage(n,false)
	print("olmec boss: starts knocked off %d times" % n)

func _lose_arm(fling: bool) -> void:
	arm_off = true
	look.lost = LOST_ARM
	_arm_bone = look.skeleton.find_bone("upper_arm."+LOST_ARM)
	var scene := load(DAMAGE_GLB) as PackedScene
	if scene == null:
		push_warning("olmec boss: no damage glb")
		return
	var src := scene.instantiate()
	var stone := Look.Style.stone_of(7) if Look.Style.ruled() else Color("5a5d63")
	var sk := look.skeleton
	# The raw break on his shoulder, on the chest bone.
	var brk := src.find_child("ShoulderBreak_"+LOST_ARM,true,false) as MeshInstance3D
	if brk != null:
		var chest := sk.find_bone("chest")
		var att := BoneAttachment3D.new()
		att.name = "ShoulderBreak"
		att.bone_name = "chest"
		sk.add_child(att)
		var mi := MeshInstance3D.new()
		mi.name = "ShoulderBreak_"+LOST_ARM
		mi.mesh = Look.HeadLook._dressed(brk.mesh,stone,Vector3.ZERO)
		mi.set_surface_override_material(0,Look.HeadLook.stone_material())
		if mi.mesh.get_surface_count() > 1: mi.set_surface_override_material(1,look._cut_mat)
		att.add_child(mi)
		mi.transform = sk.get_bone_global_rest(chest).affine_inverse()
	# The arm's blocks, where the arm is now, as rubble.
	var out := _right3()
	for piece: String in ARM_PIECES:
		var m := src.find_child(piece,true,false) as MeshInstance3D
		var b := sk.find_bone(String(ARM_PIECES[piece]))
		if m == null or b < 0: continue
		var tr := sk.global_transform*sk.get_bone_global_pose(b)*sk.get_bone_global_rest(b).affine_inverse()
		if not fling:
			# Lying at his right side already.
			var side := global_position+out*(width*0.5+1.2+0.6*float(_arm_rubble.size()))
			side.y = global_position.y+0.6
			var flat := Basis(Vector3.FORWARD,PI*0.5)*Basis(Vector3.UP,facing)
			var sb := flat*Basis.from_scale(tr.basis.get_scale())
			tr = Transform3D(sb,side-sb*m.mesh.get_aabb().get_center())
		var rb := _arm_block(m.mesh,stone,tr)
		var v := out*ARM_FLING.x+Vector3.UP*ARM_FLING.y if fling else Vector3.ZERO
		rb.linear_velocity = v
		if fling: rb.angular_velocity = _forward3()*-2.5
	src.queue_free()
	_arm_rubble_t = 0.0
	_collapse_arm()
	print("olmec boss: right arm snapped off (%d pieces)" % _arm_rubble.size())

## A piece of his arm: its rest-space mesh at `tr` (world), as kit rubble.
func _arm_block(mesh: Mesh, stone: Color, tr: Transform3D) -> RigidBody3D:
	var aabb := mesh.get_aabb()
	var sc := tr.basis.get_scale()
	var c := aabb.get_center()
	var rb := RigidBody3D.new()
	rb.name = "ArmRubble"
	var s := aabb.size*sc
	rb.mass = maxf(s.x*s.y*s.z*2.4,1.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = s*0.85
	shape.shape = box
	rb.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = Look.HeadLook._dressed(mesh,stone,Vector3.ZERO)
	mi.set_surface_override_material(0,Look.HeadLook.stone_material())
	if mi.mesh.get_surface_count() > 1: mi.set_surface_override_material(1,look._cut_mat)
	mi.transform = Transform3D(Basis.from_scale(sc),-(c*sc))
	rb.add_child(mi)
	field.add_child(rb)
	rb.global_transform = Transform3D(tr.basis.orthonormalized(),tr*c)
	_arm_rubble.append(rb)
	return rb

## The lost arm's bones collapsed to nothing (the tree may set them back).
func _collapse_arm() -> void:
	if _arm_bone >= 0: look.skeleton.set_bone_pose_scale(_arm_bone,Vector3.ONE*0.001)

func _animate(delta: float) -> void:
	super._animate(delta)
	if arm_off:
		_collapse_arm()

## One-armed, his swat only reaches you on his left (and ahead).
func _catch(m: PilotMotor, how: String) -> void:
	if arm_off and how == "swat":
		var d := m.feet-position
		if d.dot(_right3()) > ONE_ARM_SAFE*width:
			misses += 1
			chase_beat.emit("missed")
			print("olmec boss: one-armed swat missed (on his right)")
			return
	super._catch(m,how)

## One-armed, the swat (the body's own, headless_body.gd `_swat`) aimed so
## you are on his left, ONE_ARM_AIM rad off: his left fist down there. On
## his right (past ONE_ARM_SAFE) at the hit, it misses you (`_catch`).
const ONE_ARM_AIM := 0.35
## His turn after you in its windup (rate, 1/s; two-armed 6) and its last
## stretch he no longer turns (s): a dash to his right beats it.
const ONE_ARM_TURN := 4.0
const ONE_ARM_LOCK := 0.2
func _one_arm_swat(delta: float) -> void:
	_brake(delta)
	var m: PilotMotor = field.motor
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	if not _swat_hit and to.length() > 0.1 and state_t < float(knobs.swat_windup)-ONE_ARM_LOCK:
		var t := to.normalized()
		var f := t*cos(ONE_ARM_AIM)+Vector2(-t.y,t.x)*sin(ONE_ARM_AIM)
		facing = lerp_angle(facing,PilotMotor.facing_of(f),1.0-exp(-ONE_ARM_TURN*delta))
	if not _swat_hit and state_t >= float(knobs.swat_windup):
		_swat_hit = true
		quake = maxf(quake,0.3)
		var fist := position+_forward3()*(length*0.5+arm_l*0.6)+_fist_side()
		field.sound(&"body_land",fist)
		_puff(fist,hh*1.2)
		if phase2: _hit_arena(fist,FIST_HIT)
		if to.length() <= float(knobs.catch_reach)*hh+0.5 and absf(m.feet.y-position.y) < neck_h*0.6 and not m.seized():
			_catch(m,"swat")
		else:
			misses += 1
			chase_beat.emit("missed")
	if state_t >= float(knobs.swat_windup)+float(knobs.swat_after): _go(_resume())

## Where his fists come down: ahead, or ahead and to his left one-armed.
func _fist_side() -> Vector3:
	return -_right3()*width*ONE_ARM_FIST if arm_off else Vector3.ZERO

func _exit_tree() -> void:
	super._exit_tree()
	for rb: RigidBody3D in _arm_rubble:
		if is_instance_valid(rb): rb.queue_free()
	_arm_rubble.clear()

# --- The charge ---------------------------------------------------------------

func _start_charge() -> void:
	charges += 1
	move = "charge"
	_charge_ready = _clock+CHARGE_REST
	# The others wait a little after it.
	_slam_ready = maxf(_slam_ready,_clock+CHARGE_TELL+2.5)
	_bound_ready = maxf(_bound_ready,_clock+CHARGE_TELL+3.5)
	_scraped = 0
	_go("charge_tell")
	field.sound(&"body_windup",position)
	chase_beat.emit("charge")
	print("olmec boss: charge from %.1f m" % _flat_to_him())

# --- The tilt -----------------------------------------------------------------

func _tilt_due() -> bool:
	if not phase2 or crumbled: return false
	var st: Node = field.study if field != null else null
	if st == null or not bool(st.get("tilt_mix")): return false
	if tilts == 0: return hits >= TILT_AT_HITS or _clock >= _tilt_ready
	return _clock >= _tilt_ready and hits >= TILT_AT_HITS

## Off for the rim at once (the field's `--tilt-now`, or due): false if the
## field has no spot for it.
func tilt_now() -> bool:
	var st: Node = field.study if field != null else null
	if st == null or not st.has_method("tilt_spot"): return false
	var at: Vector3 = st.tilt_spot(position)
	if at == Vector3.INF:
		_tilt_ready = _clock+5.0
		return false
	tilts += 1
	_tilt_ready = INF
	_tilt_at = at
	tilt_rest = Vector3.INF
	move = "tilt"
	_tilt_step = "run"
	_end_slam()
	_go("tilt_run")
	chase_beat.emit("tilt")
	print("olmec boss: tilt %d, for the rim at (%.1f, %.1f), %.1f m off" % [tilts,at.x,at.z,Vector2(at.x-position.x,at.z-position.z).length()])
	return true

func _in_tilt() -> bool:
	return move == "tilt"

## For the rim: the run, then the bound once it reaches.
func _tilt_run(delta: float) -> void:
	var to := Vector2(_tilt_at.x-position.x,_tilt_at.z-position.z)
	var d := to.length()
	if d < 1.5:
		_brake(delta)
		_go("tilt_slam")
		return
	var top := float(knobs.chase_speed)
	facing = lerp_angle(facing,PilotMotor.facing_of(to/d),1.0-exp(-5.0*delta))
	var f := PilotMotor.forward(facing)
	var pace := move_toward(Vector2(vel.x,vel.z).length(),top,float(knobs.accel)*delta)
	vel.x = f.x*pace
	vel.z = f.y*pace
	if d <= TILT_LEAP and state_t > 0.3 and _arc_clear(_tilt_at,"jump"):
		_tilt_step = "leap"
		_up_to = _tilt_at
		leap_kind = "jump"
		_go("windup")
		field.sound(&"body_windup",position)

## Turned in from the rim, fists up, then down on it: the field tips.
func _tilt_slam(delta: float) -> void:
	_brake(delta)
	_tilt_step = "slam"
	var inward := Vector2(-position.x,-position.z)
	if inward.length() > 0.1 and state_t < TILT_WINDUP-0.15:
		facing = lerp_angle(facing,PilotMotor.facing_of(inward.normalized()),1.0-exp(-7.0*delta))
	if not _tilt_hit and state_t >= TILT_WINDUP:
		_tilt_hit = true
		var at := position+_forward3()*(length*0.5+arm_l*0.5)
		var g := _floor(at+Vector3.UP*1.0,2.0,4.0)
		if g != -INF: at.y = g
		_puff(at,hh*2.2)
		Dust.plume(field,at,hh*3.0)
		field.sound(&"body_land",at)
		field.sound(&"body_rumble",at)
		quake = maxf(quake,1.0)
		tilt_rest = position
		brace_hits = 0
		brace_broken = false
		_arc_next = ARC_FIRST
		var st: Node = field.study
		if st != null and st.has_method("tilt_begin"): st.tilt_begin(self,at)
		_go("tilt_brace")

## Braced on the rim, fists on the turf, his weight on it: held where the
## tipped field has his spot.
func _tilt_brace(delta: float) -> void:
	vel = Vector3.ZERO
	_push = Vector3.ZERO
	var st: Node = field.study
	if st != null and st.has_method("tipped") and tilt_rest != Vector3.INF:
		var p: Vector3 = st.tipped(tilt_rest)
		position.x = p.x
		position.z = p.z
		if position.y > p.y+0.5 or position.y < p.y-2.0: position.y = p.y
	quake = maxf(quake,0.12)
	# His air arcs up the slope, a volley at a time.
	if state_t >= _arc_next and st != null and st.has_method("tilt_arcs"):
		_arc_next = state_t+ARC_EVERY
		if st.tilt_arcs(self,ARC_N):
			volleys += 1
			quake = maxf(quake,0.3)
			_tip_v += 0.5
			field.sound(&"body_windup",position)
		else: _arc_next = state_t+0.3

## The field lets him go: up off the rim, then the hunt.
func tilt_let_go() -> void:
	if state != "tilt_brace": return
	_tilt_step = "let"
	_go("tilt_let")

## The field drops him (his brace broken, or held too long): he staggers
## back off the rim and falls out of sight; the field climbs him back.
func tilt_drop() -> void:
	if state != "tilt_brace" or crumbled: return
	drops += 1
	_tilt_step = "off"
	_tilt_ready = _clock+TILT_REST
	_off_rest = tilt_rest
	_off_v = Vector3.ZERO
	_go("tilt_off")
	field.sound(&"body_rumble",position)
	quake = maxf(quake,0.5)

## Rocked back two steps on the tipped rim, then over it and down.
func _tilt_off(delta: float) -> void:
	vel = Vector3.ZERO
	_push = Vector3.ZERO
	var st: Node = field.study
	var out := Vector3(_off_rest.x,0.0,_off_rest.z).normalized()
	if _tilt_step == "off":
		var k := clampf(1.0-state_t/OFF_STAGGER,0.0,1.0)
		_off_rest += out*OFF_BACK*(0.4+0.6*k)*delta
		var p: Vector3 = st.tipped(_off_rest) if st != null and st.has_method("tipped") else _off_rest
		position = p
		if state_t >= OFF_STAGGER:
			# Over the rim: falling, still going back.
			_tilt_step = "drop"
			_off_v = out*OFF_OUT
			_off_rest = position
			field.sound(&"body_windup",position)
		return
	_off_v.y -= OFF_GRAVITY*delta
	position += _off_v*delta
	if _off_rest.y-position.y >= OFF_DEEP:
		_tilt_step = "gone"
		_shown(false)
		_go("tilt_gone")

## Under the rim, out of sight, till the field is still enough to climb.
func _tilt_gone(_delta: float) -> void:
	vel = Vector3.ZERO
	var st: Node = field.study
	if state_t < OFF_GONE or st == null or not st.has_method("climb_back"): return
	if st.climb_back(self):
		climbs_back += 1
		_shown(true)
		_tilt_step = ""
		move = "back"
	elif state_t > 12.0:
		# No crag would take him: back on the rim where he went off.
		_shown(true)
		_tilt_step = ""
		var out := Vector3(tilt_rest.x,0.0,tilt_rest.z).normalized()
		position = tilt_rest-out*4.0
		grounded = true
		move = ""
		_go(_resume())

## Him (and his head on him) shown or hidden.
func _shown(on: bool) -> void:
	visible = on
	var h := _boss_head()
	if h != null: h.visible = on

func _move(delta: float) -> void:
	if state in ["tilt_off","tilt_gone"] or state in OVER:
		rotation.y = facing
		return
	super._move(delta)

func _tilt_let(delta: float) -> void:
	_brake(delta)
	if state_t >= TILT_LET:
		_tilt_step = ""
		_tilt_ready = _clock+TILT_REST
		move = ""
		_go(_resume())

func _flat_to_him() -> float:
	var m: PilotMotor = field.motor
	return Vector2(m.feet.x-position.x,m.feet.z-position.z).length()

func _think_more(delta: float) -> void:
	match state:
		"charge_tell": _charge_tell(delta)
		"charge": _charge(delta)
		"charge_skid": _charge_skid(delta)
		"charge_stagger": _charge_stagger(delta)
		"back_hit": _back_lurch(delta)
		"teeter": _teeter_think(delta)
		"teeter_back": _teeter_back(delta)
		"rim_land": _rim_land(delta)
		"knock_off": _knock_fall(delta)
		"knocked_gone": _knocked_gone(delta)
		"leap_back": _leap_back(delta)
		"tilt_run": _tilt_run(delta)
		"tilt_slam": _tilt_slam(delta)
		"tilt_brace": _tilt_brace(delta)
		"tilt_let": _tilt_let(delta)
		"tilt_off": _tilt_off(delta)
		"tilt_gone": _tilt_gone(delta)

func _pose_more(_idle: float) -> bool:
	match state:
		"charge_tell": look.want("charge_tell",minf(state_t,float(look.lengths.charge_tell)))
		"charge": look.want("charge_run",look.loop_time("charge_run",_phase,2.0))
		"charge_skid": look.want("charge_skid",minf(state_t,float(look.lengths.charge_skid)))
		"charge_stagger": look.want("charge_stagger",minf(state_t,float(look.lengths.charge_stagger)))
		# The art lane's knock-off clips.
		"back_hit": look.want("back_hit",minf(state_t,float(look.lengths.back_hit)))
		"teeter":
			var catch := float(look.lengths.teeter_catch)
			if state_t < catch: look.want("teeter_catch",state_t)
			else: look.want("teeter",fposmod(state_t-catch,float(look.lengths.teeter)))
		"teeter_back": look.want("teeter_back",minf(state_t,float(look.lengths.teeter_back)))
		"knock_off","knocked_gone": look.want("topple",minf(state_t+_topple_from,float(look.lengths.topple)))
		"leap_back": look.want("rim_leap",clampf(state_t/maxf(_leap_t,0.01),0.0,1.0)*float(look.lengths.rim_leap))
		"rim_land": look.want("rim_land",minf(state_t,float(look.lengths.rim_land)))
		"tilt_run": look.want("shoulder_run",look.loop_time("shoulder_run",_phase,2.0))
		"tilt_off","tilt_gone":
			# Rocked back off the rim (the charge's stopped-short stagger),
			# then falling (the drop's air).
			if _tilt_step == "off": look.want("charge_stagger",minf(state_t*1.2,float(look.lengths.charge_stagger)*0.5))
			else: look.want("drop_air",minf(state_t+0.3,float(look.lengths.drop_air)*0.9))
		"tilt_slam","tilt_brace","tilt_let":
			# The triumph's fists up, down on the rim (the slam's), held
			# there braced; let go, the rest of it as he stands up.
			var whole_t := float(look.lengths.triumph)
			var at := TRIUMPH_HIT*whole_t
			var t := at
			if state == "tilt_slam": t = minf(state_t/TILT_WINDUP,1.0)*at
			elif state == "tilt_let": t = at+minf(state_t/TILT_LET,1.0)*(whole_t-at)
			look.want("triumph",t)
		_: return false
	return true

func _step_len() -> float:
	if state == "tilt_run": return Look.RUN_STEP
	return Look.CHARGE_STEP if state == "charge" else super._step_len()

## Planted, turned to him, the back foot scraping; then off.
func _charge_tell(delta: float) -> void:
	_brake(delta)
	var m: PilotMotor = field.motor
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	if to.length() > 0.1 and state_t < CHARGE_TELL-0.15:
		facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-6.0*delta))
	if _scraped < CHARGE_SCRAPES.size() and state_t >= float(CHARGE_SCRAPES[_scraped]):
		_scraped += 1
		# The left (back) foot, dragged back.
		var at := position-_forward3()*(length*0.5+hh*0.35)-_right3()*hh*0.3
		_puff(at,hh*1.0)
		field.sound(&"body_step",at)
		quake = maxf(quake,0.15)
	if state_t >= CHARGE_TELL:
		_charge_way = facing
		_charge_v = Vector2(vel.x,vel.z).length()
		_charge_smash_t = 0.0
		_charge_caught = -1.0
		field.sound(&"body_land",position)
		_go("charge")

## Barrelling at him: a little steering, pieces in the way smashed, a big
## piece or the edge ahead stops him short, him caught thrown, him past
## and he overruns.
func _charge(delta: float) -> void:
	var m: PilotMotor = field.motor
	var top := float(field.motor.run)*CHARGE_RUN
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	var fwd2 := PilotMotor.forward(facing)
	var along := to.dot(fwd2)
	if along > CHARGE_LOCK and to.length() > 0.1:
		var off := angle_difference(facing,PilotMotor.facing_of(to.normalized()))
		facing = wrapf(facing+clampf(off,-CHARGE_TURN*delta,CHARGE_TURN*delta),-PI,PI)
	# One-armed, the charge pulls toward the side he lost.
	if arm_off:
		var r := _right3()
		var pull := angle_difference(facing,PilotMotor.facing_of(Vector2(r.x,r.z)))
		facing = wrapf(facing+signf(pull)*CHARGE_PULL*delta,-PI,PI)
	_charge_v = minf(top,_charge_v+CHARGE_ACCEL*delta)
	var f := PilotMotor.forward(facing)
	vel.x = f.x*_charge_v
	vel.z = f.y*_charge_v
	var fwd := _forward3()
	# Caught: carried on a moment, then he digs in.
	if _charge_caught < 0.0: _charge_catch(m)
	elif state_t-_charge_caught >= CHARGE_CARRY:
		_charge_overrun(false)
		return
	# A big piece, a wall or the edge just ahead: stopped short.
	var stop := length*0.5+maxf(_charge_v*0.2,0.8)
	var a := _arena()
	var why := ""
	if a != null and a.has_method("big_ahead") and a.big_ahead(position,fwd,stop,width*0.4) < INF: why = "big piece"
	elif _floor(position+fwd*(stop+0.5),float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: why = "edge"
	if why != "":
		_charge_stop(why)
		return
	# What's ahead in his path smashed (a column of the rim's ring is big).
	_charge_smash_t -= delta
	if _charge_smash_t <= 0.0:
		_charge_smash_t = 0.1
		# (The big ones he stops short at.)
		var a2 := _arena()
		if a2 != null: a2.hit_at(position+fwd*(length*0.5+_charge_v*CHARGE_SMASH_AHEAD),float(CHARGE_HIT[0]),float(CHARGE_HIT[1]),&"olmec",true)
	if along < -length*0.4 or state_t >= CHARGE_MOST: _charge_overrun()

func _charge_catch(m: PilotMotor) -> bool:
	if m.seized() or (m.recovering() and not m.stunnable(self)): return false
	var d := m.feet-position
	var fwd := _forward3()
	var along := d.dot(fwd)
	var side := absf(d.dot(_right3()))
	if along < -length*0.3 or along > length*0.5+0.6 or side > width*0.5+CHARGE_SIDE: return false
	if m.feet.y > position.y+neck_h or m.feet.y < position.y-1.0: return false
	# Thrown off his shoulder, away and on the way he runs.
	var way := Vector2(d.x,d.z)
	way = way.normalized() if way.length() > 0.1 else PilotMotor.forward(facing)
	way = (way+PilotMotor.forward(facing)*1.2).normalized()
	if float(knobs.void_push) > 0.0: way = OlmecVoid.toward(field,m.feet,way,float(knobs.void_push))
	m.knock(m.knock_velocity(way,float(knobs.swat_out)*float(CHARGE_THROW[0]),float(knobs.swat_up)*float(CHARGE_THROW[1])),self,float(knobs.swat_down)*float(CHARGE_THROW[2]))
	m.harm(harm_cause(),1,self)
	_cool = 0.5
	hit_pilot.emit(self)
	catches += 1
	charge_hits += 1
	if state == "charge": _charge_caught = state_t
	last_catch = "charge"
	quake = maxf(quake,0.7)
	_puff(m.feet,hh*1.0)
	field.sound(&"body_land",m.feet)
	chase_beat.emit("caught charge")
	print("olmec boss: charge caught him, along %.1f side %.1f" % [along,side])
	return true

## Bumping into him charging is the charge's catch, not the walk's shove.
func touch(m: PilotMotor, v_pre: Vector3) -> void:
	if state == "charge":
		_charge_catch(m)
		return
	super.touch(m,v_pre)

func _charge_overrun(missed := true) -> void:
	if missed: charge_overruns += 1
	_charge_v = Vector2(vel.x,vel.z).length()
	_go("charge_skid")
	_puff(position+_forward3()*length*0.5,hh*1.2)
	field.sound(&"body_land",position)
	if missed: chase_beat.emit("overran")
	print("olmec boss: charge overran at %.1f m/s" % _charge_v)

func _charge_stop(why: String) -> void:
	charge_stops += 1
	charge_stop_why = why
	_go("charge_stagger")
	var at := position+_forward3()*(length*0.5+0.4)
	_puff(at,hh*1.4)
	field.sound(&"body_land",at)
	quake = maxf(quake,0.8)
	# Into a big piece: it takes the blow (cracked, maybe felled).
	if why != "edge": _hit_arena(at+_forward3()*0.8,[2.0,0.5])
	chase_beat.emit("stopped short")
	print("olmec boss: charge stopped short (%s) at (%.1f, %.1f)" % [why,position.x,position.z])

## The overrun: slid to a stop on his dug-in heel, a stumble step on,
## then down on a hand (the window), then up.
func _charge_skid(delta: float) -> void:
	var f := PilotMotor.forward(facing)
	var v := 0.0
	if state_t < CHARGE_SLIDE: v = _charge_v*(1.0-state_t/CHARGE_SLIDE)
	elif state_t < CHARGE_SLIDE+0.3: v = 1.6*(1.0-(state_t-CHARGE_SLIDE)/0.3)
	# Don't slide over the edge.
	if v > 0.0 and _floor(position+_forward3()*(length*0.5+v*0.3+0.3),float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: v = 0.0
	vel.x = f.x*v
	vel.z = f.y*v
	if state_t < CHARGE_SLIDE and fmod(state_t,0.12) < delta: _puff(position+_forward3()*(length*0.4),hh*0.6)
	if state_t >= CHARGE_SKID:
		move = ""
		_go(_resume())

## Stopped short: jammed, rocked back a step or two, dazed, squared.
func _charge_stagger(delta: float) -> void:
	var f := PilotMotor.forward(facing)
	var v := 0.0
	if state_t > 0.12 and state_t < 0.6: v = -1.8*(1.0-(state_t-0.12)/0.48)
	vel.x = f.x*v
	vel.z = f.y*v
	if state_t >= CHARGE_STAGGER:
		move = ""
		_go(_resume())

## The slam: the swat's arms up, longer, then the fists on the turf.
func _start_slam() -> void:
	_slam = true
	_slam_hit = false
	slams += 1
	move = "slam"
	_slam_ready = _clock+SLAM_REST
	_swat_knobs = [knobs.swat_windup,knobs.swat_after]
	knobs.swat_windup = SLAM_WINDUP
	knobs.swat_after = SLAM_AFTER
	_go("swat")
	field.sound(&"body_windup",position)
	chase_beat.emit("slam")

func _end_slam() -> void:
	if not _slam: return
	_slam = false
	if _swat_knobs.size() == 2:
		knobs.swat_windup = _swat_knobs[0]
		knobs.swat_after = _swat_knobs[1]

func _go(to: String) -> void:
	# Down from the bound to the rim: straight into the slam.
	if move == "tilt" and _tilt_step == "leap" and state == "land" and to != "land": to = "tilt_slam"
	# A bound that would not go (its arc not clear): run on for the rim.
	if move == "tilt" and _tilt_step == "leap" and state == "windup" and to != "leap" and to != "land":
		_tilt_step = "run"
		to = "tilt_run"
	if to == "tilt_slam": _tilt_hit = false
	if move == "tilt" and not to.begins_with("tilt") and not (to in ["windup","leap","land","fall"]): move = ""
	if _slam and to != "swat": _end_slam()
	if _bound and not (to in ["windup","leap","land"]): _bound = false
	if to in ["chase","seek","alert","return","roam","listen","home","land","spent"] and not (to == "land" and (_bound or move == "tilt")): move = ""
	super._go(to)

func _windup_s() -> float:
	return BOUND_WINDUP if _bound else super._windup_s()

func _swat(delta: float) -> void:
	if not _slam and arm_off:
		_one_arm_swat(delta)
		return
	if not _slam:
		var was := _swat_hit
		super._swat(delta)
		if phase2 and _swat_hit and not was: _hit_arena(position+_forward3()*(length*0.5+arm_l*0.6)+_fist_side(),FIST_HIT)
		return
	_brake(delta)
	var m: PilotMotor = field.motor
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	# Turned to him till the last of the windup.
	if not _slam_hit and state_t < SLAM_WINDUP-0.2 and to.length() > 0.1:
		facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-5.0*delta))
	if not _slam_hit and state_t >= SLAM_WINDUP:
		_slam_hit = true
		var ahead := minf(length*0.5+arm_l*0.6+SLAM_AHEAD,maxf(to.length()*0.5,length*0.5+arm_l*0.6))
		var at := position+_forward3()*ahead+_fist_side()
		var g := _floor(at+Vector3.UP*1.0,2.0,4.0)
		if g != -INF: at.y = g
		_puff(at,hh*1.8)
		field.sound(&"body_land",at)
		_shock(at,SLAM_SHOCK)
		slam_shocks += 1
		_hit_arena(at,SLAM_HIT)
		weighed.emit(at,SLAM_SHOCK,"slam")
	if state_t >= SLAM_WINDUP+SLAM_AFTER:
		_end_slam()
		_go(_resume())

## A bound comes down harder; every landing whole hits the arena.
func _landed() -> void:
	var bound := _bound and state == "leap"
	if bound:
		_pounce_shock = float(knobs.pounce_shock)
		knobs.pounce_shock = BOUND_SHOCK/(float(knobs.hunt_shock) if hunting and _relentless() else 1.0)
	super._landed()
	if bound:
		knobs.pounce_shock = _pounce_shock
		print("olmec boss: bound landed at (%.1f, %.1f)" % [position.x,position.z])
	if phase2: _hit_arena(position,LAND_HIT)
