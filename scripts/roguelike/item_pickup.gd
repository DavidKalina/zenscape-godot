extends Node3D
## An item as it stands in the world (docs/design/roguelike/altars-round1.md):
## a carved basalt plinth in the city kit's weathered stone
## (scripts/city_kit_stone.gd) with the item floating over it, turning and
## bobbing, a dim warm lamp under it and a faint column of light so it reads
## from afar. Reusable: anyone who lays an item in the world (an altar, a
## vault, a merchant's stall, a dropped key) makes one with
## `ItemPickup.make(id)` and decides how it is taken.
##
##   var p := ItemPickup.make(&"wallrun")        # on a plinth
##   var k := ItemPickup.make(&"vault_key",false) # lying free (no plinth)
##   parent.add_child(p); p.global_position = ground_point
##   p.reach_of(feet)  # flat distance from his feet to it (m)
##   p.take(run)       # run.give_item(id) + the take moment; frees itself
##
## The relic is a stand-in faceted shape (no model per item yet) tinted by
## the item's kind: verb a warm gold, passive a pale straw, cursed a dull
## violet-grey, a key tarnished brass. Glows stay dim and warm on stone.
const Stone = preload("res://scripts/city_kit_stone.gd")
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")

const TINTS := {
	"verb": Color("e0b45e"), "passive": Color("d9cf9a"),
	"cursed": Color("9a86a8"), "key": Color("c9a24a"),
}
## The plinth: height (m), apothem at the foot and the top; the relic's
## middle over the plinth's top.
const PLINTH_H := 0.62
const PLINTH_R := Vector2(0.46,0.36)
const RELIC_LIFT := 0.62
const RELIC_SIZE := 0.34
## The column of light: height (m), width (m), alpha at its foot.
const BEAM_H := 9.0
const BEAM_W := 0.22
const BEAM_ALPHA := 0.16
## How near (m, flat) a walk-in takes it, and how near the name shows.
const TAKE_REACH := 1.0
const NAME_SHOWS := 9.0

var id: StringName = &""
var with_plinth := true
var taking := false
## Seconds before it may be taken (a dropped key lies a moment first).
var ready_in := 0.0
var relic: Node3D
var lamp: OmniLight3D
var label: Label3D
var _beam: MeshInstance3D
var _t := 0.0
var _phase := 0.0
var _y0 := 0.0
var free_lift := 0.5
var _mat: StandardMaterial3D

## An item stood up, on a plinth or lying free.
static func make(item: StringName, plinth := true, seed_value := 0, lift := 0.5) -> Node3D:
	var p: Node3D = (load("res://scripts/roguelike/item_pickup.gd") as GDScript).new()
	p.id = item
	p.with_plinth = plinth
	p.free_lift = lift
	p._phase = float(seed_value % 100)*0.31
	p.build(seed_value)
	return p

func build(seed_value: int) -> void:
	name = "Item_%s" % id
	var kind := String(ItemCatalog.info(id).get("kind","verb"))
	var tint: Color = TINTS.get(kind,TINTS.verb)
	var base_y := 0.0
	if with_plinth:
		var m := Stone.Mesher.new(Stone.stone_colour(),0.3)
		var xf := Transform3D.IDENTITY
		m.solid(Stone.drum(xf,6,PLINTH_R.x,PLINTH_R.y,PLINTH_H,0.05,float(seed_value%6)))
		# A capstone, a little wider, and a worn step.
		m.solid(Stone.box(Transform3D(Basis(),Vector3(0.0,PLINTH_H+0.04,0.0)),Vector3(0.43,0.04,0.43),0.03))
		m.solid(Stone.box(Transform3D(Basis(Vector3.UP,0.4),Vector3(0.0,0.05,0.0)),Vector3(0.62,0.05,0.62),0.04))
		m.runes(Vector3(-0.2,0.18,PLINTH_R.x*0.84),Vector3(0.2,0.18,PLINTH_R.x*0.84),Vector3.UP,Vector3(0,0,1),float(seed_value),0.16)
		var mesh := Stone.mesh_of(m,"refuge")
		var body := MeshInstance3D.new()
		body.name = "Plinth"
		body.mesh = mesh
		add_child(body)
		base_y = PLINTH_H+0.08
	relic = Node3D.new()
	relic.name = "Relic"
	relic.position = Vector3(0.0,base_y+(RELIC_LIFT if with_plinth else free_lift),0.0)
	add_child(relic)
	_y0 = relic.position.y
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tint.darkened(0.25)
	_mat.metallic = 0.7
	_mat.roughness = 0.35
	_mat.emission_enabled = true
	_mat.emission = tint
	_mat.emission_energy_multiplier = 0.55
	var shape := MeshInstance3D.new()
	shape.name = "Shape"
	shape.material_override = _mat
	if kind == "key":
		_key_shape(shape)
	else:
		var s := SphereMesh.new()
		s.radial_segments = 4
		s.rings = 2
		s.radius = RELIC_SIZE
		s.height = RELIC_SIZE*2.5
		shape.mesh = s
	relic.add_child(shape)
	lamp = OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = tint.lerp(Color.WHITE,0.2)
	lamp.light_energy = 0.55
	lamp.omni_range = 4.0
	lamp.shadow_enabled = false
	relic.add_child(lamp)
	# The column of light, additive and dim, readable from afar.
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	var c := CylinderMesh.new()
	c.top_radius = BEAM_W*0.5
	c.bottom_radius = BEAM_W
	c.height = BEAM_H
	c.radial_segments = 8
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	_beam.mesh = c
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(tint.r,tint.g,tint.b,BEAM_ALPHA)
	bm.disable_receive_shadows = true
	_beam.material_override = bm
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0.0,relic.position.y+BEAM_H*0.5,0.0)
	add_child(_beam)
	label = Label3D.new()
	label.name = "Name"
	label.text = "%s\n%s" % [ItemCatalog.title(id),String(ItemCatalog.info(id).get("line",""))]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.0046
	label.outline_size = 10
	label.modulate = Color("f4ead2")
	label.no_depth_test = true
	label.position = Vector3(0.0,relic.position.y+0.95,0.0)
	label.visible = false
	add_child(label)
	set_process(true)

