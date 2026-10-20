extends Node3D
## The wanderer's own rope and hook (docs/design/rope/spec-rope.md), on the
## rope study's room (studies/rope_study.gd: its `holds` and `pieces`).
##
## Throw: `walk_throw` held (LMB / T / pad RT) on the ground, coiled: he
## whirls the hook at his side and keeps moving under the stick (walk, run,
## off an edge). A reticle shows where it goes, picked from where the camera
## looks (mouse / right stick, turned faster while whirling: AIM_MOUSE,
## AIM_STICK): a swing point or anchor post near the look line (AIM_CONE),
## else the first lip of a top above him along it. Gold: a hold there (a
## solid lip, a post, a swing point). Amber: a crumbly lip (it may skitter
## off). Red: it won't catch (a smooth top, the floor, the way blocked, out
## of reach); thrown anyway, it misses. The camera eases out while he
## whirls (WHIRL_FAR). Released, the hook flies the arc shown (flatter at a
## run, RUN_FLAT), trailing the rope as he goes on. On a hold it catches and
## is set at once (state "seated", it holds his weight): there is no tug. A
## crumbly lip may skitter at the catch (POOR_BAD: grit, it slides off and
## falls); with no hold it slides off the lip and falls; a blocked arc
## knocks it down. A miss: F reels it in, or hold the throw again.
##
## Over a swing point (a hook line) the set rope is in his hand at once
## (`swing_hold`): run off the edge (or Space) into the swing; caught with
## him already in the air, he swings straight away.
##
## Climb: Jump by the hanging rope of a set hook takes hold (the motor's
## rider, scripts/pilot_motor.gd `mount`, held as the swing rope's "swing"
## hang). Stick toward the wall: hand over hand, a pull at a time (the body
## hauled up on the top hand, then the low hand reaching past it), slow;
## let go of the stick and he hangs. Stick away: down hand under hand;
## crouch (Shift / C): slides down fast; Jump: lets go. At the top he is
## handed to the motor's own ledge hang and climb (the haul over the lip,
## slowed to HAUL_TIME). A set hook never gives.
##
## Rappel: E (pad B) by an anchor post on a top, the rope coiled, ties it
## round the post's foot and throws it over the drop beyond the post (the
## way he looks past it), pulled tight (`fixed`; the "tug" state is this
## tie's yank). Jump at an edge a
## seated rope runs over, facing out: the motor's own catch and lower take
## him over to a hang, then he's on the rope rappelling: leaned back, feet
## on the wall (leg IK), the lead hand up the rope, the brake hand at his
## hip. Stick away from the wall: a hop down (crouch in, push out, swing
## back, land), chained while held, finished when let go; crouch slides;
## stick toward the wall: climbing as from below; Jump lets go. At the
## floor he steps off; the rope stays fixed, so Jump by it climbs back up.
##
## Reel: `walk_reel` (F / pad down) draws the rope in. A caught hook is
## flicked free off its lip first, falls, then is dragged in along the
## ground till it's coiled at his side. From below a fixed rope, it's
## pulled down: it runs round the post and over the edge and falls. From a
## top, it's pulled up hand over hand, the hanging end rising (state
## "pull_up"), then coiled.
##
## The rope is a line of segments from his hand to the hook, sagging by its
## slack (a parabola; paid out length minus the span) and lying on what's
## under it. Kept apart from the motor and the figure's clips, so a bag or
## a load can later ride on it (spec's out-of-scope note).
const CarryHost = preload("res://scripts/carry/carry_host.gd")
const Pad = preload("res://scripts/pad.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## The rope's full length (m, times size); a throw reaches this far.
const ROPE_LEN := 14.0
## The reticle's reach across from his feet (m, times size), its least, and
## where a throw with nothing on the look line comes down (of the reach).
const AIM_REACH := 10.0
const AIM_MIN := 1.2
const AIM_START := 0.45
## Picking the target from the camera's look (docs/design/heist-level/
## rope-throw-handoff.md): a swing point or post within AIM_CONE (deg) of
## the look line (or AIM_NEAR m across it, near him) wins over a lip on it
## when within AIM_PREFER of the cone; the line is walked for a lip in
## AIM_STEP (m) steps. While whirling the camera turns faster: the mouse
## AIM_MOUSE times its own, the right stick AIM_STICK rad/s more.
const AIM_CONE := 16.0
const AIM_NEAR := 1.2
const AIM_PREFER := 0.6
const AIM_STEP := 0.4
const AIM_MOUSE := 1.6
const AIM_STICK := 2.4
## The mouse's own turn (rad a pixel: character_study.gd LOOK).
const MOUSE_LOOK := 0.0025
## A throw at a run flies flatter: its rise times RUN_FLAT at full run
## (PilotMotor.RUN), eased from a stand.
const RUN_FLAT := 0.45
## While whirling and the hook's flight, the camera eases out to WHIRL_FAR
## times its reach and widens WHIRL_WIDE degrees, at WHIRL_EASE (1/s), back
## in after (a host with its own pull, the rope study's `_cam_pull`, keeps
## its own).
const WHIRL_FAR := 1.4
const WHIRL_WIDE := 7.0
const WHIRL_EASE := 3.0
## ...and its tilt eased up to at least WHIRL_POLAR (rad from straight
## down: lower and more level, the face ahead and the gap in view).
const WHIRL_POLAR := PI*0.5-0.3
## A top counts as above him (a lip to hook) this high over his feet (m).
const ABOVE := 1.2
## The reticle snaps to an anchor post within this (m, flat).
const POST_SNAP := 1.6
## The hook lands this far in past the lip and is dragged back to it.
const LAND_IN := 0.7
## The hook wraps a post this far under its top.
const POST_WRAP := 0.25
## Hook lines (scripts/rope/hook_line.gd: the swing study's beams carry
## them; caught, hold "beam"): the reticle snaps to one over
## his head within BEAM_SNAP (m, flat) of its line, kept BEAM_END in from
## its ends; one more than BEAM_HIGH over his feet is too high to throw
## over. Wrapped, the hook hangs BEAM_HANG under the beam's far side.
const BEAM_SNAP := 2.5
const BEAM_END := 0.5
const BEAM_HIGH := 12.0
const BEAM_HANG := 0.2
## The wrap round a beam (s): over its top and down the far side.
const WRAP_TIME := 0.22
## The throw's arc: its top over the higher end, plus this a metre across.
const AIM_RISE := 1.0
const AIM_RISE_M := 0.08
## The hook falls under this many times gravity; thrown, it flies its arc
## FLY_PACE times as fast (the same arc, a quick throw on the move).
const HOOK_G := 1.8
const FLY_PACE := 1.9
const ARC_DOTS := 22
## The whirl while aiming: its radius (m) and turns a second.
const WHIRL_R := 0.55
const WHIRL_RATE := 3.0
## Dragged back from where it landed to the lip (s); sliding off a smooth
## top as long.
const DRAG_TIME := 0.18
## Falling: a bounce off a wall keeps this much.
const BOUNCE := 0.3
## Reeling in: its pace along the ground (m/s) and the flick off a lip.
const REEL_SPEED := 6.0
const FLICK := Vector2(1.6,1.4)
## Reeled off a beam: flicked over it toward him, then yanked through the
## air to his hand (m/s², times size), in from anywhere he stands.
const YANK := 45.0
## How fast (1/s) its way turns toward his hand.
const YANK_TURN := 8.0
## The tie at a post (E): reaching up the rope, the yank back, the hold
## before it settles (s). A crumbly lip's chance the hook skitters off it at
## the catch; the slip back over the lip (s).
const TUG_REACH := 0.2
const TUG_YANK := 0.12
const TUG_HOLD := 0.35
const POOR_BAD := 0.5
const SLIP_TIME := 0.3
## Grit off a crumbly lip: bits, their life (s).
const GRIT := 7
const GRIT_LIFE := 1.4
const GRIT_COLOUR := Color(0.78,0.66,0.46)
## Coiled again within this of his feet (m).
const COILED := 0.7
## The rope's look.
const SEGS := 28
const ROPE_R := 0.022
const ROPE := Color("b59a6a")
const HOOK := Color("3a3d42")
const AIM_OK := Color(1.0,0.92,0.55)
const AIM_BAD := Color(1.0,0.3,0.25)
const AIM_POOR := Color(1.0,0.62,0.22)
const LINE_TIME := 2.5
## The climb: within this of the hanging rope (m, flat) Jump takes hold; the
## rope hangs this far out from the edge; a pull's rise (m, the gap between
## the hands too) and time (s: the haul up, then the low hand's reach, at
## REACH_AT of it); down hand under hand and the slide (m/s); the haul over
## the lip (s, the motor's climb slowed); the hands' spread on the rope (m).
const GRAB_REACH := 1.2
const ROPE_OFF := 0.04
const PULL := 0.4
const PULL_T := 0.42
const REACH_AT := 0.55
const DOWN_SPEED := 1.1
const SLIDE_SPEED := 3.5
const HAUL_TIME := 0.6
const HAND_SPREAD := 0.035
## Climbing, the hands sit this far (m) over the hang's grip, reaching up
## the rope; the feet press the wall this share of his leg over his feet
## (IK weight CLIMB_FEET).
const REACH_UP := 0.3
const FOOT_UP := 0.42
const CLIMB_FEET := 0.85
## On the rope he hangs this much further off the wall than a ledge hang
## (arms out to the rope, so they read), drawn in to the ledge's over the
## last BODY_IN under the top for the haul.
const BODY_OFF := 0.3
const BODY_IN := 0.6
## The rappel: E (the tug) by an anchor post on a top, rope coiled, fixes
## it there (within FIX_REACH, m, flat), tied TIE_UP up the post; Jump at
## the edge (within LOWER_REACH back from it, facing out) lowers him over.
## On the wall: leaning back LEAN (deg), hips out this share of his leg's
## length, feet planted FOOT_DOWN of it under the hips; eased in over
## STANCE_IN (s). A hop: HOP_T (s), down HOP_DROP (m), swung out HOP_OUT (m)
## at its middle; crouched in (HOP_CROUCH of it), flown, landed (from
## HOP_LAND). Pulled up from a top at PULL_UP (m/s).
const FIX_REACH := 1.6
const TIE_UP := 0.3
const LOWER_REACH := 1.6
const LEAN := 44.0
const HIP_OUT := 0.78
const FOOT_DOWN := 0.42
const STANCE_IN := 0.45
const HOP_T := 0.85
const HOP_DROP := 1.5
const HOP_OUT := 0.75
const HOP_CROUCH := 0.22
const HOP_LAND := 0.82
const PULL_UP := 3.0
## The rappel's descent, held stick back: from RAP_SPEED.x to .y (m/s) over
## RAP_RAMP (s) held; stops over RAP_STOP (s) once let go. The feet walk
## the wall a step each RAP_STRIDE of his leg, lifting RAP_LIFT of it; over
## RAP_SKIM (m/s) they skim, the steps fading out. Leaving it to climb, the
## stance eases out over UNRAP (s).
const RAP_SPEED := Vector2(1.1,3.4)
const RAP_RAMP := 1.4
const RAP_STOP := 0.22
const RAP_STRIDE := 0.9
const RAP_LIFT := 0.4
const RAP_SKIM := 2.8
const UNRAP := 0.3
## The swing (a rope over a beam, the swing study): Space by it takes hold
## (the rope in his hand, or within GRAB_REACH of a hanging one). Walking
## with it he takes in the slack (his grip as far from the beam's top as
## his hands, at least SWING_MIN, at most the rope); the moment he leaves
## the ground (off an edge, or Space: his jump) he's a pendulum under the
## beam (scripts/interactables/
## swing_rope.gd's: its pump, release boost and pop). Crouch on the ground
## lets go of it. A body hitting a face keeps SWING_BOUNCE of its pace
## along it; feet meeting the floor put him down still holding it, not
## swung again for SWING_COOL s. Let go, the body eases upright over UPRIGHT s.
const SWING_MIN := 1.4
## The rope over the beam and down to the hook (m, times size): what's
## left of ROPE_LEN to swing on.
const SWING_OVER := 1.0
const SWING_BOUNCE := 0.25
const SWING_COOL := 0.3
const UPRIGHT := 0.3
## Swinging, up or down the rope (m/s, times size): E/pad B climbs (the
## swing shorter, faster and tighter), F/D-pad down slides (longer, further).
## The pace scales by old/new length (his momentum round the beam kept).
## The hands go over each other SWING_HAND m apart as he climbs.
const SWING_UP := 3.5
const SWING_DOWN := 5.0
const SWING_HAND := 0.14
## Let go by Jump, the swing's own release: the boost along the swing for a
## perfect timing (m/s) and the pop up, in place of the swing rope's
## (SwingRope t_boost 6, t_pop 1.5: off a 7 m beam that carried him 10 m
## past a 9 m gap's far edge).
const SWING_BOOST := 2.0
const SWING_POP := 1.5
## The live rope (docs/design/heist-level/live-rope-handoff.md): on a hooked
## or fixed rope down a face (climbing or rappelling), his grip is a
## pendulum hung from where the rope goes over the edge, kept off the wall
## (the face stops it; a rappel's feet keep him their stance off it). Its
## gravity LIVE_G (m/s²), its damping a second in the air LIVE_DAMP and
## with him on the face LIVE_RUB (feet running a rappel: none), held under
## LIVE_MOST (rad) from the plumb. The stick across the face pumps it
## (LIVE_PUMP hanging, RUN_PUMP rappelling, his feet running the face: m/s²,
## only the way it already goes, as the swing's); E kicks off the wall
## (KICK m/s out, hanging; HOP_KICK the rappel's hop), half the pace he
## came back in with added (KICK_KEEP) when it lands as he meets the wall,
## so kicks timed to the wall build it. A face met bounces WALL_BOUNCE of
## the pace into it. Each pull throws him PULL_OUT out and PULL_SIDE to
## the pulling hand's side (m/s), heaved LURCH over the pull's rise (m) and
## settling back as the other hand reaches. Let go (Jump), he keeps the
## grip's pace, RELEASE more along it rising. A heavier bag (to the climb
## stop, LootBag CLIMB_STOP) swings slower and wider: gravity HEAVY_G less,
## damping HEAVY_DAMP less, the lurch smaller and a HEAVY_SAG drop after
## each pull. Left hanging, the rope sways on and settles (LIVE_FREE_DAMP).
const LIVE_G := 18.0
const LIVE_DAMP := 0.18
const LIVE_RUB := 1.6
const LIVE_MOST := 1.05
const LIVE_PUMP := 5.0
const RUN_PUMP := 9.0
const KICK := 2.6
const HOP_KICK := 3.2
const KICK_KEEP := 0.5
const WALL_BOUNCE := 0.12
const PULL_OUT := 0.3
const PULL_SIDE := 0.3
const LURCH := 0.09
const RELEASE := 1.2
const HEAVY_G := 0.4
const HEAVY_DAMP := 0.6
const HEAVY_SAG := 0.07
const LIVE_FREE_DAMP := 1.6
## The rappel's hop now flies the pendulum: the rope runs HOP_FALL m/s
## (times size) through the brake hand while he's off the wall, HOP_DROP at
## most a hop.
const HOP_FALL := 2.2
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const HookLine = preload("res://scripts/rope/hook_line.gd")
const LootBag = preload("res://scripts/carry/loot_bag.gd")

var study: Node3D
## The swing: holding a beam's rope on the ground (`swing_hold`, `swing_len`
## from the beam's top to his hands), on the pendulum (`swinging`), the rope
## left hanging off the beam after (`swing_left`); counts.
var swing_hold := false
var swinging := false
var swing_left := false
var swing_len := 0.0
var swings := 0
var swing_releases := 0
var scrapes := 0
var _pend: SwingRope
var _swing_cool := 0.0
var _climb_phase := 0.0
var _climb_k := 0.0
var swing_climbed := 0.0
var _tilt_left := 0.0
var _tilt := Basis.IDENTITY
## "coiled" (at his side), "aim" (whirling), "fly", "drag" (pulled back to
## the lip), "seated" (set: it holds him), "tug" (tying at a post), "slip"
## (skittering off a crumbly lip), "slide" (off a smooth top), "fall",
## "down", "reel", "pull_up" (hauled up from a top). "caught" is no longer
## entered (every catch is set).
var state := "coiled"
## Where the hook is, and where it sits once caught.
var hook_at := Vector3.ZERO
var lip := Vector3.INF
## The lip's outward way (flat, toward where the rope hangs).
var lip_out := Vector3.ZERO
## The hold it caught on ("solid", "poor", "anchor", "beam"; "" none) and its piece.
var hold := ""
var piece := ""
## Set (a seated hook holds his weight): every catch is.
var tested := false
## The last catch on a crumbly lip skittered off.
var bad := false
## Drivers: -1 rolls a crumbly lip's skitter at the catch, 0 never, 1 always.
var force_bad := -1
## Over a beam: its middle (the bar's axis under the lip) and half its
## thickness; the far side's way is -lip_out.
var beam_mid := Vector3.INF
var beam_half := 0.0
var aim_mid := Vector3.INF
var aim_half := 0.0
## The aim: the reticle (the target the arc ends at), its lip, hold, piece,
## whether it'll catch and why not, the arc.
var aim_at := Vector3.INF
var aim_lip := Vector3.INF
var aim_out := Vector3.ZERO
var aim_hold := ""
var aim_piece := ""
var aim_ok := false
var aim_why := ""
var aim_arc: PackedVector3Array = []
## The rope paid out (m).
var paid := 0.0
## Tallies (drivers, notes).
var throws := 0
var catches := 0
var misses := 0
var reels := 0
var tugs := 0
var seats := 0
var slips := 0
## Drivers: aim as though the button were held (`release` lets go), and a
## world point the camera is kept turned toward while aiming (INF none).
var hold_aim := false
var aim_point := Vector3.INF
## The camera's pull while whirling (0 to 1), and the arc's rise this throw.
var _cam_k := 0.0
var _polar_lift := 0.0
var _polar_room := 0.0
var _rise_k := 1.0
## The edge the rope runs over (a lip's own; for a post, the top's edge on
## the side it hangs) and its outward way (flat): where it hangs to climb.
var edge := Vector3.INF
var edge_out := Vector3.ZERO
## On the rope (the motor's rider), and hauling over the lip after.
var climber := false
var hauling := false
## The climb's pace (1 bare; a load would slow it: the spec's later bag).
var climb_pace := 1.0
## Tallies: holds taken, hauls over (`gave` stays 0: a set hook never gives).
var climbs := 0
var hauls := 0
var gave := 0
## Fixed round an anchor post from its top (pulled down from below, not
## flicked); being lowered over the edge (the motor's catch and lower);
## on the rope rappelling (feet on the wall), not climbing.
var fixed := false
var lowering := false
var rappel := false
## Tallies: rappels begun, hops down, ropes pulled down from below.
var rappels := 0
var hops := 0
var pulled_down := 0
## Where the rappel's hands hold the rope (world): the lead hand up the
## rope, the brake hand at his hip; the rope runs through both.
var guide_at := Vector3.INF
var brake_at := Vector3.INF

var _rap_v := 0.0
var _rap_held := 0.0
var _step := 0.0
var _hop_t := -1.0
var _hop_from := 0.0
var _hop_drop := 0.0
## The live rope: the grip's spot off the anchor (`_lp`, world, `_ll` long)
## and its pace; the wall's least out at the grip; the body's sway off its
## still spot this frame and the rope's tilt; his feet's height on the rope
## as the climb has it (the sway's lift left out); a kick asked for
## (seconds left of its buffer). Free (no one on it), its end swings on.
var _lp := Vector3.ZERO
var _lv := Vector3.ZERO
var _ll := 0.0
var _lo := 0.0
var sway := Vector3.ZERO
var _sway_tilt := Basis.IDENTITY
var _base_y := 0.0
var _kick_buf := 0.0
var _live_free := false
var _hop_fly := false
## Tallies and peaks (drivers): kicks off the wall, the widest sway across
## and out this hold (m), the last let-go's pace.
var kicks := 0
var sway_peak := Vector2.ZERO
var let_go_v := Vector3.ZERO
var too_heavy := 0
var _stance_k := 0.0
var _up_len := 0.0

var _jump_was := false
var _on_t := 0.0
## The hands' heights on the rope (world y): [top, low], and which bone side
## each is (1 right, -1 left).
var _hand_y := [0.0,0.0]
var _hand_side := [1.0,-1.0]
## A pull under way (0 to 1; -1 none), from feet at this height.
var _pull_t := -1.0
var _pull_from := 0.0
var _reach_from := 0.0
var _climb_time_was := 0.0

var _aim := Vector2.ZERO
var _throw_was := false
var _reel_was := false
var _tug_was := false
var _tug_t := 0.0
var _tug_paid := 0.0
var _tug_said := false
var _grit: Array[Dictionary] = []
var _grit_mat: StandardMaterial3D
var _click: AudioStreamPlayer3D
var _vel := Vector3.ZERO
var _from := Vector3.ZERO
var _fly_t := 0.0
var _fly_all := 0.0
var _t := 0.0
var _whirl := 0.0
var _slide_from := Vector3.ZERO
var _reel_after := false
var _yank := false
## Thrown with a rope left on a hook line: aimed once it's back in.
var _aim_after := false
## The line says a swing hint ("Holding the rope", "Swinging"): cleared once
## he's down on his feet again.
var _swing_said := false
var _hook: Node3D
var _rope: MultiMeshInstance3D
var _reticle: MeshInstance3D
var _reticle_mat: StandardMaterial3D
var _dots: MultiMeshInstance3D
var _dots_mat: StandardMaterial3D
var _line: Label3D
var _line_t := -1.0
var _clink: AudioStreamPlayer3D

func setup(host: Node3D) -> void:
	study = host
	name = "ClimbRope"
	process_priority = 100
	_hook = _hook_figure()
	add_child(_hook)
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = ROPE
	rope_mat.roughness = 0.95
	var seg := CylinderMesh.new()
	seg.top_radius = ROPE_R
	seg.bottom_radius = ROPE_R
	seg.height = 1.0
	seg.radial_segments = 6
	seg.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = seg
	mm.instance_count = SEGS
	_rope = MultiMeshInstance3D.new()
	_rope.name = "Rope"
	_rope.top_level = true
	_rope.multimesh = mm
	_rope.material_override = rope_mat
	add_child(_rope)
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reticle_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_reticle = MeshInstance3D.new()
	_reticle.name = "HookReticle"
	_reticle.top_level = true
	var ring := TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	_reticle.mesh = ring
	_reticle.material_override = _reticle_mat
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.visible = false
	add_child(_reticle)
	_dots_mat = _reticle_mat.duplicate()
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	dot.radial_segments = 8
	dot.rings = 4
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_3D
	dm.mesh = dot
	dm.instance_count = ARC_DOTS+1
	_dots = MultiMeshInstance3D.new()
	_dots.name = "HookArc"
	_dots.top_level = true
	_dots.multimesh = dm
	_dots.material_override = _dots_mat
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dots.visible = false
	add_child(_dots)
	_line = Label3D.new()
	_line.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_line.font_size = 30
	_line.pixel_size = 0.006
	_line.outline_size = 8
	_line.no_depth_test = true
	_line.top_level = true
	_line.visible = false
	add_child(_line)
	_clink = AudioStreamPlayer3D.new()
	_clink.stream = _clink_sound()
	_clink.top_level = true
	add_child(_clink)
	_click = AudioStreamPlayer3D.new()
	_click.stream = _click_sound()
	_click.top_level = true
	add_child(_click)
	_grit_mat = StandardMaterial3D.new()
	_grit_mat.albedo_color = GRIT_COLOUR
	_grit_mat.roughness = 1.0
	reset()

## Coiled at his side, nothing out.
func reset() -> void:
	state = "coiled"
	hold = ""
	piece = ""
	lip = Vector3.INF
	beam_mid = Vector3.INF
	tested = false
	bad = false
	paid = 0.0
	hold_aim = false
	aim_point = Vector3.INF
	edge = Vector3.INF
	edge_out = Vector3.ZERO
	fixed = false
	lowering = false
	_drop_swing()
	_off_rope()
	_reel_after = false
	_yank = false
	_show_aim(false)
	_rope.visible = false
	_hook.visible = false

## The rope's out (anything but coiled or aiming).
func out() -> bool:
	return state != "coiled" and state != "aim"

# --- Input ------------------------------------------------------------------------------

## Polled each frame (the drivers' Input.action_press reaches it too).
func _read_input() -> void:
	var throw_down := Input.is_action_pressed(&"walk_throw")
	var reel_down := Input.is_action_pressed(&"walk_reel")
	var tug_down := Input.is_action_pressed(&"walk_tug")
	var throw_hit := throw_down and not _throw_was
	var reel_hit := reel_down and not _reel_was
	var tug_hit := tug_down and not _tug_was
	_throw_was = throw_down
	_reel_was = reel_down
	_tug_was = tug_down
	if _busy(): return
	# A host with two slots (the greed run: the bag or the rope in hand)
	# says when the keys are the rope's.
	if study.get("rope_keys") == false: return
	if throw_hit:
		if state == "coiled":
			if _on_foot(): aim()
		elif _can_snatch():
			# Out (a miss on the ground, a hook on a lip or a swing point):
			# snatched back to his hand, then whirled again if the throw's
			# still held when it's in.
			_snatch()
			_aim_after = true
		elif out(): _say("Reel it in first (%s)" % Pad.pick("F","D-pad down"))
	if reel_hit: reel()
	if tug_hit: tug()

## A throw press can snatch the hook back: it's out, he's not on it, not
## tied at a post, not up top over it.
func _can_snatch() -> bool:
	if not out() or swinging or climber or hauling or lowering or fixed or _yank: return false
	if state in ["fly","tug","pull_up"]: return false
	if (state == "seated" or state == "caught") and on_top(): return false
	return true

## Back to his hand through the air (flicked off a lip or a beam first).
func _snatch() -> void:
	_drop_swing()
	if state in ["seated","caught","drag"]:
		if hold == "beam" and beam_mid != Vector3.INF and (_hand()-beam_mid).dot(lip_out) < 0.0: lip_out = -lip_out
		_flick()
	elif state != "fall":
		_vel = Vector3.UP*3.0*_size()
		hook_at += Vector3.UP*0.1*_size()
		state = "fall"
	_yank = true
	_reel_after = true
	reels += 1

## The mouse turns the camera faster while he whirls (AIM_MOUSE).
func _input(event: InputEvent) -> void:
	if state != "aim" or study == null or not event is InputEventMouseMotion: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _busy(): return
	study.set("_yaw",float(study.get("_yaw"))-(event as InputEventMouseMotion).relative.x*MOUSE_LOOK*(AIM_MOUSE-1.0))

func _busy() -> bool:
	if study == null or not bool(study.get("walk_ready")): return true
	var editor := study.get_node_or_null("LayoutEdit")
	if editor != null and bool(editor.get("editing")): return true
	return study.has_method("_tuning") and bool(study.call("_tuning"))

func _on_foot() -> bool:
	var motor: Variant = study.get("motor")
	return motor != null and motor.grounded

# --- The throw --------------------------------------------------------------------------

## Held: the hook whirls at his side, the reticle on what the camera looks
## at; he keeps moving.
func aim() -> void:
	if state != "coiled": return
	state = "aim"
	_whirl = 0.0
	_hook.visible = true
	_rope.visible = true
	_aim_update(0.0)

## Drivers: the camera turned toward a world point (and kept on it while
## aiming), so the reticle picks what's there as the mouse would.
func aim_toward(point: Vector3) -> void:
	aim_point = point
	_turn_to_aim()
	if state == "aim": _aim_update(0.0)

func _turn_to_aim() -> void:
	if aim_point == Vector3.INF: return
	var feet: Vector3 = study.get("motor").feet
	var d := Vector2(aim_point.x-feet.x,aim_point.z-feet.z)
	if d.length() > 0.2: study.set("_yaw",PilotMotor.facing_of(d.normalized()))

## Kept for the hosts that still call it: the stick no longer moves the
## reticle (he walks with it), so nothing to do.
func aim_steer(_want: Vector2, _delta: float) -> void:
	pass

## Let go: the hook flies the arc shown, from his hand as he goes.
func release() -> void:
	if state != "aim": return
	hold_aim = false
	aim_point = Vector3.INF
	_show_aim(false)
	_from = _hand()+Vector3.UP*0.25*_size()
	hook_at = _from
	_vel = _arc_to(_from,aim_at,_rise_k)
	_fly_all = _flight_time(_from,aim_at,_vel)
	_fly_t = 0.0
	lip = aim_lip
	lip_out = aim_out
	hold = aim_hold
	piece = aim_piece
	beam_mid = aim_mid
	beam_half = aim_half
	# Red over a beam (too high): it comes down on the bar and slides off.
	if hold == "beam" and not aim_ok: hold = ""
	throws += 1
	state = "fly"
	paid = 0.0

## The camera's look, flat (its yaw's forward).
func _look() -> Vector3:
	var f := PilotMotor.forward(float(study.get("_yaw")))
	return Vector3(f.x,0.0,f.y)

func _aim_update(_delta: float) -> void:
	var motor: Variant = study.get("motor")
	var s := _size()
	var t := _pick(_look())
	aim_at = t.at
	aim_lip = t.lip
	aim_out = t.out
	aim_hold = t.hold
	aim_piece = t.piece
	aim_why = t.why
	aim_mid = t.get("mid",Vector3.INF)
	aim_half = float(t.get("half",0.0))
	aim_ok = t.why == ""
	var feet: Vector3 = motor.feet
	# Standing, he turns to it; on the move he keeps his own way.
	var d := Vector2(aim_at.x-feet.x,aim_at.z-feet.z)
	if d.length() > 0.2 and motor.grounded and motor.speed() < 0.6: motor.facing = PilotMotor.facing_of(d.normalized())
	# At a run the throw flies flatter.
	var v: Vector3 = motor.velocity
	_rise_k = lerpf(1.0,RUN_FLAT,clampf(Vector2(v.x,v.z).length()/PilotMotor.RUN,0.0,1.0))
	# The arc there, and what it meets on the way.
	var from := _hand()+Vector3.UP*0.25*s
	aim_arc = PackedVector3Array()
	var av := _arc_to(from,aim_at,_rise_k)
	var g := _fly_g()
	var t_all := _flight_time(from,aim_at,av)
	var space := get_world_3d().direct_space_state
	var was := from
	aim_arc.append(from)
	if from.distance_to(aim_at) > ROPE_LEN*s and aim_ok:
		aim_ok = false
		aim_why = "out of reach"
	for i in range(1,ARC_DOTS+1):
		var tt := t_all*float(i)/ARC_DOTS
		var at := from+av*tt+Vector3.DOWN*0.5*g*tt*tt
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(was,at,CarryHost.SOLID_MASK))
		if not hit.is_empty() and (hit.position as Vector3).distance_to(aim_at) > LAND_IN*s+0.3:
			aim_arc.append(hit.position)
			if aim_ok:
				aim_ok = false
				aim_why = "the way's blocked"
			break
		aim_arc.append(at)
		was = at
	_show_aim(true)

