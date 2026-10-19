extends "res://studies/character_study.gd"
## The climbing rope study (docs/design/rope/spec-rope.md): a greybox room
## for the wanderer's own rope and hook. The wanderer is the game's own (the
## character study's motor, figure, camera and input), on a reduced
## moveset: walk, run, jump and the slide; no wall moves, ledge grabs, sail
## or updraft (the motor's `wall_on`, `ledge_on`, `sail_on`, `rope_on`
## gates). M (pad left) toggles his full moveset back on, to compare.
##
## The room, plain grey:
## - the start floor (y 0);
## - a 5 m wall with a solid (orange) lip to hook;
## - an 8 m face with an anchor post on top;
## - two 5 m edges side by side: a crumbly (tan) lip that slips, and a
##   solid one;
## - a 5 m tower on the floor's east rim whose far side drops 9 m to the
##   lower floor (y -4), an anchor at that edge, to rappel;
## - loot up top and below; walk into a piece to take it.
##
## Every structure and loot piece is named `rope_study/<piece>` through
## scripts/layout_overrides.gd, so the world view (F4) moves them. Each
## structure keeps its hold (`holds`): "solid", "poor" or "anchor".
##   ./run-rope-study.command
##   godot --path . res://studies/rope_study.tscn -- --no-title
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const DevKeys = preload("res://scripts/kit_isle/dev_keys.gd")
const BagStudy = preload("res://studies/bag_study.gd")
const ClimbRope = preload("res://scripts/rope/climb_rope.gd")

const SCENE_ID := "rope_study"
## The two floors (x, z) and their tops.
const UPPER := Rect2(-20.0,-20.0,34.0,40.0)
const LOWER := Rect2(14.0,-20.0,22.0,40.0)
const LOW_Y := -4.0
const FLOOR_DEPTH_HERE := 4.0
## The room's walls stand this high over the upper floor.
const WALL_TOP := 2.0
## The heights: the wall and the edges (5 m, past any jump), the face (8 m).
const WALL_H := 5.0
const FACE_H := 8.0
## The tower: on the lower floor, its top WALL_H over the upper floor; its
## near face rises from the upper floor's east rim (x 14), its far face
## drops to the lower floor.
const TOWER := Rect2(14.0,-5.0,6.0,10.0)
## An anchor post: its radius and how high it stands over its top.
const POST_R := 0.16
const POST_H := 1.0
## Taking loot: within this of a piece's foot (m, flat) and this of its
## height.
const TAKE_REACH := 0.9
const TAKE_RISE := 1.4
## The crumbly lip's colour (its band and the hint).
const CRUMBLE := Color(0.78,0.66,0.46)

## The named structures: [name, part, hold] (character_study's part formats:
## "box" Rect2, bottom, top, colour; "cyl" middle, radius, bottom, top,
## colour). A "lip" box's top edge is a solid hold (an orange band), a
## "crumble" box's a poor one (a tan band); a post is an anchor.
const PIECES := [
	# The 5 m wall with a solid lip.
	["wall",["box",Rect2(-16.0,-12.0,8.0,4.0),0.0,WALL_H,"lip"],"solid"],
	# The 8 m face, its anchor post near the edge over the start floor.
	["face",["box",Rect2(-3.0,-18.0,8.0,6.0),0.0,FACE_H,"grey"],""],
	["face_post",["cyl",Vector2(1.0,-12.7),POST_R,FACE_H,FACE_H+POST_H,"dark"],"anchor"],
	# The crumbly edge, and the solid one beside it.
	["crumble_edge",["box",Rect2(5.5,-12.0,4.0,4.0),0.0,WALL_H,"crumble"],"poor"],
	["solid_edge",["box",Rect2(9.5,-12.0,4.0,4.0),0.0,WALL_H,"lip"],"solid"],
	# The tower and its anchor at the drop's edge.
	["tower",["box",TOWER,LOW_Y,WALL_H,"lip"],"solid"],
	["tower_post",["cyl",Vector2(TOWER.end.x-0.7,0.0),POST_R,WALL_H,WALL_H+POST_H,"dark"],"anchor"],
	# A guard rail along the upper floor's east rim, but for the tower.
	["rim_n",["box",Rect2(13.6,-20.0,0.4,15.0),0.0,1.0,"grey"],""],
	["rim_s",["box",Rect2(13.6,5.0,0.4,15.0),0.0,1.0,"grey"],""],
]

