extends SceneTree
## Gate 1 (mechanics agent): windowed screenshot capture for the four new
## mechanics -- imagination transforms, pocket treasures, NPC talk, and
## swing/sandbox. Same technique and structure as scripts/verb_shots.gd
## (in-engine Viewport capture; headless never renders a frame to grab;
## drives player.gd directly by teleport + simulated input rather than
## walking DriveRoute waypoints), kept as its own file rather than added
## onto verb_shots.gd so the two "what verbs exist" screenshot tools stay
## independently owned and mergeable.
##
## Must run WITHOUT --headless. Usage:
##   godot --path godot --script res://scripts/mechanics_shots.gd --resolution 1280x720

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://mechanics_shots"

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _player: Node3D = null
var _game: Node = null
var _shot_index: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)
	_main = _runner.scene()
	if _main == null:
		push_error("mechanics_shots: failed to load/instantiate %s" % SCENE_PATH)
		_shutdown(1)
		return

	_hide_ui()
	_game = get_root().get_node("Game")
	_player = _game.player
	if not is_instance_valid(_player):
		push_error("mechanics_shots: Game.player is null after scene load")
		_shutdown(1)
		return

	_game.start_episode(0.0)
	_hide_ui()
	for _i in range(150):
		await physics_frame

	# start_episode() alone does NOT activate the play camera -- only
	# title_card.gd's "Begin the afternoon" button does, via
	# Game.title_camera.glide_to_gameplay() (see that file's own doc
	# comment). Without this, title_camera.gd's OWN Camera3D stays
	# `current` (show_title() sets that unconditionally in _ready()) and
	# every capture below would silently show its fixed title anchor
	# framing instead of the real gameplay camera, regardless of where the
	# player/NPCs actually are. Found by inspecting a first capture pass:
	# every shot showed the identical chalk-circle title frame no matter
	# which mechanic or position was being captured.
	if is_instance_valid(_game.title_camera):
		await _game.title_camera.glide_to_gameplay()

	await _shoot_imagination_props()
	await _shoot_pocket_treasures()
	await _shoot_npc_talk()
	await _shoot_swing()
	await _shoot_sandbox()

	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	_shutdown(0)


# --------------------------------------------------------- imagination props --

func _shoot_imagination_props() -> void:
	var crate: Node3D = _main.find_child("CrateProp", true, false)
	var bench: Node3D = _main.find_child("BenchProp", true, false)
	if crate == null or bench == null:
		push_error("mechanics_shots: CrateProp/BenchProp not found")
		return

	_player.global_position = crate.global_position + Vector3(0.0, 0.0, 1.3)
	await _wait_ticks(30)
	await _capture("imagination_crate_before")
	_game.interact()
	await _wait_ticks(45)
	await _capture("imagination_crate_castle")

	_player.global_position = bench.global_position + Vector3(0.0, 0.0, 1.3)
	await _wait_ticks(30)
	_game.interact()
	await _wait_ticks(45)
	await _capture("imagination_bench_boat")


# ------------------------------------------------------------ pocket treasures --

func _shoot_pocket_treasures() -> void:
	var marble: Node3D = _main.find_child("Marble", true, false)
	if marble == null:
		push_error("mechanics_shots: Marble not found")
		return

	_player.global_position = marble.global_position + Vector3(0.0, 0.0, 0.8)
	await _wait_ticks(30)
	await _capture("treasure_marble_before")
	_game.interact()
	await _wait_ticks(20)
	await _capture("treasure_marble_picked_up")

	# Force the ending screen's sill to show all three, the same way it
	# will look after a real playthrough finds every treasure -- proves
	# Game.treasures_found actually reaches ending_screen.gd, not just
	# that the pickup itself fires.
	_game.set_treasures_found(3)
	var ending: Node = _main.find_child("EndingScreen", true, false)
	if ending != null:
		ending.visible = true
		ending.call("_update_sill")
		# Also fade the sill's own icon panels in -- _update_sill() only sets
		# .visible, the fade-in is ending_screen.gd's own _reveal_sill_icons()
		# coroutine (triggered by the real episode_complete flow, not by
		# calling _update_sill() directly), so without this the icons would
		# be at their default modulate.a and might not read as "revealed" --
		# cheap enough to just set directly here rather than reaching into
		# that private coroutine.
		for icon: Panel in ending.get("treasures"):
			icon.modulate.a = 1.0
		ending.get_node("Frame").modulate.a = 1.0
		ending.get_node("Sill").modulate.a = 1.0
		await _wait_ticks(10)
		await _capture("treasure_sill_all_three", false)
		ending.visible = false


# ------------------------------------------------------------------- NPC talk --

