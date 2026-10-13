extends "res://scripts/kit_isle/kit_motif.gd"
## The colonnade spine as a motif (scripts/kit_isle/kit_motif.gd; docs/
## scenic/colonnade-spine.md): the knife-edge ridge, the processional
## colonnade along its crest, the terraces' step walls and stairs, the
## temple gate on its head, the tail's fragments, the stepping stones, the
## anchors and the live rope bridges (studies/colonnade_spine_isle_art.gd).
## The ridge's ground is turf, the prisms under its flanks stone. Built
## here for its study (studies/colonnade_spine_isle.gd) and for the
## aqueduct isle's sky alike.
##
## A family (docs/design/roguelike/motif-families.md): `configure(seed,
## knobs)` rolls what the ruin has lost (Spine `rolled`): `collapse` (how
## many piers snapped, lintels fallen and voussoirs gone from the portals'
## crowns), `tail` (how many of the tail's fragments are left) and
## `bridges` (its rope bridges holding, one snapped or both). The ridge,
## its terraces and the temple stay the one ridge's. SPINE_SEED at its own
## knobs is the authored isle. A hero: the landmark a layer is built round.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")

const SPINE_SEED := 61
## The kit stairs a little ruined: a ceremonial way up.
const STAIR_WEATHERED := 0.3
## What stands in a run-up's way (m round its middle): a pier, a lying
## drum or stub (a fallen lintel's length as beads of LINTEL's width).
## The temple's pieces are their own footprints (`piece_block`), a
## stair its run and width.
const PIER_REACH := 0.9
const LYING_REACH := 0.8

var colonnade: Node3D
var temple: Node3D
var spine: Node3D
var bridges: Array[MeshInstance3D] = []
## The ridge's own build (ms).
var spine_ms := 0
var _plan: Dictionary = {}

func id() -> String:
	return "colonnade_spine"

func isle_name() -> String:
	return "colonnade spine"

## Placeholder name and line until the isle is named; its finds are the
## ledger's (scripts/ledger/ledger.gd `card`).
func isle_card() -> Dictionary:
	return Ledger.shared().card(id(),{"name":"The Long Colonnade","epithet":"The bones of a road to nowhere"})

func top() -> float:
	return Spine.TOP

## The plants keep off the way, the north shelf and the south bench.
func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(Spine.TOP,KitLand.wear_of(Spine.paths()))

## The life reads the authored colonnade's lintels and stones: none on a
## rolled one yet.
func life_script() -> Script:
	return preload("res://studies/colonnade_spine_isle_life.gd") if authored_isle() else null

func plane_tokens() -> Array:
	return Spine.plane_tokens(plan())

func token_source() -> String:
	return "colonnade"

func warm() -> void:
	super.warm()
	Spine._rock(0.0,0.0)
	Spine.platforms(plan())

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	var p := plan()
	# The ridge, its stairs, walls and temple are the one ridge's (its own
	# seeds); what it has lost moves with the isle's seed (0 at the authored).
	var shift := current_seed()-SPINE_SEED
	spine = Spine.spine_island(SPINE_SEED)
	spine_ms = Time.get_ticks_msec()-began
	art.add_child(spine)
	colonnade = Spine.colonnade(SPINE_SEED+1+shift,p)
	art.add_child(colonnade)
	art.add_child(Spine.step_walls(SPINE_SEED+2))
	for k in range(Spine.STEPS.size()):
		var s: Node3D = RuinKit.grand_stair(SPINE_SEED+3,STAIR_WEATHERED) if Spine.STEPS[k][3] == "grand" else RuinKit.stairs(SPINE_SEED+4+k,STAIR_WEATHERED)
		s.name = "Stair%d" % k
		s.transform = Spine.stair_frame(k)
		art.add_child(s)
	temple = Spine.temple(SPINE_SEED+10)
	art.add_child(temple)
	var lands: Array = [spine]
	for land: Node3D in Spine.lands(SPINE_SEED+20,p):
		art.add_child(land)
		lands.append(land)
	art.add_child(Art.floating_stones(SPINE_SEED+30+shift,Spine.platforms(p)))
	art.add_child(Spine.anchors(SPINE_SEED+40,p))
	var k := 0
	var held: Array = Spine.bridges_held(p)
	for ends: Array in Spine.bridge_ends(p):
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		if held[k]:
			var bridge: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,SPINE_SEED+50+k),a,b,SPINE_SEED+50+k)
			bridge.name = "RopeBridge%d" % k
			art.add_child(bridge)
			bridges.append(bridge)
		k += 1
	# The ridge's ground is turf, the prisms under its flanks stone.
	for land: Node3D in lands: turf(land,null,false)
	built_ms = Time.get_ticks_msec()-began

