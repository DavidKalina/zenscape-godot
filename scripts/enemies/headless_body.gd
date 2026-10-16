extends "res://scripts/enemies/enemy.gd"
## The headless body: the
## inhaler head's (scripts/enemies/inhaler_head.gd) lost stone body, a
## hulking Olmec figure of masonry with an empty neck stump, walking the
## isles to find its head. Round 3 gave it
## its model and authored clips (scripts/enemies/headless_body_look.gd,
## art/blender/headless_body/headless_body_build.py), driven from these
## states; its hands are put on the real wall and lip on top of them.
##
## Sized off its head (`head_size` of the walker's heights, the model's head;
## the head it wears is drawn smaller, its own `size` knob 2.6, to fit the
## body): legs, torso, arms, breadth in head heights. The walker's numbers come from enemy_field.gd
## `numbers()` (AGENTS.md, Sizes).
##
## In states (`state`):
##   "listen"  it stands, turns its stump one way and the other, a hand
##             cupped by where its ear was: it hears the head (within
##             `hear` m) and turns to its bearing, off by up to `noise` rad,
##             less the nearer it is. Out of hearing it picks any way, and
##             any way too while lost (no nearer the head for `lost_after`
##             s: it wanders `lost_for` s, then hears afresh).
##   "roam"    it walks the way it heard, heavily, `walk` m/s; every
##             `listen_every` s (give or take) it stops to listen again.
##   "home"    the head is within `sense` m with nothing between its neck
##             and the head: it has it. It lifts its arms and strides
##             straight for it at `home` m/s (a tell: the body warms).
##   "climb"   a wall too tall to step stands in its way and the head is
##             above it (it hears it up there): it faces the wall and goes
##             up it hand over hand at `climb` m/s, its rays on the real
##             wall (the face held `standoff` off, the lip found by a ray
##             down past the face from over its reach). A wall taller than
##             `climb_max`, it does not take.
##   "mantle"  its hands over the lip: it hauls itself up and rolls over
##             onto the top (`mantle` s).
##   "windup"  at an edge: a ledge across the gap at about its height
##             (`jump_gap` Hh across at most, `jump_rise` Hh up, `jump_sink`
##             Hh down) it jumps to ("jump"); failing that, a lower floor
##             out along its way within `leap_max` m across and `drop_max` m
##             down it drops to ("drop"), headless and not lost never more
##             than `drop_under` m under its head's ground (off here; the
##             generator's bodies set it). It crouches, arms back,
##             `windup` s.
##   "leap"    the throw: a ballistic arc (`leap_up` m over the takeoff, a
##             jump's higher by `jump_arc` of its length) to that floor, its
##             feet ray-cast along the arc; a wall on the way stops it dead
##             and it drops.
##   "land"    a heavy landing, squashed for `land` s; dust, a quake and a
##             shockwave (`_shock`) running out along the ground: a walker
##             on the ground as the front passes him is thrown back and up,
##             less the farther out; one in the air over it is clear. The
##             mantle's end sends a smaller one.
## Set down by `cling` it starts on a cliff face, climbing, out of sight
## under the lip, and hauls itself over.
##   "fall"    walked off something unseen: it falls (below the study's
##             `lost`, it is gone).
##   "reach"   the head is in arm's reach: it stops, faces it and lifts its
##             arms; the head comes down onto its neck over `settle` s.
##   "triumph" whole again: a beat of triumph, `triumph` s, then on.
## Reunited (`whole`), it walks on whole, the head on its shoulders (eyes
## lit, its breath stopped), roaming any way, climbing and leaping still.
##
## The walker: it is a stone he stands on and rides (the base's box); walked
## into while it moves (or met by its shockwave), he is shoved through his
## own motor (PilotMotor.knock). No damage. He can't push it.
## Round 2.
##
## Whole, with `chase` on (off but in studies/whole_body_chase.tscn), it hunts the walker:
## it sees him (`sight`, scripts/enemies/body_sight.gd, the dragon's sight at
## its scale), and spotted, comes for him:
##   "alert"   suspicious: it stops and turns to where it glimpsed him.
##   "chase"   spotted: it strides at him (`chase_speed`, slower than his
##             run), climbing a wall he is up on, skirting one he isn't,
##             leaping a gap he crossed; lost from sight, to where it last
##             saw him. On the way, by his flat distance (seen):
##               within `catch_reach` Hh: "swat";
##               `pounce_min`-`pounce_max` Hh, a clear arc, rested: the
##               pounce ("windup" then "leap", aimed at him till `pounce_lock`
##               s before it goes; landing on him catches him);
##               `suck_min`-`suck_max` Hh, its mouth clear to him, rested:
##               "plant" (`suck_tell` s, the jaw opening), "suck" (the
##               head's inhale, `suck_for` s; at its feet he is swallowed:
##               "gulp" while its head holds him, then blasts him out),
##               then "spent";
##               otherwise it walks.
##   "swat"    arms up `swat_windup` s, then the fists down: within reach he
##             is knocked down (`swat_out`, `swat_up`, `swat_down`).
##   "seek"    where it last saw him, it looks about `search_for` s; then
##   "return"  it walks back to where it was set down, and roams on.

signal reunited(enemy)
## The chase's beats (whole, `chase` on): "spotted", "lost", "gave up",
## "pounce", "suck", "gulped", "blown out", "swat", "caught ...", "missed".
signal chase_beat(what: String)
## His weight come down: at `at`, `power` (a
## mantle 0.5, a leap's landing 1 or more), `kind` ("haul", "land",
## "pounce"): the isle under him tips (scripts/enemies/olmec_tilt.gd).
signal weighed(at: Vector3, power: float, kind: String)

const Look = preload("res://scripts/enemies/headless_body_look.gd")
const Dust = preload("res://scripts/enemies/body_dust.gd")
const Routes = preload("res://scripts/enemies/body_routes.gd")
const Sight = preload("res://scripts/enemies/body_sight.gd")
const Hearing = preload("res://scripts/enemies/body_hearing.gd")
const OlmecVoid = preload("res://scripts/enemies/olmec_void.gd")

## The head it looks for (found among the field's enemies: the one with a mouth).
var head: Node3D = null
## Where its own head was set down (InhalerHead `home()`), where a field
## holds several heads (scripts/enemies/body_spawner.gd); INF any head.
var head_home := Vector3.INF
## Reunited: the head on its neck.
var whole := false
## Counted, for the HUD and checks.
var climbs := 0
var leaps := 0
## Of the leaps, those ledge to ledge.
var jumps := 0
var listens := 0
## Shockwaves sent, and those that threw the walker.
var shocks := 0
var shock_hits := 0
## The last leap's kind ("jump" ledge to ledge, "drop" down), for the HUD.
var leap_kind := ""
## Climbing up from a cliff spawn (cleared once it is over the lip).
var spawned_on_cliff := false
## Came up a far cliff, in the walker's view (body_spawner.gd `pick_far`).
var far_spawn := false
## Hands put on the face climbing (each a puff of dust, stones knocked off).
var grips := 0
var homed := false
## The camera's quake now (m), from its landings.
var quake := 0.0
## Head heights (m): the head's; legs, torso, neck (top of the stump's cut).
var hh := 1.0
var legs_h := 1.0
var torso_h := 1.0
var neck_h := 1.0
var arm_l := 1.0
var _heading := 0.0
var _next_listen := 0.0
var _rng := RandomNumberGenerator.new()
var _phase := 0.0
var _step_side := 0.0
var _climb_from := 0.0
var _lip_y := INF
var _face_pt := Vector3.ZERO
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _listen_from := 0.0
var _picked := false
var _unsensed := 0.0
## Lost (round 9): its nearest yet to the head (m) and the time since it
## got nearer; `lost_after` s without, it wanders any way for `lost_for` s.
var _best_d := INF
var _since_better := 0.0
## Its nearest ever to the head, and the time since (s): the spawner takes
## a body stalled too long away, out of sight (scripts/enemies/
## body_spawner.gd).
var _best_ever := INF
var stalled := 0.0
var _seat_from := Vector3.ZERO
var _seat_k := 1.0
## Round 11, its route (scripts/enemies/body_routes.gd): the places it
## fits and its moves between them, the search running, the route's legs
## ({kind, to, from, node, from_node, d}), the leg it is on and its time on
## it walking, the goal planned for, the moves it found it couldn't make.
## Counted: plans, legs given up, routes that got to the goal or only near
## it, bail-outs, lips it climbed on from.
var routes: Routes = null
var _search: Routes.Search = null
var _route: Array = []
var _leg := 0
var _leg_t := 0.0
var _goal := Vector3.INF
var _banned := {}
var plans := 0
var leg_fails := 0
var routed_to := 0
var routed_near := 0
var bails := 0
var perches := 0
## Why the last leg was given up, for checks.
var fail_why := ""
var _fall_from := Vector3.INF
var _fall_t := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
## The model and its clips.
var look: Look
var _clock := 0.0
## The leap's time in the air (s), the landing's clip, the haul's own clock,
## the slap of its hands onto the lip (s since, -1 not yet), the lip it
## mantles over, the cross-fade into the state now, the state it had.
var _flight := 1.0
var _land_clip := "land"
var _haul_t := 0.0
var _grab_t := -1.0
var _mantle_lip := Vector3.ZERO
var _fade := 0.2
var _was := ""
var _snap := true
var _triumph_thud := false
## Round 4: the wall it feels before a climb.
var _feel_hit := {}
## This mantle a pull-up (round 4), and its landing come.
var _pull := false
var _mantle_landed := false
## Hanging from the lip, still, before the pull (round 4, `mantle_pull`).
var _hang := false
## When its feel began (s into the state; -1 while it still steps round to
## the wall: it squares up first, FEEL_WAIT s at most).
var _feel_from := -1.0
var _dust: Array = []
## Live shockwaves: {at, r, max, power, done (the walker met), parts}.
var _waves: Array = []
## The Olmec's destruction:
## what he breaks (scripts/kit_isle/colonnade_breaks.gd), or null. What
## still stands of it is left out of his rays (he plans and walks through
## it), his bulk and his shockwaves break it (`met`, `wave`), and the
## rubble once settled is read afresh (`world_changed`).
var breaker: Object = null
## A stagger after he plows through something (s left): slowed, not stopped.
var _stagger := 0.0
const STAGGER := 0.5
## The reach the route he is on was planned to (for planning it again).
var _goal_reach := 3.0
## Round 2: a wall square across his way
## (the breaker's `ahead`) he punches through: "smash", feet planted and
## fists up SMASH_WINDUP s, the hit (`smash`), then straight on in the
## state he was in, SMASH_AFTER s on. Slowed through it, never stopped.
const SMASH_WINDUP := 0.42
const SMASH_AFTER := 0.18
const SMASH_EASE := 2.6
var _smash_from := ""
var _smash_hit := false
var smashes := 0
## Olmec threat round 1: the masonry breaker (scripts/enemies/
## olmec_breach.gd, set by scripts/roguelike/layer_olmec.gd) and the wall
## hit it smashes through now ({} none); scents taken (relentless).
var breacher: Object = null
var _breach_hit := {}
var breaches := 0
var scents := 0
func _init() -> void:
	cost = 5
	tags = PackedStringArray(["heavy","climbs","leaps","pushes"])
	tell_sound = &"body_found"
	rest_colour = Color(0.56,0.53,0.48)
	mark_colour = Color(0.85,0.62,0.32)

func default_knobs(n: Dictionary) -> Dictionary:
	return {
		"head_size":3.0,"legs":0.75,"torso":1.2,"breadth":1.3,"depth":0.72,"arm":1.1,
		"walk":n.walk*0.9,"home":n.run*0.7,"accel":3.0,"turn":0.9,"step":n.unit*1.1,"look":0.9,
		"listen":2.6,"listen_every":7.0,"lost_after":20.0,"lost_for":15.0,"hear":n.unit*80.0,"sense":n.unit*15.0,"noise":0.35,"lose":2.0,
		"climb":n.unit*1.25,"haul":0.55,"climb_max":n.unit*20.0,"standoff":0.25,"lip_in":0.8,"mantle":1.4,
		"leap_max":n.unit*11.0,"drop_max":n.unit*20.0,"drop_under":INF,"windup":1.1,"leap_up":n.unit*1.6,"land":1.0,
		# Round 11: a drop goes further
		# across the deeper it is (`leap_fall` m a m down, `leap_far` at
		# most), so it leaps down onto another isle.
		"leap_far":n.unit*20.0,"leap_fall":0.6,
		# Its routes over places it fits (scripts/enemies/body_routes.gd):
		# 1 on, 0 round 9's bearing and turns. A leg not made in
		# `leg_slack` s walking is given up and the way planned again
		# without it.
		"routes":1,"leg_slack":6.0,
		"leap_gravity":n.gravity*0.7,
		# Ledge to ledge: a gap up to `jump_gap` Hh, onto a ledge up to
		# `jump_rise` Hh over or `jump_sink` Hh under its feet; the arc
		# peaks `jump_arc` of the way's length over the takeoff.
		"jump_gap":3.0,"jump_rise":0.5,"jump_sink":1.5,"jump_arc":0.22,
		"shove_out":n.unit*5.0,"shove_up":n.unit*1.0,
		# Shockwaves: radius in Hh, speed of the front, the shove at the
		# middle (m out, m up), its share left at the rim, the band over
		# the wave's ground that is hit (a walker higher off the ground
		# than `shock_air` m as it passes is jumped clear).
		"shock_r":4.0,"shock_speed":n.unit*16.0,"shock_out":n.unit*9.0,"shock_up":n.unit*2.2,
		"shock_edge":0.2,"shock_band":n.unit*1.7,"shock_air":n.unit*0.45,"shock_mantle":0.5,
		"cling":1.0,
		"reunite":n.unit*1.6,"settle":2.2,"whole_climb":0.6,"seed":1,
		# Round 3, the clips: a step's length walking and striding home (Hh;
		# the clips are made for these, other values slide the feet), and
		# the beat of triumph once whole (s; it was straight to listening).
		"stride":Look.WALK_STEP,"stride_home":Look.STRIDE_STEP,"triumph":1.8,
		# The whole body's chase: 1 on (its
		# study's), 0 off (as ever: whole, it roams). Ranges in Hh, flat.
		"chase":0,"chase_speed":n.run*0.9,"chase_turn":1.8,"chase_memory":16.0,
		"sight_range":n.unit*40.0,"sight_half":0.9,"sight_near":n.unit*14.0,"sight_fill":1.4,"sight_grace":1.0,"sight_drain":0.3,
		"search_for":12.0,"search_reach":n.unit*2.5,"return_for":30.0,
		"catch_reach":1.3,"swat_windup":0.55,"swat_after":0.7,"swat_out":n.unit*9.0,"swat_up":n.unit*2.5,"swat_down":1.2,
		"pounce_min":1.6,"pounce_max":4.5,"pounce_rise":1.0,"pounce_sink":1.5,"pounce_windup":0.8,"pounce_lock":0.3,
		"pounce_arc":0.3,"pounce_rest":3.0,"pounce_hit":n.unit*2.0,"pounce_shock":0.7,
		"suck_min":4.5,"suck_max":7.0,"suck_tell":1.2,"suck_for":5.0,"suck_rest":7.0,"suck_turn":0.6,"suck_lose":1.0,
		"suck_gulp":n.unit*1.5,"spent":1.2,
		# Leap up and grab: 1 on (whole,
		# with `chase` on), 0 off. A lip at most `grab_up` Hh over its feet,
		# its hang point at most `grab_out` Hh off flat; `grab_windup` s
		# crouched; caught if the lip is within `grab_tol` m of where it
		# reaches; `grab_hang` s hanging, swinging, before it hauls.
		"leap_grab":0,"grab_up":4.5,"grab_out":2.5,"grab_windup":1.0,"grab_tol":n.unit*1.0,"grab_hang":0.9,
		"grab_rest":2.0,"grab_lean":0.14,
		# Round 4: before a climb it
		# feels the wall, a hand laid flat on it, `feel` s (0 skips it).
		"feel":1.0,
		# Round 4: over the lip. 1: no haul. It climbs hand over hand till
		# its hands reach the lip, slaps them onto it, hangs still a beat
		# (PULL_AFTER s) and springs up by a pull-up (a lip low over its
		# feet, by a press-up). 0: round 3's haul up the face till the lip
		# is at its chest, then the press-up.
		"mantle_pull":1,
		# The periscope: 1 on (whole, with
		# `chase` on: always, the generator included), 0 off. Its sight lost, it lifts
		# its head
		# overhead (`scope_lift` s), turns it `scope_sweep` rad either way
		# about where it lost him over `scope_look` s, and lowers it
		# (`scope_lower` s); seen `scope_spot` s from up there, he's found
		# (and drawn in, in reach). Once a loss, `scope_rest` s apart; lost
		# `scope_wait` s within `scope_near` Hh of where it last saw him it
		# plants at once. It leans `scope_lean` rad out over low cover.
		"periscope":1,"scope_lift":1.7,"scope_look":5.0,"scope_lower":1.6,"scope_sweep":1.0,"scope_wide":1.5,"scope_spot":0.35,
		"scope_rest":8.0,"scope_near":1.6,"scope_wait":1.0,"scope_lean":0.38,
		# Light: in the dark (scripts/enemies/
		# light_level.gd) its sight reaches `sight_dark_range` of
		# `sight_range` and sees `sight_dark_seen` of him, eased up to all
		# as he is lit; a light's glow on him (his torch, a lit beacon) makes
		# him up to `sight_glow` times plainer. By day, no change.
		"sight_dark_range":0.4,"sight_dark_seen":0.3,"sight_glow":1.3,
		# 1: walker-only stone (scripts/walker_only.gd) blocks its sight (he
		# hides in a niche it can't reach; the default since city-refuges
		# round 1); 0: it looks through it, as it walks through it.
		"sight_walker_only":1,
		# Beacons (scripts/enemies/beacon.gd): 1 it turns to a lit one in
		# its draw and goes there, 0 it pays them no heed. Looked at its
		# `dwell`, it tires of that one `beacon_rest` s (lit again: news).
		"beacons":1,"beacon_rest":40.0,
		# City breaks round 1:
		# 1 on, 0 off (as ever). Hunting, an edge with no leap across and him
		# beyond it: a route over places it fits to him (its planner's, as
		# roaming's: a column felled across a gap is a way), walked, climbed
		# and leapt; none, it tries again `chase_replan` s on.
		"chase_routes":0,"chase_replan":3.0,
		# Climbing after him:
		# 1 on (the default, wherever he hunts), 0 off (as before: lost
		# up a wall or a stair, he scopes and gives up at the foot). Lost
		# from sight up out of his walk (or him last seen going up), he
		# plans a route (his planner's: walk, climb in `climb_max`, leap)
		# to the place he fits nearest where he last saw him, climbs after
		# him, comes over the top and looks; still not there, on along his
		# way up `after_ahead` m. `after_tries` routes a loss at most, none
		# once `after_for` s unseen.
		"climb_after":1,"after_tries":3,"after_for":60.0,"after_ahead":n.unit*10.0,"after_wait":0.6,
		# Olmec threat round 1:
		# `relentless` 1 (the generator's), 0 off (as before). Whole, the hunt
		# never falls back to idle searching: the head going on is a beat and
		# he knows where you are; lost, he looks `hunt_search` s, then takes
		# your scent (where you are now) and comes on. Hunting he sees
		# further and wider (`hunt_range` m, `hunt_half` rad), loses you
		# slower (`hunt_grace` s, `hunt_drain`, `hunt_memory` s) and the dark
		# hides you less (`hunt_dark_range`, `hunt_dark_seen`: the torch
		# matters for being spotted, not once he is on you). He leaps gaps
		# to `hunt_gap` Hh. His leap's landing comes down `hunt_shock`
		# times harder. `void_push`: a shove (his waves, his blast) bent
		# this share toward the nearest void within VOID_REACH.
		"relentless":0,"hunt_range":n.unit*60.0,"hunt_half":1.25,"hunt_grace":2.5,"hunt_drain":0.12,"hunt_memory":30.0,
		"hunt_dark_range":0.85,"hunt_dark_seen":0.8,"hunt_gap":4.6,"hunt_rise":0.9,"hunt_search":4.0,"hunt_shock":1.35,"void_push":0.0,
		# `breach` 1: hunting, a city wall, pillar or parapet in his way
		# (not over him: he climbs to you) he smashes through
		# (scripts/enemies/olmec_breach.gd, his `breacher`), not round.
		"breach":0,
	}

## Its build (m) from its knobs `k` and the walker's `unit`, as `_size` and
## `cling` make it, for those that plan round it without one (scripts/
## roguelike/layer_bodies.gd): {hh, neck, arm, length, width, hang (lip to
## its feet, hung by `cling`), chest (its chest ray over its feet)}.
static func build_of(k: Dictionary, unit: float) -> Dictionary:
	var h := float(k.head_size)*unit
	var neck := h*(float(k.legs)+float(k.torso))
	var arm := h*float(k.arm)
	return {"hh":h,"neck":neck,"arm":arm,"length":h*float(k.depth),"width":h*float(k.breadth),
		"hang":neck+arm*0.75+float(k.cling),"chest":neck*0.55}

## Its build in head heights: the box the walker meets is its torso's
## breadth and depth, up to the neck.
func _size(n: Dictionary) -> void:
	hh = float(knobs.head_size)*n.unit
	legs_h = hh*float(knobs.legs)
	torso_h = hh*float(knobs.torso)
	neck_h = legs_h+torso_h
	arm_l = hh*float(knobs.arm)
	width = hh*float(knobs.breadth)
	length = hh*float(knobs.depth)
	height = neck_h

func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
	super.setup(host,at,face,overrides)
	_rng.seed = int(knobs.seed)
	_post = at
	_heading = facing
	grounded = true
	_go("listen")

## Set on a cliff face, already climbing: `lip` the top edge of the face
## over it, `out` (x, z) the face's outward way. Its raised hands sit `cling`
## m under the lip, so none of it shows over the top till it hauls up;
## `below` m lower still, it climbs that much of the face first (a far
## spawn, `far`, seen from across a gulf: a rumble as it sets off).
func cling(lip: Vector3, out: Vector2, below := 0.0, far := false) -> void:
	var n := out.normalized()
	facing = PilotMotor.facing_of(-n)
	rotation.y = facing
	position = Vector3(lip.x,lip.y-(neck_h+arm_l*0.75)-float(knobs.cling)-below,lip.z)+Vector3(n.x,0.0,n.y)*(length*0.5+float(knobs.standoff))
	far_spawn = far
	# Its post (the chase's way back) is the top it comes over onto.
	_post = Vector3(lip.x,lip.y,lip.z)-Vector3(n.x,0.0,n.y)*(length+1.0)
	if far: field.sound(&"body_rumble",position)
	grounded = false
	vel = Vector3.ZERO
	_climb_from = position.y
	_lip_y = INF
	climbs += 1
	spawned_on_cliff = true
	_go("climb")
	_snap = true
	_animate(0.0)

# --- The figure -------------------------------------------------------------------------

## The model, sized off its head: the build's head height to ours.
func _art(root: Node3D) -> void:
	look = Look.new()
	look.name = "Look"
	root.add_child(look)
	look.build(hh/Look.HH)

## The tell: the stump's raw cut glows.
func tint(colour: Color) -> void:
	super.tint(colour)
	if look != null: look.warm(0.0 if colour == rest_colour else 1.0)

# --- What the head asks ------------------------------------------------------------------

## Where the head's chin sits now: on the neck, or on its way there.
func head_seat() -> Vector3:
	var seat := look.seat().origin
	if state == "scope" and _held_w > 0.0: return seat.lerp(_held_at,_held_w)
	if _seat_k >= 1.0: return seat
	var k := smoothstep(0.0,1.0,_seat_k)
	var p := _seat_from.lerp(seat,k)
	p.y += sin(k*PI)*hh*0.5
	return p

func head_facing() -> float:
	if state == "scope" and _held_w > 0.0: return lerp_angle(facing,_held_yaw,_held_w)
	return facing

## The stump's turn off its facing (the head's skin takes it as Euler).
func head_tilt() -> Vector3:
	var tilt := (Basis(Vector3.UP,facing).inverse()*look.seat().basis.orthonormalized()).get_euler()
	# Held up: upright, its face tipped down a little as he leans out.
	if state == "scope" and _held_w > 0.0: return tilt.lerp(Vector3(-_peer*0.6,0.0,0.0),_held_w)
	return tilt

# --- A frame -------------------------------------------------------------------------------

func think(delta: float) -> void:
	state_t += delta
	_clock += delta
	quake = maxf(0.0,quake-delta*1.2)
	_stagger = maxf(0.0,_stagger-delta)
	_find_head()
	_dusts(delta)
	_shocks(delta)
	if whole: _seat_k = minf(1.0,_seat_k+delta/float(knobs.settle))
	_progress(delta)
	_beacons(delta)
	_searching()
	if _chases(): _see(delta)
	if breaker != null and state in ["roam","home","chase","return","seek"] and breaker.ahead(self):
		_smash_from = state
		_smash_hit = false
		smashes += 1
		_go("smash")
		field.sound(&"body_windup",position)
	match state:
		"listen": _listen(delta)
		"roam","home": _walking(delta)
		"climb": _climb(delta)
		"mantle": _mantle(delta)
		"windup": _windup(delta)
		"land":
			_brake(delta)
			if state_t >= float(knobs.land): _go(_resume())
		"reach": _reach_head(delta)
		"triumph": _triumph(delta)
		"chase": _chase(delta)
		"alert": _alert(delta)
		"seek": _seek(delta)
		"return": _return(delta)
		"plant","suck","gulp": _suck(delta)
		"swat": _swat(delta)
		"smash": _smash(delta)
		"grab_windup": _grab_windup(delta)
		"grab_leap": _grab_leap(delta)
		"hang": _hang_grab(delta)
		"spent":
			_brake(delta)
			if state_t >= float(knobs.spent): _go(_resume())
		"feel": _feel(delta)
		"scope": _scope(delta)
	_animate(delta)

func _go(to: String) -> void:
	state = to
	state_t = 0.0
	if _chase_routed and to in ["listen","roam","seek","return","alert","reach"]: _chase_drop()
	if to == "listen":
		_listen_from = facing
		_picked = false
		listens += 1
		field.sound(&"body_listen",position)
	elif to == "roam":
		_next_listen = float(knobs.listen_every)*_rng.randf_range(0.7,1.3)

func _find_head() -> void:
	if head != null and is_instance_valid(head): return
	head = null
	for e in field.enemies:
		if not is_instance_valid(e) or e == self or not e.has_method("mouth"): continue
		# Its own head where there are several (set down at `head_home`).
		if head_home != Vector3.INF and e.has_method("home") and not preload("res://scripts/enemies/body_spawner.gd").same_home(e.home(),head_home): continue
		head = e

func _forward3() -> Vector3:
	var f := PilotMotor.forward(facing)
	return Vector3(f.x,0.0,f.y)

func _way3(angle: float) -> Vector3:
	var f := PilotMotor.forward(angle)
	return Vector3(f.x,0.0,f.y)

# --- Listening and walking -----------------------------------------------------------------

func _listen(delta: float) -> void:
	_brake(delta)
	var k := state_t/float(knobs.listen)
	# Round 4: it stands still and listens (it swept its facing one way and
	# the other, a turntable spin; the clip turns the stump instead).
	if k < 0.7: return
	# Heard: turns to the bearing, then goes. Round 11: the bearing a route
	# to it over places it fits, planned while it listens.
	if not _picked:
		_picked = true
		_heading = _pick_way()
		_plan()
	if _search != null and state_t < float(knobs.listen)*2.0: return
	if _beacon_gaze(delta): return
	if _routed(): _heading = _route_heading()
	var step := clampf(angle_difference(facing,_heading),-float(knobs.turn)*1.5*delta,float(knobs.turn)*1.5*delta)
	facing = wrapf(facing+step,-PI,PI)
	if k >= 1.0 and absf(angle_difference(facing,_heading)) < 0.15 and not look.steps.busy():
		if not whole and _senses(): _home()
		else: _go("roam")

## Whether it is lost: no nearer its head for `lost_after` s (it goes any
## way, `lost_for` s, then hears afresh). Round 9:
## on the generator's isles the head's bearing often runs into a wall or
## off a drop too deep, and it turned back and forth there for good.
func _progress(delta: float) -> void:
	if whole or head == null:
		_since_better = 0.0
		_best_d = INF
		stalled = 0.0
		return
	var d := head.global_position.distance_to(position)
	_since_better += delta
	stalled += delta
	if d < _best_ever-1.0:
		_best_ever = d
		stalled = 0.0
	if d < _best_d-1.0:
		_best_d = d
		_since_better = 0.0
	if _since_better > float(knobs.lost_after)+float(knobs.lost_for):
		_best_d = d
		_since_better = 0.0

func lost() -> bool:
	return _since_better > float(knobs.lost_after)

## The way it heard the head (noisy, less so near), or any way out of
## hearing (or whole, or lost); turned off a dead end (a rim with nothing
## below, a wall it won't climb).
func _pick_way() -> float:
	var way := facing+_rng.randf_range(-1.2,1.2)
	if beacon != null:
		# A lit beacon it heeds (`_beacon_pick`): its bearing, as a call's.
		var to_b := beacon.stand_at()-global_position
		var noise_b := float(knobs.noise)*CALL_NOISE
		if Vector2(to_b.x,to_b.z).length() > 0.5: way = PilotMotor.facing_of(Vector2(to_b.x,to_b.z).normalized())+_rng.randf_range(-noise_b,noise_b)
	elif lost(): way = facing+_rng.randf_range(-PI,PI)
	elif not whole and head != null:
		var to := head.global_position-global_position
		var d := Vector2(to.x,to.z).length()
		var calling: bool = head.has_method("calling") and head.calling()
		var hear := float(knobs.hear)*(CALL_HEAR if calling else 1.0)
		if d <= hear:
			var noise := float(knobs.noise)*(CALL_NOISE if calling else 1.0)*clampf(d/hear,0.25,1.0)
			way = PilotMotor.facing_of(Vector2(to.x,to.z).normalized())+_rng.randf_range(-noise,noise)
	for turn in [0.0,0.6,-0.6,1.2,-1.2,1.9,-1.9,PI]:
		if _way_ok(way+turn): return wrapf(way+turn,-PI,PI)
	return wrapf(way,-PI,PI)

func _way_ok(angle: float) -> bool:
	var dir := _way3(angle)
	var wall := _wall_along(dir,length*0.5+3.0,true)
	if not wall.is_empty(): return _climbable(wall) != INF and _wants_up()
	var past := position+dir*(length*0.5+3.0)
	if _floor(past,float(knobs.step),float(knobs.step)*2.0) != -INF: return true
	return not _landing(dir).is_empty()

