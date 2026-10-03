extends Node
## The hand's reach (docs/scenic/hand-world.md, docs/scenic/hand-sun-rim.md):
## what the pointer is reaching for, and holding it. Where you reach is what
## you touch: the sun's disc in the sky (or the moon's, by night) and the rim
## of the diorama, the top edge of its earth block, belong to the hand; the
## land and empty space stay the camera's and the brushes'. A press on
## something the hand can hold is taken here, in `_input`, before the camera's
## orbit and the creation brushes see it.
##
## - **The sun.** Dragged along its arc it sets the hour: the disc follows the
##   pointer to the nearest point of its own arc, so a drag anywhere reads.
##   Let go and it drifts on a little, slowing. Then the hour is held (pinned
##   through scripts/mood_look.gd as a held hour, the way the old scrubber
##   pinned one), or on a day that was turning, the day turns on from there.
##   By night the moon rides the same ring, half a day round, and is held the
##   same way.
## - **The rim.** Dragged along the rim, round the diorama, it turns the
##   season: a full turn is a year, a side of the plate about a season, with
##   gentle detents at the four seasons (Living.SEASONS, mid-season values).
##   The season follows live through the world clock, so the leaves and the
##   snow line follow it; let go and it settles into the nearest detent, which
##   is pinned through mood_look as the drawer's Season would be.
##
## The mouse drives and the hand interprets: nothing here recognises a gesture.
## The hand (scripts/god_hand.gd) shows the hold, through its `reach_gesture`
## and `reach_point`; it may be absent (`--no-hand`) and the reach works the
## same. A hint line names what the pointer is near, until it has been used a
## couple of times.
##
## **Modeless** (`--modeless`, docs/scenic/modeless.md). The sun no longer
## grabs and the rim no longer dials the season. A rim press is read from its
## first few pixels: sideways turns the world (scripts/world_turn.gd, held by
## the rim's edge; a fast spin winds time, scripts/spin_time.gd, unless Shift
## was held), up lifts the block (the `flip_*` signals, scripts/diorama_flip.gd,
## which decides at the release between a basin, a toss and the flip), down
## dips it for the edge spring (the `edge_spring_*` signals,
## scripts/edge_spring.gd), and a shake takes over from any of them. While a
## tossed block is in the air a press catches it (`_catch_toss`). A left
## press on the land is left free: it emits the `land_*` signals for the
## spring slice and no brush or turn sees it. The hand
## shows the zone on hover: the rim grip over the rim, a ready pinch over land.
## Anywhere else in the world is the void: a still hold there calls the cloud
## (scripts/sky_cloud.gd, docs/scenic/sky-cloud.md "Summoned") and a drag is
## the sky's wind (scripts/sky_wind.gd). Day and night are the almanac's Time
## pocket; with `--void-snap` the hand floats ready on the pointer's ray, a
## click there snaps day to night (scripts/void_snap.gd) and Shift-click steps
## the golden hours. The hover stands the hand down while the camera moves
## (`camera_moving`).
##
## The rim's grab is shared with the snow-globe shake (another slice): it
## listens to `rim_dragged`, and when a shake fires it calls
## `revert_season_to_grab` so the dial goes back to where it was taken.

const Living = preload("res://scripts/living_weather.gd")

signal rim_grabbed(screen_pos: Vector2)
signal rim_dragged(screen_delta: Vector2, delta: float)
signal rim_released()
## Modeless only. A rim drag decided to be the flip (mostly vertical), how far
## over the lip it has been taken (0..1), and its release with the progress at
## the moment. A shake that takes the rim over ends it with `flip_released(0.0)`.
signal flip_began(screen_pos: Vector2)
signal flip_dragged(progress: float)
signal flip_released(progress: float)
## Modeless only. A rim drag decided to be the edge spring (mostly vertical,
## downward): the press, the pointer as it moves, and the let-go. A shake that
## takes the rim over ends it with a release at the press, so nothing is kept.
signal edge_spring_began(screen_pos: Vector2)
signal edge_spring_dragged(screen_pos: Vector2, relative: Vector2)
signal edge_spring_released(screen_pos: Vector2)
## Modeless only. A left press on the land, its drag (pointer, and the
## motion since the last event) and its release. Nothing else sees these
## presses; a prop or a resident under the pointer keeps its own grab
## instead, and so does a tree unless a shaping tool is in hand (`shaping`).
signal land_pressed(screen_pos: Vector2)
signal land_dragged(screen_pos: Vector2, relative: Vector2)
signal land_released(screen_pos: Vector2)
## The hand took hold of "sun" or "rim", or let go ("").
signal holding_changed(what: String)

## Half the plate's side, metres (the terrain is 28 m square, centred).
const PLATE_HALF := 14.0
## The sun's disc is small (about 2 degrees), so it is grabbed generously:
## within this many pixels of its centre, or this many degrees of it.
const SUN_PIXELS := 64.0
const SUN_DEGREES := 7.0
## A body this far under the horizon (the sine of its height) is not in reach.
const SUN_LOW := -0.05
## The rim is in reach within this many pixels of its outline on screen, over
## the land's border band RIM_BAND metres deep, or over the block's walls.
const RIM_PIXELS := 28.0
const RIM_BAND := 0.8
## A hand on the block's walls lays its palm on the faceted earth sides, which
## bulge up to about 0.45 m past the plate: it stands WALL_GAP out from the
## outermost of them round the palm (WALL_SPAN metres either side along the
## wall, from WALL_BELOW under the point to WALL_ABOVE over it, where the
## fingers reach; `_wall_face`), or WALL_OUT out from the plate where the sides
## are not there to read.
const WALL_OUT := 0.5
const WALL_GAP := 0.04
const WALL_SPAN := 1.2
const WALL_BELOW := 0.8
const WALL_ABOVE := 1.8
## Metres from the camera, along the ray to the sun, the hand holds it: about
## where the Reach clips' cup is the size of the disc on screen.
const SUN_REACH := 12.0
## Searching the arc for the pointer: phase either side of the current one,
## and the steps of the coarse and fine passes.
const ARC_WINDOW := 0.12
const ARC_STEP := 0.004
const ARC_FINE := 0.0004
## Letting the sun go: it drifts on at the speed it was dragged (phase per
## second, at most DRIFT_MAX, about 1.2 hours a second), slowing at
## DRIFT_FRICTION (1/s), and comes to rest under DRIFT_STOP.
const DRIFT_MAX := 0.05
const DRIFT_FRICTION := 2.6
const DRIFT_STOP := 0.0015
## How quickly (1/s) the drag's speed is read, for the drift.
const SPEED_READ := 14.0
## The season dial: quarters (seasons) a full turn of the rim, how strongly
## the dial sticks at each season's detent (0 none, under 1), and how quickly
## (1/s) it settles into the nearest detent once let go.
const QUARTERS_PER_TURN := 4.0
const DETENT := 0.6
const SETTLE := 7.0
const SETTLED := 0.002
## The hint line, one short verb a zone, and when it goes quiet: after
## HINT_UNTIL uses of the zone's verb, or once it has been read HOVER_UNTIL
## times (a hover that showed it at least HOVER_READ seconds). Per session.
const SUN_HINT := "Drag the sun"
const MOON_HINT := "Drag the moon"
const RIM_HINT := "Drag the rim to turn the season"
const RIM_HINT_MODELESS := "Push the rim to turn the seasons"
const HINT_UNTIL := 1
const HOVER_UNTIL := 3
const HOVER_READ := 1.0
## Seconds a refusal's line (`notice`: why the land would not take what the
## hand set) holds the hint line before the hover may speak over it.
const NOTICE_SECONDS := 3.0