# --- The family ------------------------------------------------------------------

func family() -> bool:
	return true

func default_seed() -> int:
	return SPINE_SEED

## collapse: 0 whole to 1 as fallen as it gets; tail: fragments left;
## bridges: "intact", "one" snapped, "both" snapped.
func knob_choices() -> Dictionary:
	return {"collapse":[0.0,0.25,0.5,0.75,1.0],"tail":[1,2,3,4,5],"bridges":["intact","one","both"]}

func roll(at_seed: int) -> Dictionary:
	if at_seed == SPINE_SEED: return {"collapse":0.5,"tail":5,"bridges":"intact"}
	var rng := RandomNumberGenerator.new()
	rng.seed = at_seed*104723+11
	var out := {}
	var choices := knob_choices()
	for key: String in ["collapse","tail","bridges"]:
		var values: Array = choices[key]
		out[key] = values[rng.randi_range(0,values.size()-1)]
	return out

## The authored isle: its seed at its own knobs.
func authored_isle() -> bool:
	return current_seed() == SPINE_SEED and knobs == roll(SPINE_SEED)

## What the ruin has lost (Spine `authored` or `rolled`), made once per
## configure.
func plan() -> Dictionary:
	if _plan.is_empty():
		if authored_isle(): _plan = Spine.authored()
		else: _plan = Spine.rolled(current_seed(),float(knobs.collapse),int(knobs.tail),str(knobs.bridges))
	return _plan

func _plan_changed() -> void:
	_plan = {}

func role() -> String:
	return "hero"

static var _box := Rect2()
## The ridge's outline, its shelves' slabs and the tail's whole curl (the
## fragments a shorter tail leaves out stand inside it).
func footprint() -> Rect2:
	if _box.size == Vector2.ZERO:
		var ring: Array = Spine.outline()
		var box := Rect2(ring[0],Vector2.ZERO)
		for q: Vector2 in ring: box = box.expand(q)
		for s: Array in Spine.SLABS+Spine.FRAGMENTS:
			var c := Spine.slab_at(s)
			box = box.merge(Rect2(c-Vector2.ONE*float(s[3]),Vector2.ONE*float(s[3])*2.0))
		_box = box
	return _box

## The keel under the head to the podium's turf.
func height_span() -> Vector2:
	return Vector2(Spine.keel(Spine.X_WEST),Spine.TOP+Spine.PODIUM)

func build_cost() -> int:
	return 3400