func _walking(delta: float) -> void:
	if whole:
		if state == "roam" and beacon != null and _at_beacon():
			_go("listen")
			return
	elif _reunite_near():
		_go("reach")
		head.perch = self
		_seat_from = head.position
		_seat_k = 0.0
		field.sound(&"body_reach",position)
		return
	elif state == "roam" and _senses(): _home()
	elif state == "roam" and beacon != null and _at_beacon():
		_go("listen")
		return
	elif state == "home":
		if _senses(): _unsensed = 0.0
		else: _unsensed += delta
		if _unsensed > float(knobs.lose):
			homed = false
			rest()
			_go("listen")
			return
		var to := head.global_position-position
		_heading = PilotMotor.facing_of(Vector2(to.x,to.z).normalized())
	# Round 11: on its route, the way its next leg goes (homing, straight at
	# the head once only walking is left); turned to it before it steps on.
	if _routed():
		if not _follow(delta): return
	if _routed():
		if not (state == "home" and _walk_left()): _heading = _route_heading()
		# The Olmec's destruction: a pier standing just off his way draws
		# him into it (a brute's veer, under ROUTE_TURN: he never stops for it).
		if breaker != null: _heading = breaker.veer(self,_heading)
		if absf(angle_difference(facing,_heading)) > ROUTE_TURN or look.steps.busy():
			_brake(delta)
			# Olmec round 1: stopped first, then it steps round (its feet turn it).
			if Vector2(vel.x,vel.z).length() < 0.3: facing = wrapf(facing+clampf(angle_difference(facing,_heading),-float(knobs.turn)*delta,float(knobs.turn)*delta),-PI,PI)
			return
	var fwd := _forward3()
	# Olmec round 1: off a route its shoulders look ahead too (on one, the
	# planner chose where it goes; its bulk is still eased off the walls).
	var wall := _wall_along(fwd,length*0.5+float(knobs.look),not _routed())
	if not wall.is_empty():
		_meet_wall(wall)
		return
	# Walking its route, the floor is looked for no further on than where
	# the leg goes (a narrow way's next place, by a rim, is the planner's
	# to know); a leap leg's edge, as far as ever.
	var ahead := length*0.5+float(knobs.look)
	if _routed() and _route[_leg].kind == "walk":
		var to: Vector3 = _route[_leg].to
		ahead = clampf(Vector2(to.x-position.x,to.z-position.z).length()+0.3,0.6,ahead)
	if _floor(position+fwd*ahead,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF:
		_meet_edge(fwd)
		return
	var speed := float(knobs.home) if state == "home" else float(knobs.walk)*(1.15 if whole else 1.0)
	speed *= 1.0-0.2*clampf(_stagger/STAGGER,0.0,1.0)
	var step := clampf(angle_difference(facing,_heading),-float(knobs.turn)*delta,float(knobs.turn)*delta)
	facing = wrapf(facing+step,-PI,PI)
	var aligned := clampf(cos(angle_difference(facing,_heading)),0.0,1.0)
	var want := PilotMotor.forward(facing)*speed*aligned*aligned
	var flat := Vector2(vel.x,vel.z).move_toward(want,float(knobs.accel)*delta)
	vel.x = flat.x
	vel.z = flat.y
	if state == "roam":
		_next_listen -= delta
		if _next_listen <= 0.0: _go("listen")

func _home() -> void:
	homed = true
	_unsensed = 0.0
	_go("home")
	tell(mark_colour)

func _brake(delta: float) -> void:
	var flat := Vector2(vel.x,vel.z).move_toward(Vector2.ZERO,float(knobs.accel)*2.0*delta)
	vel.x = flat.x
	vel.z = flat.y

## The head within `sense` m, nothing between its neck and it.
func _senses() -> bool:
	if head == null or head.perch != null: return false
	var neck := position+Vector3.UP*neck_h
	var at: Vector3 = head.global_position+Vector3.UP*float(head.height)*0.5
	if neck.distance_to(at) > float(knobs.sense): return false
	_ray.from = neck
	_ray.to = at
	_ray.collision_mask = WalkerOnly.strip(field.study.ground.mask)
	_ray.exclude = _skip()
	return field.study.get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()

## Whether it hears the head over it (it climbs for it).
func _wants_up() -> bool:
	if whole or beacon != null: return true
	if head == null: return false
	if Vector2(head.global_position.x-position.x,head.global_position.z-position.z).length() > float(knobs.hear): return false
	return head.ground_y() > position.y+float(knobs.step)*2.0

func _reunite_near() -> bool:
	if head == null or head.perch != null or head.swallowed: return false
	if absf(head.ground_y()-position.y) > float(knobs.step)*3.0: return false
	var flat := Vector2(head.position.x-position.x,head.position.z-position.z).length()
	return flat <= length*0.5+head.length*0.5+float(knobs.reunite)

# --- Beacons ----------------------------
# A lit Beacon (scripts/enemies/beacon.gd: the great cresset, a beacon tower,
# Mudge alight) within its `draw` is heard the way the head's call is: it
# turns to its bearing (`_pick_way`), its routes go there (`_plan`), and
# there it stands and looks at it the beacon's `dwell` s (`_beacon_gaze`),
# then tires of that one `beacon_rest` s (lit again, it is news again).
# Priorities, highest first:
#   whole: him (chasing, or suspicious: alert, seek, the periscope) >
#          a beacon > roaming, and walking back to its post;
#   headless: its head in sight (`_senses`: home, reach, triumph) >
#          its head calling within call hearing > a beacon > its head
#          heard (not calling) > wandering.
# It turns at once (stops and listens) only from listen, roam or return;
# climbing, leaping and the rest, it takes the beacon up at its next listen.

## The lit beacon it heeds, or null.
var beacon: Beacon = null
## Its ears for the layer's noise (scripts/enemies/body_hearing.gd): a heard
## noise is a weaker beacon, under a lit one.
var hearing := Hearing.new()
## Times a beacon turned it; times it stood and looked at one.
var beacon_turns := 0
var beacon_visits := 0
var _beacon_t := 0.0
var _beacon_dwell := 0.0
var _beacon_near_as_can := false
## Beacons it tired of: instance id -> [until (its clock), their lightings].
var _beacon_tired := {}
## How often it looks for beacons (s).
const BEACON_POLL := 0.25
## The beacon it heeds is kept unless another draws this much harder.
const BEACON_KEEP := 1.25
## The states a beacon turns it from at once.
const BEACON_TURN_FROM := ["listen","roam","return"]

## Free to heed a beacon (nothing higher on its mind).
func _beacon_free() -> bool:
	if float(knobs.get("beacons",1)) < 0.5: return false
	if whole: return not hunting and (sight == null or sight.state == "unaware")
	if state in ["home","reach","triumph"]: return false
	if head != null and head.has_method("calling") and head.calling():
		if Vector2(head.global_position.x-position.x,head.global_position.z-position.z).length() <= float(knobs.hear)*CALL_HEAR: return false
	return true

func _tired_of(b: Beacon) -> bool:
	var t: Array = _beacon_tired.get(b.get_instance_id(),[])
	return not t.is_empty() and _clock < float(t[0]) and b.lightings == int(t[1])

## The lit beacon drawing it hardest (pull / (1 + d / draw), d flat), or null.
func _beacon_pick() -> Beacon:
	var best: Beacon = null
	var best_s := 0.0
	for b: Beacon in Beacon.all_lit(get_tree()):
		var r := b.draw_range()
		var d := Vector2(b.global_position.x-position.x,b.global_position.z-position.z).length()
		if d > r or _tired_of(b): continue
		var score := b.pull/(1.0+d/maxf(r,0.01))*(BEACON_KEEP if b == beacon else 1.0)
		if score > best_s:
			best_s = score
			best = b
	return best

## Looks for beacons (every BEACON_POLL s); a new one (or the one it heeded
## gone out) turns it from listening, roaming or walking back.
func _beacons(delta: float) -> void:
	_beacon_t -= delta
	if _beacon_t > 0.0: return
	_beacon_t = BEACON_POLL
	if beacon != null and not is_instance_valid(beacon): beacon = null
	var b: Beacon = _beacon_pick() if _beacon_free() else null
	# A heard noise, when no beacon draws it.
	var heard: Beacon = hearing.pick(self)
	if b == null and _beacon_free(): b = heard
	if b == beacon and not hearing.news(b): return
	if hearing.is_lure(b): hearing.tell(self)
	var was := beacon
	beacon = b
	_beacon_dwell = 0.0
	_beacon_near_as_can = false
	if b != null: beacon_turns += 1
	if state in BEACON_TURN_FROM and (b != null or was != null):
		_route = []
		_leg = 0
		_search = null
		_go("listen")

## Where it goes to look at its beacon: the beacon's `stand`, on the floor.
func _beacon_goal() -> Vector3:
	var p := beacon.stand_at()
	var y := _floor(p,0.5,80.0)
	return Vector3(p.x,y if y != -INF else p.y,p.z)

## There: within the beacon's `gather` of where it stands to look (flat), or
## as near as its routes get.
func _at_beacon() -> bool:
	if beacon == null: return false
	if _beacon_near_as_can and not _routed() and _search == null: return true
	var p := beacon.stand_at()
	return Vector2(p.x-position.x,p.z-position.z).length() <= length*0.5+beacon.gather+1.0

## Listening, at its beacon: it faces the flame and looks, `dwell` s; then
## tired of it, it hears afresh. True while it looks.
func _beacon_gaze(delta: float) -> bool:
	if beacon == null or not _at_beacon() or (not whole and _senses()):
		_beacon_dwell = 0.0
		return false
	var to := beacon.global_position-position
	if Vector2(to.x,to.z).length() > 0.3:
		var want := PilotMotor.facing_of(Vector2(to.x,to.z).normalized())
		facing = wrapf(facing+clampf(angle_difference(facing,want),-float(knobs.turn)*1.5*delta,float(knobs.turn)*1.5*delta),-PI,PI)
		# Its feet turn it there too (stood, `_turn_goal` is its heading,
		# and the steps' yaw is its facing): a `stand` off the flame
		# otherwise left it looking back the way it came.
		_heading = want
	if _beacon_dwell == 0.0: beacon_visits += 1
	_beacon_dwell += delta
	if _beacon_dwell >= beacon.dwell:
		_beacon_tired[beacon.get_instance_id()] = [_clock+float(knobs.get("beacon_rest",40.0)),beacon.lightings]
		beacon = null
		_beacon_dwell = 0.0
		_beacon_near_as_can = false
		_route = []
		_search = null
		_go("listen")
	return true

# --- Walls and climbing -----------------------------------------------------------------------

## A wall (steep) along `dir` from its knees, within `reach` m: the hit, or {}.
## Round 11: a riser whose top is within STAIR Ã— `step` of its feet is a
## stair's step it walks up, not a wall.
const STAIR := 1.6
func _wall_along(dir: Vector3, reach: float, sides := false) -> Dictionary:
	var knee := float(knobs.step)+0.1
	# Olmec round 1: off a route, its shoulders too (and its head, whole),
	# and an underside over it (a ramp's, an overhang's) is a wall it won't
	# climb (on one, the planner gave it room to its stump's top).
	var ups: Array[float] = [knee,neck_h*0.5]
	if not _routed(): ups.append_array([neck_h*0.92,_bulk_top()-0.3])
	for up: float in ups:
		var from := position+Vector3.UP*up
		var hit := _cast(from,from+dir*reach)
		if hit.is_empty(): continue
		var ny := (hit.normal as Vector3).y
		if ny >= 0.5: continue
		if ny <= -0.5:
			if up <= neck_h*0.5: continue
			hit["ceiling"] = true
		if up == knee and _riser(hit): continue
		return hit
	return _shoulder_wall(dir,reach) if sides else {}

## Olmec round 1: a wall in the way of its shoulders and swinging arms, not
## of its middle (a pillar's corner, a wall's end met slantwise): rays along
## `dir` out from each shoulder line, at its hips and its chest. The hit,
## flagged "side" (it isn't climbed from), or {}.
func _shoulder_wall(dir: Vector3, reach: float) -> Dictionary:
	var across := Vector3(-dir.z,0.0,dir.x)*hh*BULK_W*0.85
	for s: float in [-1.0,1.0]:
		for up: float in [neck_h*0.45,neck_h*0.8]:
			var from := position+Vector3.UP*up+across*s
			var hit := _cast(from,from+dir*(reach+SHOULDER_AHEAD*hh))
			if hit.is_empty() or (hit.normal as Vector3).y >= 0.5: continue
			hit["side"] = true
			return hit
	return {}

## Whether the face `hit` (met at the knee) tops out within STAIR Ã— `step`
## of its feet.
func _riser(hit: Dictionary) -> bool:
	var n := hit.normal as Vector3
	var past := (hit.position as Vector3)-Vector3(n.x,0.0,n.z).normalized()*0.4
	var high := position.y+float(knobs.step)*STAIR
	var top := _cast(Vector3(past.x,high+0.2,past.z),Vector3(past.x,position.y+0.05,past.z))
	return not top.is_empty() and (top.normal as Vector3).y > 0.6 and (top.position as Vector3).y <= high

## The top of the wall `hit` (a ray down past its face from `climb_max`
## over its feet), INF if it is taller than that.
func _climbable(hit: Dictionary) -> float:
	if hit.get("ceiling",false) or hit.get("side",false): return INF
	var n := hit.normal as Vector3
	n = Vector3(n.x,0.0,n.z).normalized()
	var past := (hit.position as Vector3)-n*float(knobs.lip_in)
	var top := _cast(Vector3(past.x,position.y+float(knobs.climb_max),past.z),Vector3(past.x,position.y+float(knobs.step),past.z))
	if top.is_empty() or (top.normal as Vector3).y < 0.6: return INF
	return (top.position as Vector3).y

func _meet_wall(hit: Dictionary) -> void:
	vel.x = 0.0
	vel.z = 0.0
	var climbing := _climbable(hit) != INF and _wants_up()
	if climbing and whole: climbing = _rng.randf() < float(knobs.whole_climb)
	# On its route: a climb leg's wall it climbs; any other, it gives the
	# leg up and plans again without it.
	if _routed():
		# Olmec round 1: a walk leg ending at the foot of the next leg's
		# climb is done when its wall is met (its bulk, held off the face,
		# may never stand within a cell of that end).
		if _route[_leg].kind == "walk" and _leg+1 < _route.size() and _route[_leg+1].kind == "climb" and not hit.get("side",false):
			var end: Vector3 = _route[_leg].to
			if Vector2((hit.position as Vector3).x-end.x,(hit.position as Vector3).z-end.z).length() < Routes.CELL*2.5:
				_next_leg()
		if _route[_leg].kind != "climb":
			# The planner sending it into a wall it can climb and wants up,
			# again and again: it climbs it (as off a route).
			_wall_fails += 1
			if _wall_fails > WALL_FAILS and climbing and not hit.get("side",false):
				_wall_fails = 0
				_route = []
				_start_climb(hit)
				return
			routes.block(hit.position)
			_leg_failed("wall")
			return
		climbing = true
	_wall_fails = 0
	if not climbing:
		_go("listen")
		return
	_start_climb(hit)

## Lips he let go of, no room over them (counted, for checks).
var no_room_lips := 0

## Walk legs given up at walls in a row (Olmec round 1), and how many
## before it climbs the wall instead.
var _wall_fails := 0
const WALL_FAILS := 2

## Faced to the wall `hit`, climbing.
func _start_climb(hit: Dictionary) -> void:
	var n := hit.normal as Vector3
	facing = PilotMotor.facing_of(-Vector2(n.x,n.z).normalized())
	if float(knobs.feel) > 0.0:
		_feel_hit = hit
		_feel_from = -1.0
		_go("feel")
		return
	_climb_on(hit)

## Round 4: a hand laid on the wall, `feel` s, then up it.
func _feel(delta: float) -> void:
	_brake(delta)
	# Stood clear of the face: its nearest point over his height (an
	# undercut, a bulge, a step at his feet) FEEL_BACK past the climb's
	# standoff, eased there (his feet step after); the clip's hand is made
	# for that distance. Met slantwise, his turned figure's shoulder would
	# be in the face: then it squares up at once, not step by step.
	var n := _feel_hit.normal as Vector3
	n = Vector3(n.x,0.0,n.z).normalized()
	var a := absf(angle_difference(look.steps.yaw,facing))
	var near := _face_near(n)
	var reach_out := length*0.5*cos(minf(a,PI*0.5))+width*0.72*sin(minf(a,PI*0.5))
	look.steps.hurry = reach_out+0.15 > near
	var want := length*0.5+float(knobs.standoff)+FEEL_BACK*hh/Look.HH
	# Walked in close (his toes, slantwise his chest, in it), out faster.
	var ease := FEEL_EASE*(6.0 if near < length*0.5+0.1 else 3.0 if near < want-0.3 else 1.0)
	var move := n*clampf(want-near,-ease*delta,ease*delta)
	# Never back off a rim (the floor behind him where he would stand).
	if want > near and _floor(position+n*(want-near+0.3),float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: move = Vector3.ZERO
	position += move
	# His feet shuffle with him (a planted toe would be left in the face).
	look.steps.carry(move)
	look.steps.keep_off(_feel_hit.position,n,FEEL_TOE*hh/Look.HH)
	if _feel_from < 0.0 and ((a < FEEL_SQUARE and absf(want-near) < 0.15) or state_t >= FEEL_WAIT): _feel_from = state_t
	if _feel_from >= 0.0 and state_t-_feel_from >= float(knobs.feel): _climb_on(_feel_hit)

## Squared up to the wall within FEEL_SQUARE rad (or FEEL_WAIT s on), it
## starts to feel it.
const FEEL_SQUARE := 0.3
const FEEL_WAIT := 0.8
## Further off the face than the climb stands him while he feels it (m at
## the model's size): the clip leans him in and reaches.
const FEEL_BACK := 0.5
## His ankles kept this far off the face while he feels it (m at the
## model's size: the slab foot reaches about 1.45 ahead of the ankle).
const FEEL_TOE := 1.6
## How fast he is eased off (or onto) the face (m/s).
const FEEL_EASE := 2.0
## The wrist off the face with the palm flat on it (m at the model's size:
## the hand's half thickness, its bracelet clear; the build's _fw).
## Its bracelet is wider than the hand: a forearm slanted to the face
## would put it in nearer.
const FEEL_PALM := 0.9

## The face's nearest (m, along its normal `n`) to its middle, over its
## height: rays at its knee, hips, chest, shoulders and stump; the face it
## met if none of them hit.
func _face_near(n: Vector3) -> float:
	var near := INF
	for up: float in [float(knobs.step)+0.1,neck_h*0.3,neck_h*0.55,neck_h*0.8,neck_h*1.05]:
		var from := position+Vector3.UP*up
		var hit := _cast(from,from-n*(length+hh))
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7: near = minf(near,(from-(hit.position as Vector3)).dot(n))
	return near if near != INF else (position-(_feel_hit.position as Vector3)).dot(n)

## How far through its feel it is (0 to 1; 0 while it squares up).
func _feel_k() -> float:
	return 0.0 if _feel_from < 0.0 else clampf((state_t-_feel_from)/float(knobs.feel),0.0,1.0)

func _climb_on(hit: Dictionary) -> void:
	_climb_from = position.y
	_lip_y = INF
	climbs += 1
	_go("climb")
	field.sound(&"body_grip",hit.position)

## Why the climb last let go (for drivers and F1).
var let_go_why := ""

func _climb(delta: float) -> void:
	vel = Vector3.ZERO
	var fwd := _forward3()
	var chest := position+Vector3.UP*neck_h*0.55
	var hit := _cast(chest,chest+fwd*(length*0.5+float(knobs.standoff)+1.5))
	if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7:
		var n := hit.normal as Vector3
		var want := PilotMotor.facing_of(-Vector2(n.x,n.z).normalized())
		facing = lerp_angle(facing,want,1.0-exp(-4.0*delta))
		var gap := chest.distance_to(hit.position as Vector3)-length*0.5
		position += fwd*(gap-float(knobs.standoff))*minf(1.0,6.0*delta)
		_face_pt = hit.position
	else:
		_face_pt = position+fwd*(length*0.5+float(knobs.standoff))+Vector3.UP*neck_h*0.55
	# The lip: a ray down past the face from over its reach (down to a
	# step over its feet: a ledge too tall to step, too low for its chest
	# ray, is mantled at once; round 9 found those on the generator's
	# isles, where it dropped back off them, landing, again and again).
	var reach := neck_h+arm_l*0.75
	var past := _face_pt+fwd*float(knobs.lip_in)
	var lip := _cast(Vector3(past.x,position.y+reach,past.z),Vector3(past.x,position.y+float(knobs.step),past.z))
	_lip_y = (lip.position as Vector3).y if not lip.is_empty() and (lip.normal as Vector3).y > 0.6 else INF
	# Body climb-after round 1: a lip with no room over it for him (a
	# refuge's floor under an overhang, the hauling lip's undercut): no
	# top for him. He lets go (he'd haul himself into it).
	if _lip_y != INF and _lip_y-position.y <= _hang_h()+0.5:
		var at := lip.position as Vector3
		if not _cast(at+Vector3.UP*0.1,at+Vector3.UP*neck_h*0.5).is_empty():
			no_room_lips += 1
			let_go_why = "no room over the lip"
			_fall()
			return
	# Round 4: springing, it hangs once its hands can reach the lip (and
	# climbs on hand over hand till then).
	_hang = _springs() and _lip_y != INF and _lip_y-position.y <= _hang_h()
	if _lip_y != INF and (_lip_y-position.y <= neck_h*0.55 or (_hang and _haul_t >= PULL_AFTER)):
		_pull = _lip_y-position.y > neck_h*0.55
		_hang = false
		_mantle_landed = false
		_mantle_from = position
		# In over the lip, short of a wall over it (a stair's tread, a
		# sliver under a higher face: round 11 stands it there, against the
		# next wall, to climb on, not inside it).
		var lip_at := Vector3(_face_pt.x,_lip_y,_face_pt.z)
		var inward := length*0.5+0.6
		var ahead := _cast(lip_at+Vector3.UP*(float(knobs.step)+0.3),lip_at+Vector3.UP*(float(knobs.step)+0.3)+fwd*(length+0.6))
		if not ahead.is_empty() and absf((ahead.normal as Vector3).y) < 0.5:
			inward = clampf(lip_at.distance_to(ahead.position as Vector3)-length*0.5-float(knobs.standoff),0.3,inward)
		var onto := lip_at+fwd*inward
		var g := _floor(onto,1.0,1.5)
		_mantle_to = Vector3(onto.x,g if g != -INF else _lip_y,onto.z)
		_mantle_lip = Vector3(_face_pt.x,_lip_y,_face_pt.z)
		_go("mantle")
		field.sound(&"body_grip",Vector3(_face_pt.x,_lip_y,_face_pt.z))
		return
	if hit.is_empty() and _lip_y == INF:
		# The wall gone from under its hands with no top found: it lets go.
		let_go_why = "no wall, no top"
		_fall()
		return
	if position.y-_climb_from > float(knobs.climb_max):
		let_go_why = "past climb_max"
		_fall()
		return
	if _hauling(): _haul_t += delta
	else:
		_haul_t = 0.0
		_grab_t = -1.0
	var rise := float(knobs.climb)*delta*(float(knobs.haul) if _lip_y != INF else 1.0)
	if _springs(): rise = 0.0 if _hang else float(knobs.climb)*delta
	position.y += rise
	var was := _phase
	_phase += rise/(arm_l*0.45)
	if int(was) != int(_phase):
		field.sound(&"body_grip",position+Vector3.UP*(neck_h+arm_l*0.6))
		if not _hauling(): _grip_dust(int(_phase))
	# Hauling, its feet scrabble on the face.
	if _lip_y != INF and not _springs() and int((_haul_t-delta)/0.45) != int(_haul_t/0.45):
		var feet := position+fwd*(length*0.5)+Vector3.UP*hh*0.3
		var tk := _tell_k()
		Dust.puff(field,feet,hh*1.0*tk,-fwd)
		Dust.rocks(field,feet,-fwd,2,hh*0.1*tk)

## A hand put on the face (the `k`-th): a puff off the face by it, a
## stone or two knocked down.
func _grip_dust(k: int) -> void:
	grips += 1
	var fwd := _forward3()
	var side := -1.0 if k%2 == 0 else 1.0
	var at := position+Vector3.UP*(neck_h+arm_l*0.55)+_right3()*side*hh*0.45+fwd*(length*0.5)
	var tk := _tell_k()
	Dust.puff(field,at-fwd*hh*0.3,hh*1.2*tk,-fwd)
	Dust.rocks(field,at-fwd*hh*0.2,-fwd,3 if k%2 == 0 else 4,hh*0.12*tk)

## The tells grown with the camera's distance (1 within TELL_NEAR m, up to
## TELL_MOST times), so a far body's dust and stones still read.
const TELL_NEAR := 60.0
## While the head calls (head.calling()), the body hears it this much farther
## and its bearing is this much less noisy (multipliers on `hear` and `noise`).
const CALL_HEAR := 2.0
const CALL_NOISE := 0.4
const TELL_MOST := 2.5
func _tell_k() -> float:
	var camera: Camera3D = field.study.get("camera") if field != null and field.study != null else null
	if camera == null: return 1.0
	return clampf(camera.global_position.distance_to(global_position)/TELL_NEAR,1.0,TELL_MOST)

func _mantle(delta: float) -> void:
	var k := clampf(state_t/float(knobs.mantle),0.0,1.0)
	# Round 4: a press-up (or a pull-up) that pops it up past the lip, then
	# down onto the top (the build's mantle_up / mantle_over curves).
	var up := _mantle_up(k,_pull)
	var over := smoothstep(0.48,0.66,k) if _pull else smoothstep(0.42,0.64,k)
	position = Vector3(lerpf(_mantle_from.x,_mantle_to.x,over),lerpf(_mantle_from.y,_mantle_to.y,up),lerpf(_mantle_from.z,_mantle_to.z,over))
	if not _mantle_landed and k >= (PULL_LAND_K if _pull else LAND_K):
		_mantle_landed = true
		# Its weight comes down on the top: a smaller wave.
		_shock(position,float(knobs.shock_mantle))
		weighed.emit(position,float(knobs.shock_mantle),"haul")
		Dust.plume(field,position,hh*2.6*_tell_k())
		quake = maxf(quake,0.2)
		field.sound(&"body_step",position)
	if k >= 1.0:
		grounded = true
		spawned_on_cliff = false
		# Round 11: over a lip it doesn't fit on, with its climb leg's wall
		# over it, it goes straight on climbing (no listen); hunting on a
		# route, still hunting (roam would drop the route).
		if _routed() and _route[_leg].kind == "climb" and not _at_leg_end():
			perches += 1
			_go("chase" if _chase_routed and hunting and _chases() else "roam")
			return
		_go(_resume())

## Round 4: whether it springs over lips (`mantle_pull`), hangs now, and
## from how high under the lip it hangs (its hands on it, 0.5 m over the
## top and LIP_OUT out from the face, the arms all but straight).
func _springs() -> bool:
	return float(knobs.mantle_pull) > 0.5

func _hauling() -> bool:
	return _hang if _springs() else _lip_y != INF

func _hang_h() -> float:
	var k := look.k
	var r := look.arm_reach()*0.97
	var side := 1.6*k
	var out := (length*0.5+float(knobs.standoff))-0.65*k
	return neck_h*0.927+sqrt(maxf(r*r-side*side-out*out,0.0))-0.5*k

## Round 4: the mantle's rise at `k` (a share of from its start to the top;
## over 1 at the top of the pop), the build's `mantle_up`.
const LAND_K := 0.66
const PULL_LAND_K := 0.68
## Pull-ups: hanging this long (s) with its hands on the lip, it pulls.
const PULL_AFTER := 0.55
static func _mantle_up(k: float, pull: bool) -> float:
	if not pull:
		if k < 0.2: return -0.07*smoothstep(0.0,0.2,k)
		if k < 0.36: return -0.07+0.4*pow((k-0.2)/0.16,2.0)
		if k < 0.5: return 0.33+0.78*(1.0-pow(1.0-(k-0.36)/0.14,2.0))
		if k < 0.56: return 1.11
		if k < LAND_K: return 1.11-0.11*pow((k-0.56)/(LAND_K-0.56),2.0)
		return 1.0
	if k < 0.18: return -0.03*smoothstep(0.0,0.18,k)
	if k < 0.4: return -0.03+0.4*smoothstep(0.18,0.4,k)
	if k < 0.56: return 0.37+0.71*(1.0-pow(1.0-(k-0.4)/0.16,2.0))
	if k < 0.6: return 1.08
	if k < PULL_LAND_K: return 1.08-0.08*pow((k-0.6)/(PULL_LAND_K-0.6),2.0)
	return 1.0

# --- Edges and leaps ------------------------------------------------------------------------

func _meet_edge(fwd: Vector3) -> void:
	vel.x = 0.0
	vel.z = 0.0
	# On its route: a leap leg's landing it throws itself to (or one of its
	# own along the way, if the arc there is blocked); any other leg it
	# gives up.
	if _routed():
		var leg: Dictionary = _route[_leg]
		var land := {}
		if leg.kind in ["jump","drop"]:
			var to: Vector3 = leg.to
			var g := _floor(to,2.0,3.0)
			if g != -INF: to.y = g
			if _arc_clear(to,leg.kind): land = {"at":to,"kind":leg.kind}
			else: land = _landing(fwd)
		if land.is_empty():
			_leg_failed("edge")
			return
		_leap_to = land.at
		leap_kind = land.kind
		_go("windup")
		field.sound(&"body_windup",position)
		return
	var land := _landing(fwd)
	if land.is_empty() or (head == null and not whole):
		_go("listen")
		return
	_leap_to = land.at
	leap_kind = land.kind
	_go("windup")
	field.sound(&"body_windup",position)

## Where it would come down going off the edge along `dir`: across the
## gap onto a ledge at about its height if the gap is narrow enough
## (`_ledge`), else down onto a lower floor: {at, kind} or {}.
func _landing(dir: Vector3) -> Dictionary:
	var ledge := _ledge(dir)
	if not ledge.is_empty() and _arc_clear(ledge.at,"jump"): return ledge
	var drop := _drop(dir)
	if not drop.is_empty() and _drop_ok(drop.at) and _arc_clear(drop.at,"drop"): return drop
	return {}

## Whether it drops to `at`: headless and not lost, not more than
## `drop_under` m under its head's ground (it hears it up there). Round 9: on
## the generator's isles it dropped onto spurs
## and ledges down a cliff with no way back up, and stood there for good;
## lost, it takes the drop (the study's way to the head goes down and up).
func _drop_ok(at: Vector3) -> bool:
	if whole or head == null or lost(): return true
	var ground: float = minf(head.ground_y(),(head.home() as Vector3).y) if head.has_method("home") else head.ground_y()
	return at.y >= ground-float(knobs.drop_under)

## The widest gap it jumps ledge to ledge (m): `jump_gap` head heights.
func jump_gap() -> float:
	if hunting and _relentless(): return maxf(float(knobs.jump_gap),float(knobs.hunt_gap))*hh
	return float(knobs.jump_gap)*hh

## A ledge across the gap along `dir`: the far rim within `jump_gap()` of
## the near one, its top no more than `jump_rise` Hh over its feet or
## `jump_sink` Hh under, room on it for its body: {at, kind "jump", gap}
## or {}.
func _ledge(dir: Vector3) -> Dictionary:
	var step := float(knobs.step)
	var rim := -1.0
	var d := 0.0
	while d <= length*0.5+float(knobs.look)+1.0:
		if _floor(position+dir*d,step,step*2.0) == -INF:
			rim = d
			break
		d += 0.25
	if rim < 0.0: return {}
	var over := float(knobs.jump_rise)*hh
	if hunting and _relentless(): over = maxf(over,float(knobs.hunt_rise)*hh)
	var under := float(knobs.jump_sink)*hh
	d = rim+0.25
	while d <= rim+jump_gap():
		var p := position+dir*d
		var hit := _cast(Vector3(p.x,position.y+over+step,p.z),Vector3(p.x,position.y-under,p.z))
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
			var y := (hit.position as Vector3).y
			var onto := position+dir*(d+length*0.5+1.0)
			var g := _floor(Vector3(onto.x,y,onto.z),1.0,1.0)
			if g == -INF: return {}
			return {"at":Vector3(onto.x,g,onto.z),"kind":"jump","gap":d-rim}
		d += 0.25
	return {}

## A floor out along `dir` lower than its feet, within `leap_max` m across
## and `drop_max` m down, room on it for its body: {at, kind "drop"} or {}.
func _drop(dir: Vector3) -> Dictionary:
	var d := length*0.5+float(knobs.look)
	while d <= float(knobs.leap_max):
		var p := position+dir*d
		var hit := _cast(p+Vector3.UP*float(knobs.step),p-Vector3.UP*float(knobs.drop_max))
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.7:
			var y := (hit.position as Vector3).y
			if y < position.y-float(knobs.step):
				var onto := position+dir*(d+length*0.5+1.0)
				var g := _floor(Vector3(onto.x,y,onto.z),1.0,1.0)
				if g != -INF: return {"at":Vector3(onto.x,g,onto.z),"kind":"drop"}
		d += 0.75
	return {}

func _windup(delta: float) -> void:
	_brake(delta)
	# The pounce (chase): aimed at him as it winds up, till `pounce_lock` s
	# before it goes.
	if leap_kind == "pounce" and state_t < _windup_s()-float(knobs.pounce_lock):
		var at := _pounce_spot(field.motor)
		if at != Vector3.INF: _leap_to = at
	var to := Vector2(_leap_to.x-position.x,_leap_to.z-position.z)
	facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-(9.0 if leap_kind == "pounce" else 5.0)*delta))
	if state_t < _windup_s(): return
	if leap_kind == "pounce":
		_pounce_ready = _clock+float(knobs.pounce_rest)
		if not _arc_clear(_leap_to,"pounce"):
			_go(_resume())
			return
		pounces += 1
	if leap_kind == "jump": jumps += 1
	var throw := _throw(position,_leap_to,leap_kind)
	_flight = throw[1]
	vel = throw[0]
	grounded = false
	leaps += 1
	_go("leap")
	field.sound(&"body_leap",position)

## The throw from `from` to `to` ("jump" across, else a drop): [its
## velocity, its time in the air]. A jump's is longer and flatter, peaking
## a share of its length (and over the far ledge if that stands higher).
func _throw(from: Vector3, to: Vector3, kind: String) -> Array:
	var g := float(knobs.leap_gravity)
	var flat := Vector2(to.x-from.x,to.z-from.z)
	var drop := from.y-to.y
	var up := float(knobs.leap_up)
	if kind == "jump": up = maxf(up,float(knobs.jump_arc)*flat.length())+maxf(0.0,-drop)
	elif kind == "pounce": up = maxf(up,float(knobs.pounce_arc)*flat.length())+maxf(0.0,-drop)
	var vy := sqrt(2.0*g*up)
	var t := (vy+sqrt(maxf(vy*vy+2.0*g*drop,0.0)))/g
	return [Vector3(flat.x/t,vy,flat.y/t),t]

