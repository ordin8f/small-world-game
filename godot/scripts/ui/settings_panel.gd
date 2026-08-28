class_name SettingsPanel
extends VBoxContainer
## Shared Sound/Reduce-motion toggle block. DEMO_PLAN.md's S1 title menu
## and S8 pause menu both need a "Settings" surface, and the entire
## current settings surface is exactly these two toggles (hud.gd's own
## Sound on/off, Reduce motion buttons, mirrored here) -- one scene,
## instanced from both screens, rather than duplicating the wiring twice.

@onready var mute_button: Button = $MuteButton
@onready var motion_button: Button = $MotionButton


func _ready() -> void:
	mute_button.pressed.connect(_on_mute_pressed)
	motion_button.pressed.connect(_on_motion_pressed)
	refresh()


## Called by the owning screen whenever this panel becomes visible again --
## Game.muted/reduced_motion can change elsewhere (Hud's own buttons)
## between this panel's instantiation and any later time it is shown.
func refresh() -> void:
	mute_button.text = "Sound off" if Game.muted else "Sound on"
	mute_button.button_pressed = Game.muted
	motion_button.text = "Motion reduced" if Game.reduced_motion else "Reduce motion"
	motion_button.button_pressed = Game.reduced_motion


func _on_mute_pressed() -> void:
	Game.muted = not Game.muted
	refresh()


func _on_motion_pressed() -> void:
	Game.reduced_motion = not Game.reduced_motion
	refresh()
