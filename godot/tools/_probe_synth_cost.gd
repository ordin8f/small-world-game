extends SceneTree

## Throwaway benchmark: how long does GDScript take to bake the music layer's
## waveforms? The answer decides the architecture. Fully-baked one-shot notes
## give the best timbre (upper partials decaying faster than the fundamental,
## which is what makes a struck note read as struck) but cost one
## sin()-per-partial-per-sample pass over ~2.8 s of audio. If that lands in
## the tens of milliseconds it can happen at start(); if it lands in hundreds,
## the note has to become an oscillator + per-frame VCA instead.

const SR := 44100


func _init() -> void:
	_bench_loop_tone()
	_bench_note(44100, 2.8, 5)
	_bench_note(44100, 2.8, 4)
	_bench_note(22050, 2.8, 5)
	_bench_encode(int(2.8 * 44100))
	quit()


func _bench_loop_tone() -> void:
	var partials := [1.0, 0.30, 0.12, 0.055, 0.025, 0.012]
	var start := Time.get_ticks_usec()
	var total := 0
	for freq in [110.0, 130.81, 164.81, 196.0, 261.63, 329.63, 493.88, 587.33]:
		var cycles: int = maxi(1, int(ceil(4000.0 * freq / SR)))
		var n: int = int(round(cycles * SR / freq))
		var floats := PackedFloat32Array()
		floats.resize(n)
		for k in range(partials.size()):
			var amp: float = partials[k]
			var mult := float(k + 1) * cycles
			for i in range(n):
				floats[i] += amp * sin(TAU * mult * float(i) / float(n))
		total += n
	var us := Time.get_ticks_usec() - start
	print("pad: 8 voices, %d samples total, 6 partials -> %.1f ms" % [total, us / 1000.0])


func _bench_note(rate: int, length: float, partials: int) -> void:
	var mults := [1.0, 2.0, 3.0, 4.16, 5.43]
	var amps := [1.0, 0.38, 0.15, 0.075, 0.030]
	var decays := [1.0, 0.55, 0.36, 0.26, 0.18]
	var n := int(length * rate)
	var start := Time.get_ticks_usec()
	var floats := PackedFloat32Array()
	floats.resize(n)
	for k in range(partials):
		var mult: float = mults[k]
		var amp: float = amps[k]
		var tau_k: float = 2.1 * float(decays[k])
		for i in range(n):
			var t := float(i) / float(rate)
			floats[i] += amp * sin(TAU * 440.0 * mult * t) * exp(-t / tau_k)
	var us := Time.get_ticks_usec() - start
	print("note: rate=%d len=%.1fs partials=%d (%d samples) -> %.1f ms"
		% [rate, length, partials, n, us / 1000.0])


func _bench_encode(n: int) -> void:
	var floats := PackedFloat32Array()
	floats.resize(n)
	var start := Time.get_ticks_usec()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(round(clampf(floats[i], -1.0, 1.0) * 32767.0)))
	var us := Time.get_ticks_usec() - start
	print("_floats_to_wav encode: %d samples -> %.1f ms" % [n, us / 1000.0])
