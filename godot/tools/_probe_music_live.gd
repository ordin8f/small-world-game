extends SceneTree

## Measures the music through Godot's OWN mixer, rather than through the
## offline model in _probe_music.gd.
##
## _probe_music.gd renders the music by calling the real synthesis functions
## and then mixing them itself. That covers the waveforms, the gains and the
## scheduler, but it does not cover Godot: the resampling of the detuned
## twins' pitch_scale, the per-buffer volume_db interpolation, and the summing
## of twenty-two AudioStreamPlayers. This reads AudioServer's own master-bus
## peak meter while the real scene runs, so what it reports is what the engine
## actually put on the bus.
##
## Run it non-headless -- the dummy audio driver used by --headless still mixes
## but reports nothing on the meter:
##   godot --path godot --script res://tools/_probe_music_live.gd
##
## Prints the bus peak over time at each of the three moods, plus muted and
## paused, and fails loudly if the bus is silent when it should not be.

const SCENE_PATH := "res://scenes/main.tscn"
const SAMPLE_INTERVAL_MS := 100


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	var node: Node = scene.instantiate()
	root.add_child(node)
	for _i in range(4):
		await process_frame

	var game: Node = root.get_node_or_null("Game")
	var audio: Node = root.get_node_or_null("AudioDirector")
	if game == null or audio == null:
		push_error("music_live: autoloads missing")
		quit(1)
		return

	game.call("start_episode", 0.0)
	await process_frame
	print("pad players: %d, melody players: %d, children: %d"
		% [audio.get("_pad_players").size(), audio.get("_melody_players").size(),
			audio.get_child_count()])

	# Let the fade-in finish before measuring anything.
	await _hold(6.0, "")

	for entry in [["afternoon", 0.0], ["golden", 0.5], ["dusk", 1.0]]:
		audio.call("set_music_mood", float(entry[1]))
		await _hold(9.0, entry[0])

	game.set("muted", true)
	await _hold(4.0, "muted")
	game.set("muted", false)
	await _hold(4.0, "unmuted")

	audio.call("duck", true)
	await _hold(4.0, "paused (ducked)")
	audio.call("duck", false)

	# Free the scene before quitting, or Godot reports the whole tree as
	# leaked ObjectDB instances on the way out.
	root.remove_child(node)
	node.queue_free()
	await process_frame
	quit(0)


## Samples the master bus peak for `seconds` of real time and reports the
## distribution. Peak, not RMS: the bus meter is a peak meter.
func _hold(seconds: float, label: String) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	var next := 0
	var peaks: Array = []
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if Time.get_ticks_msec() < next:
			continue
		next = Time.get_ticks_msec() + SAMPLE_INTERVAL_MS
		var left := AudioServer.get_bus_peak_volume_left_db(0, 0)
		var right := AudioServer.get_bus_peak_volume_right_db(0, 0)
		peaks.append(maxf(left, right))
	if label == "" or peaks.is_empty():
		return

	peaks.sort()
	var sum := 0.0
	for p in peaks:
		sum += p
	print("  %-16s n=%3d  min=%8.2f  median=%8.2f  max=%8.2f  mean=%8.2f dBFS"
		% [label, peaks.size(), peaks[0], peaks[peaks.size() / 2],
			peaks[peaks.size() - 1], sum / float(peaks.size())])
