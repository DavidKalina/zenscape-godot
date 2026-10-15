extends Node3D
## The sky dragon (docs/design/rim-dragon.md, round 3): an experiment. A
## wyvern after Smaug (assets/models/rim_dragon_<a|b|c>.glb, built by
## art/blender/rim_dragon/dragon_body_build.py): the wings are its arms,
## two hind legs, a long serpentine neck, a long whip tail. It rises out of
## the cloud sea and roams the archipelago round the isle: big circuits,
## threading between isles, climbs, dives and now and then a low pass over
## the isle you stand on, its shadow aimed across the turf. Everything is
## posed procedurally on its rig each frame:
##   - wingbeats with weight: a fast, powerful downstroke with the tips
##     lagging, the wings folding at the wrist on the upstroke, the body
##     bobbing against each beat; bouts of beats between glides on spread,
##     gull-bent wings;
##   - riding the air: it swells and dips, rolls and pitches a little as if
##     meeting gusts and thermals (stronger with the isle's breeze), the
##     wings trimming and twisting against it, now and then a bump it
##     shrugs off; it crabs a little into the wind;
##   - turns banked, the neck and head leading into them, the tail a
##     dragged rope (verlet points) so it trails the curve and swings late;
##   - the mouth on springs: it breathes and chews, and now and then it
##     roars: the head lifts and the neck draws back as the jaw opens (eased
##     in, overshooting and settling), the cheek skin stretching and the
##     lower lip following through;
##   - the head turning to look at the camera when it passes close.
##   - round 4, the attack: every minute or two it banks in to a far isle
##     (one of `targets`, seen from the aqueduct isle's turf), flares hard
##     with its wings cupped and back-beating and its legs reaching, and
##     slams onto the rim: hind claws and wrist thumbs hooked over the edge
##     (a little reaching IK each frame), the tail hanging and swinging
##     under the keel, the neck reared up over the turf. The isle shudders,
##     dust and stone come off the rim, its birds burst out. Then it pants
##     and looks round, breathes in (the tell: streaks drawn in, the trees
##     leaning toward it) and blows a sweeping gale across the isle
##     (scripts/dragon_gale.gd: streaks, thrashing trees, leaves torn off,
##     the cloud sea beyond thrown into a wake). After 45 to 60 s it lets
##     go, drops off the rim on a heavy beat and roams again. A pilot on
##     that isle is knocked by the blast as in round 1, and can take the
##     treasure off its tongue (`yielded`).
##
## Self-contained: the host (studies/aqueduct_isle.gd) makes one, calls
## `setup` and then `advance` every frame after its own camera is placed,
## and may set `air` (the breeze, about 0..1.5) and `air_angle` (its way,
## radians in x-z) each frame. V cycles a watch camera on it (chase,
## orbit, look from where you stand, off), which takes the host's camera
## over while on.
##
## Flags: --dragon-delay=<s> (3) before
## it rises; --dragon-skip=<s> runs it on that far at the start;
## --dragon-watch[=chase|orbit|look] starts watching; --dragon-seed=<n> its
## route's dice; --dragon-size=<x> (SIZE, 1.5) its scale; --dragon-attack starts
## it on its way in to an attack (the grab about 8 s on);
## --dragon-target=<isle name> its first (or only) target;
## --dragon-attack-every=<s> (70) between attacks.
##
## The downwash (docs/design/dragon-downwash/round1.md): flying (here, or
## on his wake's circuit, `wake_fly`), his wings push the air down under
## him on each downstroke and lift it over him (`downwash`, scripts/
## dragon_downwash.gd; the host reads it for the plane and the sail).
## --dragon-downwash-test keeps him circling low round the home isle,
## beating, no attacks (=glide: his own beats and glides).
##
## Sight (docs/design/dragon-vision/round1.md): flying, he looks for the
## pilot (`sight`, scripts/dragon_sight.gd) when the host gives him one
## (`sight_target`). Suspicious, his head turns to track the pilot and his
## eyes glow brighter (a call in the kit audio); spotted, he roars. Nothing
## else yet. A host may give him a fixed `loop` to fly (the vision greybox,
## studies/dragon_vision_study.gd) and turn his idle roars off
## (`idle_roars`), so a roar always means he has seen you.
##
## The body in flight (docs/design/dragon-spine/round1.md): the spine, neck,
## head and hind legs on damped springs (`spine`, scripts/dragon_spine.gd,
## every tuning constant there): each downstroke heaves the chest and the
## push travels late along the neck and into the hips and tail; turns bend
## the whole body into them; climbing he beats bigger and reaches, diving he
## tucks, levelling out he flares; gliding he breathes and shifts; the head
## held steady against the bob. The tail's rope carries on from the hips as
## posed (no hinge). Here and on his wake's circuit (`wake_fly`).

signal yielded
## The grip's beats as they happen, for a host's toasts (the vision
## greybox): "grab" (on the rim), "staggered" (the slam knocked the pilot),
## "inhale" (the tell), "blown" (the gale knocked him), "pull" (the last
## haul, the tell), "let go", "thrown" (the snap launched him).
signal grip_beat(what: String)

const MODEL := "res://assets/models/rim_dragon_c.glb"

## Flight (m, s, rad). Cruise between FLAP_BELOW and GLIDE_ABOVE: beats
## when slower, glides when faster.
const MAX_TURN := 0.36
const MAX_BANK := 0.9
const MAX_CLIMB := 0.42
const MAX_DIVE := 0.62
const FLAP_BELOW := 28.0
const GLIDE_ABOVE := 34.0
const MIN_SPEED := 22.0
const MAX_SPEED := 54.0
const THRUST := 3.4
const DRAG := 0.00055
const ARRIVE := 105.0
## Beats a second, cruising and climbing; the downstroke's share of a beat.
const BEAT := 0.3
const BEAT_CLIMB := 0.4
const DOWN := 0.5
## The wing's raise at the top and bottom of a beat, and gliding (rad).
const RAISE_UP := 1.1
const RAISE_DOWN := -0.78
const RAISE_GLIDE := 0.17
## The body's bob against a beat (m).
const BOB := 2.2
## The roar's length (s).
const ROAR := 3.6
## The attack (m, s, rad, before `size`). The grab's length; the cling's
## body pitch (nose up, belly to the cliff) and where its root hangs from
## the rim (out from it, down). How long it holds on.
const GRAB := 3.4
const CLING_PITCH := 1.12
const CLING_OUT := 7.5
const CLING_DOWN := 7.0
const CLING_HOLD := Vector2(45.0,60.0)
## The breath's beats: pant, inhale (the tell), blow, recover.
const PANT := Vector2(4.5,7.0)
const INHALE := 2.1
const BLOW := 3.8
const RECOVER := 1.3
## The blow's sweep either side of straight across the isle.
const SWEEP := 0.42
## The blow on a pilot on the isle: round 10 reads the ribbons' air
## (`_blow_on_pilot`); the knock's distance out and push are round 1's. The
## treasure is taken within TAKE_R of it.
const REACH := 70.0
const PUSH := 5.0
const KNOCK_OUT := Vector2(12.0,6.0)
const KNOCK_UP := 1.6
const TAKE_R := 3.2
## The grip's hits are hit stuns (PilotMotor `knock`, docs/design/
## roguelike/stun-round1.md; docs/design/dragon-grip/round2-greybox.md),
## the dragon their source, so they share his one restun gap with his air
## blast: the gale's knock is a hard hit, laid down BLOW_STUN_DOWN s once
## the skid stops; the snap's launch a hard throw, laid down
## LAUNCH_STUN_DOWN s where he lands. The slam staggers a pilot on the isle
## within SLAM_STAGGER_R m of the gripped rim (at TUNED_SIZE, scaled by
## `_k`: 21 m at 1.5, about where the chin comes down): a light knock in
## from the rim, SLAM_KNOCK_OUT walker heights along and SLAM_KNOCK_UP up
## (DragonAirBlast.walker_tall), down SLAM_STUN_DOWN s (0: only the
## tumble's own short lie, PilotMotor `tumble_down`).
const BLOW_STUN_DOWN := 0.8
const LAUNCH_STUN_DOWN := 1.5
const SLAM_STAGGER_R := 12.0
const SLAM_KNOCK_OUT := 3.0
const SLAM_KNOCK_UP := 0.5
const SLAM_STUN_DOWN := 0.0
## The spring launch (round 5): standing on the isle as it snaps back, the
## pilot leaves it the moment it comes up faster than he can fall (it
## slows harder than gravity), at its speed where he stands (LAUNCH_GAIN,
## at most LAUNCH_MOST m/s up), nudged in over the isle (LAUNCH_IN of that,
## so he comes down on it).
const LAUNCH_GAIN := 1.0
const LAUNCH_MOST := 32.0
const LAUNCH_IN := 0.1
## --dragon-ride: the first swoop in starts RIDE_OUT m out and RIDE_UP m
## up; it holds on RIDE_HOLD s (one blast) and pants RIDE_PANT s; let go,
## it swoops back for another grab. Round 9: 8.5 s (was 6), so the first
## pant always runs on into a blast (the slam's steep moment and ease back
## take about 3 s of it) and he has some 10 s on the walkable tilt.
const RIDE_OUT := 85.0
const RIDE_UP := 18.0
const RIDE_HOLD := 8.5
const RIDE_PANT := Vector2(2.5,3.5)
## Round 8: in the ride it goes off between grips on your isle to attack
## another motif isle (held RIDE_AWAY s, two blasts or so), then comes
## back. --dragon-ride-repeat keeps round 5's instant swoop back.
const RIDE_AWAY := 16.0
const DragonGale = preload("res://scripts/dragon_gale.gd")
const DragonDownwash = preload("res://scripts/dragon_downwash.gd")
## The air his wings push (see the header), updated every frame.
var downwash := DragonDownwash.new()
const DragonSight = preload("res://scripts/dragon_sight.gd")
## What he sees (see the header), updated every frame he flies.
var sight := DragonSight.new()
## The host's pilot to look for: returns {"points": PackedVector3Array,
## "airborne": bool} (DragonSight.pilot_points), or {} for none. Unset, he
## looks for no one.
var sight_target := Callable()
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")
## His body in flight (docs/design/dragon-spine/round1.md): the spine,
## neck, head and legs on springs, stepped in `_pose`.
const DragonSpine = preload("res://scripts/dragon_spine.gd")
var spine := DragonSpine.new()
## His cyclone blast once he spots you (scripts/dragon_cyclone.gd, docs/
## design/dragon-cyclone/round1.md): set `cyclone_on` before `setup` to
## have it (the vision greybox does); the host applies its knock and air.
var cyclone_on := false
var cyclone: Node3D
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
## His air blast (scripts/dragon_air_blast.gd, docs/design/dragon-air-blast/
## round1.md): a swift ball of air, his attack (the cyclone kept to
## compare). Set `blast_on` before `setup` to have it; with both, `attack`
## says which one he uses ("blast", the default, "cyclone" or "none":
## `set_attack` swaps it live).
var blast_on := false
var air_blast: Node3D
var attack := "blast"
## Round 2 of the grip (docs/design/dragon-grip/round2-greybox.md): with
## `attack` "grip", spotted with the pilot on (or over) an isle he can grip
## (`grip_pick`, the host's: its index in `targets`, or -1), he breaks off
## his flight to grip it (`grip_isle`), holding on `grip_hold` s (below 0,
## CLING_HOLD); let go, he rejoins his `loop` and leaves the pilot be for
## GRIP_REST s. Anywhere else he answers with his air blast.
const GRIP_REST := 8.0
var grip_pick := Callable()
var grip_hold := -1.0
var _grip_rest := 0.0
var grips := 0
## Whether the host's middle (`home`) is the starter isle, never attacked
## (`_attackable`); the vision greybox's isles are all fair game.
var spare_home := true
## His head tracking the pilot once suspicious: the most it turns (rad,
## yaw either way; pitch down and up) and how fast it gets there.
const TRACK_YAW := 1.2
const TRACK_PITCH := Vector2(-1.0,0.5)
## His eyes' glow while alert: the day and night emission times up to
## ALERT_EYE at spotted (half of that over 1 suspicious); the halos shown by
## day too at ALERT_HALO of their night strength; eased at ALERT_EASE a second.
const ALERT_EYE := 4.0
const ALERT_HALO := 1.4
const ALERT_EASE := 1.5
var _alert := 0.0
## His idle roars (every 12 to 22 s); off, he roars only on spotting you.
var idle_roars := true
## A fixed loop to fly (world points, flown through in order, round and
## round), set before `setup`; empty: his own roaming.
var loop: Array = []
## The snout's way in the head bone's rest frame (head to the jaw's tip).
var _snout := Vector3.FORWARD
var _ground_t := 0.0
var _ground_y := -INF
var _wake_flew := false
## --dragon-downwash-test: a cloverleaf over the home isle, CIRCLE_UP m
## over its top at `shadow_at`: straight over its middle, out CIRCLE_R m,
## round and back over it the other way (at most CIRCLE_SPEED m/s), each
## lap turned a little; beating unless "glide".
const CIRCLE_R := 150.0
const CIRCLE_UP := 45.0
const CIRCLE_SPEED := 24.0
var _circle := ""
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
## Its night glow (night light round 1, docs/design/night-light/round1.md),
## eased in as the lamps are (StoneLampLights.night_for, over NIGHT_FADE s):
## the eyes' emission by day and at night, the spines' and tail blade's,
## the membranes' rose edge (and how much of the membrane it lights
## through, NIGHT_MEMBRANE_REACH), an ember in the throat and mouth
## (NIGHT_THROAT colour, energy at rest and with the jaw open or breathing
## in), and a faint cool sheen on the hide so its shape reads against the
## night sky (NIGHT_SHEEN colour and energy).
const NIGHT_FADE := 2.5
const NIGHT_EYE := Vector2(2.2,7.5)
const NIGHT_SPINES := Vector2(1.6,3.6)
const NIGHT_MEMBRANE := Vector2(0.42,0.5)
const NIGHT_MEMBRANE_REACH := 0.3
const NIGHT_THROAT := Color("ff5a1e")
const NIGHT_THROAT_ENERGY := Vector2(0.9,3.2)
const NIGHT_SHEEN := Color("7d8fbf")
const NIGHT_SHEEN_ENERGY := 0.1

var camera: Camera3D
## The scene whose sky says how dark it is (its `_celestial`), set by the
## host; without one the dragon keeps its day look.
var sky_scene: Node = null
## 0 by day .. 1 at night, eased; its materials by key, to light at night.
var night := 0.0
var _night_materials := {}
var sea_y := -120.0
var home := Vector3.ZERO
var home_top := 30.0
var isles: Array = []
## Its scale, flying and asleep on its roost alike (scripts/dragon_roost.gd;
## docs/design/dragon-roost/round2.md). TUNED_SIZE is the size its grip's
## reach and the treasure were tuned at (they scale from it).
const SIZE := 1.5
const TUNED_SIZE := 0.85
var size := SIZE
var delay := 3.0
var _skip := 0.0
var _rng := RandomNumberGenerator.new()
## The isle's breeze (the host sets these each frame).
var air := 0.4
var air_angle := 0.0
## Where a low pass's shadow should cross (the turf's middle; the host may
## set it before `setup`, else the isle's middle at its top).
var shadow_at := Vector3.INF
## The attack's isles: each {name, home (world; y the rim), radius}; the
## host's lookup for an isle's built record ({node, shape, ...}) by name;
## its call to flush the isle's birds (home). The pilot (PilotMotor) and
## his ground's slide, and whether he is on foot (the host sets it).
var targets: Array = []
var find_isle: Callable
## Round 7: --dragon-target picked the first; the last one it attacked.
var _target_forced := false
## Whether the last pick was --dragon-target's (held even without room).
var _target_forced_was := false
var _last_target := -1
var _grip_note := ""
var _best_score := 0.0
var flush_birds: Callable
var walker: Object
var slide: Callable
var on_foot := true
var taken := false

var model: Node3D
var skeleton: Skeleton3D
var _bone := {}
var _rest_local := {}
var _rest_global := {}
var _tail_n := 0
var _neck_n := 0

## "waiting", "rising", "roaming".
var state := "waiting"
var _t := 0.0
var _clock := 0.0
## The flight: where, heading (yaw; 0 faces -z), path angle (gamma), speed,
## the turn's rate, the bank (positive rolls the right side up: a left
## turn).
var pos := Vector3.ZERO
var yaw := 0.0
var gamma := 0.0
var speed := 24.0
var yaw_rate := 0.0
var roll := 0.0
var route: Array = []
var _leg_kinds: Array = []
var leg_kind := "rise"
var _legs_since_pass := 0
## Beats: the beat's phase (0 the top), the flapping's weight, whether a
## bout is on and its beats left, the raise last frame (for the tips' lag).
var phase := 0.0
var flap_w := 1.0
var _bout := true
var _bout_left := 3
var _last_raise := RAISE_UP
var _tip_lag := 0.0
var mode := "climb"
## Riding the air: the swell's vertical speed now, the roll and pitch it
## gives, a bump (a spring kicked now and then) and when the next comes.
var _swell := 0.0
var _swell_y := 0.0
var _air_roll := 0.0
var _air_pitch := 0.0
var _bump := Vector2.ZERO
var _bump_v := Vector2.ZERO
var _bump_next := 5.0
## The neck's lead into a turn (a spring), the head's look (yaw, pitch
## springs).
var _lead := 0.0
var _lead_v := 0.0
var _look := Vector2.ZERO
var _look_v := Vector2.ZERO
var _trim := Vector2.ZERO
## The mouth: the jaw on a spring toward its goal, the lower lip's follow,
## the roar's clock (counting up while one runs, -1 between), a chew's.
var _jaw := 0.0
var _jaw_v := 0.0
var _lip := 0.0
var _lip_v := 0.0
var _roar_t := -1.0
var _roar_next := 9.0
var _chew_t := -1.0
var _chew_next := 4.0
var _chew_size := 0.1
var _rear := 0.0
var _rear_v := 0.0
## The tail's rope (world points from the hips to the tip), last frame's,
## each segment's length and rest direction (skeleton space).
var _rope: PackedVector3Array = []
var _rope_prev: PackedVector3Array = []
var _seg_len: PackedFloat32Array = []
var _seg_dir: Array = []
var _tail_start := Vector3.ZERO
var _rope_ready := false
## The watch camera: "", "chase", "orbit", "look".
var watch := ""
var _watch_eye := Vector3.ZERO
var _watch_look := Vector3.ZERO
var _watch_from := Vector3.ZERO
var _orbit := 0.0
## Pose checks (captures): --dragon-hold keeps it in place at 120 m over the
## isle's east; --dragon-phase=<0..1> holds a beat there (flapping), or
## --dragon-pose=glide|dive|roar; --dragon-orbit=<deg> fixes the orbit's
## angle from its nose (90 its right side, 0 head on, 180 behind);
## --dragon-orbit-up=<m> its height (38), --dragon-orbit-far=<m> (130).
var _hold := false
var _hold_phase := -1.0
var _hold_pose := ""
var _orbit_fixed := INF
var _orbit_up := 38.0
var _orbit_far := 130.0
var _watch_fresh := true
var _toast: Label
var _fov := -1.0
## --dragon-log: a line every 2 s (where, what it is doing).
var _log := false
var _log_t := 0.0
## --dragon-pass: starts on the low pass's way in (its shadow over the isle
## about 12 s on).
var _pass_now := false
## How free in the air it is (1 flying; the swell and bumps fade out as it
## grabs) and how far into the grab's flare.
var _free := 1.0
var _flare := 0.0
## The attack: the next target's index, the seconds till the next attack,
## the grip ({rim, out, tangent, root, yaw, wrists, feet}), the grab's
## start (pos, velocity, yaw, pitch, roll), the cling's clock and what the
## breath is doing ("settle", "pant", "inhale", "blow", "recover") and for
## how long; the effects.
var _attack_now := false
var _target_i := 0
var _attack_in := 40.0
var _attack_every := 70.0
var grip := {}
var _grab := {}
var _cling_t := 0.0
var _cling_left := 50.0
var breath := ""
var _breath_t := 0.0
var _breath_len := 0.0
var _sweep_from := 0.0
## The head's look turned to the world's way round (1 or -1: the neck's
## turn about its root runs one way or the other with the pose).
var _sweep_sign := 1.0
var _knocked := false
var gale: Node3D
var treasure: Node3D
var _treasure_light: OmniLight3D
var _glint: MeshInstance3D
## The cling's springs: the head's look round (yaw, pitch), the rear back
## (inhale) and thrust (blow), the body's settle from the slam.
var _c_look := Vector2.ZERO
var _c_look_v := Vector2.ZERO
var _c_look_goal := Vector2.ZERO
var _c_look_next := 0.0
var _c_rear := 0.0
var _c_rear_v := 0.0
var _c_settle := 0.0
var _c_settle_v := 0.0
var _jaw_goal := -1.0
## A blend from a pose snapshot (bone -> rotation) over `_blend_len` s.
var _blend_from := {}
var _blend_t := 0.0
var _blend_len := 0.0
## --dragon-ride (round 5): the pilot on foot on the target isle, the
## dragon swooping in to grip it over and over.
var ride := false
var ride_repeat := false
## The ride's own isle (index in `targets`), and the next other one.
var _ride_home := -1
var _ride_away := 0
## When each target was last attacked (index -> clock): normal mode goes to
## the one left longest.
var _attacked_at := {}
## --dragon-cling=<s>: how long it holds on outside the ride (checks).
var _cling_for := -1.0
var _ride_vy := 0.0
var launched := 0
## On the rim (round 6): the head, jaw, neck and thumbs kept on or over the
## isle's turf as it is posed now (rays on its colliders), the chin laid flush
## on the turf between blasts, Odyssey-style: the lower jaw lies on the
## ground and the head lifts off it to pant, inhale and blow.
## Probes are [bone, point in the bone's rest frame] on the mesh's underside
## (scripts measured off rim_dragon_c.glb: the jaw's floor, its sides, the
## snout, the neck's underside, the thumb claws' tips).
const TURF_LAYER := 1 << 11
const SOLID_LAYER := 1
## Each neck bone's share of the lift that lowers the head onto the turf.
const LIFT_SHARE := [0.4,0.3,0.2,0.1]
## The chin's gap over the turf when it lies there (m).
const CHIN_GAP := 0.04
## The thumbs' claws sit this far inside the lip (m, at TUNED_SIZE; scaled
## by `_k`).
const THUMB_IN := 0.9
## A neck probe further under the turf than this is under the lip's
## overhang beside the cliff, not in it (m, at TUNED_SIZE; scaled by `_k`).
const NECK_DEEP := 3.0
## Round 9: no auto-surf on the tipped isle (round 6's RIDE_SLIDE_AUTO is
## gone). He surfs only when he crouches (or carves), as on any slope.
## The last pull's length before it lets go (scripts/dragon_gale.gd
## PULL_TIME).
const PULL := 0.85
var _probes_head: Array = []
var _probes_neck: Array = []
var _chin_back: Array = []
var _chin_front: Array = []
var _gem_on: Array = []
var _chin_box: Array = []
var _thumb: Dictionary = {}
var _rest_w := 0.0
var _rest_lift := 0.0
var _rest_nod := 0.0
## Round 8: the rest's lift and nod as laid on, sprung toward the solve.
var _rest_app := Vector2.ZERO
var _rest_app_v := Vector2.ZERO
var _rest_dt := 1.0/60.0
var _heave_hz := 0.22
var _heave_ph := 0.0
## Round 8: the body's turn as shown, eased toward its pose each frame, so
## a change of state (the slam, the let-go, the grab) never snaps it.
var _body_q := Quaternion.IDENTITY
var _body_q_on := false
const BODY_EASE := 10.0
var _neck_look := Vector2.ZERO
var _neck_base: Array = []
## Logged: the chin's miss from flush (back, front; m) when last laid down.
var chin_miss := Vector2.ZERO
var _ray := PhysicsRayQueryParameters3D.new()
var chin: StaticBody3D
## Logged: the deepest any probe sat in the turf this hold (m, before the
## lift), and after it.
var sunk_before := 0.0
var sunk_after := 0.0
## Logged (round 8): how the snout moves against the body while it holds on
## (m/s and m/s², in the body's frame): the most it moved and the most it
## jerked, since the last line. A heavy animal's head moves smoothly.
var _tip_was := Vector3.INF
var _tip_v := Vector3.ZERO
var tip_speed := 0.0
var tip_jerk := 0.0

