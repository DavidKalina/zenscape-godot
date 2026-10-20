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
##             and it drops. With `leap_catch` 1 (off by default; the crag
##             reach's hunt sets it) a wall met mid-leap whose lip is within
##             `climb_max` over its feet is caught: it slaps onto the face
##             and goes to "climb" (`_catch_wall`); and hunting at an edge
##             with no landing across, him beyond, it throws itself at a face
##             across the gap up to `catch_gap` Hh off (`_wall_leap`).
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
## Whole, his head holds your eyes over the clips (olmec-look).
const OlmecGaze = preload("res://scripts/enemies/olmec_gaze.gd")
var gaze := OlmecGaze.new()
const Dust = preload("res://scripts/enemies/body_dust.gd")
const Routes = preload("res://scripts/enemies/body_routes.gd")
const Sight = preload("res://scripts/enemies/body_sight.gd")
const Hearing = preload("res://scripts/enemies/body_hearing.gd")
const OlmecVoid = preload("res://scripts/enemies/olmec_void.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")

## The head it looks for (found among the field's enemies: the one with a mouth).
var head: Node3D = null
## Where its own head was set down (InhalerHead `home()`), where a field
## holds several heads (scripts/enemies/body_spawner.gd); INF any head.
var head_home := Vector3.INF
## Reunited: the head on its neck.
var whole := false
## Whole, its chase runs on this clip ("" the stride, arms out; the Olmec
## boss sets "shoulder_run").
var run_clip := ""
## Counted, for the HUD and checks.
var climbs := 0
var leaps := 0
## Of the leaps, those ledge to ledge.
var jumps := 0
## `leap_catch`: walls caught mid-leap, leaps thrown at a face across a gap.
var wall_catches := 0
var wall_leaps := 0
## Why the last wall leap looked for wasn't taken (for drivers and F1).
var wall_leap_why := ""
## Why the last wall met mid-leap wasn't caught ("" caught).
var catch_why := ""
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
## Olmec reach (`beam`): crest lines [a, b] he walks end to end (a study's,
## the crag reach's fallen pillars), set after he's added.
var beams: Array = []
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
		"stride":Look.WALK_STEP,"stride_home":Look.STRIDE_STEP,"stride_run":Look.RUN_STEP,"triumph":1.8,
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
		# 1: walker-only stone (scripts/walker_only.gd) blocks its sight (he
		# hides in a niche it can't reach; the default since city-refuges
		# round 1); 0: it looks through it, as it walks through it.
		"sight_walker_only":1,
		# Beacons (scripts/enemies/beacon.gd, a refuge's echo): 1 it turns to a lit one in
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
		# slower (`hunt_grace` s, `hunt_drain`, `hunt_memory` s). He leaps gaps
		# to `hunt_gap` Hh. His leap's landing comes down `hunt_shock`
		# times harder. `void_push`: a shove (his waves, his blast) bent
		# this share toward the nearest void within VOID_REACH.
		"relentless":0,"hunt_range":n.unit*60.0,"hunt_half":1.25,"hunt_grace":2.5,"hunt_drain":0.12,"hunt_memory":30.0,
		"hunt_gap":4.6,"hunt_rise":0.9,"hunt_search":4.0,"hunt_shock":1.35,"void_push":0.0,
		# `breach` 1: hunting, a city wall, pillar or parapet in his way
		# (not over him: he climbs to you) he smashes through
		# (scripts/enemies/olmec_breach.gd, his `breacher`), not round.
		"breach":0,
		# Crag reach Olmec hunt: `leap_catch` 1, a wall met mid-leap is
		# caught and climbed when its lip is within `climb_max` (0: it
		# stops dead and drops, as before); hunting, a face across a gap
		# with no landing, at most `catch_gap` Hh off flat, is leapt at.
		"leap_catch":0,"catch_gap":9.0,
		# Olmec reach: `down_to` 1, hunting at a rim with you below him and
		# no plain drop, he looks along the rim (a fan of ways round yours)
		# for a floor down there nearer you, out to `down_reach` Hh flat,
		# and throws himself off on a higher arc (up to `down_arc` Hh) when
		# a lip or a ruin on the rim is in the plain arc's way.
		"down_to":0,"down_reach":5.5,"down_arc":2.4,
		# Olmec reach: `down_deep` > 0, `down_to` looks for that floor down
		# to `down_deep` Hh under the rim (a long drop onto a terrace far
		# below), not only `drop_max` m.
		"down_deep":0.0,
		# Olmec reach: `down_show` > 0 (m), `down_to` lands him where your
		# camera sees him come down (in its frame, past DOWN_SHOW_EDGE of
		# its sides) and at least that far from you flat, nearest you of
		# those; no such landing, the nearest as before. He comes down in
		# front of you, not on the camera.
		"down_show":0.0,
		# Olmec reach: `skirt_hold` 1, going round a wall in the hunt, the
		# skirt's time runs only as he walks it (not while he plants and
		# turns), and the next skirt round the same thing keeps its side,
		# so he goes round a ruin instead of bumping it on a loop.
		"skirt_hold":0,
		# Olmec reach: `climb_clear` 1, on a face (climbing, hauling,
		# mantling) his whole front is held off the rock, not his chest's
		# middle only: a bulge at his shoulder, hip or knee, a face slanting
		# across his breadth, the rim's round over his head.
		"climb_clear":0,
		# Olmec reach: `edge_fan` 1, at an edge in the hunt with no leap
		# straight on, he tries a little either side (EDGE_FAN) first.
		"edge_fan":0,
		# Olmec reach: `leg_slope` 1, the ground rising by his legs (a
		# sloped beam's crest behind him) doesn't push him sideways.
		"leg_slope":0,
		# Olmec reach: `drop_bulk` 1, a drop off an edge is taken only if
		# his bulk clears its arc (as `down_to`'s throws), not his feet only.
		"drop_bulk":0,
		# Olmec reach: `beam` 1, his `beams` (crest lines a study hands
		# him, the crag reach's fallen pillar) are a way: a goal past a
		# beam's far end, he heads for its near end and walks it end to end
		# down its crest, facing along it (no edge drops, no skirts, no
		# bulk push off it), as over a bridge.
		"beam":0,
		# Olmec reach: `dive` 1, `dive_off` (a study's call when he makes no
		# way to you) has him wind up and throw himself off the nearest
		# edge, out of the camera's look first; a dive catches no wall.
		"dive":0,
		# Olmec reach: `suck_in` 1, seen near (past his swat, inside the
		# suck's own reach) with no pounce to you (its arc or his room
		# blocked: under an overhang he can't fit) and no gain on you for
		# SUCK_IN_AFTER s, he plants and inhales you out from where you hide.
		"suck_in":0,
		# Olmec reach: `watch_throw` N s, when his landing's wave or his
		# swat throws you, he follows where you go for N s (you out of his
		# sight off a terrace's edge he threw you off): no hunt for the spot
		# you were knocked from.
		"watch_throw":0,
		# Olmec reach: `parked_off` 1, the parked plane's column (the
		# walker's keep-off, kit_isle.gd PARKED_LAYER) is no wall to him.
		"parked_off":0,
		# Olmec run: `run_up` > 0 (s), in the chase he sets off at his walk
		# (`walk`) and builds speed over `run_up` s of fairly straight
		# chasing (within RUN_STRAIGHT of his way) to `run_top` m/s. Each
		# radian he turns (past RUN_EASY rad/s) costs `run_turn_cost` of that
		# build; a plant, a
		# wall, an edge, a climb, a leap or an attack takes it all. At his
		# top he turns at `run_turn` rad/s (his chase turn at a walk), so
		# he swings wide and skids past a sharp sidestep. His gait follows
		# his real speed (walk, hunt stride, run clip; `_gait_mix`). 0 off:
		# `chase_speed` and the stride, as before.
		"run_up":0.0,"run_top":n.run*1.15,"run_turn_cost":1.0,"run_turn":0.45,
		# Olmec ledge: `ledge_stare` 1, at a rim in the chase with no leap
		# straight on he plants and stares at you (`stare_hold` s at least),
		# works out his way from that stand (a leap or drop either side,
		# `down_to`'s floor, a face across, a rim stand he walks to first),
		# turns once onto it and goes; no way, he stares on and looks again
		# every `stare_replan` s or when you move (no skirts along the rim).
		"ledge_stare":0,"stare_hold":1.0,"stare_replan":3.0,
		# Olmec ledge: `cliff_leap` 1, the stare's plan looks too for a
		# cliff face on land nearer you, across up to `cliff_gap` Hh off
		# flat and down to `cliff_deep` Hh under his feet, leapt at, caught
		# (`leap_catch`) and climbed; a study's never-stuck walks him to the
		# rim most your way to stare and plan there (`ledge_walk`).
		"cliff_leap":0,"cliff_gap":10.0,"cliff_deep":6.0,
		# Olmec climb: `climb_to` 1, you over him with no leap or drop, the
		# stare's plan looks along the foot of the face between you (rays
		# all round out to `climb_look` Hh) for a stretch he can climb
		# (`_climb_find`: no overhang, room past the lip, the lip nearer you
		# about your level or under it), walks there and climbs it. In the
		# chase, a wall he can't climb with you over it: he stares and
		# plans there (not skirts along its foot).
		"climb_to":0,"climb_look":8.0,
		# Olmec climb: `suck_up` N Hh (0 off), you over him on a ledge with
		# no face between you he can climb: from where he sees you (a stand
		# he walks to if need be), within N Hh, he plants (the jaw-opening
		# tell) and inhales you off the ledge down to him.
		"suck_up":0.0,
		# Olmec routes: `plan_chase` 1, his chase is a route over his place
		# graph (scripts/enemies/olmec_route_graph.gd, built at the study's load)
		# to where he believes you are, carried out with his own moves (walk,
		# climb, jump, drop, the cliff leap), each checked as that move checks
		# itself; the ledge stare is its planning beat. The per-terrain rules
		# it replaces are off while it is on (headless_body.gd `_plans`).
		"plan_chase":0,
		# Olmec tune (all 0 off):
		# `plan_smooth` 1, on a route's walk legs he aims at the farthest
		# point along the route within his look-ahead (PLAN_AIM, longer at
		# speed) that he walks straight to (the graph's `walk_line`), so a
		# grid route reads as straight lines and gentle curves, not 45°
		# steps; the legs pass by where he is along them.
		# `run_soft` R rad, a turn costs his build only once his facing has
		# swung more than about R over the last RUN_WINDOW s (in proportion
		# past it); a small heading change keeps his speed (also his speed
		# and build through a few degrees off his way, RUN_FREE_OFF).
		# `plan_keep` M (share), a fresh plan replaces the route he's on only
		# if its first way is near his, or it is M cheaper, or his route is
		# broken or planned to where you no longer are.
		# `plan_settle` S s, rubble come to rest plans again only once no
		# more has settled for S s (at most PLAN_SETTLE_MOST s on), and only
		# if it lies by his route.
		# `plan_flips` N, N turns back (reversals of his way past FLIP_MIN)
		# within FLIP_WINDOW s: he holds the route he's on (no fresh plan
		# but a failed leg) for FLIP_HOLD s.
		# `gaze_yaw` D degrees, his head turns no more than about D off his
		# body (eased into it); held past it, a stood body turns to follow.
		"plan_smooth":0,"run_soft":0.0,"plan_keep":0.0,"plan_settle":0.0,"plan_flips":0,"gaze_yaw":0.0,
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
	# Olmec reach: hung clear of the face's nearest across him.
	if float(knobs.climb_clear) > 0.5: _climb_clear(1.0)
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
	return gaze.over(self,tilt)

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
	if whole: gaze.step(self,delta)
	_progress(delta)
	_beacons(delta)
	_searching()
	if _plans(): _pc_flip_watch()
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
		"stare": _stare(delta)
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
		_: _think_more(delta)
	if whole and float(knobs.get("gaze_yaw",0.0)) > 0.0: _gaze_follow(delta)
	_animate(delta)

## A subclass's own states (the Olmec boss's charge), thought each frame.
func _think_more(_delta: float) -> void:
	pass

## A subclass's own states posed (clips wanted); false: not one of them.
func _pose_more(_idle: float) -> bool:
	return false

## The length of one step of its gait now, in head heights (its phase
## steps by it).
func _step_len() -> float:
	if _gaits():
		var g := _gait_mix()
		return float(knobs.stride)*g.x+float(knobs.stride_home)*g.y+float(knobs.stride_run)*g.z
	return float(knobs.stride_run if _running() else (knobs.stride_home if state in ["home","chase"] else knobs.stride))

func _go(to: String) -> void:
	# `run_up`: out of the chase (a climb, a leap, an attack, a look
	# about), his build is gone.
	if to != "chase": run_k = 0.0
	# Olmec ledge (`ledge_stare`): into the chase (over a lip, off a
	# landing) his way on is where he goes now, not the one he had before
	# the climb (his first stood step went that stale way, then back).
	if to == "chase" and _stares():
		var at := _rim_goal if _rim_goal != Vector3.INF else _stare_target()
		var d := Vector2(at.x-position.x,at.z-position.z)
		if d.length() > 0.1: _heading = PilotMotor.facing_of(d.normalized())
	state = to
	state_t = 0.0
	if to not in ["windup","leap"]: _drop_up = -1.0
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

func _brake(delta: float, share := 1.0) -> void:
	var flat := Vector2(vel.x,vel.z).move_toward(Vector2.ZERO,float(knobs.accel)*2.0*share*delta)
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
	_ray.collision_mask = _land_mask()
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
# A lit Beacon (scripts/enemies/beacon.gd: a refuge's echo) within its
# `draw` is heard the way the head's call is: it
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
	# Olmec reach: set clear of the face at once (not eased over frames).
	if float(knobs.climb_clear) > 0.5: _climb_clear(1.0)
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
	# Olmec reach: held off a bulge (`climb_clear`), his chest may be a
	# head height further off the face than the standoff.
	var far := hh if float(knobs.climb_clear) > 0.5 else 0.0
	var hit := _cast(chest,chest+fwd*(length*0.5+float(knobs.standoff)+1.5+far))
	if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7:
		var n := hit.normal as Vector3
		_face_pt = hit.position
		if float(knobs.climb_clear) < 0.5 or not _climb_clear(delta):
			var want := PilotMotor.facing_of(-Vector2(n.x,n.z).normalized())
			facing = lerp_angle(facing,want,1.0-exp(-4.0*delta))
			var gap := chest.distance_to(hit.position as Vector3)-length*0.5
			position += fwd*(gap-float(knobs.standoff))*minf(1.0,6.0*delta)
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

## Olmec reach (`climb_clear`): rays square to his facing from behind his
## back, over his breadth (each side and the middle) and his height (shin
## to head): the least gap (m) from his front to the rock, and the face's
## turn (rad) across his breadth (the left and right rays' hits at the
## same height). Hits with a floor's normal (a top he'll stand on) count
## only under his lip. {gap, turn} or {} with nothing in front of him.
const CLEAR_BACK := 1.0
const CLEAR_SIDE := 0.9
func _face_least(fwd: Vector3, lip_y := INF) -> Dictionary:
	var right := _right3()
	var half := width*0.5*CLEAR_SIDE
	var reach := length+float(knobs.standoff)+hh
	var least := INF
	var turn_sum := 0.0
	var turn_n := 0
	var top := _bulk_top()
	for k in 6:
		var up := lerpf(0.4,top,float(k)/5.0)
		var hits: Array = [null,null,null]
		for i in 3:
			var from := position+Vector3.UP*up+right*half*float(i-1)-fwd*(length*0.5+CLEAR_BACK)
			var h := _cast(from,from+fwd*(CLEAR_BACK+reach))
			if h.is_empty(): continue
			var hp := h.position as Vector3
			if absf((h.normal as Vector3).y) > 0.7 and hp.y > lip_y-0.3: continue
			if (h.normal as Vector3).dot(fwd) > 0.0: continue
			var gap := (hp-from).dot(fwd)-CLEAR_BACK-length
			least = minf(least,gap)
			hits[i] = gap
		if hits[0] != null and hits[2] != null:
			turn_sum += atan2(float(hits[2])-float(hits[0]),half*2.0)
			turn_n += 1
	if least == INF: return {}
	return {"gap":least,"turn":turn_sum/turn_n if turn_n > 0 else 0.0}

## Olmec reach (`climb_clear`): climbing, his front held `standoff` off
## the rock's nearest across him (out at once when he's in it, in or out
## eased), and turned square to the face across his breadth. False with
## no face found across him (the chest's ray then holds him, as before).
func _climb_clear(delta: float) -> bool:
	var f := _face_least(_forward3(),_lip_y)
	if f.is_empty(): return false
	var gap: float = f.gap
	var rate := 1.0 if gap < 0.0 else minf(1.0,6.0*delta)
	position += _forward3()*(gap-float(knobs.standoff))*rate
	# The right side further off than the left: he turns his front from
	# it, square to the face across his breadth (the face's line across
	# him is right x 2half + forward x (right gap - left gap)).
	var t := -float(f.turn)
	var fw := _forward3()*cos(t)+_right3()*sin(t)
	facing = lerp_angle(facing,PilotMotor.facing_of(Vector2(fw.x,fw.z)),1.0-exp(-4.0*delta))
	return true

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
		_pc_move = {}
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
	# Olmec reach (`drop_bulk`): his bulk clears the drop's arc too (off
	# main's NW rim he took a drop to a shelf 6 m down its face, his bulk
	# came down 1.2 m into the face, through the shelf and off the world).
	if not drop.is_empty() and _drop_ok(drop.at) and _arc_clear(drop.at,"drop",float(knobs.drop_bulk) > 0.5): return drop
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
	_drop_up = -1.0
	_flight = throw[1]
	vel = throw[0]
	grounded = false
	leaps += 1
	_go("leap")
	field.sound(&"body_leap",position)

## Olmec reach (`dive`): no way to you, he throws himself off the
## nearest edge: of DIVE_WAYS ways out, the first point within DIVE_LOOK
## m with no floor DIVE_DROP m under his feet, a way away from `away`
## (the camera) first; the throw lands DIVE_PAST m past that edge, far
## below. Whether he winds up for one.
const DIVE_WAYS := 16
const DIVE_LOOK := 30.0
const DIVE_DROP := 14.0
const DIVE_PAST := 8.0
var dives := 0
func dive_off(away := Vector3.INF) -> bool:
	if float(knobs.dive) < 0.5 or not grounded: return false
	if state in ["climb","mantle","windup","leap","fall","hang","grab_leap","grab_windup","land"]: return false
	var picks: Array = []
	for k in DIVE_WAYS:
		var a := TAU*float(k)/DIVE_WAYS
		var way := Vector3(cos(a),0.0,sin(a))
		var d := length*0.5
		while d <= DIVE_LOOK:
			var p := position+way*d
			if _floor(p,float(knobs.step)*STAIR,DIVE_DROP) == -INF:
				var score := d
				if away != Vector3.INF:
					var to := Vector3(away.x-position.x,0.0,away.z-position.z).normalized()
					score += maxf(0.0,way.dot(to))*DIVE_LOOK
				picks.append([score,p+way*DIVE_PAST-Vector3.UP*DIVE_DROP*2.0])
				break
			d += 1.5
	picks.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for pk: Array in picks:
		if not _dive_clear(pk[1]): continue
		_leap_to = pk[1]
		leap_kind = "dive"
		dives += 1
		_go("windup")
		field.sound(&"body_windup",position)
		return true
	return false

