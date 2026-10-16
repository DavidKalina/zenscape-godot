extends "res://studies/kit_isle.gd"
## The motif yard: ONE motif
## stood on the real stage with nothing else in the world, to prove its
## chains fast. A chain proven here holds in a layer, because everything
## that moves goes through the generator's own paths:
##   - the study base run_layer stands on (studies/kit_isle.gd, under the
##     aqueduct isle): the same pilot, motor, input, camera and tick, so
##     tools/harness/drive.gd drives it unchanged;
##   - the motif's art built by its own `build` (turf, or its grey boxes with
##     --grey, which sets the motif's own grey flag) as a placed isle
##     (scripts/kit_isle/motif_isle.gd in a scripts/kit_isle/motif_sky.gd,
##     as run_layer's sky has them: turf, flora and life);
##   - its live parts through scripts/roguelike/layer_stage.gd `setup`
##     (layer_greybox.gd `dress`: its traps, ropes and cannons; layer_
##     enemies.gd `dress`: its heads, laid by LayerGreybox `lay_heads` with
##     the generator's knobs, routes and cliffs, and their bodies);
## fed a one-isle plan (`yard_plan`: the motif at `--at=` (the origin), no
## edges, no gulfs, no ram, cannon, prize or gate). No run loop, no void
## card that lays a new layer: a fall past the net (NET m under the motif's
## lowest solid) sets him back at the start.
##
##   godot --path . res://studies/motif_yard.tscn -- --no-title --motif=<slug>
##     [--grey]          the motif's grey boxes (its own --<x>-grey flag)
##     [--bodies=0|1]    the heads' headless bodies (1, the generator's default)
##     [--rims]          stand-in pads off the way-in and way-out rims, a
##                       route stride off each lip (the generator's sizes)
##     [--at=x,y,z]      the motif's offset (default the origin)
##     [--sky]           the sky's clouds, motes, gulls and tokens too (off
##                       by default: the yard is for checks; stills want it)
##     [--plane]         the plane parked on the motif's landing strip (its
##                       `plane_park()`, else open turf near the start, as
##                       the kit isle parks it), once the motif stands: board,
##                       fly and land it by hand as in the game. Off: no plane
## `<slug>`: a greybox motif (scripts/kit_isle/greybox/registry.gd: sunken_
## giant, wardens_well, lidstack, plumb_well, vigil_bellows, noon_weir) or a
## kit motif of LayerPlan POOL (bell_spires...: stood, no heads).
##   R   back at the start, the stage (traps, heads, cannons) as built
## Chain checks: tools/harness/chain.gd (tools/README.md).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerStage = preload("res://scripts/roguelike/layer_stage.gd")
const LayerGreybox = preload("res://scripts/roguelike/layer_greybox.gd")
const LayerEnemies = preload("res://scripts/roguelike/layer_enemies.gd")
const Registry = preload("res://scripts/kit_isle/greybox/registry.gd")
const MotifSky = preload("res://scripts/kit_isle/motif_sky.gd")
const YardSky = preload("res://studies/motif_yard_sky.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## Each greybox motif's own grey flag (its `grey()`), which --grey sets.
const GREY_FLAGS := {
	"sunken_giant":"--giant-grey","wardens_well":"--wardens-well-grey","lidstack":"--lidstack-grey",
	"plumb_well":"--well-grey","vigil_bellows":"--vigil-grey","noon_weir":"--weir-grey",
}
## The net: this far (m) under the motif's lowest solid.
const NET := 60.0
## The yard plan's seed (the stage's stones and bridges seed from it; none
## stand here).
const SEED := 1

## The motif asked for (its slug or pool id), grey or turf, its offset.
var motif_slug := ""
var grey := false
var offset := Vector3.ZERO
var rims_on := false
## --plane: the plane parked on the motif's strip (`park_home`).
var plane_on := false
## The one-isle plan (`yard_plan`) and the stage stood from it.
var layer: Dictionary = {}
var stage: Node3D = null
## The motif's isle (scripts/kit_isle/motif_isle.gd) and its holder.
var motifs: Node3D = null
## The stand-in rim pads (--rims), or null.
var rim_pads: Node3D = null
var net_y := -INF
var _slot_was: Node = null
var _card: Label

func _ready() -> void:
	var args := LaunchArgs.user_args()
	for a: String in args:
		if a.begins_with("--motif="): motif_slug = a.get_slice("=",1).trim_prefix("gb_")
		elif a == "--grey": grey = true
		elif a == "--rims": rims_on = true
		elif a == "--plane": plane_on = true
		elif a.begins_with("--at="): offset = _vec(a.get_slice("=",1))
	if motif_slug == "":
		push_warning("motif yard: no --motif=<slug> (%s); plumb_well" % ", ".join(PackedStringArray(Registry.MOTIFS.keys())))
		motif_slug = "plumb_well"
	# --grey is the motif's own flag, set before its occupancy is computed
	# (its grey boxes and its turf keels differ).
	if grey and GREY_FLAGS.has(motif_slug) and not args.has(GREY_FLAGS[motif_slug]):
		var with := PackedStringArray(args)
		with.append(GREY_FLAGS[motif_slug])
		LaunchArgs.set_override(with)
	var knobs := LayerPlan.knobs_from(LaunchArgs.user_args())
	for a: String in args:
		if a.begins_with("--bodies="): knobs.bodies = int(a.get_slice("=",1))
	layer = yard_plan(motif_slug,offset,knobs)
	if layer.is_empty():
		push_error("motif yard: no motif '%s'" % motif_slug)
		layer = yard_plan("plumb_well",offset,{})
	_no_lode = true
	var spawn: Dictionary = layer.spawn
	start = spawn.at
	var face: Vector3 = spawn.face
	start_face = Vector2(face.x,face.z).normalized()
	net_y = float(layer.void_y)
	lost = net_y
	isle_ready.connect(_first_layer,CONNECT_ONE_SHOT)
	super._ready()

# --- The plan --------------------------------------------------------------------------

## A one-isle plan for motif `slug` at `at`: every field LayerStage,
## LayerGreybox, LayerEnemies `dress` and LayerBodies `cliffs` read, the
## isle made as the generator makes one (LayerPlan `_motif_isle`), its
## heads laid by LayerGreybox `lay_heads`. {} for an unknown slug.
static func yard_plan(slug: String, at: Vector3, knobs := {}) -> Dictionary:
	var pick: Array = []
	if Registry.MOTIFS.has(slug): pick = ["gb_"+slug,Registry.MOTIFS[slug],Registry.WEIGHT]
	else:
		for p: Array in LayerPlan.POOL:
			if str(p[0]) == slug: pick = p
	if pick.is_empty(): return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([slug,"yard"])
	var isle: Dictionary = LayerPlan._motif_isle(pick,rng)
	isle.role = "route"
	isle.hood = 0
	isle.offset = at
	isle.sockets = []
	for s: Dictionary in isle.own: isle.sockets.append(LayerPlan._world(s,at))
	var m: RefCounted = isle.motif
	var span := LayerPlan._span(isle)
	# The spawn: the motif's start (a greybox's), else its way in; facing in
	# off its way-in rim.
	var rims: Array = (isle.sockets as Array).filter(func(s: Dictionary) -> bool: return s.kind == "rim")
	var first: Dictionary = rims[0] if not rims.is_empty() else {}
	var spawn_at: Vector3 = (m.start()+at) if m.has_method("start") else (first.get("at",Vector3(0.0,span.y,0.0)) as Vector3)
	var face: Vector3 = -(first.get("face",Vector3.BACK) as Vector3)
	var all_knobs: Dictionary = LayerPlan.KNOBS.duplicate()
	all_knobs.merge(knobs,true)
	# No generator heads, no hazards (they're the layer's, not the motif's).
	all_knobs.heads = 0
	all_knobs.arrows = 0
	all_knobs.viaduct = 0
	var plan := {
		"seed":SEED,"knobs":all_knobs,"shape":"yard",
		"isles":[isle],"edges":[],"hoods":[[0]],"gulfs":[],"route":[0],"tubes":[],"arrows":[],
		"exit":{},"prize":{},"cannon":{},"ram":{},"heads":[],
		"spawn":{"at":spawn_at,"face":face},
		"void_y":span.x-NET,"problems":[],
	}
	# A motif's own guacharos (`flyers()`: [{home, grace, range}] in its
	# frame), laid by LayerFlyers as the flyer yard's are.
	if m.has_method("flyers"):
		plan.flyers = (m.flyers() as Array).map(func(f: Dictionary) -> Dictionary:
			var o := f.duplicate()
			o.home = (f.home as Vector3)+at
			if f.has("floor"): o.floor = float(f.floor)+at.y
			return o)
	LayerGreybox.lay_heads(plan,LayerEnemies.numbers())
	return plan

## The plan's motif isle for the sky: [motif, offset, place] (run_layer's
## `layer_entries`).
func layer_entries() -> Array:
	var out: Array = []
	for isle: Dictionary in layer.get("isles",[]):
		var r: Rect2 = LayerPlan._rect(isle)
		var c := r.get_center()
		out.append([isle.motif,isle.offset,[isle.id,Vector3(c.x,LayerPlan._span(isle).y,c.y),r.size.length()*0.5]])
	return out

func sky_script() -> Script:
	return YardSky

# --- Standing it -----------------------------------------------------------------------

## Once he walks (`isle_ready`, as run_layer's `_first_layer`): the motif's
## art stood at once (its plants and life follow, a slice a frame), the
## stage, the pilot at the start.
func _first_layer() -> void:
	_slot_was = foot_pieces
	motifs = sky.motifs if sky != null else null
	if motifs == null:
		# --no-sky: the motif's isle held here.
		motifs = MotifSky.new()
		add_child(motifs)
		motifs.setup_layer(self,null,LaunchArgs.user_args(),layer_entries())
	# Headless the art is built here, at once. Rendered it is on a worker
	# already (never waited for here: the worker's servers' calls wait on
	# this thread), and he is held at the start till it stands (`tick`).
	if not motifs.threaded:
		for isle: Node3D in motifs.isles:
			isle.build_now()
			while str(isle.stage) in ["built","standing"]: isle.work(1 << 30)
	stage = LayerStage.new()
	add_child(stage)
	stage.setup(self,layer,_slot_was)
	if rims_on: _rim_pads()
	_build_card()
	respawn()
	_last_stood = start
	print("motif yard: %s (%s) stood at %s, %d head(s), net at %.0f m" % [motif_slug,"grey" if grey else "turf",str(offset),(layer.heads as Array).size(),net_y])

## A flat pad off the way-in and the way-out rims, a route stride across
## the drop from each lip (LayerPlan `reach` x the mean GAP_SHARE) at the
## rim's height, three stepping stones (LayerPlan `stone_length`) square:
## the generator's crossing's first stone, stood in.
func _rim_pads() -> void:
	rim_pads = Node3D.new()
	rim_pads.name = "RimPads"
	add_child(rim_pads)
	var gap := LayerPlan.reach(0.0)*(LayerPlan.GAP_SHARE.x+LayerPlan.GAP_SHARE.y)*0.5
	var side := LayerPlan.stone_length()*3.0
	var isle: Dictionary = layer.isles[0]
	for s: Dictionary in isle.sockets:
		if s.kind != "rim": continue
		var face: Vector3 = s.face
		face.y = 0.0
		face = face.normalized()
		var lip: Vector3 = (s.at as Vector3)+face*float(s.get("lip",1.0))
		var mid := lip+face*(gap+side*0.5)
		var body := StaticBody3D.new()
		body.name = "Pad_%s" % str(s.name)
		body.collision_layer |= TURF_LAYER
		body.transform = Transform3D(Basis.looking_at(face,Vector3.UP),mid+Vector3.DOWN*0.5)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(side,1.0,side)
		shape.shape = box
		body.add_child(shape)
		var drawn := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		drawn.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.44,0.74,0.4)
		drawn.material_override = mat
		body.add_child(drawn)
		rim_pads.add_child(body)
		_turf_rids.append(body.get_rid())
		print("motif yard: rim pad off %s (%s), %.1f m across the drop" % [str(s.name),str(s.get("way","")),gap])