func _init() -> void:
	name = "SkyDragon"
	sight.state_changed.connect(_on_sight)

func setup(cam: Camera3D, args: PackedStringArray, sea: float, middle: Vector3, top: float, isle_list: Array) -> void:
	camera = cam
	sea_y = sea
	home = middle
	home_top = top
	isles = isle_list
	_rng.seed = 7
	for arg in args:
		if arg.begins_with("--dragon-delay="): delay = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-skip="): _skip = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-seed="): _rng.seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-size="): size = float(arg.get_slice("=",1))
		elif arg == "--dragon-log": _log = true
		elif arg == "--dragon-walk-check": _walk_check = true
		elif arg == "--dragon-pass": _pass_now = true
		elif arg == "--dragon-attack": _attack_now = true
		elif arg == "--dragon-ride": ride = true
		elif arg.begins_with("--dragon-cling="): _cling_for = float(arg.get_slice("=",1))
		elif arg == "--dragon-ride-repeat":
			ride = true
			ride_repeat = true
		elif arg.begins_with("--dragon-attack-every="): _attack_every = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-target="):
			var want := arg.get_slice("=",1)
			for i in range(targets.size()):
				if str(targets[i].name) == want:
					_target_i = i
					_target_forced = true
			if not _target_forced: push_warning("sky dragon: no target '%s'" % want)
		elif arg == "--dragon-hold": _hold = true
		elif arg.begins_with("--dragon-phase="): _hold_phase = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-pose="): _hold_pose = arg.get_slice("=",1)
		elif arg.begins_with("--dragon-orbit="): _orbit_fixed = deg_to_rad(float(arg.get_slice("=",1)))
		elif arg.begins_with("--dragon-orbit-up="): _orbit_up = float(arg.get_slice("=",1))
		elif arg.begins_with("--dragon-orbit-far="): _orbit_far = float(arg.get_slice("=",1))
		elif arg == "--dragon-watch": watch = "chase"
		elif arg == "--dragon-downwash-test": _circle = "beat"
		elif arg == "--dragon-downwash-test=glide": _circle = "glide"
		elif arg.begins_with("--dragon-watch="): watch = arg.get_slice("=",1)
	if _attack_now and not args_have(args,"--dragon-delay="): delay = 0.3
	_attack_in = _attack_every*0.55
	if _circle != "" or not loop.is_empty():
		_attack_in = INF
		if not args_have(args,"--dragon-delay="): delay = 0.5
	_build()
	_build_treasure()
	gale = DragonGale.new()
	gale.sea_y = sea_y
	add_child(gale)
	if cyclone_on:
		cyclone = DragonCyclone.new()
		add_child(cyclone)
	if blast_on:
		air_blast = DragonAirBlast.new()
		add_child(air_blast)
	# A host with only the cyclone gets it.
	if attack == "blast" and air_blast == null and cyclone != null: attack = "cyclone"
	set_attack(attack)
	_start()
	if ride and not targets.is_empty():
		# The isle is small for its neck: its chin sweeps most of it, and
		# the gem would be taken by standing still. Left out for the ride.
		if not args.has("--dragon-ride-gem"):
			taken = true
			treasure.visible = false
		_ride_in()
	print("sky dragon: rises in %.1f s" % delay)

static func args_have(args: PackedStringArray, prefix: String) -> bool:
	for arg in args:
		if arg.begins_with(prefix): return true
	return false

# --- Building ---------------------------------------------------------------------

func _build() -> void:
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	model.scale = Vector3.ONE*size
	skeleton = _find_skeleton(model)
	for i in range(skeleton.get_bone_count()):
		var b := skeleton.get_bone_name(i)
		_bone[b] = i
		_rest_local[b] = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		_rest_global[b] = skeleton.get_bone_global_rest(i).basis.orthonormalized()
	while _bone.has("tail.%d" % _tail_n): _tail_n += 1
	while _bone.has("neck.%d" % _neck_n): _neck_n += 1
	_build_probes()
	_dress(model)
	model.visible = false
	if _bone.has("head") and _bone.has("jaw.tip"):
		var head_rest := skeleton.get_bone_global_rest(_bone["head"])
		var tip := head_rest.affine_inverse()*skeleton.get_bone_global_rest(_bone["jaw.tip"]).origin
		if tip.length() > 0.001: _snout = tip.normalized()
	if chin != null: sight.exclude = [chin.get_rid()]
	# The tail's rest: the hips' end to the tip, in the skeleton's frame.
	var pts: Array = []
	for i in range(_tail_n): pts.append(skeleton.get_bone_global_rest(_bone["tail.%d" % i]).origin)
	pts.append(pts[_tail_n-1]+(pts[_tail_n-1]-pts[_tail_n-2])*0.9)
	_tail_start = pts[0]
	for i in range(_tail_n):
		_seg_len.append((pts[i+1]-pts[i]).length())
		_seg_dir.append((pts[i+1]-pts[i]).normalized())

## The probes (see `_probes_head`), each [bone index, point in its rest
## frame], and the chin's collider.
func _build_probes() -> void:
	var at := func(b: String, p: Vector3) -> Array:
		if not _bone.has(b): return []
		var i: int = _bone[b]
		return [i,skeleton.get_bone_global_rest(i).affine_inverse()*p]
	_chin_back = at.call("jaw",Vector3(0.0,3.1,-26.0))
	_chin_front = at.call("jaw.tip",Vector3(0.0,4.25,-34.0))
	_gem_on = at.call("jaw",Vector3(0.0,5.9,-33.5))
	_chin_box = at.call("jaw",Vector3(0.0,4.4,-29.0))
	for spec: Array in [["jaw",Vector3(0,3.1,-26)],["jaw",Vector3(2.2,3.8,-26)],["jaw",Vector3(-2.2,3.8,-26)],
			["jaw",Vector3(0,3.5,-29.5)],["jaw",Vector3(1.8,3.9,-30)],["jaw",Vector3(-1.8,3.9,-30)],
			["jaw.tip",Vector3(0,3.9,-32)],["jaw.tip",Vector3(0,4.25,-34)],["jaw.tip",Vector3(0,4.68,-36)],
			["head",Vector3(1.3,4.7,-24)],["head",Vector3(-1.3,4.7,-24)],["head",Vector3(1.8,4.5,-30)],
			["head",Vector3(-1.8,4.5,-30)],["head",Vector3(0,4.5,-34.5)],["head",Vector3(0,5.0,-36.5)]]:
		var pr: Array = at.call(spec[0],spec[1])
		if not pr.is_empty(): _probes_head.append(pr)
	for spec: Array in [["neck.3",Vector3(0,4.6,-22.5)],["neck.2",Vector3(0,4.2,-19)],["neck.2",Vector3(0,4.1,-18)],
			["neck.1",Vector3(0,2.1,-16)],["neck.1",Vector3(0,3.4,-17.5)]]:
		var pr: Array = at.call(spec[0],spec[1])
		if not pr.is_empty(): _probes_neck.append(pr)
	for n in ["L","R"]:
		var k := -1.0 if n == "L" else 1.0
		_thumb[n] = [at.call("wing_hand."+n,Vector3(33.53*k,2.44,-6.82)),at.call("wing_hand."+n,Vector3(33.38*k,3.84,-5.49)),at.call("wing_hand."+n,Vector3(33.0*k,4.8,-3.2))]
	# The chin: a box on the lower jaw while it clings, so the pilot slides
	# up against it (not through it) and the gem on the tongue is in reach.
	chin = StaticBody3D.new()
	chin.name = "Chin"
	chin.top_level = true
	chin.collision_layer = 0
	chin.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(4.6,2.4,10.0)*size
	var shape := CollisionShape3D.new()
	shape.shape = box
	chin.add_child(shape)
	add_child(chin)
	_ray.collide_with_areas = false
	_ray.exclude = [chin.get_rid()]

## A probe's place now (world).
func _probe(pr: Array) -> Vector3:
	return skeleton.global_transform*(skeleton.get_bone_global_pose(int(pr[0]))*(pr[1] as Vector3))

## The isle's top under `p` (world) on `mask`'s layers, -INF over nothing.
func _turf_y(space: PhysicsDirectSpaceState3D, p: Vector3, mask: int) -> float:
	_ray.from = p+Vector3.UP*30.0
	_ray.to = p+Vector3.DOWN*40.0
	_ray.collision_mask = mask
	var hit := space.intersect_ray(_ray)
	return (hit.position as Vector3).y if not hit.is_empty() else -INF

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null: return s
	return null

func _dress(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "dragon_membrane_glow": _tag_membrane(mi,i)
			elif m != null and HIDE_TONES.has(m.resource_name): _bake_hide(mi,i,m.resource_name)
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			mi.set_surface_override_material(i,_material(m.resource_name if m != null else ""))
			if m != null and m.resource_name == "dragon_eye": _find_eyes(mi,i)
		# Its shadow over the isles: the wings' too (two-sided).
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		# The wings reach far from the rest pose's bounds.
		mi.extra_cull_margin = 60.0
	for c in n.get_children(): _dress(c)

## The weathered hide (shaders/olmec_stone.gdshader, the Olmec's and the rune
## serpent's stone): each surface's tone by the model's names (sRGB), the
## weathering's strength and the scale beads' (0 none).
const HIDE_TONES := {
	"dragon_hide": [Color("40364c"),0.4,1.0],
	"dragon_belly": [Color("5c5064"),0.4,0.8],
	"dragon_horn": [Color("8a8090"),0.6,0.0],
	"dragon_claw": [Color("d8d0c2"),0.6,0.0],
	"dragon_tooth": [Color("cbc2ae"),0.4,0.0],
}
## The grain's rest place is the vertex's, this many times (the model is
## ~100 m across): a scale bead PEBBLE m, mottled washes some 10 m.
const GRAIN := 0.3
const PEBBLE := 0.8
const HIDE_SHADER := preload("res://shaders/olmec_stone.gdshader")

## Bakes what the stone shader reads onto a surface, as the rune serpent's
## faces carry it: COLOR the tone times its occlusion (alpha the occlusion),
## UV and UV2.x where the vertex lies at rest (so the grain rides on the
## body). The occlusion is read off the mesh: a vertex below the mean of
## its neighbours (across the flat-shaded seams, welded by position) lies in
## a crevice, one above it stands clear; faces turned down are darker.
func _bake_hide(mi: MeshInstance3D, surface: int, key: String) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null or src.get_blend_shape_count() > 0: return
	var arrays := src.surface_get_arrays(surface)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if points.is_empty() or normals.size() != points.size() or index.is_empty(): return
	var keys := PackedInt32Array()
	keys.resize(points.size())
	var ids := {}
	for k in range(points.size()):
		var p := mi.transform*points[k]
		var cell := Vector3i((p*50.0).round())
		if not ids.has(cell): ids[cell] = ids.size()
		keys[k] = ids[cell]
	var sum := PackedVector3Array()
	sum.resize(ids.size())
	var count := PackedFloat32Array()
	count.resize(ids.size())
	var place := PackedVector3Array()
	place.resize(ids.size())
	for t in range(0,index.size(),3):
		for e in range(3):
			var a := index[t+e]
			var b := index[t+(e+1)%3]
			sum[keys[a]] += mi.transform*points[b]
			count[keys[a]] += 1.0
			place[keys[a]] = mi.transform*points[a]
	var tone: Color = (HIDE_TONES[key][0] as Color).srgb_to_linear()
	var colours := PackedColorArray()
	colours.resize(points.size())
	var uv := PackedVector2Array()
	uv.resize(points.size())
	var uv2 := PackedVector2Array()
	uv2.resize(points.size())
	for k in range(points.size()):
		var id := keys[k]
		var p := place[id]
		var n := (mi.transform.basis*normals[k]).normalized()
		var mean := sum[id]/maxf(count[id],1.0)
		# Metres of dip into the neighbours' mean, over a stride's length.
		var dip := (mean-p).dot(n)/maxf((mean-p).length()+0.8,0.001)
		var occ := clampf(0.8-dip*0.8+minf(n.y,0.0)*0.2,0.4,1.0)
		var shade := lerpf(0.55,1.0,occ)
		colours[k] = Color(tone.r*shade,tone.g*shade,tone.b*shade,occ)
		var rest := p*GRAIN
		uv[k] = Vector2(rest.x,rest.y)
		uv2[k] = Vector2(rest.z,0.0)
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	_replace_surface(mi,surface,arrays)

## `mi`'s mesh with one surface's arrays swapped, the rest and the skin kept.
func _replace_surface(mi: MeshInstance3D, surface: int, arrays: Array) -> void:
	var src := mi.mesh as ArrayMesh
	var mesh := ArrayMesh.new()
	for i in range(src.get_surface_count()):
		var a := arrays if i == surface else src.surface_get_arrays(i)
		var format := src.surface_get_format(i) & ~(Mesh.ARRAY_FORMAT_VERTEX|Mesh.ARRAY_FORMAT_NORMAL|Mesh.ARRAY_FORMAT_TANGENT|Mesh.ARRAY_FORMAT_COLOR|Mesh.ARRAY_FORMAT_TEX_UV|Mesh.ARRAY_FORMAT_TEX_UV2|Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS|Mesh.ARRAY_FORMAT_INDEX)
		format &= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(src.surface_get_primitive_type(i),a,[],{},format)
		mesh.surface_set_material(i,src.surface_get_material(i))
		mesh.surface_set_name(i,src.surface_get_name(i))
	mi.mesh = mesh

## The membranes' panels, tagged for the night glow (night light round 2,
## docs/design/night-light/round2.md). The model's membrane is one grid
## panel per span (art/blender/rim_dragon/dragon_body_build.py `panel`):
## the arm's panel runs shoulder to knuckle in u and leading edge (the arm)
## to trailing edge in v; each finger's runs knuckle to free edge in u and
## finger to finger in v. So UV alone can't say where the free edge is.
## Each panel (a connected piece of the surface) gets a vertex colour: r how
## near the free trailing edge, g how far from any bone (thin membrane), b
## the coordinate the veins cross (they run from the bones to the edge).
## The arm panels are the two pieces reaching nearest the body.
func _tag_membrane(mi: MeshInstance3D, surface: int) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null or src.get_blend_shape_count() > 0: return
	var arrays := src.surface_get_arrays(surface)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if uvs.size() != points.size() or index.is_empty(): return
	# Union-find over the triangles: the panels share no vertices.
	var parent := PackedInt32Array()
	parent.resize(points.size())
	for k in range(points.size()): parent[k] = k
	var root := func(k: int) -> int:
		while parent[k] != k:
			parent[k] = parent[parent[k]]
			k = parent[k]
		return k
	for t in range(0,index.size(),3):
		var a: int = root.call(index[t])
		for e in [index[t+1],index[t+2]]:
			var b: int = root.call(e)
			if a != b: parent[b] = a
	var nearest := {}
	for k in range(points.size()):
		var r: int = root.call(k)
		var x := absf((mi.transform*points[k]).x)
		nearest[r] = minf(nearest.get(r,INF),x)
	var order: Array = nearest.keys()
	order.sort_custom(func(a,b) -> bool: return nearest[a] < nearest[b])
	var arm := order.slice(0,2)
	var colours := PackedColorArray()
	colours.resize(points.size())
	for k in range(points.size()):
		var u := uvs[k].x
		var v := uvs[k].y
		if root.call(k) in arm:
			colours[k] = Color(v,smoothstep(0.0,0.35,v)*smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.88,1.0,u)),u*6.0,1.0)
		else:
			colours[k] = Color(u,pow(sin(PI*v),0.7)*smoothstep(0.0,0.12,u),v,1.0)
	arrays[Mesh.ARRAY_COLOR] = colours
	_replace_surface(mi,surface,arrays)

## The game's materials, by the model's names: a dark basalt-violet hide
## (satin in a and b, matte stone in c), the lips the hide, the mouth a
## deep maroon going near black, ivory teeth, pale horn and claws, violet
## membranes (c: soft and glowing toward the trailing edge).
func _material(key: String) -> Material:
	var made := _made_material(key)
	if key in ["dragon_membrane_glow","dragon_eye","dragon_glow","dragon_mouth","dragon_tongue","dragon_hide","dragon_belly"]:
		if not _night_materials.has(key): _night_materials[key] = []
		_night_materials[key].append(made)
	return made

func _made_material(key: String) -> Material:
	if key == "dragon_membrane_glow": return _glow_membrane()
	if key == "dragon_glow": return _glow_spine()
	if HIDE_TONES.has(key):
		var h := ShaderMaterial.new()
		h.shader = HIDE_SHADER
		h.resource_name = key
		h.set_shader_parameter("weather",HIDE_TONES[key][1])
		h.set_shader_parameter("pebble",HIDE_TONES[key][2])
		h.set_shader_parameter("pebble_size",PEBBLE*GRAIN)
		# Scaled hide for the body, belly and the horn's and claws' keratin
		# (long ridged and plain); the teeth stay enamel.
		h.set_shader_parameter("reptile",1.0 if key != "dragon_tooth" else 0.0)
		# The scales run from near black to a violet-slate, as the hide
		# always did; the rim light a cool violet sheen.
		h.set_shader_parameter("scale_a",Vector3(0.55,0.5,0.62))
		h.set_shader_parameter("scale_b",Vector3(1.35,1.2,1.5))
		h.set_shader_parameter("rim",0.3)
		h.set_shader_parameter("roughness_value",0.8 if key == "dragon_hide" or key == "dragon_belly" else 0.6)
		return h
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.roughness = 0.6
	match key:
		"dragon_mouth":
			m.albedo_color = Color("2a1117")
			m.roughness = 0.7
			m.metallic_specular = 0.2
		"dragon_tongue":
			m.albedo_color = Color("3d1820")
			m.roughness = 0.55
			m.metallic_specular = 0.35
		"dragon_eye":
			m.albedo_color = Color("ffc040")
			m.emission_enabled = true
			m.emission = Color("ffb030")
			m.emission_energy_multiplier = 2.2
		"dragon_membrane":
			m.albedo_color = Color("3a2e46")
			m.roughness = 0.75
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.backlight_enabled = true
			m.backlight = Color("40243e")
		_:
			m.albedo_color = Color("4a3d5a")
	return m