## Olmec reach (`dive`): no edge within DIVE_LOOK m (the middle of a
## crown), he strides off to the nearest rim within DIVE_FAR m that he
## can throw himself off, a way toward `toward` (you) first, none within
## DIVE_SHUN m of one in `shun`, for the study's watch to dive him off it.
## Set: `dive_goal` (his chase walks there, no route, no sight); INF none.
const DIVE_FAR := 90.0
const DIVE_FAR_STEP := 3.0
const DIVE_SHUN := 8.0
var dive_goal := Vector3.INF
var dive_walks := 0
func dive_walk(toward := Vector3.INF, shun: Array = []) -> bool:
	if float(knobs.dive) < 0.5 or not grounded: return false
	if state in ["climb","mantle","windup","leap","fall","hang","grab_leap","grab_windup","land"]: return false
	var picks: Array = []
	var to := Vector3.ZERO
	if toward != Vector3.INF: to = Vector3(toward.x-position.x,0.0,toward.z-position.z).normalized()
	for k in DIVE_WAYS:
		var a := TAU*float(k)/DIVE_WAYS
		var way := Vector3(cos(a),0.0,sin(a))
		var last := Vector3.INF
		var d := length*0.5
		while d <= DIVE_FAR:
			var p := position+way*d
			var f := _floor(p,float(knobs.step)*STAIR,DIVE_DROP)
			if f == -INF:
				if last != Vector3.INF and not shun.any(func(q: Vector3) -> bool: return q.distance_to(last) < DIVE_SHUN):
					picks.append([d-maxf(0.0,way.dot(to))*DIVE_LOOK,last,p+way*DIVE_PAST-Vector3.UP*DIVE_DROP*2.0])
				break
			# A step up or down past his stair: not this way's floor.
			if last != Vector3.INF and absf(f-last.y) > float(knobs.step)*STAIR*2.0: break
			last = Vector3(p.x,f,p.z)
			d += DIVE_FAR_STEP
	picks.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var goal := Vector3.INF
	# A rim he can throw himself off (its fall clear from where he'd stand).
	for pk: Array in picks:
		if _dive_clear(pk[2],pk[1]):
			goal = pk[1]
			break
	if goal == Vector3.INF: return false
	dive_goal = goal
	dive_walks += 1
	_chase_drop()
	_skirt_t = 0.0
	if state != "chase": _go("chase")
	return true

## Whether a dive at `to` falls DIVE_DROP x 1.5 m clear: its arc flown in
## ARC_DT steps, his feet and his bulk meeting nothing past take-off (from
## `from`, else where he stands).
func _dive_clear(to: Vector3, from := Vector3.INF) -> bool:
	if from == Vector3.INF: from = position
	var throw := _throw(from,to,"dive")
	var v: Vector3 = throw[0]
	var p := from
	var g := float(knobs.leap_gravity)
	var t := 0.0
	while p.y > from.y-DIVE_DROP*1.5 and t < 5.0:
		var q := p+v*ARC_DT
		v.y -= g*ARC_DT
		t += ARC_DT
		if t > 0.15 and (not _cast(p+Vector3.UP*0.05,q).is_empty() or _bulk_sweep(p,q) < 1.0): return false
		p = q
	return true

## The throw from `from` to `to` ("jump" across, else a drop): [its
## velocity, its time in the air]. A jump's is longer and flatter, peaking
## a share of its length (and over the far ledge if that stands higher).
func _throw(from: Vector3, to: Vector3, kind: String) -> Array:
	var g := float(knobs.leap_gravity)
	var flat := Vector2(to.x-from.x,to.z-from.z)
	var drop := from.y-to.y
	var up := float(knobs.leap_up)
	if kind == "drop" and _drop_up > 0.0: up = _drop_up
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
func _arc_clear(to: Vector3, kind: String, bulk := false, coarse := 1.0) -> bool:
	# Olmec round 1: room for its bulk where it comes down (a shaft, a slot
	# its shoulders don't fit, is no landing).
	if not _room_at(to): return false
	var throw := _throw(position,to,kind)
	var v: Vector3 = throw[0]
	var p := position
	var g := float(knobs.leap_gravity)
	var t := 0.0
	# `coarse`: flown in longer steps (the place graph's build, olmec_route_graph.gd).
	var dt := ARC_DT*coarse
	while t < float(throw[1])+1.0:
		v.y -= g*dt
		var next := p+v*dt
		var hit := _cast(p+Vector3.UP*0.05,next)
		if not hit.is_empty():
			if (hit.normal as Vector3).y > 0.5 and v.y <= 0.0: return (hit.position as Vector3).distance_to(to) <= ARC_LAND
			return false
		# Olmec round 1: its bulk would fly into a wall on the way.
		if (kind != "drop" or bulk) and _bulk_sweep(p,next) < 1.0: return false
		p = next
		t += dt
	return false

## `leap_catch`: a wall met mid-leap (flying along `way`, flat) caught. The
## face found by rays along its way at its chest, hips, knee and shoulders
## (from its back, so a bulk stopped short still finds it), turned to it;
## its lip by a ray down past the face from `climb_max` over its feet,
## room over it. Caught: set on the face `standoff` off, faced to it,
## climbing (a lip under its feet' step, lowered under it, so it mantles at
## once); dust and stones off the face where it struck, a quake. False:
## off, no face, or the lip out of reach (it drops, as before).
func _catch_wall(way: Vector3) -> bool:
	if float(knobs.leap_catch) < 0.5: return false
	if leap_kind == "dive": return false
	var dir := way.normalized() if way.length() > 0.1 else _forward3()
	var c := _catch_at(position,dir)
	# Olmec routes (`plan_chase`): his bulk met the lip's round at about its
	# height (the face under his feet): the face looked for lower down.
	if c.is_empty() and _plans():
		for down: float in [hh*0.5,hh,hh*1.6]:
			c = _catch_at(position-Vector3.UP*down,dir)
			if not c.is_empty(): break
	if c.is_empty(): return false
	var n: Vector3 = c.n
	var face: Vector3 = c.face
	var lip: Vector3 = c.lip
	var feet_y := minf(position.y,lip.y-float(knobs.step)*1.2)
	position = Vector3(face.x,feet_y,face.z)+n*(length*0.5+float(knobs.standoff))
	facing = PilotMotor.facing_of(-Vector2(n.x,n.z).normalized())
	rotation.y = facing
	vel = Vector3.ZERO
	grounded = false
	# Olmec reach: caught clear of the face's nearest across him.
	if float(knobs.climb_clear) > 0.5: _climb_clear(1.0)
	_climb_from = position.y
	_lip_y = INF
	_hang = false
	_haul_t = 0.0
	climbs += 1
	wall_catches += 1
	_go("climb")
	field.sound(&"body_grip",face)
	field.sound(&"body_land",face)
	quake = maxf(quake,0.35)
	var dust_at := Vector3(face.x,position.y+neck_h*0.7,face.z)
	Dust.puff(field,dust_at,hh*1.6*_tell_k(),n)
	Dust.rocks(field,dust_at,n,5,hh*0.12*_tell_k())
	return true

## What `_catch_wall` would catch flying along `dir` with his feet at `at`:
## {n, face, lip} or {} (`catch_why` says why not).
func _catch_at(at: Vector3, dir: Vector3) -> Dictionary:
	var hit := {}
	# Its chest first, then up and down its height (the face its bulk met).
	var ups: Array[float] = [neck_h*0.55]
	var u := 0.2
	while u <= _bulk_top():
		ups.append(u)
		u += hh*0.25
	for up: float in ups:
		var from := at+Vector3.UP*up-dir*(length*0.5)
		var h := _cast(from,from+dir*(length+hh*1.5))
		if h.is_empty(): continue
		var hn := h.normal as Vector3
		if absf(hn.y) > 0.5 or Vector3(hn.x,0.0,hn.z).normalized().dot(dir) > -0.3: continue
		hit = h
		break
	if hit.is_empty():
		catch_why = "no face along its way at %s" % at.round()
		return {}
	var n := hit.normal as Vector3
	n = Vector3(n.x,0.0,n.z).normalized()
	var face := hit.position as Vector3
	var past := face-n*float(knobs.lip_in)
	var top := _cast(Vector3(past.x,at.y+float(knobs.climb_max),past.z),Vector3(past.x,at.y-neck_h*0.5,past.z))
	if top.is_empty() or (top.normal as Vector3).y < 0.6:
		catch_why = "no lip within climb_max over %s" % at.round()
		return {}
	var lip := top.position as Vector3
	if not _cast(lip+Vector3.UP*0.1,lip+Vector3.UP*neck_h*0.5).is_empty():
		catch_why = "no room over the lip at %s" % lip.round()
		return {}
	catch_why = ""
	return {"n":n,"face":face,"lip":lip}

## `leap_catch`, hunting at an edge with no landing across (`_hunt_edge`),
## him beyond and up off its feet: a face across the gap along `fwd`, at
## most `catch_gap` Hh off flat (and no farther than him), looked for at
## its own feet' height and up to three head heights under, its knee and
## chest both on it, its lip within `climb_max` over where it would meet
## it; the arc there clear (nothing met but that face). It winds up and
## throws itself at the face (a jump's arc), to catch it (`_catch_wall`).
func _wall_leap(fwd: Vector3, goal: Vector3) -> bool:
	if state != "chase": return false
	var w := _wall_leap_find(fwd,goal)
	if w.is_empty(): return false
	_leap_to = w.to
	leap_kind = "jump"
	wall_leaps += 1
	_go("windup")
	field.sound(&"body_windup",position)
	return true

## `_wall_leap`'s look, without the leap: {to (thrown at), face, lip} or {}.
func _wall_leap_find(fwd: Vector3, goal: Vector3) -> Dictionary:
	if float(knobs.leap_catch) < 0.5: return {}
	var step := float(knobs.step)
	if goal.y <= position.y-hh*3.0: return {}
	var far := Vector2(goal.x-position.x,goal.z-position.z).length()
	# The rim along its way (where its floor stops).
	var rim := -1.0
	var d := 0.0
	while d <= length*0.5+float(knobs.look)+1.0:
		if _floor(position+fwd*d,step,step*2.0) == -INF:
			rim = d
			break
		d += 0.25
	if rim < 0.0:
		wall_leap_why = "no rim"
		return {}
	var most := minf(float(knobs.catch_gap)*hh,far)
	wall_leap_why = "no face within %.1f m" % most
	for down: float in [0.0,hh,hh*2.0,hh*3.0]:
		var feet_y := position.y-down
		var hit := {}
		for up: float in [neck_h*0.55,step+0.1]:
			var from := Vector3(position.x,feet_y+up,position.z)+fwd*(rim+0.3)
			var h := _cast(from,from+fwd*maxf(most-rim,0.5))
			var hn := (h.normal as Vector3) if not h.is_empty() else Vector3.UP
			if h.is_empty() or absf(hn.y) > 0.5 or Vector3(hn.x,0.0,hn.z).normalized().dot(fwd) > -0.4:
				hit = {}
				break
			if hit.is_empty(): hit = h
		if hit.is_empty(): continue
		var n := hit.normal as Vector3
		n = Vector3(n.x,0.0,n.z).normalized()
		var face := hit.position as Vector3
		var past := face-n*float(knobs.lip_in)
		var top := _cast(Vector3(past.x,feet_y+float(knobs.climb_max),past.z),Vector3(past.x,feet_y+step,past.z))
		if top.is_empty() or (top.normal as Vector3).y < 0.6:
			wall_leap_why = "a face %.1f m off, its lip past climb_max" % Vector2(face.x-position.x,face.z-position.z).length()
			continue
		var to := Vector3(face.x,feet_y,face.z)+fwd*0.6
		if not _wall_arc(to,face):
			wall_leap_why = "a face %.1f m off, the arc there blocked" % Vector2(face.x-position.x,face.z-position.z).length()
			continue
		# Olmec ledge: only a catch his arc can make.
		if float(knobs.get("cliff_leap",0)) >= 0.5 and not _catch_ok(to,face):
			wall_leap_why = "a face %.1f m off, no catch where the arc meets it" % Vector2(face.x-position.x,face.z-position.z).length()
			continue
		wall_leap_why = ""
		return {"to":to,"face":face,"lip":top.position}
	return {}

## The arc's rise (m) for the drop being thrown (`down_to`), -1 the knob's.
var _drop_up := -1.0
var _down_next := 0.0
const DOWN_EVERY := 0.5
const DOWN_TRIES := 24
## `down_show`: the picture's margin a landing's feet and shins keep in (a
## share of its width / height), and what an unseen landing adds to its
## distance.
const DOWN_SHOW_EDGE := 0.1
const DOWN_UNSEEN := 1000.0
var down_tos := 0
var down_why := ""

## `down_to`: hunting at a rim, him a step or more under its feet and
## within twice `down_reach` flat: a floor down there nearer him than it
## stands, not a head height under his, along a fan of ways round his
## (his own first), found as `_drop` finds one but out to `down_reach` Hh;
## its arc tried plain, then higher to `down_arc` Hh, till one clears (a
## lip or a ruin on the rim no longer in its way). The nearest him wins; it
## winds up and throws itself off.
func _down_to(goal: Vector3) -> bool:
	if state != "chase": return false
	var best := _down_find(goal)
	if best.is_empty(): return false
	down_tos += 1
	_leap_to = best.at
	leap_kind = "drop"
	_drop_up = best.up
	_go("windup")
	field.sound(&"body_windup",position)
	return true

## `_down_to`'s look, without the leap: {at, up (the arc's rise)} or {}.
func _down_find(goal: Vector3) -> Dictionary:
	if float(knobs.down_to) < 0.5: return {}
	var step := float(knobs.step)
	if goal.y >= position.y-step: return {}
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	var reach := float(knobs.down_reach)*hh
	if to.length() < 0.1 or to.length() > reach*2.0: return {}
	var base := PilotMotor.facing_of(to.normalized())
	var now := position.distance_to(goal)
	var best := {}
	var best_d := INF
	var show := float(knobs.down_show)
	var deep := maxf(float(knobs.drop_max),float(knobs.down_deep)*hh)
	down_why = "no floor under the rim nearer him"
	# Arcs flown at most (each a few dozen casts and bulk sweeps): the
	# landings found first, then flown best first.
	var tries := DOWN_TRIES
	var found := []
	for a: float in [0.0,0.35,-0.35,0.7,-0.7,1.1,-1.1]:
		var dir := _way3(wrapf(base+a,-PI,PI))
		var d := length*0.5+float(knobs.look)
		while d <= reach:
			var p := position+dir*d
			var hit := _cast(p+Vector3.UP*step,p-Vector3.UP*deep)
			d += 1.5
			if hit.is_empty() or (hit.normal as Vector3).y <= 0.7: continue
			var y := (hit.position as Vector3).y
			if y >= position.y-step or y < goal.y-hh: continue
			var onto := p+dir*(length*0.5+1.0)
			var g := _floor(Vector3(onto.x,y,onto.z),1.0,1.0)
			if g == -INF: continue
			var at := _down_room(Vector3(onto.x,g,onto.z))
			if at == Vector3.INF: continue
			var dd := at.distance_to(goal)
			if dd >= now-hh: continue
			# Scored: a landing your camera won't see, or on top of you,
			# only when there's no other.
			if show > 0.0 and (Vector2(at.x-goal.x,at.z-goal.z).length() < show or not _lands_seen(at)): dd += DOWN_UNSEEN
			found.append([dd,at])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for f: Array in found:
		if tries <= 0 or float(f[0]) >= best_d: break
		var at: Vector3 = f[1]
		# Olmec ledge: his bulk flown turned to the landing, as the windup
		# turns him (not as he stands staring at you).
		var was_f := facing
		var to_at := Vector2(at.x-position.x,at.z-position.z)
		if _stares() and to_at.length() > 0.1: facing = PilotMotor.facing_of(to_at.normalized())
		for up: float in [float(knobs.leap_up),hh*0.8,hh*1.4,float(knobs.down_arc)*hh]:
			tries -= 1
			_drop_up = up
			var ok := _arc_clear(at,"drop",true)
			_drop_up = -1.0
			if ok:
				best = {"at":at,"up":up}
				best_d = float(f[0])
				break
		facing = was_f
		if not best.is_empty(): break
	if not best.is_empty(): down_why = ""
	return best

## Staged (a study's set piece, e.g. the heist's drop where you just
## were): it throws itself off where it stands onto the floor at `to` (or
## the room nearest it there), the arc tried as `_down_to` tries its own
## (plain, then higher to `down_arc` Hh); it winds up and goes. False (it
## stays) if it's off its feet or no arc clears.
func stage_drop(to: Vector3) -> bool:
	if not grounded or state in ["leap","fall","climb","mantle","hang","windup"]: return false
	var at := _down_room(to)
	if at == Vector3.INF:
		down_why = "staged: no room at %s" % to
		return false
	for up: float in [float(knobs.leap_up),hh*0.8,hh*1.4,float(knobs.down_arc)*hh]:
		_drop_up = up
		if _arc_clear(at,"drop",true):
			down_why = ""
			down_tos += 1
			_leap_to = at
			leap_kind = "drop"
			_go("windup")
			field.sound(&"body_windup",position)
			return true
	_drop_up = -1.0
	down_why = "staged: no arc clears to %s" % at
	return false

## A staged drop's landing moved to `at` while it winds up (a study
## aiming it where your camera will see it, as the pounce aims at you):
## the arc tried as `stage_drop` tries it. False (the old landing holds)
## past its windup or if no arc clears.
func aim_drop(at: Vector3) -> bool:
	if state != "windup" or leap_kind != "drop": return false
	var was := _drop_up
	for up: float in [float(knobs.leap_up),hh*0.8,hh*1.4,float(knobs.down_arc)*hh]:
		_drop_up = up
		if _arc_clear(at,"drop",true):
			_leap_to = at
			return true
	_drop_up = was
	return false

## The next drop's landing wave scaled by this (a study's staged near
## miss, set as it stages one; back to 1 as it lands).
var staged_shock := 1.0

## Whether the camera sees him land at `at`: his feet and shins (most of
## him is over the picture of a camera close over you) in front of it and
## within its picture short of DOWN_SHOW_EDGE of each side. No camera: yes.
func _lands_seen(at: Vector3) -> bool:
	var camera: Camera3D = field.study.get("camera") if field != null and field.study != null else null
	if camera == null or not camera.is_inside_tree(): return true
	var size := camera.get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0: return true
	for p: Vector3 in [at+Vector3.UP*0.3,at+Vector3.UP*hh]:
		if camera.is_position_behind(p): return false
		var px := camera.unproject_position(p)/size
		if px.x < DOWN_SHOW_EDGE or px.x > 1.0-DOWN_SHOW_EDGE or px.y < DOWN_SHOW_EDGE or px.y > 1.0-DOWN_SHOW_EDGE: return false
	return true

## A spot with room for its bulk at `at` or round it (a narrow terrace:
## the widest of it near there), on about the same floor; INF none.
func _down_room(at: Vector3) -> Vector3:
	if _room_at(at): return at
	for r: float in [hh*0.6,hh*1.2]:
		for i in 8:
			var q := at+Vector3(cos(i*TAU/8.0),0.0,sin(i*TAU/8.0))*r
			var g := _floor(q,1.0,1.5)
			if g == -INF: continue
			q.y = g
			if _room_at(q): return q
	return Vector3.INF

## Whether the jump's arc to `to` (just into a face at `face`) meets that
## face first: its feet rays along it hitting nothing till a steep face
## within ARC_LAND (flat) of `face`, its bulk swept into nothing short of
## there.
func _wall_arc(to: Vector3, face: Vector3, coarse := 1.0) -> bool:
	var throw := _throw(position,to,"jump")
	var v: Vector3 = throw[0]
	var p := position
	var g := float(knobs.leap_gravity)
	var t := 0.0
	var dt := ARC_DT*coarse
	var near := func(q: Vector3) -> bool: return Vector2(q.x-face.x,q.z-face.z).length() <= ARC_LAND+length
	while t < float(throw[1])+0.5:
		v.y -= g*dt
		var next := p+v*dt
		var hit := _cast(p+Vector3.UP*0.05,next)
		if not hit.is_empty():
			return absf((hit.normal as Vector3).y) < 0.5 and near.call(hit.position)
		if _bulk_sweep(p,next) < 1.0: return near.call(next)
		p = next
		t += dt
	return false

