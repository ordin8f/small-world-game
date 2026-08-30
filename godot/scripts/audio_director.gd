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
	# Gate 0: stepping_stones.gd's imagination cue -- a brighter, higher
	# register than the three dispatch chimes above (which this is
	# deliberately NOT one of; it never runs through game.gd's dispatch()
	# switch), so it reads as a small private moment of wonder rather than
	# a story beat landing.
	"wonder": {"frequencies": [523.25, 659.25, 783.99], "triangle": false, "peak": 0.045},
	# Gate 1 (mechanics agent): pocket_treasure.gd's pickup and
	# sandbox.gd's finished-castle flag -- a clean rising fifth, its own
	# small identity distinct from "wonder" (stepping_stones.gd/
	# imagination_prop.gd's transform cue) and from the three dispatch
	# chimes above, so "you found/finished something" never gets confused
	# with either of those other meanings.
	"keepsake": {"frequencies": [587.33, 880.0], "triangle": false, "peak": 0.04},
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

## Gate 0: two new one-shot affordance sounds, same "bake a short
## AudioStreamWAV once per trigger" approach as chimes/steps above rather
## than a live effect graph -- see this file's class doc comment for why.
## Splash (puddles.gd): a short broadband-noise burst -- a splash's
## dominant character -- plus two brighter droplet "plip" blips staggered
## just after the main hit.
const SPLASH_NOISE_DURATION := 0.28
const SPLASH_NOISE_PEAK := 0.05
const SPLASH_NOISE_DECAY := 0.14
const SPLASH_DROPLETS := [{"start": 0.05, "freq": 900.0}, {"start": 0.12, "freq": 650.0}]
const SPLASH_DROPLET_PEAK := 0.032
const SPLASH_DROPLET_DECAY := 0.09
## Slide whoosh (player.gd's _start_slide()): a soft noise sweep, rising
## then falling across the whole ride, smoothed with a cheap one-pole
## lowpass so it reads as air/wind rather than harsh static.
const WHOOSH_DURATION := 0.9
const WHOOSH_PEAK := 0.045
const WHOOSH_SMOOTHING := 0.06

## Gate 1 (mechanics agent): sandbox.gd's pat-the-sand tap. Reuses the
## whoosh's own "smoothed noise" technique (a cheap one-pole lowpass over
## white noise) but much shorter and duller -- SAND_PAT_SMOOTHING is a
## larger blend factor than WHOOSH_SMOOTHING, so LESS high-frequency
## content survives, which reads as a soft thud rather than sustained air.
const SAND_PAT_DURATION := 0.16
const SAND_PAT_PEAK := 0.045
const SAND_PAT_DECAY := 0.07
const SAND_PAT_SMOOTHING := 0.12
## Gate 1: swing.gd's bottom-of-the-arc creak -- a short, low triangle
## blip with a downward pitch slide (CREAK_FREQUENCY * a factor that eases
## from 1.3x to 1x across the same span the envelope decays over), which
## is what makes a synthesized tone read as a creak instead of a clean
## note.
const CREAK_DURATION := 0.22
const CREAK_PEAK := 0.03
const CREAK_DECAY := 0.1
const CREAK_FREQUENCY := 145.0

