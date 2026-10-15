extends "res://scripts/dragon_sight_overlay.gd"
## The whole body's sight drawn (docs/design/roguelike/whole-body-chase-round1.md),
## the dragon's overlay (scripts/dragon_sight_overlay.gd) on the body's
## sight (scripts/enemies/body_sight.gd): its flat cone as a fan on the
## ground round its feet (a ring at `near`), a line from its eye to each of
## the walker's points (green seen, red blocked, grey out of the cone), the
## awareness meter with its thresholds, and what it is doing. J shows and
## hides it. `body` is the headless body; steers nothing.

var body: Node3D

func setup_body(b: Node3D) -> void:
	body = b
	setup(b)

func _process(_delta: float) -> void:
	if body == null or not is_instance_valid(body) or not visible:
		if _cone_mesh != null:
			_cone_mesh.clear_surfaces()
			_line_mesh.clear_surfaces()
		return
	var sight: RefCounted = body.sight
	if sight == null: return
	var tint: Color = TINT.get(str(sight.state),TINT.unaware)
	_label.text = "Body sight: %s   (J hides)\nawareness %.2f · visibility %.2f · %d/%d points seen%s\ndoing: %s" % [str(sight.state).to_upper(),sight.awareness,sight.visibility,
		(sight.seen as Array).count(true),(sight.points as PackedVector3Array).size(),(" · %.0f m" % sight.distance if is_finite(float(sight.distance)) else "")+(" · lit %.2f glow %.2f (x%.2f, %.0f m)" % [sight.lit,sight.glow,sight.light_k(),sight.reach()] if sight.lit < 1.0 or sight.glow > 0.0 else ""),body.doing()]
	_label.add_theme_color_override("font_color",tint)
	_fill.size.x = 296.0*float(sight.awareness)
	_fill.color = tint
	_cone_mesh.clear_surfaces()
	_line_mesh.clear_surfaces()
	_fan(body.position+Vector3.UP*0.25,sight.look,float(sight.reach()),float(sight.half),float(sight.near_now()),tint)
	_draw_flat_lines(sight)

## The cone flat on the ground: a fan from its feet out to `deep` m,
## `half` rad either side of `look`, its rim, edges and a ring at `near`.
func _fan(at: Vector3, look: Vector3, deep: float, half: float, near: float, tint: Color) -> void:
	var base := atan2(look.x,look.z)
	var rim := PackedVector3Array()
	var ring := PackedVector3Array()
	for i in range(RAYS+1):
		var a := base-half+2.0*half*float(i)/float(RAYS)
		var way := Vector3(sin(a),0.0,cos(a))
		rim.append(at+way*deep)
		ring.append(at+way*near)
	# Filled only stood on its feet (off them, the fan would cut through it).
	if str(body.state) not in ["leap","fall","climb","mantle"]:
		_cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(RAYS):
			for p: Vector3 in [at,rim[i],rim[i+1]]:
				_cone_mesh.surface_set_color(Color(tint,FILL_ALPHA))
				_cone_mesh.surface_add_vertex(p)
		_cone_mesh.surface_end()
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var line := Color(tint,LINE_ALPHA)
	for i in range(RAYS):
		for p: Vector3 in [rim[i],rim[i+1],ring[i],ring[i+1]]:
			_cone_mesh.surface_set_color(line)
			_cone_mesh.surface_add_vertex(p)
	for p: Vector3 in [at,rim[0],at,rim[RAYS],at,at+look*near]:
		_cone_mesh.surface_set_color(Color(tint,0.9))
		_cone_mesh.surface_add_vertex(p)
	_cone_mesh.surface_end()

func _draw_flat_lines(sight: RefCounted) -> void:
	var points: PackedVector3Array = sight.points
	if points.is_empty(): return
	var seen: Array = sight.seen
	var eye: Vector3 = sight.eye
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(points.size()):
		var p := points[i]
		var colour := OUT
		if sight.sees_way(eye,sight.look,p): colour = SEEN if i < seen.size() and bool(seen[i]) else BLOCKED
		for q: Vector3 in [eye,p]:
			_line_mesh.surface_set_color(colour)
			_line_mesh.surface_add_vertex(q)
	_line_mesh.surface_end()
