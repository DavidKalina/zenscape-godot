extends "res://scripts/kit_isle/motif_greybox.gd"
## The Noon Weir in the generator: studies/greybox/noon_weir.gd's LAYOUT
## (card: docs/design/roguelike/brainstorm/round1/motif-m1-noon-weir.md),
## the same geometry in the same frame, so its climb and its chains keep the
## study's numbers: three stacked sluice channels on one shared clock (the
## study's own, `Clock` below), a stair and a bridge per tier, the Plinth
## Ram on the middle tier's gate landing, the bell floor on top.
##
## Changes from the study:
## - The way out is the catching cannon (docs/design/roguelike/cannon-
##   catch.md), the study's "cannon on a neighbouring isle" made part of the
##   motif and turned round: it stands on a plinth under the bell floor's
##   north edge, aimed east off the stack at its rest aim (40 deg, notch 2).
##   From the bell floor, jump off its north edge: you fall into the
##   mouth (a slow careful step hangs you off the lip first; hold away to
##   let go and drop in), it gulps, winds up and fires you east onto the
##   far landing, whose east edge is the rim out (`far`). Climbing in (Y)
##   and firing (A) is the same shot. The study's cannon fired DOWN the top
##   channel from an isle 8 m over the top that nothing in a layer reaches,
##   so its chain 3 is dropped; the card's "the top tier throws sideways off
##   the stack toward a lower isle" is what this is.
## - The way back up, for a route the generator runs backwards (in at the
##   far landing, out off the deck): a second cannon on the far landing
##   fires you (Y in, A) onto the top landing; from there down the channels
##   (or the Noon Flood) to the deck.
## - The rim in is the study's start deck (`deck`, its south edge). The
##   Noon Flood (chain 2) still rides you down all three spills onto it: in
##   a layer that is the free ride back to the foot, as the card has it.
## - The channels are the sluices' own build (floor, parapets, refuges), so
##   `_solids` adds them to the occupancy; parts() draws the slabs only.
## - Turf pass (the section at the end): kit terrain and carved stone by
##   default, the grey boxes with `--weir-grey` (A/B checks).
const Cannon = preload("res://scripts/cannon/cannon.gd")
const PlinthRam = preload("res://scripts/enemies/plinth_ram.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const Sluice = preload("res://scripts/traps/trap_sluice.gd")

# --- The study's numbers, verbatim (studies/greybox/noon_weir.gd) ----------------------
const TELL_TIME := 2.0
const HOLD := 0.6
const BASE := 8.0
const MULTS := [1,2,3]

## The catching cannon: its plinth's top, the mouth (where a body stepping
## off the bell floor's north edge comes down), its heading (-PI/2 fires
## +x, east, off the stack) and its rest aim (the cannon's own defaults:
## the catch fires along the set aim, so nothing needs aiming). The base is
## derived from the mouth (`cannon_base`).
const PLINTH_TOP := 16.0
const MOUTH := Vector3(0.0,0.0,64.5)
const HEADING := -PI*0.5
const PITCH := 40.0
const NOTCH := 2
## The far landing's top (2 m over the ram's landing: nothing below the top
## can sail onto it) and where the rest shot comes down on it (measured
## with Cannon.landing_for: 20.57 m east of the base at 4 m below it).
const FAR_TOP := 14.0
## The way back up (the generator may enter at the far landing): a second
## cannon on the far landing's south end, aimed west at the top landing at
## its rest pitch BACK_PITCH and power BACK_NOTCH (its `pitch_rest` and
## `power_rest`, so climbing in and firing needs no aiming): the arc peaks
## 13.9 m over its base and comes down through the top landing's height
## 15.95 m west (Cannon.flight, measured), at about (-4.5, 24, 54). It also
## catches a body dropped east off the top landing and throws it back.
const BACK_BASE := Vector3(11.5,14.0,54.0)
const BACK_HEADING := PI*0.5
const BACK_NOTCH := 4
const BACK_PITCH := 65.0

## The study's LAYOUT, verbatim but for the cannon (now the catching cannon
## on its plinth under the bell floor, and the far landing it fires onto)
## and the labels that named the start deck the exit's stand-in.
const LAYOUT := {
	"width":3.0,
	"tiers":[
		{"name":"tier 1 (low, period x1)","gate":Vector3(0.0,0.0,0.0),"length":20.0,"mult":1,"refuge":10.0},
		{"name":"tier 2 (middle, x2, the ram's lane)","gate":Vector3(0.0,12.0,29.5),"length":24.0,"mult":2,"refuge":12.0,"parapet":Vector2(0.4,1.0),"refuge_top":1.2,"wave_length":8.0},
		{"name":"tier 3 (top, x3)","gate":Vector3(0.0,24.0,49.5),"length":20.0,"mult":3,"refuge":10.0},
	],
	## [name, rect, top, bottom, colour]
	"slabs":[
		["start deck (rim in, south edge)",Rect2(-8.0,-44.0,16.0,21.6),0.0,-2.0,"pad"],
		["gate head 1",Rect2(-14.0,0.0,18.0,6.0),0.0,-2.0,"grey"],
		["stair-1 top",Rect2(-14.0,-30.0,11.8,6.0),12.0,10.0,"grey"],
		["bridge 1 (rope-bridge stand-in)",Rect2(-4.4,-30.0,2.2,44.0),12.0,11.0,"grey"],
		["gate landing 2 (the ram's)",Rect2(-14.0,29.5,18.0,6.0),12.0,10.0,"grey"],
		["stair-2 top",Rect2(-14.0,-0.5,11.8,6.0),24.0,22.0,"grey"],
		["bridge 2 (rope-bridge stand-in)",Rect2(-4.4,-0.5,2.2,37.0),24.0,23.0,"grey"],
		["gate head 3 (top landing)",Rect2(-14.0,49.5,18.0,8.0),24.0,22.0,"grey"],
		["bell floor (belfry stand-in)",Rect2(-4.0,57.5,8.0,5.0),25.2,22.0,"lip"],
		["the cannon's plinth",Rect2(-4.5,62.5,6.0,5.0),PLINTH_TOP,PLINTH_TOP-3.0,"grey"],
		["far landing (rim out, east edge)",Rect2(10.0,51.0,14.0,19.5),FAR_TOP,FAR_TOP-2.0,"pad"],
	],
	## [name, low middle edge, high middle edge, width]
	"stairs":[
		["stair 1 (grand_stair stand-in)",Vector3(-12.0,0.0,0.0),Vector3(-12.0,12.0,-24.0),4.0],
		["stair 2 (grand_stair stand-in)",Vector3(-12.0,12.0,29.5),Vector3(-12.0,24.0,5.5),4.0],
	],
	## [kind, position, facing (x, z)]
	"enemies":[
		["ram",Vector3(0.0,12.0,33.0),Vector2(0.0,-1.0)],
	],
	## Floating labels: [position, text]
	"labels":[
		[Vector3(0.0,3.5,-28.0),"TIER 1 open end (walk N, against the water)"],
		[Vector3(0.0,3.0,-3.0),"gate 1 - stair 1 beside it (west)"],
		[Vector3(-12.0,6.0,-12.0),"STAIR 1 (STAND-IN for grand_stair, 26.6 deg)"],
		[Vector3(-8.0,15.0,-14.0),"BRIDGE 1 - STAND-IN rope bridge (keeps the lip and the tier-1 spill clear)"],
		[Vector3(-3.3,15.0,12.0),"hop the parapet here into tier 2"],
		[Vector3(0.0,15.5,14.0),"TIER 2 (the ram's lane, 24 m: a knock from the gate end stays in the channel)"],
		[Vector3(0.0,15.0,34.0),"RAM's landing: it charges S down the channel at anyone walking up it"],
		[Vector3(-12.0,18.0,17.0),"STAIR 2"],
		[Vector3(-3.3,27.0,36.0),"hop the parapet here into tier 3"],
		[Vector3(0.0,27.5,42.0),"TIER 3 (top, longest period)"],
		[Vector3(-4.0,27.0,54.0),"top landing: wait for noon, run in on the tell: the Noon Flood rides you down to the deck"],
		[Vector3(0.0,29.0,60.0),"STAND-IN: bell (ring-on-landing noise not built) · the way on: step off the north edge into the cannon"],
		[Vector3(-8.0,13.5,36.0),"NOT BUILT: tower_shell wall-kick chimney (card beat 4)"],
		[Vector3(8.0,12.0,16.0),"NOT BUILT: falling-water sheet between tiers (kit ask 2)"],
		[Vector3(6.0,6.0,-6.0),"tier-2 spill lands here (chain 1 / 2): a floor lower"],
		[Vector3(6.0,18.0,18.5),"tier-3 spill lands here (chain 2), 11 m below the ram's landing"],
		[Vector3(6.0,3.0,-25.0),"tier-1 spill lands here: back on the deck"],
		[Vector3(0.0,22.0,66.5),"THE CATCHING CANNON: fall in, it fires you east (or Y in, A fire)"],
		[Vector3(17.0,17.0,64.5),"FAR LANDING: the cannon's rest shot comes down here · the way on leaves its east edge"],
		[Vector3(11.5,17.5,54.0),"THE WAY BACK UP: Y in, A fires you onto the top landing"],
		[Vector3(-6.0,6.0,38.0),"STAND-IN: shared clock (one day 48 s, noon at its end)"],
	],
}

func slug() -> String:
	return "noon_weir"

func isle_name() -> String:
	return "The Noon Weir"

func epithet() -> String:
	return "It keeps the hours. It has always kept the hours."

func brief() -> String:
	return "Climb the three channels in their dry spells: walk each north against the water, stair up beside the gate, bridge back. Mind the ram on the middle landing.\nOn top, jump off the bell floor's north edge into the cannon below: it catches you and fires you east to the way on. At noon all three gates flood: ride it down."

func start() -> Vector3:
	return Vector3(0.0,0.0,-34.0)

## The catching cannon's base (on its plinth), from its mouth.
static func cannon_base() -> Vector3:
	var k := Cannon.defaults()
	var p := deg_to_rad(PITCH)
	var f := Vector2(-sin(HEADING),-cos(HEADING))
	var dir := Vector3(f.x*cos(p),sin(p),f.y*cos(p))
	var off := Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
	return Vector3(MOUTH.x-off.x,PLINTH_TOP,MOUTH.z-off.z)

func parts() -> Array:
	var out: Array = []
	for slab: Array in LAYOUT.slabs:
		var r: Rect2 = slab[1]
		out.append(["box",r,slab[3],slab[2],slab[4]])
		out.append(["label",Vector3(r.get_center().x,float(slab[2])+0.7,r.get_center().y),"%s  y %d" % [slab[0],int(slab[2])]])
	for st: Array in LAYOUT.stairs: out.append(["ramp",st[1],st[2],st[3],"grey"])
	for lab: Array in LAYOUT.labels: out.append(["label",lab[0],lab[1]])
	return out

## The channels (the sluices build them: floor, parapets, refuges, the
## gate's header) as solids for the occupancy, not drawn by parts().
func _grey_solids() -> Array:
	var out: Array = super._solids()
	var w := float(LAYOUT.width)
	for t: Dictionary in LAYOUT.tiers:
		var g: Vector3 = t.gate
		var half := w*0.5+0.4+1.0
		out.append([Rect2(g.x-half,g.z-float(t.length),half*2.0,float(t.length)),g.y-0.4,g.y+2.6,null])
	return out

## In off the start deck's south edge (the study's start, the drop behind
## you); out off the far landing's east edge (where the cannon fires you).
func rims() -> Array:
	return [
		{"name":"deck","at":Vector3(0.0,0.0,-43.0),"face":Vector3(0.0,0.0,-1.0),"run_up":18.0,"lip":1.0},
		{"name":"far","at":Vector3(23.0,FAR_TOP,64.5),"face":Vector3(1.0,0.0,0.0),"run_up":12.0,"lip":1.0},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"ram_landing","at":Vector3(-5.0,12.0,32.5),"room":5.0},
		{"kind":"arena","name":"top_landing","at":Vector3(-6.0,24.0,53.5),"room":6.0},
		{"kind":"cover","name":"gate_head_1","at":Vector3(-8.0,0.0,3.0),"room":2.5},
		{"kind":"perch","name":"bell_floor","at":Vector3(0.0,25.2,60.0),"room":2.5},
		{"kind":"arena","name":"far_landing","at":Vector3(18.0,FAR_TOP,61.0),"room":4.0},
		{"kind":"perch","name":"deck","at":Vector3(0.0,0.0,-34.0),"room":6.0},
	]

