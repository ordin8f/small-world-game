extends Node
## Verbatim-intent port of src/audio.mjs's AudioDirector: three continuous
## sine drones with mood-driven gain, one-shot chimes on dispatch, and a
## footstep tick while the player moves.
##
## Web Audio's live-oscillator-graph approach has no direct Godot
## equivalent without either raw sample-pushing (AudioStreamGenerator --
## the plan itself flagged its web latency as [VERIFY], and it needs a
## _process-driven fill loop per voice) or the approach used here: bake
## short AudioStreamWAV clips once and drive them through ordinary
## AudioStreamPlayer nodes. The three drones loop a single seamed period
## of their sine tone and have their volume continuously smoothed
## (CameraProfile.damp's exact exponential form, matching JS's
## setTargetAtTime); chimes and the footstep tick synthesize their whole
## short waveform once per trigger and play it as a one-shot -- several
## orders of magnitude cheaper than continuous buffer-pushing for tones
## this simple, and avoids the flagged latency risk entirely.
##
## All gain values below are the source's own raw linear amplitudes
## (game.mjs/audio.mjs), baked into each clip's PCM (or, for the
## continuously-smoothed drones, applied via volume_db every frame) --
## never pre-multiplied by MASTER_GAIN, exactly mirroring the source's
## own signal chain (voice gain node -> master gain node -> destination).

const SAMPLE_RATE := 44100
const MASTER_GAIN := 0.28
const MOOD_GAIN_LAMBDA := 1.0 / 0.8   # setTargetAtTime's 0.8s time constant
const MUTE_GAIN_LAMBDA := 1.0 / 0.04  # setTargetAtTime's 0.04s time constant

const DRONE_FREQUENCIES := [92.0, 138.0, 207.0]

const CHIME_KINDS := {
	"soft": {"frequencies": [329.63, 440.0], "triangle": false, "peak": 0.055},
	"warm": {"frequencies": [392.0, 523.25, 659.25], "triangle": false, "peak": 0.055},
	"uneasy": {"frequencies": [220.0, 233.08], "triangle": true, "peak": 0.035},
}
const CHIME_START_STAGGER := 0.08  # note_start = index * this
const CHIME_ATTACK := 0.03         # linear ramp to peak, note_start .. note_start + this
const CHIME_TAIL_BASE := 0.7       # exponential decay to ~0, note_start+ATTACK .. note_start+this+index*CHIME_TAIL_STAGGER
const CHIME_TAIL_STAGGER := 0.12
const CHIME_FLOOR := 0.0001        # exponentialRampToValueAtTime's target

const STEP_DURATION := 0.09
const STEP_DECAY := 0.08
const STEP_PEAK := 0.025
const STEP_INTERVAL_RUNNING := 0.25
const STEP_INTERVAL_WALKING := 0.37
const STEP_FREQUENCY_RUNNING := 82.0
const STEP_FREQUENCY_WALKING := 68.0

var _started: bool = false
var _drone_players: Array = []          # AudioStreamPlayer, one per DRONE_FREQUENCIES
var _drone_target_gain: Array = [0.0, 0.0, 0.0]
var _drone_current_gain: Array = [0.0, 0.0, 0.0]
var _master_current_gain: float = 0.0
var _chime_player: AudioStreamPlayer
var _step_player: AudioStreamPlayer
var _last_step_time: float = -1000.0


## Idempotent, matching AudioDirector.start()'s own `if (this.context)
## return`. Called from Game.start_episode() -- audio.mjs's own call site
## (game.mjs's begin()) needs the same "only after a user gesture" timing
## browsers require for audio, which "Begin the afternoon" already
## satisfies; "Play again" calling this again is a harmless no-op, same
## as the source (resetGame() never touches audio at all).
func start() -> void:
	if _started:
		return
	_started = true
	_master_current_gain = MASTER_GAIN

	_chime_player = AudioStreamPlayer.new()
	add_child(_chime_player)
	_step_player = AudioStreamPlayer.new()
	add_child(_step_player)

	for frequency in DRONE_FREQUENCIES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.stream = _make_loop_tone(frequency)
		player.volume_db = -80.0
		player.play()
		_drone_players.append(player)


func _process(delta: float) -> void:
	if not _started:
		return
	var mute_target := 0.0 if Game.muted else MASTER_GAIN
	_master_current_gain = CameraProfile.damp(_master_current_gain, mute_target, MUTE_GAIN_LAMBDA, delta)

	for i in range(_drone_players.size()):
		_drone_current_gain[i] = CameraProfile.damp(_drone_current_gain[i], _drone_target_gain[i], MOOD_GAIN_LAMBDA, delta)
		var linear: float = _drone_current_gain[i] * _master_current_gain
		_drone_players[i].volume_db = _linear_to_db_safe(linear)


## game.mjs:376-382's audio.setMood(value) -- `lens_value` is
## EmotionalLens.value ({comfort, energy, curiosity}).
func set_mood(lens_value: Dictionary) -> void:
	if not _started:
		return
	var comfort: float = lens_value["comfort"]
	var energy: float = lens_value["energy"]
	for i in range(DRONE_FREQUENCIES.size()):
		_drone_target_gain[i] = mood_gain(i, comfort, energy)


