class_name MoodPreset
extends Resource
## An AUTHORED lighting mood. Field defaults below are deliberately NEUTRAL
## placeholders, not a mood -- so that every field of every real preset is
## written explicitly into its .tres and cannot silently change if this file is
## edited. The authored numbers live in tools/_bootstrap_moods.gd.
## This is the base world -- docs/ART_DIRECTION.md:
## "Base world -- neutral, beautiful, readable... The base scene must remain
## coherent when all Emotional Lens effects are disabled."
##
## Before this existed, perception.gd computed fog/ambient/sun/exposure from the
## EmotionalLens `warmth` float every physics frame, so there was no base scene
## at all and no lighting pass could survive a single frame. Presets are authored
## here and in tools/_bootstrap_moods.gd; the lens may only nudge them within
## bounds (see perception.gd's LENS_* limits).
##
## ART_DIRECTION.md's three required moods map to the three .tres in
## resources/moods/: afternoon (ARRIVE..RETURN_BALL), golden (INVITED),
## dusk (GO_HOME..COMPLETE).

@export_group("Sky and ambient")
## Environment.background_color -- the sky/haze value behind everything.
@export var background_color := Color(0.5, 0.5, 0.5)
## Low ambient is what lets shadow read as deep. The Three.js port used
## ambient_light_energy 1.6 (a literal HemisphereLight port) which flooded the
## scene flat; ART_DIRECTION.md wants "warm natural light with deep but
## readable shadow".
@export var ambient_color := Color(0.5, 0.5, 0.5)
@export_range(0.0, 3.0, 0.01) var ambient_energy := 1.0

@export_group("Sun")
@export var sun_color := Color(1.0, 1.0, 1.0)
@export_range(0.0, 16.0, 0.05) var sun_energy := 1.0
## World position the sun is placed at before look_at(sun_target). Low
## elevation gives the long raking shadows the concept art is built on.
@export var sun_from := Vector3(10.0, 10.0, 10.0)
@export var sun_target := Vector3(0.0, 0.0, 0.0)
## How strongly this sun feeds the volumetric fog -- this is what makes the
## visible light shafts in every concept panel.
@export_range(0.0, 8.0, 0.05) var sun_volumetric_energy := 1.0
## How much of the sun a shadow actually takes away. 1.0 is Godot's default and
## means a shadowed surface gets none of it, lit only by ambient -- which is why
## the shadows read as holes however high ambient goes. Below 1.0 the shadow
## removes only part, so ambient is a floor the sun adds to rather than a
## substitute for it, and lit surfaces keep their value while shadows come up.
@export_range(0.0, 1.0, 0.01) var shadow_opacity := 1.0

@export_group("Depth fog")
@export var fog_color := Color(0.5, 0.5, 0.5)
@export var fog_begin := 10.0
@export var fog_end := 100.0

@export_group("Volumetric fog")
@export var volumetric_enabled := true
@export_range(0.0, 0.1, 0.0005) var volumetric_density := 0.01
@export var volumetric_albedo := Color(1.0, 1.0, 1.0)
@export var volumetric_emission := Color(0.0, 0.0, 0.0)
@export var volumetric_length := 64.0

@export_group("Response")
@export_range(0.0, 4.0, 0.01) var exposure := 1.0
@export_range(1.0, 16.0, 0.1) var tonemap_white := 1.0
@export_range(0.0, 2.0, 0.01) var glow_intensity := 0.8
@export_range(0.0, 2.0, 0.01) var glow_bloom := 0.0
@export_range(0.0, 8.0, 0.05) var ssao_intensity := 1.0
@export_range(0.0, 2.0, 0.01) var saturation := 1.0
@export_range(0.0, 2.0, 0.01) var contrast := 1.0


## Linear blend between two authored presets. Every field is interpolated so a
## mood change is a continuous move through authored space, never a cut and
## never a computed-from-emotion value.
static func blend(a: MoodPreset, b: MoodPreset, t: float) -> MoodPreset:
	var m := MoodPreset.new()
	t = clampf(t, 0.0, 1.0)
	m.background_color = a.background_color.lerp(b.background_color, t)
	m.ambient_color = a.ambient_color.lerp(b.ambient_color, t)
	m.ambient_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
	m.sun_color = a.sun_color.lerp(b.sun_color, t)
	m.sun_energy = lerpf(a.sun_energy, b.sun_energy, t)
	m.sun_from = a.sun_from.lerp(b.sun_from, t)
	m.sun_target = a.sun_target.lerp(b.sun_target, t)
	m.sun_volumetric_energy = lerpf(a.sun_volumetric_energy, b.sun_volumetric_energy, t)
	m.fog_color = a.fog_color.lerp(b.fog_color, t)
	m.fog_begin = lerpf(a.fog_begin, b.fog_begin, t)
	m.fog_end = lerpf(a.fog_end, b.fog_end, t)
	m.volumetric_enabled = a.volumetric_enabled or b.volumetric_enabled
	m.volumetric_density = lerpf(a.volumetric_density, b.volumetric_density, t)
	m.volumetric_albedo = a.volumetric_albedo.lerp(b.volumetric_albedo, t)
	m.volumetric_emission = a.volumetric_emission.lerp(b.volumetric_emission, t)
	m.volumetric_length = lerpf(a.volumetric_length, b.volumetric_length, t)
	m.exposure = lerpf(a.exposure, b.exposure, t)
	m.tonemap_white = lerpf(a.tonemap_white, b.tonemap_white, t)
	m.glow_intensity = lerpf(a.glow_intensity, b.glow_intensity, t)
	m.glow_bloom = lerpf(a.glow_bloom, b.glow_bloom, t)
	m.ssao_intensity = lerpf(a.ssao_intensity, b.ssao_intensity, t)
	m.saturation = lerpf(a.saturation, b.saturation, t)
	m.contrast = lerpf(a.contrast, b.contrast, t)
	return m