## The sluices (the study's own class, its knobs), the shared clock that
## drives them (the study's), the ram, the catching cannon.
func live(g: Node) -> void:
	var w := float(LAYOUT.width)
	var sluices: Array = []
	for t: Dictionary in LAYOUT.tiers:
		var sl: Node3D = Sluice.new()
		var knobs := {
			"length":t.length,"width":w,"cover":w*0.5+0.4,"trigger":"timer","period":1.0e9,
			"tell_time":TELL_TIME,"refuges":[[t.refuge,1.0]],"gap":Trap.pilot().walk,
		}
		for key: String in ["parapet","refuge_top","wave_length"]:
			if t.has(key): knobs[key] = t[key]
		sl.configure(knobs)
		sl.position = g.w(t.gate)
		g.trap(sl)
		sluices.append(sl)
	var clock := Clock.new()
	clock.name = "NoonClock"
	clock.setup(sluices)
	g.trap(clock)
	for e: Array in LAYOUT.enemies:
		if e[0] == "ram": g.enemy(PlinthRam,g.w(e[1]),e[2])
	# The stage makes its CannonField after the greybox isles (layer_stage
	# `setup`), so the clock lays the cannon on its first step.
	clock.host = g

## The catching cannon on its plinth, in the stage's CannonField (`g` the
## live host); null if the field isn't there yet.
static func lay_cannon(g: Node) -> Node3D:
	var field: Node3D = g.cannons()
	if field == null: return null
	var gun: Node3D = field.add_cannon(g.w(cannon_base()),HEADING,{"pitch_rest":deg_to_rad(PITCH),"power_rest":NOTCH})
	field.add_cannon(g.w(BACK_BASE),BACK_HEADING,{"pitch_rest":deg_to_rad(BACK_PITCH),"power_rest":BACK_NOTCH})
	return gun