## audio.mjs:42-47's per-voice target gain formula, factored out as a
## pure function for direct unit testing (this Node's other behavior is
## side-effecting audio playback, covered by play tests instead).
static func mood_gain(drone_index: int, comfort: float, energy: float) -> float:
	return 0.004 + drone_index * 0.0015 + comfort * 0.006 + energy * 0.002


## game.mjs:195-201's audio.chime(kind) call, on every successful dispatch.
func play_chime(kind: String) -> void:
	if not _started or Game.muted:
		return
	_chime_player.stream = _make_chime_wav(kind)
	_chime_player.volume_db = _linear_to_db_safe(_master_current_gain)
	_chime_player.play()


## game.mjs:357's audio.step(now, running), called every physics tick the
## player is actually moving; self-rate-limits exactly like the source.
func play_step(running: bool) -> void:
	if not _started or Game.muted:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var interval := STEP_INTERVAL_RUNNING if running else STEP_INTERVAL_WALKING
	if now - _last_step_time < interval:
		return
	_last_step_time = now
	_step_player.stream = _make_step_wav(running)
	_step_player.volume_db = _linear_to_db_safe(_master_current_gain)
	_step_player.play()


func _linear_to_db_safe(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return linear_to_db(linear)


## A single seamed period of a sine wave, looped -- CPU-free after this
## one-time synthesis. The loop length is rounded to the nearest sample,
## so the played frequency is off by a fraction of a percent from
## `frequency`; inaudible, and standard practice for a seamless loop.
func _make_loop_tone(frequency: float) -> AudioStreamWAV:
	var period_samples := maxi(2, int(round(SAMPLE_RATE / frequency)))
	var floats := PackedFloat32Array()
	floats.resize(period_samples)
	for i in range(period_samples):
		floats[i] = sin(float(i) / float(period_samples) * TAU)
	var wav := _floats_to_wav(floats)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = period_samples
	return wav


## audio.mjs:50-67's chime(kind), pre-rendered to a single one-shot clip.
## Each note's envelope is: silence, then a CHIME_ATTACK linear ramp to
## peak, then an exponential decay to CHIME_FLOOR -- ported exactly,
## including the source's own mismatched attack/decay stagger (attack
## timing steps by CHIME_START_STAGGER per note, decay END timing steps
## by the different CHIME_TAIL_STAGGER; both anchored to the same
## chime-trigger "now", not to each other).
func _make_chime_wav(kind: String) -> AudioStreamWAV:
	var def: Dictionary = CHIME_KINDS[kind]
	var frequencies: Array = def["frequencies"]
	var peak: float = def["peak"]
	var triangle: bool = def["triangle"]

	var last_index := frequencies.size() - 1
	var last_tail_end: float = CHIME_TAIL_BASE + last_index * CHIME_TAIL_STAGGER
	var total_duration: float = last_index * CHIME_START_STAGGER + last_tail_end + 0.05
	var total_samples := int(ceil(total_duration * SAMPLE_RATE))
	var floats := PackedFloat32Array()
	floats.resize(total_samples)

	for index in range(frequencies.size()):
		var frequency: float = frequencies[index]
		var note_start: float = index * CHIME_START_STAGGER
		var attack_end: float = note_start + CHIME_ATTACK
		var tail_end: float = note_start + CHIME_TAIL_BASE + index * CHIME_TAIL_STAGGER
		var start_sample := int(note_start * SAMPLE_RATE)
		var end_sample := mini(int(tail_end * SAMPLE_RATE) + 1, total_samples)
		for s in range(start_sample, end_sample):
			var t := float(s) / SAMPLE_RATE
			var envelope: float
			if t < attack_end:
				envelope = peak * ((t - note_start) / CHIME_ATTACK)
			else:
				var ramp_t: float = (t - attack_end) / (tail_end - attack_end)
				envelope = peak * pow(CHIME_FLOOR / peak, clampf(ramp_t, 0.0, 1.0))
			var phase := (t - note_start) * frequency
			var wave := _triangle(phase) if triangle else sin(phase * TAU)
			floats[s] += wave * envelope

	return _floats_to_wav(floats)


## audio.mjs:69-83's step(now, running), pre-rendered to a one-shot clip.
func _make_step_wav(running: bool) -> AudioStreamWAV:
	var frequency := STEP_FREQUENCY_RUNNING if running else STEP_FREQUENCY_WALKING
	var total_samples := int(ceil(STEP_DURATION * SAMPLE_RATE))
	var floats := PackedFloat32Array()
	floats.resize(total_samples)
	for s in range(total_samples):
		var t := float(s) / SAMPLE_RATE
		var envelope: float
		if t < STEP_DECAY:
			envelope = STEP_PEAK * pow(CHIME_FLOOR / STEP_PEAK, t / STEP_DECAY)
		else:
			envelope = CHIME_FLOOR
		floats[s] = _triangle(t * frequency) * envelope
	return _floats_to_wav(floats)


static func _triangle(phase_in_cycles: float) -> float:
	var x := fposmod(phase_in_cycles, 1.0)
	return 4.0 * absf(x - 0.5) - 1.0


func _floats_to_wav(floats: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(floats.size() * 2)
	for i in range(floats.size()):
		var v := int(round(clampf(floats[i], -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
