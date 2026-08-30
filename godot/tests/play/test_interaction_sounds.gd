extends GdUnitTestSuite
## The three interaction-sound changes of 2026-08-30, against the real running
## game: the bench settling under a child who sits, footsteps finally ticking
## on the tower stairs, and the invitation getting its own cue instead of
## sharing one with the front door.
##
## What none of these can check is whether the sounds are any good or whether
## they click. tools/_probe_oneshots.gd renders every cue to .wav and measures
## it; tests/unit/test_audio_oneshots.gd guards the envelopes.

func before_test() -> void:
	Game.muted = false


func after_test() -> void:
	Game.muted = false


func test_sitting_on_the_bench_makes_a_sound_and_standing_up_does_not() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	var player: Node3D = Game.player
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	AudioDirector._effect_player.stop()
	Game.interact()
	await runner.simulate_frames(2)
	assert_bool(AudioDirector._effect_player.playing) \
		.override_failure_message("sitting down made no sound").is_true()

	# Standing up is deliberately silent -- sounding both halves of a toggle
	# is how a world starts reading as a menu.
	AudioDirector._effect_player.stop()
	Game.interact()
	await runner.simulate_frames(2)
	assert_bool(AudioDirector._effect_player.playing) \
		.override_failure_message("standing up made a sound; it should not").is_false()


func test_the_bench_settle_respects_mute() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	Game.muted = true
	AudioDirector._effect_player.stop()
	AudioDirector.play_bench_settle()
	await runner.simulate_frames(2)
	assert_bool(AudioDirector._effect_player.playing).is_false()

	Game.muted = false
	AudioDirector.play_bench_settle()
	await runner.simulate_frames(2)
	assert_bool(AudioDirector._effect_player.playing).is_true()


## The climb was the one verb that walked in total silence: it drives
## walk_cycle and puts feet on the treads for 1.9 s, and played nothing,
## while the ordinary walk, the tower deck and the edging all tick footsteps.
func test_climbing_the_tower_stairs_ticks_footsteps() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	var player: Node3D = Game.player
	var tree := Engine.get_main_loop() as SceneTree

	# play_step() self-rate-limits against its own clock, so clear it or a
	# footstep from walking into position would mask a silent climb.
	AudioDirector._last_step_time = -1000.0
	AudioDirector._step_player.stop()

	player.global_position = Vector3(
		WorldAffordances.CLIMB_TRIGGER.x, WorldAffordances.CLIMB_TRIGGER.y,
		WorldAffordances.CLIMB_TRIGGER.z)
	player.call("_start_climb")

	var heard := false
	for _i in range(40):
		await tree.physics_frame
		if AudioDirector._step_player.playing:
			heard = true
			break
	assert_bool(heard) \
		.override_failure_message("the climb walked up the stairs in silence").is_true()


## The invitation used to share "warm" with walking through your own front
## door. Asserted on the length of the stream actually queued for playback
## rather than on a label, so it fails if the two moments ever collapse back
## onto one sound.
func test_the_invitation_and_going_home_are_different_sounds() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	var welcome_bytes := AudioDirector._make_chime_wav("welcome").data.size()
	var warm_bytes := AudioDirector._make_chime_wav("warm").data.size()
	assert_int(welcome_bytes).is_not_equal(warm_bytes)

	# Walk the episode to the handover and check what the invitation played.
	Game.dispatch("observe")
	Game.dispatch("ball_kicked")
	Game.dispatch("ball_landed")
	Game.dispatch("ball_picked_up")
	AudioDirector._chime_player.stop()
	assert_bool(Game.dispatch("ball_returned")).is_true()
	await runner.simulate_frames(2)
	assert_int(AudioDirector._chime_player.stream.data.size()) \
		.override_failure_message("the invitation did not play the welcome cue") \
		.is_equal(welcome_bytes)

	# ...and that going home still plays the warm one, not the invitation's.
	Game.dispatch("joined")
	AudioDirector._chime_player.stop()
	assert_bool(Game.dispatch("entered_home")).is_true()
	await runner.simulate_frames(2)
	assert_int(AudioDirector._chime_player.stream.data.size()).is_equal(warm_bytes)