## The loot: [id, kind, kg, foot (world), yaw deg] (the bag study's kinds).
const LOOT := [
	["loot_01","idol",3.0,Vector3(-12.0,WALL_H,-10.5),30.0],
	["loot_02","chalice",1.5,Vector3(2.5,FACE_H,-15.0),160.0],
	["loot_03","gem",0.5,Vector3(7.5,WALL_H,-10.5),0.0],
	["loot_04","bar",4.0,Vector3(11.5,WALL_H,-10.5),70.0],
	["loot_05","urn",6.0,Vector3(16.0,WALL_H,2.5),200.0],
	["loot_06","coins",2.0,Vector3(27.0,LOW_Y,4.0),0.0],
	["loot_07","egg",12.0,Vector3(31.0,LOW_Y,-8.0),90.0],
]

## Each structure's hold, by its id: "solid", "poor", "anchor" (none: no
## entry). Its node: `pieces[id]`.
var holds: Dictionary = {}
var pieces: Dictionary = {}
## Each loot piece: {id, kind, kg, spot (the named node), taken}.
var loot: Array = []
## The loot he has taken, in kg and pieces.
var taken_kg := 0.0
var taken := 0
## His full moveset on (M / pad left), else the rope study's reduced one.
var full_moves := false
## Never in a plane here (the world view asks).
var flying := false
## His rope and hook (scripts/rope/climb_rope.gd).
var rope: Node3D
## The corner line: the moveset and the loot taken.
var _status: Label

func _ready() -> void:
	pack = SCENE_ID
	LayoutOverrides.begin(SCENE_ID)
	super._ready()
	set_full_moves(false)

func _load_pack() -> void:
	start = Vector3(0.0,0.0,9.0)
	start_face = Vector2(0.0,-1.0)
	lost = LOW_Y-16.0
	_last_stood = start
	stations = [
		{"key":1,"name":"Start","spawn":start,"face":start_face,"sign":Vector3(-4.0,2.6,12.0),"parts":[]},
		{"key":2,"name":"Wall 5 m","spawn":Vector3(-12.0,0.0,-5.0),"face":Vector2(0.0,-1.0),"sign":Vector3(-17.0,3.0,-7.0),"parts":[]},
		{"key":3,"name":"Face 8 m","spawn":Vector3(1.0,0.0,-6.0),"face":Vector2(0.0,-1.0),"sign":Vector3(-3.0,4.0,-11.4),"parts":[]},
		{"key":4,"name":"Crumbly · solid","spawn":Vector3(9.5,0.0,-5.0),"face":Vector2(0.0,-1.0),"sign":Vector3(9.5,6.6,-11.4),"parts":[]},
		{"key":5,"name":"Drop top","spawn":Vector3(16.0,WALL_H,0.0),"face":Vector2(1.0,0.0),"sign":Vector3(17.0,WALL_H+2.4,-4.6),"parts":[]},
		{"key":6,"name":"Lower floor","spawn":Vector3(26.0,LOW_Y,0.0),"face":Vector2(-1.0,0.0),"sign":Vector3(28.0,LOW_Y+2.6,-6.0),"parts":[]},
	]

