extends RefCounted
## Source wind.js six-slot parcel lifecycle. Births are measured in air distance.
var parcels := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])

func puff(center: Vector2, direction: Vector2, travel: float, wind: float, strength := 0.45) -> int:
	var newest := -1
	var oldest := -1
	for i in range(parcels.size()):
		var p := parcels[i]
		if p.w > 0.0 and (newest < 0 or p.z > parcels[newest].z):
			newest = i
		if oldest < 0 or (parcels[oldest].w > 0.0 and (p.w <= 0.0 or p.z < parcels[oldest].z)):
			oldest = i
	if newest >= 0 and travel - parcels[newest].z < (1.6 + 1.9 * wind) * 1.2:
		var p := parcels[newest]
		p.w = minf(0.8, p.w + strength * 0.6)
		parcels[newest] = p
		return newest
	var origin := center - direction * 5.0
	parcels[oldest] = Vector4(origin.x, origin.y, travel, minf(0.8, strength))
	return oldest

func retire(travel: float) -> void:
	for i in range(parcels.size()):
		if parcels[i].w > 0.0 and travel - parcels[i].z > 52.0:
			var p := parcels[i]
			p.w = 0.0
			parcels[i] = p

func sample_at(position: Vector2, direction: Vector2, travel: float) -> float:
	var value := 0.0
	for p in parcels:
		if p.w <= 0.0:
			continue
		var age := travel - p.z
		var r := position - (Vector2(p.x, p.y) + direction * age)
		var along := r.dot(direction)
		var across := r.dot(Vector2(-direction.y, direction.x))
		var shape := exp(-(along * along / 36.0 + across * across / 12.96))
		value += p.w * shape * smoothstep(0.0, 1.5, age) * (1.0 - smoothstep(30.0, 52.0, age))
	return value

func publish() -> void:
	for i in range(parcels.size()):
		RenderingServer.global_shader_parameter_set("zs_puff_%d" % i, parcels[i])
