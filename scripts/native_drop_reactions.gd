class_name NativeDropReactions
extends Node3D
## Short reactions played when the editor commits a placed object. The saved
## record is never touched: a reaction only writes a visual offset onto the
## rendered instance, and that offset resolves to exact identity on its last
## frame, so the object ends on the committed pose the refresh already wrote.
##
## Plants sprout out of the ground with the source's easeOutBack overshoot
## (foliage.js GROW_GLSL, c1 = 1.70158), scaled about the record's origin the
## way the source scales about the instance matrix origin. Everything else
## falls the last little way onto the ground and kicks up dust.
##
## Only a fresh placement reacts. A redo, a load and every other rebuild that
## re-renders an existing record restore it silently: `play` is handed the id
## the placement just minted, and refuses any record that is not it.
##
## Refresh policy: a reaction is dropped the moment a full rebuild replaces the
## batches (`GardenView.revision` changes) or its instance disappears. The
## rebuild has already written the committed transform, so dropping leaves the
## finished state rather than a partial one; `finished` still fires.

## How each placeable asset arrives. Living things grow, so they sprout; the
## Bigfoot tree sprouts and thumps the ground. Dead wood is set down rather
## than grown, so a stump or a snag settles: a short low fall and a small puff,
## no squash, because a dead trunk has no give in it. A log lands and rocks to
## rest on its round side. Loose stone and the arch fall far enough to squash
## and throw real dust. Every id in NativeTerrainData.ASSETS but "waterfall"
## appears here; anything missing simply does not react.
const REACTIONS := {
	"leaf_bed":"settle",
	"tree":"sprout",
	"redwood":"sprout",
	"fern":"sprout",
	"flower":"sprout",
	"broadleaf":"sprout",
	"joshua":"sprout",
	"birch":"sprout",
	"willow":"sprout",
	"juniper":"sprout",
	"shrub":"sprout",
	"reeds":"sprout",
	"bank_grass":"sprout",
	"grass_tuft":"sprout",
	"button_flower":"sprout",
	"spike_flower":"sprout",
	"umbel_flower":"sprout",
	"daisy_flower":"sprout",
	"oxeye_daisy":"sprout",
	"buttercup":"sprout",
	"dandelion":"sprout",
	"dandelion_clock":"sprout",
	"cosmos":"sprout",
	"sunflower":"sprout",
	"poppy":"sprout",
	"lupine":"sprout",
	"wheat":"sprout",
	"mushroom":"sprout",
	"bigfoot_tree":"thump",
	"rock":"drop",
	"arch":"drop",
	"boulder_1":"drop",
	"boulder_2":"drop",
	"boulder_3":"drop",
	"boulder_4":"drop",
	"stump":"settle",
	"snag":"settle",
	"log":"roll",
	"stone_lamp":"settle",
	"campfire":"settle",
}
const SPROUT_DURATION := 0.4
const DROP_DURATION := 0.46
const SETTLE_DURATION := 0.34
const ROLL_DURATION := 0.46
const BIGFOOT_DURATION := 0.7
## The share of a falling reaction spent in the air; the rest is the landing.
const FALL_FRACTION := 0.5
## Each style, in one row: how long it runs, how much of that is the fall, how
## far above the ground it starts in record scales, how hard it squashes, how
## far it rocks in radians and how big its dust puff is against a rock's. The
## two grow styles use the easeOutBack curve and none of the falling columns.
const STYLES := {
	"sprout":{"grow":true,"duration":SPROUT_DURATION,"fall":0.0,"height":0.0,"squash":0.0,"rock":0.0,"dust":0.0},
	"thump":{"grow":true,"duration":BIGFOOT_DURATION,"fall":0.0,"height":0.0,"squash":0.0,"rock":0.0,"dust":0.0},
	"drop":{"grow":false,"duration":DROP_DURATION,"fall":FALL_FRACTION,"height":1.1,"squash":0.26,"rock":0.0,"dust":1.0},
	"settle":{"grow":false,"duration":SETTLE_DURATION,"fall":0.72,"height":0.34,"squash":0.0,"rock":0.0,"dust":0.55},
	"roll":{"grow":false,"duration":ROLL_DURATION,"fall":0.55,"height":0.55,"squash":0.0,"rock":0.22,"dust":0.7},
}
## Source easeOutBack: 1 + c3 b^3 + c1 b^2, exactly 0 at t=0 and 1 at t=1.
const BACK_C1 := 1.70158
const BACK_C3 := 2.70158
const DUST_COUNT := 7
const THUMP := 0.22

signal finished(kind: String, record: Dictionary)

var enabled := true
var _editor: Node
var _active: Array[Dictionary] = []
var _dust_mesh: QuadMesh
var _dust_material: StandardMaterial3D

func setup(editor: Node) -> void:
	_editor = editor

