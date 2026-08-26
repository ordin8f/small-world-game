extends ColorRect
## Drives shaders/vignette.gdshader's uniforms every frame from
## EmotionalLens.get_visuals() -- the vignette/warmth values are computed
## (M2.1's emotional_lens.gd) but only actually reach the screen here.


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	var visuals := Game.lens.get_visuals()
	mat.set_shader_parameter("vignette_amount", visuals["vignette"])
	mat.set_shader_parameter("warmth", visuals["warmth"])
