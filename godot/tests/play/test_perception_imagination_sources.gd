extends GdUnitTestSuite
## Gate 1 (mechanics agent): regression guard for perception.gd's
## _imagination_sources fix. Before that fix, set_imagination_target()
## stored one plain bool -- fine with only stepping_stones.gd calling it,
## but imagination_prop.gd's flagged props (crate/bench, elsewhere in the
## world) drive the exact same channel, and two independent pollers each
## writing a single shared bool would have the later one each tick silently
## override the earlier one's "on". This test drives the multi-source path
## directly (two distinct source ids) rather than asserting on stepping
## stones/imagination_prop specifically, so it stays a guard on the shared
## channel's own contract even if either caller's own geometry changes.

const EPSILON := 0.02


func _find_perception(runner) -> Node:
	return runner.scene().find_child("Perception", true, false)


func test_cue_stays_active_until_every_source_releases_it() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var perception := _find_perception(runner)
	assert_object(perception).is_not_null()
	var tree := Engine.get_main_loop() as SceneTree

	perception.call("set_imagination_target", true, "source_a")
	perception.call("set_imagination_target", true, "source_b")
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_greater(0.5)

	# Releasing only ONE of the two active sources must NOT drop the cue --
	# this is exactly the stomping bug the fix guards against: a naive
	# single-bool implementation would zero out here.
	perception.call("set_imagination_target", false, "source_a")
	for _i in range(20):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_greater(0.5)

	# Releasing the LAST active source lets it ease back down.
	perception.call("set_imagination_target", false, "source_b")
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_less(0.05)


func test_default_source_matches_stepping_stones_own_single_arg_call() -> void:
	# stepping_stones.gd calls set_imagination_target(active) with no second
	# argument -- the default must resolve to a real, functioning source id,
	# not silently do nothing.
	#
	# stepping_stones.gd's own poller is ALSO alive in this scene and ALSO
	# calls set_imagination_target() with the same omitted-argument default
	# source, every physics tick, based on the player's actual position --
	# same reasoning scripts/verb_shots.gd's own isolated-imagination-cue
	# shot already documents ("isolate: stop its own poller fighting the
	# override below"). Without disabling it here, its own per-tick
	# `false` (the player never left its default spawn, nowhere near the
	# stepping stones) immediately re-erases the "default" key this test
	# just set, one tick after this test sets it -- not a bug in the
	# shared channel, just two callers of the literal same source id.
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var perception := _find_perception(runner)
	var stepping_stones: Node = runner.scene().find_child("SteppingStones", true, false)
	assert_object(stepping_stones).is_not_null()
	stepping_stones.set_physics_process(false)
	var tree := Engine.get_main_loop() as SceneTree

	perception.call("set_imagination_target", true)
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_greater(0.5)

	perception.call("set_imagination_target", false)
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_less(0.05)
