extends "res://scripts/planar_water.gd"
## One planar reflection view for live water (scripts/water_flow_view.gd,
## docs/scenic/water-flow.md), so a simulated pond reflects the land, reads its
## bed through the shallows and draws its shore foam per pixel, as the planned
## ponds' views do (scripts/planar_water.gd, whose copying this reuses).
##
## A live pond's level moves while it fills, and a planned pond's view is set
## up again for every new level. This one view is set up once, when live water
## first stands deep enough, and then follows the largest pond: moving its
## level only moves the mirror camera and sets the clip level on the copies'
## materials, which costs no setup. Water further than BAND from the view's
## level (a second pond, higher or lower) fades to the ordinary surface in the
## shader (`planar_band`) instead of taking a displaced reflection.

## Metres the followed pond moves before the view moves with it.
const LEVEL_STEP := 0.01
## Square metres of standing water before a view is worth its cost.
const MIN_AREA := 1.5
## Metres from the view's level over which the reflection fades out.
const BAND := 0.3
## A smaller pond at the followed level keeps the view unless another is this
## many times larger.
const SWITCH_SHARE := 1.6

## The live still water's material (a copy of the ponds'), which draws with
## the view, and the lift its mesh stands above the water.
var still_material: ShaderMaterial
var lift := 0.0
## The level the view reflects about (water surface, without the lift), or NAN.
var level := NAN
var _content_revision := -1
var _view_on := false
## Microseconds of the last sync, for probes.
var last_sync_usec := 0

## `still_source`/`moving_source`: the ponds' and streams' materials the live
## copies follow, as the planned ponds' views follow theirs.
func setup_live(still_copy: ShaderMaterial, still_source: ShaderMaterial, moving_copy: ShaderMaterial, moving_source: ShaderMaterial, surface_lift: float) -> void:
	still_material = still_copy
	lift = surface_lift
	var own := ["hide_pool_surface","planar_enabled","planar_reflection","reflection_matrix","caustics_strength","planar_levels","planar_band","planar_level","flow_edge_fade","shore_distance","live_thin","live_level","bed_absorb","fall_foam","fall_foam_count"]
	for pair: Array in [[still_copy,still_source],[moving_copy,moving_source]]:
		var names := PackedStringArray()
		for parameter in pair[1].shader.get_shader_uniform_list():
			if not parameter.name in own: names.append(parameter.name)
		_bind_material("pond:live:" + str(pair[0].get_instance_id()),"pond:" + str(pair[1].get_instance_id()),pair[1],pair[0],names)
	still_material.set_shader_parameter("planar_band",BAND)
	still_material.set_shader_parameter("caustics_strength",0.45)

## Called every frame with the standing water (`WaterFlow.pools`).
func sync_live(scene: Node3D, frame_tree: SceneTree, pools: Array) -> void:
	var began := Time.get_ticks_usec()
	_scene = scene
	camera = scene.camera
	var wanted := _wanted_level(pools)
	var shown: bool = enabled and not is_nan(wanted) and RenderingServer.get_current_rendering_method() == "forward_plus" and scene._growth.terrain >= 0.995 and scene._growth.water >= 0.995 and scene.can_process()
	if is_nan(wanted) and (not views.is_empty() or _setup_busy):
		_drop_view()
	elif shown and views.is_empty() and not _setup_busy:
		_build(scene,wanted,frame_tree)
	elif shown and not views.is_empty() and not _setup_busy:
		var content: GardenView = scene._chunk_editor.content
		var data: NativeTerrainData = scene._chunk_editor.data
		if _content_revision != content.revision or objects_revision != data.objects_revision or instances_revision != content.instances_revision:
			# New plants, props or streams: copy them over a few frames while
			# the old copies keep showing.
			_content_revision = content.revision
			objects_revision = data.objects_revision
			instances_revision = content.instances_revision
			_refresh_geometry_live(scene,frame_tree)
	if shown and not views.is_empty() and absf(wanted-level) > LEVEL_STEP:
		_move_level(wanted)
	_show(shown and not views.is_empty())
	if _view_on:
		if _setup_busy and _busy_kind == "geometry": _update_view_list(views,_old_bindings)
		else: update_views()
	else: _sync_materials()
	last_sync_usec = Time.get_ticks_usec()-began

