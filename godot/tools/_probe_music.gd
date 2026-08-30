extends SceneTree

## Renders the music layer to .wav files on disk so it can be listened to and
## measured, instead of being asserted about.
##
## A gdUnit4 test can prove a stream exists, loops, and sits under a gain
## ceiling. It cannot prove the music is any good, and it cannot catch a
## click, a sour chord, or a layer that is silent because a gain went to
## zero. This walks the real AudioDirector's real synthesis functions,
## mixes them exactly the way _update_music() sets volume_db every frame,
## and writes the result out.
##
## What this DOES model: the baked waveforms (identical code paths -- it calls
## _make_pad_loop/_make_note_wav on the live autoload), the per-voice mood
## gains, the breathing LFOs, the fade-in, the melody scheduler, and the
## detuned twins' resampling.
## What it does NOT model: Godot's own mixer. Godot resamples pitch_scale with
## a better interpolator than the linear one here, so the real output is if
## anything cleaner than what this measures.
##
## Usage:
##   godot --headless --path godot --script res://tools/_probe_music.gd
## Output: user://music_render/*.wav  (printed as an absolute path at the end)

const SR := 44100
const OUT_DIR := "user://music_render"
const RENDER_SECONDS := 45.0


func _initialize() -> void:
	var director: Object = load("res://scripts/audio_director.gd").new()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	print("== cost ==")
	_report_cost(director)

	print("\n== pad loops: tuning and seam ==")
	_report_loops(director)

	print("\n== renders ==")
	var moods := {"afternoon": 0.0, "golden": 0.5, "dusk": 1.0}
	var levels := {}
	for name in moods:
		var signal_data := _render(director, float(moods[name]), RENDER_SECONDS, true, true, true)
		levels[name] = _report(name, signal_data)
		_write_wav("%s/music_%s.wav" % [OUT_DIR, name], signal_data)

	print("\n== layers, afternoon ==")
	_report("pad only", _render(director, 0.0, 30.0, true, false, true))
	_report("melody only", _render(director, 0.0, 45.0, false, true, true))
	_report("pad, reduced motion", _render(director, 0.0, 30.0, true, false, false))
	print("\n== layers, dusk ==")
	_report("pad only", _render(director, 1.0, 30.0, true, false, true))
	_report("melody only", _render(director, 1.0, 45.0, false, true, true))

	print("\n== the mood arc as one continuous 90 s pass ==")
	var arc := _render_arc(director, 90.0)
	_report("afternoon -> dusk", arc)
	_write_wav("%s/music_arc.wav" % OUT_DIR, arc)

	print("\n== reference: what it has to sit under ==")
	_report("drones (comfort/energy .5)", _render_drones(4.0, 0.5, 0.5))
	_report("chime 'warm'", _render_existing_chime(director, "warm"))

	print("\n== discontinuities ==")
	_click_check("music afternoon", _render(director, 0.0, RENDER_SECONDS, true, true, true))
	_click_check("music dusk", _render(director, 1.0, RENDER_SECONDS, true, true, true))
	_click_check("pad only, 10 loop passes", _render(director, 0.5, 30.0, true, false, true))
	_click_check("single note A4", _to_floats(director.call("_make_note_wav", 440.0)))

	print("\n== spectrum (which chord is actually sounding) ==")
	_spectrum("pad afternoon", _render(director, 0.0, 20.0, true, false, false))
	_spectrum("pad dusk", _render(director, 1.0, 20.0, true, false, false))

	print("\nwrote: %s" % ProjectSettings.globalize_path(OUT_DIR))
	director.free()
	quit()


