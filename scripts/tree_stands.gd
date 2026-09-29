extends RefCounted
## Tree species, crown colours and autumn by stand, shared by emerged trees
## (scripts/emergence.gd) and generated worlds (scripts/inland_landscape.gd).
## Every choice is a hash of the world's `salt` and the point or the caller's
## key, so no random stream is touched. `field` is a biome blend
## (scripts/biome_blend.gd): its moisture, altitude and water distance lean
## each stand. Preloaded, not a class_name.
const Variety = preload("res://scripts/seeded_variety.gd")

## Tree species by stand. The land is split into stands about STAND_SIZE
## metres across (jittered cells, nearest seed wins, so the edges wander).
## Each stand draws a dominant and a companion species from its habitat's
## pool, leaned by the stand's moisture and altitude and by the world's own
## taste; the rest of its trees are a rare accent from the whole pool. Every
## place reads as one wood, neighbouring stands differ, and the odd stranger
## still turns up. `tree` is the spruce family.
const STAND_SIZE := 8.0
## Dominant share per stand, from a mixed stand to a near-pure one; the
## companion takes the rest but RARE_SHARE.
const STAND_PURITY := Vector2(0.55,0.9)
const RARE_SHARE := 0.08
const TREE_POOLS := {
	"meadow":{"broadleaf":1.0,"birch":0.7,"layered_tree":0.6,"tree":0.35,"willow":0.15},
	"wetland":{"broadleaf":1.0,"willow":0.9,"layered_tree":0.8,"birch":0.3,"tree":0.15},
	"woodland":{"broadleaf":1.0,"tree":0.9,"birch":0.5,"layered_tree":0.5,"juniper":0.15,"willow":0.15},
	"redwood":{"redwood":1.0,"tree":0.45,"broadleaf":0.15},
	"alpine":{"tree":1.0,"juniper":0.6,"birch":0.15,"broadleaf":0.1,"layered_tree":0.05},
	"arid":{"joshua":1.0,"cactus":0.8,"juniper":0.5,"broadleaf":0.0,"willow":0.0},
}
## Willows follow the water itself rather than their stand: where the pool
## holds one, a tree this close to water (metres, full to none) turns willow
## at up to this chance, so banks are hung with them inside any stand.
const WILLOW_BANK := Vector2(0.6,2.2)
const WILLOW_BANK_CHANCE := 0.4
## Crown colours by species (sRGB), as [colour, weight, lean]. The broadleaf,
## spruce and redwood crowns are baked grey and take the colour whole, as the
## landscape presets plant them (native_landscape_presets.gd); without one an
## emerged tree took the reference scene's first instance colour, a blossom
## pale. The layered tree's crown carries its own greens, so its entries are
## gentle multipliers. Each stand picks one colour per species, leaned by its
## ground ("wet", "high", "low") and the world's taste; TREE_STRAY of its trees
## take another. The mood's Leaves colour then moves every crown together
## (palette_role 2), so the species stay in one key.
const TREE_COLOURS := {
	"broadleaf":[["6f9c46",1.0,""],["7d9143",0.7,""],["4f8040",0.7,"wet"],["8fa843",0.35,"low"],["86a07a",0.3,"wet"],["8a5a3c",0.05,""]],
	"tree":[["3e7a44",1.0,""],["2f6440",0.7,""],["44756a",0.4,"high"],["56733f",0.3,"low"]],
	"redwood":[["b1c2a5",1.0,""],["bcc29a",0.5,""],["a3bca9",0.5,"wet"]],
	"layered_tree":[["ffffff",1.0,""],["f0ffd6",0.5,"low"],["ffecc8",0.4,""],["dcf0ea",0.4,"wet"]],
	"birch":[["8fae4f",1.0,""],["a3b85a",0.6,"low"],["7a9f4a",0.6,"wet"],["b0b865",0.3,"high"]],
	"willow":[["86a050",1.0,""],["7b9a58",0.7,"wet"],["93a95e",0.5,""],["6f8f5f",0.3,"wet"]],
	"juniper":[["527d5e",1.0,""],["5a7d6c",0.7,"high"],["66804f",0.5,"low"],["6d8a7a",0.3,"high"]],
}
const TREE_STRAY := 0.12
const TREE_BRIGHTNESS := Vector2(0.82,1.08)

