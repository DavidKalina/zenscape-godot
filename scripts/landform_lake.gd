extends RefCounted
## The lake landform: an island of the lower world holding an inland lake,
## its water standing over the sea in a bowl of green land, so that from
## the plane it reads at once as a bright, glassy eye of water in green.
## A recipe for SkyIslet (scripts/sky_islet.gd `author`), the lake itself
## cut by the islet's own lake (scripts/islet_lake.gd, the lake motif's):
## the bank round it wanders, a beach eases down to the water, reeds stand
## in the shallow shelf and the bowl drops to slate-blue deep water; the
## lake spills over the rim through a broad notch as a wide curtain of a
## fall (SkyIslets `curtain`, the fall half width scaled to the island) down
## toward the sea. The pilot can wade its shallows and swim its deep water
## (the lake's `swim`, scripts/wanderer_eye.gd).
##
## Three flavours (FLAVOURS), each drawn by weight:
##   mere: a bright lowland lake, low green banks with beaches all round, a
##     soft rise or two, willows and birches, flower drifts; clear water;
##   tarn: a dark upland lake in a deeper bowl, hills standing round it and
##     rock where they are steep, conifers, ferns and fallen wood, reeds
##     thick in the shallows: the water steeps dark slate-blue by what grows
##     round it (the lake's `tea`, after scripts/lake_tea.gd);
##   isle: a broad lake round a wooded island in its middle.
## The bowl's rim hills (MOUNDS) are laid round the middle at a share of the
## radius, so the land rises away from the water on a side or two. Big
## islands take a coarser grid (STEPS, the hills landform's), so a big
## island builds in time (tools/bench_landform_lake.gd).

const Genesis = preload("res://scripts/genesis_canvas.gd")

const NAME := "lake"
const ACROSS := Vector2(30.0,90.0)
## The sea's level in the islet's frame (scripts/landforms.gd): RISE m
## under the rim, so in the lower world the lake (at about the rim's
## height, IsletLake LEVEL) stands that much over the sea and its fall
## pours down the bank into it, rather than meeting the sea level with it.
const RISE := 1.0
const SEA := Genesis.RIM_HEIGHT-RISE
## The flavours and how often each turns up.
const FLAVOURS := [["mere",0.45],["tarn",0.35],["isle",0.2]]
## The grid's step (m) by width: [widest it serves, step].
const STEPS := [[40.0,1.0],[65.0,4.0/3.0],[INF,2.0]]
## The bank's width in from the shore, as shares of the radius (the
## lake's own `bank` is narrowed to keep water on the land, IsletLake);
## the deep's depth (m) grows with the radius by GROW a metre over 15 m,
## the shelf's width by SHELF_GROW of that.
const BANK := {"mere":Vector2(0.12,0.26),"tarn":Vector2(0.16,0.3),"isle":Vector2(0.1,0.2)}
const SHELF := Vector2(1.4,2.8)
const DEPTH := Vector2(2.6,3.6)
const GROW := 0.05
const SHELF_GROW := 0.3
## The isle: odds of one by flavour, and its radius as shares of the radius.
const ISLE := {"mere":0.3,"tarn":0.2,"isle":1.0}
const ISLE_SIZE := {"mere":Vector2(0.08,0.12),"tarn":Vector2(0.07,0.1),"isle":Vector2(0.15,0.21)}
## The fall's half width as shares of the radius (and the channel's, a
## little wider than the fall, so the notch frames it).
const FALL := Vector2(0.055,0.09)
const CHANNEL := 1.15
## Reeds: the lake's reed clumps and bank grass a metre of radius over the
## lake motif's (IsletLake REED_CLUMPS), by flavour.
const REEDS := {"mere":0.07,"tarn":0.12,"isle":0.08}
## The bowl's rim hills: how many, their middles' distance out (share of the
## radius), their reach (share of the radius) and height (m a metre of
## radius), by flavour.
const MOUNDS := {"mere":Vector2i(2,4),"tarn":Vector2i(4,6),"isle":Vector2i(2,3)}
const MOUND_OUT := Vector2(0.7,0.9)
const MOUND_REACH := {"mere":Vector2(0.3,0.45),"tarn":Vector2(0.35,0.5),"isle":Vector2(0.3,0.4)}
const MOUND_HEIGHT := {"mere":Vector2(0.05,0.09),"tarn":Vector2(0.09,0.16),"isle":Vector2(0.05,0.08)}
## The beach: how far up from the waterline the bank eases (m), so a rim
## hill comes down to the water gently; and the most a tarn steeps (0 to 1),
## so it stays slate-blue over the shelves rather than umber.
const BEACH := {"mere":Vector2(3.0,4.5),"tarn":Vector2(2.2,3.2),"isle":Vector2(3.0,4.0)}
const TEA := 0.55
## How the islet grows: its kind (the undergrowth and flowers it draws
## from), dome, trees a metre of radius (spread over it), copses a metre
## of radius (stands of one species round the water, IsletLake `copses`),
## the species, flower drifts and undergrowth.
const KIND := {"mere":"meadow","tarn":"grove","isle":"meadow"}
const DOME := {"mere":0.3,"tarn":0.5,"isle":0.25}
const TREES := {"mere":Vector2(0.6,0.9),"tarn":Vector2(1.3,1.9),"isle":Vector2(0.5,0.8)}
const COPSES := {"mere":Vector2(0.1,0.16),"tarn":Vector2(0.16,0.26),"isle":Vector2(0.08,0.12)}
const TREE_POOL := {
	"mere":{"willow":1.0,"birch":0.9,"layered_tree":0.35,"broadleaf":0.25},
	"tarn":{"tree":1.0,"juniper":0.7,"redwood":0.2,"birch":0.3},
	"isle":{"birch":1.0,"willow":0.8,"tree":0.4},
}
const DRIFTS := {"mere":Vector2(0.1,0.2),"tarn":Vector2(0.03,0.06),"isle":Vector2(0.08,0.15)}
const UNDERGROWTH := {"mere":0.8,"tarn":0.45,"isle":0.8}