## The wildcard's membrane: smooth, a deep violet at the bones going to a
## soft rose glow at the trailing edge, lit through from behind. At night
## (night light round 2) the panel goes dark and leathery and glows from
## within: an ember rose strongest at the free trailing edge and along the
## veins, falling off smoothly toward the bones (the panels' vertex colours,
## `_tag_membrane`: r near the edge, g away from the bones, b across the
## veins), with a faint warmth through the thin middle so no panel goes
## flat black.
static func _glow_membrane() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 deep : source_color = vec3(0.24, 0.17, 0.32);
uniform vec3 edge : source_color = vec3(0.45, 0.32, 0.56);
uniform vec3 glow : source_color = vec3(0.96, 0.64, 0.74);
uniform float glow_energy = 0.42;
// 0 by day, 1 at night.
uniform float night = 0.0;
uniform float night_reach = 0.3;
// The night look: the leathery hide's colour, the ember glowing through it,
// how strong the glow is at the trailing edge, along the veins and through
// the thin middle, how tight the veins are and how far in the edge reaches.
uniform vec3 night_hide : source_color = vec3(0.17, 0.13, 0.19);
uniform vec3 night_ember : source_color = vec3(0.88, 0.44, 0.42);
uniform float night_energy = 1.0;
uniform float night_edge = 1.0;
uniform float night_vein = 0.45;
uniform float night_body = 0.16;
uniform float vein_width = 0.07;
varying vec3 tag;
varying vec3 mp;
vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
// Cellular: x nearest distance, y second, z nearest cell's number.
vec3 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = h33(i + g);
				float d = length(g + o - f);
				if (d < d1) { d2 = d1; d1 = d; id = o.x; }
				else if (d < d2) { d2 = d; }
			}
		}
	}
	return vec3(d1, d2, id);
}
float h21(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	tag = COLOR.rgb;
	mp = VERTEX;
}
void fragment() {
	float v = UV.y;
	float vein = smoothstep(0.92, 1.0, fract(UV.x * 3.0 + 0.5)) * (1.0 - v) * 0.25;
	vec3 base = mix(deep, edge, smoothstep(0.2, 1.0, v));
	// Weathered hide, as the body's stone: mottled washes, stippled flecks
	// and scuffs, worked in the panel's own coordinates, faded by the
	// pixel's footprint there so it never shimmers.
	vec2 q = UV * vec2(40.0, 24.0);
	float foot = length(fwidth(q));
	float far = 1.0 - smoothstep(0.35, 1.2, foot);
	float wash = vn(q * 0.22 + 3.0) * 0.6 + vn(q * 0.5 + 9.0) * 0.4;
	float fleck = vn(q * 2.2 + 5.0);
	float scuff = smoothstep(0.7, 0.9, vn(q * vec2(0.5, 1.6) + 1.0));
	float tone = mix(0.6, 1.4, wash) * (1.0 + (fleck - 0.5) * 0.5 * far) * (1.0 - scuff * 0.3);
	base *= tone;
	// Fine scales over the whole membrane, in the model's own space (so the
	// grain is one size on every panel and rides the wing): a bead each
	// with its own tone, dark seams, a slow wrinkle across them.
	vec3 mq = mp * 1.7;
	float mpx = length(fwidth(mq));
	float mfar = 1.0 - smoothstep(0.35, 1.1, mpx);
	vec3 mc = cells(mq);
	float mgap = mc.y - mc.x;
	float mseam = 1.0 - smoothstep(0.0, max(0.12, mpx * 1.5), mgap);
	float mdome = smoothstep(0.0, 0.5, mgap);
	float wrinkle = vn(mp.xz * 0.35 + mp.y * 0.2 + 7.0) * 0.6 + vn(mp.xz * 0.9 + 2.0) * 0.4;
	base *= mix(1.0, mix(0.65, 1.35, mc.z) * mix(0.8, 1.15, mdome) * (1.0 - mseam * 0.6), 0.25 + 0.75 * mfar);
	base *= mix(0.8, 1.2, wrinkle);
	float grainmul = mix(1.0, mix(0.55, 1.35, mc.z) * (1.0 - mseam * 0.7), 0.3 + 0.7 * mfar) * mix(0.75, 1.25, wrinkle);
	float mh = (mdome * 0.1 / 1.7 * mfar + (wrinkle - 0.5) * 0.35);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 grad = sign(det) * (dFdx(mh) * r1 + dFdy(mh) * r2);
	NORMAL = normalize(abs(det) * NORMAL - 2.0 * grad);
	float breathe = 0.85 + 0.15 * sin(TIME * 1.3 + UV.x * 4.0);
	float band = smoothstep(0.55, 1.0, v);
	vec3 day_emission = glow * glow_energy * band * breathe * grainmul;
	// Night: near the free edge (eased so it falls off smoothly), the veins
	// (soft lines, brighter toward the edge), and the thin middle.
	float trail = clamp(tag.r, 0.0, 1.0);
	float thin = clamp(tag.g, 0.0, 1.0);
	float d = abs(fract(tag.b) - 0.5);
	float vline = exp(-(d * d) / (vein_width * vein_width));
	float reach = 1.0 - night_reach;
	float rim = pow(smoothstep(reach - 0.2, 1.0, trail), 2.2);
	float inner = night_edge * rim * (0.35 + 0.65 * thin)
		+ night_vein * vline * smoothstep(0.1, 1.0, trail) * thin
		+ night_body * thin;
	vec3 night_emission = night_ember * night_energy * inner * (0.9 + 0.1 * sin(TIME * 1.1 + tag.b * 2.0));
	ALBEDO = mix(base * (1.0 - vein), night_hide, night);
	ROUGHNESS = mix(0.8, 0.7, night);
	SPECULAR = 0.25;
	BACKLIGHT = mix(edge * 0.8 * grainmul, night_ember * 0.25, night);
	EMISSION = mix(day_emission, night_emission, night);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.resource_name = "dragon_membrane_glow"
	return m

## The back spines and the tail's blade: warm horn, ridged along its length
## and ringed with growth, flecked and pitted, glowing dim and warm from
## within (`energy`, NIGHT_SPINES) most through the grooves' thin horn. The
## grain is the model's own space, so it rides the body.
static func _glow_spine() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec3 horn : source_color = vec3(0.86, 0.62, 0.42);
uniform vec3 dark : source_color = vec3(0.32, 0.2, 0.17);
uniform vec3 glow : source_color = vec3(1.0, 0.6, 0.32);
uniform float energy = 1.6;
varying vec3 mp;
float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	mp = VERTEX;
}
void fragment() {
	float foot = length(fwidth(mp));
	float far = 1.0 - smoothstep(0.25, 1.0, foot);
	// Ridges run up the spine (long in y), fine across; rings of growth.
	float ridge = vn(vec3(mp.x * 5.0, mp.y * 0.7, mp.z * 5.0));
	float ridge2 = vn(vec3(mp.x * 13.0, mp.y * 1.6, mp.z * 13.0));
	float ring = smoothstep(0.55, 0.95, abs(sin(mp.y * 2.4 + ridge * 2.0)));
	float fleck = vn(mp * 7.0 + 3.0);
	float pit = smoothstep(0.78, 0.9, vn(mp * 11.0 + 9.0));
	float grain = mix(0.5, ridge * 0.6 + ridge2 * 0.4, 0.4 + 0.6 * far);
	vec3 c = mix(dark, horn, smoothstep(0.2, 0.8, grain));
	c *= 1.0 - ring * 0.25 * (0.4 + 0.6 * far);
	c *= 1.0 - pit * 0.5 * far;
	c *= 0.85 + 0.3 * fleck;
	// A little relief from the ridges.
	float h = (grain - 0.5) * 0.06;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	NORMAL = normalize(abs(det) * NORMAL - sign(det) * (dFdx(h) * r1 + dFdy(h) * r2));
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	EMISSION = glow * energy * (0.35 + 0.65 * smoothstep(0.15, 0.85, grain)) * (1.0 - ring * 0.3);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.resource_name = "dragon_glow"
	return m

## The eyes' middles (the eye surface's vertices either side of the
## midline, in the skeleton's rest frame), held in the head bone's frame
## for their night halos.
func _find_eyes(mi: MeshInstance3D, surface: int) -> void:
	if not _bone.has("head"): return
	var arrays := mi.mesh.surface_get_arrays(surface)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sums := [Vector3.ZERO,Vector3.ZERO]
	var counts := [0,0]
	for p in points:
		var k := 0 if p.x < 0.0 else 1
		sums[k] += p
		counts[k] += 1
	var head_rest := skeleton.get_bone_global_rest(_bone["head"]).affine_inverse()
	for k in range(2):
		if counts[k] > 0: _eye_points.append(head_rest*(mi.transform*(sums[k]/float(counts[k]))))

## The eyes' halos at night: soft warm glows round each eye (the stone
## lamps' halo, shaders/stone_lamp_halo.gdshader), NIGHT_EYE_HALO m across
## at the model's scale 1, at NIGHT_EYE_HALO_STRENGTH.
const NIGHT_EYE_HALO := 4.2
const NIGHT_EYE_HALO_STRENGTH := 1.0
## Round 2: the halo is drawn this share of its size toward the eye, so the
## head doesn't hide half of it.
const NIGHT_EYE_HALO_LIFT := 0.35
var _eye_points: Array[Vector3] = []
var _eye_halos: MultiMeshInstance3D = null
var _eye_halo_material: ShaderMaterial = null

func _place_eye_halos() -> void:
	if _eye_points.is_empty(): return
	if _eye_halos == null:
		_eye_halo_material = ShaderMaterial.new()
		_eye_halo_material.shader = preload("res://shaders/stone_lamp_halo.gdshader")
		_eye_halo_material.set_shader_parameter("tint",Color("ffb030"))
		_eye_halo_material.set_shader_parameter("toward_eye",NIGHT_EYE_HALO_LIFT)
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		_eye_halos = MultiMeshInstance3D.new()
		_eye_halos.name = "EyeHalos"
		_eye_halos.multimesh = MultiMesh.new()
		_eye_halos.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		_eye_halos.multimesh.mesh = quad
		_eye_halos.multimesh.instance_count = _eye_points.size()
		_eye_halos.material_override = _eye_halo_material
		_eye_halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eye_halos.top_level = true
		add_child(_eye_halos)
	_eye_halos.visible = (night > 0.001 or _alert > 0.001) and model.visible
	if not _eye_halos.visible: return
	_eye_halo_material.set_shader_parameter("glow",maxf(night*NIGHT_EYE_HALO_STRENGTH,_alert*ALERT_HALO))
	var head := skeleton.global_transform*skeleton.get_bone_global_pose(_bone["head"])
	var across := NIGHT_EYE_HALO*size
	for k in range(_eye_points.size()):
		_eye_halos.multimesh.set_instance_transform(k,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*across),head*_eye_points[k]))

## The night glow, eased in at dusk and out at dawn (NIGHT_*).
func _night_glow(delta: float) -> void:
	var goal := StoneLampLights.night_for(_daylight())
	night = move_toward(night,goal,delta/NIGHT_FADE)
	var open := clampf(_jaw*4.0,0.0,1.0)
	if breath == "inhale": open = maxf(open,0.8)
	_alert = move_toward(_alert,sight.alert(),delta*ALERT_EASE)
	for m: StandardMaterial3D in _night_materials.get("dragon_eye",[]):
		m.emission_energy_multiplier = lerpf(NIGHT_EYE.x,NIGHT_EYE.y,night)*lerpf(1.0,ALERT_EYE,_alert)
	for m: ShaderMaterial in _night_materials.get("dragon_glow",[]):
		m.set_shader_parameter("energy",lerpf(NIGHT_SPINES.x,NIGHT_SPINES.y,night))
	for m: ShaderMaterial in _night_materials.get("dragon_membrane_glow",[]):
		m.set_shader_parameter("glow_energy",NIGHT_MEMBRANE.x)
		m.set_shader_parameter("night_energy",NIGHT_MEMBRANE.y)
		m.set_shader_parameter("night",night)
		m.set_shader_parameter("night_reach",NIGHT_MEMBRANE_REACH)
	for key in ["dragon_mouth","dragon_tongue"]:
		for m: StandardMaterial3D in _night_materials.get(key,[]):
			m.emission_enabled = night > 0.001
			m.emission = NIGHT_THROAT
			m.emission_energy_multiplier = night*lerpf(NIGHT_THROAT_ENERGY.x,NIGHT_THROAT_ENERGY.y,open)*(0.6 if key == "dragon_tongue" else 1.0)
	for key in ["dragon_hide","dragon_belly"]:
		for m: ShaderMaterial in _night_materials.get(key,[]):
			m.set_shader_parameter("emit_add",NIGHT_SHEEN.srgb_to_linear()*NIGHT_SHEEN_ENERGY*night)
	_place_eye_halos()

func _daylight() -> float:
	var celestial: Variant = sky_scene.get("_celestial") if sky_scene != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	return 1.0

# --- The route ----------------------------------------------------------------------

## Under the cloud sea, out east-south-east of the isle, nose up.
func _start() -> void:
	var out := Vector3(0.88,0.0,0.48).normalized()
	pos = home+out*270.0
	pos.y = sea_y-35.0
	yaw = atan2(out.x,out.z)
	gamma = 1.15
	speed = 24.0
	state = "waiting"
	route = [Vector3(pos.x-out.x*25.0,sea_y+125.0,pos.z-out.z*25.0)]
	_leg_kinds = ["rise"]
	leg_kind = "rise"
	# Then straight into a low pass, so it is seen soon.
	_add_low_pass()
	if not loop.is_empty():
		# A fixed loop (the vision greybox): already on it, level.
		route.clear()
		_leg_kinds.clear()
		pos = loop[0]
		var to: Vector3 = loop[1%loop.size()]
		yaw = atan2(-(to.x-pos.x),-(to.z-pos.z))
		gamma = 0.0
		speed = 30.0
		for i in range(1,loop.size()+1):
			route.append(loop[i%loop.size()])
			_leg_kinds.append("low pass")
	elif _circle != "":
		# --dragon-downwash-test: already on the circle, level.
		route.clear()
		_leg_kinds.clear()
		var mid := _circle_mid()
		pos = mid+Vector3(CIRCLE_R,0.0,0.0)
		yaw = PI*0.5
		gamma = 0.0
		speed = CIRCLE_SPEED
		route.append(mid)
		_leg_kinds.append("low pass")
	elif _pass_now:
		# --dragon-pass: already on the low pass's way in, level.
		route.pop_front()
		_leg_kinds.pop_front()
		var from: Vector3 = route.pop_front()
		_leg_kinds.pop_front()
		var to: Vector3 = route[0]
		pos = from
		yaw = atan2(-(to.x-from.x),-(to.z-from.z))
		gamma = 0.0
		speed = 32.0
		flap_w = 0.0
		_bout = false
	elif _attack_now and not targets.is_empty():
		# --dragon-attack: already on its way in, level, far out.
		route.clear()
		_leg_kinds.clear()
		grip = {}
		_add_attack()
		if grip.is_empty(): return
		_on_the_way_in()

## --dragon-ride: it comes in close and low on its grab at once.
func _ride_in() -> void:
	_attack_in = INF
	route.clear()
	_leg_kinds.clear()
	_target_i = maxi(_choose_target(),0)
	_ride_home = _target_i
	_last_target = _target_i
	_attacked_at[_target_i] = _clock
	grip = _plan_grip(targets[_target_i%targets.size()])
	var out: Vector3 = grip.out
	pos = (grip.root as Vector3)+out*RIDE_OUT+(grip.tangent as Vector3)*float(grip.side)*25.0+Vector3.UP*RIDE_UP
	var to := (grip.root as Vector3)-pos
	yaw = atan2(-to.x,-to.z)
	gamma = -0.12
	speed = 30.0
	flap_w = 0.0
	_bout = false
	state = "roaming"
	model.visible = true
	_begin_grab()

## Where the pilot starts on --dragon-ride: on the target isle, a little
## more than halfway out to the gripped rim and off its blast's middle
## line, facing the dragon (x, y, z and the turn --place takes: degrees
## from facing -z, clockwise); INF without a grip.
func ride_spot() -> Vector4:
	if grip.is_empty(): return Vector4.INF
	var t: Dictionary = grip.target
	var home_at: Vector3 = t.home
	var rim: Vector3 = grip.rim
	var out: Vector3 = grip.out
	# Half way out, a third of the way round from the neck, clear of its
	# chin while it pants.
	var spot := home_at+(rim-home_at).rotated(Vector3.UP,-0.75*float(grip.side))*0.6
	var rec := _record(t)
	var shape: RefCounted = rec.get("shape") as RefCounted if rec.has("shape") else null
	var y := rim.y+1.0
	if shape != null and shape.has_method("open_at"):
		# A motif isle (round 7): open turf (no ruin, tree or water) on the
		# main land 10 to 20 m in from the gripped rim and off the blast's
		# middle line, nearest a spot 14 m in and 7 m aside.
		var tangent: Vector3 = grip.tangent
		var want := rim-out*14.0-tangent*float(grip.side)*7.0
		var best := Vector3.INF
		var near := INF
		for i in range(4,24):
			for j in range(-16,17):
				var p := rim-out*float(i)+tangent*float(j)
				var flat := Vector2(p.x-home_at.x,p.z-home_at.z)
				if not shape.main_at(flat) or not shape.open_at(flat,2.5): continue
				var d := p.distance_to(Vector3(want.x,p.y,want.z))
				if absf(float(j)) < 4.0: d += 8.0
				if d < near:
					near = d
					best = p
		if best != Vector3.INF:
			var flat := Vector2(best.x-home_at.x,best.z-home_at.z)
			spot = best
			y = home_at.y+float(shape.ground_at(flat))+0.2
		var face := rim-spot
		return Vector4(spot.x,y,spot.z,rad_to_deg(atan2(face.x,-face.z)))
	if shape != null:
		var flat := Vector2(spot.x-home_at.x,spot.z-home_at.z)
		if shape.on_land(flat): y = home_at.y+float(shape.ground_at(flat))+0.2
	return Vector4(spot.x,y,spot.z,rad_to_deg(atan2(out.x,-out.z)))

func _isle_pos(i: int) -> Vector3:
	return isles[i][0]

## Toward the sun (unit), from the scene's first shadowed directional
## light; straight up if there is none.
func _sun_to() -> Vector3:
	if not is_inside_tree(): return Vector3.UP
	for n in get_tree().root.find_children("*","DirectionalLight3D",true,false):
		var l := n as DirectionalLight3D
		if l.shadow_enabled and l.visible and l.get_viewport() == get_viewport():
			var to := l.global_transform.basis.z.normalized()
			if to.y > 0.05: return to
	return Vector3.UP

## A low pass over the home isle: in from far off and high, down over it at
## a clear height and out the far side. The middle point is set up-sun of
## the isle's middle, so its shadow sweeps across the turf.
func _add_low_pass() -> void:
	var a := _rng.randf()*TAU
	var way := Vector3(cos(a),0.0,sin(a))
	var over := home_top+42.0
	var sun := _sun_to()
	var shift := Vector3(sun.x,0.0,sun.z)*(44.0/sun.y)
	shift = shift.limit_length(80.0)
	var aim := shadow_at if shadow_at != Vector3.INF else Vector3(home.x,home_top,home.z)
	var mid := Vector3(aim.x,over,aim.z)+shift
	if _log: print("sky dragon: low pass over (%.0f, %.0f, %.0f), the sun toward (%.2f, %.2f, %.2f)" % [mid.x,mid.y,mid.z,sun.x,sun.y,sun.z])
	route.append(mid-way*340.0+Vector3.UP*40.0)
	route.append(mid-way*130.0+Vector3.UP*3.0)
	route.append(mid)
	route.append(mid+way*220.0+Vector3.UP*20.0)
	for i in range(4): _leg_kinds.append("low pass")
	_legs_since_pass = 0

## A big circuit round the archipelago, high.
func _add_circuit() -> void:
	var r := _rng.randf_range(260.0,400.0)
	var h := _rng.randf_range(105.0,150.0)
	var a0 := atan2(pos.z-home.z,pos.x-home.x)
	var turn := 1.0 if _rng.randf() < 0.5 else -1.0
	for k in range(1,4):
		var a := a0+turn*k*TAU/5.0
		route.append(home+Vector3(cos(a)*r,h-home.y+_rng.randf_range(-20.0,20.0),sin(a)*r))
		_leg_kinds.append("circuit")

## Threading between two neighbouring isles, low, at their rims' height.
func _add_thread() -> void:
	if isles.size() < 2:
		_add_circuit()
		return
	var best := []
	for i in range(isles.size()):
		for j in range(i+1,isles.size()):
			var a := _isle_pos(i)
			var b := _isle_pos(j)
			var gap := Vector2(a.x-b.x,a.z-b.z).length()-float(isles[i][1])-float(isles[j][1])
			if gap > 110.0 and gap < 420.0: best.append([i,j])
	if best.is_empty():
		_add_circuit()
		return
	var pick: Array = best[_rng.randi()%best.size()]
	var a := _isle_pos(pick[0])
	var b := _isle_pos(pick[1])
	var mid := (a+b)*0.5
	var across := Vector3(-(b.z-a.z),0.0,b.x-a.x).normalized()
	if across.dot(mid-pos) < 0.0: across = -across
	var y := minf(a.y,b.y)+10.0
	route.append(mid-across*230.0+Vector3.UP*(y+35.0-mid.y))
	route.append(Vector3(mid.x,y,mid.z))
	route.append(mid+across*220.0+Vector3.UP*(y+25.0-mid.y))
	for i in range(3): _leg_kinds.append("thread")

## Up high on heavy beats, then a long dive down at a far point.
func _add_climb_dive() -> void:
	var a := _rng.randf()*TAU
	var near := home+Vector3(cos(a),0.0,sin(a))*_rng.randf_range(180.0,300.0)
	route.append(Vector3(near.x,_rng.randf_range(190.0,230.0),near.z))
	var b := a+_rng.randf_range(1.2,2.2)
	var far := home+Vector3(cos(b),0.0,sin(b))*_rng.randf_range(240.0,380.0)
	route.append(Vector3(far.x,_rng.randf_range(60.0,80.0),far.z))
	_leg_kinds.append("climb")
	_leg_kinds.append("dive")

## --dragon-downwash-test: the circle's middle, at its height.
func _circle_mid() -> Vector3:
	var aim := shadow_at if shadow_at != Vector3.INF else Vector3(home.x,home_top,home.z)
	return Vector3(aim.x,home_top+CIRCLE_UP,aim.z)

## One lap of the cloverleaf (flown through as a low pass): over the
## middle and out one way, round, over it and out the other, round.
func _add_circle() -> void:
	var mid := _circle_mid()
	var a0 := atan2(-cos(yaw),-sin(yaw))
	for a: float in [a0,a0+0.9,INF,a0+0.9+PI,a0+1.8+PI]:
		route.append(mid if a == INF else mid+Vector3(cos(a),0.0,sin(a))*CIRCLE_R)
		_leg_kinds.append("low pass")
	route.append(mid)
	_leg_kinds.append("low pass")

func _next_legs() -> void:
	if not loop.is_empty():
		for p: Vector3 in loop:
			route.append(p)
			_leg_kinds.append("low pass")
		return
	if _circle != "":
		_add_circle()
		return
	if _attack_in <= 0.0 and not targets.is_empty():
		_add_attack()
		return
	_legs_since_pass += 1
	if _legs_since_pass >= 3 and _rng.randf() < 0.7:
		_add_low_pass()
		return
	var r := _rng.randf()
	if r < 0.34: _add_circuit()
	elif r < 0.68: _add_thread()
	else: _add_climb_dive()

# --- Each frame ---------------------------------------------------------------------

## Asleep on its roost (--dragon-roost, docs/design/dragon-roost/round2.md):
## the pose (scripts/dragon_roost.gd) lays it on its mountain and
## breathes it; it never grips or blows. With a wake (scripts/dragon_wake.gd,
## docs/design/dragon-wake/round1.md) it wakes on a schedule and flies a
## circuit round the region, spectacle only, then settles back.
var roost: RefCounted = null
var wake: RefCounted = null
## Its eyes (`_eye_points`) as found, kept for when it wakes: asleep they
## are lids, with no halo.
var _open_eyes: Array[Vector3] = []

