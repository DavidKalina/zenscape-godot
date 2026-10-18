extends Node3D
## What a generated layer lays between and on its isles (docs/design/
## roguelike/layer-round2.md, scripts/roguelike/layer_plan.gd), built from
## the plan with what the game has: the edges' floating stones (studies/
## aqueduct_isle_art.gd `floating_stones`), its rope bridges on their stone
## anchors (scripts/footbridge.gd `live`, RuinKit `bridge_anchor`, as the
## broken ring hangs its own), the Loose Voussoirs (scripts/traps/
## trap_voussoirs.gd) in a TrapField, the EnemyField, the cannon and its
## kegs (scripts/cannon/cannon_field.gd); the gulfs' rides
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
const CannonField = preload("res://scripts/cannon/cannon_field.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerRides = preload("res://scripts/roguelike/layer_rides.gd")
const LayerEnemies = preload("res://scripts/roguelike/layer_enemies.gd")
const LayerGreybox = preload("res://scripts/roguelike/layer_greybox.gd")
const CityCrossings = preload("res://scripts/roguelike/city_crossings.gd")
# [flyer] the guacharos over the gulfs (flyer-round1.md).
const LayerFlyers = preload("res://scripts/roguelike/layer_flyers.gd")

var study: Node3D
var plan: Dictionary
## What stood in the slot before (the isle's foot pieces), or null.
var inner: Node = null
var traps: Node3D
var enemies: Node
var cannons: Node3D
var stones: Node3D
var bridges: Array[MeshInstance3D] = []
var rides: Node3D
## The generator's inhaler heads (scripts/roguelike/layer_enemies.gd), or
## null.
var heads: Node = null
## The greybox isles' live bits and card (scripts/roguelike/
## layer_greybox.gd), or null.
var greybox: Node = null
## [flyer] The layer's guacharos (scripts/roguelike/layer_flyers.gd), or null.
var flyers: Node3D = null

func _init() -> void:
	name = "Layer"

## Built from `layer` (a LayerPlan) on `scene`, hooked into its slot round
## `was` (what stood there before any layer).
func setup(scene: Node3D, layer: Dictionary, was: Node) -> void:
	study = scene
	plan = layer
	inner = was
	var seed_value: int = layer.seed
	# The city (underground): every crossing in the city's basalt, column
	# tops and causeways (scripts/roguelike/city_crossings.gd).
	if LayerPlan.LayerWorlds.city(layer.knobs):
		stones = CityCrossings.build(layer.edges,seed_value%100000+500)
		stones.name = "Stones"
		add_child(stones)
	else:
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
	# The EnemyField and the inhaler heads on their rounds.
	enemies = EnemyField.new()
	enemies.study = scene
	enemies.motor = scene.motor
	enemies.lost = float(scene.lost)
	add_child(enemies)
	heads = LayerEnemies.dress(self,layer)
	# The cannon and its kegs.
	cannons = CannonField.new()
	add_child(cannons)
	cannons.attach(scene)
	if not (layer.cannon as Dictionary).is_empty():
		cannons.add_cannon(layer.cannon.at,float(layer.cannon.heading),{"speed_max":float(LayerPlan.cannon_knobs().speed_max)})
		for at: Vector3 in layer.cannon.kegs: cannons.add_keg(at)
	# The greybox isles' live bits, after the cannons (a motif's `live` may
	# add its own to them).
	greybox = LayerGreybox.dress(self,layer)
	scene.foot_pieces = self
	flyers = LayerFlyers.dress(self,layer)  # [flyer]
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

# --- The slot: what stood there, then the layer's ------------------------------

func before(delta: float) -> void:
	if inner != null: inner.before(delta)
	traps.before(delta)
	if greybox != null: greybox.before(delta)
	if heads != null: heads.before(delta)
	enemies.before(delta)
	cannons.before(delta)
	if flyers != null: flyers.before(delta)  # [flyer]

func after(delta: float, events: Dictionary) -> void:
	if inner != null: inner.after(delta,events)
	traps.after(delta,events)
	if greybox != null: greybox.after(delta,events)
	enemies.after(delta,events)
	cannons.after(delta,events)
	if flyers != null: flyers.after(delta,events)  # [flyer]

func pose(figure: Node3D) -> void:
	if inner != null: inner.pose(figure)
	enemies.pose(figure)
	cannons.pose(figure)
	if greybox != null: greybox.pose(figure)
	# Hidden while a head holds him.
	if heads != null: figure.visible = not heads.holding()

func frame(camera: Camera3D, delta: float) -> void:
	if inner != null and inner.has_method("frame"): inner.frame(camera,delta)
	cannons.frame(camera,delta)
	if heads != null: heads.frame(camera,delta)
	if greybox != null: greybox.frame(camera,delta)
	if flyers != null: flyers.frame(camera,delta)  # [flyer]

func reset() -> void:
	traps.reset()
	enemies.reset()
	cannons.reset()
	if greybox != null: greybox.reset()
	if flyers != null: flyers.reset()  # [flyer]
