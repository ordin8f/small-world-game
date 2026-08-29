extends GdUnitTestSuite
## Gate 0 play tests for player.gd's new verbs -- same
## scene_runner("res://scenes/player.tscn") pattern test_player_movement.gd
## uses (no Game/episode dependency: these verbs trigger purely from
## world_affordances.gd position checks, not episode state).

const MAX_TICKS := 300


func test_walking_into_the_tower_climbs_slides_and_lands_back_on_the_ground() -> void:
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	player.global_position = WorldAffordances.CLIMB_TRIGGER

	await runner.simulate_frames(2)
	assert_int(player.verb).is_equal(player.Verb.CLIMBING)

	var reached_platform := await _wait_for_verb(runner, player, player.Verb.ON_PLATFORM)
	assert_bool(reached_platform).is_true()
	assert_float(player.global_position.y).is_equal_approx(WorldAffordances.PLATFORM_TOP_Y, 0.01)

	# Walk toward the slide's south edge -- at this REVEAL-zone yaw, "back"
	# is the key that moves the player in world +z, away from the tower.
	runner.simulate_action_press("move_back")
	var started_sliding := await _wait_for_verb(runner, player, player.Verb.SLIDING)
	runner.simulate_action_release("move_back")
	assert_bool(started_sliding).is_true()

	var landed := await _wait_for_verb(runner, player, player.Verb.GROUND)
	assert_bool(landed).is_true()
	assert_float(player.global_position.y).is_equal_approx(0.0, 0.01)
	# Ended up clear of the tower's own collider footprint, out in the
	# open courtyard -- not still stuck inside/under the platform.
	assert_float(player.global_position.z).is_greater(WorldAffordances.TOWER_Z + WorldAffordances.TOWER_FOOTPRINT_HALF)


func test_walking_onto_the_garden_edging_balances_slower_and_never_fails_to_step_off() -> void:
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	# Just clear of the edging's own physical thickness (half 0.15) but
	# still inside WorldAffordances' 0.55 mount range. The balance verb
	# moved off the tall playground/garden-pocket boundary wall onto a low
	# brick edging around a planting bed by the home threshold
	# (world_affordances.gd's own doc comment has the developer's own
	# words on why). z=13.2 sits near the far end of the edging's own run
	# (10.45..13.65) -- this test walks toward z_min, and the 2.75 m of
	# room from there is the most the run's own 3.2 m length can offer,
	# well short of a full wall's worth (the old wall's own equivalent
	# test held 3.0 m inside a 7 m run).
	player.global_position = Vector3(-4.15, 0.0, 13.2)

	await runner.simulate_frames(2)
	assert_int(player.verb).is_equal(player.Verb.WALL_MOUNTING)

	var mounted := await _wait_for_verb(runner, player, player.Verb.WALL_WALKING)
	assert_bool(mounted).is_true()
	assert_float(player.global_position.y).is_equal_approx(WorldAffordances.EDGING_TOP_Y, 0.01)

	# Walking the top is slower than the baseline walk speed -- "should slow
	# the player" per the brief -- not a stall, just unhurried. Measured
	# over 20 frames rather than the old wall test's 60: this run is under
	# half that test's own length, and gdUnit4's simulate_frames() steps by
	# idle (process) frames, not a fixed physics delta, so the actual
	# distance covered per simulated frame isn't perfectly 1:1 with the
	# physics tick -- 20 keeps this comfortably inside the run's own 2.75 m
	# of available space even with a generous margin for that ratio, while
	# still comfortably clearing the `moved > 0.05` floor below.
	var z_before: float = player.global_position.z
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(20)
	runner.simulate_action_release("move_forward")
	var moved: float = absf(player.global_position.z - z_before)
	assert_float(moved).is_greater(0.05)  # actually moved
	assert_float(moved).is_less(player.walk_speed * 0.9)  # but slower than baseline walking
	assert_bool(player.verb == player.Verb.WALL_WALKING).is_true()  # still up there -- no random fail

	# A sustained sideways push steps the player back down -- deliberate,
	# player-driven, and never punishing: just the ground again.
	runner.simulate_action_press("move_right")
	var dismounted := await _wait_for_verb(runner, player, player.Verb.GROUND)
	runner.simulate_action_release("move_right")
	assert_bool(dismounted).is_true()
	assert_float(player.global_position.y).is_equal_approx(0.0, 0.01)

	# Regression: stepping off must actually leave. An earlier version
	# landed the dismount inside WorldAffordances.EDGING_MOUNT_X_RANGE, so
	# the very next GROUND tick's trigger check silently re-mounted the
	# player -- "stepping off" did nothing observable from outside a
	# single-frame check. Give it a couple of seconds with no input at all
	# and confirm it does NOT climb back on by itself.
	for _i in range(120):
		await runner.simulate_frames(1)
	assert_bool(player.verb == player.Verb.GROUND).is_true()
	assert_float(player.global_position.y).is_equal_approx(0.0, 0.01)


func test_walking_off_the_end_of_the_edging_dismounts_just_as_gently() -> void:
	# The OTHER way off the edging -- not a deliberate sideways lean, but
	# simply walking to where its one run (WorldAffordances.EDGING_SEGMENTS,
	# z 10.45..13.65) runs out. Same non-punishing landing: no fail state,
	# just the ground again.
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	player.global_position = Vector3(-4.15, 0.0, 13.15)  # near the run's z_max=13.65 end
	await runner.simulate_frames(2)
	await _wait_for_verb(runner, player, player.Verb.WALL_WALKING)

	# "move_back" is the key that increases world z at this yaw -- toward
	# the 13.65 end and off it (same direction sense THRESHOLD and REVEAL
	# share -- both authored_yaw values are small negative angles, see
	# CameraProfile.profile()).
	runner.simulate_action_press("move_back")
	var dismounted := await _wait_for_verb(runner, player, player.Verb.GROUND)
	runner.simulate_action_release("move_back")

	assert_bool(dismounted).is_true()
	assert_float(player.global_position.y).is_equal_approx(0.0, 0.01)
	# Walked off the far end, not teleported to the near one.
	assert_float(player.global_position.z).is_greater(13.55)


func test_cosmetic_wobble_alone_never_causes_a_fall() -> void:
	# The wobble applied to character_visual.rotation.z must be purely
	# decorative: standing still and balanced (no sideways input at all)
	# must never, by itself, cross the dismount threshold.
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	player.global_position = Vector3(-4.15, 0.0, 13.2)
	await runner.simulate_frames(2)
	await _wait_for_verb(runner, player, player.Verb.WALL_WALKING)

	for _i in range(180):  # 3s of real-time-equivalent ticks, no input held
		await runner.simulate_frames(1)

	assert_bool(player.verb == player.Verb.WALL_WALKING).is_true()


func _wait_for_verb(runner: GdUnitSceneRunner, player: CharacterBody3D, verb: int) -> bool:
	for _i in range(MAX_TICKS):
		if player.verb == verb:
			return true
		await runner.simulate_frames(1)
	return player.verb == verb
