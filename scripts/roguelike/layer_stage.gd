extends Node3D
## What a generated layer lays between and on its isles (docs/design/
## roguelike/layer-round2.md, scripts/roguelike/layer_plan.gd), built from
## the plan with what the game has: the edges' floating stones (studies/
## aqueduct_isle_art.gd `floating_stones`), its rope bridges on their stone
## anchors (scripts/footbridge.gd `live`, RuinKit `bridge_anchor`, as the
## broken ring hangs its own), the Loose Voussoirs (scripts/traps/
## trap_voussoirs.gd) in a TrapField, the Plinth Ram (scripts/enemies/
## plinth_ram.gd) in an EnemyField, the cannon and its kegs (scripts/
## cannon/cannon_field.gd), the rune set on the greed isle's perch
## (scripts/glyph_pickup.gd runes) and the exit gate; the gulfs' rides
## (scripts/roguelike/layer_rides.gd: serpents, ferries, their piers and
## the gulf cannons).
##
## It stands in the study's `foot_pieces` slot round what stood there (the
## aqueduct isle's foot pieces, `inner`) and steps the traps, the enemies
## and the cannons after it, as scripts/traps/sluice_aqueduct.gd does. A
## new layer frees it and builds another.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const PlinthRam = preload("res://scripts/enemies/plinth_ram.gd")
const CannonField = preload("res://scripts/cannon/cannon_field.gd")
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerRides = preload("res://scripts/roguelike/layer_rides.gd")
const LayerEnemies = preload("res://scripts/roguelike/layer_enemies.gd")

const GATE := Color(1.0,0.82,0.45)
const RUNE_SIZE := 0.7
## The gate: its posts' height and the gap between them (m, a share of
## the pilot's height and of his run's half second), the beam's height.
const GATE_TALL := 3.2
const GATE_WIDE := 2.6
const BEAM := 60.0

signal rune_taken(left: int)

var study: Node3D
var plan: Dictionary
## What stood in the slot before (the isle's foot pieces), or null.
var inner: Node = null
var traps: Node3D
var enemies: Node
var cannons: Node3D
var stones: Node3D
var bridges: Array[MeshInstance3D] = []
var runes: Array = []
var taken := 0
var gate: Node3D
var rides: Node3D
## The sprawl's hazards (scripts/roguelike/layer_hazards.gd), or null.
var hazards: Node3D = null
## The generator's inhaler heads (scripts/roguelike/layer_enemies.gd), or
## null.
var heads: Node = null
var _last := Vector3.INF

func _init() -> void:
	name = "Layer"

## Built from `layer` (a LayerPlan) on `scene`, hooked into its slot round
## `was` (what stood there before any layer).
func setup(scene: Node3D, layer: Dictionary, was: Node) -> void:
	study = scene
	plan = layer
	inner = was
	var seed_value: int = layer.seed
	# The stones of every edge, one node.
	var all: Array = []
	for e: Dictionary in layer.edges: all.append_array(e.stones)
	if not all.is_empty():
		stones = Art.floating_stones(seed_value%100000+500,all)
		stones.name = "Stones"
		add_child(stones)
	_bridges(seed_value)
	# The traps, stepped round the motor.
	traps = TrapField.new()
	traps.study = scene
	traps.motor = scene.motor
	add_child(traps)
	var k := 0
	for e: Dictionary in layer.edges:
		if (e.trap as Dictionary).is_empty(): continue
		var trap: Node3D = Voussoirs.new()
		trap.configure({"count":int(e.trap.count),"seed":seed_value+k})
		trap.under = str(e.trap.under)
		trap.transform = e.trap.frame
		traps.add(trap)
		k += 1
	# The ram on its arena, the heads on theirs.
	enemies = EnemyField.new()
	enemies.study = scene
	enemies.motor = scene.motor
	enemies.lost = float(scene.lost)
	add_child(enemies)
	if not (layer.ram as Dictionary).is_empty():
		var face: Vector3 = layer.ram.face
		enemies.spawn(PlinthRam,layer.ram.at,Vector2(face.x,face.z))
	# The inhaler heads on their rounds.
	heads = LayerEnemies.dress(self,layer)
	# The cannon and its kegs.
	cannons = CannonField.new()
	add_child(cannons)
	cannons.attach(scene)
	if not (layer.cannon as Dictionary).is_empty():
		cannons.add_cannon(layer.cannon.at,float(layer.cannon.heading),{"speed_max":float(LayerPlan.cannon_knobs().speed_max)})
		for at: Vector3 in layer.cannon.kegs: cannons.add_keg(at)
	scene.foot_pieces = self
	_runes()
	_gate()
	rides = LayerRides.new()
	add_child(rides)
	rides.setup(scene,layer,self)

