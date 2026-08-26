extends MeshInstance3D
## Verbatim port of scene.mjs's createHomeGlow() (lines 218-239): a
## translucent emissive plane at the home threshold, pulsing (game.mjs:446's
## pulse = (sin(time*2.1)+1)/2) while GO_HOME/COMPLETE, dark otherwise.

const GLOW_COLOR := Color(1.0, 0.66, 0.28)  # palette.warmLight

var _time: float = 0.0


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = GLOW_COLOR
	mat.emission_energy_multiplier = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	set_surface_override_material(0, mat)


func _process(delta: float) -> void:
	_time += delta
	var state := Game.director.state
	var active := state == EpisodeDirector.State.GO_HOME or state == EpisodeDirector.State.COMPLETE

	var intensity := 0.0
	if active:
		var pulse := (sin(_time * 2.1) + 1.0) / 2.0
		intensity = 0.65 + pulse * 0.25

	var mat := get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.28 + 0.28 * intensity)
	mat.emission_energy_multiplier = 0.25 + intensity * 0.75
