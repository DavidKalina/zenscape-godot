extends RefCounted
## A world profile: everything that makes one endless world this world and
## not another, over the one shared engine (the plane and flight, on foot,
## streaming, the native kernels, the look's machinery, the dressing
## machinery, the HUD and the harness hooks). The engine asks the profile;
## it never forks (docs/design/endless-flight/world-profiles-handoff.md).
##
## A profile is a script in scripts/endless/world/profiles/<id>.gd that
## extends this one and sets its tables in `_init`. Endless flight plays
## `doors` (wilderness, and amberlands through a door of cloud, PLAYS) unless
## `--world=<id>` names another; `--world=regions` is the patchwork of both,
## `--world=wilderness` is wilderness alone. Every existing flag still
## works and wins over the profile: the profile only sets the defaults the
## flags start from.
##
## The tables (the base class's values are the engine's defaults, which are
## wilderness's):
##   land    the land recipe and its knobs, handed to LandField (and through
##           it to the native field's `configure`): the recipe keys of
##           LandField.recipe_defaults() (continents, hills, ranges, peaks,
##           meadows, valleys, snow) and the flags' knobs (mountains, peaks,
##           valleys, carve, carve_*, rivers, river_*, ponds). Missing keys
##           are LandField's own constants.
##   flora   forest (the woods' share, --forest=), forest_meadows,
##           tree_weights (the spruce family's variant weights, empty for
##           HeroTrees.SPRUCE's own), grass (the tufts' share, --grass=),
##           flowers.
##   paint   mood and hour (the look's opening preset, from EndlessLook.MOODS),
##           ground (endless_ground.gdshader uniforms: the watercolour wc_*,
##           high_paint, carpet tones...), sea (endless_sea uniforms: tint_*;
##           the rivers copy the sea's water), globals (shader globals set after
##           the season reset, e.g. zs_palette_grass).
##   layers  which dressing layers run: trees, grass, birds, fish (bools),
##           arches (density, 0 none), splits (split mountains' density, 0
##           none), split_kinds (their mix of kinds, {slot, winding, gorge,
##           grand: weight}; split_sites.gd TYPES), stacks and hoodoos (each
##           rock shape kind's density, 0 none: scripts/endless/rocks/
##           rock_plan.gd KINDS, one layer a kind), traffic (planes, -1 the
##           engine's count).
##   spawn   at (Vector2 xz), alt (m over the ground), heading (degrees).
##
## Regions: the engine asks `at(x, z)` / `weights_at(x, z)` / `layer_at(...)`
## per unit of work (a tree block, a grass cell), never per height sample.
## A one-profile world is `uniform`: it answers itself everywhere, and the
## engine skips the per-unit asks entirely, so it pays nothing. A world of
## regions would extend this script, set `uniform = false` and answer per
## spot (see the handoff's "Regions").

const LaunchArgs = preload("res://scripts/launch_args.gd")
const PROFILES := "res://scripts/endless/world/profiles/"
## The base tables' world, and the fallback for an unknown id.
const DEFAULT := "wilderness"
## The world endless flight plays with no --world=: the wilderness alone
## (the Steam build, docs/ship/spec-ship.md). --world=doors plays it joined to
## the amberlands by doors (profiles/doors.gd).
const PLAYS := "wilderness"

var id := DEFAULT
var title := "Wilderness"
## A profile that exists only to prove the seam (not a world to play).
var test := false
var land := {}
var flora := {"forest":1.0,"forest_meadows":1.0,"tree_weights":PackedFloat32Array(),"grass":1.0,"flowers":true}
var paint := {"mood":"alpine_morning","hour":8.6,"ground":{},"sea":{},"globals":{}}
var layers := {"trees":true,"grass":true,"birds":true,"fish":true,"arches":1.0,"stacks":0.0,"hoodoos":0.0,"traffic":-1}
var spawn := {"at":Vector2.ZERO,"alt":45.0,"heading":0.0}
## One profile everywhere (the engine skips the per-spot asks).
var uniform := true

# --- Per spot ------------------------------------------------------------------------