## ===========================================================================
## MUSIC (2026-08-30)
## ===========================================================================
## Synthesised here rather than vendored, for one reason that matters more
## than the licensing convenience: a downloaded loop plays the same at 2pm
## and at dusk, and this game's whole thesis is that the world changes with
## how the child feels. The music is driven by the same authored mood arc
## perception.gd already uses for light.
##
## KEY. The three ambience drones above are F#2/C#3/G#3 -- a quartal stack in
## F#. Every *positive* chime, though, is drawn from C major pentatonic:
## soft E/A, warm G/C/E, wonder C/E/G, keepsake D/A. (Only "uneasy" sits
## outside, deliberately.) Measured, the drone bed is -62 dBFS A-weighted --
## effectively subliminal -- while the chimes peak at -33 dBFS. So the music
## agrees with the chimes, not the drones: every story beat then lands
## consonantly inside the music instead of against it.
##
## That does leave the music a tritone from the drones, so there are real
## semitone collisions on paper -- C3 against C#3, G3 against G#3. Beating
## between two tones is bounded by the quieter of them, and the quieter here
## is an individual pad partial at about -62 dBFS, the quietest thing in the
## mix and ~30 dB under the chimes. Retuning the drones to C/G/E would remove
## it outright, but they work, they are tested, and nobody asked.
##
## STRUCTURE. Two layers, no baked "track" anywhere:
##
##  * A PAD of eight sustained voices in an open A2..D5 voicing, each a
##    single seamless multi-period loop (see _make_pad_loop). The mix moves
##    along the mood arc as a relative-key pivot -- C major add9 in the
##    afternoon (C3 E3 G3 C4 E4 D5) settling into A minor 9 at dusk
##    (A2 E3 G3 C4 E4 B4), with E3/G3/C4/E4 held as common tones so it reads
##    as the light changing rather than as a key change. The four upper
##    voices each get a second player detuned by ~4.3 cents; the two loops
##    drift against each other forever, which is where the warmth comes from
##    and which no finite loop could give you. The low voices stay untwinned
##    (tight bass, wide top -- ordinary mixing practice).
##
##  * A MELODY of sparse music-box notes: authored one- to four-note phrases
##    from the same pentatonic scale, separated by 4.5-8.5 s of silence
##    before the comfort and jitter multipliers below widen that to roughly
##    3-14 s. Not a tune; single gestures with a lot of air around them.
##
## LEVEL. Measured on the rendered output (tools/_probe_music.gd, afternoon,
## 45 s): RMS -56.5 dBFS, A-weighted -60.2, peak -42.3. That is 6.8 dB under
## the drone bed on flat RMS and 10.4 dB under the chimes' peak, so a story
## beat always cuts through.
##
## The one number that does not flatter it: A-weighted, the music is 2.3 dB
## LOUDER than the drone bed, because it lives at 200-800 Hz where the ear
## works and the drones sit at 92-207 Hz where it does not. That is
## deliberate -- matching the drones perceptually would mean inaudible music
## -- but it is the honest reading of "sits under the ambience", so it is
## written down here rather than left to the flattering measure.
##
## MUSIC_GAIN below is the single dial if it wants to be louder or quieter;
## nothing else needs touching.
const MUSIC_GAIN := 1.0

## Peak-normalised waveforms are baked at full scale and the level is set
## through volume_db (the same thing _make_loop_tone already does), because
## baking a -55 dBFS waveform into 16 bits would leave it about 8 bits of
## resolution and audibly grainy.
const PAD_LEVEL := 0.00315     # pre-master linear, per player
const MELODY_LEVEL := 0.01275  # pre-master linear, per note

## A soft, fast-rolling-off harmonic series: warm, and with nothing above the
## sixth harmonic there is no high-frequency content to turn harsh.
const PAD_PARTIALS := [1.0, 0.30, 0.12, 0.055, 0.025, 0.012]

## Each pad voice loops ONE buffer of a whole number of cycles. Asking for at
## least this many samples means the rounding error is spread over ~10-50
## periods instead of one, which drops the tuning error from the ~8 cents
## _make_loop_tone accepts for a sub-audible drone to under 0.2 cents -- the
## difference between a chord that beats sourly and one that does not.
const PAD_LOOP_MIN_SAMPLES := 4000

const PAD_DETUNE := 0.0025       # ~4.3 cents
const PAD_BREATH_DEPTH := 0.28
## Mutually incommensurate, so the chord's internal balance never repeats.
const PAD_BREATH_RATES := [0.041, 0.053, 0.067, 0.031, 0.073, 0.059, 0.037, 0.047]

## mix is [afternoon, golden, dusk] -- see the relative-key pivot above.
const PAD_VOICES := [
	{"name": "A2", "frequency": 110.00, "mix": [0.00, 0.30, 0.55], "detune": false},
	# Fades to exactly zero rather than to a trace: _linear_to_db_safe()'s
	# -80 dB floor cuts in at 0.0001 linear, which at these levels is a mix
	# of about 0.11, so anything below that is silent in fact whatever the
	# table says. Better for the table to say what happens. C4 still carries
	# the minor third at dusk, so losing the low C only opens the bass up.
	{"name": "C3", "frequency": 130.81, "mix": [0.55, 0.40, 0.00], "detune": false},
	{"name": "E3", "frequency": 164.81, "mix": [0.45, 0.48, 0.45], "detune": false},
	{"name": "G3", "frequency": 196.00, "mix": [0.35, 0.42, 0.35], "detune": false},
	{"name": "C4", "frequency": 261.63, "mix": [0.85, 0.90, 0.72], "detune": true},
	{"name": "E4", "frequency": 329.63, "mix": [0.80, 0.85, 0.75], "detune": true},
	{"name": "B4", "frequency": 493.88, "mix": [0.00, 0.40, 0.75], "detune": true},
	{"name": "D5", "frequency": 587.33, "mix": [0.75, 0.40, 0.00], "detune": true},
]