## What a throw along `look` (flat, the camera's) goes at: a swing point or
## an anchor post near the look line (within AIM_CONE of it, or AIM_NEAR
## across it), else the first lip above him along it, else the ground out
## ahead (a miss). The swing point or post wins while it's within
## AIM_PREFER of the cone, or when there's no lip on the line.
func _pick(look: Vector3) -> Dictionary:
	var s := _size()
	var feet: Vector3 = study.get("motor").feet
	var reach := AIM_REACH*s
	var u := Vector2(look.x,look.z).normalized()
	var snap := {}
	var snap_k := INF
	# Swing points: their lines sampled for the spot nearest the look line.
	for b: Dictionary in HookLine.all_in(get_tree()):
		var a: Vector3 = b.a
		var e: Vector3 = b.b
		for i in 13:
			var p := a.lerp(e,float(i)/12.0)
			var k := _cone_k(feet,u,p,reach)
			if k < snap_k:
				var bar := _beam_target(p)
				if bar.is_empty() or str(bar.piece) != str(b.piece): continue
				snap_k = k
				snap = bar
	# Anchor posts over his head.
	var holds: Dictionary = study.get("holds")
	var pieces: Dictionary = study.get("pieces")
	for id: String in holds:
		if holds[id] != "anchor" or not pieces.has(id): continue
		var top := _post_top(pieces[id])
		if top.y-feet.y < ABOVE*s: continue
		var k := _cone_k(feet,u,top,reach)
		if k < snap_k:
			snap_k = k
			snap = _post_target(id)
	if snap_k < AIM_PREFER: return snap
	# The first top above him along the look line: its near lip.
	var space := get_world_3d().direct_space_state
	var d := AIM_MIN*s
	while d <= reach:
		var p := feet+look*d
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,feet.y+16.0*s,p.z),Vector3(p.x,feet.y-30.0*s,p.z),CarryHost.SOLID_MASK))
		if not down.is_empty() and (down.position as Vector3).y-feet.y >= ABOVE*s:
			return target(p+look*0.5*s,true)
		d += AIM_STEP*s
	if snap_k <= 1.0: return snap
	return target(feet+look*reach*AIM_START,true)

