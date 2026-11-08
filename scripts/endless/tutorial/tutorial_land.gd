extends Node
## The land that teaches (docs/ship/spec-ship.md, Round 2, lane
## `tutorial-land`): `game.tutorial_land` while the world is `tutorial`
## (scripts/endless/world/profiles/tutorial.gd).
##
## The contract: it reads `game.lesson.stage` when `game.get("lesson")`
## exists, else the `--lesson-stage=N` launch flag (0 GRASS, 1 TREES, 2 WATER,
## 3 GAUGE, 4 WALL, 5 DONE), and emits `broke_through` once the wall is
## broken and the plane has swapped to the wilderness.
##
##   the gating   the stage goes to the world profile (`stage`), which gates
##                what the meadow builds from then on: tree blocks committed
##                below TREES stand bare; ponds and straight reaches only in
##                squares first asked at WATER or later, outside DRY m of the
##                plane at that moment. On each change the tree blocks past
##                REPLAN_PAST m are dropped and planned again under the new
##                stage, so the new land shows from there out; the near ones
##                (and their solids) stay as they stood.
##   the wall     at WALL the ruin hall (tutorial_hall.gd) stands HALL_AHEAD m
##                ahead of the plane, a cracked wall across its mouth, a
##                beam of light over it; flown away from past HALL_LOST m with
##                the wall whole, it stands again ahead. A surge roll breaks
##                the wall; through the hall the land swaps to the wilderness.
##   the deck     a flat cloud deck DECK m over the turf: from under, a pale
##                ceiling; climbing into it whites the view out, descending
##                clears it. Nothing touches the flight.

signal broke_through

const Hall = preload("res://scripts/endless/tutorial/tutorial_hall.gd")

enum Stage {GRASS, TREES, WATER, GAUGE, WALL, DONE}

## The cloud deck's underside over the turf (m), and the whiteout's ramp
## (m below it to m into it).
const DECK := 60.0
const WHITE_FROM := -10.0
const WHITE_FULL := 8.0
const DECK_SIZE := 16000.0
## No ponds within this of the plane when WATER comes (m): past the land
## standing at its finest and colliding.
const DRY := 450.0
## Tree blocks wholly past this (m) are planned again on a stage change.
const REPLAN_PAST := 420.0
## The hall's mouth ahead of the plane at WALL (m), and how far off it may be
## left before it stands ahead again.
const HALL_AHEAD := 780.0
const HALL_LOST := 3000.0
## Trees held off the ruin and the way in (m).
const KEEP_RUIN := 190.0
const KEEP_WAY := 140.0

var game: Node3D
var world: RefCounted
var stage := -1
var hall: Node3D
var done := false
var _flag_stage := 0
var _deck: MeshInstance3D
var _white: ColorRect
var _beam: MeshInstance3D
var _turf := 0.0

func setup(g: Node3D) -> void:
	name = "TutorialLand"
	game = g
	world = g.world
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--lesson-stage="): _flag_stage = clampi(a.get_slice("=",1).to_int(),0,Stage.DONE)
	var at: Vector2 = world.spawn.at
	_turf = float(game.field.height(at.x,at.y))
	if not ("--no-deck" in preload("res://scripts/launch_args.gd").user_args()): _build_deck()
	_set_stage(wanted_stage())

## The stage the lesson asks for (its own, else the flag's).
func wanted_stage() -> int:
	var lesson: Variant = game.get("lesson")
	if lesson != null and is_instance_valid(lesson): return int(lesson.stage)
	return _flag_stage

## Sets the flag's stage by hand (scratch drivers): as `--lesson-stage=N`.
func force_stage(s: int) -> void:
	_flag_stage = s

func _process(_delta: float) -> void:
	if game == null or game.plane == null: return
	var s := wanted_stage()
	if s != stage: _set_stage(s)
	if stage >= Stage.WALL and hall == null and not done and bool(game.get("walk_ready")): _place_hall()
	if hall != null: _watch_hall()
	_step_deck()

func _set_stage(s: int) -> void:
	var was := stage
	stage = s
	if not done: world.stage = mini(s,Stage.WALL)
	print("tutorial land: stage %d (was %d)" % [s,was])
	if was < 0: return
	if s >= Stage.WATER and was < Stage.WATER:
		var p: Vector3 = game.plane.position
		world.dry_at = Vector2(p.x,p.z)
		world.dry_r = DRY
	_replan(REPLAN_PAST)

## The tree blocks wholly past `past` m of the plane dropped, to be planned
## again under the stage now (LandTrees streams them back in).
func _replan(past: float) -> void:
	var trees: Node = game.get("trees")
	if trees == null or not ("_blocks" in trees): return
	var p: Vector3 = game.plane.position
	var block: float = trees.BLOCK
	var drop: Array[Vector2i] = []
	for key: Vector2i in trees._blocks:
		var lo := Vector2(key.x*block,key.y*block)
		var near := Vector2(clampf(p.x,lo.x,lo.x+block),clampf(p.z,lo.y,lo.y+block))
		if near.distance_to(Vector2(p.x,p.z)) > past and world.side(lo.x+block*0.5,lo.y+block*0.5) == 1: drop.append(key)
	for key: Vector2i in drop: trees._free_block(key)
	trees._planned_at = Vector3.INF
	print("tutorial land: %d tree blocks planned again" % drop.size())

