extends Node3D
## The remains of giants in the Amberlands, half sunk in the land, placed once
## at setup: their spots come from giant_swells.gd, which heaps the land round
## them. Set, cut and baked by art/blender/giant_ruins/giant_head_build.py: a
## few poses, each a mesh cut off under the ground and a grid of its signed
## distance in assets/models/giants/ruins.json, used again and again turned.
##
## The plane flies against that grid, not the mesh: `ground` and `inside` in
## plane_ground and _blocked, the way the land's stone reaches the flight. So
## the hollows are real. A static body on layer 1 is for the wing rays.
##
## All of it hangs off this one node: nothing here moves, so each ruin is a
## RenderingServer instance and a PhysicsServer3D body, freed in `_exit_tree`.

const LandHalls = preload("res://scripts/endless/land_halls.gd")
const RUINS := "res://assets/models/giants/ruins.json"
const LAYER := 1
const STONE = preload("res://shaders/giant_stone.gdshader")

var _ruins: Array = []
var _views: Array[RID] = []
var _bodies: Array[RID] = []
var _keep: Array[Resource] = []

static func wanted(world: Variant) -> bool:
	return preload("res://scripts/endless/giant_swells.gd").home(world).is_finite()

func setup(host: Node3D) -> void:
	var list: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUINS))
	var swells: RefCounted = host.field.swells()
	if not list is Array or swells == null:
		push_error("giant_ruins: nothing to lay out")
		return
	var poses: Array = []
	for e: Dictionary in list: poses.append(_pose(e))
	for s: Dictionary in swells.spots: _add(poses[int(s.pose)],s,host)

