extends RefCounted
## Independent, versioned underground genome; never consumes the surface RNG.
const VERSION := 1
const PALETTES := {
	"mossy shale":{"rock":Color("61756c"),"light":Color("9ab6aa"),"water":Color("274c48")},
	"limestone":{"rock":Color("958d74"),"light":Color("c5bda3"),"water":Color("456663")},
	"blue slate":{"rock":Color("667987"),"light":Color("9fb7c8"),"water":Color("304e64")}
}
static func recipe(seed_value: int, palette_name := "mossy shale", moisture := 0.75) -> Dictionary:
	return {"version":VERSION,"seed":seed_value,"palette":palette_name,"moisture":moisture}

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	return value.size()==4 and value.get("version")==VERSION and GardenData._integer(value.get("seed")) and GardenData._number(value.seed,0,999999) and PALETTES.has(value.get("palette","")) and GardenData._number(value.get("moisture"),0,1)

static func sample(settings: Dictionary) -> Dictionary:
	assert(valid(settings) and not settings.is_empty())
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.seed)*7919+1907
	var rooms: Array[Dictionary] = []
	for center in [Vector2(-6,8),Vector2(5,7),Vector2(-8,-3),Vector2(7,-4),Vector2(-1,-8)]:
		var point: Vector2 = center+Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))
		rooms.append({"center":point,"radius":rng.randf_range(4.4,5.4),"height":rng.randf_range(6.2,7.7)})
	# Minimum spanning tree guarantees all chambers belong to one system.
	var links: Array[Dictionary] = []
	var reached := [0]
	while reached.size()<rooms.size():
		var nearest := INF
		var from := 0
		var to := 0
		for a: int in reached:
			for b in range(rooms.size()):
				if b in reached: continue
				var distance: float = rooms[a].center.distance_squared_to(rooms[b].center)
				if distance<nearest:
					nearest = distance
					from = a
					to = b
		links.append({"from":from,"to":to,"radius":rng.randf_range(1.8,2.3)})
		reached.append(to)
	# One loop lets the interior have an alternate passage.
	links.append({"from":0,"to":1,"radius":2.0})
	var exposures := [
		{"from":0,"point":Vector2(rooms[0].center.x,15.0),"radius":3.7},
		{"from":1,"point":Vector2(rooms[1].center.x,15.0),"radius":3.3},
		{"from":2,"point":Vector2(-15,rooms[2].center.y),"radius":3.0},
		{"from":3,"point":Vector2(15,rooms[3].center.y),"radius":3.0},
		{"from":4,"point":Vector2(rooms[4].center.x,-15),"radius":3.3}]
	return {"rooms":rooms,"links":links,"exposures":exposures,"bed":rooms[0].center,"pool":rooms[1].center+Vector2(0,2.0)}

static func segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var edge := b-a
	return point.distance_to(a+edge*clampf((point-a).dot(edge)/maxf(edge.length_squared(),0.001),0,1))

static func field(layout: Dictionary, point: Vector2) -> float:
	var value := -INF
	for room: Dictionary in layout.rooms:
		value = maxf(value,float(room.radius)-point.distance_to(room.center))
	for link: Dictionary in layout.links:
		value = maxf(value,float(link.radius)-segment_distance(point,layout.rooms[link.from].center,layout.rooms[link.to].center))
	for opening: Dictionary in layout.exposures:
		value = maxf(value,float(opening.radius)-segment_distance(point,layout.rooms[opening.from].center,opening.point))
	return value

static func passage_distance(layout: Dictionary, point: Vector2) -> float:
	var value := INF
	for link: Dictionary in layout.links:
		value = minf(value,segment_distance(point,layout.rooms[link.from].center,layout.rooms[link.to].center))
	return value

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.size()!=2 or not valid(value.get("genome")) or value.genome.is_empty(): return false
	if not value.get("stash") is Array or value.stash.size()>24: return false
	for item in value.stash:
		if item not in ["branch","leaves","fish","fruit"]: return false
	return true
