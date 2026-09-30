extends Node
## The materials tray, an experiment (docs/scenic/modeless.md "Materials tray
## (experiment)"): the linen materials bar along the bottom edge
## (scripts/materials_tray.gd) and the tool roll on the left
## (scripts/tool_roll.gd), design "ZenScape HUD 4c"
## (docs/design/materials-tray/HUD-4c.md). One thing is in hand across both:
## the bare Hand, or one material. The roll's pips (or 1, 2, 3, [ and ]) size
## it: the clay's reach, or a scatter's spread. Esc, the Hand or the material
## again puts a material down. Press a material and
## the hand takes some: it pinches seeds and stones and cups water, and a
## small clump tinted as the specimen rides in it. The hand stays modeless:
## what it holds decides what a press does.
##
## - **Tree seeds** (oak, pine, willow; birch has no slot in 4c). Press and drag over the land:
##   the hand sprinkles the forest brush's veil along the way, and the wind
##   carries it down (NativeChunkEditor `sow_from_hand`, the Forest brush's own
##   veil, scripts/pollen_cloud.gd). The seeds' kind is stamped on the veil, as
##   a flicked tree's spores are: what comes up leans to it, as far as the
##   ground there allows (SEEDS).
## - **Meadow, dandelion and reeds.** Tap to set a drift of flowers or a
##   clump of reeds; drag to scatter more under the hand (SCATTER: the build
##   palette's plants, set down by NativeChunkEditor `set_objects`, one undo
##   step a drag). They sprout as a placed plant does.
## - **Water.** Press and hold over the land: a water ball condenses and fills
##   while held, and drops on release, a pool or a spring as the ground decides
##   (NativeChunkEditor `ball_from_sky`, the cloud tuft's own ball).
## - **Stones.** Tap to set one down, bigger the longer the press; drag to
##   scatter a few pebbles under the hand (the rock tool's placement).
##
## A press in the sky, on the case or on the specimen held puts the material
## back; so does letting go there after drawing it out of the case. A press on
## a compartment not found yet gives nothing. The rim keeps its verbs with
## material in hand. The trees' flick and the cloud still give seeds and water
## as before. `--no-tray` leaves all of this out.
##
## Made by scripts/hand_reach.gd, which hands it the presses first.