## The study's shared clock (STAND-IN for kit ask 1), as a trap so the
## isle's TrapField steps it: each gate's release at n x its period + its
## offset after noon (offsets derived as the study derives them), its tell
## TELL_TIME earlier, and at noon a double surge. `day` restarts on reset.
class Clock extends "res://scripts/traps/trap.gd":
	var sluices: Array = []
	var day := 0.0
	var offsets: Array = [0.0,0.0,0.0]
	var next_tell: Array = [0.0,0.0,0.0]
	var noon_flush: Array = [false,false,false]
	## The live host, and the catching cannon once laid.
	var host: Node = null
	var gun: Node3D = null

	func setup(s: Array) -> void:
		sluices = s
		trap_name = "noon_clock"
		var study: GDScript = load("res://studies/greybox/noon_weir.gd")
		var n := sluices.size()
		offsets[n-1] = 0.0
		for i in range(n-2,-1,-1):
			var up: Node3D = sluices[i+1]
			var ride := float(up.knob("length"))/float(up.knob("speed"))
			var drop: float = (LAYOUT.tiers[i+1].gate as Vector3).y-(LAYOUT.tiers[i].gate as Vector3).y
			offsets[i] = float(offsets[i+1])+ride+float(study.spill_air(drop))+HOLD
		set_clock(0.0)

	func period_of(i: int) -> float:
		return float(MULTS[i])*BASE

	func day_length() -> float:
		return 6.0*BASE

	## The clock set to `t`: every tier's next tell from there.
	func set_clock(t: float) -> void:
		day = t
		for i in 3:
			var period := period_of(i)
			var n := ceilf((t+TELL_TIME-float(offsets[i]))/period)
			next_tell[i] = maxf(n,1.0)*period+float(offsets[i])-TELL_TIME

	func is_noon(i: int, tell_at: float) -> bool:
		var dl := day_length()
		var k := fposmod(tell_at+TELL_TIME-float(offsets[i]),dl)
		return k < 0.01 or k > dl-0.01

	## The first noon's top tell (the clock's time).
	func noon_tell_time() -> float:
		return day_length()+float(offsets[2])-TELL_TIME

	func before(delta: float) -> void:
		if gun == null and host != null: gun = load("res://scripts/kit_isle/greybox/gb_noon_weir.gd").lay_cannon(host)
		day += delta
		for i in sluices.size():
			if day >= float(next_tell[i]):
				if sluices[i].state == Sluice.IDLE:
					var noon := is_noon(i,float(next_tell[i]))
					noon_flush[i] = noon
					sluices[i].configure({"second_wave":noon})
					sluices[i].trigger()
				next_tell[i] += period_of(i)

	func reset() -> void:
		super.reset()
		set_clock(0.0)

