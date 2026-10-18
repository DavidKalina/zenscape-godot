extends RefCounted
## Knobs for the procedural builds (docs/design/world-editor/
## spec-world-handles.md goal 4): a build that places several named pieces
## from a few numbers (the stair to the clouds' slab cut: how many slabs,
## their rise, spacing, how far out and how much they curve) registers its
## knobs here with the callable that places its pieces. The world view
## (scripts/layout_edit.gd) shows the knobs of the selected piece's build
## in a panel; a changed knob rebuilds that build only, on release.
##
## A knob: [key, label, default, min, max, step]. The values off their
## defaults are kept in the layout file's "knobs" block
## ({"stair_clouds/slab_cut": {"count": 6}}, scripts/layout_overrides.gd
## `knobs`). The pieces keep their names across a rebuild, so a moved,
## sized or deleted piece stays so where the build still has it; one the
## build no longer makes is dropped (and its move with it, at the save).

const Layout = preload("res://scripts/layout_overrides.gd")

## build name -> {label, specs, values, make: Callable(values) -> Array of
## the names it placed, members}.
static var builds := {}

## Build `build` (`label` for the panel) registered with its knobs and made
## once at the file's values.
static func register(build: String, label: String, specs: Array, make: Callable) -> void:
	var values := {}
	for s: Array in specs: values[str(s[0])] = s[2]
	var saved: Dictionary = Layout.knobs.get(build,{})
	for k: String in saved:
		if values.has(k): values[k] = _shaped(saved[k],values[k])
	builds[build] = {"label":label,"specs":specs,"values":values,"make":make,"members":[]}
	builds[build].members = make.call(values)

## A value read as its default's type.
static func _shaped(v: Variant, like: Variant) -> Variant:
	if like is int: return int(round(float(v)))
	return float(v)

## The build piece `name` belongs to, "" none.
static func build_of(name: String) -> String:
	for b: String in builds:
		if name in (builds[b].members as Array): return b
	return ""

static func values(build: String) -> Dictionary:
	return (builds[build].values as Dictionary).duplicate()

## Build `build` made again at `vals`: its old pieces taken away (each one
## off its coded pose or size kept so in the file data first, so the new
## piece of that name stands there; `gone`: the names deleted now), its
## new ones placed and tracked. Returns the names it placed.
static func rebuild(build: String, vals: Dictionary, gone: Array) -> Array:
	var b: Dictionary = builds[build]
	var moved: Dictionary = Layout.data.get("moved",{})
	var sizes: Dictionary = Layout.data.get("sizes",{})
	for n: String in b.members:
		if not Layout.entries.has(n): continue
		var e: Dictionary = Layout.entries[n]
		if not is_instance_valid(e.node):
			Layout.entries.erase(n)
			continue
		var t := Layout.current(n)
		if Layout._same(t,e.coded): moved.erase(n)
		else: moved[n] = Layout.to_json(t)
		if e.has("size0"):
			var now: Variant = Layout.size_of(n)
			if Layout._same_size(now,e.size0): sizes.erase(n)
			else: sizes[n] = Layout.size_to_json(now)
		var host: Variant = e.get("host",null)
		if host != null and is_instance_valid(host) and (host as Object).has_method("_drop"): host._drop(e.node)
		else: (e.node as Node).queue_free()
		Layout.entries.erase(n)
	Layout.data["moved"] = moved
	Layout.data["sizes"] = sizes
	Layout.data["deleted"] = gone.duplicate()
	b.values = vals.duplicate()
	_keep(build)
	b.members = b.make.call(b.values)
	return b.members

## The file's knobs block for `build` (only values off their defaults).
static func _keep(build: String) -> void:
	var b: Dictionary = builds[build]
	var off := {}
	for s: Array in b.specs:
		var k := str(s[0])
		if not is_equal_approx(float(b.values[k]),float(s[2])): off[k] = b.values[k]
	if off.is_empty(): Layout.knobs.erase(build)
	else: Layout.knobs[build] = off

## A value as the panel shows it.
static func text_of(spec: Array, v: Variant) -> String:
	if spec[2] is int: return "%d" % int(v)
	return "%.2f" % float(v)