## "Music must never gate or delay a story beat." start() happens on the frame
## the player presses Play, so the synchronous half of the bake is the number
## that matters; the melody's note set is the expensive half and is on a
## worker thread, where it costs the frame nothing.
func _report_cost(director: Object) -> void:
	var start := Time.get_ticks_usec()
	for voice in director.PAD_VOICES:
		director.call("_make_pad_loop", voice["frequency"])
	var pad_us := Time.get_ticks_usec() - start

	start = Time.get_ticks_usec()
	for frequency in director.MUSIC_SCALE:
		director.call("_make_note_wav", frequency)
	var notes_us := Time.get_ticks_usec() - start

	print("  pad, synchronous in start():        %6.1f ms  (8 loops)" % [pad_us / 1000.0])
	print("  melody notes, on the worker thread: %6.1f ms  (%d pitches)"
		% [notes_us / 1000.0, director.MUSIC_SCALE.size()])


func _report_loops(director: Object) -> void:
	for voice in director.PAD_VOICES:
		var frequency: float = voice["frequency"]
		var wav: AudioStreamWAV = director.call("_make_pad_loop", frequency)
		var floats := _to_floats(wav)
		var cycles := maxi(1, int(ceil(float(director.PAD_LOOP_MIN_SAMPLES) * frequency / SR)))
		var actual := float(cycles) * SR / float(floats.size())
		var cents := 1200.0 * (log(actual / frequency) / log(2.0))
		# The honest seam test is not "are the endpoints close" -- it is
		# "is the step across the join any bigger than the steps inside the
		# buffer". If it is not, there is nothing there to hear.
		var seam: float = absf(floats[0] - floats[floats.size() - 1])
		var worst := 0.0
		for i in range(1, floats.size()):
			worst = maxf(worst, absf(floats[i] - floats[i - 1]))
		print("  %-3s want=%7.2f got=%8.3f (%+.3f cents) cycles=%2d samples=%5d seam=%.5f max_internal=%.5f ratio=%.3fx"
			% [voice["name"], frequency, actual, cents, cycles, floats.size(), seam, worst, seam / worst])


## Mixes the real synthesis the way _update_music()/_play_note() do.
func _render(director: Object, mood: float, seconds: float,
		pad: bool, melody: bool, breathing: bool) -> PackedFloat32Array:
	var total := int(seconds * SR)
	var out := PackedFloat32Array()
	out.resize(total)

	if pad:
		var slot := 0
		for voice_index in range(director.PAD_VOICES.size()):
			var voice: Dictionary = director.PAD_VOICES[voice_index]
			var loop := _to_floats(director.call("_make_pad_loop", voice["frequency"]))
			var gain: float = director.call("pad_gain", voice_index, mood)
			var rates: Array = [1.0, 1.0 + director.PAD_DETUNE] if voice["detune"] else [1.0]
			for rate in rates:
				if gain > 0.0:
					_mix_loop(out, loop, gain, float(rate),
						float(director.PAD_START_OFFSETS[slot]),
						breathing, float(director.PAD_BREATH_RATES[voice_index]),
						float(voice_index), director)
				slot += 1

	if melody:
		_mix_melody(out, director, mood, seconds)

	# The fade-in, applied last: CameraProfile.damp toward 1.0 every frame is
	# an exponential approach, so this is the closed form of it.
	for i in range(total):
		var t := float(i) / SR
		out[i] *= (1.0 - exp(-t * director.MUSIC_FADE_LAMBDA)) * director.MASTER_GAIN
	return out


