extends SceneTree
## One-shot generator: builds resources/ui/theme.tres, the project's default
## Theme (wired via project.godot's [gui] theme/custom).
##
## Why this exists: DEMO_PLAN.md's M4 gate calls out "the unstyled debug
## text currently sitting on the player's head" -- every Label/Button in
## the project rendered in Godot's bare built-in font at default size and
## color, indistinguishable from a debug overlay. Applying one authored
## Theme project-wide (rather than per-scene overrides five times over)
## fixes every screen at once, including Hud/DialogueCard, which are
## otherwise untouched -- this file changes no scene structure or copy
## anywhere, only how existing text renders.
##
## Fonts are SystemFont resources (OS font lookup by name, first match
## wins, falls back to Godot's built-in font if none are installed) rather
## than a vendored .ttf: this machine's Windows install ships the whole
## fallback chain below, avoids adding a binary asset + license file for a
## prototype UI pass, and degrades gracefully (never a missing-font error)
## on a machine that lacks them. A warm literary serif for display type
## pairs against a clean UI sans for menus/body -- ART_DIRECTION.md's
## "restrained... beauty from proportion" applies to type choice too: two
## families, used consistently, beats a font per screen.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_ui_theme.gd

const COLOR_TEXT_PRIMARY := Color(0.96, 0.94, 0.90)
const COLOR_TEXT_SECONDARY := Color(0.80, 0.76, 0.68)
const COLOR_TEXT_MUTED := Color(0.62, 0.59, 0.53)
const COLOR_ACCENT := Color(1.0, 0.66, 0.28)          # WorldBounds.PALETTE.warm_light -- the porch-light color
const COLOR_PANEL_BG := Color(0.05, 0.055, 0.05, 0.42)
const COLOR_PANEL_BG_HOVER := Color(0.09, 0.08, 0.06, 0.62)
const COLOR_PANEL_BG_PRESSED := Color(0.03, 0.035, 0.03, 0.7)
const COLOR_BORDER := Color(1.0, 0.66, 0.28, 0.30)
const COLOR_BORDER_HOVER := Color(1.0, 0.66, 0.28, 0.65)