var scene: Node3D
## What the pointer is over now ("sun", "rim" or ""), and what the hand holds.
var reaching := ""
var holding := ""
## Holding the sky: "sun" or "moon".
var body := "sun"
## The sun's speed along its arc (phase per second), read while it is dragged
## and carried on after a let-go, and whether it is drifting now.
var phase_speed := 0.0
var drifting := false
## The season dial, in quarters (0 spring's detent, 1 summer's...), unwrapped,
## and whether it is settling into a detent after a let-go.
var dial := 0.0
var settling := false
## What the rim's grab took: the dial, the clock's season override and the
## season pin, for `revert_season_to_grab`.
var grab_dial := 0.0
var grab_season_override := -1.0
var grab_season_pin := ""
## Where the hand works (plate coordinates), for scripts/god_hand.gd.
var reach_point: Variant = null
## Times each thing has been held, for the hint.
var uses := {"sun":0,"rim":0}
## Times each zone's hint has been read on a hover (`_read_hint`), the zone
## whose hint shows now and since when (`_hint_clock`, seconds of frames).
var hint_reads := {}
var _hint_zone := ""
var _hint_since := 0.0
var _hint_clock := 0.0
var _offset := Vector2.ZERO
var _last_phase := 0.0
var _turning := false
var _rim_angle: Variant = null
var _hint := ""
## The notice on the hint line, the seconds it has left, and what was in hand
## when it was given (`notice`).
var _notice := ""
var _notice_left := 0.0
var _notice_held := ""
var _cursor_owned := false
var _block_low: Variant = null
## The earth sides' triangles (corners in threes) in plate coordinates, and the
## mesh and placing they were read from.
var _skirt_points := PackedVector3Array()
var _skirt_read: Array = []
var _hover_key := []
var _land_cache := {}
var _land_frame := -1
## A shake undid this hold's turn: the let-go leaves the season as it was.
var _reverted := false
## `--modeless`: what the pointer is over ("rim", "land" or ""), the plate
## point it names for the hand, what a rim hold has made of its drag ("" while
## undecided, "turn", "flip", "spring" or "shake"), where the press was, the rim's global
## edge point the turn holds, and the gesture the hover set on the hand.
var modeless := Modeless.enabled()
var hover_zone := ""
var rim_intent := ""
var _hover_point: Variant = null
var _press_pos := Vector2.ZERO
var _grab_global: Variant = null
## The rim point the press took (plate coordinates); the hand's point moves
## with the pointer, the turn's grab does not.
var _press_edge := Vector3.ZERO
var _hover_shown := ""
## Shift was held at the rim's press: a turn from it winds no time.
var _press_shift := false
## When the rim last moved (µs), for the shake's speeds.
var _last_drag := 0
## The hand's gestures this reach sets, and so may clear.
const GESTURES := ["sun","rim"]
const Modeless = preload("res://scripts/modeless_input.gd")
const VoidSnap = preload("res://scripts/void_snap.gd")
const SnapSound = preload("res://scripts/snap_sound.gd")
## The void (docs/scenic/modeless.md "Void slice"): where the pointer reaches
## no land, rim or wall, the hand floats along the pointer's ray VOID_DEPTH of
## the camera's distance to its pivot out (about the size it has over the
## middle of the land), and never nearer than VOID_NEAR metres. A press there
## that moves under CLICK_PIXELS before its release is a click: a snap, with
## `--void-snap` (VOID_HINT is the snap's hint).
const VOID_DEPTH := 0.8
const VOID_NEAR := 5.0
const CLICK_PIXELS := 6.0
const VOID_HINT := "Click the sky for night or day"
## The sky's cloud (scripts/sky_cloud.gd, docs/scenic/sky-cloud.md): water's
## source. Its hints, over it and when it is pulled dry.
const CLOUD_HINT := "Pull the cloud for water"
const CLOUD_DRY_HINT := "Wrung dry for now"
## Summoned (docs/scenic/sky-cloud.md "Summoned"): with no cloud up, a press
## held still in the void (under CLICK_PIXELS) SUMMON_HOLD seconds calls the
## cloud into the hand's pinch; quicker clicks do nothing (or snap, with
## `--void-snap`), and a press that moves first is still the wind. With a cloud
## up, the void is the wind's only (and the snap's): the cloud is taken only by a press on it. The hand cups while it forms and pinches once it has formed, or once
## the pull passes PINCH_TENSION. The void's hint names the summon, until it
## has been used SUMMON_HINT_UNTIL times or read SUMMON_READS times (with
## `--void-snap`, after the demo cloud has shown or once the snap's hint is done).
const SUMMON_HOLD := 0.35
const PINCH_TENSION := 0.08
const SUMMON_HINT := "Hold in the sky to call a cloud"
const SUMMON_HINT_UNTIL := 2
const SUMMON_READS := 5
## A grown tree bent and let go (docs/scenic/sky-cloud.md "Seeds") flicks its
## spores out the way it whips, if it was bent at least FLICK_MIN of the way
## over: they land FLICK_REACH m out (a small tug to a full bend), a veil
## TREE_STRENGTH times the forest brush's at a full bend, that grows the
## tree's own kind. Then it rests TREE_REST seconds.
const FLICK_MIN := 0.3
const FLICK_REACH := Vector2(2.5,9.0)
const TREE_STRENGTH := 1.8
const TREE_REST := 45.0
const TREE_HINT := "Bend it and let go"
const TREE_RESTING_HINT := "Resting"
## Tree kinds emergence can grow from spores; others (a snag, Bigfoot's tree)
## leave the kind to the stand.
const SPORE_KINDS := ["tree","layered_tree","broadleaf","redwood","birch","willow","juniper"]
## Plucking (`pluck`): a Shift-press where a plain press would bend a tree
## pulls up the plant under it, one of PLUCK_TREES (a snag too, but never
## Bigfoot's tree) or PLUCK_UNDERGROWTH (a shrub, fern, flower, reeds, a tuft
## or a mushroom). Logs, stumps, rocks and the falls are not plants and stay.
## Pinned plants pluck too: a pin keeps a plant from the world's own changes
## (emergence, sliding, a clearing brush), not from the hand, and one undo
## puts any plucked plant back.
const PLUCK_TREES := ["tree","layered_tree","redwood","broadleaf","snag","birch","willow","juniper","joshua","cactus"]
const PLUCK_UNDERGROWTH := ["fern","shrub","reeds","bank_grass","grass_tuft","flower","button_flower","spike_flower","umbel_flower","daisy_flower","oxeye_daisy","buttercup","dandelion","dandelion_clock","cosmos","sunflower","poppy","lupine","wheat","mushroom"]
## Undergrowth has no pick of its own (world play registers only trees and
## props): with no tree's mesh under the pointer, the plant whose root stands
## nearest the ground under it, within PLUCK_REACH m, is the one taken.
const PLUCK_REACH := 0.5
## The ground left where a plant came up: the cover cells within PLUCK_BARE m
## of its root (and the one under it) turn hand-made, so emergence plants
## nothing there again; an emerged plant's cells also drop to the forest
## brush's CLEAR_BELOW wish, as a firm clearing pass leaves them.
const PLUCK_BARE := 0.5
## The pluck, played on a copy of the plant (`_pop`) over PLUCK_SECONDS (a
## tree; undergrowth takes PLUCK_SMALL of it), in four beats as shares of it:
## - grip, to PLUCK_GRIP: the plant shivers and settles a little into the
##   ground, more and faster as the pull builds;
## - rip, to PLUCK_RIP: it snaps up stretched, its root clod tears out with
##   it and PLUCK_BITS crumbs of soil and leaf burst from the hole;
## - dangle, to PLUCK_AWAY: it rises PLUCK_LIFT m (half for undergrowth),
##   swinging under the hand like a pendulum that settles, shedding
##   PLUCK_LEAVES leaves that drift down;
## - away: a last flick up and it shrinks out.
## The hole it leaves darkens the ground and fades over PLUCK_HOLE seconds.
const PLUCK_LIFT := 1.1
const PLUCK_SECONDS := 1.35
const PLUCK_SMALL := 0.65
const PLUCK_GRIP := 0.22
const PLUCK_RIP := 0.3
const PLUCK_AWAY := 0.8
const PLUCK_BITS := 22
const PLUCK_LEAVES := 10
const PLUCK_HOLE := 2.5
const PLUCK_SOIL := Color(0.36,0.26,0.17)
const PLUCK_LEAF := Color(0.42,0.55,0.26)
const SkyCloud = preload("res://scripts/sky_cloud.gd")
const TreeOutline = preload("res://scripts/tree_outline.gd")
const SkyWind = preload("res://scripts/sky_wind.gd")
## The camera counts as moving (the hand stands down) while its view turns or
## zooms faster than CAMERA_TURNING (rad/s, or log-distance/s) or its pivot
## slides faster than CAMERA_SLIDING m/s, besides a right drag.
const CAMERA_TURNING := 0.05
const CAMERA_SLIDING := 0.15
## The void's press: how far it has wandered, and the snaps made (for probes).
var _void_travel := 0.0
var snaps := 0
## `--void-snap`: a click in the void snaps day to night (scripts/void_snap.gd).
var sky_snap := VoidSnap.enabled()
## The snap's sound (scripts/snap_sound.gd), made in setup under --modeless
## with `--void-snap`.
var snap_sound: SnapSound
## The sky's cloud, made in setup under --modeless, and the one in hand (or
## under the pointer).
var cloud: SkyCloud
var _source: SkyCloud
## Seconds the void's press has been held, the pointer it last had, and
## whether a summoned cloud's hand has closed its pinch yet.
var _void_held := 0.0
var _void_last := Vector2.ZERO
var _pinched := true
## The golden outline round the tree under the pointer (scripts/tree_outline.gd),
## made in setup under --modeless.
var outline: TreeOutline
## The wind in the sky (scripts/sky_wind.gd): a void drag's gust or held wind.
var wind: SkyWind
## Trees' spores: when each tree (world play's object id) last gave them
## (msec), and the flicks that threw them, for probes.
var _tree_given := {}
var tree_spores := 0
## The tree in hand (a PlaySpringTree world play promoted), its object id, the
## level plane it is pulled on and where the pull began; and trees let go and
## still springing (object id to tree), stepped here while world play is
## paused (it is whenever the editor is active, which it always is under the
## hand). World play frees its promoted trees whenever the world's objects
## change (`invalidate`, as each emerged plant arrives), so each tree's spring
## is kept here (`_tree_springs`) and carried onto the tree promoted again.
var _tree: Node3D
var _tree_id := -1
var _tree_plane := Plane()
var _tree_origin := Vector3.ZERO
var _springing := {}
var _tree_springs := {}
const SPRING_STATE := ["bend","velocity","crown","crown_velocity","tip","tip_velocity"]
## Plants plucked so far (for probes), and the outlined undergrowth's parts
## read for an object id at an objects revision ([id, revision, parts]).
var plucked := 0
var _plant_outline := []
## Headless probes have no pointer: where they say it is, for the hover.
var pointer_override: Variant = null
## The materials tray (scripts/hand_materials.gd, an experiment): the field
## case of specimens; made in setup under --modeless unless --no-tray. It sees
## a free press first and holds "jar" (a press on a specimen) or "scatter"
## (setting stones, flowers or reeds).
const HandMaterials = preload("res://scripts/hand_materials.gd")
var materials: HandMaterials
## The faint ground mark of what is in hand (scripts/ground_marks.gd), made
## with the tray.
const GroundMarks = preload("res://scripts/ground_marks.gd")
var marks: GroundMarks
## Trees thin round the pointer while a shaping tool works the land
## (scripts/shaping_reveal.gd), made in setup under --modeless.
const ShapingReveal = preload("res://scripts/shaping_reveal.gd")
var reveal: ShapingReveal
signal snapped(phase: float, step: bool)

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "HandReach"
	# Last among the scene's children, so its `_input` comes before theirs.
	scene.move_child.call_deferred(self,-1)
	# The snap's sound loads here, so the first snap does not wait on it.
	if modeless:
		if sky_snap:
			snap_sound = SnapSound.new()
			add_child(snap_sound)
		cloud = SkyCloud.new()
		add_child(cloud)
		cloud.setup(scene)
		outline = TreeOutline.new()
		add_child(outline)
		reveal = ShapingReveal.new()
		wind = SkyWind.new(scene)
		if HandMaterials.enabled():
			materials = HandMaterials.new()
			add_child(materials)
			materials.setup(scene,self)
			marks = GroundMarks.new()
			add_child(marks)
			marks.setup(scene,self)

# --- What the pointer reaches --------------------------------------------------

func _editor() -> Node:
	return scene.get("_chunk_editor")

func _mood() -> Node:
	return scene.get("mood_look")

## True when the hand may reach at all: a world is open and nothing else owns
## the pointer (a menu, Craft, a regrowth, a forming world, a stroke).
func available() -> bool:
	var editor := _editor()
	if editor == null or scene.camera == null or editor.forming: return false
	if scene.get("crafting") == true: return false
	if scene.get("_has_world") == false: return false
	# The main menu over a world takes the clicks.
	var menu: Control = scene.get("_menu")
	if menu != null and menu.visible: return false
	var photo: Node = scene.get("photo")
	if photo != null and photo.get("active") == true: return false
	var wanderer: Node = scene.get("wanderer")
	if wanderer != null and wanderer.get("active") == true: return false
	var mood := _mood()
	if mood != null and mood.busy(): return false
	return not (editor.get("_painting") == true or editor.get("_ball_holding") == true or editor.get("_handful_holding") == true or (editor.get("gust") != null and editor.gust.aiming()))

## What a pointer at `point` reaches: "sun", "rim" or "". The sky's body
## wins where both are near; land under the pointer (but for its border band)
## is the camera's.
func reach_at(point: Vector2) -> String:
	var editor := _editor()
	if not editor.pointer_in_world(point): return ""
	if not modeless and not _body_at(point).is_empty(): return "sun"
	if _rim_at(point) != null: return "rim"
	return ""

## The body ("sun" or "moon") whose disc is within grabbing reach of `point`,
## the nearer if both; "" when neither.
func _body_at(point: Vector2) -> String:
	var best := ""
	var gap := INF
	for which in ["sun","moon"]:
		var direction := body_direction(which,float(scene._celestial.phase))
		if direction.y < SUN_LOW: continue
		var at: Variant = _screen(direction)
		if at == null: continue
		var pixels: float = point.distance_to(at)
		var ray: Vector3 = scene.camera.project_ray_normal(point)
		if pixels > SUN_PIXELS and rad_to_deg(ray.angle_to(direction)) > SUN_DEGREES: continue
		# A disc behind the land is hidden by it: the land is the camera's.
		if pixels > SUN_PIXELS*0.5 and _land(point) != null: continue
		if pixels < gap:
			gap = pixels
			best = which
	return best

## The sun's or the moon's direction at a phase, as studies/celestial.gd
## rings them: the moon half a day round less its month, on a flatter ring.
func body_direction(which: String, at_phase: float) -> Vector3:
	var celestial: RefCounted = scene._celestial
	var theta := (at_phase-0.25)*TAU
	if which == "moon": return celestial.moon_direction(at_phase)
	return celestial._ring_direction(theta,celestial._tilt)

## Where a sky direction is on screen, or null behind the camera.
func _screen(direction: Vector3) -> Variant:
	var camera: Camera3D = scene.camera
	var far := camera.global_position+direction*400.0
	if camera.is_position_behind(far): return null
	return camera.unproject_position(far)

