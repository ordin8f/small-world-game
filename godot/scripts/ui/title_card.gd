extends CanvasLayer
## Gate 0 frame: S0 (boot) + S1 (title over the live world) + the relocated
## playtest-feedback surface (see FeedbackPopup's doc comment below).
##
## Replaces the old verbatim index.html port: a bare Label eyebrow/title/
## lede stacked over the running game with no transition at all. DEMO_PLAN.md
## S0/S1: wordmark fades up alone on black (no engine splash, no "click to
## start" banner), holds, then the live world is revealed behind it with the
## camera already drifting (title_camera.gd, a path independent of the play
## rig). Play fades the menu out and glides the camera down behind the child
## in one unbroken move (Game.title_camera.glide_to_gameplay()) before
## start_episode() actually begins the run -- "no cut, no fade to a separate
## scene".
##
## Game.title_card/credits_screen cross-references (same pattern as
## Game.player/camera/ball/title_camera) let this screen and credits_screen.gd
## hand off to each other without either knowing the other's scene path.

@onready var backdrop: ColorRect = $Backdrop
@onready var eyebrow: Label = $MenuRoot/Card/Eyebrow
@onready var wordmark: Label = $MenuRoot/Card/Wordmark
@onready var menu_buttons: VBoxContainer = $MenuRoot/Card/MenuButtons
@onready var play_button: Button = $MenuRoot/Card/MenuButtons/PlayButton
@onready var settings_button: Button = $MenuRoot/Card/MenuButtons/SettingsButton
@onready var credits_button: Button = $MenuRoot/Card/MenuButtons/CreditsButton
@onready var hint: Label = $MenuRoot/Card/Hint
@onready var settings_panel: SettingsPanel = $MenuRoot/Card/SettingsPanel
@onready var settings_back: Button = $MenuRoot/Card/SettingsBack

@onready var feedback_corner: Control = $FeedbackCorner
@onready var feedback_button: Button = $FeedbackCorner/FeedbackButton
@onready var feedback_popup: CenterContainer = $FeedbackPopup
@onready var feedback_close: Button = $FeedbackPopup/FeedbackCard/Fields/Actions/CloseButton
@onready var copy_button: Button = $FeedbackPopup/FeedbackCard/Fields/Actions/CopyButton
@onready var copy_status: Label = $FeedbackPopup/FeedbackCard/Fields/CopyStatus
@onready var notes_edit: TextEdit = $FeedbackPopup/FeedbackCard/Fields/Notes

@onready var scale_yes: CheckBox = $FeedbackPopup/FeedbackCard/Fields/ScaleGroup/Yes
@onready var scale_partly: CheckBox = $FeedbackPopup/FeedbackCard/Fields/ScaleGroup/Partly
@onready var scale_no: CheckBox = $FeedbackPopup/FeedbackCard/Fields/ScaleGroup/No
@onready var emotion_subtle: CheckBox = $FeedbackPopup/FeedbackCard/Fields/EmotionGroup/TooSubtle
@onready var emotion_right: CheckBox = $FeedbackPopup/FeedbackCard/Fields/EmotionGroup/AboutRight
@onready var emotion_strong: CheckBox = $FeedbackPopup/FeedbackCard/Fields/EmotionGroup/TooStrong
@onready var continue_yes: CheckBox = $FeedbackPopup/FeedbackCard/Fields/ContinueGroup/Yes
@onready var continue_maybe: CheckBox = $FeedbackPopup/FeedbackCard/Fields/ContinueGroup/Maybe
@onready var continue_no: CheckBox = $FeedbackPopup/FeedbackCard/Fields/ContinueGroup/No

const SCRIM_ALPHA := 0.16  # how much of the black backdrop stays once the world is revealed