## How far off the look line `p` is, as a share of the cone (0 on it, 1 at
## its edge; INF behind him, out of reach or under ABOVE).
func _cone_k(feet: Vector3, u: Vector2, p: Vector3, reach: float) -> float:
	var s := _size()
	var w := Vector2(p.x-feet.x,p.z-feet.z)
	var along := w.dot(u)
	if along < AIM_MIN*s*0.5 or w.length() > reach*1.15 or p.y-feet.y < ABOVE*s: return INF
	var across := absf(w.dot(Vector2(-u.y,u.x)))
	var ang := rad_to_deg(atan2(across,along))
	return minf(ang/AIM_CONE,across/(AIM_NEAR*s) if along < 4.0*s else INF)

## Where a throw at `over` (a point under the reticle) goes: {at (where it
## comes down), lip (where it'd hook, else INF), out, hold, piece, why (""
## when it catches)}.
## `lip_only`: the lip under `over` alone (the swing points and posts were
## weighed already, `_pick`).
func target(over: Vector3, lip_only := false) -> Dictionary:
	var motor: Variant = study.get("motor")
	var s := _size()
	var feet: Vector3 = motor.feet
	var holds: Dictionary = study.get("holds")
	var pieces: Dictionary = study.get("pieces")
	if not lip_only:
		var bar := _beam_target(over)
		if not bar.is_empty(): return bar
		# An anchor post near the reticle, over his head.
		var best := ""
		var best_d := POST_SNAP*s
		for id: String in holds:
			if holds[id] != "anchor" or not pieces.has(id): continue
			var top := _post_top(pieces[id])
			if top.y-feet.y < ABOVE*s: continue
			var dd := Vector2(top.x-over.x,top.z-over.z).length()
			if dd < best_d:
				best_d = dd
				best = id
		if best != "": return _post_target(best)
	var space := get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(over+Vector3.UP*16.0*s,over+Vector3.DOWN*30.0*s,CarryHost.SOLID_MASK))
	if down.is_empty():
		return {"at":over+Vector3.DOWN*2.0*s,"lip":Vector3.INF,"out":Vector3.ZERO,"hold":"","piece":"","why":"nothing there"}
	var hit_at: Vector3 = down.position
	var body: Object = down.collider
	var id := _piece_of(body)
	if hit_at.y-feet.y < ABOVE*s:
		return {"at":hit_at+Vector3.UP*0.04,"lip":Vector3.INF,"out":Vector3.ZERO,"hold":"","piece":id,"why":"nothing to catch on"}
	# The lip: the top's edge on his side, along the line to the reticle.
	var y := hit_at.y-0.08*s
	var a := Vector3(feet.x,y,feet.z)
	var b := Vector3(over.x,y,over.z)
	var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b+(b-a).normalized()*0.5*s,CarryHost.SOLID_MASK))
	var edge := hit_at
	var o := -_forward()
	if not side.is_empty() and side.collider == body:
		var n: Vector3 = side.normal
		n.y = 0.0
		if n.length() > 0.5:
			o = n.normalized()
			edge = Vector3((side.position as Vector3).x,hit_at.y,(side.position as Vector3).z)
	var at := edge-o*LAND_IN*s+Vector3.UP*0.05
	var h: String = str(holds.get(id,""))
	# A host whose ground has no tagged pieces (the crag reach) may give
	# every untagged top one hold (`rope_ground_hold`, e.g. "solid").
	if id == "" and study.get("rope_ground_hold") != null: h = str(study.get("rope_ground_hold"))
	if h == "" or h == "anchor":
		return {"at":at,"lip":edge,"out":o,"hold":"","piece":id,"why":"a smooth top: nothing to catch on"}
	return {"at":at,"lip":edge,"out":o,"hold":h,"piece":id,"why":""}

## A throw at anchor post `id`: wrapped round it under its top.
func _post_target(id: String) -> Dictionary:
	var s := _size()
	var feet: Vector3 = study.get("motor").feet
	var top := _post_top(study.get("pieces")[id])
	var wrap := top+Vector3.DOWN*POST_WRAP*s
	var o := Vector3(feet.x-top.x,0.0,feet.z-top.z)
	o = o.normalized() if o.length() > 0.01 else -_forward()
	return {"at":wrap+Vector3.UP*0.05,"lip":wrap,"out":o,"hold":"anchor","piece":id,"why":""}

## A hook line near the reticle over his head (scripts/rope/hook_line.gd:
## a beam's, or anything else that carries one; hold "beam"): the point on
## its line nearest the reticle, the hook coming down on its top and
## wrapping over it; {} when none is near. Too high, it's red.
func _beam_target(over: Vector3) -> Dictionary:
	var s := _size()
	var feet: Vector3 = study.get("motor").feet
	var best := {}
	var best_d := BEAM_SNAP*s
	for b: Dictionary in HookLine.all_in(get_tree()):
		var a: Vector3 = b.a
		var e: Vector3 = b.b
		var ab := Vector2(e.x-a.x,e.z-a.z)
		var l := ab.length()
		if l < 0.01: continue
		var u := ab/l
		var k := clampf(Vector2(over.x-a.x,over.z-a.z).dot(u),minf(BEAM_END*s,l*0.5),maxf(l-BEAM_END*s,l*0.5))
		var on := a+Vector3(u.x,0.0,u.y)*k
		on.y = a.y+(e.y-a.y)*k/l
		if on.y-feet.y < ABOVE*s: continue
		var dd := Vector2(on.x-over.x,on.z-over.z).length()
		if b.get("ring",false):
			# A ring: snapped anywhere along the line, it hooks the middle.
			k = l*0.5
			on = a+Vector3(u.x,0.0,u.y)*k
			on.y = (a.y+e.y)*0.5
		if dd >= best_d: continue
		best_d = dd
		# The near side: toward him, across the line.
		var across := Vector3(-u.y,0.0,u.x)
		if across.dot(Vector3(feet.x-on.x,0.0,feet.z-on.z)) < 0.0: across = -across
		var half: float = b.half
		var why := ""
		if on.y-feet.y > BEAM_HIGH*s: why = "too high"
		best = {"at":on+Vector3.UP*0.05*s,"lip":on,"out":across,"hold":"beam","piece":str(b.piece),"why":why,
			"mid":on+Vector3.DOWN*half,"half":half}
	return best

## The study's piece id a collider belongs to ("" none).
func _piece_of(body: Object) -> String:
	if body == null or not body is Node: return ""
	var pieces: Dictionary = study.get("pieces")
	var id := str((body as Node).name)
	return id if pieces.has(id) and pieces[id] == body else ""

## A post's top (its collider's height about its middle).
func _post_top(post: Node3D) -> Vector3:
	var h := 1.0
	for c in post.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is CylinderShape3D:
			h = ((c as CollisionShape3D).shape as CylinderShape3D).height
	return post.global_transform*Vector3(0.0,h*0.5,0.0)

# --- E: the kick, the hop, the tie ------------------------------------------------------

## E (pad B): on the rope, a kick off the wall (rappelling, a hop); coiled
## by an anchor post up top, the tie. A set hook needs nothing (no tug).
func tug() -> void:
	if swinging or swing_hold: return
	if climber and rappel:
		# Rappelling, E pushes off the wall in a hop (crouched in, then
		# kicked out on the pendulum); pressed just before he meets the
		# wall again, he lands it into the next.
		if _hop_t < 0.0 and _stance_k >= 1.0 and not study.get("motor").crouch:
			_hop_t = 0.0
			_hop_fly = false
			_hop_from = _base_y
			_hop_drop = minf(HOP_DROP*_size(),_hop_from-_floor_under(study.get("motor").feet))
			_rap_v = 0.0
			hops += 1
		else: _kick_buf = 0.25
		return
	if climber:
		# Hanging on the rope, E kicks off the wall (buffered till his feet
		# are on it).
		_kick_buf = 0.25
		return
	if state == "coiled": _fix()

func _tug_step(delta: float) -> void:
	_tug_t += delta
	var motor: Variant = study.get("motor")
	var feet: Vector3 = motor.feet
	var d := Vector2(lip.x-feet.x,lip.z-feet.z)
	if d.length() > 0.2: motor.facing = PilotMotor.facing_of(d.normalized())
	var span := _span()
	# The slack taken in as he reaches and yanks.
	var k := clampf(_tug_t/(TUG_REACH+TUG_YANK),0.0,1.0)
	paid = lerpf(maxf(_tug_paid,span),span,k*k)
	if _tug_t < TUG_REACH+TUG_YANK: return
	if not _tug_said:
		_tug_said = true
		tested = true
		seats += 1
		_click_play()
		if fixed: _say("Fixed round the post. At the edge, facing out, %s goes over" % Pad.pick("Space","A"))
		else: _say("Seated: %s" % {"anchor":"round the post","beam":"round the beam"}.get(hold,"safe to climb"))
	if _tug_t >= TUG_REACH+TUG_YANK+TUG_HOLD: state = "seated"

## Skittering back over the crumbling lip, then off it.
func _slip_step(delta: float) -> void:
	_fly_t += delta
	var s := _size()
	var k := clampf(_fly_t/SLIP_TIME,0.0,1.0)
	hook_at = _slide_from+lip_out*0.25*s*k*k+Vector3.DOWN*0.06*s*k
	paid = _hand().distance_to(hook_at)
	if k < 1.0: return
	_vel = lip_out*1.4*s+Vector3.UP*0.4*s
	state = "fall"

## Grit off the lip where the hook tore out.
func _spill_grit() -> void:
	var s := _size()
	for i in GRIT:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		var e := randf_range(0.05,0.11)*s
		b.size = Vector3(e,e*0.8,e)
		m.mesh = b
		m.material_override = _grit_mat
		m.top_level = true
		add_child(m)
		var side := lip_out.cross(Vector3.UP).normalized()
		m.global_position = lip+side*randf_range(-0.25,0.25)*s+Vector3.DOWN*0.05*s
		m.rotation = Vector3(randf()*TAU,randf()*TAU,0.0)
		var v := lip_out*randf_range(0.5,1.6)*s+side*randf_range(-0.6,0.6)*s+Vector3.UP*randf_range(0.0,1.2)*s
		_grit.append({"node":m,"vel":v,"t":0.0,"spin":Vector3(randf_range(-8,8),randf_range(-8,8),0.0)})

func _grit_step(delta: float) -> void:
	var g := _gravity()
	for i in range(_grit.size()-1,-1,-1):
		var b: Dictionary = _grit[i]
		var m: MeshInstance3D = b.node
		b.t = float(b.t)+delta
		if float(b.t) > GRIT_LIFE:
			m.queue_free()
			_grit.remove_at(i)
			continue
		b.vel = (b.vel as Vector3)+Vector3.DOWN*g*delta
		var floor_y := float(study.get("lost"))
		m.global_position += (b.vel as Vector3)*delta
		m.rotation += (b.spin as Vector3)*delta
		if m.global_position.y < floor_y: b.t = GRIT_LIFE

# --- Reeling in -------------------------------------------------------------------------

## Draws the rope in: a caught hook flicked off its lip first.
func reel() -> void:
	if climber or hauling or lowering or swinging: return
	_drop_swing()
	if (state == "caught" or state == "seated") and on_top():
		# From the top: pulled up hand over hand, the hanging end rising.
		reels += 1
		state = "pull_up"
		_up_len = maxf(edge.y-_floor_under(line_at(edge.y-0.3*_size())),0.0)
		_say("Pulling it up")
		return
	if state == "seated" and fixed:
		# From below: the free end pulled, it runs round the post and drops.
		reels += 1
		pulled_down += 1
		lip = edge
		lip_out = edge_out
		edge = Vector3.INF
		fixed = false
		_slide_from = hook_at
		_fly_t = 0.0
		state = "slide"
		_reel_after = true
		_say("Pulled it down")
		return
	match state:
		"caught", "drag", "tug", "seated":
			reels += 1
			if hold == "beam" and beam_mid != Vector3.INF:
				# Off a beam: over it toward him, then pulled to his hand.
				if (_hand()-beam_mid).dot(lip_out) < 0.0: lip_out = -lip_out
				_yank = true
			_flick()
			_reel_after = true
			_say("Flicked free")
		"fall", "slide", "fly", "slip":
			reels += 1
			_reel_after = true
		"down":
			reels += 1
			state = "reel"