## Fractional loop positions the twelve pad players start from. Without these
## every voice would be phase-aligned at t=0 and the music would arrive as one
## in-phase thump instead of fading up out of nothing. Fixed rather than
## random so a render is reproducible.
const PAD_START_OFFSETS := [0.00, 0.37, 0.13, 0.61, 0.29, 0.83,
	0.47, 0.07, 0.71, 0.23, 0.91, 0.53]

## Music-box / celesta: harmonic partials with two slightly stretched upper
## ones (what makes a tone read as struck metal rather than as an organ), a
## raised-cosine attack too short to hear but long enough that there is no
## step discontinuity, and upper partials decaying faster than the fundamental.
## Columns: frequency multiple, amplitude, decay-time multiple.
const NOTE_PARTIALS := [
	[1.00, 1.000, 1.00], [2.00, 0.380, 0.55], [3.00, 0.150, 0.36],
	[4.16, 0.075, 0.26], [5.43, 0.030, 0.18],
]
const NOTE_ATTACK := 0.006
const NOTE_DECAY := 1.6      # fundamental time constant, seconds
const NOTE_LENGTH := 2.8
## The exponential never actually reaches zero, so the last stretch is faded
## out on a raised cosine. Without it every note would end on a step of ~0.24
## of its peak -- a click on all ten pitches.
const NOTE_TAIL_FADE := 0.6

## A minor / C major pentatonic across two octaves.
const MUSIC_SCALE := [220.00, 261.63, 293.66, 329.63, 392.00,
	440.00, 523.25, 587.33, 659.25, 783.99]

## Authored phrases, as [scale step above the base, onset in seconds, level].
## Deliberately short and mostly falling, with one single-note phrase, so the
## layer says almost nothing most of the time.
##
## The level column is what stops this sounding sequenced. Notes at identical
## velocity is the most recognisable tell of synthetic music, and it costs a
## column to fix: every phrase arrives on its strongest note and softens
## through, the way a person playing to themselves would. Nothing exceeds
## 1.0, so MELODY_LEVEL stays the ceiling.
const MUSIC_PHRASES := [
	[[0, 0.00, 1.00], [2, 0.85, 0.80], [3, 1.70, 0.62]],
	[[3, 0.00, 0.92], [1, 0.70, 0.75], [0, 1.75, 0.58]],
	[[2, 0.00, 0.85], [4, 1.10, 0.70]],
	[[0, 0.00, 0.78]],
	[[4, 0.00, 0.88], [3, 0.60, 0.72], [1, 1.35, 0.62], [2, 2.45, 0.55]],
	[[1, 0.00, 0.82], [2, 0.95, 0.68]],
]

## Where in MUSIC_SCALE a phrase starts, per mood: the upper octave through
## the afternoon, dropping to the lower one at dusk.
const MELODY_BASE := [5.0, 5.0, 0.0]
## Seconds of silence between phrases -- the "tempo easing" as the light goes.
const MELODY_REST := [4.5, 5.8, 8.5]
## The dusk phrases sit an octave lower, where the ear is less sensitive;
## without this they lose ~7 dB A-weighted and disappear. A lower note played
## a little harder, which is what a person would do anyway.
const MELODY_LEVEL_BY_MOOD := [1.0, 1.15, 1.5]
## Comfort stretches or shrinks the rest. A child on the edge of the game
## gets more silence; when the circle opens the phrases come back. Bounded
## hard so "lonely" can never mean "the music stopped".
const MELODY_REST_BY_COMFORT := [1.35, 0.80]
## Enough melody players that a four-note phrase can overlap itself -- notes
## ring for NOTE_LENGTH but arrive 0.6 s apart.
const MELODY_VOICES := 4
## How long the melody keeps quiet after a dispatch chime, so a story beat
## gets clear air instead of competing with a note.
const MELODY_CHIME_YIELD := 2.0
## Slow enough that the music is never heard to start.
const MUSIC_FADE_LAMBDA := 1.0 / 3.0

