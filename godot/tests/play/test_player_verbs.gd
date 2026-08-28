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


func test_walking_onto_the_garden_wall_balances_slower_and_never_fails_to_step_off() -> void:
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	# Just clear of the wall's own physics collider (half_x 0.35 + player
	# radius 0.32 = 0.67) but still inside WorldAffordances' 0.75 mount
	# range. WALL_X relocated to 11.0 for the 2026-08-28 world expansion
	# (world_bounds.gd's own doc comment); z=-13.0 sits well inside the
	# deep segment (-16..-9), same relative spot the single-room version's
	# z=-6.0 held inside its own (-8..-3.8) segment.
	player.global_position = Vector3(10.3, 0.0, -13.0)

	await runner.simulate_frames(2)
	assert_int(player.verb).is_equal(player.Verb.WALL_MOUNTING)

	var mounted := await _wait_for_verb(runner, player, player.Verb.WALL_WALKING)
	assert_bool(mounted).is_true()
	assert_float(player.global_position.y).is_equal_approx(WorldAffordances.WALL_TOP_Y, 0.01)

	# Walking the top is slower than the baseline walk speed -- "should slow
	# the player" per the brief -- not a stall, just unhurried.
	var z_before: float = player.global_position.z
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(60)
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
	# landed the dismount inside WorldAffordances.WALL_MOUNT_X_RANGE, so
	# the very next GROUND tick's trigger check silently re-mounted the
	# player -- "stepping off" did nothing observable from outside a
	# single-frame check. Give it a couple of seconds with no input at all
	# and confirm it does NOT climb back on by itself.
	for _i in range(120):
		await runner.simulate_frames(1)
	assert_bool(player.verb == player.Verb.GROUND).is_true()
	assert_float(player.global_position.y).is_equal_approx(0.0, 0.01)


func test_walking_off_the_end_of_a_wall_segment_dismounts_just_as_gently() -> void:
	# The OTHER way off the wall -- not a deliberate sideways lean, but
	# simply walking to where the segment (WorldAffordances.WALL_SEGMENTS'
	# first entry, z -16.0..-9.0 as of the 2026-08-28 world expansion) runs
	# out, toward the garden-gap opening. Same non-punishing landing: no
	# fail state, just the ground again.
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	player.global_position = Vector3(10.3, 0.0, -9.5)  # near the segment's z_max=-9.0 end
	await runner.simulate_frames(2)
	await _wait_for_verb(runner, player, player.Verb.WALL_WALKING)

	# "move_back" is the key that increases world z at this yaw -- toward
	# the -9.0 end and off it.
	runner.simulate_action_press("move_back")
	var dismounted := await _wait_for_verb(runner, player, player.Verb.GROUND)
	runner.simulate_action_release("move_back")

	assert_bool(dismounted).is_true()
	assert_float(player.global_position.y).is_equal_approx(0.0, 0.01)
	# Walked off the near end, not teleported to the far one.
	assert_float(player.global_position.z).is_greater(-9.1)


func test_cosmetic_wobble_alone_never_causes_a_fall() -> void:
	# The wobble applied to character_visual.rotation.z must be purely
	# decorative: standing still and balanced (no sideways input at all)
	# must never, by itself, cross the dismount threshold.
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	player.global_position = Vector3(10.3, 0.0, -13.0)
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