## Its rims: the head's prow (west), the plaza's and L2's south edges (over
## the flank's fall; a run-up north across the crest between the rows, at
## the terrace's clearest) and the last fragment of the tail left (away
## from the one before); its arena the clearest spot of a terrace between
## the rows; cover in the temple's north stair turret; a perch at the
## podium's clearest spot.
func sockets() -> Array:
	var p := plan()
	var blocks := _blocks(p)
	var step := pilot().run*0.25
	var out: Array = []
	# The head: off the axis by the altar, facing west down the prow.
	var head := Spine.at(HEAD.x,HEAD.y)
	var west := -Spine.along(HEAD.x)
	out.append(socket("rim","head",Vector3(head.x,Spine.ground(head.x,head.y),head.y),west,step,
		clear_run(head,-Vector2(west.x,west.z),blocks,Spine.CELLA[0][0]-HEAD.x)))
	# The south edges: at the crest's lip, where along the terrace the
	# run-up across it is clearest.
	for edge: Array in [["plaza_south",_terraces()[0]],["terrace_south",_terraces()[1]]]:
		var best := {}
		var x: float = edge[1][0]
		while x <= float(edge[1][1]):
			var at2 := Spine.at(x,Spine.WC-step)
			if room_at(at2,blocks) >= step*0.5:
				var across := Spine.along(x).cross(Vector3.UP)
				var south := across if across.z > 0.0 else -across
				var run := clear_run(at2,-Vector2(south.x,south.z),blocks,2.0*Spine.WC-2.0*step)
				if best.is_empty() or run > float(best.run_up)+0.01:
					best = socket("rim",str(edge[0]),Vector3(at2.x,Spine.ground(at2.x,at2.y),at2.y),south,step,run)
			x += 0.5
		out.append(best)
	# The tail's last fragment left, away from the one before (or the tip).
	var frags: Array = Spine.fragments(p)
	var last: Array = frags[frags.size()-1]
	var lc := Spine.slab_at(last)
	var tip := Spine.tail_tip()
	var before: Vector2 = Spine.slab_at(frags[frags.size()-2]) if frags.size() > 1 else Vector2(tip.x,tip.z)
	var away := (lc-before).normalized()
	var poly := PackedVector2Array(Art.blob(lc,float(last[3]),SPINE_SEED+20+Spine.SLABS.size()+frags.size()))
	var fa := lc+away*(reach_out(poly,lc,away)-step)
	out.append(socket("rim","tail",Vector3(fa.x,Spine.TOP+float(last[4]),fa.y),Vector3(away.x,0.0,away.y),step,
		clear_run(fa,-away,blocks,fa.distance_to(lc)+reach_out(poly,lc,-away)-step)))
	var arena: Array = _clearest(_terraces(),Spine.ROW-PIER_REACH,blocks)
	out.append(_spot("arena","terrace",arena))
	# Cover: the south stair turret's doorstep, in the angle of the turret and
	# the gate (the temple's own, whatever the ruin has lost); open toward
	# the axis. Inside, the steps start at the door; the north turret's
	# door opens into the gate's flank.
	var t := _turret(1.0)
	var step_at := t*Vector3(0.0,0.0,RuinKit.TURRET.x+DOORSTEP)
	step_at.y = Spine.ground(step_at.x,step_at.z)
	out.append(socket("cover","turret_door",step_at,t.basis.z,DOORSTEP))
	# The perch: the podium's clearest, between the prow and the gate.
	var perch: Array = _clearest([[HEAD.x,Spine.GATE_X]],Spine.WC_HEAD-1.0,blocks)
	out.append(_spot("perch","podium",perch))
	return out

## The head rim's place: x along the axis and d across it (the prow's
## crest still flat there, beside the altar).
const HEAD := Vector2(20.6,3.0)
## The cover: this far out from the south turret's shell, at its door.
const DOORSTEP := 0.25

## The terraces' clear stretches (x), stair foot to step: the plaza (L3),
## L2, L1 (to the saddle), L0 (from the saddle to where the tail falls).
static func _terraces() -> Array:
	return [[Spine.STEP_PODIUM+Spine.GRAND_RUN,Spine.STEP_L3],[Spine.STEP_L3+Spine.KIT_RUN,Spine.STEP_L2],
		[Spine.STEP_L2+Spine.KIT_RUN,Spine.SADDLE.x],[Spine.SADDLE.y,132.0]]

## A socket at a spot `_clearest` found.
func _spot(kind: String, name: String, spot: Array) -> Dictionary:
	var c: Vector2 = spot[0]
	return socket(kind,name,Vector3(c.x,Spine.ground(c.x,c.y),c.y),Spine.along(c.x),spot[1])

