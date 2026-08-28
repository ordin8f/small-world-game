extends CanvasLayer
## Gate 0 frame, S6: "an image, not a survey." Replaces end_card.gd's
## unconditional three-question feedback form (moved to the title screen,
## post-completion -- see title_card.gd's FeedbackPopup) with a held shot:
## a window frame in the extreme foreground, the world seen through it,
## up to three found-treasure tokens on the sill, one line, then black.
##
## Composition is docs/concept-art/extended/concept_08_interior_ending.png:
## a thick dark window frame close to camera, a warm dusk view beyond,
## small objects on the sill in the near foreground. Rather than modeling
## a literal room, this reuses the world the game already renders --
## title_camera.gd's own anchor/look-target (concept_07's threshold-vs-
## chalk-circle framing) is reused unchanged for the cut into this shot,
## just now lit by the dusk preset instead of afternoon, with Mina/Arun/
## Third still standing where they always stand -- "the three children
## still playing outside" falls out of the world already being there, for
## free. Only a 2D window-frame overlay (this scene) and the cut itself
## are new.
##
## treasures_found is always 0 today (DEMO_PLAN.md S3's pocket-treasure
## pickup isn't built yet -- see Game.treasures_found's own doc comment);
## _update_sill() below is written to handle 0..3 correctly regardless,
## per the brief ("the shot must work either way"), and is unit-tested at
## all four counts directly.

@onready var frame: Panel = $Frame
@onready var sill: Panel = $Sill
@onready var mullion_v: Panel = $MullionV
@onready var mullion_h: Panel = $MullionH
@onready var text_area: CenterContainer = $TextArea
@onready var line_text: Label = $TextArea/LineText
@onready var fade_to_black: ColorRect = $FadeToBlack
@onready var treasures: Array[Panel] = [$Sill/IconsCenter/Icons/Treasure0, $Sill/IconsCenter/Icons/Treasure1, $Sill/IconsCenter/Icons/Treasure2]

const LINE := "You're home now. Outside, the game is still going."

const HOLD_SECONDS := 3.4
const FADE_TO_BLACK_SECONDS := 1.0


func _ready() -> void:
	Game.ending_screen = self
	visible = false
	fade_to_black.modulate.a = 0.0  # NOT color.a -- see ui_motion.gd's doc comment; that .tres/.tscn-authored color is baked opaque and modulate is what UiMotion actually animates
	line_text.text = LINE
	Game.episode_complete.connect(_on_episode_complete)


func _on_episode_complete() -> void:
	Game.mark_completed()
	_update_sill()
	visible = true

	# The cut: reuses title_camera.gd's own anchor/look-target (concept_07's
	# framing), now under dusk lighting (perception.gd's mood arc is already
	# at COMPLETE = dusk by the time this signal fires -- see its own doc
	# comment on the arc advancing off director.state). A hard cut, not a
	# glide -- unlike S1's Play, DEMO_PLAN.md does not ask this transition to
	# be unbroken, and games routinely cut to their final shot; the overlay
	# fading in immediately after is what keeps it from reading as abrupt.
	if is_instance_valid(Game.title_camera):
		Game.title_camera.show_title()

	frame.modulate.a = 0.0
	sill.modulate.a = 0.0
	mullion_v.modulate.a = 0.0
	mullion_h.modulate.a = 0.0
	line_text.modulate.a = 0.0

	UiMotion.fade_in(frame, 0.4)
	UiMotion.fade_in(sill, 0.4)
	UiMotion.fade_in(mullion_v, 0.4)
	UiMotion.fade_in(mullion_h, 0.4)
	await get_tree().create_timer(0.5).timeout
	await _reveal_sill_icons()
	await get_tree().create_timer(0.4).timeout
	await UiMotion.fade_rise_in(line_text, 0.6).finished

	await get_tree().create_timer(HOLD_SECONDS).timeout
	await UiMotion.fade_in(fade_to_black, FADE_TO_BLACK_SECONDS).finished

	if is_instance_valid(Game.credits_screen):
		Game.credits_screen.show_credits()
	visible = false


## 0..3 tokens, in order, each a short stagger after the last -- reads as
## small things being noticed one at a time rather than appearing as a set.
func _reveal_sill_icons() -> void:
	for icon in treasures:
		if not icon.visible:
			continue
		icon.modulate.a = 0.0
		UiMotion.fade_in(icon, 0.3)
		await get_tree().create_timer(0.18).timeout


## Split out from _on_episode_complete() so tests (and this function's own
## caller) can drive it directly against any value of Game.treasures_found
## without running a full episode.
func _update_sill() -> void:
	var count := clampi(Game.treasures_found, 0, 3)
	for i in range(treasures.size()):
		treasures[i].visible = i < count