## What a music player's volume_db is set to when its voice is off or muted.
##
## NOT _linear_to_db_safe()'s -80. That floor was written for three drones and
## three idle one-shot players, where the residual summed to about -75 dBFS on
## the master bus. The music adds sixteen more players, and sixteen more voices
## sitting at -80 dB each raise that floor by roughly 11 dB -- measured on
## Godot's own bus meter (tools/_probe_music_live.gd), muting went from about
## -75 to -64 dBFS once this layer existed. Inaudible either way, but it is a
## regression to a control the player pressed deliberately, so the music floors
## itself far enough down that sixteen of them still total less than one drone
## did. Nothing else in the file changes; -80 stays right for everything that
## was already there.
const MUSIC_SILENCE_DB := -120.0

var _started: bool = false
var _drone_players: Array = []          # AudioStreamPlayer, one per DRONE_FREQUENCIES
var _drone_target_gain: Array = [0.0, 0.0, 0.0]
var _drone_current_gain: Array = [0.0, 0.0, 0.0]
var _master_current_gain: float = 0.0
var _chime_player: AudioStreamPlayer
var _step_player: AudioStreamPlayer
var _effect_player: AudioStreamPlayer  # splash/whoosh -- kept off the chime player so a
                                        # puddle splash can never cut off a dispatch chime
var _last_step_time: float = -1000.0

## Gate 0 frame (S8 pause): kept distinct from Game.muted (the persistent,
## user-facing Sound on/off toggle) so pausing/resuming can never flip that
## button's own displayed state or fight a player who muted deliberately --
## duck() only affects the transient pause-time gain target below.
var _ducked: bool = false

## --- music state -----------------------------------------------------------
var _pad_players: Array = []       # AudioStreamPlayer, 12 of them
var _pad_voice_index: Array = []   # parallel to _pad_players: which PAD_VOICES entry
var _melody_players: Array = []    # AudioStreamPlayer pool, MELODY_VOICES of them
## Pre-master linear gain of whatever each melody player is currently ringing,
## so _update_music can keep re-applying _master_current_gain to it. Without
## this a note that was already sounding when the player hit mute (or paused)
## would ring on for up to NOTE_LENGTH at its original level -- the pad and
## the drones are silenced continuously and the notes have to be too.
var _melody_gain: Array = []
var _melody_next: int = 0
var _music_time: float = 0.0       # seconds since start(), drives the breathing LFOs
var _music_fade: float = 0.0       # 0..1, so the music arrives rather than switches on
var _music_mood: float = 0.0       # 0 afternoon .. 0.5 golden .. 1 dusk
var _music_comfort: float = 0.5
var _pending_notes: Array = []     # [{"at": float, "frequency": float}], ascending
var _next_phrase_time: float = 6.0
var _last_phrase: int = -1
var _music_rng := RandomNumberGenerator.new()

## Baking the ten melody pitches costs ~0.9 s of GDScript (measured:
## tools/_probe_synth_cost.gd), which would be a visible hitch on the frame
## the player presses Play. The pad is only ~17 ms and is built synchronously
## in start(); the notes are built on a worker thread and the melody simply
## does not schedule until they land, well inside the fade-in. Nothing waits
## on this and no story beat is gated by it.
var _note_thread: Thread = null
var _note_mutex := Mutex.new()
var _note_cache: Dictionary = {}   # frequency -> AudioStreamWAV. Guarded by _note_mutex.
var _notes_ready: bool = false     # guarded by _note_mutex


## PROCESS_MODE_ALWAYS: this node's own _process() below is what performs
## the actual duck (smoothing _master_current_gain toward 0), so it must
## keep running while SceneTree.paused is true or "audio ducks while
## paused" (DEMO_PLAN.md S8) could never actually happen. Nothing else
## about this autoload's behavior depends on pause state -- start()/
## play_*() are only ever called from gameplay code that itself stops
## running while paused.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called by pause_menu.gd on pause/resume.
func duck(active: bool) -> void:
	_ducked = active


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
	_effect_player = AudioStreamPlayer.new()
	add_child(_effect_player)

	for frequency in DRONE_FREQUENCIES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.stream = _make_loop_tone(frequency)
		player.volume_db = -80.0
		player.play()
		_drone_players.append(player)

	_start_music()


func _process(delta: float) -> void:
	if not _started:
		return
	var mute_target := 0.0 if (Game.muted or _ducked) else MASTER_GAIN
	_master_current_gain = CameraProfile.damp(_master_current_gain, mute_target, MUTE_GAIN_LAMBDA, delta)

	for i in range(_drone_players.size()):
		_drone_current_gain[i] = CameraProfile.damp(_drone_current_gain[i], _drone_target_gain[i], MOOD_GAIN_LAMBDA, delta)
		var linear: float = _drone_current_gain[i] * _master_current_gain
		_drone_players[i].volume_db = _linear_to_db_safe(linear)

	_update_music(delta)