# --- Turf pass: the land and the stone -----------------------------------------------------
## Built as kit terrain and carved stone, not grey boxes (`--weir-grey`
## builds the grey boxes instead, for A/B checks). Three KitLand islands:
## the start deck (flat 0), the weir's floor under the whole stack (flat
## FOOT_Y: a fall off a channel's side, or past the cannon, lands on turf,
## not in the void), and the far landing (flat FAR_TOP). The masonry (the
## gate heads and landings, the bridges, the stairs, the bell floor, the
## cannon's plinth, piers down to the floor) in carved stone (scripts/
## kit_isle/greybox/giant_stone.gd), each collided as its greybox walk box
## to the centimetre; piers only where no chain passes. The channels are
## the sluices' own build, as in the greybox.
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")

const TURF_SEED := 5200
## The weir's floor (m) and its rect (x, z): under the stack from just
## north of tier 1's open end to past the cannon's plinth.
const FOOT_Y := -1.2
const FOOT := Rect2(-17.0,-19.0,24.0,92.0)
## Keels (m under each island's top) and how far their spurs hang under.
const DECK_DEPTH := 8.0
const FOOT_DEPTH := 11.0
const FAR_DEPTH := 9.0
const KEEL_REACH := 1.4
## The stairs' drawn beam under their walked top (m).
const STAIR_THICK := 1.4

