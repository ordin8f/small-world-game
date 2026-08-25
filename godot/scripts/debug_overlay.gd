extends CanvasLayer
## DebugOverlay — F3-toggled readout of Game.debug_state(), mirroring the
## Three.js prototype's debug HUD (game.mjs:470-481): state, beat index,
## player position, comfort/energy/curiosity, dominant emotion, camera pos.

var _label: Label
var _visible_overlay := false


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.position = Vector2(8, 8)
	add_child(_label)
	visible = _visible_overlay


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_visible_overlay = not _visible_overlay
		visible = _visible_overlay


func _process(_delta: float) -> void:
	if not _visible_overlay:
		return
	var s := Game.debug_state()
	var pos: Dictionary = s.get("player_pos", {})
	var lines := [
		"state: %s" % s.get("state", "?"),
		"beat_index: %s" % s.get("beat_index", "?"),
		"player_pos: (%.2f, %.2f, %.2f)" % [pos.get("x", 0.0), pos.get("y", 0.0), pos.get("z", 0.0)],
		"comfort/energy/curiosity: %s / %s / %s" % [s.get("comfort"), s.get("energy"), s.get("curiosity")],
		"dominant_emotion: %s" % s.get("dominant_emotion", "?"),
		"camera_pos: %s" % s.get("camera_pos"),
	]
	_label.text = "\n".join(lines)
