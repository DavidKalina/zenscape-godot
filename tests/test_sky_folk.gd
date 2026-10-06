extends SceneTree
## The sky folk (scripts/sky_folk.gd) on a stand-in island: the same seed
## gives the same people in the same spots; they stand on dry, gentle
## ground in from the shore, never in the pond or on the cliff; left alone
## they wander a little and stay near their spot, on the ground; a plane
## over them and they hail it, turned towards it; the wanderer near and
## they wave; far off they are still, and farther not drawn.
const SkyFolk = preload("res://scripts/sky_folk.gd")
const DT := 1.0/30.0
var failures := 0

## An island 30 m across with a pond in one corner (x, z > 6) and a cliff
## (a sharp step) along x = -6.
class Land extends RefCounted:
	func nearest_land(p: Vector2, inset: float, _reach: float) -> Vector2:
		return p if maxf(absf(p.x),absf(p.y)) <= 15.0-inset else Vector2.INF
	func water_reaches(r: Rect2) -> bool:
		return r.end.x > 6.0 and r.end.y > 6.0
	func ground_height(p: Vector2) -> Variant:
		if maxf(absf(p.x),absf(p.y)) > 15.0: return null
		return 2.0+(1.5 if p.x < -6.0 else 0.0)

func _initialize() -> void:
	var land := Land.new()
	var counts := {}
	var ok := true
	var same := true
	for chunk_seed in range(40):
		var a := _settle(chunk_seed,land)
		var b := _settle(chunk_seed,land)
		counts[a.people.size()] = true
		for i in range(a.people.size()):
			var p: Vector2 = a.people[i].home
			same = same and b.people.size() == a.people.size() and p == b.people[i].home
			ok = ok and maxf(absf(p.x),absf(p.y)) <= 15.0-SkyFolk.INSET and not (p.x > 6.0-SkyFolk.DRY and p.y > 6.0-SkyFolk.DRY) and absf(p.x+6.0) > SkyFolk.FLAT
			ok = ok and is_equal_approx(a.people[i].figure.position.y,float(land.ground_height(p))+5.0)
		a.free()
		b.free()
	check(same,"The same seed gives the same people in the same spots")
	check(counts.size() > 1 and counts.keys().all(func(n: int) -> bool: return n >= SkyFolk.PER_ISLAND.x and n <= SkyFolk.PER_ISLAND.y),"Between %d and %d an island (%s)" % [SkyFolk.PER_ISLAND.x,SkyFolk.PER_ISLAND.y,str(counts.keys())])
	check(ok,"On dry, gentle ground in from the shore, standing on it")
	var folk := _settle(3,land)
	var person: Dictionary = folk.people[0]
	var figure: Node3D = person.figure
	var walked := false
	var strayed := 0.0
	var start := figure.position
	for i in range(30*40):
		folk.step(DT,figure.position+Vector3(30.0,1.0,0.0),false)
		walked = walked or figure.move == "walk"
		strayed = maxf(strayed,Vector2(figure.position.x,figure.position.z).distance_to(person.home))
	check(walked and figure.position.distance_to(start) > 0.05,"Left alone, they walk about")
	check(strayed < SkyFolk.WANDER+0.5,"Staying near their spot (%.2f m)" % strayed)
	check(is_equal_approx(figure.position.y,float(land.ground_height(Vector2(figure.position.x,figure.position.z)))+5.0),"On the ground")
	var plane := figure.position+Vector3(20.0,25.0,0.0)
	for i in range(60): folk.step(DT,plane,true)
	var facing := Vector3(-sin(figure.rotation.y),0.0,-cos(figure.rotation.y))
	check(figure.move == "hail" and facing.dot(Vector3.RIGHT) > 0.9,"A plane over them, they turn and hail it")
	for i in range(30): folk.step(DT,figure.position+Vector3(0.0,0.8,-4.0),false)
	check(figure.move == "wave","The wanderer near, they wave")
	folk.step(DT,figure.position+Vector3(SkyFolk.LIVE+10.0,0.0,0.0),false)
	check(not figure.is_processing() and figure.visible,"Far off, still")
	folk.step(DT,figure.position+Vector3(SkyFolk.SHOW+10.0,0.0,0.0),false)
	check(not figure.visible,"Farther, not drawn")
	folk.free()
	print("PASS: sky folk" if failures == 0 else "FAIL: sky folk")
	quit(1 if failures else 0)

## The land stands 5 m up in the folk's frame.
func _settle(chunk_seed: int, land: Object) -> Node3D:
	var folk: Node3D = SkyFolk.new()
	folk.settle(folk,chunk_seed,land,Transform3D(Basis(),Vector3(0.0,5.0,0.0)))
	return folk

func check(ok: bool, label: String) -> void:
	print(("OK   " if ok else "FAIL ")+label)
	if not ok: failures += 1
