extends Node3D
## The Sluice Flush in context (scripts/traps/trap_sluice.gd): on the aqueduct
## isle's own channel
## (studies/aqueduct_isle.gd, and the game, studies/zenscape.tscn), with
## `--sluice`; off, nothing is laid and nothing changes.
##
## Sized from the isle as drawn (studies/aqueduct_isle_art.gd), never
## copied: the gate stands where the parapets start past the head, its
## gatehouse on the west parapet, the castellum's feed (a greybox trough off
## the water tower's crown) coming into it; the plate a run's 0.9 s in, where
## a walker up the rubble slope steps onto the channel; the channel's floor
## runs to the snap, the fallen span's gap (Art RESUME less SNAP) is the
## trap's gap, and the far run to the deck's end is its floor past the gap,
## so the wave spills over the gap and on off the end. Its width is the
## clear between the parapets, the wave covers the deck (over the parapets,
## which are not high enough), the water it drains is the channel's own.
## The refuges: the gatehouse's top, and a fallen block on the west parapet
## over the first open pier (the rope beams over the east parapet, with the
## foot pieces, are over the wave too).
##
## It stands in the study's `foot_pieces` slot and steps whatever stood
## there before it (the isle's foot pieces) as ever, then the trap.
## `--sluice=head` starts on foot at the top of the rubble slope, facing up
## the channel. `--sluice-knob=<key>=<value>` (repeatable) overrides a knob.
const Sluice = preload("res://scripts/traps/trap_sluice.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## Where the parapets start past the head (Art `_parapets`: HEAD+0.4).
const GATE_IN := 0.4
## The feed's width and depth (m), and the camera's angle at the start.
const FEED := Vector2(0.6,0.35)
const START_POLAR := 1.25

var study: Node3D
var motor: Object
## What stood in the slot before (the isle's foot pieces), or null.
var inner: Node = null
var trap: Node3D

static func wanted(args: PackedStringArray = LaunchArgs.user_args()) -> bool:
	for arg in args:
		if arg == "--sluice" or arg.begins_with("--sluice="): return true
	return false

## The trap on `scene` (the aqueduct isle) with --sluice, or null.
static func build(scene: Node3D) -> Node3D:
	if not wanted(): return null
	var hook: Node3D = new()
	hook.attach(scene)
	return hook

## The trap's frame: at the gate on the channel's floor, the route down the
## channel (world -z).
static func trap_frame() -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3(Art.MID_X,Art.TOP+Art.DECK,-(Art.HEAD+GATE_IN)))

## Its knobs on the isle: the channel's real sizes, the pilot's for the rest.
static func knobs() -> Dictionary:
	var p: Object = Sluice.pilot()
	var gate := Art.HEAD+GATE_IN
	var first_pier: float = Art.pier(2)
	return {
		"walls":false,"gate":"side","gate_side":-1.0,
		"length":Art.SNAP-gate,"gap":Art.RESUME-Art.SNAP,"beyond":Art.END-Art.RESUME,"end":"open",
		"width":(Art.PARAPET_Z-Art.PARAPET.x)*2.0,"parapet":Vector2(Art.PARAPET.x*2.0,Art.PARAPET.y),"cover":Art.FACE,
		"flow":Art.WATER_LIFT,"tell_time":3.0,"wave_length":p.run*1.5,
		"refuge_top":float(p.jumps[0])*1.25,"refuges":[[first_pier-gate,-1.0]],
	}

## `--sluice-knob=<key>=<value>` overrides: a number, true/false, or a word.
static func knob_args() -> Dictionary:
	var over := {}
	for arg in LaunchArgs.user_args():
		if not arg.begins_with("--sluice-knob="): continue
		var pair := arg.trim_prefix("--sluice-knob=")
		var value := pair.get_slice("=",1)
		var parsed: Variant = value
		if value.is_valid_float(): parsed = value.to_float()
		elif value == "true" or value == "false": parsed = value == "true"
		over[pair.get_slice("=",0)] = parsed
	return over

func _init() -> void:
	name = "Sluice"

## Laid on `scene` and hooked into its frame, round what was there.
func attach(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	inner = scene.foot_pieces
	scene.foot_pieces = self
	scene.add_child(self)
	trap = Sluice.new()
	trap.configure(knobs())
	trap.configure(knob_args())
	trap.motor = scene.motor
	trap.transform = trap_frame()
	var art: Node = scene.get("art")
	if art != null: trap.adopt_water(art.get_node_or_null("Channel"))
	add_child(trap)
	add_child(_feed())
	if "--sluice=head" in LaunchArgs.user_args() and scene.has_signal("isle_ready"):
		scene.isle_ready.connect(_start_at_head,CONNECT_ONE_SHOT)

## The castellum's feed: a trough from the water tower's crown down into the
## gatehouse's back, water in it (drawn only).
func _feed() -> Node3D:
	var house_mid: Vector3 = trap.to_global(Vector3(float(trap.knob("gate_side"))*(trap.channel()*0.5+trap.parapet().x*2.5),trap.refuge_top()*0.55,-Sluice.HOUSE_LONG*0.5-0.2))
	var from := Vector3(Art.CASTELLUM_X,Art.TOP+Art.CASTELLUM_CROWN-0.3,house_mid.z)
	var to := house_mid
	var way := to-from
	var node := Node3D.new()
	node.name = "Feed"
	var trough := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(way.length(),FEED.y,FEED.x)
	trough.mesh = box
	trough.material_override = Sluice.paint(Sluice.STONE.darkened(0.1))
	var water := MeshInstance3D.new()
	var film := BoxMesh.new()
	film.size = Vector3(way.length(),0.04,FEED.x*0.7)
	water.mesh = film
	var wet := Sluice.paint(Sluice.WATER)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = wet
	water.position.y = FEED.y*0.5+0.01
	trough.add_child(water)
	var tilt := atan2(way.y,Vector2(way.x,way.z).length())
	trough.transform = Transform3D(Basis(Vector3.FORWARD,tilt),(from+to)*0.5)
	node.add_child(trough)
	return node

func _start_at_head() -> void:
	var at := Vector3(Art.MID_X,Art.TOP+Art.DECK,-Art.HEAD+0.6)
	study.start = at
	study.start_face = Vector2(0.0,-1.0)
	study.place(at,Vector2(0.0,-1.0))
	study.set("_yaw",0.0)
	study.set("_polar",START_POLAR)
	study.set("_last_stood",at)

# --- The slot: what stood there, then the trap --------------------------------

func before(delta: float) -> void:
	if inner != null: inner.before(delta)
	trap.before(delta)

func after(delta: float, events: Dictionary) -> void:
	if inner != null: inner.after(delta,events)
	trap.after(delta,events)

func pose(figure: Node3D) -> void:
	if inner != null: inner.pose(figure)
	trap.pose(figure)

func frame(camera: Camera3D, delta: float) -> void:
	if inner != null and inner.has_method("frame"): inner.frame(camera,delta)

func reset() -> void:
	trap.reset()
