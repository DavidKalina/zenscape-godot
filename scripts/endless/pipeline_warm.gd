class_name PipelineWarm
extends Node3D
## Draws, in the load, one tiny sample of every material and mesh layout a
## flight will show later (the tutorial's guide lines, the ships and their
## balls, flashes and smoke, the hall, the wilderness past it), so their
## render pipelines are compiled before play, behind a cover, and not on the
## frame each first comes into view (a cold first flight on this Mac: 0.5-1.8 s
## frames at TREES, PARRY, WALL, the swap and out of the hall).
##
## Cost: with the OS's shader cache warm, ~17 frames under the cover. Cold (a
## machine's first run; after a shader change, that shader's samples only)
## ~35 s for the whole set, the cover counting the samples. `--no-warm` skips it.
##
## The samples are a saved scene (SET): one MeshInstance3D or
## MultiMeshInstance3D each, a one-triangle mesh with its source's vertex
## format and the source's material (textures dropped: they don't change a
## pipeline). What makes a pipeline is the shader, the vertex format, the
## primitive and the passes (shadow, transparency), so a triangle drawn once
## warms them all for the real meshes. Shaders from files are shared with the
## game (the same pipelines); shaders made in code are saved as their code,
## which the OS's shader cache matches on the next compile.
##
## The set is captured from a flight: `--warm-capture` (rendered; a driver or
## a flight by hand) walks the tree every CAPTURE_EVERY frames and, at quit,
## adds every new kind it saw to SET. Recapture after a shader's render modes,
## a mesh's vertex format or a code-made shader change; a stale sample costs
## nothing but its draw.

const SET := "res://assets/warm/pipeline_warm.scn"
## Samples drawn a frame under the cover.
const BATCH := 6
const CAPTURE_EVERY := 15
## Each sample's size and the grid's spacing in front of the eye, m.
const CELL := 0.02
const AHEAD := 2.0

var _game: Node3D
var _rig: Node3D
var _cover: CanvasLayer
var _label: Label
var _set: Node3D
var _todo: Array[GeometryInstance3D] = []
var _done := 0
var _busy := false
var _first := true
var _t0 := 0
## Capture: the kinds seen (key -> the sample node), the set's root.
var _capturing := false
var _root: Node3D
var _keys := {}
var _tick := 0

static func wanted() -> bool:
	if DisplayServer.get_name() == "headless": return false
	return not ("--no-warm" in preload("res://scripts/launch_args.gd").user_args())

## Made at the end of the load. Puts up the cover, then draws the set BATCH
## samples a frame (each also mirrored: a negative scale flips the cull, its
## own pipeline), so the window keeps answering on a cold first run, then
## lifts the cover. With --warm-capture it also starts the capture.
func setup(g: Node3D) -> void:
	_game = g
	name = "PipelineWarm"
	var cam: Camera3D = g.get("camera")
	if "--warm-capture" in preload("res://scripts/launch_args.gd").user_args(): _start_capture()
	var set_scene: PackedScene = load(SET) if ResourceLoader.exists(SET) else null
	if set_scene == null or cam == null:
		if not _capturing: queue_free()
		return
	_set = set_scene.instantiate() as Node3D
	for c: Node in _set.get_children():
		if c is GeometryInstance3D: _todo.append(c)
	_rig = Node3D.new()
	_rig.name = "PipelineWarmRig"
	_rig.position = Vector3(0.0,0.0,-AHEAD)
	cam.add_child(_rig)
	_cover = CanvasLayer.new()
	_cover.layer = 120
	var r := ColorRect.new()
	r.color = Color(0.06,0.07,0.08)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(r)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.add_theme_color_override(&"font_color",Color(0.7,0.72,0.74))
	_cover.add_child(_label)
	add_child(_cover)
	_t0 = Time.get_ticks_usec()
	_busy = true

func _process(_delta: float) -> void:
	if _busy: _step()
	if _capturing:
		_tick += 1
		if _tick % CAPTURE_EVERY == 0: _walk(_game)