func _shoot_npc_talk() -> void:
	var mina: Node3D = _main.find_child("Mina", true, false)
	var arun: Node3D = _main.find_child("Arun", true, false)
	var priya: Node3D = _main.find_child("Priya", true, false)
	if mina == null or arun == null or priya == null:
		push_error("mechanics_shots: Mina/Arun/Priya not found")
		return

	_player.global_position = mina.global_position + Vector3(-1.3, 0.0, 0.8)
	await _wait_ticks(30)
	_game.interact()
	await _wait_ticks(60)
	await _capture("npc_mina_turns")

	# South of Arun, not east -- east is within Priya's own INTERACT_RADIUS
	# too (their spawns are only ~0.8m apart) and closer to her than to
	# Arun, so Game.interact() there would talk to her instead -- same fix
	# as tests/play/test_npc_talk.gd's own comment on this.
	_player.global_position = arun.global_position + Vector3(0.0, 0.0, -1.3)
	await _wait_ticks(30)
	_game.interact()
	_player.global_position = arun.global_position + Vector3(0.0, 0.0, 2.5)
	await _wait_ticks(70)
	await _capture("npc_arun_follows")

	_player.global_position = priya.global_position + Vector3(1.3, 0.0, 0.0)
	await _wait_ticks(30)
	_game.interact()
	await _wait_ticks(120)
	await _capture("npc_priya_wanders_to_slide")


# ----------------------------------------------------------------------- swing --

func _shoot_swing() -> void:
	var swing: Node3D = _main.find_child("Swing", true, false)
	if swing == null:
		push_error("mechanics_shots: Swing not found")
		return

	# Within Swing.MOUNT_RADIUS (1.3) -- the earlier 1.5 offset sat just
	# outside it, so Game.interact() silently found nothing and the
	# player just walked normally for the rest of this beat instead of
	# actually mounting.
	_player.global_position = swing.global_position + Vector3(0.0, 0.0, 1.0)
	await _wait_ticks(30)
	await _capture("swing_before")
	_game.interact()  # mount
	await _wait_ticks(10)
	await _capture("swing_mounted")

	_runner.simulate_action_press("move_forward")
	await _wait_ticks(150)
	await _capture("swing_pumping")
	_runner.simulate_action_release("move_forward")
	await _wait_ticks(20)

	_game.interact()  # dismount
	await _wait_ticks(20)
	await _capture("swing_dismounted")


# --------------------------------------------------------------------- sandbox --

func _shoot_sandbox() -> void:
	var sandbox: Node3D = _main.find_child("Sandbox", true, false)
	if sandbox == null:
		push_error("mechanics_shots: Sandbox not found")
		return

	_player.global_position = sandbox.global_position
	await _wait_ticks(30)
	await _capture("sandbox_before")

	# Spread a few mounds from different standing spots inside the pit --
	# "where you stand matters", not one authored layout.
	var spots := [Vector3(0.7, 0.0, 0.0), Vector3(-0.7, 0.0, 0.6), Vector3(0.0, 0.0, -0.8)]
	for offset in spots:
		_player.global_position = sandbox.global_position + offset
		await _wait_ticks(15)
		_game.interact()
		await _wait_ticks(25)
	await _capture("sandbox_building")

	# Finish the castle -- two more mounds reaches MAX_MOUNDS and plants the flag.
	for offset in [Vector3(0.6, 0.0, -0.6), Vector3(-0.5, 0.0, -0.9)]:
		_player.global_position = sandbox.global_position + offset
		await _wait_ticks(15)
		_game.interact()
		await _wait_ticks(25)
	await _wait_ticks(20)
	await _capture("sandbox_flag_planted")


# --------------------------------------------------------------------- helpers --

func _shutdown(code: int) -> void:
	_runner = null
	Engine.remove_meta("GdUnitSceneRunner")
	quit(code)


func _wait_ticks(n: int) -> void:
	for _i in range(n):
		await physics_frame


## `hide_ui`=false for the one shot that WANTS a CanvasLayer up
## (treasure_sill_all_three, showing ending_screen.gd's own tokens) --
## _hide_ui() hides every CanvasLayer indiscriminately, which would
## otherwise immediately re-hide a screen this same script just made
## visible on purpose.
func _capture(beat_name: String, hide_ui: bool = true) -> void:
	if hide_ui:
		_hide_ui()
	for _i in range(20):
		await physics_frame

	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("mechanics_shots: %s produced no image" % beat_name)
		return

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_shot_index += 1
	var rel_path := "%s/%02d_%s.png" % [OUT_DIR, _shot_index, beat_name]
	var err := img.save_png(rel_path)
	if err != OK:
		push_error("mechanics_shots: save_png(%s) failed: %d" % [rel_path, err])
		return

	var abs_path := ProjectSettings.globalize_path(rel_path)
	var p := _player.global_position
	print("[%s] player=(%.2f, %.2f, %.2f) -> %s" % [beat_name, p.x, p.y, p.z, abs_path])


func _hide_ui() -> void:
	_hide_canvas_layers_recursive(_main)


func _hide_canvas_layers_recursive(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child in node.get_children():
		_hide_canvas_layers_recursive(child)
