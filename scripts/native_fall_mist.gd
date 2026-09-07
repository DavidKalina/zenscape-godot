extends RefCounted
## Source weighted plunge/ledge/veil emitters and deterministic particle recipe.
static func build(strands: Array,flow: float) -> Dictionary:
	var emitters: Array=[]
	for s in strands:
		emitters.append({"at":s.impact,"weight":3.0,"spread":0.6+flow*0.6})
		for r in s.ledges: emitters.append({"at":s.centers[r],"weight":1.0,"spread":s.halfW[r]*1.2})
		for r in range(2,s.centers.size()-1,2):
			var air: float=s.aer[r]
			if air>=0.25: emitters.append({"at":s.centers[r],"weight":air*air*1.6,"spread":s.halfW[r]*1.1})
	var total:=0.0
	for emitter in emitters: total+=emitter.weight
	var count:=floori(40.0*flow+0.5)+emitters.size()*5 if not emitters.is_empty() else 0
	var origins:=PackedFloat32Array()
	var velocity:=PackedFloat32Array()
	var phase:=PackedFloat32Array()
	var sizes:=PackedFloat32Array()
	for i in range(count):
		var pick:=_hash(i,7)*total
		var emitter: Dictionary=emitters[0]
		for candidate in emitters:
			emitter=candidate
			pick-=candidate.weight
			if pick<=0.0: break
		var angle:=_hash(i,3)*PI*2.0
		var radius: float=sqrt(_hash(i,5))*emitter.spread
		origins.append(emitter.at[0]+cos(angle)*radius)
		origins.append(emitter.at[1]+0.05)
		origins.append(emitter.at[2]+sin(angle)*radius)
		var ox: float=origins[i*3]-emitter.at[0]
		var oz: float=origins[i*3+2]-emitter.at[2]
		var length:=sqrt(ox*ox+oz*oz)
		if length==0.0: length=1.0
		var speed:=0.4+_hash(i,6)*0.8
		velocity.append(ox/length*speed+(_hash(i,8)-0.5)*0.5)
		velocity.append(0.0)
		velocity.append(oz/length*speed+(_hash(i,9)-0.5)*0.5)
		phase.append(_hash(i,10))
		sizes.append(0.7+_hash(i,11)*0.8)
	return {"positions":origins,"velocity":velocity,"phase":phase,"size":sizes,"rise":snappedf(0.9+0.6*flow,0.01)}
static func _hash(x: float,z: float) -> float:
	return preload("res://scripts/native_recipe_water.gd")._hash(x,z)
static func batches(recipe: Dictionary,transform: Transform3D) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for first in range(0,recipe.phase.size(),64):
		var data: Dictionary={"positions":[],"velocity":[],"phase":[],"size":[],"rise":recipe.rise*transform.basis.y.length()}
		for i in range(first,mini(first+64,recipe.phase.size())):
			var p:=transform*Vector3(recipe.positions[i*3],recipe.positions[i*3+1],recipe.positions[i*3+2])
			var v:=transform.basis*Vector3(recipe.velocity[i*3],recipe.velocity[i*3+1],recipe.velocity[i*3+2])
			data.positions.append_array([p.x,p.y,p.z])
			data.velocity.append_array([v.x,v.y,v.z])
			data.phase.append(recipe.phase[i])
			data.size.append(recipe.size[i]*transform.basis.x.length())
		result.append(data)
	return result