## One pose's mesh, shape, grid and material, shared by each ruin of it.
func _pose(e: Dictionary) -> Dictionary:
	var scene: Node = (load("res://assets/models/giants/%s.glb" % e.id) as PackedScene).instantiate()
	var found: Array = scene.find_children("*","MeshInstance3D",true,false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh
	scene.free()
	var stone := ShaderMaterial.new()
	stone.shader = STONE
	stone.set_shader_parameter("mask",load("res://assets/textures/ruin_stone_mask.png"))
	stone.set_shader_parameter("relief",load("res://assets/textures/giants/%s_normal.png" % e.piece))
	stone.set_shader_parameter("shade",load("res://assets/textures/giants/%s_ao.png" % e.piece))
	var o: Array = e.origin
	var s: Array = e.size
	var low := Vector3(float(o[0]),float(o[1]),float(o[2]))
	var cell := float(e.cell)
	var nx := int(s[0])
	var ny := int(s[1])
	var nz := int(s[2])
	var shape := mesh.create_trimesh_shape()
	_keep.append(mesh)
	_keep.append(shape)
	_keep.append(stone)
	return {"mesh":mesh,"shape":shape,"stone":stone,"low":low,"high":low+Vector3(nx-1,ny-1,nz-1)*cell,"cell":cell,
		"nx":nx,"ny":ny,"nz":nz,"d":Marshalls.base64_to_raw(str(e.d)),"reach":float(e.reach),
		"rim":Vector2(float(e.rim_x),float(e.rim_z))}

func _add(pose: Dictionary, s: Dictionary, host: Node3D) -> void:
	var at := Vector2(float(s.x),float(s.z))
	var yaw := float(s.yaw)
	var y := _ground_y(host,at+(pose.rim as Vector2).rotated(-yaw),float(pose.reach))
	var place := Transform3D(Basis(Vector3.UP,yaw),Vector3(at.x,y,at.y))
	_show(pose,place)
	var high: Vector3 = pose.high
	var low: Vector3 = pose.low
	var far := maxf(Vector2(low.x,low.z).length(),Vector2(high.x,high.z).length())
	_ruins.append({"pose":pose,"inv":place.affine_inverse(),"y":y,"x":at.x,"z":at.y,"reach2":(far+8.0)*(far+8.0)})

func _show(pose: Dictionary, t: Transform3D) -> void:
	var view := RenderingServer.instance_create2((pose.mesh as Mesh).get_rid(),get_world_3d().scenario)
	RenderingServer.instance_set_transform(view,t)
	RenderingServer.instance_geometry_set_material_override(view,(pose.stone as Material).get_rid())
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body,PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_collision_layer(body,LAYER)
	PhysicsServer3D.body_set_collision_mask(body,0)
	PhysicsServer3D.body_add_shape(body,(pose.shape as Shape3D).get_rid())
	PhysicsServer3D.body_attach_object_instance_id(body,get_instance_id())
	PhysicsServer3D.body_set_state(body,PhysicsServer3D.BODY_STATE_TRANSFORM,t)
	PhysicsServer3D.body_set_space(body,get_world_3d().space)
	_views.append(view)
	_bodies.append(body)

func _exit_tree() -> void:
	for view: RID in _views: RenderingServer.free_rid(view)
	for body: RID in _bodies: PhysicsServer3D.free_rid(body)
	_views.clear()
	_bodies.clear()

## The land's mean round the ruin's waterline, on the flank of its swell (the
## swell's top heaps up against the stone instead of lifting it).
func _ground_y(host: Node3D, at: Vector2, reach: float) -> float:
	var total := 0.0
	for i in 8:
		var off := Vector2.from_angle(i*TAU/8.0)*reach
		total += float(host.field.height(at.x+off.x,at.y+off.y))
	return total/8.0

static func _d(r: Dictionary, x: int, y: int, z: int) -> float:
	return (r.d as PackedByteArray).decode_s8(x+int(r.nx)*(y+int(r.ny)*z))*0.5

## The distance at height index `y` of the column at (x,z), blended over x,z.
static func _column(r: Dictionary, x: int, z: int, fx: float, fz: float, y: int) -> float:
	var a := lerpf(_d(r,x,y,z),_d(r,x+1,y,z),fx)
	var b := lerpf(_d(r,x,y,z+1),_d(r,x+1,y,z+1),fx)
	return lerpf(a,b,fz)

## The solid stretches over a point (the ruin's own frame), bottom up, grown
## by `pad`, in the world's heights.
func _stretches(r: Dictionary, l: Vector3, pad: float, list: Array) -> void:
	var pose: Dictionary = r.pose
	var cell := float(pose.cell)
	var low: Vector3 = pose.low
	var gx := (l.x-low.x)/cell
	var gz := (l.z-low.z)/cell
	var x := int(gx)
	var z := int(gz)
	var fx := gx-x
	var fz := gz-z
	var ny := int(pose.ny)
	var base := low.y+float(r.y)
	var last := _column(pose,x,z,fx,fz,0)-pad
	var from := base if last < 0.0 else INF
	for y in range(1,ny):
		var v := _column(pose,x,z,fx,fz,y)-pad
		if (v < 0.0) != (last < 0.0):
			var cross := base+(y-1+last/(last-v))*cell
			if v < 0.0: from = cross
			else:
				list.append(Vector2(from,cross))
				from = INF
		last = v
	if from < INF: list.append(Vector2(from,base+(ny-1)*cell))

## The point in a ruin's own frame, if it is over the ruin's grid.
func _local(r: Dictionary, p: Vector3) -> Variant:
	var dx := p.x-float(r.x)
	var dz := p.z-float(r.z)
	if dx*dx+dz*dz > float(r.reach2): return null
	var l: Vector3 = (r.inv as Transform3D)*p
	var pose: Dictionary = r.pose
	var low: Vector3 = pose.low
	var high: Vector3 = pose.high
	return l if l.x >= low.x and l.x < high.x and l.z >= low.z and l.z < high.z else null

func ground(p: Vector3, h: Variant, pad := 0.4) -> Variant:
	if not h is float: return h
	var list: Array = []
	for r: Dictionary in _ruins:
		var l: Variant = _local(r,p)
		if l != null: _stretches(r,l,pad,list)
	if list.is_empty(): return h
	return LandHalls.over(p,h,list)

## True in the stone, grown by `pad`.
func inside(p: Vector3, pad := 0.4) -> bool:
	for r: Dictionary in _ruins:
		var v: Variant = _local(r,p)
		if v == null: continue
		var l: Vector3 = v
		var pose: Dictionary = r.pose
		var low: Vector3 = pose.low
		var c := float(pose.cell)
		var y := int((l.y-low.y)/c)
		if y < 0 or y >= int(pose.ny): continue
		if _d(pose,int((l.x-low.x)/c+0.5),y,int((l.z-low.z)/c+0.5)) < pad: return true
	return false
