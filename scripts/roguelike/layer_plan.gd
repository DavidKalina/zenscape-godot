extends RefCounted
## One generated layer of the climb (docs/design/roguelike/layer-round2.md,
## layer-round3.md), as plain data from a seed: which isles stand where,
## the edges joining them rim to rim, what is on them. The isles stand in
## 2 or 3 neighbourhoods (`hoods`), each a few isles close together joined
## by stones, bridges and the trap as round 2 laid them; between two
## neighbourhoods a gulf of open sky (GULF, 110-220 m rim to rim, the
## `gulf` knob) crossed by a set piece: a rune serpent on its own loop past
## a boarding ledge at each rim, or the sky folk's ferry shuttling between
## them, and where it is narrow enough a cannon too. The aqueduct isle is
## the base (where the pilot starts) in the first; motif isles are drawn
## from POOL by weight (the families rolled through their own seed and
## knobs), stood one off another along a guaranteed route to the exit, a
## gate on the last neighbourhood's highest isle; one more hangs off a
## route isle as the greed branch, a rune set on its perch.
## studies/run_layer.gd builds it.
##
## An isle is placed only by moving it (no turn): an edge leaves a rim of a
## placed isle (KitMotif `socket` "rim": its facing out over the drop) and
## comes in at a rim of the next facing back, the next isle stood where
## that rim lands. Every isle's occupancy (scripts/roguelike/
## layer_pieces.gd: per 2 m cell its lowest and highest solid; a rolled
## broken ring its footprint's box) is kept CLEAR of every other's, and
## every edge's corridor (the pilot's body along it, the stones under him)
## of every isle and edge; an isle may stand over another (a missed jump
## lands lower), never in it.
##
## The edges (`edge`), each sized from the pilot's own numbers (KitMotif
## `pilot`, as the traps' `pilot()`; AGENTS.md, Sizes), so the route is
## solvable by construction: stones (each stride a share of his running
## small jump's reach at that stride's rise, `reach`), a rope bridge
## (scripts/footbridge.gd: a span of his hops, a gentle grade), the Loose
## Voussoirs trap (scripts/traps/trap_voussoirs.gd: its slabs from lip to
## lip, level), and on the greed branch harder stones (nearer his reach,
## smaller) and, where a shot lands it, the cannon (scripts/cannon/
## cannon.gd, `landing_for`) with kegs to range it.
##
## The same seed gives the same plan: `make(seed)`.
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const LayerPieces = preload("res://scripts/roguelike/layer_pieces.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const SerpentRoute = preload("res://scripts/kit_isle/serpent_route.gd")
const AirshipBuild = preload("res://scripts/airship_build.gd")
const Ferry = preload("res://scripts/kit_isle/airship_ferry.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
## The greybox motifs, opt-in on the `greybox` knob (scripts/kit_isle/
## greybox/registry.gd; docs/design/roguelike/greybox-in-generator.md).
const Greybox = preload("res://scripts/kit_isle/greybox/registry.gd")
## The run's worlds, under and sky (scripts/roguelike/layer_worlds.gd): a
## region draws only its own world's motifs.
const LayerWorlds = preload("res://scripts/roguelike/layer_worlds.gd")
## The city's crossings as a family (layer-round15-city-crossings.md).
const CityWays = preload("res://scripts/roguelike/city_ways.gd")

## The pool: [id, script, weight]. The colonnade spine and the Sundered
## gorge weighted up (the user's strongest), the stair to the clouds a
## climb, the broken ring and the bell spires fillers.
const POOL := [
	["colonnade_spine",preload("res://scripts/kit_isle/motif_colonnade_spine.gd"),3.0],
	["sundered_gorge",preload("res://scripts/kit_isle/motif_sundered_gorge.gd"),3.0],
	["stair_clouds",preload("res://scripts/kit_isle/motif_stair_clouds.gd"),1.5],
	["broken_ring",preload("res://scripts/kit_isle/motif_broken_ring.gd"),1.0],
	["bell_spires",preload("res://scripts/kit_isle/motif_bell_spires.gd"),1.0],
]
## The kit motifs the "motifs" pool keeps beside the greybox motifs (the
## `pool` knob, `draw_pool`).
const KEPT := ["sundered_gorge"]

## The pool a layer draws from, by its `pool` knob (mix and match, to see
## what works; docs/design/roguelike/greybox-pool.md):
## - "motifs" (the default, a prototype): the kit motifs in KEPT and every
##   greybox motif (or those the `greybox` knob names);
## - "classic": POOL, and the greybox motifs the `greybox` knob asks for
##   (none by default), the pool as it was;
## - "all": POOL and every greybox motif;
## - a list (comma or "+" separated): any of POOL's ids
##   and the greybox slugs (`gb_` optional), e.g.
##   `--knob=pool=sundered_gorge+sunken_giant+plumb_well`.
## The named pools keep to the layer's world (LayerWorlds `world_of`: the
## registry's WORLD tags, untagged sky): a sky region draws them less its
## underground motifs, an underground region every underground motif
## (whichever pool is named: the named pools are the sky's). A list is
## taken as asked, in either world.
static func draw_pool(knobs := {}) -> Array:
	var asked := str(knobs.get("pool","motifs")).strip_edges()
	if not asked in ["classic","motifs","","all"]: return _listed_pool(asked)
	var world := LayerWorlds.world_of(knobs)
	# The motifs the `greybox` knob names come in either world (to force one
	# into a layer for a look: `--knob=greybox=face`).
	var wanted := Greybox.entries(knobs)
	var out: Array
	if world == "under":
		out = Greybox.entries({"greybox":"all"}).filter(func(p: Array) -> bool: return Greybox.world_of(str(p[0])) == "under")
	else:
		# The named pool as it is without the knob (the knob's motifs added
		# below): "motifs" with the knob once meant only those, a pool too
		# narrow for a layer once the city's motifs went underground.
		var bare := knobs.duplicate()
		bare.erase("greybox")
		out = _named_pool(asked,bare).filter(func(p: Array) -> bool: return Greybox.world_of(str(p[0])) == world)
	for w: Array in wanted:
		if not out.any(func(p: Array) -> bool: return str(p[0]) == str(w[0])): out.append(w)
	return out

static func _named_pool(asked: String, knobs: Dictionary) -> Array:
	match asked:
		"classic":
			var extra := Greybox.entries(knobs)
			return POOL if extra.is_empty() else POOL+extra
		"motifs", "":
			var kept := POOL.filter(func(p: Array) -> bool: return KEPT.has(str(p[0])))
			var wanted := Greybox.entries(knobs)
			return kept+(wanted if not wanted.is_empty() else Greybox.entries({"greybox":"all"}))
		"all":
			return POOL+Greybox.entries({"greybox":"all"})
	return []

static func _listed_pool(asked: String) -> Array:
	var out: Array = []
	var greys := PackedStringArray()
	for word: String in asked.replace(",","+").split("+",false):
		var id := word.strip_edges()
		var kit := POOL.filter(func(p: Array) -> bool: return str(p[0]) == id)
		if not kit.is_empty(): out.append(kit[0])
		else: greys.append(id)
	if not greys.is_empty(): out += Greybox.entries({"greybox":",".join(greys)})
	return out

## How many times a pool pick may come a layer (one not a family; a
## greybox motif once, or `repeats` in the "motifs" pool, which has no
## family to fill a layer).
static func _most(id: String, repeats: int, knobs := {}) -> int:
	# Underground the pool is thin (one motif today): it fills the layer.
	if LayerWorlds.world_of(knobs) == "under": return maxi(repeats,LayerWorlds.UNDER_REPEATS)
	if Greybox.has(id) and str(knobs.get("pool","motifs")) == "classic": return Greybox.MOST
	return repeats
const BASE := "aqueduct_isle"
## The aqueduct isle's middle (world), what the layer keeps round.
const MIDDLE := Vector3(85.0,30.0,-20.0)
## Whole draws tried for a seed before the last is kept with its problems;
## motifs drawn in place of one that won't stand before a draw gives up.
const ATTEMPTS := 60
const SUBS := 2
## Edges tried for each step.
const TRIES := 240
## Clear between two isles where one stands over the other (m), and round
## an edge's corridor.
const CLEAR := 4.0
## An edge's corridor: under its path this deep (the stones and their
## clods), over it this high (the pilot), this wide either side (m).
const UNDER := 2.6
const OVER := 2.6
const SIDE := 1.0
## Near its own rims an isle doesn't count against the edge (m, flat).
const OWN_NEAR := 6.0
## The most an edge's way turns off a rim's facing (degrees).
const TURN_MOST := 30.0
## The layer keeps within this of MIDDLE (m, flat); a neighbourhood's
## isles within HOOD_BAND of its first.
const BAND := 520.0
const HOOD_BAND := 220.0
## The city's (underground): its places are hillsides 150-250 m across, so
## a neighbourhood of two spreads further (layer-round14-city-layers.md).
const CITY_BAND := Vector2(1100.0,420.0)

## How mean a layer's crossings are (0-1): underground the danger by height
## (LayerWorlds `danger`) up to MEAN_MOST; the sky's as they were (0).
const MEAN_MOST := 0.7
static func mean(knobs: Dictionary) -> float:
	if LayerWorlds.world_of(knobs) != "under": return 0.0
	return LayerWorlds.danger(knobs)*MEAN_MOST

## [BAND, HOOD_BAND] for a layer's knobs.
static func band(knobs: Dictionary) -> Vector2:
	return CITY_BAND if LayerWorlds.city(knobs) else Vector2(BAND,HOOD_BAND)
## The void: this far under the lowest solid of any isle.
const VOID_UNDER := 25.0
## How much a placing that stands over another isle (a soft fall) is
## preferred: points per share of it over.
const OVER_WEIGHT := 12.0
## The pilot starts this far back along the first rim's run-up (at most).
const SPAWN_BACK := 6.0
## The cannon stands this far behind its rim; its shot lands this far in
## from the greed isle's rim; how close is a landing (m).
const CANNON_BACK := 2.5
const SHOT_IN := 2.5
const SHOT_NEAR := 0.75
## The ram wants an arena this roomy, this far from any rim used (m).
const RAM_ROOM := 4.5
const RAM_CLEAR := 8.0
## The runes round the perch.
const RUNES := 5

## Neighbourhoods: how many (rolled), and how often one past the base's
## holds three isles, not two; isles of two neighbourhoods keep this far
## apart (m, flat, rect to rect).
const HOODS := Vector2i(2,3)
const HOOD_THREE := 0.3
## The city's neighbourhoods (underground): CITY_HOODS of them (the rolled
## count clamped into it), each CITY_HOOD places. Trimmed to about five
## minutes a layer (run-trim-round1.md): two neighbourhoods of one place,
## a serpent gulf between. `--knob=city_size=full` lays round 14's (at least
## two neighbourhoods of two, about ten minutes); `--knob=city_hood=N` pins
## the places a neighbourhood, `--knob=hoods=N` the neighbourhoods.
const CITY_HOODS := Vector2i(2,2)
const CITY_HOOD := 1
const CITY_HOODS_FULL := Vector2i(2,3)
const CITY_HOOD_FULL := 2
const HOOD_APART := 60.0
## A gulf: its width rim lip to rim lip (m, flat) rolled in GULF (a pinned
## width clamped to GULF_LIMITS), rising GULF_RISE across; its rims want
## this run-up; the corridor under its line (the sight line's, m); the eye
## over each rim the sight line runs between.
const GULF := Vector2(110.0,220.0)
const GULF_LIMITS := Vector2(60.0,400.0)
const GULF_RISE := Vector2(2.0,9.0)
const GULF_RUN_UP := 4.5
const GULF_UNDER := 4.0
## How far a gulf's line may turn off either rim's facing (degrees): the
## rides come and go round the piers, so more than an edge's.
const GULF_TURN := 50.0
const EYE := 1.6
## The honest rides across; the best placings tried for a ride's loop.
const RIDES := ["serpent","ferry"]
const GULF_RIDES_TRIED := 24
## A gulf this wide or narrower gets a cannon too, its speed up to
## GULF_CANNON_RUNS of the pilot's run.
const GULF_CANNON_MOST := 170.0
const GULF_CANNON_RUNS := 16.0
## How far it stands aside of the near pier's line (m, either way); by a
## ferry's pier further, clear of its envelope resting there (the ship lies
## along the rim's edge, its envelope some 15 m either way and 6 m up).
const GULF_CANNON_ASIDE := [5.0,-5.0,6.5,-6.5]
const FERRY_CANNON_ASIDE := [19.0,-19.0,22.0,-22.0]
## How far in past the far rim its shot is aimed (m): past the pier.
const GULF_SHOT_IN := [10.0,12.0,14.0,8.0]
## The serpent's loop: a ledge's end past its rim's lip and its top over
## the rim (m), the slither's share by a ledge (serpent_route.gd's held
## 0.1); the straight run past a ledge (control points apart, m), the
## corners' reach, the lanes' offset to the side, where they start in from
## each end (m), their points' spacing and their rise mid-gulf.
const LEDGE_JUT := 7.0
const LEDGE_RISE := 1.12
## A ride's boarding place is a pier (serpent_route.gd's ledge, longer):
## its end LEDGE_JUT m past the lip, its back PIER_OVER m in over the turf;
## the ferry's top FERRY_RISE m over the rim (its deck level with it).
const PIER_OVER := 1.5
const FERRY_RISE := 0.56
const LEDGE_WEAVE := 0.1
const SERPENT_RUN := 8.0
const SERPENT_OUT := 2.0
const SERPENT_LANE := 52.0
const SERPENT_LANE_IN := 40.0
const SERPENT_LANE_STEP := 40.0
const LANE_LIFT := 6.0
## A ride's tube sampled this often (m) and kept this much past its reach;
## round a ride's stop or ledge its own isle is left to the rim's probe
## within these (m, flat).
const TUBE_STEP := 3.0
const TUBE_MARGIN := 0.5
const EXEMPT_LEDGE := 10.0
const EXEMPT_STOP := 10.0
## The ferry's loop: its side off the lip (m), how much higher it flies
## between, its neighbours along an edge, its corners, its lanes' offset;
## its hull's and its envelope's reach [radius, over the deck] (m).
const FERRY_OFF := 0.15
const FERRY_LIFT := 8.0
const FERRY_ALONG := 9.0
const FERRY_CORNER := 22.0
const FERRY_LANE := 44.0
const FERRY_HULL := Vector2(3.6,-0.3)
const FERRY_ENVELOPE := Vector2(6.6,11.5)

# --- The pilot's reach ----------------------------------------------------------------

static var _pilot: PilotMotor
static func pilot() -> PilotMotor:
	if _pilot == null: _pilot = KitMotif.pilot()
	return _pilot

## How far (m, flat) his running small jump carries him before it comes
## down to `rise` over where it left (rising at his gravity, falling
## `fall` times as hard): the furthest a gap rising `rise` may be.
static func reach(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[0])
	if rise >= j: return 0.0
	return p.run*(sqrt(2.0*j/p.gravity)+sqrt(2.0*(j-rise)/(p.gravity*p.fall)))

## The same for the pump (his second jump in a chain, JUMPS[1]): what he
## jumps if he leaps again within the chain's window of landing, as a
## runner across stones does.
static func pump_reach(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[1])
	if rise >= j: return 0.0
	return p.run*(sqrt(2.0*j/p.gravity)+sqrt(2.0*(j-rise)/(p.gravity*p.fall)))

## How far (m, flat) before the same jump has risen `rise` (a gap rising
## `rise` shorter than this he meets the far side's face, not its top).
static func clears(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[0])
	if rise <= 0.0: return 0.0
	var v := sqrt(2.0*p.gravity*j)
	return p.run*(v-sqrt(maxf(v*v-2.0*p.gravity*rise,0.0)))/p.gravity

## A stepping stone's length along the way and its width: a share of his
## walk's second (the ring's stones, 1.5-1.7 m at his size); the greed
## branch's smaller.
static func stone_length(hard := false) -> float:
	return pilot().walk*(0.45 if hard else 0.7)

## A route stride's gap as a share of his small jump's reach at its rise;
## the greed branch's; how far past the pump's reach a stone's far end
## stands (a share of it).
const GAP_SHARE := Vector2(0.72,0.84)
const GAP_HARD := Vector2(0.86,0.93)
const PUMP_ROOM := 1.08

## A rope bridge's span (m): from SPAN_HOPS of his running hops; its grade
## at most a share of the footbridge's.
const SPAN_HOPS := Vector2(2.6,5.4)
const GRADE := 0.5

# --- Making it ------------------------------------------------------------------------

## The plan for `seed_value`: {seed, knobs, isles, edges, hoods, gulfs, route,
## exit, spawn, prize, cannon, ram, void_y, tubes, problems}. Isles: {key,
## id, script, seed, knobs, role ("base", "route", "greed"), hood, offset,
## sockets (world), occ}. Edges: {kind ("stones", "bridge", "trap", "hard",
## "gulf"), branch, from, to ([isle index, rim name]), a, b (the lips), dir,
## stones, trap, path}; a gulf's also {width, rise, ride ("serpent",
## "ferry"), serpent or ferry (its loop), sight, cannon}. `hoods`: each
## neighbourhood's isle indices; `gulfs`: the gulf edges' indices.
## `knobs` (`--knob=` on the run, KNOBS): any pinned, the rest rolled.
static func make(seed_value: int, knobs := {}) -> Dictionary:
	var plan := {}
	for attempt in range(ATTEMPTS):
		plan = _make(seed_value,attempt,knobs)
		if (plan.problems as Array).is_empty(): break
	return plan

## The layer's knobs: how many neighbourhoods (0 rolls 2 or 3), the gulf's
## width rim to rim (m, flat; 0 rolls each in GULF), the honest ride across
## each ("" alternates from a roll; "serpent" or "ferry" pins every gulf's),
## each gulf's rise rim to rim (m; 0 rolls GULF_RISE, or the knob
## `rise_roll`, a Vector2, the sprawl shape's). The sprawl shape (scripts/
## roguelike/layer_sprawl.gd) also passes `hood_more` (isles more in each
## neighbourhood) and `tier` (m: in each neighbourhood one step climbs
## onto an isle standing that much over its lowest, by a `climb` edge).
## `arrows` / `viaduct`: the sprawl's hazards (scripts/roguelike/
## layer_hazards.gd), -1 rolled; `heads` the inhaler heads (scripts/
## roguelike/layer_enemies.gd), -1 rolled; `bodies` (1 or 0) their headless
## bodies coming up the isles' cliffs (scripts/roguelike/layer_bodies.gd);
## `spawn_<rule>` (not in KNOBS: any of BodySpawner RULES, e.g.
## `spawn_far_share=1` every spawn a far one) their spawns' rules over the
## generator's (LayerBodies SPAWN).
## `alternate` (0 or 1) and `ring` (isles round it, 0 rolls) are the run's
## and the ring shape's (scripts/roguelike/layer_shapes.gd, layer_ring.gd).
## `greybox` ("" none, "all", or slugs comma separated) the greybox motifs
## in the pool, `greybox_force` (1) at least one a layer (scripts/kit_isle/
## greybox/registry.gd). `pool` ("motifs" or "classic") which pool the
## layer draws from (`draw_pool`). `one_way` how the route keeps to
## greybox motifs' ways in and out: -1 (the default) prefers them edge by
## edge (`way_score`), 1 only ever takes them (`can_out`, `ins_of`), 0
## ignores them.
## `region` (the run's region, 1 the first; 0 none), `under_regions` (how
## many from the first are underground) and `world` ("under", "sky", ""
## by region) say the layer's world (scripts/roguelike/layer_worlds.gd);
## `--world=` and `--under-regions=` are the same as their knobs.
const KNOBS := {"hoods":0,"gulf":0.0,"ride":"","rise":0.0,"arrows":-1,"viaduct":-1,"heads":-1,"bodies":1,"alternate":1,"ring":0,"greybox":"","greybox_force":1,"pool":"motifs","one_way":-1,
	"region":0,"under_regions":LayerWorlds.UNDER_REGIONS,"world":"","sky_kit":0,"danger":-1.0,"city_ring":0,"city_crossings":"varied",
	"city_size":"trim","city_hood":0}
const KNOB_CHOICES := {"hoods":[0,1,2,3],"ride":["","serpent","ferry"],"pool":["motifs","classic"],"city_size":["trim","full"]}

## `--knob=key=value` arguments as the layer's knobs (unknown keys warned).
static func knobs_from(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg: String in args:
		# The worlds' own flags (scripts/roguelike/layer_worlds.gd).
		if arg.begins_with("--world="):
			var w := arg.get_slice("=",1)
			if LayerWorlds.WORLDS.has(w): out.world = w
			else: push_warning("layer: no world '%s' (%s)" % [w,", ".join(PackedStringArray(LayerWorlds.WORLDS))])
			continue
		if arg.begins_with("--under-regions="):
			out.under_regions = int(arg.get_slice("=",1))
			continue
		if not arg.begins_with("--knob="): continue
		var pair := arg.trim_prefix("--knob=")
		var key := pair.get_slice("=",0)
		var value := pair.get_slice("=",1)
		# The bodies' spawn rules (BodySpawner RULES), `spawn_<rule>`.
		if key.begins_with("spawn_") and BodySpawner.RULES.has(key.trim_prefix("spawn_")):
			out[key] = float(value)
			continue
		if not KNOBS.has(key):
			push_warning("layer: no knob '%s' (%s, spawn_<%s>)" % [key,", ".join(PackedStringArray(KNOBS.keys())),"|".join(PackedStringArray(BodySpawner.RULES.keys()))])
			continue
		match typeof(KNOBS[key]):
			TYPE_INT: out[key] = int(value)
			TYPE_FLOAT: out[key] = float(value)
			_: out[key] = value
	return out

## Every cache a plan fills made now, on the main thread, so a worker can
## lay plans (studies/run_layer.gd).
static func warm() -> void:
	pilot()
	CityWays.warm()
	slab_length()
	_serpent_shape()
	cannon_knobs()
	LayerPieces.sockets(BASE)
	# One isle of each motif read here: the families' sockets build their
	# kit pieces once (KitMotif `piece_block`, about 2 s), which off the main
	# thread windowed waits on the renderer.
	var rng := RandomNumberGenerator.new()
	for p: Array in POOL: _motif_isle(p,rng)

## Prints each step's cost (the bake and the test's).
static var trace := false

## One attempt; with `one_way` -1 and a greybox motif in the pool, a plan
## that fails keeping to the motifs' ways is laid again ignoring them (the
## same attempt, the same draw): taking every fit forwards can leave a
## later motif nowhere to stand, and a layer with motifs backwards beats
## none.
static func _make(seed_value: int, attempt: int, knobs: Dictionary) -> Dictionary:
	var plan := _make_once(seed_value,attempt,knobs)
	if not ways_retry(plan): return plan
	var loose := knobs.duplicate()
	loose.one_way = 0
	return _make_once(seed_value,attempt,loose)

## Whether a failed plan is worth laying again with `one_way` 0.
static func ways_retry(plan: Dictionary) -> bool:
	if (plan.problems as Array).is_empty(): return false
	if int((plan.knobs as Dictionary).get("one_way",-1)) != -1: return false
	return draw_pool(plan.knobs).any(func(p: Array) -> bool: return Greybox.has(str(p[0])))

static func _make_once(seed_value: int, attempt: int, knobs: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,attempt,"layer"])
	var k_all := KNOBS.duplicate()
	k_all.merge(knobs,true)
	# Underground the gulfs are the rune serpent's (the ferry is the sky
	# folk's), unless the knob pins one.
	if LayerWorlds.world_of(k_all) == "under" and str(k_all.ride) == "": k_all.ride = "serpent"
	var plan := {"seed":seed_value,"world":LayerWorlds.world_of(k_all),"attempt":attempt,"knobs":k_all,"isles":[],"edges":[],"hoods":[],"gulfs":[],"route":[],"exit":{},"spawn":{},
		"prize":{},"cannon":{},"ram":{},"void_y":0.0,"tubes":[],"problems":[]}
	# The neighbourhoods: the base's holds 1-2 motif isles, each other 2
	# (now and then 3); one more isle is the greed branch's.
	var hoods := int(k_all.hoods)
	if hoods <= 0: hoods = rng.randi_range(HOODS.x,HOODS.y)
	hoods = clampi(hoods,1,3)
	var sizes: Array[int] = []
	for h in range(hoods): sizes.append(rng.randi_range(1,2) if h == 0 else (3 if rng.randf() < HOOD_THREE else 2))
	for h in range(hoods): sizes[h] += int(k_all.get("hood_more",0))
	# The city: CITY_HOODS neighbourhoods of CITY_HOOD places, a gulf
	# between each: the way up through two places, about five minutes
	# (run-trim-round1.md; round 14's full size, four to six places and ten
	# minutes, with `--knob=city_size=full`). The `hoods` knob still pins
	# how many, `city_hood` the places in each.
	if LayerWorlds.city(k_all):
		var full := str(k_all.get("city_size","trim")) == "full"
		var range_h: Vector2i = CITY_HOODS_FULL if full else CITY_HOODS
		if int(k_all.hoods) <= 0: hoods = clampi(hoods,range_h.x,range_h.y)
		var per := int(k_all.get("city_hood",0))
		if per <= 0: per = CITY_HOOD_FULL if full else CITY_HOOD
		sizes.clear()
		for h in range(hoods): sizes.append(per)
	var count := 1
	for n: int in sizes: count += n
	var motifs: Array = []
	for p: Array in _draw(count,rng,int(k_all.get("repeats",1)),k_all): motifs.append(_motif_isle(p,rng))
	# A pool with no family can run dry (the "motifs" pool, a narrow
	# `greybox` knob).
	if motifs.size() < count:
		plan.problems.append("too few motifs drawn")
		return plan
	var base := _base_isle(k_all)
	base.hood = 0
	plan.isles.append(base)
	plan.hoods.append([0])
	# The greed isle: drawn, the smaller the likelier (never the hero, a
	# landmark of the route).
	var can: Array = motifs.filter(func(m: Dictionary) -> bool: return m.motif.role() != "hero")
	# Nor one that runs one way (a greybox motif: its chain ends at a way
	# out a dead end would leave unused), while another will do.
	var two_way := can.filter(func(m: Dictionary) -> bool: return not one_way(m))
	if not two_way.is_empty(): can = two_way
	if can.is_empty(): can = motifs.duplicate()
	var total_inv := 0.0
	for m: Dictionary in can: total_inv += 1.0/_area(m)
	var draw := rng.randf()*total_inv
	var greed: Dictionary = can[can.size()-1]
	for m: Dictionary in can:
		draw -= 1.0/_area(m)
		if draw <= 0.0:
			greed = m
			break
	motifs.erase(greed)
	# Into the neighbourhoods in turn, a hero at most once in each; each
	# climbing through its isles, the one with the most climb in it last.
	if attempt > 0: _shuffle(motifs,rng)
	var groups: Array = []
	var at := 0
	for h in range(hoods):
		var group: Array = motifs.slice(at,at+sizes[h])
		at += sizes[h]
		groups.append(group)
	for h in range(hoods):
		var heroes: Array = groups[h].filter(func(m: Dictionary) -> bool: return m.motif.role() == "hero")
		while heroes.size() > 1:
			var swapped := false
			for g in range(hoods):
				if g == h: continue
				for j in range((groups[g] as Array).size()):
					if groups[g][j].motif.role() == "hero" or groups[g].any(func(m: Dictionary) -> bool: return m.motif.role() == "hero"): continue
					var other: Dictionary = groups[g][j]
					var i: int = groups[h].find(heroes[1])
					groups[g][j] = heroes[1]
					groups[h][i] = other
					heroes.remove_at(1)
					swapped = true
					break
				if swapped: break
			if not swapped: break
		if attempt == 0: (groups[h] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _climb(a) < _climb(b))
	# The route: through each neighbourhood, a gulf to the next.
	var used := {}
	var from := 0
	# Underground no Loose Voussoirs (the sky kit's trap).
	var traps_left := 0 if LayerWorlds.city(k_all) else 1
	var gulf_n := 0
	var ride_roll: String = RIDES[rng.randi_range(0,RIDES.size()-1)]
	var tier := float(k_all.get("tier",0.0))
	var tiered := {}
	for h in range(hoods):
		var group: Array = groups[h]
		for k in range(group.size()):
			var m: Dictionary = group[k]
			m.role = "route"
			m.hood = h
			var last := h == hoods-1 and k == group.size()-1
			if h > 0 and k == 0:
				var width := float(k_all.gulf)
				width = clampf(width,GULF_LIMITS.x,GULF_LIMITS.y) if width > 0.0 else rng.randf_range(GULF.x,GULF.y)
				var ride := str(k_all.ride)
				var pinned := RIDES.has(ride)
				if not pinned: ride = ride_roll if gulf_n%2 == 0 else str(RIDES[(RIDES.find(ride_roll)+1)%RIDES.size()])
				var g := _gulf(plan,h-1,m,h,width,ride,pinned,used,rng)
				# One that won't stand there: another drawn in its place.
				for sub in range(SUBS):
					if not g.is_empty(): break
					m = _substitute(plan,groups,greed,h,rng)
					if m.is_empty(): break
					groups[h][k] = m
					g = _gulf(plan,h-1,m,h,width,ride,pinned,used,rng)
				if g.is_empty():
					plan.problems.append("no gulf onto %s" % group[k].id)
					return plan
				gulf_n += 1
				from = plan.isles.size()-1
				plan.hoods.append([from])
				continue
			var kinds := ["trap"] if traps_left > 0 and (rng.randf() < 0.5 or last) else ["stones","bridge","stones"]
			# The city's family (city_ways.gd): one kind drawn first (by the
			# danger, not the one laid before), the rest if it won't stand.
			var then: Array = []
			if CityWays.on(k_all) and kinds[0] != "trap":
				var prev := ""
				for e: Dictionary in plan.edges: if e.branch == "route" and e.kind != "gulf": prev = e.kind
				var order := CityWays.order(prev,LayerWorlds.danger(k_all),rng)
				kinds = [order[0]]
				then = order.slice(1)
			# The last stands over every other in its neighbourhood (the exit
			# is on the highest).
			var least := -INF
			# (Not in the city: its places climb in themselves, in at the foot
			# and out at the top, and the gate is the exit chain's.)
			if last and not LayerWorlds.city(k_all):
				for i: int in plan.hoods[h]: least = maxf(least,_top_walked(plan.isles[i])+1.0)
			# A tier (the `tier` knob): the first step of a neighbourhood that
			# needn't be the trap climbs onto an isle standing over its lowest.
			if tier > 0.0 and not tiered.has(h) and not (last and traps_left > 0):
				tiered[h] = true
				kinds = ["climb"]
				var low := INF
				for i: int in plan.hoods[h]: low = minf(low,_top_walked(plan.isles[i]))
				least = maxf(least,low+tier)
			# Off the last isle laid in the neighbourhood, else off another of
			# it (the one before is then a side isle); one that won't stand
			# anywhere: another drawn in its place.
			var froms: Array = [from]
			for i: int in plan.hoods[h]:
				if i != from and plan.isles[i].role != "greed": froms.append(i)
			var got := {}
			for sub in range(SUBS+1):
				if sub > 0:
					m = _substitute(plan,groups,greed,h,rng)
					if m.is_empty(): break
					groups[h][k] = m
				for f: int in froms:
					got = _step(plan,f,m,kinds,"route",used,rng,least,INF,h)
					if got.is_empty() and not then.is_empty() and kinds[0] != "climb": got = _step(plan,f,m,then,"route",used,rng,least,INF,h)
					if got.is_empty() and kinds[0] == "trap":
						got = _step(plan,f,m,["stones","bridge"],"route",used,rng,least,INF,h)
					elif not got.is_empty() and kinds[0] == "trap": traps_left -= 1
					if not got.is_empty(): break
				if not got.is_empty(): break
			if got.is_empty():
				plan.problems.append("no way onto %s" % group[k].id)
				return plan
			from = plan.isles.size()-1
			plan.hoods[h].append(from)
	if traps_left > 0: plan.problems.append("no trap edge on the route")
	for i in range(plan.isles.size()): plan.route.append(i)
	# The exit: the highest rim left on the last isle, its gate.
	var top: Dictionary = plan.isles[from]
	var exit := {}
	for s: Dictionary in top.sockets:
		if s.kind != "rim" or used.has(_key(from,s.name)) or not can_out(s,plan.knobs): continue
		if exit.is_empty() or (s.at as Vector3).y+way_score(s,{},plan.knobs) > (exit.at as Vector3).y+way_score(exit,{},plan.knobs): exit = s
	if exit.is_empty():
		plan.problems.append("no exit rim on %s" % top.id)
		return plan
	used[_key(from,exit.name)] = true
	plan.exit = {"isle":from,"rim":exit.name,"at":exit.at,"face":exit.face}
	# The greed branch: off a route isle past the base (the base if none),
	# onto the greed isle in that isle's neighbourhood; the rune set on its
	# roomiest perch.
	greed.role = "greed"
	var starts: Array = range(1,plan.isles.size()) if plan.isles.size() > 1 else [0]
	_shuffle(starts,rng)
	var branched := {}
	var ceiling := _top_walked(plan.isles[from])-1.0
	for s: int in starts+[0]:
		greed.hood = int(plan.isles[s].hood)
		branched = _step(plan,s,greed,["hard"],"greed",used,rng,-INF,ceiling,int(greed.hood))
		if not branched.is_empty(): break
	if branched.is_empty():
		plan.problems.append("no greed branch onto %s" % greed.id)
		return plan
	var g: int = plan.isles.size()-1
	plan.hoods[int(greed.hood)].append(g)
	var perch := {}
	for s: Dictionary in plan.isles[g].sockets:
		if s.kind == "perch" and (perch.is_empty() or float(s.room) > float(perch.room)): perch = s
	if perch.is_empty(): perch = {"at":(branched.to_rim.at as Vector3)-(branched.to_rim.face as Vector3)*3.0,"room":2.0}
	var ring := clampf(float(perch.room)*0.6,1.0,2.2)
	var runes: Array = []
	for i in range(RUNES):
		var a := TAU*i/RUNES
		runes.append((perch.at as Vector3)+Vector3(cos(a)*ring,1.0,sin(a)*ring))
	plan.prize = {"isle":g,"at":perch.at,"room":perch.room,"runes":runes}
	# The highest of its neighbourhood: the exit's isle.
	var exit_y := _top_walked(plan.isles[from])
	for i: int in plan.hoods[hoods-1]:
		if i == from or LayerWorlds.city(k_all): continue
		if _top_walked(plan.isles[i]) > exit_y:
			plan.problems.append("%s stands higher than the exit" % plan.isles[i].id)
			return plan
	_cannon(plan,branched,rng)
	# A gulf narrow enough gets a cannon too: the fast, risky way over.
	for gi: int in plan.gulfs:
		var e: Dictionary = plan.edges[gi]
		e.cannon = {}
		if float(e.width) <= GULF_CANNON_MOST: e.cannon = _gulf_cannon(plan,e)
	_ram(plan,used)
	# The spawn: back along the first edge's rim's run-up on the base.
	var first: Dictionary = plan.edges[0]
	var rim: Dictionary = first.from_rim
	var back := minf(float(rim.run_up)*0.7,SPAWN_BACK)
	plan.spawn = {"at":(rim.at as Vector3)-(rim.face as Vector3)*back+Vector3.UP*0.2,"face":rim.face}
	var low := INF
	for isle: Dictionary in plan.isles: low = minf(low,_span(isle).x)
	plan.void_y = low-VOID_UNDER
	if Greybox.missing(plan): plan.problems.append("no greybox isle placed")
	return plan

## A motif drawn for neighbourhood `h` in place of one that won't stand:
## by weight, a family any number of times, the rest only if the layer
## has none of them yet, a hero only where the neighbourhood has none.
static func _substitute(plan: Dictionary, groups: Array, greed: Dictionary, h: int, rng: RandomNumberGenerator) -> Dictionary:
	var taken := {}
	var hero := false
	for isle: Dictionary in plan.isles: taken[isle.id] = int(taken.get(isle.id,0))+1
	for g: Array in groups:
		for m: Dictionary in g: taken[m.id] = int(taken.get(m.id,0))+1
	taken[greed.id] = int(taken.get(greed.id,0))+1
	for m: Dictionary in groups[h]: if m.has("motif") and m.motif.role() == "hero": hero = true
	for i: int in plan.hoods[h] if h < (plan.hoods as Array).size() else []:
		if plan.isles[i].has("motif") and plan.isles[i].motif.role() == "hero": hero = true
	var pool: Array = []
	for p: Array in draw_pool(plan.knobs):
		var probe: RefCounted = (p[1] as Script).new()
		if not probe.family() and int(taken.get(str(p[0]),0)) >= _most(str(p[0]),int(plan.knobs.get("repeats",1)),plan.knobs): continue
		if hero and probe.role() == "hero": continue
		pool.append(p)
	if pool.is_empty(): return {}
	# Underground one the layer hasn't got yet, where any is left.
	if LayerWorlds.world_of(plan.knobs) == "under":
		var fresh := pool.filter(func(p: Array) -> bool: return int(taken.get(str(p[0]),0)) == 0)
		if not fresh.is_empty(): pool = fresh
	var total := 0.0
	for p: Array in pool: total += float(p[2])
	var roll := rng.randf()*total
	for p: Array in pool:
		roll -= float(p[2])
		if roll <= 0.0:
			var m := _motif_isle(p,rng)
			m.role = "route"
			m.hood = h
			return m
	var last := _motif_isle(pool[pool.size()-1],rng)
	last.role = "route"
	last.hood = h
	return last

## `count` pool picks by weight: a family any number of times (its own seed
## and knobs each), the rest at most once a layer.
## `repeats` (a knob, the sprawl shape's): how many times one that is not
## a family may come a layer. `knobs` the layer's: its greybox motifs in
## the pool, the first draw one of them where forced.
static func _draw(count: int, rng: RandomNumberGenerator, repeats := 1, knobs := {}) -> Array:
	var drawn := {}
	var picks: Array = []
	var pool: Array = draw_pool(knobs).duplicate()
	var forced := Greybox.forced(knobs)
	var asked := Greybox.wanted(knobs)
	# Underground every city motif once before any comes again (a fresh
	# round of the pool when it runs dry), so a layer holds as many
	# different places as fit (layer-round14-city-layers.md).
	var under := LayerWorlds.world_of(knobs) == "under"
	var round_left: Array = pool.duplicate()
	while picks.size() < count and not pool.is_empty():
		var from: Array = pool
		if under:
			round_left = round_left.filter(func(p: Array) -> bool: return pool.has(p))
			if round_left.is_empty(): round_left = pool.duplicate()
			from = round_left
		# The first draw a motif the `greybox` knob forces.
		if forced and picks.is_empty():
			var named := pool.filter(func(p: Array) -> bool: return asked.has(str(p[0]).trim_prefix("gb_")))
			if not named.is_empty(): from = named
		var total := 0.0
		for p: Array in from: total += float(p[2])
		var roll := rng.randf()*total
		for k in range(from.size()):
			roll -= float(from[k][2])
			if roll <= 0.0 or k == from.size()-1:
				var i := pool.find(from[k])
				picks.append(pool[i])
				round_left.erase(pool[i])
				var probe: RefCounted = (pool[i][1] as Script).new()
				drawn[pool[i][0]] = int(drawn.get(pool[i][0],0))+1
				if not probe.family() and int(drawn[pool[i][0]]) >= _most(str(pool[i][0]),repeats,knobs): pool.remove_at(i)
				break
	return picks

## What a crossing that keeps to a motif's ways adds to its score (with
## `one_way` -1): more than any other reason, so a fit forwards always wins
## and one backwards stands only where none forwards does (a motif's single
## way in, facing one way, often won't fit; better backwards than the
## layer short).
const WAY_WEIGHT := 1000.0

## A rim's way (a greybox motif's, motif_greybox.gd `sockets`): one marked
## "in" is never left by, one marked "out" never come in at, so the route
## runs a motif's chain forwards.
static func can_out(s: Dictionary, knobs: Dictionary) -> bool:
	return int(knobs.get("one_way",-1)) != 1 or str(s.get("way","")) != "in"

## The rims of `rims` an edge may come in at: those marked "in" where any
## is, else all but those marked "out".
static func ins_of(rims: Array, knobs: Dictionary) -> Array:
	if int(knobs.get("one_way",-1)) != 1: return rims
	var marked := rims.filter(func(s: Dictionary) -> bool: return str(s.get("way","")) == "in")
	return marked if not marked.is_empty() else rims.filter(func(s: Dictionary) -> bool: return str(s.get("way","")) != "out")

## What a crossing out of rim `ra` (or {}) into rim `rb` (or {}) adds to its
## score for keeping to their ways (WAY_WEIGHT, the `one_way` knob).
static func way_score(ra: Dictionary, rb: Dictionary, knobs: Dictionary) -> float:
	if int(knobs.get("one_way",-1)) == 0: return 0.0
	return WAY_WEIGHT if str(ra.get("way","")) != "in" and str(rb.get("way","")) != "out" else 0.0

## Whether an isle runs one way (its rims marked), so it belongs on the route,
## not as the greed branch's dead end.
static func one_way(m: Dictionary) -> bool:
	return (m.own as Array).any(func(s: Dictionary) -> bool: return str(s.get("way","")) != "")

static func _key(isle: int, rim: String) -> String:
	return "%d/%s" % [isle,rim]

# --- The isles ----------------------------------------------------------------------

## The base as an isle record: the aqueduct isle (stood at the origin), or
## underground the city landing (scripts/kit_isle/greybox/gb_city_landing.gd)
## with its crown's middle at MIDDLE (layer-round14-city-layers.md). Its
## sockets in the world.
static func _base_isle(knobs := {}) -> Dictionary:
	if LayerWorlds.city(knobs):
		var slug := LayerWorlds.UNDER_BASE
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var land := _motif_isle(["gb_"+slug,Greybox.MOTIFS[slug],0.0],rng)
		land.key = "gb_"+slug
		land.role = "base"
		land.offset = MIDDLE
		land.sockets = []
		for s: Dictionary in land.own: land.sockets.append(_world(s,MIDDLE))
		return land
	var aq := {"key":BASE,"id":BASE,"script":null,"seed":-1,"knobs":{},"role":"base","offset":Vector3.ZERO,
		"own":LayerPieces.sockets(BASE).filter(func(s: Dictionary) -> bool: return s.kind == "rim"),"occ":LayerPieces.occupancy(BASE),"sockets":[]}
	aq.sockets = (aq.own as Array).duplicate()
	return aq

## Whether `plan`'s base is the aqueduct isle (the study's own land), not a
## motif stood like the others.
static func aqueduct_base(plan: Dictionary) -> bool:
	return (plan.get("isles",[]) as Array).is_empty() or str(plan.isles[0].id) == BASE

## The base's spots of `kind` (world): the aqueduct's baked ones, else the
## base isle's own sockets.
static func base_spots(plan: Dictionary, kind: String) -> Array:
	if aqueduct_base(plan): return LayerPieces.sockets(BASE).filter(func(s: Dictionary) -> bool: return s.kind == kind)
	return (plan.isles[0].sockets as Array).filter(func(s: Dictionary) -> bool: return s.kind == kind)

## A pool pick as an isle record, a family configured from `rng` (its own
## seed and knobs), its sockets read in its own frame (`own`).
static func _motif_isle(pick: Array, rng: RandomNumberGenerator) -> Dictionary:
	var script: Script = pick[1]
	var m: RefCounted = script.new()
	var isle_seed := -1
	if m.family():
		isle_seed = rng.randi_range(1,9999)
		m.configure(isle_seed)
	elif m.has_method("vary"):
		# One not a family that varies its look from a seed (its shape kept:
		# gb_stacked_court.gd, many a layer underground).
		isle_seed = rng.randi_range(1,9999)
		m.vary(isle_seed)
	var own: Array = []
	for s: Dictionary in m.sockets():
		var c := s.duplicate()
		if not c.has("lip"): c.lip = float(s.room) if s.kind == "rim" else 0.0
		own.append(c)
	# The colonnade's tail rim only with both its bridges holding (else its
	# fragments may be out of reach on foot).
	if m.id() == "colonnade_spine" and str(m.knobs.get("bridges","intact")) != "intact":
		own = own.filter(func(s: Dictionary) -> bool: return s.name != "tail")
	var occ := LayerPieces.occupancy(m.id())
	# A rolled ring moves its isles: its occupancy from its plan.
	if m.id() == "broken_ring": occ = _ring_occ(m)
	# A greybox motif computes its own (scripts/kit_isle/motif_greybox.gd).
	elif occ.is_empty() and m.has_method("occupancy"): occ = m.occupancy()
	elif occ.is_empty(): occ = _box_occ(m.footprint(),m.height_span())
	return {"key":"%s_%d_%d" % [m.id(),isle_seed,rng.randi()%100000],"id":m.id(),"script":script,"seed":isle_seed,"knobs":m.knobs.duplicate(),"role":"",
		"offset":Vector3.ZERO,"own":own,"occ":occ,"sockets":[],"motif":m}

static func _box_occ(rect: Rect2, span: Vector2) -> Dictionary:
	var cell := 2.0
	var cols := int(ceil(rect.size.x/cell))+2
	var rows := int(ceil(rect.size.y/cell))+2
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	lo.resize(cols*rows)
	hi.resize(cols*rows)
	lo.fill(span.x)
	hi.fill(span.y)
	return {"origin":rect.position-Vector2.ONE*cell,"cell":cell,"cols":cols,"rows":rows,"lo":lo,"hi":hi}

## A broken ring's occupancy from its plan (studies/broken_ring_isle_art.gd):
## its central isle and each satellite a disc from its keel (the art's
## depths) to RING_OVER over its top (the circle, the turret, the notes),
## each floating stone a small block.
const RING_OVER := 10.0
static func _ring_occ(m: RefCounted) -> Dictionary:
	var Ring: GDScript = m.Ring
	var p: Dictionary = m.plan()
	var occ := _box_occ(m.footprint().grow(2.0),Vector2(INF,-INF))
	var discs: Array = [[Ring.C,float(Ring.CENTRE_R)*1.08,float(Ring.centre_top(p))-24.0,float(Ring.centre_top(p))+RING_OVER]]
	for sat: Dictionary in Ring.sats(p):
		discs.append([sat.c,float(sat.r)*1.08,float(sat.top)-7.0-float(sat.r),float(sat.top)+RING_OVER*0.7])
	for st: Dictionary in Ring.platforms(p):
		var at: Vector3 = st.at
		discs.append([Vector2(at.x,at.z),1.4,at.y-2.6,at.y+0.2])
	var lo: PackedFloat32Array = occ.lo
	var hi: PackedFloat32Array = occ.hi
	var cell: float = occ.cell
	var origin: Vector2 = occ.origin
	for k in range(lo.size()):
		var q := origin+Vector2(k%int(occ.cols)+0.5,k/int(occ.cols)+0.5)*cell
		for d: Array in discs:
			if q.distance_to(d[0]) > float(d[1])+cell*0.75: continue
			lo[k] = minf(lo[k],float(d[2]))
			hi[k] = maxf(hi[k],float(d[3]))
	occ.lo = lo
	occ.hi = hi
	return occ

static func _area(isle: Dictionary) -> float:
	var o: Dictionary = isle.occ
	return float(o.cols)*float(o.rows)

## How far its rims climb (m): its highest rim over its lowest.
static func _climb(isle: Dictionary) -> float:
	var lo := INF
	var hi := -INF
	for s: Dictionary in isle.own:
		if s.kind != "rim": continue
		lo = minf(lo,(s.at as Vector3).y)
		hi = maxf(hi,(s.at as Vector3).y)
	return hi-lo if hi > lo else 0.0

## Its highest walked point (world): its rims and spots.
static func _top_walked(isle: Dictionary) -> float:
	var h := -INF
	for s: Dictionary in isle.own: h = maxf(h,(s.at as Vector3).y)
	return h+(isle.offset as Vector3).y

## Its lowest and highest solid (world y).
static func _span(isle: Dictionary) -> Vector2:
	var o: Dictionary = isle.occ
	if not o.has("_span"):
		var span := Vector2(INF,-INF)
		for v: float in o.lo: if v < INF: span.x = minf(span.x,v)
		for v: float in o.hi: if v > -INF: span.y = maxf(span.y,v)
		o._span = span
	return (o._span as Vector2)+Vector2.ONE*(isle.offset as Vector3).y

## Its rect (world x, z).
static func _rect(isle: Dictionary) -> Rect2:
	var o: Dictionary = isle.occ
	var off: Vector3 = isle.offset
	return Rect2((o.origin as Vector2)+Vector2(off.x,off.z),Vector2(float(o.cols),float(o.rows))*float(o.cell))

## Its lowest and highest solid at (x, z) (world), Vector2(INF, -INF) for
## none.
static func occ_at(isle: Dictionary, x: float, z: float) -> Vector2:
	return _grid_at(isle.occ,isle.offset,x,z)

static func _grid_at(o: Dictionary, off: Vector3, x: float, z: float) -> Vector2:
	var origin: Vector2 = o.origin
	var c := int(floor((x-off.x-origin.x)/float(o.cell)))
	var r := int(floor((z-off.z-origin.y)/float(o.cell)))
	if c < 0 or r < 0 or c >= int(o.cols) or r >= int(o.rows): return Vector2(INF,-INF)
	var k := r*int(o.cols)+c
	var lo: float = (o.lo as PackedFloat32Array)[k]
	if lo == INF: return Vector2(INF,-INF)
	return Vector2(lo+off.y,(o.hi as PackedFloat32Array)[k]+off.y)

## Its occupancy COARSE cells to a side merged (each the lowest and highest
## of its cells), made once: what `clash` looks at first.
const COARSE := 4
static func _coarse(o: Dictionary) -> Dictionary:
	if o.has("_coarse"): return o._coarse
	var cols := int(ceil(float(o.cols)/COARSE))
	var rows := int(ceil(float(o.rows)/COARSE))
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	lo.resize(cols*rows)
	hi.resize(cols*rows)
	lo.fill(INF)
	hi.fill(-INF)
	var flo: PackedFloat32Array = o.lo
	var fhi: PackedFloat32Array = o.hi
	for k in range(flo.size()):
		if flo[k] == INF: continue
		var ck := (k/int(o.cols))/COARSE*cols+(k%int(o.cols))/COARSE
		lo[ck] = minf(lo[ck],flo[k])
		hi[ck] = maxf(hi[ck],fhi[k])
	o._coarse = {"origin":o.origin,"cell":float(o.cell)*COARSE,"cols":cols,"rows":rows,"lo":lo,"hi":hi}
	return o._coarse

## Whether two isles stand in each other (CLEAR kept over and under): their
## coarse cells first, the fine ones only where those meet.
static func clash(a: Dictionary, b: Dictionary) -> bool:
	var ra := _rect(a)
	var rb := _rect(b)
	if not ra.intersects(rb): return false
	var sa := _span(a)
	var sb := _span(b)
	if sa.y+CLEAR < sb.x or sb.y+CLEAR < sa.x: return false
	var both := ra.intersection(rb)
	var cb := _coarse(b.occ)
	var ca := _coarse(a.occ)
	var off_a: Vector3 = a.offset
	var off_b: Vector3 = b.offset
	var big: float = cb.cell
	var ob: Vector2 = (cb.origin as Vector2)+Vector2(off_b.x,off_b.z)
	var c0 := maxi(int(floor((both.position.x-ob.x)/big)),0)
	var c1 := mini(int(floor((both.end.x-ob.x)/big)),int(cb.cols)-1)
	var r0 := maxi(int(floor((both.position.y-ob.y)/big)),0)
	var r1 := mini(int(floor((both.end.y-ob.y)/big)),int(cb.rows)-1)
	var cell: float = b.occ.cell
	for r in range(r0,r1+1):
		for c in range(c0,c1+1):
			var hb := _grid_at(cb,off_b,ob.x-off_b.x+off_b.x+(c+0.5)*big,ob.y+(r+0.5)*big)
			if hb.x == INF: continue
			# The other's coarse cells under this one's corners and middle.
			var ha := Vector2(INF,-INF)
			for o: Vector2 in [Vector2(0.01,0.01),Vector2(0.99,0.01),Vector2(0.01,0.99),Vector2(0.99,0.99),Vector2(0.5,0.5)]:
				var h := _grid_at(ca,off_a,ob.x+(c+o.x)*big,ob.y+(r+o.y)*big)
				ha = Vector2(minf(ha.x,h.x),maxf(ha.y,h.y))
			if ha.x == INF or ha.x >= hb.y+CLEAR or hb.x >= ha.y+CLEAR: continue
			# Fine, within this coarse cell.
			var x := ob.x+c*big+cell*0.5
			while x < ob.x+(c+1)*big:
				var z := ob.y+r*big+cell*0.5
				while z < ob.y+(r+1)*big:
					var fb := occ_at(b,x,z)
					if fb.x < INF:
						var fa := occ_at(a,x,z)
						if fa.x < INF and fa.x < fb.y+CLEAR and fb.x < fa.y+CLEAR: return true
					z += cell
				x += cell
	return false

## How much of `b` stands over another isle (a share of its coarse cells):
## a missed jump off it lands lower.
static func over_share(plan: Dictionary, b: Dictionary) -> float:
	var cb := _coarse(b.occ)
	var off_b: Vector3 = b.offset
	var ob: Vector2 = (cb.origin as Vector2)+Vector2(off_b.x,off_b.z)
	var n := 0
	var over := 0
	for r in range(int(cb.rows)):
		for c in range(int(cb.cols)):
			var x := ob.x+(c+0.5)*float(cb.cell)
			var z := ob.y+(r+0.5)*float(cb.cell)
			var hb := _grid_at(cb,off_b,x,z)
			if hb.x == INF: continue
			n += 1
			for a: Dictionary in plan.isles:
				if a == b: continue
				var ha := occ_at(a,x,z)
				if ha.x < INF and ha.y < hb.x:
					over += 1
					break
	return float(over)/maxf(n,1)

# --- The edges ----------------------------------------------------------------------

## The next isle `m` stood off isle `from` by an edge of one of `kinds`
## (tried TRIES times, the best kept; its highest walked point between `least`
## and `most`): the edge appended to the plan, `m`
## placed and appended; the edge, or {} if none fits.
static func _step(plan: Dictionary, from: int, m: Dictionary, kinds: Array, branch: String, used: Dictionary, rng: RandomNumberGenerator,
		least := -INF, most := INF, hood := 0) -> Dictionary:
	var a: Dictionary = plan.isles[from]
	var outs: Array = a.own.filter(func(s: Dictionary) -> bool: return s.kind == "rim" and not used.has(_key(from,s.name)) and can_out(s,plan.knobs))
	var ins: Array = ins_of(m.own.filter(func(s: Dictionary) -> bool: return s.kind == "rim"),plan.knobs)
	# A family's way through: in at its entry, out at its exit (the ring).
	if ins.any(func(s: Dictionary) -> bool: return s.name == "entry"): ins = ins.filter(func(s: Dictionary) -> bool: return s.name == "entry")
	if from > 0 and outs.any(func(s: Dictionary) -> bool: return s.name == "exit"): outs = outs.filter(func(s: Dictionary) -> bool: return s.name == "exit")
	if outs.is_empty() or ins.is_empty(): return {}
	var off_a: Vector3 = a.offset
	var began := Time.get_ticks_msec()
	# The neighbourhood's middle: its first isle's (the base's MIDDLE).
	var anchor := Vector2(MIDDLE.x,MIDDLE.z)
	if hood < (plan.hoods as Array).size() and int(plan.hoods[hood][0]) > 0: anchor = _rect(plan.isles[plan.hoods[hood][0]]).get_center()
	var why := {}
	var best := {}
	var best_score := -INF
	# Every out rim and in rim that face each other, each kind, in a shuffled
	# order: TRIES of them tried.
	var combos: Array = []
	for ra: Dictionary in outs:
		for rb: Dictionary in ins:
			if (ra.face as Vector3).dot(-(rb.face as Vector3)) < cos(deg_to_rad(TURN_MOST*2.0)): continue
			for kind: String in kinds: combos.append([ra,rb,kind])
	for i in range(combos.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap: Variant = combos[i]
		combos[i] = combos[j]
		combos[j] = swap
	# Those keeping to a motif's ways tried first (none marked: as shuffled).
	var ahead := combos.filter(func(c: Array) -> bool: return way_score(c[0],c[1],plan.knobs) > 0.0)
	if not ahead.is_empty() and ahead.size() < combos.size():
		combos = ahead+combos.filter(func(c: Array) -> bool: return way_score(c[0],c[1],plan.knobs) <= 0.0)
	for t in range(TRIES):
		if combos.is_empty(): break
		var combo: Array = combos[t%combos.size()]
		var ra: Dictionary = combo[0]
		var rb: Dictionary = combo[1]
		var kind: String = combo[2]
		var fa: Vector3 = ra.face
		var fb: Vector3 = rb.face
		var dir := (fa-fb).normalized()
		if dir.dot(fa) < cos(deg_to_rad(TURN_MOST)) or dir.dot(-fb) < cos(deg_to_rad(TURN_MOST)): continue
		if kind in ["stones","hard","climb","piers","broken"] and float(ra.run_up) < 1.5: continue
		if kind == "hard" and float(ra.run_up) < CANNON_BACK+1.0: continue
		# A climb comes up onto clear ground (its bridge's anchor and him).
		if kind == "climb" and float(rb.run_up) < CLIMB_RUN_UP: continue
		var lip_a: Vector3 = (ra.at as Vector3)+off_a+fa*float(ra.lip)
		var shape := _shape(kind,lip_a,dir,rng,mean(plan.knobs),CityWays.on(plan.knobs))
		if shape.is_empty(): continue
		var lip_b: Vector3 = shape.b
		var at_b: Vector3 = lip_b-fb*float(rb.lip)
		var off_b: Vector3 = at_b-(rb.at as Vector3)
		var placed := m.duplicate()
		placed.offset = off_b
		placed.hood = hood
		var top_b := _top_walked(placed)
		if top_b < least or top_b > most:
			why.height = why.get("height",0)+1
			continue
		# Kept within the band round the base.
		var mid := _rect(placed).get_center()
		if mid.distance_to(Vector2(MIDDLE.x,MIDDLE.z)) > band(plan.knobs).x or mid.distance_to(anchor) > band(plan.knobs).y:
			why.band = why.get("band",0)+1
			continue
		if not _apart(plan,placed):
			why.apart = why.get("apart",0)+1
			continue
		if _isle_in_tubes(placed,plan.tubes):
			why.tubes = why.get("tubes",0)+1
			continue
		var bad := false
		for other: Dictionary in plan.isles:
			if clash(other,placed):
				bad = true
				break
		if bad:
			why.clash = why.get("clash",0)+1
			continue
		var edge := {"kind":kind,"branch":branch,"from":[from,ra.name],"to":[plan.isles.size(),rb.name],"a":lip_a,"b":lip_b,"dir":dir,
			"stones":shape.stones,"bridges":shape.bridges,"parts":shape.parts,"trap":shape.trap,"path":shape.path,"from_rim":_world(ra,off_a),"to_rim":_world(rb,off_b)}
		# The city family's own (city_ways.gd): its spans, its chute, its flanks.
		for k: String in ["spans","chute","flank"]: if shape.has(k): edge[k] = shape[k]
		var isles: Array = plan.isles+[placed]
		if not _corridor_clear(edge,isles,from,isles.size()-1):
			why.corridor = why.get("corridor",0)+1
			continue
		if _crosses(edge,plan.edges):
			why.crosses = why.get("crosses",0)+1
			continue
		if _covers_edges(placed,plan.edges):
			why.covers = why.get("covers",0)+1
			continue
		# The best: climbing, over another isle (a soft fall), near the base.
		var score := rng.randf()*2.0
		score += 0.15*(lip_b.y-lip_a.y)
		score += OVER_WEIGHT*over_share(plan,placed)
		score -= 0.01*mid.distance_to(anchor)
		score += _lean(plan,mid)
		score += way_score(ra,rb,plan.knobs)
		if score > best_score:
			best_score = score
			best = {"edge":edge,"isle":placed}
	if trace: print("layer plan: step %d -> %s %s, %d ms %s" % [from,m.id,kinds,Time.get_ticks_msec()-began,why])
	if best.is_empty(): return {}
	var placed_isle: Dictionary = best.isle
	placed_isle.sockets = []
	for s: Dictionary in placed_isle.own: placed_isle.sockets.append(_world(s,placed_isle.offset))
	plan.isles.append(placed_isle)
	var e: Dictionary = best.edge
	if not (e.trap as Dictionary).is_empty(): e.trap.under = _under(e,plan.isles)
	plan.edges.append(e)
	used[_key(from,e.from[1])] = true
	used[_key(e.to[0],e.to[1])] = true
	return e

static func _world(s: Dictionary, off: Vector3) -> Dictionary:
	var w := s.duplicate()
	w.at = (s.at as Vector3)+off
	return w

## An edge of `kind` leaving lip `a` along `dir`: {b (its far lip), path
## (samples [point, under, over]), stones (floating stones' platforms),
## bridges ([a, b] deck ends), trap ({frame, count, under}), parts (what it
## is made of, in order)}, sized from the pilot. Rims stand tens of metres
## apart, so most edges are made of parts: a run of stones up to a landing
## (a floating slab), then a rope bridge or the trap from it; or a long run
## of stones.
static func _shape(kind: String, a: Vector3, dir: Vector3, rng: RandomNumberGenerator, meanness := 0.0, ways := false) -> Dictionary:
	# The city's family (city_ways.gd); the greed branch's hard edge its
	# hard piers.
	if ways and kind in CityWays.KINDS and kind != "stones": return CityWays.shape(kind,a,dir,rng,meanness)
	if ways and kind == "hard": return CityWays.shape("piers",a,dir,rng,meanness,true)
	var out := {"stones":[],"bridges":[],"trap":{},"parts":[],"path":[],"mean":meanness}
	var chain := "%s_%d_%d" % [kind,roundi(a.x),roundi(a.z)]
	var p := a
	match kind:
		"stones":
			p = _lay_stones(out,p,dir,rng.randi_range(4,9),false,rng,chain)
		"hard":
			p = _lay_stones(out,p,dir,rng.randi_range(3,6),true,rng,chain)
		"bridge":
			if rng.randf() < 0.6:
				p = _lay_stones(out,p,dir,rng.randi_range(2,5),false,rng,chain)
				p = _landing(out,p,dir,chain)
			var hop := KitMotif.hop_reach()
			var span := clampf(hop*rng.randf_range(SPAN_HOPS.x,SPAN_HOPS.y),Footbridge.TIMBER_SPAN,Footbridge.MAX_SPAN)
			var rise := span*Footbridge.MAX_GRADE*GRADE*rng.randf_range(0.0,1.0)
			var b := p+dir*span+Vector3.UP*rise
			out.bridges.append([p,b])
			out.parts.append("bridge %.1f m" % span)
			out.path.append_array(_line(p,b,Footbridge.bow(span)+0.6))
			p = b
		"climb":
			# Up a tier: runs of stones each stepping up as steeply as his
			# small jump keeps easy, a landing after each, a bridge up at the
			# footbridge's grade to the far rim.
			for r in range(rng.randi_range(2,3)):
				p = _lay_stones(out,p,dir,rng.randi_range(4,6),false,rng,"%s_%d" % [chain,r],CLIMB_LIFT)
				p = _landing(out,p,dir,"%s_%d" % [chain,r])
			var span := clampf(KitMotif.hop_reach()*rng.randf_range(SPAN_HOPS.x,SPAN_HOPS.y),Footbridge.TIMBER_SPAN,Footbridge.MAX_SPAN)
			var b := p+dir*span+Vector3.UP*span*Footbridge.MAX_GRADE*GRADE
			out.bridges.append([p,b])
			out.parts.append("bridge up %.1f m" % span)
			out.path.append_array(_line(p,b,Footbridge.bow(span)+0.6))
			p = b
		"trap":
			if rng.randf() < 0.7:
				p = _lay_stones(out,p,dir,rng.randi_range(2,5),false,rng,chain)
				p = _landing(out,p,dir,chain)
			var slab := slab_length()
			var count := rng.randi_range(6,9)
			var over := slab*0.25
			var length := count*slab-2.0*over
			var b := p+dir*length
			out.trap = {"frame":Transform3D(Basis.looking_at(dir,Vector3.UP),p-dir*over),"count":count,"under":"void"}
			out.parts.append("voussoirs x%d" % count)
			out.path.append_array(_line(p,b,1.0))
			p = b
	out.b = p
	return out

static var _slab := 0.0
## The Loose Voussoirs' slab length (its own default, from the pilot's walk).
static func slab_length() -> float:
	if _slab == 0.0:
		var v: Node3D = Voussoirs.new()
		_slab = float(v.defaults().length)
		v.free()
	return _slab

## `n` stones on from `p` (the lip or a landing's far edge) along `dir`,
## each stride a gap a share of his reach at its rise, into `out`; answers
## where the next part's near edge stands (one more stride on).
## A climb's stones step up this share of his small jump.
const CLIMB_LIFT := Vector2(0.42,0.5)
## A climb's far rim wants this much clear ground behind it (m).
const CLIMB_RUN_UP := 2.5
static func _lay_stones(out: Dictionary, p: Vector3, dir: Vector3, n: int, hard: bool, rng: RandomNumberGenerator, chain: String, lift := Vector2(0.15,0.5)) -> Vector3:
	var j := float(pilot().jumps[0])
	var h := j*(rng.randf_range(0.0,0.4) if hard else rng.randf_range(lift.x,lift.y))
	# Each gap a share of his small jump's reach at its rise (the greed
	# branch's nearer it); each stone long enough that the pump (a jump
	# straight off a landing, as a runner chains them) still comes down on
	# the next, not past it.
	var share := rng.randf_range(GAP_HARD.x,GAP_HARD.y) if hard else rng.randf_range(GAP_SHARE.x,GAP_SHARE.y)
	# Meaner higher up (`mean`): the route's gaps eased toward the greed
	# branch's, the stones a little smaller.
	var meanness := float(out.get("mean",0.0))
	if not hard and meanness > 0.0: share = lerpf(share,rng.randf_range(GAP_HARD.x,GAP_HARD.y),meanness)
	var gap := reach(h)*share
	gap = maxf(gap,clears(h)+0.3)
	var length := maxf(lerpf(stone_length(hard),stone_length(true),meanness*0.6),pump_reach(h)*PUMP_ROOM-gap)
	var yaw := atan2(-dir.z,dir.x)
	var first: int = (out.stones as Array).size()
	for k in range(n):
		var top := p+dir*(gap*(k+1)+length*(k+0.5))+Vector3.UP*h*(k+1)
		out.stones.append({"name":"%s_%d" % [chain,first+k+1],"at":top,"size":Vector3(length,0.7 if k%2 == 0 else 0.9,length*(0.95 if hard else 1.0)),
			"yaw":yaw+(0.12 if k%2 else -0.08),"kind":"block","chain":chain,"gap":gap,"rise":h})
	var next := p+dir*(gap*(n+1)+length*n)+Vector3.UP*h*(n+1)
	out.parts.append("%d stones (gap %.2f, rise %.2f)" % [n,gap,h])
	out.path.append_array(_line(p,next,UNDER))
	return next

## A landing: a broad floating slab whose near edge is at `p`; answers its
## far edge (on its top).
static func _landing(out: Dictionary, p: Vector3, dir: Vector3, chain: String) -> Vector3:
	var size := landing_size()
	var top := p+dir*size*0.5
	out.stones.append({"name":"%s_landing" % chain,"at":top,"size":Vector3(size,1.0,size),"yaw":atan2(-dir.z,dir.x),"kind":"block","chain":chain,"landing":true})
	out.parts.append("landing")
	var far := p+dir*size
	out.path.append_array(_line(p,far,UNDER))
	return far

## A landing's side (m): a running half second of his, room for a bridge's
## anchors.
static func landing_size() -> float:
	return pilot().run*0.6

## Samples along a straight edge from `a` to `b` every half metre:
## [point, how deep under it, how high over it].
static func _line(a: Vector3, b: Vector3, under: float, step := 0.5) -> Array:
	var out: Array = []
	var n := maxi(int(ceil(a.distance_to(b)/step)),1)
	for i in range(n+1):
		out.append([a.lerp(b,float(i)/n),under,OVER])
	return out

## Whether the edge's corridor is clear of every isle (its own two only
## past OWN_NEAR of its lips).
static func _corridor_clear(edge: Dictionary, isles: Array, from: int, to: int) -> bool:
	var a: Vector3 = edge.a
	var b: Vector3 = edge.b
	var dir: Vector3 = edge.dir
	var side := dir.cross(Vector3.UP).normalized()
	for s: Array in edge.path+edge.get("flank",[]):
		var p: Vector3 = s[0]
		var lo := p.y-float(s[1])
		var hi := p.y+float(s[2])
		var near_a := Vector2(p.x-a.x,p.z-a.z).length() < OWN_NEAR
		var near_b := Vector2(p.x-b.x,p.z-b.z).length() < OWN_NEAR
		for i in range(isles.size()):
			if (i == from and near_a) or (i == to and near_b): continue
			for off: float in [-SIDE,0.0,SIDE]:
				var q := p+side*off
				var o := occ_at(isles[i],q.x,q.z)
				if o.x < INF and o.x < hi+CLEAR*0.5 and lo-CLEAR*0.5 < o.y: return false
	return true

## Whether the edge comes within CLEAR of another edge's corridor.
static func _crosses(edge: Dictionary, edges: Array) -> bool:
	var mine: Array = edge.path+edge.get("flank",[])
	for e: Dictionary in edges:
		var theirs: Array = e.path+e.get("flank",[])
		for s: Array in mine:
			var p: Vector3 = s[0]
			for t: Array in theirs:
				var q: Vector3 = t[0]
				if Vector2(p.x-q.x,p.z-q.z).length() < CLEAR and absf(p.y-q.y) < OVER+UNDER+CLEAR: return true
	return false

## Whether the isle stands in an edge laid before.
static func _covers_edges(isle: Dictionary, edges: Array) -> bool:
	for e: Dictionary in edges:
		for s: Array in e.path+e.get("flank",[]):
			var p: Vector3 = s[0]
			var o := occ_at(isle,p.x,p.z)
			if o.x < INF and o.x < p.y+float(s[2])+CLEAR*0.5 and p.y-float(s[1])-CLEAR*0.5 < o.y: return true
	return false

## What is under a trap's slabs: "layer" if any isle is under its middle
## half, else "void".
static func _under(edge: Dictionary, isles: Array) -> String:
	var path: Array = edge.path
	for i in range(path.size()/4,path.size()*3/4):
		var p: Vector3 = path[i][0]
		for isle: Dictionary in isles:
			if occ_at(isle,p.x,p.z).y < p.y-2.0: return "layer"
	return "void"

# --- The greed branch's cannon, the ram ---------------------------------------------

## A cannon behind the greed branch's rim whose shot (at some power and
## pitch, aimed at the greed isle) lands SHOT_IN past its rim, its arc
## clear of every isle; kegs beside it to range it. None if no shot lands.
static func _cannon(plan: Dictionary, edge: Dictionary, _rng: RandomNumberGenerator) -> void:
	var rim: Dictionary = edge.from_rim
	# Further back along the run-up, further in past the far rim, till a
	# shot lands clear.
	for back: float in [CANNON_BACK,CANNON_BACK+1.5,CANNON_BACK+3.0,CANNON_BACK+5.0]:
		if back > float(rim.run_up)-0.5 and back > CANNON_BACK: break
		for inland: float in [SHOT_IN,SHOT_IN+2.0,SHOT_IN+4.0]:
			if _cannon_at(plan,edge,back,inland): return

## The layer's cannon: the cannon's own knobs but its launch a little
## faster (CANNON_RUNS of the pilot's run at full power, the cannon's own
## 5.4), so a shot carries a greed gap tens of metres wide.
const CANNON_RUNS := 6.6
static func cannon_knobs() -> Dictionary:
	var k := Cannon.defaults()
	k.speed_max = pilot().run*CANNON_RUNS
	return k

## Where a shot from the layer's cannon at `base` comes down on flat ground
## at `floor_y` (the cannon's `landing_for`, at its knobs).
static func _shot(base: Vector3, yaw: float, pitch: float, notch: int, floor_y: float, speed := 0.0) -> Vector3:
	var k := cannon_knobs()
	if speed > 0.0: k.speed_max = speed
	var f := PilotMotor.forward(yaw)
	var dir := Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))
	var from: Vector3 = base+Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
	return Cannon.landing(from,dir*float(k.speed_max)*float(k.power_notches[notch]),floor_y)

static func _cannon_at(plan: Dictionary, edge: Dictionary, back: float, inland: float) -> bool:
	var c := _aim(plan,edge,back,inland,float(cannon_knobs().speed_max))
	if c.is_empty(): return false
	plan.cannon = c
	return true

## A cannon `back` behind the edge's rim at launch `speed`, its shot landing
## `inland` past the far rim at some notch and pitch, its arc clear: {at,
## heading, pitch, notch, speed, target, landing, kegs}, or {}.
static func _aim(plan: Dictionary, edge: Dictionary, back: float, inland: float, speed: float, aside := 0.0) -> Dictionary:
	var rim: Dictionary = edge.from_rim
	var to: Dictionary = edge.to_rim
	var face: Vector3 = rim.face
	var across := face.cross(Vector3.UP).normalized()
	var base: Vector3 = (rim.at as Vector3)-face*back+across*aside
	var target: Vector3 = (to.at as Vector3)-(to.face as Vector3)*inland
	var flat := Vector2(target.x-base.x,target.z-base.z)
	var yaw := atan2(-flat.x,-flat.y)
	var k := cannon_knobs()
	for notch in range((k.power_notches as Array).size()):
		var lo := float(k.pitch_min)
		var hi := deg_to_rad(45.0)
		# The low arc: further as it pitches up to 45 degrees.
		var far := _shot(base,yaw,hi,notch,target.y,speed)
		var near := _shot(base,yaw,lo,notch,target.y,speed)
		var want := flat.length()
		if Vector2(far.x-base.x,far.z-base.z).length() < want or Vector2(near.x-base.x,near.z-base.z).length() > want: continue
		for i in range(30):
			var mid := (lo+hi)*0.5
			var land := _shot(base,yaw,mid,notch,target.y,speed)
			if Vector2(land.x-base.x,land.z-base.z).length() < want: lo = mid
			else: hi = mid
		var pitch := (lo+hi)*0.5
		var landing := _shot(base,yaw,pitch,notch,target.y,speed)
		if Vector2(landing.x-target.x,landing.z-target.z).length() > SHOT_NEAR: continue
		if not _arc_clear(plan,base,yaw,pitch,notch,target,edge,back,inland,speed): continue
		var side := face.cross(Vector3.UP).normalized()
		var keg_at := (rim.at as Vector3)-face*0.6
		var kegs := [keg_at+side*1.4+Vector3.UP*0.05,keg_at-side*1.4+Vector3.UP*0.05,base+face*1.2+side*1.6+Vector3.UP*0.05]
		# Stood aside (off a pier's line): its kegs on its far side.
		if aside != 0.0:
			var out := across*signf(aside)
			kegs = [base+out*1.8+face*0.7+Vector3.UP*0.05,base+out*1.8-face*0.7+Vector3.UP*0.05,base+out*3.0+Vector3.UP*0.05]
		return {"at":base,"heading":yaw,"pitch":pitch,"notch":notch,"speed":speed,"target":target,"landing":landing,"kegs":kegs}
	return {}

## The shot's arc clear of every isle (but the two it leaves and lands on
## near its ends).
static func _arc_clear(plan: Dictionary, base: Vector3, yaw: float, pitch: float, notch: int, target: Vector3, edge: Dictionary, back: float, inland: float, speed := 0.0) -> bool:
	var k := cannon_knobs()
	if speed > 0.0: k.speed_max = speed
	var f := PilotMotor.forward(yaw)
	var dir := Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))
	var from: Vector3 = base+Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
	var pts := Cannon.flight(from,dir*float(k.speed_max)*float(k.power_notches[notch]),pilot(),1.0/60.0,30.0,target.y)
	var a: int = edge.from[0]
	var b: int = edge.to[0]
	for p: Vector3 in pts:
		for i in range(plan.isles.size()):
			if i == a and Vector2(p.x-base.x,p.z-base.z).length() < back+OWN_NEAR: continue
			if i == b and Vector2(p.x-target.x,p.z-target.z).length() < inland+OWN_NEAR: continue
			var o := occ_at(plan.isles[i],p.x,p.z)
			if o.x < INF and o.x < p.y+1.5 and p.y-1.0 < o.y: return false
	return true