## Whether the throw to `to` comes down there: its arc flown as `_move`
## flies it (its feet ray-cast along it), nothing met on the way but the
## floor it lands on, within ARC_LAND of `to`. Round 9 (layer-round9-
## bodies.md): on the generator's isles a throw into a far wall dropped it
## into the void.
const ARC_LAND := 2.0
const ARC_DT := 1.0/30.0
func _arc_clear(to: Vector3, kind: String) -> bool:
	# Olmec round 1: room for its bulk where it comes down (a shaft, a slot
	# its shoulders don't fit, is no landing).
	if not _room_at(to): return false
	var throw := _throw(position,to,kind)
	var v: Vector3 = throw[0]
	var p := position
	var g := float(knobs.leap_gravity)
	var t := 0.0
	while t < float(throw[1])+1.0:
		v.y -= g*ARC_DT
		var next := p+v*ARC_DT
		var hit := _cast(p+Vector3.UP*0.05,next)
		if not hit.is_empty():
			if (hit.normal as Vector3).y > 0.5 and v.y <= 0.0: return (hit.position as Vector3).distance_to(to) <= ARC_LAND
			return false
		# Olmec round 1: its bulk would fly into a wall on the way.
		if kind != "drop" and _bulk_sweep(p,next) < 1.0: return false
		p = next
		t += ARC_DT
	return false

func _fall() -> void:
	grounded = false
	vel = Vector3(vel.x,minf(vel.y,0.0),vel.z)
	_go("fall")

## Down: the harder it came down, the bigger the wave (a head height's
## fall is 1; 0.6 to 1.5).
func _landed() -> void:
	var impact := maxf(0.0,-vel.y)
	var pounced := state == "leap" and leap_kind == "pounce"
	_land_clip = "drop_land" if state == "leap" and leap_kind == "drop" else "land"
	grounded = true
	vel = Vector3.ZERO
	_go("land")
	_puff(position,hh*2.2)
	Dust.plume(field,position,hh*3.5*_tell_k())
	field.sound(&"body_land",position)
	field.sound(&"body_rumble",position)
	var power := float(knobs.pounce_shock) if pounced else clampf(impact/sqrt(2.0*float(knobs.leap_gravity)*hh),0.6,1.5)
	# Olmec threat round 1: hunting, his leaps come down harder.
	if hunting and _relentless(): power *= float(knobs.hunt_shock)
	_shock(position,power)
	weighed.emit(position,power,"pounce" if pounced else "land")
	# The pounce come down on him: caught.
	if pounced:
		var m: PilotMotor = field.motor
		if Vector2(m.feet.x-position.x,m.feet.z-position.z).length() <= float(knobs.pounce_hit) and absf(m.feet.y-position.y) < neck_h*0.5 and not m.seized():
			_catch(m,"pounce")

# --- Shockwaves -------------------------------------------------------------------------------

## A landing's noise carries this many times its shockwave's reach (m).
const SHOCK_HEARD := 2.5

## A shockwave from `at`, `power` (1 a leap's landing): a ring and a dust
## wall running out along the ground to `shock_r` Hh Ã— âˆšpower, stones
## kicked up; the walker it passes on the ground is thrown back and up
## through his motor, less the farther out.
func _shock(at: Vector3, power: float) -> void:
	shocks += 1
	quake = maxf(quake,0.35+0.45*power)
	var reach := float(knobs.shock_r)*hh*sqrt(power)
	var parts: Array = []
	# The front: a thin bright ring hugging the ground.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = _wave_mat(Color(0.95,0.88,0.74,0.9))
	parts.append(ring)
	# Behind it, a skirt of dust thrown up off the ground.
	var wall := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 48
	wall.mesh = tube
	wall.material_override = _wave_mat(Color(0.74,0.68,0.58,0.55))
	parts.append(wall)
	for p: MeshInstance3D in parts:
		field.add_child(p)
		p.global_position = at+Vector3.UP*0.15
		p.scale = Vector3(0.1,0.1,0.1)
	# Stones kicked up round it.
	var chips: Array = []
	for i in 10:
		var chip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE*hh*_rng.randf_range(0.08,0.16)*sqrt(power)
		chip.mesh = box
		chip.material_override = _wave_mat(Color(0.6,0.56,0.5,1.0))
		field.add_child(chip)
		var a := TAU*(i+_rng.randf())/10.0
		chip.global_position = at+Vector3(sin(a),0.3,cos(a))*hh*0.6
		chips.append([chip,Vector3(sin(a)*_rng.randf_range(3.0,7.0),_rng.randf_range(5.0,10.0)*sqrt(power),cos(a)*_rng.randf_range(3.0,7.0))])
	_waves.append({"at":at,"r":0.0,"max":reach,"power":power,"done":false,"t":0.0,"parts":parts,"chips":chips})
	field.sound(&"body_shock",at)
	# Its landing heard across the layer; not by
	# itself or another body (scripts/enemies/body_hearing.gd).
	NoiseBus.make(self,at,reach*SHOCK_HEARD,&"olmec_land")

func _wave_mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _shocks(delta: float) -> void:
	for w: Dictionary in _waves:
		w.t += delta
		w.r = minf(w.max,w.r+float(knobs.shock_speed)*delta)
		var k: float = w.r/w.max
		var fade := 1.0-smoothstep(0.55,1.0,k) if w.r < w.max else maxf(0.0,1.0-(w.t-w.max/float(knobs.shock_speed))/0.35)
		var ring: MeshInstance3D = w.parts[0]
		var wall: MeshInstance3D = w.parts[1]
		var thick := hh*0.35*sqrt(w.power)
		ring.scale = Vector3(w.r,thick*(1.0-0.6*k),w.r)
		var high := hh*0.9*sqrt(w.power)*sin(minf(k,1.0)*PI*0.5+0.35)*(1.0-0.7*k)
		wall.scale = Vector3(maxf(w.r-thick*0.4,0.1),maxf(high,0.05),maxf(w.r-thick*0.4,0.1))
		wall.global_position.y = (w.at as Vector3).y+high*0.5
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.9*fade
		(wall.material_override as StandardMaterial3D).albedo_color.a = 0.55*fade
		for c: Array in w.chips:
			var chip: MeshInstance3D = c[0]
			c[1].y -= float(knobs.leap_gravity)*delta
			chip.global_position += c[1]*delta
			chip.rotation += Vector3(3.0,2.0,1.0)*delta
			if chip.global_position.y < (w.at as Vector3).y: chip.visible = false
		if not w.done: _shock_meets(w)
		if breaker != null and w.r < w.max: breaker.wave(self,w)
	for w: Dictionary in _waves:
		if w.t > w.max/float(knobs.shock_speed)+0.6:
			for p: Node in w.parts+w.chips.map(func(c: Array) -> Node: return c[0]):
				if is_instance_valid(p): p.queue_free()
	_waves = _waves.filter(func(w: Dictionary) -> bool: return w.t <= w.max/float(knobs.shock_speed)+0.6)

## The front reaching the walker: on the ground in the wave's band (or
## barely off it), he is thrown; airborne over it, he is clear.
func _shock_meets(w: Dictionary) -> void:
	var m: PilotMotor = field.motor
	var at: Vector3 = w.at
	var off := Vector2(m.feet.x-at.x,m.feet.z-at.z)
	var d := off.length()
	if d > w.max:
		w.done = true
		return
	if d > w.r: return
	w.done = true
	if m.seized() or m.rider != null: return
	# On walker-only stone (scripts/walker_only.gd) he is off its ground:
	# the wave runs under him.
	if m.grounded and field.pilot_on_walker_only(): return
	var dy := m.feet.y-at.y
	if absf(dy) > float(knobs.shock_band): return
	if not m.grounded and m.feet.y-_floor(m.feet,0.1,float(knobs.shock_band)*2.0) > float(knobs.shock_air): return
	# On its shoulders he rides it out.
	if m.grounded and field.under_pilot() == body.get_rid(): return
	# A breakable that takes the wave's hit on him itself (the city's drum
	# floor).
	if breaker != null and breaker.has_method("takes_shock") and breaker.takes_shock(self,w): return
	var f := lerpf(1.0,float(knobs.shock_edge),d/w.max)*float(w.power)
	var way := off.normalized() if d > 0.1 else PilotMotor.forward(facing)
	# Olmec threat round 1: thrown toward the void near a rim.
	if float(knobs.void_push) > 0.0 and _relentless(): way = OlmecVoid.toward(field,m.feet,way,float(knobs.void_push))
	shock_hits += 1
	shove_pilot(m,way,float(knobs.shock_out)*f,float(knobs.shock_up)*f)

# --- Routes (round 11) ---------------------------------------------------------------------------
# Where `routes` is on,
# it hears the head as before, but goes the way a route over places it fits
# goes (scripts/enemies/body_routes.gd): walking, climbing (on up over lips
# it doesn't fit on), jumping and dropping; a leg it can't make it gives up
# and plans round; where its head can't be got to, it goes to the place
# nearest it it can, then out (`_bail`).

## The search's slice of a frame (Âµs).
const ROUTE_US := 1500
## Turned further off its leg's way than this (rad), it turns on the spot.
const ROUTE_TURN := 0.4
## The head moved more than this from the goal planned for (m): planned again.
const GOAL_MOVED := 6.0
## Wandering (whole, out of hearing, lost): a goal this far off (m).
const WANDER := Vector2(25.0,45.0)
## A leap down out of a pocket: a goal this far off and down (m); a route
## ending within BAIL_NEAR m of it (not at its goal) is no way out.
const BAIL := Vector2(35.0,18.0)
const BAIL_NEAR := 4.0
var _bailing := 0
var _route_found := false
## Out along its leap or climb leg's way, at its start.
var _leg_out := false

## On a route now.
func _routed() -> bool:
	return _leg < _route.size()

## A route planned where it is to its head (heard, not lost), or to a goal
## off any way (whole, out of hearing, lost); the one it is on kept if its
## head is still where it was going and it is still on it.
func _plan() -> void:
	if float(knobs.routes) < 0.5: return
	if routes == null: routes = Routes.new(self)
	var goal := Vector3.INF
	var reach := 3.0
	# Lost (no nearer for `lost_after` s) counts only off a route that gets
	# there: a way round can lead away a while.
	if beacon != null:
		# To the beacon: where it stands to
		# look at it, as near as its routes get.
		goal = _beacon_goal()
		reach = length*0.5+beacon.gather
	elif not whole and head != null and (not lost() or (_route_found and _routed())) and Vector2(head.global_position.x-position.x,head.global_position.z-position.z).length() <= float(knobs.hear):
		goal = Vector3(head.global_position.x,head.ground_y(),head.global_position.z)
		reach = length*0.5+float(head.length)*0.5+float(knobs.reunite)
	else:
		# Along the way it picked as it listened (on as it faced, out of
		# hearing; any way, lost): a goal any way paced it back and forth
		# across one isle, never on into hearing.
		goal = _wander_goal(WANDER.x,WANDER.y,0.0,_heading)
		reach = 6.0
	if _routed() and goal.distance_to(_goal) < GOAL_MOVED and _on_leg(): return
	_start_search(goal,reach)

func _start_search(goal: Vector3, reach: float) -> void:
	_goal = goal
	_goal_reach = reach
	_route = []
	_leg = 0
	_leg_out = false
	plans += 1
	_search = Routes.Search.new(routes,position,goal,reach,_banned)

## A goal `near`-`far` m off any way (or `way`'s, as `facing`), `down` m
## under its feet.
func _wander_goal(near: float, far: float, down: float, way := INF) -> Vector3:
	var d := _rng.randf_range(near,far)
	if way != INF: return position+_way3(way)*d+Vector3.DOWN*down
	var a := _rng.randf_range(-PI,PI)
	return position+Vector3(sin(a)*d,-down,cos(a)*d)

## The search stepped; done, its route taken (none: out, `_bail`).
func _searching() -> void:
	if _search == null: return
	# After her, he climbs beside her walker-only stone, not through it.
	routes.shun_hers = _after and _chase_routed
	if not _search.step(ROUTE_US): return
	var s := _search
	_search = null
	_route = s.path
	_leg = 0
	_leg_out = false
	_leg_t = 0.0
	_route_found = s.found
	if s.found:
		routed_to += 1
		_bailing = 0
		if _chase_routed: chase_found += 1
		return
	routed_near += 1
	# A hunt's route that doesn't get to him: no bail (the hunt goes on).
	if _chase_routed: return
	if s.start == Routes.NONE: return
	if beacon != null:
		# A beacon it can't get to (up a spire): it walks as near as its
		# route gets, and looks from there (no bail).
		var end_b: Vector3 = _route[-1].to if not _route.is_empty() else position
		if Vector2(end_b.x-position.x,end_b.z-position.z).length() <= BAIL_NEAR:
			_beacon_near_as_can = true
			_route = []
		return
	# Nowhere much nearer (its route ends within BAIL_NEAR m): out of
	# here, down and away; a second time running, its old bearing.
	var end: Vector3 = _route[-1].to if not _route.is_empty() else position
	if Vector2(end.x-position.x,end.z-position.z).length() > BAIL_NEAR or _bailing >= 2:
		_bailing = 0
		return
	_bail()

## Nothing nearer its goal to get to from here: a route down and away (a
## drop off to a lower place, an isle under it), then it hears afresh.
func _bail() -> void:
	bails += 1
	_bailing += 1
	_start_search(_wander_goal(BAIL.x*0.6,BAIL.x,BAIL.y),8.0)

## Its legs walked: on to the next where it stands at a leg's end; a leg not
## made in `leg_slack` s given up (false: it stopped for that).
func _follow(delta: float) -> bool:
	_leg_t += delta
	while _routed() and _at_leg_end(): _next_leg()
	# Walking, past its leg's end toward the next (nearer the next's end
	# than its own is): on, not back.
	while _routed() and _leg+1 < _route.size() and _route[_leg].kind == "walk":
		var a: Vector3 = _route[_leg].to
		var b: Vector3 = _route[_leg+1].to
		if Vector2(a.x-position.x,a.z-position.z).length() > Routes.CELL*1.6 or Vector2(b.x-position.x,b.z-position.z).length() >= Vector2(b.x-a.x,b.z-a.z).length() or absf(a.y-position.y) > float(knobs.step)*2.0: break
		_next_leg()
	# Walking, a later walk leg's end it is at (it cut a corner): on to it.
	for i in range(_leg+1,mini(_leg+4,_route.size())):
		if _route[i-1].kind != "walk": break
		var to: Vector3 = _route[i].to
		if Vector2(to.x-position.x,to.z-position.z).length() <= Routes.CELL*0.9 and absf(to.y-position.y) <= float(knobs.step)*2.0:
			_leg = i+1
			_leg_t = 0.0
			_leg_out = false
	if not _routed():
		# Its route's end: homing, straight on at the head; else it hears
		# again (its head may have moved on).
		_route = []
		if state == "home": return true
		if state == "chase":
			_chase_routed = false
			if _after:
				# Up where it went after him: a fresh look about from here
				# (once a loss: on along his way, it presses on).
				_after = false
				after_got += 1
				if _after_k == 0: _scoped = false
			return false
		_go("listen")
		return false
	var leg: Dictionary = _route[_leg]
	var slack := float(knobs.leg_slack)*(1.0 if leg.kind == "walk" else 1.6)
	if _leg_t > slack:
		_leg_failed("slow")
		return false
	return true

func _next_leg() -> void:
	_leg += 1
	_leg_t = 0.0
	_leg_out = false

## Stood at the end of the leg it is on (its place, within a cell flat).
func _at_leg_end() -> bool:
	var to: Vector3 = _route[_leg].to
	var near := Routes.CELL*(0.9 if _route[_leg].kind == "walk" else 1.4)
	# Olmec round 1: a walk leg's end by a wall its bulk is held off.
	if _route[_leg].kind == "walk" and _clock-_pushed_at < 0.3: near += hh*BULK_W
	return Vector2(to.x-position.x,to.z-position.z).length() <= near and absf(to.y-position.y) <= float(knobs.step)*2.0

## Back where it was on its leg (within a cell or so of its start or end).
func _on_leg() -> bool:
	if not _routed(): return false
	for p: Vector3 in [_route[_leg].from,_route[_leg].to]:
		if Vector2(p.x-position.x,p.z-position.z).length() <= Routes.CELL*1.6 and absf(p.y-position.y) <= float(knobs.step)*2.0: return true
	return false

## Only walking left to its route's end.
func _walk_left() -> bool:
	for i in range(_leg,_route.size()):
		if _route[i].kind != "walk": return false
	return true

## The way its leg goes: walking, at the furthest of the next few walk legs
## within a few metres; a climb or a leap, to the leg's start, then out
## along its way.
func _route_heading() -> float:
	var leg: Dictionary = _route[_leg]
	var aim: Vector3 = leg.to
	if leg.kind == "walk":
		for i in range(_leg+1,mini(_leg+4,_route.size())):
			var next: Dictionary = _route[i]
			if next.kind != "walk": break
			var p: Vector3 = next.to
			if Vector2(p.x-position.x,p.z-position.z).length() > 6.0: break
			aim = p
	else:
		# To the leg's start, then out along its way; once there it keeps
		# on out (it doesn't turn back for its start as it walks on from
		# it: that turned it back and forth at the rim).
		var from: Vector3 = leg.from
		var d: Vector2 = leg.d
		var off := Vector2(from.x-position.x,from.z-position.z).length()
		if off <= Routes.CELL*1.2: _leg_out = true
		elif off > Routes.CELL*3.0: _leg_out = false
		if _leg_out: aim = position+Vector3(d.x,0.0,d.y)*Routes.CELL*3.0
		else: aim = from
	var to := Vector2(aim.x-position.x,aim.z-position.z)
	if to.length() < 0.05: return facing
	return PilotMotor.facing_of(to.normalized())

## The leg it's on can't be made (a wall or an edge where it walks, a leap
## with no landing, too slow): never again this way; it stops, hears and
## plans round it.
func _leg_failed(why: String) -> void:
	var leg: Dictionary = _route[_leg]
	fail_why = "%s %s leg %d/%d at %s to %s" % [why,leg.kind,_leg,_route.size(),str(position.snapped(Vector3.ONE*0.1)),str((leg.to as Vector3).snapped(Vector3.ONE*0.1))]
	_banned[Routes.Search._key(leg.from_node,leg.node)] = true
	leg_fails += 1
	_route = []
	_leg = 0
	_leg_out = false
	vel.x = 0.0
	vel.z = 0.0
	# Hunting on a route (city breaks round 1): still hunting, it plans
	# again at once without that move.
	if state == "chase" and _chase_routed:
		var was_after := _after
		_chase_drop()
		_chase_plan_at = _clock
		# After him: the same place again, round that move (a try).
		if was_after: _after_again()
		return
	# A short beat (not a whole listen) and it plans again.
	_go("listen")
	state_t = float(knobs.listen)*0.6
	_listen_from = facing

## A fall that doesn't fall (wedged between faces): a second with less than
## half a metre down, it is eased out toward the most open way.
func _unwedge(delta: float) -> void:
	if state != "fall":
		_fall_from = Vector3.INF
		_fall_t = 0.0
		return
	_fall_t += delta
	if _fall_t < 1.0: return
	if _fall_from != Vector3.INF and _fall_from.y-position.y < 0.5:
		var best := Vector3.ZERO
		var far := 0.0
		for k in 8:
			var d := _way3(k*TAU/8.0)
			var hit := _cast(position+Vector3.UP*1.0,position+Vector3.UP*1.0+d*4.0)
			var free := 4.0 if hit.is_empty() else (hit.position as Vector3).distance_to(position+Vector3.UP*1.0)
			if free > far:
				far = free
				best = d
		position += best*0.6
		vel.x = best.x*2.0
		vel.z = best.z*2.0
	_fall_from = position
	_fall_t = 0.0

## Its routes' numbers, for checks.
func route_stats() -> String:
	return "plans %d to %d near %d fails %d bails %d perches %d rays %d" % [plans,routed_to,routed_near,leg_fails,bails,perches,routes.rays if routes != null else 0]

# --- The whole body's chase -------------------------------------------
# Whole, with `chase` on: it sees the walker (`sight`), and spotted, comes for
# him, swatting him near, pouncing on him a little way off, sucking him in
# with its head's breath further off; lost, it looks where it last saw him,
# then goes back. Off (`chase` 0), none of this runs: the generator's bodies
# and the headless body isle's are as they were.

## The windup's crouch held through the inhale (its share of the clip).
const BRACE := 0.45
## The triumph clip's fists-down beat (of its 1.8 s): the swat's hit.
const TRIUMPH_HIT := 1.34/1.8
## Turned further off its way than this (rad) chasing, it turns on the spot.
const CHASE_TURN := 0.8
## Skirting a wall: ways tried off the way to its goal (rad), and how long
## it holds one (s).
const SKIRT := [0.7,1.2,1.8,2.4]
const SKIRT_FOR := 1.2

## What it sees (scripts/enemies/body_sight.gd), made once it is whole.
var sight: RefCounted = null
## Hunting him (spotted, till it gives up looking).
var hunting := false
## Where it last saw his feet (INF never), the time since (s).
var seen_at := Vector3.INF
var seen_t := INF
## Where it was set down (it goes back there, giving up).
var _post := Vector3.ZERO
## When it may pounce again, suck again (its clock, s).
var _pounce_ready := 0.0
var _suck_ready := 0.0
var _suck_unseen := 0.0
var _seek_from := 0.0
var _swat_hit := false
var _skirt_way := 0.0
var _skirt_t := 0.0
## Counted, for its study's HUD and checks.
var spots := 0
var pounces := 0
var sucks := 0
var gulps := 0
var swats := 0
var catches := 0
var misses := 0
var gave_up := 0
var last_catch := ""

## The chase on: whole, `chase` 1.
func _chases() -> bool:
	return whole and float(knobs.chase) >= 0.5

## The same, for its head (scripts/enemies/inhaler_head.gd `_worn`).
func chasing_whole() -> bool:
	return _chases()

