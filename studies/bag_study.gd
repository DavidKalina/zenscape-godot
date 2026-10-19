extends "res://studies/character_study.gd"
## The loot bag study (docs/design/bag/spec-bag.md): a greybox room for the
## wanderer's cloth bag. The wanderer is the game's own (the character
## study's motor, figure, camera and input). The room, plain grey:
##
## - the start floor (y 0), with loot of mixed weights scattered on it;
## - a low step (0.4 m), a ledge he climbs empty (1.7 m, a jump's catch)
##   with loot on top, and a raised platform up a ramp (1.2 m);
## - the throw wall (1.7 m, a jump's catch, out of reach loaded) closing
##   off a pocket behind it: throw the bag over, climb after it;
## - a long slope east (12 m, 4 m down, about 18°) to the lower floor
##   (y -4), where rocks and curbs stand for a dragged bag to catch on.
##
## Every structure and loot piece is named `bag_study/<piece>` through
## scripts/layout_overrides.gd, so the world view (F4) moves them.
##   ./run-bag-study.command
##   godot --path . res://studies/bag_study.tscn -- --no-title
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const Models = preload("res://scripts/carry/treasure_models.gd")
const DevKeys = preload("res://scripts/kit_isle/dev_keys.gd")
const LootBag = preload("res://scripts/carry/loot_bag.gd")

const SCENE_ID := "bag_study"
## The two floors (x, z) and their tops.
const UPPER := Rect2(-16.0,-14.0,32.0,28.0)
const LOWER := Rect2(16.0,-14.0,32.0,28.0)
const LOW_Y := -4.0
const FLOOR_DEPTH_HERE := 4.0
const WALL_TOP := 3.0
## The slope: its top edge on the upper floor's east rim, its foot on the
## lower floor; centred on z SLOPE_Z, SLOPE_W wide.
const SLOPE_TOP_X := 16.0
const SLOPE_FOOT_X := 28.0
const SLOPE_Z := 2.0
const SLOPE_W := 8.0

## The named structures: [name, part] (character_study's part formats:
## "box" Rect2, bottom, top, colour; "ramp" low, high, width, colour; "cyl"
## middle, radius, bottom, top, colour).
const PIECES := [
	# A low step he walks up even loaded.
	["low_step",["box",Rect2(-12.0,5.0,3.0,3.0),0.0,0.4,"grey"]],
	# The ledge: a jump's catch empty (1.7 m), out of reach loaded.
	["climb_ledge",["box",Rect2(-15.0,-6.0,4.0,5.0),0.0,1.7,"lip"]],
	# The raised platform and its ramp up.
	["platform",["box",Rect2(5.0,-13.5,9.0,5.0),0.0,1.2,"grey"]],
	["platform_ramp",["ramp",Vector3(9.5,0.0,-5.0),Vector3(9.5,1.2,-8.5),3.0,"grey"]],
	# The throw wall, and the pocket behind it (walled on its sides).
	["throw_wall",["box",Rect2(-7.0,-8.0,8.0,0.6),0.0,1.7,"lip"]],
	["pocket_side_w",["box",Rect2(-7.6,-14.0,0.6,6.6),0.0,1.7,"grey"]],
	["pocket_side_e",["box",Rect2(1.0,-14.0,0.6,6.6),0.0,1.7,"grey"]],
	# A guard rail along the upper floor's east rim, but for the slope.
	["rim_n",["box",Rect2(15.6,-14.0,0.4,SLOPE_Z-SLOPE_W*0.5+14.0),0.0,1.0,"grey"]],
	["rim_s",["box",Rect2(15.6,SLOPE_Z+SLOPE_W*0.5,0.4,14.0-SLOPE_Z-SLOPE_W*0.5),0.0,1.0,"grey"]],
	["slope",["ramp",Vector3(SLOPE_FOOT_X,LOW_Y,SLOPE_Z),Vector3(SLOPE_TOP_X,0.0,SLOPE_Z),SLOPE_W,"grey"]],
	# The lower floor's catches: rocks and curbs.
	["rock_a",["cyl",Vector2(33.0,-1.0),0.6,LOW_Y,LOW_Y+0.5,"dark"]],
	["rock_b",["cyl",Vector2(37.0,5.0),0.45,LOW_Y,LOW_Y+0.35,"dark"]],
	["rock_c",["cyl",Vector2(41.0,-6.0),0.8,LOW_Y,LOW_Y+0.7,"dark"]],
	["curb_a",["box",Rect2(35.0,-4.0,4.0,0.3),LOW_Y,LOW_Y+0.2,"grey"]],
	["curb_b",["box",Rect2(42.0,1.0,0.3,5.0),LOW_Y,LOW_Y+0.25,"grey"]],
]

