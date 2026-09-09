extends Node3D
## Temper is independent of locomotion: interruptions and water still own his body.
var scene: Node
var heat := 0.0
var remaining := 0.0
var enraged: bool:
	get: return remaining>0.0
var _eyes: Array[MeshInstance3D] = []
var _originals: Array[Material] = []
var _red := StandardMaterial3D.new()
var _puffs: Array[MeshInstance3D] = []
var _ages: Array[float] = []
var _velocities: Array[Vector3] = []
var _clock := 0.0
var _emit := 0.0
var _next := 0

func setup(playground: Node) -> void:
	scene = playground
	_red.albedo_color = Color(1.0,0.035,0.015)
	_red.emission_enabled = true
	_red.emission = Color(1.0,0.02,0.005)
	_red.emission_energy_multiplier = 2.5
	for mesh in scene.creature.actor.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(surface)
			if material!=null and "eyes" in material.resource_name.to_lower():
				_eyes.append(mesh)
				_originals.append(mesh.material_override)
				break
	var ball := SphereMesh.new()
	ball.radius = 0.10
	ball.height = 0.2
	ball.radial_segments = 8
	ball.rings = 4
	for i in range(16):
		var puff := MeshInstance3D.new()
		puff.mesh = ball
		var steam := StandardMaterial3D.new()
		steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		steam.albedo_color = Color(0.92,0.94,0.95,0.7)
		steam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = steam
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.visible = false
		add_child(puff)
		_puffs.append(puff)
		_ages.append(2.0)
		_velocities.append(Vector3.ZERO)

func provoke(amount: float = 0.4) -> void:
	if scene._paused: return
	if enraged:
		remaining = minf(30.0,remaining+amount*8.0)
		return
	heat = clampf(heat+amount,0.0,1.0)
	if heat>=1.0:
		remaining = 24.0
		scene.creature.action_tempo = 1.4
		for eye in _eyes: eye.material_override = _red
		scene.mischief._cooldown = 0.0
		scene._show_reaction("!!","That's it. He's steaming.")

func advance(delta: float) -> void:
	if scene._paused: return
	_clock += delta
	if enraged:
		remaining = maxf(0.0,remaining-delta)
		if not enraged:
			reset()
			scene._show_reaction("…","Deep breaths. Back to the forest.")
	else: heat = maxf(0.0,heat-delta*0.025)
	_emit -= delta
	if enraged and _emit<=0.0:
		_emit = 0.16
		var actor: CreatureActor = scene.creature
		var head: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor._head).origin)
		for side in [-1.0,1.0]:
			var puff := _puffs[_next]
			puff.global_position = head+actor.global_basis*Vector3(side*0.38,0.25,0)
			_velocities[_next] = actor.global_basis*Vector3(side*0.65,0.5,0.04*sin(_clock*13.0))
			_ages[_next] = 0.0
			_next = (_next+1)%_puffs.size()
	for i in range(_puffs.size()):
		_ages[i] += delta
		var age := _ages[i]
		_puffs[i].visible = age<1.1 and enraged
		if _puffs[i].visible:
			_puffs[i].global_position += _velocities[i]*delta
			_puffs[i].scale = Vector3.ONE*(0.6+age*2.2)
			_puffs[i].material_override.albedo_color.a = 0.75*(1.0-age/1.1)

func reset() -> void:
	heat = 0.0
	remaining = 0.0
	if scene!=null: scene.creature.action_tempo = 1.0
	for i in range(_eyes.size()): _eyes[i].material_override = _originals[i]
	for puff in _puffs: puff.visible = false
	for i in range(_ages.size()): _ages[i] = 2.0