## Whole now: `h` on its neck (its study sets it down whole).
func make_whole(h: Node3D) -> void:
	head = h
	head.perch = self
	whole = true
	homed = false
	_seat_k = 1.0
	rest()
	_go("listen")

## Where it looks from: between the head's eyes (its neck headless).
func _eye() -> Vector3:
	if head != null and is_instance_valid(head) and head.perch == self:
		return head.mouth()+Vector3.UP*float(head.height)*0.3
	return position+Vector3.UP*neck_h

## Looks for him; spotted from a calm state, the hunt is on.
func _see(delta: float) -> void:
	if sight == null:
		sight = Sight.new()
		sight.tune(knobs)
	var m: PilotMotor = field.motor
	sight.mask = WalkerOnly.strip(field.study.ground.mask)
	# `sight_walker_only` 1: walker-only stone (a niche, a hush gallery)
	# hides him from its eyes, though it can't walk or climb it.
	if float(knobs.get("sight_walker_only",0)) >= 0.5: sight.mask |= WalkerOnly.LAYER
	# Held up, it looks down and about more widely (`scope_wide` times its cone).
	# Olmec threat round 1: hunting (relentless) he sees further and wider,
	# loses you slower, and the dark hides you less.
	var hunt := hunting and _relentless()
	sight.deep = float(knobs.hunt_range) if hunt else float(knobs.sight_range)
	sight.grace = float(knobs.hunt_grace) if hunt else float(knobs.sight_grace)
	sight.drain = float(knobs.hunt_drain) if hunt else float(knobs.sight_drain)
	sight.dark_range = float(knobs.hunt_dark_range) if hunt else float(knobs.sight_dark_range)
	sight.dark_seen = float(knobs.hunt_dark_seen) if hunt else float(knobs.sight_dark_seen)
	sight.half = (float(knobs.hunt_half) if hunt else float(knobs.sight_half))*(float(knobs.scope_wide) if state == "scope" and _held_w > 0.5 else 1.0)
	sight.exclude = _skip()
	if m.seized():
		# In its mouth: held, not looked for.
		sight.step(delta,1.0)
		seen_at = m.feet
		seen_t = 0.0
		return
	var pts := Sight.pilot_points(m.feet,false)
	# How lit he stands: by day, no change.
	LightLevel.refresh(get_tree())
	if LightLevel.daylight(): sight.light(1.0,0.0)
	else: sight.light(LightLevel.exposure(get_tree(),pts[1]),LightLevel.glow(get_tree(),pts[1]))
	sight.update(delta,field.study.get_world_3d().direct_space_state,_eye(),_look_way(),pts,not m.grounded)
	if sight.seeing():
		seen_at = m.feet
		seen_t = 0.0
		if state != "scope": _scoped = false
		_trail_seen(m.feet)
	else: seen_t += delta
	if sight.state == "spotted" and sight.seeing() and (state in ["listen","roam","alert","seek","return"] or (not hunting and state == "triumph")):
		_spot()
	elif not hunting and sight.state == "suspicious" and state in ["listen","roam"]:
		_route = []
		_search = null
		_go("alert")

func _spot() -> void:
	if not hunting:
		spots += 1
		field.sound(&"head_call",_eye())
		chase_beat.emit("spotted")
	hunting = true
	_route = []
	_leg = 0
	_search = null
	_skirt_t = 0.0
	tell(mark_colour)
	_go("chase")

## Where it goes on after a climb, a leap or a beat: the hunt, or listening.
func _resume() -> String:
	if not _chases(): return "listen"
	return "chase" if hunting else "listen"

## The text its study's overlay shows: what it is doing and why.
func doing() -> String:
	var m: PilotMotor = field.motor
	var d := Vector2(m.feet.x-position.x,m.feet.z-position.z).length()
	var line := "%s %.1fs · %.1f m/s\nyou %.1f m (%.1f Hh) off, %+.1f m up" % [state,state_t,Vector2(vel.x,vel.z).length(),d,d/hh,m.feet.y-position.y]
	if not _chases(): return line
	if _scopes() or state == "scope":
		line += "\nperiscope %s · %d up, %d found%s" % [scope_phase if state == "scope" else "-",scopes,scope_finds,
			"" if _clock >= _scope_ready else " · resting %.1fs" % (_scope_ready-_clock)]
	line +="\nswat ≤%.1f m · pounce %.1f-%.1f m %s\nsuck %.1f-%.1f m %s" % [float(knobs.catch_reach)*hh,float(knobs.pounce_min)*hh,float(knobs.pounce_max)*hh,
		_ready_text(_pounce_ready),float(knobs.suck_min)*hh,float(knobs.suck_max)*hh,_ready_text(_suck_ready)]
	return line

func _ready_text(at: float) -> String:
	if _clock >= at: return "ready"
	return "resting %.1fs" % (at-_clock) if at-_clock < 100.0 else "off"

## Spotted: at him (seen) or where it last saw him, attacking as his
## distance says.
func _chase(delta: float) -> void:
	var m: PilotMotor = field.motor
	var seeing: bool = sight.seeing()
	# Unseen, it goes where it last saw him, or where it went after him.
	var target := m.feet if seeing else (_after_at if _after_at != Vector3.INF else seen_at)
	var to := target-position
	var flat := Vector2(to.x,to.z).length()
	var after := _chase_routed and _after
	if not seeing:
		if after:
			# Climbing after him: on up its route; unseen too long, it gives
			# that up (and looks about where it is, next).
			if seen_t > float(knobs.after_for):
				after_why = "unseen %.0f s" % seen_t
				_chase_drop()
				_after_at = Vector3.INF
				return
		# Olmec threat round 1: relentless, where you were about his level
		# he simply comes on (no scope, no route), till he's there.
		elif _relentless() and absf(to.y) < neck_h*0.6 and flat > float(knobs.search_reach) and seen_t <= float(knobs.hunt_memory): pass
		elif flat <= float(knobs.search_reach) or seen_t > (float(knobs.hunt_memory) if _relentless() else float(knobs.chase_memory)):
			if _scope_try("seek"): return
			if _after_try(): return
			_seek_start()
			return
		# Lost him near where it saw him last: it plants and looks over.
		elif seen_t > float(knobs.scope_wait) and flat <= float(knobs.scope_near)*hh and _scope_try("chase"): return
		# Lost him up out of its walk: after him, by a route.
		elif seen_t > float(knobs.after_wait) and _after_try(): return
	elif _attack(m,flat,to.y): return
	elif after and to.y <= _after_rise():
		# Seen again about its own level: straight at him.
		_chase_drop()
		_after_at = Vector3.INF
	elif after and m.feet.distance_to(_after_from) > GOAL_MOVED and _clock >= _chase_plan_at:
		# Seen up there, moved on: after him afresh.
		_chase_plan_at = _clock+float(knobs.chase_replan)
		_chase_drop()
		if _after_try(m.feet): return
	# Right under him, him up out of its reach: a moment, then after him
	# by a route (`climb_after`), or it looks about (round 2: it paced
	# under him for good).
	if seeing and not after and to.y > float(knobs.step)*STAIR*1.5 and flat < length*1.5+float(knobs.search_reach):
		_under_t += delta
		if _under_t > UNDER_GIVE:
			_under_t = 0.0
			if _after_try(m.feet): return
			_seek_start()
			return
	else: _under_t = 0.0
	if _chase_routing(delta,target): return
	_pursue(delta,target,float(knobs.chase_speed))

# --- City breaks round 1: the hunt over its planner's routes ----------------------------------

## On a route to him (`chase_routes`), planned at an edge it couldn't leap.
var _chase_routed := false
var _chase_plan_at := -INF
## Chase routes planned, and those found (counted, for checks).
var chase_plans := 0
var chase_found := 0

## An edge it can't leap, him beyond it: a route to him, if it's time.
func _chase_plan(goal: Vector3) -> bool:
	if state != "chase" or float(knobs.chase_routes) < 0.5 or float(knobs.routes) < 0.5: return false
	if _clock < _chase_plan_at: return false
	_chase_plan_at = _clock+float(knobs.chase_replan)
	if routes == null: routes = Routes.new(self)
	_chase_routed = true
	chase_plans += 1
	_start_search(goal,length*0.5+2.0)
	return true

## On its route to him: planning (it waits), walking it as roaming does
## (climbs and leaps by its legs), planned again if he moved far. False:
## no route (it hunts as ever).
func _chase_routing(delta: float, target: Vector3) -> bool:
	if not _chase_routed: return false
	if _search != null:
		_brake(delta)
		return true
	if not _routed() or (not _route_found and not (_after and _after_gets_up())):
		if _after:
			after_why = "no way up there"
			after_fails += 1
			_after_at = Vector3.INF
		_chase_drop()
		return false
	if not _after and target.distance_to(_goal) > GOAL_MOVED and _clock >= _chase_plan_at:
		_chase_plan_at = _clock+float(knobs.chase_replan)
		chase_plans += 1
		_start_search(target,length*0.5+2.0)
		_brake(delta)
		return true
	_walking(delta)
	return true

func _chase_drop() -> void:
	_chase_routed = false
	_after = false
	_route = []
	_leg = 0
	_search = null

# --- Climbing after him -------------------------------------------
# Hunting, with `climb_after` on: lost from sight up out of its walk (over a
# lip it can climb, up a long stair), it doesn't give up at the foot. It
# plans a route (its planner's moves: no refuge it doesn't fit, no wall
# past `climb_max`) to the place it fits nearest where it last saw him,
# climbs after him, hauls over the top and looks about from there (the
# periscope afresh, then its search); not there, on along his last way up
# `after_ahead` m. At most `after_tries` routes a loss, none once he's
# been unseen `after_for` s; a route that doesn't get it up there is
# given up, and it searches where it stands, then goes back.

## The chase route now one after him, and how many this loss (reset when
## it sees him), how far on along his way it pushed, where it goes (INF
## none), the spot it planned from (his feet or where it last saw them).
var _after := false
var _after_n := 0
var _after_k := 0
var _after_at := Vector3.INF
var _after_from := Vector3.INF
var _after_ready := 0.0
## Where it stood when it first went after him this loss.
var _after_start := Vector3.INF
## His feet seen these last AFTER_TRAIL s ([time, feet], oldest first), and
## his way over them (m: where his feet went).
var _trail: Array = []
var _seen_way := Vector3.ZERO
var _trail_dt := 0.0
## Counted: routes after him, those that got it there, those that didn't;
## why the last try didn't go.
var afters := 0
var after_got := 0
var after_fails := 0
var after_why := ""
const AFTER_TRAIL := 2.5
## Risen this much over the trail (m): he was going up.
const AFTER_RISE := 0.8
## Tries this far apart at least (s).
const AFTER_GAP := 1.0
## Where it goes is the place it fits nearest the spot, within this (m
## flat), and this (m) over the spot at most.
const AFTER_NEAR := 7.5
const AFTER_UP := 4.0
## Pushed on along his way this far at most (m).
const AFTER_FAR := 45.0

func _trail_seen(feet: Vector3) -> void:
	_trail.append([_clock,feet])
	while _trail.size() > 2 and _clock-float(_trail[0][0]) > AFTER_TRAIL: _trail.pop_front()
	_seen_way = feet-(_trail[0][1] as Vector3)
	_trail_dt = _clock-float(_trail[0][0])
	_after_n = 0
	_after_k = 0
	if not _after: _after_at = Vector3.INF

## Within this (m, flat) of where it went after him, it's there.
func _after_near() -> float:
	return maxf(float(knobs.search_reach)+length*0.5,float(knobs.scope_near)*hh)

## Over this (m, on its feet) it can't walk up to: a wall, a ledge.
func _after_rise() -> float:
	return float(knobs.step)*STAIR*1.5

## Its route after him, not all the way, gets it up near where it goes.
func _after_gets_up() -> bool:
	if _route.is_empty() or _after_at == Vector3.INF: return false
	var end: Vector3 = _route[-1].to
	return Vector2(end.x-_after_at.x,end.z-_after_at.z).length() <= AFTER_NEAR and end.y >= _after_at.y-float(knobs.step)*2.0 \
		and end.y > position.y+float(knobs.step)

## After him, if it may: lost up out of its walk (or `at`, his feet seen
## up there with no way at him), to where it last saw him; there already,
## on along his way, if he went up. True: a route is being planned.
func _after_try(at := Vector3.INF) -> bool:
	if float(knobs.get("climb_after",0)) < 0.5 or float(knobs.routes) < 0.5 or not hunting: return false
	if _clock < _after_ready: return false
	var seen := at if at != Vector3.INF else seen_at
	if seen == Vector3.INF: return false
	if at == Vector3.INF and seen_t > float(knobs.after_for):
		after_why = "unseen %.0f s" % seen_t
		return false
	if _after_n >= int(knobs.after_tries):
		after_why = "tried %d" % _after_n
		return false
	var rise := _after_rise()
	var up := seen.y > position.y+rise
	var here := (_after_at if _after_at != Vector3.INF else seen)
	var near := Vector2(here.x-position.x,here.z-position.z).length() <= _after_near() and absf(here.y-position.y) < rise
	var p := seen
	if not near and not up:
		after_why = "not there yet"
		return false
	if near:
		# At where it last saw him (or went after him): on along his way,
		# if that went up.
		var went_up := _seen_way.y >= AFTER_RISE or (_after_start != Vector3.INF and seen.y > _after_start.y+rise)
		if at != Vector3.INF or not went_up:
			after_why = "he didn't go up"
			return false
		var way := Vector2(_seen_way.x,_seen_way.z)
		# Straight up a face: on away from it, the way it came at him.
		if way.length() < 1.0 and _after_start != Vector3.INF: way = Vector2(seen.x-_after_start.x,seen.z-_after_start.z)
		if way.length() < 1.0: way = PilotMotor.forward(facing)
		_after_k += 1
		# As far on as he'd have gone at the pace it last saw him at, since
		# (`after_ahead` m at least, AFTER_FAR at most), and as much up as
		# his way rose: the place it fits nearest that, or nearer.
		var flat_way := Vector2(_seen_way.x,_seen_way.z).length()
		var pace := flat_way/maxf(_trail_dt,0.1)
		var ahead := clampf(pace*seen_t,float(knobs.after_ahead)*_after_k,AFTER_FAR)
		var slope := clampf(_seen_way.y/maxf(flat_way,1.0),0.0,1.0)
		var dir := Vector3(way.normalized().x,0.0,way.normalized().y)
		_after_ready = _clock+AFTER_GAP
		var goal_p := Vector3.INF
		for share: float in [1.0,0.6,0.3]:
			goal_p = _after_goal(seen+(dir+Vector3.UP*slope)*ahead*share,seen)
			if goal_p != Vector3.INF: break
		p = goal_p
	_after_ready = _clock+AFTER_GAP
	var goal := p if near else _after_goal(p,seen)
	if goal == Vector3.INF:
		after_why = "no place up there"
		return false
	if Vector2(goal.x-position.x,goal.z-position.z).length() <= _after_near() and absf(goal.y-position.y) < rise:
		after_why = "nowhere further"
		return false
	if _after_n == 0: _after_start = position
	_after_n += 1
	afters += 1
	_after_at = goal
	_after_from = seen
	if routes == null: routes = Routes.new(self)
	_chase_routed = true
	_after = true
	_chase_plan_at = _clock+float(knobs.chase_replan)
	_start_search(goal,length*0.5+2.0)
	after_why = "after him to %s" % str(goal.snapped(Vector3.ONE*0.1))
	chase_beat.emit("after")
	return true


## A leg of its route after him failed: planned again to the same place,
## round it, if it has a try left.
func _after_again() -> bool:
	if _after_at == Vector3.INF or _after_n >= int(knobs.after_tries) or seen_t > float(knobs.after_for): return false
	_after_n += 1
	afters += 1
	_chase_routed = true
	_after = true
	_start_search(_after_at,length*0.5+2.0)
	after_why = "after him again to %s" % str(_after_at.snapped(Vector3.ONE*0.1))
	return true

## The place it fits nearest `p` (looked for within AFTER_NEAR m flat of it,
## from a little under `seen` to AFTER_UP over the higher of them, none
## under its own feet): its floor, INF none.
func _after_goal(p: Vector3, seen: Vector3) -> Vector3:
	if routes == null: routes = Routes.new(self)
	routes.refresh()
	var lo := maxf(minf(seen.y,p.y)-float(knobs.step)*2.0,position.y-float(knobs.step))
	var hi := maxf(seen.y,p.y)+AFTER_UP
	var c := Routes.cell_of(p)
	var n := ceili(AFTER_NEAR/Routes.CELL)
	var best := Vector3.INF
	var best_d := INF
	for dx in range(-n,n+1):
		for dz in range(-n,n+1):
			var cc := c+Vector2i(dx,dz)
			if Routes.centre(cc).distance_to(Vector2(p.x,p.z)) > AFTER_NEAR: continue
			var f := routes.col(cc)
			for i in range(0,f.size(),2):
				if f[i] < lo or f[i] > hi: continue
				var u := Vector3i(cc.x,cc.y,i/2)
				var q := routes.at(u)
				var d := q.distance_to(p)
				if d >= best_d or not routes.fits(u): continue
				best = q
				best_d = d
	return best

## The attack his distance calls for (`flat` m off, `dy` up), if any: the
## swat within reach, the pounce a little way off, the suck further.
func _attack(m: PilotMotor, flat: float, dy: float) -> bool:
	if m.seized(): return false
	if flat <= float(knobs.catch_reach)*hh and absf(dy) < neck_h*0.6:
		swats += 1
		_swat_hit = false
		_go("swat")
		field.sound(&"body_windup",position)
		chase_beat.emit("swat")
		return true
	if flat >= float(knobs.pounce_min)*hh and flat <= float(knobs.pounce_max)*hh and _clock >= _pounce_ready \
			and dy <= float(knobs.pounce_rise)*hh and dy >= -float(knobs.pounce_sink)*hh:
		var at := _pounce_spot(m)
		# Olmec round 1: room for the crouch, its arms swept back, turned to him.
		var to_at := Vector2(at.x-position.x,at.z-position.z) if at != Vector3.INF else Vector2.ZERO
		if at != Vector3.INF and _arc_clear(at,"pounce") and _room_for(PilotMotor.facing_of(to_at.normalized()) if to_at.length() > 0.01 else facing,WINDUP_ROOM):
			_leap_to = at
			leap_kind = "pounce"
			_go("windup")
			field.sound(&"body_windup",position)
			chase_beat.emit("pounce")
			return true
	if flat >= float(knobs.suck_min)*hh and flat <= float(knobs.suck_max)*hh*(1.3 if _relentless() else 1.0) and _clock >= _suck_ready and head != null and head.perch == self \
			and head.has_method("worn_reaches") and head.worn_reaches(m):
		sucks += 1
		_suck_unseen = 0.0
		_go("plant")
		field.sound(&"head_inhale",head.mouth())
		chase_beat.emit("suck")
		return true
	return false

## The floor under his feet (where a pounce comes down), INF none.
func _pounce_spot(m: PilotMotor) -> Vector3:
	var g := _floor(m.feet+Vector3.UP*0.5,1.0,6.0)
	if g == -INF: return Vector3.INF
	return Vector3(m.feet.x,g,m.feet.z)

## The windup's length (s): the pounce's own, quicker.
func _windup_s() -> float:
	return float(knobs.pounce_windup) if leap_kind == "pounce" else float(knobs.windup)