## The same render, but with the mood sweeping afternoon -> dusk across the
## whole pass, which is how it is actually heard.
func _render_arc(director: Object, seconds: float) -> PackedFloat32Array:
	var total := int(seconds * SR)
	var out := PackedFloat32Array()
	out.resize(total)
	var slot := 0
	for voice_index in range(director.PAD_VOICES.size()):
		var voice: Dictionary = director.PAD_VOICES[voice_index]
		var loop := _to_floats(director.call("_make_pad_loop", voice["frequency"]))
		var rates: Array = [1.0, 1.0 + director.PAD_DETUNE] if voice["detune"] else [1.0]
		for rate in rates:
			var position: float = float(director.PAD_START_OFFSETS[slot]) * loop.size()
			var step: float = float(rate)
			for i in range(total):
				var mood := float(i) / float(total)
				var gain: float = director.call("pad_gain", voice_index, mood)
				gain *= 1.0 + director.PAD_BREATH_DEPTH * sin(
					TAU * float(director.PAD_BREATH_RATES[voice_index]) * (float(i) / SR) + float(voice_index))
				out[i] += _sample_loop(loop, position) * gain
				position = fposmod(position + step, float(loop.size()))
			slot += 1
	for i in range(total):
		var t := float(i) / SR
		out[i] *= (1.0 - exp(-t * director.MUSIC_FADE_LAMBDA)) * director.MASTER_GAIN
	return out


func _mix_loop(out: PackedFloat32Array, loop: PackedFloat32Array, gain: float,
		rate: float, offset: float, breathing: bool, breath_rate: float,
		phase: float, director: Object) -> void:
	var position := offset * loop.size()
	for i in range(out.size()):
		var g := gain
		if breathing:
			g *= 1.0 + director.PAD_BREATH_DEPTH * sin(TAU * breath_rate * (float(i) / SR) + phase)
		out[i] += _sample_loop(loop, position) * g
		position = fposmod(position + rate, float(loop.size()))


static func _sample_loop(loop: PackedFloat32Array, position: float) -> float:
	var i0 := int(position)
	var frac := position - float(i0)
	var i1 := (i0 + 1) % loop.size()
	return lerpf(loop[i0], loop[i1], frac)


## Replays _schedule_phrase()/_play_note() deterministically, using the same
## seed and the same RNG the game uses, so the rendered melody is the melody
## that will actually be heard.
func _mix_melody(out: PackedFloat32Array, director: Object, mood: float, seconds: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260830
	var cache := {}
	var base := int(round(director.call("mood_lerp", director.MELODY_BASE, mood)))
	var level: float = director.MELODY_LEVEL * director.MUSIC_GAIN \
		* float(director.call("mood_lerp", director.MELODY_LEVEL_BY_MOOD, mood))
	var cursor := 6.0
	var last := -1
	var count := 0
	while cursor < seconds:
		var index := rng.randi_range(0, director.MUSIC_PHRASES.size() - 1)
		if index == last:
			index = (index + 1) % director.MUSIC_PHRASES.size()
		last = index
		var phrase: Array = director.MUSIC_PHRASES[index]
		var last_onset := 0.0
		for note in phrase:
			last_onset = maxf(last_onset, float(note[1]))
			var scale_index: int = clampi(base + int(note[0]), 0, director.MUSIC_SCALE.size() - 1)
			var frequency: float = director.MUSIC_SCALE[scale_index]
			if not cache.has(frequency):
				cache[frequency] = _to_floats(director.call("_make_note_wav", frequency))
			var clip: PackedFloat32Array = cache[frequency]
			var start := int((cursor + float(note[1])) * SR)
			var velocity: float = float(note[2])
			for j in range(clip.size()):
				var s := start + j
				if s >= out.size():
					break
				if s >= 0:
					out[s] += clip[j] * level * velocity
			count += 1
		var rest: float = director.call("mood_lerp", director.MELODY_REST, mood)
		rest *= lerpf(director.MELODY_REST_BY_COMFORT[0], director.MELODY_REST_BY_COMFORT[1], 0.5)
		rest *= rng.randf_range(0.8, 1.2)
		cursor += last_onset + rest
	print("    (%d notes in %.0f s)" % [count, seconds])


func _render_drones(seconds: float, comfort: float, energy: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * SR))
	var director: GDScript = load("res://scripts/audio_director.gd")
	for i in range(3):
		var frequency: float = [92.0, 138.0, 207.0][i]
		var gain: float = director.mood_gain(i, comfort, energy)
		for s in range(out.size()):
			out[s] += sin(TAU * frequency * float(s) / SR) * gain
	for s in range(out.size()):
		out[s] *= 0.28
	return out


