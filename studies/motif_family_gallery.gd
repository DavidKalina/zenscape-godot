extends "res://studies/kit_isle.gd"
## The motif family gallery (docs/design/roguelike/motif-families.md): one
## family built at a seed, its sockets drawn as markers, the pilot on it to
## walk it, to flip through the isles a family gives and judge them. A kit
## isle (studies/kit_isle.gd: the look, the light, the grass, the plane);
## no sky round it and no life on it (a rolled isle has none yet).
##   N / Shift+N  next / previous seed
##   M / Shift+M  next / previous family
##   R            back to the start (on its arena, looking at its first rim)
##   godot --path . res://studies/motif_family_gallery.tscn -- --no-title --family=broken_ring --seed=81
## `--family=<id>` (FAMILIES' keys) and `--seed=<n>` (the family's
## authored seed if none) pick the first; `--knob=<key>=<value>`
## (repeatable) pins knobs (they hold as the seed steps; M drops them).
## The markers, by kind: a rim an orange post with its facing as an arrow
## and its run-up as a line back over the ground; an arena a red ring at
## its room; cover a blue post; a perch a green post and ring. Each is
## labelled with its name and numbers.
const FAMILIES := {
	"colonnade_spine":preload("res://scripts/kit_isle/motif_colonnade_spine.gd"),
	"broken_ring":preload("res://scripts/kit_isle/motif_broken_ring.gd"),
}
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const SOCKET_COLOURS := {"rim":Color(1.0,0.55,0.1),"arena":Color(0.95,0.2,0.2),"cover":Color(0.25,0.5,1.0),"perch":Color(0.3,0.9,0.35)}
## A marker's post, its head and its labels (m).
const POST := 3.0
const HEAD := 0.35
const LABEL_UP := 3.8

## What is showing, kept across the reloads N and M make.
static var shown_family := ""
static var shown_seed := -1
static var pinned: Dictionary = {}

var motif: KitMotif
var markers: Node3D

func _ready() -> void:
	if shown_family == "":
		shown_family = FAMILIES.keys()[0]
		for arg in preload("res://scripts/launch_args.gd").user_args():
			if arg.begins_with("--family="): shown_family = arg.get_slice("=",1)
			elif arg.begins_with("--seed="): shown_seed = int(arg.get_slice("=",1))
			elif arg.begins_with("--knob="):
				var pair := arg.trim_prefix("--knob=")
				var value := pair.get_slice("=",1)
				pinned[pair.get_slice("=",0)] = value.to_float() if value.is_valid_float() else value
		if not FAMILIES.has(shown_family):
			push_warning("family gallery: no family '%s' (%s)" % [shown_family,", ".join(FAMILIES.keys())])
			shown_family = FAMILIES.keys()[0]
	motif = (FAMILIES[shown_family] as GDScript).new()
	if shown_seed < 0: shown_seed = motif.default_seed()
	motif.configure(shown_seed,pinned)
	super._ready()
	await ready_to_walk
	_build_card()
	print("family gallery: %s seed %d %s, built in %d ms, %d sockets" % [shown_family,shown_seed,motif.knobs,motif.built_ms,motif.sockets().size()])

## The start: on its arena, looking at its first rim.
func _load_pack() -> void:
	stations = []
	var sockets: Array = motif.sockets()
	var arena: Dictionary = sockets.filter(func(s: Dictionary) -> bool: return s.kind == "arena")[0]
	var rim: Dictionary = sockets.filter(func(s: Dictionary) -> bool: return s.kind == "rim")[0]
	start = arena.at
	var way: Vector3 = (rim.at as Vector3)-start
	start_face = Vector2(way.x,way.z).normalized()
	lost = float(motif.height_span().x)-10.0
	_last_stood = start

func isle_name() -> String:
	return "%s %d" % [motif.isle_name(),shown_seed]

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

func isle_summit() -> Vector3:
	return motif.summit()

func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func flora_seed() -> int:
	return motif.flora_seed()

func capture_look() -> Vector3:
	return motif.summit()

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	motif.warm()
	motif.build(art)
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	markers = Node3D.new()
	markers.name = "Sockets"
	add_child(markers)
	for s: Dictionary in motif.sockets(): _marker(s)

