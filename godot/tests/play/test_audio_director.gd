extends GdUnitTestSuite
## M2.5b play test: exercises AudioDirector wiring against the real
## running game -- start_episode(), a dispatch (chime), player movement
## (footstep), and mute -- rather than testing audio.mjs's ported side
## effects in isolation. Godot's headless test runner uses a dummy audio
## driver, so there's no audible signal to assert on directly; what's
## verified here is that the wiring runs at all (no script error would
## surface as anything BUT a clean pass), that start() actually
## initializes the voice players, and that muted genuinely suppresses
## playback rather than just silencing it.

func after_test() -> void:
	Game.muted = false


func test_start_episode_initializes_the_drone_and_oneshot_players() -> void:
	# AudioDirector is a process-global autoload, not scene-scoped, so
	# other suites in this same run may have already called start()
	# (idempotent) before this test does -- assert the post-start
	# invariant, not "0 children beforehand".
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	Game.start_episode(0.0)
	# chime player + step player + effect player (Gate 0: splash/whoosh) +
	# 3 drones + the music layer's 12 pad players and 4 melody players.
	assert_int(AudioDirector.get_child_count()).is_equal(22)

	# Calling start() again (Game.start_episode() on "Play again") must
	# stay idempotent, not spawn a second set of players.
	Game.start_episode(0.0)
	assert_int(AudioDirector.get_child_count()).is_equal(22)


func test_dispatch_and_movement_drive_audio_without_error() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()

	# A few physics ticks of movement -- long enough to cross
	# STEP_INTERVAL_WALKING (0.37s) at least once.
	runner.simulate_action_press("move_forward")
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(30):
		await tree.physics_frame
	runner.simulate_action_release("move_forward")

	# Each of the plan's three chime kinds, via the same events
	# test_playthrough.gd drives.
	Game.dispatch("observe")   # soft
	Game.dispatch("ball_kicked")  # uneasy (auto-scheduled normally; forced here)


func test_muted_suppresses_chime_playback() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	Game.muted = false
	AudioDirector.play_chime("soft")
	await runner.simulate_frames(2)
	var unmuted_playing: bool = AudioDirector._chime_player.playing

	AudioDirector._chime_player.stop()
	Game.muted = true
	AudioDirector.play_chime("soft")
	await runner.simulate_frames(2)
	var muted_playing: bool = AudioDirector._chime_player.playing

	assert_bool(unmuted_playing).is_true()
	assert_bool(muted_playing).is_false()


func test_splash_and_whoosh_play_on_their_own_effect_player() -> void:
	# Gate 0: puddles.gd/player.gd's two new one-shot sounds. Kept off the
	# chime player deliberately (see audio_director.gd's _effect_player doc
	# comment) -- assert that directly, not just "no error".
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)
	Game.muted = false

	AudioDirector.play_splash()
	await runner.simulate_frames(2)
	assert_bool(AudioDirector._effect_player.playing).is_true()

	AudioDirector._effect_player.stop()
	AudioDirector.play_slide_whoosh()
	await runner.simulate_frames(2)
	assert_bool(AudioDirector._effect_player.playing).is_true()
	assert_bool(AudioDirector._chime_player.playing).is_false()
