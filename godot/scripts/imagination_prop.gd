class_name ImaginationProp
extends Node3D
## Gate 1 (mechanics agent): docs/EMOTIONAL_LENS.md's "imagination overlays"
## applied to a WORLD OBJECT rather than a place -- "a cardboard box
## suggests a boat... playground towers feel castle-like when excited" --
## distinct from stepping_stones.gd's floor-is-lava cue (a REGION, entered
## passively) and puddles.gd's splash (automatic on contact). This one is
## deliberately interact-gated, per the brief's own wording: "press
## interact near a flagged prop and it briefly becomes something else in
## the child's eyes... then reverts."
##
## Two instances exist today (CrateProp -> castle, BenchProp -> boat, see
## PROP_DATA below), both entirely new objects authored by this file rather
## than re-flagging courtyard.tscn's real bench/props: the world-expansion
## agent owns tools/_bootstrap_courtyard.gd and is actively rewriting it,
## so reaching into that scene's existing node names here would be both a
## merge hazard and a fragile cross-file coupling. Config keyed by node
## .name, same convention character_visual.gd/interaction_zone.gd already
## use for a template scene reused with different per-instance data.
##
## Reuses perception.gd's existing imagination-cue channel
## (set_imagination_target) for the ambient nudge (fog/saturation/glow --
## scalars only, see that file's own doc comment) rather than inventing a
## second one, exactly as the brief asks: "extend that pattern rather than
## inventing a second one." The "becomes something else" part is this
## node's own local overlay mesh fading in/out -- never a colour written
## onto the Environment, so it cannot trip test_perception_wiring.gd's
## "the lens never authors a colour" guard, which only watches the
## Environment/Sun, not an ordinary in-world MeshInstance3D.

const PROP_DATA := {
	"CrateProp": {
		"base_color": Color(0.42, 0.28, 0.16),
		"base_size": Vector3(0.62, 0.58, 0.62),
		"imagined": "castle",
	},
	"BenchProp": {
		"base_color": Color(0.36, 0.22, 0.13),
		"base_size": Vector3(1.1, 0.42, 0.42),
		"imagined": "boat",
	},
}

const IMAGINED_COLOR := Color(0.95, 0.85, 0.6)
const REVERT_SECONDS := 3.2  ## "briefly" -- long enough to register, short enough to stay a flicker of imagination, not a new steady state
const FADE_SECONDS := 0.45
const INTERACT_RADIUS := 1.5

var label: String = "Look closer"
var radius: float = INTERACT_RADIUS

var _imagined: bool = false
var _overlay: Node3D = null
var _revert_timer: float = 0.0
var _perception: Node = null


func _ready() -> void:
	var data: Dictionary = PROP_DATA[name]
	_build_base(data)
	_overlay = _build_overlay(data["imagined"])
	_overlay.visible = false
	_overlay.scale = Vector3.ZERO
	_perception = get_parent().find_child("Perception", true, false) if get_parent() != null else null
	Game.register_free_interactable(self)
	Game.state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
	Game.unregister_free_interactable(self)


func _physics_process(delta: float) -> void:
	if not _imagined:
		return
	_revert_timer -= delta
	if _revert_timer <= 0.0:
		_end_imagining()


## Toggled by Game.interact() once this prop is the active free
## interactable. A second press ends the cue early -- reverting is always
## the child's own to choose too, not only something that happens TO them
## on a timeout.
func interact() -> void:
	if _imagined:
		_end_imagining()
		return
	_imagined = true
	_revert_timer = REVERT_SECONDS
	AudioDirector.play_chime("wonder")
	_overlay.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "scale", Vector3.ONE, FADE_SECONDS)
	if _perception != null:
		_perception.set_imagination_target(true, name)


func _end_imagining() -> void:
	_imagined = false
	if _perception != null:
		_perception.set_imagination_target(false, name)
	var overlay := _overlay
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(overlay, "scale", Vector3.ZERO, FADE_SECONDS)
	tween.finished.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.visible = false
	)


## A fresh "Play again" must not carry a mid-transform prop into the new
## run -- same restart contract player.gd/ball.gd already hold to.
func _on_state_changed(new_state: String) -> void:
	if new_state == EpisodeDirector.State.ARRIVE and _imagined:
		_imagined = false
		if _perception != null:
			_perception.set_imagination_target(false, name)
		_overlay.visible = false
		_overlay.scale = Vector3.ZERO


func _build_base(data: Dictionary) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data["base_color"]
	mat.roughness = 0.88
	var mesh := BoxMesh.new()
	mesh.size = data["base_size"]
	mesh.surface_set_material(0, mat)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = data["base_size"].y * 0.5
	add_child(instance)


func _build_overlay(kind: String) -> Node3D:
	match kind:
		"castle":
			return _build_castle_overlay()
		"boat":
			return _build_boat_overlay()
	return Node3D.new()


func _build_castle_overlay() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var mat := _imagined_material()

	for pos in [Vector3(0.26, 0.0, 0.26), Vector3(-0.26, 0.0, 0.26), Vector3(0.26, 0.0, -0.26), Vector3(-0.26, 0.0, -0.26)]:
		var turret := CylinderMesh.new()
		turret.top_radius = 0.07
		turret.bottom_radius = 0.09
		turret.height = 0.5
		turret.radial_segments = 8
		root.add_child(_primitive(turret, mat, pos + Vector3(0.0, 0.75, 0.0)))

		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = 0.11
		roof.height = 0.22
		roof.radial_segments = 8
		root.add_child(_primitive(roof, mat, pos + Vector3(0.0, 1.11, 0.0)))

	var keep := BoxMesh.new()
	keep.size = Vector3(0.4, 0.55, 0.4)
	root.add_child(_primitive(keep, mat, Vector3(0.0, 0.9, 0.0)))
	return root


func _build_boat_overlay() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var mat := _imagined_material()

	var hull := BoxMesh.new()
	hull.size = Vector3(1.5, 0.32, 0.6)
	root.add_child(_primitive(hull, mat, Vector3(0.0, 0.45, 0.0)))

	var mast := CylinderMesh.new()
	mast.top_radius = 0.02
	mast.bottom_radius = 0.03
	mast.height = 0.7
	root.add_child(_primitive(mast, mat, Vector3(0.0, 0.95, 0.0)))

	var sail := PrismMesh.new()
	sail.size = Vector3(0.4, 0.45, 0.02)
	var sail_instance := _primitive(sail, mat, Vector3(0.05, 1.05, 0.0))
	sail_instance.rotation.y = PI * 0.5
	root.add_child(sail_instance)
	return root


func _primitive(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	return instance


func _imagined_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = IMAGINED_COLOR
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = IMAGINED_COLOR
	mat.emission_energy_multiplier = 0.9
	return mat