## game.mjs:376-382's audio.setMood(value) -- `lens_value` is
## EmotionalLens.value ({comfort, energy, curiosity}).
func set_mood(lens_value: Dictionary) -> void:
	if not _started:
		return
	var comfort: float = lens_value["comfort"]
	var energy: float = lens_value["energy"]
	for i in range(DRONE_FREQUENCIES.size()):
		_drone_target_gain[i] = mood_gain(i, comfort, energy)
	# The melody's one live response to the child rather than to the clock --
	# see MELODY_REST_BY_COMFORT.
	_music_comfort = comfort


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
	_yield_melody_to(MELODY_CHIME_YIELD)


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


## puddles.gd's splash-crossing trigger.
func play_splash() -> void:
	if not _started or Game.muted:
		return
	_effect_player.stream = _make_splash_wav()
	_effect_player.volume_db = _linear_to_db_safe(_master_current_gain)
	_effect_player.play()


## player.gd's _start_slide() -- fires once, at the top of the ride.
func play_slide_whoosh() -> void:
	if not _started or Game.muted:
		return
	_effect_player.stream = _make_whoosh_wav()
	_effect_player.volume_db = _linear_to_db_safe(_master_current_gain)
	_effect_player.play()


## sandbox.gd's interact() -- fires once per mound patted into place.
func play_sand_pat() -> void:
	if not _started or Game.muted:
		return
	_effect_player.stream = _make_sand_pat_wav()
	_effect_player.volume_db = _linear_to_db_safe(_master_current_gain)
	_effect_player.play()


## swing.gd's _maybe_creak() -- rate-limited there, not here (matches how
## play_step()'s OWN self-rate-limit lives in that function rather than in
## the caller). `intensity` 0..1 scales loudness a little with how fast the
## swing is actually moving.
func play_swing_creak(intensity: float) -> void:
	if not _started or Game.muted:
		return
	_effect_player.stream = _make_creak_wav(clampf(intensity, 0.0, 1.0))
	_effect_player.volume_db = _linear_to_db_safe(_master_current_gain)
	_effect_player.play()


## ===========================================================================
## MUSIC -- see the constants block at the top of this file for the design.
## ===========================================================================

## perception.gd's mood arc, 0 afternoon .. 0.5 golden .. 1 dusk. Pushed in
## from there rather than recomputed here, so there is exactly one mapping
## from episode state to "where in the afternoon are we" and the light and
## the music can never disagree about it.
func set_music_mood(progress: float) -> void:
	_music_mood = clampf(progress, 0.0, 1.0)


## True once the melody's note set has finished baking on the worker thread.
## Exposed for tests; nothing in the game waits on it.
func music_ready() -> bool:
	_note_mutex.lock()
	var ready := _notes_ready
	_note_mutex.unlock()
	return ready


## Interpolates an [afternoon, golden, dusk] table at `mood`, matching
## perception.gd's own afternoon->golden->dusk blend exactly. Static and pure
## so the mood mapping is directly unit-testable, the same way mood_gain() is.
static func mood_lerp(table: Array, mood: float) -> float:
	var m := clampf(mood, 0.0, 1.0)
	if m <= 0.5:
		return lerpf(table[0], table[1], m * 2.0)
	return lerpf(table[1], table[2], (m - 0.5) * 2.0)


## The pre-master linear gain of one pad voice at a given point in the
## afternoon. This is the whole mood tie-in in one pure function: voice 0
## (A2, the A-minor root) is silent at mood 0 and loudest at mood 1, voice 7
## (D5, the bright top) does the opposite, and the middle voices hold.
static func pad_gain(voice_index: int, mood: float) -> float:
	var voice: Dictionary = PAD_VOICES[voice_index]
	return mood_lerp(voice["mix"], mood) * PAD_LEVEL * MUSIC_GAIN