## A recipe for an island `across` m wide (ACROSS), drawn from `rng`.
static func recipe(rng: RandomNumberGenerator, across: float) -> Dictionary:
	across = clampf(across,ACROSS.x,ACROSS.y)
	var radius := across*0.5
	var flavour := _weighted(rng)
	var grow := 1.0+maxf(radius-15.0,0.0)*GROW
	var copses: Vector2 = COPSES[flavour]*radius
	var fall := radius*rng.randf_range(FALL.x,FALL.y)
	var bank: Vector2 = BANK[flavour]
	var lake := {
		"bank":bank*radius,
		"shelf":SHELF*(1.0+(grow-1.0)*SHELF_GROW),
		"depth":DEPTH*grow,
		"isle":ISLE[flavour],
		"isle_radius":(ISLE_SIZE[flavour] as Vector2)*radius,
		"copses":Vector2i(roundi(copses.x),roundi(copses.y)),
		"fall":fall,
		"channel":fall*CHANNEL,
		"reeds":maxf(1.0,radius*float(REEDS[flavour])),
		"toward":Vector2.from_angle(rng.randf()*TAU),
		"beach":rng.randf_range((BEACH[flavour] as Vector2).x,(BEACH[flavour] as Vector2).y),
		"swim":true,
	}
	if flavour == "tarn": lake.tea = TEA
	# The bowl's rim hills, spread round the middle.
	var mounds: Array[Vector4] = []
	var count: Vector2i = MOUNDS[flavour]
	var heights: Vector2 = MOUND_HEIGHT[flavour]
	var turn := rng.randf()*TAU
	var n := rng.randi_range(count.x,count.y)
	for k in range(n):
		var a := turn+TAU*(k+rng.randf_range(-0.25,0.25))/n
		var out := radius*rng.randf_range(MOUND_OUT.x,MOUND_OUT.y)
		var reach: Vector2 = MOUND_REACH[flavour]
		mounds.append(Vector4(cos(a)*out,sin(a)*out,radius*rng.randf_range(reach.x,reach.y),radius*rng.randf_range(heights.x,heights.y)))
	var trees: Vector2 = TREES[flavour]*radius
	var drifts: Vector2 = DRIFTS[flavour]*radius
	var spec := {
		"kind":KIND[flavour],"flavour":flavour,"radius":radius,"dome":DOME[flavour],"lake":lake,"mounds":mounds,
		"trees":Vector2i(roundi(trees.x),roundi(trees.y)),"tree_pool":TREE_POOL[flavour],"mixed":true,
		"drifts":Vector2i(roundi(drifts.x),maxi(roundi(drifts.y),1)),"undergrowth":UNDERGROWTH[flavour],
	}
	for s: Array in STEPS:
		if across <= float(s[0]):
			spec.step = float(s[1])
			break
	return spec

static func _weighted(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for f: Array in FLAVOURS: total += float(f[1])
	var roll := rng.randf()*total
	for f: Array in FLAVOURS:
		roll -= float(f[1])
		if roll <= 0.0: return f[0]
	return FLAVOURS[0][0]