## The loot: [id, kind, kg, foot (world), yaw deg]. Kinds: the treasure
## models' (idol, urn, egg, chalice) and plain shapes (bar, coins, gem).
## 46 kg in all, enough to fill the bag and leave some over.
const LOOT := [
	["loot_01","chalice",1.5,Vector3(2.0,0.0,4.0),20.0],
	["loot_02","idol",3.0,Vector3(-3.0,0.0,3.0),160.0],
	["loot_03","bar",4.0,Vector3(5.0,0.0,0.5),35.0],
	["loot_04","coins",2.0,Vector3(-6.0,0.0,-1.5),0.0],
	["loot_05","urn",6.0,Vector3(8.0,0.0,6.0),200.0],
	["loot_06","gem",0.5,Vector3(-13.0,1.7,-3.5),0.0],
	["loot_07","egg",12.0,Vector3(-8.0,0.0,9.0),90.0],
	["loot_08","bar",4.0,Vector3(10.0,1.2,-11.0),70.0],
	["loot_09","idol",3.0,Vector3(-13.0,1.7,-5.0),220.0],
	["loot_10","urn",6.0,Vector3(40.0,LOW_Y,0.0),130.0],
	["loot_11","bar",4.0,Vector3(12.0,0.0,3.0),10.0],
]

## Each loot piece: {id, kind, kg, spot (the named node), node (its figure)}.
var loot: Array = []
## The bag on his back (scripts/carry/loot_bag.gd).
var bag: Node3D
## Never in a plane here (the world view and the carry ask).
var flying := false

func _ready() -> void:
	pack = SCENE_ID
	LayoutOverrides.begin(SCENE_ID)
	super._ready()

func _load_pack() -> void:
	start = Vector3(0.0,0.0,9.0)
	start_face = Vector2(0.0,-1.0)
	lost = LOW_Y-16.0
	_last_stood = start
	stations = [
		{"key":1,"name":"Start","spawn":start,"face":start_face,"sign":Vector3(-4.0,2.6,12.0),"parts":[]},
		{"key":2,"name":"Ledge","spawn":Vector3(-9.0,0.0,-3.5),"face":Vector2(-1.0,0.0),"sign":Vector3(-13.0,3.0,-0.6),"parts":[]},
		{"key":3,"name":"Throw wall","spawn":Vector3(-3.0,0.0,-4.0),"face":Vector2(0.0,-1.0),"sign":Vector3(-3.0,3.4,-7.4),"parts":[]},
		{"key":4,"name":"Slope","spawn":Vector3(12.0,0.0,SLOPE_Z),"face":Vector2(1.0,0.0),"sign":Vector3(16.0,2.0,SLOPE_Z-SLOPE_W*0.5-0.4),"parts":[]},
		{"key":5,"name":"Lower floor","spawn":Vector3(31.0,LOW_Y,SLOPE_Z),"face":Vector2(1.0,0.0),"sign":Vector3(34.0,LOW_Y+2.0,10.0),"parts":[]},
	]

func _build_room() -> void:
	# The floors, and the walls round both.
	_box(UPPER,-FLOOR_DEPTH_HERE,0.0,"floor")
	_box(LOWER,LOW_Y-FLOOR_DEPTH_HERE,LOW_Y,"floor")
	var all := UPPER.merge(LOWER)
	for r: Rect2 in [Rect2(all.position.x-1.0,all.position.y-1.0,all.size.x+2.0,1.0),
			Rect2(all.position.x-1.0,all.end.y,all.size.x+2.0,1.0),
			Rect2(all.position.x-1.0,all.position.y,1.0,all.size.y),
			Rect2(all.end.x,all.position.y,1.0,all.size.y)]:
		_box(r,LOW_Y-FLOOR_DEPTH_HERE,WALL_TOP,"wall")
	for p: Array in PIECES: _named_part(str(p[0]),p[1])
	super._build_room()
	_build_loot()
	bag = LootBag.new()
	add_child(bag)
	bag.setup(self)
	if DevKeys.enabled():
		var editor: Node = preload("res://scripts/layout_edit.gd").new()
		editor.name = "LayoutEdit"
		add_child(editor)
		editor.setup(self,null)

