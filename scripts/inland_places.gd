extends RefCounted
## Small inhabitable terraces, planned against the original terrain and water.
## Derived from the recipe seed; no additional save fields are required.
static func plan(field: RefCounted) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(field.genome.seed)*7919+967
	var result: Array[Dictionary] = []
	for slot in range(3):
		var best := {}
		var best_score := INF
		for i in range(90):
			var p := Vector2(rng.randf_range(-8.5,8.5),rng.randf_range(-7.5,8.5))
			var h: float = field.original_height(p.x,p.y)
			if not field.has_ground(p,3.0) or field.wet(p,0.9): continue
			var separated := true
			for place in result:
				if p.distance_to(place.center)<5.0: separated = false
			if not separated: continue
			var slope := Vector2(field.original_height(p.x+0.5,p.y)-h,field.original_height(p.x,p.y+0.5)-h).length()*2.0
			var score := h*0.35+slope*2.0+rng.randf()*0.5
			if score<best_score:
				best_score = score
				best = {"center":p,"height":h,"radius":rng.randf_range(1.9,2.4),"kind":slot}
		if not best.is_empty(): result.append(best)
	return result

static func shape(places: Array[Dictionary],p: Vector2,base: float) -> float:
	for place in places:
		var distance: float = p.distance_to(place.center)
		var blend := 1.0-smoothstep(float(place.radius)*0.65,float(place.radius)+1.7,distance)
		base = lerpf(base,float(place.height),blend)
	return base

## Connected dry ground matters more than the number of scattered objects.
static func quality(field: RefCounted) -> Dictionary:
	var usable := {}
	for z in range(-10,11):
		for x in range(-10,11):
			var p := Vector2(x,z)
			if not field.has_ground(p,0.6) or field.wet(p): continue
			var slope := Vector2(field.height(x+0.25,z)-field.height(x-0.25,z),field.height(x,z+0.25)-field.height(x,z-0.25)).length()*2.0
			if slope<=0.65: usable[Vector2i(x,z)] = true
	var remaining := usable.duplicate()
	var largest := 0
	while not remaining.is_empty():
		var queue: Array = [remaining.keys()[0]]
		remaining.erase(queue[0])
		var cursor := 0
		while cursor<queue.size():
			var cell: Vector2i = queue[cursor]
			cursor += 1
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = cell+offset
				if remaining.erase(next): queue.append(next)
		largest = maxi(largest,queue.size())
	return {"usable":usable.size()/441.0,"connected":largest/441.0,"places":field.places.size()}