func _start_music() -> void:
	for i in range(PAD_VOICES.size()):
		var voice: Dictionary = PAD_VOICES[i]
		var stream := _make_pad_loop(voice["frequency"])
		var rates: Array = [1.0, 1.0 + PAD_DETUNE] if voice["detune"] else [1.0]
		for rate in rates:
			var player := AudioStreamPlayer.new()
			add_child(player)
			player.stream = stream
			player.pitch_scale = rate
			player.volume_db = MUSIC_SILENCE_DB
			var slot := _pad_players.size()
			# play(from_position) rather than play(): see PAD_START_OFFSETS.
			player.play(float(PAD_START_OFFSETS[slot]) * _stream_length(stream))
			_pad_players.append(player)
			_pad_voice_index.append(i)

	for _i in range(MELODY_VOICES):
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.volume_db = MUSIC_SILENCE_DB
		_melody_players.append(player)
		_melody_gain.append(0.0)

	# Fixed seed: the phrase order is then the same every run, which makes a
	# render reproducible and costs nothing (nobody replays a 15-minute
	# afternoon often enough to recognise the sequence).
	_music_rng.seed = 20260830

	_note_thread = Thread.new()
	_note_thread.start(_bake_notes)


## Runs on _note_thread. Touches only local state and the two members it
## guards with _note_mutex; it creates no nodes and reads nothing the main
## thread writes.
func _bake_notes() -> void:
	var baked := {}
	for frequency in MUSIC_SCALE:
		baked[frequency] = _make_note_wav(frequency)
	_note_mutex.lock()
	_note_cache = baked
	_notes_ready = true
	_note_mutex.unlock()


func _update_music(delta: float) -> void:
	if _pad_players.is_empty():
		return
	_music_time += delta
	_music_fade = CameraProfile.damp(_music_fade, 1.0, MUSIC_FADE_LAMBDA, delta)

	for slot in range(_pad_players.size()):
		var voice_index: int = _pad_voice_index[slot]
		var gain := pad_gain(voice_index, _music_mood) * _music_fade
		# "Reduced motion" is not an audio setting, so the reading taken here
		# is the narrow, literal one: it stops the one thing in the music that
		# moves on its own. The chord still changes with the afternoon.
		if not Game.reduced_motion:
			var rate: float = PAD_BREATH_RATES[voice_index]
			gain *= 1.0 + PAD_BREATH_DEPTH * sin(TAU * rate * _music_time + float(voice_index))
		_pad_players[slot].volume_db = _music_db(gain * _master_current_gain)

	# Re-apply the master gain to any note still ringing, so mute and the
	# pause duck reach it too -- see _melody_gain.
	for i in range(_melody_players.size()):
		_melody_players[i].volume_db = _music_db(_melody_gain[i] * _master_current_gain)

	_update_melody()


func _update_melody() -> void:
	if not music_ready():
		return
	while not _pending_notes.is_empty() and float(_pending_notes[0]["at"]) <= _music_time:
		var event: Dictionary = _pending_notes.pop_front()
		_play_note(float(event["frequency"]), float(event["level"]))
	if _pending_notes.is_empty() and _music_time >= _next_phrase_time:
		_schedule_phrase()


func _schedule_phrase() -> void:
	var index := _music_rng.randi_range(0, MUSIC_PHRASES.size() - 1)
	if index == _last_phrase:
		index = (index + 1) % MUSIC_PHRASES.size()
	_last_phrase = index
	var phrase: Array = MUSIC_PHRASES[index]
	var base := int(round(mood_lerp(MELODY_BASE, _music_mood)))

	var last_onset := 0.0
	for note in phrase:
		var step: int = note[0]
		var onset: float = note[1]
		last_onset = maxf(last_onset, onset)
		var scale_index: int = clampi(base + step, 0, MUSIC_SCALE.size() - 1)
		_pending_notes.append({
			"at": _music_time + onset,
			"frequency": MUSIC_SCALE[scale_index],
			"level": float(note[2]),
		})

	var rest := mood_lerp(MELODY_REST, _music_mood)
	rest *= lerpf(MELODY_REST_BY_COMFORT[0], MELODY_REST_BY_COMFORT[1], clampf(_music_comfort, 0.0, 1.0))
	rest *= _music_rng.randf_range(0.8, 1.2)
	_next_phrase_time = _music_time + last_onset + rest


## `level` is the note's place in its phrase's shape -- see MUSIC_PHRASES.
func _play_note(frequency: float, level: float = 1.0) -> void:
	if Game.muted:
		return
	_note_mutex.lock()
	var stream: AudioStreamWAV = _note_cache.get(frequency)
	_note_mutex.unlock()
	if stream == null:
		return
	var index := _melody_next
	_melody_next = (_melody_next + 1) % _melody_players.size()
	var player: AudioStreamPlayer = _melody_players[index]
	var gain := MELODY_LEVEL * MUSIC_GAIN * mood_lerp(MELODY_LEVEL_BY_MOOD, _music_mood)
	gain *= clampf(level, 0.0, 1.0)
	_melody_gain[index] = gain * _music_fade
	player.stream = stream
	player.volume_db = _music_db(_melody_gain[index] * _master_current_gain)
	player.play()