## Walked at `goal` at `speed` m/s: turned to it (on the spot if far off),
## a wall met climbed (he's up there) or skirted, an edge met leapt.
func _pursue(delta: float, goal: Vector3, speed: float) -> void:
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	if _skirt_t > 0.0:
		_skirt_t -= delta
		_heading = _skirt_way
	elif to.length() > 0.05: _heading = PilotMotor.facing_of(to.normalized())
	if _grab_try(delta,goal): return
	# A rim it would grab, too far off: it heads for where it would hang from
	# it (out from under a place over it, too).
	if _grab_aim != Vector3.INF and _skirt_t <= 0.0:
		var aim := Vector2(_grab_aim.x-position.x,_grab_aim.z-position.z)
		if aim.length() > 0.3: _heading = PilotMotor.facing_of(aim.normalized())
	var turn := float(knobs.turn)*float(knobs.chase_turn)
	var off := angle_difference(facing,_heading)
	# Olmec round 1: a big turn plants first (braked, not swung round at
	# speed), then steps round, and only then strides on.
	var big := absf(off) > CHASE_TURN or look.steps.busy()
	if not big or Vector2(vel.x,vel.z).length() < 0.3: facing = wrapf(facing+clampf(off,-turn*delta,turn*delta),-PI,PI)
	if big:
		_brake(delta)
		return
	var fwd := _forward3()
	var wall := _wall_along(fwd,length*0.5+float(knobs.look),true)
	if not wall.is_empty():
		_hunt_wall(wall,goal)
		return
	var ahead := clampf(to.length()+0.3,0.6,length*0.5+float(knobs.look))
	if _floor(position+fwd*ahead,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF:
		_hunt_edge(fwd,goal)
		return
	var aligned := clampf(cos(angle_difference(facing,_heading)),0.0,1.0)
	var want := PilotMotor.forward(facing)*speed*aligned*aligned
	var flat := Vector2(vel.x,vel.z).move_toward(want,float(knobs.accel)*delta)
	vel.x = flat.x
	vel.z = flat.y

## A wall in the way of the hunt: climbed if its goal is up over its feet
## (or there is no way round), else skirted.
func _hunt_wall(hit: Dictionary, goal: Vector3) -> void:
	vel.x = 0.0
	vel.z = 0.0
	# Cover in the way to where it lost him: it looks over it first.
	# (Relentless, he knows where you are: no looking over, on at it.)
	if state == "chase" and not sight.seeing() and not _relentless() and _scope_try("chase"): return
	var top := _climbable(hit)
	if top != INF and goal.y > position.y+float(knobs.step)*2.0:
		_start_climb(hit)
		return
	# Olmec threat round 1: masonry in his way, you past it about his
	# level: he smashes through it (`breach`).
	if state == "chase" and _breach_try(hit,goal): return
	# City breaks round 2: a wall past his climb, him beyond it (through a
	# gate he broke open): a route to him, as at an edge (`chase_routes`).
	if top == INF and _chase_plan(goal): return
	var way := _skirt(goal)
	if way != INF:
		_skirt_way = way
		_skirt_t = SKIRT_FOR
		return
	if top != INF:
		_start_climb(hit)
		return
	_stuck()

## An edge in the way: a ledge across (a jump) or a floor under its goal
## (a drop) leapt to; else along the rim, or it stops there.
func _hunt_edge(fwd: Vector3, goal: Vector3) -> void:
	vel.x = 0.0
	vel.z = 0.0
	var land := _landing(fwd)
	if not land.is_empty() and (land.kind == "jump" or goal.y < position.y-float(knobs.step)):
		_leap_to = land.at
		leap_kind = land.kind
		_go("windup")
		field.sound(&"body_windup",position)
		return
	if _chase_plan(goal): return
	var way := _skirt(goal)
	if way != INF:
		_skirt_way = way
		_skirt_t = SKIRT_FOR
		return
	_stuck()

## No way on: hunting, it looks about where it stands; going back, it roams.
func _stuck() -> void:
	if state == "chase": _seek_start()
	else:
		rest()
		_go("listen")

## A way off the way to `goal` with no wall near and floor ahead (the one
## nearest the goal's way), INF none.
func _skirt(goal: Vector3) -> float:
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	var base := PilotMotor.facing_of(to.normalized()) if to.length() > 0.05 else facing
	for a: float in SKIRT:
		for s: float in [1.0,-1.0]:
			var way := wrapf(base+a*s,-PI,PI)
			var dir := _way3(way)
			if not _wall_along(dir,length*0.5+float(knobs.look)+1.5,true).is_empty(): continue
			if _floor(position+dir*(length*0.5+float(knobs.look)),float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: continue
			return way
	return INF

## Suspicious: it stops and turns to where it glimpsed him.
func _alert(delta: float) -> void:
	_brake(delta)
	if seen_at != Vector3.INF:
		var to := Vector2(seen_at.x-position.x,seen_at.z-position.z)
		if to.length() > 0.1:
			var turn := float(knobs.turn)*1.5*delta
			facing = wrapf(facing+clampf(angle_difference(facing,PilotMotor.facing_of(to.normalized())),-turn,turn),-PI,PI)
	if sight.state == "unaware": _go("listen")

func _seek_start() -> void:
	_seek_from = facing
	_go("seek")
	chase_beat.emit("lost")

## Where it last saw him: it looks about, `search_for` s; then gives up.
func _seek(delta: float) -> void:
	_brake(delta)
	var k := state_t/float(knobs.search_for)
	var was := facing
	facing = wrapf(_seek_from+sin(k*TAU*1.5)*0.9,-PI,PI)
	# Turning to scan, it steps round on the spot (its feet's phase).
	_seek_turn = absf(angle_difference(was,facing))/maxf(delta,0.0001)
	_phase += _seek_turn*delta*SEEK_STEP
	if _relentless() and state_t >= float(knobs.hunt_search):
		_scent()
		return
	if state_t >= float(knobs.search_for):
		hunting = false
		gave_up += 1
		rest()
		chase_beat.emit("gave up")
		_skirt_t = 0.0
		# Its post not on a floor it can get back to: straight to roaming.
		if _floor(_post,1.0,3.0) == -INF: _go("listen")
		else: _go("return")

## Back to where it was set down, walking; there (or `return_for` s on), it
## roams.
func _return(delta: float) -> void:
	var to := Vector2(_post.x-position.x,_post.z-position.z)
	if to.length() < 3.0 or state_t > float(knobs.return_for):
		_go("listen")
		return
	_pursue(delta,_post,float(knobs.walk))

## The suck: planted, its head's jaw opening (`suck_tell` s), then the
## inhale (`suck_for` s, he out of its sight `suck_lose` s ends it), turned
## slowly after him; he swallowed, it holds still till its head blows him
## out, then spent.
func _suck(delta: float) -> void:
	_brake(delta)
	if head == null or not is_instance_valid(head) or head.perch != self:
		_go(_resume())
		return
	if head.swallowed:
		if state != "gulp":
			gulps += 1
			_go("gulp")
			chase_beat.emit("gulped")
		return
	if state == "gulp":
		_suck_ready = _clock+float(knobs.suck_rest)
		_go("spent")
		chase_beat.emit("blown out")
		return
	var m: PilotMotor = field.motor
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	if to.length() > 0.1:
		var turn := float(knobs.suck_turn)*delta
		facing = wrapf(facing+clampf(angle_difference(facing,PilotMotor.facing_of(to.normalized())),-turn,turn),-PI,PI)
	_suck_unseen = 0.0 if sight.seeing() else _suck_unseen+delta
	if state == "plant" and state_t >= float(knobs.suck_tell): _go("suck")
	elif state == "suck" and (state_t >= float(knobs.suck_for) or _suck_unseen > float(knobs.suck_lose)):
		_suck_ready = _clock+float(knobs.suck_rest)
		_go("spent")

## Its head's draw asked (scripts/enemies/inhaler_head.gd `_worn`): 0 none,
## the jaw opening as it plants (under 1), 1 the inhale.
func worn_draw() -> float:
	if not _chases(): return 0.0
	match state:
		"plant": return clampf(state_t/float(knobs.suck_tell),0.01,0.99)
		"suck","gulp": return 1.0
		"scope": return _scope_draw()
	return 0.0

## Whether he is drawn in to its feet (its head swallows him there): in
## front of it within `suck_gulp` m of its front, no higher than its neck.
func worn_gulp(feet: Vector3) -> bool:
	var scoped := state == "scope" and scope_phase == "suck"
	if state != "suck" and not scoped: return false
	var local := Basis(Vector3.UP,facing).inverse()*(feet-position)
	# Drawn in under its raised head: at its front, anywhere up to the head.
	if scoped:
		return local.z < 0.0 and local.z > -(length*0.5+float(knobs.suck_gulp)) and absf(local.x) < width*0.5+float(knobs.suck_gulp) \
			and feet.y < _held_at.y+float(head.height) and feet.y > position.y-1.0
	return local.z < 0.0 and local.z > -(length*0.5+float(knobs.suck_gulp)) and absf(local.x) < width*0.5+float(knobs.suck_gulp)*0.5 \
		and feet.y < position.y+neck_h and feet.y > position.y-1.0

## The swat: arms up `swat_windup` s, then the fists down; in reach, caught.
func _swat(delta: float) -> void:
	_brake(delta)
	var m: PilotMotor = field.motor
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	if not _swat_hit and to.length() > 0.1:
		facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-6.0*delta))
	if not _swat_hit and state_t >= float(knobs.swat_windup):
		_swat_hit = true
		quake = maxf(quake,0.3)
		field.sound(&"body_land",position+_forward3()*length)
		_puff(position+_forward3()*(length*0.5+arm_l*0.6),hh*1.2)
		if to.length() <= float(knobs.catch_reach)*hh+0.5 and absf(m.feet.y-position.y) < neck_h*0.6 and not m.seized():
			_catch(m,"swat")
		else:
			misses += 1
			chase_beat.emit("missed")
	if state_t >= float(knobs.swat_windup)+float(knobs.swat_after): _go(_resume())

## The punch through a wall (round 2): eased, not braked, so his stride
## carries on through it; the hit at SMASH_WINDUP, then on as he was.
func _smash(delta: float) -> void:
	var keep := exp(-SMASH_EASE*delta)
	vel.x *= keep
	vel.z *= keep
	if not _smash_hit and state_t >= SMASH_WINDUP:
		_smash_hit = true
		quake = maxf(quake,0.6)
		if not _breach_hit.is_empty():
			if breacher != null and is_instance_valid(breacher): breacher.smash(self,_breach_hit)
			_breach_hit = {}
		elif breaker != null: breaker.smash(self)
	if state_t >= SMASH_WINDUP+SMASH_AFTER: _go(_smash_from if _smash_from != "" else _resume())

## Olmec threat round 1: a wall hit in the hunt's way that its breacher
## can take down, you past it no higher than a climb's worth: the punch.
func _breach_try(hit: Dictionary, goal: Vector3) -> bool:
	if float(knobs.breach) < 0.5 or breacher == null or not is_instance_valid(breacher): return false
	if goal.y > position.y+neck_h*0.8: return false
	if not breacher.can_breach(self,hit): return false
	_breach_hit = hit
	_smash_from = state
	_smash_hit = false
	smashes += 1
	breaches += 1
	_go("smash")
	field.sound(&"body_windup",position)
	chase_beat.emit("breach")
	return true

## Caught him (`how`, "swat" or "pounce"): knocked down and away (no damage).
func _catch(m: PilotMotor, how: String) -> void:
	var way := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	way = way.normalized() if way.length() > 0.1 else PilotMotor.forward(facing)
	if float(knobs.void_push) > 0.0: way = OlmecVoid.toward(field,m.feet,way,float(knobs.void_push))
	m.knock(m.knock_velocity(way,float(knobs.swat_out),float(knobs.swat_up)),self,float(knobs.swat_down))
	m.harm(harm_cause(),1,self)
	_cool = 0.3
	hit_pilot.emit(self)
	catches += 1
	last_catch = how
	quake = maxf(quake,0.45)
	chase_beat.emit("caught "+how)


# --- The periscope ----------------------------------------------------
# Whole, hunting, with `periscope` on: his sight broken behind cover, he
# plants, lifts his own head off his shoulders and holds it up overhead in
# both hands (the clips scope_lift, scope_look, scope_lower), turns it slowly
# about where he lost you, and holds; his sight is cast from it up there, so
# low cover no longer hides you (tall cover and an overhang still do). Seen,
# his head draws you in from up there (the worn suck); not, he lowers it,
# puts it back and searches on. He doesn't walk while it is up.

## The clips' beats (the build's SCOPE_TAKE, SCOPE_SEAT): the head leaves the
## stump at this share of the lift, is seated at this share of the lower.
const SCOPE_TAKE := 0.42/1.7
const SCOPE_SEAT := 0.92/1.6
## The wrists over the held head's chin (model m), its palm off its side.
const SCOPE_GRIP := 0.3
const SCOPE_PALM := 0.28
## The most the trunk twists toward where it looks (rad), and how much more
## the head turns in his hands.
const SCOPE_TWIST := 0.9
const SCOPE_HEAD_TURN := 0.3
var scopes := 0
var scope_finds := 0
## Its beat up there: "lift", "look", "draw", "suck", "gulp", "lower".
var scope_phase := ""
var _scope_t := 0.0
var _scope_ready := 0.0
## Scoped since it last saw him (once a loss).
var _scoped := false
var _scope_then := ""
var _scope_found := false
var _scope_saw := 0.0
## Where it searches about (world yaw), where it looks now, the trunk's
## twist toward it, the lean out over what is in front.
var _scope_base := 0.0
var _look_yaw := 0.0
var _twist := 0.0
var _peer := 0.0
var _peer_cap := INF
## The held head's chin (global) and its yaw; how much it is held (0 on the
## stump, 1 in his hands) and how much the hands are on it.
var _held_at := Vector3.ZERO
var _held_yaw := 0.0
var _held_w := 0.0
var _grip_w := 0.0
var _head_box := BoxShape3D.new()
var _head_q := PhysicsShapeQueryParameters3D.new()
var head_bumps := 0
## Stepping up to low cover first: it stands its front this far off the
## face (m), steps at most this far (m) and this long (s).
const SCOPE_STANDOFF := 0.45
const SCOPE_STEP_MOST := 5.0
const SCOPE_STEP_FOR := 3.0
var _scope_face := INF

func _scopes() -> bool:
	return _chases() and float(knobs.periscope) >= 0.5 and head != null and is_instance_valid(head) and head.perch == self

## Lost him: up goes the head, if it may (once a loss, rested).
func _scope_try(then: String) -> bool:
	if not _scopes() or _scoped or _clock < _scope_ready or field.motor.seized(): return false
	scopes += 1
	_scoped = true
	_scope_then = then
	_scope_found = false
	_scope_saw = 0.0
	vel.x = 0.0
	vel.z = 0.0
	var to := Vector2(seen_at.x-position.x,seen_at.z-position.z) if seen_at != Vector3.INF else Vector2.ZERO
	_scope_base = PilotMotor.facing_of(to.normalized()) if to.length() > 0.5 else facing
	_look_yaw = _scope_base
	_twist = 0.0
	_peer = 0.0
	_peer_cap = INF
	_go("scope")
	# Low cover a little way ahead (under its head held up): it steps up to
	# it first, so the head goes up over it.
	# The nearest low cover about the way it lost him: it squares up to it.
	var best := {}
	for a: float in [0.0,0.4,-0.4,0.8,-0.8]:
		var hit := _cover_hit(_way3(wrapf(_scope_base+a,-PI,PI)))
		if not hit.is_empty() and (best.is_empty() or float(hit.d) < float(best.d)): best = hit
	_scope_face = INF
	if not best.is_empty():
		var n: Vector3 = best.n
		_scope_base = PilotMotor.facing_of(Vector2(-n.x,-n.z).normalized())
		_look_yaw = _scope_base
		_scope_face = _cover_ahead(_way3(_scope_base))
	if (_scope_face != INF and _scope_face > length*0.5+SCOPE_STANDOFF+0.3) or absf(angle_difference(facing,_scope_base)) > 0.3 \
			or Vector2(vel.x,vel.z).length() > 0.4: _scope_go("step")
	else:
		_scope_go("lift")
		field.sound(&"body_windup",position)
	chase_beat.emit("scope")
	return true

## Low cover along `dir` within reach: how far its face is from its middle
## (m), INF none (or none it could see over held up).
func _cover_ahead(dir: Vector3) -> float:
	var hit := _cover_hit(dir)
	return INF if hit.is_empty() else float(hit.d)

## The same: {d, n (the face's normal, flat)}, {} none.
func _cover_hit(dir: Vector3) -> Dictionary:
	var reach := length*0.5+SCOPE_STEP_MOST
	var from := position+Vector3.UP*(float(knobs.step)*STAIR+0.4)
	var low := _cast(from,from+dir*reach)
	if low.is_empty() or absf((low.normal as Vector3).y) > 0.5: return {}
	var d := ((low.position as Vector3)-position).dot(dir)
	# Over the top of it, at the height of its eyes held up: clear, it's low.
	var high := position+Vector3.UP*(neck_h+hh*0.75)
	if not _cast(high,high+dir*(d+1.0)).is_empty(): return {}
	var n := low.normal as Vector3
	return {"d":d,"n":Vector3(n.x,0.0,n.z).normalized()}

func _scope_go(phase: String) -> void:
	scope_phase = phase
	_scope_t = 0.0
	_fade = 0.15

## How far into the look's sweep (a share of `scope_sweep` either way): a
## hold, slowly one way, a hold, the other, a hold, back.
static func _sweep(u: float) -> float:
	var keys := [[0.0,0.0],[0.1,0.0],[0.34,1.0],[0.46,1.0],[0.76,-1.0],[0.88,-1.0],[1.0,0.0]]
	for i in range(1,keys.size()):
		if u <= float(keys[i][0]):
			var a: Array = keys[i-1]
			var b: Array = keys[i]
			return lerpf(float(a[1]),float(b[1]),smoothstep(float(a[0]),float(b[0]),u))
	return 0.0

func _scope(delta: float) -> void:
	_scope_t += delta
	if scope_phase != "step": _brake(delta)
	var m: PilotMotor = field.motor
	var to_him := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	match scope_phase:
		"step":
			var dir := _way3(_scope_base)
			var off := angle_difference(facing,_scope_base)
			var turn := float(knobs.turn)*delta
			facing = wrapf(facing+clampf(off,-turn,turn),-PI,PI)
			var left := _cover_ahead(dir)-(length*0.5+SCOPE_STANDOFF)
			if left <= 0.05 or left == INF or _scope_t > SCOPE_STEP_FOR:
				_brake(delta)
				# Squared up to where it will look (its turn's steps done)
				# before the head comes off: no step turns with it up.
				var square := (absf(off) < 0.3 and not look.steps.busy() and look.turn_weight() < 0.05) or _scope_t > SCOPE_STEP_FOR+2.0
				if Vector2(vel.x,vel.z).length() < 0.4 and square:
					vel.x = 0.0
					vel.z = 0.0
					_scope_go("lift")
					field.sound(&"body_windup",position)
				return
			var aligned := clampf(cos(off),0.0,1.0)
			var want := Vector2(dir.x,dir.z)*minf(float(knobs.walk),left*1.5+0.3)*aligned*aligned
			var flat := Vector2(vel.x,vel.z).move_toward(want,float(knobs.accel)*delta)
			vel.x = flat.x
			vel.z = flat.y
			return
		"lift","look":
			var lift_s := float(knobs.scope_lift)
			if scope_phase == "look":
				_look_yaw = wrapf(_scope_base+_sweep(_scope_t/float(knobs.scope_look))*float(knobs.scope_sweep),-PI,PI)
			# Up (or nearly), it looks: seen a moment, he's found.
			var up := scope_phase == "look" or _scope_t > lift_s*0.8
			if up and sight.seeing() and not m.seized(): _scope_saw += delta
			else: _scope_saw = maxf(0.0,_scope_saw-delta*0.5)
			if _scope_saw >= float(knobs.scope_spot):
				scope_finds += 1
				_scope_found = true
				hunting = true
				seen_at = m.feet
				sight.awareness = 1.0
				field.sound(&"head_call",_eye())
				chase_beat.emit("scope saw")
				# In its draw's reach with nothing between (it turns its mouth
				# to him as its jaw opens): it draws him in from up there.
				var chest: Vector3 = head._chest(m)
				if head.has_method("worn_reaches") and (head.worn_reaches(m) or \
						(head.mouth().distance_to(chest) < float(head.knobs.worn_reach)*0.8 and head._clear(head.mouth(),chest))):
					sucks += 1
					_suck_unseen = 0.0
					field.sound(&"head_inhale",head.mouth())
					chase_beat.emit("suck")
					_scope_go("draw")
				else: _scope_go("lower")
				return
			if scope_phase == "lift" and _scope_t >= lift_s: _scope_go("look")
			elif scope_phase == "look" and _scope_t >= float(knobs.scope_look):
				chase_beat.emit("scope none")
				_scope_go("lower")
		"draw","suck","gulp":
			if to_him.length() > 0.1 and scope_phase != "gulp": _look_yaw = PilotMotor.facing_of(to_him.normalized())
			if head.swallowed:
				if scope_phase != "gulp":
					gulps += 1
					_scope_go("gulp")
					chase_beat.emit("gulped")
				return
			if scope_phase == "gulp":
				chase_beat.emit("blown out")
				_suck_ready = _clock+float(knobs.suck_rest)
				_scope_go("lower")
				return
			_suck_unseen = 0.0 if sight.seeing() else _suck_unseen+delta
			if scope_phase == "draw" and _scope_t >= float(knobs.suck_tell): _scope_go("suck")
			elif scope_phase == "suck" and (_scope_t >= float(knobs.suck_for) or _suck_unseen > float(knobs.suck_lose)):
				_suck_ready = _clock+float(knobs.suck_rest)
				_scope_go("lower")
		"lower":
			if _scope_t >= float(knobs.scope_lower):
				_scope_ready = _clock+float(knobs.scope_rest)
				scope_phase = ""
				quake = maxf(quake,0.1)
				if _scope_found or _scope_then == "chase":
					hunting = true
					_go("chase")
				# Not seen from up there: after him, if he went up; else it
				# searches about.
				elif not _after_try(): _seek_start()
		_:
			_go(_resume())

## Its draw from up there, as `worn_draw` asks.
func _scope_draw() -> float:
	match scope_phase:
		"draw": return clampf(_scope_t/float(knobs.suck_tell),0.01,0.99)
		"suck","gulp": return 1.0
	return 0.0

## The share of the clip it is in (0 to 1).
func _scope_u() -> float:
	match scope_phase:
		"lift": return clampf(_scope_t/float(knobs.scope_lift),0.0,1.0)
		"lower": return clampf(_scope_t/float(knobs.scope_lower),0.0,1.0)
	return 1.0

## After the clips: the trunk turned toward where it looks and leaned out
## over what is in front; then the head carried between the wrists.
func _scope_pose(delta: float) -> void:
	var u := _scope_u()
	match scope_phase:
		"step":
			_held_w = 0.0
			_grip_w = 0.0
			return
		"lift":
			_held_w = smoothstep(SCOPE_TAKE-0.03,SCOPE_TAKE+0.02,u)
			_grip_w = smoothstep(0.08,SCOPE_TAKE,u)
		"lower":
			_held_w = 1.0-smoothstep(SCOPE_SEAT-0.04,SCOPE_SEAT+0.01,u)
			_grip_w = 1.0-smoothstep(0.66,0.76,u)
		_:
			_held_w = 1.0
			_grip_w = 1.0
	# The turn: slow and deliberate; the trunk takes what it can.
	var off := angle_difference(facing,_look_yaw)
	var up_k := _held_w if scope_phase != "lower" else 1.0-smoothstep(0.1,0.5,u)
	var want_twist := clampf(off,-SCOPE_TWIST,SCOPE_TWIST)*up_k
	var rate := 1.4 if scope_phase in ["draw","suck","gulp"] else 0.9
	_twist = move_toward(_twist,want_twist,rate*delta)
	# The lean: out over low cover; back, looking up at a ledge over him;
	# never into what is there (the cap, once it bumps).
	var want_peer := 0.0
	if scope_phase in ["look","draw","suck","gulp"]:
		var ledge := seen_at != Vector3.INF and seen_at.y > position.y+neck_h*0.9
		want_peer = -0.12 if ledge else float(knobs.scope_lean)
	want_peer = minf(want_peer,_peer_cap)
	_peer = move_toward(_peer,want_peer,(1.5 if _peer > want_peer else 0.3)*delta)
	look.twist("hips",_twist*0.15)
	look.twist("spine",_twist*0.35)
	look.twist("chest",_twist*0.5)
	look.pitch("spine",_peer*0.55)
	look.pitch("chest",_peer*0.45)
	# The head between the wrists, upright, turned a little past the trunk.
	var mid := (look.wrist("L")+look.wrist("R"))*0.5
	_held_at = mid-Vector3.UP*SCOPE_GRIP*look.k
	_held_yaw = wrapf(facing+_twist*(1.0+SCOPE_HEAD_TURN/SCOPE_TWIST),-PI,PI)
	# Bumped (the held head in a wall or a ledge's face): it leans less.
	if _held_w > 0.9 and head != null and is_instance_valid(head):
		_head_box.size = Vector3(float(head.width),float(head.height),float(head.length))*0.92
		_head_q.shape = _head_box
		_head_q.transform = Transform3D(Basis(Vector3.UP,_held_yaw),_held_at+Vector3.UP*float(head.height)*0.5)
		_head_q.collision_mask = WalkerOnly.strip(field.study.ground.mask)
		_head_q.exclude = _skip()
		var space: PhysicsDirectSpaceState3D = field.study.get_world_3d().direct_space_state
		if not space.intersect_shape(_head_q,1).is_empty():
			head_bumps += 1
			_peer_cap = maxf(-0.25,minf(_peer_cap,_peer-0.1))