func _render_existing_chime(director: Object, kind: String) -> PackedFloat32Array:
	var floats := _to_floats(director.call("_make_chime_wav", kind))
	for i in range(floats.size()):
		floats[i] *= 0.28
	return floats


static func _to_floats(wav: AudioStreamWAV) -> PackedFloat32Array:
	var data := wav.data
	var count := data.size() / 2
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		out[i] = float(data.decode_s16(i * 2)) / 32767.0
	return out


func _db(x: float) -> float:
	return -999.0 if x <= 0.0 else 20.0 * (log(x) / log(10.0))


## IEC 61672 A-weighting magnitude, normalised to 0 dB at 1 kHz. The drone
## bed lives at 92-207 Hz where the ear is ~14 dB less sensitive than flat
## RMS suggests, so comparing the music to it on flat RMS alone would be
## misleading in the music's favour.
static func _a_weight(frequency: float) -> float:
	var f2 := frequency * frequency
	var num := 12194.0 * 12194.0 * f2 * f2
	var den := (f2 + 20.6 * 20.6) \
		* sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9)) \
		* (f2 + 12194.0 * 12194.0)
	if den <= 0.0:
		return 0.0
	return (num / den) * pow(10.0, 2.0 / 20.0)


func _report(name: String, floats: PackedFloat32Array) -> float:
	var sum_squares := 0.0
	var peak := 0.0
	for v in floats:
		sum_squares += v * v
		peak = maxf(peak, absf(v))
	var rms := sqrt(sum_squares / float(floats.size()))
	var power := _power_spectrum(floats)
	var total := 0.0
	var weighted := 0.0
	for bin in range(power.size()):
		var w := _a_weight(float(bin) * SR / float(power.size() * 2))
		total += power[bin]
		weighted += power[bin] * w * w
	var a := rms * sqrt(weighted / maxf(total, 1e-30))
	print("  %-26s len=%6.1fs  RMS=%7.2f  A-RMS=%7.2f  peak=%7.2f  crest=%5.2f dB"
		% [name, float(floats.size()) / SR, _db(rms), _db(a), _db(peak), _db(peak) - _db(rms)])
	return rms


func _click_check(name: String, floats: PackedFloat32Array) -> void:
	var steps := PackedFloat32Array()
	steps.resize(floats.size() - 1)
	var worst := 0.0
	var at := 0
	for i in range(1, floats.size()):
		var d := absf(floats[i] - floats[i - 1])
		steps[i - 1] = d
		if d > worst:
			worst = d
			at = i
	var sorted := Array(steps)
	sorted.sort()
	var p999: float = sorted[int(float(sorted.size()) * 0.999)]
	# A click is a step far larger than the signal's own typical slew. A real
	# discontinuity puts this ratio in the hundreds; band-limited audio keeps
	# it near 1.
	print("  %-26s max step=%.6f at %7.3fs  99.9th pct=%.6f  ratio=%6.2fx"
		% [name, worst, float(at) / SR, p999, worst / maxf(p999, 1e-12)])


static func _bands() -> Array:
	return [[0, 100], [100, 200], [200, 400], [400, 800],
		[800, 1600], [1600, 3200], [3200, 6400], [6400, 22050]]


## Power per FFT bin of a 32768-sample Hann-windowed slice from the middle of
## the signal (0.74 s, 1.35 Hz resolution). A first pass sampled each octave
## band at 24 probe frequencies instead; against a line spectrum like this one
## the probes mostly fell between the partials and the band shares were wrong
## by tens of percent. Bins do not miss lines.
func _power_spectrum(floats: PackedFloat32Array) -> PackedFloat64Array:
	var n := 32768
	while n > floats.size():
		n /= 2
	var start := maxi(0, (floats.size() - n) / 2)
	var re := PackedFloat64Array()
	var im := PackedFloat64Array()
	re.resize(n)
	im.resize(n)
	for i in range(n):
		var hann := 0.5 - 0.5 * cos(TAU * float(i) / float(n))
		re[i] = float(floats[start + i]) * hann
	_fft(re, im)
	var half := n / 2
	var power := PackedFloat64Array()
	power.resize(half)
	for i in range(half):
		power[i] = re[i] * re[i] + im[i] * im[i]
	return power


