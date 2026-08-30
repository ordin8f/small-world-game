extends GdUnitTestSuite
## Play tests for the music layer against the real running game: that the
## players exist and are playing, that every pad loop is genuinely seamless,
## that the mood arc moves real volume_db on real nodes, and that mute and
## reduce-motion reach it.
##
## What these CANNOT check is whether it sounds good, or whether it clicks.
## tools/_probe_music.gd renders the layer to .wav and measures level,
## headroom, spectrum and sample-to-sample discontinuity; that is the
## verification for those, and it is a listening artefact, not an assertion.

func before_test() -> void:
	Game.muted = false
	Game.reduced_motion = false


func after_test() -> void:
	Game.muted = false
	Game.reduced_motion = false


func test_start_episode_brings_up_the_pad_and_melody_players() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	# 8 voices, 4 of them with a detuned twin.
	assert_int(AudioDirector._pad_players.size()).is_equal(12)
	assert_int(AudioDirector._melody_players.size()).is_equal(AudioDirector.MELODY_VOICES)

	for player in AudioDirector._pad_players:
		assert_bool(player.playing).is_true()
		assert_object(player.stream).is_not_null()
		assert_int(player.stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)

	# Idempotent, like the rest of start().
	Game.start_episode(0.0)
	assert_int(AudioDirector._pad_players.size()).is_equal(12)


## The honest seam test. Not "do the endpoints nearly match" -- a loop can pass
## that and still tick -- but "is the step across the join any larger than the
## largest step inside the buffer". If it is not, there is nothing to hear.
func test_every_pad_loop_joins_without_a_step() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	for player in AudioDirector._pad_players:
		var wav: AudioStreamWAV = player.stream
		var count := wav.data.size() / 2
		assert_int(count).is_greater(1000)
		assert_int(wav.loop_end).is_equal(count)

		var worst_internal := 0.0
		var previous := float(wav.data.decode_s16(0)) / 32767.0
		var first := previous
		for i in range(1, count):
			var value := float(wav.data.decode_s16(i * 2)) / 32767.0
			worst_internal = maxf(worst_internal, absf(value - previous))
			previous = value
		var seam := absf(first - previous)
		assert_float(seam).is_less_equal(worst_internal)


## Seamlessness alone is cheap -- _make_pad_loop generates its partials against
## the buffer length, so the join is seamless whatever length it picks. What
## costs something is being seamless AT THE RIGHT PITCH, which is what
## PAD_LOOP_MIN_SAMPLES buys: spreading the rounding over 10-50 cycles instead
## of one. A single-period loop would put G4 7.7 cents flat and B4 5.7 sharp,
## and eight voices mistuned by that much against each other is a chord that
## beats sourly. Derived from the buffer length here, not from the production
## formula, so this is a measurement rather than a restatement.
func test_every_pad_loop_is_seamless_at_the_pitch_it_was_asked_for() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	for slot in range(AudioDirector._pad_players.size()):
		var voice: Dictionary = AudioDirector.PAD_VOICES[AudioDirector._pad_voice_index[slot]]
		var wanted: float = voice["frequency"]
		var wav: AudioStreamWAV = AudioDirector._pad_players[slot].stream
		var samples := wav.data.size() / 2

		# A seamless loop holds a whole number of cycles, so the pitch it
		# actually sounds is fixed by the buffer length alone.
		var cycles := roundf(float(samples) * wanted / AudioDirector.SAMPLE_RATE)
		assert_float(cycles).is_greater(0.0)
		var realised := cycles * AudioDirector.SAMPLE_RATE / float(samples)
		var cents := 1200.0 * (log(realised / wanted) / log(2.0))
		assert_float(absf(cents)).is_less(0.5)


