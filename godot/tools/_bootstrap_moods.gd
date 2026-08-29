extends SceneTree
## One-shot generator: authors the three lighting moods that docs/ART_DIRECTION.md
## requires ("The vertical slice should prove at least three lighting moods using
## largely the same environment") and saves them to resources/moods/*.tres.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_moods.gd
##
## These numbers are a FIRST PASS. They are meant to be tuned against
## docs/concept-art/ with a human looking at the result -- that is Gate 1 of the
## demo plan, and the whole reason this file exists rather than the values being
## computed from the EmotionalLens at runtime.
##
## Fog distances were re-scaled 2026-08-28 for the expanded world. They were
## authored for a 20x24 m room (diagonal ~31 m); at 39x37 m (diagonal ~54 m)
## the old 60 m envelope covered the entire world and everything washed to fog
## colour -- the deep shadow these moods exist for disappeared.
##
## Direction being aimed at, from ART_DIRECTION.md and the concept sheet:
## warm low sun raking across, deep readable shadow, visible haze carrying the
## light, restrained palette with selective warmth -- NOT a toy-box palette and
## NOT the flat 1.6-energy ambient the Three.js HemisphereLight port produced.

const MoodPresetScript := preload("res://scripts/mood_preset.gd")

const OUT_DIR := "res://resources/moods"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_save(_afternoon(), "afternoon")
	_save(_golden(), "golden")
	_save(_dusk(), "dusk")
	quit()


func _save(preset: Resource, name: String) -> void:
	var path := "%s/%s.tres" % [OUT_DIR, name]
	var err := ResourceSaver.save(preset, path)
	if err != OK:
		printerr("Failed to save %s: %d" % [path, err])
		quit(1)
		return
	print("Wrote ", path)


## Late afternoon -- the episode's home mood (ARRIVE..RETURN_BALL).
## "Golden directional light creates long readable shapes. Dust, leaves, and
## subtle atmospheric depth can make the open space feel expansive without
## adding more geometry." (ART_DIRECTION.md)
func _afternoon() -> Resource:
	var m := MoodPresetScript.new()
	m.background_color = Color(0.70, 0.67, 0.60)
	m.ambient_color = Color(0.46, 0.51, 0.60)
	m.ambient_energy = 0.34
	m.sun_color = Color(1.0, 0.87, 0.68)
	m.sun_energy = 4.0
	m.sun_from = Vector3(16.0, 10.0, 12.0)
	m.sun_target = Vector3(0.0, 1.2, -2.0)
	m.sun_volumetric_energy = 2.2
	m.fog_color = Color(0.76, 0.70, 0.59)
	m.fog_begin = 22.0
	m.fog_end = 120.0
	m.volumetric_density = 0.018
	m.volumetric_albedo = Color(1.0, 0.92, 0.80)
	m.exposure = 0.80
	m.tonemap_white = 2.0
	m.glow_intensity = 0.35
	m.glow_bloom = 0.10
	m.ssao_intensity = 1.6
	m.saturation = 1.06
	m.contrast = 1.28
	return m


## Invitation warmth -- the single beat where the circle opens (INVITED).
## The warmest, most luminous frame in the episode; this is the emotional peak
## and the light should be doing the work, not a UI cue.
func _golden() -> Resource:
	var m := MoodPresetScript.new()
	m.background_color = Color(0.82, 0.68, 0.49)
	m.ambient_color = Color(0.54, 0.49, 0.49)
	m.ambient_energy = 0.38
	m.sun_color = Color(1.0, 0.78, 0.50)
	m.sun_energy = 4.4
	m.sun_from = Vector3(18.0, 7.5, 8.0)
	m.sun_target = Vector3(0.0, 1.1, -3.0)
	m.sun_volumetric_energy = 3.0
	m.fog_color = Color(0.86, 0.71, 0.51)
	m.fog_begin = 20.0
	m.fog_end = 110.0
	m.volumetric_density = 0.020
	m.volumetric_albedo = Color(1.0, 0.88, 0.70)
	m.exposure = 0.84
	m.tonemap_white = 2.0
	m.glow_intensity = 0.50
	m.glow_bloom = 0.16
	m.ssao_intensity = 1.5
	m.saturation = 1.08
	m.contrast = 1.26
	return m


## Dusk / return -- GO_HOME..COMPLETE. "The environment becomes cooler and
## quieter while windows and the home doorway become warm anchors. The scene
## should feel vulnerable, not horrific." (ART_DIRECTION.md)
func _dusk() -> Resource:
	var m := MoodPresetScript.new()
	m.background_color = Color(0.46, 0.40, 0.52)
	m.ambient_color = Color(0.42, 0.44, 0.58)
	m.ambient_energy = 0.58
	m.sun_color = Color(0.85, 0.55, 0.52)
	m.sun_energy = 3.0
	m.sun_from = Vector3(20.0, 4.0, 3.5)
	m.sun_target = Vector3(0.0, 1.0, -4.0)
	m.sun_volumetric_energy = 2.0
	m.fog_color = Color(0.55, 0.46, 0.56)
	m.fog_begin = 16.0
	m.fog_end = 85.0
	m.volumetric_density = 0.026
	m.volumetric_albedo = Color(0.85, 0.78, 0.86)
	m.volumetric_emission = Color(0.02, 0.018, 0.03)
	m.exposure = 1.12
	m.tonemap_white = 2.0
	m.glow_intensity = 0.55
	m.glow_bloom = 0.20
	m.ssao_intensity = 1.8
	m.saturation = 1.00
	m.contrast = 1.26
	return m