## A structure as a named, movable solid (`bag_study/<id>`): built about its
## middle, so the world view's move carries the mesh, collider and cap.
func _named_part(id: String, part: Array) -> void:
	var called := "%s/%s" % [SCENE_ID,id]
	if LayoutOverrides.deleted(called): return
	var mesh: Mesh
	var shape: Shape3D
	var coded := Transform3D.IDENTITY
	var colour := ""
	var cap := Vector3.ZERO
	match str(part[0]):
		"box":
			var rect: Rect2 = part[1]
			var size := Vector3(rect.size.x,float(part[3])-float(part[2]),rect.size.y)
			var b := BoxMesh.new()
			b.size = size
			var s := BoxShape3D.new()
			s.size = size
			mesh = b
			shape = s
			coded.origin = Vector3(rect.get_center().x,(float(part[3])+float(part[2]))*0.5,rect.get_center().y)
			colour = str(part[4])
			if colour == "lip": cap = Vector3(size.x,size.y,size.z)
		"ramp":
			var low: Vector3 = part[1]
			var high: Vector3 = part[2]
			var along := (high-low).normalized()
			var side := Vector3.UP.cross(along).normalized()
			var up := along.cross(side).normalized()
			var size := Vector3(float(part[3]),0.4,low.distance_to(high)+0.02)
			var b := BoxMesh.new()
			b.size = size
			var s := BoxShape3D.new()
			s.size = size
			mesh = b
			shape = s
			coded = Transform3D(Basis(side,up,along),(low+high)*0.5-up*0.2)
			colour = str(part[4])
		"cyl":
			var mid: Vector2 = part[1]
			var c := CylinderMesh.new()
			c.top_radius = float(part[2])
			c.bottom_radius = float(part[2])
			c.height = float(part[4])-float(part[3])
			c.radial_segments = 14
			var s := CylinderShape3D.new()
			s.radius = float(part[2])
			s.height = c.height
			mesh = c
			shape = s
			coded.origin = Vector3(mid.x,(float(part[3])+float(part[4]))*0.5,mid.y)
			colour = str(part[5])
	var solid := _solid(mesh,shape,LayoutOverrides.xform(called,coded),colour)
	solid.name = id
	if cap != Vector3.ZERO:
		var band := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(cap.x+0.02,0.1,cap.z+0.02)
		band.mesh = slab
		band.position = Vector3(0.0,cap.y*0.5-0.045,0.0)
		band.material_override = _material("lip")
		solid.add_child(band)
	LayoutOverrides.track(called,solid,"piece",coded)

# --- The loot --------------------------------------------------------------------------

## Stands each loot piece on its named spot (`bag_study/loot_NN`), its kg
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
		var made := loot_model(str(row[1]))
		var node: Node3D = made.node
		spot.add_child(node)
		var tag := Label3D.new()
		tag.name = "Kg"
		tag.text = _kg_text(float(row[2]))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 28
		tag.pixel_size = 0.006
		tag.outline_size = 6
		tag.position = Vector3(0.0,float(made.height)+0.25,0.0)
		spot.add_child(tag)
		loot.append({"id":str(row[0]),"kind":str(row[1]),"kg":float(row[2]),"spot":spot,"node":node,"measures":made})

static func _kg_text(kg: float) -> String:
	return ("%.1f kg" % kg) if kg < 1.0 or kg != floorf(kg) else ("%d kg" % int(kg))