## The Plinth Ram on the roomiest arena of a route isle past the base, clear
## of every rim used.
static func _ram(plan: Dictionary, used: Dictionary) -> void:
	var best := {}
	for i in range(1,plan.isles.size()):
		var isle: Dictionary = plan.isles[i]
		if isle.role != "route": continue
		for s: Dictionary in isle.sockets:
			if s.kind != "arena" or float(s.room) < RAM_ROOM: continue
			var clear := true
			for r: Dictionary in isle.sockets:
				if r.kind == "rim" and used.has(_key(i,r.name)) and (r.at as Vector3).distance_to(s.at) < RAM_CLEAR: clear = false
			if clear and (best.is_empty() or float(s.room) > float(best.room)):
				best = s.duplicate()
				best.isle = i
	if not best.is_empty(): plan.ram = {"isle":best.isle,"at":best.at,"face":best.face,"room":best.room}

# --- Neighbourhoods and gulfs (round 3) ---------------------------------------------

## The next neighbourhood's first isle `m` stood across a gulf `width` m
## wide (rim lip to rim lip, flat) off a rim of neighbourhood `hood_from`,
## rising GULF_RISE, the honest `ride` across it laid (a serpent's loop past
## a boarding ledge at each rim, or the ferry's between the two) and its
## tube kept clear of every isle; the sight line from rim to rim clear. The
## gulf edge appended, `m` placed in neighbourhood `hood_to`; {} if none
## fits.
static func _gulf(plan: Dictionary, hood_from: int, m: Dictionary, hood_to: int, width: float, ride: String, pinned: bool, used: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var began := Time.get_ticks_msec()
	var ins: Array = ins_of(m.own.filter(func(s: Dictionary) -> bool: return s.kind == "rim" and float(s.run_up) >= GULF_RUN_UP),plan.knobs)
	if ins.any(func(s: Dictionary) -> bool: return s.name == "entry"): ins = ins.filter(func(s: Dictionary) -> bool: return s.name == "entry")
	var combos: Array = []
	for i: int in plan.hoods[hood_from]:
		var a: Dictionary = plan.isles[i]
		for ra: Dictionary in a.own:
			if ra.kind != "rim" or used.has(_key(i,ra.name)) or float(ra.run_up) < GULF_RUN_UP or not can_out(ra,plan.knobs): continue
			for rb: Dictionary in ins:
				if (ra.face as Vector3).dot(-(rb.face as Vector3)) < cos(deg_to_rad(GULF_TURN*2.0)): continue
				combos.append([i,ra,rb])
	_shuffle(combos,rng)
	var why := {}
	var fits: Array = []
	for c: Array in combos:
		var from: int = c[0]
		var a: Dictionary = plan.isles[from]
		var ra: Dictionary = c[1]
		var rb: Dictionary = c[2]
		var fa: Vector3 = ra.face
		var fb: Vector3 = rb.face
		var dir := (fa-fb).normalized()
		if dir.dot(fa) < cos(deg_to_rad(GULF_TURN)) or dir.dot(-fb) < cos(deg_to_rad(GULF_TURN)): continue
		var lip_a: Vector3 = (ra.at as Vector3)+(a.offset as Vector3)+fa*float(ra.lip)
		var rise := _rise(plan,width,rng)
		var lip_b := lip_a+dir*width+Vector3.UP*rise
		var off_b: Vector3 = lip_b-fb*float(rb.lip)-(rb.at as Vector3)
		var placed := m.duplicate()
		placed.offset = off_b
		placed.hood = hood_to
		var mid := _rect(placed).get_center()
		if mid.distance_to(Vector2(MIDDLE.x,MIDDLE.z)) > band(plan.knobs).x:
			why.band = why.get("band",0)+1
			continue
		if plan.isles.any(func(o: Dictionary) -> bool: return clash(o,placed)):
			why.clash = why.get("clash",0)+1
			continue
		if not _apart(plan,placed):
			why.apart = why.get("apart",0)+1
			continue
		var edge := {"kind":"gulf","branch":"route","from":[from,ra.name],"to":[plan.isles.size(),rb.name],"a":lip_a,"b":lip_b,"dir":dir,
			"stones":[],"bridges":[],"parts":["gulf %.0f m" % width,ride],"trap":{},"path":_line(lip_a,lip_b,GULF_UNDER,2.0),
			"from_rim":_world(ra,a.offset),"to_rim":_world(rb,off_b),"width":width,"rise":rise,"ride":ride,
			"sight":[(ra.at as Vector3)+(a.offset as Vector3)+Vector3.UP*EYE,(rb.at as Vector3)+off_b+Vector3.UP*EYE]}
		var isles: Array = plan.isles+[placed]
		if not _corridor_clear(edge,isles,from,isles.size()-1):
			why.corridor = why.get("corridor",0)+1
			continue
		if _crosses(edge,plan.edges):
			why.crosses = why.get("crosses",0)+1
			continue
		if _isle_in_tubes(placed,plan.tubes):
			why.tubes = why.get("tubes",0)+1
			continue
		# The best: off a high rim (seen from far), near the base.
		var score := rng.randf()*2.0+0.08*lip_a.y-0.004*mid.distance_to(Vector2(MIDDLE.x,MIDDLE.z))+_lean(plan,mid)
		score += way_score(ra,rb,plan.knobs)
		fits.append([score,edge,placed])
	fits.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) > float(q[0]))
	# The ride's loop, the best first, till one stands clear of every isle.
	# The ride asked for first; unless pinned, the other where it won't go.
	var rides: Array = [ride]
	if not pinned: rides.append(RIDES[(RIDES.find(ride)+1)%RIDES.size()])
	var best := {}
	for want: String in rides:
		for f: Array in fits.slice(0,GULF_RIDES_TRIED):
			var edge: Dictionary = f[1]
			var placed: Dictionary = f[2]
			var isles: Array = plan.isles+[placed]
			var loop := _serpent_loop(edge,isles,rng) if want == "serpent" else _ferry_loop(edge,isles,rng)
			if loop.is_empty():
				why.ride = why.get("ride",0)+1
				if trace: print("  %s: %s" % [want,_ride_why])
				continue
			edge.ride = want
			edge.parts = ["gulf %.0f m" % width,want]
			edge[want] = loop
			best = {"edge":edge,"isle":placed,"tube":loop.tube}
			break
		if not best.is_empty(): break
	if trace: print("layer plan: gulf %d -> %s %.0f m %s, %d fits, %d ms %s" % [hood_from,m.id,width,ride,fits.size(),Time.get_ticks_msec()-began,why])
	if best.is_empty(): return {}
	var placed_isle: Dictionary = best.isle
	placed_isle.sockets = []
	for s: Dictionary in placed_isle.own: placed_isle.sockets.append(_world(s,placed_isle.offset))
	plan.isles.append(placed_isle)
	var e: Dictionary = best.edge
	plan.gulfs.append(plan.edges.size())
	plan.edges.append(e)
	plan.tubes.append_array(best.tube)
	used[_key(int(e.from[0]),e.from[1])] = true
	used[_key(int(e.to[0]),e.to[1])] = true
	return e

