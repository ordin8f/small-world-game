extends GdUnitTestSuite
## Guards the whole one-shot sound family against the defect short cues
## actually suffer from: an envelope that stops before it reaches silence,
## which ends the buffer on a step, which is a click.
##
## This is a regression guard over EVERY cue, not just the new ones. The
## audible verification -- what they sound like -- is tools/_probe_oneshots.gd,
## which renders each one to .wav and prints these same figures.


## The noise-based cues (splash, sand pat, bench settle) use the global RNG,
## so seed it: otherwise the click bound below is being applied to a
## different waveform on every run, which is how a bound becomes flaky and
## then becomes ignored.
func before_test() -> void:
	seed(20260830)


func _every_cue() -> Dictionary:
	var cues := {}
	for kind in AudioDirector.CHIME_KINDS:
		cues["chime_%s" % kind] = AudioDirector._make_chime_wav(kind)
	cues["step_walking"] = AudioDirector._make_step_wav(false)
	cues["step_running"] = AudioDirector._make_step_wav(true)
	cues["splash"] = AudioDirector._make_splash_wav()
	cues["slide_whoosh"] = AudioDirector._make_whoosh_wav()
	cues["sand_pat"] = AudioDirector._make_sand_pat_wav()
	cues["swing_creak"] = AudioDirector._make_creak_wav(1.0)
	cues["bench_settle"] = AudioDirector._make_bench_wav()
	return cues


static func _samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var count := wav.data.size() / 2
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		out[i] = float(wav.data.decode_s16(i * 2)) / 32767.0
	return out


## Every cue has to reach silence before its buffer runs out. -80 dBFS is
## the threshold the rest of this file already treats as silent, and the
## measured family sits at -95 dBFS or true zero, so there is real margin.
func test_every_one_shot_decays_to_silence_before_it_ends() -> void:
	for name in _every_cue():
		var floats := _samples(_every_cue()[name])
		assert_int(floats.size()).is_greater(100)
		var last: float = absf(floats[floats.size() - 1])
		assert_float(last) \
			.override_failure_message("%s ends at %f, not silence -- that is a click" % [name, last]) \
			.is_less(0.0001)


## No cue may contain a sample-to-sample jump far larger than its own typical
## slew. Bench settle's creak layer starts mid-buffer and, before it was given
## an attack ramp, _triangle(0)'s value of 1.0 made it jump straight to peak:
## 5.6x by this measure, against 1.0-1.3x for every other cue. The bound
## catches that with margin and is nowhere near the measured family.
func test_no_one_shot_contains_a_discontinuity() -> void:
	for name in _every_cue():
		var floats := _samples(_every_cue()[name])
		var steps := []
		var worst := 0.0
		for i in range(1, floats.size()):
			var d: float = absf(floats[i] - floats[i - 1])
			steps.append(d)
			worst = maxf(worst, d)
		steps.sort()
		var typical: float = steps[int(float(steps.size()) * 0.999)]
		var ratio: float = worst / maxf(typical, 1e-12)
		assert_float(ratio) \
			.override_failure_message("%s jumps %.2fx its own typical slew" % [name, ratio]) \
			.is_less(2.5)


func test_no_one_shot_clips() -> void:
	for name in _every_cue():
		for v in _samples(_every_cue()[name]):
			assert_float(absf(v) * AudioDirector.MASTER_GAIN).is_less(1.0)


## The invitation is the emotional peak of the demo, and it is the one cue
## allowed to be special. Special by shape and length -- four rising notes
## and the longest tail of anything in the game -- rather than by being
## louder than the cues it has to sit among.
func test_the_welcome_cue_is_the_longest_and_the_only_rising_four_note_one() -> void:
	var welcome := AudioDirector._make_chime_wav("welcome")
	var welcome_length := welcome.data.size()

	for kind in AudioDirector.CHIME_KINDS:
		if kind == "welcome":
			continue
		var other := AudioDirector._make_chime_wav(kind)
		assert_int(welcome_length) \
			.override_failure_message("welcome is not longer than %s" % kind) \
			.is_greater(other.data.size())

	var frequencies: Array = AudioDirector.CHIME_KINDS["welcome"]["frequencies"]
	assert_int(frequencies.size()).is_equal(4)
	for i in range(1, frequencies.size()):
		assert_float(frequencies[i]).is_greater(frequencies[i - 1])

	# Level with the loudest existing chime, not above it.
	var loudest := 0.0
	for kind in AudioDirector.CHIME_KINDS:
		loudest = maxf(loudest, float(AudioDirector.CHIME_KINDS[kind]["peak"]))
	assert_float(AudioDirector.CHIME_KINDS["welcome"]["peak"]).is_equal(loudest)


## The bench is a small physical cue and must sit well under the story beats.
func test_the_bench_settle_is_quieter_than_any_chime() -> void:
	var bench_peak := 0.0
	for v in _samples(AudioDirector._make_bench_wav()):
		bench_peak = maxf(bench_peak, absf(v))
	var quietest_chime := 1.0
	for kind in AudioDirector.CHIME_KINDS:
		quietest_chime = minf(quietest_chime, float(AudioDirector.CHIME_KINDS[kind]["peak"]))
	assert_float(bench_peak).is_less(quietest_chime)


## The five cues that existed before 2026-08-30 must be untouched by the two
## optional keys "welcome" introduced. If a default leaked, these change.
func test_the_original_chimes_are_unchanged_by_the_new_optional_keys() -> void:
	var expected := {"soft": 0.95, "warm": 1.15, "uneasy": 0.95, "wonder": 1.15, "keepsake": 0.95}
	for kind in expected:
		var wav := AudioDirector._make_chime_wav(kind)
		var seconds := float(wav.data.size() / 2) / float(AudioDirector.SAMPLE_RATE)
		assert_float(seconds) \
			.override_failure_message("%s changed length" % kind) \
			.is_equal_approx(float(expected[kind]), 0.01)
		assert_bool(AudioDirector.CHIME_KINDS[kind].has("stagger")).is_false()
		assert_bool(AudioDirector.CHIME_KINDS[kind].has("tail_scale")).is_false()