## A loot piece's figure and measures ({node, height, grip, radius}, foot
## at its origin): a treasure model's, or a plain shape's.
static func loot_model(kind: String) -> Dictionary:
	if kind in Models.KINDS: return Models.build(kind)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Figure"
	var mat := StandardMaterial3D.new()
	var height := 0.2
	var radius := 0.2
	match kind:
		"bar":
			# A gold ingot.
			var b := BoxMesh.new()
			b.size = Vector3(0.34,0.12,0.16)
			mesh_node.mesh = b
			mesh_node.position.y = 0.06
			mat.albedo_color = Color(0.95,0.74,0.25)
			mat.metallic = 0.9
			mat.roughness = 0.3
			height = 0.12
			radius = 0.2
		"coins":
			# A squat purse of coins.
			var s := SphereMesh.new()
			s.radius = 0.16
			s.height = 0.22
			mesh_node.mesh = s
			mesh_node.position.y = 0.11
			mat.albedo_color = Color(0.55,0.42,0.28)
			mat.roughness = 0.9
			height = 0.22
			radius = 0.17
		_:
			# A cut gem.
			var g := SphereMesh.new()
			g.radius = 0.09
			g.height = 0.2
			g.radial_segments = 6
			g.rings = 2
			mesh_node.mesh = g
			mesh_node.position.y = 0.1
			mat.albedo_color = Color(0.25,0.55,0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.15,0.35,0.8)
			mat.roughness = 0.15
			height = 0.2
			radius = 0.1
	mesh_node.material_override = mat
	var node := Node3D.new()
	node.add_child(mesh_node)
	return {"node":node,"height":height,"grip":radius,"radius":radius}

## The loot's total kg (on the ground now).
func loot_kg() -> float:
	var kg := 0.0
	for l: Dictionary in loot: kg += float(l.kg)
	return kg

## Dragging, the bag holds him to its rope (scripts/carry/loot_bag.gd).
## Aiming a throw, the stick moves the reticle, not him.
func _want(delta: float) -> Vector2:
	var want := super._want(delta)
	if bag == null or bag.act != "aim": return want
	bag.aim_steer(want,delta)
	return Vector2.ZERO

## Aiming, the camera eases back, lower and a little round to his right,
## looking between him and the reticle, so the arc reads as an arc (the
## reticle behind a wall shows through it, faint: loot_bag's ghost pass).
const AIM_CAM_OUT := 0.45
const AIM_CAM_POLAR := 0.22
const AIM_CAM_SWING := 0.42
const AIM_CAM_LOOK := 0.4
const AIM_CAM_EASE := 0.35
var _aim_cam := 0.0
var _aim_look := Vector3.INF

func _frame(delta: float) -> void:
	super._frame(delta)
	var aiming: bool = bag != null and bag.act == "aim" and bag.aim_at != Vector3.INF
	if aiming: _aim_look = bag.aim_at
	if delta > 0.0: _aim_cam = move_toward(_aim_cam,1.0 if aiming else 0.0,delta/AIM_CAM_EASE)
	if _aim_cam <= 0.0 or _aim_look == Vector3.INF: return
	var e := smoothstep(0.0,1.0,_aim_cam)
	var pivot := Vector3(_cam_at.x,_cam_y,_cam_at.y)
	var look := pivot.lerp(Vector3(_aim_look.x,pivot.y,_aim_look.z),AIM_CAM_LOOK*e)
	var polar := clampf(_polar+AIM_CAM_POLAR*e,POLAR.x,POLAR.y)
	var yaw := _yaw+AIM_CAM_SWING*e
	var out := Vector3(sin(polar)*sin(yaw),cos(polar),sin(polar)*cos(yaw))
	var dist := CAM_DISTANCE*wanderer_scale*(1.0+AIM_CAM_OUT*e)
	var hit := ground.space.intersect_ray(PhysicsRayQueryParameters3D.create(look,look+out*(dist+0.3)))
	if not hit.is_empty(): dist = maxf(look.distance_to(hit.position)-0.3,0.5)
	var at := pivot+out*_cam_distance
	camera.look_at_from_position(at.lerp(look+out*dist,e),pivot.lerp(look,e))

func _sync_figure() -> void:
	if bag != null: bag.leash(get_process_delta_time())
	super._sync_figure()

func _hint_text() -> String:
	return "Bag study: WASD run · Space jump · Shift/C crouch · E (pad B) by loot: into the bag · F (pad down) bag off / on / drag / let go · hold LMB or T (pad RT) worn: aim a throw, let go to throw (8 kg or under) · V (pad right) by it: shove it · 1 start, 2 ledge, 3 throw wall, 4 slope, 5 lower floor · R start · F1 numbers · F4 world view · Esc mouse"