func _ready() -> void:
	Game.title_card = self

	backdrop.color.a = 1.0
	eyebrow.modulate.a = 0.0
	wordmark.modulate.a = 0.0
	menu_buttons.modulate.a = 0.0
	hint.modulate.a = 0.0
	settings_panel.visible = false
	settings_back.visible = false
	feedback_popup.visible = false

	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_back.pressed.connect(_on_settings_back_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	feedback_button.pressed.connect(_on_feedback_pressed)
	feedback_close.pressed.connect(_on_feedback_close_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	_wire_exclusive_group([scale_yes, scale_partly, scale_no])
	_wire_exclusive_group([emotion_subtle, emotion_right, emotion_strong])
	_wire_exclusive_group([continue_yes, continue_maybe, continue_no])

	_refresh_feedback_visibility()

	# The existing ambient bed (three mood drones -- audio_director.gd),
	# started here rather than waiting for Play so the title isn't silent.
	# set_mood() is already driven every physics frame by perception.gd
	# regardless of title/gameplay state (Game.player exists from scene
	# load); only start() was gated behind the old "Begin the afternoon"
	# button, which is why the title was silent before.
	AudioDirector.start()

	_play_boot_sequence()


## S0 -> S1: hold on black, fade the wordmark up alone, then pull the
## backdrop back to a thin scrim so the live world (already drifting under
## title_camera.gd) reads behind the type. Runs exactly once, at boot.
func _play_boot_sequence() -> void:
	await get_tree().create_timer(0.35).timeout
	await UiMotion.fade_rise_in(eyebrow, 0.45).finished
	await UiMotion.fade_rise_in(wordmark, 0.55).finished

	var scrim := create_tween()
	scrim.tween_property(backdrop, "color:a", SCRIM_ALPHA, 0.9)

	await get_tree().create_timer(0.2).timeout
	UiMotion.fade_rise_in(menu_buttons, 0.35)
	UiMotion.fade_rise_in(hint, 0.35)


## Re-entry point for "Credits -> Return to title" (S7) -- a plain
## re-show, not the boot sequence again (the black hold is a first-
## impression beat, once per launch). Also where the cinematic camera
## resumes its drift for the new menu session.
func show_title_menu() -> void:
	visible = true
	backdrop.color.a = SCRIM_ALPHA
	_show_menu_view()
	UiMotion.fade_in(eyebrow, 0.25)
	UiMotion.fade_in(wordmark, 0.25)
	UiMotion.fade_in(menu_buttons, 0.25)
	UiMotion.fade_in(hint, 0.25)
	_refresh_feedback_visibility()
	if is_instance_valid(Game.title_camera):
		Game.title_camera.show_title()


func _show_menu_view() -> void:
	menu_buttons.visible = true
	hint.visible = true
	settings_panel.visible = false
	settings_back.visible = false


# ------------------------------------------------------------------ play --

func _on_play_pressed() -> void:
	play_button.disabled = true  # guard against a second click mid-glide
	settings_button.disabled = true
	credits_button.disabled = true

	UiMotion.fade_out(eyebrow, 0.25)
	UiMotion.fade_out(wordmark, 0.25)
	UiMotion.fade_out(menu_buttons, 0.2)
	UiMotion.fade_out(hint, 0.2)
	var scrim := create_tween()
	scrim.tween_property(backdrop, "color:a", 0.0, 0.6)

	if is_instance_valid(Game.title_camera):
		await Game.title_camera.glide_to_gameplay()

	Game.start_episode()
	visible = false
	play_button.disabled = false
	settings_button.disabled = false
	credits_button.disabled = false


# -------------------------------------------------------------- settings --

func _on_settings_pressed() -> void:
	UiMotion.fade_out(menu_buttons, 0.18)
	UiMotion.fade_out(hint, 0.18)
	settings_panel.refresh()
	settings_panel.modulate.a = 1.0
	settings_back.modulate.a = 1.0
	UiMotion.fade_rise_in(settings_panel, 0.2)
	UiMotion.fade_rise_in(settings_back, 0.2)


func _on_settings_back_pressed() -> void:
	UiMotion.fade_out(settings_panel, 0.18)
	UiMotion.fade_out(settings_back, 0.18)
	menu_buttons.modulate.a = 1.0
	hint.modulate.a = 1.0
	UiMotion.fade_rise_in(menu_buttons, 0.2)
	UiMotion.fade_rise_in(hint, 0.2)


# --------------------------------------------------------------- credits --

func _on_credits_pressed() -> void:
	if not is_instance_valid(Game.credits_screen):
		return
	Game.credits_screen.show_credits()
	visible = false


# -------------------------------------------------------------- feedback --
## DEMO_PLAN.md: "The current end-card feedback survey is removed from the
## ending... Feedback moves to the title screen, post-completion." Same
## three questions + notes + copy-to-clipboard end_card.gd used to show on
## every completion, unconditionally, in the middle of the ending -- now
## a small opt-in button here, visible only once Game.completed_once (set
## by ending_screen.gd the moment the episode actually completes).

func _refresh_feedback_visibility() -> void:
	feedback_corner.visible = Game.completed_once


func _on_feedback_pressed() -> void:
	copy_status.text = ""
	feedback_popup.modulate.a = 1.0
	UiMotion.fade_rise_in(feedback_popup, 0.2)


func _on_feedback_close_pressed() -> void:
	UiMotion.fade_out(feedback_popup, 0.18)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_feedback_text())
	copy_status.text = "Playtest notes copied."


func _feedback_text() -> String:
	var notes := notes_edit.text.strip_edges()
	return "\n".join([
		"SMALL WORLD -- THE LOST BALL PLAYTEST",
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
