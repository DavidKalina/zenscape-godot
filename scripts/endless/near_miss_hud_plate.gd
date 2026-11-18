extends "res://scripts/endless/near_miss_hud_handoff.gd"
## The near misses as the flight UI's "plate and trail" draws them
## (docs/design/ui/mock/Chain.dc.html, and Hud.dc.html where that later
## mock-up shows the same tag; spec-flight-ui.md, lane chain). The same calls
## as the ring (near_miss_hud_ring.gd); the handoff HUD's time-hold, keylined
## text and plane-following helpers. Sizes are the mock-up's px in its
## 1280 x 800 frame (M), scaled by the kit's one rule (Kit.scale_of).
## Hung off the plane's upper left, tilted ANGLE_P about the disc's middle;
## nothing shows until a line's first pass.
## - the disc: each pass pops its faceted glyph in (near_glyphs.gd, by id);
##   round it the bank timer (NearMiss `bank_left`), a thick arc on a dark
##   track in the multiplier's heat. Its last SOON s the track gilds, the arc
##   pales and the total warms to gold: about to bank. `fuse` (--chain-timer=
##   fuse) draws the same timer as a line under the total instead.
## - the plate: the gilt total ticking, the multiplier with three segments
##   from x1 to the cap (NearMiss `top`); a step (a switch's, a flourish's)
##   pops out past the plate, flies into the multiplier and the number changes
##   as it lands (STEP_LAND s).
## - the strip under it: just after a pass, that pass: its run's name
##   (LineScore's: TREES ×3, ARCH), how close in its band's colour (near,
##   close, razor), and RAZOR or FLOURISH; in a lull the line so far, a glyph
##   a run with its count, a flourish underlined. A filler moment (a near
##   pull-out) only ticks the total.
## - the bank: the multiplier folds into the total, which counts up to what
##   was banked; `bank` lands in the disc; the cream pennant unrolls under the
##   plate, short of the wing: the line's runs stamped as seals (their glyphs
##   in the ink ground, a flourish's ringed in red), then the money (the
##   `coin` glyph, the money chip's) and the closest pass; the arc runs the
##   pennant's PENNANT s down. "Flight best" on the plate when it beat this
##   flight's best line (`show_best`, --chain-best=0 off). A new pass cuts it
##   short. `banked` fires as the money row shows; `pennant_money_anchor` is
##   where it is.
## - lost (a scrape or crash with a line up): the disc rimmed coral round how
##   it was lost (`crash` or `scrape`, in the loss ground; under today's
##   drawing the cracked glyph of what was hit), LINE LOST and the loss, the
##   trail's glyphs falling away grey, the block sagging.
## - roll ready: `_ready_id`'s mark (`roll`, the corner HUD's roll mark) by the
##   tag for READY_TIME s when the meter fills during a line.
## No meter is drawn here: the charge belongs to the corner HUD.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")

## Emitted once a bank, as the pennant's money row shows (or as the bank is cut
## short before it): the money the book paid and the points banked. The coins
## leave the row COINS_AFTER s later (the mock-up's 1.9 s after the bank).
signal banked(money: int, points: int)

## The block's top left off the plane on screen (M), its tilt and the point it
## turns about (the disc's middle).
const BLOCK_AT := Vector2(-284.0,-106.0)
const ANGLE_P := -0.10472
const PIVOT := Vector2(20.0,15.0)
## A step: how long it shows, when it starts flying and when it lands (s).
const STEP_SHOWS := 0.7
const STEP_FLIES := 0.4
const STEP_LAND := 0.5
## About to bank: the timer's last seconds.
const SOON := 1.2
## The bank: how long the block stays (s), when the money row shows, how long
## after that the coins leave it, when the arc starts running down and for how
## long (the pennant's time).
const BANK_TIME := 3.6
const PAY_AT := 1.15
const COINS_AFTER := 0.75
const PENNANT_FROM := 1.2
const PENNANT := 2.4
const LOSS_TIME_P := 1.4
const READY_TIME := 2.2
## The most runs in the strip's trail and on the pennant.
const BEADS_MOST := 5
## The pennant's marks, M across their 24-unit box, in the mock-up's 18 M
## seal: a run's glyph stamped in ink, and the money's coin.
const SEAL := 17.0
const COIN := 18.0

const CLOSE_C := Color("f7dc8a")
const RAZOR_C := Color("ffb640")
const GLINT := Color("fff3c9")
const DISC := Color("16181d")
const CLOTH := Color("f4eedc")
const INK := Color("1b1d22")
const LAND_INK := Color("3a3a36")
const NAME_INK := Color("8c2a16")
const FLASH := Color("fff8df")
const LOST_NAME := Color("e9e5d8")
const GRAIN := Color("3c280a")

## The bank timer as a line under the total, not the arc.
var fuse := false
## "Flight best" on a bank that beats this flight's best line.
var show_best := true

## The plate's fire on a hot line (`_burn`); `--line-fire=off` leaves it out.
var fire := not ("--line-fire=off" in preload("res://scripts/launch_args.gd").user_args())
## Where it starts (the multiplier's heat, 0 at x1 to 1 at the cap), how tall at
## its most (M over the plate's middle), and how fast it takes and dies (s).
const FIRE_FROM := 0.04
const FIRE_FULL := 0.85
const FIRE_TALL := 62.0
const FIRE_IN := 0.6
const FIRE_OUT := 0.35
var _flame: Node2D
var _fire := 0.0
var _plate_right := 120.0

var _k1 := 1.0
## The newest pass shown {id, name, fl, clear, band, tag, age}; {} with no line.
var _pass := {}
## The line under way: its age (s), each run's glyph by its index, and the
## runs as the trail reads them [{g, n, fl}].
var _line_age := 0.0
var _run_glyph := {}
var _beads: Array = []
## The step in flight {text, big, age, landed}, and the multiplier as shown.
var _step := {}
var _mult_shown := 1.0
var _ready_age := INF
var _flight_best := 0.0
var _pay_local := Vector2.ZERO
var _halo: GradientTexture2D
var _spot: GradientTexture2D

