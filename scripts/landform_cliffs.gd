extends RefCounted
## The lower world's sea-cliff islands: a grassy tableland whose edges drop
## in tall, layered rock walls straight to the sea, sea stacks standing off
## them, now and then an arch, and a glen on the low side coming down to a
## small cove with a beach (Hebrides, Faroe, Moher). The run along the
## face and between the stacks is the thing to fly.
##
## `recipe` is a SkyIslet recipe (scripts/sky_islet.gd `author`); the shaping
## is scripts/sea_cliffs.gd (the recipe's `cliffs`). The islet's frame: the
## sea at SEA (y = 0), the cove's beach just over it, the tableland CLIFF m
## over it (scaled by the island's width), the rock going on down under the
## sea to the islet's foot. Big islands are laid on a coarser grid (STEP).
##   godot --path . -- --no-title --landform=cliffs

const SeaCliffs = preload("res://scripts/sea_cliffs.gd")

const NAME := "cliffs"
## Island width range (m): the width of a circle of its land.
const ACROSS := Vector2(30.0,90.0)
## The sea's level in the islet's frame.
const SEA := SeaCliffs.SEA
## The high side's cliff over the sea (m), for the narrowest island and the
## widest, each drawn within CLIFF_SPREAD of it; the low side's share.
const CLIFF := Vector2(14.0,36.0)
const CLIFF_SPREAD := 0.15
const LOW := Vector2(0.4,0.62)
## The grid's step (m) by width, as the other landforms snap it: the
## narrowest third, the middle, the widest.
const STEPS := [1.0,4.0/3.0,2.0]
## Stacks, by width (narrowest, widest), the odds of an arch, of a cove.
const STACKS := [Vector2i(1,2),Vector2i(2,4)]
const ARCH_ODDS := 0.6
const COVE_ODDS := 0.9
## The beds' unit (m), a whole number of which each bed of the walls is high.
const BED := Vector2(1.5,2.3)
## The rock looks it is drawn in (scripts/rock_looks.gd), by weight, and
## their tone range.
const ROCK := {"basalt_warm":1.0,"basalt":0.6,"slate":0.3}
const TONE := Vector2(0.78,0.95)
## The rock's keel under the sea: a share of an islet's own.
const KEEL := 0.35
## The planting: a few wind-bent trees in shelter, machair drifts.
const TREES := Vector2i(0,4)
const TREE_POOL := {"juniper":1.0,"tree":0.6,"birch":0.35}
const DRIFTS := Vector2i(3,7)

## A SkyIslet recipe for a cliff island `across` m wide, drawn from `rng`.
static func recipe(rng: RandomNumberGenerator, across: float) -> Dictionary:
	across = clampf(across,ACROSS.x,ACROSS.y)
	var size := (across-ACROSS.x)/(ACROSS.y-ACROSS.x)
	var height := lerpf(CLIFF.x,CLIFF.y,size)*rng.randf_range(1.0-CLIFF_SPREAD,1.0+CLIFF_SPREAD)
	var stacks: Vector2i = STACKS[0] if size < 0.5 else STACKS[1]
	var bed := rng.randf_range(BED.x,BED.y)
	var total := 0.0
	for k: String in ROCK: total += float(ROCK[k])
	var roll := rng.randf()*total
	var palette: String = ROCK.keys()[0]
	for k: String in ROCK:
		roll -= float(ROCK[k])
		if roll <= 0.0:
			palette = k
			break
	return {"kind":"hills","radius":across*0.5,"step":STEPS[clampi(roundi(size*2.0),0,2)],
		"room":SeaCliffs.GAP.y+SeaCliffs.STACK.y*2.6,
		"cliffs":{"height":height,"low":rng.randf_range(LOW.x,LOW.y),"tilt":rng.randf()*TAU,"bed":bed,
			"stacks":rng.randi_range(stacks.x,stacks.y),"arch":rng.randf() < ARCH_ODDS,"cove":rng.randf() < COVE_ODDS},
		"mounds":[],"dome":0.4,"keel":KEEL,
		"trees":TREES,"tree_pool":TREE_POOL,"drifts":DRIFTS,"undergrowth":0.6,
		"rock":{"palette":palette,"tone":rng.randf_range(TONE.x,TONE.y),"vary":rng.randf(),"bed":bed}}
