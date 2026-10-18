extends RefCounted
## Whether a lump (an enemy's body, a head on its column) stands clear of a
## layer's plan: its isles, its edges' paths, the rides' tubes, the gulfs'
## piers and the cannons (scripts/roguelike/layer_enemies.gd and
## layer_bodies.gd ask `_lumps_clear` before they lay one).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")

## Clear (m) round an edge's path, a tube, a pier, a cannon.
const PATH_CLEAR := 5.0
const TUBE_CLEAR := 6.0
const PIER_CLEAR := 16.0
const CANNON_CLEAR := 6.0

## Whether lumps ([middle, radius, under, over], world) stand clear of every
## isle, every edge's path but `skip`'s, the rides' tubes, the gulfs' piers
## and the cannons.
static func _lumps_clear(plan: Dictionary, lumps: Array, skip := -1) -> bool:
	for l: Array in lumps:
		var p: Vector3 = l[0]
		var r: float = l[1]
		var lo := p.y-float(l[2])
		var hi := p.y+float(l[3])
		for isle: Dictionary in plan.isles:
			if not LayerPlan._rect(isle).grow(r+2.0).has_point(Vector2(p.x,p.z)): continue
			var k := -r
			while k <= r:
				var j := -r
				while j <= r:
					if k*k+j*j <= r*r+1.0:
						var o := LayerPlan.occ_at(isle,p.x+k,p.z+j)
						if o.x < INF and o.x < hi+LayerPlan.CLEAR*0.5 and lo-LayerPlan.CLEAR*0.5 < o.y: return false
					j += 2.0
				k += 2.0
		for i in range((plan.edges as Array).size()):
			if i == skip: continue
			for s: Array in plan.edges[i].path:
				var q: Vector3 = s[0]
				if absf(q.x-p.x) > r+PATH_CLEAR or absf(q.z-p.z) > r+PATH_CLEAR: continue
				if Vector2(q.x-p.x,q.z-p.z).length() < r+PATH_CLEAR*0.5 and q.y-float(s[1]) < hi+2.0 and q.y+float(s[2]) > lo-2.0: return false
		for t: Array in plan.tubes:
			var tp: Vector3 = t[0]
			if tp.distance_to(Vector3(p.x,clampf(tp.y,lo,hi),p.z)) < float(t[1])+r+TUBE_CLEAR*0.5: return false
		for kp: Array in _keep(plan):
			var c: Vector3 = kp[0]
			if Vector2(c.x-p.x,c.z-p.z).length() < float(kp[1])+r and c.y > lo-8.0 and c.y < hi+8.0: return false
	return true

## The gulfs' piers and the cannons and kegs: [point, clear].
static func _keep(plan: Dictionary) -> Array:
	var keep: Array = []
	for gi: int in plan.gulfs:
		var g: Dictionary = plan.edges[gi]
		keep.append([g.from_rim.at,PIER_CLEAR])
		keep.append([g.to_rim.at,PIER_CLEAR])
	for e: Dictionary in plan.edges:
		var c: Dictionary = e.get("cannon",{})
		if c.is_empty(): continue
		keep.append([c.at,CANNON_CLEAR])
		for kat: Vector3 in c.kegs: keep.append([kat,CANNON_CLEAR])
	if not (plan.cannon as Dictionary).is_empty():
		keep.append([plan.cannon.at,CANNON_CLEAR])
		for kat: Vector3 in plan.cannon.kegs: keep.append([kat,CANNON_CLEAR])
	return keep

# --- The slot (LayerStage forwards) -------------------------------------------------