## The level of the largest standing water, keeping the followed pond while
## it is not much smaller than the largest.
func _wanted_level(pools: Array) -> float:
	var largest := {}
	var kept := {}
	for pool: Dictionary in pools:
		if float(pool.area) < MIN_AREA: continue
		if largest.is_empty() or float(pool.area) > float(largest.area): largest = pool
		if not is_nan(level) and absf(float(pool.level)-level) < BAND and (kept.is_empty() or float(pool.area) > float(kept.area)): kept = pool
	if largest.is_empty(): return NAN
	if not kept.is_empty() and float(largest.area) < float(kept.area)*SWITCH_SHARE: return float(kept.level)
	return float(largest.level)

func _show(value: bool) -> void:
	if value == _view_on: return
	_view_on = value
	visible = value
	still_material.set_shader_parameter("planar_enabled",value)
	for view in views:
		view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

## The view, as a planned pond's (planar_water.gd `setup`), without its own
## surface: the live still mesh draws with it.
func _build(scene: Node3D, at: float, frame_tree: SceneTree) -> void:
	_setup_generation += 1
	var generation := _setup_generation
	_setup_busy = true
	_busy_kind = "setup"
	var content: GardenView = scene._chunk_editor.content
	_content_revision = content.revision
	objects_revision = scene._chunk_editor.data.objects_revision
	instances_revision = content.instances_revision
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,320)
	viewport.own_world_3d = true
	viewport.msaa_3d = scene.get_viewport().msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = scene._environment.duplicate()
	environment.environment.volumetric_fog_enabled = false
	environment.environment.ssr_enabled = false
	viewport.add_child(environment)
	if not await _copy_geometry(scene,viewport,at,frame_tree): return
	if generation != _setup_generation or not is_instance_valid(scene): return
	for light in scene._lights:
		var copy := DirectionalLight3D.new()
		copy.transform = light.global_transform
		copy.light_color = light.light_color
		copy.light_energy = light.light_energy
		copy.shadow_enabled = false
		copy.directional_shadow_mode = light.directional_shadow_mode
		copy.directional_shadow_max_distance = 80.0
		copy.shadow_normal_bias = light.shadow_normal_bias
		viewport.add_child(copy)
	var mirror := Camera3D.new()
	viewport.add_child(mirror)
	mirror.current = true
	still_material.set_shader_parameter("planar_reflection",viewport.get_texture())
	views = [{"viewport":viewport,"camera":mirror,"material":still_material,"level":at,"environment":environment.environment,"lights":viewport.get_children().filter(func(n): return n is DirectionalLight3D)}]
	level = at
	still_material.set_shader_parameter("planar_level",at+lift)
	_setup_busy = false
	_busy_kind = ""
	_view_on = false

## Follows the pond: the mirror reads `level` every frame; the copies clip at it.
func _move_level(at: float) -> void:
	level = at
	for view in views: view.level = at
	still_material.set_shader_parameter("planar_level",at+lift)
	for key: String in _material_bindings:
		if key.begins_with("pond:"): continue
		_material_bindings[key].target.set_shader_parameter("zs_clip_level",at+0.015)

## No standing water: the view and its copies go; the material bindings stay.
func _drop_view() -> void:
	_setup_generation += 1
	_setup_busy = false
	_busy_kind = ""
	_show(false)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	views = []
	_bindings = []
	_old_bindings = []
	for key: String in _material_bindings.keys():
		if not key.begins_with("pond:"): _material_bindings.erase(key)
	_groups_dirty = true
	level = NAN
	_prune_shaders()