## The rim point (plate coordinates) a pointer at `point` reaches, or null.
## The block's walls are all rim: a pointer on one reaches the very point it
## is over, unless a hill stands in front. Otherwise it is found on the plane
## of the rim's height and the rim's outline on screen, which are cheap; only
## a candidate asks the land (a ray into the terrain, about a millisecond)
## whether a hill stands in front.
func _rim_at(point: Vector2) -> Variant:
	var hit: Variant = _land(point)
	var wall: Variant = _wall_hit(point)
	if wall != null and (hit == null or _eye_distance(point,hit) > _eye_distance(point,wall)-0.05): return wall
	var rim: Variant = null
	var at: Variant = _plate_at(point)
	if at != null and absf(at.x) <= PLATE_HALF and absf(at.z) <= PLATE_HALF:
		if maxf(absf(at.x),absf(at.z)) < PLATE_HALF-RIM_BAND: return null
		rim = _edge(Vector2(at.x,at.z))
	else:
		var near: Array = _outline_nearest(point)
		if float(near[0]) > RIM_PIXELS: return null
		rim = near[1]
	if hit != null and maxf(absf(hit.x),absf(hit.z)) < PLATE_HALF-RIM_BAND: return null
	return rim

## How far a plate point is from the camera's eye along the pointer's ray.
func _eye_distance(point: Vector2, local: Vector3) -> float:
	return _editor().terrain.to_local(scene.camera.project_ray_origin(point)).distance_to(local)

## The rim point nearest the pointer, wherever it is: for a drag, which may
## wander off the rim. Cheap: no ray into the terrain.
func rim_point(point: Vector2) -> Vector3:
	var wall: Variant = _wall_hit(point)
	if wall != null: return wall
	var at: Variant = _plate_at(point)
	if at != null and absf(at.x) <= PLATE_HALF and absf(at.z) <= PLATE_HALF: return _edge(Vector2(at.x,at.z))
	return _outline_nearest(point)[1]

## Where the hand shows a rim point: on the lip as it is, on a wall stood out
## from it onto the face of the earth sides round the palm, so they do not
## hide it and the palm lies on them.
func _hand_at(rim: Vector3) -> Vector3:
	var edge := Vector2(rim.x,rim.z)
	if rim.y > _rim_height(edge)-0.05: return rim
	var out := Vector3(signf(rim.x),0.0,0.0) if absf(rim.x) >= absf(rim.z) else Vector3(0.0,0.0,signf(rim.z))
	return rim+out*_wall_face(rim,out)

## How far out from the plate's wall at `rim` (outward `out`) the palm lies:
## WALL_GAP past the outermost face of the earth sides round it, read along
## rays into their facets over the palm and fingers and at the facets' corners
## there. The facets are large, so their corners alone can miss a bulge.
func _wall_face(rim: Vector3, out: Vector3) -> float:
	var editor := _editor()
	var skirt: MeshInstance3D = editor.get("_skirt")
	if skirt == null or skirt.mesh == null or not skirt.visible: return WALL_OUT
	var placing: Transform3D = editor.terrain.global_transform.affine_inverse()*skirt.global_transform
	if _skirt_read != [skirt.mesh,placing]:
		_skirt_read = [skirt.mesh,placing]
		_skirt_points = placing*skirt.mesh.get_faces()
	var along := Vector3(out.z,0.0,-out.x)
	var near := PackedVector3Array()
	var face := -INF
	for i in range(0,_skirt_points.size()-2,3):
		var corners := [_skirt_points[i]-rim,_skirt_points[i+1]-rim,_skirt_points[i+2]-rim]
		var outmost := -INF
		var low := INF
		var high := -INF
		var left := INF
		var right := -INF
		for d: Vector3 in corners:
			outmost = maxf(outmost,d.dot(out))
			low = minf(low,d.y)
			high = maxf(high,d.y)
			left = minf(left,d.dot(along))
			right = maxf(right,d.dot(along))
		# Only this wall's facets over the palm's reach.
		if outmost < -1.0 or high < -WALL_BELOW or low > WALL_ABOVE or right < -WALL_SPAN or left > WALL_SPAN: continue
		near.append_array(PackedVector3Array(corners))
		for d: Vector3 in corners:
			if d.y >= -WALL_BELOW and d.y <= WALL_ABOVE and absf(d.dot(along)) <= WALL_SPAN: face = maxf(face,d.dot(out))
	for across in [-WALL_SPAN,0.0,WALL_SPAN]:
		for up in [-WALL_BELOW,0.0,WALL_ABOVE*0.5,WALL_ABOVE]:
			var from: Vector3 = along*across+Vector3.UP*up+out*2.0
			for i in range(0,near.size(),3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(from,-out,near[i],near[i+1],near[i+2])
				if hit != null: face = maxf(face,Vector3(hit).dot(out))
	return maxf(face,0.0)+WALL_GAP if face > -INF else WALL_OUT

## The way into the wall a hand point faces (`_hand_at`), or null on the lip.
func _wall_facing(at: Variant) -> Variant:
	if at == null: return null
	var p: Vector3 = at
	if maxf(absf(p.x),absf(p.z)) < PLATE_HALF+0.01: return null
	return Vector3(-signf(p.x),0.0,0.0) if absf(p.x) >= absf(p.z) else Vector3(0.0,0.0,-signf(p.z))

## Where the pointer's ray meets the plane of the rim's height near it (plate
## coordinates), or null when it looks up.
func _plate_at(point: Vector2) -> Variant:
	var terrain: Node3D = _editor().terrain
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(point))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(point)).normalized()
	if direction.y > -0.001: return null
	var at := origin+direction*(-origin.y/direction.y)
	var height := _edge(Vector2(at.x,at.z)).y
	return origin+direction*((height-origin.y)/direction.y)

## The land under a pointer (NativeChunkEditor.pick), once a frame per point;
## the editor's own hit when it has read this pointer already.
func _land(point: Vector2) -> Variant:
	var editor := _editor()
	var frame := Engine.get_process_frames()
	if frame != _land_frame:
		_land_frame = frame
		_land_cache.clear()
	if not _land_cache.has(point):
		var mouse := scene.get_viewport().get_mouse_position()
		var read: bool = editor.active and not scene.get("_orbiting") == true and point.distance_to(mouse) < 0.5
		_land_cache[point] = editor.pointer_hit if read else editor.pick(point)
	return _land_cache[point]

## The rim point nearest a plate position: on the nearer edge, at the land's height there.
func _edge(p: Vector2) -> Vector3:
	var edge := p.clamp(Vector2.ONE*-PLATE_HALF,Vector2.ONE*PLATE_HALF)
	if absf(edge.x) >= absf(edge.y): edge.x = signf(edge.x)*PLATE_HALF if edge.x != 0.0 else PLATE_HALF
	else: edge.y = signf(edge.y)*PLATE_HALF
	return Vector3(edge.x,_rim_height(edge),edge.y)

func _rim_height(edge: Vector2) -> float:
	var inside := edge.clamp(Vector2.ONE*-(PLATE_HALF-0.02),Vector2.ONE*(PLATE_HALF-0.02))
	var h: Variant = _editor().data.ground_height(inside)
	return float(h) if h != null else 0.0

## The block's walls: where the pointer's ray meets one from outside, between
## the block's foot and the rim over it (a little above it counts as the lip).
func _wall_hit(point: Vector2) -> Variant:
	var editor := _editor()
	var terrain: Node3D = editor.terrain
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(point))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(point)).normalized()
	var low := _foot()
	var best: Variant = null
	var nearest := INF
	for axis in [0,2]:
		if absf(direction[axis]) < 1e-5: continue
		for side in [-1.0,1.0]:
			# Only a wall's outer face: the ray must be going in through it.
			if side*direction[axis] >= 0.0: continue
			var t: float = (side*PLATE_HALF-origin[axis])/direction[axis]
			if t <= 0.0 or t >= nearest: continue
			var at: Vector3 = origin+direction*t
			var across := at.z if axis == 0 else at.x
			if absf(across) > PLATE_HALF: continue
			var edge := Vector2(at.x,at.z)
			var top := _rim_height(edge)
			if at.y < low or at.y > top+0.3: continue
			nearest = t
			best = Vector3(edge.x,minf(at.y,top),edge.y)
	return best

## The foot of the earth block, plate coordinates (the skirt mesh's lowest point).
func _foot() -> float:
	if _block_low == null:
		_block_low = -6.0
		var editor := _editor()
		var skirt: MeshInstance3D = editor.get("_skirt")
		if skirt != null and skirt.mesh != null:
			var box := skirt.mesh.get_aabb()
			_block_low = editor.terrain.to_local(skirt.to_global(box.position)).y
	return float(_block_low)

## The rim's outline on screen, round the plate and closed, for the first
## steps' card to light (scripts/first_steps_card.gd `rim`); empty when any
## of it is behind the camera.
func rim_outline() -> PackedVector2Array:
	var camera: Camera3D = scene.camera
	var terrain: Node3D = _editor().terrain
	var points := PackedVector2Array()
	var steps := 24
	for side in range(4):
		for i in range(steps):
			var f := -PLATE_HALF+2.0*PLATE_HALF*float(i)/steps
			var edge: Vector2 = [Vector2(f,-PLATE_HALF),Vector2(PLATE_HALF,f),Vector2(-f,PLATE_HALF),Vector2(-PLATE_HALF,-f)][side]
			var world := terrain.to_global(Vector3(edge.x,_rim_height(edge),edge.y))
			if camera.is_position_behind(world): return PackedVector2Array()
			points.append(camera.unproject_position(world))
	points.append(points[0])
	return points

## [pixels, rim point] for the rim's outline sample nearest `point` on screen.
func _outline_nearest(point: Vector2) -> Array:
	var camera: Camera3D = scene.camera
	var terrain: Node3D = _editor().terrain
	var best := [INF,Vector3.ZERO]
	var steps := 24
	for side in range(4):
		for i in range(steps):
			var f := -PLATE_HALF+2.0*PLATE_HALF*(i+0.5)/steps
			var edge: Vector2 = [Vector2(f,-PLATE_HALF),Vector2(PLATE_HALF,f),Vector2(-f,PLATE_HALF),Vector2(-PLATE_HALF,-f)][side]
			var local := Vector3(edge.x,_rim_height(edge),edge.y)
			var world := terrain.to_global(local)
			if camera.is_position_behind(world): continue
			var pixels := point.distance_to(camera.unproject_position(world))
			if pixels < float(best[0]): best = [pixels,local]
	return best

# --- Input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if handle(event): get_viewport().set_input_as_handled()

## The pointer's events. True when the event was the hand's.
func handle(event: InputEvent) -> bool:
	if scene == null or not scene.is_node_ready(): return false
	if event is InputEventKey:
		return materials != null and holding.is_empty() and available() and materials.key(event as InputEventKey)
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT: return false
		if button.pressed:
			# While the diorama is turning over, a press waits for it to land.
			var flip: Node = scene.get("flip")
			if holding.is_empty() and flip != null and flip.active():
				# A tossed block in the air is caught; otherwise the press waits.
				if modeless and flip.can_catch(): _catch_toss(button.position)
				return true
			if not holding.is_empty() or not available() or button.ctrl_pressed or button.double_click: return false
			_press_shift = button.shift_pressed
			if materials != null and materials.press(button.position): return true
			if modeless and _cloud_press(button.position): return true
			var what := reach_at(button.position)
			if what.is_empty():
				if modeless and _void_press(button.position): return true
				# Shift on a plant plucks it (or the undergrowth) out, whatever tool
				# is in hand. Otherwise a shaping tool works the land under a tree,
				# and only a free hand bends it.
				if modeless and _press_shift and _pluck_press(button.position): return true
				if modeless and not shaping() and _tree_press(button.position): return true
				return modeless and _land_press(button.position)
			grab(what,button.position)
			return true
		if holding.is_empty(): return false
		if holding == "void":
			_void_release(button.position,button.shift_pressed)
			return true
		release(button.position)
		return true
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if holding.is_empty(): return false
		drag(motion.position,motion.relative)
		return true
	return false