## A lean to one side (the sprawl shape's exit side, scripts/roguelike/
## layer_sprawl.gd): the knob `lean`, a flat heading as long as its weight,
## gives points per 100 m stood that way off MIDDLE. None without it.
static func _lean(plan: Dictionary, mid: Vector2) -> float:
	var lean: Variant = (plan.knobs as Dictionary).get("lean")
	if not lean is Vector2: return 0.0
	return (mid-Vector2(MIDDLE.x,MIDDLE.z)).dot(lean)/100.0

## A gulf's rise rim to rim: the `rise` knob, else rolled in GULF_RISE (or
## the knob `rise_roll`), at most GULF_GRADE of its width.
const GULF_GRADE := 0.3
static func _rise(plan: Dictionary, width: float, rng: RandomNumberGenerator) -> float:
	var k: Dictionary = plan.knobs
	if float(k.get("rise",0.0)) > 0.0: return minf(float(k.rise),width*GULF_GRADE)
	var roll: Vector2 = k.get("rise_roll",GULF_RISE)
	return minf(rng.randf_range(roll.x,roll.y),width*GULF_GRADE)

## Whether `isle` keeps HOOD_APART (flat, rect to rect) from every isle of
## another neighbourhood: the gulfs stay open sky.
static func _apart(plan: Dictionary, isle: Dictionary) -> bool:
	var r := _rect(isle)
	for o: Dictionary in plan.isles:
		if int(o.get("hood",0)) == int(isle.hood): continue
		var q := _rect(o)
		var dx := maxf(maxf(q.position.x-r.end.x,r.position.x-q.end.x),0.0)
		var dz := maxf(maxf(q.position.y-r.end.y,r.position.y-q.end.y),0.0)
		if Vector2(dx,dz).length() >= HOOD_APART: continue
		# Their rects near: their solid cells (coarse) to each other.
		if _near_cells(isle,o,HOOD_APART): return false
	return true