func _build_room() -> void:
	_box(UPPER,-FLOOR_DEPTH_HERE,0.0,"floor")
	_box(LOWER,LOW_Y-FLOOR_DEPTH_HERE,LOW_Y,"floor")
	var all := UPPER.merge(LOWER)
	for r: Rect2 in [Rect2(all.position.x-1.0,all.position.y-1.0,all.size.x+2.0,1.0),
			Rect2(all.position.x-1.0,all.end.y,all.size.x+2.0,1.0),
			Rect2(all.position.x-1.0,all.position.y,1.0,all.size.y),
			Rect2(all.end.x,all.position.y,1.0,all.size.y)]:
		_box(r,LOW_Y-FLOOR_DEPTH_HERE,WALL_TOP,"wall")
	for p: Array in PIECES:
		_named_part(str(p[0]),p[1])
		if str(p[2]) != "": holds[str(p[0])] = str(p[2])
	super._build_room()
	_build_loot()
	rope = ClimbRope.new()
	add_child(rope)
	rope.setup(self)
	if DevKeys.enabled():
		var editor: Node = preload("res://scripts/layout_edit.gd").new()
		editor.name = "LayoutEdit"
		add_child(editor)
		editor.setup(self,null)

func _material(colour: String) -> Material:
	if colour == "crumble" and not _materials.has(colour):
		var m := ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("tint",CRUMBLE)
		_materials[colour] = m
	return super._material(colour)

## A structure as a named, movable solid (`rope_study/<id>`): built about
## its middle, so the world view's move carries the mesh, collider and its
## lip's band.
func _named_part(id: String, part: Array) -> void:
	var called := "%s/%s" % [SCENE_ID,id]
	if LayoutOverrides.deleted(called): return
	var mesh: Mesh
	var shape: Shape3D
	var coded := Transform3D.IDENTITY
	var colour := ""
	var band := ""
	var size := Vector3.ZERO
	match str(part[0]):
		"box":
			var rect: Rect2 = part[1]
			size = Vector3(rect.size.x,float(part[3])-float(part[2]),rect.size.y)
			var b := BoxMesh.new()
			b.size = size
			var s := BoxShape3D.new()
			s.size = size
			mesh = b
			shape = s
			coded.origin = Vector3(rect.get_center().x,(float(part[3])+float(part[2]))*0.5,rect.get_center().y)
			colour = str(part[4])
			if colour == "lip" or colour == "crumble":
				band = colour
				colour = "grey"
		"cyl":
			var mid: Vector2 = part[1]
			var c := CylinderMesh.new()
			c.top_radius = float(part[2])
			c.bottom_radius = float(part[2])
			c.height = float(part[4])-float(part[3])
			c.radial_segments = 12
			var s := CylinderShape3D.new()
			s.radius = float(part[2])
			s.height = c.height
			mesh = c
			shape = s
			coded.origin = Vector3(mid.x,(float(part[3])+float(part[4]))*0.5,mid.y)
			colour = str(part[5])
	var solid := _solid(mesh,shape,LayoutOverrides.xform(called,coded),colour)
	solid.name = id
	pieces[id] = solid
	if band != "":
		var drawn := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(size.x+0.02,0.1,size.z+0.02)
		drawn.mesh = slab
		drawn.position = Vector3(0.0,size.y*0.5-0.045,0.0)
		drawn.material_override = _material(band)
		solid.add_child(drawn)
	LayoutOverrides.track(called,solid,"piece",coded)

# --- The moveset -----------------------------------------------------------------------

## His full moveset on, or the reduced one (walk, run, jump, slide): the
## motor's gates, and the updraft (and its side slam) kept aside.
var _updraft_kept: Node3D
var _side_slam_kept: Node3D

func set_full_moves(on: bool) -> void:
	full_moves = on
	motor.wall_on = on
	motor.ledge_on = on
	motor.sail_on = on
	motor.rope_on = on
	if on:
		if _updraft_kept != null: updraft = _updraft_kept
		if _side_slam_kept != null: side_slam = _side_slam_kept
	else:
		if updraft != null:
			_updraft_kept = updraft
			updraft.reset()
		if side_slam != null:
			_side_slam_kept = side_slam
			side_slam.reset()
		updraft = null
		side_slam = null
	_show_status()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"walk_moveset") and not event.is_echo() and not _tuning():
		set_full_moves(not full_moves)
		_say("Full moveset" if full_moves else "Rope moveset: walk, run, jump, slide")
		return
	super._unhandled_input(event)

# --- The loot --------------------------------------------------------------------------