## Called when a dispatch chime fires: the music gets out of the way rather
## than playing over a story beat. Drops whatever phrase was in flight -- a
## phrase ending early is musically fine, a note landing on top of the chime
## that says "they let you in" is not.
func _yield_melody_to(seconds: float) -> void:
	_pending_notes.clear()
	_next_phrase_time = maxf(_next_phrase_time, _music_time + seconds)


## One pad voice: a whole number of cycles of a fixed harmonic series, so the
## loop point is not a seam at all -- the join is the same sample-to-sample
## step as every other sample in the buffer. Peak-normalised to full scale;
## the playback level lives in volume_db.
func _make_pad_loop(frequency: float) -> AudioStreamWAV:
	var cycles := maxi(1, int(ceil(float(PAD_LOOP_MIN_SAMPLES) * frequency / SAMPLE_RATE)))
	var samples := maxi(2, int(round(float(cycles) * SAMPLE_RATE / frequency)))
	var floats := PackedFloat32Array()
	floats.resize(samples)
	for k in range(PAD_PARTIALS.size()):
		var amplitude: float = PAD_PARTIALS[k]
		var harmonic := float(k + 1) * float(cycles)
		for i in range(samples):
			floats[i] += amplitude * sin(TAU * harmonic * float(i) / float(samples))
	_normalize(floats)
	var wav := _floats_to_wav(floats)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	return wav


## One melody note. Same additive approach as _make_chime_wav above, but with
## a per-partial decay (upper partials die first) and a raised-cosine attack
## and tail rather than the chime's linear attack and bare exponential.
func _make_note_wav(frequency: float) -> AudioStreamWAV:
	var samples := int(ceil(NOTE_LENGTH * SAMPLE_RATE))
	var floats := PackedFloat32Array()
	floats.resize(samples)
	for p in NOTE_PARTIALS:
		var multiple: float = p[0]
		var amplitude: float = p[1]
		var decay: float = NOTE_DECAY * float(p[2])
		for i in range(samples):
			var t := float(i) / SAMPLE_RATE
			floats[i] += amplitude * sin(TAU * frequency * multiple * t) * exp(-t / decay)

	var fade_start := NOTE_LENGTH - NOTE_TAIL_FADE
	for i in range(samples):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0
		if t < NOTE_ATTACK:
			envelope = 0.5 - 0.5 * cos(PI * (t / NOTE_ATTACK))
		if t > fade_start:
			envelope *= 0.5 + 0.5 * cos(PI * clampf((t - fade_start) / NOTE_TAIL_FADE, 0.0, 1.0))
		floats[i] *= envelope

	_normalize(floats)
	return _floats_to_wav(floats)


static func _normalize(floats: PackedFloat32Array) -> void:
	var peak := 0.0
	for v in floats:
		peak = maxf(peak, absf(v))
	if peak <= 0.0:
		return
	for i in range(floats.size()):
		floats[i] /= peak


static func _stream_length(stream: AudioStreamWAV) -> float:
	return float(stream.data.size() / 2) / float(stream.mix_rate)


## Threads must be joined before they are released, or Godot reports an error
## at shutdown. Nothing else here needs teardown -- the players are children
## of this node and go with it.
func _exit_tree() -> void:
	if _note_thread != null and _note_thread.is_started():
		_note_thread.wait_to_finish()
		_note_thread = null


## _linear_to_db_safe for the music players -- same threshold, much lower
## floor. See MUSIC_SILENCE_DB.
static func _music_db(linear: float) -> float:
	if linear <= 0.0001:
		return MUSIC_SILENCE_DB
	return linear_to_db(linear)


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