## One frame of the warm: the last batch taken down, the next put up.
func _step() -> void:
	if _first:
		# The cover's own frame first, so it is up before the first long one.
		_first = false
		return
	for c: Node in _rig.get_children():
		_rig.remove_child(c)
		c.free()
	if _done >= _todo.size():
		print("pipeline warm: %d samples drawn in %.0f ms" % [_todo.size(),(Time.get_ticks_usec()-_t0)/1000.0])
		_busy = false
		_rig.queue_free()
		_rig = null
		_set.free()
		_set = null
		_cover.queue_free()
		_cover = null
		if not _capturing: queue_free()
		return
	_label.text = "Getting the shaders ready  %d / %d" % [_done,_todo.size()]
	_label.position = _label.get_viewport_rect().size*0.5-Vector2(140.0,10.0)
	var n := 0
	while _done < _todo.size() and n < BATCH:
		var src: GeometryInstance3D = _todo[_done]
		# Plain, mirrored, and (when it fades by distance) see-through.
		for k in (3 if src.has_meta(&"warm_fade") else 2):
			var s: GeometryInstance3D = src.duplicate() as GeometryInstance3D
			var x := (float(n)-BATCH*0.5)*CELL*4.0
			s.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(-CELL if k == 1 else CELL,CELL,CELL)),Vector3(x+CELL*1.2*k,0.0,0.0))
			if k == 2: s.transparency = 0.5
			_rig.add_child(s)
		_done += 1
		n += 1

func _exit_tree() -> void:
	if _capturing: _save()

# --- capture ---------------------------------------------------------------

func _start_capture() -> void:
	_capturing = true
	_root = Node3D.new()
	_root.name = "PipelineWarmSet"
	if ResourceLoader.exists(SET):
		var old: Node3D = (load(SET) as PackedScene).instantiate()
		for c: Node in old.get_children():
			old.remove_child(c)
			_root.add_child(c)
			_keys[String(c.get_meta(&"warm_key",""))] = c
		old.free()
	print("pipeline warm: capturing (%d kinds in the set)" % _keys.size())

func _walk(n: Node) -> void:
	if n == _rig or n == self: return
	if n is GeometryInstance3D and (n as Node3D).is_visible_in_tree(): _take(n as GeometryInstance3D)
	for c: Node in n.get_children(): _walk(c)

func _take(gi: GeometryInstance3D) -> void:
	var mesh: Mesh = null
	var mm: MultiMesh = null
	if gi is MeshInstance3D: mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D:
		mm = (gi as MultiMeshInstance3D).multimesh
		if mm != null: mesh = mm.mesh
	if mesh == null: return
	for si in mesh.get_surface_count():
		var m: Material = gi.material_override
		if m == null and gi is MeshInstance3D: m = (gi as MeshInstance3D).get_surface_override_material(si)
		if m == null: m = mesh.surface_get_material(si)
		if m == null: continue
		var sd: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(),si)
		if sd.is_empty(): continue
		var fmt := int(sd.get("format",0))
		var prim := int(sd.get("primitive",RenderingServer.PRIMITIVE_TRIANGLES))
		var key := "%s|%s|f%x|p%d|s%d|t%d" % ["mm%d%d%d" % [mm.transform_format,int(mm.use_colors),int(mm.use_custom_data)] if mm != null else "mi",_mat_key(m),fmt,prim,gi.cast_shadow,int(gi.transparency > 0.0)]
		# A visibility range's fade draws it in the transparent pass while it fades.
		var fade := gi.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if fade: key += "|v1"
		if _keys.has(key): continue
		var tri := _triangle(mesh,si,fmt,prim)
		if tri == null:
			_keys[key] = null
			continue
		var s: GeometryInstance3D
		if mm != null:
			var m2 := MultiMesh.new()
			m2.transform_format = mm.transform_format
			m2.use_colors = mm.use_colors
			m2.use_custom_data = mm.use_custom_data
			m2.mesh = tri
			m2.instance_count = 1
			m2.set_instance_transform(0,Transform3D.IDENTITY)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = m2
			s = mmi
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = tri
			s = mi
		s.material_override = _bare(m)
		s.cast_shadow = gi.cast_shadow
		s.transparency = gi.transparency
		s.layers = gi.layers
		s.name = "W%d" % _keys.size()
		s.set_meta(&"warm_key",key)
		if fade: s.set_meta(&"warm_fade",true)
		s.set_meta(&"warm_from",str(gi.get_path()).right(80))
		_root.add_child(s)
		_keys[key] = s
		print("pipeline warm: new %s from %s" % [key,str(gi.get_path()).right(60)])