## The hands on the head's sides (where it is now), palms flat on it.
func _scope_hands() -> void:
	if _grip_w <= 0.0 or head == null or not is_instance_valid(head): return
	var chin := head_seat()
	var yaw := head_facing()
	var right := Basis(Vector3.UP,yaw)*Vector3.RIGHT
	var off := float(head.width)*0.5+SCOPE_PALM*look.k
	for side in ["L","R"]:
		var s := -1.0 if side == "L" else 1.0
		look.reach(side,chin+Vector3.UP*SCOPE_GRIP*look.k+right*s*off,_grip_w,Vector3.UP,-right*s)

## Where its sight looks (flat): the held head's way, else its own.
func _look_way() -> Vector3:
	if state == "scope" and _held_w > 0.5: return _way3(head_facing())
	return _forward3()

# --- Leap up and grab -------------------------------------------
# Whole, with the chase and `leap_grab` on: where its goal (him, where it
# last saw him, its post going back) is up on a higher place it can't walk
# or climb to, and that place's rim is within `grab_up` Hh over its feet and
# `grab_out` Hh off, it crouches and looks up (`grab_windup` s), leaps,
# catches the rim with its hands (hung from it, swinging), and hauls itself
# up and over as it does climbing (the climb's haul and mantle). A rim it
# can't reach it doesn't try for (`grab_why` says why).

## Its seek's step: the feet's phase a radian turned, and the turn (rad/s)
## that has it fully stepping.
const SEEK_STEP := 0.9
const SEEK_TURN_FULL := 1.2
var _seek_turn := 0.0
## Under him, out of reach, this long (s): it looks about.
const UNDER_GIVE := 3.0
var _under_t := 0.0
## How often it looks for a rim (s).
const GRAB_LOOK := 0.2
## Its goal this much over its feet (× step) before it looks for a rim.
const GRAB_OVER := 2.5
## The rim's search: along its way in steps this long (m); the rim
## narrowed by halving this many times.
const GRAB_STEP := 0.5
const GRAB_FINE := 5

## The grab it is making: {lip (the rim, at its top), inward (flat, unit),
## hang (where it hangs from it), top}; empty none.
var grab := {}
## Where it heads to grab a rim too far off now (INF none).
var _grab_aim := Vector3.INF
var _grab_look := 0.0
var _grab_ready := 0.0
var _grab_from := Vector3.ZERO
## Counted, and why the last rim was not tried, for its study's HUD and checks.
var grabs := 0
var grab_leaps := 0
var grab_refusals := 0
var grab_why := ""

## The grab on: the chase on and `leap_grab` 1.
func _grabs() -> bool:
	return _chases() and float(knobs.leap_grab) >= 0.5

## Where it hangs from a rim (its feet under the lip): its reach, a little
## less, so its hands are over the top.
func _hang_drop() -> float:
	return neck_h+arm_l*0.75-0.3

## Its goal over it and a rim to it in reach: winds up (true).
func _grab_try(delta: float, goal: Vector3) -> bool:
	if not _grabs() or _clock < _grab_ready or goal.y < position.y+float(knobs.step)*GRAB_OVER:
		_grab_aim = Vector3.INF
		return false
	_grab_look -= delta
	if _grab_look > 0.0: return false
	_grab_look = GRAB_LOOK
	_grab_aim = Vector3.INF
	var spot := grab_spot(goal)
	if spot.is_empty(): return false
	var off := Vector2(spot.hang.x-position.x,spot.hang.z-position.z).length()
	if off > float(knobs.grab_out)*hh:
		grab_why = "rim %.1f m off (reach %.1f m): walks to it" % [off,float(knobs.grab_out)*hh]
		_grab_aim = spot.hang
		return false
	grab = spot
	grab_leaps += 1
	vel.x = 0.0
	vel.z = 0.0
	_go("grab_windup")
	field.sound(&"body_windup",position)
	chase_beat.emit("grab")
	return true

## The rim over the way to `goal` it would grab: from where it stands along
## the flat way to it (or, stood under a higher place, back out from under
## it), the first top over its head within `grab_up` Hh, whose face doesn't
## come down to its floor (that it walks to and climbs); {} none (`grab_why`).
func grab_spot(goal: Vector3) -> Dictionary:
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	var way := to.normalized() if to.length() > 0.5 else PilotMotor.forward(facing)
	var dir := Vector3(way.x,0.0,way.y)
	var low := position.y+float(knobs.step)*GRAB_OVER
	var high := position.y+float(knobs.grab_up)*hh
	var reach := float(knobs.grab_out)*hh+length+to.length()
	reach = minf(reach,float(knobs.grab_out)*hh*3.0+length)
	var under := _top_over(position,low,high) != -INF
	# Along its way; stood under a place, out from under it the nearest way
	# of four (its way first: the rim nearest him).
	var search := dir
	var last := 0.0
	var found := -1.0
	var ways := [dir,Vector3(-dir.z,0.0,dir.x),Vector3(dir.z,0.0,-dir.x),-dir] if under else [dir]
	for w: Vector3 in ways:
		var w_last := 0.0
		var d := GRAB_STEP
		while d <= reach and (found < 0.0 or d < found):
			var has := _top_over(position+w*d,low,high) != -INF
			if has != under:
				found = d
				last = w_last
				search = w
				break
			w_last = d
			d += GRAB_STEP
	if found < 0.0:
		var any := _top_over(position+dir*minf(to.length(),reach),low,high+30.0)
		grab_why = ("no rim in reach" if any == -INF else "rim %.1f m up (most %.1f m): out of reach" % [any-position.y,high-position.y])
		if any != -INF and any > high: grab_refusals += 1
		return {}
	# Narrowed: `yes` over the place, `no` off it.
	var yes := last if under else found
	var no := found if under else last
	for i in GRAB_FINE:
		var m := (yes+no)*0.5
		if _top_over(position+search*m,low,high) != -INF: yes = m
		else: no = m
	var inward := -search if under else search
	var rim := position+search*yes
	var top := _top_over(rim+inward*0.3,low,high)
	if top == -INF: return {}
	# Room on it for its body.
	var on := _top_over(rim+inward*(length*0.5+1.0),top-0.6,top+0.6)
	if on == -INF:
		grab_why = "no room on the rim"
		return {}
	# Its face down to the floor here: that it walks to and climbs.
	var knee := position+Vector3.UP*(float(knobs.step)+0.1)
	var face := _cast(knee,Vector3(rim.x,knee.y,rim.z)+inward*0.5)
	if not face.is_empty() and absf((face.normal as Vector3).y) < 0.5:
		grab_why = "its face comes down to the floor: it climbs"
		return {}
	var lip := Vector3(rim.x,top,rim.z)
	var hang := lip-inward*(length*0.5+float(knobs.standoff))-Vector3.UP*_hang_drop()
	grab_why = "rim %.1f m up, %.1f m off" % [top-position.y,Vector2(hang.x-position.x,hang.z-position.z).length()]
	return {"lip":lip,"inward":inward,"hang":hang,"top":top}

## The top of a place over `p` (looked for from over `high` down to `low`),
## -INF none (a place's underside met first is none).
func _top_over(p: Vector3, low: float, high: float) -> float:
	var hit := _cast(Vector3(p.x,high+0.5,p.z),Vector3(p.x,low,p.z))
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7: return -INF
	var y := (hit.position as Vector3).y
	return y if y >= low and y <= high+0.01 else -INF

## Crouched, looking up at the rim, turned to it; then the leap.
func _grab_windup(delta: float) -> void:
	_brake(delta)
	var inward: Vector3 = grab.inward
	facing = lerp_angle(facing,PilotMotor.facing_of(Vector2(inward.x,inward.z)),1.0-exp(-6.0*delta))
	if state_t < float(knobs.grab_windup): return
	# The throw: its feet up to the hang point at the top of the arc.
	var hang: Vector3 = grab.hang
	var g := float(knobs.leap_gravity)
	var up := maxf(hang.y-position.y,0.5)
	var vy := sqrt(2.0*g*up)
	_flight = vy/g
	vel = Vector3((hang.x-position.x)/_flight,vy,(hang.z-position.z)/_flight)
	_grab_from = position
	grounded = false
	leaps += 1
	_go("grab_leap")
	field.sound(&"body_leap",position)
	_puff(position,hh*1.6)
	_shock(position,0.5)

## In the air up to the rim; at the arc's top, its hands on the lip if it is
## there (within `grab_tol`), else it falls.
func _grab_leap(delta: float) -> void:
	vel.y -= float(knobs.leap_gravity)*delta
	position += vel*delta
	var inward: Vector3 = grab.inward
	facing = lerp_angle(facing,PilotMotor.facing_of(Vector2(inward.x,inward.z)),1.0-exp(-8.0*delta))
	if vel.y > 0.0 and state_t < _flight+0.5: return
	var hang: Vector3 = grab.hang
	var lip: Vector3 = grab.lip
	var reach_to := position+Vector3.UP*_hang_drop()+inward*(length*0.5+float(knobs.standoff))
	var top := _top_over(lip+inward*0.3,lip.y-float(knobs.grab_tol),lip.y+float(knobs.grab_tol))
	if top == -INF or reach_to.distance_to(lip) > float(knobs.grab_tol)+0.5:
		grab_why = "missed the lip"
		grab = {}
		_grab_ready = _clock+float(knobs.grab_rest)
		_fall()
		return
	position = hang
	vel = Vector3.ZERO
	grabs += 1
	_lip_y = top
	_face_pt = Vector3(lip.x,lip.y-neck_h*0.3,lip.z)
	_haul_t = 0.0
	_grab_t = -1.0
	quake = maxf(quake,0.25)
	field.sound(&"body_grip",lip)
	field.sound(&"body_rumble",lip)
	_puff(lip,hh*0.8)
	Dust.rocks(field,lip-inward*0.4,-inward,6,hh*0.12)
	_go("hang")

## Hung from the lip: a swing out and back that dies, then the haul.
func _hang_grab(delta: float) -> void:
	var inward: Vector3 = grab.inward
	var hang: Vector3 = grab.hang
	_haul_t += delta
	var swing := sin(state_t*TAU*0.9)*exp(-2.6*state_t)*hh*0.35
	position = hang-inward*swing
	if state_t < float(knobs.grab_hang): return
	position = hang
	_climb_from = position.y
	_lip_y = INF
	climbs += 1
	_grab_ready = _clock+float(knobs.grab_rest)
	grab = {}
	_go("climb")

## Crouched for the grab it leans back, looking up at the rim; back upright
## once it goes.
func _lean_up(delta: float) -> void:
	var want := 0.0
	if state == "grab_windup": want = float(knobs.grab_lean)*smoothstep(0.0,0.6,state_t/float(knobs.grab_windup))
	elif state == "grab_leap": want = -float(knobs.grab_lean)*0.5
	look.rotation.x = lerpf(look.rotation.x,want,1.0-exp(-8.0*delta))

# --- Reunion -----------------------------------------------------------------------------------

func _reach_head(delta: float) -> void:
	_brake(delta)
	var to := Vector2(_seat_from.x-position.x,_seat_from.z-position.z)
	if to.length() > 0.2: facing = lerp_angle(facing,PilotMotor.facing_of(to.normalized()),1.0-exp(-3.0*delta))
	_seat_k = minf(1.0,state_t/float(knobs.settle))
	if _seat_k >= 1.0:
		whole = true
		homed = false
		rest()
		_puff(look.seat().origin,hh*1.2)
		quake = 0.3
		field.sound(&"body_whole",position)
		reunited.emit(self)
		_triumph_thud = false
		_go("triumph")

## Whole: arms up, then the fists down with a thud (at the clip's 1.34 of
## its 1.8 s), then on.
func _triumph(delta: float) -> void:
	_brake(delta)
	var t := float(knobs.triumph)
	if not _triumph_thud and state_t >= t*1.34/1.8:
		_triumph_thud = true
		quake = maxf(quake,0.25)
		field.sound(&"body_step",position)
	if state_t >= t:
		# Olmec threat round 1: whole, he knows where you are.
		if _relentless() and _chases():
			_wake_hunt()
			return
		_go("listen")

## Relentless: whole, with the hunt on.
func _relentless() -> bool:
	return float(knobs.get("relentless",0)) >= 0.5 and _chases()

## The hunt woken (the head on, or brought up a cliff after you by the
## layer's Olmec, scripts/roguelike/layer_olmec.gd): spotted, at you.
func _wake_hunt() -> void:
	if sight == null:
		sight = Sight.new()
		sight.tune(knobs)
	sight.awareness = 1.0
	sight.state = "spotted"
	var was := hunting
	hunting = true
	_scent()
	if not was:
		spots += 1
		chase_beat.emit("spotted")
	tell(mark_colour)

## Lost you: he takes your scent (where you are now) and comes on.
func _scent() -> void:
	var m: PilotMotor = field.motor
	seen_at = m.feet
	seen_t = 0.0
	_after_n = 0
	_after_k = 0
	_after_at = Vector3.INF
	_route = []
	_leg = 0
	_search = null
	_skirt_t = 0.0
	scents += 1
	chase_beat.emit("scent")
	_go("chase")

# --- Moving -------------------------------------------------------------------------------------

func _move(delta: float) -> void:
	_unwedge(delta)
	if state in ["leap","fall"]:
		# Olmec round 1: glanced off what its bulk is in (set off by a wall).
		_clear_bulk(delta,false)
		vel.y -= float(knobs.leap_gravity)*delta
		var to := position+vel*delta
		var hit := _cast(position+Vector3.UP*0.05,to)
		# Olmec round 1: its bulk swept too (its chest, its arms): a wall it
		# would fly into stops it dead and it drops, as a wall at its feet does.
		var bulk := _bulk_sweep(position,to) if state == "leap" and leap_kind != "drop" else 1.0
		if bulk < 1.0 and (hit.is_empty() or bulk < position.distance_to(hit.position)/maxf(position.distance_to(to),0.0001)):
			position = position.lerp(to,bulk)
			vel.x = 0.0
			vel.z = 0.0
			bulk_stops += 1
			if state == "leap": _go("fall")
		elif not hit.is_empty():
			var n := hit.normal as Vector3
			if n.y > 0.5 and vel.y <= 0.0:
				position = hit.position
				_landed()
			else:
				# A wall on the way: it stops dead against it and drops.
				position = (hit.position as Vector3)+Vector3(n.x,0.0,n.z)*0.1-Vector3.UP*0.05
				vel.x = 0.0
				vel.z = 0.0
				if state == "leap": _go("fall")
		else: position = to
		if position.y < field.lost:
			gone = true
			field.gone_count += 1
			fell.emit(self)
			queue_free()
	elif state not in ["climb","mantle","grab_leap","hang"]:
		position.x += vel.x*delta
		position.z += vel.z*delta
		if state not in BULK_FREE: _clear_bulk(delta)
		var g := _feet_floor(float(knobs.step)*STAIR,float(knobs.step))
		if g == -INF: _fall()
		else: position.y = move_toward(position.y,g,maxf(absf(g-position.y)*8.0,2.0)*delta) if g > position.y else g
		# A step each phase (the clips' feet come down on whole phases).
		var was := _phase
		_phase += Vector2(vel.x,vel.z).length()*delta/(hh*float(knobs.stride_home if state in ["home","chase"] else knobs.stride))
		if floori(was) != floori(_phase):
			field.sound(&"body_step",position)
			quake = maxf(quake,0.06)
	rotation.y = facing
	if breaker != null: breaker.met(self)

## Plowed through something (`k` 0 to 1, how much): slowed for a beat and a
## jolt, never stopped dead.
func stagger(k: float) -> void:
	# Round 2: barely slowed (a hit should feel like nothing to him).
	_stagger = maxf(_stagger,STAGGER*clampf(k,0.0,1.0))
	vel.x *= 1.0-0.1*k
	vel.z *= 1.0-0.1*k
	quake = maxf(quake,0.25+0.25*k)

## The world changed in `box` (rubble come to rest): its columns read
## afresh, and the route it is on planned again from here.
func world_changed(box: AABB) -> void:
	if routes != null: routes.forget(box)
	if _goal != Vector3.INF and (_routed() or _search != null): _start_search(_goal,_goal_reach)

# --- Olmec round 1: its bulk against the world -------------------

## Its bulk, a box turned with it (in head heights at its size): half across
## its shoulders and hanging arms, half along it; from over a stair's step
## (what it walks up is not in it) to the top of its stump (whole, its head).
const BULK_W := 1.0
const BULK_L := 0.5
## Its legs' box (head heights, half across its feet, half along them),
## and the height (m) of a block beside them it is eased off.
const LEG_W := 0.58
const LEG_L := 0.45
const LEG_BLOCK := 0.9
## How far (head heights) a landing may be off its room by a wall.
const ROOM_GIVE := 0.9
## Two bodies kept this share of their breadths apart (middle to middle).
const BODY_GAP := 1.15
## Eased out of what it is in, at most this fast (m/s).
const BULK_EASE := 8.0
## Its arms swing out ahead of its bulk walking (head heights): the
## shoulder rays look this much further.
const SHOULDER_AHEAD := 0.25
## States whose own code keeps it off the world (on a wall, over a lip, in
## the air; the feel eases it off the face itself).
const BULK_FREE := ["climb","mantle","grab_leap","hang","feel"]
var _bulk := BoxShape3D.new()
var _bulk_q := PhysicsShapeQueryParameters3D.new()
## Counted, for checks: frames it was eased out, flights stopped by a wall.
var bulk_pushes := 0
var bulk_stops := 0
var _pushed_at := -INF

func _bulk_top() -> float:
	return neck_h+(hh*0.8 if whole else 0.0)

func _bulk_at(p: Vector3, motion := Vector3.ZERO) -> PhysicsShapeQueryParameters3D:
	var low := float(knobs.step)*STAIR+0.15
	var top := _bulk_top()
	_bulk.size = Vector3(hh*BULK_W*2.0,top-low,hh*BULK_L*2.0)
	_bulk_q.shape = _bulk
	_bulk_q.transform = Transform3D(Basis(Vector3.UP,facing),p+Vector3.UP*(low+top)*0.5)
	_bulk_q.collision_mask = WalkerOnly.strip(field.study.ground.mask)
	var skip := _skip()
	# The Olmec's destruction: rubble is waded through, not shoved off.
	if breaker != null: skip.append_array(breaker.rubble_rids())
	_bulk_q.exclude = skip
	_bulk_q.motion = motion
	_bulk_q.margin = 0.02
	return _bulk_q