## Take hold of `what` ("sun" or "rim") with the pointer at `point`.
func grab(what: String, point: Vector2) -> void:
	holding = what
	_press_pos = point
	rim_intent = ""
	drifting = false
	settling = false
	_reverted = false
	uses[what] = int(uses.get(what,0))+1
	var mood := _mood()
	if mood != null: mood.finish_fade()
	var clock: WorldClock = scene.world_clock
	if what == "sun":
		body = _body_at(point)
		if body.is_empty(): body = "sun"
		var at: Variant = _screen(body_direction(body,float(scene._celestial.phase)))
		_offset = (at-point) if at != null else Vector2.ZERO
		_turning = clock.running
		clock.running = false
		_last_phase = float(scene._celestial.phase)
		phase_speed = 0.0
	else:
		if not modeless:
			dial = dial_for_season(clock.season)
			grab_dial = dial
			grab_season_override = clock.season_override
			grab_season_pin = str(mood.pins.get("season","")) if mood != null else ""
		_press_edge = rim_point(point)
		reach_point = _hand_at(_press_edge)
		_rim_angle = _angle_round(point)
		_last_drag = Time.get_ticks_usec()
		if modeless: _catch_spin(point)
		rim_grabbed.emit(point)
	_set_cursor(Input.CURSOR_DRAG)
	_show_hint("")
	holding_changed.emit(what)

func drag(point: Vector2, relative: Vector2) -> void:
	if holding == "sun":
		var phase := arc_phase(point+_offset,float(scene._celestial.phase))
		scene._celestial.set_phase(phase)
	elif holding == "land":
		land_dragged.emit(point,relative)
	elif holding == "void":
		_void_drag(point)
	elif holding == "cloud":
		_cloud_drag(point)
	elif holding == "tree":
		_tree_pull(point)
	elif holding in ["jar","scatter","almanac","paint","fence_line","bridge"]:
		materials.drag(point)
	elif holding == "rim":
		var angle: Variant = _angle_round(point)
		# Once a shake has taken the rim (scripts/snow_globe.gd) the dial stays
		# where it was taken.
		if angle != null and _rim_angle != null and not _reverted and not modeless:
			turn_dial(angle_difference(float(_rim_angle),float(angle))/TAU*QUARTERS_PER_TURN)
		_rim_angle = angle
		reach_point = _hand_at(rim_point(point))
		# The time since the last move, not the frame's: several moves may
		# come in one frame, and the shake reads their speed.
		var now := Time.get_ticks_usec()
		rim_dragged.emit(relative,clampf((now-_last_drag)/1000000.0,0.001,0.1))
		_last_drag = now
		if modeless: _rim_motion(point,relative)

## Let go of what the hand holds.
func release(point := Vector2.INF) -> void:
	var what := holding
	holding = ""
	_set_cursor(Input.CURSOR_ARROW)
	if what == "land":
		land_released.emit(point if point != Vector2.INF else _press_pos)
	elif what == "void":
		reach_point = null
	elif what == "tree":
		reach_point = null
		_tree_let_go()
	elif what == "pluck":
		reach_point = null
	elif what == "cloud":
		reach_point = null
		if _source != null: _source.let_go()
	elif what in ["jar","scatter","almanac","feather","can","paint","fence_line","bridge"]:
		reach_point = null
		materials.let_go(what,point)
	elif what == "sun":
		drifting = true
		phase_speed = clampf(phase_speed,-DRIFT_MAX,DRIFT_MAX)
	elif what == "rim":
		settling = not _reverted and not modeless
		if modeless: _rim_release(point)
		rim_released.emit()
	holding_changed.emit("")

## Another part of the hand (scripts/hand_materials.gd) takes the press as
## `what`: its drag and release come back to it through `drag` and `release`.
func take_hold(what: String, point: Vector2) -> void:
	holding = what
	_press_pos = point
	_show_hint("")
	holding_changed.emit(what)

## Lets go of a hold without its release: its press has gone on to the
## editor, which holds it from here.
func drop_hold() -> void:
	holding = ""
	reach_point = null
	holding_changed.emit("")

## A hold ends if the window loses the pointer mid-drag, as a release would.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not holding.is_empty(): release()

# --- The sun ------------------------------------------------------------------

## The phase near `from` whose body lands nearest `target` on screen: a coarse
## pass over ARC_WINDOW either side, then a fine one round the best.
func arc_phase(target: Vector2, from: float) -> float:
	var best := from
	var gap := _arc_gap(target,from)
	var span := ARC_WINDOW
	for step: float in [ARC_STEP,ARC_FINE]:
		var centre := best
		var count := int(span/step)
		for i in range(-count,count+1):
			var candidate: float = centre+i*step
			var d := _arc_gap(target,candidate)
			if d < gap:
				gap = d
				best = candidate
		span = ARC_STEP*1.5
	return fposmod(best,1.0)

func _arc_gap(target: Vector2, at_phase: float) -> float:
	var at: Variant = _screen(body_direction(body,at_phase))
	return INF if at == null else target.distance_squared_to(at)

# --- The season dial ------------------------------------------------------------

## The pointer's angle round the plate's middle, seen from above (radians,
## growing as the rim turns anticlockwise, which is the near rim pushed to the
## right): where its ray meets the rim's height, else round the plate's middle
## on screen.
func _angle_round(point: Vector2) -> Variant:
	var editor := _editor()
	var terrain: Node3D = editor.terrain
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(point))
	var direction := (terrain.global_basis.inverse()*camera.project_ray_normal(point)).normalized()
	var height: float = reach_point.y if reach_point != null else 0.0
	if direction.y < -0.02:
		var at := origin+direction*((height-origin.y)/direction.y)
		if Vector2(at.x,at.z).length() > 0.5: return atan2(at.x,at.z)
	var middle := camera.unproject_position(terrain.to_global(Vector3(0,height,0)))
	var away := point-middle
	if away.length() < 4.0: return null
	return -atan2(away.y,away.x)

## Turn the dial by `quarters` (a season is 1).
func turn_dial(quarters: float) -> void:
	dial += quarters
	_apply_dial()

## The season value (0..1, the world clock's) a dial position shows: the
## detents stick (DETENT), and between them the value runs piecewise between
## Living weather's mid-season values.
static func season_for_dial(value: float) -> float:
	var shaped := value-DETENT*sin(TAU*value)/TAU
	var q := fposmod(shaped,4.0)
	var i := int(floor(q))%4
	var seasons: Array = Living.SEASONS
	var a := float(seasons[i])
	var b := float(seasons[(i+1)%4])+(1.0 if i == 3 else 0.0)
	return fposmod(lerpf(a,b,q-floor(q)),1.0)

## The dial position (in [0, 4)) that shows a season value.
static func dial_for_season(season: float) -> float:
	var seasons: Array = Living.SEASONS
	var s := fposmod(season,1.0)
	if s < float(seasons[0]): s += 1.0
	var q := 3.0+(s-float(seasons[3]))/(float(seasons[0])+1.0-float(seasons[3]))
	for i in range(3):
		if s < float(seasons[i+1]):
			q = i+(s-float(seasons[i]))/(float(seasons[i+1])-float(seasons[i]))
			break
	# Undo the detents' shaping: solve u - DETENT sin(2πu)/2π = q.
	var u := q
	for _i in range(8): u -= (u-DETENT*sin(TAU*u)/TAU-q)/(1.0-DETENT*cos(TAU*u))
	return u

## The season id ("spring"...) of a dial position's nearest detent.
static func season_id(value: float) -> String:
	return str(WorldClock.SEASON_NAMES[posmod(roundi(value),4)])

func _apply_dial() -> void:
	var clock: WorldClock = scene.world_clock
	clock.season_override = season_for_dial(dial)
	# The shown season follows at once: no glide behind the hand.
	scene._season_shown = clock.season

## A shake (the snow-globe slice) undoes the turn: the dial goes back to where
## the rim was taken, and a settle in progress stops. After the let-go it
## puts the season pin back as it was too.
func revert_season_to_grab() -> void:
	# Modeless there is no dial to undo: a shake just takes the rim from the turn or the flip.
	if modeless:
		_shake_takes_rim()
		return
	settling = false
	_reverted = not holding.is_empty()
	dial = grab_dial
	var clock: WorldClock = scene.world_clock
	clock.season_override = grab_season_override
	scene._season_shown = clock.season
	var mood := _mood()
	if mood == null or not holding.is_empty(): return
	var pinned := str(mood.pins.get("season",""))
	if pinned == grab_season_pin: return
	if grab_season_pin.is_empty(): mood.unpin("season")
	else: mood.pin("season",grab_season_pin)

# --- Frames ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_hint_clock += delta
	_notice_left -= delta
	if scene == null or scene.camera == null or _editor() == null: return
	delta = minf(delta,0.1)
	var phase := float(scene._celestial.phase)
	if holding == "sun":
		var moved := angle_difference(_last_phase*TAU,phase*TAU)/TAU
		phase_speed = lerpf(phase_speed,moved/maxf(delta,0.001),1.0-exp(-SPEED_READ*delta))
		_last_phase = phase
	elif drifting:
		phase_speed *= exp(-DRIFT_FRICTION*delta)
		scene._celestial.set_phase(phase+phase_speed*delta)
		if absf(phase_speed) < DRIFT_STOP: _rest_sun()
	if settling:
		var goal := roundf(dial)
		dial = lerpf(dial,goal,1.0-exp(-SETTLE*delta))
		if absf(dial-goal) < SETTLED:
			dial = goal
			settling = false
			_apply_dial()
			_rest_season()
		else:
			_apply_dial()
	# Looking out through the wanderer (scripts/wanderer_eye.gd) the hover
	# shows nothing: no outline, hint, cursor or hand pose.
	var eye := _eye_in()
	if eye: _stand_down_for_eye()
	# The hover first, so the hand shows what the pointer is over this frame.
	elif holding.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_hover(scene.get_viewport().get_mouse_position() if pointer_override == null else pointer_override)
	elif outline != null and outline.tree_id > 0: _outline_tree(-1)
	if outline != null and outline.tree_id > 0: outline.spores_ready = _tree_rested(outline.tree_id)
	if modeless:
		if cloud != null: cloud.calm = holding.is_empty() and available()
		# A still hold in the void calls the cloud (before the wind reads it).
		if holding == "void":
			_void_held += delta
			if _void_travel <= CLICK_PIXELS and _void_held >= SUMMON_HOLD and cloud != null and cloud.summoned and cloud.presence == "gone": _summon()
		# A hand hovering by the cloud keeps it up.
		if cloud != null and cloud.summoned and holding.is_empty() and cloud.near(scene.get_viewport().get_mouse_position() if pointer_override == null else pointer_override): cloud.keep()
		if wind != null:
			# A press let go off the window never releases: the wind lets go too.
			if holding != "void" and not wind.state.is_empty(): wind.state = ""
			# Only a drag is the wind's: a still press is a click or a summon.
			if holding == "void" and _void_travel > CLICK_PIXELS: wind.step(delta)
		_step_trees(delta)
		if reveal != null: reveal.step(delta,_reveal_at(eye),scene.camera.global_position,_clay_size())
		if not eye: _drive_hand_modeless()
		if materials != null: materials.step(delta)
		if marks != null: marks.step(delta)
	elif not eye: _drive_hand()

## True while the camera looks out through the wanderer.
func _eye_in() -> bool:
	var wanderer: Node = scene.get("wanderer")
	return wanderer != null and wanderer.get("active") == true

## Clears every hover affordance, once, on stepping into the wanderer; the
## hover reads afresh on stepping out (`_hover_key` is cleared).
func _stand_down_for_eye() -> void:
	if outline != null and outline.tree_id > 0: _outline_tree(-1)
	if _hover_key.is_empty() and hover_zone.is_empty(): return
	_hover_key = []
	hover_zone = ""
	_hover_point = null
	reaching = ""
	_set_cursor(Input.CURSOR_ARROW)
	_read_hint("")
	_show_hint("")
	var hand: Node3D = scene.get("god_hand")
	if hand != null and not _hover_shown.is_empty() and hand.reach_gesture == _hover_shown: _set_hand(hand,"",null,null)
	_hover_shown = ""

