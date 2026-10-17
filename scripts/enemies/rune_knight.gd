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
## - **His runes and the skid** (spec "His runes, his deaths, his drop"):
##   three runes (`runes`: left gauntlet, right gauntlet, chest) are his
##   health. A rally miss (a shot from in front he let go, past his limit
##   or too fast) cracks the next (`rune_crack`, its form the rune) and
##   skids him KNOBS.skid_miss_min..max m; any other hit (the side,
##   behind, a gust shot's `hit`) cracks nothing and skids him
##   KNOBS.skid_side_min..max m, both by the shot's strength. The skid
##   (`skid`): on his feet, scraping back along the hit's flat way at a
##   constant deceleration. One that would carry past the deck's side by
##   KNOBS.teeter_reach or less stops at the lip and he teeters
##   (`teeter`, till its `end`, then tracks you); any hit while teetering
##   puts him over; a longer one carries him over.
## - **His deaths:** broken, all three runes dark, once his skid or teeter
##   is over he plays `kneel` (state "kneel"), the wind going out of him.
##   Any hit then (a shot burst on him, a gust shot's `hit`) and he plays
##   `crumble` (a heap of his blocks where he knelt) and the last of his
##   wind bursts out of him at you: a wind shot (KNOBS.burst_speed m/s)
##   whose parry fills the whole gauge (meta `parry_gain` 1.0, read by
##   scripts/wind_parry.gd). Off the edge, whatever his runes, he falls
##   (`fall`); at its `land` beat (the body's, when his root stops
##   dropping) he plays `shatter` on the ground below. Dead ("dead"), he
##   leaves the lock targets and his room, reads no shots, and `died_at`
##   and `death` ("crumble", "shatter", or "gone": over the island's rim, his
##   rune with him) say where and how.
## - **The riposte** (spec "The brutal parry, the riposte, the brace"): a
##   parry of one of his shots (scripts/wind_parry.gd calls `parried`)
##   rips his wind from him: `reel` (state "reel", till its `end`), runes
##   flaring. A shot that reaches him reeling (a gust shot's ball, X) can't
##   be caught and, from any side, cracks a rune and skids him as a rally
##   miss does (`ripostes`).
## - **The brace:** a shove that cracks nothing (a side or back hit) never
##   throws him straight off the deck: he braces and his skid turns along
##   the deck (its across share at most KNOBS.brace_across), and where it
##   still reaches the lip it ends there teetering. A knock-off from the
##   side takes a teeter and a second hit. A rally miss or a riposte keeps
##   its line (and may carry him straight over).
## - **The leap** (spec "The leap"): his spots (`leap_spots`) are found
##   once from the aqueduct's real shape: turf beside its foot each side,
##   the column up to the deck clear of stone (the buttress, the footings),
##   off the plane's landing run. On the deck tracking you, with you on the
##   meadow near the aqueduct and no clean line on you KNOBS.leap_wait s
##   (or close below him KNOBS.leap_close_wait s, when he holds his
##   slash), he walks along the deck over the spot nearest you (`to_leap`)
##   and leaps down (`leap` "down"), landing KNOBS.leap_short m short of
##   you where the turf takes him. On the meadow (`on_meadow`) he fights as
##   on the deck (no lip, no brace: a skid into stone stops). You on the
##   deck, he walks to the spot below you and leaps up (`leap` "up"); you
##   unseen KNOBS.home_wait s, he leaps home to his patrol. The arc is his
##   (sampled at the body's `launch`; a hang at the top, his feet going
##   across only while he is over the lip); the body sends `crouch`,
##   `launch`, `apex`, `land`, `end`. Each landing's ring
##   (scripts/enemies/leap_ring.gd, set at the launch) knocks a wanderer
##   within KNOBS.leap_ring m; a parry timed to the touchdown takes it, and
##   he reels as he lands. In the air shots crack but don't turn him.
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
	# The skid (a hit's knockback): how far a side or back hit skids him
	# (m, from the weakest shot to the strongest, strength 0.6..1.0); how
	# far a rally miss does (and cracks a rune); his deceleration fighting
	# to stop (m/s/s, at the full skid; cut short at the lip he digs in
	# harder); how far past the deck's side a skid may carry and still end
	# teetering at the lip (m; farther, he goes straight over); where along
	# his half width the lip stops him (share of deck_half); a push off
	# the teeter (m/s, out over the drop).
	"skid_side_min": 3.0,
	"skid_side_max": 4.0,
	"skid_miss_min": 6.0,
	"skid_miss_max": 8.0,
	"skid_decel": 9.0,
	"teeter_reach": 1.2,
	"teeter_lip": 0.9,
	"over_push": 3.0,
	# The brace: a shove's skid turned along the deck, its across share at
	# most this (0 straight along, 1 unbraced).
	"brace_across": 0.4,
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
	# The last wind burst out of him as he crumbles: its speed (m/s), its
	# knock's share, metres before stone can pop it, and the gauge share a
	# parry of it fills (1.0 the whole gauge).
	"burst_speed": 12.0,
	"burst_strength": 1.0,
	"burst_grace": 3.0,
	"burst_gain": 1.0,
	# The leap (spec "The leap"): his spots on the turf beside the
	# aqueduct's foot are this far (m) past his room off the deck's side,
	# looked for every leap_step m along the deck; the column over one is
	# clear of stone this much wider than his room (m).
	"leap_out": 1.2,
	"leap_step": 1.0,
	"leap_clear": 0.6,
	# Down: the wanderer on the meadow this near the aqueduct's side (m,
	# flat) and unseen (no clean line) this long (s) draws him down; this
	# near him (m, flat) and below, this long (s) does too. He lands this
	# short of the wanderer (m), at most leap_far m out from his spot.
	"leap_reach": 24.0,
	"leap_wait": 2.5,
	"leap_close": 7.0,
	"leap_close_wait": 0.6,
	"leap_short": 2.5,
	"leap_far": 7.0,
	# The arc: the top's height over the higher end (m; up, then down); near
	# the top (|v up| under leap_hang_v m/s) his pull is leap_hang of
	# gravity (the hang).
	"leap_rise_up": 1.3,
	"leap_rise_down": 1.0,
	"leap_hang": 0.3,
	"leap_hang_v": 3.5,
	# The landing's ring: the wanderer within leap_ring m (flat) of where he
	# lands and within a body's height of it is knocked, the knock's share.
	"leap_ring": 4.0,
	"leap_ring_strength": 0.8,
	# Home: on the meadow, the wanderer unseen this long (s), he leaps back up.
	"home_wait": 6.0,
	# The island's rim (task 12): a meadow skid's lip is where the ground
	# under him ends (nothing within rim_depth m below); gone over, he
	# falls rim_drop m, then, nothing under him for fall_drop m, is gone
	# (dead, out of sight below; ground under him, he lands and shatters).
	# A fall off the deck is gone the same after fall_drop m.
	"rim_step": 0.25,
	"rim_depth": 2.5,
	"rim_drop": 5.0,
	"fall_drop": 40.0,
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
## "slash", "catch", "return", "skid", "teeter", "stagger", "fall", "down"
## (landed from a fall, waiting on the body's `land`), "kneel", "dead",
## "to_leap" (walking to a leap's launch), "leap".
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
## His runes, his health: the lit ones, cracked in this order (a rally
## miss cracks the first); `cracks` how many have gone.
var runes: Array[String] = ["hand_l","hand_r","chest"]
var cracks := 0
## The skid under way: its flat way, its speed at the start (m/s), its
## length and what is left of it (m); whether it ends teetering at the
## lip; whether the clip's `end` came before he stopped; skids so far and
## the last one's metres (for the drivers).
var skid_way := Vector3.ZERO
var _skid_v0 := 0.0
var _skid_len := 0.0
var _skid_left := 0.0
var _skid_teeter := false
var _skid_ended := false
var skids := 0
var skid_from := Vector3.ZERO
var skid_meters := 0.0
var teeters := 0
## Parries of his shots that set him reeling, hits that landed in a reel.
var reels := 0
var ripostes := 0
## Whether the last skid was braced (turned along the deck).
var braced := false
## His attack ("slash" or "lob"), the form of the slash under way, the
## next form when set ("" picks by KNOBS.level_share), slashes sent.
var attack := "slash"
var slash_form := "level"
var next_form := ""
var slashes := 0
## His death: "" alive, "crumble", "shatter" or "gone"; where it was; the wind
## burst out of him as he crumbled (null none).
var death := ""
var died_at := Vector3.INF
var burst: Node3D = null
## The leap: his spots (found once, `leap_spots`: {at (world, on the turf),
## side (+1/-1, deck z), x (deck x)}); the leap under way: its form ("up",
## "down"), where he walks to first (the launch point), its ends, the
## arc's heights (sampled every LEAP_DT s from launch), its length and the
## span of it his feet go across in, the time into it (-1 before the
## launch); whether a parry of its ring sets him reeling on landing, and
## whether it takes him home to his patrol. `on_meadow` he leapt down.
var leap_spots: Array = []
var _spots_found := false
var leap_form := ""
var _leap_goal := Vector3.INF
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_ys := PackedFloat32Array()
var _leap_len := 0.0
var _leap_across := Vector2.ZERO
var _leap_t := -1.0
var _leap_reel := false
var _leap_home := false
var ring: Node3D = null
var on_meadow := false
## Leaps launched and landed; how long below him unseen, how long close below.
var leaps := 0
var landings := 0
var no_line := 0.0
## The fall's top (y), INF when not falling; the rim's out way (flat) while
## he teeters on it; ripostes' spills.
var _fall_top := INF
var _rim_out := Vector3.ZERO
var spills := 0
var close_below := 0.0
const LEAP_DT := 1.0/240.0
const LeapRing = preload("res://scripts/enemies/leap_ring.gd")
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
	if state == "dead": return
	_read_shots(delta)
	at = position
	_sense()
	cool = maxf(0.0,cool-delta)
	unseen = 0.0 if sees else unseen+delta
	_leap_think(delta)
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
		"to_leap":
			at = _walk_to_leap(at,delta)
		"leap":
			at = _fly_leap(at,delta)
		"skid":
			if _skid_left > 0.0 and on_meadow:
				at = _skid_meadow(at,delta)
			elif _skid_left > 0.0:
				# Constant deceleration to the planned stop: v = v0 sqrt(left/len).
				var v := _skid_v0*sqrt(_skid_left/maxf(_skid_len,0.001))
				var step := minf(maxf(v,0.6)*delta,_skid_left)
				_skid_left -= step
				var to := at+skid_way*step
				if _off_deck(to):
					off_deck = true
					state = "fall"
					fall_v = skid_way*maxf(v,knob("over_push"))
					body.play("fall")
					print("rune knight: skids off the deck at (%.1f, %.1f, %.1f)" % [to.x,to.y,to.z])
					at = to
				else:
					var kept := _keep_on_deck(to)
					if kept.distance_to(to) > 0.01: _skid_left = 0.0
					at = kept
				if state == "skid" and _skid_left <= 0.0: _skid_stopped(at)
		"teeter", "kneel", "down", "reel":
			pass
		"stagger":
			at += push*delta
			push *= exp(-3.0*delta)
			if not off_deck and _off_deck(at):
				off_deck = true
				state = "fall"
				fall_v = push
				body.play("fall")
				print("rune knight: pushed off the deck at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
			elif not off_deck:
				at = _keep_on_deck(at)
		"fall":
			if _fall_top == INF: _fall_top = at.y
			if at.y < _fall_top-(knob("rim_drop") if on_meadow else knob("fall_drop")) and _fall_hit(at,Vector3.DOWN*knob("fall_drop")).is_empty():
				# Over the island's rim, nothing under him: out of sight below, gone.
				print("rune knight: falls past the rim, gone below")
				_die("gone")
				return
			fall_v += Vector3.DOWN*knob("gravity")*delta
			var step := fall_v*delta
			var hit := _fall_hit(at,step)
			if not hit.is_empty() and (hit.normal as Vector3).y < 0.5:
				# A wall (the aqueduct's side): he scrapes down it.
				var nrm: Vector3 = hit.normal
				if fall_v.dot(nrm) < 0.0: fall_v -= nrm*fall_v.dot(nrm)
				at = (hit.position as Vector3)+nrm*0.05
			elif not hit.is_empty():
				at = hit.position
				fall_v = Vector3.ZERO
				push = Vector3.ZERO
				# The body sends `land` once his root stops dropping: he shatters.
				state = "down"
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
				elif sees and cool <= 0.0 and absf(yaw_goal-yaw) < knob("face_ok") and close_below <= 0.0:
					_gather()
	if state != "fall": _fall_top = INF
	yaw = move_toward(yaw,yaw_goal,knob("turn_rate")*delta)
	transform = Transform3D(Basis(Vector3.UP,yaw),at)
	if _room != null: _room.global_transform = Transform3D(Basis.IDENTITY,at)

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
	elif clip == "leap" and state == "leap":
		if beat == "launch": _launch()
		elif beat == "end": _leap_done()
	elif clip == "skid" and beat == "end":
		_skid_ended = true
		if state == "skid" and _skid_left <= 0.0: _skid_stopped(position)
	elif clip == "reel" and beat == "end" and state == "reel":
		print("rune knight: gathers himself out of the reel")
		state = "track"
		cool = knob("throw_gap")
		body.set_effect("rune_glow",false)
		body.play("idle")
	elif clip == "teeter" and beat == "end" and state == "teeter":
		# Caught his balance: back to tracking you (or, broken, to his knee).
		print("rune knight: recovers from the teeter")
		_recover()
	elif clip == "fall" and beat == "land" and state in ["down","fall"]:
		_shatter()
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
	if state in ["catch","return","stagger","fall","skid","teeter","kneel","down","dead","reel","leap"]: return false
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

## A gust shot's ball burst on him (scripts/lock_on/gust_shot.gd): a
## shove, he skids back along its flat way, farther with more strength.
func hit(at: Vector3, way: Vector3, strength := 1.0) -> void:
	var riposte := _riposte()
	_skid(way,_skid_meters(riposte,strength),riposte,riposte)
	print("rune knight: gust shot hit at (%.1f, %.1f, %.1f), strength %.2f, %s (%d hits)" % [at.x,at.y,at.z,strength,"a riposte" if riposte else "skids",hits])

## A shot burst on him: a rally miss (one from in front he let go, past
## his limit or too fast) cracks a rune and skids him far; any other (the
## side, behind, or while he couldn't catch) shoves him back.
func _hit(node: Node, at: Vector3, v: Vector3) -> void:
	if node.has_method("strike"): node.call("strike",at)
	var st = node.get("strength")
	var riposte := _riposte()
	var miss := node.has_meta("missed") or riposte
	_skid(v,_skid_meters(miss,float(st) if st != null else 1.0),miss,riposte)
	print("rune knight: hit at %.1f m/s (%s), skids (%d hits)" % [v.length(),"a riposte" if riposte else ("a rally miss" if miss else "a shove"),hits])

## A hit landing while he reels: a riposte (it cracks and skids as a miss).
func _riposte() -> bool:
	if state != "reel": return false
	ripostes += 1
	return true

## One of his shots parried (scripts/wind_parry.gd): his wind ripped from
## him, he reels, open, till the clip's `end`.
func parried(_shot: Node) -> void:
	if state in ["dead","down","fall","kneel","teeter","skid"]: return
	if state == "leap":
		# His landing's ring parried: he reels as he lands.
		_leap_reel = true
		print("rune knight: his landing's wind parried")
		return
	_drop_gather()
	if caught != null and is_instance_valid(caught) and caught.has_method("absorb"): caught.call("absorb")
	caught = null
	reels += 1
	state = "reel"
	body.set_effect("rune_glow",true)
	body.play("reel")
	print("rune knight: his wind parried, he reels (%d)" % reels)

## A skid's metres: a shove's or a miss's span, by the shot's strength
## (0.6 the weakest gust shot, 1.0 and up the strongest).
func _skid_meters(miss: bool, strength: float) -> float:
	var u := clampf((strength-0.6)/0.4,0.0,1.0)
	if miss: return lerpf(knob("skid_miss_min"),knob("skid_miss_max"),u)
	return lerpf(knob("skid_side_min"),knob("skid_side_max"),u)

## Knocked back `meters` m along `v`'s flat way: a heavy skid, on his
## feet, scraping back and fighting to stop (any gather or held shot
## lost; `crack` a rune cracks). Teetering, any hit puts him over. A skid
## that would carry past the deck's side by KNOBS.teeter_reach or less
## ends at the lip, teetering; farther, it carries him over.
func _skid(v: Vector3, meters: float, crack: bool, riposte := false) -> void:
	if state in ["dead","down"]: return
	if state == "kneel":
		hits += 1
		_crumble()
		return
	if state == "leap":
		# Stone in flight: the hit tells (a crack), it doesn't turn him.
		hits += 1
		if crack and not runes.is_empty():
			var r: String = runes.pop_front()
			cracks += 1
			body.set_effect("rune_crack",true,r)
		return
	_drop_gather()
	if caught != null and is_instance_valid(caught) and caught.has_method("absorb"): caught.call("absorb")
	caught = null
	body.set_effect("rune_glow",false)
	hits += 1
	if crack and not runes.is_empty():
		var rune: String = runes.pop_front()
		cracks += 1
		body.set_effect("rune_crack",true,rune)
		if riposte:
			# The riposte spills it: shards and light pour out of him.
			spills += 1
			body.set_effect("rune_spill",true,rune)
		print("rune knight: the %s rune cracks%s (%d left)" % [rune," and spills" if riposte else "",runes.size()])
	if state == "fall": return
	var flat := Vector3(v.x,0.0,v.z)
	if flat.length() < 0.1: flat = -_forward()
	flat = flat.normalized()
	if state == "teeter":
		off_deck = true
		state = "fall"
		var side: Vector3
		if on_meadow:
			# Over the island's rim: carried out past its last turf first.
			side = _rim_out
			var d := 0.0
			while d < 1.5 and not is_nan(_ground_y(position+side*d)): d += 0.05
			position += side*(d+0.05)
		else:
			var out := _deck_local(position)
			side = (Art.AQ.basis*Vector3(0.0,0.0,signf(out.z) if out.z != 0.0 else 1.0)).normalized()
		fall_v = (side+flat*0.5).normalized()*knob("over_push")
		body.play("fall")
		print("rune knight: hit teetering, goes over")
		return
	# Braced (a shove, or a riposte: never a kill), a skid reaching the
	# lip ends there teetering; on the deck it also turns along it.
	braced = false
	if (not crack or riposte) and not on_meadow: flat = _brace(flat)
	elif (not crack or riposte): braced = true
	skid_way = flat
	skid_from = position
	skid_meters = meters
	skids += 1
	_skid_v0 = sqrt(2.0*knob("skid_decel")*meters)
	_skid_len = meters
	_skid_teeter = false
	var lip := _lip_along(position,flat) if not on_meadow else _rim_along(position,flat,meters+knob("teeter_reach")+0.5)
	if on_meadow: _rim_out = flat
	if lip < meters and (braced or meters-lip <= knob("teeter_reach")):
		_skid_len = maxf(lip,0.0)
		_skid_teeter = true
	_skid_left = _skid_len
	_skid_ended = false
	state = "skid"
	body.play("skid")

## The brace: a shove's flat way turned along the deck till its across
## share is KNOBS.brace_across at most (along the way it leaned, or, square
## across, toward the deck's middle). Braced, a skid that still reaches
## the lip ends there teetering, never over.
func _brace(flat: Vector3) -> Vector3:
	var w := Art.AQ.basis.inverse()*flat
	w.y = 0.0
	if w.length() < 0.001: return flat
	w = w.normalized()
	var most := knob("brace_across")
	if absf(w.z) > most:
		var along := signf(w.x)
		if absf(w.x) < 0.05:
			along = 1.0 if _deck_local(position).x < (Art.HEAD+Art.SNAP)*0.5 else -1.0
		w = Vector3(along*sqrt(1.0-most*most),0.0,signf(w.z)*most)
	braced = true
	var out := Art.AQ.basis*w
	out.y = 0.0
	return out.normalized()

## How far from `at` along `way` (flat) his feet reach the lip
## (KNOBS.teeter_lip of deck_half off the deck's middle), or INF.
func _lip_along(at: Vector3, way: Vector3) -> float:
	var l := _deck_local(at)
	var w := Art.AQ.basis.inverse()*way
	var edge := knob("deck_half")*knob("teeter_lip")
	if absf(w.z) < 0.001: return INF
	var to := (signf(w.z)*edge-l.z)/w.z
	return maxf(to,0.0)

## The skid run out: at the lip he teeters, else he holds the skid's
## recovery till its `end`, then tracks you.
func _skid_stopped(at: Vector3) -> void:
	_skid_left = 0.0
	if _skid_teeter:
		state = "teeter"
		teeters += 1
		body.play("teeter")
		print("rune knight: teeters at the lip (%.1f m skid)" % skid_from.distance_to(at))
		return
	if not _skid_ended: return
	print("rune knight: skid over, %.1f m" % skid_from.distance_to(at))
	_recover()

## Back on his feet after a skid or teeter: tracking you, or, all his
## runes dark, down on one knee.
func _recover() -> void:
	if runes.is_empty():
		state = "kneel"
		body.play("kneel")
		print("rune knight: broken, drops to one knee")
		return
	state = "track"
	cool = knob("throw_gap")
	body.play("idle")

# --- His deaths ---------------------------------------------------------------------

## Hit kneeling: he crumbles to a heap of blocks where he knelt, and the
## last of his wind bursts out of him at you.
func _crumble() -> void:
	_die("crumble")
	var node: Node3D = WindShot.new()
	isle.add_child(node)
	node.global_position = aim_point()
	node.set("strength",knob("burst_strength"))
	node.set("shooter",self)
	node.set("target",isle.get("motor"))
	node.set("flight",WindShot.FLIGHT)
	node.set_meta("parry_gain",knob("burst_gain"))
	var from := node.global_position
	var to := _target()
	if to == Vector3.INF: to = last_seen if last_seen != Vector3.INF else from+_forward()*10.0
	node.call("launch",(to-from).normalized()*knob("burst_speed"),0.0,knob("burst_grace"))
	burst = node
	print("rune knight: crumbles, his last wind bursts out at (%.1f, %.1f, %.1f)" % [to.x,to.y,to.z])

## Landed from a fall off the deck: he shatters on the ground below.
func _shatter() -> void:
	_die("shatter")
	print("rune knight: shatters at (%.1f, %.1f, %.1f)" % [position.x,position.y,position.z])

func _die(how: String) -> void:
	_drop_gather()
	if caught != null and is_instance_valid(caught) and caught.has_method("absorb"): caught.call("absorb")
	caught = null
	death = how
	died_at = position
	state = "dead"
	body.play(how)
	remove_from_group("lock_targets")
	remove_from_group("wind_shot_aim")
	if _room != null:
		_room.queue_free()
		_room = null

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

## Where a fall's step from `at` along `step` meets stone or turf (the
## ray's hit: position, normal), or empty.
func _fall_hit(at: Vector3, step: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = SIGHT_MASK
	ray.from = at
	ray.to = at+step+Vector3.DOWN*0.05
	return get_world_3d().direct_space_state.intersect_ray(ray)

# --- The leap -------------------------------------------------------------------------

## Whether `at` is on the turf: a ray down from over it meets turf (layer
## 11, not stone) facing up; the hit or empty.
func _turf_at(at: Vector3, over := 3.0, under := 30.0) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = SIGHT_MASK
	ray.from = at+Vector3.UP*over
	ray.to = at+Vector3.DOWN*under
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.8: return {}
	var c = hit.collider
	if not c is CollisionObject3D or ((c as CollisionObject3D).collision_layer & (1 << 11)) == 0: return {}
	return hit

## Whether he could stand on the turf at `ground` with nothing of stone
## round him up to `tall_` m: the turf level under his room's rim (within
## half a metre) and a column of his room's width (plus KNOBS.leap_clear)
## clear of stone.
func _clear_stand(ground: Vector3, tall_: float) -> bool:
	var r: float = float(_shape.radius)+knob("leap_clear")
	for k in range(6):
		var a := float(k)/6.0*TAU
		var rim := _turf_at(ground+Vector3(cos(a),0.0,sin(a))*r,1.5,2.0)
		if rim.is_empty() or absf((rim.position as Vector3).y-ground.y) > 0.5: return false
	var box := BoxShape3D.new()
	box.size = Vector3(r*2.0,maxf(tall_-0.4,0.5),r*2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = 1
	q.transform = Transform3D(Art.AQ.basis,ground+Vector3.UP*(0.4+box.size.y*0.5))
	return get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()

## His leap spots, found once from the aqueduct's real shape: every
## KNOBS.leap_step m along the deck, each side, KNOBS.leap_out m past his
## room off the deck's side, where the turf lies under the deck (no void,
## no stone) and the column up to the deck is clear of stone (the
## buttress, a pier's footing, the stair), and off the plane's landing
## run.
func _find_spots() -> void:
	_spots_found = true
	leap_spots.clear()
	var off := knob("deck_half")+float(_shape.radius)+knob("leap_out")
	var deck_y := Art.TOP+Art.DECK
	var x := Art.HEAD+1.0
	while x <= Art.SNAP-1.0:
		for side: float in [-1.0,1.0]:
			var top := Art.AQ*Vector3(x,Art.DECK,side*off)
			var hit := _turf_at(top,1.0,Art.DECK+6.0)
			if hit.is_empty(): continue
			var g: Vector3 = hit.position
			if g.y > deck_y-4.0 or _on_strip(g): continue
			if not _clear_stand(g,deck_y-g.y): continue
			leap_spots.append({"at":g,"side":side,"x":x})
		x += knob("leap_step")
	print("rune knight: %d leap spots" % leap_spots.size())

## Whether `p` lies on the plane's landing run: the turf ahead of where it
## parks (the isle's parked_at/parked_heading; WorldScale `gap` wide, from
## behind its tail to well ahead), kept clear (AGENTS.md).
func _on_strip(p: Vector3) -> bool:
	if isle == null or isle.get("parked") != true: return false
	var at: Vector3 = isle.get("parked_at")
	var h: float = isle.get("parked_heading")
	var fwd := Vector3(-sin(h),0.0,-cos(h))
	var off := Vector3(p.x-at.x,0.0,p.z-at.z)
	var along := off.dot(fwd)
	return along > -12.0 and along < 80.0 and absf(off.dot(Vector3(fwd.z,0.0,-fwd.x))) < WorldScale.gap()*0.5

## The spot on `side` (0: either) nearest along the deck to deck x `x`,
## or {} none.
func _spot_near(x: float, side: float) -> Dictionary:
	if not _spots_found: _find_spots()
	var best := {}
	var d := INF
	for s: Dictionary in leap_spots:
		if side != 0.0 and float(s.side) != side: continue
		var e := absf(float(s.x)-x)
		if e < d:
			d = e
			best = s
	return best

## Whether the wanderer stands on the deck (over it, by the deck's top).
func _on_deck(feet: Vector3) -> bool:
	return not _off_deck(feet) and feet.y > Art.TOP+Art.DECK-0.6

## Each frame: whether to leap. On the deck tracking you, with you on the
## meadow near the aqueduct and no clean line on you KNOBS.leap_wait s (or
## close below him KNOBS.leap_close_wait s), he goes down to you. On the
## meadow tracking, with you on the deck, he goes up below you; with you
## unseen KNOBS.home_wait s, he goes home.
func _leap_think(delta: float) -> void:
	if not state in ["track","notice","gather","slash","throw"] or death != "":
		no_line = 0.0
		close_below = 0.0
		return
	var motor = isle.get("motor") if isle != null else null
	var chest := _target()
	if chest == Vector3.INF: return
	var feet: Vector3 = motor.feet
	if on_meadow:
		if state != "track": return
		if _on_deck(feet):
			var s := _spot_near(_deck_local(feet).x,signf(_deck_local(position).z))
			if not s.is_empty(): _go_up(s,false)
		elif unseen > knob("home_wait"):
			var s := _spot_near(_deck_local(position).x,signf(_deck_local(position).z))
			if not s.is_empty(): _go_up(s,true)
		return
	if off_deck: return
	var l := _deck_local(feet)
	var below := feet.y < position.y-3.0 and absf(l.z) < knob("leap_reach") and l.x > Art.HEAD-4.0 and l.x < Art.SNAP+4.0
	no_line = no_line+delta if below and not sees else 0.0
	var flat := Vector2(feet.x-position.x,feet.z-position.z).length()
	close_below = close_below+delta if below and flat < knob("leap_close") else 0.0
	if state == "track" and (no_line > knob("leap_wait") or close_below > knob("leap_close_wait")):
		var s := _spot_near(l.x,signf(l.z) if l.z != 0.0 else 1.0)
		if not s.is_empty(): _go_down(s,feet)

## Down to `feet` from spot `s`: he walks along the deck to over it, then
## leaps, landing KNOBS.leap_short m short of you (at most KNOBS.leap_far
## m out from the spot), where turf takes him; else on the spot.
func _go_down(s: Dictionary, feet: Vector3) -> void:
	var base: Vector3 = s.at
	var way := Vector3(feet.x-base.x,0.0,feet.z-base.z)
	var d := clampf(way.length()-knob("leap_short"),0.0,knob("leap_far"))
	var land := base
	if d > 0.5:
		var hit := _turf_at(base+way.normalized()*d,6.0,10.0)
		if not hit.is_empty() and not _on_strip(hit.position) and _clear_stand(hit.position,float(_shape.height)):
			land = hit.position
	_start_leap("down",Art.AQ*Vector3(float(s.x),Art.DECK,float(s.side)*knob("deck_half")*0.55),land,false)
	print("rune knight: goes down to you, over (%.1f, %.1f, %.1f) to (%.1f, %.1f, %.1f)" % [_leap_goal.x,_leap_goal.y,_leap_goal.z,land.x,land.y,land.z])

## Up from spot `s` to the deck over it (`home`: then to his patrol).
func _go_up(s: Dictionary, home: bool) -> void:
	_start_leap("up",s.at,Art.AQ*Vector3(float(s.x),Art.DECK,float(s.side)*0.3),home)
	print("rune knight: goes %s, to the spot at (%.1f, %.1f, %.1f)" % ["home" if home else "up to you",_leap_goal.x,_leap_goal.y,_leap_goal.z])

func _start_leap(form: String, from: Vector3, to: Vector3, home: bool) -> void:
	_drop_gather()
	leap_form = form
	_leap_goal = from
	_leap_to = to
	_leap_home = home
	_leap_reel = false
	_leap_t = -1.0
	no_line = 0.0
	close_below = 0.0
	state = "to_leap"
	body.play("walk")

## Walking to the launch point (on the deck along it, on the meadow over
## the turf); there, he faces his landing and crouches into the leap.
func _walk_to_leap(at: Vector3, delta: float) -> Vector3:
	var off := Vector3(_leap_goal.x-at.x,0.0,_leap_goal.z-at.z)
	var left := off.length()
	if left < 0.05:
		at = Vector3(_leap_goal.x,at.y,_leap_goal.z)
		var look := _leap_to-at
		if leap_form == "down" and last_seen != Vector3.INF: look = last_seen-at
		yaw_goal = yaw+wrapf(_yaw_to(look)-yaw,-PI,PI)
		state = "leap"
		body.play("leap",leap_form)
		print("rune knight: crouches to leap %s" % leap_form)
		return at
	yaw_goal = yaw+wrapf(_yaw_to(off)-yaw,-PI,PI)
	# He turns before he walks off (planted, not sliding sideways).
	if absf(yaw_goal-yaw) > 0.6: return at
	at += off/left*minf(float(_shape.pace)*delta,left)
	if on_meadow:
		var g := _turf_at(at,1.5,3.0)
		if not g.is_empty(): at.y = (g.position as Vector3).y
	return at

## The launch (the body's `launch`): the arc from here to the landing, its
## heights sampled; the landing's ring set where he will come down.
func _launch() -> void:
	_leap_from = position
	var g := knob("gravity")
	var hang := knob("leap_hang")
	var hv := knob("leap_hang_v")
	var top := maxf(_leap_from.y,_leap_to.y)+knob("leap_rise_up" if leap_form == "up" else "leap_rise_down")
	var h := top-_leap_from.y
	var h2 := hv*hv/(2.0*g*hang)
	var v := sqrt(2.0*g*(h-h2)+hv*hv) if h > h2 else sqrt(2.0*g*hang*h)
	var y := _leap_from.y
	_leap_ys = PackedFloat32Array([y])
	var t := 0.0
	var above_from := -1.0
	var above_to := -1.0
	var lip := _leap_to.y+0.3 if leap_form == "up" else _leap_from.y+0.2
	while t < 6.0:
		v -= g*(hang if absf(v) < hv else 1.0)*LEAP_DT
		y += v*LEAP_DT
		t += LEAP_DT
		if v < 0.0 and y <= _leap_to.y:
			_leap_ys.append(_leap_to.y)
			break
		_leap_ys.append(y)
		if y >= lip and above_from < 0.0: above_from = t
		if y >= lip: above_to = t
	_leap_len = t
	# His feet go across while he is over the lip (up: from clearing it to
	# the touchdown; down: off the deck before he drops past it).
	if leap_form == "up": _leap_across = Vector2(maxf(above_from,0.0),t)
	else: _leap_across = Vector2(0.0,maxf(above_to,t*0.3))
	_leap_t = 0.0
	leaps += 1
	ring = LeapRing.new()
	isle.add_child(ring)
	ring.global_position = _leap_to
	ring.set("shooter",self)
	ring.set("target",isle.get("motor"))
	ring.set("strength",knob("leap_ring_strength"))
	ring.set("reach",knob("leap_ring"))
	ring.set("tall",float(_shape.height))
	ring.set("eta",_leap_len)
	print("rune knight: leaps %s, %.2f s aloft, top %.1f m" % [leap_form,_leap_len,top])

## In the air: along the sampled arc, across in its span; at the
## touchdown the ring goes off and he is on the deck or the meadow.
func _fly_leap(at: Vector3, delta: float) -> Vector3:
	if _leap_t < 0.0: return at
	_leap_t = minf(_leap_t+delta,_leap_len)
	var i := _leap_t/LEAP_DT
	var i0 := mini(int(i),_leap_ys.size()-1)
	var i1 := mini(i0+1,_leap_ys.size()-1)
	var y := lerpf(_leap_ys[i0],_leap_ys[i1],i-float(int(i)))
	var u := smoothstep(_leap_across.x,_leap_across.y,_leap_t) if _leap_across.y > _leap_across.x else 1.0
	var flat := Vector3(_leap_from.x,0.0,_leap_from.z).lerp(Vector3(_leap_to.x,0.0,_leap_to.z),u)
	at = Vector3(flat.x,y,flat.z)
	if ring != null and is_instance_valid(ring): ring.set("eta",_leap_len-_leap_t)
	if _leap_t >= _leap_len:
		at = _leap_to
		_leap_t = -1.0
		landings += 1
		on_meadow = leap_form == "down"
		off_deck = on_meadow
		if ring != null and is_instance_valid(ring): ring.call("touch")
		ring = null
		print("rune knight: lands at (%.1f, %.1f, %.1f)" % [at.x,at.y,at.z])
	return at

## The leap's `end`: reeling if its ring was parried, home to his patrol,
## or tracking you.
func _leap_done() -> void:
	if _leap_t >= 0.0: return
	if _leap_reel:
		_leap_reel = false
		state = "track"
		parried(null)
		return
	if _leap_home and not on_meadow:
		_turn_to(_yaw_to(ends[heading_to]-position))
		return
	state = "track"
	cool = minf(cool,knob("throw_gap")*0.5)
	body.play("idle")

## Ground under `p` for a meadow skid: turf, or anything within
## KNOBS.rim_depth below; its y, or NAN past the island's rim.
func _ground_y(p: Vector3) -> float:
	var g := _turf_at(p,1.0,1.5)
	if not g.is_empty(): return (g.position as Vector3).y
	var any := _fall_hit(p+Vector3.UP*1.0,Vector3.DOWN*(1.0+knob("rim_depth")))
	if any.is_empty(): return NAN
	return (any.position as Vector3).y

## How far from `at` along `way` (flat) the ground under him lasts before
## the island's rim (the last step with ground), or INF within `most` m
## (or stone stops him first).
func _rim_along(at: Vector3, way: Vector3, most: float) -> float:
	var step := knob("rim_step")
	var d := step
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	ray.from = at+Vector3.UP*height*0.4
	ray.to = ray.from+way*(most+float(_shape.radius))
	var wall := get_world_3d().direct_space_state.intersect_ray(ray)
	var stop := most if wall.is_empty() else minf(most,ray.from.distance_to(wall.position as Vector3)-float(_shape.radius))
	while d <= stop:
		if is_nan(_ground_y(at+way*d)): return maxf(d-step,0.0)
		d += step
	return INF

## A skid on the meadow: over the turf, its lip the island's rim; stone in the way (the
## aqueduct's wall) stops it; the turf falling away under him, he falls.
func _skid_meadow(at: Vector3, delta: float) -> Vector3:
	var v := _skid_v0*sqrt(_skid_left/maxf(_skid_len,0.001))
	var step := minf(maxf(v,0.6)*delta,_skid_left)
	_skid_left -= step
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	ray.from = at+Vector3.UP*height*0.4
	ray.to = ray.from+skid_way*(step+float(_shape.radius))
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		print("rune knight: skids into stone")
		_skid_left = 0.0
		_skid_stopped(at)
		return at
	var to := at+skid_way*step
	var gy := _ground_y(to)
	if is_nan(gy):
		state = "fall"
		fall_v = skid_way*maxf(v,knob("over_push"))
		body.play("fall")
		print("rune knight: skids over the island's rim at (%.1f, %.1f, %.1f)" % [to.x,to.y,to.z])
		return to
	to.y = gy
	if _skid_left <= 0.0: _skid_stopped(to)
	return to
