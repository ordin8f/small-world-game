extends Node
## Game — top-level orchestration autoload.
##
## M0: exposes debug_state() with placeholder values so DebugBridge and
## DebugOverlay have a stable shape to read from. M2 (episode_director.gd +
## emotional_lens.gd) replaces the placeholders with real state -- the shape
## (keys below) is deliberately final now so M0's bridge/overlay work does
## not need to change later. Player position mirrors whatever node the game
## currently considers "the player" (null until M1.3). Camera likewise
## mirrors the active play camera (null until M1.4).

var player: Node3D = null
var camera: Camera3D = null


func _ready() -> void:
	pass


func debug_state() -> Dictionary:
	var player_pos := Vector3.ZERO
	if is_instance_valid(player):
		player_pos = player.global_position

	var camera_pos = null
	if is_instance_valid(camera):
		var c := camera.global_position
		camera_pos = {"x": c.x, "y": c.y, "z": c.z}

	return {
		"state": "N/A (M0 stub)",
		"beat_index": -1,
		"player_pos": {"x": player_pos.x, "y": player_pos.y, "z": player_pos.z},
		"comfort": null,
		"energy": null,
		"curiosity": null,
		"dominant_emotion": "N/A (M0 stub)",
		"camera_pos": camera_pos,
	}