## The surface's first primitive, its vertices at a unit triangle (positions
## don't make a pipeline), in the surface's own format.
func _triangle(mesh: Mesh, si: int, fmt: int, prim: int) -> ArrayMesh:
	var arr: Array = mesh.surface_get_arrays(si)
	if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null: return null
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nv := verts.size()
	var want := 1 if prim == Mesh.PRIMITIVE_POINTS else (2 if prim == Mesh.PRIMITIVE_LINES or prim == Mesh.PRIMITIVE_LINE_STRIP else 3)
	if nv < want: return null
	var idx: Array[int] = []
	var ind: Variant = arr[Mesh.ARRAY_INDEX]
	if ind is PackedInt32Array and (ind as PackedInt32Array).size() >= want:
		for i in want: idx.append((ind as PackedInt32Array)[i])
	else:
		for i in want: idx.append(i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in Mesh.ARRAY_MAX:
		if a == Mesh.ARRAY_INDEX or arr[a] == null: continue
		var src: Variant = arr[a]
		var n: int = src.size()
		if n == 0 or n % nv != 0:
			out[a] = src
			continue
		var stride: int = n/nv
		var dst: Variant = src.slice(0,0)
		for v: int in idx:
			for k in stride: dst.append(src[v*stride+k])
		out[a] = dst
	var unit := PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	out[Mesh.ARRAY_VERTEX] = unit.slice(0,want)
	var ia := PackedInt32Array()
	for i in want: ia.append(i)
	if ind != null: out[Mesh.ARRAY_INDEX] = ia
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(prim,out,[],{},fmt & ~(Mesh.ARRAY_FORMAT_VERTEX|Mesh.ARRAY_FORMAT_NORMAL|Mesh.ARRAY_FORMAT_TANGENT|Mesh.ARRAY_FORMAT_COLOR|Mesh.ARRAY_FORMAT_TEX_UV|Mesh.ARRAY_FORMAT_TEX_UV2|Mesh.ARRAY_FORMAT_CUSTOM0|Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|Mesh.ARRAY_FORMAT_CUSTOM3|Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS|Mesh.ARRAY_FORMAT_INDEX))
	if am.get_surface_count() == 0: return null
	var got := int(RenderingServer.mesh_get_surface(am.get_rid(),0).get("format",0))
	if got != fmt: print("pipeline warm: format %x came out %x" % [fmt,got])
	return am

## A copy of the material with its textures dropped (a chain's next passes too).
func _bare(m: Material) -> Material:
	var c: Material = m.duplicate()
	if c is ShaderMaterial:
		var sm := c as ShaderMaterial
		if sm.shader != null:
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				if sm.get_shader_parameter(u.name) is Texture: sm.set_shader_parameter(u.name,null)
	elif c is BaseMaterial3D:
		for p: Dictionary in c.get_property_list():
			if p.type == TYPE_OBJECT and c.get(p.name) is Texture: c.set(p.name,null)
	if c.next_pass != null: c.next_pass = _bare(c.next_pass)
	return c

func _mat_key(m: Material) -> String:
	var k := ""
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		k = "sh:" + ("" if sh == null else (sh.resource_path if sh.resource_path != "" else "code%x" % hash(sh.code)))
	elif m is BaseMaterial3D:
		# A BaseMaterial3D's shader is made from its features and flags.
		k = "std:%x" % hash(_std_sig(m as BaseMaterial3D))
	else:
		k = m.get_class()
	if m.next_pass != null: k += "+" + _mat_key(m.next_pass)
	return k

func _std_sig(b: BaseMaterial3D) -> String:
	var s := ""
	for p: Dictionary in b.get_property_list():
		if p.type == TYPE_BOOL or (p.type == TYPE_INT and String(p.name) not in ["render_priority"]):
			s += "%s=%s;" % [p.name,str(b.get(p.name))]
	return s

func _save() -> void:
	for c: Node in _root.get_children(): c.owner = _root
	var ps := PackedScene.new()
	var err := ps.pack(_root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SET.get_base_dir()))
		err = ResourceSaver.save(ps,SET,ResourceSaver.FLAG_COMPRESS)
	print("pipeline warm: saved %d samples to %s (%s)" % [_root.get_child_count(),SET,error_string(err)])
	_root.free()
	_capturing = false