## The sun has come to rest: the hour is held, or a day that was turning turns on.
func _rest_sun() -> void:
	drifting = false
	phase_speed = 0.0
	var phase := float(scene._celestial.phase)
	var mood := _mood()
	if _turning:
		scene.world_clock.running = true
	elif mood != null:
		mood.pin_hour(phase)
	else:
		scene._celestial.set_phase(phase)

## The dial has settled into a detent: pin that season, as the drawer would.
func _rest_season() -> void:
	var mood := _mood()
	if mood == null: return
	var id := season_id(dial)
	if mood.value("season") != id or not mood.pinned("season"): mood.pin("season",id)

## The hand shows the hold: it cups the sun SUN_REACH out along the ray to
## it, or grips the rim under the pointer.
func _drive_hand() -> void:
	var hand: Node3D = scene.get("god_hand")
	if holding == "sun":
		var direction := body_direction(body,float(scene._celestial.phase))
		reach_point = _editor().terrain.to_local(scene.camera.global_position+direction*SUN_REACH)
	elif holding.is_empty():
		reach_point = null
	if hand == null: return
	# A decided shake has the hand; and when nothing is held, only a reach of
	# its own is let go, so the lazy Susan's grip (scripts/world_turn.gd) stays.
	var globe: Node = scene.get("snow_globe")
	if holding == "rim" and globe != null and globe.decided: return
	if not holding.is_empty():
		hand.reach_gesture = holding
		hand.reach_point = reach_point
	elif hand.reach_gesture in GESTURES:
		hand.reach_gesture = ""
		hand.reach_point = null

# --- Hover and hint --------------------------------------------------------------

func _hover(point: Vector2) -> void:
	# Only when the pointer or the camera has moved.
	var key := [point,scene.camera.global_transform,snappedf(float(scene._celestial.phase),0.0005)]
	# The cloud drifts under a still pointer.
	if cloud != null: key.append(cloud.centre.snapped(Vector3.ONE*0.25))
	# Shift outlines what a press would pluck; a plucked plant's outline goes.
	if modeless: key.append_array([Input.is_key_pressed(KEY_SHIFT),_editor().data.objects_revision])
	# A notice's end reads the hover afresh.
	key.append(_noticing())
	if key == _hover_key: return
	_hover_key = key
	var what := reach_at(point) if available() else ""
	if what == "sun" and _body_at(point) == "moon": what = "moon"
	reaching = "sun" if what == "moon" else what
	if modeless:
		hover_zone = what
		_hover_point = null
		var found := _source_at(point)
		if not found.is_empty():
			what = ""
			reaching = ""
			hover_zone = "cloud"
			_source = found[0]
			_hover_point = _editor().terrain.to_local(found[1])
		elif what == "rim": _hover_point = _hand_at(rim_point(point))
		elif available() and _editor().pointer_in_world(point):
			var land: Variant = _land(point)
			if land != null:
				hover_zone = "land"
				_hover_point = land
		_hover_void(point)
		if materials != null and hover_zone.is_empty() and materials.tray_under(point): hover_zone = "tray"
		# With material in hand a press on a tree sows or pours, and with a
		# shaping tool it works the land under it: no outline. With Shift
		# held, with any tool, it outlines what a press would pluck,
		# undergrowth too.
		var carrying := materials != null and not materials.held.is_empty()
		var free := what.is_empty() and hover_zone in ["land",""] and not carrying \
				and (Input.is_key_pressed(KEY_SHIFT) or not shaping())
		_outline_tree((plant_under(point) if Input.is_key_pressed(KEY_SHIFT) else _tree_under(point)) if free else -1)
	_set_cursor(Input.CURSOR_POINTING_HAND if not what.is_empty() or hover_zone in ["cloud","tray"] else Input.CURSOR_ARROW)
	var text := ""
	var zone := ""
	if not what.is_empty():
		zone = reaching
		text = {"sun":SUN_HINT,"moon":MOON_HINT,"rim":RIM_HINT_MODELESS if modeless else RIM_HINT}[what]
	if modeless and hover_zone == "void":
		zone = "void" if sky_snap else ""
		text = VOID_HINT if sky_snap else ""
		# The summon: at once, or with the snap once the demo cloud has shown
		# or the snap is known.
		if cloud != null and cloud.summoned and not _hint_quiet("summon") and (not sky_snap or SkyCloud.demo_shown or _hint_quiet("void")):
			zone = "summon"
			text = SUMMON_HINT
	if modeless and hover_zone == "cloud":
		zone = _source.kind
		text = CLOUD_HINT
	if materials != null and not materials.held.is_empty() and hover_zone in ["land","void","cloud"]:
		var said: Array = materials.hint(hover_zone)
		zone = said[0]
		text = said[1]
	if _hint_quiet(zone): text = ""
	# A notice holds the line until its time is up.
	if _noticing(): return
	_read_hint(zone if not text.is_empty() else "")
	_show_hint(text)

## A refusal's line (why the land would not take what the hand set): shown at
## once, and held NOTICE_SECONDS against the hover, which would otherwise
## write over it at the next sun step or pointer move. A press (its
## `_show_hint("")`), another line, or something else taken up in hand ends
## it sooner.
func notice(text: String) -> void:
	_show_hint(text)
	_notice = text
	_notice_left = NOTICE_SECONDS if not text.is_empty() else 0.0
	_notice_held = materials.held if materials != null else ""

## True while a notice holds the hint line.
func _noticing() -> bool:
	if _notice_left <= 0.0 or _notice.is_empty() or _hint != _notice: return false
	return materials == null or materials.held == _notice_held

## A zone's hint is done: its verb used HINT_UNTIL times (the sky's snap or
## any gust counts for the void), or read HOVER_UNTIL times.
func _hint_quiet(zone: String) -> bool:
	if zone.is_empty(): return true
	if zone == "summon": return int(uses.get("summon",0)) >= SUMMON_HINT_UNTIL or int(hint_reads.get(zone,0)) >= SUMMON_READS
	var used := int(uses.get(zone,0))+(int(uses.get("wind",0)) if zone == "void" else 0)
	return used >= HINT_UNTIL or int(hint_reads.get(zone,0)) >= HOVER_UNTIL

## The zone whose hint the hover shows now; one shown HOVER_READ seconds or
## more counts as read once when it goes.
func _read_hint(zone: String) -> void:
	if zone == _hint_zone: return
	if not _hint_zone.is_empty() and _hint_clock-_hint_since >= HOVER_READ:
		hint_reads[_hint_zone] = int(hint_reads.get(_hint_zone,0))+1
	_hint_zone = zone
	_hint_since = _hint_clock

## The hint line: the Lantern shell's (`reach_hint`); the glass palette's
## status line otherwise.
func _show_hint(text: String) -> void:
	if text == _hint: return
	_hint = text
	var shell: Node = scene.get("creation_palette")
	if shell != null and shell.has_method("reach_hint"): shell.reach_hint(text)
	elif not text.is_empty() and _editor() != null: _editor()._set_status(text)

func _set_cursor(shape: Input.CursorShape) -> void:
	if shape == Input.CURSOR_ARROW:
		if not _cursor_owned: return
		_cursor_owned = false
	else:
		_cursor_owned = true
	Input.set_default_cursor_shape(shape)

# --- Modeless: the rim's verbs and the land's seam ---------------------------------

## The turn (scripts/world_turn.gd), or null.
func _turn() -> Node:
	var rig: Node = scene.get("camera_rig")
	return rig.get("turn") if rig != null else null

## A press into a spin catches it, as any press on the world does.
func _catch_spin(point: Vector2) -> void:
	var turn := _turn()
	if turn != null and turn.enabled and turn.spinning(): turn.catch_at(point)

## A left press that reached no sun or rim. Under `--modeless` a press on the
## land is clay's (scripts/land_clay.gd): emitted, and taken so no brush or
## turn sees it. A prop or a resident under the pointer keeps its own grab,
## and so does a tree but for a shaping tool, which works the land under it
## (`shaping`). The sky and the far ground are nobody's.
func _land_press(point: Vector2) -> bool:
	if tool_down() or _land(point) == null or _prop_at(point,not shaping()): return false
	holding = "land"
	_press_pos = point
	_show_hint("")
	_catch_spin(point)
	land_pressed.emit(point)
	return true

## True when a grabbable prop or tree, or a resident, is under the pointer.
## Without `trees`, trees are looked through: a prop behind one still counts.
func _prop_at(point: Vector2, trees := true) -> bool:
	var play: Variant = scene.get("world_play")
	if play != null and play.owner_scene != null:
		if play.loose_props.pick(point) != null: return true
		var id: int = play.pick_object(point,trees)
		if id > 0:
			var asset: Variant = play._records.get(id,{}).get("asset")
			if asset in play.TREES or asset in play.PROPS: return true
	var resident: Variant = scene.get("_resident_play")
	return resident != null and resident.scene != null and bool(resident.hovered)

## A drag on the held rim, once the snow globe has been fed it. Undecided, the
## first AXIS_PIXELS of travel choose: sideways the turn, up the flip, down
## the edge spring.
func _rim_motion(point: Vector2, relative: Vector2) -> void:
	var globe: Node = scene.get("snow_globe")
	if globe != null and globe.decided:
		_shake_takes_rim()
		return
	var travel := point-_press_pos
	if rim_intent.is_empty():
		if travel.length() < Modeless.AXIS_PIXELS: return
		if absf(travel.y) > absf(travel.x)*Modeless.VERTICAL_BIAS:
			if travel.y < 0.0:
				rim_intent = "flip"
				flip_began.emit(_press_pos)
			else:
				rim_intent = "spring"
				edge_spring_began.emit(_press_pos)
		else:
			rim_intent = "turn"
			var turn := _turn()
			# Shift turns without winding time, however fast (spin_time.gd).
			if turn != null: turn.timeless = _press_shift or Input.is_key_pressed(KEY_SHIFT)
			var terrain: Node3D = _editor().terrain
			_grab_global = terrain.to_global(_press_edge)
			if turn != null: turn.hold_begin(_press_pos,_grab_global)
	if rim_intent == "turn":
		var turn := _turn()
		if turn != null: turn.hold_move(point)
	elif rim_intent == "flip":
		flip_dragged.emit(_flip_progress(point))
	elif rim_intent == "spring":
		edge_spring_dragged.emit(point,relative)

## A press while a tossed block is in the air: the hand holds the rim again
## and the flip is caught where it is, so the next drag and flick add to it.
func _catch_toss(point: Vector2) -> void:
	var flip: Node = scene.get("flip")
	if not flip.catch(point): return
	grab("rim",point)
	rim_intent = "flip"

## How far over the lip an upward drag has taken the diorama, 0..1.
func _flip_progress(point: Vector2) -> float:
	var height := maxf(scene.get_viewport().get_visible_rect().size.y,1.0)
	return clampf((_press_pos.y-point.y)/(Modeless.FLIP_REACH*height),0.0,1.0)

## A shake was decided: it takes the rim. The turn stops where it is (no spin
## carried on), a flip in the making is abandoned as never begun, and an edge
## spring is let go at its press, so it relaxes and keeps nothing.
func _shake_takes_rim() -> void:
	if holding != "rim" or rim_intent == "shake": return
	var was := rim_intent
	rim_intent = "shake"
	if was == "turn":
		var turn := _turn()
		if turn != null: turn.hold_end(false)
	elif was == "flip":
		flip_released.emit(0.0)
	elif was == "spring":
		edge_spring_released.emit(_press_pos)

