extends SceneTree

## Renders EVERY one-shot sound in the game to .wav and measures it, so the
## short cues can be listened to and inspected rather than asserted about.
##
## Short sounds are where clicks and clipping hide: a chime whose envelope
## stops before it reaches zero ends on a step, and a step is a click. This
## reports, for each cue, whether it starts and ends at silence, how big the
## worst sample-to-sample step is against the signal's own typical slew, and
## the level relative to the ambience it has to sit under.
##
## Covers the pre-existing cues as well as the new ones deliberately -- the
## point is a picture of the whole sound family, not just of what changed.
##
## Usage:
##   godot --headless --path godot --script res://tools/_probe_oneshots.gd
## Output: user://oneshot_render/*.wav

const SR := 44100
const OUT_DIR := "user://oneshot_render"


func _initialize() -> void:
	var director: Object = load("res://scripts/audio_director.gd").new()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var cues := []
	for kind in director.CHIME_KINDS:
		cues.append(["chime_%s" % kind, director.call("_make_chime_wav", kind)])
	cues.append(["step_walking", director.call("_make_step_wav", false)])
	cues.append(["step_running", director.call("_make_step_wav", true)])
	cues.append(["splash", director.call("_make_splash_wav")])
	cues.append(["slide_whoosh", director.call("_make_whoosh_wav")])
	cues.append(["sand_pat", director.call("_make_sand_pat_wav")])
	cues.append(["swing_creak", director.call("_make_creak_wav", 1.0)])
	cues.append(["bench_settle", director.call("_make_bench_wav")])

	print("MASTER_GAIN %.2f is applied below, so every dBFS figure is what "
		% director.MASTER_GAIN)
	print("actually reaches the bus, not the raw baked amplitude.\n")
	print("%-16s %7s %9s %9s %9s %9s %8s %9s"
		% ["cue", "length", "peak", "RMS", "first", "last", "step", "clicks?"])
	print("-".repeat(88))

	for cue in cues:
		var name: String = cue[0]
		var floats := _to_floats(cue[1])
		for i in range(floats.size()):
			floats[i] *= director.MASTER_GAIN
		_report(name, floats)
		_write_wav("%s/%s.wav" % [OUT_DIR, name], floats)

	print("\n'first'/'last' are the first and last sample in dBFS. A cue that "
		+ "ends well above\nsilence ends on a step, which is a click. "
		+ "'step' is the worst sample-to-sample\njump divided by the 99.9th "
		+ "percentile jump -- a real discontinuity puts that in the\nhundreds; "
		+ "band-limited audio keeps it near 1.")
	print("\nwrote: %s" % ProjectSettings.globalize_path(OUT_DIR))
	director.free()
	quit()


func _report(name: String, floats: PackedFloat32Array) -> void:
	var peak := 0.0
	var sum_squares := 0.0
	for v in floats:
		peak = maxf(peak, absf(v))
		sum_squares += v * v
	var rms := sqrt(sum_squares / float(floats.size()))

	var steps := []
	var worst := 0.0
	for i in range(1, floats.size()):
		var d := absf(floats[i] - floats[i - 1])
		steps.append(d)
		worst = maxf(worst, d)
	steps.sort()
	var p999: float = steps[int(float(steps.size()) * 0.999)]
	var ratio := worst / maxf(p999, 1e-12)

	var clipped := 0
	for v in floats:
		if absf(v) >= 0.9995:
			clipped += 1

	var verdict := "ok"
	if ratio > 20.0:
		verdict = "CLICK"
	if clipped > 0:
		verdict = "CLIPPED"

	print("%-16s %6.2fs %9.2f %9.2f %9.2f %9.2f %7.2fx %9s"
		% [name, float(floats.size()) / SR, _db(peak), _db(rms),
			_db(absf(floats[0])), _db(absf(floats[floats.size() - 1])),
			ratio, verdict])


func _db(x: float) -> float:
	return -999.0 if x <= 0.0 else 20.0 * (log(x) / log(10.0))


static func _to_floats(wav: AudioStreamWAV) -> PackedFloat32Array:
	var data := wav.data
	var count := data.size() / 2
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		out[i] = float(data.decode_s16(i * 2)) / 32767.0
	return out


func _write_wav(path: String, floats: PackedFloat32Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("could not write %s" % path)
		return
	var data_bytes := floats.size() * 2
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data_bytes)
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(SR)
	file.store_32(SR * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_bytes)
	for v in floats:
		file.store_16(int(round(clampf(v, -1.0, 1.0) * 32767.0)) & 0xFFFF)
	file.close()