## The stand a point belongs to: the nearest of the jittered stand seeds in
## the cells around it, with the seed's key and its moisture and altitude, so
## a whole stand leans the same way.
static func stand(p: Vector2, salt: int, field: RefCounted) -> Dictionary:
	var base := Vector2i((p/STAND_SIZE).floor())
	var best := {}
	var nearest := INF
	for dz in range(-1,2):
		for dx in range(-1,2):
			var c := base+Vector2i(dx,dz)
			var seed := (Vector2(c)+Vector2(Variety.unit([salt,c.x,c.y,31]),Variety.unit([salt,c.x,c.y,32])))*STAND_SIZE
			var d := p.distance_squared_to(seed)
			if d < nearest:
				nearest = d
				best = {"key":[salt,c.x,c.y,30],"seed":seed}
	var at: Vector2 = best.seed.clamp(Vector2(-13.99,-13.99),Vector2(13.99,13.99))
	best.moisture = field.moisture(at)
	best.altitude = field.altitude(at)
	return best

## The species for a tree at `p`: the bank's willow, or the stand's dominant,
## companion or rare accent by `pick`, 0..1. `pools` replaces TREE_POOLS.
static func tree_kind(habitat: String, p: Vector2, pick: float, bank_pick: float, salt: int, field: RefCounted, pools: Dictionary = TREE_POOLS) -> String:
	var pool: Dictionary = pools.get(habitat,{"tree":1.0})
	if pool.has("willow") and bank_pick < WILLOW_BANK_CHANCE*(1.0-smoothstep(WILLOW_BANK.x,WILLOW_BANK.y,field.water_distance(p)))*Variety.lean(salt,"tree:willow"):
		return "willow"
	var at := stand(p,salt,field)
	var kinds: Array = pool.keys()
	var weights := []
	for kind: String in kinds:
		weights.append(species_weight(habitat,kind,float(pool[kind]),at.moisture,at.altitude)*Variety.lean(salt,"tree:"+kind))
	var dominant := Variety.weighted(weights,Variety.unit(at.key+[1]))
	var purity := lerpf(STAND_PURITY.x,STAND_PURITY.y,Variety.unit(at.key+[3]))
	if pick < purity:
		return kinds[dominant]
	var others := weights.duplicate()
	others[dominant] = 0.0
	var total := 0.0
	for w: float in others: total += w
	if total <= 0.0:
		return kinds[dominant]
	var companion := Variety.weighted(others,Variety.unit(at.key+[2]))
	if pick < 1.0-RARE_SHARE or kinds.size() < 3:
		return kinds[companion]
	# The rare accent: anything else in the pool, by its weight, so a rare
	# species stays rare even when it is the accent.
	var rare := weights.duplicate()
	rare[dominant] = 0.0
	rare[companion] = 0.0
	total = 0.0
	for w: float in rare: total += w
	if total <= 0.0:
		return kinds[companion]
	return kinds[Variety.weighted(rare,(pick-(1.0-RARE_SHARE))/RARE_SHARE)]

## A tree's crown tint, or "" to keep the catalog colour. `key` is the tree's
## own hash key, for its stray colour and brightness.
static func tree_tint(kind: String, p: Vector2, key: Array, salt: int, field: RefCounted) -> String:
	if not TREE_COLOURS.has(kind):
		return ""
	var at := stand(p,salt,field)
	var options: Array = TREE_COLOURS[kind]
	var weights := []
	for n in range(options.size()):
		var lean := 1.0
		match options[n][2]:
			"wet": lean = lerpf(0.4,1.8,at.moisture)
			"high": lean = lerpf(0.5,1.7,at.altitude)
			"low": lean = lerpf(1.4,0.6,at.altitude)
		weights.append(float(options[n][1])*lean*Variety.lean(salt,"tint:%s:%d" % [kind,n]))
	var pick := Variety.weighted(weights,Variety.unit(at.key+[6,kind.hash()]))
	if Variety.unit(key+[23]) < TREE_STRAY:
		pick = Variety.weighted(weights,Variety.unit(key+[24]))
	var color := Color(options[pick][0]).srgb_to_linear()*lerpf(TREE_BRIGHTNESS.x,TREE_BRIGHTNESS.y,Variety.unit(key+[22]))
	# Tints above 1 are refused (NativeObjectPose.valid_tint), and the tree with them.
	return NativeObjectPose.encode_tint(Color(minf(color.r,1.0),minf(color.g,1.0),minf(color.b,1.0)))