## The rope bridges and their anchors (the broken ring's own).
func _bridges(seed_value: int) -> void:
	var holder := Node3D.new()
	holder.name = "Bridges"
	add_child(holder)
	var k := 0
	for e: Dictionary in plan.edges:
		for ends: Array in e.bridges:
			var a: Vector3 = ends[0]
			var b: Vector3 = ends[1]
			var s := seed_value%100000+k*7
			var live: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,s),a,b,s)
			live.name = "Bridge%d" % k
			holder.add_child(live)
			bridges.append(live)
			for end: Array in [[a,b],[b,a]]:
				var anchor := RuinKit.bridge_anchor(s*3+int(end[0] == b),0.45,Footbridge.WIDTH,
					{"post_x":Footbridge.WIDTH*0.5+0.33,"post_z":0.0,"sill":Vector3(0.75,0.11,0.55),"sill_at":Vector3(0.0,-0.11,0.15),
					"plinth":Vector3(1.15,1.4,0.375),"plinth_z":0.2})
				var way: Vector3 = (end[1] as Vector3)-(end[0] as Vector3)
				way.y = 0.0
				anchor.transform = Transform3D(Basis.looking_at(way.normalized(),Vector3.UP),end[0])
				holder.add_child(anchor)
			k += 1

## The rune set: a ring of runes over the greed isle's perch.
func _runes() -> void:
	var prize: Dictionary = plan.prize
	if prize.is_empty(): return
	var i := 0
	for at: Vector3 in prize.runes:
		var holder := GlyphPickup.make("rune",RUNE_SIZE,float(i)*1.3,true)
		holder.name = "Rune%d" % i
		holder.position = at
		add_child(holder)
		holder.motes_on(true)
		runes.append(holder)
		i += 1

## The exit: two glowing posts and a lintel at the top isle's rim, the way
## through facing out over the drop, a beam of light up from it to see it
## by from below. Drawn only (nothing to bump).
func _gate() -> void:
	var exit: Dictionary = plan.exit
	if exit.is_empty(): return
	gate = Node3D.new()
	gate.name = "ExitGate"
	var face: Vector3 = exit.face
	gate.transform = Transform3D(Basis.looking_at(face,Vector3.UP),exit.at)
	add_child(gate)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = GATE
	glow.emission_enabled = true
	glow.emission = GATE
	for side: float in [-1.0,1.0]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22,GATE_TALL,0.22)
		post.mesh = box
		post.material_override = glow
		post.position = Vector3(side*GATE_WIDE*0.5,GATE_TALL*0.5,0.0)
		gate.add_child(post)
	var lintel := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(GATE_WIDE+0.5,0.25,0.3)
	lintel.mesh = bar
	lintel.material_override = glow
	lintel.position = Vector3(0.0,GATE_TALL,0.0)
	gate.add_child(lintel)
	var beam := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.6
	column.bottom_radius = 0.6
	column.height = BEAM
	beam.mesh = column
	var faint := StandardMaterial3D.new()
	faint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	faint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	faint.albedo_color = Color(GATE,0.18)
	faint.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = faint
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0.0,BEAM*0.5,0.0)
	gate.add_child(beam)

## Whether feet at `feet` (world) are through the gate: within its width
## of it, on its level.
func at_exit(feet: Vector3) -> bool:
	var exit: Dictionary = plan.exit
	if exit.is_empty(): return false
	var at: Vector3 = exit.at
	return Vector2(feet.x-at.x,feet.z-at.z).length() < GATE_WIDE*0.5 and absf(feet.y-at.y) < 1.5

## The runes the pilot's middle swept past since the last frame (the kit
## tokens' reach).
func touch(point: Vector3) -> void:
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= 6.0 else point
	_last = point
	for holder: Node3D in runes.duplicate():
		if not is_instance_valid(holder) or holder.taking: continue
		var near := Geometry3D.get_closest_point_to_segment(holder.global_position,from,point)
		if near.distance_to(holder.global_position) < Lines.WALKER_REACH+RUNE_SIZE*0.5:
			runes.erase(holder)
			holder.take(hash(holder.name) & 0xffff)
			taken += 1
			rune_taken.emit(runes.size())

func runes_left() -> int:
	return runes.size()

# --- The slot: what stood there, then the layer's ------------------------------

func before(delta: float) -> void:
	if inner != null: inner.before(delta)
	traps.before(delta)
	if heads != null: heads.before(delta)
	enemies.before(delta)
	cannons.before(delta)
	if hazards != null: hazards.before(delta)

func after(delta: float, events: Dictionary) -> void:
	if inner != null: inner.after(delta,events)
	traps.after(delta,events)
	enemies.after(delta,events)
	cannons.after(delta,events)
	if hazards != null: hazards.after(delta,events)
	if study.get("figure") != null: touch(study.figure.global_position+Vector3.UP*Lines.WALKER_MIDDLE)

func pose(figure: Node3D) -> void:
	if inner != null: inner.pose(figure)
	enemies.pose(figure)
	cannons.pose(figure)
	# Hidden while a head holds him.
	if heads != null: figure.visible = not heads.holding()

func frame(camera: Camera3D, delta: float) -> void:
	if inner != null and inner.has_method("frame"): inner.frame(camera,delta)
	cannons.frame(camera,delta)
	if heads != null: heads.frame(camera,delta)

func reset() -> void:
	traps.reset()
	enemies.reset()
	cannons.reset()
