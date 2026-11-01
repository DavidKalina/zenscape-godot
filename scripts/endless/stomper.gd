extends Node3D
## The stomper (docs/design/endless-flight/spec-stomper.md): one giant headless
## stone body in the Amberlands, the only one in the world. It stands near the
## spawn at about HEIGHT m; `--stomper=0` leaves it out.
##
## One skinned mesh and one Skeleton3D from assets/models/stomper_body.glb
## (art/blender/headless_body/reduce_stomper.py), dressed in the kit's stone.
##   wanted(world)   whether this world has it
##   setup(study)    finds its ground and stands it there

const LaunchArgs = preload("res://scripts/launch_args.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const MODEL := "res://assets/models/stomper_body.glb"
const WORLD := "amberlands"
## Its height in play (m), and the model's, stump's cut to soles (m).
const HEIGHT := 250.0
const MODEL_HEIGHT := 7.02
## The site's search round the spawn: rings (m), bearings a ring, how far its
## stance reaches from the middle (m), the most the ground may vary across it
## (m), how far over the water it must stay (m).
const RINGS := [700.0,900.0,1100.0,1300.0]
const BEARINGS := 24
const STANCE := 90.0
const SITE_RISE := 36.0
const SITE_DRY := 6.0
## The baked occlusion's darkest share and its curve.
const AO_FLOOR := 0.42
const AO_EASE := 0.7
## LODs for the dressed mesh (ImporterMesh.generate_lods).
const LOD_MERGE := 60.0
const LOD_SPLIT := 25.0

var skeleton: Skeleton3D
var body: MeshInstance3D
var player: AnimationPlayer

static func wanted(world: RefCounted) -> bool:
	return String(world.id) == WORLD and not ("--stomper=0" in LaunchArgs.user_args())

func setup(study: Node) -> void:
	var field: RefCounted = study.field
	var start: Vector2 = study._start
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	model.scale = Vector3.ONE*(HEIGHT/MODEL_HEIGHT)
	add_child(model)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	body = skeleton.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	body.mesh = _dressed(body.mesh)
	var stone: Material = RuinKit.materials().stone
	for s in range(body.mesh.get_surface_count()):
		body.set_surface_override_material(s,stone)
	player = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	player.play("idle")
	var site := _site(field,start)
	position = Vector3(site.x,float(field.height(site.x,site.y))-1.0,site.y)
	# Its front is -Z; it faces the spawn.
	rotation.y = atan2(site.x-start.x,site.y-start.y)

## The flattest dry ground on the rings round `start`, first of equals in the
## plane's way out (at heading 0 it flies toward -X).
func _site(field: RefCounted, start: Vector2) -> Vector2:
	var best := start+Vector2(-float(RINGS[0]),0.0)
	var score := INF
	for ring: float in RINGS:
		for i in range(BEARINGS):
			var a := TAU*float(i)/float(BEARINGS)
			var at := start+Vector2(-cos(a),sin(a))*ring
			var low := INF
			var high := -INF
			var dry := true
			for j in range(9):
				var p := at
				if j > 0: p += Vector2.from_angle(TAU*float(j)/8.0)*STANCE
				var h := float(field.height(p.x,p.y))
				low = minf(low,h)
				high = maxf(high,h)
				var river := float(field.river_y(p.x,p.y))
				if h < float(field.SEA_Y)+SITE_DRY or (not is_nan(river) and h < river+SITE_DRY): dry = false
			if not dry or high-low > SITE_RISE: continue
			var s := high-low+ring*0.01+(1.0-cos(a))*40.0
			if s < score:
				score = s
				best = at
	return best

## The mesh in the kit's stone: each vertex coloured as the kit colours a face
## and darkened by the baked occlusion. Generated again as an ImporterMesh, or
## it has no LODs.
func _dressed(mesh: Mesh) -> ArrayMesh:
	var out := ImporterMesh.new()
	var stone := Style.stone_of(7) if Style.ruled() else Color("5a5d63")
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ao: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var colours := PackedColorArray()
		colours.resize(verts.size())
		for i in range(verts.size()):
			var p := verts[i]
			var occ := 1.0
			if ao.size() == verts.size(): occ = pow(clampf(ao[i].r,0.0,1.0),AO_EASE)
			var c := Style.shade(stone,p,p+Vector3.UP*4.0,normals[i],1.0)*lerpf(AO_FLOOR,1.0,occ)
			c.a = occ
			colours[i] = c
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.generate_lods(LOD_MERGE,LOD_SPLIT,[])
	return out.get_mesh()
