extends RefCounted
## Items (docs/design/roguelike/items-contract.md): the things a run finds,
## buys or steals and keeps until it ends. A run carries them in
## RunState.items (ids below); whoever an item changes asks
## `RunState.holds(id)` and reads it live, so an item taken mid-layer
## works at once and a new run starts with none.
##
## Each entry: `name` (the caption and the strip), `line` (the caption's
## second line: what it does, in a few words), `kind` ("verb": a new move or
## route; "passive": a standing help; "cursed": a gift with a cost), `price`
## (runes at a merchant), `rarity` (1 common .. 3 rare: how often altars and
## stalls lay it), `once` (true: taken, not kept in the strip; e.g. a heart).
##
## Add an item here first, then make it do its thing where it acts. Keep ids
## stable: saves and the card name them.

const ITEMS := {
	# [altars] The vault's key: carried like an item (strip, lost with the run), never drawn.
	&"vault_key": {"name":"Vault Key","line":"opens a vault on a deeper layer","kind":"key","price":0,"rarity":3,"once":false},
	&"wallrun": {"name":"Gecko Wraps","line":"run along walls","kind":"verb","price":9,"rarity":2,"once":false},
	# [items_passive] standing helps (scripts/roguelike/passive_items.gd)
	&"heart_vessel": {"name":"Heart Vessel","line":"one more heart, mended","kind":"passive","price":14,"rarity":1,"once":true},
	&"lantern": {"name":"Hand Lantern","line":"a warm light; the dark stands back","kind":"passive","price":10,"rarity":2,"once":false},
	&"waystone": {"name":"Way-stone","line":"it leans toward the gate","kind":"passive","price":8,"rarity":2,"once":false},
	&"quiet_soles": {"name":"Quiet Soles","line":"steps and landings hush","kind":"passive","price":9,"rarity":2,"once":false},
	&"rune_magnet": {"name":"Lodestone","line":"runes drift to you","kind":"passive","price":8,"rarity":2,"once":false},
	&"tithe_bell": {"name":"Tithe Bell","line":"runes count double; it rings as you go","kind":"cursed","price":6,"rarity":2,"once":false},
	# [items_move] movement verbs (scripts/roguelike/items_move.gd).
	&"grapnel": {"name":"Grapnel","line":"V / RT: hook a lip, hold to haul up","kind":"verb","price":12,"rarity":3,"once":false},
	&"cloak": {"name":"Drift Cloak","line":"hold Jump falling: drift down","kind":"verb","price":8,"rarity":2,"once":false},
	&"picks": {"name":"Rock Picks","line":"stick into a wall: climb a few pulls","kind":"verb","price":10,"rarity":2,"once":false},
}

static func has(id: StringName) -> bool:
	return ITEMS.has(id)

## The entry for `id` ({} when unknown).
static func info(id: StringName) -> Dictionary:
	return ITEMS.get(id,{})

static func title(id: StringName) -> String:
	return String(info(id).get("name",String(id)))

## Every id, or those of `kind`.
static func ids(kind := "") -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ITEMS.keys():
		if kind == "" or String(ITEMS[id].get("kind","")) == kind: out.append(id)
	return out

## An id drawn by rarity (rarer less often) from `pool` (all when empty),
## skipping those `run` already carries (kept ones only). "" when none.
static func draw(rng: RandomNumberGenerator, pool: Array[StringName] = [], run: Object = null) -> StringName:
	var from := pool if not pool.is_empty() else ids()
	var weights := 0.0
	var left: Array[StringName] = []
	for id in from:
		if not has(id): continue
		if String(info(id).get("kind","")) == "key": continue  # [altars]
		if run != null and run.carrying(id) and not bool(info(id).get("once",false)): continue
		left.append(id)
		weights += 1.0/float(info(id).get("rarity",1))
	if left.is_empty(): return &""
	var roll := rng.randf()*weights
	for id in left:
		roll -= 1.0/float(info(id).get("rarity",1))
		if roll <= 0.0: return id
	return left[-1]
