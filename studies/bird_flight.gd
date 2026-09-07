extends RefCounted
## Source birds.js thermal steering, crossings, stoops, pull-ups and effort.
signal bird_call(position: Vector3)
var birds: Array = []
var columns: Array = []
var growth := 1.0
var swell := 0.0
var swell_target := 0.0
var random_seed := 7311
var ground: RefCounted
var mesh: MultiMesh
var bounds := 14.56
var species := "gull"
func random_value() -> float:
	random_seed = (random_seed * 1664525 + 1013904223) & 0xffffffff
	return float(random_seed) / 4294967296.0
func setup(multimesh: MultiMesh, terrain: RefCounted, data: Dictionary) -> void:
	birds = data.birds.duplicate(true)
	columns = data.cols.duplicate(true)
	species = data.species
	ground = terrain
	mesh = multimesh
	mesh.custom_aabb = AABB(Vector3(-24,-10,-24),Vector3(48,80,48))
	mesh.instance_count = 0
	mesh.use_custom_data = true
	mesh.instance_count = birds.size()
	for i in range(birds.size()):
		if mesh.use_colors:
			mesh.set_instance_color(i,Color.WHITE)
		publish(i, birds[i], float(birds[i].out))
func height_at(x: float, z: float) -> float:
	var h: Variant = ground.height_at(x,z)
	return float(h) if h != null else 0.6
func publish(i: int, b: Dictionary, amount: float) -> void:
	var pitch := -atan2(float(b.vy), maxf(Vector2(b.vx,b.vz).length(),0.5)) * (0.55 if b.mode == "soar" else 0.85)
	var scale := float(b.s) * amount if amount > 0.001 else 0.00001
	mesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(pitch,b.yaw,b.roll),EULER_ORDER_YXZ).scaled(Vector3.ONE * scale),Vector3(b.x,b.y,b.z)))
	mesh.set_instance_custom_data(i,Color(b.flap,b.phase,0,1))
func startle(at: Vector3) -> void:
	for b: Dictionary in birds:
		var direction := Vector2(b.x-at.x,b.z-at.z).normalized()
		b.vx += direction.x * 4.0
		b.vz += direction.y * 4.0
		b.vy += 2.6
		b.flap = 1.0
		b.mode = "pullup"
		b.timer = 2.2 + random_value() * 1.5
func advance(delta: float, paused: bool, wind: float, direction: Vector2) -> void:
	if paused or delta <= 0:
		# Growth controls remain live while the simulation clock is stopped.
		var reach := growth + minf(growth,swell)
		for i in range(birds.size()):
			var b: Dictionary = birds[i]
			b.out = smoothstep(float(b.delay),float(b.delay)+0.25,reach)
			publish(i,b,b.out)
		return
	var dt := minf(delta,0.05)
	swell += (swell_target-swell) * minf(1.0,dt/40.0)
	var reach := growth + minf(growth,swell)
	for i in range(birds.size()):
		var b: Dictionary = birds[i]
		var amount := smoothstep(float(b.delay),float(b.delay)+0.25,reach)
		b.out = amount
		if amount <= 0.001:
			publish(i,b,0.0)
			continue
		var c: Dictionary = columns[int(b.col)]
		var dx: float = c.x-b.x
		var dz: float = c.z-b.z
		var r := maxf(Vector2(dx,dz).length(),0.0001)
		b.timer -= dt
		if b.mode == "stoop" and r < c.r*1.5:
			b.timer = minf(b.timer,0.05)
		if b.timer <= 0:
			if b.mode == "soar" and columns.size() > 1:
				var next := int(b.col)
				while next == int(b.col):
					next = int(random_value()*columns.size())
				b.col = next
				b.mode = "stoop" if species == "gull" and random_value() < 0.5 else "cross"
				b.timer = 7.0 + random_value()*7.0
				if growth > 0.7 and random_value() < 0.6:
					bird_call.emit(Vector3(b.x,b.y,b.z))
			elif b.mode == "stoop":
				b.mode = "pullup"
				b.timer = 2.8
			else:
				b.mode = "soar"
				b.timer = 9.0 + random_value()*22.0
		b.blend += ((0.0 if b.mode == "soar" else 1.0)-b.blend)*minf(1.0,1.6*dt)
		var speed: float = b.speed*(1.0+(0.55 if b.mode == "stoop" else 0.0)+(0.15 if b.mode == "pullup" else 0.0))
		var rs := maxf(r,c.r*0.6)
		var radial := Vector2(dx,dz)/rs
		var tangent := Vector2(-radial.y,radial.x)*float(b.spin)
		var pull := clampf((r-c.r)*0.5,-1.6,1.6)
		var desired := tangent*speed+radial*pull*speed
		var arrive := smoothstep(c.r*1.7,c.r*0.9,r)
		var beeline: float = (1.0-arrive)*b.blend
		var aim := desired*(1.0-beeline)+radial*speed*beeline
		b.vx += (aim.x-b.vx)*1.6*dt + direction.x*wind*0.22*dt
		b.vz += (aim.y-b.vz)*1.6*dt + direction.y*wind*0.22*dt
		var terrain := maxf(height_at(b.x,b.z),height_at(b.x+b.vx*0.7,b.z+b.vz*0.7))
		var clearance := 1.5 if b.mode == "stoop" else 2.2
		var floor_y := terrain+clearance
		var in_column := (1.0-smoothstep(c.r*0.4,c.r*2.4,r))*(1.0-beeline)
		var room := 1.0-smoothstep(c.top-3.0,c.top,b.y)
		var climb: float = c.lift*in_column*room-0.75
		var rate := 1.1
		if b.mode == "stoop":
			climb = -7.0*smoothstep(0.3,3.5,b.y-floor_y)
			rate = 3.0
		elif b.mode == "pullup":
			climb = 6.0
			rate = 3.4
		b.vy += (climb-b.vy)*rate*dt
		var effort := 0.0
		if b.y < floor_y+2.5:
			effort = smoothstep(floor_y+2.5,floor_y-1.0,b.y)
			b.vy += effort*7.0*dt
		var cap_y := maxf(c.top,floor_y+3.0)
		if b.y > cap_y:
			b.vy -= (b.y-cap_y)*1.6*dt
		if absf(b.x)>bounds:
			b.vx -= signf(b.x)*5.0*dt
		if absf(b.z)>bounds:
			b.vz -= signf(b.z)*5.0*dt
		b.x += b.vx*dt
		b.z += b.vz*dt
		b.y += b.vy*dt
		var hard := height_at(b.x,b.z)+clearance*0.8
		if b.y < hard:
			b.y = hard
			b.vy = maxf(b.vy,0.0)
		var turn := wrapf(atan2(b.vx,b.vz)-b.yaw,-PI,PI)
		var step := clampf(turn,-3.0*dt,3.0*dt)
		b.yaw += step
		var roll := clampf(-step/maxf(dt,0.0001)*0.42,-1.15,1.15)
		b.roll += (roll-b.roll)*minf(1.0,6.0*dt)
		var work := 0.0 if b.mode == "stoop" else 1.0 if b.mode == "pullup" else clampf(effort+maxf(0.0,-climb*0.35)+absf(b.roll)*0.22,0.0,1.0)
		b.flap += (0.06+work*0.85-b.flap)*minf(1.0,(9.0 if b.mode == "pullup" else 2.5)*dt)
		b.phase += dt*(4.5+b.flap*7.0)*(1.0 if species == "gull" else 0.65)
		publish(i,b,amount)