## The centres of `isle`'s coarse occupied cells (world, flat).
static func _cells(isle: Dictionary) -> PackedVector2Array:
	var c := _coarse(isle.occ)
	var off: Vector3 = isle.offset
	var out := PackedVector2Array()
	var lo: PackedFloat32Array = c.lo
	for k in range(lo.size()):
		if lo[k] == INF: continue
		out.append((c.origin as Vector2)+Vector2(off.x,off.z)+Vector2(k%int(c.cols)+0.5,k/int(c.cols)+0.5)*float(c.cell))
	return out

## Whether any solid of `a` stands within `d` (flat) of `b`'s (coarse cells,
## less a cell's half diagonal each).
static func _near_cells(a: Dictionary, b: Dictionary, d: float) -> bool:
	var ca := _cells(a)
	var cb := _cells(b)
	var reach := d+float(_coarse(a.occ).cell)*0.71+float(_coarse(b.occ).cell)*0.71
	var rb := _rect(b).grow(reach)
	for p: Vector2 in ca:
		if not rb.has_point(p): continue
		for q: Vector2 in cb:
			if p.distance_squared_to(q) < reach*reach-2.0*float(_coarse(a.occ).cell)*reach: return true
	return false

## Whether any of `isle`'s solid stands within a tube sample ([point,
## radius]) of a ride laid before.
static func _isle_in_tubes(isle: Dictionary, tubes: Array) -> bool:
	if tubes.is_empty(): return false
	var r := _rect(isle)
	if not r.intersects(_tubes_rect(tubes)): return false
	var span := _span(isle)
	for t: Array in tubes:
		var p: Vector3 = t[0]
		var rad: float = t[1]
		if p.x < r.position.x-rad or p.x > r.end.x+rad or p.z < r.position.y-rad or p.z > r.end.y+rad: continue
		if p.y+rad < span.x or p.y-rad > span.y: continue
		if _column_hit(isle,p,rad): return true
	return false

