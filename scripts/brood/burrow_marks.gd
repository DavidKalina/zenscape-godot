extends Node3D
## Where to dig, in the bag study (docs/design/bag-brood/spec-bag-brood.md,
## task 5): each burrow with loot in it (scripts/brood/bag_brood.gd `buried`,
## `bag_in`) shows a fresh pile of turned earth over its mouth, growing with
## the kg in it, a glint and a thin beam over it and a "buried N kg" tag,
## all seen from across the room (the tag through walls). Close up, a
## prompt: "G dig", "shake them off" while guards cling, or "find the spade".
## The spade lying shows a glint and a "spade" tag too, and the first burial
## says where it went.
const K = preload("res://scripts/brood/brood_knobs.gd")
const Pad = preload("res://scripts/pad.gd")

## The pile: radius and height (m, times size) from none to PILE_FULL kg.
const PILE_R := Vector2(0.55,1.05)
const PILE_H := Vector2(0.2,0.55)
const PILE_FULL := 15.0
## The glint's height over the mouth (m, times size), its bob and spin.
const GLINT_UP := 1.5
const GLINT_BOB := 0.12
## The beam: height (m, times size) and radius.
const BEAM_HIGH := 7.0
const BEAM_R := 0.05
## How near (m across, times size) he gets for the prompt.
const PROMPT_NEAR := 2.6

var host: Node3D = null
var size := 1.0
## burrow name -> {pile, glint, beam, tag, prompt, mouth}.
var _marks := {}
var _spade_glint: Node3D = null
var _spade_tag: Label3D = null
var _t := 0.0
var _burials_seen := 0

func setup(scene: Node3D) -> void:
	host = scene
	name = "BurrowMarks"
	size = float(scene.get("wanderer_scale")) if scene.get("wanderer_scale") != null else 1.0
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(0.24,0.17,0.11)
	earth.roughness = 1.0
	for b: Variant in host.get("burrows"):
		var hole := b as Node3D
		var pile := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = 1.0
		dome.height = 1.0
		dome.is_hemisphere = true
		dome.radial_segments = 16
		dome.rings = 5
		pile.mesh = dome
		pile.material_override = earth
		pile.visible = false
		hole.add_child(pile)
		var glint := _glint(Color(1.0,0.78,0.3))
		glint.visible = false
		hole.add_child(glint)
		var beam := _beam()
		beam.visible = false
		hole.add_child(beam)
		var tag := _label(40,Color(1.0,0.85,0.45),true)
		hole.add_child(tag)
		var prompt := _label(32,Color(1,1,1),false)
		hole.add_child(prompt)
		_marks[str(hole.name)] = {"pile":pile,"glint":glint,"beam":beam,"tag":tag,"prompt":prompt,"mouth":hole.get_node_or_null("Mouth")}
	_spade_glint = _glint(Color(0.75,0.9,1.0))
	add_child(_spade_glint)
	_spade_tag = _label(36,Color(0.8,0.92,1.0),true)
	add_child(_spade_tag)

func _glint(colour: Color) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = 0.16*size
	gem.height = 0.4*size
	gem.radial_segments = 4
	gem.rings = 1
	g.mesh = gem
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 2.5
	mat.metallic = 0.6
	mat.roughness = 0.2
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g

func _beam() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = BEAM_R*0.3*size
	c.bottom_radius = BEAM_R*size
	c.height = BEAM_HIGH*size
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	m.position.y = BEAM_HIGH*size*0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0,0.8,0.35,0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _label(px: int, colour: Color, far: bool) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = far
	l.fixed_size = far
	l.font_size = px
	l.pixel_size = 0.0011 if far else 0.006
	l.outline_size = 8
	l.modulate = colour
	l.visible = false
	return l