# --- The isle's hooks ------------------------------------------------------------------

func isle_name() -> String:
	return "motif yard"

func isle_top() -> float:
	var isle: Dictionary = layer.isles[0] if not layer.is_empty() else {}
	return float(isle.motif.top())+offset.y if not isle.is_empty() else TOP

func isle_summit() -> Vector3:
	var isle: Dictionary = layer.isles[0] if not layer.is_empty() else {}
	return (isle.motif.summit() as Vector3)+offset if not isle.is_empty() else super.isle_summit()

func capture_look() -> Vector3:
	return isle_summit()

## No plane parked unless --plane (it would stand on the motif); with it,
## parked at `plane_home` once the motif stands under it (`tick`), so its
## wheels rest on the motif's turf.
func park_home() -> void:
	if not plane_on or not motif_stands(): return
	super.park_home()

## The motif's own parking spot (`plane_park()`: x, y, z its turf, w its
## heading, in its frame), else the kit isle's search round the start.
func plane_home() -> Vector4:
	var isle: Dictionary = layer.isles[0] if not layer.is_empty() else {}
	if not isle.is_empty() and isle.motif.has_method("plane_park"):
		var p: Vector4 = isle.motif.plane_park()
		return Vector4(p.x+offset.x,p.y+offset.y,p.z+offset.z,p.w)
	return super.plane_home()

