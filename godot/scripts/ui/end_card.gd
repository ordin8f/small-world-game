extends CanvasLayer
## Verbatim-copy end card from index.html's #end-screen (lines 59-93):
## summary + three playtest questions (scale/emotion/continue), notes,
## "Copy playtest notes", "Play again". Shows on Game.episode_complete;
## hides + restarts the episode on "Play again".

@onready var summary_label: Label = $Root/Card/Summary
@onready var notes_edit: TextEdit = $Root/Card/Notes
@onready var copy_button: Button = $Root/Card/Actions/CopyButton
@onready var restart_button: Button = $Root/Card/Actions/RestartButton
@onready var copy_status: Label = $Root/Card/CopyStatus

@onready var scale_yes: CheckBox = $Root/Card/ScaleGroup/Yes
@onready var scale_partly: CheckBox = $Root/Card/ScaleGroup/Partly
@onready var scale_no: CheckBox = $Root/Card/ScaleGroup/No

@onready var emotion_subtle: CheckBox = $Root/Card/EmotionGroup/TooSubtle
@onready var emotion_right: CheckBox = $Root/Card/EmotionGroup/AboutRight
@onready var emotion_strong: CheckBox = $Root/Card/EmotionGroup/TooStrong

@onready var continue_yes: CheckBox = $Root/Card/ContinueGroup/Yes
@onready var continue_maybe: CheckBox = $Root/Card/ContinueGroup/Maybe
@onready var continue_no: CheckBox = $Root/Card/ContinueGroup/No


func _ready() -> void:
	visible = false
	Game.episode_complete.connect(_on_episode_complete)
	copy_button.pressed.connect(_on_copy_pressed)
	restart_button.pressed.connect(_on_restart_pressed)

	_wire_exclusive_group([scale_yes, scale_partly, scale_no])
	_wire_exclusive_group([emotion_subtle, emotion_right, emotion_strong])
	_wire_exclusive_group([continue_yes, continue_maybe, continue_no])


func _on_episode_complete() -> void:
	var seconds := int(round(_elapsed_seconds()))
	var minutes := maxi(1, int(round(seconds / 60.0)))
	summary_label.text = "The children made room for you. You finished this playtest in about %d minute%s. No emotion score was shown; the world changed around the feeling instead." % [minutes, "" if minutes == 1 else "s"]
	copy_status.text = ""
	visible = true


func _on_restart_pressed() -> void:
	visible = false
	Game.start_episode()


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_feedback_text())
	copy_status.text = "Playtest notes copied."


func _elapsed_seconds() -> float:
	return Game.director.elapsed(Time.get_ticks_msec() / 1000.0)


func _feedback_text() -> String:
	var elapsed := int(round(_elapsed_seconds()))
	var notes := notes_edit.text.strip_edges()
	return "\n".join([
		"SMALL WORLD -- THE LOST BALL PLAYTEST",
		"Approx. completion time: %ds" % elapsed,
		"World felt child-sized: %s" % _selected_value([scale_yes, scale_partly, scale_no], ["yes", "partly", "no"]),
		"Emotional shift: %s" % _selected_value([emotion_subtle, emotion_right, emotion_strong], ["too subtle", "about right", "too strong"]),
		"Would play another afternoon: %s" % _selected_value([continue_yes, continue_maybe, continue_no], ["yes", "maybe", "no"]),
		"Notes: %s" % (notes if notes != "" else "none"),
	])


func _selected_value(boxes: Array, values: Array) -> String:
	for i in range(boxes.size()):
		if boxes[i].button_pressed:
			return values[i]
	return "not answered"


func _wire_exclusive_group(boxes: Array) -> void:
	for box in boxes:
		box.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				for other in boxes:
					if other != box:
						other.button_pressed = false
		)
