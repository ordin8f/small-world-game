extends CanvasLayer
## Gate 0 frame, S7: asset credits, reachable from the title's Credits
## button or automatically after the ending. Copy is a hand-condensed
## summary of ASSET_CREDITS.md -- update both places together if that file
## changes. Always ends by returning to the title (show_title_menu()),
## which is where DEMO_PLAN.md's "the game remembers you finished" lives:
## Game.completed_once/director.state already carry that by the time this
## screen hands back, so this file only needs to call show_title_menu().

@onready var backdrop: ColorRect = $Backdrop
@onready var card: VBoxContainer = $Root/Card
@onready var return_button: Button = $Root/Card/ReturnButton


func _ready() -> void:
	Game.credits_screen = self
	visible = false
	backdrop.modulate.a = 0.0  # NOT color.a -- see ui_motion.gd's doc comment
	return_button.pressed.connect(_on_return_pressed)


func show_credits() -> void:
	visible = true
	card.modulate.a = 1.0
	UiMotion.fade_in(backdrop, 0.2)
	UiMotion.fade_rise_in(card, 0.3)


func _on_return_pressed() -> void:
	UiMotion.fade_out(backdrop, 0.2)
	UiMotion.fade_out(card, 0.2)
	if is_instance_valid(Game.title_card):
		Game.title_card.show_title_menu()
	await get_tree().create_timer(0.22).timeout
	visible = false