# The frame as drawn (`_compose` sets these, `_draw_block` paints them).
var _v_a := 0.0
var _v_drop := 0.0
var _v_rot := ANGLE_P
var _v_lost := false
var _v_tot := ""
var _v_tot_col := CREAM
var _v_tot_grow := 1.0
var _v_tot_dy := 0.0
var _v_tot_glow := 0.0
var _v_mul := ""
var _v_mul_col := CREAM
var _v_mul_px := 17.0
var _v_mul_grow := 1.0
var _v_mul_glow := 0.0
var _v_mul_a := 1.0
var _v_mul_w := -1.0
var _v_seg := 0.0
var _v_seg_col := CLOSE_C
var _v_best := 0.0
var _v_share := 0.0
var _v_arc := CLOSE_C
var _v_track := Color(CREAM,0.2)
var _v_halo := 0.0
var _v_halo_col := GOLD
var _v_rim := Color(CREAM,0.3)
var _v_glyph := ""
var _v_glyph_variant := "icon"
var _v_glyph_grow := 1.0
var _v_glyph_a := 1.0
var _v_flash := 0.0
var _v_crack := 0.0
var _v_shake := Vector2.ZERO
var _v_strip := 1.0
var _v_rep := 0.0
var _v_trail := 0.0
var _v_name := ""
var _v_name_col := CREAM
var _v_dist := ""
var _v_dist_col := CREAM
var _v_tag := ""
var _v_tag_col := GOLD
var _v_beads: Array = []
var _v_ready := 0.0
var _v_ready_grow := 1.0

func _ready() -> void:
	tag = false
	var args := preload("res://scripts/launch_args.gd").user_args()
	fuse = "--chain-timer=fuse" in args
	show_best = not ("--chain-best=0" in args)
	# The disc's halo (a 12 M blur past a 3 M spread) and the flash's soft spot.
	_halo = _radial([0.0,0.385,0.69,1.0],[1.0,1.0,0.5,0.0])
	_spot = _radial([0.0,1.0],[1.0,0.0])

## Always by the plane: the plate has no top layout.
func set_tag(_on: bool, _keep := true) -> void:
	tag = false

static func _radial(offsets: Array, alphas: Array) -> GradientTexture2D:
	var g := Gradient.new()
	var cols := PackedColorArray()
	for a: float in alphas: cols.append(Color(1,1,1,a))
	g.offsets = PackedFloat32Array(offsets)
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5,0.5)
	t.fill_to = Vector2(1.0,0.5)
	t.width = 96
	t.height = 96
	return t

## The mark of the roll being ready: `roll` once near_glyphs.gd has it, the
## charge's mark until then.
static func _ready_id() -> String:
	return "roll" if not Glyphs.item("roll").is_empty() else "surge"

## Where the coins start: the middle of the pennant's money seal, screen px.
func pennant_money_anchor() -> Vector2:
	return _block.get_global_transform()*_p(_pay_local.x,_pay_local.y)

## Seconds since the bank on show, or -1 with none.
func bank_age() -> float:
	return float(_bank.age) if not _bank.is_empty() else -1.0

## The charge's place on screen (the parry's light flies to it): the corner
## HUD's cells, lower right (Hud.dc.html): where that HUD says they are, by
## the mock-up's number with none up.
func meter_point() -> Vector2:
	var hud: Control = FlightHud.up
	if hud != null and is_instance_valid(hud): return hud.call("cells_point")
	var k := Kit.scale_of(size)
	return global_position+size-Vector2(104.0,38.0)*k

# --- The frame's state -------------------------------------------------------------------

func show_state(delta: float, near: NearMiss, on: bool, events: Dictionary) -> void:
	visible = on
	_near = near
	_release_hold()
	if not on:
		# On the ground: the flight is over, and what was on show with it.
		_prev_chain = near.chain_points
		_prev_mult = near.multiplier()
		_anchored = false
		_flight_best = 0.0
		_pay_out()
		_bank = {}
		_loss = {}
		_end_line()
		return
	_clock += delta
	_k1 = Kit.scale_of(size)
	if events.has("near"): _on_pass(events.near,near)
	if events.has("banked"): _on_bank(events.banked,near)
	if events.has("crash") or events.has("scrape"): _on_loss(events)
	if not _pass.is_empty(): _pass.age = float(_pass.age)+delta
	_line_age += delta
	# The total ticks over 0.35 s, ease-out.
	var target := maxf(near.chain_points,0.0)
	if target <= 0.0:
		_total_from = 0.0
		_total_to = 0.0
		_total_t = 1.0
	elif absf(target-_total_to) > 0.5:
		_total_from = _shown
		_total_to = target
		_total_t = 0.0
	_total_t = minf(_total_t+delta/0.35,1.0)
	_shown = lerpf(_total_from,_total_to,1.0-pow(1.0-_total_t,3.0))
	_jolt += delta
	# The multiplier: a step lands STEP_LAND s after its pass and kicks; with
	# none in flight the number follows the line's.
	var mult := near.multiplier()
	_mult_kick += delta
	if not _step.is_empty():
		_step.age = float(_step.age)+delta
		if not bool(_step.landed) and float(_step.age) >= STEP_LAND: _land_step(mult)
		if float(_step.age) >= STEP_SHOWS: _step = {}
	if _step.is_empty() or bool(_step.landed):
		if mult > _mult_shown+0.01: _mult_kick = 0.0
		_mult_shown = mult
	if near.chain_points <= 0.0 and _bank.is_empty() and _loss.is_empty(): _end_line()
	if not _bank.is_empty():
		_bank.age = float(_bank.age)+delta
		var b := float(_bank.age)
		if b >= PAY_AT: _pay_out()
		if b >= BANK_TIME or (_bank.has("cut") and b >= float(_bank.cut)+0.2):
			_pay_out()
			_bank = {}
			# The line that cut it comes in from nothing.
			_line_age = 0.0
	if not _loss.is_empty():
		_loss.age = float(_loss.age)+delta
		if float(_loss.age) >= LOSS_TIME_P: _loss = {}
	# Roll ready: the meter full and not being spent, since when.
	if near.meter >= 0.999 and near.surge <= 0.0: _ready_age = 0.0 if _ready_age == INF else _ready_age+delta
	else: _ready_age = INF
	_compose(near)
	_place(delta)
	_prev_chain = near.chain_points
	_prev_mult = mult
	_block.modulate.a = _v_a
	_block.queue_redraw()
	_burn(delta,near)

