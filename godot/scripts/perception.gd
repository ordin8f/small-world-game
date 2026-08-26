extends Node
## Verbatim port of src/game.mjs's applyEnvironment() (lines 413-428) plus
## the updateEmotion() call that feeds it (lines 376-382). Nothing else in
## the game drives EmotionalLens forward -- this Node's _physics_process is
## what makes comfort/energy/curiosity, and therefore every visual effect
## derived from them, move at all. Found via find_child() from the actual
## SceneTree root rather than a fixed NodePath, since this Node doesn't
## need to live at a specific place in the tree -- NOT via
## get_tree().current_scene, which is null both here (no run/main_scene
## configured) and in every gdUnit4 SceneRunner test (it adds the
## instantiated scene under root, but never sets current_scene to it).

const GROUP_POSITION := Vector2(0.0, -3.8)  # game.mjs's groupPosition, x/z only

@onready var world_environment: WorldEnvironment = get_tree().root.find_child("WorldEnvironment", true, false)
@onready var sun: DirectionalLight3D = get_tree().root.find_child("Sun", true, false)


func _physics_process(delta: float) -> void:
	var player := Game.player
	if not is_instance_valid(player):
		return

	var p := player.global_position
	var distance_from_group := Vector2(p.x - GROUP_POSITION.x, p.z - GROUP_POSITION.y).length()
	Game.lens.set_target(Game.director.emotional_target(distance_from_group))
	Game.lens.update(delta)

	_apply_environment(Game.lens.get_visuals())


func _apply_environment(visuals: Dictionary) -> void:
	var warm: float = visuals["warmth"]
	var fog_color: Array = LensMath.interpolate_color([0.23, 0.28, 0.33], [0.72, 0.58, 0.39], warm)
	var ambient_color: Array = LensMath.interpolate_color([0.22, 0.24, 0.28], [0.45, 0.40, 0.31], warm)
	var light_color: Array = LensMath.interpolate_color([0.58, 0.65, 0.76], [1.08, 0.84, 0.54], warm)

	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.fog_light_color = Color(fog_color[0], fog_color[1], fog_color[2])
		env.fog_depth_begin = visuals["fog_near"]
		env.fog_depth_end = visuals["fog_far"]
		env.ambient_light_color = Color(ambient_color[0], ambient_color[1], ambient_color[2])
		env.tonemap_exposure = LensMath.lerp_value(0.82, 1.12, warm)

	if sun != null:
		sun.light_color = Color(light_color[0], light_color[1], light_color[2])
