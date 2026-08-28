extends GdUnitTestSuite
## Camera-fix task (2026-08-28): drag-to-look, restored from src/game.mjs's
## pointerdown/pointermove drag-look (camera_rig.gd's own class doc comment
## has the full history -- the original Godot port dropped it entirely).
##
## HONEST LIMIT: real mouse-look cannot be verified end-to-end in a headless
## run -- Godot's own InputEvents (real OS-level mouse motion) never reach a
## `--headless` process, and no screenshot can be taken here either
## (screenshot_route.gd's own doc comment: headless never renders a frame).
## What CAN be verified headlessly, and is verified below: gdUnit4's
## SceneRunner synthesizes real InputEventMouseButton/InputEventMouseMotion
## and pushes them through the actual Input singleton and the actual
## CameraRig._unhandled_input() -- so this exercises the real drag-state
## machinery and the real springback damping, just without a rendered frame
## to look at. Visual confirmation (does it actually LOOK right while
## dragging) is a windowed-build, human-eyes check -- see the camera-fix
## task's own report for what was and wasn't confirmed that way.
##
## _look_yaw/_drag_active are accessed directly (no underscore-hiding in
## GDScript) rather than inferred from camera.global_position -- the
## position is several steps removed (yaw -> back/lat -> raw_offset ->
## possibly the home-zone pull-in -> damped _smoothed_desired -> spring
## length), so asserting on it would also be asserting on all of that
## machinery's timing, not on whether the drag itself works.


func after_test() -> void:
	# Game.reduced_motion is autoload-global -- always restore it, pass or
	# fail, same reasoning as test_dispatch_and_zones.gd's own
	# Engine.time_scale restore.
	Game.reduced_motion = false


func test_drag_rotates_look_yaw_and_it_springs_back_on_release() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let CameraRig/Player _ready() run
	var camera_rig: Node = runner.find_child("CameraRig")
	assert_object(camera_rig).is_not_null()
	assert_float(camera_rig.get("_look_yaw")).is_equal(0.0)

	runner.set_mouse_position(Vector2(640, 360))
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_bool(camera_rig.get("_drag_active")).is_true()

	# Several rightward drag steps -- game.mjs:322's own sign convention,
	# ported verbatim into camera_rig.gd's _unhandled_input: dragging the
	# mouse right (positive relative.x) DECREASES look_yaw. Several small
	# moves rather than one big jump so the accumulated total isn't
	# swallowed entirely by the LOOK_YAW_LIMIT clamp before this assertion
	# even gets to check the sign/magnitude relationship.
	for i in range(6):
		runner.simulate_mouse_move(Vector2(640 + (i + 1) * 60, 360))
		await runner.await_input_processed()

	var dragged_yaw: float = camera_rig.get("_look_yaw")
	# Strictly negative (the sign game.mjs:322 dictates for a rightward
	# drag) and strictly within the ported clamp -- not merely "changed",
	# which a sign error could still satisfy.
	assert_float(dragged_yaw).is_less(0.0)
	assert_float(dragged_yaw).is_greater_equal(-0.36 - 0.001)

	# Springback engages the moment the button releases (camera_rig.gd's
	# own `if not _drag_active or Game.reduced_motion`) -- give it enough
	# PHYSICS ticks to meaningfully decay (lambda 2.0 halves the remaining
	# error roughly every 0.35s; simulate_frames() awaits idle frames, which
	# in this headless sandbox tick far faster than physics -- see
	# test_player_movement.gd's own doc comment -- so the frame budget here
	# is generous specifically to make sure enough real 60Hz physics ticks
	# land underneath, not because 240 idle frames is itself 4 seconds).
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_bool(camera_rig.get("_drag_active")).is_false()

	await runner.simulate_frames(240)
	var settled_yaw: float = camera_rig.get("_look_yaw")
	assert_float(absf(settled_yaw)).is_less(absf(dragged_yaw))


func test_reduced_motion_disables_the_drag_look() -> void:
	Game.reduced_motion = true
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var camera_rig: Node = runner.find_child("CameraRig")
	assert_object(camera_rig).is_not_null()

	runner.set_mouse_position(Vector2(640, 360))
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	for i in range(6):
		runner.simulate_mouse_move(Vector2(640 + (i + 1) * 60, 360))
		await runner.await_input_processed()
	# A few physics ticks so the springback (which reduced motion forces
	# even while "dragging" -- camera_rig.gd's own `or Game.reduced_motion`)
	# has a chance to run at all, matching the source's own
	# `if (!dragActive || reducedMotion) return` in the pointermove handler.
	await runner.simulate_frames(10)

	assert_float(camera_rig.get("_look_yaw")).is_equal(0.0)