## Built and laid asleep on its roost instead of `setup`: no route, gale or
## treasure; `pose` (scripts/dragon_roost.gd) poses it every frame.
## Its size is the pose's (`size`: SIZE, the same as it flies at).
func setup_roost(cam: Camera3D, pose: RefCounted) -> void:
	camera = cam
	size = float(pose.get("size"))
	_build()
	model.visible = true
	state = "roosting"
	_open_eyes = _eye_points.duplicate()
	roost = pose
	roost.setup(self)

## Where a host wants his head to look while nothing else holds it (no
## pilot in his sight): a world point, INF for none.
var gaze := Vector3.INF

## Off his wake's takeoff and into the whole flight (the generator's
## dragon, scripts/roguelike/layer_dragon.gd, docs/design/roguelike/
## layer-round12-dragon.md): the roost left behind, the gale (his grip)
## and the air blast (with `blast_on`) built, no treasure; `_step` flies
## him from here on, his `route` the host's. `wake` is kept (still out),
## so `awake` holds and the host shows him; it is no longer stepped.
func go_live(sea: float, middle: Vector3, top: float, isle_list: Array) -> void:
	sea_y = sea
	home = middle
	home_top = top
	isles = isle_list
	roost = null
	taken = true
	_attack_in = INF
	if gale == null:
		gale = DragonGale.new()
		gale.sea_y = sea_y
		add_child(gale)
	if blast_on and air_blast == null:
		air_blast = DragonAirBlast.new()
		add_child(air_blast)
	set_attack(attack)
	state = "roaming"
	model.visible = true
	_t = 0.0

## Whether it is off its roost (or waking on it): its wake's to say.
func awake() -> bool:
	return wake != null and bool(wake.call("out"))

## Its eyes open (the eye surface its own, glowing, the night halos back)
## or shut (worn as the hide, as asleep).
func open_eyes(open: bool) -> void:
	_eye_points.clear()
	if open: _eye_points.append_array(_open_eyes)
	elif _eye_halos != null: _eye_halos.visible = false
	for mi: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m != null and m.resource_name == "dragon_eye": mi.set_surface_override_material(i,_material("dragon_eye" if open else "dragon_hide"))

## Its flight for the wake (scripts/dragon_wake.gd): the air, steering along
## `route`, the pose and the body's ease; no attack, gale or treasure (it
## has none off its roost: `setup_roost` builds neither).
func wake_fly(delta: float) -> void:
	_clock += delta
	_wake_flew = true
	_ride_air(delta)
	_fly(delta)
	_pose(delta)
	_ease_body(delta)

## Its flight pose for the wake's takeoff and landing, flown by the wake
## itself (`pos`, `yaw`, `gamma`, `flap_w`, `phase` set there); the body's
## turn eased as in flight, so it carries on smoothly into and out of it.
func wake_pose(delta: float) -> void:
	_clock += delta
	_ride_air(delta)
	_pose(delta)
	_ease_body(delta)

func advance(delta: float) -> void:
	if delta <= 0.0: return
	if roost != null:
		if wake != null: wake.call("advance",delta)
		else: roost.advance(delta)
		_downwash(delta,_wake_flew)
		_look_out(delta,_wake_flew)
		_cyclone(delta,_wake_flew)
		_wake_flew = false
		_night_glow(delta)
		if awake(): _watch_camera(delta)
		return
	if _skip > 0.0:
		var ahead := _skip
		_skip = 0.0
		while ahead > 0.0:
			_step(minf(ahead,1.0/30.0))
			ahead -= 1.0/30.0
	_step(minf(delta,0.1))
	_downwash(delta,state in ["roaming","rising"] and model.visible)
	_look_out(delta,state in ["roaming","rising"] and model.visible)
	_grip_attack(delta)
	_cyclone(delta,state in ["roaming","rising"] and model.visible)
	_night_glow(delta)
	_watch_camera(delta)

func _step(delta: float) -> void:
	_clock += delta
	_t += delta
	if state == "waiting":
		if _t < delay: return
		state = "roaming" if _pass_now or _attack_now or _circle != "" or not loop.is_empty() else "rising"
		model.visible = true
		_t = 0.0
	if state == "roaming": _attack_in -= delta
	_ride_air(delta)
	match state:
		"grabbing":
			_grabbing(delta)
			_pose(delta)
		"clinging": _clinging(delta)
		"leaving":
			_leaving(delta)
			_pose(delta)
			_ease_off_rim()
		_:
			if _hold: _held(delta)
			else: _fly(delta)
			_pose(delta)
	_ease_body(delta)
	_blend(delta)
	gale.advance(delta)
	# Round 6: head, jaw and neck clear of the isle as it stands after its
	# move this frame, the chin's collider and the gem on the jaw so posed.
	if state in ["grabbing","clinging","leaving"]: _clear_turf(delta)
	else: _relax_clear(delta)
	_place_chin(state == "clinging")
	_place_treasure(delta)
	_measure_tip(delta)
	_ride_isle(delta)
	_walking_check(delta)
	if _log:
		_log_t += delta
		if _log_t >= (0.5 if leg_kind == "low pass" else 2.0):
			_log_t = 0.0
			if walker != null and on_foot:
				var f: Vector3 = walker.get("feet")
				var gem := treasure.global_position if treasure != null else Vector3.ZERO
				print("sky dragon: pilot at (%.1f, %.1f, %.1f) grounded %s v.y %.1f, %s%s on %.0f°, %.1f m/s, on the held isle %s, the gem at (%.1f, %.1f, %.1f), the isle's rim sags %.1f m; breath ribbons %d (%d lee curls, %d on the ground, %d steered round), knocked %d, pushed %d frames, air on him at most %.1f m/s" % [f.x,f.y,f.z,str(walker.get("grounded")),(walker.get("velocity") as Vector3).y,str(walker.get("move")),(" hold "+str(walker.get("hold"))) if str(walker.get("hold")) != "" else "",walker.steepness(),walker.speed(),str(gale.stands_on(f,1.5)),gem.x,gem.y,gem.z,gale.sag,gale.breath.count(),gale.breath.lees,gale.breath.grounds,gale.breath.steers,knocks,pushed,air_most])
			if state in ["clinging","grabbing","leaving"]:
				print("sky dragon: t %.1f %s %s, %.0f s to let go, at (%.0f, %.0f, %.0f), %.0f m from the isle's middle; head in the turf %.2f m unlifted, %.2f m lifted, resting %.2f (chin off flush %.2f, %.2f m), isle tipped %.0f°; snout at most %.1f m/s, %.0f m/s²" % [_clock,state,breath,_cling_left,pos.x,pos.y,pos.z,Vector2(pos.x-home.x,pos.z-home.z).length(),-sunk_before,-sunk_after,_rest_w,chin_miss.x,chin_miss.y,rad_to_deg(gale.tip()),tip_speed,tip_jerk])
				sunk_before = 0.0
				sunk_after = 0.0
				tip_speed = 0.0
				tip_jerk = 0.0
			else: print("sky dragon: t %.0f %s %s leg %s at (%.0f, %.0f, %.0f) %.1f m/s gamma %.2f roll %.2f flap %.2f, %.0f m from the isle's middle; downwash on the ground %.2f, gust %.2f" % [_clock,state,mode,leg_kind,pos.x,pos.y,pos.z,speed,gamma,roll,flap_w,Vector2(pos.x-home.x,pos.z-home.z).length(),downwash.reach_ground(),downwash.burst.w])

func _fly(delta: float) -> void:
	if route.is_empty(): _next_legs()
	_replan_attack()
	var target: Vector3 = route[0]
	leg_kind = _leg_kinds[0]
	var to := target-pos
	var flat := Vector2(to.x,to.z)
	var dist := flat.length()
	# A low pass is flown right through its points, so it really is low.
	var arrive := 30.0 if state == "rising" else (40.0 if leg_kind in ["low pass","grab"] else ARRIVE)
	var behind := Vector2(-sin(yaw),-cos(yaw)).dot(flat.normalized()) < -0.2
	var reached := pos.y > target.y-10.0 if state == "rising" else (dist < arrive or (behind and dist < (90.0 if leg_kind == "low pass" else 220.0)))
	if reached:
		route.pop_front()
		_leg_kinds.pop_front()
		if state == "rising": state = "roaming"
		if leg_kind == "grab":
			_begin_grab()
			return
		if route.is_empty(): _next_legs()
		target = route[0]
		to = target-pos
		flat = Vector2(to.x,to.z)
		dist = flat.length()
	# Turn toward it, the turn's rate eased; bank to suit. A slow weave on
	# top, so a straight never looks ruled.
	var want_yaw := atan2(-to.x,-to.z)
	var dyaw := wrapf(want_yaw-yaw,-PI,PI)
	var max_turn := MAX_TURN*(0.6 if state == "rising" else 1.0)
	var weave := 0.035*sin(_clock*0.23+1.3)+0.02*sin(_clock*0.61)
	var want_rate := clampf(dyaw*0.6+weave,-max_turn,max_turn)
	yaw_rate = move_toward(yaw_rate,want_rate,0.3*delta)
	yaw += yaw_rate*delta
	var want_roll := clampf(atan(speed*yaw_rate/9.8),-MAX_BANK,MAX_BANK)
	roll = lerpf(roll,want_roll,1.0-exp(-delta*1.8))
	# Climb or dive toward its height.
	var want_gamma := clampf(atan2(to.y,maxf(dist,1.0))*1.4,-MAX_DIVE,MAX_CLIMB)
	if state == "rising": want_gamma = clampf(atan2(to.y,maxf(dist,1.0))*2.0,0.2,1.15)
	gamma = move_toward(gamma,want_gamma,(0.5 if state == "rising" else 0.36)*delta)
	# Beats or glides: climbing always beats, diving tucks, cruising beats in
	# bouts when slow and glides when quick.
	if gamma > 0.22 or state == "rising": mode = "climb"
	elif gamma < -0.2: mode = "dive"
	else: mode = "cruise"
	match mode:
		"climb": _bout = true
		"dive": _bout = false
		"cruise":
			if not _bout and speed < FLAP_BELOW:
				_bout = true
				_bout_left = _rng.randi_range(1,3)
			elif _bout and speed > GLIDE_ABOVE and _bout_left <= 0: _bout = false
	if _circle == "beat": _bout = true
	flap_w = move_toward(flap_w,1.0 if _bout else 0.0,delta*(1.4 if _bout else 0.7))
	# The push comes on the downstroke, so each beat surges.
	var power := (1.4 if mode == "climb" else 1.0)*(1.8 if phase < DOWN else 0.2)
	var accel := flap_w*THRUST*power-DRAG*speed*speed-9.8*sin(gamma)*0.5
	if mode == "dive": accel -= DRAG*speed*speed*0.4
	# The swell's lift feeds the speed a little, as a soaring bird's does.
	accel += _swell*0.12
	speed = clampf(speed+accel*delta,24.0 if state == "rising" else MIN_SPEED,MAX_SPEED)
	if _circle != "": speed = minf(speed,CIRCLE_SPEED)
	var fwd := Vector3(-sin(yaw)*cos(gamma),sin(gamma),-cos(yaw)*cos(gamma))
	pos += fwd*speed*delta
	# Carried by the air: a drift down the wind (the swell is laid on in
	# `_pose`, as a bounded rise and fall).
	pos += Vector3(cos(air_angle),0.0,sin(air_angle))*(1.5+3.0*air)*delta
	# The beat keeps turning while the flapping fades, so wings settle.
	var hz := lerpf(BEAT,BEAT_CLIMB,clampf(gamma/MAX_CLIMB,0.0,1.0)) if state != "rising" else BEAT_CLIMB
	var before := phase
	if flap_w > 0.01 or fposmod(phase,1.0) > 0.02: phase = fposmod(phase+delta*hz,1.0)
	if phase < before and _bout_left > 0: _bout_left -= 1

## The air it rides: a slow swell of rising and sinking air (a few m/s,
## more in a stronger breeze, most when gliding), the roll and pitch the
## air puts on it, and now and then a bump (a kicked spring) it shrugs off.
func _ride_air(delta: float) -> void:
	var c := _clock
	var gain := (0.7+0.9*clampf(air,0.0,1.5))*(1.0-0.45*flap_w)
	# The rise and fall (m) and its vertical speed (m/s).
	_swell_y = gain*(5.0*sin(c*0.19+0.4)+2.2*sin(c*0.43+2.1)+0.6*sin(c*0.97+4.0))
	_swell = gain*(0.95*cos(c*0.19+0.4)+0.95*cos(c*0.43+2.1)+0.58*cos(c*0.97+4.0))
	_air_roll = gain*(0.07*sin(c*0.31+1.0)+0.045*sin(c*0.83+0.3)+0.02*sin(c*1.9))
	_air_pitch = gain*(0.035*sin(c*0.27+2.6)+0.02*sin(c*0.71+1.1))+_swell*0.025
	_bump_next -= delta
	if _bump_next <= 0.0:
		_bump_next = _rng.randf_range(3.5,8.0)
		_bump_v += Vector2(_rng.randf_range(-0.5,0.5),_rng.randf_range(-0.25,0.35))*gain
	# Roll and pitch bumps, under-damped: a jolt, a sway, settled.
	_bump_v += (-_bump*7.0-_bump_v*2.6)*delta
	_bump += _bump_v*delta

## The downwash's frame (scripts/dragon_downwash.gd): where he is, the beat,
## and the turf under him (a ray every 0.2 s while flying) for its ring.
func _downwash(delta: float, flying: bool) -> void:
	var hz := lerpf(BEAT,BEAT_CLIMB,clampf(gamma/MAX_CLIMB,0.0,1.0))
	var at := global_position if is_inside_tree() else pos
	_ground_t -= delta
	if not flying: _ground_y = -INF
	elif _ground_t <= 0.0 and is_inside_tree():
		_ground_t = 0.2
		var reach := DragonDownwash.BELOW*DragonDownwash.MODEL_SPAN*size
		_ray.from = at
		_ray.to = at+Vector3.DOWN*reach
		_ray.collision_mask = TURF_LAYER|SOLID_LAYER
		var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
		_ground_y = (hit.position as Vector3).y if not hit.is_empty() else -INF
	downwash.update(delta,flying,at,yaw,size,phase,flap_w,hz,_ground_y,is_inside_tree())

## His sight's frame (scripts/dragon_sight.gd): flying with a pilot to look
## for, from his eye along his snout; else blind (the awareness drains).
func _look_out(delta: float, flying: bool) -> void:
	var want: Dictionary = sight_target.call() if flying and sight_target.is_valid() and is_inside_tree() else {}
	if want.is_empty() or (want.get("points",PackedVector3Array()) as PackedVector3Array).is_empty():
		sight.blind(delta)
		return
	sight.update(delta,get_world_3d().direct_space_state,head_eye(),head_look(),want.points,bool(want.get("airborne",false)))

## The attack he uses now ("blast", "cyclone" or "none"): the other's
## wind-up dropped, its shots in the air left to finish.
func set_attack(kind: String) -> void:
	attack = kind
	if cyclone != null:
		cyclone.on = kind == "cyclone"
		if not cyclone.on: cyclone.phase = "idle"
	if air_blast != null:
		# The grip falls back to the blast off an isle (`_grip_attack`).
		air_blast.on = kind in ["blast","grip"]
		if not air_blast.on: air_blast.phase = "idle"

## The attack in use (null for none): the grip's fallback is the blast.
func attack_node() -> Node3D:
	if attack == "blast" or attack == "grip": return air_blast
	if attack == "cyclone": return cyclone
	return null

## His cyclone (scripts/dragon_cyclone.gd) or air blast (scripts/
## dragon_air_blast.gd): spotted (and his roar far enough on, each's
## AFTER_ROAR s in) he winds up, drawing air into his mouth from the
## pilot's way (the gale's inhale), and fires at the pilot as he sees him.
func _cyclone(delta: float, flying: bool) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() and (cyclone != null or air_blast != null) else null
	var mouth := mouth_at() if cyclone != null or air_blast != null else Vector3.ZERO
	var aim := sight.target()
	var seen := flying and sight.state == "spotted"
	if cyclone != null:
		cyclone.span = DragonDownwash.MODEL_SPAN*size
		cyclone.advance(delta,space,seen and (_roar_t < 0.0 or _roar_t >= DragonCyclone.AFTER_ROAR),mouth,aim)
	if air_blast != null:
		air_blast.span = DragonDownwash.MODEL_SPAN*size
		air_blast.advance(delta,space,seen and (_roar_t < 0.0 or _roar_t >= DragonAirBlast.AFTER_ROAR),mouth,aim)
	var on := attack_node()
	if on == null: return
	# The wind-up cuts the spotting roar's close short.
	if on.phase == "windup" and _roar_t >= 0.0 and _hold_pose != "roar": _roar_t = -1.0
	if on.phase == "windup" and aim != Vector3.INF:
		var way := Vector3(aim.x-mouth.x,0.0,aim.z-mouth.z)
		if way.length() > 0.1: gale.inhale(mouth,way.normalized(),delta*(2.0 if on == air_blast else 1.0))

## The grip as his attack (see `grip_pick`): the blast held while the
## pilot is on an isle he can grip or a grip is under way, and the grip
## begun once he has spotted him there.
func _grip_attack(delta: float) -> void:
	_grip_rest = maxf(0.0,_grip_rest-delta)
	if attack != "grip": return
	var i: int = int(grip_pick.call()) if grip_pick.is_valid() else -1
	var can := i >= 0 and i < targets.size() and not _record(targets[i]).is_empty() and _has_room(targets[i])
	if air_blast != null: air_blast.on = grip.is_empty() and not can
	if can and state == "roaming" and grip.is_empty() and _grip_rest <= 0.0 and sight.state == "spotted":
		print("sky dragon: he spots the pilot on %s and breaks off to grip it" % str(targets[i].name))
		grip_isle(i,grip_hold)

## Off to grip target `i` now, whatever he was flying (held `hold` s, below
## 0 his own CLING_HOLD); `near` starts him on the way in already, close
## (--grip-now, as --dragon-attack).
func grip_isle(i: int, hold := -1.0, near := false) -> void:
	if i < 0 or i >= targets.size(): return
	if hold > 0.0: _cling_for = hold
	_target_i = i
	_target_forced = true
	route.clear()
	_leg_kinds.clear()
	grip = {}
	_add_attack()
	if grip.is_empty(): return
	grips += 1
	if state == "waiting":
		state = "roaming"
		_t = 0.0
	model.visible = true
	if near: _on_the_way_in()

## Already on the attack's way in, level, far out (--dragon-attack): the
## wide leg skipped.
func _on_the_way_in() -> void:
	route.pop_front()
	_leg_kinds.pop_front()
	var to: Vector3 = route[0]
	var away: Vector3 = grip.out
	var along: Vector3 = grip.tangent
	pos = to+away*170.0+along*float(grip.side)*70.0+Vector3.UP*22.0
	yaw = atan2(-(to.x-pos.x),-(to.z-pos.z))
	gamma = 0.0
	speed = 32.0
	flap_w = 0.0
	_bout = false

## Back onto his `loop` after a grip: from its point nearest ahead of him
## (the nearest at all if none is ahead), round.
func _rejoin_loop() -> void:
	var fwd := Vector2(-sin(yaw),-cos(yaw))
	var best := 0
	var near := INF
	for i in range(loop.size()):
		var p: Vector3 = loop[i]
		var to := Vector2(p.x-pos.x,p.z-pos.z)
		var d := to.length()+(0.0 if to.dot(fwd) > 0.0 else 1000.0)
		if d < near:
			near = d
			best = i
	for k in range(loop.size()):
		route.append(loop[(best+k)%loop.size()])
		_leg_kinds.append("low pass")

## His eye (world): between his eyes on the head bone as posed (the head's
## middle without them).
func head_eye() -> Vector3:
	var head := skeleton.global_transform*skeleton.get_bone_global_pose(_bone["head"])
	var points: Array[Vector3] = _eye_points if not _eye_points.is_empty() else _open_eyes
	if points.is_empty(): return head.origin
	var m := Vector3.ZERO
	for p in points: m += head*p
	return m/float(points.size())

## Where his head points (world, unit): the head bone's snout as posed.
func head_look() -> Vector3:
	var head := skeleton.global_transform*skeleton.get_bone_global_pose(_bone["head"])
	return (head.basis*_snout).normalized()

## Each change of his sight's state: spotted, he roars (its call in the kit
## audio, scripts/kit_isle/kit_audio_beasts.gd, as every roar's).
func _on_sight(now: String, was: String) -> void:
	print("sky dragon: sight %s -> %s (awareness %.2f, visibility %.2f, %.0f m)" % [was,now,sight.awareness,sight.visibility,sight.distance])
	if now == "spotted" and _roar_t < 0.0: _roar_t = 0.0

## Held in place for a pose check.
func _held(delta: float) -> void:
	state = "roaming"
	pos = home+Vector3(150.0,120.0-home.y,0.0)
	yaw = 0.0
	yaw_rate = 0.0
	roll = 0.0
	speed = 30.0
	gamma = -0.35 if _hold_pose == "dive" else 0.0
	mode = "dive" if _hold_pose == "dive" else "cruise"
	if _hold_phase >= 0.0:
		flap_w = 1.0
		phase = _hold_phase
	elif _hold_pose != "":
		flap_w = 0.0
	else:
		flap_w = 1.0
		phase = fposmod(phase+delta*BEAT,1.0)
	if _hold_pose == "roar" and _roar_t < 0.0 and _clock > 1.0: _roar_t = 0.0

## The wing's raise and fold through a beat (phase 0 = top).
static func _beat_raise(p: float) -> float:
	if p < DOWN:
		var u := p/DOWN
		# The power stroke: quick through its middle.
		return lerpf(RAISE_UP,RAISE_DOWN,u*u*(3.0-2.0*u))
	var u := (p-DOWN)/(1.0-DOWN)
	return lerpf(RAISE_DOWN,RAISE_UP,u*u*(3.0-2.0*u))

static func _beat_fold(p: float) -> float:
	if p < DOWN: return 0.25*pow(1.0-p/DOWN,3.0)
	return sin(PI*(p-DOWN)/(1.0-DOWN))

