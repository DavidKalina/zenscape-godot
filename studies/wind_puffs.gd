extends RefCounted
## Source wind.js six-slot parcel lifecycle. Births are measured in air distance.
var parcels := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
## Each parcel's own heading (world x, z, unit); zero rides the global wind
## direction, as every source parcel does. Published packed in pairs as
## zs_puff_heading_0..2 (parcels 2i in xy, 2i+1 in zw).
var headings := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
## Slots a steering owner holds (scripts/wind_gust.gd): it writes the parcel
## and heading every frame, so the source lifecycle neither merges into,
## replaces nor retires them.
var held := PackedByteArray([0, 0, 0, 0, 0, 0])

func puff(center: Vector2, direction: Vector2, travel: float, wind: float, strength := 0.45) -> int:
	var newest := -1
	var oldest := -1
	for i in range(parcels.size()):
		if held[i] != 0:
			continue
		var p := parcels[i]
		if p.w > 0.0 and (newest < 0 or p.z > parcels[newest].z):
			newest = i
		if oldest < 0 or (parcels[oldest].w > 0.0 and (p.w <= 0.0 or p.z < parcels[oldest].z)):
			oldest = i
	if oldest < 0:
		return -1
	if newest >= 0 and travel - parcels[newest].z < (1.6 + 1.9 * wind) * 1.2:
		var p := parcels[newest]
		p.w = minf(0.8, p.w + strength * 0.6)
		parcels[newest] = p
		return newest
	var origin := center - direction * 5.0
	parcels[oldest] = Vector4(origin.x, origin.y, travel, minf(0.8, strength))
	headings[oldest] = Vector2.ZERO
	return oldest

func retire(travel: float) -> void:
	for i in range(parcels.size()):
		if held[i] == 0 and parcels[i].w > 0.0 and travel - parcels[i].z > 52.0:
			var p := parcels[i]
			p.w = 0.0
			parcels[i] = p

## Take a slot for steering: an idle one, else the oldest unheld. -1 when
## all are held.
func hold_slot() -> int:
	var pick := -1
	for i in range(parcels.size()):
		if held[i] != 0:
			continue
		if parcels[i].w <= 0.0:
			pick = i
			break
		if pick < 0 or parcels[i].z < parcels[pick].z:
			pick = i
	if pick >= 0:
		held[pick] = 1
		parcels[pick] = Vector4.ZERO
		headings[pick] = Vector2.ZERO
	return pick

## A held slot's parcel and heading for this frame.
func steer(slot: int, parcel: Vector4, heading: Vector2) -> void:
	if slot < 0 or slot >= parcels.size() or held[slot] == 0:
		return
	parcels[slot] = parcel
	headings[slot] = heading

## Give a held slot back, empty.
func let_go(slot: int) -> void:
	if slot < 0 or slot >= parcels.size():
		return
	held[slot] = 0
	parcels[slot] = Vector4.ZERO
	headings[slot] = Vector2.ZERO

func _heading(i: int, direction: Vector2) -> Vector2:
	return headings[i] if headings[i].length_squared() > 0.25 else direction

func sample_at(position: Vector2, direction: Vector2, travel: float) -> float:
	var value := 0.0
	for i in range(parcels.size()):
		var p := parcels[i]
		if p.w <= 0.0:
			continue
		var dir := _heading(i, direction)
		var age := travel - p.z
		var r := position - (Vector2(p.x, p.y) + dir * age)
		var along := r.dot(dir)
		var across := r.dot(Vector2(-dir.y, dir.x))
		var shape := exp(-(along * along / 36.0 + across * across / 12.96))
		value += p.w * shape * smoothstep(0.0, 1.5, age) * (1.0 - smoothstep(30.0, 52.0, age))
	return value

## The parcels' push at `position`: each one's pulse along its own heading.
## Parcels without a heading push along `direction`, so this is
## `direction * sample_at` until something steers a parcel.
func push_at(position: Vector2, direction: Vector2, travel: float) -> Vector2:
	var push := Vector2.ZERO
	for i in range(parcels.size()):
		var p := parcels[i]
		if p.w <= 0.0:
			continue
		var dir := _heading(i, direction)
		var age := travel - p.z
		var r := position - (Vector2(p.x, p.y) + dir * age)
		var along := r.dot(dir)
		var across := r.dot(Vector2(-dir.y, dir.x))
		var shape := exp(-(along * along / 36.0 + across * across / 12.96))
		push += dir * p.w * shape * smoothstep(0.0, 1.5, age) * (1.0 - smoothstep(30.0, 52.0, age))
	return push

func publish() -> void:
	for i in range(parcels.size()):
		RenderingServer.global_shader_parameter_set("zs_puff_%d" % i, parcels[i])
	for i in range(3):
		var a := headings[i * 2]
		var b := headings[i * 2 + 1]
		RenderingServer.global_shader_parameter_set("zs_puff_heading_%d" % i, Vector4(a.x, a.y, b.x, b.y))