const Tray = preload("res://scripts/materials_tray.gd")
const Roll = preload("res://scripts/tool_roll.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Modeless = preload("res://scripts/modeless_input.gd")
## Tree seeds: the specimen and the emergence tree kind it sows
## (scripts/tree_stands.gd TREE_POOLS; "tree" is the spruce family's pine).
const SEEDS := {"oak":"broadleaf","pine":"tree","willow":"willow","birch":"birch"}
## Things set down by a tap or a drag: the assets (one picked for each), how
## many one drop sets and how far they spread (m), a tap's size range (record
## scale, growing over `grow` s of holding) and a drag's (growing over
## `scatter_grow` s), and at most `most` drops a drag.
const SCATTER := {
	"stone":{"assets":["rock"],"each":1,"spread":0.0,"tap":Vector2(0.5,1.4),"grow":1.6,"scatter":Vector2(0.26,0.6),"scatter_grow":2.5,"most":7},
	"wildflower":{"assets":["daisy_flower","spike_flower","umbel_flower"],"each":5,"spread":0.75,"tap":Vector2(0.55,0.9),"grow":1.6,"scatter":Vector2(0.5,0.8),"scatter_grow":2.5,"most":8},
	"dandelion":{"assets":["button_flower","daisy_flower"],"each":4,"spread":0.9,"tap":Vector2(0.5,0.8),"grow":1.6,"scatter":Vector2(0.45,0.75),"scatter_grow":2.5,"most":8},
	"reed":{"assets":["reeds"],"each":3,"spread":0.4,"tap":Vector2(0.6,1.0),"grow":1.6,"scatter":Vector2(0.55,0.85),"scatter_grow":2.5,"most":8},
}
## Cupped, not pinched.
const CUPPED := ["water"]
## The hand carrying floats CARRY_LIFT m over the pointer's ground point.
## Over the tray it floats TRAY_DEPTH of the camera's distance out along the
## pointer's ray (nearer than the void's: the near land lies under the tray).
const CARRY_LIFT := 0.8
const TRAY_DEPTH := 0.55
const TRAY_NEAR := 4.0
## A drag drops a set every STONE_GAP m under the hand, no sooner than
## STONE_SECONDS apart (and only once the last has been drawn and has landed).
const STONE_GAP := 0.9
const STONE_SECONDS := 0.3
## Screen pixels a press may wander and still be a tap.
const CLICK_PIXELS := 6.0
## The hint line with material in hand, until each has been used once.
const SOW_HINT := "Drag over the land to sow"
const HINTS := {"water":"Hold over the land to pour","stone":"Tap to set a stone  ·  Drag to scatter pebbles",
	"wildflower":"Tap to sow a drift of flowers  ·  Drag to scatter","dandelion":"Tap to sow a drift of flowers  ·  Drag to scatter","reed":"Tap to set reeds  ·  Drag to scatter"}
const BACK_HINT := "Click the sky or the case to put it back"
## Design units the Lantern hint line moves up to clear the case.
const HINT_LIFT := 100.0

static func enabled() -> bool:
	return Modeless.enabled() and not "--no-tray" in OS.get_cmdline_user_args()

var scene: Node3D
var reach: Node
var tray: Control
var roll: Control
var clump: Clump
## The specimen in hand (a materials_tray.gd SPECIMENS id) or "".
var held := ""
## Stones, flowers and reeds set down, for probes.
var stones_set := 0
var _press_pos := Vector2.ZERO
var _left_tray := false
var _held_seconds := 0.0
var _travel := 0.0
var _stone_last: Variant = null
var _stone_step: Variant = null
var _stone_count := 0
var _stone_since := 0.0
var _carry_shown := false
var _shell_lifted := false

func setup(owner_scene: Node3D, hand_reach: Node) -> void:
	scene = owner_scene
	reach = hand_reach
	name = "HandMaterials"
	var layer := CanvasLayer.new()
	layer.name = "MaterialsTrayLayer"
	layer.layer = 19
	add_child(layer)
	tray = Tray.new()
	layer.add_child(tray)
	roll = Roll.new()
	layer.add_child(roll)
	clump = Clump.new()
	clump.name = "HeldMaterial"
	reach._editor().terrain.add_child(clump)

## True over the materials bar or the tool roll, while they show.
func tray_under(point: Vector2) -> bool:
	return (tray != null and tray.contains_pointer(point)) or (roll != null and roll.contains_pointer(point))

## The size in hand (the roll's pips): the clay's reach and a scatter's spread.
func size_scale() -> float:
	return roll.size_scale() if roll != null else 1.0

func set_size(level: int) -> void:
	if roll == null: return
	roll.size_level = clampi(level,0,Roll.SIZES.size()-1)
	var clay: Node = scene.get("land_clay")
	if clay != null: clay.size_scale = roll.size_scale()

## Keys for the hand's HUD: 1, 2, 3 or [ and ] size what is in hand; Esc puts
## a material down (back to the bare Hand). True when the key was used.
func key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo or roll == null or roll.shown < 0.5: return false
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed: return false
	match event.keycode:
		KEY_1, KEY_2, KEY_3: set_size(event.keycode-KEY_1)
		KEY_BRACKETLEFT: set_size(roll.size_level-1)
		KEY_BRACKETRIGHT: set_size(roll.size_level+1)
		KEY_ESCAPE:
			if held.is_empty(): return false
			put_back()
		_: return false
	return true

func _pointer() -> Vector2:
	return scene.get_viewport().get_mouse_position() if reach.pointer_override == null else reach.pointer_override

# --- Presses ----------------------------------------------------------------------

## A left press the hand reach has let through (nothing held, the hand free).
## True when it was the case's or the material's.
func press(point: Vector2) -> bool:
	# The tool roll: the pips size what is in hand; the Hand puts a material down.
	var pip: int = roll.pip_at(point)
	if pip >= 0:
		set_size(pip)
		return true
	var tool: String = roll.tool_at(point)
	if not tool.is_empty():
		if not roll.discovered(tool): roll.not_yet(tool)
		elif tool == "hand": put_back()
		return true
	if roll.contains_pointer(point): return true
	var specimen: String = tray.specimen_at(point)
	if not specimen.is_empty():
		if not tray.discovered(specimen):
			tray.not_yet(specimen)
			return true
		if specimen == held: put_back()
		else:
			if not held.is_empty(): put_back()
			_take(specimen)
		_press_pos = point
		_left_tray = false
		reach.take_hold("jar",point)
		return true
	if tray.contains_pointer(point):
		put_back()
		return true
	if held.is_empty(): return false
	# The rim keeps its verbs; the land is the material's; the sky puts it back.
	if reach.reach_at(point) == "rim": return false
	if reach._land(point) != null:
		_use(point)
		return true
	if reach._editor().pointer_in_world(point):
		put_back()
		return true
	return false

func _take(id: String) -> void:
	held = id
	tray.lift_out(id)
	# A quiet tick belongs here when the tray has sound.
	clump.show_kind(id)

## The specimen goes home to its compartment.
func put_back() -> void:
	if held.is_empty(): return
	var from := _pointer()
	if clump.visible and not scene.camera.is_position_behind(clump.global_position): from = scene.camera.unproject_position(clump.global_position)
	tray.return_home(held,from)
	reach.uses["tray_back"] = int(reach.uses.get("tray_back",0))+1
	held = ""
	clump.hide_away()

## A press over the land with material in hand. Seeds and water go to the
## editor, which holds them until the button comes up; what is set down by
## hand is held here.
func _use(point: Vector2) -> void:
	var editor: Node = reach._editor()
	if SEEDS.has(held):
		if editor.has_method("sow_from_hand") and editor.sow_from_hand(point,SEEDS[held]): _used()
	elif held == "water":
		if editor.get("water_ball") != true: return
		editor.ball_supply = Callable()
		if editor.ball_from_sky(point): _used()
	elif SCATTER.has(held):
		reach.take_hold("scatter",point)
		_press_pos = point
		_held_seconds = 0.0
		_travel = 0.0
		_stone_last = null
		_stone_step = null
		_stone_count = 0
		_stone_since = STONE_SECONDS

func _used() -> void:
	reach.uses[held] = int(reach.uses.get(held,0))+1
	reach._show_hint("")

## The pointer moves while the hand holds "jar" or "scatter".
func drag(point: Vector2) -> void:
	_travel = maxf(_travel,point.distance_to(_press_pos))
	if reach.holding != "jar": return
	if tray.contains_pointer(point): return
	_left_tray = true
	if held.is_empty() or reach._land(point) == null or reach.reach_at(point) == "rim": return
	# Drawn out of the case onto the land: the press is the material's from here.
	reach.drop_hold()
	_use(point)

## The hold of "jar" or "scatter" ends at `point` (Vector2.INF: the window lost it).
func let_go(what: String, point: Vector2) -> void:
	var known := point != Vector2.INF
	var over_land: bool = known and reach._land(point) != null
	var home: bool = known and not over_land and reach.reach_at(point) != "rim"
	if what == "jar":
		# Drawn out and let go in the sky or back on the case.
		if _left_tray and home: put_back()
		return
	if _stone_count == 0 and SCATTER.has(held):
		var spec: Dictionary = SCATTER[held]
		if _travel <= CLICK_PIXELS: _drop(_ground(_press_pos),lerpf(spec.tap.x,spec.tap.y,smoothstep(0.12,float(spec.grow),_held_seconds)))
		elif over_land: _drop(_ground(point),_scatter_size())
		elif home: put_back()
	elif home: put_back()
	_stone_step = null

func _scatter_size() -> float:
	var spec: Dictionary = SCATTER[held]
	return lerpf(spec.scatter.x,spec.scatter.y,smoothstep(0.0,float(spec.scatter_grow),_held_seconds))

## The plate point under a pointer, or null.
func _ground(point: Vector2) -> Variant:
	var hit: Variant = reach._land(point)
	return Vector2(hit.x,hit.z) if hit != null else null

## Sets down one drop of what is held at `at` (plate): a stone, or a drift of
## flowers or reeds round it.
func _drop(at: Variant, size: float) -> bool:
	if at == null or not SCATTER.has(held): return false
	var spec: Dictionary = SCATTER[held]
	var items := []
	for i in range(int(spec.each)):
		var offset := Vector2.ZERO
		if i > 0: offset = Vector2.from_angle(randf()*TAU)*float(spec.spread)*size_scale()*sqrt(randf())
		var assets: Array = spec.assets
		items.append({"asset":assets[randi()%assets.size()],"point":at+offset,"size":size*randf_range(0.88,1.12)*(1.0 if i == 0 else randf_range(0.75,1.0)),"angle":randf()*TAU})
	var step: Variant = reach._editor().set_objects(items,_stone_step)
	if step == null: return false
	_stone_step = step
	_stone_last = at
	_stone_count += 1
	_stone_since = 0.0
	stones_set += 1
	reach.uses[held] = int(reach.uses.get(held,0))+1
	clump.shed()
	return true

# --- Frames -----------------------------------------------------------------------

## Each frame, after the hand reach has driven the hand.
func step(delta: float) -> void:
	var wanted := _tray_wanted()
	tray.want(wanted)
	roll.want(wanted)
	# A drag under way (a rim pull, the clay, a sowing) never wakes the bars.
	var quiet: bool = not str(reach.holding) in ["","jar"]
	tray.quiet = quiet
	roll.quiet = quiet
	roll.material_held = not held.is_empty()
	roll.held_tint = Icons.item(held if not held.is_empty() else roll.tool).get("tint",roll.held_tint)
	# The Lantern hint line sits just over the case.
	var shell: Node = scene.get("creation_palette")
	if not _shell_lifted and shell != null and "bottom_lift" in shell:
		shell.bottom_lift = HINT_LIFT
		shell.fit()
		_shell_lifted = true
	if reach.holding == "scatter": _scatter(delta)
	var hand: Node3D = scene.get("god_hand")
	var at: Variant = reach.reach_point
	var share := 1.0
	var size := 1.0
	if hand != null:
		# It fades with the hand, as the camera moves.
		share = float(hand.opacity) if hand.visible else 0.0
		if hand.visible:
			at = hand.hold_at(not held in CUPPED)
			size = hand.basis.get_scale().x/float(hand.HAND_METRES)
	if at == null: at = clump.position
	if held.is_empty() or not _carry_shown: clump.hide_away()
	elif clump.kind != held or clump.target == 0.0: clump.show_kind(held)
	var growing: bool = reach.holding == "scatter" and _travel <= CLICK_PIXELS and SCATTER.has(held)
	clump.grow = smoothstep(0.12,float(SCATTER[held].grow),_held_seconds) if growing else 0.0
	clump.advance(delta,at,size,share)
	_carry_shown = false

func _tray_wanted() -> bool:
	var editor: Node = reach._editor()
	if editor == null or editor.forming or scene.camera == null: return false
	if scene.get("_has_world") == false or scene.get("crafting") == true or scene.get("titled") == true: return false
	var menu: Control = scene.get("_menu")
	if menu != null and menu.visible: return false
	for key: String in ["photo","wanderer"]:
		var node: Node = scene.get(key)
		if node != null and node.get("active") == true: return false
	return true

## A held drag sets more down under the hand as it goes.
func _scatter(delta: float) -> void:
	_held_seconds += delta
	_stone_since += delta
	if not SCATTER.has(held): return
	if _travel <= CLICK_PIXELS or _stone_count >= int(SCATTER[held].most) or _stone_since < STONE_SECONDS: return
	var editor: Node = reach._editor()
	if int(editor.refresh_pending) > 0 or editor.reactions.active_count() > 0: return
	var at: Variant = _ground(_pointer())
	if at == null: return
	if _stone_last == null or (at as Vector2).distance_to(_stone_last) >= STONE_GAP*size_scale(): _drop(at,_scatter_size())

## The hand while material is in hand, or over the case: it pinches or cups
## what it carries over the land and in the sky, and floats ready over the
## case. False when it has nothing to show, so the hand reach drives it.
func drive_hand(hand: Node3D) -> bool:
	var holding: String = reach.holding
	if not holding in ["","jar","scatter"]: return false
	var carrying := not held.is_empty()
	var pointer := _pointer()
	var gesture := ("summon" if held in CUPPED else "cloud") if carrying else "void"
	var at: Variant = null
	if holding == "jar":
		var ground: Variant = reach._land(pointer)
		at = _carry_point(ground) if ground != null else _tray_point(pointer)
	elif holding == "scatter":
		var ground: Variant = reach._land(pointer)
		at = _carry_point(ground) if ground != null else reach._void_point(pointer)
	else:
		if not reach.available(): return false
		if reach.hover_zone == "tray": at = _tray_point(pointer)
		elif not carrying: return false
		elif reach.hover_zone == "land": at = _carry_point(reach._hover_point)
		elif reach.hover_zone in ["void","cloud"]: at = reach._void_point(pointer)
		else: return false
		hand.held_off = reach.camera_moving()
	if holding.is_empty() and not (hand.reach_gesture.is_empty() or hand.reach_gesture == reach._hover_shown): return true
	reach._set_hand(hand,gesture,at,null)
	_carry_shown = carrying
	return true

func _carry_point(ground: Vector3) -> Vector3:
	return ground+Vector3.UP*CARRY_LIFT

func _tray_point(point: Vector2) -> Vector3:
	var camera: Camera3D = scene.camera
	var depth := maxf(float(scene.get("distance"))*TRAY_DEPTH,TRAY_NEAR)
	return reach._editor().terrain.to_local(camera.project_ray_origin(point)+camera.project_ray_normal(point)*depth)

## The hint with material in hand: its verb over the land, the way home over
## the sky. [zone, text], or ["", ""].
func hint(zone: String) -> Array:
	if held.is_empty(): return ["",""]
	if zone == "land": return [held,SOW_HINT if SEEDS.has(held) else str(HINTS.get(held,""))]
	if zone in ["void","cloud"]: return ["tray_back",BACK_HINT]
	return ["",""]

## The clump that rides in the hand: a few seeds, a droplet or pebbles, tinted
## as the specimen taken. It pops in when taken, sheds a little as a drop is
## set down, swells as a still press grows a stone, and shrinks away when used
## or put back.
class Clump extends Node3D:
	## Pop spring (1/s², 1/s), under-damped so it overshoots once.
	const SPRING := 220.0
	const DAMP := 11.0
	## Seed tones by specimen (sRGB): acorn browns, pine-seed umber, willow
	## down, birch straw, flower seed with a petal or two, reed brown.
	const TONES := {
		"oak":["a57b48","8c6a3f","c09a66"],"pine":["7a5a3a","946f48","6a4c30"],"willow":["dcd8c4","c9c6ae","ece8d6"],
		"birch":["c9ab7a","b89868","dcc190"],"wildflower":["c9a86a","f2c53d","e38aa0"],"dandelion":["efe9d6","d8cfb4","b89a5e"],"reed":["8a6a45","7a5c3a","a07e56"],
	}
	var kind := ""
	var target := 0.0
	var grow := 0.0
	var _size := 0.0
	var _speed := 0.0
	var _shed := 0.0
	var _time := 0.0
	var _parts: Array[MeshInstance3D] = []
	var _rest: Array[Vector3] = []

	func _init() -> void:
		visible = false

	func show_kind(next: String) -> void:
		if next != kind: _build(next)
		kind = next
		if target == 0.0:
			target = 1.0
			if _size < 0.05:
				_size = 0.0
				_speed = 0.0

	func hide_away() -> void:
		target = 0.0

	func shed() -> void:
		_shed = 1.0

	func advance(delta: float, at: Vector3, hand_size: float, share: float) -> void:
		delta = minf(delta,0.05)
		_time += delta
		if target > 0.0:
			_speed += ((target-_size)*SPRING-_speed*DAMP)*delta
			_size += _speed*delta
		else:
			_size = move_toward(_size,0.0,delta*7.0)
			_speed = 0.0
		_shed = move_toward(_shed,0.0,delta*3.0)
		var s := maxf(_size,0.0)*hand_size*share*(1.0+0.45*grow)*(1.0-0.35*_shed*_shed)
		visible = s > 0.01
		if not visible: return
		position = at
		scale = Vector3.ONE*s
		# A small living wobble, never still.
		rotation = Vector3(sin(_time*1.3)*0.12,_time*0.4,cos(_time*1.1)*0.1)
		for i in range(_parts.size()):
			_parts[i].position = _rest[i]+Vector3(0.0,sin(_time*2.3+i*1.7)*0.012,0.0)

	func _build(next: String) -> void:
		for part in _parts: part.queue_free()
		_parts.clear()
		_rest.clear()
		if TONES.has(next):
			var tones: Array = TONES[next]
			# Reed seed is slender; the rest are plump.
			var shape := Vector3(0.03,0.03,0.1) if next == "reed" else Vector3(0.05,0.045,0.085)
			for i in range(6):
				var angle := TAU*i/6.0
				_part(_egg(),Color(tones[i%3]),Vector3(cos(angle)*0.07,(i%2)*0.04,sin(angle)*0.07),shape,Vector3(0.3*i,angle,0.2),0.7)
			return
		match next:
			"water":
				_part(_ball(),Color("8ecaf0"),Vector3.ZERO,Vector3(0.16,0.19,0.16),Vector3.ZERO,0.08)
				_part(_ball(),Color("f4fbff"),Vector3(-0.05,0.07,0.1),Vector3.ONE*0.035,Vector3.ZERO,0.1)
			"stone":
				_part(_pebble(),Color("a89d91"),Vector3(0.0,0.0,0.0),Vector3(0.13,0.085,0.11),Vector3(0.2,0.4,0.1),0.85)
				_part(_pebble(),Color("c6bbae"),Vector3(0.05,0.075,0.03),Vector3(0.085,0.06,0.08),Vector3(-0.3,1.2,0.2),0.85)
				_part(_pebble(),Color("b7ab9f"),Vector3(-0.1,0.02,0.06),Vector3(0.055,0.045,0.05),Vector3(0.5,2.0,-0.2),0.85)

	func _part(mesh: Mesh, colour: Color, at: Vector3, size: Vector3, turn: Vector3, rough: float) -> void:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = rough
		# A little light of its own, so it reads by night and in the hand's glow.
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 0.22
		if rough < 0.2:
			material.metallic_specular = 0.9
			material.rim_enabled = true
			material.rim = 0.6
		node.material_override = material
		node.position = at
		node.rotation = turn
		node.scale = size
		add_child(node)
		_parts.append(node)
		_rest.append(at)

	static func _egg() -> Mesh:
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		return mesh

	static func _ball() -> Mesh:
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 20
		mesh.rings = 10
		return mesh

	## Faceted, like the land's stones.
	static func _pebble() -> Mesh:
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 7
		mesh.rings = 4
		return mesh