func _flick() -> void:
	var s := _size()
	_vel = lip_out*FLICK.x*s+Vector3.UP*FLICK.y*s
	hook_at = (lip if lip != Vector3.INF else hook_at)+lip_out*0.15*s+Vector3.UP*0.1*s
	state = "fall"

# --- The climb -------------------------------------------------------------------------

## The edge the caught rope runs over (`edge`, `edge_out`): a lip's own; a
## post's, walked out from it toward where the rope hangs till the top
## ends, then found exactly by a ray back at its face.
func _find_edge() -> void:
	edge = lip
	edge_out = lip_out
	if hold == "beam" and beam_mid != Vector3.INF:
		# Over a beam the rope runs down its near side.
		edge = lip+lip_out*beam_half
		return
	if hold != "anchor": return
	var s := _size()
	var space := get_world_3d().direct_space_state
	var top_y := INF
	var last := Vector3.INF
	for i in 120:
		var p := lip+lip_out*(0.22+0.05*i)*s
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.6*s,p+Vector3.DOWN*3.0*s,CarryHost.SOLID_MASK))
		if hit.is_empty(): break
		var y := (hit.position as Vector3).y
		if top_y == INF: top_y = y
		if absf(y-top_y) > 0.25*s: break
		last = Vector3(p.x,y,p.z)
	if last == Vector3.INF: return
	var a := last+lip_out*0.4*s+Vector3.DOWN*0.08*s
	var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,a-lip_out*0.8*s,CarryHost.SOLID_MASK))
	edge = last
	if not side.is_empty():
		var n: Vector3 = side.normal
		n.y = 0.0
		if n.length() > 0.5:
			edge_out = n.normalized()
			edge = Vector3((side.position as Vector3).x,last.y,(side.position as Vector3).z)

## He's up on the top the rope's hooked over (or level with it).
func on_top() -> bool:
	if edge == Vector3.INF: return false
	var motor: Variant = study.get("motor")
	return (motor.feet as Vector3).y > edge.y-0.4*_size()

## Where the hanging rope is at height `y` (world).
func line_at(y: float) -> Vector3:
	var s := _size()
	return Vector3(edge.x+edge_out.x*ROPE_OFF*s,y,edge.z+edge_out.z*ROPE_OFF*s)

## Called by the study before the motor's step: Jump by the hanging rope of
## a set hook takes hold of it (instead of the jump).
func pre_step(jump_down: bool) -> void:
	var hit := jump_down and not _jump_was
	_jump_was = jump_down
	if swing_hold and not swinging and not _busy(): _swing_frame()
	if not hit or climber or hauling or lowering or _busy(): return
	if state != "caught" and state != "seated": return
	if hold == "beam" and beam_mid != Vector3.INF:
		_swing_pre(hit)
		return
	if edge == Vector3.INF or not _on_foot(): return
	var motor: Variant = study.get("motor")
	var s := _size()
	var feet: Vector3 = motor.feet
	if on_top():
		# At the edge the rope goes over, facing out: lowered over it.
		var rel := Vector3(feet.x-edge.x,0.0,feet.z-edge.z)
		var back := -rel.dot(edge_out)
		var along := absf(rel.dot(edge_out.cross(Vector3.UP).normalized()))
		var f := PilotMotor.forward(motor.facing)
		if back < -0.1*s or back > LOWER_REACH*s or along > 1.0*s: return
		if f.dot(Vector2(edge_out.x,edge_out.z)) < 0.3: return
		_lower(motor)
		return
	var at := line_at(feet.y)
	if Vector2(at.x-feet.x,at.z-feet.z).length() > GRAB_REACH*s: return
	_mount(motor)

# --- The swing (a rope over a beam) -----------------------------------------------------

## The beam's top the rope runs over (the pendulum's anchor).
func _swing_top() -> Vector3:
	return lip+Vector3.UP*ROPE_R*_size()

## Jump by a beam's rope: taken hold of (the rope in his hand, or a hanging
## one within GRAB_REACH), this press not a jump. Held, Jump is his own jump
## (off the edge, into the swing).
func _swing_pre(_hit: bool) -> void:
	if swing_hold or swinging or not _on_foot(): return
	_take_swing(true)

## The rope over the beam taken in hand (`swing_hold`): on the ground he's
## held to its reach; in the air (thrown off an edge) the next step swings
## him. `near`: only within GRAB_REACH of a rope left hanging. False when
## out of reach (or on a ledge, a rope, in water).
func _take_swing(near := false) -> bool:
	if swing_hold or swinging: return false
	var motor: Variant = study.get("motor")
	if climber or motor.rider != null or motor.swimming or motor.on_ledge(): return false
	var s := _size()
	var hand := SwingRope.hand_of(motor)
	var top := _swing_top()
	if swing_left and _pend != null:
		var q := Geometry3D.get_closest_point_to_segment(hand,top,_pend.hands)
		if near and hand.distance_to(q) > GRAB_REACH*s: return false
	var d := hand.distance_to(top)
	if d > ROPE_LEN*s:
		_say("Too far from the beam")
		return false
	swing_hold = true
	swing_left = false
	swing_len = maxf(d,SWING_MIN*s)
	motor._held = true
	_say("Holding the rope: run off the edge or %s to swing · %s lets go" % [Pad.pick("Space","A"),Pad.pick("Shift","crouch")])
	_swing_said = true
	return true

## Each frame holding a beam's rope (before the motor's step): on the
## ground, the slack taken in, kept within the rope's reach of the beam
## (crouch lets go); off the ground, on the pendulum.
func _swing_frame() -> void:
	var motor: Variant = study.get("motor")
	if motor.rider != null or motor.swimming or motor.on_ledge():
		swing_hold = false
		return
	var s := _size()
	var top := _swing_top()
	var hand := SwingRope.hand_of(motor)
	var d := hand.distance_to(top)
	if motor.grounded:
		if motor.crouch and motor.speed() < 1.0:
			swing_hold = false
			_say("Let go of the rope")
			return
		# He takes in the slack as he goes: the rope's as long as his hands
		# are from the beam, up to all of it (then he's held at that).
		var most := ROPE_LEN*s-SWING_OVER*s
		if d > most:
			var off := hand-top
			var dy := off.y
			var flat := Vector2(off.x,off.z)
			var r := sqrt(maxf(most*most-dy*dy,0.0))
			if flat.length() > 0.001:
				var fix := flat.normalized()*(r-flat.length())
				motor.feet += Vector3(fix.x,0.0,fix.y)
				var v: Vector3 = motor.velocity
				var out := Vector3(flat.x,0.0,flat.y).normalized()
				if v.dot(out) > 0.0: motor.velocity = v-out*v.dot(out)
		swing_len = clampf(d,SWING_MIN*s,most)
		return
	if _swing_cool > 0.0: return
	_swing_mount(motor)

## Off the ground: on the pendulum under the beam (its pace taken into the
## swing), this rope his rider.
func _swing_mount(motor: Variant) -> void:
	if _pend == null: _pend = SwingRope.new()
	_pend.setup(_swing_top(),swing_len)
	_pend._take(motor,SwingRope.hand_of(motor))
	motor.rider = self
	swinging = true
	swings += 1
	# The yank off the ground throws the brood off him, as a jump does
	# (their slow on his run-off would else drop him off the rim, put down
	# and swung again, till he slips under the lip and swings too hard).
	var brood: Variant = study.get("brood")
	if brood != null and brood.has_method("shake_off"):
		var v: Vector3 = motor.velocity
		brood.shake_off(Vector3(v.x,0.0,v.z)*0.3)
	_say("Swinging: %s pumps · %s climbs · %s slides down · %s lets go" % [Pad.pick("W/S","stick"),Pad.pick("E","B"),Pad.pick("F","D-pad down"),Pad.pick("Space","A")])
	_swing_said = true

## One step on the pendulum: the swing rope's ride (pump, steer, release),
## then a face hit (the pace into it taken off, a little bounce) and the
## floor (put down on his feet, still holding the rope).
func _swing_ride(walker: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	var s := _size()
	var was_feet := walker.feet
	_swing_climb(delta)
	var was_hands := _pend.hands
	var was_v := _pend.velocity
	var keep := [SwingRope.t_boost,SwingRope.t_pop]
	SwingRope.t_boost = SWING_BOOST
	SwingRope.t_pop = SWING_POP
	var out := _pend.ride(walker,delta,want,pressed)
	SwingRope.t_boost = keep[0]
	SwingRope.t_pop = keep[1]
	if out.get("swing",true) == false:
		# Let go (Jump, with the swing's pace; crouch, without): the rope
		# left hanging off the beam, its end swinging on.
		swinging = false
		swing_hold = false
		swing_left = true
		swing_releases += 1
		_tilt_left = UPRIGHT
		out["let_go"] = true
		return out
	var chest := Vector3.UP*0.6*s
	var a := was_feet+chest
	var b := walker.feet+chest
	if a.distance_to(b) > 0.0001:
		var b2 := b+(b-a).normalized()*0.3*s
		var space := get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b2,CarryHost.SOLID_MASK))
		if not hit.is_empty():
			var n: Vector3 = hit.normal
			var v := was_v
			var vn := v.dot(n)
			if vn < 0.0: v -= n*vn*(1.0+SWING_BOUNCE)
			_pend.hands = was_hands
			var u := (_pend.hands-_pend.anchor).normalized()
			_pend.velocity = v-u*v.dot(u)
			_pend._place(walker)
			out["swing_hit"] = true
	var fl := _floor_under(walker.feet+Vector3.UP*0.6*s)
	if walker.feet.y < fl:
		# The swing scrapes the floor: down on his feet, the rope in hand.
		walker.feet.y = fl
		var v := _pend.velocity
		walker.toss(Vector3(v.x,0.0,v.z)*0.6)
		swinging = false
		_swing_cool = SWING_COOL
		_tilt_left = UPRIGHT
		scrapes += 1
		_say("Scraped the floor")
		out["scraped"] = true
	return out

## Up (E) or down (F) the rope on the pendulum: the grip moved along it
## between SWING_MIN and the rope's reach, the pace scaled by old/new.
func _swing_climb(delta: float) -> void:
	var s := _size()
	var rate := 0.0
	if Input.is_action_pressed(&"walk_tug"): rate -= SWING_UP*s
	if Input.is_action_pressed(&"walk_reel"): rate += SWING_DOWN*s
	_climb_k = move_toward(_climb_k,1.0 if rate < 0.0 else 0.0,delta*8.0)
	if rate == 0.0: return
	var old := _pend.grip
	var g := clampf(old+rate*delta,SWING_MIN*s,ROPE_LEN*s-SWING_OVER*s)
	if absf(g-old) < 0.0001: return
	var u := (_pend.hands-_pend.anchor).normalized()
	_pend.grip = g
	_pend.length = g
	_pend.hands = _pend.anchor+u*g
	_pend.velocity = (_pend.velocity*old/g).limit_length(SwingRope.t_top)
	swing_len = g
	swing_climbed += g-old
	_climb_phase += absf(g-old)/(SWING_HAND*2.0*s)*PI

## The rope off the beam: not held, not swung, not left hanging.
func _drop_swing() -> void:
	if swinging and study != null and study.get("motor") != null and study.get("motor").rider == self:
		study.get("motor").release(self)
	swinging = false
	swing_hold = false
	swing_left = false
	_tilt_left = 0.0

## On the pendulum: the body along the rope (the swing rope's frame), both
## hands on it at the grip.
func _swing_pose(sk: Skeleton3D) -> void:
	var fig: Node3D = study.get("figure")
	if fig == null: return
	var s := _size()
	_tilt = _pend.tilt
	fig.global_basis = _tilt*Basis.from_scale(fig.global_basis.get_scale())
	var up := (_pend.anchor-_pend.hands).normalized()
	var right := _tilt.x.normalized()
	var back := _tilt.z.normalized()
	var to_sk := sk.global_transform.affine_inverse()
	for sd: float in [1.0,-1.0]:
		var names := ["upper_arm.R","forearm.R","hand.R"] if sd > 0.0 else ["upper_arm.L","forearm.L","hand.L"]
		var upper := sk.find_bone(names[0])
		var fore := sk.find_bone(names[1])
		var hand := sk.find_bone(names[2])
		if upper < 0 or fore < 0 or hand < 0: return
		# Climbing, hand over hand: each hand reaches up as the other holds.
		var over := sin(_climb_phase+(0.0 if sd > 0.0 else PI))*SWING_HAND*_climb_k
		var at := _pend.hands+up*((0.07 if sd > 0.0 else -0.07)+over)*s+right*sd*HAND_SPREAD*s
		var pole := (sk.global_basis.inverse()*(right*sd*0.8+Vector3.DOWN*0.3+back*0.5)).normalized()
		CarryHost._two_bone(sk,upper,fore,hand,to_sk*at,pole,1.0)

func _mount(motor: Variant) -> void:
	var s := _size()
	var feet: Vector3 = motor.feet
	var y := minf(feet.y+0.12*s,edge.y-float(motor.hang_drop))
	motor.mount(self,_body_at(motor,y),false,PilotMotor.facing_of(Vector2(-edge_out.x,-edge_out.z)),true)
	motor.hold = "swing"
	motor.move = ""
	climber = true
	climbs += 1
	_on_t = 0.0
	_stance_k = 0.0
	_rap_v = 0.0
	_rap_held = 0.0
	_pull_t = -1.0
	var top := y+float(motor.hang_drop)
	_hand_y = [top,top-PULL*s]
	_hand_side = [1.0,-1.0]
	_live_begin(motor,y)
	if rappel:
		_hop_t = -1.0
		_say("Rappelling: %s lowers · %s climbs · %s pushes off · %s slides · %s lets go" % [Pad.pick("S","stick back"),Pad.pick("W","stick up"),Pad.pick("E","B"),Pad.pick("Shift","crouch"),Pad.pick("Space","A")])
		return
	_say("On the rope: %s climbs · %s lets go · %s slides" % [Pad.pick("W","stick up"),Pad.pick("Space","A"),Pad.pick("Shift","crouch")])

## Over the edge from the top: the motor's own catch (turned to face the
## edge) and lower (the climb played back) to a hang, then on the rope,
## rappelling (`_process` takes the hang).
func _lower(motor: Variant) -> void:
	motor.lip = edge
	motor.lip_out = Vector2(edge_out.x,edge_out.z)
	motor.hold = "catch"
	motor._hold_time = 0.0
	motor.facing = PilotMotor.facing_of(-Vector2(edge_out.x,edge_out.z))
	motor._still()
	lowering = true
	rappels += 1

