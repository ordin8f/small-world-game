extends Node
## Game -- top-level orchestration autoload.
##
## Owns the EpisodeDirector/EmotionalLens instances, the dispatch() switch
## and its three timers (verbatim port of src/game.mjs:192-236), and the
## interaction-zone polling that feeds interact(). Player/camera position
## mirrors whatever nodes the running scene currently considers "the
## player"/"the play camera" (both null before M1.3/M1.4's scenes exist).
##
## Ball state, HUD rendering, and fog/light perception are later
## milestones (M2.3-M2.5) that react to this autoload's signals rather
## than living inside it.

signal state_changed(new_state: String)
signal dialogue_shown(speaker: String, text: String, duration: float)
signal prompt_changed(label: String)
signal episode_complete

const DIALOGUES := {
	"arrival": ["Other children", "They are playing the circle game again."],
	"watch": ["Mina", "It only counts if it stays inside the chalk."],
	"kick": ["Arun", "Oh—no. It went through the garden gap."],
	"pickup": ["You", "It is muddier than it looked from far away."],
	"return": ["Mina", "You found it. You can roll first."],
	"join": ["Arun", "Stand here. Not too close. Ready?"],
	"mother": ["Mom, somewhere above", "Honey, the light is going. Come home now."],
	"home": ["You", "Tomorrow, they might already be waiting."],
}

var player: Node3D = null
var camera: Camera3D = null
var ball: Node3D = null

## Set by title_camera.gd's _ready() (Gate 0 frame, S1); null once no
## title sequence is active. A plain reference, same pattern as
## player/camera/ball above -- title_card.gd reaches through this to
## trigger the Play glide without either script needing to know the
## other's node path.
var title_camera: Node3D = null

## Gate 0 frame: the four new/rewritten screens (S1/S6/S7/S8), each set by
## its own _ready(), same cross-reference pattern as title_camera above --
## lets title_card.gd/ending_screen.gd/credits_screen.gd/pause_menu.gd hand
## off to each other (Play -> gameplay, Credits -> Title, ending -> Credits,
## pause -> Restart) without any of them knowing another's scene path.
var title_card: CanvasLayer = null
var credits_screen: CanvasLayer = null
var ending_screen: CanvasLayer = null
var pause_menu: CanvasLayer = null

var director: EpisodeDirector = EpisodeDirector.new()
var lens: EmotionalLens = EmotionalLens.new()
var run_id: int = 0

var zones: Array = []
var active_zone: Node = null

## UI-facing toggles (hud.gd's Sound/Reduce-motion buttons). reduced_motion
## is consumed directly by camera_rig.gd; muted is a flag ready for M2.5's
## audio to read once it exists (game.mjs's audio.setMuted mirror).
var reduced_motion: bool = false
var muted: bool = false

## Gate 0 frame (S7 credits / S1 title): DEMO_PLAN.md's only sanctioned
## save -- "a 'completed once' flag; nothing more" (PRODUCT_CONTRACT.md
## bans saves beyond exactly this). Persisted to disk (not just this
## run's memory) so a relaunch after finishing once still opens on the
## dusk title -- see _present_as_completed()'s doc comment for how.
const SAVE_PATH := "user://progress.cfg"
var completed_once: bool = false

## Gate 0 frame (S6 ending): how many of the three optional pocket
## treasures (DEMO_PLAN.md S3, Act 2/garden -- not yet built, tracked by
## nothing today) the player has found this run. Always 0 until that
## pickup mechanic exists; ending_screen.gd is written to render 0..3
## correctly regardless, per the brief ("the shot must work either way").
## Clamped through the setter rather than trusted as a bare field so nothing
## downstream needs to re-check the 0..3 bound itself.
var treasures_found: int = 0


func _ready() -> void:
	completed_once = _load_completed_flag()
	if completed_once:
		_present_as_completed()


func set_treasures_found(count: int) -> void:
	treasures_found = clampi(count, 0, 3)


## Called once, when episode_complete actually fires (ending_screen.gd).
## Idempotent: re-completing a later run just re-saves the same value.
func mark_completed() -> void:
	completed_once = true
	_save_completed_flag()


## Reused at two call sites: here at boot (a *previous* session's
## completion, loaded from disk) and, in principle, anywhere else that
## wants "present the title the way it looks right after finishing" --
## today just boot. Sets director.state directly rather than going through
## dispatch()/start() -- this is presentation only, before any real episode
## has begun, and start_episode() (the Play button) always replaces
## `director` with a brand-new EpisodeDirector (state ARRIVE) regardless of
## what state it was left in, so this can never leak into real gameplay.
## The payoff is free: perception.gd's mood arc and home_glow.gd's pulse
## both already key off director.state, so COMPLETE alone gets both "dusk"
## and "porch light on" with no new lighting/glow code at all.
func _present_as_completed() -> void:
	director.state = EpisodeDirector.State.COMPLETE


