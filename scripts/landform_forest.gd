extends RefCounted
## The forest landform: a wooded island for the lower world, ACROSS m wide,
## made to be skimmed over low in the plane. Its recipe is a SkyIslet's
## (scripts/sky_islet.gd `author`):
##   the ground: a grove's, its grid coarser on the bigger islands (STEPS),
##     rising inland in a dome to one to three rounded hills of high ground
##     (HILLS), so the canopy rolls over them;
##   the stream: on most, a brook rising between the hills and running
##     down a valley it has cut to the shore (scripts/islet_stream.gd),
##     a darker fold through the trees with water at its floor;
##   the wood: scripts/forest_canopy.gd, dark spruce on the high ground,
##     birch and mixed stands lower, birch and willow along the stream, a
##     ragged edge of birch, young spruce and juniper meeting the shore,
##     redwood giants standing over it (a grove of them on some), a
##     clearing levelled to land in, a glade or more to see into;
##   the far trees: its trees drawn as cheap stand-ins past FAR m
##     (scripts/far_trees.gd), so many forested islands show at once.
## The islet stands in the sea in the lower world; the sea foot is the
## world's, not the recipe's.

const NAME := "forest"
const ACROSS := Vector2(30.0,90.0)

## The grid's step (m) by width: [widest it serves, step], as the other
## landforms' (scripts/landform_hills.gd STEPS), so many can stand in view.
const STEPS := [[40.0,1.0],[65.0,4.0/3.0],[INF,2.0]]
## The dome inland (m), and the hills: how many, how high (m, at the
## smallest and the biggest island), their reach (share of the radius), and
## how far out their middles stand (share of the radius).
const DOME := Vector2(1.0,3.0)
const HILLS := Vector2i(1,3)
const HILL_HEIGHT := Vector2(1.8,4.5)
const HILL_REACH := Vector2(0.45,0.75)
const HILL_OUT := 0.3
## The odds of a stream, at the smallest and the biggest island; its
## valley's half width (m) and how deep it cuts (m), likewise.
const STREAM := Vector2(0.5,1.0)
const VALLEY := Vector2(3.8,8.0)
const INCISE := Vector2(0.9,2.2)
## The clearing's radius (m), the glades' count and radius (m), likewise.
const CLEARING := [Vector2(4.5,6.0),Vector2(7.5,10.0)]
const GLADES := [Vector2i(1,2),Vector2i(2,4)]
const GLADE := [Vector2(2.8,4.0),Vector2(4.0,6.5)]
## Giants, at the smallest and the biggest, and the odds of a grove.
const GIANTS := [Vector2i(0,1),Vector2i(1,4)]
const GROVE := Vector2(0.15,0.45)
## The erosion: its passes (the islets' 16) and its grid's cell (share of
## the island's grid step): under the trees its fine gullies hardly show,
## and on the plate's fine cell it is most of a big island's build.
const ERODE_PASSES := 8
const ERODE_CELL := 1.0
## Grass tufts (share of an islet's), the far trees' range (m).
const TUFTS := 0.3
const FAR := 150.0
## The rock under it: the forest hold's basalts.
const ROCK := {"basalt":1.0,"basalt_warm":0.7,"slate":0.4}

## A SkyIslet recipe for a forested island `across` m wide (clamped to
## ACROSS), seeded by `rng`.
static func recipe(rng: RandomNumberGenerator, across: float) -> Dictionary:
	across = clampf(across,ACROSS.x,ACROSS.y)
	var radius := across*0.5
	var big := inverse_lerp(ACROSS.x,ACROSS.y,across)
	# The high ground: hills about the middle, the first the highest.
	var hills: Array[Vector4] = []
	var lift := lerpf(HILL_HEIGHT.x,HILL_HEIGHT.y,big)
	var first := Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.0,HILL_OUT)
	for k in range(rng.randi_range(HILLS.x,HILLS.y)):
		var at := first if k == 0 else first+Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.35,0.6)
		if at.length() > radius*0.55: at = at.normalized()*radius*0.55
		var height := lift*rng.randf_range(0.8,1.1)*(1.0 if k == 0 else rng.randf_range(0.5,0.8))
		hills.append(Vector4(at.x,at.y,radius*rng.randf_range(HILL_REACH.x,HILL_REACH.y),height))
	var spec := {
		"kind":"grove","radius":radius,"step":_step(across),
		"dome":lerpf(DOME.x,DOME.y,big)*rng.randf_range(0.8,1.2),"mounds":hills,
		"trees":Vector2i(0,0),"drifts":Vector2i(0,0),"undergrowth":0.0,"tufts":TUFTS,"far_trees":FAR,
		"erode":{"iterations":ERODE_PASSES,"cell":_step(across)*ERODE_CELL},
		"rock":{"palette":_weighted(ROCK,rng.randf()),"tone":rng.randf_range(0.86,1.05),"vary":rng.randf()},
		"forest":{
			"clearing":(CLEARING[0] as Vector2).lerp(CLEARING[1],big),
			"glades":Vector2i(roundi(lerpf(GLADES[0].x,GLADES[1].x,big)),roundi(lerpf(GLADES[0].y,GLADES[1].y,big))),
			"glade":(GLADE[0] as Vector2).lerp(GLADE[1],big),
			"giants":Vector2i(roundi(lerpf(GIANTS[0].x,GIANTS[1].x,big)),roundi(lerpf(GIANTS[0].y,GIANTS[1].y,big))),
			"grove":lerpf(GROVE.x,GROVE.y,big),
			"line":rng.randf_range(0.4,0.6),
		},
	}
	# The stream: from the high ground's foot, out the way away from it.
	if rng.randf() < lerpf(STREAM.x,STREAM.y,big):
		var away := -first.normalized() if first.length() > 1.0 else Vector2.from_angle(rng.randf()*TAU)
		away = away.rotated(rng.randf_range(-0.6,0.6))
		var from := first+away*radius*rng.randf_range(0.2,0.35)
		spec.stream = {"from":from,"toward":away,"valley":lerpf(VALLEY.x,VALLEY.y,big)*rng.randf_range(0.85,1.15),
			"incise":lerpf(INCISE.x,INCISE.y,big)}
	return spec

## The grid's step for an island `across` m wide (STEPS).
static func _step(across: float) -> float:
	for s: Array in STEPS:
		if across <= float(s[0]): return float(s[1])
	return 2.0

static func _weighted(pool: Dictionary, roll: float) -> String:
	var total := 0.0
	for k in pool: total += float(pool[k])
	roll *= total
	for k in pool:
		roll -= float(pool[k])
		if roll <= 0.0: return k
	return pool.keys()[0]
