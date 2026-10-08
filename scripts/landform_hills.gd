extends RefCounted
## The hills landform: rolling green hill country standing in the lower
## world's sea, Hebridean downs meeting the shore. Soft swelling downs with
## long grassy slopes, cliffs along some of the coast and beaches along the
## rest, a glen winding down to a cove, a few tors of rock on the high
## shoulders, a lone tree or a small copse on a crest, flower drifts in the
## hollows; shaded broadly so the slopes read from a low-flying plane
## (scripts/hill_downs.gd lays all of it over a SkyIslet, scripts/
## sky_islet.gd, as its recipe's `downs`).
##
## `recipe` gives a SkyIslet recipe (SkyIslet `author`) for an island
## `across` m wide. Big islands take a coarser grid (STEPS), so many can
## stand in view at once: the plate's 0.67 m step would make a 90 m island
## some 60 000 faces and two seconds' work; at 2 m it is some 7 000 and a
## fifth of a second.
##   godot --path . -- --no-title --landform=hills   (scripts/landform_preview.gd)

const NAME := "hills"
const ACROSS := Vector2(30.0,90.0)
## The grid's step (m) by width: [widest it serves, step].
const STEPS := [[40.0,1.0],[65.0,4.0/3.0],[INF,2.0]]
## How high the downs rise over the shore (share of the radius, at least
## and most m).
const RISE := Vector2(0.16,0.26)
const RISE_M := Vector2(2.4,12.0)
## The flower kinds a hill island draws its drifts from (MeadowTypes
## FLOWER_KEYS), by weight: the machair's yellows and whites, some red and
## purple.
const FLOWERS := {"buttercup":1.0,"oxeye_daisy":0.9,"poppy":0.5,"lupine":0.45,"dandelion":0.4}
## The rock under it (scripts/rock_looks.gd), by weight.
const ROCK := {"slate":1.0,"basalt_warm":0.6,"basalt":0.4}

static func recipe(rng: RandomNumberGenerator, across: float) -> Dictionary:
	across = clampf(across,ACROSS.x,ACROSS.y)
	var radius := across*0.5
	var step := 2.0
	for s: Array in STEPS:
		if across <= float(s[0]):
			step = float(s[1])
			break
	var flowers: Array = []
	var pool := FLOWERS.duplicate()
	for n in range(rng.randi_range(2,3)):
		var k := _weighted(pool,rng.randf())
		pool.erase(k)
		flowers.append(k)
	return {"kind":"hills","radius":radius,"step":step,
		# The downs plant their own trees and drifts; the kind's mounds,
		# trees and drifts stay out.
		"mounds":[],"trees":Vector2i(0,0),"drifts":Vector2i(0,0),
		"undergrowth":0.5,"tufts":0.6,
		# Gentle weathering: runnels down the long slopes, not raw scree.
		"erode":{"detail":0.03,"k":0.01,"max_cut":0.16},
		"downs":{"rise":clampf(radius*rng.randf_range(RISE.x,RISE.y),RISE_M.x,RISE_M.y),
			"ridges":Vector2i(2,3) if across < 55.0 else Vector2i(3,4),
			"cliffs":rng.randf_range(0.2,0.7),
			"tors":Vector2i(0,1) if across < 45.0 else Vector2i(1,3),
			"copse":0 if rng.randf() < 0.45 else rng.randi_range(3,6),
			"drifts":rng.randi_range(3,5)+int(across/30.0),
			"flowers":flowers},
		"rock":{"palette":_weighted(ROCK,rng.randf()),"tone":rng.randf_range(0.9,1.1),"vary":rng.randf()}}

static func _weighted(pool: Dictionary, roll: float) -> String:
	var total := 0.0
	for k in pool: total += float(pool[k])
	roll *= total
	for k in pool:
		roll -= float(pool[k])
		if roll <= 0.0: return k
	return pool.keys()[0]