## A stand's autumn character, the tree record's `autumn`, 0..1: low stands
## hang on green late and stop at gold, the middle turns on time and stops at
## amber, high stands turn first and go all the way to copper-red
## (zs_autumn_stand_paint, shaders/reference_autumn.gdshaderinc). Drawn per
## stand so a grove turns as one, and leaned by the world's taste so one world
## runs coppery and another golden. Evergreens carry it and ignore it.
static func autumn(p: Vector2, salt: int, field: RefCounted) -> float:
	return snappedf(pow(Variety.unit(stand(p,salt,field).key+[40]),1.0/sqrt(Variety.lean(salt,"autumn"))),0.01)

## How well `kind` suits the ground at `p`, 0..1: its weight there over the
## best kind's (`species_weight`, leaned by the world's taste), 0 where the
## habitat does not grow it. A flicked tree's seeds keep its kind by this
## (Emergence `_heir_kind`).
static func fit(habitat: String, kind: String, p: Vector2, salt: int, field: RefCounted) -> float:
	var pool: Dictionary = TREE_POOLS.get(habitat,{"tree":1.0})
	if not pool.has(kind): return 0.0
	var at := stand(p,salt,field)
	var best := 0.0
	var own := 0.0
	for other: String in pool:
		var w := species_weight(habitat,other,float(pool[other]),at.moisture,at.altitude)*Variety.lean(salt,"tree:"+other)
		best = maxf(best,w)
		if other == kind: own = w
	return own/best if best > 0.0 else 0.0

## A sport: some other kind the ground at `p` grows, by its weight there
## (`pick` 0..1), or "" if there is none.
static func sport(habitat: String, kind: String, p: Vector2, pick: float, salt: int, field: RefCounted) -> String:
	var pool: Dictionary = TREE_POOLS.get(habitat,{"tree":1.0})
	var at := stand(p,salt,field)
	var kinds := []
	var weights := []
	for other: String in pool:
		if other == kind: continue
		var w := species_weight(habitat,other,float(pool[other]),at.moisture,at.altitude)*Variety.lean(salt,"tree:"+other)
		if w <= 0.0: continue
		kinds.append(other)
		weights.append(w)
	return "" if kinds.is_empty() else kinds[Variety.weighted(weights,pick)]

## A species' weight in a stand: its pool weight leaned by the stand's
## ground. Broadleaves and layered trees want water, spruce wants height and
## drier ground, cactus wants neither. In arid land a broadleaf or a willow
## stands only by water, where it makes an oasis. Birch takes any ground and
## climbs a little; willow wants water above all; juniper wants it dry, high
## and exposed.
static func species_weight(habitat: String, kind: String, base: float, moisture: float, altitude: float) -> float:
	match kind:
		"broadleaf":
			if habitat == "arid": return 1.2*smoothstep(0.45,0.8,moisture)
			return base*lerpf(0.6,1.5,moisture)*lerpf(1.2,0.6,altitude)
		"layered_tree": return base*lerpf(0.7,1.4,moisture)
		"tree": return base*lerpf(1.3,0.7,moisture)*lerpf(0.8,1.6,altitude)
		"redwood": return base*lerpf(0.6,1.4,moisture)
		"cactus": return base*lerpf(1.4,0.4,moisture)
		"birch": return base*lerpf(0.9,1.3,altitude)
		"willow":
			if habitat == "arid": return 0.8*smoothstep(0.5,0.85,moisture)
			return base*lerpf(0.02,2.5,smoothstep(0.3,0.75,moisture))
		"juniper": return base*lerpf(1.5,0.25,moisture)*lerpf(0.7,1.6,altitude)
	return base
