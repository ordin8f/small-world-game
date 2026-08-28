extends CanvasLayer
## Gate 0 frame, S8: Esc or window blur pauses; Resume / Restart the
## afternoon / Settings / Quit; audio ducks while paused.
##
## PROCESS_MODE_ALWAYS on the whole layer: SceneTree.paused stops every
## default (INHERIT) node's _process/_physics_process/input, including
## this one's, unless it opts out -- both the Esc-while-paused-to-resume
## input and the pause menu's own buttons need to keep working while
## everything else is frozen. AudioDirector.duck() (audio_director.gd)
## needed the matching PROCESS_MODE_ALWAYS treatment for the same reason;
## see that file's own doc comment.
##
## Only responds to Esc/blur while a real episode is actually running
## (_gameplay_active, mirrored from the same Game.state_changed/
## episode_complete signals hud.gd shows/hides itself on) -- pausing over
## the title, credits, or the ending would be a stray, confusing state.

@onready var backdrop: ColorRect = $Backdrop
@onready var card: VBoxContainer = $Root/Card
@onready var menu_buttons: VBoxContainer = $Root/Card/MenuButtons
@onready var resume_button: Button = $Root/Card/MenuButtons/ResumeButton
@onready var restart_button: Button = $Root/Card/MenuButtons/RestartButton
@onready var settings_button: Button = $Root/Card/MenuButtons/SettingsButton
@onready var quit_button: Button = $Root/Card/MenuButtons/QuitButton
@onready var settings_panel: SettingsPanel = $Root/Card/SettingsPanel
@onready var settings_back: Button = $Root/Card/SettingsBack

var _gameplay_active: bool = false


func _ready() -> void:
	Game.pause_menu = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	settings_panel.visible = false
	settings_back.visible = false

	Game.state_changed.connect(func(_s: String) -> void: _gameplay_active = true)
	Game.episode_complete.connect(func() -> void: _gameplay_active = false)

	resume_button.pressed.connect(resume)
	restart_button.pressed.connect(_on_restart_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_back.pressed.connect(_on_settings_back_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	get_window().focus_exited.connect(_on_window_focus_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func _on_window_focus_exited() -> void:
	if _gameplay_active and not get_tree().paused:
		pause()


func toggle_pause() -> void:
	if not _gameplay_active:
		return
	if get_tree().paused:
		resume()
	else:
		pause()


func pause() -> void:
	get_tree().paused = true
	AudioDirector.duck(true)
	_show_menu_view()
	visible = true
	UiMotion.fade_in(backdrop, 0.18)
	UiMotion.fade_rise_in(card, 0.2)


func resume() -> void:
	get_tree().paused = false
	AudioDirector.duck(false)
	visible = false


func _show_menu_view() -> void:
	menu_buttons.visible = true
	settings_panel.visible = false
	settings_back.visible = false


func _on_restart_pressed() -> void:
	resume()
	Game.start_episode()


func _on_settings_pressed() -> void:
	UiMotion.fade_out(menu_buttons, 0.15)
	settings_panel.refresh()
	settings_panel.modulate.a = 1.0
	settings_back.modulate.a = 1.0
	UiMotion.fade_rise_in(settings_panel, 0.18)
	UiMotion.fade_rise_in(settings_back, 0.18)


func _on_settings_back_pressed() -> void:
	UiMotion.fade_out(settings_panel, 0.15)
	UiMotion.fade_out(settings_back, 0.15)
	menu_buttons.modulate.a = 1.0
	UiMotion.fade_rise_in(menu_buttons, 0.18)


func _on_quit_pressed() -> void:
	get_tree().quit()