## Letting go of the rim: the turn spins on if it was fast, the flip is told
## how far over it had gone, the edge spring where the pointer let go.
func _rim_release(point: Vector2) -> void:
	if rim_intent == "turn":
		var turn := _turn()
		if turn != null: turn.hold_end(true)
	elif rim_intent == "flip":
		flip_released.emit(_flip_progress(point) if point != Vector2.INF else 0.0)
	elif rim_intent == "spring":
		edge_spring_released.emit(point if point != Vector2.INF else _press_pos)
	rim_intent = ""

## The hand for the modeless zones: over the rim's lip it takes the rim grip,
## on the block's walls it lays its palm on the wall ("wall", facing into it),
## over the land it readies a pinch; held on the rim it keeps that pose while it
## turns (a decided shake and the flip have the hand, as ever). The land's hold
## is the spring slice's to show.
func _drive_hand_modeless() -> void:
	var hand: Node3D = scene.get("god_hand")
	if holding.is_empty(): reach_point = null
	if hand == null: return
	# Only the hover stands the hand down for the camera; a hold keeps it.
	hand.held_off = false
	if materials != null and materials.drive_hand(hand): return
	var globe: Node = scene.get("snow_globe")
	if holding == "rim" and globe != null and globe.decided: return
	if holding == "land":
		_hover_shown = ""
		return
	if holding == "void":
		_drive_void_hold(hand)
		return
	if holding == "cloud":
		reach_point = _editor().terrain.to_local(_source.hand_point())
		# A summoned cloud forms in a cupped hand; the pinch closes on it.
		if not _pinched and (not _source.forming() or _source.tension >= PINCH_TENSION): _pinched = true
		_set_hand(hand,"cloud" if _pinched else "summon",reach_point,null)
		return
	if holding == "tree":
		if is_instance_valid(_tree): reach_point = _editor().terrain.to_local(_tree.center(float(_tree.tree_height)*0.6))
		_set_hand(hand,"cloud",reach_point,null)
		return
	# Turning the diorama over, the flip (scripts/diorama_flip.gd) has the hand.
	# Drawing the edge spring, the spring (scripts/land_spring.gd) has it.
	if holding == "rim" and rim_intent in ["flip","spring"]: return
	if holding == "rim":
		_show_hand(hand,reach_point)
		return
	var want := ""
	var target: Variant = null
	# While the camera moves the hand fades out as it stands, and comes back.
	var camera_busy := camera_moving()
	hand.held_off = camera_busy
	if available():
		if hover_zone == "rim":
			want = "rim"
			target = _hover_point
		elif hover_zone == "land":
			# Ready to pinch, or gripping the shaping tool in hand; open with
			# the tool put down.
			var clay: Node = scene.get("land_clay")
			if tool_down(): want = "void"
			else: want = clay.hover_gesture() if clay != null else "pinch"
			target = _hover_point
		elif hover_zone == "void" and sky_snap:
			want = "void"
			target = _void_point(_void_pointer())
		elif hover_zone == "cloud":
			# Open and ready over the cloud, where the pointer meets it.
			want = "void"
			target = _hover_point
	if not want.is_empty():
		# Only over a hand that is free, or one of our own hover poses.
		if hand.reach_gesture.is_empty() or hand.reach_gesture == _hover_shown:
			if want == "rim": _show_hand(hand,target)
			else: _set_hand(hand,want,target,null)
	elif not _hover_shown.is_empty():
		if hand.reach_gesture == _hover_shown: _set_hand(hand,"",null,null)
		_hover_shown = ""

## The rim pose at a hand point (`_hand_at`): the palm on the wall, facing into
## it, below the lip; the rim grip on it.
func _show_hand(hand: Node3D, at: Variant) -> void:
	var facing: Variant = _wall_facing(at)
	_set_hand(hand,"rim" if facing == null else "wall",at,facing)

func _set_hand(hand: Node3D, gesture: String, at: Variant, facing: Variant) -> void:
	hand.reach_gesture = gesture
	hand.reach_point = at
	hand.reach_facing = facing
	_hover_shown = gesture

# --- Modeless: the void and the snap (docs/scenic/modeless.md "Void slice";
# the snap behind `--void-snap`) --------

## True when a pointer at `point` is in the void: in the world, reaching no
## rim or wall, over no land and no prop or resident.
func void_at(point: Vector2) -> bool:
	if not available() or not _editor().pointer_in_world(point): return false
	return reach_at(point).is_empty() and _land(point) == null and not _prop_at(point)

## Where the hand floats for a pointer in the void (plate coordinates): along
## its ray, VOID_DEPTH of the camera's distance to its pivot out.
func _void_point(point: Vector2) -> Vector3:
	var camera: Camera3D = scene.camera
	var depth := maxf(float(scene.get("distance"))*VOID_DEPTH,VOID_NEAR)
	return _editor().terrain.to_local(camera.project_ray_origin(point)+camera.project_ray_normal(point)*depth)

## The pointer the hover last read.
func _void_pointer() -> Vector2:
	if not _hover_key.is_empty(): return _hover_key[0]
	return scene.get_viewport().get_mouse_position() if pointer_override == null else pointer_override

## Hover: the void when no rim, wall or land is under the pointer.
func _hover_void(point: Vector2) -> void:
	if not hover_zone.is_empty() or not available() or not _editor().pointer_in_world(point): return
	if _prop_at(point): return
	hover_zone = "void"
	_hover_point = _void_point(point)

## A left press in the void (a summon, the wind, or with `--void-snap` a
## snap); nothing else sees it.
func _void_press(point: Vector2) -> bool:
	if not void_at(point): return false
	holding = "void"
	_press_pos = point
	_void_travel = 0.0
	_void_held = 0.0
	_void_last = point
	if wind != null: wind.press(point)
	reach_point = _void_point(point)
	_show_hint("")
	holding_changed.emit("void")
	return true

func _void_drag(point: Vector2) -> void:
	_void_travel = maxf(_void_travel,point.distance_to(_press_pos))
	_void_last = point
	reach_point = _void_point(point)
	if wind == null: return
	wind.drag(point)
	# Over the land the drag takes the wind tool in hand (scripts/sky_wind.gd
	# `to_land`); the editor has the gesture from here to the release. With
	# the tray the wind is the Feather: its lane is the Feather's width, and
	# it stays in hand after, pressed in the roll (hand_materials `take_feather`).
	var half: float = materials.feather_half() if materials != null else -1.0
	if _void_travel > CLICK_PIXELS and _land(point) != null and wind.to_land(point,half):
		uses["wind"] = int(uses.get("wind",0))+1
		release(point)
		if materials != null: materials.take_feather()

## The release: a click does nothing, or fires the snap with `--void-snap`; a
## drag is the wind's, a swipe's gust or a held sweep's wind (scripts/sky_wind.gd).
func _void_release(point: Vector2, step: bool) -> void:
	_void_travel = maxf(_void_travel,point.distance_to(_press_pos))
	var click := _void_travel <= CLICK_PIXELS
	var blew := ""
	if wind != null:
		if click: wind.state = ""
		else: blew = wind.release(point)
	release(point)
	if click and sky_snap: fire_snap(step)
	elif not blew.is_empty(): uses["wind"] = int(uses.get("wind",0))+1

## Snap: the hand snaps its fingers and the world cuts to night or day (or,
## with `step`, the next golden hour) in the same frame, with the snap's
## sound (a lighter one for a step).
func fire_snap(step := false) -> void:
	var phase := VoidSnap.snap(scene,step)
	if snap_sound != null: snap_sound.snap(step)
	snaps += 1
	uses["void"] = int(uses.get("void",0))+1
	var hand: Node3D = scene.get("god_hand")
	if hand != null:
		hand.reach_gesture = "void"
		hand.snap()
		_hover_shown = "void"
	_hover_key = []
	snapped.emit(phase,step)

## Held in the void, the hand is loaded to snap while the press is still a
## click (with `--void-snap`), and relaxes once it has become a drag.
func _drive_void_hold(hand: Node3D) -> void:
	if not (hand.reach_gesture.is_empty() or hand.reach_gesture in ["void","snap"]): return
	hand.reach_gesture = "snap" if sky_snap and _void_travel <= CLICK_PIXELS else "void"
	hand.reach_point = reach_point
	_hover_shown = hand.reach_gesture

## True while the camera is moving under the player's hand: a right drag, or
## its view or pivot still gliding from one (a fling, a zoom, a double-click's
## glide). A world turned by the rim or a spin is not the camera moving, nor
## is a followed creature carrying the pivot.
func camera_moving() -> bool:
	if scene.get("_orbiting") == true or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): return true
	var rig: Node = scene.get("camera_rig")
	if rig == null or not "_view_v" in rig: return false
	if (rig._view_v as Vector3).length() > CAMERA_TURNING: return true
	return not rig.following and (rig._pivot_v as Vector3).length() > CAMERA_SLIDING

# --- Modeless: the sky's cloud and trees' spores (docs/scenic/sky-cloud.md)

## The sky source (the cloud) under a pointer and the point on it (world), or [].
func _source_at(point: Vector2) -> Array:
	if cloud == null or not available() or not _editor().pointer_in_world(point): return []
	var at: Variant = cloud.hit(point)
	return [cloud,at] if at != null else []

## The point on a sky source under a pointer (world), or null.
func _cloud_at(point: Vector2) -> Variant:
	var found := _source_at(point)
	return found[1] if not found.is_empty() else null

## A left press on the cloud: the hand pinches it, and nothing
## else sees it.
func _cloud_press(point: Vector2) -> bool:
	var found := _source_at(point)
	if found.is_empty(): return false
	_source = found[0]
	holding = "cloud"
	_press_pos = point
	_pinched = true
	_source.grab(point,found[1])
	reach_point = _editor().terrain.to_local(_source.hand_point())
	_set_cursor(Input.CURSOR_DRAG)
	_show_hint("")
	holding_changed.emit("cloud")
	return true

## A still hold in the void calls the cloud (scripts/sky_cloud.gd `summon`):
## it forms round the hand's pinch, where the hand floats on the pointer's
## ray, and the press is the cloud's from here, so the same hold pulls it.
func _summon() -> void:
	var point := _void_last
	if wind != null: wind.state = ""
	var at: Vector3 = _editor().terrain.to_global(_void_point(point))
	_source = cloud
	holding = "cloud"
	_press_pos = point
	_pinched = false
	cloud.summon(point,at)
	uses["summon"] = int(uses.get("summon",0))+1
	reach_point = _editor().terrain.to_local(cloud.hand_point())
	_set_cursor(Input.CURSOR_DRAG)
	_show_hint("")
	holding_changed.emit("cloud")

## The cloud stretches after the pointer and, pulled far enough, tears a
## tuft off into the hand. Carried over the land the tuft becomes the water
## ball (NativeChunkEditor `ball_from_sky`), which fills from the cloud while
## the editor holds it, until the button is let go.
func _cloud_drag(point: Vector2) -> void:
	_source.pull(point)
	if _source.dry: _show_hint(CLOUD_DRY_HINT)
	if not _source.torn() or _land(point) == null: return
	var editor := _editor()
	if editor.get("water_ball") != true or not editor.has_method("ball_from_sky"): return
	editor.ball_supply = _source.supply
	if not editor.ball_from_sky(point):
		editor.ball_supply = Callable()
		return
	_source.into_ball(editor.ball)
	uses[_source.kind] = int(uses.get(_source.kind,0))+1
	release(point)

