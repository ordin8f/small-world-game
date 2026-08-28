extends CanvasLayer
## Verbatim-copy title card from index.html's #start-screen (lines 16-30):
## eyebrow, title, lede, "Begin the afternoon" button, controls summary.

@onready var begin_button: Button = $Root/Card/BeginButton


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)


func _on_begin_pressed() -> void:
	Game.start_episode()
	visible = false