## The yard's own ground has no plants or life (the motif's isle has its own).
func _grow() -> void:
	if not _turf.is_empty(): super._grow()

func _add_life() -> void:
	pass

## Down off the edge he falls till he lands or meets the net (run_layer's).
func _strand() -> void:
	pass

# --- The loop --------------------------------------------------------------------------

## True once the motif's art stands (rendered, it is built on a worker).
func motif_stands() -> bool:
	if motifs == null: return false
	for isle: Node3D in motifs.isles:
		if not isle.stands(): return false
	return true

var _held := true

func tick(delta: float) -> void:
	if _held:
		# Held at the start till the motif stands under him.
		if not motif_stands(): return
		_held = false
		respawn()
		if plane_on and not flying and not parked: park_home()
	super.tick(delta)
	if flying: return
	# The net (off the edge the study's own `lost` is held off).
	if motor.feet.y < net_y:
		_end_fall()
		respawn()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R and walk_ready and stage != null:
		reset_yard()
		return
	super._unhandled_input(event)

## The stage as built (traps, heads, cannons, the greybox's live bits) and
## him at the start.
func reset_yard() -> void:
	if stage != null: stage.reset()
	_end_fall()
	respawn()

# --- The card --------------------------------------------------------------------------

func _build_card() -> void:
	var holder := CanvasLayer.new()
	holder.name = "YardCard"
	add_child(holder)
	_card = Label.new()
	_card.add_theme_font_size_override("font_size",18)
	_card.add_theme_color_override("font_color",Color("fbf6ea"))
	_card.add_theme_color_override("font_shadow_color",Color(0,0,0,0.75))
	_card.position = Vector2(16.0,12.0)
	holder.add_child(_card)
	var isle: Dictionary = layer.isles[0]
	_card.text = "Motif yard · %s (%s)%s%s · R start again" % [str(isle.motif.isle_name()),"grey" if grey else "turf",", rims" if rims_on else "",", plane" if plane_on else ""]