## The rendered pose of a committed record, matching GardenView's own placement.
func record_pose(record: Dictionary) -> Transform3D:
	var basis := preload("res://scripts/native_object_pose.gd").decode_basis(record.pose) if record.has("pose") else Basis(Vector3.UP,record.angle).scaled(Vector3.ONE*record.scale)
	return Transform3D(basis,_editor.data.object_position(record))

## Start a reaction for a record the editor has just committed and drawn.
## `fresh` is the id `NativeTerrainData.place` minted for this very click. A
## reaction runs only for that record, so every path that re-renders a record
## that already exists — redo, a load, a rebuild — restores it silently: those
## paths have no minted id to hand over and cannot ask for a reaction.
func play(kind: String, pose: Transform3D, record: Dictionary, fresh: int) -> bool:
	if not enabled or _editor == null or not REACTIONS.has(kind):
		return false
	if fresh < 1 or int(record.get("id",-1)) != fresh:
		return false
	var style: Dictionary = STYLES[REACTIONS[kind]]
	var angle := float(record.get("angle",0.0))
	var reaction := {
		"kind":kind,
		"style":REACTIONS[kind],
		"record":record,
		"anchor":pose.origin,
		"size":float(record.get("scale",1.0)),
		# The horizontal axis a log tips over, taken from the record's own yaw.
		"axis":Vector3(-sin(angle),0.0,cos(angle)),
		"elapsed":0.0,
		"duration":float(style.duration),
		"sprout":bool(style.grow),
		"revision":_editor.content.revision,
		"targets":_targets(record),
		"node":_editor.landmarks.get_node_or_null("%s_%d" % [kind,record.id]),
		"rest":Transform3D.IDENTITY,
		"dust":null,
		"thumped":false,
	}
	if reaction.node != null:
		reaction.rest = reaction.node.transform
	if reaction.targets.is_empty() and reaction.node == null:
		return false
	_active.append(reaction)
	_apply(reaction,0.0)
	return true

func playing(record: Dictionary) -> bool:
	for reaction in _active:
		if reaction.record.id == record.id:
			return true
	return false

func active_count() -> int:
	return _active.size()

## The committed transform a live reaction is heading back to, per rendered
## part, keyed by the batch's part name and "landmark" for landmark nodes.
func targets_of(record: Dictionary) -> Dictionary:
	var poses := {}
	for reaction in _active:
		if reaction.record.id != record.id:
			continue
		for target: Dictionary in reaction.targets:
			poses[target.batch.get_meta("part")] = _editor.content._instance_transform(target.recipe)
		if reaction.node != null:
			poses["landmark"] = reaction.rest
	return poses

func _process(delta: float) -> void:
	advance(delta)

## Advance every live reaction. The scene's P pause freezes them where they are.
func advance(delta: float) -> void:
	if _active.is_empty() or _editor == null or _editor.scene._paused:
		return
	var done: Array[Dictionary] = []
	for reaction in _active.duplicate():
		if _stale(reaction):
			_release(reaction)
			done.append(reaction)
			continue
		reaction.elapsed += delta
		var t := clampf(reaction.elapsed/float(reaction.duration),0.0,1.0)
		_apply(reaction,t)
		if t >= 1.0:
			_release(reaction)
			done.append(reaction)
	for reaction in done:
		_active.erase(reaction)
		finished.emit(reaction.kind,reaction.record)

## Drop every live reaction onto its committed pose without animating further.
func finish_all() -> void:
	for reaction in _active.duplicate():
		if not _stale(reaction):
			_apply(reaction,1.0)
		_release(reaction)
		_active.erase(reaction)
		finished.emit(reaction.kind,reaction.record)

