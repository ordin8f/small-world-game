extends Node3D
## Gate 0 frame (S0/S1): the title's own cinematic camera -- entirely
## independent of camera_rig.gd/camera_profile.gd (the play rig is off
## limits, per the brief: "add a separate cinematic path rather than
## editing the play rig"). Two jobs:
##
## 1. A slow, low, child-height drift over the live world while the title
##    menu is up (DEMO_PLAN.md S1: "camera drifting at child height").
## 2. On Play, an unbroken glide from wherever it is into the real
##    gameplay camera's current pose -- "no cut, no fade to a separate
##    scene". glide_to_gameplay() samples Game.camera's transform every
##    frame (not a one-shot snapshot) so it always converges onto wherever
##    the play rig actually is, then hands `current` to it explicitly.
##
## Anchor/look-target: docs/concept-art/extended/concept_07_circle.png --
## a low camera standing inside the home threshold passage
## (_bootstrap_courtyard.gd's piers, z 10.6..12.6, x opening -1.2..1.2),
## looking south through it at the chalk circle where the three NPCs
## already stand (courtyard.tscn's KeyPoints/Group marker, (0, -3.8) --
## same GROUP_POSITION perception.gd uses). Reuses existing geometry,
## lighting and characters entirely; this file only ever places a camera.

signal glide_finished

const ANCHOR := Vector3(0.0, 1.4, 11.0)
const LOOK_TARGET := Vector3(0.0, 1.15, -3.8)
const FOV := 46.0

## Small, slow, independent sines on position and look-target -- an
## organic "someone is holding this shot, not quite still" drift rather
## than a locked-off frame. Different periods/axes so the motion never
## repeats in an obviously loop-y way over a normal menu dwell time.
const DRIFT_POS_AMPLITUDE := Vector3(0.30, 0.12, 0.16)
const DRIFT_POS_PERIOD := Vector3(19.0, 13.0, 23.0)
const DRIFT_LOOK_AMPLITUDE := Vector2(0.35, 0.15)
const DRIFT_LOOK_PERIOD := Vector2(17.0, 11.0)

const GLIDE_DURATION := 1.9

@onready var camera: Camera3D = $Camera3D

var _time: float = 0.0
var _gliding: bool = false
var _glide_t: float = 0.0
var _glide_start_xform: Transform3D
var _glide_start_fov: float = FOV


func _ready() -> void:
	Game.title_camera = self
	camera.fov = FOV
	show_title()


## Reactivates the title cinematic (used both on first boot and every
## time S7's "return to title" brings the menu back up after Credits).
## A clean snap back to the anchor -- only the Title -> Play transition is
## required to be unbroken; menu navigation cuts are ordinary.
func show_title() -> void:
	_gliding = false
	_time = 0.0
	global_position = ANCHOR
	look_at(LOOK_TARGET, Vector3.UP)
	camera.fov = FOV
	camera.current = true


func _process(delta: float) -> void:
	_time += delta
	if _gliding:
		_process_glide(delta)
	else:
		_process_drift()


func _process_drift() -> void:
	var offset := Vector3(
		sin(_time * TAU / DRIFT_POS_PERIOD.x) * DRIFT_POS_AMPLITUDE.x,
		sin(_time * TAU / DRIFT_POS_PERIOD.y) * DRIFT_POS_AMPLITUDE.y,
		sin(_time * TAU / DRIFT_POS_PERIOD.z) * DRIFT_POS_AMPLITUDE.z,
	)
	global_position = ANCHOR + offset

	var look_offset := Vector3(
		sin(_time * TAU / DRIFT_LOOK_PERIOD.x) * DRIFT_LOOK_AMPLITUDE.x,
		sin(_time * TAU / DRIFT_LOOK_PERIOD.y) * DRIFT_LOOK_AMPLITUDE.y,
		0.0,
	)
	look_at(LOOK_TARGET + look_offset, Vector3.UP)


## Begins the glide; returns once it has actually finished (await this).
## Idempotent against being called twice -- a second call while already
## gliding is a no-op rather than restarting the blend.
func glide_to_gameplay() -> void:
	if _gliding:
		await glide_finished
		return
	_gliding = true
	_glide_t = 0.0
	_glide_start_xform = global_transform
	_glide_start_fov = camera.fov
	await glide_finished


func _process_glide(delta: float) -> void:
	_glide_t = minf(_glide_t + delta / GLIDE_DURATION, 1.0)
	var eased := _ease_in_out_cubic(_glide_t)

	var target_cam: Camera3D = Game.camera
	if is_instance_valid(target_cam):
		global_transform = _glide_start_xform.interpolate_with(target_cam.global_transform, eased)
		camera.fov = lerpf(_glide_start_fov, target_cam.fov, eased)

	if _glide_t >= 1.0:
		_gliding = false
		if is_instance_valid(target_cam):
			target_cam.current = true  # hand off first -- never a frame with no current camera
		camera.current = false
		glide_finished.emit()


static func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	var f := -2.0 * t + 2.0
	return 1.0 - (f * f * f) / 2.0