static func grey() -> bool:
	return preload("res://scripts/launch_args.gd").user_args().has("--weir-grey")

static func _slab(prefix: String) -> Array:
	for s: Array in LAYOUT.slabs:
		if str(s[0]).begins_with(prefix): return s
	return []

## The deck's turf stops short of its north edge; the sill (KERB, stone, a
## walk box) is that edge, exact: the tier-1 spill lands a body on its lip
## (z -22.4), where the kit's ±0.25 m wobble would drop it.
const KERB := Rect2(-8.0,-23.6,16.0,1.2)

static func deck_outline() -> Array:
	return _rounded(Rect2(-8.0,-44.0,16.0,21.0),1.6)

static func far_outline() -> Array:
	return _rounded(_slab("far landing")[1],1.8)

static func foot_outline() -> Array:
	return _rounded(FOOT,3.0)

static func _rounded(r: Rect2, cut: float) -> Array:
	var a := r.position
	var b := r.end
	return [Vector2(a.x+cut,a.y),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),Vector2(b.x,b.y-cut),
		Vector2(b.x-cut,b.y),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),Vector2(a.x,a.y+cut)]

## The worn ways: the deck's run-up to the hop, the far landing from the
## shot's fall to its rim.
static func paths() -> Array:
	return [[Vector2(0.0,-43.0),Vector2(0.0,-23.0)],[Vector2(16.0,64.5),Vector2(23.0,64.5)],[Vector2(16.0,64.5),Vector2(13.0,55.0)]]

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return TURF_SEED+9