func _pose(delta: float) -> void:
	# The body's part in the flight (scripts/dragon_spine.gd): springs on
	# the spine, neck, head and legs, stepped from the beat and the flight.
	var bob := -BOB*cos(TAU*phase)*flap_w*(1.3 if mode == "climb" else 1.0)
	spine.step(delta,_clock,phase,DOWN,flap_w,gamma,yaw_rate/MAX_TURN,(_air_pitch+_bump.y)*_free,(_air_roll+_bump.x)*_free,bob)
	# The wings: a beat (bigger climbing) blended with the glide (or the
	# dive's tuck: part folded, swept back).
	var mid := (RAISE_UP+RAISE_DOWN)*0.5
	var raise := lerpf(RAISE_GLIDE,mid+(_beat_raise(phase)-mid)*spine.beat_gain,flap_w)
	var fold := lerpf(0.05,_beat_fold(phase)*0.95,flap_w)+spine.fold
	var sweep := spine.sweep
	if mode == "dive":
		var tuck := (1.0-flap_w)*smoothstep(0.2,0.45,-gamma)
		raise = lerpf(raise,0.32,tuck)
		fold = lerpf(fold,0.55,tuck)
		sweep += 0.3*tuck
	# The grab's flare: wings cupped forward, beating back against the air.
	sweep -= 0.55*_flare
	# The tips lag the beat: they bend against the raise's speed.
	var rv := (raise-_last_raise)/maxf(delta,0.001)
	_last_raise = raise
	_tip_lag = lerpf(_tip_lag,clampf(-rv*0.16,-0.5,0.5),1.0-exp(-delta*10.0))
	# Gliding: the wings trim against the air, each on its own: the raise
	# answers the air's roll (the low wing lifts), the hands twist with the
	# swell, the tips flex on a bump.
	var still := 1.0-flap_w
	var air_roll := (_air_roll+_bump.x)*_free
	_trim = Vector2(0.05*sin(_clock*0.71)+0.03*sin(_clock*1.9),0.05*sin(_clock*0.63+1.7)+0.03*sin(_clock*2.3))*still
	var twist := (_swell*0.02+0.06*sin(_clock*0.9))*still
	# The body: bobbing against each beat, nodding with it, rolled and
	# pitched by the air.
	var nod := 0.04*sin(TAU*phase)*flap_w
	var pitch := gamma*0.75+0.05+nod+(_air_pitch+_bump.y)*_free
	var body_roll := roll+air_roll
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,body_roll)
	global_transform = Transform3D(basis,pos+basis.y*bob*size+Vector3.UP*_swell_y*_free)
	for side in [-1.0,1.0]:
		var n := "L" if side < 0.0 else "R"
		# The low wing (air rolling it down) lifts against it.
		var r: float = raise+(_trim.x if side < 0.0 else _trim.y)-side*roll*0.08+side*air_roll*0.9*still
		var flex: float = _bump_v.x*side*0.12*still
		_turn("wing_arm."+n,[[Vector3.BACK,side*r],[Vector3.UP,-side*(sweep+0.15*fold)],[Vector3.RIGHT,0.06*flap_w*sin(TAU*phase)+twist*0.4*side]])
		# A gull's bend at the wrist when gliding: the hand a little down.
		_turn("wing_fore."+n,[[Vector3.UP,side*fold*0.85],[Vector3.BACK,side*(0.2*r+_tip_lag*0.3-0.22*still)]])
		_turn("wing_hand."+n,[[Vector3.UP,-side*fold*1.75],[Vector3.BACK,side*(_tip_lag*0.6+flex)],[Vector3.RIGHT,twist*side]])
		_turn("wing_f1."+n,[[Vector3.BACK,side*(_tip_lag*0.5+0.06*still)]])
		_turn("wing_f1b."+n,[[Vector3.BACK,side*(_tip_lag*0.7+flex*1.5+0.08*still)]])
		_turn("wing_f2."+n,[[Vector3.UP,side*fold*0.15],[Vector3.BACK,side*(_tip_lag*0.5+flex)]])
		_turn("wing_f3."+n,[[Vector3.UP,side*fold*0.3],[Vector3.BACK,side*_tip_lag*0.4]])
		_turn("wing_f4."+n,[[Vector3.UP,side*fold*0.45],[Vector3.BACK,side*_tip_lag*0.3]])
		# The hind legs tucked back under the tail's root, hanging on springs
		# (`spine.leg`: swinging late with the beat's heave and out of turns,
		# drawn up in a dive); in the grab's flare they swing down and
		# forward, claws open, reaching.
		var hang := spine.leg
		_turn("hind_upper."+n,[[Vector3.RIGHT,lerpf(-1.5+hang.x,0.7,_flare)],[Vector3.BACK,hang.y*(1.0-_flare)]])
		_turn("hind_lower."+n,[[Vector3.RIGHT,lerpf(0.9+hang.z,-0.4,_flare)]])
		_turn("hind_foot."+n,[[Vector3.RIGHT,lerpf(-0.7-hang.z*0.5,0.5,_flare)]])
	_mouth(delta)
	# The spine: the chest and hips bent by the spring chain (the beat's
	# push, the turn, the climb or tuck, the air); the chest swelling with
	# each push and breathing.
	var chest_t := spine.turn_of("chest")
	var hips_t := spine.turn_of("hips")
	_turn("chest",[[Vector3.RIGHT,chest_t.x],[Vector3.UP,chest_t.y]])
	_set_chest(Vector3(1.0+spine.swell,1.0,1.0+spine.swell*1.2),delta)
	_turn("hips",[[Vector3.RIGHT,hips_t.x],[Vector3.UP,hips_t.y]])
	# The neck leads into the turn (a spring, so it overshoots a little) and
	# holds the head level against the pitch, bank and bob; it sways in a
	# slow S of its own; in a roar it draws back and the head lifts.
	var want_lead := clampf(yaw_rate*2.2,-0.75,0.75)
	_lead_v += ((want_lead-_lead)*6.0-_lead_v*3.2)*delta
	_lead += _lead_v*delta
	var look_goal := Vector2.ZERO
	var track := sight.target() if sight.state != "unaware" else Vector3.INF
	if track != Vector3.INF:
		# Suspicious or spotted: the head turns to the pilot, wider than
		# to the camera, and fully.
		var off := global_transform.affine_inverse()*track
		look_goal = Vector2(clampf(atan2(-off.x,-off.z),-TRACK_YAW,TRACK_YAW),clampf(atan2(off.y,Vector2(off.x,off.z).length()),TRACK_PITCH.x,TRACK_PITCH.y))
	elif gaze != Vector3.INF:
		# A host's point to watch (the layer under his circuit): the head
		# turned to it, down and in, as far as it turns.
		var off := global_transform.affine_inverse()*gaze
		look_goal = Vector2(clampf(atan2(-off.x,-off.z),-TRACK_YAW,TRACK_YAW),clampf(atan2(off.y,Vector2(off.x,off.z).length()),TRACK_PITCH.x,TRACK_PITCH.y))
	elif camera != null and watch != "chase":
		var eye := camera.global_position
		var off := global_transform.affine_inverse()*eye
		var d := off.length()
		if d < 260.0 and off.z < 20.0:
			var w := 1.0-smoothstep(150.0,260.0,d)
			look_goal = Vector2(clampf(atan2(-off.x,-off.z),-0.8,0.8),clampf(atan2(off.y,Vector2(off.x,off.z).length()),-0.6,0.35))*w
	# The air blast's wind-up: the head snaps onto the pilot.
	var snap := air_blast != null and air_blast == attack_node() and str(air_blast.phase) == "windup"
	if snap: _look_v += ((look_goal-_look)*60.0-_look_v*14.0)*delta
	else: _look_v += ((look_goal-_look)*3.0-_look_v*2.6)*delta
	_look += _look_v*delta
	var head_yaw := _lead+_look.x
	# The head held level against the flight's pitch (less climbing, as the
	# neck reaches into it; little diving, in line with the neck) and steady
	# against the body's nod, the air's pitch and the spine's own sway.
	var level := -(gamma*0.75+0.05)*0.7*spine.head_level-(pitch-gamma*0.75-0.05)*DragonSpine.HEAD_STEADY+_look.y
	var neck_sway := 0.04*sin(_clock*0.37)
	var slither := 0.05*sin(_clock*0.29+0.8)
	var spine2 := spine.turn_of("spine.2")
	_turn("spine.2",[[Vector3.RIGHT,-0.06+spine2.x],[Vector3.UP,spine2.y]])
	# Each neck bone, root to head: the S's bend (root up, head end down;
	# straightened in a dive), its share of the lead, the slow sway passing
	# up it, the spring chain's bend (the beat's wave, the turn, the reach)
	# and the roar's draw back.
	for i in range(_neck_n):
		var u := float(i)/maxf(_neck_n-1,1)
		var bend := lerpf(0.04,-0.08,u)*spine.neck_s+_rear*lerpf(0.2,-0.14,u)
		var wave := neck_sway*sin(PI*u+0.3)+slither*cos(PI*u)
		var chain := spine.turn_of("neck.%d" % i)
		_turn("neck.%d" % i,[[Vector3.RIGHT,bend+wave+chain.x],[Vector3.UP,head_yaw*1.0/_neck_n+slither*0.6*(u-0.5)+chain.y]])
	_turn("head",[[Vector3.RIGHT,0.08*spine.neck_s+level-neck_sway*0.6+_rear*0.3+spine.head_steady.x],[Vector3.UP,head_yaw*0.2+spine.head_steady.y],[Vector3.BACK,-body_roll*0.5]])
	_tail(delta)

## The mouth, all on springs: breathing (a slight part and close), chews
## now and then, and the roar: a tightening first, then the jaw eased open
## (a spring past its goal and back), held trembling, eased shut, the head
## lifting and the neck drawing back with it; the lower lip follows the
## jaw late (jaw.tip), and the cheek skin stretches (the model's weights).
func _mouth(delta: float) -> void:
	var goal := 0.03+0.015*sin(_clock*TAU*0.18+0.6)
	var rear_goal := 0.0
	if state == "clinging" and _jaw_goal >= 0.0:
		# On the rim the breath sets the jaw (no chews, no roars).
		goal = _jaw_goal
	elif _roar_t < 0.0 and _hold_pose != "roar" and idle_roars:
		_roar_next -= delta
		if _roar_next <= 0.0:
			_roar_t = 0.0
			_roar_next = _rng.randf_range(12.0,22.0)
	var hit_with := attack_node()
	var drawn: float = hit_with.windup_share() if hit_with != null else -1.0
	var shot: float = float(hit_with.since_shot) if hit_with != null else INF
	if _roar_t < 0.0 and drawn >= 0.0:
		# The cyclone's wind-up: the jaw a little open, the head drawn
		# back, drawing in more and more.
		goal = lerpf(0.12,0.3,drawn)+0.02*sin(_clock*23.0)
		rear_goal = 0.7*smoothstep(0.0,0.5,drawn)
	elif _roar_t < 0.0 and shot < 0.7:
		# Fired: the jaw flung wide, the head thrust forward, eased back.
		var u := shot/0.7
		goal = lerpf(0.6,0.05,u*u)
		rear_goal = lerpf(-0.6,0.0,u)
	elif _roar_t >= 0.0:
		_roar_t += delta
		var t := _roar_t
		if t < 0.45:
			goal = 0.0
			rear_goal = -0.15*sin(PI*t/0.45)
		elif t < 1.35:
			var u := (t-0.45)/0.9
			goal = 0.62*u*u*(3.0-2.0*u)*u
			rear_goal = smoothstep(0.0,1.0,u)
		elif t < 2.5:
			goal = 0.62+0.025*sin(t*31.0)
			rear_goal = 1.0
		elif t < ROAR:
			var u := (t-2.5)/(ROAR-2.5)
			goal = lerpf(0.62,0.03,u*u*(3.0-2.0*u))
			rear_goal = 1.0-smoothstep(0.0,1.0,u)
		else:
			_roar_t = 0.0 if _hold_pose == "roar" else -1.0
	elif state != "clinging":
		_chew_next -= delta
		if _chew_next <= 0.0 and _chew_t < 0.0:
			_chew_t = 0.0
			_chew_size = _rng.randf_range(0.06,0.14)
			_chew_next = _rng.randf_range(2.5,6.5)
		if _chew_t >= 0.0:
			_chew_t += delta
			# One or two small bites, each soft in and out.
			var bites := 2.0 if _chew_size > 0.1 else 1.0
			var span := 0.55*bites
			if _chew_t >= span: _chew_t = -1.0
			else: goal += _chew_size*pow(sin(PI*fposmod(_chew_t,0.55)/0.55),2.0)
	# The jaw: an under-damped spring (overshoot, settle).
	var acc := (goal-_jaw)*55.0-_jaw_v*8.0
	_jaw_v += acc*delta
	_jaw += _jaw_v*delta
	# The lip lags the jaw's speed and springs back.
	_lip_v += ((clampf(_jaw_v*0.09,-0.2,0.2)-_lip)*70.0-_lip_v*7.0)*delta
	_lip += _lip_v*delta
	_rear_v += ((rear_goal-_rear)*14.0-_rear_v*5.5)*delta
	_rear += _rear_v*delta
	_turn("jaw",[[Vector3.RIGHT,-maxf(_jaw,-0.01)]])
	_turn("jaw.tip",[[Vector3.RIGHT,_lip]])

## The tail: a rope of points dragged from the hips, each held a segment's
## length from the one before and pulled softly toward its rest line, so
## it trails the flight's curve, swings late out of turns and ripples with
## the bob. The bones are then turned to lie along it.
## Round 11 (docs/design/dragon-spine/round1.md): its rest line and the
## bones' turns are taken from the hips as posed, so it carries on the
## spine's bend with no hinge where it leaves the hips, and in a turn its
## rest line curls on into the turn (`spine.tail_curl`, a segment's share
## more each segment out) and droops in a flare.
func _tail(delta: float) -> void:
	for i in range(_tail_n): _turn("tail.%d" % i,[])
	var sk := skeleton.global_transform
	var hips_pose := skeleton.get_bone_global_pose(_bone["hips"])
	var hips_rest := skeleton.get_bone_global_rest(_bone["hips"])
	var start := sk*(hips_pose*(hips_rest.affine_inverse()*_tail_start))
	var basis := sk.basis*(hips_pose.basis.orthonormalized()*hips_rest.basis.orthonormalized().inverse())
	var curl := spine.tail_curl if state != "clinging" else 0.0
	var droop := spine.tail_droop if state != "clinging" else 0.0
	if not _rope_ready:
		_rope = [start]
		for i in range(_tail_n): _rope.append(_rope[i]+basis*((_seg_dir[i] as Vector3)*_seg_len[i]))
		_rope_prev = _rope.duplicate()
		_rope_ready = true
	_rope[0] = start
	var n := float(_tail_n)
	for i in range(1,_tail_n+1):
		var p := _rope[i]
		var v := (p-_rope_prev[i])*0.94
		_rope_prev[i] = p
		p += v
		var bent := Basis(Vector3.UP,curl*float(i))*Basis(Vector3.RIGHT,droop*float(i)/n)
		var len_w := (basis*(bent*(_seg_dir[i-1] as Vector3)*_seg_len[i-1]))
		# Its rest line from the point before, firmer near the hips; a slow
		# wave down it, as a whip in the air.
		var rest := _rope[i-1]+len_w
		rest += basis.x.normalized()*sin(_clock*0.8-float(i)*0.7)*0.25*float(i)/n*len_w.length()
		if state == "clinging" and not grip.is_empty():
			# Hanging: down under the keel, swinging slowly side to side.
			rest += Vector3.DOWN*len_w.length()*0.35
			rest += (grip.tangent as Vector3)*sin(_clock*0.5-float(i)*0.32)*0.22*float(i)/n*len_w.length()
		p = p.lerp(rest,clampf((n+1.0-float(i))*5.4/n*delta,0.0,1.0))
		var d := p-_rope[i-1]
		_rope[i] = _rope[i-1]+d.normalized()*len_w.length()
	# The bones along the rope: each turned by its bend from the one before.
	var inv := basis.inverse()
	var prev_yaw := 0.0
	var prev_pitch := 0.0
	for i in range(_tail_n):
		var d: Vector3 = inv*(_rope[i+1]-_rope[i])
		var r: Vector3 = _seg_dir[i]
		var yaw_t := atan2(d.x,d.z)-atan2(r.x,r.z)
		var pitch_t := atan2(-d.y,Vector2(d.x,d.z).length())-atan2(-r.y,Vector2(r.x,r.z).length())
		var by := clampf(wrapf(yaw_t-prev_yaw,-PI,PI),-0.45,0.45)
		var bp := clampf(pitch_t-prev_pitch,-0.35,0.35)
		prev_yaw += by
		prev_pitch += bp
		_turn("tail.%d" % i,[[Vector3.UP,by],[Vector3.RIGHT,bp]])

func _turn(b: String, turns: Array) -> void:
	if not _bone.has(b): return
	var g: Basis = _rest_global[b]
	var q: Quaternion = _rest_local[b]
	for turn: Array in turns:
		var angle: float = turn[1]
		if absf(angle) < 0.00001: continue
		q = q*Quaternion((g.inverse()*(turn[0] as Vector3)).normalized(),angle)
	skeleton.set_bone_pose_rotation(_bone[b],q)

# --- The attack ------------------------------------------------------------------------

## The treasure on its tongue: a gem riding the jaw, a small light and a
## glint that flares now and then, big enough to catch the eye from afar.
func _build_treasure() -> void:
	treasure = Node3D.new()
	treasure.name = "Treasure"
	treasure.top_level = true
	add_child(treasure)
	var gem := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.9
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	gem.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd56a")
	m.metallic = 0.8
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = Color("ffb84a")
	m.emission_energy_multiplier = 3.0
	gem.material_override = m
	gem.name = "Gem"
	treasure.add_child(gem)
	_treasure_light = OmniLight3D.new()
	_treasure_light.light_color = Color("ffcf70")
	_treasure_light.light_energy = 1.4
	_treasure_light.omni_range = 7.0
	treasure.add_child(_treasure_light)
	_glint = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,1.0)
	_glint.mesh = quad
	var g := StandardMaterial3D.new()
	g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	g.no_depth_test = false
	g.albedo_color = Color(1.0,0.85,0.5,1.0)
	g.albedo_texture = _glint_texture()
	_glint.material_override = g
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	treasure.add_child(_glint)
	treasure.visible = false

## A four-pointed star of light.
static func _glint_texture() -> Texture2D:
	var n := 64
	var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var p := Vector2(x+0.5-n*0.5,y+0.5-n*0.5)/(n*0.5)
			var core := exp(-p.length_squared()*18.0)
			var rays := exp(-absf(p.x)*40.0)*(1.0-absf(p.y))+exp(-absf(p.y)*40.0)*(1.0-absf(p.x))
			var a := clampf(core+rays*0.8,0.0,1.0)
			img.set_pixel(x,y,Color(1,1,1,a))
	return ImageTexture.create_from_image(img)

## The gem on the tongue, between the jaw's root and its tip; the glint
## flaring every couple of seconds.
func _place_treasure(_delta: float) -> void:
	if treasure == null: return
	treasure.visible = model.visible and not taken
	if not treasure.visible: return
	# On the tongue near the front of the jaw (round 6: riding the jaw's
	# own frame, so it lies in the mouth when the chin rests on the turf, in
	# reach of a pilot up against the chin).
	treasure.global_position = _probe(_gem_on)
	treasure.scale = Vector3.ONE*size/TUNED_SIZE
	var flare := pow(maxf(sin(_clock*TAU/2.3),0.0),14.0)+0.5*pow(maxf(sin(_clock*TAU/3.7+1.0),0.0),20.0)
	_glint.scale = Vector3.ONE*(1.5+7.0*flare)
	(_glint.material_override as StandardMaterial3D).albedo_color.a = 0.25+0.75*flare
	_treasure_light.light_energy = 1.0+2.0*flare

## The next isle to attack (round 7): from `_target_i` round the list, the
## first that stands (its record known), that the pilot isn't on (unless
## --dragon-ride, which wants him on it), not the one it last let go of,
## and in the camera's view (within 75° of its look, 900 m); failing the
## view, the first of the rest. --dragon-target's pick holds the first time.
## Only an isle with room for its grip (`_has_room`); -1 when none has.
func _choose_target() -> int:
	var n := targets.size()
	if n == 0: return 0
	_target_forced_was = _target_forced
	if _target_forced:
		_target_forced = false
		return _target_i%n
	if ride:
		# On foot on it: the isle with the best grip (open turf, a level
		# lip, nothing under the body) of those that stand.
		var best := -1
		var top := -INF
		for i in range(n):
			var rec := _record(targets[i])
			if rec.is_empty() or not rec.has("shape") or not (rec.shape as RefCounted).has_method("open_at"): continue
			if not _has_room(targets[i]): continue
			_plan_grip(targets[i])
			if _best_score > top:
				top = _best_score
				best = i
		if best >= 0: return best
	# Round 8: of those that stand, the pilot isn't on and it didn't just
	# let go of, the one left longest since its last attack, with a minute's
	# head start for one in the camera's view (within 75°, 900 m). So it
	# favours what you can see but goes round all of them in time.
	var best := -1
	var top := -INF
	var roomy := -1
	for i in range(n):
		var t: Dictionary = targets[i]
		if not _has_room(t): continue
		# Failing all else, the first with room from `_target_i` round (one
		# not yet standing on its listed radius: planned again once it
		# stands, `_replan_attack`).
		if roomy < 0 or (i-_target_i+n)%n < (roomy-_target_i+n)%n: roomy = i
		var rec := _record(t)
		if find_isle.is_valid() and rec.is_empty(): continue
		if rec.has("home"): t.home = rec.home
		var at: Vector3 = t.home
		if walker != null and on_foot:
			var feet: Vector3 = walker.get("feet")
			if Vector2(feet.x-at.x,feet.z-at.z).length() < float(t.radius)+12.0: continue
		if i == _last_target and n > 1: continue
		var score := _clock-float(_attacked_at.get(i,-1000.0))
		if camera != null and camera.is_inside_tree():
			var c := camera.global_position
			var to := at-c
			var look := -camera.global_transform.basis.z
			if to.length() < 900.0 and Vector2(look.x,look.z).normalized().dot(Vector2(to.x,to.z).normalized()) > cos(deg_to_rad(75.0)): score += 60.0
		# Ties (none attacked yet) go round from `_target_i`.
		score -= 0.01*float((i-_target_i+n)%n)
		if score > top:
			top = score
			best = i
	return best if best >= 0 else roomy

