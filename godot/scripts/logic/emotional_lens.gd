class_name EmotionalLens
extends RefCounted
## Verbatim port of src/logic.mjs's EmotionalLens class and dominantEmotion()
## function. Comfort/energy/curiosity are never shown to the player as a
## meter -- only their DERIVED dominant_emotion() label and getVisuals()'s
## camera/fog/color mapping (perception.gd, M2.5) ever reach the screen.

var value: Dictionary
var target: Dictionary


func _init(initial: Dictionary = {"comfort": 0.38, "energy": 0.48, "curiosity": 0.58}) -> void:
	value = initial.duplicate()
	target = initial.duplicate()


func set_target(new_target: Dictionary) -> void:
	target = {
		"comfort": LensMath.clamp_value(new_target["comfort"]),
		"energy": LensMath.clamp_value(new_target["energy"]),
		"curiosity": LensMath.clamp_value(new_target["curiosity"]),
	}


func nudge(delta: Dictionary) -> void:
	set_target({
		"comfort": target["comfort"] + delta.get("comfort", 0.0),
		"energy": target["energy"] + delta.get("energy", 0.0),
		"curiosity": target["curiosity"] + delta.get("curiosity", 0.0),
	})


func update(dt: float) -> Dictionary:
	var t := 1.0 - exp(-maxf(0.0, dt) * 1.7)
	value["comfort"] = LensMath.lerp_value(value["comfort"], target["comfort"], t)
	value["energy"] = LensMath.lerp_value(value["energy"], target["energy"], t)
	value["curiosity"] = LensMath.lerp_value(value["curiosity"], target["curiosity"], t)
	return value


func get_visuals() -> Dictionary:
	var comfort: float = value["comfort"]
	var energy: float = value["energy"]
	var curiosity: float = value["curiosity"]
	var unease := 1.0 - comfort
	return {
		"emotion": dominant_emotion(value),
		"camera_distance": LensMath.lerp_value(4.55, 6.15, comfort),
		"camera_fov": LensMath.lerp_value(52.0, 61.0, comfort),
		"vignette": LensMath.clamp_value(0.12 + unease * 0.34 + energy * unease * 0.12, 0.1, 0.58),
		"saturation": LensMath.lerp_value(0.76, 1.08, comfort) + curiosity * 0.06,
		"warmth": LensMath.clamp_value(0.25 + comfort * 0.7, 0.0, 1.0),
		"curiosity_glow": LensMath.smoothstep(0.52, 0.9, curiosity),
		"sway": unease * energy * 0.035,
		"fog_near": LensMath.lerp_value(10.0, 18.0, comfort),
		"fog_far": LensMath.lerp_value(27.0, 42.0, comfort),
	}


## state: Dictionary with "comfort"/"energy"/"curiosity" float keys (accepts
## either `value` or `target`, or any equivalent literal for tests).
static func dominant_emotion(state: Dictionary) -> String:
	var comfort: float = state["comfort"]
	var energy: float = state["energy"]
	var curiosity: float = state["curiosity"]
	if comfort < 0.35 and energy > 0.62:
		return "anxious"
	if comfort < 0.4 and energy <= 0.62:
		return "lonely"
	if curiosity > 0.72 and comfort >= 0.35:
		return "curious"
	if comfort > 0.72 and energy > 0.55:
		return "happy"
	if comfort > 0.65 and energy <= 0.55:
		return "secure"
	return "uncertain"