## Stands each loot piece on its named spot (`rope_study/loot_NN`), its kg
## over it.
func _build_loot() -> void:
	var holder := Node3D.new()
	holder.name = "Loot"
	add_child(holder)
	for row: Array in LOOT:
		var called := "%s/%s" % [SCENE_ID,str(row[0])]
		if LayoutOverrides.deleted(called): continue
		var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(float(row[4]))),row[3])
		var spot := Node3D.new()
		spot.name = str(row[0])
		spot.transform = LayoutOverrides.xform(called,coded)
		holder.add_child(spot)
		LayoutOverrides.track(called,spot,"token",coded)
		var made := BagStudy.loot_model(str(row[1]))
		spot.add_child(made.node)
		var tag := Label3D.new()
		tag.name = "Kg"
		tag.text = BagStudy._kg_text(float(row[2]))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 28
		tag.pixel_size = 0.006
		tag.outline_size = 6
		tag.position = Vector3(0.0,float(made.height)+0.25,0.0)
		spot.add_child(tag)
		loot.append({"id":str(row[0]),"kind":str(row[1]),"kg":float(row[2]),"spot":spot,"taken":false})

## Walked into, a loot piece is his.
func _take_loot() -> void:
	for l: Dictionary in loot:
		if l.taken: continue
		var at: Vector3 = (l.spot as Node3D).global_position
		if Vector2(at.x-motor.feet.x,at.z-motor.feet.z).length() > TAKE_REACH: continue
		if absf(motor.feet.y-at.y) > TAKE_RISE: continue
		l.taken = true
		(l.spot as Node3D).visible = false
		taken += 1
		taken_kg += float(l.kg)
		_say("Took the %s (%s)" % [l.kind,BagStudy._kg_text(float(l.kg))])
		_show_status()

## Aiming the hook, the stick moves the reticle, not him; tugging it or
## pulling it up, he stands.
func _want(delta: float) -> Vector2:
	var want := super._want(delta)
	if rope == null or not rope.state in ["aim","tug","pull_up"]: return want
	rope.aim_steer(want,delta)
	return Vector2.ZERO

func tick(delta: float) -> void:
	# Jump by a hooked rope takes hold of it (before the motor would jump).
	if rope != null: rope.pre_step((script_jump if scripted else Input.is_action_pressed(&"walk_jump")) and not _tuning())
	super.tick(delta)
	_take_loot()

func respawn() -> void:
	super.respawn()
	if rope != null: rope.reset()
	for l: Dictionary in loot:
		l.taken = false
		(l.spot as Node3D).visible = true
	taken = 0
	taken_kg = 0.0
	_show_status()

# --- The UI ----------------------------------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size",16)
	_status.add_theme_color_override("font_color",Color("fbf6ea"))
	_status.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	_status.add_theme_constant_override("shadow_offset_y",1)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.offset_left = -420.0
	_status.offset_right = -16.0
	_status.offset_top = 12.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_status)
	_show_status()

func _show_status() -> void:
	if _status == null: return
	var moves := "full moveset" if full_moves else "rope moveset (walk, run, jump, slide)"
	_status.text = "%s · %s %s\nloot %d / %d · %s" % [moves,Pad.pick("M","LEFT"),"to switch",taken,loot.size(),BagStudy._kg_text(taken_kg)]

func _hint_text() -> String:
	return "Rope study: WASD run · Space jump · Shift/C crouch, at a run: slide · hold LMB or T (pad RT): aim the hook (gold catches, red won't), let go to throw · E (pad B) tug a caught hook: it seats, or slips off a crumbly lip · Space (pad A) by a hooked rope: take hold; W / stick toward the wall climbs, back down, Shift / crouch slides, Space lets go; at the top he hauls over · E by a post up top fixes the rope over the drop; Space at the edge facing out goes over; S / stick back hops down, W climbs, Shift slides · F (pad down) reel it in (from below a fixed rope: pull it down; from a top: pull it up) · M (pad left) full moveset on / off · walk into loot to take it · 1 start, 2 wall 5 m, 3 face 8 m, 4 crumbly / solid edge, 5 drop top, 6 lower floor · R start · F1 numbers · F4 world view · Esc mouse"
