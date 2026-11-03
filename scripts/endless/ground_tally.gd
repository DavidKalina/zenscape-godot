class_name GroundTally
extends RefCounted
## How often the flight asks for the ground, per part of the study's tick
## (the FrameLog parts): each ground query counts itself here, and FrameLog
## `mark` files the counts since the last mark under the part just done. On
## only when a driver turns it on (`start`, with a --frame-log); off, a query pays one
## static read. Main-thread calls only: the land's workers ask too, and they
## are not the frame's cost. Spec: docs/design/endless-flight/spec-ground-native.md.

static var on := false
static var _main := -1
## Counts since the last mark: query name -> calls.
static var _open := {}
## Filed counts: part -> {query name -> calls}.
static var parts := {}

## Turns the tally on (or off), from nothing.
static func start(yes := true) -> void:
	on = yes
	_main = OS.get_main_thread_id()
	_open.clear()
	parts.clear()

## One call of the query `what`.
static func tick(what: StringName) -> void:
	if not on or OS.get_thread_caller_id() != _main: return
	_open[what] = int(_open.get(what,0))+1

## The counts since the last mark, filed under `part` (FrameLog `mark`).
static func file(part: StringName) -> void:
	if _open.is_empty(): return
	var into: Dictionary = parts.get(part,{})
	for k: StringName in _open: into[k] = int(into.get(k,0))+int(_open[k])
	parts[part] = into
	_open.clear()