## The plate's fire (shaders/line_flame.gdshader): off the plate's top while a
## line is live and its multiplier is past FIRE_FROM of the way to its cap,
## taller with it; a step of the multiplier leaps it. Out on a bank or a loss.
func _burn(delta: float, near: NearMiss) -> void:
	if not fire: return
	if _flame == null:
		_flame = Node2D.new()
		_flame.show_behind_parent = true
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/line_flame.gdshader")
		# The flames' shape: smooth noise that tiles, so it scrolls with no seam.
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.022
		noise.fractal_octaves = 2
		noise.fractal_gain = 0.4
		var grain := NoiseTexture2D.new()
		grain.width = 256
		grain.height = 256
		grain.seamless = true
		grain.seamless_blend_skirt = 0.3
		grain.noise = noise
		mat.set_shader_parameter(&"grain",grain)
		_flame.material = mat
		_flame.draw.connect(_draw_flame)
		_block.add_child(_flame)
	var live := _bank.is_empty() and _loss.is_empty() and near.chain_points >= 1.0
	var want := smoothstep(FIRE_FROM,FIRE_FULL,_mult_heat(_mult_shown)) if live else 0.0
	_fire = move_toward(_fire,want,delta/(FIRE_IN if want > _fire else FIRE_OUT))
	_flame.visible = _fire > 0.005
	if not _flame.visible: return
	var mat2 := _flame.material as ShaderMaterial
	mat2.set_shader_parameter(&"heat",_fire)
	mat2.set_shader_parameter(&"flare",1.0-smoothstep(0.0,0.5,_mult_kick))
	_flame.queue_redraw()

func _draw_flame() -> void:
	# From the disc's left to the plate's end, the foot behind the plate.
	var x0 := -6.0
	var x1 := maxf(_plate_right+3.0,x0+40.0)
	var top := 14.0-FIRE_TALL
	_flame.draw_colored_polygon(PackedVector2Array([_p(x0,top),_p(x1,top),_p(x1,14.0),_p(x0,14.0)]),Color.WHITE,
		PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]))

func _on_pass(m: Dictionary, near: NearMiss) -> void:
	var band := str(m.band)
	if band == "razor": _hold(0.25,50)
	if not _bank.is_empty() and not _bank.has("cut"): _bank.cut = float(_bank.age)
	if not _loss.is_empty(): _loss.age = maxf(float(_loss.age),LOSS_TIME_P-0.25)
	var filler := bool(m.get("filler",false))
	var first := _pass.is_empty()
	if first: _line_age = 0.0
	# A filler moment takes no pop; the disc needs a glyph only if it's the line's first.
	if filler and not first: return
	var id := Glyphs.for_moment(m)
	var name := str(m.kind).to_upper()
	var runs: Array[Dictionary] = near.score_line.runs
	var run := int(m.get("run",-1))
	if not filler and run >= 0 and run < runs.size():
		name = LineScore.Line.label(runs[run])
		if not _run_glyph.has(run): _run_glyph[run] = id
		_read_runs(runs)
	var fl := bool(m.get("flourish",false))
	_pass = {"id":id,"name":name,"fl":fl,"clear":float(m.get("clear",INF)),"band":band,
		"tag":"FLOURISH" if fl else ("RAZOR" if band == "razor" else ""),"age":0.0}
	if filler: return
	_jolt = 0.0
	var step := float(m.get("line_step",0.0))
	if near.line_new and step > 0.0:
		# One still in flight lands now.
		if not _step.is_empty() and not bool(_step.landed): _land_step(near.multiplier()-step)
		_step = {"text":"+%.1f" % step,"big":fl,"age":0.0,"landed":false}

func _land_step(mult: float) -> void:
	_step.landed = true
	_mult_shown = mult
	_mult_kick = 0.0

## The line's runs as the trail and the pennant read them.
func _read_runs(runs: Array[Dictionary]) -> void:
	_beads = []
	for i in runs.size():
		var run: Dictionary = runs[i]
		var g := str(_run_glyph.get(i,""))
		if g == "": g = Glyphs.for_moment({"kind":str(run.move),"of":str(run.kind),"surface":str(run.surface)})
		_beads.append({"g":g,"n":int(run.n),"fl":bool(run.flourish)})

## A banked line's glyphs (near_miss.gd `_line`) as runs, when the line's own
## weren't seen (a prize).
static func _beads_of(glyphs: Array) -> Array:
	var out: Array = []
	for g: Variant in glyphs:
		if not out.is_empty() and str(out[-1].g) == str(g): out[-1].n = int(out[-1].n)+1
		else: out.append({"g":str(g),"n":1,"fl":false})
	return out

func _on_bank(b: Dictionary, near: NearMiss) -> void:
	_pay_out()
	var pts := float(b.points)
	var line: Dictionary = b.get("line",{})
	var mult := float(line.get("mult",_prev_mult))
	# A prize banks beside a line still under way: that line's runs stay its own.
	var own := near.chain_points < 1.0
	var beads: Array = _beads if own else []
	if beads.is_empty(): beads = _beads_of(line.get("glyphs",[]))
	var named := str(line.get("name","")).to_upper()
	_bank = {"age":0.0,"points":pts,"raw":float(line.get("raw",pts/maxf(mult,1.0))),"mult":mult,
		"dur":0.4 if pts < 2000.0 else (0.8 if pts < 10000.0 else 1.2),"beads":beads.slice(-BEADS_MOST),
		"money":int(line.get("money",0)),"closest":float(line.get("closest",INF)),"name":named,
		"best":show_best and pts > _flight_best,"paid":false}
	_flight_best = maxf(_flight_best,pts)
	_pay_local = Vector2(18.0+14.0+9.0,_pennant_top()+5.0+(20.0 if named != "" else 0.0)+22.0+3.0+10.0)
	if own: _end_line()

## The bank's `banked`, once.
func _pay_out() -> void:
	if _bank.is_empty() or bool(_bank.paid): return
	_bank.paid = true
	banked.emit(int(_bank.money),roundi(float(_bank.points)))