# --- The wall ------------------------------------------------------------------

func _place_hall() -> void:
	var p: Vector3 = game.plane.position
	var v: Vector3 = game.plane.velocity
	var way := Vector2(v.x,v.z)
	if way.length() < 1.0: way = Vector2(-sin(float(game.plane.heading)),-cos(float(game.plane.heading)))
	way = way.normalized()
	var at := Vector2(p.x,p.z)+way*HALL_AHEAD
	world.keep_off = [[at+way*80.0,KEEP_RUIN],[at-way*170.0,KEEP_WAY]]
	if game.doors != null:
		push_warning("tutorial land: the world already has doors; the hall replaces them")
		game.doors.queue_free()
	hall = Hall.new()
	game.add_child(hall)
	hall.place(game,at,way,int(game.seed))
	game.doors = hall
	_build_beam()
	_replan(REPLAN_PAST)

## The hall stood ahead again when it has been left far behind (the wall
## whole); the swap seen through to the end.
func _watch_hall() -> void:
	if done: return
	if hall.through():
		done = true
		world.keep_off = []
		if _deck != null: _deck.visible = false
		if _beam != null: _beam.visible = false
		print("tutorial land: broke through to the wilderness at %s" % str(game.plane.position.round()))
		broke_through.emit()
		return
	var p: Vector3 = game.plane.position
	var m: Vector3 = hall.mouth()
	if not hall.inside_hall and not hall.broken() and Vector2(p.x-m.x,p.z-m.z).length() > HALL_LOST: _drop_hall()

func _drop_hall() -> void:
	var cw: Node = game.smash.walls
	var site: Dictionary = cw.sites.get(hall.wall_handle,{})
	if str(site.get("state","")) == "building": return
	if str(site.get("state","")) == "up": cw._free(site)
	cw.sites.erase(hall.wall_handle)
	if hall.lands[0] != null and hall.lands[0] != game.land: hall.lands[0].queue_free()
	game.doors = null
	hall.queue_free()
	hall = null
	if _beam != null:
		_beam.queue_free()
		_beam = null
	print("tutorial land: the hall left behind; it stands ahead again")
	_place_hall()

## A column of light over the ruin, seen from far over the meadow.
func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "HallBeam"
	var c := CylinderMesh.new()
	c.top_radius = 5.0
	c.bottom_radius = 7.0
	c.height = 420.0
	c.radial_segments = 16
	c.cap_top = false
	c.cap_bottom = false
	_beam.mesh = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0,0.78,0.42,0.55)
	m.disable_fog = true
	_beam.material_override = m
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(_beam)
	# Over the ruin's back, clear of the way in.
	var f: Transform3D = hall._frames[1]
	_beam.global_position = f*Vector3(0.0,0.0,float(hall._out)+40.0)+Vector3.UP*(c.height*0.5+20.0)

# --- The deck ------------------------------------------------------------------

func _build_deck() -> void:
	_deck = MeshInstance3D.new()
	_deck.name = "CloudDeck"
	var pm := PlaneMesh.new()
	pm.size = Vector2(DECK_SIZE,DECK_SIZE)
	pm.subdivide_width = 31
	pm.subdivide_depth = 31
	_deck.mesh = pm
	_deck.custom_aabb = AABB(Vector3(-DECK_SIZE*0.5,-40.0,-DECK_SIZE*0.5),Vector3(DECK_SIZE,80.0,DECK_SIZE))
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, shadows_disabled;
uniform vec3 tone = vec3(0.9, 0.92, 0.95);
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	float puff = n(wp.xz / 90.0) * 0.6 + n(wp.xz / 23.0) * 0.4;
	ALBEDO = tone * mix(0.8, 1.02, puff);
	ALPHA = mix(0.78, 0.96, puff) * (1.0 - smoothstep(3000.0, 7800.0, d));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_deck.material_override = m
	_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_deck)
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_white = ColorRect.new()
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.color = Color(0.93,0.94,0.96,0.0)
	_white.visible = false
	layer.add_child(_white)

func _step_deck() -> void:
	if _deck == null: return
	var eye: Vector3 = (game.camera as Camera3D).global_position
	var on: bool = not done and int(world.side(eye.x,eye.z)) == 1
	var deck_y := _turf+DECK
	_deck.visible = on and eye.y < deck_y+WHITE_FULL
	_deck.global_position = Vector3(eye.x,deck_y,eye.z)
	var w := smoothstep(deck_y+WHITE_FROM,deck_y+WHITE_FULL,eye.y) if on else 0.0
	_white.visible = w > 0.002
	_white.color.a = w*0.98

## Whether the eye is in the deck (for drivers).
func whited() -> float:
	return _white.color.a if _white != null and _white.visible else 0.0
