extends Node
## Applies the AUTHORED lighting mood to the world, then lets the Emotional Lens
## nudge it within bounds. Also the only thing that drives EmotionalLens forward.
##
## ARCHITECTURE NOTE -- this file was inverted on 2026-08-28.
##
## It previously computed fog colour, fog distances, ambient colour, sun colour
## and tonemap exposure from the lens `warmth` float and wrote them straight onto
## the Environment every physics frame. That meant there was no authored base
## scene: any lighting a human set was overwritten within one frame, so the game
## could not be art-directed at all. It contradicted docs/ART_DIRECTION.md:
##   "Base world -- neutral, beautiful, readable... The base scene must remain
##    coherent when all Emotional Lens effects are disabled."
## The flaw was ported verbatim from src/game.mjs:413-428 and survived every
## rewrite (WebGL2 -> Three.js -> Godot).
##
## Now: resources/moods/*.tres hold authored moods (see scripts/mood_preset.gd),
## the episode state selects one, and the lens may only apply the bounded
## modulations below. It may never write an absolute colour.
##
## Set `lens_enabled = false` and the scene must still look good. That is the
## acceptance test ART_DIRECTION.md asks for and it is now actually checkable.

const GROUP_POSITION := Vector2(0.0, -3.8)  # game.mjs's groupPosition, x/z only

const MoodPresetScript := preload("res://scripts/mood_preset.gd")

## How far the lens may move the authored base. These are deliberately small --
## the lens is a modulation, not an author. Widening them is an art-direction
## decision, not a tuning tweak.
const LENS_FOG_SCALE := 0.25       # +/-25% on fog distances (unease closes the world in)
const LENS_EXPOSURE_TRIM := 0.10   # +/-0.10 stops
const LENS_SATURATION_TRIM := 0.10
const LENS_VOLUMETRIC_SCALE := 0.35

## Seconds-scale easing for the mood arc. Slower than the lens (1.7) so a mood
## change reads as the afternoon turning, not as a reaction.
const MOOD_EASE := 0.9

## When false, no lens modulation is applied at all and the world shows the
## pure authored mood. Used by the art-direction acceptance test.
@export var lens_enabled := true

@onready var world_environment: WorldEnvironment = _scope().find_child("WorldEnvironment", true, false)
@onready var sun: DirectionalLight3D = _scope().find_child("Sun", true, false)

var _moods: Dictionary = {}
var _mood_progress := 0.0
var _base: Resource


## The scene this Node belongs to. Deliberately NOT get_tree().root: under
## gdUnit4 every scene_runner instantiates another copy of main.tscn under the
## root, so a root-wide search can bind to a different test's scene. Also
## deliberately not get_tree().current_scene, which is null both in the runner
## and when this project is driven by a --script SceneTree.
func _scope() -> Node:
	return get_parent() if get_parent() != null else get_tree().root


func _ready() -> void:
	_moods = {
		"afternoon": load("res://resources/moods/afternoon.tres"),
		"golden": load("res://resources/moods/golden.tres"),
		"dusk": load("res://resources/moods/dusk.tres"),
	}
	for key in _moods:
		if _moods[key] == null:
			printerr("perception.gd: missing mood preset '%s' -- run tools/_bootstrap_moods.gd" % key)
	_mood_progress = _mood_target()
	_ensure_static_environment()


func _physics_process(delta: float) -> void:
	# The mood arc advances even before the player exists, so the title card
	# sits in the correct authored light.
	_mood_progress = lerpf(_mood_progress, _mood_target(), 1.0 - exp(-maxf(0.0, delta) * MOOD_EASE))
	_base = _blend_moods(_mood_progress)

	var player := Game.player
	if is_instance_valid(player):
		var p := player.global_position
		var distance_from_group := Vector2(p.x - GROUP_POSITION.x, p.z - GROUP_POSITION.y).length()
		Game.lens.set_target(Game.director.emotional_target(distance_from_group))
		Game.lens.update(delta)
		AudioDirector.set_mood(Game.lens.value)

	_apply(_base, Game.lens.get_visuals())


