extends RefCounted
## A material's on/off switches folded into its shader.
## shaders/reference_surface.gdshader is one shader
## for the grass, the flowers, ferns, mushrooms, the ground and the rock, each
## picking its paths with `uniform bool`s (grass_blades, flower_heads,
## terrain_growth, ...). Left as uniforms, the GPU carries every path's
## registers and branches for every pixel of every tuft; that made the city's
## grass cost 30-45 ms a frame at 720 lines on an M5 Pro. Folded, the same
## switches are `const bool`s with the material's own values, the compiler
## drops the paths not taken, and the picture is the same: every float, colour
## and texture stays a live uniform.
##
## The discards go too where the material can never take them (Apple's GPUs
## lose their hidden-surface removal on a shader that may discard, and grass
## overdraws a lot): the sea cut when `sea_cut` is unset, the tree tread when
## it is off, the char when fire is off and `object_fire` unset (FireMaterial
## leaves folded materials alone: it takes only the plain shader), and the
## leaf fall when the caller names `leaf_season.y` steady and it is 0.
##
## Only for materials whose switches are set once, when made (the sky's and
## the kit's plant materials, KitLook's ground and rock): a switch flipped later
## on a folded material does nothing. Name such a switch in `live` to keep it a
## uniform. Materials with the same switches share one folded shader.
## `--shader-fold=0` leaves every material on the plain shader (A/B checks).

const FLAG := "--shader-fold="
## Dead code a material can't reach: [what makes it dead, the text, its stand-in].
const DEAD := [
	["sea_cut","} else if (sea_cut > -1.0e8) {","} else if (false) {"],
	["sea_cut","if (above < 0.0) discard;",""],
	["tree_tread","if (tree_tread && zs_revealed(leaf_local, plant_root, tree_tread_height, FRAGCOORD.xy)) discard;",""],
	["leaf_fall","if (leaf_season.y > 0.0 && zs_leaf_fallen(leaf_local, plant_root, leaf_season.y)) discard;",""],
	["char","if (zs_char_gone(char_state.x, char_clump, char_foliage)) discard;",""],
]
const BOOLS := "(?m)^uniform bool (\\w+)\\s*(?:=\\s*(\\w+))?\\s*;"
static var _cache := {}
static var _on := -1
static var _re: RegEx = null
static var _lock := Mutex.new()

static func enabled() -> bool:
	if _on < 0:
		_on = 1
		for a: String in preload("res://scripts/launch_args.gd").user_args():
			if a.begins_with(FLAG): _on = 0 if a.trim_prefix(FLAG) in ["0","off","false"] else 1
	return _on == 1

## Folds `material`'s bool uniforms (all but `live`) into its shader, at their
## values now. `steady`: other values the caller promises never change on it
## ("leaf_season.y"). Nothing for a material without a shader or without
## bools, or when already folded.
static func fold(material: Material, live: Array = [], steady: Array = []) -> void:
	if not enabled() or not material is ShaderMaterial: return
	var m := material as ShaderMaterial
	if m.shader == null or m.has_meta("folded_from"): return
	_lock.lock()
	_fold(m,live,steady)
	_lock.unlock()

static func _param(m: ShaderMaterial, name: String, otherwise: Variant) -> Variant:
	var v: Variant = m.get_shader_parameter(name)
	return otherwise if v == null else v

static func _fold(m: ShaderMaterial, live: Array, steady: Array) -> void:
	var source: Shader = m.shader
	if _re == null: _re = RegEx.create_from_string(BOOLS)
	var code := source.code
	var found := _re.search_all(code)
	if found.is_empty(): return
	var sig := PackedStringArray([source.resource_path if source.resource_path != "" else str(source.get_instance_id())])
	var values := []
	var bools := {}
	for r: RegExMatch in found:
		var name := r.get_string(1)
		if name in live:
			values.append(null)
			sig.append("~")
			continue
		var v: Variant = m.get_shader_parameter(name)
		var on: bool = bool(v) if v != null else r.get_string(2) == "true"
		values.append(on)
		bools[name] = on
		sig.append("1" if on else "0")
	# What can't happen on this material.
	var season: Variant = _param(m,"leaf_season",Vector4(1.0,0.0,0.0,0.0))
	var fire: Variant = _param(m,"object_fire",Vector2.ZERO)
	var dead := {
		"sea_cut":float(_param(m,"sea_cut",-1.0e9)) <= -1.0e8 and not "sea_cut" in live,
		"tree_tread":bools.get("tree_tread",true) == false,
		"leaf_fall":"leaf_season.y" in steady and season is Vector4 and is_zero_approx((season as Vector4).y),
		"char":bools.get("instance_fire_enabled",true) == false and fire is Vector2 and (fire as Vector2) == Vector2.ZERO,
	}
	for k: String in dead: sig.append(k if dead[k] else "-")
	var key := ",".join(sig)
	if not _cache.has(key):
		var parts := PackedStringArray()
		var at := 0
		for i in found.size():
			var r: RegExMatch = found[i]
			parts.append(code.substr(at,r.get_start()-at))
			if values[i] == null: parts.append(r.get_string(0))
			else: parts.append("const bool %s = %s;" % [r.get_string(1),"true" if values[i] else "false"])
			at = r.get_end()
		parts.append(code.substr(at))
		var out := "".join(parts)
		for rule: Array in DEAD:
			if dead[rule[0]]: out = out.replace(rule[1],rule[2])
		var folded := Shader.new()
		folded.code = out
		_cache[key] = folded
	m.set_meta("folded_from",source)
	m.shader = _cache[key]