func _on_loss(events: Dictionary) -> void:
	var had := _prev_chain >= 1.0 and not _pass.is_empty()
	if had:
		var crash := events.has("crash")
		var hit: Dictionary = events.get("crash",events.get("scrape",{}))
		var what := str(hit.get("what","land"))
		_pay_out()
		_bank = {}
		_loss = {"age":0.0,"lost":float((events.get("lost",{}) as Dictionary).get("points",0.0)),"crash":crash,"what":what,
			"id":"rock" if what == "stone" else (what if what in ["tree","water"] else "ground"),"beads":_beads.slice(-BEADS_MOST)}
		_hold(0.0,60)
	_end_line()

func _end_line() -> void:
	_pass = {}
	_run_glyph = {}
	_beads = []
	_step = {}

func _pennant_top() -> float:
	return 40.0 if fuse else 38.0

## The pop into the disc: 135% to 94% to 100% over 0.22 s.
static func _pop(age: float) -> float:
	if age < 0.1: return lerpf(1.35,0.94,smoothstep(0.0,0.1,age))
	return lerpf(0.94,1.0,smoothstep(0.1,0.22,age))

## This frame as the mock-up's sequence gives it: the bank, the loss, the line
## under way, or nothing.
func _compose(near: NearMiss) -> void:
	_v_a = 0.0
	_v_drop = 0.0
	_v_rot = ANGLE_P
	_v_lost = false
	_v_tot = ""
	_v_tot_col = CREAM
	_v_tot_grow = 1.0
	_v_tot_dy = 0.0
	_v_tot_glow = 0.0
	_v_mul = ""
	_v_mul_grow = 1.0
	_v_mul_glow = 0.0
	_v_mul_a = 1.0
	_v_mul_w = -1.0
	_v_best = 0.0
	_v_share = 0.0
	_v_track = Color(CREAM,0.2)
	_v_halo = 0.0
	_v_halo_col = GOLD
	_v_rim = Color(CREAM,0.3)
	_v_glyph = ""
	_v_glyph_variant = "icon"
	_v_glyph_grow = 1.0
	_v_glyph_a = 1.0
	_v_flash = 0.0
	_v_crack = 0.0
	_v_shake = Vector2.ZERO
	_v_strip = 1.0
	_v_rep = 0.0
	_v_trail = 0.0
	_v_name = ""
	_v_dist = ""
	_v_tag = ""
	_v_beads = []
	_v_ready = 0.0
	if not _bank.is_empty(): _compose_bank()
	elif not _loss.is_empty(): _compose_loss()
	elif near.chain_points >= 1.0 and not _pass.is_empty(): _compose_live(near)

func _compose_live(near: NearMiss) -> void:
	var age := float(_pass.age)
	_v_a = smoothstep(0.0,0.08,_line_age)
	_v_tot = _grouped(_shown)
	var j := 1.0-smoothstep(0.0,0.14,_jolt)
	_v_tot_dy = -2.0*j
	_v_tot_grow = 1.0+0.06*j
	var heat := _mult_heat(_mult_shown)
	_set_mult(_mult_shown,heat)
	if _mult_kick < 0.05: _v_mul_col = Color.WHITE
	_v_mul_grow = 1.0+0.3*(1.0-smoothstep(0.0,0.2,_mult_kick))
	_v_mul_glow = 0.55*heat if heat > 0.3 else 0.0
	# The timer, and its last SOON s: about to bank.
	var left := near.bank_left
	_v_share = clampf(left/near.bank_after(),0.0,1.0)
	var soon := 1.0-smoothstep(SOON-0.5,SOON,left)
	_v_arc = GLINT if left < SOON else _v_seg_col
	_v_track = Color(GOLD,lerpf(0.2,0.55,soon))
	_v_tot_col = CREAM.lerp(GOLD,soon)
	_v_halo = maxf(0.55*soon,0.35*heat)
	_v_glyph = str(_pass.id)
	_v_glyph_grow = _pop(age)
	_v_glyph_a = smoothstep(0.0,0.04,age)
	_v_flash = 0.5*(1.0-smoothstep(0.0,0.3,age))
	# The strip: the pass just made, then the line so far.
	_v_beads = _beads.slice(-BEADS_MOST)
	_v_rep = smoothstep(0.0,0.06,age)
	if not _v_beads.is_empty():
		_v_rep *= 1.0-smoothstep(1.3,1.6,age)
		_v_trail = smoothstep(1.45,1.75,age)
	var fl := bool(_pass.fl)
	var band := str(_pass.band)
	_v_name = str(_pass.name)
	_v_name_col = GOLD if fl else CREAM
	var clear := float(_pass.clear)
	_v_dist = "%s m" % _metres(clear) if is_finite(clear) else ""
	_v_dist_col = RAZOR_C if band == "razor" else (CLOSE_C if band == "close" else NEAR_C)
	_v_tag = str(_pass.tag)
	_v_tag_col = GOLD if fl else RAZOR_C
	# Roll ready, by the tag.
	if _ready_age < READY_TIME:
		_v_ready = smoothstep(0.0,0.08,_ready_age)*(1.0-smoothstep(1.8,2.2,_ready_age))
		_v_ready_grow = _pop(_ready_age)

## The multiplier's text, size, segments and their colour at `mult`.
func _set_mult(mult: float, heat: float) -> void:
	_v_mul = "×%.1f" % mult
	_v_mul_px = lerpf(17.0,21.0,heat)
	_v_mul_col = _ramp(HEAT,heat)
	_v_seg = heat*3.0
	_v_seg_col = _ramp(HEAT,maxf(heat,0.25))