func _init() -> void:
	var display_base := SystemFont.new()
	display_base.font_names = PackedStringArray(["Cambria", "Constantia", "Georgia", "Times New Roman"])

	var ui_base := SystemFont.new()
	ui_base.font_names = PackedStringArray(["Segoe UI Semilight", "Segoe UI", "Calibri", "Verdana"])

	var ui_bold := SystemFont.new()
	ui_bold.font_names = PackedStringArray(["Segoe UI Semibold", "Segoe UI", "Calibri", "Verdana"])
	ui_bold.font_weight = 600

	# Wide-tracked variant of the UI font for small-caps eyebrow labels
	# ("SMALL WORLD", menu items) -- a common storybook/title-card device
	# that needs no new font file, just letter-spacing on the existing one.
	var eyebrow := FontVariation.new()
	eyebrow.base_font = ui_base
	eyebrow.spacing_glyph = 5

	var theme := Theme.new()
	theme.default_font = ui_base
	theme.default_font_size = 18

	# ---- base Label/Button (covers Hud/DialogueCard with zero scene edits) --
	theme.set_font("font", "Label", ui_base)
	theme.set_font_size("font", "Label", 18)
	theme.set_color("font_color", "Label", COLOR_TEXT_SECONDARY)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)

	theme.set_font("font", "Button", ui_bold)
	theme.set_font_size("font", "Button", 19)
	theme.set_color("font_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", COLOR_ACCENT)
	theme.set_color("font_pressed_color", "Button", COLOR_ACCENT)
	theme.set_color("font_focus_color", "Button", COLOR_ACCENT)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	theme.set_stylebox("normal", "Button", _button_box(COLOR_PANEL_BG, COLOR_BORDER))
	theme.set_stylebox("hover", "Button", _button_box(COLOR_PANEL_BG_HOVER, COLOR_BORDER_HOVER))
	theme.set_stylebox("pressed", "Button", _button_box(COLOR_PANEL_BG_PRESSED, COLOR_BORDER_HOVER))
	theme.set_stylebox("disabled", "Button", _button_box(COLOR_PANEL_BG, Color(1, 1, 1, 0.08)))
	theme.set_stylebox("focus", "Button", _focus_box())

	theme.set_font("font", "CheckBox", ui_base)
	theme.set_font_size("font", "CheckBox", 17)
	theme.set_color("font_color", "CheckBox", COLOR_TEXT_SECONDARY)
	theme.set_color("font_hover_color", "CheckBox", COLOR_TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "CheckBox", COLOR_ACCENT)

	theme.set_font("font", "TextEdit", ui_base)
	theme.set_font_size("font", "TextEdit", 16)
	theme.set_color("font_color", "TextEdit", COLOR_TEXT_SECONDARY)
	theme.set_stylebox("normal", "TextEdit", _button_box(COLOR_PANEL_BG, Color(1, 1, 1, 0.12)))

	# ---- named type variations -- opt in per-Label via theme_type_variation --
	theme.set_type_variation("Wordmark", "Label")
	theme.set_font("font", "Wordmark", display_base)
	theme.set_font_size("font", "Wordmark", 64)
	theme.set_color("font_color", "Wordmark", COLOR_TEXT_PRIMARY)
	theme.set_color("font_shadow_color", "Wordmark", Color(0, 0, 0, 0.65))
	theme.set_constant("shadow_offset_x", "Wordmark", 0)
	theme.set_constant("shadow_offset_y", "Wordmark", 3)

	theme.set_type_variation("Eyebrow", "Label")
	theme.set_font("font", "Eyebrow", eyebrow)
	theme.set_font_size("font", "Eyebrow", 15)
	theme.set_color("font_color", "Eyebrow", COLOR_TEXT_MUTED)

	theme.set_type_variation("ScreenHeading", "Label")
	theme.set_font("font", "ScreenHeading", display_base)
	theme.set_font_size("font", "ScreenHeading", 36)
	theme.set_color("font_color", "ScreenHeading", COLOR_TEXT_PRIMARY)

	theme.set_type_variation("BodyText", "Label")
	theme.set_font("font", "BodyText", ui_base)
	theme.set_font_size("font", "BodyText", 19)
	theme.set_color("font_color", "BodyText", COLOR_TEXT_SECONDARY)

	theme.set_type_variation("MutedText", "Label")
	theme.set_font("font", "MutedText", ui_base)
	theme.set_font_size("font", "MutedText", 15)
	theme.set_color("font_color", "MutedText", COLOR_TEXT_MUTED)

	theme.set_type_variation("PlainButton", "Button")
	theme.set_font("font", "PlainButton", eyebrow)
	theme.set_font_size("font", "PlainButton", 20)
	theme.set_stylebox("normal", "PlainButton", _flat_box())
	theme.set_stylebox("hover", "PlainButton", _flat_box())
	theme.set_stylebox("pressed", "PlainButton", _flat_box())
	theme.set_stylebox("focus", "PlainButton", _flat_box())
	theme.set_color("font_color", "PlainButton", COLOR_TEXT_SECONDARY)
	theme.set_color("font_hover_color", "PlainButton", COLOR_ACCENT)
	theme.set_color("font_pressed_color", "PlainButton", COLOR_ACCENT)
	theme.set_color("font_focus_color", "PlainButton", COLOR_ACCENT)

	var err := ResourceSaver.save(theme, "res://resources/ui/theme.tres")
	if err != OK:
		printerr("Failed to save resources/ui/theme.tres: ", err)
		quit(1)
		return
	print("Wrote resources/ui/theme.tres")
	quit()


func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(1)
	box.border_color = border
	box.set_corner_radius_all(3)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## Borderless variant for PlainButton -- the title/pause menu reads as a
## short list of words (ART_DIRECTION.md's UI restraint), not as boxed
## buttons; hover/press state is carried entirely by font_hover_color/
## font_pressed_color above.
func _flat_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_border_width_all(1)
	box.border_color = COLOR_ACCENT
	box.set_corner_radius_all(3)
	return box
