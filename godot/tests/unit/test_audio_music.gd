extends GdUnitTestSuite
## Unit tests for the music layer's pure functions: the afternoon->golden->dusk
## interpolation and the per-voice mix that rides it. The rest of the layer is
## side-effecting playback and is covered by the play test; how it actually
## sounds is covered by tools/_probe_music.gd, which renders it to disk and
## measures it.

const AudioDirectorScript := preload("res://scripts/audio_director.gd")


func test_mood_lerp_hits_the_three_authored_anchors() -> void:
	# The whole point of a three-entry table is that mood 0/0.5/1 land exactly
	# on the authored values rather than near them.
	var table := [10.0, 20.0, 40.0]
	assert_float(AudioDirectorScript.mood_lerp(table, 0.0)).is_equal_approx(10.0, 0.0001)
	assert_float(AudioDirectorScript.mood_lerp(table, 0.5)).is_equal_approx(20.0, 0.0001)
	assert_float(AudioDirectorScript.mood_lerp(table, 1.0)).is_equal_approx(40.0, 0.0001)
	# And that it interpolates within each half rather than stepping.
	assert_float(AudioDirectorScript.mood_lerp(table, 0.25)).is_equal_approx(15.0, 0.0001)
	assert_float(AudioDirectorScript.mood_lerp(table, 0.75)).is_equal_approx(30.0, 0.0001)


func test_mood_lerp_clamps_outside_the_arc() -> void:
	var table := [10.0, 20.0, 40.0]
	assert_float(AudioDirectorScript.mood_lerp(table, -3.0)).is_equal_approx(10.0, 0.0001)
	assert_float(AudioDirectorScript.mood_lerp(table, 9.0)).is_equal_approx(40.0, 0.0001)


## The mood tie-in, as a claim about the chord rather than about a float:
## the afternoon is C major (no A in the bass, D5 on top) and dusk is A minor
## (A2 in the bass, D5 gone, the ninth arrived). If someone flattens the mix
## table so the mood stops doing anything, this is what fails.
func test_the_chord_pivots_from_c_major_to_a_minor_across_the_afternoon() -> void:
	var a2 := _voice("A2")
	var c3 := _voice("C3")
	var b4 := _voice("B4")
	var d5 := _voice("D5")

	# Afternoon: C major add9. No A root at all, and the bright top voice is up.
	assert_float(AudioDirectorScript.pad_gain(a2, 0.0)).is_equal(0.0)
	assert_float(AudioDirectorScript.pad_gain(b4, 0.0)).is_equal(0.0)
	assert_float(AudioDirectorScript.pad_gain(d5, 0.0)).is_greater(0.0)
	assert_float(AudioDirectorScript.pad_gain(c3, 0.0)).is_greater(0.0)

	# Dusk: A minor 9. The A root and the ninth have arrived, D5 has gone,
	# and the C root has receded to a trace.
	assert_float(AudioDirectorScript.pad_gain(d5, 1.0)).is_equal(0.0)
	assert_float(AudioDirectorScript.pad_gain(c3, 1.0)).is_equal(0.0)
	assert_float(AudioDirectorScript.pad_gain(a2, 1.0)).is_greater(0.0)
	assert_float(AudioDirectorScript.pad_gain(b4, 1.0)).is_greater(0.0)

	# The pivot has to be a crossfade, not a switch: at the midpoint both
	# roots are sounding, which is what makes it read as the light changing.
	assert_float(AudioDirectorScript.pad_gain(a2, 0.5)).is_greater(0.0)
	assert_float(AudioDirectorScript.pad_gain(c3, 0.5)).is_greater(0.0)


func test_the_common_tones_hold_across_the_whole_arc() -> void:
	# E3/G3/C4/E4 are what stop the pivot sounding like a key change. Each
	# must stay within a third of its own afternoon level all the way to dusk.
	for name in ["E3", "G3", "C4", "E4"]:
		var index := _voice(name)
		var afternoon := AudioDirectorScript.pad_gain(index, 0.0)
		assert_float(afternoon).is_greater(0.0)
		for mood in [0.25, 0.5, 0.75, 1.0]:
			var here := AudioDirectorScript.pad_gain(index, mood)
			assert_float(here).is_between(afternoon * 0.66, afternoon * 1.34)


## "Sits under the existing ambience, never over it." Tied to the ambience's
## own constant rather than to a number typed in here, so raising MUSIC_GAIN
## far enough to fight a story beat fails this rather than silently shipping.
func test_the_whole_pad_stays_quieter_than_a_chime() -> void:
	var ceiling: float = AudioDirectorScript.CHIME_KINDS["soft"]["peak"]
	var breath_peak: float = 1.0 + AudioDirectorScript.PAD_BREATH_DEPTH
	for mood in [0.0, 0.25, 0.5, 0.75, 1.0]:
		# Worst case: every voice at once, every detuned twin, every breath
		# at the top of its swing, all summing in phase.
		var total := 0.0
		for i in range(AudioDirectorScript.PAD_VOICES.size()):
			var voice: Dictionary = AudioDirectorScript.PAD_VOICES[i]
			var players := 2 if voice["detune"] else 1
			total += AudioDirectorScript.pad_gain(i, mood) * players * breath_peak
		assert_float(total).is_less(ceiling)


func test_a_melody_note_stays_quieter_than_a_chime() -> void:
	var ceiling: float = AudioDirectorScript.CHIME_KINDS["soft"]["peak"]
	for mood in [0.0, 0.5, 1.0]:
		var level: float = AudioDirectorScript.MELODY_LEVEL \
			* AudioDirectorScript.MUSIC_GAIN \
			* AudioDirectorScript.mood_lerp(AudioDirectorScript.MELODY_LEVEL_BY_MOOD, mood)
		assert_float(level).is_less(ceiling)


## Every phrase must stay inside the scale array at both ends of the arc --
## a phrase reaching past the top would silently clamp to the same note twice.
func test_every_phrase_fits_the_scale_at_every_mood() -> void:
	var size: int = AudioDirectorScript.MUSIC_SCALE.size()
	for mood in [0.0, 0.5, 1.0]:
		var base := int(round(AudioDirectorScript.mood_lerp(AudioDirectorScript.MELODY_BASE, mood)))
		for phrase in AudioDirectorScript.MUSIC_PHRASES:
			for note in phrase:
				var index: int = base + int(note[0])
				assert_int(index).is_between(0, size - 1)


## MELODY_LEVEL is the ceiling the level tests above are written against, so
## no phrase may exceed 1.0; and every phrase has to actually be shaped, or
## the level column is decoration and the melody is back to sounding
## sequenced. Onsets must ascend, or notes would fire out of order.
func test_every_phrase_is_shaped_and_within_the_level_ceiling() -> void:
	for phrase in AudioDirectorScript.MUSIC_PHRASES:
		var previous_onset := -1.0
		var loudest := 0.0
		var quietest := 2.0
		for note in phrase:
			var onset: float = note[1]
			var level: float = note[2]
			assert_float(onset).is_greater(previous_onset)
			previous_onset = onset
			assert_float(level).is_between(0.4, 1.0)
			loudest = maxf(loudest, level)
			quietest = minf(quietest, level)
		if phrase.size() > 1:
			# At least 1.5 dB of shape across the phrase.
			assert_float(loudest / quietest).is_greater(1.19)


func _voice(name: String) -> int:
	for i in range(AudioDirectorScript.PAD_VOICES.size()):
		if AudioDirectorScript.PAD_VOICES[i]["name"] == name:
			return i
	fail("no pad voice named %s" % name)
	return -1