## Gate 0: broadband noise burst + two droplet blips, pre-rendered to a
## single one-shot clip -- same exponential-decay envelope shape
## _make_step_wav below already uses, just applied to noise instead of a
## triangle tone for the main hit.
func _make_splash_wav() -> AudioStreamWAV:
	var total_samples := int(ceil(SPLASH_NOISE_DURATION * SAMPLE_RATE))
	# The two droplets can extend past the main noise burst; size the
	# buffer to whichever one actually finishes last.
	for d in SPLASH_DROPLETS:
		var droplet_end: float = float(d["start"]) + SPLASH_DROPLET_DECAY * 3.0
		total_samples = maxi(total_samples, int(ceil(droplet_end * SAMPLE_RATE)))

	var floats := PackedFloat32Array()
	floats.resize(total_samples)

	var noise_samples := int(SPLASH_NOISE_DURATION * SAMPLE_RATE)
	for s in range(noise_samples):
		var t := float(s) / SAMPLE_RATE
		var envelope: float = SPLASH_NOISE_PEAK * pow(CHIME_FLOOR / SPLASH_NOISE_PEAK, clampf(t / SPLASH_NOISE_DECAY, 0.0, 1.0))
		floats[s] += randf_range(-1.0, 1.0) * envelope

	for d in SPLASH_DROPLETS:
		var start: float = d["start"]
		var frequency: float = d["freq"]
		var start_sample := int(start * SAMPLE_RATE)
		var droplet_samples := int(SPLASH_DROPLET_DECAY * 3.0 * SAMPLE_RATE)
		for i in range(droplet_samples):
			var s := start_sample + i
			if s >= total_samples:
				break
			var t := float(i) / SAMPLE_RATE
			var envelope: float = SPLASH_DROPLET_PEAK * pow(CHIME_FLOOR / SPLASH_DROPLET_PEAK, clampf(t / SPLASH_DROPLET_DECAY, 0.0, 1.0))
			floats[s] += sin(t * frequency * TAU) * envelope

	return _floats_to_wav(floats)


## Gate 0: white noise smoothed with a cheap one-pole lowpass (each sample
## eased a small step toward the next raw noise value rather than jumping
## straight to it) so it reads as soft air/wind instead of harsh static,
## under a sin(progress*PI) envelope that rises then falls across the
## whole ride -- one continuous "down the slide" gesture rather than a hit.
func _make_whoosh_wav() -> AudioStreamWAV:
	var total_samples := int(ceil(WHOOSH_DURATION * SAMPLE_RATE))
	var floats := PackedFloat32Array()
	floats.resize(total_samples)
	var smoothed := 0.0
	for s in range(total_samples):
		var progress := float(s) / float(total_samples)
		var envelope: float = WHOOSH_PEAK * sin(progress * PI)
		smoothed = lerpf(smoothed, randf_range(-1.0, 1.0), WHOOSH_SMOOTHING)
		floats[s] = smoothed * envelope
	return _floats_to_wav(floats)


## Gate 1: same smoothed-noise technique as _make_whoosh_wav() just above,
## but short and percussive (a fast exponential decay envelope, not a
## rise-then-fall) and duller (a much larger smoothing factor, so less
## high-frequency content survives) -- a soft pat, not a gust.
func _make_sand_pat_wav() -> AudioStreamWAV:
	var total_samples := int(ceil(SAND_PAT_DURATION * SAMPLE_RATE))
	var floats := PackedFloat32Array()
	floats.resize(total_samples)
	var smoothed := 0.0
	for s in range(total_samples):
		var t := float(s) / SAMPLE_RATE
		var envelope: float = SAND_PAT_PEAK * pow(CHIME_FLOOR / SAND_PAT_PEAK, clampf(t / SAND_PAT_DECAY, 0.0, 1.0))
		smoothed = lerpf(smoothed, randf_range(-1.0, 1.0), SAND_PAT_SMOOTHING)
		floats[s] = smoothed * envelope
	return _floats_to_wav(floats)


## Gate 1: a short triangle blip (_make_step_wav()'s own technique) at a
## low frequency, with a downward pitch slide across the decay -- a crude
## but cheap approximation of frequency modulation that's what actually
## makes this read as a creak rather than a clean plucked note.
func _make_creak_wav(intensity: float) -> AudioStreamWAV:
	var total_samples := int(ceil(CREAK_DURATION * SAMPLE_RATE))
	var floats := PackedFloat32Array()
	floats.resize(total_samples)
	var peak: float = CREAK_PEAK * lerpf(0.5, 1.0, intensity)
	for s in range(total_samples):
		var t := float(s) / SAMPLE_RATE
		var envelope: float = peak * pow(CHIME_FLOOR / peak, clampf(t / CREAK_DECAY, 0.0, 1.0))
		var drift: float = lerpf(1.3, 1.0, clampf(t / CREAK_DECAY, 0.0, 1.0))
		floats[s] = _triangle(t * CREAK_FREQUENCY * drift) * envelope
	return _floats_to_wav(floats)


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
