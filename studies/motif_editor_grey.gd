extends RefCounted
## The motif editor's grey editing look (spec-editor-traps item 8): the bare
## land and pieces in plain flat materials (land green on the flats, grey up
## the cliffs; stone one grey; water one flat blue), a plain colour sky, one
## static sun and flat ambient light. The live sky, clouds, look pass,
## screen air, weather and flora are hidden and not stepped while it is on.
## The editor's view only: saving and what the yard and generator build are
## unchanged. The traps keep their own colours (they stand outside `bare`).

const SKY := Color(0.70,0.77,0.84)
const AMBIENT := Color(0.78,0.80,0.84)
const STONE := Color(0.63,0.62,0.59)
const GRASS := Color(0.47,0.55,0.40)
const ROCK := Color(0.55,0.53,0.50)
const WATER := Color(0.34,0.52,0.68)

const LAND_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 grass : source_color;
uniform vec3 rock : source_color;
varying float up;
void vertex() { up = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y; }
void fragment() {
	ALBEDO = mix(rock, grass, smoothstep(0.55, 0.8, up));
	ROUGHNESS = 1.0;
}
"""

var study: Node3D
var on := false
var env: Environment
var sun: DirectionalLight3D
var stone: StandardMaterial3D
var water: StandardMaterial3D
var land: ShaderMaterial
## What it hid: node -> [visible, process_mode], given back when it goes off.
var _hid := {}

func _init(s: Node3D) -> void:
	study = s
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	sun = DirectionalLight3D.new()
	sun.name = "GreySun"
	sun.rotation_degrees = Vector3(-55.0,-35.0,0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.visible = false
	study.add_child(sun)
	stone = _flat(STONE)
	water = _flat(WATER)
	var sh := Shader.new()
	sh.code = LAND_SHADER
	land = ShaderMaterial.new()
	land.shader = sh
	land.set_shader_parameter("grass",GRASS)
	land.set_shader_parameter("rock",ROCK)

static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

## The look on or off (the dressed look's nodes hidden or given back).
func set_on(want: bool) -> void:
	if want == on: return
	on = want
	study.camera.environment = env if on else null
	sun.visible = on
	if on:
		_hid.clear()
		for n: Node in _dressed_nodes():
			var vis: Variant = n.get("visible")
			_hid[n] = [vis,n.process_mode]
			if vis != null: n.set("visible",false)
			if n is Node3D or n is CanvasLayer: n.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		for n: Node in _hid:
			if not is_instance_valid(n): continue
			if _hid[n][0] != null: n.set("visible",_hid[n][0])
			n.process_mode = _hid[n][1]
		_hid.clear()

## The full look's nodes: the sky round the isle, the sky's lights and
## objects, the look pass's layers, the screen air, the weather, the flora.
func _dressed_nodes() -> Array:
	var out: Array = []
	for key: String in ["sky","_display_fog","_precipitation","flora"]:
		var n: Variant = study.get(key)
		if n is Node: out.append(n)
	var lighting: Variant = study.get("_lighting")
	if lighting is Node:
		for l: Node in lighting.lights: out.append(l)
		if lighting.sky_objects is Node: out.append(lighting.sky_objects)
	var look: Variant = study.get("_look")
	if look is Object:
		for key: String in ["_grade_layer","_motes","sea","cloud_volume","grass"]:
			var n: Variant = look.get(key)
			if n is Node: out.append(n)
	return out

## Everything under `root` drawn flat: under a node named "Hill" (the bare
## land) the land material, water the flat blue, the rest stone.
func paint(root: Node) -> void:
	if root == null: return
	for g: Node in root.find_children("*","GeometryInstance3D",true,false):
		paint_one(g as GeometryInstance3D,root)

func paint_one(g: GeometryInstance3D, root: Node) -> void:
	if _is_water(g): g.material_override = water
	elif _under_land(g,root): g.material_override = land
	else: g.material_override = stone

static func _under_land(n: Node, root: Node) -> bool:
	var p := n
	while p != null and p != root:
		if p.name == &"Hill": return true
		p = p.get_parent()
	return false

static func _is_water(g: GeometryInstance3D) -> bool:
	if String(g.name).to_lower().contains("water") or String(g.name).to_lower().contains("pond"): return true
	var mats: Array = [g.material_override]
	if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
		var mi := g as MeshInstance3D
		for s in range(mi.mesh.get_surface_count()): mats.append(mi.get_active_material(s))
	for m: Variant in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path.to_lower().contains("water"): return true
	return false