## The flat rect round every tube sample's reach (kept on the list's last
## sample's third entry, made again when the list grows).
static func _tubes_rect(tubes: Array) -> Rect2:
	var last: Array = tubes[tubes.size()-1]
	if last.size() > 2: return last[2]
	var r := Rect2((tubes[0][0] as Vector3).x,(tubes[0][0] as Vector3).z,0.0,0.0)
	for t: Array in tubes:
		var p: Vector3 = t[0]
		r = r.merge(Rect2(p.x-float(t[1]),p.z-float(t[1]),2.0*float(t[1]),2.0*float(t[1])))
	last.append(r)
	return r

## Whether any occupied cell column of `isle` comes within `rad` of `p`.
static func _column_hit(isle: Dictionary, p: Vector3, rad: float) -> bool:
	var o: Dictionary = isle.occ
	var off: Vector3 = isle.offset
	var cell: float = o.cell
	var x := p.x-rad
	while x <= p.x+rad:
		var z := p.z-rad
		while z <= p.z+rad:
			var flat := Vector2(x-p.x,z-p.z).length()
			if flat <= rad:
				var h := occ_at(isle,x,z)
				if h.x < INF:
					var gap := maxf(maxf(h.x-p.y,p.y-h.y),0.0)
					if flat*flat+gap*gap < rad*rad: return true
			z += cell
		x += cell
	return false