## Round 1 of the grip at 1.5 (docs/design/dragon-grip/round1.md): the
## room a grip needs. A way round an isle counts only if its rim stands at
## least ROOM out from the isle's middle (m at TUNED_SIZE, scaled by `_k`:
## 35 m at 1.5; the chin lies about 13 m in from the lip at 0.85, 22 m at
## 1.5, so it lies short of the middle, where the isle runs on past it;
## tuned by tools/measure_dragon_grip.gd), both wrists find a
## lip of their own (not `_rim_line`'s fallback in open air), and the band
## the chin lies and sweeps on is at least ROOM_OPEN open turf with at most
## ROOM_TALL samples standing tall (`_best_turn`). An isle with no such way
## is never attacked: a ring 28 m across can't take a 30 m hand span, nor
## a bell field a 1.5 head. The aqueduct isle, the starter isle, is never
## a target at all (`_attackable`).
const ROOM := 20.0
const ROOM_OPEN := 0.75
const ROOM_TALL := 2
## A way without room (`ROOM`, a wrist on the fallback) loses this much in
## `_best_turn`, so it is chosen only where no way has room (a forced
## --dragon-target).
const NO_ROOM := 100.0

## The grip's distances tuned at TUNED_SIZE, as a factor for `size`.
func _k() -> float:
	return size/TUNED_SIZE

## Whether the dragon may attack `t`: never the aqueduct isle (the starter
## isle: the player shouldn't have to mind the dragon there; the host lists
## only the motif isles, and this keeps it so if it is ever listed) nor its
## own roost, and only an isle with room for its grip (`ROOM`): one way
## round it at least, scored by `_best_turn` on the isle's shape. Known
## once the isle stands (then kept on `t`); before that, its listed
## radius against ROOM.
func _has_room(t: Dictionary) -> bool:
	if not _attackable(t): return false
	if t.has("room"): return bool(t.room)
	var rec := _record(t)
	var shape: RefCounted = rec.get("shape") as RefCounted if rec.has("shape") else null
	if shape == null or not shape.has_method("open_at"): return float(t.radius) >= ROOM*_k()
	if rec.has("home"):
		t.home = rec.home
		t.radius = float(rec.radius)
	var keep_note := _grip_note
	var keep_score := _best_score
	_best_turn(t,shape,Vector3.FORWARD)
	t.room = _best_roomy
	if not _best_roomy: print("sky dragon: %s has no room for its grip at size %.2f (%s); it won't attack it" % [str(t.name),size,_grip_note])
	_grip_note = keep_note
	_best_score = keep_score
	return bool(t.room)

## Not the aqueduct isle (the starter isle: anything listed within its
## 60 m of `home`, its middle) nor the dragon's roost.
func _attackable(t: Dictionary) -> bool:
	if str(t.name) in ["aqueduct_isle","dragon_roost"]: return false
	if not spare_home: return true
	var at: Vector3 = t.home
	return Vector2(at.x-home.x,at.z-home.z).length() > 60.0

## The isle's move since the grip was planned (its shudder), as a transform
## to carry grip points along with it.
func _isle_xf() -> Transform3D:
	if gale == null or gale.isle == null or not is_instance_valid(gale.isle): return Transform3D.IDENTITY
	return gale.isle.transform*gale.isle_rest.affine_inverse()

## The isle's built record ({node, shape, ...}), or {}.
func _record(t: Dictionary) -> Dictionary:
	if not find_isle.is_valid(): return {}
	var rec: Variant = find_isle.call(str(t.name))
	return rec if rec is Dictionary else {}

## The rim's lip from the isle's middle along `dir` (flat, unit): the last
## land along it, at the ground there; else the radius at the rim's height.
func _rim_along(t: Dictionary, dir: Vector3) -> Vector3:
	var home: Vector3 = t.home
	var rec := _record(t)
	var shape: RefCounted = rec.get("shape") as RefCounted if rec.has("shape") else null
	if shape == null: return home+dir*float(t.radius)
	var reach := float(shape.get("reach")) if shape.get("reach") != null else float(t.radius)*1.5
	var last := Vector2.INF
	var r := 0.0
	while r <= reach+1.0:
		var p := Vector2(dir.x,dir.z)*r
		if shape.on_land(p): last = p
		elif last != Vector2.INF and r > 2.0: break
		r += 0.5
	if last == Vector2.INF: return home+dir*float(t.radius)
	return home+Vector3(last.x,float(shape.ground_at(last)),last.y)

## Where it will grip target `t`: the side it comes from (`turn`, or a coin
## for it), the rim there, its wrists and feet on the lip either side, where
## its root hangs and which way it faces. Seen from the aqueduct isle's
## turf, it clings on the isle's flank and a little beyond it, so the body
## shows beside the isle and the neck rears over the turf, and the blast
## crosses the view.
func _plan_grip(t: Dictionary, turn := 0.0) -> Dictionary:
	# A motif isle's record (round 7) knows its main land's middle and
	# radius once it stands: those, not the guess it was listed with.
	var rec := _record(t)
	if rec.has("home"):
		t.home = rec.home
		t.radius = float(rec.radius)
	var home: Vector3 = t.home
	var eye := _eye_for(t)
	var view := Vector3(home.x-eye.x,0.0,home.z-eye.z)
	view = view.normalized() if view.length() > 1.0 else Vector3.FORWARD
	var shape: RefCounted = rec.get("shape") as RefCounted if rec.has("shape") else null
	var scored := shape != null and shape.has_method("open_at")
	if turn == 0.0: turn = _best_turn(t,shape,view) if scored else 1.5*_clear_side(t,view,eye)
	var out := view.rotated(Vector3.UP,turn)
	var tangent := Vector3(-out.z,0.0,out.x)
	var rim := _rim_along(t,out)
	var right := (-out).cross(Vector3.UP).normalized()
	var wrists := {}
	var feet := {}
	for k in [-1.0,1.0]:
		var w: Vector3
		var f: Vector3
		if scored:
			# Its holds on the real lip either side, at the reach of its
			# wrists and feet (as on hills_ne's 14 m rim), wherever the
			# lip runs.
			w = _rim_line(t,out,right*k*HOLD_WRIST*_k(),rim)
			f = _rim_line(t,out,right*k*HOLD_FOOT*_k(),rim)
		else:
			w = _rim_along(t,out.rotated(Vector3.UP,0.62*k))
			f = _rim_along(t,out.rotated(Vector3.UP,0.2*k))
		var n := "R" if (w-rim).dot(right) > 0.0 else "L"
		wrists[n] = w
		feet["R" if (f-rim).dot(right) > 0.0 else "L"] = f
	var root := rim+out*CLING_OUT*size/TUNED_SIZE-Vector3.UP*CLING_DOWN*size/TUNED_SIZE
	return {"target":t,"turn":turn,"rim":rim,"out":out,"tangent":tangent,"side":signf(turn),
		"wrists":wrists,"feet":feet,"root":root,"yaw":atan2(out.x,out.z),"scored":scored}

## The eye the grip is planned for: the camera when it is off the isle
## (the player's view), else the aqueduct isle's turf.
func _eye_for(t: Dictionary) -> Vector3:
	var at: Vector3 = t.home
	# The ride (round 8): another isle is gripped on its flank as seen
	# from yours, where the pilot stands watching.
	if ride and not _is_ride_home(t):
		return targets[_ride_home].home
	if not ride and camera != null and camera.is_inside_tree():
		var c := camera.global_position
		if Vector2(c.x-at.x,c.z-at.z).length() > float(t.radius)+30.0: return c
	return shadow_at if shadow_at != Vector3.INF else at

## The lip along `out` from the line `by` (flat) off the isle's middle (the
## last land along it), at the ground there; else the main rim moved by
## `by` (no land on that line: a hold in open air), and `_rim_fell` says
## so until the next call.
var _rim_fell := false
func _rim_line(t: Dictionary, out: Vector3, by: Vector3, rim: Vector3) -> Vector3:
	var at: Vector3 = t.home
	var shape: RefCounted = _record(t).get("shape") as RefCounted
	var last := Vector2.INF
	var r := 0.0
	var reach := float(shape.get("reach"))
	while r <= reach+1.0:
		var p := Vector2(by.x+out.x*r,by.z+out.z*r)
		if shape.on_land(p): last = p
		elif last != Vector2.INF and r > 2.0: break
		r += 0.5
	_rim_fell = last == Vector2.INF
	if _rim_fell: return rim+by
	return at+Vector3(last.x,float(shape.ground_at(last)),last.y)

## A motif isle's grip (round 7): of 48 ways out round it, the best by
## open turf inside the rim where the chin will lie and the neck reach (no
## ruin, bell, tree or water: `open_at`), no other land under its body
## beyond the rim (a satellite, a spire), a lip at its wrists' reach either
## side at the rim's height, a rim not too near the middle (the tip goes as
## the sag over it), and (off the isle) a flank as seen from the eye, so
## the body shows in profile. The way as a turn from `view`.
## Its distances were tuned at TUNED_SIZE and scale by `_k` (the grip at
## 1.5): the chin lies about 13 m in from the lip at 0.85, 22 m at 1.5, so
## the bands are sampled where it lands. A way without room (`ROOM`, or a
## wrist with no lip of its own) loses NO_ROOM; `_best_roomy` says whether
## the best way has room.
const HOLD_WRIST := 8.5
const HOLD_FOOT := 2.8
var _best_roomy := false
func _best_turn(t: Dictionary, shape: RefCounted, view: Vector3) -> float:
	var k := _k()
	var best := 1.5
	var best_score := -INF
	for i in range(48):
		var turn := -PI+TAU*float(i)/48.0
		var out := view.rotated(Vector3.UP,turn)
		var rim := _rim_along(t,out)
		var at: Vector3 = t.home
		var r_flat := Vector2(rim.x-at.x,rim.z-at.z)
		var r := r_flat.length()
		var right := (-out).cross(Vector3.UP).normalized()
		var score := 0.0
		# Open turf inside the rim, along the chin's line and either side.
		var open := 0
		var count := 0
		var rise := 0.0
		for d: float in [3.0,5.0,7.0,9.0,11.0,13.0,16.0]:
			for side: float in [-3.0,0.0,3.0]:
				var p: Vector2 = r_flat-Vector2(out.x,out.z)*d*k+Vector2(right.x,right.z)*side*k
				count += 1
				if shape.open_at(p,1.2*k): open += 1
				# The turf the chin lies on near the lip's height: not a
				# ridge climbing away from it, nor a hollow.
				if d <= 11.0 and shape.on_land(p): rise = maxf(rise,absf(at.y+float(shape.ground_at(p))-rim.y)-0.4*d*k)
		score += 6.0*float(open)/float(count)
		score -= minf(rise*0.5,4.0)
		# Round 8: nothing tall where the head pants and sweeps (a bell's
		# frame, a wall): it can't lie there, and lifted over it, it hangs.
		var tall := 0
		if shape.has_method("solid_at"):
			for d: float in [4.0,7.0,10.0,13.0]:
				for side: float in [-6.0,-3.0,0.0,3.0,6.0]:
					var p: Vector2 = r_flat-Vector2(out.x,out.z)*d*k+Vector2(right.x,right.z)*side*k
					var top: Variant = shape.solid_at(p)
					var turf: Variant = shape.turf_at(p)
					if top != null and float(top)-(float(turf) if turf != null else 0.0) > 2.0: tall += 1
		score -= 0.5*float(tall)
		# Nothing under its body beyond the rim.
		for d: float in [4.0,10.0,18.0,28.0,40.0,55.0]:
			for side: float in [-12.0,0.0,12.0]:
				var p: Vector2 = r_flat+Vector2(out.x,out.z)*d*k+Vector2(right.x,right.z)*side*k
				if shape.on_land(p): score -= 1.5
		# A lip at the wrists' reach either side, near the rim's height; a
		# wrist with none (the fallback, a claw in open air) has no room.
		var roomy := r >= ROOM*k
		for kk: float in [-1.0,1.0]:
			var w := _rim_line(t,out,right*kk*HOLD_WRIST*k,rim)
			if _rim_fell: roomy = false
			var miss := absf(w.y-rim.y)+maxf(absf((w-rim).dot(out))-6.0*k,0.0)
			score -= minf(miss*0.25,2.0)
		# And the chin's band mostly open turf, with little standing tall
		# in it: at 1.5 the head can't lie among bell spires or cloister
		# walls, lifted over them it hangs, and in the blow it sweeps into
		# them.
		if float(open) < ROOM_OPEN*float(count) or tall > ROOM_TALL: roomy = false
		if not roomy: score -= NO_ROOM
		# A rim neither at the middle nor far out on a spit.
		if r < 10.0*k: score -= (10.0*k-r)*0.4/k
		if r > 34.0*k: score -= (r-34.0*k)*0.08/k
		# Seen in profile from off the isle.
		if not ride or not _is_ride_home(t): score += 1.5*(1.0-absf(absf(turn)-1.5)/1.5)
		if score > best_score:
			best_score = score
			best = turn
			_best_score = score
			_best_roomy = roomy
			_grip_note = "open %.0f%%, rise %.1f m, %d tall, rim %.0f m out, score %.1f%s" % [100.0*float(open)/float(count),rise,tall,r,score,"" if roomy else ", no room"]
	return best

## Which flank (1 or -1) shows from `eye`: the one whose rim stands
## furthest, as seen, from any nearer isle in front of it.
func _clear_side(t: Dictionary, view: Vector3, eye: Vector3) -> float:
	var home: Vector3 = t.home
	var best := 1.0
	var best_gap := -INF
	for k in [1.0,-1.0]:
		var at := home+view.rotated(Vector3.UP,1.5*k)*(float(t.radius)+10.0)-Vector3.UP*10.0
		var d := at-eye
		var gap := INF
		for isle: Array in isles:
			var p: Vector3 = isle[0]
			if p.distance_to(home) < 1.0: continue
			var to := p-eye
			if to.length() >= d.length() or to.length() < 60.0: continue
			gap = minf(gap,to.angle_to(d)-atan2(float(isle[1])*1.6,to.length()))
		if gap > best_gap:
			best_gap = gap
			best = k
	return best

## Off to attack the next target: in wide and banking round, then low
## outside its rim, where the grab begins.
func _add_attack() -> void:
	var pick := _choose_target()
	if pick < 0:
		# No isle with room for its grip: round again, and try later.
		_add_circuit()
		_attack_in = _attack_every*_rng.randf_range(0.85,1.2)
		return
	_target_i = pick
	_last_target = _target_i
	_attacked_at[_target_i] = _clock
	var t: Dictionary = targets[_target_i%targets.size()]
	grip = _plan_grip(t)
	var out: Vector3 = grip.out
	var tangent: Vector3 = grip.tangent
	var root: Vector3 = grip.root
	route.append(_attack_way(grip))
	route.append(_grab_way(grip))
	_leg_kinds.append("attack")
	_leg_kinds.append("grab")
	_attack_in = INF
	print("sky dragon: off to attack %s, %.0f m from the isle's middle" % [str(t.name),Vector2(root.x-home.x,root.z-home.z).length()])

## The attack's way in (wide, banking round) and where the grab begins.
func _attack_way(g: Dictionary) -> Vector3:
	return (g.root as Vector3)+(g.out as Vector3)*240.0+(g.tangent as Vector3)*float(g.side)*130.0+Vector3.UP*28.0

func _grab_way(g: Dictionary) -> Vector3:
	return (g.root as Vector3)+(g.out as Vector3)*95.0+Vector3.UP*6.0

## On its way in to an isle that hadn't stood when it was planned (round
## 7: the motif isles come up a while after the scene): once it stands, the
## grip planned again on its real land and the way in moved to suit.
func _replan_attack() -> void:
	if grip.is_empty() or bool(grip.get("scored",true)) or _leg_kinds.is_empty() or not (_leg_kinds[0] in ["attack","grab"]): return
	if _record(grip.target).is_empty(): return
	if _turned_away(): return
	grip = _plan_grip(grip.target)
	if not bool(grip.scored): return
	if _leg_kinds[0] == "attack": route = [_attack_way(grip),_grab_way(grip)]
	else: route = [_grab_way(grip)]
	print("sky dragon: %s stands now: its grip planned again (%s)" % [str(grip.target.name),_grip_note])

## An isle picked before it stood (on its listed radius) that, standing,
## has no room for the grip (`_has_room`): off round again, to try another
## later. Not --dragon-target's pick, which is held regardless.
func _turned_away() -> bool:
	if grip.is_empty() or _target_forced_was or _record(grip.target).is_empty() or _has_room(grip.target): return false
	print("sky dragon: %s stands now, with no room for its grip: it turns away" % str(grip.target.name))
	state = "roaming"
	route.clear()
	_leg_kinds.clear()
	grip = {}
	_add_circuit()
	_attack_in = _attack_every*_rng.randf_range(0.85,1.2)
	return true

## The grab begins: from its flight into a hard flare and onto the rim.
func _begin_grab() -> void:
	if _turned_away(): return
	# The isle may have stood up since the plan: the rim again, same side.
	grip = _plan_grip(grip.target,float(grip.turn))
	var fwd := Vector3(-sin(yaw)*cos(gamma),sin(gamma),-cos(yaw)*cos(gamma))
	_grab = {"p0":pos,"v0":fwd*speed,"yaw0":yaw,"pitch0":gamma*0.75+0.05,"roll0":roll,"t":0.0}
	state = "grabbing"
	route.clear()
	_leg_kinds.clear()
	leg_kind = "grab"

## The grab: a curve from where it was (at its speed) to its hold on the
## rim, arriving slowed but still coming; it pitches up into a flare, the
## wings cupped and beating back hard, the legs swung forward to reach.
func _grabbing(delta: float) -> void:
	_grab.t = float(_grab.t)+delta
	var u := clampf(float(_grab.t)/GRAB,0.0,1.0)
	var p0: Vector3 = _grab.p0
	var p1: Vector3 = grip.root
	var m0: Vector3 = (_grab.v0 as Vector3)*GRAB
	m0 = m0.limit_length(p0.distance_to(p1)*1.25)
	var m1: Vector3 = (-(grip.out as Vector3)*0.5+Vector3.DOWN*0.8).normalized()*14.0
	var u2 := u*u
	var u3 := u2*u
	pos = p0*(2.0*u3-3.0*u2+1.0)+m0*(u3-2.0*u2+u)+p1*(-2.0*u3+3.0*u2)+m1*(u3-u2)
	yaw = lerp_angle(float(_grab.yaw0),float(grip.yaw),smoothstep(0.0,0.8,u))
	var pitch := lerpf(float(_grab.pitch0),CLING_PITCH*0.92,smoothstep(0.15,0.9,u))
	gamma = (pitch-0.05)/0.75
	roll = lerpf(float(_grab.roll0),0.0,smoothstep(0.0,0.6,u))
	_free = 1.0-smoothstep(0.0,0.5,u)
	_flare = smoothstep(0.3,0.75,u)
	mode = "climb"
	# Hard back-beats through the flare.
	flap_w = 1.0
	phase = fposmod(phase+delta*lerpf(BEAT,0.75,_flare),1.0)
	if u >= 1.0: _slam()

## On the rim: it holds on, the isle shudders, dust and stone come off,
## the isle's birds burst out.
func _slam() -> void:
	state = "clinging"
	# Round 8: a longer blend onto the rim (0.3 s popped the head).
	_snapshot(0.75)
	_free = 0.0
	_flare = 0.0
	var t: Dictionary = grip.target
	var rec := _record(t)
	gale.hold_isle(rec.get("node") as Node3D if rec.has("node") else null,rec.get("shape") as RefCounted if rec.has("shape") else null,t.home,float(t.radius),grip.out,grip.rim,
		rec.get("frame",Transform3D.IDENTITY),rec.get("pivot",Vector3.INF))
	gale.slam(grip.rim,grip.out,grip.tangent)
	# Its rays at the turf skip the isle's other lands (a spire's top).
	var skip: Array[RID] = [chin.get_rid()]
	for rid: RID in rec.get("exclude",[]): skip.append(rid)
	_ray.exclude = skip
	if flush_birds.is_valid(): flush_birds.call(t.home)
	_c_settle_v = -7.0
	_cling_t = 0.0
	_cling_left = _rng.randf_range(CLING_HOLD.x,CLING_HOLD.y) if _cling_for < 0.0 else _cling_for
	if ride: _cling_left = RIDE_HOLD if (_target_i == _ride_home or ride_repeat) else RIDE_AWAY
	_set_breath("settle",2.6)
	_c_look_next = 0.0
	_roar_t = -1.0
	grip_beat.emit("grab")
	_stagger_pilot()
	print("sky dragon: it grips %s's rim at (%.0f, %.0f, %.0f); lets go in %.0f s (%s)" % [str(t.name),(grip.rim as Vector3).x,(grip.rim as Vector3).y,(grip.rim as Vector3).z,_cling_left,_grip_note])

func _set_breath(to: String, length: float) -> void:
	breath = to
	_breath_t = 0.0
	_breath_len = length
	if to == "blow":
		# One knock a blast (its ribbons run on after the blow).
		_knocked = false
		_sweep_from = SWEEP if _rng.randf() < 0.5 else -SWEEP
		gale.deepen()

## Holding on: the breath's beats, its pose, the gale and the pilot.
func _clinging(delta: float) -> void:
	_cling_t += delta
	_cling_left -= delta
	_breath_t += delta
	if _breath_t >= _breath_len:
		match breath:
			"settle": _set_breath("pant",_pant_length())
			"pant":
				if _cling_left <= 0.0:
					# Round 9: one last heavy haul on the rim (the tell),
					# then it lets go.
					_set_breath("pull",PULL)
					gale.pull_down()
					grip_beat.emit("pull")
					print("sky dragon: the last haul on %s's rim, isle tipped %.0f°" % [str(grip.target.name),rad_to_deg(gale.tip())])
				else:
					_set_breath("inhale",INHALE)
					grip_beat.emit("inhale")
			"pull":
				_let_go()
				return
			"inhale": _set_breath("blow",BLOW)
			"blow": _set_breath("recover",RECOVER)
			"recover": _set_breath("pant",_pant_length())
	_cling_pose(delta)
	var mouth := mouth_at()
	var way := blast_way()
	match breath:
		"inhale":
			if _breath_t > 0.3: gale.inhale(mouth,way,delta)
		"blow":
			var env := blow_envelope()
			gale.blow(mouth,way,env,delta)
			if gale.take_crumble(): gale.crumble(grip.rim,grip.out,grip.tangent,14.0)
	# Round 10: the wind on the pilot is the ribbons' own, wherever they
	# are now (they run on after the blow).
	_blow_on_pilot(delta,mouth)
	if (breath == "pull" or (breath == "settle" and _breath_t < 1.6)) and _rng.randf() < delta*8.0: gale.crumble(grip.rim,grip.out,grip.tangent,12.0)
	_touch_treasure()

