extends RefCounted
## Aerated water over steep parts of an editable stream. Uses the same course
## levels as the river and the existing animated waterfall material.
static func build(data: NativeTerrainData,route: Dictionary) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var points: Array = route.pts
	var first := -1
	for i in range(points.size()):
		var steep := false
		if i<points.size()-1:
			var a: Dictionary = points[i]
			var b: Dictionary = points[i+1]
			var run := Vector2(b.x-a.x,b.z-a.z).length()
			steep = (a.h-b.h)/maxf(run,0.001)>0.4
		if steep and first<0: first = maxi(0,i-1)
		if not steep and first>=0:
			var last := mini(points.size()-1,i+1)
			if points[first].h-points[last].h>0.35:
				var node := _strand(data,route,first,last)
				if node != null: result.append(node)
			first = -1
	return result

static func _strand(data: NativeTerrainData,route: Dictionary,first: int,last: int) -> MeshInstance3D:
	var strand := {"seed":float(first),"centers":[],"tau":[],"axA":[],"axB":[],"halfW":[],"thick":[],"aer":[],"steep":[]}
	var count := mini(32,last-first+1)
	var previous := Vector3.ZERO
	var length := 0.0
	for i in range(count):
		var station := float(first)+(last-first)*float(i)/(count-1)
		var lo := mini(last-1,int(station))
		var t := station-lo
		var a: Dictionary = route.pts[lo]
		var b: Dictionary = route.pts[lo+1]
		var point := Vector3(lerpf(a.x,b.x,t),lerpf(a.h,b.h,t)-route.depth+route.surface*0.065+0.03,lerpf(a.z,b.z,t))
		# A sculpted obstruction hides its water until the obstruction is undone.
		if data.stream_ground_height(point.x,point.z)>point.y: return null
		var tangent := Vector3(b.x-a.x,b.h-a.h,b.z-a.z).normalized()
		var across := tangent.cross(Vector3.UP).normalized()
		var outward := across.cross(tangent).normalized()
		if i>0: length += point.distance_to(previous)
		previous = point
		var steep := maxf(0.0,-tangent.y)
		var edge := smoothstep(0.0,0.18,float(i)/(count-1))*(1.0-smoothstep(0.82,1.0,float(i)/(count-1)))
		strand.centers.append([point.x,point.y,point.z])
		strand.tau.append(length)
		strand.axA.append([across.x,across.y,across.z])
		strand.axB.append([outward.x,outward.y,outward.z])
		strand.halfW.append(route.width*0.48*edge+0.015)
		strand.thick.append(0.035+0.07*edge)
		strand.aer.append(0.35+0.5*steep)
		strand.steep.append(steep)
	var mesh := preload("res://scripts/native_fall_renderer.gd").create(strand)
	mesh.name = "StreamCascade"
	return mesh