## Whether the samples ([point, radius]) are clear of every isle in
## `isles`, but each of `exempt` ([isle index, point, radius]) within its radius
## (m, flat) of its point: the rim probe keeps the air off a rim clear.
static func _tube_clear(samples: Array, isles: Array, exempt: Array) -> bool:
	for i in range(isles.size()):
		var isle: Dictionary = isles[i]
		var r := _rect(isle)
		var span := _span(isle)
		for t: Array in samples:
			var p: Vector3 = t[0]
			var rad: float = t[1]
			if p.x < r.position.x-rad or p.x > r.end.x+rad or p.z < r.position.y-rad or p.z > r.end.y+rad: continue
			if p.y+rad < span.x or p.y-rad > span.y: continue
			var skip := false
			for ex: Array in exempt:
				if int(ex[0]) == i and Vector2(p.x-(ex[1] as Vector3).x,p.z-(ex[1] as Vector3).z).length() < float(ex[2]): skip = true
			if skip: continue
			if _column_hit(isle,p,rad):
				if trace: _ride_why = "%s at %s (r %.1f)" % [isle.id,p.round(),rad]
				return false
	return true

static var _ride_why := ""

## A gulf's flat frame: u across it (a to b), v to one side.
static func _gulf_frame(e: Dictionary) -> Array:
	var d: Vector3 = (e.b as Vector3)-(e.a as Vector3)
	var u := Vector3(d.x,0.0,d.z).normalized()
	return [u,Vector3(-u.z,0.0,u.x)]

