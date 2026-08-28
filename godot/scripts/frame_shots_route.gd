extends SceneTree
## frame_shots_route.gd -- the Gate 0 frame's own evidence tool, alongside
## screenshot_route.gd's six story-beat shots: captures S0 (boot), S1
## (title), S6 (ending), S7 (credits) and S8 (pause) at the real play
## camera. See tools/frame_shots.ps1 for the exact invocation.
##
## Must run WITHOUT --headless -- same reason as screenshot_route.gd:
## headless never renders a frame to capture. Built on the same proven
## machinery (GdUnitSceneRunnerImpl instantiated directly, the same
## null-runner-then-quit() shutdown dance) -- see that file's own doc
## comment for why each piece is there; not re-explained per line here.
##
## Reaches the episode's COMPLETE state the same way
## tests/play/test_ending_screen.gd does: Game.dispatch() directly,
## bypassing DriveRoute/walking entirely (dispatch() never checks the
## player's actual position, only interact() does) -- this tool only needs
## the STATE to change, not a faithful walkthrough (screenshot_route.gd
## already is that).

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://frame_shots"
const MAX_WAIT_TICKS := 400

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _game: Node = null  # see screenshot_route.gd's own doc comment on why get_node(), not the bare identifier
var _shot_index: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)

	_main = _runner.scene()
	if _main == null:
		push_error("frame_shots_route: failed to load/instantiate %s" % SCENE_PATH)
		_shutdown(1)
		return
	_game = get_root().get_node("Game")

	# --- S0: boot, wordmark up alone on black, menu not yet in -----------------
	# title_card.gd's _play_boot_sequence: 0.35s hold, eyebrow fades 0.35-0.8s,
	# wordmark fades 0.8-1.35s, THEN (only after both finish) a 0.2s wait
	# before the menu/hint start their own fade -- 80 ticks (1.33s) lands
	# right as the wordmark finishes but before the menu has started.
	await _settle_ticks(80)
	await _capture("s0_boot")

	# --- S1: title settled over the live, drifting world ---------------------
	await _settle_ticks(150)  # well past the boot sequence's own fades
	await _capture("s1_title")

	# --- S6: the ending, sill populated so the shot demonstrates 0..3 (the
	# pickup mechanic itself isn't built yet -- see Game.treasures_found's
	# own doc comment; this only proves the render path, same as the unit
	# test does numerically). ------------------------------------------------
	# Real-time waits below (OBSERVED's 2.6s auto ball_kicked, the ball's
	# own 1.8s flight tween) at Engine.time_scale 1.0 proved unreliable
	# under this harness -- both test_ending_screen.gd and
	# test_playthrough.gd already accelerate the identical sequence via
	# Engine.time_scale 8.0 rather than waiting it out at real speed; same
	# fix here.
	Engine.time_scale = 8.0
	_game.set_treasures_found(3)
	# start_episode() called directly rather than through TitleCard's own
	# Play button (which is what actually hides it) -- same shortcut
	# tests/play/test_ending_screen.gd takes, since dispatch() doesn't care
	# how the episode started. Hide it explicitly here to match what a real
	# Play press would have already done by this point.
	_main.get_node("TitleCard").visible = false
	_game.start_episode(0.0)
	await _settle_ticks(4)
	_dispatch("observe")
	await _wait_while_state(EpisodeDirector.State.OBSERVED)
	await _wait_while_state(EpisodeDirector.State.BALL_IN_FLIGHT)
	_dispatch("ball_picked_up")
	_dispatch("ball_returned")
	_dispatch("joined")
	_dispatch("entered_home")
	await _wait_until_visible(_main.get_node("EndingScreen"))
	Engine.time_scale = 1.0  # back to real speed for the ending's own authored fades/hold
	await _settle_ticks(150)  # past the sill/line-text reveal, well before the hold ends
	await _capture("s6_ending")

	# --- S7: credits ----------------------------------------------------------
	_main.get_node("TitleCard").visible = false
	_main.get_node("EndingScreen").visible = false
	_game.credits_screen.show_credits()
	await _settle_ticks(40)
	await _capture("s7_credits")
	_main.get_node("CreditsScreen").visible = false

	# --- S8: pause, mid-gameplay -----------------------------------------------
	_game.start_episode(0.0)
	await _settle_ticks(30)
	_runner.simulate_action_press("ui_cancel")
	_runner.simulate_action_release("ui_cancel")
	await _settle_ticks(30)
	await _capture("s8_pause")

	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	if _failures.is_empty():
		print("frame_shots_route: all shots captured cleanly.")
		_shutdown(0)
	else:
		push_error("frame_shots_route: %d shot(s) look broken: %s" % [_failures.size(), ", ".join(_failures)])
		_shutdown(1)


## Same PREDELETE/double-free hazard screenshot_route.gd's own doc comment
## explains -- see that file for the full account.
func _shutdown(code: int) -> void:
	_runner = null
	Engine.remove_meta("GdUnitSceneRunner")
	quit(code)


func _dispatch(event_name: String) -> void:
	if not _game.dispatch(event_name):
		push_error("frame_shots_route: dispatch(%s) rejected in state %s" % [event_name, _game.director.state])


func _wait_while_state(state: String) -> void:
	var waited := 0
	while _game.director.state == state and waited < MAX_WAIT_TICKS:
		await physics_frame
		waited += 1


func _wait_until_visible(node: Node) -> void:
	var waited := 0
	while not node.visible and waited < MAX_WAIT_TICKS:
		await physics_frame
		waited += 1


func _settle_ticks(n: int) -> void:
	for _i in range(n):
		await physics_frame


func _capture(beat_name: String) -> void:
	_shot_index += 1
	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		_failures.append("%s (no image)" % beat_name)
		push_error("frame_shots_route: %s produced no image" % beat_name)
		return

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var rel_path := "%s/%02d_%s.png" % [OUT_DIR, _shot_index, beat_name]
	var err := img.save_png(rel_path)
	if err != OK:
		_failures.append("%s (save_png error %d)" % [beat_name, err])
		push_error("frame_shots_route: save_png(%s) failed: %d" % [rel_path, err])
		return
	print("[%s] -> %s" % [beat_name, ProjectSettings.globalize_path(rel_path)])