## The clearest spot along `spans` (x), within `half` m of the axis: [where
## (x, z), its room from what stands there, the span's ends and `half`],
## half a metre at a time.
func _clearest(spans: Array, half: float, blocks: Array) -> Array:
	var best: Array = [Vector2.ZERO,-1.0]
	for span: Array in spans:
		var x: float = span[0]
		while x <= float(span[1]):
			var d := -half
			while d <= half:
				var c := Spine.at(x,d)
				var room := minf(minf(x-float(span[0]),float(span[1])-x),half-absf(d))
				room = minf(room,room_at(c,blocks))
				if room > float(best[1]): best = [c,room]
				d += 0.5
			x += 0.5
	return best

## The temple's stair turret on `side` (-1 north), as `temple` stands it.
static func _turret(side: float) -> Transform3D:
	var f := Spine.frame(Spine.GATE_X-0.8,side*Spine.TURRET_D,Spine.TOP+Spine.PODIUM)
	return Transform3D(f.basis*Basis(Vector3.UP,PI*0.5*side),f.origin)

## What stands on the crest and the podium: the piers and stubs, the fallen
## lintels (beads), the drums lying, the ways up, the stairs (their runs),
## and the temple's pieces (their footprints, stood as `temple` stands them).
func _blocks(p: Dictionary) -> Array:
	var out: Array = []
	for i in range(Spine.LINES.size()):
		for side: float in [-1.0,1.0]:
			if Spine.pier_height(i,side,p) > 0.0: out.append([Spine.at(float(Spine.LINES[i][0]),side*Spine.ROW),PIER_REACH])
	for key: String in p.fallen:
		var i := int(key.get_slice(",",0))
		var side := float(key.get_slice(",",1))
		var x: float = float(Spine.LINES[i][0])+0.4
		while x < float(Spine.LINES[i+1][0])-0.4:
			out.append([Spine.at(x,side*(Spine.ROW-1.5)),Spine.LINTEL.x])
			x += Spine.LINTEL.x
	var tx: float = Spine.LINES[Spine.TOPPLED][0]
	for k in range(3): out.append([Spine.at(tx+k*0.15,Spine.ROW-0.5-k*1.15),LYING_REACH])
	out.append([Spine.at(tx+0.8,-Spine.ROW+1.9),LYING_REACH])
	for s: Array in Spine.STACKS:
		out.append([Spine.at(float(s[0]),float(s[1])*(Spine.ROW-1.5)),LYING_REACH])
		out.append([Spine.at(float(s[0]),float(s[1])*(Spine.ROW-2.8)),LYING_REACH])
	for step: Array in Spine.STEPS:
		var grand: bool = step[3] == "grand"
		var run: float = Spine.GRAND_RUN if grand else Spine.KIT_RUN
		var wide: float = (RuinKit.GRAND_WIDTH if grand else RuinKit.STAIR_WIDTH)*0.5+RuinKit.CHEEK.x
		var x: float = step[0]
		while x <= float(step[0])+run:
			out.append([Spine.at(x,0.0),wide])
			x += 0.5
	var seed_value := SPINE_SEED+10
	var y := Spine.TOP+Spine.PODIUM
	out.append(piece_block("rose_gable",seed_value,0.45,Spine.frame(Spine.GATE_X,0.0,y)))
	out.append(piece_block("turret",seed_value+1,0.35,_turret(-1.0)))
	out.append(piece_block("turret",seed_value+2,0.7,_turret(1.0)))
	for k in range(Spine.CELLA.size()):
		var c: Array = Spine.CELLA[k]
		var f := Spine.frame(float(c[0]),float(c[1]),y)
		var face := Basis(Vector3.UP,PI*0.5) if float(c[1]) < 0.0 else Basis(Vector3.UP,-PI*0.5)
		out.append(piece_block("lancet_wall",seed_value+3+k,0.5+0.15*k,Transform3D(f.basis*face,f.origin)))
	out.append(piece_block("tomb_chest",seed_value+8,0.5,Spine.frame(Spine.ALTAR_X,0.0,y)))
	return out
