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
##   - the swat as before, quicker.
## His fists, landings and slams hit the arena (scripts/olmec_boss/arena.gd
## `hit_at`), and his shockwaves break what they pass as they always have
## (the hub is his breaker). PHASE2_HITS gust shots bring him down
## (`crumble`). `move` names the attack he is on ("" none), for the card.

## Phase 2's knobs over the body's own (scaled by the field's numbers in
## `phase_two`: speeds by the walker's run).
const PHASE2 := {"chase_turn":2.8,"accel":5.5,"swat_windup":0.42,"swat_after":0.5,
	"pounce_windup":0.6,"pounce_rest":2.0,"land":0.7,"suck_rest":10.0}
## His hunt's pace: this times the walker's run.
const CHASE_RUN := 1.12
## Gust shots to bring him down whole.
const PHASE2_HITS := 8
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

## Whole: the boss's moveset on, his hits counted afresh.
func phase_two() -> void:
	if phase2: return
	phase2 = true
	hits = 0
	most_hits = PHASE2_HITS
	knobs.merge(PHASE2,true)
	var run: float = field.motor.run
	knobs.chase_speed = run*CHASE_RUN
	knobs.relentless = 1
	knobs.chase = 1
	# A beat after the triumph before the big moves.
	_bound_ready = _clock+2.0
	_slam_ready = _clock+1.0
	_puff_ready = _clock+PUFF_FIRST
	_hunt_pace = float(knobs.chase_speed)
	print("olmec boss: phase 2, chase %.1f m/s (walker run %.1f), hh %.2f, neck %.2f" % [float(knobs.chase_speed),run,hh,neck_h])

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
	var level := absf(dy) < neck_h*0.6
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
			_leap_to = at
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

## A gust shot in his head's absorb or tell breaks the puff.
func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	if phase2 and not crumbled:
		var h := _boss_head()
		if h != null and h.break_worn(): _puff_ready = maxf(_puff_ready,_clock+PUFF_REST*0.5)
	super.hit(at,way,strength)

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
	if _slam and to != "swat": _end_slam()
	if _bound and not (to in ["windup","leap","land"]): _bound = false
	if to in ["chase","seek","alert","return","roam","listen","home","land","spent"] and not (to == "land" and _bound): move = ""
	super._go(to)

func _windup_s() -> float:
	return BOUND_WINDUP if _bound else super._windup_s()

func _swat(delta: float) -> void:
	if not _slam:
		var was := _swat_hit
		super._swat(delta)
		if phase2 and _swat_hit and not was: _hit_arena(position+_forward3()*(length*0.5+arm_l*0.6),FIST_HIT)
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
		var at := position+_forward3()*ahead
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
