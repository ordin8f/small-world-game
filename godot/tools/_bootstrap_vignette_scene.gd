extends SceneTree
## One-shot generator: builds scenes/ui/vignette.tscn -- a full-screen
## ColorRect with shaders/vignette.gdshader, port of index.html's
## #lens-overlay (styles.css:34-41).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_vignette_scene.gd

func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "Vignette"
	root.layer = 8  # above the 3D viewport, below HUD/cards
	# NOTE: script deliberately NOT attached here -- same reason as
	# player.tscn's generator (see its doc comment).

	var rect := ColorRect.new()
	rect.name = "Overlay"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1, 1, 1, 1)  # irrelevant -- the shader fully overrides COLOR

	var shader: Shader = load("res://shaders/vignette.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# Explicit defaults -- without this, ShaderMaterial.new() serializes
	# shader_parameter overrides as `null` rather than falling back to the
	# shader's own uniform defaults (confirmed via a first-pass save/read).
	mat.set_shader_parameter("vignette_amount", 0.28)
	mat.set_shader_parameter("warmth", 0.5)
	rect.material = mat

	root.add_child(rect)
	rect.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/vignette.tscn")
	if err != OK:
		printerr("Failed to save vignette.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/vignette.tscn")
	quit()