## The rune serpent's way round a gulf (scripts/kit_isle/serpent_route.gd's
## grammar): straight and level past a boarding pier at each rim (three
## control points in a line along the rim's edge, the slither held in,
## three quarters pace), in and out of it at 45 degrees off open sky, a
## lane out over the gulf on one side and back on the other. Each pier's
## end LEDGE_JUT m past its rim's lip and its top LEDGE_RISE m over the rim
## (as the route lays its ledges off its way: the way passes its flank,
## slither and gap further out, its crest's height under the ledge's top;
## its heave there taken out). {points, marks, start, spots, tube, length}
## or {} when its tube meets an isle.
static func _serpent_loop(e: Dictionary, isles: Array, rng: RandomNumberGenerator) -> Dictionary:
	var v: Vector3 = _gulf_frame(e)[1]
	var shape := _serpent_shape()
	var out: float = shape.flank+shape.weave*LEDGE_WEAVE+SerpentRoute.LEDGE_GAP+LEDGE_JUT
	var ends: Array = []
	for rim: Dictionary in [e.from_rim,e.to_rim]:
		var f: Vector3 = rim.face
		var f2 := Vector3(f.x,0.0,f.z).normalized()
		var lip: Vector3 = (rim.at as Vector3)+f*float(rim.lip)
		var p := Vector3(lip.x,(rim.at as Vector3).y+LEDGE_RISE-shape.crest+SerpentRoute.LEDGE_DROP,lip.z)+f2*out
		ends.append([p,f2])
	for side: float in ([1.0,-1.0] if rng.randf() < 0.5 else [-1.0,1.0]):
		var sv := v*side
		var pa: Vector3 = ends[0][0]
		var fa: Vector3 = ends[0][1]
		var pb: Vector3 = ends[1][0]
		var fb: Vector3 = ends[1][1]
		var ea := Vector3(fa.z,0.0,-fa.x)
		if ea.dot(sv) < 0.0: ea = -ea
		var eb := Vector3(fb.z,0.0,-fb.x)
		if eb.dot(sv) > 0.0: eb = -eb
		# By each pier three points in a line along its rim's edge (the way
		# straight past it), out from it at 45 degrees either side, so it
		# comes in off open sky and leaves into it.
		var run := SERPENT_RUN
		var lane := SERPENT_LANE
		var d := Vector2(pb.x-pa.x,pb.z-pa.z).length()
		var t0 := clampf(SERPENT_LANE_IN/d,0.15,0.4)
		var pts: Array = []
		var marks := {}
		var held := func(p: Vector3) -> Array: return [p,LEDGE_WEAVE,0.75,0.0]
		var free := func(p: Vector3, w: float) -> Array: return [p,w,1.0,0.0]
		for k in range(-1,2): pts.append(held.call(pa+ea*run*k))
		marks.a = 1
		pts.append(free.call(pa+(ea+fa)*run*SERPENT_OUT,0.4))
		for p: Vector3 in _lane(pa,pb,sv*lane,t0): pts.append(free.call(p,1.0))
		pts.append(free.call(pb+(-eb+fb)*run*SERPENT_OUT,0.4))
		marks.b = pts.size()+1
		for k in range(-1,2): pts.append(held.call(pb+eb*run*k))
		pts.append(free.call(pb+(eb+fb)*run*SERPENT_OUT,0.4))
		var back := _lane(pb,pa,-sv*lane,t0)
		marks.back = pts.size()+int(back.size()/2.0)
		for p: Vector3 in back: pts.append(free.call(p,1.0))
		pts.append(free.call(pa+(-ea+fa)*run*SERPENT_OUT,0.4))
		# Its heave by each pier taken out of the way there, so the pier's top
		# stands LEDGE_RISE over its rim (twice: the arcs move a little).
		var tube := _serpent_tube(pts,marks)
		var level := {"a":pa.y,"b":pb.y}
		for again in range(2):
			for mark: String in ["a","b"]:
				var y: float = float(level[mark])-float(tube.heave[mark])
				for i in range(int(marks[mark])-1,int(marks[mark])+2): pts[i][0] = Vector3((pts[i][0] as Vector3).x,y,(pts[i][0] as Vector3).z)
			tube = _serpent_tube(pts,marks)
		var exempt := [[int(e.from[0]),pa,EXEMPT_LEDGE],[int(e.to[0]),pb,EXEMPT_LEDGE]]
		if not _tube_clear(tube.samples,isles,exempt): continue
		# The ledges stand on the isle's side of the way.
		var spots: Array = []
		for k in range(2):
			var way: Vector3 = ea if k == 0 else eb
			var f: Vector3 = ends[k][1]
			var right := Vector2(-way.z,way.x)
			spots.append({"name":"ab"[k],"isle":int(e.from[0] if k == 0 else e.to[0]),"side":1.0 if Vector2(-f.x,-f.z).dot(right) > 0.0 else -1.0})
		return {"points":pts,"marks":marks,"start":"back","spots":spots,"tube":tube.samples,"length":tube.length}
	return {}