func _compose_bank() -> void:
	var b := float(_bank.age)
	var dur := float(_bank.dur)
	_v_a = 1.0-smoothstep(BANK_TIME-0.3,BANK_TIME,b)
	if _bank.has("cut"): _v_a *= 1.0-smoothstep(float(_bank.cut),float(_bank.cut)+0.2,b)
	var c := clampf(b/dur,0.0,1.0)
	_v_tot = "+"+_grouped(lerpf(float(_bank.raw),float(_bank.points),1.0-pow(1.0-c,3.0)))
	_v_tot_col = GOLD
	_v_tot_glow = lerpf(0.75,0.3,smoothstep(dur,dur+0.6,b))
	_v_tot_grow = 1.0+0.22*(1.0-smoothstep(0.0,0.12,b))
	# The multiplier folds in.
	_set_mult(float(_bank.mult),_mult_heat(float(_bank.mult)))
	_v_mul_a = 1.0-smoothstep(0.12,0.4,b)
	_v_mul_w = lerpf(46.0,0.0,smoothstep(0.25,0.55,b))
	_v_share = 1.0 if b < PENNANT_FROM else clampf(1.0-(b-PENNANT_FROM)/PENNANT,0.0,1.0)
	_v_arc = GOLD
	_v_halo = 0.8*(1.0-smoothstep(1.0,1.5,b))
	_v_rim = Color(GOLD,0.5)
	_v_glyph = "bank"
	_v_glyph_grow = _pop(b)
	_v_flash = 0.6*(1.0-smoothstep(0.0,0.35,b))
	_v_strip = 1.0-smoothstep(0.0,0.15,b)
	_v_trail = 1.0
	_v_beads = _bank.beads
	if bool(_bank.best): _v_best = smoothstep(dur+0.15,dur+0.4,b)

func _compose_loss() -> void:
	var a := float(_loss.age)
	_v_lost = true
	_v_a = 1.0-smoothstep(1.15,1.4,a)
	_v_drop = 8.0*smoothstep(0.8,1.4,a)
	_v_rot = ANGLE_P*(1.0-0.5*smoothstep(0.5,1.4,a))
	var lost := float(_loss.lost)
	_v_tot = "−"+_grouped(lost) if lost >= 1.0 else ""
	_v_tot_col = LOST
	_v_tot_grow = 1.0+0.15*(1.0-smoothstep(0.0,0.12,a))
	# How it was lost: `crash` or `scrape`, in the loss ground. Today's drawing
	# has no crash: there, what was hit under a crack.
	if Glyphs.mode() != "old":
		_v_glyph = "crash" if bool(_loss.crash) else "scrape"
		_v_glyph_variant = "loss"
		_v_glyph_grow = _pop(a)
	else:
		_v_glyph = str(_loss.id)
		_v_crack = smoothstep(0.0,0.08,a)
	_v_rim = Color(LOST,0.75)
	_v_halo = 0.5*(1.0-smoothstep(0.0,0.5,a))
	_v_halo_col = LOST
	var q := 1.0-smoothstep(0.0,0.22,a)
	_v_shake = Vector2(sin(a*95.0),cos(a*71.0))*2.2*q
	_v_rep = smoothstep(0.05,0.15,a)
	var word := {"stone":"ROCK","tree":"TREE","water":"WATER"}.get(str(_loss.what),"GROUND") as String
	_v_name = ("HIT " if bool(_loss.crash) else "SCRAPED ")+word
	_v_name_col = LOST_NAME

## The block follows the plane, its pivot (the disc's middle) off its upper
## left; it stays on screen and left of the middle of the view.
func _place(delta: float) -> void:
	var k := _k1
	var to := _plane_screen()+(BLOCK_AT+PIVOT)*k
	var right := maxf(size.x*0.5+(BLOCK_AT.x+PIVOT.x)*k,60.0*k)
	to = Vector2(clampf(to.x,minf(60.0*k,right),right),clampf(to.y,40.0*k,maxf(size.y-120.0*k,40.0*k)))
	_anchor = to if not _anchored else _anchor.lerp(to,minf(1.0,delta*FOLLOW))
	_anchored = true
	_block.position = _anchor+Vector2(0.0,_v_drop*k)
	_block.rotation = _v_rot

# --- Drawing ------------------------------------------------------------------------------

## No meter in the corner: the corner HUD draws the charge.
func _draw() -> void:
	pass

func _draw_block() -> void:
	if _near == null or _v_a <= 0.003: return
	_paint_ready()
	if not _bank.is_empty(): _paint_pennant()
	_paint_strip()
	_paint_plate()
	_paint_disc()
	if not _loss.is_empty(): _paint_falls()

## A point of the mock-up's block (M) in the block's own px.
func _p(x: float, y: float) -> Vector2:
	return (Vector2(x,y)-PIVOT)*_k1

## The width of `s` in a face, in M.
func _w(face: int, s: String, px: float, track := 0.0) -> float:
	return Kit.text_w(face,s,px,_k1,track)/_k1

func _text(face: int, s: String, x: float, y: float, px: float, track: float, col: Color, a := 1.0) -> void:
	Kit.text(_block,face,s,_p(x,y),px,_k1,track,col,0.0,a)

## `s` from (x, y) (M; its left edge and middle line), scaled `grow` about
## that point, with a soft glow of `glow` behind it.
func _text_grown(face: int, s: String, x: float, y: float, px: float, col: Color, a: float, grow: float, glow := Color(0,0,0,0)) -> void:
	if s.is_empty() or a <= 0.003: return
	_block.draw_set_transform(_p(x,y),0.0,Vector2.ONE*grow)
	if glow.a > 0.01:
		var ipx := maxi(roundi(px*_k1),4)
		var f := Kit.face(face,ipx)
		var at := Vector2(0.0,roundf((f.get_ascent(ipx)-f.get_descent(ipx))*0.5))
		_block.draw_string_outline(f,at,s,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,roundi(14.0*_k1),Color(glow,glow.a*0.2*a))
		_block.draw_string_outline(f,at,s,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,roundi(7.0*_k1),Color(glow,glow.a*0.32*a))
	Kit.text(_block,face,s,Vector2.ZERO,px,_k1,0.0,col,0.0,a)
	_block.draw_set_transform_matrix(Transform2D.IDENTITY)

