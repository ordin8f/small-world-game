extends SceneTree
const SCENE_PATH := "res://scenes/ui/ending_screen.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/ui/ending_screen.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/ui/ending_screen.tscn -- the S6 "held
## shot" window-frame overlay. See scripts/ui/ending_screen.gd's doc
## comment for the composition and behavior; this only builds the node
## tree its @onready paths expect.
##
## Fractions below assume the project's configured 1280x720 viewport
## (project.godot's display/window/size) and canvas_items stretch mode,
## which scales Control pixel metrics with the window -- same assumption
## hud.tscn's own hardcoded pixel offsets already make.
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## issue as the other UI generators. Attached as a plain ExtResource text
## edit afterward.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_ending_screen_scene.gd

## Narrower and taller than a letterbox: a window is a portrait-ish hole in a
## wall. At 0.125/0.875 the opening was wider than it was tall and read as a
## cinematic bar with lines drawn on it rather than as something to look through.
const PANE_LEFT := 0.225
const PANE_RIGHT := 0.775
const PANE_TOP := 0.115
const PANE_BOTTOM := 0.7083  # 1 - 210px sill band / 720px


func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "EndingScreen"
	root.layer = 10

	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(0, 0, 0, 0)
	frame_box.border_color = Color(0.02, 0.02, 0.02, 0.97)
	frame_box.border_width_left = 288
	frame_box.border_width_right = 288
	frame_box.border_width_top = 83
	frame_box.border_width_bottom = 0
	frame.add_theme_stylebox_override("panel", frame_box)
	root.add_child(frame)
	frame.owner = root

	var sill := Panel.new()
	sill.name = "Sill"
	sill.anchor_left = 0.0
	sill.anchor_right = 1.0
	sill.anchor_top = PANE_BOTTOM
	sill.anchor_bottom = 1.0
	sill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sill_box := StyleBoxFlat.new()
	sill_box.bg_color = Color(0.09, 0.065, 0.045, 0.97)
	sill_box.border_width_top = 2
	sill_box.border_color = Color(1.0, 0.66, 0.28, 0.35)
	sill.add_theme_stylebox_override("panel", sill_box)
	root.add_child(sill)
	sill.owner = root

	var icons_center := CenterContainer.new()
	icons_center.name = "IconsCenter"
	icons_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	icons_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sill.add_child(icons_center)
	icons_center.owner = root

	var icons := HBoxContainer.new()
	icons.name = "Icons"
	icons.add_theme_constant_override("separation", 44)
	icons_center.add_child(icons)
	icons.owner = root

	for i in range(3):
		var icon := Panel.new()
		icon.name = "Treasure%d" % i
		icon.custom_minimum_size = Vector2(26, 26)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_box := StyleBoxFlat.new()
		icon_box.bg_color = Color(1.0, 0.74, 0.4, 1.0)
		icon_box.set_corner_radius_all(13)
		icon_box.set_border_width_all(1)
		icon_box.border_color = Color(1.0, 0.92, 0.78, 0.6)
		icon.add_theme_stylebox_override("panel", icon_box)
		icon.visible = false
		icons.add_child(icon)
		icon.owner = root

	# NO MULLIONS. A cross of bars over a live 3D frame does not read as a
	# window -- it reads as a UI overlay on a gameplay screenshot, because the
	# bars cut through the scene instead of framing it. A single clean aperture
	# in a dark wall does the job, which is also what concept_08 shows.

	var text_area := CenterContainer.new()
	text_area.name = "TextArea"
	# BELOW the aperture, not over it. Centred inside the window the line
	# competed with the image it was supposed to caption -- and this shot is
	# meant to be an image first. It now sits on the dark sill band, which is
	# also where a caption belongs.
	text_area.anchor_left = 0.0
	text_area.anchor_right = 1.0
	text_area.anchor_top = PANE_BOTTOM
	text_area.anchor_bottom = PANE_BOTTOM
	text_area.offset_top = 26
	text_area.offset_bottom = 96
	text_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(text_area)
	text_area.owner = root

	var line_text := Label.new()
	line_text.name = "LineText"
	line_text.theme_type_variation = "ScreenHeading"
	line_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_text.custom_minimum_size = Vector2(560, 0)
	text_area.add_child(line_text)
	line_text.owner = root

	var fade_to_black := ColorRect.new()
	fade_to_black.name = "FadeToBlack"
	# Alpha baked opaque (1) -- ending_screen.gd fades this in via
	# modulate.a (UiMotion.fade_in), not color.a; color.a must stay at its
	# full authored value or the two multiply to permanent invisibility.
	# See ui_motion.gd's own doc comment.
	fade_to_black.color = Color(0, 0, 0, 1)
	fade_to_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_to_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_to_black)
	fade_to_black.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/ending_screen.tscn")
	if err != OK:
		printerr("Failed to save ending_screen.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/ending_screen.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