func life_script() -> Script:
	return null if grey() else KitLife

func warm() -> void:
	super.warm()
	if grey(): return
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	RuinKit.materials()
	GiantStone.warm()

## The piers: [rect, top] (their foot in the weir's floor), each under a
## slab's or a channel's underside, clear of every spill's fall (at x 0
## from each open end, south), the stairs (x -14..-10), the parapet hops
## and the ram's landing.
static func piers() -> Array:
	return [
		[Rect2(-1.9,-20.0,3.8,20.0),-0.4],          # under tier 1's channel
		[Rect2(-4.2,-12.0,1.8,2.0),11.0],           # bridge 1
		[Rect2(-1.9,11.0,3.8,2.4),11.6],            # tier 2's channel
		[Rect2(-1.9,24.0,3.8,2.4),11.6],
		[Rect2(-9.0,30.5,4.0,4.0),10.0],            # the ram's landing
		[Rect2(-3.0,30.5,4.0,4.0),10.0],
		[Rect2(-9.0,0.0,4.0,4.0),22.0],             # stair-2 top
		[Rect2(-4.2,19.0,1.8,2.0),23.0],            # bridge 2
		[Rect2(-1.9,38.0,3.8,2.4),23.6],            # tier 3's channel
		[Rect2(-1.9,44.0,3.8,2.4),23.6],
		[Rect2(-8.0,51.0,4.0,5.0),22.0],            # the top landing
		[Rect2(-3.0,58.5,6.0,3.0),22.0],            # the bell floor
		[Rect2(-4.0,63.0,5.0,4.0),PLINTH_TOP-3.0],  # the cannon's plinth
	]

## The greybox's solids, the channels, the keels under the three islands
## and the piers, so the occupancy keeps the generator off the rock.
func _solids() -> Array:
	var out: Array = _grey_solids()
	if grey(): return out
	for keel: Array in [[deck_outline(),0.0,DECK_DEPTH],[foot_outline(),FOOT_Y,FOOT_DEPTH],[far_outline(),FAR_TOP,FAR_DEPTH]]:
		var ring: Array = keel[0]
		var box := Rect2(ring[0],Vector2.ZERO)
		for p: Vector2 in ring: box = box.expand(p)
		out.append([box.grow(-1.0),float(keel[1])-float(keel[2])*KEEL_REACH,float(keel[1]),null])
	for p: Array in piers(): out.append([p[0],FOOT_Y,float(p[1]),null])
	return out

## Measured headless (the turf build, this container).
func build_cost() -> int:
	return 0 if grey() else 250

## Turf on the deck, the floor and the far landing; the weir in stone.
func build(into: Node3D) -> void:
	if grey():
		super.build(into)
		return
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "NoonWeir"
	into.add_child(root)
	var tone := KitLook.turf(TURF_SEED,KitLand.wear_of(paths()))
	var deck := KitLand.island({"outline":deck_outline(),"seed":TURF_SEED,"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":DECK_DEPTH,"hang":true,"resample":[40.0,90,32],"tone":tone})
	deck.name = "Deck"
	var floor_land := KitLand.island({"outline":foot_outline(),"seed":TURF_SEED+1,"ground":func(_x: float, _z: float) -> float: return FOOT_Y,
		"top":FOOT_Y,"depth":FOOT_DEPTH,"hang":true,"resample":[60.0,220,32],"tone":tone})
	floor_land.name = "Floor"
	var far := KitLand.island({"outline":far_outline(),"seed":TURF_SEED+2,"ground":func(_x: float, _z: float) -> float: return FAR_TOP,
		"top":FAR_TOP,"depth":FAR_DEPTH,"hang":true,"resample":[40.0,90,32],"tone":tone})
	far.name = "FarLanding"
	for land: Node3D in [deck,floor_land,far]:
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	_stone(root)
	built_ms = Time.get_ticks_msec()-began