## Room for its bulk stood at `p` (any way it faces: its bulk's breadth
## round), a little give for the push-out.
func _room_at(p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = field.study.get_world_3d().direct_space_state
	var w := hh*BULK_W*2.0*0.85
	var out := Vector3.ZERO
	# By a wall is room (the push-out eases it off a little); a shaft or a
	# slot it doesn't fit, pushed both ways, isn't.
	for i in 4:
		var q := _bulk_at(p+out)
		_bulk.size = Vector3(w,_bulk.size.y,w)
		var pts: Array[Vector3] = space.collide_shape(q,8)
		if pts.is_empty(): return out.length() <= hh*ROOM_GIVE
		var best := Vector3.ZERO
		for j in range(0,pts.size()-1,2):
			var d: Vector3 = pts[j+1]-pts[j]
			d.y = 0.0
			if d.length() > best.length(): best = d
		if best.length() < 0.01: return false
		out += best+best.normalized()*0.05
	return false

## The crouch's arms swept back past its bulk (head heights, along it).
const WINDUP_ROOM := 0.6

## Room for a pose here turned to `face`: its bulk `more_l` head heights
## longer each way meets nothing (a wind-up's arms swung back by a wall).
func _room_for(face: float, more_l: float) -> bool:
	var was := facing
	facing = face
	var q := _bulk_at(position)
	_bulk.size.z += 2.0*more_l*hh
	var space: PhysicsDirectSpaceState3D = field.study.get_world_3d().direct_space_state
	var clear := space.collide_shape(q,1).is_empty()
	facing = was
	return clear

## How far (0 to 1) its bulk goes from `a` to `b` before it meets the world
## (1 clear; 1 too if it starts in something: that is for the push-out).
func _bulk_sweep(a: Vector3, b: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = field.study.get_world_3d().direct_space_state
	if not space.collide_shape(_bulk_at(a),1).is_empty(): return 1.0
	var r: PackedFloat32Array = space.cast_motion(_bulk_at(a,b-a))
	return r[0] if r.size() > 0 else 1.0

## Eased (flat) out of the world its bulk is in: a wall it walked along, a
## pillar's corner its shoulder met, an underside it walked under, the turn
## that swung its arms into a wall. Never off its floor.
func _clear_bulk(delta: float, floored := true) -> void:
	var space: PhysicsDirectSpaceState3D = field.study.get_world_3d().direct_space_state
	var out := Vector3.ZERO
	for i in 4:
		var pts: Array[Vector3] = space.collide_shape(_bulk_at(position+out),8)
		if pts.is_empty(): break
		var best := Vector3.ZERO
		for j in range(0,pts.size()-1,2):
			var d: Vector3 = pts[j+1]-pts[j]
			d.y = 0.0
			if d.length() > best.length(): best = d
		if best.length() < 0.01: break
		out += best+best.normalized()*0.02
	# Its legs: a block it walks beside (taller than LEG_BLOCK, under its
	# bulk's bottom) eases it off sideways only (one met head on is a
	# stair's step it walks up, or a wall its rays meet).
	if floored:
		var right := _right3()
		var q := _bulk_at(position+out)
		var low := 0.35
		var top := float(knobs.step)*STAIR+0.15
		_bulk.size = Vector3(hh*LEG_W*2.0,top-low,hh*LEG_L*2.0)
		q.transform.origin = position+out+Vector3.UP*(low+top)*0.5
		var pts: Array[Vector3] = space.collide_shape(q,8)
		var side := 0.0
		for j in range(0,pts.size()-1,2):
			var b: Vector3 = pts[j+1]
			var a: Vector3 = pts[j]
			var top_y := _floor(Vector3(b.x,position.y,b.z)+(a-b).normalized()*-0.1,float(knobs.step)*STAIR+1.0,0.5)
			if top_y != -INF and top_y < position.y+LEG_BLOCK: continue
			var d := (b-a).dot(right)
			if absf(d) > absf(side): side = d
		if absf(side) > 0.01: out += right*side
	# Other bodies: eased apart (each its half), flat.
	for e in field.enemies:
		if e == self or not is_instance_valid(e) or not e.has_method("make_whole") or e.get("gone"): continue
		var d := Vector3(position.x-e.position.x,0.0,position.z-e.position.z)
		var most := (width+float(e.width))*0.5*BODY_GAP
		if d.length() < most and absf(position.y-e.position.y) < neck_h:
			out += (d.normalized() if d.length() > 0.01 else _right3())*(most-d.length())*0.5
	if out == Vector3.ZERO: return
	out = out.limit_length(BULK_EASE*delta)
	var at := position+out
	if floored and _floor(at,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: return
	position = at
	bulk_pushes += 1
	_pushed_at = _clock
	# Its planted feet go with it (they would slide otherwise).
	if look != null: look.steps.carry(out)

## Its hands drawn in off a wall beside them (Olmec round 1): each arm's
## line from the shoulder out to the elbow, the wrist and the fingertips is
## ray-cast; past a wall's face, the wrist is pulled back in along its normal
## by the overlap and TUCK_CLEAR (the forearm's thickness), eased in and out.
const TUCK_CLEAR := 0.75
const TUCK_EASE := 0.15
const TUCK_IN := 0.05
var _tuck_w := {"L":0.0,"R":0.0}
var _tuck_by := {"L":Vector3.ZERO,"R":Vector3.ZERO}
## Frames a hand was drawn in (for checks).
var tucks := 0

func _tuck(delta: float) -> void:
	var k := look.k
	for side: String in ["L","R"]:
		var sh := look.shoulder(side)
		var by := Vector3.ZERO
		var el := look.elbow(side)
		var wr := look.wrist(side)
		for p: Vector3 in [el,el.lerp(wr,0.5),wr,look.fingertip(side),look.thumbtip(side)]:
			var out := p-sh
			var hit := _cast(sh,p+out.normalized()*TUCK_CLEAR*k)
			# The arm's line clear: its thickness, out from it (away from his
			# middle), may still graze a face.
			if hit.is_empty():
				var away := Vector3(p.x-position.x,0.0,p.z-position.z)
				if away.length() < 0.01: continue
				hit = _cast(p,p+away.normalized()*TUCK_CLEAR*k)
				if hit.is_empty(): continue
			var n := hit.normal as Vector3
			if n.y > 0.5: continue
			n = Vector3(n.x,0.0,n.z).normalized() if absf(n.y) < 0.95 else -Vector3(out.x,0.0,out.z).normalized()
			var past := ((hit.position as Vector3)-p).dot(n)+TUCK_CLEAR*k
			if past > by.length(): by = n*past
		var want := 1.0 if by != Vector3.ZERO else 0.0
		if by != Vector3.ZERO:
			if float(_tuck_w[side]) > 0.0: _tuck_by[side] = (_tuck_by[side] as Vector3).lerp(by,1.0-exp(-3.0*delta/TUCK_EASE))
			else: _tuck_by[side] = by
		_tuck_w[side] = move_toward(float(_tuck_w[side]),want,delta/(TUCK_IN if want > 0.0 else TUCK_EASE))
		var w: float = _tuck_w[side]
		if w <= 0.0: continue
		tucks += 1
		look.reach(side,look.wrist(side)+(_tuck_by[side] as Vector3)*w,1.0)

# --- The clips ------------------------------------------------------------------------------

## The cross-fade into each state (s); others take FADE.
const FADE := 0.22
const FADES := {"scope":0.12,"land":0.05,"leap":0.08,"fall":0.15,"mantle":0.12,"windup":0.1,"triumph":0.08,"reach":0.3,"swat":0.08,"smash":0.06,"plant":0.15,
	"grab_windup":0.12,"grab_leap":0.06,"hang":0.05}
## The slap of the hands onto a lip: up and over (s), then down on it.
const GRAB := 0.32

## Posed every frame within ANIM_FAR[0] m of the camera; past each
## [m, s] in ANIM_FAR, no oftener than every s.
const ANIM_FAR := [[90.0,1.0/30.0],[180.0,1.0/20.0]]
var _pose_debt := 0.0
## Frames posed (for checks).
var poses := 0

## How often it is posed at its distance from the camera now (s; 0 every
## frame).
func _pose_every() -> float:
	var camera: Camera3D = field.study.get("camera") if field != null and field.study != null else null
	if camera == null: return 0.0
	var d := camera.global_position.distance_to(global_position)
	var every := 0.0
	for a: Array in ANIM_FAR:
		if d > float(a[0]): every = float(a[1])
	return every

## The clips its state wants, at the places its own clocks say (the walk's
## and the climb's phase, its state's time over that state's knob), then
## the corrections on top: hands on the real wall and lip.
func _animate(delta: float) -> void:
	if look == null: return
	# Far off, posed less often (ANIM_FAR): the clips' blend and the hands'
	# IK are the body's main cost on the CPU.
	if not _snap:
		var every := _pose_every()
		if every > 0.0:
			_pose_debt += delta
			if _pose_debt < every: return
			delta = _pose_debt
		_pose_debt = 0.0
	if state != _was:
		_was = state
		_fade = float(FADES.get(state,FADE))
	var idle := fposmod(_clock,float(look.lengths.idle))
	match state:
		"listen":
			if whole: look.want("idle",idle)
			# Past its listen (still planning its way), it breathes.
			elif state_t > float(knobs.listen): look.want("idle",idle)
			else: look.want("listen",state_t/float(knobs.listen)*float(look.lengths.listen))
		"feel": look.want("feel",_feel_k()*float(look.lengths.feel))
		"roam","home","chase","return":
			var gait := "stride" if state in ["home","chase"] else "walk"
			var pace := float(knobs.home) if state == "home" else (float(knobs.chase_speed) if state == "chase" else float(knobs.walk))
			var m := clampf(Vector2(vel.x,vel.z).length()/maxf(pace*0.5,0.1),0.0,1.0)
			look.want(gait,look.loop_time(gait,_phase,2.0),m)
			look.want("idle",idle,1.0-m)
		"climb","hang":
			if _springs() and (_hang or state == "hang"): look.want("mantle_pull",0.0)
			elif not _hauling(): look.want("climb",look.loop_time("climb",_phase,2.0))
			else:
				var clip := "spawn_haul" if spawned_on_cliff else "haul"
				look.want(clip,fposmod(_haul_t,float(look.lengths[clip])))
		"mantle":
			var clip := "mantle_pull" if _pull else "mantle"
			look.want(clip,state_t/float(knobs.mantle)*float(look.lengths[clip]))
		"windup": look.want("windup",state_t/_windup_s()*float(look.lengths.windup))
		"grab_windup": look.want("windup",clampf(state_t/float(knobs.grab_windup),0.0,1.0)*float(look.lengths.windup))
		"grab_leap": look.want("jump_air",clampf(state_t/maxf(_flight,0.1),0.0,1.0)*float(look.lengths.jump_air)*0.5)
		"leap":
			var clip := "drop_air" if leap_kind == "drop" else "jump_air"
			look.want(clip,state_t/maxf(_flight,0.1)*float(look.lengths[clip]))
		"fall": look.want("drop_air",minf(state_t+0.3,float(look.lengths.drop_air)*0.9))
		"land": look.want(_land_clip,state_t/float(knobs.land)*float(look.lengths[_land_clip]))
		"reach": look.want("reach",state_t/float(knobs.settle)*float(look.lengths.reach))
		"triumph": look.want("triumph",state_t/float(knobs.triumph)*float(look.lengths.triumph))
		# The chase's (placeholders on the clips there are: whole-body-chase-
		# round1.md lists the clips to author).
		"seek":
			# A look-about with its head on: stepping round as it turns (the
			# walk at the turn's share), else stood (never the listen clip).
			# Olmec round 1: its feet step it round (headless_body_steps.gd).
			look.want("idle",idle)
		"plant": look.want("windup",clampf(state_t/float(knobs.suck_tell),0.0,1.0)*float(look.lengths.windup)*BRACE)
		"suck","gulp": look.want("windup",float(look.lengths.windup)*BRACE)
		"scope":
			match scope_phase:
				"step":
					var mv := clampf(Vector2(vel.x,vel.z).length()/maxf(float(knobs.walk)*0.5,0.1),0.0,1.0)
					look.want("walk",look.loop_time("walk",_phase,2.0),mv)
					look.want("idle",idle,1.0-mv)
				"lift": look.want("scope_lift",_scope_u()*float(look.lengths.scope_lift))
				"lower": look.want("scope_lower",_scope_u()*float(look.lengths.scope_lower))
				_: look.want("scope_look",fposmod(_clock,float(look.lengths.scope_look)))
		"smash":
			# The triumph's arms up, then its fists down at the hit (the swat's).
			var whole_t := float(look.lengths.triumph)
			var at := TRIUMPH_HIT*whole_t
			var t := state_t/SMASH_WINDUP*at if state_t < SMASH_WINDUP else at+(state_t-SMASH_WINDUP)/SMASH_AFTER*(whole_t-at)*0.5
			look.want("triumph",t)
		"swat":
			# The triumph's arms up, then its fists down at the hit.
			var whole_t := float(look.lengths.triumph)
			var at := TRIUMPH_HIT*whole_t
			var t := state_t/float(knobs.swat_windup)*at if state_t < float(knobs.swat_windup) else at+(state_t-float(knobs.swat_windup))/float(knobs.swat_after)*(whole_t-at)
			look.want("triumph",t)
		_: look.want("idle",idle)
	# Round 4: turns stepped and feet planted (headless_body_steps.gd).
	var mode := _steps_mode()
	if not look.steps.floor_at.is_valid(): look.steps.floor_at = func(p: Vector3) -> float: return _floor(p,float(knobs.step)*STAIR,float(knobs.step))
	look.steps.pace = TURN_PACE_HUNT if hunting else 1.0
	look.turn(facing,mode,delta,fposmod(_phase/2.0,1.0),state == "home",_turn_goal() if mode == Look.Steps.STAND else NAN)
	# Olmec round 1: stood, it faces where its feet have turned it (its
	# sight, its box, its way on), not ahead of them; the feel squares up
	# its own way.
	if mode == Look.Steps.STAND and state != "feel":
		facing = look.steps.yaw
		rotation.y = facing
		look.model.rotation.y = 0.0
	if _grabs(): _lean_up(delta)
	poses += 1
	look.advance(delta,0.0 if _snap else _fade)
	_snap = false
	if state == "scope": _scope_pose(delta)
	else: _held_w = 0.0
	look.plant_feet(delta)
	_hands(delta)

## Its stood turns' steps, hunting: quicker (Olmec round 1).
const TURN_PACE_HUNT := 1.3

## Where a stood turn is going (rad): its way on, where it glimpsed him;
## else its facing as its state sets it.
func _turn_goal() -> float:
	match state:
		"chase","return","roam","home": return _heading
		"listen": return _heading if _picked else facing
		"scope":
			# Squaring up first; with the head off, its trunk turns, not its feet
			# (a turn step would swing its arms off the head).
			if scope_phase == "step": return _scope_base
			return facing
		"alert":
			if seen_at != Vector3.INF:
				var to := Vector2(seen_at.x-position.x,seen_at.z-position.z)
				if to.length() > 0.1: return PilotMotor.facing_of(to.normalized())
	return facing

## How its turns and feet go: stepping round where it stands, walking, or
## the clips' own (climbing, leaping, landing).
func _steps_mode() -> int:
	match state:
		"listen","reach","triumph","feel","alert": return Look.Steps.STAND
		"scope": return Look.Steps.WALK if scope_phase == "step" and Vector2(vel.x,vel.z).length() > 0.15 else Look.Steps.STAND
		"roam","home","chase","return","seek": return Look.Steps.WALK if Vector2(vel.x,vel.z).length() > 0.15 else Look.Steps.STAND
	return Look.Steps.OFF

## Its right (global, flat).
func _right3() -> Vector3:
	var f := _forward3()
	return Vector3(-f.z,0.0,f.x)

## The hands onto the world: climbing, each hand moved in or out to the
## real face (the clip has a flat wall `standoff` off its front); hauling,
## both on the lip (slapped down onto it once they can reach it); early in
## the mantle, pressing on it.
func _hands(delta: float) -> void:
	var fwd := _forward3()
	var right := _right3()
	var k := look.k
	if state not in BULK_FREE and state != "scope": _tuck(delta)
	match state:
		"scope": _scope_hands()
		"climb","hang":
			if not _hauling():
				var face := position+fwd*(length*0.5+float(knobs.standoff))
				for side in ["L","R"]:
					var w := look.wrist(side)
					var hit := _cast(w-fwd*1.6*k,w+fwd*2.2*k)
					if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.7: continue
					look.reach(side,w+fwd*((hit.position as Vector3)-face).dot(fwd),1.0)
				return
			var lip := Vector3(_face_pt.x,_lip_y,_face_pt.z)
			var reach := look.arm_reach()
			var lift := 0.0
			if _grab_t < 0.0 and _springs(): _grab_t = 0.0
			if _grab_t < 0.0:
				var near := look.shoulder("L").distance_to(lip+Vector3.UP*0.42*k-right*1.5*k)
				if near <= reach*1.02: _grab_t = 0.0
			if _grab_t >= 0.0:
				var was := _grab_t
				_grab_t += delta
				# Up over the lip, a beat, then slammed down on it.
				lift = 1.3*k*smoothstep(0.0,0.12,_grab_t)*(1.0-smoothstep(0.2,GRAB,_grab_t))
				if was < GRAB and _grab_t >= GRAB:
					field.sound(&"body_grip",lip)
					field.sound(&"body_rumble",lip)
					quake = maxf(quake,0.12)
					for s in [-1.0,1.0]: _puff(lip+right*s*1.5*k+fwd*0.4*k,hh*0.45)
					# Its hands slam onto the lip: a cloud off the top, the
					# rim's stones knocked off down the face.
					var tk := _tell_k()
					Dust.plume(field,lip,hh*2.2*tk)
					Dust.rocks(field,lip-fwd*0.6,-fwd,10,hh*0.14*tk)
			# Springing, the hands are the slap's at once (the clips' blend from
			# the climb would swing them through the lip's corner).
			var w := smoothstep(0.0,0.05 if _springs() else 0.2,_haul_t)
			for side in ["L","R"]:
				var s := -1.0 if side == "L" else 1.0
				var at := lip+fwd*0.35*k+right*s*1.5*k+Vector3.UP*(0.42*k+lift)
				# Springing, hung as the pull-up starts (the mantle's hands).
				if _springs():
					at = lip-fwd*0.65*k+right*s*1.7*k+Vector3.UP*(0.5*k+lift)
					# The hand turns over (fingers up the face to over the top)
					# only once it is up past the lip: it never sweeps into it.
					var over := smoothstep(0.06,0.16,maxf(_grab_t,0.0))
					look.reach(side,at,w,Vector3.UP.slerp(fwd,over).normalized(),fwd.slerp(Vector3.DOWN,over).normalized())
					continue
				look.reach(side,at,w,fwd,Vector3.DOWN)
		"feel":
			# The palm flat on the real face, where the clip's wrist is.
			# The face where the wrist and where the fingertips are (an
			# uneven or leaning face): the palm on the nearer, the wrist the
			# hand's thickness off it along its normal.
			var wr := look.wrist("R")
			var best := INF
			var n := Vector3.ZERO
			for up: float in [0.0,1.2*k]:
				var p := wr+Vector3.UP*up
				var hit := _cast(p-fwd*2.0*k,p+fwd*3.0*k)
				if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.7: continue
				var d := ((hit.position as Vector3)-p).dot(fwd)
				if d < best:
					best = d
					n = Vector3((hit.normal as Vector3).x,0.0,(hit.normal as Vector3).z).normalized()
			if best == INF: return
			var w := smoothstep(0.1,0.3,_feel_k())*(1.0-smoothstep(0.92,1.0,_feel_k()))
			look.reach("R",wr+fwd*best+n*FEEL_PALM*k,w,Vector3.UP,-n)
		"mantle":
			var kk := clampf(state_t/float(knobs.mantle),0.0,1.0)
			# Round 4: planted through the gather and the press, let go at its top.
			var w := 1.0-(smoothstep(0.38,0.44,kk) if _pull else smoothstep(0.34,0.42,kk))
			for side in ["L","R"]:
				var s := -1.0 if side == "L" else 1.0
				# The wrist just out from the face over the top (the build's
				# LIP_OUT): the forearm up the face, the hand over the edge.
				look.reach(side,_mantle_lip-fwd*0.65*k+right*s*1.7*k+Vector3.UP*0.5*k,w,fwd,Vector3.DOWN)

# --- The world, as it asks ------------------------------------------------------------------------

## Its own body and its head's left out of every ray.
func _skip() -> Array[RID]:
	var out: Array[RID] = [body.get_rid()]
	for e in field.enemies:
		if is_instance_valid(e) and e.get("body") != null: out.append(e.body.get_rid())
	if breaker != null: out.append_array(breaker.standing_rids())
	return out

func _cast(from: Vector3, to: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = WalkerOnly.strip(field.study.ground.mask)
	_ray.exclude = _skip()
	return field.study.get_world_3d().direct_space_state.intersect_ray(_ray)

## The floor under `p`, looked for from `up` over it to `down` under it; -INF none.
## The floor under its feet: under its middle, else under its feet's
## spread (round 11: its feet span a gap its middle is over, stepping
## stones, a crack between two blocks), the highest of them.
func _feet_floor(up: float, down: float) -> float:
	var g := _floor(position,up,down)
	if g != -INF: return g
	var fwd := _forward3()
	var right := _right3()
	for off: Vector3 in [fwd*length*0.35,-fwd*length*0.35,right*width*0.25,-right*width*0.25]:
		g = maxf(g,_floor(position+off,up,down))
	return g

## Round 11: a steep face met on the way down (a rail's rounded top, a
## lamp, a prop's side) is looked past to the floor under it.
func _floor(p: Vector3, up: float, down: float) -> float:
	var from := p+Vector3.UP*up
	var to := p-Vector3.UP*down
	for i in 3:
		var hit := _cast(from,to)
		if hit.is_empty(): return -INF
		if (hit.normal as Vector3).y >= 0.5: return (hit.position as Vector3).y
		from = (hit.position as Vector3)-Vector3.UP*0.05
		if from.y <= to.y: return -INF
	return -INF

# --- Dust (greybox: a ring that spreads and fades) ------------------------------------------------

func _puff(at: Vector3, size: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78,0.72,0.62,0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	field.add_child(ring)
	ring.global_position = at+Vector3.UP*0.2
	ring.scale = Vector3.ONE*size*0.3
	_dust.append([ring,0.0,size])

func _dusts(delta: float) -> void:
	for d: Array in _dust:
		d[1] += delta
		var k := clampf(float(d[1])/0.8,0.0,1.0)
		var ring: MeshInstance3D = d[0]
		ring.scale = Vector3(1.0,0.4,1.0)*float(d[2])*lerpf(0.3,1.0,sqrt(k))
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.7*(1.0-k)
		if k >= 1.0: ring.queue_free()
	_dust = _dust.filter(func(d: Array) -> bool: return float(d[1]) < 0.8)

func _exit_tree() -> void:
	for d: Array in _dust:
		if is_instance_valid(d[0]): d[0].queue_free()
	_dust.clear()
	for w: Dictionary in _waves:
		for p: Node in w.parts+w.chips.map(func(c: Array) -> Node: return c[0]):
			if is_instance_valid(p): p.queue_free()
	_waves.clear()

# --- The walker -------------------------------------------------------------------------------------

## Heavy: he can't push it; walked into while it moves he is shoved.
func touch(m: PilotMotor, _v_pre: Vector3) -> void:
	if gone or _cool > 0.0 or not harmful() or m.seized(): return
	var local := Basis(Vector3.UP,facing).inverse()*(m.feet-position)
	var margin := float(knobs.radius)+0.25
	if absf(local.x) > width*0.5+margin or absf(local.z) > length*0.5+margin: return
	if m.feet.y > position.y+height-0.1 or m.feet.y < position.y-0.6: return
	if m.recovering() and not m.stunnable(self): return
	var way := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	if way.length() < 0.01: way = PilotMotor.forward(facing)
	shove_pilot(m,way.normalized(),float(knobs.shove_out),float(knobs.shove_up))

## On the death card: the Olmec.
func harm_cause() -> String:
	return "olmec"

func harmful() -> bool:
	return state in ["leap","fall","mantle"] or Vector2(vel.x,vel.z).length() > 0.3

func bucks() -> bool:
	return state in ["leap","fall"]
