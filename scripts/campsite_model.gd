extends RefCounted
## Shared meshes for the editor preview and the placed campsite.
static func part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(parent,mesh,at,color)

static func branch() -> Node3D:
	var root := Node3D.new()
	for entry in [[Vector3(0,0.09,0),Vector3(1.0,0.13,0.13),0.0],[Vector3(0.2,0.11,0.16),Vector3(0.5,0.08,0.09),-0.6]]:
		box(root,entry[0],entry[1],Color("68523d")).rotation.y = entry[2]
	return root

static func tent(wood := 0, food := 3) -> Node3D:
	var root := Node3D.new()
	root.add_child(preload("res://assets/models/zenscape-tent-ochre-v01.glb").instantiate())
	var cooler := box(root,Vector3(1.48,0.23,0.50),Vector3(0.48,0.40,0.38),Color("526f69"))
	cooler.name = "FoodBox"
	box(root,Vector3(1.48,0.44,0.50),Vector3(0.51,0.06,0.41),Color("dbca9f"))
	for i in range(food):
		box(root,Vector3(1.35+i*0.12,0.52,0.50),Vector3(0.09,0.10,0.13),Color("b18a49"))
	var lantern := box(root,Vector3(1.55,0.28,1.15),Vector3(0.18,0.3,0.18),Color("ffe2a1"))
	lantern.name = "Lantern"
	lantern.material_override.emission_enabled = true
	lantern.material_override.emission = Color("ffbd76")*0.5
	for i in range(mini(wood,8)):
		var log := branch()
		root.add_child(log)
		log.position = Vector3(-1.55,0.05+floori(i/3.0)*0.15,0.7+(i%3)*0.22)
		log.scale *= 0.65
	return root

static func human(variant := "photographer") -> Node3D:
	var actor = preload("res://scripts/camper_visual.gd").new()
	actor.setup(variant)
	return actor
