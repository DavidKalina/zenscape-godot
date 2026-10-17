extends Node3D
## A rune spilled out of the rune knight by a riposte
## (docs/design/rune-knight/spec-rune-knight.md, "The riposte spills his
## runes"): glowing shards and the rune's light burst out of the groove,
## scatter round him and come down on the deck or turf, flaring, then
## guttering out over a few seconds, flickering, till they are gone.
##
## Set by his body (`set_effect("rune_spill", true, rune)`) at the rune's
## socket, top level in the isle; frees itself when its light is out.

## Shards, their size (share of his height), the burst's speed (m/s, out
## and up, share of his height per s), the fall (m/s^2).
const SHARDS := 40
const SHARD := 0.09
const OUT := 0.85
const UP := 1.3
const FALL := 16.0
## The light: a flare (s), the glow held (s), then guttering out (s).
const FLARE := 0.25
const HOLD := 2.2
const GUTTER := 2.4
const LIT := 10.0
const LIGHT := 10.0

var tint := Color(0.55,0.85,1.0)
var tall := 3.0
var out_way := Vector3.FORWARD
var _t := 0.0
var _rng := RandomNumberGenerator.new()
## Per shard: [node, velocity, spin (axis*rad/s), resting, its own fade lag].
var _shards: Array = []
var _mat: StandardMaterial3D
var _light: OmniLight3D
## The burst's flash: a bright ball of the rune's light, out and gone.
const FLASH := 0.3
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D

func _init() -> void:
	name = "RuneSpill"

func _ready() -> void:
	_rng.randomize()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = tint.darkened(0.6)
	_mat.emission_enabled = true
	_mat.emission = tint
	_mat.emission_energy_multiplier = LIT*1.6
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var flat := Vector3(out_way.x,0.0,out_way.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	for i in SHARDS:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = _mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s := SHARD*tall*_rng.randf_range(0.5,1.4)
		m.scale = Vector3(s*_rng.randf_range(0.3,0.7),s*_rng.randf_range(1.0,2.2),s*_rng.randf_range(0.2,0.5))
		m.rotation = Vector3(_rng.randf()*TAU,_rng.randf()*TAU,_rng.randf()*TAU)
		add_child(m)
		# Out of the groove: mostly out his front, spraying round him.
		var a := _rng.randf_range(-PI,PI)
		var round_ := Vector3(cos(a),0.0,sin(a))
		var way := (flat*1.2+round_).normalized() if i % 3 != 0 else round_
		var v := way*OUT*tall*_rng.randf_range(0.35,1.0)+Vector3.UP*UP*tall*_rng.randf_range(0.3,1.0)
		var spin := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized()*_rng.randf_range(6.0,16.0)
		_shards.append([m,v,spin,false,_rng.randf_range(0.0,0.9)])
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.omni_range = 0.5*tall*LIGHT
	_light.light_energy = LIGHT
	add_child(_light)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(tint.r,tint.g,tint.b,1.0)
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	_flash = MeshInstance3D.new()
	_flash.mesh = ball
	_flash.material_override = _flash_mat
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash)

## The light's strength now (0..1+): the flare, the hold, the gutter.
func light_at(t: float) -> float:
	if t < FLARE: return 1.0+1.5*(1.0-t/FLARE)
	if t < FLARE+HOLD: return 1.0
	return maxf(1.0-(t-FLARE-HOLD)/GUTTER,0.0)

func lasts() -> float:
	return FLARE+HOLD+GUTTER+0.9

func _process(delta: float) -> void:
	if delta <= 0.0: return
	_t += delta
	var k := light_at(_t)
	var flick := 1.0 if _t < FLARE+HOLD*0.5 or sin(_t*41.0)+sin(_t*23.0) > -0.4 else 0.4
	_mat.emission_energy_multiplier = LIT*k*flick
	_light.light_energy = LIGHT*k*flick
	if _flash != null:
		var u := _t/FLASH
		if u >= 1.0:
			_flash.queue_free()
			_flash = null
		else:
			_flash.scale = Vector3.ONE*tall*lerpf(0.15,0.7,sqrt(u))
			_flash_mat.albedo_color.a = (1.0-u)*(1.0-u)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var mid := Vector3.ZERO
	for f: Array in _shards:
		var m: MeshInstance3D = f[0]
		var lag: float = f[4]
		if light_at(maxf(_t-lag,0.0)) <= 0.0: m.visible = false
		mid += m.global_position
		if f[3]: continue
		var v: Vector3 = f[1]
		v += Vector3.DOWN*FALL*delta
		var at := m.global_position
		var to := at+v*delta
		if space != null:
			var ray := PhysicsRayQueryParameters3D.new()
			ray.collision_mask = 1 | (1 << 11)
			ray.from = at
			ray.to = to+Vector3.DOWN*0.02
			var hit := space.intersect_ray(ray)
			if not hit.is_empty():
				var nrm: Vector3 = hit.normal
				to = (hit.position as Vector3)+nrm*0.02
				if nrm.y > 0.5 and absf(v.y) < 2.5:
					f[3] = true
					v = Vector3.ZERO
				else:
					v = (v-nrm*v.dot(nrm)*1.5)*0.45
		var spin: Vector3 = f[2]
		if spin.length() > 0.01:
			m.global_basis = Basis(spin.normalized(),spin.length()*delta)*m.global_basis
			f[2] = spin*(0.4 if f[3] else 1.0)
		m.global_position = to
		f[1] = v
	if not _shards.is_empty(): _light.global_position = mid/float(_shards.size())+Vector3.UP*0.3*tall*0.3
	if _t > lasts(): queue_free()

## How many shards are down (for the drivers), and how many there are.
func shards_at_rest() -> Vector2i:
	var n := 0
	for f: Array in _shards:
		if f[3]: n += 1
	return Vector2i(n,_shards.size())