## E by an anchor post on a top, the rope coiled: tied round its foot and
## the rest thrown over the nearest drop beyond it (the way he looks past
## it), tugged to seat it.
func _fix() -> void:
	if not _on_foot(): return
	var motor: Variant = study.get("motor")
	var s := _size()
	var feet: Vector3 = motor.feet
	var holds: Dictionary = study.get("holds")
	var pieces: Dictionary = study.get("pieces")
	var best := ""
	var best_d := FIX_REACH*s
	for id: String in holds:
		if holds[id] != "anchor" or not pieces.has(id): continue
		var post: Node3D = pieces[id]
		var top := _post_top(post)
		var foot := post.global_position*2.0-top
		if absf(foot.y-feet.y) > 0.4*s: continue
		var d := Vector2(top.x-feet.x,top.z-feet.z).length()
		if d < best_d:
			best_d = d
			best = id
	if best == "":
		return
	var post: Node3D = pieces[best]
	var foot := post.global_position*2.0-_post_top(post)
	var o := Vector3(foot.x-feet.x,0.0,foot.z-feet.z)
	o = o.normalized() if o.length() > 0.05 else _forward()
	hold = "anchor"
	piece = best
	lip = foot+Vector3.UP*TIE_UP*s
	lip_out = o
	hook_at = lip
	bad = false
	tested = false
	_find_edge()
	if edge.distance_to(lip) < 0.3*s:
		edge = Vector3.INF
		edge_out = Vector3.ZERO
		_say("No drop that way")
		return
	fixed = true
	tugs += 1
	state = "tug"
	_tug_t = 0.0
	paid = _hand().distance_to(hook_at)+0.3*s
	_tug_paid = paid
	_tug_said = false

## His feet hanging on the rope with them at height `y`: off the wall as
## the motor's ledge hang holds him.
func _body_at(motor: Variant, y: float) -> Vector3:
	var s := _size()
	var near := clampf((edge.y-float(motor.hang_drop)-y)/(BODY_IN*s),0.0,1.0)
	var o := float(motor.hang_out)+BODY_OFF*s*near
	return Vector3(edge.x+edge_out.x*o,y,edge.z+edge_out.z*o)

## One step on the rope (the motor's rider, scripts/pilot_motor.gd `ride`).
func ride(walker: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	if swinging: return _swing_ride(walker,delta,want,pressed)
	var out := {}
	_on_t += delta
	var s := _size()
	_kick_buf = maxf(_kick_buf-delta,0.0)
	if pressed and _on_t > 0.2:
		# Let go: off with the grip's pace (more along it, rising), a little
		# off the wall and up.
		var v := _lv
		if v.y > 0.2 and v.length() > 1.0: v += v.normalized()*RELEASE*s
		let_go_v = v+edge_out*0.3*s+Vector3.UP*0.6*s
		walker.toss(let_go_v)
		_off_rope()
		out["let_go"] = true
		return out
	var toward := Vector2(-edge_out.x,-edge_out.z).normalized()
	# The stick's own up/down (forward climbs, back lowers), whatever way
	# the camera looks; across the face, it pumps the sway.
	var push := _to_cam(want).y
	var across := _across(want)
	var y := _base_y
	var drop := float(walker.hang_drop)
	var top_y := edge.y-drop
	if rappel:
		if push > 0.35 and _hop_t < 0.0 and not walker.crouch and not _too_heavy():
			# Stick up: hands up the rope, climbing as from below (the
			# stance eases out, no snap).
			rappel = false
			_rap_v = 0.0
			_hand_y = [y+drop,y+drop-PULL*s]
			_hand_side = [1.0,-1.0]
		else:
			return _rappel_step(walker,delta,push,across,out)
	var heavy := _load_k()
	if walker.crouch:
		# Sliding down, both hands loose on the rope over his head.
		_pull_t = -1.0
		y -= SLIDE_SPEED*s*delta
		_hand_y = [y+drop,y+drop-0.12*s]
	elif _pull_t < 0.0 and push > 0.35 and _too_heavy():
		# Too heavy to haul up: a strained heave that gets nowhere.
		if walker._refuse_cool <= 0.0:
			too_heavy += 1
			_lv += edge_out*0.2*s
			_say("Too heavy to climb (%.0f kg): throw the bag up first" % _kg())
		walker.refuse("ledge")
	elif _pull_t >= 0.0 or push > 0.35:
		if _pull_t < 0.0:
			if y >= top_y-0.01*s:
				_haul(walker,out)
				return out
			_pull_t = 0.0
			_pull_from = y
			_reach_from = float(_hand_y[1])
			# The heave throws him off the wall and toward the hauling hand.
			_lv += edge_out*PULL_OUT*s*(1.0-0.4*heavy)+_side()*float(_hand_side[0])*PULL_SIDE*s
		_pull_t = minf(_pull_t+delta/(PULL_T*climb_pace),1.0)
		var rise := minf(PULL*s,top_y-_pull_from)
		# Hauled up on the top hand (eased in and out) past the pull's
		# height (the lurch), then the low hand reaches past it, arcing off
		# the rope, as he settles back (heavy: sags under it first).
		var k := clampf(_pull_t/REACH_AT,0.0,1.0)
		var r := clampf((_pull_t-REACH_AT)/(1.0-REACH_AT),0.0,1.0)
		var settle := r*r*(3.0-2.0*r)
		var lurch := LURCH*s*(1.0-0.6*heavy)*sin(PI*0.5*k)*sin(PI*0.5*k)*(1.0-settle)
		lurch -= HEAVY_SAG*s*heavy*sin(PI*r)
		y = _pull_from+rise*k*k*(3.0-2.0*k)+lurch
		if _pull_t > REACH_AT:
			var rr := 1.0-(1.0-r)*(1.0-r)
			_hand_y[1] = lerpf(_reach_from,_pull_from+rise+drop,rr)
		if _pull_t >= 1.0:
			# The reached hand is the top one now.
			y = _pull_from+rise
			_hand_y = [_hand_y[1],_hand_y[0]]
			_hand_side = [_hand_side[1],_hand_side[0]]
			_pull_t = -1.0
			out["pulled"] = true
	elif push < -0.35:
		# Down hand under hand: the hands slide along, swapping as they go.
		y -= DOWN_SPEED*s*climb_pace*delta
		var bob := sin((y/(PULL*s))*PI)*0.5*PULL*s
		_hand_y = [y+drop-maxf(bob,0.0),y+drop-PULL*s+minf(bob,0.0)]
	_stance_k = maxf(_stance_k-delta/UNRAP,0.0)
	# The live rope: his kick, the stick across pumping it.
	if _kick_buf > 0.0 and _on_wall():
		_kick_buf = 0.0
		_kick(KICK*s)
	_live_step(delta,y,0.0,across*LIVE_PUMP*s,LIVE_RUB)
	var at := _stance_at(walker,y)+sway
	# Down to the ground under him: off the rope, on his feet.
	var ground := _floor_under(at)
	if y <= ground+0.01*s or at.y <= ground+0.01*s:
		walker.feet = Vector3(at.x,ground,at.z)
		walker.toss(Vector3(_lv.x,0.0,_lv.z)*0.5)
		_off_rope()
		out["off_rope"] = true
		return out
	_base_y = y
	walker.feet = at
	walker.velocity = Vector3.ZERO
	walker.facing = PilotMotor.facing_of(toward)
	walker.ground_y = ground
	return out

## The floor under the rope at `at` (world y; far under, the room's lost).
func _floor_under(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.3*_size(),at+Vector3.DOWN*40.0,CarryHost.SOLID_MASK))
	return float(study.get("lost")) if hit.is_empty() else (hit.position as Vector3).y

## At the top: handed to the motor's own ledge hang, and its climb over the
## lip (slowed to HAUL_TIME).
func _haul(walker: PilotMotor, out: Dictionary) -> void:
	walker.release(self)
	_off_rope()
	walker.lip = Vector3(edge.x,edge.y,edge.z)
	walker.lip_out = Vector2(edge_out.x,edge_out.z)
	walker.hold = "hang"
	walker.hold_t = 0.0
	walker.feet = walker._hang_at()
	walker.velocity = Vector3.ZERO
	var ground: Variant = study.get("ground")
	_climb_time_was = walker.climb_time
	walker.climb_time = HAUL_TIME*climb_pace
	if walker._climb(ground.ground_callable(),ground.slide_callable()):
		hauling = true
		hauls += 1
		out["hauled"] = true
	else:
		walker.climb_time = _climb_time_was
		_say("No room to stand up there")

## One step rappelling: feet on the wall; stick back lowers him smoothly,
## faster the longer it's held, the feet walking (then skimming) the wall;
## let go, he stops and hangs. The stick across runs him along the face on
## the pendulum (out and back in an arc). E's hop (`tug`): crouched in,
## kicked out on the pendulum, the rope running through the brake hand till
## he meets the wall again, landed (E pressed as he comes in: straight into
## the next). Crouch slides; at the floor, off.
func _rappel_step(walker: PilotMotor, delta: float, push: float, across: float, out: Dictionary) -> Dictionary:
	var s := _size()
	var y := _base_y
	_stance_k = minf(_stance_k+delta/STANCE_IN,1.0)
	var ground := _floor_under(_stance_at(walker,y)+sway)
	if walker.crouch:
		_hop_t = -1.0
		_hop_fly = false
		_rap_v = 0.0
		y -= SLIDE_SPEED*s*delta
	elif _hop_t >= 0.0:
		if _hop_fly:
			# Off the wall: the rope runs; back on it, landed.
			if _hop_from-y < _hop_drop: y = maxf(y-HOP_FALL*s*delta/climb_pace,_hop_from-_hop_drop)
			if _on_wall() and _lv.dot(edge_out) <= 0.05*s and _hop_t >= HOP_CROUCH+0.01:
				_hop_fly = false
				_hop_t = HOP_LAND
				if _kick_buf > 0.0:
					# Into the next hop off this landing, its pace kept.
					_kick_buf = 0.0
					_hop_t = HOP_CROUCH
					_hop_fly = true
					_hop_from = y
					_hop_drop = minf(HOP_DROP*s,_hop_from-ground)
					hops += 1
					_kick(HOP_KICK*s)
				out["hopped"] = true
			else: _hop_t = minf(_hop_t+delta,HOP_LAND-0.01)
		else:
			_hop_t = minf(_hop_t+delta/(HOP_T*climb_pace),1.0)
			if _hop_t >= HOP_CROUCH and _hop_t < HOP_LAND:
				# Crouched in: kicked out.
				_hop_fly = true
				_hop_t = HOP_CROUCH+0.001
				_kick(HOP_KICK*s)
			elif _hop_t >= 1.0:
				_hop_t = -1.0
	else:
		if push < -0.35 and _stance_k > 0.6:
			_rap_held += delta
			var k := clampf(_rap_held/RAP_RAMP,0.0,1.0)
			var v := lerpf(RAP_SPEED.x,RAP_SPEED.y,k*k)*s/climb_pace
			# Quick to start, quicker as held.
			_rap_v = move_toward(_rap_v,v,8.0*s*delta)
		else:
			_rap_held = 0.0
			_rap_v = move_toward(_rap_v,0.0,RAP_SPEED.y*s/RAP_STOP*delta)
		y -= _rap_v*delta
		_step += _rap_v*delta/(RAP_STRIDE*_leg())
	# Running the face: the feet step it as he goes along.
	var run := absf(_lv.dot(_side()))
	if _on_wall(): _step += run*delta/(RAP_STRIDE*_leg())
	# The stick across runs him along it only with his feet on it.
	var pump := across*RUN_PUMP*s if _on_wall() and _stance_k > 0.6 else across*LIVE_PUMP*s*0.3
	var rub := LIVE_RUB if absf(across) < 0.3 else 0.0
	_live_step(delta,y,_rest_out(walker,y),pump,rub)
	var at := _stance_at(walker,y)+sway
	if y <= ground+0.01*s or at.y <= _floor_under(at)+0.01*s:
		walker.feet = Vector3(at.x,_floor_under(at),at.z)
		walker.toss(Vector3(_lv.x,0.0,_lv.z)*0.5)
		_off_rope()
		out["off_rope"] = true
		_say("Down. The rope stays: %s by it climbs, %s pulls it down" % [Pad.pick("Space","A"),Pad.pick("F","D-pad down")])
		return out
	_base_y = y
	walker.feet = at
	walker.velocity = Vector3.ZERO
	walker.facing = PilotMotor.facing_of(Vector2(-edge_out.x,-edge_out.z))
	walker.ground_y = ground
	return out

## Walking down the wall: how far each foot is lifted off it (0..1) and
## the share of a step (fading to a skim at speed).
func _walk_k() -> float:
	var v := maxf(_rap_v,absf(_lv.dot(_side()))*0.8 if climber and edge != Vector3.INF else 0.0)
	return clampf(1.0-(v/_size()-RAP_SKIM*0.6)/(RAP_SKIM*0.4),0.0,1.0)*clampf(v/(0.4*_size()),0.0,1.0)

## Where his feet (the motor's) stand rappelling at height `y`: out from the
## wall, the hips HIP_OUT of his leg off it, swung out mid-hop and drawn in
## crouching and landing; eased from the hang's spot as he settles.
func _stance_at(walker: Variant, y: float) -> Vector3:
	var s := _size()
	var out_d := HIP_OUT*_leg()+_hop_swing()
	var at := Vector3(edge.x+edge_out.x*out_d,y,edge.z+edge_out.z*out_d)
	return _body_at(walker,y).lerp(at,_stance_k*_stance_k*(3.0-2.0*_stance_k))

## The hop's swing off the wall (m): in a little crouching, nothing of its
## own flying (the pendulum carries him), in again landing.
func _hop_swing() -> float:
	if _hop_t < 0.0 or _hop_fly: return 0.0
	var s := _size()
	if _hop_t < HOP_CROUCH:
		var c := _hop_t/HOP_CROUCH
		return -0.2*s*c*c
	if _hop_t < HOP_LAND: return 0.0
	var w := (_hop_t-HOP_LAND)/(1.0-HOP_LAND)
	return -0.16*s*sin(PI*w)

## His leg's length (m, thigh to ankle; 0.8 m scaled without a skeleton).
func _leg() -> float:
	var sk := _skeleton()
	if sk != null:
		var a := sk.find_bone("thigh.L")
		var b := sk.find_bone("shin.L")
		var c := sk.find_bone("foot.L")
		if a >= 0 and b >= 0 and c >= 0:
			var g := sk.global_basis
			var pa := sk.get_bone_global_rest(a).origin
			var pb := sk.get_bone_global_rest(b).origin
			var pc := sk.get_bone_global_rest(c).origin
			return (g*(pb-pa)).length()+(g*(pc-pb)).length()
	return 0.8*_size()

func _off_rope() -> void:
	# The rope he leaves sways on (its end from where his grip was).
	_live_free = climber and edge != Vector3.INF
	sway = Vector3.ZERO
	_sway_tilt = Basis.IDENTITY
	_hop_fly = false
	_kick_buf = 0.0
	climber = false
	rappel = false
	_rap_v = 0.0
	_rap_held = 0.0
	_hop_t = -1.0
	guide_at = Vector3.INF
	brake_at = Vector3.INF
	_pull_t = -1.0

# --- The live rope ----------------------------------------------------------------------

## Along the face (flat, to his right as he faces it).
func _side() -> Vector3:
	return (-edge_out).cross(Vector3.UP).normalized()

## The pendulum's anchor: where the rope leaves the edge.
func _anchor() -> Vector3:
	return line_at(edge.y)

## The bag on his back (kg) and its share of the way to the climb stop.
func _kg() -> float:
	var bag: Variant = study.get("bag")
	if bag == null or not bag.has_method("worn_kg"): return 0.0
	return float(bag.worn_kg())

func _load_k() -> float:
	return clampf((_kg()-LootBag.FREE_KG)/(LootBag.CLIMB_STOP-LootBag.FREE_KG),0.0,1.0)