func _pant_length() -> float:
	var span := RIDE_PANT if ride else PANT
	return _rng.randf_range(span.x,span.y)

## The blow's strength through its beat: quick in, held, eased out.
func blow_envelope() -> float:
	return smoothstep(0.0,0.35,_breath_t)*(1.0-smoothstep(BLOW-0.7,BLOW,_breath_t))

## Seconds into its roar now, or below 0 between roars (read by its sound,
## scripts/kit_isle/kit_audio_beasts.gd).
func roar_time() -> float:
	return _roar_t

## The mouth (world): the jaw's tip.
func mouth_at() -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(_bone["jaw.tip"]).origin

## Which way it blows, flat (unit): in across the isle, turned by the
## head's sweep.
func blast_way() -> Vector3:
	if grip.is_empty(): return Vector3.FORWARD
	return (-(grip.out as Vector3)).rotated(Vector3.UP,_c_look.x*float(_sweep_sign)).normalized()

## The pose on the rim. The body hangs nose up with its belly to the cliff,
## heaving as it breathes; the wrists' thumbs and the hind claws are reached
## to the lip (a little IK each frame); the neck rears over the turf and
## turns, looking round, drawing back on the inhale and thrusting and
## sweeping on the blow; the mouth pants open, the tail hangs under the keel.
func _cling_pose(delta: float) -> void:
	var xf := _isle_xf()
	var out: Vector3 = grip.out
	var u := _breath_t/maxf(_breath_len,0.01)
	var rear_goal := 0.0
	var jaw := 0.0
	var wing_open := 0.2
	var yaw_goal := 0.0
	var pant := 0.0
	match breath:
		"settle":
			jaw = 0.42*sin(PI*clampf(_breath_t/1.6,0.0,1.0))
			rear_goal = 0.5*sin(PI*clampf(_breath_t/2.0,0.0,1.0))
			wing_open = lerpf(0.75,0.2,smoothstep(0.0,1.0,u))
		"pant":
			pant = 1.0
			jaw = 0.26+0.07*sin(_clock*TAU*1.4)
			rear_goal = -0.15
		"inhale":
			jaw = lerpf(0.2,0.42,smoothstep(0.0,1.0,u))
			rear_goal = smoothstep(0.0,0.8,u)
			wing_open = lerpf(0.2,0.5,u)
		"blow":
			var env := blow_envelope()
			jaw = lerpf(0.42,0.66,smoothstep(0.0,0.3,_breath_t))+0.006*sin(_clock*17.0)
			rear_goal = lerpf(1.0,-0.5,smoothstep(0.0,0.4,_breath_t))
			wing_open = 0.5+0.25*env
			yaw_goal = lerpf(_sweep_from,-_sweep_from,smoothstep(0.1,0.9,u))
		"pull":
			# Round 9: hauling the rim down, jaw clenched, reared back,
			# wings half open for the heave.
			jaw = 0.08
			rear_goal = lerpf(0.0,0.7,smoothstep(0.0,0.6,u))
			wing_open = lerpf(0.2,0.6,u)
		"recover":
			jaw = lerpf(0.5,0.28,u)
			rear_goal = lerpf(-0.5,-0.15,smoothstep(0.0,1.0,u))
			wing_open = lerpf(0.75,0.2,u)
	# Looking round between blasts: a new glance every couple of seconds.
	if breath in ["pant","settle","recover"]:
		_c_look_next -= delta
		if _c_look_next <= 0.0:
			_c_look_next = _rng.randf_range(1.4,3.2)
			_c_look_goal = Vector2(_rng.randf_range(-0.6,0.6),_rng.randf_range(-0.2,0.25))
		yaw_goal = _c_look_goal.x
	_c_look_v += ((Vector2(yaw_goal,_c_look_goal.y*(1.0 if pant > 0.0 else 0.0))-_c_look)*(14.0 if breath == "blow" else 5.0)-_c_look_v*(5.5 if breath == "blow" else 3.4))*delta
	_c_look += _c_look_v*delta
	_c_rear_v += ((rear_goal-_c_rear)*12.0-_c_rear_v*5.0)*delta
	_c_rear += _c_rear_v*delta
	_c_settle_v += (-_c_settle*16.0-_c_settle_v*3.0)*delta
	_c_settle += _c_settle_v*delta
	_jaw_goal = jaw
	# The body.
	# The breathing's pace eases between panting and slow breaths, its
	# phase carried on (a switch of pace never jumps the heave).
	_heave_hz = move_toward(_heave_hz,0.6 if pant > 0.0 else 0.22,delta*0.5)
	_heave_ph = fposmod(_heave_ph+delta*TAU*_heave_hz,TAU)
	var heave := sin(_heave_ph)
	var pitch := CLING_PITCH+_c_rear*0.1+0.02*heave
	var basis := Basis(Vector3.UP,float(grip.yaw))*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,0.03*sin(_clock*0.37))
	pos = xf*(grip.root as Vector3)+Vector3.UP*_c_settle+out*(_c_rear*0.9)
	# Round 8: it hangs on the tipping rim, tipped with the isle.
	var tip_q := Quaternion.IDENTITY.slerp(xf.basis.get_rotation_quaternion(),BODY_TIP)
	global_transform = Transform3D(Basis(tip_q)*basis,pos)
	yaw = float(grip.yaw)
	_set_chest(Vector3(1.0+0.05*heave*(0.4+pant),1.0,1.0+0.06*heave*(0.4+pant)),delta)
	_turn("chest",[[Vector3.RIGHT,-0.04*_c_rear]])
	_turn("hips",[[Vector3.RIGHT,0.1]])
	_turn("spine.2",[[Vector3.RIGHT,-0.1]])
	var sk_inv := skeleton.global_transform.affine_inverse()
	for side in [-1.0,1.0]:
		var n := "L" if side < 0.0 else "R"
		var fold := 1.0-wing_open
		_turn("wing_arm."+n,[[Vector3.BACK,-side*0.5],[Vector3.UP,side*0.3]])
		_turn("wing_fore."+n,[[Vector3.UP,side*fold*0.9]])
		_turn("wing_hand."+n,[[Vector3.UP,-side*fold*1.6],[Vector3.BACK,-side*0.25]])
		_turn("wing_f1."+n,[[Vector3.BACK,side*0.1]])
		_turn("wing_f1b."+n,[[Vector3.BACK,side*0.15]])
		_turn("wing_f2."+n,[[Vector3.UP,side*fold*0.2]])
		_turn("wing_f3."+n,[[Vector3.UP,side*fold*0.4]])
		_turn("wing_f4."+n,[[Vector3.UP,side*fold*0.6]])
		var wrist: Vector3 = xf*(grip.wrists[n] as Vector3)+Vector3.UP*0.8*size-out*1.2*size
		_reach(["wing_arm."+n,"wing_fore."+n],"wing_hand."+n,sk_inv*wrist)
		_seat_thumb(n,wrist,xf*(grip.wrists[n] as Vector3)-out*THUMB_IN*_k(),sk_inv)
		_turn("hind_upper."+n,[[Vector3.RIGHT,0.5]])
		_turn("hind_lower."+n,[[Vector3.RIGHT,-0.3]])
		_turn("hind_foot."+n,[[Vector3.RIGHT,0.9]])
		var foot: Vector3 = xf*(grip.feet[n] as Vector3)-Vector3.UP*1.0*size+out*0.4*size
		_reach(["hind_upper."+n,"hind_lower."+n],"hind_foot."+n,sk_inv*foot)
	# The neck: bent forward to carry the head out level over the turf
	# (the body's pitch undone), turned round its own root to look and
	# sweep, drawn back and up on the inhale, thrust on the blow. Between
	# blasts (round 6) the chin comes down to rest on the turf and the
	# glances shrink to small turns of the head where it lies.
	var rest_goal := 1.0 if breath == "pant" or (breath == "settle" and _breath_t > 1.2) or (breath == "recover" and u > 0.35) else 0.0
	_rest_w = move_toward(_rest_w,rest_goal,delta*(1.4 if rest_goal > _rest_w else 1.8))
	_neck_look = Vector2(_c_look.x*(1.0-0.75*_rest_w),_c_look.y*(1.0-_rest_w))
	# Resting, it pants with the mouth a little open: the head bobbing up
	# off the jaw that lies on the turf.
	if breath == "pant": _jaw_goal = lerpf(_jaw_goal,0.15+0.07*sin(_clock*TAU*1.4),_rest_w)
	_pose_neck()
	_mouth(delta)
	_rest_dt = delta
	_rest_head()
	_tail(delta)

## The neck and head as `_cling_pose` sets them.
func _pose_neck() -> void:
	var look_yaw := _neck_look.x
	var look_pitch := _neck_look.y
	var bends := [0.0,-0.3,-0.34,-0.24]
	for i in range(_neck_n):
		var b: float = bends[mini(i,bends.size()-1)]
		var u_n := float(i)/maxf(_neck_n-1,1)
		var rear := _c_rear*lerpf(0.32,-0.1,u_n)
		var wave := 0.03*sin(_clock*0.9-float(i)*0.6)
		_turn("neck.%d" % i,[[Vector3.FORWARD,look_yaw*lerpf(0.4,0.1,u_n)],[Vector3.RIGHT,b+rear+wave]])
	_turn("head",[[Vector3.RIGHT,-0.12+look_pitch+_c_rear*0.25],[Vector3.UP,look_yaw*0.35]])

## The neck's and head's turns now, to bend from (`_bend_neck`).
func _keep_neck() -> void:
	_neck_base.clear()
	for i in range(_neck_n): _neck_base.append(skeleton.get_bone_pose_rotation(_bone["neck.%d" % i]))
	_neck_base.append(skeleton.get_bone_pose_rotation(_bone["head"]))

## The kept neck lowered `lift` (radians about each bone's own right, its
## LIFT_SHARE on each) and the head nodded `nod` more.
func _bend_neck(lift: float, nod: float) -> void:
	for i in range(_neck_n+1):
		var b := "neck.%d" % i if i < _neck_n else "head"
		var angle: float = nod if i == _neck_n else lift*float(LIFT_SHARE[mini(i,LIFT_SHARE.size()-1)])
		var axis := ((_rest_global[b] as Basis).inverse()*Vector3.RIGHT).normalized()
		skeleton.set_bone_pose_rotation(_bone[b],(_neck_base[i] as Quaternion)*Quaternion(axis,angle))

## Round 8: the head and neck kept out of the isle smoothly. The isle is
## read from its shape (scripts/dragon_isle_shape.gd, sampled once at rest)
## posed as it stands now (`_land`), not from raw rays each frame, so the
## floor under a probe is a smooth field, not collider edges. What clears
## the head is a goal (lift, nod) it springs toward, rate-limited, and what
## the neck can't clear the body eases up out of: never a push or a bump in
## one frame.
const CLEAR_GAP := 0.25
const CLEAR_W := 12.0
const CLEAR_RATE := Vector2(1.2,1.8)
const BODY_W := 6.0
## The most the body is eased up out of the isle (m, at TUNED_SIZE; scaled
## by `_k`).
const BODY_MOST := 6.0
## The most each neck bone and the head may turn against the body (rad/s):
## the last guard against a pop.
const NECK_RATE := 1.6
## Share of the isle's tip the clinging body takes with it (round 8): it
## hangs on the tipping rim, so the tipped turf no longer rises into its
## pose's head.
const BODY_TIP := 1.0
var _clr := Vector2.ZERO
var _clr_v := Vector2.ZERO
var _body_up := 0.0
var _body_up_v := 0.0
var _body_goal := 0.0
var _neck_was: Array = []
var _land := {}

## The gripped isle's shape and its frame as posed now ({} without one).
func _land_now() -> Dictionary:
	if grip.is_empty(): return {}
	var rec := _record(grip.target)
	if rec.is_empty() or not rec.has("shape") or not (rec.shape as RefCounted).has_method("top_at"): return {}
	var node: Node3D = rec.node
	if node == null or not is_instance_valid(node): return {}
	var xf: Transform3D = node.global_transform*(rec.frame as Transform3D)
	return {"shape":rec.shape,"xf":xf,"inv":xf.affine_inverse()}

## How far `p` (world) stands over the isle's floor along its up (m), or INF
## where there is none under it. `head`: its turf and anything standing on
## it within 5 m over the probe (a ruin's wall, not an arch far overhead);
## else (the neck) its turf and rock, unless the probe is deep under the lip
## beside the cliff.
func _floor_gap(p: Vector3, head: bool) -> float:
	if _land.is_empty(): return INF
	var l: Vector3 = (_land.inv as Transform3D)*p
	var flat := Vector2(l.x,l.z)
	var shape: RefCounted = _land.shape
	var under := -INF
	var turf: Variant = shape.turf_at(flat)
	if turf != null: under = float(turf)
	var top: Variant = shape.solid_at(flat) if head else shape.top_at(flat)
	if top != null and (not head or float(top) < l.y+5.0): under = maxf(under,float(top))
	if under == -INF: return INF
	if not head and l.y < under-NECK_DEEP*_k(): return INF
	return l.y-under

## The chin's two probes over the turf (m, less CHIN_GAP) bent `lift` and
## `nod`.
func _chin_error(lift: float, nod: float) -> Vector2:
	_bend_neck(lift,nod)
	return Vector2(_floor_gap(_probe(_chin_back),true)-CHIN_GAP,_floor_gap(_probe(_chin_front),true)-CHIN_GAP)

## The chin laid on the isle while it rests (round 6, `_rest_w`): the lift
## and nod that lay the jaw's floor flush on the turf, back and front (a
## few Newton steps a frame from last frame's, so it follows the isle's
## groan), blended in by `_rest_w` (eased). The jaw's own opening is on top,
## so it lies still and the head lifts off it to pant.
func _rest_head() -> void:
	_land = _land_now()
	if _chin_back.is_empty() or _chin_front.is_empty() or not is_inside_tree(): return
	if _rest_w <= 0.001:
		_rest_app = Vector2(_rest_lift,_rest_nod)
		_rest_app_v = Vector2.ZERO
		return
	_keep_neck()
	var lift := _rest_lift
	var nod := _rest_nod
	var e0 := _chin_error(lift,nod)
	if is_finite(e0.x) and is_finite(e0.y):
		for k in range(3):
			var e := _chin_error(lift,nod)
			if e.length() < 0.01: break
			var a := (_chin_error(lift+0.02,nod)-e)/0.02
			var b := (_chin_error(lift,nod+0.02)-e)/0.02
			var det := a.x*b.y-b.x*a.y
			if absf(det) < 1e-3 or not is_finite(det): break
			lift = clampf(lift+clampf((-e.x*b.y+b.x*e.y)/det,-0.3,0.3),-1.8,1.4)
			nod = clampf(nod+clampf((-a.x*e.y+a.y*e.x)/det,-0.3,0.3),-1.4,1.4)
		_rest_lift = lift
		_rest_nod = nod
	# Laid on through a spring at a limited rate, so a solve that jumps
	# (the head high off the turf as it comes down) never pops the head.
	var goal := Vector2(_rest_lift,_rest_nod)
	_rest_app_v += ((goal-_rest_app)*64.0-_rest_app_v*16.0)*_rest_dt
	_rest_app_v = _rest_app_v.limit_length(0.8)
	_rest_app += _rest_app_v*_rest_dt
	chin_miss = _chin_error(_rest_app.x,_rest_app.y)
	var w := smoothstep(0.0,1.0,_rest_w)
	_bend_neck(_rest_app.x*w,_rest_app.y*w)

## No probe in the isle as it stands now (after the blend and the isle's
## move this frame). Each frame the smallest lift and nod that clear the
## deepest probes (a few Newton steps from none) is the goal; the neck
## springs toward it at a limited rate. What is left in, the body eases up
## out of over a few frames. On the rim, the grab and the let-go alike.
func _clear_turf(delta: float) -> void:
	_land = _land_now()
	if _chin_back.is_empty() or not is_inside_tree() or _land.is_empty():
		_relax_clear(delta)
		return
	# The body's ease up out of the isle (what last frame left in).
	_body_up_v += ((_body_goal-_body_up)*BODY_W*BODY_W-2.0*BODY_W*_body_up_v)*delta
	_body_up = maxf(_body_up+_body_up_v*delta,0.0)
	if _body_up > 0.0005:
		pos += Vector3.UP*_body_up
		global_position = pos
	_keep_neck()
	var probes: Array = _probes_head+_probes_neck
	var nh := _probes_head.size()
	var gaps := func() -> float:
		var worst := INF
		for i in range(probes.size()): worst = minf(worst,_floor_gap(_probe(probes[i]),i < nh))
		return worst
	var worst0: float = gaps.call()
	if is_finite(worst0): sunk_before = minf(sunk_before,worst0)
	# The goal: from none, the deepest probe lifted clear by the neck or the
	# nod, whichever moves it more.
	var goal := Vector2.ZERO
	for k in range(6):
		_bend_neck(goal.x,goal.y)
		var worst := CLEAR_GAP
		var worst_i := -1
		for i in range(probes.size()):
			var g := _floor_gap(_probe(probes[i]),i < nh)
			if g < worst:
				worst = g
				worst_i = i
		if worst_i < 0: break
		_bend_neck(goal.x+0.03,goal.y)
		var dl := (_floor_gap(_probe(probes[worst_i]),worst_i < nh)-worst)/0.03
		_bend_neck(goal.x,goal.y+0.03)
		var dn := (_floor_gap(_probe(probes[worst_i]),worst_i < nh)-worst)/0.03
		var need := CLEAR_GAP+0.05-worst
		if absf(dl) >= absf(dn) and absf(dl) > 0.05: goal.x += clampf(need/dl,-0.4,0.4)
		elif absf(dn) > 0.05: goal.y += clampf(need/dn,-0.4,0.4)
		else: break
	goal = Vector2(clampf(goal.x,-1.2,1.2),clampf(goal.y,-1.2,1.2))
	# Sprung toward it, critically damped, at a limited rate.
	_clr_v += ((goal-_clr)*CLEAR_W*CLEAR_W-_clr_v*2.0*CLEAR_W)*delta
	_clr_v = Vector2(clampf(_clr_v.x,-CLEAR_RATE.x,CLEAR_RATE.x),clampf(_clr_v.y,-CLEAR_RATE.y,CLEAR_RATE.y))
	_clr += _clr_v*delta
	_bend_neck(_clr.x,_clr.y)
	_limit_neck(delta)
	var left: float = gaps.call()
	if is_finite(left):
		sunk_after = minf(sunk_after,minf(left,0.0))
		# Still in it (the neck lagging, the isle springing up under it): the
		# body eased up out of it; clear by a margin, it eases back down.
		_body_goal = clampf(_body_up-(left-CLEAR_GAP),0.0,BODY_MOST*_k())
	else: _body_goal = 0.0

## Off any isle: the clearance and the body's lift ease away.
func _relax_clear(delta: float) -> void:
	_clr = _clr.lerp(Vector2.ZERO,1.0-exp(-delta*3.0))
	_clr_v = Vector2.ZERO
	_body_goal = 0.0
	_body_up = lerpf(_body_up,0.0,1.0-exp(-delta*3.0))
	_body_up_v = 0.0
	_neck_was.clear()

## Each neck bone's and the head's turn moved from last frame's toward the
## pose's at a speed that builds up and brakes at most NECK_ACCEL rad/s²,
## up to NECK_RATE rad/s: a heavy neck, never a jump to full speed.
const NECK_ACCEL := 7.0
var _neck_speed: PackedFloat32Array = []
func _limit_neck(delta: float) -> void:
	var names: Array = []
	for i in range(_neck_n): names.append("neck.%d" % i)
	names.append("head")
	if _neck_was.size() != names.size():
		_neck_was.clear()
		_neck_speed.resize(names.size())
		for i in range(names.size()):
			_neck_was.append(skeleton.get_bone_pose_rotation(_bone[names[i]]))
			_neck_speed[i] = 0.0
		return
	for i in range(names.size()):
		var bi: int = _bone[names[i]]
		var now := skeleton.get_bone_pose_rotation(bi)
		var was: Quaternion = _neck_was[i]
		var angle := was.angle_to(now)
		# Speed up by NECK_ACCEL, but no faster than it can brake to a stop
		# in the angle left.
		var speed := minf(minf(_neck_speed[i]+NECK_ACCEL*delta,NECK_RATE),sqrt(2.0*NECK_ACCEL*angle))
		var step := minf(angle,speed*delta)
		if angle > 0.0001 and step < angle:
			now = was.slerp(now,step/angle)
			skeleton.set_bone_pose_rotation(bi,now)
		_neck_speed[i] = step/delta
		_neck_was[i] = now

## The chin's collider on the jaw while it clings (`on`), else out of the
## world's way.
func _place_chin(on: bool) -> void:
	if chin == null: return
	if not on or _chin_box.is_empty():
		if chin.collision_layer != 0: chin.collision_layer = 0
		return
	var i: int = _chin_box[0]
	var bone := skeleton.get_bone_global_pose(i)*skeleton.get_bone_global_rest(i).affine_inverse()
	var basis := (skeleton.global_transform.basis*bone.basis).orthonormalized()
	chin.global_transform = Transform3D(basis,_probe(_chin_box))
	chin.collision_layer = SOLID_LAYER

