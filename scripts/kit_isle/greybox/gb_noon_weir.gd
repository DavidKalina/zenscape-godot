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
##   Ring the bell (stand on the bell floor), then step off its north edge:
##   you fall into its mouth, it gulps, winds up and fires you east onto the
##   far landing, whose east edge is the rim out (`far`). Climbing in (Y)
##   and firing (A) is the same shot. The study's cannon fired DOWN the top
##   channel from an isle 8 m over the top that nothing in a layer reaches,
##   so its chain 3 is dropped; the card's "the top tier throws sideways off
##   the stack toward a lower isle" is what this is.
## - The rim in is the study's start deck (`deck`, its south edge). The
##   Noon Flood (chain 2) still rides you down all three spills onto it: in
##   a layer that is the free ride back to the foot, as the card has it.
## - The channels are the sluices' own build (floor, parapets, refuges), so
##   `_solids` adds them to the occupancy; parts() draws the slabs only.
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
		["far landing (rim out, east edge)",Rect2(10.0,58.5,14.0,12.0),FAR_TOP,FAR_TOP-2.0,"pad"],
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
	return "Climb the three channels in their dry spells: walk each north against the water, stair up beside the gate, bridge back. Mind the ram on the middle landing.\nOn top, step off the bell floor's north edge into the cannon: it fires you east to the way on. At noon all three gates flood: ride it down."

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
func _solids() -> Array:
	var out: Array = super()
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
	var gun: Node3D = field.add_cannon(g.w(cannon_base()),HEADING)
	gun.set_aim(0.0,deg_to_rad(PITCH))
	gun.set_power(NOTCH)
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