## A filled polygon, every edge feathered one px (the block is tilted, so no
## edge is level on screen).
func _fill(pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3 or col.a <= 0.003: return
	if Geometry2D.triangulate_polygon(pts).is_empty(): return
	_block.draw_colored_polygon(pts,col)
	var area := 0.0
	for i in n: area += pts[i].cross(pts[(i+1)%n])
	var out_sign := 1.0 if area > 0.0 else -1.0
	var clear := Color(col,0.0)
	for i in n:
		var a := pts[i]
		var b := pts[(i+1)%n]
		var d := b-a
		if d.length_squared() < 0.01: continue
		var out := Vector2(d.y,-d.x).normalized()*out_sign
		_block.draw_polygon(PackedVector2Array([a,b,b+out,a+out]),PackedColorArray([col,col,clear,clear]))

## The dark plate's shape in the M rect (x, y, w, h): its right edge cut 9 M in
## at the foot.
func _plate(x: float, y: float, w: float, h: float, col: Color) -> void:
	if w <= Kit.PLATE_CUT+1.0: return
	_fill(PackedVector2Array([_p(x,y),_p(x+w,y),_p(x+w-Kit.PLATE_CUT,y+h),_p(x,y+h)]),col)

## A bar leaning 14 degrees in the M rect (x, y, w, h).
func _slant(x: float, y: float, w: float, h: float, col: Color) -> void:
	if w <= 0.05: return
	var dx := Kit.SKEW*h*0.5
	_fill(PackedVector2Array([_p(x+dx,y),_p(x+w+dx,y),_p(x+w-dx,y+h),_p(x-dx,y+h)]),col)

## A faceted glyph `px` M across its 24-unit box, centred `c` (block px, or the
## transform's), scaled `grow`. Rasterised once at its size at rest.
func _glyph(id: String, c: Vector2, px: float, grow := 1.0, mod := Color.WHITE, variant := "icon") -> void:
	if mod.a <= 0.003: return
	var at_px := maxf(roundf(px*_k1),4.0)
	var tex := Glyphs.texture(id,variant,at_px)
	if tex == null: return
	var sz := Vector2(tex.get_size())*grow*(px*_k1/at_px)
	_block.draw_texture_rect(tex,Rect2(c-sz*0.5,sz),false,mod)

func _circle(c: Vector2, r: float, col: Color) -> void:
	if col.a > 0.003 and r > 0.2: _block.draw_circle(c,r,col,true,-1.0,true)

## The plate: LINE LOST, the total, the multiplier over its segments, "flight
## best"; the step flying in; the fuse under it.
func _paint_plate() -> void:
	var k := _k1
	var x := 49.0
	var lost_w := _w(Kit.MED,"LINE LOST",10.5,0.2)+9.0 if _v_lost else 0.0
	var tot_w := _w(Kit.NUM,_v_tot,25.0)
	# The bank's total lands big: the plate gives it room, so it does not lie
	# over the multiplier folding in beside it.
	if not _bank.is_empty(): tot_w *= _v_tot_grow
	var mul_w := 0.0
	var mul_gap := 0.0
	if _v_mul != "":
		mul_w = _w(Kit.NUM,_v_mul,_v_mul_px)
		mul_gap = 9.0
		if _v_mul_w >= 0.0:
			mul_w = minf(mul_w,_v_mul_w)
			mul_gap = lerpf(0.0,9.0,_v_mul_w/46.0)
	var best_w := (10.0+_w(Kit.MED,"FLIGHT BEST",10.0,0.2))*_v_best
	var right := x+lost_w+tot_w+mul_gap+mul_w+best_w+19.0
	_plate_right = right
	_plate(16.0,0.0,right-16.0,30.0,Color(Kit.PLATE,0.86))
	if _v_lost:
		_text(Kit.MED,"LINE LOST",x,15.0,10.5,0.2,LOST)
		x += lost_w
	_text_grown(Kit.NUM,_v_tot,x,15.0+_v_tot_dy,25.0,_v_tot_col,1.0,_v_tot_grow,Color(1.0,0.745,0.275,_v_tot_glow))
	x += tot_w+mul_gap
	if _v_mul != "" and _v_mul_a > 0.01 and mul_w > 1.0:
		_text_grown(Kit.NUM,_v_mul,x,13.75,_v_mul_px,_v_mul_col,_v_mul_a,_v_mul_grow,Color(0.969,0.573,0.18,_v_mul_glow))
		# Three segments, x1 to the cap.
		var sw := (mul_w-4.0-4.0)/3.0
		for i in 3:
			var sx := x+3.0+(sw+2.0)*i
			_slant(sx,24.25,sw,2.5,Color(CREAM,0.24*_v_mul_a))
			_slant(sx,24.25,sw*clampf(_v_seg-i,0.0,1.0),2.5,Color(_v_seg_col,_v_mul_a))
	x += mul_w
	if _v_best > 0.01: _text(Kit.MED,"FLIGHT BEST",x+10.0*_v_best,15.0,10.0,0.2,GLINT,smoothstep(0.5,1.0,_v_best))
	# The step: out past the plate's end, then into the multiplier.
	if not _step.is_empty() and _bank.is_empty() and _loss.is_empty():
		var age := float(_step.age)
		var big := bool(_step.big)
		var fly := smoothstep(STEP_FLIES,STEP_SHOWS,age)
		# Gone as it reaches the multiplier (the mock-up kept it whole until
		# 0.53 s, when it lay over the number it was changing).
		var a := smoothstep(0.0,0.05,age)*(1.0-smoothstep(STEP_FLIES+0.03,STEP_LAND+0.1,age))
		var ipx := maxi(roundi((21.0 if big else 15.0)*k),4)
		var glow := Color(1.0,0.745,0.275,0.7*a) if big else Color(0,0,0,0)
		_txt(_block,Kit.face(Kit.NUM,ipx),str(_step.text),_p(right+lerpf(2.0,-52.0,fly),15.0),ipx,Color(GOLD if big else CLOSE_C,a),2.0*k,
			_pop(age)*lerpf(1.0,0.6,fly),0.0,glow,6.0*k if big else 0.0,0.0)
	# The fuse: the timer as a line under the plate.
	if fuse and not _v_lost:
		var fw := right-15.0-46.0
		_slant(46.0,32.0,fw,3.0,Color(KEY,0.85))
		if _v_arc == GOLD or _v_arc == GLINT: _slant(46.0-1.5,30.5,fw*_v_share+3.0,6.0,Color(GOLD,0.22))
		_slant(46.0,32.0,fw*_v_share,3.0,_v_arc)

## The strip: the pass just made (name, how close, RAZOR or FLOURISH) or the
## line so far (a glyph a run, its count, a flourish underlined).
func _paint_strip() -> void:
	if _v_strip <= 0.01: return
	var top := 37.0 if fuse else 33.0
	var mid := top+10.0
	var name_w := _w(Kit.MED,_v_name,11.5,0.14)
	var dist_w := _w(Kit.NUM,_v_dist,14.0)
	var rep_w := name_w+7.0+dist_w+7.0+_w(Kit.MED,_v_tag,10.0,0.18) if _v_name != "" else 0.0
	var trail_w := 0.0
	for i in _v_beads.size():
		var n := int(_v_beads[i].n)
		trail_w += 18.0+(_w(Kit.NUM,str(n),11.5) if n > 1 else 0.0)+(9.0 if i > 0 else 0.0)
	var inner := maxf(rep_w,trail_w)
	if inner <= 0.5: return
	_plate(34.0,top,inner+28.0,20.0,Color(Kit.PLATE,0.8*_v_strip))
	var x := 45.0
	var ra := _v_rep*_v_strip
	if ra > 0.01 and _v_name != "":
		_text(Kit.MED,_v_name,x,mid,11.5,0.14,_v_name_col,ra)
		_text(Kit.NUM,_v_dist,x+name_w+7.0,mid,14.0,0.0,_v_dist_col,ra)
		_text(Kit.MED,_v_tag,x+name_w+7.0+dist_w+7.0,mid,10.0,0.18,_v_tag_col,ra)
	var ta := _v_trail*_v_strip
	if ta > 0.01:
		for b: Dictionary in _v_beads:
			_glyph(str(b.g),_p(x+8.0,mid),16.0,1.0,Color(1,1,1,ta))
			if bool(b.fl): _slant(x+2.0,top+17.0,12.0,2.0,Color(GOLD,ta))
			x += 18.0
			if int(b.n) > 1:
				var count := str(int(b.n))
				_text(Kit.NUM,count,x,mid,11.5,0.0,CREAM,ta)
				x += _w(Kit.NUM,count,11.5)
			x += 9.0

## The disc: halo, the timer's arc on its track (or a plain rim), the glyph,
## the crack of a lost line, the flash of a pass.
func _paint_disc() -> void:
	var k := _k1
	var c := Vector2.ZERO
	if _v_halo > 0.01:
		var hr := 39.0*k
		_block.draw_texture_rect(_halo,Rect2(c-Vector2.ONE*hr,Vector2.ONE*hr*2.0),false,Color(_v_halo_col,_v_halo))
	_circle(c,24.5*k,KEY)
	var ring := not fuse and not _v_lost
	if ring:
		_block.draw_arc(c,21.5*k,0.0,TAU,72,_v_track,3.0*k,true)
		if _v_share > 0.002:
			var a0 := -PI*0.5
			_block.draw_arc(c,21.5*k,a0,a0+TAU*_v_share,maxi(8,roundi(72*_v_share)),_v_arc,3.0*k,true)
	_circle(c,20.0*k,DISC)
	_block.draw_arc(c,19.25*k,0.0,TAU,64,KEY if ring else _v_rim,1.5*k,true)
	var at := c+_v_shake*k
	if _v_glyph != "": _glyph(_v_glyph,at,28.0,_v_glyph_grow,Color(1,1,1,_v_glyph_a),_v_glyph_variant)
	if _v_crack > 0.01:
		var crack := PackedVector2Array()
		for p: Vector2 in [Vector2(8,5),Vector2(11,11),Vector2(9.5,13),Vector2(13,19)]: crack.append(at+(p-Vector2(12,12))*28.0/24.0*k)
		_block.draw_polyline(crack,Color(KEY,_v_crack),3.0*k,true)
		_block.draw_polyline(crack,Color(LOST,_v_crack),1.5*k,true)
	if _v_flash > 0.01:
		# A soft spot that ends inside the disc's face (its middle 7 M off the disc's).
		var fr := 12.5*k
		_block.draw_texture_rect(_spot,Rect2(c+Vector2(-4.5,-5.5)*k-Vector2.ONE*fr,Vector2.ONE*fr*2.0),false,Color(FLASH,minf(_v_flash*1.25,1.0)))

## The pennant under the plate: cream cloth unrolling to the right, the line's
## runs stamped as seals, then the money and the closest pass.
func _paint_pennant() -> void:
	var k := _k1
	var b := float(_bank.age)
	var beads: Array = _bank.beads
	var ox := 18.0
	var oy := _pennant_top()
	var named := str(_bank.name)
	# The rows measured (M).
	var row1 := 0.0
	var widths := PackedFloat32Array()
	for i in beads.size():
		var bead: Dictionary = beads[i]
		var bw := 18.0+(3.0 if bool(bead.fl) else 0.0)+3.0+(_w(Kit.NUM,str(int(bead.n)),12.0) if int(bead.n) > 1 else 0.0)
		widths.append(bw)
		row1 += bw+(7.0 if i > 0 else 0.0)
	var pay := "+%s" % _grouped(float(_bank.money))
	var pay_w := _w(Kit.NUM,pay,15.0)
	var closest := float(_bank.closest)
	var close_text := "%s m" % _metres(closest) if is_finite(closest) else ""
	var label_w := _w(Kit.MED,"CLOSEST",10.0,0.16)
	var row2 := 18.0+4.0+pay_w
	if close_text != "": row2 += 9.0+1.0+9.0+label_w+5.0+_w(Kit.NUM,close_text,13.0)
	var name_h := 20.0 if named != "" else 0.0
	var w := maxf(maxf(row1,row2),_w(Kit.NUM,named,15.0,0.1))+14.0+28.0
	var h := 5.0+name_h+22.0+3.0+20.0+6.0
	var open := minf(w,smoothstep(0.45,0.75,b)*340.0)
	if open < 6.0: return
	# The cloth as it will lie (its swallowtail's point 11 M in from its end),
	# shown as far as it has unrolled; its hard shadow, grain and ink spine.
	var notch := 11.0
	var tail := (w-open)/notch
	var cloth := PackedVector2Array([_p(ox,oy),_p(ox+open,oy)])
	if tail >= 1.0: cloth.append(_p(ox+open,oy+h))
	else:
		if tail > 0.02: cloth.append(_p(ox+open,oy+tail*h*0.5))
		cloth.append(_p(ox+w-notch,oy+h*0.5))
		if tail > 0.02: cloth.append(_p(ox+open,oy+h-tail*h*0.5))
		cloth.append(_p(ox+open,oy+h))
	cloth.append(_p(ox,oy+h))
	var drop := PackedVector2Array()
	for p: Vector2 in cloth: drop.append(p+Vector2(0.0,3.0*k))
	_fill(drop,Color(KEY,0.4))
	_fill(cloth,CLOTH)
	var gx := 0.0
	var body := minf(open,w-notch)
	while gx < body:
		var g0 := Color(GRAIN,0.0)
		var g1 := Color(GRAIN,0.06)
		var m0 := minf(gx+46.0,body)
		var m1 := minf(gx+92.0,body)
		var c0 := g0.lerp(g1,(m0-gx)/46.0)
		_block.draw_polygon(PackedVector2Array([_p(ox+gx,oy),_p(ox+m0,oy),_p(ox+m0,oy+h),_p(ox+gx,oy+h)]),PackedColorArray([g0,c0,c0,g0]))
		if m1 > m0:
			var c1 := g1.lerp(g0,(m1-m0)/46.0)
			_block.draw_polygon(PackedVector2Array([_p(ox+m0,oy),_p(ox+m1,oy),_p(ox+m1,oy+h),_p(ox+m0,oy+h)]),PackedColorArray([c0,c1,c1,c0]))
		gx += 92.0
	_fill(PackedVector2Array([_p(ox,oy),_p(ox+3.0,oy),_p(ox+3.0,oy+h),_p(ox,oy+h)]),INK)
	var y := oy+5.0
	# The line's name, if it earned one.
	if named != "":
		_text(Kit.NUM,named,ox+14.0,y+10.0,15.0,0.1,NAME_INK,smoothstep(0.9,1.1,b))
		y += name_h
	# The runs, stamped 80 ms apart.
	var x := ox+14.0
	for i in beads.size():
		var bead: Dictionary = beads[i]
		var st := b-0.62-0.08*i
		var bw := widths[i]
		var a := smoothstep(0.0,0.1,st)
		if a > 0.01 and x+bw-ox <= body+2.0:
			var fl := bool(bead.fl)
			_block.draw_set_transform(_p(x+bw*0.5,y+11.0),0.0,Vector2.ONE*(1.0+0.35*(1.0-a)))
			var sc := Vector2((9.0-bw*0.5)*k,0.0)
			if fl:
				_circle(sc,12.0*k,Color(NAME_INK,a))
				_circle(sc,10.5*k,Color(CLOTH,a))
			# Stamped in ink on the cloth; today's drawing keeps its dark seal.
			if Glyphs.mode() != "old": _glyph(str(bead.g),sc,SEAL,1.0,Color(1,1,1,a),"ink")
			else:
				_circle(sc,9.0*k,Color(DISC,a))
				_glyph(str(bead.g),sc,14.0,1.0,Color(1,1,1,a))
			if int(bead.n) > 1: Kit.text(_block,Kit.NUM,str(int(bead.n)),Vector2((18.0+(3.0 if fl else 0.0)+3.0-bw*0.5)*k,0.0),12.0,k,0.0,INK,0.0,a)
			_block.draw_set_transform_matrix(Transform2D.IDENTITY)
		x += bw+7.0
	# The money (dimming as the coins leave it) and the closest pass.
	var ra := smoothstep(PAY_AT,PAY_AT+0.2,b)
	if ra <= 0.01: return
	y += 22.0+3.0+10.0
	x = ox+14.0
	var dim := ra*lerpf(1.0,0.45,smoothstep(PAY_AT+COINS_AFTER,PAY_AT+COINS_AFTER+0.6,b))
	# The money's coin, the chip's own mark (the coins in the air leave from it).
	if Glyphs.mode() != "old":
		_circle(_p(x+9.0,y)+Vector2(0.0,1.0)*k,COIN*0.41*k,Color(INK,0.4*dim))
		_glyph("coin",_p(x+9.0,y),COIN,1.0,Color(1,1,1,dim))
	else:
		_circle(_p(x+9.0,y),9.0*k,Color(DISC,dim))
		_glyph("bank",_p(x+9.0,y),14.0,1.0,Color(1,1,1,dim))
	_text(Kit.NUM,pay,x+22.0,y,15.0,0.0,INK,dim)
	if close_text == "": return
	x += 22.0+pay_w+9.0
	_slant(x,y-5.5,1.0,11.0,Color(INK,0.3*ra))
	x += 1.0+9.0
	_text(Kit.MED,"CLOSEST",x,y,10.0,0.16,LAND_INK,ra)
	_text(Kit.NUM,close_text,x+label_w+5.0,y,13.0,0.0,INK,ra)

## The lost line's trail: its runs' glyphs falling away grey.
func _paint_falls() -> void:
	var a := float(_loss.age)
	var fade := 0.6*(1.0-smoothstep(0.4,1.0,a))
	if fade <= 0.01: return
	var beads: Array = _loss.beads
	var drift := [0.35,-0.6,0.5,-0.3,0.15]
	for i in mini(beads.size(),drift.size()):
		var d := float(drift[i])
		var fy := a*a*150.0+a*18.0*(1.0+d*0.4)
		var fx := 42.0+i*24.0+d*26.0*a
		_block.draw_set_transform(_p(fx+8.0,35.0+fy+8.0),deg_to_rad((1.0 if i%2 == 0 else -1.0)*130.0*a))
		_glyph(str(beads[i].g),Vector2.ZERO,16.0,1.0,Color(0.62,0.62,0.6,fade),"shadow")
		_block.draw_set_transform_matrix(Transform2D.IDENTITY)

## Roll ready: the mark and its word, left of the disc.
func _paint_ready() -> void:
	if _v_ready <= 0.01: return
	var k := _k1
	var id := _ready_id()
	var g := _v_ready_grow
	var c := _p(-23.0,9.0)+Vector2(0.0,-7.0)*k*g
	_glyph(id,c+Vector2(0.0,1.5)*k,24.0,1.08*g,Color(0.055,0.063,0.075,0.7*_v_ready),"shadow")
	_glyph(id,c,24.0,g,Color(1,1,1,_v_ready))
	var ipx := maxi(roundi(9.5*k),4)
	_txt(_block,Kit.face(Kit.MED,ipx,0.2),"ROLL",_p(-23.0,9.0)+Vector2(0.0,12.0)*k*g,ipx,Color(GLINT,_v_ready),2.0*k,g)