## Too heavy to haul himself up the rope (LootBag CLIMB_STOP).
func _too_heavy() -> bool:
	return _kg() >= LootBag.CLIMB_STOP-0.001

## The grip's least out off the anchor's plumb at `y`: hanging, none (the
## rope lies on the face); rappelling, his stance's (feet on the wall).
func _rest_out(walker: Variant, y: float) -> float:
	var at := _stance_at(walker,y)
	var a := _anchor()
	return maxf(Vector3(at.x-a.x,0.0,at.z-a.z).dot(edge_out)-(float(walker.hang_out)+BODY_OFF*_size()),0.0)

## Its still spot at length `l`, `lo` out.
func _rest(l: float, lo: float) -> Vector3:
	lo = minf(lo,l*0.9)
	return edge_out*lo+Vector3.DOWN*sqrt(maxf(l*l-lo*lo,0.0))

## Taken hold of (or lowered on): the pendulum still under the anchor, at
## his pace across the face.
func _live_begin(motor: Variant, y: float) -> void:
	var s := _size()
	_base_y = y
	_ll = maxf(edge.y-(y+float(motor.hang_drop)),0.3*s)
	_lo = 0.0
	_lp = _rest(_ll,_lo)
	var v: Vector3 = motor.velocity
	_lv = _side()*v.dot(_side())*0.5
	_live_free = false
	_kick_buf = 0.0
	_hop_fly = false
	sway = Vector3.ZERO
	_sway_tilt = Basis.IDENTITY
	sway_peak = Vector2.ZERO

## The stick's own left/right (not its up/down, the climb's) as a push
## along the face, to his right +1: as the camera sees the face.
func _across(want: Vector2) -> float:
	var f := PilotMotor.forward(float(study.get("_yaw")))
	var cam_r := Vector3(-f.y,0.0,f.x)
	return _to_cam(want).x*clampf(cam_r.dot(_side())*2.0,-1.0,1.0)

## The grip's off the wall (within a few cm of its least out).
func _on_wall() -> bool:
	return _lp.dot(edge_out) <= _lo+0.03*_size()

## A kick off the wall: `v` out, and KICK_KEEP of the pace he came in with.
func _kick(v: float) -> void:
	var vn := _lv.dot(edge_out)
	_lv += edge_out*(v-minf(vn,0.0)*(1.0+KICK_KEEP))
	kicks += 1

## One step of the pendulum with his feet at `y` (the grip HANG_DROP over
## them), `lo` out at least, `pump` (m/s², across the face: the way it
## goes once moving, as the swing's pump) and `rub` (damping a second on the
## face); `sway` and `_sway_tilt` set from it. A body swung into a face
## across his way stops there.
func _live_step(delta: float, y: float, lo: float, pump: float, rub: float) -> void:
	var s := _size()
	var motor: Variant = study.get("motor")
	var heavy := _load_k()
	var g := LIVE_G*s*(1.0-HEAVY_G*heavy)
	var l := maxf(edge.y-(y+float(motor.hang_drop)),0.3*s)
	if absf(l-_ll) > 0.0001:
		# Paid out or climbed: the angle kept, the pace by old/new.
		_lv *= clampf(_ll/l,0.5,1.5)
		_lp = _lp.normalized()*l if _lp.length() > 0.001 else _rest(l,lo)
		_ll = l
	_lo = minf(lo,l*0.9)
	var side := _side()
	var push := side*pump
	var along := _lv.dot(side)
	if absf(along) > 0.4*s: push = side*pump*(1.0 if signf(pump) == signf(along) else 0.0)
	var was := _lp
	var left := delta
	while left > 0.0:
		var dt := minf(left,1.0/120.0)
		left -= dt
		var u := _lp.normalized()
		_lv += (Vector3.DOWN*g+push)*dt
		_lv -= u*_lv.dot(u)
		var damp := LIVE_DAMP*(1.0-HEAVY_DAMP*heavy)
		if _on_wall():
			_lv -= side*_lv.dot(side)*minf(rub*dt,1.0)
			damp *= 2.0
		_lv *= maxf(1.0-damp*dt,0.0)
		_lp = (_lp+_lv*dt).normalized()*l
		# Held under the most from the plumb.
		u = _lp.normalized()
		var ang := u.angle_to(Vector3.DOWN)
		if ang > LIVE_MOST:
			var axis := Vector3.DOWN.cross(u).normalized()
			u = Vector3.DOWN.rotated(axis,LIVE_MOST)
			_lp = u*l
			var outward := axis.cross(u).normalized()
			if _lv.dot(outward) > 0.0: _lv -= outward*_lv.dot(outward)
		# The face: not in past the least out; the pace into it bounced.
		var o := _lp.dot(edge_out)
		if o < _lo:
			var flat := _lp-edge_out*o
			flat.y = 0.0
			var a2 := _lp.dot(side)
			var dn := sqrt(maxf(l*l-_lo*_lo-a2*a2,0.0))
			_lp = edge_out*_lo+side*a2+Vector3.DOWN*dn
			var vn := _lv.dot(edge_out)
			if vn < 0.0: _lv -= edge_out*vn*(1.0+WALL_BOUNCE)
		_lv -= _lp.normalized()*_lv.dot(_lp.normalized())
	var rest := _rest(l,_lo)
	var d := _lp-rest
	# Swung into a face across his way (a buttress, the block's end): held
	# where he was, the pace into it taken off.
	var chest := Vector3.UP*0.6*s
	var base := _stance_at(motor,y)
	var a := base+sway+chest
	var b := base+d+chest
	if a.distance_to(b) > 0.0001:
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b+(b-a).normalized()*0.25*s,CarryHost.SOLID_MASK))
		if not hit.is_empty():
			var n: Vector3 = hit.normal
			if absf(n.dot(edge_out)) < 0.7:
				_lp = was
				var vn := _lv.dot(n)
				if vn < 0.0: _lv -= n*vn*(1.0+WALL_BOUNCE)
				d = _lp-rest
	sway = d
	sway_peak = Vector2(maxf(sway_peak.x,absf(d.dot(side))),maxf(sway_peak.y,d.dot(edge_out)))
	var r0 := rest.normalized()
	var r1 := _lp.normalized()
	_sway_tilt = Basis(Quaternion(r0,r1)) if r0.distance_to(r1) > 0.0005 else Basis.IDENTITY

## Left hanging: its end swings on from where his grip let go, settling.
func _live_free_step(delta: float) -> void:
	if not _live_free or edge == Vector3.INF or not (state == "caught" or state == "seated"):
		_live_free = false
		return
	var s := _size()
	var a := _anchor()
	var l := maxf(a.y-_floor_under(line_at(edge.y-0.3*s))-0.05*s,0.3*s)
	if absf(l-_ll) > 0.001:
		_lp = _lp.normalized()*l if _lp.length() > 0.001 else _rest(l,0.0)
		_ll = l
	var left := delta
	while left > 0.0:
		var dt := minf(left,1.0/60.0)
		left -= dt
		_lv += Vector3.DOWN*LIVE_G*s*dt
		_lv -= _lp.normalized()*_lv.dot(_lp.normalized())
		_lv *= maxf(1.0-LIVE_FREE_DAMP*dt,0.0)
		_lp = (_lp+_lv*dt).normalized()*l
		var o := _lp.dot(edge_out)
		if o < 0.0:
			_lp -= edge_out*o
			_lp = _lp.normalized()*l
			var vn := _lv.dot(edge_out)
			if vn < 0.0: _lv -= edge_out*vn*(1.0+WALL_BOUNCE)
	if _lv.length() < 0.02*s and _lp.normalized().dot(Vector3.DOWN) > 0.9995: _live_free = false

## Where the rope runs at height `y`: down from the anchor through his grip
## (the live rope's line), else the plumb line down the face.
func rope_at(y: float) -> Vector3:
	if (climber or _live_free) and _lp.length() > 0.01 and _lp.y < -0.01:
		var a := _anchor()
		return a+_lp*((a.y-y)/-_lp.y)
	return line_at(y)

# --- Each frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if study == null or study.get("motor") == null: return
	_read_input()
	_t += delta
	if climber and study.get("motor").rider != self: _off_rope()
	_swing_cool = maxf(_swing_cool-delta,0.0)
	_tilt_left = maxf(_tilt_left-delta,0.0)
	if swinging and study.get("motor").rider != self:
		swinging = false
		swing_hold = false
	if swing_left and not swinging and _pend != null: _pend.advance(delta)
	if _live_free and not climber: _live_free_step(delta)
	climb_pace = LootBag.climb_pace_of(_kg())
	if lowering:
		var motor: Variant = study.get("motor")
		if motor.hold == "hang":
			# Hanging under the edge: onto the rope, feet to the wall.
			lowering = false
			motor.hold = ""
			rappel = true
			_mount(motor)
		elif motor.hold != "catch" and motor.hold != "lower":
			lowering = false
	if hauling and study.get("motor").hold != "climb":
		hauling = false
		study.get("motor").climb_time = _climb_time_was
		if study.get("motor").grounded: _say("Up and over")
	_cam_step(delta)
	match state:
		"aim": _aim_step(delta)
		"fly": _fly_step(delta)
		"drag": _drag_step(delta)
		"slide": _slide_step(delta)
		"fall": _fall_step(delta)
		"reel": _reel_step(delta)
		"tug": _tug_step(delta)
		"slip": _slip_step(delta)
		"pull_up": _pull_up_step(delta)
	if _aim_after and state != "fall" and state != "reel":
		_aim_after = false
		if state == "coiled" and Input.is_action_pressed(&"walk_throw") and _on_foot(): aim()
	if _swing_said and not swinging and not swing_hold and _on_foot():
		_swing_said = false
		if _line_t >= 0.0:
			_line_t = -1.0
			_line.visible = false
	if not _grit.is_empty(): _grit_step(delta)
	_arm_pose()
	_draw_rope()
	_place_hook()
	if _line_t >= 0.0:
		_line_t += delta
		_line.global_position = (study.get("motor").feet as Vector3)+Vector3.UP*2.4*_size()
		if _line_t > LINE_TIME:
			_line_t = -1.0
			_line.visible = false

## The camera eased out while he whirls and the hook flies (WHIRL_FAR,
## WHIRL_WIDE), back in after; a host with its own pull keeps it.
func _cam_step(delta: float) -> void:
	if study.has_method("_cam_pull") or study.get("cam_far") == null: return
	var want := 1.0 if state in ["aim","fly","drag"] else 0.0
	if _cam_k == 0.0 and want == 0.0: return
	_cam_k = move_toward(_cam_k,want,delta*WHIRL_EASE*(1.0 if want > 0.0 else 0.7))
	var k := _cam_k*_cam_k*(3.0-2.0*_cam_k)
	study.set("cam_far",lerpf(1.0,WHIRL_FAR,k))
	study.set("cam_wide",lerpf(0.0,WHIRL_WIDE,k))
	# Levelled toward WHIRL_POLAR (an offset on the player's own look,
	# taken off again as it eases back).
	var polar := float(study.get("_polar"))
	if _cam_k > 0.0 and want > 0.0 and _polar_lift == 0.0 and k < 0.05: _polar_room = maxf(WHIRL_POLAR-polar,0.0)
	var lift := _polar_room*k
	study.set("_polar",polar+lift-_polar_lift)
	_polar_lift = lift
	if _cam_k == 0.0:
		_polar_lift = 0.0
		_polar_room = 0.0

## Pulled up from the top: the hanging end rises to the edge, then coiled.
func _pull_up_step(delta: float) -> void:
	var motor: Variant = study.get("motor")
	var feet: Vector3 = motor.feet
	var d := Vector2(edge.x-feet.x,edge.z-feet.z)
	if d.length() > 0.2: motor.facing = PilotMotor.facing_of(d.normalized())
	_up_len -= PULL_UP*_size()*delta
	if _up_len > 0.0: return
	_coil()
	_say("Pulled it up")

func _aim_step(delta: float) -> void:
	var motor: Variant = study.get("motor")
	# Whirled on the move, through a jump or off an edge; a ledge, a rider
	# (a rope, a knock) or the water put it away.
	if motor.rider != null or motor.on_ledge() or motor.swimming:
		reset()
		return
	_turn_to_aim()
	# The right stick turns the camera faster while he whirls.
	var look := Pad.curve(Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down"),1.6)
	if look.x != 0.0 and not _busy(): study.set("_yaw",float(study.get("_yaw"))-look.x*AIM_STICK*delta)
	_aim_update(delta)
	_whirl += delta*TAU*WHIRL_RATE
	var s := _size()
	var f := _forward()
	var r := f.cross(Vector3.UP).normalized()
	var c := _hand()+Vector3.UP*0.35*s+r*0.12*s
	hook_at = c+(f*cos(_whirl)+Vector3.UP*sin(_whirl)*0.6+r*0.2)*WHIRL_R*s
	_show_aim(true)
	if not Input.is_action_pressed(&"walk_throw") and not hold_aim: release()

func _fly_step(delta: float) -> void:
	var g := _fly_g()
	_fly_t += delta
	var t := minf(_fly_t,_fly_all)
	var next := _from+_vel*t+Vector3.DOWN*0.5*g*t*t
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hook_at,next,CarryHost.SOLID_MASK))
	paid = maxf(paid,_hand().distance_to(next)*1.03)
	if _hand().distance_to(next) > ROPE_LEN*_size():
		# The rope runs out: jerked short, the hook drops.
		_vel = (_vel+Vector3.DOWN*g*t)*0.15
		misses += 1
		_clank()
		_say("The rope ran out: too far")
		state = "fall"
		return
	if not hit.is_empty() and (hit.position as Vector3).distance_to(aim_at) > 0.35*_size():
		# Knocked down on the way.
		var n: Vector3 = hit.normal
		var v := _vel+Vector3.DOWN*g*t
		hook_at = (hit.position as Vector3)+n*0.05
		_vel = v.bounce(n)*BOUNCE
		misses += 1
		_clank()
		_say("Knocked down")
		state = "fall"
		return
	hook_at = next
	if _fly_t < _fly_all: return
	_clank()
	_slide_from = hook_at
	_fly_t = 0.0
	if hold != "":
		state = "drag"
	else:
		_vel = Vector3.ZERO
		misses += 1
		if lip != Vector3.INF:
			state = "slide"
			_say("No catch: %s" % aim_why if aim_why != "" else "No catch")
		else:
			# Down on open ground.
			state = "down"
			if _reel_after:
				_reel_after = false
				state = "reel"
			else: _say("Nothing to catch on. %s reels it in" % Pad.pick("F","D-pad down"))

