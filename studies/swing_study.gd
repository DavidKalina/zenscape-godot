extends "res://studies/rope_study.gd"
## The rope swing study (docs/design/rope-swing/spec-rope-swing.md): a
## greybox room for hooking the wanderer's own rope over an overhead beam and
## swinging from it across gaps he can't jump. Built on the rope study (its
## reduced moveset, M toggle, rope, named pieces and world view, F4).
##
## The room, plain grey, decks at y 0 over a pit (y -6) that runs under
## every crossing, three lanes north (-z) from the start deck:
## - lane A (west): a 9 m gap, one beam over its middle (one swing across);
## - lane B (middle): an 8 m gap, a small platform, an 8.5 m gap, a beam over
##   each gap (swing, land, throw, swing);
## - lane C (east): a 14 m gap with a beam too high to reach and a tall one
##   for a long swing; on the start deck behind it, a beam so low the swing
##   scrapes the floor;
## - the pit: every deck's face to it is a solid (orange) lip, so a bad
##   release climbs back out on the rope.
## Beams are plain grey bars on dark pillars, every one named
## `swing_study/<piece>` (scripts/layout_overrides.gd).
##   ./run-swing-study.command
##   godot --path . res://studies/swing_study.tscn -- --no-title

## The decks' top and the pit's floor.
const PIT_Y := -6.0
## The room (x, z): the start deck's south end to the far decks' north one.
const ROOM := Rect2(-20.0,-24.0,56.0,48.0)
## A beam's square section (m) and a pillar's radius.
const BEAM_T := 0.3
const PILLAR_R := 0.25
## A deck's lip band (m in from its edge).
const RIM_W := 0.35

## The named structures: [name, part, hold] (the rope study's formats). A
## deck's top edge is a solid lip (its face to the pit climbs on the rope).
## Beams: hold "" for now (the hook's beam wrap is the next task).
const SWING_PIECES := [
	# The start deck, across all three lanes.
	["start_deck",["box",Rect2(-20.0,4.0,56.0,20.0),PIT_Y,0.0,"grey"],"solid"],
	# Lane A: the far deck past a 9 m gap; one beam over the gap's middle.
	["far_a",["box",Rect2(-20.0,-24.0,14.0,19.0),PIT_Y,0.0,"grey"],"solid"],
	["beam_a",["box",Rect2(-18.0,-0.5-BEAM_T*0.5,10.0,BEAM_T),7.0-BEAM_T,7.0,"grey"],""],
	["beam_a_w",["cyl",Vector2(-18.4,-0.5),PILLAR_R,PIT_Y,7.0,"dark"],""],
	["beam_a_e",["cyl",Vector2(-7.6,-0.5),PILLAR_R,PIT_Y,7.0,"dark"],""],
	# Lane B: 8 m to a small platform, 8.5 m on to the far deck; a beam over
	# each gap.
	["platform_b",["box",Rect2(1.0,-7.5,6.0,3.5),PIT_Y,0.0,"grey"],"solid"],
	["far_b",["box",Rect2(-3.0,-24.0,14.0,8.0),PIT_Y,0.0,"grey"],"solid"],
	["beam_b1",["box",Rect2(-2.0,0.0-BEAM_T*0.5,12.0,BEAM_T),7.0-BEAM_T,7.0,"grey"],""],
	["beam_b1_w",["cyl",Vector2(-2.4,0.0),PILLAR_R,PIT_Y,7.0,"dark"],""],
	["beam_b1_e",["cyl",Vector2(10.4,0.0),PILLAR_R,PIT_Y,7.0,"dark"],""],
	["beam_b2",["box",Rect2(-2.0,-11.75-BEAM_T*0.5,12.0,BEAM_T),7.5-BEAM_T,7.5,"grey"],""],
	["beam_b2_w",["cyl",Vector2(-2.4,-11.75),PILLAR_R,PIT_Y,7.5,"dark"],""],
	["beam_b2_e",["cyl",Vector2(10.4,-11.75),PILLAR_R,PIT_Y,7.5,"dark"],""],
	# Lane C: the far deck past a 14 m gap; a beam out of reach (16 m) and a
	# tall one (11 m) for a long swing.
	["far_c",["box",Rect2(15.0,-24.0,21.0,14.0),PIT_Y,0.0,"grey"],"solid"],
	["high_beam",["box",Rect2(16.0,-3.0-BEAM_T*0.5,8.0,BEAM_T),16.0-BEAM_T,16.0,"grey"],""],
	["high_beam_w",["cyl",Vector2(15.6,-3.0),PILLAR_R,PIT_Y,16.0,"dark"],""],
	["high_beam_e",["cyl",Vector2(24.4,-3.0),PILLAR_R,PIT_Y,16.0,"dark"],""],
	["tall_beam",["box",Rect2(26.0,-3.0-BEAM_T*0.5,9.0,BEAM_T),11.0-BEAM_T,11.0,"grey"],""],
	["tall_beam_w",["cyl",Vector2(25.6,-3.0),PILLAR_R,PIT_Y,11.0,"dark"],""],
	["tall_beam_e",["cyl",Vector2(35.4,-3.0),PILLAR_R,PIT_Y,11.0,"dark"],""],
	# On the start deck behind lane C: a beam so low (3.2 m) the swing
	# scrapes the floor.
	["low_beam",["box",Rect2(18.0,13.0-BEAM_T*0.5,14.0,BEAM_T),3.2-BEAM_T,3.2,"grey"],""],
	["low_beam_w",["cyl",Vector2(17.6,13.0),PILLAR_R,0.0,3.2,"dark"],""],
	["low_beam_e",["cyl",Vector2(32.4,13.0),PILLAR_R,0.0,3.2,"dark"],""],
]