## Iterative in-place radix-2 Cooley-Tukey. n must be a power of two.
static func _fft(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j |= bit
		if i < j:
			var tr := re[i]
			re[i] = re[j]
			re[j] = tr
			var ti := im[i]
			im[i] = im[j]
			im[j] = ti
	var length := 2
	while length <= n:
		var angle := -TAU / float(length)
		var wr := cos(angle)
		var wi := sin(angle)
		var i := 0
		while i < n:
			var cr := 1.0
			var ci := 0.0
			for k in range(length / 2):
				var ur := re[i + k]
				var ui := im[i + k]
				var vr := re[i + k + length / 2] * cr - im[i + k + length / 2] * ci
				var vi := re[i + k + length / 2] * ci + im[i + k + length / 2] * cr
				re[i + k] = ur + vr
				im[i + k] = ui + vi
				re[i + k + length / 2] = ur - vr
				im[i + k + length / 2] = ui - vi
				var next_cr := cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = next_cr
			i += length
		length <<= 1


func _band_shares(floats: PackedFloat32Array, bands: Array) -> Array:
	var power := _power_spectrum(floats)
	var bins := power.size()
	var energies := []
	var total := 0.0
	for band in bands:
		var e := 0.0
		for bin in range(bins):
			var f := float(bin) * SR / float(bins * 2)
			if f >= float(band[0]) and f < float(band[1]):
				e += power[bin]
		energies.append(e)
		total += e
	var shares := []
	for e in energies:
		shares.append(100.0 * float(e) / maxf(total, 1e-30))
	return shares


func _goertzel(floats: PackedFloat32Array, frequency: float) -> float:
	var n := mini(floats.size(), SR)          # one second is plenty of resolution
	var start := maxi(0, (floats.size() - n) / 2)
	var w := TAU * frequency / SR
	var coefficient := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in range(start, start + n):
		var s := floats[i] + coefficient * s1 - s2
		s2 = s1
		s1 = s
	return s1 * s1 + s2 * s2 - coefficient * s1 * s2


func _spectrum(name: String, floats: PackedFloat32Array) -> void:
	var bands := _bands()
	var shares := _band_shares(floats, bands)
	var line := ""
	for i in range(bands.size()):
		line += "%d-%d:%5.1f%%  " % [bands[i][0], bands[i][1], shares[i]]
	print("  %s\n    %s" % [name, line])
	# Which chord tones are actually sounding: the mood tie-in, measured.
	var probe := {"A2": 110.0, "C3": 130.81, "E3": 164.81, "G3": 196.0,
		"C4": 261.63, "E4": 329.63, "B4": 493.88, "D5": 587.33}
	var out := ""
	var loudest := 0.0
	for key in probe:
		loudest = maxf(loudest, _goertzel(floats, float(probe[key])))
	for key in probe:
		var rel := _goertzel(floats, float(probe[key])) / maxf(loudest, 1e-30)
		out += "%s=%5.1fdB  " % [key, 10.0 * (log(maxf(rel, 1e-9)) / log(10.0))]
	print("    " + out)


func _write_wav(path: String, floats: PackedFloat32Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % path)
		return
	var count := floats.size()
	var data_bytes := count * 2
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data_bytes)
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)              # PCM
	file.store_16(1)              # mono
	file.store_32(SR)
	file.store_32(SR * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_bytes)
	for v in floats:
		file.store_16(int(round(clampf(v, -1.0, 1.0) * 32767.0)) & 0xFFFF)
	file.close()
