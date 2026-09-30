extends Node
## Winter reaches the water (docs/scenic/life.md, "Winter on the water").
## LandLife reads the world's ice (SurfaceWeather.ice, which also draws the ice
## and slows the water's visible flow, falls and rills too). Under ice the fish
## drift slow, deep and dark and stop rising, the frogs back into their banks
## and bury themselves, no frogspawn comes, and the heron and snake stay away.
## A thaw after a held freeze brings a burst of frogspawn, frogs crawling back
## out of the banks, and lively fish. Cold clear dawns lift a low mist off the
## ponds (studies/fall_mist.gd, composited after the display fog, so the
## balanced preset's fog cannot paint over it).

const Survey = preload("res://scripts/life_survey.gd")
const Models = preload("res://scripts/life_models.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const Mist = preload("res://studies/fall_mist.gd")

## Ice at or above FROZEN freezes the ponds for life; at or below THAW they open.
const FROZEN := 0.5
const THAW := 0.25
## Ice over which the fish feel it, from none to all.
const UNDER_ICE := Vector2(0.3,0.8)
## Life-clock seconds the ponds must stay frozen for their thaw to count.
const FREEZE_HELD := 20.0
## Life-clock seconds a thaw's liveliness lasts, easing out.
const THAW_SECONDS := 240.0
## Fish under full ice: share of their swim pace, metres deeper (keeping
## FISH_FLOOR off the bed), shade and tail beat.
const ICE_PACE := 0.1
const ICE_SINK := 0.28
const FISH_FLOOR := 0.08
const ICE_SHADE := 0.4
const ICE_BEAT := 0.15
## Fish at a thaw's start: swim pace, and the share of their usual wait
## between rises.
const THAW_PACE := 1.6
const THAW_RISE := 0.3
## A thaw's frogspawn: extra clumps a pond and in all, and the share of their
## (and their frogs') usual delay.
const THAW_SPAWN_BODY := 3
const THAW_SPAWN_MAX := 6
const THAW_HASTE := 0.3
## A frog going into its bank: seconds, metres back up the bank, depth by its
## size, and shoves. Coming out takes EMERGE_SECONDS.
const BURROW_SECONDS := 7.0
const BURROW_REACH := 0.3
const BURROW_DEPTH := 0.16
const BURROW_SHOVES := 5
const EMERGE_SECONDS := 5.0
## Pond mist: the celestial phase window and its soft edges, the cloud that
## clears it, rain that stops it, and how much each season brings, at each
## season's opening [spring, summer, autumn, winter] (WorldClock.season_factor).
const MIST_DAWN := Vector2(0.17,0.38)
const MIST_EDGE := 0.05
const MIST_CLOUD := 0.6
const MIST_RAIN := 0.05
const MIST_SEASON := [0.8, 0.0, 0.6, 1.0]
## Ponds at least MIST_AREA m² steam, MIST_DENSITY sprites a m², at most the
## mist shader's 64, MIST_LIFT m over the water, rising MIST_RISE m through a
## cycle of 1/MIST_CYCLE s.
const MIST_AREA := 2.0
const MIST_DENSITY := 2.5
const MIST_SPRITES := 64
const MIST_LIFT := 0.05
const MIST_RISE := 0.3
const MIST_CYCLE := 0.05
const MIST_STRENGTH := 0.85
const MIST_SCALE := 1.5
## Per real second, how fast the mist comes and goes.
const MIST_EASE := 0.05

var life: Node3D
## 0..1, how far under ice the fish are.
var under := 0.0
## Life clock when the last counted thaw began, and thaws so far, for probes.
var thaw_began := -INF
var thaws := 0
## 0..1, the pond mist now.
var mist := 0.0
var _frozen := false
var _frozen_since := -INF
var _mist_layer: CanvasLayer
var _mist_survey := -1
## Fish look -> tail beat share its material shows.
var _beat := {}

func setup(owner: Node3D) -> void:
	life = owner
	name = "LifeWinter"

## The ponds are frozen for life: no frogs or frogspawn, no heron or snake.
func frozen() -> bool:
	return _frozen

## 0..1, how much of a thaw's liveliness is left.
func lively() -> float:
	return 1.0-clampf((float(life.clock)-thaw_began)/THAW_SECONDS,0.0,1.0)

func thawing() -> bool:
	return lively() > 0.0

func clear() -> void:
	thaw_began = -INF
	_frozen = false
	_frozen_since = -INF
	mist = 0.0
	_mist_survey = -1
	if _mist_layer != null: _mist_layer.visible = false

func advance(real_step: float) -> void:
	var ice := _ice()
	under = smoothstep(UNDER_ICE.x,UNDER_ICE.y,ice)
	if not _frozen and ice >= FROZEN:
		_frozen = true
		_frozen_since = float(life.clock)
		thaw_began = -INF
		life._changed(true)
	elif _frozen and ice <= THAW:
		_frozen = false
		if float(life.clock)-_frozen_since >= FREEZE_HELD:
			thaw_began = float(life.clock)
			thaws += 1
		life._changed(true)
	_hush_tails()
	_advance_mist(real_step)

func _ice() -> float:
	var precipitation: Variant = life.scene.get("_precipitation")
	var weather: Variant = precipitation.get("surface_weather") if precipitation != null else null
	var value: Variant = weather.get("ice") if weather != null else null
	return clampf(float(value),0.0,1.0) if (value is float or value is int) and is_finite(float(value)) else 0.0

# --- Fish ---------------------------------------------------------------------

## A fish's swim pace now: near still under ice, quick for a while after a thaw.
func fish_pace() -> float:
	return lerpf(1.0,ICE_PACE,under)*lerpf(1.0,THAW_PACE,lively())

## Metres below its usual depth a fish keeps, off its pond's bed.
func fish_sink(site: Dictionary) -> float:
	if under <= 0.0 or life.survey == null: return 0.0
	var room: float = life.survey.depth(int(site.cell))-float(site.sink)-FISH_FLOOR
	return clampf(room,0.0,ICE_SINK)*under

## No rings through ice.
func rises() -> bool:
	return under < 0.05

## The share of a fish's usual wait before it rises again.
func rise_wait() -> float:
	return lerpf(1.0,THAW_RISE,lively())

## Dim a fish under ice, seen through it; nothing while its shade holds.
func shade_fish(site: Dictionary, batch: MultiMesh) -> void:
	var shade := float(site.get("shade",1.0))*lerpf(1.0,ICE_SHADE,under)
	if absf(shade-float(site.get("shown_shade",-1.0))) < 0.01: return
	site.shown_shade = shade
	batch.set_instance_color(site.slot,Color(shade,shade,shade))

## Under ice the tails barely beat. Each look's own material, so only its
## `fish_wave` amplitude moves.
func _hush_tails() -> void:
	var beat := snappedf(lerpf(1.0,ICE_BEAT,under),0.05)
	for look: String in life._fish_looks:
		if is_equal_approx(float(_beat.get(look,1.0)),beat): continue
		var swim := (life._fish_looks[look] as MultiMeshInstance3D).material_override as ShaderMaterial
		if swim == null: continue
		_beat[look] = beat
		var wave: Vector4 = Models.fish_wave(look.get_slice(" ",0))
		wave.z *= beat
		swim.set_shader_parameter("fish_wave",wave)

# --- Frogspawn and frogs -------------------------------------------------------

## Extra frogspawn a pond takes in a thaw, and in all.
func extra_spawn() -> int:
	return THAW_SPAWN_BODY if thawing() else 0

func extra_spawn_total() -> int:
	return THAW_SPAWN_MAX if thawing() else 0

## The share of a new site's delay: frogspawn and frogs hurry in a thaw.
func haste(kind: String) -> float:
	return THAW_HASTE if thawing() and (kind == "spawn" or kind == "frog") else 1.0

## A frog leaving as the ponds freeze backs into its bank instead of hopping
## off; false when it leaves as usual. One in the water swims back to its
## bank first, and LandLife burrows it when it lands (`begin_burrow`).
func burrow_on_leave(site: Dictionary) -> bool:
	if not _frozen: return false
	site.burrow = true
	# The leave's fade waits until the frog is under.
	site.left = float(life.clock)+1.0e6
	if site.mode == "sit" or site.mode == "turn": begin_burrow(site)
	return true

func begin_burrow(site: Dictionary) -> void:
	site.crawl_from = site.p
	site.crawl_to = _up_bank(site)
	site.mode = "burrow"
	site.age = 0.0
	site.yaw = life._facing_water(site)

## A frog arriving in a thaw crawls out of the bank just above its place,
## instead of hopping in. Nothing outside a thaw.
func emerge_on_arrival(site: Dictionary) -> void:
	if not thawing(): return
	site.crawl_from = _up_bank(site)
	site.crawl_to = site.home
	site.p = site.crawl_from
	site.mode = "emerge"
	site.age = 0.0
	site.yaw = life._facing_water(site)

## On the ground BURROW_REACH m up the bank from a frog's place.
func _up_bank(site: Dictionary) -> Vector3:
	var home: Vector3 = site.home
	var back: Vector3 = home-(site.landing as Vector3)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.001 else Vector3.BACK
	var spot := home+back*BURROW_REACH
	var ground: Variant = life.data.ground_height(Vector2(spot.x,spot.z))
	spot.y = (float(ground) if ground != null else home.y-0.02)+0.02
	return spot

## Burrowing and emerging frogs, in shoves with a still beat between: rear
## first and nose up into the bank, head first out of it. Returns the pitch
## and the crouch for LandLife `_move_frog`.
func crawl(site: Dictionary) -> Vector2:
	var burrowing: bool = site.mode == "burrow"
	var u := minf(1.0,float(site.age)/(BURROW_SECONDS if burrowing else EMERGE_SECONDS))
	var beat := u*float(BURROW_SHOVES)
	var within := fposmod(beat,1.0) if u < 1.0 else 1.0
	var progress := minf(1.0,(floorf(beat)+smoothstep(0.0,0.7,within))/float(BURROW_SHOVES)) if u < 1.0 else 1.0
	var from: Vector3 = site.crawl_from
	site.p = from.lerp(site.crawl_to,progress)
	var depth := BURROW_DEPTH*float(site.size)
	var sunk := smoothstep(0.25,1.0,progress) if burrowing else 1.0-smoothstep(0.0,0.65,progress)
	site.p.y -= depth*sunk
	# Digging works the frog from side to side; each shove starts from a crouch.
	var facing: float = life._facing_water(site)
	site.yaw = facing+0.14*sin(beat*TAU)*(1.0-sunk*0.5)
	var crouch := 1.0-0.1*(1.0-smoothstep(0.0,0.35,within))*(1.0-smoothstep(0.7,1.0,within))
	var pitch := -0.35*smoothstep(0.1,0.6,progress) if burrowing else -0.4*(1.0-smoothstep(0.3,1.0,progress))
	if u >= 1.0:
		if burrowing:
			# Under: the leave's fade ends now and LandLife lets it go.
			site.mode = "sit"
			site.left = -1.0e6
		else:
			site.mode = "turn"
			site.age = 0.0
			site.turn_from = float(site.yaw)
	return Vector2(pitch,crouch)

# --- Pond mist ------------------------------------------------------------------

func _advance_mist(real_step: float) -> void:
	mist = move_toward(mist,_mist_wanted(),maxf(real_step,0.0)*MIST_EASE)
	var depth: Variant = life.scene._display_fog.depth if life.scene.get("_display_fog") != null else null
	var shown: bool = mist > 0.001 and life.visible and life.survey != null and depth != null and life.scene.get("camera") != null
	if not shown:
		if _mist_layer != null: _mist_layer.visible = false
		return
	if _mist_layer == null:
		_mist_layer = Mist.new()
		_mist_layer.name = "PondMist"
		add_child(_mist_layer)
		_mist_layer.setup({"phase":PackedFloat32Array(),"positions":PackedFloat32Array(),"velocity":PackedFloat32Array(),"size":PackedFloat32Array(),"rise":MIST_RISE})
		_mist_layer.material.set_shader_parameter("cycle_rate",MIST_CYCLE)
		_mist_layer.material.set_shader_parameter("mist_scale",MIST_SCALE)
	if _mist_survey != int(life.surveys): _place_mist()
	_mist_layer.visible = true
	_mist_layer.material.set_shader_parameter("mist_strength",mist*MIST_STRENGTH)
	_mist_layer.update_view(life.scene.camera,depth)

## Cold, clear dawns in the cold half of the year, over open water.
func _mist_wanted() -> float:
	if _frozen or life.survey == null: return 0.0
	var phase := float(life.scene._celestial.phase)
	var dawn := smoothstep(MIST_DAWN.x,MIST_DAWN.x+MIST_EDGE,phase)*(1.0-smoothstep(MIST_DAWN.y-MIST_EDGE,MIST_DAWN.y,phase))
	var state: Vector4 = life.scene._precipitation.state
	if dawn <= 0.0 or state.x > MIST_RAIN: return 0.0
	return dawn*(1.0-smoothstep(MIST_CLOUD*0.6,MIST_CLOUD,state.z))*WorldClock.season_factor(life._season(),MIST_SEASON)

## Sprites over each pond's water by its share of the area, a slow drift each.
func _place_mist() -> void:
	_mist_survey = int(life.surveys)
	var ponds: Array = life.survey.bodies.filter(func(record: Dictionary) -> bool: return float(record.area) >= MIST_AREA)
	var total := 0.0
	for record: Dictionary in ponds: total += float(record.area)
	var count := mini(MIST_SPRITES,int(total*MIST_DENSITY))
	var origins := PackedVector3Array()
	var motion := PackedVector4Array()
	origins.resize(MIST_SPRITES)
	motion.resize(MIST_SPRITES)
	var placed := 0
	for record: Dictionary in ponds:
		var cells: PackedInt32Array = record.cells
		var share := mini(count-placed,ceili(float(count)*float(record.area)/total))
		for k in range(share):
			var tag := [life.salt,int(record.cells[0]),k]
			var cell := cells[int(Variety.unit(tag+[1])*float(cells.size()))%cells.size()]
			var c := Survey.center(cell)+Vector2(Variety.unit(tag+[2])-0.5,Variety.unit(tag+[3])-0.5)*Survey.STEP
			origins[placed] = life.to_global(Vector3(c.x,float(record.level)+MIST_LIFT,c.y))
			var drift := Vector2.from_angle(Variety.unit(tag+[4])*TAU)*(0.15+0.25*Variety.unit(tag+[5]))
			motion[placed] = Vector4(drift.x,drift.y,Variety.unit(tag+[6]),0.8+0.6*Variety.unit(tag+[7]))
			placed += 1
	_mist_layer.material.set_shader_parameter("origins",origins)
	_mist_layer.material.set_shader_parameter("motion",motion)
	_mist_layer.material.set_shader_parameter("particle_count",placed)
