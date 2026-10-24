extends RefCounted
## Overgrown's paint, flora and dressing layers
## (scripts/endless/world/profiles/overgrown.gd). For now wilderness's; the
## palette and overgrowth round gives it its own.

static func flora() -> Dictionary:
	return {"forest":0.5,"forest_meadows":0.5,
		"tree_weights":PackedFloat32Array([1.0,0.8,0.4,3.0,3.0,1.5]),"grass":1.0,"grass_tall":1.5,"flowers":true}

static func paint() -> Dictionary:
	return {"mood":"desert_afternoon","hour":14.8,
		"ground":{"carpet_tone_top":Vector3(3.0,0.92,0.42),"carpet_tone_low":Vector3(2.8,0.80,0.38),
			"carpet_under_tone":Vector3(2.2,0.56,0.22)},
		"far":{"root_colour":Vector3(0.20,0.085,0.03),"tip_colour":Vector3(0.62,0.30,0.08)},
		# The undersides the wash and the wind bow into view: pale straw, not sage.
		"silver_colour":Vector3(0.80,0.64,0.42),
		"sea":{},
		"globals":{"zs_autumn":1.0,"zs_season":Vector4(0,0,0,0.7)}}

static func layers() -> Dictionary:
	return {"trees":true,"grass":true,"birds":true,"fish":true,"arches":1.0,"halls":1.0,"traffic":-1}
