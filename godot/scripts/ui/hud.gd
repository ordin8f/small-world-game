extends CanvasLayer
## Verbatim-copy HUD from index.html's #hud (lines 32-53): objective card,
## Sound/Reduce-motion toggles, dialogue card, interaction prompt. Shows
## itself on the first Game.state_changed after start_episode() (mirrors
## game.mjs's begin()'s hud.hidden = false); hides again on
## Game.episode_complete (mirrors showEnding()'s hud.hidden = true).

@onready var objective_label: Label = $Root/Top/ObjectiveCard/ObjectiveText
@onready var mute_button: Button = $Root/Top/Buttons/MuteButton
@onready var motion_button: Button = $Root/Top/Buttons/MotionButton
@onready var dialogue_card: Control = $Root/DialogueCard
@onready var dialogue_speaker: Label = $Root/DialogueCard/Speaker
@onready var dialogue_text: Label = $Root/DialogueCard/Text
@onready var prompt: Control = $Root/Prompt
@onready var prompt_text: Label = $Root/Prompt/PromptText
@onready var dialogue_timer: Timer = $DialogueTimer


func _ready() -> void:
	visible = false
	dialogue_card.visible = false
	prompt.visible = false
	Game.state_changed.connect(_on_state_changed)
	Game.prompt_changed.connect(_on_prompt_changed)
	Game.dialogue_shown.connect(_on_dialogue_shown)
	Game.episode_complete.connect(_on_episode_complete)
	mute_button.pressed.connect(_on_mute_pressed)
	motion_button.pressed.connect(_on_motion_pressed)
	dialogue_timer.timeout.connect(_on_dialogue_timeout)
	_update_mute_label()
	_update_motion_label()


func _on_state_changed(_new_state: String) -> void:
	visible = true
	objective_label.text = Game.director.copy()["objective"]


func _on_prompt_changed(label: String) -> void:
	prompt.visible = label != ""
	prompt_text.text = label


func _on_dialogue_shown(speaker: String, text: String, duration: float) -> void:
	dialogue_speaker.text = speaker
	dialogue_text.text = text
	dialogue_card.visible = true
	dialogue_timer.start(duration)


func _on_dialogue_timeout() -> void:
	dialogue_card.visible = false


func _on_episode_complete() -> void:
	visible = false


func _on_mute_pressed() -> void:
	Game.muted = not Game.muted
	_update_mute_label()


func _on_motion_pressed() -> void:
	Game.reduced_motion = not Game.reduced_motion
	_update_motion_label()


func _update_mute_label() -> void:
	mute_button.text = "Sound off" if Game.muted else "Sound on"
	mute_button.button_pressed = Game.muted


func _update_motion_label() -> void:
	motion_button.text = "Motion reduced" if Game.reduced_motion else "Reduce motion"
	motion_button.button_pressed = Game.reduced_motion
