extends RefCounted
## Stable per-world and per-instance choices for props, rocks and trees.
## Everything here is integer hashing, so a seed gives the same world on every
## platform and no choice consumes a draw from anyone's random stream.

const MASK := 0xFFFFFFFF

## Rock characters. Each world leans on one of them (see `world`), so one
## world's stones read as granite knolls and another's as split slate.
## Weights are over RockVariants.VARIANTS, in order:
## rounded, lumpy, blocky, tabular, slab, flag, shard, column.
const ROCK_STYLES := {
	"granite":[4.0,3.0,1.5,0.5,1.0,0.3,0.3,0.2],
	"slate":[0.5,0.5,1.5,1.0,4.0,3.0,1.5,0.3],
	"basalt":[0.5,1.0,4.0,1.0,0.5,0.3,1.0,3.0],
	"sandstone":[1.5,2.0,1.0,4.0,2.0,0.5,0.3,1.0],
}
const WET_STYLES := ["granite","granite","slate","basalt","sandstone"]
const DRY_STYLES := ["sandstone","sandstone","basalt","granite"]
## Share of a world's rocks drawn evenly from every variant, so a styled world
## still shows the odd stranger.
const ROCK_SPREAD := 0.2

## A 32-bit integer mix of any number of integers.
static func mix(values: Array) -> int:
	var h := 0x9E3779B9
	for v in values:
		h = _avalanche(h ^ (int(v) & MASK))
	return h

## A stable 0..1 value from integers.
static func unit(values: Array) -> float:
	return float(mix(values))/4294967296.0

## Centimetre grid coordinates, so a position hashes the same after JSON.
static func cell(p: Vector2) -> Array:
	return [roundi(p.x*100.0),roundi(p.y*100.0)]

static func _avalanche(x: int) -> int:
	x = ((x >> 16) ^ x) & MASK
	x = (x*0x045d9f3b) & MASK
	x = ((x >> 16) ^ x) & MASK
	x = (x*0x045d9f3b) & MASK
	return ((x >> 16) ^ x) & MASK

## Index into `weights` for a 0..1 roll.
static func weighted(weights: Array, roll: float) -> int:
	var total := 0.0
	for w in weights: total += float(w)
	roll *= total
	for i in range(weights.size()):
		roll -= float(weights[i])
		if roll < 0.0: return i
	return weights.size()-1

## A world's multiplier for one named rate, 0.5..1.6, so each world keeps its
## own balance of logs, ferns or flowers instead of one fixed ratio.
static func lean(salt: int, name: String) -> float:
	return lerpf(0.5,1.6,unit([salt,name.hash()]))

## What the renderer needs to pick mesh variants for one world. Built on the
## main thread from the recipe; an empty recipe gives the neutral world 0.
static func world(settings: Dictionary) -> Dictionary:
	var salt := 0
	if settings.has("seed"): salt = mix([int(settings.seed),1])
	elif settings.has("variation"): salt = mix([int(settings.variation),2])
	var dry: bool = settings.get("biome","") in ["arid","desert"]
	var styles: Array = DRY_STYLES if dry else WET_STYLES
	var style: String = "granite" if salt == 0 else styles[mix([salt,3])%styles.size()]
	var rock: Array = []
	for w in ROCK_STYLES[style]: rock.append(float(w)*(1.0-ROCK_SPREAD)+ROCK_SPREAD*2.0)
	# Layered broadleaves: every world favours one of the forms.
	var layered := [1.0,1.0,1.0]
	if salt != 0: layered[mix([salt,4])%layered.size()] = 3.0
	return {"salt":salt,"rock_style":style,"rock":rock,"layered":layered}

## A record's own stable key: its id, or its position when it has none.
static func record_key(world_salt: int, item: Dictionary, tag: int) -> Array:
	if item.has("id"): return [world_salt,tag,int(item.id)]
	return [world_salt,tag]+cell(Vector2(float(item.x),float(item.z)))

## Which layered broadleaf form (LayeredTree.VARIANT_SEEDS) a record grows.
static func layered_index(item: Dictionary, world: Dictionary) -> int:
	var weights: Array = world.get("layered",[1.0,1.0,1.0])
	return weighted(weights,unit(record_key(int(world.get("salt",0)),item,21)))

## Per-tree proportions under the record's own scale: a little taller or
## broader, shared by trunk and crown so they stay joined.
static func layered_shape(item: Dictionary, world: Dictionary) -> Transform3D:
	var key := record_key(int(world.get("salt",0)),item,22)
	var width := lerpf(0.92,1.08,unit(key+[1]))
	return Transform3D(Basis.from_scale(Vector3(width,lerpf(0.9,1.12,unit(key+[2])),width)),Vector3.ZERO)