## The beams, by piece id (the hook's targets, next task).
const BEAMS := ["beam_a","beam_b1","beam_b2","high_beam","tall_beam","low_beam"]

func _init() -> void:
	scene_id = "swing_study"

func _load_pack() -> void:
	start = Vector3(-13.0,0.0,8.0)
	start_face = Vector2(0.0,-1.0)
	lost = PIT_Y-14.0
	_last_stood = start
	stations = [
		{"key":1,"name":"One beam (A)","spawn":start,"face":start_face,"sign":Vector3(-17.5,2.6,5.0),"parts":[]},
		{"key":2,"name":"Two beams (B)","spawn":Vector3(4.0,0.0,7.0),"face":Vector2(0.0,-1.0),"sign":Vector3(0.0,2.6,5.0),"parts":[]},
		{"key":3,"name":"Platform","spawn":Vector3(4.0,0.0,-6.5),"face":Vector2(0.0,-1.0),"sign":Vector3(4.0,2.2,-7.3),"parts":[]},
		{"key":4,"name":"High · tall (C)","spawn":Vector3(25.0,0.0,6.0),"face":Vector2(0.0,-1.0),"sign":Vector3(21.0,2.6,5.0),"parts":[]},
		{"key":5,"name":"Low beam","spawn":Vector3(25.0,0.0,18.0),"face":Vector2(0.0,-1.0),"sign":Vector3(25.0,4.4,13.0),"parts":[]},
		{"key":6,"name":"The pit","spawn":Vector3(4.0,PIT_Y,-1.0),"face":Vector2(0.0,1.0),"sign":Vector3(4.0,PIT_Y+2.6,3.6),"parts":[]},
		{"key":7,"name":"Far deck A","spawn":Vector3(-13.0,0.0,-9.0),"face":Vector2(0.0,1.0),"sign":Vector3(-13.0,2.6,-14.0),"parts":[]},
	]

func _build_room() -> void:
	# The pit floor under everything, the room's walls round it.
	_box(ROOM,PIT_Y-FLOOR_DEPTH_HERE,PIT_Y,"floor")
	for r: Rect2 in [Rect2(ROOM.position.x-1.0,ROOM.position.y-1.0,ROOM.size.x+2.0,1.0),
			Rect2(ROOM.position.x-1.0,ROOM.end.y,ROOM.size.x+2.0,1.0),
			Rect2(ROOM.position.x-1.0,ROOM.position.y,1.0,ROOM.size.y),
			Rect2(ROOM.end.x,ROOM.position.y,1.0,ROOM.size.y)]:
		_box(r,PIT_Y-FLOOR_DEPTH_HERE,WALL_TOP,"wall")
	for p: Array in SWING_PIECES:
		_named_part(str(p[0]),p[1])
		if str(p[2]) != "":
			holds[str(p[0])] = str(p[2])
			if pieces.has(str(p[0])): _rim(pieces[str(p[0])],p[1][1],float(p[1][3])-float(p[1][2]))
	# The character study's signs and start mark (its pack branch).
	_build_signs()
	rope = ClimbRope.new()
	add_child(rope)
	rope.setup(self)
	if DevKeys.enabled():
		var editor: Node = preload("res://scripts/layout_edit.gd").new()
		editor.name = "LayoutEdit"
		add_child(editor)
		editor.setup(self,null)

## A deck's solid lip, drawn as an orange band round its top's edges (the
## deck's own top stays grey), on its solid so the world view moves it.
func _rim(solid: Node3D, rect: Rect2, height: float) -> void:
	var y := height*0.5-0.045
	for e: Array in [[Vector3(0.0,y,-rect.size.y*0.5+RIM_W*0.5),Vector3(rect.size.x+0.02,0.1,RIM_W)],
			[Vector3(0.0,y,rect.size.y*0.5-RIM_W*0.5),Vector3(rect.size.x+0.02,0.1,RIM_W)],
			[Vector3(-rect.size.x*0.5+RIM_W*0.5,y,0.0),Vector3(RIM_W,0.1,rect.size.y+0.02)],
			[Vector3(rect.size.x*0.5-RIM_W*0.5,y,0.0),Vector3(RIM_W,0.1,rect.size.y+0.02)]]:
		var drawn := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = e[1]
		drawn.mesh = slab
		drawn.position = e[0]
		drawn.material_override = _material("lip")
		solid.add_child(drawn)

## The stations' signs and the start mark (the character study's pack room,
## skipping the rope study's loot).
func _build_signs() -> void:
	for station: Dictionary in stations:
		if station.has("sign"): _label(station.sign,"%s  %s" % [key_name(station.key),station.name],64)
	_label(start+Vector3(1.6,0.4,0.0),"START · R",36)

func _show_status() -> void:
	if _status == null: return
	var moves := "full moveset" if full_moves else "rope moveset (walk, run, jump, slide)"
	_status.text = "%s · %s %s" % [moves,Pad.pick("M","LEFT"),"to switch"]

func _hint_text() -> String:
	return "Swing study: WASD run · Space jump · Shift/C crouch, at a run: slide · hold LMB or T (pad RT): aim the hook, let go to throw · E (pad B) tug a caught hook · Space (pad A) by a hooked rope: take hold; W / S climb, Space lets go · F (pad down) reel it in · M (pad left) full moveset on / off · 1 one beam (A), 2 two beams (B), 3 platform, 4 high / tall beams (C), 5 low beam, 6 the pit, 7 far deck A · R start · F1 numbers · F4 world view · Esc mouse"