## An island's hanging sides collided as drawn (as the giant's).
static func _collide_sides(land: Node3D) -> void:
	var sides := land.get_node_or_null("Mesh") as MeshInstance3D
	if sides == null or sides.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(sides.mesh.get_faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	land.add_child(body)

## The masonry: drawn as one mesh of carved stone, collided as the
## greybox's walk boxes (the deck and the far landing are turf).
func _stone(root: Node3D) -> void:
	var m: RefCounted = GiantStone.mesher()
	var solids := Node3D.new()
	solids.name = "Walk"
	root.add_child(solids)
	for slab: Array in LAYOUT.slabs:
		var label := str(slab[0])
		if label.begins_with("start deck") or label.begins_with("far landing"): continue
		var r: Rect2 = slab[1]
		var bottom := float(slab[3])
		# Gate head 1 stands on the weir's floor, its foot buried in it.
		if label.begins_with("gate head 1"): bottom = FOOT_Y-0.6
		_block(m,solids,r,bottom,float(slab[2]),0.25)
	for st: Array in LAYOUT.stairs:
		var low: Vector3 = st[1]
		var high: Vector3 = st[2]
		var w := float(st[3])
		var along := (high-low).normalized()
		var side := Vector3.UP.cross(along).normalized()
		var up := along.cross(side).normalized()
		var basis := Basis(side,up,along)
		var length := low.distance_to(high)+0.02
		# Collided exactly as the greybox ramp; drawn as a thicker beam with
		# that ramp its top, treads drawn on it.
		_walk_shape(solids,Transform3D(basis,(low+high)*0.5-up*0.2),Vector3(w,0.4,length))
		m.box(Transform3D(basis,(low+high)*0.5-up*STAIR_THICK*0.5),Vector3(w,STAIR_THICK,length),0.2)
		var steps := int(floor(length/1.2))
		for k in steps:
			var t := (float(k)+0.5)/float(steps)
			m.box(Transform3D(basis,low.lerp(high,t)+up*0.05),Vector3(w-0.3,0.1,0.5),0.03,NAN,1.08)
	for p: Array in piers():
		_block(m,solids,p[0],FOOT_Y-0.6,float(p[1]),0.3,FOOT_Y)
	_block(m,solids,KERB,-1.6,0.0,0.06,-1.0)
	# The notch where all three gates coincide, cut deepest, with a rune: a
	# lit band on the top landing's west and east faces under its lip.
	var gh: Rect2 = _slab("gate head 3")[1]
	var band := 24.0-1.3
	m.runes(Vector3(gh.position.x,band,gh.end.y),Vector3(gh.position.x,band,gh.position.y),Vector3.UP,Vector3(-1,0,0),1.0)
	m.runes(Vector3(gh.end.x,band,gh.position.y),Vector3(gh.end.x,band,gh.end.y),Vector3.UP,Vector3(1,0,0),2.0)
	var body := MeshInstance3D.new()
	body.name = "Masonry"
	body.mesh = GiantStone.mesh_of(m)
	root.add_child(body)
	root.set_meta("stone_triangles",m.triangles())

## A block drawn and collided (its rect x z, bottom, top).
static func _block(m: RefCounted, solids: Node3D, r: Rect2, bottom: float, high: float, bevel: float, foot := NAN) -> void:
	var place := Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y))
	var size := Vector3(r.size.x,high-bottom,r.size.y)
	_walk_shape(solids,place,size)
	m.box(place,size,bevel,foot)

static func _walk_shape(solids: Node3D, place: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.transform = place
	var c := CollisionShape3D.new()
	c.shape = _box_shape(size)
	body.add_child(c)
	solids.add_child(body)