## Pulled taut, back to the lip, where it hooks over.
func _drag_step(delta: float) -> void:
	_fly_t += delta
	if hold == "beam" and beam_mid != Vector3.INF:
		# Over the top and round the far side, swinging down to hang.
		var w := clampf(_fly_t/WRAP_TIME,0.0,1.0)
		hook_at = _wrap_at(w)
		if w < 1.0: return
	else:
		var k := clampf(_fly_t/DRAG_TIME,0.0,1.0)
		hook_at = _slide_from.lerp(lip,k*k)
		if k < 1.0: return
	_clank()
	bad = hold == "poor" and (force_bad == 1 or (force_bad < 0 and randf() < POOR_BAD))
	if bad:
		# A crumbly lip: the hook skitters on it in grit and comes off.
		misses += 1
		slips += 1
		state = "slip"
		_slide_from = hook_at
		_fly_t = 0.0
		_spill_grit()
		_say("It skittered off the crumbly lip: throw again")
		return
	# Set at once: it holds his weight.
	state = "seated"
	catches += 1
	seats += 1
	tested = true
	paid = _hand().distance_to(lip)+0.3*_size()
	_find_edge()
	_click_play()
	if hold == "beam" and beam_mid != Vector3.INF:
		# Over a swing point the rope's in his hand: run off into the swing.
		if _take_swing(): return
	_say("Caught (%s): %s by the rope climbs" % [{"solid":"a solid lip","poor":"a crumbly lip","anchor":"a post","beam":"over the beam"}.get(hold,hold),Pad.pick("Space","A")])

## The hook wrapping a beam, `w` 0 (on its top) to 1 (hung under its far
## side): round the bar's axis, then dropping a little as it swings in.
func _wrap_at(w: float) -> Vector3:
	var s := _size()
	var r := beam_half+0.06*s
	var a := w*w*(3.0-2.0*w)*PI*0.62
	var far := -lip_out
	return beam_mid+(Vector3.UP*cos(a)+far*sin(a))*r+Vector3.DOWN*BEAM_HANG*s*w*w

## Off a smooth top: dragged to the lip and over it.
func _slide_step(delta: float) -> void:
	_fly_t += delta
	var k := clampf(_fly_t/DRAG_TIME,0.0,1.0)
	hook_at = _slide_from.lerp(lip,k*k)
	if k < 1.0: return
	_vel = lip_out*0.6*_size()
	hook_at = lip+lip_out*0.1*_size()
	state = "fall"

func _fall_step(delta: float) -> void:
	_vel += Vector3.DOWN*_gravity()*delta
	if _yank:
		var s := _size()
		var to := _hand()-hook_at
		if to.length() < COILED*s*1.5:
			_coil()
			_say("Reeled in")
			return
		# Pulled in along the rope, quicker as it comes, turned toward his
		# hand (it never circles him); nothing stops it on its way.
		var sp := _vel.length()+YANK*s*delta
		_vel = _vel.lerp(to.normalized()*sp,minf(YANK_TURN*delta,1.0))
		if _vel.length()*delta >= to.length():
			_coil()
			_say("Reeled in")
			return
		hook_at += _vel*delta
		paid = maxf(_hand().distance_to(hook_at),0.0)
		return
	var next := hook_at+_vel*delta
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hook_at+Vector3.UP*0.03,next,CarryHost.SOLID_MASK))
	paid = maxf(paid,_hand().distance_to(next))
	if hit.is_empty():
		hook_at = next
		if hook_at.y < float(study.get("lost")): _coil()
		return
	var n: Vector3 = hit.normal
	hook_at = (hit.position as Vector3)+n*0.04
	if n.y > 0.6:
		state = "down"
		_vel = Vector3.ZERO
		_clank()
		if _reel_after:
			_reel_after = false
			state = "reel"
		else:
			_say("Down. %s reels it in" % Pad.pick("F","D-pad down"))
		return
	_vel = _vel.bounce(n)*BOUNCE

## Dragged in along the ground toward his feet, over what's in the way.
func _reel_step(delta: float) -> void:
	var feet: Vector3 = study.get("motor").feet
	var s := _size()
	var to := Vector2(feet.x-hook_at.x,feet.z-hook_at.z)
	if to.length() < COILED*s and absf(feet.y-hook_at.y) < 1.5*s:
		_coil()
		_say("Reeled in")
		return
	var step := to.limit_length(REEL_SPEED*s*delta)
	var at := Vector3(hook_at.x+step.x,hook_at.y,hook_at.z+step.y)
	var space := get_world_3d().direct_space_state
	var top := maxf(hook_at.y,feet.y)+1.0*s
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,top,at.z),Vector3(at.x,at.y-20.0*s,at.z),CarryHost.SOLID_MASK))
	if not hit.is_empty(): at.y = (hit.position as Vector3).y+0.04
	hook_at = at
	paid = _hand().distance_to(hook_at)*1.05

func _coil() -> void:
	reset()

# --- The look ---------------------------------------------------------------------------

## The hook: a shank and three tines, its eye up (+Y) toward the rope.
func _hook_figure() -> Node3D:
	var root := Node3D.new()
	root.name = "Hook"
	root.top_level = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HOOK
	mat.metallic = 0.6
	mat.roughness = 0.45
	var shank := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.03
	c.height = 0.34
	c.radial_segments = 8
	shank.mesh = c
	shank.material_override = mat
	root.add_child(shank)
	var eye := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.025
	ring.outer_radius = 0.05
	ring.rings = 10
	ring.ring_segments = 6
	eye.mesh = ring
	eye.rotation = Vector3(PI*0.5,0.0,0.0)
	eye.position = Vector3(0.0,0.2,0.0)
	eye.material_override = mat
	root.add_child(eye)
	for i in 3:
		var a := TAU*float(i)/3.0
		var tine := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.022
		tm.bottom_radius = 0.012
		tm.height = 0.2
		tm.radial_segments = 6
		tine.mesh = tm
		tine.material_override = mat
		var out := Vector3(cos(a),0.0,sin(a))
		# Splayed out and curled back up.
		tine.transform = Transform3D(Basis(out.cross(Vector3.UP).normalized(),deg_to_rad(-55.0)),Vector3(0.0,-0.16,0.0)+out*0.07+Vector3.UP*0.02)
		root.add_child(tine)
	return root

func _place_hook() -> void:
	_hook.visible = state != "coiled"
	if not _hook.visible: return
	var s := _size()
	var up := Vector3.UP
	match state:
		"fly":
			var v := _vel+Vector3.DOWN*_fly_g()*_fly_t
			if v.length() > 0.1: up = -v.normalized()
		"aim":
			up = (_hand()-hook_at).normalized() if _hand().distance_to(hook_at) > 0.05 else Vector3.UP
		"caught", "drag", "tug", "seated", "slip", "pull_up":
			if hold == "beam" and beam_mid != Vector3.INF:
				# Hung on the far side, its eye up toward the bar's top.
				var to := beam_mid+Vector3.UP*beam_half-hook_at
				up = to.normalized() if to.length() > 0.05 else Vector3.UP
			elif hold == "anchor":
				var pull := _hand()-hook_at
				if fixed and state != "tug" and edge != Vector3.INF: pull = line_at(edge.y)-hook_at
				up = pull.normalized() if pull.length() > 0.05 else Vector3.UP
			else:
				# Lying on the top, its eye over the lip, tines dug in behind.
				up = (lip_out+Vector3.DOWN*0.15).normalized()
				_hook.global_transform = Transform3D(_basis_up(up)*Basis.from_scale(Vector3.ONE*s),hook_at-lip_out*0.17*s+Vector3.UP*0.05*s)
				return
		"down", "reel":
			up = (lip_out+Vector3.UP*0.2).normalized() if lip_out != Vector3.ZERO else Vector3.RIGHT
		_:
			up = (_hand()-hook_at).normalized() if _hand().distance_to(hook_at) > 0.05 else Vector3.UP
	_hook.global_transform = Transform3D(_basis_up(up)*Basis.from_scale(Vector3.ONE*s),hook_at)

## A basis whose +Y is `up`.
static func _basis_up(up: Vector3) -> Basis:
	var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x,up,x.cross(up)).orthonormalized()

## The rope from his hand to the hook's eye: sagging by its slack, lying on
## what's under it.
func _draw_rope() -> void:
	_rope.visible = state != "coiled"
	if not _rope.visible: return
	var s := _size()
	if state == "pull_up":
		var over := line_at(edge.y+ROPE_R*s)
		var low := maxf(_floor_under(line_at(edge.y-0.3*s))+ROPE_R*s,edge.y-_up_len)
		_draw_line(PackedVector3Array([hook_at,over,line_at(low)]))
		return
	if climber and rappel and guide_at != Vector3.INF:
		# Over the edge, through his lead hand and the brake at his hip, down.
		var over := line_at(edge.y+ROPE_R*s)
		var foot := _floor_under(brake_at)
		var down := Vector3(brake_at.x,foot+ROPE_R*s,brake_at.z)
		_draw_line(PackedVector3Array([hook_at,over,guide_at,brake_at,down,down+edge_out*0.5*s]))
		return
	if edge != Vector3.INF and (state == "caught" or state == "seated") and (climber or hauling or fixed or on_top()):
		_draw_hanging()
		return
	if hold == "beam" and beam_mid != Vector3.INF and state in ["caught","tug","seated","drag"]:
		_draw_over_beam()
		return
	var a := _hand()
	var b := hook_at
	var d := a.distance_to(b)
	if state == "aim": paid = d
	elif state == "caught": paid = maxf(paid,d)
	elif state == "seated": paid = d+0.02*s
	var slack := maxf(paid-d,0.0)
	var sag := sqrt(3.0*d*slack/8.0) if d > 0.01 else 0.0
	var space := get_world_3d().direct_space_state
	var pts := PackedVector3Array()
	for i in SEGS+1:
		var t := float(i)/SEGS
		var p := a.lerp(b,t)+Vector3.DOWN*4.0*sag*t*(1.0-t)
		if i > 0 and i < SEGS and sag > 0.01:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*(4.0*sag*t*(1.0-t)+0.05),p+Vector3.DOWN*0.05,CarryHost.SOLID_MASK))
			if not hit.is_empty(): p.y = (hit.position as Vector3).y+ROPE_R*s
		pts.append(p)
	var mm := _rope.multimesh
	for i in SEGS:
		var p := pts[i]
		var q := pts[i+1]
		var dir := q-p
		var l := dir.length()
		if l < 0.0001:
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),p))
			continue
		var y := dir/l
		var x := y.cross(Vector3.UP).normalized() if absf(y.y) < 0.95 else Vector3.RIGHT
		mm.set_instance_transform(i,Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(s,l+0.01,s)),(p+q)*0.5))

## The rope's length from his hand to the hook (over a beam: over its top).
func _span() -> float:
	if hold == "beam" and beam_mid != Vector3.INF and state != "fly":
		var near := beam_mid+(lip_out+Vector3.UP).normalized()*(beam_half+ROPE_R*_size())
		return _hand().distance_to(near)+near.distance_to(hook_at)
	return _hand().distance_to(hook_at)

## Over a beam: from his hand up to the bar's near side (sagging by the
## slack), round its top, and down the far side to the hook.
func _draw_over_beam() -> void:
	var s := _size()
	var r := beam_half+ROPE_R*s
	var near := beam_mid+(lip_out+Vector3.UP).normalized()*r
	var top := beam_mid+Vector3.UP*r
	var far := beam_mid+(-lip_out+Vector3.UP).normalized()*r
	if (swinging or swing_left) and _pend != null:
		# Swung on, or left hanging: from his hands (its free end) straight
		# up to the top, over, and down to the hook.
		_draw_line(PackedVector3Array([_pend.hands,top,far,hook_at]))
		return
	var a := _hand()
	var d := a.distance_to(near)
	var span := d+near.distance_to(top)+top.distance_to(far)+far.distance_to(hook_at)
	if state == "caught": paid = maxf(paid,span)
	elif state == "seated": paid = span+0.02*s
	var slack := maxf(paid-span,0.0)
	if swing_hold: slack = maxf(swing_len-a.distance_to(_swing_top()),0.0)
	var sag := sqrt(3.0*d*slack/8.0) if d > 0.01 else 0.0
	var pts := PackedVector3Array()
	for i in 13:
		var t := float(i)/12.0
		pts.append(a.lerp(near,t)+Vector3.DOWN*4.0*sag*t*(1.0-t))
	if state != "drag": pts.append_array([top,far])
	pts.append(hook_at)
	_draw_line(pts)

## Hooked and hanging free of his hand (he's on it, or up top): from the
## hook over the edge, straight down the face to the floor, a little lying
## there. Segments shared out by each leg's length, so the edge is a corner.
func _draw_hanging() -> void:
	var s := _size()
	var over := line_at(edge.y+ROPE_R*s)
	if (climber or _live_free) and _lp.length() > 0.01:
		# Live: from the edge straight to his grip (or its swinging end),
		# then on down from there to the floor.
		var grip := _anchor()+_lp
		var on := grip+_lp.normalized()*0.35*s
		var fl := _floor_under(on)+ROPE_R*s
		if on.y < fl: on.y = fl
		var low := Vector3(on.x,fl,on.z)
		_draw_line(PackedVector3Array([hook_at,over,grip,on,low,low+edge_out*0.5*s]))
		return
	var foot := line_at(_floor_under(line_at(edge.y-0.3*s))+ROPE_R*s)
	var tail := foot+edge_out*0.5*s
	var pts := PackedVector3Array([hook_at,over,foot,tail])
	_draw_line(pts)

## The rope along the polyline `pts`, its SEGS segments shared by length.
func _draw_line(pts: PackedVector3Array) -> void:
	var s := _size()
	var total := 0.0
	for i in pts.size()-1: total += pts[i].distance_to(pts[i+1])
	var line := PackedVector3Array([pts[0]])
	var left := SEGS
	for i in pts.size()-1:
		var legs := pts.size()-1-i
		var n := left-(legs-1) if legs == 1 else clampi(roundi(SEGS*pts[i].distance_to(pts[i+1])/maxf(total,0.001)),1,left-(legs-1))
		left -= n
		for j in n: line.append(pts[i].lerp(pts[i+1],float(j+1)/n))
	var mm := _rope.multimesh
	for i in SEGS:
		var p := line[i]
		var q := line[i+1]
		var dir := q-p
		var l := dir.length()
		if l < 0.0001:
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),p))
			continue
		var y := dir/l
		var x := y.cross(Vector3.UP).normalized() if absf(y.y) < 0.95 else Vector3.RIGHT
		mm.set_instance_transform(i,Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(s,l+0.01,s)),(p+q)*0.5))