func _targets(record: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for batch: MultiMeshInstance3D in _editor.content._batches:
		var part: String = batch.get_meta("part")
		var recipes: Array = _editor.content._sources[part]
		for i in range(recipes.size()):
			var recipe: Dictionary = recipes[i]
			if recipe.item != null and int(recipe.item.get("id",-1)) == int(record.id):
				found.append({"batch":batch,"index":i,"recipe":recipe})
	return found

func _stale(reaction: Dictionary) -> bool:
	if _editor.content.revision != reaction.revision:
		return true
	for target: Dictionary in reaction.targets:
		if not is_instance_valid(target.batch) or target.index >= target.batch.multimesh.instance_count:
			return true
	return reaction.node != null and not is_instance_valid(reaction.node)

## A basis applied about the record's ground origin plus a vertical lift.
## Identity when the basis is identity and the lift is zero, so the last frame
## writes the record's committed transform back untouched.
static func about(anchor: Vector3, basis: Basis, lift: float) -> Transform3D:
	return Transform3D(basis,anchor-basis*anchor+Vector3.UP*lift)

## The same, for the common case of a pure scale about the anchor.
static func offset(anchor: Vector3, size: Vector3, lift: float) -> Transform3D:
	return about(anchor,Basis.IDENTITY.scaled(size),lift)

## How far through the landing a falling reaction is, 0 the moment it touches
## down and exactly 1 on its last frame. Dust and squash both ride this, so a
## puff always finishes fading at the same instant the reaction ends.
static func landing(style: Dictionary, t: float) -> float:
	return clampf((t-float(style.fall))/maxf(1.0-float(style.fall),0.0001),0.0,1.0)

## The reaction's visual offset at normalised time, identity at t = 1.
func shape(reaction: Dictionary, t: float) -> Transform3D:
	if t >= 1.0:
		return Transform3D.IDENTITY
	if reaction.sprout:
		var b := t-1.0
		var s := maxf(1.0+BACK_C3*b*b*b+BACK_C1*b*b,0.0001)
		return offset(reaction.anchor,Vector3.ONE*s,0.0)
	var style: Dictionary = STYLES[reaction.style]
	if t < float(style.fall):
		var f: float = t/float(style.fall)
		return offset(reaction.anchor,Vector3.ONE,float(style.height)*reaction.size*(1.0-f)*(1.0-f))
	# One damped swing shared by the squash and the log's rock, so both die out
	# together and reach exactly zero on the last frame.
	var u := landing(style,t)
	var swing := exp(-4.0*u)*cos(TAU*0.75*u)*(1.0-u)
	var q: float = float(style.squash)*swing
	var basis := Basis.IDENTITY.scaled(Vector3(1.0+q*0.5,1.0-q,1.0+q*0.5))
	if float(style.rock) != 0.0:
		basis = Basis(reaction.axis,float(style.rock)*swing)*basis
	return about(reaction.anchor,basis,0.0)

func _apply(reaction: Dictionary, t: float) -> void:
	var shift := shape(reaction,t)
	for target: Dictionary in reaction.targets:
		var committed: Variant = _editor.content._instance_transform(target.recipe)
		if committed == null:
			continue
		target.batch.multimesh.set_instance_transform(target.index,committed if t >= 1.0 else shift*committed)
	if reaction.node != null:
		reaction.node.transform = reaction.rest if t >= 1.0 else shift*reaction.rest
	var style: Dictionary = STYLES[reaction.style]
	if float(style.dust) > 0.0:
		if t >= float(style.fall) and reaction.dust == null and t < 1.0:
			reaction.dust = _spawn_dust(reaction)
		if reaction.dust != null:
			_shape_dust(reaction,landing(style,t))
	if reaction.kind == "bigfoot_tree" and not reaction.thumped and t >= 0.6:
		reaction.thumped = true
		if _editor.scene._bigfoot != null and _editor.scene._bigfoot.rig != null:
			_editor.scene._tremor.add(THUMP)

func _release(reaction: Dictionary) -> void:
	if reaction.dust != null and is_instance_valid(reaction.dust):
		reaction.dust.free()
	reaction.dust = null

func _spawn_dust(reaction: Dictionary) -> MultiMeshInstance3D:
	if _dust_mesh == null:
		_dust_mesh = QuadMesh.new()
		_dust_mesh.size = Vector2.ONE*0.7
		_dust_material = StandardMaterial3D.new()
		_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_dust_material.vertex_color_use_as_albedo = true
		_dust_material.albedo_color = Color(0.88,0.83,0.72)
		# A soft radial falloff, so a puff reads as dust and not as a lit quad.
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0,0.55,1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.45),Color(1,1,1,0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5,0.5)
		texture.fill_to = Vector2(1.0,0.5)
		texture.width = 64
		texture.height = 64
		_dust_material.albedo_texture = texture
		_dust_material.disable_receive_shadows = true
	var node := MultiMeshInstance3D.new()
	node.name = "Dust_%d" % int(reaction.record.id)
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = true
	node.multimesh.mesh = _dust_mesh
	node.multimesh.instance_count = DUST_COUNT
	node.material_override = _dust_material
	add_child(node)
	return node

## The puff at `u` through the landing. It rides the record's own scale and the
## style's dust weight, so a small flower-sized boulder throws a small puff and
## a stump only a wisp, and its alpha reaches exactly zero at u = 1, the frame
## the reaction ends and frees the node.
func _shape_dust(reaction: Dictionary, u: float) -> void:
	var node: MultiMeshInstance3D = reaction.dust
	u = clampf(u,0.0,1.0)
	var size: float = reaction.size*float(STYLES[reaction.style].dust)
	for i in range(DUST_COUNT):
		var angle := float(i)*TAU/float(DUST_COUNT)+float(int(reaction.record.id)%7)*0.41
		var reach := (0.30+1.05*u)*size
		var point: Vector3 = reaction.anchor+Vector3(cos(angle)*reach,(0.10+0.50*u)*size,sin(angle)*reach)
		var grow := (0.60+1.10*u)*size
		node.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*grow),point))
		node.multimesh.set_instance_color(i,Color(1.0,1.0,1.0,0.72*(1.0-u)*(1.0-u)))