## The lane's points from `a` to `b` stood `off` to the side, from t0 to
## 1 - t0 of the way, about every SERPENT_LANE_STEP m.
static func _lane(a: Vector3, b: Vector3, off: Vector3, t0: float) -> Array:
	var d := Vector2(b.x-a.x,b.z-a.z).length()*(1.0-2.0*t0)
	var n := maxi(int(ceil(d/SERPENT_LANE_STEP)),1)
	var out: Array = []
	for i in range(n+1):
		var t := lerpf(t0,1.0-t0,float(i)/n)
		out.append(a.lerp(b,t)+off+Vector3.UP*LANE_LIFT*sin(PI*t))
	return out

## The serpent's girth numbers, from one never set up (its stations laid).
static var _girth := {}
static func _serpent_shape() -> Dictionary:
	if _girth.is_empty():
		var s: Node3D = RuneSerpent.new()
		s.girth = SerpentRoute.GIRTH
		s._stations()
		_girth = {"flank":SerpentRoute.flank_of(s),"crest":SerpentRoute.crest_of(s),"weave":RuneSerpent.WAVE*tan(RuneSerpent.WEAVE)/TAU}
		s.free()
	return _girth

## A serpent's way through `points` as its own (RuneSerpent `_build_route`),
## sampled every TUBE_STEP m: {samples ([point, its reach there]), length}.
static func _serpent_tube(points: Array, marks: Dictionary) -> Dictionary:
	var s: Node3D = RuneSerpent.new()
	s.route = points
	s.route_marks = marks
	s.girth = SerpentRoute.GIRTH
	s._build_route()
	var samples: Array = []
	var at := 0.0
	while at < s.route_length:
		samples.append([s.route_point(at),float(s.reach_at(at))+TUBE_MARGIN])
		at += TUBE_STEP
	var length: float = s.route_length
	# Its heave by each mark (serpent_route.gd `pass_point`'s), the way
	# being level there.
	var heave := {}
	for mark: String in marks: heave[mark] = s.heave_reach()*sin(TAU*float(s._marks.get(mark,0.0))/s._heave_wave+1.3)
	s.free()
	return {"samples":samples,"length":length,"heave":heave}

## The ferry's loop over a gulf (scripts/kit_isle/airship_ferry.gd's
## grammar): it rests at a pier off each rim (LEDGE_JUT m out, its top
## FERRY_RISE over the rim) square to the rim's edge, its deck level with
## the pier's top and its side a hand off the pier's end, coming in and
## leaving at 45 degrees off open sky; out on one side of the gulf and back
## on the other, a little higher between. {route ([point, stop, side]),
## tube, piers} or {}.
static func _ferry_loop(e: Dictionary, isles: Array, rng: RandomNumberGenerator) -> Dictionary:
	var v: Vector3 = _gulf_frame(e)[1]
	var half := AirshipBuild.HULL.x*Ferry.SCALE
	var stops: Array = []
	var piers: Array = []
	for rim: Dictionary in [e.from_rim,e.to_rim]:
		var f: Vector3 = rim.face
		var f2 := Vector3(f.x,0.0,f.z).normalized()
		var lip: Vector3 = (rim.at as Vector3)+f*float(rim.lip)
		var top := (rim.at as Vector3).y+FERRY_RISE
		var end := Vector3(lip.x,top,lip.z)+f2*LEDGE_JUT
		piers.append({"end":end,"top":top,"toward":Vector2(f2.x,f2.z)})
		stops.append([Vector3(end.x,top-Ferry.DECK,end.z)+f2*(half+FERRY_OFF),f2])
	var high := maxf((stops[0][0] as Vector3).y,(stops[1][0] as Vector3).y)+FERRY_LIFT
	# Over a tall gulf (the `rise` knobs) it climbs across, FERRY_LIFT over
	# the straight way between its stops, not level at the higher's.
	var steep := absf((stops[0][0] as Vector3).y-(stops[1][0] as Vector3).y) > GULF_RISE.y+2.0
	var high_a := (stops[0][0] as Vector3).y+FERRY_LIFT if steep else high
	var high_b := (stops[1][0] as Vector3).y+FERRY_LIFT if steep else high
	var lane_y := func(q: Vector3) -> float: return q.y+FERRY_LIFT if steep else high
	for side: float in ([1.0,-1.0] if rng.randf() < 0.5 else [-1.0,1.0]):
		var sv := v*side
		var oa: Vector3 = stops[0][0]
		var fa: Vector3 = stops[0][1]
		var ob: Vector3 = stops[1][0]
		var fb: Vector3 = stops[1][1]
		var ea := Vector3(fa.z,0.0,-fa.x)
		if ea.dot(sv) < 0.0: ea = -ea
		var eb := Vector3(fb.z,0.0,-fb.x)
		if eb.dot(sv) > 0.0: eb = -eb
		# Its foredeck (FOREDECK, toward the bow) by the pier's middle.
		oa -= ea*Ferry.FOREDECK.z
		ob -= eb*Ferry.FOREDECK.z
		var route: Array = []
		var lift := func(p: Vector3, y: float) -> Vector3: return Vector3(p.x,y,p.z)
		# Into each stop and out of it at 45 degrees off open sky, square to
		# the rim's edge at the stop.
		route.append([oa+(-ea+fa)*FERRY_ALONG,""])
		route.append([oa,"a",_ferry_side(ea,fa)])
		route.append([oa+(ea+fa)*FERRY_ALONG,""])
		route.append([lift.call(oa+(ea+fa)*FERRY_CORNER,lerpf(oa.y,high_a,0.5)),""])
		for p: Vector3 in _lane(oa,ob,sv*FERRY_LANE,0.3): route.append([lift.call(p,lane_y.call(p)),""])
		route.append([lift.call(ob+(-eb+fb)*FERRY_CORNER,lerpf(ob.y,high_b,0.5)),""])
		route.append([ob+(-eb+fb)*FERRY_ALONG,""])
		route.append([ob,"b",_ferry_side(eb,fb)])
		route.append([ob+(eb+fb)*FERRY_ALONG,""])
		route.append([lift.call(ob+(eb+fb)*FERRY_CORNER,lerpf(ob.y,high_b,0.5)),""])
		for p: Vector3 in _lane(ob,oa,-sv*FERRY_LANE,0.3): route.append([lift.call(p,lane_y.call(p)),""])
		route.append([lift.call(oa+(-ea+fa)*FERRY_CORNER,lerpf(oa.y,high_a,0.5)),""])
		# Its hull and its envelope along the loop.
		var hull: Array = []
		var envelope: Array = []
		var around := 0.0
		for i in range(route.size()): around += (route[i][0] as Vector3).distance_to(route[(i+1)%route.size()][0])
		var n := maxi(int(around/TUBE_STEP),route.size()*4)
		for i in range(n):
			var p := Ferry.spline_of(route,float(i)/n)
			hull.append([p+Vector3.UP*FERRY_HULL.y,FERRY_HULL.x])
			envelope.append([p+Vector3.UP*FERRY_ENVELOPE.y,FERRY_ENVELOPE.x])
		var exempt := [[int(e.from[0]),oa,EXEMPT_STOP],[int(e.to[0]),ob,EXEMPT_STOP]]
		if not _tube_clear(hull,isles,exempt) or not _tube_clear(envelope,isles,[]): continue
		var named: Array = []
		for k in range(2):
			var pier: Dictionary = piers[k].duplicate()
			pier.id = "ferry_%s" % "ab"[k]
			pier.isle = int(e.from[0] if k == 0 else e.to[0])
			named.append(pier)
		return {"route":route,"tube":hull+envelope,"piers":named}
	return {}

## The isle's side of a ferry resting heading `way` at a rim facing `face`:
## +1 starboard (its +X, the bow's right), -1 port.
static func _ferry_side(way: Vector3, face: Vector3) -> float:
	var starboard := way.cross(Vector3.UP)
	return 1.0 if starboard.dot(-face) > 0.0 else -1.0

## A cannon behind a gulf's near rim, its shot landing on the far
## neighbourhood's rim isle (faster than the greed branch's: the least
## speed whose top notch carries the gulf with room), its arc clear.
static func _gulf_cannon(plan: Dictionary, edge: Dictionary) -> Dictionary:
	var rim: Dictionary = edge.from_rim
	var to: Dictionary = edge.to_rim
	var want := Vector2((to.at as Vector3).x-(rim.at as Vector3).x,(to.at as Vector3).z-(rim.at as Vector3).z).length()+CANNON_BACK+SHOT_IN+4.0
	var speed := pilot().run*CANNON_RUNS
	var k := cannon_knobs()
	while speed < pilot().run*GULF_CANNON_RUNS:
		var f := Vector3(0.0,sin(deg_to_rad(45.0)),-cos(deg_to_rad(45.0)))
		var land := Cannon.landing(Vector3.ZERO,f*speed,(to.at as Vector3).y-(rim.at as Vector3).y-float(k.base_height))
		if -land.z > want*1.08: break
		speed += pilot().run*0.25
	# It lands past the far pier's back and its steps (PIER_OVER and a
	# flight), on ground near the rim's level.
	# It stands aside of the near pier's line (its flight and back), on
	# ground at the rim's level, its kegs further aside.
	var far: Dictionary = plan.isles[int(edge.to[0])]
	var near: Dictionary = plan.isles[int(edge.from[0])]
	var face: Vector3 = rim.face
	var across := face.cross(Vector3.UP).normalized()
	for aside: float in (GULF_CANNON_ASIDE if edge.ride == "serpent" else FERRY_CANNON_ASIDE):
		for back: float in [CANNON_BACK,CANNON_BACK+1.5,CANNON_BACK+3.0]:
			var base: Vector3 = (rim.at as Vector3)-face*back+across*aside
			var ok := true
			for step: float in [0.0,1.8,3.0]:
				var p := base+across*signf(aside)*step
				var under := occ_at(near,p.x,p.z)
				if under.x == INF or absf(under.y-base.y) > 1.0: ok = false
			if not ok: continue
			for inland: float in GULF_SHOT_IN:
				var target: Vector3 = (to.at as Vector3)-(to.face as Vector3)*inland
				var under := occ_at(far,target.x,target.z)
				if under.x == INF or absf(under.y-target.y) > 1.5: continue
				var c := _aim(plan,edge,back,inland,speed,aside)
				if not c.is_empty(): return c
	return {}

# --- Reading it -----------------------------------------------------------------------

## One line per isle and edge, for the card and the log.
static func describe(plan: Dictionary) -> String:
	var lines := PackedStringArray()
	for i in range(plan.isles.size()):
		var isle: Dictionary = plan.isles[i]
		var knobs := ""
		if not (isle.knobs as Dictionary).is_empty(): knobs = " seed %d %s" % [int(isle.seed),str(isle.knobs)]
		var over := "" if i == 0 else ", %d%% over another" % roundi(over_share(plan,isle)*100.0)
		lines.append("%d %s (%s, hood %d)%s at %s%s" % [i,isle.id,isle.role,int(isle.get("hood",0)),knobs,str((isle.offset as Vector3).round()),over])
	for e: Dictionary in plan.edges:
		var extra := ": "+", ".join(PackedStringArray(e.parts))
		if not (e.trap as Dictionary).is_empty(): extra += " over the %s" % str(e.trap.under)
		if e.kind == "gulf":
			var ride: Dictionary = e[e.ride]
			if e.ride == "serpent": extra += " (its loop %.0f m)" % float(ride.length)
			if not (e.get("cannon",{}) as Dictionary).is_empty(): extra += ", a cannon (%.1f runs, notch %d, pitch %.0f deg)" % [float(e.cannon.speed)/pilot().run,int(e.cannon.notch)+1,rad_to_deg(float(e.cannon.pitch))]
		lines.append("%s %s: %d.%s -> %d.%s, %.1f m, rise %.1f m%s" % [e.branch,e.kind,int(e.from[0]),str(e.from[1]),int(e.to[0]),str(e.to[1]),
			Vector2((e.b as Vector3).x-(e.a as Vector3).x,(e.b as Vector3).z-(e.a as Vector3).z).length(),(e.b as Vector3).y-(e.a as Vector3).y,extra])
	if not (plan.cannon as Dictionary).is_empty(): lines.append("cannon: notch %d pitch %.0f deg" % [int(plan.cannon.notch)+1,rad_to_deg(float(plan.cannon.pitch))])
	if not (plan.ram as Dictionary).is_empty(): lines.append("ram on %d" % int(plan.ram.isle))
	lines.append("hoods %s" % str(plan.get("hoods",[])))
	lines.append("world %s, region %d" % [LayerWorlds.of(plan),LayerWorlds.region_of(plan)])
	if not (plan.problems as Array).is_empty(): lines.append("problems: %s" % str(plan.problems))
	return "\n".join(lines)

static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap
