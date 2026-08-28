extends GdUnitTestSuite
## Play test for scripts/perception.gd.
##
## REWRITTEN 2026-08-28 alongside the lens inversion. The previous version
## asserted `WorldEnvironment.environment.fog_depth_begin == lens.get_visuals()
## ["fog_near"]` -- i.e. it asserted that the Emotional Lens *authors* the
## lighting. That was exactly the architecture defect being removed: it meant no
## authored base scene could survive a frame, and the game could not be
## art-directed (see the note at the top of perception.gd).
##
## The behavioural intent of the old test is preserved and strengthened:
##   1. perception.gd is actually running and drives EmotionalLens forward.
##   2. Unease still visibly closes the world in -- but as a BOUNDED modulation
##      of an authored mood, not as an absolute value.
##   3. NEW, and the acceptance criterion docs/ART_DIRECTION.md has always
##      stated but was never testable: with the lens disabled the scene still
##      shows a complete, authored mood.

const MoodPresetScript := preload("res://scripts/mood_preset.gd")
const EPSILON := 0.001


func _find_perception(runner) -> Node:
	return runner.scene().find_child("Perception", true, false)


func test_lens_still_advances_and_unease_closes_the_world_in() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let every node's _ready() run

	var player: Node3D = Game.player
	assert_object(player).is_not_null()

	Game.start_episode(0.0)
	var initial_comfort: float = Game.lens.value["comfort"]

	# Force FIND_BALL and stand far from the group so emotional_target()'s
	# distance term pulls comfort down hard.
	Game.director.state = EpisodeDirector.State.FIND_BALL
	player.global_position = Vector3(8.6, 0.0, -6.6)

	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(120):
		await tree.physics_frame

	# 1. The lens is genuinely being driven.
	assert_float(Game.lens.value["comfort"]).is_less(initial_comfort)

	# 2. Fog tracks the AUTHORED mood, modulated within the documented bound.
	var afternoon: Resource = load("res://resources/moods/afternoon.tres")
	assert_object(afternoon).is_not_null()

	var world_env: WorldEnvironment = runner.scene().find_child("WorldEnvironment", true, false)
	assert_object(world_env).is_not_null()
	var actual: float = world_env.environment.fog_depth_begin

	var lo: float = afternoon.fog_begin * (1.0 - Perception_fog_bound())
	var hi: float = afternoon.fog_begin * (1.0 + Perception_fog_bound())
	assert_float(actual).is_between(lo, hi)

	# Low comfort must pull the fog IN, not push it out -- the emotional read
	# the original test was really guarding.
	assert_float(actual).is_less(afternoon.fog_begin)


func test_scene_is_complete_and_authored_with_the_lens_disabled() -> void:
	# docs/ART_DIRECTION.md: "The base scene must remain coherent when all
	# Emotional Lens effects are disabled." Before the inversion there was no
	# base scene at all, so this could not be written.
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var perception := _find_perception(runner)
	assert_object(perception).is_not_null()
	perception.set("lens_enabled", false)

	Game.start_episode(0.0)
	Game.director.state = EpisodeDirector.State.FIND_BALL
	if is_instance_valid(Game.player):
		Game.player.global_position = Vector3(8.6, 0.0, -6.6)

	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(60):
		await tree.physics_frame

	var afternoon: Resource = load("res://resources/moods/afternoon.tres")
	var world_env: WorldEnvironment = runner.scene().find_child("WorldEnvironment", true, false)
	var env: Environment = world_env.environment

	# With no lens modulation the world is exactly the authored afternoon mood,
	# regardless of how unhappy the child is.
	assert_float(env.fog_depth_begin).is_equal_approx(afternoon.fog_begin, EPSILON)
	assert_float(env.fog_depth_end).is_equal_approx(afternoon.fog_end, EPSILON)
	assert_float(env.tonemap_exposure).is_equal_approx(afternoon.exposure, EPSILON)
	assert_float(env.adjustment_saturation).is_equal_approx(afternoon.saturation, EPSILON)
	assert_float(env.ambient_light_energy).is_equal_approx(afternoon.ambient_energy, EPSILON)

	# And it is a real mood, not an empty Environment: deep shadow (low ambient),
	# visible haze, and a warm sun feeding it.
	assert_float(env.ambient_light_energy).is_less(1.0)
	assert_bool(env.volumetric_fog_enabled).is_true()
	assert_float(env.volumetric_fog_density).is_greater(0.0)

	var sun: DirectionalLight3D = runner.scene().find_child("Sun", true, false)
	assert_object(sun).is_not_null()
	assert_float(sun.light_energy).is_greater(1.0)
	assert_float(sun.light_volumetric_fog_energy).is_greater(0.0)


func test_mood_moves_from_afternoon_to_dusk_across_the_episode() -> void:
	# The three authored moods ART_DIRECTION.md requires must actually be
	# reachable from the episode, not just exist as files on disk.
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var perception := _find_perception(runner)
	var tree := Engine.get_main_loop() as SceneTree

	Game.start_episode(0.0)
	Game.director.state = EpisodeDirector.State.ARRIVE
	for _i in range(30):
		await tree.physics_frame
	var early: float = perception.call("mood_progress")

	Game.director.state = EpisodeDirector.State.GO_HOME
	for _i in range(300):
		await tree.physics_frame
	var late: float = perception.call("mood_progress")

	assert_float(early).is_less(0.1)
	assert_float(late).is_greater(early)
	assert_float(late).is_greater(0.7)


## Mirrors perception.gd's LENS_FOG_SCALE. Kept as a function so the test fails
## loudly if the constant is widened without a deliberate art decision.
func Perception_fog_bound() -> float:
	return 0.25
