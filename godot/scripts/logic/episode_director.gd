class_name EpisodeDirector
extends RefCounted
## Verbatim port of src/logic.mjs's EpisodeDirector + EpisodeState + STATE_COPY
## + ALLOWED. Deterministic state machine: dispatch() only accepts the one
## event each state allows, returns false (no state change, no history
## entry) for anything else -- including replays and out-of-order events.

## String-keyed to match the JS `Object.freeze({ARRIVE: 'ARRIVE', ...})`
## pattern (each key maps to its own name) rather than a Godot int enum, so
## `state` stays directly usable as a STATE_COPY/ALLOWED dictionary key and
## as the debug-bridge/HUD's displayed string.
const State := {
	"ARRIVE": "ARRIVE",
	"OBSERVED": "OBSERVED",
	"BALL_IN_FLIGHT": "BALL_IN_FLIGHT",
	"FIND_BALL": "FIND_BALL",
	"RETURN_BALL": "RETURN_BALL",
	"INVITED": "INVITED",
	"GO_HOME": "GO_HOME",
	"COMPLETE": "COMPLETE",
}

const STATE_COPY := {
	"ARRIVE": {"objective": "Stand near the chalk circle and watch the game.", "prompt": "Watch quietly"},
	"OBSERVED": {"objective": "Stay nearby. See how their game works.", "prompt": null},
	"BALL_IN_FLIGHT": {"objective": "The ball is getting away.", "prompt": null},
	"FIND_BALL": {"objective": "Find the ball beyond the low garden wall.", "prompt": "Pick up the ball"},
	"RETURN_BALL": {"objective": "Carry the ball back to the children.", "prompt": "Give the ball back"},
	"INVITED": {"objective": "Stay for one small turn.", "prompt": "Join the circle"},
	"GO_HOME": {"objective": "Follow the warm light home.", "prompt": "Go inside"},
	"COMPLETE": {"objective": "The afternoon is complete.", "prompt": null},
}

const ALLOWED := {
	"ARRIVE": {"observe": "OBSERVED"},
	"OBSERVED": {"ball_kicked": "BALL_IN_FLIGHT"},
	"BALL_IN_FLIGHT": {"ball_landed": "FIND_BALL"},
	"FIND_BALL": {"ball_picked_up": "RETURN_BALL"},
	"RETURN_BALL": {"ball_returned": "INVITED"},
	"INVITED": {"joined": "GO_HOME"},
	"GO_HOME": {"entered_home": "COMPLETE"},
	"COMPLETE": {},
}

var state: String = State.ARRIVE
var history: Array = []
var started_at: float = 0.0


func _init() -> void:
	history = [{"state": state, "at": 0.0}]


func start(now: float = 0.0) -> void:
	started_at = now
	history = [{"state": state, "at": 0.0}]


func dispatch(event_name: String, now: float = 0.0) -> bool:
	var transitions: Dictionary = ALLOWED.get(state, {})
	if not transitions.has(event_name):
		return false
	var next: String = transitions[event_name]
	state = next
	history.append({"state": next, "at": maxf(0.0, now - started_at)})
	return true


func copy() -> Dictionary:
	return STATE_COPY[state]


func emotional_target(distance_from_group: float = 0.0) -> Dictionary:
	var d := LensMath.clamp_value(distance_from_group / 15.0)
	match state:
		State.ARRIVE:
			return {"comfort": 0.36, "energy": 0.48, "curiosity": 0.62}
		State.OBSERVED:
			return {"comfort": 0.42, "energy": 0.53, "curiosity": 0.78}
		State.BALL_IN_FLIGHT:
			return {"comfort": 0.28, "energy": 0.78, "curiosity": 0.72}
		State.FIND_BALL:
			return {"comfort": LensMath.clamp_value(0.38 - d * 0.16), "energy": 0.68, "curiosity": 0.86}
		State.RETURN_BALL:
			return {"comfort": 0.58, "energy": 0.66, "curiosity": 0.72}
		State.INVITED:
			return {"comfort": 0.82, "energy": 0.7, "curiosity": 0.7}
		State.GO_HOME:
			return {"comfort": 0.7, "energy": 0.45, "curiosity": 0.48}
		State.COMPLETE:
			return {"comfort": 0.9, "energy": 0.35, "curiosity": 0.45}
		_:
			return {"comfort": 0.5, "energy": 0.5, "curiosity": 0.5}


func elapsed(now: float) -> float:
	return maxf(0.0, now - started_at)
