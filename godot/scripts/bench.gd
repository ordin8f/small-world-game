class_name Bench
extends Node3D
## Sitting on the park bench west of the chalk circle (developer, 2026-08-30:
## "I can't sit on the bench and go right through it").
##
## The going-through-it half is fixed in world_bounds.gd, which had no entry
## for this prop at all. This is the other half: a bench is a thing you sit
## on, and sitting is the one verb it obviously affords.
##
## Free-roam interactable (Game.free_interactables), exactly like swing.gd:
## walk up, press interact to sit, press it again to get up. Deliberately
## NOT gated on episode state and deliberately not wired to any event -- it
## must never gate or delay a story beat, so nothing here talks to
## EpisodeDirector beyond standing the player back up on a fresh run.
##
## WHAT THIS VERB IS, so nobody later mistakes it for an unfinished one:
## it is a pause, not an activity. There is deliberately nothing to do while
## seated -- no swing to pump, no timer, no reward. It earns its place
## because of where it points: the bench faces the chalk circle, so sitting
## is a way to stop and watch the other children, in a game whose whole
## subject is watching other children and wanting to join in.
##
## That is also its one real fragility, and it is a placement fact rather
## than a code fact: this is furniture the moment it stops facing something
## worth watching. If WorldAffordances.BENCH_FACES ever moves off the
## circle, or the children stop gathering there, the right response is to
## re-aim the bench or cut the verb -- not to bolt an activity onto it.
##
## Unlike swing.tscn this scene carries no geometry of its own. The bench
## MODEL is a prop in the generated courtyard (tools/_bootstrap_courtyard.gd)
## and its footprint is a WorldBounds collider, so a second copy here would
## be a third place to disagree about where the bench is. It follows
## stepping_stones.tscn/puddles.tscn instead: a script-only node that reads
## the authored geometry out of WorldAffordances, and moves itself there so
## Game's own distance check measures from the real bench.

## Leaving must be free. Interact toggles it, and so does simply trying to
## walk away -- a child gets up off a bench by getting up, and a player who
## has forgotten which key they pressed to sit down should not be stuck
## there. Armed only once every movement key has been released, so that
## sitting down while still holding the key you walked up with does not pop
## you straight back out of the seat.
const MOVE_ACTIONS := ["move_forward", "move_back", "move_left", "move_right"]

## "sit" rather than the swing's "drive": hands in the lap is right on a
## bench, where there is nothing to hold. Both drop the rig's root bone to
## seat height; character_visual.gd's _apply() compensates that, and
## WorldAffordances.SEATED_RIDER_LIFT is the small residual left over, so
## nothing here re-derives a seat height of its own.
const SIT_CLIP := "sit"

var label: String = "Sit on the bench"
var radius: float = WorldAffordances.BENCH_SIT_RADIUS

var _seated: bool = false
var _movement_release_seen: bool = false


func _ready() -> void:
	global_position = WorldAffordances.BENCH_POSITION
	rotation.y = WorldAffordances.bench_yaw()
	Game.register_free_interactable(self)
	Game.state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
	Game.unregister_free_interactable(self)


func interact() -> void:
	if _seated:
		_stand()
	else:
		_sit()


func seated() -> bool:
	return _seated


func _sit() -> void:
	if not is_instance_valid(Game.player):
		return
	_seated = true
	_movement_release_seen = false
	var player := Game.player
	player.external_control = true
	player.global_position = WorldAffordances.bench_sit_position()
	# The sitter looks out over the seat, i.e. along the bench's local +z --
	# which is heading + PI, since the character rig's forward is -z at
	# heading 0 (player.gd's own atan2(-x, -z) convention).
	player.rotation.y = rotation.y + PI
	player.character_visual.play_pose(SIT_CLIP)
	# Sitting only. _stand() stays deliberately silent -- see
	# audio_director.gd's BENCH_DURATION for why sounding both halves of a
	# toggle is the wrong call.
	AudioDirector.play_bench_settle()


func _stand() -> void:
	_seated = false
	if not is_instance_valid(Game.player):
		return
	var player := Game.player
	player.external_control = false
	player.global_position = WorldAffordances.bench_stand_position()
	player.global_position.y = player.locked_y
	# Facing out from the bench, the way they were while sitting -- standing
	# up should not spin the child round to look at the seat they just left.
	player.rotation.y = rotation.y + PI
	player.character_visual.set_motion(false, false)


func _physics_process(_delta: float) -> void:
	if not _seated:
		return
	if not is_instance_valid(Game.player):
		_stand()
		return
	if not _any_move_pressed():
		_movement_release_seen = true
	elif _movement_release_seen:
		_stand()


func _any_move_pressed() -> bool:
	for action in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false


## A fresh run mid-sit hands control back, same defensive reasoning as
## swing.gd's own ARRIVE handler (and player.gd's unconditional
## external_control reset, which covers the case where these two race).
func _on_state_changed(new_state: String) -> void:
	if new_state == EpisodeDirector.State.ARRIVE and _seated:
		_stand()
