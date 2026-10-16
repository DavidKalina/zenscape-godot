extends Node3D
## The rune knight's mind (a greybox enemy, docs/design/rune-knight/
## spec-rune-knight.md; `--rune-knight` on the aqueduct isle, off by
## default): a stone knight KNOBS.tall_ratio times the wanderer's height
## (scripts/world_scale.gd `wanderer_tall`), patrolling the aqueduct's deck
## end to end.
##
## - **His body** is behind the contract's API (`play`, `beat_reached`,
##   `socket`, `set_effect`, `shape`): today the stand-in
##   (scripts/enemies/rune_knight_body_standin.gd), later a Blender body.
##   The mind touches it only through those.
## - **The patrol:** he walks the deck's line (studies/aqueduct_isle_art.gd
##   `AQ`, from the head to the snap, KNOBS.end_margin m short of each) at
##   the body's pace (`shape().pace`), playing `walk`. At an end he plays
##   `turn` and his yaw comes round in KNOBS.turn_steps chunks, one set
##   going at each `plant` beat (planted steps), then walks back.
## - **His room:** a column on the parked plane's layer (what the walker
##   sees and walks round, as scripts/kit_isle/watcher.gd's), sized by the
##   body's shape and moved with him, so you can't walk through him.
##   Someone on the deck just ahead of him holds him up: he stands (`idle`)
##   till the way is clear.
## - **Sense:** from his `eye` socket, the wanderer's chest within
##   KNOBS.sight m with nothing of stone or turf between (the deck or the
##   meadow below; looking down, past his deck's lip, KNOBS.lip). Patrolling, he notices you in front of him (within
##   KNOBS.notice_cone of his facing) or anywhere within KNOBS.near m: he
##   stops and plays `notice`, turning to you; then he tracks you (`idle`,
##   his yaw following you). Unseen KNOBS.give_up s, he turns back to his
##   patrol (planted steps) and walks on.
## - **The gather and the throw:** tracking you, faced (within
##   KNOBS.face_ok) and KNOBS.throw_gap s after his last throw, he plays
##   `gather` with `wind_gather` on: a shot (scripts/enemies/wind_shot.gd)
##   sits on `hands_mid`, growing from `grab` (where `rune_glow` comes on).
##   At `full` he plays `throw`; at `release` the shot leaves on a lob
##   that comes down through where your chest was last seen,
##   KNOBS.shot_pace m/s along the ground at most, pulled down
##   KNOBS.shot_fall, climbing KNOBS.shot_rise first; at
##   `end` he tracks again. A shot that meets you knocks you (the gust's).
## - **The slash** (his main attack, KNOBS.attack "slash"; "lob" or
##   `--rune-attack=lob` brings back the gather and throw above): tracking
##   and faced as for a throw, he picks a form (`level` or `high`,
##   KNOBS.level_share) and plays `gather` "blade" with `wind_gather` and
##   `wind_blade` on: the air streams into his right gauntlet and builds
##   along his forearm into a blade. At `full` he plays `slash` in that
##   form (its windup tells which); at `release` a crescent
##   (scripts/enemies/wind_shot.gd, form "crescent") leaves the `blade`
##   socket straight at you, KNOBS.slash_speed m/s: a level one, flat
##   (tilt 0), at KNOBS.slash_low of your height over your feet, to jump;
##   a high one rolled KNOBS.slash_tilt, at your chest, to sidestep. Aimed
##   at where you were, not led. It flies KNOBS.slash_grace m before stone
##   can pop it (off his deck's lip).
## - **Tennis:** each frame he reads every node in the `wind_shot` group
##   (scripts/enemies/wind_shot.gd's seam: position, velocity, shooter,
##   strength, state; `hold`, `launch`). A flying shot not his own, coming
##   at him from in front (within KNOBS.catch_cone of his facing), about to
##   come within his reach (`shape().reach` of his chest), no faster than
##   KNOBS.catch_speed and caught fewer than KNOBS.rally_limit times
##   (meta `rally` on the shot), he catches: it held on `hands_mid`,
##   `catch` (`contact`, `hold`), then (state "return") he wraps it onto
##   his blade (`wind_blade`) and plays `slash` in a form he picks; at
##   `release` it goes back at you as a crescent of that form,
##   KNOBS.return_gain times as fast as it came (at least
##   KNOBS.return_min), its strength up KNOBS.rally_strength (`_send_return`,
##   the one place a return leaves his hands). A gather in his hands when
##   he catches fizzles. Any other shot of another's passing his body (a
##   miss, or from behind or the side) bursts on him (`strike`) and he
##   staggers: `stagger`, pushed back along the shot KNOBS.stagger_push m
##   (eased out by `plant`), then at `recover` he tracks again. Pushed off
##   the deck (past its side or end), he falls to the ground below, lands
##   in another stagger, and stays there off his patrol.
## - **Lock-on and the gust shot** (scripts/lock_on/): he is in
##   "lock_targets" (`aim_point` his chest, `tall` his height, so the
##   marker hangs over his helm). The gust shot's live balls are in the
##   `wind_shot` group too (gust_shot.gd's Seam): caught like any shot
##   (made a wind shot in his hands, counted at its `rally_speed`), or,
##   from the side or behind or past his limit, struck on him. A locked
##   ball that bursts on him calls `hit(at, way, strength)`: a stagger
##   pushed KNOBS.stagger_push x (hit_push_base + hit_push_strength x
##   strength) m along its flat way.
##
## The host (studies/aqueduct_isle.gd) makes him in `_add_life` when
## `wanted`. His knobs are the one dictionary below so a field (enemy.gd)
## or the motif editor can adopt him later.
const WorldScale = preload("res://scripts/world_scale.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const BodyStandin = preload("res://scripts/enemies/rune_knight_body_standin.gd")

const KNOBS := {
	# His height over the wanderer's.
	"tall_ratio": 1.6,
	# The patrol's ends kept off the deck's ends (m); how many planted steps
	# make his half turn; how fast his yaw eases to each step's (rad/s).
	"end_margin": 1.6,
	"turn_steps": 3,
	"turn_rate": 2.6,
	# How near ahead (m past his room) someone on the deck holds him up.
	"blocked": 0.7,
	# Sight (m); the half angle in front he notices you in (rad); how near
	# he notices you anyway (m); unseen this long (s) he gives you up.
	"sight": 28.0,
	"notice_cone": 1.05,
	"near": 5.0,
	"give_up": 4.0,
	# Looking down at someone below, he looks past his own deck's lip (its
	# buttresses): the sight starts this far out (m) toward them.
	"lip": 5.0,
	# Faced this near (rad) he gathers; the rest from a throw's end to the
	# next gather (s).
	"face_ok": 0.3,
	"throw_gap": 2.2,
	# The lob: its pace along the ground (m/s), its pull down (m/s/s), its
	# time aloft's bounds (s), the knock's share of the gust's.
	"shot_pace": 8.0,
	"shot_fall": 9.0,
	"shot_time_min": 0.9,
	"shot_time_max": 4.0,
	# It always climbs at least this far (m) over his hands first, so a lob
	# down off the deck clears its lip.
	"shot_rise": 1.5,
	"shot_strength": 1.0,
	# Tennis: the half angle in front he catches in (rad); the fastest shot
	# he catches (m/s); catches of one shot before he misses it; a return's
	# speed over the shot's (and its floor, m/s), the strength it gains (it
	# goes back as a slash's crescent).
	"catch_cone": 1.0,
	"catch_speed": 30.0,
	"rally_limit": 3,
	"return_gain": 1.3,
	"return_min": 14.0,
	"rally_strength": 0.25,
	# A hit: how far it pushes him back (m); the deck's half width he
	# keeps to (m, off its sides he falls); the fall's pull (m/s/s).
	"stagger_push": 1.1,
	# A gust shot's hit (`hit`): the push's share of stagger_push at no
	# strength and per unit of it (0.6..1.0 from the charge).
	"hit_push_base": 0.7,
	"hit_push_strength": 0.4,
	"deck_half": 1.25,
	"gravity": 22.0,
	# His attack: "slash" (the crescent) or "lob" (the gathered ball).
	"attack": "slash",
	# The slash: the crescent's speed (m/s); the share of level slashes (the
	# rest high); a level one's height over your feet (your heights); a high
	# one's roll (rad); metres before stone can pop it; its knock's share.
	"slash_speed": 15.0,
	"level_share": 0.5,
	"slash_low": 0.3,
	"slash_tilt": 1.0,
	"slash_grace": 6.0,
	"slash_strength": 1.0,
}
## What hides you from him: stone (layer 1) and turf (layer 11).
const SIGHT_MASK := 1 | (1 << 11)
const WindShot = preload("res://scripts/enemies/wind_shot.gd")
## The parked plane's layer (studies/kit_isle.gd PARKED_LAYER): only the
## walker and his ground probes see it.
const ROOM_LAYER := 1 << 13

var isle: Node3D
var body: Node3D
var height := 1.9
## "patrol", "turn", "held", "notice", "track", "gather", "throw",
## "catch", "return", "stagger", "fall".
var state := "patrol"
## His yaw (he faces -Z of Basis(UP, yaw)) and the one it eases to.
var yaw := 0.0
var yaw_goal := 0.0
## The patrol's two ends (world, deck height) and which he walks to.
var ends: Array[Vector3] = []
var heading_to := 1
var _turns_left := 0
var _shape: Dictionary = {}
var _room: StaticBody3D
## The half turn's chunk (rad) and the state a turn ends in.
var _turn_step := 0.0
## Whether he sees the wanderer this frame, how long unseen (s), where his
## chest was last seen, the rest left before a gather (s), the shot in his
## hands (null none) and the count thrown.
var sees := false
var unseen := 0.0
var last_seen := Vector3.INF
var cool := 0.0
var shot: Node3D = null
var throws := 0
## Tennis: the shot he caught (null none), catches, returns, hits taken;
## the stagger's push (m/s, flat) and the fall's speed; off his deck (he
## fell) he no longer patrols.
var caught: Node3D = null
var catches := 0
var returns := 0
var hits := 0
var push := Vector3.ZERO
var fall_v := Vector3.ZERO
var off_deck := false
var _caught_speed := 0.0
## His attack ("slash" or "lob"), the form of the slash under way, the
## next form when set ("" picks by KNOBS.level_share), slashes sent.
var attack := "slash"
var slash_form := "level"
var next_form := ""
var slashes := 0
var _rng := RandomNumberGenerator.new()

static func wanted() -> bool:
	return LaunchArgs.user_args().has("--rune-knight")

func _init() -> void:
	name = "RuneKnight"
	# Before his body (0), which reads where he went this frame.
	process_priority = -10

func knob(key: String) -> float:
	return float(KNOBS[key])

## His height (m), for the lock marker over his helm.
func tall() -> float:
	return height

## Where a blast aimed at him goes: his chest rune.
func aim_point() -> Vector3:
	return body.socket("chest_rune").global_position if body != null else global_position+Vector3.UP*height*0.7

## Him on `host`'s aqueduct deck (the aqueduct isle), at the head end,
## facing along it.
func setup(host: Node3D) -> void:
	isle = host
	height = WorldScale.wanderer_tall*knob("tall_ratio")
	_rng.randomize()
	attack = String(KNOBS.attack)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--rune-attack="): attack = a.get_slice("=",1)
	var margin := knob("end_margin")
	ends = [Art.AQ*Vector3(Art.HEAD+margin,Art.DECK,0.0),Art.AQ*Vector3(Art.SNAP-margin,Art.DECK,0.0)]
	yaw = _yaw_to(ends[1]-ends[0])
	yaw_goal = yaw
	transform = Transform3D(Basis(Vector3.UP,yaw),ends[0])
	body = BodyStandin.new()
	add_child(body)
	body.setup(height)
	body.beat_reached.connect(_on_beat)
	_shape = body.shape()
	# The stand-in blast (scripts/enemies/wind_blast_standin.gd) aims at him.
	add_to_group("wind_shot_aim")
	# Lock-on (scripts/lock_on/foot_lock.gd) and the gust shot's hit.
	add_to_group("lock_targets")
	_build_room()
	body.play("walk")

func _process(delta: float) -> void:
	var at := position
	_read_shots(delta)
	at = position
	_sense()
	cool = maxf(0.0,cool-delta)
	unseen = 0.0 if sees else unseen+delta
	if state in ["patrol","held","turn"] and sees and _noticeable() and not off_deck:
		state = "notice"
		body.play("notice")
	match state:
		"patrol", "held":
			var fwd := _forward()
			var left := (ends[heading_to]-at).dot(fwd)
			if left <= 0.02:
				heading_to = 1-heading_to
				_turn_to(_yaw_to(ends[heading_to]-at))
			elif _blocked(fwd):
				if state != "held": body.play("idle")
				state = "held"
			else:
				if state != "patrol": body.play("walk")
				state = "patrol"
				at += fwd*minf(float(_shape.pace)*delta,left)
		"turn":
			pass
		"stagger":
			at += push*delta
			push *= exp(-3.0*delta)
			if not off_deck and _off_deck(at):
				off_deck = true
				state = "fall"
				fall_v = push
				print("rune knight: pushed off the deck at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
			elif not off_deck:
				at = _keep_on_deck(at)
		"fall":
			fall_v += Vector3.DOWN*knob("gravity")*delta
			var step := fall_v*delta
			var ground := _ground_below(at,step)
			if ground != Vector3.INF:
				at = ground
				fall_v = Vector3.ZERO
				push = Vector3.ZERO
				state = "stagger"
				body.play("stagger")
				print("rune knight: landed at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
			else:
				at += step
		"catch", "return", "slash":
			if last_seen != Vector3.INF:
				yaw_goal = yaw+wrapf(_yaw_to(last_seen-at)-yaw,-PI,PI)
		"notice", "track", "gather", "throw":
			if last_seen != Vector3.INF and state != "throw":
				yaw_goal = yaw+wrapf(_yaw_to(last_seen-at)-yaw,-PI,PI)
			if state == "track":
				if unseen > knob("give_up") and off_deck:
					pass
				elif unseen > knob("give_up"):
					_turn_to(_yaw_to(ends[heading_to]-at))
				elif sees and cool <= 0.0 and absf(yaw_goal-yaw) < knob("face_ok"):
					_gather()
	yaw = move_toward(yaw,yaw_goal,knob("turn_rate")*delta)
	transform = Transform3D(Basis(Vector3.UP,yaw),at)
	_room.global_transform = Transform3D(Basis.IDENTITY,at)

func _on_beat(clip: String, beat: String) -> void:
	if clip == "turn" and beat == "plant" and state == "turn":
		if _turns_left > 0: _next_turn()
		elif absf(yaw-yaw_goal) < 0.01:
			state = "patrol"
			body.play("walk")
	elif clip == "notice" and beat == "end" and state == "notice":
		state = "track"
		body.play("idle")
	elif clip == "gather" and state == "gather":
		if beat == "grab":
			body.set_effect("rune_glow",true)
			if shot != null: shot.grow()
		elif beat == "full":
			body.set_effect("wind_gather",false)
			if attack == "lob":
				state = "throw"
				body.play("throw")
			else:
				state = "slash"
				body.play("slash",slash_form)
	elif clip == "slash" and state == "slash":
		if beat == "release": _release_slash()
		elif beat == "end":
			state = "track"
			cool = knob("throw_gap")
			body.play("idle")
	elif clip == "catch" and state == "catch":
		if beat == "hold":
			state = "return"
			slash_form = _pick_form()
			body.play("slash",slash_form)
			body.set_effect("wind_blade",true)
			if caught != null and is_instance_valid(caught):
				caught.call("hold",body.socket("blade"))
				caught.set("form","crescent")
	elif clip == "slash" and state == "return":
		if beat == "release": _return_caught()
		elif beat == "end":
			state = "track"
			cool = knob("throw_gap")
			body.play("idle")
	elif clip == "stagger" and state == "stagger":
		if beat == "recover":
			state = "track"
			push = Vector3.ZERO
			cool = knob("throw_gap")
			body.play("idle")
	elif clip == "throw" and state == "throw":
		if beat == "release": _release()
		elif beat == "end":
			state = "track"
			cool = knob("throw_gap")
			body.play("idle")

## Turned to `want` (yaw) in planted steps, each at most a
## 1/KNOBS.turn_steps half turn, then walking his patrol.
func _turn_to(want: float) -> void:
	var diff := wrapf(want-yaw,-PI,PI)
	var chunks := maxi(1,ceili(absf(diff)/(PI/knob("turn_steps"))-0.01))
	_turn_step = diff/float(chunks)
	_turns_left = chunks
	yaw_goal = yaw
	state = "turn"
	body.play("turn")
	_next_turn()

## The next chunk of the turn: his yaw's goal comes round by one step.
func _next_turn() -> void:
	_turns_left -= 1
	yaw_goal += _turn_step

# --- Sense --------------------------------------------------------------------------

## The wanderer's chest, or INF when he isn't on foot.
func _target() -> Vector3:
	var motor = isle.get("motor") if isle != null else null
	if motor == null or motor.get("rider") != null: return Vector3.INF
	return (motor.feet as Vector3)+Vector3.UP*0.6*WindShot.walker_tall()

## Whether he sees the wanderer: in sight range, nothing of stone or turf
## between his eye and the chest. Sets `sees` and `last_seen`.
func _sense() -> void:
	sees = false
	var chest := _target()
	if chest == Vector3.INF or not is_inside_tree(): return
	var eye: Vector3 = body.socket("eye").global_position
	if eye.distance_to(chest) > knob("sight"): return
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = SIGHT_MASK
	ray.from = eye
	if chest.y < position.y-1.5:
		var flat := Vector3(chest.x-eye.x,0.0,chest.z-eye.z)
		ray.from = eye+flat.normalized()*minf(knob("lip"),flat.length()*0.5)
	ray.to = chest
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
	sees = true
	last_seen = chest

## Whether a patrolling knight notices what he sees: in front of him or near.
func _noticeable() -> bool:
	var off := last_seen-position
	if Vector2(off.x,off.z).length() < knob("near"): return true
	return absf(wrapf(_yaw_to(off)-yaw,-PI,PI)) < knob("notice_cone")

# --- The gather and the throw -------------------------------------------------------

func _gather() -> void:
	state = "gather"
	if attack != "lob":
		slash_form = _pick_form()
		body.play("gather","blade")
		body.set_effect("wind_gather",true)
		body.set_effect("wind_blade",true)
		shot = null
		return
	body.play("gather")
	body.set_effect("wind_gather",true)
	shot = WindShot.new()
	isle.add_child(shot)
	shot.shooter = self
	shot.strength = knob("shot_strength")
	shot.target = isle.get("motor")
	shot.hold(body.socket("hands_mid"))

## The shot leaves his hands on a lob down through where he last saw you.
func _release() -> void:
	body.set_effect("rune_glow",false)
	if shot == null or not is_instance_valid(shot): return
	var from: Vector3 = shot.global_position
	var to := last_seen if last_seen != Vector3.INF else from+_forward()*10.0
	var flat := Vector2(to.x-from.x,to.z-from.z).length()
	# Long enough aloft to climb shot_rise first (v up >= sqrt(2 g rise)).
	var g := knob("shot_fall")
	var v_up := sqrt(2.0*g*knob("shot_rise"))
	var climb := (v_up+sqrt(maxf(v_up*v_up-2.0*g*(to.y-from.y),0.0)))/g
	var t := clampf(maxf(flat/knob("shot_pace"),climb),knob("shot_time_min"),knob("shot_time_max"))
	shot.launch(WindShot.lob(from,to,t,knob("shot_fall")),knob("shot_fall"))
	throws += 1
	print("rune knight: throws at (%.1f, %.1f, %.1f), %.1f m off, %.1f s aloft" % [to.x,to.y,to.z,flat,t])
	shot = null

## The next slash's form: `next_form` if set (then cleared), else level
## KNOBS.level_share of the time, high the rest.
func _pick_form() -> String:
	if next_form != "":
		var f := next_form
		next_form = ""
		return f
	return "level" if _rng.randf() < knob("level_share") else "high"

## The slash's crescent leaves his blade at where he last saw you.
func _release_slash() -> void:
	body.set_effect("rune_glow",false)
	body.set_effect("wind_blade",false)
	var node: Node3D = WindShot.new()
	isle.add_child(node)
	node.global_position = body.socket("blade").global_position
	node.set("strength",knob("slash_strength"))
	_send_crescent(node,slash_form,knob("slash_speed"))
	slashes += 1

## Where a crescent of `form` aims: a level one low over your feet, a
## high one at your chest (where he last saw you).
func _crescent_aim(form: String, from: Vector3) -> Vector3:
	var chest := _target()
	var to := chest if chest != Vector3.INF and sees else last_seen
	if to == Vector3.INF: return from+_forward()*10.0
	if form == "level":
		to += Vector3.DOWN*(0.6-knob("slash_low"))*WindShot.walker_tall()
	return to

## `node` sent from where it is as a crescent of `form`, straight at its
## aim `speed` m/s, his, at the wanderer.
func _send_crescent(node: Node3D, form: String, speed: float) -> void:
	var from := node.global_position
	var to := _crescent_aim(form,from)
	node.set("shooter",self)
	node.set("target",isle.get("motor"))
	node.set("flight",WindShot.FLIGHT)
	node.set("tilt",0.0 if form == "level" else -knob("slash_tilt"))
	node.call("launch",(to-from).normalized()*speed,0.0,knob("slash_grace"))
	node.set("form","crescent")
	print("rune knight: slashes (%s) at %.1f m/s toward (%.1f, %.1f, %.1f)" % [form,speed,to.x,to.y,to.z])

## Whether the walker stands on the deck just ahead of him.
func _blocked(fwd: Vector3) -> bool:
	var motor = isle.get("motor") if isle != null else null
	if motor == null: return false
	var feet: Vector3 = motor.feet
	if absf(feet.y-position.y) > height*0.6: return false
	var off := feet-position
	var ahead := off.dot(fwd)
	var room: float = _shape.radius
	return ahead > 0.0 and ahead < room+knob("blocked")+0.4 and absf(off.dot(Basis(Vector3.UP,yaw).x)) < room+0.4

func _forward() -> Vector3:
	return -(Basis(Vector3.UP,yaw).z)

static func _yaw_to(way: Vector3) -> float:
	return atan2(-way.x,-way.z)

func _build_room() -> void:
	_room = StaticBody3D.new()
	_room.name = "RuneKnightRoom"
	_room.collision_layer = ROOM_LAYER
	_room.collision_mask = 0
	_room.top_level = true
	var shape := CollisionShape3D.new()
	var column := CylinderShape3D.new()
	column.radius = float(_shape.radius)
	column.height = float(_shape.height)
	shape.shape = column
	shape.position = Vector3.UP*column.height*0.5
	_room.add_child(shape)
	add_child(_room)
	_room.global_transform = Transform3D(Basis.IDENTITY,position)

# --- Tennis ---------------------------------------------------------------------------

## Every flying shot not his own: caught if it comes from in front within
## reach and he can, else burst on him if it passes his body.
func _read_shots(delta: float) -> void:
	if body == null or not is_inside_tree(): return
	var chest := aim_point()
	var reach: float = _shape.reach
	var hit_r: float = WindShot.radius()+float(_shape.radius)+WindShot.FUSE*WindShot.walker_tall()
	var a := position+Vector3.UP*height*0.15
	var b := position+Vector3.UP*height*0.9
	for node: Node in get_tree().get_nodes_in_group(WindShot.GROUP):
		if not node is Node3D or node == shot or node == caught: continue
		if node.get("state") != "flying" or node.get("shooter") == self: continue
		var p := (node as Node3D).global_position
		var v: Vector3 = node.get("velocity") if node.get("velocity") != null else Vector3.ZERO
		var next := p+v*delta
		var coming := v.dot(chest-p) > 0.0
		if coming and _can_catch(node,p,v) and minf(p.distance_to(chest),next.distance_to(chest)) < reach+v.length()*delta:
			_catch(node,v)
			return
		var near := Geometry3D.get_closest_points_between_segments(p,next,a,b)
		if (near[0] as Vector3).distance_to(near[1]) < hit_r:
			_hit(node,near[0],v)
			return

## Whether he can catch `node` now: free to (not catching, returning,
## staggered or falling), the shot from in front, slow enough, and not yet
## caught KNOBS.rally_limit times.
func _can_catch(node: Node, p: Vector3, v: Vector3) -> bool:
	if state in ["catch","return","stagger","fall"]: return false
	if not (node.has_method("hold") and node.has_method("launch")) and not node.has_method("absorb"): return false
	var off := p-position
	if absf(wrapf(_yaw_to(off)-yaw,-PI,PI)) > knob("catch_cone"): return false
	var why := ""
	if _pace(node,v) > knob("catch_speed"): why = "too fast to catch (%.1f m/s)" % _pace(node,v)
	elif int(node.get_meta("rally",0)) >= int(knob("rally_limit")): why = "past his rally limit"
	if why != "":
		if not node.has_meta("missed"):
			node.set_meta("missed",true)
			print("rune knight: %s, misses it" % why)
		return false
	return true

## A shot's pace as a rally counts it: its `rally_speed` if it has one
## (the gust shot's balls), else its speed.
static func _pace(node: Node, v: Vector3) -> float:
	var r = node.get("rally_speed")
	return float(r) if r != null else v.length()

func _catch(node: Node3D, v: Vector3) -> void:
	_drop_gather()
	_caught_speed = _pace(node,v)
	if not node.has_method("hold"):
		# Not a wind shot (a gust shot's ball): taken into one in his hands.
		var held: Node3D = WindShot.new()
		isle.add_child(held)
		held.global_position = node.global_position
		held.set("shooter",node.get("shooter"))
		var st = node.get("strength")
		if st != null: held.set("strength",float(st))
		held.set_meta("rally",int(node.get_meta("rally",0)))
		node.call("absorb")
		node = held
	caught = node
	node.set_meta("rally",int(node.get_meta("rally",0))+1)
	node.call("hold",body.socket("hands_mid"))
	catches += 1
	state = "catch"
	body.play("catch")
	body.set_effect("rune_glow",true)
	print("rune knight: catches a shot at %.1f m/s (rally %d)" % [_caught_speed,int(node.get_meta("rally"))])

## A gather in his hands when a catch or a hit comes: it fizzles.
func _drop_gather() -> void:
	body.set_effect("wind_gather",false)
	body.set_effect("wind_blade",false)
	if shot != null and is_instance_valid(shot): shot.absorb()
	shot = null

## The caught shot back at your chest, faster.
func _return_caught() -> void:
	body.set_effect("rune_glow",false)
	body.set_effect("wind_blade",false)
	# Sent: the slash's follow-through, in which he can catch again.
	state = "slash"
	var node := caught
	caught = null
	if node == null or not is_instance_valid(node): return
	var speed := maxf(_caught_speed*knob("return_gain"),knob("return_min"))
	_send_return(node,speed)
	returns += 1

## The one place a return leaves his hands: `node` (held on his blade)
## slashed back at you `speed` m/s as a crescent of the slash's form, a
## little stronger.
func _send_return(node: Node3D, speed: float) -> void:
	var st = node.get("strength")
	if st != null: node.set("strength",float(st)+knob("rally_strength"))
	_send_crescent(node,slash_form,speed)
	print("rune knight: returns it at %.1f m/s" % speed)

## A gust shot's ball burst on him (scripts/lock_on/gust_shot.gd): he
## staggers back along its flat way, farther with more strength.
func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	_stagger(way,knob("stagger_push")*(knob("hit_push_base")+knob("hit_push_strength")*strength))
	print("rune knight: gust shot hit at (%.1f, %.1f, %.1f), strength %.2f, staggers (%d hits)" % [at.x,at.y,at.z,strength,hits])

## A shot burst on him: he staggers back along it (a gust shot's ball as
## `hit` would push him).
func _hit(node: Node, at: Vector3, v: Vector3) -> void:
	if node.has_method("strike"): node.call("strike",at)
	var meters := knob("stagger_push")
	if not node.has_method("hold"):
		var st = node.get("strength")
		meters *= knob("hit_push_base")+knob("hit_push_strength")*(float(st) if st != null else 1.0)
	_stagger(v,meters)
	print("rune knight: hit at %.1f m/s, staggers (%d hits)" % [v.length(),hits])

## Staggered back `meters` m along `v`'s flat way (any gather or held shot
## lost).
func _stagger(v: Vector3, meters: float) -> void:
	_drop_gather()
	if caught != null and is_instance_valid(caught) and caught.has_method("absorb"): caught.call("absorb")
	caught = null
	body.set_effect("rune_glow",false)
	hits += 1
	var flat := Vector3(v.x,0.0,v.z)
	if flat.length() < 0.1: flat = -_forward()
	if state != "fall":
		# Eased out over the clip: push decays exp(-3 t), so it goes push/3.
		push = flat.normalized()*meters*3.0
		state = "stagger"
		body.play("stagger")

## The deck's frame: x along it, z across.
func _deck_local(at: Vector3) -> Vector3:
	return Art.AQ.affine_inverse()*at

## Whether `at` is past the deck's side or ends.
func _off_deck(at: Vector3) -> bool:
	var l := _deck_local(at)
	return absf(l.z) > knob("deck_half") or l.x < Art.HEAD or l.x > Art.SNAP

## `at` kept on the patrol's line's span (he may stand off its middle).
func _keep_on_deck(at: Vector3) -> Vector3:
	var l := _deck_local(at)
	var margin := knob("end_margin")
	l.x = clampf(l.x,Art.HEAD+margin*0.5,Art.SNAP-margin*0.5)
	return Art.AQ*l

## Where a fall's step from `at` along `step` meets stone or turf, or INF.
func _ground_below(at: Vector3, step: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = SIGHT_MASK
	ray.from = at
	ray.to = at+step+Vector3.DOWN*0.05
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return Vector3.INF if hit.is_empty() else hit.position as Vector3
