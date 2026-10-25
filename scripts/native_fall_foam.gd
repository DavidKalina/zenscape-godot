extends Node3D
## Source foamCluster placement, animated by the same controller as fidelity.
var animator:=preload("res://scripts/shared/fall_foam.gd").new()
static func clusters(strands: Array,flow: float) -> Array[Dictionary]:
	var blobs: Array[Dictionary]=[]
	for i in range(strands.size()):
		var s: Dictionary=strands[i]
		_cluster(blobs,s.impact,0.5+flow*0.5,floori(4.0+flow*3.0+0.5),0.7+flow*0.25,i*5.1,0.88)
		for r in s.ledges:
			_cluster(blobs,s.centers[r],s.halfW[r]*1.3,3,0.5+flow*0.15,r*3.7+i,s.tau[r]/maxf(s.tau[-1],0.000001)*0.9)
	return blobs
static func _cluster(blobs: Array[Dictionary],at: Array,spread: float,count: int,size: float,seed: float,gate: float) -> void:
	for i in range(count):
		var angle:=float(i)/count*PI*2.0+seed
		var radius: float=(0.35+preload("res://scripts/native_recipe_water.gd")._hash(i+seed,1.0)*0.9)*spread
		blobs.append({"position":[at[0]+cos(angle)*radius,at[1]+0.04,at[2]+sin(angle)*radius*0.75],"rotation":[float(i),float(i*2),float(i*3)],"baseY":at[1]+0.04,"gate":gate,"radius":(0.12+preload("res://scripts/native_recipe_water.gd")._hash(i+seed,2.0)*0.18)*size,"mesh":"Blob_%d" % blobs.size()})
func setup(strands: Array,flow: float,template: Mesh) -> void:
	var blobs:=clusters(strands,flow)
	var arrays:=template.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var radius:=vertices[0].length()
	for blob in blobs:
		var copied:=arrays.duplicate(true)
		var points:=vertices.duplicate()
		for i in range(points.size()): points[i]*=blob.radius/radius
		copied[Mesh.ARRAY_VERTEX]=points
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copied)
		mesh.surface_set_material(0,template.surface_get_material(0))
		var node:=MeshInstance3D.new()
		node.name=blob.mesh
		node.mesh=mesh
		add_child(node)
	animator.setup(self,{"blobs":blobs})
