extends SceneTree
## One-shot maintenance script: (re)writes the project's InputMap actions into
## project.godot via ProjectSettings, so the resource syntax is always
## Godot's own serialization rather than hand-authored text.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_input.gd
## Re-run any time the action list below changes, then re-run --import.

func _init() -> void:
	_set_action("move_forward", [KEY_W, KEY_UP])
	_set_action("move_back", [KEY_S, KEY_DOWN])
	_set_action("move_left", [KEY_A, KEY_LEFT])
	_set_action("move_right", [KEY_D, KEY_RIGHT])
	_set_action("run", [KEY_SHIFT])
	_set_action("interact", [KEY_E, KEY_SPACE])
	_set_action("restart", [KEY_R])
	_set_action("debug_toggle", [KEY_F3])

	ProjectSettings.save()
	print("Input map written to project.godot")
	quit()


func _set_action(action_name: String, keycodes: Array) -> void:
	var setting_path := "input/%s" % action_name
	var events: Array = []
	for kc in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = kc
		events.append(ev)
	ProjectSettings.set_setting(setting_path, {
		"deadzone": 0.5,
		"events": events,
	})
	ProjectSettings.set_initial_value(setting_path, {
		"deadzone": 0.5,
		"events": [],
	})
	ProjectSettings.add_property_info({
		"name": setting_path,
		"type": TYPE_DICTIONARY,
	})