## True when a shaping tool is in hand: the clay's Modeller, Paddle, Chisel,
## Wire or Hammer (scripts/land_clay.gd), with no material held and not the
## Feather, nor the tool put down. A press on a tree then works the land
## under it (the landscape audit, docs/design/tools/LANDSCAPE-AUDIT.md: a
## press on a tree did nothing), and the trees near the pointer thin so the
## ground shows (`reveal`).
func shaping() -> bool:
	if not modeless or scene == null or scene.get("land_clay") == null: return false
	if materials == null: return true
	return materials.held.is_empty() and (materials.roll == null or not materials.roll.tool in [HandMaterials.FEATHER,HandMaterials.CAN,HandMaterials.FREE])

## True when the hand has put its tool down (HandMaterials FREE) and holds no
## material: a press on the land works nothing.
func tool_down() -> bool:
	return modeless and materials != null and materials.held.is_empty() and materials.roll != null \
			and materials.roll.tool == HandMaterials.FREE

## The size in hand (the tool roll's pips), as the clay reads it.
func _clay_size() -> float:
	var clay: Node = scene.get("land_clay")
	return float(clay.size_scale) if clay != null else 1.0

## Where the trees thin for the shaping tool (global), or null: the land under
## the pointer while a shaping tool hovers it or works it.
func _reveal_at(eye: bool) -> Variant:
	if eye or not shaping(): return null
	if holding != "land" and not (holding.is_empty() and hover_zone == "land" and available()): return null
	var land: Variant = _land(scene.get_viewport().get_mouse_position() if pointer_override == null else pointer_override)
	return _editor().terrain.to_global(land) if land != null else null

## A left press on a grown tree: the hand takes it by the crown to bend it
## (world play's spring tree, scripts/play_spring_tree.gd, promoted here
## because world play is paused while the editor is active). Let go, it whips
## back, and a rested tree flicks its spores (`_tree_let_go`).
func _tree_press(point: Vector2) -> bool:
	var id := _tree_under(point)
	if id <= 0: return false
	var tree := _tree_node(id,_springing.get(id))
	if tree == null: return false
	holding = "tree"
	_press_pos = point
	_tree = tree
	_tree_id = id
	tree.begin_grab()
	_springing.erase(id)
	var camera: Camera3D = scene.camera
	_tree_plane = Plane(Vector3.UP,tree.center(float(tree.tree_height)*0.6).y)
	var at: Variant = _tree_plane.intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
	_tree_origin = at if at != null else tree.global_position
	reach_point = _editor().terrain.to_local(tree.center(float(tree.tree_height)*0.6))
	_set_cursor(Input.CURSOR_DRAG)
	_show_hint(TREE_HINT if _tree_rested(id) and int(uses.get("tree",0)) < HINT_UNTIL else "")
	holding_changed.emit("tree")
	return true

## World play's object id of the grown tree under a pointer, or -1.
func _tree_under(point: Vector2) -> int:
	var play: Variant = scene.get("world_play")
	if play == null or play.owner_scene == null: return -1
	# A tree already taken (promoted) is not in world play's pick: its own is.
	var id := -1
	for active_id: int in play._active:
		if play._active[active_id] is PlaySpringTree and play._active[active_id].pick(scene.camera,point): id = active_id
	if id <= 0: id = play.pick_object(point)
	if id <= 0 or not str(play._records.get(id,{}).get("asset","")) in play.TREES: return -1
	return id

## The plant a Shift-press at `point` would pluck (its object id), or -1: the
## tree whose mesh is under the pointer, else the plant (`pluckable`) whose
## root stands nearest the ground under it, within PLUCK_REACH. Bigfoot's
## tree under the pointer is nobody's to pluck, and hides what is behind it.
func plant_under(point: Vector2) -> int:
	var tree := _tree_under(point)
	if tree > 0: return tree if pluckable(str(_record(tree).get("asset",""))) else -1
	var land: Variant = _land(point)
	if land == null: return -1
	var at := Vector2(land.x,land.z)
	var best := -1
	var nearest := PLUCK_REACH
	for item: Dictionary in _editor().data.objects:
		if not pluckable(str(item.asset)): continue
		var gap := at.distance_to(Vector2(item.x,item.z))
		if gap < nearest:
			nearest = gap
			best = int(item.id)
	return best

## True for a kind the hand may pluck: PLUCK_TREES or PLUCK_UNDERGROWTH.
static func pluckable(asset: String) -> bool:
	return asset in PLUCK_TREES or asset in PLUCK_UNDERGROWTH

## The object record `id` in the land's data, or {} when there is none.
func _record(id: int) -> Dictionary:
	for item: Dictionary in _editor().data.objects:
		if int(item.id) == id: return item
	return {}

## A Shift-press with a free hand: the plant under it comes up (`pluck`), and
## the press is held as "pluck" until it is let go, so nothing else takes it.
func _pluck_press(point: Vector2) -> bool:
	var id := plant_under(point)
	if id <= 0 or not pluck(id): return false
	holding = "pluck"
	_press_pos = point
	_show_hint("")
	holding_changed.emit("pluck")
	return true

## Pull plant `id` out of the land, as one undo step (the chunk editor's
## `delete_selected`): its record goes, and the ground it stood on is kept
## bare (`_keep_bare`) inside the same step, so emergence does not grow it
## back and one undo brings the plant and its ground back together. A tree
## the hand was springing is let go of first. It pops out of the ground on
## its way (`_pop`). False when `id` is not a plant the hand may pluck.
func pluck(id: int) -> bool:
	var editor := _editor()
	var data: NativeTerrainData = editor.data
	var record := _record(id)
	if record.is_empty() or not pluckable(str(record.asset)) or editor.get("forming") == true: return false
	var parts := _plant_parts(id)
	var root := Vector2(record.x,record.z)
	var base: Vector3 = editor.terrain.to_global(data.object_position(record))
	# A tree still springing back, or promoted for its bend, goes with it.
	_springing.erase(id)
	_tree_springs.erase(id)
	if _tree_id == id:
		_tree = null
		_tree_id = -1
	var play: Variant = scene.get("world_play")
	if play != null and play._active.has(id):
		var node: Variant = play._active[id]
		play._active.erase(id)
		if is_instance_valid(node): node.queue_free()
	if outline != null and outline.tree_id == id: outline.show_tree(-1,[])
	editor.finish_stroke()
	data.begin_stroke()
	data.remove_object(id)
	_keep_bare(root,NativeTerrainData.object_source(record) == "emerged")
	data.end_stroke()
	editor.refresh()
	var tree := str(record.asset) in PLUCK_TREES
	_pop(parts,base,tree)
	var clay: Node = scene.get("land_clay")
	if clay != null and clay.has_method("sound"):
		clay.sound(&"crumble" if tree else &"plant",root,0.8 if tree else 0.5)
		if tree: clay.sound(&"trees",root,0.4)
	plucked += 1
	return true

