extends RefCounted
## A layer's plan as plain data: which isles stand where, the edges
## joining them, what is on them. The motif yard and editor
## (studies/motif_yard.gd `yard_plan`) make a one-isle plan for the motif
## they stand; LayerStage, LayerGreybox, LayerEnemies and LayerBodies read
## it. Here: the pool of motif isles (POOL), an isle record from a pick
## (`_motif_isle`) with its occupancy (scripts/roguelike/layer_pieces.gd:
## per 2 m cell its lowest and highest solid; a rolled broken ring its
## footprint's box), the pilot's reach the pieces are sized by, the knobs.
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const LayerPieces = preload("res://scripts/roguelike/layer_pieces.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
## The run's worlds, under and sky (scripts/roguelike/layer_worlds.gd): a
## region draws only its own world's motifs.
const LayerWorlds = preload("res://scripts/roguelike/layer_worlds.gd")
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
const BASE := "aqueduct_isle"
## The aqueduct isle's middle (world), what the layer keeps round.
const MIDDLE := Vector3(85.0,30.0,-20.0)
## Clear between two isles where one stands over the other (m), and round
## an edge's corridor.
const CLEAR := 4.0
## The layer keeps within this of MIDDLE (m, flat); a neighbourhood's
## isles within HOOD_BAND of its first.
const BAND := 520.0
const RAM_CLEAR := 8.0
## The serpent's loop: a ledge's end past its rim's lip and its top over
## the rim (m), the slither's share by a ledge (serpent_route.gd's held
## 0.1); the straight run past a ledge (control points apart, m), the
## corners' reach, the lanes' offset to the side, where they start in from
## each end (m), their points' spacing and their rise mid-gulf.
const LEDGE_JUT := 7.0
## A ride's boarding place is a pier (serpent_route.gd's ledge, longer):
## its end LEDGE_JUT m past the lip, its back PIER_OVER m in over the turf;
## the ferry's top FERRY_RISE m over the rim (its deck level with it).
const PIER_OVER := 1.5

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

## A stepping stone's length along the way and its width: a share of his
## walk's second (the ring's stones, 1.5-1.7 m at his size); `hard`
## smaller.
static func stone_length(hard := false) -> float:
	return pilot().walk*(0.45 if hard else 0.7)

## A stride's gap as a share of his small jump's reach at its rise.
const GAP_SHARE := Vector2(0.72,0.84)

# --- The knobs -----------------------------------------------------------------------

## The layer's knobs (`--knob=key=value`): `arrows` / `viaduct` the
## hazards (scripts/roguelike/layer_hazards.gd), -1 rolled; `heads` the
## inhaler heads (scripts/roguelike/layer_enemies.gd), -1 rolled; `bodies`
## (1 or 0) their headless bodies coming up the isles' cliffs
## (scripts/roguelike/layer_bodies.gd); `spawn_<rule>` (not in KNOBS: any
## of BodySpawner RULES, e.g. `spawn_far_share=1` every spawn a far one)
## their spawns' rules (LayerBodies SPAWN). `greybox` ("" none, "all", or
## slugs comma separated) the greybox motifs (scripts/kit_isle/greybox/
## registry.gd). `region`, `under_regions` and `world` ("under", "sky")
## say the layer's world (scripts/roguelike/layer_worlds.gd); `--world=`
## and `--under-regions=` are the same as their knobs. The rest are read
## by the motifs and the city kit.
const KNOBS := {"hoods":0,"gulf":0.0,"ride":"","rise":0.0,"arrows":-1,"viaduct":-1,"heads":-1,"bodies":1,"alternate":1,"ring":0,"greybox":"","greybox_force":1,"pool":"motifs","one_way":-1,
	"region":0,"under_regions":LayerWorlds.UNDER_REGIONS,"world":"","sky_kit":0,"danger":-1.0,"city_ring":0,"city_crossings":"varied",
	"city_size":"trim","city_hood":0}
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
		# [olmec] The roaming Olmec (olmec-threat-round1.md): `olmecs`
		# (roam | places) and `olmec_<x>`, not plan knobs.
		if key == "olmecs" or key.begins_with("olmec_"):
			out[key] = value if key == "olmecs" else float(value)
			continue
		if not KNOBS.has(key):
			push_warning("layer: no knob '%s' (%s, spawn_<%s>)" % [key,", ".join(PackedStringArray(KNOBS.keys())),"|".join(PackedStringArray(BodySpawner.RULES.keys()))])
			continue
		match typeof(KNOBS[key]):
			TYPE_INT: out[key] = int(value)
			TYPE_FLOAT: out[key] = float(value)
			_: out[key] = value
	return out

static func _key(isle: int, rim: String) -> String:
	return "%d/%s" % [isle,rim]

# --- The isles ----------------------------------------------------------------------

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
	# A rolled ring moves its isles: its occupancy from its plan (a motif
	# built in the editor on a base, scripts/kit_isle/motif_based.gd: its base's).
	if m.id() == "broken_ring": occ = _ring_occ(m.base() if m.has_method("based_on") else m)
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

# --- The edges ----------------------------------------------------------------------

## Socket `s` (an isle's own frame) moved by `off` into the world.
static func _world(s: Dictionary, off: Vector3) -> Dictionary:
	var w := s.duplicate()
	w.at = (s.at as Vector3)+off
	return w

# --- The cannon ----------------------------------------------------------------------

## The layer's cannon: the cannon's own knobs but its launch a little
## faster (CANNON_RUNS of the pilot's run at full power, the cannon's own
## 5.4), so a shot carries a gap tens of metres wide.
const CANNON_RUNS := 6.6
static func cannon_knobs() -> Dictionary:
	var k := Cannon.defaults()
	k.speed_max = pilot().run*CANNON_RUNS
	return k

# --- Helpers -------------------------------------------------------------------------

static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap
