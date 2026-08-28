class_name InteractionZone
extends Node3D
## One node per trigger from game.mjs's nearestInteraction() (lines
## 170-188), which is a plain 2D Euclidean-distance check against the
## player -- not a physics trigger volume, despite the source's radii
## reading like collider sizes. Ported verbatim as the same distance
## check rather than an Area3D: an Area3D + CollisionShape3D version was
## tried first and reliably produced "possible orphan nodes" warnings and
## an intermittent multi-minute hang later in the same test run (repro'd
## via tools/test.sh; isolated 2-3 suite subsets never hung, only the
## full run did, inconsistently) -- consistent with Area3D's monitoring
## state needing an extra physics step to clear after node removal, which
## a synchronous scene teardown (as gdUnit4's SceneRunner does) doesn't
## wait for. A plain distance check has no physics-server state at all,
## so there's nothing to leak.
##
## Game.gd polls every registered zone each physics tick and treats one
## as "active" only when its required_state matches the current
## EpisodeDirector state AND the player is within radius -- multiple
## zones can overlap without conflict since at most one state is ever
## current.
##
## event_name/required_state/label/radius are looked up by node .name
## rather than set as @export properties on each instance: the
## main-scene generator instantiates this template inside a bare
## `--script` run, where loading this very script fails to compile
## ("Identifier not found: Game", same cause as player.tscn/
## camera_rig.tscn's generators -- see their doc comments) and so can't
## set script-exported properties at generation time. .name is a plain
## Node property, unaffected by that, and always resolves correctly once
## the scene runs for real.

const ZONE_DATA := {
	"Watch": {"event_name": "observe", "required_state": "ARRIVE", "label": "Watch the children", "radius": 2.3},
	"BallEnd": {"event_name": "ball_picked_up", "required_state": "FIND_BALL", "label": "Pick up the ball", "radius": 1.45},
	"Return": {"event_name": "ball_returned", "required_state": "RETURN_BALL", "label": "Give the ball back", "radius": 2.1},
	"Join": {"event_name": "joined", "required_state": "INVITED", "label": "Join the circle", "radius": 2.2},
	"Door": {"event_name": "entered_home", "required_state": "GO_HOME", "label": "Go inside", "radius": 1.8},
}

var event_name: String = ""
var required_state: String = ""
var label: String = ""
var radius: float = 0.0


func _ready() -> void:
	var data: Dictionary = ZONE_DATA[name]
	event_name = data["event_name"]
	required_state = data["required_state"]
	label = data["label"]
	radius = data["radius"]
	Game.register_zone(self)


func _exit_tree() -> void:
	# Game.zones is a persistent autoload array; a test suite that spins up
	# and tears down scene_runner("res://scenes/main.tscn") more than once
	# (M2.2's own test does, on top of M1.3/M1.4's) would otherwise leave
	# stale entries behind for every run after the first.
	Game.unregister_zone(self)


## game.mjs:166-168's distance2D() -- x/z only, matching the source
## (world height is irrelevant to these triggers).
func player_overlapping() -> bool:
	var player := Game.player
	if not is_instance_valid(player):
		return false
	var p := player.global_position
	var here := global_position
	return Vector2(p.x - here.x, p.z - here.z).length() < radius
