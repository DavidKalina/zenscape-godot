extends RefCounted
## Shared parts for the small ambient life (dragonflies, butterflies, the
## woodpecker, geese; docs/scenic/life.md): hidden MultiMesh batches, mirrored
## double-sided wings, weather reads and a few synthesised sounds. Every model
## is built from LifeModels' faceted parts and drawn with LandLife's shared
## Fidelity material, so nothing new compiles.

const Models = preload("res://scripts/life_models.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const Sound = preload("res://scripts/genesis_audio.gd")

const RATE := 22050

static func hidden() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE*0.00001),Vector3(0,-50,0))

## A batch of `count` creatures' parts under `parent`, all hidden and white.
## The box is generous: creatures range over the whole plate.
static func batch(parent: Node3D, label: String, mesh: Mesh, count: int) -> MultiMesh:
	var node := MultiMeshInstance3D.new()
	node.name = label
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.instance_count = count
	instances.mesh = mesh
	instances.custom_aabb = AABB(Vector3(-40,-4,-40),Vector3(80,60,80))
	for i in range(count):
		instances.set_instance_transform(i,hidden())
		instances.set_instance_color(i,Color.WHITE)
	node.multimesh = instances
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return instances

## A wing reaching along +X from its root: a fan whose inner part is `base` and
## rim `edge`, drawn from both sides so a mirrored copy (negative X scale)
## still shows.
static func wing(material: Material, rim: Array, base: Color, edge: Color, hub := Vector3.ZERO) -> ArrayMesh:
	var b := Models.Build.new()
	b.fin(hub,rim,base,edge)
	var back := rim.duplicate()
	back.reverse()
	b.fin(hub,back,base,edge)
	return b.commit(material)

## A wing's transform on a body at `body`: root offset `root` (x is the right
## wing's side; the left mirrors it), lifted by `angle` radians about the body's
## length, and pitched by `sweep` about its width.
static func wing_pair(body: Transform3D, root: Vector3, angle: float, sweep := 0.0, size := 1.0) -> Array[Transform3D]:
	var right := Transform3D(Basis(Vector3(0,0,1),angle)*Basis(Vector3.UP,sweep)*Basis.from_scale(Vector3.ONE*size),root)
	var left := Transform3D(Basis(Vector3(0,0,1),-angle)*Basis(Vector3.UP,-sweep)*Basis.from_scale(Vector3(-size,size,size)),Vector3(-root.x,root.y,root.z))
	return [body*right,body*left]

static func rain(life: Node3D) -> float:
	return float(life.scene._precipitation.state.x)

static func unit(key: Array) -> float:
	return Variety.unit(key)

## Smooth ease of `value` toward `target`, in `step` seconds at `rate` per second.
static func ease_to(value: float, target: float, rate: float, step: float) -> float:
	return lerpf(value,target,1.0-exp(-rate*step))

## The camera in LandLife's plate space, or `fallback`.
static func camera_local(life: Node3D, fallback := Vector3(0,20,40)) -> Vector3:
	var camera: Variant = life.scene.get("camera")
	return life.to_local((camera as Node3D).global_position) if camera is Node3D else fallback

# --- Sounds ---------------------------------------------------------------

## A one-shot 3D player on the Genesis bus (or its distant one), with distance
## falloff, so it follows the Sound settings.
static func speaker(parent: Node3D, far := false) -> AudioStreamPlayer3D:
	Sound.ensure_buses()
	var player := AudioStreamPlayer3D.new()
	player.bus = Sound.FAR_BUS if far else Sound.BUS
	player.panning_strength = 0.6
	player.unit_size = 10.0
	player.max_distance = 90.0
	parent.add_child(player)
	return player

static func pcm(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for s in samples: peak = maxf(peak,absf(s))
	var bytes := PackedByteArray()
	bytes.resize(samples.size()*2)
	for i in range(samples.size()): bytes.encode_s16(i*2,int(clampf(samples[i]/peak*0.9,-1.0,1.0)*32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream

## A drum roll on dead wood: dry knocks (a burst of noise over two wooden
## resonances) about `rate` a second for `seconds`, each a touch different, the
## roll swelling in and dying off.
static func drum_roll(seconds: float, rate: float, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := PackedFloat32Array()
	out.resize(int((seconds+0.1)*RATE))
	var knock := int(0.022*RATE)
	var t := 0.0
	while t < seconds:
		var u := t/seconds
		var gain := smoothstep(0.0,0.12,u)*(1.0-0.45*smoothstep(0.55,1.0,u))*rng.randf_range(0.8,1.0)
		var tone := rng.randf_range(0.92,1.08)
		var start := int(t*RATE)
		for i in range(knock):
			var age := float(i)/RATE
			var env := exp(-age/0.0045)
			var v := (rng.randf_range(-1.0,1.0)*0.55+sin(TAU*1150.0*tone*age)*0.55+sin(TAU*2350.0*tone*age)*0.18)*env*gain
			if start+i < out.size(): out[start+i] += v
		t += (1.0/rate)*rng.randf_range(0.9,1.1)
	return pcm(out)

## A goose's honk: a buzzy, nasal call gliding down, with a rough wobble.
static func honk(seconds: float, pitch: float, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var count := int(seconds*RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in range(count):
		var u := float(i)/count
		var f := pitch*(1.08-0.3*u)*(1.0+0.03*sin(TAU*31.0*u*seconds))
		phase += TAU*f/RATE
		var v := 0.0
		for h in range(1,11):
			var at := f*h
			v += sin(phase*h)/h*(1.0+1.6*exp(-pow((at-1050.0)/380.0,2.0)))
		v += rng.randf_range(-0.12,0.12)
		var env := smoothstep(0.0,0.06,u)*(1.0-smoothstep(0.55,1.0,u))
		out[i] = v*env*(0.75+0.25*sin(TAU*58.0*u*seconds))
	return pcm(out)
