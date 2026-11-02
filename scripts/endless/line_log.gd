class_name LineLog
extends RefCounted
## One row per near-miss moment of a real flight, for tuning the line's score:
## `--line-log=FILE` on the game's command line (a hand flight or a driven one),
## and a row when a line ends. Read and re-scored by tools/line_report.py (the
## same steps as scripts/endless/line_score.gd, from the raw columns). Off, a
## row costs one static read.
##
## A moment's row (row = moment): its time, the line it is in, its kind (the
## score's: graze, thread, pull-out, a held move), the move it was named
## (knife edge, late pull...), surface, band, k, clearance (m), speed, the
## plane's cruise and top (m/s), closing (m/s), roll (deg), height over the land
## (m), under, width (m, a gap's), hold (a held move's time over its least,
## capped), farm (the same-spot cut), the factors and their product, its points
## (units), its run (index in the line) and length so far, flourish, the line's
## multiplier and running total (units) after it, and the old formula's points.
## A line's end (row = end): the line, its multiplier and total, and why
## (banked or lost).

const COLUMNS := ["row","t","line","kind","move","surface","band","k","clear","speed","cruise","top","closing",
	"roll_deg","height","under","width","hold","farm","f_close","f_fast","f_knife","f_low","f_under","product",
	"points","run","run_n","flourish","mult","line_total","old_points","reason"]

static var on := false
static var _file: FileAccess

## Starts the log when the launch flags ask for it.
static func begin(args: PackedStringArray) -> void:
	if on: return
	for a in args:
		if a.begins_with("--line-log="): _open(a.get_slice("=",1))

static func _open(path: String) -> void:
	_file = FileAccess.open(path,FileAccess.WRITE)
	if _file == null:
		push_warning("--line-log: can't write %s" % path)
		return
	on = true
	_file.store_line(",".join(COLUMNS))
	_file.flush()

## A row of `values` (keyed by COLUMNS; missing ones blank).
static func write(values: Dictionary) -> void:
	if not on: return
	var row := PackedStringArray()
	for c: String in COLUMNS:
		var v: Variant = values.get(c,"")
		if v is float: row.append("%.6f" % v if is_finite(v) else "")
		elif v is bool: row.append("1" if v else "0")
		else: row.append(str(v).replace(","," "))
	_file.store_line(",".join(row))
	_file.flush()

static func stop() -> void:
	if not on: return
	on = false
	_file.close()
	_file = null
