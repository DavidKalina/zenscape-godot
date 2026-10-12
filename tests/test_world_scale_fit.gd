extends SceneTree
## The game's sizes still fit the world (scripts/world_scale.gd, docs/design/
## plane-ground-scale.md), headless, at the default sizes and again at
## `--plane-scale=1 --wanderer-scale=1 --opening-ratio=1` (a second Godot
## run of this script, since WorldScale reads its flags once). Every flown
## opening is its toy-era width through `WorldScale.opening` (toy width x
## plane x RATIO, floored at SNUG's 1.2 m past each wingtip unless its toy
## ratio was under that): the aqueduct's arch (the kit's and the aqueduct
## isle's), the kit's gothic arch, THREAD, lancet and rose, the hall's lane,
## breach and broken arch, the token lines' air gap and wing box, the
## pierced isle's route, the ring arch (capped), the stone circle's gaps
## (SNUG at least) and its stones' heights; at the default sizes each keeps
## RATIO of its toy width in wingspans, and in the second run each is its
## toy width exactly. The knife-edge slots pass the plane only on its
## wingtip, the cockpit pilot is the walker's size, and the walker, sized as
## the game sizes him (PilotMotor.set_size), still catches the ledges the
## kit's climbing routes are laid on. A pure check of the derived numbers:
## nothing is built.
##   godot --headless --path . --script tests/test_world_scale_fit.gd
const WorldScale = preload("res://scripts/world_scale.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const Pierced = preload("res://scripts/pierced_isle.gd")
const AqIsle = preload("res://studies/aqueduct_isle.gd")
const AqChain = preload("res://studies/aqueduct_isle_chain.gd")
const AqArt = preload("res://studies/aqueduct_isle_art.gd")
const NaveArt = preload("res://studies/drowned_nave_isle_art.gd")
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const OLD := ["--plane-scale=1","--wanderer-scale=1","--opening-ratio=1"]

var failures := 0

func _initialize() -> void:
	var child := "--plane-scale=1" in OS.get_cmdline_user_args()
	var tag := "plane %.2f, wanderer %.2f, ratio %.2f" % [WorldScale.plane,WorldScale.wanderer,WorldScale.ratio]
	if child: check(is_equal_approx(WorldScale.plane,1.0) and is_equal_approx(WorldScale.wanderer,1.0) and is_equal_approx(WorldScale.ratio,1.0),"the flags set the old sizes and ratio 1 ("+tag+")")
	else: check(is_equal_approx(WorldScale.plane,WorldScale.PLANE) and is_equal_approx(WorldScale.wanderer,WorldScale.WANDERER) and is_equal_approx(WorldScale.ratio,WorldScale.RATIO),"the knobs' sizes and RATIO by default ("+tag+", ratio %.2f)" % WorldScale.ratio)
	_gaps(tag)
	_reach(tag)
	if not child: _old_sizes()
	print("PASS: world scale fit" if failures == 0 else "FAIL: world scale fit (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## Each flown opening from its toy width: [value, toy width, how] where
## how is "ratio" (opening()), "cap" (opening() capped: the ring), "snug"
## (no toy width flown: SNUG at least).
func _gaps(tag: String) -> void:
	var child := "--plane-scale=1" in OS.get_cmdline_user_args()
	var span := WorldScale.span
	check(is_equal_approx(span,WorldScale.TOY_SPAN*WorldScale.plane),"the span is the toy's times the plane (%.2f m, %s)" % [span,tag])
	var least := WorldScale.past_tip(WorldScale.gap(WorldScale.SNUG))
	check(least >= 1.2-0.001,"SNUG is 1.2 m past each tip (%.2f, %s)" % [least,tag])
	# opening(): toy x plane x ratio, never under SNUG unless the toy width
	# itself was, and exactly the toy width at plane 1 and ratio 1.
	check(is_equal_approx(WorldScale.opening(3.5),maxf(3.5*WorldScale.plane*WorldScale.ratio,minf(WorldScale.gap(WorldScale.SNUG),3.5*WorldScale.plane))),"opening(3.5) is toy x plane x ratio, floored (%.2f, %s)" % [WorldScale.opening(3.5),tag])
	# The stone circle's gap between two sarsens at their inner faces, where
	# the ring is narrowest: the chord there less a sarsen's width.
	var inner := RuinKit.CIRCLE_RADIUS-RuinKit.SARSEN.z*0.5
	var henge := 2.0*inner*sin(PI/RuinKit.CIRCLE_STONES)-RuinKit.SARSEN.x
	var gaps := {
		"aqueduct arch clear (Aqueduct.CLEAR)":[Aqueduct.CLEAR,Aqueduct.TOY_CLEAR,"ratio"],
		"the aqueduct isle's arches (AqueductIsleArt.CLEAR)":[AqArt.CLEAR,AqArt.TOY_CLEAR,"ratio"],
		"gothic arch (RuinKit.ARCH_SPAN)":[RuinKit.ARCH_SPAN,RuinKit.TOY_ARCH_SPAN,"ratio"],
		"threaded gap (RuinKit.THREAD)":[RuinKit.THREAD,RuinKit.TOY_THREAD,"ratio"],
		"lancet window (RuinKit.WINDOW.x)":[RuinKit.WINDOW.x,RuinKit.TOY_WINDOW,"ratio"],
		"rose's glass (RuinKit.ROSE)":[2.0*(RuinKit.ROSE.y-RuinKit.ROSE.z),RuinKit.TOY_ROSE,"ratio"],
		"hall lane (Hall.LANE)":[Hall.LANE.y-Hall.LANE.x,Hall.TOY_LANE,"ratio"],
		"hall breach corridor (Hall.BREACH_HALF)":[Hall.BREACH_HALF*2.0,Hall.TOY_BREACH,"ratio"],
		"hall broken arch (Hall.ARCH.x)":[Hall.ARCH.x,Hall.TOY_ARCH,"ratio"],
		"air token gap (CollectibleLines.GAP_ROOM)":[Lines.GAP_ROOM,Lines.TOY_GAP_ROOM,"ratio"],
		"token wing box (CollectibleLines.WING both sides)":[Lines.WING*2.0,Lines.TOY_WING*2.0,"ratio"],
		"pierced isle route corridor (ROUTE_CLEAR both sides)":[Pierced.ROUTE_CLEAR*2.0,Pierced.TOY_ROUTE,"ratio"],
		"ring arch on the lodestone's line (AqChain.RING_SPAN)":[RuinKit.ARCH_SPAN*AqChain.RING_SCALE,AqChain.TOY_RING,"cap"],
		"stone circle, sarsen to sarsen at their inner faces":[henge,RuinKit.TOY_HENGE,"snug"],
		"colonnade portal clear (2 x (Spine.ROW - ORDER))":[2.0*(Spine.ROW-RuinKit.ORDER),Spine.TOY_PORTAL,"ratio"],
		"colonnade north-row bay (Spine.OUT_PITCH)":[Spine.OUT_PITCH-2.0*Spine.PIER_SHAFT,Spine.TOY_OUT,"ratio"],
		"colonnade south-row bay (Spine.IN_PITCH)":[Spine.IN_PITCH-2.0*Spine.PIER_SHAFT,Spine.TOY_IN,"ratio"],
		"drowned nave crossing (NaveArt.CROSS_CLEAR)":[NaveArt.CROSS_CLEAR,NaveArt.TOY_CROSS,"ratio"],
		"cloister tarn water gate (between the piers' shafts)":[float(TarnArt.EAST_PIERS[TarnArt.EAST_PIERS.size()/2])-float(TarnArt.EAST_PIERS[TarnArt.EAST_PIERS.size()/2-1])-2.0*Cloister.PIER_REACH,TarnArt.TOY_GATE_PITCH-2.0*Cloister.PIER_REACH,"ratio"],
		"cloister tarn west gap stub slot (TarnArt.STUB_GAP)":[float(TarnArt.WEST_PIERS[4])-float(TarnArt.WEST_PIERS[3])-2.0*Cloister.PIER_REACH,TarnArt.TOY_STUB_PITCH-2.0*Cloister.PIER_REACH,"ratio"],
	}
	for name: String in gaps:
		var g: Array = gaps[name]
		var w := float(g[0])
		var toy := float(g[1])
		var past := WorldScale.past_tip(w)
		var want := WorldScale.opening(toy)
		if g[2] == "cap": want = minf(want,AqChain.RING_MOST)
		if g[2] == "snug": want = maxf(want,WorldScale.gap(WorldScale.SNUG))
		check(absf(w-want) < 0.02,"%s %.2f m is its toy %.2f m's opening (%.2f; %.2f m past each tip, %s)" % [name,w,toy,want,past,tag])
		if child and g[2] != "snug":
			check(absf(w-toy) < 0.01,"%s is its toy width %.2f exactly at plane 1, ratio 1 (%.2f)" % [name,toy,w])
		elif not child and g[2] == "ratio" and toy*WorldScale.plane*WorldScale.ratio >= WorldScale.gap(WorldScale.SNUG):
			var spans := (w/span)/(toy/WorldScale.TOY_SPAN)
			check(absf(spans-WorldScale.ratio) < 0.01,"%s keeps %.2f of its toy ratio to the wingspan (%.2f spans, the toy %.2f)" % [name,spans,w/span,toy/WorldScale.TOY_SPAN])
		var floor_past := minf(least,WorldScale.past_tip(toy*WorldScale.plane))
		check(past >= floor_past-0.03,"%s passes the %.2f m span, %.2f m past each tip (at least %.2f, %s)" % [name,span,past,floor_past,tag])
	# The stone circle's stones stand as tall as the toy's in wingspans, and
	# the great trilithon with them, but never more than a pumped catch
	# (TRILITHON_RISE) over the sarsens.
	var heights := {"a sarsen (RuinKit.SARSEN.y)":[RuinKit.SARSEN.y,RuinKit.TOY_SARSEN.y,INF],"the great trilithon (RuinKit.TRILITHON.y)":[RuinKit.TRILITHON.y,RuinKit.TOY_TRILITHON.y,RuinKit.SARSEN.y+RuinKit.TRILITHON_RISE]}
	for name: String in heights:
		var h: Array = heights[name]
		var want := minf(WorldScale.opening(float(h[1])),float(h[2]))
		check(absf(float(h[0])-want) < 0.02 and (not child or absf(float(h[0])-float(h[1])) < 0.01),"%s stands %.2f m, its toy %.2f m's opening, capped %.2f (%s)" % [name,float(h[0]),float(h[1]),want,tag])
	check(RuinKit.TRILITHON.y-RuinKit.SARSEN.y <= RuinKit.TRILITHON_RISE+0.01,"the great trilithon stands %.2f m over the ring, a pumped catch from the back lintel (%s)" % [RuinKit.TRILITHON.y-RuinKit.SARSEN.y,tag])
	# The ring's lintels a jump-catch from the leaning stone's head and the
	# fallen trilithon's stub (the walker's, whatever their height).
	var ring_top := RuinKit.SARSEN.y+RuinKit.LINTEL.y
	check(ring_top-RuinKit.STUB <= 1.5+0.01,"the fallen trilithon's stub %.2f m is a jump under the lintels' top %.2f (%s)" % [RuinKit.STUB,ring_top,tag])
	# The knife-edge slots: under the span (level, the wings catch), over
	# the plane's height on its wingtip.
	var tall := WorldScale.TOY_TALL*WorldScale.plane
	var knives := {
		"the great trilithon's slot (RuinKit.TRILITHON_SLOT)":RuinKit.TRILITHON_SLOT,
		"the aqueduct isle's stumps (AqueductIsle.stump_slot)":AqIsle.stump_slot(),
		"a hall's knife slit (Hall.KNIFE.x)":Hall.KNIFE.x,
	}
	for name: String in knives:
		var w := float(knives[name])
		check(w < span and w > tall+0.2,"%s %.2f m: a knife edge, under the %.2f m span, %.2f m round the plane on its wingtip (%s)" % [name,w,span,(w-tall)*0.5,tag])
	# The cockpit pilot drawn the walker's size: his own scale times the
	# ground cheat's times the plane's is PILOT_RATIO times the walker's.
	var pilot := WorldScale.pilot_size*WorldScale.ground_factor()*WorldScale.plane
	check(is_equal_approx(pilot,WorldScale.PILOT_RATIO*WorldScale.wanderer) and WorldScale.pilot_size <= WorldScale.PILOT_MOST,"the cockpit pilot is the walker's size (drawn %.2f, cheat %.2f, %s)" % [WorldScale.pilot_size,WorldScale.ground_factor(),tag])
	if not "--plane-scale=1" in OS.get_cmdline_user_args():
		check(is_equal_approx(WorldScale.ground_factor(),1.0),"no ground cheat at the game's sizes (%.3f)" % WorldScale.ground_factor())

## The walker's catch tops, from his sized jumps and hang, over the kit's
## ledges (each a margin under, as test_ruin_kit holds them).
func _reach(tag: String) -> void:
	var m := PilotMotor.new()
	m.set_size(WorldScale.wanderer)
	var first: float = float(m.jumps[0])+m.hang_drop+PilotMotor.GRAB_LOW
	var pump: float = float(m.jumps[1])+m.hang_drop+PilotMotor.GRAB_LOW
	print("     catch tops %.3f (jump) and %.3f (pump), %s" % [first,pump,tag])
	check(is_equal_approx(first,RuinKit.GRAB_TOP) and is_equal_approx(pump,RuinKit.CHAIN_TOP),"his catch tops are the kit's GRAB_TOP and CHAIN_TOP (%s)" % tag)
	var once := {
		"a set-off (SET_OFF)":RuinKit.SET_OFF,
		"a window sill (WINDOW.y)":RuinKit.WINDOW.y,
		"the chest's top (CHEST.z)":RuinKit.CHEST.z,
		"the vault walls' lowest step":float(RuinKit.VAULT_STEPS[-1]),
		"a stump's step (Aqueduct.STUMP.x)":Aqueduct.STUMP.x,
	}
	for name: String in once:
		check(float(once[name]) < first-0.2+0.001,"%s %.2f m is caught with one jump (%s)" % [name,float(once[name]),tag])
	check(RuinKit.WALL_HEIGHT > first and RuinKit.WALL_HEIGHT < pump-0.1,"a wall %.2f m is caught from the pump, not one jump (%s)" % [RuinKit.WALL_HEIGHT,tag])
	check(Aqueduct.STUMP.y < pump,"a stump %.2f m is climbed from the water (%s)" % [Aqueduct.STUMP.y,tag])
	check(m.climb_in+RuinKit.BODY <= RuinKit.STAND+0.001,"a STAND-deep top holds him climbed in (%s)" % tag)

## The same checks at the old sizes, in a second run.
func _old_sizes() -> void:
	var out := []
	var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/test_world_scale_fit.gd","--"]+OLD)
	var code := OS.execute(OS.get_executable_path(),args,out,true)
	var text := "".join(out)
	for line in text.split("\n"):
		if line.begins_with("OK ") or line.begins_with("FAIL ") or line.begins_with("     "): print("  [old] "+line)
	check(code == 0 and "PASS: world scale fit" in text,"the old sizes (%s) fit too (exit %d)" % [" ".join(OLD),code])