## Olmec ledge (`cliff_leap`): whether the jump at `to` (just into a face at
## `face`) is caught there: its arc flown as `_wall_arc` flies it to where
## its feet or bulk meet that face, and `_catch_at` from there finding the
## face and a lip within `climb_max` with room over it (only throws whose
## catch his arc can make). `cliff_misses` counts those turned down.
var cliff_misses := 0
func _catch_ok(to: Vector3, face: Vector3, coarse := 1.0) -> bool:
	var throw := _throw(position,to,"jump")
	var v: Vector3 = throw[0]
	var dir := Vector3(v.x,0.0,v.z).normalized()
	var p := position
	var g := float(knobs.leap_gravity)
	var t := 0.0
	var dt := ARC_DT*coarse
	var stop := Vector3.INF
	while t < float(throw[1])+0.5:
		v.y -= g*dt
		var next := p+v*dt
		var hit := _cast(p+Vector3.UP*0.05,next)
		var f := _bulk_sweep(p,next)
		if f < 1.0 and (hit.is_empty() or f < p.distance_to(hit.position)/maxf(p.distance_to(next),0.0001)):
			stop = p.lerp(next,f)
			break
		if not hit.is_empty():
			var n := hit.normal as Vector3
			if absf(n.y) >= 0.5: return false
			stop = (hit.position as Vector3)+Vector3(n.x,0.0,n.z)*0.1-Vector3.UP*0.05
			break
		p = next
		t += dt
	if stop == Vector3.INF or Vector2(stop.x-face.x,stop.z-face.z).length() > ARC_LAND+length: return false
	var why := catch_why
	var c := _catch_at(stop,dir)
	catch_why = why
	if c.is_empty():
		cliff_misses += 1
		return false
	return true

func _fall() -> void:
	# Olmec routes: off a planned climb's face, that climb is banned.
	if state in ["climb","feel","mantle"]: _pc_move_failed("let go (%s)" % let_go_why)
	grounded = false
	vel = Vector3(vel.x,minf(vel.y,0.0),vel.z)
	_go("fall")

## Down: the harder it came down, the bigger the wave (a head height's
## fall is 1; 0.6 to 1.5).
func _landed() -> void:
	var impact := maxf(0.0,-vel.y)
	var pounced := state == "leap" and leap_kind == "pounce"
	_land_clip = "drop_land" if state == "leap" and leap_kind == "drop" else "land"
	# Olmec routes: a planned leap come down off its end (a fall after it,
	# a wall it stopped dead on): banned; at its end, done.
	if not _pc_move.is_empty():
		var end: Vector3 = _pc_move.to
		if Vector2(end.x-position.x,end.z-position.z).length() > Routes.CELL*3.0 or absf(end.y-position.y) > 3.0: _pc_move_failed("came down off its end")
		else: _pc_move = {}
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
	if leap_kind == "drop":
		power *= staged_shock
		staged_shock = 1.0
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
	_threw_t = float(knobs.get("watch_throw",0))
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
## `skirt_hold`: a skirt that ended this recently (s) keeps its side.
const SKIRT_KEEP := 4.0

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
## `suck_in`: how long (s) he's been near you with no pounce and no gain.
var _suck_in_t := 0.0
## `watch_throw`: s left of following you after a throw.
var _threw_t := 0.0
var _suck_in_d := INF
const SUCK_IN_AFTER := 1.5
var sucks_in := 0
var _suck_unseen := 0.0
var _seek_from := 0.0
var _swat_hit := false
var _skirt_way := 0.0
var _skirt_t := 0.0
## `skirt_hold`: the side (+1/-1) the last skirt took, and when it ended.
var _skirt_side := 0.0
## The skirt is round a wall (from `_hunt_wall`), not along a rim.
var _skirt_wall := false
var _skirt_end := -INF
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
	sight.mask = _land_mask()
	# `sight_walker_only` 1: walker-only stone (a niche, a hush gallery)
	# hides him from its eyes, though it can't walk or climb it.
	if float(knobs.get("sight_walker_only",0)) >= 0.5: sight.mask |= WalkerOnly.LAYER
	# Held up, it looks down and about more widely (`scope_wide` times its cone).
	# Olmec threat round 1: hunting (relentless) he sees further and wider,
	# and loses you slower.
	var hunt := hunting and _relentless()
	sight.deep = float(knobs.hunt_range) if hunt else float(knobs.sight_range)
	sight.grace = float(knobs.hunt_grace) if hunt else float(knobs.sight_grace)
	sight.drain = float(knobs.hunt_drain) if hunt else float(knobs.sight_drain)
	sight.half = (float(knobs.hunt_half) if hunt else float(knobs.sight_half))*(float(knobs.scope_wide) if state == "scope" and _held_w > 0.5 else 1.0)
	sight.exclude = _skip()
	if m.seized():
		# In its mouth: held, not looked for.
		sight.step(delta,1.0)
		seen_at = m.feet
		seen_t = 0.0
		return
	# `watch_throw`: he threw you; he knows where you went.
	var threw := _threw_t > 0.0
	if threw: _threw_t -= delta
	var pts := Sight.pilot_points(m.feet,false)
	sight.update(delta,field.study.get_world_3d().direct_space_state,_eye(),_look_way(),pts,not m.grounded)
	if sight.seeing():
		seen_at = m.feet
		seen_t = 0.0
		if state != "scope": _scoped = false
		_trail_seen(m.feet)
	elif threw:
		seen_at = m.feet
		seen_t = 0.0
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
	if _plans(): line += "\n"+plan_text()
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
	# Olmec reach (`dive_walk`): off to a rim to throw himself off it.
	if dive_goal != Vector3.INF:
		_pursue(delta,dive_goal,_chase_pace())
		return
	# Olmec routes (`plan_chase`): his route over the place graph.
	if _plans():
		_pc_chase(delta)
		return
	# Olmec ledge: on his walk to a rim stand.
	if _rim_walk(delta): return
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
	elif _attack_with(m,flat,to.y,delta): return
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
	# Olmec reach: you down under the rim near him: he looks for a way off
	# it to you as he comes (not only at the edge his walk meets, which a
	# ruin or the aqueduct's end can keep him from).
	if not _chase_routed and _clock >= _down_next:
		_down_next = _clock+DOWN_EVERY
		if _down_to(target): return
	if _chase_routing(delta,target): return
	_pursue(delta,target,_chase_pace())

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

## `climb_to`: the stare found no climb; the planner's route may go.
var _route_next := false

## After him, if it may: lost up out of its walk (or `at`, his feet seen
## up there with no way at him), to where it last saw him; there already,
## on along his way, if he went up. True: a route is being planned.
func _after_try(at := Vector3.INF) -> bool:
	if float(knobs.get("climb_after",0)) < 0.5 or float(knobs.routes) < 0.5 or not hunting: return false
	if _clock < _after_ready: return false
	var seen := at if at != Vector3.INF else seen_at
	if seen == Vector3.INF: return false
	# Olmec climb (`climb_to`): you up out of his walk, he stares and looks
	# along the face's foot first; the planner's route is his next try.
	if _climbs_up(seen) and _stares() and state == "chase" and not _route_next and _clock >= _wall_stare_next:
		_wall_stare_next = _clock+float(knobs.stare_replan)
		_stare_start()
		return true
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
## `_attack` with the frame's delta kept for `suck_in`'s clock.
var _attack_dt := 0.0
func _attack_with(m: PilotMotor, flat: float, dy: float, delta: float) -> bool:
	_attack_dt = delta
	return _attack(m,flat,dy)

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
	# Olmec climb (`suck_up`): you over him on a ledge, his plan found no
	# face between you to climb: he pulls you off it down to him, now.
	var up := _climbs_up(m.feet) and dy > neck_h*0.6
	if up and float(knobs.get("suck_up",0)) > 0.0 and _up_none and state == "stare" and _clock >= _suck_ready \
			and m.feet.distance_to(position) <= float(knobs.suck_up)*hh and head != null and head.perch == self \
			and head.has_method("worn_reaches") and head.worn_reaches(m):
		sucks_up += 1
		_suck_up_now = true
		sucks += 1
		_suck_unseen = 0.0
		_stare_note("pulls you down from %s" % m.feet.round())
		_go("plant")
		field.sound(&"head_inhale",head.mouth())
		chase_beat.emit("suck")
		return true
	# While he works out or takes a way up, no suck from under you.
	if up and (state == "stare" and not _up_none or str(_rim_then.get("kind","")) == "climb"): return false
	var near_in := float(knobs.get("suck_in",0)) > 0.0 and flat > float(knobs.catch_reach)*hh and flat < float(knobs.suck_min)*hh
	if near_in:
		# No gain of 1 m on you, the clock runs (reset when he gains).
		if flat < _suck_in_d-1.0:
			_suck_in_d = flat
			_suck_in_t = 0.0
		else: _suck_in_t += _attack_dt
	else:
		_suck_in_t = 0.0
		_suck_in_d = INF
	var sucks_close := near_in and _suck_in_t >= SUCK_IN_AFTER
	if (sucks_close or (flat >= float(knobs.suck_min)*hh and flat <= float(knobs.suck_max)*hh*(1.3 if _relentless() else 1.0))) and _clock >= _suck_ready and head != null and head.perch == self \
			and head.has_method("worn_reaches") and head.worn_reaches(m):
		if sucks_close:
			sucks_in += 1
			_suck_in_t = 0.0
			_suck_in_d = INF
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

# --- Olmec run (`run_up`): speed built up into a run ------------------------------------

## His build (0 his walk, 1 `run_top`): it climbs over `run_up` s of
## fairly straight chasing; turns, plants and other states take it off.
var run_k := 0.0
## Within this of his way (rad) the chase counts as straight: the build climbs.
const RUN_STRAIGHT := 0.3
## Turning slower than this (rad/s) costs nothing (`run_turn_cost` is a
## radian turned faster): he leans into a gentle curve at speed.
const RUN_EASY := 0.2
## At his top he swings round up to this off his way (rad) before he
## plants (CHASE_TURN at a walk).
const RUN_WIDE := 1.4
## A plant at his top brakes at this share of the walk's brake: he skids on.
const RUN_SKID := 0.5
## The build never runs more than this ahead of his real speed's share
## (so a wall, a skirt or a brake takes it off as they slow him).
const RUN_SLACK := 0.06
## No floor where he'd stop (at his speed, braking at `accel`), the
## build goes off this fast (a s): he eases up before a rim.
const RUN_EASE := 0.8
## His gaits by real speed (head heights a second, so they keep to his
## size): walk to hunt stride over GAIT_STRIDE, the stride to the run
## clip over GAIT_RUN. Each clip's phase comes from the distance walked
## over the blended step (`_step_len`), so the feet don't slide.
const GAIT_STRIDE := Vector2(0.62,0.85)
const GAIT_RUN := Vector2(1.05,1.3)

## Olmec tune (`run_soft`): the window (s) his facing's swing is read over,
## and the share off his way (rad) that costs no speed.
const RUN_WINDOW := 1.0
const RUN_FREE_OFF := 0.25
## His facing over the last RUN_WINDOW s: [clock, facing] pairs.
var _fac_hist: Array[Vector2] = []

## `run_soft`: his facing noted now; 0 (a small change, free) to 1 (a real
## turn) by how far it swung over the last RUN_WINDOW s, the most of any
## time in it from now, eased over 0.8 to 1.3 of `soft` rad.
func _turn_real(soft: float) -> float:
	if not _fac_hist.is_empty() and _clock-_fac_hist[-1].x > 0.25: _fac_hist.clear()
	_fac_hist.append(Vector2(_clock,facing))
	while _fac_hist.size() > 1 and _clock-_fac_hist[0].x > RUN_WINDOW: _fac_hist.pop_front()
	var net := 0.0
	for h: Vector2 in _fac_hist: net = maxf(net,absf(angle_difference(h.y,facing)))
	return smoothstep(soft*0.8,soft*1.3,net)

## Chasing with `run_up` on.
func _runs() -> bool:
	return float(knobs.get("run_up",0.0)) > 0.0 and state == "chase"

## The chase's speed (m/s): `run_up`, his walk to `run_top` by his build;
## else `chase_speed`.
func _chase_pace() -> float:
	if not _runs(): return float(knobs.chase_speed)
	return lerpf(float(knobs.walk),float(knobs.run_top),run_k)