## Episode state -> position along the authored mood arc.
## afternoon (0.0) .. golden (0.5) .. dusk (1.0), matching ART_DIRECTION.md's
## three required lighting moods and GODOT_REBUILD_PLAN.md's M3.3 mapping.
func _mood_target() -> float:
	match Game.director.state:
		EpisodeDirector.State.INVITED:
			return 0.5
		EpisodeDirector.State.GO_HOME, EpisodeDirector.State.COMPLETE:
			return 1.0
		_:
			return 0.0


func _blend_moods(t: float) -> Resource:
	var afternoon: Resource = _moods.get("afternoon")
	var golden: Resource = _moods.get("golden")
	var dusk: Resource = _moods.get("dusk")
	if afternoon == null or golden == null or dusk == null:
		return null
	if t <= 0.5:
		return MoodPresetScript.blend(afternoon, golden, t * 2.0)
	return MoodPresetScript.blend(golden, dusk, (t - 0.5) * 2.0)


## Values that never change per-frame, set once so the Environment is valid even
## before the first _physics_process.
func _ensure_static_environment() -> void:
	if world_environment == null or world_environment.environment == null:
		return
	var env := world_environment.environment
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ssao_enabled = true
	env.adjustment_enabled = true


func _apply(base: Resource, visuals: Dictionary) -> void:
	if base == null:
		return

	# --- lens modulation, bounded ------------------------------------------
	# comfort 0..1 maps to a signed -1..1 "unease" that closes the world in and
	# cools the response. Nothing here picks a colour; it only scales authored
	# values. `warmth` is the lens's own 0.25..0.95 composite of comfort.
	var unease := 0.0
	var saturation_trim := 0.0
	var exposure_trim := 0.0
	if lens_enabled:
		var warm: float = visuals["warmth"]
		# warmth sits in 0.25..0.95; recentre so the authored mood is the
		# neutral midpoint and the lens swings either side of it.
		unease = clampf((0.6 - warm) / 0.35, -1.0, 1.0)
		saturation_trim = -unease * LENS_SATURATION_TRIM
		exposure_trim = -unease * LENS_EXPOSURE_TRIM

	var fog_scale := 1.0 - unease * LENS_FOG_SCALE
	var volumetric_scale := 1.0 + unease * LENS_VOLUMETRIC_SCALE

	# --- environment --------------------------------------------------------
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.background_color = base.background_color
		env.ambient_light_color = base.ambient_color
		env.ambient_light_energy = base.ambient_energy

		env.fog_light_color = base.fog_color
		env.fog_depth_begin = base.fog_begin * fog_scale
		env.fog_depth_end = base.fog_end * fog_scale

		env.volumetric_fog_enabled = base.volumetric_enabled
		env.volumetric_fog_density = base.volumetric_density * volumetric_scale
		env.volumetric_fog_albedo = base.volumetric_albedo
		env.volumetric_fog_emission = base.volumetric_emission
		env.volumetric_fog_length = base.volumetric_length

		env.tonemap_exposure = base.exposure + exposure_trim
		env.tonemap_white = base.tonemap_white
		env.glow_intensity = base.glow_intensity
		env.glow_bloom = base.glow_bloom
		env.ssao_intensity = base.ssao_intensity
		env.adjustment_saturation = base.saturation + saturation_trim
		env.adjustment_contrast = base.contrast

	# --- sun ----------------------------------------------------------------
	if sun != null:
		sun.light_color = base.sun_color
		sun.light_energy = base.sun_energy
		sun.light_volumetric_fog_energy = base.sun_volumetric_energy
		sun.shadow_enabled = true
		if not base.sun_from.is_equal_approx(base.sun_target):
			sun.look_at_from_position(base.sun_from, base.sun_target, Vector3.UP)


## Exposed for tests and the debug overlay: the authored mood currently in
## effect, before lens modulation.
func current_mood() -> Resource:
	return _base


func mood_progress() -> float:
	return _mood_progress
