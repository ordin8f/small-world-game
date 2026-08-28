class_name PocketTreasure
extends Node3D
## Gate 1 (mechanics agent): findable keepsakes -- "three of them, placed
## to reward looking rather than following the objective." Free-roam
## interactable (Game.free_interactables), never gated on director.state,
## same as imagination_prop.gd/NPC talk.
##
## docs/PRODUCT_CONTRACT.md bans collectibles and scoring outright, so this
## is deliberately NOT a collectible: no counter, no HUD tally, no "2/3"
## anywhere, no completion prompt for finding all three. Picking one up
## plays one small authored line (Game.dialogue_shown, the same signal
## every other line in the game already uses) and increments
## Game.treasures_found -- a plain int scripts/ui/ending_screen.gd already
## renders as 0..3 tokens on the sill (see that file's own doc comment: it
## was written and tested before anything ever set the count above zero).
## Nothing here reads that count back or displays it during play.

const KIND_DATA := {
	"Marble": {
		"shape": "sphere",
		"color": Color(0.32, 0.5, 0.78),
		"scale": Vector3(0.09, 0.09, 0.09),
		"line": "A marble. It still has a bit of shine.",
	},
	"Stone": {
		# Flattened sphere -- same "a squashed sphere reads as a stone"
		# convention tools/_bootstrap_courtyard.gd already uses for the
		# stepping stones themselves.
		"shape": "sphere",
		"color": Color(0.55, 0.53, 0.5),
		"scale": Vector3(0.13, 0.06, 0.11),
		"line": "A good flat stone. Perfect for skipping.",
	},
	"Feather": {
		"shape": "box",
		"color": Color(0.86, 0.78, 0.5),
		"scale": Vector3(0.03, 0.16, 0.05),
		"line": "A feather, soft at the edges.",
	},
}

const INTERACT_RADIUS := 1.1
const BOB_HEIGHT := 0.045
const BOB_SPEED := 1.7
const SPIN_SPEED := 0.5

var label: String = "Pick it up"
var radius: float = INTERACT_RADIUS

var _found: bool = false
var _time: float = 0.0
var _base_y: float = 0.0
var _mesh_instance: MeshInstance3D = null


func _ready() -> void:
	var data: Dictionary = KIND_DATA[name]
	_time = randf() * TAU  # desynced bob phase per-instance, purely cosmetic
	_base_y = data["scale"].y * 0.5 + 0.03
	_mesh_instance = _build_mesh(data)
	Game.register_free_interactable(self)
	Game.state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
	Game.unregister_free_interactable(self)


func _physics_process(delta: float) -> void:
	if _found:
		return
	_time += delta
	position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
	_mesh_instance.rotation.y += delta * SPIN_SPEED


## Toggled by Game.interact() once this treasure is the active free
## interactable. One-shot: unregisters itself so it can't be "found" twice
## in the same run.
func interact() -> void:
	if _found:
		return
	_found = true
	visible = false
	Game.set_treasures_found(Game.treasures_found + 1)
	AudioDirector.play_chime("keepsake")
	Game.dialogue_shown.emit("You", KIND_DATA[name]["line"], 2.6)
	Game.unregister_free_interactable(self)


## A fresh "Play again" makes every treasure findable again -- game.gd's
## start_episode() already zeroes Game.treasures_found itself (before this
## signal fires, so no race); this only restores this node's own
## visibility/registration to match.
func _on_state_changed(new_state: String) -> void:
	if new_state == EpisodeDirector.State.ARRIVE and _found:
		_found = false
		visible = true
		Game.register_free_interactable(self)


func _build_mesh(data: Dictionary) -> MeshInstance3D:
	var mesh: Mesh
	match data["shape"]:
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 14
			sm.rings = 10
			mesh = sm
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE
			mesh = bm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["color"]
	mat.roughness = 0.4
	mat.metallic = 0.05
	mat.emission_enabled = true
	mat.emission = data["color"]
	mat.emission_energy_multiplier = 0.3
	mesh.surface_set_material(0, mat)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.scale = data["scale"]
	add_child(instance)
	return instance