## The profile that holds world XZ (x, z): this one, in a uniform world.
func at(_x: float, _z: float) -> RefCounted:
	return self

## The profiles meeting at (x, z) and their weights (summing to 1).
func weights_at(_x: float, _z: float) -> Dictionary:
	return {self:1.0}

## Whether dressing layer `layer` runs at (x, z).
func layer_at(layer: StringName, x: float, z: float) -> bool:
	var v: Variant = at(x,z).layers.get(layer,true)
	return v if v is bool else float(v) > 0.0

# --- Reading the tables --------------------------------------------------------------

func flora_value(key: String, default: Variant) -> Variant:
	return flora.get(key,default)

func layer(key: String, default: Variant) -> Variant:
	return layers.get(key,default)

## The ground shader's uniforms this world paints (before the flags' own).
func apply_ground(material: ShaderMaterial) -> void:
	if material == null: return
	var g: Dictionary = paint.get("ground",{})
	for k: String in g: material.set_shader_parameter(k,g[k])

## The far tuft ring's uniforms this world sets (paint.far: root_colour,
## tip_colour...; before --far-set=). Absent: the engine's own.
func apply_far(material: ShaderMaterial) -> void:
	if material == null: return
	var f: Dictionary = paint.get("far",{})
	for k: String in f: material.set_shader_parameter(k,f[k])

## The sea's uniforms this world tints (before --sea-set=).
func apply_sea(material: ShaderMaterial) -> void:
	if material == null: return
	var s: Dictionary = paint.get("sea",{})
	for k: String in s: material.set_shader_parameter(k,s[k])

## The grass's underside hue (paint.silver_colour) on grass material `m`.
## Absent: the shader's own sage.
func apply_silver(material: ShaderMaterial) -> void:
	if material == null or not paint.has("silver_colour"): return
	material.set_shader_parameter("grass_silver_colour",paint.silver_colour)

## The swells' speed at (x, z) as a share of the air's (paint.sheen_pace; 1
## absent): one clock for the whole land, so it follows the eye's weights.
func sheen_pace_at(x: float, z: float) -> float:
	var pace := 0.0
	var weights := weights_at(x,z)
	for p: RefCounted in weights: pace += float(weights[p])*float(p.paint.get("sheen_pace",1.0))
	return pace

## The shader globals this world sets (after the season reset).
func apply_globals() -> void:
	var g: Dictionary = paint.get("globals",{})
	for k: String in g: RenderingServer.global_shader_parameter_set(k,g[k])

# --- The world in play ---------------------------------------------------------------

static var _current: RefCounted
static var _current_key := ""
static var _lock := Mutex.new()

## The profile `--world=` names (PLAYS by default), made once per name
## and shared (every worker's LandField reads it; it is never written after
## it is made).
static func current() -> RefCounted:
	var want := wanted_id()
	var got: RefCounted = _current
	if got != null and _current_key == want: return got
	_lock.lock()
	if _current == null or _current_key != want:
		_current = make(want)
		_current_key = want
	got = _current
	_lock.unlock()
	return got

## The id `--world=` asks for.
static func wanted_id() -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--world="): return a.get_slice("=",1)
	return PLAYS

## A fresh profile by id (or a res:// path to a profile script, for a
## throwaway one in scratch/); an unknown id warns and plays wilderness.
## Whether this world's regions are whole lands joined by doors, each keeping
## its own edge (a regions patchwork has none).
func is_doors() -> bool:
	return id == PLAYS

static func make(profile_id: String) -> RefCounted:
	var path := profile_id if profile_id.begins_with("res://") else PROFILES+profile_id+".gd"
	if not ResourceLoader.exists(path):
		push_error("no world profile '%s' (%s); the worlds: %s. Playing %s." % [profile_id,path,", ".join(ids()),DEFAULT])
		path = PROFILES+DEFAULT+".gd"
	var p: RefCounted = (load(path) as GDScript).new()
	return p

## The profiles' ids.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in ResourceLoader.list_directory(PROFILES):
		if f.ends_with(".gd"): out.append(f.get_basename())
	return out