func _load_completed_flag() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return bool(cfg.get_value("progress", "completed_once", false))


func _save_completed_flag() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "completed_once", true)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		printerr("game.gd: failed to save %s: %s" % [SAVE_PATH, err])


func _physics_process(_delta: float) -> void:
	_update_active_zone()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact()


## game.mjs's begin()/resetGame() both funnel through here -- HUD's title
## card (M2.4) calls this on "Begin the afternoon"; restart calls it again.
## `now < 0` (the default) means "use the real clock"; tests pass an
## explicit value the same way the ported JS tests pass one to start(0).
func start_episode(now: float = -1.0) -> void:
	AudioDirector.start()
	run_id += 1
	director = EpisodeDirector.new()
	director.start(now if now >= 0.0 else _now_seconds())
	lens = EmotionalLens.new()
	active_zone = null
	state_changed.emit(director.state)
	dialogue_shown.emit(DIALOGUES["arrival"][0], DIALOGUES["arrival"][1], 3.5)


func reset(now: float = -1.0) -> void:
	start_episode(now)


func register_zone(zone: Node) -> void:
	zones.append(zone)


func unregister_zone(zone: Node) -> void:
	zones.erase(zone)
	if active_zone == zone:
		active_zone = null


## game.mjs:192-236 -- dispatch(), verbatim, minus the ball/audio side
## effects that belong to ball.gd/perception.gd (M2.3/M2.5), which react
## to state_changed instead.
func dispatch(event_name: String) -> bool:
	if not director.dispatch(event_name, _now_seconds()):
		return false
	state_changed.emit(director.state)

	# game.mjs:195-201 -- keyed on the event that fired, not the state
	# reached.
	var chime_kind := "soft"
	if event_name == "ball_kicked":
		chime_kind = "uneasy"
	elif event_name == "ball_returned" or event_name == "entered_home":
		chime_kind = "warm"
	AudioDirector.play_chime(chime_kind)

	match director.state:
		EpisodeDirector.State.OBSERVED:
			_show_dialogue("watch", 3.2)
			var scheduled_run := run_id
			schedule(func() -> void:
				if scheduled_run == run_id:
					dispatch("ball_kicked")
			, 2.6)
		EpisodeDirector.State.BALL_IN_FLIGHT:
			_show_dialogue("kick", 2.6)
		EpisodeDirector.State.RETURN_BALL:
			_show_dialogue("pickup", 3.2)
		EpisodeDirector.State.INVITED:
			_show_dialogue("return", 3.7)
		EpisodeDirector.State.GO_HOME:
			_show_dialogue("join", 3.2)
			schedule(func() -> void: _show_dialogue("mother", 4.2), 3.0)
		EpisodeDirector.State.COMPLETE:
			_show_dialogue("home", 2.5)
			schedule(func() -> void: episode_complete.emit(), 1.9)
	return true


func interact() -> void:
	if active_zone != null:
		dispatch(active_zone.event_name)


## Fires `callable` after `delay_secs`, scaled by Engine.time_scale (tests
## accelerate via Engine.time_scale, matching game.mjs's runId-guarded
## window.setTimeout -- callers that need the runId guard, like the
## ball_kicked timer above, capture run_id themselves before scheduling).
func schedule(callable: Callable, delay_secs: float) -> void:
	get_tree().create_timer(delay_secs).timeout.connect(callable)


func debug_state() -> Dictionary:
	var player_pos := Vector3.ZERO
	if is_instance_valid(player):
		player_pos = player.global_position

	var camera_pos = null
	if is_instance_valid(camera):
		var c := camera.global_position
		camera_pos = {"x": c.x, "y": c.y, "z": c.z}

	var ball_pos = null
	if is_instance_valid(ball):
		var b := ball.global_position
		ball_pos = {"x": b.x, "y": b.y, "z": b.z}

	return {
		"state": director.state,
		"beat_index": director.history.size() - 1,
		"player_pos": {"x": player_pos.x, "y": player_pos.y, "z": player_pos.z},
		"comfort": lens.value["comfort"],
		"energy": lens.value["energy"],
		"curiosity": lens.value["curiosity"],
		"dominant_emotion": EmotionalLens.dominant_emotion(lens.value),
		"camera_pos": camera_pos,
		"ball_pos": ball_pos,
	}


func _show_dialogue(key: String, duration: float) -> void:
	var pair: Array = DIALOGUES[key]
	dialogue_shown.emit(pair[0], pair[1], duration)


func _update_active_zone() -> void:
	var found: Node = null
	for zone in zones:
		if not is_instance_valid(zone):
			continue  # defensive: _exit_tree()/unregister_zone() should already prevent this
		if zone.required_state == director.state and zone.player_overlapping():
			found = zone
			break
	if found != active_zone:
		active_zone = found
		prompt_changed.emit(found.label if found != null else "")


func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