## The kg buried in burrow `called` (the bag's and the pieces').
func pile_kg(called: String) -> float:
	var brood: Variant = host.get("brood")
	if brood == null: return 0.0
	var kg := 0.0
	if str(brood.bag_in) == called: kg += float(host.get("bag").kg)
	for p: Dictionary in brood.buried.get(called,[]): kg += float(p.kg)
	return kg

func _process(delta: float) -> void:
	if host == null or not bool(host.get("walk_ready")): return
	_t += delta
	var brood: Variant = host.get("brood")
	var dig: Variant = host.get("dig")
	var motor: Variant = host.get("motor")
	var feet: Vector3 = motor.feet if motor != null else Vector3.INF
	var bob := sin(_t*2.2)*GLINT_BOB*size
	for called: String in _marks:
		var mk: Dictionary = _marks[called]
		var piled: bool = brood != null and brood.has_pile(called)
		var kg := pile_kg(called) if piled else 0.0
		var k := clampf(kg/PILE_FULL,0.0,1.0)
		var r := lerpf(PILE_R.x,PILE_R.y,sqrt(k))*size
		var h := lerpf(PILE_H.x,PILE_H.y,sqrt(k))*size
		var pile: MeshInstance3D = mk.pile
		pile.visible = piled
		pile.scale = Vector3(r,h,r)
		if mk.mouth != null: (mk.mouth as Node3D).visible = not piled
		var glint: Node3D = mk.glint
		glint.visible = piled
		glint.position = Vector3(0.0,h+GLINT_UP*size+bob,0.0)
		glint.rotation.y = _t*1.6
		(mk.beam as Node3D).visible = piled
		var tag: Label3D = mk.tag
		tag.visible = piled
		tag.text = "buried  %s kg" % _kg(kg)
		tag.position = Vector3(0.0,h+GLINT_UP*size+0.55*size,0.0)
		var prompt: Label3D = mk.prompt
		prompt.visible = false
		if not piled or feet == Vector3.INF: continue
		var at := (mk.pile as Node3D).global_position
		if Vector2(at.x-feet.x,at.z-feet.z).length() > PROMPT_NEAR*size or absf(at.y-feet.y) > 1.5*size: continue
		var key := "Y" if Pad.using_pad() else "G"
		if dig == null or not bool(dig.has_spade()):
			prompt.text = "find the spade (by the start) to dig"
			prompt.modulate = Color(1.0,0.7,0.55)
		elif brood != null and int(brood.clinging) > 0:
			prompt.text = "jump: shake them off to dig"
			prompt.modulate = Color(1.0,0.7,0.55)
		else:
			prompt.text = "%s  dig  (face the mound)" % key
			prompt.modulate = Color(1,1,1)
		prompt.position = Vector3(0.0,h+0.7*size,0.0)
		prompt.visible = true
	_spade_mark(dig,bob)
	if brood != null and int(brood.burials) > _burials_seen:
		_burials_seen = int(brood.burials)
		if _burials_seen == 1 and host.has_method("_say"):
			var where := ""
			for called: String in _marks: if brood.has_pile(called): where = called
			host._say("They buried it in %s: the spade digs it out (G / pad Y)%s" % [where.replace("_"," "),"" if dig != null and bool(dig.has_spade()) else "; the spade lies by the start"],6.0)

func _spade_mark(dig: Variant, bob: float) -> void:
	var lying: bool = dig != null and str(dig.spade_state) == "lying" and dig.spade_lying != null
	_spade_glint.visible = lying
	_spade_tag.visible = lying
	if not lying: return
	var at: Vector3 = (dig.spade_lying as Node3D).global_position
	_spade_glint.global_position = at+Vector3.UP*(1.1*size+bob)
	_spade_glint.rotation.y = _t*1.6
	_spade_tag.global_position = at+Vector3.UP*1.6*size
	_spade_tag.text = "spade  (walk over it)"

static func _kg(kg: float) -> String:
	return ("%.1f" % kg) if kg != floorf(kg) else ("%d" % int(kg))