func _key_shape(host: MeshInstance3D) -> void:
	# A small brass key: a ring, a shaft and two teeth, in one mesh.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = [
		[Vector3(0.0,0.16,0.0),Vector3(0.11,0.11,0.035)],
		[Vector3(0.0,-0.06,0.0),Vector3(0.035,0.2,0.03)],
		[Vector3(0.07,-0.2,0.0),Vector3(0.07,0.035,0.03)],
		[Vector3(0.06,-0.1,0.0),Vector3(0.06,0.03,0.03)],
	]
	for part: Array in parts:
		var b := BoxMesh.new()
		b.size = (part[1] as Vector3)*2.0
		st.append_from(b,0,Transform3D(Basis(),part[0]))
	host.mesh = st.commit()
	host.scale = Vector3.ONE*1.5

func _process(delta: float) -> void:
	_t += delta
	ready_in = maxf(0.0,ready_in-delta)
	if relic == null or taking: return
	if not is_instance_valid(label):
		relic.position.y = _y0+sin(_t*1.6+_phase)*0.07
		relic.rotation.y = _t*0.9+_phase
		return
	relic.position.y = _y0+sin(_t*1.6+_phase)*0.07
	relic.rotation.y = _t*0.9+_phase
	lamp.light_energy = 0.55+0.12*sin(_t*2.3+_phase)
	# The name shows when he is near (a sky-high column carries the rest).
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		label.visible = global_position.distance_to(cam.global_position) < NAME_SHOWS*2.2 and not taking

## Flat distance (m) from `feet` to it.
func reach_of(feet: Vector3) -> float:
	return Vector2(global_position.x-feet.x,global_position.z-feet.z).length()

## Whether `feet` (a walker) is close enough to walk into it.
func within(feet: Vector3) -> bool:
	return ready_in <= 0.0 and not taking and reach_of(feet) < TAKE_REACH and absf(feet.y-global_position.y) < 1.8

## Taken: into the run, a bright swell of its lamp, the relic's lift and
## shrink, then it frees itself (the plinth stays, bare).
func take(run: Object) -> void:
	if taking: return
	taking = true
	label.visible = false
	if run != null: run.give_item(id)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lamp,"light_energy",2.6,0.12)
	t.tween_property(lamp,"omni_range",7.0,0.12)
	t.tween_property(relic,"position:y",relic.position.y+0.9,0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(relic,"scale",Vector3.ONE*0.05,0.4).set_delay(0.1)
	t.tween_property(_mat,"emission_energy_multiplier",3.0,0.2)
	t.tween_property(_beam,"scale",Vector3(0.1,1.0,0.1),0.5)
	t.chain().tween_callback(func() -> void:
		if with_plinth:
			relic.queue_free()
			_beam.queue_free()
			lamp = null
		else:
			queue_free())
	set_process(false)

## Dims it (a plinth with nothing to give: the altar's bargain refused).
func dim() -> void:
	if lamp != null: lamp.light_energy = 0.1
	if _beam != null: _beam.visible = false

## Only the relic (no column, no name): the key bobbing over his head.
func bare() -> void:
	if _beam != null: _beam.queue_free()
	_beam = null
	if label != null: label.queue_free()
	if lamp != null:
		lamp.light_energy = 0.25
		lamp.omni_range = 2.5
	if relic != null: relic.scale = Vector3.ONE*0.6
	ready_in = 1.0e9
