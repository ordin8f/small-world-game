extends OmniLight3D
## The warm light spilling from home, which intensifies on the walk back.
##
## Was a 2x3 m double-sided translucent emissive PlaneMesh at z=11.82 -- a
## verbatim port of scene.mjs's createHomeGlow(). That worked in the browser
## build, where the world ended at z=12 and the camera never passed z=11.05, so
## the plane was always ahead of the camera and read as a glow at the doorway.
##
## After the world expansion it did not. The house is now at z=16.3, the camera
## reaches 15.9, and the player walks to ~12.5 -- so the plane sat 4.5 m adrift
## in open courtyard, and because it was CULL_DISABLED the player walked THROUGH
## a glowing orange sheet on the way home. It filled most of the frame at the
## door beat, which is precisely where the dusk return is supposed to pay off.
##
## A home glow should be light, not a billboard. As an OmniLight3D at the porch
## it cannot be walked through, cannot be seen edge-on, actually lights the
## facade and step that now exist there, and feeds the volumetric fog so it
## reads as a glow in the air rather than a decal in space.

const GLOW_COLOR := Color(1.0, 0.66, 0.28)  # palette.warmLight

## Always-on porch light, so home reads as inhabited from the first frame.
const BASE_ENERGY := 0.55
## Added while walking home. game.mjs:446's pulse is preserved as the shape of
## the intensification -- it is the same beat, driven the same way.
const ACTIVE_ENERGY := 3.2

var _time: float = 0.0


func _ready() -> void:
	light_color = GLOW_COLOR
	light_energy = BASE_ENERGY
	omni_range = 9.0
	omni_attenuation = 1.6
	light_volumetric_fog_energy = 2.2
	shadow_enabled = false


func _process(delta: float) -> void:
	_time += delta
	var state := Game.director.state
	var active := state == EpisodeDirector.State.GO_HOME or state == EpisodeDirector.State.COMPLETE

	var intensity := 0.0
	if active:
		var pulse := (sin(_time * 2.1) + 1.0) / 2.0
		intensity = 0.65 + pulse * 0.25

	light_energy = BASE_ENERGY + ACTIVE_ENERGY * intensity
