extends SceneTree
## The game's sizes still fit the world (scripts/world_scale.gd, docs/design/
## plane-ground-scale.md), headless, at the default sizes and again at
## `--plane-scale=1 --wanderer-scale=1` (a second Godot run of this script,
## since WorldScale reads its flags once): the flown openings (the
## aqueduct's arch, the kit's gothic arch, THREAD, window and rose, the
## stone circle's gaps, the hall's lane, breach and arch, the ring arch, the
## token lines' and pierced isle's clearances) leave the plane at least
## SNUG's 1.2 m past each wingtip, the knife-edge slots pass it only on its
## wingtip, the cockpit pilot is the walker's size, and the walker,
## sized as the game sizes him (PilotMotor.set_size), still catches the
## ledges the kit's climbing routes are laid on (tests/test_ruin_kit.gd
## `_scale`, the aqueduct isle's routes). A pure check of the derived
## numbers: nothing is built.
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
const OLD := ["--plane-scale=1","--wanderer-scale=1"]

var failures := 0

func _initialize() -> void:
	var child := "--plane-scale=1" in OS.get_cmdline_user_args()
	var tag := "plane %.2f, wanderer %.2f" % [WorldScale.plane,WorldScale.wanderer]
	if child: check(is_equal_approx(WorldScale.plane,1.0) and is_equal_approx(WorldScale.wanderer,1.0),"the flags set the old sizes ("+tag+")")
	else: check(is_equal_approx(WorldScale.plane,WorldScale.PLANE) and is_equal_approx(WorldScale.wanderer,WorldScale.WANDERER),"the knobs' sizes by default ("+tag+")")
	_gaps(tag)
	_reach(tag)
	if not child: _old_sizes()
	print("PASS: world scale fit" if failures == 0 else "FAIL: world scale fit (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## Each flown gap is the plane's span and room past its tips: at least
## WorldScale.SNUG's 1.2 m past each tip (the world spaced out, feature/
## world-spacing), but for the knife-edge slots, which a level plane can't
## pass and one on its wingtip can.
func _gaps(tag: String) -> void:
	var span := WorldScale.span
	check(is_equal_approx(span,WorldScale.TOY_SPAN*WorldScale.plane),"the span is the toy's times the plane (%.2f m, %s)" % [span,tag])
	var least := WorldScale.past_tip(WorldScale.gap(WorldScale.SNUG))
	check(least >= 1.2-0.001 and WorldScale.past_tip(WorldScale.gap()) >= least,"SNUG is 1.2 m past each tip and ROOM more (%.2f, %.2f, %s)" % [least,WorldScale.past_tip(WorldScale.gap()),tag])
	# The stone circle's gap between two sarsens at their inner faces, where
	# the ring is narrowest: the chord there less a sarsen's width.
	var inner := RuinKit.CIRCLE_RADIUS-RuinKit.SARSEN.z*0.5
	var henge := 2.0*inner*sin(PI/RuinKit.CIRCLE_STONES)-RuinKit.SARSEN.x
	var gaps := {
		"aqueduct arch clear (Aqueduct.CLEAR)":Aqueduct.CLEAR,
		"gothic arch (RuinKit.ARCH_SPAN)":RuinKit.ARCH_SPAN,
		"threaded gap (RuinKit.THREAD)":RuinKit.THREAD,
		"lancet window (RuinKit.WINDOW.x)":RuinKit.WINDOW.x,
		"rose's glass (RuinKit.ROSE)":2.0*(RuinKit.ROSE.y-RuinKit.ROSE.z),
		"stone circle, sarsen to sarsen at their inner faces":henge,
		"hall lane (Hall.LANE)":Hall.LANE.y-Hall.LANE.x,
		"hall breach corridor (Hall.BREACH_HALF)":Hall.BREACH_HALF*2.0,
		"hall broken arch (Hall.ARCH.x)":Hall.ARCH.x,
		"ring arch on the lodestone's line (AqChain)":RuinKit.ARCH_SPAN*AqChain.RING_SCALE,
		"air token gap (CollectibleLines.GAP_ROOM)":Lines.GAP_ROOM,
		"pierced isle route corridor (ROUTE_CLEAR both sides)":Pierced.ROUTE_CLEAR*2.0,
		"token wing clearance (CollectibleLines.WING both sides)":Lines.WING*2.0,
	}
	for name: String in gaps:
		var past := WorldScale.past_tip(float(gaps[name]))
		check(past >= least-0.03,"%s %.2f m passes the %.2f m span, %.2f m past each tip (%s)" % [name,float(gaps[name]),span,past,tag])
	# The knife-edge slots: under the span (level, the wings catch), over
	# the plane's height on its wingtip.
	var tall := WorldScale.TOY_TALL*WorldScale.plane
	var knives := {
		"the great trilithon's slot (RuinKit.TRILITHON_SLOT)":RuinKit.TRILITHON_SLOT,
		"the aqueduct isle's stumps (AqueductIsle.STUMP_SLOT)":AqIsle.STUMP_SLOT,
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