## The thumb's claw onto the turf just inside the lip (`seat`, world): the
## wrist's reach moved by the claw's miss, twice; then the claw's tip, its
## middle and the wrist kept over the top.
func _seat_thumb(n: String, wrist: Vector3, seat: Vector3, sk_inv: Transform3D) -> void:
	if not _thumb.has(n) or (_thumb[n][0] as Array).is_empty() or not is_inside_tree(): return
	var space := get_world_3d().direct_space_state
	var top := _turf_y(space,seat,TURF_LAYER)
	if not is_finite(top): return
	seat.y = top+0.05
	var chain := ["wing_arm."+n,"wing_fore."+n]
	for k in range(2):
		wrist += seat-_probe(_thumb[n][0])
		_reach(chain,"wing_hand."+n,sk_inv*wrist)
	for k in range(2):
		var sunk := 0.0
		for pr: Array in _thumb[n]:
			var p := _probe(pr)
			var g := _turf_y(space,p,TURF_LAYER)
			if is_finite(g): sunk = minf(sunk,p.y-g)
		if sunk >= -0.02: break
		wrist += Vector3.UP*(-sunk+0.05)
		_reach(chain,"wing_hand."+n,sk_inv*wrist)

## A little reaching IK (cyclic coordinate descent): turns `chain`'s bones
## (root first) so `end`'s origin comes to `target` (skeleton space).
func _reach(chain: Array, end: String, target: Vector3) -> void:
	if not _bone.has(end): return
	for k in range(4):
		for j in range(chain.size()-1,-1,-1):
			var b: String = chain[j]
			if not _bone.has(b): continue
			var bi: int = _bone[b]
			var bg := skeleton.get_bone_global_pose(bi)
			var e := skeleton.get_bone_global_pose(_bone[end]).origin
			var to_e := e-bg.origin
			var to_t := target-bg.origin
			if to_e.length() < 0.01 or to_t.length() < 0.01: continue
			var axis := to_e.cross(to_t)
			if axis.length() < 0.00001: continue
			var angle := minf(to_e.angle_to(to_t),0.7)
			var new_g := Basis(axis.normalized(),angle)*bg.basis
			var parent := skeleton.get_bone_parent(bi)
			var pg := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
			skeleton.set_bone_pose_rotation(bi,(pg.inverse()*new_g).get_rotation_quaternion())

## Lets go: it pushes off and drops back from the rim on a heavy beat,
## turning out, and the isle springs back.
func _let_go() -> void:
	state = "leaving"
	_place_chin(false)
	_rest_w = 0.0
	_snapshot(0.6)
	gale.release_isle()
	for i in range(14): gale.crumble(grip.rim,grip.out,grip.tangent,14.0)
	_jaw_goal = -1.0
	breath = ""
	_grab = {"t":0.0,"p0":pos,"yaw0":float(grip.yaw),"q0":global_transform.basis.get_rotation_quaternion()}
	flap_w = 1.0
	phase = 0.55
	_bout = true
	grip_beat.emit("let go")
	print("sky dragon: it lets go of %s" % str(grip.target.name))

const LEAVE := 3.2

## Round 8: off the rim, the body turns from its tipped cling (`q0`) to its
## flight over the first part of the let-go, not in one frame.
func _ease_off_rim() -> void:
	if state != "leaving" or not _grab.has("q0"): return
	var u := clampf(float(_grab.t)/(LEAVE*0.55),0.0,1.0)
	if u >= 1.0: return
	var q0: Quaternion = _grab.q0
	var q1 := global_transform.basis.get_rotation_quaternion()
	global_transform = Transform3D(Basis(q0.slerp(q1,smoothstep(0.0,1.0,u))),global_position)

func _leaving(delta: float) -> void:
	_grab.t = float(_grab.t)+delta
	var t := float(_grab.t)
	var u := clampf(t/LEAVE,0.0,1.0)
	var out: Vector3 = grip.out
	pos = (_grab.p0 as Vector3)+out*(6.0*t+2.2*t*t)+Vector3.DOWN*(2.6*t*t)
	yaw = lerp_angle(float(_grab.yaw0),float(_grab.yaw0)+PI*float(grip.side),smoothstep(0.15,0.95,u))
	var pitch := lerpf(CLING_PITCH*0.9,-0.25,smoothstep(0.0,0.85,u))
	gamma = (pitch-0.05)/0.75
	roll = 0.5*float(grip.side)*sin(PI*u)
	_free = smoothstep(0.5,1.0,u)
	# One heavy beat, then gliding off.
	flap_w = 1.0-smoothstep(0.7,1.0,u)
	phase = fposmod(phase+delta*0.42,1.0)
	mode = "cruise"
	if u >= 1.0:
		state = "roaming"
		yaw = atan2(-out.x,-out.z)
		# The flight's pitch where the let-go's ended (-0.25), no jump.
		gamma = -0.4
		speed = 26.0
		_free = 1.0
		route.clear()
		_leg_kinds.clear()
		if ride_repeat and not grip.is_empty():
			# --dragon-ride-repeat: round again and back onto the rim.
			_begin_grab()
			return
		if ride and targets.size() > 1:
			# --dragon-ride (round 8): off to another motif isle, then back
			# to yours.
			_target_i = _ride_next()
			_target_forced = true
			grip = {}
			_add_attack()
			return
		if not loop.is_empty():
			# A fixed loop (the vision greybox): back onto it, and the
			# pilot left be a while.
			grip = {}
			_grip_rest = GRIP_REST
			_rejoin_loop()
			return
		_add_circuit()
		_target_i = (_target_i+1)%maxi(targets.size(),1)
		_attack_in = _attack_every*_rng.randf_range(0.85,1.2)
		grip = {}

## The chest's swell toward `want`, eased (round 8: it carries the neck and
## head, so a jump in it popped the head by a metre or more).
var _chest := Vector3.ONE
func _set_chest(want: Vector3, delta: float) -> void:
	if not _bone.has("chest"): return
	_chest = _chest.lerp(want,1.0-exp(-delta*6.0))
	skeleton.set_bone_pose_scale(_bone["chest"],_chest)

## The body's turn eased toward the pose's (BODY_EASE 1/s).
func _ease_body(delta: float) -> void:
	var want := global_transform.basis.get_rotation_quaternion()
	if not _body_q_on:
		_body_q = want
		_body_q_on = true
		return
	_body_q = _body_q.slerp(want,1.0-exp(-delta*BODY_EASE)).normalized()
	global_transform = Transform3D(Basis(_body_q),global_position)

## Whether `t` is the ride's own isle (the pilot's).
func _is_ride_home(t: Dictionary) -> bool:
	return _ride_home < 0 or (_ride_home < targets.size() and targets[_ride_home] == t)

## The ride's next isle: after yours, the next of the others that stand
## (nearest first, round in turn); after another, yours.
func _ride_next() -> int:
	if _target_i != _ride_home: return _ride_home
	var home_at: Vector3 = targets[_ride_home].home
	var others: Array = []
	for i in range(targets.size()):
		if i == _ride_home or _record(targets[i]).is_empty() or not _has_room(targets[i]): continue
		others.append(i)
	if others.is_empty(): return _ride_home
	others.sort_custom(func(a: int, b: int) -> bool: return (targets[a].home as Vector3).distance_to(home_at) < (targets[b].home as Vector3).distance_to(home_at))
	var pick: int = others[_ride_away%others.size()]
	_ride_away += 1
	return pick

## Remembers every bone's turn now, to blend from it over `length` s.
func _snapshot(length: float) -> void:
	_blend_from.clear()
	for b: String in _bone:
		# Round 8: not the neck and head. Their snapshot holds this frame's
		# clearance, which would be laid on twice; they are rate-limited
		# from their last turn anyway (`_limit_neck`).
		if b == "head" or b.begins_with("neck."): continue
		var i: int = _bone[b]
		_blend_from[i] = skeleton.get_bone_pose_rotation(i)
	_blend_t = 0.0
	_blend_len = length

func _blend(delta: float) -> void:
	if _blend_from.is_empty(): return
	_blend_t += delta
	var w := smoothstep(0.0,1.0,_blend_t/maxf(_blend_len,0.01))
	if w >= 1.0:
		_blend_from.clear()
		return
	for i: int in _blend_from:
		var now := skeleton.get_bone_pose_rotation(i)
		skeleton.set_bone_pose_rotation(i,(_blend_from[i] as Quaternion).slerp(now,w))

## The blow on a pilot on the isle. Round 10: the air on him is the breath
## ribbons' where they are (scripts/dragon_breath.gd `air_near`: within
## PILOT_REACH m to the side and PILOT_RISE m up or down of his chest), so a
## ground ribbon tearing across the turf through him is what knocks him into
## a tumble (once a blast, while the blow is strong), a weaker or glancing
## one pushes him along; one passing over a wall he crouches behind, or
## arcing high overhead, misses him.
const PILOT_REACH := 2.0
const PILOT_RISE := 3.0
## Where on him the air is read (m over his feet: his chest).
const PILOT_CHEST := 1.3
const KNOCK_AIR := 11.0
const PUSH_AIR := 3.0
## Logged: knocks and the frames he was pushed this hold.
var knocks := 0
var pushed := 0
var air_most := 0.0
func _blow_on_pilot(delta: float, mouth: Vector3) -> void:
	if walker == null or not on_foot or gale == null: return
	if walker.has_method("recovering") and walker.recovering(): return
	var mid: Vector3 = (walker.get("feet") as Vector3)+Vector3.UP*PILOT_CHEST
	var air: Vector3 = gale.breath.air_near(mid,PILOT_REACH,PILOT_RISE)
	var flat := Vector2(air.x,air.z)
	var hard := flat.length()
	air_most = maxf(air_most,hard)
	if hard < PUSH_AIR: return
	var away := flat/hard
	var dist := Vector2(mid.x-mouth.x,mid.z-mouth.z).length()
	if hard >= KNOCK_AIR and float(gale.gust_env) > 0.3 and not _knocked:
		var stuns := _stuns_pilot()
		walker.knock(walker.knock_velocity(away,lerpf(KNOCK_OUT.x,KNOCK_OUT.y,clampf(dist/REACH,0.0,1.0))*clampf(hard/20.0,0.75,1.2),KNOCK_UP),self,BLOW_STUN_DOWN)
		_knocked = true
		knocks += 1
		grip_beat.emit("blown")
		print("sky dragon: a ground gust knocks the pilot, %.1f m from the mouth, air %.1f m/s (%s)" % [dist,hard,"a hard hit stun, down %.1f s" % BLOW_STUN_DOWN if stuns else "within his restun gap: thrown, not stunned again"])
		return
	if slide.is_valid() and bool(walker.get("grounded")):
		var push := away*PUSH*clampf(hard/14.0,0.0,1.4)*delta
		var feet: Vector3 = walker.get("feet")
		var moved: Vector3 = slide.call(feet,push)
		walker.set("feet",Vector3(moved.x,feet.y,moved.z))
		pushed += 1

## The isle under the pilot (round 5): standing on it while it sags, holds
## and snaps, he is carried with it (PilotMotor.carry, as a moving body
## carries him); as it snaps back he is flung off it into a tumble the
## moment it slows harder than he falls, at its speed where he stands, so
## hardest by the gripped rim. And the snap's jolt: stone, dust and leaves
## jump loose.
func _ride_isle(delta: float) -> void:
	if gale.snapped and not grip.is_empty(): gale.jolt(_isle_xf()*(grip.rim as Vector3),grip.out,grip.tangent,-gale.sag_v)
	if walker == null or not on_foot or gale.isle == null or delta <= 0.0: return
	if gale.moved.is_equal_approx(Transform3D.IDENTITY):
		_ride_vy = 0.0
		return
	var feet: Vector3 = walker.get("feet")
	var vel: Vector3 = walker.get("velocity")
	if not gale.stands_on(feet) or (not bool(walker.get("grounded")) and vel.y > 0.5):
		_ride_vy = 0.0
		return
	var moved_by: Transform3D = gale.moved
	var now := moved_by*feet
	walker.carry(moved_by,0.0)
	var v := (now-feet)/delta
	var accel := (v.y-_ride_vy)/delta
	_ride_vy = v.y
	if gale.phase != "snap" or v.y < 3.0 or accel > -float(walker.get("gravity")): return
	var up := minf(v.y*LAUNCH_GAIN,LAUNCH_MOST)
	var inward := -(grip.out as Vector3)*up*LAUNCH_IN if not grip.is_empty() else Vector3.ZERO
	var stuns := _stuns_pilot()
	walker.knock(Vector3(v.x+inward.x,up,v.z+inward.z),self,LAUNCH_STUN_DOWN)
	_ride_vy = 0.0
	launched += 1
	grip_beat.emit("thrown")
	var rim_at: Vector3 = grip.rim if not grip.is_empty() else feet
	print("sky dragon: the isle springs back and flings the pilot up at %.1f m/s, %.1f m from the rim it held (%s)" % [up,Vector2(feet.x-rim_at.x,feet.z-rim_at.z).length(),"a hard throw stun, down %.1f s where he lands" % LAUNCH_STUN_DOWN if stuns else "within his restun gap: thrown, not stunned again"])

## Whether his knock now would stun the pilot (PilotMotor `stunnable`: not
## within his restun gap or past the chain cap), for the log.
func _stuns_pilot() -> bool:
	return walker != null and walker.has_method("stunnable") and bool(walker.stunnable(self))

## The slam's stagger (round 2 of the grip): a pilot standing on the isle
## within SLAM_STAGGER_R (scaled) of the rim it slams onto is knocked a
## little way in from it, a light stun (SLAM_STUN_DOWN).
var staggered := 0
func _stagger_pilot() -> void:
	if walker == null or not on_foot or gale == null or gale.isle == null or grip.is_empty(): return
	if walker.has_method("recovering") and walker.recovering(): return
	var feet: Vector3 = walker.get("feet")
	if not gale.stands_on(feet,1.5): return
	var rim: Vector3 = grip.rim
	var dist := Vector2(feet.x-rim.x,feet.z-rim.z).length()
	if dist > SLAM_STAGGER_R*_k(): return
	var out: Vector3 = grip.out
	var tall := DragonAirBlast.walker_tall()
	var stuns := _stuns_pilot()
	walker.knock(walker.knock_velocity(Vector2(-out.x,-out.z),SLAM_KNOCK_OUT*tall,SLAM_KNOCK_UP*tall),self,SLAM_STUN_DOWN)
	staggered += 1
	grip_beat.emit("staggered")
	print("sky dragon: the slam staggers the pilot %.1f m from the rim, knocked in from it (%s)" % [dist,"a light stun" if stuns else "within his restun gap: shoved, not stunned"])

## Round 9's check (--dragon-walk-check, headless): the stick pressed
## forward, then back, 1.4 s each, so the pilot runs to and fro: on the
## flat before the first grip, and through the hold once it has eased back
## to its walkable tilt (he stands still for the slam, the steep moment and
## the last pull, to be flung). Every 0.25 s it prints his pace, the slope
## under him, the isle's tip and his water; once per hold, each of the
## isle's pools' water as the pilot's ground reads it against the posed
## surface.
var _walk_check := false
var _walk_t := 0.0
var _walk_log := 0.0
var _walk_pools := false
func _walking_check(delta: float) -> void:
	if not _walk_check or walker == null: return
	var flat: bool = gale.phase == "" and launched == 0 and state != "grabbing" and _clock > 1.0
	var held: bool = state == "clinging" and gale.phase == "held" and gale.eased() and breath != "pull"
	var go: bool = on_foot and (flat or held)
	if not go:
		Input.action_release(&"move_forward")
		Input.action_release(&"move_back")
		if gale.phase != "held": _walk_pools = false
		# Standing through the slam's steep moment and the last pull.
		if on_foot and gale.phase in ["held","snap"]:
			_walk_log += delta
			if _walk_log >= 0.2:
				_walk_log = 0.0
				print("sky dragon walk: t %.2f %s, isle tipped %.1f°, the rim sags %.2f m, pilot %s %.2f m/s on %.1f°, grounded %s, swimming %s" % [_clock,"pull" if breath == "pull" else str(gale.phase),rad_to_deg(gale.tip()),gale.sag,str(walker.get("move")),walker.speed(),walker.steepness(),str(walker.get("grounded")),str(walker.get("swimming"))])
		return
	_walk_t += delta
	var fwd := fmod(_walk_t,2.8) < 1.4
	if fwd:
		Input.action_release(&"move_back")
		Input.action_press(&"move_forward")
	else:
		Input.action_release(&"move_forward")
		Input.action_press(&"move_back")
	_walk_log += delta
	if _walk_log >= 0.25:
		_walk_log = 0.0
		var f: Vector3 = walker.get("feet")
		print("sky dragon walk: t %.2f %s, isle tipped %.1f°, pilot %s %.2f m/s on %.1f°, grounded %s, swimming %s wade %.2f, feet y %.2f" % [_clock,"flat" if flat else "held",rad_to_deg(gale.tip()),str(walker.get("move")),walker.speed(),walker.steepness(),str(walker.get("grounded")),str(walker.get("swimming")),float(walker.get("wade")),f.y])
	if held and not _walk_pools:
		_walk_pools = true
		var ground: Object = slide.get_object() if slide.is_valid() else null
		var motif: Variant = gale.isle.get("motif")
		if ground == null or motif == null or not ground.has_method("surface"): return
		var off: Vector3 = gale.isle.get("offset")
		for pool: Dictionary in motif.pools():
			var c: Vector2 = (pool.rect as Rect2).get_center()
			var rest := Vector3(c.x+off.x,float(pool.top)+off.y,c.y+off.z)
			var posed := _isle_xf()*rest
			var at := Vector2(posed.x,posed.z)
			print("sky dragon walk: pool at (%.1f, %.1f, %.1f) at rest; tipped %.1f°: its water stands at y %.2f, the pilot's ground reads its surface at %.2f (its rest top %.2f), the bed at %.2f, %.2f m deep" % [rest.x,rest.y,rest.z,rad_to_deg(gale.tip()),posed.y,float(ground.surface(at)),rest.y,float(ground.ground(at)),float(ground.depth(at))])

## The snout's motion against the body (round 8's log): the most speed and
## the most change of speed since the last line, while on a rim.
func _measure_tip(delta: float) -> void:
	if not (state in ["grabbing","clinging","leaving"]) or not _bone.has("jaw.tip"):
		_tip_was = Vector3.INF
		return
	var tip := skeleton.global_transform.basis*skeleton.get_bone_global_pose(_bone["jaw.tip"]).origin
	if _tip_was != Vector3.INF:
		var v := (tip-_tip_was)/delta
		tip_speed = maxf(tip_speed,v.length())
		tip_jerk = maxf(tip_jerk,(v-_tip_v).length()/delta)
		_tip_v = v
	_tip_was = tip

## The treasure taken from its tongue: a roar, and it lets go.
func _touch_treasure() -> void:
	if taken or walker == null or not on_foot or treasure == null: return
	var mid: Vector3 = (walker.get("feet") as Vector3)+Vector3.UP*0.6
	if mid.distance_to(treasure.global_position) > TAKE_R: return
	taken = true
	treasure.visible = false
	print("sky dragon: the treasure is taken; it roars and lets go")
	yielded.emit()
	_let_go()
	_roar_t = 0.0

# --- The watch camera ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Asleep it takes no keys; awake (its wake's circuit) V still watches it.
	if roost != null and not awake(): return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_G and state == "clinging":
		_say("It lets go")
		_let_go()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_V:
		var order := ["","chase","orbit","look"]
		watch = order[(order.find(watch)+1)%order.size()]
		if watch == "" and _fov > 0.0 and camera != null: camera.fov = _fov
		_watch_fresh = true
		_say("Dragon camera: %s" % (watch if watch != "" else "off"))
		get_viewport().set_input_as_handled()

func _say(text: String) -> void:
	if _toast == null:
		var layer := CanvasLayer.new()
		layer.layer = 7
		add_child(layer)
		_toast = Label.new()
		_toast.position = Vector2(24,24)
		_toast.add_theme_font_size_override("font_size",20)
		_toast.add_theme_color_override("font_shadow_color",Color(0,0,0,0.6))
		layer.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast,"modulate:a",0.0,0.8)

## The camera on the dragon while watching: behind and above it (chase), a
## slow orbit round it, or looking at it from where the camera was.
func _watch_camera(delta: float) -> void:
	if watch == "" or camera == null or state == "waiting": return
	var at := global_position
	var fwd := Vector3(-sin(yaw),0.0,-cos(yaw))
	var eye := Vector3.ZERO
	var aim := at
	match watch:
		"chase":
			eye = at-fwd*100.0+Vector3.UP*28.0
			aim = at+fwd*25.0+Vector3.UP*2.0
		"orbit":
			_orbit += delta*0.18
			var a := _orbit
			if _orbit_fixed != INF: a = -yaw-PI*0.5+_orbit_fixed
			eye = at+Vector3(cos(a),0.0,sin(a))*_orbit_far+Vector3.UP*_orbit_up
			aim = at
		"look":
			if _watch_fresh: _watch_from = camera.global_position
			eye = _watch_from
			aim = at
		_: return
	# On a rim: framed on the isle and the dragon on it, out to the side so
	# the neck over the turf, the hanging tail and the blast across all show.
	var on_rim := not grip.is_empty() and (state == "clinging" or (state == "grabbing" and float(_grab.get("t",0.0)) > GRAB*0.4))
	if on_rim:
		var rim: Vector3 = _isle_xf()*(grip.rim as Vector3)
		var out: Vector3 = grip.out
		var tangent: Vector3 = grip.tangent
		match watch:
			"chase":
				eye = rim+out*72.0+tangent*float(grip.side)*62.0+Vector3.UP*26.0
				aim = rim+Vector3.UP*4.0-out*6.0
			"orbit":
				var a := _orbit
				if _orbit_fixed != INF: a = atan2(out.z,out.x)+_orbit_fixed
				eye = rim+Vector3(cos(a),0.0,sin(a))*_orbit_far+Vector3.UP*_orbit_up
				aim = rim+Vector3.UP*2.0
			"look":
				aim = rim+Vector3.UP*8.0
	if _watch_fresh:
		if _fov < 0.0: _fov = camera.fov
		_watch_eye = eye
		_watch_look = aim
		_watch_fresh = false
	var k := 1.0-exp(-delta*(2.5 if watch == "chase" else 4.0))
	_watch_eye = _watch_eye.lerp(eye,k)
	_watch_look = _watch_look.lerp(aim,1.0-exp(-delta*6.0))
	if watch == "look" or _orbit_fixed != INF: _watch_eye = eye
	camera.global_position = _watch_eye
	camera.look_at(_watch_look,Vector3.UP)
	camera.fov = 55.0 if watch != "look" else 40.0