## The ground a plucked plant stood on stays clear: its cover cells within
## PLUCK_BARE of `root` turn hand-made (as the clay's bared ground does,
## scripts/land_clay.gd `_bare`), which emergence never plants; an `emerged`
## plant's cells also drop to the forest brush's CLEAR_BELOW wish
## (scripts/forest_brush.gd `_settle_clearing`), so the stand round it reads
## the gap as cleared ground. Inside the open undo step.
func _keep_bare(root: Vector2, emerged: bool) -> void:
	var editor := _editor()
	var data: NativeTerrainData = editor.data
	var side := NativeTerrainData.MEADOW_CELLS
	var step := NativeTerrainData.MEADOW_STEP
	var under := data.meadow_cell(root)
	var intent: RefCounted = editor.emergence.intent if editor.get("emergence") != null else null
	var wish: PackedFloat32Array = intent.forest if intent != null else PackedFloat32Array()
	var clear: float = preload("res://scripts/forest_brush.gd").CLEAR_BELOW
	var low := Vector2i(((root-Vector2.ONE*PLUCK_BARE+Vector2(14,14))/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var high := Vector2i(((root+Vector2.ONE*PLUCK_BARE+Vector2(14,14))/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := z*side+x
			if cell != under and (data.meadow_position(x,z)+Vector2.ONE*step*0.5).distance_to(root) > PLUCK_BARE: continue
			data.provenance[cell] = NativeTerrainData.SOURCE_HAND
			if emerged and not wish.is_empty() and wish[cell] > clear: wish[cell] = clear
	if emerged and intent != null:
		intent.forest = wish
		intent.revision += 1

## The drawn parts of plant `id` ([{"mesh", "transform" (world), "material"}]):
## the meshes of the tree world play has promoted, else its instances in the
## land's batches, tinted as world play tints a promoted tree's.
func _plant_parts(id: int) -> Array:
	var parts := []
	var play: Variant = scene.get("world_play")
	var active: Variant = play._active.get(id) if play != null else null
	if is_instance_valid(active):
		for mesh: MeshInstance3D in active.find_children("*","MeshInstance3D",true,false):
			if mesh.visible and mesh.mesh != null: parts.append({"mesh":mesh.mesh,"transform":mesh.global_transform,"material":mesh.get_active_material(0)})
		return parts
	var content: Node = _editor().content
	for batch: MultiMeshInstance3D in content._batches:
		if not is_instance_valid(batch) or batch.multimesh == null or batch.multimesh.mesh == null: continue
		var sources: Array = content._sources.get(batch.get_meta("part"),[])
		for i in range(sources.size()):
			var item: Variant = sources[i].get("item")
			if item == null or int(item.id) != id: continue
			var placed: Variant = content._instance_transform(sources[i])
			if placed == null: continue
			var mesh: Mesh = batch.multimesh.mesh
			var material: Material = batch.material_override if batch.material_override != null else mesh.surface_get_material(0)
			if play != null: material = play._material(material,sources[i].get("color",Color.WHITE))
			parts.append({"mesh":mesh,"transform":batch.global_transform*placed,"material":material})
	return parts

## The plucked plant's pull (PLUCK_SECONDS, its beats above): a copy of its
## `parts` grips, rips, dangles and goes from the ground at `base` (global),
## with a root clod, a soil burst, drifting leaves and a fading hole. A `tree`
## is pulled the full length and height; undergrowth quicker and lower.
## Nothing is kept: the copy frees itself when it has gone.
func _pop(parts: Array, base: Vector3, tree: bool) -> void:
	var pop := Node3D.new()
	pop.name = "PluckPop"
	pop.top_level = true
	add_child(pop)
	var meshes: Array[MeshInstance3D] = []
	var top := base.y
	for part: Dictionary in parts:
		var mesh := MeshInstance3D.new()
		mesh.mesh = part.mesh
		if part.material != null: mesh.material_override = part.material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.top_level = true
		pop.add_child(mesh)
		mesh.global_transform = part.transform
		meshes.append(mesh)
		if part.mesh != null: top = maxf(top,(part.transform*(part.mesh as Mesh).get_aabb()).end.y)
	var height := maxf(top-base.y,0.3)
	var seconds := PLUCK_SECONDS*(1.0 if tree else PLUCK_SMALL)
	var lift := PLUCK_LIFT*(1.0 if tree else 0.5)
	# The root clod: a squat lump of soil under the root, torn out with it.
	var clod := MeshInstance3D.new()
	var lump := SphereMesh.new()
	lump.radius = 0.22 if tree else 0.1
	lump.height = lump.radius*1.3
	lump.radial_segments = 7
	lump.rings = 3
	lump.material = _pluck_paint(PLUCK_SOIL)
	clod.mesh = lump
	clod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clod.top_level = true
	clod.visible = false
	pop.add_child(clod)
	meshes.append(clod)
	var start: Array[Transform3D] = []
	for mesh in meshes: start.append(mesh.global_transform)
	start[start.size()-1] = Transform3D(Basis.IDENTITY,base+Vector3.DOWN*lump.height*0.3)
	# The burst at the rip, and the leaves shed while it dangles.
	var bits := _pluck_bits(PLUCK_BITS,0.07 if tree else 0.045,PLUCK_SOIL,PLUCK_LEAF)
	bits.explosiveness = 0.95
	bits.lifetime = 0.9
	bits.spread = 50.0
	bits.initial_velocity_min = 1.4
	bits.initial_velocity_max = 2.8 if tree else 1.9
	bits.gravity = Vector3(0,-8.0,0)
	pop.add_child(bits)
	bits.global_position = base+Vector3.UP*0.05
	var leaves := _pluck_bits(PLUCK_LEAVES if tree else int(PLUCK_LEAVES*0.5),0.06 if tree else 0.04,PLUCK_LEAF,PLUCK_LEAF.lightened(0.25))
	leaves.one_shot = true
	leaves.explosiveness = 0.2
	leaves.lifetime = 1.6
	leaves.spread = 180.0
	leaves.initial_velocity_min = 0.2
	leaves.initial_velocity_max = 0.6
	leaves.gravity = Vector3(0,-1.1,0)
	leaves.damping_min = 0.6
	leaves.damping_max = 1.2
	leaves.angular_velocity_min = -240.0
	leaves.angular_velocity_max = 240.0
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	leaves.emission_sphere_radius = height*0.25
	pop.add_child(leaves)
	# The hole left in the ground, darkening it and fading.
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.32 if tree else 0.15
	disc.bottom_radius = disc.top_radius
	disc.height = 0.01
	disc.radial_segments = 10
	var dark := _pluck_paint(PLUCK_SOIL.darkened(0.35))
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material = dark
	hole.mesh = disc
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.top_level = true
	hole.visible = false
	pop.add_child(hole)
	hole.global_position = base+Vector3.UP*0.02
	var swing := Vector3(randf_range(-1.0,1.0),0.0,randf_range(-1.0,1.0)).normalized()
	var ripped := [false]
	var step := func(t: float) -> void:
		var lean := 0.0
		var rise := 0.0
		var stretch := 1.0
		var size := 1.0
		var dangling := t >= PLUCK_RIP
		if t < PLUCK_GRIP:
			# Grip: a shiver that builds, and the plant settles into the ground.
			var g := t/PLUCK_GRIP
			lean = sin(g*TAU*4.0)*0.05*g
			rise = -0.04*g
			stretch = 1.0-0.06*g
		elif t < PLUCK_RIP:
			# Rip: up and stretched, the clod with it.
			var r := (t-PLUCK_GRIP)/(PLUCK_RIP-PLUCK_GRIP)
			if not ripped[0]:
				ripped[0] = true
				clod.visible = true
				hole.visible = true
				bits.emitting = true
				leaves.emitting = true
			rise = lift*0.35*(1.0-pow(1.0-r,2.0))
			stretch = lerpf(0.94,1.14,sin(r*PI*0.5))
		elif t < PLUCK_AWAY:
			# Dangle: up the rest of the way, swinging and settling.
			var d := (t-PLUCK_RIP)/(PLUCK_AWAY-PLUCK_RIP)
			rise = lerpf(lift*0.35,lift,1.0-pow(1.0-d,3.0))
			lean = sin(d*TAU*1.6)*0.22*exp(-2.2*d)
			stretch = lerpf(1.14,1.0,minf(d*3.0,1.0))
		else:
			# Away: a flick up, and it shrinks out.
			var a := (t-PLUCK_AWAY)/(1.0-PLUCK_AWAY)
			rise = lift+lift*0.25*a
			size = 1.0-smoothstep(0.0,1.0,a)
		var turn := Basis(swing.cross(Vector3.UP).normalized(),lean) if lean != 0.0 else Basis.IDENTITY
		var shape := Basis.from_scale(Vector3(1.0/sqrt(stretch),stretch,1.0/sqrt(stretch))*maxf(size,0.001))
		# Stretched and shrunk about its root, then lifted; rooted, it shivers
		# about its root, and once out it hangs from the hand above it, so it
		# swings about its top. The lean is nil where the two meet.
		var shaped := Transform3D(shape,base+Vector3.UP*rise)*Transform3D(Basis.IDENTITY,-base)
		var root := base+Vector3.UP*rise
		var pivot := root+Vector3.UP*height*stretch*size if dangling else root
		var held := Transform3D(turn,pivot)*Transform3D(Basis.IDENTITY,-pivot)*shaped
		for i in range(meshes.size()): meshes[i].global_transform = held*start[i]
		leaves.global_position = root+Vector3.UP*height*0.65
	var fade := func(t: float) -> void:
		dark.albedo_color.a = 0.85*(1.0-t)
	var tween := pop.create_tween()
	tween.tween_method(step,0.0,1.0,seconds)
	tween.tween_callback(func() -> void:
		for mesh in meshes: mesh.hide())
	pop.create_tween().tween_method(fade,0.0,1.0,PLUCK_HOLE).set_delay(seconds*PLUCK_RIP)
	tween.tween_interval(maxf(PLUCK_HOLE+seconds*PLUCK_RIP-seconds,leaves.lifetime))
	tween.tween_callback(pop.queue_free)

## A flat-lit, vertex-coloured material for the pluck's pieces.
func _pluck_paint(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 1.0
	return paint

## A one-shot burst of `amount` little cubes `size` m across, coloured
## between `from` and `to`; not yet emitting.
func _pluck_bits(amount: int, size: float, from: Color, to: Color) -> CPUParticles3D:
	var bits := CPUParticles3D.new()
	bits.one_shot = true
	bits.emitting = false
	bits.amount = maxi(amount,1)
	bits.direction = Vector3.UP
	bits.scale_amount_min = 0.5
	bits.scale_amount_max = 1.0
	var crumb := BoxMesh.new()
	crumb.size = Vector3.ONE*size
	crumb.material = _pluck_paint(Color.WHITE)
	bits.mesh = crumb
	var colours := Gradient.new()
	colours.set_color(0,from)
	colours.set_color(1,to)
	bits.color_initial_ramp = colours
	return bits

## Outline tree `id` (or none, for -1): its parts as world play batches them,
## or the meshes of the tree it has promoted. A bent tree is not outlined,
## as the outline would not bend with it.
func _outline_tree(id: int) -> void:
	if outline == null: return
	var parts := []
	var play: Variant = scene.get("world_play")
	if id > 0 and play != null:
		var active: Variant = play._active.get(id)
		if is_instance_valid(active) and active is PlaySpringTree:
			if float(active.tension) < 0.03 and float(active.velocity.length()) < 0.05:
				for child in active.get_children():
					if child is MeshInstance3D and child.visible and child.mesh != null: parts.append({"mesh":child.mesh,"transform":child.global_transform})
		elif play._parts.has(id):
			for part: Dictionary in play._parts[id]: parts.append({"mesh":part.mesh,"transform":part.transform})
		else:
			# Undergrowth (Shift, to pluck): its drawn parts, read once a revision.
			var revision := int(_editor().data.objects_revision)
			if _plant_outline.size() < 3 or _plant_outline[0] != id or _plant_outline[1] != revision:
				_plant_outline = [id,revision,_plant_parts(id)]
			parts = _plant_outline[2]
	if parts.is_empty(): id = -1
	if id == outline.tree_id and id <= 0: return
	outline.show_tree(id,parts)
	if id > 0: outline.spores_ready = _tree_rested(id)

func _tree_rested(id: int) -> bool:
	return Time.get_ticks_msec()-int(_tree_given.get(id,-1000000)) > TREE_REST*1000.0

## The tree bends after the pointer.
func _tree_pull(point: Vector2) -> void:
	_tree = _tree_node(_tree_id,_tree)
	if _tree == null:
		release(point)
		return
	var camera: Camera3D = scene.camera
	var at: Variant = _tree_plane.intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
	if at != null: _tree.drag_to(Vector3(at)-_tree_origin)
	var tension := float(_tree.get("tension"))
	var rested := _tree_rested(_tree_id)
	if not rested and tension > 0.4 and int(uses.get("tree",0)) < HINT_UNTIL: _show_hint(TREE_RESTING_HINT)

## Let the tree go: it springs back (and flings what it hits, as world play's
## release does), stepped here until it rests. Bent far enough, a rested tree
## flicks its spores out the way it whips (`_flick`).
func _tree_let_go() -> void:
	_tree = _tree_node(_tree_id,_tree)
	if _tree == null:
		_tree_id = -1
		return
	var play: Variant = scene.get("world_play")
	var strength := float(_tree.get("tension"))
	if strength >= FLICK_MIN and _tree_rested(_tree_id): _flick(_tree,_tree_id,strength)
	_tree.release()
	_springing[_tree_id] = _tree
	if play != null and not play._habitat_blocked and scene.get("environment_life") != null:
		scene.environment_life.notice_tree_release(_tree,strength)
	_tree = null
	_tree_id = -1

## A tree let go at `tension` throws its spores the way it whips back, against
## the pull, further and thicker the further it was bent (NativeChunkEditor
## `fling_from_tree`); they grow its own kind.
func _flick(tree: Node3D, id: int, tension: float) -> void:
	var editor := _editor()
	var terrain: Node3D = editor.terrain
	var pull: Vector3 = terrain.global_basis.inverse()*Vector3(tree.last_pull)
	var direction := -Vector2(pull.x,pull.z)
	if direction.length() < 0.001: return
	var play: Variant = scene.get("world_play")
	var kind := str(play._records.get(id,{}).get("asset",""))
	if not kind in SPORE_KINDS: kind = ""
	var share := inverse_lerp(FLICK_MIN,1.0,minf(tension,1.0))
	var reach := lerpf(FLICK_REACH.x,FLICK_REACH.y,share)
	var base := terrain.to_local(tree.global_position)
	var crown := terrain.to_local(tree.center(float(tree.tree_height)*0.8))
	if not editor.fling_from_tree(base,crown,direction.normalized(),reach,kind,TREE_STRENGTH*lerpf(0.4,1.0,share)): return
	_tree_given[id] = Time.get_ticks_msec()
	tree_spores += 1
	uses["tree"] = int(uses.get("tree",0))+1
	_show_hint("")

## Trees in hand or springing back are stepped here while world play is
## paused; when it runs it steps its own.
func _step_trees(delta: float) -> void:
	var play: Variant = scene.get("world_play")
	if play == null or not play._paused:
		_springing.clear()
		_tree_springs.clear()
		return
	if holding == "tree":
		_tree = _tree_node(_tree_id,_tree)
		if _tree == null:
			release()
			return
		_tree.advance(delta)
		_keep_spring(_tree_id,_tree)
	for id: int in _springing.keys():
		var tree := _tree_node(id,_springing[id])
		if tree == null:
			_springing.erase(id)
			_tree_springs.erase(id)
			continue
		tree.advance(delta)
		_springing[id] = tree
		if tree.bend == Vector2.ZERO and not tree.held:
			_springing.erase(id)
			_tree_springs.erase(id)
		else:
			_keep_spring(id,tree)

## The tree for object `id`: `known` while it stands, else world play's
## promoted one, else promoted again and given the spring kept for it (a held
## tree is taken hold of again, at the same pull). Null if it is gone.
func _tree_node(id: int, known: Variant) -> Node3D:
	if is_instance_valid(known): return known
	var play: Variant = scene.get("world_play")
	if play == null or id <= 0: return null
	var active: Variant = play._active.get(id)
	var tree: Variant = active if is_instance_valid(active) and active is PlaySpringTree else play.promote(id)
	if not is_instance_valid(tree) or not tree is PlaySpringTree: return null
	var kept: Dictionary = _tree_springs.get(id,{})
	if not kept.is_empty():
		for field: String in SPRING_STATE: tree.set(field,kept[field])
		if kept.held:
			tree.begin_grab()
			tree.drag_to(kept.pull)
	return tree

func _keep_spring(id: int, tree: Node3D) -> void:
	var kept := {"held":tree.held,"pull":tree.last_pull}
	for field: String in SPRING_STATE: kept[field] = tree.get(field)
	_tree_springs[id] = kept