## No sky round it and no life on it: the isle alone.
func _add_sky() -> void:
	pass

func _add_life() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_N:
				shown_seed = maxi(shown_seed+(-1 if key.shift_pressed else 1),0)
				get_tree().reload_current_scene()
				return
			KEY_M:
				var ids: Array = FAMILIES.keys()
				shown_family = ids[posmod(ids.find(shown_family)+(-1 if key.shift_pressed else 1),ids.size())]
				shown_seed = -1
				pinned = {}
				get_tree().reload_current_scene()
				return
	super._unhandled_input(event)

# --- The markers ------------------------------------------------------------------

func _marker(s: Dictionary) -> void:
	var colour: Color = SOCKET_COLOURS[s.kind]
	var at: Vector3 = s.at
	var face: Vector3 = s.face
	var mark := Node3D.new()
	mark.name = "%s_%s" % [s.kind,s.name]
	markers.add_child(mark)
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.06
	post.height = POST
	_mesh(mark,post,colour,at+Vector3.UP*POST*0.5)
	var head := SphereMesh.new()
	head.radius = HEAD
	head.height = HEAD*2.0
	_mesh(mark,head,colour,at+Vector3.UP*POST)
	var text := "%s %s" % [s.kind,s.name]
	match str(s.kind):
		"rim":
			# Its facing, an arrow out over the drop; its run-up a line back.
			var arrow := BoxMesh.new()
			arrow.size = Vector3(0.12,0.12,2.0)
			var turn := Basis.looking_at(face,Vector3.UP)
			_mesh(mark,arrow,colour,at+Vector3.UP*1.2+face*1.0,turn)
			var tip := PrismMesh.new()
			tip.size = Vector3(0.5,0.6,0.12)
			_mesh(mark,tip,colour,at+Vector3.UP*1.2+face*2.2,turn*Basis(Vector3.RIGHT,-PI*0.5))
			var run := BoxMesh.new()
			run.size = Vector3(0.08,0.04,float(s.run_up))
			_mesh(mark,run,colour.lightened(0.4),at+Vector3.UP*0.08-face*float(s.run_up)*0.5,turn)
			text += "\nrun-up %.1f m" % float(s.run_up)
		_:
			_ring(mark,at,float(s.room),colour)
			text += "\nroom %.1f m" % float(s.room)
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.pixel_size = 0.006
	label.outline_size = 12
	label.modulate = colour.lightened(0.5)
	label.position = at+Vector3.UP*LABEL_UP
	mark.add_child(label)

func _mesh(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, turn := Basis.IDENTITY) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _paint(colour)
	m.transform = Transform3D(turn,at)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

## A ring on the ground `room` m round `at`.
func _ring(parent: Node3D, at: Vector3, room: float, colour: Color) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(room-0.06,0.01)
	ring.outer_radius = room+0.06
	ring.rings = 48
	_mesh(parent,ring,colour,at+Vector3.UP*0.1)

func _paint(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

# --- The card -------------------------------------------------------------------------

## What is showing and the keys, top left.
func _build_card() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FamilyCard"
	add_child(layer)
	var card := Label.new()
	var knobs := PackedStringArray()
	for key: String in motif.knobs: knobs.append("%s %s" % [key,motif.knobs[key]])
	var authored: bool = motif.call("authored_isle")
	card.text = "%s  ·  seed %d%s  ·  %s, %s\n%s\nfootprint %s  ·  height %s  ·  built in %d ms\nrim orange · arena red · cover blue · perch green\nN / Shift+N seed  ·  M / Shift+M family  ·  R start" % [
		shown_family,shown_seed," (authored)" if authored else "",motif.role(),", ".join(knobs) if not knobs.is_empty() else "",
		"pinned: %s" % pinned if not pinned.is_empty() else "",motif.footprint(),motif.height_span(),motif.built_ms]
	card.add_theme_font_size_override("font_size",18)
	card.add_theme_color_override("font_color",Color("fbf6ea"))
	card.add_theme_color_override("font_shadow_color",Color(0,0,0,0.75))
	card.position = Vector2(16.0,12.0)
	layer.add_child(card)
