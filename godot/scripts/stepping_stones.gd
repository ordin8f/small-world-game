extends Node
## Gate 0: "the floor is lava" -- crossing the stepping stones near the
## garden wall. docs/EMOTIONAL_LENS.md's imagination-overlay section calls
## for exactly this ("a puddle briefly reads as a sea... a crack in the
## pavement becomes a canyon or river") but it had never been built. Being
## ON a stone is the ordinary, calm read (no cue); being in the ground
## between them, while still among the stones, briefly nudges perception
## the way a child crossing "the floor is lava" would feel it.
##
## Pure poller: WorldAffordances.stone_index_at()/in_stones_region() are
## side-effect-free queries against the player's existing x/z, so this
## never touches collision, navigation, or movement -- only
## perception.gd's bounded, additive imagination-cue channel (see that
## file's "Gate 0 -- IMAGINATION CUE" doc comment). No fail state: leaving
## the region or stepping back onto a stone simply eases the cue back out.

@onready var _perception: Node = get_parent().find_child("Perception", true, false) if get_parent() != null else null

## Tracks the previous tick's state so the "wonder" chime fires once on the
## rising edge (stepping off a stone into the gap), not every tick spent
## there -- same one-shot-on-entry pattern puddles.gd uses for its splash.
## The chime exists because a purely visual cue this restrained (see
## perception.gd's own doc comment on why it was widened once already)
## still risks going unnoticed; a small sound is cheap insurance that the
## moment actually registers.
var _cue_was_active: bool = false


func _physics_process(_delta: float) -> void:
	if _perception == null or not is_instance_valid(Game.player):
		return
	var p := Game.player.global_position
	var in_region := WorldAffordances.in_stones_region(p.x, p.z)
	var on_stone := WorldAffordances.stone_index_at(p.x, p.z) >= 0
	var active := in_region and not on_stone

	if active and not _cue_was_active:
		AudioDirector.play_chime("wonder")
	_cue_was_active = active

	_perception.set_imagination_target(active)
