class_name Sandbox
extends Node3D
## Gate 1 (mechanics agent): "the sandbox should let you build something
## that persists -- a sandcastle that stays built." Self-contained,
## position-parametrized scene (see tools/_bootstrap_sandbox_scene.gd's own
## doc comment, same reasoning as swing.gd).
##
## Free-roam interactable: walk into the pit, press interact repeatedly to
## add mounds AT THE PLAYER'S OWN STANDING SPOT within the pit (clamped to
## stay inside it). One button, but where you stand is a real, if small,
## creative choice -- a ring of mounds, a cluster, spread out -- rather
## than an authored fixed layout every player gets identically.
##
## "Persists" is scoped to the current afternoon: docs/PRODUCT_CONTRACT.md's
## only sanctioned save is the single completed_once flag (see game.gd's
## own doc comment on SAVE_PATH), so a built sandcastle is NOT written to
## disk -- it stays built for as long as this run's session lasts and
## resets on a fresh "Play again" (Game.state_changed -> ARRIVE), exactly
## like every other piece of session state in this project (ball, player
## position, pocket treasures).
##
## No fail state, no piece count shown anywhere -- docs/PRODUCT_CONTRACT.md
## bans scoring outright, same reason pocket_treasure.gd shows no tally.
## Planting the flag once the pit is full IS the "finished" signal; there
## is no numeric readout of it anywhere, during play or otherwise.

const MAX_MOUNDS := 5
const PIT_HALF := 1.6  ## must match tools/_bootstrap_sandbox_scene.gd's own PIT_HALF -- see that file's doc comment
const MOUND_MARGIN := 0.35  ## keeps a mound's own footprint inside the border, not clipping through it
const MOUND_RADIUS := 0.22
const GROW_SECONDS := 0.35

## One squat per handful of sand. The obvious reading of "build a sandcastle"
## would be to hold `crouch` for the whole time the child is in the pit and
## punch `interact-right` in on each pat -- but those two fight: interact-right
## is a standing clip that touches the torso, so every pat would stand the
## child back up and then drop them again. A repeated squat is also simply
## the truer picture of patting sand, and it composes with the pit's own
## rule that WHERE you stand is the choice: the child squats wherever they
## are, stands, walks two steps, squats again.
const PAT_CLIP := "crouch"
## crouch is a 0.17s held pose, so its own length is far too short to read.
const PAT_HOLD_SECONDS := 0.7
const SAND_MOUND_COLOR := Color(0.78, 0.66, 0.46)
const FLAG_POLE_COLOR := Color(0.4, 0.24, 0.14)
const FLAG_CLOTH_COLOR := Color(0.75, 0.28, 0.22)

var label: String = "Pat the sand into shape"
## A bit past the border, not just the interior -- so the prompt is offered
## on approach, not only once already standing inside the pit.
var radius: float = PIT_HALF + 0.5

var _mound_count: int = 0
var _flag_planted: bool = false
var _mounds_container: Node3D = null


func _ready() -> void:
	_mounds_container = Node3D.new()
	_mounds_container.name = "Mounds"
	add_child(_mounds_container)
	Game.register_free_interactable(self)
	Game.state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
	Game.unregister_free_interactable(self)


func interact() -> void:
	if _mound_count >= MAX_MOUNDS or not is_instance_valid(Game.player):
		return
	var local_pos := to_local(Game.player.global_position)
	var limit := PIT_HALF - MOUND_MARGIN
	var clamped_x := clampf(local_pos.x, -limit, limit)
	var clamped_z := clampf(local_pos.z, -limit, limit)
	_spawn_mound(Vector3(clamped_x, 0.0, clamped_z))
	_mound_count += 1
	AudioDirector.play_sand_pat()
	# Presentation only, and after the mound already exists -- the pat has
	# fully happened by this line whether or not a clip plays.
	var visual := CharacterVisual.of_player()
	if visual != null:
		visual.play_pose(PAT_CLIP, PAT_HOLD_SECONDS)
	if _mound_count >= MAX_MOUNDS and not _flag_planted:
		_plant_flag()


func _spawn_mound(local_pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = MOUND_RADIUS
	mesh.height = MOUND_RADIUS * 1.3
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SAND_MOUND_COLOR
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = local_pos + Vector3(0.0, 0.06, 0.0)
	instance.scale = Vector3.ZERO
	_mounds_container.add_child(instance)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(instance, "scale", Vector3.ONE, GROW_SECONDS)


## The finishing touch, planted center-pit once the fifth mound lands --
## deliberately the ONLY signal that the castle is "done"; there is no
## numeric readout anywhere else.
func _plant_flag() -> void:
	_flag_planted = true
	Game.unregister_free_interactable(self)  # nothing left to do here -- no lingering "Pat the sand" prompt on a finished castle

	var root := Node3D.new()

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.015
	pole_mesh.bottom_radius = 0.02
	pole_mesh.height = 0.42
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = FLAG_POLE_COLOR
	pole_mesh.surface_set_material(0, pole_mat)
	var pole := MeshInstance3D.new()
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, 0.21, 0.0)
	root.add_child(pole)

	var cloth_mesh := PrismMesh.new()
	cloth_mesh.size = Vector3(0.16, 0.12, 0.01)
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = FLAG_CLOTH_COLOR
	cloth_mesh.surface_set_material(0, cloth_mat)
	var cloth := MeshInstance3D.new()
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(0.08, 0.36, 0.0)
	root.add_child(cloth)

	root.scale = Vector3.ZERO
	_mounds_container.add_child(root)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "scale", Vector3.ONE, GROW_SECONDS * 1.4)

	# Reuses the same small discovery sting pocket_treasure.gd plays --
	# "you finished it" deserves the same warmth as finding a keepsake, not
	# a third distinct meaning for the player to learn.
	AudioDirector.play_chime("keepsake")


func _on_state_changed(new_state: String) -> void:
	if new_state == EpisodeDirector.State.ARRIVE:
		_reset()


func _reset() -> void:
	if _mound_count == 0 and not _flag_planted:
		return
	_mound_count = 0
	_flag_planted = false
	for child in _mounds_container.get_children():
		child.queue_free()
	Game.register_free_interactable(self)  # no-op if never unregistered; restores the prompt if a full castle had unregistered it