func test_the_mood_arc_moves_the_chord_on_the_real_players() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	# Settle the fade-in and freeze the breathing so this measures the mood
	# and nothing else. delta 0 makes damp() a no-op, so one call is one
	# instant rather than one step of smoothing.
	AudioDirector._music_fade = 1.0
	AudioDirector._music_time = 0.0
	Game.reduced_motion = true

	AudioDirector.set_music_mood(0.0)
	AudioDirector._update_music(0.0)
	var afternoon := _voice_db()

	AudioDirector.set_music_mood(1.0)
	AudioDirector._update_music(0.0)
	var dusk := _voice_db()

	# Stated as the chord rather than as a dB delta, because volume_db cannot
	# express the real swing: _music_db() floors at MUSIC_SILENCE_DB, so a
	# voice that is genuinely off and one that is merely very quiet both land
	# there. "At the floor" is therefore exactly "this voice is not sounding",
	# which is the claim worth making. The acoustic size of the change (about
	# 45 dB, measured on the rendered .wav) is in tools/_probe_music.gd.

	# Afternoon is C major add9: no A root, no ninth, bright top voice up.
	assert_float(afternoon["A2"]).is_equal(AudioDirector.MUSIC_SILENCE_DB)
	assert_float(afternoon["B4"]).is_equal(AudioDirector.MUSIC_SILENCE_DB)
	assert_float(afternoon["C3"]).is_greater(AudioDirector.MUSIC_SILENCE_DB)
	assert_float(afternoon["D5"]).is_greater(AudioDirector.MUSIC_SILENCE_DB)

	# Dusk is A minor 9: the A root and the ninth are in, the low C and the
	# bright top voice are gone.
	assert_float(dusk["A2"]).is_greater(AudioDirector.MUSIC_SILENCE_DB)
	assert_float(dusk["B4"]).is_greater(AudioDirector.MUSIC_SILENCE_DB)
	assert_float(dusk["C3"]).is_equal(AudioDirector.MUSIC_SILENCE_DB)
	assert_float(dusk["D5"]).is_equal(AudioDirector.MUSIC_SILENCE_DB)

	# ...while the common tones hold, which is what stops it being a switch.
	assert_float(absf(dusk["E3"] - afternoon["E3"])).is_less(2.0)
	assert_float(absf(dusk["E4"] - afternoon["E4"])).is_less(2.0)
	assert_float(afternoon["E4"]).is_greater(AudioDirector.MUSIC_SILENCE_DB)


func test_reduced_motion_stops_the_pad_breathing() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)
	AudioDirector._music_fade = 1.0
	AudioDirector.set_music_mood(0.0)

	# Same voice, same mood, two points in time. The only thing that can
	# differ between them is the breathing LFO.
	Game.reduced_motion = false
	var moving := _db_at_two_times()
	Game.reduced_motion = true
	var still := _db_at_two_times()

	assert_float(absf(moving[0] - moving[1])).is_greater(0.5)
	assert_float(absf(still[0] - still[1])).is_equal_approx(0.0, 0.0001)


func test_mute_silences_the_pad_and_suppresses_notes() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)
	AudioDirector._music_fade = 1.0
	AudioDirector.set_music_mood(0.0)
	AudioDirector._update_music(0.0)

	var index := _index_of("C4")
	assert_float(AudioDirector._pad_players[index].volume_db).is_greater(AudioDirector.MUSIC_SILENCE_DB)

	Game.muted = true
	# The master gain smooths to zero over ~0.04 s; give it frames to land.
	await runner.simulate_frames(30)
	assert_float(AudioDirector._pad_players[index].volume_db).is_equal(AudioDirector.MUSIC_SILENCE_DB)

	# A melody note must be suppressed outright, not merely silenced -- the
	# same distinction the chime test already draws.
	for player in AudioDirector._melody_players:
		player.stop()
	AudioDirector._play_note(440.0)
	await runner.simulate_frames(2)
	for player in AudioDirector._melody_players:
		assert_bool(player.playing).is_false()


## A note is 2.8 s long, so muting halfway through one has to reach the note
## that is already sounding, not just stop the next one from starting.
func test_mute_silences_a_note_that_is_already_ringing() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	var deadline := Time.get_ticks_msec() + 20000
	while not AudioDirector.music_ready() and Time.get_ticks_msec() < deadline:
		await runner.simulate_frames(1)

	AudioDirector._music_fade = 1.0
	AudioDirector._play_note(AudioDirector.MUSIC_SCALE[5])
	await runner.simulate_frames(2)

	var index := (AudioDirector._melody_next - 1 + AudioDirector.MELODY_VOICES) % AudioDirector.MELODY_VOICES
	var player: AudioStreamPlayer = AudioDirector._melody_players[index]
	assert_bool(player.playing).is_true()
	assert_float(player.volume_db).is_greater(AudioDirector.MUSIC_SILENCE_DB)

	Game.muted = true
	await runner.simulate_frames(30)
	# Still ringing as far as the node is concerned, but at the silence floor.
	assert_float(player.volume_db).is_equal(AudioDirector.MUSIC_SILENCE_DB)