## The build after a frame of the chase's walk: up while he heads fairly
## straight, eased off before a rim, held to his real speed.
func _run_build(delta: float, off: float, fwd: Vector3) -> void:
	if absf(off) < RUN_STRAIGHT: run_k = minf(run_k+delta/float(knobs.run_up),1.0)
	if run_k > 0.2:
		var v := Vector2(vel.x,vel.z).length()
		var stop := v*v/(2.0*float(knobs.accel))
		if _floor(position+fwd*stop,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF:
			run_k = maxf(run_k-RUN_EASE*delta,0.0)
	_run_hold()

func _run_hold() -> void:
	var v := Vector2(vel.x,vel.z).length()
	var real := (v-float(knobs.walk))/maxf(float(knobs.run_top)-float(knobs.walk),0.01)
	run_k = clampf(minf(run_k,maxf(real,0.0)+RUN_SLACK),0.0,1.0)

## His gait picked by his real speed (`run_up` on, chasing).
func _gaits() -> bool:
	return _runs() and whole

## The gaits' shares by his real speed: (walk, hunt stride, run).
func _gait_mix() -> Vector3:
	var v := Vector2(vel.x,vel.z).length()/maxf(hh,0.01)
	var run := smoothstep(GAIT_RUN.x,GAIT_RUN.y,v)
	var walk := 1.0-smoothstep(GAIT_STRIDE.x,GAIT_STRIDE.y,v)
	return Vector3(walk,maxf(1.0-walk-run,0.0),run)

## The gait clips (walk, stride, run) `_gait_mix` blends.
func _gait_clips() -> Array[String]:
	return ["walk","hunt_stride",run_clip if run_clip != "" else "shoulder_run"]

## The gait clip with most of his walk now ("" none: not walking on gaits).
func gait() -> String:
	if not _gaits(): return ""
	var g := _gait_mix()
	var c := _gait_clips()
	return c[0] if g.x >= g.y and g.x >= g.z else (c[1] if g.y >= g.z else c[2])

## Walked at `goal` at `speed` m/s: turned to it (on the spot if far off),
## a wall met climbed (he's up there) or skirted, an edge met leapt.
func _pursue(delta: float, goal: Vector3, speed: float) -> void:
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	if _skirt_t > 0.0:
		# `skirt_hold`: round a wall, the skirt's clock runs as he walks it
		# (a quarter as fast while he plants and turns onto it).
		# `edge_fan`: along a rim too (on main's east rim the whole skirt
		# went in the plant and turn, and he stood there 12 s).
		var walked := float(knobs.skirt_hold) < 0.5 or (not _skirt_wall and float(knobs.edge_fan) < 0.5) or Vector2(vel.x,vel.z).length() > 0.5
		_skirt_t -= delta if walked else delta*0.25
		if _skirt_t <= 0.0: _skirt_end = _clock
		_heading = _skirt_way
	elif to.length() > 0.05: _heading = PilotMotor.facing_of(to.normalized())
	if _grab_try(delta,goal): return
	# A rim it would grab, too far off: it heads for where it would hang from
	# it (out from under a place over it, too).
	if _grab_aim != Vector3.INF and _skirt_t <= 0.0:
		var aim := Vector2(_grab_aim.x-position.x,_grab_aim.z-position.z)
		if aim.length() > 0.3: _heading = PilotMotor.facing_of(aim.normalized())
	# Olmec reach (`beam`): on a beam, along it to its end on your side;
	# a goal past one's far end, to its near end first.
	var beam := _beam_way(goal)
	if not beam.is_empty():
		_skirt_t = 0.0
		var to_b := Vector2(beam.aim.x-position.x,beam.aim.z-position.z)
		if to_b.length() > 0.3: _heading = PilotMotor.facing_of(to_b.normalized())
	var runs := _runs()
	var turn := float(knobs.turn)*float(knobs.chase_turn)
	# `run_up`: the faster he goes, the slower he turns.
	if runs: turn = lerpf(turn,float(knobs.run_turn),run_k)
	var off := angle_difference(facing,_heading)
	# Olmec round 1: a big turn plants first (braked, not swung round at
	# speed), then steps round, and only then strides on. (`run_up`: at
	# speed he swings round wider, up to RUN_WIDE, before he plants.)
	var big := absf(off) > (lerpf(CHASE_TURN,RUN_WIDE,run_k) if runs else CHASE_TURN) or look.steps.busy()
	var was := facing
	if not big or Vector2(vel.x,vel.z).length() < 0.3: facing = wrapf(facing+clampf(off,-turn*delta,turn*delta),-PI,PI)
	var turned := absf(angle_difference(was,facing))
	# Olmec tune (`run_soft`): only a real turn (his facing swung past
	# about `run_soft` rad over RUN_WINDOW s) costs, in proportion.
	var soft := float(knobs.get("run_soft",0.0)) if runs else 0.0
	var real_turn := _turn_real(soft) if soft > 0.0 else 0.0
	if runs and soft > 0.0: run_k = maxf(run_k-turned*real_turn*float(knobs.run_turn_cost),0.0)
	elif runs: run_k = maxf(run_k-maxf(turned-RUN_EASY*delta,0.0)*float(knobs.run_turn_cost),0.0)
	if big:
		# His weight carries him on: a planted run skids (RUN_SKID).
		_brake(delta,lerpf(1.0,RUN_SKID,run_k) if runs else 1.0)
		if runs: _run_hold()
		return
	var fwd := _forward3()
	# On a beam its crest is his floor on to its end (its slope reads as
	# an edge, its rise as a wall, to his rays).
	var walking_beam: bool = not beam.is_empty() and bool(beam.on)
	var wall: Dictionary = {} if walking_beam else _wall_along(fwd,length*0.5+float(knobs.look),true)
	# Olmec routes (`plan_chase`): his route's places have room for his
	# footprint; a wall at his shoulder only (a corner, the side of a knoll
	# along whose foot he walks) his bulk is eased off, not stopped by.
	if not wall.is_empty() and wall.get("side",false) and _plans() and state == "chase": wall = {}
	# On a walk leg the graph says his footprint walks on: a face his rays
	# meet (a bump at his knee, a slope's foot) is walked into, his bulk
	# eased along it; held there (pinned), the leg fails.
	if not wall.is_empty() and _plans() and state == "chase" and _rim_goal == Vector3.INF and _pc_on_walk() and not wall.get("ceiling",false): wall = {}
	var ahead := clampf(to.length()+0.3,0.6,length*0.5+float(knobs.look))
	var edge: bool = not walking_beam and _floor(position+fwd*ahead,float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF and not _climb_walk_floor(fwd,ahead)
	# Olmec routes (`plan_chase`): on his route, a wall or an edge off his
	# facing while the way to his leg is clear (turning onto it on a narrow
	# terrace) is no wall and no edge: he stops and turns onto his way.
	if (edge or not wall.is_empty()) and _plans() and state == "chase" and absf(off) > 0.05:
		var hd := _way3(_heading)
		if _wall_along(hd,length*0.5+float(knobs.look),true).is_empty() and _floor(position+hd*ahead,float(knobs.step)*STAIR,float(knobs.step)*2.0) != -INF:
			_brake(delta)
			facing = wrapf(facing+clampf(off,-turn*delta,turn*delta),-PI,PI)
			if runs: _run_hold()
			return
	if not wall.is_empty():
		_hunt_wall(wall,goal)
		return
	if edge:
		_hunt_edge(fwd,goal)
		return
	var aligned := clampf(cos(angle_difference(facing,_heading)),0.0,1.0)
	# (`run_soft`: a few degrees off his way keep his speed.)
	if soft > 0.0: aligned = clampf(cos(maxf(absf(angle_difference(facing,_heading))-RUN_FREE_OFF,0.0)),0.0,1.0)
	var want := PilotMotor.forward(facing)*speed*aligned*aligned
	var flat := Vector2(vel.x,vel.z).move_toward(want,float(knobs.accel)*delta)
	vel.x = flat.x
	vel.z = flat.y
	if runs: _run_build(delta,off if (turned <= RUN_EASY*delta if soft <= 0.0 else real_turn < 0.01) else PI,fwd)
	if _pinned(delta,flat.length()):
		# His bulk walks into what his rays don't see (a ruin's arch, its
		# overhang): a wall all the same.
		_hunt_wall({"position":position+fwd*(length*0.5),"normal":-fwd,"side":true},goal)

## `climb_to`: a wall stare's earliest next (s, his clock).
var _wall_stare_next := 0.0

## A wall in the way of the hunt: climbed if its goal is up over its feet
## (or there is no way round), else skirted.
func _hunt_wall(hit: Dictionary, goal: Vector3) -> void:
	vel.x = 0.0
	vel.z = 0.0
	# Cover in the way to where it lost him: it looks over it first.
	# (Relentless, he knows where you are: no looking over, on at it.)
	if state == "chase" and not sight.seeing() and not _relentless() and _scope_try("chase"): return
	# Olmec climb (`climb_to`): on his walk to a climb, its face met (or a
	# wall met by his stand): he's there.
	if _climb_walk_met(hit): return
	# Olmec routes (`plan_chase`): a wall his walk meets is his route's to
	# say (its next leg's climb, else the leg failed); masonry he smashes.
	if _plans() and state == "chase":
		if _breach_try(hit,goal): return
		_pc_blocked("wall",hit)
		return
	var top := _climbable(hit)
	if top != INF and goal.y > position.y+float(knobs.step)*2.0:
		_start_climb(hit)
		return
	# Olmec climb (`climb_to`): you over a wall he can't climb (too tall, an
	# overhang, its underside): he stares and plans, along its foot.
	if state == "chase" and _stares() and _climbs_up(goal) and _clock >= _wall_stare_next:
		_wall_stare_next = _clock+float(knobs.stare_replan)
		_stare_start()
		return
	# Olmec threat round 1: masonry in his way, you past it about his
	# level: he smashes through it (`breach`).
	if state == "chase" and _breach_try(hit,goal): return
	# Olmec reach: a ruin on the rim between him and you below: off the
	# rim beside it (`down_to`), not round it and back for good.
	if _down_to(goal): return
	# City breaks round 2: a wall past his climb, him beyond it (through a
	# gate he broke open): a route to him, as at an edge (`chase_routes`).
	if top == INF and _chase_plan(goal): return
	var way := _skirt(goal,true)
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
	# Olmec routes (`plan_chase`): an edge his walk meets is his route's.
	if _plans() and state == "chase":
		_pc_blocked("edge")
		return
	var land := _landing(fwd)
	# Olmec ledge (`ledge_stare`): no leap straight on, he stares and plans.
	if _stares() and state == "chase" and (land.is_empty() or not (land.kind == "jump" or goal.y < position.y-float(knobs.step))):
		if _rim_goal != Vector3.INF and Vector2(_rim_goal.x-position.x,_rim_goal.z-position.z).length() < RIM_AT*2.0: _rim_arrive()
		else: _stare_start()
		return
	# Olmec reach (`edge_fan`): none straight on, a leap a little either
	# side (and the leap at a wall below, after).
	if float(knobs.edge_fan) > 0.5 and land.is_empty():
		for off: float in EDGE_FAN:
			land = _landing(_way3(wrapf(facing+off,-PI,PI)))
			if not land.is_empty(): break
	if not land.is_empty() and (land.kind == "jump" or goal.y < position.y-float(knobs.step)):
		_leap_to = land.at
		leap_kind = land.kind
		_go("windup")
		field.sound(&"body_windup",position)
		return
	if _down_to(goal): return
	if _wall_leap(fwd,goal): return
	# `edge_fan`: off main's east rim the leap at the east islet's face lay
	# 0.4 rad off his way to you, found only by chance mid-turn, after 12 s
	# of skirts along the rim.
	if float(knobs.edge_fan) > 0.5:
		for off: float in EDGE_FAN:
			if _wall_leap(_way3(wrapf(facing+off,-PI,PI)),goal): return
	if _chase_plan(goal): return
	var way := _skirt(goal)
	if way != INF:
		_skirt_way = way
		_skirt_t = SKIRT_FOR
		return
	_stuck()

# --- Olmec ledge (`ledge_stare`, `cliff_leap`) ------------------------------------------------
# At a rim with no leap straight on, he plants and stares at you
# ("stare"): his body turned to you once, his head's gaze on you, and from
# that stand he works out his way (`_stare_plan`, spread over frames): a
# leap or drop a little either side, `down_to`'s floor below, a face
# across the gap (`leap_catch`), a stand along the rim he walks to and
# goes from, and (`cliff_leap`) a cliff face on land nearer you, leapt at,
# caught and climbed. Then he turns once to it and goes. You moving while
# he stares, he plans again, still facing you. No way at all: he holds the
# stare and looks again every `stare_replan` s, or when you move.

## You moved this far (m) since his plan: he plans again.
const STARE_MOVED := 3.0
## The commit turn: done within this (rad), or after this long (s).
const STARE_AIM := 0.2
const STARE_TURN_MOST := 2.5
## The plan's budget a frame (us).
const STARE_US := 2500
## The ways tried round yours (rad), from his stand and from a rim stand.
const STARE_FAN := [0.0,0.35,-0.35,0.7,-0.7,1.1,-1.1]
const STAND_FAN := [0.0,0.35,-0.35]
## Rim stands looked at: ways round him, how far (m), the most tried.
const STAND_WAYS := 16
const STAND_RADII := [3.0,6.0,9.0,13.0,18.0]
const STAND_MOST := 8
## A plan's way scored by how far it leaves him from you (m), plus these
## (m) by its kind, plus half the walk to its stand.
const WAY_COST := {"jump":0.0,"drop":0.0,"wall":3.0,"cliff":8.0,"walk":2.0,"climb":4.0}
## A way must leave him this much (m) nearer you than he stands.
const WAY_GAIN := 1.5
## `cliff_leap`: the ways tried (rad off yours), his feet's heights at the
## face (Hh under his feet; under 0 over them), the least gain on you (m).
const CLIFF_FAN := [0.0,0.25,-0.25,0.5,-0.5,0.8,-0.8,1.15,-1.15,1.5,-1.5]
const CLIFF_DOWN := [-0.5,0.0,1.0,2.0,3.0,4.5,6.0]
const CLIFF_GAIN := 5.0
## The walk to a rim stand: given up after this long (s); there within (m).
const RIM_WALK_MOST := 15.0
const RIM_AT := 1.2

## Counted, for checks: stares begun, those that found no way, cliff leaps
## (and a line each: from, the face, the lip, how far it left him from you).
var stares := 0
var stare_nones := 0
var cliff_leaps := 0
var cliff_log: Array = []
var ledge_walks := 0
## The stare now: "plan" (working it out), "turn" (onto the way found),
## "none" (no way: staring, looking again soon).
var stare_why := ""
var _stare_jobs: Array = []
var _stare_best := {}
var _stare_for := Vector3.INF
var _stare_from := Vector3.ZERO
var _stare_way := 0.0
var _stare_t := 0.0
## The stare held facing you (s), and how near your way counts as facing.
var _stare_held := 0.0
const STARE_FACED := 0.3
## A rim stand he walks to (INF none), and the way he goes from it ({}:
## on to you on foot; {"kind":"stare"}: he stares there).
var _rim_goal := Vector3.INF
var _rim_then := {}
var _rim_t := 0.0

## The stares' outcomes, newest last (at most STARE_LOG), for checks.
const STARE_LOG := 40
var stare_log: Array = []
func _stare_note(line: String) -> void:
	stare_log.append("%.1f %s" % [_clock,line])
	if stare_log.size() > STARE_LOG: stare_log.pop_front()

func _stares() -> bool:
	return float(knobs.get("ledge_stare",0)) >= 0.5 and _chases()

## Where he means to go at you: you (seen), else where he last saw you.
func _stare_target() -> Vector3:
	var m: PilotMotor = field.motor
	if sight != null and sight.seeing(): return m.feet
	return seen_at if seen_at != Vector3.INF else m.feet

func _stare_start() -> void:
	vel.x = 0.0
	vel.z = 0.0
	_stare_held = 0.0
	_rim_goal = Vector3.INF
	_rim_then = {}
	_skirt_t = 0.0
	stares += 1
	_go("stare")
	_stare_plan(_stare_target())

## The plan's jobs from where he stands, toward `goal`.
var stare_plans := 0
func _stare_plan(goal: Vector3) -> void:
	stare_plans += 1
	stare_why = "plan"
	_stare_t = 0.0
	_stare_for = goal
	_stare_from = position
	_stare_best = {}
	_stare_jobs = []
	# Olmec routes (`plan_chase`): the beat's plan is the route search.
	if _plans():
		_pc_stare_plan(goal)
		return
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	var base := PilotMotor.facing_of(to.normalized()) if to.length() > 0.05 else facing
	for off: float in STARE_FAN: _stare_jobs.append(["land",wrapf(base+off,-PI,PI),Vector3.INF])
	_stare_jobs.append(["down",base,Vector3.INF])
	for off: float in STARE_FAN: _stare_jobs.append(["wall",wrapf(base+off,-PI,PI),Vector3.INF])
	# Olmec climb: you over him, a rim stand along his own level is no way
	# up (he walked rim to rim under you); the climbs' own stands below.
	if not _climbs_up(goal): _stare_jobs.append(["stands",base,Vector3.INF])
	if float(knobs.get("cliff_leap",0)) >= 0.5:
		for off: float in CLIFF_FAN: _stare_jobs.append(["cliff",wrapf(base+off,-PI,PI),Vector3.INF])
	# Olmec climb: you over him, the foot of the face looked along all round.
	_stare_sight = {}
	_up_none = false
	if _climbs_up(goal):
		for k in CLIMB_WAYS: _stare_jobs.append(["climb",wrapf(base+TAU*float(k)/CLIMB_WAYS,-PI,PI),Vector3.INF])
		_stare_jobs.append(["climbstands",base,Vector3.INF])
		if float(knobs.get("suck_up",0)) > 0.0: _stare_jobs.append(["sights",base,Vector3.INF])

## The way of kind `kind` along `way` from `from` (INF where he stands)
## toward `goal`: {kind, at, up, way, left, from, ...} or {}.
func _way_from(kind: String, way: float, from: Vector3, goal: Vector3) -> Dictionary:
	var was := position
	var was_f := facing
	if from != Vector3.INF: position = from
	facing = way
	var o := {}
	match kind:
		"land":
			var land := _landing(_way3(way))
			if not land.is_empty() and (land.kind == "jump" or goal.y < position.y-float(knobs.step)):
				o = {"kind":land.kind,"at":land.at,"up":-1.0}
		"down":
			var dn := _down_find(goal)
			if not dn.is_empty(): o = {"kind":"drop","at":dn.at,"up":dn.up}
		"wall":
			var w := _wall_leap_find(_way3(way),goal)
			if not w.is_empty(): o = {"kind":"wall","at":w.to,"up":-1.0,"face":w.face,"lip":w.lip}
		"cliff":
			var c := _cliff_find(way,goal)
			if not c.is_empty(): o = {"kind":"cliff","at":c.to,"up":-1.0,"face":c.face,"lip":c.lip}
		"walk":
			if _walk_on(goal): o = {"kind":"walk","at":position,"up":-1.0}
		"climb":
			var cl := _climb_find(way,goal)
			if not cl.is_empty(): o = {"kind":"climb","at":cl.to,"up":-1.0,"face":cl.face,"n":cl.n,"lip":cl.lip,"foot":cl.foot}
	if not o.is_empty():
		var at: Vector3 = o.get("lip",o.at)
		var dir := Vector2(o.at.x-position.x,o.at.z-position.z)
		o.way = PilotMotor.facing_of(dir.normalized()) if dir.length() > 0.05 else way
		o.left = at.distance_to(goal)
		o.from = from
	position = was
	facing = was_f
	return o

## From where he stands, on foot straight at `goal` for a good way
## (8 m, or all the way): floor every metre at about his level.
func _walk_on(goal: Vector3) -> bool:
	var to := Vector3(goal.x-position.x,0.0,goal.z-position.z)
	var far := minf(to.length(),8.0)
	if far < 2.0: return false
	return _walk_line(position,position+to.normalized()*far)

## Floor all along `a` to `b` (flat) at about his level, no step past his
## stair, his bulk clear.
func _walk_line(a: Vector3, b: Vector3) -> bool:
	var step := float(knobs.step)*STAIR
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	var n := maxi(1,ceili(flat.length()))
	var y := a.y
	for i in range(1,n+1):
		var p := a+flat*(float(i)/n)
		var g := _floor(Vector3(p.x,y,p.z),step,step*2.0)
		if g == -INF: return false
		y = g
	return _bulk_sweep(a+Vector3.UP*0.1,Vector3(b.x,y,b.z)+Vector3.UP*0.1) >= 1.0

## Rim stands round him nearer `goal`, walkable straight from here, the
## nearest it first: their jobs.
func _stand_jobs(goal: Vector3) -> Array:
	var now := position.distance_to(goal)
	var found: Array = []
	var step := float(knobs.step)*STAIR
	var r_rim := length*0.5+float(knobs.look)+0.5
	for k in STAND_WAYS:
		var a := TAU*float(k)/STAND_WAYS
		var dir := Vector3(cos(a),0.0,sin(a))
		for r: float in STAND_RADII:
			var p := position+dir*r
			var g := _floor(p,step*2.0,step*2.0)
			if g == -INF: break
			p.y = g
			var d := p.distance_to(goal)
			if d >= now-WAY_GAIN: continue
			# A rim stand: no floor his reach off it some way round.
			var rim := false
			for j in 8:
				var b := TAU*float(j)/8.0
				if _floor(p+Vector3(cos(b),0.0,sin(b))*r_rim,step,step*2.0) == -INF:
					rim = true
					break
			if not rim: continue
			found.append([d,p,r])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var jobs: Array = []
	var n := 0
	for f: Array in found:
		if n >= STAND_MOST: break
		var p: Vector3 = f[1]
		if not _walk_line(position,p): continue
		n += 1
		var to := Vector2(goal.x-p.x,goal.z-p.z)
		var base := PilotMotor.facing_of(to.normalized()) if to.length() > 0.05 else facing
		jobs.append(["walk",base,p])
		for off: float in STAND_FAN: jobs.append(["land",wrapf(base+off,-PI,PI),p])
		jobs.append(["down",base,p])
		for off: float in STAND_FAN: jobs.append(["wall",wrapf(base+off,-PI,PI),p])
	return jobs

## The plan's jobs worked through, STARE_US a frame; the best way kept.
func _stare_work() -> void:
	var t0 := Time.get_ticks_usec()
	var now := position.distance_to(_stare_for)
	while not _stare_jobs.is_empty() and Time.get_ticks_usec()-t0 < STARE_US:
		var job: Array = _stare_jobs.pop_front()
		if job[0] == "stands":
			_stare_jobs.append_array(_stand_jobs(_stare_for))
			continue
		if job[0] == "sights":
			_sight_find(_stare_for)
			continue
		if job[0] == "climbstands":
			_stare_jobs.append_array(_climb_stand_jobs(_stare_for))
			continue
		var o := _way_from(job[0],job[1],job[2],_stare_for)
		if o.is_empty(): continue
		var walk := 0.0 if job[2] == Vector3.INF else position.distance_to(job[2])
		# A climb's walk is along the foot to where he climbs.
		if o.kind == "climb": walk = (position.distance_to(job[2])+job[2].distance_to(o.at)) if job[2] != Vector3.INF else position.distance_to(o.at)
		o.score = float(o.left)+float(WAY_COST.get(o.kind,0.0))+walk*0.5
		if float(o.left) >= now-WAY_GAIN: continue
		if _stare_best.is_empty() or float(o.score) < float(_stare_best.score): _stare_best = o

## Staring at you from the rim, working out his way, then turning once
## onto it and going.
func _stare(delta: float) -> void:
	_brake(delta)
	_stare_t += delta
	var m: PilotMotor = field.motor
	# Relentless, you out of his sight a while: he takes your scent (as his
	# seek does) and stares and plans at where you are now.
	if _relentless() and not sight.seeing() and seen_t > float(knobs.hunt_search):
		seen_at = m.feet
		seen_t = 0.0
		scents += 1
	var target := _stare_target()
	var to := target-position
	if sight.seeing() and _attack_with(m,Vector2(to.x,to.z).length(),to.y,delta): return
	# Olmec climb (`suck_up`): no way up, you in plain view up there.
	if _up_none and not sight.seeing() and _sees_from(position,m.feet) and _attack_with(m,Vector2(to.x,to.z).length(),to.y,delta): return
	match stare_why:
		"plan":
			if target.distance_to(_stare_for) > STARE_MOVED:
				_stare_plan(target)
				return
			var planner := _plans()
			if planner: _pc_step()
			else: _stare_work()
			# The stare's beat runs once he has come round to you (his stood
			# steps done), so the turn onto his way never cuts across it.
			var to_you := Vector2(to.x,to.z)
			if to_you.length() < 0.1 or (absf(angle_difference(facing,PilotMotor.facing_of(to_you.normalized()))) < STARE_FACED and not look.steps.busy()): _stare_held += delta
			var working := _pc_search != null if planner else not _stare_jobs.is_empty()
			if working or (_stare_held < float(knobs.stare_hold) and state_t < float(knobs.stare_hold)+STARE_TURN_MOST): return
			if planner:
				_pc_decide()
				return
			if _stare_best.is_empty():
				# Olmec climb (`suck_up`): no way up to you, he sees you
				# from here or walks to where he would (and pulls you down).
				if _climbs_up(_stare_for) and float(knobs.get("suck_up",0)) > 0.0: _up_none = true
				# No climb and no pull: the planner's route up, if it has one.
				if _climbs_up(_stare_for) and (not _up_none or (_stare_sight.is_empty() and not _sees_from(position,_stare_for))):
					_go("chase")
					_route_next = true
					var routed := _after_try(_stare_for if sight.seeing() else Vector3.INF)
					_route_next = false
					if routed:
						_stare_note("no climb at %s; a route up" % position.round())
						return
					_go("stare")
				if not _stare_sight.is_empty() and Vector2(_stare_sight.at.x-position.x,_stare_sight.at.z-position.z).length() > RIM_AT:
					_stare_note("no way up; to see you from %s" % (_stare_sight.at as Vector3).round())
					_stare_best = _stare_sight
					var to_s := Vector2(_stare_sight.at.x-position.x,_stare_sight.at.z-position.z)
					_stare_way = PilotMotor.facing_of(to_s.normalized())
					stare_why = "turn"
					_stare_t = 0.0
					return
				stare_why = "none"
				stare_nones += 1
				_stare_t = 0.0
				_stare_note("none at %s, you %s" % [position.round(),_stare_for.round()])
				return
			_stare_note("%s%s at %s, left %.0f m" % [_stare_best.kind," from stand %s" % (_stare_best.from as Vector3).round() if _stare_best.from != Vector3.INF else "",(_stare_best.at as Vector3).round(),float(_stare_best.left)])
			var to_go: Vector3 = _stare_best.from if _stare_best.from != Vector3.INF else _stare_best.at
			var dir := Vector2(to_go.x-position.x,to_go.z-position.z)
			_stare_way = PilotMotor.facing_of(dir.normalized()) if dir.length() > 0.3 else float(_stare_best.way)
			stare_why = "turn"
			_stare_t = 0.0
		"none":
			if target.distance_to(_stare_for) > STARE_MOVED or _stare_t >= float(knobs.stare_replan): _stare_plan(target)
		"turn":
			if absf(angle_difference(facing,_stare_way)) > STARE_AIM and _stare_t < STARE_TURN_MOST: return
			_stare_go(_stare_best)

## The way found taken: a walk to its stand, or the leap from here.
func _stare_go(o: Dictionary) -> void:
	# Olmec climb: along the foot to where he climbs (or up it from here),
	# or (`suck_up`) to where he sees you, to stare there.
	if o.kind in ["climb","sight"]:
		var first: Vector3 = o.from if o.from != Vector3.INF else o.at
		if Vector2(first.x-position.x,first.z-position.z).length() > RIM_AT:
			_rim_goal = first
			_rim_then = o if o.kind == "climb" else {"kind":"stare"}
			_rim_t = 0.0
			_go("chase")
			return
		if o.kind == "climb":
			# Turned to the face: in to it, and up.
			var inn := o.duplicate()
			inn["in"] = true
			_rim_goal = o.foot
			_rim_then = inn
			_rim_t = 0.0
			_go("chase")
			return
		_stare_start()
		return
	if o.from != Vector3.INF:
		_rim_goal = o.from
		_rim_then = {} if o.kind == "walk" else o
		_rim_t = 0.0
		_go("chase")
		return
	if o.kind == "walk":
		_go("chase")
		return
	_leap_at(o)

func _leap_at(o: Dictionary) -> void:
	_leap_to = o.at
	leap_kind = "drop" if o.kind == "drop" else "jump"
	match str(o.kind):
		"drop": down_tos += 1
		"wall": wall_leaps += 1
		"cliff":
			cliff_leaps += 1
			cliff_log.append("%s -> face %s lip %s, %.0f m from you" % [position.round(),(o.face as Vector3).round(),(o.lip as Vector3).round(),float(o.left)])
	_go("windup")
	_drop_up = float(o.up)
	field.sound(&"body_windup",position)

## On his walk to a rim stand (`_chase` calls it first): there, its way
## taken from where he really stands (looked at again); walked too long,
## a stare. True while it has him.
func _rim_walk(delta: float) -> bool:
	if _rim_goal == Vector3.INF: return false
	_rim_t += delta
	var m: PilotMotor = field.motor
	if sight.seeing():
		var to := m.feet-position
		if _attack_with(m,Vector2(to.x,to.z).length(),to.y,delta):
			_rim_goal = Vector3.INF
			return true
	var left := Vector2(_rim_goal.x-position.x,_rim_goal.z-position.z).length()
	if left <= RIM_AT:
		_rim_arrive()
		return true
	if _rim_t > RIM_WALK_MOST:
		_stare_start()
		return true
	_pursue(delta,_rim_goal,_chase_pace())
	return true

func _rim_arrive() -> void:
	_rim_goal = Vector3.INF
	var then := _rim_then
	_rim_then = {}
	vel.x = 0.0
	vel.z = 0.0
	if then.is_empty(): return
	if str(then.kind) == "stare":
		_stare_start()
		return
	if str(then.kind) == "climb":
		# At the stand he looked from: on along the foot to it.
		if Vector2(then.at.x-position.x,then.at.z-position.z).length() > RIM_AT*1.5:
			_rim_goal = then.at
			_rim_then = then
			_rim_t = 0.0
			_go("chase")
			return
		# Walked in to its foot: up it.
		if then.get("in",false):
			var c_in := _climb_here(then)
			if c_in.is_empty():
				_stare_note("climb gone at %s" % position.round())
				_stare_start()
				return
			_climb_up(c_in)
			return
		# At the stand off its foot: turned to the face (the stare's turn).
		var c := _climb_here(then,true)
		if c.is_empty():
			_stare_note("climb gone at %s" % position.round())
			_stare_start()
			return
		_go("stare")
		stares += 1
		_stare_best = c
		_stare_for = _stare_target()
		_stare_way = float(c.way)
		stare_why = "turn"
		_stare_t = 0.0
		return
	var goal := _stare_target()
	var o := _way_from("land" if then.kind in ["jump"] else ("down" if then.kind == "drop" else str(then.kind)),float(then.way),Vector3.INF,goal)
	if o.is_empty() and then.kind == "drop": o = _way_from("land",float(then.way),Vector3.INF,goal)
	if o.is_empty():
		_stare_start()
		return
	# Turned onto it (he walked there facing the stand), then off.
	_go("stare")
	stares += 1
	_stare_best = o
	_stare_for = goal
	_stare_way = float(o.way)
	stare_why = "turn"
	_stare_t = 0.0

## `cliff_leap`: a cliff face across the gap along `way`, within
## `cliff_gap` Hh off flat, met with his feet from half a head height over
## his own down to `cliff_deep` Hh under (CLIFF_DOWN), its lip within
## `climb_max` over where he meets it, clean (no shelf he'd haul out onto
## short of the lip), with room over the lip and past it, and that lip at
## least CLIFF_GAIN m nearer `goal` than he stands; the arc there meeting
## that face first. The nearest you of those: {to, face, lip} or {}.
func _cliff_find(way: float, goal: Vector3, coarse := 1.0) -> Dictionary:
	var dir := _way3(way)
	var step := float(knobs.step)
	var rim := -1.0
	var d := 0.0
	while d <= length*0.5+float(knobs.look)+3.0:
		if _floor(position+dir*d,step,step*2.0) == -INF:
			rim = d
			break
		d += 0.25
	if rim < 0.0: return {}
	var most := float(knobs.cliff_gap)*hh
	# `goal` INF (the place graph's build): any face, the nearest.
	var any := goal == Vector3.INF
	var now := INF if any else position.distance_to(goal)
	var best := {}
	var best_d := INF
	for down: float in CLIFF_DOWN:
		if down > float(knobs.cliff_deep): break
		var feet_y := position.y-down*hh
		var hit := {}
		for up: float in [neck_h*0.55,step+0.1]:
			var from := Vector3(position.x,feet_y+up,position.z)+dir*(rim+0.3)
			var h := _cast(from,from+dir*maxf(most-rim,0.5))
			var hn := (h.normal as Vector3) if not h.is_empty() else Vector3.UP
			if h.is_empty() or absf(hn.y) > 0.5 or Vector3(hn.x,0.0,hn.z).normalized().dot(dir) > -0.4:
				hit = {}
				break
			if hit.is_empty(): hit = h
		if hit.is_empty(): continue
		var n := hit.normal as Vector3
		n = Vector3(n.x,0.0,n.z).normalized()
		var face := hit.position as Vector3
		var past := face-n*float(knobs.lip_in)
		var top := _cast(Vector3(past.x,feet_y+float(knobs.climb_max),past.z),Vector3(past.x,feet_y+step,past.z))
		if top.is_empty() or (top.normal as Vector3).y < 0.6: continue
		var lip := top.position as Vector3
		var left := Vector2(face.x-position.x,face.z-position.z).length() if any else lip.distance_to(goal)
		if (not any and left > now-CLIFF_GAIN) or left >= best_d: continue
		if not _cast(lip+Vector3.UP*0.1,lip+Vector3.UP*neck_h*0.5).is_empty(): continue
		var on := lip-n*(length*0.5+1.0)
		var g := _floor(on,1.0,1.5)
		if g == -INF or not _room_at(Vector3(on.x,g,on.z)): continue
		if not _face_clean_at(face,n,feet_y,lip.y): continue
		var to := Vector3(face.x,feet_y,face.z)+dir*0.6
		if not _wall_arc(to,face,coarse) or not _catch_ok(to,face,coarse): continue
		best = {"to":to,"face":face,"lip":lip,"n":n}
		best_d = left
	return best

## `climb_to`: you over him, the face along `way` from where he stands
## (a ray at his chest, out to `climb_look` Hh: looked along the foot of
## the face, not only straight at it) that he can climb from its foot:
## the face meets his floor (his knee ray finds it as near as his chest's,
## no undercut), its foot walkable straight from here, its lip within his
## climb (`climb_max` over his feet, plus his mantle's reach), no shelf
## short of the lip (`_face_clean_at`), his bulk hung on it clear of the
## rock all the way up (no overhang, no bulge past his `climb_clear`), and
## no roof over the lip, room past it, and that lip at least CLIMB_GAIN m
## nearer `goal` than he stands, about your level or under it.
## {to (where he stands to climb), face, n (out of it), lip} or {}.
## `climb_why` says why the last face looked at was passed over.
const CLIMB_GAIN := 3.0
## Where he turns to the face: this far (m) past his half-breadth off it.
const CLIMB_OFF := 0.6
var climb_why := ""
func _climb_find(way: float, goal: Vector3, look := -1.0) -> Dictionary:
	var dir := _way3(way)
	var step := float(knobs.step)
	var chest := neck_h*0.55
	var far := float(knobs.get("climb_look",8.0))*hh if look < 0.0 else look
	var from := position+Vector3.UP*chest
	var h := _cast(from,from+dir*far)
	# `plan_chase`'s graph (`look` given): a face under his chest (a low
	# wall, a ledge over his stair) met at his knee.
	if h.is_empty() and look >= 0.0:
		from = position+Vector3.UP*(step+0.6)
		h = _cast(from,from+dir*far)
	if h.is_empty():
		climb_why = "no face"
		return {}
	var n := h.normal as Vector3
	if absf(n.y) > 0.5:
		climb_why = "not steep"
		return {}
	n = Vector3(n.x,0.0,n.z).normalized()
	# Met along the foot too (a glancing ray), not from behind.
	if n.dot(dir) > -0.15:
		climb_why = "back of it"
		return {}
	var face := h.position as Vector3
	# Its foot at his floor: at his knee the face is there too, no nearer
	# his chest's (an undercut) and not much farther (a step out, a slope).
	var knee := Vector3(face.x,position.y+step+0.1,face.z)+n*1.5
	var kh := _cast(knee,knee-n*3.0)
	if kh.is_empty() or absf((kh.normal as Vector3).y) > 0.6:
		climb_why = "no foot"
		return {}
	var off_k := (kh.position as Vector3)-face
	off_k.y = 0.0
	if off_k.dot(n) > 0.6 or off_k.dot(n) < -1.5:
		climb_why = "foot off the face"
		return {}
	# He stands off it by his shoulders' breadth (walking along its foot his
	# arms would be in it), turns to it there and walks in to it.
	var foot := face+n*(length*0.5+float(knobs.standoff)+0.4)
	var stand := face+n*(hh*BULK_W+CLIMB_OFF)
	var g := _floor(Vector3(stand.x,position.y,stand.z),step*STAIR,step*2.0)
	if g == -INF:
		climb_why = "no floor at its foot"
		return {}
	stand = Vector3(stand.x,g,stand.z)
	var fg := _floor(Vector3(foot.x,g,foot.z),step*STAIR,step*2.0)
	if fg == -INF:
		climb_why = "no floor at its foot"
		return {}
	if Vector2(stand.x-position.x,stand.z-position.z).length() > RIM_AT and not _walk_line(position,stand):
		climb_why = "no walk to its foot"
		return {}
	# The lip: down past the face from over his climb and mantle.
	var past := face-n*float(knobs.lip_in)
	var top := _cast(Vector3(past.x,g+float(knobs.climb_max)+chest,past.z),Vector3(past.x,g+step*STAIR,past.z))
	if top.is_empty() or (top.normal as Vector3).y < 0.6:
		climb_why = "no lip"
		return {}
	var lip := top.position as Vector3
	# A shelf short of that top is where his climb hauls out: that's this
	# climb's lip (the face over it is the next climb).
	var shelf := _face_shelf(face,n,g,lip.y)
	if shelf != Vector3.INF: lip = shelf
	if lip.y < g+step*STAIR*1.5:
		climb_why = "a step"
		return {}
	if goal != Vector3.INF and lip.y > goal.y+step*STAIR:
		climb_why = "over you"
		return {}
	if goal != Vector3.INF and lip.distance_to(goal) > position.distance_to(goal)-CLIMB_GAIN:
		climb_why = "no gain"
		return {}
	if not _cast(lip+Vector3.UP*0.1,lip+Vector3.UP*neck_h*0.5).is_empty():
		climb_why = "roof over the lip"
		return {}
	var on := lip-n*(length*0.5+1.0)
	var og := _floor(on,1.0,1.5)
	if og == -INF or not _room_at(Vector3(on.x,og,on.z)):
		climb_why = "no room past the lip"
		return {}
	if not _climb_column(face,n,g,lip.y):
		return {}
	climb_why = ""
	return {"to":stand,"face":face,"n":n,"lip":lip,"foot":Vector3(foot.x,fg,foot.z)}

## `plan_chase` (scripts/enemies/olmec_route_graph.gd): the climb along `way`
## within `far` m, as `_climb_find` checks it, with no goal (any lip).
func _climb_at(way: float, far: float) -> Dictionary:
	return _climb_find(way,Vector3.INF,far)

## `climb_to`: his bulk hung on the face at `face` (`n` out of it), from his
## feet at `from_y` up to where he hauls over `lip_y`, clear of the rock
## (a box his breadth x depth x torso every metre, held a little off the
## face as `climb_clear` holds him), and the face before his chest all
## the way (a face leaning far back loses his hands).
func _climb_column(face: Vector3, n: Vector3, from_y: float, lip_y: float) -> bool:
	var space: PhysicsDirectSpaceState3D = field.study.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	var tall := neck_h*0.6
	box.size = Vector3(width*0.85,tall,length*0.8)
	q.shape = box
	q.collision_mask = _land_mask()
	q.exclude = _skip()
	var basis := Basis(Vector3.UP,PilotMotor.facing_of(-Vector2(n.x,n.z)))
	var c := face+n*(length*0.5+float(knobs.standoff)+0.3)
	var chest := neck_h*0.55
	var reach := neck_h+arm_l*0.75
	var hold := length*0.5+float(knobs.standoff)+1.5+(hh if float(knobs.climb_clear) > 0.5 else 0.0)
	var top := lip_y-chest
	var y := from_y+float(knobs.step)*STAIR+0.2
	while y <= top:
		q.transform = Transform3D(basis,Vector3(c.x,y+tall*0.5,c.z))
		if not space.intersect_shape(q,1).is_empty():
			climb_why = "overhang %.0f m up" % (y-from_y)
			return false
		if y+reach < lip_y:
			var at := Vector3(c.x,y+chest,c.z)
			var fh := _cast(at,at-n*hold)
			if fh.is_empty() or absf((fh.normal as Vector3).y) >= 0.7:
				climb_why = "face lost %.0f m up" % (y-from_y)
				return false
		y += 1.0
	return true

## `climb_to`: the ways the plan looks along for a face to climb (all
## round him), and (`suck_up`) the best stand he'd see you from ({} none or
## here), and whether this plan found no way up to you (the pull's go).
const CLIMB_WAYS := 32
var _stare_sight := {}
var _up_none := false
## Climbs and pulls down begun (counted, for checks).
var climb_ups := 0
var sucks_up := 0
## A `suck_up` pull under way (his mouth's line to you keeps it going).
var _suck_up_now := false
## Its brace's share of the suck's own (the windup clip's crouch).
const SUCK_UP_BRACE := 0.3

func _climbs_to() -> bool:
	return float(knobs.get("climb_to",0)) >= 0.5 and _chases()

## You over him: a climb (or the pull) is his way, not a leap or a drop.
## (Over him: up past his stair and within `climb_look` Hh off flat; far off
## across a gap, his ledge ways go on as before.)
func _climbs_up(goal: Vector3) -> bool:
	if not _climbs_to() or goal.y <= position.y+float(knobs.step)*STAIR*1.5: return false
	return Vector2(goal.x-position.x,goal.z-position.z).length() <= float(knobs.get("climb_look",8.0))*hh

## `suck_up`: whether from `at` (his feet) his eye has a clear line to your
## chest within `suck_up` Hh.
func _sees_from(at: Vector3, goal: Vector3) -> bool:
	# His mouth there turned to you (his head sits out over his front), and
	# your chest (the head's own): a clear line between, as his pull needs.
	var worn: bool = head != null and is_instance_valid(head) and head.perch == self
	var off: Vector3 = (head.mouth() if worn else _eye())-position
	var to := Vector2(goal.x-at.x,goal.z-at.z)
	var flat := Vector2(off.x,off.z).length()
	var mouth := at+Vector3.UP*off.y+(Vector3(to.x,0.0,to.y).normalized()*flat if to.length() > 0.1 else Vector3.ZERO)
	if mouth.distance_to(goal) > float(knobs.suck_up)*hh: return false
	var chest := goal+Vector3.UP*float(field.study.ground.head_top)*0.55
	return _cast(mouth,chest).is_empty()

## `suck_up`: no way up, the nearest stand within reach (walkable straight
## from here, as the rim stands) he'd see you from; here first.
func _sight_find(goal: Vector3) -> void:
	_stare_sight = {}
	if _sees_from(position,goal): return
	var step := float(knobs.step)*STAIR
	var best_d := INF
	for k in STAND_WAYS:
		var a := TAU*float(k)/STAND_WAYS
		var dir := Vector3(cos(a),0.0,sin(a))
		for r: float in STAND_RADII:
			if r >= best_d: break
			var p := position+dir*r
			var g := _floor(p,step*2.0,step*2.0)
			if g == -INF: break
			p.y = g
			# Seen from it and from where his walk stops short of it too.
			if not _sees_from(p,goal) or not _sees_from(p-dir*RIM_AT,goal): continue
			if not _walk_line(position,p): continue
			best_d = r
			var to := Vector2(goal.x-p.x,goal.z-p.z)
			_stare_sight = {"kind":"sight","at":p,"up":-1.0,"way":PilotMotor.facing_of(to.normalized()) if to.length() > 0.05 else facing,"left":p.distance_to(goal),"from":Vector3.INF,"score":0.0}
			break

## `climb_to`: stands round him (walkable straight, about his level, the
## nearest you first, CLIMB_STANDS at most) to look along the face's foot
## from too (a foot he can't walk straight to from here): their jobs.
const CLIMB_STANDS := 6
const CLIMB_STAND_FAN := [0.0,0.4,-0.4,0.8,-0.8,1.2,-1.2,1.6,-1.6]
func _climb_stand_jobs(goal: Vector3) -> Array:
	var step := float(knobs.step)*STAIR
	var found: Array = []
	for k in STAND_WAYS:
		var a := TAU*float(k)/STAND_WAYS
		var dir := Vector3(cos(a),0.0,sin(a))
		for r: float in STAND_RADII:
			var p := position+dir*r
			var g := _floor(p,step*2.0,step*2.0)
			if g == -INF: break
			if absf(g-position.y) > step*2.0: break
			p.y = g
			found.append([p.distance_to(goal),p])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var jobs: Array = []
	var n := 0
	for f: Array in found:
		if n >= CLIMB_STANDS: break
		var p: Vector3 = f[1]
		if not _walk_line(position,p): continue
		n += 1
		var to := Vector2(goal.x-p.x,goal.z-p.z)
		var base := PilotMotor.facing_of(to.normalized()) if to.length() > 0.05 else facing
		for off: float in CLIMB_STAND_FAN: jobs.append(["climb",wrapf(base+off,-PI,PI),p])
	return jobs

## `climb_to`: at the foot of the climb `o`, the face before him (along
## `o.n` back in): the climb from here {kind, at, face, n, lip, way, from,
## left}, {} if the face isn't there.
func _climb_here(o: Dictionary, off := false) -> Dictionary:
	var n: Vector3 = o.n
	var chest := position+Vector3.UP*neck_h*0.55
	var h := _cast(chest,chest-n*(length*0.5+float(knobs.standoff)+2.5+(hh*BULK_W+CLIMB_OFF if off else 0.0)))
	if h.is_empty() or absf((h.normal as Vector3).y) > 0.5: return {}
	var hn := h.normal as Vector3
	hn = Vector3(hn.x,0.0,hn.z).normalized()
	return {"kind":"climb","at":position,"up":-1.0,"face":h.position,"n":hn,"lip":o.lip,"foot":(h.position as Vector3)+hn*(length*0.5+float(knobs.standoff)+0.4),"way":PilotMotor.facing_of(-Vector2(hn.x,hn.z)),"from":Vector3.INF,"left":o.get("left",0.0)}

## `climb_to`: on his walk to a climb's foot (a line found walkable), a
## floor ray lost in clutter (an aqueduct pier's faces) isn't an edge when
## the floor is there a little short of it and past it.
func _climb_walk_floor(fwd: Vector3, ahead: float) -> bool:
	if _rim_goal == Vector3.INF or str(_rim_then.get("kind","")) != "climb": return false
	var step := float(knobs.step)*STAIR
	for d: float in [ahead*0.5,ahead+0.6]:
		if _floor(position+fwd*d,step,float(knobs.step)*2.0) == -INF: return false
	return true

## `climb_to`: a wall met on his walk to a climb: the climb's own face
## (turned about as it, near its foot) is its foot reached; any wall met
## within CLIMB_MET m of the stand he walks to is that stand reached.
## True: he's there (`_rim_arrive`).
const CLIMB_MET := 3.0
func _climb_walk_met(hit: Dictionary) -> bool:
	if _rim_goal == Vector3.INF or str(_rim_then.get("kind","")) != "climb": return false
	var o: Dictionary = _rim_then
	var n := hit.normal as Vector3
	n = Vector3(n.x,0.0,n.z).normalized()
	var face: Vector3 = o.face
	var near_face := Vector2((hit.position as Vector3).x-face.x,(hit.position as Vector3).z-face.z).length() < CLIMB_MET+length
	if near_face and n.dot(o.n) > 0.7:
		_rim_goal = Vector3.INF
		_rim_then = {}
		vel.x = 0.0
		vel.z = 0.0
		if o.get("in",false):
			_climb_up({"face":hit.position,"n":n,"lip":o.lip})
			return true
		# Along its foot, at it short of his stand: he turns to it here.
		var c := _climb_here(o,true)
		if c.is_empty():
			_stare_start()
			return true
		_go("stare")
		stares += 1
		_stare_best = c
		_stare_for = _stare_target()
		_stare_way = float(c.way)
		stare_why = "turn"
		_stare_t = 0.0
		return true
	if Vector2(_rim_goal.x-position.x,_rim_goal.z-position.z).length() < CLIMB_MET:
		_rim_goal = position
		_rim_arrive()
		return true
	return false

## `climb_to`: up the face `o` from its foot (his climb and mantle).
func _climb_up(o: Dictionary) -> void:
	climb_ups += 1
	_stare_note("climb at %s to lip %s" % [position.round(),(o.lip as Vector3).round()])
	_start_climb({"position":o.face,"normal":o.n})

## Whether his climb up the face at `face` (`n` out of it) from his feet at
## `from_y` finds no top short of `lip_y`, as his climb looks for one:
## every half metre up, the face at his chest, a ray down past it from his
## reach (crag_reach.gd `_face_clean`, from his own build).
func _face_clean_at(face: Vector3, n: Vector3, from_y: float, lip_y: float) -> bool:
	return _face_shelf(face,n,from_y,lip_y) == Vector3.INF

## The first top short of `lip_y` his climb up that face would find (the
## shelf he'd haul out onto), INF none.
func _face_shelf(face: Vector3, n: Vector3, from_y: float, lip_y: float) -> Vector3:
	var reach := neck_h+arm_l*0.75
	var chest := neck_h*0.55
	var step := float(knobs.step)
	var f := face
	var y := from_y
	while y < lip_y-step:
		var c := Vector3(face.x,y+chest,face.z)
		var hit := _cast(c+n*4.0,c-n*4.0)
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.7: f = hit.position
		var past := Vector3(f.x,0.0,f.z)-n*0.8
		var top := _cast(Vector3(past.x,y+reach,past.z),Vector3(past.x,y+step,past.z))
		if not top.is_empty() and (top.normal as Vector3).y > 0.6 and (top.position as Vector3).y < lip_y-0.5: return top.position
		y += 0.5
	return Vector3.INF

## `cliff_leap`, a study's call when he makes no way to you: off to the rim
## that lies most your way within DIVE_FAR m (none within DIVE_SHUN of one
## in `shun`, none more than `worse` m farther from you than he stands), to
## stare and plan from there. Whether he goes.
func ledge_walk(toward: Vector3, shun: Array = [], worse := INF) -> bool:
	if not grounded or state not in ["chase","stare","seek"]: return false
	var picks: Array = []
	for k in DIVE_WAYS:
		var a := TAU*float(k)/DIVE_WAYS
		var way := Vector3(cos(a),0.0,sin(a))
		var last := Vector3.INF
		var d := length*0.5
		while d <= DIVE_FAR:
			var p := position+way*d
			var f := _floor(p,float(knobs.step)*STAIR,float(knobs.step)*2.0)
			if f == -INF:
				if last != Vector3.INF and last.distance_to(toward) <= position.distance_to(toward)+worse and not shun.any(func(q: Vector3) -> bool: return q.distance_to(last) < DIVE_SHUN):
					picks.append([last.distance_to(toward)+d*0.5,last])
				break
			if last != Vector3.INF and absf(f-last.y) > float(knobs.step)*STAIR*2.0: break
			last = Vector3(p.x,f,p.z)
			d += DIVE_FAR_STEP
	picks.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for pk: Array in picks:
		var p: Vector3 = pk[1]
		if p.distance_to(position) < 3.0: continue
		if not _walk_line(position,p): continue
		_rim_goal = p
		_rim_then = {"kind":"stare"}
		_rim_t = 0.0
		ledge_walks += 1
		_chase_drop()
		_skirt_t = 0.0
		if state != "chase": _go("chase")
		return true
	return false

## `beam`: off a beam's crest line (m, flat) and over or under it (m) he is
## still on it; how far on along it he aims (m); how near its end (m) he
## leaves it; how far from its near end he takes it.
const BEAM_SIDE := 1.6
const BEAM_UP := 2.5
const BEAM_DOWN := 1.0
const BEAM_AIM := 4.0
const BEAM_END := 2.5
const BEAM_TAKE := 60.0

## The beam he stands on: {a, b (its ends), t (0 to 1 along), len (flat)},
## {} none.
func _on_beam() -> Dictionary:
	if float(knobs.beam) < 0.5: return {}
	for be: Array in beams:
		var a: Vector3 = be[0]
		var b: Vector3 = be[1]
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var l := ab.length()
		if l < 1.0: continue
		var t := Vector2(position.x-a.x,position.z-a.z).dot(ab)/(l*l)
		if t < -BEAM_END/l or t > 1.0+BEAM_END/l: continue
		var tc := clampf(t,0.0,1.0)
		var p := a.lerp(b,tc)
		if Vector2(position.x-p.x,position.z-p.z).length() > BEAM_SIDE: continue
		if position.y > p.y+BEAM_UP or position.y < p.y-BEAM_DOWN: continue
		return {"a":a,"b":b,"t":t,"len":l}
	return {}

## The way a beam gives to `goal`: {aim (where he heads), on (walking it)},
## {} none (off one with none to take, or at its end on your side).
func _beam_way(goal: Vector3) -> Dictionary:
	if float(knobs.beam) < 0.5 or beams.is_empty(): return {}
	var on := _on_beam()
	if not on.is_empty():
		var a: Vector3 = on.a
		var b: Vector3 = on.b
		var l: float = on.len
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var tg := Vector2(goal.x-a.x,goal.z-a.z).dot(ab)/(l*l)
		var t: float = on.t
		# Your side of him along it: on to that end, off it near there (or
		# off it beside you, under it).
		var dir := 1.0 if tg > t else -1.0
		var stop := clampf(tg,0.0,1.0)
		if absf(stop-t)*l < BEAM_END: return {}
		var ta := clampf(t+dir*BEAM_AIM/l,0.0,1.0)
		if dir > 0.0: ta = minf(ta,stop)
		else: ta = maxf(ta,stop)
		# Past its end, the aim runs on off it (onto the turf it lies on).
		var aim := a.lerp(b,ta)
		if (dir > 0.0 and ta >= 1.0) or (dir < 0.0 and ta <= 0.0):
			aim += Vector3(ab.x,0.0,ab.y).normalized()*dir*BEAM_AIM
		return {"aim":aim,"on":true}
	# Off one: a beam whose far end lies your way, its near end at his
	# level and not far, the way over it not much longer than straight.
	var best := {}
	var best_d := INF
	var straight := Vector2(goal.x-position.x,goal.z-position.z).length()
	for be: Array in beams:
		for k in 2:
			var near: Vector3 = be[k]
			var far: Vector3 = be[1-k]
			if absf(near.y-position.y) > BEAM_UP*2.0: continue
			var dn := Vector2(near.x-position.x,near.z-position.z).length()
			if dn > BEAM_TAKE: continue
			var nf := Vector2(far.x-near.x,far.z-near.z)
			var l := nf.length()
			if l < 1.0: continue
			var tg := Vector2(goal.x-near.x,goal.z-near.z).dot(nf)/(l*l)
			if tg < 0.85: continue
			var via := dn+l+Vector2(goal.x-far.x,goal.z-far.z).length()
			if via > straight*1.3+15.0 or via >= best_d: continue
			best_d = via
			# Onto it along its line: from behind its near end while off its line.
			var into := Vector3(nf.x,0.0,nf.y)/l
			var back := near-into*BEAM_END*1.5
			var side := Vector2(position.x-near.x,position.z-near.z)
			var off_line := absf(side.dot(Vector2(-nf.y,nf.x)/l))
			best = {"aim":back if off_line > BEAM_SIDE and dn > BEAM_END else near+into*BEAM_AIM,"on":false}
	return best

## `edge_fan`: ways tried off his facing at an edge (rad).
const EDGE_FAN := [0.35,-0.35,0.7,-0.7]

## No way on: hunting, it looks about where it stands; going back, it roams.
func _stuck() -> void:
	if state == "chase": _seek_start()
	else:
		rest()
		_go("listen")

## `skirt_hold`: walking on, pushed back by his bulk with no ground made
## (PIN_FOR s, under PIN_GAIN m), he is pinned on something.
const PIN_FOR := 0.5
const PIN_GAIN := 0.4
var _pin_t := 0.0
var _pin_from := Vector3.INF
## Times he found himself pinned (for checks).
var pins := 0
func _pinned(delta: float, speed: float) -> bool:
	if float(knobs.skirt_hold) < 0.5 or speed < 0.5 or _clock-_pushed_at > 0.1:
		_pin_t = 0.0
		_pin_from = Vector3.INF
		return false
	if _pin_from == Vector3.INF or position.distance_to(_pin_from) > PIN_GAIN:
		_pin_from = position
		_pin_t = 0.0
		return false
	_pin_t += delta
	if _pin_t < PIN_FOR: return false
	_pin_t = 0.0
	_pin_from = Vector3.INF
	pins += 1
	return true

## A way off the way to `goal` with no wall near and floor ahead (the one
## nearest the goal's way), INF none.
func _skirt(goal: Vector3, wall := false) -> float:
	var to := Vector2(goal.x-position.x,goal.z-position.z)
	var base := PilotMotor.facing_of(to.normalized()) if to.length() > 0.05 else facing
	var sides := [1.0,-1.0]
	# `skirt_hold`: soon after a skirt, the same side first (round it, not
	# back and forth across its face).
	var hold := wall and float(knobs.skirt_hold) >= 0.5 and _skirt_side != 0.0 and _clock-_skirt_end < SKIRT_KEEP
	var tries := []
	var hold_bulk := wall and float(knobs.skirt_hold) >= 0.5
	if hold:
		# Its side at every angle first; the other only once it's out of ways.
		for s: float in [_skirt_side,-_skirt_side]:
			for a: float in SKIRT: tries.append(a*s)
	else:
		for a: float in SKIRT:
			for s: float in sides: tries.append(a*s)
	for off: float in tries:
		var way := wrapf(base+off,-PI,PI)
		var dir := _way3(way)
		if not _wall_along(dir,length*0.5+float(knobs.look)+1.5,true).is_empty(): continue
		if _floor(position+dir*(length*0.5+float(knobs.look)),float(knobs.step)*STAIR,float(knobs.step)*2.0) == -INF: continue
		# `skirt_hold`, round a wall: his bulk gets on that way too (not
		# only his rays).
		if hold_bulk and _bulk_sweep(position+Vector3.UP*0.1,position+Vector3.UP*0.1+dir*(length*0.5+float(knobs.look))) < 0.5: continue
		_skirt_side = signf(off)
		_skirt_wall = wall
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
	# Olmec ledge (`ledge_stare`): no swing this way and that; he stands
	# turned to where he lost you (`_turn_goal`), his head's gaze searching.
	if not _stares(): facing = wrapf(_seek_from+sin(k*TAU*1.5)*0.9,-PI,PI)
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
	# Olmec climb (`suck_up`): pulling you down off a ledge, his mouth's line
	# to you counts as his sight of you (his eyes lose you over the lip).
	var seen_now: bool = sight.seeing() or (_suck_up_now and _sees_from(position,m.feet))
	_suck_unseen = 0.0 if seen_now else _suck_unseen+delta
	if state == "plant" and state_t >= float(knobs.suck_tell): _go("suck")
	elif state == "suck" and (state_t >= float(knobs.suck_for) or _suck_unseen > float(knobs.suck_lose)):
		_suck_ready = _clock+float(knobs.suck_rest)
		_suck_up_now = false
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
	_threw_t = float(knobs.get("watch_throw",0))
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
		_head_q.collision_mask = _land_mask()
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
			var way := Vector3(vel.x,0.0,vel.z)
			vel.x = 0.0
			vel.z = 0.0
			bulk_stops += 1
			if state == "leap" and not _catch_wall(way): _go("fall")
		elif not hit.is_empty():
			var n := hit.normal as Vector3
			if n.y > 0.5 and vel.y <= 0.0:
				position = hit.position
				_landed()
			else:
				# A wall on the way: it stops dead against it and drops.
				position = (hit.position as Vector3)+Vector3(n.x,0.0,n.z)*0.1-Vector3.UP*0.05
				var way := Vector3(vel.x,0.0,vel.z)
				vel.x = 0.0
				vel.z = 0.0
				if state == "leap" and not _catch_wall(way): _go("fall")
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
		_phase += Vector2(vel.x,vel.z).length()*delta/(hh*_step_len())
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
	# Olmec routes: his place graph lets go of the box; his route planned again.
	if _plans():
		var g = Places.of(field)
		if g != null: g.forget(box)
		world_changes += 1
		# Olmec tune (`plan_settle`): planned again once the rubble has
		# settled (none more for `plan_settle` s), and only by his route.
		if float(knobs.get("plan_settle",0.0)) > 0.0: _pc_settle(box)
		else: _pc_at = -INF
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
	_bulk_q.collision_mask = _land_mask()
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
	# `beam`: walking a beam, its round flanks don't push him off its crest
	# (his heading holds him on the crest line): pushed along it only (off
	# the rim it lies from, onto it).
	var beam_on := _on_beam() if floored else {}
	var on_beam := not beam_on.is_empty()
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
	if on_beam:
		var ax := Vector3((beam_on.b as Vector3).x-(beam_on.a as Vector3).x,0.0,(beam_on.b as Vector3).z-(beam_on.a as Vector3).z).normalized()
		out = ax*out.dot(ax)
	# Its legs: a block it walks beside (taller than LEG_BLOCK, under its
	# bulk's bottom) eases it off sideways only (one met head on is a
	# stair's step it walks up, or a wall its rays meet).
	if floored and not on_beam:
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
			# Olmec reach (`leg_slope`): ground rising by his legs (pushed
			# out more up than across) is a slope under him, not a block
			# beside them: on the fallen pillar the column's crest behind
			# him, met turned across it, pushed him off its deck onto its
			# round flank, 1.5 m into it.
			if float(knobs.leg_slope) > 0.5 and absf((b-a).y) > Vector2((b-a).x,(b-a).z).length(): continue
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
	"grab_windup":0.12,"grab_leap":0.06,"hang":0.05,"charge_tell":0.12,"charge":0.1,"charge_skid":0.06,"charge_stagger":0.04}
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

## Whole and chasing on its own run clip (`run_clip`, the Olmec boss's
## shoulder-led "shoulder_run"), not the stride with its arms out.
func _running() -> bool:
	return run_clip != "" and whole and state == "chase"

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
		"roam","home","chase","return" when _gaits():
			# `run_up`: walk, hunt stride and run clip by his real speed.
			var g := _gait_mix()
			var m := clampf(Vector2(vel.x,vel.z).length()/maxf(float(knobs.walk)*0.5,0.1),0.0,1.0)
			var clips := _gait_clips()
			for i in 3:
				if g[i] > 0.001: look.want(clips[i],look.loop_time(clips[i],_phase,2.0),g[i]*m)
			look.want("idle",idle,1.0-m)
		"roam","home","chase","return":
			var gait := run_clip if _running() else ("stride" if state in ["home","chase"] else "walk")
			# Whole, he hunts on the upright hunt stride, not the arms-out one (olmec-look).
			if gait == "stride" and whole: gait = "hunt_stride"
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
		# Olmec climb (`suck_up`): pulling you down from a ledge over him, he
		# braces only a little (SUCK_UP_BRACE), his head kept up at you (the
		# full brace ducks his mouth under the lip's line).
		"plant": look.want("windup",clampf(state_t/float(knobs.suck_tell),0.0,1.0)*float(look.lengths.windup)*BRACE*(SUCK_UP_BRACE if _suck_up_now else 1.0))
		"suck","gulp": look.want("windup",float(look.lengths.windup)*BRACE*(SUCK_UP_BRACE if _suck_up_now and state == "suck" else 1.0))
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
		_: if not _pose_more(idle): look.want("idle",idle)
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
		"seek" when _stares() and seen_at != Vector3.INF:
			var to := Vector2(seen_at.x-position.x,seen_at.z-position.z)
			if to.length() > 0.1: return PilotMotor.facing_of(to.normalized())
		"stare":
			# At you while he plans; onto his way once found.
			if stare_why == "turn": return _stare_way
			var at := _stare_target()
			var to := Vector2(at.x-position.x,at.z-position.z)
			if to.length() > 0.1: return PilotMotor.facing_of(to.normalized())
	return facing

## How its turns and feet go: stepping round where it stands, walking, or
## the clips' own (climbing, leaping, landing).
func _steps_mode() -> int:
	match state:
		"listen","reach","triumph","feel","alert","stare": return Look.Steps.STAND
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

## What his rays, sight and bulk meet: the study's ground, less walker-only
## stone; with `parked_off`, less the parked plane's column too (the
## walker's keep-off, not stone: on main's crown he skirted it on and on).
const PARKED_LAYER := 1 << 13
func _land_mask() -> int:
	var m := WalkerOnly.strip(field.study.ground.mask)
	if float(knobs.get("parked_off",0)) >= 0.5: m &= ~PARKED_LAYER
	return m

func _cast(from: Vector3, to: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = _land_mask()
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
## lamp, a prop's side) is looked past to the floor under it. A start
## under the open top of hollow land (steep turf rising over `p`) reads
## that top, not the land's sides far below or a void (asked only past
## REACH under `p`, so a real step down never pays or changes).
func _floor(p: Vector3, up: float, down: float) -> float:
	var g := _floor_down(p,up,down)
	if g >= p.y-PhysicsGround.REACH: return g
	var top := PhysicsGround.land_top(field.study.get_world_3d().direct_space_state,_ray,p,up)
	return top if top != -INF else g

func _floor_down(p: Vector3, up: float, down: float) -> float:
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

# --- Olmec routes (`plan_chase`): his chase over a planned route ----------------------------------
# With `plan_chase` on, the chase is driven by a route over his place graph
# (scripts/enemies/olmec_route_graph.gd, built ahead at the study's load): to
# where he believes you are (seen, else where he last saw you or where your
# throw went; relentless, your scent after `hunt_search` s unseen), walked,
# climbed and leapt with his own moves. He plans again every
# `chase_replan` s, when you move GOAL_MOVED m, or when a leg fails (a
# failed leg is banned PLAN_BAN s). The search on open ground runs as he
# walks; at the start of a climb or a leap, after a leg fails, and where
# no way gets to you, it is the ledge stare's beat: he stops, faces you and
# holds the stare while it runs, then turns once onto the first leg and
# goes. No way to you: the way to the place nearest you he can reach, and
# he stares from there (seeing you, his pull from below or his suck), and
# plans again as you move. The rules it replaces (edge_fan, the skirts,
# down_to's and the stare's own pickers, cliff_leap's and climb_to's
# pickers, leap_catch's gap picking, climb_after, chase_routes) are off
# while it is on; their moves and checks are its legs.

const Places = preload("res://scripts/enemies/olmec_route_graph.gd")
## The search's slice of a frame (us).
const PLAN_US := 2500
## The graph's build a frame (us), where his study doesn't build it.
const PLAN_BUILD_US := 3000
## Walk legs aimed at this far ahead at most (m): his run builds along them.
const PLAN_AIM := 9.0
## A banned move is let go of after this (s).
const PLAN_BAN := 30.0
## At a special leg's start within this (m, flat).
const PLAN_AT := 1.6
## A jump this near straight on at you and his facing (rad): no beat.
const PLAN_STRAIGHT := 0.45
## A beat's next no sooner than this after the last (s), on the same leg.
const PLAN_BEAT_GAP := 6.0
## With no route (or at its end), planned again no oftener than this (s).
const PLAN_AGAIN := 0.5
## A special leg starting this near (m, flat) when a beat picks a walk on:
## that beat is its beat.
const PLAN_NEAR_MOVE := 7.0
## Fails in a row before a beat gives up for `stare_replan` s.
const PLAN_FAILS := 3
var _pc_search = null
var _pc_route: Array = []
var _pc_leg := 0
var _pc_leg_t := 0.0
var _pc_goal := Vector3.INF
var _pc_found := false
var _pc_at := -INF
var _pc_banned := {}
var _pc_ban_t := -INF
var _pc_fails := 0
var _pc_beat_t := -INF
var _pc_beat_leg := {}
## The route's id (one each search's), and the [id, leg] whose move he took.
var _pc_rid := 0
## The goal the route he's on was planned to.
var _pc_route_goal := Vector3.INF
var _pc_took := Vector2i(-1,-1)
## Counted, for checks: plans, those that got to you, those that didn't,
## legs given up, the longest search (ms), special legs taken by kind, and
## why the last leg failed.
var plan_n := 0
var plan_found := 0
var plan_none := 0
var plan_fails := 0
var plan_ms := 0.0
var plan_legs := {}
var plan_why := ""
## No place under him to plan from (counted), and that now: he goes on
## straight at you a moment (`_pursue`) till he's on one.
var plan_lost := 0
var _pc_lost := false

func _plans() -> bool:
	return float(knobs.get("plan_chase",0)) >= 0.5 and _chases()

## His field's place graph (made here, its moves built as the search
## comes to them, if the study didn't make it at its load).
func _pc_graph() -> RefCounted:
	var g = Places.of(field)
	if g == null:
		var r := 150.0
		g = Places.make(self,[AABB(position-Vector3(r,r,r),Vector3(r,r,r)*2.0)])
	g.use(self)
	# Its moves built a slice a frame here, if its study doesn't (the crag
	# reach builds it at load and steps it on breaks: `_olmec_graph_step`).
	if not g.built and field.study.get("olmec_graph") != g: g.step(PLAN_BUILD_US)
	return g

## Where he believes you are.
func _pc_target() -> Vector3:
	var m: PilotMotor = field.motor
	if sight != null and sight.seeing(): return m.feet
	return seen_at if seen_at != Vector3.INF else m.feet

func _pc_plan(goal: Vector3) -> void:
	if _clock-_pc_ban_t > PLAN_BAN:
		_pc_banned = {}
		_pc_ban_t = INF
	_pc_goal = goal
	_pc_at = _clock
	plan_n += 1
	_pc_search = Places.Search.new(_pc_graph(),position,goal,length*0.5+2.0,_pc_banned)

## The search stepped; done, its route taken. True: just done.
func _pc_step() -> bool:
	if _pc_search == null: return false
	if not _pc_search.step(PLAN_US): return false
	var s = _pc_search
	_pc_search = null
	plan_ms = maxf(plan_ms,float(s.usec)/1000.0)
	# Olmec tune (`plan_keep`, `plan_flips`): the route he's on kept over
	# one not clearly better that turns him another way.
	if _pc_keep_old(s):
		plan_kept += 1
		return true
	if not _pc_route.is_empty() and _pc_leg < _pc_route.size() and not s.path.is_empty():
		if absf(_pc_way_of(_pc_route,_pc_leg).angle_to(_pc_way_of(s.path,0))) > PLAN_KEEP_WAY: plan_switches += 1
	_pc_route = s.path
	_pc_route_goal = s.goal
	_pc_rid += 1
	_pc_leg = 0
	_pc_leg_t = 0.0
	_pc_found = s.found
	_pc_lost = s.start == Places.NONE
	if s.found: plan_found += 1
	elif _pc_lost: plan_lost += 1
	else: plan_none += 1
	return true

func _pc_drop_route() -> void:
	_pc_route = []
	_pc_leg = 0
	_pc_leg_t = 0.0
	_pc_search = null

## The chase with `plan_chase`: his attacks as ever, then his route's legs.
func _pc_chase(delta: float) -> void:
	var m: PilotMotor = field.motor
	var seeing: bool = sight.seeing()
	# Relentless, you out of his sight a while: he takes your scent.
	if _relentless() and not seeing and seen_t > float(knobs.hunt_search):
		seen_at = m.feet
		seen_t = 0.0
		scents += 1
	var target := _pc_target()
	var to := target-position
	var flat := Vector2(to.x,to.z).length()
	if seeing and _attack_with(m,flat,to.y,delta): return
	# On his walk to a climb's foot or to where he sees you (`_stare_go`).
	if _rim_walk(delta): return
	# On a way only to the place nearest you, where he has you from here.
	if not _pc_found and _pc_search == null and _pc_pulls_from(position,target):
		_pc_beat()
		return
	# You up over him with no way there: the beat decides (his pull, where
	# he'd see you from), not a walk to the place nearest.
	if _pc_step() and not _pc_found and _climbs_up(target):
		_pc_beat()
		return
	# Olmec tune (`plan_settle`): the rubble by his route settled.
	if _pc_settle_due != INF and _clock >= _pc_settle_due:
		_pc_settle_due = INF
		_pc_settle_first = INF
		_pc_at = -INF
	# (No route, or one done: planned again no oftener than PLAN_AGAIN s.)
	var due := (_pc_route.is_empty() and _clock-_pc_at >= PLAN_AGAIN) or _clock-_pc_at >= float(knobs.chase_replan) or target.distance_to(_pc_goal) > GOAL_MOVED
	# (`plan_flips`: turned back and forth, he holds his route a while.)
	if due and _pc_holding() and not _pc_route.is_empty() and _pc_leg < _pc_route.size(): due = false
	if due and _pc_search == null: _pc_plan(target)
	_pc_advance()
	# His route goes to where you were, well off where you are now: he
	# stops (facing you) while the new search runs (a frame or a few).
	if _pc_search != null and _pc_route_goal != Vector3.INF and target.distance_to(_pc_route_goal) > GOAL_MOVED*2.0:
		_pursue_face(delta,target)
		return
	if _pc_leg >= _pc_route.size():
		# Olmec tune (`plan_smooth`): at a route's end with you on past it
		# over ground he walks straight on, he runs on at you (planning
		# again) rather than pulling up for the fresh route.
		if _smooths() and _pc_run_on(target):
			if _pc_search == null and _clock-_pc_at >= PLAN_AGAIN: _pc_plan(target)
			_pursue(delta,target,_chase_pace())
			return
		if _pc_search != null:
			_brake(delta)
			return
		if _pc_lost:
			_pursue(delta,target,_chase_pace())
			return
		# His route's end: by you, on at you; else (the nearest he gets, or
		# you not there) he stares and plans.
		if _pc_found and flat < length+float(knobs.pounce_max)*hh*0.5:
			_pursue(delta,target,_chase_pace())
			return
		_pc_beat()
		return
	var leg: Dictionary = _pc_route[_pc_leg]
	_pc_leg_t += delta
	if leg.kind == "walk":
		if _pc_leg_t > float(knobs.leg_slack):
			_pc_fail("slow")
			return
		# Off the route (thrown, slid): planned again from here, now.
		var near_leg := _flat_d(leg.from) < CELL_OFF or _flat_d(leg.to) < CELL_OFF
		if _smooths() and not near_leg: near_leg = _seg_d(leg.from,leg.to) < CELL_OFF
		if not near_leg and _pc_search == null: _pc_plan(target)
		_pursue(delta,_pc_smooth_aim() if _smooths() else _pc_aim(),_chase_pace())
		return
	# A special leg: to its start, then (a beat) the move.
	if _flat_d(leg.from) > PLAN_AT:
		if _pc_leg_t > float(knobs.leg_slack):
			_pc_fail("slow to its start")
			return
		_pursue(delta,leg.from,_chase_pace())
		return
	_pc_special(leg,target)

const CELL_OFF := Routes.CELL*3.0

## Braked, turned toward `at` (his stood turn).
func _pursue_face(delta: float, at: Vector3) -> void:
	_brake(delta)
	var to := Vector2(at.x-position.x,at.z-position.z)
	if to.length() > 0.1: _heading = PilotMotor.facing_of(to.normalized())
	if _runs(): _run_hold()

func _flat_d(p: Vector3) -> float:
	return Vector2(p.x-position.x,p.z-position.z).length()

## Legs he is done with (stood at a walk leg's end, landed by a special
## leg's) passed; a later walk leg's end he cut to, on to it.
func _pc_advance() -> void:
	while _pc_leg < _pc_route.size():
		var leg: Dictionary = _pc_route[_pc_leg]
		var to: Vector3 = leg.to
		var walk: bool = leg.kind == "walk"
		var near := Routes.CELL*(0.9 if walk else 2.5)
		if walk and _clock-_pushed_at < 0.3: near += hh*BULK_W
		var dy := float(knobs.step)*2.0 if walk else 3.0
		if _flat_d(to) <= near and absf(to.y-position.y) <= dy:
			_pc_leg += 1
			_pc_leg_t = 0.0
			continue
		# A special leg's move made (he's up, or down) but short of its end:
		# a fresh route from here.
		if not walk and _pc_took == Vector2i(_pc_rid,_pc_leg) and grounded and _flat_d(leg.from) > PLAN_AT*2.0 and _pc_search == null and state == "chase":
			_pc_plan(_pc_target())
		break
	for i in range(_pc_leg+1,mini(_pc_leg+6,_pc_route.size())):
		if _pc_route[i-1].kind != "walk" or _pc_route[i].kind != "walk": break
		var to: Vector3 = _pc_route[i].to
		if _flat_d(to) <= Routes.CELL*0.9 and absf(to.y-position.y) <= float(knobs.step)*2.0:
			_pc_leg = i+1
			_pc_leg_t = 0.0
	if _smooths(): _pc_pass_legs()

# --- Olmec tune (`plan_keep`, `plan_settle`, `plan_flips`): no flip-flops -------------------------

## A fresh route turning him no more than this (rad) off the way he goes
## is taken as it comes (no switch to see).
const PLAN_KEEP_WAY := 0.6
## A fresh route turning him more must be cheaper by `plan_keep` of his
## route's cost left, and at least this (m of walk).
const PLAN_KEEP_MIN := 3.0
## Longer than this (s) on the leg he's on, his route isn't kept.
const PLAN_KEEP_STUCK := 3.0
## His route's next legs looked over for a break (`_pc_broken`).
const PLAN_KEEP_LEGS := 16
## Rubble settling (`plan_settle`): his plan waits at most this long (s)
## from the first settle for the last.
const PLAN_SETTLE_MOST := 4.0
## Turns back (`plan_flips`): one counts once he swung back this far (rad);
## `plan_flips` of them within FLIP_WINDOW s, and he holds his route for
## FLIP_HOLD s.
const FLIP_MIN := 0.3
const FLIP_WINDOW := 8.0
const FLIP_HOLD := 6.0
## Counted, for checks: world changes read, fresh routes turned down,
## fresh routes that turned him (past PLAN_KEEP_WAY), his turns back, and
## the holds they set.
var world_changes := 0
var plan_kept := 0
var plan_switches := 0
var plan_flipped := 0
var plan_holds := 0
## Why the last fresh route was turned down (for checks).
var keep_why := ""
var _pc_settle_due := INF
var _pc_settle_first := INF
var _pc_hold_until := -INF
var _fl_f := INF
var _fl_dir := 0.0
var _fl_opp := 0.0
var _flips: Array[float] = []

func _pc_holding() -> bool:
	return int(knobs.get("plan_flips",0)) > 0 and _clock < _pc_hold_until

## The way (flat, unit) `route` takes him from where he stands from leg
## `i0`: to its first point 5 m off, or its first special leg's start.
func _pc_way_of(route: Array, i0: int) -> Vector2:
	var me := Vector2(position.x,position.z)
	var last := me
	for i in range(i0,route.size()):
		var l: Dictionary = route[i]
		var p: Vector3 = l.to if l.kind == "walk" else l.from
		last = Vector2(p.x,p.z)
		if l.kind != "walk" or last.distance_to(me) >= 5.0: break
	var d := last-me
	return d.normalized() if d.length() > 0.1 else PilotMotor.forward(facing)

## His route's cost left from where he stands (the graph's costs), with the
## search's estimate from its end to `goal`.
func _pc_cost_left(goal: Vector3) -> float:
	var c := 0.0
	var at := position
	for i in range(_pc_leg,_pc_route.size()):
		var l: Dictionary = _pc_route[i]
		var to: Vector3 = l.to
		if l.kind == "walk" or i == _pc_leg: c += Vector2(to.x-at.x,to.z-at.z).length()+absf(to.y-at.y)*0.5
		if l.kind != "walk": c += float((l.edge as Dictionary).get("cost",0.0))
		at = to
	var r := length*0.5+2.0
	return c+maxf(0.0,Vector2(goal.x-at.x,goal.z-at.z).length()-r)+maxf(absf(goal.y-at.y)-Places.GOAL_DY,0.0)*0.5

## Whether his route's next legs are broken: a walk place he no longer fits,
## a special move rebuilt without it, or a banned move.
func _pc_broken() -> bool:
	var g = Places.of(field)
	if g == null: return true
	for i in range(_pc_leg,mini(_pc_leg+PLAN_KEEP_LEGS,_pc_route.size())):
		var l: Dictionary = _pc_route[i]
		if _pc_banned.has(Places.Search.key(l.from_node,l.node)): return true
		if l.kind == "walk":
			if not g.standable(l.node): return true
			continue
		if not g.special.has(l.from_node): continue
		var ok := false
		for e: Dictionary in g.special[l.from_node]:
			if str(e.kind) == str(l.kind) and e.to == l.node:
				ok = true
				break
		if not ok: return true
	return false

## Whether a fresh search's route is turned down for the one he's on: it
## turns him another way (past PLAN_KEEP_WAY) and isn't clearly cheaper
## (`plan_keep`), or he's holding his route (`plan_flips`); never for a
## broken route, one done, one to where you were (GOAL_MOVED off), or one
## to the nearest place when this gets to you.
func _pc_keep_old(s) -> bool:
	var keep := float(knobs.get("plan_keep",0.0))
	var hold := _pc_holding()
	if keep <= 0.0 and not hold: return false
	if _pc_route.is_empty() or _pc_leg >= _pc_route.size() or s.path.is_empty(): return false
	if s.found and not _pc_found: return false
	# Planned to where you were, well off where you are now: the fresh one.
	if _pc_route_goal == Vector3.INF or (s.goal as Vector3).distance_to(_pc_route_goal) > GOAL_MOVED: return false
	if absf(_pc_way_of(_pc_route,_pc_leg).angle_to(_pc_way_of(s.path,0))) <= PLAN_KEEP_WAY: return false
	if _pc_broken(): return false
	# Stuck on the leg he's on (wading, pinned): the fresh one.
	if _pc_leg_t > PLAN_KEEP_STUCK: return false
	if hold: return true
	var old := _pc_cost_left(s.goal)
	var fresh: float = float(s.cost)+float(s.left)
	keep_why = "old %.1f fresh %.1f (%s, found %s/%s)" % [old,fresh,_pc_kinds(),_pc_found,s.found]
	return fresh+maxf(old*keep,PLAN_KEEP_MIN) > old

## Rubble settled in `box`: by his route (or with none), a plan once no
## more has settled for `plan_settle` s (PLAN_SETTLE_MOST s at most).
func _pc_settle(box: AABB) -> void:
	var grown := box.grow(Routes.CELL*3.0)
	var near := _pc_route.is_empty() or Places._flat_in(grown,position)
	if not near:
		for i in range(_pc_leg,mini(_pc_leg+PLAN_KEEP_LEGS,_pc_route.size())):
			var l: Dictionary = _pc_route[i]
			if Places._flat_in(grown,l.from as Vector3) or Places._flat_in(grown,l.to as Vector3):
				near = true
				break
	if not near: return
	if _pc_settle_first == INF: _pc_settle_first = _clock
	_pc_settle_due = minf(_clock+float(knobs.plan_settle),_pc_settle_first+PLAN_SETTLE_MOST)

## His turns back counted (`plan_flips`): `plan_flips` within FLIP_WINDOW s
## and he holds the route he's on FLIP_HOLD s.
func _pc_flip_watch() -> void:
	if _fl_f == INF:
		_fl_f = facing
		return
	var df := angle_difference(_fl_f,facing)
	_fl_f = facing
	if absf(df) < 0.0005 or absf(df) > 1.0: return
	var sg := signf(df)
	if _fl_dir == 0.0: _fl_dir = sg
	elif sg == _fl_dir: _fl_opp = 0.0
	else:
		_fl_opp += absf(df)
		if _fl_opp > FLIP_MIN:
			_fl_dir = sg
			_fl_opp = 0.0
			plan_flipped += 1
			_flips.append(_clock)
	while not _flips.is_empty() and _clock-_flips[0] > FLIP_WINDOW: _flips.pop_front()
	var most := int(knobs.get("plan_flips",0))
	if most > 0 and _flips.size() >= most and not _pc_holding():
		_pc_hold_until = _clock+FLIP_HOLD
		plan_holds += 1
		_flips.clear()

## `gaze_yaw`: stood in these states (nothing else turning him), his body
## turns after a look held past the head's ease.
const GAZE_FOLLOW := ["seek","land","spent","listen","alert"]
## The look past the ease this long (s) before the body turns.
const GAZE_FOLLOW_AFTER := 0.25
var _gaze_past_t := 0.0

## `gaze_yaw`: his head held past its ease (`gaze.past`) while he stands in
## a GAZE_FOLLOW state: his body turns after it (at his stood turn, his
## steps stepping it round), till the head is back inside its ease.
func _gaze_follow(delta: float) -> void:
	var past := float(gaze.past)
	if absf(past) < 0.02 or not (state in GAZE_FOLLOW) or Vector2(vel.x,vel.z).length() > 0.3:
		_gaze_past_t = 0.0
		return
	_gaze_past_t += delta
	if _gaze_past_t < GAZE_FOLLOW_AFTER: return
	var rate := float(knobs.turn)*float(knobs.chase_turn)*clampf(absf(past)/0.3,0.25,1.0)
	facing = wrapf(facing+signf(past)*minf(absf(past),rate*delta),-PI,PI)
	_heading = facing

# --- Olmec tune (`plan_smooth`): his walk legs shortcut and curved ---------------------------------

## A walk's look-ahead at his top run (m); PLAN_AIM at his walk.
const SMOOTH_AIM_TOP := 14.0
## The route sampled this often along it (m) for the aim.
const SMOOTH_STEP := 0.75
## The aim found again this often (s).
const SMOOTH_EVERY := 0.1
var _ps_aim := Vector3.INF
var _ps_at := -INF
var _ps_key := Vector3i(-1,-1,-1)

func _smooths() -> bool:
	return float(knobs.get("plan_smooth",0)) >= 0.5

## Flat distance from him to the segment `a`..`b`.
func _seg_d(a: Vector3, b: Vector3) -> float:
	var me := Vector2(position.x,position.z)
	return Geometry2D.get_closest_point_to_segment(me,Vector2(a.x,a.z),Vector2(b.x,b.z)).distance_to(me)

## The walk legs he is along passed: the leg nearest him among the next
## walk legs (the later on a tie), looked for till they lead away.
func _pc_pass_legs() -> void:
	var best := -1
	var best_d := INF
	for i in range(_pc_leg,mini(_pc_leg+16,_pc_route.size())):
		var l: Dictionary = _pc_route[i]
		if l.kind != "walk": break
		if absf((l.to as Vector3).y-position.y) > float(knobs.step)*2.0: break
		var d := _seg_d(l.from,l.to)
		if d <= best_d+0.01:
			best_d = d
			best = i
		elif d > best_d+Routes.CELL*2.0: break
	if best > _pc_leg and best_d < Routes.CELL:
		_pc_leg = best
		_pc_leg_t = 0.0

## `plan_smooth`: at his route's end, whether he runs on straight at
## `target` (seen, on his level, over places he fits all the way, or the
## first PLAN_AIM m of it).
func _pc_run_on(target: Vector3) -> bool:
	if not _pc_found or sight == null or not sight.seeing(): return false
	if absf(target.y-position.y) > float(knobs.step)*STAIR*2.0: return false
	var g = Places.of(field)
	if g == null or not g.has_method("walk_line"): return false
	var to := Vector3(target.x-position.x,0.0,target.z-position.z)
	var p := target if to.length() <= PLAN_AIM else position+to.normalized()*PLAN_AIM
	return g.walk_line(position,p)

## Where his walk aims (`plan_smooth`): along his route's walk legs from
## where he is along the leg he's on, the farthest point within his
## look-ahead (PLAN_AIM at a walk to SMOOTH_AIM_TOP at his top) he walks
## straight to over places he fits; none, `_pc_aim`.
func _pc_smooth_aim() -> Vector3:
	var key := Vector3i(_pc_rid,_pc_leg,0)
	if _ps_aim != Vector3.INF and _clock-_ps_at < SMOOTH_EVERY and key == _ps_key: return _ps_aim
	var g = Places.of(field)
	if g == null or not g.has_method("walk_line"): return _pc_aim()
	var reach := lerpf(PLAN_AIM,SMOOTH_AIM_TOP,run_k)
	var leg: Dictionary = _pc_route[_pc_leg]
	var a: Vector3 = leg.from
	var b: Vector3 = leg.to
	var me := Vector2(position.x,position.z)
	var near := Geometry2D.get_closest_point_to_segment(me,Vector2(a.x,a.z),Vector2(b.x,b.z))
	var t := 0.0 if Vector2(b.x-a.x,b.z-a.z).length() < 0.01 else Vector2(a.x,a.z).distance_to(near)/Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
	var pts: Array[Vector3] = [a.lerp(b,t),b]
	var run := Vector2(pts[0].x,pts[0].z).distance_to(Vector2(b.x,b.z))
	for i in range(_pc_leg+1,_pc_route.size()):
		if run > reach: break
		var l: Dictionary = _pc_route[i]
		if l.kind != "walk": break
		var p: Vector3 = l.to
		run += Vector2(pts[-1].x,pts[-1].z).distance_to(Vector2(p.x,p.z))
		pts.append(p)
	# Points along it every SMOOTH_STEP m, out to `reach` (its end too).
	var samples: Array[Vector3] = []
	var gone := 0.0
	var next := SMOOTH_STEP
	for j in range(pts.size()-1):
		var seg := Vector2(pts[j+1].x-pts[j].x,pts[j+1].z-pts[j].z).length()
		while next <= gone+seg and next <= reach:
			samples.append(pts[j].lerp(pts[j+1],(next-gone)/maxf(seg,0.001)))
			next += SMOOTH_STEP
		gone += seg
		if next > reach: break
	if gone <= reach: samples.append(pts[-1])
	var best := Vector3.INF
	var dy := float(knobs.step)*STAIR*2.0
	for p: Vector3 in samples:
		if absf(p.y-position.y) > dy or not g.walk_line(position,p): break
		best = p
	if best == Vector3.INF: best = _pc_aim()
	_ps_aim = best
	_ps_at = _clock
	_ps_key = key
	return best

## On a walk leg of his route, the next leg a walk too (not at a climb's foot).
func _pc_on_walk() -> bool:
	if _pc_leg >= _pc_route.size() or _pc_route[_pc_leg].kind != "walk": return false
	return _pc_leg+1 >= _pc_route.size() or _pc_route[_pc_leg+1].kind == "walk" or _flat_d(_pc_route[_pc_leg+1].from) > Routes.CELL*2.5

## Where his walk aims: the furthest of the next walk legs' ends within
## PLAN_AIM m (up to the start of a special leg).
func _pc_aim() -> Vector3:
	var aim: Vector3 = _pc_route[_pc_leg].to
	var a := Vector2(position.x,position.z)
	for i in range(_pc_leg+1,mini(_pc_leg+8,_pc_route.size())):
		var next: Dictionary = _pc_route[i]
		if next.kind != "walk": break
		var p: Vector3 = next.to
		if _flat_d(p) > PLAN_AIM or absf(p.y-position.y) > float(knobs.step)*STAIR*2.0: break
		# No corner cut: the legs' ends between lie by the line to it.
		var b := Vector2(p.x,p.z)
		var cut := false
		for j in range(_pc_leg,i):
			var q: Vector3 = _pc_route[j].to
			if Geometry2D.get_closest_point_to_segment(Vector2(q.x,q.z),a,b).distance_to(Vector2(q.x,q.z)) > PLAN_CUT:
				cut = true
				break
		if cut: break
		aim = p
	return aim

## A walk's aim cuts no corner of its route by more than this (m).
const PLAN_CUT := 1.0

## At a special leg's start: the move, checked again from where he stands
## (straight on at you, at once; else the stare's beat first).
func _pc_special(leg: Dictionary, target: Vector3) -> void:
	var e: Dictionary = leg.edge
	var way := float(e.way)
	var to_you := Vector2(target.x-position.x,target.z-position.z)
	var you_way := PilotMotor.facing_of(to_you.normalized()) if to_you.length() > 0.1 else facing
	if e.kind == "jump" and absf(angle_difference(way,you_way)) < PLAN_STRAIGHT and absf(angle_difference(facing,way)) < PLAN_STRAIGHT:
		var o := _pc_way(leg)
		if not o.is_empty():
			_pc_take(o)
			return
	if _pc_beat_leg == leg and _clock-_pc_beat_t < PLAN_BEAT_GAP:
		var o2 := _pc_way(leg)
		if o2.is_empty():
			_pc_fail("not from here")
			return
		_pc_doing(leg)
		plan_legs[o2.kind] = int(plan_legs.get(o2.kind,0))+1
		_pc_turn_now(o2)
		return
	_pc_beat()

## The special leg whose move he is making ({} none): if he lets go of its
## face or lands off its end, it is banned (he doesn't try it again at once).
var _pc_move := {}
func _pc_doing(leg: Dictionary) -> void:
	_pc_move = {"key":Places.Search.key(leg.from_node,leg.node),"to":leg.to,"kind":leg.kind,"t":_clock,"at":(leg.edge as Dictionary).get("at",leg.to)}

## The move `key` banned (PLAN_BAN s), and (a special one) every special
## move near its spot `at`.
func _pc_ban(key: String, at: Variant) -> void:
	_pc_banned[key] = true
	if at is Vector3 and at != Vector3.INF:
		if not _pc_banned.has("@spots"): _pc_banned["@spots"] = []
		(_pc_banned["@spots"] as Array).append(at)
	if _pc_ban_t == INF or _pc_ban_t == -INF: _pc_ban_t = _clock

## His move let go of (a fall off its face, a landing off its end): banned.
func _pc_move_failed(why: String) -> void:
	if _pc_move.is_empty() or not _plans(): return
	_pc_ban(str(_pc_move.key),_pc_move.at)
	plan_fails += 1
	plan_why = "%s %s at %s" % [why,_pc_move.kind,position.round()]
	_stare_note("move failed: %s" % plan_why)
	_pc_move = {}
	_pc_drop_route()

## Into the stare's turn onto `o` at once (the beat just held for it).
func _pc_turn_now(o: Dictionary) -> void:
	vel.x = 0.0
	vel.z = 0.0
	_rim_goal = Vector3.INF
	_rim_then = {}
	_go("stare")
	stares += 1
	_stare_held = 0.0
	_stare_for = _stare_target()
	_stare_best = o
	_pc_turn_to(o)

## The stare's beat (`_stare_start`, whose plan is the search now).
func _pc_beat() -> void:
	if state == "stare": return
	_stare_start()

## A special leg's move from where he stands now, its checks again: {kind,
## at, up, way, face, lip, n, foot, from, left} as the stare's ways are
## (`_stare_go` takes it), {} it can't be made from here.
func _pc_way(leg: Dictionary) -> Dictionary:
	var e: Dictionary = leg.edge
	var target := _pc_target()
	var at: Vector3 = e.at
	var o := {"kind":str(e.kind),"at":at,"up":float(e.up),"way":float(e.way),"from":Vector3.INF,"left":(e.land as Vector3).distance_to(target),"edge":e}
	var was_f := facing
	var to_at := Vector2(at.x-position.x,at.z-position.z)
	if to_at.length() > 0.1: facing = PilotMotor.facing_of(to_at.normalized())
	var ok := true
	match str(e.kind):
		"jump":
			ok = _arc_clear(at,"jump")
			if not ok:
				var lg := _ledge(_way3(float(e.way)))
				if not lg.is_empty() and (lg.at as Vector3).distance_to(e.land) < Routes.CELL*3.0 and _arc_clear(lg.at,"jump"):
					o.at = lg.at
					ok = true
		"drop":
			ok = false
			var ups: Array = [float(e.up),float(knobs.leap_up),hh*0.8,hh*1.4,float(knobs.down_arc)*hh]
			# `down_show`: a landing near the planned one your camera sees
			# him come down on (and not on you), if there is one.
			if float(knobs.down_show) > 0.0:
				var alt := _down_find(target)
				if not alt.is_empty() and (alt.at as Vector3).distance_to(e.land) < 9.0 and absf((alt.at as Vector3).y-(e.land as Vector3).y) < 2.5:
					o.at = alt.at
					o.up = float(alt.up)
					ok = true
			if not ok:
				for up: float in ups:
					_drop_up = up
					var clear := _arc_clear(at,"drop",true)
					_drop_up = -1.0
					if clear:
						o.up = up
						ok = true
						break
		"cliff":
			o.face = e.face
			o.lip = e.lip
			ok = _wall_arc(at,e.face) and _catch_ok(at,e.face)
			if not ok:
				var cf := _cliff_find(float(e.way),Vector3.INF)
				if not cf.is_empty() and (cf.lip as Vector3).distance_to(e.lip) < Routes.CELL*3.0:
					o.at = cf.to
					o.face = cf.face
					o.lip = cf.lip
					ok = true
		"climb":
			o.at = e.at
			o.face = e.face
			o.n = e.n
			o.lip = e.lip
			o.foot = e.foot
	facing = was_f
	if not ok: return {}
	if str(e.kind) != "climb":
		var d := Vector2((o.at as Vector3).x-position.x,(o.at as Vector3).z-position.z)
		if d.length() > 0.1: o.way = PilotMotor.facing_of(d.normalized())
	return o

## A checked move taken at once (no beat): the windup.
func _pc_take(o: Dictionary) -> void:
	plan_legs[o.kind] = int(plan_legs.get(o.kind,0))+1
	_pc_took = Vector2i(_pc_rid,_pc_leg)
	_pc_doing(_pc_route[_pc_leg])
	_stare_best = o
	_stare_go(o)

## Turned onto the move `o` (the stare's turn), then `_stare_go`.
func _pc_turn_to(o: Dictionary) -> void:
	var to_go: Vector3 = o.at
	var dir := Vector2(to_go.x-position.x,to_go.z-position.z)
	_stare_way = PilotMotor.facing_of(dir.normalized()) if dir.length() > 0.3 else float(o.way)
	stare_why = "turn"
	_stare_t = 0.0

## The leg he is on can't be made: banned a while, and the beat plans round it.
func _pc_fail(why: String) -> void:
	plan_fails += 1
	_pc_fails += 1
	if _pc_leg < _pc_route.size():
		var leg: Dictionary = _pc_route[_pc_leg]
		plan_why = "%s %s leg %d/%d at %s" % [why,leg.kind,_pc_leg,_pc_route.size(),position.round()]
		_pc_ban(Places.Search.key(leg.from_node,leg.node),(leg.edge as Dictionary).get("at",Vector3.INF))
	else: plan_why = "%s at %s" % [why,position.round()]
	_stare_note("leg failed: %s [%s]" % [plan_why,plan_wall_why])
	plan_wall_why = ""
	_pc_drop_route()
	vel.x = 0.0
	vel.z = 0.0
	_pc_beat()

## His walk (`_pursue`) met a wall or an edge it isn't taking: by the next
## leg's start, that leg; else the leg failed.
func _pc_blocked(why: String, hit := {}) -> void:
	vel.x = 0.0
	vel.z = 0.0
	# On his way to a climb, its face met a little off where it was looked
	# at (its lip about the planned one's height): up it from here.
	if not hit.is_empty() and _pc_climb_here(hit): return
	if not hit.is_empty():
		var col: Object = hit.get("collider")
		why += " (%s n %s %s)" % [(hit.position as Vector3).round(),(hit.normal as Vector3).snapped(Vector3.ONE*0.1),String((col as Node).name) if col is Node else ""]
	if _rim_goal != Vector3.INF:
		var near_rim := _flat_d(_rim_goal) < RIM_AT*2.0
		if near_rim:
			_rim_arrive()
			return
		_rim_goal = Vector3.INF
		_rim_then = {}
		_pc_fail(why+" on his walk to a stand")
		return
	if _pc_leg < _pc_route.size():
		var leg: Dictionary = _pc_route[_pc_leg]
		if leg.kind == "walk" and _pc_leg+1 < _pc_route.size() and _pc_route[_pc_leg+1].kind != "walk" and _flat_d(_pc_route[_pc_leg+1].from) < Routes.CELL*2.5:
			_pc_leg += 1
			_pc_leg_t = 0.0
			_pc_special(_pc_route[_pc_leg],_pc_target())
			return
		if leg.kind != "walk" and _flat_d(leg.from) < Routes.CELL*2.5:
			_pc_special(leg,_pc_target())
			return
		_pc_fail(why)
		return
	if _clock >= _wall_stare_next:
		_wall_stare_next = _clock+float(knobs.stare_replan)
		_pc_beat()

## The climb he's on his way to (on his walk to its foot, or its leg or
## the next): the wall `hit` taken for it if it is that face near where it
## was checked, climbable to about its lip. Whether he climbs.
const PLAN_CLIMB_NEAR := 5.0
var plan_wall_why := ""
func _pc_climb_here(hit: Dictionary) -> bool:
	if hit.get("side",false) or hit.get("ceiling",false): return false
	var e := {}
	if str(_rim_then.get("kind","")) == "climb": e = _rim_then
	else:
		for i in range(_pc_leg,mini(_pc_leg+2,_pc_route.size())):
			if _pc_route[i].kind == "climb":
				e = _pc_route[i].edge
				break
	if e.is_empty(): return false
	var face: Vector3 = e.face
	var lip: Vector3 = e.lip
	var at := hit.position as Vector3
	var n := hit.normal as Vector3
	n = Vector3(n.x,0.0,n.z).normalized()
	var top := _climbable(hit)
	plan_wall_why = "wall %s n %s top %.1f; climb face %s n %s lip %.1f" % [at.round(),n.snapped(Vector3.ONE*0.1),top,face.round(),(e.n as Vector3).snapped(Vector3.ONE*0.1),lip.y]
	if Vector2(at.x-face.x,at.z-face.z).length() > PLAN_CLIMB_NEAR: return false
	if n.dot(e.n) < 0.5: return false
	if top == INF or absf(top-lip.y) > float(knobs.step)*STAIR*1.5: return false
	_rim_goal = Vector3.INF
	_rim_then = {}
	plan_legs["climb_met"] = int(plan_legs.get("climb_met",0))+1
	_climb_up({"face":at,"n":n,"lip":Vector3(at.x,top,at.z)})
	return true

## The stare's plan with `plan_chase`: the search, from here to `goal`.
func _pc_stare_plan(goal: Vector3) -> void:
	_stare_jobs = []
	_stare_sight = {}
	# (`_up_none` holds till a route is found: his pull goes on meanwhile.)
	_pc_drop_route()
	_pc_plan(goal)

## The stare's plan done (and held): the first leg's move, turned onto;
## none, the stare goes on (you over him, the pull's go; where he'd see you
## from, he walks there first).
func _pc_decide() -> void:
	var target := _stare_target()
	if _pc_found: _up_none = false
	# No way to you: seen from here (or where he'd stand to see you, you
	# over him), his pull or his suck, before the walk to the place nearest.
	elif _pc_pulls_from(position,target):
		_pc_none(target)
		return
	elif _climbs_up(target) and float(knobs.get("suck_up",0)) > 0.0:
		_sight_find(target)
		if not _stare_sight.is_empty() and _flat_d(_stare_sight.at) > RIM_AT:
			_up_none = true
			_stare_note("no way up; to see you from %s" % (_stare_sight.at as Vector3).round())
			_stare_best = _stare_sight
			_pc_turn_to(_stare_sight)
			return
	# Walk legs that end by where he stands passed.
	_pc_advance()
	while _pc_leg < _pc_route.size() and _pc_route[_pc_leg].kind == "walk" and _flat_d(_pc_route[_pc_leg].to) < Routes.CELL*1.2: _pc_leg += 1
	if _pc_leg >= _pc_route.size():
		var flat := Vector2(target.x-position.x,target.z-position.z).length()
		if _pc_found and flat < length+float(knobs.pounce_max)*hh*0.5:
			_go("chase")
			return
		_pc_none(target)
		return
	var leg: Dictionary = _pc_route[_pc_leg]
	if leg.kind == "walk":
		_pc_fails = 0
		var aim := _pc_aim()
		_stare_best = {"kind":"walk","at":aim,"up":-1.0,"way":facing,"from":Vector3.INF,"left":aim.distance_to(target)}
		_stare_note("route %d legs (%s), %s, walks on" % [_pc_route.size(),_pc_kinds(),"to you" if _pc_found else "nearest you"])
		# A climb or a leap a few steps on: this beat was its beat.
		for i in range(_pc_leg,_pc_route.size()):
			if _pc_route[i].kind == "walk": continue
			if _flat_d(_pc_route[i].from) < PLAN_NEAR_MOVE:
				_pc_beat_t = _clock
				_pc_beat_leg = _pc_route[i]
			break
		_pc_turn_to(_stare_best)
		return
	if _flat_d(leg.from) > PLAN_AT:
		# Short of its start: there first (the beat held for it already).
		_pc_beat_t = _clock
		_pc_beat_leg = leg
		_stare_best = {"kind":"walk","at":leg.from,"up":-1.0,"way":facing,"from":Vector3.INF,"left":0.0}
		_pc_turn_to(_stare_best)
		return
	var o := _pc_way(leg)
	if o.is_empty():
		_pc_ban(Places.Search.key(leg.from_node,leg.node),(leg.edge as Dictionary).get("at",Vector3.INF))
		plan_fails += 1
		_pc_fails += 1
		_stare_note("%s from %s not from here; round it" % [leg.kind,position.round()])
		if _pc_fails < PLAN_FAILS:
			_stare_plan(target)
			return
		_pc_fails = 0
		_pc_none(target)
		return
	_pc_fails = 0
	_pc_beat_t = _clock
	_pc_beat_leg = leg
	plan_legs[o.kind] = int(plan_legs.get(o.kind,0))+1
	_pc_took = Vector2i(_pc_rid,_pc_leg)
	_pc_doing(_pc_route[_pc_leg])
	_stare_note("route %d legs (%s), %s: %s at %s" % [_pc_route.size(),_pc_kinds(),"to you" if _pc_found else "nearest you",o.kind,(o.at as Vector3).round()])
	_stare_best = o
	_pc_turn_to(o)

## No way on from here: staring at you, the plan again as you move (you
## over him with no way up: his pull; out of his line, where he'd see you).
func _pc_none(target: Vector3) -> void:
	if _climbs_up(target) and float(knobs.get("suck_up",0)) > 0.0:
		_up_none = true
		_sight_find(target)
		if not _stare_sight.is_empty() and _flat_d(_stare_sight.at) > RIM_AT:
			_stare_note("no way up; to see you from %s" % (_stare_sight.at as Vector3).round())
			_stare_best = _stare_sight
			_pc_turn_to(_stare_sight)
			return
	stare_why = "none"
	stare_nones += 1
	_stare_t = 0.0
	_stare_note("none at %s, you %s (%s)" % [position.round(),target.round(),"at the nearest he gets" if not _pc_found else "there"])

## No way to you: whether from `at` he'd have you with no route (you over
## him in his pull's reach and his mouth's line; or seen, in his suck's).
func _pc_pulls_from(at: Vector3, target: Vector3) -> bool:
	if _climbs_up(target) and float(knobs.get("suck_up",0)) > 0.0 and _sees_from(at,target): return true
	var flat := Vector2(target.x-at.x,target.z-at.z).length()
	var pulls: bool = sight != null and sight.seeing() and at == position and flat <= float(knobs.suck_max)*hh*(1.3 if _relentless() else 1.0)
	# Olmec tune (`plan_keep`): only if his worn head's pull reaches you
	# from here (else he stood staring, the suck never firing).
	if pulls and float(knobs.get("plan_keep",0.0)) > 0.0 and head != null and head.has_method("worn_reaches"): pulls = head.worn_reaches(field.motor)
	return pulls

func _pc_kinds() -> String:
	var k: Array = []
	for l: Dictionary in _pc_route.slice(_pc_leg):
		if l.kind != "walk": k.append(l.kind)
	return ",".join(k) if not k.is_empty() else "walk"

## The route's state, for drivers and the overlay.
func plan_text() -> String:
	if not _plans(): return ""
	return "plan %d (%d to you, %d nearest) leg %d/%d [%s]%s fails %d %s" % [plan_n,plan_found,plan_none,_pc_leg,_pc_route.size(),_pc_kinds(),
		(" searching %d exp %.0f ms" % [_pc_search.expanded,_pc_search.usec/1000.0]) if _pc_search != null else "",plan_fails,plan_why]

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
