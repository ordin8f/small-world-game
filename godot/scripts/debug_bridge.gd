extends Node
## DebugBridge — publishes Game.debug_state() to window.__SMALL_WORLD__ on
## web builds every frame, and (only when the page URL has ?debug=1) polls
## window.__SW_QUEUE__ for test commands and executes them.
##
## Command shapes (JS pushes objects onto window.__SW_QUEUE__, an array):
##   {cmd:"press", action:"move_forward", frames:60}  -- hold an input action
##   {cmd:"teleport", x:4.2, z:-3.0}                   -- snap Game.player
##   {cmd:"dispatch", event:"observe"}                 -- Game.dispatch(event)
##
## All bridge traffic is JSON strings in both directions (not relying on
## JavaScriptBridge.eval's variable Variant-conversion behavior for JS
## arrays/objects) -- see GODOT_REBUILD_PLAN.md's [VERIFY eval return type]
## note; this sidesteps that ambiguity entirely.

var _is_web := false
var _debug_enabled := false
var _pending_releases: Array = []  # [{action: String, frames_left: int}]


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return
	var raw: Variant = JavaScriptBridge.eval(
		"(window.location.search.indexOf('debug=1') !== -1) ? 'yes' : 'no'", true
	)
	_debug_enabled = (raw == "yes")


func _process(_delta: float) -> void:
	if not _is_web:
		return
	_publish_state()
	if _debug_enabled:
		_poll_queue()


func _physics_process(_delta: float) -> void:
	if _pending_releases.is_empty():
		return
	var still_pending: Array = []
	for entry in _pending_releases:
		entry["frames_left"] -= 1
		if entry["frames_left"] <= 0:
			Input.action_release(entry["action"])
		else:
			still_pending.append(entry)
	_pending_releases = still_pending


func _publish_state() -> void:
	var json := JSON.stringify(Game.debug_state())
	# Assign rather than merge so a stale page reload always sees fresh data.
	JavaScriptBridge.eval("window.__SMALL_WORLD__ = %s;" % json, true)


func _poll_queue() -> void:
	var raw: Variant = JavaScriptBridge.eval(
		"(function(){ var q = window.__SW_QUEUE__ || []; window.__SW_QUEUE__ = []; return JSON.stringify(q); })()",
		true
	)
	if typeof(raw) != TYPE_STRING or raw == "":
		return
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		return
	for command in parsed:
		_execute(command)


func _execute(command: Variant) -> void:
	if typeof(command) != TYPE_DICTIONARY or not command.has("cmd"):
		return
	match command["cmd"]:
		"press":
			var action: String = command.get("action", "")
			var frames: int = int(command.get("frames", 1))
			if action == "" or frames <= 0:
				return
			Input.action_press(action)
			_pending_releases.append({"action": action, "frames_left": frames})
		"teleport":
			if is_instance_valid(Game.player):
				var pos := Game.player.global_position
				pos.x = float(command.get("x", pos.x))
				pos.z = float(command.get("z", pos.z))
				Game.player.global_position = pos
		"dispatch":
			var event: String = command.get("event", "")
			if event != "" and Game.has_method("dispatch"):
				Game.dispatch(event)