func test_a_chime_clears_the_music_out_of_its_way() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	AudioDirector._music_time = 10.0
	AudioDirector._next_phrase_time = 10.2
	AudioDirector._pending_notes = [{"at": 10.4, "frequency": 440.0}]

	AudioDirector.play_chime("soft")

	assert_array(AudioDirector._pending_notes).is_empty()
	assert_float(AudioDirector._next_phrase_time) \
		.is_greater_equal(10.0 + AudioDirector.MELODY_CHIME_YIELD)


## The layer's one live response to the child rather than to the clock: a
## child on the edge of the game gets longer silences than one who has been
## let in. Both calls are given the same RNG seed and the same starting
## phrase, so the jitter is identical and comfort is the only difference.
func test_comfort_changes_how_much_silence_there_is_between_phrases() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)
	AudioDirector.set_music_mood(0.0)

	var lonely := _rest_after_a_phrase(0.05)
	var welcomed := _rest_after_a_phrase(0.95)

	assert_float(lonely).is_greater(welcomed)
	# ...and bounded, so "lonely" can never mean "the music stopped". The
	# ratio is fixed by MELODY_REST_BY_COMFORT and must stay under 2x.
	assert_float(lonely / welcomed).is_less(2.0)


## The melody's note set is baked on a worker thread, so this is the one test
## that has to wait for real time to pass rather than for frames.
func test_the_note_set_bakes_and_a_note_actually_plays() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	var deadline := Time.get_ticks_msec() + 20000
	while not AudioDirector.music_ready() and Time.get_ticks_msec() < deadline:
		await runner.simulate_frames(1)
	assert_bool(AudioDirector.music_ready()).is_true()

	for player in AudioDirector._melody_players:
		player.stop()
	AudioDirector._music_fade = 1.0
	AudioDirector._play_note(AudioDirector.MUSIC_SCALE[5])
	await runner.simulate_frames(2)

	var playing := 0
	for player in AudioDirector._melody_players:
		if player.playing:
			playing += 1
	assert_int(playing).is_equal(1)


## Every pitch the scheduler can reach must have been baked, or a phrase would
## silently drop notes on the floor.
func test_every_scale_pitch_was_baked() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)

	var deadline := Time.get_ticks_msec() + 20000
	while not AudioDirector.music_ready() and Time.get_ticks_msec() < deadline:
		await runner.simulate_frames(1)

	for frequency in AudioDirector.MUSIC_SCALE:
		assert_bool(AudioDirector._note_cache.has(frequency)).is_true()
		var wav: AudioStreamWAV = AudioDirector._note_cache[frequency]
		assert_int(wav.data.size() / 2).is_greater(int(AudioDirector.NOTE_LENGTH * 40000))


func _index_of(name: String) -> int:
	for slot in range(AudioDirector._pad_players.size()):
		var voice: Dictionary = AudioDirector.PAD_VOICES[AudioDirector._pad_voice_index[slot]]
		if voice["name"] == name:
			return slot
	fail("no pad player for voice %s" % name)
	return -1


func _voice_db() -> Dictionary:
	var out := {}
	for name in ["A2", "C3", "E3", "E4", "B4", "D5"]:
		out[name] = AudioDirector._pad_players[_index_of(name)].volume_db
	return out


## Seconds of silence _schedule_phrase() leaves after the phrase it queues,
## at a given comfort, with the RNG and the phrase choice pinned.
func _rest_after_a_phrase(comfort: float) -> float:
	AudioDirector._music_rng.seed = 1
	AudioDirector._last_phrase = -1
	AudioDirector._music_time = 100.0
	AudioDirector._pending_notes = []
	AudioDirector._music_comfort = comfort
	AudioDirector._schedule_phrase()
	var last_onset := 0.0
	for event in AudioDirector._pending_notes:
		last_onset = maxf(last_onset, float(event["at"]) - 100.0)
	return AudioDirector._next_phrase_time - 100.0 - last_onset


func _db_at_two_times() -> Array:
	var index := _index_of("C4")
	AudioDirector._music_time = 0.0
	AudioDirector._update_music(0.0)
	var a: float = AudioDirector._pad_players[index].volume_db
	AudioDirector._music_time = 7.0
	AudioDirector._update_music(0.0)
	var b: float = AudioDirector._pad_players[index].volume_db
	return [a, b]