## His throwing arm: up over his shoulder while whirling, flung forward as
## it flies.
func _arm_pose() -> void:
	var sk := _skeleton()
	if sk == null: return
	var arm := sk.find_bone("upper_arm.R")
	if arm < 0: return
	if swinging:
		_swing_pose(sk)
		return
	if _tilt_left > 0.0:
		# Just off the swing: eased back upright.
		var fig: Node3D = study.get("figure")
		if fig != null:
			var sc := fig.global_basis.get_scale()
			var upright := fig.global_basis.orthonormalized()
			fig.global_basis = upright.slerp(_tilt.orthonormalized(),_tilt_left/UPRIGHT)*Basis.from_scale(sc)
	var r := _forward().cross(Vector3.UP).normalized()
	if climber:
		if rappel: _rappel_pose(sk)
		else:
			# Hung along the live rope: turned about his grip.
			_tilt_figure(_anchor()+_lp,1.0)
			# Just off a rappel: its lean eases out under the climb.
			if _stance_k > 0.0: _lean_figure(sk,_stance_k*_stance_k*(3.0-2.0*_stance_k),deg_to_rad(LEAN))
			_climb_feet(sk)
			_climb_hands(sk)
		return
	if state == "tug":
		_tug_pose(sk,arm,r)
		return
	if state == "pull_up":
		# Hand over hand, the arms taking turns hauling.
		var w := sin(_t*TAU*1.4)
		CarryHost._turn_bone(sk,arm,r,deg_to_rad(70.0+45.0*w))
		var left := sk.find_bone("upper_arm.L")
		if left >= 0: CarryHost._turn_bone(sk,left,r,deg_to_rad(70.0-45.0*w))
		var chest := sk.find_bone("chest")
		if chest >= 0: CarryHost._turn_bone(sk,chest,r,deg_to_rad(10.0+6.0*w))
		return
	if hauling or on_top(): return
	match state:
		"aim":
			# Up at his side, the arm circling with the hook.
			CarryHost._turn_bone(sk,arm,r,deg_to_rad(118.0+18.0*sin(_whirl)))
			var fore := sk.find_bone("forearm.R")
			if fore >= 0: CarryHost._turn_bone(sk,fore,_forward(),deg_to_rad(22.0*cos(_whirl)))
		"fly":
			var k := clampf(_fly_t/0.15,0.0,1.0)
			CarryHost._turn_bone(sk,arm,r,deg_to_rad(lerpf(120.0,60.0,k)))
		"caught", "drag", "reel", "seated":
			CarryHost._turn_bone(sk,arm,r,deg_to_rad(45.0))

## The tug: both hands reach up the rope (leaning in), then yank it down to
## his chest (leaning back), held there; the slip throws him back a touch more.
func _tug_pose(sk: Skeleton3D, arm: int, r: Vector3) -> void:
	var up_a := 45.0
	var lean := 0.0
	if _tug_t < TUG_REACH:
		var k := _tug_t/TUG_REACH
		k = k*k*(3.0-2.0*k)
		up_a = lerpf(45.0,150.0,k)
		lean = lerpf(0.0,-14.0,k)
	elif _tug_t < TUG_REACH+TUG_YANK:
		var k := (_tug_t-TUG_REACH)/TUG_YANK
		k = 1.0-(1.0-k)*(1.0-k)
		up_a = lerpf(150.0,10.0,k)
		lean = lerpf(-14.0,26.0,k)
	else:
		var k := clampf((_tug_t-TUG_REACH-TUG_YANK)/TUG_HOLD,0.0,1.0)
		up_a = lerpf(10.0,40.0,k*k)
		lean = lerpf(26.0,4.0,k*k)
	CarryHost._turn_bone(sk,arm,r,deg_to_rad(up_a))
	var left := sk.find_bone("upper_arm.L")
	if left >= 0: CarryHost._turn_bone(sk,left,r,deg_to_rad(up_a-8.0))
	var chest := sk.find_bone("chest")
	if chest >= 0: CarryHost._turn_bone(sk,chest,r,deg_to_rad(lean))

## On the rope: each hand on it at its height (two-bone IK over the hang's
## clip), elbows out and back off the wall, the mitt closed round it.
func _climb_hands(sk: Skeleton3D) -> void:
	var s := _size()
	var fwd := -edge_out
	var right := fwd.cross(Vector3.UP).normalized()
	var to_sk := sk.global_transform.affine_inverse()
	for i in 2:
		var sd: float = _hand_side[i]
		var names := ["upper_arm.R","forearm.R","hand.R"] if sd > 0.0 else ["upper_arm.L","forearm.L","hand.L"]
		var upper := sk.find_bone(names[0])
		var fore := sk.find_bone(names[1])
		var hand := sk.find_bone(names[2])
		if upper < 0 or fore < 0 or hand < 0: return
		var at := rope_at(minf(float(_hand_y[i])+REACH_UP*s+sway.y,edge.y-0.04*s))+right*sd*HAND_SPREAD*s
		# The reaching hand comes off the rope a little as it passes.
		if i == 1 and _pull_t > REACH_AT:
			var r := (_pull_t-REACH_AT)/(1.0-REACH_AT)
			at += edge_out*sin(PI*r)*0.14*s+right*sd*sin(PI*r)*0.06*s
		var pole_w := right*sd*0.8+Vector3.DOWN*0.6+edge_out*0.5
		var pole := (sk.global_basis.inverse()*pole_w).normalized()
		CarryHost._two_bone(sk,upper,fore,hand,to_sk*at,pole,1.0)

## Climbing: the feet pressed to the wall a little over his feet, one
## higher than the other by which hand is on top, knees out.
func _climb_feet(sk: Skeleton3D) -> void:
	var motor: Variant = study.get("motor")
	var s := _size()
	var leg := _leg()
	var right := (-edge_out).cross(Vector3.UP).normalized()
	var to_sk := sk.global_transform.affine_inverse()
	var to_sk_b := sk.global_basis.inverse()
	var y0 := (motor.feet as Vector3).y+FOOT_UP*leg
	if hauling or (motor.feet as Vector3).y > edge.y-float(motor.hang_drop)-0.2*s: return
	# Swung off the wall, the feet come off it, reaching back for it.
	var off := sway.dot(edge_out)
	var w := CLIMB_FEET*(1.0-smoothstep(0.08*s,0.5*s,off))
	for sd: float in [1.0,-1.0]:
		var side := "R" if sd > 0.0 else "L"
		var a := sk.find_bone("thigh."+side)
		var b := sk.find_bone("shin."+side)
		var c := sk.find_bone("foot."+side)
		if a < 0 or b < 0 or c < 0: continue
		var up := 0.18*leg if sd == float(_hand_side[0]) else 0.0
		var goal := Vector3(edge.x,y0+up,edge.z)+edge_out*(0.06*s+off*0.5)+right*(sd*0.14*s+sway.dot(right))
		var pole := (to_sk_b*(Vector3.UP*0.8-edge_out*0.5+right*sd*0.4)).normalized()
		if w > 0.01: CarryHost._two_bone(sk,a,b,c,to_sk*goal,pole,w)

## The figure leaned back `lean` (rad) times `k` about its hips, the hips set
## over the motor's feet (up his leg as `k` grows); the hips' world spot.
func _lean_figure(sk: Skeleton3D, k: float, lean: float) -> Vector3:
	var fig: Node3D = study.get("figure")
	var motor: Variant = study.get("motor")
	var hips := sk.find_bone("hips")
	if fig == null or hips < 0: return Vector3.INF
	var hip_w := sk.global_transform*sk.get_bone_global_pose(hips).origin
	var hip_up := hip_w.y-fig.global_position.y
	var tilt := Basis(Vector3.UP.cross(edge_out).normalized(),lean*k)
	var want_hip := (motor.feet as Vector3)+Vector3.UP*lerpf(hip_up,_leg()*0.95,k)
	fig.global_basis = tilt*fig.global_basis
	hip_w = sk.global_transform*sk.get_bone_global_pose(hips).origin
	fig.global_position += want_hip-hip_w
	return want_hip

## The figure turned by the live rope's tilt (`k` of it) about `pivot`.
func _tilt_figure(pivot: Vector3, k: float) -> void:
	var fig: Node3D = study.get("figure")
	if fig == null or _sway_tilt == Basis.IDENTITY: return
	var r := Basis.IDENTITY.slerp(_sway_tilt,k) if k < 1.0 else _sway_tilt
	var xf := fig.global_transform
	fig.global_transform = Transform3D(r*xf.basis,pivot+r*(xf.origin-pivot))

## Rappelling: the figure (in the hang's clip) leaned back off the wall
## about its hips, set where the stance puts them; legs (two-bone IK) to
## the wall, knees up, walking down it as he lowers (each foot lifting in
## turn, skimming at speed); the lead hand up the rope before his chest,
## the brake hand at his hip. Eased in by `_stance_k` from the hang.
func _rappel_pose(sk: Skeleton3D) -> void:
	var hips := sk.find_bone("hips")
	if hips < 0: return
	var s := _size()
	var k := _stance_k*_stance_k*(3.0-2.0*_stance_k)
	var leg := _leg()
	var right := (-edge_out).cross(Vector3.UP).normalized()
	var lean := deg_to_rad(LEAN)
	# Out off the wall he opens up, sitting back further.
	var off := sway.dot(edge_out)
	lean += deg_to_rad(10.0)*clampf(off/(0.8*s),0.0,1.0)
	# Faster, he sits back further into it.
	lean += deg_to_rad(6.0)*clampf(_rap_v/(RAP_SPEED.y*s),0.0,1.0)
	var want_hip := _lean_figure(sk,k,lean)
	if want_hip == Vector3.INF: return
	# The live rope's tilt, about his hips (his feet keep to the wall).
	_tilt_figure(want_hip,0.7)
	var to_sk := sk.global_transform.affine_inverse()
	var to_sk_b := sk.global_basis.inverse()
	# Feet on the wall under the hips, walking down it.
	var wall_y := want_hip.y-FOOT_DOWN*leg
	var walk := _walk_k()
	for sd: float in [1.0,-1.0]:
		var side := "R" if sd > 0.0 else "L"
		var a := sk.find_bone("thigh."+side)
		var b := sk.find_bone("shin."+side)
		var c := sk.find_bone("foot."+side)
		if a < 0 or b < 0 or c < 0: continue
		var ph := _step*PI+(0.0 if sd > 0.0 else PI)
		var lift := maxf(sin(ph),0.0)*walk
		var goal := Vector3(edge.x,wall_y-cos(ph)*0.2*leg*walk,edge.z)+edge_out*(0.06*s+lift*RAP_LIFT*leg+maxf(off,0.0)*0.55)+right*(sd*0.13*s+sway.dot(right))
		var pole := (to_sk_b*(Vector3.UP*0.8-edge_out*0.6+right*sd*0.2)).normalized()
		CarryHost._two_bone(sk,a,b,c,to_sk*goal,pole,k)
	# The hands: the lead up the rope before his chest, the brake at the hip.
	var chest := sk.find_bone("chest")
	var chest_w := sk.global_transform*sk.get_bone_global_pose(chest if chest >= 0 else hips).origin
	var hip_w := sk.global_transform*sk.get_bone_global_pose(hips).origin
	guide_at = chest_w-edge_out*0.3*s+Vector3.UP*0.12*s
	brake_at = hip_w+right*0.22*s+edge_out*0.12*s-Vector3.UP*0.04*s
	var arms := [["upper_arm.L","forearm.L","hand.L",guide_at,-right*0.7+Vector3.DOWN*0.7],
		["upper_arm.R","forearm.R","hand.R",brake_at,right*0.7+Vector3.DOWN*0.3+edge_out*0.5]]
	for arm: Array in arms:
		var u := sk.find_bone(arm[0])
		var f := sk.find_bone(arm[1])
		var h := sk.find_bone(arm[2])
		if u < 0 or f < 0 or h < 0: continue
		CarryHost._two_bone(sk,u,f,h,to_sk*(arm[3] as Vector3),(to_sk_b*(arm[4] as Vector3)).normalized(),1.0)

## The reticle (a ring at the target) and the arc's dots, gold or red.
func _show_aim(on: bool) -> void:
	_reticle.visible = on
	_dots.visible = on
	if not on: return
	var colour := (AIM_POOR if aim_hold == "poor" else AIM_OK) if aim_ok else AIM_BAD
	_reticle_mat.albedo_color = Color(colour,0.85)
	_dots_mat.albedo_color = Color(colour,0.55)
	var s := _size()
	var pulse := 1.0+0.08*sin(Time.get_ticks_msec()*0.008)
	var ring := (0.35 if aim_hold == "anchor" else 0.45)*s*pulse
	var at := aim_lip if aim_lip != Vector3.INF else aim_at
	_reticle.global_transform = Transform3D(Basis.from_scale(Vector3(ring,1.0,ring)),at+Vector3.UP*0.06*s)
	var mm := _dots.multimesh
	mm.visible_instance_count = mini(aim_arc.size(),mm.instance_count)
	for i in mm.visible_instance_count:
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*s),aim_arc[i]))

func _clank() -> void:
	_clink.global_position = hook_at
	_clink.pitch_scale = randf_range(0.9,1.15)
	_clink.play()

## A short metal clink, made up.
static func _clink_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*0.18)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in n:
		var t := float(i)/rate
		var v := (sin(TAU*2400.0*t)*0.5+sin(TAU*3700.0*t)*0.3+sin(TAU*1300.0*t)*0.2)*exp(-t*28.0)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _click_play() -> void:
	_click.global_position = hook_at
	_click.play()

## The seat: a sharp, dry double click, made up.
static func _click_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*0.14)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in n:
		var t := float(i)/rate
		var v := 0.0
		for at: float in [0.0,0.055]:
			if t >= at:
				var u := t-at
				v += (sin(TAU*4200.0*u)*0.6+sin(TAU*1900.0*u)*0.4)*exp(-u*90.0)
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*22000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

func _say(text: String) -> void:
	_swing_said = false
	_line.text = text
	_line.visible = true
	_line_t = 0.0

# --- Helpers ----------------------------------------------------------------------------

func _size() -> float:
	return float(study.get("motor").size)

func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))*HOOK_G

## The thrown hook's flight: the same arc as under `_gravity`, flown
## FLY_PACE times as fast.
func _fly_g() -> float:
	return _gravity()*FLY_PACE*FLY_PACE

## The arc from `from` to `to` over a top AIM_RISE (plus AIM_RISE_M a metre
## across) above the higher end, times `rise_k` (flatter at a run).
func _arc_to(from: Vector3, to: Vector3, rise_k := 1.0) -> Vector3:
	var g := _fly_g()
	var s := _size()
	var flat := Vector3(to.x-from.x,0.0,to.z-from.z)
	var top := maxf(from.y,to.y)+(AIM_RISE*s+AIM_RISE_M*flat.length())*rise_k
	var up := sqrt(2.0*g*(top-from.y))
	var t := up/g+sqrt(2.0*g*(top-to.y))/g
	return flat/t+Vector3.UP*up

func _flight_time(from: Vector3, to: Vector3, v: Vector3) -> float:
	var g := _fly_g()
	var top := from.y+v.y*v.y/(2.0*g)
	return v.y/g+sqrt(2.0*maxf(top-to.y,0.0)/g)

func _to_cam(v: Vector2) -> Vector2:
	var f := PilotMotor.forward(float(study.get("_yaw")))
	var r := Vector2(-f.y,f.x)
	return Vector2(v.dot(r),v.dot(f))

func _from_cam(v: Vector2) -> Vector2:
	var f := PilotMotor.forward(float(study.get("_yaw")))
	var r := Vector2(-f.y,f.x)
	return r*v.x+f*v.y

func _forward() -> Vector3:
	var fig: Node3D = study.get("figure")
	if fig == null: return Vector3.FORWARD
	var f := -fig.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

func _skeleton() -> Skeleton3D:
	var body: Node = study.get("body")
	return null if body == null else body.get("_skeleton") as Skeleton3D

## His right hand (or near his hip).
func _hand() -> Vector3:
	var sk := _skeleton()
	if sk != null:
		for b: String in ["hand.R","forearm.R"]:
			var i := sk.find_bone(b)
			if i >= 0: return sk.global_transform*sk.get_bone_global_pose(i).origin
	var motor: Variant = study.get("motor")
	return (motor.feet as Vector3)+Vector3.UP*0.9*_size()
